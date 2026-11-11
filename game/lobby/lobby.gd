extends Node2D
## The lobby: "Who keeps the watch tonight?" Pick a player, add one, or remove one; the game
## then runs for that player with its own save (ProfileStore). In a web build served from the
## home server, profiles and saves live there too (SaveSync), so a player can carry on from
## any device at home. The game's menu offers "Switch player", which returns here.

const SIZE := Vector2(1448, 1086)
const GAME_SCENE := "res://game/core/game.tscn"
const TITLE_PLATE := "res://assets/stages/photo_drawer.png"
const COLS := 2
const MAX_SHOWN := 8
const CARD := Vector2(500, 92)
const GRID_TOP := 300.0
const GAP := Vector2(28, 22)
const ARM_SECONDS := 3.0

## loading | pick | naming | starting | playing
var state := "loading"
var store := ProfileStore.new()
var sync: SaveSync
var game: Node
var serif: Font
var hand: Font
var notice := ""            # one line under the heading (errors, "saving...")
var hover := ""
var remove_armed := ""      # profile id whose Remove was clicked once
var remove_armed_at := -INF
var time := 0.0
var name_edit: LineEdit
var _plate: Texture2D

func _ready() -> void:
	Ink.install_web_fallback()
	serif = Ink.serif()
	hand = Ink.hand()
	if ResourceLoader.exists(TITLE_PLATE):
		_plate = load(TITLE_PLATE) as Texture2D
	sync = SaveSync.new(store)
	add_child(sync)
	_build_name_edit()
	await _refresh()

func _refresh() -> void:
	state = "loading"
	queue_redraw()
	if sync.enabled():
		var ok := await sync.refresh()
		notice = "" if ok else "The station server can't be reached. Saves stay on this device for now."
	state = "pick"
	queue_redraw()

func _process(dt: float) -> void:
	time += dt
	if remove_armed != "" and time - remove_armed_at > ARM_SECONDS:
		remove_armed = ""
		queue_redraw()

# ---------------------------------------------------------------------------
# layout
# ---------------------------------------------------------------------------
func shown_profiles() -> Array:
	return store.list().slice(0, MAX_SHOWN)

## Card `i` of the grid (players, then New player). A row holding one card is centred.
func card_rect(i: int) -> Rect2:
	var total := mini(shown_profiles().size() + 1, MAX_SHOWN)
	var row := i / COLS
	var in_row := mini(COLS, total - row * COLS)
	var w := in_row * CARD.x + (in_row - 1) * GAP.x
	var x0 := (SIZE.x - w) * 0.5
	return Rect2(x0 + (i % COLS) * (CARD.x + GAP.x), GRID_TOP + row * (CARD.y + GAP.y), CARD.x, CARD.y)

func remove_rect(i: int) -> Rect2:
	var r := card_rect(i)
	return Rect2(r.end.x - 118, r.position.y + 26, 104, 40)

func new_rect() -> Rect2:
	var n := shown_profiles().size()
	if n >= MAX_SHOWN:
		n = MAX_SHOWN - 1   # the last slot becomes "New player" when the grid is full
	return card_rect(n) if n < MAX_SHOWN else Rect2()

const PANEL := Rect2(374, 330, 700, 330)
const BEGIN_RECT := Rect2(744, 560, 290, 70)
const CANCEL_RECT := Rect2(414, 560, 290, 70)
const EDIT_RECT := Rect2(424, 440, 600, 70)

## What a click at `p` would do: "play:<id>", "remove:<id>", "new", "begin", "cancel" or "".
func action_at(p: Vector2) -> String:
	match state:
		"pick":
			var ps := shown_profiles()
			for i in ps.size():
				if remove_rect(i).has_point(p):
					return "remove:" + ps[i].id
				if card_rect(i).has_point(p):
					return "play:" + ps[i].id
			if new_rect().has_point(p) and store.list().size() < 64:
				return "new"
		"naming":
			if BEGIN_RECT.has_point(p):
				return "begin"
			if CANCEL_RECT.has_point(p):
				return "cancel"
	return ""

# ---------------------------------------------------------------------------
# actions
# ---------------------------------------------------------------------------
func act(a: String) -> void:
	if a == "":
		return
	if a == "new":
		state = "naming"
		notice = ""
		name_edit.text = ""
		name_edit.visible = true
		name_edit.grab_focus()
	elif a == "cancel":
		_close_naming()
	elif a == "begin":
		await _create(name_edit.text)
	elif a.begins_with("remove:"):
		var id := a.trim_prefix("remove:")
		if remove_armed == id and time - remove_armed_at <= ARM_SECONDS:
			remove_armed = ""
			await _remove(id)
		else:
			remove_armed = id
			remove_armed_at = time
	elif a.begins_with("play:"):
		await start(a.trim_prefix("play:"))
	queue_redraw()

func _close_naming() -> void:
	state = "pick"
	name_edit.visible = false
	name_edit.release_focus()
	queue_redraw()

func _create(raw: String) -> void:
	var problem := store.name_problem(raw)
	if problem != "":
		notice = problem
		queue_redraw()
		return
	var first := store.list().is_empty()
	var p: Dictionary
	if sync.enabled():
		p = await sync.create(raw)
	else:
		p = store.create(raw)
	if p.is_empty() or p.has("error"):
		notice = str(p.get("error", "That player couldn't be added. Try again."))
		queue_redraw()
		return
	# The first player on a device that played before the lobby keeps that watch.
	if first:
		store.adopt_legacy(p.id)
	_close_naming()
	await start(p.id, true)

func _remove(id: String) -> void:
	var name: String = store.find(id).get("name", "")
	var ok := true
	if sync.enabled() and not store.find(id).get("local", false):
		ok = await sync.remove(id)
	else:
		store.remove(id)
	notice = ("%s's watch is closed." % name) if ok else "Couldn't reach the station server to remove %s." % name
	queue_redraw()

## Runs the game for profile `id`. `fresh`: just created, nothing on the server to pull.
func start(id: String, fresh := false) -> void:
	var p := store.find(id)
	if p.is_empty() or state == "playing":
		return
	state = "starting"
	notice = ""
	queue_redraw()
	if sync.enabled() and not fresh and not p.get("local", false):
		if not await sync.pull(id):
			notice = "Playing from this device's copy; the server couldn't be reached."
	store.touch(id, int(Time.get_unix_time_from_system()))
	game = load(GAME_SCENE).instantiate()
	game.save_path = store.save_path(id)
	game.migrate_slice_save = false
	game.player_name = p.name
	game.switch_player_requested.connect(_on_switch_player)
	state = "playing"
	queue_redraw()
	add_child(game)
	sync.watch(id)

func _on_switch_player() -> void:
	if game == null:
		return
	var g := game
	game = null
	state = "loading"
	notice = "Saving..."
	g.queue_free()
	queue_redraw()
	await sync.stop()
	notice = ""
	await _refresh()

# ---------------------------------------------------------------------------
# input
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if state in ["playing", "loading", "starting"]:
		return
	var pos := get_global_mouse_position()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		act(action_at(pos))
	elif event is InputEventMouseMotion:
		var h := action_at(pos)
		if h != hover:
			hover = h
			queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and state == "naming":
		_close_naming()

func _build_name_edit() -> void:
	name_edit = LineEdit.new()
	name_edit.position = EDIT_RECT.position
	name_edit.size = EDIT_RECT.size
	name_edit.max_length = ProfileStore.NAME_MAX
	name_edit.placeholder_text = "Your name, as you'd sign the log"
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.add_theme_font_override("font", serif)
	name_edit.add_theme_font_size_override("font_size", 34)
	name_edit.add_theme_color_override("font_color", Ink.PAPER)
	name_edit.add_theme_color_override("font_placeholder_color", Color(Ink.PAPER, 0.4))
	name_edit.add_theme_color_override("caret_color", Ink.GOLD)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Ink.BLACK, 0.6)
	box.border_color = Color(Ink.GOLD, 0.7)
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	name_edit.add_theme_stylebox_override("normal", box)
	name_edit.add_theme_stylebox_override("focus", box)
	name_edit.visible = false
	name_edit.text_submitted.connect(func(t): act("begin"))
	add_child(name_edit)

# ---------------------------------------------------------------------------
# drawing
# ---------------------------------------------------------------------------
func _draw() -> void:
	if state == "playing":
		return
	draw_rect(Rect2(Vector2.ZERO, SIZE), Ink.BLACK)
	if _plate:
		var ts := Vector2(_plate.get_size())
		var k := maxf(SIZE.x / ts.x, SIZE.y / ts.y)
		draw_texture_rect(_plate, Rect2((SIZE - ts * k) * 0.5, ts * k), false, Color(0.55, 0.6, 0.62))
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(Ink.INK, 0.72))
	_centered("THE NINTH TIDE", 130, 64, Ink.PAPER, serif)
	_centered("Who keeps the watch tonight?", 206, 32, Color(Ink.PAPER, 0.85), hand)
	if notice != "":
		_centered(notice, 262, 22, Color(Ink.GOLD, 0.9), serif)
	match state:
		"loading", "starting":
			_centered("Opening the log book..." if state == "loading" else "Fetching your watch...", 520, 26, Color(Ink.PAPER, 0.7), hand)
		"pick":
			_draw_cards()
		"naming":
			_draw_naming()
	var where := "Your watch is kept at the station: carry on from any device at home." if sync.online \
		else "Each player keeps their own watch on this device."
	_centered(where, 1040, 18, Color(Ink.PAPER, 0.55), serif)

func _draw_cards() -> void:
	var ps := shown_profiles()
	for i in ps.size():
		var p: Dictionary = ps[i]
		var r := card_rect(i)
		var lit: bool = hover == "play:" + p.id
		_card(r, lit)
		Ink.text(self, p.name, r.position + Vector2(26, 44), 32, Ink.PAPER, serif, r.size.x - 160, HORIZONTAL_ALIGNMENT_LEFT)
		Ink.text(self, last_seen(int(p.updated)), r.position + Vector2(26, 76), 18, Color(Ink.PAPER, 0.6), hand, r.size.x - 160, HORIZONTAL_ALIGNMENT_LEFT)
		var armed: bool = remove_armed == p.id
		Ink.button(self, remove_rect(i), "Sure?" if armed else "Remove", armed, 18, not armed and hover != "remove:" + p.id)
	var nr := new_rect()
	if nr.size != Vector2.ZERO and ps.size() <= MAX_SHOWN:
		_card(nr, hover == "new", true)
		var label := "+  New player" if ps.size() > 0 else "+  Sign the log to begin"
		Ink.text(self, label, nr.position + Vector2(0, 58), 28, Color(Ink.GOLD, 0.95), serif, nr.size.x)
	if remove_armed != "":
		_centered("Click Sure? to remove %s and their saved progress." % store.find(remove_armed).get("name", ""),
			GRID_TOP - 18, 20, Color(Ink.PAPER, 0.75), serif)

func _draw_naming() -> void:
	_card(PANEL, false)
	_centered("Sign the log", PANEL.position.y + 70, 36, Ink.PAPER, serif)
	Ink.button(self, CANCEL_RECT, "Cancel", false, 24, hover != "cancel")
	Ink.button(self, BEGIN_RECT, "Begin the watch", hover == "begin", 24)

func _card(r: Rect2, lit: bool, dashed := false) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Ink.BLACK, 0.55 if not lit else 0.75)
	s.border_color = Color(Ink.GOLD, 0.9) if lit else Color("8ba19a", 0.35 if dashed else 0.6)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	draw_style_box(s, r)

func _centered(s: String, y: float, size: int, col: Color, font: Font) -> void:
	draw_string_outline(font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, size, maxi(5, size / 6), Color(Ink.INK, 0.7 * col.a))
	draw_string(font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, size, col)

## "Last on watch: today" etc., from a unix time (0: never).
func last_seen(t: int) -> String:
	if t <= 0:
		return "Not yet on watch"
	var days := int((Time.get_unix_time_from_system() - t) / 86400.0)
	if days <= 0:
		return "Last on watch today"
	if days == 1:
		return "Last on watch yesterday"
	return "Last on watch %d days ago" % days
