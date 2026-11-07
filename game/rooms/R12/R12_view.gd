extends RoomView
## R12, the Observation Chamber: the painted renderer for R12Sim.
##
## Three base walls on the world layer (layer 0): A, the chair and the instrument ("room"); B, the
## record wall ("frames"); C, the routing wall ("routing"). The close-ups c_frames (P25), c_routing
## (P26) and c_final (P27) and the ending tableaux sit on a CanvasLayer at 5. The view only
## presents: it reads R12Sim's helpers and transient vars and never changes the sim. Everything it
## times (typing strips, previews, the surface drawing back, the ending's beats) keys to the sim's
## fx events and to on_sfx(id), so a chain played late stays in step with its sounds. Every motion
## has a still alternative with "Motion & flicker" off, and nothing flashes.
##
## Art: assets/rooms/R12/*.png (tools/art/rooms/R12.py). The plates carry no words: every label,
## schematic and line of writing is drawn here with Ink's fonts.

const DIR := "res://assets/rooms/R12/%s.png"

# ---------------------------------------------------------------------------------------------
# hit tables ([id, rect, label]; first match wins)
# ---------------------------------------------------------------------------------------------
const HOTSPOTS := [
	["pressure", Rect2(1110, 430, 120, 120), "Pressure gauge"],
	["window", Rect2(474, 96, 500, 290), "Window"],
	["chair", Rect2(360, 470, 300, 430), "Chair"],
	["armatures", Rect2(660, 410, 420, 490), "Instrument"],
	["to_frames", Rect2(30, 300, 150, 420), "◂ Record wall"],
	["to_routing", Rect2(1268, 300, 150, 420), "Routing wall ▸"],
]
const EXIT_RECTS := {
	"R11": Rect2(20, 922, 250, 64),
}
const FRAMES_HOTSPOTS := [
	["nameplate", Rect2(474, 250, 500, 66), "Name plate"],
	["indicators", Rect2(140, 100, 1168, 140), "Staff indicators"],
	["frame_body", Rect2(130, 330, 340, 380), "BODY frame"],
	["frame_place", Rect2(554, 330, 340, 380), "PLACE frame"],
	["frame_name", Rect2(978, 330, 340, 380), "NAME frame"],
	["terminal", Rect2(130, 740, 340, 170), "Witness terminal"],
	["card_rack", Rect2(554, 740, 340, 170), "Card rack"],
	["copy_port", Rect2(978, 740, 200, 170), "COPY port"],
]
const ROUTING_HOTSPOTS := [
	["plate_sever", Rect2(110, 110, 540, 400), "SEVER plate"],
	["plate_continue", Rect2(798, 110, 540, 400), "CONTINUE plate"],
	["cards", Rect2(474, 540, 500, 150), "Consequence cards"],
	["handle", Rect2(1240, 560, 150, 340), "Severance handle"],
	["yoke_tray", Rect2(110, 740, 330, 160), "Yoke tray"],
	["contacts", Rect2(470, 740, 330, 160), "Feed contacts"],
	["bridge_seat", Rect2(830, 740, 380, 160), "My terminal"],
]
const FRAMES_CONTROLS := [
	["f_body", Rect2(140, 110, 340, 420), "BODY frame"],
	["f_place", Rect2(554, 110, 340, 420), "PLACE frame"],
	["f_name", Rect2(968, 110, 340, 420), "NAME frame"],
	["look_body", Rect2(180, 540, 260, 64), "BODY plate"],
	["look_place", Rect2(594, 540, 260, 64), "PLACE plate"],
	["look_name", Rect2(1008, 540, 260, 64), "NAME plate"],
	["rack_identity", Rect2(110, 660, 300, 200), "Card: CONTRACT"],
	["rack_trace", Rect2(430, 660, 300, 200), "Card: MOVEMENT"],
	["rack_position", Rect2(750, 660, 300, 200), "Card: POSITION"],
	["look_strip", Rect2(1110, 600, 300, 80), "Strip"],
	["switch", Rect2(1110, 700, 300, 120), "Switch: WITNESS / COPY"],
	["route", Rect2(1110, 840, 300, 130), "ROUTE"],
]
## The consequence cards' rows are built per frame (a card's rect follows the card).
const ROUTING_CONTROLS := [
	["look_sever", Rect2(110, 100, 540, 360), "SEVER plate"],
	["look_continue", Rect2(798, 100, 540, 360), "CONTINUE plate"],
	["preview_sever", Rect2(260, 470, 240, 90), "PREVIEW"],
	["preview_continue", Rect2(948, 470, 240, 90), "PREVIEW"],
	["slot_sever", Rect2(140, 590, 420, 150), "SEVER card slot"],
	["slot_continue", Rect2(888, 590, 420, 150), "CONTINUE card slot"],
	["confirm", Rect2(604, 590, 240, 150), "CONFIRM UNDERSTANDING"],
]
const CC_WELLS := {
	"cc_restored": Rect2(64, 790, 310, 160), "cc_remains": Rect2(394, 790, 310, 160),
	"cc_returns": Rect2(724, 790, 310, 160), "cc_ends": Rect2(1054, 790, 310, 160),
}
const FINAL_CONTROLS := [
	["contacts", Rect2(100, 140, 440, 260), "Feed contacts"],
	["look_lamps", Rect2(560, 140, 328, 260), "Preview lamps"],
	["bridge_seat", Rect2(908, 140, 440, 260), "My terminal"],
	["tray", Rect2(100, 440, 440, 170), "Yoke tray"],
	["preview", Rect2(604, 460, 240, 120), "PREVIEW"],
	["look_handle", Rect2(908, 440, 440, 170), "Severance handle"],
	["btn_sever", Rect2(100, 700, 600, 200), "BREAK CONNECTION AND LEAVE"],
	["btn_continue", Rect2(748, 700, 600, 200), "REMAIN AS WITNESS"],
]

# ---------------------------------------------------------------------------------------------
# sound (tools/audio/rooms/R12.py, S4)
# ---------------------------------------------------------------------------------------------
const SFX_DB := {
	"card_lift": -14, "card_seat": -12, "card_return": -14, "frame_lamp": -14, "switch_throw": -11,
	"strip_type": -13, "route_key": -10, "route_refuse": -12, "frames_slide": -9, "terminal_on": -12,
	"venn_last": -6, "shutters_open": -16, "preview_key": -13, "preview_out": -12, "preview_move": -12,
	"cc_lift": -14, "cc_seat": -12, "cc_return": -14, "confirm_refuse": -12, "mismatch_lamp": -13,
	"confirm_stamp": -8, "slots_close": -11, "surface_withdraw": -8, "yoke_lift": -12, "yoke_fit": -9,
	"yoke_return": -12, "bridge_seat": -11, "bridge_lift": -13, "final_preview": -13, "button_refuse": -14,
	"one_or_other": -14, "handle_pull": -7, "line_out_1": -12, "line_out_2": -12, "line_out_3": -12,
	"line_out_4": -12, "line_out_5": -12, "line_out_6": -12, "line_out_7": -12, "line_out_8": -12,
	"funnel_stop": -11, "throat": -14, "breath_stop": -10, "jar_level": -14, "spoon_settle": -16,
	"mattress_rise": -14, "pen_lift": -14, "venn_allright": -6, "record_lift": -13, "launch_engine": -10,
	"gulls": -14, "inquiry_pen": -12, "page_dry": -14, "motif_human_a": -8, "feed_move": -11,
	"coat_slump": -11, "chair_sit": -12, "armature_settle": -14, "index_type": -12, "pencil_correct": -12,
	"cup_warm": -16, "counter_type": -12, "paper_cover": -12, "motif_human_b": -8,
}
const SFX_SOFT := ["handle_pull", "confirm_stamp", "frames_slide", "slots_close", "yoke_fit", "shutters_open",
	"launch_engine"]
const LOOPS := ["r12_hum", "r12_pressure", "r12_pressure_low", "r12_surface", "r12_terminal", "end_sea_day",
	"end_wide"]
const CROSSFADE := 3.0          # s, a stage's loop change
const ENDING_FADE := 4.0        # s, the chamber loops leaving at the ending's step 8

# ---------------------------------------------------------------------------------------------
# palette and geometry
# ---------------------------------------------------------------------------------------------
const INK := Ink.INK
const PAPER := Ink.PAPER
const BRUISE := Ink.BRUISE
const BLUE_INK := Ink.BLUE_INK
const BRASS := Color("b08a4a")
const BRASS_HI := Color("d4b270")
const ENAMEL := Color("ded8c6")
const PENCIL := Color("55585e")
const AMBER_HI := Color("ecce8c")
const TIMBER := Color("675d51")
const SHADOW := Color(0, 0, 0, 0.38)

const TYPE_CPS := 14.0          # strips and her hand, characters per second
const LIFT := 18.0              # a held card or yoke
const LAMP_LIT_TIME := 2.5      # the lit category plate on a refused ROUTE
const SLIDE_TIME := 1.0         # the frames recessing (P25)
const SHUTTER_TIME := 1.6       # the routing shutters rolling up
const COVERS_TIME := 0.6        # the slots closing (P26)
const WITHDRAW_TIME := 3.0      # the surface drawing back (P26's glance)
const HOLD_TIME := 1.5          # the arrival hold on the name frame
const TAB_FADE := 0.8           # between ending tableaux
const CHANGE_FADE := 1.2        # an instrument's before -> after
const COVER_SLIDE := 1.0

const GAUGE_C := Vector2(1170, 490)
const GAUGE_NUM_R := 27.0
const NEEDLE_PIVOT := Vector2(6, 54)
const WIN_C := Vector2(724, 346)
const WIN_RI := 224.0
const LID_X := 484.0
const LID_TOP := 110.0
const LID_BOT := 376.0
const LID_RUN := 40.0
const LID_WAIT := 50.0
## The brief's 0.35 / 0.25 left the lid all but invisible on the dark surface in captures at
## 1024x768; the owner wants the wrongness clearly seen, so it is raised.
const LID_ALPHA := 0.75
const LID_ALPHA_STILL := 0.5
const LAMP_B_X0 := 214.0
const LAMP_B_STEP := 146.0
const LAMP_B_Y := 160.0
const FRAMES_B := [130.0, 554.0, 978.0]
const FRAMES_C := [140.0, 554.0, 968.0]
const RACK_C := [110.0, 430.0, 750.0]
const RACK_B_X0 := 572.0        # view B: pocket i at RACK_B_X0 + 108 i
const STRIP_RECT := Rect2(1122, 612, 236, 56)
const SWITCH_AT := Vector2(1110, 700)
const ROUTE_AT := Vector2(1110, 840)
const SLOTS := {"sever": Vector2(140, 590), "continue": Vector2(888, 590)}
const BTN_X := {"sever": 100.0, "continue": 748.0}
const BTN_TEXT := {"sever": "BREAK CONNECTION AND LEAVE", "continue": "REMAIN AS WITNESS"}
const FINAL_LAMPS_Y := [200.0, 270.0]
const OVAL_AT := Vector2(274, 160)
const CAPTION := Rect2(514, 830, 420, 48)
const CAPTIONS := {
	"m_funnels": "LISTENING ROOM", "m_diaphragm": "MACHINE ROOM", "m_jars": "WET LABORATORY",
	"m_spoon": "KITCHEN AND MESS", "m_bed": "BUNK ROOM", "m_pen": "CHART ROOM",
	"m_funnel_venn": "LISTENING ROOM", "m_coat": "INTAKE OFFICE", "m_cup": "KITCHEN AND MESS",
}
## [before, after] sprite suffixes of each instrument tableau.
const PAIRS := {
	"m_funnels": ["on", "off"], "m_diaphragm": ["in", "still"], "m_jars": ["tilted", "level"],
	"m_spoon": ["up", "down"], "m_bed": ["pressed", "risen"], "m_pen": ["down", "up"],
	"m_funnel_venn": ["on", "off"], "m_coat": ["full", "slack"], "m_cup": ["cold", "warm"],
}
const INQUIRY_NAMES := ["Silas Rook", "Nora Bell", "T. Ives", "M. Lusk", "O. Pryce", "C. Doane", "S. Hart",
	"A. Tull", "Elias Venn"]
const INQUIRY_LAST := ["I cannot certify their absence.", "A. Mercer"]
const TERM_LINES := [
	["type", "SUBJECT BELL POSSESSES NO SURVIVING PERSONAL EFFECTS."],
	["pencil", "Personal effect identified. Repaired cup. Nora Bell."],
	["type", "SUBJECT IVES: RECORD COMPLETE."],
	["pencil", "Not complete. Ives wrote lying down."],
	["type", "DISCREPANCY DETECTED: SUBJECT CONTINUES."],
]
const COVER_STRIP := "LOCAL SURVEY: ONE OF…"
const COVER_LINE := "Nora Bell took her tea without sugar. Begin there."
const COVER_LINE_ROWS := ["Nora Bell took her tea without sugar.", "Begin there."]

var r: R12Sim:
	get:
		return sim as R12Sim

var textures := {}
var close: Node2D              # c_frames / c_routing / c_final (layer 5)
var tab_prev: Node2D           # the tableau fading out
var tab_cur: Node2D            # the tableau on show
var caption_node: Node2D       # her lines during the ending (the HUD and subtitles are hidden)
var mixer: LoopMixer

# --- presentation clocks (never saved) ---------------------------------------------------------
var hold_t := 0.0              # the arrival hold, seconds left
var needle_a := 133.0          # the gauge needle's resting angle, degrees from straight up
var withdraw_pending := false  # P26 committed; the surface has not yet drawn back on screen
var withdraw_t0 := -1.0        # time the withdrawal began (-1 = none)
var slide_pending := false     # P25: the frames wait for the frames_slide sound
var slide_t0 := -1.0
var terminal_pending := false  # P25: the terminal lamp waits for terminal_on
var shutters_pending := false  # P25: the routing shutters wait for shutters_open
var shutters_t0 := -1.0
var covers_pending := false    # P26: the slot covers wait for slots_close
var covers_t0 := -1.0
var lamp_t0 := -1.0            # a refused ROUTE lit a category plate
var strip_queue := []          # lines a strip_print fx is typing
var strip_starts := []         # time each queued line began typing
var strip_since := -1.0
var pv_route := ""             # a running preview animation ("sever" / "continue")
var pv_t0 := -1.0              # its clock (-1 = waiting for its sound)
var pv_since := 0.0
var fit_t0 := -1.0             # the yoke or bridge settling
var fit_what := ""
# --- the ending --------------------------------------------------------------------------------
var cur_tab := ""
var prev_tab := ""
var cur_step := -1
var cur_change := ""
var tab_done := false          # draw the current tableau complete (after a load or a jump)
var tab_t0 := 0.0
var fade_t0 := -99.0
var lines_out := 0
var am_t0 := -1.0
var change_t0 := -1.0
var pen_t0 := []
var index_t0 := -1.0
var pencil_t0 := []
var counter_t0 := -1.0
var paper_t0 := -1.0
var cover_line_t0 := -1.0

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	close = Node2D.new()
	close.name = "Close"
	layer.add_child(close)
	close.draw.connect(_draw_close)
	tab_prev = Node2D.new()
	tab_prev.name = "TableauPrev"
	layer.add_child(tab_prev)
	tab_prev.draw.connect(func() -> void: _draw_tab(tab_prev, prev_tab, true))
	tab_cur = Node2D.new()
	tab_cur.name = "Tableau"
	layer.add_child(tab_cur)
	tab_cur.draw.connect(func() -> void: _draw_tab(tab_cur, cur_tab, tab_done))
	caption_node = Node2D.new()
	caption_node.name = "Caption"
	layer.add_child(caption_node)
	caption_node.draw.connect(_draw_caption)
	mixer = LoopMixer.new()
	add_child(mixer)
	if game != null:
		for id in LOOPS:
			mixer.add_loop(id, game.load_audio(id))
	apply_instantly()
	redraw()

func _tex(id: String) -> Texture2D:
	if not textures.has(id):
		var path := DIR % id
		textures[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return textures[id]

# ---------------------------------------------------------------------------------------------
# state reads
# ---------------------------------------------------------------------------------------------
func _view() -> String:
	return r.local_view

func _stage() -> int:
	match r.stage():
		"s2":
			return 2
		"s1":
			return 1
	return 0

func _now() -> float:
	return time

func _since(t0: float) -> float:
	return _now() - t0 if t0 >= 0.0 else -1.0

## 0..1 over `dur` from t0 (eased); 1 with Motion off once started; 0 if not started.
func _k(t0: float, dur: float) -> float:
	if t0 < 0.0:
		return 0.0
	if not motion or dur <= 0.0:
		return 1.0
	return smoothstep(0.0, 1.0, clampf((_now() - t0) / dur, 0.0, 1.0))

func _in_ending() -> bool:
	return _view() == "ending"

func hold_active() -> bool:
	return hold_t > 0.0

# ---------------------------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------------------------
func tick(dt: float) -> void:
	if hold_t > 0.0:
		hold_t = maxf(0.0, hold_t - dt)
	var target := 118.0 if _stage() >= 2 else 133.0
	needle_a = move_toward(needle_a, target, dt * 6.0) if motion else target
	if strip_since >= 0.0 and _now() - strip_since > 14.0:
		_strip_clear()
	if not strip_queue.is_empty() and strip_starts.size() == strip_queue.size():
		var last: float = strip_starts[-1]
		var n: int = str(strip_queue[-1]).length()
		if not motion or _now() - last > n / TYPE_CPS + 0.4:
			_strip_clear()
	if pv_route != "":
		if pv_t0 < 0.0 and _now() - pv_since > 0.7:
			pv_t0 = _now()
		if pv_t0 >= 0.0 and _now() - pv_t0 > _preview_length(pv_route):
			pv_route = ""
	if slide_pending and _now() - slide_t0 > 3.0 and slide_t0 >= 0.0:
		slide_pending = false
	if _in_ending() and cur_change != "" and change_t0 < 0.0 and not tab_done and game != null \
			and _now() - tab_t0 > 0.5 and not game.chain_active():
		change_t0 = _now()
	if _in_ending() and cur_tab == "end_b_cover" and cover_line_t0 < 0.0 and game != null \
			and game.cur_text == COVER_LINE:
		cover_line_t0 = _now()
	tab_prev.visible = _in_ending() and prev_tab != "" and _since(fade_t0) < TAB_FADE
	tab_cur.visible = _in_ending()
	caption_node.visible = _in_ending()
	tab_cur.modulate.a = 1.0 if not tab_prev.visible else _k(fade_t0, TAB_FADE)
	close.visible = _view() in ["c_frames", "c_routing", "c_final"]
	_tick_audio(dt)
	redraw()

func redraw() -> void:
	queue_redraw()
	if close:
		close.queue_redraw()
		tab_prev.queue_redraw()
		tab_cur.queue_redraw()
		caption_node.queue_redraw()

# ---------------------------------------------------------------------------------------------
# sound
# ---------------------------------------------------------------------------------------------
static func _lin(db: float) -> float:
	return db_to_linear(db)

func loop_targets() -> Dictionary:
	var s := _stage()
	var t := {
		"r12_hum": _lin(-16.0 if s == 0 else -15.0),
		"r12_pressure": _lin(-15.0) if s < 2 else 0.0,
		"r12_pressure_low": _lin(-15.0) if s >= 2 else 0.0,
		"r12_surface": _lin(-22.0),
		"r12_terminal": _lin(-20.0) if s >= 1 and not terminal_pending else 0.0,
		"end_sea_day": 0.0,
		"end_wide": 0.0,
	}
	var choice := r.chosen()
	if choice == "":
		return t
	var step := r.ending_step()
	if choice == "sever":
		var out := lines_out if step == 0 and not tab_done else 8
		t["r12_hum"] = _lin(-15.0) * float(8 - out) / 8.0
		if step >= 7:
			t["r12_terminal"] = 0.0
		if step >= 8:
			t["r12_pressure_low"] = 0.0
			t["r12_surface"] = 0.0
			t["end_sea_day"] = _lin(-12.0)
	else:
		t["r12_hum"] = _lin(-15.0)
		t["r12_terminal"] = _lin(-20.0)
		if step >= 8:
			for id in ["r12_hum", "r12_pressure", "r12_pressure_low", "r12_surface", "r12_terminal"]:
				t[id] = 0.0
			t["end_wide"] = _lin(-14.0)
	return t

func loop_rates() -> Dictionary:
	var rates := {}
	for id in LOOPS:
		rates[id] = _lin(-12.0) / CROSSFADE
	if r.chosen() != "":
		var step := r.ending_step()
		if step >= 8:
			for id in LOOPS:
				rates[id] = _lin(-12.0) / ENDING_FADE
		elif r.chosen() == "sever" and step == 0:
			rates["r12_hum"] = _lin(-15.0) / 8.0 / 0.5   # each eighth over half a second
	return rates

func _tick_audio(dt: float) -> void:
	if mixer:
		mixer.tick(loop_targets(), loop_rates(), dt)

# ---------------------------------------------------------------------------------------------
# events
# ---------------------------------------------------------------------------------------------
func play_fx(id: String, e: Dictionary) -> void:
	match id:
		"notice":
			if str(e.get("which", "")) == "name_frame":
				hold_t = HOLD_TIME
		"card_seat":
			lamp_t0 = -1.0
		"strip_print":
			strip_queue = (e.get("lines", []) as Array).duplicate()
			strip_starts = []
			strip_since = _now()
		"frame_lamp":
			lamp_t0 = _now()
		"frames_slide":
			slide_pending = true
			slide_t0 = -1.0
		"terminal_lit":
			terminal_pending = true
			shutters_pending = true
			shutters_t0 = -1.0
		"preview", "final_preview":
			pv_route = str(e.get("route", ""))
			pv_t0 = -1.0
			pv_since = _now()
		"mismatch":
			pv_route = ""
		"slots_close":
			covers_pending = true
			covers_t0 = -1.0
			withdraw_pending = true
			withdraw_t0 = -1.0
		"yoke_fit", "bridge_seat":
			fit_what = id
			fit_t0 = _now()
		"ending":
			_start_step(int(e.get("step", 0)), str(e.get("tableau", "")), str(e.get("change", "")))

func on_sfx(id: String) -> void:
	match id:
		"strip_type":
			if strip_starts.size() < strip_queue.size():
				strip_starts.append(_now())
		"frames_slide":
			if slide_pending:
				slide_pending = false
				slide_t0 = _now()
		"terminal_on":
			terminal_pending = false
			if cur_tab == "c_continue" and am_t0 < 0.0:
				am_t0 = _now()
		"shutters_open":
			if shutters_pending:
				shutters_pending = false
				shutters_t0 = _now()
		"preview_out", "preview_move":
			if pv_route != "" and pv_t0 < 0.0:
				pv_t0 = _now()
		"slots_close":
			if covers_pending:
				covers_pending = false
				covers_t0 = _now()
		"inquiry_pen":
			if cur_tab == "end_a_inquiry" and pen_t0.size() < 2:
				pen_t0.append(_now())
		"index_type":
			if cur_tab == "end_b_terminal_1" and index_t0 < 0.0:
				index_t0 = _now()
		"pencil_correct":
			if cur_tab in ["end_b_terminal_1", "end_b_terminal_2"] and pencil_t0.is_empty():
				pencil_t0.append(_now())
		"counter_type":
			if cur_tab in ["end_b_terminal_2", "end_b_cover"] and counter_t0 < 0.0:
				counter_t0 = _now()
		"paper_cover":
			if cur_tab == "end_b_cover" and paper_t0 < 0.0:
				paper_t0 = _now()
	if id.begins_with("line_out_") and cur_tab == "c_sever":
		lines_out = maxi(lines_out, clampi(int(id.substr(9)), 0, 8))
	if id == cur_change and change_t0 < 0.0 and _in_ending():
		change_t0 = _now()

func _strip_clear() -> void:
	strip_queue = []
	strip_starts = []
	strip_since = -1.0

func _start_step(step: int, tab: String, change: String) -> void:
	if cur_tab != "" and tab != cur_tab and motion:
		prev_tab = cur_tab
		fade_t0 = _now()
	else:
		prev_tab = ""
		fade_t0 = -99.0
	cur_tab = tab
	cur_step = step
	cur_change = change
	tab_done = false
	tab_t0 = _now()
	lines_out = 0
	am_t0 = -1.0
	change_t0 = -1.0
	pen_t0 = []
	index_t0 = -1.0
	pencil_t0 = []
	counter_t0 = -1.0
	paper_t0 = -1.0
	cover_line_t0 = -1.0

func start_glance(target: String, _rect: Rect2) -> bool:
	if target != "window" or _view() != "room":
		return false
	withdraw_pending = false
	withdraw_t0 = _now()
	return true

func consume_click(_p: Vector2) -> bool:
	if hold_t > 0.0:
		hold_t = 0.0
		return true
	return false

func apply_instantly() -> void:
	hold_t = 0.0
	needle_a = 118.0 if _stage() >= 2 else 133.0
	withdraw_pending = false
	withdraw_t0 = -1.0
	slide_pending = false
	slide_t0 = -1.0
	terminal_pending = false
	shutters_pending = false
	shutters_t0 = -1.0
	covers_pending = false
	covers_t0 = -1.0
	lamp_t0 = -1.0
	_strip_clear()
	pv_route = ""
	pv_t0 = -1.0
	fit_t0 = -1.0
	fit_what = ""
	prev_tab = ""
	fade_t0 = -99.0
	if r != null and r.chosen() != "":
		cur_tab = r.tableau()
		cur_step = r.ending_step()
		cur_change = ""
		tab_done = true
		lines_out = 8
	else:
		cur_tab = ""
		cur_step = -1
		cur_change = ""
		tab_done = false
		lines_out = 0
	if mixer and r != null:
		mixer.snap(loop_targets())

func reset_presentation() -> void:
	apply_instantly()

# ---------------------------------------------------------------------------------------------
# core hooks
# ---------------------------------------------------------------------------------------------
func back_visible() -> bool:
	return not _view() in ["room", "ending"]

func back_label() -> String:
	return "◂ Chair" if _view() in ["frames", "routing"] else "Back"

func esc_action() -> String:
	return "menu" if _view() in ["room", "ending"] else "back"

func exits_active() -> bool:
	return _view() == "room" and hold_t <= 0.0

func hud_hidden() -> bool:
	return _view() == "ending"

func chain_gates() -> bool:
	return true

func exit_arrow(to_rid: String) -> String:
	return "left" if to_rid == "R11" else ""

## The [id, rect, label] rows of view `v` (the hotspots of a base wall, a close-up's controls).
func closeup_controls(v: String) -> Array:
	match v:
		"room":
			return HOTSPOTS
		"frames":
			return FRAMES_HOTSPOTS
		"routing":
			return ROUTING_HOTSPOTS
		"c_frames":
			return FRAMES_CONTROLS
		"c_routing":
			var out := ROUTING_CONTROLS.duplicate()
			for cid in R12Sim.CC_IDS:
				out.append([cid, _cc_rect(cid), "Card"])
			return out
		"c_final":
			return FINAL_CONTROLS
	return []

## Where consequence card `cid` lies: its tray well, or the slot it is in.
func _cc_rect(cid: String) -> Rect2:
	if r != null:
		var rt := r.routes()
		for route in R12Sim.ROUTES:
			if rt[route] == cid:
				return Rect2(SLOTS[route], Vector2(420, 150))
	return CC_WELLS[cid]

func action_at(p: Vector2) -> String:
	if _in_ending():
		return "ending_next"
	for h in closeup_controls(_view()):
		if h[1].has_point(p):
			return h[0]
	return ""

func hover_at(p: Vector2) -> String:
	if _in_ending():
		return ""
	return action_at(p)

func label_for(id: String) -> String:
	for v in [_view(), "room", "frames", "routing", "c_frames", "c_routing", "c_final"]:
		for h in closeup_controls(v):
			if h[0] == id:
				return h[2]
	return ""

func dev_rects() -> Array:
	var out := []
	for h in closeup_controls(_view()):
		out.append(h[1])
	return out

# ---------------------------------------------------------------------------------------------
# drawing helpers
# ---------------------------------------------------------------------------------------------
func _full(c: CanvasItem, id: String, a := 1.0) -> void:
	var t := _tex(id)
	if t and a > 0.0:
		c.draw_texture_rect(t, Rect2(Vector2.ZERO, SIZE), false, Color(1, 1, 1, a))

func _sprite(c: CanvasItem, id: String, at: Vector2, a := 1.0, s := 1.0) -> void:
	var t := _tex(id)
	if t and a > 0.0:
		c.draw_texture_rect(t, Rect2(at, t.get_size() * s), false, Color(1, 1, 1, a))

static func _tw(s: String, size: int, font: Font) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## Centred on x; y is the baseline.
static func _ctext(c: CanvasItem, s: String, x: float, y: float, size: int, col: Color, font: Font) -> void:
	c.draw_string(font, Vector2(x - _tw(s, size, font) / 2.0, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## Centred in rect (caps sit 0.36 em under the centre line).
static func _rtext(c: CanvasItem, s: String, rect: Rect2, size: int, col: Color, font: Font) -> void:
	var cen := rect.get_center()
	_ctext(c, s, cen.x, cen.y + size * 0.36, size, col, font)

static func _ltext(c: CanvasItem, s: String, x: float, y: float, size: int, col: Color, font: Font) -> void:
	c.draw_string(font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## Letter-spaced caps centred in rect.
static func _spaced(c: CanvasItem, s: String, rect: Rect2, size: int, col: Color, font: Font, gap: float) -> void:
	var w := 0.0
	for i in s.length():
		w += font.get_char_size(s.unicode_at(i), size).x + (gap if i < s.length() - 1 else 0.0)
	var x := rect.get_center().x - w / 2.0
	var y := rect.get_center().y + size * 0.36
	for i in s.length():
		c.draw_char(font, Vector2(x, y), s[i], size, col)
		x += font.get_char_size(s.unicode_at(i), size).x + gap

static func _wrap(s: String, width: float, size: int, font: Font) -> Array:
	var out := []
	var line := ""
	for word in s.split(" "):
		var trial: String = word if line == "" else line + " " + word
		if line != "" and _tw(trial, size, font) > width:
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out

## A small code-drawn enamel label plate with a brass rim.
static func _plate(c: CanvasItem, rect: Rect2) -> void:
	c.draw_rect(rect.grow(2.0), BRASS)
	c.draw_rect(rect, ENAMEL)
	c.draw_rect(rect.grow(2.0), INK, false, 1.5)

## The first chars of `s` typed from t0 at TYPE_CPS ("" before; all of it once done or still).
func _typed_n(s: String, t0: float, done := false) -> int:
	if done:
		return s.length()
	if t0 < 0.0:
		return 0
	if not motion:
		return s.length()
	return clampi(int((_now() - t0) * TYPE_CPS), 0, s.length())

func _lamp(c: CanvasItem, at: Vector2, on: bool, s := 1.0) -> void:
	var t := _tex("lamp_on" if on else "lamp_off")
	if t:
		var sz := t.get_size() * s
		c.draw_texture_rect(t, Rect2(at - sz / 2.0, sz), false)

func _square(c: CanvasItem, at: Vector2, size: float, col: Color) -> void:
	c.draw_rect(Rect2(at - Vector2(size, size) / 2.0, Vector2(size, size)), col)

# ---------------------------------------------------------------------------------------------
# the world layer: views A, B, C (and the arrival hold)
# ---------------------------------------------------------------------------------------------
func _draw() -> void:
	if r == null:
		return
	if hold_t > 0.0:
		_draw_view_b(self, "")
		return
	match _view():
		"frames", "c_frames":
			_draw_view_b(self, "")
		"routing", "c_routing", "c_final":
			_draw_view_c(self, "")
		_:
			_draw_view_a(self, "")

## View A, the chair wall. `tab` is an ending tableau ("a_day", "a_sit", "a_morning") or "" (live).
func _draw_view_a(c: CanvasItem, tab: String) -> void:
	_full(c, "view_a")
	var s := _stage()
	match tab:
		"a_day":
			_full(c, "a_daylight")
		"a_sit":
			_full(c, "a_surface_withdrawn")
		"a_morning":
			_full(c, "a_morning")
		_:
			if s >= 2 and not withdraw_pending:
				var k := _k(withdraw_t0, WITHDRAW_TIME) if withdraw_t0 >= 0.0 else 1.0
				_full(c, "a_surface", 1.0)
				_full(c, "a_surface_withdrawn", k)
			else:
				_full(c, "a_surface")
	if tab == "":
		_draw_lid(c)
	var low := (s >= 1 and tab == "") or tab in ["a_sit", "a_morning"]
	_full(c, "a_arm_low" if low else "a_arm_rest")
	if tab == "" and s >= 1:
		_full(c, "a_cushion_dent")
	if tab in ["a_sit", "a_morning"]:
		_full(c, "a_ada_seated")
	_draw_gauge(c, tab)

## The lid line: a pale line crossing the surface, top to bottom, then a long wait.
func _draw_lid(c: CanvasItem) -> void:
	var t := _tex("a_lid_line")
	if t == null:
		return
	var y := 250.0
	var a := LID_ALPHA_STILL
	if motion:
		var ph := fposmod(time, LID_RUN + LID_WAIT)
		if ph > LID_RUN:
			return
		y = lerpf(LID_TOP, LID_BOT, ph / LID_RUN)
		a = LID_ALPHA
	var yc := y + t.get_size().y / 2.0
	var hw := WIN_RI if yc >= WIN_C.y else sqrt(maxf(0.0, WIN_RI * WIN_RI - pow(WIN_C.y - yc, 2)))
	var x0 := maxf(LID_X, WIN_C.x - hw)
	var x1 := minf(LID_X + t.get_size().x, WIN_C.x + hw)
	if x1 - x0 < 4.0:
		return
	c.draw_texture_rect_region(t, Rect2(x0, y, x1 - x0, t.get_size().y), Rect2(x0 - LID_X, 0, x1 - x0, t.get_size().y),
		Color(1, 1, 1, a))

func _draw_gauge(c: CanvasItem, tab: String) -> void:
	# Nine tide ticks at the rim; the odd numerals inside them. The face (r 46) is too small for
	# all nine numerals to read at 1024x768 without colliding, so I, III, V, VII and IX carry them.
	var f := Ink.serif()
	for i in 9:
		var ang := deg_to_rad(-135.0 + 270.0 * i / 8.0)
		var dir := Vector2(sin(ang), -cos(ang))
		c.draw_line(GAUGE_C + dir * 38.0, GAUGE_C + dir * 45.0, INK, 2.0 if i % 2 == 0 else 1.2)
		if i % 2 == 0:
			var at := GAUGE_C + dir * GAUGE_NUM_R
			_ctext(c, GameSim.NUMERALS[i], at.x, at.y + 14 * 0.36, 14, INK if i < 8 else BRUISE.darkened(0.3), f)
	var t := _tex("a_gauge_needle")
	if t == null:
		return
	var a := needle_a if tab == "" else 118.0
	if motion and tab == "":
		a += (1.5 if _stage() < 2 else 0.5) * sin(TAU * 0.7 * time)
	c.draw_set_transform(GAUGE_C, deg_to_rad(a), Vector2.ONE)
	c.draw_texture(t, -NEEDLE_PIVOT)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## View B, the record wall. `tab` "b_dark" for the ending's dead indicators, or "" (live).
func _draw_view_b(c: CanvasItem, tab: String) -> void:
	_full(c, "view_b")
	var s := _stage() if tab == "" else 2
	var f := Ink.serif()
	if s >= 1:
		_full(c, "b_shutters_turned")
		_full(c, "b_copy_uncapped")
		_full(c, "b_frames_filled")
		if not terminal_pending or tab != "":
			_full(c, "b_terminal_lit")
	if tab == "b_dark":
		_full(c, "b_indicators_dark")
	else:
		_draw_lamp_glow(c)
	# the staff names under their lamps
	for i in 8:
		var rect := Rect2(159 + 146 * i, 206, 110, 26)
		_rtext(c, R12Sim.STAFF[i], rect, 16, INK, f)
	_spaced(c, "ADA MERCER", Rect2(474, 250, 500, 66), 30, INK, f, 7.0)
	for i in 3:
		_rtext(c, ["BODY", "PLACE", "NAME"][i], Rect2(FRAMES_B[i] + 40, 650, 260, 40), 22, INK, f)
	if s >= 1 and (not terminal_pending or tab != ""):
		var y := 816.0
		for line in ["AUTOMATIC", "COUNTERSIGN", "AVAILABLE."]:
			_ctext(c, line, 328, y, 12, INK, f)
			y += 15.0
	# the cards: in a frame window or in the rack, until the record is routed
	var fr := r.frames()
	for i in 3:
		var px: float = RACK_B_X0 + 108 * i
		var cid: String = R12Sim.RACK_ORDER[i]
		if s >= 1 or not r.card_in_rack(cid):
			# its pocket is empty: the painted card above the pocket front is covered
			c.draw_rect(Rect2(px + 6, 762, 88, 37), TIMBER)
		else:
			_sprite(c, "card", Vector2(px + 2, 764), 1.0, 0.32)
	if s == 0:
		for i in 3:
			var cid: String = fr[R12Sim.FRAME_IDS[i]]
			if cid != "":
				_sprite(c, "card", Vector2(FRAMES_B[i] + 170 - 48, 470 - 32), 1.0, 0.32)

## Each shuttered lamp's faint glow, breathing on its own tremolo (still with Motion off).
func _draw_lamp_glow(c: CanvasItem) -> void:
	for i in 8:
		var a := 0.17
		if motion:
			var f := 0.07 + 0.06 * i / 7.0
			a = 0.15 + 0.05 * sin(TAU * f * time + i * 0.9)
		var at := Vector2(LAMP_B_X0 + LAMP_B_STEP * i, LAMP_B_Y)
		c.draw_circle(at, 46.0, Color(AMBER_HI, a * 0.35))
		c.draw_circle(at, 34.0, Color(AMBER_HI, a * 0.6))

## View C, the routing wall. `tab` "c_sever" / "c_continue" in the ending, or "" (live).
func _draw_view_c(c: CanvasItem, tab: String) -> void:
	_full(c, "view_c")
	var s := _stage() if tab == "" else 2
	var f := Ink.serif()
	var st := _plate_state("sever", tab)
	var ct := _plate_state("continue", tab)
	if s >= 1:
		_draw_schematic(c, "sever", Rect2(140, 140, 480, 250), false, st)
		_draw_schematic(c, "continue", Rect2(828, 140, 480, 250), false, ct)
	if s < 2:
		# the four consequence cards stand in the holder until they are sealed into the plates
		for i in R12Sim.CC_IDS.size():
			if r.cc_in_tray(R12Sim.CC_IDS[i]) or r.held_cc() == R12Sim.CC_IDS[i]:
				_sprite(c, "cc_card", Vector2(499 + 120 * i, 578), 1.0, 0.3)
	if s == 0 or shutters_pending or (shutters_t0 >= 0.0 and _k(shutters_t0, SHUTTER_TIME) < 1.0):
		var k := 0.0 if s == 0 or shutters_pending else _k(shutters_t0, SHUTTER_TIME)
		var t := _tex("c_shutters_closed")
		if t and k < 1.0:
			var top := 84.0
			var h := (734.0 - top) * (1.0 - k)
			c.draw_texture_rect_region(t, Rect2(0, top, SIZE.x, h), Rect2(0, top, SIZE.x, h))
	if s >= 2:
		_full(c, "c_lamps_ready")
	var yoke_on := r.yoke() == "contacts" or tab == "c_sever"
	var seated := r.bridge_seated() or tab == "c_continue"
	if yoke_on:
		_full(c, "c_tray_empty")
		_full(c, "c_yoke_fitted")
	if seated:
		_full(c, "c_bridge_seated")
		if not ct.am:
			_lamp(c, Vector2(1150, 790), false, 0.9)
	if tab == "c_sever":
		_full(c, "c_handle_pulled")
	# labels: the feed studs and her terminal (code plates sized to their words)
	for k in 2:
		var cx := 550.0 + 170.0 * k
		var label: String = ["FEED A · SUBJECTS 1–4", "FEED B · SUBJECTS 5–8"][k]
		var w := _tw(label, 14, f) + 12.0
		var rect := Rect2(cx - w / 2.0, 865, w, 24)
		_plate(c, rect)
		_rtext(c, label, rect, 14, INK, f)
	var tl := "A. MERCER · WITNESS"
	var tw := _tw(tl, 16, f) + 16.0
	var trect := Rect2(1000 - tw / 2.0, 852, tw, 26)
	_plate(c, trect)
	_rtext(c, tl, trect, 16, INK, f)

## The lamps a routing schematic shows now: {subj: [8 bools], feed (SEVER), ev, am, slider, door}.
func _plate_state(route: String, tab: String, where := "c_routing") -> Dictionary:
	var d := {"subj": [true, true, true, true, true, true, true, true], "feed": true, "ev": true, "am": false,
		"slider": 0.0, "door": false}
	if tab == "c_sever":
		# the real lines going out: both plates show them; the feed goes with the last
		var out := 8 if tab_done else lines_out
		for i in 8:
			d.subj[i] = i >= out
		d.feed = out < 8
		d.ev = out < 8
		return d
	if tab == "c_continue":
		if route == "continue" and (tab_done or am_t0 >= 0.0):
			d.ev = false
			d.am = true
			d.slider = 1.0
		return d
	if pv_route != route or pv_t0 < 0.0 or _view() != where:
		return d
	var e := _now() - pv_t0
	if route == "sever":
		var n := 8 if not motion else clampi(int(floor(e / 0.5)) + 1, 0, 8)
		for i in 8:
			d.subj[i] = i >= n
		d.feed = motion and e < 4.0
		d.door = not motion or e >= 4.5
	else:
		d.slider = 1.0 if not motion else clampf(e / 2.5, 0.0, 1.0)
		if not motion or e >= 2.5:
			d.ev = false
			d.am = true
	return d

func _preview_length(route: String) -> float:
	if not motion:
		return 3.0
	return 6.0 if route == "sever" else 4.0

## A routing schematic on its enamel panel. `big` is the c_routing scale.
func _draw_schematic(c: CanvasItem, route: String, panel: Rect2, big: bool, d: Dictionary) -> void:
	var f := Ink.serif()
	var hs := 34 if big else 26
	var rs := 20 if big else 16
	var x0 := panel.position.x
	var y0 := panel.position.y
	var w := panel.size.x
	var sc := 1.1 if big else 0.8
	var row_y: Array = [y0 + 100, y0 + 230, y0 + 300] if big else [y0 + 70, y0 + 160, y0 + 214]
	var lamps_y := y0 + 150 if big else y0 + 108
	_ctext(c, route.to_upper(), x0 + w / 2.0, y0 + (52 if big else 38), hs, INK, f)
	c.draw_line(Vector2(x0 + w / 2.0 - 70, y0 + (62 if big else 46)), Vector2(x0 + w / 2.0 + 70, y0 + (62 if big else 46)),
		Color(INK, 0.6), 1.5)
	var labels: Array = ["SUBJECT LINES 1–8", "WITNESS FEED", "OUTER DOOR"]
	if route == "continue":
		labels[1] = "WITNESS FEED  E.V. → A.M."
	var lx := x0 + (40 if big else 30)
	for i in 3:
		_ltext(c, labels[i], lx, row_y[i], rs, INK, f)
	# the eight subject lamps
	var step := (w - 100.0) / 7.0
	for i in 8:
		var at := Vector2(x0 + 50 + step * i, lamps_y)
		_lamp(c, at, d.subj[i], sc)
		_ctext(c, str(i + 1), at.x, lamps_y + (40 if big else 30), 13 if big else 11, Color(INK, 0.8), f)
	# the feed row
	var fy: float = row_y[1] - rs * 0.36
	if route == "sever":
		_lamp(c, Vector2(x0 + w - 50, fy), d.feed, sc)
	else:
		var ev_x := x0 + w - (170.0 if big else 140.0)
		var am_x := x0 + w - 44.0
		c.draw_line(Vector2(ev_x + 16, fy), Vector2(am_x - 16, fy), Color(INK, 0.7), 2.0)
		_lamp(c, Vector2(ev_x, fy), d.ev, sc)
		_lamp(c, Vector2(am_x, fy), d.am, sc)
		var sx := lerpf(ev_x + 18, am_x - 18, d.slider)
		var sr := Rect2(sx - 7, fy - 9, 14, 18)
		c.draw_rect(sr, BRASS)
		c.draw_rect(sr, INK, false, 1.5)
	# the outer door
	var door := "OPEN" if d.door else "SHUT"
	var dw := _tw(door, rs, f)
	_ltext(c, door, x0 + w - 30 - dw, row_y[2], rs, INK, f)
	# a CONFIRM mismatch: the named row underlined, with a square at its left
	var mm: Dictionary = r.last_mismatch
	if not mm.is_empty() and str(mm.get("plate", "")) == route:
		var row := int(mm.get("row", 0))
		var tw := _tw(labels[row], rs, f)
		var uy: float = row_y[row] + 6
		c.draw_rect(Rect2(lx, uy, tw, 4), BRUISE)
		_square(c, Vector2(lx - 14, row_y[row] - rs * 0.36), 10.0, BRUISE)

# ---------------------------------------------------------------------------------------------
# layer 5: the close-ups
# ---------------------------------------------------------------------------------------------
func _draw_close() -> void:
	if r == null:
		return
	match _view():
		"c_frames":
			_draw_c_frames(close)
		"c_routing":
			_draw_c_routing(close)
		"c_final":
			_draw_c_final(close)

func _draw_c_frames(c: CanvasItem) -> void:
	_full(c, "c_frames")
	var f := Ink.serif()
	var done := _stage() >= 1
	var slide := 1.0
	if done:
		slide = 0.0 if slide_pending else (_k(slide_t0, SLIDE_TIME) if slide_t0 >= 0.0 else 1.0)
		_full(c, "c_frames_back", slide)
		_full(c, "c_frames_lit", slide)
	# category plates
	for i in 3:
		var fid: String = R12Sim.FRAME_IDS[i]
		var plate := Rect2(FRAMES_C[i] + 40, 540, 260, 64)
		if r.last_lamp_frame == fid and not done:
			var lit := (not motion) or (lamp_t0 >= 0.0 and _now() - lamp_t0 < LAMP_LIT_TIME)
			if lit:
				c.draw_rect(plate, Color(AMBER_HI, 0.45))
			c.draw_rect(plate.grow(2.0), BRUISE, false, 3.0)
		_rtext(c, R12Sim.FRAME_LABEL[fid], plate, 30, INK, f)
	# the cards
	var fr := r.frames()
	for i in 3:
		var cid: String = fr[R12Sim.FRAME_IDS[i]]
		if cid != "":
			var at := Vector2(FRAMES_C[i] + 20, 200)
			if done and slide > 0.0:
				# recessed with the frames: a touch smaller, in shadow
				var s := lerpf(1.0, 0.9, slide)
				var cen := at + Vector2(150, 100)
				_card(c, cid, cen - Vector2(150, 100) * s, s, Color(1, 1, 1).darkened(0.35 * slide))
			else:
				_card(c, cid, at)
	for i in 3:
		var cid: String = R12Sim.RACK_ORDER[i]
		var at := Vector2(RACK_C[i], 660)
		if r.held_card() == cid:
			if motion:
				c.draw_rect(Rect2(at + Vector2(8, 10 - LIFT), Vector2(300, 200)), SHADOW)
				_card(c, cid, at - Vector2(0, LIFT))
			else:
				_card(c, cid, at)
				c.draw_rect(Rect2(at, Vector2(300, 200)).grow(1.5), BRASS, false, 3.0)
		elif r.card_in_rack(cid):
			_card(c, cid, at)
	# the switch, the ROUTE key, the strip
	_sprite(c, "switch_witness" if r.switch() == "witness" else "switch_copy", SWITCH_AT)
	_rtext(c, "WITNESS", Rect2(SWITCH_AT + Vector2(22, 22), Vector2(82, 22)), 16, INK, f)
	_rtext(c, "COPY", Rect2(SWITCH_AT + Vector2(196, 22), Vector2(82, 22)), 16, INK, f)
	_sprite(c, "route_key_turned" if done else "route_key", ROUTE_AT)
	_draw_strip(c)

## A card at `at` (top-left), scale s: the painted card with its printed face.
func _card(c: CanvasItem, cid: String, at: Vector2, s := 1.0, mod := Color(1, 1, 1)) -> void:
	var t := _tex("card")
	if t:
		c.draw_texture_rect(t, Rect2(at, t.get_size() * s), false, mod)
	c.draw_set_transform(at, 0.0, Vector2(s, s))
	var f := Ink.serif()
	var col := Color(INK.r * mod.r, INK.g * mod.g, INK.b * mod.b)
	_ltext(c, r.card_header(cid).to_upper(), 16, 52, 13, col, f)
	c.draw_line(Vector2(16, 60), Vector2(284, 60), Color(col, 0.5), 1.0)
	var y := 82.0
	var lines := r.card_text(cid)
	for i in lines.size():
		var font: Font = Ink.hand() if cid == "trace" and i == lines.size() - 1 else f
		for wl in _wrap(str(lines[i]), 268, 15, font):
			_ltext(c, wl, 16, y, 15, col, font)
			y += 20.0
		y += 2.0
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_strip(c: CanvasItem) -> void:
	var f := Ink.serif()
	var shown := []
	if not strip_queue.is_empty():
		for i in strip_starts.size():
			var s: String = strip_queue[i]
			shown.append(s.substr(0, _typed_n(s, strip_starts[i])))
	else:
		shown = r.strip_lines()
	var rows := []
	for s in shown:
		rows.append_array(_wrap(str(s), STRIP_RECT.size.x - 12, 15, f))
	# a paper strip feeds upward: the newest row sits at the bottom
	var n := mini(rows.size(), 2)
	for i in n:
		var line: String = rows[rows.size() - n + i]
		_ltext(c, line, STRIP_RECT.position.x + 6, STRIP_RECT.position.y + 24 + 22 * i, 15, INK, f)

func _draw_c_routing(c: CanvasItem) -> void:
	_full(c, "c_routing")
	var f := Ink.serif()
	var sealed := _stage() >= 2
	_draw_schematic(c, "sever", Rect2(110, 100, 540, 360), true, _plate_state("sever", ""))
	_draw_schematic(c, "continue", Rect2(798, 100, 540, 360), true, _plate_state("continue", ""))
	for route in R12Sim.ROUTES:
		var key := Rect2(260, 470, 240, 90) if route == "sever" else Rect2(948, 470, 240, 90)
		var lr := Rect2(key.position.x + 40, key.end.y - 4, 160, 22)
		_plate(c, lr)
		_rtext(c, "PREVIEW", lr, 14, INK, f)
	# CONFIRM UNDERSTANDING
	var br := Rect2(616, 628, 216, 74)
	_plate(c, br)
	_ctext(c, "CONFIRM", br.get_center().x, br.position.y + 32, 20, INK, f)
	_ctext(c, "UNDERSTANDING", br.get_center().x, br.position.y + 60, 20, INK, f)
	# the consequence cards
	var rt := r.routes()
	for route in R12Sim.ROUTES:
		var cid: String = rt[route]
		if cid != "":
			var at: Vector2 = SLOTS[route] + Vector2(60, 0)
			if sealed:
				# the covers close over them; their top edges show
				at.y -= 34.0 * (0.0 if covers_pending else (_k(covers_t0, COVERS_TIME) if covers_t0 >= 0.0 else 1.0))
			_cc(c, cid, at)
	if sealed:
		var k := 0.0 if covers_pending else (_k(covers_t0, COVERS_TIME) if covers_t0 >= 0.0 else 1.0)
		_full(c, "c_routing_closed", k)
	for cid in R12Sim.CC_IDS:
		if r.held_cc() == cid:
			var at: Vector2 = CC_WELLS[cid].position + Vector2(5, 5)
			if motion:
				c.draw_rect(Rect2(at + Vector2(8, 10 - LIFT), Vector2(300, 150)), SHADOW)
				_cc(c, cid, at - Vector2(0, LIFT))
			else:
				_cc(c, cid, at)
				c.draw_rect(Rect2(at, Vector2(300, 150)).grow(1.5), BRASS, false, 3.0)
		elif r.cc_in_tray(cid):
			_cc(c, cid, CC_WELLS[cid].position + Vector2(5, 5))

func _cc(c: CanvasItem, cid: String, at: Vector2) -> void:
	_sprite(c, "cc_card", at)
	var f := Ink.serif()
	var y := at.y + 38
	for line in _wrap(R12Sim.CC_TEXT[cid], 270, 17, f):
		_ltext(c, line, at.x + 15, y, 17, INK, f)
		y += 25.0

func _draw_c_final(c: CanvasItem) -> void:
	_full(c, "c_final")
	var f := Ink.serif()
	# feed studs and her terminal
	for k in 2:
		var cx := 220.0 + 200.0 * k
		var rect := Rect2(cx - 82, 340, 164, 50)
		_plate(c, rect)
		_ctext(c, ["FEED A", "FEED B"][k], cx, 361, 18, INK, f)
		_ctext(c, ["SUBJECTS 1–4", "SUBJECTS 5–8"][k], cx, 383, 18, INK, f)
	_rtext(c, "A. MERCER · WITNESS", Rect2(1008, 176, 240, 30), 20, INK, f)
	# the lamp panel: eight subjects, then E.V. and A.M.
	var sv := _plate_state("sever", "", "c_final")
	var ct := _plate_state("continue", "", "c_final")
	var d := sv if pv_route == "sever" else ct
	for i in 8:
		var at := Vector2(600 + 64 * (i % 4), FINAL_LAMPS_Y[i / 4])
		_lamp(c, at, d.subj[i], 1.25)
		_ctext(c, str(i + 1), at.x, at.y + 33, 12, Color(Ink.PAPER, 0.85), f)
	var ev_on: bool = (sv.feed if pv_route == "sever" else ct.ev)
	_lamp(c, Vector2(620, 350), ev_on, 1.25)
	_lamp(c, Vector2(820, 350), ct.am, 1.25)
	_ctext(c, "E.V.", 668, 356, 14, PAPER, f)
	_ctext(c, "A.M.", 772, 356, 14, PAPER, f)
	if pv_route == "continue" and pv_t0 >= 0.0:
		var sx := lerpf(640, 800, ct.slider)
		c.draw_line(Vector2(640, 376), Vector2(800, 376), Color(PAPER, 0.5), 2.0)
		var sr := Rect2(sx - 7, 368, 14, 16)
		c.draw_rect(sr, BRASS)
		c.draw_rect(sr, INK, false, 1.5)
	# the PREVIEW key's word
	var pr := Rect2(644, 584, 160, 22)
	_plate(c, pr)
	_rtext(c, "PREVIEW", pr, 15, INK, f)
	# the handle's lock tongue across its slot
	var tongue := Rect2(1190, 506, 22, 40)
	c.draw_rect(tongue, BRASS)
	c.draw_rect(Rect2(1193, 509, 4, 34), BRASS_HI)
	c.draw_rect(tongue, INK, false, 2.0)
	# the yoke and the bridge
	var yt := _tex("yoke")
	if yt:
		var yat := Vector2(110, 455)
		if r.yoke() == "contacts":
			yat = Vector2(110, 210)
			if fit_what == "yoke_fit" and motion and fit_t0 >= 0.0:
				yat.y -= 12.0 * (1.0 - _k(fit_t0, 0.25))
			c.draw_texture(yt, yat)
		elif r.held_yoke():
			if motion:
				c.draw_texture(yt, yat + Vector2(8, 10), Color(0, 0, 0, 0.4))
				c.draw_texture(yt, yat - Vector2(0, LIFT))
			else:
				c.draw_texture(yt, yat)
				c.draw_rect(Rect2(yat + Vector2(36, 6), Vector2(348, 128)), BRASS, false, 3.0)
		else:
			c.draw_texture(yt, yat)
	if r.bridge_seated():
		var bat := Vector2(1008, 225)
		if fit_what == "bridge_seat" and motion and fit_t0 >= 0.0:
			bat.y -= 12.0 * (1.0 - _k(fit_t0, 0.25))
		_sprite(c, "bridge", bat)
	# the two buttons
	for route in R12Sim.ROUTES:
		var x0: float = BTN_X[route]
		var face := Rect2(x0 + 30, 730, 540, 140)
		var text: String = BTN_TEXT[route]
		var lines := _wrap(text, 500, 30, f)
		var refused: bool = r.refused_button == route
		var block := 38.0 * lines.size() + (30.0 if refused else 0.0)
		var y := face.get_center().y - block / 2.0 + 28.0
		for line in lines:
			_ctext(c, line, face.get_center().x, y, 30, INK, f)
			y += 38.0
		if refused:
			_ctext(c, "Preview first.", face.get_center().x, y + 2, 20, BRUISE, Ink.hand())

# ---------------------------------------------------------------------------------------------
# layer 5: the ending tableaux
# ---------------------------------------------------------------------------------------------
func _draw_tab(c: CanvasItem, id: String, done: bool) -> void:
	if r == null or id == "" or not _in_ending():
		return
	match id:
		"c_sever", "c_continue":
			_draw_view_c(c, id)
		"b_dark":
			_draw_view_b(c, "b_dark")
		"a_day", "a_sit", "a_morning":
			_draw_view_a(c, id)
		"end_a_record", "end_a_jetty":
			_full(c, id)
		"end_a_inquiry":
			_draw_inquiry(c, done)
		"end_a_page":
			_draw_page(c)
		"end_b_terminal_1", "end_b_terminal_2":
			_draw_terminal(c, id, done)
		"end_b_wide":
			_draw_wide(c)
		"end_b_cover":
			_draw_cover(c, done)
		_:
			if PAIRS.has(id):
				_draw_instrument(c, id, done)

func _draw_instrument(c: CanvasItem, id: String, done: bool) -> void:
	_full(c, "end_card")
	var pair: Array = PAIRS[id]
	var k := 1.0 if done else 0.0
	if not done and change_t0 >= 0.0:
		k = _k(change_t0, CHANGE_FADE)
	if k < 1.0:
		_sprite(c, "%s_%s" % [id, pair[0]], OVAL_AT)
	_sprite(c, "%s_%s" % [id, pair[1]], OVAL_AT, k)
	_rtext(c, CAPTIONS.get(id, ""), CAPTION, 22, INK, Ink.serif())

func _draw_inquiry(c: CanvasItem, done: bool) -> void:
	_full(c, "end_a_inquiry")
	var f := Ink.serif()
	_ctext(c, "HARBOUR BOARD OF INQUIRY", 724, 250, 26, INK, f)
	_ltext(c, "In the matter of Greywake Survey Station, Morrow Sound.", 400, 304, 18, INK, f)
	_ltext(c, "The witness is asked to certify that the station was found unoccupied.", 400, 344, 18, INK, f)
	# her hand: the nine names in two columns, then the refusal and her name
	var t0: float = pen_t0[0] if pen_t0.size() > 0 else -1.0
	var total := 0
	for n in INQUIRY_NAMES:
		total += str(n).length()
	var budget := _typed_n("x".repeat(total), t0, done)
	for i in INQUIRY_NAMES.size():
		var s: String = INQUIRY_NAMES[i]
		var n := mini(budget, s.length())
		budget -= n
		if n <= 0:
			break
		var at := Vector2(500 + 300 * (i / 5), 424 + 40 * (i % 5))
		Ink.handwriting(c, s, n, at, 22, i, n < s.length(), BLUE_INK)
	var t1: float = pen_t0[1] if pen_t0.size() > 1 else -1.0
	if t1 >= 0.0 and t0 >= 0.0 and motion:
		t1 = maxf(t1, t0 + total / TYPE_CPS + 0.4)   # the refusal waits for the ninth name
	var b2 := _typed_n("x".repeat(INQUIRY_LAST[0].length() + INQUIRY_LAST[1].length()), t1, done)
	var a := mini(b2, INQUIRY_LAST[0].length())
	if a > 0:
		Ink.handwriting(c, INQUIRY_LAST[0], a, Vector2(500, 664), 22, 20, a < INQUIRY_LAST[0].length(), BLUE_INK)
	var b := b2 - a
	if b > 0:
		Ink.handwriting(c, INQUIRY_LAST[1], b, Vector2(400, 742), 22, 21, b < INQUIRY_LAST[1].length(), BLUE_INK)

func _draw_page(c: CanvasItem) -> void:
	_full(c, "end_a_page")
	for i in INQUIRY_NAMES.size():
		var s: String = INQUIRY_NAMES[i]
		Ink.handwriting(c, s, s.length(), Vector2(570, 308 + 34 * i), 22, i, false, Color(BLUE_INK, 0.5))

func _draw_terminal(c: CanvasItem, id: String, done: bool) -> void:
	_full(c, "end_b_terminal")
	var f := Ink.serif()
	var pencil0: float = pencil_t0[0] if pencil_t0.size() > 0 else -1.0
	var rows: Array
	var starts: Array
	if id == "end_b_terminal_1":
		rows = TERM_LINES.slice(0, 2)
		starts = [index_t0, pencil0]
	else:
		rows = TERM_LINES
		# the second line types from the step's start; its correction waits for the pencil and the line
		var typed2 := tab_t0 + TERM_LINES[2][1].length() / TYPE_CPS
		starts = [-2.0, -2.0, tab_t0, maxf(pencil0, typed2) if pencil0 >= 0.0 else -1.0, counter_t0]
	for i in rows.size():
		var kind: String = rows[i][0]
		var s: String = rows[i][1]
		var t0: float = starts[i]
		var n := s.length() if t0 == -2.0 else _typed_n(s, t0, done)
		if n <= 0:
			continue
		var y := 340.0 + 42.0 * i
		if kind == "type":
			_ltext(c, s.substr(0, n), 230, y, 22, INK, f)
		else:
			Ink.handwriting(c, s, n, Vector2(250, y), 22, 40 + i, n < s.length(), PENCIL)

func _draw_wide(c: CanvasItem) -> void:
	_full(c, "end_b_wide")
	var a := 0.22
	if motion:
		a = 0.16 + 0.10 * (0.5 + 0.5 * sin(TAU * 0.1 * time))
	var at := Vector2(875, 614)
	# a smooth falloff: many faint discs, each a little smaller and stacked toward the window
	for k in 16:
		c.draw_circle(at, 76.0 - 4.2 * k, Color(AMBER_HI, a * 0.16))

func _draw_cover(c: CanvasItem, done: bool) -> void:
	_full(c, "end_b_cover")
	var f := Ink.serif()
	var n := _typed_n(COVER_STRIP, counter_t0, done)
	if n > 0:
		_ltext(c, COVER_STRIP.substr(0, n), 260, 394, 22, INK, f)
	var t := _tex("cover_sheet")
	if t == null:
		return
	var k := 1.0 if done else _k(paper_t0, COVER_SLIDE)
	if done or paper_t0 >= 0.0:
		var x := lerpf(1448.0, 374.0, k)
		c.draw_texture(t, Vector2(x, 330))
		var budget := _typed_n(COVER_LINE, cover_line_t0, done)
		for i in COVER_LINE_ROWS.size():
			var s: String = COVER_LINE_ROWS[i]
			var m := mini(budget, s.length())
			budget = maxi(0, budget - s.length() - 1)
			if m > 0:
				Ink.handwriting(c, s, m, Vector2(x + 96, 330 + 140 + 56 * i), 30, 60 + i, m < s.length(), BLUE_INK)

## Her lines while the HUD is hidden: the same typed subtitle, on the ending's own slab.
func _draw_caption() -> void:
	if game == null or game.cur_text == "":
		return
	var c := caption_node
	var f := Ink.serif()
	var s: String = game.cur_text
	var n := s.length() if not motion else mini(s.length(), int(game.line_t * GameView.TYPE_CPS))
	c.draw_rect(Rect2(20, 994, 1408, 80), Color(0.03, 0.06, 0.08, 0.9))
	var lines := _wrap(s, 1340, 24, f)
	var y := 1040.0 - 15.0 * (lines.size() - 1)
	var left := n
	for line in lines:
		var m := mini(left, str(line).length())
		left = maxi(0, left - str(line).length() - 1)
		var w := _tw(line, 24, f)
		_ltext(c, str(line).substr(0, m), 724 - w / 2.0, y, 24, PAPER, f)
		y += 30.0
	if game.chain_active():
		_ltext(c, "▸", 1392, 1040, 22, Color(PAPER, 0.55), f)
