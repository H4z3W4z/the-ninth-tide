extends RoomView
## R10, the Records Vault: renderer. Presents R10Sim (game/rooms/R10/R10_sim.gd) and never
## mutates it. Everything timed here (the clamp, the cover, the last blank turning, the
## reflection, the folders shutting, the riffle, the strip printing, the deep-bay lamp and the
## divider tab) is presentation and is never saved.
##
## Layering:
##   `room` (world layer 0): view A (the shelves) or view B (the catalogue wall), their painted
##          overlays and every label; a child node adds the pendant's constant amber glow.
##   CanvasLayer 5 `close`: c_contact (P16), c_folders (P18), c_model (P23).
##
## Painted plates: assets/rooms/R10/*.png, and the later-stage art in assets/stages/R10/*.png (the
## catalogue chest with ring pulls and STAFF shut, the stripe running up out of it, the vault
## grade), both from tools/art/rooms/R10.py. They carry no
## text: every label, numeral, clock hand, tally and printed line is drawn here, so the clues stay
## exact.
## Owner rule: no darkening at any band. Dread is what is clearly seen being wrong.

const DIR := "res://assets/rooms/R10/%s.png"
const STAGE_DIR := "res://assets/stages/R10/%s.png"
## The overlays that live in assets/stages/R10/ (new stage art; the room's own plates stay put).
const STAGE_IDS := ["vault_grade", "cabinet_r3", "staff_seep_r3", "staff_seep_r3_1", "staff_seep_r3_2",
	"drawer_open_r3", "a_cabinet_r3", "r10_flood_b6", "r10_flood_b6_a", "r10_dusk_a", "r10_dusk_b",
	"r10_tide_b5_a", "r10_tide_b5_b", "r10_tide_b6_a", "r10_tide_b6_b"]
## The STAFF drawer is always drawn shut (cabinet_r3, ring pulls). Out of its seam a hard
## sea-glass stripe runs up to the ceiling, at aperture width 0, 1, 2 (each step wider).
const STAFF_SEEPS := ["staff_seep_r3", "staff_seep_r3_1", "staff_seep_r3_2"]
## Venn's drawer open, with its ring pull.
const DRAWER_OPEN := "drawer_open_r3"
## From band 5 the vault floods to a dead-level line at the office's tide height (R10.py TIDE_Y).
## Below it the shelves are their own reflection: the strip above, flipped, sea-glass tinted.
const FLOOD_BAND := 5
const FLOOD_Y := 512.0
const FLOOD_LINE := Color("5f8f86")
const REFLECT_X := Vector2(36, 516)        # the shelves' span (R10.py SHELF)
const REFLECT_BOTTOM := 830.0
const REFLECT_TINT := Color(0.74, 0.86, 0.83, 0.85)
const FLOOD_WASH := Color(0.37, 0.56, 0.53, 0.08)
## Where the line breaks (x0, x1): nowhere in view A; across the folder cabinet's spine plates in B.
const FLOOD_KEEP_A := Vector2(0, 0)
const FLOOD_KEEP_B := Vector2(820, 1180)
## From this band the back shelving is graded toward storm navy (vault_grade).
const GRADE_BAND := 6
## From band 5 the water's plate (R10.py r10_tide_b5_*, round p4): a hard sea-glass band from
## FLOOD_Y down to WATER_FOOT (40% of the wall's height), the card drawers under it swollen dark
## past their frames with their labels re-stroked, the STAFF card-holder hanging open (view B)
## and chair 6's sitter standing, back turned, in the portrait row (view A). From band 6 the same
## with the water below washed deeper (r10_tide_b6_*).
const FLOOD_PLATE_BAND := 5
const FLOOD_PLATES := {5: {"a": "r10_tide_b5_a", "b": "r10_tide_b5_b"}, 6: {"a": "r10_tide_b6_a", "b": "r10_tide_b6_b"}}
const WATER_FOOT := 558.0
## From band 4 the waterline: a 7 px storm-navy contour under a 2 px pale sea-glass highlight,
## and the wallpaper one flat storm layer deeper (r10_dusk_*: the wall only, never an object).
const WATERLINE_BAND := 4
const DUSK_BAND := 4
const DUSK_PLATES := {"a": "r10_dusk_a", "b": "r10_dusk_b"}
const CONTOUR_W := 7.0
const MENISCUS_W := 2.0
const MENISCUS_HI := Color("a9c8b8")

const PAPER := Color("ded4ba")
const PAPER_HI := Color("e8e1cf")
const INK := Color("172b36")
const STORM := Color("22384a")
const VIOLET := Color("746577")
const BRASS := Color("9c7e46")
const BRASS_HI := Color("c9a869")
const BRASS_LO := Color("745c32")
const EBONITE := Color("25313b")
const SEPIA := Color("a99f8b")          # the panels' photograph ground (R10.py SEPIA)
const GLASS := Color("bccbc3")          # the contact table's glass, pale sea-glass
const AMBER := Color("c39959")
const GRAPHITE := Color("2e3338")
const OCCLUDER := Color("0d1418")
const STAMP_CLOSED_COL := Color("22384a")
const STAMP_OPEN_COL := Color("3c5a5c")

## [id, rect, label]; first match wins, so small objects come first.
const HOTSPOTS := [
	["wall_clock", Rect2(934, 112, 150, 150), "Wall clock"],
	["photographs", Rect2(560, 320, 860, 160), "Photographs"],
	["index_cards", Rect2(540, 540, 230, 290), "Hanging file"],
	["contact_table", Rect2(800, 560, 400, 270), "Contact table"],
	["shelves", Rect2(36, 120, 480, 710), "Shelves"],
	["to_catalogue", Rect2(600, 850, 248, 64), "The catalogue wall"],
]
## View B, the catalogue wall (a base view, not a close-up).
const CATALOGUE_HOTSPOTS := [
	["staff_drawer", Rect2(420, 370, 220, 160), "STAFF drawer"],
	["tray", Rect2(420, 540, 220, 80), "Tray"],
	["correspondence_drawer", Rect2(100, 680, 240, 120), "Venn's drawer"],
	["wrapped_photo", Rect2(1220, 300, 180, 160), "Parcel"],
	["model", Rect2(820, 200, 340, 250), "Index model"],
	["folders", Rect2(800, 470, 380, 360), "Folder cabinet"],
	["to_shelves", Rect2(600, 850, 248, 64), "The shelves"],
]
const EXIT_RECTS := {
	"R07": Rect2(20, 922, 250, 64),
}
## View A: the way back to the laboratory is the vault door itself, so its tab sits on the leaf.
const DOOR_EXIT := Rect2(1214, 744, 206, 64)

## Close-up controls: [id, rect, hover label].
const CONTACT_CONTROLS := [
	["slot_1", Rect2(104, 190, 280, 360), "Slot 1"],
	["slot_2", Rect2(424, 190, 280, 360), "Slot 2"],
	["slot_3", Rect2(744, 190, 280, 360), "Slot 3"],
	["slot_4", Rect2(1064, 190, 280, 360), "Slot 4"],
	["loose_a", Rect2(230, 700, 200, 200), "Panel A"],
	["loose_b", Rect2(490, 700, 200, 200), "Panel B"],
	["loose_c", Rect2(750, 700, 200, 200), "Panel C"],
	["loose_d", Rect2(1010, 700, 200, 200), "Panel D"],
	["clip", Rect2(104, 556, 1240, 64), "Edge clamp"],
	["cover", Rect2(1344, 320, 84, 130), "Cover tab"],
]
const FOLDER_CONTROLS := [
	["lid_card", Rect2(380, 92, 690, 80), "Protocol card"],
	["fold_body", Rect2(110, 190, 360, 400), "BODY"],
	["fold_place", Rect2(544, 190, 360, 400), "PLACE"],
	["fold_name", Rect2(978, 190, 360, 400), "NAME"],
	["cmp_tray", Rect2(110, 640, 560, 160), "Comparison tray"],
	["day_up", Rect2(720, 626, 120, 64), "Day ▲"],
	["day_dn", Rect2(720, 796, 120, 64), "Day ▼"],
	["mon_up", Rect2(860, 626, 120, 64), "Month ▲"],
	["mon_dn", Rect2(860, 796, 120, 64), "Month ▼"],
	["year_up", Rect2(1000, 626, 150, 64), "Year ▲"],
	["year_dn", Rect2(1000, 796, 150, 64), "Year ▼"],
	["chair_up", Rect2(1088, 882, 64, 50), "Chair ▲"],
	["chair_dn", Rect2(1088, 934, 64, 50), "Chair ▼"],
	["compare", Rect2(1180, 626, 200, 110), "COMPARE"],
	["release", Rect2(1160, 760, 260, 150), "TRAINING RELEASE"],
]
const MODEL_CONTROLS := [
	["faceplate", Rect2(220, 96, 1010, 110), "Faceplate"],
	["strip", Rect2(220, 222, 1010, 180), "Strip"],
	["bridge", Rect2(1008, 440, 240, 70), "Bridge"],
	["shutter", Rect2(200, 430, 1050, 300), "Shutter"],
	["t_input", Rect2(220, 520, 200, 200), "Triangle terminal"],
	["t_copy", Rect2(624, 520, 200, 200), "Two-square terminal"],
	["t_witness", Rect2(1028, 520, 200, 200), "Circle terminal"],
	["lead", Rect2(220, 770, 260, 120), "Lead"],
	["test", Rect2(560, 770, 260, 120), "TEST AMENDMENT"],
	["reset", Rect2(860, 770, 180, 120), "RESET"],
	["stamp", Rect2(1080, 770, 170, 120), "Stamp"],
]

## One-shot levels (dB) and the sudden ones "Soften sudden sounds" turns down.
const SFX_DB := {
	"paper_settle": -6.0, "panel_pick": -6.0, "panel_place": -5.0, "edge_refuse": -4.0, "clip_snap": -2.0,
	"cover_slide": -4.0, "blank_turn": 0.0, "sheet_take": -6.0, "folder_file": -5.0, "folder_return": -5.0,
	"wheel_click": -8.0, "compare_key": -4.0, "compare_refuse": -4.0, "strip_print": -7.0, "index_close": -1.0,
	"tabs_riffle": -2.0, "release_lever": -4.0, "records_return": -5.0, "drawer_self": -5.0,
	"letters_take": -6.0, "staff_open": -3.0, "staff_settle": -2.0, "drawer_locked": -4.0, "card_flip": -6.0,
	"clock_tap": -5.0, "string_untie": -6.0, "paper_unwrap": -5.0, "lead_plug": -5.0, "lead_unplug": -6.0,
	"test_key": -4.0, "stamp_closed": -2.0, "stamp_open": -4.0, "reset_key": -5.0, "bridge_lift": -4.0,
	"staff_slam": -2.0,
}
const SFX_SOFT := ["clip_snap", "stamp_closed", "drawer_locked", "staff_slam"]

const LOOPS := ["r10_room", "r10_paper_far", "r10_paper_tick", "r10_sea_wall", "r10_aperture", "r10_model_hum"]
## The band-driven bed, dB per weather band 0..7 (OFF = silent). tools/audio/rooms/R10.py keeps a
## copy (STAGE_DB) and checks the mix survives a laptop speaker; the level sits within 3 dB of the
## laboratory's at the same band. Paper ticks from band 0; far paper from band 2 until band 7
## swaps it for the aperture's breath; the sea through the wall at band 4 only.
const OFF := -80.0
const STAGE_DB := {
	"r10_room": [-6.0, -6.0, -6.0, -6.0, -6.0, -6.0, -6.0, -5.0],
	"r10_paper_far": [OFF, OFF, -14.0, -14.0, -14.0, -14.0, -14.0, OFF],
	"r10_paper_tick": [-16.0, -16.0, -16.0, -16.0, -16.0, -16.0, -16.0, -16.0],
	"r10_sea_wall": [OFF, OFF, OFF, OFF, -12.0, OFF, OFF, OFF],
}
## The quiet reveals the room's loops duck under (6 dB).
const DUCK_IDS := ["blank_turn", "index_close"]
const LOOP_RATE := 0.11

## Ambient per weather band: held at full (owner rule: no darkening).
const TINT := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

# --- view A geometry ----------------------------------------------------------------------
const CLOCK_C := Vector2(1009, 187)
const MERCER_RECT := Rect2(572, 536, 168, 60)
const RECORDS_PLATE := Rect2(1257, 522, 120, 30)
const TURN_PLATE := Rect2(612, 861, 224, 42)
const RECESS := Rect2(250, 330, 90, 150)
const DEEP_LAMP := Vector2(296, 372)
const DEEP_PERIOD := 11.0
## The passer: in to mid-recess, a stop facing out, then on and out of sight.
const DEEP_IN := 0.6
const DEEP_STOP := 0.5
const DEEP_OUT := 0.6
const DEEP_PASS := DEEP_IN + DEEP_STOP + DEEP_OUT
const DIVIDER_PIVOT := Vector2(735, 606)
const DIVIDER_PERIOD := 7.0
const PENDANT_A := Vector2(770, 190)
const PENDANT_B := Vector2(700, 120)
## Where the wall meets the boards (R10.py FLOOR_Y): the flood wash stops here.
const FLOOR_TOP := 900.0

# --- view B geometry ----------------------------------------------------------------------
const STAFF_PLATE := Rect2(480, 392, 100, 28)
const SPINE_PLATES := [Rect2(830, 500, 100, 26), Rect2(950, 500, 100, 26), Rect2(1070, 500, 100, 26)]
const OPEN_PATCH := Rect2(1044, 346, 60, 24)
const OBSERVER_PLATE := Rect2(946, 406, 111, 20)
const DRAWER_SLIDE := 0.6
const DRAWER_SLIDE_PX := 40.0

# --- c_contact geometry -------------------------------------------------------------------
const SLOT_X := [104.0, 424.0, 744.0, 1064.0]
const SLOT_Y := 190.0
const PANEL := Vector2(280, 360)
const REST_X := [230.0, 490.0, 750.0, 1010.0]
const REST_Y := 700.0
const LOOSE_SCALE := 0.55
const LOOSE_CLOCK := 1.3
const CELL_X := [20.0, 85.0, 150.0, 215.0]
const CELL := Rect2(0, 318, 50, 24)
const PANEL_CLOCK := Vector2(56, 52)
const LETTER_PLATE := Rect2(212, 18, 48, 32)
const LAST_SEAT := Vector2(232, 160)
const CLAMP_X := 104.0
const CLAMP_Y := 564.0
const CLAMP_TIME := 0.25
const COVER_POS := Vector2(104, 320)
const COVER_TIME := 1.0
const TURN_TIME := 2.4
const REFL_TIME := 1.5
const REFL_AFTER_TURN := 6.2
const LIFT := 12.0
## The chair lamps on every panel (panel space): centres, radius. Lit: a solid amber dot;
## out: a navy ring. At the loose scale a dot is still at least 8 px across.
const LAMP_Y := 130.0
const LAMP_X0 := 28.0
const LAMP_DX := 32.0
const LAMP_R := 8.0
const LAMP_BED := Rect2(4, 125, 272, 24)
## The chair numbers under the lamps (full-size panels only): 1 to 8, left to right.
const LAMP_NUM_BED := Rect2(4, 149, 272, 18)
## Frame 16, the last blank on panel C (panel space), and its turned silhouette's feet.
const FRAME16 := Rect2(222, 132, 56, 100)
const TURNED_FEET := Vector2(253, 229)
## The glance at frame 16 once the cover has slid off.
const GLANCE_TIME := 2.5
## The reflection in the glass: an inset in the emptied lower tray.
const REFL_INSET := Rect2(510, 640, 160, 220)

# --- c_folders geometry -------------------------------------------------------------------
const POCKETS := [Rect2(110, 190, 360, 400), Rect2(544, 190, 360, 400), Rect2(978, 190, 360, 400)]
const REC_SPRITE := {"nora_frame": "c_rec_frame", "nora_spatial_strip": "c_rec_strip",
	"nora_register_card": "c_rec_card"}
const REC_LABEL := {"nora_frame": "N. BELL", "nora_spatial_strip": "BEARING: N. BELL",
	"nora_register_card": "BELL, N."}
const REC_SIZE := {"nora_frame": Vector2(220, 160), "nora_spatial_strip": Vector2(260, 90),
	"nora_register_card": Vector2(200, 130)}
const LID_CARD := Rect2(380, 96, 690, 80)
const RESULT_WIN := Rect2(120, 830, 540, 50)
const DATE_WIN := [Rect2(720, 694, 120, 96), Rect2(860, 694, 120, 96), Rect2(1000, 694, 150, 96)]
const DATE_HEADS := ["DAY", "MONTH", "YEAR"]
const COMPARE_POS := Vector2(1180, 626)
const LEVER_POS := Vector2(1230, 745)
const TRAINING_AT := Vector2(1214, 796)
const RELEASE_AT := Vector2(1366, 796)
const CMP_TRAY := Rect2(122, 652, 536, 136)
const RELEASE_SLIP := Rect2(1180, 916, 200, 66)
const INDEX_CARD := Rect2(690, 884, 476, 102)
## The CHAIR dial: a brass plate under the date dials (clear of the subtitle bar), with a plan of
## the 1927 session table (eight chairs round it, numbered as on the panels: chair 6 at the left,
## by the room's only door), the number window and two keys. After P18 the index card lies over
## it and its keys are gone.
const CHAIR_PLATE := Rect2(696, 878, 464, 108)
const CHAIR_WIN := Rect2(1012, 904, 66, 72)
const CHAIR_KEYS := {"chair_up": Vector2(1120, 907), "chair_dn": Vector2(1120, 959)}
const PLAN_ROOM := Rect2(752, 888, 248, 90)
const PLAN_C := Vector2(876, 933)
const PLAN_R := Vector2(96, 32)
## Chair k sits at angle (k - 1) * 45 deg - 45 deg (screen y down): 6 at the left, 8 at the top.
const PLAN_A0 := -45.0
## The door gap in the plan's left wall (y0 .. y1), level with chair 6.
const PLAN_DOOR := Vector2(918, 948)
## The records' slide from the tray into their folders when they file themselves (s).
const SELF_FILE_TIME := 0.7
const SELF_FILE_STAGGER := 0.25
const LEAF_STAGGER := 0.35
const LEAF_FOLD := 0.4
const BAR_DROP := 0.4
const BAR_X := 104.0
const BAR_Y := 360.0
const LEVER_PULL := 0.4
const BACK_TIME := 0.8
const RIFFLE_TIME := 0.25
const RIFFLE_STILL := 1.2

# --- c_model geometry ---------------------------------------------------------------------
const SOCK := {"input": Vector2(320, 620), "copy": Vector2(724, 620), "witness": Vector2(1128, 620)}
const SOCK_LABEL_Y := 690.0
const CUPS := [Vector2(286, 834), Vector2(414, 834)]
const BRIDGE_POS := Vector2(1008, 442)
const SHUTTER_POS := Vector2(200, 430)
const SHUTTER_PLATE := Rect2(565, 527, 439, 106)
const STRIP_IN := Rect2(232, 234, 986, 156)
const STAMP_POS := Vector2(1080, 770)
const TEST_POS := Vector2(560, 770)
const RESET_POS := Vector2(860, 770)
const PRINT_RATE := 18.0
## The inspection glass on the faceplate: it shows the STAFF drawer behind her, mirrored.
const MIRROR := Rect2(270, 112, 196, 78)
const MIRROR_SRC := Rect2(390, 300, 280, 112)
const AP_TIME := 1.0
## The faceplate carries only the terminals' marks (R10Sim.TERMINAL_GLYPHS), in socket order, and
## no word: two of them are the session log's margin marks (R04Sim.MARGIN_MARKS).
const FACEPLATE_PORTS := ["input", "copy", "witness"]
const FACEPLATE_PORT_X := [640.0, 848.0, 1056.0]
## The copy test: the frame photographs on the shelves wall go blank for one beat (s).
const BLANK_BEAT := 0.9
## Where each frame's photograph sits in view A (R10.py frame_photo: FRIEZE_X + 12, y 349, 60x86).
const FRIEZE_X0 := 572.0
const FRIEZE_DX := 94.0
const PHOTO_RECT := Rect2(12, 349, 60, 86)
const KEY_DOWN_TIME := 0.15
const PRESS_TIME := 0.15

## Notice holds: focus rects (view A unless noted).
const HOLD_TIME := 1.5
const HOLD_ZOOM := 0.06
const NOTICE_FOCUS := {
	"shelves": Rect2(36, 120, 480, 710),
	"ninth_photo": Rect2(1318, 330, 96, 128),
	"mercer_card": Rect2(556, 528, 200, 90),
	"shelves_more": Rect2(36, 120, 480, 710),
	"aperture_wide": Rect2(420, 40, 220, 490),
}
## Reveals that wait for their sound: fx id -> [sound, sounds of that id to let pass first].
const REVEAL_SOUND := {
	"last_turn": ["blank_turn", 0], "index_close": ["index_close", 0], "riffle": ["tabs_riffle", 0],
	"release": ["release_lever", 0], "records_back": ["records_return", 0], "stamp_closed": ["stamp_closed", 0],
	"stamp_open": ["stamp_open", 0], "print2": ["strip_print", 1], "bridge_free": ["bridge_lift", 0],
	"aperture_wider": ["staff_settle", 0], "staff_slam": ["staff_slam", 0],
}
## Seconds a reveal still waits once its sound is no longer queued (it never arrived).
const REVEAL_FALLBACK := 1.5

var r: R10Sim:
	get:
		return sim as R10Sim

var textures := {}
var narrow: SystemFont
var narrow_reg: SystemFont
var room: Node2D
var glow: Node2D
var close: Node2D
var shade: CanvasModulate
var mixer: LoopMixer

# presentation state (never saved)
var hold_t := 0.0
var hold_id := ""
var hold_rect := Rect2()
var zoom_k := 0.0
var waits := []                 # [{id, sound, skip, left}]: reveals waiting for their sound
var clamp_t := -1.0
var cover_t := -1.0             # -1 settled; >= 0 sliding off
var cover_hold := false         # the cover still on the plate (its reveal not begun)
var turn_t := -1.0              # seconds into the last blank's turn; -1 settled
var turn_hold := false          # waiting for blank_turn: the last blank still faces front
var refl_t := -1.0
var refl_hold := false
var seq_on := false             # P18's closing sequence, from COMPARE to the records' return
var ghost := {}                 # folder -> record: what the folders closed on (sim has returned them)
var idx_t := -1.0
var rel_t := -1.0
var back_t := -1.0
var riffle_t := -1.0
var riffle_owed := false
var drawer_hide := false
var drawer_t := -1.0
var print1_t := -1.0
var print2_t := -1.0
var print2_hold := false
var stamp_hold := false
var press_t := 0.0
var bridge_hold := false
var key_down := ""
var key_down_t := 0.0
var cmp_date := ""              # the date COMPARE last read (stamped in the tray)
var cmp_recs := []              # the records it read in the folders (their shadows in the tray)
var self_file_t := -1.0         # seconds into her records filing themselves; -1 settled
var ap_hold := false            # P23: the mirror still shows the STAFF opening as it was
var ap_t := -1.0                # seconds into its widening in the mirror; -1 settled
var cg_t := -1.0                # c_contact's own glance (frame 16); -1 none
var cg_rect := Rect2()
var bg_t := -1.0                # view B's two-part glance after P18: STAFF, then Venn's drawer
var slam_hold := false          # the copy test: STAFF still shows open until its slam is heard
var blank_t := -1.0             # seconds into the photographs' blank beat; -1 none
var blank_owed := false         # the beat came while she was not facing the shelves wall

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
		var path: String = (STAGE_DIR if id in STAGE_IDS else DIR) % id
		textures[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return textures[id]

func _build_nodes() -> void:
	room = Node2D.new()
	room.name = "Room"
	add_child(room)
	room.draw.connect(_draw_room)
	glow = Node2D.new()
	glow.name = "PendantGlow"
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	room.add_child(glow)
	glow.draw.connect(_draw_glow)
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

## View B shows behind its own close-ups (c_folders, c_model); view A behind c_contact.
func _side() -> String:
	return "b" if _view() in ["catalogue", "c_folders", "c_model"] else "a"

## Band 4: the stripes ripple once (the sea heard through the wall). Band 5 on: damp, the tide
## line and leaning stripes. Band 7 (view A): the breach and the card trail.
func plate_id() -> String:
	return "view_%s_t%d" % [_side(), tide_n()]

## The tide the vault's plates are painted for: VI to IX. Each one deepens the shelf bay and
## darkens the paper one step toward storm navy (R10.py view_a_t*, view_b_t*).
func tide_n() -> int:
	return clampi(r.tide(), 6, 9)

## The receding shelf bay's nested frames at this tide (painted into view_a_t*).
func bay_frames() -> int:
	return {6: 6, 7: 9}.get(tide_n(), 14)

## From tide VIII the innermost frame is a lit doorway with the ninth photograph's chair in it.
func bay_doorway() -> bool:
	return tide_n() >= 8

## The view A / view B overlays drawn now, in order (tests and captures read this).
func overlay_ids() -> Array:
	var out := []
	if _side() == "a":
		if _band() >= GRADE_BAND:
			out.append("vault_grade")
		out.append("a_cabinet_r3")
		out.append("a_sheet_assembled" if r.sheet_assembled() else "a_panels_loose")
		if r.photos_turned():
			out.append("a_photos_turned")
		if r.ninth_photo():
			out.append("a_ninth_photo")
		if r.mercer_card():
			out.append("a_mercer_card")
		return out
	out.append("cabinet_r3")
	var seep := seep_id()
	if seep != "":
		out.append(seep)
	if r.drawer_open() and not drawer_hide:
		out.append(DRAWER_OPEN)
	if r.shutter_open():
		out.append("b_terminals" if r.bridge_present() else "b_terminals_nobridge")
	if r.wrap() == 1:
		out.append("b_string_loose")
	elif r.wrap() == 2:
		out.append("b_photo_unwrapped")
	return out

## The STAFF drawer is drawn slammed shut: the sim says so (the copy closed the record) and its
## slam has been heard.
func staff_shut_drawn() -> bool:
	return r.staff_shut() and not slam_hold

## The stripe running up out of STAFF now ("" while the copy test has stopped it). The P18
## riffle jolts it one step wider for a moment.
func seep_id() -> String:
	if staff_shut_drawn():
		return ""
	var w := clampi(r.aperture_width(), 0, 2)
	if riffle_t >= 0.0:
		w = mini(w + 1, 2)
	return STAFF_SEEPS[w]

## The vault is flooded to FLOOD_Y (band 5 on).
func flooded() -> bool:
	return _band() >= FLOOD_BAND

## The photographs on the shelves wall are blank for their beat.
func photos_blank() -> bool:
	return blank_t >= 0.0

## The frame photographs' rects in view A (eight, and the ninth once it hangs).
func photo_rects() -> Array:
	var out := []
	for i in (9 if r.ninth_photo() else 8):
		out.append(Rect2(PHOTO_RECT.position + Vector2(FRIEZE_X0 + FRIEZE_DX * i, 0), PHOTO_RECT.size))
	return out

## The last blank's pose sprites and alphas: [[id, alpha], ...].
func last_blank() -> Array:
	if not r.last_turned() or turn_hold:
		return [["c_blank_t0", 1.0]]
	if turn_t < 0.0 or not motion:
		return [["c_blank_t2", 1.0]]
	var k := clampf(turn_t / TURN_TIME, 0.0, 1.0)
	if k < 0.5:
		return [["c_blank_t0", 1.0 - 2.0 * k], ["c_blank_t1", 2.0 * k]]
	return [["c_blank_t1", 2.0 - 2.0 * k], ["c_blank_t2", 2.0 * k - 1.0]]

func reflection_alpha() -> float:
	if not r.state.p16_complete or refl_hold:
		return 0.0
	if refl_t < 0.0 or not motion:
		return 1.0
	return clampf(refl_t / REFL_TIME, 0.0, 1.0)

## The cover's x offset off the plate, or -1 when it is gone.
func cover_dx() -> float:
	if not r.state.cover_off or cover_hold:
		return 0.0
	if cover_t < 0.0 or not motion:
		return -1.0
	var k := clampf(cover_t / COVER_TIME, 0.0, 1.0)
	return 1344.0 * (1.0 - pow(1.0 - k, 3.0))

## The film-edge numbers drawn on each placed panel: {slot: [cell, ...]}. Only where two
## neighbouring placed panels meet: cell 3 toward a filled slot on the right, cell 0 toward a
## filled slot on the left. Continuity reads when they run on; the break shows when not.
func edge_cells() -> Dictionary:
	var slots: Array = r.slot_letters()
	var out := {}
	for k in 4:
		if slots[k] == "":
			continue
		var cells := []
		if k > 0 and slots[k - 1] != "":
			cells.append(0)
		if k < 3 and slots[k + 1] != "":
			cells.append(3)
		out[k] = cells
	return out

## The film edge's date shows only once the cover has slid off.
func date_shown() -> bool:
	return r.state.cover_off and cover_dx() < 0.0

## Frame 16 on the table (panel C's last seat), or an empty rect when C is not placed.
func frame16_rect() -> Rect2:
	var k: int = r.slot_letters().find("C")
	if k < 0:
		return Rect2()
	return Rect2(Vector2(SLOT_X[k], SLOT_Y) + FRAME16.position, FRAME16.size)

## 0..1: the release lever's pull (0 up, 1 down).
func lever_k() -> float:
	if not r.state.p18_complete:
		return 0.0
	if seq_on:
		if rel_t < 0.0:
			return 0.0
		if motion:
			return clampf(rel_t / LEVER_PULL, 0.0, 1.0)
	return 1.0

## View B's glance after P18: "staff", then "drawer", or "".
func b_glance() -> String:
	if bg_t < 0.0:
		return ""
	return "staff" if bg_t < GLANCE_TIME / 2.0 else "drawer"

## 0..1: how far folder k's leaf is shut.
func leaf_closed(k: int) -> float:
	if not seq_on:
		return 0.0
	if rel_t >= 0.0:
		if not motion:
			return 0.0
		return 1.0 - clampf((rel_t - BAR_DROP - LEAF_STAGGER * k) / LEAF_FOLD, 0.0, 1.0)
	if idx_t >= 0.0:
		if not motion:
			return 1.0
		return clampf((idx_t - LEAF_STAGGER * k) / LEAF_FOLD, 0.0, 1.0)
	return 0.0

## The index bar's top y, or NAN when it is not across the folders.
func bar_y() -> float:
	if not seq_on:
		return NAN
	var top := -80.0
	if rel_t >= 0.0:
		if not motion or rel_t >= BAR_DROP:
			return NAN
		return lerpf(BAR_Y, top, smoothstep(0.0, 1.0, rel_t / BAR_DROP))
	if idx_t < 0.0:
		return NAN
	if not motion:
		return BAR_Y
	var t0 := LEAF_STAGGER * 2 + LEAF_FOLD
	if idx_t < t0:
		return NAN
	var k := clampf((idx_t - t0) / BAR_DROP, 0.0, 1.0)
	return lerpf(top, BAR_Y, k * k)

## The release lever is down once P18 is done and its pull has been seen.
func lever_down() -> bool:
	return lever_k() >= 1.0

## The model strip's lines as drawn now (typed reveals cut short).
func strip_lines() -> Array:
	var lines: Array = r.model_lines().duplicate()
	if lines.size() >= 2 and print2_hold:
		lines.resize(1)
	if lines.size() >= 1 and print1_t >= 0.0 and motion:
		lines[0] = str(lines[0]).substr(0, int(print1_t * PRINT_RATE))
	if lines.size() >= 2 and print2_t >= 0.0 and motion:
		lines[1] = str(lines[1]).substr(0, int(print2_t * PRINT_RATE))
	return lines

func stamp_word() -> String:
	if stamp_hold:
		return ""
	return str(r.state.stamp)

func bridge_drawn() -> bool:
	return r.bridge_present() or bridge_hold

# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------
func tick(dt: float) -> void:
	if hold_t > 0.0:
		hold_t = maxf(0.0, hold_t - dt)
	var zt := 1.0 if hold_t > 0.0 and motion and not r.is_closeup() else 0.0
	zoom_k = move_toward(zoom_k, zt, dt * 2.5)
	var s := 1.0 + HOLD_ZOOM * smoothstep(0.0, 1.0, zoom_k)
	room.scale = Vector2(s, s)
	room.position = hold_rect.get_center() * (1.0 - s)
	_tick_waits(dt)
	if clamp_t >= 0.0:
		clamp_t += dt
		if clamp_t > CLAMP_TIME:
			clamp_t = -1.0
	if cover_t >= 0.0:
		cover_t += dt
		if cover_t > COVER_TIME:
			cover_t = -1.0
			start_glance("frame_16", frame16_rect())
	if cg_t >= 0.0:
		cg_t += dt
		if cg_t > GLANCE_TIME or _view() != "c_contact":
			cg_t = -1.0
	if bg_t >= 0.0:
		bg_t += dt
		if b_glance() == "drawer" and drawer_hide:
			drawer_hide = false
			drawer_t = 0.0 if motion else -1.0
		if bg_t > GLANCE_TIME or _view() != "catalogue":
			bg_t = -1.0
			drawer_hide = false
	if turn_t >= 0.0:
		turn_t += dt
		if turn_t > TURN_TIME:
			turn_t = -1.0
	if refl_t >= 0.0:
		refl_t += dt
		if refl_t > REFL_TIME:
			refl_t = -1.0
	if seq_on:
		if idx_t >= 0.0:
			idx_t += dt
		if rel_t >= 0.0:
			rel_t += dt
		if back_t >= 0.0:
			back_t += dt
			if back_t > BACK_TIME or not motion:
				seq_on = false
				ghost = {}
				idx_t = -1.0
				rel_t = -1.0
				back_t = -1.0
	if self_file_t >= 0.0:
		self_file_t += dt
		if self_file_t > SELF_FILE_TIME + SELF_FILE_STAGGER * 2.0 or not motion:
			self_file_t = -1.0
	if riffle_t >= 0.0:
		riffle_t += dt
		if riffle_t > (RIFFLE_TIME if motion else RIFFLE_STILL):
			riffle_t = -1.0
	if ap_t >= 0.0:
		ap_t += dt
		if ap_t > AP_TIME:
			ap_t = -1.0
	if blank_owed and _view() == "room":
		blank_owed = false
		blank_t = 0.0
	if blank_t >= 0.0:
		blank_t += dt
		if blank_t > BLANK_BEAT or _view() != "room":
			blank_t = -1.0
	if drawer_t >= 0.0:
		drawer_t += dt
		if drawer_t > DRAWER_SLIDE:
			drawer_t = -1.0
	for pair in [["print1_t", 0], ["print2_t", 1]]:
		var v: float = get(pair[0])
		if v >= 0.0:
			v += dt
			var lines := r.model_lines()
			var n: int = str(lines[pair[1]]).length() if lines.size() > pair[1] else 0
			set(pair[0], -1.0 if v * PRINT_RATE > n + 1 else v)
	press_t = maxf(0.0, press_t - dt)
	key_down_t = maxf(0.0, key_down_t - dt)
	shade.color = Color(TINT[_band()], TINT[_band()], TINT[_band()])
	_tick_audio(dt)
	redraw()

func _tick_waits(dt: float) -> void:
	var keep := []
	var due := []
	for w in waits:
		if w.sound != "" and game and game.sfx_pending(w.sound):
			keep.append(w)
			continue
		w.left -= dt
		if w.left <= 0.0:
			due.append(w.id)
		else:
			keep.append(w)
	waits = keep
	for id in due:
		_begin(id)

func loop_targets() -> Dictionary:
	var b := _band()
	var v := _view()
	var out := {}
	for id in STAGE_DB:
		var db: float = STAGE_DB[id][b]
		out[id] = 0.0 if db <= OFF else db_to_linear(db)
	var ap := 0.0
	if r.staff_open():
		ap = [0.0, 0.25, 0.45][clampi(r.aperture_width(), 0, 2)]
		if v == "room":
			ap *= 0.5
	out["r10_aperture"] = ap
	var hum := 0.0
	if r.shutter_open():
		match v:
			"c_model":
				hum = 0.4
			"catalogue", "c_folders":
				hum = 0.25
			_:
				hum = 0.1
	out["r10_model_hum"] = hum
	if game != null and game.oneshot_playing(DUCK_IDS):
		for id in out:
			out[id] *= db_to_linear(-6.0)
	return out

func _tick_audio(dt: float) -> void:
	var rates := {}
	for id in LOOPS:
		rates[id] = LOOP_RATE
	mixer.tick(loop_targets(), rates, dt)

# ---------------------------------------------------------------------------
# hooks
# ---------------------------------------------------------------------------
func play_fx(id: String, e: Dictionary) -> void:
	if id.begins_with("notice_"):
		_start_hold(id.substr(7))
		return
	match id:
		"clamp":
			clamp_t = 0.0 if motion else -1.0
		"cover_off":
			cover_hold = false
			cover_t = 0.0 if motion else -1.0
			if not motion:
				start_glance("frame_16", frame16_rect())
			turn_hold = true
			refl_hold = true
		"self_file":
			self_file_t = 0.0 if motion else -1.0
		"index_close":
			seq_on = true
			ghost = {}
			for rec in R10Sim.RECORDS:
				ghost[R10Sim.RECORD_FOLDER[rec]] = rec
			idx_t = -1.0
			rel_t = -1.0
			back_t = -1.0
			drawer_hide = true
		"print":
			print1_t = 0.0 if motion else -1.0
			print2_hold = true
			ap_hold = true
		"print_closed":
			print1_t = 0.0 if motion else -1.0
		"stamp_closed", "stamp_open":
			stamp_hold = true
		"bridge_free":
			bridge_hold = true
		"aperture_wider":
			ap_hold = true
		"staff_slam":
			slam_hold = true
		"photos_blank":
			# one beat, when she next faces the shelves wall (now, if she does)
			blank_owed = true
	if REVEAL_SOUND.has(id):
		var s: Array = REVEAL_SOUND[id]
		if float(e.get("delay", 0.0)) <= 0.0 and s[1] == 0 and not (game and game.sfx_pending(s[0])):
			_begin(id)
		else:
			waits.append({"id": id, "sound": s[0], "skip": s[1], "left": REVEAL_FALLBACK})

func on_sfx(id: String) -> void:
	match id:
		"compare_key":
			_press("compare")
			cmp_date = r.date_text()
			cmp_recs = []
			for f in R10Sim.FOLDER_ORDER:
				var rec: String = r.state.filed[f]
				if rec != "":
					cmp_recs.append(rec)
			if r.state.p18_complete:
				cmp_recs = R10Sim.RECORDS.duplicate()
		"folder_file", "folder_return":
			cmp_date = ""
		"test_key":
			_press("test")
		"reset_key":
			_press("reset")
		"drawer_self":
			if drawer_hide and _view() == "catalogue":
				drawer_hide = false
				drawer_t = 0.0 if motion else -1.0
	for k in waits.size():
		var w: Dictionary = waits[k]
		if w.sound != id:
			continue
		if w.skip > 0:
			w.skip -= 1
			return
		waits.remove_at(k)
		_begin(w.id)
		return

func _press(k: String) -> void:
	key_down = k
	key_down_t = KEY_DOWN_TIME

## A reveal's moment has come: start it (Motion off: its still).
func _begin(id: String) -> void:
	match id:
		"last_turn":
			turn_hold = false
			turn_t = 0.0 if motion else -1.0
			waits.append({"id": "reflection", "sound": "", "skip": 0, "left": REFL_AFTER_TURN})
		"reflection":
			refl_hold = false
			refl_t = 0.0 if motion else -1.0
		"index_close":
			if seq_on:
				idx_t = 0.0
		"release":
			if seq_on:
				if idx_t < 0.0:
					idx_t = 99.0
				rel_t = 0.0
		"records_back":
			if seq_on:
				if rel_t < 0.0:
					rel_t = 99.0
				back_t = 0.0
		"riffle":
			if r.is_closeup():
				riffle_owed = true
			else:
				riffle_t = 0.0
		"stamp_closed", "stamp_open":
			stamp_hold = false
			press_t = PRESS_TIME if motion else 0.0
		"print2":
			print2_hold = false
			print2_t = 0.0 if motion else -1.0
		"bridge_free":
			bridge_hold = false
		"aperture_wider":
			ap_hold = false
			ap_t = 0.0 if motion else -1.0
		"staff_slam":
			slam_hold = false

func on_view_changed(_before: String) -> void:
	if _view() != "c_folders":
		cmp_date = ""
		cmp_recs = []
		self_file_t = -1.0
	if riffle_owed and _view() == "catalogue":
		riffle_owed = false
		riffle_t = 0.0

func _start_hold(n: String) -> void:
	var rect: Rect2 = NOTICE_FOCUS.get(n, Rect2())
	if rect.size == Vector2.ZERO:
		return
	hold_id = n
	hold_rect = rect
	hold_t = HOLD_TIME

func hold_active() -> bool:
	return hold_t > 0.0

## Frame 16 is bracketed on the contact table once the cover is off. After P18 the catalogue
## wall shows STAFF, then Venn's drawer sliding out on its own; the other rewards get the
## core's brackets.
func start_glance(target: String, rect: Rect2) -> bool:
	if target == "frame_16":
		if rect.size == Vector2.ZERO or _view() != "c_contact":
			return false
		cg_rect = rect
		cg_t = 0.0
		return true
	if target == "correspondence_drawer":
		if _view() == "catalogue":
			bg_t = 0.0
			return true
		drawer_hide = false
	return false

func exit_arrow(to: String) -> String:
	if to == "R07":
		return "right" if _side() == "a" else "left"
	return ""

func exit_rects() -> Dictionary:
	if _side() == "a":
		return {"R07": DOOR_EXIT}
	return EXIT_RECTS

func apply_instantly() -> void:
	reset_presentation()
	shade.color = Color.WHITE
	if mixer:
		mixer.snap(loop_targets())
	room.scale = Vector2.ONE
	room.position = Vector2.ZERO

func reset_presentation() -> void:
	hold_t = 0.0
	hold_id = ""
	zoom_k = 0.0
	waits = []
	clamp_t = -1.0
	cover_t = -1.0
	cover_hold = false
	turn_t = -1.0
	turn_hold = false
	refl_t = -1.0
	refl_hold = false
	seq_on = false
	ghost = {}
	idx_t = -1.0
	rel_t = -1.0
	back_t = -1.0
	riffle_t = -1.0
	riffle_owed = false
	drawer_hide = false
	drawer_t = -1.0
	print1_t = -1.0
	print2_t = -1.0
	print2_hold = false
	stamp_hold = false
	press_t = 0.0
	bridge_hold = false
	key_down = ""
	key_down_t = 0.0
	cmp_date = ""
	cmp_recs = []
	ap_hold = false
	ap_t = -1.0
	cg_t = -1.0
	cg_rect = Rect2()
	bg_t = -1.0
	slam_hold = false
	blank_t = -1.0
	blank_owed = false

func redraw() -> void:
	room.queue_redraw()
	glow.queue_redraw()
	close.queue_redraw()

func back_visible() -> bool:
	return r.is_closeup()

func esc_action() -> String:
	# Esc steps back from a close-up and from the catalogue wall; the menu opens only from view A.
	return "back" if r.is_closeup() or r.local_view == "catalogue" else "menu"

func exits_active() -> bool:
	return not r.is_closeup()

# ---------------------------------------------------------------------------
# input (pure hit-tests)
# ---------------------------------------------------------------------------
## The live controls of close-up `cid` as [id, rect, label], in hit order.
func closeup_controls(cid: String) -> Array:
	match cid:
		"c_contact":
			var out := []
			var loose := r.loose_letters()
			for h in CONTACT_CONTROLS:
				var id: String = h[0]
				if id.begins_with("loose_"):
					var x := id.substr(6).to_upper()
					if not (x in loose or r.held == x):
						continue
				out.append(h)
			return out
		"c_folders":
			if not r.state.p18_complete:
				return FOLDER_CONTROLS
			# after P18 the index card lies over the CHAIR dial
			return FOLDER_CONTROLS.filter(func(h): return not h[0].begins_with("chair_"))
		"c_model":
			var out := []
			for h in MODEL_CONTROLS:
				match h[0]:
					"bridge":
						if not (r.bridge_present() and r.shutter_open()):
							continue
					"shutter":
						if r.shutter_open():
							continue
				out.append(h)
			return out
	return []

func _controls() -> Array:
	match _view():
		"room":
			return HOTSPOTS
		"catalogue":
			return CATALOGUE_HOTSPOTS
	return closeup_controls(_view())

func consume_click(_p: Vector2) -> bool:
	if hold_t > 0.0:
		hold_t = 0.0
		return true
	return false

func action_at(p: Vector2) -> String:
	if hold_t > 0.0:
		return ""
	for h in _controls():
		if h[1].has_point(p):
			if h[0] == "folders" and r.game.selected_item != "":
				return folder_spine_at(p)
			return h[0]
	return ""

## With an item in hand, the folder cabinet on the catalogue wall answers by spine: its three
## columns (under the BODY, PLACE, NAME plates) are the three folders, so the item goes straight in.
func folder_spine_at(p: Vector2) -> String:
	var rect: Rect2 = hotspot_rect("folders")
	var k := clampi(int((p.x - rect.position.x) / (rect.size.x / 3.0)), 0, 2)
	return ["fold_body", "fold_place", "fold_name"][k]

func hover_at(p: Vector2) -> String:
	return action_at(p)

func label_for(id: String) -> String:
	for table in [HOTSPOTS, CATALOGUE_HOTSPOTS, CONTACT_CONTROLS, FOLDER_CONTROLS, MODEL_CONTROLS]:
		for h in table:
			if h[0] == id:
				return h[2]
	return ""

func hotspot_rect(id: String) -> Rect2:
	for table in [HOTSPOTS, CATALOGUE_HOTSPOTS]:
		for h in table:
			if h[0] == id:
				return h[1]
	return Rect2()

func dev_rects() -> Array:
	var out := []
	for h in HOTSPOTS + CATALOGUE_HOTSPOTS:
		out.append(h[1])
	if r.is_closeup():
		for h in closeup_controls(_view()):
			out.append(h[1])
	return out

# ---------------------------------------------------------------------------
# drawing helpers
# ---------------------------------------------------------------------------
func _full(c: CanvasItem, id: String, a := 1.0, off := Vector2.ZERO) -> void:
	var t := _tex(id)
	if t:
		c.draw_texture_rect(t, Rect2(off, SIZE), false, Color(1, 1, 1, a))

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
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial: String = word if line == "" else line + " " + word
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return out

## Wrapped lines centred on `cx` from the first baseline `y`; returns the next baseline.
func _cpara(c: CanvasItem, s: String, cx: float, y: float, size: int, col: Color, width: float,
		font: Font = null, lead := 1.25) -> float:
	var f: Font = font if font else Ink.serif()
	for line in _wrap(s, f, size, width):
		_ctext(c, line, cx, y, size, col, f)
		y += size * lead
	return y

## A dashed line: `pattern` is [on, off, ...] in px.
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
		_dashed(c, p[k], p[(k + 1) % 4], col, w, [12.0, 7.0])

## Corner brackets round `rect` in `col` over a paper underlay.
func _brackets(c: CanvasItem, rect: Rect2, col := INK, grow := 14.0) -> void:
	var g := rect.grow(grow)
	var arm := minf(40.0, minf(g.size.x, g.size.y) * 0.3)
	for corner in [[g.position, Vector2(1, 1)], [Vector2(g.end.x, g.position.y), Vector2(-1, 1)],
			[g.end, Vector2(-1, -1)], [Vector2(g.position.x, g.end.y), Vector2(1, -1)]]:
		var p: Vector2 = corner[0]
		var s: Vector2 = corner[1]
		for pass_ in [[col, 7.0], [PAPER_HI, 3.0]]:
			c.draw_polyline(PackedVector2Array([p + Vector2(0, s.y * arm), p, p + Vector2(s.x * arm, 0)]),
				pass_[0], pass_[1])

## A paper slip with an ink rim.
func _slip(c: CanvasItem, rect: Rect2, shadow := true) -> void:
	if shadow:
		c.draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color(0.05, 0.08, 0.1, 0.3))
	c.draw_rect(rect, PAPER_HI)
	c.draw_rect(rect, INK, false, 2.0)

## A clock hand from `c0` at `deg` (0 = twelve, clockwise), tapered.
func _hand(c: CanvasItem, c0: Vector2, deg: float, length: float, width: float, col: Color) -> void:
	var d := Vector2(sin(deg_to_rad(deg)), -cos(deg_to_rad(deg)))
	var n := d.orthogonal()
	var tail := c0 - d * length * 0.18
	c.draw_colored_polygon(PackedVector2Array([tail + n * width * 0.5, c0 + d * length, tail - n * width * 0.5]), col)

## Hour and minute hands for "HH:MM".
func _clock_hands(c: CanvasItem, c0: Vector2, hhmm: String, rh: float, rm: float, wh: float, wm: float,
		col: Color) -> void:
	var parts := hhmm.split(":")
	var h := int(parts[0]) % 12
	var m := int(parts[1])
	_hand(c, c0, (h + m / 60.0) * 30.0, rh, wh, col)
	_hand(c, c0, m * 6.0, rm, wm, col)
	c.draw_circle(c0, wh * 0.45, col)

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
	_full(c, plate_id())
	_draw_dusk(c, "a")
	var ov := overlay_ids()
	for id in ov:
		if id != "a_mercer_card":
			_full(c, id)
	if flooded():
		_draw_reflection_a(c, ov)
	_draw_flood_plate(c, "a")
	# the wall clock: stopped at 22:00
	_clock_hands(c, CLOCK_C, "22:00", 30.0, 46.0, 9.0, 6.0, INK)
	c.draw_circle(CLOCK_C, 4.0, BRASS)
	# the deep-bay lamp and, from band 5, someone passing it
	_draw_deep_lamp(c)
	# the empty divider tab after TULL (the one thing in the vault that moves)
	_draw_divider_tab(c)
	if "a_mercer_card" in ov:
		_full(c, "a_mercer_card")
		_rtext(c, "MERCER, A.", MERCER_RECT, 26, INK, narrow)
	if photos_blank():
		# the copy closed a record: for one beat every photograph is only its paper
		for pr in photo_rects():
			c.draw_rect(pr, PAPER_HI)
			c.draw_rect(pr, Color(INK, 0.6), false, 1.4)
	if waterline():
		_draw_flood_line(c, FLOOD_KEEP_A)
	# the vault door's inner plate
	c.draw_rect(RECORDS_PLATE, Color("d4cab0"))
	c.draw_rect(RECORDS_PLATE, INK, false, 2.0)
	_rtext(c, "RECORDS", RECORDS_PLATE, 20, INK, narrow)
	_rtext(c, "The catalogue wall ▸", TURN_PLATE, 22, INK, narrow)

## Below the flood line the shelves are not lit: they are the strip above, flipped about
## FLOOD_Y, tinted sea-glass at 0.85 (with the vault grade, and the deep lamp and whoever passes
## it, mirrored the same way). Only the shelves' span: everything else keeps its own face.
func reflection_rect() -> Rect2:
	return Rect2(REFLECT_X.x, FLOOD_Y, REFLECT_X.y - REFLECT_X.x, REFLECT_BOTTOM - FLOOD_Y)

func _draw_reflection_a(c: CanvasItem, ov: Array) -> void:
	var dst := reflection_rect()
	var h := dst.size.y
	var src := Rect2(dst.position.x, FLOOD_Y - h, dst.size.x, h)
	c.draw_rect(dst, PAPER)
	c.draw_set_transform(Vector2(0, 2.0 * FLOOD_Y), 0.0, Vector2(1, -1))
	for id in [plate_id()] + (["vault_grade"] if "vault_grade" in ov else []):
		var t := _tex(id)
		if t:
			c.draw_texture_rect_region(t, src, src, REFLECT_TINT)
	var f := deep_figure()
	var lamp_a := REFLECT_TINT.a
	c.draw_circle(DEEP_LAMP, 3.0, Color(AMBER.lerp(FLOOD_LINE, 0.4), lamp_a))
	if not f.is_empty():
		_draw_figure(c, f.x, f.facing_out)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## The waterline is drawn from band 4 (the sea heard through the wall marks where it will stand);
## the water itself, from band 5.
func waterline() -> bool:
	return _band() >= WATERLINE_BAND

## The waterline: hard, dead level, the width of the wall except across `keep` (x0, x1: a label
## it must not cross); from band 5 a faint sea-glass wash below it, to the boards.
func _draw_flood_line(c: CanvasItem, keep: Vector2) -> void:
	if flooded():
		c.draw_rect(Rect2(0, FLOOD_Y, 1448, FLOOR_TOP - FLOOD_Y), FLOOD_WASH)
	for span in [Vector2(0, keep.x), Vector2(keep.y, 1448)]:
		if span.y <= span.x:
			continue
		# a 2 px pale sea-glass highlight on a 7 px storm-navy contour, the water's top edge
		c.draw_rect(Rect2(span.x, FLOOD_Y, span.y - span.x, CONTOUR_W), STORM)
		c.draw_rect(Rect2(span.x, FLOOD_Y - MENISCUS_W, span.y - span.x, MENISCUS_W), MENISCUS_HI)

## The wall's dusk overlay for `side`, or "" below DUSK_BAND.
func dusk_id(side: String) -> String:
	return DUSK_PLATES[side] if _band() >= DUSK_BAND else ""

func _draw_dusk(c: CanvasItem, side: String) -> void:
	var id := dusk_id(side)
	if id != "":
		_full(c, id)

## The water's plate for view `side` ("a" or "b"), or "" below FLOOD_PLATE_BAND.
func flood_plate_id(side: String) -> String:
	var b := r.band()
	if b < FLOOD_PLATE_BAND:
		return ""
	return FLOOD_PLATES[mini(b, 6)][side]

## The water standing in the room, under the waterline and every label the view writes.
func _draw_flood_plate(c: CanvasItem, side: String) -> void:
	var id := flood_plate_id(side)
	if id != "":
		_full(c, id)

func _draw_deep_lamp(c: CanvasItem) -> void:
	c.draw_circle(DEEP_LAMP, 5.0, Color(AMBER, 0.35))
	c.draw_circle(DEEP_LAMP, 3.0, AMBER)
	var f := deep_figure()
	if f.is_empty():
		return
	_draw_figure(c, f.x, f.facing_out)

## Where the passer is now: {x, facing_out}, or {} when the recess is empty. Motion off: it
## stands stopped at mid-recess, facing out, the way it pauses on its pass.
func deep_figure() -> Dictionary:
	if not r.deep_lamp_passing():
		return {}
	var mid := RECESS.get_center().x
	if not motion:
		return {"x": mid, "facing_out": true}
	var ph := fmod(time, DEEP_PERIOD)
	if ph >= DEEP_PASS:
		return {}
	var x0 := RECESS.position.x - 24.0
	var x1 := RECESS.end.x + 24.0
	if ph < DEEP_IN:
		return {"x": lerpf(x0, mid, smoothstep(0.0, 1.0, ph / DEEP_IN) * 0.5 + ph / DEEP_IN * 0.5), "facing_out": false}
	if ph < DEEP_IN + DEEP_STOP:
		return {"x": mid, "facing_out": true}
	var k := (ph - DEEP_IN - DEEP_STOP) / DEEP_OUT
	return {"x": lerpf(mid, x1, k * k * 0.5 + k * 0.5), "facing_out": false}

## One joined flat silhouette, feet on the recess floor, about 70% of its height, clipped to
## the recess. Walking: a profile with a slight forward hunch. Stopped: facing out, narrow
## sloped shoulders.
func _draw_figure(c: CanvasItem, x: float, facing_out: bool) -> void:
	var feet := Vector2(x, RECESS.end.y)
	var body: PackedVector2Array
	var head: Vector2
	if facing_out:
		body = PackedVector2Array([Vector2(-14, 0), Vector2(-15, -46), Vector2(-17, -63), Vector2(-14, -70),
			Vector2(-7, -75), Vector2(-5, -82), Vector2(5, -82), Vector2(7, -75), Vector2(14, -70),
			Vector2(17, -63), Vector2(15, -46), Vector2(14, 0)])
		head = Vector2(0, -91)
	else:
		body = PackedVector2Array([Vector2(-12, 0), Vector2(-13, -44), Vector2(-15, -62), Vector2(-10, -72),
			Vector2(0, -78), Vector2(5, -84), Vector2(12, -82), Vector2(13, -74), Vector2(14, -64),
			Vector2(12, -46), Vector2(10, 0)])
		head = Vector2(7, -89)
	var rect := PackedVector2Array([RECESS.position, Vector2(RECESS.end.x, RECESS.position.y), RECESS.end,
		Vector2(RECESS.position.x, RECESS.end.y)])
	var shapes := [body, Ink.ellipse(head, 11.0, 11.5, 20)]
	for shape in shapes:
		var moved := PackedVector2Array()
		for q in shape:
			moved.append(feet + q)
		for part in Geometry2D.intersect_polygons(moved, rect):
			c.draw_colored_polygon(part, OCCLUDER)

func _draw_divider_tab(c: CanvasItem) -> void:
	var deg := 2.0
	if motion:
		deg = 2.0 * sin(time * TAU / DIVIDER_PERIOD)
	c.draw_set_transform(DIVIDER_PIVOT, deg_to_rad(deg), Vector2.ONE)
	c.draw_rect(Rect2(-7, -40, 14, 40), BRASS)
	c.draw_rect(Rect2(-7, -40, 14, 40), INK, false, 1.6)
	var tab := PackedVector2Array([Vector2(-7, -40), Vector2(-7, -56), Vector2(-3, -60), Vector2(17, -60),
		Vector2(21, -56), Vector2(21, -40)])
	c.draw_colored_polygon(tab, PAPER_HI)
	tab.append(tab[0])
	c.draw_polyline(tab, INK, 1.6)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_view_b(c: CanvasItem) -> void:
	_full(c, plate_id())
	_draw_dusk(c, "b")
	for id in overlay_ids():
		if id == "b_drawer_open" and drawer_t >= 0.0:
			var k := smoothstep(0.0, 1.0, drawer_t / DRAWER_SLIDE)
			_full(c, id, k, Vector2(0, -DRAWER_SLIDE_PX * (1.0 - k)))
		else:
			_full(c, id)
		if id == "cabinet_r3":
			# the water stands over the chest (its drawers swell under it), under Venn's open
			# drawer, the stripe and everything the view writes
			_draw_flood_plate(c, "b")
	if waterline():
		# under the labels, and broken where the folder cabinet's spine plates stand (R10.py
		# paints its tide line round them too)
		_draw_flood_line(c, FLOOD_KEEP_B)
	c.draw_rect(STAFF_PLATE, Color("e3dccb"))
	c.draw_rect(STAFF_PLATE, INK, false, 2.0)
	# the label is in Ada's own hand
	_rtext(c, "STAFF", STAFF_PLATE, 22, GRAPHITE, Ink.hand())
	for k in 3:
		_rtext(c, R10Sim.FOLDER_ORDER[k], SPINE_PLATES[k], 18, INK, narrow)
	if r.state.p23_complete:
		_rtext(c, "OPEN", OPEN_PATCH, 15, STAMP_OPEN_COL, narrow)
	if not r.shutter_open():
		_rtext(c, "OBSERVER", OBSERVER_PLATE, 15, INK, narrow)
	_rtext(c, "◂ The shelves", TURN_PLATE, 22, INK, narrow)
	match b_glance():
		"staff":
			_brackets(c, GameView.glance_rect_of(R10Sim.GLANCE_STAFF))
		"drawer":
			_brackets(c, GameView.glance_rect_of(R10Sim.GLANCE_DRAWER))

## The pendant's constant amber glow (additive, on the glow node).
func _draw_glow() -> void:
	if r.is_closeup():
		return
	var at := PENDANT_B if _side() == "b" else PENDANT_A
	for k in 6:
		var s := 1.0 - k * 0.15
		var pts := Ink.ellipse(at + Vector2(0, 10), 120.0 * s, 70.0 * s, 40)
		glow.draw_colored_polygon(pts, Color(AMBER.r, AMBER.g * 0.85, AMBER.b * 0.6, 0.035))

# ---------------------------------------------------------------------------
# drawing: close-ups (layer 5)
# ---------------------------------------------------------------------------
func _draw_close() -> void:
	match _view():
		"c_contact":
			_draw_contact(close)
		"c_folders":
			_draw_folders(close)
		"c_model":
			_draw_model(close)

# --- c_contact ----------------------------------------------------------------------------
## Panel `x` with its top-left at `pos`, scaled `s`: the sprite, its letter, the chair lamps,
## clock hands, the film-edge numbers in `cells` (none on the felt) and, for C, the last blank.
func _draw_panel(c: CanvasItem, x: String, pos: Vector2, s: float, cells: Array = []) -> void:
	c.draw_set_transform(pos, 0.0, Vector2(s, s))
	_sprite(c, "c_panel_" + x.to_lower(), Vector2.ZERO)
	_draw_lamps(c, x, s >= 1.0)
	if x == "C":
		for pa in last_blank():
			if pa[0] == "c_blank_t2":
				_draw_turned(c, pa[1])
			else:
				_sprite(c, pa[0], LAST_SEAT, pa[1])
	if s < 1.0:
		# on the felt the panels are small: their clocks are drawn a third larger to stay legible
		var k := LOOSE_CLOCK
		c.draw_circle(PANEL_CLOCK, 32.0 * k, Color("e3dccb"))
		c.draw_arc(PANEL_CLOCK, 32.0 * k, 0.0, TAU, 40, INK, 3.0)
		for t in 12:
			var d := Vector2(sin(t * TAU / 12.0), -cos(t * TAU / 12.0))
			c.draw_line(PANEL_CLOCK + d * 25.0 * k, PANEL_CLOCK + d * 30.0 * k, INK, 3.0 if t % 3 == 0 else 1.6)
		_clock_hands(c, PANEL_CLOCK, R10Sim.panel_clock(x), 13.0 * k, 21.0 * k, 4.0 * k, 3.0 * k, INK)
	else:
		_clock_hands(c, PANEL_CLOCK, R10Sim.panel_clock(x), 13.0, 21.0, 4.0, 3.0, INK)
	_rtext(c, x, LETTER_PLATE, 28, INK, narrow)
	var nums := R10Sim.edge_numbers(x)
	for k in cells:
		_rtext(c, str(nums[k]), Rect2(CELL_X[k], CELL.position.y, CELL.size.x, CELL.size.y), 22, INK, narrow)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## The eight chair lamps along a panel's top rail, in panel space, countable by eye: the
## painted lamps are covered by a strip of the photograph's ground, then each lamp is a solid
## amber dot (lit) or a navy ring (out), over its own chair (R10Sim.lamp_on). Full-size panels
## also number the chairs 1 to 8 under their lamps, as the folders' CHAIR dial does.
func _draw_lamps(c: CanvasItem, x: String, numbered: bool) -> void:
	c.draw_rect(LAMP_BED, SEPIA)
	if numbered:
		c.draw_rect(LAMP_NUM_BED, SEPIA)
	for k in 8:
		var at := Vector2(LAMP_X0 + LAMP_DX * k, LAMP_Y)
		if numbered:
			_ctext(c, str(k + 1), at.x, LAMP_NUM_BED.end.y - 2, 15, INK, narrow)
		if R10Sim.lamp_on(x, k + 1):
			c.draw_circle(at, LAMP_R + 1.4, INK)
			c.draw_circle(at, LAMP_R, AMBER)
			c.draw_circle(at + Vector2(-2.5, -2.5), 2.4, PAPER_HI)
		else:
			c.draw_arc(at, LAMP_R - 1.2, 0.0, TAU, 28, INK, 2.8)

## Frame 16 turned: one stark navy silhouette about 90 px tall, its back to us (no face, a
## centre seam down the coat, the collar's notch), taller than the blanks either side of it.
func _draw_turned(c: CanvasItem, a: float) -> void:
	var f := TURNED_FEET
	var col := Color(OCCLUDER, a)
	var body := PackedVector2Array([f + Vector2(-25, 0), f + Vector2(-24, -30), f + Vector2(-21, -46),
		f + Vector2(-12, -54), f + Vector2(-6, -57), f + Vector2(6, -57), f + Vector2(12, -54),
		f + Vector2(21, -46), f + Vector2(24, -30), f + Vector2(25, 0)])
	c.draw_colored_polygon(body, col)
	c.draw_rect(Rect2(f + Vector2(-7, -64), Vector2(14, 10)), col)
	c.draw_colored_polygon(Ink.ellipse(f + Vector2(0, -75), 14.0, 16.0, 28), col)
	var seam := Color(STORM, a)
	c.draw_line(f + Vector2(0, -50), f + Vector2(0, -2), seam, 1.6)
	c.draw_polyline(PackedVector2Array([f + Vector2(-9, -55), f + Vector2(0, -48), f + Vector2(9, -55)]), seam, 1.6)

func _draw_contact(c: CanvasItem) -> void:
	var st: Dictionary = r.state
	_full(c, "c_contact")
	for k in 4:
		_ctext(c, str(k + 1), SLOT_X[k] + PANEL.x / 2.0, 171, 24, INK, narrow)
	var slots: Array = r.slot_letters()
	var cells := edge_cells()
	for k in 4:
		var x: String = slots[k]
		if x == "":
			continue
		_draw_panel(c, x, Vector2(SLOT_X[k], SLOT_Y), 1.0, cells.get(k, []))
		if x == "C" and turn_t >= 0.0 and motion:
			# a paper rim pulses on panel C's frame while its last blank turns
			var a := 0.5 - 0.5 * cos(turn_t / TURN_TIME * TAU * 2.0)
			c.draw_rect(Rect2(SLOT_X[k] - 3, SLOT_Y - 3, PANEL.x + 6, PANEL.y + 6), Color(PAPER_HI, a), false, 3.0)
	# the edge break: a violet dashed bracket and an ink cross over the pair that doesn't run on
	if r.edge_break >= 0 and r.edge_break < 3:
		var k := r.edge_break
		var a: float = SLOT_X[k] + CELL_X[3] - 6
		var b: float = SLOT_X[k + 1] + CELL_X[0] + CELL.size.x + 6
		var br := Rect2(a, SLOT_Y + CELL.position.y - 8, b - a, CELL.size.y + 16)
		_dashed_rect(c, br.grow(2), PAPER_HI, 7.0)
		_dashed_rect(c, br, VIOLET, 4.0)
		var xc := Vector2(SLOT_X[k] + PANEL.x + 20, br.get_center().y)
		for pass_ in [[PAPER_HI, 8.0], [INK, 4.0]]:
			c.draw_line(xc + Vector2(-11, -11), xc + Vector2(11, 11), pass_[0], pass_[1])
			c.draw_line(xc + Vector2(11, -11), xc + Vector2(-11, 11), pass_[0], pass_[1])
	# the clamp
	if st.clipped:
		var y := CLAMP_Y
		if clamp_t >= 0.0:
			y = lerpf(CLAMP_Y - 70.0, CLAMP_Y, smoothstep(0.0, 1.0, clamp_t / CLAMP_TIME))
		_sprite(c, "c_clamp", Vector2(CLAMP_X, y))
	# the film edge's date and its pencilled note, once the cover has slid off
	if date_shown():
		var date_slip := Rect2(1150, 572, 108, 32)
		_slip(c, date_slip, false)
		_rtext(c, "18 OCT 1927", date_slip, 20, INK, narrow)
		var note := Rect2(194, 574, 104, 30)
		_slip(c, note, false)
		_rtext(c, "Sync: bell.", note, 18, GRAPHITE, Ink.hand())
		var mark := Rect2(310, 574, 214, 30)
		_slip(c, mark, false)
		_rtext(c, "2 frames after the bell", mark, 18, GRAPHITE, Ink.hand())
	# the registration cover
	var dx := cover_dx()
	if dx >= 0.0:
		var at := COVER_POS + Vector2(dx, 0)
		_sprite(c, "c_cover", at)
		_ctext(c, "REGISTRATION COVER: DO NOT LIFT BEFORE CLAMPING", at.x + 620, at.y + 74, 22, PAPER_HI, narrow)
	# the loose panels on the felt, and the one in hand lifted
	for x in R10Sim.PANELS:
		var held: bool = r.held == x
		if not (x in r.loose_letters() or held):
			continue
		var i := R10Sim.PANELS.find(x)
		var w := PANEL.x * LOOSE_SCALE
		var h := PANEL.y * LOOSE_SCALE
		var pos := Vector2(REST_X[i] + (200.0 - w) / 2.0, REST_Y + (200.0 - h) / 2.0)
		if held:
			pos.y -= LIFT
			c.draw_rect(Rect2(pos + Vector2(8, 14), Vector2(w, h)), Color(STORM, 0.55))
		_draw_panel(c, x, pos, LOOSE_SCALE)
		# a legible letter tag at the panel's corner
		var tag := Rect2(pos.x + w - 30, pos.y - 6, 36, 32)
		_slip(c, tag, false)
		_rtext(c, x, tag, 24, INK, narrow)
		if held:
			_brackets(c, Rect2(pos, Vector2(w, h)), BRASS, 8.0)
	var ra := reflection_alpha()
	if ra > 0.0:
		_draw_reflection(c, ra)
	if cg_t >= 0.0:
		_brackets(c, cg_rect, INK, 10.0)

## The reflection in the glass, in the emptied lower tray: eight empty chairs in a row in flat
## ink, and one standing figure outside the row, with no head detail. Fixed geometry.
func _draw_reflection(c: CanvasItem, a: float) -> void:
	var g := REFL_INSET
	c.draw_rect(Rect2(g.position + Vector2(4, 6), g.size), Color(0.05, 0.08, 0.1, 0.3 * a))
	c.draw_rect(g, Color(GLASS, a))
	var ink := Color(INK, a)
	var floor_y := g.end.y - 22.0
	c.draw_line(Vector2(g.position.x + 6, floor_y), Vector2(g.end.x - 6, floor_y), Color(STORM, 0.5 * a), 2.0)
	for k in 8:
		_mini_chair(c, g.position.x + 13.0 + 14.5 * k, floor_y, ink)
	# the standing figure, past the end of the row: taller than the chairs by more than twice
	var fx := g.end.x - 18.0
	var body := PackedVector2Array([Vector2(fx - 9, floor_y), Vector2(fx - 11, floor_y - 52),
		Vector2(fx - 13, floor_y - 92), Vector2(fx - 8, floor_y - 100), Vector2(fx + 8, floor_y - 100),
		Vector2(fx + 13, floor_y - 92), Vector2(fx + 11, floor_y - 52), Vector2(fx + 9, floor_y)])
	c.draw_colored_polygon(body, ink)
	c.draw_rect(Rect2(fx - 3.5, floor_y - 106, 7, 8), ink)
	c.draw_colored_polygon(Ink.ellipse(Vector2(fx, floor_y - 114), 8.0, 10.0, 20), ink)
	# the glass: one diagonal gleam and an ink rim
	var p0 := g.position
	c.draw_colored_polygon(PackedVector2Array([p0 + Vector2(96, 0), p0 + Vector2(122, 0), p0 + Vector2(38, 120),
		p0 + Vector2(12, 120)]), Color(PAPER_HI, 0.22 * a))
	c.draw_rect(g, Color(BRASS_LO, a), false, 5.0)
	c.draw_rect(g.grow(-3), ink, false, 1.6)

## One empty chair, front view, flat: back posts and rail, seat, two legs, 12 px wide.
func _mini_chair(c: CanvasItem, cx: float, floor_y: float, col: Color) -> void:
	var seat := floor_y - 20.0
	c.draw_rect(Rect2(cx - 6, seat - 24, 2.4, 24), col)
	c.draw_rect(Rect2(cx + 3.6, seat - 24, 2.4, 24), col)
	c.draw_rect(Rect2(cx - 6, seat - 24, 12, 4), col)
	c.draw_rect(Rect2(cx - 7, seat, 14, 3.2), col)
	c.draw_rect(Rect2(cx - 6.5, seat + 3, 2.4, 17), col)
	c.draw_rect(Rect2(cx + 4.1, seat + 3, 2.4, 17), col)

# --- c_folders ----------------------------------------------------------------------------
func _rec_at(c: CanvasItem, rec: String, pos: Vector2, s := 1.0, a := 1.0) -> void:
	c.draw_set_transform(pos, 0.0, Vector2(s, s))
	_sprite(c, REC_SPRITE[rec], Vector2.ZERO, a)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	var size: Vector2 = REC_SIZE[rec] * s
	var fs := 20 if s >= 0.9 else 15
	_ctext(c, REC_LABEL[rec], pos.x + size.x / 2.0, pos.y + size.y + fs + 4, fs, Color(INK, a), narrow)

func _draw_folders(c: CanvasItem) -> void:
	var st: Dictionary = r.state
	_full(c, "c_folders")
	_cpara(c, "A subject is complete when BODY, PLACE and NAME correspond in one chair on one session date. S.R.",
		LID_CARD.get_center().x, LID_CARD.position.y + 34, 22, INK, LID_CARD.size.x - 40)
	for k in 3:
		var pk: Rect2 = POCKETS[k]
		var f: String = R10Sim.FOLDER_ORDER[k]
		_rtext(c, f, Rect2(pk.position.x + 90, pk.position.y + 10, pk.size.x - 180, 26), 20, INK, narrow)
		var rec: String = st.filed[f]
		var ga := 1.0
		var goff := Vector2.ZERO
		if rec == "" and ghost.has(f):
			rec = ghost[f]
			if back_t >= 0.0 and motion:
				var t := clampf(back_t / BACK_TIME, 0.0, 1.0)
				ga = 1.0 - t
				goff = Vector2(-260, 260) * smoothstep(0.0, 1.0, t)
		if rec != "":
			var size: Vector2 = REC_SIZE[rec]
			# in the pocket's sleeve, clear of the cover's diagram
			var home := Vector2(pk.get_center().x - size.x / 2.0, pk.position.y + 186)
			var sc := 1.0
			var sk := self_file_k(rec)
			if sk < 1.0:
				# filing itself: up out of the tray into its own folder, unhurried
				var from := Vector2(CMP_TRAY.position.x + 18 + 178 * R10Sim.RECORDS.find(rec), CMP_TRAY.position.y + 14)
				var e := smoothstep(0.0, 1.0, sk)
				home = from.lerp(home, e)
				sc = lerpf(0.6, 1.0, e)
			_rec_at(c, rec, home + goff, sc, ga)
	# the leaves shutting on her, and the index bar across them
	for k in 3:
		var ck := leaf_closed(k)
		if ck <= 0.0:
			continue
		var pk: Rect2 = POCKETS[k]
		var lt := _tex("c_leaf_closed")
		if lt:
			# two half-leaves swing in from either side and meet over the record
			var hw := pk.size.x / 2.0
			c.draw_texture_rect_region(lt, Rect2(pk.position, Vector2(hw * ck, pk.size.y)),
				Rect2(0, 0, hw, pk.size.y))
			c.draw_texture_rect_region(lt, Rect2(pk.end.x - hw * ck, pk.position.y, hw * ck, pk.size.y),
				Rect2(hw, 0, hw, pk.size.y))
		if ck >= 0.95:
			_rtext(c, R10Sim.FOLDER_ORDER[k], Rect2(pk.position.x + 110, pk.position.y + 18, 140, 26), 18, INK, narrow)
	var by := bar_y()
	if not is_nan(by):
		_sprite(c, "c_index_bar", Vector2(BAR_X, by))
	# the comparison tray: its printed legend, then what COMPARE last read
	if cmp_date == "" and self_file_t < 0.0:
		_ctext(c, "TRAINING SUBJECT", CMP_TRAY.get_center().x, CMP_TRAY.get_center().y + 10, 26, Color(PAPER_HI, 0.9), narrow)
	_draw_cmp_tray(c)
	# the result window
	var lines := str(r.strip_text).split("\n")
	var lh := 22 if lines.size() <= 2 else 16
	var y0 := RESULT_WIN.get_center().y + 7 - (lines.size() - 1) * lh / 2.0
	for i in lines.size():
		var fs := 20 if lines.size() == 1 else (18 if lines.size() == 2 else 15)
		_ctext(c, lines[i], RESULT_WIN.get_center().x, y0 + lh * i, fs, INK, narrow)
	if not st.p18_complete:
		_draw_chair_dial(c, int(st.chair))
	# the date dials
	var vals := ["%02d" % int(st.day), R10Sim.MONTHS[int(st.month) - 1], str(int(st.year))]
	for k in 3:
		var w: Rect2 = DATE_WIN[k]
		_ctext(c, DATE_HEADS[k], w.get_center().x, w.position.y + 28, 15, INK, narrow_reg)
		_ctext(c, vals[k], w.get_center().x, w.position.y + 74, 36, INK, narrow)
	# COMPARE
	var down := key_down == "compare" and key_down_t > 0.0
	if down:
		_sprite(c, "c_key_down", COMPARE_POS)
	_ctext(c, "COMPARE", COMPARE_POS.x + 100, COMPARE_POS.y + 51 + (19 if down else 0), 22, INK, narrow)
	# the release: its printed panel either side of the knob, the lever, the slip below
	_ctext(c, "TRAINING", TRAINING_AT.x, TRAINING_AT.y, 17, INK, narrow)
	_ctext(c, "RELEASE", RELEASE_AT.x, RELEASE_AT.y, 17, INK, narrow)
	var lk := lever_k()
	if lk <= 0.0:
		_sprite(c, "c_lever_up", LEVER_POS)
	elif lk >= 1.0:
		_sprite(c, "c_lever_down", LEVER_POS)
	else:
		_draw_lever(c, lk)
	_slip(c, RELEASE_SLIP)
	_cpara(c, "Training model. Release returns all records.", RELEASE_SLIP.get_center().x,
		RELEASE_SLIP.position.y + 25, 17, INK, RELEASE_SLIP.size.x - 16, narrow_reg, 1.15)
	if st.p18_complete and lever_down():
		_slip(c, INDEX_CARD)
		_cpara(c, "THE STATION INDEX RETAINED EIGHT SUBJECTS THROUGH THESE THREE CORRESPONDENCES. 18.X.27.",
			INDEX_CARD.get_center().x, INDEX_CARD.position.y + 30, 20, INK, INDEX_CARD.size.x - 28, narrow, 1.2)

## How far record `rec` is on its way from the tray into its folder (1 = home). They go in the
## order R10Sim.RECORDS, a beat apart.
func self_file_k(rec: String) -> float:
	if self_file_t < 0.0:
		return 1.0
	var i := R10Sim.RECORDS.find(rec)
	return clampf((self_file_t - SELF_FILE_STAGGER * i) / SELF_FILE_TIME, 0.0, 1.0)

## The CHAIR dial plate: the plan of the session room with the chosen chair ringed, the number
## window and its two keys. Flat brass and ink, every numeral drawn.
func _draw_chair_dial(c: CanvasItem, chair: int) -> void:
	var p := CHAIR_PLATE
	c.draw_rect(Rect2(p.position + Vector2(5, 6), p.size), Color(STORM, 0.35))
	c.draw_rect(p, BRASS)
	c.draw_rect(p.grow(-6), BRASS_LO, false, 1.6)
	c.draw_rect(p, INK, false, 3.0)
	# the plan: the session room's walls with the door gap, the round table, eight chairs
	var rm := PLAN_ROOM
	c.draw_rect(rm, Color(PAPER, 0.95))
	var wall := 4.0
	c.draw_line(rm.position, Vector2(rm.end.x, rm.position.y), INK, wall)
	c.draw_line(Vector2(rm.end.x, rm.position.y), rm.end, INK, wall)
	c.draw_line(Vector2(rm.position.x, rm.end.y), rm.end, INK, wall)
	c.draw_line(rm.position, Vector2(rm.position.x, PLAN_DOOR.x), INK, wall)
	c.draw_line(Vector2(rm.position.x, PLAN_DOOR.y), Vector2(rm.position.x, rm.end.y), INK, wall)
	# the door: its leaf standing open, out of the room, from the hinge at the gap's top
	var hinge := Vector2(rm.position.x, PLAN_DOOR.x)
	var leaf := PLAN_DOOR.y - PLAN_DOOR.x
	c.draw_line(hinge, hinge + Vector2(-leaf * 0.7, -leaf * 0.7), INK, 3.0)
	c.draw_arc(hinge, leaf, PI * 0.75, PI, 12, Color(INK, 0.7), 1.4)
	_ctext(c, "DOOR", rm.position.x - 26, PLAN_DOOR.y + 22, 13, INK, narrow)
	c.draw_colored_polygon(Ink.ellipse(PLAN_C, 46.0, 13.0, 36), BRASS_LO)
	c.draw_polyline(Ink.ellipse(PLAN_C, 46.0, 13.0, 36), INK, 2.2, true)
	for k in 8:
		var at := plan_chair(k + 1)
		if k + 1 == chair:
			c.draw_circle(at, 15.0, INK)
			c.draw_circle(at, 12.5, BRASS_HI)
		else:
			c.draw_circle(at, 11.5, PAPER_HI)
			c.draw_arc(at, 11.5, 0.0, TAU, 24, INK, 1.8)
		_ctext(c, str(k + 1), at.x, at.y + 5.5, 15, INK, narrow)
	# the window and its number
	_ctext(c, "CHAIR", CHAIR_WIN.get_center().x, CHAIR_WIN.position.y - 6, 14, INK, narrow)
	c.draw_rect(CHAIR_WIN, PAPER_HI)
	c.draw_rect(Rect2(CHAIR_WIN.position.x, CHAIR_WIN.end.y - 9, CHAIR_WIN.size.x, 9), Color(SEPIA, 0.8))
	c.draw_rect(CHAIR_WIN, INK, false, 3.0)
	_ctext(c, str(chair), CHAIR_WIN.get_center().x, CHAIR_WIN.get_center().y + 15, 42, INK, narrow)
	# the keys: brass bosses with an ink arrow
	for id in CHAIR_KEYS:
		var at: Vector2 = CHAIR_KEYS[id]
		c.draw_circle(at + Vector2(2, 3), 21.0, Color(STORM, 0.45))
		c.draw_circle(at, 21.0, INK)
		c.draw_circle(at, 19.0, BRASS_HI)
		c.draw_arc(at, 14.0, 0.0, TAU, 28, BRASS_LO, 1.4)
		var tip := -9.0 if id == "chair_up" else 9.0
		c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, tip), at + Vector2(8, -tip * 0.7),
			at + Vector2(-8, -tip * 0.7)]), INK)

## Where chair `n` (1-8) sits on the CHAIR dial's plan.
func plan_chair(n: int) -> Vector2:
	var a := deg_to_rad(PLAN_A0 + (n - 1) * 45.0)
	return PLAN_C + Vector2(cos(a) * PLAN_R.x, sin(a) * PLAN_R.y)

## The release lever mid-pull (R10.py lever()): the knob travels from above the pivot boss
## to below it, the arm shortening through the boss as it swings toward her.
func _draw_lever(c: CanvasItem, k: float) -> void:
	var cx := LEVER_POS.x + 60.0
	var cy := LEVER_POS.y + 85.0
	var ty := lerpf(LEVER_POS.y + 20.0, LEVER_POS.y + 150.0, smoothstep(0.0, 1.0, k))
	var top := minf(cy, ty)
	var bot := maxf(cy, ty)
	if bot - top > 1.0:
		var arm := Rect2(cx - 9, top, 18, bot - top)
		c.draw_rect(arm, BRASS)
		c.draw_rect(arm, INK, false, 2.6)
	c.draw_circle(Vector2(cx, ty), 18.3, INK)
	c.draw_circle(Vector2(cx, ty), 17.0, EBONITE)
	c.draw_circle(Vector2(cx, cy), 25.3, INK)
	c.draw_circle(Vector2(cx, cy), 24.0, BRASS_LO)
	c.draw_circle(Vector2(cx, cy), 13.0, BRASS_HI)
	c.draw_arc(Vector2(cx, cy), 13.0, 0.0, TAU, 24, INK, 1.8)
	c.draw_circle(Vector2(cx, cy), 5.0, BRASS)

## What the comparison tray shows after COMPARE: the shadows of the records it read and the
## date it read them on, stamped. Presentation only: cleared when she leaves the close-up.
func _draw_cmp_tray(c: CanvasItem) -> void:
	if cmp_date == "":
		return
	if not r.subject_filed():
		for i in cmp_recs.size():
			var rec: String = cmp_recs[i]
			var size: Vector2 = REC_SIZE[rec] * 0.6
			var at := Vector2(CMP_TRAY.position.x + 18 + 178 * i, CMP_TRAY.position.y + 14)
			var t := _tex(REC_SPRITE[rec])
			if t:
				# the record's shadow, as if it still lay on the glass: its own shape in navy
				c.draw_texture_rect(t, Rect2(at, size), false, Color(0.16, 0.24, 0.3, 0.55))
	var box := Rect2(CMP_TRAY.end.x - 236, CMP_TRAY.end.y - 62, 220, 50)
	c.draw_set_transform(box.get_center(), deg_to_rad(-4.0), Vector2.ONE)
	var local := Rect2(-box.size / 2.0, box.size)
	c.draw_rect(local, Color(STAMP_CLOSED_COL, 0.85), false, 3.0)
	c.draw_rect(local.grow(-5), Color(STAMP_CLOSED_COL, 0.6), false, 1.4)
	_rtext(c, cmp_date, local, 24, Color(STAMP_CLOSED_COL, 0.9), narrow)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- c_model ------------------------------------------------------------------------------
## One terminal mark, flat ink, centred on `at`, `r` its half-size: "triangle" solid, "squares"
## two overlapping outlines, "circle" hollow. The same shapes as R04's session-log margin.
func glyph(c: CanvasItem, kind: String, at: Vector2, r: float, col: Color) -> void:
	var w := maxf(1.8, r * 0.2)
	match kind:
		"triangle":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r * 1.05, r * 0.8),
				at + Vector2(-r * 1.05, r * 0.8)]), col)
		"squares":
			var s := r * 1.2
			c.draw_rect(Rect2(at + Vector2(-r, -r), Vector2(s, s)), col, false, w)
			c.draw_rect(Rect2(at + Vector2(r - s, r - s), Vector2(s, s)), col, false, w)
		"circle":
			c.draw_arc(at, r - w / 2.0, 0.0, TAU, 40, col, w)
func _cable(c: CanvasItem, a: Vector2, b: Vector2, sag: float) -> void:
	var m := (a + b) / 2.0 + Vector2(0, sag)
	var pts := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		pts.append(a.lerp(m, t).lerp(m.lerp(b, t), t))
	c.draw_polyline(pts, INK, 9.0, true)
	c.draw_polyline(pts, STORM, 5.0, true)
	var hi := PackedVector2Array()
	for q in pts:
		hi.append(q + Vector2(-1, -1.5))
	c.draw_polyline(hi, Color("5d7a86"), 1.6, true)

## The STAFF opening's overlays in the mirror now: [[id, alpha], ...].
func mirror_staff() -> Array:
	if staff_shut_drawn():
		return [["cabinet_r3", 1.0]]
	var ids := STAFF_SEEPS
	var w := clampi(r.aperture_width(), 0, 2)
	if ap_hold:
		return [["cabinet_r3", 1.0], [ids[maxi(0, w - 1)], 1.0]]
	if ap_t >= 0.0 and w >= 1:
		var k := smoothstep(0.0, 1.0, ap_t / AP_TIME)
		return [["cabinet_r3", 1.0], [ids[w - 1], 1.0 - k], [ids[w], k]]
	return [["cabinet_r3", 1.0], [ids[w], 1.0]]

func _draw_mirror(c: CanvasItem) -> void:
	var plate := _tex("view_b_t%d" % tide_n())
	c.draw_set_transform(MIRROR.position + Vector2(MIRROR.size.x, 0), 0.0, Vector2(-1, 1))
	var dst := Rect2(Vector2.ZERO, MIRROR.size)
	if plate:
		c.draw_texture_rect_region(plate, dst, MIRROR_SRC)
	for pa in mirror_staff():
		var t := _tex(pa[0])
		if t:
			c.draw_texture_rect_region(t, dst, MIRROR_SRC, Color(1, 1, 1, pa[1]))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	# the glass: a cool skin and one diagonal gleam
	c.draw_rect(MIRROR, Color(0.55, 0.66, 0.7, 0.22))
	var g := MIRROR.position
	c.draw_colored_polygon(PackedVector2Array([g + Vector2(118, 0), g + Vector2(140, 0), g + Vector2(92, 78),
		g + Vector2(70, 78)]), Color(PAPER_HI, 0.16))
	c.draw_rect(MIRROR, INK, false, 2.4)

func _draw_model(c: CanvasItem) -> void:
	var st: Dictionary = r.state
	_full(c, "c_model")
	_draw_mirror(c)
	# faceplate: the port labels and nothing else. The rule is written only in the margin of
	# the session log (R04, P17); here it is learned by testing.
	for k in FACEPLATE_PORTS.size():
		glyph(c, R10Sim.TERMINAL_GLYPHS[FACEPLATE_PORTS[k]], Vector2(FACEPLATE_PORT_X[k], 152), 17.0, INK)
	# the strip
	var lines := strip_lines()
	for i in lines.size():
		_ctext(c, lines[i], STRIP_IN.get_center().x, STRIP_IN.position.y + 66 + 48 * i, 34, INK, narrow)
	# the bridge across WITNESS
	if bridge_drawn():
		_sprite(c, "c_bridge", BRIDGE_POS)
	# the lead: cables from INPUT's plug, then the plugs over them
	var ends := {"copy": CUPS[0], "witness": CUPS[1]}
	var seated := {"copy": st.copy, "witness": st.witness}
	if st.input:
		var from: Vector2 = SOCK.input + Vector2(0, 30)
		for key in ["copy", "witness"]:
			var to: Vector2 = SOCK[key] + Vector2(0, 30) if seated[key] else ends[key] + Vector2(0, -6)
			_cable(c, from, to, 110.0 if seated[key] else 50.0)
	else:
		_cable(c, CUPS[0] + Vector2(0, 10), CUPS[1] + Vector2(0, 10), 40.0)
	# the socket labels stay legible over the lead
	for key in ["input", "copy", "witness"]:
		var plate := Rect2(SOCK[key].x - 60, SOCK_LABEL_Y, 120, 26)
		c.draw_rect(plate, BRASS_HI)
		c.draw_rect(plate, INK, false, 1.8)
		glyph(c, R10Sim.TERMINAL_GLYPHS[key], plate.get_center(), 9.0, INK)
	if st.input:
		_sprite(c, "c_plug", SOCK.input - Vector2(40, 40))
	for key in ["copy", "witness"]:
		if st.input and seated[key]:
			_sprite(c, "c_plug", SOCK[key] - Vector2(40, 40))
		else:
			_sprite(c, "c_plug_parked", ends[key] - Vector2(40, 34))
	# keys
	var tdown := key_down == "test" and key_down_t > 0.0
	var rdown := key_down == "reset" and key_down_t > 0.0
	if tdown:
		_sprite(c, "c_mkey_down", TEST_POS)
	if rdown:
		_sprite(c, "c_rkey_down", RESET_POS)
	_ctext(c, "TEST AMENDMENT", TEST_POS.x + 130, TEST_POS.y + 56 + (20 if tdown else 0), 20, INK, narrow)
	_ctext(c, "RESET", RESET_POS.x + 90, RESET_POS.y + 56 + (20 if rdown else 0), 20, INK, narrow)
	# the stamp window
	var sw := stamp_word()
	if sw != "":
		var off := Vector2(0, 2) if press_t > 0.0 else Vector2.ZERO
		var col := STAMP_CLOSED_COL if sw == "closed" else STAMP_OPEN_COL
		_sprite(c, "c_stamp_" + sw, STAMP_POS + off)
		_rtext(c, sw.to_upper(), Rect2(STAMP_POS + off + Vector2(8, 10), Vector2(154, 100)), 34, col, narrow)
	# the shutter, until it is opened from the other side
	if not r.shutter_open():
		_sprite(c, "c_shutter", SHUTTER_POS)
		_rtext(c, "OBSERVER", SHUTTER_PLATE, 44, INK, narrow)
