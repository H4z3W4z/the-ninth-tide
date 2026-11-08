class_name R03Sim
extends RoomSim
## R03, the Chart Room. Owns P03 part 2 (registration), P04 (calibration), P05 (the
## departure observation) and P21 (the station's real plan). Writes `chart_clips` and, at
## P05's RECORD, `p05_trace` (via game.freeze_p05_trace()).
##
## Three walls, all `local_view == "room"`: A chart table, B recorder wall, C hatch wall.
## The wall Ada faces is a sim member (`wall`), never saved: a load lands on wall A, an
## arrival faces the wall of the newest unseen change (NOTICES). Close-ups: c_registration
## (P03), c_recorder (P04, P05), c_plan (P21). Node-free and deterministic; the view plays
## the events and reads the public helpers at the bottom of this file.

const ID := "R03"
const TITLE := "Chart Room"
const REQUIRES := ["P01"]
const LOCKED := "The chart room door is latched. Electrically, by the feel of it."
const RESUME := "Back in the chart room."
const ARRIVAL := "The chart room. A tide pen scratches against a drum that isn't turning."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R02", "Office", []],
	["R11", "Observation hatch", []],
	["R04", "Listening room", []],
]
## Wall A's hotspots: the room-view ids the core and the skeleton checks know about.
const HOTSPOTS := ["empty_clip", "clip_tin", "compass", "plan_wall", "sheet_table"]
const WALL_HOTSPOTS := {
	"A": HOTSPOTS,
	"B": ["pen_drum", "seal", "plate_rack", "sea_window", "recorder"],
	"C": ["hatch_scratches", "outer_window", "hatch"],
}
## hotspot -> wall (WALL_HOTSPOTS inverted; R03_test checks they agree).
const WALL_OF := {
	"empty_clip": "A", "clip_tin": "A", "compass": "A", "plan_wall": "A", "sheet_table": "A",
	"pen_drum": "B", "seal": "B", "plate_rack": "B", "sea_window": "B", "recorder": "B",
	"hatch_scratches": "C", "outer_window": "C", "hatch": "C",
}
const WALLS := ["A", "B", "C"]
const TURNS := {
	"A": {"turn_left": "C", "turn_right": "B"},
	"B": {"turn_left": "A", "turn_right": "C"},
	"C": {"turn_left": "B", "turn_right": "A"},
}
const CLOSEUPS := ["c_registration", "c_recorder", "c_plan"]
## The wall each close-up is on (Back returns to it).
const CLOSEUP_WALL := {"c_registration": "A", "c_recorder": "B", "c_plan": "A"}
const LOOKS := {}

# --- P03 part 2: registration -------------------------------------------------
const REG_BASES := ["14", "17"]
const REG_SNAPS := ["", "lighthouse", "buoy", "datum"]
const REG_ANSWER := {"base": "17", "rot": 0, "snap": "lighthouse"}
## The base-sheet rack's engraved labels, by sheet id. "17" is the table's own sheet.
const REG_SLOT_LABELS := {"14": "SPARE: 14 OCT", "17": "TABLE: 17 OCT"}
const CURVE_LINE := "Together they draw a line neither sheet has. I've seen it before: scratched into the hatch, from the underside."
const RECONCILE_LINE := "The charts agree now. Something in the office has already written that down."
## Contextual use in c_registration: his sheet is laid by using it on the table (reg_table),
## the clips by using them on the clip rail (reg_clip). A bare click says what's missing.
const REG_HAS_SHEET := "His sheet's with me. It goes on the table, over this one."
const REG_HAS_CLIPS := "The rail's empty. The clips are in my pocket."
const REG_LAID_ALREADY := "His sheet's already on the table."
const REG_CLIPPED := "It's clipped. I'm not taking it apart."
const REG_NOT_LAID := "Nothing laid over it to turn."
const REG_REFUSE := {
	"no_sheet": "Both sheets, he said. The other's with E.V.",
	"not_laid": "Venn's sheet isn't on the table yet.",
	"no_clips": "Nothing to hold them with. There was a tin.",
	"date": "The dates don't match. 14th and 17th.",
	"north": "North arrows disagree.",
	"no_snap": "The crosses aren't on each other yet.",
	"cross": "Those crosses aren't the same mark.",
}

# --- P04: calibration ---------------------------------------------------------
const ZERO_ANSWER := 4
const INTERVAL_ANSWER := 3
const GAUGE_VALUES := ["", "ok", "mismatch"]
const SEAL_LINE := "Under a paper seal, signed E.V.: 'Calibrate on filing of the closure report. Duty card, item 2 before item 3.'"
const SEAL_BROKEN_LINE := "Broken. The paper's pushed outward, as if something in the recorder leaned on it."
const CALIBRATED := "Calibrated. I'm leaving it alone."
const WHEELS := ["rec_zero_up", "rec_zero_down", "rec_int_up", "rec_int_down"]

# --- P05: the departure observation -------------------------------------------
const PLATES := ["boundary", "relation", "observer"]
## The rack's home order, positions 0..2.
const RACK_HOME := ["observer", "boundary", "relation"]
const SHUTTERED := "The record panel is shuttered. Stencilled on it: CALIBRATE FIRST."
const RECORDED := "Recorded. The plates stay where they are."
const REFUSE_INCOMPLETE := "RECORD REFUSED: INCOMPLETE."
const REFUSE_BOUNDARY := "RECORD REFUSED: OBSERVATION MUST BEGIN AT BOUNDARY."
const REFUSE_RELATION := "RECORD REFUSED: RELATION PRECEDES OBSERVER."
const RECORD_REFUSALS := [REFUSE_INCOMPLETE, REFUSE_BOUNDARY, REFUSE_RELATION]
const RECORD_MISS_LINES := ["It printed why.", "Refused. The order's wrong.", "It's patient about it."]
const MINIATURE := "From the duty card: \"Departure observation: record the marks in the order the observer meets them going down. Example, from the jetty: PILE → SPAN → LAMP, as met walking out. Then RECORD.\""
## The framed card itself (the view prints it; MINIATURE is what she reads aloud).
const MINIATURE_CARD := "Departure observation: record the marks in the order the observer meets them going down. Example, from the jetty: PILE → SPAN → LAMP, as met walking out. Then RECORD."
const SCRATCHES_AFTER_MINIATURE := "Not his example. The marks on the hatch."
const STRIP_HEAD := "DEPARTURE OBSERVATION"
const STRIP_RELAY := "COLLECTION ANSWERS. ATTEND JETTY."
const LINE4_TURNED := "Observer has looked behind her once."
const LINE4_STILL := "Observer has not yet looked behind her."

# --- P21: the station's real plan ---------------------------------------------
## P03's mechanic again, on the plan: his composite chart is laid over the station plan,
## turned until its north arrow agrees with the plan's (the plan is drawn with north to the
## right: one quarter turn clockwise), pinned by his lighthouse cross on the plan's own
## lighthouse cross beside the lantern gallery, and clipped. Then the WITNESS pin goes where
## his three marks end: the centre chamber.
const PLAN_ROT := 1
## The composite comes off the chart table as it was clipped there: north up.
const PLAN_ROT_START := 0
const PLAN_SNAP := "lighthouse"
## The zones the WITNESS pin can be offered to (the view's PLAN_ZONES).
const ZONES := ["lab", "chart", "office", "centre"]
const ZONE_DESC := {
	"lab": "The laboratory and the listening room, drawn as a pair.",
	"chart": "The chart room and the lantern gallery, one above the other.",
	"office": "The office and the records vault, side by side.",
	"centre": "The observation chamber, outlined, marked WITNESS.",
}
const PLAN_LID := "The plan's under a glass lid, screwed down. Nothing goes on it yet."
const PLAN_NO_COMPOSITE := "There's nothing of his to lay on it. His chart table has two sheets that should be one."
const PLAN_NOT_LAID := "Nothing laid over the plan."
const PLAN_WRONG := "The line runs through walls. Not like that."
const PLAN_CLIPPED := "It's clipped. The line stays where it is."
const PLAN_FIXED := "It's pinned. The plan stays as it is."
const PIN_NOT_YET := "A brass pin, stamped WITNESS. I don't know where it goes. Not yet."
## The WITNESS pin offered to a zone that isn't the chamber.
const PIN_REFUSE := {
	"lab": "Not there. That's the body.",
	"chart": "Not there. That's where it's looking from.",
	"office": "That's the name, underneath it. Not the witness.",
}
const PIN_PEOPLE := "Those are the people, not the instrument."
const MARGINS := ["plan_margin_kitchen", "plan_margin_bunks"]

## Presentation milestones: [id, wall, trigger, evidence, line]. Per wall only the newest met
## notice can be pending (unseen); older met ones are marked seen silently, evidence kept.
const NOTICES := [
	["n_arrival", "B", "visited", "recorder", ARRIVAL],
	["n_threshold", "B", "t1x", "seal_broken", "The seal on the recorder is broken. The paper's pushed outward, from inside."],
	["n_p04", "C", "P04", "stair_threshold", "Water in the window. Air in the hatch."],
	["n_b3", "B", "band3", "vis_nil", "The pen's writing VIS 0.0 NM. I can see the sea from here."],
	["n_b4", "A", "band4", "compass_bent", "The compass lines on his chart bend. Toward where I'm standing."],
	["n_b5", "B", "band5", "attending", "SEA STATE: ATTENDING. The drum has stopped. The pen hasn't."],
	["n_b5_prints", "A", "band5", "standing", "Two wet footprints in front of the table, where I stand. None lead there."],
	["n_b6", "A", "P21", "station_outline", "The plan on the wall is a body, sitting."],
	["n_b7", "C", "band7", "water_standing", "The water in the window is standing up."],
]
const NOTICE_DELAY := 1.4
const KNOT_BASE := 6.0
const KNOT_STEP := 4.0
const KNOT_MAX := 60.0
const LAMP_OUT_LINE :="The lighthouse is out. The sea hasn't come back from where it went."

## The flags this room owns, and the state key that mirrors each.
const OWNED := [["P03", "p03_complete"], ["P04", "p04_complete"], ["P05", "p05_complete"], ["P21", "p21_complete"]]
const SAVED_BOOLS := ["clips_taken", "reg_laid", "p03_complete", "prophecy_seen", "p04_complete",
	"stair_looked", "p05_complete", "looked_behind", "plan_lid_seen", "plan_laid", "plan_registered",
	"p21_complete", "lamp_out_said"]
const SAVED_COUNTS := ["clip_misses", "pull_misses", "record_misses"]

const OBSERVATIONS := {
	"sheets": "Two tide sheets on the chart table, dated 14 Oct and 17 Oct. Each has three registration crosses (lighthouse, buoy, datum stone), a north arrow and a date.",
	"example": "A worked example under glass: two unrelated sheets registered at a cross. The line runs across interval bands numbered 1 to 5, through band 1.",
	"empty_clip": "An empty clip on the board, labelled 'sheet 2 of 2: with E.V.'",
	"clip_tin": "A tin of brass chart clips. I took them.",
	"venn_sheet": "Venn's 17 Oct sheet is tracing paper, folded so its north arrow points down. The same three crosses.",
	"calibration_interval": "Registered, the charts draw a line neither sheet has. It runs through one of his numbered interval bands, and it has the shape of the marks scratched on the hatch. The composite is clipped on the chart table.",
	"composite_chart": "Composite chart, 17 Oct: Venn's sheet over the table sheet, north up, lighthouse cross on lighthouse cross. The line crosses one of his numbered bands; it is on neither sheet alone.",
	"plan": "The station plan, 1889, revised E.V. 1927. The landward edge is marked with a bracket and the word BOUNDARY. Down the dry stair, landings in bracket pairs: '[ 1' above '] 1'. A '[ 2' with nothing under it. North is drawn pointing right, and a registration cross marked LIGHTHOUSE is printed beside the lantern gallery.",
	"compass": "A brass compass rose on the wall. North is where north should be.",
	"compass_bent": "The compass lines on the chart sheet bend toward the place in front of the table where I stand.",
	"standing": "Two wet footprints on the floor in front of the chart table, where I stand to read it. Bare, narrow. None lead there.",
	"plan_registered": "His composite laid over the station plan, north with the plan's north, lighthouse cross on the plan's lighthouse cross: the curve runs down through the lantern gallery, the chart room, the listening room and the laboratory, and those rooms fill in as one shape, sitting. The office and the vault lie outside it, underneath. His three marks end in the chamber in the middle.",
	"station_outline": "The station is a diagram of a seated person. Body: lab and listening. Place: chart and lantern. Name: office and vault. The chamber in the middle is the witness. A procedure in the margin: three frames, one witness, the copy port left bare.",
	"plan_name": "The witness frame at the centre of the plan printed a name in the recorder's type: ADA MERCER.",
	"recorder": "The tide recorder: copper float, bone-paper drum, a polished CALIBRATE lever. The pen moves. The drum does not.",
	"seal": "A paper closure seal over the ZERO and INTERVAL wheels, signed E.V.: 'Calibrate on filing of the closure report. Duty card, item 2 before item 3.'",
	"seal_broken": "The closure seal is broken, the paper pushed outward from inside the recorder. I didn't touch it.",
	"pen_report": "The pen traced the figures from my closure report: 10, 2, 19:34, 9.9.",
	"calibration_plate": "The calibration plate: ZERO and INTERVAL are independent controls. Worked example: ZERO 7, INTERVAL 2, then pull CALIBRATE.",
	"plates": "Three record plates: '[' BOUNDARY, two linked strokes RELATION, a hollow circle OBSERVER.",
	"miniature": "Framed beside the slots. From the duty card: \"Departure observation: record the marks in the order the observer meets them going down. Example, from the jetty: PILE → SPAN → LAMP, as met walking out. Then RECORD.\"",
	"sea_window": "The sea window: overcast, the lighthouse clear, ordinary waves.",
	"sea_low": "The sea window after the threshold: the lighthouse is out, and the sea lies flat and glassy below the MUD mark on his tide scale. No waves.",
	"vis_nil": "The pen writes 'VIS 0.0 NM'. Out of the window I can still see the sea.",
	"attending": "The pen writes 'SEA STATE: ATTENDING'. The drum has stopped turning.",
	"stair_threshold": "The observation hatch opens onto a dry stair going down. The window beside it is full of seawater at the same level.",
	"departure_record": "The recorder wrote down the last things I did, in order, and then one line about me.",
	"relay": "The relay answered the departure signal: 'COLLECTION ANSWERS. ATTEND JETTY.'",
	"hatch": "The observation hatch, low in the wall, iron, wheel-latched from the far side.",
	"scratches": "Three marks carved down the hatch frame, top to bottom: a bracket, two linked strokes, a hollow circle.",
	"outer_window": "The window beside the hatch is full of seawater to the top, at the level of the hatch. This room is above the sea.",
	"stair_down": "Down the hatch: a dry stair, lit from below. A pressure gate across it.",
	"water_standing": "The water in the window beside the hatch stands upright, its surface vertical. A pale line moves slowly across it.",
	"lens_window": "Through the lens, there is no glass in the window beside the hatch. The water stands in the frame by itself.",
}
const OBJECTIVES := {
	"sheet_missing": "Register both chart sheets at the lighthouse cross. One is missing.",
	"register": "Register Venn's sheet on the chart table.",
	"zero": "The chart gives the interval. The recorder will want a zero too.",
	"office": "The records here reconcile. The office isn't finished with me.",
	"calibrate": "Set the sea to zero: calibrate the recorder.",
	"record": "Make the departure observation on the recorder.",
	"jetty": "The collection answers. Attend the jetty.",
	"away": "Nothing here needs me yet.",
	"plan": "Lay his composite chart over the station plan.",
	"done": "The plan is fixed. My name is in the middle of it.",
}
## Evidence tiers (hint_tiers()): what the room, the recorder and the notebook already show,
## said before the answer and short of it. P03 (register), T1X (office), P04, P05 and P21 have one; the rest
## have three tiers.
const EVIDENCE_CALIBRATE := "Venn's recording says the zero out loud. The registered curve runs through one of his numbered bands. The plate's seven and two are only its example."
const EVIDENCE_RECORD := "The recorder printed what you actually did. The hatch frame is carved top to bottom: a bracket, two linked strokes, a circle. The plates carry the same marks."
const EVIDENCE_PLAN := "The composite chart is in the notebook: his lighthouse cross, his north arrow, and the line his two sheets draw together. The station plan prints a lighthouse cross of its own, and its own north arrow."
## P03's evidence tier (the register ladder): what the table and his sheet already show.
const EVIDENCE_REGISTER := "The table has two sheets for the 17th. His sheet's north arrow is pointing somewhere else."
## T1X's evidence tier (the office ladder): what his log already showed her.
const EVIDENCE_OFFICE := "His log ended with my name on the 18th. A record is only finished when nobody is still writing in it."
const PLAN_ANSWER_HINT := "Lay his composite on the plan and turn it once to the right, so its north points the way the plan's does. Pin his lighthouse cross on the plan's, beside the lantern gallery, and clip. Then the WITNESS pin in the centre chamber."
const HINTS := {
	"sheet_missing": [
		"The chart room has one sheet of the pair. The other is with E.V. His desk drawer wants the hour she mended the lamp.",
		"The stained hour is one high water after 06:31, by his margin rule. In the chart room, the two 17 Oct sheets go together at the lighthouse cross with north the same way.",
		"Drawer: 1-8-5-2. Chart room: Venn's sheet on the 17 Oct sheet, north up, lighthouse cross on lighthouse cross, then clip. The curve crosses band 3.",
	],
	"register": [
		"Venn's sheet goes on the chart table. The clip tin is on the ledge below it.",
		"The two 17 Oct sheets go together at the lighthouse cross, with north the same way.",
		EVIDENCE_REGISTER,
		"Choose the 17 Oct table sheet, lay Venn's sheet, turn it north up, pin his lighthouse cross, then clip. The curve crosses band 3.",
	],
	"zero": [
		"The listening room has a recording to preserve.",
		"The recording's last line gives the recorder its zero.",
		"Assemble and play the recording in the listening room.",
	],
	"office": [
		"Something in the office has changed.",
		"Venn's log is not finished with you.",
		EVIDENCE_OFFICE,
		"Go back to the Intake Office and open the tide log.",
	],
	"calibrate": [
		"The recorder in the chart room has two wheels and a lever.",
		"One wheel takes the recording's zero, the other the chart's interval.",
		EVIDENCE_CALIBRATE,
		"Set ZERO to 4 and INTERVAL to 3, then pull CALIBRATE.",
	],
	"record": [
		"The recorder's other panel takes three plates.",
		"The hatch frame is carved. Read it the way you'd meet it going down.",
		EVIDENCE_RECORD,
		"Slots left to right: BOUNDARY, RELATION, OBSERVER. Press RECORD.",
	],
	"jetty": [
		"The relay answered: attend jetty.",
		"The jetty is through the office's outer door.",
		"Go out to the jetty through the office.",
	],
	"away": [
		"The chart room is quiet for now.",
		"The station plan in the notebook shows where the work is.",
		"Follow the current tide in the other rooms.",
	],
	"plan": [
		"The station plan on the chart wall. Its lid is open now.",
		"His chart and the plan share a cross.",
		EVIDENCE_PLAN,
		PLAN_ANSWER_HINT,
	],
	"done": [
		"The margin has a procedure: three frames, one witness.",
		"The frames are made in the bunk room and the records vault.",
		"Follow the station outline's procedure in the bunk room and the vault.",
	],
}
## Items this room hands out (docs/design/puzzle-cards/flags.md section 4).
const ITEMS := {
	"chart_clips": {"name": "Chart clips", "desc": "Brass clips from the chart table, for holding sheets in register."},
}

## The wall she faces in the room view. Not state: never saved.
var wall := "A"
## The hand inside a close-up. Never saved; an object in the hand is back on its rack/tray.
var held_plate := ""
## The WITNESS pin in the hand (c_plan). Never saved: a load finds it back in its slot.
var held_pin := false

func initial_state() -> Dictionary:
	return {
		"clips_taken": false, "reg_base": "14", "reg_laid": false, "reg_rot": 2, "reg_snap": "",
		"p03_complete": false, "clip_misses": 0, "prophecy_seen": false,
		"zero": 7, "interval": 2, "gauges": ["", ""], "pull_misses": 0, "p04_complete": false,
		"stair_looked": false,
		"slots": ["", "", ""], "record_refusal": "", "record_misses": 0, "p05_complete": false,
		"looked_behind": false,
		"plan_lid_seen": false, "plan_laid": false, "plan_rot": PLAN_ROT_START, "plan_snap": "",
		"plan_registered": false, "p21_complete": false,
		"notices": [], "lamp_out_said": false,
	}

# ---------------------------------------------------------------------------
# persistence and flags
# ---------------------------------------------------------------------------
func load_state(d: Variant) -> void:
	state = initial_state()
	wall = "A"
	_drop_hand()
	if not d is Dictionary:
		return
	for k in SAVED_BOOLS:
		if d.get(k) is bool:
			state[k] = d[k]
	# The save's flags are loaded first and win: a completion the flags dropped (malformed)
	# is not restored from the room dict.
	for pair in OWNED:
		if state[pair[1]] and game != null and not game.flag(pair[0]):
			state[pair[1]] = false
	for k in SAVED_COUNTS:
		var n = d.get(k)
		if _whole(n) and float(n) >= 0.0:
			state[k] = int(n)
	var base = d.get("reg_base")
	if base is String and base in REG_BASES:
		state.reg_base = base
	var rot = d.get("reg_rot")
	if _whole(rot) and float(rot) >= 0.0 and float(rot) <= 3.0:
		state.reg_rot = int(rot)
	var snap = d.get("reg_snap")
	if snap is String and snap in REG_SNAPS:
		state.reg_snap = snap
	for k in ["zero", "interval"]:
		var w = d.get(k)
		if _whole(w) and float(w) >= 0.0 and float(w) <= 9.0:
			state[k] = int(w)
	var gauges = d.get("gauges")
	if gauges is Array and gauges.size() == 2:
		for i in 2:
			if gauges[i] is String and gauges[i] in GAUGE_VALUES:
				state.gauges[i] = gauges[i]
	var slots = d.get("slots")
	if slots is Array and slots.size() == 3:
		for i in 3:
			var p = slots[i]
			if p is String and p in PLATES and not p in state.slots:
				state.slots[i] = p
	var refusal = d.get("record_refusal")
	if refusal is String and refusal in RECORD_REFUSALS:
		state.record_refusal = refusal
	var prot = d.get("plan_rot")
	if _whole(prot) and float(prot) >= 0.0 and float(prot) <= 3.0:
		state.plan_rot = int(prot)
	var psnap = d.get("plan_snap")
	if psnap is String and psnap in REG_SNAPS:
		state.plan_snap = psnap
	var notes = d.get("notices")
	if notes is Array:
		# Saved order is kept: it records which change she met first.
		var known := []
		for n in NOTICES:
			known.append(n[0])
		for n in notes:
			if n is String and n in known and not n in state.notices:
				state.notices.append(n)
	_derive()

## Make the local arrangement agree with the completion flags.
func _derive() -> void:
	if state.p03_complete:
		state.clips_taken = true
		state.reg_base = REG_ANSWER.base
		state.reg_laid = true
		state.reg_rot = REG_ANSWER.rot
		state.reg_snap = REG_ANSWER.snap
	if state.p04_complete:
		state.zero = ZERO_ANSWER
		state.interval = INTERVAL_ANSWER
		state.gauges = ["ok", "ok"]
	if state.p05_complete:
		state.slots = PLATES.duplicate()
		state.record_refusal = ""
	if state.p21_complete:
		state.plan_registered = true
	if state.plan_registered:
		state.plan_laid = true
		state.plan_rot = PLAN_ROT
		state.plan_snap = PLAN_SNAP
	if not state.reg_laid:
		state.reg_snap = ""
	if not state.plan_laid:
		state.plan_snap = ""

func reconcile() -> void:
	for pair in OWNED:
		var key: String = pair[1]
		state[key] = state[key] or game.flag(pair[0])
		game.set_flag(pair[0], state[key])
	_derive()
	if state.reg_laid and not state.p03_complete and not game.has_item("venn_tide_sheet"):
		state.reg_laid = false
		state.reg_snap = ""
	if state.plan_laid and not state.p21_complete and not has_seen("composite_chart"):
		state.plan_laid = false
		state.plan_registered = false
		state.plan_snap = ""
	if state.p05_complete and game.value("p05_trace").is_empty():
		game.freeze_p05_trace()

# ---------------------------------------------------------------------------
# arrival, walls, Back
# ---------------------------------------------------------------------------
func arrive(ev: Array, first: bool) -> void:
	local_view = "room"
	_drop_hand()
	if first:
		_say(ev, ARRIVAL)
	_settle_notices()
	var n := _latest_pending()
	if n.is_empty():
		wall = "A"
	else:
		# The arrival line already said what n_arrival would say.
		_play_notice(n, ev, not (first and n[4] == ARRIVAL))

func back(ev: Array) -> void:
	if local_view == "room":
		return
	wall = CLOSEUP_WALL.get(local_view, wall)
	_leave_closeup()
	_settle_notices()
	var n := _latest_pending()
	if not n.is_empty():
		_play_notice(n, ev)

func _wall_entered(ev: Array, from: String) -> void:
	_settle_notices()
	var id := pending_notice(wall)
	if id != "":
		_play_notice(_notice(id), ev)
	elif state.p05_complete and not state.looked_behind and from == "B":
		state.looked_behind = true
		_say(ev, "Nothing behind me. Once was enough." if game.flag("t1x_turned") \
			else "Nothing behind me. The room's as I left it.")

func _leave_closeup() -> void:
	local_view = "room"
	_drop_hand()

func _drop_hand() -> void:
	held_plate = ""
	held_pin = false

# ---------------------------------------------------------------------------
# notices
# ---------------------------------------------------------------------------
func _notice_met(trigger: String) -> bool:
	match trigger:
		"visited":
			return ID in game.state.visited
		"t1x":
			return game.flag("t1x_threshold_crossed")
		"P04", "P21":
			return game.flag(trigger)
	if trigger.begins_with("band"):
		return game.weather_band() >= int(trigger.substr(4))
	return false

func _notice(id: String) -> Array:
	for n in NOTICES:
		if n[0] == id:
			return n
	return []

## The newest met notice on wall `w`, if she hasn't seen it; "" otherwise.
func pending_notice(w := "") -> String:
	if w == "":
		w = wall
	var latest := ""
	for n in NOTICES:
		if n[1] == w and _notice_met(n[2]):
			latest = n[0]
	return "" if latest == "" or latest in state.notices else latest

## The pending notice with the newest place in NOTICES, on any wall.
func _latest_pending() -> Array:
	var best := -1
	for w in WALLS:
		var id := pending_notice(w)
		if id != "":
			for i in NOTICES.size():
				if NOTICES[i][0] == id and i > best:
					best = i
	return [] if best < 0 else NOTICES[best]

## Older met notices on each wall are superseded: seen silently, their evidence kept.
func _settle_notices() -> void:
	for w in WALLS:
		var met := []
		for n in NOTICES:
			if n[1] == w and _notice_met(n[2]):
				met.append(n)
		for i in range(0, met.size() - 1):
			if not met[i][0] in state.notices:
				state.notices.append(met[i][0])
				_observe(met[i][3])

func _play_notice(n: Array, ev: Array, say_line := true) -> void:
	wall = n[1]
	if not n[0] in state.notices:
		state.notices.append(n[0])
	_observe(n[3])
	ev.append({"type": "fx", "id": "notice", "notice": n[0]})
	# Tide II's arrival: after the broken seal, the window. Said once, as part of the reveal.
	var lamp_out: bool = n[0] == "n_threshold" and sea_low() and not state.lamp_out_said
	if say_line:
		_say(ev, n[4], NOTICE_DELAY, lamp_out)
	if lamp_out:
		state.lamp_out_said = true
		_observe("sea_low")
		_say(ev, LAMP_OUT_LINE, NOTICE_DELAY + 2.6, true)

## Tide II, before it is done: the threshold is crossed and the sea in the window has gone out
## below his mud line, flat and still; the lighthouse is dark.
func sea_low() -> bool:
	return game.flag("t1x_threshold_crossed") and game.weather_band() == 0

# ---------------------------------------------------------------------------
# actions
# ---------------------------------------------------------------------------
func act(action: String, ev: Array) -> void:
	if WALL_OF.has(action):
		_leave_closeup()
		wall = WALL_OF[action]
		_hotspot(action, ev)
	elif action in ["turn_left", "turn_right"]:
		if local_view == "room":
			var from := wall
			wall = TURNS[wall][action]
			_sfx(ev, "turn")
			_wall_entered(ev, from)
	else:
		match local_view:
			"c_registration":
				_act_registration(action, ev)
			"c_recorder":
				_act_recorder(action, ev)
			"c_plan":
				_act_plan(action, ev)
	_settle_notices()

func _hotspot(h: String, ev: Array) -> void:
	var band := game.weather_band()
	match h:
		"sheet_table":
			_open_registration(ev)
		"plan_wall":
			_open_plan(ev)
		"clip_tin":
			if not state.clips_taken:
				state.clips_taken = true
				game.give("chart_clips", ev)
				_observe("clip_tin")
				_sfx(ev, "tin_open")
				_say(ev, "A tin of brass chart clips. I'll take them.")
			else:
				_say(ev, "The tin's empty. I have the clips.")
		"empty_clip":
			_observe("empty_clip")
			_say(ev, "His sheet is in it now. The label still says 'with E.V.'" if state.p03_complete \
				else "An empty clip on the board, labelled 'sheet 2 of 2: with E.V.'")
		"compass":
			if band < 4:
				_observe("compass")
				_say(ev, "A compass rose. North is where north should be.")
			else:
				_observe("compass_bent")
				_say(ev, "The compass is fine. It's the lines on his chart that bend. Toward where I stand.")
		"recorder":
			_open_recorder(ev)
		"seal":
			if not game.flag("t1x_threshold_crossed"):
				_observe("seal")
				_say(ev, SEAL_LINE)
			else:
				_observe("seal_broken")
				_say(ev, SEAL_BROKEN_LINE)
				_open_recorder(ev, false)
		"plate_rack":
			_observe("plates")
			_say(ev, "The rack's empty. The plates are in the slots." if state.p05_complete \
				else "Three brass plates with symbols and words.")
			_open_recorder(ev, false)
		"pen_drum":
			_pen_drum(ev, band)
		"sea_window":
			_say(ev, _sea_window_line(band))
			if band == 0:
				_observe("sea_low" if sea_low() else "sea_window")
		"hatch":
			if not state.p04_complete:
				_observe("hatch")
				_say(ev, "The observation hatch. Iron, wheel-latched. The wheel won't turn from this side.")
			elif not has_seen("stair_down"):
				_observe("stair_down")
				_look_down_stair()
				_say(ev, "A dry stair, going down below the waterline, and dry. A pressure gate across it.")
			else:
				_say(ev, "The stair goes down. The hatch tab will take me.")
		"outer_window":
			if band >= 7:
				_observe("water_standing")
				_say(ev, "The water stands upright in the frame, its surface vertical. A pale line crosses it, slowly.")
			elif state.p04_complete:
				_observe("outer_window")
				_look_down_stair()
				_say(ev, "There is water on the other side of that wall. There is not room for both.")
			else:
				_observe("outer_window")
				_say(ev, "Seawater to the top of the frame, at the level of the hatch. This room is a floor above the jetty.")
			if band >= 7 and state.p04_complete:
				_look_down_stair()
		"hatch_scratches":
			_observe("scratches")
			_say(ev, "The same shape as the curve on the composite." if state.p03_complete \
				else "Three marks cut down the frame, top to bottom: a bracket, two linked strokes, a hollow circle.")
			if has_seen("miniature") and not state.p05_complete:
				_say(ev, SCRATCHES_AFTER_MINIATURE, 2.0)

func _look_down_stair() -> void:
	if not state.stair_looked:
		state.stair_looked = true
		game.record_move("stair_looked")

func _pen_drum(ev: Array, band: int) -> void:
	if not game.flag("t1x_threshold_crossed"):
		_say(ev, "The pen's scratching. The drum isn't turning. It writes the same line over and over.")
	elif not state.p04_complete:
		_observe("pen_report")
		_say(ev, "It's tracing figures. 10. 2. 19:34. 9.9. My report.")
	elif band < 3:
		_say(ev, "Turning now. High water, low water, a steady line.")
	elif band <= 4:
		_observe("vis_nil")
		_say(ev, "VIS 0.0 NM. Visibility nil. The window is right there.")
	elif band <= 6:
		_observe("attending")
		_say(ev, "SEA STATE: ATTENDING. The drum has stopped. The pen hasn't.")
	else:
		_say(ev, "SEA STATE: ATTENDING. The line is flat and pressed hard into the paper.")

func _sea_window_line(band: int) -> String:
	match band:
		0:
			if sea_low():
				return "The lighthouse is out. The sea's down below his mud line, flat as a plate. Not a wave on it."
			return "Overcast. The lighthouse is clear and the sea is ordinary."
		1, 2:
			return "Rain on the glass. The water's darker than it was."
		3:
			return "The sea's still there. I can see it. The pen says I can't."
		4:
			return "The horizon in this window sits higher than it should."
		5:
			return "No colour left in it. Sea and sky the same grey. Rain, and no sound of rain."
		6:
			return "Dark, close to the glass. The lighthouse is in the wrong place."
	return "The surface is right outside. It moves, very slowly, like something settling."

# --- P03 part 2 -----------------------------------------------------------------
func _open_registration(ev: Array) -> void:
	wall = "A"
	var first := not has_seen("sheets")
	local_view = "c_registration"
	_drop_hand()
	_observe("sheets")
	if state.p03_complete:
		_say(ev, "The composite, clipped. The curve is still there.")
	elif first:
		_say(ev, "The chart table. Two sheets, the 14th and the 17th, and an empty clip for a third.")
	else:
		_say(ev, "His chart table.")
	if game.flag("P02") and not state.prophecy_seen:
		state.prophecy_seen = true
		_say(ev, "'Mercer will be standing at the chart table.' I am.", 1.2, true)

func _act_registration(action: String, ev: Array) -> void:
	if not action.begins_with("reg_"):
		return
	if state.p03_complete:
		_say(ev, REG_CLIPPED)
		return
	match action:
		"reg_base_14", "reg_base_17":
			state.reg_base = action.substr(9)
			_sfx(ev, "sheet_slide")
		"reg_lay", "reg_table":
			# His sheet is laid by using it on the table; a bare click says what's missing.
			if not state.reg_laid:
				_say(ev, REG_HAS_SHEET if game.has_item("venn_tide_sheet") else REG_REFUSE.no_sheet)
		"reg_lift":
			state.reg_laid = false
			state.reg_snap = ""
			_sfx(ev, "sheet_slide")
		"reg_rot_cw", "reg_rot_ccw":
			if not state.reg_laid:
				_say(ev, REG_NOT_LAID)
				return
			state.reg_rot = posmod(int(state.reg_rot) + (1 if action == "reg_rot_cw" else -1), 4)
			_sfx(ev, "sheet_rotate")
		"reg_snap_lighthouse", "reg_snap_buoy", "reg_snap_datum":
			if not state.reg_laid:
				_say(ev, REG_NOT_LAID)
				return
			state.reg_snap = action.substr(9)
			_sfx(ev, "cross_snap")
		"reg_example":
			_observe("example")
			_say(ev, "Two sheets that have nothing to do with each other, registered at a cross. The line runs through band 1.")
		"reg_clip":
			# The clips go on the rail from the inventory; the bare rail is empty.
			_say(ev, REG_HAS_CLIPS if game.has_item("chart_clips") else REG_REFUSE.no_clips)

func _reg_lay(ev: Array) -> void:
	if state.p03_complete:
		_say(ev, REG_CLIPPED)
		return
	if not game.has_item("venn_tide_sheet"):
		_say(ev, REG_REFUSE.no_sheet)
		return
	if state.reg_laid:
		_say(ev, REG_LAID_ALREADY)
		return
	state.reg_laid = true
	_observe("venn_sheet")
	_say(ev, "His sheet is tracing paper. Folded so its north arrow points down.")
	_sfx(ev, "sheet_slide")

## The first inconsistency in the registration, or "" when it's in register.
func reg_refusal() -> String:
	if not game.has_item("venn_tide_sheet"):
		return "no_sheet"
	if not state.reg_laid:
		return "not_laid"
	if not game.has_item("chart_clips"):
		return "no_clips"
	if state.reg_base != REG_ANSWER.base:
		return "date"
	if int(state.reg_rot) != REG_ANSWER.rot:
		return "north"
	if state.reg_snap == "":
		return "no_snap"
	if state.reg_snap != REG_ANSWER.snap:
		return "cross"
	return ""

func _reg_clip(ev: Array) -> void:
	var why := reg_refusal()
	if why != "":
		_sfx(ev, "clip_refuse")
		state.clip_misses = int(state.clip_misses) + 1
		_say(ev, REG_REFUSE[why])
		return
	game.take("venn_tide_sheet")
	state.p03_complete = true
	game.solve("P03", ev)
	_observe("calibration_interval")
	_observe("composite_chart")
	game.record_move("charts_aligned")
	_sfx(ev, "clip_snap", 0.0)
	_fx(ev, "composite")
	_say(ev, "Clipped. The two halves meet.", 0.3, true)
	_say(ev, CURVE_LINE, 2.4, true)
	if game.tide_done(1):
		_say(ev, RECONCILE_LINE, 5.6, true)

# --- P04 / P05: the recorder ------------------------------------------------------
func _open_recorder(ev: Array, opening_line := true) -> void:
	wall = "B"
	var first := not has_seen("recorder")
	local_view = "c_recorder"
	_drop_hand()
	if opening_line:
		_say(ev, "The tide recorder. Copper float, bone paper, a lever polished by a lot of hands." if first \
			else "The recorder.")
	_observe("recorder")

func _act_recorder(action: String, ev: Array) -> void:
	if action == "rec_plate_info":
		_observe("calibration_plate")
		_say(ev, "ZERO and INTERVAL are separate controls. His example: zero 7, interval 2, then pull.")
	elif action in WHEELS or action in ["rec_seal", "rec_calibrate"]:
		_act_calibration(action, ev)
	elif action == "rec_shutter" or action == "rec_miniature" or action == "rec_record" \
			or action.begins_with("rec_plate_") or action.begins_with("rec_slot_"):
		_act_record_panel(action, ev)

func _act_calibration(action: String, ev: Array) -> void:
	if not game.flag("t1x_threshold_crossed"):
		if action == "rec_calibrate":
			_say(ev, "It won't pull. Not with his seal across it.")
		else:
			_observe("seal")
			_say(ev, SEAL_LINE)
		return
	if action == "rec_seal":
		_observe("seal_broken")
		_say(ev, SEAL_BROKEN_LINE)
		return
	if state.p04_complete:
		_say(ev, CALIBRATED)
		return
	match action:
		"rec_zero_up", "rec_zero_down":
			state.zero = posmod(int(state.zero) + (1 if action == "rec_zero_up" else -1), 10)
			game.record_move("zero_turned")
			_wheel_moved(ev)
		"rec_int_up", "rec_int_down":
			state.interval = posmod(int(state.interval) + (1 if action == "rec_int_up" else -1), 10)
			game.record_move("interval_set")
			_wheel_moved(ev)
		"rec_calibrate":
			_calibrate(ev)

func _wheel_moved(ev: Array) -> void:
	state.gauges = ["", ""]
	_sfx(ev, "wheel_click")

func _calibrate(ev: Array) -> void:
	if not game.flag("P02"):
		_say(ev, "I don't have a zero to set it to. The listening room has the recording.")
		return
	var zero_ok: bool = int(state.zero) == ZERO_ANSWER
	var int_ok: bool = int(state.interval) == INTERVAL_ANSWER
	state.gauges = ["ok" if zero_ok else "mismatch", "ok" if int_ok else "mismatch"]
	_sfx(ev, "lever_pull", 0.0)
	if not (zero_ok and int_ok):
		_sfx(ev, "lever_refuse", 0.25)
		state.pull_misses = int(state.pull_misses) + 1
		if not zero_ok and not int_ok:
			_say(ev, "Both out.", 0.3)
		elif not zero_ok:
			_say(ev, "The zero's out.", 0.3)
		else:
			_say(ev, "The interval's out.", 0.3)
		return
	state.p04_complete = true
	game.solve("P04", ev)
	game.record_move("hatch_opened")
	_observe("stair_threshold")
	_sfx(ev, "calibrate_ratchet", 0.25)
	_fx(ev, "drum_turn")
	_say(ev, "A clean ratchet. The pen settles into a steady line, and the drum turns. It's recording.", 0.4, true)
	_sfx(ev, "hatch_open", 3.2)
	_say(ev, "Behind me, something heavy swings open. No water. Not a drop.", 3.6, true)

func _act_record_panel(action: String, ev: Array) -> void:
	if not state.p04_complete:
		_say(ev, SHUTTERED)
		return
	if state.p05_complete:
		_say(ev, RECORDED)
		return
	if action == "rec_shutter":
		_say(ev, "The shutter's up. Three slots, left to right, and the rack.")
	elif action == "rec_miniature":
		_observe("miniature")
		_say(ev, MINIATURE)
	elif action == "rec_record":
		_record(ev)
	elif action.begins_with("rec_plate_"):
		var p := action.substr(10)
		if p in PLATES:
			_pick_plate(p, ev)
	elif action.begins_with("rec_slot_"):
		var s := action.substr(9)
		if s.is_valid_int() and int(s) >= 0 and int(s) < 3:
			_use_slot(int(s), ev)

func _pick_plate(p: String, ev: Array) -> void:
	_observe("plates")
	if held_plate == p:
		held_plate = ""
	else:
		var i: int = state.slots.find(p)
		if i >= 0:
			state.slots[i] = ""
		held_plate = p   # a plate already in the hand goes back to the rack
	_sfx(ev, "plate_pick")

func _use_slot(i: int, ev: Array) -> void:
	if held_plate != "":
		state.slots[i] = held_plate   # a plate already there goes back to the rack
		held_plate = ""
		_sfx(ev, "plate_set")
	elif state.slots[i] != "":
		held_plate = state.slots[i]
		state.slots[i] = ""
		_sfx(ev, "plate_pick")
	else:
		_say(ev, "An empty slot.")

## The RECORD refusal for the current slots, or "".
func record_check() -> String:
	if "" in state.slots:
		return REFUSE_INCOMPLETE
	if state.slots[0] != "boundary":
		return REFUSE_BOUNDARY
	if state.slots[1] != "relation":
		return REFUSE_RELATION
	return ""

func _record(ev: Array) -> void:
	var why := record_check()
	_sfx(ev, "record_key", 0.0)
	if why != "":
		state.record_refusal = why
		_sfx(ev, "record_refuse", 0.2)
		_say(ev, RECORD_MISS_LINES[int(state.record_misses) % RECORD_MISS_LINES.size()], 0.4)
		state.record_misses = int(state.record_misses) + 1
		return
	state.p05_complete = true
	state.record_refusal = ""
	var trace := game.freeze_p05_trace()
	game.solve("P05", ev)
	_observe("departure_record")
	_observe("relay")
	_sfx(ev, "relay_clack", 0.3)
	_sfx(ev, "far_bell", 1.6)
	_sfx(ev, "strip_print", 3.0)
	_sfx(ev, "strip_print_last", 8.0)
	_sfx(ev, "relay_clack", 11.0)
	_fx(ev, "strip_print")
	_say(ev, "The relay clacks over. Somewhere out on the water, a bell answers.", 0.6, true)
	_say(ev, "It isn't printing readings. It's printing what I did: '" + _trace_text(trace) + "'", 3.4, true)
	_say(ev, "Then one more line.", 7.6, true)
	_say(ev, "'" + line4() + "'", 8.8, true)
	_say(ev, "The relay again. Under it: COLLECTION ANSWERS. ATTEND JETTY.", 11.4, true)

func line4() -> String:
	return LINE4_TURNED if game.flag("t1x_turned") else LINE4_STILL

func _trace_text(trace: Array) -> String:
	var texts := []
	for t in trace:
		texts.append(GameSim.move_text(t))
	return " ".join(texts)

# --- P21: the plan ------------------------------------------------------------------
## The lid comes off after P19 and P20 (the GDD's gate).
func plan_unlocked() -> bool:
	return game.flag("P19") and game.flag("P20")

## His composite (P03) is the thing laid on the plan; it lives in the notebook.
func has_composite() -> bool:
	return has_seen("composite_chart")

func _open_plan(ev: Array) -> void:
	wall = "A"
	var first := not has_seen("plan")
	local_view = "c_plan"
	_drop_hand()
	_observe("plan")
	if state.p21_complete:
		_say(ev, "It's a body, sitting. My name where its heart would be.")
		return
	_say(ev, "The station plan, 1889, revised in his hand. Bracket marks, and a word: BOUNDARY." if first \
		else "The station plan.")
	if plan_unlocked() and not state.plan_lid_seen:
		state.plan_lid_seen = true
		_say(ev, "The lid's screws are out. Someone lined them up on the frame. Nine of them.", 1.2)

func _act_plan(action: String, ev: Array) -> void:
	if action in MARGINS:
		_say(ev, PIN_PEOPLE if held_pin else "PERSONAL EVIDENCE: the kitchen and the bunks, printed in the margin.")
		return
	if action.begins_with("plan_zone_"):
		var z := action.substr(10)
		if z in ZONES:
			_plan_zone(z, ev)
		return
	if not action in ["plan_lay", "plan_lift", "plan_rotate", "plan_rotate_cw", "plan_rotate_ccw", "plan_clip",
			"plan_pin", "plan_snap_lighthouse", "plan_snap_buoy", "plan_snap_datum"]:
		return
	if not plan_unlocked():
		_say(ev, PLAN_LID)
		return
	if state.p21_complete:
		_say(ev, PLAN_FIXED)
		return
	if action == "plan_pin":
		_plan_pick_pin(ev)
		return
	if state.plan_registered:
		_say(ev, PLAN_CLIPPED)
		return
	match action:
		"plan_lay":
			if not has_composite():
				_say(ev, PLAN_NO_COMPOSITE)
			elif not state.plan_laid:
				state.plan_laid = true
				state.plan_rot = PLAN_ROT_START
				state.plan_snap = ""
				_sfx(ev, "sheet_slide")
				_say(ev, "His composite, unclipped from the table and laid over the plan. North up, as it was.")
		"plan_lift":
			state.plan_laid = false
			state.plan_snap = ""
			_sfx(ev, "sheet_slide")
		"plan_rotate", "plan_rotate_cw", "plan_rotate_ccw":
			if not state.plan_laid:
				_say(ev, PLAN_NOT_LAID)
				return
			state.plan_rot = posmod(int(state.plan_rot) + (-1 if action == "plan_rotate_ccw" else 1), 4)
			_sfx(ev, "sheet_rotate")
		"plan_snap_lighthouse", "plan_snap_buoy", "plan_snap_datum":
			if not state.plan_laid:
				_say(ev, PLAN_NOT_LAID)
				return
			state.plan_snap = action.substr(10)
			_sfx(ev, "cross_snap")
		"plan_clip":
			_plan_clip(ev)

## True when his composite lies on the plan in register: north with the plan's north, his
## lighthouse cross on the plan's.
func plan_in_register() -> bool:
	return state.plan_laid and int(state.plan_rot) == PLAN_ROT and state.plan_snap == PLAN_SNAP

func _plan_clip(ev: Array) -> void:
	if not state.plan_laid:
		_say(ev, PLAN_NOT_LAID if has_composite() else PLAN_NO_COMPOSITE)
		return
	if not plan_in_register():
		# Nothing is consumed: the composite stays where she left it.
		_sfx(ev, "clip_refuse")
		_say(ev, PLAN_WRONG)
		return
	state.plan_registered = true
	_observe("plan_registered")
	_sfx(ev, "clip_snap", 0.0)
	_sfx(ev, "plan_resolve", 1.0)
	_fx(ev, "plan_register")
	_say(ev, "Clipped. The line runs down through the lantern gallery, the chart room, the listening room, the laboratory.", 0.3, true)
	_say(ev, "The rooms it touches fill in, all one colour. A head. Shoulders. Something sitting.", 3.2, true)
	_say(ev, "The office and the vault lie outside it, underneath. Where a name would go.", 6.4, true)
	_say(ev, "His three marks end in the chamber in the middle.", 9.2, true)

func _plan_pick_pin(ev: Array) -> void:
	if not state.plan_registered:
		_say(ev, PIN_NOT_YET)
		return
	held_pin = not held_pin
	_sfx(ev, "tile")

func _plan_zone(z: String, ev: Array) -> void:
	if not held_pin or state.p21_complete:
		_say(ev, ZONE_DESC[z])
		return
	if z != "centre":
		# The pin stays in the hand; nothing is used up.
		_say(ev, PIN_REFUSE[z])
		return
	held_pin = false
	state.p21_complete = true
	game.solve("P21", ev)
	_observe("station_outline")
	_observe("plan_name")
	_settle_notices()
	if not "n_b6" in state.notices:
		state.notices.append("n_b6")
	_fx(ev, "plan_resolve")
	_sfx(ev, "fix_pin", 0.0)
	_sfx(ev, "name_print", 4.2)
	_say(ev, "The pin goes in, where his marks end.", 0.2, true)
	_say(ev, "The rooms aren't where the walls are. They're where a body would be. Sitting.", 1.8, true)
	_say(ev, "In the witness frame, in the recorder's type: ADA MERCER.", 4.8, true)

# ---------------------------------------------------------------------------
# items
# ---------------------------------------------------------------------------
func use_item(item: String, target: String, ev: Array) -> bool:
	var line := ""
	match item:
		"venn_tide_sheet":
			var on_table: bool = target in ["reg_table", "reg_lay"] and local_view == "c_registration"
			if target == "sheet_table" or on_table:
				if local_view != "c_registration":
					_open_registration(ev)
				_reg_lay(ev)
				_settle_notices()
				return true
		"chart_clips":
			if target == "reg_clip" and local_view == "c_registration":
				if state.p03_complete:
					_say(ev, REG_CLIPPED)
				else:
					_reg_clip(ev)
				_settle_notices()
				return true
			if target == "plan_clip" and local_view == "c_plan":
				# Her clips do what the plan's own clip does.
				_act_plan("plan_clip", ev)
				_settle_notices()
				return true
			if target == "sheet_table" or target == "reg_table":
				line = "The clips go on the rail, once the sheets are in register."
		"inspection_lens":
			match target:
				"outer_window":
					line = "Through the lens there's no glass in the frame. Just water, standing in it."
					_observe("lens_window")
				"pen_drum":
					line = "The nib is wet. Salt dries white along the line it writes."
				"hatch_scratches":
					line = "Cut from the stair side. The burr curls toward this room."
				"sheet_table":
					line = "Every cross is pricked through with a pin. Many times."
				"compass":
					line = "The needle is steady. It isn't the compass."
		"pencil":
			if target == "sheet_table":
				line = "I don't amend his charts."
	if line == "":
		return false
	if WALL_OF.has(target):
		_leave_closeup()
		wall = WALL_OF[target]
	_say(ev, line)
	return true

# ---------------------------------------------------------------------------
# notebook, objectives
# ---------------------------------------------------------------------------
## The notebook text for an observation. departure_record is computed from the stored
## trace and t1x_turned only, so it reads the same after a save and load.
func observation_text(obs: String) -> String:
	if obs == "departure_record" and state.p05_complete:
		return "The recorder wrote down the last three things I did, in order: '" \
			+ _trace_text(game.value("p05_trace")) + "' Then: '" + line4() + "'"
	return OBSERVATIONS.get(obs, "")

func objective() -> String:
	if not game.flag("P03"):
		return "register" if game.has_item("venn_tide_sheet") else "sheet_missing"
	if not game.flag("P02"):
		return "zero"
	if game.tide_done(1) and not game.flag("t1x_threshold_crossed"):
		return "office"
	if not game.flag("P04"):
		return "calibrate"
	if not game.flag("P05"):
		return "record"
	if not game.flag("P06"):
		return "jetty"
	if not (game.flag("P19") and game.flag("P20")):
		return "away"
	if not game.flag("P21"):
		return "plan"
	return "done"

## P03 (register), T1X (office), P04, P05 and P21 have four tiers (nudge, relationship, evidence, answer); the rest three.
func hint_tiers() -> int:
	return 4 if HINTS.get(objective(), []).size() >= 4 else 3

## The tier at `level` (0..hint_tiers()-1); past the end, the last tier (the answer).
func hint_line(level: int) -> String:
	var ladder: Array = HINTS.get(objective(), [])
	if ladder.is_empty():
		return super.hint_line(level)
	return ladder[mini(level, ladder.size() - 1)]

## Before the lamp the instrument doors are latched; after it, she's free to come.
func locked_line() -> String:
	if not game.flag("P01"):
		return LOCKED
	return "The latch has gone. The office isn't finished with me yet."

# ---------------------------------------------------------------------------
# debug
# ---------------------------------------------------------------------------
func debug_prepare(t: int) -> void:
	if t >= 2:
		_prepare_p03()
	if t >= 3:
		state.p04_complete = true
		state.p05_complete = true
		state.stair_looked = true
		for o in ["recorder", "seal_broken", "calibration_plate", "stair_threshold", "stair_down",
				"plates", "departure_record", "relay"]:
			_observe(o)
		if game.value("p05_trace").is_empty():
			# The trace real play froze. A tide start keeps no movement history of its own
			# (core_test), so the moves are recorded only long enough to freeze them.
			var before: Array = game.value("movement_events")
			game.record_move("interval_set")
			game.record_move("hatch_opened")
			game.record_move("stair_looked")
			game.freeze_p05_trace()
			game.state.movement_events = before
	if t >= 8:
		state.p21_complete = true
		state.plan_lid_seen = true
		_observe("plan")
		_observe("plan_registered")
		_observe("station_outline")
		_observe("plan_name")
	_derive()

func _prepare_p03() -> void:
	state.p03_complete = true
	state.clips_taken = true
	game.give("chart_clips")
	for o in ["sheets", "clip_tin", "venn_sheet", "calibration_interval", "composite_chart"]:
		_observe(o)
	_derive()

## Dev: the room's own stages 0..8 (see docs: R03 logic spec).
func debug_jump(n: int) -> void:
	wall = "A"
	_drop_hand()
	match n:
		0, 1:
			_jump_lamp()
			if n == 1:
				for it in ["venn_tide_sheet", "inspection_lens", "chart_clips"]:
					game.give(it)
				state.clips_taken = true
				_observe("clip_tin")
		2:
			_jump_lamp()
			game.set_flag("P02")
			game.record_move("charts_aligned")
			_prepare_p03()
		3, 4:
			game.debug_tide(2, ID)
			if n == 4:
				game.record_move("zero_turned")
				game.record_move("interval_set")
				game.record_move("hatch_opened")
				state.p04_complete = true
				_observe("stair_threshold")
		5:
			game.debug_tide(3, ID)
		6:
			game.debug_tide(7, ID)
			game.set_flag("P19")
			game.set_flag("P20")
		7:
			game.debug_tide(8, ID)
		8:
			game.debug_tide(9, ID)
	wall = "A"
	local_view = "room"
	reconcile()

## Stage 0: the lamp mended in the office (R02's stage 1), standing in the chart room.
func _jump_lamp() -> void:
	game.room("R02").debug_jump(1)
	game.debug_enter(ID)

# ---------------------------------------------------------------------------
# read helpers for the view
# ---------------------------------------------------------------------------
func pen_text() -> String:
	if not game.flag("t1x_threshold_crossed"):
		return ""
	if not state.p04_complete:
		return "10 · 2 · 19:34 · 9.9"
	var band := game.weather_band()
	if band < 3:
		return ""
	return "VIS 0.0 NM" if band <= 4 else "SEA STATE: ATTENDING"

## Puzzles solved anywhere in the station (P01..P27 flags set).
func solved_count() -> int:
	var n := 0
	for i in range(1, 28):
		if game.flag("P%02d" % i):
			n += 1
	return n

## The ink knot at the pen's nib: the pen keeps writing in one place while the drum is still,
## and the knot grows with every solved puzzle. 6 px, plus 4 px a puzzle, never over 60.
func ink_knot_radius() -> float:
	return minf(KNOT_MAX, KNOT_BASE + KNOT_STEP * solved_count())

func drum_turning() -> bool:
	return state.p04_complete and game.weather_band() < 5

## The printed strip after P05: heading, her three moves, line 4, the relay. Empty before.
func strip_lines() -> Array:
	if not state.p05_complete:
		return []
	var out := [STRIP_HEAD]
	for t in game.value("p05_trace"):
		out.append(GameSim.move_text(t))
	out.append(line4())
	out.append(STRIP_RELAY)
	return out

## The current RECORD refusal printed on the panel ("" for none).
func refusal_text() -> String:
	return state.record_refusal

## The rack in home order (observer, boundary, relation): a plate id, or "" where it's out.
func rack_plates() -> Array:
	var out := []
	for p in RACK_HOME:
		out.append("" if p in state.slots or p == held_plate else p)
	return out

func plan_state() -> Dictionary:
	return {"laid": state.plan_laid, "rot": int(state.plan_rot), "snap": state.plan_snap,
		"registered": state.plan_registered, "held_pin": held_pin, "unlocked": plan_unlocked(),
		"lid_seen": state.plan_lid_seen, "complete": state.p21_complete, "composite": has_composite()}

static func _whole(v: Variant) -> bool:
	return (v is int or v is float) and float(v) == floorf(float(v))
