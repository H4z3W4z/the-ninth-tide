extends RoomView
## R07, the Wet Laboratory: renderer. Presents R07Sim (game/rooms/R07/R07_sim.gd) and never
## mutates it. Everything timed here (the tip, the lean, the beam, the drip, ripples, fog
## blooms, holds, loop fades) is presentation and is never saved.
##
## Layering:
##   `room` (world layer 0, under a CanvasModulate that only ever lifts toward white): view A
##          (the tank wall) or view B (the bench), their painted overlays, every water surface
##          and every label.
##   CanvasLayer 5 `close`: the close-ups c_tilt_rack (P10), c_balance (P13), c_frame (P14).
##
## Water is drawn, never painted: each vessel's interior rectangle, rotated with its vessel, is
## clipped against the half-plane below a surface line through its centre, so every vessel is
## exactly half full and only the angle of the surface changes. That angle is the room's clue
## (A follows gravity, B its jar, C the brass datum) and, later, its wrongness (the water turns
## to the vault door, then to her).
##
## Painted plates: assets/rooms/R07/*.png (tools/art/rooms/R07.py). They carry no text: every
## label, numeral, trace and reading is drawn here, so the clues stay exact and legible.

const DIR := "res://assets/rooms/R07/%s.png"
## Stage overlays (tools/art/rooms/R07.py "stage overlays"): dread while the puzzles are played.
const STAGE_DIR := "res://assets/stages/R07/%s.png"
const STAGE_IDS := ["b2_tidemark", "b2_tidemark_bench", "b4_lamp_pool", "b4_water_lean", "datum_water_r3"]
## Band >= 3, view A (R07Sim.datum_flooded()): the sea stands flat at the DATUM. Below the
## surface (y >= DATUM_SURFACE_Y) the room is laid again DATUM_SHIFT px to the right and washed
## sea-glass by datum_water_r3; where that PNG leaves the wash out (doors, tank, basin, socket,
## rack, plates) the room's own pixels are put back, registered, and every hotspot drawn by the
## view lies on top.
const DATUM_SURFACE_Y := 304
const DATUM_SHIFT := 6
## View B plates whose cabinet tide mark is painted as clear water (tools/art/rooms/R07.py).
const B_WATER_PLATES := {3: "view_b_s3_v2", 4: "view_b_s4_v2"}
## b2_tidemark's caustic bands (y 60-260) drift sideways this far, slowly; Motion off: still.
const CAUSTIC_ROWS := 300.0
const CAUSTIC_DRIFT := 5.0

const PAPER := Color("ded4ba")
const PAPER_HI := Color("e8e1cf")
const INK := Color("172b36")
const BRUISE := Color("746577")
const SEAGLASS_HI := Color("96b2a6")
const WATER := Color(0.302, 0.431, 0.392, 0.96)          # #4d6e64: a filled matte mass
const STORM := Color("22384a")
## Below the surface the water is 15% darker than its fill colour.
const WATER_BODY := 0.85

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["jar_a", Rect2(860, 572, 112, 196), "Jar A"],
	["jar_b", Rect2(972, 572, 112, 196), "Jar B"],
	["jar_c", Rect2(1084, 572, 112, 196), "Jar C"],
	["reference_socket", Rect2(716, 318, 130, 362), "Reference socket"],
	["datum_line", Rect2(866, 252, 190, 296), "Brass datum"],
	["basin", Rect2(198, 520, 152, 260), "Washbasin"],
	["tilt_rack", Rect2(848, 552, 352, 244), "Tilt rack"],
	["tank", Rect2(366, 400, 340, 428), "Flotation tank"],
	["vault_door", Rect2(1208, 318, 155, 534), "Vault door"],
	["return_door", Rect2(26, 330, 152, 522), "Stair door"],
	["to_bench", Rect2(600, 850, 248, 64), "The bench"],
]
## View B, the specimen bench (a base view, not a close-up).
const BENCH_HOTSPOTS := [
	["control_tray", Rect2(540, 470, 140, 110), "Control tray"],
	["balance", Rect2(300, 300, 380, 300), "Balance"],
	["sample_cards", Rect2(60, 160, 220, 200), "Sample cards"],
	["register", Rect2(80, 640, 300, 150), "Specimen register"],
	["frame_stand", Rect2(720, 330, 250, 270), "Specimen frame"],
	["sealed_jar", Rect2(974, 396, 204, 204), "Sealed jar"],
	["sample_rack", Rect2(1190, 360, 220, 240), "Sample rack"],
	["to_tank", Rect2(600, 850, 248, 64), "The tank wall"],
]
const EXIT_RECTS := {
	"R05": Rect2(20, 922, 250, 64),
	"R10": Rect2(282, 922, 250, 64),
	"R11": Rect2(544, 922, 250, 64),
	"R08": Rect2(806, 922, 250, 64),
}

## Close-up controls: [id, rect, hover label].
const RACK_CONTROLS := [
	["rest_a", Rect2(100, 520, 180, 340), "Station A"],
	["rest_b", Rect2(300, 520, 180, 340), "Station B"],
	["rest_c", Rect2(500, 520, 180, 340), "Station C"],
	["cradle", Rect2(710, 420, 300, 320), "Cradle"],
	["tip", Rect2(720, 770, 130, 120), "TIP"],
	["seat", Rect2(860, 770, 170, 120), "SEAT IN SOCKET"],
	["test_card", Rect2(560, 100, 520, 300), "Test card"],
	["ref_card", Rect2(1110, 120, 240, 220), "Reference card"],
	["socket", Rect2(1110, 380, 240, 400), "Reference socket"],
]
const BALANCE_CONTROLS := [
	["smp_w", Rect2(120, 680, 110, 130), "Specimen 27-03"],
	["smp_n", Rect2(250, 680, 110, 130), "Specimen 27-11"],
	["smp_f", Rect2(380, 680, 110, 130), "Specimen 27-19"],
	["pan", Rect2(304, 470, 200, 140), "Sample pan"],
	["tray", Rect2(944, 470, 200, 140), "Control tray"],
	["holder", Rect2(644, 400, 160, 90), "Name holder"],
	["gauge", Rect2(670, 560, 110, 90), "Stair pressure gauge"],
	["cards", Rect2(90, 110, 276, 160), "Sample cards"],
	["key_address", Rect2(560, 680, 140, 100), "ADDRESS"],
	["key_release", Rect2(720, 680, 140, 100), "RELEASE"],
	["key_record", Rect2(880, 680, 140, 100), "RECORD"],
	["strip", Rect2(1080, 640, 320, 180), "Strip printer"],
	["reg_bell", Rect2(120, 836, 140, 84), "Register: BELL"],
	["reg_doane", Rect2(270, 836, 140, 84), "Register: DOANE"],
	["reg_hart", Rect2(420, 836, 140, 84), "Register: HART"],
	["reg_ives", Rect2(570, 836, 140, 84), "Register: IVES"],
	["reg_lusk", Rect2(720, 836, 140, 84), "Register: LUSK"],
	["reg_pryce", Rect2(870, 836, 140, 84), "Register: PRYCE"],
	["reg_rook", Rect2(1020, 836, 140, 84), "Register: ROOK"],
	["reg_tull", Rect2(1170, 836, 140, 84), "Register: TULL"],
]
## c_frame's fixed controls; the tray's loose sections are added per tray_sections().
const FRAME_FIXED := [
	["ref_card", Rect2(140, 100, 1170, 220), "Reference"],
	["slot_0", Rect2(170, 370, 360, 200), "Slot 1"],
	["slot_1", Rect2(545, 370, 360, 200), "Slot 2"],
	["slot_2", Rect2(920, 370, 360, 200), "Slot 3"],
	["name_tab", Rect2(180, 594, 340, 70), "Name tab"],
	["strip_clip", Rect2(560, 594, 340, 70), "Strip clip"],
	["seal", Rect2(1290, 740, 140, 140), "SEAL FRAME"],
]
const TRAY_RECTS := [Rect2(170, 720, 360, 170), Rect2(545, 720, 360, 170), Rect2(920, 720, 360, 170)]

## One-shot levels (dB) and the sudden ones "Soften sudden sounds" turns down.
const SFX_DB := {
	"jar_slide": -4.0, "cradle_clamp": -5.0, "rack_tip": -3.0, "slosh_a": -3.0, "glass_creak_b": -4.0,
	"slosh_c": -3.0, "test_pen": -8.0,
	"socket_refuse": -3.0, "socket_click": -1.0, "tag_drop": -4.0, "water_lean": 0.0, "door_rattle": -3.0,
	"vault_settle": -6.0, "glass_tap": -4.0, "tap_turn": -6.0,
	"pan_place": -4.0, "beam_swing": -5.0, "key_press": -4.0, "key_refuse": -4.0, "strip_print": -6.0,
	"card_flick": -5.0, "felt_press": 0.0,
	"section_slide": -5.0, "name_write": -6.0, "strip_clip": -4.0, "frame_seal": -1.0, "breath_hiss": 0.0,
}
const SFX_SOFT := ["socket_refuse", "key_refuse", "door_rattle", "breath_hiss"]
## The breath must still be heard: it is only taken down 8 dB.
const SFX_SOFT_CUT := {"breath_hiss": 8.0}

const LOOPS := ["r07_room", "r07_tank_hum", "r07_drip", "r07_trickle", "r07_glass_sing", "r07_undertow"]
## The quiet reveals the room's loops duck under (6 dB).
const DUCK_IDS := ["water_lean", "felt_press", "breath_hiss"]
const LOOP_RATE := 0.11        # linear units / s: about a 1.5 s fade at these levels

## Ambient per weather band: held at full. The bands are painted into the plates (wall tone,
## grout, tide mark, runs, blooms); the owner rule is that late stages stay bright enough for
## every painted change and every hotspot to read at 1024x768.
const TINT := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

# --- view A geometry ----------------------------------------------------------------------
const JAR_POS := {"A": Vector2(916, 668), "B": Vector2(1028, 668), "C": Vector2(1140, 668)}
const SOCKET_POS := Vector2(781, 492)
## Jar C sits in the socket larger than on the rack, so its surface (and the lean) reads.
const SOCKET_SCALE := 1.25
const JAR_SPRITE_C := Vector2(44, 84)        # jar_back/front: interior centre in the 88x150 sprite
const JAR_HALF := Vector2(34, 56)            # interior (10,28)-(78,140)
const JAR_LABEL := Vector2(0, 38)            # the label plate's centre from the interior centre
const TANK_IN := Rect2(386, 430, 300, 350)
const TANK_C := Vector2(536, 605)
const VAULT_C := Vector2(1290, 620)
## Band 5-6: every surface leans this hard toward the vault (the down component of its normal).
const VAULT_PULL_DOWN := 0.55
## c_tilt_rack: the vault lies off the close-up's right edge.
const VAULT_C_CLOSE := Vector2(2300, 640)
const ADA_DEFAULT := Vector2(724, 1040)
const ADA_TURN := 0.3
const REFL := Rect2(394, 438, 284, 150)
## The reflection is laid on the glass faint and a little warm: another time.
const REFL_TINT := Color(1.0, 0.93, 0.82, 0.42)
const PLUMB_PIVOT := Vector2(1004, 300)
const PLUMB_SPRITE_PIV := Vector2(20, 4)
const DATUM_TAG := Rect2(878, 270, 96, 26)
const STAIR_TAG := Rect2(58, 360, 88, 30)
const RECORDS_TAG := Rect2(1236, 338, 100, 28)
const SOCKET_CARD := Rect2(722, 326, 118, 54)
const SOCKET_TAG := Rect2(722, 614, 118, 58)
const RACK_PLATE_Y := 772.0
## The basin tap: a drop falls along the gravity slant, every DRIP_PERIOD seconds.
const DRIP_FROM := Vector2(274, 560)
const DRIP_TO := Vector2(294, 700)
const DRIP_HANG := Vector2(278, 590)
const DRIP_PERIOD := 2.2
const DRIP_FALL := 0.5
const DRIP_RING := 0.5
## The lean: C's surface goes 0 -> +34, holds as a still frame for 1.5 s (Motion off: only the
## still), then settles to 0.
const LEAN_RISE := 0.6
const LEAN_HOLD := 1.5
const LEAN_SETTLE := 0.8

# --- c_tilt_rack geometry -----------------------------------------------------------------
const STATION := {"A": Vector2(190, 690), "B": Vector2(390, 690), "C": Vector2(590, 690)}
const CRADLE_PIVOT := Vector2(860, 600)
const CRADLE_SPRITE_C := Vector2(110, 160)
const CJAR_SPRITE_C := Vector2(80, 152)      # c_jar_back/front interior centre (160x272)
const CJAR_HALF := Vector2(62, 102)          # interior (18,50)-(142,254)
const CJAR_LABEL := Vector2(0, 77)
const C_SOCKET := Vector2(1230, 590)
const TEST_BOX_X := [580.0, 750.0, 920.0]
const TEST_BOX_Y := 160.0
const TEST_BOX := Vector2(150, 200)
const TAG_REST := Rect2(1160, 800, 140, 80)
const TAG_SLIDE := 0.5
const TIP_UP := 0.9
const TIP_HOLD := 1.2
const TIP_BACK := 0.6
const C_PLUMB_PIVOT := Vector2(60, 150)

# --- c_balance geometry -------------------------------------------------------------------
const BEAM_PIVOT := Vector2(724, 300)
const BEAM_ARM := 320.0
const BEAM_TIME := 0.5
## The stands, left to right by specimen number (R07Sim.SAMPLE_ORDER): 27-03, 27-11, 27-19.
const STANDS := {"W": 120.0, "N": 250.0, "F": 380.0}
const GAUGE_C := Vector2(725, 646)
const KEY_X := {"key_address": 560.0, "key_release": 720.0, "key_record": 880.0}
const KEY_WORD := {"key_address": "ADDRESS", "key_release": "RELEASE", "key_record": "RECORD"}
const KEY_DOWN_TIME := 0.15
const STRIP_X0 := 1096.0
const HOLDER_SLIP := Rect2(1168, 104, 256, 196)

# --- c_frame geometry ---------------------------------------------------------------------
const SLOT_X := [170.0, 545.0, 920.0]
const SECTION := Vector2(340, 160)
const REF_TRACE_TOP := 168.0
const REF_TRACE_BOTTOM := 268.0
const SEAL_DOWN_TIME := 0.2
## Trace shapes in section-local coordinates: x 0..1 across, y up from the 0.2 baseline.
const SHAPES := {
	"short": [Vector2(0, 0.2), Vector2(0.10, 0.2), Vector2(0.22, 0.55), Vector2(0.32, 0.2),
		Vector2(0.45, 0.2), Vector2(0.57, 0.55), Vector2(0.67, 0.2), Vector2(1, 0.2)],
	"pause": [Vector2(0, 0.2), Vector2(1, 0.2)],
	"long": [Vector2(0, 0.2), Vector2(0.05, 0.2), Vector2(0.75, 0.85), Vector2(0.95, 0.2), Vector2(1, 0.2)],
}
const REF_HEADING := "REFERENCE: N. BELL, KITCHEN WORK CARD, CALIBRATION 1927"
## The kitchen work card's trace (R05_view _draw_card_trace, card px, baseline y 95), cut into
## the three sections; the frame's sections show their piece at twice the card's scale.
const CARD_BASE := 95.0
const CARD_SCALE := 2.0
const CARD_PIECES := {
	"short": [Vector2(8, 95), Vector2(12, 95), Vector2(19, 75), Vector2(26, 95), Vector2(28, 95), Vector2(35, 75),
		Vector2(42, 95)],
	"pause": [Vector2(42, 95), Vector2(62, 95)],
	"long": [Vector2(62, 95), Vector2(65, 86.5), Vector2(68, 78.5), Vector2(71, 71.67), Vector2(74, 66.4),
		Vector2(77, 63.1), Vector2(80, 62.0), Vector2(83, 63.1), Vector2(86, 66.4), Vector2(89, 71.3),
		Vector2(92, 78.5), Vector2(95, 86.5), Vector2(98, 95), Vector2(102, 95)],
}
## The hover label of every loose section (they carry no names).
const SECTION_HOVER := "Trace section"
const REF_UNSEEN := "(card not to hand: kitchen, by the range)"
## The fog's three breaths, synced to breath_hiss (tools/audio/rooms/R07.py BREATH_WINDOWS).
const FOG_BLOOMS := [0.0, 0.55, 1.80]
const FOG_BLOOM_LEN := 0.35
## The inscription, wiped through the fog: two lines centred in the dome.
const INSCRIPTION_C := Vector2(1076, 470)
const INSCRIPTION_SIZE := 26
const WIPED := Color(0.16, 0.25, 0.28)       # dark glass showing through the wiped letters

## Notice holds: focus rects (view A unless noted).
const HOLD_TIME := 1.5
const HOLD_ZOOM := 0.06
const NOTICE_FOCUS := {
	"angles": Rect2(848, 552, 352, 244),
	"lean": Rect2(716, 318, 130, 362),
	"tank_lag": Rect2(366, 400, 340, 428),
	"vault_ajar": Rect2(1208, 318, 155, 534),
	"jars_to_vault": Rect2(716, 318, 647, 478),
	"tank_pane": Rect2(366, 400, 340, 428),
	"jars_face": Rect2(848, 552, 352, 244),
	"shells_rings": Rect2(1190, 360, 220, 240),
	"fog": Rect2(974, 396, 204, 204),
}
## Reveals that wait for their sound; if the sound never arrives they show after this long.
## (While the core still has the sound queued, behind a story line, they keep waiting.)
const REVEAL_FALLBACK := {"tag": 2.4, "pen": 2.2, "thumb": 5.0, "fog": 3.0}
const REVEAL_SOUND := {"tag": "tag_drop", "pen": "test_pen", "thumb": "felt_press", "fog": "breath_hiss"}

var r: R07Sim:
	get:
		return sim as R07Sim

var textures := {}
var narrow: SystemFont
var narrow_reg: SystemFont
var room: Node2D
var close: Node2D
var shade: CanvasModulate
var mixer: LoopMixer

# presentation state (never saved)
var hold_t := 0.0
var hold_id := ""
var hold_rect := Rect2()
var zoom_k := 0.0
var tint := 1.0
var ada_from := ADA_DEFAULT
var ada_to := ADA_DEFAULT
var ada_t := 1.0
var lean_t := -1.0              # seconds into the lean, -1 = none
var tip_t := -1.0               # seconds into the tip, -1 = none
var tip_jar := ""
var tag_t := -1.0               # -1 settled (or never), >= 0 sliding
var pending := {}               # reveal id -> seconds waited for its sound
var pen_drawn := {}             # jars whose test line has been drawn
var pen_jar := ""               # the jar whose line waits for the pen
var thumb_t := -1.0             # seconds into the thumb's fade, -1 = settled
var fog_t := -1.0               # seconds into the blooms, -1 = settled
var beam_deg := 0.0
var beam_from := 0.0
var beam_t := -1.0
var key_down := ""
var key_down_t := 0.0
var seal_t := 0.0
var close_ada := ADA_DEFAULT    # band 7 in c_tilt_rack: where the water turns (last click there)
var glance_wait := -1.0         # seconds until a queued reward glance starts, -1 = none
var glance_rect := Rect2()
var hold_close := Rect2()       # the hold's rect on the close-up layer (a glance seen in a close-up)

func _ready() -> void:
	narrow = SystemFont.new()
	narrow.font_names = PackedStringArray(["Liberation Sans Narrow", "Nimbus Sans Narrow", "DejaVu Sans Condensed", "sans-serif"])
	narrow.font_weight = 700
	narrow_reg = SystemFont.new()
	narrow_reg.font_names = narrow.font_names
	_build_nodes()
	_build_audio()
	apply_instantly()
	redraw()

func _tex(id: String) -> Texture2D:
	if not textures.has(id):
		var path := (STAGE_DIR if id in STAGE_IDS else DIR) % id
		textures[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return textures[id]

func _build_nodes() -> void:
	room = Node2D.new()
	room.name = "Room"
	add_child(room)
	room.draw.connect(_draw_room)
	shade = CanvasModulate.new()
	add_child(shade)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	close = Node2D.new()
	layer.add_child(close)
	close.draw.connect(_draw_close)

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
	return clampi(r.band(), 0, 7)

func _sever() -> bool:
	return r.ending() == "sever"

## View B (the bench) shows behind its own close-ups; view A behind the rack.
func _side() -> String:
	return "b" if _view() in ["bench", "c_balance", "c_frame"] else "a"

func stage_suffix() -> String:
	if _sever():
		return "_sever"
	var b := _band()
	return "" if b <= 2 else "_s%d" % b

func plate_id() -> String:
	if _side() == "b" and not _sever() and B_WATER_PLATES.has(_band()):
		return B_WATER_PLATES[_band()]
	return ("view_b" if _side() == "b" else "view_a") + stage_suffix()

func _p(key: String) -> bool:
	return bool(r.state.get(key, false))

func _water_col() -> Color:
	if _band() >= 7 and not _sever():
		var c := Color(WATER, 1.0).lerp(BRUISE, 0.2)
		return Color(c, WATER.a)
	return WATER

## Where the water turns to at band 7 (eased toward the last click in view A).
func ada_point() -> Vector2:
	var k := smoothstep(0.0, 1.0, ada_t)
	return ada_from.lerp(ada_to, k)

## The surface angle (degrees, screen space, positive = descending to the right) of a jar in
## view A, by its rule, the room's anomaly and the lean.
func jar_surface_deg(j: String, centre: Vector2, rot: float) -> float:
	match r.anomaly():
		"level":
			return 0.0
		"vault":
			return _leaning_deg(centre, VAULT_C)
		"ada":
			return _facing_deg(centre, ada_point())
	if r.stair_lean():
		return R07Sim.STAIR_LEAN_DEG
	if j == "C" and r.state.socket == "C":
		return R07Sim.surface_deg(R07Sim.JAR_RULE[j], rot) + lean_deg()
	return R07Sim.rack_rest_deg(j)

## Band 5-6: the water still lies down, but pulled hard toward `to`: its surface rises on the
## side facing it, about 60 degrees off level for the vault.
static func _leaning_deg(from: Vector2, to: Vector2) -> float:
	var d := to - from
	if d.length() < 0.001:
		return 0.0
	var n := (d.normalized() + Vector2(0, VAULT_PULL_DOWN)).normalized()
	return rad_to_deg(atan2(-n.x, n.y))

## theta for a surface whose water side normal points from `from` to `to`.
static func _facing_deg(from: Vector2, to: Vector2) -> float:
	var n := (to - from)
	if n.length() < 0.001:
		return 0.0
	n = n.normalized()
	return rad_to_deg(atan2(-n.x, n.y))

func tank_surface_deg() -> float:
	match r.tank_mode():
		"pane":
			return R07Sim.PANE_DEG
		"level":
			return 0.0
	if r.stair_lean():
		return R07Sim.STAIR_LEAN_DEG
	return R07Sim.GRAVITY_DEG

## C's lean right now (0 when still).
func lean_deg() -> float:
	if lean_t < 0.0:
		return 0.0
	if not motion:
		return R07Sim.LEAN_DEG if lean_t < LEAN_HOLD else 0.0
	var t := lean_t
	if t < LEAN_RISE:
		return R07Sim.LEAN_DEG * smoothstep(0.0, 1.0, t / LEAN_RISE)
	t -= LEAN_RISE
	if t < LEAN_HOLD:
		return R07Sim.LEAN_DEG
	t -= LEAN_HOLD
	return R07Sim.LEAN_DEG * (1.0 - smoothstep(0.0, 1.0, t / LEAN_SETTLE))

func plumb_deg() -> float:
	return 0.0 if _sever() else R07Sim.GRAVITY_DEG

## The cradle jar's rotation through the tip.
func tip_deg() -> float:
	if tip_t < 0.0:
		return 0.0
	if not motion:
		return R07Sim.TIP_DEG
	var t := tip_t
	if t < TIP_UP:
		return R07Sim.TIP_DEG * smoothstep(0.0, 1.0, t / TIP_UP)
	t -= TIP_UP
	if t < TIP_HOLD:
		return R07Sim.TIP_DEG
	t -= TIP_HOLD
	return R07Sim.TIP_DEG * (1.0 - smoothstep(0.0, 1.0, t / TIP_BACK))

func _tip_len() -> float:
	return (TIP_UP + TIP_HOLD + TIP_BACK) if motion else HOLD_TIME

func beam_target() -> float:
	return -float(r.beam_reading()) * 3.0

func fog_alpha() -> float:
	if not r.fog_shown():
		return 0.0
	if pending.has("fog"):
		return 0.0
	if fog_t < 0.0:
		return 1.0
	if not motion:
		return 1.0 if hold_t <= 0.0 else 0.0
	var a := 0.0
	for k in FOG_BLOOMS.size():
		a += clampf((fog_t - FOG_BLOOMS[k]) / FOG_BLOOM_LEN, 0.0, 1.0) / FOG_BLOOMS.size()
	return a

func thumb_alpha() -> float:
	if not r.state.p13_complete or pending.has("thumb"):
		return 0.0
	if thumb_t < 0.0 or not motion:
		return 1.0
	return clampf(thumb_t / 0.6, 0.0, 1.0)

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------
func tick(dt: float) -> void:
	if hold_t > 0.0:
		hold_t = maxf(0.0, hold_t - dt)
	var zt := 1.0 if hold_t > 0.0 and motion and not r.is_closeup() else 0.0
	zoom_k = move_toward(zoom_k, zt, dt * 2.5)
	var s := 1.0 + HOLD_ZOOM * smoothstep(0.0, 1.0, zoom_k)
	var focus := hold_rect.get_center()
	room.scale = Vector2(s, s)
	room.position = focus * (1.0 - s)
	ada_t = minf(1.0, ada_t + dt / ADA_TURN) if motion else 1.0
	if lean_t >= 0.0:
		lean_t += dt
		if lean_t > (LEAN_RISE + LEAN_HOLD + LEAN_SETTLE if motion else LEAN_HOLD):
			lean_t = -1.0
	if glance_wait >= 0.0:
		glance_wait -= dt
		if glance_wait < 0.0:
			start_glance("", glance_rect)
	if tip_t >= 0.0:
		tip_t += dt
		if tip_t > _tip_len():
			tip_t = -1.0
			tip_jar = ""
	if tag_t >= 0.0:
		tag_t += dt
		if tag_t > TAG_SLIDE or not motion:
			tag_t = -1.0
	if thumb_t >= 0.0:
		thumb_t += dt
		if thumb_t > 0.6:
			thumb_t = -1.0
	if fog_t >= 0.0:
		fog_t += dt
		if fog_t > FOG_BLOOMS[-1] + FOG_BLOOM_LEN and hold_t <= 0.0:
			fog_t = -1.0
	for id in pending.keys():
		if game and game.sfx_pending(REVEAL_SOUND[id]):
			pending[id] = 0.0
			continue
		pending[id] += dt
		if pending[id] > REVEAL_FALLBACK[id]:
			_reveal(id)
	if pen_jar == "":
		for j in R07Sim.JARS:
			if r.state.tested[j]:
				pen_drawn[j] = true
	# the beam
	var bt := beam_target()
	if beam_t >= 0.0 and motion:
		beam_t += dt
		var k := smoothstep(0.0, 1.0, minf(1.0, beam_t / BEAM_TIME))
		beam_deg = lerpf(beam_from, bt, k)
		if beam_t >= BEAM_TIME:
			beam_t = -1.0
	else:
		beam_t = -1.0
		beam_deg = bt
	key_down_t = maxf(0.0, key_down_t - dt)
	seal_t = maxf(0.0, seal_t - dt)
	var tt: float = 1.0 if _sever() else TINT[_band()]
	tint = move_toward(tint, tt, dt * 0.2)
	shade.color = Color(tint, tint, tint)
	_tick_audio(dt)
	redraw()

func loop_targets() -> Dictionary:
	var b := _band()
	var sever := _sever()
	var hangs := r.drip_hangs()
	var db := {"r07_room": -6.0}
	if sever:
		db["r07_tank_hum"] = -10.0
	elif b <= 2:
		db["r07_tank_hum"] = -10.0
	elif b <= 5:
		db["r07_tank_hum"] = -8.0
	if not hangs:
		if _p("tap_on"):
			db["r07_trickle"] = -10.0
		else:
			db["r07_drip"] = -12.0
	if not sever:
		if b >= 5:
			db["r07_glass_sing"] = [-20.0, -16.0, -13.0][b - 5]
		if b >= 4:
			db["r07_undertow"] = [-20.0, -17.0, -14.0, -11.0][b - 4]
	var in_close := r.is_closeup()
	var duck := game != null and game.oneshot_playing(DUCK_IDS)
	var out := {}
	for id in LOOPS:
		if not db.has(id):
			out[id] = 0.0
			continue
		var v: float = db[id]
		if in_close and id != "r07_room":
			v -= 4.0
		if duck:
			v -= 6.0
		out[id] = db_to_linear(v)
	return out

func _tick_audio(dt: float) -> void:
	var targets := loop_targets()
	var rates := {}
	for id in LOOPS:
		rates[id] = LOOP_RATE
	mixer.tick(targets, rates, dt)

# ---------------------------------------------------------------------------
# hooks
# ---------------------------------------------------------------------------
func play_fx(id: String, e: Dictionary) -> void:
	if id.begins_with("notice_"):
		_start_hold(id.substr(7))
		match id:
			"notice_fog":
				pending["fog"] = 0.0
				fog_t = -1.0
		return
	match id:
		"glance":
			glance_rect = e.get("rect", Rect2())
			glance_wait = maxf(0.0, float(e.get("delay", 0.0)))
		"tip":
			tip_jar = r.last_test
			tip_t = 0.0
			if tip_jar != "" and not pen_drawn.has(tip_jar):
				pen_jar = tip_jar
				pending["pen"] = 0.0
		"tag":
			pending["tag"] = 0.0
		"thumb":
			pending["thumb"] = 0.0
			thumb_t = -1.0
		"strip", "strip_recorded":
			beam_from = beam_deg
			beam_t = 0.0
		"frame_sealed":
			seal_t = SEAL_DOWN_TIME

func on_sfx(id: String) -> void:
	match id:
		"water_lean":
			lean_t = 0.0
			# the notice's hold (zoom or brackets) stays on the jar until the still has held
			if hold_id == "lean" and hold_t > 0.0:
				hold_t = maxf(hold_t, (LEAN_RISE + LEAN_HOLD) if motion else LEAN_HOLD)
		"test_pen":
			_reveal("pen")
		"tag_drop":
			_reveal("tag")
		"felt_press":
			_reveal("thumb")
		"breath_hiss":
			_reveal("fog")

## A reveal's sound has started (or it waited too long): show it.
func _reveal(id: String) -> void:
	if not pending.has(id):
		return
	pending.erase(id)
	match id:
		"pen":
			if pen_jar != "":
				pen_drawn[pen_jar] = true
			pen_jar = ""
		"tag":
			tag_t = 0.0 if motion else -1.0
		"thumb":
			thumb_t = 0.0 if motion else -1.0
		"fog":
			fog_t = 0.0

func _start_hold(n: String, rect := Rect2()) -> void:
	if rect.size == Vector2.ZERO:
		rect = NOTICE_FOCUS.get(n, Rect2())
	if rect.size == Vector2.ZERO:
		return
	hold_id = n
	hold_rect = rect
	hold_close = Rect2()
	hold_t = HOLD_TIME

## Where a reward glance lands on the close-up layer when she is in that close-up: the socket
## (P10, c_tilt_rack) and the sealed frame (P14, c_frame).
const GLANCE_CLOSE := {
	"c_tilt_rack": [Rect2(716, 318, 130, 362), Rect2(1110, 380, 240, 400)],
	"c_frame": [Rect2(720, 330, 250, 270), Rect2(140, 340, 1170, 340)],
}

## A reward is seen: the notice hold's brackets and zoom on `rect` (view A/B space). In a
## close-up the brackets go round the same thing there. Motion off: still brackets.
func start_glance(_target: String, rect: Rect2) -> bool:
	glance_wait = -1.0
	if rect.size == Vector2.ZERO:
		return false
	_start_hold("glance", rect)
	var m: Array = GLANCE_CLOSE.get(_view(), [])
	if not m.is_empty() and m[0] == rect:
		hold_close = m[1]
	return true

## Exit tabs point to the side their painted door is on: RECORDS is on the right of view A, the
## STAIR door on the left. "" keeps the core's default.
func exit_arrow(to: String) -> String:
	match to:
		"R10":
			return "right"
		"R11":
			return "left"
	return ""

func hold_active() -> bool:
	return hold_t > 0.0

func apply_instantly() -> void:
	reset_presentation()
	tint = 1.0 if _sever() else TINT[_band()]
	shade.color = Color(tint, tint, tint)
	beam_deg = beam_target()
	for j in R07Sim.JARS:
		if r.state.tested[j]:
			pen_drawn[j] = true
	if mixer:
		mixer.snap(loop_targets())
	room.scale = Vector2.ONE
	room.position = Vector2.ZERO

func reset_presentation() -> void:
	hold_t = 0.0
	hold_id = ""
	zoom_k = 0.0
	ada_from = ADA_DEFAULT
	ada_to = ADA_DEFAULT
	ada_t = 1.0
	lean_t = -1.0
	tip_t = -1.0
	tip_jar = ""
	tag_t = -1.0
	pending = {}
	pen_drawn = {}
	pen_jar = ""
	thumb_t = -1.0
	fog_t = -1.0
	beam_t = -1.0
	key_down = ""
	key_down_t = 0.0
	seal_t = 0.0
	close_ada = ADA_DEFAULT
	glance_wait = -1.0
	glance_rect = Rect2()
	hold_close = Rect2()

func redraw() -> void:
	room.queue_redraw()
	close.queue_redraw()

func back_visible() -> bool:
	return _view() != "room"

func esc_action() -> String:
	return "back" if _view() != "room" else "menu"

func exits_active() -> bool:
	return _view() == "room"

# ---------------------------------------------------------------------------
# input
# ---------------------------------------------------------------------------
## The controls of close-up `cid` as [id, rect, label]; c_frame's loose sections sit at their
## tray positions (sim.tray_sections()).
func closeup_controls(cid: String) -> Array:
	match cid:
		"c_tilt_rack":
			return RACK_CONTROLS
		"c_balance":
			return BALANCE_CONTROLS
		"c_frame":
			var out := []
			var tray := r.tray_sections()
			for k in tray.size():
				if tray[k] != "":
					out.append(["sec_" + tray[k], TRAY_RECTS[k], SECTION_HOVER])
			return out + FRAME_FIXED
	return []

func _controls() -> Array:
	match _view():
		"room":
			return HOTSPOTS
		"bench":
			return BENCH_HOTSPOTS
	return closeup_controls(_view())

func action_at(p: Vector2) -> String:
	if _view() in ["room", "c_tilt_rack"]:
		_note_click(p)
	if hold_t > 0.0:
		hold_t = 0.0   # a click skips the hold, and does nothing else
		return ""
	for h in _controls():
		if h[1].has_point(p):
			var id: String = h[0]
			if _view() == "room" and gsim():
				if id == "vault_door" and gsim().exit_open(rid, "R10") and r.state.vault_ajar_said:
					return "go:R10"
				if id == "return_door" and gsim().exit_open(rid, "R11"):
					return "go:R11"
			if id.begins_with("key_"):
				key_down = id
				key_down_t = KEY_DOWN_TIME
			return id
	return ""

## Band 7: the water turns to face wherever she last clicked in view A (presentation only).
func _note_click(p: Vector2) -> void:
	if _view() == "c_tilt_rack":
		close_ada = p
		return
	if p.distance_to(ada_to) < 0.5:
		return
	ada_from = ada_point()
	ada_to = p
	ada_t = 0.0 if motion else 1.0

func hover_at(p: Vector2) -> String:
	if hold_t > 0.0:
		return ""
	for h in _controls():
		if h[1].has_point(p):
			return h[0]
	return ""

func label_for(id: String) -> String:
	for table in [HOTSPOTS, BENCH_HOTSPOTS, RACK_CONTROLS, BALANCE_CONTROLS, FRAME_FIXED]:
		for h in table:
			if h[0] == id:
				return h[2]
	if id.begins_with("sec_") and R07Sim.SECTION_LABELS.has(id.substr(4)):
		return SECTION_HOVER
	return ""

func hotspot_rect(id: String) -> Rect2:
	for table in [HOTSPOTS, BENCH_HOTSPOTS]:
		for h in table:
			if h[0] == id:
				return h[1]
	return Rect2()

func dev_rects() -> Array:
	var out := []
	for h in _controls():
		out.append(h[1])
	return out

# ---------------------------------------------------------------------------
# drawing helpers
# ---------------------------------------------------------------------------
func _full(c: CanvasItem, id: String, a := 1.0) -> void:
	var t := _tex(id)
	if t:
		c.draw_texture_rect(t, Rect2(Vector2.ZERO, SIZE), false, Color(1, 1, 1, a))

func _sprite(c: CanvasItem, id: String, at: Vector2, a := 1.0) -> void:
	var t := _tex(id)
	if t:
		c.draw_texture(t, at, Color(1, 1, 1, a))

## Centred on x; `y` is the baseline.
func _ctext(c: CanvasItem, s: String, x: float, y: float, size: int, col: Color, font: Font = null) -> void:
	var f: Font = font if font else Ink.serif()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(f, Vector2(x - w / 2.0, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## Centred in `rect`.
func _rtext(c: CanvasItem, s: String, rect: Rect2, size: int, col: Color, font: Font = null) -> void:
	var f: Font = font if font else Ink.serif()
	_ctext(c, s, rect.get_center().x, rect.get_center().y + f.get_ascent(size) * 0.5 - f.get_descent(size) * 0.3,
		size, col, f)

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

## Wrapped lines, left aligned from `pos` (first baseline); returns the next baseline.
func _para(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, width: float, font: Font = null,
		lead := 1.3) -> float:
	var f: Font = font if font else Ink.serif()
	var y := pos.y
	for line in _wrap(s, f, size, width):
		c.draw_string(f, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		y += size * lead
	return y

## A dashed (or dot-dash) line: `pattern` is [on, off, on, off, ...] in px.
func _dashed(c: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float, pattern: Array) -> void:
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var d := (b - a) / length
	var t := 0.0
	var i := 0
	while t < length:
		var seg: float = pattern[i % pattern.size()]
		if i % 2 == 0:
			c.draw_line(a + d * t, a + d * minf(length, t + seg), col, w)
		t += seg
		i += 1

func _dashed_rect(c: CanvasItem, rect: Rect2, col: Color, w: float) -> void:
	var p := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for k in 4:
		_dashed(c, p[k], p[(k + 1) % 4], col, w, [12.0, 8.0])

## Ink corner brackets round `rect` (the still alternative to the hold zoom).
func _brackets(c: CanvasItem, rect: Rect2) -> void:
	var g := rect.grow(14)
	var arm := minf(40.0, minf(g.size.x, g.size.y) * 0.3)
	for corner in [[g.position, Vector2(1, 1)], [Vector2(g.end.x, g.position.y), Vector2(-1, 1)],
			[g.end, Vector2(-1, -1)], [Vector2(g.position.x, g.end.y), Vector2(1, -1)]]:
		var p: Vector2 = corner[0]
		var s: Vector2 = corner[1]
		for pass_ in [[INK, 7.0], [PAPER_HI, 3.0]]:
			c.draw_polyline(PackedVector2Array([p + Vector2(0, s.y * arm), p, p + Vector2(s.x * arm, 0)]),
				pass_[0], pass_[1])

## A paper plate with ink edge and centred narrow text.
func _plate(c: CanvasItem, rect: Rect2, s: String, size: int) -> void:
	c.draw_rect(rect, PAPER_HI)
	c.draw_rect(rect, INK, false, 2.0)
	_rtext(c, s, rect, size, INK, narrow)

## Text written on a painted blank plate (no new plate).
func _on_plate(c: CanvasItem, rect: Rect2, s: String, size: int, font: Font = null) -> void:
	_rtext(c, s, rect, size, INK, font if font else narrow)

# --- water --------------------------------------------------------------------------------
## Clips the convex `poly` to {p : (p - c) . n >= 0}; returns [polygon, chord points].
static func clip_half(poly: PackedVector2Array, c: Vector2, n: Vector2) -> Array:
	var out := PackedVector2Array()
	var chord := []
	var m := poly.size()
	for i in m:
		var a := poly[i]
		var b := poly[(i + 1) % m]
		var da := (a - c).dot(n)
		var db := (b - c).dot(n)
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			var q := a.lerp(b, da / (da - db))
			out.append(q)
			chord.append(q)
	return [out, chord]

static func surface_normal(theta_deg: float) -> Vector2:
	var t := deg_to_rad(theta_deg)
	return Vector2(-sin(t), cos(t))

## The interior rectangle of a vessel whose interior centre is `centre`, rotated `rot` degrees.
static func interior(centre: Vector2, half: Vector2, rot: float) -> PackedVector2Array:
	var a := deg_to_rad(rot)
	var out := PackedVector2Array()
	for k in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		out.append(centre + k.rotated(a))
	return out

## Half-full water in `poly` (convex) with its surface through `centre` at `theta`; `ripple`
## px of shimmer on the surface line (0 = still).
func _water(c: CanvasItem, poly: PackedVector2Array, centre: Vector2, theta: float, ripple: float,
		phase := 0.0) -> void:
	var n := surface_normal(theta)
	var res := clip_half(poly, centre, n)
	var body: PackedVector2Array = res[0]
	var col := _water_col()
	if body.size() >= 3:
		c.draw_colored_polygon(body, Color(col.r * WATER_BODY, col.g * WATER_BODY, col.b * WATER_BODY, col.a))
	var chord: Array = res[1]
	if chord.size() < 2:
		return
	# a sea-glass highlight just under the surface, then the storm-navy meniscus on the line
	var line := _shimmer(chord[0], chord[1], n, ripple, phase)
	var under := PackedVector2Array()
	for q in line:
		under.append(q + n * 2.5)
	c.draw_polyline(under, SEAGLASS_HI, 2.0, true)
	c.draw_polyline(line, STORM, 3.0, true)

func _shimmer(a: Vector2, b: Vector2, n: Vector2, amp: float, phase: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if amp <= 0.0:
		pts.append(a)
		pts.append(b)
		return pts
	var steps := 24
	for i in steps + 1:
		var s := float(i) / steps
		var off := amp * sin(s * TAU * 2.0 + time * 2.2 + phase) * sin(PI * s)
		pts.append(a.lerp(b, s) + n * off)
	return pts

## Surfaces are one straight hard edge (stark flat silhouettes): no shimmer anywhere.
func _ripple() -> float:
	return 0.0

## A jar, sprite pair `pre`_back / `pre`_front, its interior centre at `centre`, rotated `rot`,
## with half-full water at `theta` and its letter on the label plate.
func _jar(c: CanvasItem, pre: String, sprite_c: Vector2, half: Vector2, label_off: Vector2, centre: Vector2,
		rot: float, theta: float, letter: String, size: int, ripple: float, k := 1.0) -> void:
	var a := deg_to_rad(rot)
	c.draw_set_transform(centre, a, Vector2(k, k))
	_sprite(c, pre + "_back", -sprite_c)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	_water(c, interior(centre, half * k, rot), centre, theta, ripple, centre.x * 0.05)
	c.draw_set_transform(centre, a, Vector2(k, k))
	_sprite(c, pre + "_front", -sprite_c)
	if letter != "":
		_ctext(c, letter, label_off.x, label_off.y + size * 0.36, size, INK, narrow)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## A plumb sprite hung from `pivot`, its tag lettered GRAVITY along the string.
func _plumb(c: CanvasItem, id: String, pivot: Vector2, sprite_piv: Vector2, tag_y: float) -> void:
	var a := deg_to_rad(-plumb_deg())   # the bob swings to +x for a negative surface angle
	c.draw_set_transform(pivot, a, Vector2.ONE)
	_sprite(c, id, -sprite_piv)
	var tag := Rect2(-13, tag_y, 26, 72)
	c.draw_rect(tag, PAPER_HI)
	c.draw_rect(tag, INK, false, 2.0)
	c.draw_circle(Vector2(0, tag_y + 6), 2.5, INK)
	c.draw_set_transform_matrix(Transform2D(a, pivot) * Transform2D(PI / 2.0, Vector2.ZERO))
	var w := narrow.get_string_size("GRAVITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	c.draw_string(narrow, Vector2(tag_y + 12 + (60 - w) / 2.0, 6), "GRAVITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

# ---------------------------------------------------------------------------
# drawing: view A and view B (world)
# ---------------------------------------------------------------------------
func _draw_room() -> void:
	if _side() == "b":
		_draw_view_b(room)
	else:
		_draw_view_a(room)
	if hold_t > 0.0 and not r.is_closeup() and not motion:
		_brackets(room, hold_rect)

func _draw_view_a(c: CanvasItem) -> void:
	var b := _band()
	var sever := _sever()
	var p10: bool = r.state.p10_complete
	_full(c, plate_id())
	_draw_sea(c, "a")
	_draw_stage(c, "b2_tidemark")
	for id in deep_layers():
		_full(c, id)
	_draw_stage(c, "b4_water_lean")
	_draw_datum_water(c)
	# the tank: water, the lagging reflection, then the glass and frame over both
	var tpoly := interior(TANK_C, TANK_IN.size / 2.0, 0.0)
	var tr := 0.0 if r.tank_mode() == "pane" else _ripple()
	_water(c, tpoly, TANK_C, tank_surface_deg(), tr, 1.3)
	_draw_reflection(c, b)
	var glass := _tex("a_tank_glass")
	if glass:
		c.draw_texture_rect(glass, Rect2(Vector2.ZERO, SIZE), false,
			Color(0.93, 0.93, 0.93) if sever else Color.WHITE)
	# the wall lamp, redrawn over the water's overlays: from band 6 it hangs 40 px lower, over the
	# tank's rim
	if sea_tier() >= 2:
		_full(c, "a_lamp_low" if sea_tier() >= 6 else "a_lamp")
	if r.vault_ajar():
		_full(c, "a_vault_ajar")
		if sea_tier() >= 6:
			_full(c, "a_sea_b6_slot")
	if r.return_unbolted():
		_full(c, "a_return_unbolted")
	if p10:
		_full(c, "a_rack_salt_v2")
	# the brass datum and the plumb that disagrees with it
	_on_plate(c, DATUM_TAG, "DATUM", 18)
	_plumb(c, "plumb", PLUMB_PIVOT, PLUMB_SPRITE_PIV, 108.0)
	# the rack's station plates, then the jars
	for j in R07Sim.JARS:
		var pc: Vector2 = JAR_POS[j]
		_on_plate(c, Rect2(pc.x - 28, RACK_PLATE_Y, 56, 22), j, 18)
	for j in R07Sim.JARS:
		var centre: Vector2 = JAR_POS[j]
		if j == "C" and r.state.socket == "C":
			centre = SOCKET_POS
		var rot := r.jar_rest_rot(j)
		var k := SOCKET_SCALE if centre == SOCKET_POS else 1.0
		_jar(c, "jar", JAR_SPRITE_C, JAR_HALF, JAR_LABEL, centre, rot, jar_surface_deg(j, centre, rot), j, 18,
			_ripple(), k)
	# the socket's reference card and, after P10, its tag
	_rtext(c, "REFERENCE", Rect2(SOCKET_CARD.position.x, SOCKET_CARD.position.y + 5, SOCKET_CARD.size.x, 22), 17,
		INK, narrow_reg)
	_rtext(c, "SOCKET", Rect2(SOCKET_CARD.position.x, SOCKET_CARD.position.y + 27, SOCKET_CARD.size.x, 22), 17,
		INK, narrow_reg)
	if p10:
		_full(c, "a_socket_tag")
		# two lines: the tag is narrow, and the figure is the thing to read
		var tx := SOCKET_TAG.position.x + 30 + (SOCKET_TAG.size.x - 34) / 2.0
		_ctext(c, "TARGET", tx, SOCKET_TAG.position.y + 25, 21, INK, narrow_reg)
		_ctext(c, "2", tx, SOCKET_TAG.position.y + 50, 24, INK, narrow)
	# doors
	_on_plate(c, STAIR_TAG, "STAIR", 20)
	_on_plate(c, RECORDS_TAG, "RECORDS", 20)
	_draw_basin_water(c)

## True while view A shows the sea standing at the datum (band >= 3, not after sever).
func datum_water_on() -> bool:
	return r.datum_flooded()

## The view-A layers under the datum water, bottom to top, in _draw_view_a's order (all of
## them still below y 300: only b2_tidemark's caustic rows above it move).
func _datum_layers() -> Array:
	var ids := [plate_id()]
	var t := sea_tier()
	if t >= 6:
		ids.append("a_lamp_patch_s%d" % mini(_band(), 7))
	for k in [2, 3, 4, 6, 7]:
		if t >= k:
			ids.append("a_sea_b%d" % k)
	var stages := stage_overlays()
	if "b2_tidemark" in stages:
		ids.append("b2_tidemark")
	ids.append_array(deep_layers())
	if "b4_water_lean" in stages:
		ids.append("b4_water_lean")
	return ids

var _datum_key := ""
var _datum_tex: Texture2D = null

func _draw_datum_water(c: CanvasItem) -> void:
	if not datum_water_on():
		return
	var ids := _datum_layers()
	var key := ",".join(ids)
	if key != _datum_key:
		_datum_key = key
		_datum_tex = _compose_datum_water(ids)
	if _datum_tex:
		c.draw_texture(_datum_tex, Vector2(0, DATUM_SURFACE_Y))
	else:
		# no image access (headless): the wash and the surface alone, unshifted
		_full(c, "datum_water_r3")

## Below the surface: the layers flattened, shifted DATUM_SHIFT px where the wash falls, then
## washed; the unwashed pixels (the hotspot art) stay as they are. Built once per stage.
func _compose_datum_water(ids: Array) -> Texture2D:
	var wt := _tex("datum_water_r3")
	if wt == null:
		return null
	var area := Rect2i(0, DATUM_SURFACE_Y, int(SIZE.x), int(SIZE.y) - DATUM_SURFACE_Y)
	var whole := Rect2i(Vector2i.ZERO, area.size)
	var wash := _region(wt, area)
	if wash == null:
		return null
	var below: Image = null
	for id in ids:
		var t := _tex(id)
		if t == null:
			continue
		var im := _region(t, area)
		if im == null:
			return null
		if below == null:
			below = im
		else:
			below.blend_rect(im, whole, Vector2i.ZERO)
	if below == null:
		return null
	var shifted := below.duplicate() as Image
	shifted.blit_rect(below, Rect2i(0, 0, area.size.x - DATUM_SHIFT, area.size.y), Vector2i(DATUM_SHIFT, 0))
	var out := below.duplicate() as Image
	out.blit_rect_mask(shifted, wash, whole, Vector2i.ZERO)
	out.blend_rect(wash, whole, Vector2i.ZERO)
	return ImageTexture.create_from_image(out)

## `area` of a texture as an RGBA8 image, or null when the texture has no readable image.
static func _region(t: Texture2D, area: Rect2i) -> Image:
	var im := t.get_image()
	if im == null or im.is_empty():
		return null
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	return im.get_region(area)

## The lab takes on water (tools/art/rooms/R07.py "the sea comes in"): the highest overlay tier
## due now, 0 for none. Bands are game.weather_band(); R07 opens at band 2. Sever releases it.
func sea_tier() -> int:
	if _sever():
		return 0
	var b := _band()
	for t in [7, 6, 4, 3, 2]:
		if b >= t:
			return t
	return 0

## Every tier up to the current one, over the stage plate: condensation (2), the waterline at
## the datum (3), navy grout and the porthole (4), wet tiles and the lowered lamp's wall (6), the
## band-7 handprint and bloom contours (7). From band 6 a patch of the plate's own wall first
## takes the painted lamp away; the lamp is redrawn above the overlays.
func _draw_sea(c: CanvasItem, side: String) -> void:
	var t := sea_tier()
	if t >= 6:
		_full(c, "%s_lamp_patch_s%d" % [side, mini(_band(), 7)])
	for k in [2, 3, 4, 6, 7]:
		if t >= k:
			_full(c, "%s_sea_b%d" % [side, k])

## The stage overlays due now on the side she is looking at (assets/stages/R07): the tide stain,
## caustics and storm floor from band 2 (so P10, P13 and P14 are played under them), from band 4
## the bench lamp shrunk to one pool with the right third matte navy (view B), and in bands 4-6
## every run of water heading for the STAIR door (view A). Sever releases the room.
func stage_overlays() -> Array:
	if _sever():
		return []
	var b := _band()
	var out := []
	if _side() == "a":
		if b >= 2:
			out.append("b2_tidemark")
		if r.stair_lean():
			out.append("b4_water_lean")
	else:
		if b >= 2:
			out.append("b2_tidemark_bench")
		if b >= 4:
			out.append("b4_lamp_pool")
	return out

func _draw_stage(c: CanvasItem, id: String) -> void:
	if not id in stage_overlays():
		return
	var t := _tex(id)
	if t == null:
		return
	if not id.begins_with("b2_tidemark") or not motion:
		c.draw_texture_rect(t, Rect2(Vector2.ZERO, SIZE), false)
		return
	# the caustic rows drift, the rest holds still
	var top := Rect2(0, 0, SIZE.x, CAUSTIC_ROWS)
	var dx := CAUSTIC_DRIFT * sin(time * 0.45)
	c.draw_texture_rect_region(t, Rect2(top.position + Vector2(dx, 0), top.size), top)
	var rest := Rect2(0, CAUSTIC_ROWS, SIZE.x, SIZE.y - CAUSTIC_ROWS)
	c.draw_texture_rect_region(t, rest, rest)

## The room beneath the water (tools/art/rooms/R07.py), over the sea tiers in view A: the room's
## own waterline, flat and square to the DATUM while the plumb's GRAVITY tag hangs eight degrees
## off it (4), tide rings on the ceiling (6), the wet hand brought forward (7). Sever drains it.
func deep_layers() -> Array:
	var t := sea_tier()
	var out := []
	if t >= 4:
		out.append("waterline")
	if t >= 6:
		out.append("ceiling_rings")
	if t >= 7:
		out.append("wall_hand")
	return out

## The rack as the tank glass remembers it: faint, and from band 3 its ripples run the wrong way.
func _draw_reflection(c: CanvasItem, b: int) -> void:
	var t := _tex("a_reflect_three" if r.reflection_jars() == 3 else "a_reflect_two")
	if t == null:
		return
	var col := REFL_TINT
	if b < 3 or not motion or _sever():
		c.draw_texture_rect_region(t, REFL, REFL, col)
		return
	var y := REFL.position.y
	while y < REFL.end.y:
		var h := minf(6.0, REFL.end.y - y)
		var dx := 2.0 * sin(y * 0.11 - time * 2.2)   # counter to the water's shimmer
		var src := Rect2(REFL.position.x, y, REFL.size.x, h)
		c.draw_texture_rect_region(t, Rect2(src.position + Vector2(dx, 0), src.size), src, col)
		y += h

## The tap: a drop every 2.2 s along the gravity slant, a run when the tap is on, or (band 6+) a
## drop that hangs at the spout and never falls.
func _draw_basin_water(c: CanvasItem) -> void:
	var drop_col := SEAGLASS_HI
	if r.drip_hangs():
		_drop(c, DRIP_HANG, drop_col)
		return
	var to := DRIP_TO
	var from := DRIP_FROM
	if r.anomaly() == "level":
		to = Vector2(DRIP_FROM.x, DRIP_TO.y)
	if _p("tap_on"):
		var pts := PackedVector2Array()
		var n := (to - from).normalized().orthogonal()
		for i in 13:
			var s := i / 12.0
			var off := (1.2 * sin(s * 18.0 - time * 14.0)) if motion else 0.0
			pts.append(from.lerp(to, s) + n * off)
		c.draw_polyline(pts, INK, 6.0, true)
		c.draw_polyline(pts, drop_col, 3.0, true)
		_ring(c, to, 12.0, 3.0, Color(INK, 0.6), 1.6)
		return
	if not motion:
		_drop(c, from.lerp(to, 0.5), drop_col)
		return
	var ph := fmod(time, DRIP_PERIOD)
	if ph < DRIP_FALL:
		var k := ph / DRIP_FALL
		_drop(c, from.lerp(to, k * k), drop_col)
	elif ph < DRIP_FALL + DRIP_RING:
		var k := (ph - DRIP_FALL) / DRIP_RING
		_ring(c, to, 4.0 + 14.0 * k, 1.0 + 3.0 * k, Color(INK, 0.7 * (1.0 - k)), 1.6)
	else:
		_drop(c, from, drop_col)   # the next one swelling at the spout

## A teardrop leaning along the gravity slant: a round belly and a point toward the spout.
func _drop(c: CanvasItem, at: Vector2, col: Color) -> void:
	var up := (DRIP_FROM - DRIP_TO).normalized()
	var side := up.orthogonal()
	var tip := at + up * 9.0
	for pass_ in [[INK, 5.0], [col, 3.4]]:
		var rad: float = pass_[1]
		c.draw_colored_polygon(PackedVector2Array([tip + up * (rad - 3.4), at + side * rad, at - side * rad]), pass_[0])
		c.draw_circle(at, rad, pass_[0])
	c.draw_circle(at - side * 1.2 + up * 1.0, 1.0, PAPER_HI)

func _ring(c: CanvasItem, centre: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := Ink.ellipse(centre, rx, ry, 32)
	pts.append(pts[0])
	c.draw_polyline(pts, col, w, true)

func _draw_view_b(c: CanvasItem) -> void:
	var p13: bool = r.state.p13_complete
	var p14: bool = r.state.p14_complete
	_full(c, plate_id())
	_draw_sea(c, "b")
	_draw_stage(c, "b2_tidemark_bench")
	_draw_stage(c, "b4_lamp_pool")
	if sea_tier() >= 6:
		_full(c, "b_lamp_low")
	_full(c, "b_stand_empty" if p14 else "b_frame")
	_full(c, "b_lid_open" if p13 and not p14 else "b_lid_closed")
	_full(c, "b_shells_rings" if r.shells_aligned() else "b_shells_loose")
	if r.thumb_shown():
		_full(c, "b_thumb", thumb_alpha())
	if p13 and not p14:
		_full(c, "b_register_open")
		_full(c, "b_strip")
	var fa := fog_alpha()
	if fa > 0.0:
		_full(c, "b_fog", fa)
		var ia := clampf((fa - 0.66) / 0.34, 0.0, 1.0)
		if ia > 0.0:
			_inscription(c, ia)
	# the sample cards: a specimen number only; the readings are found on the balance
	for k in 3:
		var x0 := 60.0 + k * 76
		var sm: String = R07Sim.SAMPLE_ORDER[k]
		_ctext(c, R07Sim.SPECIMEN[sm], x0 + 34, 183, 16, INK, narrow)
	if not (p13 and not p14):
		_on_plate(c, Rect2(180, 672, 100, 26), "REGISTER", 16)

## The inscription as letters wiped clear through the fog by a finger: dark glass showing
## through, each glyph a little off its line, with a short smear where the finger dragged.
func _inscription(c: CanvasItem, a: float) -> void:
	var lines := ["Retention is", "not resuscitation."]
	var sz := INSCRIPTION_SIZE
	for k in lines.size():
		var s: String = lines[k]
		var w := narrow_reg.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var pos := Vector2(INSCRIPTION_C.x - w / 2.0, INSCRIPTION_C.y + k * (sz + 8))
		Ink.handwriting(c, s, s.length(), pos + Vector2(1.5, 1.0), sz, 40 + k, false, Color(WIPED, 0.35 * a),
			narrow_reg, 0.04)
		Ink.handwriting(c, s, s.length(), pos, sz, 40 + k, false, Color(WIPED, 0.92 * a), narrow_reg, 0.04)

# ---------------------------------------------------------------------------
# drawing: close-ups (layer 5)
# ---------------------------------------------------------------------------
func _draw_close() -> void:
	match _view():
		"c_tilt_rack":
			_draw_rack(close)
		"c_balance":
			_draw_balance(close)
		"c_frame":
			_draw_frame(close)
		_:
			return
	if hold_t > 0.0 and hold_close.size != Vector2.ZERO:
		_brackets(close, hold_close)

# --- c_tilt_rack --------------------------------------------------------------------------
## A close-up jar's surface follows the same band rule as the room: at rest all three lie alike
## (jar A's resting slant); only the tip shows a jar's own rule, blended in with the cradle's
## turn so nothing jumps. From band 5 every jar leans to the vault (off to the right), at band 7
## faces her last click here. `rule_k` 0..1: how far into the tip the jar is.
func _close_theta(j: String, rot: float, centre: Vector2, rule_k := 0.0) -> float:
	match r.anomaly():
		"level":
			return 0.0
		"vault":
			return _leaning_deg(centre, VAULT_C_CLOSE)
		"ada":
			return _facing_deg(centre, close_ada)
	if rule_k <= 0.0:
		return R07Sim.rack_rest_deg(j)
	return lerpf(R07Sim.rack_rest_deg(j), R07Sim.surface_deg(R07Sim.JAR_RULE[j], rot), clampf(rule_k, 0.0, 1.0))

func _draw_rack(c: CanvasItem) -> void:
	var st: Dictionary = r.state
	_full(c, "c_tilt_rack")
	_on_plate(c, Rect2(120, 124, 110, 26), "DATUM", 18)
	_plumb(c, "c_plumb", C_PLUMB_PIVOT, Vector2(24, 4), 96.0)
	# station plates and the jars at rest
	for j in R07Sim.JARS:
		var sc: Vector2 = STATION[j]
		_on_plate(c, Rect2(sc.x - 56, 860, 112, 24), j, 20)
		if st.cradle == j or (j == "C" and st.socket == "C"):
			continue
		var rot := R07Sim.RACK_CANT_DEG
		_jar(c, "c_jar", CJAR_SPRITE_C, CJAR_HALF, CJAR_LABEL, sc, rot, _close_theta(j, rot, sc), j, 22, _ripple())
	# the cradle and its jar, turning through the tip
	var cj: String = st.cradle
	var phi := tip_deg() if (tip_t >= 0.0 and cj != "" and cj == tip_jar) else 0.0
	if cj != "":
		_jar(c, "c_jar", CJAR_SPRITE_C, CJAR_HALF, CJAR_LABEL, CRADLE_PIVOT, phi,
			_close_theta(cj, phi, CRADLE_PIVOT, phi / R07Sim.TIP_DEG), cj, 22, _ripple() if tip_t < 0.0 else 0.0)
	c.draw_set_transform(CRADLE_PIVOT, deg_to_rad(phi), Vector2.ONE)
	_sprite(c, "c_cradle", -CRADLE_SPRITE_C)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	if tip_t >= 0.0:
		_sprite(c, "c_lever_down", Vector2(720, 770))
	_plate(c, Rect2(722, 894, 126, 28), "TIP", 18)
	_plate(c, Rect2(862, 894, 166, 28), "SEAT IN SOCKET", 18)
	_draw_test_card(c)
	# the reference card
	_ctext(c, "REFERENCE", 1230, 150, 18, INK, narrow)
	c.draw_line(Vector2(1130, 160), Vector2(1330, 160), Color(INK, 0.5), 1.5)
	_para(c, R07Sim.REF_CARD, Vector2(1126, 188), 20, INK, 208, Ink.serif(), 1.25)
	# the socket: C seated after P10, and its tag
	if st.socket == "C":
		_jar(c, "c_jar", CJAR_SPRITE_C, CJAR_HALF, CJAR_LABEL, C_SOCKET, 0.0, _close_theta("C", 0.0, C_SOCKET, 1.0), "C",
			22, _ripple())
	if r.state.p10_complete and not pending.has("tag"):
		var rest := TAG_REST
		if tag_t >= 0.0:
			var k := smoothstep(0.0, 1.0, tag_t / TAG_SLIDE)
			rest.position.y = lerpf(790.0 - TAG_REST.size.y * 0.6, TAG_REST.position.y, k)
		var tt := _tex("c_tag")
		if tt:
			c.draw_texture_rect(tt, rest, false)
		_rtext(c, "TARGET 2", Rect2(rest.position + Vector2(34, 0), rest.size - Vector2(38, 0)), 22, INK, narrow_reg)

const REF_ANGLES := {"gravity": -8.0, "jar": 90.0, "datum": 0.0}
const REF_PATTERN := {"gravity": [], "jar": [12.0, 8.0], "datum": [16.0, 6.0, 3.0, 6.0]}
const REF_WORD := {"gravity": "GRAVITY", "jar": "JAR", "datum": "DATUM"}

func _ref_line(c: CanvasItem, box: Rect2, rule: String, col: Color, w: float) -> void:
	var ends := _line_in_box(box.get_center(), REF_ANGLES[rule], box.grow(-6))
	var pat: Array = REF_PATTERN[rule]
	if pat.is_empty():
		c.draw_line(ends[0], ends[1], col, w, true)
	else:
		_dashed(c, ends[0], ends[1], col, w, pat)

## The segment through `centre` at `deg` clipped to `box`.
static func _line_in_box(centre: Vector2, deg: float, box: Rect2) -> Array:
	var d := Vector2.from_angle(deg_to_rad(deg))
	var t := INF
	if absf(d.x) > 0.0001:
		t = minf(t, (box.size.x / 2.0) / absf(d.x))
	if absf(d.y) > 0.0001:
		t = minf(t, (box.size.y / 2.0) / absf(d.y))
	return [centre - d * t, centre + d * t]

func _draw_test_card(c: CanvasItem) -> void:
	_ctext(c, "TEST", 620, 138, 24, INK, narrow)
	# the legend: each line's own style, then its word
	var lx := 690.0
	for rule in ["gravity", "jar", "datum"]:
		var a := Vector2(lx, 131)
		var b := Vector2(lx + 44, 131)
		var pat: Array = REF_PATTERN[rule]
		if pat.is_empty():
			c.draw_line(a, b, INK, 2.5)
		else:
			_dashed(c, a, b, INK, 2.5, pat)
		c.draw_string(narrow, Vector2(lx + 52, 138), REF_WORD[rule], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
		lx += 128.0
	var cells := test_cell_texts()
	for k in 3:
		var j: String = R07Sim.JARS[k]
		var box := Rect2(TEST_BOX_X[k], TEST_BOX_Y, TEST_BOX.x, TEST_BOX.y)
		for rule in ["gravity", "jar", "datum"]:
			_ref_line(c, box, rule, Color(INK, 0.6), 2.0)
		c.draw_rect(Rect2(box.position + Vector2(6, 6), Vector2(28, 28)), PAPER_HI)
		c.draw_rect(Rect2(box.position + Vector2(6, 6), Vector2(28, 28)), INK, false, 1.5)
		_ctext(c, cells[k], box.position.x + 20, box.position.y + 28, 20, INK, narrow)
		# the pen draws the surface the tipped jar showed, one plain heavy line: which printed
		# line it lies on is for her to see
		var deg := test_surface_deg(j)
		if not is_nan(deg):
			var ends := _line_in_box(box.get_center(), deg, box.grow(-6))
			c.draw_line(ends[0], ends[1], INK, 4.5, true)

## Every string drawn inside the test cells, in cell order: the jar letters, nothing else.
func test_cell_texts() -> Array:
	return R07Sim.JARS.duplicate()

## The pen line in jar `j`'s test cell (degrees, as REF_ANGLES), or NAN while untested.
func test_surface_deg(j: String) -> float:
	if not r.state.tested[j] or pen_jar == j:
		return NAN
	return REF_ANGLES[R07Sim.JAR_RULE[j]]

# --- c_balance ----------------------------------------------------------------------------
func _beam_end(sign_: float) -> Vector2:
	return BEAM_PIVOT + Vector2(sign_ * BEAM_ARM, 0).rotated(deg_to_rad(beam_deg))

## Every sample is the same opaque stoppered tube: only its stand's number tells them apart.
func _sample_sprite(c: CanvasItem, _s: String, bottom_centre: Vector2) -> void:
	_sprite(c, "c_sample_tube", bottom_centre - Vector2(45, 116))

func _draw_balance(c: CanvasItem) -> void:
	var st: Dictionary = r.state
	var p13: bool = st.p13_complete
	_full(c, "c_balance")
	_draw_sample_cards(c)
	# the beam, its pan and the control tray, hung plumb from its ends
	var bt := _tex("c_beam")
	if bt:
		c.draw_set_transform(BEAM_PIVOT, deg_to_rad(beam_deg), Vector2.ONE)
		c.draw_texture(bt, Vector2(-350, -30))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
	var le := _beam_end(-1.0)
	var re := _beam_end(1.0)
	_sprite(c, "c_pan", le - Vector2(110, 6))
	_sprite(c, "c_tray", re - Vector2(110, 6))
	var ta := thumb_alpha()
	if ta > 0.0:
		_sprite(c, "c_thumb", re + Vector2(0, 257) - Vector2(60, 32), ta)
	if not r.beam_unlocked():
		_sprite(c, "c_pin", Vector2(718, 300))
	# samples: on their stands, or on the pan
	for s in R07Sim.SAMPLE_ORDER:
		var x0: float = STANDS[s]
		_ctext(c, R07Sim.SPECIMEN[s], x0 + 55, 808, 16, INK, narrow)
		if st.pan == s:
			_sample_sprite(c, s, le + Vector2(0, 252))
		else:
			_sample_sprite(c, s, Vector2(x0 + 55, 780))
	# the gauge: 0 until the stair circuit gives it pressure, then 2
	for v in [0, 2]:
		# set just clockwise of its tick, so the needle never covers its own figure
		var a := deg_to_rad(-145.0 + 22.0 * v + 11.0)
		_ctext(c, str(v), GAUGE_C.x + 40 * cos(a), GAUGE_C.y + 40 * sin(a) + 6, 16, INK, narrow)
	var nt := _tex("c_needle")
	if nt:
		c.draw_set_transform(GAUGE_C, deg_to_rad(-55.0 + 22.0 * r.gauge_value()), Vector2(0.5, 0.5))
		c.draw_texture(nt, Vector2(-6, -114))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
	# keys
	for id in KEY_X:
		var x0: float = KEY_X[id]
		var down: bool = key_down == id and key_down_t > 0.0
		if down:
			_sprite(c, "c_key_down", Vector2(x0, 680))
		_ctext(c, KEY_WORD[id], x0 + 70, 721 + (20 if down else 0), 18, INK, narrow)
	_draw_strip(c)
	_draw_register(c)

func _draw_sample_cards(c: CanvasItem) -> void:
	for k in 3:
		var x0 := 90.0 + k * 96
		var cx := x0 + 42
		var sm: String = R07Sim.SAMPLE_ORDER[k]
		_ctext(c, R07Sim.SPECIMEN[sm], cx, 129, 17, INK, narrow)
		var stamp := Rect2(cx - 37, 133, 74, 42)
		c.draw_rect(stamp, PAPER_HI)
		c.draw_rect(stamp, BRUISE, false, 2.0)
		_ctext(c, "SPECIMEN", cx, 159, 14, BRUISE, narrow_reg)

func _draw_strip(c: CanvasItem) -> void:
	var cells := r.strip_cells()
	var heads := ["UNATTENDED", "ADDRESSED", "RELEASED"]
	for k in 3:
		var cx := STRIP_X0 + k * 98 + 46
		_ctext(c, heads[k], cx, 684, 16, INK, narrow_reg)
		if cells[k] != "":
			_ctext(c, cells[k], cx, 730, 26, INK, Ink.serif())
	var note := r.strip_note()
	if note != "":
		_ctext(c, note, 1240, 782, 18, INK, narrow)

func _draw_register(c: CanvasItem) -> void:
	var st: Dictionary = r.state
	for k in R07Sim.NAMES.size():
		var n: String = R07Sim.NAMES[k]
		var tx := 120.0 + 150 * k
		if (n == "BELL" and st.p13_complete) or st.holder == n:
			continue
		_sprite(c, "c_card", Vector2(tx, 836))
		_ctext(c, n, tx + 70, 836 + 50, 22, INK, narrow)
	var h: String = st.holder
	if h == "":
		return
	_sprite(c, "c_card", Vector2(654, 403))
	_ctext(c, h, 724, 403 + 50, 22, INK, narrow)
	# the card read out at full size on the slip beside the balance
	var slip := HOLDER_SLIP
	c.draw_rect(Rect2(slip.position + Vector2(5, 6), slip.size), Color(0.1, 0.1, 0.1, 0.25))
	c.draw_rect(slip, PAPER_HI)
	c.draw_rect(slip, INK, false, 2.0)
	_ctext(c, "IN THE HOLDER", slip.get_center().x, slip.position.y + 24, 16, INK, narrow)
	c.draw_line(slip.position + Vector2(12, 32), Vector2(slip.end.x - 12, slip.position.y + 32), Color(INK, 0.5), 1.4)
	var y := _para(c, R07Sim.REGISTER[h], slip.position + Vector2(14, 56), 18, INK, slip.size.x - 28)
	y = _para(c, R07Sim.NO_EFFECTS, Vector2(slip.position.x + 14, y), 18, INK, slip.size.x - 28)
	c.draw_string(narrow, Vector2(slip.position.x + 14, y + 2), R07Sim.STAMP_ALL, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		BRUISE)

# --- c_frame ------------------------------------------------------------------------------
func _trace_pts(shape: String, x0: float, x1: float, y_base: float, y_top: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for q in SHAPES[shape]:
		pts.append(Vector2(lerpf(x0, x1, q.x), lerpf(y_base, y_top, q.y)))
	return pts

func _section_rect(slot_x: float, y: float) -> Rect2:
	return Rect2(slot_x + 10, y, SECTION.x, SECTION.y)

func _draw_section(c: CanvasItem, s: String, rect: Rect2, raised: bool) -> void:
	if raised:
		rect.position.y -= 8
	var t := _tex("c_section")
	if t:
		c.draw_texture_rect(t, rect, false)
	if raised:
		c.draw_rect(rect.grow(3), INK, false, 3.0)
	# no label: the bare piece of her trace, at twice the work card's scale, on a faint baseline
	var base := rect.end.y - 44.0
	c.draw_line(Vector2(rect.position.x + 14, base), Vector2(rect.end.x - 14, base), Color(INK, 0.35), 1.5)
	c.draw_polyline(section_pts(s, rect), INK, 3.0, true)

## A section's trace: its piece of the kitchen work card's trace (R05, card px) at CARD_SCALE,
## centred on the tile, baseline 44 px above its bottom.
func section_pts(s: String, rect: Rect2) -> PackedVector2Array:
	var piece: Array = CARD_PIECES[s]
	var x0: float = piece[0].x
	var x1: float = piece[-1].x
	var o := Vector2(rect.get_center().x - (x1 - x0) * CARD_SCALE / 2.0, rect.end.y - 44.0)
	var pts := PackedVector2Array()
	for q in piece:
		pts.append(o + Vector2((q.x - x0) * CARD_SCALE, (q.y - CARD_BASE) * CARD_SCALE))
	return pts

func _draw_frame(c: CanvasItem) -> void:
	var st: Dictionary = r.state
	_full(c, "c_frame")
	# the reference: her work card's trace, or a note that it is still in the kitchen
	c.draw_string(narrow, Vector2(180, 146), REF_HEADING, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	if r.reference_seen():
		for k in 3:
			var x0: float = SLOT_X[k] + 16
			c.draw_polyline(_trace_pts(R07Sim.SOLUTION_SLOTS[k], x0, x0 + SECTION.x - 12, REF_TRACE_BOTTOM,
				REF_TRACE_TOP), INK, 3.0, true)
	else:
		_ctext(c, REF_UNSEEN, 725, 226, 22, INK, Ink.serif())
	# the slots and what is in them
	for k in 3:
		var s: String = st.slots[k]
		if s != "":
			_draw_section(c, s, _section_rect(SLOT_X[k], 390), r.held == s)
	for k in r.frame_miss:
		_dashed_rect(c, Rect2(SLOT_X[k] - 4, 366, 368, 208), INK, 3.0)
		if r.reference_seen():
			_dashed_rect(c, Rect2(SLOT_X[k] + 4, 158, 352, 118), INK, 3.0)
	# the tray
	var tray := r.tray_sections()
	for k in tray.size():
		if tray[k] != "":
			_draw_section(c, tray[k], _section_rect(TRAY_RECTS[k].position.x, 725), r.held == tray[k])
	# name tab, strip clip, the printed label
	if st.name_tab:
		_sprite(c, "c_name_tab", Vector2(180, 594))
		var hs := "BELL, N."
		Ink.handwriting(c, hs, hs.length(), Vector2(266, 640), 30, 7, false, Ink.BLUE_INK)
	if st.strip_clipped:
		_sprite(c, "c_strip", Vector2(560, 594))
		for k in 3:
			_ctext(c, ["0 dr", "3 dr", "0 dr"][k], 560 + 2 + 112 * k + 56, 638, 22, INK, Ink.serif())
	_on_plate(c, Rect2(940, 596, 340, 64), "CATEGORY: " + R07Sim.CATEGORY, 22)
	if st.p14_complete:
		_sprite(c, "c_frame_glass", Vector2(140, 340))
	var down := seal_t > 0.0
	if down:
		_sprite(c, "c_seal_down", Vector2(1290, 740))
	_ctext(c, "SEAL", 1360, 794 + (28 if down else 0), 18, INK, narrow)
	_ctext(c, "FRAME", 1360, 814 + (28 if down else 0), 18, INK, narrow)
