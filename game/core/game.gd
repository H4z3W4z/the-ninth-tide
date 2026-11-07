class_name GameView
extends Node2D
## The one game scene: hosts the current room's view and everything shared by every room.
##
## Layering:
##   world (layer 0): the current room view (game/rooms/<rid>/<rid>_view.tscn). A room may
##                    add its own CanvasModulate, lights and CanvasLayers (close-ups at 5).
##   CanvasLayer 8 "over":  title, menu, notebook, end card (always fully readable)
##   CanvasLayer 9 "card":  the tide card that marks a tide change
##   CanvasLayer 10 "hud":  subtitles, HUD buttons, inventory bar, Back, hover names
##
## All story state lives in `sim` (GameSim). This node only presents it: the subtitle /
## typewriter / chain scheduler, one-shot sounds, saves, input routing. Everything timed
## here is presentation and is never saved. Lifted from the Intake Office slice view.

const SIZE := Vector2(1448, 1086)
const DEFAULT_SAVE_PATH := "user://ninth_tide_progress.json"
const SETTINGS_SUFFIX := ".settings.json"
const PREV_SUFFIX := ".prev.json"
const CHECKPOINT_SUFFIX := ".pre_ending.json"
## The slice's save: migrated once if no full-game save exists. Never deleted.
const SLICE_SAVE_PATH := "user://intake_office_v2.json"

const HUD_BUTTONS := [
	["notebook", Rect2(1112, 22, 150, 50), "Notebook"],
	["hint", Rect2(1272, 22, 86, 50), "Hint"],
	["menu", Rect2(1368, 22, 58, 50), "≡"],
]
const BACK_RECT := Rect2(952, 22, 150, 50)
## Inventory slots run left to right along the top-left of the HUD.
const INV_ORIGIN := Vector2(20, 22)
const INV_SLOT := Vector2(140, 50)
const INV_GAP := 10.0
const INV_MAX := 6
## More items than slots: five items a page and a pager in the sixth slot.
const INV_PER_PAGE := 5
const END_BUTTONS := [["return_decision", Rect2(364, 880, 340, 70), "Return to final decision"],
	["new_game", Rect2(744, 880, 340, 70), "New game"]]
const NOTEBOOK_PAGE := Rect2(164, 90, 1120, 900)

const REVEAL_CPS := 14.0      # characters per second handwriting writes itself
const TYPE_CPS := 48.0        # subtitle typewriter
const LINE_LINGER := 4.0      # a line with nothing after it clears this long after its hold
const ADVANCE_SWALLOW := 0.35 # a click this soon after a story line went up is swallowed
const VOICE_CAP := 2          # live copies of one one-shot at most
const RESTART_ARM := 3.0      # seconds the menu's restart stays armed after the first click
const FEEDBACK_HOLD := 1.2    # a click's line stays up at least this long before the next replaces it
const BACKLOG_SQUEEZE := 0.6  # read-time factor for older story lines when a new reveal arrives
const TIDE_CARD_TIME := 3.0
const TIDE_CARD_FADE := 0.5
const TIDE_CARD_STILL := 2.5  # Motion off: the card is simply there this long
const TIDE_CARD_QUIET := 1.0  # the card waits this long after the last story line's hold
## In a close-up the card sits in the band above the subtitles, or the nearest band clear
## of the close-up's controls (a slimmer card if no full one fits).
const TIDE_CARD_CLOSEUP_RECT := Rect2(324, 860, 800, 110)
const TIDE_CARD_SLIM_H := 84.0
const TIDE_CARD_CLOSEUP_ALPHA := 0.85
const TRAVEL_DEBOUNCE := 0.4  # an exit or plan click this soon after arriving is ignored
## The glance: corner brackets that show where a commit's reward is (when the room has no
## glance of its own). Storm navy, on the HUD layer.
const GLANCE_TIME := 2.5
const GLANCE_EASE := 0.3
const GLANCE_ARM := 48.0
const GLANCE_THICK := 4.0
const GLANCE_BACKS := 4       # at most this many Backs to put a close-up down for a glance
## A hovered target taller than this (or any close-up control) puts its label above it.
const HOVER_TALL := 120.0
const HOVER_H := 34.0
const HOVER_SIZE := 20
const HOVER_MARGIN := 8.0
const HOVER_BAR_Y := 980.0    # last resort: the label sits in the row above the subtitles
## Actions a click always carries out, even while a story chain plays (the chain advances
## first). Room hotspots and close-up controls only advance a playing chain.
const ALWAYS_ACT_PREFIXES := ["go:", "item:"]
const ALWAYS_ACT_NOTEBOOK := ["tab:", "plan:", "nbpage:"]
const TRAVEL_DIP := 0.25      # storm-navy dip between rooms (Motion on)
const TRAVEL_DIP_COLOR := Color("1b2a36")
const MIXER_FADE := 0.4       # the old room's loops fade out this long after she leaves
const MIXER_FADE_RATE := 2.5
## The notebook's layouts, roomiest first. Past the last, the entries go on more pages.
const NB_LAYOUTS := [[22, 960, 1], [20, 960, 1], [18, 960, 1], [18, 460, 2], [17, 460, 2]]
const NB_INTRUSION_ROOM := 40.0

## Base levels for one-shots (dB) the core plays for itself; rooms add their own SFX_DB.
const SFX_DB := {"page": -10.0}

var save_path := DEFAULT_SAVE_PATH
## Tests and capture runs set this false so they never pick up the slice's real save.
var migrate_slice_save := true
var sim := GameSim.new()
var room_view: RoomView
var serif: Font
var hand: Font

# nodes
var world: Node2D
var over: Node2D
var card: Node2D
var hud: Node2D
var subtitle: Label

# presentation state (never saved)
var lines: Array = []          # queued {text, due, story, beat, click, hold}, sorted by due
var cur_text := ""
var cur_story := false
var cur_since := 0.0
var cur_hold := 0.0
var cur_click := 0
var line_t := 0.0
var hover_id := ""
var time := 0.0
var pending_sfx: Array = []    # [id, time_left, beat]
var oneshots: Array = []
var dev := false
var click_id := 0
var restart_armed_at := -INF
var slab_a := 0.0
var shown_log: Array = []      # every line that went up, in order (tests and drivers read it)
var played_log: Array = []     # [sfx id, shown_log.size() when it played]
var last_events: Array = []
var intrusion_written := false
var intrusion_t := 0.0
var tide_card_t := 99.0
var tide_card_n := 0
var tide_card_pending := 0     # a tide card waiting for the reveal before it to finish
var tide_card_closeup := false # the card started over a close-up: it sits low
var tide_card_closeup_rect := TIDE_CARD_CLOSEUP_RECT
var story_end := -INF          # when the last story line's hold ended (or ends)
var arrived_at := -INF         # when she last arrived in a room (travel debounce)
var pending_glance := {}       # a glance fx waiting for its chain to finish
var glance_t := 99.0
var glance_rect := Rect2()
var end_t := 0.0
var last_checkpoint := ""
var inv_page := 0              # the inventory page on show (presentation only)
var nb_page := -1              # the notebook page on show; -1 = the page with the newest entry
var nb_cache := {}             # notebook pagination, keyed by what it depends on
var came_from := ""            # the room she last travelled from (the placeholder's way back)
var travel_dip_t := 99.0
var fading_mixers: Array = []  # [LoopMixer, seconds left] the rooms she just left
var seen_game_view := ""
var seen_local_view := ""
var seen_inv_size := 0

func _ready() -> void:
	serif = Ink.serif()
	hand = Ink.hand()
	_build_nodes()
	_build_audio()
	_load_progress()
	_mount_room()
	_redraw()

func _exit_tree() -> void:
	for p in oneshots:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
			p.queue_free()
	oneshots.clear()

# ---------------------------------------------------------------------------
# setup
# ---------------------------------------------------------------------------
func _build_nodes() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	var over_layer := CanvasLayer.new()
	over_layer.layer = 8
	add_child(over_layer)
	over = Node2D.new()
	over_layer.add_child(over)
	over.draw.connect(_draw_over)
	var card_layer := CanvasLayer.new()
	card_layer.layer = 9
	add_child(card_layer)
	card = Node2D.new()
	card_layer.add_child(card)
	card.draw.connect(_draw_card)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Node2D.new()
	hud_layer.add_child(hud)
	hud.draw.connect(_draw_hud)
	subtitle = Label.new()
	subtitle.position = Vector2(48, 996)
	subtitle.size = Vector2(1352, 76)
	subtitle.add_theme_font_override("font", serif)
	subtitle.add_theme_font_size_override("font_size", 27)
	subtitle.add_theme_color_override("font_color", Ink.PAPER)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.visible_ratio = 1.0
	hud_layer.add_child(subtitle)

func _build_audio() -> void:
	# One limiter on Master, however many times the scene is instanced.
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)

## Shows the current room's view, replacing any other. A room without a view of its own
## gets the placeholder.
func _mount_room(travel := false) -> void:
	var rid: String = sim.state.room
	if room_view and is_instance_valid(room_view) and room_view.rid == rid:
		return
	if room_view and is_instance_valid(room_view):
		if travel:
			# The room she leaves keeps sounding for a moment, fading out, instead of cutting.
			for m in _mixers_in(room_view):
				m.carry_to(self)
				fading_mixers.append([m, MIXER_FADE])
		world.remove_child(room_view)
		room_view.queue_free()
	var path := "res://game/rooms/%s/%s_view.tscn" % [rid, rid]
	var v: RoomView
	if ResourceLoader.exists(path):
		v = load(path).instantiate()
	else:
		v = RoomView.new()
	v.game = self
	v.rid = rid
	v.sim = sim.room(rid)
	v.name = "Room" + rid
	world.add_child(v)
	room_view = v
	v.apply_instantly()
	if travel:
		# Arriving, the room's loops start from silence; its own tick() brings them up.
		for m in _mixers_in(v):
			m.snap({})
		if sim.settings.motion:
			travel_dip_t = 0.0

## Every LoopMixer under `n`.
static func _mixers_in(n: Node) -> Array:
	var out := []
	for ch in n.get_children():
		if ch is LoopMixer:
			out.append(ch)
		out.append_array(_mixers_in(ch))
	return out

func _tick_fading_mixers(dt: float) -> void:
	for i in range(fading_mixers.size() - 1, -1, -1):
		var m: LoopMixer = fading_mixers[i][0]
		fading_mixers[i][1] -= dt
		if not is_instance_valid(m):
			fading_mixers.remove_at(i)
			continue
		m.tick({}, {}, dt, MIXER_FADE_RATE)
		if fading_mixers[i][1] <= 0.0:
			fading_mixers.remove_at(i)
			m.queue_free()

## The current room's sim.
func room_sim() -> RoomSim:
	return sim.room()

# ---------------------------------------------------------------------------
# persistence
# ---------------------------------------------------------------------------
func _settings_path() -> String:
	return save_path.get_basename() + SETTINGS_SUFFIX

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return null
	return j.data

func _load_progress() -> void:
	sim.load_settings(_read_json(_settings_path()))
	var d = _read_json(save_path)
	var loaded := false
	if d != null:
		loaded = sim.from_dict(d)
	if not loaded:
		# The previous valid save, then (once) the slice's.
		d = _read_json(save_path.get_basename() + PREV_SUFFIX)
		if d != null:
			loaded = sim.from_dict(d)
	if not loaded and migrate_slice_save and save_path == DEFAULT_SAVE_PATH:
		d = _read_json(SLICE_SAVE_PATH)
		if d != null:
			loaded = sim.from_dict(d)
	if not loaded:
		sim.reset()
	var cp = _read_json(save_path.get_basename() + CHECKPOINT_SUFFIX)
	if cp is Dictionary:
		sim.checkpoint = cp
	if loaded and sim.state.started and sim.view == "room":
		var r := sim.room()
		_queue_line(r.c("RESUME", "Back.") + " " + sim.objective_text(), 0.3)

func _save_progress() -> void:
	var text := JSON.stringify(sim.to_dict())
	var old := FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else ""
	if old != "" and old != text:
		var prev := FileAccess.open(save_path.get_basename() + PREV_SUFFIX, FileAccess.WRITE)
		if prev:
			prev.store_string(old)
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(text)
	var s := FileAccess.open(_settings_path(), FileAccess.WRITE)
	if s:
		s.store_string(JSON.stringify(sim.settings_dict()))
	if not sim.checkpoint.is_empty():
		var cp := JSON.stringify(sim.checkpoint)
		if cp != last_checkpoint:
			last_checkpoint = cp
			var c := FileAccess.open(save_path.get_basename() + CHECKPOINT_SUFFIX, FileAccess.WRITE)
			if c:
				c.store_string(cp)

## Removes every file this scene writes for `path` (tests and capture runs).
static func remove_saves(path: String) -> void:
	for p in [path, path.get_basename() + SETTINGS_SUFFIX, path.get_basename() + PREV_SUFFIX,
			path.get_basename() + CHECKPOINT_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------
func _process(dt: float) -> void:
	time += dt
	_tick_lines(dt)
	if cur_story and cur_text != "":
		story_end = cur_since + cur_hold
	_tick_sfx(dt)
	if room_view:
		room_view.tick(dt)
	if sim.view == "notebook" and _intrusion_writing():
		intrusion_t += dt
	if sim.view == "end":
		end_t += dt
	tide_card_t += dt
	glance_t += dt
	_tick_tide_card()
	_tick_glance()
	_tick_fading_mixers(dt)
	_refresh_hover_on_view_change()
	_keep_inv_page()
	if not sim.view in ["room"] or travel_dip_t < TRAVEL_DIP + dt:
		over.queue_redraw()
	travel_dip_t += dt
	if tide_card_t < TIDE_CARD_TIME + dt:
		card.queue_redraw()
	hud.queue_redraw()

## The reveal finishes before the tide card: a pending card starts once no story chain is
## playing and the last story line has been readable for TIDE_CARD_QUIET.
func _tick_tide_card() -> void:
	if tide_card_pending <= 0 or chain_active() or time < story_end + TIDE_CARD_QUIET:
		return
	_start_tide_card()

func _start_tide_card() -> void:
	tide_card_n = tide_card_pending
	tide_card_pending = 0
	tide_card_t = 0.0
	tide_card_closeup = room_sim() != null and sim.view == "room" and room_sim().is_closeup()
	if tide_card_closeup:
		tide_card_closeup_rect = _closeup_card_rect()
	card.queue_redraw()

## The close-up band for the card: TIDE_CARD_CLOSEUP_RECT if no control is under it, else
## the lowest clear band (scanning up from the subtitles), full height first, then slim.
func _closeup_card_rect() -> Rect2:
	var avoid := []
	if room_view:
		for h in room_view.control_rows():
			avoid.append(h[1])
	var base := TIDE_CARD_CLOSEUP_RECT
	for h in [base.size.y, TIDE_CARD_SLIM_H]:
		var ys := [base.position.y]
		var y: float = 994.0 - h - 4.0
		while y >= 84.0:
			ys.append(y)
			y -= 6.0
		for cy in ys:
			var r := Rect2(base.position.x, cy, base.size.x, h)
			if r.end.y > 994.0:
				continue
			var clear := true
			for a in avoid:
				clear = clear and not r.intersects(a)
			if clear:
				return r
	return base

## True while a tide card is waiting or on screen (rooms that hold their own beat for it).
func tide_card_busy() -> bool:
	return tide_card_pending > 0 or tide_card_alpha() > 0.0

## A glance waits for its chain; then the close-up is put down (by the sim's own Back) and
## the room shows where the reward is, or the core brackets it.
func _tick_glance() -> void:
	if pending_glance.is_empty() or chain_active() or sim.view != "room" or room_sim() == null:
		return
	var tries := 0
	while room_sim().is_closeup() and tries < GLANCE_BACKS:
		dispatch("back")
		tries += 1
	var e := pending_glance
	pending_glance = {}
	var rect := glance_rect_of(e.get("rect"))
	if room_view == null or not room_view.start_glance(str(e.get("target", "")), rect):
		glance_rect = rect
		glance_t = 0.0

## A glance fx's rect: [x, y, w, h] (the sim's JSON-safe form) or a Rect2.
static func glance_rect_of(v: Variant) -> Rect2:
	if v is Rect2:
		return v
	if v is Array and v.size() == 4:
		return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return Rect2()

## 0..1: the core's glance brackets. Motion on they ease in over GLANCE_EASE; off, they are
## simply there for GLANCE_TIME.
func glance_alpha() -> float:
	if glance_rect.size == Vector2.ZERO or glance_t >= GLANCE_TIME:
		return 0.0
	if not sim.settings.motion:
		return 1.0
	return smoothstep(0.0, GLANCE_EASE, glance_t) * clampf((GLANCE_TIME - glance_t) / GLANCE_EASE, 0.0, 1.0)

## A view change (a close-up opening, the notebook) re-reads what is under the pointer, so
## a label from the view she left never hangs over the new one.
func _refresh_hover_on_view_change() -> void:
	var lv: String = room_sim().local_view if room_sim() else ""
	if sim.view == seen_game_view and lv == seen_local_view:
		return
	_mark_view_seen()
	hover_id = _hover_at(get_global_mouse_position())

func _mark_view_seen() -> void:
	seen_game_view = sim.view
	seen_local_view = room_sim().local_view if room_sim() else ""

func _tick_sfx(dt: float) -> void:
	for i in range(pending_sfx.size() - 1, -1, -1):
		pending_sfx[i][1] -= dt
		var id: String = pending_sfx[i][0]
		if room_view:
			room_view.on_sfx_pending(id, pending_sfx[i][1])
		if pending_sfx[i][1] <= 0.0:
			pending_sfx.remove_at(i)
			_play_sfx_now(id)

# ---------------------------------------------------------------------------
# subtitles: a scheduler keyed to absolute time
# ---------------------------------------------------------------------------
static func min_read(text: String) -> float:
	return 0.7 + 0.028 * text.length()

## A story line on screen can't be replaced by a click until it has been readable.
func _cur_protected() -> bool:
	return cur_story and cur_text != "" and time - cur_since < cur_hold

## Queued lines never cut off any line before its hold. A non-story line yields early: to
## a newer click's line after FEEDBACK_HOLD, and to a waiting story line once it has had
## the squeezed read time, so chatter never starves a reveal.
func _cur_readable(next: Dictionary = {}) -> bool:
	if cur_text == "":
		return true
	var hold := cur_hold
	if not cur_story:
		if int(next.get("click", 0)) > cur_click:
			hold = minf(hold, FEEDBACK_HOLD)
		elif next.get("story", false):
			hold = minf(hold, maxf(FEEDBACK_HOLD, min_read(cur_text) * BACKLOG_SQUEEZE))
	return time - cur_since >= hold

## When the story lines already queued (and a story line on screen) will have been read.
func _story_backlog_end() -> float:
	var t := time
	if cur_story and cur_text != "":
		t = maxf(t, cur_since + cur_hold)
	for l in lines:
		if l.story:
			t = maxf(t, l.due) + l.hold
	return t

## A new scene's reveal is arriving: everything older still waiting is re-timed back to
## back from now at BACKLOG_SQUEEZE of its read time. Returns when the squeezed backlog ends.
func _squeeze_backlog() -> float:
	var t := time
	if cur_story and cur_text != "":
		cur_hold = minf(cur_hold, min_read(cur_text) * BACKLOG_SQUEEZE)
		t = maxf(t, cur_since + cur_hold)
	for l in lines:
		if l.story:
			l.hold = min_read(l.text) * BACKLOG_SQUEEZE
			l.due = t
			t += l.hold
	return t

func _tick_lines(dt: float) -> void:
	if not lines.is_empty() and lines[0].due <= time and _cur_readable(lines[0]):
		var head: Dictionary = lines.pop_front()
		_show_line(head.text, head.story, head.hold, head.click)
	if cur_text != "":
		line_t += dt
		subtitle.visible_characters = int(line_t * TYPE_CPS)
		if lines.is_empty() and time - cur_since > cur_hold + LINE_LINGER:
			cur_text = ""
			cur_story = false
			subtitle.text = ""
	# The slab is up only while something is said (or about to be): an empty slab never waits
	# for a line that is seconds away.
	if cur_text == "" and not _line_due_within(0.2):
		slab_a = maxf(0.0, slab_a - dt / 0.4)
	else:
		slab_a = minf(1.0, slab_a + dt / 0.15)

func _line_due_within(s: float) -> bool:
	return not lines.is_empty() and lines[0].due - time <= s

## A story chain is playing: a line of it is queued, or one is on screen and still held.
func chain_active() -> bool:
	for l in lines:
		if l.story:
			return true
	return cur_story and cur_text != "" and time - cur_since < cur_hold

## The player sets the chain's speed: bring its next line up now, with its own sounds.
func advance() -> void:
	if cur_story and cur_text != "" and time - cur_since < ADVANCE_SWALLOW:
		return   # a double click doesn't skip a line unread
	var next: Dictionary = {}
	for l in lines:
		if l.story:
			next = l
			break
	if next.is_empty():
		# Only the last line is left on screen: release it, so the next click is a click.
		if cur_story and cur_text != "":
			cur_hold = minf(cur_hold, time - cur_since)
		return
	var delta := maxf(0.0, next.due - time)
	for l in lines:
		l.due -= delta
	var due_now: Array = []
	for i in range(pending_sfx.size() - 1, -1, -1):
		var p: Array = pending_sfx[i]
		if next.beat != 0 and p[2] == next.beat:
			p[1] -= delta
		if room_view:
			room_view.on_sfx_pending(p[0], p[1])
		if p[1] <= 0.0:
			due_now.append(p)
			pending_sfx.remove_at(i)
	# The sounds a line waits for land before it does.
	due_now.sort_custom(func(a, b): return a[1] < b[1])
	for p in due_now:
		_play_sfx_now(p[0])
	lines.erase(next)
	_show_line(next.text, true, next.hold, next.click)

## A click (or tap) at `p`, exactly as the mouse handler does it. Drivers and tests use it.
## Clicks are never eaten: the HUD always answers, and exits, Back, the inventory and the
## notebook's tabs, plan rows and pages always act (a playing chain advances first, in the
## same press). Only a room hotspot or close-up control click is spent advancing a chain.
## The room sees its click first (consume_click: skipping its own hold).
func click(p: Vector2) -> void:
	var a := _core_action_at(p)
	if a == "" and _room_takes_click():
		if room_view.consume_click(p):
			return
		a = room_view.action_at(p)
	if a in ["notebook", "hint", "menu"]:
		if not _cinematic():
			dispatch(a)
		return
	if (a.begins_with("go:") or a.begins_with("plan:")) and time - arrived_at < TRAVEL_DEBOUNCE:
		return   # a double click on an exit moves one room, not two
	if always_acts(a):
		if _chain_gates() and chain_active():
			advance()
		if not _local_action(a):
			dispatch(a)
		return
	if _local_action(a):
		return
	if _chain_gates() and chain_active():
		advance()
		return
	if a != "":
		dispatch(a)

## True for the actions a click always carries out, even during a story chain: exits,
## Back, the inventory, and in the notebook its tabs, plan rows and page turners.
func always_acts(a: String) -> bool:
	if a == "back" or a == "inv_page":
		return true
	for pre in ALWAYS_ACT_PREFIXES:
		if a.begins_with(pre):
			return true
	if sim.view == "notebook":
		for pre in ALWAYS_ACT_NOTEBOOK:
			if a.begins_with(pre):
				return true
	return false

## A full-screen room moment (an interlude card): no notebook, hint or menu from the HUD.
func _cinematic() -> bool:
	return sim.view == "room" and room_view != null and room_view.hud_hidden()

## Presentation-only controls (inventory and notebook pages): never sent to the sim.
func _local_action(a: String) -> bool:
	match a:
		"inv_page":
			var pages := _inv_pages()
			inv_page = (_inv_page_shown() + 1) % pages
		"nbpage:prev", "nbpage:next":
			var info := _nb_pagination(_nb_page())
			var n: int = info.pages.size()
			var cur: int = info.shown
			nb_page = clampi(cur + (1 if a == "nbpage:next" else -1), 0, n - 1)
		_:
			return false
	_redraw()
	return true

## Views where a playing chain holds clicks. The title, end card and menu show no
## subtitles; a room may exempt its own views (the threshold has its own clock).
func _chain_gates() -> bool:
	if sim.view in ["title", "end", "menu"]:
		return false
	return room_view == null or sim.view != "room" or room_view.chain_gates()

func _show_line(text: String, story: bool, hold := -1.0, from_click := -1) -> void:
	if cur_story and cur_text != "":
		story_end = cur_since + minf(cur_hold, time - cur_since)   # the story line it replaces
	cur_text = text
	cur_story = story
	cur_click = click_id if from_click < 0 else from_click
	cur_since = time
	cur_hold = min_read(text) if hold < 0.0 else hold
	line_t = 0.0
	if story:
		story_end = cur_since + cur_hold
	subtitle.text = text
	shown_log.append(text)
	subtitle.add_theme_font_size_override("font_size", 24 if text.length() > 90 else 27)
	subtitle.visible_characters = 0

## Inserts a line due at absolute time `due`, after any line due no later.
func _insert_line(text: String, due: float, story: bool, beat := 0) -> void:
	var i := lines.size()
	while i > 0 and lines[i - 1].due > due:
		i -= 1
	lines.insert(i, _line(text, due, story, beat))

func _line(text: String, due: float, story: bool, beat: int) -> Dictionary:
	return {"text": text, "due": due, "story": story, "beat": beat, "click": click_id,
		"hold": min_read(text)}

func _queue_line(text: String, delay := 0.0, story := false) -> void:
	_insert_line(text, time + delay, story)

## A click's immediate line. Drops older clicks' chatter (never a story line, never this
## click's own lines). If a story line is still being read, or the last click's line has
## been up for less than FEEDBACK_HOLD, the new line goes to the front of the queue.
func _say_now(text: String, story: bool) -> void:
	lines = lines.filter(func(l): return l.story or l.click == click_id)
	var due := -1.0
	if _cur_protected():
		due = time
	elif not cur_story and cur_text != "" and time - cur_since < FEEDBACK_HOLD:
		due = cur_since + FEEDBACK_HOLD
	if due < 0.0:
		_show_line(text, story)
	elif story:
		_insert_line(text, due, story)
	else:
		lines.insert(0, _line(text, due, story, 0))

# ---------------------------------------------------------------------------
# events
# ---------------------------------------------------------------------------
func dispatch(action: String) -> void:
	if action == "restart_arm":
		# The menu's restart takes two clicks: the first only asks.
		restart_armed_at = time
		_redraw()
		return
	click_id += 1
	var before_game := sim.view
	var before_room := room_sim().view if room_sim() else ""
	var chain_was := chain_active()
	var before_tab := sim.nb_tab
	var ev := sim.dispatch(action)
	last_events = ev
	play_events(ev, chain_was)
	_mount_room()
	var after_room := room_sim().view if room_sim() else ""
	if before_room != after_room or before_game != sim.view:
		hover_id = ""   # the label of what she was pointing at stays with the view she left
		_mark_view_seen()
		_on_view_changed(before_game, before_room)
	if sim.nb_tab != before_tab:
		nb_page = -1
	if action.begins_with("item:") and sim.selected_item != "":
		_show_item_page(sim.selected_item)   # the page that holds what's in her hand
	if sim.view == "title":
		_reset_presentation()
	_refresh_hover_on_view_change()
	_save_progress()
	_redraw()

## Plays a list of sim events. Story chains are atomic: anything that arrives while one
## plays (a Hint, a key) waits after it, whole and in order, with its timed sounds.
func play_events(ev: Array, chain_was := false) -> void:
	var beat := false
	for e in ev:
		if e.type == "say" and e.get("story", false) and e.delay > 0.0:
			beat = true
	var offset := 0.0
	if chain_was:
		offset = maxf(0.0, _story_backlog_end() - time)
	elif beat:
		lines = lines.filter(func(l): return l.story)   # older chatter gives way to a reveal
	var beat_id := click_id if beat else 0
	var spoke_now := false
	card_offered = false
	for e in ev:
		match e.type:
			"say":
				var story: bool = e.get("story", false)
				if e.delay <= 0.0 and not spoke_now and offset <= 0.0:
					spoke_now = true
					_say_now(e.text, story)
				else:
					_insert_line(e.text, time + offset + e.delay, story, beat_id)
			"sfx":
				if e.delay > 0.0:
					pending_sfx.append([e.id, e.delay + offset, beat_id])
				else:
					_play_sfx_now(e.id)
			"fx":
				_play_fx(e)
	_settle_card_offer()

## While one event list plays, a new tide card is offered to the room as "just started"
## (tide_card_t = 0): a room view that times the card to its own beat takes it over from its
## play_fx by setting tide_card_t to 99 and releasing it later (R01's withdrawal). After the
## list, a card no room took goes back to waiting for the reveal.
var card_offered := false

func _settle_card_offer() -> void:
	if not card_offered:
		return
	card_offered = false
	if tide_card_pending <= 0:
		return   # it started already (she travelled)
	if tide_card_t >= 99.0:
		tide_card_pending = 0   # the room holds it
	else:
		tide_card_t = 99.0
func _play_fx(e: Dictionary) -> void:
	match e.id:
		"travel":
			# A new room. The old room's chatter, its feedback line and its timed sounds stay
			# behind; anything of the story still being said finishes.
			lines = lines.filter(func(l): return l.story)
			if not cur_story and cur_text != "":
				cur_text = ""
				subtitle.text = ""
			pending_sfx.clear()
			hover_id = ""
			arrived_at = time
			pending_glance = {}
			glance_t = 99.0
			came_from = str(e.get("from", ""))
			_mount_room(e.get("from", "") != "")
			# A tide card still waiting for the old room's reveal plays on arrival instead.
			if tide_card_pending > 0:
				_start_tide_card()
		"tide":
			# The card waits for the reveal that earned it (_tick_tide_card), after the room
			# has had the chance to take it over (_settle_card_offer).
			tide_card_pending = int(e.get("tide", sim.tide()))
			tide_card_n = tide_card_pending
			tide_card_t = 0.0
			tide_card_closeup = false
			card_offered = true
		"glance":
			pending_glance = e.duplicate()
		"item_added":
			_show_item_page(str(e.get("item", "")))
		_:
			if room_view:
				room_view.play_fx(e.id, e)

func _on_view_changed(before_game: String, before_room: String) -> void:
	var before := before_room
	if before_game != "room":
		before = before_game
	if before == "notebook" and room_sim() and room_sim().notebook_intrusion() != "":
		intrusion_written = true
	if sim.view == "notebook":
		intrusion_t = 0.0
		nb_page = -1
	if sim.view == "end":
		end_t = 0.0
	if room_view:
		room_view.on_view_changed(before)

## Dev/capture/tests: put the game at room `rid`'s local stage `n` (the room's own
## debug_jump), with clean presentation.
func room_jump(rid: String, n: int) -> void:
	var r: RoomSim = sim.room(rid)
	if r and r.has_method("debug_jump"):
		r.debug_jump(n)
	else:
		sim.reset()
		sim.debug_enter(rid)
	_mount_room()
	_reset_presentation()
	_save_progress()
	_redraw()

## Dev/capture/tests: the start of tide `t`, standing in `rid` (default the office).
func tide_jump(t: int, rid := "") -> void:
	sim.debug_tide(t, rid)
	_mount_room()
	_reset_presentation()
	_save_progress()
	_redraw()

## Dev/capture: go to `rid` ignoring gates, keeping progress.
func enter_jump(rid: String) -> void:
	sim.debug_enter(rid)
	_mount_room()
	_reset_presentation()
	_redraw()

## Clears everything timed so a restart or jump can't inherit old lines or sounds.
func _reset_presentation() -> void:
	lines.clear()
	cur_text = ""
	cur_story = false
	cur_hold = 0.0
	line_t = 0.0
	subtitle.text = ""
	shown_log.clear()
	played_log.clear()
	restart_armed_at = -INF
	pending_sfx.clear()
	for p in oneshots:
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	oneshots.clear()
	intrusion_written = false
	intrusion_t = 0.0
	tide_card_t = 99.0
	tide_card_pending = 0
	tide_card_closeup = false
	tide_card_closeup_rect = TIDE_CARD_CLOSEUP_RECT
	story_end = -INF
	arrived_at = -INF
	pending_glance = {}
	glance_t = 99.0
	glance_rect = Rect2()
	end_t = 0.0
	travel_dip_t = 99.0
	inv_page = 0
	nb_page = -1
	_mount_room()
	if room_view:
		room_view.reset_presentation()
		room_view.apply_instantly()

## The level a one-shot plays at, after the "Soften sudden sounds" cut. Rooms list their
## own levels (SFX_DB) and which sounds are sudden (SFX_SOFT) in their view.
func sfx_db(id: String) -> float:
	var table: Dictionary = room_view.c("SFX_DB", {}) if room_view else {}
	var db: float = table.get(id, SFX_DB.get(id, -6.0))
	if sim.settings.soft_audio and room_view and id in room_view.c("SFX_SOFT", []):
		var cut: Dictionary = room_view.c("SFX_SOFT_CUT", {})
		db -= cut.get(id, 12.0)
	return db

func _play_sfx_now(id: String) -> void:
	played_log.append([id, shown_log.size()])
	if room_view:
		room_view.on_sfx(id)
	var stream := load_audio(id)
	if stream == null:
		return
	# Voice cap: rapid repeats (pages, dials) never pile up more than VOICE_CAP copies.
	var same: Array = oneshots.filter(func(o): return is_instance_valid(o) and o.get_meta("sfx_id", "") == id)
	if same.size() >= VOICE_CAP:
		var oldest: AudioStreamPlayer = same[0]
		oneshots.erase(oldest)
		oldest.stop()
		oldest.queue_free()
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.set_meta("sfx_id", id)
	p.volume_db = sfx_db(id)
	if room_view:
		p.bus = room_view.sfx_bus(id)
	add_child(p)
	oneshots.append(p)
	p.finished.connect(func():
		oneshots.erase(p)
		p.queue_free())
	p.play()

## A sound by id: the current room's own (assets/audio/<rid>/<id>.wav) first, then the
## shared set (assets/audio/<id>.wav). Missing files are skipped silently.
func load_audio(id: String) -> AudioStream:
	for path in ["res://assets/audio/%s/%s.wav" % [sim.state.room, id], "res://assets/audio/%s.wav" % id]:
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null

## True while a live one-shot is playing one of `ids`.
func oneshot_playing(ids: Array) -> bool:
	for p in oneshots:
		if is_instance_valid(p) and p.playing and p.get_meta("sfx_id", "") in ids:
			return true
	return false

func sfx_pending(id: String) -> bool:
	for p in pending_sfx:
		if p[0] == id:
			return true
	return false

func _redraw() -> void:
	if room_view:
		room_view.redraw()
	over.queue_redraw()
	card.queue_redraw()
	hud.queue_redraw()

# ---------------------------------------------------------------------------
# input
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		var id := _hover_at(get_global_mouse_position())
		if id != hover_id:
			hover_id = id
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if id != "" else Input.CURSOR_ARROW)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if sim.view == "title":
					dispatch("menu")
				elif sim.view == "room":
					var esc := room_view.esc_action() if room_view else "menu"
					if always_acts(esc) and _chain_gates() and chain_active():
						advance()   # Back is one press: the line finishes and she steps back
					if esc != "":
						dispatch(esc)
				elif sim.view in ["notebook", "menu"]:
					if _chain_gates() and chain_active():
						advance()
					dispatch("back")
			KEY_N:
				if not _cinematic():
					dispatch("notebook")
			KEY_H:
				if not _cinematic():
					dispatch("hint")
			KEY_F1:
				if OS.is_debug_build():
					dev = not dev
					_redraw()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				if dev and OS.is_debug_build():
					var n: int = event.keycode - KEY_1
					if event.shift_pressed:
						tide_jump(n + 1)          # Shift+1..9: start of tide I..IX
					else:
						room_jump(sim.state.room, n)   # 1..9: the room's own stages 0..8

func _hover_at(p: Vector2) -> String:
	if sim.view != "room" or room_view == null:
		return ""
	if sim.state.started and _hud_shown():
		for slot in _inv_layout():
			if slot[0].has_point(p):
				return slot[1]
	var ex := _exit_at(p)
	if ex != "":
		return ex
	var id := room_view.hover_at(p)
	# In a close-up only its own controls name themselves: a room hotspot's label never
	# hangs over the close-up.
	if id != "" and room_sim().is_closeup() and room_view.action_at(p) != id:
		return ""
	return id

## The exit under `p` as "go:<rid>", when the room is showing itself.
func _exit_at(p: Vector2) -> String:
	if room_view == null or room_sim().is_closeup() or not room_view.exits_active():
		return ""
	var rects: Dictionary = room_view.live_exit_rects()
	for e in sim.exits():
		if rects.has(e[0]) and rects[e[0]].has_point(p):
			return "go:" + e[0]
	return ""

## Maps a screen point to an action for the current view. "" = nothing.
func action_at(p: Vector2) -> String:
	var a := _core_action_at(p)
	if a == "" and _room_takes_click():
		return room_view.action_at(p)
	return a

## A point the core resolved to nothing goes to the room (its hotspots and close-ups).
func _room_takes_click() -> bool:
	return sim.view == "room" and room_view != null

## Everything the core answers itself: the title, end card and menu, the HUD, the
## inventory, the notebook, Back and the exits. "" leaves the point to the room.
func _core_action_at(p: Vector2) -> String:
	match sim.view:
		"title":
			return "begin"
		"end":
			if end_t < 1.5:
				return ""
			for b in END_BUTTONS:
				if b[1].has_point(p) and (b[0] != "return_decision" or not sim.checkpoint.is_empty()):
					return b[0]
			return ""
		"menu":
			var items := ["resume", "toggle_motion", "toggle_soft", "restart" if _restart_armed() else "restart_arm"]
			for i in items.size():
				if _menu_rect(i).has_point(p):
					return items[i]
			return ""
	if sim.state.started and _hud_shown():
		for b in HUD_BUTTONS:
			if b[1].has_point(p):
				return b[0]
		if sim.view == "room":
			for slot in _inv_layout():
				if slot[0].has_point(p):
					return slot[1]
	if sim.view == "notebook":
		if BACK_RECT.has_point(p):
			return "back"
		for b in _nb_page_buttons():
			if b[0].has_point(p):
				return b[1]
		for t in _notebook_tabs():
			if t[1].has_point(p):
				return "tab:" + t[0]
		if _nb_page() == "plan":
			for row in _plan_rows():
				if row[2] and row[1].has_point(p):
					return "plan:" + row[0]
		return ""
	if sim.view != "room" or room_view == null:
		return ""
	if room_view.back_visible() and BACK_RECT.has_point(p):
		return "back"
	return _exit_at(p)

func _hud_shown() -> bool:
	return sim.view == "notebook" or (sim.view == "room" and (room_view == null or not room_view.hud_hidden()))

## Slot `i` of the bar: the layout's rect when it has one, else where slot i would be.
func _inv_rect(i: int) -> Rect2:
	var layout := _inv_layout()
	return layout[i][0] if i < layout.size() else _slot_rect(i)

static func _slot_rect(i: int) -> Rect2:
	return Rect2(INV_ORIGIN + Vector2(i * (INV_SLOT.x + INV_GAP), 0), INV_SLOT)

## The inventory bar, shared by hit-testing, hover and drawing: [rect, action] per
## slot. Up to INV_MAX items show as they are; more go five to a page with a pager in the
## sixth slot ("inv_page").
func _inv_layout() -> Array:
	var inv: Array = sim.state.inventory
	var out := []
	if inv.size() <= INV_MAX:
		for i in inv.size():
			out.append([_slot_rect(i), "item:" + inv[i]])
		return out
	var page := _inv_page_shown()
	for k in INV_PER_PAGE:
		var i := page * INV_PER_PAGE + k
		if i >= inv.size():
			break
		out.append([_slot_rect(k), "item:" + inv[i]])
	out.append([_slot_rect(INV_PER_PAGE), "inv_page"])
	return out

func _inv_pages() -> int:
	var n: int = sim.state.inventory.size()
	return 1 if n <= INV_MAX else ceili(float(n) / INV_PER_PAGE)

## The page on show: inv_page, kept in range as items are used up.
func _inv_page_shown() -> int:
	return clampi(inv_page, 0, _inv_pages() - 1)

## The bar changed size (an item used up): stay in range, and on the item in her hand.
func _keep_inv_page() -> void:
	var n: int = sim.state.inventory.size()
	if n == seen_inv_size:
		return
	seen_inv_size = n
	inv_page = _inv_page_shown()
	if sim.selected_item != "":
		_show_item_page(sim.selected_item)

func _show_item_page(item: String) -> void:
	var i: int = sim.state.inventory.find(item)
	if i >= 0 and _inv_pages() > 1:
		inv_page = i / INV_PER_PAGE

func _restart_armed() -> bool:
	return time - restart_armed_at < RESTART_ARM

func _menu_rect(i: int) -> Rect2:
	return Rect2(474, 330 + i * 100, 500, 76)

# ---------------------------------------------------------------------------
# drawing: title, menu, notebook, end (over layer)
# ---------------------------------------------------------------------------
func _draw_over() -> void:
	var c := over
	match sim.view:
		"title":
			_draw_title(c)
		"menu":
			_draw_menu(c)
		"notebook":
			_draw_notebook(c)
		"end":
			_draw_end(c)
	# Between rooms: a short dip through storm navy (Motion on only).
	if travel_dip_t < TRAVEL_DIP and sim.settings.motion:
		c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(TRAVEL_DIP_COLOR, 1.0 - travel_dip_t / TRAVEL_DIP))

func _draw_title(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Ink.BLACK)
	var pulse := 0.55 + 0.45 * sin(time * 1.6) if sim.settings.motion else 1.0
	Ink.text(c, "THE NINTH TIDE", Vector2(0, 470), 78, Ink.PAPER, serif, SIZE.x)
	Ink.text(c, sim.tide_title(), Vector2(0, 540), 30, Color(Ink.PAPER, 0.7), hand, SIZE.x)
	Ink.text(c, "Greywake Survey Station, Morrow Sound. October 1931.", Vector2(0, 640), 24,
		Color(Ink.PAPER, 0.5), serif, SIZE.x)
	Ink.text(c, "click to begin", Vector2(0, 820), 24, Color(Ink.GOLD, pulse), serif, SIZE.x)
	Ink.text(c, "Headphones recommended. Esc for options.", Vector2(0, 1040), 18,
		Color(Ink.PAPER, 0.35), serif, SIZE.x)

func _draw_menu(c: Node2D) -> void:
	if sim.return_view == "title":
		c.draw_rect(Rect2(Vector2.ZERO, SIZE), Ink.BLACK)   # nothing of the room before the opening
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(Ink.INK, 0.93))
	Ink.text(c, "Paused" if sim.return_view != "title" else "Options", Vector2(0, 260), 40, Ink.PAPER, serif, SIZE.x)
	var labels := ["Resume", "Motion & flicker: " + ("on" if sim.settings.motion else "off"),
		"Soften sudden sounds: " + ("on" if sim.settings.soft_audio else "off"),
		"Restart? Click again" if _restart_armed() else "New game"]
	for i in labels.size():
		Ink.button(c, _menu_rect(i), labels[i])

## The notebook's pages: the plan (after P05), then each visited room, current first.
func _notebook_tabs() -> Array:
	var ids: Array = [sim.state.room]
	for rid in sim.state.visited:
		if not rid in ids:
			ids.append(rid)
	if sim.flag("P05"):
		ids.append("plan")
	var out := []
	var x := NOTEBOOK_PAGE.position.x + 40.0
	for rid in ids:
		var label: String = "Plan" if rid == "plan" else rid
		var w := maxf(64.0, serif.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 24.0)
		out.append([rid, Rect2(x, NOTEBOOK_PAGE.position.y - 2, w, 64), label])
		x += w + 6.0
	return out

func _nb_page() -> String:
	if sim.nb_tab == "plan" and sim.flag("P05"):
		return "plan"
	if sim.nb_tab != "" and sim.rooms.has(sim.nb_tab) and (sim.nb_tab in sim.state.visited):
		return sim.nb_tab
	return sim.state.room

## [rid, rect, can_travel] for each visited room on the plan page.
func _plan_rows() -> Array:
	var out := []
	var reach := sim.reachable()
	var i := 0
	for rid in sim.order:
		if not rid in sim.state.visited:
			continue
		var ok: bool = rid != sim.state.room and rid in reach
		# Two columns of six, so all twelve rooms fit on the page.
		var x := NOTEBOOK_PAGE.position.x + 60.0 + (i / 6) * 520.0
		var y := NOTEBOOK_PAGE.position.y + 190.0 + (i % 6) * 76.0
		out.append([rid, Rect2(x, y, 480, 64), ok])
		i += 1
	return out

func _draw_notebook(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(Ink.INK, 0.97))
	var page := NOTEBOOK_PAGE
	c.draw_rect(page, Color("e4dcc4"))
	var cur := _nb_page()
	for t in _notebook_tabs():
		var on: bool = t[0] == cur
		c.draw_rect(Rect2(t[1].position, Vector2(t[1].size.x, 30)), Color("e4dcc4") if on else Color("b9b099"))
		Ink.text(c, t[2], t[1].position + Vector2(0, 22), 18, Color(Ink.INK, 1.0 if on else 0.6), serif, t[1].size.x)
	if cur == "plan":
		_draw_plan(c, page)
		return
	var r: RoomSim = sim.room(cur)
	var obs: Dictionary = r.c("OBSERVATIONS", {})
	var nb := _nb_pagination(cur)
	var pager := _nb_page_buttons()
	var noted_right := page.size.x - 50.0
	if not pager.is_empty():
		var first: Rect2 = pager[0][0]
		noted_right = first.position.x - page.position.x - 14.0
		for b in pager:
			var off: bool = (b[1] == "nbpage:prev" and nb.shown == 0) or \
				(b[1] == "nbpage:next" and nb.shown == nb.pages.size() - 1)
			Ink.button(c, b[0], "◂" if b[1] == "nbpage:prev" else "▸", false, 20, off)
		var mid := Rect2(first.end.x, first.position.y, pager[1][0].position.x - first.end.x, first.size.y)
		Ink.text(c, "p %d/%d" % [nb.shown + 1, nb.pages.size()], Vector2(mid.position.x, mid.position.y + 27), 20,
			Color(Ink.INK, 0.75), serif, mid.size.x)
	Ink.text(c, "NOTEBOOK — A. MERCER  ·  " + str(r.c("TITLE", cur)).to_upper(), page.position + Vector2(50, 64), 26,
		Ink.INK, serif, 900, HORIZONTAL_ALIGNMENT_LEFT)
	Ink.text(c, "Noted %d of %d" % [r.seen().size(), obs.size()],
		page.position + Vector2(0, 64), 20, Color(Ink.INK, 0.5), serif, noted_right, HORIZONTAL_ALIGNMENT_RIGHT)
	if cur == sim.state.room:
		Ink.text(c, "Now: " + sim.objective_text(), page.position + Vector2(50, 112), 24,
			Color("5b3a2e"), hand, 1000, HORIZONTAL_ALIGNMENT_LEFT)
	if nb.pages.is_empty():
		Ink.text(c, "Nothing recorded yet. Look around.", Vector2(page.position.x + 80, nb.top), 22,
			Color(Ink.INK, 0.6), hand, 900, HORIZONTAL_ALIGNMENT_LEFT)
		return
	var last: bool = nb.shown == nb.pages.size() - 1
	var flow := _notebook_flow(c, obs, nb.pages[nb.shown], nb.layout, nb.top,
		nb.bottom - (nb.room_for if last else 0.0), page.position.x, true)
	if nb.intrusion == "" or not last:
		return
	# A line she did not write, in her hand, straight after her last entry (its room is kept).
	var intrusion: String = nb.intrusion
	var n := intrusion.length()
	if _intrusion_writing():
		n = mini(n, int(intrusion_t * REVEAL_CPS * 0.45))
	var size: int = nb.layout[0]
	var pos: Vector2 = flow.next + Vector2(20, 8 - size * 0.45)
	var w := hand.get_string_size(intrusion, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	pos.x = minf(pos.x, page.end.x - 30 - w)
	Ink.handwriting(c, intrusion, n, pos, 22, 300, _intrusion_writing())

## How room `rid`'s notebook page lays out: {layout, pages (arrays of observation ids), shown,
## top, bottom, room_for, intrusion}. The roomiest layout that holds every entry; past the
## smallest ([17, 460, 2]) the entries run onto more pages, the stranger's line keeping its
## room on the last. Cached: it measures text.
func _nb_pagination(rid: String) -> Dictionary:
	var r: RoomSim = sim.room(rid)
	var obs: Dictionary = r.c("OBSERVATIONS", {}) if r else {}
	var ids := []
	for id in obs:
		if r.has_seen(id):
			ids.append(id)
	var intrusion := r.notebook_intrusion() if r and rid == sim.state.room else ""
	var key := [rid, ids, intrusion]
	var info: Dictionary
	if nb_cache.get("key") == key:
		info = nb_cache.info
	else:
		info = _nb_paginate(obs, ids, intrusion)
		nb_cache = {"key": key, "info": info}
	var pages: Array = info.pages
	var shown := 0
	if nb_page >= 0:
		shown = clampi(nb_page, 0, maxi(pages.size() - 1, 0))
	elif r and not r.seen().is_empty():
		# The page with the newest entry.
		var newest: String = r.seen()[-1]
		for i in pages.size():
			if newest in pages[i]:
				shown = i
	info = info.duplicate()
	info["shown"] = shown
	return info

func _nb_paginate(obs: Dictionary, ids: Array, intrusion: String) -> Dictionary:
	var page := NOTEBOOK_PAGE
	var top := page.position.y + 180
	var bottom := page.end.y - 24
	var room_for := NB_INTRUSION_ROOM if intrusion != "" else 0.0
	var out := {"top": top, "bottom": bottom, "room_for": room_for, "intrusion": intrusion,
		"layout": NB_LAYOUTS[0], "pages": []}
	if ids.is_empty():
		return out
	for opt in NB_LAYOUTS:
		out.layout = opt
		if _notebook_flow(over, obs, ids, opt, top, bottom - room_for, page.position.x, false).fits:
			out.pages = [ids.duplicate()]
			return out
	# Too many for one page: fill each page as far as it goes.
	var pages := []
	var cur := []
	for id in ids:
		var trial := cur.duplicate()
		trial.append(id)
		if cur.is_empty() or _notebook_flow(over, obs, trial, out.layout, top, bottom, page.position.x, false).fits:
			cur = trial
		else:
			pages.append(cur)
			cur = [id]
	pages.append(cur)
	# The last page keeps the stranger's line its room.
	var spill := []
	while pages[-1].size() > 1 and not _notebook_flow(over, obs, pages[-1], out.layout, top, bottom - room_for,
			page.position.x, false).fits:
		spill.push_front(pages[-1].pop_back())
	if not spill.is_empty():
		pages.append(spill)
	out.pages = pages
	return out

## The notebook's page turners, [rect, action], when a room's entries need more than one page.
func _nb_page_buttons() -> Array:
	if sim.view != "notebook":
		return []
	var cur := _nb_page()
	if cur == "plan" or _nb_pagination(cur).pages.size() < 2:
		return []
	var y := NOTEBOOK_PAGE.position.y + 38
	var right := NOTEBOOK_PAGE.end.x - 50
	return [[Rect2(right - 44 - 84 - 44, y, 44, 40), "nbpage:prev"], [Rect2(right - 44, y, 44, 40), "nbpage:next"]]

func _draw_plan(c: Node2D, page: Rect2) -> void:
	Ink.text(c, "STATION PLAN", page.position + Vector2(50, 64), 26, Ink.INK, serif, 900, HORIZONTAL_ALIGNMENT_LEFT)
	Ink.text(c, "Rooms I have been in. Where the way is open, I can go straight there.",
		page.position + Vector2(50, 112), 22, Color("5b3a2e"), hand, 1000, HORIZONTAL_ALIGNMENT_LEFT)
	for row in _plan_rows():
		var r: RoomSim = sim.room(row[0])
		var here: bool = row[0] == sim.state.room
		var label: String = "%s  %s%s" % [row[0], r.c("TITLE", ""), "  (here)" if here else ""]
		Ink.button(c, row[1], label, here, 22, not row[2] and not here)

## The stranger line writes itself once, slowly, the first time the notebook opens after
## the room makes one. Motion off: it is simply there.
func _intrusion_writing() -> bool:
	var r := room_sim()
	if r == null or sim.view != "notebook" or not sim.settings.motion or intrusion_written:
		return false
	var s := r.notebook_intrusion()
	return s != "" and intrusion_t * REVEAL_CPS * 0.45 < s.length()

## Lays out notebook entries in columns. Returns {fits, next, rects}: rects is [id, Rect2]
## per entry (bullet to the end of its last line), for tests and drivers.
func _notebook_flow(c: CanvasItem, obs: Dictionary, ids: Array, layout: Array, top: float, bottom: float,
		left: float, draw: bool) -> Dictionary:
	var size: int = layout[0]
	var width: float = layout[1]
	var columns: int = layout[2]
	var col := 0
	var y := top
	var x := left + 60
	var rects := []
	for id in ids:
		var h := Ink.wrapped(c, obs[id], Vector2(0, 0), size, Ink.INK, width, false)
		if y + h - size > bottom and col + 1 < columns:
			col += 1
			y = top
		x = left + 60 + col * (width + 60)
		if draw:
			c.draw_circle(Vector2(x, y - size * 0.36), 4, Color(Ink.INK, 0.6))
			Ink.wrapped(c, obs[id], Vector2(x + 20, y), size, Ink.INK, width)
		rects.append([id, Rect2(x - 6, y - size, width + 26, h)])
		y += h + size * 0.45
	return {"fits": y - size * 1.9 <= bottom, "next": Vector2(x, y), "rects": rects}

func _draw_end(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Ink.BLACK)
	var e: Dictionary = GameSim.ENDINGS.get(sim.state.ending, {"title": "", "lines": []})
	var a := clampf(end_t / 2.0, 0.0, 1.0) if sim.settings.motion else 1.0
	Ink.text(c, e.title, Vector2(0, 420), 48, Color(Ink.PAPER, a), serif, SIZE.x)
	for i in e.lines.size():
		Ink.text(c, e.lines[i], Vector2(0, 520 + 50 * i), 26, Color(Ink.NIGHT_INK, a), hand, SIZE.x)
	Ink.text(c, "Endings seen: %d of 2" % sim.settings.endings_seen.size(), Vector2(0, 780), 20,
		Color(Ink.PAPER, 0.5 * a), serif, SIZE.x)
	if end_t >= 1.5:
		for b in END_BUTTONS:
			if b[0] == "return_decision" and sim.checkpoint.is_empty():
				continue
			Ink.button(c, b[1], b[2])

## The tide card: high on the screen, clear of the room's reveal below it. Fades in and out
## over TIDE_CARD_TIME; Motion off, it is simply there for TIDE_CARD_STILL.
func tide_card_alpha() -> float:
	if tide_card_n <= 0:
		return 0.0
	if not sim.settings.motion:
		return 1.0 if tide_card_t < TIDE_CARD_STILL else 0.0
	if tide_card_t >= TIDE_CARD_TIME:
		return 0.0
	return clampf(minf(tide_card_t, TIDE_CARD_TIME - tide_card_t) / TIDE_CARD_FADE, 0.0, 1.0)

const TIDE_CARD_RECT := Rect2(324, 120, 800, 110)

## Where the card on show sits: high on the room, or low (above the subtitles, a little
## lighter) when it started over a close-up, so it never covers the close-up's controls.
func tide_card_rect() -> Rect2:
	return tide_card_closeup_rect if tide_card_closeup else TIDE_CARD_RECT

func _draw_card() -> void:
	var a := tide_card_alpha()
	if a <= 0.0:
		return
	if tide_card_closeup:
		a *= TIDE_CARD_CLOSEUP_ALPHA
	var r := tide_card_rect()
	card.draw_rect(r, Color(Ink.INK, 0.88 * a))
	card.draw_rect(r, Color(Ink.BRASS, 0.8 * a), false, 2)
	var slim := r.size.y < TIDE_CARD_RECT.size.y
	Ink.text(card, "TIDE " + GameSim.NUMERALS[tide_card_n - 1], r.position + Vector2(0, 38 if slim else 48),
		30 if slim else 36, Color(Ink.PAPER, a), serif, r.size.x)
	Ink.text(card, GameSim.TIDE_TITLES[tide_card_n - 1], r.position + Vector2(0, 70 if slim else 90),
		22 if slim else 26, Color(Ink.PAPER, 0.8 * a), hand, r.size.x)

# ---------------------------------------------------------------------------
# drawing: HUD
# ---------------------------------------------------------------------------
func _draw_hud() -> void:
	var c := hud
	if sim.view in ["title", "end", "menu"] or (sim.view == "room" and room_view and room_view.hud_hidden()):
		subtitle.visible = false
		return
	subtitle.visible = true
	if slab_a > 0.0:
		c.draw_rect(Rect2(20, 994, 1408, 80), Color(0.03, 0.06, 0.08, 0.9 * slab_a))
	if chain_active() and _chain_gates():
		# More to come: a click brings the next line up.
		var pulse := 0.75 + 0.25 * sin(time * 2.0) if sim.settings.motion else 1.0
		c.draw_string(serif, Vector2(1392, 1040), "▸", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Ink.PAPER, 0.55 * pulse))
	for b in HUD_BUTTONS:
		Ink.button(c, b[1], b[2], false, 21)
	if sim.view == "notebook":
		Ink.button(c, BACK_RECT, "Back", false, 21)
		return
	if room_view and room_view.back_visible():
		Ink.button(c, BACK_RECT, room_view.back_label(), false, 21)
	_draw_glance(c)
	_draw_inventory(c)
	_draw_exits(c)
	if room_view:
		room_view.draw_hud(c)
	if hover_id != "" and sim.view == "room":
		var label := _hover_label(hover_id)
		var box := hover_label_rect(hover_id, get_global_mouse_position())
		if label != "" and box.size != Vector2.ZERO:
			c.draw_rect(box, Color(0.03, 0.06, 0.08, 0.8))
			c.draw_string(serif, box.position + Vector2(10, 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, HOVER_SIZE, Ink.PAPER)
	if sim.selected_item != "":
		var name: String = sim.item_defs().get(sim.selected_item, {}).get("name", sim.selected_item)
		var p := get_global_mouse_position() + Vector2(22, -14)
		c.draw_string(hand, p, "using " + name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Ink.GOLD)
	if dev:
		_draw_dev(c)

## The hover label's box for `id` with the pointer at `mouse` (pure: drawing and tests).
## Small room hotspots and exits: beside the pointer. A close-up control, or anything
## taller than HOVER_TALL: just above its rect, else just below it, else in the row above
## the subtitles, so the label never covers the clue it names. Always on screen.
func hover_label_rect(id: String, mouse: Vector2) -> Rect2:
	var label := _hover_label(id)
	if label == "":
		return Rect2()
	var w := serif.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, HOVER_SIZE).x + 20.0
	var target := hover_target_rect(id)
	var closeup: bool = room_sim() != null and room_sim().is_closeup()
	var box: Rect2
	if target.size != Vector2.ZERO and (closeup or target.size.y > HOVER_TALL):
		# Text baseline at (x, y); the box runs 24 above it to 10 below.
		box = _hover_box(Vector2(target.position.x, target.position.y - 10.0), w)
		if box.position.y < 0.0:
			box = _hover_box(Vector2(target.position.x, target.end.y + 34.0), w)
		if box.end.y > SIZE.y or box.intersects(target):
			box = _hover_box(Vector2(target.position.x, HOVER_BAR_Y), w)
	else:
		box = _hover_box(mouse + Vector2(22, 34), w)
	box.position.x = clampf(box.position.x, HOVER_MARGIN, SIZE.x - w - HOVER_MARGIN)
	box.position.y = clampf(box.position.y, 0.0, SIZE.y - HOVER_H)
	return box

static func _hover_box(baseline: Vector2, w: float) -> Rect2:
	return Rect2(baseline - Vector2(10, 24), Vector2(w, HOVER_H))

## The rect of what `id` names: an exit tab, an inventory slot, or the room's hotspot or
## close-up control (RoomView.control_rect). Rect2() when unknown.
func hover_target_rect(id: String) -> Rect2:
	if room_view == null:
		return Rect2()
	if id.begins_with("go:"):
		return room_view.live_exit_rects().get(id.substr(3), Rect2())
	if id.begins_with("item:") or id == "inv_page":
		for slot in _inv_layout():
			if slot[1] == id:
				return slot[0]
		return Rect2()
	return room_view.control_rect(id)

func _hover_label(id: String) -> String:
	if id.begins_with("go:"):
		var to := id.substr(3)
		for e in sim.exits():
			if e[0] == to:
				if not sim.exit_open(sim.state.room, to):
					return "%s (locked)" % e[1]
				return "%s ▸" % _exit_text(to, e[1])
		return ""
	if id.begins_with("item:"):
		var item := id.substr(5)
		return sim.item_defs().get(item, {}).get("name", item)   # the full name; the slot shows the short one
	if id == "inv_page":
		return "More of what I'm carrying"
	return room_view.label_for(id) if room_view else ""

func _draw_inventory(c: Node2D) -> void:
	if sim.view != "room":
		return
	var defs := sim.item_defs()
	for slot in _inv_layout():
		var a: String = slot[1]
		if a == "inv_page":
			Ink.button(c, slot[0], "▸ %d/%d" % [_inv_page_shown() + 1, _inv_pages()], false, 18)
			continue
		var id := a.substr(5)
		var d: Dictionary = defs.get(id, {})
		Ink.button(c, slot[0], d.get("short", d.get("name", id)), id == sim.selected_item, 18)

## Exit tabs: a plaque per way out, arrowed toward the side it leaves by, dimmed while
## locked. On the HUD layer, so no room lighting can hide them.
func _draw_exits(c: Node2D) -> void:
	if sim.view != "room" or room_view == null or room_sim().is_closeup() or not room_view.exits_active():
		return
	var rects: Dictionary = room_view.live_exit_rects()
	for e in sim.exits():
		if not rects.has(e[0]):
			continue
		var r: Rect2 = rects[e[0]]
		var open := sim.exit_open(sim.state.room, e[0])
		# Locked, or a room not built yet: dimmed (an unbuilt room's tab still answers).
		Ink.button(c, r, exit_tab_label(e[0]), hover_id == "go:" + e[0], 19, not open or sim.is_unbuilt(e[0]))

## The text on the tab of the exit to `to`: its name (marked when the room beyond is not
## built yet), arrowed the way the room says (RoomView.exit_arrow), else toward the side of
## the screen the tab sits on.
func exit_tab_label(to: String) -> String:
	var name := ""
	for e in sim.exits():
		if e[0] == to:
			name = e[1]
	var text := _exit_text(to, name)
	var side: String = room_view.exit_arrow(to) if room_view else ""
	if side == "":
		var r: Rect2 = room_view.live_exit_rects().get(to, room_view.exit_rects().get(to, Rect2())) if room_view else Rect2()
		side = "left" if r.get_center().x < SIZE.x / 2.0 else "right"
	match side:
		"left":
			return "◂ " + text
		"down":
			return "▾ " + text
	return text + " ▸"

## An exit's name, marked when the room beyond is not built yet.
func _exit_text(to: String, label: String) -> String:
	return label + " (not yet built)" if sim.is_unbuilt(to) else label

## Four storm-navy corner brackets round the glance rect (a room without its own glance).
func _draw_glance(c: Node2D) -> void:
	var a := glance_alpha()
	if a <= 0.0 or sim.view != "room":
		return
	var out := (1.0 - a) * 24.0 if sim.settings.motion else 0.0   # they close in as they ease in
	var r := glance_rect.grow(6.0 + out)
	var arm := minf(GLANCE_ARM, minf(r.size.x, r.size.y) * 0.5)
	var halo := Color(Ink.PAPER, 0.55 * a)
	var navy := Color(Ink.STORM, a)
	for k in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
			[Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		var p: Vector2 = k[0]
		var d: Vector2 = k[1]
		for pass_n in 2:
			var col := halo if pass_n == 0 else navy
			var wdt := GLANCE_THICK + 4.0 if pass_n == 0 else GLANCE_THICK
			var h := wdt * 0.5   # square corners: each arm runs half a stroke past the corner
			c.draw_line(p - Vector2(d.x * h, 0), p + Vector2(d.x * arm, 0), col, wdt)
			c.draw_line(p - Vector2(0, d.y * h), p + Vector2(0, d.y * arm), col, wdt)

func _draw_dev(c: Node2D) -> void:
	c.draw_rect(Rect2(20, 90, 620, 190), Color(0, 0, 0, 0.75))
	var y := 120
	for line in ["DEV (F1)  %s  view %s/%s  tide %d  weather %d" % [sim.state.room, sim.view,
				room_sim().local_view if room_sim() else "-", sim.tide(), sim.weather_band()],
			"1-9 room stage jumps, Shift+1-9 start of tide I-IX",
			"objective: " + (room_sim().objective() if room_sim() else ""),
			"flags: " + ", ".join(sim.state.flags.keys())]:
		c.draw_string(serif, Vector2(34, y), line, HORIZONTAL_ALIGNMENT_LEFT, 600, 18, Color.WHITE)
		y += 34
	if room_view:
		for r in room_view.dev_rects():
			c.draw_rect(r, Color(1, 0, 1, 0.6), false, 2)
		for r in room_view.live_exit_rects().values():
			c.draw_rect(r, Color(0, 1, 1, 0.6), false, 2)
