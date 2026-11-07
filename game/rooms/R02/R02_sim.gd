class_name R02Sim
extends RoomSim
## R02, the Intake Office: the slice's Tide I chain (P01, the drawer, the self-writing log,
## the closure report and the threshold, T1X) plus the entry wall (view B: outer door,
## service door, comparison board, barometer, receipt), P20 and the office's escalation
## through every later tide.
##
## No nodes, no clocks, no randomness: every change is caused by a player action. act()
## mutates state and appends presentation events for the view to play. Title, menu,
## notebook, settings and hints-ladder bookkeeping live in the core (GameSim).
##
## Every "delay" in an event is seconds after the click that caused it.
## "story" lines are part of a reveal: the view never drops them for a
## later click, and never cuts one off before it can be read.
##
## P01 rule (AGENTS.md): supply OFF, straight bridge B installed, supply ON.
## Curved C is rejected without consuming anything.
##
## Weather is the core's weather_band(), which only moves with puzzle flags. The office
## reads it only once she is past the threshold (band() is 0 before): Tide I is one night.

const ID := "R02"
const TITLE := "Intake Office"
const REQUIRES := []
const LOCKED := ""
const ARRIVAL := ""
const RESUME := "Back in the office."
## [to, label, extra flags]. R03/R04 need P01, R05/R06 need P06 (their own REQUIRES); the
## service door also needs the capsule's key turned once (exit_block).
const EXITS := [
	["R01", "Jetty", []],
	["R03", "Chart room", []],
	["R04", "Listening room", []],
	["R05", "Kitchen", []],
	["R06", "Bunks", []],
]
## View A, the desk wall (the approved plate).
const HOTSPOTS := ["mug", "tray", "lamp", "logbook", "papers", "chair", "drawer", "puddle",
	"hooks", "coat", "map", "stove", "window", "door"]
## View B, the entry wall.
const HOTSPOTS_B := ["outer_door", "service_door", "board", "barometer", "receipt"]
## Items this room hands out (docs/design/puzzle-cards/flags.md section 4).
const ITEMS := {
	"pencil": {"name": "Pencil", "desc": "Ada's own pencil. Short, and sharpened with a knife."},
	"venn_tide_sheet": {"name": "Venn's tide sheet, 17 Oct", "short": "Tide sheet", "desc": "His second tide sheet from the drawer, with a registration cross and a north arrow."},
	"inspection_lens": {"name": "Inspection lens", "short": "Lens", "desc": "A brass-rimmed lens from Venn's drawer."},
}

## The framed chart while the report is the objective: its count has moved since she read it.
const PILINGS_TEN_LINE := "Ten pilings now. I counted nine an hour ago."
## The office window at Tide II: the sea has gone out and not come back (R03's lamp line).
const LOW_WATER_LINE := "The sea has gone out past the lighthouse, and stayed out. Mud, all the way. The lighthouse is dark."

## The drawer plate wants the hour the log says she mends the lamp: 18:52.
const DRAWER_CODE := [1, 8, 5, 2]

## Venn's closure report: [label, options]. Every answer has a witness in her notebook.
const REPORT_FIELDS := [
	["Pilings, Greywake jetty", ["8", "9", "10"]],
	["Observers on station", ["1", "2", "3"]],
	["Height of that water", ["4.4 m", "9.9 m"]],
]
const REPORT_ANSWER := [2, 1, 1]
## The evening's high water is worked out, not read: 07:13 + 12 h 21 m = 19:34.
const REPORT_TIME_LABEL := "High water, 18 Oct, evening"
const REPORT_TIME_ANSWER := [1, 9, 3, 4]
## Wrong times that earn their own answer, keyed by the four digits.
const REPORT_TIME_MISSES := {
	"0713": "That's the morning tide. His rule gives the next one.",
	"1852": "That was the lamp. His rule runs on from the last time in the log.",
	"1913": "Twelve hours on. His tides don't keep to twelve.",
	"1933": "One minute out. He never was.",
	"1935": "One minute out. He never was.",
}
## The miss rows the log writes for her, in order.
const MISS_IDS := ["miss0", "miss1", "miss2"]

## P20, the comparison board: three pins, a thread, a stamp on the provenance field.
const MARKS := {
	"m_addressee": "Contract: Miss Ada Mercer",
	"m_countersign": "Contract: countersigned E. Venn",
	"m_callis": "Inquiry: J. Callis",
	"m_orme": "Inquiry: R. Orme",
	"m_mercer": "Inquiry: A. Mercer, dissenting",
	"m_sentence": "Letter: 'unverified does not mean absent'",
}
const STAMPS := {
	"stamp_venn": "REQUESTED BY VENN",
	"stamp_board": "ASSIGNED BY BOARD",
	"stamp_unknown": "UNKNOWN",
}
const BOARD_ANSWER := ["m_addressee", "m_mercer", "m_sentence"]
const BOARD_STAMP := "stamp_venn"
const BOARD_SLOTS := 3
const BOARD_DONE := "It's done. The thread runs from my name to my name to my sentence."

const OBJECTIVES := {
	"lamp": "Get the desk lamp working.",
	"log": "Read what Venn left on the desk.",
	"changed": "Something in the room changed while I was reading.",
	"drawer": "The footprints stop at a locked desk drawer.",
	"instruments": "Venn's note names two jobs down the corridor: the chart sheets and the recording.",
	"reread": "The logbook has been written in since I left.",
	"chair": "The log has written what I do next.",
	"report": "Reconcile the records. The closure report is under the duty card.",
	"filed": "The report is signed.",
	"leave": "The door has unlatched itself.",
	"board": "Venn's letters belong on the comparison board.",
	"service": "The kitchen key from the capsule fits the service door on the entry wall.",
	"away_t2": "The chart room's recorder, and whatever comes to the jetty.",
	"away_t3": "The kitchen and the bunk room, through the service door.",
	"away_t4": "The laboratory and the machine room, below the kitchen.",
	"away_t5": "The laboratory, the stair, and the lantern above it.",
	"away_t6": "The records vault, and the listening room again.",
	"away_t7": "The empty channel, and the station plan in the chart room.",
	"away_t8": "The bunk room, the vault and the stair: three frames, one witness.",
	"away_t9": "The chamber at the foot of the stair.",
}

const HINTS := {
	"lamp": [
		"The desk lamp is dead. The tray beside it holds spares.",
		"The plate inside the lamp says what kind of contact it takes, and what to do before fitting one.",
		"Open the lamp. Switch the supply OFF, select straight bridge B, tap the terminals, then switch ON.",
	],
	"log": [
		"With the lamp on, the desk is readable.",
		"Venn's tide log is the dark book on the desk.",
		"Open the tide log on the desk.",
	],
	"changed": [
		"Listen to the room. Then look at the floor.",
		"The coat has been dripping. Look beneath it.",
		"Inspect the puddle under the coat.",
	],
	"drawer": [
		"The prints stop at the desk. So does something else.",
		"The time she mends the lamp is stained. The tide before it isn't, and Venn wrote down the rhythm in the margin.",
		"Set the drawer dials to 1-8-5-2, the hour the log says she mends the lamp, then try the drawer.",
	],
	"instruments": [
		"Venn's note names two jobs: the chart sheets and the recording.",
		"The chart room wants both sheets registered at the lighthouse cross. The listening room has the recording he said to preserve.",
		"Take the corridor to the chart room and the listening room. His tide sheet from the drawer goes in the chart room.",
	],
	"reread": [
		"Something in the office has changed.",
		"Venn's log is not finished with you.",
		"Go back to the Intake Office and open the tide log.",
	],
	"chair": [
		"The log has told you what you do next.",
		"\"She looks at the chair.\"",
		"Inspect the chair behind the desk.",
	],
	"report": [
		"Each line has a witness. The evening's high water has to be worked out, not read.",
		"Look at the chart again, as it is now.",
		"Pilings 10. Observers 2. High water 19:34 (07:13 plus 12 h 21 m). Height 9.9 m. Then sign it.",
	],
	"filed": ["Put the report down.", "Step back from the desk.", "Use Back."],
	"leave": [
		"The door has unlatched itself.",
		"The corridor door is on the right.",
		"Use the door.",
	],
	"board": [
		"Venn's letters belong on the comparison board in the office.",
		"Follow the name on the contract to the inquiry clipping, and the sentence his letter quotes.",
		"Thread contract addressee to dissent signatory to the quoted sentence, then stamp REQUESTED BY VENN.",
	],
	"service": [
		"The service door is on the entry wall, behind you.",
		"The key from the mooring capsule is a kitchen key.",
		"Select the kitchen service key, then the service door.",
	],
	"away_t2": [
		"The office has given what it can for now. The corridor goes on.",
		"The chart room has the recorder; the duty card puts the records before the signal.",
		"Go to the chart room.",
	],
	"away_t3": [
		"The service door on the entry wall is open now.",
		"The kitchen and the bunk room were kept by people who lived here.",
		"Go through the service door to the kitchen or the bunk room.",
	],
	"away_t4": [
		"The kitchen's hatch opened onto a lower passage.",
		"Something in the laboratory and something in the machine room have to agree before the stair will.",
		"Go to the wet laboratory and the machine room, through the kitchen.",
	],
	"away_t5": [
		"The stair is open. So is the laboratory's return door.",
		"The laboratory is not finished with Nora Bell. Neither is the lantern.",
		"Go to the wet laboratory, then up the stair to the lantern gallery.",
	],
	"away_t6": [
		"The vault door in the laboratory has let go.",
		"The vault holds the 1927 session. The listening room can hear it.",
		"Go to the records vault, then the listening room.",
	],
	"away_t7": [
		"The listening room and the chart room.",
		"The empty channel answers to a seal. The plan wants everything you've been told.",
		"Go to the listening room's empty channel, then the chart room's plan.",
	],
	"away_t8": [
		"Three frames, one witness.",
		"The bunk room, the vault and the stair each hold part of a person.",
		"Go to the bunk room, the records vault, then the stair.",
	],
	"away_t9": [
		"The lower door on the stair is open.",
		"The chamber is waiting for an observer.",
		"Go down the stair to the observation chamber.",
	],
}
## At the threshold the hint ladder steps aside: there is only one thing to do.
const THRESHOLD_HINT := "Stand still until it finishes breathing. Then walk into it."

## Notebook text for each observation, in the order they read best.
const OBSERVATIONS := {
	"duty": "Closure duty: inventory the instruments, reconcile the records, restore the departure signal.",
	"contract": "Closure contract, addressed to Miss Ada Mercer, cataloguer. Inventory instruments. Reconcile outstanding records. Restore departure signal. Do not certify an observation you have not made. The collection launch (pennant, two stripes) answers the departure signal; due 18 Oct, morning high water. Signed for the Board; countersigned E. Venn.",
	"coat": "Venn's oilskin is soaked through. It has not rained today.",
	"hooks": "Nine hooks. His coat is on the seventh. The ninth is wet, with nothing on it.",
	"map": "The 1889 survey shows nine jetty pilings. I counted eight from the launch.",
	"chart": "The chart has been corrected in pencil: nine pilings.",
	"chart_tenth": "Later, a tenth piling inked in, past where the jetty ends.",
	"pilings_ten": "The chart shows ten pilings now. I counted nine an hour ago.",
	"soundings": "Venn has re-sounded the Sound in pencil. Every depth is deeper than in 1889, by the same amount everywhere. Past the ninth piling he wrote no number, only: 'no bottom at 400 fm. Line came up warm.'",
	"contours": "Venn's new contours close in rings. The centre of them is not the deep water. It is the ninth piling, at the end of this jetty.",
	"mug": "His mug is rinsed, a clean spoon laid across it.",
	"stove": "Stove cold. The ash raked smooth.",
	"lamp": "Desk lamp repaired: supply off, straight bridge B, supply on.",
	"note": "Pencil note under the duty card. At the bottom: \"Lamp service completed. A.M.\" My initials, gone dull as if written days ago. Also: register both chart sheets at the lighthouse cross; preserve the recording before winding again.",
	"shadow": "The chair's shadow falls toward the lamp.",
	"handwriting": "Venn's tide log is worked out to tomorrow, in advance. The last line is in my handwriting.",
	"silent": "The sea is still moving against the pilings. It no longer makes a sound.",
	"piling": "Nine pilings in the window now. The ninth is closer than the others.",
	"prints": "Bare, narrow footprints from the puddle to the desk drawer. None come back.",
	"watch": "Venn's watch, locked in the drawer, stopped at 18:52: the minute the log says I mend the lamp.",
	"photo": "A photograph of this window from outside, at night, dated 18 Oct: me at the desk. There is nothing outside the window to stand on.",
	"behind": "Through his lens: in the photograph, something pale and too tall stands behind my chair.",
	"rewritten": "New lines in the tide log, in my hand: \"She reads this line.\" \"She looks at the chair.\" \"HW 9.9 m. Observer located.\"",
	"seat": "The chair seat is wet, and still warm underneath.",
	"knock": "Three taps on the window glass, from outside. This room is on the second floor.",
	"palms": "Three wet palm marks on the outside of the window, below the sill line. The wall below goes straight into the sea.",
	"horizon": "The horizon outside is no longer level. The room is.",
	"eye": "A ring on the water past the pilings. It keeps its place against me.",
	"through": "It is not looking at the room. The room is what it looks through.",
	"tag": "A brass tag on the ninth hook, stamped A.M. It hangs at the height of my collar.",
	"hook_measures": "Brass tags on hooks one to eight, stamped with my numbers: ZERO 4, INT 3, PRESS 2, BEARING 3, HEIGHT 5 ft 6, REACH 5 ft 7, HAND R, STRIDE 2 ft 4. Every setting I entered, and some I never told anyone.",
	"away_mug": "Venn's mug is full to the brim with seawater. Nobody filled it.",
	"away_stove": "The stove is full of seawater, up into the flue. Its door was shut.",
	"away_coat": "The oilskin's hood is up, turned toward the desk.",
	"away_door": "Seawater seeps under the corridor door, from the corridor side.",
	"away_puddle": "Wet footprints go up the wall beside the door. None come down.",
	"away_window": "A fourth wet hand on the window, at the top of the glass, as if it had stood up.",
	"report": "Closure report, filed in my hand: pilings 10; observers on station 2; high water 18 Oct 19:34, 9.9 m.",
	"why_ada": "Venn asked for me because I wouldn't certify that Daniel Roe never existed. 'You have already refused to make a person disappear for the convenience of a form.' The photograph pinned itself to the board. On its back, in his hand: 'Not mine. It was in the developing tray on the 15th. She will need to see herself from outside. — E.V.'",
	"coat_collapsed": "Venn's oilskin has gone slack on its hook. An ordinary wet coat. Nobody is in it.",
}

## The observations Tide I can show her, all of them inside the office. The end card says
## nothing went unrecorded only when every one is in the notebook.
const REACHABLE_BY_T1X := ["duty", "contract", "coat", "hooks", "map", "chart", "chart_tenth",
	"soundings", "mug", "stove", "lamp", "note", "shadow", "handwriting", "silent", "piling",
	"prints", "watch", "photo", "behind", "rewritten", "seat", "knock", "palms", "report"]

## Venn's tide log. [date, time, tide, note, in_adas_hand]
## Strictly periodic: high water to high water is 12 h 21 m, low water falls 6 h 19 m
## after high. The drawer's hour can be worked out from the rhythm alone.
const LOG_ENTRIES := [
	["14 Oct", "04:25", "HW 3.8 m", "Wind SW, steady. Launch due 17th.", false],
	["14 Oct", "10:44", "LW 0.6 m", "Lamp bridge failing again.", false],
	["15 Oct", "05:07", "HW 3.9 m", "Spare B left in the tray for her.", false],
	["15 Oct", "11:26", "LW 0.5 m", "", false],
	["16 Oct", "05:49", "HW 4.1 m", "", false],
	["16 Oct", "12:08", "LW 0.4 m", "", false],
	["17 Oct", "06:31", "HW 4.3 m", "She arrives on the evening launch.", false],
	["17 Oct", "18:52", "HW 4.3 m", "She mends the lamp.", false],
	["18 Oct", "07:13", "HW 4.4 m", "Observer: A. Mercer", true],
]
## Row 7's time sits under a seawater stain until the drawer is open.
const BLOTTED_ROW := 7
const LOG_MARGIN := "HW to HW, 12 h 21 m. It never varies. — E.V."

## Lines the log writes for itself once Tide I's instruments are done.
const LOG_LATER := [
	["18 Oct", "07:13", "HW 4.4 m", "She reads this line.", true],
	["18 Oct", "—", "—", "She looks at the chair.", true],
	["18 Oct", "—", "HW 9.9 m", "Observer located.", true],
]
const LOG_FINAL := ["—", "—", "—", "She opens the door. It is already open.", true]

## Between the chair and the report, the log records what she does, in her hand.
const HISTORY_TEXT := {
	"coat": "She looks at the coat. It is fuller.",
	"window": "She looks at the window. It looks back.",
	"hooks": "She counts the hooks. There are nine. One is wet.",
	"map": "She counts the pilings. She gets ten.",
	"chair": "She looks at the chair again. It is not empty.",
	"puddle": "She follows her own feet.",
	"mug": "She touches the warm ring.",
	"stove": "She looks at the ash. It has been raked again.",
	"lamp": "She checks the lamp. It is still mended.",
	"tray": "She checks the lamp. It is still mended.",
	"drawer": "She looks at the photograph again.",
	"outer_door": "She tries the outer door. It is latched.",
	"service_door": "She tries the service door.",
	"barometer": "She taps the barometer. Nothing moves.",
	"receipt": "She reads a receipt for a mug.",
	"turn": "She turns her back on the desk.",
	"miss0": "She gets it wrong.",
	"miss1": "She gets it wrong again. The room is patient.",
	"miss2": "She guesses.",
}
const HISTORY_MAX := 3
const HISTORY_CLOSE := ["18 Oct", "—", "—", "She does not turn round.", true]

## Presentation lines the view plays at the threshold: [seconds after the door, text].
## They live here so the story text stays in one place and tests can see it.
const THRESHOLD_LINES := [
	[0.8, "The corridor is dark. It goes on further than the station does."],
	[3.4, "Something down there breathes in. The tide goes out with it, as far as the lighthouse."],
	[7.6, "It breathes out. Every piling in the Sound goes under at once."],
]
## Spoken when she has held still long enough (or at the fallback); only then can she go on.
const THRESHOLD_STILL_LINE := "I hold my breath. So does the sea."
const THRESHOLD_STILL_AFTER := 8.0
const THRESHOLD_FALLBACK := 18.0

## The Tide I card. Two rows write themselves in the log; which two depends on whether she
## turned. The core's tide card (Tide II) follows end_continue.
const END_LOG_ROW := "18 Oct  —  19:34  —  HW 9.9 m  —  Observer located."
const END_TURN_ROW := "18 Oct  —  19:34  —  She turns round."
const END_NEXT_ROW := "19 Oct  —  07:55  —  HW 4.4 m  —  Observer: E. Venn."
const END_NEXT_TURNED := "19 Oct  —  07:55  —  HW 4.4 m  —  Observer: A. Mercer."
const END_ON_STATION := "Observers on station: 1."
const END_ALL_SEEN := "Nothing in the room went unrecorded."
const NOTEBOOK_INTRUSION := "She will not finish this page."

const ROOM_IDS := HOTSPOTS

## What changes while she looks away, re-timed to the weather bands: [change, band]. Each
## applies on the first return to view A (from a close-up, the notebook, or another room)
## once its band is reached, one per return, in this order. Once applied it stays.
const LOOK_AWAY := [["mug", 2], ["door", 3], ["stove", 4], ["window", 5], ["puddle", 6], ["coat", 7]]
## The arrival notices the view holds for: the Tide I call-back and one per band.
const NOTICE_KEYS := ["callback", "b1", "b2", "b3", "b4", "b5", "b6", "b7"]

const LATCHED_LINE := "Latched. His rule's on the duty card: nobody leaves until the records reconcile."
const LATCHED_AGAIN := "Latched."
const SERVICE_NO_KEY := "The service door. Brass lock, keyhole on the kitchen side. Nothing on this side to turn."

## Barometer needle per band (degrees, 0 = up, clockwise; STORMY -120, RAIN -60, CHANGE 0,
## FAIR 60, VERY DRY 120).
const NEEDLE := [0, -55, -80, -118, -150, -168, 180, 180]
## The office clock per band after the threshold: [h, m, running].
const CLOCK_BANDS := [[7, 34, true], [9, 10, true], [11, 25, true], [1, 50, true],
	[3, 15, true], [5, 40, true], [7, 13, false], [7, 13, false]]

const SAVED_BOOLS := ["supply_on", "bridge_installed", "p01_complete", "log_read",
	"prints_seen", "drawer_open", "log_rewritten", "seat_wet", "foretold_door", "initialled",
	"finished", "report_filed", "history_seen", "soundings_heard",
	"heard_silence", "heard_unlatch", "contours_seen", "turned",
	"board_loaded", "board_stamped", "hook_tags_seen", "service_unlocked", "callback_heard",
	"latch_announced", "photo_changed_seen", "b_seen"]

# Transient presentation-adjacent state: never saved, reset in initial_state().
var facing := "A"           # "A" desk wall, "B" entry wall
var selected := ""          # spare selected in the repair close-up
var drawer_miss_n := 0      # rotates the drawer's generic refusal
var held_stamp := ""        # the stamp in her hand at the board
var photo_from := "drawer"  # where Back from the photograph goes
var photo_back := false     # the photograph turned over (after P20)

func initial_state() -> Dictionary:
	facing = "A"
	selected = ""
	drawer_miss_n = 0
	held_stamp = ""
	photo_from = "drawer"
	photo_back = false
	return {
		"supply_on": true, "bridge_installed": false, "p01_complete": false,
		"log_read": false, "prints_seen": false, "drawer_open": false, "log_rewritten": false,
		"seat_wet": false, "foretold_door": false, "initialled": false, "finished": false,
		"drawer_dial": [0, 0, 0, 0],
		"report_filed": false, "report_fields": [0, 0, 0], "report_time": [0, 0, 0, 0],
		"heard_unlatch": false,
		"history": [], "history_seen": false,
		"soundings_heard": false, "heard_silence": false, "photo_looks": 0,
		"contours_seen": false, "turned": false,
		"look_away_applied": [],
		"board_loaded": false, "board_pins": [], "board_stamped": false,
		"hook_tags_seen": false, "service_unlocked": false,
		"notices_seen": [], "callback_heard": false, "latch_announced": false,
		"photo_changed_seen": false, "b_seen": false,
	}

## Test convenience: a fresh game, as the slice's reset() was. Settings survive.
func reset(_keep_settings := false) -> void:
	game.reset()

# ---------------------------------------------------------------------------
# derived
# ---------------------------------------------------------------------------
func objective() -> String:
	if not state.finished:
		if not state.p01_complete: return "lamp"
		if not state.log_read: return "log"
		if not state.prints_seen and not state.drawer_open: return "changed"
		if not state.drawer_open: return "drawer"
		if not game.tide_done(1) and not state.log_rewritten: return "instruments"
		if not state.log_rewritten: return "reread"
		if not state.seat_wet: return "chair"
		if not state.report_filed: return "report"
		if not state.heard_unlatch: return "filed"
		return "leave"
	if game.tide_done(6) and not board_solved(): return "board"
	if game.flag("P06") and service_locked(): return "service"
	return "away_t%d" % maxi(game.tide(), 2)

## 0 arrival, 1 lamp lit, 2 log read (sea silent, prints, drawer), 3 seat wet (and after).
func stage() -> int:
	if state.seat_wet: return 3
	if state.log_read: return 2
	if state.p01_complete: return 1
	return 0

## The station's weather band, as the office shows it: Tide I is one night, so 0 until
## she is past the threshold.
func band() -> int:
	return game.weather_band() if state.finished else 0

## "", "sever" or "continue".
func ending() -> String:
	return str(game.value("ending_choice"))

func board_solved() -> bool:
	return state.board_stamped or game.flag("P20")

## True once the room has made its change for `id` (see LOOK_AWAY).
func look_away(id: String) -> bool:
	return id in state.look_away_applied

## The service door holds until the capsule's key has been turned in it once.
func service_locked() -> bool:
	return not game.flag("P06") or (game.has_item("service_key") and not state.service_unlocked)

## The print the photograph shows: the drawer original, then (from band 1) the one where
## the chair is empty, or the one where she has turned round.
func photo_variant() -> String:
	if band() == 0:
		return "drawer"
	return "turned" if state.turned else "after"

## The window shows a tenth piling past the jetty's end from the wet seat (the chart has it
## inked) until she is past the threshold: the report's pilings line can be seen, not guessed.
func tenth_piling_shown() -> bool:
	return state.seat_wet and not state.finished and ending() == ""

## Tide II in the office window: the sea pulled back to mud flats, the lighthouse out. From the
## threshold until P06 (the core's tide() is 2 exactly then).
func low_water() -> bool:
	return state.finished and ending() == "" and game.tide() == 2

## T1X: from the wet seat until she is past the threshold.
func _t1x() -> bool:
	return state.seat_wet and not state.finished

func is_closeup(v := local_view) -> bool:
	return v in ["repair", "logbook", "duty", "note", "drawer", "report", "board", "photo"]

## The office clock: [h, m, running].
func clock() -> Array:
	var e := ending()
	if e != "":
		return [7, 13, true]
	if not state.p01_complete:
		return [6, 40, true]
	if not state.finished:
		return [6, 52, true]
	return CLOCK_BANDS[band()].duplicate()

## The barometer needle, in degrees from straight up, clockwise.
func needle() -> int:
	match ending():
		"sever":
			return 30
		"continue":
			return 180
	return NEEDLE[band()]

## The tide log as it reads now. It grows as she does what it says. Rows are only
## ever appended (the blotted time is the one cell that changes in place), so the
## view can count the rows it has already written.
func log_rows() -> Array:
	var rows: Array = LOG_ENTRIES.duplicate(true)
	if not state.drawer_open:
		rows[BLOTTED_ROW][1] = ""
	if state.log_rewritten:
		rows.append_array(LOG_LATER)
	for id in state.history:
		rows.append(["18 Oct", "—", "—", HISTORY_TEXT[id], true])
	if state.report_filed:
		if not state.history.is_empty():
			rows.append(HISTORY_CLOSE)
		rows.append(LOG_FINAL)
	return rows

## The two log rows the Tide I card writes, as [text, hand]: hand is "her" or "venn".
## She does not turn: her row, then the next tide in his hand. She turns: both are hers.
func end_rows() -> Array:
	if state.turned:
		return [[END_TURN_ROW, "her"], [END_NEXT_TURNED, "her"]]
	return [[END_LOG_ROW, "her"], [END_NEXT_ROW, "venn"]]

## Lines for the Tide I card, in order. The tide line is the core's card, after it.
func end_lines() -> Array:
	var out := [END_ON_STATION]
	var all_seen := true
	for id in REACHABLE_BY_T1X:
		all_seen = all_seen and has_seen(id)
	if all_seen:
		out.append(END_ALL_SEEN)
	return out

## How many wrong filings the log has written down (0-3).
func report_misses() -> int:
	var n := 0
	for id in state.history:
		if id in MISS_IDS:
			n += 1
	return n

## A line in her notebook she did not write. Empty until the log has rewritten itself.
func notebook_intrusion() -> String:
	return NOTEBOOK_INTRUSION if state.log_rewritten else ""

func dial_code() -> Array:
	return state.drawer_dial.duplicate()

# ---------------------------------------------------------------------------
# events helper
# ---------------------------------------------------------------------------
## Says [[delay, text], ...] as one reveal: story lines when there is more than one.
func _chain(ev: Array, lines: Array) -> void:
	var story := lines.size() > 1
	for l in lines:
		_say(ev, l[1], l[0], story)

# ---------------------------------------------------------------------------
# actions
# ---------------------------------------------------------------------------
func act(action: String, ev: Array) -> void:
	# A room hotspot sent while a close-up is open (a driver or test; the views never do)
	# steps back first, with Back's own consequences, then acts on the room.
	if is_closeup() and ((facing == "A" and action in HOTSPOTS) or (facing == "B" and action in HOTSPOTS_B)):
		back(ev)
		if local_view == "room":
			act(action, ev)
		return
	match local_view:
		"room":
			if action == "turn":
				_turn(ev)
			elif facing == "A" and action in HOTSPOTS:
				_room(action, ev)
			elif facing == "B" and action in HOTSPOTS_B:
				_room_b(action, ev)
		"repair":
			_repair(action, ev)
		"drawer":
			_drawer(action, ev)
		"report":
			_report(action, ev)
		"duty", "note":
			if action == "read_contract":
				_read_contract(ev)
		"board":
			_board(action, ev)
		"photo":
			_photo(action, ev)
		"threshold":
			if action == "continue":
				state.finished = true
				local_view = "end"
				game.record_move("held_still")
				_sfx(ev, "motif")
			elif action == "turn":
				state.turned = true
				state.finished = true
				local_view = "end"
				game.record_move("turned_round")
				game.set_flag("t1x_turned")
				_sfx(ev, "exhale_near")
				_sfx(ev, "motif", 1.4)
				_fx(ev, "turn")
		"end":
			if action == "end_continue":
				# The Tide I card gives way to the Tide II card, and the corridor to the chart room.
				local_view = "room"
				facing = "A"
				game.solve("t1x_threshold_crossed", ev)
				# TODO(lead): use the public GameSim.travel() once the core exposes one.
				game._travel("R03", ev)

## The first arrival is the game's opening. Every arrival faces the desk, lets the room
## make one look-away change, and carries at most one notice for the view's arrival hold.
func arrive(ev: Array, first: bool) -> void:
	facing = "A"
	if first:
		_say(ev, "Greywake Survey Station. The launch won't be back for me until the morning tide.")
		_say(ev, "Power's out. The duty card says to start with the desk lamp.", 3.2)
		game.give("pencil", ev)
	_apply_look_away(ev)
	if game.tide_done(1) and not state.log_rewritten and not state.callback_heard:
		state.callback_heard = true
		_add_notice("callback")
		_sfx(ev, "pen_far", 0.4)
		ev.append({"type": "fx", "id": "notice", "key": "callback"})
	elif band() >= 1 and not ("b%d" % band()) in state.notices_seen:
		for b in range(1, band() + 1):
			_add_notice("b%d" % b)
		ev.append({"type": "fx", "id": "notice", "key": "b%d" % band()})
		if band() == 6:
			_sfx(ev, "clock_stop", 0.6)

func _add_notice(key: String) -> void:
	if not key in state.notices_seen:
		state.notices_seen.append(key)

## The next look-away change, if its band has come. One per call. Returns its id or "".
func _apply_look_away(ev: Array) -> String:
	for e in LOOK_AWAY:
		if e[0] in state.look_away_applied:
			continue
		if int(e[1]) <= band():
			state.look_away_applied.append(e[0])
			_observe("away_" + e[0])
			ev.append({"type": "fx", "id": "look_away", "change": e[0]})
			return e[0]
		return ""
	return ""

func exit_block(to: String) -> String:
	# Venn's rule: nobody leaves until the records reconcile.
	if _t1x():
		return _latch_line()
	if to in ["R03", "R04"] and not game.flag("P01"):
		return "The corridor is pitch black. Light first."
	if to in ["R05", "R06"] and service_locked():
		if not game.flag("P06"):
			return SERVICE_NO_KEY
		return "Locked. The kitchen key from the capsule should fit it."
	return ""

## Both doors share one announcement: the rule the first time, then just the latch.
func _latch_line() -> String:
	if not state.latch_announced:
		state.latch_announced = true
		return LATCHED_LINE
	return LATCHED_AGAIN

func back(ev: Array) -> void:
	var before := local_view
	_back_view(ev)
	# The room uses the moments she isn't looking at the desk. The board and the photograph
	# on it return her facing the entry wall, which doesn't count.
	if local_view == "room" and is_closeup(before) and facing == "A":
		_apply_look_away(ev)

func on_core_return(from: String, ev: Array) -> void:
	if from == "notebook" and local_view == "room" and facing == "A":
		_apply_look_away(ev)

func _back_view(ev: Array) -> void:
	match local_view:
		"logbook":
			local_view = "room"
			# The room changed while she was reading. Say nothing; let her hear it. Once.
			if state.log_read and not state.heard_silence:
				state.heard_silence = true
				_fx(ev, "sea_fade")
				_say(ev, "...Listen.", 2.2, true)
		"report":
			local_view = "room"
			# She signed it at the desk. Only when she steps back does the door answer.
			if state.report_filed and not state.heard_unlatch:
				state.heard_unlatch = true
				_sfx(ev, "latch_near", 0.2)
				_say(ev, "Behind me, the corridor door unlatched itself.", 0.6, true)
		"repair", "duty", "note", "drawer":
			local_view = "room"
			selected = ""
		"board":
			local_view = "room"
			held_stamp = ""
		"photo":
			local_view = photo_from
			photo_back = false
		"threshold", "end":
			pass   # there is no going back from the doorway; the card has its own button
		_:
			local_view = "room"

func _turn(ev: Array) -> void:
	if state.seat_wet and not state.report_filed:
		_record_history("turn")
	facing = "B" if facing == "A" else "A"
	_sfx(ev, "turn")
	if facing == "B" and not state.b_seen:
		state.b_seen = true
		_say(ev, "The entry wall. The way I came in.")

# ---------------------------------------------------------------------------
# view A
# ---------------------------------------------------------------------------
func _room(id: String, ev: Array) -> void:
	var s := stage()
	# Between the chair and the report, the log keeps her: the first three different
	# things she does are written down, in order, in her hand.
	if state.seat_wet and not state.report_filed:
		_record_history(id)
	match id:
		"lamp", "tray":
			local_view = "repair"
			if state.p01_complete:
				_say(ev, "The bridge is seated and the lamp is steady.")
			else:
				_say(ev, "A contact bridge has burnt through. There's a plate inside the shade.")
		"logbook":
			_logbook(ev)
		"papers":
			_papers(ev)
		"mug":
			_observe("mug")
			if look_away("mug"):
				_say(ev, "His mug is full to the brim. Seawater. I didn't fill it.")
			elif state.finished:
				_say(ev, "His mug, rinsed, the spoon across it. The ring on the desk is still warm.")
			elif s >= 2:
				_say(ev, "Two rings on the desk now. One is still warm.")
			else:
				_say(ev, "A chipped green mug, rinsed. A clean spoon laid across it. Someone tidied before they left.")
		"stove":
			_observe("stove")
			if look_away("stove"):
				_say(ev, "Water is seeping round the stove door. It's full, up into the flue. The door was shut the whole time.")
			elif s >= 2:
				_say(ev, "Raked smooth again. I didn't touch it.")
			else:
				_say(ev, "Cold through. The ash has been raked smooth, like a page nobody wrote on.")
		"map":
			_map(s, ev)
		"hooks":
			_hooks(s, ev)
		"window":
			_window(s, ev)
		"coat":
			_coat(s, ev)
		"drawer":
			local_view = "drawer"
			_sfx(ev, "dial")
			if state.drawer_open and board_solved():
				_say(ev, "His watch. The photograph has gone from the drawer.")
			elif state.drawer_open:
				_say(ev, "His watch and the photograph. I keep looking at the back of my own head.")
			else:
				_say(ev, "The right-hand drawer is locked. Four brass dials, and a plate: \"E.V. Open at the hour she mended it.\"")
		"puddle":
			if state.finished:
				_observe("prints")
				var lines := [[0.0, "The puddle. Two trails, dried to salt. One of them is mine."]]
				if look_away("puddle"):
					lines.append([2.0, "Wet footprints go up the wall beside the door. They don't come down."])
				_chain(ev, lines)
			elif s >= 3:
				_observe("prints")
				_say(ev, "There are two trails now.")
				_say(ev, "One goes to the drawer. One comes from the drawer to the door. The second one is my size.", 2.0, true)
			elif s == 2:
				var first_prints: bool = not state.prints_seen
				state.prints_seen = true
				_observe("prints")
				if first_prints:
					_fx(ev, "prints")
				_say(ev, "Bare feet. Narrow. From the puddle to the desk drawer.")
				_say(ev, "They don't come back.", 2.0, true)
			else:
				_say(ev, "Seawater, by the smell. It's run off the coat.")
		"chair":
			_chair(s, ev)
		"door":
			if state.finished:
				if look_away("door"):
					_say(ev, "Water is coming under the door from the corridor side. The corridor floor beyond is dry.")
				else:
					_say(ev, "A corridor. Forty feet of it, a mat, two doors at the end. It goes exactly as far as it should.")
			elif state.report_filed and state.heard_unlatch:
				local_view = "threshold"
				_sfx(ev, "door")
				_fx(ev, "threshold")
			elif state.seat_wet:
				_say(ev, _latch_line())
			elif s == 2:
				_say(ev, "The latches downstairs let go when the lamp came on. Something wanted the doors open before I did.")
			elif s == 1:
				_say(ev, "The corridor. The latches down there let go when the lamp came on.")
			else:
				_say(ev, "The corridor is pitch black. Light first.")

## Appends a room click to the log's record of her, up to HISTORY_MAX distinct lines.
## Miss rows (MISS_IDS) are written by the report itself and don't count against it.
func _record_history(id: String) -> void:
	if not HISTORY_TEXT.has(id) or id in MISS_IDS:
		return
	var n := 0
	for h in state.history:
		if not h in MISS_IDS:
			n += 1
	if n >= HISTORY_MAX:
		return
	for h in state.history:
		if HISTORY_TEXT[h] == HISTORY_TEXT[id]:
			return
	state.history.append(id)

func _papers(ev: Array) -> void:
	if state.seat_wet and not state.finished:
		local_view = "report"
		_sfx(ev, "page")
		if state.report_filed:
			_say(ev, "Filed. In my hand. I don't remember choosing the two.")
		elif state.report_fields != [0, 0, 0] or state.report_time != [0, 0, 0, 0]:
			_say(ev, "His closure report. Half reconciled.")
		else:
			_say(ev, "Under the duty card, his closure report. Blank. Four lines to reconcile before the station can be left.")
		return
	if state.p01_complete and game.tide_done(1) and not state.log_rewritten:
		# Back from the instruments: the desk has been touched, and the log is what changed.
		_observe("note")   # the note's evidence stays in the notebook either way
		_say(ev, "The duty card's been moved. Someone has written in the log since I left.")
		return
	if state.p01_complete:
		local_view = "note"
		_observe("note")
		_say(ev, "In the lamplight there's pencil beneath the duty card.")
		if not state.initialled:
			state.initialled = true
			_say(ev, "At the bottom: \"Lamp service completed. A.M.\"", 1.8, true)
			_say(ev, "That's my initial. The graphite's gone dull, like it's been there for days.", 4.0, true)
	else:
		local_view = "duty"
		_observe("duty")
		_say(ev, "Closure duty. Inventory, reconcile, restore the signal. Begin with the lamp.")
	_sfx(ev, "page")

## c_duty / c_note: the contract under the card.
func _read_contract(ev: Array) -> void:
	if has_seen("contract"):
		_say(ev, "My contract. Two stripes on the pennant. Do not certify what I have not seen.")
		return
	_observe("contract")
	_sfx(ev, "page")
	_chain(ev, [
		[0.0, "The contract, under his card. Addressed to me by name: Miss Ada Mercer, cataloguer."],
		[2.6, "'Do not certify an observation you have not made.' Underlined, in his ink."],
		[5.2, "The launch that collects me flies two stripes. It answers the departure signal."],
	])

func _map(s: int, ev: Array) -> void:
	if s >= 2 and state.drawer_open and not state.soundings_heard:
		# The scale of it: the whole floor of the Sound is going down, evenly.
		state.soundings_heard = true
		_observe("chart")
		_observe("soundings")
		_say(ev, "He's re-sounded the whole Sound. Every depth is greater than it was in 1889.", 0.0, true)
		_say(ev, "Not by much. By the same amount, everywhere. As if the bottom were being drawn down.", 2.8, true)
		_sfx(ev, "deep", 5.6)
		_say(ev, "Past the ninth piling there's no figure. 'No bottom at four hundred fathoms. Line came up warm.'", 6.0, true)
		if state.seat_wet:
			_observe("chart_tenth")
			_say(ev, "And someone has inked a tenth piling, further out than the jetty goes.", 9.0, true)
			if objective() == "report":
				_observe("pilings_ten")
				_say(ev, PILINGS_TEN_LINE, 11.6, true)
	elif band() >= 4 and state.soundings_heard and not state.contours_seen:
		# The Sound is not a basin. It is an eye, and the jetty runs out to its pupil.
		state.contours_seen = true
		_observe("contours")
		_fx(ev, "contours")
		_sfx(ev, "deep", 4.8)
		_say(ev, "His new contours don't follow the coast. They go round.", 0.0, true)
		_say(ev, "Ring inside ring, closing on the jetty. The ninth piling is the middle.", 2.6, true)
		_say(ev, "The station is built on the edge of it. Like a lash.", 5.4, true)
	elif s >= 2:
		_observe("chart")
		if not state.seat_wet:
			_say(ev, "The chart has been corrected. In pencil. Nine.")
		elif objective() == "report":
			# The report's first witness, fair at the moment it is asked for.
			_observe("chart_tenth")
			_observe("pilings_ten")
			_say(ev, PILINGS_TEN_LINE)
		else:
			_observe("chart_tenth")
			_say(ev, "Someone has inked a tenth piling. Further out than the jetty goes.")
	else:
		_observe("map")
		_say(ev, "Morrow Sound, surveyed 1889. The jetty has nine pilings. I counted eight from the launch.")

func _hooks(s: int, ev: Array) -> void:
	_observe("hooks")
	if band() >= 6:
		if not state.hook_tags_seen:
			state.hook_tags_seen = true
			_observe("tag")
			_observe("hook_measures")
			_chain(ev, [
				[0.0, "There are brass tags on the hooks now. Stamped, like luggage."],
				[2.4, "ZERO 4. INT 3. PRESS 2. BEARING 3. Every setting I've entered in this station."],
				[5.4, "Five foot six. Five foot seven. R. Two foot four. My height, my reach, my hand, my stride."],
				[8.6, "The ninth says A.M. It hangs at the height of my collar."],
			])
		else:
			_say(ev, "My numbers on his hooks. The ninth one is mine.")
	elif state.seat_wet:
		_say(ev, "Nine hooks. The ninth is wet again. Nothing has hung on it.")
	elif s == 2:
		_say(ev, "Nine hooks. The ninth is wet again. I dried it with my sleeve an hour ago.")
	else:
		_say(ev, "Nine hooks. His coat's on the seventh. The ninth is wet, and nothing is hanging on it.")

func _coat(s: int, ev: Array) -> void:
	_observe("coat")
	var b := band()
	match ending():
		"sever":
			_say(ev, "An ordinary wet coat.")
			return
		"continue":
			_observe("coat_collapsed")
			_say(ev, "It has gone slack on the hook. An ordinary wet coat. Nobody is in it.")
			return
	if look_away("coat"):
		_chain(ev, [[0.0, "The hood is up. It's facing the desk."],
			[2.0, "There are shoulders in it. Nobody is wearing it."]])
	elif board_solved():
		_say(ev, "It said yes. I'm not going to ask it anything else.")
	elif b >= 4:
		_say(ev, "The shoulders have shape now. I am not going to touch it.")
	elif b >= 1:
		_say(ev, "Heavier at the shoulders again. It has dripped onto the same spot for hours.")
	elif state.log_rewritten:
		_say(ev, "It hangs differently. Heavier at the shoulders.")
	elif s == 2:
		_say(ev, "Still dripping. Onto the same spot, every time. Like it's being counted.")
	else:
		_say(ev, "Venn's oilskin, soaked through. It hasn't rained since I landed.")

func _logbook(ev: Array) -> void:
	local_view = "logbook"
	_sfx(ev, "page")
	if not state.p01_complete:
		_say(ev, "Venn's tide log. The ink is too faint to read by torchlight.")
		return
	var first: bool = not state.log_read
	state.log_read = true
	_observe("handwriting")
	if first:
		game.record_move("log_read")
		_say(ev, "He's worked out the tides to tomorrow. In advance.", 0.0, true)
		_say(ev, "And the last line... that's my handwriting.", 1.4, true)
		_say(ev, "One of the times is under a tide-stain. His margin note isn't.", 3.0, true)
		_fx(ev, "dread")
	elif state.drawer_open and game.tide_done(1) and not state.log_rewritten:
		state.log_rewritten = true
		_observe("rewritten")
		_fx(ev, "log_write")
		_sfx(ev, "motif_short", 0.4)
		_say(ev, "There are new lines. In my hand. The ink is still wet.", 0.0, true)
		_say(ev, "\"She looks at the chair.\" I haven't looked at it yet.", 2.4, true)
		_say(ev, "HW nine point nine. Nothing in forty years of this log has come above four and a half.", 4.8, true)
		_say(ev, "I check the date on it. Tomorrow.", 7.4, true)
	elif state.seat_wet and not state.report_filed and not state.history.is_empty() \
			and not state.history_seen:
		state.history_seen = true
		_fx(ev, "log_write")
		_say(ev, "It has written down what I did since the chair. In the order I did it.", 0.0, true)
		_say(ev, "It was writing while I did it.", 2.6, true)
	elif state.report_filed and not state.foretold_door:
		state.foretold_door = true
		_fx(ev, "log_write")
		_say(ev, "It has the next line already.", 0.0, true)
	elif state.foretold_door:
		_say(ev, "The line about the door is dry now. It's been there a long time.")
	elif state.log_rewritten:
		_say(ev, "Observer located. I am the only one here to locate.")
	else:
		_say(ev, "Observer: A. Mercer. In my hand. I have never seen this book.")

func _window(s: int, ev: Array) -> void:
	match ending():
		"sever":
			_say(ev, "Grey water, and daylight. A launch is coming in past the lighthouse.")
			return
		"continue":
			_say(ev, "The dark surface, close to the glass. The desk is lit.")
			return
	if not state.seat_wet:
		if s == 2:
			_observe("silent")
			_observe("piling")
			_say(ev, "The sea is still moving. It has stopped making a sound, the way a person stops talking when you come into a room.")
			if state.drawer_open:
				_say(ev, "The ninth piling is nearer again. I don't think it is a piling.", 3.6, true)
			else:
				_say(ev, "There are nine pilings now. The ninth is closer than the others.", 3.6, true)
		elif s == 1:
			_say(ev, "Dark enough now that the glass shows the lamp more than the sea.")
		else:
			_say(ev, "The launch is already past the lighthouse. Nobody else is coming tonight.")
		return
	var b := band()
	var lines: Array = []
	match b:
		0:
			_observe("silent")
			_observe("piling")
			if low_water():
				lines.append([0.0, LOW_WATER_LINE])
			elif tenth_piling_shown():
				lines.append([0.0, "Ten pilings now. The sea moving against them, without a sound."])
			else:
				lines.append([0.0, "Nine pilings. The sea moving against them, without a sound."])
		1:
			lines.append([0.0, "Rain on the glass now. The cloud has come down to the water."])
		2:
			lines.append([0.0, "Heavier rain. The end of the jetty has gone into it. Damp is coming through under the sill."])
		3:
			_observe("horizon")
			lines.append([0.0, "The rain is falling slower than rain falls."])
			lines.append([2.6, "The horizon isn't level. The house is."])
		4:
			_observe("horizon")
			_observe("eye")
			lines.append([0.0, "There's a ring on the water, out past the pilings. When I move, it moves."])
			lines.append([2.6, "I step to the left. It is still in the middle of the glass."])
		5:
			_observe("horizon")
			_observe("eye")
			lines.append([0.0, "Rain on the glass, and no sound of it. Sea and sky are one colour."])
			lines.append([2.6, "The ring is still there. Still in the middle."])
		6:
			_observe("horizon")
			_observe("eye")
			lines.append([0.0, "The ring has come in to the end of the jetty. It is the size of this window."])
		_:
			_observe("horizon")
			_observe("eye")
			lines.append([0.0, "There is no sea. Something dark stands where it was, close to the glass."])
			lines.append([2.6, "Now and then, very slowly, it moves. The desk is still lit."])
	if has_seen("knock") and not has_seen("palms"):
		_observe("palms")
		lines.append([lines.back()[0] + 2.8, "There are marks on the outside of the glass, low down. Three. And the heel of a hand."])
	if look_away("window"):
		lines.append([lines.back()[0] + 2.8, "There's a fourth hand now. At the top of the glass."])
	if b >= 4 and state.contours_seen and not has_seen("through"):
		_observe("through")
		lines.append([lines.back()[0] + 2.8, OBSERVATIONS["through"]])
	_chain(ev, lines)

func _chair(s: int, ev: Array) -> void:
	if state.finished:
		if band() >= 7:
			_say(ev, "The cushion is pressed down again. Fresh, and cold.")
		elif state.turned:
			_say(ev, "Venn's chair. I turned round to it once. I won't again.")
		else:
			_say(ev, "Venn's chair. Dry now. It keeps the shape of someone who sat very still.")
	elif s == 0:
		_say(ev, "Venn's chair. The cushion keeps the shape of someone who sat very still.")
	elif state.seat_wet:
		_say(ev, "The seat is wet. Still warm underneath.")
	elif state.log_rewritten:
		state.seat_wet = true
		_observe("shadow")
		_observe("seat")
		_fx(ev, "seat_hush")   # no stinger: the room goes silent around the wet seat
		_say(ev, "The seat is wet. Still warm underneath.", 0.0, true)
		_sfx(ev, "knock_glass", 3.4)
		_observe("knock")
		_say(ev, "Three taps on the glass.", 4.4, true)
		_say(ev, "Low down. Below the sill. Where the wall goes straight down into the water.", 6.6, true)
	else:
		_observe("shadow")
		_say(ev, "Its shadow falls toward the lamp.")
		if state.prints_seen:
			_say(ev, "The prints don't go near it. Not yet.", 1.8)

# ---------------------------------------------------------------------------
# view B
# ---------------------------------------------------------------------------
func _room_b(id: String, ev: Array) -> void:
	if state.seat_wet and not state.report_filed:
		_record_history(id)
	match id:
		"outer_door":
			_say(ev, _outer_door_line())
		"service_door":
			if not game.flag("P06"):
				_say(ev, SERVICE_NO_KEY)
			elif service_locked():
				_say(ev, "Locked from the kitchen side. The key from the capsule should fit.")
			elif band() <= 2:
				_say(ev, "The service door, unlocked. The passage beyond smells of soup.")
			else:
				_say(ev, "The service door. The passage smells of soup. Nobody has cooked for days.")
		"board":
			if board_solved():
				local_view = "board"
				_say(ev, "My name, my name, my sentence. And the photograph, which I didn't pin.")
			elif state.board_loaded:
				local_view = "board"
				_say(ev, "His letters, the inquiry clipping and the contract. Three pins and a thread.")
			elif game.has_item("venn_correspondence"):
				_say(ev, "A comparison board. Venn's letters would go on it, side by side with the contract.")
			else:
				_say(ev, "A comparison board. Cork, three pins, a rail of rubber stamps. Nothing pinned to it.")
		"barometer":
			_sfx(ev, "baro_tap")
			_say(ev, _barometer_line())
		"receipt":
			if not state.p01_complete:
				_say(ev, "A paper pinned by the door. Too dark to read.")
			elif not game.flag("o01_found"):
				game.set_flag("o01_found")
				_sfx(ev, "page")
				_chain(ev, [
					[0.0, "A contractor's receipt, pinned by the door. 'To mending one green enamel mug, chipped at the lip: 1s 4d. New mug, if preferred: 9d.'"],
					[2.6, "He paid the one and four."],
					[4.4, "Under it, in his hand: 'Some things you keep because they have been used.'"],
				])
			else:
				_say(ev, "The mug receipt. One and four, to keep a chipped mug.")

func _outer_door_line() -> String:
	if _t1x():
		return _latch_line()
	if ending() == "sever":
		return "Grey water. A launch with two stripes on its pennant."
	if not state.p01_complete:
		return "The outer door. Through its glass, the launch going out past the lighthouse."
	if not state.finished:
		return "The jetty, in the dark. The bell on its post hangs too low."
	match band():
		0:
			if game.flag("P05") and not game.flag("P06"):
				return "There's a launch at the jetty. It isn't moving. The water is."
			return "The jetty, in the dark. The bell on its post hangs too low."
		1:
			return "Rain on the jetty. The capsule hangs open on the mooring line."
		2:
			return "The far end of the jetty has gone into the rain."
		3:
			return "The pilings' reflections are late. And there's a tenth, past the end."
		4:
			return "Out there, the horizon tilts up toward the station."
		5:
			return "Sea and sky are one colour. The lighthouse has gone."
		6:
			return "The lighthouse light is falling on the jetty from behind the station."
	return "Where the sea was, something dark stands up off the end of the jetty. The jetty is still lit."

func _barometer_line() -> String:
	if ending() != "":
		return "The clock is going again."
	if not state.p01_complete:
		return "A barometer in a brass case, a clock above it. Twenty to seven. The needle sits on CHANGE."
	if not state.finished:
		return "Eight minutes to seven, the minute I mended the lamp. The second hand goes round. The minute hand doesn't."
	match band():
		0:
			return "Twenty-six minutes to eight. The clock has caught up with the tide I signed for."
		1:
			return "Ten past nine. The needle has gone over to RAIN. It is raining."
		2:
			return "Twenty-five past eleven. RAIN, and falling."
		3:
			return "Ten to two. The needle is at STORMY, and still going."
		4:
			return "A quarter past three. The needle has gone past STORMY, onto the bare brass. Someone has scratched a mark there."
		5:
			return "Twenty to six. The needle is nearly upside down."
		6:
			return "The clock has stopped. Thirteen minutes past seven: the morning tide, when the launch was due. The needle points straight down."
	return "Still thirteen past seven. The needle points down, at the floor. When I tap the glass, something presses back."

# ---------------------------------------------------------------------------
# P20: the comparison board (c_board)
# ---------------------------------------------------------------------------
func _board(action: String, ev: Array) -> void:
	match action:
		"read_contract":
			_say(ev, "The contract. My name, my duties, his countersignature.")
			return
		"read_clipping":
			_say(ev, "Morrow Harbour Board, 1929. The inquiry into Daniel Roe, dockworker, reported missing. Three signatures. Mine is the one that dissents.")
			return
		"read_letter":
			_say(ev, "His letter to the Board, never sent. He asks for me by name, and quotes me to them.")
			return
		"seal":
			if board_solved():
				_say(ev, "'You have already refused to make a person disappear for the convenience of a form.'")
			else:
				_say(ev, "Sealed with his three-cut seal. It won't lift.")
			return
	var board_control: bool = MARKS.has(action) or STAMPS.has(action) or action == "provenance" \
		or action in ["slot_0", "slot_1", "slot_2"]
	if board_solved():
		if board_control:
			_say(ev, BOARD_DONE)
		elif action == "photo":
			local_view = "photo"
			photo_from = "board"
			_photo_look(ev)
		return
	var pins: Array = state.board_pins
	if MARKS.has(action):
		var at := pins.find(action)
		if at >= 0:
			pins.remove_at(at)
			_sfx(ev, "unpin")
		elif pins.size() >= BOARD_SLOTS:
			_say(ev, "Three pins. Take one out first.")
		else:
			pins.append(action)
			_sfx(ev, "pin")
	elif action in ["slot_0", "slot_1", "slot_2"]:
		var i := int(action.substr(5))
		if i < pins.size():
			pins.remove_at(i)
			_sfx(ev, "unpin")
	elif STAMPS.has(action):
		held_stamp = "" if held_stamp == action else action
	elif action == "provenance":
		_provenance(ev)

## The board's refusal for the current pins and stamp, in the card's order, or "" to commit.
func board_refusal(pins: Array, stamp: String) -> String:
	if pins.size() < BOARD_SLOTS:
		return "The thread has to run all the way. Three pins first."
	if "m_callis" in pins or "m_orme" in pins:
		return "Their signatures don't carry the sentence. Mine does."
	if "m_countersign" in pins:
		return "That's his name, not mine. The thread follows mine."
	if pins != BOARD_ANSWER:
		return "The name went from the contract, to the inquiry, to his letter. The thread should go the same way."
	if stamp == "stamp_board":
		return "The Board didn't assign me. He asked."
	if stamp == "stamp_unknown":
		return "It isn't unknown. It's in his letter, in his hand."
	return ""

func _provenance(ev: Array) -> void:
	if held_stamp == "":
		_say(ev, "Pick a stamp from the rack first.")
		return
	var refusal := board_refusal(state.board_pins, held_stamp)
	if refusal != "":
		held_stamp = ""
		_sfx(ev, "stamp_dry")
		_say(ev, refusal)
		return
	state.board_stamped = true
	held_stamp = ""
	game.solve("P20", ev)
	_observe("why_ada")
	_sfx(ev, "stamp", 0.0)
	_sfx(ev, "seal", 1.6)
	_sfx(ev, "oilskin", 11.0)
	_sfx(ev, "pin", 16.6)
	_fx(ev, "p20_solved")
	_chain(ev, [
		[0.0, "Requested by Venn."],
		[1.6, "The seal on his letter has cracked by itself. There's a paragraph under it."],
		[3.8, "'You have already refused to make a person disappear for the convenience of a form.'"],
		[6.6, "You could have asked."],
		[8.6, "You knew I would finish the work before I understood what it was."],
		[11.4, "Behind me, from the oilskin on the seventh hook, very quietly: 'Yes.'"],
		[14.0, "A pause. 'I was afraid you would be kinder than me. I was also counting on it.'"],
		[17.0, "The photograph from his drawer is pinned to the board. I didn't pin it."],
		[19.6, "On the back, in his hand: 'Not mine. It was in the developing tray on the 15th. She will need to see herself from outside. — E.V.'"],
	])

# ---------------------------------------------------------------------------
# c_photo
# ---------------------------------------------------------------------------
func _photo(action: String, ev: Array) -> void:
	match action:
		"photo":
			_photo_look(ev)
		"turn_over":
			if board_solved():
				photo_back = not photo_back
				if photo_back:
					_say(ev, "His hand, on the back.")

## One look at the print. In Tide I a second look finds what is behind her chair; from
## band 1 the print has changed, and says so once.
func _photo_look(ev: Array) -> void:
	if band() == 0:
		state.photo_looks = mini(int(state.photo_looks) + 1, 9)
		if int(state.photo_looks) == 1:
			_say(ev, "Me, from outside. From the sea side.")
		else:
			_observe("behind")
			_say(ev, "I hold his lens over it. There is someone behind me in this. There is no one behind me now.")
	elif not state.photo_changed_seen:
		state.photo_changed_seen = true
		if photo_variant() == "turned":
			_chain(ev, [[0.0, "The photograph has changed. In it I have turned round in the chair, to face the camera."],
				[2.4, "There is nothing on the front of my head."]])
		else:
			_chain(ev, [[0.0, "The photograph has changed. The chair in it is empty."],
				[2.4, "In the lower pane there's a lit window. In the window, this photograph."]])
	else:
		_say(ev, "The photograph. It stays changed.")

# ---------------------------------------------------------------------------
# drawer, report, repair
# ---------------------------------------------------------------------------
func _drawer(action: String, ev: Array) -> void:
	match action:
		"dial_0", "dial_1", "dial_2", "dial_3", "dial_down_0", "dial_down_1", "dial_down_2", "dial_down_3":
			if state.drawer_open:
				return
			var i := int(action.substr(action.length() - 1))
			var step := 9 if action.begins_with("dial_down") else 1
			state.drawer_dial[i] = (int(state.drawer_dial[i]) + step) % 10
			_sfx(ev, "dial")
		"try_drawer":
			if state.drawer_open:
				return
			var code: Array = state.drawer_dial
			if code == DRAWER_CODE and state.log_read:
				state.drawer_open = true
				game.record_move("drawer_opened")
				_observe("watch")
				_observe("photo")
				_sfx(ev, "drawer")
				_sfx(ev, "motif_short", 1.0)
				_fx(ev, "drawer_open")
				_say(ev, "It gives.", 0.0, true)
				_say(ev, "Venn's watch. Stopped at eight minutes to seven.", 1.4, true)
				_say(ev, "Eighteen fifty-two. He stopped it at the minute I mended the lamp. Three days before I got here.", 3.8, true)
				_say(ev, "And a photograph.", 7.0, true)
				_say(ev, "This window, from outside, at night. Someone at the desk under the lamp.", 8.6, true)
				_say(ev, "That's my coat. That's me.", 11.2, true)
				_say(ev, "There is nothing outside this window to stand on.", 13.4, true)
				# P03 part 1: his second tide sheet and his lens were in there too.
				game.give("venn_tide_sheet", ev)
				game.give("inspection_lens", ev)
			else:
				_sfx(ev, "clunk")
				_say(ev, _drawer_miss(code))
		"look_watch":
			if state.drawer_open:
				_say(ev, "Stopped at 18:52.")
		"look_photo":
			if not state.drawer_open:
				return
			if board_solved():
				_say(ev, "The photograph has gone from the drawer. It's on the board, by the door.")
				return
			local_view = "photo"
			photo_from = "drawer"
			_photo_look(ev)

## What a wrong code earns: near misses are answered, the rest just clunk.
func _drawer_miss(code: Array) -> String:
	if code == DRAWER_CODE:
		return "Nothing. Whatever hour he means, I don't know it yet."
	if code == [0, 7, 1, 3]:
		return "07:13 is tomorrow. He wants the hour it already happened."
	if code == [1, 9, 3, 1]:
		return "The year won't do it. He wants an hour."
	if code == [1, 2, 5, 0]:
		return "Twelve fifty is low water. The lamp was mended on the flood."
	if code == [0, 6, 3, 1]:
		return "06:31 is the morning tide. I came in on the evening one."
	if code == [1, 8, 5, 4]:
		return "Close. His arithmetic is better than mine."
	if code.slice(0, 3) == [1, 8, 5]:
		return "Eighteen fifty-something. The last figure is under the stain. His margin gives it to the minute."
	var line: String = DRAWER_REFUSALS[drawer_miss_n % DRAWER_REFUSALS.size()]
	drawer_miss_n += 1
	return line

const DRAWER_REFUSALS := ["The drawer doesn't give.", "Still nothing.", "The dials are cold. The drawer isn't."]

func _report(action: String, ev: Array) -> void:
	match action:
		"field_0", "field_1", "field_2":
			if state.report_filed:
				return
			var i := int(action.substr(6))
			var n: int = REPORT_FIELDS[i][1].size()
			state.report_fields[i] = (int(state.report_fields[i]) + 1) % n
			_sfx(ev, "nib")
		"rtime_0", "rtime_1", "rtime_2", "rtime_3", "rtime_down_0", "rtime_down_1", "rtime_down_2", "rtime_down_3":
			if state.report_filed:
				return
			var i := int(action.substr(action.length() - 1))
			var step := 9 if action.begins_with("rtime_down") else 1
			state.report_time[i] = (int(state.report_time[i]) + step) % 10
			_sfx(ev, "dial")
		"file_report":
			if state.report_filed:
				return
			if state.report_fields == REPORT_ANSWER and state.report_time == REPORT_TIME_ANSWER:
				state.report_filed = true
				game.record_move("report_signed")
				game.set_flag("closure_report_filed")
				_observe("report")
				_sfx(ev, "sign")
				_say(ev, "I sign it. A. Mercer, observer.", 0.0, true)
				_say(ev, "The two is in my hand. I wrote it without counting.", 2.2, true)
				_sfx(ev, "motif_short", 2.6)
			else:
				# Never say which line is wrong: the notebook holds every witness. The log,
				# though, writes the mistake down, in her hand, the first three times.
				var n := report_misses()
				if n < MISS_IDS.size():
					state.history.append(MISS_IDS[n])
				_sfx(ev, "page")
				_say(ev, report_time_miss(state.report_time))
				if n == 0:
					_fx(ev, "log_write")
					_say(ev, "Somewhere on the desk, a pen is moving.", 1.6, true)
				elif n == MISS_IDS.size() - 1:
					_say(ev, "It is writing down my mistakes. It wants the right numbers more than I do.", 2.0, true)

## The answer a wrong filing gets: a near-miss time has its own, everything else doesn't reconcile.
static func report_time_miss(t: Array) -> String:
	var key := ""
	for d in t:
		key += str(int(d))
	return REPORT_TIME_MISSES.get(key, "Something here doesn't reconcile.")

func _repair(action: String, ev: Array) -> void:
	match action:
		"toggle_supply":
			if state.p01_complete:
				_say(ev, "Leave it. I want the light.")
				return
			state.supply_on = not state.supply_on
			_sfx(ev, "switch")
			if state.supply_on and state.bridge_installed and not state.p01_complete:
				state.p01_complete = true
				_observe("lamp")
				game.record_move("lamp_mended")
				game.solve("P01", ev)
				local_view = "room"
				selected = ""
				_fx(ev, "lamp_on")
				_sfx(ev, "latch_far", 1.3)
				_say(ev, "Light.", 0.35, true)
				_say(ev, "And somewhere down the corridor, two latches let go.", 1.6, true)
			elif state.supply_on:
				_say(ev, "Supply on. Nothing. The circuit's still open.")
			else:
				_say(ev, "Supply off. Safe to work on it.")
		"select_b":
			if state.bridge_installed:
				_say(ev, "Bridge B is already seated.")
			else:
				selected = "B"
				_say(ev, "Bridge B. Straight, two contacts.")
		"select_c":
			selected = "C"
			_say(ev, "Spare C. Curved, two contacts.")
		"fit":
			if state.bridge_installed:
				_say(ev, "The bridge is seated. It wants power.")
			elif selected == "":
				_say(ev, "Pick a spare from the tray first.")
			elif state.supply_on:
				# A jolt, not a punishment: nothing is consumed or lost.
				_fx(ev, "spark")
				_sfx(ev, "spark")
				_say(ev, "Ah! It bit me. Supply off first, Mercer.")
			elif selected == "C":
				_sfx(ev, "clink")
				_say(ev, "The curve won't lie flat across both terminals.")
			else:
				state.bridge_installed = true
				selected = ""
				_sfx(ev, "seat")
				_say(ev, "Bridge B seats with a click. Now the supply.")

# ---------------------------------------------------------------------------
# inventory
# ---------------------------------------------------------------------------
func use_item(item: String, target: String, ev: Array) -> bool:
	if item == "service_key" and target in ["go:R05", "go:R06"] and local_view == "room" \
			and game.flag("P06") and service_locked():
		# The kitchen and bunk tabs are the service door's way out: the key goes in that door.
		return _service_key_turn(ev)
	var on_a: bool = local_view == "room" and facing == "A" and target in HOTSPOTS
	var on_b: bool = local_view == "room" and facing == "B" and target in HOTSPOTS_B
	match item:
		"service_key":
			if on_b and target == "service_door" and game.flag("P06") and service_locked():
				return _service_key_turn(ev)
			if on_a and target == "door":
				_say(ev, "Wrong door. This one has no keyhole on this side.")
				return true
			if on_b and target == "outer_door":
				_say(ev, "That door isn't locked.")
				return true
		"venn_correspondence":
			if on_b and target == "board":
				_load_board(ev)
				return true
		"inspection_lens":
			if local_view == "photo" and target == "photo":
				if band() == 0:
					_observe("behind")
					_say(ev, "I hold his lens over it. There is someone behind me in this. There is no one behind me now.")
				else:
					_say(ev, "Through the lens: the same changed print. Sharper.")
				return true
			if on_a:
				match target:
					"window":
						_say(ev, "Through the lens the far water is sharper. It doesn't make it any smaller.")
						return true
					"map":
						_say(ev, "Under the lens his pencil is pressed hard into the paper, as if he was afraid it would fade.")
						return true
					"hooks":
						if band() >= 6:
							_say(ev, "The stamping is fresh. The brass under it isn't.")
						else:
							_say(ev, "Brass hooks. Salt in the screw heads.")
						return true
					"coat":
						_say(ev, "Salt dried in the seams. Under it, the oilskin is wet from the inside.")
						return true
			if on_b:
				match target:
					"barometer":
						_say(ev, "Behind the glass, the needle's pivot is green with salt.")
						return true
					"receipt":
						_say(ev, "The contractor's stamp: MORROW HARBOUR REPAIRS. Paid in full.")
						return true
		"venn_tide_sheet":
			if on_a and target == "map":
				_say(ev, "His sheet goes with the chart room's sheet, not this chart.")
				return true
	return false

func _service_key_turn(ev: Array) -> bool:
	game.take("service_key")
	state.service_unlocked = true
	_sfx(ev, "lock_turn")
	_chain(ev, [[0.0, "The key turns."],
		[1.6, "From the kitchen end of the passage, the smell of soup. Nobody has cooked here for days."]])
	return true

func _load_board(ev: Array) -> void:
	if not game.tide_done(6):
		_say(ev, "Not yet. I don't know what I'm comparing them against.")
	elif state.board_loaded or board_solved():
		_say(ev, "They're already on the board.")
	else:
		# The contract goes up with the letters: unread until now, she reads it as she pins it.
		_observe("contract")
		state.board_loaded = true
		local_view = "board"
		_sfx(ev, "pin", 0.0)
		_sfx(ev, "pin", 0.3)
		_sfx(ev, "pin", 0.6)
		_say(ev, "I pin up his letters and the inquiry clipping, and fetch the contract from the desk.")

## The ending flow (the lead or R12) tells the office which ending she chose.
func apply_ending(choice: String) -> void:
	if choice == "continue":
		_observe("coat_collapsed")

# ---------------------------------------------------------------------------
# hints
# ---------------------------------------------------------------------------
## At the threshold the hint ladder steps aside: there is only one thing to do.
func hint_frozen() -> bool:
	return local_view == "threshold"

func hint_line(level: int) -> String:
	if local_view == "threshold":
		return THRESHOLD_HINT
	return HINTS[objective()][mini(level, 2)]

func objective_text() -> String:
	return OBJECTIVES[objective()]

# ---------------------------------------------------------------------------
# persistence
# ---------------------------------------------------------------------------
## Restores R02's local state from a saved dict (or a slice save, migrated by the core),
## ignoring anything malformed. Global flags are already loaded when this runs.
func load_state(d: Variant) -> void:
	state = initial_state()
	if not d is Dictionary:
		return
	for key in SAVED_BOOLS:
		if d.get(key) is bool:
			state[key] = d[key]
	var dial = d.get("drawer_dial")
	if dial is Array and dial.size() == 4:
		if _all_whole(dial):
			state.drawer_dial = [clampi(int(dial[0]), 0, 9), clampi(int(dial[1]), 0, 9),
				clampi(int(dial[2]), 0, 9), clampi(int(dial[3]), 0, 9)]
	var fields = d.get("report_fields")
	if fields is Array and fields.size() == REPORT_FIELDS.size() and _all_whole(fields):
		for i in fields.size():
			state.report_fields[i] = clampi(int(fields[i]), 0, REPORT_FIELDS[i][1].size() - 1)
	var rtime = d.get("report_time")
	if rtime is Array and rtime.size() == 4 and _all_whole(rtime):
		state.report_time = [clampi(int(rtime[0]), 0, 9), clampi(int(rtime[1]), 0, 9),
			clampi(int(rtime[2]), 0, 9), clampi(int(rtime[3]), 0, 9)]
	if d.get("history") is Array:
		for hid in d.history:
			if not hid is String:
				continue
			if hid in MISS_IDS:
				# Misses only in order: miss0, miss1, miss2.
				var n := report_misses()
				if n < MISS_IDS.size() and hid == MISS_IDS[n]:
					state.history.append(hid)
			elif HISTORY_TEXT.has(hid):
				_record_history(hid)
	var looks = d.get("photo_looks")
	if (looks is int or looks is float) and float(looks) == floorf(float(looks)):
		state.photo_looks = clampi(int(looks), 0, 9)
	# Look-away changes happen in one order only: accept an exact prefix of it.
	var applied = d.get("look_away_applied")
	if applied is Array and applied.size() <= LOOK_AWAY.size():
		var ok := true
		for i in applied.size():
			ok = ok and applied[i] is String and applied[i] == LOOK_AWAY[i][0]
		if ok:
			state.look_away_applied = applied.duplicate()
	if d.get("notices_seen") is Array:
		for k in d.notices_seen:
			if k is String and k in NOTICE_KEYS and not k in state.notices_seen:
				state.notices_seen.append(k)
	if d.get("board_pins") is Array:
		for m in d.board_pins:
			if m is String and MARKS.has(m) and not m in state.board_pins \
					and state.board_pins.size() < BOARD_SLOTS:
				state.board_pins.append(m)
	# Derived flags must agree: progress implies its prerequisites.
	if state.p01_complete:
		state.bridge_installed = true
		state.supply_on = true
	state.initialled = state.initialled and state.p01_complete
	state.log_read = state.log_read and state.p01_complete
	state.prints_seen = state.prints_seen and state.log_read
	state.drawer_open = state.drawer_open and state.log_read
	state.log_rewritten = state.log_rewritten and state.drawer_open
	state.seat_wet = state.seat_wet and state.log_rewritten
	state.report_filed = state.report_filed and state.seat_wet \
		and state.report_fields == REPORT_ANSWER and state.report_time == REPORT_TIME_ANSWER
	# A filed save always lands in the room, so she has already stepped back from the desk.
	state.heard_unlatch = state.report_filed
	if not state.seat_wet:
		state.history = []
	state.history_seen = state.history_seen and not state.history.is_empty()
	state.foretold_door = state.foretold_door and state.report_filed
	state.finished = state.finished and state.report_filed
	state.turned = state.turned and state.finished
	state.heard_silence = state.heard_silence and state.log_read
	state.soundings_heard = state.soundings_heard and state.drawer_open
	state.contours_seen = state.contours_seen and state.soundings_heard and state.finished
	state.callback_heard = state.callback_heard and state.drawer_open
	state.latch_announced = state.latch_announced and state.seat_wet
	# The board: stamped implies loaded; the core's P20 implies the solved board; a stamp
	# only stands on the right thread.
	state.board_loaded = state.board_loaded or state.board_stamped
	if game.flag("P20"):
		state.board_loaded = true
		state.board_pins = BOARD_ANSWER.duplicate()
		state.board_stamped = true
	state.board_stamped = state.board_stamped and state.board_pins == BOARD_ANSWER
	# The threshold and its card are never restored: a save lands in the room.

## P01, P20 and the Tide I transition flags are R02's (flags.md): they follow its state.
func reconcile() -> void:
	game.set_flag("P01", state.p01_complete)
	game.set_flag("closure_report_filed", state.report_filed)
	game.set_flag("t1x_threshold_crossed", state.finished)
	game.set_flag("t1x_turned", state.turned)
	if state.board_stamped:
		game.set_flag("P20")

## Dev-only: jump to a story stage (0-3), or 4 = stage 3 with the report filed, or 5 = the
## threshold passed. Room state only: P02/P03 are the instrument rooms' (set them to test
## what needs tide_done(1)).
## 6 = the start of Tide VII facing the loaded board; 7 = Tide VIII, the board solved.
func debug_jump(target: int) -> void:
	if target >= 6:
		game.debug_tide(7 if target == 6 else 8, ID)
		facing = "B"
		if target == 6:
			state.board_loaded = true
			_observe("contract")
		return
	game.reset()
	game.debug_enter(ID)
	_jump_state(target)
	reconcile()

func _jump_state(target: int) -> void:
	if target >= 1:
		state.p01_complete = true; state.bridge_installed = true; state.supply_on = true
		_observe("lamp")
	if target >= 2:
		state.log_read = true; _observe("handwriting")
	if target >= 3:
		state.prints_seen = true; state.drawer_open = true; state.log_rewritten = true
		state.seat_wet = true
		state.callback_heard = true
		state.drawer_dial = DRAWER_CODE.duplicate()
		_observe("prints"); _observe("piling"); _observe("watch"); _observe("photo")
		_observe("rewritten"); _observe("seat")
	if target >= 4:
		state.report_fields = REPORT_ANSWER.duplicate()
		state.report_time = REPORT_TIME_ANSWER.duplicate()
		state.report_filed = true
		state.heard_unlatch = true
		_observe("report")
	if target >= 5:
		state.finished = true

## The office as real play leaves it at the start of tide `t`. The core has already set
## every earlier tide's flags, so weather_band() is the band she arrives in.
func debug_prepare(t: int) -> void:
	if t >= 1:
		game.give("pencil")
	if t >= 2:
		_jump_state(5)
		game.give("inspection_lens")
		var b: int = game.weather_band()
		state.notices_seen = ["callback"]
		for n in range(1, b + 1):
			state.notices_seen.append("b%d" % n)
		var upto: int = mini(maxi(0, t - 2), 7)
		state.look_away_applied = []
		for e in LOOK_AWAY:
			if int(e[1]) <= upto:
				state.look_away_applied.append(e[0])
				_observe("away_" + e[0])
	if t >= 3:
		state.service_unlocked = true
		game.take("service_key")
	if t >= 8:
		state.board_loaded = true
		state.board_pins = BOARD_ANSWER.duplicate()
		state.board_stamped = true
		_observe("contract")
		_observe("why_ada")
	# From Tide VII the hook tags are up but unread (hook_tags_seen stays false), so a
	# capture shows the first reading.
