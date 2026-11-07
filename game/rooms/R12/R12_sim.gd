class_name R12Sim
extends RoomSim
## R12, the Observation Chamber. Owns P25 (the record of the observer), P26 (understand each
## route) and P27 (the choice), the P26 checkpoint and both endings (docs/design/game-design.md
## sections 8-9, docs/design/puzzle-cards/). Node-free and deterministic: every change is
## caused by an action; presentation timing lives in the event delays and the view.
##
## Views: "room" (A, the chair wall), "frames" (B, the record wall), "routing" (C, the routing
## wall), the close-ups "c_frames" (P25), "c_routing" (P26), "c_final" (P27) and "ending" (the
## ending tableaux, stepped by "ending_next"). Every view but "room" is a close-up for the core.

const ID := "R12"
const TITLE := "Observation Chamber"
const REQUIRES := ["P24"]
const LOCKED := "The lower door has three empty frames and a socket, and no handle."
const RESUME := "Back in the observation chamber."
const WAY_IN_HINT := "The lower door on the stair landing has opened. Below it, the chamber."
const ARRIVAL := "The chamber. A chair faces an instrument. Nothing in here is dusty."
## [to, label, extra flags]: the ways out. The target's REQUIRES also apply.
const EXITS := [
	["R11", "Stair", []],
]
## witness_bridge is declared by R10, where it is found.
const ITEMS := {}

## View A (the room), in hit order.
const HOTSPOTS := ["pressure", "window", "chair", "armatures", "to_frames", "to_routing"]
## View B, the record wall.
const FRAMES_HOTSPOTS := ["nameplate", "indicators", "frame_body", "frame_place", "frame_name",
	"terminal", "card_rack", "copy_port"]
## View C, the routing wall.
const ROUTING_HOTSPOTS := ["plate_sever", "plate_continue", "cards", "handle", "yoke_tray",
	"contacts", "bridge_seat"]
## The rack controls are rack_<card id> in RACK_ORDER (seven fixed slots, left to right).
const FRAMES_CONTROLS := ["f_body", "f_place", "f_name", "look_body", "look_place", "look_name",
	"rack_position_b", "rack_trace_a", "rack_identity", "rack_trace", "rack_identity_b", "rack_trace_b",
	"rack_position", "look_strip", "switch", "route"]
const ROUTING_CONTROLS := ["look_sever", "look_continue", "preview_sever", "preview_continue",
	"slot_sever", "slot_continue", "confirm", "cc_restored", "cc_remains", "cc_returns", "cc_ends"]
const FINAL_CONTROLS := ["contacts", "look_lamps", "bridge_seat", "tray", "preview", "look_handle",
	"btn_sever", "btn_continue"]
const ENDING_CONTROLS := ["ending_next"]

const V_ROOM := "room"
const V_FRAMES := "frames"
const V_ROUTING := "routing"
const C_FRAMES := "c_frames"
const C_ROUTING := "c_routing"
const C_FINAL := "c_final"
const V_ENDING := "ending"
const OPENED_IDS := [C_FRAMES, C_ROUTING, C_FINAL]
const NOTICED_IDS := ["arrival"]

const STAFF := ["ROOK", "BELL", "IVES", "LUSK", "PRYCE", "DOANE", "HART", "TULL"]
const BRIDGE := "witness_bridge"

# ---------------------------------------------------------------------------------------------
# P25: seven cards in her name (room-local; never in the inventory). Three are true: the
# MOVEMENT card is her stored P05 trace, the POSITION and CONTRACT cards are the evidence's
# words. The others are near misses she must tell apart by what she saw and read.
# ---------------------------------------------------------------------------------------------
const CARD_IDS := ["trace", "trace_a", "trace_b", "position", "position_b", "identity", "identity_b"]
## The rack, left to right: fixed slots, deliberately not grouped and not true-first.
const RACK_ORDER := ["position_b", "trace_a", "identity", "trace", "identity_b", "trace_b", "position"]
## The frame each card's category belongs to.
const CARD_FRAME := {
	"trace": "body", "trace_a": "body", "trace_b": "body",
	"position": "place", "position_b": "place",
	"identity": "name", "identity_b": "name",
}
const CARD_HEADER := {
	"trace": "MOVEMENT · A. MERCER", "trace_a": "MOVEMENT · A. MERCER", "trace_b": "MOVEMENT · A. MERCER",
	"position": "POSITION · A. MERCER", "position_b": "POSITION · A. MERCER",
	"identity": "CONTRACT · A. MERCER", "identity_b": "CONTRACT · A. MERCER",
}
## The fixed card faces; the MOVEMENT cards are body_card_lines() / decoy_card_lines().
const CARD_TEXT := {
	"position": "Ninth position. Centre of the station outline.",
	"position_b": "Eighth position. Seat beside the window.",
	"identity": "Miss Ada Mercer, cataloguer. Requested by E. Venn.",
	"identity_b": "Miss Ada Mercer, cataloguer. Requested by S. Rook.",
}
## What she says lifting a card the first time. Neutral: the card is in her name, not hers yet.
const CARD_LIFT := {
	"position": "A POSITION card: 'Ninth position. Centre of the station outline.'",
	"position_b": "A POSITION card: 'Eighth position. Seat beside the window.'",
	"identity": "A CONTRACT card: 'Miss Ada Mercer, cataloguer. Requested by E. Venn.'",
	"identity_b": "A CONTRACT card: 'Miss Ada Mercer, cataloguer. Requested by S. Rook.'",
}
## Decoy MOVEMENT runs when swapping the real trace can't make two that differ from it (a trace
## under three events, or one whose swaps repeat it): fixed whitelist runs, taken in order.
const DECOY_FALLBACK := [["held_still", "turned_round", "log_read"],
	["interval_set", "charts_aligned", "lamp_mended"], ["report_signed", "recording_played", "drawer_opened"]]
## The plate of a frame holding a card of its own category that is not hers.
const NOT_OBSERVER := "DOES NOT CORRESPOND TO OBSERVER"
const FRAME_IDS := ["body", "place", "name"]
const FRAME_LABEL := {"body": "BODY", "place": "PLACE", "name": "NAME"}
const CATEGORY := {
	"body": "What the subject did, in the order it was done.",
	"place": "Where the subject stands in the survey.",
	"name": "Who the subject is, and who asked for them.",
}
const SOLUTION_FRAMES := {"body": "trace", "place": "position", "name": "identity"}
## Identical to R03Sim's (P05's printed fourth line); the tests assert it.
const LINE4_TURNED := "Observer has looked behind her once."
const LINE4_STILL := "Observer has not yet looked behind her."
const STRIP_COPY := ["WOULD FINALIZE OBSERVER"]
const STRIP_DONE := ["NINTH OBSERVER LOCATED.", "AUTOMATIC COUNTERSIGN AVAILABLE."]
const FRAMES_READ_ONLY := "It has its record of me. The frames won't open again."

# ---------------------------------------------------------------------------------------------
# P26: the consequence cards
# ---------------------------------------------------------------------------------------------
const ROUTES := ["sever", "continue"]
## The tray, left to right.
const CC_IDS := ["cc_restored", "cc_remains", "cc_returns", "cc_ends"]
const CC_TEXT := {
	"cc_ends": "Connection ends. Retained traces become inaccessible. Ada can leave.",
	"cc_remains": "Ada remains as witness. Traces stay accessible. Venn's duty ends.",
	"cc_restored": "Traces are restored to life.",
	"cc_returns": "Venn returns.",
}
const SOLUTION_ROUTES := {"sever": "cc_ends", "continue": "cc_remains"}
## The refusal for a wrong card in a plate: [line, lamp row].
const MISMATCH := {
	"sever": {
		"cc_restored": ["Nothing in the preview comes back to life.", 0],
		"cc_returns": ["The preview doesn't bring him back. His line goes out with the other eight.", 1],
		"cc_remains": ["The preview doesn't keep anything. All eight lines go out, and the door opens.", 0],
	},
	"continue": {
		"cc_restored": ["Nothing in the preview comes back to life.", 0],
		"cc_returns": ["The preview doesn't bring him back. It moves his line to me.", 1],
		"cc_ends": ["The preview doesn't end anything but his line. The eight stay lit, and the line comes to me.", 0],
	},
}
const ROUTING_SEALED := "Both cards are sealed in. I know what each one does."
const ROUTING_LATER := "Not until I know exactly what each one does."

# ---------------------------------------------------------------------------------------------
# Endings: steps of {tableau, lines [[delay, text]], sfx [[id, delay]], change}. `change` is
# the sfx whose play switches the tableau from its before to its after state ("" = none).
# ---------------------------------------------------------------------------------------------
const ENDING_SEVER := [
	{"tableau": "c_sever", "lines": [
		[0.0, "I pull the handle. It is heavier than it looks, and then it isn't."],
		[2.6, "Above the frames the eight indicators go out. Not together. One, and a wait, and the next."]],
	# each wait a little longer than the last; the view spaces the lamps from this table
	"sfx": [["handle_pull", 0.0], ["line_out_1", 3.0], ["line_out_2", 3.8], ["line_out_3", 4.9],
		["line_out_4", 6.3], ["line_out_5", 8.0], ["line_out_6", 10.1], ["line_out_7", 12.6],
		["line_out_8", 16.2]],
	"change": ""},
	{"tableau": "m_funnels", "lines": [
		[0.0, "In the listening room the funnels stop hissing."],
		[2.6, "In the quiet, for a moment, someone clears their throat."]],
	"sfx": [["funnel_stop", 0.4], ["throat", 3.6]], "change": "funnel_stop"},
	{"tableau": "m_diaphragm", "lines": [
		[0.0, "In the machine room the diaphragm lets out its last breath against the bolts."],
		[2.8, "It doesn't take another."]],
	"sfx": [["breath_stop", 0.4]], "change": "breath_stop"},
	{"tableau": "m_jars", "lines": [
		[0.0, "In the laboratory the water in every jar goes level."]],
	"sfx": [["jar_level", 0.3]], "change": "jar_level"},
	{"tableau": "m_spoon", "lines": [
		[0.0, "In the kitchen, his spoon settles into its dent."],
		[2.4, "Nora's towel is just a towel."]],
	"sfx": [["spoon_settle", 0.6]], "change": "spoon_settle"},
	{"tableau": "m_bed", "lines": [
		[0.0, "In the bunk room the hollows in the mattresses rise, one by one, until the beds are only made."]],
	"sfx": [["mattress_rise", 0.4], ["mattress_rise", 1.4], ["mattress_rise", 2.4]], "change": "mattress_rise"},
	{"tableau": "m_pen", "lines": [
		[0.0, "In the chart room the pen lifts off the drum, and stays lifted."]],
	"sfx": [["pen_lift", 0.5]], "change": "pen_lift"},
	{"tableau": "b_dark", "lines": [
		[0.0, "VENN: \"All right.\""],
		[2.6, "Only that. Then the terminal is a box with a lamp in it."]],
	"sfx": [["venn_allright", 0.0]], "change": ""},
	{"tableau": "a_day", "lines": [
		[0.0, "The surface outside the window goes back, and back, and is water."],
		[2.8, "Grey water. Weather. An edge, and past it a sky."]],
	"sfx": [], "change": ""},
	{"tableau": "end_a_record", "lines": [
		[0.0, "I go up through the station. The office is grey with daylight. The coat on the hook is only wet."],
		[3.0, "I take the corrected record from his desk."]],
	"sfx": [["record_lift", 3.0]], "change": ""},
	{"tableau": "end_a_jetty", "lines": [
		[0.0, "At the jetty, on the morning water, a launch. Two stripes on its pennant."],
		[3.0, "Through its cabin window, its own cabin. Empty. Real."]],
	"sfx": [["launch_engine", 0.0], ["gulls", 1.5]], "change": ""},
	{"tableau": "end_a_inquiry", "lines": [
		[0.0, "The harbour inquiry asks me to certify that the station was found empty."],
		[3.2, "I write eight names. Then his."],
		[5.6, "Then: I cannot certify their absence."]],
	"sfx": [["inquiry_pen", 3.4], ["inquiry_pen", 5.8]], "change": ""},
	{"tableau": "end_a_page", "lines": [
		[0.0, "The corrected page dries on the sill in ordinary daylight."],
		[3.0, "There's a small water stain at its corner. Nothing is reflected in it."]],
	"sfx": [["page_dry", 0.4], ["motif_human_a", 3.6]], "change": ""},
]
const ENDING_CONTINUE := [
	{"tableau": "c_continue", "lines": [
		[0.0, "I press it. The lit line leaves the terminal marked E.V. and comes into mine."],
		[3.0, "It's warm. At my own temperature."]],
	"sfx": [["feed_move", 0.0], ["terminal_on", 2.2]], "change": ""},
	{"tableau": "m_funnel_venn", "lines": [
		[0.0, "In the listening room, his funnel goes quiet."],
		[2.6, "Not cut off. Finished."]],
	"sfx": [["funnel_stop", 0.4]], "change": "funnel_stop"},
	{"tableau": "m_coat", "lines": [
		[0.0, "In the office, the wet coat on the seventh hook lets go of its shoulders."],
		[2.8, "It is an ordinary garment. Nobody is in it."]],
	"sfx": [["coat_slump", 0.5]], "change": "coat_slump"},
	{"tableau": "a_sit", "lines": [
		[0.0, "I sit down. The arms of the instrument come to rest where they were always going to."],
		[3.2, "They don't hold me. They only touch."]],
	"sfx": [["chair_sit", 0.0], ["armature_settle", 1.4]], "change": ""},
	{"tableau": "end_b_terminal_1", "lines": [
		[0.0, "The strip types its first sentence for me."],
		[2.6, "SUBJECT BELL POSSESSES NO SURVIVING PERSONAL EFFECTS."],
		[5.2, "I write under it: Personal effect identified. Repaired cup. Nora Bell."]],
	"sfx": [["index_type", 0.8], ["pencil_correct", 5.0]], "change": ""},
	{"tableau": "m_cup", "lines": [
		[0.0, "In the kitchen, the handle of her cup is warm."]],
	"sfx": [["cup_warm", 0.4]], "change": "cup_warm"},
	{"tableau": "end_b_terminal_2", "lines": [
		[0.0, "Another line. I correct it. Another."],
		[3.0, "DISCREPANCY DETECTED: SUBJECT CONTINUES."],
		[5.4, "Yes."]],
	"sfx": [["pencil_correct", 0.6], ["counter_type", 2.4]], "change": ""},
	{"tableau": "a_morning", "lines": [
		[0.0, "Morning reaches the windows."],
		[2.6, "The station does not go back to the shore."]],
	"sfx": [], "change": ""},
	{"tableau": "end_b_wide", "lines": [
		[0.0, "Far out in the dark, one small lit window. The kitchen."],
		# 1.2 s of silence before the count (the view ducks the ambient in the gap)
		[4.2, "Around it, more windows than I can count. None of them lit."]],
	"sfx": [], "change": ""},
	{"tableau": "end_b_cover", "lines": [
		[0.0, "The recorder starts a new heading: LOCAL SURVEY: ONE OF"],
		[3.0, "I lay a sheet of my own paper over it."],
		[5.4, "Nora Bell took her tea without sugar. Begin there."]],
	"sfx": [["counter_type", 0.4], ["paper_cover", 3.2], ["motif_human_b", 5.8]], "change": ""},
]
const CHOSEN_LINE := "Not now. I've chosen."
## The still the core's end card shows for an ending (CONTINUE: the kitchen among the field of
## dark stations). Read by the core; a missing key means no still.
const END_STILL := {"continue": "res://assets/rooms/R12/end_b_field.png"}

static func end_still(choice: String) -> String:
	return END_STILL.get(choice, "")

# ---------------------------------------------------------------------------------------------
# notebook, objectives, hints
# ---------------------------------------------------------------------------------------------
const OBSERVATIONS := {
	"chamber": "The observation chamber. A chair facing an instrument whose arms end at the head, hands and feet of whoever sits in it.",
	"chair": "The chair is bolted down, facing the instrument. The seat is worn pale in the shape of somebody.",
	"chair_pressed": "After the record was routed, the chair's cushion was pressed down as if someone had just sat in it. Nobody had.",
	"armatures": "The armatures end in a head cup, two cuffs and two foot plates. All adjustable.",
	"armatures_adjusted": "The armature joints are bright: adjusted recently.",
	"armatures_lowered": "After the record was routed, the head cup came down to my height.",
	"surface": "Outside the chamber window, the surface fills the glass. No edge. No reflection of the room.",
	"surface_lid": "A line crosses the surface slowly, top to bottom, like a lid. It is looking at the chair.",
	"surface_withdrew": "When I confirmed what each route does, the surface drew back from the window. A margin of darker water at the edge. The only time it has moved away.",
	"pressure": "The pressure gauge is marked in tides. Its needle rests on IX, trembling.",
	"indicators": "Eight shuttered indicators: ROOK, BELL, IVES, LUSK, PRYCE, DOANE, HART, TULL. Each hums on its own note. Closed.",
	"shutters_turned": "After the record was routed, the eight shutters turned a little toward my terminal.",
	"nameplate": "Over three empty frames, a freshly engraved brass plate: ADA MERCER.",
	"frames_procedure": "Three frames, BODY, PLACE, NAME; a rack of seven cards, all in my name; a switch, WITNESS or COPY; a ROUTE key.",
	"frame_categories": "The frame plates: BODY, what the subject did, in the order it was done. PLACE, where the subject stands in the survey. NAME, who the subject is, and who asked for them.",
	"card_trace": "My MOVEMENT card: the recorder's departure record word for word, the three things I did and its fourth line under them.",
	"card_position": "My POSITION card: 'Ninth position. Centre of the station outline.'",
	"card_identity": "My CONTRACT card: 'Miss Ada Mercer, cataloguer. Requested by E. Venn.'",
	"card_trace_a": "A second MOVEMENT card in my name, with a different run of moves on it.",
	"card_trace_b": "A third MOVEMENT card in my name, with another run of moves on it.",
	"card_position_b": "A second POSITION card: 'Eighth position. Seat beside the window.'",
	"card_identity_b": "A second CONTRACT card: 'Miss Ada Mercer, cataloguer. Requested by S. Rook.'",
	"plate_mismatch": "A frame given a card of its own kind that isn't mine lights its plate: DOES NOT CORRESPOND TO OBSERVER.",
	"copy_port": "A COPY port under a warm brass dust cap.",
	"copy_uncapped": "After the record was routed, the COPY port's cap came off by itself.",
	"copy_preview": "With the switch on COPY, the strip reads: WOULD FINALIZE OBSERVER.",
	"ninth_position": "I am the ninth position. Not indexed: witnessing. It offered to countersign me. I didn't let it.",
	"venn_last": "Venn, through the witness terminal, the last time: 'Don't let it sign for you.'",
	"routing_plates": "Two routing plates, SEVER and CONTINUE, behind shutters until a record is routed.",
	"yoke": "A severance yoke in a tray on the routing wall, always there.",
	"feed_contacts": "Two feed contacts: FEED A, subjects 1 to 4; FEED B, subjects 5 to 8.",
	"ada_terminal": "My terminal: A. MERCER · WITNESS, with a seat shaped for the bridge from the model.",
	"preview_sever": "SEVER, previewed: the eight subject lines go out one by one, then the witness feed. The outer door marker turns to OPEN. Nothing in the preview comes back.",
	"preview_continue": "CONTINUE, previewed: the eight subject lines stay lit. The witness feed moves from E.V.'s terminal to mine. His lamp goes out; mine comes on.",
	"consequences": "If I break it, they're gone, all of them, and I go home. If I stay, they're kept, whatever they are, and Venn can stop. Nobody comes back either way.",
	"seen_sever": "I have broken the line before. I remember the launch.",
	"seen_continue": "I have stayed before. I remember the first correction.",
}
const OBJECTIVES := {
	"frames": "Give the chamber its record of me. Don't let it sign.",
	"routing": "Find out exactly what each route does.",
	"decide": "Choose: break the line, or stay as its witness.",
	"finale": "See it through.",
	"done_chamber": "It's done.",
}
const HINTS := {
	"frames": [
		"The chamber wants a record of you.",
		"Your movements are a body record, your position is a place, your contract is your name. Route as the model showed.",
		"Trace to BODY, position to PLACE, identity to NAME, switch to WITNESS, then ROUTE.",
	],   # hint_line() spells the third step out card by card
	"routing": [
		"Before choosing, make sure you know what each choice does.",
		"Preview each route and match it to what Venn said and what the model showed.",
		"SEVER: connection ends, traces lost, you leave. CONTINUE: you stay as witness, traces kept, Venn's duty ends.",
	],
	"decide": [
		"Both choices are ready. The chamber is waiting for your hands.",
		"The yoke goes across the feed contacts. The bridge goes in your terminal. Preview before you confirm.",
		"To leave: yoke on the contacts, preview, BREAK CONNECTION AND LEAVE. To stay: bridge in your terminal, preview, REMAIN AS WITNESS.",
	],
	"finale": [
		"I've chosen. All that's left is to watch it happen.",
		"I've chosen. All that's left is to watch it happen.",
		"I've chosen. All that's left is to watch it happen.",
	],
}

# ---------------------------------------------------------------------------------------------
# transient presentation-facing state: never saved; cleared by back() and on load
# ---------------------------------------------------------------------------------------------
var _held_card := ""
var _held_cc := ""
var _held_yoke := false
## {} or {"plate": "sever"|"continue", "row": 0|1}: the last CONFIRM mismatch lamp.
var last_mismatch := {}
## The frame whose category plate lit on the last refused ROUTE, or "".
var last_lamp_frame := ""
## The P27 button last refused with "Preview first.", or "".
var refused_button := ""

func initial_state() -> Dictionary:
	return {
		"frames": {"body": "", "place": "", "name": ""}, "switch": "copy", "p25_complete": false,
		"routes": {"sever": "", "continue": ""}, "previewed": [], "p26_complete": false,
		"yoke": "tray", "bridge_seated": false, "final_preview": "", "chosen": "",
		"p27_complete": false, "ending_step": 0, "noticed": [], "window_looks": 0,
		"armature_looks": 0, "opened": [],
	}

func _clear_transient() -> void:
	_held_card = ""
	_held_cc = ""
	_held_yoke = false
	last_mismatch = {}
	last_lamp_frame = ""
	refused_button = ""

func _fresh_state() -> void:
	state = initial_state()
	if game != null:
		game.state.rooms[ID] = state
	_clear_transient()

func is_closeup(v := local_view) -> bool:
	return v != V_ROOM

# ---------------------------------------------------------------------------------------------
# persistence
# ---------------------------------------------------------------------------------------------
func load_state(d: Variant) -> void:
	state = initial_state()
	_clear_transient()
	if not d is Dictionary:
		return
	for k in ["p25_complete", "p26_complete", "p27_complete", "bridge_seated"]:
		if d.get(k) is bool:
			state[k] = d[k]
	state.frames = _load_slots(d.get("frames"), FRAME_IDS, CARD_IDS)
	state.routes = _load_slots(d.get("routes"), ROUTES, CC_IDS)
	if d.get("switch") in ["copy", "witness"]:
		state.switch = d.switch
	if d.get("previewed") is Array:
		for r in d.previewed:
			if r is String and r in ROUTES and not r in state.previewed:
				state.previewed.append(r)
	if d.get("yoke") in ["tray", "contacts"]:
		state.yoke = d.yoke
	if d.get("final_preview") in ["", "sever", "continue"]:
		state.final_preview = d.final_preview
	if d.get("chosen") in ["", "sever", "continue"]:
		state.chosen = d.chosen
	state.noticed = _load_ids(d.get("noticed"), NOTICED_IDS)
	state.opened = _load_ids(d.get("opened"), OPENED_IDS)
	for k in ["window_looks", "armature_looks"]:
		if _all_whole([d.get(k)]):
			state[k] = clampi(int(d[k]), 0, 99)
	# Derived agreement: each puzzle needs the one before it; a choice needs P27 and vice versa.
	if state.p26_complete and not state.p25_complete:
		state.p26_complete = false
	if not (state.p26_complete and state.p27_complete and state.chosen != ""):
		state.p27_complete = false
		state.chosen = ""
	if state.chosen != "" and _all_whole([d.get("ending_step")]):
		state.ending_step = clampi(int(d.ending_step), 0, steps(state.chosen).size() - 1)
	if state.chosen != "":
		local_view = V_ENDING   # harmless; the core resets it, reconcile() puts it back
	if state.p25_complete:
		state.frames = SOLUTION_FRAMES.duplicate()
		state.switch = "witness"
	if state.p26_complete:
		state.routes = SOLUTION_ROUTES.duplicate()
		state.previewed = ["sever", "continue"]
	else:
		state.yoke = "tray"
		state.bridge_seated = false
		state.final_preview = ""
	_sync_final_preview()

## A preview only stands for the fitting it was taken with.
func _sync_final_preview() -> void:
	var yoke_on: bool = state.yoke == "contacts"
	var seated: bool = state.bridge_seated
	if state.final_preview == "sever" and not (yoke_on and not seated):
		state.final_preview = ""
	if state.final_preview == "continue" and not (seated and not yoke_on):
		state.final_preview = ""

## {slot: id or ""} for `slots`, accepting only `ids`, each in one slot at most (a later slot loses).
static func _load_slots(v: Variant, slots: Array, ids: Array) -> Dictionary:
	var out := {}
	for s in slots:
		out[s] = ""
	if not v is Dictionary:
		return out
	var used := []
	for s in slots:
		var x = v.get(s)
		if x is String and x in ids and not x in used:
			out[s] = x
			used.append(x)
	return out

static func _load_ids(v: Variant, known: Array) -> Array:
	var out := []
	if v is Array:
		for x in v:
			if x is String and x in known and not x in out:
				out.append(x)
	return out

func reconcile() -> void:
	for pid in ["P25", "P26", "P27"]:
		var key := "p%s_complete" % pid.substr(1)
		if state[key] and not game.flag(pid):
			game.set_flag(pid)
	if game.flag("P25") and not state.p25_complete:
		_set_p25_state()
	if game.flag("P26") and not state.p26_complete:
		_set_p25_state()
		_set_p26_state()
		if not game.flag("P25"):
			game.set_flag("P25")
	if game.flag("P27") and not state.p27_complete:
		state.p27_complete = true
	_bridge_net([])
	# A load lands every room in "room"; once she has chosen, this one stands in the ending.
	if state.chosen != "":
		local_view = V_ENDING

func _set_p25_state() -> void:
	state.p25_complete = true
	state.frames = SOLUTION_FRAMES.duplicate()
	state.switch = "witness"

func _set_p26_state() -> void:
	state.p26_complete = true
	state.routes = SOLUTION_ROUTES.duplicate()
	state.previewed = ["sever", "continue"]

## The bridge is always somewhere she can reach once the stair door has opened: in her pocket or
## seated in her terminal, never both, never neither. Returns true if it handed the bridge back.
func _bridge_net(ev: Array) -> bool:
	if state.bridge_seated and game.has_item(BRIDGE):
		state.bridge_seated = false
		_sync_final_preview()
	if game.flag("P24") and not state.bridge_seated and not game.has_item(BRIDGE):
		game.give(BRIDGE, ev)
		return true
	return false

# ---------------------------------------------------------------------------------------------
# pure helpers for the view and tests
# ---------------------------------------------------------------------------------------------
func p25_done() -> bool:
	return state.p25_complete or game.flag("P25")

func p26_done() -> bool:
	return state.p26_complete or game.flag("P26")

func p27_done() -> bool:
	return state.p27_complete or game.flag("P27")

## "s0" before the record is routed, "s1" after P25, "s2" after P26.
func stage() -> String:
	if p26_done():
		return "s2"
	if p25_done():
		return "s1"
	return "s0"

func frames() -> Dictionary:
	return state.frames.duplicate()

func switch() -> String:
	return state.switch

func held_card() -> String:
	return _held_card

func held_cc() -> String:
	return _held_cc

func held_yoke() -> bool:
	return _held_yoke

## True while the card sits in the rack (not in a frame, not in her hand).
func card_in_rack(cid: String) -> bool:
	return cid in CARD_IDS and not cid in state.frames.values() and _held_card != cid

## True while the consequence card sits in the tray (not in a slot, not in her hand).
func cc_in_tray(cid: String) -> bool:
	return cid in CC_IDS and not cid in state.routes.values() and _held_cc != cid

func strip_lines() -> Array:
	if p25_done():
		return STRIP_DONE.duplicate()
	return STRIP_COPY.duplicate() if state.switch == "copy" else []

## The MOVEMENT card: the stored P05 trace (never recomputed) and the recorder's fourth line.
func body_card_lines() -> Array:
	return _move_lines(game.value("p05_trace"))

func _move_lines(trace: Array) -> Array:
	var out := []
	for t in trace:
		out.append(GameSim.move_text(t))
	out.append(line4())
	return out

## The two decoy MOVEMENT runs for `trace`: the first two events swapped, and the last two
## swapped. A decoy that would repeat the trace or the other decoy, or any decoy of a trace
## under three events, is the next DECOY_FALLBACK run that differs from both. Deterministic.
static func decoys_for(trace: Array) -> Array:
	var made := []
	if trace.size() >= 3:
		var a := trace.duplicate()
		a[0] = trace[1]
		a[1] = trace[0]
		var b := trace.duplicate()
		b[-2] = trace[-1]
		b[-1] = trace[-2]
		made = [a, b]
	else:
		made = [[], []]
	var out := []
	for d in made:
		var pick: Array = d
		if pick.size() < 3 or pick == trace or pick in out:
			for f in DECOY_FALLBACK:
				if f != trace and not f in out:
					pick = f.duplicate()
					break
		out.append(pick)
	return out

## The move ids printed on MOVEMENT card `cid` ("trace", "trace_a" or "trace_b").
func movement_of(cid: String) -> Array:
	var trace: Array = game.value("p05_trace")
	match cid:
		"trace":
			return trace
		"trace_a":
			return decoys_for(trace)[0]
		"trace_b":
			return decoys_for(trace)[1]
	return []

## True while frame `f` holds a card of its own category that is not hers: its plate is lit
## with NOT_OBSERVER. Derived from the frames, so it survives saves; nothing locks.
func plate_mismatch(f: String) -> bool:
	if p25_done() or not f in FRAME_IDS:
		return false
	var cid: String = state.frames[f]
	return cid != "" and CARD_FRAME.get(cid, "") == f and cid != SOLUTION_FRAMES[f]

func line4() -> String:
	return LINE4_TURNED if game.flag("t1x_turned") else LINE4_STILL

func card_header(cid: String) -> String:
	return CARD_HEADER.get(cid, "")

## The card's face as lines (a MOVEMENT card has several).
func card_text(cid: String) -> Array:
	if cid == "trace":
		return body_card_lines()
	if cid in ["trace_a", "trace_b"]:
		return _move_lines(movement_of(cid))
	return [CARD_TEXT[cid]] if CARD_TEXT.has(cid) else []

func routes() -> Dictionary:
	return state.routes.duplicate()

func previewed(route: String) -> bool:
	return route in state.previewed

func yoke() -> String:
	return state.yoke

func bridge_seated() -> bool:
	return state.bridge_seated

func final_preview() -> String:
	return state.final_preview

func chosen() -> String:
	return state.chosen

func ending_step() -> int:
	return state.ending_step

static func steps(choice: String) -> Array:
	if choice == "sever":
		return ENDING_SEVER
	if choice == "continue":
		return ENDING_CONTINUE
	return []

func tableau() -> String:
	var s := steps(state.chosen)
	return s[state.ending_step].tableau if not s.is_empty() else ""

func endings_seen() -> Array:
	return game.value("endings_seen")

# ---------------------------------------------------------------------------------------------
# arrival, exits, back
# ---------------------------------------------------------------------------------------------
func arrive(ev: Array, first: bool) -> void:
	_clear_transient()
	var gave := _bridge_net(ev)
	var chain: bool = first and not "arrival" in state.noticed
	if chain:
		state.noticed.append("arrival")
		_fx(ev, "notice", {"which": "name_frame"})
		_observe("chamber")
		_say(ev, ARRIVAL, 0.0, true)
		_say(ev, "Every arm of the instrument ends where a part of a seated person would be. Head. Hands. Feet.", 2.4, true)
		_say(ev, "Through the left arch, a wall of frames. One of them already has a name on it.", 5.0, true)
		_say(ev, "Mine.", 7.2, true)
	if gave:
		if chain:
			_say(ev, "The bridge is in my pocket. The door gave it back.", 9.2, true)
		else:
			_say(ev, "The bridge is in my pocket. The door gave it back.")

func exit_block(to: String) -> String:
	if to == "R11" and state.chosen != "":
		return CHOSEN_LINE
	return ""

func back(_ev: Array) -> void:
	match local_view:
		V_ENDING:
			return
		C_FRAMES:
			local_view = V_FRAMES
		C_ROUTING, C_FINAL:
			local_view = V_ROUTING
		_:
			local_view = V_ROOM
	_clear_transient()

func hint_frozen() -> bool:
	return local_view == V_ENDING

## P25's third step names each true card by what is printed on it.
const HINT_FRAMES_3 := "The true cards: %s to BODY; 'Ninth position. Centre of the station outline.' to PLACE; 'Requested by E. Venn.' to NAME. Then the switch to WITNESS, and ROUTE."
func hint_line(level: int) -> String:
	if objective() == "frames" and level >= 2:
		var moves := body_card_lines()
		moves.pop_back()
		var body := "the MOVEMENT card reading '" + " ".join(moves) + "'" if not moves.is_empty() \
			else "the MOVEMENT card that is my own departure record"
		return HINT_FRAMES_3 % body
	return super.hint_line(level)

## Where a loaded game stands in this room (the core's resume hook): in the ending once she
## has chosen, else the room.
func resume_view() -> String:
	return V_ENDING if state.chosen != "" else V_ROOM

## A load in this room. Mid-ending there is no "Back in the observation chamber.": the page she
## was on is played again, so the view redraws it. Returns true if it handled the resume.
func resume(ev: Array) -> bool:
	if state.chosen == "":
		return false
	local_view = V_ENDING
	_emit_step(ev)
	return true

func objective() -> String:
	if state.chosen != "":
		return "finale"
	if not p25_done():
		return "frames"
	if not p26_done():
		return "routing"
	if not p27_done():
		return "decide"
	return "done_chamber"

# ---------------------------------------------------------------------------------------------
# actions
# ---------------------------------------------------------------------------------------------
func _known(action: String) -> bool:
	return action in HOTSPOTS or action in FRAMES_HOTSPOTS or action in ROUTING_HOTSPOTS \
		or action in FRAMES_CONTROLS or action in ROUTING_CONTROLS or action in FINAL_CONTROLS \
		or action in ENDING_CONTROLS

## Moves to a base view; leaving a close-up puts whatever is in her hand back.
func _goto(v: String) -> void:
	if local_view != v and local_view in OPENED_IDS:
		_clear_transient()
	local_view = v

func act(action: String, ev: Array) -> void:
	if state.chosen != "":
		if local_view == V_ENDING and action == "ending_next":
			_ending_next(ev)
		elif _known(action):
			# After a load (or any stray click) the ending resumes where it was.
			local_view = V_ENDING
			_emit_step(ev)
		return
	match local_view:
		C_FRAMES:
			if action in FRAMES_CONTROLS:
				_frames_control(action, ev)
				return
		C_ROUTING:
			if action in ROUTING_CONTROLS:
				_routing_control(action, ev)
				return
		C_FINAL:
			if action in FINAL_CONTROLS:
				_final_control(action, ev)
				return
	if action in HOTSPOTS:
		_goto(V_ROOM)
		_room(action, ev)
	elif action in FRAMES_HOTSPOTS:
		_goto(V_FRAMES)
		_frames_wall(action, ev)
	elif action in ROUTING_HOTSPOTS:
		_goto(V_ROUTING)
		_routing_wall(action, ev)

# ----- view A ---------------------------------------------------------------------------------
func _room(action: String, ev: Array) -> void:
	var s := stage()
	match action:
		"to_frames":
			local_view = V_FRAMES
			_say(ev, "The record wall.")
		"to_routing":
			local_view = V_ROUTING
			_say(ev, "The routing wall.")
		"chair":
			if s == "s0":
				_observe("chair")
				_say(ev, "A plain chair, bolted down, facing the instrument. The seat is worn pale in the shape of somebody.")
			elif s == "s1":
				_observe("chair_pressed")
				_say(ev, "The cushion is pressed down, as if someone has just sat. Nobody has. I haven't.")
			else:
				_say(ev, "It's waiting. It doesn't mind how long.")
		"armatures":
			state.armature_looks = mini(state.armature_looks + 1, 99)
			if s != "s0":
				_observe("armatures_lowered")
				_say(ev, "The head cup has come down. It's at my height now.")
			elif not has_seen("armatures"):
				_observe("armatures")
				_say(ev, "Every arm ends at a part of whoever sits there. A cup for the back of the head. Two cuffs. Two plates for the feet.")
			else:
				_observe("armatures_adjusted")
				_say(ev, "Someone has adjusted them recently. The brass is bright at the joints.")
		"window":
			if p26_done():
				_say(ev, "It drew back from the glass. A margin of darker water at the edge. It made room.")
				return
			state.window_looks = mini(state.window_looks + 1, 99)
			match state.window_looks:
				1:
					_observe("surface")
					_say(ev, "The surface. It fills the glass. There's no edge to it, and no reflection of the room.")
				2:
					_say(ev, "It isn't water. Water moves. This is holding still, the way a held breath is still.")
				_:
					_observe("surface_lid")
					_say(ev, "A line has crossed it, slowly, top to bottom, like a lid. It isn't looking at the station. It's looking at the chair.")
		"pressure":
			if p26_done():
				_say(ev, "The needle has eased back a hair. Off IX, a little.")
			else:
				_observe("pressure")
				_say(ev, "A pressure gauge, marked in tides. The needle rests on IX and trembles, as if something is leaning on it.")

# ----- view B ---------------------------------------------------------------------------------
func _frames_wall(action: String, ev: Array) -> void:
	var s := stage()
	match action:
		"nameplate":
			_observe("nameplate")
			_say(ev, "A brass plate over three empty frames: ADA MERCER. The engraving is fresh. There are brass filings still in the letters.")
		"indicators":
			if s == "s0":
				_observe("indicators")
				_say(ev, "Eight indicators, shuttered. Under each, a name: ROOK, BELL, IVES, LUSK, PRYCE, DOANE, HART, TULL. Each hums very faintly, on its own note.")
			else:
				_observe("shutters_turned")
				_say(ev, "The shutters have all turned a little. Toward my terminal.")
		"copy_port":
			if s == "s0":
				_observe("copy_port")
				_say(ev, "A socket marked COPY, under a brass dust cap on a chain. The cap is warm.")
			else:
				_observe("copy_uncapped")
				_say(ev, "The cap is off, hanging on its chain. I didn't take it off.")
		"frame_body", "frame_place", "frame_name", "card_rack", "terminal":
			var first: bool = not C_FRAMES in state.opened
			if first:
				state.opened.append(C_FRAMES)
				_observe("frames_procedure")
			local_view = C_FRAMES
			if p25_done():
				if action == "terminal":
					_say(ev, "Lit. The strip still says it: AUTOMATIC COUNTERSIGN AVAILABLE.")
				else:
					_say(ev, FRAMES_READ_ONLY)
			elif first:
				if state.switch == "copy":
					_say(ev, "Three frames: BODY, PLACE, NAME. A rack of seven cards, all in my name. The switch is on COPY, and the strip under it already reads: WOULD FINALIZE OBSERVER.")
				else:
					_say(ev, "Three frames: BODY, PLACE, NAME. A rack of seven cards, all in my name. The switch is on WITNESS.")
			else:
				_say(ev, "The frames, the cards, the switch.")

# ----- c_frames (P25) -------------------------------------------------------------------------
func _category_line(f: String) -> String:
	return FRAME_LABEL[f] + ". " + CATEGORY[f]

func _frame_of(cid: String) -> String:
	for f in FRAME_IDS:
		if state.frames[f] == cid:
			return f
	return ""

func _frames_control(action: String, ev: Array) -> void:
	if p25_done():
		_say(ev, FRAMES_READ_ONLY)
		return
	if action.begins_with("rack_"):
		_rack(action.substr(5), ev)
	elif action.begins_with("f_"):
		_frame(action.substr(2), ev)
	elif action.begins_with("look_") and action.substr(5) in FRAME_IDS:
		_observe("frame_categories")
		_say(ev, _category_line(action.substr(5)))
	elif action == "look_strip":
		var lines := strip_lines()
		_say(ev, " ".join(lines) if not lines.is_empty() else "The strip is blank.")
	elif action == "switch":
		_switch(ev)
	elif action == "route":
		_route(ev)

func _rack(cid: String, ev: Array) -> void:
	if not cid in CARD_IDS:
		return
	if _frame_of(cid) != "":
		_say(ev, "That card's in a frame.")
		return
	if _held_card == cid:
		_held_card = ""
		_sfx(ev, "card_return")
		_say(ev, "Back in the rack.")
		return
	_held_card = cid
	_sfx(ev, "card_lift")
	# every lift reads the card aloud: seven cards in her name, told apart only by their words
	_observe("card_" + cid)
	if CARD_FRAME[cid] == "body":
		var moves := card_text(cid)
		moves.pop_back()
		_say(ev, "A MOVEMENT card: '" + " ".join(moves) + "' And under them: '" + line4() + "'")
	else:
		_say(ev, CARD_LIFT[cid])

func _frame(f: String, ev: Array) -> void:
	if _held_card != "":
		var occupant: String = state.frames[f]
		state.frames[f] = _held_card
		_held_card = ""
		if last_lamp_frame == f:
			last_lamp_frame = ""
		_sfx(ev, "card_seat")
		_fx(ev, "card_seat", {"frame": f})
		var line := "It clips into the %s frame." % FRAME_LABEL[f]
		if occupant != "":
			line += " The other card goes back to the rack."
		if plate_mismatch(f):
			_sfx(ev, "frame_lamp", 0.2)
			_fx(ev, "plate_mismatch", {"frame": f})
			_observe("plate_mismatch")
			line += " The plate lights: " + NOT_OBSERVER + "."
		_say(ev, line)
	elif state.frames[f] != "":
		state.frames[f] = ""
		if last_lamp_frame == f:
			last_lamp_frame = ""
		_sfx(ev, "card_return")
		_say(ev, "Back in the rack.")
	else:
		_observe("frame_categories")
		_say(ev, _category_line(f))

func _switch(ev: Array) -> void:
	_sfx(ev, "switch_throw")
	if state.switch == "copy":
		state.switch = "witness"
		_say(ev, "WITNESS. The strip goes blank.")
	else:
		state.switch = "copy"
		_sfx(ev, "strip_type", 0.3)
		_fx(ev, "strip_print", {"lines": strip_lines()})
		_observe("copy_preview")
		_say(ev, "COPY. The strip types: WOULD FINALIZE OBSERVER.")

func _route(ev: Array) -> void:
	for f in FRAME_IDS:
		if state.frames[f] == "":
			_sfx(ev, "route_refuse")
			_say(ev, "ROUTE won't turn. The %s frame is empty." % FRAME_LABEL[f])
			return
	if state.switch == "copy":
		_sfx(ev, "route_refuse")
		_sfx(ev, "strip_type", 0.2)
		_fx(ev, "strip_print", {"lines": STRIP_COPY.duplicate()})
		_observe("copy_preview")
		_say(ev, "ROUTE won't turn. The strip: WOULD FINALIZE OBSERVER.")
		_say(ev, "Not COPY. Not that.", 1.8)
		return
	for f in FRAME_IDS:
		if state.frames[f] != SOLUTION_FRAMES[f]:
			_sfx(ev, "route_refuse")
			_sfx(ev, "frame_lamp", 0.2)
			if plate_mismatch(f):
				# the right kind of card, not hers: the plate is already lit and says so
				_fx(ev, "plate_mismatch", {"frame": f})
				_observe("plate_mismatch")
				_say(ev, "ROUTE won't turn. The %s plate reads: %s." % [FRAME_LABEL[f], NOT_OBSERVER])
				return
			_fx(ev, "frame_lamp", {"frame": f})
			last_lamp_frame = f
			_say(ev, "ROUTE won't turn. The %s plate lights: '%s'" % [FRAME_LABEL[f], CATEGORY[f]])
			return
	state.p25_complete = true
	_clear_transient()
	game.solve("P25", ev)
	_observe("ninth_position")
	_observe("venn_last")
	for s in [["route_key", 0.0], ["frames_slide", 0.5], ["strip_type", 2.6], ["strip_type", 5.4],
			["terminal_on", 9.4], ["venn_last", 11.6], ["shutters_open", 16.2]]:
		_sfx(ev, s[0], s[1])
	_fx(ev, "frames_slide")
	_fx(ev, "strip_print", {"lines": STRIP_DONE.duplicate(), "delays": [2.6, 5.4]})
	_fx(ev, "terminal_lit")
	for l in [[0.0, "The key turns. All three frames slide back into the wall together, like drawers into a desk."],
			[2.6, "The strip types, slowly: NINTH OBSERVER LOCATED."],
			[5.4, "Then: AUTOMATIC COUNTERSIGN AVAILABLE."],
			[7.6, "It's offering to sign for me."],
			[9.6, "The terminal lights. Through its grille, small and close, his voice."],
			[11.8, "VENN: \"Don't let it sign for you.\""],
			[14.4, "That was the last of him it had. The lamp stays on."],
			[16.4, "Across the chamber, on the routing wall, a shutter rolls up."]]:
		_say(ev, l[1], l[0], true)

# ----- view C ---------------------------------------------------------------------------------
func _routing_wall(action: String, ev: Array) -> void:
	if not p25_done():
		match action:
			"plate_sever", "plate_continue":
				_observe("routing_plates")
				_say(ev, "Two plates behind brass shutters: SEVER and CONTINUE. The shutters are locked. A tag: ROUTE A RECORD FIRST.")
			"cards":
				_say(ev, "A holder of four cards, behind the same shutter.")
			"handle":
				_say(ev, "The severance handle, locked in its housing.")
			"yoke_tray":
				_observe("yoke")
				_say(ev, "A tray with a severance yoke in it: a heavy insulated bar. It's on the chamber's inventory, in his hand.")
			"contacts":
				_observe("feed_contacts")
				_say(ev, "Two feed contacts, labelled FEED A and FEED B.")
			"bridge_seat":
				_observe("ada_terminal")
				_say(ev, "My terminal. A. MERCER · WITNESS. There's a seat in it the shape of the bridge from the model.")
		return
	if action in ["plate_sever", "plate_continue", "cards"]:
		var first: bool = not C_ROUTING in state.opened
		if first:
			state.opened.append(C_ROUTING)
		local_view = C_ROUTING
		if p26_done():
			_say(ev, ROUTING_SEALED)
		elif first:
			_say(ev, "Two plates, SEVER and CONTINUE, each with a PREVIEW key and a card slot. Four cards in the tray. A button: CONFIRM UNDERSTANDING.")
		else:
			_say(ev, "The routing plates.")
		return
	if not p26_done():
		_say(ev, ROUTING_LATER)
		return
	_open_final(ev)

# ----- c_routing (P26) ------------------------------------------------------------------------
func _slot_of(cid: String) -> String:
	for r in ROUTES:
		if state.routes[r] == cid:
			return r
	return ""

func _routing_control(action: String, ev: Array) -> void:
	if p26_done():
		_say(ev, ROUTING_SEALED)
		return
	if action in CC_IDS:
		if _slot_of(action) != "":
			_say(ev, "That card's in a plate.")
		elif _held_cc == action:
			_held_cc = ""
			_sfx(ev, "cc_return")
			_say(ev, "Back in the tray.")
		else:
			_held_cc = action
			_sfx(ev, "cc_lift")
			_say(ev, "'" + CC_TEXT[action] + "'")
		return
	match action:
		"slot_sever", "slot_continue":
			var r := action.substr(5)
			if _held_cc != "":
				state.routes[r] = _held_cc
				_held_cc = ""
				last_mismatch = {}
				_sfx(ev, "cc_seat")
				_say(ev, "Into the %s slot." % r.to_upper())
			elif state.routes[r] != "":
				state.routes[r] = ""
				last_mismatch = {}
				_sfx(ev, "cc_return")
				_say(ev, "Back in the tray.")
			else:
				_say(ev, "An empty card slot.")
		"preview_sever":
			_preview_route("sever", "preview_out", [
				[0.0, "PREVIEW. On the SEVER plate the eight subject lamps go out, one after another."],
				[3.0, "The witness feed lamp goes out last. The outer-door shutter turns to OPEN."],
				[5.6, "Then they all light again. It was only showing me."]],
				"The eight go out. The feed goes out. The door opens. Every time.", ev)
		"preview_continue":
			_preview_route("continue", "preview_move", [
				[0.0, "PREVIEW. On the CONTINUE plate the eight subject lamps stay lit."],
				[2.8, "The witness feed slides along its rail, from the terminal marked E.V. to the one marked A.M."],
				[5.6, "His lamp goes out. Mine comes on. The eight don't change."]],
				"The eight stay lit. His lamp out, mine on.", ev)
		"look_sever":
			_say(ev, "SEVER. Subject lines one to eight, the witness feed, the outer door. Each with a lamp.")
		"look_continue":
			_say(ev, "CONTINUE. Subject lines one to eight, the witness feed from E.V. to A.M., the outer door.")
		"confirm":
			_confirm(ev)

func _preview_route(r: String, sound: String, first_lines: Array, repeat: String, ev: Array) -> void:
	if not r in state.previewed:
		state.previewed.append(r)
	_sfx(ev, "preview_key")
	_sfx(ev, sound, 0.3)
	_fx(ev, "preview", {"route": r})
	if not has_seen("preview_" + r):
		_observe("preview_" + r)
		for l in first_lines:
			_say(ev, l[1], l[0], true)
	else:
		_say(ev, repeat)

func _confirm(ev: Array) -> void:
	if not ("sever" in state.previewed and "continue" in state.previewed):
		_sfx(ev, "confirm_refuse")
		_say(ev, "CONFIRM UNDERSTANDING won't press. A tag on it: PREVIEW EACH ROUTE.")
		return
	if state.routes.sever == "" or state.routes["continue"] == "":
		_sfx(ev, "confirm_refuse")
		_say(ev, "Each plate needs a card before I can say I understand it.")
		return
	for r in ROUTES:
		var card: String = state.routes[r]
		if card != SOLUTION_ROUTES[r]:
			var m: Array = MISMATCH[r][card]
			last_mismatch = {"plate": r, "row": m[1]}
			_sfx(ev, "mismatch_lamp")
			_fx(ev, "mismatch", {"plate": r, "row": m[1]})
			_say(ev, m[0])
			return
	state.p26_complete = true
	_clear_transient()
	game.solve("P26", ev)
	_observe("consequences")
	_observe("surface_withdrew")
	_sfx(ev, "confirm_stamp", 0.0)
	_sfx(ev, "slots_close", 0.6)
	_sfx(ev, "surface_withdraw", 10.4)
	_fx(ev, "slots_close")
	for l in [[0.0, "CONFIRM UNDERSTANDING. The two cards drop into the plates, and the slots close over them."],
			[2.8, "If I break it, they're gone, all of them, and I go home."],
			[5.6, "If I stay, they're kept, whatever they are, and Venn can stop."],
			[8.2, "Nobody comes back either way."],
			[10.4, "Behind me, in the window, something moved."]]:
		_say(ev, l[1], l[0], true)
	_fx(ev, "glance", {"rect": [474, 96, 500, 290], "target": "window"})
	game.save_checkpoint()

# ----- c_final (P27) --------------------------------------------------------------------------
func _open_final(ev: Array) -> void:
	var first: bool = not C_FINAL in state.opened
	if first:
		state.opened.append(C_FINAL)
	local_view = C_FINAL
	_say(ev, "The feed contacts, my terminal, the preview lamps. Two buttons, each with its whole meaning printed on it."
		if first else "The yoke, the bridge, the two buttons.")
	var seen_e := endings_seen()
	if "sever" in seen_e and not has_seen("seen_sever"):
		_observe("seen_sever")
		_say(ev, "I've broken the line before. I remember the launch.", 1.6)
	if "continue" in seen_e and not has_seen("seen_continue"):
		_observe("seen_continue")
		_say(ev, "I've stayed before. I remember the first correction.", 1.6)

func _fittings_changed() -> void:
	state.final_preview = ""
	refused_button = ""

func _final_control(action: String, ev: Array) -> void:
	var yoke_on: bool = state.yoke == "contacts"
	var seated: bool = state.bridge_seated
	match action:
		"tray":
			if _held_yoke:
				_held_yoke = false
				_sfx(ev, "yoke_return")
				_say(ev, "Back in its tray.")
			elif not yoke_on:
				_held_yoke = true
				_sfx(ev, "yoke_lift")
				_say(ev, "The severance yoke. Heavy, and insulated at the grips.")
			else:
				_say(ev, "The tray is empty. The yoke is across the contacts.")
		"contacts":
			if _held_yoke:
				state.yoke = "contacts"
				_held_yoke = false
				_fittings_changed()
				_sfx(ev, "yoke_fit")
				_fx(ev, "yoke_fit")
				_say(ev, "It drops across both feed contacts and seats.")
			elif yoke_on:
				state.yoke = "tray"
				_fittings_changed()
				_sfx(ev, "yoke_return")
				_say(ev, "I lift the yoke off. Back in its tray.")
			else:
				_observe("feed_contacts")
				_say(ev, "Two feed contacts: FEED A, SUBJECTS 1 TO 4. FEED B, SUBJECTS 5 TO 8. The yoke would sit across both.")
		"bridge_seat":
			_bridge_seat(ev)
		"preview":
			refused_button = ""
			if yoke_on and seated:
				state.final_preview = ""
				_sfx(ev, "one_or_other")
				_say(ev, "One or the other.")
			elif not yoke_on and not seated:
				state.final_preview = ""
				_sfx(ev, "final_preview")
				_say(ev, "PREVIEW. Nothing fitted. The lamps show the chamber as it is.")
			elif yoke_on:
				state.final_preview = "sever"
				_sfx(ev, "final_preview")
				_sfx(ev, "preview_out", 0.3)
				_fx(ev, "final_preview", {"route": "sever"})
				_say(ev, "PREVIEW. The eight lines go out on the panel, one by one. In the preview only.")
			else:
				state.final_preview = "continue"
				_sfx(ev, "final_preview")
				_sfx(ev, "preview_move", 0.3)
				_fx(ev, "final_preview", {"route": "continue"})
				_say(ev, "PREVIEW. The lit line moves from E.V. to A.M. on the panel. In the preview only.")
		"btn_sever":
			if yoke_on and seated:
				_sfx(ev, "one_or_other")
				_say(ev, "One or the other.")
			elif not yoke_on:
				_sfx(ev, "button_refuse")
				_say(ev, "The yoke isn't across the contacts.")
			elif state.final_preview != "sever":
				refused_button = "sever"
				_sfx(ev, "button_refuse")
				_say(ev, "Preview first.")
			else:
				_commit("sever", ev)
		"btn_continue":
			if yoke_on and seated:
				_sfx(ev, "one_or_other")
				_say(ev, "One or the other.")
			elif not seated:
				_sfx(ev, "button_refuse")
				_say(ev, "The bridge isn't in my terminal.")
			elif state.final_preview != "continue":
				refused_button = "continue"
				_sfx(ev, "button_refuse")
				_say(ev, "Preview first.")
			else:
				_commit("continue", ev)
		"look_lamps":
			_say(ev, "The preview lamps. They only show. They don't do.")
		"look_handle":
			_say(ev, "The severance handle. It stays locked until BREAK CONNECTION AND LEAVE is pressed.")

func _bridge_seat(ev: Array) -> void:
	if state.bridge_seated:
		game.give(BRIDGE, ev)
		state.bridge_seated = false
		_fittings_changed()
		_sfx(ev, "bridge_lift")
		_say(ev, "I take the bridge out. It's still warm.")
	elif game.has_item(BRIDGE):
		game.take(BRIDGE)
		state.bridge_seated = true
		_fittings_changed()
		_sfx(ev, "bridge_seat")
		_fx(ev, "bridge_seat")
		_say(ev, "The bridge seats in my terminal. A. MERCER · WITNESS. The lamp beside it doesn't light. Not yet.")
	else:
		_say(ev, "The seat is empty. It wants the bridge from the model.")

func _commit(choice: String, ev: Array) -> void:
	state.chosen = choice
	state.p27_complete = true
	_clear_transient()
	game.solve("P27", ev)
	local_view = V_ENDING
	state.ending_step = 0
	_emit_step(ev)

# ----- endings --------------------------------------------------------------------------------
func _emit_step(ev: Array) -> void:
	var all := steps(state.chosen)
	if all.is_empty():
		return
	var st: Dictionary = all[state.ending_step]
	for l in st.lines:
		_say(ev, l[1], l[0], true)
	for s in st.sfx:
		_sfx(ev, s[0], s[1])
	_fx(ev, "ending", {"choice": state.chosen, "step": state.ending_step, "tableau": st.tableau,
		"change": st.change})

func _ending_next(ev: Array) -> void:
	if state.ending_step < steps(state.chosen).size() - 1:
		state.ending_step += 1
		_emit_step(ev)
	else:
		game.finish(state.chosen)

# ---------------------------------------------------------------------------------------------
# items
# ---------------------------------------------------------------------------------------------
func use_item(item: String, target: String, ev: Array) -> bool:
	if target.begins_with("go:") or not _known(target):
		return false
	if state.chosen != "":
		local_view = V_ENDING
		_emit_step(ev)
		return true
	if item != BRIDGE:
		_say(ev, "That belongs upstairs.")
		return true
	match target:
		"bridge_seat":
			if not p26_done():
				_say(ev, "Not yet. I don't know yet what it would do.")
			else:
				if local_view != C_FINAL:
					_goto(V_ROUTING)
					if not C_FINAL in state.opened:
						state.opened.append(C_FINAL)
					local_view = C_FINAL
				_bridge_seat(ev)
		"contacts":
			_say(ev, "The bridge goes in my terminal, not across the feed.")
		_:
			_say(ev, "Not here. The bridge is for my terminal.")
	return true

# ---------------------------------------------------------------------------------------------
# debug
# ---------------------------------------------------------------------------------------------
## R12 is first entered at tide IX: every tide starts it fresh.
func debug_prepare(_t: int) -> void:
	_fresh_state()

## 0 fresh at IX; 1 P25; 2 P26 (checkpoint); 3 yoke fitted, SEVER previewed; 4 bridge seated,
## CONTINUE previewed; 5 / 6 the SEVER / CONTINUE ending at its first step; 7 / 8 at its last.
func debug_jump(n: int) -> void:
	game.debug_tide(9, ID)
	_fresh_state()
	local_view = V_ROOM
	var ev: Array = []
	if n >= 1:
		state.noticed = ["arrival"]
		_set_p25_state()
		game.solve("P25", ev)
	if n >= 2:
		_set_p26_state()
		game.solve("P26", ev)
		_bridge_net(ev)
		game.save_checkpoint()
	if n == 3 or n == 5 or n == 7:
		state.yoke = "contacts"
		state.final_preview = "sever"
	if n == 4 or n == 6 or n == 8:
		game.take(BRIDGE)
		state.bridge_seated = true
		state.final_preview = "continue"
	if n == 5 or n == 7:
		_commit("sever", ev)
	if n == 6 or n == 8:
		_commit("continue", ev)
	if n == 7 or n == 8:
		state.ending_step = steps(state.chosen).size() - 1
	reconcile()
