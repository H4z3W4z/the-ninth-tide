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
## Plates that have a newer page (new files, never overwrites): the ending page table reads these.
const PAGE_TEX := {
	"end_a_record": "res://assets/stages/R12/r12_sever_office.png",
	"end_b_terminal": "res://assets/stages/R12/r12_continue_terminal.png",
	"end_b_field": "res://assets/stages/R12/end_b_wide_3.png",
	"end_b_wide": "res://assets/stages/R12/end_b_wide_3.png",
	"c_routing": "res://assets/rooms/R12/c_routing_preview.png",
}

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
	["rack_position_b", Rect2(98, 656, 130, 216), "Card: POSITION"],
	["rack_trace_a", Rect2(236, 656, 130, 216), "Card: MOVEMENT"],
	["rack_identity", Rect2(374, 656, 130, 216), "Card: CONTRACT"],
	["rack_trace", Rect2(512, 656, 130, 216), "Card: MOVEMENT"],
	["rack_identity_b", Rect2(650, 656, 130, 216), "Card: CONTRACT"],
	["rack_trace_b", Rect2(788, 656, 130, 216), "Card: MOVEMENT"],
	["rack_position", Rect2(926, 656, 130, 216), "Card: POSITION"],
	["look_strip", Rect2(1110, 600, 300, 80), "Strip"],
	["switch", Rect2(1110, 700, 300, 120), "Switch: WITNESS / COPY"],
	["route", Rect2(1110, 840, 300, 130), "ROUTE"],
]
const ROUTING_CONTROLS := [
	["look_sever", Rect2(110, 100, 540, 360), "SEVER plate"],
	["look_continue", Rect2(798, 100, 540, 360), "CONTINUE plate"],
	["preview_sever", Rect2(260, 470, 240, 90), "PREVIEW SEVER"],
	["preview_continue", Rect2(948, 470, 240, 90), "PREVIEW CONTINUE"],
]
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
	"launch_engine", "throat"]
## "Soften sudden sounds" cuts 12 dB unless listed here: the throat in the silence is capped at -18.
const SFX_SOFT_CUT := {"throat": 4.0}
const LOOPS := ["r12_hum", "r12_pressure", "r12_pressure_low", "r12_surface", "r12_terminal", "end_sea_day",
	"end_wide", "r12_mid"]
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
## The surface fills the back wall: a_surface_wide's pane (tools/art/rooms/R12.py GLASS; its iron
## frame is 12 px inside). GLASS_IN is the water inside the frame.
const GLASS := Rect2(200, 86, 1048, 344)
const GLASS_IN := Rect2(212, 98, 1024, 320)
## What hangs in front of the glass (the conduit, the caged lamp, the column's capital): the lid
## and the margin are cut round them, so the room stays in front of the water.
const GLASS_HOLES := [
	Rect2(964, 0, 32, 404),                                                  # the conduit
	Rect2(956, 88, 48, 18), Rect2(956, 228, 48, 18), Rect2(956, 358, 48, 18),  # its brass bands
	Rect2(247, 0, 7, 104), Rect2(232, 100, 36, 22), Rect2(230, 112, 40, 44),  # the caged lamp
	Rect2(884, 398, 192, 40),                                                # the column's capital
]
## The lid: a stark dark band the full width of the window. It comes down only when the sim
## blinks (twice a game): closing over BLINK_CLOSE, held shut BLINK_HOLD, opening over BLINK_OPEN.
## With Motion off it is simply shut for the whole blink, then gone.
const LID_COLOR := Color("141d29")
const LID_EDGE := Color("a9c8b8")
const BLINK_CLOSE := 0.5
const BLINK_HOLD := 0.35
const BLINK_OPEN := 0.65
const BLINK_TIME := BLINK_CLOSE + BLINK_HOLD + BLINK_OPEN
## The eye (a_surface_eye_r3.png: the surface field with the iris at its centre, wider and taller
## than the glass so it can turn) and its slit pupil (a_pupil_r3.png), centred on EYE_C plus
## R12Sim.pupil_offset(). An eye_look fx turns it over LOOK_TIME, eased in and out; with Motion
## off it is simply where it looks. The pupil leads the iris a little (PUPIL_LEAD of the offset).
const EYE_C := Vector2(724, 258)            # GLASS_IN's centre
const LOOK_TIME := 0.8
const PUPIL_LEAD := 0.2
const EYE_SCALE_P26 := 1.15                 # after P26 the eye is closer
## The window's water line: water standing inside the pane, up from the sill. After P25 it
## stands WATER_RISE higher.
const WATER_Y := 382.0
const WATER_RISE := 80.0
const WATER_COLOR := Color(0x7f / 255.0, 0x95 / 255.0, 0x90 / 255.0, 0.24)
const WATER_EDGE := Color("a9c8b8")
## The previews' two lamps, reflected in the pupil: offsets from its centre.
const PUPIL_LAMPS := [Vector2(-52, -8), Vector2(52, -8)]
## Ending B's morning: the chamber window goes grey, flat, over the eye.
const MORNING_GREY := Color(0x9a / 255.0, 0xa4 / 255.0, 0xa8 / 255.0, 0.7)
## A held breath: the chamber's loops go silent over BREATH_OUT, come back over BREATH_IN.
const BREATH_OUT := 0.15
const BREATH_IN := 0.8
const BREATH_IN_SOFT := 1.6
## The previews in the window (P26): a_prev_*.png, GLASS_IN-sized; positions match
## tools/art/rooms/R12.py PREV_*. Times are seconds after the glance.
const PREV_FRAME_X := [112, 200, 288, 376, 464, 552, 640, 728]
const PREV_LAMP_Y := 30.0
const PREV_IN := 0.6
const PREV_LAMP_AT := 1.0        # the first portrait lamp goes out
const PREV_LAMP_STEP := 0.45
const PREV_BOWLS_AT := 5.0
const PREV_FEED := [1.0, 3.5]    # the feed slides E.V. -> A.M.
const PREV_COAT := [3.5, 4.5]    # the oilskin comes up
const PREV_HOLD := 7.0
const PREV_OUT := 0.8
## After P26: the margin of darker water inside the glass edge (storm navy at 0.85).
const MARGIN_W := 40.0
const MARGIN_COLOR := Color(0x22 / 255.0, 0x30 / 255.0, 0x3a / 255.0, 0.85)
## Ending B's morning: warm light on the wall round the pane, never on the water.
const MORNING := Color("e8c27a")
const LAMP_B_X0 := 214.0
const LAMP_B_STEP := 146.0
const LAMP_B_Y := 160.0
const FRAMES_B := [130.0, 554.0, 978.0]
const FRAMES_C := [140.0, 554.0, 968.0]
## c_frames: seven rack slots (R12Sim.RACK_ORDER), slot i at RACK_X0 + RACK_STEP i.
const RACK_X0 := 98.0
const RACK_STEP := 138.0
const RACK_SLOT := Vector2(130, 216)
const RACK_Y := 656.0
const TAB := Vector2(118, 196)  # a card standing in its slot
const RACK_B_X0 := 572.0        # view B: pocket i at RACK_B_X0 + 108 i
const FELT := Color("30463f")
const STRIP_RECT := Rect2(1122, 612, 236, 56)
const SWITCH_AT := Vector2(1110, 700)
const ROUTE_AT := Vector2(1110, 840)
const BTN_X := {"sever": 100.0, "continue": 748.0}
const BTN_TEXT := {"sever": "BREAK CONNECTION AND LEAVE", "continue": "REMAIN AS WITNESS"}
const FINAL_LAMPS_Y := [200.0, 270.0]
const OVAL_AT := Vector2(80, 40)     # the instrument tableau window in end_card
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
## The kitchen's window in end_b_wide_2 / end_b_wide_3 (tools/art/rooms/R12.py wide2_lit_at()).
const FIELD_GLOW := Vector2(723.5, 643)
## The ending's 'Go on' button, at the right end of the subtitle bar; it fades in over CONT_FADE.
const CAPTION_BAR := Rect2(20, 994, 1408, 80)
const CONT_RECT := Rect2(1256, 1008, 156, 52)
const CONT_FADE := 0.6
const CAPTION_W := 1150.0       # her line's wrap width, clear of the button
const CAPTION_X := 640.0        # and its centre
## Card faces: body text at least CARD_BODY px in plate space, wrapped.
const CARD_BODY := 18
## Typed strips and plaques: fitted from PLAQUE_MAX down to PLAQUE_MIN px, wrapped, never cut.
const PLAQUE_MAX := 16
const PLAQUE_MIN := 14
const AUTO_NEXT := 12.0         # s after the mark appears, the page turns by itself

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
var page_spoke := false        # the page's first line has gone up (ends SEVER's silence)
var cont_t0 := -1.0            # the 'Go on' button appeared (-1 = not yet)
var cont_node: Node2D          # the button, on its own node so it can fade
# --- the eye ----------------------------------------------------------------------------------
var gaze_at := Vector2.ZERO    # the eye's drawn offset (R12Sim.PUPIL_OFFSET, tweened)
var look_from := Vector2.ZERO  # the turn running: from, to, and its clock (-1 = none)
var look_to := Vector2.ZERO
var look_t0 := -1.0
var look_waits := []           # [{target, from, line, due}] turns waiting for their line
var blink_waits := []          # [{line, due}] blinks the sim has asked for, waiting for their line
var blink_t0 := -1.0           # the lid's clock (-1 = no blink)
var breath_waits := []         # [{seconds, line|sfx+lead|due}] held breaths waiting to start
var breath_until := -1.0       # the chamber is silent until this time
var win_route := ""            # the preview the window shows ("" = none)
var win_t0 := -1.0             # its clock (-1 = waiting for the glance)

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
	cont_node = Node2D.new()
	cont_node.name = "GoOn"
	layer.add_child(cont_node)
	cont_node.draw.connect(func() -> void: _draw_cont(cont_node))
	mixer = LoopMixer.new()
	add_child(mixer)
	if game != null:
		for id in LOOPS:
			mixer.add_loop(id, game.load_audio(id))
	apply_instantly()
	redraw()

func _tex(id: String) -> Texture2D:
	if not textures.has(id):
		var path: String = PAGE_TEX.get(id, DIR % id)
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
	_tick_eye(dt)
	if _in_ending() and cur_change != "" and change_t0 < 0.0 and not tab_done and game != null \
			and _now() - tab_t0 > 0.5 and not game.chain_active():
		change_t0 = _now()
	if _in_ending() and cur_tab == "end_b_cover" and cover_line_t0 < 0.0 and game != null \
			and game.cur_text == COVER_LINE:
		cover_line_t0 = _now()
	_tick_ending()
	tab_prev.visible = _in_ending() and prev_tab != "" and _since(fade_t0) < TAB_FADE
	tab_cur.visible = _in_ending()
	caption_node.visible = _in_ending()
	cont_node.visible = _in_ending() and cont_visible()
	cont_node.modulate.a = cont_alpha()
	tab_cur.modulate.a = 1.0 if not tab_prev.visible else _k(fade_t0, TAB_FADE)
	close.visible = _view() in ["c_frames", "c_routing", "c_final"]
	_tick_audio(dt)
	redraw()

## The eye: the pupil eases to where the sim says it looks; a waiting blink or held breath
## starts when its line goes up (or its sound is `lead` s off); the window's preview runs out.
func _tick_eye(_dt: float) -> void:
	var cur: String = game.cur_text if game != null else ""
	for i in range(look_waits.size() - 1, -1, -1):
		var w: Dictionary = look_waits[i]
		if (w.line != "" and cur == w.line) or _now() >= w.due:
			look_waits.remove_at(i)
			_turn_to(w.target)
	if look_t0 >= 0.0:
		var e := (_now() - look_t0) / LOOK_TIME
		if not motion or e >= 1.0:
			gaze_at = look_to
			look_t0 = -1.0
		else:
			gaze_at = look_from.lerp(look_to, smoothstep(0.0, 1.0, clampf(e, 0.0, 1.0)))
	for i in range(blink_waits.size() - 1, -1, -1):
		var w: Dictionary = blink_waits[i]
		if (w.line != "" and cur == w.line) or _now() >= w.due:
			blink_waits.remove_at(i)
			blink_t0 = _now()
	for i in range(breath_waits.size() - 1, -1, -1):
		var w: Dictionary = breath_waits[i]
		if (w.line != "" and cur == w.line) or _now() >= w.due:
			breath_waits.remove_at(i)
			_hold_breath(w.seconds)
	if win_route != "" and win_t0 >= 0.0 and _now() - win_t0 > PREV_HOLD + PREV_OUT:
		win_route = ""
		win_t0 = -1.0

## The eye turns to `target` from wherever it is drawn now (Motion off: it is simply there).
func _turn_to(target: String) -> void:
	var o: Array = R12Sim.PUPIL_OFFSET.get(target, [0, 0])
	look_from = gaze_at
	look_to = Vector2(o[0], o[1])
	look_t0 = _now()
	if not motion:
		gaze_at = look_to
		look_t0 = -1.0

func look_running() -> bool:
	return look_t0 >= 0.0

func _hold_breath(seconds: float) -> void:
	breath_until = maxf(breath_until, _now() + seconds)

## True while the chamber holds its breath: every loop at 0.
func breath_held() -> bool:
	return breath_until >= 0.0 and _now() < breath_until

## 0..1, how far the lid is down (0 when no blink is running).
func blink_k() -> float:
	if blink_t0 < 0.0:
		return 0.0
	var e := _now() - blink_t0
	if e < 0.0 or e >= BLINK_TIME:
		return 0.0
	if not motion:
		return 1.0
	if e < BLINK_CLOSE:
		return smoothstep(0.0, 1.0, e / BLINK_CLOSE)
	if e < BLINK_CLOSE + BLINK_HOLD:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (e - BLINK_CLOSE - BLINK_HOLD) / BLINK_OPEN)

## The ending's own clock: which of the page's lines have gone up, and the 'continue' mark once
## the page has finished (its lines read, its sounds played). Unanswered, the mark turns the
## page itself after AUTO_NEXT: presentation timing only; the sim just sees ending_next.
func _tick_ending() -> void:
	if not _in_ending() or game == null or r.chosen() == "":
		cont_t0 = -1.0
		return
	var st: Dictionary = R12Sim.steps(r.chosen())[r.ending_step()]
	var said: Array = st.lines
	if not page_spoke and not said.is_empty() and game.cur_text == said[0][1]:
		page_spoke = true
	if page_finished():
		if cont_t0 < 0.0:
			cont_t0 = _now()
		elif _now() - cont_t0 >= AUTO_NEXT:
			cont_t0 = -1.0
			game.dispatch("ending_next")
	else:
		cont_t0 = -1.0

## The page on show has said everything and played every sound, and its last line has had
## its read time.
func page_finished() -> bool:
	if not _in_ending() or game == null:
		return false
	if not tab_done and (cur_step != r.ending_step() or _now() - tab_t0 < 0.5):
		return false
	return not game.chain_active() and game.lines.is_empty() and game.pending_sfx.is_empty()

## Every line of the page on show has gone up and been read (its sounds may still be playing,
## e.g. SEVER's last line-outs): a click may turn the page without leaving a caption behind.
func captions_done() -> bool:
	if not _in_ending() or game == null:
		return false
	if not tab_done and (cur_step != r.ending_step() or _now() - tab_t0 < 0.5):
		return false
	return not game.chain_active() and game.lines.is_empty()

func cont_visible() -> bool:
	return cont_t0 >= 0.0

## The button's alpha: it fades in over CONT_FADE once the page is done (its last line has had
## its read time); with Motion off it is simply there. No pulse.
func cont_alpha() -> float:
	if not cont_visible():
		return 0.0
	if not motion:
		return 1.0
	return clampf((_now() - cont_t0) / CONT_FADE, 0.0, 1.0)

func redraw() -> void:
	queue_redraw()
	if close:
		close.queue_redraw()
		tab_prev.queue_redraw()
		tab_cur.queue_redraw()
		caption_node.queue_redraw()
		cont_node.queue_redraw()

# ---------------------------------------------------------------------------------------------
# sound
# ---------------------------------------------------------------------------------------------
static func _lin(db: float) -> float:
	return db_to_linear(db)

## The chamber's bed, loud enough to be heard on a laptop: the eight hums lift a dB after P25.
func hum_db() -> float:
	return -9.0 if _stage() == 0 else -8.0

const PRESSURE_DB := -10.0
const SURFACE_DB := -14.0
const TERMINAL_DB := -20.0
const R12_LOOPS := ["r12_hum", "r12_pressure", "r12_pressure_low", "r12_surface", "r12_terminal", "r12_mid"]
const LINE_OUT_FADE := 0.5      # s, each eighth of the hum after its line goes out
const WIDE_DB := -14.0          # CONTINUE's wide dark

## The mid band (r12_mid, mastered at -24/-28 dBFS): -6 dB, 2 dB up after P25 and 2 more after P26.
func mid_db() -> float:
	return -6.0 + 2.0 * _stage()

func loop_targets() -> Dictionary:
	var s := _stage()
	var t := {
		"r12_hum": _lin(hum_db()),
		"r12_pressure": _lin(PRESSURE_DB) if s < 2 else 0.0,
		"r12_pressure_low": _lin(PRESSURE_DB) if s >= 2 else 0.0,
		"r12_surface": _lin(SURFACE_DB),
		"r12_terminal": _lin(TERMINAL_DB) if s >= 1 and not terminal_pending else 0.0,
		"end_sea_day": 0.0,
		"end_wide": 0.0,
		"r12_mid": _lin(mid_db()),
	}
	var choice := r.chosen()
	if choice == "":
		return _breath_targets(t)
	var step := r.ending_step()
	if choice == "sever":
		var out := lines_out if step == 0 and not tab_done else 8
		t["r12_hum"] = _lin(hum_db()) * float(8 - out) / 8.0
		if sever_silence():
			# the last line has gone out: nothing at all, no bed, until the next page speaks
			for id in R12_LOOPS:
				t[id] = 0.0
		if step >= 7:
			t["r12_terminal"] = 0.0
		if step >= 8:
			t["r12_pressure_low"] = 0.0
			t["r12_surface"] = 0.0
			t["r12_mid"] = 0.0
			t["end_sea_day"] = _lin(-12.0)
	else:
		t["r12_hum"] = _lin(hum_db())
		t["r12_terminal"] = _lin(TERMINAL_DB)
		if step >= 8:
			for id in R12_LOOPS:
				t[id] = 0.0
			t["end_wide"] = _lin(WIDE_DB)
	return _breath_targets(t)

func _breath_targets(t: Dictionary) -> Dictionary:
	if breath_held():
		for id in t:
			t[id] = 0.0
	return t

## SEVER: from the moment the eighth line goes out until the next page's first line types,
## every chamber loop holds at 0.
func sever_silence() -> bool:
	if r == null or r.chosen() != "sever" or tab_done:
		return false
	var step := r.ending_step()
	if step == 0:
		return lines_out >= 8
	return step == 1 and not page_spoke

func loop_rates() -> Dictionary:
	var rates := {}
	for id in LOOPS:
		rates[id] = _lin(-12.0) / CROSSFADE
	if r.chosen() != "":
		var step := r.ending_step()
		if step >= 8:
			for id in LOOPS:
				rates[id] = _lin(-12.0) / ENDING_FADE
		elif r.chosen() == "sever" and step <= 1:
			# each eighth of the hum over half a second as its line goes out (the gaps come from
			# the step's sfx table); after the eighth, the rest of the bed goes as fast
			rates["r12_hum"] = _lin(hum_db()) / 8.0 / LINE_OUT_FADE
			if sever_silence():
				for id in ["r12_pressure", "r12_pressure_low", "r12_surface", "r12_terminal", "r12_mid"]:
					rates[id] = _lin(PRESSURE_DB) / LINE_OUT_FADE
	# a held breath: out at once, back slowly (slower still with Soften sudden sounds)
	if breath_held():
		for id in LOOPS:
			rates[id] = _lin(-6.0) / BREATH_OUT
	elif breath_until >= 0.0 and _now() - breath_until < BREATH_IN_SOFT:
		for id in LOOPS:
			rates[id] = minf(rates[id], _lin(-8.0) / (BREATH_IN_SOFT if soft_audio else BREATH_IN))
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
		"window_preview":
			# shown in the window when the glance puts the close-up down
			win_route = str(e.get("route", ""))
			win_t0 = -1.0
		"surface_withdraw":
			withdraw_pending = true
			withdraw_t0 = -1.0
		"eye_look":
			var target := str(e.get("target", "centre"))
			var line := str(e.get("line", ""))
			var delay := float(e.get("delay", 0.0))
			if line != "" or delay > 0.0:
				# shown where it was until its line goes up (the entry snapped it to the new look)
				var f: Array = R12Sim.PUPIL_OFFSET.get(str(e.get("from", "centre")), [0, 0])
				gaze_at = Vector2(f[0], f[1])
				look_t0 = -1.0
				look_waits.append({"target": target, "line": line,
					"due": _now() + delay + (30.0 if line != "" else 0.0)})
			else:
				_turn_to(target)
		"blink":
			blink_waits.append({"line": str(e.get("line", "")), "due": _now() + float(e.get("delay", 0.0)) + 30.0})
		"hold_breath":
			var secs := float(e.get("seconds", 1.5))
			if str(e.get("sfx", "")) != "":
				breath_waits.append({"line": "", "due": INF, "sfx": str(e.sfx), "lead": float(e.get("lead", 0.0)),
					"seconds": secs})
			else:
				breath_waits.append({"line": str(e.get("line", "")), "seconds": secs,
					"due": _now() + float(e.get("delay", 0.0)) + (30.0 if str(e.get("line", "")) != "" else 0.0)})
		"yoke_fit", "bridge_seat":
			fit_what = id
			fit_t0 = _now()
		"ending":
			_start_step(int(e.get("step", 0)), str(e.get("tableau", "")), str(e.get("change", "")))

## A held breath keyed to a sound starts `lead` s before it plays.
func on_sfx_pending(id: String, left: float) -> void:
	for i in range(breath_waits.size() - 1, -1, -1):
		var w: Dictionary = breath_waits[i]
		if str(w.get("sfx", "")) == id and left <= float(w.lead):
			breath_waits.remove_at(i)
			_hold_breath(w.seconds)

func on_sfx(id: String) -> void:
	on_sfx_pending(id, 0.0)
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
	page_spoke = false
	cont_t0 = -1.0

## The window's glance (P26): the preview it was asked to show, and the surface drawing back
## with it once P26 is done. The room shows both itself.
func start_glance(target: String, _rect: Rect2) -> bool:
	if not target.begins_with("window") or _view() != "room":
		return false
	var route := target.substr(7) if target.begins_with("window_") else ""
	if route in R12Sim.ROUTES:
		win_route = route
		win_t0 = _now()
	if withdraw_pending:
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
	lamp_t0 = -1.0
	_strip_clear()
	pv_route = ""
	pv_t0 = -1.0
	fit_t0 = -1.0
	fit_what = ""
	prev_tab = ""
	fade_t0 = -99.0
	cont_t0 = -1.0
	page_spoke = false
	blink_waits = []
	blink_t0 = -1.0
	breath_waits = []
	breath_until = -1.0
	win_route = ""
	win_t0 = -1.0
	look_waits = []
	look_t0 = -1.0
	if r != null:
		gaze_at = r.pupil_offset()
		look_to = gaze_at
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
			return ROUTING_CONTROLS
		"c_final":
			return FINAL_CONTROLS
	return []

## In the ending a click turns the page only once the page is done (or its mark is up);
## before that it returns "" and the core's click advances her lines instead, so the caption
## never runs ahead of, or behind, the plate it belongs to.
func action_at(p: Vector2) -> String:
	if _in_ending():
		return "ending_next" if page_finished() or cont_visible() or captions_done() else ""
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
			# it stays drawn back from the glass
			_full(c, "a_surface_wide")
			_draw_eye(c)
			_draw_water(c)
			_draw_margin(c, 1.0)
		"a_morning":
			# morning reaches the windows: the chamber's goes grey, flat, over the eye
			_full(c, "a_surface_wide")
			_draw_eye(c)
			_draw_water(c)
			_draw_margin(c, 1.0)
			_glass_rect(c, GLASS_IN, MORNING_GREY)
		_:
			_full(c, "a_surface_wide")
			_draw_eye(c)
			_draw_water(c)
			if s >= 2:
				_draw_margin(c, _withdraw_k())
	if tab == "":
		_draw_window_preview(c)
		_draw_pupil_lamps(c)
		_draw_lid(c)
	# the stage marks on the chamber itself: the tide line rising up the wainscot, the gauge's
	# bowed bezel (S2), the seat pressed hollow (S1+)
	if s >= 1 and tab != "a_day":
		_full(c, "a_stain_2" if s >= 2 else "a_stain_1")
	if s >= 2 and tab != "a_day":
		_full(c, "a_gauge_pinned")
	var low := (s >= 1 and tab == "") or tab in ["a_sit", "a_morning"]
	if tab == "" and s >= 2:
		_full(c, "a_arm_ready")
	else:
		_full(c, "a_arm_low" if low else "a_arm_rest")
	if tab == "" and s >= 1:
		_full(c, "a_cushion_dent")
	if tab in ["a_sit", "a_morning"]:
		_full(c, "a_ada_seated")
	_draw_gauge(c, tab)
	if tab == "a_morning":
		_draw_morning(c)

func _withdraw_k() -> float:
	if _stage() < 2 or withdraw_pending:
		return 0.0
	return _k(withdraw_t0, WITHDRAW_TIME) if withdraw_t0 >= 0.0 else 1.0

## The lid's lower edge now (y): the top of the water when open, its bottom when shut.
func lid_bottom() -> float:
	return lerpf(GLASS_IN.position.y, GLASS_IN.end.y, blink_k())

## The blink: a stark dark lid the full width of the window, coming down from the top of the
## glass to its sill and going back up, its edge a sea-glass line. Only while the sim blinks.
func _draw_lid(c: CanvasItem) -> void:
	var k := blink_k()
	if k <= 0.0:
		return
	var y := lid_bottom()
	var g := GLASS_IN
	_glass_rect(c, Rect2(g.position.x, g.position.y, g.size.x, y - g.position.y), LID_COLOR)
	if k < 1.0:
		_glass_rect(c, Rect2(g.position.x, y - 3.0, g.size.x, 3.0), LID_EDGE)

## The eye's scale: closer (x1.15) once P26 is done.
func eye_scale() -> float:
	return EYE_SCALE_P26 if _stage() >= 2 else 1.0

## The eye's centre in the room now.
func eye_centre() -> Vector2:
	return EYE_C + gaze_at

## The pupil's centre: the iris's, led a little further the way the eye looks.
func pupil_centre() -> Vector2:
	return EYE_C + gaze_at * (1.0 + PUPIL_LEAD) * eye_scale()

## The eye: the surface field and iris (a_surface_eye_r3) at its gaze, scaled after P26, then the
## slit pupil (a_pupil_r3). Clipped to the water, the room in front of it.
func _draw_eye(c: CanvasItem) -> void:
	var sc := eye_scale()
	_glass_tex_scaled(c, _tex("a_surface_eye_r3"), eye_centre(), sc)
	_glass_tex_scaled(c, _tex("a_pupil_r3"), pupil_centre(), sc)

## Draws `t` centred on `centre` at scale `sc`, clipped to the water and cut round the holes.
func _glass_tex_scaled(c: CanvasItem, t: Texture2D, centre: Vector2, sc: float, a := 1.0) -> void:
	if t == null or a <= 0.0:
		return
	var size := t.get_size() * sc
	var dest := Rect2(centre - size / 2.0, size)
	for p in _glass_parts(dest):
		c.draw_texture_rect_region(t, p, Rect2((p.position - dest.position) / sc, p.size / sc), Color(1, 1, 1, a))

## The water line in the window: water standing inside the pane, up from the sill (higher after
## P25). A flat band of darker water and a pale line on it; the eye still reads through it.
func water_y() -> float:
	return WATER_Y - (WATER_RISE if _stage() >= 1 else 0.0)

func _draw_water(c: CanvasItem) -> void:
	var y := water_y()
	_glass_rect(c, Rect2(GLASS_IN.position.x, y, GLASS_IN.size.x, GLASS_IN.end.y - y), WATER_COLOR)
	_glass_rect(c, Rect2(GLASS_IN.position.x, y - 1.5, GLASS_IN.size.x, 3.0), Color(WATER_EDGE, 0.85))

## The previews, reflected in the pupil: two small lamp points. SEVER: both lit, then out one
## by one with the portrait lamps. CONTINUE: his goes out as the feed moves; the kitchen's stays.
func pupil_lamps() -> Array:
	var a := window_preview_a()
	if a <= 0.0:
		return [false, false]
	if win_route == "sever":
		var out := window_lamps_out()
		return [out < 4, out < 8]
	return [window_feed()[0] < 1.0, true]

func _draw_pupil_lamps(c: CanvasItem) -> void:
	var a := window_preview_a()
	if a <= 0.0:
		return
	var lit := pupil_lamps()
	var sc := eye_scale()
	for i in 2:
		var at: Vector2 = pupil_centre() + PUPIL_LAMPS[i] * sc
		if lit[i]:
			c.draw_circle(at, 16.0 * sc, Color(Ink.AMBER, 0.3 * a))
			c.draw_circle(at, 8.0 * sc, Color(AMBER_HI, a))
		else:
			c.draw_circle(at, 8.0 * sc, Color(Ink.STORM, a))
			c.draw_arc(at, 8.0 * sc, 0.0, TAU, 20, Color(LID_EDGE, 0.55 * a), 1.5)

## Draws `t` with its corner at `at`, clipped to the water and cut round what hangs in front.
func _glass_tex(c: CanvasItem, t: Texture2D, at: Vector2, a := 1.0) -> void:
	if t == null or a <= 0.0:
		return
	for p in _glass_parts(Rect2(at, t.get_size())):
		c.draw_texture_rect_region(t, p, Rect2(p.position - at, p.size), Color(1, 1, 1, a))

## `rect` within the water, less the holes, as rectangles.
func _glass_parts(rect: Rect2) -> Array:
	var parts := [rect.intersection(GLASS_IN)]
	for hole in GLASS_HOLES:
		var next := []
		for p in parts:
			next.append_array(_minus(p, hole))
		parts = next
	return parts.filter(func(p: Rect2) -> bool: return p.size.x > 0.0 and p.size.y > 0.0)

## 0..1 alpha of the window's preview (in, held, out), 0 when none is showing.
func window_preview_a() -> float:
	if win_route == "" or win_t0 < 0.0:
		return 0.0
	var e := _now() - win_t0
	if e < 0.0 or e > PREV_HOLD + PREV_OUT:
		return 0.0
	if not motion:
		return 1.0
	return clampf(e / PREV_IN, 0.0, 1.0) * clampf((PREV_HOLD + PREV_OUT - e) / PREV_OUT, 0.0, 1.0)

## How many of the eight portrait lamps are out in the SEVER preview (all at once, still).
func window_lamps_out() -> int:
	if win_route != "sever" or win_t0 < 0.0:
		return 0
	var e := _now() - win_t0
	if not motion:
		return 8 if e >= PREV_HOLD * 0.4 else 0
	return clampi(int(floor((e - PREV_LAMP_AT) / PREV_LAMP_STEP)) + 1, 0, 8)

## The CONTINUE preview: [feed 0..1 from E.V. to A.M., oilskin alpha 0..1].
func window_feed() -> Array:
	if win_route != "continue" or win_t0 < 0.0:
		return [0.0, 0.0]
	var e := _now() - win_t0
	if not motion:
		return [1.0, 1.0] if e >= PREV_HOLD * 0.4 else [0.0, 0.0]
	return [clampf((e - PREV_FEED[0]) / (PREV_FEED[1] - PREV_FEED[0]), 0.0, 1.0),
		clampf((e - PREV_COAT[0]) / (PREV_COAT[1] - PREV_COAT[0]), 0.0, 1.0)]

## The preview in the window: flat overlays over the eye, the lamps and the feed drawn here.
func _draw_window_preview(c: CanvasItem) -> void:
	var a := window_preview_a()
	if a <= 0.0:
		return
	var o := GLASS_IN.position
	if win_route == "sever":
		var out := window_lamps_out()
		var e := _now() - win_t0
		var dark := (not motion and out >= 8) or (motion and e >= PREV_BOWLS_AT)
		var dk := 1.0 if not motion else clampf((e - PREV_BOWLS_AT) / 0.8, 0.0, 1.0)
		_glass_tex(c, _tex("a_prev_sever_lit"), o, a * (1.0 - dk if dark else 1.0))
		# each portrait goes dark under its own lamp, one by one
		var dt := _tex("a_prev_sever_dark")
		if dt:
			for i in out:
				var col := Rect2(o + Vector2(PREV_FRAME_X[i] - 40, 0), Vector2(80, 128))
				for p in _glass_parts(col):
					c.draw_texture_rect_region(dt, p, Rect2(p.position - o, p.size), Color(1, 1, 1, a))
			if dark:
				_glass_tex(c, dt, o, a * dk)
	else:
		# his oilskin comes up in the window, empty; the feed's lamps are in the pupil
		var fd := window_feed()
		_glass_tex(c, _tex("a_prev_oilskin"), o, a * fd[1])

## The margin of darker water inside the glass edge, faded in by k.
func _draw_margin(c: CanvasItem, k: float) -> void:
	if k <= 0.0:
		return
	var col := Color(MARGIN_COLOR, MARGIN_COLOR.a * k)
	var g := GLASS_IN
	var m := MARGIN_W
	_glass_rect(c, Rect2(g.position.x, g.position.y, g.size.x, m), col)
	_glass_rect(c, Rect2(g.position.x, g.end.y - m, g.size.x, m), col)
	_glass_rect(c, Rect2(g.position.x, g.position.y + m, m, g.size.y - 2.0 * m), col)
	_glass_rect(c, Rect2(g.end.x - m, g.position.y + m, m, g.size.y - 2.0 * m), col)

## Fills `rect` clipped to the water and cut round what hangs in front of it.
func _glass_rect(c: CanvasItem, rect: Rect2, col: Color) -> void:
	var parts := [rect.intersection(GLASS_IN)]
	for hole in GLASS_HOLES:
		var next := []
		for p in parts:
			next.append_array(_minus(p, hole))
		parts = next
	for p in parts:
		if p.size.x > 0.0 and p.size.y > 0.0:
			c.draw_rect(p, col)

## `a` less `b`, as up to four rectangles.
static func _minus(a: Rect2, b: Rect2) -> Array:
	if a.size.x <= 0.0 or a.size.y <= 0.0:
		return []
	if not a.intersects(b):
		return [a]
	var i := a.intersection(b)
	var out := []
	if i.position.y > a.position.y:
		out.append(Rect2(a.position.x, a.position.y, a.size.x, i.position.y - a.position.y))
	if i.end.y < a.end.y:
		out.append(Rect2(a.position.x, i.end.y, a.size.x, a.end.y - i.end.y))
	if i.position.x > a.position.x:
		out.append(Rect2(a.position.x, i.position.y, i.position.x - a.position.x, i.size.y))
	if i.end.x < a.end.x:
		out.append(Rect2(i.end.x, i.position.y, a.end.x - i.end.x, i.size.y))
	return out

## Ending B's morning: warm light down the wall round the pane (strongest high up, gone by the
## wainscot), never on the water. Flat bands, no flicker.
func _draw_morning(c: CanvasItem) -> void:
	var g := GLASS
	var bands := [
		Rect2(0, 0, SIZE.x, g.position.y),                                  # over the pane
		Rect2(0, g.position.y, g.position.x, g.size.y),                     # left of it
		Rect2(g.end.x, g.position.y, SIZE.x - g.end.x, g.size.y),           # right of it
	]
	for b in bands:
		_vgrad(c, b, Color(MORNING, 0.34), Color(MORNING, 0.24))
	_vgrad(c, Rect2(0, g.end.y, SIZE.x, 700.0 - g.end.y), Color(MORNING, 0.24), Color(MORNING, 0.0))

static func _vgrad(c: CanvasItem, r: Rect2, top: Color, bot: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	c.draw_polygon(pts, PackedColorArray([top, top, bot, bot]))

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
		_draw_lamp_glow(c, s)
	if s >= 1:
		# the NAME record: her name struck into the card in the third frame
		_spaced(c, "ADA MERCER", Rect2(FRAMES_B[2] + 62, 432, 216, 72), 24, INK, f, 3.0)
	# the staff names under their lamps
	for i in 8:
		var rect := Rect2(159 + 146 * i, 206, 110, 26)
		_rtext(c, R12Sim.STAFF[i], rect, 16, INK, f)
	_spaced(c, "ADA MERCER", Rect2(474, 250, 500, 66), 30, INK, f, 7.0)
	for i in 3:
		_rtext(c, ["BODY", "PLACE", "NAME"][i], Rect2(FRAMES_B[i] + 40, 650, 260, 40), 22, INK, f)
	if s >= 1 and (not terminal_pending or tab != ""):
		_draw_countersign(c)
	# the cards: in a frame window or in the rack, until the record is routed. The three painted
	# pockets are covered and the seven cards stand in a row across them, in their rack order.
	var fr := r.frames()
	for i in 3:
		c.draw_rect(Rect2(RACK_B_X0 + 108 * i + 6, 762, 88, 37), TIMBER)
	if s == 0:
		for i in R12Sim.RACK_ORDER.size():
			var cid: String = R12Sim.RACK_ORDER[i]
			if r.card_in_rack(cid):
				var at := Vector2(RACK_B_X0 + 2 + 46 * i, 760)
				c.draw_rect(Rect2(at, Vector2(42, 40)), ENAMEL)
				c.draw_rect(Rect2(at, Vector2(42, 40)), INK, false, 1.5)
				c.draw_line(at + Vector2(6, 10), at + Vector2(36, 10), Color(INK, 0.6), 1.5)
	if s == 0:
		for i in 3:
			var cid: String = fr[R12Sim.FRAME_IDS[i]]
			if cid != "":
				_sprite(c, "card", Vector2(FRAMES_B[i] + 170 - 48, 470 - 32), 1.0, 0.32)

## The countersign plaque on the witness terminal (view B, after P25): the strip's two lines in
## full on an enamel plate under the slot, as wide as they need (inside the terminal's face).
const COUNTERSIGN_TOP := 800.0
const COUNTERSIGN_CX := 300.0
const COUNTERSIGN_MAX_W := 300.0

func countersign_layout() -> Dictionary:
	var f := Ink.serif()
	var fit := fit_rows(R12Sim.STRIP_DONE, COUNTERSIGN_MAX_W - 20.0, f)
	var w := 0.0
	for row in fit.rows:
		w = maxf(w, _tw(str(row), fit.size, f))
	var lead: float = fit.size + 5.0
	var rect := Rect2(COUNTERSIGN_CX - (w + 20.0) / 2.0, COUNTERSIGN_TOP, w + 20.0, lead * fit.rows.size() + 10.0)
	return {"size": fit.size, "rows": fit.rows, "rect": rect, "lead": lead}

func _draw_countersign(c: CanvasItem) -> void:
	var lay := countersign_layout()
	var rect: Rect2 = lay.rect
	_plate(c, rect)
	var y: float = rect.position.y + 5.0 + lay.size
	for row in lay.rows:
		_ctext(c, str(row), rect.get_center().x, y, lay.size, INK, Ink.serif())
		y += lay.lead

## Fits `lines` into `width`: the largest size from `hi` down to `lo` at which every line fits
## whole, else `lo` with the long lines word-wrapped. Never cut. {size, rows}.
static func fit_rows(lines: Array, width: float, font: Font, hi := PLAQUE_MAX, lo := PLAQUE_MIN) -> Dictionary:
	for size in range(hi, lo - 1, -1):
		var ok := true
		for l in lines:
			if _tw(str(l), size, font) > width:
				ok = false
				break
		if ok:
			return {"size": size, "rows": lines.duplicate()}
	var rows := []
	for l in lines:
		rows.append_array(_wrap(str(l), width, lo, font))
	return {"size": lo, "rows": rows}

## Each shuttered lamp's faint glow, breathing on its own tremolo (still with Motion off).
func _draw_lamp_glow(c: CanvasItem, s := 0) -> void:
	# once the shutters have turned (P25) the eight are dead: their glass barely warms
	var dim := 1.0 if s == 0 else (0.35 if s == 1 else 0.15)
	for i in 8:
		var a := 0.17
		if motion:
			var f := 0.07 + 0.06 * i / 7.0
			a = 0.15 + 0.05 * sin(TAU * f * time + i * 0.9)
		var at := Vector2(LAMP_B_X0 + LAMP_B_STEP * i, LAMP_B_Y)
		c.draw_circle(at, 46.0, Color(AMBER_HI, a * 0.35 * dim))
		c.draw_circle(at, 34.0, Color(AMBER_HI, a * 0.6 * dim))

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
		if r.plate_mismatch(fid):
			# a card of its own kind that isn't hers: the plate stays lit and says so (no flash)
			c.draw_rect(plate, Color(AMBER_HI, 0.6))
			c.draw_rect(plate.grow(2.0), BRUISE, false, 3.0)
			_ctext(c, "DOES NOT CORRESPOND", plate.get_center().x, plate.position.y + 27, 18, INK, f)
			_ctext(c, "TO OBSERVER", plate.get_center().x, plate.position.y + 51, 18, INK, f)
			continue
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
	# the rack: seven slots over the painted wells, each card standing in its own
	c.draw_rect(Rect2(104, 652, 960, 218), FELT)
	for i in R12Sim.RACK_ORDER.size() + 1:
		var x := RACK_X0 + RACK_STEP * i - 4.0
		c.draw_rect(Rect2(x, 652, 4, 218), TIMBER)
		c.draw_line(Vector2(x, 652), Vector2(x, 870), INK, 1.5)
	for i in R12Sim.RACK_ORDER.size():
		var cid: String = R12Sim.RACK_ORDER[i]
		var at := Vector2(RACK_X0 + RACK_STEP * i, RACK_Y) + Vector2(6, 12)
		if r.held_card() == cid:
			# lifted out of its slot (Motion off: in place, ringed in brass); she reads it aloud
			if motion:
				c.draw_rect(Rect2(at + Vector2(6, 8 - LIFT), TAB), SHADOW)
				_tab(c, cid, at - Vector2(0, LIFT), false)
			else:
				_tab(c, cid, at, false)
				c.draw_rect(Rect2(at, TAB).grow(2.0), BRASS, false, 3.0)
		elif r.card_in_rack(cid):
			_tab(c, cid, at)
	# the switch, the ROUTE key, the strip
	_sprite(c, "switch_witness" if r.switch() == "witness" else "switch_copy", SWITCH_AT)
	_rtext(c, "WITNESS", Rect2(SWITCH_AT + Vector2(22, 22), Vector2(82, 22)), 16, INK, f)
	_rtext(c, "COPY", Rect2(SWITCH_AT + Vector2(196, 22), Vector2(82, 22)), 16, INK, f)
	_sprite(c, "route_key_turned" if done else "route_key", ROUTE_AT)
	_draw_strip(c)

## A card standing in its rack slot: its category large, then the start of its face.
func _tab(c: CanvasItem, cid: String, at: Vector2, shadow := true) -> void:
	var rect := Rect2(at, TAB)
	if shadow:
		c.draw_rect(Rect2(at + Vector2(4, 5), TAB), Color(SHADOW, 0.25))
	c.draw_rect(rect, ENAMEL)
	c.draw_rect(rect, INK, false, 2.0)
	var f := Ink.serif()
	var cat: String = r.card_header(cid).get_slice(" ", 0)
	_ctext(c, cat, rect.get_center().x, at.y + 26, 16, INK, f)
	c.draw_line(at + Vector2(8, 34), at + Vector2(TAB.x - 8, 34), Color(INK, 0.5), 1.0)
	# the start of its face at CARD_BODY px, wrapped; what doesn't fit ends in an ellipsis (the
	# whole face is on the card in its frame, in her voice when lifted, and in the notebook)
	var y := at.y + 58
	var rows := []
	for line in r.card_text(cid):
		rows.append_array(_wrap(str(line), TAB.x - 12, CARD_BODY, f))
	for k in rows.size():
		if y > at.y + TAB.y - 8:
			break
		var row: String = rows[k]
		if y + 22 > at.y + TAB.y - 8 and k < rows.size() - 1:
			row += "…"
		_ltext(c, row, at.x + 6, y, CARD_BODY, INK, f)
		y += 22.0

## A card at `at` (top-left), scale s: the painted card with its printed face.
func _card(c: CanvasItem, cid: String, at: Vector2, s := 1.0, mod := Color(1, 1, 1)) -> void:
	var t := _tex("card")
	if t:
		c.draw_texture_rect(t, Rect2(at, t.get_size() * s), false, mod)
	c.draw_set_transform(at, 0.0, Vector2(s, s))
	var f := Ink.serif()
	var col := Color(INK.r * mod.r, INK.g * mod.g, INK.b * mod.b)
	_ltext(c, r.card_header(cid).to_upper(), 16, 52, 14, col, f)
	c.draw_line(Vector2(16, 60), Vector2(284, 60), Color(col, 0.5), 1.0)
	# the face at CARD_BODY px, wrapped; the leading closes up (never under 19 px) to keep a long
	# MOVEMENT run on the card
	var lines := r.card_text(cid)
	var wrapped := []
	var n := 0
	for i in lines.size():
		var font: Font = Ink.hand() if cid == "trace" and i == lines.size() - 1 else f
		var rows := _wrap(str(lines[i]), 268, CARD_BODY, font)
		wrapped.append([font, rows])
		n += rows.size()
	var lead := clampf((188.0 - 84.0 - 2.0 * (lines.size() - 1)) / maxf(1.0, n - 1), 19.0, 22.0)
	var y := 84.0
	for w in wrapped:
		for wl in w[1]:
			_ltext(c, wl, 16, y, CARD_BODY, col, w[0])
			y += lead
		y += 2.0
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## The strip plaque in c_frames: wider than the painted slot, as tall as its rows, every line
## of the strip in full (fitted from PLAQUE_MAX to PLAQUE_MIN px, then wrapped; never cut).
const STRIP_PLAQUE_X := 1110.0
const STRIP_PLAQUE_W := 262.0

## {size, rows: [[line index, row text]], rect, lead} for the strip's full lines.
func strip_layout() -> Dictionary:
	var f := Ink.serif()
	var full: Array = strip_queue if not strip_queue.is_empty() else r.strip_lines()
	var fit := fit_rows(full, STRIP_PLAQUE_W - 16.0, f)
	var rows := []
	for i in full.size():
		for row in fit_rows([full[i]], STRIP_PLAQUE_W - 16.0, f, fit.size, fit.size).rows:
			rows.append([i, str(row)])
	var lead: float = fit.size + 6.0
	var rect := Rect2(STRIP_PLAQUE_X, STRIP_RECT.position.y - 6.0, STRIP_PLAQUE_W,
		maxf(STRIP_RECT.size.y + 12.0, lead * rows.size() + 14.0))
	return {"size": fit.size, "rows": rows, "rect": rect, "lead": lead, "full": full}

func _draw_strip(c: CanvasItem) -> void:
	var f := Ink.serif()
	var lay := strip_layout()
	if lay.rows.is_empty():
		return
	var rect: Rect2 = lay.rect
	c.draw_rect(rect, Color("ece3cb"))
	c.draw_rect(rect, INK, false, 1.5)
	# how much of each line has typed (all of it once printed, or with Motion off)
	var typed := []
	for i in lay.full.size():
		var s: String = lay.full[i]
		if strip_queue.is_empty():
			typed.append(s.length())
		elif i < strip_starts.size():
			typed.append(_typed_n(s, strip_starts[i]))
		else:
			typed.append(0)
	var used := {}
	var y: float = rect.position.y + 7.0 + lay.size
	for row in lay.rows:
		var i: int = row[0]
		var text: String = row[1]
		var left: int = typed[i] - int(used.get(i, 0))
		used[i] = int(used.get(i, 0)) + text.length() + 1
		if left > 0:
			_ltext(c, text.substr(0, mini(left, text.length())), rect.position.x + 8.0, y, lay.size, INK, f)
		y += lay.lead

## c_routing (P26): the two plates and their PREVIEW keys on c_routing_preview (no card slots,
## no tray, no CONFIRM). A preview runs on the plate's lamps, then in the window.
func _draw_c_routing(c: CanvasItem) -> void:
	_full(c, "c_routing")
	var f := Ink.serif()
	_draw_schematic(c, "sever", Rect2(110, 100, 540, 360), true, _plate_state("sever", ""))
	_draw_schematic(c, "continue", Rect2(798, 100, 540, 360), true, _plate_state("continue", ""))
	for route in R12Sim.ROUTES:
		var key := Rect2(260, 470, 240, 90) if route == "sever" else Rect2(948, 470, 240, 90)
		var lr := Rect2(key.position.x + 40, key.end.y - 4, 160, 22)
		_plate(c, lr)
		_rtext(c, "PREVIEW", lr, 14, INK, f)
		if r.previewed(route):
			# a small brass tick on the key's plate once she has watched it
			_square(c, Vector2(lr.end.x - 12, lr.get_center().y), 6.0, BRASS_HI)

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

## CONTINUE's wide page: the night field (end_b_wide_3). Its one lit window and its small flat
## glow are painted; nothing here moves.
func _draw_wide(c: CanvasItem) -> void:
	_full(c, "end_b_field")

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
	if game == null:
		return
	if game.cur_text == "":
		if cont_visible():
			caption_node.draw_rect(CAPTION_BAR, Color(0.03, 0.06, 0.08, 0.9))
		return
	var c := caption_node
	var f := Ink.serif()
	var s: String = game.cur_text
	var n := s.length() if not motion else mini(s.length(), int(game.line_t * GameView.TYPE_CPS))
	c.draw_rect(CAPTION_BAR, Color(0.03, 0.06, 0.08, 0.9))
	var lines := _wrap(s, CAPTION_W, 24, f)
	var y := 1040.0 - 15.0 * (lines.size() - 1)
	var left := n
	for line in lines:
		var m := mini(left, str(line).length())
		left = maxi(0, left - str(line).length() - 1)
		var w := _tw(line, 24, f)
		_ltext(c, str(line).substr(0, m), CAPTION_X - w / 2.0, y, 24, PAPER, f)
		y += 30.0
	if game.chain_active():
		_ltext(c, "▸", CONT_RECT.position.x - 30.0, 1040, 22, Color(PAPER, 0.55), f)

## 'Go on': the core's button (Ink.button: storm-navy face, sea-glass rim, paper type) at the
## subtitle bar's right end. Its own node fades it in (cont_alpha); nothing pulses.
func _draw_cont(c: CanvasItem) -> void:
	if not cont_visible():
		return
	Ink.button(c, CONT_RECT, "Go on ▸", false, 22)
