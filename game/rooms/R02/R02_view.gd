extends RoomView
## R02, the Intake Office: renders R02Sim, plays its events, owns its light and loops.
## Migrated from the slice view (rounds 1-3); the subtitle scheduler, one-shots, HUD,
## notebook, menu, title and saves now live in the core (game/core/game.gd).
##
## Layering (inside the game's world layer):
##   this node (affected by CanvasModulate + 2D lights): room plate, lamp, overlays
##   CanvasLayer 1  "deep":  the open doorway, unlit: what is down there makes its own light
##   CanvasLayer 5  "close": close-ups and documents (always fully readable)
##   CanvasLayer 9  "flash": the spark's flash
## All state lives in `sim`; this script only presents it. Everything timed
## here (fades, reveals, loops) is presentation and is never saved.

const PAPER := Color("ded4ba")
const INK := Color("172b36")
const GOLD := Color("d2aa66")
const AMBER := Color("c39959")
const BRUISE := Color("746577")
const BLUE_INK := Color("1f3f8a")
## Her ink as it reads on black (the end card): BLUE_INK fails contrast on the dark.
const NIGHT_INK := Color("8fa6e0")
const BRASS := Color("b08a4a")
## The desk lamp's lit tint: never warmer or brighter than tarnished brass (AMBER, c39959),
## and its glow at most this opaque, so the brass reads as brass and not orange.
const LAMP_GLOW_ALPHA_MAX := 0.6

## Ambient modulate per phase (see _phase()): the Tide I stages, then the weather bands,
## then the endings. Floors, not targets: late stages are lit so the painted wrongness reads
## (owner note, round 3). Both facings share it.
const MODULATE := {
	"s0": Color(0.30, 0.33, 0.42), "s1": Color(0.46, 0.44, 0.48), "s2": Color(0.40, 0.40, 0.48),
	"t1x": Color(0.40, 0.39, 0.48), "b0": Color(0.46, 0.44, 0.50), "b1": Color(0.58, 0.60, 0.68),
	"b2": Color(0.56, 0.58, 0.66), "b3": Color(0.55, 0.56, 0.65), "b4": Color(0.54, 0.56, 0.66),
	"b5": Color(0.54, 0.55, 0.64), "b6": Color(0.54, 0.54, 0.62), "b7": Color(0.56, 0.55, 0.62),
	"sever": Color(0.95, 0.95, 0.93), "continue": Color(0.56, 0.55, 0.62),
}
## The lamp's pool of light shrinks as Tide I closes in; after it the desk is an isolated,
## usable warm pool.
const LAMP_SCALE := [3.2, 3.2, 1.85, 1.45]
const LAMP_SCALE_AFTER := 1.6
const VIGNETTE := {"s2": 0.35, "t1x": 0.40, "b0": 0.18, "b1": 0.18, "b2": 0.18, "b3": 0.2,
	"b4": 0.2, "b5": 0.2, "b6": 0.22, "b7": 0.25}
## The window's own light per phase (the modulate alone leaves painted glass black).
const SEA_GLOW := {"s2": 0.45, "t1x": 0.45, "b0": 0.45, "b1": 0.45, "b2": 0.45, "b3": 0.45,
	"b4": 0.45, "b5": 0.45, "b6": 0.45, "b7": 0.25, "continue": 0.25}
## The dusk wash over the glass: the window darkens with the story, never so far that the
## painted water stops reading.
const DUSK := {"s0": 0.18, "s1": 0.42, "s2": 0.45, "t1x": 0.45, "b0": 0.34, "b1": 0.16,
	"b2": 0.16, "b3": 0.14, "b4": 0.12, "b5": 0.12, "b6": 0.12, "b7": 0.10}
const BRICK := Color("8e3b2e")
## Venn's hand: plainer, upright, grey-black (the end card's 'his' row uses the same).
const VENN_INK := Color("2b3238")
## The lamp behind her when she faces the entry wall.
const BACK_LAMP_POS := Vector2(724, 1150)
const SEA_GLOW_COL := Color(0.62, 0.76, 0.76)
const TORCH_WARM := Color(1.0, 0.94, 0.82)
const TORCH_COLD := Color(0.82, 0.88, 1.0)
## The room at the threshold stays as lit as the wet seat left it (owner note, round 3):
## the dark is inside the corridor, not over the room.
const THRESHOLD_SHADE := Color(0.40, 0.39, 0.48)
## At the threshold the view leans in on the doorway, so the corridor and what stands in it
## are large: scale about a pivot on the right edge, so the door stays on screen.
const THRESHOLD_ZOOM := 1.3
const THRESHOLD_PIVOT := Vector2(1448, 560)
## After the lean the camera closes on the doorway: the slab fills over 42% of the frame,
## its vanishing point at the centre of the screen. Motion off: it is simply there.
const THRESHOLD_PUSH_SCALE := 3.0
const THRESHOLD_PUSH_AT := 2.2
const THRESHOLD_PUSH_TIME := 2.8
const SCREEN_C := Vector2(724, 543)
## The corridor, drawn flat in code (no upscaled texture): nested casings toward VP.
const CORRIDOR_NAVY := Color("1b2a36")
const CORRIDOR_TEAL := Color("2c5a5e")
const CORRIDOR_GAP := Color("0a1117")
const CORRIDOR_END := 0.12      # depth scale of the corridor's far end
const CORRIDOR_SKY := Color("4d6466")   # what the far end opens on when the tide is out
const WATER_SKIN := Color("8fa3b0")
const WATER_TOP := Color("22384a")
const MUD := Color("6d6150")
const WINDOW_MUD := Color("9c8868")   # the window's mud: the room's dusk takes it down to wet brown
const STUB := Color("2a2f33")
const FIGURE_INK := Color("05080b")
## The figure's fill: opaque storm navy, so nothing behind it (the far lighthouse) shows through.
const FIGURE_FILL := Color("1b2a36")
const FIGURE_DEPTH := 0.15      # where it stands: near the far end, its head on the horizon
const FIGURE_SCALES := [1.0, 1.12, 1.24, 1.35]   # per exhale, about VP (unused since p4)
## The figure stands still at one size, with Motion on or off (T1X card: no movement).
const FIGURE_SCALE_STILL := 1.2
## Corridor-space x offsets and depths of the five piling stubs on the drained floor.
const STUBS := [[62.0, 0.62], [58.0, 0.45], [54.0, 0.33], [50.0, 0.245], [46.0, 0.18]]
## The tide's resting height (0 floor .. 1 top casing bar).
const TIDE_REST := 0.10
const GO_ON_LINE := "Go on, then."
## The doorway's hover name once she may go on: the one verb the threshold hint names.
const WALK_ON_LABEL := "Walk toward it"
## Its label's top (screen): the bottom of the corridor, under the figure's feet and just
## above the subtitles, so the name never lies across what stands there.
const WALK_ON_LABEL_Y := 960.0
## The window during the threshold: the horizon, the piling feet's mud line, the top bar.
const WINDOW_HORIZON := 476.0
const WINDOW_MUD_LOW := 532.0
const WINDOW_TOP := 144.0
## The office window inset at the threshold: once the push has carried the room's own window
## off screen, the same plate's window (THRESHOLD_INSET_SRC, sash and all) is set into the
## coat-side wall left of the doorway, a quarter of the screen wide, in screen space. Its sea
## is R02Sim.threshold_sea() of the line on screen; everything in it is clipped to the window.
const THRESHOLD_INSET_SRC := Rect2(462, 123, 358, 442)
const THRESHOLD_INSET := Rect2(52, 150, 362, 447)
## The inset is on the unlit doorway layer: tinted to sit in the room's dusk, still legible.
const INSET_TINT := Color(0.74, 0.76, 0.82)
## The window's flooded sea: its skin above every piling and the deck, at the second sash bar.
const WINDOW_FLOOD_Y := 330.0
## The turn tab's signpost until she first turns round: a slow pulse (Motion off: steady).
const TURN_PULSE_PERIOD := 2.6
const TURN_SIGNPOST := Color("9fd0bf")   # sea-glass green
## The plate's jetty pilings below the deck (x), and the ninth, for the drained window.
const WINDOW_PILINGS := [646, 665, 684, 700, 715, 731, 749, 768, 783, 797]
## Off the plate's right edge (the push sees past it): the door's right casing, then wall.
const OFF_CASING := Color8(45, 82, 97)
const OFF_WALL := Color8(164, 180, 162)
const OFF_WAINSCOT := Color8(41, 79, 95)
## The wet seat's silence: room, drone and sea fall away and stay away until the third
## line has been read, then come back slowly.
const SEAT_HUSH_IN := 0.4
const SEAT_HUSH_OUT := 3.0
const SEAT_HUSH_LINE_AT := 6.6
const SEAT_HUSH_LINE := "Low down. Below the sill. Where the wall goes straight down into the water."
## The turn tab at the threshold at rest: legible, a step down from hovered.
const TAB_REST_ALPHA := 0.8
## The exit bar (exit tabs and the turn tab) at rest, while the cursor is elsewhere: faint,
## so the floor, the drawers and the prints read through it. A closed exit rests at 0.6 of
## this. The tabs still answer clicks at rest; only the drawing waits for the cursor.
const BAR_REST_ALPHA := 0.45
const SHADOW_COL := Color(0.02, 0.04, 0.07, 0.42)
const PRINT_COL := Color(0.06, 0.09, 0.12)
const PILING_COL := Color(0.07, 0.08, 0.11, 0.92)

## Room hotspots. First match wins, so small objects precede large ones.
const HOTSPOTS := [
	["mug", Rect2(915, 662, 82, 64), "Mug"],
	["tray", Rect2(341, 666, 128, 64), "Spares tray"],
	["lamp", Rect2(242, 469, 192, 260), "Desk lamp"],
	["logbook", Rect2(500, 684, 205, 64), "Tide log"],
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

## 'Go on' sits at the right end of the subtitle strip (GameView.SUBTITLE_BAR), as R12's does.
const END_BUTTON := Rect2(1256, 1008, 156, 52)
## The Tide I card's print: 70% of the screen's height, centred on x = 724 like the card's
## words; its caption sits under it on the same axis, outside the print (never on it as well).
## It comes up to full value over END_PHOTO_FADE (at once with Motion off).
const END_PHOTO_CX := 724.0
const END_PHOTO_TOP := 14.0
const END_PHOTO_H := 760.0
const END_PHOTO_FADE := 0.8
const END_CAPTION_SIZE := 18
const END_CAPTION_COL := Color("d9d2c0")
const END_PHOTO_BORDER := 22.0
const END_CAPTION := "Greywake. 18 Oct."
const END_CAPTION_GAP := 22.0
## Baselines under the print: the two log rows, then the closing lines, all above the strip.
const END_ROW_Y := [844.0, 884.0]
const END_LINE_Y := {R02Sim.END_ON_STATION: 926.0, R02Sim.END_ALL_SEEN: 960.0}
## Exit tabs along the floor line, clear of the drawer and the puddle. The core draws them.
const EXIT_RECTS := {
	"R01": Rect2(20, 922, 200, 64),
	"R03": Rect2(232, 922, 230, 64),
	"R04": Rect2(474, 922, 260, 64),
	"R05": Rect2(1196, 922, 112, 64),
	"R06": Rect2(1316, 922, 112, 64),
}

## View B, the entry wall (registered to assets/rooms/R02/entry_wall*.png).
const HOTSPOTS_B := [
	["receipt", Rect2(410, 604, 96, 120), "Receipt"],
	["outer_door", Rect2(88, 120, 316, 790), "Outer door"],
	["barometer", Rect2(456, 150, 208, 410), "Barometer"],
	["board", Rect2(692, 142, 436, 414), "Comparison board"],
	["service_door", Rect2(1160, 120, 270, 790), "Service door"],
]
## The turn tab between the desk wall and the entry wall, on the floor line between the exits.
const TURN_RECT := Rect2(746, 922, 76, 64)

# View B geometry.
const OUTER_GLASS_AT := Vector2(168, 216)
const LATCH_BAR := Rect2(330, 546, 52, 14)
const SERVICE_LABEL := Rect2(1235, 206, 120, 30)
const CLOCK_C := Vector2(560, 200)
const BARO_C := Vector2(560, 452)
const BARO_WORDS := [["STORMY", -120.0], ["RAIN", -60.0], ["CHANGE", 0.0], ["FAIR", 60.0], ["VERY DRY", 120.0]]
## Room-scale points on the board papers where the thread is pinned.
const BOARD_POINTS := {
	"m_addressee": Vector2(790, 230), "m_countersign": Vector2(790, 320), "m_callis": Vector2(912, 300),
	"m_orme": Vector2(912, 325), "m_mercer": Vector2(912, 352), "m_sentence": Vector2(1010, 276),
}
const PROVENANCE_STRIP := Rect2(760, 396, 300, 30)
## The three brass slot pins under the strip (as on c_board's lower rail): the thread runs
## from each pinned mark to its slot pin, then pin to pin, exactly as in the close-up.
const BOARD_SLOT_PINS := [Vector2(812, 438), Vector2(910, 438), Vector2(1008, 438)]
## The night print pinned over the letter's corner (b_board_solved.png), and its image.
const BOARD_PRINT := Rect2(1040, 300, 56, 66)
## The receipt's patch of wall: when it slides, the boards it covered come back from the
## plate itself, two boards (96 px) to the right, so every plate state matches.
const RECEIPT_PATCH := Rect2(410, 604, 96, 124)
## Exit tabs and the turn tab show while the cursor is on them (or at the bottom edge), so
## the floor, the drawers and the trail of prints stay visible the rest of the time.
const EXIT_REVEAL_PAD := 12.0
const EXIT_REVEAL_EDGE := 994.0

# c_board geometry. Hit-tested in this order.
const C_BOARD_PHOTO := Rect2(1180, 96, 120, 140)
const C_BOARD_RECTS := [
	["m_addressee", Rect2(186, 214, 298, 72)],
	["m_countersign", Rect2(186, 456, 298, 72)],
	["m_callis", Rect2(576, 372, 298, 64)],
	["m_orme", Rect2(576, 440, 298, 64)],
	["m_mercer", Rect2(576, 508, 298, 108)],
	["m_sentence", Rect2(966, 330, 298, 96)],
	["seal", Rect2(966, 470, 298, 110)],
	["read_contract", Rect2(170, 130, 330, 80)],
	["read_clipping", Rect2(560, 130, 330, 230)],
	["read_letter", Rect2(950, 130, 330, 190)],
	["slot_0", Rect2(250, 680, 240, 80)],
	["slot_1", Rect2(604, 680, 240, 80)],
	["slot_2", Rect2(958, 680, 240, 80)],
	["provenance", Rect2(250, 820, 520, 100)],
	["stamp_venn", Rect2(820, 812, 150, 116)],
	["stamp_board", Rect2(984, 812, 150, 116)],
	["stamp_unknown", Rect2(1148, 812, 150, 116)],
]
const C_CONTRACT := Rect2(170, 130, 330, 420)
const C_CLIPPING := Rect2(560, 130, 330, 500)
const C_LETTER := Rect2(950, 130, 330, 470)
const C_SEAL := Rect2(966, 470, 298, 110)
const STAMP_LINES := {"stamp_venn": ["REQUESTED", "BY VENN"], "stamp_board": ["ASSIGNED", "BY BOARD"],
	"stamp_unknown": ["UNKNOWN"]}
const CONTRACT_LINES := [
	"GREYWAKE SURVEY STATION. CONTRACT OF CLOSURE.",
	"Addressed to: Miss Ada Mercer, cataloguer.",
	"Inventory instruments. Reconcile outstanding records. Restore departure signal.",
	"Do not certify an observation you have not made.",
	"Signed for the Board. Countersigned: E. Venn.",
]
const SEAL_TEXT := "You have already refused to make a person disappear for the convenience of a form."
const PHOTO_BACK_TEXT := "Not mine. It was in the developing tray on the 15th. She will need to see herself from outside. — E.V."

## The two cards' words, in card space (800 x 650): [baseline y, size, text]. As the old
## SVG cards had them, now in the serif.
const DUTY_CARD_LINES := [[90, 24, "GREYWAKE SURVEY STATION"], [153, 36, "CLOSURE DUTY"],
	[236, 26, "Inventory the station instruments."], [281, 26, "Reconcile outstanding records."],
	[326, 26, "Restore the departure signal."], [416, 26, "Begin with the desk lamp."],
	[461, 26, "The spare bridge is in the tray."]]
const NOTE_CARD_LINES := [[90, 24, "GREYWAKE SURVEY STATION"], [153, 36, "PENCIL NOTE"],
	[236, 26, "Lamp service completed."], [326, 26, "Chart Room: register both sheets"],
	[371, 26, "at the lighthouse cross."], [461, 26, "Listening Room: preserve the"],
	[506, 26, "recording before winding again."]]

# c_duty / c_note and c_photo geometry.
const DUTY_CONTRACT := Rect2(800, 150, 500, 760)
const DUTY_CARD_BOX := Rect2(150, 150, 600, 760)
const PHOTO_PRINT := Rect2(460, 130, 528, 620)
const PHOTO_BACK_TEXT_RECT := Rect2(508, 250, 432, 360)
const TURN_OVER := Rect2(574, 800, 300, 76)

## The arrival notices: where the room holds the eye for 1.5 s.
const NOTICE_RECTS := {
	"callback": Rect2(500, 684, 205, 44), "b1": Rect2(832, 752, 152, 226), "b2": Rect2(915, 662, 82, 62),
	"b3": Rect2(428, 82, 430, 515), "b4": Rect2(428, 82, 430, 515), "b5": Rect2(428, 82, 430, 515),
	"b6": Rect2(840, 126, 350, 232), "b7": Rect2(1025, 300, 115, 540),
}
const NOTICE_TIME := 1.5
## The hook tags (band 6): stamped settings, hooks 1-8, and her measurements. One pale card
## per hook (assets/rooms/R02/hook_tags_large.png), two staggered rows, each tied to its hook.
const HOOK_X := [872, 907, 941, 976, 1011, 1045, 1080, 1115]
const HOOK_TAG_TOPS := [132, 196]
const HOOK_TAG_W := 50.0
## The A.M. tag on the ninth hook, at her collar height, tied on with the same brick string.
const HOOK9_TAG := Rect2(1138, 298, 46, 56)
const HOOK_TAGS := [["ZERO", "4"], ["INT", "3"], ["PRESS", "2"], ["BEAR", "3"], ["HT", "5'6"],
	["REACH", "5'7"], ["HAND", "R"], ["STRIDE", "2'4"]]
const HOOK9 := Vector2(1150, 262)
## The late wave: one pale crest per loop, starting at this phase of the late_wave loop.
const WAVE_PERIOD := 7.0
const WAVE_AT := 3.0
const WAVE_SWEEP := 0.8

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
const REVEAL_GAP := 0.5       # the pause between one written row and the next
## A row the log is writing is finished this long before the subtitle that reads it out.
const REVEAL_LEAD := 0.25
## Subtitles that read a log row out without quoting it: fragment -> the row's note.
## Any subtitle that quotes a row's note word for word reads that row too.
const LOG_CUES := {"that's my handwriting": "Observer: A. Mercer",
	"HW nine point nine": "Observer located."}
## Forward slant for her hand. In Godot's Transform2D a positive skew leans glyph tops
## to the right; -0.18 visibly cancelled the italic and read as a back-hand.
const HAND_SKEW := 0.18
const END_GRACE := 1.5

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

## R02's own sim, typed.
var office: R02Sim:
	get:
		return sim as R02Sim

var textures := {}
var serif: Font
var hand: Font

# nodes
var room: Node2D
var deep: Node2D
var close: Node2D
var shade: CanvasModulate
var torch: PointLight2D
var lamp_glow: PointLight2D
var sea_glow: PointLight2D     # the window's own light: the painted sea is lit from below
var flash: ColorRect

# presentation state (never saved)
var torch_dead := 0.0          # seconds of blackout left after a spark
var rng := RandomNumberGenerator.new()
var lamp_tween: Tween

var last_targets := {}         # the mix targets of the last audio tick (tests read these)
var hush := 0.0                # seconds the room falls silent around the knock
var palms_k := 0.0             # 0..1 palm marks on the glass after the knock
var palms_armed := false
var pane_tex: Array = []       # edge-padded window panes for the tipped sea, built lazily
var door_panner: AudioEffectPanner
var mixer: LoopMixer
var breath_clock := 0.0        # breath phase fallback when the loop isn't playing
var still_t := 0.0             # seconds the cursor has held still at the threshold
var still_anchor := Vector2.INF
var continue_ready := false
var continue_t := 0.0          # threshold_t when continue became available
var still_spoken := false
var door_env := 0.5            # the doorway's breath, frozen when she holds hers
var creep_t := 99.0            # seconds since the shadow last leaned
var deep_drawn := false        # the doorway layer has something on it

var last_stage := 0
var prints_fade := 1.0         # 0..1 fade-in of the first trail
var shadow_creep := 0          # 0..4: the shadow leans further each time she looks back
var tilt_k := 0.0              # 0..1 progress of the horizon tilt
var eye_x := 640.0
var log_shown_hand := 0        # in-hand log rows already written
var reveal_t := 0.0            # seconds into the row being written (or its pause)
var reveal_n := 0.0            # characters of that row written so far
var breath_hold := 0.0         # seconds the room holds its breath after the prints
var threshold_t := 0.0
var end_t := 0.0
var drawer_k := 1.0            # 0..1 drawer slide progress
var contours_k := 1.0          # 0..1 fade of Venn's ring contours on the chart
var away_alpha := {}           # look-away change id -> 0..1 fade (absent = fully in)
var pane_src := ""             # which plate the tipped panes were cut from
var back_lamp: PointLight2D    # the desk lamp behind her, facing the entry wall
var last_facing := "A"
var notice_rect := Rect2()     # the arrival hold's focus
var notice_t := -1.0           # seconds into the hold; < 0 when none
var photo_armed := false       # P20 solved: the photograph waits for its pin
var oil_hush := 0.0            # seconds the room holds near-silence around 'Yes.'
var oil_hush_done := false
var zoom_k := 0.0              # 0..1 the threshold lean toward the doorway
var push_k := 0.0              # 0..1 the push in on the doorway after the lean
var door_phase := 0.0          # the breath phase as last drawn (frozen while she holds hers)
var exhales := 0               # exhales begun since the door opened
var fig_scale := FIGURE_SCALE_STILL   # the figure's scale about VP (fixed)
var go_on_said := false
var seat_hush_t := -1.0        # seconds since the wet seat; < 0 when none
var hud_pass_open := false     # between tick and draw_hud: how strongly draw_hud paints the bar
var threshold_armed := false   # the doorway's lines are queued (on the door, or a load into it)
var threshold_line := -1       # the latest THRESHOLD_LINES entry that has come on screen
var pointer_at: Variant = null # tests: a Vector2 stands in for a hovering pointer there

func _ready() -> void:
	rng.seed = 9
	serif = Ink.serif()
	hand = Ink.hand()
	_load_textures()
	_build_nodes()
	_build_audio()
	apply_instantly()
	redraw()

## Stop every voice before the mixer.players go, so the audio server lets their playbacks go too.


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

## A full-canvas overlay by id, if it is there.
func _draw_full(c: CanvasItem, id: String, a := 1.0) -> void:
	var tex := _tex(id)
	if tex and a > 0.0:
		c.draw_texture_rect(tex, Rect2(Vector2.ZERO, SIZE), false, Color(1, 1, 1, a))

func _tex(id: String) -> Texture2D:
	return textures.get(id)



## The lamp's light colour: tarnished brass, its alpha capped at LAMP_GLOW_ALPHA_MAX.
static func lamp_glow_color() -> Color:
	return Color(AMBER, LAMP_GLOW_ALPHA_MAX)

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
	shade.color = MODULATE["s0"]
	add_child(shade)

	lamp_glow = PointLight2D.new()
	lamp_glow.texture = _radial(512, 0.35)
	lamp_glow.texture_scale = LAMP_SCALE[0]
	lamp_glow.color = lamp_glow_color()
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

	# The desk lamp behind her when she faces the entry wall: a warm wedge from the lower
	# right (painted as a quarter-scale light texture), never a sourceless pool.
	back_lamp = PointLight2D.new()
	var wedge := _tex("R02/b_lamp_wedge")
	if wedge:
		back_lamp.texture = wedge
		back_lamp.texture_scale = 4.0
		back_lamp.position = Vector2(SIZE.x / 2.0, (wedge.get_height() * 4.0) / 2.0)
	else:
		back_lamp.texture = _radial(512, 0.4)
		back_lamp.texture_scale = 3.0
		back_lamp.position = BACK_LAMP_POS
	back_lamp.color = lamp_glow_color()
	back_lamp.energy = 0.0
	add_child(back_lamp)

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

	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 9
	add_child(flash_layer)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = SIZE
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(flash)

func _build_audio() -> void:
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
	mixer = LoopMixer.new()
	add_child(mixer)
	for id in ["room", "sea", "wind", "drip", "hum", "drone", "heartbeat", "breath", "ring", "pen",
			"clock", "rain_glass", "whistle", "late_wave", "pressure", "gulls", "kitchen_air"]:
		mixer.add_loop(id, _load_audio(id), "Door" if id == "breath" else "Master")

func sfx_bus(id: String) -> String:
	return "Door" if id in ["door", "latch_near"] else "Master"

## Missing sound files are skipped silently: sound is built by a separate tool.

## Missing sound files are skipped silently: sound is built by a separate tool.
func _load_audio(id: String) -> AudioStream:
	return game.load_audio(id) if game else null

# ---------------------------------------------------------------------------
# persistence
# ---------------------------------------------------------------------------




# ---------------------------------------------------------------------------
# frame
# ---------------------------------------------------------------------------

func tick(dt: float) -> void:
	_open_hud_pass()
	if office.facing != last_facing:
		# Turning round is a cut, not a fade: the light is already where it belongs.
		last_facing = office.facing
		_snap_light()
	_tick_stage(dt)
	_tick_reveal(dt)
	_tick_light(dt)
	_tick_audio(dt)
	if office.view in ["room", "threshold"]:
		room.queue_redraw()
	if _at_threshold() or deep_drawn:
		deep.queue_redraw()
	if not office.view in ["room", "threshold"]:
		close.queue_redraw()

func _started() -> bool:
	return game != null and game.sim.state.started

func _at_threshold() -> bool:
	return office.view == "threshold" or office.view in ["notebook", "menu"] and office.return_view == "threshold"

## Where the office is in the story, for light, plates and mix: the Tide I stages ("s0",
## "s1", "s2", "t1x"), then the weather band ("b0".."b7"), then an ending.
func _phase() -> String:
	var e := office.ending()
	if e != "":
		return e
	if office.state.finished:
		return "b%d" % office.band()
	return ["s0", "s1", "s2", "t1x"][office.stage()]

## The weather band as the office shows it, or -1 in Tide I and in the endings.
func _band() -> int:
	if not office.state.finished or office.ending() != "":
		return -1
	return office.band()

## The horizon is tipped from band 3 (the plates from band 4 paint their own tilt).
func _tilted() -> bool:
	return _band() >= 3

func _tick_stage(dt: float) -> void:
	last_stage = office.stage()
	tilt_k = 1.0 if _tilted() else 0.0
	if prints_fade < 1.0:
		prints_fade = minf(1.0, prints_fade + dt / 1.5) if motion else 1.0
	if drawer_k < 1.0:
		drawer_k = minf(1.0, drawer_k + dt / 0.8) if motion else 1.0
	if palms_armed and palms_k < 1.0:
		palms_k = minf(1.0, palms_k + dt / 2.0) if motion else 1.0
	if contours_k < 1.0:
		contours_k = minf(1.0, contours_k + dt / 2.0) if motion else 1.0
	for k in away_alpha.keys():
		away_alpha[k] = minf(1.0, away_alpha[k] + dt / 0.8) if motion else 1.0
		if away_alpha[k] >= 1.0:
			away_alpha.erase(k)
	if notice_t >= 0.0:
		notice_t += dt
		if notice_t >= NOTICE_TIME:
			notice_t = -1.0
	creep_t += dt
	breath_clock += dt
	if motion:
		var mx := clampf(get_global_mouse_position().x, 560.0, 720.0)
		eye_x = lerpf(eye_x, mx, clampf(dt * 0.8, 0.0, 1.0))
	else:
		eye_x = 640.0
	if _at_threshold():
		threshold_t += dt
		_tick_still(dt, game.pointer_position() if game else get_global_mouse_position())
		_tick_figure(dt)
		_tick_go_on()
		threshold_line_index()
	if seat_hush_t >= 0.0:
		seat_hush_t += dt
		if seat_hush_k(seat_hush_t) >= 1.0 and seat_hush_t > SEAT_HUSH_IN:
			seat_hush_t = -1.0
	if office.view == "end":
		end_t += dt
	breath_hold = maxf(0.0, breath_hold - dt)
	_tick_zoom(dt)
	hush = maxf(0.0, hush - dt)
	oil_hush = maxf(0.0, oil_hush - dt)

## The lean toward the doorway: in with the door's opening, back out when she turns round.
## Motion off: it snaps.
func _tick_zoom(dt: float) -> void:
	var at := _at_threshold()
	var target := 1.0 if at else 0.0
	var push_target := 1.0 if at and (threshold_t >= THRESHOLD_PUSH_AT or not motion) else 0.0
	if not motion:
		zoom_k = target
		push_k = push_target
	else:
		if zoom_k < target:
			zoom_k = minf(target, zoom_k + dt / 2.2)
		else:
			zoom_k = maxf(target, zoom_k - dt / 0.6)
		if push_k < push_target:
			push_k = minf(push_target, push_k + dt / THRESHOLD_PUSH_TIME)
		else:
			push_k = maxf(push_target, push_k - dt / 0.6)
	var xf := _zoom_xform()
	if transform != xf:
		transform = xf
		deep.transform = xf

## Room space to screen space at the current lean.
func _zoom_xform() -> Transform2D:
	var s := lerpf(1.0, THRESHOLD_ZOOM, smoothstep(0.0, 1.0, zoom_k))
	var o := THRESHOLD_PIVOT - THRESHOLD_PIVOT * s
	var p := smoothstep(0.0, 1.0, push_k)
	if p > 0.0:
		o = o.lerp(SCREEN_C - VP * THRESHOLD_PUSH_SCALE, p)
		s = lerpf(s, THRESHOLD_PUSH_SCALE, p)
	return Transform2D(0.0, Vector2(s, s), 0.0, o)

## The breaths are counted (the corridor's tide keeps to them); the figure does not move:
## it stands at one size, Motion on or off.
func _tick_figure(_dt: float) -> void:
	fig_scale = FIGURE_SCALE_STILL   # it does not come nearer: it is simply there
	if not motion or _breath_held():
		return
	var ph := _breath_phase()
	if door_phase < BREATH_IN and ph >= BREATH_IN and ph - door_phase < 2.0:
		exhales += 1
	door_phase = ph

## Once she may go on and has stood a while without going, one quiet push.
func _tick_go_on() -> void:
	if go_on_said or not continue_ready or office.view != "threshold":
		return
	if threshold_t >= maxf(12.0, continue_t + 3.0):
		go_on_said = true
		game._insert_line(GO_ON_LINE, maxf(time, game._story_backlog_end()), false)

## The figure at the corridor's end comes up over the first seconds and then stays, fully
## opaque; Motion off, it is simply there from 1.5 s. Holding her breath never hides it.
static func threshold_figure_alpha(t: float, motion_on: bool, _held: bool) -> float:
	if not motion_on:
		return 1.0 if t >= 1.5 else 0.0
	return smoothstep(1.5, 3.0, t)

## The latest threshold line that has come on screen (latched: it stays after the line goes),
## read from the core's subtitle, so the window's sea changes on that line's first frame.
func threshold_line_index() -> int:
	if game and _at_threshold() and game.cur_text != "":
		for i in range(R02Sim.THRESHOLD_LINES.size() - 1, threshold_line, -1):
			if game.cur_text == R02Sim.THRESHOLD_LINES[i][1]:
				threshold_line = i
				break
	return threshold_line

## The office window's sea at the threshold: 0 as painted, 1 drained, 2 flooded.
func threshold_sea_now() -> int:
	return R02Sim.threshold_sea(threshold_line_index())

## The tide in the corridor at a breath phase: x = how far the water has drained back
## toward the far end (0..1), y = its height up the corridor (0 floor .. 1 top casing bar).
## The inhale drains it to bare mud; the exhale brings it back and up to the top bar; the
## stillness lets it settle to rest.
static func threshold_tide(phase: float) -> Vector2:
	var env := _breath_env(phase)
	if phase < BREATH_IN:
		return Vector2(clampf(env, 0.0, 1.0), TIDE_REST)
	if phase < BREATH_OUT_END:
		var u := clampf(1.0 - env / BREATH_OUT_PEAK, 0.0, 1.0)
		return Vector2(1.0 - smoothstep(0.0, 0.12, u), lerpf(TIDE_REST, 1.0, smoothstep(0.08, 0.6, u)))
	var v := (phase - BREATH_OUT_END) / (BREATH_PERIOD - BREATH_OUT_END)
	return Vector2(0.0, lerpf(1.0, TIDE_REST, smoothstep(0.0, 1.0, v)))

## The tide as drawn. Motion off: the state the current line describes.
func _tide_drawn() -> Vector2:
	if not motion:
		match threshold_sea_now():
			1:
				return Vector2(1.0, TIDE_REST)
			2:
				return Vector2(0.0, 1.0)
		return Vector2(0.0, TIDE_REST)
	var ph := door_phase if _breath_held() else _breath_phase()
	if exhales == 0 and ph >= BREATH_IN:
		return Vector2(0.0, TIDE_REST)   # the tail of a breath from before the door: at rest
	return threshold_tide(ph)

## The wet seat's silence factor at `t` seconds after the click: 1 -> 0 over SEAT_HUSH_IN,
## held at 0 until the third line has been read, then back to 1 over SEAT_HUSH_OUT.
static func seat_hush_k(t: float) -> float:
	if t < 0.0:
		return 1.0
	var hold_end := SEAT_HUSH_LINE_AT + GameView.min_read(SEAT_HUSH_LINE)
	if t < SEAT_HUSH_IN:
		return 1.0 - t / SEAT_HUSH_IN
	if t < hold_end:
		return 0.0
	return clampf((t - hold_end) / SEAT_HUSH_OUT, 0.0, 1.0)

## The threshold asks her to hold still. The cursor is her body: once it has stayed within
## 4 px for long enough (or the fallback passes, for anyone who can't), she may go on.

func _tick_still(dt: float, mouse: Vector2) -> void:
	if threshold_t < R02Sim.THRESHOLD_STILL_AFTER:
		return
	if still_anchor == Vector2.INF or mouse.distance_to(still_anchor) > 4.0:
		still_anchor = mouse
		if not still_spoken:
			still_t = 0.0
	else:
		still_t += dt
	if not _breath_held():
		door_env = _breath_env(_breath_phase())
	if not still_spoken and (still_t > 3.0 or threshold_t >= R02Sim.THRESHOLD_FALLBACK):
		still_spoken = true
		continue_ready = true
		continue_t = threshold_t
		# After anything still being said, never squeezed in front of it.
		game._insert_line(R02Sim.THRESHOLD_STILL_LINE, game._story_backlog_end(), true)
		# The pointer has not moved, so re-read what is under it: if it is resting on the
		# corridor, the verb names itself now, not on the next twitch.
		game.hover_id = game._hover_at(mouse)

## True once she has held still long enough that the corridor stops breathing.

func _breath_held() -> bool:
	return still_spoken or threshold_t >= R02Sim.THRESHOLD_STILL_AFTER and still_t > 1.2

## The breath envelope at a phase in [0, BREATH_PERIOD): inhale, exhale, then stillness.

static func _breath_env(phase: float) -> float:
	if phase < BREATH_IN:
		return pow(sin(PI / 2.0 * phase / BREATH_IN), 2)
	if phase < BREATH_OUT_END:
		return BREATH_OUT_PEAK * pow(cos(PI / 2.0 * (phase - BREATH_IN) / (BREATH_OUT_END - BREATH_IN)), 2)
	return 0.0

## Where the breath loop is now. The loop itself is the clock, so sound and light agree.

func _breath_phase() -> float:
	var p: AudioStreamPlayer = mixer.players.get("breath")
	if p and p.playing:
		return fmod(p.get_playback_position(), BREATH_PERIOD)
	return fmod(breath_clock, BREATH_PERIOD)

## The breath for drawing: 0..1, constant at the midpoint with Motion off.

func _env_drawn() -> float:
	if not motion:
		return 0.5
	return clampf(_breath_env(_breath_phase()), 0.0, 1.0)

func _modulate_target() -> Color:
	return MODULATE[_phase()]

func _lamp_scale_target() -> float:
	return LAMP_SCALE[office.stage()] if not office.state.finished else LAMP_SCALE_AFTER

func _sea_glow_target() -> float:
	if not _started() or office.facing != "A":
		return 0.0
	return SEA_GLOW.get(_phase(), 0.0)

func _back_lamp_target() -> float:
	if not _back_lamp_on():
		return 0.0
	return 0.5

## The lamp is behind her on the entry wall once it is mended (never before: the corridor's
## 'light first' gate holds here too), except in the grey daylight of the sever ending.
func _back_lamp_on() -> bool:
	return office.facing == "B" and office.state.p01_complete and office.ending() != "sever"

## Every light straight to where the state puts it (entry, load, jump, a turn).
func _snap_light() -> void:
	var b := office.facing == "B"
	shade.color = _modulate_target()
	lamp_glow.texture_scale = _lamp_scale_target()
	lamp_glow.energy = 1.05 if office.state.p01_complete and not b else 0.0
	sea_glow.energy = _sea_glow_target()
	back_lamp.energy = _back_lamp_target()

func _tick_light(dt: float) -> void:
	var s := office.stage()
	var after: bool = office.state.finished
	var at_door := _at_threshold()
	var facing_b := office.facing == "B"
	var in_room: bool = office.view in ["room", "threshold"] or \
		office.view == "menu" and office.return_view in ["room", "threshold"]
	# Her hand-held light is on the desk wall only: facing the entry wall, the lamp behind her
	# is the only light, so nothing glows without a source.
	torch.visible = in_room and _started() and office.ending() != "sever" and not facing_b
	torch.global_position = get_global_mouse_position()
	var flick := 1.0
	if motion:
		flick = 0.93 + 0.07 * sin(time * 13.0) * sin(time * 7.3)
		if s >= 2 and not after and fmod(time, 9.0) < 0.35:
			flick *= 0.35 + 0.65 * absf(sin(time * 40.0))   # the torch stutters in Tide I's last hour
	if torch_dead > 0.0:
		torch_dead -= dt
		flick = 0.0 if torch_dead > 0.25 or not motion else rng.randf()
	# After Tide I the room is lit enough to see; the torch is only a hand-held warmth.
	var torch_k := 0.45 if after else (0.75 if s >= 1 else 1.0)
	torch.energy = 1.15 * flick * torch_k * (0.4 if at_door else 1.0)
	torch.color = torch.color.lerp(TORCH_COLD if s >= 2 else TORCH_WARM, clampf(dt * 0.6, 0.0, 1.0))
	if at_door:
		shade.color = shade.color.lerp(THRESHOLD_SHADE, clampf(dt * 1.0, 0.0, 1.0))
	else:
		shade.color = shade.color.lerp(_modulate_target(), clampf(dt * 1.5, 0.0, 1.0))
	var scale_target := _lamp_scale_target()
	var scale_rate := 0.6
	if s >= 2 and not after and motion and not at_door:
		# The pool of light breathes with the room.
		scale_target *= 1.0 + 0.04 * (_env_drawn() * 2.0 - 1.0)
		scale_rate = 1.5
	lamp_glow.texture_scale = lerpf(lamp_glow.texture_scale, scale_target, clampf(dt * scale_rate, 0.0, 1.0))
	var glow_target := _sea_glow_target()
	if at_door:
		glow_target *= 0.5
	sea_glow.energy = lerpf(sea_glow.energy, glow_target, clampf(dt * 1.5, 0.0, 1.0))
	back_lamp.energy = lerpf(back_lamp.energy, _back_lamp_target(), clampf(dt * 3.0, 0.0, 1.0))
	if office.state.p01_complete and not facing_b:
		var lamp_target := 1.05
		if at_door:
			lamp_target = 0.85
		elif s >= 2 and not after:
			# The lamp swells and sags with the breath. With Motion off it holds the midpoint.
			lamp_target *= 0.96 + 0.04 * _env_drawn()
		var rate := 1.0 if at_door else 3.0
		if lamp_tween == null or not lamp_tween.is_running():
			lamp_glow.energy = lerpf(lamp_glow.energy, lamp_target, clampf(dt * rate, 0.0, 1.0))
	else:
		lamp_glow.energy = 0.0
	if flash.color.a > 0.0:
		flash.color.a = maxf(0.0, flash.color.a - dt * 4.0)

func _knock_pending() -> bool:
	return game.sfx_pending("knock_glass") if game else false

## Ambient targets for every loop. Tide I keeps the slice's mix (plus the clock); after the
## threshold the weather band drives it; the endings have their own.
func _tick_audio(dt: float) -> void:
	var s := office.stage()
	var env := clampf(_breath_env(_breath_phase()), 0.0, 1.0)
	# The sea goes quiet after the first read, except while she is still reading it.
	var silent: bool = office.state.log_read and (office.view != "logbook" or office.state.heard_silence \
		or office.state.prints_seen)
	var focus := 0.55 if office.is_closeup() or office.view == "notebook" else 1.0
	var b := _band()
	var ending := office.ending()
	var facing_b := office.facing == "B"
	var target := {
		"room": [0.30, 0.30, 0.12, 0.12][s],
		"sea": 0.0 if silent else 0.75 * focus,
		"wind": 0.15 * focus if silent else [0.35, 0.35, 0.15, 0.18][s] * focus,
		"drip": [0.45, 0.45, 0.0, 0.6][s] * focus,
		"hum": 0.18 if office.state.p01_complete else 0.0,
		"drone": [0.0, 0.0, 0.30, 0.50][s],
		"heartbeat": 0.0,
		"ring": [0.0, 0.0, 0.05, 0.07][s],
		"breath": 0.16 if s == 3 else 0.0,
		"pen": 0.45 if _reveal_active() or _end_row_writing() or game._intrusion_writing() else 0.0,
		"clock": (0.26 if facing_b else 0.16) * focus,
		"rain_glass": 0.0, "whistle": 0.0, "late_wave": 0.0, "pressure": 0.0, "gulls": 0.0,
		"kitchen_air": 0.0,
	}
	if ending != "":
		for k in target: target[k] = 0.0
		target["clock"] = 0.2 * focus
		target["hum"] = 0.18
		if ending == "sever":
			target["sea"] = 0.5 * focus
			target["gulls"] = 0.35 * focus
			target["wind"] = 0.12 * focus
			target["room"] = 0.25
		else:
			target["pressure"] = 0.12
			target["room"] = 0.12
	elif b >= 0:
		target["room"] = 0.22
		target["breath"] = 0.0
		target["drip"] = 0.45 * focus
		target["drone"] = 0.30 if b >= 2 else 0.0
		target["ring"] = 0.05 if b >= 4 else 0.0
		target["wind"] = 0.0 if b >= 5 else 0.15 * focus
		target["clock"] = 0.0 if b >= 6 else target["clock"]
		target["rain_glass"] = [0.0, 0.30, 0.40, 0.34, 0.30, 0.0, 0.0, 0.0][b] * focus
		target["whistle"] = [0.0, 0.14, 0.16, 0.12, 0.10, 0.0, 0.0, 0.0][b] * focus
		target["late_wave"] = 0.28 * focus if b == 3 else 0.0
		target["pressure"] = 0.35 if b == 7 else 0.0
		if facing_b and not office.service_locked() and b >= 1 and b <= 6:
			target["kitchen_air"] = 0.08 * focus
	# The sea and the wind drain away together; the pen stops with the nib.
	var rates := {"sea": 0.9, "wind": 0.9 if silent else 0.8, "pen": 4.0}
	var hum_pitch := 1.0 - 0.012 * (s if not office.state.finished else 1)
	if not _started():
		for k in target: target[k] = 0.0
		target["sea"] = 0.4
		target["wind"] = 0.3
	elif office.view == "end":
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
		if s >= 2 and not office.state.finished:
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
		if oil_hush > 0.0:
			# 'Yes.' is said into near-silence.
			for k in target:
				target[k] *= 0.4
				rates[k] = 3.0
		if seat_hush_t >= 0.0:
			# The wet seat: no stinger, the room simply stops. The knock's own hush sits
			# inside this one; afterwards only this factor brings the loops back.
			var f := seat_hush_k(seat_hush_t)
			for k in ["room", "drone", "sea"]:
				target[k] *= f
				rates[k] = 1.0 / SEAT_HUSH_IN if seat_hush_t < SEAT_HUSH_IN else (4.0 if f == 0.0 else 1.0 / SEAT_HUSH_OUT)
	if office.view != "end" and _motif_playing():
		target["drone"] *= 0.6   # the harmonium sits on top of the drone, not inside it
	last_targets = target
	mixer.tick(target, rates, dt)
	if mixer.players.has("hum"):
		var hum: AudioStreamPlayer = mixer.players["hum"]
		hum.pitch_scale = lerpf(hum.pitch_scale, hum_pitch, clampf(dt * 0.5, 0.0, 1.0))
	if door_panner:
		door_panner.pan = move_toward(door_panner.pan, 0.6 if _at_threshold() else 0.0, dt * 1.0)

## True while a live one-shot is playing the motif (or its short tail).
func _motif_playing() -> bool:
	return game.oneshot_playing(["motif", "motif_short"]) if game else false

## The room falls silent to listen to the glass, just before the knock lands; and it goes
## nearly silent for the coat's answer at the board.
func on_sfx_pending(id: String, left: float) -> void:
	if id == "knock_glass" and left <= 0.6 and hush == 0.0:
		hush = 1.6
	if id == "oilskin" and left <= 0.6 and not oil_hush_done:
		oil_hush_done = true
		oil_hush = 1.2

# ---------------------------------------------------------------------------
# subtitles: a scheduler keyed to absolute time
# ---------------------------------------------------------------------------
## Every queued line is {text, due, story, beat, click, hold}: `click` is the dispatch that
## queued it, `beat` the click of the reveal it belongs to (0 for none), and `hold` how
## long it stays up once shown.


## A story line on screen can't be replaced by a click until it has been readable.


## Queued lines never cut off any line, story or not, before its hold: without this an
## overdue story line would replace a click's fresh line on the very next frame. A non-story
## line yields early: to a newer click's line after FEEDBACK_HOLD, and to a waiting story
## line once it has had the squeezed read time, so chatter never starves a reveal.


## When the story lines already queued (and a story line on screen) will have been read.


## A new reveal is arriving: everything older that is still waiting is re-timed back to
## back from now at BACKLOG_SQUEEZE of its read time, so nothing is lost and nothing
## goes stale. Returns when the squeezed backlog ends.




## A story chain is playing: a line of it is queued, or one is on screen and still held.
## While it plays, a click in the scene advances it instead of starting something new.


## The player sets the chain's speed: bring its next line up now, with its own sounds.
## Everything queued moves up by the same amount, so nothing behind it changes order.


## A click (or tap) at `p`, exactly as the mouse handler does it. Drivers and tests use it.
## The HUD always answers; anywhere else, a playing chain is advanced, not interrupted.


## Views where a playing chain holds clicks. The threshold has its own clock, and the
## title, end card and menu show no subtitles.

## The threshold has its own clock, and the end card shows no subtitles.
func chain_gates() -> bool:
	return not office.local_view in ["threshold", "end"]

func hud_hidden() -> bool:
	return office.local_view == "end"

func esc_action() -> String:
	if office.local_view == "end":
		return ""
	if office.local_view == "threshold":
		return "menu"
	return super.esc_action()

## The exits answer whenever she is looking at the room, and only then: hit-testing never
## waits on the cursor or on a frame being drawn, so a tap, a driver's click, or a click after
## a tick with no draw all go through. How strongly the bar is painted is draw_hud's business.
func exits_active() -> bool:
	return office.local_view == "room"

## The exit bar shows at full strength only while the cursor is on a tab (or at the bottom
## edge of the screen); the rest of the time it is faint, so it does not cover the floor,
## the drawers and the prints.
func _exit_bar_live() -> bool:
	if game == null:
		return true
	if pointer_at is Vector2:
		return exit_bar_live_at(pointer_at)
	if not game.has_pointer():
		return true
	return exit_bar_live_at(game.pointer_position())

## The HUD pass (opened by tick, closed by draw_hud) only says whether draw_hud is painting
## the room's bar this frame, and so how strongly: it never gates a hit-test.
func _open_hud_pass() -> void:
	hud_pass_open = game != null and game.sim.view == "room" and office.view == "room" and not hud_hidden()

func _close_hud_pass() -> void:
	hud_pass_open = false

## Without a hovering pointer (headless, touch screens) the bar is simply always there:
## there is no cursor to call it up with. The core's pointer stands in for drivers and tests.
func _has_pointer() -> bool:
	return game != null and game.has_pointer()

func exit_bar_live_at(p: Vector2) -> bool:
	if p.y >= EXIT_REVEAL_EDGE:
		return true
	if TURN_RECT.grow(EXIT_REVEAL_PAD).has_point(p):
		return true
	for r in exit_rects().values():
		if r.grow(EXIT_REVEAL_PAD).has_point(p):
			return true
	return false


## Inserts a line due at absolute time `due`, after any line due no later.






## A click's immediate line. Drops older clicks' chatter (never a story line, never this
## click's own lines). If a story line is still being read, or the last click's line has
## been up for less than FEEDBACK_HOLD, the new line goes to the front of the queue so
## feedback is never starved behind a reveal.


# ---------------------------------------------------------------------------
# events
# ---------------------------------------------------------------------------



func on_view_changed(before: String) -> void:
	if before == "board" and office.view != "photo":
		photo_armed = false   # she left before the pin: the photograph is simply there next time
	if office.view == "room" and (office.is_closeup(before) or before == "notebook"):
		shadow_creep = mini(shadow_creep + 1, 4)
		creep_t = 0.0
	if before == "logbook":
		# Leaving mid-reveal: the lines are simply there next time.
		log_shown_hand = _in_hand_count()
		reveal_t = 0.0
		reveal_n = 0.0
	if office.view == "end":
		end_t = 0.0

## Dev/capture: jump to a story stage with clean presentation.


## Clears everything timed so a restart or jump can't inherit old lines or sounds.

## Clears everything timed so a restart or jump can't inherit old reveals.
func reset_presentation() -> void:
	torch_dead = 0.0
	if lamp_tween:
		lamp_tween.kill()
		lamp_tween = null
	lamp_glow.energy = 0.0
	reveal_n = 0.0
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
	threshold_armed = false
	threshold_line = -1
	_reset_still()
	end_t = 0.0
	drawer_k = 1.0
	flash.color.a = 0.0
	away_alpha.clear()
	notice_t = -1.0
	photo_armed = false
	oil_hush = 0.0
	oil_hush_done = false
	zoom_k = 0.0
	push_k = 0.0
	exhales = 0
	fig_scale = FIGURE_SCALE_STILL
	go_on_said = false
	seat_hush_t = -1.0
	transform = Transform2D.IDENTITY
	deep.transform = Transform2D.IDENTITY

func _reset_still() -> void:
	still_t = 0.0
	still_anchor = Vector2.INF
	continue_ready = false
	continue_t = 0.0
	still_spoken = false
	door_env = 0.5

func play_fx(id: String, e: Dictionary = {}) -> void:
	match id:
		"notice":
			# The room holds the eye on what changed, once, on arrival. A click ends it.
			var key := str(e.get("key", ""))
			if NOTICE_RECTS.has(key):
				notice_rect = NOTICE_RECTS[key]
				notice_t = 0.0
		"look_away":
			var change := str(e.get("change", ""))
			if change != "":
				away_alpha[change] = 0.0 if motion else 1.0
		"seat_hush":
			seat_hush_t = 0.0
		"p20_solved":
			photo_armed = true
			oil_hush_done = false
		"spark":
			if motion:
				flash.color = Color(0.85, 0.9, 1.0, 0.75)
			torch_dead = 1.1
		"lamp_on":
			lamp_glow.energy = 0.0
			if motion:
				if lamp_tween:
					lamp_tween.kill()
				lamp_tween = create_tween()
				for en in [0.9, 0.1, 0.7, 0.0, 1.05]:
					lamp_tween.tween_property(lamp_glow, "energy", en, 0.09)
		"prints":
			prints_fade = 0.0 if motion else 1.0
			breath_hold = 2.5
		"drawer_open":
			drawer_k = 0.0 if motion else 1.0
		"contours":
			contours_k = 0.0 if motion else 1.0
		"threshold":
			threshold_armed = true
			threshold_t = 0.0
			threshold_line = -1
			_reset_still()
			hush = 0.0
			# A new scene. Room chatter stays behind; anything of the story still being said
			# is finished first, briskly, and the doorway's lines follow it.
			game.lines = game.lines.filter(func(l): return l.story)
			var base := maxf(time, game._squeeze_backlog())
			for p in game.pending_sfx:
				if p[0] == "latch_near":
					game._play_sfx_now(p[0])   # the door she is opening is the one that unlatched
			game.pending_sfx.clear()
			for l in R02Sim.THRESHOLD_LINES:
				game._insert_line(l[1], base + l[0], true)
			# Phase-lock the breath: the first inhale begins with the 3.4 s line.
			var seek := fposmod(THRESHOLD_BREATH_SEEK - (base - time), BREATH_PERIOD)
			breath_clock = seek
			door_phase = seek
			exhales = 0
			fig_scale = FIGURE_SCALE_STILL
			go_on_said = false
			if mixer.players.has("breath"):
				mixer.players["breath"].seek(seek)
		"turn":
			# She turns round. Nothing more is said in the room.
			game.lines.clear()
			game.cur_text = ""
			game.cur_story = false
			game.subtitle.text = ""
			game.pending_sfx = game.pending_sfx.filter(func(p): return p[0] in ["exhale_near", "motif"])
		"sea_fade", "dread", "log_write":
			pass  # carried by the mix, the room drawing and the logbook reveal

## Base levels for one-shots (dB), and the ones "Soften sudden sounds" turns down.
const SFX_DB := {"spark": -4.0, "sting": -6.0, "latch_far": -8.0, "latch_near": -5.0,
	"door": -6.0, "page": -10.0, "switch": -6.0, "seat": -6.0, "clink": -8.0,
	"knock_glass": -3.0, "dial": -16.0, "clunk": -10.0, "drawer": -9.0, "sign": -8.0, "nib": -14.0,
	"deep": -9.0, "motif": -14.0, "motif_short": -14.0, "exhale_near": -10.0,
	"turn": -14.0, "lock_turn": -7.0, "pin": -12.0, "unpin": -14.0, "thread": -14.0, "stamp": -6.0,
	"stamp_dry": -10.0, "seal": -9.0, "oilskin": -8.0, "pen_far": -10.0, "baro_tap": -12.0,
	"paper_lift": -14.0, "clock_stop": -9.0, "photo_turn": -14.0}
const SFX_SOFT := ["spark", "latch_near", "sting", "door", "knock_glass", "clunk", "deep", "exhale_near",
	"lock_turn", "seal"]

## "Soften sudden sounds" takes 12 dB off these, and 8 off the knock.
const SFX_SOFT_CUT := {"knock_glass": 8.0}




func on_sfx(id: String) -> void:
	if id == "pin":
		if photo_armed:
			photo_armed = false   # the photograph is pinned with the sound of its pin
		elif office.view == "board" and office.state.board_pins.size() >= 2 and game:
			game._play_sfx_now("thread")   # the thread draws tight to the new pin
	if id == "oilskin":
		oil_hush_done = false
	if id == "knock_glass":
		# The marks on the glass appear with the knock, whether or not the file loads.
		palms_armed = true
		palms_k = 0.0 if motion else 1.0

func apply_instantly() -> void:
	var s := office.stage()
	last_stage = s
	last_facing = office.facing
	_snap_light()
	torch.color = TORCH_COLD if s >= 2 else TORCH_WARM
	tilt_k = 1.0 if _tilted() else 0.0
	palms_k = 1.0 if _palms_on() else 0.0
	palms_armed = palms_k > 0.0
	contours_k = 1.0
	away_alpha.clear()
	eye_x = 640.0
	zoom_k = 1.0 if _at_threshold() else 0.0
	push_k = zoom_k
	transform = _zoom_xform()
	deep.transform = transform
	if office.view == "threshold" and threshold_t == 0.0 and not threshold_armed:
		# A load into the doorway (R02Sim.resume_view): its chain plays again from the first beat.
		play_fx("threshold")
	if mixer.players.has("hum"):
		mixer.players["hum"].pitch_scale = 1.0 - 0.012 * (s if not office.state.finished else 1)

## The palms are on the glass from the knock on (a jump to the wet seat counts as heard).
func _palms_on() -> bool:
	return office.has_seen("knock") or office.state.seat_wet

func redraw() -> void:
	room.queue_redraw()
	deep.queue_redraw()
	close.queue_redraw()

# ---------------------------------------------------------------------------
# logbook reveal (presentation only)
# ---------------------------------------------------------------------------

func _in_hand_rows() -> Array:
	var out := []
	for e in office.log_rows():
		if e[4]:
			out.append(e)
	return out

func _in_hand_count() -> int:
	return _in_hand_rows().size()

func _reveal_active() -> bool:
	return office.view == "logbook" and office.state.p01_complete and motion \
		and log_shown_hand < _in_hand_count()

## Which in-hand row (index into `rows`) a subtitle reads out, or -1: a row whose note it
## quotes word for word, or one named in LOG_CUES.
static func log_cue_row(text: String, rows: Array) -> int:
	for i in rows.size():
		var note: String = rows[i][3]
		if note in text:
			return i
		for frag in LOG_CUES:
			if LOG_CUES[frag] == note and frag in text:
				return i
	return -1

## Characters per second the row being written needs so that it, and every row after it that
## a queued subtitle reads out, is written REVEAL_LEAD before that subtitle is due.
## `cues` is [[in-hand row, seconds until due], ...]. Never slower than REVEAL_CPS.
static func reveal_rate(rows: Array, shown: int, written: float, cues: Array) -> float:
	var rate := REVEAL_CPS
	for cue in cues:
		var j: int = cue[0]
		if j < shown or j >= rows.size():
			continue
		var chars := float((rows[shown][3] as String).length()) - written
		for k in range(shown + 1, j + 1):
			chars += float((rows[k][3] as String).length())
		var room := float(cue[1]) - REVEAL_LEAD - REVEAL_GAP * float(j - shown)
		rate = maxf(rate, chars / maxf(0.05, room))
	return rate

## The queued subtitles that read out an in-hand row: [[row, seconds until due], ...].
func _reveal_cues(rows: Array) -> Array:
	var out := []
	if game == null:
		return out
	for l in game.lines:
		var j := log_cue_row(l.text, rows)
		if j >= 0:
			out.append([j, float(l.due) - time])
	return out

func _tick_reveal(dt: float) -> void:
	if office.view != "logbook" or not office.state.p01_complete:
		return
	var rows := _in_hand_rows()
	if log_shown_hand >= rows.size():
		return
	if not motion:
		log_shown_hand = rows.size()
		reveal_t = 0.0
		reveal_n = 0.0
		return
	# A subtitle that reads a row out never shows before that row is written: if it is up
	# (the player brought it forward), the row and every row before it are finished now.
	if game and game.cur_text != "":
		var j := log_cue_row(game.cur_text, rows)
		if j >= log_shown_hand:
			log_shown_hand = j + 1
			reveal_t = 0.0
			reveal_n = 0.0
			if log_shown_hand >= rows.size():
				return
	var text: String = rows[log_shown_hand][3]
	if reveal_n < float(text.length()):
		reveal_n = minf(float(text.length()),
			reveal_n + dt * reveal_rate(rows, log_shown_hand, reveal_n, _reveal_cues(rows)))
		reveal_t = 0.0
		return
	# Written: a short pause, shortened when a later row is due to be read out soon.
	reveal_t += dt
	var gap := REVEAL_GAP
	if log_shown_hand + 1 < rows.size() \
			and reveal_rate(rows, log_shown_hand + 1, 0.0, _reveal_cues(rows)) > REVEAL_CPS:
		gap = 0.0
	if reveal_t >= gap:
		log_shown_hand += 1
		reveal_t = 0.0
		reveal_n = 0.0

# ---------------------------------------------------------------------------
# input
# ---------------------------------------------------------------------------



func _hotspots() -> Array:
	return HOTSPOTS_B if office.facing == "B" else HOTSPOTS

func _notice_active() -> bool:
	return notice_t >= 0.0 and notice_t < NOTICE_TIME

func hover_at(p: Vector2) -> String:
	if office.view == "threshold":
		return "continue" if _walk_on_at(p) else ""
	if office.view != "room":
		return ""
	if TURN_RECT.has_point(p):
		return "turn"
	for h in _hotspots():
		if h[1].has_point(p):
			return h[0]
	return ""

func label_for(id: String) -> String:
	if id == "turn":
		return "Entry wall" if office.facing == "A" else "Desk wall"
	if id == "continue" and office.view == "threshold":
		if game and game.hover_id == id:
			return ""   # the view anchors it under the figure's feet (draw_hud), never on it
		return WALK_ON_LABEL
	if office.facing == "B" and game and game.hover_id == id:
		return ""   # the entry wall anchors its names above each object (draw_hud), off its props
	return _hotspot_label(id)

func _hotspot_label(id: String) -> String:
	for h in _hotspots():
		if h[0] == id:
			return h[2]
	return ""

func dev_rects() -> Array:
	var out := [TURN_RECT]
	for h in _hotspots():
		out.append(h[1])
	return out

## Maps a screen point to a room action for the room's current view. "" = nothing.
## The core handles the HUD, Back and the exits first.
## The drawer's reveal chain ("And a photograph." ... the window line) is a story beat: a click
## on the photograph while it plays only advances it, so the photo close-up cannot cut in ahead
## of the reveal (the core otherwise lets close-up controls act in the advancing press).
func consume_click(p: Vector2) -> bool:
	if game and office.view == "drawer" and office.state.drawer_open and PHOTO_RECT.has_point(p) \
			and game.chain_active():
		game.advance()
		return true
	return false

func action_at(p: Vector2) -> String:
	if _notice_active():
		# The arrival hold: any click ends it, and does nothing else.
		notice_t = -1.0
		return ""
	match office.view:
		"end":
			return "end_continue" if _end_button_ready() and END_BUTTON.has_point(p) else ""
		"room":
			if TURN_RECT.has_point(p):
				return "turn"
			for h in _hotspots():
				if h[1].has_point(p):
					return _door_action(h[0])
		"repair":
			if Rect2(260, 582, 370, 126).has_point(p): return "toggle_supply"
			if Rect2(250, 435, 415, 132).has_point(p): return "fit"
			if Rect2(88, 855, 278, 139).has_point(p): return "select_b"
			if Rect2(376, 855, 278, 139).has_point(p): return "select_c"
		"duty", "note":
			if DUTY_CONTRACT.has_point(p):
				if not office.has_seen("contract") and game:
					game._play_sfx_now("paper_lift")   # the contract lifts from under the card
				return "read_contract"
		"board":
			if office.board_solved() and not photo_armed and C_BOARD_PHOTO.has_point(p):
				return "photo"
			for r in C_BOARD_RECTS:
				if r[1].has_point(p):
					return r[0]
		"photo":
			if office.board_solved() and TURN_OVER.has_point(p):
				if game:
					game._play_sfx_now("photo_turn")
				return "turn_over"
			if PHOTO_PRINT.has_point(p):
				return "photo"
		"drawer":
			if office.state.drawer_open:
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
			if not office.state.report_filed:
				for i in 4:
					var r := _rtime_rect(i)
					if Rect2(r.position, Vector2(r.size.x, r.size.y / 2.0)).has_point(p):
						return "rtime_%d" % i
					if Rect2(r.position + Vector2(0, r.size.y / 2.0), Vector2(r.size.x, r.size.y / 2.0)).has_point(p):
						return "rtime_down_%d" % i
			for i in R02Sim.REPORT_FIELDS.size():
				if _report_row(REPORT_FIELD_ROWS[i]).has_point(p):
					return "field_%d" % i
			if not office.state.report_filed and REPORT_SIGN.has_point(p):
				return "file_report"
		"threshold":
			# Two ways out: turn round (the turn tab, or the chair while it is in view), or go
			# on through the doorway once she may. The view leans in on the door here, so the
			# click is taken back into the room's frame. Before she may go on, a click on the
			# doorway does nothing at all: it can never skip to the card.
			if TURN_RECT.has_point(p):
				return "turn"
			p = _zoom_xform().affine_inverse() * p
			if _hotspot_rect("chair").has_point(p):
				return "turn"
			if continue_ready and (_hotspot_rect("door").has_point(p) or DOOR_SLAB.has_point(p)):
				return "continue"
			return ""
	return ""

## At the threshold, once she may go on: the doorway and the corridor painted in it (screen
## point `p`, taken back through the lean) walk her in. The turn tab and the chair turn first.
func _walk_on_at(p: Vector2) -> bool:
	if not continue_ready or TURN_RECT.has_point(p):
		return false
	var q := _zoom_xform().affine_inverse() * p
	if _hotspot_rect("chair").has_point(q):
		return false
	return _hotspot_rect("door").has_point(q) or DOOR_SLAB.has_point(q)

## The doors are ways out once there is somewhere to go: the corridor door leads to the
## chart room from P01 (the sim's exit rules still apply), except when it opens on the
## threshold; the outer door leads to the jetty whenever that exit is open, and the service
## door to the kitchen once the capsule's key has turned in it.
func _door_action(id: String) -> String:
	if game == null:
		return id
	if id == "door" and game.sim.flag("P01") and not (office.state.report_filed \
			and office.state.heard_unlatch and not office.state.finished):
		return "go:R03"
	if id == "outer_door" and game.sim.exit_open("R02", "R01"):
		return "go:R01"
	if id == "service_door" and not office.service_locked() and office.exit_block("R05") == "" \
			and game.sim.exit_open("R02", "R05"):
		return "go:R05"
	return id

func _hotspot_rect(id: String) -> Rect2:
	for h in HOTSPOTS:
		if h[0] == id:
			return h[1]
	return Rect2()


## What a dial shows: [above, current, below]. The top half turns it up, so the digit above
## is where an up click goes; the one below is where a down click goes.

static func dial_digits(v: int) -> Array:
	return [(v + 1) % 10, v, (v + 9) % 10]



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
	if office.facing == "B":
		_draw_entry_wall(room)
		return
	var c := room
	var s := office.stage()
	var phase := _phase()
	var b := _band()
	var ending := office.ending()
	var full := Rect2(Vector2.ZERO, SIZE)
	var base_id := _base_plate()
	c.draw_texture_rect(textures.get(base_id, textures["office_arrival"]), full, false)
	var tilt := deg_to_rad(TILT_DEG) * smoothstep(0.0, 1.0, tilt_k) if _tilted() else 0.0
	if b == 3 and _tex("office_s2"):
		_draw_tipped_panes(c, tilt, "office_s2")   # band 3: the s2 plate's sea, really turned
	if ending == "":
		if office.low_water():
			_draw_full(c, "R02/window_low_water")   # Tide II: the sea out to the lighthouse, and stayed out
		# The window darkens with the story, not with a clock. Painted water must still read.
		c.draw_rect(GLASS, Color(0.04, 0.06, 0.12, DUSK.get(phase, 0.12)))
		var sea_moves: bool = ((s >= 2 and not office.state.finished) or (b >= 0 and b <= 4)) \
			and not office.low_water()
		if sea_moves:
			# The sea outside keeps moving, silently: a slow bruise-violet sheen on the water.
			var sheen := 0.10 + (0.05 * sin(time * 0.8) if motion else 0.0)
			_draw_sea_sheen(c, tilt, Color(BRUISE, sheen))
		# Everything out on the water tips with the sea; the frame stays square.
		c.draw_set_transform_matrix(_tilt_xform(tilt))
		if (s >= 2 and not office.state.finished) or (b >= 0 and b <= 2):
			_draw_ninth_piling(c, s)
		if office.tenth_piling_shown():
			_draw_full(c, "R02/window_tenth_piling")   # the report's tenth: a post past the jetty's end
		if b == 3:
			_draw_late_wave(c, tilt)
		if b >= 4:
			_draw_eye(c, tilt)   # above the dusk wash: Ada says she can see it, so the player must too
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
		if b >= 1:
			_draw_rain(c, b)
		if office.view == "threshold" and _window_in_frame():
			_draw_window_sea(c, threshold_sea_now())
		_draw_palms(c)
		_draw_away_one(c, "window")
	elif ending == "sever" and _tex("R02/window_day"):
		c.draw_texture_rect(_tex("R02/window_day"), full, false)
	elif ending == "continue":
		# The sea has risen to the glass: a flat mass, its skin across the top row.
		var drowned := _tex("R02/window_drowned")
		if drowned == null:
			drowned = _tex("R02/window_surface")
		if drowned:
			c.draw_texture_rect(drowned, full, false)
	if b >= 4 or ending == "continue":
		# The high-water mark from band 4: a salt crust with a wet band under it, a mark on
		# the wall (not a seam in the plate), darker where it crosses the paper and the coat.
		_draw_full(c, "R02/tide_mark")
	if b >= 2 or ending == "continue":
		var damp := _tex("R02/damp_sill")
		if damp:
			c.draw_texture_rect(damp, full, false)
		_draw_full(c, "R02/damp_window_hard")   # band 2: the damp under the sill, as one hard shape
	if s >= 1 and ending != "sever":
		_draw_wrong_shadow(c, s)   # on the wall, so the lamp stands in front of it
	for id in ["door", "stove", "puddle", "coat"]:
		_draw_away_one(c, id)
	if office.look_away("door"):
		# The seep from the corridor side, as a hard flat tongue on the boards (away_door).
		_draw_full(c, "R02/door_seep_hard", away_alpha.get("door", 1.0))
	c.draw_texture_rect(textures["lamp_off"], Rect2(242, 469, 192, 288), false)
	if office.state.p01_complete:
		c.draw_texture_rect(textures["lamp_light"], Rect2(242, 469, 192, 288), false)
	_draw_away_one(c, "mug")   # the brimming mug stands in front of the lamp's foot
	c.draw_texture_rect(textures["spares_tray"], Rect2(341, 666, 128, 64), false)
	if s >= 2:
		_draw_map_pencil(c, s)
	if b >= 6:
		_draw_hook_tags(c)
	if office.state.seat_wet and ending != "sever":
		_draw_hook9_wet(c)
	if b >= 6:
		_draw_hook_tag(c)
	_draw_coat_weight(c, s)
	if office.state.seat_wet and not office.state.report_filed:
		_draw_report_edge(c)
	_draw_prints(c, s)
	_draw_drawer_gap(c)
	if _at_threshold():
		_draw_off_plate(c)   # the doorway draws on its own layer; the push sees past the plate
	elif office.state.report_filed and not office.state.finished:
		c.draw_rect(Rect2(1228, 168, 6, 736), Color(0.01, 0.01, 0.02, 0.85))   # unlatched, ajar
	var vig: float = VIGNETTE.get(phase, 0.0)
	if phase == "t1x":
		vig += 0.06 * _env_drawn()
	if _at_threshold():
		vig = 0.12   # the room stays readable; the corridor carries the dark
	_draw_vignette(c, vig)
	_draw_notice(c)

## The desk wall's plate for the phase (reconciliation D8): the arrival plate through Tide I
## and band 0; rain at 1-2; s2 at 3; s3 at 4-6; ominous at 7. The endings use the rain or the
## band-7 plate with their own window.
func _base_plate() -> String:
	match office.ending():
		"sever":
			return "office_rain"
		"continue":
			return "office_ominous"
	var b := _band()
	if b <= 0:
		return "office_arrival"
	if b <= 2:
		return "office_rain"
	if b == 3:
		return "office_s2"
	if b <= 6:
		return "office_s3"
	return "office_ominous"

## Rain on the glass: quick at bands 1-2, slow at 3-4 (rain falling slower than rain falls),
## and still from 5 (rain seen, not heard). Motion off: the first frame, still.
func _draw_rain(c: Node2D, b: int) -> void:
	if b >= 5:
		_draw_rain_still(c)
		return
	var frame := 0
	if motion:
		var period := 0.12 if b <= 2 else 0.36
		frame = int(floor(time / period)) % 3
	var tex := _tex("rain_%d" % frame)
	if tex:
		c.draw_texture_rect(tex, Rect2(Vector2.ZERO, SIZE), false, Color(1, 1, 1, 0.85))

## True while any of the window glass is on screen at the current lean.
func _window_in_frame() -> bool:
	return Rect2(Vector2.ZERO, SIZE).intersects(_zoom_xform() * GLASS)

## The office window's sea at the threshold (R02Sim.threshold_sea), in room space. Every fill
## is a pane or part of one, so nothing reaches past the glass; the sash bars stay the plate's.
## 0: as painted. 1 drained: bare mud from the horizon down, the jetty's pilings and the ninth
## standing in it. 2 flooded: the skin at the second sash bar, every piling and the deck under.
## `tint` multiplies every colour (the inset on the unlit layer); `a` is its opacity.
func _draw_window_sea(c: CanvasItem, sea: int, tint := Color.WHITE, a := 1.0) -> void:
	if sea <= 0:
		return
	var mud := Color(WINDOW_MUD * tint, a)
	var stub := Color(STUB * tint, a)
	var skin := Color(WATER_SKIN * tint, a)
	var water := Color(WATER_TOP * tint, a)
	for pane in PANES:
		var r: Rect2 = pane
		if sea == 1:
			var bed := Rect2(r.position.x, maxf(r.position.y, WINDOW_HORIZON), r.size.x, 0.0)
			bed.size.y = r.end.y - bed.position.y
			if bed.size.y <= 0.0:
				continue
			c.draw_rect(bed, mud)
			for x in WINDOW_PILINGS:
				var post := Rect2(x - 3.5, WINDOW_HORIZON - 6.0, 7.0, WINDOW_MUD_LOW - WINDOW_HORIZON + 6.0)
				post = post.intersection(r)
				if post.has_area():
					c.draw_rect(post, stub)
			var ninth := Rect2(612, 446, 9, WINDOW_MUD_LOW - 446.0).intersection(r)
			if ninth.has_area():
				c.draw_rect(ninth, stub)
			c.draw_line(Vector2(r.position.x, WINDOW_HORIZON), Vector2(r.end.x, WINDOW_HORIZON), skin, 1.5)
		else:
			var top := maxf(r.position.y, WINDOW_FLOOD_Y)
			if top >= r.end.y:
				continue
			c.draw_rect(Rect2(r.position.x, top, r.size.x, r.end.y - top), water)
			if WINDOW_FLOOD_Y >= r.position.y:
				c.draw_line(Vector2(r.position.x, WINDOW_FLOOD_Y), Vector2(r.end.x, WINDOW_FLOOD_Y), skin, 2.0)

## The inset's opacity: it comes in over the end of the push (the room's own window has left
## the frame by then); with Motion off the push snaps, and it is simply there.
func threshold_inset_alpha() -> float:
	if not _at_threshold():
		return 0.0
	if not motion:
		return 1.0
	return smoothstep(0.55, 0.95, smoothstep(0.0, 1.0, push_k))

## The office window set into the coat-side wall at the threshold (screen space, on the deep
## layer): the same plate's window and the same sea as the room's, drawn as texture regions
## and pane rects inside THRESHOLD_INSET_SRC only, so it is clipped to its own frame.
func _draw_threshold_inset(c: Node2D) -> void:
	var a := threshold_inset_alpha()
	var tex: Texture2D = textures.get(_base_plate(), textures.get("office_arrival"))
	if a <= 0.0 or tex == null:
		return
	var src := THRESHOLD_INSET_SRC
	var k := THRESHOLD_INSET.size / src.size
	var map := Transform2D(0.0, k, 0.0, THRESHOLD_INSET.position - src.position * k)
	var to_screen := _zoom_xform().affine_inverse()
	c.draw_set_transform_matrix(to_screen)
	c.draw_rect(THRESHOLD_INSET.grow(10.0), Color(INK, a))   # an ink mount in the wall
	c.draw_set_transform_matrix(to_screen * map)
	c.draw_texture_rect_region(tex, src, src, Color(INSET_TINT, a))
	var tenth := _tex("R02/window_tenth_piling")
	if office.tenth_piling_shown() and tenth:
		c.draw_texture_rect_region(tenth, src, src, Color(INSET_TINT, a))
	c.draw_rect(GLASS, Color(0.04, 0.06, 0.12, 0.5 * DUSK.get(_phase(), 0.12) * a))
	var sea := threshold_sea_now()
	if sea == 0 and office.stage() >= 2 and not office.state.finished:
		_draw_ninth_piling(c, office.stage())
	_draw_window_sea(c, sea, INSET_TINT, a)
	c.draw_set_transform_matrix(to_screen)
	c.draw_rect(THRESHOLD_INSET, Color(CORRIDOR_GAP, a), false, 2.0)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## Past the plate's right edge, which only the push-in sees: the door's right casing, a
## contour, then the wall and wainscot, flat, matching the plate.
func _draw_off_plate(c: Node2D) -> void:
	var x0 := SIZE.x
	c.draw_rect(Rect2(x0, -600, 28, SIZE.y + 1200), OFF_CASING)
	c.draw_rect(Rect2(x0 + 28, -600, 600, 580 + 600), OFF_WALL)
	c.draw_rect(Rect2(x0 + 28, 580, 600, 4), INK)
	c.draw_rect(Rect2(x0 + 28, 584, 600, SIZE.y + 600 - 584), OFF_WAINSCOT)
	c.draw_line(Vector2(x0 + 28, -600), Vector2(x0 + 28, SIZE.y + 600), INK, 2.5)

## From the wet seat until it is filed, the closure report's ruled edge shows under the duty
## card's clip: the desk has changed, and it can be seen without a click.
func _draw_report_edge(c: Node2D) -> void:
	var cream := Color("e9e1cc")
	var form := PackedVector2Array([Vector2(744, 708), Vector2(896, 704), Vector2(899, 728), Vector2(747, 731)])
	c.draw_colored_polygon(form, cream)
	c.draw_polyline(form + PackedVector2Array([form[0]]), INK, 1.5, true)
	for i in 3:
		var y0 := 713.0 + i * 5.5
		c.draw_line(Vector2(752, y0 - i * 0.1), Vector2(890, y0 - 3.0 - i * 0.1), Color(INK, 0.8), 1.0, true)
	c.draw_line(Vector2(792, 706), Vector2(793, 730), Color(INK, 0.8), 1.0, true)   # the form's column rule

## From band 5 the rain has stopped falling and hangs where it was: one fixed set of short
## pale dashes in the glass, seeded, never advancing, whatever Motion says.
func _draw_rain_still(c: Node2D) -> void:
	var g := RandomNumberGenerator.new()
	g.seed = 5005
	var col := Color(Color("c9d3da"), 0.7)
	for pane in PANES:
		var r: Rect2 = pane
		var n := int(r.size.x * r.size.y / 900.0)
		for i in n:
			var p := Vector2(g.randf_range(r.position.x + 3, r.end.x - 3), g.randf_range(r.position.y + 3, r.end.y - 12))
			c.draw_line(p, p + Vector2(-1.2, g.randf_range(5.0, 9.0)), col, 1.5)

## Band 3: a pale crest crosses the lower pane once a loop, a beat before its sound. It follows
## the late_wave loop's own playhead. Motion off: drawn still, mid-pane.
func _draw_late_wave(c: Node2D, tilt: float) -> void:
	var lo: Rect2 = PANES[6]
	var k := 0.5
	var a := 0.55
	if motion:
		var phase := fmod(time, WAVE_PERIOD)
		var p: AudioStreamPlayer = mixer.players.get("late_wave")
		if p and p.playing:
			phase = fmod(p.get_playback_position(), WAVE_PERIOD)
		var u := (phase - WAVE_AT) / WAVE_SWEEP
		if u < 0.0 or u > 1.3:
			return
		k = clampf(u, 0.0, 1.0)
		a = 0.6 * (1.0 - smoothstep(0.9, 1.3, u))
	var y := lerpf(HORIZON_PIVOT.y + 6.0, lo.end.y - 6.0, k)
	var pane := _tilt_xform(tilt).affine_inverse() * PackedVector2Array([lo.position,
		Vector2(lo.end.x, lo.position.y), lo.end, Vector2(lo.position.x, lo.end.y)])
	var crest := PackedVector2Array()
	for i in 25:
		var x := lerpf(lo.position.x - 40.0, lo.end.x + 40.0, i / 24.0)
		crest.append(Vector2(x, y + 3.0 * sin(x * 0.045)))
	for part in Geometry2D.intersect_polyline_with_polygon(crest, pane):
		if part.size() >= 2:
			c.draw_polyline(part, Color(0.88, 0.93, 0.95, a), 3.0, true)
			c.draw_polyline(part, Color(0.88, 0.93, 0.95, a * 0.35), 8.0, true)

## Her settings and her measurements, stamped on brass tags on hooks 1-8 (band 6 on).
## Pale card tags, ink words: the setting's name over a rule, the figure large beneath it.
func _draw_hook_tags(c: Node2D) -> void:
	var tex := _tex("R02/hook_tags_large")
	if tex:
		c.draw_texture_rect(tex, Rect2(Vector2.ZERO, SIZE), false)
	for i in HOOK_X.size():
		var cx: float = HOOK_X[i]
		var top: float = HOOK_TAG_TOPS[i % 2]
		for row in 2:
			var word: String = HOOK_TAGS[i][row]
			var size := 15 if row == 0 else 25
			var room_w := HOOK_TAG_W - 10.0
			var w := serif.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			while w > room_w and size > 9:
				size -= 1
				w = serif.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			c.draw_string(serif, Vector2(cx - w / 2.0, top + (21.0 if row == 0 else 47.0)), word,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)

## The ninth hook is wet again from the wet seat on: a sheen on the brass, and a drip.
func _draw_hook9_wet(c: Node2D) -> void:
	var sheen := Color(0.86, 0.93, 0.96, 0.7)
	c.draw_polyline(PackedVector2Array([HOOK9 + Vector2(-2, 6), HOOK9 + Vector2(-3, 22),
		HOOK9 + Vector2(-1, 36), HOOK9 + Vector2(5, 44)]), sheen, 2.0, true)
	c.draw_circle(HOOK9 + Vector2(-3, 2), 2.5, sheen)
	var tip := HOOK9 + Vector2(4, 50)
	if _band() >= 6:
		tip = Vector2(HOOK9_TAG.get_center().x, HOOK9_TAG.end.y)   # it drips off the tag now
	var drop := tip
	if motion:
		var t := fmod(time, 2.2)
		drop = tip + Vector2(0, 0.0 if t < 1.4 else 260.0 * pow(t - 1.4, 2))
	if drop.y < 700.0:
		c.draw_colored_polygon(_ellipse(drop + Vector2(0, 3), 2.6, 3.6, 10), Color(0.80, 0.88, 0.93, 0.85))
	# A dark wet run down the wall under it.
	c.draw_line(tip + Vector2(0, 6), tip + Vector2(1, 40), Color(0.10, 0.14, 0.18, 0.28), 3.0, true)

## The drawer stands a finger open once she has opened it; what is in it follows the print.
func _draw_drawer_gap(c: Node2D) -> void:
	if not office.state.drawer_open:
		return
	var id := "R02/drawer_gap"
	if office.board_solved():
		id = "R02/drawer_gap_empty"
	elif office.band() >= 1 and office.state.finished:
		id = "R02/drawer_gap_turned" if office.photo_variant() == "turned" else "R02/drawer_gap_after"
	var tex := _tex(id)
	if tex:
		c.draw_texture_rect(tex, Rect2(Vector2.ZERO, SIZE), false)

## The arrival hold: everything outside the change dims a little, then lets go.
func _draw_notice(c: Node2D) -> void:
	if not _notice_active():
		return
	var k := 1.0
	if motion:
		k = minf(clampf(notice_t / 0.3, 0.0, 1.0), clampf((NOTICE_TIME - notice_t) / 0.3, 0.0, 1.0))
	var col := Color(0, 0, 0, 0.25 * k)
	var r := notice_rect.grow(40).intersection(Rect2(Vector2.ZERO, SIZE))
	c.draw_rect(Rect2(0, 0, SIZE.x, r.position.y), col)
	c.draw_rect(Rect2(0, r.end.y, SIZE.x, SIZE.y - r.end.y), col)
	c.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), col)
	c.draw_rect(Rect2(r.end.x, r.position.y, SIZE.x - r.end.x, r.size.y), col)

## One look-away change (office.look_away), as its painted overlay, faded in if it is new.
## The coat's is gone in the endings: it is an ordinary coat again.
func _draw_away_one(c: Node2D, id: String) -> void:
	if not office.look_away(id) or (id == "coat" and office.ending() != ""):
		return
	var tex := _tex("away_" + id)
	if tex == null:
		return
	c.draw_texture_rect(tex, Rect2(Vector2.ZERO, SIZE), false, Color(1, 1, 1, away_alpha.get(id, 1.0)))

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
	var band_k := 1.0 - 0.08 * env if motion else 1.0
	var pupil_k := 1.0 - 0.3 * env if motion else 1.0
	var lo: Rect2 = PANES[6]
	var pane := _tilt_xform(tilt).affine_inverse() * PackedVector2Array([lo.position,
		Vector2(lo.end.x, lo.position.y), lo.end, Vector2(lo.position.x, lo.end.y)])
	var centre := Vector2(eye_x, 502)
	for band in [[260.0, 19.0, 0.12], [190.0, 14.0, 0.19], [120.0, 9.0, 0.28]]:
		var ell := _ellipse(centre, band[0] * band_k, band[1], 48)
		for poly in Geometry2D.intersect_polygons(ell, pane):
			c.draw_colored_polygon(poly, Color(0.62, 0.74, 0.74, band[2]))
	c.draw_colored_polygon(_ellipse(centre, 23.0 * pupil_k, 3.0, 24), Color(0.02, 0.03, 0.05, 0.6))

func _draw_ninth_piling(c: Node2D, _s: int) -> void:
	if office.state.drawer_open:
		c.draw_rect(Rect2(590, 436, 14, 92), PILING_COL)
		c.draw_circle(Vector2(597, 436), 7, PILING_COL)
	else:
		c.draw_rect(Rect2(612, 452, 9, 64), PILING_COL)

## Three hands pressed to the outside of the glass, low down, below the horizon.
## They are on the glass, not on the sea, so they do not tip.

func _draw_palms(c: Node2D) -> void:
	if palms_k <= 0.0 or not _palms_on():
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
	if office.state.contours_seen:
		_draw_contours(c)
	var pencil := Color(0.25, 0.25, 0.28, 0.8)
	c.draw_line(Vector2(352, 298), Vector2(352, 342), pencil, 2.5)
	c.draw_string(hand, Vector2(346, 364), "9", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, pencil)
	if office.state.seat_wet:
		c.draw_line(Vector2(372, 318), Vector2(372, 354), Color(0.09, 0.10, 0.12, 0.85), 3.0)
	if office.state.soundings_heard:
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
	var r := HOOK9_TAG
	var eye := Vector2(r.get_center().x, r.position.y + 7)
	c.draw_line(HOOK9 + Vector2(0, 4), eye, BRICK, 2.6, true)   # tied to the hook, like the others
	c.draw_rect(r, Color("e6dfca"))
	c.draw_rect(r, INK, false, 2.0)
	c.draw_circle(eye, 3.4, BRASS.darkened(0.2))
	c.draw_arc(eye, 3.4, 0, TAU, 12, INK, 1.0)
	var w := hand.get_string_size("A.M.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	c.draw_string(hand, Vector2(r.get_center().x - w / 2.0, r.end.y - 12), "A.M.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		BLUE_INK)

## The oilskin fills out at the shoulders, as if someone were standing inside it.

func _draw_coat_weight(c: Node2D, _s: int) -> void:
	if office.ending() != "" or office.look_away("coat"):
		return   # an ordinary coat again; or the painted one, filled, hood up
	var a := 0.0
	var b := _band()
	if b >= 4:
		a = 0.55
	elif b >= 1:
		a = 0.42
	elif office.state.log_rewritten:
		a = 0.30
	if a <= 0.0:
		return
	if motion:
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
	if b >= 4:
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
		if motion:
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
	if s >= 3:
		# Behind the sitter, the chair back stays one solid shape.
		c.draw_colored_polygon(PackedVector2Array([sh.call(Vector2(561, 622)), sh.call(Vector2(728, 622)),
			sh.call(Vector2(728, 684)), sh.call(Vector2(561, 684))]), Color(SHADOW_COL, 0.42))
		return
	# Stages 1-2: the chair's own back, sheared: a top rail, four spindles, the seat edge.
	# The parts abut and never overlap, so the shadow is one even tone.
	var col := Color(SHADOW_COL, 0.45)
	var parts := [Rect2(561, 622, 167, 12), Rect2(553, 676, 183, 8)]
	for x in [561.0, 614.0, 667.0, 720.0]:
		parts.append(Rect2(x, 634, 8, 42))
	for r in parts:
		c.draw_colored_polygon(PackedVector2Array([sh.call(r.position), sh.call(Vector2(r.end.x, r.position.y)),
			sh.call(r.end), sh.call(Vector2(r.position.x, r.end.y))]), col)

func _arc_pts(center: Vector2, rx: float, ry: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 13:
		var ang := lerpf(a0, a1, k / 12.0)
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts

func _draw_prints(c: Node2D, s: int) -> void:
	if s >= 2 and (office.state.prints_seen or s >= 3):
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

## The open door, and the corridor behind it: deeper than the building, breathing. Drawn
## as crisp flat shapes (casings, water, mud, a silhouette), so the push-in stays sharp.
## Deep layer, unlit: what is down there makes its own light.

func _draw_door_opening(c: Node2D) -> void:
	var k := 1.0
	if motion:
		k = smoothstep(0.0, 1.0, clampf(threshold_t / 2.2, 0.0, 1.0))
	var slab := DOOR_SLAB
	var open := Rect2(slab.position, Vector2(slab.size.x * k, slab.size.y))
	c.draw_rect(open, CORRIDOR_GAP)
	if k <= 0.0:
		return
	var clip := _rect_poly(open)
	var tide := _tide_drawn()
	var far := _draw_casings(c, open)
	_draw_far_end(c, far, clip, tide.x)
	_draw_corridor_floor(c, clip, tide.x)
	var skin := _draw_corridor_water(c, clip, tide)
	_draw_threshold_inset(c)
	# The figure after the floor, the water and the window: nothing can be drawn over it.
	_draw_threshold_figure(c, clip)
	for seg in skin:
		c.draw_line(seg[0], seg[1], WATER_SKIN, _px(1.5))
	if k < 1.0:
		return
	# On the inhale, a wet gleam reaches out of the doorway across the floor toward the desk.
	var env := door_env if _breath_held() else _env_drawn()
	var reach := 260.0 * env
	if reach < 2.0:
		return
	c.draw_colored_polygon(PackedVector2Array([Vector2(1228, 900), Vector2(1228, 920),
		Vector2(1228 - reach, 916), Vector2(1228 - reach, 906)]), Color(0.70, 0.76, 0.84, 0.08 * env))

## A width in screen pixels, in room units at the current lean.
func _px(w: float) -> float:
	return w / maxf(_zoom_xform().get_scale().x, 0.01)

static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

## The doorway's cross-section at depth scale f (1 = the door itself), shrunk toward VP.
static func corridor_section(f: float) -> Rect2:
	return Rect2(VP + (DOOR_SLAB.position - VP) * f, DOOR_SLAB.size * f)

## Fills `poly` clipped to `clip`.
func _fill_clipped(c: Node2D, poly: PackedVector2Array, clip: PackedVector2Array, col: Color) -> void:
	for part in Geometry2D.intersect_polygons(poly, clip):
		if part.size() >= 3 and not Geometry2D.triangulate_polygon(part).is_empty():
			c.draw_colored_polygon(part, col)

## Nested casings toward VP, teal and storm navy by turns, each 0.86 of the last, with dark
## corridor between them. Clipped to the opened part of the doorway. Returns the far end.
func _draw_casings(c: Node2D, open: Rect2) -> Rect2:
	var f := 1.0
	var i := 0
	var far := corridor_section(CORRIDOR_END)
	while f > CORRIDOR_END:
		var r := corridor_section(f)
		var band := r.intersection(open)
		if band.has_area():
			c.draw_rect(band, CORRIDOR_TEAL if i % 2 == 0 else CORRIDOR_NAVY)
		far = r.grow(-maxf(12.0 * f, 1.0))
		var inner := far.intersection(open)
		if inner.has_area():
			c.draw_rect(inner, CORRIDOR_GAP)
		f *= 0.86
		i += 1
	return far

## The corridor's end. When the tide goes out it opens on the drained Sound, as far as the
## lighthouse: a tiny rock and a dark tower, on the horizon at VP.
func _draw_far_end(c: Node2D, far: Rect2, clip: PackedVector2Array, drain: float) -> void:
	if drain <= 0.0:
		return
	var sky := Rect2(far.position, Vector2(far.size.x, VP.y - far.position.y))
	_fill_clipped(c, _rect_poly(sky), clip, Color(CORRIDOR_SKY, drain))
	_fill_clipped(c, _rect_poly(Rect2(far.position.x, VP.y, far.size.x, far.end.y - VP.y)), clip, Color(MUD, drain))
	var rock := PackedVector2Array()
	for j in 13:
		var a := PI + PI * j / 12.0
		rock.append(VP + Vector2(cos(a) * 7.0, sin(a) * 2.6))
	_fill_clipped(c, rock, clip, Color(FIGURE_INK, drain))
	_fill_clipped(c, _rect_poly(Rect2(VP.x - 1.2, VP.y - 11.0, 2.4, 10.0)), clip, Color(FIGURE_INK, drain))
	_fill_clipped(c, _rect_poly(Rect2(VP.x - 1.8, VP.y - 12.2, 3.6, 1.4)), clip, Color(FIGURE_INK, drain))

## The corridor floor: wet mud, five piling stubs walking off toward the lighthouse. Under
## the water, so it only shows where the tide has gone out.
func _draw_corridor_floor(c: Node2D, clip: PackedVector2Array, drain: float) -> void:
	if drain <= 0.0:
		return
	var near := corridor_section(1.0)
	var far := corridor_section(CORRIDOR_END)
	var floor_poly := PackedVector2Array([Vector2(near.position.x, near.end.y), near.end,
		far.end, Vector2(far.position.x, far.end.y)])
	_fill_clipped(c, floor_poly, clip, MUD)
	for st in STUBS:
		var f: float = st[1]
		var base := Vector2(VP.x + st[0] * f, VP.y + (DOOR_SLAB.end.y - VP.y) * f)
		var w := 18.0 * f
		var h := 110.0 * f
		_fill_clipped(c, _rect_poly(Rect2(base.x - w / 2.0, base.y - h, w, h)), clip, STUB)
		_fill_clipped(c, _ellipse(Vector2(base.x, base.y - h), w / 2.0, w * 0.22, 12), clip, STUB.lightened(0.12))

## The water in the corridor: a dark body (convex hull of its near and far faces) and its
## surface, both flat. Drained, its near edge pulls back toward the far end. Returns the
## surface skin's segments, drawn last so they cross whatever stands in it.
func _draw_corridor_water(c: Node2D, clip: PackedVector2Array, tide: Vector2) -> Array:
	var f_near := lerpf(1.0, CORRIDOR_END, clampf(tide.x, 0.0, 1.0))
	if f_near <= CORRIDOR_END + 0.002:
		return []
	var h := clampf(tide.y, 0.0, 1.0)
	var near := corridor_section(f_near)
	var far := corridor_section(CORRIDOR_END)
	var yn := near.end.y - h * near.size.y
	var yf := far.end.y - h * far.size.y
	var pts := PackedVector2Array([Vector2(near.position.x, yn), Vector2(near.end.x, yn), near.end,
		Vector2(near.position.x, near.end.y), Vector2(far.position.x, yf), Vector2(far.end.x, yf), far.end,
		Vector2(far.position.x, far.end.y)])
	_fill_clipped(c, Geometry2D.convex_hull(pts), clip, Color(CORRIDOR_NAVY, 0.8))
	var surface := PackedVector2Array([Vector2(near.position.x, yn), Vector2(near.end.x, yn),
		Vector2(far.end.x, yf), Vector2(far.position.x, yf)])
	if yn - yf > 0.5:
		_fill_clipped(c, surface, clip, WATER_TOP)   # seen from above only: below her eye
	# The waterline on every casing it reaches, so its height reads all the way down.
	var f := 0.86
	while f > CORRIDOR_END:
		if f < f_near:
			var r := corridor_section(f)
			var y := r.end.y - h * r.size.y
			for part in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([
					Vector2(r.position.x, y), Vector2(r.end.x, y)]), clip):
				if part.size() >= 2:
					c.draw_line(part[0], part[part.size() - 1], Color(WATER_SKIN, 0.55), _px(1.5))
		f *= 0.86
	var out := []
	for part in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([
			Vector2(near.position.x, yn), Vector2(near.end.x, yn)]), clip):
		if part.size() >= 2:
			out.append([part[0], part[part.size() - 1]])
	return out

## Someone standing at the far end: a flat navy-black silhouette with a pale rim, its head
## on the horizon (her own eye height), a long body. No eyes. It stands nearer each exhale.
func _draw_threshold_figure(c: Node2D, clip: PackedVector2Array) -> void:
	var a := threshold_figure_alpha(threshold_t, motion, _breath_held())
	if a <= 0.0:
		return
	var feet := Vector2(VP.x, VP.y + (DOOR_SLAB.end.y - VP.y) * FIGURE_DEPTH)
	var hh := feet.y - VP.y - 1.0   # head to heel
	var sc := fig_scale if motion else FIGURE_SCALE_STILL
	var to_screen := func(u: Vector2) -> Vector2:
		# u in figure units (x across, y up from the heel, both in head-to-heel heights).
		var p := feet + Vector2(u.x * hh, -u.y * hh)
		return VP + (p - VP) * sc
	var head_c := Vector2(0.0, 0.94)
	var head := PackedVector2Array()
	var rim_head := PackedVector2Array()
	for j in 24:
		var t := TAU * j / 24.0
		head.append(to_screen.call(head_c + Vector2(cos(t) * 0.05, sin(t) * 0.06)))
	for j in 19:
		var t := lerpf(-0.25 * PI, 1.25 * PI, j / 18.0)   # over the top, not across the neck
		rim_head.append(to_screen.call(head_c + Vector2(cos(t) * 0.05, sin(t) * 0.06)))
	# A long neck, sloped shoulders, arms hanging past the hips, legs together.
	var half := [Vector2(0.026, 0.885), Vector2(0.03, 0.84), Vector2(0.11, 0.80), Vector2(0.15, 0.76),
		Vector2(0.158, 0.66), Vector2(0.15, 0.44), Vector2(0.138, 0.27), Vector2(0.116, 0.25),
		Vector2(0.104, 0.36), Vector2(0.094, 0.30), Vector2(0.078, 0.0), Vector2(0.014, 0.0), Vector2(0.0, 0.2)]
	var body := PackedVector2Array()
	for u in half:   # down the left side to the crotch
		body.append(to_screen.call(Vector2(-u.x, u.y)))
	for i in range(half.size() - 2, -1, -1):   # and back up the right
		body.append(to_screen.call(half[i]))
	var ink := Color(FIGURE_FILL, a)
	_fill_clipped(c, body, clip, ink)
	_fill_clipped(c, head, clip, ink)
	var rim := Color(WATER_SKIN, a)
	var w := _px(2.0)
	c.draw_polyline(rim_head, rim, w, true)
	c.draw_polyline(body, rim, w, true)

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
# drawing: view B, the entry wall (world space, lit)
# ---------------------------------------------------------------------------

func _entry_plate() -> String:
	if office.ending() == "sever":
		return "R02/entry_wall_day"
	if office.ending() == "continue":
		return "R02/entry_wall_ominous"
	var b := _band()
	if b <= 2:
		return "R02/entry_wall"
	if b <= 6:
		return "R02/entry_wall_damp"
	return "R02/entry_wall_ominous"

## The entry wall's escalation step: the weather band, with the continue ending holding the
## last band's wrongness (the sever ending is the day plate, and steps back to -1).
func _b_step() -> int:
	match office.ending():
		"continue":
			return 7
		"sever":
			return -1
	return _band()

func _outer_glass() -> String:
	if office.ending() == "sever":
		return "R02/outer_glass_day"
	if _b_step() >= 7 and _tex("R02/outer_glass_sea"):
		return "R02/outer_glass_sea"   # the sea stands above the jetty
	if game and game.sim.flag("P05") and not game.sim.flag("P06"):
		return "R02/outer_glass_boat"
	return "R02/outer_glass_%d" % maxi(_band(), 0)

func _draw_entry_wall(c: Node2D) -> void:
	var full := Rect2(Vector2.ZERO, SIZE)
	var plate := _tex(_entry_plate())
	if plate == null:
		plate = _tex("R02/entry_wall")
	if plate:
		c.draw_texture_rect(plate, full, false)
	var step := _b_step()
	if step >= 2 and plate:
		# Bands 2-3 on: the receipt has slid down the boards and been pinned again upside
		# down. The boards it covered come back from the plate itself, two boards along.
		c.draw_texture_rect_region(plate, RECEIPT_PATCH, Rect2(RECEIPT_PATCH.position + Vector2(96, 0),
			RECEIPT_PATCH.size))
		_draw_full(c, "R02/receipt_fallen")
	if _band() == 2 and _tex("R02/b_damp_low"):
		c.draw_texture_rect(_tex("R02/b_damp_low"), full, false)
	if step >= 4:
		_draw_full(c, "R02/entry_wall_s4_stain")   # band 4: the wet climbs off the skirting, hard-edged
	if _back_lamp_on():
		_draw_full(c, "R02/entry_wall_shadow")     # her own shadow, thrown by the lamp behind her
		if step >= 5:
			_draw_full(c, "R02/entry_wall_shadow2")   # and, from band 5, someone taller just behind it
	var glass := _tex(_outer_glass())
	if glass:
		c.draw_texture_rect(glass, Rect2(OUTER_GLASS_AT, glass.get_size()), false)
	if step >= 7:
		_draw_full(c, "R02/outer_door_pour")       # the sea, coming in under the glass
	if office.state.seat_wet and not office.state.finished:
		# The T1X latch: a brass bar across the outer door's lock plate.
		c.draw_rect(LATCH_BAR, BRASS)
		c.draw_rect(LATCH_BAR, BRASS.darkened(0.55), false, 2.0)
		c.draw_line(LATCH_BAR.position + Vector2(4, 4), LATCH_BAR.position + Vector2(LATCH_BAR.size.x - 4, 4),
			Color(BRASS.lightened(0.4), 0.8), 1.5)
		for x in [LATCH_BAR.position.x + 7, LATCH_BAR.end.x - 7]:
			c.draw_circle(Vector2(x, LATCH_BAR.get_center().y), 2.5, BRASS.darkened(0.6))
	if not office.service_locked() and _tex("R02/b_service_open"):
		c.draw_texture_rect(_tex("R02/b_service_open"), full, false)
	var lw := serif.get_string_size("SERVICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	c.draw_string(serif, Vector2(SERVICE_LABEL.get_center().x - lw / 2.0, SERVICE_LABEL.position.y + 22),
		"SERVICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
	_draw_barometer(c)
	_draw_clock(c)
	_draw_board_room(c)
	_draw_vignette(c, VIGNETTE.get(_phase(), 0.0) * 0.6)

## A direction from straight up, clockwise, in degrees.
static func _dir(deg: float) -> Vector2:
	var a := deg_to_rad(deg)
	return Vector2(sin(a), -cos(a))

func _draw_barometer(c: Node2D) -> void:
	for w in BARO_WORDS:
		var p: Vector2 = BARO_C + _dir(w[1]) * 66.0
		var ws := serif.get_string_size(w[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		# The dial's own enamel behind each word, so the scale ticks never cut through it.
		c.draw_rect(Rect2(p + Vector2(-ws.x / 2.0 - 3, -9), Vector2(ws.x + 6, 18)), Color("e0d6bd", 0.95))
		c.draw_string(serif, p + Vector2(-ws.x / 2.0, 5), w[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	if _band() >= 4 or office.ending() != "":
		# Someone has scratched a mark on the bare brass past STORMY.
		var d := _dir(-150.0)
		var n := d.orthogonal()
		c.draw_line(BARO_C + d * 70.0, BARO_C + d * 86.0, Color(INK, 0.85), 1.5, true)
		c.draw_line(BARO_C + d * 71.0 + n * 1.5, BARO_C + d * 84.0 + n * 2.5, Color(INK, 0.5), 1.0, true)
	var nd := float(office.needle())
	var navy := Color("1b2a44")
	if _band() == 7 or office.ending() == "continue":
		# Bent: the last 18 px kinked over by 25 degrees.
		var knee := BARO_C + _dir(nd) * 60.0
		c.draw_line(BARO_C, knee, navy, 3.0, true)
		c.draw_line(knee, knee + _dir(nd + 25.0) * 18.0, navy, 3.0, true)
	else:
		c.draw_line(BARO_C, BARO_C + _dir(nd) * 78.0, navy, 3.0, true)
	c.draw_line(BARO_C, BARO_C - _dir(nd) * 14.0, navy, 4.0, true)
	c.draw_circle(BARO_C, 6.0, BRASS.darkened(0.3))
	c.draw_circle(BARO_C, 3.0, navy)

func _draw_clock(c: Node2D) -> void:
	var t: Array = office.clock()
	var h := float(t[0])
	var m := float(t[1])
	var running: bool = t[2]
	c.draw_line(CLOCK_C, CLOCK_C + _dir((fmod(h, 12.0) + m / 60.0) * 30.0) * 19.0, INK, 3.5, true)
	if _b_step() >= 7:
		# The clock's minute hand is bent exactly as the barometer's needle is.
		var knee := CLOCK_C + _dir(m * 6.0) * 21.0
		c.draw_line(CLOCK_C, knee, INK, 2.5, true)
		c.draw_line(knee, knee + _dir(m * 6.0 + 25.0) * 9.0, INK, 2.5, true)
	else:
		c.draw_line(CLOCK_C, CLOCK_C + _dir(m * 6.0) * 29.0, INK, 2.5, true)
	var sec := 0.0
	if running and motion:
		sec = fmod(floor(time), 60.0) * 6.0
	c.draw_line(CLOCK_C - _dir(sec) * 6.0, CLOCK_C + _dir(sec) * 31.0, BRICK, 1.2, true)
	c.draw_circle(CLOCK_C, 3.0, INK)

## The board at room scale mirrors c_board: each pinned mark is outlined in brick, a thread
## runs from it to its slot pin on the lower rail, then pin to pin. The aged-card strip lies
## over the thread; when stamped it carries a bold VENN block that fits it.
func _draw_board_room(c: Node2D) -> void:
	var full := Rect2(Vector2.ZERO, SIZE)
	if office.state.board_loaded and _tex("R02/b_board_papers"):
		c.draw_texture_rect(_tex("R02/b_board_papers"), full, false)
	var pins: Array = office.state.board_pins
	var n := 0
	for i in pins.size():
		if not BOARD_POINTS.has(pins[i]) or i >= BOARD_SLOT_PINS.size():
			continue
		var p: Vector2 = BOARD_POINTS[pins[i]]
		c.draw_rect(Rect2(p - Vector2(26, 7), Vector2(52, 14)), Color(BRICK, 0.9), false, 1.5)
		c.draw_line(p + Vector2(26, 0), BOARD_SLOT_PINS[i], BRICK, 2.0, true)
		if i > 0:
			c.draw_line(BOARD_SLOT_PINS[i - 1], BOARD_SLOT_PINS[i], BRICK, 2.0, true)
		n += 1
	var solved := office.board_solved()
	if solved and _tex("R02/b_board_solved"):
		c.draw_texture_rect(_tex("R02/b_board_solved"), full, false)
	var strip := _tex("R02/b_board_strip")
	if strip:
		c.draw_texture_rect(strip, PROVENANCE_STRIP, false)
	for i in BOARD_SLOT_PINS.size():
		if i < n:
			var pin: Vector2 = BOARD_SLOT_PINS[i]
			c.draw_circle(pin, 4.0, BRICK)   # the thread's knot on its pin
	if solved:
		_draw_venn_stamp(c, PROVENANCE_STRIP.get_center())
		# The night print gets its pale border, so it reads as a photograph and not a hole.
		var pr := BOARD_PRINT
		var card := Color("e2dccb")
		for r in [Rect2(pr.position - Vector2(6, 6), Vector2(pr.size.x + 12, 11)),
				Rect2(pr.position.x - 6, pr.end.y - 12, pr.size.x + 12, 22),
				Rect2(pr.position - Vector2(6, 6), Vector2(11, pr.size.y + 16)),
				Rect2(pr.end.x - 5, pr.position.y - 6, 11, pr.size.y + 16)]:
			c.draw_rect(r, card)
		c.draw_rect(Rect2(pr.position - Vector2(6, 6), pr.size + Vector2(12, 16)), INK, false, 2.0)
		c.draw_circle(Vector2(pr.get_center().x, pr.position.y - 1), 4.0, BRASS)
		c.draw_arc(Vector2(pr.get_center().x, pr.position.y - 1), 4.0, 0, TAU, 12, INK, 1.0)

## A bold rubber-stamp block: double brick border, VENN in heavy capitals, sized to the strip.
func _draw_venn_stamp(c: CanvasItem, ctr: Vector2) -> void:
	var box := Rect2(ctr - Vector2(46, 11), Vector2(92, 22))
	c.draw_rect(box, Color(BRICK, 0.16))
	c.draw_rect(box, Color(BRICK, 0.95), false, 2.5)
	c.draw_rect(box.grow(-4), Color(BRICK, 0.85), false, 1.2)
	var w := serif.get_string_size("VENN", HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var at := Vector2(ctr.x - w / 2.0, ctr.y + 6.5)
	for o in [Vector2.ZERO, Vector2(0.8, 0), Vector2(0, 0.6)]:   # struck heavy, as a rubber stamp is
		c.draw_string(serif, at + o, "VENN", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, BRICK)

# ---------------------------------------------------------------------------
# drawing: close-ups and full-screen views (unlit layer)
# ---------------------------------------------------------------------------

func _draw_close() -> void:
	var c := close
	match office.view:
		"end":
			_draw_end(c)
		"repair":
			_draw_repair(c)
		"logbook":
			_draw_logbook(c)
		"duty", "note":
			_draw_duty(c)
		"drawer":
			_draw_drawer(c)
		"report":
			_draw_report(c)
		"board":
			_draw_board_close(c)
		"photo":
			_draw_photo_close(c)

## c_duty / c_note: the card (or the note) on the left, the contract it was lying on to the
## right of it, with the launch she is waiting for.
func _draw_duty(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.94))
	# The card is set in the serif like every other paper in the station: a blank painted card
	# (assets/rooms/R02/c_note_card.png, 800 x 650 like the old SVG cards) and the words here.
	var tex: Texture2D = _tex("R02/c_note_card")
	if tex == null:
		tex = textures["duty_card" if office.view == "duty" else "chart_note"]
	var k := minf(DUTY_CARD_BOX.size.x / tex.get_width(), DUTY_CARD_BOX.size.y / tex.get_height())
	var size := tex.get_size() * k
	var card := Rect2(DUTY_CARD_BOX.position + (DUTY_CARD_BOX.size - size) / 2.0, size)
	c.draw_texture_rect(tex, card, false)
	if _tex("R02/c_note_card"):
		var lines: Array = DUTY_CARD_LINES if office.view == "duty" else NOTE_CARD_LINES
		for l in lines:
			c.draw_string(serif, card.position + Vector2(58, l[0]) * k, l[2], HORIZONTAL_ALIGNMENT_LEFT,
				card.size.x - 100 * k, int(round(l[1] * k)), INK)
	if office.view == "note":
		# Her initials, in a hand she doesn't remember using.
		c.draw_set_transform(card.position + Vector2(0.073, 0.897) * card.size, -0.025)
		c.draw_string(hand, Vector2.ZERO, "Lamp service completed.  — A.M.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(30 * k * 1.2)), Color(0.22, 0.22, 0.25, 0.9))
		c.draw_set_transform(Vector2.ZERO)
	var paper := _tex("R02/c_duty_contract")
	if paper:
		c.draw_texture_rect(paper, DUTY_CONTRACT, false)
	else:
		c.draw_rect(DUTY_CONTRACT, PAPER)
	var x := DUTY_CONTRACT.position.x + 34
	var w := DUTY_CONTRACT.size.x - 68
	var y := DUTY_CONTRACT.position.y + 82
	c.draw_string(serif, Vector2(x, y), "GREYWAKE SURVEY STATION.", HORIZONTAL_ALIGNMENT_LEFT, w, 20, INK)
	c.draw_string(serif, Vector2(x, y + 25), "CONTRACT OF CLOSURE.", HORIZONTAL_ALIGNMENT_LEFT, w, 20, INK)
	y = DUTY_CONTRACT.position.y + 154
	for i in range(1, CONTRACT_LINES.size() - 1):
		y = Ink.wrapped(c, CONTRACT_LINES[i], Vector2(x, y), 19, INK, w, true, serif) + 10
	Ink.wrapped(c, CONTRACT_LINES[CONTRACT_LINES.size() - 1], Vector2(x, DUTY_CONTRACT.position.y + 440), 18,
		INK, w, true, serif)
	c.draw_string(serif, Vector2(x, DUTY_CONTRACT.position.y + 512), "Collection: the station launch, two stripes.",
		HORIZONTAL_ALIGNMENT_LEFT, w, 16, Color(INK, 0.8))

## c_board: the contract, the inquiry clipping and his letter, three slots, the provenance
## field and the stamp rack. Every word on it is drawn here, readable at any light.
func _draw_board_close(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.94))
	var bg := _tex("R02/c_board")
	if bg:
		c.draw_texture_rect(bg, Rect2(Vector2.ZERO, SIZE), false)
	var solved := office.board_solved()
	# The contract.
	var cx := C_CONTRACT.position.x + 18
	var cw := C_CONTRACT.size.x - 36
	c.draw_string(serif, Vector2(cx, 194), "GREYWAKE SURVEY STATION.", HORIZONTAL_ALIGNMENT_LEFT, cw, 15, INK)
	c.draw_string(serif, Vector2(cx, 210), "CONTRACT OF CLOSURE.", HORIZONTAL_ALIGNMENT_LEFT, cw, 15, INK)
	Ink.wrapped(c, CONTRACT_LINES[1], Vector2(cx, 246), 17, INK, cw, true, serif)
	var y := Ink.wrapped(c, CONTRACT_LINES[2], Vector2(cx, 314), 15, INK, cw, true, serif) + 6
	Ink.wrapped(c, CONTRACT_LINES[3], Vector2(cx, y), 15, INK, cw, true, serif)
	c.draw_string(serif, Vector2(cx, 474), "Signed for the Board.", HORIZONTAL_ALIGNMENT_LEFT, cw, 16, INK)
	c.draw_string(serif, Vector2(cx, 504), "Countersigned: E. Venn.", HORIZONTAL_ALIGNMENT_LEFT, cw, 16, INK)
	# The clipping.
	var kx := C_CLIPPING.position.x + 18
	var kw := C_CLIPPING.size.x - 36
	y = Ink.wrapped(c, "MORROW HARBOUR BOARD. Inquiry, 1929.", Vector2(kx, 166), 17, INK, kw, true, serif) + 4
	Ink.wrapped(c, "In the matter of Daniel Roe, dockworker, reported missing. The Board certifies that no person of that name was employed on the harbour.",
		Vector2(kx, y), 15, INK, kw, true, serif)
	c.draw_string(hand, Vector2(kx, 412), "J. Callis", HORIZONTAL_ALIGNMENT_LEFT, kw, 20, INK)
	c.draw_string(hand, Vector2(kx, 480), "R. Orme", HORIZONTAL_ALIGNMENT_LEFT, kw, 20, INK)
	Ink.wrapped(c, "A. Mercer, dissenting: 'Unverified does not mean absent. I will not certify that this man never worked here.'",
		Vector2(kx, 532), 15, INK, kw, true, hand)
	# The letter, in his hand.
	var lx := C_LETTER.position.x + 18
	var lw := C_LETTER.size.x - 36
	# The pinned photograph covers the letter's top right corner: the heading keeps clear of it.
	var head_w := C_BOARD_PHOTO.position.x - 8.0 - lx
	c.draw_string(serif, Vector2(lx, 176), "Greywake, 2 September 1931.", HORIZONTAL_ALIGNMENT_LEFT, head_w, 14, VENN_INK)
	Ink.wrapped(c, "To the Secretary, Morrow Harbour Board.", Vector2(lx, 210), 15, VENN_INK, head_w, true, serif)
	Ink.wrapped(c, "For the closure I ask for one person by name: Miss A. Mercer, who sat on your Roe inquiry.",
		Vector2(lx, 260), 15, VENN_INK, lw, true, serif)
	Ink.wrapped(c, "She wrote that 'unverified does not mean absent.' I require exactly that.", Vector2(lx, 356), 16,
		VENN_INK, lw, true, serif)
	c.draw_string(serif, Vector2(lx + 160, 452), "E. Venn", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, VENN_INK)
	if solved:
		var broken := _tex("R02/venn_seal_broken")
		if broken:
			c.draw_texture_rect(broken, Rect2(C_SEAL.end.x - 60, C_SEAL.position.y + 2, 56, 56), false)
		Ink.wrapped(c, SEAL_TEXT, C_SEAL.position + Vector2(8, 22), 15, VENN_INK, C_SEAL.size.x - 82, true, serif)
	else:
		for i in 4:   # the folded paragraph under the seal: lines, unreadable
			var ly := C_SEAL.position.y + 22 + i * 22
			c.draw_line(Vector2(C_SEAL.position.x + 10, ly), Vector2(C_SEAL.end.x - 10 - (60 if i == 3 else 0), ly),
				Color(VENN_INK, 0.18), 6.0)
		var seal := _tex("R02/venn_seal")
		if seal:
			c.draw_texture_rect(seal, Rect2(C_SEAL.get_center() - Vector2(48, 48), Vector2(96, 96)), false)
	# The marks, outlined where pinned.
	var pins: Array = office.state.board_pins
	var rects := {}
	for r in C_BOARD_RECTS:
		rects[r[0]] = r[1]
	for id in pins:
		if rects.has(id):
			c.draw_rect(rects[id], Color(BRICK, 0.9), false, 2.5)
	# The thread: each pinned mark to its slot, then slot to slot.
	for i in pins.size():
		if not rects.has(pins[i]):
			continue
		var mr: Rect2 = rects[pins[i]]
		var slot: Vector2 = rects["slot_%d" % i].get_center()
		c.draw_line(Vector2(mr.end.x, mr.get_center().y), slot, BRICK, 3.0, true)
		if i > 0:
			c.draw_line(rects["slot_%d" % (i - 1)].get_center(), slot, BRICK, 3.0, true)
	for i in R02Sim.BOARD_SLOTS:
		var sr: Rect2 = rects["slot_%d" % i]
		if i < pins.size():
			var label: String = R02Sim.MARKS.get(pins[i], pins[i])
			var h := Ink.wrapped(c, label, Vector2.ZERO, 16, PAPER, sr.size.x - 16, false, serif)
			var plaque := Rect2(sr.position + Vector2(0, 44), Vector2(sr.size.x, h + 8))
			c.draw_rect(plaque, Color(INK, 0.86))
			Ink.wrapped(c, label, plaque.position + Vector2(8, 22), 16, PAPER, sr.size.x - 16, true, serif)
		c.draw_circle(sr.get_center(), 9.0, Color(BRASS.darkened(0.2), 0.0 if i >= pins.size() else 1.0))
	# The provenance field.
	var prov: Rect2 = rects["provenance"]
	c.draw_string(serif, prov.position + Vector2(14, 22), "PROVENANCE OF APPOINTMENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(INK, 0.7))
	if solved:
		var ink := _tex("R02/stamp_ink")
		var ir := Rect2(prov.get_center() - Vector2(180, 30), Vector2(360, 72))
		if ink:
			c.draw_texture_rect(ink, ir, false)
		var tw := serif.get_string_size("REQUESTED BY VENN", HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		c.draw_string(serif, Vector2(ir.get_center().x - tw / 2.0, ir.get_center().y + 11), "REQUESTED BY VENN",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, BRICK)
	# The stamp rack.
	for id in ["stamp_venn", "stamp_board", "stamp_unknown"]:
		var r: Rect2 = rects[id]
		var held: bool = office.held_stamp == id
		if held:
			c.draw_rect(Rect2(r.position + Vector2(0, 52), Vector2(r.size.x, r.size.y - 52)), Color(0, 0, 0, 0.35))
			r = Rect2(r.position - Vector2(0, 14), r.size)
			var face := Rect2(r.position + Vector2(4, 50), Vector2(r.size.x - 8, 52))
			c.draw_rect(face, Color("5a3d26"))
			c.draw_rect(face.grow(2), GOLD, false, 3.0)
		var lines: Array = STAMP_LINES[id]
		for li in lines.size():
			var ws := serif.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var ty := r.position.y + (82.0 if lines.size() == 1 else 72.0 + li * 20.0)
			c.draw_string(serif, Vector2(r.get_center().x - ws / 2.0, ty), lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PAPER)
	if solved and not photo_armed:
		_draw_photo(c, C_BOARD_PHOTO, office.photo_variant())
		c.draw_circle(C_BOARD_PHOTO.position + Vector2(60, 6), 5.0, BRASS)

## c_photo: the print, full frame; after P20 its back, in his hand.
func _draw_photo_close(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.94))
	if office.photo_back:
		var back := _tex("R02/photo_back")
		if back:
			c.draw_texture_rect(back, PHOTO_PRINT, false)
		else:
			c.draw_rect(PHOTO_PRINT, Color("e4dcc8"))
		Ink.wrapped(c, PHOTO_BACK_TEXT, PHOTO_BACK_TEXT_RECT.position + Vector2(0, 30), 26, VENN_INK,
			PHOTO_BACK_TEXT_RECT.size.x, true, serif)
	else:
		_draw_photo(c, PHOTO_PRINT, office.photo_variant())
	if office.board_solved():
		_button(c, TURN_OVER, "Turn it back" if office.photo_back else "Turn it over")


## The end card: the photograph from after she left, the log's last row writing itself,
## then the lines. With Motion off it is all there at once.

func _draw_end(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color("070b0f"))
	var t := end_t if motion else 1.0e6
	var photo_a := end_photo_alpha(t)
	if photo_a > 0.0:
		_draw_end_print(c, "turned" if office.state.turned else "after", photo_a)
	# Built fresh every frame: only what is due at `t`, so no row's time stamp outlives its
	# row or lands on the caption's line.
	for e in end_card_texts(t):
		match e.kind:
			"caption":
				_text(c, e.text, e.pos, END_CAPTION_SIZE, Color(END_CAPTION_COL, e.a), hand, e.width)
			"row_her":
				_draw_handwriting(c, e.text, e.n, e.pos, 30, e.seed, e.n < e.text.length(), NIGHT_INK)
			"row_venn":
				_draw_handwriting(c, e.text, e.n, e.pos, 26, e.seed, e.n < e.text.length(),
					Color(0.66, 0.68, 0.70), serif, 0.0)
			"line_station":
				_text(c, e.text, e.pos, 24, Color(NIGHT_INK, e.a), hand, SIZE.x)
			"line_seen":
				_text(c, e.text, e.pos, 22, Color(PAPER, 0.6 * e.a), serif, SIZE.x)
	if _end_button_ready():
		_button(c, END_BUTTON, "Go on")

## The print's value on the card at `t`: full by END_PHOTO_FADE; at once with Motion off.
func end_photo_alpha(t: float) -> float:
	if not motion:
		return 1.0
	return clampf(t / END_PHOTO_FADE, 0.0, 1.0)

## The print on the Tide I card, in plate space: END_PHOTO_H tall, centred on END_PHOTO_CX.
func end_photo_rect() -> Rect2:
	var tex := _end_print_tex("turned" if office.state.turned else "after")
	var aspect := 528.0 / 620.0
	if tex:
		aspect = float(tex.get_width()) / float(tex.get_height())
	var img_h := END_PHOTO_H - 2.0 * END_PHOTO_BORDER
	var w := img_h * aspect + 2.0 * END_PHOTO_BORDER
	return Rect2(END_PHOTO_CX - w / 2.0, END_PHOTO_TOP, w, END_PHOTO_H)

## The painted print for the card: the re-inked T1X print when there is one.
func _end_print_tex(variant: String) -> Texture2D:
	if variant == "after" and _tex("R02/photo_t1x_after"):
		return _tex("R02/photo_t1x_after")
	return _photo_tex(variant)

func _draw_end_print(c: Node2D, variant: String, alpha: float) -> void:
	var rect := end_photo_rect()
	c.draw_rect(rect, Color("d8d0bc"))
	var img := rect.grow(-END_PHOTO_BORDER)
	var painted := _end_print_tex(variant)
	if painted:
		c.draw_texture_rect(painted, img, false)
	else:
		c.draw_set_transform(img.get_center())
		_draw_photo_drawn(c, Rect2(-img.size / 2.0, img.size), variant)
		c.draw_set_transform(Vector2.ZERO)
	c.draw_rect(img, Color(0.45, 0.35, 0.2, 0.12))
	c.draw_rect(rect, Color("8f7a55", 0.6), false, 2.0)
	if alpha < 1.0:
		c.draw_rect(rect.grow(3), Color("070b0f", 1.0 - alpha))

## Every string the Tide I card draws at `t` seconds, in draw order, as
## {kind, text, pos, width, a, n, seed}: the caption once, under the print; each log row only
## from its start, with how much of it is written; each closing line once it is fading in.
func end_card_texts(t: float) -> Array:
	var out := []
	var sch := _end_schedule()
	var photo_a := end_photo_alpha(t)
	var rect := end_photo_rect()
	if photo_a > 0.0:
		# Centred END_CAPTION_GAP under the print, on its axis (baseline 8 px below that).
		var cw := rect.size.x
		out.append({"kind": "caption", "text": END_CAPTION, "a": photo_a, "width": cw,
			"pos": Vector2(END_PHOTO_CX - cw / 2.0, rect.end.y + END_CAPTION_GAP + 8.0)})
	# The log's next two rows write themselves. Hers in her ink; his, if it is his, in a
	# plainer, upright, grey hand: someone else is keeping the log now.
	var rows := office.end_rows()
	var starts := [sch.r1_start, sch.r2_start]
	for i in 2:
		if t < starts[i]:
			continue
		var text: String = rows[i][0]
		var n := mini(int((t - starts[i]) * REVEAL_CPS), text.length())
		var venn: bool = rows[i][1] == "venn"
		var font: Font = serif if venn else hand
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26 if venn else 30).x
		out.append({"kind": "row_venn" if venn else "row_her", "text": text, "n": n, "seed": (78 if venn else 77) + i,
			"pos": Vector2(END_PHOTO_CX - w / 2.0, END_ROW_Y[i]), "a": 1.0, "width": w})
	var lines_at: Array = sch.lines
	var end_text := office.end_lines()
	for i in end_text.size():
		var a := clampf((t - float(lines_at[i])) / 1.0, 0.0, 1.0)
		if a <= 0.0:
			continue
		out.append({"kind": "line_station" if end_text[i] == R02Sim.END_ON_STATION else "line_seen",
			"text": end_text[i], "a": a, "width": SIZE.x, "pos": Vector2(0, END_LINE_Y.get(end_text[i], 952.0))})
	return out

## When each part of the end card appears, in seconds after the end card opens:
## the two rows (start, done), each closing line's fade-in, and when the last is in.

func _end_schedule() -> Dictionary:
	var rows := office.end_rows()
	var r1_start := 3.0
	var r1_done: float = r1_start + rows[0][0].length() / REVEAL_CPS
	var r2_start := r1_done + 2.0
	var r2_done: float = r2_start + rows[1][0].length() / REVEAL_CPS
	var at := []
	for i in office.end_lines().size():
		at.append(r2_done + 1.5 + 1.6 * i)
	return {"r1_start": r1_start, "r1_done": r1_done, "r2_start": r2_start, "r2_done": r2_done,
		"lines": at, "cont": at.back(), "done": float(at.back()) + 1.0}

func _end_row_writing() -> bool:
	if office.view != "end" or not motion:
		return false
	var sch := _end_schedule()
	return end_t >= sch.r1_start and end_t < sch.r1_done or end_t >= sch.r2_start and end_t < sch.r2_done

## "Play again" exists only once the last line is in (or after the grace, Motion off).

func _end_button_ready() -> bool:
	if not motion:
		return end_t > END_GRACE
	return end_t >= _end_schedule().done

func _draw_repair(c: Node2D) -> void:
	c.draw_texture_rect(textures["repair_panel"], Rect2(Vector2.ZERO, SIZE), false)
	_draw_repair_stains(c)
	_text(c, "(water-damaged)", Vector2(896, 765), 18, Color(INK, 0.6), hand, 400, HORIZONTAL_ALIGNMENT_LEFT)
	c.draw_texture_rect(textures["switch_on" if office.state.supply_on else "switch_off"],
		Rect2(Vector2.ZERO, SIZE), false)
	if office.state.bridge_installed:
		c.draw_texture_rect(textures["bridge_b_installed"], Rect2(Vector2.ZERO, SIZE), false)
	else:
		c.draw_texture_rect(textures["bridge_b"], Rect2(106, 868, 240, 120), false)
	c.draw_texture_rect(textures["bridge_c"], Rect2(396, 868, 240, 120), false)
	if office.state.bridge_installed and office.state.supply_on:
		c.draw_texture_rect(textures["indicator_on"], Rect2(Vector2.ZERO, SIZE), false)
	if office.selected != "":
		var r := Rect2(88, 867, 278, 122) if office.selected == "B" else Rect2(376, 867, 278, 122)
		c.draw_rect(r, GOLD, false, 5)

## The card's water damage: a seeded cluster of stains and tide-marks in the margin below
## the card's '(water-damaged)' caption, clear of all three steps and the B shape.
const REPAIR_STAIN_BOX := Rect2(880, 778, 400, 80)

func _draw_repair_stains(c: Node2D) -> void:
	var g := RandomNumberGenerator.new()
	g.seed = 1852
	var stain := Color("b8a47c", 0.55)
	var mark := Color("8f7a55", 0.45)
	var box := REPAIR_STAIN_BOX
	for i in 8:
		var r := g.randf_range(18.0, box.size.y / 2.0 - 2.0)
		var p := Vector2(g.randf_range(box.position.x + r, box.end.x - r),
			g.randf_range(box.position.y + r, box.end.y - r))
		c.draw_circle(p, r, stain)
		c.draw_arc(p, r, 0, TAU, 40, mark, 2.0, true)
	c.draw_arc(box.get_center() + Vector2(60, 0), box.size.y / 2.0 - 1.0, 0, TAU, 64, Color("8f7a55", 0.5), 3.0)

func _draw_logbook(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.96))
	var page := Rect2(204, 110, 1040, 860)
	var lit: bool = office.state.p01_complete
	c.draw_rect(page, Color("d9cfb2"))
	c.draw_rect(page, Color("8f7a55"), false, 2)
	_text(c, "GREYWAKE SURVEY STATION — TIDE LOG", page.position + Vector2(48, 66), 26, INK, serif, 900, HORIZONTAL_ALIGNMENT_LEFT)
	var obs_pos := page.position + Vector2(48, 104)
	_text(c, "Observer: E. Venn", obs_pos, 22, Color(INK, 0.7), hand, 600, HORIZONTAL_ALIGNMENT_LEFT)
	if lit and office.stage() >= 3:
		var w := hand.get_string_size("Observer: E. Venn", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		c.draw_line(obs_pos + Vector2(0, -7), obs_pos + Vector2(w, -7), INK, 2.0)
		_text(c, "A. Mercer", obs_pos + Vector2(w + 18, 0), 24, BLUE_INK, hand, 300, HORIZONTAL_ALIGNMENT_LEFT)
	if lit:
		# Venn's rule, in pencil in the margin: the key to the stained hour.
		var mw := hand.get_string_size(R02Sim.LOG_MARGIN, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var mx := minf(640.0, page.size.x - 40.0 - mw)
		c.draw_set_transform(page.position + Vector2(mx, 104), -0.03)
		c.draw_string(hand, Vector2.ZERO, R02Sim.LOG_MARGIN, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
			Color(0.25, 0.25, 0.28, 0.85))
		c.draw_set_transform(Vector2.ZERO)
	var rows := office.log_rows()
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
		if r == R02Sim.BLOTTED_ROW and e[1] == "":
			_draw_blot(c, Vector2(page.position.x + 262, y - 7))
		_text(c, e[2], Vector2(page.position.x + 352, y), size, col, hand, 150, HORIZONTAL_ALIGNMENT_LEFT)
		var note_pos := Vector2(page.position.x + 512, y)
		if e[4]:
			var n: int = e[3].length()
			var writing := idx == log_shown_hand
			if writing:
				n = mini(int(floor(reveal_n)), n)
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

## Her hand, glyph by glyph: seeded jitter, a forward slant, and wet ink at the nib.
func _draw_handwriting(c: Node2D, text: String, count: int, pos: Vector2, size: int, row: int,
		wet: bool, ink := BLUE_INK, font: Font = null, skew := HAND_SKEW) -> void:
	Ink.handwriting(c, text, count, pos, size, row, wet, ink, font if font else hand, skew)

func _draw_drawer(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.94))
	if office.state.drawer_open:
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
	var code: Array = office.state.drawer_dial
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
	# A hairline crack across the glass, flat navy.
	c.draw_polyline(PackedVector2Array([WATCH_C + Vector2(-96, -52), WATCH_C + Vector2(-30, -14),
		WATCH_C + Vector2(18, -40), WATCH_C + Vector2(88, 30)]), Color(INK, 0.85), 1.0, true)
	_text(c, "stopped 18:52", Vector2(480, 770), 22, PAPER, hand, 300, HORIZONTAL_ALIGNMENT_LEFT)
	if not office.board_solved():
		_draw_photo(c, PHOTO_RECT, office.photo_variant())

## The painted print for a photo variant, or null for the drawn fallback.

func _photo_tex(variant: String) -> Texture2D:
	match variant:
		"drawer":
			if int(office.state.photo_looks) >= 3 and _tex("photo_drawer_hand"):
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
	var k := minf(1.0, rect.size.x / 300.0)   # a small print keeps its proportions
	c.draw_rect(Rect2(-half, rect.size), Color("d8d0bc"))
	var img := Rect2(-half.x + 18 * k, -half.y + 18 * k, rect.size.x - 36 * k, rect.size.y - 70 * k)
	var painted := _photo_tex(variant)
	if painted:
		c.draw_texture_rect(painted, img, false)
	else:
		_draw_photo_drawn(c, img, variant)
	c.draw_rect(img, Color(0.45, 0.35, 0.2, 0.18))
	_text(c, "Greywake. 18 Oct.", Vector2(-half.x, half.y - 18 * k), maxi(9, int(20 * k)), INK, hand, rect.size.x)
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
	var filed: bool = office.state.report_filed
	c.draw_rect(pg, Color("ded4ba"))
	c.draw_rect(pg, Color("8f7a55"), false, 2)
	_text(c, "GREYWAKE SURVEY STATION — CLOSURE REPORT", pg.position + Vector2(0, 74), 26, INK, serif, pg.size.x)
	_text(c, "To be completed by the observer before the station is left.", pg.position + Vector2(0, 112), 20,
		Color(INK, 0.6), hand, pg.size.x)
	for i in R02Sim.REPORT_FIELDS.size():
		var r := _report_row(REPORT_FIELD_ROWS[i])
		var field: Array = R02Sim.REPORT_FIELDS[i]
		var value: String = field[1][int(office.state.report_fields[i])]
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
	_text(c, R02Sim.REPORT_TIME_LABEL, r.position + Vector2(20, 62), 24, INK, serif, 480, HORIZONTAL_ALIGNMENT_LEFT)
	var t: Array = office.state.report_time
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


## The stranger line writes itself once, slowly, the first time the notebook opens after
## the log rewrote itself. Motion off: it is simply there.


## Lays out notebook entries in 1 or 2 columns. Returns {fits, next}: whether they fit
## above `bottom`, and where the next entry would start.




# ---------------------------------------------------------------------------
# drawing: HUD
# ---------------------------------------------------------------------------

## The exits and the turn tab are always there, raised clear of the subtitle bar: the core
## draws the exit plaques; the turn tab is faint at rest and full when the cursor is on the
## bar or at the bottom edge. At the threshold only the turn tab remains, so she can always
## turn round.
func draw_hud(c: Node2D) -> void:
	# A pass the room's tick opened: paint by the cursor (full on the bar, faint at rest so
	# the tab does not sit on the floor). A draw with no tick before it paints full.
	var faint := hud_pass_open and not _exit_bar_live()
	_close_hud_pass()
	if office.view == "room" and game and game.sim.view == "room":
		# The core has drawn the exit plaques; the turn tab is the room's.
		_draw_turn_tab(c, BAR_REST_ALPHA if faint else 1.0)
		if turn_signposted():
			_draw_turn_signpost(c)
		_draw_anchored_label(c)
	if office.view == "threshold" and game and game.sim.view == "room":
		var hot := _has_pointer() and TURN_RECT.has_point(game.pointer_position())
		_draw_turn_tab(c, 1.0 if hot else TAB_REST_ALPHA, hot)
		if game.hover_id == "continue":
			var r := walk_on_label_rect()
			c.draw_rect(r, Color(0.03, 0.06, 0.08, 0.8))
			c.draw_string(serif, r.position + Vector2(10, 24), WALK_ON_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)

## The figure in the doorway as the screen shows it (pure): its whole unclipped silhouette
## and rim, at its current nearness, through the lean and the push.
func threshold_figure_rect() -> Rect2:
	var sc := fig_scale if motion else FIGURE_SCALE_STILL
	var feet_y := VP.y + (DOOR_SLAB.end.y - VP.y) * FIGURE_DEPTH
	var hh := feet_y - VP.y - 1.0   # head to heel, as _draw_threshold_figure has it
	var half_w := 0.16 * hh * sc
	var top := VP.y + (feet_y - hh - VP.y) * sc
	var bottom := VP.y + (feet_y - VP.y) * sc
	var native := Rect2(VP.x - half_w, top, 2.0 * half_w, bottom - top).grow(3.0)
	return _zoom_xform() * native

## Where "Walk toward it" sits at the threshold (pure: drawing and tests): centred on the
## corridor under the figure, at the bottom of the frame above the subtitles, stepped aside
## (toward the figure's side) off the turn tab.
func walk_on_label_rect() -> Rect2:
	var w := serif.get_string_size(WALK_ON_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 20.0
	var fig := threshold_figure_rect()
	var y := maxf(WALK_ON_LABEL_Y, fig.end.y + 6.0)
	var r := Rect2(clampf(fig.get_center().x - w / 2.0, 8.0, SIZE.x - w - 8.0), y, w, 34.0)
	var tab := TURN_RECT.grow(6.0)
	if r.intersects(tab):
		var left := tab.position.x - w
		r.position.x = left if fig.get_center().x <= tab.get_center().x and left >= 8.0 else tab.end.x
	return r

## Ink.button with an opacity: the same plaque, faded as a whole.
func _plaque(c: CanvasItem, rect: Rect2, label: String, a: float, active: bool, size := 19) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Color("786440") if active else Color(0.15, 0.25, 0.29), 0.92 * a)
	style.border_color = Color(GOLD if active else Color("8ba19a"), a)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	c.draw_style_box(style, rect)
	if label == "":
		return
	var ts := serif.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	while ts.x > rect.size.x - 12.0 and size > 13:
		size -= 1
		ts = serif.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	c.draw_string(serif, rect.position + Vector2((rect.size.x - ts.x) / 2.0, rect.size.y / 2.0 + size * 0.36),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(PAPER, a))

## Facing the entry wall, a hovered object's name sits just above it (or just inside its
## top edge), not at the cursor, so it never lies over the stamp rail or the board.
func _draw_anchored_label(c: Node2D) -> void:
	if office.facing != "B" or game.hover_id == "" or game.hover_id == "turn":
		return
	var r := Rect2()
	for h in HOTSPOTS_B:
		if h[0] == game.hover_id:
			r = h[1]
	if not r.has_area():
		return
	var label := _hotspot_label(game.hover_id)
	var w := serif.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 20
	var y := r.position.y - 40.0
	if y < 84.0:
		y = r.position.y + 6.0
	var x := clampf(r.get_center().x - w / 2.0, 8.0, SIZE.x - w - 8.0)
	c.draw_rect(Rect2(x, y, w, 34), Color(0.03, 0.06, 0.08, 0.8))
	c.draw_string(serif, Vector2(x + 10, y + 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)

## Until she first turns round (the entry wall unseen), the turn tab is signposted.
func turn_signposted() -> bool:
	return office.view == "room" and office.facing == "A" and not office.state.b_seen

## The signpost's outline opacity: a slow idle pulse; Motion off, steady and bright.
func turn_signpost_alpha() -> float:
	if not motion:
		return 1.0
	return 0.35 + 0.65 * (0.5 + 0.5 * sin(TAU * time / TURN_PULSE_PERIOD))

## A sea-glass outline round the tab and its arrow at full value, whatever the bar's rest.
func _draw_turn_signpost(c: Node2D) -> void:
	var a := turn_signpost_alpha()
	c.draw_rect(TURN_RECT.grow(4.0), Color(TURN_SIGNPOST, a), false, 3.0 if motion else 3.5)
	_draw_turn_arrow(c, Color(PAPER, 0.55 + 0.45 * a))

## The turn tab: a plaque like the exit tabs, with a curved arrow drawn in ink lines that
## bends the way she turns.
func _draw_turn_tab(c: Node2D, alpha := 1.0, hot := false) -> void:
	_plaque(c, TURN_RECT, "", alpha, hot or game.hover_id == "turn")
	_draw_turn_arrow(c, Color(PAPER, 0.95 * alpha))

func _draw_turn_arrow(c: Node2D, col: Color) -> void:
	var ctr := TURN_RECT.get_center() + Vector2(0, 6)
	var sweep := 1.0 if office.facing == "A" else -1.0
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI * 0.95, PI * 0.05, i / 16.0)
		pts.append(ctr + Vector2(cos(a) * 20.0 * sweep, -sin(a) * 15.0))
	c.draw_polyline(pts, col, 3.0, true)
	var tip := pts[pts.size() - 1]
	c.draw_line(tip, tip + Vector2(-9 * sweep, -3), col, 3.0, true)
	c.draw_line(tip, tip + Vector2(-1 * sweep, -10), col, 3.0, true)

# ---------------------------------------------------------------------------
# drawing helpers
# ---------------------------------------------------------------------------

func _button(c: CanvasItem, rect: Rect2, label: String, active := false, size := 24) -> void:
	Ink.button(c, rect, label, active, size)

func _text(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, font: Font, width: float,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	c.draw_string(font, pos, s, align, width, size, col)

## Draws word-wrapped text; returns the y below the last line.

## Draws word-wrapped text; returns the y below the last line.
func _wrapped(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, width: float,
		draw := true) -> float:
	return Ink.wrapped(c, s, pos, size, col, width, draw, serif)
