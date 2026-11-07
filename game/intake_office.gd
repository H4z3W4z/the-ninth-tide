extends Node2D
## Intake Office slice: renders an OfficeSim, plays its events, owns light and sound.
##
## Layering:
##   world (affected by CanvasModulate + 2D lights): room plate, lamp, overlays
##   CanvasLayer 5  "close": close-ups and documents (always fully readable)
##   CanvasLayer 10 "hud":   subtitles, buttons, hover name, flash
## All state lives in `sim`; this script only presents it.

const SIZE := Vector2(1448, 1086)
const DEFAULT_SAVE_PATH := "user://intake_office_v2.json"
const PAPER := Color("ded4ba")
const INK := Color("172b36")
const GOLD := Color("d2aa66")
const AMBER := Color("c39959")
const BRUISE := Color("746577")

## Ambient modulate per story stage (0 arrival .. 3 seat wet).
const MODULATE := [Color(0.30, 0.33, 0.42), Color(0.50, 0.48, 0.50),
	Color(0.40, 0.40, 0.47), Color(0.33, 0.32, 0.40)]

## Room hotspots. First match wins, so small objects precede large ones.
const HOTSPOTS := [
	["mug", Rect2(915, 662, 82, 62), "Mug"],
	["tray", Rect2(341, 666, 128, 64), "Spares tray"],
	["lamp", Rect2(242, 469, 192, 260), "Desk lamp"],
	["logbook", Rect2(500, 684, 205, 44), "Tide log"],
	["papers", Rect2(738, 622, 165, 104), "Duty papers"],
	["chair", Rect2(553, 618, 180, 66), "Chair"],
	["puddle", Rect2(1050, 880, 135, 70), "Puddle"],
	["hooks", Rect2(852, 250, 322, 80), "Coat hooks"],
	["coat", Rect2(1025, 300, 115, 540), "Coat"],
	["map", Rect2(126, 178, 266, 290), "Survey chart"],
	["stove", Rect2(5, 610, 160, 310), "Stove"],
	["window", Rect2(428, 82, 430, 515), "Window"],
	["door", Rect2(1188, 128, 255, 780), "Corridor door"],
]

## HUD buttons (screen space, drawn on the HUD layer).
const HUD_BUTTONS := [
	["notebook", Rect2(1112, 22, 150, 50), "Notebook"],
	["hint", Rect2(1272, 22, 86, 50), "Hint"],
	["menu", Rect2(1368, 22, 58, 50), "≡"],
]
const BACK_RECT := Rect2(1180, 75, 185, 64)

var save_path := DEFAULT_SAVE_PATH
var sim := OfficeSim.new()
var textures := {}
var serif: SystemFont
var hand: SystemFont

# nodes
var room: Node2D
var close: Node2D
var hud: Node2D
var shade: CanvasModulate
var torch: PointLight2D
var lamp_glow: PointLight2D
var subtitle: Label
var flash: ColorRect

# presentation state (never saved)
var lines: Array = []          # queued [text, delay]
var line_t := 0.0
var line_hold := 0.0
var hover_id := ""
var torch_dead := 0.0          # seconds of blackout left after a spark
var rng := RandomNumberGenerator.new()
var time := 0.0
var players := {}              # loop id -> AudioStreamPlayer
var mix := {}                  # loop id -> current linear volume
var pending_sfx: Array = []    # [id, time_left]
var prints_fade := 1.0
var dev := false

func _ready() -> void:
	rng.seed = 9
	_load_textures()
	_build_fonts()
	_build_nodes()
	_build_audio()
	_load_progress()
	_apply_stage_instantly()
	_redraw()

# ---------------------------------------------------------------------------
# setup
# ---------------------------------------------------------------------------
func _load_textures() -> void:
	var f := FileAccess.open("res://asset_manifest.json", FileAccess.READ)
	var manifest = JSON.parse_string(f.get_as_text())
	for asset in manifest.assets:
		if asset.path.ends_with(".png"):
			textures[asset.id] = load("res://" + asset.path)

func _build_fonts() -> void:
	var names := PackedStringArray(["Noto Serif", "DejaVu Serif", "Liberation Serif", "serif"])
	serif = SystemFont.new()
	serif.font_names = names
	hand = SystemFont.new()
	hand.font_names = names
	hand.font_italic = true

func _radial(size: int, soft: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(soft, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t

func _build_nodes() -> void:
	room = Node2D.new()
	room.name = "Room"
	add_child(room)
	room.draw.connect(_draw_room)

	shade = CanvasModulate.new()
	shade.color = MODULATE[0]
	add_child(shade)

	lamp_glow = PointLight2D.new()
	lamp_glow.texture = _radial(512, 0.35)
	lamp_glow.texture_scale = 3.2
	lamp_glow.color = AMBER.lightened(0.15)
	lamp_glow.energy = 0.0
	lamp_glow.position = Vector2(338, 545)
	add_child(lamp_glow)

	torch = PointLight2D.new()
	torch.texture = _radial(512, 0.25)
	torch.texture_scale = 0.95
	torch.color = Color(1.0, 0.94, 0.82)
	torch.energy = 1.15
	add_child(torch)

	var close_layer := CanvasLayer.new()
	close_layer.layer = 5
	add_child(close_layer)
	close = Node2D.new()
	close_layer.add_child(close)
	close.draw.connect(_draw_close)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = SIZE
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(flash)
	hud = Node2D.new()
	hud_layer.add_child(hud)
	hud.draw.connect(_draw_hud)
	subtitle = Label.new()
	subtitle.position = Vector2(48, 1004)
	subtitle.size = Vector2(1352, 64)
	subtitle.add_theme_font_override("font", serif)
	subtitle.add_theme_font_size_override("font_size", 27)
	subtitle.add_theme_color_override("font_color", PAPER)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.visible_ratio = 1.0
	hud_layer.add_child(subtitle)

func _build_audio() -> void:
	var levels := {"room": 0.0, "sea": 0.0, "wind": 0.0, "drip": 0.0, "hum": 0.0,
		"drone": 0.0, "heartbeat": 0.0}
	for id in levels:
		var stream := load("res://assets/audio/%s.wav" % id) as AudioStreamWAV
		if stream == null:
			continue
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = -80.0
		add_child(p)
		p.play()
		players[id] = p
		mix[id] = 0.0

# ---------------------------------------------------------------------------
# persistence
# ---------------------------------------------------------------------------
func _load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f and sim.from_dict(JSON.parse_string(f.get_as_text())):
		if sim.state.started and not sim.state.finished:
			_queue_line("Back in the office. " + OfficeSim.OBJECTIVES[sim.objective()], 0.3)

func _save_progress() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(sim.to_dict()))

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------
func _process(dt: float) -> void:
	time += dt
	_tick_lines(dt)
	_tick_sfx(dt)
	_tick_light(dt)
	_tick_audio(dt)
	if sim.state.motion and sim.view == "room":
		room.queue_redraw()
	hud.queue_redraw()
	if sim.view in ["title", "end"]:
		close.queue_redraw()

func _tick_light(dt: float) -> void:
	var s := sim.stage()
	var in_room: bool = sim.view == "room" or sim.view == "menu" and sim.return_view == "room"
	torch.visible = in_room and sim.state.started
	torch.position = get_global_mouse_position()
	var flick := 1.0
	if sim.state.motion:
		flick = 0.93 + 0.07 * sin(time * 13.0) * sin(time * 7.3)
		if s >= 2 and fmod(time, 9.0) < 0.35:
			flick *= 0.35 + 0.65 * absf(sin(time * 40.0))   # the torch stutters later on
	if torch_dead > 0.0:
		torch_dead -= dt
		flick = 0.0 if torch_dead > 0.25 or not sim.state.motion else rng.randf()
	torch.energy = 1.15 * flick * (0.75 if s >= 1 else 1.0)
	var target: Color = MODULATE[s]
	shade.color = shade.color.lerp(target, clampf(dt * 1.5, 0.0, 1.0))
	if sim.state.p01_complete:
		var lamp_target := 1.05
		if sim.state.motion and s >= 2:
			lamp_target *= 0.94 + 0.06 * sin(time * 2.1 + sin(time * 5.7))
		lamp_glow.energy = lerpf(lamp_glow.energy, lamp_target, clampf(dt * 3.0, 0.0, 1.0))
	else:
		lamp_glow.energy = 0.0
	if flash.color.a > 0.0:
		flash.color.a = maxf(0.0, flash.color.a - dt * 4.0)

func _tick_audio(dt: float) -> void:
	var s := sim.stage()
	var silent: bool = sim.state.log_read and sim.view != "logbook"
	var focus := 0.55 if sim.is_closeup() or sim.view == "notebook" else 1.0
	var target := {
		"room": 0.30,
		"sea": 0.0 if silent else 0.75 * focus,
		"wind": (0.35 if s < 2 else 0.5) * focus,
		"drip": 0.45 * focus,
		"hum": 0.22 if sim.state.p01_complete else 0.0,
		"drone": [0.0, 0.0, 0.33, 0.55][s],
		"heartbeat": 0.4 if s >= 3 else 0.0,
	}
	if not sim.state.started:
		for k in target: target[k] = 0.0
		target["sea"] = 0.4
		target["wind"] = 0.3
	if sim.view == "end":
		for k in target: target[k] = 0.0
		target["drone"] = 0.4
	for id in players:
		var rate := 0.35 if id == "sea" else 0.8   # the sea drains away slowly
		mix[id] = move_toward(mix[id], target.get(id, 0.0), dt * rate)
		players[id].volume_db = linear_to_db(maxf(mix[id], 0.0001))

func _tick_sfx(dt: float) -> void:
	for i in range(pending_sfx.size() - 1, -1, -1):
		pending_sfx[i][1] -= dt
		if pending_sfx[i][1] <= 0.0:
			_play_sfx_now(pending_sfx[i][0])
			pending_sfx.remove_at(i)

func _tick_lines(dt: float) -> void:
	if lines.is_empty():
		return
	var cur: Array = lines[0]
	if cur[1] > 0.0:
		cur[1] -= dt
		if cur[1] <= 0.0:
			subtitle.text = cur[0]
			subtitle.visible_characters = 0
			line_t = 0.0
		return
	line_t += dt
	var shown := int(line_t * 48.0)
	subtitle.visible_characters = shown
	if shown >= subtitle.text.length():
		line_hold += dt
		if lines.size() > 1 and line_hold > 0.9 + subtitle.text.length() * 0.025:
			lines.pop_front()
			line_hold = 0.0
			_start_line()

func _queue_line(text: String, delay := 0.0) -> void:
	lines.append([text, delay])
	if lines.size() == 1:
		_start_line()

func _start_line() -> void:
	if lines.is_empty():
		return
	line_t = 0.0
	line_hold = 0.0
	if lines[0][1] <= 0.0:
		subtitle.text = lines[0][0]
		subtitle.visible_characters = 0

func _set_line_now(text: String) -> void:
	lines = [[text, 0.0]]
	_start_line()

# ---------------------------------------------------------------------------
# events
# ---------------------------------------------------------------------------
func dispatch(action: String) -> void:
	var ev := sim.dispatch(action)
	var interrupt := true
	for e in ev:
		match e.type:
			"say":
				if interrupt and e.delay <= 0.0:
					_set_line_now(e.text)
					interrupt = false
				else:
					_queue_line(e.text, e.delay)
			"sfx":
				if e.delay > 0.0:
					pending_sfx.append([e.id, e.delay])
				else:
					_play_sfx_now(e.id)
			"fx":
				_play_fx(e.id)
	_save_progress()
	_redraw()

func _play_fx(id: String) -> void:
	match id:
		"spark":
			if sim.state.motion:
				flash.color = Color(0.85, 0.9, 1.0, 0.75)
			torch_dead = 1.1
		"lamp_on":
			lamp_glow.energy = 0.0
			if sim.state.motion:
				var tw := create_tween()
				for e in [0.9, 0.1, 0.7, 0.0, 1.05]:
					tw.tween_property(lamp_glow, "energy", e, 0.09)
		"sea_fade", "dread", "prints":
			pass  # carried by the mix and the room drawing

func _play_sfx_now(id: String) -> void:
	var stream := load("res://assets/audio/%s.wav" % id) as AudioStream
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	var base := {"spark": -4.0, "sting": -6.0, "latch_far": -8.0, "latch_near": -5.0,
		"door": -6.0, "page": -10.0, "switch": -6.0, "seat": -6.0, "clink": -8.0}
	p.volume_db = base.get(id, -6.0)
	if sim.state.soft_audio and id in ["spark", "latch_near", "sting", "door"]:
		p.volume_db -= 12.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func _apply_stage_instantly() -> void:
	shade.color = MODULATE[sim.stage()]
	if sim.state.p01_complete:
		lamp_glow.energy = 1.05

func _redraw() -> void:
	room.queue_redraw()
	close.queue_redraw()
	hud.queue_redraw()

# ---------------------------------------------------------------------------
# input
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var a := action_at(get_global_mouse_position())
		if a != "":
			dispatch(a)
	elif event is InputEventMouseMotion:
		var id := _hover_at(get_global_mouse_position())
		if id != hover_id:
			hover_id = id
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if id != "" else Input.CURSOR_ARROW)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				dispatch("back" if sim.view != "room" else "menu")
			KEY_N:
				dispatch("notebook")
			KEY_H:
				dispatch("hint")
			KEY_F1:
				dev = not dev
				_redraw()
			KEY_1, KEY_2, KEY_3, KEY_4:
				if dev:
					sim.debug_jump(event.keycode - KEY_1)
					_apply_stage_instantly()
					_save_progress()
					_redraw()

func _hover_at(p: Vector2) -> String:
	if sim.view != "room":
		return ""
	for h in HOTSPOTS:
		if h[1].has_point(p):
			return h[0]
	return ""

## Maps a screen point to a sim action for the current view. "" = nothing.
func action_at(p: Vector2) -> String:
	match sim.view:
		"title":
			return "begin"
		"end":
			return "restart" if Rect2(574, 760, 300, 70).has_point(p) else ""
		"menu":
			var items := ["resume", "toggle_motion", "toggle_soft", "restart"]
			for i in items.size():
				if _menu_rect(i).has_point(p):
					return items[i]
			return ""
	if sim.state.started:
		for b in HUD_BUTTONS:
			if b[1].has_point(p):
				return b[0]
	match sim.view:
		"room":
			for h in HOTSPOTS:
				if h[1].has_point(p):
					return h[0]
		"repair":
			if BACK_RECT.has_point(p): return "back"
			if Rect2(260, 582, 370, 126).has_point(p): return "toggle_supply"
			if Rect2(250, 435, 415, 132).has_point(p): return "fit"
			if Rect2(88, 855, 278, 139).has_point(p): return "select_b"
			if Rect2(376, 855, 278, 139).has_point(p): return "select_c"
		_:
			if BACK_RECT.has_point(p): return "back"
	return ""

func _menu_rect(i: int) -> Rect2:
	return Rect2(474, 330 + i * 100, 500, 76)

# ---------------------------------------------------------------------------
# drawing: room (world space, lit)
# ---------------------------------------------------------------------------
func _draw_room() -> void:
	if textures.is_empty():
		return
	var c := room
	var s := sim.stage()
	c.draw_texture_rect(textures["office_arrival"], Rect2(Vector2.ZERO, SIZE), false)
	# The window darkens with the story, not with a clock.
	var dusk: float = [0.18, 0.42, 0.62, 0.72][s]
	c.draw_rect(Rect2(482, 143, 318, 402), Color(0.04, 0.06, 0.12, dusk))
	if s >= 2:
		# The sea outside keeps moving, silently: a slow bruise-violet sheen on the water.
		var sheen := 0.10 + (0.05 * sin(time * 0.8) if sim.state.motion else 0.0)
		c.draw_rect(Rect2(482, 425, 318, 120), Color(BRUISE, sheen))
	c.draw_texture_rect(textures["lamp_off"], Rect2(242, 469, 192, 288), false)
	if sim.state.p01_complete:
		c.draw_texture_rect(textures["lamp_light"], Rect2(242, 469, 192, 288), false)
	c.draw_texture_rect(textures["spares_tray"], Rect2(341, 666, 128, 64), false)
	if s >= 1:
		_draw_wrong_shadow(c)
	if sim.state.prints_seen or s >= 2:
		_draw_prints(c, s)

func _draw_wrong_shadow(c: Node2D) -> void:
	# The chair's shadow falls toward the lamp: leaning left, onto the wainscot.
	var a := 0.34
	if sim.state.motion:
		a += 0.04 * sin(time * 0.7)
	var col := Color(0.03, 0.05, 0.08, a)
	var pts := PackedVector2Array([
		Vector2(560, 724), Vector2(470, 640), Vector2(468, 624), Vector2(632, 618),
		Vector2(640, 634), Vector2(586, 724)])
	c.draw_colored_polygon(pts, col)
	for x in [496, 530, 566, 600]:
		c.draw_line(Vector2(x, 636), Vector2(x + 52, 722), col, 7.0)

func _draw_prints(c: Node2D, s: int) -> void:
	# Bare, narrow, alternating feet: from the puddle to the end of the desk.
	var steps := [Vector2(1092, 930), Vector2(1066, 958), Vector2(1052, 924), Vector2(1030, 952)]
	for i in steps.size():
		var p: Vector2 = steps[i]
		var pts := PackedVector2Array()
		for k in 14:
			var ang := TAU * k / 14.0
			pts.append(p + Vector2(cos(ang) * 9.0, sin(ang) * 17.0).rotated(-0.5))
		c.draw_colored_polygon(pts, Color(0.06, 0.09, 0.12, 0.55 if s >= 2 else 0.0))
		for t in 4:
			c.draw_circle(p + Vector2(-8 + t * 5, -20).rotated(-0.5), 2.6, Color(0.06, 0.09, 0.12, 0.5))

# ---------------------------------------------------------------------------
# drawing: close-ups and full-screen views (unlit layer)
# ---------------------------------------------------------------------------
func _draw_close() -> void:
	var c := close
	match sim.view:
		"title":
			_draw_title(c)
		"end":
			_draw_end(c)
		"repair":
			_draw_repair(c)
		"logbook":
			_draw_logbook(c)
		"duty", "note":
			c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.94))
			c.draw_texture_rect(textures["duty_card" if sim.view == "duty" else "chart_note"],
				Rect2(244, 180, 960, 780), false)
			_button(c, BACK_RECT, "Back")
		"notebook":
			_draw_notebook(c)
		"menu":
			_draw_menu(c)

func _draw_title(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color("070b0f"))
	var pulse := 0.55 + 0.45 * sin(time * 1.6)
	_text(c, "THE NINTH TIDE", Vector2(0, 470), 78, PAPER, serif, SIZE.x)
	_text(c, "Tide I  ·  The Last Shift", Vector2(0, 540), 30, Color(PAPER, 0.7), hand, SIZE.x)
	_text(c, "Greywake Survey Station, Morrow Sound. October 1931.", Vector2(0, 640), 24,
		Color(PAPER, 0.5), serif, SIZE.x)
	_text(c, "click to begin", Vector2(0, 820), 24, Color(GOLD, pulse), serif, SIZE.x)
	_text(c, "Headphones recommended. Esc for options.", Vector2(0, 1040), 18,
		Color(PAPER, 0.35), serif, SIZE.x)

func _draw_end(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color("070b0f"))
	_text(c, "The corridor smells of the sea.", Vector2(0, 400), 34, PAPER, hand, SIZE.x)
	_text(c, "Tide I continues in the Chart Room.", Vector2(0, 470), 28, Color(PAPER, 0.7), serif, SIZE.x)
	_text(c, "End of the Intake Office slice.", Vector2(0, 600), 22, Color(PAPER, 0.45), serif, SIZE.x)
	_button(c, Rect2(574, 760, 300, 70), "Play again")

func _draw_repair(c: Node2D) -> void:
	c.draw_texture_rect(textures["repair_panel"], Rect2(Vector2.ZERO, SIZE), false)
	# Water damage over the solved steps and reference: the plate itself stays legible.
	var stain := Color("b8a47c")
	for blob in [[Vector2(1010, 356), 44], [Vector2(1090, 350), 40], [Vector2(1160, 362), 36],
			[Vector2(960, 362), 30], [Vector2(1050, 575), 70], [Vector2(980, 590), 50],
			[Vector2(1120, 590), 55], [Vector2(1060, 660), 62], [Vector2(980, 690), 48],
			[Vector2(1150, 690), 52], [Vector2(1080, 720), 40], [Vector2(1220, 670), 34]]:
		c.draw_circle(blob[0], blob[1], Color(stain, 0.96))
	for ring in [[Vector2(1050, 610), 120], [Vector2(1060, 358), 76]]:
		c.draw_arc(ring[0], ring[1], 0, TAU, 64, Color("8f7a55", 0.5), 3.0)
	_text(c, "(water-damaged)", Vector2(896, 765), 18, Color(INK, 0.6), hand, 400, HORIZONTAL_ALIGNMENT_LEFT)
	c.draw_texture_rect(textures["switch_on" if sim.state.supply_on else "switch_off"],
		Rect2(Vector2.ZERO, SIZE), false)
	if sim.state.bridge_installed:
		c.draw_texture_rect(textures["bridge_b_installed"], Rect2(Vector2.ZERO, SIZE), false)
	else:
		c.draw_texture_rect(textures["bridge_b"], Rect2(106, 868, 240, 120), false)
	c.draw_texture_rect(textures["bridge_c"], Rect2(396, 868, 240, 120), false)
	if sim.state.bridge_installed and sim.state.supply_on:
		c.draw_texture_rect(textures["indicator_on"], Rect2(Vector2.ZERO, SIZE), false)
	if sim.selected != "":
		var r := Rect2(88, 867, 278, 122) if sim.selected == "B" else Rect2(376, 867, 278, 122)
		c.draw_rect(r, GOLD, false, 5)
	_button(c, BACK_RECT, "Back")

func _draw_logbook(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.96))
	var page := Rect2(204, 110, 1040, 860)
	c.draw_rect(page, Color("d9cfb2"))
	c.draw_rect(page, Color("8f7a55"), false, 2)
	_text(c, "GREYWAKE SURVEY STATION — TIDE LOG", page.position + Vector2(48, 66), 26, INK, serif, 900, HORIZONTAL_ALIGNMENT_LEFT)
	_text(c, "Observer: E. Venn", page.position + Vector2(48, 104), 22, Color(INK, 0.7), hand, 600, HORIZONTAL_ALIGNMENT_LEFT)
	var y := page.position.y + 170
	for x in [page.position.x + 40, page.position.x + 210, page.position.x + 340, page.position.x + 500]:
		c.draw_line(Vector2(x, y - 40), Vector2(x, page.end.y - 40), Color(INK, 0.15), 1.0)
	for e in OfficeSim.LOG_ENTRIES:
		c.draw_line(Vector2(page.position.x + 30, y + 14), Vector2(page.end.x - 30, y + 14), Color(INK, 0.18), 1.0)
		var col := Color("1f3f8a") if e[4] else Color(INK, 0.85)
		var f := hand
		var size := 25 if e[4] else 23
		_text(c, e[0], Vector2(page.position.x + 52, y), size, col, f, 160, HORIZONTAL_ALIGNMENT_LEFT)
		_text(c, e[1], Vector2(page.position.x + 222, y), size, col, f, 120, HORIZONTAL_ALIGNMENT_LEFT)
		_text(c, e[2], Vector2(page.position.x + 352, y), size, col, f, 150, HORIZONTAL_ALIGNMENT_LEFT)
		_text(c, e[3], Vector2(page.position.x + 512, y), size, col, f, 500, HORIZONTAL_ALIGNMENT_LEFT)
		y += 70
	if not sim.state.p01_complete:
		c.draw_rect(page, Color(0.02, 0.03, 0.05, 0.86))
		var spot := get_global_mouse_position()
		c.draw_circle(spot, 120, Color(0.85, 0.8, 0.65, 0.07))
		_text(c, "Too faint to read by torchlight.", Vector2(0, 560), 30, Color(PAPER, 0.75), hand, SIZE.x)
	_button(c, BACK_RECT, "Back")

func _draw_notebook(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.97))
	var page := Rect2(164, 90, 1120, 900)
	c.draw_rect(page, Color("e4dcc4"))
	_text(c, "NOTEBOOK — A. MERCER", page.position + Vector2(50, 64), 26, INK, serif, 900, HORIZONTAL_ALIGNMENT_LEFT)
	_text(c, "Now: " + OfficeSim.OBJECTIVES[sim.objective()], page.position + Vector2(50, 112), 24,
		Color("5b3a2e"), hand, 1000, HORIZONTAL_ALIGNMENT_LEFT)
	var y := page.position.y + 180
	var any := false
	for id in OfficeSim.OBSERVATIONS:
		if sim.has_seen(id):
			any = true
			c.draw_circle(Vector2(page.position.x + 60, y - 8), 4, Color(INK, 0.6))
			y = _wrapped(c, OfficeSim.OBSERVATIONS[id], Vector2(page.position.x + 80, y), 22, INK, 960) + 16
	if not any:
		_text(c, "Nothing recorded yet. Look around the office.", Vector2(page.position.x + 80, y), 22,
			Color(INK, 0.6), hand, 900, HORIZONTAL_ALIGNMENT_LEFT)
	_button(c, BACK_RECT, "Back")

func _draw_menu(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.93))
	_text(c, "Paused", Vector2(0, 260), 40, PAPER, serif, SIZE.x)
	var labels := ["Resume", "Motion & flicker: " + ("on" if sim.state.motion else "off"),
		"Soften sudden sounds: " + ("on" if sim.state.soft_audio else "off"), "Restart slice"]
	for i in labels.size():
		_button(c, _menu_rect(i), labels[i])

# ---------------------------------------------------------------------------
# drawing: HUD
# ---------------------------------------------------------------------------
func _draw_hud() -> void:
	var c := hud
	if sim.view in ["title", "end"]:
		subtitle.visible = false
		return
	subtitle.visible = true
	c.draw_rect(Rect2(20, 994, 1408, 80), Color(0.03, 0.06, 0.08, 0.9))
	for b in HUD_BUTTONS:
		_button(c, b[1], b[2], false, 21)
	if hover_id != "" and sim.view == "room":
		for h in HOTSPOTS:
			if h[0] == hover_id:
				var p := get_global_mouse_position() + Vector2(22, 34)
				var w := serif.get_string_size(h[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 20
				c.draw_rect(Rect2(p - Vector2(10, 24), Vector2(w, 34)), Color(0.03, 0.06, 0.08, 0.8))
				c.draw_string(serif, p, h[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)
	if dev:
		c.draw_rect(Rect2(20, 90, 520, 150), Color(0, 0, 0, 0.75))
		var y := 120
		for line in ["DEV (F1)  stage %d  view %s" % [sim.stage(), sim.view],
				"1-4 jump to stage 0-3", "objective: " + sim.objective()]:
			c.draw_string(serif, Vector2(34, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
			y += 34
		for h in HOTSPOTS:
			c.draw_rect(h[1], Color(1, 0, 1, 0.6), false, 2)

# ---------------------------------------------------------------------------
# drawing helpers
# ---------------------------------------------------------------------------
func _button(c: CanvasItem, rect: Rect2, label: String, active := false, size := 24) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("786440") if active else Color(0.15, 0.25, 0.29, 0.92)
	style.border_color = GOLD if active else Color("8ba19a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	c.draw_style_box(style, rect)
	var ts := serif.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	c.draw_string(serif, rect.position + Vector2((rect.size.x - ts.x) / 2.0, rect.size.y / 2.0 + size * 0.36),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, PAPER)

func _text(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, font: Font, width: float,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	c.draw_string(font, pos, s, align, width, size, col)

## Draws word-wrapped text; returns the y below the last line.
func _wrapped(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, width: float) -> float:
	var y := pos.y
	var line := ""
	for word in s.split(" "):
		var trial := word if line == "" else line + " " + word
		if serif.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			c.draw_string(serif, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			y += size * 1.45
			line = word
		else:
			line = trial
	if line != "":
		c.draw_string(serif, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		y += size * 1.45
	return y
