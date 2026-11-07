extends RoomView
## R04, the Listening Room: renderer. Presents R04Sim (game/rooms/R04/R04_sim.gd) and never
## mutates it. Everything timed here (needle arm, playhead, coast, holds, needle wander, loop
## fades) is presentation and is never saved.
##
## Layering:
##   `room` (world, under CanvasModulate + small lamp lights): the stage plate of view A (funnel
##          wall) or B (channel board), the painted escalation overlays and the code-drawn labels;
##          over them two light layers, `light_mul` (multiply: vignette, falloff from the lamp, the
##          stage's cold) and `light_add` (additive: the lamp's warm pool), painted per stage.
##   CanvasLayer 5 `close`: the close-ups c_spindle, c_mixer, c_channels (always fully lit).
##
## Painted plates: assets/rooms/R04/*.png (tools/art/rooms/R04.py). Every label, numeral,
## notch, seam and waveform is drawn here, so the clues stay exact and legible.

const DIR := "res://assets/rooms/R04/%s.png"

const PAPER := Color("ded4ba")
const PAPER_HI := Color("e8e1cf")
const INK := Color("172b36")
const AMBER := Color("c39959")
const BRUISE := Color("746577")
const BRASS := Color("9c7e46")
const BRASS_HI := Color("c9a869")
const THROAT := Color("0e161c")
const GUIDE := Color("805434")       # brown ink: the guide ruled on the chart glass
const PENCIL := Color(0.30, 0.31, 0.34)
const SEAGLASS_HI := Color("96b2a6")

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["spindle", Rect2(940, 470, 280, 120), "Cylinder spindle"],
	["band_tray", Rect2(1230, 520, 110, 72), "Recording bands"],
	["printer", Rect2(1010, 220, 260, 200), "Transcript printer"],
	["stool", Rect2(150, 610, 240, 300), "Listening seat"],
	["funnels", Rect2(160, 100, 660, 420), "Ear trumpets"],
	["plaster", Rect2(90, 96, 820, 420), "Sealed plaster"],
	["to_board", Rect2(1350, 640, 90, 250), "Channel board"],
]
## View B, the channel board.
const BOARD_HOTSPOTS := [
	["witness_key", Rect2(960, 430, 180, 170), "WITNESS key"],
	["channel_a", Rect2(430, 390, 150, 240), "Channel A"],
	["channel_b", Rect2(600, 390, 150, 240), "Channel B"],
	["channel_c", Rect2(770, 390, 150, 240), "Channel C"],
	["motor", Rect2(220, 400, 170, 230), "Motor switch"],
	["mixer", Rect2(420, 670, 620, 200), "Mixer"],
	["speaker", Rect2(560, 100, 330, 220), "Speaker funnel"],
	["to_funnels", Rect2(8, 640, 90, 250), "Funnel wall"],
]
const EXIT_RECTS := {
	"R02": Rect2(20, 922, 250, 64),
	"R03": Rect2(282, 922, 250, 64),
}

## Close-up controls: [id, rect, hover label].
const MIXER_CONTROLS := [
	["off_left", Rect2(240, 600, 120, 110), "Offset left"],
	["off_right", Rect2(1090, 600, 120, 110), "Offset right"],
	["toggle_venn", Rect2(260, 770, 240, 130), "VENN channel"],
	["toggle_nora", Rect2(540, 770, 240, 130), "NORA channel"],
	["look_sheet", Rect2(820, 770, 160, 130), "Contact sheet"],
	["play", Rect2(1010, 770, 240, 130), "PLAY"],
]
const CHANNEL_CONTROLS := [
	["motor", Rect2(150, 250, 190, 380), "MOTOR"],
	["key_a", Rect2(420, 250, 190, 380), "Channel A key"],
	["key_b", Rect2(650, 250, 190, 380), "Channel B key"],
	["key_c", Rect2(880, 250, 190, 380), "Channel C key"],
	["witness", Rect2(1120, 300, 220, 260), "WITNESS key"],
	["procedure", Rect2(150, 660, 940, 120), "Procedure"],
	["q_where", Rect2(150, 820, 370, 120), "Where are they?"],
	["q_whole", Rect2(540, 820, 370, 120), "Are they still themselves?"],
	["q_need", Rect2(930, 820, 370, 120), "What do you need from me?"],
]

## Base levels for one-shots (dB), and the sudden ones "Soften sudden sounds" turns down.
const SFX_DB := {"throat_clear": -10.0, "motor_click": -12.0, "band_seat": -8.0, "band_lift": -9.0,
	"band_click": -10.0, "needle_down": -8.0, "needle_skip": -6.0, "wax_fragment_1": -8.0,
	"wax_fragment_2": -8.0, "recording_p02": -4.0, "cylinder_coast": -9.0, "printer_chatter": -12.0,
	"slider_step": -12.0, "toggle_channel": -11.0, "mix_overlap": -6.0, "mix_combined": -4.0,
	"mix_venn": -4.0, "mix_nora": -4.0, "breath_c": -9.0, "switch_motor": -8.0, "key_channel": -9.0,
	"witness_key": -7.0, "reject_buzz": -9.0, "relay_on": -11.0, "relay_off": -7.0,
	"venn_answer_where": -4.0, "venn_answer_whole": -4.0, "venn_answer_need": -4.0, "venn_funnel": -3.0}
const SFX_SOFT := ["needle_skip", "reject_buzz", "relay_off", "venn_funnel"]
## The funnel voice must still be heard: it is only taken down 8 dB.
const SFX_SOFT_CUT := {"venn_funnel": 8.0}

const LOOPS := ["r04_room", "r04_motor", "r04_leak_wind", "r04_leak_rain", "r04_c_tone", "r04_pressure"]
## Voices the room ducks its loops under (8 dB).
const DUCK_IDS := ["recording_p02", "mix_overlap", "mix_combined", "mix_venn", "mix_nora",
	"venn_answer_where", "venn_answer_whole", "venn_answer_need", "venn_funnel"]
const LOOP_RATE := 0.11        # linear units / s: a ~1.5 s fade at these levels
const DARK_SILENCE := 4.0      # seconds of silence round the funnel voice after channel C goes dark

## Interior tint per weather band. The stage's light and cold are painted (the light maps),
## so this only cools the room a touch more as the band rises.
const TINT := [Color(1, 1, 1), Color(1, 1, 1), Color(0.99, 0.99, 1), Color(0.98, 0.99, 1),
	Color(0.97, 0.98, 1), Color(0.96, 0.975, 0.99), Color(0.95, 0.97, 0.99), Color(0.94, 0.96, 0.98)]

## Funnel number tabs (centre x, top y), hung on wires painted in tools/art/rooms/R04.py
## (TABS / TABS_TURNED there). Turned: the bells aimed at the seat (band 4+).
const TABS := [Vector2(353, 262), Vector2(553, 262), Vector2(753, 262), Vector2(353, 452),
	Vector2(456, 364), Vector2(753, 452)]
const TABS_TURNED := [Vector2(294, 267), Vector2(465, 266), Vector2(644, 261), Vector2(292, 457),
	Vector2(471, 509), Vector2(702, 394)]
const TAG5_EYELET := Vector2(540, 392)
## Band 7: the plaster swells about this point, 1-2 px on a 6 s breath.
const BULGE_CENTRE := Vector2(510, 300)
const BULGE_PERIOD := 6.0
const BULGE_AMP := 0.0035
## Band 5+: the transcript strip lifts from the printer as if breathed on, every 7 s.
const PAPER_PIVOT := Vector2(1138, 398)
const PAPER_PERIOD := 7.0
const CHANNEL_X := {"A": 505.0, "B": 675.0, "C": 845.0}
const CUTS := {"A": 1, "B": 2, "C": 3}
const CUT_WORDS := {"A": "one cut", "B": "two cuts", "C": "three cuts"}
const CLOSE_X := {"A": 515.0, "B": 745.0, "C": 975.0}

## Notice holds: focus rects.
const HOLD_TIME := 1.5
const NOTICE_FOCUS := {
	"throat": Rect2(630, 145, 140, 140),
	"leak_wind": Rect2(430, 310, 140, 140),
	"leak_silence": Rect2(160, 100, 660, 420),
	"funnels_turned": Rect2(150, 100, 680, 810),
	"plaster_bulge": Rect2(90, 96, 820, 420),
}

# c_spindle geometry ------------------------------------------------------------------------
const SLOT_X0 := 260.0
const SLOT_STEP := 330.0
const SLOT_Y := 370.0
const BAND_SIZE := Vector2(320, 220)
const PHASE_Y0 := 50.0         # band-local y of snap I (absolute 420 when seated)
const PHASE_DY := 60.0
const TRAY_RECTS := {"C": Rect2(300, 740, 250, 170), "A": Rect2(600, 740, 250, 170), "B": Rect2(900, 740, 250, 170)}
const TRAY_TINT := {"C": Color(0.74, 0.67, 0.59), "A": Color(0.93, 0.90, 0.84), "B": Color(1, 1, 1)}
const BREAK_X := {"start_end": 260.0, "start_arrow": 260.0, "join1": 585.0, "join2": 915.0}
const PLAY_RECT := Rect2(1250, 380, 170, 220)
const ARROW_RECT := Rect2(192, 380, 64, 90)
const CARD_RECT := Rect2(260, 110, 980, 230)
const ARM_PIVOT := Vector2(1400, 400)
const ARM_UP := 0.5           # radians: the stylus lifted clear of the bands
const ARM_DOWN_TIME := 0.4
## The recording, in recording time (s from the start of recording_p02): caption starts,
## the throat clear and the breath, and the end of the motor.
const REC_CAPTIONS := [0.2, 5.0, 8.6, 11.4]
const REC_THROAT := 9.8
const REC_BREATH := 10.8
const REC_LEN := 15.6
const COAST_TIME := 3.0
const TRACE_X0 := 290.0
const TRACE_X1 := 1210.0
const TRACE_Y := 312.0

# c_mixer geometry --------------------------------------------------------------------------
const GUIDE_X := 725.0
const STEP_PX := 70.0          # waveform shift per offset step
const DETENT_PX := 104.5       # the painted detents (412 + 104.5 k)
const LANE_Y := [260.0, 450.0]
const WIN_X0 := 212.0
const WIN_X1 := 1238.0
const LOG_CARD := Rect2(1282, 160, 136, 388)

var r: R04Sim:
	get:
		return sim as R04Sim

var textures := {}
var mono: SystemFont
var narrow: SystemFont
var room: Node2D
var close: Node2D
var shade: CanvasModulate
var light_mul: Node2D         # multiply light map over the plate and overlays
var light_add: Node2D         # additive warm light
var lamp_lights := {}          # "A"/"B"/"C" -> PointLight2D
var mixer: LoopMixer
var wave := PackedFloat32Array()

# presentation state (never saved)
var arm_k := 0.0               # 0 up, 1 down
var arm_target := 0.0
var arm_lift_at := -1.0        # time the arm lifts after a failed play
var jolt_t := 0.0
var rec_start := -1.0          # time recording_p02 began
var coast_t := -1.0            # seconds into the coast, -1 = none
var coast_pending := false
var coasted := false           # the seam mark has slid one band (held)
var hold_t := 0.0
var hold_rect := Rect2()
var hold_on_board := false
var zoom_k := 0.0
var witness_t := 0.0           # seconds left of the pressed WITNESS key
var c_hold := false            # channel C stays lit until the relay actually drops
var c_dark_pending := false
var dark_t := 0.0              # seconds left of the silence after channel C goes dark
var soft_cut_t := 0.0
var needles := {"A": -40.0, "B": -40.0, "C": -40.0}
var tint := Color(1, 1, 1)

func _ready() -> void:
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Liberation Mono", "Noto Mono", "monospace"])
	narrow = SystemFont.new()
	narrow.font_names = PackedStringArray(["Liberation Sans Narrow", "Nimbus Sans Narrow", "DejaVu Sans Condensed", "sans-serif"])
	narrow.font_weight = 700
	var g := RandomNumberGenerator.new()
	g.seed = 1931_04_17
	for i in 240:
		wave.append(g.randf())
	_build_nodes()
	_build_audio()
	apply_instantly()
	redraw()

func _tex(id: String) -> Texture2D:
	if not textures.has(id):
		var path := DIR % id
		textures[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return textures[id]

func _radial(size: int) -> GradientTexture2D:
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = gr
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
	add_child(shade)
	light_mul = _light_layer(CanvasItemMaterial.BLEND_MODE_MUL, "mul")
	light_add = _light_layer(CanvasItemMaterial.BLEND_MODE_ADD, "add")
	var glow := _radial(256)
	for ch in ["A", "B", "C"]:
		var l := PointLight2D.new()
		l.texture = glow
		l.texture_scale = 1.3
		l.color = AMBER.lightened(0.2)
		l.energy = 0.0
		l.position = Vector2(CHANNEL_X[ch], 440)
		room.add_child(l)
		lamp_lights[ch] = l
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	close = Node2D.new()
	layer.add_child(close)
	close.draw.connect(_draw_close)

func _light_layer(mode: int, kind: String) -> Node2D:
	var n := Node2D.new()
	n.name = "Light_" + kind
	var m := CanvasItemMaterial.new()
	m.blend_mode = mode
	n.material = m
	n.light_mask = 0
	n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	room.add_child(n)
	n.draw.connect(func() -> void: _draw_light(n, kind))
	return n

## "s1" bands 0-2, "s2" 3-4, "s3" 5-6, "s4" 7; "sever" once the room has been released.
func stage() -> String:
	if r.ending() == "sever":
		return "sever"
	var b := _band()
	return "s1" if b <= 2 else ("s2" if b <= 4 else ("s3" if b <= 6 else "s4"))

func _side() -> String:
	return "b" if _view() == "board" or (r.is_closeup() and _view() != "c_spindle") else "a"

func plate_id() -> String:
	var b := _band()
	if _side() == "b":
		return {"s1": "view_b", "s2": "view_b_s2", "s3": "view_b_s3", "s4": "view_b_s4", "sever": "view_b"}[stage()]
	if stage() == "sever":
		return "view_a_sever"
	if b <= 2:
		return "view_a"
	if b == 3:
		return "view_a_s2"
	if b == 4:
		return "view_a_turned"
	return "view_a_s3" if b <= 6 else "view_a_s4"

## The bells aim at the seat from band 4, until the room is released.
func turned() -> bool:
	return _band() >= 4 and r.ending() != "sever"

func _draw_light(n: Node2D, kind: String) -> void:
	var t := _tex("%s_%s_%s" % [_side(), kind, stage()])
	if t:
		n.draw_texture_rect(t, Rect2(Vector2.ZERO, SIZE), false)

func _build_audio() -> void:
	mixer = LoopMixer.new()
	add_child(mixer)
	if game == null:
		return
	for id in LOOPS:
		mixer.add_loop(id, game.load_audio(id))

# ---------------------------------------------------------------------------
# state reads (presentation only)
# ---------------------------------------------------------------------------
func _view() -> String:
	return r.local_view

func _band() -> int:
	return r.band()

## Channel C's lamp: lit at band 0 and while the witness line is open; held lit through the
## last answer until the relay drops. All lamps are off once an ending is chosen.
func lamp_lit(ch: String) -> bool:
	if r.ending() != "":
		return false
	if ch == "C":
		return r.indicator_lit("C") or c_hold or _band() == 0
	return r.indicator_lit(ch)

func _needle_target(ch: String) -> float:
	var mode := r.needle_mode(ch)
	if ch == "C" and lamp_lit("C"):
		mode = "live"
	var ph: float = {"A": 0.0, "B": 2.1, "C": 4.3}[ch]
	match mode:
		"live":
			if motion:
				return -8.0 + 14.0 * sin(time * 0.37 + ph) + 6.0 * sin(time * 0.91 + ph * 1.7)
			return -8.0
		"tremble":
			if motion:
				return -22.0 + 3.0 * sin(time * 13.0) * (0.6 + 0.4 * sin(time * 2.3))
			return -22.0
	return -40.0

func _p16() -> bool:
	return gsim().flag("P16") if gsim() else false

func _has_sheet() -> bool:
	return gsim().has_item("contact_sheet") if gsim() else false

func _questions_live() -> bool:
	return r.state.witness_open or r.state.p19_complete

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------
func tick(dt: float) -> void:
	# needle arm
	if arm_lift_at >= 0.0 and time >= arm_lift_at:
		arm_lift_at = -1.0
		arm_target = 0.0
	if motion:
		arm_k = move_toward(arm_k, arm_target, dt / ARM_DOWN_TIME)
	else:
		arm_k = arm_target
	jolt_t = maxf(0.0, jolt_t - dt)
	witness_t = maxf(0.0, witness_t - dt)
	if coast_t >= 0.0:
		coast_t += dt
		if coast_t >= COAST_TIME or not motion:
			coast_t = -1.0
			coasted = true
	# notice hold
	if hold_t > 0.0:
		hold_t = maxf(0.0, hold_t - dt)
	var zt := 0.0
	if hold_t > 0.0 and motion and not r.is_closeup():
		zt = 1.0
	zoom_k = move_toward(zoom_k, zt, dt * 2.5)
	var s := 1.0 + 0.04 * smoothstep(0.0, 1.0, zoom_k)
	var focus := hold_rect.get_center()
	room.scale = Vector2(s, s)
	room.position = focus * (1.0 - s)
	# needles, tint, lamps
	for ch in needles:
		var target := _needle_target(ch)
		needles[ch] = move_toward(needles[ch], target, dt * 70.0) if motion else target
	var tt: Color = TINT[clampi(_band(), 0, 7)]
	tint = Color(move_toward(tint.r, tt.r, dt * 0.2), move_toward(tint.g, tt.g, dt * 0.2),
		move_toward(tint.b, tt.b, dt * 0.2))
	shade.color = tint
	_tick_lamps()
	dark_t = maxf(0.0, dark_t - dt)
	soft_cut_t = maxf(0.0, soft_cut_t - dt)
	_tick_audio(dt)
	redraw()

func _tick_lamps() -> void:
	var on_board := _view() == "board"
	for ch in lamp_lights:
		lamp_lights[ch].energy = 1.0 if on_board and lamp_lit(ch) else 0.0

func loop_targets() -> Dictionary:
	var b := _band()
	var ending := r.ending()
	var db := {}
	db["r04_room"] = -16.0 if b <= 2 else (-21.0 if b <= 6 else -18.0)
	if ending == "":
		if r.state.motor_on:
			db["r04_motor"] = -22.0
		if b == 1:
			db["r04_leak_wind"] = -20.0
		elif b == 2:
			db["r04_leak_wind"] = -24.0
			db["r04_leak_rain"] = -21.0
		if r.state.p17_complete and not r.state.p19_complete:
			db["r04_c_tone"] = -18.0 if _view() in ["c_channels", "board"] else -24.0
		if b == 7:
			db["r04_pressure"] = -18.0
	var duck := game != null and game.oneshot_playing(DUCK_IDS)
	var out := {}
	for id in LOOPS:
		if not db.has(id) or (dark_t > 0.0 and id != "r04_room"):
			out[id] = 0.0
		else:
			out[id] = db_to_linear(db[id] - (8.0 if duck else 0.0))
	return out

func _tick_audio(dt: float) -> void:
	var targets := loop_targets()
	var rates := {}
	for id in LOOPS:
		rates[id] = 0.6 if soft_cut_t > 0.0 and id != "r04_room" else LOOP_RATE
	mixer.tick(targets, rates, dt)

## The relay has dropped: channel C goes dark at once, and every loop but the room tone
## falls silent so the funnel voice lands in silence (0.3 s under "Soften sudden sounds").
func _cut_c() -> void:
	c_hold = false
	c_dark_pending = false
	dark_t = DARK_SILENCE
	if soft_audio:
		soft_cut_t = 0.3
		return
	for id in mixer.players:
		if id != "r04_room":
			mixer.mix[id] = 0.0
			mixer.players[id].volume_db = -80.0

# ---------------------------------------------------------------------------
# hooks
# ---------------------------------------------------------------------------
func play_fx(id: String, _e: Dictionary) -> void:
	if id.begins_with("notice_"):
		_start_hold(id.substr(7))
		return
	match id:
		"needle_down":
			arm_target = 1.0
			arm_lift_at = -1.0
			coast_pending = true
			if not motion:
				arm_k = 1.0
		"seam_break":
			arm_target = 1.0
			arm_lift_at = time + 3.4
			coast_pending = false
			if not motion:
				arm_k = 1.0
		"cylinder_coast":
			coast_pending = true   # the coast itself starts with its sound
		"c_open":
			c_hold = false
			witness_t = 0.3
		"c_dark":
			# The sim closes the line at once; the lamp holds until the relay drops.
			c_hold = true
			c_dark_pending = true
		"c_presence", "funnel_voice":
			pass

func on_sfx(id: String) -> void:
	match id:
		"recording_p02":
			rec_start = time
			coasted = false
		"needle_skip":
			jolt_t = 0.25 if motion else 0.0
		"cylinder_coast":
			arm_target = 0.0
			if not motion:
				arm_k = 0.0
			if coast_pending:
				coast_pending = false
				coast_t = 0.0 if motion else -1.0
				if not motion:
					coasted = true
		"witness_key", "reject_buzz":
			witness_t = 0.3
		"relay_off":
			if c_dark_pending:
				_cut_c()

func _start_hold(n: String) -> void:
	var rect: Rect2 = NOTICE_FOCUS.get(n, Rect2())
	hold_on_board = false
	if n == "c_presence":
		if _view() == "board":
			rect = BOARD_HOTSPOTS[3][1]
			hold_on_board = true
		else:
			rect = HOTSPOTS[6][1]
	if rect.size == Vector2.ZERO:
		return
	hold_rect = rect
	hold_t = HOLD_TIME

func hold_active() -> bool:
	return hold_t > 0.0

func apply_instantly() -> void:
	tint = TINT[clampi(_band(), 0, 7)]
	shade.color = tint
	arm_k = 0.0
	arm_target = 0.0
	for ch in needles:
		needles[ch] = _needle_target(ch)
	_tick_lamps()
	if mixer:
		mixer.snap(loop_targets())
	room.scale = Vector2.ONE
	room.position = Vector2.ZERO
	zoom_k = 0.0

func reset_presentation() -> void:
	arm_k = 0.0
	arm_target = 0.0
	arm_lift_at = -1.0
	jolt_t = 0.0
	rec_start = -1.0
	coast_t = -1.0
	coast_pending = false
	coasted = false
	hold_t = 0.0
	zoom_k = 0.0
	witness_t = 0.0
	c_hold = false
	c_dark_pending = false
	dark_t = 0.0
	soft_cut_t = 0.0

func redraw() -> void:
	room.queue_redraw()
	close.queue_redraw()
	light_mul.queue_redraw()
	light_add.queue_redraw()

func back_visible() -> bool:
	return _view() != "room"

func esc_action() -> String:
	return "back" if _view() != "room" else "menu"

func exits_active() -> bool:
	return _view() == "room"

# ---------------------------------------------------------------------------
# input
# ---------------------------------------------------------------------------
func _controls() -> Array:
	match _view():
		"room":
			return HOTSPOTS
		"board":
			return BOARD_HOTSPOTS
		"c_spindle":
			return spindle_controls()
		"c_mixer":
			var out := []
			for h in MIXER_CONTROLS:
				if h[0] != "look_sheet" or _has_sheet():
					out.append(h)
			return out
		"c_channels":
			var out := []
			for h in CHANNEL_CONTROLS:
				if not str(h[0]).begins_with("q_") or _questions_live():
					out.append(h)
			return out
	return []

static func spindle_controls() -> Array:
	var out := []
	for k in 3:
		out.append(["rot_down_%d" % k, Rect2(270 + SLOT_STEP * k, 610, 140, 70), "◁ I-II-III"])
		out.append(["rot_up_%d" % k, Rect2(430 + SLOT_STEP * k, 610, 140, 70), "I-II-III ▷"])
		out.append(["slot_%d" % k, Rect2(SLOT_X0 + SLOT_STEP * k, SLOT_Y, 320, 220), "Spindle position %d" % (k + 1)])
	for b in ["C", "A", "B"]:
		out.append(["tray_" + b, TRAY_RECTS[b], "Band " + b])
	out.append(["play", PLAY_RECT, "PLAY"])
	out.append(["look_arrow", ARROW_RECT, "START arrow"])
	return out

func action_at(p: Vector2) -> String:
	if hold_t > 0.0:
		hold_t = 0.0   # a click skips the hold, and does nothing else
		return ""
	for h in _controls():
		if h[1].has_point(p):
			return h[0]
	return ""

func hover_at(p: Vector2) -> String:
	if hold_t > 0.0:
		return ""
	for h in _controls():
		if h[1].has_point(p):
			return h[0]
	return ""

func label_for(id: String) -> String:
	for table in [HOTSPOTS, BOARD_HOTSPOTS, _controls()]:
		for h in table:
			if h[0] == id:
				return h[2]
	return ""

func dev_rects() -> Array:
	var out := []
	for h in _controls():
		out.append(h[1])
	return out

# ---------------------------------------------------------------------------
# text helpers
# ---------------------------------------------------------------------------
func _text(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, font: Font = null) -> void:
	c.draw_string(font if font else Ink.serif(), pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## Centred on x; `y` is the baseline.
func _ctext(c: CanvasItem, s: String, x: float, y: float, size: int, col: Color, font: Font = null) -> void:
	var f: Font = font if font else Ink.serif()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(f, Vector2(x - w / 2.0, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _wrap(s: String, font: Font, size: int, width: float) -> Array:
	var out := []
	var line := ""
	for word in s.split(" "):
		var trial: String = word if line == "" else line + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out

func _ring(c: CanvasItem, center: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := Ink.ellipse(center, rx, ry, 64)
	pts.append(pts[0])
	c.draw_polyline(pts, col, w, true)

func _plate(c: CanvasItem, rect: Rect2, s: String, size: int) -> void:
	c.draw_rect(rect, PAPER_HI)
	c.draw_rect(rect, INK, false, 2.0)
	_ctext(c, s, rect.get_center().x, rect.get_center().y + size * 0.36, size, INK, narrow)

# ---------------------------------------------------------------------------
# drawing: view A and view B (world)
# ---------------------------------------------------------------------------
func _draw_room() -> void:
	if _view() == "board" or (r.is_closeup() and _view() != "c_spindle"):
		_draw_view_b(room)
	else:
		_draw_view_a(room)
	if hold_t > 0.0 and not r.is_closeup():
		var a := 0.9 if not motion else 0.9 * smoothstep(0.0, 0.3, HOLD_TIME - hold_t)
		var ctr := hold_rect.get_center()
		var rad := hold_rect.size * 0.5 + Vector2(22, 22)
		_ring(room, ctr, rad.x, rad.y, Color(INK, a * 0.85), 8.0)
		_ring(room, ctr, rad.x, rad.y, Color(PAPER_HI, a), 3.0)

func _full(c: CanvasItem, id: String) -> void:
	var t := _tex(id)
	if t:
		c.draw_texture_rect(t, Rect2(Vector2.ZERO, SIZE), false)

## 0..1, a slow intake and a quicker release; 0 with motion off (the still alternative).
func _breath(period: float, phase: float = 0.0) -> float:
	if not motion:
		return 0.0
	return pow(maxf(0.0, sin(TAU * (time / period + phase))), 3.0)

func _draw_view_a(c: CanvasItem) -> void:
	var b := _band()
	var sever := r.ending() == "sever"
	var tu := turned()
	_full(c, plate_id())
	if not sever:
		if b == 2 or b == 3:
			_full(c, "a_condensation")
		elif b >= 4:
			_full(c, "a_condensation_turned")
		if b == 3 or b == 4:
			_full(c, "a_seat_rings")   # on the folded-up seat; let down from band 5
	if r.bulge_shown():
		var bt := _tex("a_bulge")
		if bt:
			var s := 1.0 + BULGE_AMP * (sin(TAU * time / BULGE_PERIOD) if motion else 0.0)
			c.draw_set_transform(BULGE_CENTRE * (1.0 - s), 0.0, Vector2(s, s))
			c.draw_texture_rect(bt, Rect2(Vector2.ZERO, SIZE), false)
			c.draw_set_transform_matrix(Transform2D.IDENTITY)
	if r.state.p02_complete:
		_full(c, "a_mounted")
		if b == 7 and not sever:
			_full(c, "a_printout_long")
		var tt := _tex("a_transcript")
		if tt:
			var lift := 0.0
			if b >= 5 and not sever:
				lift = -deg_to_rad(1.6) * _breath(PAPER_PERIOD)
			c.draw_set_transform(PAPER_PIVOT, lift, Vector2.ONE)
			c.draw_texture_rect(tt, Rect2(-PAPER_PIVOT, SIZE), false)
			c.draw_set_transform_matrix(Transform2D.IDENTITY)
	# funnel numbers on their enamel tabs
	var tabs: Array = TABS_TURNED if tu else TABS
	for i in 6:
		var p: Vector2 = tabs[i]
		var tab := Rect2(p.x - 15, p.y + 4, 30, 27)
		c.draw_rect(tab, PAPER_HI)
		c.draw_rect(tab, INK, false, 2.0)
		_ctext(c, str(i + 1), p.x, p.y + 25, 20, INK)
	# funnel 5's paper tag: lifted by the wind at bands 1-2
	if b == 1 or b == 2:
		var tag := _tex("a_tag5")
		if tag:
			var deg := -35.0
			if motion:
				deg = -35.0 - 15.0 * clampf(0.62 * sin(time * 2.3) + 0.38 * sin(time * 5.7 + 1.3), -1.0, 1.0)
			c.draw_set_transform(TAG5_EYELET, deg_to_rad(deg), Vector2.ONE)
			c.draw_texture(tag, Vector2(-6, -24))
			c.draw_set_transform_matrix(Transform2D.IDENTITY)
	# the spindle's START arrow field
	_arrow(c, Vector2(968, 519), 22, INK)
	# the way through to the board
	_plate(c, Rect2(1362, 650, 70, 26), "BOARD", 16)

func _arrow(c: CanvasItem, at: Vector2, w: float, col: Color) -> void:
	c.draw_line(at, at + Vector2(w * 0.7, 0), col, 3.0)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(w * 0.55, -w * 0.3), at + Vector2(w, 0),
		at + Vector2(w * 0.55, w * 0.3)]), col)

func _notches(c: CanvasItem, x: float, top: float, n: int, w: float, h: float) -> void:
	for i in n:
		var cx := x + i * (w + 4)
		c.draw_colored_polygon(PackedVector2Array([Vector2(cx - w / 2, top), Vector2(cx + w / 2, top),
			Vector2(cx, top + h)]), THROAT)

func _draw_view_b(c: CanvasItem) -> void:
	var b := _band()
	_full(c, plate_id())
	if b >= 2 and r.ending() != "sever":
		_full(c, "b_condensation")
	if r.state.p19_complete:
		_full(c, "b_speaker_wet")
	if r.bulge_shown():
		_full(c, "b_bulge")
	if not r.state.motor_on:
		_full(c, "b_motor_off")
	if _p16():
		_full(c, "b_spool")
		_ctext(c, "SESSION", 560, 794, 12, INK, narrow)
		if r.state.p17_complete:
			_full(c, "b_mixer_aligned")
		else:
			_draw_b_traces(c)
	# motor
	_ctext(c, "MOTOR", 305, 430, 16, INK, narrow)
	_ctext(c, "ON" if r.state.motor_on else "OFF", 352, 536, 16, PAPER_HI, narrow)
	# channels
	var lit_tex := _tex("b_lamp_lit")
	var needle := _tex("b_needle")
	for ch in ["A", "B", "C"]:
		var x: float = CHANNEL_X[ch]
		_ctext(c, ch, x - 34, 416, 20, INK)
		_notches(c, x + 6, 394, CUTS[ch], 9.0, 10.0)
		if lamp_lit(ch) and lit_tex:
			c.draw_texture(lit_tex, Vector2(x, 440) - lit_tex.get_size() / 2.0)
		if needle:
			c.draw_set_transform(Vector2(x, 548), deg_to_rad(needles[ch]), Vector2.ONE)
			c.draw_texture(needle, Vector2(-5, -72))
			c.draw_set_transform_matrix(Transform2D.IDENTITY)
		var open: bool = r.state.ch_open[ch]
		var key := _tex("b_key_open" if open else "b_key_closed")
		if key:
			c.draw_texture(key, Vector2(x - 55, 555))
		_ctext(c, "OPEN" if open else "CLOSED", x, 637 if open else 574, 14, INK, narrow)
	# WITNESS
	_ctext(c, "WITNESS", 1050, 585, 17, INK, narrow)
	_plate(c, Rect2(14, 650, 84, 26), "FUNNELS", 15)

## The session spool before the bells are aligned: two traces, the second bell off the guide.
func _draw_b_traces(c: CanvasItem) -> void:
	var off := int(r.state.offset)
	var gx := 730.0
	for lane in 2:
		var base := 718.0 if lane == 0 else 756.0
		var shift := 0.0 if lane == 0 else 35.0 * (off + 2)
		var peak := gx + shift
		var pts := PackedVector2Array()
		var x := 474.0
		var i := 0
		while x <= 986.0:
			if absf(x - peak) < 8.0:
				pts.append(Vector2(peak - 6, base))
				pts.append(Vector2(peak, base - 24))
				pts.append(Vector2(peak + 6, base + 3))
				x = peak + 10.0
				continue
			pts.append(Vector2(x, base + (wave[(i + lane * 37) % wave.size()] - 0.5) * 6.0))
			x += 6.0
			i += 1
		c.draw_polyline(pts, INK, 2.0, true)
	for y in range(692, 770, 8):
		c.draw_line(Vector2(gx, y), Vector2(gx, y + 4), GUIDE, 2.0)

# ---------------------------------------------------------------------------
# drawing: close-ups (layer 5)
# ---------------------------------------------------------------------------
func _draw_close() -> void:
	match _view():
		"c_spindle":
			_draw_spindle(close)
		"c_mixer":
			_draw_mixer(close)
		"c_channels":
			_draw_channels(close)

# --- c_spindle ------------------------------------------------------------------------------
func _rec_t() -> float:
	return time - rec_start if rec_start >= 0.0 else -1.0

func _recording() -> bool:
	var t := _rec_t()
	return t >= 0.0 and t < REC_LEN + 0.4

## The playhead's x across the bands (and the trace): smooth with motion, else it jumps to
## the start of each caption.
func _playhead_x() -> float:
	var t := _rec_t()
	if not motion:
		var k := 0.0
		for ct in REC_CAPTIONS:
			if t >= ct:
				k = ct
		t = k
	return lerpf(TRACE_X0, TRACE_X1, clampf(t / REC_LEN, 0.0, 1.0))

func _band_phase_in(b: String) -> int:
	return (int(r.state.band_rot[b]) + int(R04Sim.SEAM[b]["in"])) % 3

func _band_phase_out(b: String) -> int:
	if R04Sim.SEAM[b].has("out"):
		return (int(r.state.band_rot[b]) + int(R04Sim.SEAM[b]["out"])) % 3
	return (int(r.state.band_rot[b]) + int(R04Sim.SEAM[b]["in"]) + 1) % 3   # B: to its END notch

func _draw_spindle(c: CanvasItem) -> void:
	_full(c, "c_spindle")
	var st: Dictionary = r.state
	var fixed: bool = st.p02_complete
	# START arrow and word at the left end
	_arrow(c, Vector2(207, 420), 36, INK)
	_ctext(c, "START", 225, 462, 15, INK, narrow)
	# PLAY on the lever
	_plate(c, Rect2(1270, 452, 74, 28), "PLAY", 17)
	# bands in the tray
	for b in ["C", "A", "B"]:
		if not b in st.spindle:
			var tr: Rect2 = TRAY_RECTS[b]
			var w := tr.size.y * BAND_SIZE.x / BAND_SIZE.y
			_draw_band(c, Rect2(tr.position + Vector2((tr.size.x - w) / 2.0, 0), Vector2(w, tr.size.y)), b, true)
	# bands on the spindle
	for k in 3:
		var b: String = st.spindle[k]
		if b != "":
			_draw_band(c, Rect2(SLOT_X0 + SLOT_STEP * k, SLOT_Y, BAND_SIZE.x, BAND_SIZE.y), b, false)
	# rotation buttons: arrows on the knobs; dimmed and FIXED once the recording is preserved
	for k in 3:
		var cx := SLOT_X0 + SLOT_STEP * k + 160.0
		var lk := Vector2(cx - 58, 645)
		var rk := Vector2(cx + 58, 645)
		c.draw_colored_polygon(PackedVector2Array([lk + Vector2(9, -12), lk + Vector2(9, 12), lk + Vector2(-11, 0)]), INK)
		c.draw_colored_polygon(PackedVector2Array([rk + Vector2(-9, -12), rk + Vector2(-9, 12), rk + Vector2(11, 0)]), INK)
		var b: String = st.spindle[k]
		var chip := Rect2(cx - 24, 626, 48, 32)
		c.draw_rect(chip, PAPER_HI)
		c.draw_rect(chip, INK, false, 2.0)
		if b != "":
			_ctext(c, ["I", "II", "III"][int(st.band_rot[b])], cx, 650, 22, INK)
		if fixed:
			for kp in [lk, rk]:
				c.draw_circle(kp, 33, Color(0.05, 0.07, 0.09, 0.55))
			var strap := Rect2(cx - 96, 662, 192, 24)
			c.draw_rect(strap, PAPER_HI)
			c.draw_rect(strap, BRUISE, false, 2.5)
			_ctext(c, "FIXED", cx, 680, 17, INK, narrow)
	if fixed:
		_ctext(c, "PRESERVE THE RECORDING  ·  DO NOT WIND", 715, 706, 16, PAPER_HI, narrow)
	# coast: the seam mark slides one band to the right and stays there
	if coast_t >= 0.0 or coasted:
		var k := 1.0 if coast_t < 0.0 else smoothstep(0.0, 1.0, coast_t / COAST_TIME)
		var mx := SLOT_X0 + 4.0 + SLOT_STEP * k
		var my := SLOT_Y + PHASE_Y0
		c.draw_colored_polygon(PackedVector2Array([Vector2(mx, my - 15), Vector2(mx + 26, my), Vector2(mx, my + 15)]),
			Color(THROAT, 0.75))
		c.draw_line(Vector2(mx + 26, my), Vector2(mx + 90, my), Color(INK, 0.45), 4.0)
	# playhead across the bands
	if _recording():
		var px := _playhead_x()
		c.draw_line(Vector2(px, 372), Vector2(px, 588), Color(INK, 0.5), 6.0)
		c.draw_line(Vector2(px, 372), Vector2(px, 588), Color("f2d79a"), 3.0)
		c.draw_line(Vector2(px, 120), Vector2(px, 334), Color(BRUISE, 0.8), 2.0)
	# seam break
	if r.seam_break != "":
		_draw_break(c, r.seam_break)
	_draw_card(c)
	_draw_arm(c)

func _draw_band(c: CanvasItem, rect: Rect2, b: String, in_tray: bool) -> void:
	var tex := _tex("c_band")
	var s := rect.size.x / BAND_SIZE.x
	c.draw_set_transform(rect.position, 0.0, Vector2(s, s))
	if tex:
		c.draw_texture(tex, Vector2.ZERO, TRAY_TINT[b])
	# grooves turning with the coast
	if coast_t >= 0.0 and not in_tray:
		var k := coast_t / COAST_TIME
		for g in 3:
			var gy := 16.0 + fposmod(k * 188.0 + g * 63.0, 188.0)
			c.draw_line(Vector2(34, gy), Vector2(286, gy), Color(INK, 0.4), 3.0)
	var rot := int(r.state.band_rot[b])
	var pin := _band_phase_in(b)
	var pout := _band_phase_out(b)
	var yin := PHASE_Y0 + PHASE_DY * pin
	var yout := PHASE_Y0 + PHASE_DY * pout
	# roman numerals on both edges, current position underlined
	var nums := ["I", "II", "III"]
	for edge in [16.0, 304.0]:
		for i in 3:
			var y := PHASE_Y0 + PHASE_DY * i
			if i == rot:
				c.draw_rect(Rect2(edge - 13, y + 5, 26, 26), PAPER_HI)
				c.draw_rect(Rect2(edge - 11, y + 27, 22, 4), INK)
			_ctext(c, nums[i], edge, y + 24, 18, INK, narrow)
	# the seam
	var x0 := 0.0
	var x1 := 320.0
	if b == "C":
		x0 = 20.0
	if b == "B":
		x1 = 290.0
	c.draw_line(Vector2(x0, yin), Vector2(x1, yout), INK, 4.0, true)
	# START notch: a V cut on C's left edge at its entry
	if b == "C":
		c.draw_colored_polygon(PackedVector2Array([Vector2(0, yin - 13), Vector2(22, yin), Vector2(0, yin + 13)]), THROAT)
		_text(c, "START", Vector2(36, yin - 8), 13, INK, narrow)
	# END notch: a square cut where B's seam stops
	if b == "B":
		c.draw_rect(Rect2(290, yout - 10, 20, 20), THROAT)
		_ctext(c, "END", 262, yout - 10, 14, INK, narrow)
	# the stamped letter
	_ctext(c, b, 160, 206, 52, Color(INK, 0.88))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_break(c: CanvasItem, kind: String) -> void:
	var x: float = BREAK_X.get(kind, 260.0)
	var y := 480.0
	var sp: Array = r.state.spindle
	match kind:
		"start_end", "start_arrow":
			if sp[0] != "":
				y = SLOT_Y + PHASE_Y0 + PHASE_DY * _band_phase_in(sp[0])
		"join1", "join2":
			var j := 0 if kind == "join1" else 1
			if sp[j] != "":
				y = SLOT_Y + PHASE_Y0 + PHASE_DY * _band_phase_out(sp[j])
	var ctr := Vector2(x, y)
	c.draw_circle(ctr, 46, Color(BRUISE, 0.18))
	_ring(c, ctr, 46, 46, Color(PAPER_HI, 0.9), 8.0)
	_ring(c, ctr, 46, 46, BRUISE, 5.0)
	# the gap: two short bars across the seam
	for dx in [-7.0, 7.0]:
		c.draw_line(ctr + Vector2(dx, -16), ctr + Vector2(dx, 16), INK, 4.0)
	var lab := Rect2(x - 34, y + 50, 68, 24)
	c.draw_rect(lab, PAPER_HI)
	c.draw_rect(lab, BRUISE, false, 2.5)
	_ctext(c, "BREAK", x, y + 68, 16, INK, narrow)

func _draw_card(c: CanvasItem) -> void:
	var lines: Array = r.transcript_lines()
	var t := _rec_t()
	var playing := _recording() and r.seam_break == ""
	_text(c, "TRANSCRIPT", Vector2(CARD_RECT.position.x + 48, 146), 15, Color(INK, 0.6), narrow)
	var y := 172.0
	for i in lines.size():
		var s: String = lines[i]
		if playing:
			if i >= REC_CAPTIONS.size() or t < REC_CAPTIONS[i]:
				break
			if motion:
				s = s.substr(0, int((t - REC_CAPTIONS[i]) * 40.0))
		for row in _wrap(s, mono, 17, CARD_RECT.size.x - 96):
			_text(c, row, Vector2(CARD_RECT.position.x + 48, y), 17, INK, mono)
			y += 22.0
	# the trace: the recording's envelope, written as it plays, whole afterwards
	if r.state.p02_complete and r.seam_break == "":
		var upto := TRACE_X1
		if playing:
			upto = _playhead_x()
		_draw_trace(c, upto)

## Deterministic envelope of the recording: speech, a creak, the throat clear, and after it a
## second, smaller breath nobody is credited with.
func _trace_amp(tt: float, i: int) -> float:
	var a := 0.06
	for seg in [[0.2, 4.6], [5.0, 8.2], [11.4, 15.2]]:
		if tt >= seg[0] and tt <= seg[1]:
			a = 0.35 + 0.5 * wave[i % wave.size()]
	if absf(tt - 9.0) < 0.15:
		a = maxf(a, 0.4)
	if absf(tt - REC_THROAT) < 0.25:
		a = maxf(a, 1.0 - absf(tt - REC_THROAT) * 2.0)
	if absf(tt - REC_BREATH) < 0.2:
		a = maxf(a, 0.55 - absf(tt - REC_BREATH) * 1.6)
	return a

func _draw_trace(c: CanvasItem, upto: float) -> void:
	c.draw_line(Vector2(TRACE_X0, TRACE_Y), Vector2(TRACE_X1, TRACE_Y), Color(INK, 0.25), 1.0)
	var n := 230
	for i in n:
		var x := lerpf(TRACE_X0, TRACE_X1, float(i) / (n - 1))
		if x > upto:
			break
		var tt := REC_LEN * float(i) / (n - 1)
		var h := _trace_amp(tt, i) * 26.0
		c.draw_line(Vector2(x, TRACE_Y - h), Vector2(x, TRACE_Y + h * 0.5), INK, 2.0)
	var bx := lerpf(TRACE_X0, TRACE_X1, REC_BREATH / REC_LEN)
	if upto >= bx:
		c.draw_line(Vector2(bx, TRACE_Y - 18), Vector2(bx + 18, TRACE_Y - 30), Color(INK, 0.7), 1.5)
		_text(c, "breath", Vector2(bx + 20, TRACE_Y - 28), 15, INK, Ink.hand())

func _draw_arm(c: CanvasItem) -> void:
	var tex := _tex("c_needle_arm")
	if tex == null:
		return
	var ang := lerpf(ARM_UP, 0.0, smoothstep(0.0, 1.0, arm_k))
	var jolt := 0.0
	if jolt_t > 0.0 and motion:
		jolt = 6.0 * sin(jolt_t * 90.0)
	c.draw_set_transform(ARM_PIVOT + Vector2(0, jolt), ang, Vector2.ONE)
	c.draw_texture(tex, Vector2(-240, -20))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- c_mixer --------------------------------------------------------------------------------
func _bell(c: CanvasItem, top: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for p in [Vector2(-2, 0), Vector2(2, 0), Vector2(6, 3), Vector2(7, 9), Vector2(8, 14), Vector2(11, 17),
			Vector2(-11, 17), Vector2(-8, 14), Vector2(-7, 9), Vector2(-6, 3), Vector2(-2, 0)]:
		pts.append(top + p)
	c.draw_polyline(pts, col, 2.0, true)
	c.draw_circle(top + Vector2(0, 20), 2.5, col)

## One lane of the strip chart: a continuous ink pen trace, the bell an inked spike.
func _draw_lane(c: CanvasItem, lane: int, shift: float, on: bool) -> void:
	var cy: float = LANE_Y[lane]
	var col := INK if on else Color(INK, 0.28)
	var peak := GUIDE_X + (0.0 if lane == 0 else STEP_PX * 2.0) + shift
	var pts := PackedVector2Array()
	var spiked := false
	var i := 0
	var x := WIN_X0 + 4.0 + shift
	while x < WIN_X1:
		if x >= WIN_X0 + 2.0:
			if absf(x - peak) <= 7.0:
				if not spiked:
					pts.append_array(PackedVector2Array([Vector2(peak - 5, cy), Vector2(peak, cy - 58),
						Vector2(peak + 4, cy + 22), Vector2(peak + 8, cy)]))
					spiked = true
			else:
				var amp := 6.0 + 30.0 * wave[(i + lane * 53) % wave.size()] * (0.55 + 0.45 * sin(i * 0.21 + lane))
				pts.append(Vector2(x, cy - amp))
				pts.append(Vector2(x + 3.0, cy + amp * 0.85))
		x += 6.0
		i += 1
	if pts.size() > 1:
		c.draw_polyline(pts, col, 2.0, true)
	if peak > WIN_X0 and peak < WIN_X1:
		_bell(c, Vector2(peak, cy - 80), col)

func _draw_mixer(c: CanvasItem) -> void:
	_full(c, "c_mixer")
	var st: Dictionary = r.state
	var off := int(st.offset)
	_draw_lane(c, 0, 0.0, st.venn_on)
	_draw_lane(c, 1, STEP_PX * off, st.nora_on)
	for lane in 2:
		var top: float = [180.0, 370.0][lane]
		var lab: String = ["1 VENN", "2 NORA"][lane]
		var tag := Rect2(214, top + 4, 96, 30)
		c.draw_rect(tag, PAPER)
		c.draw_rect(tag, INK, false, 2.0)
		_text(c, lab, Vector2(222, top + 27), 20, INK, narrow)
	# detents and the knob
	for k in range(-3, 4):
		var dx := GUIDE_X + DETENT_PX * k
		var s := ("+%d" % k) if k > 0 else str(k)
		_ctext(c, s, dx, 734, 20, PAPER_HI if k != off else Color("f2d79a"), narrow)
	var kx := GUIDE_X + DETENT_PX * off
	var knob := Rect2(kx - 15, 626, 30, 58)
	c.draw_rect(knob, BRASS_HI)
	c.draw_rect(knob, INK, false, 3.0)
	c.draw_line(Vector2(kx, 632), Vector2(kx, 678), INK, 2.0)
	if st.p17_complete:
		_ctext(c, "SET", kx, 620, 14, PAPER_HI, narrow)
	# step buttons
	_arrow_left(c, Vector2(318, 655))
	_arrow(c, Vector2(1132, 655), 36, INK)
	# toggles
	for t in [["VENN", "venn_on", 260.0], ["NORA", "nora_on", 540.0]]:
		var on: bool = st[t[1]]
		var cx: float = t[2] + 120.0
		var tip := Vector2(cx, 812) + (Vector2(0, -28) if on else Vector2(0, 28))
		c.draw_line(Vector2(cx, 812), tip, INK, 7.0)
		c.draw_circle(tip, 7, BRASS_HI)
		c.draw_arc(tip, 7, 0, TAU, 20, INK, 2.0)
		_ctext(c, t[0] + "  " + ("ON" if on else "OFF"), cx, 882, 20, INK, narrow)
	_ctext(c, "PLAY", 1130, 880, 22, INK, narrow)
	if _has_sheet():
		var scrap := Rect2(846, 808, 108, 78)
		c.draw_rect(scrap, PAPER_HI)
		c.draw_rect(scrap, INK, false, 2.0)
		Ink.handwriting(c, "Sync: bell.", 11, Vector2(854, 854), 20, 4, false, Ink.BLUE_INK)
	# result tape
	var res: Array = r.mix_transcript()
	if res.size() > 0:
		var tape := Rect2(232, 512, 986, 40)   # inside the window, under lane 2
		c.draw_rect(tape, PAPER_HI)
		c.draw_rect(tape, INK, false, 2.0)
		if res.size() == 2:
			_text(c, res[0], Vector2(252, 538), 18, INK, mono)
			_text(c, res[1], Vector2(737, 538), 18, INK, mono)
			c.draw_line(Vector2(725, 516), Vector2(725, 548), Color(INK, 0.4), 1.5)
		else:
			_ctext(c, res[0], 725, 538, 18, INK, mono)
	_draw_session_log(c)

func _arrow_left(c: CanvasItem, at: Vector2) -> void:
	c.draw_line(at, at + Vector2(-24, 0), INK, 3.0)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-19, -11), at + Vector2(-36, 0), at + Vector2(-19, 11)]), INK)

func _draw_session_log(c: CanvasItem) -> void:
	var x := LOG_CARD.get_center().x
	_ctext(c, "SESSION LOG", x, 194, 17, INK, narrow)
	_ctext(c, "18.X.27", x, 216, 17, INK, narrow)
	c.draw_line(Vector2(1294, 226), Vector2(1406, 226), Color(INK, 0.5), 1.5)
	_text(c, "TRK 1  VENN", Vector2(1294, 252), 13, INK, mono)
	_text(c, "TRK 2  NORA", Vector2(1294, 272), 13, INK, mono)
	if not r.state.p17_complete:
		return
	var y := 312.0
	var hf := Ink.hand()
	var row := 30
	for note in R04Sim.MARGIN_NOTE:
		for line in _wrap(note, hf, 16, 116):
			Ink.handwriting(c, line, line.length(), Vector2(1292, y), 16, row, false, PENCIL)
			y += 21.0
			row += 1
		y += 10.0

# --- c_channels -----------------------------------------------------------------------------
func _draw_channels(c: CanvasItem) -> void:
	_full(c, "c_channels")
	var st: Dictionary = r.state
	var up := _tex("c_lever_up")
	var down := _tex("c_lever_down")
	# MOTOR
	_ctext(c, "MOTOR", 245, 289, 24, INK, narrow)
	var lev: Texture2D = up if st.motor_on else down
	if lev:
		c.draw_texture(lev, Vector2(245 - 75, 350))
	_ctext(c, "MOTOR " + ("ON" if st.motor_on else "OFF"), 245, 652, 20, PAPER_HI, narrow)
	# channels: cut labels, lamps, keys
	var lamp := _tex("c_lamp_lit")
	for ch in ["A", "B", "C"]:
		var cx: float = CLOSE_X[ch]
		_notches(c, cx + 26, 260, CUTS[ch], 12.0, 14.0)
		_text(c, ch, Vector2(cx - 70, 293), 28, INK)
		_text(c, CUT_WORDS[ch], Vector2(cx - 42, 292), 16, INK, narrow)
		if lamp_lit(ch) and lamp:
			c.draw_texture(lamp, Vector2(cx - 48, 282))
		var open: bool = st.ch_open[ch]
		var t: Texture2D = up if open else down
		if t:
			c.draw_texture(t, Vector2(cx - 75, 350))
		_ctext(c, "OPEN" if open else "CLOSED", cx, 652, 20, PAPER_HI, narrow)
	# WITNESS key
	var pressed := witness_t > 0.0 or bool(st.witness_open)
	var wd := _tex("c_witness_down")
	if pressed and wd:
		c.draw_texture(wd, Vector2(1120, 300))
	_ctext(c, "WITNESS", 1230, 490, 20, INK, narrow)
	# status tape
	var tape: String = r.board_tape
	if tape == "" and st.witness_open:
		tape = "WITNESS LINE OPEN."
	if tape != "":
		_ctext(c, tape, 1230, 631, 15, INK, narrow)
	# procedure
	_text(c, "PROCEDURE", Vector2(186, 694), 16, Color(INK, 0.7), narrow)
	var y := 724.0
	for line in _wrap("Isolate live playback before addressing a witness: motor off, live channels closed.",
			Ink.serif(), 23, 860):
		_text(c, line, Vector2(186, y), 23, INK)
		y += 30.0
	# the questions
	if not _questions_live():
		return
	for h in CHANNEL_CONTROLS:
		var id: String = h[0]
		if not id.begins_with("q_"):
			continue
		var rr: Rect2 = h[1]
		var card := Rect2(rr.position.x + 18, 836, rr.size.x - 36, 88)
		c.draw_rect(card, PAPER_HI)
		c.draw_rect(card, INK, false, 2.5)
		_ctext(c, h[2], card.get_center().x, 874, 22, INK)
		var asked: bool = id in st.asked
		if st.p19_complete:
			_ctext(c, "REPLAY", card.get_center().x, 910, 15, Color(INK, 0.75), narrow)
		elif asked:
			var tx := card.position.x + 16
			c.draw_polyline(PackedVector2Array([Vector2(tx, 900), Vector2(tx + 7, 908), Vector2(tx + 20, 890)]), INK, 3.0)
			_text(c, "ASKED", Vector2(tx + 28, 910), 15, INK, narrow)
