extends RoomView
## R08, the Machine Room: renderer. Presents R08Sim (game/rooms/R08/R08_sim.gd) and never
## mutates it. Everything timed here (belt and flywheel motion, the breath, the hold, the trace
## draw, the P11 reveal, loop fades) is presentation and is never saved.
##
## Layering:
##   `room` (world, under a CanvasModulate tint per weather band): the stage plate, the dust
##          overlay, flywheel, pulleys, belts 1/3, the crank rod, belt 2, the membrane and its
##          reflection, the code-drawn labels; over them two light layers, `light_mul` (multiply)
##          and `light_add` (additive), stretched from the painted 362x272 maps.
##   CanvasLayer 5 `close`: the close-ups c_valves and c_tags (always fully lit).
##
## Painted plates: assets/rooms/R08/*.png (tools/art/rooms/R08.py). Every word, the drawing's
## circuit, the fault window, the toggles' OPEN/SHUT and the tag writing are drawn here, so the
## clues stay exact and legible.
##
## The breath: the r08_breath* loops are 8.000 s and start together, so the playback position
## of r08_breath mod 8 is the phase of every breath and of the machine's cycle. The envelopes
## below are the audio contract's (tools/audio/rooms/R08.py), with the same cosine easing.

const DIR := "res://assets/rooms/R08/%s.png"

const PAPER := Color("ded4ba")
const PAPER_HI := Color("e8e1cf")
const INK := Color("172b36")
const BRUISE := Color("746577")
const BRASS := Color("9c7e46")
const BRASS_HI := Color("c9a869")
const BRASS_LO := Color("745c32")
const LEATHER_DK := Color("4e3828")
const SEAGLASS := Color("a9c8b8")
const SEAGLASS_DK := Color("3f6a5c")   # the loop trace on paper: sea-glass, deep enough to read
const STORM := Color("22384a")
## INDEX's later ink on the drawing: a brown-violet, subtle at a glance, plain once told.
const INDEX_INK := Color("5a4256")
const ENGRAVE := Color("2a1e10")
const EMBER := Color(0.32, 0.3, 0.28)
const DUST_HI := Color("bab8ac")

## [id, rect, label]; first match wins, so small objects come first. Never moved by state.
const HOTSPOTS := [
	["repair_tags", Rect2(556, 286, 128, 136), "Repair tags"],
	["nameplate", Rect2(556, 510, 128, 104), "Nameplate"],
	["belt", Rect2(556, 128, 128, 536), "Drive belt"],
	["bolts", Rect2(100, 596, 380, 90), "Restraining bolts"],
	["diaphragm", Rect2(84, 244, 412, 352), "Diaphragm"],
	["flywheel", Rect2(690, 390, 340, 340), "Flywheel"],
	["drawing", Rect2(1090, 150, 300, 230), "Maintenance drawing"],
	["valve_board", Rect2(1090, 420, 300, 330), "Valve board"],
	["dust", Rect2(560, 790, 520, 110), "Dust"],
]
const EXIT_RECTS := {
	"R05": Rect2(20, 922, 250, 64),
	"R07": Rect2(282, 922, 250, 64),
}
const VALVE_CONTROLS := [
	["tog_supply", Rect2(230, 620, 150, 260), "Toggle No. 07"],
	["tog_gate", Rect2(420, 620, 150, 260), "Toggle No. 12"],
	["tog_return", Rect2(610, 620, 150, 260), "Toggle No. 31"],
	["tog_index", Rect2(800, 620, 150, 260), "Toggle No. 44"],
	["preview", Rect2(1000, 780, 120, 110), "PREVIEW"],
	["pump", Rect2(1140, 600, 120, 330), "PUMP lever"],
	["look_drawing", Rect2(170, 100, 1108, 450), "Maintenance drawing"],
]
const TAG_CONTROLS := [
	["tag_prev", Rect2(160, 400, 160, 200), "Previous tag"],
	["tag_next", Rect2(1128, 400, 160, 200), "Next tag"],
	["tag", Rect2(424, 300, 600, 340), "Turn the tag"],
]

## Base levels for one-shots (dB), and the sudden ones "Soften sudden sounds" turns down.
const SFX_DB := {"toggle_open": -10.0, "toggle_shut": -10.0, "board_locked": -10.0, "preview_key": -11.0,
	"trace_tick": -14.0, "fault_buzz": -10.0, "lever_spring": -9.0, "pawl_lock": -8.0, "pump_engage": -5.0,
	"pump_run_up": -8.0, "gauge_rise": -12.0, "belt_wind_down": -7.0, "belt_drop": -7.0,
	"breath_alone": -4.0, "dust_drag": -8.0, "cycle_stop": -6.0, "cycle_resume": -7.0, "tag_lift": -10.0,
	"tag_flip": -12.0, "tag_settle": -12.0, "bolt_tap": -10.0, "nameplate_tap": -12.0}
const SFX_SOFT := ["pump_engage", "cycle_stop", "fault_buzz", "pawl_lock", "belt_drop"]

const LOOPS := ["r08_room", "r08_cycle", "r08_cycle_two", "r08_breath", "r08_breath_nora",
	"r08_breath_even", "r08_late", "r08_hold", "r08_drip"]
const LOOP_RATE := 0.11
## The belt drop's silence: every loop ducks to DROP_DB over DROP_IN (DROP_IN_SOFT with "Soften
## sudden sounds") and holds DROP_HOLD s from the drop; breath_alone then plays into the silence
## while r08_breath alone fades back over BREATH_BACK. The rest return over ROOM_BACK, once the
## reveal's last line is up (ROOM_BACK_LATEST s after the drop at the latest).
const DROP_DB := -60.0
const DROP_IN := 0.25
const DROP_IN_SOFT := 0.6
const DROP_HOLD := 1.6
const BREATH_BACK := 1.0
const ROOM_BACK := 3.0
const ROOM_BACK_LATEST := 20.0
## {fx hold_breath}: with the reveal's last line the whole room stops for `seconds` (the sim's
## HOLD_BREATH_SECONDS). Every loop ducks to silence over HB_IN (HB_IN_SOFT with "Soften sudden
## sounds"), holds, then comes back over HB_OUT; the membrane and the wheels hold their pose.
const HB_IN := 0.12
const HB_IN_SOFT := 0.5
const HB_OUT := 0.9

## Interior tint per weather band (R04's grade); the released room is a flat grey daylight.
const TINT := [Color(1, 1, 1), Color(0.9714, 0.9771, 0.9857), Color(0.9429, 0.9543, 0.9714),
	Color(0.9143, 0.9314, 0.9571), Color(0.8857, 0.9086, 0.9429), Color(0.8571, 0.8857, 0.9286),
	Color(0.8286, 0.8629, 0.9143), Color(0.80, 0.84, 0.90)]
const TINT_SEVER := Color(0.92, 0.93, 0.95)

# --- the cycle ---------------------------------------------------------------------------------
const PERIOD := 8.0
## (time s, inhale 0..1), cosine-eased between knots: tools/audio/rooms/R08.py.
const BREATH_CYCLE := [[0.0, 0.0], [3.6, 1.0], [4.0, 1.0], [6.4, 0.15], [7.6, 0.0], [8.0, 0.0]]
const BREATH_NORA := [[0.0, 0.0], [0.7, 0.45], [1.1, 0.1], [1.8, 0.45], [2.2, 0.1], [3.8, 0.1],
	[6.6, 1.0], [8.0, 0.0]]
const BREATH_EVEN := [[0.0, 0.0], [4.0, 0.8], [8.0, 0.0]]
const HITCH := Vector2(6.4, 7.6)
const HITCH_MUL := 0.2
## Machine time per 8 s cycle once the hitch is counted (6.4 + 1.2 * 0.2 + 0.4).
const CYCLE_UNITS := 7.04
const STILL_V := 0.7
const HOLD_IN := 0.6
const HOLD_OUT := 0.8

# --- room geometry (tools/art/rooms/R08.py) ----------------------------------------------------
const RING_C := Vector2(290, 450)
const FLY := Vector2(860, 560)
const FLY_R := 187.0          # the belt's pitch radius on the flywheel (FLY_R + 7)
const FLY_SPEED := 0.9        # rad/s
const TOP_PULLEY := Vector2(860, 128)
const PUMP_PULLEY := Vector2(1024, 884)
const PULLEY_R := 51.0
const CRANK := Vector2(528, 663)
const CRANK_R := 18.0
const BELT2_X := Vector2(582, 658)
const BELT2_Y := Vector2(154, 636)
const STITCH_STEP := 260.0
const STITCH_SPEED := 120.0
const TICK_STEP := 60.0
const TICK_SPEED := 90.0
## The membrane sprites' origin.
const MEM_ORIGIN := Vector2(90, 250)
## Band 6+: the horizon in the surface rides the breath HORIZON_LAG s late, HORIZON_SWAY px deep.
const HORIZON_LAG := 0.6
const HORIZON_SWAY := 7.0
const NAMEPLATE := Rect2(554, 514, 132, 90)
const LAMP_AT := Vector2(440, 140)
## The breath, seen: the sheen's travel (px) and where the rim gap starts to open.
const SHEEN_TRAVEL := 28.0
const GAP_FROM := 0.78
## Mini valve board on the room plate.
const MINI_SOCKETS := [1135.0, 1195.0, 1255.0, 1315.0]
const MINI_SOCKET_Y := 560.0
const MINI_LEVER_X := 1360.0
const MINI_PAPER := Rect2(1100, 160, 280, 210)
const DWG_ORIGIN := Vector2(170, 100)
const DWG_SIZE := Vector2(1108, 450)
const MINI_SCALE := 0.25

# --- c_valves ----------------------------------------------------------------------------------
const C_SOCKETS := {"SUPPLY": 305.0, "GATE": 495.0, "RETURN": 685.0, "INDEX": 875.0}
const C_SOCKET_Y := 790.0
const OPEN_Y := 684.0         # word centres: clear of the knob (697-727 up, 853-883 down)
const SHUT_Y := 906.0
const GAUGE := Vector2(1060, 680)
const GAUGE_R := 52.0
const GAUGE_ZERO := -120.0
const GAUGE_ON := 60.0
const LAMP := Vector2(1060, 770)
const PUMP_TOP := Vector2(1140, 600)
const PUMP_TRAVEL := 190.0    # px from the up pose to the down pose (sprite y 72 -> 262)
const FAULT_RECT := Rect2(890, 140, 360, 60)
## c_seal_cut's top-left: its lug sits on INDEX's socket ring (tools/art/rooms/R08.py SEAL_AT).
const SEAL_AT := Vector2(880, 800)
## A pen lift inside a trace route (the gate box's label is never drawn over).
const BREAK := Vector2(-1, -1)
const PAPER_CLIP := Rect2(174, 104, 1100, 442)
const TRACE_TIME := 1.2
const DASH := 14.0
const GAP := 8.0
## The drawing: pump, valves, junction, cap, gate box (absolute close-up px).
const D_PUMP := Vector2(290, 430)
const D_PUMP_R := 36.0
const D_SUPPLY := Vector2(450, 430)
const D_J := Vector2(610, 430)
const D_INDEX := Vector2(610, 300)
const D_CAP_Y := 200.0
const D_CAP_BLOCK := Rect2(580, 176, 60, 24)
const D_CAP_RING := Vector2(610, 188)
const D_GATE := Vector2(800, 430)
const D_GATE_BOX := Rect2(930, 394, 150, 72)
const D_RETURN := Vector2(900, 500)
const ROUTE_LOOP := [Vector2(326, 430), Vector2(1190, 430), Vector2(1190, 500), Vector2(290, 500),
	Vector2(290, 466)]

# --- c_tags ------------------------------------------------------------------------------------
const TAG_RECT := Rect2(424, 300, 600, 340)
const TAG_HOLE := Vector2(724, 334)
const TAG_TEXT := Rect2(474, 370, 500, 240)
const TAG_SWAY := 3.0
const TAG_SETTLE := 1.6
## Venn's left-handed backward slope: the glyphs' upright sheared 12 degrees back (tan 12).
const HAND_SHEAR := 0.2126
## The A.M. line: struck from the same die, crooked and doubled.
const AM_TILT := -0.044
const AM_GHOST := Vector2(2.6, -1.8)

# --- the P11 reveal (s after the commit) -------------------------------------------------------
const RV_CLOSE_OUT := 1.8
const RV_CLOSE_FADE := 0.4
const RV_SLOW := 3.4
const RV_STOP := 6.4
const RV_DROP := 6.6
const RV_DROP_TIME := 0.35
const RV_PLATE := 6.8
const RV_PLATE_IN := 0.8
const RV_INHALE := R08Sim.BREATH_ALONE_AT
const RV_INHALE_TIME := 2.6
## The dust moves with the reveal's inhale, not after it (dust_drag plays at the same beat).
const RV_DUST := R08Sim.DUST_DRAG_AT
const RV_DUST_TIME := 2.3
const RV_END := 12.4
const GAUGE_SWEEP := 1.2

## Notice holds: focus rects.
const HOLD_TIME := 1.5
const NOTICE_FOCUS := {
	"cycle_pause": Rect2(540, 100, 520, 660),
	"breathes_alone": Rect2(64, 224, 640, 460),
	"dust_lines": Rect2(60, 780, 1100, 130),
	"bolts_out": Rect2(64, 224, 452, 452),
	"breath_nora": Rect2(64, 224, 1000, 690),
	"belts_still": Rect2(520, 100, 760, 820),
	"late_reflection": Rect2(98, 258, 384, 384),
	"far_horizon": Rect2(98, 258, 384, 384),
	"end_sever": Rect2(64, 224, 452, 452),
	"end_continue": Rect2(64, 224, 452, 452),
}

var r: R08Sim:
	get:
		return sim as R08Sim

var textures := {}
var narrow: SystemFont
var room: Node2D
var close: Node2D
var shade: CanvasModulate
var light_mul: Node2D
var light_add: Node2D
var light_rim: Node2D
var mixer: LoopMixer
var grains := []               # [y, delay, size, alpha] for the reveal's dust

# presentation state (never saved)
var tint := Color(1, 1, 1)
var fly_a := 0.0               # flywheel angle
var pulley_a := [0.0, 0.0]     # top pulley (belt 3), pump pulley (belt 1)
var tick_off := 0.0            # belt 1/3 tick scroll, px
var stitch_off := 0.0          # belt 2 stitch scroll, px
var crank_a := 0.0
var hold_k := 0.0              # 0 live .. 1 the held breath
var v := STILL_V               # the membrane's inhale, 0..1
var trace_t := -1.0            # seconds into the trace draw
var preview_t := 0.0           # seconds left of the pressed PREVIEW key
var pump_fail_t := 0.0         # seconds left of a refused PUMP stroke
var pump_fail_k := 1.0         # how far the refused stroke travels (0.4 against the pawl)
var reveal_t := -1.0           # seconds into p11_reveal, -1 = none
var tag_shown := -1
var tag_t := 99.0              # seconds since the tag turned
var hold_t := 0.0
var hold_rect := Rect2()
var zoom_k := 0.0
var pucker_t := 0.0
var hand_font: FontVariation
var clock0 := 0.0              # scene time the loops started at
## The belt drop's duck (seconds since belt_drop, -1 = none), and when its two returns began.
var drop_t := -1.0
var breath_back_t := -1.0
var room_back_t := -1.0
var drop_in := DROP_IN
var drop_from := {}            # loop id -> linear level when the duck began
var reveal_click := -1
## The held breath: seconds until it starts (-1 = none armed), seconds into it (-1 = none),
## its length, its duck time, the loop levels and the membrane's pose when it began.
var hb_wait := -1.0
var hb_t := -1.0
var hb_len := 0.0
var hb_in := HB_IN
var hb_from := {}
var hb_v := STILL_V

func _ready() -> void:
	clock0 = time
	narrow = SystemFont.new()
	narrow.font_names = PackedStringArray(["Liberation Sans Narrow", "Nimbus Sans Narrow", "DejaVu Sans Condensed", "sans-serif"])
	narrow.font_weight = 700
	var g := RandomNumberGenerator.new()
	g.seed = 1931_08_11
	for i in 60:
		grains.append([g.randf_range(800, 905), g.randf_range(0.0, 0.9), g.randf_range(2.0, 4.0),
			g.randf_range(0.55, 0.95)])
	_build_nodes()
	_build_audio()
	apply_instantly()
	redraw()

func _tex(id: String) -> Texture2D:
	if not textures.has(id):
		var path := DIR % id
		textures[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return textures[id]

func _build_nodes() -> void:
	room = Node2D.new()
	room.name = "Room"
	add_child(room)
	room.draw.connect(_draw_room)
	shade = CanvasModulate.new()
	add_child(shade)
	light_mul = _light_layer(CanvasItemMaterial.BLEND_MODE_MUL, "mul")
	light_add = _light_layer(CanvasItemMaterial.BLEND_MODE_ADD, "add")
	light_rim = _light_layer(CanvasItemMaterial.BLEND_MODE_ADD, "rim")
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

func _draw_light(n: Node2D, kind: String) -> void:
	if kind == "rim":
		_draw_rim(n)
		return
	var t := _tex("light_" + kind)
	if t:
		n.draw_texture_rect(t, Rect2(Vector2.ZERO, SIZE), false, _lamp_mod() if kind == "add" else Color(1, 1, 1))

## The sconce: full until band 6, then a dull ember, so the membrane's wet rim becomes the key light.
func _lamp_mod() -> Color:
	if r.ending() == "sever":
		return Color(0.25, 0.25, 0.25)
	return EMBER if _band() >= 6 else Color(1, 1, 1)

## From band 5 a cold wet rim light rings the membrane (additive); from band 6 it is the key light.
func _draw_rim(n: Node2D) -> void:
	if r.ending() == "sever" or _band() < 5:
		return
	var t := _tex("diaphragm_rim")
	if t == null:
		return
	var a := 0.6 if _band() == 5 else 1.0
	a *= 0.8 + 0.2 * v
	n.draw_texture(t, MEM_ORIGIN, Color(1, 1, 1, a))

func _build_audio() -> void:
	mixer = LoopMixer.new()
	add_child(mixer)
	if game == null:
		return
	# All at once, so the 8 s loops stay in phase with each other.
	for id in LOOPS:
		mixer.add_loop(id, game.load_audio(id))

# ---------------------------------------------------------------------------
# state reads (presentation only)
# ---------------------------------------------------------------------------
func _view() -> String:
	return r.local_view

func _band() -> int:
	return r.band()

func _held() -> bool:
	return r.held()

func _revealing() -> bool:
	return reveal_t >= 0.0

## belts_running(), overridden while the reveal plays its own beats.
func belts() -> Array:
	if _revealing() and reveal_t < RV_DROP:
		return [true, true, true]
	return r.belts_running()

## The driven cycle (the hitch, the crank, the r08_cycle loop): before P11, unless overridden.
func _driven() -> bool:
	return not r.nameplate_shown() or (_revealing() and reveal_t < RV_SLOW)

func _breath_knots() -> Array:
	match r.breath_mode():
		"nora":
			return BREATH_NORA
		"even":
			return BREATH_EVEN
	return BREATH_CYCLE

## The breath's phase: the r08_breath loop's playback position, so the image breathes with the
## sound. If the audio clock has parted from the scene clock (a --fixed-fps capture renders
## scene time faster than the audio plays; a stalled device), the scene clock leads.
func phase() -> float:
	var scene := fposmod(time - clock0, PERIOD)
	if mixer and mixer.players.has("r08_breath") and mixer.players["r08_breath"].playing:
		var a := fposmod(mixer.players["r08_breath"].get_playback_position(), PERIOD)
		if absf(wrapf(a - scene, -PERIOD / 2.0, PERIOD / 2.0)) < 0.5:
			return a
	return scene

static func envelope(knots: Array, t: float) -> float:
	t = fposmod(t, PERIOD)
	for i in knots.size() - 1:
		var a: Array = knots[i]
		var b: Array = knots[i + 1]
		if t <= b[0]:
			var span: float = b[0] - a[0]
			var k: float = 0.0 if span <= 0.0 else (t - a[0]) / span
			return lerpf(a[1], b[1], 0.5 - 0.5 * cos(PI * k))
	return knots[-1][1]

## Machine time into the cycle at phase t (the hitch runs at x0.2).
static func machine_units(t: float) -> float:
	if t <= HITCH.x:
		return t
	if t <= HITCH.y:
		return HITCH.x + (t - HITCH.x) * HITCH_MUL
	return HITCH.x + (HITCH.y - HITCH.x) * HITCH_MUL + (t - HITCH.y)

func _crank_target(t: float) -> float:
	return TAU * machine_units(t) / CYCLE_UNITS

## The live breath value: the envelope, or the still pose with motion off.
func _live_v() -> float:
	if r.breath_mode() == "still":
		return 0.0
	if not motion:
		return STILL_V
	return envelope(_breath_knots(), phase())

## 0..1 ease from t0 over dur; a cut at t0 with motion off.
func _k(t: float, t0: float, dur: float) -> float:
	if not motion:
		return 1.0 if t >= t0 else 0.0
	return clampf((t - t0) / dur, 0.0, 1.0) if dur > 0.0 else (1.0 if t >= t0 else 0.0)

func _ease_out(k: float) -> float:
	return 1.0 - (1.0 - k) * (1.0 - k)

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------
func tick(dt: float) -> void:
	if _revealing():
		reveal_t += dt
		if reveal_t >= RV_END:
			reveal_t = -1.0
	if trace_t >= 0.0:
		trace_t += dt
	preview_t = maxf(0.0, preview_t - dt)
	pump_fail_t = maxf(0.0, pump_fail_t - dt)
	tag_t += dt
	pucker_t += dt
	_tick_hold_breath(dt)
	if _view() == "c_tags" and int(r.state.tag) != tag_shown:
		tag_shown = int(r.state.tag)
		tag_t = 0.0
	# the hold
	var held := _held()
	if held:
		hold_k = minf(1.0, hold_k + dt / HOLD_IN) if motion else 1.0
	else:
		hold_k = maxf(0.0, hold_k - dt / HOLD_OUT) if motion else 0.0
	_tick_motion(dt, held)
	# notice hold
	if hold_t > 0.0:
		hold_t = maxf(0.0, hold_t - dt)
	var zt := 1.0 if hold_t > 0.0 and motion and not r.is_closeup() else 0.0
	zoom_k = move_toward(zoom_k, zt, dt * 2.5)
	var s := 1.0 + 0.04 * smoothstep(0.0, 1.0, zoom_k)
	var focus := hold_rect.get_center()
	room.scale = Vector2(s, s)
	room.position = focus * (1.0 - s)
	var tt := _tint_target()
	tint = Color(move_toward(tint.r, tt.r, dt * 0.2), move_toward(tint.g, tt.g, dt * 0.2),
		move_toward(tint.b, tt.b, dt * 0.2))
	shade.color = tint
	_tick_audio(dt)
	redraw()

func _tint_target() -> Color:
	return TINT_SEVER if r.ending() == "sever" else TINT[clampi(_band(), 0, 7)]

func _tick_motion(dt: float, held: bool) -> void:
	var ph := phase()
	var run := belts()
	# speed multiplier: frozen while held, easing back after; x0.2 through the hitch
	var mul := 0.0 if held else 1.0 - hold_k
	if not motion:
		mul = 0.0
	var hitch := 1.0
	if _driven():
		var e := 0.15
		var into := smoothstep(HITCH.x - e, HITCH.x + e, ph) * (1.0 - smoothstep(HITCH.y - e, HITCH.y + e, ph))
		hitch = lerpf(1.0, HITCH_MUL, into)
	var m := mul * hitch * hold_breath_gain()
	if run[0]:
		fly_a = fposmod(fly_a + dt * FLY_SPEED * m, TAU)
		pulley_a[1] = fposmod(pulley_a[1] + dt * TICK_SPEED / PULLEY_R * m, TAU)
	if run[2]:
		pulley_a[0] = fposmod(pulley_a[0] + dt * TICK_SPEED / PULLEY_R * m, TAU)
	if run[0] or run[2]:
		tick_off = fposmod(tick_off + dt * TICK_SPEED * m, TICK_STEP)
	# belt 2 and the crank: driven before P11; they ease to a stop through the reveal
	var b2 := 1.0
	if _revealing():
		b2 = 1.0 - _ease_out(_k(reveal_t, RV_SLOW, RV_STOP - RV_SLOW)) if motion else (1.0 if reveal_t < RV_SLOW else 0.0)
	if run[1] and b2 > 0.0:
		stitch_off = fposmod(stitch_off + dt * STITCH_SPEED * m * b2, STITCH_STEP)
		if _revealing():
			crank_a = fposmod(crank_a + dt * TAU / CYCLE_UNITS * m * b2, TAU)
		elif motion and not held:
			# the crank follows the cycle's phase; after a hold it catches up gently
			var target := _crank_target(ph)
			var err := wrapf(target - crank_a, -PI, PI)
			crank_a = fposmod(crank_a + dt * TAU / CYCLE_UNITS * m + err * minf(1.0, dt * 2.0 * (1.0 - hold_k)), TAU)
	# the breath
	var live := _live_v()
	var target_v := lerpf(live, 1.0, smoothstep(0.0, 1.0, hold_k))
	if not motion:
		target_v = 1.0 if held else live
	if _revealing() and motion:
		target_v = _reveal_v(live)
	if hb_t >= 0.0 and motion:
		# the membrane holds where it was; after the silence it eases back into the breath
		target_v = lerpf(hb_v, target_v, smoothstep(0.0, 1.0, (hb_t - hb_len) / HB_OUT))
	v = target_v

## The reveal's breath: live until the belt drops, eases to empty, one full inhale with the rod
## still, then back to the live envelope.
func _reveal_v(live: float) -> float:
	var t := reveal_t
	if t < RV_DROP:
		return live
	if t < RV_INHALE:
		return lerpf(live, 0.0, smoothstep(0.0, 1.0, (t - RV_DROP) / (RV_INHALE - RV_DROP)))
	var top := RV_INHALE + RV_INHALE_TIME
	if t < top:
		return 0.5 - 0.5 * cos(PI * (t - RV_INHALE) / RV_INHALE_TIME)
	return lerpf(1.0, live, smoothstep(0.0, 1.0, (t - top) / (RV_END - top)))

func loop_targets() -> Dictionary:
	var held := _held()
	var pre := not r.nameplate_shown()
	var mode := r.breath_mode()
	var out := {}
	out["r08_room"] = 0.4 if r.ending() == "sever" else 0.55
	out["r08_cycle"] = 0.8 if pre and not held else 0.0
	out["r08_cycle_two"] = 0.6 if r.pump_on() and r.belts_running()[0] else 0.0
	var breath := 0.0
	if pre and not held:
		breath = 0.45
	elif mode == "alone":
		breath = 0.75
	out["r08_breath"] = breath
	out["r08_breath_nora"] = 0.8 if mode == "nora" else 0.0
	out["r08_breath_even"] = 0.6 if mode == "even" else 0.0
	out["r08_late"] = 0.35 if r.reflection_mode() == "late" else 0.0
	out["r08_hold"] = 0.5 if held else 0.0
	out["r08_drip"] = 0.4 if r.ending() == "sever" else 0.0
	return out

func _tick_audio(dt: float) -> void:
	var targets := loop_targets()
	var rates := {}
	for id in LOOPS:
		rates[id] = LOOP_RATE
	if drop_t >= 0.0:
		if not hold_breath_silent():
			_tick_drop(dt)   # the drop's returns wait out the held breath
		if drop_t >= 0.0:
			# the duck draws its own envelope: the mixer follows it exactly
			for id in LOOPS:
				targets[id] = drop_level(id, float(targets.get(id, 0.0)))
				rates[id] = 1000.0
	if hb_t >= 0.0:
		for id in LOOPS:
			targets[id] = hold_breath_level(id, float(targets.get(id, 0.0)))
			rates[id] = 1000.0
	mixer.tick(targets, rates, dt)

## Arms, starts and ends the held breath. It starts when its delay runs out or when the line it
## belongs to comes on screen, whichever is first.
func _tick_hold_breath(dt: float) -> void:
	if hb_wait >= 0.0:
		hb_wait -= dt
		var shown := game != null and game.cur_text == R08Sim.REVEAL_LAST_SAY
		if hb_wait <= 0.0 or shown:
			_start_hold_breath()
	elif hb_t >= 0.0:
		hb_t += dt
		if hb_t >= hb_len + HB_OUT:
			hb_t = -1.0

func _start_hold_breath() -> void:
	hb_wait = -1.0
	hb_t = 0.0
	hb_in = HB_IN_SOFT if soft_audio else HB_IN
	hb_from = mixer.mix.duplicate() if mixer else {}
	hb_v = v

## True from the held breath's start until it begins to let go.
func hold_breath_silent() -> bool:
	return hb_t >= 0.0 and hb_t < hb_len

## 1 outside the held breath; 0 while held; easing in over hb_in and back out over HB_OUT.
func hold_breath_gain() -> float:
	if hb_t < 0.0:
		return 1.0
	if hb_t < hb_len:
		return 1.0 - clampf(hb_t / hb_in, 0.0, 1.0)
	return clampf((hb_t - hb_len) / HB_OUT, 0.0, 1.0)

## A loop's level under the held breath, given its level without it (linear). The duck runs in
## dB from where the loop was to DROP_DB; the return rises toward `target`.
func hold_breath_level(id: String, target: float) -> float:
	if hb_t < 0.0:
		return target
	var floor_lin := db_to_linear(DROP_DB)
	if hb_t < hb_len:
		var from_db := linear_to_db(maxf(float(hb_from.get(id, target)), floor_lin))
		var db := lerpf(from_db, DROP_DB, clampf(hb_t / hb_in, 0.0, 1.0))
		return 0.0 if db <= DROP_DB else db_to_linear(db)
	if target <= 0.0:
		return 0.0
	var to_db := linear_to_db(maxf(target, floor_lin))
	return db_to_linear(lerpf(DROP_DB, to_db, hold_breath_gain()))

## Starts the belt drop's duck from the loops' current levels.
func _start_drop() -> void:
	drop_t = 0.0
	breath_back_t = -1.0
	room_back_t = -1.0
	drop_in = DROP_IN_SOFT if soft_audio else DROP_IN
	drop_from = mixer.mix.duplicate() if mixer else {}

func _tick_drop(dt: float) -> void:
	drop_t += dt
	if breath_back_t < 0.0 and drop_t >= DROP_HOLD + 0.5:
		breath_back_t = 0.0   # breath_alone never came (a missing file): the breath comes back anyway
	elif breath_back_t >= 0.0:
		breath_back_t += dt
	if room_back_t >= 0.0:
		room_back_t += dt
	elif breath_back_t >= 0.0 and (_reveal_lines_done() or drop_t >= ROOM_BACK_LATEST):
		room_back_t = 0.0
	if room_back_t >= ROOM_BACK and breath_back_t >= BREATH_BACK:
		drop_t = -1.0

## The reveal's lines are all up: none of them is still queued.
func _reveal_lines_done() -> bool:
	if game == null:
		return true
	for l in game.lines:
		if int(l.click) == reveal_click:
			return false
	return true

## A loop's level under the duck, given its normal `target` (linear). Down to DROP_DB, held; the
## breath returns first (from breath_alone), the room after the reveal's last line. Fades run in dB.
func drop_level(id: String, target: float) -> float:
	var floor_db := DROP_DB
	var from_db := linear_to_db(maxf(float(drop_from.get(id, target)), db_to_linear(floor_db)))
	var db := lerpf(from_db, floor_db, clampf(drop_t / drop_in, 0.0, 1.0))
	var back := room_back_t
	var span := ROOM_BACK
	if id == "r08_breath":
		back = breath_back_t
		span = BREATH_BACK
	if back >= 0.0:
		var to_db := linear_to_db(maxf(target, db_to_linear(floor_db)))
		db = lerpf(floor_db, to_db, clampf(back / span, 0.0, 1.0))
	return 0.0 if target <= 0.0 and back >= span else db_to_linear(db)

## True while the drop holds the room silent (no loop has begun to return).
func drop_silent() -> bool:
	return drop_t >= drop_in and breath_back_t < 0.0 and room_back_t < 0.0

# ---------------------------------------------------------------------------
# hooks
# ---------------------------------------------------------------------------
func play_fx(id: String, e: Dictionary) -> void:
	if id.begins_with("notice_"):
		_start_hold(id.substr(7))
		return
	match id:
		"p11_reveal":
			reveal_t = 0.0
			trace_t = TRACE_TIME
			reveal_click = int(game.click_id) if game != null else -1
			if game != null:
				_flush_for_reveal.call_deferred(game.click_id)
		"hold_breath":
			hb_len = maxf(0.0, float(e.get("seconds", R08Sim.HOLD_BREATH_SECONDS)))
			hb_t = -1.0
			hb_wait = maxf(0.0, float(e.get("delay", 0.0)))
			if hb_wait <= 0.0:
				_start_hold_breath()
		"hold":
			pucker_t = 0.0
			if not motion:
				hold_k = 1.0
		"release":
			if not motion:
				hold_k = 0.0
		"trace":
			trace_t = 0.0 if motion else TRACE_TIME
			if r.trace_kind == "pump" and r.trace != "loop":
				pump_fail_t = 0.4 if r.trace == "index" else 0.25
				pump_fail_k = 0.4 if r.trace == "index" else 1.0

## The commit can land while the hold's story lines are still queued (a fast hand, a driver):
## the core then times the reveal's lines and sounds after that backlog, and the narration
## trails the image by seconds. The reveal owns the screen: drop every older line, release the
## one on screen, and pull this click's lines and sounds back to the times the sim gave them.
## (Deferred: it runs once the core has queued the click's events.)
func _flush_for_reveal(click: int) -> void:
	if game == null:
		return
	var first := INF
	for l in game.lines:
		if int(l.click) == click:
			first = minf(first, float(l.due))
	if first == INF:
		return
	game.lines = game.lines.filter(func(l): return int(l.click) == click)
	if game.cur_text != "" and int(game.cur_click) != click:
		game.cur_hold = minf(game.cur_hold, maxf(0.0, game.time - game.cur_since))
	var late: float = first - (game.time + R08Sim.REVEAL_FIRST_SAY)
	if late <= 0.001:
		return
	for l in game.lines:
		l.due -= late
	for p in game.pending_sfx:
		if int(p[2]) == click:
			p[1] -= late

func on_sfx(id: String) -> void:
	match id:
		"preview_key":
			preview_t = 0.3
		"belt_drop":
			_start_drop()
		"breath_alone":
			if drop_t >= 0.0:
				breath_back_t = 0.0

func _start_hold(n: String) -> void:
	var rect: Rect2 = NOTICE_FOCUS.get(n, Rect2())
	if rect.size == Vector2.ZERO:
		return
	hold_rect = rect
	hold_t = HOLD_TIME

func hold_active() -> bool:
	return hold_t > 0.0

func apply_instantly() -> void:
	reveal_t = -1.0
	tint = _tint_target()
	shade.color = tint
	hold_k = 1.0 if _held() else 0.0
	v = 1.0 if _held() else _live_v()
	crank_a = _crank_target(phase()) if motion else 0.0
	tag_shown = int(r.state.tag)
	tag_t = 99.0
	drop_t = -1.0
	hb_wait = -1.0
	hb_t = -1.0
	if mixer:
		mixer.snap(loop_targets())
	room.scale = Vector2.ONE
	room.position = Vector2.ZERO
	zoom_k = 0.0

func reset_presentation() -> void:
	reveal_t = -1.0
	trace_t = -1.0
	preview_t = 0.0
	pump_fail_t = 0.0
	hold_k = 1.0 if _held() else 0.0
	hold_t = 0.0
	zoom_k = 0.0
	tag_t = 99.0
	drop_t = -1.0
	hb_wait = -1.0
	hb_t = -1.0

func redraw() -> void:
	room.queue_redraw()
	close.queue_redraw()
	light_mul.queue_redraw()
	light_add.queue_redraw()
	light_rim.queue_redraw()

func back_visible() -> bool:
	return _view() in ["c_valves", "c_tags"]

func esc_action() -> String:
	return "back" if _view() != "room" else "menu"

func exits_active() -> bool:
	if _revealing() and reveal_t < RV_DROP:
		return false
	return _view() == "room"

# ---------------------------------------------------------------------------
# input
# ---------------------------------------------------------------------------
func _controls() -> Array:
	match _view():
		"room":
			if _revealing() and reveal_t < RV_CLOSE_OUT + RV_CLOSE_FADE:
				return []   # the close-up is still on screen
			return HOTSPOTS
		"c_valves":
			return VALVE_CONTROLS
		"c_tags":
			var out := []
			var page := int(r.state.tag)
			for h in TAG_CONTROLS:
				if h[0] == "tag_prev" and page <= 0:
					continue
				if h[0] == "tag_next" and page >= R08Sim.TAG_LAST:
					continue
				out.append(h)
			return out
	return []

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
	if not r.nameplate_shown():
		if id == "nameplate":
			return "Behind the belt"
		if id == "repair_tags":
			return "Tags behind the belt"
	for table in [HOTSPOTS, VALVE_CONTROLS, TAG_CONTROLS]:
		for h in table:
			if h[0] == id:
				return h[2]
	return ""

func dev_rects() -> Array:
	var out := []
	for h in HOTSPOTS if _view() == "room" else _controls():
		out.append(h[1])
	return out

# ---------------------------------------------------------------------------
# text helpers
# ---------------------------------------------------------------------------
func _text(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, font: Font = null) -> void:
	c.draw_string(font if font else narrow, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _tw(s: String, size: int, font: Font = null) -> float:
	return (font if font else narrow).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## Centred on x; `y` is the baseline.
func _ctext(c: CanvasItem, s: String, x: float, y: float, size: int, col: Color, font: Font = null) -> void:
	c.draw_string(font if font else narrow, Vector2(x - _tw(s, size, font) / 2.0, y), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## Centred on the point (x, y) for caps: the baseline sits 0.36 em under the centre.
func _mtext(c: CanvasItem, s: String, x: float, y: float, size: int, col: Color, font: Font = null) -> void:
	_ctext(c, s, x, y + size * 0.36, size, col, font)

func _ring(c: CanvasItem, center: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := Ink.ellipse(center, rx, ry, 64)
	pts.append(pts[0])
	c.draw_polyline(pts, col, w, true)

func _full(c: CanvasItem, id: String, mod := Color(1, 1, 1, 1)) -> void:
	var t := _tex(id)
	if t:
		c.draw_texture_rect(t, Rect2(Vector2.ZERO, SIZE), false, mod)

## A sprite turned `ang` about its own centre, which sits at `at`.
func _spin(c: CanvasItem, id: String, at: Vector2, ang: float) -> void:
	var t := _tex(id)
	if t == null:
		return
	c.draw_set_transform(at, ang, Vector2.ONE)
	c.draw_texture(t, -t.get_size() / 2.0)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

# ---------------------------------------------------------------------------
# drawing: the room (world)
# ---------------------------------------------------------------------------
func _draw_room() -> void:
	var c := room
	var sever := r.ending() == "sever"
	var run := belts()
	var t := reveal_t
	_full(c, r.stage_plate())
	if not sever and _band() >= 6:
		_full_at(c, "lamp_ember", LAMP_AT - Vector2(40, 40))
	# dust: the evidence of each state (the plate's plinth is even dust)
	for layer in dust_layers():
		_full(c, layer[0], Color(1, 1, 1, layer[1]))
	if r.dust_mode() in ["streaks", "lines", "raked"]:
		_full(c, "floor_front")   # the pedestal and pump stand in the dust, not under it
	if _revealing() and t >= RV_DUST:
		_draw_grains(c, t - RV_DUST)
	# flywheel, pulleys, belts 1 and 3
	_spin(c, "flywheel", FLY, fly_a)
	_spin(c, "pulley", TOP_PULLEY, pulley_a[0])
	_spin(c, "pulley", PUMP_PULLEY, pulley_a[1])
	_full(c, "belt1_taut" if run[0] else "belt1_slack")
	_full(c, "belt3_taut" if run[2] else "belt3_slack")
	if run[0]:
		_belt_ticks(c, PUMP_PULLEY)
	if run[2]:
		_belt_ticks(c, TOP_PULLEY)
	# the crank rod and disc
	var pin := CRANK + Vector2(cos(crank_a), sin(crank_a)) * CRANK_R
	c.draw_line(RING_C, pin, INK, 22.0, true)
	c.draw_line(RING_C, pin, BRASS, 18.0, true)
	c.draw_line(RING_C + Vector2(0, -4), pin + Vector2(0, -4), Color(BRASS_HI, 0.8), 4.0, true)
	_spin(c, "crank_disc", CRANK, crank_a)
	c.draw_circle(pin, 7.0, INK)
	c.draw_circle(pin, 4.5, BRASS_HI)
	# belt 2: taut and laced, or dropped
	if run[1]:
		_full(c, "belt2_taut")
		_belt2_stitches(c)
	else:
		var dy := 0.0
		if _revealing() and motion:
			dy = -24.0 * (1.0 - _k(t, RV_DROP, RV_DROP_TIME))
		var bt := _tex("belt2_slack")
		if bt:
			c.draw_texture_rect(bt, Rect2(Vector2(0, dy), SIZE), false)
	# the membrane
	_draw_membrane(c, sever)
	# labels
	_draw_room_labels(c)
	# notice focus
	if hold_t > 0.0 and not r.is_closeup():
		var a := 1.0 if not motion else smoothstep(0.0, 0.3, HOLD_TIME - hold_t)
		_draw_focus(c, hold_rect, a)

## The floor's dust overlays now, [[id, alpha], ...] bottom first. After P11 the dragged fan is
## a still that stays: streaks, then the combed lines, and from band 5 the rake drawn over them.
## Only the reveal itself eases the streaks in, with its one inhalation.
func dust_layers() -> Array:
	match r.dust_mode():
		"streaks":
			if _revealing():
				var k := _k(reveal_t, RV_DUST, RV_DUST_TIME)
				return [["dust_streaks", 0.5 - 0.5 * cos(PI * k)]]
			return [["dust_streaks", 1.0]]
		"lines":
			return [["dust_lines", 1.0]]
		"raked":
			return [["dust_lines", 1.0], ["dust_raked", 1.0]]
	return []

## The engraved nameplate's alpha: 1.0 whenever the belt is off it, except while the reveal
## brings it up.
func nameplate_alpha() -> float:
	if not r.nameplate_shown():
		return 0.0
	if _revealing():
		return _k(reveal_t, RV_PLATE, RV_PLATE_IN)
	return 1.0

## The breath reads in silhouette: two fold plates crossfade (relaxed, bowed ribs at exhale; a
## hard pucker at the boss at inhale), the sheen slides across the skin, and at the top of the
## inhale a thin bright gap opens between membrane and ring on the side away from the light.
func _draw_membrane(c: CanvasItem, sever: bool) -> void:
	if sever:
		_full_at(c, "diaphragm_slack", MEM_ORIGIN)
		return
	_full_at(c, "diaphragm", MEM_ORIGIN)
	_full_at(c, "diaphragm_out", MEM_ORIGIN, 1.0 - smoothstep(0.1, 0.55, v))
	_full_at(c, "diaphragm_in", MEM_ORIGIN, smoothstep(0.25, 0.85, v))
	var hollow := _tex("diaphragm_hollow")
	if hollow:
		var s := 0.35 + 0.65 * v
		c.draw_set_transform(RING_C, 0.0, Vector2(s, s))
		c.draw_texture(hollow, -hollow.get_size() / 2.0, Color(1, 1, 1, 0.2 + 0.45 * v))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
	var sheen := _tex("diaphragm_sheen")
	if sheen:
		c.draw_texture(sheen, MEM_ORIGIN + Vector2(1, 1).normalized() * v * SHEEN_TRAVEL)
	var gap := smoothstep(GAP_FROM, 1.0, v)
	if gap > 0.0:
		_full_at(c, "diaphragm_gap", MEM_ORIGIN, gap)
	match r.reflection_mode():
		"late":
			# not the room: a far horizon and nine pale points, following the breath a moment late
			var dy := 0.0
			if motion:
				dy = HORIZON_SWAY * envelope(_breath_knots(), phase() - HORIZON_LAG)
			_full_at(c, "a_surface_horizon_b6", MEM_ORIGIN + Vector2(0, dy))
		"now":
			_full_at(c, "diaphragm_reflect_now", MEM_ORIGIN, 0.5)

func _full_at(c: CanvasItem, id: String, at: Vector2, alpha := 1.0) -> void:
	var t := _tex(id)
	if t:
		c.draw_texture(t, at, Color(1, 1, 1, alpha))

## Belt 2's laced splices, scrolling down with the belt: two rows of rawhide X-stitches each.
func _belt2_stitches(c: CanvasItem) -> void:
	var lace := Color("b89a6c")
	var x0 := BELT2_X.x + 9.0
	var x1 := BELT2_X.y - 9.0
	var n := 4
	var w := (x1 - x0) / n
	var y := BELT2_Y.x + stitch_off - STITCH_STEP
	while y < BELT2_Y.y:
		for row in 2:
			var y0 := y + row * 14.0
			if y0 < BELT2_Y.x or y0 + 11.0 > BELT2_Y.y:
				continue
			c.draw_line(Vector2(x0, y0 + 5.5), Vector2(x1, y0 + 5.5), Color(INK, 0.45), 1.5)
			for k in n:
				var a := Vector2(x0 + k * w, y0)
				c.draw_line(a + Vector2(0, 1), a + Vector2(w, 12), Color(INK, 0.6), 3.5, true)
				c.draw_line(a + Vector2(0, 12), a + Vector2(w, 1), Color(INK, 0.6), 3.5, true)
				c.draw_line(a, a + Vector2(w, 11), lace, 2.2, true)
				c.draw_line(a + Vector2(0, 11), a + Vector2(w, 0), lace, 2.2, true)
		y += STITCH_STEP

## Ticks along both strands of a taut belt, travelling with it (the flywheel turns clockwise).
func _belt_ticks(c: CanvasItem, pulley: Vector2) -> void:
	for strand in _strands(pulley):
		var a: Vector2 = strand[0]
		var b: Vector2 = strand[1]
		var ph: float = strand[2]
		var dir := (b - a).normalized()
		var vel := Vector2(-sin(ph), cos(ph))   # rim velocity at the flywheel's tangent point
		var sgn := 1.0 if vel.dot(dir) >= 0.0 else -1.0
		var length := a.distance_to(b)
		var nrm := Vector2(-dir.y, dir.x)
		var d := fposmod(tick_off * sgn, TICK_STEP)
		while d < length:
			var p := a + dir * d
			c.draw_line(p - nrm * 6.0, p + nrm * 6.0, Color(LEATHER_DK, 0.95), 2.5)
			d += TICK_STEP

## The two external tangents between the flywheel and `pulley`: [[on fly, on pulley, angle]].
func _strands(pulley: Vector2) -> Array:
	var dvec := pulley - FLY
	var dist := dvec.length()
	var th := dvec.angle()
	var al := acos((FLY_R - PULLEY_R) / dist)
	var out := []
	for s in [1.0, -1.0]:
		var ph: float = th + s * al
		var u := Vector2(cos(ph), sin(ph))
		out.append([FLY + u * FLY_R, pulley + u * PULLEY_R, ph])
	return out

## The reveal's dust: grains dragged right-to-left toward the ring, faster as they go.
func _draw_grains(c: CanvasItem, t: float) -> void:
	if not motion:
		return
	for g in grains:
		var k := clampf((t - g[1]) / (RV_DUST_TIME - 0.9), 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var x := lerpf(1080.0, 520.0, k * k)
		var a: float = g[3] * (1.0 - 0.4 * k)
		var trail := 10.0 + 70.0 * k
		c.draw_line(Vector2(x, g[0]), Vector2(x + trail, g[0]), Color(PAPER_HI, a * 0.45), g[2] * 0.6)
		c.draw_rect(Rect2(x - 1, g[0] - g[2] / 2.0 + 1, g[2] + 1, g[2]), Color(INK, a * 0.35))
		c.draw_rect(Rect2(x - 2, g[0] - g[2] / 2.0, g[2] + 1, g[2]), Color(PAPER_HI, a))

func _draw_room_labels(c: CanvasItem) -> void:
	# the exposed nameplate
	var plate_a := nameplate_alpha()
	if plate_a > 0.0:
		# engraved: a dark cut fill, with the brass catching light on each letter's lower lip
		var cx := NAMEPLATE.get_center().x
		var size := 20
		while size > 16 and _tw("RESPIRATION", size) > NAMEPLATE.size.x - 22.0:
			size -= 1
		for pair in [["REFERENCE", 551.0], ["RESPIRATION", 579.0]]:
			_ctext(c, pair[0], cx, pair[1] + 1.2, size, Color(BRASS_HI.lightened(0.25), plate_a))
			_ctext(c, pair[0], cx, pair[1], size, Color(ENGRAVE, plate_a))
	# the mini valve board
	var tog: Dictionary = r.state.toggles
	for i in 4:
		var x: float = MINI_SOCKETS[i]
		var valve: String = R08Sim.VALVES[i]
		var open: bool = tog[valve]
		var tip := Vector2(x, MINI_SOCKET_Y + (-26.0 if open else 26.0))
		c.draw_line(Vector2(x, MINI_SOCKET_Y), tip, INK, 8.0, true)
		c.draw_line(Vector2(x, MINI_SOCKET_Y), tip, BRASS_HI, 5.0, true)
		c.draw_circle(tip, 4.5, BRASS_HI)
		c.draw_arc(tip, 4.5, 0, TAU, 12, INK, 1.5)
		# the lever's throw is the signifier here; the close-up carries the stamped numbers
		_ctext(c, R08Sim.VALVE_TAGS[valve], x, 616, 13, PAPER_HI)
	# the mini PUMP lever: up idle, down once the gate line holds
	var down := r.pump_on() or r.gauge_powered()
	if _revealing():
		down = true
	c.draw_rect(Rect2(MINI_LEVER_X - 7, 522, 14, 116), Color("12202a"))
	var ly := 618.0 if down else 538.0
	c.draw_rect(Rect2(MINI_LEVER_X - 14, ly - 10, 28, 20), BRASS)
	c.draw_rect(Rect2(MINI_LEVER_X - 14, ly - 10, 28, 20), INK, false, 2.0)
	c.draw_circle(Vector2(MINI_LEVER_X, ly), 5.0, BRASS_HI)
	# the mini drawing: the circuit at a quarter scale, ink only
	var off := Vector2(MINI_PAPER.position.x + (MINI_PAPER.size.x - DWG_SIZE.x * MINI_SCALE) / 2.0,
		MINI_PAPER.position.y + (MINI_PAPER.size.y - DWG_SIZE.y * MINI_SCALE) / 2.0)
	c.draw_set_transform(off - DWG_ORIGIN * MINI_SCALE, 0.0, Vector2(MINI_SCALE, MINI_SCALE))
	_draw_circuit(c, false)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## The notice focus: a light ink frame and a soft surround; the object itself is never darkened.
func _draw_focus(c: CanvasItem, rect: Rect2, a: float) -> void:
	var g := rect.grow(10)
	var dim := Color(0.03, 0.05, 0.07, 0.11 * a)
	c.draw_rect(Rect2(0, 0, SIZE.x, g.position.y), dim)
	c.draw_rect(Rect2(0, g.end.y, SIZE.x, SIZE.y - g.end.y), dim)
	c.draw_rect(Rect2(0, g.position.y, g.position.x, g.size.y), dim)
	c.draw_rect(Rect2(g.end.x, g.position.y, SIZE.x - g.end.x, g.size.y), dim)
	c.draw_rect(g, Color(INK, 0.75 * a), false, 4.0)
	c.draw_rect(g.grow(-4), Color(PAPER_HI, 0.8 * a), false, 1.5)

# ---------------------------------------------------------------------------
# drawing: close-ups (layer 5)
# ---------------------------------------------------------------------------
func _draw_close() -> void:
	close.modulate = Color(1, 1, 1, 1)
	if _revealing() and reveal_t < RV_CLOSE_OUT + RV_CLOSE_FADE:
		close.modulate = Color(1, 1, 1, 1.0 - _k(reveal_t, RV_CLOSE_OUT, RV_CLOSE_FADE))
		_draw_valves(close)
		return
	match _view():
		"c_valves":
			_draw_valves(close)
		"c_tags":
			_draw_tags(close)

# --- c_valves ---------------------------------------------------------------------------------
func _bowtie(c: CanvasItem, at: Vector2, vertical: bool, col: Color, w: float) -> void:
	var hw := 22.0
	var hh := 16.0
	var pts_a: PackedVector2Array
	var pts_b: PackedVector2Array
	if vertical:
		pts_a = PackedVector2Array([at + Vector2(-hh, -hw), at + Vector2(hh, -hw), at])
		pts_b = PackedVector2Array([at + Vector2(-hh, hw), at + Vector2(hh, hw), at])
	else:
		pts_a = PackedVector2Array([at + Vector2(-hw, -hh), at + Vector2(-hw, hh), at])
		pts_b = PackedVector2Array([at + Vector2(hw, -hh), at + Vector2(hw, hh), at])
	for pts in [pts_a, pts_b]:
		c.draw_colored_polygon(pts, PAPER_HI)
		var cl: PackedVector2Array = pts.duplicate()
		cl.append(pts[0])
		c.draw_polyline(cl, col, w, true)

func _chevron(c: CanvasItem, at: Vector2, dir: Vector2, col: Color, size := 9.0) -> void:
	var n := Vector2(-dir.y, dir.x)
	c.draw_colored_polygon(PackedVector2Array([at + dir * size, at - dir * size * 0.7 + n * size * 0.8,
		at - dir * size * 0.7 - n * size * 0.8]), col)

## Points every `step` px along a polyline: [[point, direction], ...].
func _along(pts: Array, step: float, start: float) -> Array:
	var out := []
	var d := start
	var acc := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg := a.distance_to(b)
		while d <= acc + seg:
			out.append([a.lerp(b, (d - acc) / seg), (b - a).normalized()])
			d += step
		acc += seg
	return out

## The maintenance drawing, in close-up px. `words` false for the room's quarter-scale copy.
func _draw_circuit(c: CanvasItem, words: bool) -> void:
	var w := 4.0
	var ink := INK
	# lines first, then the symbols over them
	c.draw_polyline(PackedVector2Array(ROUTE_LOOP), ink, w, true)
	# INDEX was added later, in another ink (lens_index_ink): its branch, valve, cap and words
	var later := INDEX_INK
	c.draw_line(D_J, Vector2(D_J.x, D_CAP_Y), later, w, true)
	if words:
		for a in _along(ROUTE_LOOP, 160.0, 80.0):
			var p: Vector2 = a[0]
			if p.distance_to(D_SUPPLY) < 40 or p.distance_to(D_GATE) < 40 or p.distance_to(D_RETURN) < 40 \
					or D_GATE_BOX.grow(12).has_point(p) or p.distance_to(D_J) < 24:
				continue
			_chevron(c, p, a[1], ink)
	# pump
	c.draw_circle(D_PUMP, D_PUMP_R, PAPER_HI)
	c.draw_arc(D_PUMP, D_PUMP_R, 0, TAU, 48, ink, w, true)
	# valves, junction, cap, gate box
	_bowtie(c, D_SUPPLY, false, ink, w)
	_bowtie(c, D_GATE, false, ink, w)
	_bowtie(c, D_RETURN, false, ink, w)
	_bowtie(c, D_INDEX, true, later, w)
	c.draw_circle(D_J, 7.0, ink)
	c.draw_line(Vector2(D_J.x - 30, D_CAP_Y), Vector2(D_J.x + 30, D_CAP_Y), later, w + 2.0)
	c.draw_rect(D_CAP_BLOCK, Color(BRASS_LO, 0.25))
	c.draw_rect(D_CAP_BLOCK, later, false, w * 0.75)
	for k in 6:
		var x0 := D_CAP_BLOCK.position.x + k * 12.0
		c.draw_line(Vector2(x0, D_CAP_BLOCK.end.y), Vector2(minf(x0 + 24.0, D_CAP_BLOCK.end.x),
			D_CAP_BLOCK.end.y - minf(24.0, D_CAP_BLOCK.end.x - x0)), later, 2.0)
	c.draw_rect(D_GATE_BOX, PAPER_HI)
	c.draw_rect(D_GATE_BOX, ink, false, w)
	if not words:
		return
	_text(c, "GATE PRESSURE CIRCUIT  -  MAINT. DWG. 4", Vector2(200, 140), 20, ink)
	_mtext(c, "PUMP", D_PUMP.x, D_PUMP.y, 16, ink)
	_mtext(c, "SUPPLY", D_SUPPLY.x, 392, 18, ink)
	_mtext(c, "GATE", D_GATE.x, 392, 18, ink)
	_mtext(c, "RETURN", D_RETURN.x, 534, 18, ink)
	_text(c, "INDEX", Vector2(642, D_INDEX.y + 7), 18, later)
	_text(c, "SEALED. NEVER FEED.", Vector2(660, 196), 20, later)
	_mtext(c, "STAIR GATE", D_GATE_BOX.get_center().x, D_GATE_BOX.get_center().y, 18, ink)

## The route a circuit code traces, the X stop mark (or none) and whether the cap is ringed.
func _trace_route(code: String) -> Array:
	match code:
		"no_supply":
			return [[Vector2(326, 430), D_SUPPLY], D_SUPPLY]
		"index":
			return [[Vector2(326, 430), D_J, Vector2(D_J.x, D_CAP_Y)], null]
		"gate_shut":
			return [[Vector2(326, 430), D_GATE], D_GATE]
		"dead_gate":
			return [[Vector2(326, 430), Vector2(D_GATE_BOX.position.x, 430), BREAK,
				Vector2(D_GATE_BOX.end.x, 430), Vector2(1190, 430), Vector2(1190, 500), D_RETURN], D_RETURN]
		"loop":
			return [[Vector2(326, 430), Vector2(D_GATE_BOX.position.x, 430), BREAK,
				Vector2(D_GATE_BOX.end.x, 430)] + ROUTE_LOOP.slice(1), null]
	return [[], null]

func _shown_trace() -> String:
	if _revealing():
		return "loop"
	return r.trace

## The dashed (or, for the loop, solid) trace drawn along `pts` up to length `upto`.
func _draw_trace(c: CanvasItem, code: String, k: float) -> void:
	var route := _trace_route(code)
	var pts: Array = route[0]
	if pts.is_empty():
		return
	var total := 0.0
	for i in pts.size() - 1:
		if pts[i] != BREAK and pts[i + 1] != BREAK:
			total += (pts[i] as Vector2).distance_to(pts[i + 1])
	var upto := total * k
	var solid := code == "loop"
	var col := SEAGLASS_DK if solid else BRUISE
	var acc := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if a == BREAK or b == BREAK:
			continue
		var seg := a.distance_to(b)
		var dir := (b - a).normalized()
		if solid:
			var e := clampf(upto - acc, 0.0, seg)
			if e > 0.0:
				c.draw_line(a, a + dir * e, Color(INK, 0.9), 10.0, true)
				c.draw_line(a, a + dir * e, col, 6.0, true)
		else:
			var d := 0.0
			while d < seg and acc + d < upto:
				var e2 := minf(minf(d + DASH, seg), upto - acc)
				c.draw_line(a + dir * d, a + dir * e2, col, 6.0, true)
				d += DASH + GAP
		acc += seg
	if k < 1.0:
		return
	if solid:
		for a in _along(ROUTE_LOOP, 160.0, 80.0):
			if not D_GATE_BOX.grow(12).has_point(a[0]):
				_chevron(c, a[0], a[1], PAPER_HI, 7.0)
	var stop = route[1]
	if stop is Vector2:
		var s := 16.0
		for dd in [Vector2(s, s), Vector2(s, -s)]:
			c.draw_line(stop - dd, stop + dd, PAPER_HI, 11.0, true)
			c.draw_line(stop - dd, stop + dd, BRUISE, 6.0, true)
	if code == "index":
		var n := 28
		for i in n:
			if i % 2 == 0:
				c.draw_arc(D_CAP_RING, 40.0, TAU * i / n, TAU * (i + 1) / n, 4, BRUISE, 4.0, true)

func _draw_fault(c: CanvasItem, code: String) -> void:
	if code == "":
		return
	var text: String = "LOOP COMPLETE" if code == "loop" else "FAULT: " + R08Sim.FAULT_NAMES[code]
	var size := 24
	var room_w := FAULT_RECT.size.x - (60.0 if code == "loop" else 24.0)
	while _tw(text, size) > room_w and size > 16:
		size -= 1
	var cy := FAULT_RECT.get_center().y + size * 0.36
	if code == "loop":
		var tw := _tw(text, size)
		var x0 := FAULT_RECT.get_center().x - (tw + 34.0) / 2.0
		c.draw_circle(Vector2(x0 + 11, FAULT_RECT.get_center().y), 11.0, SEAGLASS_DK)
		c.draw_arc(Vector2(x0 + 11, FAULT_RECT.get_center().y), 11.0, 0, TAU, 24, INK, 2.0)
		_text(c, text, Vector2(x0 + 34, cy), size, INK)
	else:
		_ctext(c, text, FAULT_RECT.get_center().x, cy, size, INK)

## The pucker round the capped INDEX line while the machine holds.
func _draw_pucker(c: CanvasItem) -> void:
	var shrink := 0.0
	if motion:
		shrink = fposmod(pucker_t, 4.0) / 4.0
	for i in 5:
		var ry := lerpf(30.0, 150.0, i / 4.0)
		if motion:
			ry = lerpf(30.0, 150.0, fposmod(i / 5.0 + 1.0 - shrink, 1.0))
		var a := 0.22
		_clipped_ring(c, D_CAP_RING + Vector2(3, 4), ry * 1.3, ry, Color(0.08, 0.06, 0.1, a * 0.45), 3.0)
		_clipped_ring(c, D_CAP_RING, ry * 1.3, ry, Color(INK, a), 2.5)
	c.draw_line(D_J, Vector2(D_J.x, D_CAP_Y), BRUISE, 9.0, true)

## An ellipse drawn only where it lies on the drawing's paper.
func _clipped_ring(c: CanvasItem, center: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := Ink.ellipse(center, rx, ry, 96)
	pts.append(pts[0])
	var run := PackedVector2Array()
	for p in pts:
		if PAPER_CLIP.has_point(p):
			run.append(p)
		else:
			if run.size() > 1:
				c.draw_polyline(run, col, w, true)
			run = PackedVector2Array()
	if run.size() > 1:
		c.draw_polyline(run, col, w, true)

func _draw_valves(c: CanvasItem) -> void:
	_full(c, "c_valves")
	var held := _held()
	var code := _shown_trace()
	var trace_k := 1.0
	if trace_t >= 0.0 and motion:
		trace_k = clampf(trace_t / TRACE_TIME, 0.0, 1.0)
	# the drawing
	_draw_circuit(c, true)
	if held:
		_draw_pucker(c)
	if code != "":
		_draw_trace(c, code, trace_k)
	_draw_fault(c, code if trace_k >= 1.0 else "")
	# toggles
	var tog: Dictionary = r.state.toggles
	for valve in R08Sim.VALVES:
		var cx: float = C_SOCKETS[valve]
		var open: bool = tog[valve]
		_toggle_number(c, "No. " + R08Sim.VALVE_TAGS[valve], cx, 647)
		var t := _tex("c_toggle_open" if open else "c_toggle_shut")
		if t:
			c.draw_texture(t, Vector2(cx, C_SOCKET_Y) - t.get_size() / 2.0)
		_pill(c, "OPEN", cx, OPEN_Y, open)
		_pill(c, "SHUT", cx, SHUT_Y, not open)
	# INDEX's cut lead seal, dangling off its socket lug (over the lever, never under it)
	var seal := _tex("c_seal_cut")
	if seal:
		c.draw_texture(seal, SEAL_AT)
	# gauge
	var sweep := 1.0
	if _revealing() and motion:
		sweep = smoothstep(0.0, 1.0, reveal_t / GAUGE_SWEEP)
	var on := r.gauge_powered()
	var ang := deg_to_rad(lerpf(GAUGE_ZERO, GAUGE_ON, sweep if on else 0.0))
	c.draw_line(GAUGE + Vector2.from_angle(deg_to_rad(GAUGE_ZERO)) * 44.0,
		GAUGE + Vector2.from_angle(deg_to_rad(GAUGE_ZERO)) * 52.0, INK, 2.5)
	c.draw_line(GAUGE + Vector2.from_angle(deg_to_rad(GAUGE_ON)) * 44.0,
		GAUGE + Vector2.from_angle(deg_to_rad(GAUGE_ON)) * 52.0, INK, 2.5)
	# "0" sits beside its mark (the resting needle lies along it); POWERED under the hub, left of
	# the needle's powered line
	var p0l := GAUGE + Vector2.from_angle(deg_to_rad(GAUGE_ZERO - 32.0)) * 34.0
	_mtext(c, "0", p0l.x, p0l.y, 14, INK)
	_mtext(c, "POWERED", GAUGE.x - 12, GAUGE.y + 30, 13, INK)
	var tip := GAUGE + Vector2.from_angle(ang) * 44.0
	c.draw_line(GAUGE, tip, BRUISE if not on else INK, 3.0, true)
	c.draw_circle(GAUGE, 6.0, INK)
	_ctext(c, "GATE LINE", GAUGE.x, 749, 14, PAPER_HI)
	# PREVIEW key and lamp
	var key := _tex("c_preview_down" if preview_t > 0.0 else "c_preview_up")
	if key:
		c.draw_texture(key, Vector2(1000, 780))
	if code != "" and trace_k > 0.0:
		var lamp := _tex("c_preview_lamp")
		if lamp:
			c.draw_texture(lamp, LAMP - lamp.get_size() / 2.0)
	_ctext(c, "PREVIEW", 1060, 922, 18, PAPER_HI)
	# PUMP lever
	var lever_k := 1.0 if r.pump_on() or r.gauge_powered() else 0.0
	if lever_k < 1.0 and pump_fail_t > 0.0:
		lever_k = pump_fail_k
	var pump := _tex("c_pump_up")
	if pump:
		c.draw_texture(pump, PUMP_TOP + Vector2(0, PUMP_TRAVEL * lever_k))
	_mtext(c, "PUMP", 1200, 623, 20, INK)

## A toggle's tag number, struck into its plate: a dark cut with the light on each lower lip.
func _toggle_number(c: CanvasItem, s: String, cx: float, cy: float) -> void:
	var size := 24
	_mtext(c, s, cx, cy + 1.4, size, Color(PAPER_HI, 0.9))
	_mtext(c, s, cx, cy, size, ENGRAVE)

## OPEN / SHUT: the active word in paper on an ink pill; the other at 35%.
func _pill(c: CanvasItem, word: String, cx: float, cy: float, active: bool) -> void:
	var size := 17
	if active:
		var w := _tw(word, size) + 22.0
		var rect := Rect2(cx - w / 2.0, cy - 12.0, w, 24.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = INK
		sb.border_color = PAPER_HI
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(12)
		c.draw_style_box(sb, rect)
		_mtext(c, word, cx, cy, size, PAPER_HI)
	else:
		var w2 := _tw(word, size) + 22.0
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = STORM
		sb2.border_color = Color(PAPER_HI, 0.2)
		sb2.set_border_width_all(1)
		sb2.set_corner_radius_all(12)
		c.draw_style_box(sb2, Rect2(cx - w2 / 2.0, cy - 12.0, w2, 24.0))
		_mtext(c, word, cx, cy, size, Color(PAPER_HI, 0.35))

# --- c_tags -----------------------------------------------------------------------------------
func _draw_tags(c: CanvasItem) -> void:
	_full(c, "c_tags")
	var page := int(r.state.tag)
	var last := page == R08Sim.TAG_LAST
	c.draw_set_transform_matrix(_tag_xf())
	var t := _tex("c_tag_new" if last else "c_tag")
	var o := TAG_RECT.position - TAG_HOLE
	if t:
		c.draw_texture(t, o)
	if last:
		var lines := r.tag_stamp()
		_stamp(c, lines[0], TAG_RECT.get_center().x - TAG_HOLE.x, 470 - TAG_HOLE.y)
		if lines.size() > 1:
			_stamp(c, lines[1], TAG_RECT.get_center().x - TAG_HOLE.x, 530 - TAG_HOLE.y, true)
	else:
		var text: String = R08Sim.TAGS[page]
		var at := o + (TAG_TEXT.position - TAG_RECT.position)
		var num := R08Sim.tag_number(page)
		if num != "":
			# a valve tag: the toggle's number struck in, his note under it
			_stamp(c, "No. " + num, TAG_RECT.get_center().x - TAG_HOLE.x, 414 - TAG_HOLE.y)
			text = text.substr(text.find(": ") + 2)
			at.y += 56.0
		_tag_hand(c, text, at)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	# counter and the arrows
	_ctext(c, "%d / %d" % [page + 1, R08Sim.TAGS.size()], 724, 707, 20, PAPER_HI, Ink.serif())
	for h in _controls():
		if h[0] == "tag_prev" or h[0] == "tag_next":
			_arrow_button(c, h[1], h[0] == "tag_prev")

## Venn's left-handed slope: upright letters leaning back. The date line first, then the note.
## Venn's hand: the serif, sheared back through the font itself (a canvas skew doesn't reach
## the glyphs).
func _hand_font() -> Font:
	if hand_font == null:
		hand_font = FontVariation.new()
		hand_font.base_font = Ink.serif()
		hand_font.variation_transform = Transform2D(Vector2(1, 0), Vector2(HAND_SHEAR, 1), Vector2.ZERO)
	return hand_font

func _tag_hand(c: CanvasItem, s: String, at: Vector2) -> void:
	var size := 26
	var font := _hand_font()
	var cut := s.find(". ")
	var lines := []
	if cut > 0:
		lines.append(s.substr(0, cut + 1))
		s = s.substr(cut + 2)
	var line := ""
	for word in s.split(" "):
		var trial: String = word if line == "" else line + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > TAG_TEXT.size.x - 20 and line != "":
			lines.append(line)
			line = word
		else:
			line = trial
	if line != "":
		lines.append(line)
	var y := at.y + size
	var row := 0
	for l in lines:
		_hand_line(c, l, Vector2(at.x + 6, y), size, row, font)
		y += size * 1.5
		row += 1

func _hand_line(c: CanvasItem, s: String, pos: Vector2, size: int, row: int, font: Font) -> void:
	var g := RandomNumberGenerator.new()
	var x := pos.x
	var sway_xf := _tag_xf()
	for i in s.length():
		g.seed = 8_11 + row * 97 + i
		var dy := g.randf_range(-1.6, 1.6)
		var rot := g.randf_range(-0.05, 0.05)
		c.draw_set_transform_matrix(sway_xf * Transform2D(rot, Vector2(x, pos.y + dy)))
		c.draw_char(font, Vector2.ZERO, s[i], size, INK)
		x += font.get_char_size(s.unicode_at(i), size).x
	c.draw_set_transform_matrix(sway_xf)

## The tag's sway transform (about its hole), as _draw_tags sets it.
func _tag_xf() -> Transform2D:
	var sway := 0.0
	if motion and tag_t < TAG_SETTLE:
		sway = deg_to_rad(TAG_SWAY) * exp(-3.0 * tag_t) * sin(tag_t * 9.0) * (1.0 - tag_t / TAG_SETTLE)
	return Transform2D(sway, TAG_HOLE)

## Stamped letters, debossed into the new brass: a dark cut fill with the light catching each
## letter's lower lip. `crooked`: the same die struck again, 2.5 degrees off and doubled.
func _stamp(c: CanvasItem, s: String, cx: float, y: float, crooked := false) -> void:
	var size := 34
	var spacing := 6.0
	var w := 0.0
	for i in s.length():
		w += narrow.get_char_size(s.unicode_at(i), size).x + spacing
	w -= spacing
	var base := _tag_xf()
	var xf := base * Transform2D(AM_TILT if crooked else 0.0, Vector2(cx, y))
	c.draw_set_transform_matrix(xf)
	var cut := Color(0.24, 0.17, 0.07, 0.95)
	var lip := Color(1.0, 0.95, 0.8, 0.85)
	var strikes := [Vector2.ZERO]
	if crooked:
		strikes = [AM_GHOST, Vector2.ZERO]
	for k in strikes.size():
		var off: Vector2 = strikes[k]
		var x := -w / 2.0
		for i in s.length():
			var ch := s[i]
			if k == strikes.size() - 1:
				c.draw_char(narrow, Vector2(x, 1.6) + off, ch, size, lip)
				c.draw_char(narrow, Vector2(x, 0) + off, ch, size, cut)
			else:
				c.draw_char(narrow, Vector2(x, 0) + off, ch, size, Color(cut, 0.55))
			x += narrow.get_char_size(s.unicode_at(i), size).x + spacing
	c.draw_set_transform_matrix(base)

func _arrow_button(c: CanvasItem, rect: Rect2, left: bool) -> void:
	var inner := Rect2(rect.position.x + 24, 517, rect.size.x - 48, 60)
	Ink.button(c, inner, "", false)
	c.draw_rect(inner.grow(3), BRASS_HI, false, 2.0)
	var ctr := inner.get_center()
	var d := -1.0 if left else 1.0
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(d * 16, 0), ctr + Vector2(-d * 11, -16),
		ctr + Vector2(-d * 11, 16)]), PAPER_HI)
