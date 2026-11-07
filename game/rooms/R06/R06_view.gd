extends RoomView
## R06, the Bunk Room: renderer. Presents R06Sim (game/rooms/R06/R06_sim.gd) and never mutates
## it. Everything timed here (notice holds, the hollows appearing and rising, the curtain's
## sway, steam, rain frames, key presses, loop fades) is presentation and is never saved.
##
## Layering:
##   `room` (world, under a mild CanvasModulate): view A (lockers and bunks) or view B (the
##          curtain wall), the stage plate, the painted overlays and every code-drawn label.
##   CanvasLayer 5 `close`: the close-ups c_lockers (P08) and c_slope (P22), always fully lit.
##
## Painted plates: assets/rooms/R06/*.png (tools/art/rooms/R06.py). The art carries no text:
## every plate, card, tag, calendar line and wheel word is drawn here, so clues stay exact.

const DIR := "res://assets/rooms/R06/%s.png"

const INK := Color("172b36")
const PAPER_HI := Color("e8e1cf")
const ENAMEL := Color("e2dcca")
const BRASS := Color("9c7e46")
const FELT_HI := Color("8fa69a")
const GRAPHITE := Color("3a3e44")
const SHADOW_NAVY := Color("0e1a24")

## [id, rect, label]; first match wins, so small objects come first. View A.
const HOTSPOTS := [
	["belongings_shelf", Rect2(448, 150, 256, 100), "Loose belongings"],
	["locker_bell", Rect2(48, 250, 100, 640), "BELL locker"],
	["locker_rook", Rect2(148, 250, 100, 640), "ROOK locker"],
	["locker_venn", Rect2(248, 250, 100, 640), "VENN locker"],
	["locker_ives", Rect2(348, 250, 100, 640), "IVES locker"],
	["closed_lockers", Rect2(448, 250, 256, 640), "Locked lockers"],
	["venn_bunk", Rect2(724, 640, 380, 124), "Venn's bunk"],
	["luggage", Rect2(740, 776, 600, 116), "Luggage"],
	["to_curtain", Rect2(1356, 776, 88, 116), "Curtain wall"],
	["bunks", Rect2(724, 330, 724, 434), "Bunks"],
]
## View B, the curtain wall.
const CURTAIN_HOTSPOTS := [
	["ives_letter", Rect2(706, 524, 96, 84), "Pigeonhole"],
	["slope", Rect2(496, 600, 320, 164), "Writing slope"],
	["calendar", Rect2(500, 136, 280, 376), "Calendar"],
	["pencil_shelf", Rect2(856, 536, 140, 72), "Pencil shelf"],
	["cup_shelf", Rect2(1192, 540, 120, 72), "Bracket shelf"],
	["curtain", Rect2(36, 120, 440, 640), "Curtain"],
	["bunks_b", Rect2(832, 330, 616, 434), "Bunks"],
	["to_lockers", Rect2(4, 776, 88, 116), "Lockers"],
]
const EXIT_RECTS := {
	"R02": Rect2(20, 922, 250, 64),
	"R05": Rect2(282, 922, 250, 64),
}

# c_lockers -----------------------------------------------------------------------------------
const LOCKER_X := {"bell": 74.0, "rook": 394.0, "venn": 714.0, "ives": 1034.0}
## The static controls; the tray objects are added per frame (lockers_controls()).
const LOCKER_CONTROLS := [
	["card_bell", Rect2(94, 196, 260, 160), "BELL card"],
	["card_rook", Rect2(414, 196, 260, 160), "ROOK card"],
	["card_venn", Rect2(734, 196, 260, 160), "VENN card"],
	["card_ives", Rect2(1054, 196, 260, 160), "IVES card"],
	["venn_back", Rect2(744, 600, 240, 190), "The back of Venn's locker"],
	["shelf_bell", Rect2(74, 380, 300, 420), "BELL shelf"],
	["shelf_rook", Rect2(394, 380, 300, 420), "ROOK shelf"],
	["shelf_venn", Rect2(714, 380, 300, 420), "VENN shelf"],
	["shelf_ives", Rect2(1034, 380, 300, 420), "IVES shelf"],
]
## Tray slot i of R06Sim.TRAY_ORDER (checked by the tests; the live ids are obj_<object>).
const TRAY_CONTROLS := [
	["tray_0", Rect2(150, 828, 240, 150), "Tray slot 1"],
	["tray_1", Rect2(440, 828, 240, 150), "Tray slot 2"],
	["tray_2", Rect2(730, 828, 240, 150), "Tray slot 3"],
	["tray_3", Rect2(1020, 828, 240, 150), "Tray slot 4"],
]
const OBJ_LABELS := {"cup": "Cup", "calipers": "Calipers", "pencils": "Pencil holder", "glove": "Glove"}
const SPRITE := {"cup": "c_cup", "calipers": "c_calipers", "pencils": "c_pencils", "glove": "c_glove"}
const SHELF_CX := {"bell": 224.0, "rook": 544.0, "venn": 864.0, "ives": 1184.0}
const SHELF_Y := 560.0
const TRAY_X := [270.0, 560.0, 850.0, 1140.0]
const TRAY_Y := 960.0
const LIFT_PX := 40.0
const TOKEN_AT := Vector2(764, 620)       # the rubbing sprite, its nail on Venn's painted nail
const CUP_MARK_AT := Vector2(150, 556)
const VENN_FADE := 0.4
## The card's text column: 240 px less the cream card's painted edge, so no line touches it.
const CARD_WRAP := 226.0

# c_slope ---------------------------------------------------------------------------------
const SLOPE_CONTROLS := [
	["printed_line", Rect2(220, 440, 360, 64), "The printed line"],
	["rest_record", Rect2(160, 200, 480, 420), "RECORD rest"],
	["rest_evidence", Rect2(808, 200, 480, 420), "EVIDENCE rest"],
	["fin_prev", Rect2(160, 680, 64, 80), "Finding ◁"],
	["fin_next", Rect2(456, 680, 64, 80), "Finding ▷"],
	["obj_prev", Rect2(544, 680, 64, 80), "Object ◁"],
	["obj_next", Rect2(840, 680, 64, 80), "Object ▷"],
	["own_prev", Rect2(928, 680, 64, 80), "Owner ◁"],
	["own_next", Rect2(1224, 680, 64, 80), "Owner ▷"],
	["erase", Rect2(160, 820, 280, 120), "ERASE"],
	["append", Rect2(1008, 820, 280, 120), "APPEND"],
]
const WHEEL_X := [[236.0, 448.0], [620.0, 832.0], [1004.0, 1216.0]]
const WHEEL_BASE := 728.0
const KEY_TIME := 0.15

# base-view text --------------------------------------------------------------------------
const PLATE_A := [["BELL", 98], ["ROOK", 198], ["VENN", 298], ["IVES", 398]]
const PLATE_SHUT := [["LUSK", 480], ["DOANE", 544], ["HART", 608], ["TULL", 672]]
const TAGS_A := [["ROOK", Vector2(920, 497)], ["VENN", Vector2(920, 747)], ["HART", Vector2(1300, 497)],
	["IVES", Vector2(1300, 747)]]
const TAGS_B := [["LUSK", Vector2(1030, 497)], ["DOANE", Vector2(1030, 747)], ["TULL", Vector2(1350, 497)],
	["BELL", Vector2(1350, 747)]]
## The rota's eight hands, one per row: [size, slant, ink]. Fixed, never random.
const MANY_HANDS := [
	[21, 0.24, Color("1f3f8a")], [19, 0.06, Color("172b36")], [22, 0.16, Color("3a3e44")],
	[18, 0.30, Color("4a2e1c")], [20, 0.02, Color("1f3f8a")], [22, 0.20, Color("172b36")],
	[19, 0.12, Color("4a2e1c")], [21, 0.26, Color("3a3e44")]]

# escalation ------------------------------------------------------------------------------
const HOLD_TIME := 1.5
const NOTICE_FOCUS := {
	"pillow": Rect2(724, 640, 380, 124),
	"names_moved": Rect2(500, 136, 280, 376),
	"her_name": Rect2(500, 136, 280, 376),
	"doane": Rect2(832, 640, 318, 124),
	"curtain_shape": Rect2(36, 120, 440, 640),
	"four": Rect2(724, 330, 724, 434),
	"every_bed": Rect2(724, 330, 724, 434),
	"rise": Rect2(724, 330, 724, 434),
	"cup": Rect2(48, 250, 100, 640),
}
const A_BEDS := ["venn", "rook", "hart", "ives"]
const B_BEDS := ["doane", "lusk", "tull", "bell"]
const EIGHT_STEP := 0.7        # springs_eight: one settle every 0.7 s
const RISE_STEP := 1.2         # dents_rise: one release every 1.2 s
const RISE_FADE := 1.5
const FAN_GLASS := Rect2(828, 150, 404, 92)
const CURTAIN_BOX := Rect2(26, 126, 482, 770)

# sound -----------------------------------------------------------------------------------
const SFX_DB := {"springs_settle": -12.0, "spring_creak": -10.0, "springs_eight": -9.0, "dents_rise": -10.0,
	"turn_step": -16.0, "locker_door": -12.0, "belonging_lift": -14.0, "belonging_set_down": -14.0,
	"cup_set": -10.0, "calipers_set": -10.0, "pencils_set": -10.0, "glove_set": -12.0, "plate_click": -8.0,
	"reject_set": -11.0, "compartment_drop": -6.0, "latch_small": -9.0, "letter_unfold": -12.0,
	"calendar_page": -13.0, "curtain_rings": -10.0, "slope_lid": -11.0, "card_lay": -13.0,
	"sketch_lay": -13.0, "wheel_step": -14.0, "erase_refuse": -10.0, "append_refuse": -11.0,
	"pencil_scratch": -8.0, "cup_warm": -9.0}
const SFX_SOFT := ["spring_creak", "compartment_drop", "latch_small"]
## Soften sudden sounds: the card's spring creak is not heard at all.
const SFX_SOFT_CUT := {"spring_creak": 80.0}
const LOOPS := ["r06_room", "r06_rain_roof", "r06_rain_heavy", "r06_wind_louvre", "r06_curtain_draught",
	"r06_beds_breath", "r06_pressure", "r06_cup_steam"]
const RAIN_LOOPS := ["r06_rain_roof", "r06_rain_heavy"]
const LOOP_RATE := 0.11
const CLOSE_DUCK_DB := 4.0
const RAIN_DUCK_DB := 6.0

var r: R06Sim:
	get:
		return sim as R06Sim

var textures := {}
var narrow: SystemFont
var serif_bold: SystemFont
var room: Node2D
var close: Node2D
var shade: CanvasModulate
var mixer: LoopMixer
var letter_texts := []

# presentation state (never saved)
var tint := Color(1, 1, 1)
var hold_t := 0.0
var hold_e := 0.0             # seconds into the hold
var hold_rect := Rect2()
var hold_wall := "room"       # the wall a notice hold shows: "room" (A) or "curtain" (B)
var zoom_k := 0.0
var reveal_kind := ""         # "every_bed" | "rise" | ""
var reveal_t := -1.0          # seconds since its sound began; -1 waiting for it
var reveal_wait := 0.0        # fallback: start anyway if the sound never comes
var reveal_prev := []         # the A hollows already shown before every_bed
var venn_k := 1.0             # c_venn_open crossfade (1 = open, shown when the compartment is)
var venn_pending := false
var token_on := false         # the rubbing shows through the P08 reveal chain
var key_t := {"erase": 0.0, "append": 0.0}
var refuse_t := 0.0
var refuse_shelf := ""

func _ready() -> void:
	narrow = SystemFont.new()
	narrow.font_names = PackedStringArray(["Liberation Sans Narrow", "Nimbus Sans Narrow", "DejaVu Sans Condensed", "sans-serif"])
	narrow.font_weight = 700
	serif_bold = SystemFont.new()
	serif_bold.font_names = PackedStringArray(["Noto Serif", "DejaVu Serif", "Liberation Serif", "serif"])
	serif_bold.font_weight = 700
	for l in R06Sim.LETTER:
		letter_texts.append(l[0])
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

## 1..7: a band-0 debug entry reads as the arrival band.
func _band() -> int:
	return clampi(r.band(), 1, 7)

func _sever() -> bool:
	return r.ending() == "sever"

## The interior tint per band: even steps from white (band 1) to (0.86, 0.89, 0.93) at band 7.
static func tint_for(band: int) -> Color:
	var t := clampf((band - 1) / 6.0, 0.0, 1.0)
	return Color(1.0 - 0.14 * t, 1.0 - 0.11 * t, 1.0 - 0.07 * t)

## The wall on screen: B for the curtain wall and its slope, and for a B notice's hold.
func shown_wall() -> String:
	var v := _view()
	if v == "curtain" or v == "c_slope":
		return "curtain"
	if v == "room" and hold_t > 0.0:
		return hold_wall
	return "room"

func plate_id(wall: String) -> String:
	var st := r.plate_stage()
	var base := "view_a" if wall == "room" else "view_b"
	return base if st == "s1" else base + "_" + st

## The hollows on screen for `bed` (0..1), with every_bed's reveal and the sever rise.
func dent_alpha(bed: String) -> float:
	if reveal_kind == "rise":
		if not motion:
			return 0.0
		var t := maxf(reveal_t, 0.0)
		var k := R06Sim.DENT_ORDER.find(bed)
		return 1.0 - clampf((t - RISE_STEP * k) / RISE_FADE, 0.0, 1.0)
	if not bed in r.dents():
		return 0.0
	if reveal_kind == "every_bed" and motion and not bed in reveal_prev:
		var k := R06Sim.DENT_ORDER.find(bed)
		return 1.0 if reveal_t >= 0.0 and reveal_t >= EIGHT_STEP * k else 0.0
	return 1.0

func _rise_len() -> float:
	return RISE_STEP * R06Sim.DENT_ORDER.find("hart") + RISE_FADE

func _eight_len() -> float:
	var last := 0
	for b in A_BEDS:
		last = maxi(last, R06Sim.DENT_ORDER.find(b))
	return EIGHT_STEP * last

func hold_active() -> bool:
	return hold_t > 0.0

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------
func tick(dt: float) -> void:
	if hold_t > 0.0:
		hold_t = maxf(0.0, hold_t - dt)
		hold_e += dt
	if reveal_kind != "":
		if reveal_t < 0.0:
			reveal_wait -= dt
			if reveal_wait <= 0.0:
				reveal_t = 0.0
		else:
			reveal_t += dt
		var end := _rise_len() if reveal_kind == "rise" else _eight_len()
		if reveal_t > end + 0.05 or not motion:
			reveal_kind = ""
	var zt := 1.0 if hold_t > 0.0 and motion and not r.is_closeup() else 0.0
	zoom_k = move_toward(zoom_k, zt, dt * 2.5)
	var s := 1.0 + 0.04 * smoothstep(0.0, 1.0, zoom_k)
	var focus := hold_rect.get_center()
	room.scale = Vector2(s, s)
	room.position = focus * (1.0 - s)
	var tt := tint_for(_band())
	tint = Color(move_toward(tint.r, tt.r, dt * 0.2), move_toward(tint.g, tt.g, dt * 0.2),
		move_toward(tint.b, tt.b, dt * 0.2))
	shade.color = tint
	if not venn_pending and venn_k < 1.0:
		venn_k = minf(1.0, venn_k + dt / VENN_FADE) if motion else 1.0
	if token_on and game and not game.chain_active():
		token_on = false
	for k in key_t:
		key_t[k] = maxf(0.0, key_t[k] - dt)
	refuse_t = maxf(0.0, refuse_t - dt)
	_tick_audio(dt)
	redraw()

func loop_targets() -> Dictionary:
	var b := _band()
	var e := r.ending()
	var sever := e == "sever"
	var t := {}
	t["r06_room"] = 0.4 if sever else 0.5
	if sever:
		t["r06_rain_roof"] = 0.3
	elif b == 1:
		t["r06_rain_roof"] = 0.45
	elif b <= 3:
		t["r06_rain_roof"] = 0.55
	elif b <= 5:
		t["r06_rain_roof"] = 0.4
	if not sever:
		if b >= 2 and b <= 3:
			t["r06_rain_heavy"] = 0.35
		elif b >= 4 and b <= 5:
			t["r06_rain_heavy"] = 0.25
		if b == 1:
			t["r06_wind_louvre"] = 0.15
		elif b <= 5:
			t["r06_wind_louvre"] = 0.25
		elif b == 6:
			t["r06_wind_louvre"] = 0.1
		if b == 5:
			t["r06_beds_breath"] = 0.12
		elif b == 6:
			t["r06_beds_breath"] = 0.22
		elif b == 7:
			t["r06_beds_breath"] = 0.26
		if b == 7 and e == "":
			t["r06_pressure"] = 0.3
	if r.curtain_shape():
		t["r06_curtain_draught"] = 0.2
	if r.cup_steam():
		t["r06_cup_steam"] = 0.12
	var close_k := db_to_linear(-CLOSE_DUCK_DB) if r.is_closeup() else 1.0
	var rain_k := db_to_linear(-RAIN_DUCK_DB) if _rain_ducked() else 1.0
	var out := {}
	for id in LOOPS:
		var v: float = t.get(id, 0.0) * close_k
		if id in RAIN_LOOPS:
			v *= rain_k
		out[id] = v
	return out

## The rain steps back while she writes the amendment or reads Ives's letter.
func _rain_ducked() -> bool:
	if game == null:
		return false
	return game.oneshot_playing(["pencil_scratch"]) or game.cur_text in letter_texts

func _tick_audio(dt: float) -> void:
	mixer.tick(loop_targets(), {}, dt, LOOP_RATE)

# ---------------------------------------------------------------------------
# hooks
# ---------------------------------------------------------------------------
func play_fx(id: String, e: Dictionary) -> void:
	if id.begins_with("notice_"):
		_start_hold(id.substr(7), str(e.get("view", "")))
		return
	match id:
		"venn_open":
			venn_k = 0.0
			venn_pending = true
			token_on = true
		"pigeonhole_open", "cup_warm":
			pass   # it happens across the room (view B / the locker); only the sound tells her

func on_sfx(id: String) -> void:
	match id:
		"compartment_drop":
			if venn_pending:
				venn_pending = false
				if not motion:
					venn_k = 1.0
		"springs_eight":
			if reveal_kind == "every_bed" and reveal_t < 0.0:
				reveal_t = 0.0
		"dents_rise":
			if reveal_kind == "rise" and reveal_t < 0.0:
				reveal_t = 0.0
		"erase_refuse":
			key_t["erase"] = KEY_TIME
		"append_refuse", "pencil_scratch":
			key_t["append"] = KEY_TIME
		"reject_set":
			var lr := r.last_refusal
			if lr.contains(">"):
				refuse_shelf = lr.split(">")[1]
				refuse_t = 0.6

func _start_hold(n: String, wall: String) -> void:
	var rect: Rect2 = NOTICE_FOCUS.get(n, Rect2())
	if rect.size == Vector2.ZERO:
		return
	hold_rect = rect
	hold_wall = wall if wall in ["room", "curtain"] else r.notice_view(n)
	if n == "cup":
		hold_wall = "room"
	hold_t = HOLD_TIME
	hold_e = 0.0
	reveal_kind = ""
	reveal_t = -1.0
	if n == "every_bed" and motion:
		reveal_kind = "every_bed"
		reveal_prev = []
		if r.state.pillow_dented:
			reveal_prev.append("venn")
		reveal_prev.append("ives")   # band 5 had shown Venn's and Ives's on this side
		reveal_wait = 1.0
		hold_t = maxf(HOLD_TIME, 0.4 + _eight_len() + 0.4)
	elif n == "rise" and motion:
		reveal_kind = "rise"
		reveal_wait = 1.4
		hold_t = maxf(HOLD_TIME, 0.8 + _rise_len() + 0.3)

## Skip a hold: everything lands in its end state.
func _end_hold() -> void:
	hold_t = 0.0
	reveal_kind = ""
	reveal_t = -1.0

func apply_instantly() -> void:
	tint = tint_for(_band())
	shade.color = tint
	hold_t = 0.0
	zoom_k = 0.0
	reveal_kind = ""
	reveal_t = -1.0
	venn_k = 1.0
	venn_pending = false
	room.scale = Vector2.ONE
	room.position = Vector2.ZERO
	if mixer:
		mixer.snap(loop_targets())

func reset_presentation() -> void:
	hold_t = 0.0
	zoom_k = 0.0
	reveal_kind = ""
	reveal_t = -1.0
	venn_k = 1.0
	venn_pending = false
	token_on = false
	key_t = {"erase": 0.0, "append": 0.0}
	refuse_t = 0.0
	refuse_shelf = ""

func on_view_changed(before: String) -> void:
	if _view() == "c_lockers" and before != "c_lockers" and game:
		game._play_sfx_now("locker_door")

func redraw() -> void:
	room.queue_redraw()
	close.queue_redraw()

func back_visible() -> bool:
	return _view() != "room"

func esc_action() -> String:
	return "back" if _view() != "room" else "menu"

## View A only; a notice hold showing the curtain wall is view B for its moment.
func exits_active() -> bool:
	return _view() == "room" and shown_wall() == "room"

# ---------------------------------------------------------------------------
# input
# ---------------------------------------------------------------------------
## c_lockers' live controls: cards, Venn's open back (after P08), shelves, then the tray.
func lockers_controls() -> Array:
	var out := []
	for h in LOCKER_CONTROLS:
		if h[0] != "venn_back" or r.compartment_open():
			out.append(h)
	var tray := r.tray_objects()
	for i in R06Sim.TRAY_ORDER.size():
		var o: String = R06Sim.TRAY_ORDER[i]
		if o in tray:
			out.append(["obj_" + o, TRAY_CONTROLS[i][1], OBJ_LABELS[o]])
	return out

func _controls() -> Array:
	match _view():
		"room":
			return HOTSPOTS
		"curtain":
			return CURTAIN_HOTSPOTS
		"c_lockers":
			return lockers_controls()
		"c_slope":
			var out := []
			for h in SLOPE_CONTROLS:
				if h[0] != "printed_line" or r.state.card_on_rest:
					out.append(h)
			return out
	return []

func action_at(p: Vector2) -> String:
	if hold_t > 0.0:
		_end_hold()   # a click skips the hold, and does nothing else
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
	if id == "ives_letter" and r.pigeonhole_open():
		return "Ives's letter"
	for table in [_controls(), HOTSPOTS, CURTAIN_HOTSPOTS]:
		for h in table:
			if h[0] == id:
				return h[2]
	return ""

func dev_rects() -> Array:
	var out := []
	for h in _controls():
		out.append(h[1])
	return out

## The amended card's text rides under its inventory tooltip (the notebook keeps it too).
func draw_hud(c: Node2D) -> void:
	if game == null or game.hover_id != "item:amended_nora_card" or gsim().view != "room":
		return
	var s := R06Sim.AMEND_TEXT + "  A.M."
	var p := get_global_mouse_position() + Vector2(22, 72)
	var f := Ink.hand()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 20
	p.x = minf(p.x, SIZE.x - w - 4)
	c.draw_rect(Rect2(p - Vector2(10, 22), Vector2(w, 32)), Color(0.03, 0.06, 0.08, 0.8))
	c.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Ink.NIGHT_INK)

# ---------------------------------------------------------------------------
# text helpers
# ---------------------------------------------------------------------------
## Centred on x; `y` is the baseline.
func _ctext(c: CanvasItem, s: String, x: float, y: float, size: int, col: Color, font: Font = null) -> void:
	var f: Font = font if font else Ink.serif()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(f, Vector2(x - w / 2.0, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _text(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, font: Font = null) -> void:
	c.draw_string(font if font else Ink.serif(), pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## The largest size from `size` down to `floor_size` at which `s` fits `width`.
func _fit(s: String, font: Font, size: int, floor_size: int, width: float) -> int:
	while size > floor_size and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size

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

func _full(c: CanvasItem, id: String, col := Color(1, 1, 1, 1)) -> void:
	var t := _tex(id)
	if t:
		c.draw_texture_rect(t, Rect2(Vector2.ZERO, SIZE), false, col)

## A sprite by its bottom centre.
func _sprite(c: CanvasItem, id: String, bottom: Vector2, col := Color(1, 1, 1, 1)) -> void:
	var t := _tex(id)
	if t:
		c.draw_texture(t, bottom - Vector2(t.get_width() / 2.0, t.get_height()), col)

## A stencilled chevron tab on enamel: the turn to the other wall.
func _turn_tab(c: CanvasItem, hot: Rect2, right: bool) -> void:
	var tab := Rect2(hot.position + Vector2(10, 18), Vector2(hot.size.x - 20, hot.size.y - 36))
	var sb := StyleBoxFlat.new()
	sb.bg_color = ENAMEL
	sb.border_color = INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(SHADOW_NAVY, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(2, 3)
	c.draw_style_box(sb, tab)
	var ctr := tab.get_center()
	var s := 1.0 if right else -1.0
	for dx in [-10.0, 8.0]:
		var x: float = ctr.x + dx * s
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - 8 * s, ctr.y - 20), Vector2(x + 2 * s, ctr.y - 20),
			Vector2(x + 14 * s, ctr.y), Vector2(x + 2 * s, ctr.y + 20), Vector2(x - 8 * s, ctr.y + 20),
			Vector2(x + 4 * s, ctr.y)]), INK)

# ---------------------------------------------------------------------------
# drawing: the world (views A and B)
# ---------------------------------------------------------------------------
func _draw_room() -> void:
	if shown_wall() == "curtain":
		_draw_view_b(room)
	else:
		_draw_view_a(room)
	if hold_t > 0.0 and not r.is_closeup():
		var a := 0.9 if not motion else 0.9 * smoothstep(0.0, 0.3, hold_e)
		var fr := hold_rect.grow(14)
		room.draw_rect(fr, Color(INK, a * 0.85), false, 7.0)
		room.draw_rect(fr.grow(-1), Color(PAPER_HI, a), false, 2.5)

func _draw_view_a(c: CanvasItem) -> void:
	var b := _band()
	var sever := _sever()
	_full(c, plate_id("room"))
	# the fanlight: the sea, then the rain on the glass, then the glazing bars
	var fan := _tex("a_fan_sever" if sever else "a_fan_b%d" % b)
	if fan:
		if b == 7 and not sever and motion:
			# the line out there drifts: a pixel every half second, up and back within 6 px
			var step := int(time / 0.5) % 24
			var dy := float(step if step <= 6 else (12 - step if step <= 18 else step - 24))
			c.draw_texture_rect_region(fan, FAN_GLASS, Rect2(FAN_GLASS.position - Vector2(0, dy), FAN_GLASS.size))
		else:
			c.draw_texture_rect(fan, Rect2(Vector2.ZERO, SIZE), false)
	var frame := int(time * 6.0) % 2 if motion else 0
	if sever:
		_full(c, "a_fan_rain_%d" % frame, Color(1, 1, 1, 0.7))
	elif b == 1:
		_full(c, "a_fan_rain_%d" % frame)
	elif b == 2:
		_full(c, "a_fan_rain_heavy_%d" % frame)
	elif b <= 6:
		_full(c, "a_fan_rain_hang")
	_full(c, "a_fan_frame")
	# belongings: on top of the locked lockers, or home on their shelves
	for o in r.tray_objects():
		_full(c, "a_top_" + o)
	for l in R06Sim.LOCKERS:
		var o := r.placed_in(l)
		if o != "":
			_full(c, "a_in_" + o)
	if r.cup_marked():
		_full(c, "a_cup_mark")
	if r.compartment_open():
		_full(c, "a_venn_open")
	if r.dry_ring():
		_full(c, "a_dry_ring")
	for bed in A_BEDS:
		var a := dent_alpha(bed)
		if a > 0.0:
			_full(c, "a_dent_" + bed, Color(1, 1, 1, a))
	if r.cup_steam():
		var st := _tex("a_steam")
		if st:
			var alpha := 0.45
			var dx := 0.0
			if motion:
				alpha = 0.475 + 0.125 * sin(TAU * time / 3.2)
				dx = 4.0 * sin(TAU * time / 3.2 + 0.9)
			c.draw_texture(st, Vector2(98 - st.get_width() / 2.0 + dx, 512 - st.get_height()), Color(1, 1, 1, alpha))
	# the code-drawn labels on the painted blanks
	for p in PLATE_A:
		_ctext(c, p[0], p[1], 282, 15, INK, narrow)
	for p in PLATE_SHUT:
		_ctext(c, p[0], p[1], 280, 12, INK, narrow)
	for t in TAGS_A:
		_ctext(c, t[0], t[1].x, t[1].y, 14, INK, narrow)
	_turn_tab(c, HOTSPOTS[8][1], true)

func _draw_view_b(c: CanvasItem) -> void:
	var plate := plate_id("curtain")
	_full(c, plate)
	# the curtain moves a little with her breath, until something stands behind it
	if r.curtain_sways() and motion:
		var pt := _tex(plate)
		if pt:
			var sway := 2.0 * sin(TAU * time / 7.0)
			var y := CURTAIN_BOX.position.y
			while y < CURTAIN_BOX.end.y:
				var h := minf(16.0, CURTAIN_BOX.end.y - y)
				var dx := sway * (y - CURTAIN_BOX.position.y) / CURTAIN_BOX.size.y
				c.draw_texture_rect_region(pt, Rect2(CURTAIN_BOX.position.x + dx, y, CURTAIN_BOX.size.x, h),
					Rect2(CURTAIN_BOX.position.x, y, CURTAIN_BOX.size.x, h))
				y += h
	if r.pigeonhole_open():
		_full(c, "b_pigeonhole_open")
	for bed in B_BEDS:
		var a := dent_alpha(bed)
		if a > 0.0:
			_full(c, "b_dent_" + bed, Color(1, 1, 1, a))
	if r.curtain_shape():
		_full(c, "b_curtain_shape")
	for t in TAGS_B:
		_ctext(c, t[0], t[1].x, t[1].y, 14, INK, narrow)
	_draw_calendar(c)
	Ink.handwriting(c, "N.B.", 4, Vector2(1264, 582), 14, 3, false, GRAPHITE)
	_turn_tab(c, CURTAIN_HOTSPOTS[7][1], false)

func _draw_calendar(c: CanvasItem) -> void:
	_ctext(c, R06Sim.CAL_HEADER, 640, 178, 16, INK, narrow)
	var names := r.calendar_names()
	var hand := r.calendar_hand()
	for k in R06Sim.CALENDAR_DATES.size():
		var y := 196.0 + 38.0 * k + 27.0
		_ctext(c, R06Sim.CALENDAR_DATES[k], 544, y, 20, INK)
		var n: String = names[k] if k < names.size() else ""
		if n == "":
			continue
		match hand:
			"many":
				var hh: Array = MANY_HANDS[k]
				Ink.handwriting(c, n, n.length(), Vector2(590, y), hh[0], 40 + k, false, hh[2], null, hh[1])
			"ada":
				Ink.handwriting(c, n, n.length(), Vector2(590, y), 22, 7, false, Ink.BLUE_INK)
			_:
				_text(c, n.to_upper(), Vector2(590, y), 19, INK, narrow)

# ---------------------------------------------------------------------------
# drawing: close-ups (layer 5)
# ---------------------------------------------------------------------------
func _draw_close() -> void:
	match _view():
		"c_lockers":
			_draw_lockers(close)
		"c_slope":
			_draw_slope(close)

func _draw_lockers(c: CanvasItem) -> void:
	_full(c, "c_lockers")
	var serif := Ink.serif()
	for l in R06Sim.LOCKERS:
		var x: float = LOCKER_X[l]
		_ctext(c, l.to_upper(), x + 150, 162, 30, INK, serif)
		# the card: each sentence wrapped to the holder, centred in it
		var lines := []
		for s in R06Sim.CARD_TEXT[l]:
			lines.append_array(_wrap(s, serif, 19, CARD_WRAP))
		var lh := 19 * 1.25
		var y0 := 202.0 + (148.0 - lh * lines.size()) / 2.0 + 17.0
		for i in lines.size():
			_text(c, lines[i], Vector2(x + 150 - CARD_WRAP / 2.0, y0 + lh * i), 19, INK, serif)
		var o := r.placed_in(l)
		if o != "":
			_sprite(c, SPRITE[o], Vector2(SHELF_CX[l], SHELF_Y))
	if r.compartment_open():
		_full(c, "c_venn_open", Color(1, 1, 1, venn_k if not venn_pending else 0.0))
		if token_on and not venn_pending:
			var tk := _tex("c_token_rubbing")
			if tk:
				c.draw_texture(tk, TOKEN_AT, Color(1, 1, 1, venn_k))
	var pd := _tex("c_plate_down")
	for l in R06Sim.LOCKERS:
		var x: float = LOCKER_X[l]
		if pd and r.placed_in(l) != "":
			c.draw_texture(pd, Vector2(x + 130, 586))
		if refuse_t > 0.0 and refuse_shelf == l:
			# the refused shelf: a pale chalk frame that fades, readable on the dark interior
			var a := refuse_t / 0.6
			var fr := Rect2(x + 14, 380, 272, 416)
			c.draw_rect(fr, Color(SHADOW_NAVY, 0.6 * a), false, 8.0)
			c.draw_rect(fr, Color(PAPER_HI, 0.9 * a), false, 3.0)
	if r.cup_marked():
		var cm := _tex("c_cup_mark")
		if cm:
			c.draw_texture(cm, CUP_MARK_AT)
	# the tray: what's still on top of the locked lockers; the lifted one rides above its slot
	var tray := r.tray_objects()
	for i in R06Sim.TRAY_ORDER.size():
		var o: String = R06Sim.TRAY_ORDER[i]
		if not o in tray:
			continue
		var at := Vector2(TRAY_X[i], TRAY_Y)
		if r.lifted == o:
			var slot := Rect2(at.x - 74, TRAY_Y - 9, 148, 14)
			var sb := StyleBoxFlat.new()
			sb.draw_center = false
			sb.border_color = FELT_HI
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(6)
			c.draw_style_box(sb, slot)
			for k in 4:
				var rx := 70.0 - 12.0 * k
				c.draw_colored_polygon(Ink.ellipse(at + Vector2(0, -2), rx, 9.0 - 1.5 * k, 32),
					Color(SHADOW_NAVY, 0.10))
			_sprite(c, SPRITE[o], at - Vector2(0, LIFT_PX))
		else:
			_sprite(c, SPRITE[o], at)

func _draw_slope(c: CanvasItem) -> void:
	_full(c, "c_slope")
	_ctext(c, "RECORD", 400, 184, 22, INK, narrow)
	_ctext(c, "EVIDENCE", 1048, 184, 22, INK, narrow)
	var st: Dictionary = r.state
	if st.card_on_rest:
		var card := _tex("c_card")
		if card:
			c.draw_texture(card, Vector2(200, 260))
		# clear of the card's punched hole (painted at 230, 296)
		_text(c, R06Sim.REGISTER_TEXT[0], Vector2(250, 330), 30, INK, serif_bold)
		_text(c, R06Sim.REGISTER_TEXT[1], Vector2(230, 380), 22, INK)
		_text(c, R06Sim.REGISTER_TEXT[2], Vector2(230, 478), 22, INK)
		var box := Rect2(470, 276, 120, 44)
		c.draw_rect(box, INK, false, 2.0)
		c.draw_rect(box.grow(-3), Color(INK, 0.6), false, 1.0)
		_ctext(c, R06Sim.REGISTER_STAMP, box.get_center().x, box.get_center().y + 6, 16, INK, narrow)
	if st.sketch_on_rest:
		var sk := _tex("c_sketch")
		if sk:
			c.draw_texture(sk, Vector2(848, 260))
		Ink.handwriting(c, R06Sim.SKETCH_TEXT, R06Sim.SKETCH_TEXT.length(), Vector2(880, 520), 22, 11, false,
			Ink.BLUE_INK)
		_text(c, "(copied from N. Bell's book)", Vector2(880, 548), 14, INK)
	for i in 3:
		var s := r.wheel_text(i)
		var w: Array = WHEEL_X[i]
		var size := _fit(s, narrow, 20, 16, w[1] - w[0] - 8)
		if narrow.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w[1] - w[0] - 8:
			size = _fit(s, narrow, size, 13, w[1] - w[0] - 8)
		_ctext(c, s, (w[0] + w[1]) / 2.0, WHEEL_BASE, size, INK, narrow)
	for k in [["erase", 160.0, "ERASE"], ["append", 1008.0, "APPEND"]]:
		var down: bool = key_t[k[0]] > 0.0
		var x0: float = k[1]
		if down:
			var kd := _tex("c_key_down")
			if kd:
				c.draw_texture(kd, Vector2(x0, 820))
		_ctext(c, k[2], x0 + 140, 880 + (10 if down else 0), 26, INK, narrow)
