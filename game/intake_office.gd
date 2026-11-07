extends Node2D
## Intake Office slice: renders an OfficeSim, plays its events, owns light and sound.
##
## Layering:
##   world (affected by CanvasModulate + 2D lights): room plate, lamp, overlays
##   CanvasLayer 5  "close": close-ups and documents (always fully readable)
##   CanvasLayer 10 "hud":   subtitles, buttons, hover name, flash
## All state lives in `sim`; this script only presents it. Everything timed
## here (fades, line scheduling, reveals) is presentation and is never saved.

const SIZE := Vector2(1448, 1086)
const DEFAULT_SAVE_PATH := "user://intake_office_v2.json"
const PAPER := Color("ded4ba")
const INK := Color("172b36")
const GOLD := Color("d2aa66")
const AMBER := Color("c39959")
const BRUISE := Color("746577")
const BLUE_INK := Color("1f3f8a")
const BRASS := Color("b08a4a")

## Ambient modulate per story stage (0 arrival .. 3 seat wet).
const MODULATE := [Color(0.30, 0.33, 0.42), Color(0.46, 0.44, 0.48),
	Color(0.30, 0.30, 0.38), Color(0.22, 0.21, 0.30)]
## The lamp's pool of light shrinks as the story closes in.
const LAMP_SCALE := [3.2, 3.2, 2.3, 1.7]
const TORCH_WARM := Color(1.0, 0.94, 0.82)
const TORCH_COLD := Color(0.82, 0.88, 1.0)
const THRESHOLD_SHADE := Color(0.08, 0.08, 0.12)
const SHADOW_COL := Color(0.02, 0.04, 0.07, 0.42)
const PRINT_COL := Color(0.06, 0.09, 0.12)
const PILING_COL := Color(0.07, 0.08, 0.11, 0.92)

## Room hotspots. First match wins, so small objects precede large ones.
const HOTSPOTS := [
	["mug", Rect2(915, 662, 82, 62), "Mug"],
	["tray", Rect2(341, 666, 128, 64), "Spares tray"],
	["lamp", Rect2(242, 469, 192, 260), "Desk lamp"],
	["logbook", Rect2(500, 684, 205, 44), "Tide log"],
	["papers", Rect2(738, 622, 165, 104), "Duty papers"],
	["chair", Rect2(553, 618, 180, 66), "Chair"],
	["drawer", Rect2(832, 752, 152, 226), "Desk drawer"],
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
const BACK_RECT := Rect2(952, 22, 150, 50)
const END_BUTTON := Rect2(574, 760, 300, 70)

# Drawer close-up geometry.
const DRAWER_FRONT := Rect2(324, 300, 800, 520)
const DRAWER_PLATE := Rect2(484, 336, 480, 72)
const DRAWER_TRY := Rect2(574, 690, 300, 76)
const WATCH_C := Vector2(560, 600)
const WATCH_R := 120.0
const PHOTO_RECT := Rect2(770, 430, 300, 380)

const REVEAL_CPS := 14.0      # characters per second the log writes itself
## Forward slant for her hand. In Godot's Transform2D a positive skew leans glyph tops
## to the right; -0.18 visibly cancelled the italic and read as a back-hand.
const HAND_SKEW := 0.18
const TYPE_CPS := 48.0        # subtitle typewriter
const THRESHOLD_CONTINUE := 9.4
const END_GRACE := 1.5

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
var lines: Array = []          # queued {text, due, story}, sorted by due
var cur_text := ""             # the line on screen
var cur_story := false
var cur_since := 0.0           # time the current line went up
var line_t := 0.0              # typewriter clock for the current line
var hover_id := ""
var torch_dead := 0.0          # seconds of blackout left after a spark
var rng := RandomNumberGenerator.new()
var time := 0.0
var players := {}              # loop id -> AudioStreamPlayer
var mix := {}                  # loop id -> current linear volume
var pending_sfx: Array = []    # [id, time_left]
var oneshots: Array = []       # live one-shot players
var lamp_tween: Tween
var dev := false

var last_stage := 0
var prints_fade := 1.0         # 0..1 fade-in of the first trail
var shadow_creep := 0          # 0..4: the shadow leans further each time she looks back
var tilt_k := 0.0              # 0..1 progress of the horizon tilt
var eye_x := 640.0
var log_shown_hand := 0        # in-hand log rows already written
var reveal_t := 0.0            # seconds into the row being written
var breath_hold := 0.0         # seconds the room holds its breath after the prints
var threshold_t := 0.0
var end_t := 0.0
var drawer_k := 1.0            # 0..1 drawer slide progress

func _ready() -> void:
	rng.seed = 9
	_load_textures()
	_build_fonts()
	_build_nodes()
	_build_audio()
	_load_progress()
	_apply_stage_instantly()
	_redraw()

## Stop every voice before the players go, so the audio server lets their playbacks go too.
func _exit_tree() -> void:
	for p in players.values():
		p.stop()
	for p in oneshots:
		if is_instance_valid(p):
			p.stop()

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
	lamp_glow.texture_scale = LAMP_SCALE[0]
	lamp_glow.color = AMBER.lightened(0.15)
	lamp_glow.energy = 0.0
	lamp_glow.position = Vector2(338, 545)
	add_child(lamp_glow)

	torch = PointLight2D.new()
	torch.texture = _radial(512, 0.25)
	torch.texture_scale = 0.95
	torch.color = TORCH_WARM
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
	# One limiter on Master, however many times the scene is instanced.
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, limiter)
	for id in ["room", "sea", "wind", "drip", "hum", "drone", "heartbeat", "breath", "ring", "pen"]:
		var stream := _load_audio(id) as AudioStreamWAV
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

## Missing sound files are skipped silently: sound is built by a separate tool.
func _load_audio(id: String) -> AudioStream:
	var path := "res://assets/audio/%s.wav" % id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream

# ---------------------------------------------------------------------------
# persistence
# ---------------------------------------------------------------------------
func _load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var j := JSON.new()
	if j.parse(f.get_as_text()) == OK and sim.from_dict(j.data):
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
	_tick_stage(dt)
	_tick_lines(dt)
	_tick_sfx(dt)
	_tick_reveal(dt)
	_tick_light(dt)
	_tick_audio(dt)
	if sim.view in ["room", "threshold"] and (sim.state.motion or sim.view == "threshold"):
		room.queue_redraw()
	if not sim.view in ["room", "threshold"]:
		close.queue_redraw()
	hud.queue_redraw()

func _at_threshold() -> bool:
	return sim.view == "threshold" or sim.view in ["notebook", "menu"] and sim.return_view == "threshold"

func _tick_stage(dt: float) -> void:
	var s := sim.stage()
	if s != last_stage:
		# The horizon tips once, when the seat is found wet; never on load or jump.
		tilt_k = 0.0 if s == 3 and sim.state.motion else (1.0 if s == 3 else 0.0)
		last_stage = s
	if s == 3 and tilt_k < 1.0:
		tilt_k = minf(1.0, tilt_k + dt / 6.0) if sim.state.motion else 1.0
	if prints_fade < 1.0:
		prints_fade = minf(1.0, prints_fade + dt / 1.5) if sim.state.motion else 1.0
	if drawer_k < 1.0:
		drawer_k = minf(1.0, drawer_k + dt / 0.8) if sim.state.motion else 1.0
	if sim.state.motion:
		var mx := clampf(get_global_mouse_position().x, 560.0, 720.0)
		eye_x = lerpf(eye_x, mx, clampf(dt * 0.8, 0.0, 1.0))
	else:
		eye_x = 640.0
	if _at_threshold():
		threshold_t += dt
	if sim.view == "end":
		end_t += dt
	breath_hold = maxf(0.0, breath_hold - dt)

func _tick_light(dt: float) -> void:
	var s := sim.stage()
	var at_door := _at_threshold()
	var in_room: bool = sim.view in ["room", "threshold"] or \
		sim.view == "menu" and sim.return_view in ["room", "threshold"]
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
	torch.energy = 1.15 * flick * (0.75 if s >= 1 else 1.0) * (0.4 if at_door else 1.0)
	torch.color = torch.color.lerp(TORCH_COLD if s >= 2 else TORCH_WARM, clampf(dt * 0.6, 0.0, 1.0))
	if at_door:
		shade.color = shade.color.lerp(THRESHOLD_SHADE, clampf(dt * 1.0, 0.0, 1.0))
	else:
		shade.color = shade.color.lerp(MODULATE[s], clampf(dt * 1.5, 0.0, 1.0))
	lamp_glow.texture_scale = lerpf(lamp_glow.texture_scale, LAMP_SCALE[s], clampf(dt * 0.6, 0.0, 1.0))
	if sim.state.p01_complete:
		var lamp_target := 1.05
		if at_door:
			lamp_target = 0.35
		elif sim.state.motion and s >= 2:
			lamp_target *= 0.94 + 0.06 * sin(time * 2.1 + sin(time * 5.7))
		var rate := 1.0 if at_door else 3.0
		lamp_glow.energy = lerpf(lamp_glow.energy, lamp_target, clampf(dt * rate, 0.0, 1.0))
	else:
		lamp_glow.energy = 0.0
	if flash.color.a > 0.0:
		flash.color.a = maxf(0.0, flash.color.a - dt * 4.0)

func _tick_audio(dt: float) -> void:
	var s := sim.stage()
	var silent: bool = sim.state.log_read and sim.view != "logbook"
	var focus := 0.55 if sim.is_closeup() or sim.view == "notebook" else 1.0
	var target := {
		"room": [0.30, 0.30, 0.12, 0.12][s],
		"sea": 0.0 if silent else 0.75 * focus,
		"wind": [0.35, 0.35, 0.15, 0.18][s] * focus,
		"drip": [0.45, 0.45, 0.0, 0.6][s] * focus,
		"hum": 0.18 if sim.state.p01_complete else 0.0,
		"drone": [0.0, 0.0, 0.30, 0.50][s],
		"heartbeat": 0.35 if s == 3 else 0.0,
		"ring": [0.0, 0.0, 0.05, 0.07][s],
		"breath": 0.0,
		"pen": 0.45 if _reveal_active() else 0.0,
	}
	var rates := {"sea": 0.35, "pen": 4.0}   # the sea drains away slowly; the pen stops with the nib
	if not sim.state.started:
		for k in target: target[k] = 0.0
		target["sea"] = 0.4
		target["wind"] = 0.3
	elif sim.view == "end":
		for k in target: target[k] = 0.0
		target["drone"] = 0.4
		target["ring"] = 0.03
	elif _at_threshold():
		for k in target: target[k] = 0.0
		target["drone"] = 0.45
		target["ring"] = 0.08
		target["breath"] = 0.55
		if threshold_t >= 8.2:
			# "It stops when I do."
			target["breath"] = 0.0
			rates["breath"] = 2.5
	elif breath_hold > 0.0:
		# The room holds its breath when she finds the prints.
		for k in target:
			if k != "heartbeat" and k != "ring":
				target[k] = 0.0
				rates[k] = 3.0
	for id in players:
		mix[id] = move_toward(mix[id], target.get(id, 0.0), dt * rates.get(id, 0.8))
		players[id].volume_db = linear_to_db(maxf(mix[id], 0.0001))
	if players.has("hum"):
		var hum: AudioStreamPlayer = players["hum"]
		hum.pitch_scale = lerpf(hum.pitch_scale, 1.0 - 0.012 * s, clampf(dt * 0.5, 0.0, 1.0))

func _tick_sfx(dt: float) -> void:
	for i in range(pending_sfx.size() - 1, -1, -1):
		pending_sfx[i][1] -= dt
		if pending_sfx[i][1] <= 0.0:
			var id: String = pending_sfx[i][0]
			pending_sfx.remove_at(i)
			_play_sfx_now(id)

# ---------------------------------------------------------------------------
# subtitles: a scheduler keyed to absolute time
# ---------------------------------------------------------------------------
static func min_read(text: String) -> float:
	return 0.7 + 0.028 * text.length()

## A story line on screen can't be replaced by a click until it has been readable.
func _cur_protected() -> bool:
	return cur_story and cur_text != "" and time - cur_since < min_read(cur_text)

## Queued lines never cut off any line, story or not, before min_read: without this an
## overdue story line would replace a click's fresh line on the very next frame.
func _cur_readable() -> bool:
	return cur_text == "" or time - cur_since >= min_read(cur_text)

## When the story lines already queued (and a story line on screen) will have been read.
func _story_backlog_end() -> float:
	var t := time
	if cur_story and cur_text != "":
		t = maxf(t, cur_since + min_read(cur_text))
	for l in lines:
		if l.story:
			t = maxf(t, l.due) + min_read(l.text)
	return t

func _tick_lines(dt: float) -> void:
	if not lines.is_empty() and lines[0].due <= time and _cur_readable():
		var head: Dictionary = lines.pop_front()
		_show_line(head.text, head.story)
	if cur_text != "":
		line_t += dt
		subtitle.visible_characters = int(line_t * TYPE_CPS)

func _show_line(text: String, story: bool) -> void:
	cur_text = text
	cur_story = story
	cur_since = time
	line_t = 0.0
	subtitle.text = text
	subtitle.visible_characters = 0

## Inserts a line due at absolute time `due`, after any line due no later.
func _insert_line(text: String, due: float, story: bool) -> void:
	var i := lines.size()
	while i > 0 and lines[i - 1].due > due:
		i -= 1
	lines.insert(i, {"text": text, "due": due, "story": story})

func _queue_line(text: String, delay := 0.0, story := false) -> void:
	_insert_line(text, time + delay, story)

## A click's immediate line: drops stale chatter, never a story line.
func _say_now(text: String, story: bool) -> void:
	lines = lines.filter(func(l): return l.story)
	if _cur_protected():
		_insert_line(text, time, story)
	else:
		_show_line(text, story)

# ---------------------------------------------------------------------------
# events
# ---------------------------------------------------------------------------
func dispatch(action: String) -> void:
	var before := sim.view
	var ev := sim.dispatch(action)
	# A click that starts a timed reveal waits for any reveal still being read, so two
	# reveals never interleave. Its timed sounds move with it; its first sound doesn't.
	var beat := false
	for e in ev:
		if e.type == "say" and e.get("story", false) and e.delay > 0.0:
			beat = true
	var offset := 0.0
	if beat:
		lines = lines.filter(func(l): return l.story)
		offset = maxf(0.0, _story_backlog_end() - time)
	var spoke_now := false
	for e in ev:
		match e.type:
			"say":
				var story: bool = e.get("story", false)
				if e.delay <= 0.0 and not spoke_now and offset <= 0.0:
					spoke_now = true
					_say_now(e.text, story)
				else:
					_insert_line(e.text, time + offset + e.delay, story)
			"sfx":
				if e.delay > 0.0:
					pending_sfx.append([e.id, e.delay + offset])
				else:
					_play_sfx_now(e.id)
			"fx":
				_play_fx(e.id)
	if sim.view != before:
		_on_view_changed(before)
	if sim.view == "title":
		_reset_presentation()
	_save_progress()
	_redraw()

func _on_view_changed(before: String) -> void:
	if sim.view == "room" and (sim.is_closeup(before) or before == "notebook"):
		shadow_creep = mini(shadow_creep + 1, 4)
	if before == "logbook":
		# Leaving mid-reveal: the lines are simply there next time.
		log_shown_hand = _in_hand_count()
		reveal_t = 0.0
	if sim.view == "end":
		end_t = 0.0

## Dev/capture: jump to a story stage with clean presentation.
func debug_jump(target: int) -> void:
	sim.debug_jump(target)
	_reset_presentation()
	_save_progress()
	_redraw()

## Clears everything timed so a restart or jump can't inherit old lines or sounds.
func _reset_presentation() -> void:
	lines.clear()
	cur_text = ""
	cur_story = false
	line_t = 0.0
	subtitle.text = ""
	pending_sfx.clear()
	torch_dead = 0.0
	if lamp_tween:
		lamp_tween.kill()
		lamp_tween = null
	lamp_glow.energy = 0.0
	for p in oneshots:
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	oneshots.clear()
	log_shown_hand = 0
	reveal_t = 0.0
	shadow_creep = 0
	tilt_k = 0.0
	prints_fade = 1.0
	breath_hold = 0.0
	threshold_t = 0.0
	end_t = 0.0
	drawer_k = 1.0
	flash.color.a = 0.0
	_apply_stage_instantly()

func _play_fx(id: String) -> void:
	match id:
		"spark":
			if sim.state.motion:
				flash.color = Color(0.85, 0.9, 1.0, 0.75)
			torch_dead = 1.1
		"lamp_on":
			lamp_glow.energy = 0.0
			if sim.state.motion:
				if lamp_tween:
					lamp_tween.kill()
				lamp_tween = create_tween()
				for e in [0.9, 0.1, 0.7, 0.0, 1.05]:
					lamp_tween.tween_property(lamp_glow, "energy", e, 0.09)
		"prints":
			prints_fade = 0.0 if sim.state.motion else 1.0
			breath_hold = 2.5
		"drawer_open":
			drawer_k = 0.0 if sim.state.motion else 1.0
		"threshold":
			threshold_t = 0.0
			# A new scene: nothing from the room follows her into the doorway.
			lines.clear()
			pending_sfx.clear()
			for l in OfficeSim.THRESHOLD_LINES:
				_insert_line(l[1], time + l[0], true)
		"sea_fade", "dread", "log_write":
			pass  # carried by the mix, the room drawing and the logbook reveal

func _play_sfx_now(id: String) -> void:
	var stream := _load_audio(id)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	var base := {"spark": -4.0, "sting": -6.0, "latch_far": -8.0, "latch_near": -5.0,
		"door": -6.0, "page": -10.0, "switch": -6.0, "seat": -6.0, "clink": -8.0,
		"knock_glass": -9.0, "dial": -16.0, "clunk": -10.0, "drawer": -9.0}
	p.volume_db = base.get(id, -6.0)
	if sim.state.soft_audio and id in ["spark", "latch_near", "sting", "door", "knock_glass", "clunk"]:
		p.volume_db -= 12.0
	add_child(p)
	oneshots.append(p)
	p.finished.connect(func():
		oneshots.erase(p)
		p.queue_free())
	p.play()

func _apply_stage_instantly() -> void:
	var s := sim.stage()
	last_stage = s
	shade.color = MODULATE[s]
	lamp_glow.energy = 1.05 if sim.state.p01_complete else 0.0
	lamp_glow.texture_scale = LAMP_SCALE[s]
	torch.color = TORCH_COLD if s >= 2 else TORCH_WARM
	tilt_k = 1.0 if s == 3 else 0.0
	eye_x = 640.0
	if players.has("hum"):
		players["hum"].pitch_scale = 1.0 - 0.012 * s

func _redraw() -> void:
	room.queue_redraw()
	close.queue_redraw()
	hud.queue_redraw()

# ---------------------------------------------------------------------------
# logbook reveal (presentation only)
# ---------------------------------------------------------------------------
func _in_hand_rows() -> Array:
	var out := []
	for e in sim.log_rows():
		if e[4]:
			out.append(e)
	return out

func _in_hand_count() -> int:
	return _in_hand_rows().size()

func _reveal_active() -> bool:
	return sim.view == "logbook" and sim.state.p01_complete and sim.state.motion \
		and log_shown_hand < _in_hand_count()

func _tick_reveal(dt: float) -> void:
	if sim.view != "logbook" or not sim.state.p01_complete:
		return
	var rows := _in_hand_rows()
	if log_shown_hand >= rows.size():
		return
	if not sim.state.motion:
		log_shown_hand = rows.size()
		reveal_t = 0.0
		return
	reveal_t += dt
	var text: String = rows[log_shown_hand][3]
	if reveal_t >= text.length() / REVEAL_CPS + 0.5:
		log_shown_hand += 1
		reveal_t = 0.0

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
				if sim.view in ["title", "room", "threshold"]:
					dispatch("menu")
				elif sim.view != "end":
					dispatch("back")
			KEY_N:
				dispatch("notebook")
			KEY_H:
				dispatch("hint")
			KEY_F1:
				if OS.is_debug_build():
					dev = not dev
					_redraw()
			KEY_1, KEY_2, KEY_3, KEY_4:
				if dev and OS.is_debug_build():
					debug_jump(event.keycode - KEY_1)

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
			return "restart" if end_t > END_GRACE and END_BUTTON.has_point(p) else ""
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
	if (sim.is_closeup() or sim.view == "notebook") and BACK_RECT.has_point(p):
		return "back"
	match sim.view:
		"room":
			for h in HOTSPOTS:
				if h[1].has_point(p):
					return h[0]
		"repair":
			if Rect2(260, 582, 370, 126).has_point(p): return "toggle_supply"
			if Rect2(250, 435, 415, 132).has_point(p): return "fit"
			if Rect2(88, 855, 278, 139).has_point(p): return "select_b"
			if Rect2(376, 855, 278, 139).has_point(p): return "select_c"
		"drawer":
			if sim.state.drawer_open:
				if Rect2(WATCH_C - Vector2.ONE * WATCH_R, Vector2.ONE * WATCH_R * 2).has_point(p):
					return "look_watch"
				if PHOTO_RECT.has_point(p):
					return "look_photo"
			else:
				for i in 4:
					if _dial_rect(i).has_point(p):
						return "dial_%d" % i
				if DRAWER_TRY.has_point(p):
					return "try_drawer"
		"threshold":
			return "continue" if threshold_t >= THRESHOLD_CONTINUE else ""
	return ""

func _menu_rect(i: int) -> Rect2:
	return Rect2(474, 330 + i * 100, 500, 76)

func _dial_rect(i: int) -> Rect2:
	return Rect2(424 + i * 160, 450, 120, 170)

# ---------------------------------------------------------------------------
# drawing: room (world space, lit)
# ---------------------------------------------------------------------------
func _draw_room() -> void:
	if textures.is_empty():
		return
	var c := room
	var s := sim.stage()
	c.draw_texture_rect(textures["office_arrival"], Rect2(Vector2.ZERO, SIZE), false)
	if s == 3:
		_draw_horizon_tilt(c)
	# The window darkens with the story, not with a clock.
	var dusk: float = [0.18, 0.42, 0.62, 0.72][s]
	c.draw_rect(Rect2(482, 143, 318, 402), Color(0.04, 0.06, 0.12, dusk))
	if s >= 2:
		# The sea outside keeps moving, silently: a slow bruise-violet sheen on the water.
		var sheen := 0.10 + (0.05 * sin(time * 0.8) if sim.state.motion else 0.0)
		c.draw_rect(Rect2(482, 425, 318, 120), Color(BRUISE, sheen))
		_draw_ninth_piling(c, s)
	if s == 3:
		_draw_eye(c)   # above the dusk wash: Ada says she can see it, so the player must too
	c.draw_texture_rect(textures["lamp_off"], Rect2(242, 469, 192, 288), false)
	if sim.state.p01_complete:
		c.draw_texture_rect(textures["lamp_light"], Rect2(242, 469, 192, 288), false)
	c.draw_texture_rect(textures["spares_tray"], Rect2(341, 666, 128, 64), false)
	if s >= 2:
		_draw_map_pencil(c, s)
	if s >= 3:
		_draw_hook_tag(c)
	_draw_coat_weight(c, s)
	if s >= 1:
		_draw_wrong_shadow(c, s)
	_draw_prints(c, s)
	if _at_threshold():
		_draw_door_opening(c)
	elif s >= 3:
		c.draw_rect(Rect2(1228, 168, 6, 736), Color(0.01, 0.01, 0.02, 0.85))   # ajar
	_draw_vignette(c, [0.0, 0.0, 0.35, 0.5][s])

func _draw_horizon_tilt(c: Node2D) -> void:
	# The sea's edge lifts on the right. The room stays square; the world doesn't.
	var k := smoothstep(0.0, 1.0, tilt_k)
	c.draw_colored_polygon(PackedVector2Array([Vector2(600, 436), Vector2(800, 436),
		Vector2(800, 433 - 24 * k), Vector2(600, 433)]), Color(0.16, 0.19, 0.24))

func _draw_eye(c: Node2D) -> void:
	var ring := _ellipse(Vector2(eye_x, 502), 70, 14, 32)
	ring.append(ring[0])
	c.draw_polyline(ring, Color(0.80, 0.84, 0.90, 0.22), 2.0, true)
	c.draw_colored_polygon(_ellipse(Vector2(eye_x, 502), 18, 5, 20), Color(0.02, 0.03, 0.05, 0.5))

func _draw_ninth_piling(c: Node2D, s: int) -> void:
	if sim.state.drawer_open or s == 3:
		c.draw_rect(Rect2(590, 436, 14, 92), PILING_COL)
		c.draw_circle(Vector2(597, 436), 7, PILING_COL)
	else:
		c.draw_rect(Rect2(612, 452, 9, 64), PILING_COL)

func _draw_map_pencil(c: Node2D, s: int) -> void:
	c.draw_line(Vector2(352, 298), Vector2(352, 342), Color(0.25, 0.25, 0.28, 0.8), 2.5)
	c.draw_string(hand, Vector2(346, 364), "9", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.25, 0.25, 0.28, 0.8))
	if s == 3:
		c.draw_line(Vector2(372, 318), Vector2(372, 354), Color(0.09, 0.10, 0.12, 0.85), 3.0)

func _draw_hook_tag(c: Node2D) -> void:
	c.draw_rect(Rect2(1141, 306, 22, 30), BRASS)
	c.draw_line(Vector2(1145, 315), Vector2(1159, 315), BLUE_INK, 1.5)
	c.draw_line(Vector2(1145, 323), Vector2(1156, 323), BLUE_INK, 1.5)

func _draw_coat_weight(c: Node2D, s: int) -> void:
	var a := 0.0
	if s >= 3:
		a = 0.6
	elif sim.state.log_rewritten:
		a = 0.3
	if a <= 0.0:
		return
	if sim.state.motion:
		a += 0.02 * sin(time * 0.9)   # slow enough to read as breathing, not flicker
	c.draw_colored_polygon(PackedVector2Array([Vector2(1040, 352), Vector2(1080, 318),
		Vector2(1122, 352), Vector2(1136, 402), Vector2(1028, 402)]), Color(0.04, 0.06, 0.09, a))
	if s >= 3:
		c.draw_colored_polygon(_ellipse(Vector2(1082, 318), 22, 14, 18), Color(0.04, 0.06, 0.09, 0.5))

func _draw_wrong_shadow(c: Node2D, s: int) -> void:
	# The chair's shadow falls toward the lamp, and leans further each time she looks back.
	var k := 10.0 * shadow_creep
	c.draw_colored_polygon(PackedVector2Array([Vector2(452 - k, 596), Vector2(612 - k, 596),
		Vector2(628 - k, 608), Vector2(468 - k, 608)]), SHADOW_COL)
	c.draw_line(Vector2(452 - k, 596), Vector2(500, 682), SHADOW_COL, 9.0)
	c.draw_line(Vector2(612 - k, 596), Vector2(660, 682), SHADOW_COL, 9.0)
	for x in [478, 512, 546, 580]:
		c.draw_line(Vector2(x - k, 608), Vector2(x + 40, 682), SHADOW_COL, 6.0)
	if s >= 3:
		# Someone is sitting in the shadow. Not in the chair.
		c.draw_colored_polygon(_ellipse(Vector2(520 - k, 568), 24, 30, 14), SHADOW_COL)
		c.draw_colored_polygon(PackedVector2Array([Vector2(476 - k, 600), Vector2(564 - k, 600),
			Vector2(552 - k, 582), Vector2(488 - k, 582)]), SHADOW_COL)

func _draw_prints(c: Node2D, s: int) -> void:
	if s >= 2 and (sim.state.prints_seen or s >= 3):
		var trail_a := [Vector2(1124, 950), Vector2(1100, 972), Vector2(1076, 948),
			Vector2(1052, 970), Vector2(1030, 952)]
		var col := Color(PRINT_COL, 0.55 * smoothstep(0.0, 1.0, prints_fade))
		for p in trail_a:
			_foot(c, p, Vector2.LEFT, 1.0, col)
	if s >= 3:
		# A second trail, from the desk to the door, thinning to nothing.
		var trail_b := [Vector2(1070, 960), Vector2(1112, 978), Vector2(1150, 950),
			Vector2(1186, 968), Vector2(1218, 940)]
		for i in trail_b.size():
			_foot(c, trail_b[i], Vector2.RIGHT, pow(0.88, i), Color(PRINT_COL, 0.55 * pow(0.9, i) * prints_fade))

func _foot(c: Node2D, p: Vector2, dir: Vector2, w: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		var ang := TAU * k / 14.0
		pts.append(p + Vector2(cos(ang) * 16.0, sin(ang) * 8.0 * w).rotated(dir.angle()))
	c.draw_colored_polygon(pts, col)
	var side := dir.orthogonal()
	for t in 4:
		var off := (-1.5 + t) * 4.2 * w
		c.draw_circle(p + dir * (21.0 - absf(off) * 0.35) + side * off, 2.2 * maxf(w, 0.6), col)

func _draw_door_opening(c: Node2D) -> void:
	var k := 1.0
	if sim.state.motion:
		k = smoothstep(0.0, 1.0, clampf(threshold_t / 2.2, 0.0, 1.0))
	c.draw_rect(Rect2(1228, 168, 206 * k, 736), Color(0.01, 0.012, 0.02))
	if k >= 1.0:
		c.draw_rect(Rect2(1228, 904, 206, 3), Color(0.55, 0.62, 0.7, 0.18))

func _draw_vignette(c: Node2D, a: float) -> void:
	if a <= 0.0:
		return
	var w := SIZE.x
	var h := SIZE.y
	var i := 260.0
	var o := Color(0, 0, 0, a)
	var n := Color(0, 0, 0, 0)
	var cols := PackedColorArray([o, o, n, n])
	for quad in [
			[Vector2(0, 0), Vector2(w, 0), Vector2(w - i, i), Vector2(i, i)],
			[Vector2(w, 0), Vector2(w, h), Vector2(w - i, h - i), Vector2(w - i, i)],
			[Vector2(w, h), Vector2(0, h), Vector2(i, h - i), Vector2(w - i, h - i)],
			[Vector2(0, h), Vector2(0, 0), Vector2(i, i), Vector2(i, h - i)]]:
		c.draw_polygon(PackedVector2Array(quad), cols)

func _ellipse(center: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var ang := TAU * k / n
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts

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
			if sim.view == "note":
				# Her initials, in a hand she doesn't remember using.
				c.draw_set_transform(Vector2(314, 880), -0.025)
				c.draw_string(hand, Vector2.ZERO, "Lamp service completed.  — A.M.",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.22, 0.22, 0.25, 0.9))
				c.draw_set_transform(Vector2.ZERO)
		"drawer":
			_draw_drawer(c)
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
	_text(c, "Observer: A. Mercer. Located.", Vector2(0, 380), 36, Color("8fa6e0"), hand, SIZE.x)
	_text(c, "Tide I continues.", Vector2(0, 450), 28, Color(PAPER, 0.75), serif, SIZE.x)
	_text(c, "You noted %d of %d things." % [sim.state.seen.size(), OfficeSim.OBSERVATIONS.size()],
		Vector2(0, 540), 22, Color(PAPER, 0.5), serif, SIZE.x)
	_text(c, "End of the Intake Office slice.", Vector2(0, 1000), 18, Color(PAPER, 0.4), serif, SIZE.x)
	if end_t > END_GRACE:
		_button(c, END_BUTTON, "Play again")

func _draw_repair(c: Node2D) -> void:
	c.draw_texture_rect(textures["repair_panel"], Rect2(Vector2.ZERO, SIZE), false)
	# Water damage over the solved steps and reference: stained, tide-marked, dripping.
	var stain := Color("b8a47c", 0.55)
	var mark := Color("8f7a55", 0.45)
	for blob in [[Vector2(1010, 356), 44], [Vector2(1090, 350), 40], [Vector2(1160, 362), 36],
			[Vector2(960, 362), 30], [Vector2(1050, 575), 70], [Vector2(980, 590), 50],
			[Vector2(1120, 590), 55], [Vector2(1060, 660), 62], [Vector2(980, 690), 48],
			[Vector2(1150, 690), 52], [Vector2(1080, 720), 40], [Vector2(1220, 670), 34]]:
		c.draw_circle(blob[0], blob[1], stain)
		c.draw_arc(blob[0], blob[1], 0, TAU, 48, mark, 2.0, true)
	for drip in [[Vector2(1068, 758), 34], [Vector2(986, 736), 22], [Vector2(1162, 740), 28]]:
		c.draw_line(drip[0], drip[0] + Vector2(0, drip[1]), Color("8f7a55", 0.3), 2.0)
		c.draw_circle(drip[0] + Vector2(0, drip[1]), 2.4, Color("8f7a55", 0.3))
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

func _draw_logbook(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.96))
	var page := Rect2(204, 110, 1040, 860)
	var lit: bool = sim.state.p01_complete
	c.draw_rect(page, Color("d9cfb2"))
	c.draw_rect(page, Color("8f7a55"), false, 2)
	_text(c, "GREYWAKE SURVEY STATION — TIDE LOG", page.position + Vector2(48, 66), 26, INK, serif, 900, HORIZONTAL_ALIGNMENT_LEFT)
	var obs_pos := page.position + Vector2(48, 104)
	_text(c, "Observer: E. Venn", obs_pos, 22, Color(INK, 0.7), hand, 600, HORIZONTAL_ALIGNMENT_LEFT)
	if lit and sim.stage() >= 3:
		var w := hand.get_string_size("Observer: E. Venn", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		c.draw_line(obs_pos + Vector2(0, -7), obs_pos + Vector2(w, -7), INK, 2.0)
		_text(c, "A. Mercer", obs_pos + Vector2(w + 18, 0), 24, BLUE_INK, hand, 300, HORIZONTAL_ALIGNMENT_LEFT)
	var rows := sim.log_rows()
	var many := rows.size() > 9
	var step := 52 if many else 70
	var ink_size := 21 if many else 23
	var hand_size := 23 if many else 25
	var y := page.position.y + 170
	for x in [page.position.x + 40, page.position.x + 210, page.position.x + 340, page.position.x + 500]:
		c.draw_line(Vector2(x, y - 40), Vector2(x, page.end.y - 40), Color(INK, 0.15), 1.0)
	var hand_i := 0
	for r in rows.size():
		var e: Array = rows[r]
		c.draw_line(Vector2(page.position.x + 30, y + 14), Vector2(page.end.x - 30, y + 14), Color(INK, 0.18), 1.0)
		var idx := -1
		if e[4]:
			idx = hand_i
			hand_i += 1
		if idx > log_shown_hand:
			y += step   # not written yet: an empty ruled line
			continue
		var col := BLUE_INK if e[4] else Color(INK, 0.85)
		var size := hand_size if e[4] else ink_size
		if not lit:
			col = Color(INK, 0.25)
			_text(c, e[0], Vector2(page.position.x + 52, y), size, col, hand, 160, HORIZONTAL_ALIGNMENT_LEFT)
			_text(c, e[1], Vector2(page.position.x + 222, y), size, col, hand, 120, HORIZONTAL_ALIGNMENT_LEFT)
			y += step
			continue
		_text(c, e[0], Vector2(page.position.x + 52, y), size, col, hand, 160, HORIZONTAL_ALIGNMENT_LEFT)
		_text(c, e[1], Vector2(page.position.x + 222, y), size, col, hand, 120, HORIZONTAL_ALIGNMENT_LEFT)
		_text(c, e[2], Vector2(page.position.x + 352, y), size, col, hand, 150, HORIZONTAL_ALIGNMENT_LEFT)
		var note_pos := Vector2(page.position.x + 512, y)
		if e[4]:
			var n: int = e[3].length()
			var writing := idx == log_shown_hand
			if writing:
				n = mini(int(floor(reveal_t * REVEAL_CPS)), n)
			_draw_handwriting(c, e[3], n, note_pos, size, r, writing)
		else:
			_text(c, e[3], note_pos, size, col, hand, 500, HORIZONTAL_ALIGNMENT_LEFT)
		y += step
	if not lit:
		c.draw_rect(page, Color(0.02, 0.03, 0.05, 0.97))
		c.draw_rect(page, Color("8f7a55", 0.12), false, 2)
		var spot := get_global_mouse_position()
		c.draw_circle(spot, 120, Color(0.85, 0.8, 0.65, 0.07))
		_text(c, "Too faint to read by torchlight.", Vector2(0, 560), 30, Color(PAPER, 0.75), hand, SIZE.x)

## Her hand, glyph by glyph: seeded jitter, a forward slant, and wet ink at the nib.
func _draw_handwriting(c: Node2D, text: String, count: int, pos: Vector2, size: int, row: int,
		wet: bool) -> void:
	var g := RandomNumberGenerator.new()
	var x := pos.x
	for i in count:
		g.seed = 18 + row * 97 + i
		var dy := g.randf_range(-2.0, 2.0)
		var rot := g.randf_range(-0.06, 0.06)
		var ch := text.unicode_at(i)
		var a := 0.6 if wet and i >= count - 6 else 1.0
		c.draw_set_transform_matrix(Transform2D(rot, Vector2.ONE, HAND_SKEW, Vector2(x, pos.y + dy)))
		c.draw_char(hand, Vector2.ZERO, text[i], size, Color(BLUE_INK, a))
		x += hand.get_char_size(ch, size).x
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_drawer(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.94))
	if sim.state.drawer_open:
		_draw_drawer_open(c)
		if drawer_k < 1.0:
			# The front slides away to show what he locked in.
			var off := Vector2(0, 520 * smoothstep(0.0, 1.0, drawer_k))
			_draw_drawer_front(c, off, false)
	else:
		_draw_drawer_front(c, Vector2.ZERO, true)

func _draw_drawer_front(c: Node2D, off: Vector2, interactive: bool) -> void:
	c.draw_rect(Rect2(DRAWER_FRONT.position + off, DRAWER_FRONT.size), Color("5a3d26"))
	c.draw_rect(Rect2(DRAWER_FRONT.position + off, DRAWER_FRONT.size), Color("3a2716"), false, 2)
	c.draw_rect(Rect2(DRAWER_PLATE.position + off, DRAWER_PLATE.size), BRASS)
	_text(c, "E.V. — Open at the hour she mended it.", DRAWER_PLATE.position + off + Vector2(0, 46), 24,
		INK, hand, DRAWER_PLATE.size.x)
	var code: Array = sim.state.drawer_dial
	for i in 4:
		var r := _dial_rect(i)
		r.position += off
		c.draw_rect(r, PAPER)
		c.draw_rect(r, INK, false, 2)
		_text(c, "▲", r.position + Vector2(0, 26), 18, Color(INK, 0.5), serif, r.size.x)
		_text(c, str(code[i]), r.position + Vector2(0, 124), 96, INK, serif, r.size.x)
	if interactive:
		_button(c, DRAWER_TRY, "Try the drawer")

func _draw_drawer_open(c: Node2D) -> void:
	c.draw_rect(DRAWER_FRONT, Color("1c130c"))
	# WATCH: stopped at 18:52, the minute she mended the lamp.
	c.draw_circle(WATCH_C, WATCH_R + 4, BRASS)
	c.draw_circle(WATCH_C, WATCH_R, Color("d8cfb4"))
	for i in 12:
		var d := Vector2(sin(TAU * i / 12.0), -cos(TAU * i / 12.0))
		c.draw_line(WATCH_C + d * 100, WATCH_C + d * 112, INK, 3.0 if i % 3 == 0 else 1.5)
	var hour_a := (6.0 + 52.0 / 60.0) / 12.0 * TAU
	var min_a := 52.0 / 60.0 * TAU
	c.draw_line(WATCH_C, WATCH_C + Vector2(sin(hour_a), -cos(hour_a)) * 60, INK, 6.0, true)
	c.draw_line(WATCH_C, WATCH_C + Vector2(sin(min_a), -cos(min_a)) * 95, INK, 3.0, true)
	c.draw_circle(WATCH_C, 6, INK)
	c.draw_polyline(PackedVector2Array([WATCH_C + Vector2(-96, -52), WATCH_C + Vector2(-30, -14),
		WATCH_C + Vector2(18, -40), WATCH_C + Vector2(88, 30)]), Color(1, 1, 1, 0.35), 2.0, true)
	_text(c, "stopped 18:52", Vector2(480, 770), 22, PAPER, hand, 300, HORIZONTAL_ALIGNMENT_LEFT)
	# PHOTO: this window from the sea side, at night. Her at the desk.
	var ctr := PHOTO_RECT.get_center()
	c.draw_set_transform(ctr, 0.04)
	var half := PHOTO_RECT.size / 2.0
	c.draw_rect(Rect2(-half, PHOTO_RECT.size), Color("d8d0bc"))
	var img := Rect2(-half.x + 18, -half.y + 18, PHOTO_RECT.size.x - 36, PHOTO_RECT.size.y - 70)
	c.draw_rect(img, Color("1a1f24"))
	var win := Rect2(-100, img.position.y + 26, 200, 150)
	var pw := win.size.x / 3.0
	var ph := win.size.y / 2.0
	for i in 3:
		c.draw_rect(Rect2(win.position + Vector2(pw * i, 0), Vector2(pw, ph)), Color(AMBER, 0.18))
		c.draw_rect(Rect2(win.position + Vector2(pw * i, ph), Vector2(pw, ph)), Color(AMBER, 0.75))
	for k in 3:   # the lamp, as a soft glow rather than a disc
		c.draw_circle(win.position + Vector2(pw * 0.5, ph * 1.5), 30 - k * 9, Color("f0d9a0", 0.6 / 3.0))
	var base := win.position + Vector2(pw * 1.5, win.size.y)
	c.draw_colored_polygon(PackedVector2Array([base + Vector2(-26, 0), base + Vector2(26, 0),
		base + Vector2(16, -26), base + Vector2(-16, -26)]), Color(0.03, 0.03, 0.04))
	c.draw_colored_polygon(_ellipse(base + Vector2(0, -40), 14, 17, 16), Color(0.03, 0.03, 0.04))
	var muntin := Color("c9c0a8", 0.7)
	c.draw_rect(win, muntin, false, 4)
	for i in [1, 2]:
		c.draw_line(win.position + Vector2(pw * i, 0), win.position + Vector2(pw * i, win.size.y), muntin, 4)
	c.draw_line(win.position + Vector2(0, ph), win.position + Vector2(win.size.x, ph), muntin, 4)
	var sea := Rect2(img.position.x, img.end.y - 46, img.size.x, 46)
	c.draw_rect(sea, Color("22303a"))
	for k in 3:
		var yy := sea.position.y + 10 + k * 12
		c.draw_line(Vector2(img.position.x + 14 + k * 30, yy), Vector2(img.end.x - 40 + k * 10, yy + 1),
			Color(0.75, 0.8, 0.82, 0.35), 1.0)
	c.draw_rect(img, Color(0.45, 0.35, 0.2, 0.18))
	_text(c, "Greywake. 18 Oct.", Vector2(-half.x, half.y - 18), 20, INK, hand, PHOTO_RECT.size.x)
	c.draw_set_transform(Vector2.ZERO)

func _draw_notebook(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.97))
	var page := Rect2(164, 90, 1120, 900)
	c.draw_rect(page, Color("e4dcc4"))
	_text(c, "NOTEBOOK — A. MERCER", page.position + Vector2(50, 64), 26, INK, serif, 900, HORIZONTAL_ALIGNMENT_LEFT)
	_text(c, "Now: " + OfficeSim.OBJECTIVES[sim.objective()], page.position + Vector2(50, 112), 24,
		Color("5b3a2e"), hand, 1000, HORIZONTAL_ALIGNMENT_LEFT)
	var top := page.position.y + 180
	var bottom := page.end.y - 24
	var ids := []
	for id in OfficeSim.OBSERVATIONS:
		if sim.has_seen(id):
			ids.append(id)
	if ids.is_empty():
		_text(c, "Nothing recorded yet. Look around the office.", Vector2(page.position.x + 80, top), 22,
			Color(INK, 0.6), hand, 900, HORIZONTAL_ALIGNMENT_LEFT)
		return
	# Late in the slice there is a lot to keep: shrink, then split into two columns,
	# so every entry stays on the page. Evidence is never dropped.
	var layout := [22, 960, 1]
	for opt in [[22, 960, 1], [20, 960, 1], [18, 960, 1], [18, 460, 2], [17, 460, 2], [16, 460, 2]]:
		layout = opt
		if _notebook_flow(c, ids, opt, top, bottom, page.position.x, false):
			break
	_notebook_flow(c, ids, layout, top, bottom, page.position.x, true)

## Lays out notebook entries in 1 or 2 columns; returns true if they fit above `bottom`.
func _notebook_flow(c: CanvasItem, ids: Array, layout: Array, top: float, bottom: float, left: float,
		draw: bool) -> bool:
	var size: int = layout[0]
	var width: float = layout[1]
	var columns: int = layout[2]
	var col := 0
	var y := top
	for id in ids:
		var h := _wrapped(c, OfficeSim.OBSERVATIONS[id], Vector2(0, 0), size, INK, width, false)
		if y + h - size > bottom and col + 1 < columns:
			col += 1
			y = top
		var x := left + 60 + col * (width + 60)
		if draw:
			c.draw_circle(Vector2(x, y - size * 0.36), 4, Color(INK, 0.6))
			_wrapped(c, OfficeSim.OBSERVATIONS[id], Vector2(x + 20, y), size, INK, width)
		y += h + size * 0.45
	return y - size * 1.9 <= bottom

func _draw_menu(c: Node2D) -> void:
	if sim.return_view == "title":
		c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color("070b0f"))   # nothing of the room before the opening
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.93))
	_text(c, "Paused" if sim.return_view != "title" else "Options", Vector2(0, 260), 40, PAPER, serif, SIZE.x)
	var labels := ["Resume", "Motion & flicker: " + ("on" if sim.state.motion else "off"),
		"Soften sudden sounds: " + ("on" if sim.state.soft_audio else "off"), "Restart slice"]
	for i in labels.size():
		_button(c, _menu_rect(i), labels[i])

# ---------------------------------------------------------------------------
# drawing: HUD
# ---------------------------------------------------------------------------
func _draw_hud() -> void:
	var c := hud
	if sim.view in ["title", "end", "menu"]:
		subtitle.visible = false
		return
	subtitle.visible = true
	c.draw_rect(Rect2(20, 994, 1408, 80), Color(0.03, 0.06, 0.08, 0.9))
	for b in HUD_BUTTONS:
		_button(c, b[1], b[2], false, 21)
	if sim.is_closeup() or sim.view == "notebook":
		_button(c, BACK_RECT, "Back", false, 21)
	if hover_id != "" and sim.view == "room":
		for h in HOTSPOTS:
			if h[0] == hover_id:
				var p := get_global_mouse_position() + Vector2(22, 34)
				var w := serif.get_string_size(h[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 20
				c.draw_rect(Rect2(p - Vector2(10, 24), Vector2(w, 34)), Color(0.03, 0.06, 0.08, 0.8))
				c.draw_string(serif, p, h[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)
	if sim.view == "threshold" and threshold_t >= THRESHOLD_CONTINUE:
		var a := clampf((threshold_t - THRESHOLD_CONTINUE) / 1.5, 0.0, 1.0) * 0.6
		_text(c, "Click to step into the corridor.", Vector2(0, 966), 20, Color(PAPER, a), hand, SIZE.x)
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
func _wrapped(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, width: float,
		draw := true) -> float:
	var y := pos.y
	var line := ""
	for word in s.split(" "):
		var trial := word if line == "" else line + " " + word
		if serif.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			if draw:
				c.draw_string(serif, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			y += size * 1.45
			line = word
		else:
			line = trial
	if line != "":
		if draw:
			c.draw_string(serif, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		y += size * 1.45
	return y
