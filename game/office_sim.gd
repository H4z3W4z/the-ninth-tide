class_name OfficeSim
extends RefCounted
## Deterministic state for the Intake Office slice (Tide I).
##
## No nodes, no clocks, no randomness: every change is caused by a player
## action. dispatch() mutates state and returns presentation events
## ({type: "say"|"sfx"|"fx", ...}) for the view to play. The view never
## mutates state itself, so the whole slice is testable headless.
##
## Every "delay" in an event is seconds after the click that caused it.
## "story" lines are part of a reveal: the view never drops them for a
## later click, and never cuts one off before it can be read.
##
## P01 rule (AGENTS.md): supply OFF, straight bridge B installed, supply ON.
## Curved C is rejected without consuming anything.

const SCHEMA := 5

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

const OBJECTIVES := {
	"lamp": "Get the desk lamp working.",
	"log": "Read what Venn left on the desk.",
	"changed": "Something in the room changed while I was reading.",
	"drawer": "The footprints stop at a locked desk drawer.",
	"reread": "Read the tide log again.",
	"chair": "The log has written what I do next.",
	"report": "Reconcile the records. The closure report is under the duty card.",
	"filed": "The report is signed.",
	"leave": "The door has unlatched itself.",
	"done": "Tide I continues.",
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
	"reread": [
		"Something on the desk has changed since you last read it.",
		"Venn's log is not finished with you.",
		"Open the tide log again.",
	],
	"chair": [
		"The log has told you what you do next.",
		"\"She looks at the chair.\"",
		"Inspect the chair behind the desk.",
	],
	"report": [
		"Each line has a witness. The evening's high water has to be worked out, not read.",
		"Pilings: the chart as it is now. Observers: count the trails from the puddle. The evening tide: Venn's margin rule, from the last time in the log. The height: what the log wrote for itself.",
		"Pilings 10. Observers 2. High water 19:34 (07:13 plus 12 h 21 m). Height 9.9 m. Then sign it.",
	],
	"filed": ["Put the report down.", "Step back from the desk.", "Use Back."],
	"leave": [
		"The door has unlatched itself.",
		"The corridor door is on the right.",
		"Use the door.",
	],
	"done": ["The slice is complete.", "The slice is complete.", "The slice is complete."],
}
## At the threshold the hint ladder steps aside: there is only one thing to do.
const THRESHOLD_HINT := "Hold still. Listen to it."

## Notebook text for each observation, in the order they read best.
const OBSERVATIONS := {
	"duty": "Closure duty: inventory the instruments, reconcile the records, restore the departure signal.",
	"coat": "Venn's oilskin is soaked through. It has not rained today.",
	"hooks": "Nine hooks. His coat is on the seventh. The ninth is wet, with nothing on it.",
	"map": "The 1889 survey shows nine jetty pilings. I counted eight from the launch.",
	"chart": "The chart has been corrected in pencil: nine pilings.",
	"chart_tenth": "Later, a tenth piling inked in, past where the jetty ends.",
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
	"behind": "In the photograph, something pale and too tall stands behind my chair.",
	"rewritten": "New lines in the tide log, in my hand: \"She reads this line.\" \"She looks at the chair.\" \"HW 9.9\u00a0m. Observer located.\"",
	"seat": "The chair seat is wet, and still warm underneath.",
	"knock": "Three taps on the window glass, from outside. This room is on the second floor.",
	"palms": "Three wet palm marks on the outside of the window, below the sill line. The wall below goes straight into the sea.",
	"horizon": "The horizon outside is no longer level. The room is.",
	"eye": "A ring on the water past the pilings. It keeps its place against me.",
	"through": "It is not looking at the room. The room is what it looks through.",
	"tag": "A brass tag on the ninth hook, stamped A.M. It hangs at the height of my collar.",
	"away_mug": "Venn's mug is full to the brim with seawater. Nobody filled it.",
	"away_stove": "The stove is full of seawater, up into the flue. Its door was shut.",
	"away_coat": "The oilskin's hood is up, turned toward the desk.",
	"away_door": "Seawater seeps under the corridor door, from the corridor side.",
	"away_puddle": "Wet footprints go up the wall beside the door. None come down.",
	"away_window": "A fourth wet hand on the window, at the top of the glass, as if it had stood up.",
	"report": "Closure report, filed in my hand: pilings 10; observers on station 2; high water 18 Oct 19:34, 9.9\u00a0m.",
}

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

## Lines the log writes for itself once she has opened the drawer.
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
	"hooks": "She reads her name on the ninth hook.",
	"map": "She counts the pilings. She gets ten.",
	"chair": "She looks at the chair again. It is not empty.",
	"puddle": "She follows her own feet.",
	"mug": "She touches the warm ring.",
	"stove": "She looks at the ash. It has been raked again.",
	"lamp": "She checks the lamp. It is still mended.",
	"tray": "She checks the lamp. It is still mended.",
	"drawer": "She looks at the photograph again.",
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

## The end card. Two rows write themselves in the log; which two depends on whether she turned.
const END_LOG_ROW := "18 Oct  —  19:34  —  HW 9.9 m  —  Observer located."
const END_TURN_ROW := "18 Oct  —  19:34  —  She turns round."
const END_NEXT_ROW := "19 Oct  —  07:55  —  HW 4.4 m  —  Observer: E. Venn."
const END_NEXT_TURNED := "19 Oct  —  07:55  —  HW 4.4 m  —  Observer: A. Mercer."
const END_ON_STATION := "Observers on station: 1."
const END_ALL_SEEN := "Nothing in the room went unrecorded."
const END_CONTINUES := "Tide I continues."
const NOTEBOOK_INTRUSION := "She will not finish this page."

const ROOM_IDS := ["lamp", "tray", "logbook", "papers", "mug", "chair", "map",
	"stove", "window", "hooks", "coat", "drawer", "puddle", "door"]

## What changes while she looks away at stage 3, in the order it happens: the n-th
## return from a close-up (or the notebook) to the room applies the n-th change.
const LOOK_AWAY := ["mug", "stove", "coat", "door", "puddle", "window"]
const RETURNS_MAX := 6

const SAVED_BOOLS := ["started", "supply_on", "bridge_installed", "p01_complete", "log_read",
	"prints_seen", "drawer_open", "log_rewritten", "seat_wet", "foretold_door", "initialled",
	"finished", "motion", "soft_audio", "report_filed", "history_seen", "soundings_heard",
	"heard_silence", "heard_unlatch", "contours_seen", "turned"]

var state := {}
var view := "title"
var return_view := "room"   # where Back goes from the notebook / menu
var selected := ""          # transient: spare selected in the repair close-up
var drawer_miss_n := 0      # transient: rotates the drawer's generic refusal

func _init() -> void:
	reset()

func reset(keep_settings := false) -> void:
	var motion: bool = state.get("motion", true) if keep_settings else true
	var soft: bool = state.get("soft_audio", false) if keep_settings else false
	state = {
		"schema": SCHEMA, "started": false,
		"supply_on": true, "bridge_installed": false, "p01_complete": false,
		"log_read": false, "prints_seen": false, "drawer_open": false, "log_rewritten": false,
		"seat_wet": false, "foretold_door": false, "initialled": false, "finished": false,
		"drawer_dial": [0, 0, 0, 0],
		"report_filed": false, "report_fields": [0, 0, 0], "report_time": [0, 0, 0, 0],
		"heard_unlatch": false,
		"history": [], "history_seen": false,
		"soundings_heard": false, "heard_silence": false, "photo_looks": 0,
		"contours_seen": false, "returns": 0, "turned": false,
		"seen": [], "hint_level": 0, "hint_for": "",
		"motion": motion, "soft_audio": soft,
	}
	view = "title"
	return_view = "room"
	selected = ""
	drawer_miss_n = 0

# ---------------------------------------------------------------------------
# derived
# ---------------------------------------------------------------------------
func objective() -> String:
	if state.finished: return "done"
	if not state.p01_complete: return "lamp"
	if not state.log_read: return "log"
	if not state.prints_seen: return "changed"
	if not state.drawer_open: return "drawer"
	if not state.log_rewritten: return "reread"
	if not state.seat_wet: return "chair"
	if not state.report_filed: return "report"
	if not state.heard_unlatch: return "filed"
	return "leave"

## 0 arrival, 1 lamp lit, 2 log read (sea silent, prints, drawer), 3 seat wet.
func stage() -> int:
	if state.seat_wet: return 3
	if state.log_read: return 2
	if state.p01_complete: return 1
	return 0

func has_seen(id: String) -> bool:
	return id in state.seen

func is_closeup(v := view) -> bool:
	return v in ["repair", "logbook", "duty", "note", "drawer", "report"]

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

## The two log rows the end card writes, as [text, hand]: hand is "her" or "venn".
## She does not turn: her row, then the next tide in his hand. She turns: both are hers.
func end_rows() -> Array:
	if state.turned:
		return [[END_TURN_ROW, "her"], [END_NEXT_TURNED, "her"]]
	return [[END_LOG_ROW, "her"], [END_NEXT_ROW, "venn"]]

## Lines for the end card, in order.
func end_lines() -> Array:
	var out := [END_ON_STATION]
	if state.seen.size() == OBSERVATIONS.size():
		out.append(END_ALL_SEEN)
	out.append(END_CONTINUES)
	return out

## How many wrong filings the log has written down (0-3).
func report_misses() -> int:
	var n := 0
	for id in state.history:
		if id in MISS_IDS:
			n += 1
	return n

## True once the room has made its change for `id` (see LOOK_AWAY).
func look_away(id: String) -> bool:
	var i := LOOK_AWAY.find(id)
	return i >= 0 and i + 1 <= int(state.returns)

## A line in her notebook she did not write. Empty until the log has rewritten itself.
func notebook_intrusion() -> String:
	return NOTEBOOK_INTRUSION if state.log_rewritten else ""

func dial_code() -> Array:
	return state.drawer_dial.duplicate()

# ---------------------------------------------------------------------------
# actions
# ---------------------------------------------------------------------------
func dispatch(action: String) -> Array:
	var ev: Array = []
	if view == "title":
		match action:
			"begin":
				_begin(ev)
			"menu":
				return_view = "title"
				view = "menu"
		return ev
	if view == "end":
		if action == "restart":
			reset(true)
		return ev
	# Settings reached from the title: nothing in the story is reachable from here.
	if view == "menu" and return_view == "title" and not action in [
			"resume", "back", "toggle_motion", "toggle_soft", "restart"]:
		return ev

	match action:
		"notebook":
			if view != "notebook":
				return_view = view if view != "menu" else return_view
				view = "notebook"
				_sfx(ev, "page")
		"menu":
			if view != "menu":
				return_view = view if view != "notebook" else return_view
				view = "menu"
		"hint":
			_hint(ev)
		"back":
			_back(ev)
		"resume":
			if view == "menu":
				view = return_view
		"toggle_motion":
			state.motion = not state.motion
		"toggle_soft":
			state.soft_audio = not state.soft_audio
		"restart":
			reset(true)
		_:
			if view == "room" and action in ROOM_IDS:
				_room(action, ev)
			elif view == "repair":
				_repair(action, ev)
			elif view == "drawer":
				_drawer(action, ev)
			elif view == "report":
				_report(action, ev)
			elif view == "threshold" and action == "continue":
				state.finished = true
				view = "end"
				_sfx(ev, "motif")
			elif view == "threshold" and action == "turn":
				state.turned = true
				state.finished = true
				view = "end"
				_sfx(ev, "exhale_near")
				_sfx(ev, "motif", 1.4)
				_fx(ev, "turn")
	return ev

func _begin(ev: Array) -> void:
	state.started = true
	view = "room"
	_say(ev, "Greywake Survey Station. The launch won't be back for me until the morning tide.")
	_say(ev, "Power's out. The duty card says to start with the desk lamp.", 3.2)

func _back(ev: Array) -> void:
	var before := view
	_back_view(ev)
	# At stage 3 the room uses the moments she isn't looking at it. The menu doesn't count.
	if view == "room" and (is_closeup(before) or before == "notebook") and stage() == 3:
		state.returns = mini(int(state.returns) + 1, RETURNS_MAX)

func _back_view(ev: Array) -> void:
	match view:
		"notebook", "menu":
			view = return_view
		"logbook":
			view = "room"
			# The room changed while she was reading. Say nothing; let her hear it. Once.
			if state.log_read and not state.heard_silence:
				state.heard_silence = true
				_fx(ev, "sea_fade")
				_say(ev, "...Listen.", 2.2, true)
		"report":
			view = "room"
			# She signed it at the desk. Only when she steps back does the door answer.
			if state.report_filed and not state.heard_unlatch:
				state.heard_unlatch = true
				_sfx(ev, "latch_near", 0.2)
				_say(ev, "Behind me, the corridor door unlatched itself.", 0.6, true)
		"repair", "duty", "note", "drawer":
			view = "room"
			selected = ""
		"threshold":
			pass   # there is no going back from the doorway
		_:
			view = "room"

func _room(id: String, ev: Array) -> void:
	var s := stage()
	# Between the chair and the report, the log keeps her: the first three different
	# things she does are written down, in order, in her hand.
	if state.seat_wet and not state.report_filed:
		_record_history(id)
	match id:
		"lamp", "tray":
			view = "repair"
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
			if s >= 3 and look_away("mug"):
				_observe("away_mug")
				_say(ev, "His mug is full to the brim. Seawater. I didn't fill it.")
			elif s >= 2:
				_say(ev, "Two rings on the desk now. One is still warm.")
			else:
				_say(ev, "A chipped green mug, rinsed. A clean spoon laid across it. Someone tidied before they left.")
		"stove":
			_observe("stove")
			if s >= 3 and look_away("stove"):
				_observe("away_stove")
				_say(ev, "The stove door is open. It's full of water, up into the flue.")
			elif s >= 2:
				_say(ev, "Raked smooth again. I didn't touch it.")
			else:
				_say(ev, "Cold through. The ash has been raked smooth, like a page nobody wrote on.")
		"map":
			_map(s, ev)
		"hooks":
			_observe("hooks")
			if s >= 3:
				_observe("tag")
				_say(ev, "There's a tag on the ninth hook now. Stamped A.M. It hangs at the height of my collar.")
			elif s == 2:
				_say(ev, "Nine hooks. The ninth is wet again. I dried it with my sleeve an hour ago.")
			else:
				_say(ev, "Nine hooks. His coat's on the seventh. The ninth is wet, and nothing is hanging on it.")
		"window":
			_window(s, ev)
		"coat":
			_observe("coat")
			if s >= 3 and look_away("coat"):
				_observe("away_coat")
				_say(ev, "The hood is up. It's facing the desk.")
			elif s >= 3:
				_say(ev, "The shoulders have shape now. I am not going to touch it.")
			elif state.log_rewritten:
				_say(ev, "It hangs differently. Heavier at the shoulders.")
			elif s == 2:
				_say(ev, "Still dripping. Onto the same spot, every time. Like it's being counted.")
			else:
				_say(ev, "Venn's oilskin, soaked through. It hasn't rained since I landed.")
		"drawer":
			view = "drawer"
			_sfx(ev, "dial")
			if state.drawer_open:
				_say(ev, "His watch and the photograph. I keep looking at the back of my own head.")
			else:
				_say(ev, "The right-hand drawer is locked. Four brass dials, and a plate: \"E.V. Open at the hour she mended it.\"")
		"puddle":
			if s >= 3:
				_observe("prints")
				_say(ev, "There are two trails now.")
				_say(ev, "One goes to the drawer. One comes from the drawer to the door. The second one is my size.", 2.0, true)
				if look_away("puddle"):
					_observe("away_puddle")
					_say(ev, "And a third. Up the wall beside the door. It doesn't come down.", 4.2, true)
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
			if state.report_filed and state.heard_unlatch:
				view = "threshold"
				_sfx(ev, "door")
				_fx(ev, "threshold")
			elif state.seat_wet:
				if look_away("door"):
					_observe("away_door")
					_say(ev, "Water is coming under the door. From the corridor side.")
					_say(ev, LATCHED_LINE, 2.4)
				else:
					_say(ev, LATCHED_LINE)
			elif s == 2:
				_say(ev, "The latches downstairs let go when the lamp came on. Something wanted the doors open before I did.")
			elif s == 1:
				_say(ev, "Two latches let go somewhere below. I'd rather know what's in this room first.")
			else:
				_say(ev, "The corridor is pitch black. Light first.")

const LATCHED_LINE := "Latched. His rule's on the duty card: nobody leaves until the records reconcile."

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
	if state.seat_wet:
		view = "report"
		_sfx(ev, "page")
		if state.report_filed:
			_say(ev, "Filed. In my hand. I don't remember choosing the two.")
		elif state.report_fields != [0, 0, 0] or state.report_time != [0, 0, 0, 0]:
			_say(ev, "His closure report. Half reconciled.")
		else:
			_say(ev, "Under the duty card, his closure report. Blank. Four lines to reconcile before the station can be left.")
		return
	if state.p01_complete:
		view = "note"
		_observe("note")
		_say(ev, "In the lamplight there's pencil beneath the duty card.")
		if not state.initialled:
			state.initialled = true
			_say(ev, "At the bottom: \"Lamp service completed. A.M.\"", 1.8, true)
			_say(ev, "That's my initial. The graphite's gone dull, like it's been there for days.", 4.0, true)
	else:
		view = "duty"
		_observe("duty")
		_say(ev, "Closure duty. Inventory, reconcile, restore the signal. Begin with the lamp.")
	_sfx(ev, "page")

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
		if s == 3:
			_observe("chart_tenth")
			_say(ev, "And someone has inked a tenth piling, further out than the jetty goes.", 9.0, true)
	elif s == 3 and state.soundings_heard and not state.contours_seen:
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
		if s == 2:
			_say(ev, "The chart has been corrected. In pencil. Nine.")
		else:
			_observe("chart_tenth")
			_say(ev, "Someone has inked a tenth piling. Further out than the jetty goes.")
	else:
		_observe("map")
		_say(ev, "Morrow Sound, surveyed 1889. The jetty has nine pilings. I counted eight from the launch.")

func _logbook(ev: Array) -> void:
	view = "logbook"
	_sfx(ev, "page")
	if not state.p01_complete:
		_say(ev, "Venn's tide log. The ink is too faint to read by torchlight.")
		return
	var first: bool = not state.log_read
	state.log_read = true
	_observe("handwriting")
	if first:
		_say(ev, "He's worked out the tides to tomorrow. In advance.", 0.0, true)
		_say(ev, "And the last line... that's my handwriting.", 1.4, true)
		_say(ev, "One of the times is under a tide-stain. His margin note isn't.", 3.0, true)
		_fx(ev, "dread")
	elif state.prints_seen and state.drawer_open and not state.log_rewritten:
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
	if s >= 3:
		# Evidence from stage 2 stays collectable: the sea is still silent.
		_observe("silent")
		_observe("piling")
		_observe("horizon")
		_observe("eye")
		_say(ev, "The horizon isn't level. The house is.")
		_say(ev, "There's a ring on the water, out past the pilings. When I move, it moves.", 2.6, true)
		_say(ev, "I step to the left. It is still in the middle of the glass.", 5.4, true)
		var last := 5.4
		if has_seen("knock"):
			_observe("palms")
			last = 8.4
			_say(ev, "There are marks on the outside of the glass, low down. Three. And the heel of a hand.", last, true)
		if look_away("window"):
			_observe("away_window")
			last += 2.8
			_say(ev, "There's a fourth hand now. At the top of the glass.", last, true)
		if state.contours_seen and not has_seen("through"):
			_observe("through")
			last += 2.8
			_say(ev, OBSERVATIONS["through"], last, true)
	elif s == 2:
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

func _chair(s: int, ev: Array) -> void:
	if s == 0:
		_say(ev, "Venn's chair. The cushion keeps the shape of someone who sat very still.")
	elif state.seat_wet:
		_say(ev, "The seat is wet. Still warm underneath.")
	elif state.log_rewritten:
		state.seat_wet = true
		_observe("shadow")
		_observe("seat")
		_sfx(ev, "sting")
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
			else:
				_sfx(ev, "clunk")
				_say(ev, _drawer_miss(code))
		"look_watch":
			if state.drawer_open:
				_say(ev, "Stopped at 18:52.")
		"look_photo":
			if state.drawer_open:
				state.photo_looks = mini(int(state.photo_looks) + 1, 9)
				if int(state.photo_looks) == 1:
					_say(ev, "Me, from outside. From the sea side.")
				else:
					_observe("behind")
					_say(ev, "There is someone behind me in this. There is no one behind me now.")

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
				view = "room"
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

func _hint(ev: Array) -> void:
	if view == "threshold":
		_say(ev, THRESHOLD_HINT)   # the ladder is untouched: nothing here is a puzzle
		return
	var obj := objective()
	if state.hint_for != obj:
		state.hint_for = obj
		state.hint_level = 0
	var level: int = mini(int(state.hint_level), 2)
	_say(ev, HINTS[obj][level])
	state.hint_level = level + 1

# ---------------------------------------------------------------------------
# persistence
# ---------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return state.duplicate(true)

## Restores a saved dict, ignoring anything malformed. Returns true if loaded.
func from_dict(d: Variant) -> bool:
	if not d is Dictionary or int(d.get("schema", 0)) != SCHEMA:
		return false
	reset()
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
		for id in d.history:
			if not id is String:
				continue
			if id in MISS_IDS:
				# Misses only in order: miss0, miss1, miss2.
				var n := report_misses()
				if n < MISS_IDS.size() and id == MISS_IDS[n]:
					state.history.append(id)
			elif HISTORY_TEXT.has(id):
				_record_history(id)
	var returns = d.get("returns")
	if (returns is int or returns is float) and float(returns) == floorf(float(returns)):
		state.returns = clampi(int(returns), 0, RETURNS_MAX)
	var looks = d.get("photo_looks")
	if (looks is int or looks is float) and float(looks) == floorf(float(looks)):
		state.photo_looks = clampi(int(looks), 0, 9)
	if d.get("seen") is Array:
		for id in d.seen:
			if id is String and OBSERVATIONS.has(id) and not id in state.seen:
				state.seen.append(id)
	# Derived flags must agree: progress implies its prerequisites.
	if state.p01_complete:
		state.bridge_installed = true
		state.supply_on = true
	state.initialled = state.initialled and state.p01_complete
	state.log_read = state.log_read and state.p01_complete
	state.prints_seen = state.prints_seen and state.log_read
	state.drawer_open = state.drawer_open and state.log_read
	state.log_rewritten = state.log_rewritten and state.drawer_open and state.prints_seen
	state.seat_wet = state.seat_wet and state.log_rewritten
	state.report_filed = state.report_filed and state.seat_wet \
		and state.report_fields == REPORT_ANSWER and state.report_time == REPORT_TIME_ANSWER
	# A filed save always lands in the room, so she has already stepped back from the desk.
	state.heard_unlatch = state.report_filed
	if not state.seat_wet:
		state.history = []
		state.returns = 0
	state.history_seen = state.history_seen and not state.history.is_empty()
	state.foretold_door = state.foretold_door and state.report_filed
	state.finished = state.finished and state.report_filed
	state.turned = state.turned and state.finished
	state.heard_silence = state.heard_silence and state.log_read
	state.soundings_heard = state.soundings_heard and state.drawer_open
	state.contours_seen = state.contours_seen and state.soundings_heard and state.seat_wet
	# The threshold is never restored: a seat_wet save lands in the room.
	view = "room" if state.started else "title"
	if state.finished:
		view = "end"
	return true

## JSON numbers come back as floats; accept only whole numbers.
static func _all_whole(values: Array) -> bool:
	for v in values:
		if not (v is int or v is float) or float(v) != floorf(float(v)):
			return false
	return true

## Dev-only: jump to a story stage (0-3), or 4 = stage 3 with the report filed.
## Builds the state the real actions would.
func debug_jump(target: int) -> void:
	reset(true)
	state.started = true
	view = "room"
	if target >= 1:
		state.p01_complete = true; state.bridge_installed = true; state.supply_on = true
		_observe("lamp")
	if target >= 2:
		state.log_read = true; _observe("handwriting")
	if target >= 3:
		state.prints_seen = true; state.drawer_open = true; state.log_rewritten = true
		state.seat_wet = true
		state.drawer_dial = DRAWER_CODE.duplicate()
		_observe("prints"); _observe("piling"); _observe("watch"); _observe("photo")
		_observe("rewritten"); _observe("seat")
	if target >= 4:
		state.report_fields = REPORT_ANSWER.duplicate()
		state.report_time = REPORT_TIME_ANSWER.duplicate()
		state.report_filed = true
		state.heard_unlatch = true
		_observe("report")

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
func _observe(id: String) -> void:
	if not id in state.seen:
		state.seen.append(id)

func _say(ev: Array, text: String, delay := 0.0, story := false) -> void:
	ev.append({"type": "say", "text": text, "delay": delay, "story": story})

func _sfx(ev: Array, id: String, delay := 0.0) -> void:
	ev.append({"type": "sfx", "id": id, "delay": delay})

func _fx(ev: Array, id: String) -> void:
	ev.append({"type": "fx", "id": id})
