extends RoomView
## R05, the Kitchen and Mess: renderer. Presents R05Sim (game/rooms/R05/R05_sim.gd) and never
## mutates it. Everything timed here (the spoon beat, the board swing and fog, the card's breath,
## the tape feed, page turns, holds, loop fades) is presentation and is never saved: a load lands
## in view A with every overlay snapped to state.
##
## Layering:
##   `room` (world layer 0, under the CanvasModulate `shade`): the stage plate of view A (the mess
##          table) or view B (the kitchen), the painted overlays and every code-drawn label.
##          Two children draw over it: `glow` (additive: a_warm_b7, b_range_glow) and `top`
##          (turn chevrons, the lectern pencil, the motion-off hold outline).
##   CanvasLayer 5 `close`: the close-ups c_table, c_ledger and c_service_board.
##
## Painted plates: assets/rooms/R05/*.png (tools/art/rooms/R05.py). The plates carry no text: every
## initial, numeral, name, page line and label is drawn here so the clues stay exact.

const DIR := "res://assets/rooms/R05/%s.png"

const PAPER := Color("ded4ba")
const PAPER_HI := Color("e8e1cf")
const INK := Color("172b36")
const NAVY := Color("22384a")
const PENCIL := Color(0.30, 0.31, 0.34)
const WET_INK := Color("0e1b23")
const SHADOW := Color("261e16")

## [id, rect, label]; first match wins, so small objects come first. View A, the mess.
const HOTSPOTS := [
	["spoon", Rect2(1262, 540, 64, 64), "His spoon"],
	["unsigned_bowl", Rect2(40, 404, 104, 66), "Unsigned bowl"],
	["tally", Rect2(170, 604, 96, 96), "Serving tally"],
	["towel", Rect2(166, 516, 104, 72), "Nora's towel"],
	["window", Rect2(560, 110, 340, 190), "High window"],
	["place_1", Rect2(278, 500, 104, 196), "Place 1"],
	["place_2", Rect2(390, 500, 104, 196), "Place 2"],
	["place_3", Rect2(502, 500, 104, 196), "Place 3"],
	["place_4", Rect2(614, 500, 104, 196), "Place 4"],
	["place_5", Rect2(726, 500, 104, 196), "Place 5"],
	["place_6", Rect2(838, 500, 104, 196), "Place 6"],
	["place_7", Rect2(950, 500, 104, 196), "Place 7"],
	["place_8", Rect2(1062, 500, 104, 196), "Place 8"],
	["place_9", Rect2(1174, 500, 104, 196), "Place 9, by the door"],
	["place_10", Rect2(164, 704, 108, 176), "Place 10, by the rack"],
	["bowl_stack", Rect2(30, 474, 124, 190), "Bowl rack"],
	["chair", Rect2(1176, 700, 156, 200), "His chair"],
	["to_kitchen", Rect2(1352, 330, 80, 130), "Kitchen ▸"],
]
## View B, the kitchen.
const KITCHEN_HOTSPOTS := [
	["work_card", Rect2(40, 300, 110, 150), "Work card"],
	["menu_note", Rect2(40, 500, 110, 140), "Menu"],
	["kettle", Rect2(250, 300, 130, 110), "Kettle"],
	["ledger", Rect2(700, 520, 200, 150), "Nora's book"],
	["service_drawer", Rect2(990, 600, 290, 110), "Service drawer"],
	["service_hatch", Rect2(1316, 560, 120, 320), "Service hatch"],
	["shift_board", Rect2(960, 140, 340, 380), "Shift board"],
	["range", Rect2(170, 440, 400, 420), "Range"],
	["to_mess", Rect2(30, 720, 100, 140), "◂ Mess"],
]
## The hatch exits lead down to the lower passage.
const EXIT_ARROWS := {"R07": "down", "R08": "down"}
const EXIT_RECTS := {
	"R02": Rect2(20, 922, 250, 64),
	"R07": Rect2(282, 922, 250, 64),
	"R08": Rect2(544, 922, 250, 64),
	"R06": Rect2(806, 922, 250, 64),
}

## Close-up controls: [id, rect, hover label].
const TABLE_CONTROLS := [
	["place_1", Rect2(130, 170, 124, 200), "Place 1"],
	["place_2", Rect2(266, 170, 124, 200), "Place 2"],
	["place_3", Rect2(402, 170, 124, 200), "Place 3"],
	["place_4", Rect2(538, 170, 124, 200), "Place 4"],
	["place_5", Rect2(674, 170, 124, 200), "Place 5"],
	["place_6", Rect2(810, 170, 124, 200), "Place 6"],
	["place_7", Rect2(946, 170, 124, 200), "Place 7"],
	["place_8", Rect2(1082, 170, 124, 200), "Place 8"],
	["place_9", Rect2(1226, 200, 112, 280), "Place 9, by the door"],
	["place_10", Rect2(118, 384, 136, 182), "Place 10, by the rack"],
	["slot_0", Rect2(110, 640, 104, 150), "Rack"],
	["slot_1", Rect2(222, 640, 104, 150), "Rack"],
	["slot_2", Rect2(334, 640, 104, 150), "Rack"],
	["slot_3", Rect2(446, 640, 104, 150), "Rack"],
	["slot_4", Rect2(558, 640, 104, 150), "Rack"],
	["slot_5", Rect2(670, 640, 104, 150), "Rack"],
	["slot_6", Rect2(782, 640, 104, 150), "Rack"],
	["slot_7", Rect2(894, 640, 104, 150), "Rack"],
	["slot_8", Rect2(1006, 640, 104, 150), "Rack"],
	["tally_down", Rect2(1140, 740, 72, 64), "Tally ◂"],
	["tally_up", Rect2(1218, 740, 72, 64), "Tally ▸"],
	["look_register", Rect2(1300, 600, 130, 100), "Register plate"],
	["compare", Rect2(1310, 712, 120, 200), "COMPARE"],
]
const LEDGER_CONTROLS := [
	["left_page", Rect2(150, 110, 560, 770), "Left page"],
	["right_page", Rect2(738, 110, 560, 770), "Right page"],
	["page_prev", Rect2(150, 900, 150, 72), "◂ Page"],
	["page_next", Rect2(1148, 900, 150, 72), "Page ▸"],
]
const BOARD_CONTROLS := [
	["tile_0", Rect2(50, 140, 210, 66), "BELL"],
	["tile_1", Rect2(50, 216, 210, 66), "DOANE"],
	["tile_2", Rect2(50, 292, 210, 66), "HART"],
	["tile_3", Rect2(50, 368, 210, 66), "IVES"],
	["tile_4", Rect2(50, 444, 210, 66), "LUSK"],
	["tile_5", Rect2(50, 520, 210, 66), "MERCER"],
	["tile_6", Rect2(50, 596, 210, 66), "PRYCE"],
	["tile_7", Rect2(50, 672, 210, 66), "ROOK"],
	["tile_8", Rect2(50, 748, 210, 66), "TULL"],
	["tile_9", Rect2(50, 824, 210, 66), "VENN"],
	["count_down", Rect2(700, 616, 72, 68), "PRESENT ◂"],
	["look_count", Rect2(788, 604, 100, 90), "PRESENT"],
	["count_up", Rect2(904, 616, 72, 68), "PRESENT ▸"],
	["f_count", Rect2(320, 730, 150, 96), "Amend: count"],
	["f_name", Rect2(490, 730, 330, 96), "Amend: name"],
	["f_status", Rect2(840, 730, 210, 96), "Amend: status"],
	["look_rule", Rect2(300, 850, 760, 110), "Placard"],
	["socket_pantry", Rect2(1110, 140, 140, 190), "Socket, pantry half"],
	["socket_bunk", Rect2(1260, 140, 140, 190), "Socket, bunk half"],
	["socket_turn", Rect2(1205, 340, 100, 90), "Turn the socket"],
	["seal_1", Rect2(1100, 480, 96, 130), "Seal |"],
	["seal_2", Rect2(1202, 480, 96, 130), "Seal ||"],
	["seal_3", Rect2(1304, 480, 96, 130), "Seal |||"],
	["stamp", Rect2(1110, 676, 290, 180), "STAMP"],
]
## Only after P09: the second board behind the first.
const BOARD_CONTROLS_AFTER := [
	["look_duplicate", Rect2(340, 100, 720, 620), "Rook's board, on hinges"],
]

## Base levels for one-shots (dB), and the sudden ones "Soften sudden sounds" turns down.
const SFX_DB := {"bowl_lift": -14.0, "bowl_set": -12.0, "bowl_rack": -13.0, "tally_click": -14.0,
	"compare_pull": -8.0, "flag_flip": -14.0, "drawer_unlatch": -12.0, "drawer_slide": -10.0,
	"spoon_lift": -22.0, "spoon_china": -16.0, "book_open": -12.0, "page_turn": -12.0,
	"tile_flip": -14.0, "tile_seat": -12.0, "tile_lift": -14.0, "count_reset": -10.0,
	"token_seat": -10.0, "token_pull": -12.0, "socket_turn": -9.0, "socket_jam": -11.0,
	"seal_click": -13.0, "stamp_thud": -6.0, "stamp_locked": -11.0, "reject_tape": -12.0,
	"board_hinge": -9.0, "pencil_copy": -14.0, "fog_creep": -12.0, "hatch_unlatch": -7.0,
	"kettle_tick": -16.0, "card_flutter": -18.0, "steam_wisp": -20.0, "chair_scrape": -13.0,
	"towel_drip": -15.0}
const SFX_SOFT := ["compare_pull", "drawer_unlatch", "count_reset", "socket_jam", "stamp_thud",
	"board_hinge", "hatch_unlatch"]

const LOOPS := ["r05_room", "r05_rain", "r05_rain_heavy", "r05_kettle", "r05_draught",
	"r05_draught_breath", "r05_range"]
const LOOP_RATE := 0.11        # linear units / s
const BREATH_LEN := 5.2        # r05_draught_breath: rises 0-0.35, 0.5-0.85, 1.6-3.6, then rest
const FOG_DUCK := 0.3          # r05_room and r05_rain under the fog's creep
const FOG_RESTORE := 2.0

## Interior luminance per weather band: a slight cool shift that never drops below 0.88.
const TINT_LUM := [1.0, 1.0, 0.975, 0.955, 0.94, 0.925, 0.91, 0.90]

## Arrival holds: focus rects.
const HOLD_TIME := 1.5
const HOLD_ZOOM := 0.06
const NOTICE_FOCUS := {
	"inward": Rect2(278, 480, 1060, 220),
	"soup": Rect2(1174, 500, 104, 196),
	"chair": Rect2(1170, 450, 270, 450),
	"towel": Rect2(160, 516, 120, 80),
	"card_breath": Rect2(40, 300, 110, 150),
	"fog_wiped": Rect2(950, 130, 360, 400),
	"warm_range": Rect2(170, 440, 400, 420),
}
const NOTICE_SIDE := {"inward": "a", "soup": "a", "chair": "a", "towel": "a",
	"card_breath": "b", "fog_wiped": "b", "warm_range": "b"}

# view A geometry -------------------------------------------------------------------------------
const RAIN_AT := Vector2(560, 110)
const RAIN_SIZE := Vector2(340, 190)
const STACK_SHELF := 660.0
const BOWL_BASE_Y := 590.0
const PATCH_Y := 648.0
## a_spoon_dark (70x28) rests on its bottom edge in the place-9 dent (cloth top y 590).
const SPOON_AT := Vector2(1246, 563)
const TOWEL_AT := Vector2(166, 550)
const TOWEL_WET_AT := Vector2(162, 522)
const RING_AT := Vector2(236, 582)
const RING_AMBER_AT := Vector2(224, 576)
const RING_WISP_AT := Vector2(224, 488)
const RING_CENTRE := Vector2(256, 588)
const TALLY_WIN := Rect2(196, 630, 48, 40)
const SPOON_RISE := 36.0
const CHAIR_TUCKED_AT := Vector2(1172, 452)
const SEAT9_AT := Vector2(1176, 740)
const CHAIR_PULLED_AT := Vector2(1162, 610)
const SOUP_AT := Vector2(1178, 526)
const KETTLE_SPOUT := Vector2(255, 346)
const BOOK_BLANK_AT := Vector2(690, 468)
const BOARD_BACK_AT := Vector2(782, 130)

# view B geometry -------------------------------------------------------------------------------
const CARD_AT := Vector2(40, 300)
const CARD_NAIL := Vector2(95, 306)
## Breath windows of r05_draught_breath (s) and the card's lift in each (degrees).
const BREATH := [[0.0, 0.35, 4.0], [0.5, 0.85, 4.0], [1.6, 3.6, 7.0]]
const VB_BOARD_STRIPS_Y := 200.0
const VB_BOARD_STRIP_DY := 34.0

# c_table geometry ------------------------------------------------------------------------------
## Plan bowl centres registered to the painted mats (tools/art/rooms/R05.py BOWL_PLAN).
const MAT_X0 := 130.0
const MAT_DX := 136.0
const PLAN_Y := 258.0
const PLAN_9 := Vector2(1282, 340)
const DENT_9 := Rect2(1265, 232, 34, 96)
const RACK_Y := 715.0
const LIFT := 40.0

# c_service_board geometry ----------------------------------------------------------------------
const BOARD_RECT := Rect2(300, 100, 760, 600)
const BOARD_HINGE_X := 300.0
const SWUNG_AT := Vector2(300, 100)
const FOG_AT := Vector2(340, 100)
const FOG_ROWS := 6
const FOG_ROW_H := 103.0
const FOG_ROW_T := 0.8
const SEAL_X := [1148.0, 1250.0, 1352.0]
## The amendment row on the front board, under TULL, and the stamp ink it is struck in.
const STRIP_RECT := Rect2(336, 570, 420, 36)
const STAMP_INK := Color("8a3b2a")
const ROOK_BROWN := Color("5b3a24")
const SLANT := 0.22
const WELL_IDS := ["f_count", "f_name", "f_status"]

# P07's second blank and the door end (tools/art/rooms/R05.py PLACE10_A / PLACE10_C)
const PLACE10_A := Vector2(218, 772)
const PLACE10_C := Vector2(186, 470)

# glances: a reward seen in the room view, from a close-up
const GLANCE_RISE := 0.6
const GLANCE_HOLD := 2.5
const GLANCE_DROP := 0.25
const GLANCE_SPOON_LIFT := 18.0
const GLANCE_HATCH_LEN := 2.6
## a_window_eye_b7v2's upper lid (tools/art/rooms/R05.py eye_lids()): its 1 px drift every 6 s.
const LID_P0 := Vector2(456, 214)
const LID_P1 := Vector2(730, 96)
const LID_P2 := Vector2(1004, 214)
const GLASS := Rect2(576, 126, 308, 166)
const LID_PERIOD := 6.0

# P07 / P09 beat timings (s after the click)
const P07_FLAGS := 0.3
const P07_RISE := 3.6
const P07_DOWN := 6.0
const P07_DOWN_END := 6.4
const LIFT_RISE := 0.4
const LIFT_DOWN := 2.2
const LIFT_DOWN_END := 2.6
const P09_SWING := 2.6         # board_hinge: the stamped strip reads first
const P09_SWING_LEN := 0.8
const P09_FOG := 8.0
const P09_END := P09_FOG + FOG_ROWS * FOG_ROW_T

var r: R05Sim:
	get:
		return sim as R05Sim

var textures := {}
var mono: SystemFont
var narrow: SystemFont
var narrow_plain: SystemFont
var room: Node2D
var glow: Node2D
var top: Node2D
var close: Node2D
var shade: CanvasModulate
var mixer: LoopMixer

# presentation state (never saved)
var hold_t := 0.0
var hold_rect := Rect2()
var hold_side := ""
var zoom_k := 0.0
var spoon_t0 := -1.0
var spoon_beat := [0.0, 0.0, 0.0]   # rise, down, down end
var compare_t0 := -1.0
var flags_shown := {"places": "", "portions": ""}
var lever_t := 0.0
var stamp_t := 0.0
var drawer_t := 1.0                  # 0..1 the drawer sliding out
var reveal_t0 := -1.0
var tape_t0 := -1.0
var count_flip_at := -1.0
var shown_count := 8
var shown_spread := 0
var turn_t := 0.0
var turn_dir := 1
var fog_duck := 1.0
var dup_open := false                # the close-up's front board swung open (presentation)
var swing_v := 0.0
var home_t0 := -1.0                  # the eight bowls setting themselves
var home_list: Array = []
var glance_armed := {}               # glance id -> room-view rect, waiting for its cue
var glance_id := ""
var glance_rect := Rect2()
var glance_t0 := -1.0
var glance_dropped := false
var glance_wait := {}                # glance id -> deadline: cued, waiting for its line to show

func _ready() -> void:
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Liberation Mono", "Noto Mono", "monospace"])
	narrow = SystemFont.new()
	narrow.font_names = PackedStringArray(["Liberation Sans Narrow", "Nimbus Sans Narrow", "DejaVu Sans Condensed", "sans-serif"])
	narrow.font_weight = 700
	narrow_plain = SystemFont.new()
	narrow_plain.font_names = narrow.font_names
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
	glow = Node2D.new()
	glow.name = "Glow"
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	room.add_child(glow)
	glow.draw.connect(_draw_glow)
	top = Node2D.new()
	top.name = "Top"
	room.add_child(top)
	top.draw.connect(_draw_top)
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

## "a" (the mess: room, c_table) or "b" (the kitchen: kitchen, c_ledger, c_service_board).
func _side() -> String:
	if glance_active():
		return "a" if glance_id == "p07_spoon" else "b"
	return "a" if _view() in ["room", "c_table"] else "b"

func _closeup() -> bool:
	return r.is_closeup()

func plate_a() -> String:
	var s := r.plate_stage()
	return "view_a" if s == "b0" else "view_a_" + s

func plate_b() -> String:
	var s := r.plate_stage()
	return "view_b" if s == "b0" else "view_b_" + s

## The interior tint: white at bands 0-1, then a slight cool shift; luminance never below 0.88.
func tint_color() -> Color:
	if r.ending() == "sever":
		return Color(1, 1, 1)
	var v: float = TINT_LUM[_band()]
	if v >= 1.0:
		return Color(1, 1, 1)
	return Color(v * 0.975, v * 0.99, minf(1.0, v * 1.01))

func close_tint() -> Color:
	if r.ending() != "sever" and _band() >= 5:
		return Color(0.955, 0.96, 0.97)
	return Color(1, 1, 1)

## The rain sprite on the window glass, or "".
func rain_id() -> String:
	var e := r.ending()
	if e == "sever":
		return "a_rain_1"
	if e == "continue":
		return ""
	var b := _band()
	if b <= 1:
		return "a_rain_1"
	if b == 2:
		return "a_rain_2"
	if b <= 6:
		return "a_rain_still"
	return ""

func rain_speed() -> float:
	if not motion:
		return 0.0
	return 40.0 if _band() <= 2 or r.ending() == "sever" else 0.0   # band 3-6: hanging, not falling

## 0..1: how far the spoon is lifted off the cloth now.
func spoon_raise() -> float:
	var k := 0.0
	if spoon_t0 >= 0.0:
		var t := time - spoon_t0
		var rise: float = spoon_beat[0]
		var down: float = spoon_beat[1]
		var down_end: float = spoon_beat[2]
		if motion:
			if t >= rise and t < down_end:
				if t < rise + 0.3:
					k = smoothstep(0.0, 1.0, (t - rise) / 0.3)
				elif t < down:
					k = 1.0
				else:
					k = 1.0 - smoothstep(0.0, 1.0, (t - down) / (down_end - down))
		else:
			k = 1.0 if t >= rise and t < down_end else 0.0   # one still frame, clearly raised
	if r.spoon_raised_still():
		k = maxf(k, 0.3)
	return k

## Seconds into the P09 reveal, or -1.
func reveal_t() -> float:
	if reveal_t0 < 0.0 or not r.state.p09_complete:
		return -1.0
	var t := time - reveal_t0
	return t if t < P09_END + FOG_RESTORE else -1.0

## 0..1: the original board swung away on its hinge (eased in tick()).
func swing_k() -> float:
	return swing_v if r.board_swung() else 0.0

## Where the front board wants to be: shut (its stamped strip showing) unless the reveal has
## swung it or the player has opened it.
func swing_target() -> float:
	if not r.board_swung():
		return 0.0
	var t := reveal_t()
	if t >= 0.0:
		return 1.0 if t >= P09_SWING else 0.0
	return 1.0 if dup_open else 0.0

## Rows of the fog revealed (0..FOG_ROWS, fractional with motion) while the reveal plays; -1 after.
func fog_rows() -> float:
	var t := reveal_t()
	if t < 0.0:
		return -1.0
	if t < P09_FOG:
		return 0.0
	if not motion:
		return float(FOG_ROWS)
	return clampf((t - P09_FOG) / FOG_ROW_T, 0.0, float(FOG_ROWS))

func fog_creeping() -> bool:
	var t := reveal_t()
	return t >= P09_FOG and t < P09_END

## Band 6 on: the card has come off its nail and hangs in the air at a slant (a still pose, so
## the breath reads with Motion off too).
func card_off_nail() -> bool:
	return r.card_breathing() and _band() >= 6

## The card's lift (degrees) now, synced to r05_draught_breath when it is playing.
func card_angle() -> float:
	if not r.card_breathing():
		return 0.0
	var base := 14.0 if card_off_nail() else 0.0
	if not motion:
		return maxf(base, 9.0)
	return base + _breath_angle()

func _breath_angle() -> float:
	var ph := fposmod(time, BREATH_LEN)
	if mixer and mixer.players.has("r05_draught_breath"):
		var p: AudioStreamPlayer = mixer.players["r05_draught_breath"]
		if p.playing:
			ph = fposmod(p.get_playback_position(), BREATH_LEN)
	for w in BREATH:
		if ph >= w[0] and ph < w[1]:
			return float(w[2]) * sin(PI * (ph - w[0]) / (w[1] - w[0]))
	return 0.0

func _bowl_initials(b: String) -> String:
	return str(R05Sim.BOWL_INITIALS.get(b, ""))

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------
func tick(dt: float) -> void:
	if hold_t > 0.0:
		hold_t = maxf(0.0, hold_t - dt)
	var zt := 1.0 if hold_t > 0.0 and motion and not _closeup() else 0.0
	zoom_k = move_toward(zoom_k, zt, dt * 2.5)
	var s := 1.0 + HOLD_ZOOM * smoothstep(0.0, 1.0, zoom_k)
	room.scale = Vector2(s, s)
	room.position = hold_pivot() * (1.0 - s)
	lever_t = maxf(0.0, lever_t - dt)
	stamp_t = maxf(0.0, stamp_t - dt)
	drawer_t = minf(1.0, drawer_t + dt / 0.4) if motion else 1.0
	turn_t = maxf(0.0, turn_t - dt)
	if r.ledger_spread != shown_spread:
		turn_dir = 1 if r.ledger_spread > shown_spread else -1
		shown_spread = r.ledger_spread
		turn_t = 0.35 if motion else 0.0
	if count_flip_at < 0.0 or time >= count_flip_at + 0.15:
		shown_count = int(r.state.board_count)
		if count_flip_at >= 0.0 and time >= count_flip_at + 0.3:
			count_flip_at = -1.0
	if compare_t0 < 0.0 or time - compare_t0 >= P07_FLAGS:
		flags_shown = r.last_compare.duplicate()
	var st := swing_target()
	swing_v = move_toward(swing_v, st, dt / P09_SWING_LEN) if motion else st
	_tick_glance()
	shade.color = tint_color()
	close.modulate = close_tint()
	var dt_target := FOG_DUCK if fog_creeping() else 1.0
	fog_duck = dt_target if dt_target < fog_duck else move_toward(fog_duck, 1.0, dt * (1.0 - FOG_DUCK) / FOG_RESTORE)
	_tick_audio(dt)
	redraw()

func loop_targets() -> Dictionary:
	var b := _band()
	var e := r.ending()
	var kitchen := _side() == "b"
	var mess_k := 1.0 if kitchen else 0.5
	var out := {}
	for id in LOOPS:
		out[id] = 0.0
	out["r05_room"] = (0.35 if e == "sever" else 0.5) * fog_duck
	if r.rain_audible():
		var v := 0.45 if b <= 1 or e == "sever" else 0.5
		if kitchen or _closeup():
			v *= 0.6
		out["r05_rain"] = v * fog_duck
	if e == "" and (b == 2 or b == 3):
		out["r05_rain_heavy"] = 0.35
	if r.kettle_ticking():
		out["r05_kettle"] = 0.3 * mess_k
	if r.hatch_open() and b >= 2 and b <= 4 and e == "":
		out["r05_draught"] = 0.4 * mess_k
	if r.card_breathing():
		out["r05_draught_breath"] = 0.45
	if r.range_lit():
		out["r05_range"] = 0.4 * mess_k
	return out

func _tick_audio(dt: float) -> void:
	var rates := {}
	for id in LOOPS:
		rates[id] = LOOP_RATE
	if fog_creeping():
		rates["r05_room"] = 4.0
		rates["r05_rain"] = 4.0
	mixer.tick(loop_targets(), rates, dt)

# ---------------------------------------------------------------------------
# hooks
# ---------------------------------------------------------------------------
func play_fx(id: String, e: Dictionary) -> void:
	if id.begins_with("notice_"):
		_start_hold(id.substr(7))
		return
	match id:
		"p07_compare":
			compare_t0 = time
		"p07_agree":
			compare_t0 = time
		"glance":
			glance_armed[str(e.get("glance", ""))] = e.get("rect", Rect2())
		"bowls_home":
			home_t0 = time
			home_list = e.get("bowls", []).duplicate()
		"board_toggle":
			dup_open = not dup_open
		"board_open":
			dup_open = true
		"spoon_lift":
			spoon_t0 = time
			spoon_beat = [LIFT_RISE, LIFT_DOWN, LIFT_DOWN_END]
		"drawer_open":
			drawer_t = 0.0 if motion else 1.0
		"p09_reveal":
			reveal_t0 = time
			dup_open = true
		"reject":
			tape_t0 = time + 0.3
		"count_reset":
			count_flip_at = time + 1.0

func on_sfx(id: String) -> void:
	if id.begins_with("cue_"):
		_cue_glance(id.substr(4))
		return
	match id:
		"compare_pull":
			lever_t = 0.6
		"stamp_thud":
			stamp_t = 0.5

# ---------------------------------------------------------------------------
# glances: the room view, seen for a moment from a close-up
# ---------------------------------------------------------------------------
## Starts glance `id` (p07_spoon: the spoon at the door place lifts; p09_hatch: the kitchen's
## hatch stands open). The room view shows over the close-up while it plays. Idempotent.
func begin_glance(id: String) -> void:
	if glance_active() and glance_id == id:
		return
	glance_id = id
	glance_rect = glance_armed.get(id, R05Sim.P07_SPOON_RECT if id == "p07_spoon" else R05Sim.P09_HATCH_RECT)
	glance_t0 = time
	glance_dropped = false
	glance_armed.erase(id)
	hold_t = 0.0
	redraw()

## The chain line each glance belongs to: the glance starts when that line is on screen.
func _glance_line(id: String) -> String:
	return R05Sim.P07_SPOON_LINE if id == "p07_spoon" else R05Sim.P09_HATCH_LINE

## The silent cue arrived. If the line is up (or never comes within 4 s), the glance starts.
func _cue_glance(id: String) -> void:
	glance_wait[id] = time + 4.0
	_poll_glance()

func _poll_glance() -> void:
	for id in glance_wait.keys():
		var shown: bool = game != null and game.cur_text == _glance_line(id)
		if shown or time >= float(glance_wait[id]):
			glance_wait.erase(id)
			begin_glance(id)

## The core's glance hook (after the chain, close-up down). The room has already shown its
## reward on the chain line's cue (begin_glance), so the core draws no brackets of its own.
func start_glance(_target: String, _rect: Rect2) -> bool:
	return true

func glance_len() -> float:
	if glance_id == "p07_spoon":
		return GLANCE_RISE + GLANCE_HOLD + GLANCE_DROP + 0.5
	return GLANCE_HATCH_LEN

func glance_active() -> bool:
	return glance_t0 >= 0.0 and time - glance_t0 < glance_len()

## Seconds into the glance, or -1.
func glance_t() -> float:
	return time - glance_t0 if glance_active() else -1.0

## The door-place spoon's lift (px) during the p07 glance. Motion off: up, still, then flat.
func glance_spoon_lift() -> float:
	var t := glance_t()
	if t < 0.0 or glance_id != "p07_spoon":
		return 0.0
	if not motion:
		return GLANCE_SPOON_LIFT if t < GLANCE_HOLD else 0.0
	if t < GLANCE_RISE:
		return GLANCE_SPOON_LIFT * smoothstep(0.0, 1.0, t / GLANCE_RISE)
	if t < GLANCE_RISE + GLANCE_HOLD:
		return GLANCE_SPOON_LIFT
	return GLANCE_SPOON_LIFT * (1.0 - smoothstep(0.0, 1.0, (t - GLANCE_RISE - GLANCE_HOLD) / GLANCE_DROP))

func _tick_glance() -> void:
	if not glance_wait.is_empty():
		_poll_glance()
	var on := glance_active()
	close.visible = not on
	if not on:
		if glance_t0 >= 0.0 and not glance_dropped and glance_id == "p07_spoon":
			glance_dropped = true
			_play_own("spoon_china")
		if glance_t0 >= 0.0:
			glance_t0 = -1.0
			glance_id = ""
		return
	if glance_id == "p07_spoon" and not glance_dropped:
		var drop_at := GLANCE_HOLD if not motion else GLANCE_RISE + GLANCE_HOLD + GLANCE_DROP * 0.8
		if glance_t() >= drop_at:
			glance_dropped = true
			_play_own("spoon_china")

## A one-shot the view times itself (the glance's spoon landing), at the room's level.
func _play_own(id: String) -> void:
	if game == null:
		return
	var stream := game.load_audio(id)
	if stream == null:
		return
	var pl := AudioStreamPlayer.new()
	pl.stream = stream
	pl.volume_db = game.sfx_db(id)
	add_child(pl)
	pl.finished.connect(pl.queue_free)
	pl.play()

## The HUD's Back label: in the kitchen, Back goes to the mess.
func back_label() -> String:
	return "◂ Mess" if _view() == "kitchen" else "Back"

## The arrow an exit tab carries: the hatch exits go down.
func exit_arrow(to: String) -> String:
	return str(EXIT_ARROWS.get(to, ""))

func _start_hold(n: String) -> void:
	var rect: Rect2 = NOTICE_FOCUS.get(n, Rect2())
	if rect.size == Vector2.ZERO:
		return
	hold_rect = rect
	hold_side = NOTICE_SIDE.get(n, "a")
	hold_t = HOLD_TIME

## The point the arrival hold zooms about: the focus centre, pulled in just enough that a 56 px
## inset of the frame (exit chevrons, the work card, the bowl rack) stays on screen at full zoom.
func hold_pivot() -> Vector2:
	var sm := 1.0 + HOLD_ZOOM
	var m := 56.0
	var e := 16.0
	var c := hold_rect.get_center()
	var out := Vector2()
	for ax in 2:
		var full: float = SIZE[ax]
		var hi := (m * sm - e) / (sm - 1.0)
		var lo := ((full - m) * sm - (full - e)) / (sm - 1.0)
		out[ax] = clampf(c[ax], lo, hi) if lo <= hi else full / 2.0
	return out

func hold_active() -> bool:
	return hold_t > 0.0

## A hold belongs to the side it was raised on; leaving that side (or opening a close-up) ends it.
func on_view_changed(_before: String) -> void:
	if _view() == "c_service_board" and _before != "c_service_board" and reveal_t() < 0.0:
		dup_open = false
		swing_v = swing_target()
	if hold_t > 0.0 and (_closeup() or _side() != hold_side):
		hold_t = 0.0
	if hold_t <= 0.0:
		zoom_k = 0.0
		room.scale = Vector2.ONE
		room.position = Vector2.ZERO
	redraw()

func apply_instantly() -> void:
	shade.color = tint_color()
	close.modulate = close_tint()
	shown_count = int(r.state.board_count)
	shown_spread = r.ledger_spread
	flags_shown = r.last_compare.duplicate()
	drawer_t = 1.0
	fog_duck = 1.0
	swing_v = swing_target()
	room.scale = Vector2.ONE
	room.position = Vector2.ZERO
	zoom_k = 0.0
	if mixer:
		mixer.snap(loop_targets())

func reset_presentation() -> void:
	hold_t = 0.0
	hold_side = ""
	zoom_k = 0.0
	spoon_t0 = -1.0
	compare_t0 = -1.0
	lever_t = 0.0
	stamp_t = 0.0
	drawer_t = 1.0
	reveal_t0 = -1.0
	tape_t0 = -1.0
	count_flip_at = -1.0
	turn_t = 0.0
	fog_duck = 1.0
	dup_open = false
	swing_v = 0.0
	home_t0 = -1.0
	home_list = []
	glance_armed = {}
	glance_wait = {}
	glance_t0 = -1.0
	glance_id = ""
	glance_dropped = false
	if close:
		close.visible = true

func redraw() -> void:
	room.queue_redraw()
	glow.queue_redraw()
	top.queue_redraw()
	close.queue_redraw()

func back_visible() -> bool:
	return _view() != "room"

func esc_action() -> String:
	return "back" if _view() != "room" else "menu"

func exits_active() -> bool:
	return _view() in ["room", "kitchen"]

# ---------------------------------------------------------------------------
# input
# ---------------------------------------------------------------------------
func _controls() -> Array:
	match _view():
		"room":
			return HOTSPOTS
		"kitchen":
			return KITCHEN_HOTSPOTS
		"c_table":
			return TABLE_CONTROLS
		"c_ledger":
			return LEDGER_CONTROLS
		"c_service_board":
			if r.state.p09_complete:
				return BOARD_CONTROLS_AFTER + BOARD_CONTROLS
			return BOARD_CONTROLS
	return []

func action_at(p: Vector2) -> String:
	if glance_active():
		return ""   # a glance is short; it plays out
	if hold_t > 0.0:
		hold_t = 0.0   # a click skips the hold, and does nothing else
		return ""
	for h in _controls():
		if h[1].has_point(p):
			return h[0]
	return ""

func hover_at(p: Vector2) -> String:
	if hold_t > 0.0 or glance_active():
		return ""
	for h in _controls():
		if h[1].has_point(p):
			return h[0]
	return ""

func label_for(id: String) -> String:
	for table in [_controls(), HOTSPOTS, KITCHEN_HOTSPOTS]:
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

func _width(s: String, font: Font, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## Centred on x; `y` is the baseline.
func _ctext(c: CanvasItem, s: String, x: float, y: float, size: int, col: Color, font: Font = null) -> void:
	var f: Font = font if font else Ink.serif()
	c.draw_string(f, Vector2(x - _width(s, f, size) / 2.0, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## Right-aligned at x.
func _rtext(c: CanvasItem, s: String, x: float, y: float, size: int, col: Color, font: Font = null) -> void:
	var f: Font = font if font else Ink.serif()
	c.draw_string(f, Vector2(x - _width(s, f, size), y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## The largest size <= `size` (and >= `min_size`) at which `s` fits `width`.
func _fit(s: String, font: Font, size: int, width: float, min_size := 9) -> int:
	while size > min_size and _width(s, font, size) > width:
		size -= 1
	return size

## Centred in `rect` (vertically by cap height), shrunk to fit its width.
func _rect_text(c: CanvasItem, s: String, rect: Rect2, size: int, col: Color, font: Font) -> void:
	var sz := _fit(s, font, size, rect.size.x - 8)
	_ctext(c, s, rect.get_center().x, rect.get_center().y + sz * 0.36, sz, col, font)

func _wrap(s: String, font: Font, size: int, width: float) -> Array:
	var out := []
	var line := ""
	for word in s.split(" "):
		var trial: String = word if line == "" else line + " " + word
		if _width(trial, font, size) > width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out

func _tex_at(c: CanvasItem, id: String, at: Vector2, mod := Color(1, 1, 1, 1)) -> void:
	var t := _tex(id)
	if t:
		c.draw_texture(t, at, mod)
	else:
		_missing(c, Rect2(at, Vector2(64, 40)), id)

func _tex_centred(c: CanvasItem, id: String, centre: Vector2, scale := 1.0, mod := Color(1, 1, 1, 1)) -> void:
	var t := _tex(id)
	if t == null:
		_missing(c, Rect2(centre - Vector2(32, 20), Vector2(64, 40)), id)
		return
	var sz := t.get_size() * scale
	c.draw_texture_rect(t, Rect2(centre - sz / 2.0, sz), false, mod)

func _full(c: CanvasItem, id: String, mod := Color(1, 1, 1, 1)) -> void:
	var t := _tex(id)
	if t:
		c.draw_texture_rect(t, Rect2(Vector2.ZERO, SIZE), false, mod)
	elif id.begins_with("view_") or id in ["c_table", "c_ledger", "c_board"]:
		c.draw_rect(Rect2(Vector2.ZERO, SIZE), Ink.STORM)
		_text(c, id + " (missing)", Vector2(40, 140), 24, Ink.PAPER)

## A missing sprite still shows where it belongs.
func _missing(c: CanvasItem, rect: Rect2, id: String) -> void:
	c.draw_rect(rect, Color(Ink.STORM, 0.8))
	c.draw_rect(rect, Ink.BRASS, false, 2.0)
	_rect_text(c, id, rect, 11, Ink.PAPER, narrow_plain)

func _chevron(c: CanvasItem, centre: Vector2, right: bool) -> void:
	c.draw_circle(centre, 24, Color(NAVY, 0.92))
	c.draw_arc(centre, 24, 0, TAU, 40, PAPER_HI, 2.0, true)
	var s := 1.0 if right else -1.0
	c.draw_colored_polygon(PackedVector2Array([centre + Vector2(-7 * s, -11), centre + Vector2(10 * s, 0),
		centre + Vector2(-7 * s, 11)]), PAPER_HI)

func _ring(c: CanvasItem, rect: Rect2, col: Color, w: float) -> void:
	c.draw_rect(rect, col, false, w)

# ---------------------------------------------------------------------------
# drawing: world (views A and B)
# ---------------------------------------------------------------------------
func _draw_room() -> void:
	if _side() == "b":
		_draw_view_b(room)
	else:
		_draw_view_a(room)

func _draw_glow() -> void:
	var c := glow
	if _side() == "a":
		if r.ending() != "sever" and (_band() == 7 or r.ending() == "continue"):
			_full(c, "a_warm_b7")
	elif r.range_lit():
		var a := 0.9
		if motion:
			a += 0.05 * sin(TAU * 0.7 * time)
		_full(c, "b_range_glow", Color(1, 1, 1, a))

func _draw_top() -> void:
	var c := top
	if _side() == "a":
		_chevron(c, _rect_of(HOTSPOTS, "to_kitchen").get_center(), true)
	else:
		if book_blank():
			_tex_at(c, "b_book_blank", BOOK_BLANK_AT)
		else:
			_draw_lectern_pencil(c)
		_chevron(c, _rect_of(KITCHEN_HOTSPOTS, "to_mess").get_center(), false)
	if hold_t > 0.0 and not motion and not _closeup():
		_ring(c, hold_rect.grow(3), Color(PAPER_HI, 0.95), 2.0)
	if glance_active():
		# the glance's focus: everything else steps back a little
		var g := glance_rect.grow(28)
		var dim := Color(0.04, 0.06, 0.08, 0.32)
		c.draw_rect(Rect2(0, 0, SIZE.x, g.position.y), dim)
		c.draw_rect(Rect2(0, g.end.y, SIZE.x, SIZE.y - g.end.y), dim)
		c.draw_rect(Rect2(0, g.position.y, g.position.x, g.size.y), dim)
		c.draw_rect(Rect2(g.end.x, g.position.y, SIZE.x - g.end.x, g.size.y), dim)
		if glance_id == "p07_spoon" and r.spoon_in_dent():
			_draw_glance_spoon(c)

## The door-place spoon at 2x its plate scale, lifted by the glance; its shadow stays on the cloth.
func _draw_glance_spoon(c: CanvasItem) -> void:
	var sid := "a_spoon_used" if r.soup_shown() else "a_spoon_dark"
	var sp := _tex(sid)
	if sp == null:
		return
	var sz := sp.get_size() * 2.0
	var rest := SPOON_AT + sp.get_size() - Vector2(sp.get_size().x / 2.0, 0)   # bottom centre
	var lift := glance_spoon_lift()
	var at := Vector2(rest.x - sz.x / 2.0, rest.y - sz.y - lift)
	var k := lift / GLANCE_SPOON_LIFT
	if k > 0.0:
		c.draw_texture_rect(sp, Rect2(at + Vector2(6, 8 + lift), sz), false, Color(SHADOW, 0.45 * k))
	c.draw_texture_rect(sp, Rect2(at, sz), false)

func _rect_of(table: Array, id: String) -> Rect2:
	for h in table:
		if h[0] == id:
			return h[1]
	return Rect2()

# --- view A: the mess ---------------------------------------------------------------------------
func _place_x(i: int) -> float:
	return 330.0 + 112.0 * (i - 1)

func _draw_view_a(c: CanvasItem) -> void:
	var serif := Ink.serif()
	_full(c, plate_a())
	if r.plate_stage() == "b7":
		_draw_eye(c)
	# rain on the glass
	var rid_ := rain_id()
	if rid_ != "":
		var t := _tex(rid_)
		if t:
			var off := fposmod(time * rain_speed(), RAIN_SIZE.y)
			if off < 0.5:
				c.draw_texture(t, RAIN_AT)
			else:
				# wrapped scroll: the bottom strip of the sprite at the top, the rest below it
				c.draw_texture_rect_region(t, Rect2(RAIN_AT, Vector2(RAIN_SIZE.x, off)),
					Rect2(0, RAIN_SIZE.y - off, RAIN_SIZE.x, off))
				c.draw_texture_rect_region(t, Rect2(RAIN_AT + Vector2(0, off), Vector2(RAIN_SIZE.x, RAIN_SIZE.y - off)),
					Rect2(0, 0, RAIN_SIZE.x, RAIN_SIZE.y - off))
	# his chair: tucked in (its back over the table, its bare seat under it), or pulled out
	if r.chair_out():
		_tex_at(c, "a_chair_pulled", CHAIR_PULLED_AT)
	else:
		_tex_at(c, "a_chair_tucked", CHAIR_TUCKED_AT)
		_tex_at(c, "a_seat9_wet" if seat_wet() else "a_seat9", SEAT9_AT)
	# place 10: the stool with its blank napkin at the rack end
	_full(c, "a_place10")
	# the rack: one rim per initialled bowl still in it, the patched bowl on top
	var rack: Array = r.rack_contents()
	var j := 0
	for b in rack:
		if b != "" and b != "b_sq":
			_tex_at(c, "a_stack_rim", Vector2(40, STACK_SHELF - 22 - 20 * j))
			j += 1
	if "b_sq" in rack:
		_tex_at(c, "a_bowl_sq", Vector2(44, 406))
	# bowls at the places (place 10's on its stool)
	for i in range(1, R05Sim.PLACES + 1):
		var b := r.place_bowl(i)
		if b != "":
			var base := Vector2(_place_x(i), BOWL_BASE_Y) if i <= 9 else PLACE10_A
			_tex_at(c, "a_bowl_sq" if b == "b_sq" else "a_bowl", base - Vector2(48, 64))
	if r.soup_shown():
		_tex_at(c, "a_soup_ring", SOUP_AT)
	# the wet running along the cloth toward his place, the beads on the bowls (kept above the
	# initials, which are drawn after it so they always read)
	var wid := wet_id()
	if wid != "":
		_full(c, wid)
	for i in range(1, 10):
		var ini := _bowl_initials(r.place_bowl(i))
		if ini != "":
			_ctext(c, ini, _place_x(i), BOWL_BASE_Y - 14, 16, INK, serif)   # on the white body, under the navy band
	# hem patches: the eight initialled place marks; place 9's patch is blank
	for i in range(1, 9):
		_ctext(c, R05Sim.PLACE_MARKS[i - 1], _place_x(i), PATCH_Y + 8, 22, INK, serif)
	# his spoon in its dent: big and dark, so a lift reads across the room (the glance draws it
	# itself, larger, over everything)
	if r.spoon_in_dent() and not (glance_active() and glance_id == "p07_spoon"):
		var k := spoon_raise()
		var sid := "a_spoon_used" if r.soup_shown() else "a_spoon_dark"
		var sp := _tex(sid)
		if sp:
			if k > 0.0:
				c.draw_texture(sp, SPOON_AT + Vector2(3, 4), Color(SHADOW, 0.4 * k))
			c.draw_texture(sp, SPOON_AT - Vector2(0, SPOON_RISE * k))
		else:
			_missing(c, Rect2(SPOON_AT, Vector2(70, 28)), sid)
	# Nora's towel and the ring where her cup stood
	if r.towel_pose() == "halves":
		_tex_at(c, "a_towel_wet", TOWEL_WET_AT)
	else:
		_tex_at(c, "a_towel", TOWEL_AT)
	if r.ring_pose() == "warm":
		if motion:
			_tex_at(c, "a_ring_amber", RING_AMBER_AT)
			_draw_ribbon(c, RING_CENTRE + Vector2(0, -6), 84.0, 3.0)
		else:
			_tex_at(c, "a_ring_wisp", RING_WISP_AT)
	else:
		_tex_at(c, "a_ring", RING_AT)
	# the tally numeral
	var n := str(int(r.state.tally))
	_ctext(c, n, TALLY_WIN.get_center().x, TALLY_WIN.end.y - 9, _fit(n, serif, 28, TALLY_WIN.size.x - 4), INK, serif)

## Band 7: the eye pressed to the window, stark (a_window_eye_b7v2). Motion on, the upper lid
## drifts down 1 px for a moment every 6 s; motion off, it is still.
func _draw_eye(c: CanvasItem) -> void:
	_full(c, "a_window_eye_b7v2")
	if not motion or fposmod(time, LID_PERIOD) >= 0.9:
		return
	var pts := PackedVector2Array()
	for i in 41:
		var t := i / 40.0
		var q := LID_P0 * (1.0 - t) * (1.0 - t) + LID_P1 * 2.0 * t * (1.0 - t) + LID_P2 * t * t
		q.y += 1.0
		if GLASS.has_point(q):
			pts.append(q)
	if pts.size() >= 2:
		c.draw_polyline(pts, Color("0e161c"), 7.0, true)
	# the glazing bars stay in front
	c.draw_rect(Rect2(725, GLASS.position.y, 10, GLASS.size.y), Ink.STORM)
	c.draw_rect(Rect2(GLASS.position.x, 204, GLASS.size.x, 10), Ink.STORM)

## His seat under the table is wet from band 2 (before the chair is pulled out at band 4).
func seat_wet() -> bool:
	return _band() >= 2 and r.ending() != "sever"

## The cloth's wet overlay for this band (a_wet_b2..b7), or "".
func wet_id() -> String:
	if not r.condensation_shown():
		return ""
	return "a_wet_b%dv2" % clampi(_band(), 2, 7)

## A soft pale ribbon of steam rising `height` px from `base`, swaying; still when Motion is off.
func _draw_ribbon(c: CanvasItem, base: Vector2, height: float, period: float) -> void:
	var t := fposmod(time, period) / period if motion else 0.35
	var widths := [18.0, 9.0, 4.0]
	var alphas := [0.2, 0.34, 0.7]
	for pass_i in 3:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 31:
			var s := i / 30.0
			var sway := 9.0 * sin(TAU * (s * 1.1 - t)) * (0.3 + s)
			pts.append(Vector2(base.x + sway, base.y - height * s))
			cols.append(Color(PAPER_HI, alphas[pass_i] * (1.0 - s * s) * (0.8 + 0.2 * sin(PI * t))))
		c.draw_polyline_colors(pts, cols, widths[pass_i], true)

# --- view B: the kitchen ------------------------------------------------------------------------
func _draw_view_b(c: CanvasItem) -> void:
	var serif := Ink.serif()
	var hand := Ink.hand()
	_full(c, plate_b())
	# the service hatch
	if r.hatch_open():
		_tex_at(c, "b_hatch_open", Vector2(1316, 560))
	else:
		_rect_text(c, "LOWER PASSAGE", Rect2(1330, 580, 92, 30), 14, INK, narrow)
	# band 3: a thread of steam off the kettle, over a range that is cold
	if steam_shown():
		_draw_ribbon(c, KETTLE_SPOUT, 96.0, 3.4)
	# the shift board: Rook's register on its strips; after P09 the official board stands swung
	# open on its hinge (its back to us) beside the second board it hid, and that one's fog
	_draw_vb_board(c)
	if r.board_swung():
		_tex_at(c, "b_board_back", BOARD_BACK_AT)
		_tex_at(c, "b_board_swung", Vector2(950, 130))
		var pose := r.fog_pose()
		if pose in ["wiped", "dry"]:
			_rook_line(c, R05Sim.DUPLICATE_LINE, Rect2(1004, 440, 290, 30), 15, ROOK_BROWN)
		_ctext(c, "SHIFT REGISTER", 1149, 168, 11, Color(INK, 0.8), narrow_plain)
		if pose == "full":
			_tex_at(c, "b_fog", Vector2(960, 140))
		elif pose == "wiped":
			_tex_at(c, "b_fog_wiped", Vector2(960, 140))
	# the service drawer, slid out
	if r.drawer_open():
		var k := smoothstep(0.0, 1.0, drawer_t)
		var t := _tex("b_drawer_open")
		var at := Vector2(985, 596 - 6.0 * (1.0 - k))
		if t:
			c.draw_texture(t, at, Color(1, 1, 1, k))
		_text(c, "E.V. ate.", at + Vector2(48, 44), 14, Color(INK, k), hand)
	# Nora's work card, lifting on its nail; from band 6, off it, hanging in the air at a slant
	var ang := deg_to_rad(card_angle())
	var pivot := CARD_NAIL + (Vector2(10, -16) if card_off_nail() else Vector2.ZERO)
	c.draw_set_transform(pivot, -ang, Vector2.ONE)
	var o := CARD_AT - CARD_NAIL
	_tex_at(c, "b_work_card", o)
	_draw_card_trace(c, o)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_card_trace(c: CanvasItem, o: Vector2) -> void:
	_ctext(c, "CALIBRATION 18 OCT 1927", o.x + 55, o.y + 23, 8, INK, narrow_plain)
	var pts := PackedVector2Array([Vector2(8, 95), Vector2(12, 95), Vector2(19, 75), Vector2(26, 95),
		Vector2(28, 95), Vector2(35, 75), Vector2(42, 95), Vector2(62, 95)])
	for i in 13:
		var s := i / 12.0
		pts.append(Vector2(62 + 36 * s, 95 - 33 * sin(PI * s)))
	pts.append(Vector2(102, 95))
	var abs_pts := PackedVector2Array()
	for p in pts:
		abs_pts.append(o + p)
	c.draw_polyline(abs_pts, INK, 2.0, true)

## Rook's register on the kitchen wall, small: header, the eight strips, PRESENT 8.
func _draw_vb_board(c: CanvasItem) -> void:
	if r.board_swung():
		return
	_rect_text(c, "SHIFT REGISTER · 18 OCT 1927", Rect2(980, 152, 284, 38), 13, INK, narrow)
	for k in 8:
		var y := VB_BOARD_STRIPS_Y + VB_BOARD_STRIP_DY * k
		var nm: String = R05Sim.BOARD_NAMES[k]
		_text(c, nm, Vector2(986, y + 20), _fit(nm, Ink.hand(), 15, 204), INK, Ink.hand())
	_rect_text(c, str(int(r.state.board_count)), Rect2(1206, 432, 58, 34), 22, INK, Ink.serif())
	_ctext(c, "PRESENT", 1235, 428, 10, INK, narrow)

## Band 3 only: the kettle steams over the cold range.
func steam_shown() -> bool:
	return _band() == 3 and r.ending() == "" and not r.range_lit()

## Band 5 on: the book has opened itself at a fresh ruled page (one pencil line).
func book_blank() -> bool:
	return _band() >= 5 and r.ending() != "sever"

## Faint grey pencil on the lectern book's pages.
func _draw_lectern_pencil(c: CanvasItem) -> void:
	var col := Color(0.30, 0.31, 0.34, 0.55)
	for k in 4:
		var y := 536.0 + 11.0 * k
		c.draw_line(Vector2(716, y), Vector2(716 + [62, 48, 70, 40][k], y + 1), col, 1.6)
		c.draw_line(Vector2(812, y), Vector2(812 + [58, 66, 36, 52][k], y), col, 1.6)

# ---------------------------------------------------------------------------
# drawing: close-ups (layer 5)
# ---------------------------------------------------------------------------
## 0..1: how far the station's damp has reached into the close-up backdrops (bands 2..7).
func close_damp() -> float:
	if r.ending() == "sever":
		return 0.0
	return clampf((_band() - 1) / 6.0, 0.0, 1.0)

func _damp(c: CanvasItem, id: String) -> void:
	var k := close_damp()
	if k > 0.0:
		_full(c, id, Color(1, 1, 1, k))

func _draw_close() -> void:
	match _view():
		"c_table":
			_draw_table(close)
		"c_ledger":
			_draw_ledger(close)
		"c_service_board":
			_draw_board(close)

# --- c_table ------------------------------------------------------------------------------------
func _mat_x(k: int) -> float:
	return MAT_X0 + MAT_DX * (k - 1)

## The plan centre of a bowl set at place k.
func _place_centre(k: int) -> Vector2:
	if k == 10:
		return PLACE10_C
	return PLAN_9 if k == 9 else Vector2(_mat_x(k) + 48.0, PLAN_Y)

func _rack_centre(slot: int) -> Vector2:
	return Vector2(162.0 + 112.0 * slot, RACK_Y)

func _draw_plan_bowl(c: CanvasItem, b: String, centre: Vector2) -> void:
	_tex_centred(c, "c_bowl_sq" if b == "b_sq" else "c_bowl", centre)
	_draw_plan_initials(c, b, centre)
	if b == "b_sq" and not r.spoon_in_dent():
		_tex_centred(c, "c_spoon", centre + Vector2(0, -2))

## The initials inside the well, clear of the navy rim.
func _draw_plan_initials(c: CanvasItem, b: String, centre: Vector2) -> void:
	var ini := _bowl_initials(b)
	if ini != "":
		_ctext(c, ini, centre.x, centre.y + 24, 20, INK, Ink.serif())

func _draw_table(c: CanvasItem) -> void:
	var serif := Ink.serif()
	_full(c, "c_table")
	_damp(c, "c_table_damp")
	_full(c, "c_place10")
	_full(c, "c_door_edge")
	_ctext(c, "DOOR", 1409, 372, 18, PAPER_HI, narrow)
	# place marks on the stitched patches; places 9 and 10 are blank
	for k in range(1, 9):
		_ctext(c, R05Sim.PLACE_MARKS[k - 1], _mat_x(k) + 62, 348, 24, INK, serif)
	# his spoon in the place-9 dent (after P07), lifting with the beat
	if r.spoon_in_dent():
		var k := spoon_raise()
		var sp := _tex("c_spoon")
		if sp:
			var ctr := DENT_9.get_center()
			if k > 0.0:
				c.draw_texture_rect(sp, Rect2(DENT_9.position + Vector2(14, 14) * k, DENT_9.size), false,
					Color(SHADOW, 0.4 * k))
			var s := 1.0 + 0.12 * k
			var sz := DENT_9.size * s
			c.draw_texture_rect(sp, Rect2(ctr - sz / 2.0, sz), false)
	# bowls at the places (the eight setting themselves are drawn in flight below)
	for k in range(1, R05Sim.PLACES + 1):
		var b := r.place_bowl(k)
		if b != "" and not _homing(b):
			_draw_plan_bowl(c, b, _place_centre(k))
	if r.soup_shown():
		_tex_centred(c, "c_soup", PLAN_9)
	# the rack: bowls in their home recesses; the held one lifted, its shadow left behind
	var rack: Array = r.rack_contents()
	for slot in 9:
		if rack[slot] != "":
			_draw_plan_bowl(c, rack[slot], _rack_centre(slot))
	if r.held != "":
		var home := R05Sim.RACK_HOME.find(r.held)
		var at := _rack_centre(maxi(home, 0))
		_tex_centred(c, "c_shadow", at)
		_draw_plan_bowl(c, r.held, at - Vector2(0, LIFT))
	_draw_homing(c)
	if r.condensation_shown():
		_full(c, "c_condense_plan")
		# the beads run over the bowls; the initials stay on top so they always read
		for k in range(1, R05Sim.PLACES + 1):
			if r.place_bowl(k) != "":
				_draw_plan_initials(c, r.place_bowl(k), _place_centre(k))
		for slot in 9:
			if rack[slot] != "":
				_draw_plan_initials(c, rack[slot], _rack_centre(slot))
		if r.held != "":
			_draw_plan_initials(c, r.held, _rack_centre(maxi(R05Sim.RACK_HOME.find(r.held), 0)) - Vector2(0, LIFT))
	# tally drum, register plate, result flags, COMPARE lever
	_tex_at(c, "c_tally_wheel", Vector2(1150, 620))
	var n := str(int(r.state.tally))
	_ctext(c, n, 1215, 684, 42, INK, serif)   # sized to the drum's white band
	_ctext(c, "REGISTER", 1365, 640, 16, INK, narrow)
	_ctext(c, str(R05Sim.REGISTER), 1365, 677, 44, INK, serif)
	var flags: Dictionary = flags_shown
	if r.state.p07_complete and (compare_t0 < 0.0 or time - compare_t0 >= P07_FLAGS):
		flags = {"places": "agree", "portions": "agree"}
	_draw_flag(c, Vector2(1140, 820), "PLACES", str(flags.get("places", "")))
	_draw_flag(c, Vector2(1140, 870), "PORTIONS", str(flags.get("portions", "")))
	_tex_at(c, "c_lever_down" if lever_t > 0.0 else "c_lever_up", Vector2(1310, 712))
	_ctext(c, "COMPARE", 1370, 932, 15, PAPER_HI, narrow)

## 0..1 of bowl `b`'s flight from its rack recess to its own place, or -1 when not homing.
func _home_k(b: String) -> float:
	if home_t0 < 0.0 or not motion:
		return -1.0
	var j := home_list.find(b)
	if j < 0:
		return -1.0
	var t := time - home_t0 - R05Sim.HOME_STAGGER * j
	var k := t / 0.3
	return clampf(k, 0.0, 1.0) if k < 1.0 else -1.0

func _homing(b: String) -> bool:
	return _home_k(b) >= 0.0

## The eight named bowls rising out of the rack and dropping onto their own initials, in turn.
func _draw_homing(c: CanvasItem) -> void:
	for b in home_list:
		var k := _home_k(b)
		if k < 0.0:
			continue
		var from := _rack_centre(R05Sim.RACK_HOME.find(b))
		var to := _place_centre(R05Sim.SOLUTION.find(b) + 1)
		var e := smoothstep(0.0, 1.0, k)
		var at := from.lerp(to, e) - Vector2(0, 46.0 * sin(PI * k))
		_tex_centred(c, "c_shadow", from.lerp(to, e))
		_draw_plan_bowl(c, b, at)

func _draw_flag(c: CanvasItem, at: Vector2, word: String, state: String) -> void:
	if state == "":
		return
	var agree := state == "agree"
	_tex_at(c, "c_flag_agree" if agree else "c_flag_disagree", at)
	var s := word + (" AGREE" if agree else " DISAGREE")
	_rect_text(c, s, Rect2(at + Vector2(8, 4), Vector2(134, 36)), 16, INK if agree else PAPER_HI, narrow)

# --- c_ledger -----------------------------------------------------------------------------------
func _draw_ledger(c: CanvasItem) -> void:
	var hand := Ink.hand()
	_full(c, "c_ledger")
	_damp(c, "c_ledger_damp")
	var spread := r.ledger_spread
	var page := r.ledger_page(spread)
	var y := _draw_page_lines(c, page.left, 190.0, 480.0, spread == 2)
	if str(page.margin) != "":
		var m := _wrap(str(page.margin), hand, 22, 420.0)
		var my := y + 44.0
		for line in m:
			_rtext(c, line, 670.0, my, 22, PENCIL, hand)
			my += 30.0
	if spread == 0:
		var right: Array = page.right
		_text(c, str(right[0]), Vector2(778, 192), 26, INK, hand)
		_tex_at(c, "c_sketch_bowl", Vector2(790, 200))
		var cy := 424.0
		for line in _wrap(str(right[1]), hand, 22, 480.0):
			_text(c, line, Vector2(778, cy), 22, INK, hand)
			cy += 28.0
		_tex_at(c, "c_sketch_cup", Vector2(790, 520))
		_text(c, str(right[2]), Vector2(778, 744), 22, INK, hand)
	else:
		_draw_page_lines(c, page.right, 778.0, 480.0, false)
	# page-turn tabs
	_tab_arrow(c, Vector2(225, 936), false, spread > 0)
	_tab_arrow(c, Vector2(1223, 936), true, spread < R05Sim.LEDGER_LAST)
	# a page turning: a blank leaf sweeping over the gutter
	if turn_t > 0.0:
		var k := 1.0 - turn_t / 0.35
		var w := 560.0 * absf(cos(PI * k))
		var leaf: Rect2
		var over_right := k < 0.5
		if turn_dir < 0:
			over_right = not over_right
		leaf = Rect2(724, 110, w, 770) if over_right else Rect2(724 - w, 110, w, 770)
		c.draw_rect(leaf, PAPER)
		c.draw_rect(leaf, INK, false, 2.0)

## A page-turn arrow on its brass tab; dimmed (and hollow) at the end of the book.
func _tab_arrow(c: CanvasItem, at: Vector2, right: bool, live: bool) -> void:
	var d := 1.0 if right else -1.0
	var pts := PackedVector2Array([at + Vector2(-14 * d, -16), at + Vector2(16 * d, 0), at + Vector2(-14 * d, 16)])
	if live:
		c.draw_colored_polygon(pts, INK)
	else:
		pts.append(pts[0])
		c.draw_polyline(pts, Color(INK, 0.45), 2.0, true)

## Lines on the 44 px rules from y 200; long lines wrap onto the next rule. Returns the last baseline.
func _draw_page_lines(c: CanvasItem, lines: Array, x0: float, width: float, wet: bool) -> float:
	var hand := Ink.hand()
	var x := x0 if x0 > 700.0 else 190.0
	var y := 194.0
	for line in lines:
		for part in _wrap(str(line), hand, 26, width):
			_text(c, part, Vector2(x, y), 26, WET_INK if wet else INK, hand)
			y += 44.0
	return y - 44.0

# --- c_service_board ----------------------------------------------------------------------------
func _draw_board(c: CanvasItem) -> void:
	var serif := Ink.serif()
	var hand := Ink.hand()
	var st: Dictionary = r.state
	_full(c, "c_board")
	_damp(c, "c_board_damp")
	var sw := swing_k()
	# the swung board fades in behind the original as it folds to the hinge
	if sw > 0.0:
		var t := _tex("c_board_swung")
		if t:
			c.draw_texture(t, SWUNG_AT, Color(1, 1, 1, sw))
		_draw_duplicate(c, sw)
		_draw_fog(c)
	if sw < 1.0:
		var sx := maxf(0.02, 1.0 - sw)
		if sw > 0.0:
			var plate := _tex("c_board")
			if plate:
				# the original board, compressed toward its hinge; the cavity shows past it
				c.draw_texture_rect_region(plate, Rect2(BOARD_RECT.position, Vector2(BOARD_RECT.size.x * sx, BOARD_RECT.size.y)),
					BOARD_RECT)
		c.draw_set_transform(Vector2(BOARD_HINGE_X * (1.0 - sx), 0), 0.0, Vector2(sx, 1.0))
		_draw_board_text(c)
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
	# the tile rack: a seated tile leaves its recess empty
	var seated := R05Sim.NAME_TILES.find(str(st.amend.name))
	for k in 10:
		if k == seated:
			continue
		var at := Vector2(50, 140 + 76 * k)
		var nm: String = R05Sim.NAME_TILES[k]
		_tex_at(c, "c_tile_new" if nm == "MERCER" else "c_tile", at)
		_rect_text(c, nm, Rect2(at, Vector2(210, 66)), 22, INK, narrow)
	# the amendment wells: recessed brass frames, stencilled while empty
	var a: Dictionary = st.amend
	for h in BOARD_CONTROLS:
		if h[0] in WELL_IDS:
			var wr: Rect2 = h[1]
			c.draw_rect(wr, Ink.BRASS, false, 2.0)
			c.draw_rect(wr.grow(-2), NAVY, false, 1.0)
			var key: String = {"f_count": "count", "f_name": "name", "f_status": "status"}[h[0]]
			if str(a[key]) == "" and not st.p09_complete:
				_ctext(c, "click to set", wr.get_center().x, wr.get_center().y + 5, 14, Color(PAPER, 0.45), narrow_plain)
	if str(a.count) != "":
		_tex_at(c, "c_tile_small", Vector2(325, 735))
		_rect_text(c, str(a.count).replace("-", "−"), Rect2(325, 735, 140, 86), 34, INK, serif)
	if str(a.name) != "":
		var nm2: String = a.name
		_tex_at(c, "c_tile_new" if nm2 == "MERCER" else "c_tile", Vector2(550, 745))
		_rect_text(c, nm2, Rect2(550, 745, 210, 66), 22, INK, narrow)
	if str(a.status) != "":
		var pr := Rect2(852, 748, 186, 60)
		c.draw_rect(pr, PAPER_HI)
		c.draw_rect(pr, INK, false, 2.0)
		_rect_text(c, str(a.status).to_upper(), pr, 20, INK, narrow_plain)
	_ctext(c, "COUNT", 395, 724, 14, PAPER_HI, narrow)
	_ctext(c, "NAME", 655, 724, 14, PAPER_HI, narrow)
	_ctext(c, "STATUS", 945, 724, 14, PAPER_HI, narrow)
	# the placard
	var rl := _wrap(R05Sim.RULE_TEXT, serif, 20, 712.0)
	var ry := 862.0 + 86.0 / 2.0 - (rl.size() * 28.0) / 2.0 + 20.0
	for line in rl:
		_ctext(c, line, 680, ry, 20, INK, serif)
		ry += 28.0
	# the token socket
	if st.fitted.pantry:
		_tex_at(c, "c_token_pantry", Vector2(1110, 140))
	if st.fitted.bunk:
		_tex_at(c, "c_token_bunk", Vector2(1260, 140))
	_tex_at(c, "c_knob_turned" if st.socket_turned else "c_knob", Vector2(1205, 340))
	_ctext(c, "PANTRY", 1150, 354, 17, INK, narrow)
	_ctext(c, "BUNKS", 1362, 354, 17, INK, narrow)
	# the seal selector
	var seal := clampi(int(st.seal), 1, 3)
	_tex_centred(c, "c_seal_marker", Vector2(SEAL_X[seal - 1], 586))
	for n in range(1, 4):
		_rect_text(c, str(R05Sim.SEAL_LABELS[n]), Rect2(SEAL_X[n - 1] - 48, 612, 96, 48), 14, INK, narrow)
	# the stamp
	_tex_at(c, "c_stamp_down" if stamp_t > 0.0 else "c_stamp_up", Vector2(1110, 676))
	_draw_tape(c)

## Rook's register: header, the eight names in his hand, PRESENT and the count, the steps; and,
## once stamped, the amendment inked under PRESENT. Drawn in board space (the swing compresses it).
func _draw_board_text(c: CanvasItem) -> void:
	var hand := Ink.hand()
	var st: Dictionary = r.state
	_rect_text(c, R05Sim.BOARD_HEADER, Rect2(320, 116, 720, 50), 20, INK, narrow)
	for k in 8:
		var y := 180.0 + 50.0 * k
		_text(c, R05Sim.BOARD_NAMES[k], Vector2(348, y + 31), 24, INK, hand)
	_text(c, "PRESENT", Vector2(340, 634), 22, INK, Ink.serif())
	if st.p09_complete:
		# the amendment row under TULL, struck in stamp ink: Rook's eight stands above it
		c.draw_rect(STRIP_RECT, Color(STAMP_INK, 0.08))
		c.draw_rect(STRIP_RECT, Color(STAMP_INK, 0.9), false, 2.0)
		_text(c, R05Sim.AMEND_INK, STRIP_RECT.position + Vector2(14, 27), 24, STAMP_INK, narrow)
	# the count window, flipping back after an overwrite
	var sy := 1.0
	if count_flip_at >= 0.0 and time >= count_flip_at and time < count_flip_at + 0.3 and motion:
		sy = absf(cos(PI * (time - count_flip_at) / 0.3))
	c.draw_set_transform(Vector2(0, 649 * (1.0 - sy)), 0.0, Vector2(1, sy))
	_ctext(c, str(shown_count), 838, 666, 48, PAPER_HI, Ink.serif())
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## The board behind the board: one line, in Rook's brown ink and forward-leaning hand.
func _draw_duplicate(c: CanvasItem, a: float) -> void:
	_rook_line(c, R05Sim.DUPLICATE_LINE, Rect2(376, 584, 660, 44), 34, Color(ROOK_BROWN, a))

## A line in Rook's hand: brown, slanted forward, centred in `rect`.
func _rook_line(c: CanvasItem, s: String, rect: Rect2, size: int, col: Color) -> void:
	var hand := Ink.hand()
	var sz := _fit(s, hand, size, rect.size.x - 16)
	var base := rect.get_center().y + sz * 0.36
	c.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-SLANT, 1), Vector2(SLANT * base, 0)))
	_ctext(c, s, rect.get_center().x, base, sz, col, hand)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## The fog over the second board: creeping row by row during the reveal, then by fog_pose().
func _draw_fog(c: CanvasItem) -> void:
	var rows := fog_rows()
	if rows < 0.0:
		match r.fog_pose():
			"full":
				_tex_at(c, "c_fog", FOG_AT)
			"wiped":
				_tex_at(c, "c_fog_wiped", FOG_AT)
		return
	var t := _tex("c_fog")
	if t == null or rows <= 0.0:
		return
	var h := FOG_ROW_H * rows
	h = minf(h, t.get_size().y)
	c.draw_texture_rect_region(t, Rect2(FOG_AT, Vector2(t.get_size().x, h)), Rect2(0, 0, t.get_size().x, h))

## The reject tape: fed up through the window, then held as two printed lines.
func _draw_tape(c: CanvasItem) -> void:
	if r.tape == "":
		return
	var win := Rect2(1100, 896, 310, 38)
	var feed := 1.0
	if tape_t0 >= 0.0 and motion:
		feed = clampf((time - tape_t0) / 0.8, 0.0, 1.0)
	elif tape_t0 >= 0.0 and time < tape_t0:
		feed = 0.0
	if feed <= 0.0:
		return
	var parts := r.tape.split(". ", false, 1)
	var lines: Array = [parts[0] + "." if parts.size() > 1 else parts[0]]
	if parts.size() > 1:
		lines.append(parts[1])
	var dy := (1.0 - feed) * 40.0
	var y := win.position.y + 16.0 + dy
	for line in lines:
		if y <= win.end.y + 2.0:
			var sz := _fit(line, mono, 14, win.size.x - 10, 10)
			_ctext(c, line, win.get_center().x, y, sz, INK, mono)
		y += 17.0
