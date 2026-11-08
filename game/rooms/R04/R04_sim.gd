class_name R04Sim
extends RoomSim
## R04, the Listening Room. Owns P02 (tomorrow's recording), P17 (two people in one sentence)
## and P19 (speak to the empty channel): docs/design/puzzle-cards/P02.md, P17.md, P19.md and
## rooms.md R04. Node-free and deterministic; the view reads the helpers at the bottom and the
## transient highlight vars (seam_break, mix_result, board_tape), and plays the events.
##
## Two base views: "room" (A, the funnel wall) and "board" (B, the channel board; not a
## close-up). Close-ups: c_spindle (P02), c_mixer (P17), c_channels (P19).

const ID := "R04"
const TITLE := "Listening Room"
const REQUIRES := ["P01"]
const LOCKED := "The listening room door is latched. Electrically, by the feel of it."
const RESUME := "Back in the listening room."
const ARRIVAL := "The listening room. Six ear trumpets, all pointing at one damp patch in the plaster. It's the shape of someone sitting."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R02", "Office", []],
	["R03", "Chart room", []],
]

## View A (the funnel wall) and view B (the channel board) hotspots.
const HOTSPOTS := ["spindle", "band_tray", "printer", "stool", "funnels", "plaster", "to_board"]
const BOARD_HOTSPOTS := ["witness_key", "channel_a", "channel_b", "channel_c", "motor", "mixer",
	"speaker", "to_funnels"]
const CLOSEUPS := ["c_spindle", "c_mixer", "c_channels"]

# --- P02: three of four bands on the spindle --------------------------------------------------
## The felt tray's order (deliberately not alphabetical). D is the decoy: a second START band,
## scratched 14 OCT on its rim, whose seam can be made to run on into A and B. The transcript
## card is headed 17 OCT; only C is that day.
const BANDS := ["B", "D", "A", "C"]
const SOLUTION_ORDER := ["C", "A", "B"]
## Snap positions: 0 = I, 1 = II, 2 = III.
const SOLUTION_ROT := {"C": 0, "A": 2, "B": 1}
## The diagonal seam. A band at rotation r meets its left neighbour at phase (r + in) % 3 and
## its right neighbour at (r + out) % 3. C carries the START notch, B the END notch; the
## spindle's START arrow is phase 0.
const SEAM := {
	"C": {"in": 0, "out": 1, "start": true},
	"D": {"in": 1, "out": 0, "start": true, "wrong_day": true},
	"A": {"in": 2, "out": 0},
	"B": {"in": 1, "end": true},
}
const START_PHASE := 0
const SEAM_LINES := {
	"start_end": "The start notch is at the wrong end.",
	"start_arrow": "It jumps right at the start. The notch isn't on the arrow.",
	"join1": "It jumps at the first join. The seam doesn't carry on.",
	"join2": "It jumps at the second join. The seam doesn't carry on.",
	"wrong_day": "That's the wrong day.",
}
const SEAM_TRANSCRIPT := {
	"start_end": ["[needle skips]  — seam —"],
	"start_arrow": ["[needle skips]  — seam —"],
	"join1": ["VENN: Grey—  — seam —"],
	"join2": ["VENN: Greywake, seventeenth October. Calib—  — seam —"],
	"wrong_day": ["VENN: Greywake, fourteenth October..."],
}
## The decoy's voice, when D starts the spindle and the seam breaks at the second join.
const JOIN2_D := ["VENN: Greywake, fourteenth Oc—  — seam —"]
## The day the transcript card is headed with, and the day scratched on D (the view writes both).
const CARD_DAY := "17 OCT"
const D_DAY := "14 OCT"
## [line, delay] of Venn's recording; the same four lines print on the transcript roll.
const RECORDING := [
	["VENN: Greywake, seventeenth October. Calibration zero is four. Write it down, whoever you are.", 0.6],
	["VENN: The recorder is accurate. That is the difficulty.", 5.4],
	["[a chair creaks on the cylinder. Then, close to the horn, someone who is not Venn breathes in.]", 9.0],
	["VENN: Eighteenth October. Mercer will be standing at the chart table.", 11.8],
]
const RECORDING_AFTER := [
	["The motor stopped. The cylinder went round once more anyway.", 16.4],
	["The eighteenth. That's tomorrow.", 19.0],
	["Mercer. He had my name before I signed anything.", 21.0],
	["It's on the contract. He wrote the contract.", 23.4],
]
const PRINTER_DELAYS := [0.0, 2.0, 4.0, 5.6]
const PRESERVE_LINE := "'Preserve the recording before winding again.' I'll leave it as it is."

# --- P17: the session spool -------------------------------------------------------------------
const OFFSET_MIN := -3
const OFFSET_MAX := 3
const OFFSET_SOLUTION := -2
const MIX_LINES := {
	"venn": "VENN: Leave the witness line open.",
	"nora": "NORA: Tell them I was here.",
}
const MIX_OVERLAP := ["VENN: Leave the wit… line o…", "NORA: …ell them I wa… here"]
const MIX_COMBINED := "VENN / NORA: Leave the witness line... I was here."
## The pencil margin note on the session log, found after the separation (the view writes it).
const MARGIN_NOTE := ["An automatic countersign closes a record. A human correction keeps it open.",
	"Channel C is my station now. E.V."]
## Under the rule, in pencil, two marks joined by a stroke: a solid triangle and a hollow circle.
## The Index model in the vault (R10, P23) carries the same two over two of its terminals.
const MARGIN_MARKS := ["triangle", "circle"]
## The marks' own notebook entry (evidence for P23), filed with the separation.
const MARGIN_MARKS_LINE := "Session log margin: a triangle and a hollow circle, in Venn's pencil."
## The sync bell is heard, never drawn: one 1.2 kHz strike per track (sfx "mix_bell"), on a film
## frame. The spool's frame ticks run every FRAME_S seconds from PLAY (tick n at n * FRAME_S).
## Venn's bell falls on BELL_FRAME.venn; Nora's on BELL_FRAME.nora plus the slider's offset, so at
## OFFSET_SOLUTION both fall on the same frame. Each enabled track strikes its own bell.
const FRAME_S := 0.5
const BELL_FRAME := {"venn": 2, "nora": 4}
const MIX_MOTOR_OFF := "Motor's off — on the channel board."

# --- P19: the dead channel --------------------------------------------------------------------
const QUESTIONS := ["q_where", "q_whole", "q_need"]
const ANSWERS := {
	"q_where": ["where", "MERCER: Where are they?",
		"VENN: Here. In the instruments. I kept them where they could still be reached.",
		"VENN: I never found how to let them out."],
	"q_whole": ["whole", "MERCER: Are they still themselves?",
		"VENN: I don't know. I can't promise you they're whole.",
		"VENN: They answer. That's all I can tell you."],
	"q_need": ["need", "MERCER: What do you need from me?",
		"VENN: If you break it, they end, every trace. If you don't, someone has to stay.",
		"VENN: Physically. Here. A witness, not a signature. Three days I have stood where you are standing. There is less of me each tide."],
}
const ANSWER_DELAYS := [0.0, 2.2, 6.0]
## After P19, funnel 5 faces her: "It's dark all the way down." lands this long after the click,
## and the room holds its breath (every bed drops out) for HOLE_HOLD seconds from that line.
const HOLE_DELAY := 1.4
const HOLE_HOLD := 2.0
## The printed procedure on the board. It says what, never how: the failures teach the how.
const PROCEDURE := "Address a witness on a quiet line."
## WITNESS with the motor running: channel C carries the director's 1927 dictation off the cylinder.
const ROOK_DICTATION := ["ROOK (channel C, 1927): Session of the eighteenth of October. Eight present.",
	"ROOK (channel C, 1927): The instruments are recording. Witness station C is vacant."]
const LINE_OCCUPIED := "The line is occupied."
## WITNESS on a quiet line (motor off, A and B closed, C open) before anyone can be on it.
const LINE_QUIET := "The line is quiet. Nobody is on it yet."
## WITNESS with A or B open: the P17 session voices bleed onto C.
const LINE_CROWDED := "Two other voices on the line. His can't get through them."
## The board's status tape after a failed WITNESS.
const TAPE_MOTOR := "LINE OCCUPIED."
const TAPE_CROWDED := "LINE CROWDED."
const ON_THE_LINE := "Not while he's on the line."

# --- escalation --------------------------------------------------------------------------------
## First-time arrival holds, oldest first. Seeing one retires every older one.
const NOTICES := ["throat", "leak_wind", "leak_silence", "funnels_turned", "c_presence", "plaster_bulge"]
const NOTICE_LINES := {
	"leak_wind": "Wind. Out of number five. It has turned halfway out of the wall.",
	"leak_silence": "Every funnel's gone quiet.",
	"funnels_turned": "The funnels. They're pointing at the seat.",
	"c_presence": "Channel C has something on it. Room tone. Another room's.",
	"plaster_bulge": "The wall is breathing out.",
}

const OBSERVATIONS := {
	"funnels": "Six brass ear trumpets, numbered 1 to 6. Their pipes run into sealed plaster and don't come out the other side. Number 5's bell faces the wall.",
	"throat": "Someone cleared their throat in funnel 3 the first time I came in. Its pipe runs into the plaster.",
	"plaster": "Sealed plaster behind the funnels. On the other side is the outer wall, and then the sea.",
	"stain_seated": "A damp patch in the plaster at chair height, the shape of someone sitting. All six trumpets point at it.",
	"stool": "A tip-up listening seat, polished by use into the shape of one person sitting very still.",
	"spindle": "Cylinder spindle, three seats. START is engraved at the left end with an arrow. Each band seats at one of three positions, I, II, III. The transcript card above it is headed 17 OCT.",
	"band_tray": "Four wax bands in a felt tray, laid out B, D, A, C. C has a START notch. So does D, and its rim is scratched 14 OCT. A's seam runs off both edges. B's seam stops at an END notch.",
	"printer": "A transcript printer. It types whatever is played, under the speaker's name.",
	"recording_tomorrow": "Venn's recording, 17 Oct. VENN: 'Greywake, seventeenth October. Calibration zero is four. Write it down, whoever you are.' VENN: 'The recorder is accurate. That is the difficulty.' [A chair creaks on the cylinder. Then, close to the horn, someone who is not Venn breathes in.] VENN: 'Eighteenth October. Mercer will be standing at the chart table.' The last line is dated tomorrow.",
	"calibration_zero": "Venn's recording gives the recorder's calibration zero: 4.",
	"board": "Channel board: a MOTOR switch, live channels A and B, dead channel C, and a key marked WITNESS.",
	"socket_cuts": "No words on the sockets. Strokes are cut into the brass above each: I over A, II over B, III over C.",
	"procedure": "Printed procedure: 'Address a witness on a quiet line.'",
	"line_occupied": "WITNESS with the motor running: channel C played Rook's 1927 dictation off the cylinder. The line was occupied.",
	"line_crowded": "WITNESS with channel A or B open: the session voices bled onto C. Two other voices on the line; his couldn't get through them.",
	"speaker": "A brass speaker funnel above the board, the only funnel that faces into the room.",
	"mixer": "A two-track mixer: VENN on track 1, NORA on track 2, an offset slider from -3 to +3 and a centre guide.",
	"session_spool": "A session spool is threaded on the mixer: SESSION, 18 OCT 1927. I didn't thread it.",
	"bell_peaks": "Neither trace marks the bell. Whatever syncs the two tracks has to be heard, one track at a time.",
	"bell_venn": "Track 1, VENN, played: the bell strikes on frame 2 of the film.",
	"bell_nora": "Track 2, NORA, played: with the slider at 0 the bell strikes on frame 4. Each step of the slider moves it one frame.",
	"margin_marks": MARGIN_MARKS_LINE,
	"witness_procedure": "Venn: 'Leave the witness line open.' Nora: 'Tell them I was here.' Margin of the session log: an automatic countersign closes a record; a human correction keeps it open. Under it, two pencil marks joined by a stroke: a solid triangle and a hollow circle. The dead channel is Venn's station now.",
	"c_presence": "Channel C carries room tone now, from a room that isn't this one. Once, it drew breath.",
	"venn_answers": "Where are they? VENN: 'Here. In the instruments. I kept them where they could still be reached. I never found how to let them out.' Are they still themselves? VENN: 'I don't know. I can't promise you they're whole. They answer. That's all I can tell you.' What do you need from me? VENN: 'If you break it, they end, every trace. If you don't, someone has to stay. Physically. Here. A witness, not a signature. Three days I have stood where you are standing. There is less of me each tide.' He kept them reachable. He can't promise they're whole. Breaking it ends them. Not breaking it needs someone to stay.",
	"funnel_voice": "After channel C went dark, with the motor off, his voice came through the speaker funnel: 'You'll want to be angry with me. Be angry in the office. The board is there.'",
	"funnel_voice_letter": "After channel C went dark, with the motor off, his voice came through the speaker funnel: 'You've read the letter. Good. Stay angry; it keeps the record open.'",
	"speaker_wet": "The speaker funnel's mouth was wet with seawater afterwards.",
	"printer_questions": "The transcript printer typed my three questions under his answers, labelled MERCER.",
	"leak_wind": "Wind blows out of funnel 5. When I came it faced the plaster; it has turned halfway toward the room.",
	"five_facing": "After Venn's answers, funnel 5 turned until its bell faced me. It stays that way.",
	"leak_rain": "Rain comes through funnel 2. It isn't raining on the roof. The funnel bells are fogged on the inside.",
	"leak_silence": "The weather leaks have stopped. Not one funnel makes a sound.",
	"stool_rings": "Wax dust lies on the seat in rings, like ripples round a dropped stone.",
	"funnels_turned": "All six funnels have turned a few degrees toward the seat. Nobody moved them.",
	"plaster_bulge": "The plaster bulges round every funnel pipe, as if the wall were breathing out.",
	"printer_mercer": "The printer has typed a new line: 'MERCER: (breathing)'. Nothing was playing.",
	"lens_pipes": "Under the lens the pipes meet the plaster with no join. They weren't fitted into the wall.",
}
const OBJECTIVES := {
	"p02": "Put Venn's recording back together and play it.",
	"p17": "Separate the two voices on the session recording.",
	"wait_p18": "Channel C is Venn's station. Something in the vault comes first.",
	"p19": "Address the dead channel.",
	"p19_ask": "Ask Venn all three questions.",
	"away": "Nothing here needs me yet. The horns are listening anyway.",
	"done": "The board is quiet.",
}
const HINTS := {
	"p02": [
		"The Listening Room. Something on the spindle needs putting back together.",
		"One band starts, one ends, and the seam has to run unbroken from the start end. The transcript card says which day.",
		"The notebook has it: the card says 17 OCT and D's rim says 14 OCT, so D is the wrong day. C has the START notch, B the END notch, and A's seam runs off both edges, so A goes between.",
		"Place C, then A, then B from the start end. Turn them to I, III, II so the seam is continuous. Then play.",
	],
	"p17": [
		"The listening room's mixer has two voices on top of each other.",
		"Both tracks have a bell in them. The contact sheet says the bell is the sync.",
		"The contact sheet's edge says where the bell falls against the film. Listen to each track alone.",
		"Track 2 offset to -2, then play VENN alone and NORA alone.",
	],
	"wait_p18": [
		"The records vault.",
		"Channel C needs Rook's own record put straight first.",
		"Finish the director's record in the vault, then come back to the channel board.",
	],
	"p19": [
		"The listening room's dead channel can be addressed.",
		"Venn's seal has three cuts. The procedure wants a quiet line.",
		"The seal rubbing in the notebook, from Venn's locker: three cuts. III is cut over socket C, Venn's station. A quiet line carries nothing else: no cylinder playing, no other channel open.",
		"Motor off, close A and B, open C, press WITNESS. Ask all three questions.",
	],
	"p19_ask": [
		"The question cards on the channel board.",
		"All three answers matter. Any order.",
		"Ask where they are, whether they're still themselves, and what he needs from me.",
	],
	"away": [
		"Nothing in the listening room is waiting on me.",
		"The board wakes when something elsewhere is finished.",
		"Come back when the mixer has a spool on it, or the vault is done.",
	],
	"done": [
		"The listening room has said what it had to say.",
		"Venn answered all three. The rest is elsewhere.",
		"Nothing more to do here.",
	],
}
const ITEMS := {}

const SAVED_BOOLS := ["p02_complete", "p17_complete", "venn_on", "nora_on", "heard_venn",
	"heard_nora", "heard_combined", "c_breath_heard", "motor_on", "witness_open", "p19_complete",
	"printer_q_seen"]

## Transient, never saved: what the view highlights after the last action.
var seam_break := ""   # "" | "start_end" | "start_arrow" | "join1" | "join2" | "wrong_day"
var mix_result := ""   # "" | "overlap" | "combined" | "venn" | "nora" | "silent"
var board_tape := ""   # "" | TAPE_MOTOR | TAPE_CROWDED
var _board_said := false

func initial_state() -> Dictionary:
	return {
		"p02_complete": false, "spindle": ["", "", ""], "band_rot": {"C": 1, "A": 0, "B": 2, "D": 0},
		"p17_complete": false, "offset": 0, "venn_on": true, "nora_on": true,
		"heard_venn": false, "heard_nora": false, "heard_combined": false, "c_breath_heard": false,
		"motor_on": true, "ch_open": {"A": true, "B": true, "C": false}, "witness_open": false,
		"asked": [], "p19_complete": false, "notices": [], "printer_q_seen": false,
	}

## P02, P17 and P19 carry a fourth tier (what the notebook already holds) before the solution; the
## core asks before giving the last. Same rule as RoomSim.hint_tiers(): four lines, four tiers.
func hint_tiers() -> int:
	return 4 if HINTS.get(objective(), []).size() >= 4 else 3

func is_closeup(v := local_view) -> bool:
	return v in CLOSEUPS

func objective() -> String:
	_sync()
	if not state.p02_complete:
		return "p02"
	if state.witness_open:
		return "p19_ask"
	if game.flag("P16") and not state.p17_complete:
		return "p17"
	if state.p17_complete and not game.flag("P18"):
		return "wait_p18"
	if state.p17_complete and game.flag("P18") and not state.p19_complete:
		return "p19"
	if state.p19_complete:
		return "done"
	return "away"

## Before the lamp the instrument doors are latched; after it, she's free to come.
func locked_line() -> String:
	if not game.flag("P01"):
		return LOCKED
	return "The latch has gone. The office isn't finished with me yet."

## After the sever ending the room is released: grey daylight, the bells hang as they were hung.
const SEVER_LINES := {
	"funnels": "They hang the way they were hung. The bells are dry.",
	"plaster": "Flat again. Old plaster, painted over many times.",
	"stool": "Just a seat, folded up against the wall.",
}

# ---------------------------------------------------------------------------------------------
# view helpers (read-only)
# ---------------------------------------------------------------------------------------------
func band() -> int:
	return game.weather_band()

func ending() -> String:
	return str(game.value("ending_choice"))

## The level-indicator lamp of channel "A", "B" or "C".
func indicator_lit(ch: String) -> bool:
	if ending() != "":
		return false
	if ch == "C":
		return state.witness_open
	return state.motor_on and bool(state.ch_open.get(ch, false))

## The level needle of a channel: "rest", "live" or "tremble" (channel C's presence).
func needle_mode(ch: String) -> String:
	if ending() != "":
		return "rest"
	if ch == "C":
		if state.witness_open:
			return "live"
		if state.p17_complete and not state.p19_complete:
			return "tremble"
		return "rest"
	return "live" if indicator_lit(ch) else "rest"

## Funnel 5's pose (the view draws it): "rest" (into the wall, at the stain), "half" (after P04
## it has turned partway toward the room), "turned" (band 4+, at the seat with the others) or
## "facing" (after P19, its bell full on the viewer for the rest of Tide VII).
func funnel5_pose() -> String:
	if ending() == "sever":
		return "rest"
	if ending() == "" and state.p19_complete and not game.flag("P21"):
		return "facing"
	if band() >= 4:
		return "turned"
	if game.flag("P04"):
		return "half"
	return "rest"

func funnels_turned_shown() -> bool:
	return band() >= 4 and ending() != "sever"

func stool_rings_shown() -> bool:
	return band() >= 3

func bulge_shown() -> bool:
	return band() == 7 and ending() != "sever"

## The escalation notice due now (a NOTICES id), or "".
func current_notice() -> String:
	if ending() != "":
		return ""
	var b := band()
	if b == 7:
		return "plaster_bulge"
	if state.p17_complete and not state.p19_complete:
		return "c_presence"
	if b >= 4:
		return "funnels_turned"
	if b == 3:
		return "leak_silence"
	if b >= 1:
		return "leak_wind"
	return ""

## The transcript card under the spindle: the broken line after a failed play, the full
## recording once it has played, else nothing.
func transcript_lines() -> Array:
	if seam_break == "join2" and state.spindle[0] == "D":
		return JOIN2_D.duplicate()
	if seam_break != "":
		return SEAM_TRANSCRIPT[seam_break].duplicate()
	if state.p02_complete:
		var out := []
		for r in RECORDING:
			out.append(r[0])
		return out
	return []

## The mixer's transcript for the last play (overlap is two columns, VENN | NORA).
func mix_transcript() -> Array:
	match mix_result:
		"overlap":
			return MIX_OVERLAP.duplicate()
		"combined":
			return [MIX_COMBINED]
		"venn", "nora":
			return [MIX_LINES[mix_result]]
	return []

## The first break in the seam for an arrangement, "wrong_day" when it runs START to END from
## the decoy band D, or "" when it runs START to END from C.
static func seam_failure(spindle: Array, rot: Dictionary) -> String:
	var first: String = spindle[0]
	if first == "" or not SEAM[first].has("start"):
		return "start_end"
	if (int(rot[first]) + int(SEAM[first]["in"])) % 3 != START_PHASE:
		return "start_arrow"
	for j in 2:
		var a: String = spindle[j]
		var b: String = spindle[j + 1]
		var broken: bool = SEAM[a].has("end") or SEAM[b].has("start")
		if not broken:
			broken = (int(rot[a]) + int(SEAM[a]["out"])) % 3 != (int(rot[b]) + int(SEAM[b]["in"])) % 3
		if broken:
			return "join%d" % (j + 1)
	if SEAM[first].has("wrong_day"):
		return "wrong_day"
	return ""

func evaluate() -> String:
	return seam_failure(state.spindle, state.band_rot)

# ---------------------------------------------------------------------------------------------
# entry points
# ---------------------------------------------------------------------------------------------
func arrive(ev: Array, first: bool) -> void:
	_sync()
	if first:
		_say(ev, ARRIVAL)
		_sfx(ev, "throat_clear", 2.4)
		_fx(ev, "notice_throat")
		_observe("throat")
		_observe("stain_seated")
		_mark_notice("throat")
	else:
		var n := current_notice()
		if n != "" and not n in state.notices:
			_fx(ev, "notice_" + n)
			_mark_notice(n)
			_say(ev, NOTICE_LINES.get(n, ""), 1.6)
	if state.motor_on and band() <= 2:
		_sfx(ev, "motor_click", 0.3)

func back(ev: Array) -> void:
	_sync()
	match local_view:
		"c_mixer":
			local_view = "board"
			if state.p17_complete and not state.c_breath_heard:
				state.c_breath_heard = true
				_sfx(ev, "breath_c", 0.6)
				_say(ev, "...Channel C just drew breath.", 1.4, true)
				_observe("c_presence")
		"c_channels":
			local_view = "board"
		_:
			local_view = "room"

func act(action: String, ev: Array) -> void:
	_sync()
	match local_view:
		"c_spindle":
			if _spindle(action, ev):
				return
		"c_mixer":
			if _mixer(action, ev):
				return
		"c_channels":
			if _channels(action, ev):
				return
	if action in HOTSPOTS:
		local_view = "room"
		_room(action, ev)
	elif action in BOARD_HOTSPOTS:
		local_view = "board"
		_board(action, ev)

func use_item(item: String, target: String, ev: Array) -> bool:
	_sync()
	var at_spindle: bool = target in ["spindle", "band_tray"] or local_view == "c_spindle"
	var at_mixer: bool = target == "mixer" or local_view == "c_mixer"
	match item:
		"contact_sheet":
			if at_mixer:
				if game.flag("P16"):
					local_view = "c_mixer"
					_say(ev, "Sync: bell. There's a bell on both tracks.")
				else:
					_say(ev, "Both spools are empty. Nothing to sync.")
				return true
			_say(ev, "Nothing to sync here. The mixer, maybe.")
			return true
		"inspection_lens":
			if target in ["funnels", "plaster"]:
				_say(ev, "Through the lens the pipes meet the plaster with no join at all. Nobody fitted them.")
				_observe("lens_pipes")
				return true
			if at_spindle:
				_say(ev, "Under the lens the seam is one cut, made in one pass, across all three bands.")
				return true
			if target == "stool" and band() >= 3:
				_say(ev, "The rings are wax dust, settled the way water settles.")
				return true
		"chart_clips":
			if at_spindle:
				_say(ev, "Clips are for paper. These are wax.")
				return true
	return false

# ---------------------------------------------------------------------------------------------
# view A: the funnel wall
# ---------------------------------------------------------------------------------------------
func _room(action: String, ev: Array) -> void:
	var b := band()
	match action:
		"funnels":
			_observe("funnels")
			if ending() == "sever":
				_say(ev, SEVER_LINES.funnels)
			elif funnel5_pose() == "facing":
				_say(ev, "Number five is looking straight at me.", 0.0, true)
				_say(ev, "It's dark all the way down.", HOLE_DELAY, true)
				_fx(ev, "hold_breath", {"seconds": HOLE_HOLD, "delay": HOLE_DELAY})
				_observe("five_facing")
			elif b == 0:
				_say(ev, "Six brass ear trumpets, numbered. Their pipes go into the plaster and don't come out the other side.")
			elif b == 1:
				_say(ev, "Wind is coming out of number five. It used to face the wall. It's turned halfway round.")
				_observe("leak_wind")
			elif b == 2:
				_say(ev, "Rain in number two. It isn't raining on the roof. The bells have fogged on the inside.")
				_observe("leak_rain")
			elif b == 3:
				_say(ev, "Nothing from any of them now. Not wind, not rain.")
				_observe("leak_silence")
			elif b <= 6:
				_say(ev, "They've turned. All six point at the stool.")
				_observe("funnels_turned")
			else:
				_say(ev, "Every pipe has the plaster swelling round it.")
				_observe("plaster_bulge")
		"plaster":
			_observe("plaster")
			if ending() == "sever":
				_say(ev, SEVER_LINES.plaster)
			elif b < 7:
				_say(ev, "Sealed plaster, painted over many times. The damp patch in it sits like a person waiting. Behind it, the outer wall, then the sea.")
				_observe("stain_seated")
			else:
				_say(ev, "It bulges round the pipes, as if the wall had taken a breath and was letting it out.")
				_observe("plaster_bulge")
		"stool":
			_observe("stool")
			if ending() == "sever":
				_say(ev, SEVER_LINES.stool)
			elif b <= 2:
				_say(ev, "A tip-up seat, polished by use. The polish is the shape of one person sitting very still.")
			elif b == 3:
				_say(ev, "Wax dust on the seat, in rings. Like ripples round something dropped into still water.")
				_observe("stool_rings")
			elif b <= 6:
				_say(ev, "Every funnel in the room points at this seat.")
			else:
				_say(ev, "Every funnel points at the seat. I don't sit down.")
		"spindle", "band_tray":
			local_view = "c_spindle"
			if not has_seen("spindle"):
				_say(ev, "Four wax bands, three seats on a spindle marked START.")
				_observe("spindle")
				_observe("band_tray")
			elif state.p02_complete:
				_say(ev, "The recording's still on the spindle.")
			else:
				_say(ev, "The spindle, and the bands.")
		"printer":
			_printer(ev)
		"to_board":
			local_view = "board"
			if not _board_said and not has_seen("board"):
				_say(ev, "The channel board.")
			else:
				_say(ev, "The board.")
			_board_said = true

func _printer(ev: Array) -> void:
	_observe("printer")
	if not state.p02_complete:
		_say(ev, "A transcript printer. The roll is blank to the end.")
		return
	_sfx(ev, "printer_chatter")
	for i in RECORDING.size():
		_say(ev, RECORDING[i][0], PRINTER_DELAYS[i], true)
	var t := 7.6
	if state.p19_complete:
		_say(ev, "Under his answers it has typed my three questions. MERCER, it says.", t, true)
		_observe("printer_questions")
		state.printer_q_seen = true
		t += 2.0
	if band() == 7:
		_say(ev, "And a new line: 'MERCER: (breathing).' Nothing is playing.", t, true)
		_observe("printer_mercer")

# ---------------------------------------------------------------------------------------------
# view B: the channel board
# ---------------------------------------------------------------------------------------------
func _board(action: String, ev: Array) -> void:
	match action:
		"motor", "channel_a", "channel_b", "channel_c", "witness_key":
			local_view = "c_channels"
			if not has_seen("board"):
				_say(ev, "Motor, three channels, and a key marked WITNESS.")
				_observe("board")
				_observe("socket_cuts")
				_observe("procedure")
			else:
				_say(ev, "Motor, channels, WITNESS.")
		"mixer":
			if not game.flag("P16"):
				_say(ev, "A two-track mixer. Both spools are empty.")
				_observe("mixer")
				return
			local_view = "c_mixer"
			if not has_seen("session_spool"):
				_say(ev, "There's a spool threaded now. SESSION, 18 OCT 1927. I didn't thread it.", 0.0, true)
				_say(ev, "Nothing on either trace marks a bell. I'd have to listen for it.", 2.2, true)
				_observe("mixer")
				_observe("session_spool")
				_observe("bell_peaks")
			elif state.p17_complete:
				_say(ev, "The session spool. The bells line up now.")
			else:
				_say(ev, "The session spool. Two voices on one track.")
		"speaker":
			if not state.p19_complete:
				_say(ev, "The speaker funnel. The only one that faces into the room.")
				_observe("speaker")
			else:
				_say(ev, "The mouth of it is wet. It smells of the sea.")
				_observe("speaker_wet")
		"to_funnels":
			local_view = "room"
			_say(ev, "The funnels.")

# ---------------------------------------------------------------------------------------------
# P02: c_spindle
# ---------------------------------------------------------------------------------------------
## Handles a c_spindle control; false if `action` isn't one.
func _spindle(action: String, ev: Array) -> bool:
	if action == "play":
		_play_recording(ev)
		return true
	if action == "look_arrow":
		_say(ev, "START, and an arrow. The left end.")
		return true
	var band_id := ""
	var slot := -1
	var dir := 0
	if action.begins_with("tray_") and action.substr(5) in BANDS:
		band_id = action.substr(5)
	elif action.begins_with("slot_"):
		slot = _slot_index(action.substr(5))
	elif action.begins_with("rot_up_"):
		slot = _slot_index(action.substr(7))
		dir = 1
	elif action.begins_with("rot_down_"):
		slot = _slot_index(action.substr(9))
		dir = -1
	if band_id == "" and slot < 0:
		return false
	if state.p02_complete:
		_say(ev, PRESERVE_LINE)
		return true
	seam_break = ""
	if band_id != "":
		if not "" in state.spindle:
			_say(ev, "The spindle's full.")
		elif band_id in state.spindle:
			_say(ev, "That one's already on the spindle.")
		else:
			state.spindle[state.spindle.find("")] = band_id
			_sfx(ev, "band_seat")
	elif state.spindle[slot] == "":
		pass
	elif dir == 0:
		var lifted: String = state.spindle[slot]
		state.spindle[slot] = ""
		_sfx(ev, "band_lift")
		_say(ev, "I take band %s back off." % lifted)
	else:
		var b: String = state.spindle[slot]
		state.band_rot[b] = posmod(int(state.band_rot[b]) + dir, 3)
		_sfx(ev, "band_click")
	return true

static func _slot_index(s: String) -> int:
	return int(s) if s in ["0", "1", "2"] else -1

func _play_recording(ev: Array) -> void:
	seam_break = ""
	if not state.motor_on:
		_say(ev, "The motor's off. The board's through there.")
		return
	if "" in state.spindle:
		_say(ev, "The spindle takes three bands.")
		return
	var fail := evaluate()
	if fail != "":
		seam_break = fail
		_sfx(ev, "needle_down", 0.0)
		match fail:
			"wrong_day":
				_sfx(ev, "wax_fragment_2", 0.2)
				_sfx(ev, "needle_skip", 2.4)
			"join1":
				_sfx(ev, "wax_fragment_1", 0.2)
				_sfx(ev, "needle_skip", 1.2)
			"join2":
				_sfx(ev, "wax_fragment_2", 0.2)
				_sfx(ev, "needle_skip", 2.6)
			_:
				_sfx(ev, "needle_skip", 0.3)
		_fx(ev, "seam_break")
		if fail == "wrong_day":
			_say(ev, SEAM_TRANSCRIPT.wrong_day[0], 0.4, true)
			_say(ev, SEAM_LINES.wrong_day, 2.6, true)
		else:
			_say(ev, SEAM_LINES[fail])
		return
	var first: bool = not state.p02_complete
	if first:
		state.p02_complete = true
		game.record_move("recording_played")
		game.solve("P02", ev)
		_observe("recording_tomorrow")
		_observe("calibration_zero")
	_sfx(ev, "needle_down", 0.0)
	_sfx(ev, "recording_p02", 0.4)
	_fx(ev, "needle_down")
	for r in RECORDING:
		_say(ev, r[0], r[1], true)
	_sfx(ev, "cylinder_coast", 16.0)
	_fx(ev, "cylinder_coast")
	if not first:
		return
	_sfx(ev, "printer_chatter", 17.0)
	for r in RECORDING_AFTER:
		_say(ev, r[0], r[1], true)
	if game.flag("P03"):
		_say(ev, "I've already stood at the chart table.", 25.6, true)
	elif not ("R03" in game.state.visited and game.has_seen("R03", "sheets")):
		# Only true if she really hasn't looked at R03's table ("sheets" is its first-look
		# observation); otherwise the chain simply ends on the last RECORDING_AFTER line.
		_say(ev, "I haven't been near the chart table yet.", 25.6, true)

# ---------------------------------------------------------------------------------------------
# P17: c_mixer
# ---------------------------------------------------------------------------------------------
## The frame track `who` ("venn" or "nora") strikes its bell on at the current offset.
func bell_frame(who: String) -> int:
	return int(BELL_FRAME[who]) + (int(state.offset) if who == "nora" else 0)

## One heard strike per enabled track, on its frame, captioned for anyone who can't hear it.
func _bells(ev: Array) -> void:
	for t in [["venn", "1, VENN"], ["nora", "2, NORA"]]:
		if not state[t[0] + "_on"]:
			continue
		var f := bell_frame(t[0])
		_sfx(ev, "mix_bell", f * FRAME_S)
		_say(ev, "[TRK %s: a bell, on frame %d]" % [t[1], f], f * FRAME_S, true)
		_observe("bell_" + t[0])

func _mixer(action: String, ev: Array) -> bool:
	match action:
		"off_left", "off_right":
			var to := clampi(int(state.offset) + (-1 if action == "off_left" else 1), OFFSET_MIN, OFFSET_MAX)
			if state.p17_complete:
				_say(ev, "The bells are lined up. I'll leave it there.")
			elif to != int(state.offset):
				state.offset = to
				mix_result = ""
				_sfx(ev, "slider_step")
		"toggle_venn", "toggle_nora":
			var key := "venn_on" if action == "toggle_venn" else "nora_on"
			state[key] = not state[key]
			mix_result = ""
			_sfx(ev, "toggle_channel")
		"look_sheet":
			_say(ev, "Sync: bell." if game.has_item("contact_sheet") else "Nothing pinned here.")
		"play":
			_play_mix(ev)
		_:
			return false
	return true

func _play_mix(ev: Array) -> void:
	mix_result = ""
	if not state.motor_on:
		_say(ev, MIX_MOTOR_OFF)
		return
	if not game.has_item("contact_sheet"):
		_say(ev, "I'd want the contact sheet in front of me for this.")
		return
	if not state.venn_on and not state.nora_on:
		mix_result = "silent"
		_say(ev, "Both channels are off.")
		return
	if int(state.offset) != OFFSET_SOLUTION:
		mix_result = "overlap"
		_sfx(ev, "mix_overlap")
		_say(ev, "The bells don't land together.")
		_bells(ev)
		return
	if state.venn_on and state.nora_on:
		mix_result = "combined"
		_sfx(ev, "mix_combined")
		_say(ev, MIX_COMBINED, 0.0, true)
		_bells(ev)
		_say(ev, "His voice starts it. Hers finishes it.", 2.4, true)
		state.heard_combined = true
		return
	mix_result = "venn" if state.venn_on else "nora"
	_sfx(ev, "mix_" + mix_result)
	_say(ev, MIX_LINES[mix_result], 0.0, true)
	_bells(ev)
	state["heard_" + mix_result] = true
	if state.heard_venn and state.heard_nora and not state.p17_complete:
		state.p17_complete = true
		game.solve("P17", ev)
		_observe("witness_procedure")
		_observe("margin_marks")
		_mark_notice("c_presence")
		_fx(ev, "c_presence")
		_say(ev, "Two people. One sentence between them.", 2.4, true)
		_say(ev, "Pencil in the margin of the session log.", 4.6, true)
		_say(ev, "'%s'" % MARGIN_NOTE[0], 6.8, true)
		_say(ev, "And under it, in his hand: '%s'" % MARGIN_NOTE[1], 9.6, true)
		_say(ev, MARGIN_MARKS_LINE, 12.4, true)

# ---------------------------------------------------------------------------------------------
# P19: c_channels
# ---------------------------------------------------------------------------------------------
func _channels(action: String, ev: Array) -> bool:
	match action:
		"motor", "key_a", "key_b", "key_c":
			if state.witness_open and not state.p19_complete:
				_say(ev, ON_THE_LINE)
				return true
			board_tape = ""
			if action == "motor":
				state.motor_on = not state.motor_on
				_sfx(ev, "switch_motor")
			else:
				var ch := action.substr(4).to_upper()
				state.ch_open[ch] = not state.ch_open[ch]
				_sfx(ev, "key_channel")
		"procedure":
			_say(ev, "'%s'" % PROCEDURE)
			_observe("procedure")
		"witness":
			_witness(ev)
		_:
			if action in QUESTIONS:
				_ask(action, ev)
			else:
				return false
	return true

func _witness(ev: Array) -> void:
	board_tape = ""
	if state.p19_complete:
		_say(ev, "The key clicks. Channel C is dark.")
		return
	if state.witness_open:
		_say(ev, "He's listening.")
		return
	var ready: bool = game.flag("P17") and game.flag("P18")
	if ready and state.motor_on:
		# the cylinder is still turning: C carries the director, not Venn
		board_tape = TAPE_MOTOR
		_sfx(ev, "witness_key")
		_sfx(ev, "rook_dictation", 0.3)
		_say(ev, ROOK_DICTATION[0], 0.4, true)
		_say(ev, ROOK_DICTATION[1], 3.4, true)
		_say(ev, LINE_OCCUPIED, 6.6, true)
		_observe("line_occupied")
		return
	if ready and (state.ch_open.A or state.ch_open.B):
		# the live channels bleed the 1927 session onto C
		board_tape = TAPE_CROWDED
		_sfx(ev, "witness_key")
		_sfx(ev, "mix_overlap", 0.3)
		_say(ev, MIX_OVERLAP[0], 0.4, true)
		_say(ev, MIX_OVERLAP[1], 1.6, true)
		_say(ev, LINE_CROWDED, 4.4, true)
		_observe("line_crowded")
		return
	if not ready and state.ch_open.C and not state.motor_on and not state.ch_open.A \
			and not state.ch_open.B:
		# the right procedure, too early: the line is quiet because nobody is on it yet
		_sfx(ev, "witness_key")
		_say(ev, LINE_QUIET)
		return
	if not state.ch_open.C or not ready:
		_sfx(ev, "witness_key")
		_say(ev, "The key clicks. Nothing answers.")
		return
	state.witness_open = true
	_sfx(ev, "witness_key", 0.0)
	_sfx(ev, "relay_on", 0.5)
	_fx(ev, "c_open")
	_say(ev, "Channel C is open.", 0.8, true)
	_say(ev, "VENN (channel C): Ask, then. I'll answer what I can.", 2.6, true)

func _ask(q: String, ev: Array) -> void:
	if not state.witness_open and not state.p19_complete:
		_say(ev, "Nobody's on the line.")
		return
	var a: Array = ANSWERS[q]
	_sfx(ev, "venn_answer_" + a[0], 0.4)
	for i in 3:
		_say(ev, a[i + 1], ANSWER_DELAYS[i], true)
	if state.p19_complete or q in state.asked:
		return
	state.asked.append(q)
	if state.asked.size() < QUESTIONS.size():
		return
	state.p19_complete = true
	state.witness_open = false
	game.solve("P19", ev)
	_observe("venn_answers")
	_sfx(ev, "relay_off", 9.0)
	_fx(ev, "c_dark")
	_say(ev, "[channel C indicator: dark]", 9.2, true)
	_sfx(ev, "venn_funnel", 11.0)
	_fx(ev, "funnel_voice")
	if game.flag("P20"):
		_say(ev, "VENN (speaker funnel): You've read the letter. Good. Stay angry; it keeps the record open.", 11.2, true)
		_observe("funnel_voice_letter")
	else:
		_say(ev, "VENN (speaker funnel): You'll want to be angry with me. Be angry in the office. The board is there.", 11.2, true)
		_observe("funnel_voice")
	_say(ev, "The motor's off. Channel C is dark. Nothing in this room is connected to that funnel.", 16.0, true)
	_observe("speaker_wet")

# ---------------------------------------------------------------------------------------------
# state
# ---------------------------------------------------------------------------------------------
## Marks `n` and every older notice as seen, so an obsolete one never plays later.
func _mark_notice(n: String) -> void:
	var k := NOTICES.find(n)
	for i in k + 1:
		if not NOTICES[i] in state.notices:
			state.notices.append(NOTICES[i])

func _set_p02_done() -> void:
	state.p02_complete = true
	state.spindle = SOLUTION_ORDER.duplicate()
	for b in SOLUTION_ROT:
		state.band_rot[b] = SOLUTION_ROT[b]

func _set_p17_done() -> void:
	state.p17_complete = true
	state.offset = OFFSET_SOLUTION
	state.heard_venn = true
	state.heard_nora = true

func _set_p19_done() -> void:
	state.p19_complete = true
	state.asked = QUESTIONS.duplicate()
	state.witness_open = false

## Flags set elsewhere (tests, debug) pull the local arrangement along. Never clears anything.
func _sync() -> void:
	if game.flag("P02") and not state.p02_complete:
		_set_p02_done()
	if game.flag("P17") and not state.p17_complete:
		_set_p17_done()
	if game.flag("P19") and not state.p19_complete:
		_set_p19_done()

func load_state(d: Variant) -> void:
	state = initial_state()
	seam_break = ""
	mix_result = ""
	board_tape = ""
	_board_said = false
	if not d is Dictionary:
		return
	for key in SAVED_BOOLS:
		if d.get(key) is bool:
			state[key] = d[key]
	var sp = d.get("spindle")
	if sp is Array and sp.size() == 3:
		var ok := true
		var letters := []
		for s in sp:
			if not (s is String and (s == "" or s in BANDS)):
				ok = false
			elif s != "":
				ok = ok and not s in letters
				letters.append(s)
		if ok:
			state.spindle = sp.duplicate()
	var rot = d.get("band_rot")
	if rot is Dictionary:
		for b in BANDS:
			if rot.has(b) and _all_whole([rot[b]]):
				state.band_rot[b] = clampi(int(rot[b]), 0, 2)
	var off = d.get("offset")
	if _all_whole([off]):
		state.offset = clampi(int(off), OFFSET_MIN, OFFSET_MAX)
	var ch = d.get("ch_open")
	if ch is Dictionary:
		for k in ["A", "B", "C"]:
			if ch.get(k) is bool:
				state.ch_open[k] = ch[k]
	if d.get("asked") is Array:
		for q in d.asked:
			if q is String and q in QUESTIONS and not q in state.asked:
				state.asked.append(q)
	if d.get("notices") is Array:
		for n in d.notices:
			if n is String and n in NOTICES and not n in state.notices:
				state.notices.append(n)
	# Derived: later progress implies earlier progress and its arrangement.
	if state.p19_complete:
		state.p17_complete = true
	if state.p17_complete:
		state.p02_complete = true
	if state.p02_complete:
		_set_p02_done()
	if state.p17_complete:
		_set_p17_done()
	else:
		state.c_breath_heard = false
	if state.p19_complete:
		_set_p19_done()
	if state.witness_open and not (not state.motor_on and not state.ch_open.A
			and not state.ch_open.B and state.ch_open.C and state.p17_complete):
		state.witness_open = false
	if not state.p19_complete:
		if not state.witness_open:
			state.asked = []
		elif state.asked.size() >= QUESTIONS.size():
			state.asked.resize(QUESTIONS.size() - 1)
	state.printer_q_seen = state.printer_q_seen and state.p19_complete

## P02, P17 and P19 are R04's: a flag set elsewhere (tests, debug) is honoured, then the flags
## follow the state.
func reconcile() -> void:
	_sync()
	game.set_flag("P02", state.p02_complete)
	game.set_flag("P17", state.p17_complete)
	game.set_flag("P19", state.p19_complete)
	if not (game.flag("P17") and game.flag("P18")):
		state.witness_open = false

# ---------------------------------------------------------------------------------------------
# debug
# ---------------------------------------------------------------------------------------------
## The local state real play leaves at the start of tide `t`.
func debug_prepare(t: int) -> void:
	if t >= 2:
		_set_p02_done()
		for o in ["throat", "spindle", "band_tray", "recording_tomorrow", "calibration_zero"]:
			_observe(o)
	if t >= 7:
		_set_p17_done()
		state.c_breath_heard = true
		for o in ["mixer", "session_spool", "bell_peaks", "bell_venn", "bell_nora", "witness_procedure",
				"margin_marks", "c_presence"]:
			_observe(o)
	if t >= 8:
		state.motor_on = false
		state.ch_open = {"A": false, "B": false, "C": true}
		_set_p19_done()
		for o in ["board", "socket_cuts", "procedure", "venn_answers", "funnel_voice", "speaker_wet",
				"printer_questions"]:
			_observe(o)
		state.printer_q_seen = true
	if t >= 2:
		_prepare_notices()

## Every notice older than the current one is behind her; the current one still plays.
func _prepare_notices() -> void:
	var n := current_notice()
	var k := NOTICES.find(n) if n != "" else 1
	for i in k:
		if not NOTICES[i] in state.notices:
			state.notices.append(NOTICES[i])

## Dev stages: 0 Tide I fresh, 1 P02 solved, 2 Tide VI (P16, mixer live), 3 P17 solved
## (waiting for P18), 4 P19 ready, 5 witness open, 6 P19 solved, 7 Tide IX.
func debug_jump(n: int) -> void:
	if n <= 1:
		var office: RoomSim = game.room("R02")
		if office and office.has_method("debug_jump"):
			office.debug_jump(1)
		else:
			game.reset()
		game.set_flag("P01")
		game.debug_enter(ID)
		if n == 1:
			_set_p02_done()
			for o in ["throat", "spindle", "band_tray", "recording_tomorrow", "calibration_zero"]:
				_observe(o)
			_mark_notice("throat")
	elif n <= 6:
		game.debug_tide(6, ID)
		game.set_flag("P16")
		if not game.has_item("contact_sheet"):
			game.give("contact_sheet", [])
		if n >= 3:
			_set_p17_done()
			for o in ["mixer", "session_spool", "bell_peaks", "bell_venn", "bell_nora", "witness_procedure",
				"margin_marks", "c_presence"]:
				_observe(o)
			_mark_notice("c_presence")
		if n >= 4:
			game.set_flag("P18")
		if n >= 5:
			state.motor_on = false
			state.ch_open = {"A": false, "B": false, "C": true}
			for o in ["board", "socket_cuts", "procedure"]:
				_observe(o)
			state.witness_open = true
		if n >= 6:
			_set_p19_done()
			for o in ["venn_answers", "funnel_voice", "speaker_wet"]:
				_observe(o)
	else:
		game.debug_tide(9, ID)
	seam_break = ""
	mix_result = ""
	board_tape = ""
	reconcile()
