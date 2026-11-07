extends Node2D
## Intake Office slice: renders an OfficeSim, plays its events, owns light and sound.
##
## Layering:
##   world (affected by CanvasModulate + 2D lights): room plate, lamp, overlays
##   CanvasLayer 1  "deep":  the open doorway, unlit: what is down there makes its own light
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
## Her ink as it reads on black (the end card): BLUE_INK fails contrast on the dark.
const NIGHT_INK := Color("8fa6e0")
const BRASS := Color("b08a4a")

## Ambient modulate per story stage (0 arrival .. 3 seat wet).
const MODULATE := [Color(0.30, 0.33, 0.42), Color(0.46, 0.44, 0.48),
	Color(0.22, 0.23, 0.31), Color(0.22, 0.21, 0.30)]
## The lamp's pool of light shrinks as the story closes in.
const LAMP_SCALE := [3.2, 3.2, 1.85, 1.45]
## The window's own light per stage, only with the painted plates (they were painted to be
## seen; the modulate alone leaves the glass black). Stage 3 is lit from below.
const SEA_GLOW := [0.0, 0.0, 0.45, 0.95]
const SEA_GLOW_COL := Color(0.62, 0.76, 0.76)
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
const END_BUTTON := Rect2(574, 880, 300, 70)

# Closure report geometry.
const REPORT_PAGE := Rect2(284, 150, 880, 820)
const REPORT_SIGN := Rect2(574, 850, 300, 76)

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
const END_GRACE := 1.5
const LINE_LINGER := 4.0      # a line with nothing after it clears this long after its hold
const ADVANCE_SWALLOW := 0.35 # a click this soon after a story line went up is swallowed
const VOICE_CAP := 2          # live copies of one one-shot at most
const RESTART_ARM := 3.0      # seconds the menu's restart stays armed after the first click
const FEEDBACK_HOLD := 1.2    # a click's line stays up at least this long before the next click replaces it
const BACKLOG_SQUEEZE := 0.6  # read-time factor for older story lines when a new reveal arrives

## The tide breath. Mirrors tools/build_audio.py exactly: the room's swell, the lamp,
## the threshold and the sea all follow the breath loop's own playback phase.
const BREATH_PERIOD := 11.0
const BREATH_IN := 4.0
const BREATH_OUT_END := 8.8
const BREATH_OUT_PEAK := 1.1
## At the door the loop jumps here, so the first inhale starts as the 3.4 s line does.
const THRESHOLD_BREATH_SEEK := 7.6

## The window glass in the arrival plate, measured from office_arrival.png: a six-over-one
## sash. The sea tips inside these panes; the bars between them are the plate's own pixels.
const GLASS := Rect2(482, 143, 318, 402)
const PANES := [
	Rect2(483, 144, 100, 108), Rect2(593, 144, 100, 108), Rect2(702, 144, 98, 108),
	Rect2(483, 262, 100, 93), Rect2(593, 262, 100, 93), Rect2(702, 262, 98, 93),
	Rect2(483, 368, 317, 177),
]
const HORIZON_PIVOT := Vector2(641, 472)
const TILT_DEG := -7.0
const PANE_PAD := 28          # edge-extended margin so a tipped pane never shows its frame
const PALM_COL := Color(0.86, 0.90, 0.94)
## The open door's slab and the corridor's vanishing point, off-centre and low.
const DOOR_SLAB := Rect2(1228, 168, 206, 736)
const VP := Vector2(1316, 548)
## The chart's fallback contours: centred on the ninth piling, clipped to the sheet.
const CONTOUR_C := Vector2(338, 300)
const CONTOUR_CLIP := Rect2(140, 192, 238, 262)

var save_path := DEFAULT_SAVE_PATH
var sim := OfficeSim.new()
var textures := {}
var serif: SystemFont
var hand: SystemFont

# nodes
var room: Node2D
var deep: Node2D
var close: Node2D
var hud: Node2D
var shade: CanvasModulate
var torch: PointLight2D
var lamp_glow: PointLight2D
var sea_glow: PointLight2D     # the window's own light: the painted sea is lit from below
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
var pending_sfx: Array = []    # [id, time_left, beat]
var oneshots: Array = []       # live one-shot players
var lamp_tween: Tween
var dev := false

var click_id := 0             # increments on every dispatch; lines remember theirs
var cur_hold := 0.0            # how long the line on screen must stay up
var cur_click := 0             # the click that put it there
var last_targets := {}         # the mix targets of the last audio tick (tests read these)
var hush := 0.0                # seconds the room falls silent around the knock
var palms_k := 0.0             # 0..1 palm marks on the glass after the knock
var palms_armed := false
var pane_tex: Array = []       # edge-padded window panes for the tipped sea, built lazily
var door_panner: AudioEffectPanner
var breath_clock := 0.0        # breath phase fallback when the loop isn't playing
var still_t := 0.0             # seconds the cursor has held still at the threshold
var still_anchor := Vector2.INF
var continue_ready := false
var continue_t := 0.0          # threshold_t when continue became available
var still_spoken := false
var door_env := 0.5            # the doorway's breath, frozen when she holds hers
var creep_t := 99.0            # seconds since the shadow last leaned
var deep_drawn := false        # the doorway layer has something on it
var intrusion_written := false # the notebook's stranger line has written itself once
var intrusion_t := 0.0

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
var contours_k := 1.0          # 0..1 fade of Venn's ring contours on the chart
var away_shown := 0            # sim.state.returns as the view last drew it
var away_from := 0             # changes up to this index are fully in; later ones fade by away_k
var away_k := 1.0
var restart_armed_at := -INF   # time of the menu's first restart click
var slab_a := 0.0              # subtitle slab opacity: it fades out when nothing is being said
var pane_src := ""             # which plate the tipped panes were cut from
var shown_log: Array = []      # every line that went up, in order (tests and drivers read it)
var played_log: Array = []     # [sfx id, shown_log.size() when it played]
var last_events: Array = []    # the sim events of the last dispatch

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
		if is_instance_valid(p):
			p.stop()
			p.stream = null
			p.queue_free()
	for p in oneshots:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
			p.queue_free()
	players.clear()
	oneshots.clear()

# ---------------------------------------------------------------------------
# setup
# ---------------------------------------------------------------------------
func _load_textures() -> void:
	var f := FileAccess.open("res://asset_manifest.json", FileAccess.READ)
	var manifest = JSON.parse_string(f.get_as_text())
	for asset in manifest.assets:
		var path: String = "res://" + asset.path
		if asset.path.ends_with(".png") and ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				textures[asset.id] = tex

## A texture by id, or null: every painted stage plate is optional, with a drawn fallback.
func _tex(id: String) -> Texture2D:
	return textures.get(id)

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

	# The sea makes its own light. Shaped to the glass, so the painted water reads through
	# the room's darkness without lifting anything else.
	sea_glow = PointLight2D.new()
	var glass_img := Image.create(int(GLASS.size.x), int(GLASS.size.y), false, Image.FORMAT_RGBA8)
	glass_img.fill(Color.WHITE)
	sea_glow.texture = ImageTexture.create_from_image(glass_img)
	sea_glow.position = GLASS.get_center()
	sea_glow.color = SEA_GLOW_COL
	sea_glow.energy = 0.0
	add_child(sea_glow)

	torch = PointLight2D.new()
	torch.texture = _radial(512, 0.25)
	torch.texture_scale = 0.95
	torch.color = TORCH_WARM
	torch.energy = 1.15
	add_child(torch)

	var deep_layer := CanvasLayer.new()
	deep_layer.layer = 1
	add_child(deep_layer)
	deep = Node2D.new()
	deep_layer.add_child(deep)
	deep.draw.connect(_draw_deep)

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
	subtitle.position = Vector2(48, 996)
	subtitle.size = Vector2(1352, 76)
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
	# The doorway's own bus: whatever breathes in the corridor sits a little to the right.
	if AudioServer.get_bus_index("Door") == -1:
		AudioServer.add_bus()
		var bi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, "Door")
		AudioServer.set_bus_send(bi, "Master")
		AudioServer.add_bus_effect(bi, AudioEffectPanner.new())
	var door_bus := AudioServer.get_bus_index("Door")
	for i in AudioServer.get_bus_effect_count(door_bus):
		if AudioServer.get_bus_effect(door_bus, i) is AudioEffectPanner:
			door_panner = AudioServer.get_bus_effect(door_bus, i)
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
		if id == "breath":
			p.bus = "Door"
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
	if _at_threshold() or deep_drawn:
		deep.queue_redraw()
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
	if palms_armed and palms_k < 1.0:
		palms_k = minf(1.0, palms_k + dt / 2.0) if sim.state.motion else 1.0
	if contours_k < 1.0:
		contours_k = minf(1.0, contours_k + dt / 2.0) if sim.state.motion else 1.0
	var returns := int(sim.state.returns)
	if returns != away_shown:
		# A change she comes back to fades in; anything else (a load, a restart) is just there.
		var fades: bool = returns > away_shown and sim.state.motion
		away_from = away_shown if fades else returns
		away_k = 0.0 if fades else 1.0
		away_shown = returns
	if away_k < 1.0:
		away_k = minf(1.0, away_k + dt / 1.2) if sim.state.motion else 1.0
	creep_t += dt
	breath_clock += dt
	if sim.state.motion:
		var mx := clampf(get_global_mouse_position().x, 560.0, 720.0)
		eye_x = lerpf(eye_x, mx, clampf(dt * 0.8, 0.0, 1.0))
	else:
		eye_x = 640.0
	if _at_threshold():
		threshold_t += dt
		_tick_still(dt, get_global_mouse_position())
	if sim.view == "end":
		end_t += dt
	if sim.view == "notebook" and _intrusion_writing():
		intrusion_t += dt
	breath_hold = maxf(0.0, breath_hold - dt)
	hush = maxf(0.0, hush - dt)

## The threshold asks her to hold still. The cursor is her body: once it has stayed within
## 4 px for long enough (or the fallback passes, for anyone who can't), she may go on.
func _tick_still(dt: float, mouse: Vector2) -> void:
	if threshold_t < OfficeSim.THRESHOLD_STILL_AFTER:
		return
	if still_anchor == Vector2.INF or mouse.distance_to(still_anchor) > 4.0:
		still_anchor = mouse
		if not still_spoken:
			still_t = 0.0
	else:
		still_t += dt
	if not _breath_held():
		door_env = _breath_env(_breath_phase())
	if not still_spoken and (still_t > 3.0 or threshold_t >= OfficeSim.THRESHOLD_FALLBACK):
		still_spoken = true
		continue_ready = true
		continue_t = threshold_t
		# After anything still being said, never squeezed in front of it.
		_insert_line(OfficeSim.THRESHOLD_STILL_LINE, _story_backlog_end(), true)

## True once she has held still long enough that the corridor stops breathing.
func _breath_held() -> bool:
	return still_spoken or threshold_t >= OfficeSim.THRESHOLD_STILL_AFTER and still_t > 1.2

## The breath envelope at a phase in [0, BREATH_PERIOD): inhale, exhale, then stillness.
static func _breath_env(phase: float) -> float:
	if phase < BREATH_IN:
		return pow(sin(PI / 2.0 * phase / BREATH_IN), 2)
	if phase < BREATH_OUT_END:
		return BREATH_OUT_PEAK * pow(cos(PI / 2.0 * (phase - BREATH_IN) / (BREATH_OUT_END - BREATH_IN)), 2)
	return 0.0

## Where the breath loop is now. The loop itself is the clock, so sound and light agree.
func _breath_phase() -> float:
	var p: AudioStreamPlayer = players.get("breath")
	if p and p.playing:
		return fmod(p.get_playback_position(), BREATH_PERIOD)
	return fmod(breath_clock, BREATH_PERIOD)

## The breath for drawing: 0..1, constant at the midpoint with Motion off.
func _env_drawn() -> float:
	if not sim.state.motion:
		return 0.5
	return clampf(_breath_env(_breath_phase()), 0.0, 1.0)

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
	var scale_target: float = LAMP_SCALE[s]
	var scale_rate := 0.6
	if s >= 2 and sim.state.motion and not at_door:
		# The pool of light breathes with the room.
		scale_target *= 1.0 + 0.04 * (_env_drawn() * 2.0 - 1.0)
		scale_rate = 1.5
	lamp_glow.texture_scale = lerpf(lamp_glow.texture_scale, scale_target, clampf(dt * scale_rate, 0.0, 1.0))
	var glow_target := 0.0
	if _tex("office_s2") and sim.state.started:
		glow_target = SEA_GLOW[s]
		if s == 3 and _tex("office_s3"):
			glow_target = lerpf(SEA_GLOW[2], SEA_GLOW[3], smoothstep(0.0, 1.0, tilt_k))
		if at_door:
			glow_target *= 0.5
	sea_glow.energy = lerpf(sea_glow.energy, glow_target, clampf(dt * 1.5, 0.0, 1.0))
	if sim.state.p01_complete:
		var lamp_target := 1.05
		if at_door:
			lamp_target = 0.35
		elif s >= 2:
			# The lamp swells and sags with the breath. With Motion off it holds the midpoint.
			lamp_target *= 0.96 + 0.04 * _env_drawn()
		var rate := 1.0 if at_door else 3.0
		lamp_glow.energy = lerpf(lamp_glow.energy, lamp_target, clampf(dt * rate, 0.0, 1.0))
	else:
		lamp_glow.energy = 0.0
	if flash.color.a > 0.0:
		flash.color.a = maxf(0.0, flash.color.a - dt * 4.0)

func _knock_pending() -> bool:
	for p in pending_sfx:
		if p[0] == "knock_glass":
			return true
	return false

func _tick_audio(dt: float) -> void:
	var s := sim.stage()
	var env := clampf(_breath_env(_breath_phase()), 0.0, 1.0)
	# The sea goes quiet after the first read, except while she is still reading it.
	var silent: bool = sim.state.log_read and (sim.view != "logbook" or sim.state.heard_silence \
		or sim.state.prints_seen)
	var focus := 0.55 if sim.is_closeup() or sim.view == "notebook" else 1.0
	var target := {
		"room": [0.30, 0.30, 0.12, 0.12][s],
		"sea": 0.0 if silent else 0.75 * focus,
		"wind": 0.15 * focus if silent else [0.35, 0.35, 0.15, 0.18][s] * focus,
		"drip": [0.45, 0.45, 0.0, 0.6][s] * focus,
		"hum": 0.18 if sim.state.p01_complete else 0.0,
		"drone": [0.0, 0.0, 0.30, 0.50][s],
		"heartbeat": 0.0,
		"ring": [0.0, 0.0, 0.05, 0.07][s],
		"breath": 0.16 if s == 3 else 0.0,
		"pen": 0.45 if _reveal_active() or _end_row_writing() or _intrusion_writing() else 0.0,
	}
	# The sea and the wind drain away together; the pen stops with the nib.
	var rates := {"sea": 0.9, "wind": 0.9 if silent else 0.8, "pen": 4.0}
	var hum_pitch := 1.0 - 0.012 * s
	if not sim.state.started:
		for k in target: target[k] = 0.0
		target["sea"] = 0.4
		target["wind"] = 0.3
	elif sim.view == "end":
		for k in target: target[k] = 0.0
		target["drone"] = 0.25 if _motif_playing() else 0.4
		target["ring"] = 0.03
		target["pen"] = 0.45 if _end_row_writing() else 0.0
	elif _at_threshold():
		for k in target: target[k] = 0.0
		target["drone"] = 0.45
		target["ring"] = 0.08
		if _breath_held():
			# She holds her breath. So does the sea.
			rates["breath"] = 2.5
			rates["sea"] = 2.5
		else:
			target["breath"] = 0.55 if threshold_t >= 2.8 else 0.0
			target["sea"] = 0.40 * env   # the silent sea comes back only on the exhale
	else:
		if s >= 2:
			# The room has been breathing all along: everything swells with the loop.
			var swell := lerpf(0.55, 1.0, env)
			for k in ["room", "hum", "drip", "drone"]:
				target[k] *= swell
			hum_pitch *= 1.0 + 0.006 * (env * 2.0 - 1.0)
		if s == 3 and (hush > 0.0 or _knock_pending()):
			target["drip"] = 0.0
		if hush > 0.0:
			# Everything stops to listen to the glass.
			for k in target:
				target[k] = 0.0
				rates[k] = 4.0
			target["ring"] = 0.10
		elif breath_hold > 0.0:
			# The room holds its breath when she finds the prints.
			for k in target:
				if k != "heartbeat" and k != "ring":
					target[k] = 0.0
					rates[k] = 3.0
	if sim.view != "end" and _motif_playing():
		target["drone"] *= 0.6   # the harmonium sits on top of the drone, not inside it
	last_targets = target
	for id in players:
		mix[id] = move_toward(mix[id], target.get(id, 0.0), dt * rates.get(id, 0.8))
		players[id].volume_db = linear_to_db(maxf(mix[id], 0.0001))
	if players.has("hum"):
		var hum: AudioStreamPlayer = players["hum"]
		hum.pitch_scale = lerpf(hum.pitch_scale, hum_pitch, clampf(dt * 0.5, 0.0, 1.0))
	if door_panner:
		door_panner.pan = move_toward(door_panner.pan, 0.6 if _at_threshold() else 0.0, dt * 1.0)

## True while a live one-shot is playing the motif (or its short tail).
func _motif_playing() -> bool:
	for p in oneshots:
		if is_instance_valid(p) and p.playing and p.get_meta("sfx_id", "") in ["motif", "motif_short"]:
			return true
	return false

func _tick_sfx(dt: float) -> void:
	for i in range(pending_sfx.size() - 1, -1, -1):
		pending_sfx[i][1] -= dt
		var id: String = pending_sfx[i][0]
		if id == "knock_glass" and pending_sfx[i][1] <= 0.6 and hush == 0.0:
			hush = 1.6
		if pending_sfx[i][1] <= 0.0:
			pending_sfx.remove_at(i)
			_play_sfx_now(id)

# ---------------------------------------------------------------------------
# subtitles: a scheduler keyed to absolute time
# ---------------------------------------------------------------------------
## Every queued line is {text, due, story, beat, click, hold}: `click` is the dispatch that
## queued it, `beat` the click of the reveal it belongs to (0 for none), and `hold` how
## long it stays up once shown.
static func min_read(text: String) -> float:
	return 0.7 + 0.028 * text.length()

## A story line on screen can't be replaced by a click until it has been readable.
func _cur_protected() -> bool:
	return cur_story and cur_text != "" and time - cur_since < cur_hold

## Queued lines never cut off any line, story or not, before its hold: without this an
## overdue story line would replace a click's fresh line on the very next frame. A non-story
## line yields early: to a newer click's line after FEEDBACK_HOLD, and to a waiting story
## line once it has had the squeezed read time, so chatter never starves a reveal.
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

## A new reveal is arriving: everything older that is still waiting is re-timed back to
## back from now at BACKLOG_SQUEEZE of its read time, so nothing is lost and nothing
## goes stale. Returns when the squeezed backlog ends.
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
	# The slab goes when nothing is being said, and comes straight back for the next line.
	if cur_text == "" and lines.is_empty():
		slab_a = maxf(0.0, slab_a - dt / 0.4)
	else:
		slab_a = minf(1.0, slab_a + dt / 0.15)

## A story chain is playing: a line of it is queued, or one is on screen and still held.
## While it plays, a click in the scene advances it instead of starting something new.
func chain_active() -> bool:
	for l in lines:
		if l.story:
			return true
	return cur_story and cur_text != "" and time - cur_since < cur_hold

## The player sets the chain's speed: bring its next line up now, with its own sounds.
## Everything queued moves up by the same amount, so nothing behind it changes order.
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
		if p[0] == "knock_glass" and p[1] <= 0.6 and hush == 0.0:
			hush = 1.6
		if p[1] <= 0.0:
			due_now.append(p)
			pending_sfx.remove_at(i)
	# The sounds a line waits for land before it does: the knock before "Three taps".
	due_now.sort_custom(func(a, b): return a[1] < b[1])
	for p in due_now:
		_play_sfx_now(p[0])
	lines.erase(next)
	_show_line(next.text, true, next.hold, next.click)

## A click (or tap) at `p`, exactly as the mouse handler does it. Drivers and tests use it.
## The HUD always answers; anywhere else, a playing chain is advanced, not interrupted.
func click(p: Vector2) -> void:
	var a := action_at(p)
	if a in ["notebook", "hint", "menu"]:
		dispatch(a)
		return
	if _chain_gates() and chain_active():
		advance()
		return
	if a != "":
		dispatch(a)

## Views where a playing chain holds clicks. The threshold has its own clock, and the
## title, end card and menu show no subtitles.
func _chain_gates() -> bool:
	return not sim.view in ["threshold", "title", "end", "menu"]

func _show_line(text: String, story: bool, hold := -1.0, from_click := -1) -> void:
	cur_text = text
	cur_story = story
	cur_click = click_id if from_click < 0 else from_click
	cur_since = time
	cur_hold = min_read(text) if hold < 0.0 else hold
	line_t = 0.0
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
## been up for less than FEEDBACK_HOLD, the new line goes to the front of the queue so
## feedback is never starved behind a reveal.
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
	var before := sim.view
	var chain_was := chain_active()
	var ev := sim.dispatch(action)
	last_events = ev
	# Story chains are atomic. In the scene a new one can only start once the last has
	# played out (click() advances a playing chain instead), so normally nothing is queued.
	# Anything that arrives while one plays (a Hint, a key) waits after it, whole and in
	# order: never squeezed in, never interleaved, never dropped. Its timed sounds move with it.
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
		creep_t = 0.0
	if before == "logbook":
		# Leaving mid-reveal: the lines are simply there next time.
		log_shown_hand = _in_hand_count()
		reveal_t = 0.0
	if before == "notebook" and sim.notebook_intrusion() != "":
		intrusion_written = true
	if sim.view == "notebook":
		intrusion_t = 0.0
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
	cur_hold = 0.0
	line_t = 0.0
	subtitle.text = ""
	shown_log.clear()
	played_log.clear()
	restart_armed_at = -INF
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
	creep_t = 99.0
	tilt_k = 0.0
	prints_fade = 1.0
	breath_hold = 0.0
	hush = 0.0
	palms_armed = false
	threshold_t = 0.0
	_reset_still()
	end_t = 0.0
	drawer_k = 1.0
	intrusion_written = false
	intrusion_t = 0.0
	flash.color.a = 0.0
	_apply_stage_instantly()

func _reset_still() -> void:
	still_t = 0.0
	still_anchor = Vector2.INF
	continue_ready = false
	continue_t = 0.0
	still_spoken = false
	door_env = 0.5

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
		"contours":
			contours_k = 0.0 if sim.state.motion else 1.0
		"threshold":
			threshold_t = 0.0
			_reset_still()
			hush = 0.0
			# A new scene. Room chatter stays behind; anything of the story still being said
			# is finished first, briskly, and the doorway's lines follow it.
			lines = lines.filter(func(l): return l.story)
			var base := maxf(time, _squeeze_backlog())
			for p in pending_sfx:
				if p[0] == "latch_near":
					_play_sfx_now(p[0])   # the door she is opening is the one that unlatched
			pending_sfx.clear()
			for l in OfficeSim.THRESHOLD_LINES:
				_insert_line(l[1], base + l[0], true)
			# Phase-lock the breath: the first inhale begins with the 3.4 s line.
			var seek := fposmod(THRESHOLD_BREATH_SEEK - (base - time), BREATH_PERIOD)
			breath_clock = seek
			if players.has("breath"):
				players["breath"].seek(seek)
		"turn":
			# She turns round. Nothing more is said in the room.
			lines.clear()
			cur_text = ""
			cur_story = false
			subtitle.text = ""
			pending_sfx = pending_sfx.filter(func(p): return p[0] in ["exhale_near", "motif"])
		"sea_fade", "dread", "log_write":
			pass  # carried by the mix, the room drawing and the logbook reveal

## Base levels for one-shots (dB), and the ones "Soften sudden sounds" turns down.
const SFX_DB := {"spark": -4.0, "sting": -6.0, "latch_far": -8.0, "latch_near": -5.0,
	"door": -6.0, "page": -10.0, "switch": -6.0, "seat": -6.0, "clink": -8.0,
	"knock_glass": -3.0, "dial": -16.0, "clunk": -10.0, "drawer": -9.0, "sign": -8.0, "nib": -14.0,
	"deep": -9.0, "motif": -14.0, "motif_short": -14.0, "exhale_near": -10.0}
const SFX_SOFT := ["spark", "latch_near", "sting", "door", "knock_glass", "clunk", "deep", "exhale_near"]

## The level a one-shot plays at, after the "Soften sudden sounds" cut.
func sfx_db(id: String) -> float:
	var db: float = SFX_DB.get(id, -6.0)
	if sim.state.soft_audio and id in SFX_SOFT:
		db -= 8.0 if id == "knock_glass" else 12.0
	return db

func _play_sfx_now(id: String) -> void:
	played_log.append([id, shown_log.size()])
	if id == "knock_glass":
		# The marks on the glass appear with the knock, whether or not the file loads.
		palms_armed = true
		palms_k = 0.0 if sim.state.motion else 1.0
	var stream := _load_audio(id)
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
	if id in ["door", "latch_near"]:
		p.bus = "Door"
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
	sea_glow.energy = SEA_GLOW[s] if _tex("office_s2") and sim.state.started else 0.0
	torch.color = TORCH_COLD if s >= 2 else TORCH_WARM
	tilt_k = 1.0 if s == 3 else 0.0
	palms_k = 1.0 if s == 3 else 0.0
	contours_k = 1.0
	away_shown = int(sim.state.returns)
	away_from = away_shown
	away_k = 1.0
	eye_x = 640.0
	if players.has("hum"):
		players["hum"].pitch_scale = 1.0 - 0.012 * s

func _redraw() -> void:
	room.queue_redraw()
	deep.queue_redraw()
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
		click(get_global_mouse_position())
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
					# Back out of a close-up goes through the same gate as a click.
					if _chain_gates() and chain_active():
						advance()
					else:
						dispatch("back")
			KEY_N:
				dispatch("notebook")
			KEY_H:
				dispatch("hint")
			KEY_F1:
				if OS.is_debug_build():
					dev = not dev
					_redraw()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
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
			return "restart" if _end_button_ready() and END_BUTTON.has_point(p) else ""
		"menu":
			var items := ["resume", "toggle_motion", "toggle_soft", "restart" if _restart_armed() else "restart_arm"]
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
					if _dial_up_rect(i).has_point(p):
						return "dial_%d" % i
					if _dial_down_rect(i).has_point(p):
						return "dial_down_%d" % i
				if DRAWER_TRY.has_point(p):
					return "try_drawer"
		"report":
			if not sim.state.report_filed:
				for i in 4:
					var r := _rtime_rect(i)
					if Rect2(r.position, Vector2(r.size.x, r.size.y / 2.0)).has_point(p):
						return "rtime_%d" % i
					if Rect2(r.position + Vector2(0, r.size.y / 2.0), Vector2(r.size.x, r.size.y / 2.0)).has_point(p):
						return "rtime_down_%d" % i
			for i in OfficeSim.REPORT_FIELDS.size():
				if _report_row(REPORT_FIELD_ROWS[i]).has_point(p):
					return "field_%d" % i
			if not sim.state.report_filed and REPORT_SIGN.has_point(p):
				return "file_report"
		"threshold":
			# Two ways out: turn round to the chair, or go on through the doorway.
			if _hotspot_rect("chair").has_point(p):
				return "turn"
			if continue_ready and _hotspot_rect("door").has_point(p):
				return "continue"
			return ""
	return ""

func _hotspot_rect(id: String) -> Rect2:
	for h in HOTSPOTS:
		if h[0] == id:
			return h[1]
	return Rect2()

func _restart_armed() -> bool:
	return time - restart_armed_at < RESTART_ARM

## What a dial shows: [above, current, below]. The top half turns it up, so the digit above
## is where an up click goes; the one below is where a down click goes.
static func dial_digits(v: int) -> Array:
	return [(v + 1) % 10, v, (v + 9) % 10]

func _menu_rect(i: int) -> Rect2:
	return Rect2(474, 330 + i * 100, 500, 76)

func _dial_rect(i: int) -> Rect2:
	return Rect2(424 + i * 160, 450, 120, 170)

## The top half of a dial turns it up, the bottom half down.
func _dial_up_rect(i: int) -> Rect2:
	var r := _dial_rect(i)
	return Rect2(r.position, Vector2(r.size.x, r.size.y / 2.0))

func _dial_down_rect(i: int) -> Rect2:
	var r := _dial_rect(i)
	return Rect2(r.position + Vector2(0, r.size.y / 2.0), Vector2(r.size.x, r.size.y / 2.0))

## The report's rows: the three choice fields sit on rows 0, 1 and 3; row 2 is the time.
const REPORT_FIELD_ROWS := [0, 1, 3]
const REPORT_TIME_ROW := 2

func _report_row(k: int) -> Rect2:
	return Rect2(324, 260 + k * 130, 800, 104)

func _rtime_rect(i: int) -> Rect2:
	return Rect2(820 + i * 66 + (22 if i >= 2 else 0), 260 + REPORT_TIME_ROW * 130, 56, 104)

# ---------------------------------------------------------------------------
# drawing: room (world space, lit)
# ---------------------------------------------------------------------------
func _draw_room() -> void:
	if textures.is_empty():
		return
	var c := room
	var s := sim.stage()
	var full := Rect2(Vector2.ZERO, SIZE)
	# The painted stage plates, when present: s2 is the base from the log on, and at s3 the
	# tipped plate crossfades in over it with the tilt. Without them, the drawn fallback.
	var base_id := "office_s2" if s >= 2 and _tex("office_s2") else "office_arrival"
	c.draw_texture_rect(textures[base_id], full, false)
	var s3_plate: Texture2D = _tex("office_s3") if s == 3 else null
	var tilt := 0.0
	if s == 3:
		tilt = deg_to_rad(TILT_DEG) * smoothstep(0.0, 1.0, tilt_k)
		if s3_plate:
			c.draw_texture_rect(s3_plate, full, false, Color(1, 1, 1, smoothstep(0.0, 1.0, tilt_k)))
		else:
			_draw_tipped_panes(c, tilt, base_id)
	# The window darkens with the story, not with a clock. Painted water must still read.
	var painted := base_id == "office_s2"
	var dusk: float = ([0.18, 0.42, 0.45, 0.34] if painted else [0.18, 0.42, 0.62, 0.72])[s]
	c.draw_rect(GLASS, Color(0.04, 0.06, 0.12, dusk))
	if s >= 2:
		# The sea outside keeps moving, silently: a slow bruise-violet sheen on the water.
		var sheen := 0.10 + (0.05 * sin(time * 0.8) if sim.state.motion else 0.0)
		_draw_sea_sheen(c, tilt, Color(BRUISE, sheen))
		# Everything out on the water tips with the sea; the frame stays square.
		c.draw_set_transform_matrix(_tilt_xform(tilt))
		_draw_ninth_piling(c, s)
		if s == 3:
			_draw_eye(c, tilt)   # above the dusk wash: Ada says she can see it, so the player must too
			if s3_plate == null:
				# The plate paints its own tipped horizon; the drawn one is only a hint of it.
				var lo: Rect2 = PANES[6]
				c.draw_line(Vector2(lo.position.x + 2, HORIZON_PIVOT.y), Vector2(lo.end.x - 2, HORIZON_PIVOT.y),
					Color(0.80, 0.84, 0.90, 0.15), 1.5, true)
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
	if s == 3:
		_draw_palms(c)
	if s >= 1:
		_draw_wrong_shadow(c, s)   # on the wall, so the lamp stands in front of it
	_draw_away(c, false)
	c.draw_texture_rect(textures["lamp_off"], Rect2(242, 469, 192, 288), false)
	if sim.state.p01_complete:
		c.draw_texture_rect(textures["lamp_light"], Rect2(242, 469, 192, 288), false)
	_draw_away(c, true)   # the brimming mug stands in front of the lamp's foot
	c.draw_texture_rect(textures["spares_tray"], Rect2(341, 666, 128, 64), false)
	if s >= 2:
		_draw_map_pencil(c, s)
	if s >= 3:
		_draw_hook_tag(c)
	_draw_coat_weight(c, s)
	_draw_prints(c, s)
	if _at_threshold():
		pass   # the doorway draws on its own layer
	elif sim.state.report_filed:
		c.draw_rect(Rect2(1228, 168, 6, 736), Color(0.01, 0.01, 0.02, 0.85))   # unlatched, ajar
	var vig: float = [0.0, 0.0, 0.35, 0.5][s]
	if s == 3:
		vig += 0.06 * _env_drawn()
	_draw_vignette(c, vig)

## What changed while she looked away (sim.look_away), as painted overlays. The mug is
## drawn after the lamp; the others before it. A missing PNG is skipped: the line and the
## notebook still carry the change.
func _draw_away(c: Node2D, mug: bool) -> void:
	if sim.stage() != 3:
		return
	for i in OfficeSim.LOOK_AWAY.size():
		var id: String = OfficeSim.LOOK_AWAY[i]
		if (id == "mug") != mug or not sim.look_away(id):
			continue
		var tex := _tex("away_" + id)
		if tex == null:
			continue
		var a := away_k if i + 1 > away_from else 1.0
		c.draw_texture_rect(tex, Rect2(Vector2.ZERO, SIZE), false, Color(1, 1, 1, a))

## Rotation about the painted horizon.
func _tilt_xform(tilt: float) -> Transform2D:
	return Transform2D(tilt, HORIZON_PIVOT - HORIZON_PIVOT.rotated(tilt))

## The seascape, really turned: each pane samples the plate as if the world outside had
## rotated about the horizon. Every pane is padded with its own edge pixels, so a turned
## pane never shows a ghost of the glazing bars; the bars are the plate's, untouched.
func _draw_tipped_panes(c: CanvasItem, tilt: float, src_id: String) -> void:
	if pane_tex.is_empty() or pane_src != src_id:
		_build_pane_textures(src_id)
	if pane_tex.size() != PANES.size():
		return
	var inv := _tilt_xform(tilt).affine_inverse()
	for i in PANES.size():
		var r: Rect2 = PANES[i]
		var tex: Texture2D = pane_tex[i]
		var origin := r.position - Vector2(PANE_PAD, PANE_PAD)
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)])
		var uvs := PackedVector2Array()
		for p in pts:
			uvs.append((inv * p - origin) / tex.get_size())
		c.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)

func _build_pane_textures(src_id: String) -> void:
	pane_tex = []
	pane_src = src_id
	var tex: Texture2D = textures.get(src_id)
	var img: Image = tex.get_image() if tex else null
	if img == null or img.is_empty():
		return
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var m := PANE_PAD
	for r in PANES:
		var ri := Rect2i(r)
		var w := ri.size.x
		var h := ri.size.y
		var out := Image.create(w + 2 * m, h + 2 * m, false, Image.FORMAT_RGBA8)
		out.blit_rect(img, ri, Vector2i(m, m))
		for edge in [[ri.position.y, 0], [ri.end.y - 1, m + h]]:
			var row := img.get_region(Rect2i(ri.position.x, edge[0], w, 1))
			row.resize(w, m, Image.INTERPOLATE_NEAREST)
			out.blit_rect(row, Rect2i(0, 0, w, m), Vector2i(m, edge[1]))
		for edge in [[m, 0], [m + w - 1, m + w]]:
			var col := out.get_region(Rect2i(edge[0], 0, 1, h + 2 * m))
			col.resize(m, h + 2 * m, Image.INTERPOLATE_NEAREST)
			out.blit_rect(col, Rect2i(0, 0, m, h + 2 * m), Vector2i(edge[1], 0))
		pane_tex.append(ImageTexture.create_from_image(out))

func _draw_sea_sheen(c: CanvasItem, tilt: float, col: Color) -> void:
	var band := _tilt_xform(tilt) * PackedVector2Array([Vector2(470, 425), Vector2(812, 425),
		Vector2(812, 560), Vector2(470, 560)])
	var lo: Rect2 = PANES[6]
	var pane := PackedVector2Array([lo.position, Vector2(lo.end.x, lo.position.y), lo.end,
		Vector2(lo.position.x, lo.end.y)])
	for poly in Geometry2D.intersect_polygons(band, pane):
		c.draw_colored_polygon(poly, col)

## The eye on the water: three flat bands in the sea's own colour, wider than the glass, so
## they run off both sides of it, and a flat dark pupil. Drawn inside _tilt_xform, so the
## clip pane is taken into the tipped frame. With Motion on, it contracts with the breath.
func _draw_eye(c: Node2D, tilt: float) -> void:
	var env := _env_drawn()
	var band_k := 1.0 - 0.08 * env if sim.state.motion else 1.0
	var pupil_k := 1.0 - 0.3 * env if sim.state.motion else 1.0
	var lo: Rect2 = PANES[6]
	var pane := _tilt_xform(tilt).affine_inverse() * PackedVector2Array([lo.position,
		Vector2(lo.end.x, lo.position.y), lo.end, Vector2(lo.position.x, lo.end.y)])
	var centre := Vector2(eye_x, 502)
	for band in [[260.0, 19.0, 0.08], [190.0, 14.0, 0.13], [120.0, 9.0, 0.20]]:
		var ell := _ellipse(centre, band[0] * band_k, band[1], 48)
		for poly in Geometry2D.intersect_polygons(ell, pane):
			c.draw_colored_polygon(poly, Color(0.62, 0.74, 0.74, band[2]))
	c.draw_colored_polygon(_ellipse(centre, 23.0 * pupil_k, 3.0, 24), Color(0.02, 0.03, 0.05, 0.6))

func _draw_ninth_piling(c: Node2D, s: int) -> void:
	if s == 3:
		# The pupil the contours point at: larger, nearer, unmistakable.
		c.draw_rect(Rect2(586, 428, 18, 110), PILING_COL)
		c.draw_circle(Vector2(595, 428), 9, PILING_COL)
	elif sim.state.drawer_open:
		c.draw_rect(Rect2(590, 436, 14, 92), PILING_COL)
		c.draw_circle(Vector2(597, 436), 7, PILING_COL)
	else:
		c.draw_rect(Rect2(612, 452, 9, 64), PILING_COL)

## Three hands pressed to the outside of the glass, low down, below the horizon.
## They are on the glass, not on the sea, so they do not tip.
func _draw_palms(c: Node2D) -> void:
	if palms_k <= 0.0:
		return
	var painted := _tex("palms_glass")
	if painted:
		c.draw_texture_rect(painted, Rect2(Vector2.ZERO, SIZE), false, Color(1, 1, 1, palms_k))
		return
	var col := Color(PALM_COL, 0.16 * palms_k)
	var drip := Color(PALM_COL, 0.10 * palms_k)
	# [heel centre, lean, drip length, mirrored]
	for palm in [[Vector2(560, 526), -0.18, 14.0, false], [Vector2(632, 530), 0.04, 12.0, true],
			[Vector2(712, 522), 0.22, 18.0, false]]:
		var p: Vector2 = palm[0]
		var rot: float = palm[1]
		var m := -1.0 if palm[3] else 1.0
		c.draw_colored_polygon(_xform_pts(_ellipse(Vector2.ZERO, 8.5, 9.5, 18), p, rot), col)
		# Four fingers, slightly apart, the middle two longest; a thumb low on one side.
		for f in 4:
			var fx := (-5.4 + f * 3.6) * m
			var length: float = [6.5, 8.0, 7.6, 5.6][f] if m > 0.0 else [5.6, 7.6, 8.0, 6.5][f]
			var centre := Vector2(fx * 1.08, -9.0 - length)
			var finger := _ellipse(Vector2.ZERO, 1.55, length, 10)
			c.draw_colored_polygon(_xform_pts(_xform_pts(finger, centre, fx * 0.035), p, rot), col)
		var thumb := _ellipse(Vector2.ZERO, 1.8, 5.2, 10)
		c.draw_colored_polygon(_xform_pts(_xform_pts(thumb, Vector2(9.5 * m, -3.0), 0.75 * m), p, rot), col)
		# The heel slid a little as it came away: a thin run of water below it.
		var start := p + Vector2(-2.5 * m, 9.0).rotated(rot)
		c.draw_line(start, start + Vector2(0.4, palm[2]), drip, 1.0, true)
		c.draw_circle(start + Vector2(0.4, palm[2]), 1.1, drip)

func _xform_pts(pts: PackedVector2Array, at: Vector2, rot: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(at + p.rotated(rot))
	return out

func _draw_map_pencil(c: Node2D, s: int) -> void:
	if sim.state.contours_seen:
		_draw_contours(c)
	var pencil := Color(0.25, 0.25, 0.28, 0.8)
	c.draw_line(Vector2(352, 298), Vector2(352, 342), pencil, 2.5)
	c.draw_string(hand, Vector2(346, 364), "9", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, pencil)
	if s == 3:
		c.draw_line(Vector2(372, 318), Vector2(372, 354), Color(0.09, 0.10, 0.12, 0.85), 3.0)
	if sim.state.soundings_heard:
		# His re-soundings over the open water: deeper everywhere. Seaward, past the jetty's
		# end, no figure at all, only a scrawl and one word.
		var fig := Color(0.25, 0.25, 0.28, 0.75)
		for d in [[Vector2(292, 250), "41"], [Vector2(306, 268), "47"], [Vector2(284, 284), "52"]]:
			c.draw_string(hand, d[0], d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, fig)
		var g := RandomNumberGenerator.new()
		g.seed = 400
		var scrawl := PackedVector2Array()
		for i in 11:
			scrawl.append(Vector2(314.0 + i * 4.4, 214.0 - i * 0.6 + g.randf_range(-2.5, 2.5)))
		c.draw_polyline(scrawl, fig, 1.2, true)
		c.draw_string(hand, Vector2(318, 230), "warm", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, fig)

## Venn's ring contours: the Sound closes on the ninth piling. Painted if present, else
## seven graphite rings clipped to the chart sheet. Fades in from the 'contours' beat.
func _draw_contours(c: Node2D) -> void:
	var painted := _tex("chart_contours")
	if painted:
		c.draw_texture_rect(painted, Rect2(Vector2.ZERO, SIZE), false, Color(1, 1, 1, contours_k))
		return
	var r := CONTOUR_CLIP
	var clip := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var col := Color(0.25, 0.25, 0.28, 0.5 * contours_k)
	for i in 7:
		var rx := 8.0 + 16.0 * i
		var ring := _ellipse(CONTOUR_C, rx, 0.8 * rx, 48)
		ring.append(ring[0])
		for part in Geometry2D.clip_polyline_with_polygon(ring, clip):
			if part.size() >= 2:
				c.draw_polyline(part, col, 1.5, true)

## The brass tag on the ninth hook, stamped with her initials, at the height of her collar.
func _draw_hook_tag(c: Node2D) -> void:
	var r := Rect2(1135, 300, 34, 44)
	c.draw_rect(r, BRASS)
	c.draw_rect(r, BRASS.darkened(0.45), false, 1.0)
	c.draw_circle(Vector2(r.get_center().x, r.position.y + 6), 3, Color(0.06, 0.05, 0.04))
	c.draw_string(hand, Vector2(1139, 334), "A.M.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, BLUE_INK)

## The oilskin fills out at the shoulders, as if someone were standing inside it.
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
	var col := Color(0.04, 0.06, 0.09, a)
	# A rounded torso under two shoulders, inside the coat's own outline: no corners anywhere.
	var torso := PackedVector2Array()
	for k in 13:
		var t := float(k) / 12.0
		torso.append(Vector2(lerpf(1046.0, 1118.0, t), 404.0 + 6.0 * sin(PI * t)))
	torso.append(Vector2(1114, 372))
	torso.append(Vector2(1082, 350))
	torso.append(Vector2(1050, 372))
	c.draw_colored_polygon(torso, col)
	c.draw_colored_polygon(_ellipse(Vector2(1064, 364), 21, 15, 20), Color(col, a * 0.7))
	c.draw_colored_polygon(_ellipse(Vector2(1100, 364), 21, 15, 20), Color(col, a * 0.7))
	if s >= 3:
		c.draw_colored_polygon(_ellipse(Vector2(1082, 324), 19, 14, 18), Color(0.04, 0.06, 0.09, 0.5))

## The chair's shadow falls toward the lamp, built from the chair's own back, and leans
## further each time she looks back. At stage 3 someone sits in it, sheared with it.
## The chair itself stays empty.
func _draw_wrong_shadow(c: Node2D, s: int) -> void:
	var ox := -150.0 - 10.0 * shadow_creep
	var sh := func(p: Vector2) -> Vector2: return Vector2(p.x + ox + (p.y - 684.0) * 0.35, p.y)
	if s >= 3:
		# The sitter, in the chair's own coordinates: shoulders above the top rail, a neck,
		# a head. Stretched 1.35x upward about the seat, so it sits taller than anyone should,
		# and its head rises a little more each time she looks back. Drawn first so the
		# chair back crosses it.
		var lift := 3.0 * shadow_creep
		var sit := func(p: Vector2, up: float) -> Vector2:
			return sh.call(Vector2(p.x, 640.0 + (p.y - 640.0) * 1.35 - up))
		var body := Color(SHADOW_COL, 0.62)
		var turn := 0.0
		if sim.state.motion:
			turn = 6.0 * smoothstep(0.0, 4.0, creep_t)   # its head turns, slowly, after she looks away
		var torso := PackedVector2Array()
		for p in [Vector2(598, 640), Vector2(598, 616), Vector2(603, 603), Vector2(614, 595),
				Vector2(630, 590), Vector2(638, 586), Vector2(651, 586), Vector2(659, 590),
				Vector2(675, 595), Vector2(686, 603), Vector2(691, 616), Vector2(691, 640)]:
			torso.append(sit.call(p, 0.0))
		c.draw_colored_polygon(torso, body)
		var head_c := Vector2(645 + turn, 560)
		var head := PackedVector2Array()
		for p in _ellipse(head_c, 18, 24, 22):
			head.append(sit.call(p, lift))
		c.draw_colored_polygon(head, body)
		var neck := PackedVector2Array([sit.call(Vector2(638, 590), 0.0), sit.call(Vector2(651, 590), 0.0),
			sit.call(Vector2(650 + turn * 0.5, 576), lift), sit.call(Vector2(639 + turn * 0.5, 576), lift)])
		c.draw_colored_polygon(neck, body)
		# A thin rim where the lamp catches it, on the lamp side only.
		var rim := Color(AMBER, 0.25)
		var head_rim := PackedVector2Array()
		for p in _arc_pts(head_c, 18, 24, PI * 0.6, PI * 1.35):
			head_rim.append(sit.call(p, lift))
		c.draw_polyline(head_rim, rim, 1.5, true)
		c.draw_polyline(PackedVector2Array([sit.call(Vector2(598, 618), 0.0), sit.call(Vector2(603, 603), 0.0),
			sit.call(Vector2(614, 595), 0.0), sit.call(Vector2(630, 590), 0.0)]), rim, 1.5, true)
	# The chair back: one solid shape, so it reads as a chair and not a comb.
	c.draw_colored_polygon(PackedVector2Array([sh.call(Vector2(561, 622)), sh.call(Vector2(728, 622)),
		sh.call(Vector2(728, 684)), sh.call(Vector2(561, 684))]), Color(SHADOW_COL, 0.42))

func _arc_pts(center: Vector2, rx: float, ry: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 13:
		var ang := lerpf(a0, a1, k / 12.0)
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts

func _draw_prints(c: Node2D, s: int) -> void:
	if s >= 2 and (sim.state.prints_seen or s >= 3):
		# From the puddle to the drawer, shrinking toward the desk.
		var k := smoothstep(0.0, 1.0, prints_fade)
		var painted := _tex("prints_drawer")
		if painted:
			c.draw_texture_rect(painted, Rect2(Vector2.ZERO, SIZE), false, Color(1, 1, 1, 0.9 * k))
		else:
			_trail(c, Vector2(1110, 940), Vector2(990, 905), 6, Color(PRINT_COL, 0.55 * k), false)
	if s >= 3:
		# A second trail, from the drawer to the door, thinning to nothing.
		var painted_door := _tex("prints_door")
		if painted_door:
			c.draw_texture_rect(painted_door, Rect2(Vector2.ZERO, SIZE), false, Color(1, 1, 1, 0.9))
		else:
			_trail(c, Vector2(1000, 915), Vector2(1228, 900), 8, Color(PRINT_COL, 0.55 * prints_fade), true)

## A walked line of prints: alternating feet either side of the line of travel.
func _trail(c: Node2D, from: Vector2, to: Vector2, n: int, col: Color, fade: bool) -> void:
	var dir := (to - from).normalized()
	var side := dir.orthogonal()
	for i in n:
		var t := float(i) / float(n - 1)
		var p := from.lerp(to, t) + side * (9.0 if i % 2 == 0 else -9.0)
		var size_k := lerpf(1.0, 0.8, t) if not fade else 0.92
		var a := col.a * (pow(0.88, i) if fade else 1.0)
		_foot(c, p, dir, size_k, Color(col, a), i % 2 == 0)

## A bare, narrow sole: heel, pinched waist, ball of the foot, and four toes in an arc.
func _foot(c: Node2D, p: Vector2, dir: Vector2, size_k: float, col: Color, left: bool) -> void:
	var ang := dir.angle()
	var flip := 1.0 if left else -1.0
	var pts := PackedVector2Array()
	for k in 24:
		var th := TAU * k / 24.0
		var u := cos(th)                       # -1 heel .. +1 ball
		var width := 4.2 if u < -0.55 else (2.6 if u < 0.15 else 5.0)
		width = lerpf(width, 4.0, 0.25)
		var local := Vector2(u * 13.0, sin(th) * width + flip * 1.2 * maxf(u, 0.0))
		pts.append(p + (local * size_k).rotated(ang))
	c.draw_colored_polygon(pts, col)
	for t in 4:
		var a := lerpf(-0.75, 0.75, t / 3.0)
		var toe := Vector2(15.5, 0).rotated(a) + Vector2(1.5, flip * 1.0)
		c.draw_circle(p + (toe * size_k).rotated(ang), (1.9 - 0.25 * t if left else 1.15 + 0.25 * t) * size_k, col)

func _draw_deep() -> void:
	deep_drawn = _at_threshold()
	if deep_drawn:
		_draw_door_opening(deep)

## The open door, and the corridor behind it: deeper than the building, breathing.
## Deep layer, unlit: what is down there makes its own light.
func _draw_door_opening(c: Node2D) -> void:
	var k := 1.0
	if sim.state.motion:
		k = smoothstep(0.0, 1.0, clampf(threshold_t / 2.2, 0.0, 1.0))
	var slab := DOOR_SLAB
	var open := Rect2(slab.position, Vector2(slab.size.x * k, slab.size.y))
	c.draw_rect(open, Color(0.01, 0.012, 0.02))
	if k <= 0.0:
		return
	var held := _breath_held()
	var env := door_env if held else _env_drawn()
	var corridor := _tex("threshold_corridor")
	if corridor:
		# The corridor swells on the exhale: the source is the slab shrunk toward the
		# vanishing point, so the image grows about it and never spills past the doorway.
		var f := 1.0
		if sim.state.motion:
			f = 1.0 / (1.0 + 0.025 * env)
		var src := Rect2(VP + (slab.position - VP) * f, slab.size * f)
		src.size.x *= k
		c.draw_texture_rect_region(corridor, open, _canvas_to_tex(corridor, src))
	else:
		_draw_casings(c, open)
	# The water comes up the corridor while she stands there. Its height runs on threshold
	# time, so it always reaches the same end.
	var water := 860.0
	if sim.state.motion:
		water = lerpf(904.0, 860.0, clampf(threshold_t / 11.0, 0.0, 1.0))
	if water < slab.end.y - 0.5:
		c.draw_colored_polygon(PackedVector2Array([Vector2(open.position.x, water), Vector2(open.end.x, water),
			Vector2(open.end.x, slab.end.y), Vector2(open.position.x, slab.end.y)]), Color(0.05, 0.08, 0.11, 0.8))
		c.draw_line(Vector2(open.position.x, water), Vector2(open.end.x, water), Color(0.55, 0.62, 0.70, 0.3), 1.0)
	# At the end of it, something opens an eye as it breathes. It freezes when she holds hers.
	if open.end.x > VP.x + 12.0:
		var hh := lerpf(1.0, 3.5, env)
		var almond := PackedVector2Array()
		for j in 13:
			var u := j / 12.0
			almond.append(VP + Vector2(lerpf(-11.0, 11.0, u), -hh * sin(PI * u)))
		for j in range(11, 0, -1):
			var u := j / 12.0
			almond.append(VP + Vector2(lerpf(-11.0, 11.0, u), hh * sin(PI * u)))
		c.draw_colored_polygon(almond, Color(0.85, 0.88, 0.92, 0.5 * env))
		c.draw_rect(Rect2(VP - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.02, 0.02, 0.03, 0.9))
	# Only at the top of a breath, only while she isn't holding hers: someone standing there.
	var figure := _tex("threshold_figure")
	if figure and k >= 1.0 and sim.state.motion and not held and not still_spoken:
		var fa := 0.42 * smoothstep(0.85, 1.0, env)
		if fa > 0.0:
			c.draw_texture_rect(figure, Rect2(Vector2.ZERO, SIZE), false, Color(1, 1, 1, fa))
	if k < 1.0:
		return
	# On the inhale, a wet gleam reaches out of the doorway across the floor toward the desk.
	var reach := 260.0 * env
	c.draw_colored_polygon(PackedVector2Array([Vector2(1228, 900), Vector2(1228, 920),
		Vector2(1228 - reach, 916), Vector2(1228 - reach, 906)]), Color(0.70, 0.76, 0.84, 0.08 * env))

## Fallback corridor: nine teal casings, each 0.86 of the last toward the vanishing point,
## black inside, darker with distance. Clipped to the opened part of the doorway.
func _draw_casings(c: Node2D, open: Rect2) -> void:
	var frame := DOOR_SLAB.grow(-6)
	for i in 9:
		var f := pow(0.78, i)
		var casing := frame.intersection(open)
		if casing.has_area():
			c.draw_rect(casing, Color(0.11 * f, 0.18 * f, 0.22 * f))
		var inner := frame.grow(-10.0 * pow(0.86, i)).intersection(open)
		if inner.has_area():
			c.draw_rect(inner, Color(0, 0, 0))
		frame = Rect2(VP + (frame.position - VP) * 0.86, frame.size * 0.86)

## Maps a canvas-space rect onto a texture: full-canvas plates are 1:1; a texture cut to
## the door slab is scaled from it.
func _canvas_to_tex(tex: Texture2D, r: Rect2) -> Rect2:
	var ts := tex.get_size()
	if ts.is_equal_approx(SIZE):
		return r
	var sc := ts / DOOR_SLAB.size
	return Rect2((r.position - DOOR_SLAB.position) * sc, r.size * sc)

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
		"report":
			_draw_report(c)
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

## The end card: the photograph from after she left, the log's last row writing itself,
## then the lines. With Motion off it is all there at once.
func _draw_end(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color("070b0f"))
	var t := end_t if sim.state.motion else 1.0e6
	var sch := _end_schedule()
	var photo_a := clampf(t / 4.0, 0.0, 1.0)
	if photo_a > 0.0:
		_draw_photo(c, Rect2(574, 110, 300, 380), "turned" if sim.state.turned else "after", photo_a)
	# The log's next two rows write themselves. Hers in her ink; his, if it is his, in a
	# plainer, upright, grey hand: someone else is keeping the log now.
	var rows := sim.end_rows()
	var starts := [sch.r1_start, sch.r2_start]
	for i in 2:
		if t < starts[i]:
			continue
		var text: String = rows[i][0]
		var n := mini(int((t - starts[i]) * REVEAL_CPS), text.length())
		var y := 600.0 + 50.0 * i
		if rows[i][1] == "venn":
			var w := serif.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			_draw_handwriting(c, text, n, Vector2((SIZE.x - w) / 2.0, y), 26, 78 + i, n < text.length(),
				Color(0.66, 0.68, 0.70), serif, 0.0)
		else:
			var w := hand.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			_draw_handwriting(c, text, n, Vector2((SIZE.x - w) / 2.0, y), 30, 77 + i, n < text.length(), NIGHT_INK)
	var lines_at: Array = sch.lines
	var end_text := sim.end_lines()
	for i in end_text.size():
		var a := clampf((t - float(lines_at[i])) / 1.0, 0.0, 1.0)
		if a <= 0.0:
			continue
		match end_text[i]:
			OfficeSim.END_ON_STATION:
				_text(c, end_text[i], Vector2(0, 730), 24, Color(NIGHT_INK, a), hand, SIZE.x)
			OfficeSim.END_ALL_SEEN:
				_text(c, end_text[i], Vector2(0, 770), 22, Color(PAPER, 0.6 * a), serif, SIZE.x)
			_:
				_text(c, end_text[i], Vector2(0, 830), 26, Color(PAPER, 0.75 * a), serif, SIZE.x)
	_text(c, "End of the Intake Office slice.", Vector2(0, 1040), 16, Color(PAPER, 0.3), serif, SIZE.x)
	if _end_button_ready():
		_button(c, END_BUTTON, "Play again")

## When each part of the end card appears, in seconds after the end card opens:
## the two rows (start, done), each closing line's fade-in, and when the last is in.
func _end_schedule() -> Dictionary:
	var rows := sim.end_rows()
	var r1_start := 3.0
	var r1_done: float = r1_start + rows[0][0].length() / REVEAL_CPS
	var r2_start := r1_done + 2.0
	var r2_done: float = r2_start + rows[1][0].length() / REVEAL_CPS
	var at := []
	for i in sim.end_lines().size():
		at.append(r2_done + 1.5 + 1.6 * i)
	return {"r1_start": r1_start, "r1_done": r1_done, "r2_start": r2_start, "r2_done": r2_done,
		"lines": at, "cont": at.back(), "done": float(at.back()) + 1.0}

func _end_row_writing() -> bool:
	if sim.view != "end" or not sim.state.motion:
		return false
	var sch := _end_schedule()
	return end_t >= sch.r1_start and end_t < sch.r1_done or end_t >= sch.r2_start and end_t < sch.r2_done

## "Play again" exists only once the last line is in (or after the grace, Motion off).
func _end_button_ready() -> bool:
	if not sim.state.motion:
		return end_t > END_GRACE
	return end_t >= _end_schedule().done

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
	if lit:
		# Venn's rule, in pencil in the margin: the key to the stained hour.
		var mw := hand.get_string_size(OfficeSim.LOG_MARGIN, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var mx := minf(640.0, page.size.x - 40.0 - mw)
		c.draw_set_transform(page.position + Vector2(mx, 104), -0.03)
		c.draw_string(hand, Vector2.ZERO, OfficeSim.LOG_MARGIN, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
			Color(0.25, 0.25, 0.28, 0.85))
		c.draw_set_transform(Vector2.ZERO)
	var rows := sim.log_rows()
	var step := 70.0
	var ink_size := 23
	var hand_size := 25
	if rows.size() > 12:
		ink_size = 19
		hand_size = 21
		step = minf(44.0, (page.end.y - 36.0 - (page.position.y + 170.0)) / float(rows.size() - 1))
	elif rows.size() > 9:
		step = 52.0
		ink_size = 21
		hand_size = 23
	var y := page.position.y + 170
	for x in [page.position.x + 40, page.position.x + 210, page.position.x + 340, page.position.x + 500]:
		c.draw_line(Vector2(x, y - 40), Vector2(x, page.end.y - 24), Color(INK, 0.15), 1.0)
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
		if r == OfficeSim.BLOTTED_ROW and e[1] == "":
			_draw_blot(c, Vector2(page.position.x + 262, y - 7))
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

## A dried seawater stain over one cell: soft overlapping pools and a ragged tide-mark rim.
func _draw_blot(c: Node2D, at: Vector2) -> void:
	c.draw_colored_polygon(_ellipse(at + Vector2(-6, 2), 48, 22, 28), Color("b8a47c", 0.5))
	c.draw_colored_polygon(_ellipse(at + Vector2(14, -4), 34, 18, 24), Color("8f7a55", 0.35))
	c.draw_colored_polygon(_ellipse(at + Vector2(-22, 6), 26, 14, 20), Color("8f7a55", 0.35))
	var g := RandomNumberGenerator.new()
	g.seed = 1852
	var rim := PackedVector2Array()
	for k in 41:
		var ang := TAU * k / 40.0
		var wob := 1.0 + g.randf_range(-0.09, 0.09) + 0.06 * sin(ang * 3.0)
		rim.append(at + Vector2(cos(ang) * 52.0 * wob, sin(ang) * 25.0 * wob))
	rim[40] = rim[0]
	c.draw_polyline(rim, Color("8f7a55", 0.55), 1.4, true)

## Her hand, glyph by glyph: seeded jitter, a forward slant, and wet ink at the nib.
func _draw_handwriting(c: Node2D, text: String, count: int, pos: Vector2, size: int, row: int,
		wet: bool, ink := BLUE_INK, font: Font = null, skew := HAND_SKEW) -> void:
	if font == null:
		font = hand
	var g := RandomNumberGenerator.new()
	var x := pos.x
	for i in count:
		g.seed = 18 + row * 97 + i
		var dy := g.randf_range(-2.0, 2.0)
		var rot := g.randf_range(-0.06, 0.06)
		var ch := text.unicode_at(i)
		var a := 0.6 if wet and i >= count - 6 else 1.0
		c.draw_set_transform_matrix(Transform2D(rot, Vector2.ONE, skew, Vector2(x, pos.y + dy)))
		c.draw_char(font, Vector2.ZERO, text[i], size, Color(ink, a))
		x += font.get_char_size(ch, size).x
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
	var front := Rect2(DRAWER_FRONT.position + off, DRAWER_FRONT.size)
	c.draw_rect(front, Color("5a3d26"))
	# Wood grain: thin wavy lines from a fixed seed, so the drawer is the same every time.
	var g := RandomNumberGenerator.new()
	g.seed = 1889
	var grain := Color("3a2716", 0.25)
	for i in 16:
		var y0 := front.position.y + 16.0 + i * (front.size.y - 32.0) / 15.0 + g.randf_range(-6.0, 6.0)
		var amp := g.randf_range(1.0, 3.5)
		var freq := g.randf_range(0.006, 0.014)
		var ph := g.randf_range(0.0, TAU)
		var pts := PackedVector2Array()
		for k in 21:
			var x := front.position.x + 8.0 + k * (front.size.x - 16.0) / 20.0
			pts.append(Vector2(x, y0 + amp * sin(x * freq + ph)))
		c.draw_polyline(pts, grain, g.randf_range(1.0, 2.0), true)
	c.draw_rect(front, Color("3a2716"), false, 2)
	# The escutcheon: a brass backing plate with four screws, the dials set into it.
	var esc := Rect2(Vector2(386, 428) + off, Vector2(676, 214))
	c.draw_rect(esc, BRASS.darkened(0.28))
	c.draw_rect(esc, BRASS.darkened(0.55), false, 2)
	for corner in [Vector2(14, 14), Vector2(662, 14), Vector2(14, 200), Vector2(662, 200)]:
		c.draw_circle(esc.position + corner, 5, BRASS.darkened(0.1))
		c.draw_line(esc.position + corner - Vector2(3, 3), esc.position + corner + Vector2(3, 3), BRASS.darkened(0.6), 1.5)
	c.draw_rect(Rect2(DRAWER_PLATE.position + off, DRAWER_PLATE.size), BRASS)
	c.draw_rect(Rect2(DRAWER_PLATE.position + off, DRAWER_PLATE.size), BRASS.darkened(0.45), false, 2)
	_text(c, "E.V. — Open at the hour she mended it.", DRAWER_PLATE.position + off + Vector2(0, 46), 24,
		INK, hand, DRAWER_PLATE.size.x)
	var code: Array = sim.state.drawer_dial
	for i in 4:
		var r := _dial_rect(i)
		r.position += off
		var v: int = int(code[i])
		# A recessed drum: dark well, brass cylinder lit from above, shaded toward the bottom.
		c.draw_rect(r.grow(6), Color(0.07, 0.05, 0.03))
		c.draw_rect(r, BRASS)
		c.draw_rect(Rect2(r.position, Vector2(r.size.x, 26)), BRASS.darkened(0.25))
		c.draw_rect(Rect2(r.position + Vector2(0, 26), Vector2(r.size.x, 12)), Color(BRASS.lightened(0.45), 0.7))
		c.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 34), Vector2(r.size.x, 34)), BRASS.darkened(0.35))
		var digits := dial_digits(v)   # each half shows where a click on it goes
		_text(c, "▲", r.position + Vector2(0, 20), 16, Color(INK, 0.6), serif, r.size.x)
		_text(c, str(digits[0]), r.position + Vector2(0, 58), 40, Color(INK, 0.25), serif, r.size.x)
		_text(c, str(digits[1]), r.position + Vector2(0, 116), 64, INK, serif, r.size.x)
		_text(c, str(digits[2]), r.position + Vector2(0, 152), 40, Color(INK, 0.25), serif, r.size.x)
		_text(c, "▼", r.position + Vector2(0, 167), 16, Color(INK, 0.6), serif, r.size.x)
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
	_draw_photo(c, PHOTO_RECT, "drawer")

## The painted print for a photo variant, or null for the drawn fallback.
func _photo_tex(variant: String) -> Texture2D:
	match variant:
		"drawer":
			if int(sim.state.photo_looks) >= 3 and _tex("photo_drawer_hand"):
				return _tex("photo_drawer_hand")
			return _tex("photo_drawer")
		"after":
			return _tex("photo_after")
		"turned":
			return _tex("photo_turned")
	return null

## The photograph of this window from the sea side, at night. Six-over-one like the plate:
## top row dark, middle row half lit, the lower pane lamplit.
##   "drawer": her at the desk, and something pale and too tall standing behind her.
##   "after":  the desk lit, the chair empty, and in the lower pane a tiny lit window:
##             the photograph contains the photograph.
##   "turned": her, turned round in the chair to face the camera, with no face.
## A painted print replaces the drawn image; the border, wash and caption are always drawn.
## `alpha` fades the whole print in over the end card's black.
func _draw_photo(c: Node2D, rect: Rect2, variant: String, alpha := 1.0) -> void:
	var ctr := rect.get_center()
	c.draw_set_transform(ctr, 0.04)
	var half := rect.size / 2.0
	c.draw_rect(Rect2(-half, rect.size), Color("d8d0bc"))
	var img := Rect2(-half.x + 18, -half.y + 18, rect.size.x - 36, rect.size.y - 70)
	var painted := _photo_tex(variant)
	if painted:
		c.draw_texture_rect(painted, img, false)
	else:
		_draw_photo_drawn(c, img, variant)
	c.draw_rect(img, Color(0.45, 0.35, 0.2, 0.18))
	_text(c, "Greywake. 18 Oct.", Vector2(-half.x, half.y - 18), 20, INK, hand, rect.size.x)
	if alpha < 1.0:
		c.draw_rect(Rect2(-half, rect.size).grow(3), Color("070b0f", 1.0 - alpha))
	c.draw_set_transform(Vector2.ZERO)

func _draw_photo_drawn(c: Node2D, img: Rect2, variant: String) -> void:
	c.draw_rect(img, Color("1a1f24"))
	var win := Rect2(-100, img.position.y + 24, 200, 196)
	var pw := win.size.x / 3.0
	var row_h := 42.0
	var lower := Rect2(win.position + Vector2(0, row_h * 2 + 6), Vector2(win.size.x, win.size.y - row_h * 2 - 6))
	for i in 3:
		var x := win.position.x + pw * i
		c.draw_rect(Rect2(x, win.position.y, pw, row_h), Color(AMBER, 0.05))
		c.draw_rect(Rect2(x, win.position.y + row_h, pw, row_h * 0.5), Color(AMBER, 0.14))
		c.draw_rect(Rect2(x, win.position.y + row_h * 1.5, pw, row_h * 0.5), Color(AMBER, 0.42))
	c.draw_rect(lower, Color(AMBER, 0.75))
	for k in 3:   # the lamp, as a soft glow rather than a disc
		c.draw_circle(lower.position + Vector2(34, 50), 30 - k * 9, Color("f0d9a0", 0.6 / 3.0))
	var dark := Color(0.03, 0.03, 0.04)
	var base := Vector2(lower.get_center().x + 6, lower.end.y - 10)
	if variant == "after":
		# The chair, empty: posts, a curved rail, spindles.
		c.draw_rect(Rect2(base + Vector2(-20, -44), Vector2(40, 6)), dark)
		c.draw_rect(Rect2(base + Vector2(-20, -44), Vector2(5, 44)), dark)
		c.draw_rect(Rect2(base + Vector2(15, -44), Vector2(5, 44)), dark)
		for x in [-9, -1, 7]:
			c.draw_rect(Rect2(base + Vector2(x, -38), Vector2(3, 38)), dark)
		# ...and, in the lower pane, a window within the window, lit.
		var tiny := Rect2(lower.end.x - 46, lower.position.y + 18, 28, 34)
		c.draw_rect(tiny, Color("f0d9a0", 0.85))
		c.draw_rect(tiny, Color("c9c0a8", 0.8), false, 1.5)
		c.draw_line(Vector2(tiny.get_center().x, tiny.position.y), Vector2(tiny.get_center().x, tiny.position.y + 14), Color("c9c0a8", 0.8), 1.0)
		c.draw_line(Vector2(tiny.position.x, tiny.position.y + 14), Vector2(tiny.end.x, tiny.position.y + 14), Color("c9c0a8", 0.8), 1.0)
		c.draw_circle(tiny.get_center() + Vector2(0, 9), 3.0, dark)
	else:
		if variant == "drawer":
			# Behind the chair: pale, narrow, too tall. Its head is above the lit pane.
			# Cool grey against the warm lamplight, and its head is up in the dark sash.
			var pale := Color(0.80, 0.83, 0.86, 0.34)
			var cx := base.x + 24
			var top := win.position.y + row_h * 1.1
			c.draw_rect(Rect2(cx - 7, top + 14, 14, base.y - top - 14), pale)
			c.draw_colored_polygon(_ellipse(Vector2(cx, top + 16), 9, 5, 14), pale)
			c.draw_colored_polygon(_ellipse(Vector2(cx, top + 2), 6, 9, 16), pale)
		c.draw_colored_polygon(PackedVector2Array([base + Vector2(-26, 0), base + Vector2(26, 0),
			base + Vector2(16, -26), base + Vector2(-16, -26)]), dark)
		c.draw_colored_polygon(_ellipse(base + Vector2(0, -40), 14, 17, 16), dark)
		if variant == "turned":
			# She has turned round to face the camera. There is nothing on the front of her head.
			c.draw_colored_polygon(_ellipse(base + Vector2(0, -40), 9, 12, 16), Color(0.86, 0.85, 0.80, 0.85))
	# The desk's edge along the bottom of the pane.
	c.draw_rect(Rect2(lower.position.x, lower.end.y - 10, lower.size.x, 10), Color(0.05, 0.04, 0.03, 0.9))
	var muntin := Color("c9c0a8", 0.7)
	c.draw_rect(win, muntin, false, 4)
	for i in [1, 2]:
		c.draw_line(win.position + Vector2(pw * i, 0), win.position + Vector2(pw * i, row_h * 2), muntin, 4)
	c.draw_line(win.position + Vector2(0, row_h), win.position + Vector2(win.size.x, row_h), muntin, 4)
	c.draw_rect(Rect2(win.position + Vector2(0, row_h * 2), Vector2(win.size.x, 6)), muntin)
	var sea := Rect2(img.position.x, img.end.y - 46, img.size.x, 46)
	c.draw_rect(sea, Color("22303a"))
	for k in 3:
		var yy := sea.position.y + 10 + k * 12
		c.draw_line(Vector2(img.position.x + 14 + k * 30, yy), Vector2(img.end.x - 40 + k * 10, yy + 1),
			Color(0.75, 0.8, 0.82, 0.35), 1.0)

## Venn's closure report. Four lines, each with a witness in her notebook; the evening's
## high water is set on four dials, because it has to be worked out.
func _draw_report(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.94))
	var pg := REPORT_PAGE
	var filed: bool = sim.state.report_filed
	c.draw_rect(pg, Color("ded4ba"))
	c.draw_rect(pg, Color("8f7a55"), false, 2)
	_text(c, "GREYWAKE SURVEY STATION — CLOSURE REPORT", pg.position + Vector2(0, 74), 26, INK, serif, pg.size.x)
	_text(c, "To be completed by the observer before the station is left.", pg.position + Vector2(0, 112), 20,
		Color(INK, 0.6), hand, pg.size.x)
	for i in OfficeSim.REPORT_FIELDS.size():
		var r := _report_row(REPORT_FIELD_ROWS[i])
		var field: Array = OfficeSim.REPORT_FIELDS[i]
		var value: String = field[1][int(sim.state.report_fields[i])]
		_text(c, field[0], r.position + Vector2(20, 62), 24, INK, serif, 480, HORIZONTAL_ALIGNMENT_LEFT)
		c.draw_line(r.position + Vector2(500, 74), r.position + Vector2(r.size.x - 60, 74), Color(INK, 0.35), 1.5)
		_text(c, value, r.position + Vector2(520, 64), 32, BLUE_INK, hand, 220, HORIZONTAL_ALIGNMENT_LEFT)
		if not filed:
			_text(c, "▸", r.position + Vector2(r.size.x - 44, 62), 24, Color(INK, 0.4), serif, 30, HORIZONTAL_ALIGNMENT_LEFT)
	_draw_report_time(c, filed)
	if filed:
		c.draw_line(Vector2(600, 910), Vector2(860, 910), Color(INK, 0.35), 1.5)
		_draw_handwriting(c, "A. Mercer", 9, Vector2(620, 900), 36, 41, false)
		_text(c, "Filed 18 Oct", Vector2(880, 904), 20, Color(INK, 0.6), hand, 200, HORIZONTAL_ALIGNMENT_LEFT)
	else:
		_button(c, REPORT_SIGN, "Sign and file")

func _draw_report_time(c: Node2D, filed: bool) -> void:
	var r := _report_row(REPORT_TIME_ROW)
	_text(c, OfficeSim.REPORT_TIME_LABEL, r.position + Vector2(20, 62), 24, INK, serif, 480, HORIZONTAL_ALIGNMENT_LEFT)
	var t: Array = sim.state.report_time
	if filed:
		c.draw_line(r.position + Vector2(500, 74), r.position + Vector2(r.size.x - 60, 74), Color(INK, 0.35), 1.5)
		_text(c, "%d%d:%d%d" % [t[0], t[1], t[2], t[3]], r.position + Vector2(520, 64), 32, BLUE_INK, hand, 220,
			HORIZONTAL_ALIGNMENT_LEFT)
		return
	for i in 4:
		var d := _rtime_rect(i)
		var digits := dial_digits(int(t[i]))
		c.draw_rect(d, Color(INK, 0.06))
		c.draw_line(Vector2(d.position.x + 6, d.end.y - 18), Vector2(d.end.x - 6, d.end.y - 18), Color(INK, 0.35), 1.5)
		_text(c, str(digits[0]), d.position + Vector2(0, 24), 18, Color(INK, 0.28), hand, d.size.x)
		_text(c, str(digits[1]), d.position + Vector2(0, 66), 34, BLUE_INK, hand, d.size.x)
		_text(c, str(digits[2]), d.position + Vector2(0, 98), 18, Color(INK, 0.28), hand, d.size.x)
	var colon_x := (_rtime_rect(1).end.x + _rtime_rect(2).position.x) / 2.0
	_text(c, ":", Vector2(colon_x - 10, r.position.y + 62), 32, BLUE_INK, hand, 20)

func _draw_notebook(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.97))
	var page := Rect2(164, 90, 1120, 900)
	c.draw_rect(page, Color("e4dcc4"))
	_text(c, "NOTEBOOK — A. MERCER", page.position + Vector2(50, 64), 26, INK, serif, 900, HORIZONTAL_ALIGNMENT_LEFT)
	_text(c, "Noted %d of %d" % [sim.state.seen.size(), OfficeSim.OBSERVATIONS.size()],
		page.position + Vector2(0, 64), 20, Color(INK, 0.5), serif, page.size.x - 50, HORIZONTAL_ALIGNMENT_RIGHT)
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
	var intrusion := sim.notebook_intrusion()
	var room_for := 40.0 if intrusion != "" else 0.0
	# Late in the slice there is a lot to keep: shrink, then split into two columns,
	# so every entry stays on the page. Evidence is never dropped.
	var layout := [22, 960, 1]
	for opt in [[22, 960, 1], [20, 960, 1], [18, 960, 1], [18, 460, 2], [17, 460, 2], [17, 300, 3],
			[16, 300, 3], [15, 300, 3], [14, 300, 3]]:
		layout = opt
		if _notebook_flow(c, ids, opt, top, bottom - room_for, page.position.x, false).fits:
			break
	var flow := _notebook_flow(c, ids, layout, top, bottom - room_for, page.position.x, true)
	if intrusion == "":
		return
	# A line she did not write, in her hand, after her last entry.
	var n := intrusion.length()
	if _intrusion_writing():
		n = mini(n, int(intrusion_t * REVEAL_CPS * 0.45))
	var pos: Vector2 = flow.next + Vector2(20, 14)
	var w := hand.get_string_size(intrusion, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	if pos.y > bottom or pos.x + w > page.end.x - 30:
		pos = Vector2(page.end.x - w - 60, page.end.y - 28)
	_draw_handwriting(c, intrusion, n, pos, 22, 300, _intrusion_writing())

## The stranger line writes itself once, slowly, the first time the notebook opens after
## the log rewrote itself. Motion off: it is simply there.
func _intrusion_writing() -> bool:
	return sim.view == "notebook" and sim.state.motion and not intrusion_written \
		and sim.notebook_intrusion() != "" \
		and intrusion_t * REVEAL_CPS * 0.45 < sim.notebook_intrusion().length()

## Lays out notebook entries in 1 or 2 columns. Returns {fits, next}: whether they fit
## above `bottom`, and where the next entry would start.
func _notebook_flow(c: CanvasItem, ids: Array, layout: Array, top: float, bottom: float, left: float,
		draw: bool) -> Dictionary:
	var size: int = layout[0]
	var width: float = layout[1]
	var columns: int = layout[2]
	var col := 0
	var y := top
	var x := left + 60
	for id in ids:
		var h := _wrapped(c, OfficeSim.OBSERVATIONS[id], Vector2(0, 0), size, INK, width, false)
		if y + h - size > bottom and col + 1 < columns:
			col += 1
			y = top
		x = left + 60 + col * (width + 60)
		if draw:
			c.draw_circle(Vector2(x, y - size * 0.36), 4, Color(INK, 0.6))
			_wrapped(c, OfficeSim.OBSERVATIONS[id], Vector2(x + 20, y), size, INK, width)
		y += h + size * 0.45
	return {"fits": y - size * 1.9 <= bottom, "next": Vector2(x, y)}

func _draw_menu(c: Node2D) -> void:
	if sim.return_view == "title":
		c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color("070b0f"))   # nothing of the room before the opening
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.93))
	_text(c, "Paused" if sim.return_view != "title" else "Options", Vector2(0, 260), 40, PAPER, serif, SIZE.x)
	var labels := ["Resume", "Motion & flicker: " + ("on" if sim.state.motion else "off"),
		"Soften sudden sounds: " + ("on" if sim.state.soft_audio else "off"),
		"Restart? Click again" if _restart_armed() else "Restart slice"]
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
	if slab_a > 0.0:
		c.draw_rect(Rect2(20, 994, 1408, 80), Color(0.03, 0.06, 0.08, 0.9 * slab_a))
	if chain_active() and sim.view != "threshold":
		# More to come: a click brings the next line up.
		var pulse := 0.75 + 0.25 * sin(time * 2.0) if sim.state.motion else 1.0
		c.draw_string(serif, Vector2(1392, 1040), "▸", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(PAPER, 0.55 * pulse))
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
	if sim.view == "threshold" and continue_ready:
		var a := clampf((threshold_t - continue_t - 1.5) / 1.5, 0.0, 1.0)
		if a > 0.0:
			var prompt := "Click the doorway to step into the corridor."
			var w := hand.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 60
			c.draw_rect(Rect2((SIZE.x - w) / 2.0, 940, w, 40), Color(0.03, 0.06, 0.08, 0.85 * a))
			_text(c, prompt, Vector2(0, 967), 22, Color(PAPER, 0.9 * a), hand, SIZE.x)
	if dev:
		c.draw_rect(Rect2(20, 90, 520, 150), Color(0, 0, 0, 0.75))
		var y := 120
		for line in ["DEV (F1)  stage %d  view %s" % [sim.stage(), sim.view],
				"1-5 jump to stage 0-3, 4 = report filed", "objective: " + sim.objective()]:
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
