extends RoomView
## R03, the Chart Room: renders R03Sim, plays its events, owns its light and loops.
##
## Layering (inside the game's world layer):
##   this node (under the CanvasModulate): the wall Ada faces, its overlays, the view-drawn
##     marks (sheet crosses, drum trace, plates, hatch scratches) and the notice frame
##   CanvasLayer 5 "close": the three close-ups, always at full brightness
## Three walls share local_view "room"; the sim's `wall` says which one is drawn. Everything
## timed here (holds, fades, typing, the drum's scroll) is presentation and never saved.

## Wall A (the chart table). First match wins, so small objects precede large ones.
const HOTSPOTS := [
	["empty_clip", Rect2(860, 176, 150, 72), "Empty clip"],
	["clip_tin", Rect2(560, 760, 150, 96), "Clip tin"],
	["compass", Rect2(1140, 150, 200, 200), "Compass rose"],
	["plan_wall", Rect2(110, 150, 340, 420), "Station plan"],
	["sheet_table", Rect2(520, 240, 560, 500), "Chart table"],
]
## Wall B (the recorder wall).
const WALL_HOTSPOTS_B := [
	["pen_drum", Rect2(520, 230, 420, 170), "Recorder pen"],
	["seal", Rect2(560, 560, 340, 120), "Closure seal"],
	["plate_rack", Rect2(1060, 420, 220, 280), "Plate rack"],
	["sea_window", Rect2(110, 150, 300, 440), "Sea window"],
	["recorder", Rect2(470, 200, 520, 680), "Tide recorder"],
]
## Wall C (the hatch wall).
const WALL_HOTSPOTS_C := [
	["hatch_scratches", Rect2(470, 380, 84, 380), "Hatch frame"],
	["outer_window", Rect2(1000, 380, 300, 300), "Window by the hatch"],
	["hatch", Rect2(570, 360, 360, 520), "Observation hatch"],
]
const WALL_HOTSPOTS := {"A": HOTSPOTS, "B": WALL_HOTSPOTS_B, "C": WALL_HOTSPOTS_C}
const TURN_RECTS := {"turn_left": Rect2(16, 430, 72, 200), "turn_right": Rect2(1360, 430, 72, 200)}
const WALL_NAMES := {"A": "Chart wall", "B": "Recorder wall", "C": "Hatch wall"}
## Where each exit is clicked. The core draws these as tabs on the HUD layer.
const EXIT_RECTS := {
	"R02": Rect2(20, 922, 250, 64),
	"R04": Rect2(282, 922, 270, 64),
	"R11": Rect2(1178, 922, 250, 64),
}

## Ambient light per weather band. Never below 0.74: the dread is in what is seen.
const MODULATE := [Color(0.97, 0.98, 1.00), Color(0.92, 0.93, 0.97), Color(0.88, 0.90, 0.95),
	Color(0.85, 0.87, 0.93), Color(0.82, 0.84, 0.92), Color(0.79, 0.81, 0.90),
	Color(0.77, 0.79, 0.90), Color(0.74, 0.77, 0.90)]
const WINDOW_GLASS := Rect2(134, 174, 252, 392)
const WINDOW_LIGHT := Color(0.72, 0.84, 0.96)

const VENN_INK := Color("1b2650")      # Venn's blue-black
const PALE := Color(0.93, 0.95, 0.97)   # the notice frame's pale ink
const COPPER_FILL := Color8(97, 125, 116)

# --- wall A: the pinned sheet, sheet-local x0.8 -----------------------------------
const SHEET_RECT := Rect2(560, 266, 480, 448)
const SHEET_K := 0.8

# --- shared sheet geometry (sheet-local, 600x560) ----------------------------------
const CROSSES := {"lighthouse": Vector2(150, 150), "buoy": Vector2(440, 190), "datum": Vector2(300, 430)}
const CROSS_LABELS := {"lighthouse": "LIGHTHOUSE", "buoy": "BUOY", "datum": "DATUM STONE"}
const NORTH_AT := Vector2(530, 470)
const BANDS_Y := [80, 176, 272, 368, 464, 560]
const CURVE_17 := [Vector2(20, 200), Vector2(80, 212), Vector2(140, 228), Vector2(200, 250),
	Vector2(250, 272), Vector2(280, 290), Vector2(300, 300)]
const CURVE_14 := [Vector2(20, 110), Vector2(150, 130), Vector2(300, 150), Vector2(450, 140), Vector2(580, 120)]
const VENN_BRACKET := [Vector2(300, 300), Vector2(322, 300), Vector2(322, 350), Vector2(344, 350)]
const VENN_LINKED := [Vector2(360, 330), Vector2(380, 350), Vector2(392, 338), Vector2(412, 358)]
const VENN_LOOP_C := Vector2(450, 330)
const VENN_LOOP_R := 16.0
const VENN_EXIT := [Vector2(470, 346), Vector2(520, 360), Vector2(580, 366)]
const VENN_CENTRE := Vector2(300, 280)
const UNSNAPPED := Vector2(38, 26)

# --- c_registration ------------------------------------------------------------------
const REG_SHEET := Rect2(424, 170, 600, 560)
const REG_CONTROLS := [
	["reg_base_14", Rect2(84, 170, 240, 90), "14 OCT"],
	["reg_base_17", Rect2(84, 280, 240, 90), "17 OCT"],
	["reg_lay", Rect2(84, 430, 240, 90), "Lay Venn's sheet"],
	["reg_example", Rect2(84, 600, 240, 260), "Example"],
	["reg_rot_ccw", Rect2(1124, 300, 130, 90), "Turn left"],
	["reg_rot_cw", Rect2(1274, 300, 130, 90), "Turn right"],
	["reg_snap_lighthouse", Rect2(1124, 440, 280, 76), "His LIGHTHOUSE"],
	["reg_snap_buoy", Rect2(1124, 526, 280, 76), "His BUOY"],
	["reg_snap_datum", Rect2(1124, 612, 280, 76), "His DATUM STONE"],
	["reg_clip", Rect2(1124, 740, 280, 100), "CLIP"],
]
const REG_TABLE := Rect2(374, 130, 700, 650)
const REG_PANEL := Rect2(1112, 282, 306, 576)

# --- c_recorder ----------------------------------------------------------------------
const DRUM_TEXT := Rect2(260, 130, 920, 190)
const CAL_PLATE := Rect2(224, 360, 520, 76)
const WHEEL_WIN := [Rect2(254, 520, 150, 150), Rect2(494, 520, 150, 150)]
const REC_CONTROLS := [
	["rec_zero_up", Rect2(269, 452, 120, 64)],
	["rec_zero_down", Rect2(269, 678, 120, 64)],
	["rec_int_up", Rect2(509, 452, 120, 64)],
	["rec_int_down", Rect2(509, 678, 120, 64)],
	["rec_calibrate", Rect2(724, 470, 110, 400)],
	["rec_plate_info", Rect2(224, 360, 520, 76)],
]
const GAUGES := [Rect2(234, 770, 190, 150), Rect2(474, 770, 190, 150)]
const SEAL_RECT := Rect2(234, 440, 430, 320)
const REC_MINIATURE := Rect2(904, 370, 460, 90)
const REC_SLOTS := [Rect2(924, 490, 130, 150), Rect2(1069, 490, 130, 150), Rect2(1214, 490, 130, 150)]
const REC_HOMES := [Rect2(924, 680, 130, 130), Rect2(1069, 680, 130, 130), Rect2(1214, 680, 130, 130)]
const REC_RECORD := Rect2(1034, 840, 240, 90)
const REC_SHUTTER := Rect2(884, 470, 500, 470)
const PLATE_WORDS := {"boundary": "BOUNDARY", "relation": "RELATION", "observer": "OBSERVER"}
const TYPE_CPS := 14.0

# --- c_plan --------------------------------------------------------------------------
const PLAN_PAPER := Rect2(220, 100, 1000, 800)
const PLAN_ROOMS := [
	["LANTERN GALLERY", Rect2(650, 150, 140, 60)],
	["CHART ROOM", Rect2(640, 220, 160, 90)],
	["LISTENING ROOM", Rect2(520, 350, 180, 120)],
	["WET LABORATORY", Rect2(740, 350, 180, 120)],
	["MACHINE ROOM", Rect2(740, 480, 180, 60)],
	["INTAKE OFFICE", Rect2(480, 720, 200, 110)],
	["RECORDS VAULT", Rect2(760, 720, 200, 110)],
	["JETTY", Rect2(1000, 760, 180, 40)],
	["KITCHEN & MESS", Rect2(270, 360, 170, 90)],
	["BUNK ROOM", Rect2(270, 480, 170, 90)],
]
const PLAN_CHAMBER := Rect2(660, 570, 120, 110)
const PLAN_ZONES := {
	"chart": Rect2(620, 140, 200, 180), "lab": Rect2(500, 340, 440, 210),
	"centre": Rect2(640, 560, 160, 130), "office": Rect2(460, 710, 520, 130),
}
const PLAN_MARGINS := [["plan_margin_kitchen", Rect2(270, 360, 170, 90)], ["plan_margin_bunks", Rect2(270, 480, 170, 90)]]
const PLAN_HOMES := {
	"body": Rect2(1250, 200, 170, 84), "place": Rect2(1250, 300, 170, 84),
	"name": Rect2(1250, 400, 170, 84), "witness": Rect2(1250, 500, 170, 84),
}
const PLAN_FIX := Rect2(1260, 760, 150, 110)
## Where a misplaced tile's reference card sits, beside its zone.
const PLAN_CARD_AT := {
	"chart": Vector2(830, 236), "lab": Vector2(948, 402), "centre": Vector2(810, 600), "office": Vector2(980, 820),
}
const PLAN_MARGIN_TEXT := "Three frames. One witness. The copy port left bare."
const NAME_CPS := 6.0

## Notice regions: [rect, kind]; "sheet" means the board sheet on wall A.
const NOTICE_RECTS := {
	"n_arrival": Rect2(540, 250, 380, 120), "n_b3": Rect2(540, 250, 380, 120), "n_b5": Rect2(540, 250, 380, 120),
	"n_threshold": Rect2(560, 560, 340, 120), "n_p04": Rect2(570, 360, 730, 520),
	"n_b4": Rect2(560, 266, 480, 448), "n_b5_prints": Rect2(690, 890, 220, 110),
	"n_b6": Rect2(110, 150, 340, 420), "n_b7": Rect2(1000, 380, 300, 300),
}
const HOLD_TIME := 1.5

## Ambient loops.
const LOOPS := ["r03_room", "r03_sea", "r03_rain", "r03_scratch", "r03_drum", "r03_pressure", "r03_stair_air"]
const SFX_DB := {
	"turn": -14.0, "sheet_slide": -10.0, "sheet_rotate": -11.0, "cross_snap": -9.0, "clip_snap": -5.0,
	"clip_refuse": -8.0, "tin_open": -8.0, "wheel_click": -9.0, "lever_pull": -6.0, "lever_refuse": -5.0,
	"calibrate_ratchet": -5.0, "hatch_open": -4.0, "plate_pick": -10.0, "plate_set": -8.0,
	"record_key": -7.0, "record_refuse": -8.0, "relay_clack": -5.0, "far_bell": -9.0, "strip_print": -8.0,
	"strip_print_last": -8.0, "tile": -10.0, "fix_pin": -6.0, "plan_resolve": -6.0, "name_print": -7.0,
	"glass_press": -6.0, "motif_short": -14.0,
}
const SFX_SOFT := ["hatch_open", "relay_clack", "lever_refuse", "glass_press"]

## R03's own sim, typed.
var r3: R03Sim:
	get:
		return sim as R03Sim

var textures := {}
static var _narrow: SystemFont

# nodes
var shade: CanvasModulate
var window_light: PointLight2D
var close: Node2D
var reg_sheets: Control
var close_top: Node2D
var mixer: LoopMixer

# presentation (never saved)
var reg_origin := Vector2.ZERO
var hold_id := ""          # the notice being held
var hold_t := -1.0         # seconds into the hold; < 0 while waiting for the tide card
var drum_t := 0.0          # seconds the drum has scrolled
var comp_k := 1.0          # 0..1 the composite curve's fade
var plan_k := 1.0          # 0..1 the plan body's fade
var plan_fading := false
var strip_live := false    # the strip is being printed this visit
var strip_cue := 0         # 1 strip_print, 2 strip_print_last, 3 the second relay clack
var strip_chars := 0.0     # characters typed across the strip's lines
var name_live := false     # ADA MERCER waits for its cue
var name_chars := 0.0

func _ready() -> void:
	_load_textures()
	_build_nodes()
	mixer = LoopMixer.new()
	add_child(mixer)
	for id in LOOPS:
		mixer.add_loop(id, game.load_audio(id) if game else null)
	apply_instantly()

# ---------------------------------------------------------------------------
# setup
# ---------------------------------------------------------------------------
func _load_textures() -> void:
	for n in ["A_base", "A_composite", "A_compass_bent", "A_standing", "A_plan_body",
			"B_base", "B_p05", "B_pen", "B_rain_a", "B_rain_b", "B_rain_c", "B_seal_broken", "B_seal_intact",
			"B_strip", "B_window_0", "B_window_1", "B_window_2", "B_window_3", "B_window_4", "B_window_5",
			"B_window_6", "B_window_7", "C_base", "C_hatch_open", "C_line", "C_window_7",
			"cu_plan", "cu_plan_body", "cu_plan_lid", "cu_recorder", "cu_recorder_shutter", "cu_registration",
			"cu_seal", "cu_seal_broken", "plate_blank", "sheet_paper", "sheet_tracing", "tile_blank"]:
		var path := "res://assets/rooms/R03/%s.png" % n
		if ResourceLoader.exists(path):
			var t := load(path) as Texture2D
			if t:
				textures[n] = t

func _tex(id: String) -> Texture2D:
	return textures.get(id)

func _build_nodes() -> void:
	shade = CanvasModulate.new()
	shade.color = MODULATE[0]
	add_child(shade)
	# Wall B's sea window makes its own cool light, shaped to the glass.
	window_light = PointLight2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.6))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 256
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	window_light.texture = gt
	window_light.texture_scale = 2.6
	window_light.position = WINDOW_GLASS.get_center() + Vector2(40, 40)
	window_light.color = WINDOW_LIGHT
	window_light.energy = 0.0
	add_child(window_light)
	var close_layer := CanvasLayer.new()
	close_layer.layer = 5
	add_child(close_layer)
	close = Node2D.new()
	close_layer.add_child(close)
	close.draw.connect(_draw_close)
	# The light table clips the sheets: a sheet pinned wrong slides off it, not over the controls.
	reg_sheets = Control.new()
	reg_sheets.position = REG_TABLE.position
	reg_sheets.size = REG_TABLE.size
	reg_sheets.clip_contents = true
	reg_sheets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close.add_child(reg_sheets)
	reg_sheets.draw.connect(_draw_reg_sheets)
	close_top = Node2D.new()
	close.add_child(close_top)
	close_top.draw.connect(_draw_close_top)

static func narrow() -> Font:
	if _narrow == null:
		_narrow = SystemFont.new()
		_narrow.font_names = PackedStringArray(["Liberation Sans Narrow", "Nimbus Sans Narrow",
			"DejaVu Sans Condensed", "Ubuntu Condensed", "sans-serif"])
	return _narrow

func _band() -> int:
	return clampi(gsim().weather_band(), 0, 7) if gsim() else 0

func _flag(f: String) -> bool:
	return gsim().flag(f) if gsim() else false

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------
func tick(dt: float) -> void:
	if r3 == null:
		return
	var band := _band()
	shade.color = MODULATE[band]
	window_light.energy = _window_energy(band) if r3.local_view == "room" and r3.wall == "B" else 0.0
	_tick_hold(dt)
	if r3.drum_turning() and motion:
		drum_t += dt
	if comp_k < 1.0:
		comp_k = minf(1.0, comp_k + dt / 0.8) if motion else 1.0
	if plan_fading and plan_k < 1.0 and motion:
		plan_k = minf(1.0, plan_k + dt / 4.0)
	_tick_typing(dt)
	_tick_audio(dt)
	queue_redraw()
	_redraw_close()

func _redraw_close() -> void:
	close.queue_redraw()
	reg_sheets.queue_redraw()
	close_top.queue_redraw()

func _window_energy(band: int) -> float:
	return [0.16, 0.14, 0.14, 0.16, 0.18, 0.2, 0.24, 0.28][band]

func _tick_hold(dt: float) -> void:
	if hold_id == "":
		return
	if hold_t < 0.0:
		# The core's tide card plays first.
		if game and game.tide_card_t < GameView.TIDE_CARD_TIME and game.tide_card_n > 0:
			return
		_start_hold()
		return
	hold_t += dt
	if hold_t >= HOLD_TIME:
		hold_id = ""
		hold_t = -1.0

func _start_hold() -> void:
	hold_t = 0.0
	if game:
		if hold_id == "n_threshold":
			game._play_sfx_now("motif_short")
		elif hold_id == "n_b7":
			game._play_sfx_now("glass_press")

func holding() -> bool:
	return hold_id != ""

func _tick_typing(dt: float) -> void:
	if strip_live:
		var lines := r3.strip_lines()
		var cap := _strip_cap(lines)
		if motion:
			strip_chars = minf(strip_chars + dt * TYPE_CPS, float(cap))
		else:
			strip_chars = float(cap)
		if strip_cue >= 3 and strip_chars >= _strip_total(lines):
			strip_live = false
	if name_live and name_chars >= 0.0:
		name_chars = name_chars + dt * NAME_CPS if motion else 99.0

## How many characters the strip may show by now: the head and three moves after the first
## print, line 4 after the last print, the relay's reply after the second clack.
func _strip_cap(lines: Array) -> int:
	var upto := 0
	if strip_cue >= 1:
		upto = mini(4, lines.size())
	if strip_cue >= 2:
		upto = mini(5, lines.size())
	if strip_cue >= 3:
		upto = lines.size()
	var n := 0
	for i in upto:
		n += String(lines[i]).length()
	return n

func _strip_total(lines: Array) -> int:
	var n := 0
	for l in lines:
		n += String(l).length()
	return n

## The visible part of each strip line.
func strip_visible() -> Array:
	var lines := r3.strip_lines()
	if not strip_live:
		return lines
	var out := []
	var left := int(strip_chars)
	for l in lines:
		var s := String(l)
		if left <= 0:
			break
		out.append(s.substr(0, mini(left, s.length())))
		left -= s.length()
	return out

func _tick_audio(dt: float) -> void:
	var t := audio_targets()
	mixer.tick(t, {}, dt)
	var rain: AudioStreamPlayer = mixer.players.get("r03_rain")
	if rain:
		rain.pitch_scale = _rain_rate()

func _rain_rate() -> float:
	match _band():
		3:
			return 0.6
		4:
			return 0.5
	return 1.0

## The ambient mix for the current state and wall (tests read this).
func audio_targets() -> Dictionary:
	var band := _band()
	var p04 := _flag("P04")
	var w := r3.wall
	var t := {}
	t["r03_room"] = 0.35 if band >= 7 else 0.55
	var sea: float = 0.0 if band >= 5 else [0.6, 0.6, 0.55, 0.5, 0.4][band]
	if w == "C" and p04:
		sea = 0.0
	t["r03_sea"] = sea
	t["r03_rain"] = {1: 0.5, 2: 0.6, 3: 0.4, 4: 0.3}.get(band, 0.0)
	if not p04:
		t["r03_scratch"] = 0.6 if w == "B" else 0.35
	elif band < 5:
		t["r03_scratch"] = 0.0
	else:
		t["r03_scratch"] = 0.3 if band >= 7 else 0.45
	t["r03_drum"] = (0.45 if w == "B" else 0.25) if p04 and band < 5 else 0.0
	t["r03_pressure"] = 0.6 if band >= 7 else 0.0
	t["r03_stair_air"] = 0.25 if w == "C" and p04 else 0.0
	return t

# ---------------------------------------------------------------------------
# hooks
# ---------------------------------------------------------------------------
func back_visible() -> bool:
	return r3.is_closeup()

func esc_action() -> String:
	if holding():
		return ""
	return "back" if r3.is_closeup() else "menu"

func chain_gates() -> bool:
	return true

func exits_active() -> bool:
	return r3.local_view == "room" and not holding()

func apply_instantly() -> void:
	if r3 == null:
		return
	hold_id = ""
	hold_t = -1.0
	comp_k = 1.0
	plan_k = 1.0
	plan_fading = false
	strip_live = false
	strip_cue = 3
	name_live = false
	name_chars = 99.0
	var band := _band()
	shade.color = MODULATE[band]
	window_light.energy = _window_energy(band) if r3.local_view == "room" and r3.wall == "B" else 0.0
	mixer.snap(audio_targets())
	queue_redraw()
	_redraw_close()

func reset_presentation() -> void:
	hold_id = ""
	hold_t = -1.0
	comp_k = 1.0
	plan_k = 1.0
	plan_fading = false
	strip_live = false
	strip_cue = 3
	strip_chars = 0.0
	name_live = false
	name_chars = 99.0

func play_fx(id: String, e: Dictionary) -> void:
	match id:
		"notice":
			hold_id = String(e.get("notice", ""))
			hold_t = -1.0
			if hold_id != "" and not NOTICE_RECTS.has(hold_id):
				hold_id = ""
			if hold_id != "":
				_tick_hold(0.0)
		"composite":
			comp_k = 0.0 if motion else 1.0
		"drum_turn":
			drum_t = 0.0
		"strip_print":
			strip_live = true
			strip_cue = 0
			strip_chars = 0.0
		"plan_resolve":
			plan_fading = true
			plan_k = 0.0
			name_live = true
			name_chars = -1.0
	queue_redraw()
	_redraw_close()

func on_sfx(id: String) -> void:
	match id:
		"strip_print":
			if strip_live:
				strip_cue = maxi(strip_cue, 1)
		"strip_print_last":
			if strip_live:
				strip_cue = maxi(strip_cue, 2)
		"relay_clack":
			if strip_live and strip_cue >= 2:
				strip_cue = 3
		"plan_resolve":
			if plan_fading and not motion:
				plan_k = 1.0   # still: plain, then resolved on the cue
		"name_print":
			if name_live:
				name_chars = 0.0 if motion else 99.0

# ---------------------------------------------------------------------------
# hit testing
# ---------------------------------------------------------------------------
func _wall_list() -> Array:
	return WALL_HOTSPOTS.get(r3.wall, HOTSPOTS)

func action_at(p: Vector2) -> String:
	if holding():
		# A click skips the hold and does nothing else.
		hold_id = ""
		hold_t = -1.0
		return ""
	match r3.local_view:
		"room":
			for t in TURN_RECTS:
				if TURN_RECTS[t].has_point(p):
					return t
			for h in _wall_list():
				if h[1].has_point(p):
					return h[0]
		"c_registration":
			return _reg_action(p)
		"c_recorder":
			return _rec_action(p)
		"c_plan":
			return _plan_action(p)
	return ""

func hover_at(p: Vector2) -> String:
	if holding() or r3 == null:
		return ""
	if r3.local_view == "room":
		for t in TURN_RECTS:
			if TURN_RECTS[t].has_point(p):
				return t
		for h in _wall_list():
			if h[1].has_point(p):
				return h[0]
		return ""
	return action_at(p)

func label_for(id: String) -> String:
	if TURN_RECTS.has(id) and r3:
		return _turn_label(id)
	for w in WALL_HOTSPOTS:
		for h in WALL_HOTSPOTS[w]:
			if h[0] == id:
				return h[2]
	return ""

func _turn_label(t: String) -> String:
	var dest: String = R03Sim.TURNS[r3.wall][t]
	return ("◂ " + WALL_NAMES[dest]) if t == "turn_left" else (WALL_NAMES[dest] + " ▸")

func hotspot_rect(id: String) -> Rect2:
	if TURN_RECTS.has(id):
		return TURN_RECTS[id]
	for w in WALL_HOTSPOTS:
		for h in WALL_HOTSPOTS[w]:
			if h[0] == id:
				return h[1]
	return Rect2()

func dev_rects() -> Array:
	var out := []
	match r3.local_view:
		"room":
			for h in _wall_list():
				out.append(h[1])
			for t in TURN_RECTS:
				out.append(TURN_RECTS[t])
		"c_registration":
			for c0 in REG_CONTROLS:
				out.append(c0[1])
			out.append(REG_TABLE)
		"c_recorder":
			for c0 in REC_CONTROLS:
				out.append(c0[1])
			out += REC_SLOTS + REC_HOMES + [REC_MINIATURE, REC_RECORD, SEAL_RECT]
		"c_plan":
			for z in PLAN_ZONES:
				out.append(PLAN_ZONES[z])
			for t in PLAN_HOMES:
				out.append(PLAN_HOMES[t])
			out.append(PLAN_FIX)
	return out

func _reg_action(p: Vector2) -> String:
	var st: Dictionary = r3.state
	for c0 in REG_CONTROLS:
		if c0[1].has_point(p):
			if c0[0] == "reg_lay" and st.reg_laid:
				return "reg_lift"
			return c0[0]
	if st.reg_laid and not st.p03_complete:
		var xf := _venn_screen_xform()
		for k in CROSSES:
			var at: Vector2 = xf * CROSSES[k]
			if REG_TABLE.has_point(at) and at.distance_to(p) <= 34.0:
				return "reg_snap_" + k
	if REG_TABLE.has_point(p):
		return "reg_table"
	return ""

func _rec_action(p: Vector2) -> String:
	var t1x := _flag("t1x_threshold_crossed")
	if not t1x and SEAL_RECT.has_point(p):
		return "rec_seal"
	for c0 in REC_CONTROLS:
		if c0[1].has_point(p):
			return c0[0]
	if not r3.state.p04_complete:
		if REC_SHUTTER.has_point(p):
			return "rec_shutter"
	else:
		if REC_MINIATURE.has_point(p):
			return "rec_miniature"
		for i in 3:
			if REC_SLOTS[i].has_point(p):
				return "rec_slot_%d" % i
		for i in 3:
			if REC_HOMES[i].has_point(p):
				return "rec_plate_" + R03Sim.RACK_HOME[i]
		if REC_RECORD.has_point(p):
			return "rec_record"
	if SEAL_RECT.has_point(p):
		return "rec_seal"
	return ""

## The rect a placed tile is drawn at: centred in its zone, 150x70 in the centre zone.
func tile_rect(zone: String) -> Rect2:
	var z: Rect2 = PLAN_ZONES[zone]
	var size := Vector2(150, 70) if zone == "centre" else Vector2(170, 84)
	return Rect2(z.get_center() - size / 2.0, size)

func _plan_action(p: Vector2) -> String:
	var ps := r3.plan_state()
	for t in R03Sim.TILES:
		var z: String = ps.tiles[t]
		if z != "" and tile_rect(z).has_point(p):
			return "plan_tile_" + t
	for t in R03Sim.TILES:
		if PLAN_HOMES[t].has_point(p) and (t in ps.tray or ps.held == t):
			return "plan_tile_" + t
	for z in PLAN_ZONES:
		if PLAN_ZONES[z].has_point(p):
			return "plan_zone_" + z
	for m in PLAN_MARGINS:
		if m[1].has_point(p):
			return m[0]
	if PLAN_FIX.has_point(p):
		return "plan_fix"
	return ""

# ---------------------------------------------------------------------------
# drawing: the walls
# ---------------------------------------------------------------------------
func _draw() -> void:
	if r3 == null or r3.is_closeup():
		return
	match r3.wall:
		"A":
			_draw_wall_a()
		"B":
			_draw_wall_b()
		"C":
			_draw_wall_c()
	_draw_notice_frame()

func _plate(id: String) -> bool:
	var t := _tex(id)
	if t:
		draw_texture(t, Vector2.ZERO)
		return true
	return false

func _placeholder(list: Array) -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("b8c9b4"))
	draw_rect(Rect2(0, 600, SIZE.x, 300), Color("2f5b6e"))
	draw_rect(Rect2(0, 900, SIZE.x, 186), Color("7d6e5c"))
	for h in list:
		draw_rect(h[1], Color(Ink.PAPER, 0.92))
		draw_rect(h[1], Ink.INK, false, 3.0)
		Ink.wrapped(self, h[2], h[1].position + Vector2(12, 34), 22, Ink.INK, h[1].size.x - 24)

func _sl(p: Vector2) -> Vector2:
	return SHEET_RECT.position + p * SHEET_K

func _sl_pts(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_sl(p))
	return out

func _draw_wall_a() -> void:
	var band := _band()
	if not _plate("A_base"):
		_placeholder(HOTSPOTS)
	if _flag("P03"):
		_plate("A_composite")
	_draw_board_sheet()
	if band >= 4:
		_plate("A_compass_bent")
	if band >= 5:
		_plate("A_standing")
	if _flag("P21"):
		_plate("A_plan_body")

## The 17 Oct sheet pinned on the board: crosses, north, date, bands, its half of the curve;
## after P03 the whole composite in Venn's ink.
func _draw_board_sheet() -> void:
	var nf := narrow()
	for k in CROSSES:
		_cross(self, _sl(CROSSES[k]), 9.0, Ink.INK, 2.5)
	_north(self, _sl(NORTH_AT), 70.0 * SHEET_K, Ink.INK, 18)
	Ink.text(self, "17 OCT 1931", _sl(Vector2(24, 36)) + Vector2(0, 2), 20, Ink.INK, nf, 200, HORIZONTAL_ALIGNMENT_LEFT)
	for i in 5:
		var y: float = (BANDS_Y[i] + BANDS_Y[i + 1]) / 2.0
		Ink.text(self, str(i + 1), _sl(Vector2(566, y)) + Vector2(-8, 7), 20, Ink.INK, nf, 30)
		draw_line(_sl(Vector2(548, BANDS_Y[i + 1])), _sl(Vector2(596, BANDS_Y[i + 1])), Color(Ink.INK, 0.5), 1.5)
	draw_polyline(_sl_pts(CURVE_17), Ink.INK, 3.0, true)
	if _flag("P03"):
		_composite_curve(self, Callable(self, "_sl"), VENN_INK, 3.5, 1.0)

func _draw_wall_b() -> void:
	var band := _band()
	var t1x := _flag("t1x_threshold_crossed")
	var p04 := _flag("P04")
	var p05 := _flag("P05")
	if not _plate("B_base"):
		_placeholder(WALL_HOTSPOTS_B)
	_plate("B_window_%d" % band)
	if band >= 1 and band <= 5:
		var frame := 0
		if motion:
			var period := 0.22 if band <= 2 else 0.6
			frame = int(time / period) % 3
		_plate(["B_rain_a", "B_rain_b", "B_rain_c"][frame])
	_plate("B_seal_broken" if t1x else "B_seal_intact")
	_draw_drum_face(self, Rect2(540, 250, 380, 120), 0, p04, band)
	_draw_pen(p04, band)
	_draw_pen_text(self, Rect2(540, 250, 380, 120), 24)
	if p05:
		_plate("B_p05")
		_plate("B_strip")
		var slots := [Rect2(609, 714, 70, 56), Rect2(695, 714, 70, 56), Rect2(781, 714, 70, 56)]
		for i in 3:
			var pid: String = r3.state.slots[i]
			if pid != "":
				_plate_face(self, slots[i], pid, 16)
	else:
		var homes := [Rect2(1133, 436, 74, 70), Rect2(1133, 526, 74, 70), Rect2(1133, 616, 74, 70)]
		for i in 3:
			# The rack on the wall shows every plate not set in a slot.
			var pid: String = R03Sim.RACK_HOME[i]
			if not pid in r3.state.slots:
				_plate_face(self, homes[i], pid, 16)

func _draw_pen(p04: bool, band: int) -> void:
	var t := _tex("B_pen")
	var swing := (not p04) or (band >= 5 and band < 7)
	var ang := 0.0
	if swing and motion:
		ang = deg_to_rad(6.0 if not p04 else 3.0) * sin(time * TAU * 7.0)
	var pivot := Vector2(730, 236)
	draw_set_transform(pivot, ang, Vector2.ONE)
	if t:
		draw_texture(t, Vector2(-80, -20))
	else:
		draw_line(Vector2.ZERO, Vector2(0, 170), Ink.INK, 4.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)

## The drum: before P04 one scribble at the same spot (and, after the threshold, her report
## figures); after it, rulings scrolling left with a tide line, until the drum stops at band 5.
func _draw_drum_face(cv: CanvasItem, r: Rect2, _size: int, p04: bool, band: int) -> void:
	var ink := Ink.INK
	var line_top := r.position.y + r.size.y * 0.52
	var line_h := r.size.y * 0.36
	if not p04:
		# One short line, written over and over at the same place.
		var cx := r.position.x + r.size.x * 0.5
		var cy := line_top + line_h * 0.6
		var pts := PackedVector2Array()
		for k in 13:
			pts.append(Vector2(cx - 26 + k * 4.3, cy + (7.0 if k % 2 == 0 else -7.0)))
		for j in 3:
			var off := Vector2(j * 0.8, j * 1.2 - 1.0)
			var shifted := PackedVector2Array()
			for p in pts:
				shifted.append(p + off)
			cv.draw_polyline(shifted, Color(ink, 0.75), 2.0, true)
	else:
		var scroll := 0.0
		if band < 5 and motion:
			scroll = fmod(drum_t * 18.0, 38.0)
		var step := 38.0
		var x := r.position.x + step - scroll
		while x < r.end.x:
			if x > r.position.x + 2:
				cv.draw_line(Vector2(x, r.position.y + 2), Vector2(x, r.end.y - 2), Color(Ink.COPPER, 0.55), 1.5)
			x += step
		var pts := PackedVector2Array()
		var flat := band >= 7
		var xx := r.position.x + 4
		while xx <= r.end.x - 4:
			var ph := (xx + (drum_t * 18.0 if band < 5 and motion else 0.0)) / 46.0
			var y := line_top + line_h * 0.5 + (0.0 if flat else line_h * 0.42 * sin(ph))
			pts.append(Vector2(xx, y))
			xx += 4.0
		cv.draw_polyline(pts, ink, 4.0 if flat else 2.5, true)

## What the pen writes, on a slip of the drum's paper so it reads over the pen arm.
func _draw_pen_text(cv: CanvasItem, r: Rect2, size: int) -> void:
	var nf := narrow()
	var txt := r3.pen_text()
	if txt == "":
		return
	var w := nf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var bx := Rect2(r.get_center().x - w / 2.0 - 10, r.position.y + 6, w + 20, size + 12)
	cv.draw_rect(bx, Color(Ink.PAPER, 0.9))
	Ink.text(cv, txt, Vector2(r.position.x, r.position.y + size + 8), size, Ink.INK, nf, r.size.x)

func _draw_wall_c() -> void:
	var band := _band()
	if not _plate("C_base"):
		_placeholder(WALL_HOTSPOTS_C)
	_draw_scratches()
	if _flag("P04"):
		_plate("C_hatch_open")
	if band >= 7:
		_plate("C_window_7")
		var lx := 1150.0
		if motion:
			var ph := fmod(time / 14.0, 2.0)
			lx = 1030.0 + 240.0 * (ph if ph < 1.0 else 2.0 - ph)
		var lt := _tex("C_line")
		if lt:
			draw_texture(lt, Vector2(lx - 4, 400))
		else:
			draw_line(Vector2(lx, 400), Vector2(lx, 660), Color(PALE, 0.8), 3.0)

## The three marks cut down the jamb: a dark groove with a pale lower lip.
func _draw_scratches() -> void:
	var strokes := scratch_strokes()
	var lip := Color(0.86, 0.80, 0.68, 0.9)
	var groove := Color(0.10, 0.08, 0.07)
	for s in strokes:
		var shifted := PackedVector2Array()
		for p in s:
			shifted.append(p + Vector2(0, 3))
		draw_polyline(shifted, lip, 2.0, true)
	for s in strokes:
		draw_polyline(s, groove, 5.0, true)

## The scratch glyphs as polylines (also used by tests to check they sit on the jamb).
static func scratch_strokes() -> Array:
	var out := []
	# '[' centred (512,450), 70 tall
	out.append(PackedVector2Array([Vector2(526, 415), Vector2(502, 415), Vector2(502, 485), Vector2(526, 485)]))
	# two parallel 45-degree strokes joined by a short bar, centred (512,570)
	out.append(PackedVector2Array([Vector2(481, 553), Vector2(505, 577), Vector2(519, 563), Vector2(543, 587)]))
	# hollow circle, centre (512,690), r 24
	var ring := PackedVector2Array()
	for k in 33:
		var a := TAU * k / 32.0
		ring.append(Vector2(512, 690) + Vector2(cos(a), sin(a)) * 24.0)
	out.append(ring)
	return out

## A slow pale ink frame drawn round the notice's region (static with Motion off).
func _draw_notice_frame() -> void:
	if not holding():
		return
	var r: Rect2 = NOTICE_RECTS[hold_id].grow(10)
	var k := 1.0
	if motion:
		k = clampf(hold_t / HOLD_TIME, 0.0, 1.0) if hold_t >= 0.0 else 0.0
	var a := 0.85
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	var per := 2.0 * (r.size.x + r.size.y)
	var left := per * k
	for i in 4:
		var p0: Vector2 = corners[i]
		var p1: Vector2 = corners[i + 1]
		var seg := p0.distance_to(p1)
		if left <= 0.0:
			break
		var q := p0.lerp(p1, minf(1.0, left / seg))
		draw_line(p0, q, Color(Ink.INK, 0.45 * a), 7.0)
		draw_line(p0, q, Color(PALE, a), 3.0)
		left -= seg

# ---------------------------------------------------------------------------
# shared marks
# ---------------------------------------------------------------------------
## A registration cross: an 18 px plus with a ring.
func _cross(cv: CanvasItem, at: Vector2, half: float, col: Color, w: float) -> void:
	cv.draw_line(at - Vector2(half, 0), at + Vector2(half, 0), col, w)
	cv.draw_line(at - Vector2(0, half), at + Vector2(0, half), col, w)
	cv.draw_arc(at, half * 0.62, 0, TAU, 24, col, maxf(1.5, w * 0.7))

func _north(cv: CanvasItem, base: Vector2, length: float, col: Color, size: int) -> void:
	var tip := base - Vector2(0, length)
	cv.draw_line(base, tip, col, 3.0)
	cv.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-8, 16), tip + Vector2(8, 16)]), col)
	Ink.text(cv, "N", tip + Vector2(-20, -6), size, col, Ink.serif(), 40)

## A plate symbol: '[' boundary, two linked strokes relation, a hollow circle observer.
func _symbol(cv: CanvasItem, kind: String, c0: Vector2, s: float, col: Color, w: float) -> void:
	match kind:
		"boundary":
			cv.draw_polyline(PackedVector2Array([c0 + Vector2(s * 0.22, -s * 0.5), c0 + Vector2(-s * 0.18, -s * 0.5),
				c0 + Vector2(-s * 0.18, s * 0.5), c0 + Vector2(s * 0.22, s * 0.5)]), col, w, true)
		"relation":
			var k := s / 52.0
			cv.draw_polyline(PackedVector2Array([c0 + Vector2(-26, -14) * k, c0 + Vector2(-6, 6) * k,
				c0 + Vector2(6, -6) * k, c0 + Vector2(26, 14) * k]), col, w, true)
		"observer":
			cv.draw_arc(c0, s * 0.36, 0, TAU, 32, col, w, true)

## A record plate's face: symbol above its word, in ink on brass.
func _plate_face(cv: CanvasItem, r: Rect2, pid: String, word_size: int) -> void:
	var s := minf(r.size.x, r.size.y) * 0.5
	_symbol(cv, pid, r.position + Vector2(r.size.x / 2.0, r.size.y * 0.38), s, Ink.INK, maxf(2.5, s * 0.1))
	var word: String = PLATE_WORDS[pid]
	var fs := word_size
	while fs > 12 and narrow().get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x + 2:
		fs -= 1
	Ink.text(cv, word, Vector2(r.position.x - 6, r.end.y - r.size.y * 0.1), fs, Ink.INK, narrow(), r.size.x + 12)

## The registered curve: the 17 Oct half and Venn's half, through `map` (sheet -> canvas).
func _composite_curve(cv: CanvasItem, map: Callable, col: Color, w: float, alpha: float) -> void:
	var c0 := Color(col, alpha)
	var whole: Array = CURVE_17 + VENN_BRACKET.slice(1) + VENN_LINKED
	cv.draw_polyline(_mapped(whole, map), c0, w, true)
	cv.draw_line(map.call(VENN_LINKED[3]), map.call(VENN_LOOP_C + Vector2(-VENN_LOOP_R, 0)), c0, w)
	var ring := []
	for k in 33:
		var a := PI + TAU * k / 32.0
		ring.append(VENN_LOOP_C + Vector2(cos(a), sin(a)) * VENN_LOOP_R)
	cv.draw_polyline(_mapped(ring, map), c0, w, true)
	cv.draw_line(map.call(VENN_LOOP_C + Vector2(VENN_LOOP_R, 0)), map.call(VENN_EXIT[0]), c0, w)
	cv.draw_polyline(_mapped(VENN_EXIT, map), c0, w, true)

func _mapped(pts: Array, map: Callable) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(map.call(p))
	return out

## Venn's half alone, in his own sheet coordinates (drawn under his sheet's transform).
func _venn_half(cv: CanvasItem, col: Color, w: float) -> void:
	cv.draw_polyline(PackedVector2Array(VENN_BRACKET), col, w, true)
	cv.draw_line(VENN_BRACKET[3], VENN_LINKED[0], col, w)
	cv.draw_polyline(PackedVector2Array(VENN_LINKED), col, w, true)
	cv.draw_line(VENN_LINKED[3], VENN_LOOP_C + Vector2(-VENN_LOOP_R, 0), col, w)
	cv.draw_arc(VENN_LOOP_C, VENN_LOOP_R, 0, TAU, 32, col, w, true)
	cv.draw_line(VENN_LOOP_C + Vector2(VENN_LOOP_R, 0), VENN_EXIT[0], col, w)
	cv.draw_polyline(PackedVector2Array(VENN_EXIT), col, w, true)

# ---------------------------------------------------------------------------
# HUD: the turn plaques
# ---------------------------------------------------------------------------
func draw_hud(c0: Node2D) -> void:
	if r3 == null or r3.local_view != "room":
		return
	for t in TURN_RECTS:
		var r: Rect2 = TURN_RECTS[t]
		Ink.button(c0, r, "", false, 20, holding())
		var left: bool = t == "turn_left"
		var dest: String = R03Sim.TURNS[r3.wall][t]
		var f := Ink.serif()
		var arrow := "◂" if left else "▸"
		var aw := f.get_string_size(arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		c0.draw_string(f, Vector2(r.get_center().x - aw / 2.0, r.position.y + 40), arrow,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Ink.PAPER)
		# The destination's name runs up the plaque, read with the head tilted.
		var name: String = WALL_NAMES[dest]
		var size := 19
		var nw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var cx := r.get_center().x
		var cy := r.position.y + 52 + (r.size.y - 52) / 2.0
		c0.draw_set_transform(Vector2(cx + 7, cy + nw / 2.0), -PI / 2.0, Vector2.ONE)
		c0.draw_string(f, Vector2.ZERO, name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Ink.PAPER)
		c0.draw_set_transform_matrix(Transform2D.IDENTITY)

# ---------------------------------------------------------------------------
# close-ups (layer 5, unmodulated)
# ---------------------------------------------------------------------------
func _draw_close() -> void:
	if r3 == null:
		return
	match r3.local_view:
		"c_registration":
			_bg(close, "cu_registration", Color("3a3430"))
		"c_recorder":
			_draw_recorder(close)
		"c_plan":
			_draw_plan(close)

func _draw_reg_sheets() -> void:
	if r3 != null and r3.local_view == "c_registration":
		_draw_registration(reg_sheets, -REG_TABLE.position)

func _draw_close_top() -> void:
	if r3 != null and r3.local_view == "c_registration":
		_draw_reg_controls(close_top)

func _bg(cv: CanvasItem, id: String, fallback: Color) -> void:
	var t := _tex(id)
	if t:
		cv.draw_texture(t, Vector2.ZERO)
	else:
		cv.draw_rect(Rect2(Vector2.ZERO, SIZE), fallback)

func _over(cv: CanvasItem, id: String) -> void:
	var t := _tex(id)
	if t:
		cv.draw_texture(t, Vector2.ZERO)

# --- c_registration ----------------------------------------------------------------
func _base_xform(origin := Vector2.ZERO) -> Transform2D:
	return Transform2D(0.0, REG_SHEET.position + origin)

## Venn's sheet, sheet-local -> sheet-local of the table: turned reg_rot quarter turns
## clockwise about its centre, then pinned (or loose, out of register).
func venn_xform() -> Transform2D:
	var st: Dictionary = r3.state
	var rot := float(int(st.reg_rot)) * PI / 2.0
	var r := Transform2D(rot, Vector2.ZERO)
	var off := UNSNAPPED
	var snap: String = st.reg_snap
	if snap != "" and CROSSES.has(snap):
		off = CROSSES.lighthouse - (r * (CROSSES[snap] - VENN_CENTRE) + VENN_CENTRE)
	return Transform2D(rot, VENN_CENTRE + off) * Transform2D(0.0, -VENN_CENTRE)

func _venn_screen_xform(origin := Vector2.ZERO) -> Transform2D:
	return _base_xform(origin) * venn_xform()

## The sheets on the light table, drawn into the clipping node (`origin` = its offset).
func _draw_registration(cv: CanvasItem, origin: Vector2) -> void:
	var st: Dictionary = r3.state
	var nf := narrow()
	reg_origin = origin
	# The base sheet.
	var base14: bool = st.reg_base == "14"
	cv.draw_set_transform_matrix(_base_xform(origin))
	var sp := _tex("sheet_paper")
	if sp:
		cv.draw_texture(sp, Vector2.ZERO)
	else:
		cv.draw_rect(Rect2(0, 0, 600, 560), Ink.PAPER)
	for i in 5:
		var y0: float = BANDS_Y[i]
		if i % 2 == 0:
			cv.draw_rect(Rect2(14, y0, 572, BANDS_Y[i + 1] - y0), Color(Ink.SEA_GLASS, 0.22))
		cv.draw_line(Vector2(14, y0), Vector2(586, y0), Color(Ink.INK, 0.35), 1.0)
		Ink.text(cv, str(i + 1), Vector2(572 - 14, (y0 + BANDS_Y[i + 1]) / 2.0 + 8), 22, Ink.INK, nf, 28)
	cv.draw_line(Vector2(14, 560 - 2), Vector2(586, 560 - 2), Color(Ink.INK, 0.35), 1.0)
	Ink.text(cv, "14 OCT 1931" if base14 else "17 OCT 1931", Vector2(24, 36), 22, Ink.INK, nf, 200,
		HORIZONTAL_ALIGNMENT_LEFT)
	Ink.text(cv, "GREYWAKE SOUND · SHEET 1 OF 2", Vector2(0, 36), 18, Ink.INK, nf, 600)
	_sheet_marks(cv, Ink.INK)
	cv.draw_polyline(PackedVector2Array(CURVE_14 if base14 else CURVE_17), Ink.INK, 3.0, true)
	cv.draw_set_transform_matrix(Transform2D.IDENTITY)
	# Venn's tracing, laid over.
	if st.reg_laid:
		cv.draw_set_transform_matrix(_venn_screen_xform(origin))
		var tr := _tex("sheet_tracing")
		if tr:
			cv.draw_texture(tr, Vector2.ZERO)
		else:
			cv.draw_rect(Rect2(0, 0, 600, 560), Color(0.95, 0.95, 0.9, 0.55))
		cv.draw_rect(Rect2(0, 0, 600, 560), Color(VENN_INK, 0.6), false, 2.0)
		Ink.text(cv, "SHEET 2 OF 2 · E.V. · 17 OCT 1931", Vector2(0, 520), 18, VENN_INK, nf, 600)
		_sheet_marks(cv, VENN_INK)
		_venn_half(cv, VENN_INK, 3.0)
		cv.draw_set_transform_matrix(Transform2D.IDENTITY)
	if st.p03_complete:
		_composite_curve(cv, Callable(self, "_reg_map"), VENN_INK, 5.0, comp_k)
		for p in [Vector2(424, 170), Vector2(1024, 170), Vector2(424, 730), Vector2(1024, 730)]:
			var q: Vector2 = p + origin
			cv.draw_rect(Rect2(q - Vector2(18, 10), Vector2(36, 20)), Color(Ink.BRASS, 1.0))
			cv.draw_rect(Rect2(q - Vector2(18, 10), Vector2(36, 20)), Ink.INK, false, 2.0)

func _reg_map(p: Vector2) -> Vector2:
	return REG_SHEET.position + reg_origin + p

func _sheet_marks(cv: CanvasItem, col: Color) -> void:
	var nf := narrow()
	for k in CROSSES:
		var at: Vector2 = CROSSES[k]
		_cross(cv, at, 9.0, col, 2.5)
		Ink.text(cv, CROSS_LABELS[k], at + Vector2(-90, 34), 16, col, nf, 180)
	_north(cv, NORTH_AT, 70.0, col, 20)

func _draw_reg_controls(cv: CanvasItem) -> void:
	var st: Dictionary = r3.state
	var nf := narrow()
	# The right panel, cleared for the pin and turn controls.
	cv.draw_rect(REG_PANEL, Color8(150, 118, 64))
	cv.draw_rect(REG_PANEL, Ink.INK, false, 3.0)
	cv.draw_rect(REG_PANEL.grow(-10), Color(Ink.INK, 0.4), false, 1.0)
	for c0 in REG_CONTROLS:
		var id: String = c0[0]
		var r: Rect2 = c0[1]
		match id:
			"reg_example":
				_draw_example(cv, r)
			"reg_lay":
				Ink.button(cv, r, "Lift Venn's sheet" if st.reg_laid else "Lay Venn's sheet", false, 22)
			"reg_base_14":
				Ink.button(cv, r, "14 OCT", st.reg_base == "14", 26)
			"reg_base_17":
				Ink.button(cv, r, "17 OCT", st.reg_base == "17", 26)
			"reg_clip":
				Ink.button(cv, r, "CLIP", st.p03_complete, 30)
			_:
				var active: bool = id.begins_with("reg_snap_") and st.reg_snap == id.substr(9)
				Ink.button(cv, r, c0[2], active, 22, not st.reg_laid)
	Ink.text(cv, "Pin to the table's lighthouse cross:", Vector2(1124, 428), 18, Ink.INK, nf, 280,
		HORIZONTAL_ALIGNMENT_LEFT)
	Ink.text(cv, "TURN HIS SHEET", Vector2(1124, 272), 18, Ink.PAPER, nf, 280)
	Ink.text(cv, "BASE SHEET", Vector2(84, 160), 18, Ink.PAPER, nf, 240)

func _draw_example(cv: CanvasItem, _r: Rect2) -> void:
	var nf := narrow()
	var glass := Rect2(100, 616, 206, 226)
	var a := Rect2(glass.position + Vector2(16, 14), Vector2(130, 110))
	var b := Rect2(a.position + Vector2(44, 26), Vector2(130, 110))
	cv.draw_rect(a, Color(Ink.PAPER, 0.95))
	cv.draw_rect(a, Ink.INK, false, 1.5)
	for i in 5:
		var y := a.position.y + 8 + i * 20
		Ink.text(cv, str(i + 1), Vector2(a.position.x + 2, y + 14), 11, Ink.INK, nf, 14)
		cv.draw_line(Vector2(a.position.x, y), Vector2(a.end.x, y), Color(Ink.INK, 0.25), 1.0)
	cv.draw_rect(b, Color(0.92, 0.94, 0.95, 0.6))
	cv.draw_rect(b, Color(VENN_INK, 0.8), false, 1.5)
	var pin := a.position + Vector2(70, 40)
	_cross(cv, pin, 6.0, Ink.INK, 1.8)
	_cross(cv, pin + Vector2(0.5, 0.5), 6.0, VENN_INK, 1.2)
	var y1 := a.position.y + 18
	cv.draw_polyline(PackedVector2Array([Vector2(a.position.x + 16, y1 + 4), Vector2(a.position.x + 70, y1 - 2),
		Vector2(b.end.x - 10, y1 + 3)]), VENN_INK, 2.5, true)
	var cap := Rect2(glass.position.x + 4, glass.end.y - 82, glass.size.x - 8, 78)
	cv.draw_rect(cap, Color(Ink.PAPER, 0.95))
	Ink.wrapped(cv, "Example: register at the cross. The line runs through band 1.",
		cap.position + Vector2(6, 20), 16, Ink.INK, cap.size.x - 12, true, nf)

# --- c_recorder --------------------------------------------------------------------
func _draw_recorder(cv: Node2D) -> void:
	var st: Dictionary = r3.state
	var nf := narrow()
	var t1x := _flag("t1x_threshold_crossed")
	var p04: bool = st.p04_complete
	_bg(cv, "cu_recorder", Color("4d6a63"))
	# The drum: a trace under the text.
	_draw_drum_face(cv, Rect2(226, 112, 996, 226), 0, p04, _band())
	var lines := []
	if st.p05_complete:
		lines = strip_visible()
	else:
		var rf := r3.refusal_text()
		if rf != "":
			lines = [rf]
		elif r3.pen_text() != "":
			lines = [r3.pen_text()]
	for i in lines.size():
		var y := 150.0 + 36.0 * i
		var s: String = lines[i]
		var w := nf.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		cv.draw_rect(Rect2(DRUM_TEXT.get_center().x - w / 2.0 - 8, y - 24, w + 16, 32), Color(Ink.PAPER, 0.88))
		Ink.text(cv, s, Vector2(DRUM_TEXT.position.x, y), 26, Ink.INK, nf, DRUM_TEXT.size.x)
	# The seal over the wheels. Broken, its torn halves curl back round the housings: the
	# plate, wheels and gauges stand proud of the paper (patched from the plate itself).
	var bg := _tex("cu_recorder")
	if t1x:
		_over(cv, "cu_seal_broken")
		if bg:
			for pr in [CAL_PLATE.grow(4), Rect2(244, 466, 170, 304), Rect2(484, 466, 170, 304),
					GAUGES[0].grow(2), GAUGES[1].grow(2)]:
				cv.draw_texture_rect_region(bg, pr, pr)
	# Calibration plate.
	Ink.wrapped(cv, "ZERO AND INTERVAL ARE INDEPENDENT CONTROLS · EXAMPLE: ZERO 7 · INTERVAL 2 → CALIBRATE",
		CAL_PLATE.position + Vector2(18, 30), 19, Ink.INK, CAL_PLATE.size.x - 36, true, nf)
	# Wheels.
	var vals := [int(st.zero), int(st.interval)]
	var names := ["ZERO", "INTERVAL"]
	for i in 2:
		var wr: Rect2 = WHEEL_WIN[i]
		var s := str(vals[i])
		var f := Ink.serif()
		var dw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
		cv.draw_string(f, Vector2(wr.get_center().x - dw / 2.0, wr.get_center().y + 26), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Ink.INK)
		Ink.text(cv, names[i], Vector2(wr.position.x - 20, 763), 20, Ink.PAPER, nf, wr.size.x + 40)
		_arrow(cv, REC_CONTROLS[i * 2][1].get_center() + Vector2(0, 1), true)
		_arrow(cv, REC_CONTROLS[i * 2 + 1][1].get_center() + Vector2(0, 1), false)
	# Gauges: needle position plus a word, never colour alone.
	for i in 2:
		_gauge(cv, GAUGES[i], String(st.gauges[i]), i)
	# The lever: handle down after P04.
	if p04:
		cv.draw_rect(Rect2(712, 482, 134, 52), COPPER_FILL)
		cv.draw_rect(Rect2(766, 482, 26, 52), Color8(10, 14, 18))
		cv.draw_rect(Rect2(770, 520, 18, 14), Ink.BRASS)
		cv.draw_rect(Rect2(724, 470, 110, 400), Ink.INK, false, 3.0)
		var hr := Rect2(716, 800, 126, 44)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color8(232, 204, 140)
		sb.border_color = Ink.INK
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(20)
		cv.draw_style_box(sb, hr)
	Ink.text(cv, "CALIBRATE", Vector2(704, 900), 20, Ink.PAPER, nf, 150)
	if not t1x:
		_over(cv, "cu_seal")
		var hand_rows := [["Calibrate on filing of the", 490], ["closure report.", 524],
			["Duty card, item 2 before", 690], ["item 3. — E.V.", 724]]
		for k in hand_rows.size():
			var row: Array = hand_rows[k]
			var txt: String = row[0]
			Ink.handwriting(cv, txt, txt.length(), Vector2(262, row[1]), 24, k + 1, false)
	_draw_record_panel(cv)

func _arrow(cv: CanvasItem, c0: Vector2, up: bool) -> void:
	var d := -1.0 if up else 1.0
	cv.draw_colored_polygon(PackedVector2Array([c0 + Vector2(0, 12 * d), c0 + Vector2(-12, -6 * d),
		c0 + Vector2(12, -6 * d)]), Ink.INK)

func _gauge(cv: CanvasItem, r: Rect2, v: String, i: int) -> void:
	var nf := narrow()
	var pivot := Vector2(r.position.x + 95, 892)
	var target := Vector2(r.position.x + 30, 800)
	var word := ""
	match v:
		"ok":
			target = Vector2(pivot.x, 796)
			word = "TRUE"
		"mismatch":
			target = Vector2(r.position.x + 152, 800)
			word = "ZERO REFERENCE MISMATCH" if i == 0 else "INTERVAL MISMATCH"
	cv.draw_line(pivot, pivot + (target - pivot).normalized() * 96.0, Ink.INK, 4.0)
	cv.draw_circle(pivot, 7.0, Ink.INK)
	if word != "":
		var tag := Rect2(r.position.x, r.end.y + 6, r.size.x, 30)
		cv.draw_rect(tag, Color(Ink.PAPER, 0.95))
		cv.draw_rect(tag, Ink.INK, false, 1.5)
		var fs := 18
		while fs > 12 and nf.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > tag.size.x - 10:
			fs -= 1
		Ink.text(cv, word, Vector2(tag.position.x, tag.position.y + 21), fs, Ink.INK, nf, tag.size.x)

func _draw_record_panel(cv: Node2D) -> void:
	var st: Dictionary = r3.state
	var nf := narrow()
	Ink.wrapped(cv, "Departure observation, example: BOUNDARY → RELATION → OBSERVER, then RECORD.",
		REC_MINIATURE.position + Vector2(22, 36), 19, Ink.INK, REC_MINIATURE.size.x - 44, true, nf)
	var pt := _tex("plate_blank")
	for i in 3:
		var sr: Rect2 = REC_SLOTS[i]
		Ink.text(cv, str(i + 1), Vector2(sr.position.x, sr.position.y - 8), 20, Ink.PAPER, nf, sr.size.x)
		var pid: String = st.slots[i]
		if pid != "":
			var pr := Rect2(sr.position.x, sr.position.y + 10, 130, 130)
			_plate_sprite(cv, pt, pr, pid)
	var rack := r3.rack_plates()
	for i in 3:
		if rack[i] != "":
			_plate_sprite(cv, pt, REC_HOMES[i], rack[i])
	Ink.text(cv, "RECORD", Vector2(REC_RECORD.position.x, REC_RECORD.position.y + 66), 20, Ink.INK, nf,
		REC_RECORD.size.x)
	if not st.p04_complete:
		_over(cv, "cu_recorder_shutter")
		Ink.text(cv, "CALIBRATE FIRST", Vector2(992, 718), 32, Ink.INK, Ink.serif(), 284)
	if r3.held_plate != "":
		var m := cv.get_global_mouse_position() + Vector2(18, 18)
		_plate_sprite(cv, pt, Rect2(m, Vector2(130, 130)), r3.held_plate)

func _plate_sprite(cv: CanvasItem, pt: Texture2D, r: Rect2, pid: String) -> void:
	if pt:
		cv.draw_texture_rect(pt, r, false)
	else:
		cv.draw_rect(r, Ink.BRASS)
		cv.draw_rect(r, Ink.INK, false, 2.0)
	_plate_face(cv, r.grow(-14), pid, 20)

# --- c_plan ---------------------------------------------------------------------------
func _draw_plan(cv: Node2D) -> void:
	var ps := r3.plan_state()
	var nf := narrow()
	var ink := Ink.INK
	_bg(cv, "cu_plan", Color("1e2a36"))
	var t := _tex("cu_plan")
	if t == null:
		cv.draw_rect(PLAN_PAPER, Ink.PAPER)
	Ink.text(cv, "GREYWAKE SURVEY STATION · GENERAL PLAN · 1889 · REVISED E.V. 1927", Vector2(220, 134), 20, ink,
		Ink.serif(), 1000)
	for rm in PLAN_ROOMS:
		var r: Rect2 = rm[1]
		cv.draw_rect(r, ink, false, 2.5)
		Ink.wrapped(cv, rm[0], r.position + Vector2(8, 22), 16, ink, r.size.x - 12, true, nf)
	# The observation chamber: outline only, printed WITNESS.
	_dashed_rect(cv, PLAN_CHAMBER, ink, 2.5, 10.0)
	Ink.text(cv, "OBSERVATION CHAMBER", PLAN_CHAMBER.position + Vector2(-20, -8), 14, ink, nf, PLAN_CHAMBER.size.x + 40)
	Ink.text(cv, "WITNESS", PLAN_CHAMBER.position + Vector2(0, PLAN_CHAMBER.size.y - 12), 16, ink, nf,
		PLAN_CHAMBER.size.x)
	# The margin column.
	Ink.text(cv, "PERSONAL EVIDENCE", Vector2(255, 330), 18, ink, nf, 200)
	cv.draw_line(Vector2(260, 340), Vector2(450, 340), Color(ink, 0.6), 1.5)
	# The landward bracket, BOUNDARY written up it.
	cv.draw_polyline(PackedVector2Array([Vector2(260, 300), Vector2(236, 300), Vector2(236, 800), Vector2(260, 800)]),
		ink, 4.0)
	cv.draw_set_transform(Vector2(230, 600), -PI / 2.0, Vector2.ONE)
	cv.draw_string(nf, Vector2(0, 0), "BOUNDARY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
	cv.draw_set_transform_matrix(Transform2D.IDENTITY)
	# The dry stair with its landings.
	var y := 310.0
	while y < 570.0:
		cv.draw_line(Vector2(720, y), Vector2(720, minf(y + 12, 570)), ink, 2.5)
		y += 20.0
	Ink.text(cv, "[ 1", Vector2(736, 336), 18, ink, nf, 60, HORIZONTAL_ALIGNMENT_LEFT)
	Ink.text(cv, "] 1", Vector2(736, 554), 18, ink, nf, 60, HORIZONTAL_ALIGNMENT_LEFT)
	Ink.text(cv, "[ 2", Vector2(736, 696), 18, ink, nf, 60, HORIZONTAL_ALIGNMENT_LEFT)
	# The body beneath the rooms.
	if ps.complete:
		var body := _tex("cu_plan_body")
		if body:
			cv.draw_texture(body, Vector2.ZERO, Color(1, 1, 1, plan_k))
		Ink.wrapped(cv, PLAN_MARGIN_TEXT, Vector2(262, 620), 18, Ink.BLUE_INK, 190, true, Ink.hand())
	# Placed tiles, centred in their zones.
	var tt := _tex("tile_blank")
	for tile in R03Sim.TILES:
		var z: String = ps.tiles[tile]
		if z != "":
			_tile(cv, tt, tile_rect(z), tile)
	# Reference cards beside the misplaced ones.
	if not ps.complete:
		for tile in ps.misplaced:
			var z: String = ps.tiles[tile]
			if z != "":
				_ref_card(cv, PLAN_CARD_AT[z], "%s: %s" % [String(tile).to_upper(), R03Sim.TILE_REFS[tile]])
	# The tray.
	for tile in ps.tray:
		_tile(cv, tt, PLAN_HOMES[tile], tile)
	if not ps.unlocked:
		_over(cv, "cu_plan_lid")
	# ADA MERCER in the witness frame, under the word.
	if ps.complete and ps.tiles.witness == "centre":
		var full := "ADA MERCER"
		var n := full.length()
		if name_live:
			n = 0 if name_chars < 0.0 else clampi(int(name_chars), 0, full.length())
		var zr: Rect2 = tile_rect("centre")
		var fw := nf.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		if n > 0:
			cv.draw_string(nf, Vector2(zr.get_center().x - fw / 2.0, zr.end.y - 10), full.substr(0, n),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	Ink.text(cv, "FIX", Vector2(PLAN_FIX.position.x, PLAN_FIX.position.y + 100), 20, ink, nf, PLAN_FIX.size.x)
	if r3.held_tile != "":
		var m := cv.get_global_mouse_position() + Vector2(18, 18)
		_tile(cv, tt, Rect2(m, Vector2(170, 84)), r3.held_tile)

func _tile(cv: CanvasItem, tt: Texture2D, r: Rect2, tile: String) -> void:
	if tt:
		cv.draw_texture_rect(tt, r, false)
	else:
		cv.draw_rect(r, Ink.PAPER)
		cv.draw_rect(r, Ink.INK, false, 2.0)
	var size := 24 if r.size.x >= 160 else 22
	var y := r.get_center().y + size * 0.36
	if tile == "witness" and r.size.x < 160 and r3.state.p21_complete:
		y = r.position.y + 30   # room under the word for the name
		size = 20
	Ink.text(cv, tile.to_upper(), Vector2(r.position.x, y), size, Ink.INK, Ink.serif(), r.size.x)

func _ref_card(cv: CanvasItem, at: Vector2, s: String) -> void:
	var nf := narrow()
	var w := nf.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 24
	var r := Rect2(at, Vector2(w, 40))
	if r.end.x > 1236:
		r.position.x = 1236 - w
	cv.draw_rect(r, Color(0.97, 0.94, 0.86))
	cv.draw_rect(r, Ink.INK, false, 2.0)
	Ink.text(cv, s, Vector2(r.position.x + 12, r.position.y + 27), 18, Ink.INK, nf, w, HORIZONTAL_ALIGNMENT_LEFT)

func _dashed_rect(cv: CanvasItem, r: Rect2, col: Color, w: float, dash: float) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var n := int(a.distance_to(b) / dash)
		for k in range(0, n, 2):
			cv.draw_line(a.lerp(b, float(k) / n), a.lerp(b, minf(1.0, float(k + 1) / n)), col, w)
