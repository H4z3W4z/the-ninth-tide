extends "res://tests/rooms/room_test_base.gd"
## R12, the Observation Chamber: P25 (the record of the observer), P26 (understand each route),
## P27 (the choice), the P26 checkpoint, both endings, the bridge net, saves, reconcile, hints,
## debug jumps and the chain actions handed to tests/chain_test.gd.
##   godot --headless --path . --script tests/rooms/R12_test.gd

const ROOM := "R12"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := ["P24"]
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 9

const TRACE := ["zero_turned", "hatch_opened", "stair_looked"]
const BRIDGE := "witness_bridge"
const READ_ONLY := "It has its record of me. The frames won't open again."
const SEALED := "I've seen both. I know what each one does."
const LATER := "Not until I know exactly what each one does."
const COPY_REFUSAL := "ROUTE won't turn. The strip: WOULD FINALIZE OBSERVER."
const ONE_OR_OTHER := "One or the other."
const PREVIEW_FIRST := "Preview first."
const CATEGORY := {
	"body": "What the subject did, in the order it was done.",
	"place": "Where the subject stands in the survey.",
	"name": "Who the subject is, and who asked for them.",
}
const LABEL := {"body": "BODY", "place": "PLACE", "name": "NAME"}
const SOL := {"body": "trace", "place": "position", "name": "identity"}
const P25_STORY := [
	"The key turns. All three frames slide back into the wall together, like drawers into a desk.",
	"The strip types, slowly: NINTH OBSERVER LOCATED.",
	"Then: AUTOMATIC COUNTERSIGN AVAILABLE.",
	"It's offering to sign for me.",
	"The terminal lights. Through its grille, small and close, his voice.",
	"VENN: \"Don't let it sign for you.\"",
	"That was the last of him it had. The lamp stays on.",
	"Across the chamber, on the routing wall, a shutter rolls up.",
]
const CONSEQUENCES := "If I break it, they're gone, all of them, and I go home. If I stay, they're kept, whatever they are, and Venn can stop. Nobody comes back either way."
const P26_TAIL := [CONSEQUENCES, "Behind me, in the window, something moved."]
const SEVER_PREVIEW := ["PREVIEW. On the SEVER plate the eight subject lamps go out, one after another.",
	"The witness feed lamp goes out last. The outer-door shutter turns to OPEN.",
	"Then they all light again. It was only showing me. Behind me, the window is showing it too."]
const CONTINUE_PREVIEW := ["PREVIEW. On the CONTINUE plate the eight subject lamps stay lit.",
	"The witness feed slides along its rail, from the terminal marked E.V. to the one marked A.M.",
	"His lamp goes out. Mine comes on. Behind me, the window is showing it too."]
const BLINK_LINE := "Outside, the surface closes once, all the way, and opens. On me."
const EYE_DOOR := "The eye in the window isn't on the instrument. It's on the door I came in by."
const ARRIVAL_STORY := [
	"The chamber. A chair faces an instrument. Nothing in here is dusty.",
	"Every arm of the instrument ends where a part of a seated person would be. Head. Hands. Feet.",
	EYE_DOOR,
	"Through the left arch, a wall of frames. One of them already has a name on it.",
	"Mine.",
	"Outside, the surface closes once, all the way, and opens. On me.",
]
## Four tiers: where, the relationship, the evidence, the solution (frames: spelled per card).
const REF_HINTS := {
	"frames": ["The chamber wants a record of you.",
		"Your movements are a body record, your position is a place, your contract is your name. Route as the model showed.",
		"It's all in the notebook: the recorder's record of my last three moves, the ninth position on the station model, and who asked for me on my contract.",
		"Trace to BODY, position to PLACE, identity to NAME, switch to WITNESS, then ROUTE."],
	"routing": ["The routing plates, right of the chair. Each route has to be patched before its PREVIEW will run.",
		"Venn's three answers say where each line goes.",
		"In the listening room Venn said: 'If you break it, they end, every trace. If you don't, someone has to stay. Physically. Here.' In the vault the model said the witness has to be a person, and the person has to stay.",
		"For SEVER: FEED A, FEED B and E.V. into OPEN, then PREVIEW SEVER. For CONTINUE: E.V. into A.M. and A.M. into TERMINAL, then PREVIEW CONTINUE. Watch the window each time."],
	"decide": ["Both choices are ready. The chamber is waiting for your hands.",
		"The yoke goes across the feed contacts. The bridge goes in your terminal. Preview before you confirm.",
		"The window showed me: SEVER puts out the eight lamps and the bowls; CONTINUE moves the feed to A.M. and empties his coat.",
		"To leave: yoke on the contacts, preview, BREAK CONNECTION AND LEAVE. To stay: bridge in your terminal, preview, REMAIN AS WITNESS."],
	"finale": ["I've chosen. All that's left is to watch it happen.",
		"Nothing in the chamber wants my hands any more.",
		"The choice is made. The station is carrying it out.",
		"Stand still and watch it finish."],
}
const P25_ACTIONS := ["to_frames", "frame_body", "rack_trace", "f_body", "rack_position", "f_place",
	"rack_identity", "f_name", "switch", "route"]
## P26's patches, as the sim's patch actions and as the clicks that make them (a cord, a socket).
const PATCH_SEVER := ["patch:feed_a:open", "patch:feed_b:open", "patch:ev:open"]
const PATCH_CONTINUE := ["patch:ev:am", "patch:am:terminal"]
const CLICK_SEVER := ["cord_feed_a", "jack_open", "cord_feed_b", "jack_open", "cord_ev", "jack_open"]
const CLICK_CONTINUE := ["cord_ev", "jack_am", "cord_am", "jack_terminal"]
const PATCH_WRONG := "Not like that. He said what each one does."
var P26_ACTIONS: Array = ["back", "back", "to_routing", "plate_sever"] + PATCH_SEVER + ["preview_sever"] \
	+ PATCH_CONTINUE + ["preview_continue"]
const P27_SEVER := ["back", "contacts", "tray", "contacts", "preview", "btn_sever"]
const P27_CONTINUE := ["to_routing", "bridge_seat", "bridge_seat", "preview", "btn_continue"]

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	test_constants()
	test_arrival()
	test_p25_solution()
	test_p25_permutations()
	test_p25_refusals()
	test_p25_cards()
	test_p25_decoys()
	test_p25_wrong_cards()
	test_p25_only_true_cards()
	test_body_card()
	test_p25_after()
	test_p25_save_load()
	test_load_state()
	test_p26_gates()
	test_p26_both_previews()
	test_p26_patch()
	test_p26_previews()
	test_p26_checkpoint()
	test_eye_gaze()
	test_blinks()
	test_hold_breath()
	test_p27_gates()
	test_p27_fittings()
	test_p27_buttons()
	test_endings_sever_and_replay()
	test_seen_lines()
	test_bridge_net()
	test_ending_saves()
	test_ending_reload()
	test_ending_timings()
	test_use_item()
	test_answers()
	test_objectives_hints()
	test_reconcile()
	test_debug_jumps()
	test_back()
	test_chain_actions()
	if _view_ready():
		await view_checks(ROOM)
		await test_view_tables()
		await test_view_hooks()
		await test_view_arrival()
		await test_view_endings()
		await test_view_surface()
		await test_view_ending_sound()
		await test_view_continue_mark()
		await test_view_caption_desync()
		await test_view_eye()
		await test_view_window_preview()
		await test_view_hold_breath()
		await test_view_legibility()
		await test_view_rack_faces()
		await test_view_patch()
		await test_view_final()
		await test_view_sever_wall()
		await test_view_morning()
		await test_view_page_turns()
	else:
		print("SKIP: R12 view_checks: the R12 view does not yet declare rects for every sim hotspot (view team)")

# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
## The line_out fx of SEVER's first page: [id, delay], one per line_out sound.
func expect_outs() -> Array:
	return [["line_out_1", 3.0], ["line_out_2", 3.8], ["line_out_3", 4.9], ["line_out_4", 6.3],
		["line_out_5", 8.0], ["line_out_6", 10.1], ["line_out_7", 12.6], ["line_out_8", 16.2]]

func r12(g: GameSim) -> R12Sim:
	return g.room(ROOM) as R12Sim

## A started game in the chamber with only P24 set, the stored trace and the bridge from R10.
func fresh(bridge := true) -> GameSim:
	var g := with_flags(["P24"], ROOM)
	g.state.p05_trace = TRACE.duplicate()
	if bridge:
		g.give(BRIDGE)
	return g

func play(g: GameSim, actions: Array) -> Array:
	var ev: Array = []
	for a in actions:
		ev = g.dispatch(a)
	return ev

func p25_game() -> GameSim:
	var g := fresh()
	play(g, P25_ACTIONS)
	return g

## P26 done, standing in c_routing.
func p26_game() -> GameSim:
	var g := p25_game()
	play(g, P26_ACTIONS)
	return g

## P26 done, standing in c_final.
func final_game() -> GameSim:
	var g := p26_game()
	play(g, ["back", "contacts"])
	return g

func story(ev: Array) -> Array:
	var out := []
	for e in ev:
		if e.type == "say" and e.story:
			out.append(e.text)
	return out

func fx(ev: Array, id: String) -> Dictionary:
	for e in ev:
		if e.type == "fx" and e.get("id", "") == id:
			return e
	return {}

func fx_count(ev: Array, id: String) -> int:
	var n := 0
	for e in ev:
		if e.type == "fx" and e.get("id", "") == id:
			n += 1
	return n

func sfx_list(ev: Array) -> Array:
	var out := []
	for e in ev:
		if e.type == "sfx":
			out.append([e.id, _d(e.delay)])
	return out

## A delay to two places, as the nearest float to its literal (so 2.6 == 2.6).
static func _d(x: float) -> float:
	return float("%.2f" % x)

func flags_json(g: GameSim) -> String:
	return JSON.stringify(g.state.flags)

func roundtrip(g: GameSim) -> GameSim:
	var t := GameSim.new()
	t.load_settings(g.settings_dict())
	t.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	return t

func bridges(g: GameSim) -> int:
	return g.state.inventory.count(BRIDGE)

func sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b

## Places the cards: perm[i] goes into FRAME_IDS[i] ("" leaves it empty). Ends in c_frames.
func place(g: GameSim, perm: Array) -> void:
	play(g, ["to_frames", "frame_body"])
	for i in perm.size():
		if perm[i] != "":
			g.dispatch("rack_" + perm[i])
			g.dispatch("f_" + R12Sim.FRAME_IDS[i])

func _view_ready() -> bool:
	var m: Dictionary = load("res://game/rooms/R12/R12_view.gd").get_script_constant_map()
	var ids := []
	for h in m.get("HOTSPOTS", []):
		ids.append(h[0])
	for id in R12Sim.HOTSPOTS:
		if not id in ids:
			return false
	return true

# ---------------------------------------------------------------------------------------------
# constants and arrival
# ---------------------------------------------------------------------------------------------
func test_constants() -> void:
	check(R12Sim.ID == "R12" and R12Sim.TITLE == "Observation Chamber", "R12 id and title")
	check(R12Sim.LINE4_TURNED == R03Sim.LINE4_TURNED and R12Sim.LINE4_STILL == R03Sim.LINE4_STILL,
		"the fourth line is P05's, word for word")
	check(not R12Sim.new().get_script().get_script_constant_map().has("SKELETON"), "R12 is built (no SKELETON)")
	check(not GameSim.new().is_unbuilt(ROOM), "the core treats R12 as built")
	check(R12Sim.ITEMS.is_empty() and GameSim.new().item_defs()[BRIDGE].room == "R10",
		"the bridge is R10's item")
	check(R12Sim.EXITS == [["R11", "Stair", []]], "one way out, the stair")
	var r := fresh().room(ROOM)
	for v in ["frames", "routing", "c_frames", "c_routing", "c_final", "ending"]:
		check(r.is_closeup(v), "%s is a close-up for the core" % v)
	check(not r.is_closeup("room"), "the room is not a close-up")
	for id in R12Sim.OBSERVATIONS:
		check(R12Sim.OBSERVATIONS[id] != "", "observation %s has text" % id)

func test_arrival() -> void:
	var g := with_flags(["P04", "P24"], "R11")
	g.state.p05_trace = TRACE.duplicate()
	var ev := g.dispatch("go:R12")
	check(g.state.room == ROOM, "walked into the chamber")
	var st := story(ev)
	check(st.slice(0, 6) == ARRIVAL_STORY, "the arrival chain, the blink line last (%s)" % [st])
	var says_at := {}
	for e2 in ev:
		if e2.type == "say":
			says_at[e2.text] = _d(e2.delay)
	check(says_at.get(EYE_DOOR) == 5.0 and says_at.get("Every arm of the instrument ends where a part of a seated person would be. Head. Hands. Feet.") == 2.4,
		"the eye on the door, after the instrument line")
	check(says_at.get(BLINK_LINE) == 11.8 and says_at.get("Mine.") == 10.0, "the blink line at 11.8, after 'Mine.' at 10.0")
	check(says_at.get("The bridge is in my pocket. The door gave it back.") == 14.2, "the bridge line after the blink")
	var looks := _fxs(ev, "eye_look")
	check(looks.size() == 1 and looks[0].get("target") == "door" and looks[0].get("from") == "centre"
		and looks[0].get("line") == EYE_DOOR and _d(looks[0].get("delay")) == 5.0,
		"arrival: the eye turns to the door with its line (%s)" % [looks])
	check(r12(g).gaze() == "door" and r12(g).state.eye_look == "door", "arrival: the eye is on the door")
	check(fx_count(ev, "notice") == 1 and fx(ev, "notice").get("which") == "name_frame", "notice fx: the name frame")
	check(r12(g).has_seen("chamber"), "arrival notes the chamber")
	check(bridges(g) == 1 and "The bridge is in my pocket. The door gave it back." in says(ev),
		"the bridge net hands back a missing bridge on arrival")
	check(has_ev(ev, "fx", "item_added"), "the bridge arrives with item_added")
	g.dispatch("go:R11")
	ev = g.dispatch("go:R12")
	check(story(ev).is_empty() and fx_count(ev, "notice") == 0, "the arrival chain plays once")
	check(fx_count(ev, "eye_look") == 0 and r12(g).gaze() == "door", "re-arrival: the eye stays on the door")
	check(bridges(g) == 1 and not "door gave it back" in says(ev), "no second bridge on re-arrival")
	# Arrival with the bridge already in hand: no bridge line, chain without it.
	var h := with_flags(["P04", "P24"], "R11")
	h.give(BRIDGE)
	ev = h.dispatch("go:R12")
	check(story(ev) == ARRIVAL_STORY and bridges(h) == 1, "arrival with the bridge: just the chain")

# ---------------------------------------------------------------------------------------------
# P25
# ---------------------------------------------------------------------------------------------
func test_p25_solution() -> void:
	var g := fresh()
	var r := r12(g)
	var ev := g.dispatch("to_frames")
	check(r.local_view == "frames" and says(ev) == "The record wall.", "to the record wall")
	ev = g.dispatch("frame_body")
	check(r.local_view == "c_frames", "a frame opens c_frames")
	check(r.switch() == "copy", "the switch starts on COPY")
	check("WOULD FINALIZE OBSERVER" in says(ev), "the first c_frames line shows the copy preview (%s)" % says(ev))
	check(r.has_seen("frames_procedure"), "the procedure is noted")
	ev = g.dispatch("rack_trace")
	check(says(ev) == "A card in my name: 'Turned the zero wheel. Opened the hatch. Looked down the stair. Observer has not yet looked behind her.'",
		"the trace card reads the stored trace, whole, no category (%s)" % says(ev))
	check(r.held_card() == "trace" and has_ev(ev, "sfx", "card_lift"), "the trace card is in hand")
	ev = g.dispatch("f_body")
	check(says(ev) == "It clips into the BODY frame." and fx(ev, "card_seat").get("frame") == "body",
		"the trace clips into BODY")
	play(g, ["rack_position", "f_place", "rack_identity", "f_name"])
	check(not g.flag("P25"), "three cards on COPY: not yet")
	ev = g.dispatch("switch")
	check(says(ev) == "WITNESS. The strip goes blank." and r.strip_lines().is_empty(), "WITNESS blanks the strip")
	ev = g.dispatch("route")
	check(g.flag("P25") and r.state.p25_complete, "ROUTE solves P25")
	check(story(ev) == P25_STORY, "the P25 story lines (%s)" % [story(ev)])
	var delays := []
	for e in ev:
		if e.type == "say":
			delays.append(_d(e.delay))
	check(delays == [0.0, 2.6, 5.4, 7.6, 9.6, 11.8, 14.4, 16.4], "the P25 line timings (%s)" % [delays])
	check(sfx_list(ev) == [["route_key", 0.0], ["frames_slide", 0.5], ["strip_type", 2.6], ["strip_type", 5.4],
		["terminal_on", 9.4], ["venn_last", 11.6], ["shutters_open", 16.2]], "the P25 sounds (%s)" % [sfx_list(ev)])
	check(fx(ev, "strip_print").get("lines") == ["NINTH OBSERVER LOCATED.", "AUTOMATIC COUNTERSIGN AVAILABLE."]
		and fx(ev, "strip_print").get("delays") == [2.6, 5.4], "the strip prints the countersign offer")
	check(has_ev(ev, "fx", "frames_slide") and has_ev(ev, "fx", "terminal_lit"), "frames slide, terminal lights")
	check(not has_ev(ev, "fx", "tide") and not has_ev(ev, "fx", "glance"), "no tide card, no glance")
	check(r.has_seen("ninth_position") and r.has_seen("venn_last"), "the ninth position and Venn's last line are noted")
	check(r.strip_lines() == ["NINTH OBSERVER LOCATED.", "AUTOMATIC COUNTERSIGN AVAILABLE."], "the strip after P25")
	check(r.stage() == "s1", "stage s1 after P25")
	# At tide IX with everything before it behind her: still no tide card.
	var t := game_at(9, ROOM)
	ev = play(t, P25_ACTIONS)
	check(t.flag("P25") and not has_ev(ev, "fx", "tide") and t.tide() == 9, "P25 at tide IX: no tide card")

const PERMS := [["trace", "position", "identity"], ["trace", "identity", "position"],
	["position", "trace", "identity"], ["position", "identity", "trace"],
	["identity", "trace", "position"], ["identity", "position", "trace"]]

func test_p25_permutations() -> void:
	for perm in PERMS:
		for sw in ["copy", "witness"]:
			var g := fresh()
			var r := r12(g)
			place(g, perm)
			if sw == "witness":
				g.dispatch("switch")
			var before := flags_json(g)
			var ev := g.dispatch("route")
			var tag := "%s/%s" % [perm, sw]
			var solution: bool = perm == ["trace", "position", "identity"] and sw == "witness"
			check(g.flag("P25") == solution, "%s: P25 only for the solution on WITNESS" % tag)
			if solution:
				continue
			check(flags_json(g) == before and not r.state.p25_complete, "%s: a wrong ROUTE changes no flag" % tag)
			check(has_ev(ev, "sfx", "route_refuse"), "%s: the key refuses" % tag)
			if sw == "copy":
				check(says(ev) == COPY_REFUSAL + " | Not COPY. Not that.", "%s: the COPY refusal (%s)" % [tag, says(ev)])
				check(fx(ev, "strip_print").get("lines") == ["WOULD FINALIZE OBSERVER"], "%s: COPY prints" % tag)
				check(r.has_seen("copy_preview"), "%s: the copy preview is noted" % tag)
			else:
				var wrong := ""
				for f in ["body", "place", "name"]:
					if wrong == "" and r.frames()[f] != SOL[f]:
						wrong = f
				check(says(ev) == "ROUTE won't turn. The %s plate lights: '%s'" % [LABEL[wrong], CATEGORY[wrong]],
					"%s: the first wrong frame lights (%s)" % [tag, says(ev)])
				check(fx(ev, "frame_lamp").get("frame") == wrong and r.last_lamp_frame == wrong, "%s: frame lamp fx" % tag)
			check(r.frames() == {"body": perm[0], "place": perm[1], "name": perm[2]}, "%s: nothing is consumed" % tag)

func test_p25_refusals() -> void:
	# Empty frames: the first empty one is named, in BODY, PLACE, NAME order.
	for perm in [["", "", ""], ["trace", "", ""], ["trace", "position", ""], ["", "position", "identity"],
			["trace", "", "identity"]]:
		var g := fresh()
		place(g, perm)
		g.dispatch("switch")
		var before := flags_json(g)
		var ev := g.dispatch("route")
		var empty := ""
		for i in 3:
			if empty == "" and perm[i] == "":
				empty = R12Sim.FRAME_IDS[i]
		check(says(ev) == "ROUTE won't turn. The %s frame is empty." % LABEL[empty], "%s: names the %s frame (%s)" % [perm, empty, says(ev)])
		check(flags_json(g) == before and has_ev(ev, "sfx", "route_refuse"), "%s: refused, no flags" % [perm])
	# The empty check comes before the switch check.
	var c := fresh()
	place(c, ["trace", "position", ""])
	check(says(c.dispatch("route")) == "ROUTE won't turn. The NAME frame is empty.", "empty beats COPY")
	# Switching to COPY always prints the preview first.
	var s := fresh()
	var r := r12(s)
	place(s, ["", "", ""])
	s.dispatch("switch")
	var ev := s.dispatch("switch")
	check(r.switch() == "copy" and fx(ev, "strip_print").get("lines") == r.strip_lines()
		and r.strip_lines() == ["WOULD FINALIZE OBSERVER"], "switching to COPY prints its preview")
	check(says(ev) == "COPY. The strip types: WOULD FINALIZE OBSERVER." and has_ev(ev, "sfx", "switch_throw")
		and has_ev(ev, "sfx", "strip_type"), "the COPY line and sounds")
	check(says(s.dispatch("look_strip")) == "WOULD FINALIZE OBSERVER", "look_strip on COPY")
	s.dispatch("switch")
	check(says(s.dispatch("look_strip")) == "The strip is blank.", "look_strip on WITNESS")
	# Categories: an empty frame and the look controls say the plate, and note it.
	for f in ["body", "place", "name"]:
		check(says(s.dispatch("f_" + f)) == "%s. %s" % [LABEL[f], CATEGORY[f]], "empty %s frame says its plate" % f)
		check(says(s.dispatch("look_" + f)) == "%s. %s" % [LABEL[f], CATEGORY[f]], "look_%s says its plate" % f)
	check(r.has_seen("frame_categories"), "the plates are noted")

func test_p25_cards() -> void:
	var g := fresh()
	var r := r12(g)
	place(g, ["", "", ""])
	# First lifts say the card; later lifts say its header.
	var ev := g.dispatch("rack_position")
	check(says(ev) == "A card in my name: 'Ninth position. Centre of the station outline.'" and r.has_seen("card_position"), "position card")
	ev = g.dispatch("rack_position")
	check(says(ev) == "Back in the rack." and r.held_card() == "" and has_ev(ev, "sfx", "card_return"), "lift twice puts it back")
	check(says(g.dispatch("rack_position")) == "A card in my name: 'Ninth position. Centre of the station outline.'",
		"a second lift reads the card again")
	ev = g.dispatch("rack_identity")
	check(says(ev) == "A card in my name: 'Miss Ada Mercer, cataloguer. Requested by E. Venn.'" and r.held_card() == "identity",
		"lifting another card swaps it silently")
	# no lift line and no card header names a category
	for cid in R12Sim.CARD_IDS:
		var h := fresh()
		place(h, [])
		var line := says(h.dispatch("rack_" + cid))
		check(line.begins_with("A card in my name: '") and line.ends_with("'") and r12(h).card_header(cid) == "A. MERCER",
			"%s: the lift reads the face whole (%s)" % [cid, line])
		for cat in ["MOVEMENT", "POSITION", "CONTRACT"]:
			check(not cat in line and not cat in r12(h).card_header(cid), "%s: no %s header" % [cid, cat])
	check(r.card_in_rack("position") and not r.card_in_rack("identity"), "the swapped card is back in the rack")
	g.dispatch("f_name")
	check(says(g.dispatch("rack_identity")) == "That card's in a frame.", "a framed card stays framed")
	# Displacing a card.
	g.dispatch("rack_trace")
	ev = g.dispatch("f_name")
	check(says(ev) == "It clips into the NAME frame. The other card goes back to the rack.", "displacement line")
	check(r.frames().name == "trace" and r.card_in_rack("identity"), "the occupant returns to the rack")
	# Empty hand on a filled frame: back to the rack.
	ev = g.dispatch("f_name")
	check(says(ev) == "Back in the rack." and r.frames().name == "" and r.card_in_rack("trace"), "a filled frame empties")
	check(R12Sim.RACK_ORDER == ["position_b", "trace_a", "identity", "trace", "identity_b", "trace_b", "position"],
		"rack order, left to right: fixed, mixed, not true-first")
	check(r.card_header("trace") == "A. MERCER" and r.card_header("identity") == "A. MERCER", "card headers: her name only")
	check(r.card_text("position") == ["Ninth position. Centre of the station outline."], "position card text")
	check(r.card_text("trace") == r.body_card_lines(), "the trace card is the body card")
	check(not g.has_item("trace") and g.state.inventory == [BRIDGE], "the cards never enter the inventory")

## The decoy MOVEMENT runs: for every trace record_move can leave (consecutive duplicates
## collapsed, 1 to 8 events) over a sample of the whitelist, neither decoy repeats the trace or
## the other decoy; with three or more events each differs from it in the middle event only,
## never repeating a neighbour.
func test_p25_decoys() -> void:
	var sample := ["zero_turned", "hatch_opened", "stair_looked", "lamp_mended"]
	var seqs := [[]]
	var checked := 0
	var bad := []
	for length in range(1, 9):
		var next := []
		for q in seqs:
			for m in sample:
				if q.is_empty() or q.back() != m:
					var t: Array = q.duplicate()
					t.append(m)
					next.append(t)
		seqs = next
		for t in seqs:
			var d := R12Sim.decoys_for(t)
			checked += 1
			if d.size() != 2 or d[0] == t or d[1] == t or d[0] == d[1] or d[0].size() < 3 or d[1].size() < 3:
				bad.append(t)
			for run in d:
				for m in run:
					if not GameSim.MOVES.has(m):
						bad.append([t, m])
			if t.size() >= 3:
				for run in d:
					var diff := []
					for k in t.size():
						if run[k] != t[k]:
							diff.append(k)
					if diff != [1] or run[1] == run[0] or run[1] == run[2]:
						bad.append(["middle only", t, run])
	check(bad.is_empty() and checked > 3000, "decoys never repeat the trace (%d traces, bad %s)" % [checked, bad.slice(0, 3)])
	# the same through record_move and the real freeze, as play leaves it
	var g := fresh()
	g.state.p05_trace = []
	for m in ["lamp_mended", "lamp_mended", "zero_turned", "hatch_opened", "zero_turned"]:
		g.record_move(m)
	g.freeze_p05_trace()
	var tr: Array = g.value("p05_trace")
	var r := r12(g)
	check(tr == ["zero_turned", "hatch_opened", "zero_turned"], "the frozen trace (%s)" % [tr])
	check(r.movement_of("trace_a") == ["zero_turned", "held_still", "zero_turned"]
		and r.movement_of("trace_b") == ["zero_turned", "turned_round", "zero_turned"], "decoys: the middle event changed")
	var std := R12Sim.decoys_for(TRACE)
	check(std == [["zero_turned", "held_still", "stair_looked"], ["zero_turned", "turned_round", "stair_looked"]],
		"the usual trace's decoys differ only in the middle (%s)" % [std])
	for cid in ["trace_a", "trace_b"]:
		check(r.card_text(cid).back() == r.line4() and r.card_text(cid) != r.body_card_lines(),
			"%s prints its own run and the same fourth line" % cid)
	# short and empty traces take the fixed runs, which differ from the trace and each other
	for t in [[], ["zero_turned"], ["held_still", "turned_round"]]:
		var d := R12Sim.decoys_for(t)
		check(d == [R12Sim.DECOY_FALLBACK[0], R12Sim.DECOY_FALLBACK[1]], "short trace %s: the fixed runs" % [t])
	var d2 := R12Sim.decoys_for(R12Sim.DECOY_FALLBACK[0])
	check(not R12Sim.DECOY_FALLBACK[0] in d2 and d2[0] != d2[1], "a trace equal to a fixed run never meets itself")
	# the rack: seven cards, fixed slots, three categories, faces as specified
	check(R12Sim.CARD_IDS.size() == 7 and sorted(R12Sim.RACK_ORDER) == sorted(R12Sim.CARD_IDS), "seven cards, each in one slot")
	check(R12Sim.RACK_ORDER.find("trace") != 0 and R12Sim.RACK_ORDER.slice(0, 3) != ["trace", "position", "identity"],
		"the true cards are not first")
	check(r.card_text("position_b") == ["Ninth position. Seat beside the window."]
		and r.card_text("identity_b") == ["Miss Ada Mercer, cataloguer. Requested by the Board."], "decoy faces")
	var src: String = FileAccess.get_file_as_string("res://game/rooms/R12/R12_sim.gd")
	check(not "Eighth position" in src and not "Requested by S. Rook" in src, "no 'Eighth position' or 'S. Rook' card left anywhere")
	check(R12Sim.OBSERVATIONS.card_position_b == "A card in my name: 'Ninth position. Seat beside the window.'",
		"the decoy's notebook line quotes it")

	var rack_ids := []
	for c in R12Sim.FRAMES_CONTROLS:
		if c.begins_with("rack_"):
			rack_ids.append(c.substr(5))
	check(rack_ids == R12Sim.RACK_ORDER, "the rack controls follow the rack order")
	for cid in R12Sim.CARD_IDS:
		check(R12Sim.OBSERVATIONS.has("card_" + cid), "card_%s has a notebook line" % cid)

## A wrong card of the right category lights its frame's plate: DOES NOT CORRESPOND TO
## OBSERVER. It persists (and saves), nothing locks, and a wrong category still names its own.
func test_p25_wrong_cards() -> void:
	var lit := "DOES NOT CORRESPOND TO OBSERVER"
	for pair in [["trace_a", "body"], ["trace_b", "body"], ["position_b", "place"], ["identity_b", "name"]]:
		var g := fresh()
		var r := r12(g)
		place(g, [])
		g.dispatch("rack_" + pair[0])
		var ev := g.dispatch("f_" + pair[1])
		var f: String = pair[1]
		check(says(ev) == "It clips into the %s frame. The plate lights: %s." % [LABEL[f], lit],
			"%s in %s: the plate lights (%s)" % [pair[0], f, says(ev)])
		check(fx(ev, "plate_mismatch").get("frame") == f and has_ev(ev, "sfx", "frame_lamp"), "%s: plate fx and lamp" % pair[0])
		check(r.plate_mismatch(f) and r.has_seen("plate_mismatch"), "%s: the plate stays lit and is noted" % pair[0])
		var t := roundtrip(g)
		check(r12(t).frames()[f] == pair[0] and r12(t).plate_mismatch(f), "%s: the lit plate survives a save" % pair[0])
		check(JSON.stringify(t.to_dict()) == JSON.stringify(roundtrip(t).to_dict()), "%s: the save round-trips" % pair[0])
		# nothing locks: lift it back out, the plate goes dark
		g.dispatch("f_" + f)
		check(r.frames()[f] == "" and not r.plate_mismatch(f) and r.card_in_rack(pair[0]), "%s: it comes back out" % pair[0])
	# ROUTE with a lit plate refuses and says so; the true card then clears it.
	var h := fresh()
	var q := r12(h)
	place(h, ["trace_b", "position", "identity"])
	h.dispatch("switch")
	var before := flags_json(h)
	var ev := h.dispatch("route")
	check(says(ev) == "ROUTE won't turn. The BODY plate reads: %s." % lit and flags_json(h) == before
		and has_ev(ev, "sfx", "route_refuse"), "ROUTE refuses a lit plate (%s)" % says(ev))
	play(h, ["rack_trace", "f_body"])
	check(not q.plate_mismatch("body"), "the true card puts the plate out")
	play(h, ["route"])
	check(h.flag("P25"), "then P25")
	# A wrong category names its category, as before.
	var w := fresh()
	place(w, ["position_b", "trace", "identity"])
	w.dispatch("switch")
	check(says(w.dispatch("route")) == "ROUTE won't turn. The BODY plate lights: '%s'" % CATEGORY.body
		and not r12(w).plate_mismatch("body"), "a wrong category names its category")
	# Load validation: unknown ids drop, decoy ids load, one card per frame.
	var v := fresh()
	var rv := r12(v)
	rv.load_state({"frames": {"body": "trace_a", "place": "identity_b", "name": "trace_c"}})
	check(rv.frames() == {"body": "trace_a", "place": "identity_b", "name": ""}, "load keeps known cards only (%s)" % [rv.frames()])
	check(rv.plate_mismatch("body") and not rv.plate_mismatch("place"), "a loaded wrong-category card is not lit")

## P25 commits only with the three true cards, in their frames, on WITNESS (every placement of
## any three of the seven cards).
func test_p25_only_true_cards() -> void:
	var g0 := fresh()
	var base := g0.to_dict()
	var wrong_solved := []
	var solved := 0
	for a in R12Sim.CARD_IDS:
		for b in R12Sim.CARD_IDS:
			for c in R12Sim.CARD_IDS:
				if a == b or b == c or a == c:
					continue
				var g := GameSim.new()
				g.from_dict(base)
				place(g, [a, b, c])
				g.dispatch("switch")
				g.dispatch("route")
				if g.flag("P25"):
					if [a, b, c] == ["trace", "position", "identity"]:
						solved += 1
					else:
						wrong_solved.append([a, b, c])
	check(solved == 1 and wrong_solved.is_empty(), "only the true cards route (%d, %s)" % [solved, wrong_solved])

func test_body_card() -> void:
	for turned in [false, true]:
		# At tide IX R02's threshold is behind her, so its `turned` (which owns the flag) holds on a load.
		var g := game_at(9, ROOM)
		g.state.p05_trace = TRACE.duplicate()
		g.room("R02").state.turned = turned
		g.set_flag("t1x_turned", turned)
		var r := r12(g)
		var line4 := R03Sim.LINE4_TURNED if turned else R03Sim.LINE4_STILL
		var expect := ["Turned the zero wheel.", "Opened the hatch.", "Looked down the stair.", line4]
		check(r.body_card_lines() == expect, "body card lines (turned %s): %s" % [turned, r.body_card_lines()])
		check(r.line4() == line4, "line4 follows t1x_turned")
		g.record_move("lamp_mended")
		check(r.body_card_lines() == expect, "the stored trace, not recomputed from new moves")
		var t := roundtrip(g)
		check(r12(t).body_card_lines() == expect, "the body card survives a save (turned %s)" % turned)
	var h := fresh()
	h.set_flag("t1x_turned")
	place(h, [])
	check(says(h.dispatch("rack_trace")).ends_with(" Observer has looked behind her once.'"), "the turned fourth line on the card")

func test_p25_after() -> void:
	var g := p25_game()
	var r := r12(g)
	var nb: int = g.state.notebook.size()
	var ev := g.dispatch("route")
	check(says(ev) == READ_ONLY and ev.size() == 1, "a repeat ROUTE is the read-only line and nothing else")
	check(g.state.notebook.size() == nb, "no new observations from a repeat")
	for c in R12Sim.FRAMES_CONTROLS:
		var before := JSON.stringify(r.state)
		ev = g.dispatch(c)
		check(says(ev) == READ_ONLY and JSON.stringify(r.state) == before, "after P25, %s is read-only" % c)
	play(g, ["back"])
	check(says(g.dispatch("frame_body")) == READ_ONLY and r.local_view == "c_frames", "the frames read-only on re-entry")
	g.dispatch("back")
	check(says(g.dispatch("terminal")) == "Lit. The strip still says it: AUTOMATIC COUNTERSIGN AVAILABLE.", "terminal after P25")

func test_p25_save_load() -> void:
	var g := fresh()
	place(g, ["trace", "position", ""])
	g.dispatch("switch")
	g.dispatch("rack_identity")
	check(r12(g).held_card() == "identity", "a card in hand before the save")
	var t := roundtrip(g)
	var r := r12(t)
	check(r.frames() == {"body": "trace", "place": "position", "name": ""}, "the frames survive a save")
	check(r.switch() == "witness", "the switch survives a save")
	check(r.held_card() == "" and r.card_in_rack("identity"), "the held card drops back to the rack")
	check(r.local_view == "room" and t.view == "room" and t.state.room == ROOM, "a load lands in the room")
	check(JSON.stringify(t.to_dict()) == JSON.stringify(roundtrip(t).to_dict()), "the mid-puzzle save round-trips")
	play(t, ["frame_body", "rack_identity", "f_name", "route"])
	check(t.flag("P25"), "the loaded puzzle completes")

func test_load_state() -> void:
	var g := fresh()
	var r := r12(g)
	r.load_state({"frames": {"body": "trace", "place": "trace", "name": "bogus"}, "switch": "sideways",
		"previewed": ["sever", "sever", "x"], "blinks": ["located", "located", "x"],
		"window_looks": 3.5, "armature_looks": 500, "noticed": ["arrival", "x"], "opened": ["c_frames", "c_x"],
		"yoke": "contacts", "final_preview": "sever", "chosen": "sever", "ending_step": 4, "bridge_seated": true})
	check(r.frames() == {"body": "trace", "place": "", "name": ""}, "duplicate and unknown cards are dropped (%s)" % [r.frames()])
	check(r.switch() == "copy", "an unknown switch position is dropped")
	check(r.blinks() == ["located", "arrival"], "blinks: known, once; a noticed arrival has blinked (%s)" % [r.blinks()])
	check(r.state.previewed == ["sever"], "previewed: known, once")
	check(r.state.window_looks == 0 and r.state.armature_looks == 99, "looks: whole, clamped")
	check(r.state.noticed == ["arrival"] and r.state.opened == ["c_frames"], "known ids only")
	check(r.yoke() == "tray" and not r.bridge_seated() and r.final_preview() == "", "no P26: nothing fitted")
	check(r.chosen() == "" and r.ending_step() == 0 and not r.state.p27_complete, "no P27 without P26")
	r.load_state({"p25_complete": true, "frames": {"body": "identity"}, "switch": "copy"})
	check(r.frames() == R12Sim.SOLUTION_FRAMES and r.switch() == "witness", "p25_complete forces the solution")
	r.load_state({"p26_complete": true})
	check(not r.state.p26_complete, "P26 needs P25")
	r.load_state({"p25_complete": true, "p26_complete": true, "previewed": []})
	check(r.state.previewed == ["sever", "continue"] and "located" in r.blinks(), "p26_complete forces both previews; P25 spent its blink")
	r.load_state({"p25_complete": true, "p26_complete": true, "p27_complete": true, "chosen": "", "ending_step": 3})
	check(not r.state.p27_complete and r.ending_step() == 0, "P27 needs a choice")
	r.load_state({"p25_complete": true, "p26_complete": true, "p27_complete": true, "chosen": "continue", "ending_step": 40})
	check(r.chosen() == "continue" and r.ending_step() == 10, "ending_step clamps to the choice's steps")
	r.load_state({"p25_complete": true, "p26_complete": true, "yoke": "contacts", "final_preview": "continue"})
	check(r.final_preview() == "", "a preview that doesn't match the fittings is dropped")
	r.load_state("junk")
	check(JSON.stringify(r.state) == JSON.stringify(r.initial_state()), "junk loads fresh")

# ---------------------------------------------------------------------------------------------
# P26
# ---------------------------------------------------------------------------------------------
func test_p26_gates() -> void:
	var g := fresh()
	var r := r12(g)
	g.dispatch("to_routing")
	var lines := {
		"plate_sever": "Two plates behind brass shutters: SEVER and CONTINUE. The shutters are locked. A tag: ROUTE A RECORD FIRST.",
		"plate_continue": "Two plates behind brass shutters: SEVER and CONTINUE. The shutters are locked. A tag: ROUTE A RECORD FIRST.",
		"cards": "A holder for four cards, behind the same shutter. All four places are empty.",
		"handle": "The severance handle, locked in its housing.",
		"yoke_tray": "A tray with a severance yoke in it: a heavy insulated bar. It's on the chamber's inventory, in his hand.",
		"contacts": "Two feed contacts, labelled FEED A and FEED B.",
		"bridge_seat": "My terminal. A. MERCER · WITNESS. There's a seat in it the shape of the bridge from the model.",
	}
	for h in lines:
		check(says(g.dispatch(h)) == lines[h] and r.local_view == "routing", "before P25, %s stays on the wall" % h)
	for o in ["routing_plates", "yoke", "feed_contacts", "ada_terminal"]:
		check(r.has_seen(o), "before P25, %s is noted" % o)
	for c in R12Sim.ROUTING_CONTROLS:
		g.dispatch(c)
	check(r.state.previewed.is_empty() and r.local_view == "routing", "routing controls do nothing before P25")
	# After P25: the plates open; the final hardware waits.
	var p := p25_game()
	var q := r12(p)
	play(p, ["back", "back", "to_routing"])
	check(says(p.dispatch("plate_continue")) == "Two plates, SEVER and CONTINUE, each with a PREVIEW key. Under them a patch field: four cords, FEED A, FEED B, E.V. and A.M., and three sockets. It wants each route wired before it will show me."
		and q.local_view == "c_routing" and q.has_seen("patch_field"), "first c_routing entry")
	p.dispatch("back")
	check(says(p.dispatch("cards")) == "The routing plates." and q.local_view == "c_routing", "later entries")
	p.dispatch("back")
	for h in ["handle", "yoke_tray", "contacts", "bridge_seat"]:
		check(says(p.dispatch(h)) == LATER and q.local_view == "routing", "after P25, %s waits for P26" % h)

func _routing_game() -> GameSim:
	var g := p25_game()
	play(g, ["back", "back", "to_routing", "plate_sever"])
	return g

## The patch a route's preview runs on.
func _patch_for(preview: String) -> Array:
	return PATCH_SEVER if preview == "preview_sever" else PATCH_CONTINUE

## P26 completes when both routes have been rehearsed on a correct patch, in either order, and
## only then: a repeated preview of one route never does; the looks never do.
func test_p26_both_previews() -> void:
	check(R12Sim.ROUTING_CONTROLS == ["look_sever", "look_continue", "preview_sever", "preview_continue",
		"cord_feed_a", "cord_feed_b", "cord_ev", "cord_am", "jack_open", "jack_am", "jack_terminal"],
		"c_routing: two looks, two PREVIEW keys and the patch field; no cards, no CONFIRM")
	for order in [["preview_sever", "preview_continue"], ["preview_continue", "preview_sever"]]:
		var g := _routing_game()
		var r := r12(g)
		play(g, _patch_for(order[0]))
		var ev := g.dispatch(order[0])
		check(not g.flag("P26") and not r.state.p26_complete and g.checkpoint.is_empty(), "%s alone: not yet" % order[0])
		ev = g.dispatch(order[0])
		check(not g.flag("P26") and g.checkpoint.is_empty(), "%s twice: still not" % order[0])
		for c in ["look_sever", "look_continue"]:
			g.dispatch(c)
		check(not g.flag("P26"), "%s + looks: still not" % order[0])
		# the second route on the first route's patch: refused, nothing previewed
		var before := flags_json(g)
		ev = g.dispatch(order[1])
		check(not g.flag("P26") and says(ev) == PATCH_WRONG and flags_json(g) == before, "%s on the wrong patch: refused" % order[1])
		play(g, _patch_for(order[1]))
		ev = g.dispatch(order[1])
		check(g.flag("P26") and r.state.p26_complete and r.stage() == "s2" and flags_json(g) != before,
			"%s then %s: P26" % order)
		var st := story(ev)
		check(st.slice(st.size() - 2) == P26_TAIL, "%s: then she says the consequences (%s)" % [order[1], st])
		check(r.has_seen("consequences") and r.has_seen("surface_withdrew"), "%s: consequences noted" % order[1])
		check(has_ev(ev, "fx", "surface_withdraw") and not has_ev(ev, "fx", "tide"), "%s: the surface withdraws, no tide card" % order[1])
		check(not g.checkpoint.is_empty(), "%s: the checkpoint" % order[1])
		var t := roundtrip(g)
		check(t.flag("P26") and r12(t).state.previewed.size() == 2, "%s: P26 survives a save" % order[1])
	# the consequences line is the notebook's, word for word
	check(R12Sim.OBSERVATIONS.consequences == CONSEQUENCES, "the said line is the notebook line")
	# a save between the two previews keeps the first
	var h := _routing_game()
	play(h, PATCH_CONTINUE + ["preview_continue"])
	var q := roundtrip(h)
	check(r12(q).patch() == r12(h).patch() and r12(q).previewed("continue"), "the patch and the rehearsal survive a save")
	play(q, ["back", "back", "to_routing", "plate_sever"] + PATCH_SEVER)
	q.dispatch("preview_sever")
	check(q.flag("P26"), "one preview, a save, the other: P26")

## The patch field: cords lifted and dropped in sockets (patch:<cord>:<socket>); a PREVIEW only
## runs on its route's patch, else ROUTE INCOMPLETE and nothing is consumed or previewed; the
## patch saves, and a bad saved patch is put right on load.
func test_p26_patch() -> void:
	var g := _routing_game()
	var r := r12(g)
	check(r.patch() == {"feed_a": "home", "feed_b": "home", "ev": "home", "am": "home"}, "every cord in its own line")
	# a wrong patch on each route: the plate lights, she says so, nothing runs or changes
	for pv in ["preview_sever", "preview_continue"]:
		var route: String = pv.substr(8)
		var before := JSON.stringify(g.to_dict())
		var ev := g.dispatch(pv)
		check(says(ev) == PATCH_WRONG and r.incomplete_route == route, "%s unpatched: ROUTE INCOMPLETE (%s)" % [pv, says(ev)])
		check(fx(ev, "route_incomplete").get("route") == route and not has_ev(ev, "fx", "preview")
			and not has_ev(ev, "fx", "window_preview") and not has_ev(ev, "fx", "glance") and not has_ev(ev, "fx", "eye_look"),
			"%s unpatched: nothing previewed, no glance" % pv)
		check(story(ev).is_empty() and not r.previewed(route) and g.checkpoint.is_empty(), "%s unpatched: not rehearsed" % pv)
		check(JSON.stringify(g.to_dict().flags) == JSON.stringify(JSON.parse_string(before).flags)
			and g.state.inventory == [BRIDGE], "%s unpatched: nothing consumed" % pv)
	check(r.has_seen("route_incomplete"), "the refusal is noted")
	# half a patch is still wrong
	play(g, ["patch:feed_a:open", "patch:feed_b:open"])
	check(r.incomplete_route == "" and says(g.dispatch("preview_sever")) == PATCH_WRONG, "SEVER without E.V. in OPEN")
	play(g, ["patch:ev:open"])
	check(r.patch_matches("sever") and not r.patch_matches("continue"), "the SEVER patch")
	var ev := g.dispatch("preview_sever")
	check(r.previewed("sever") and has_ev(ev, "fx", "window_preview") and fx(ev, "glance").get("target") == "window_sever"
		and r.incomplete_route == "", "the SEVER patch rehearses SEVER and shows it in the window")
	# CONTINUE needs E.V. into A.M. and A.M. into TERMINAL; the feeds may stay where they are
	play(g, ["patch:ev:am"])
	check(says(g.dispatch("preview_continue")) == PATCH_WRONG and not r.previewed("continue"), "A.M. not yet in TERMINAL")
	play(g, ["patch:am:terminal"])
	ev = g.dispatch("preview_continue")
	check(g.flag("P26") and not g.checkpoint.is_empty(), "both rehearsed on a correct patch: P26 and the checkpoint")
	check(JSON.parse_string(JSON.stringify(g.checkpoint)).rooms.R12.patch == r.patch(), "the checkpoint keeps the patch")
	# the clicks: lift a cord at its contact, drop it in a socket
	var c := _routing_game()
	var q := r12(c)
	ev = c.dispatch("cord_feed_a")
	check(q.held_cord() == "feed_a" and says(ev) == "The FEED A cord. Its plug was in its own line." and has_ev(ev, "sfx", "cc_lift"),
		"lift the FEED A cord")
	ev = c.dispatch("jack_open")
	check(q.held_cord() == "" and q.patch_of("feed_a") == "open" and says(ev) == "FEED A into OPEN."
		and fx(ev, "patch").get("cord") == "feed_a" and fx(ev, "patch").get("jack") == "open", "drop it in OPEN")
	check(says(c.dispatch("jack_open")) == "OPEN. In it: FEED A." and says(c.dispatch("jack_am")) == "A.M. Nothing in it.",
		"a socket says what is in it")
	var dd := _routing_game()
	dd.dispatch("cord_ev")
	check(says(dd.dispatch("jack_am")) == "E.V. into A.M." and says(dd.dispatch("cord_ev")) == "The E.V. cord. Its plug was in A.M.",
		"labels ending in a stop are not doubled")
	play(c, ["cord_feed_a"])
	check(says(c.dispatch("cord_feed_a")) == "FEED A back in its own line." and q.patch_of("feed_a") == "home",
		"its own contact again puts it home")
	play(c, ["cord_ev", "cord_am"])
	check(q.held_cord() == "am", "another cord swaps what is in hand")
	check(says(c.dispatch("jack_am")) == "Not into itself." and q.patch_of("am") == "home" and q.held_cord() == "",
		"A.M. never into itself")
	play(c, CLICK_SEVER + ["preview_sever"] + CLICK_CONTINUE + ["preview_continue"])
	check(c.flag("P26"), "P26 by clicks alone")
	# a wrong patch's lit plate goes out with the next change; Back drops a cord in hand
	var w := _routing_game()
	play(w, ["preview_sever", "patch:feed_a:open"])
	check(r12(w).incomplete_route == "", "a change puts ROUTE INCOMPLETE out")
	play(w, ["cord_ev", "back"])
	check(r12(w).held_cord() == "" and r12(w).patch_of("ev") == "home", "Back puts the cord down where it was")
	# saved and validated
	var s := _routing_game()
	play(s, ["patch:feed_b:terminal", "patch:ev:am"])
	var t := roundtrip(s)
	check(r12(t).patch() == {"feed_a": "home", "feed_b": "terminal", "ev": "am", "am": "home"}, "the patch saves")
	check(JSON.stringify(t.to_dict()) == JSON.stringify(roundtrip(t).to_dict()), "a mid-patch save round-trips")
	var d: Dictionary = r12(s).state.duplicate(true)
	d.patch = {"feed_a": "nowhere", "feed_b": 7, "ev": "open", "am": "am", "x": "open"}
	r12(t).load_state(d)
	check(r12(t).patch() == {"feed_a": "home", "feed_b": "home", "ev": "open", "am": "home"},
		"unknown sockets, A.M. into itself and unknown cords are put right (%s)" % [r12(t).patch()])
	d.erase("patch")
	r12(t).load_state(d)
	check(r12(t).patch() == {"feed_a": "home", "feed_b": "home", "ev": "home", "am": "home"}, "an old save: every cord home")
	# patches only answer in c_routing, after P25
	var e := fresh()
	play(e, ["to_routing", "patch:ev:am"])
	check(r12(e).patch_of("ev") == "home", "no patching on the shuttered wall")

func test_p26_previews() -> void:
	var g := _routing_game()
	var r := r12(g)
	play(g, PATCH_SEVER)
	var ev := g.dispatch("preview_sever")
	check(story(ev) == SEVER_PREVIEW, "first SEVER preview (%s)" % [story(ev)])
	check(sfx_list(ev) == [["preview_key", 0.0], ["preview_out", 0.3]] and fx(ev, "preview").get("route") == "sever", "SEVER preview sounds/fx")
	check(fx(ev, "window_preview").get("route") == "sever", "the window shows the SEVER preview")
	var gl := fx(ev, "glance")
	check(gl.get("rect") == [474, 96, 500, 290] and gl.get("target") == "window_sever", "the glance goes to the window (SEVER)")
	check(r.has_seen("preview_sever") and r.previewed("sever"), "SEVER previewed and noted")
	ev = g.dispatch("preview_sever")
	check(says(ev) == "The eight go out. The feed goes out. The door opens. Every time." and story(ev).is_empty(), "repeat SEVER preview")
	check(fx(ev, "glance").get("target") == "window_sever", "a repeat preview shows in the window again")
	check(r.state.previewed == ["sever"], "previewed once")
	play(g, PATCH_CONTINUE)
	ev = g.dispatch("preview_continue")
	check(story(ev).slice(0, 3) == CONTINUE_PREVIEW, "first CONTINUE preview")
	check(sfx_list(ev).slice(0, 2) == [["preview_key", 0.0], ["preview_move", 0.3]] and fx(ev, "preview").get("route") == "continue", "CONTINUE preview sounds/fx")
	check(fx(ev, "window_preview").get("route") == "continue" and fx(ev, "glance").get("target") == "window_continue",
		"the window shows the CONTINUE preview")
	check(says(g.dispatch("preview_continue")) == "The eight stay lit. His lamp out, mine on.", "repeat CONTINUE preview")
	check(says(g.dispatch("preview_sever")) == PATCH_WRONG, "after P26 a preview still needs its patch")
	check(says(g.dispatch("look_sever")) == "SEVER. Subject lines one to eight, the witness feed, the outer door. Each with a lamp.", "look_sever")
	check(says(g.dispatch("look_continue")) == "CONTINUE. Subject lines one to eight, the witness feed from E.V. to A.M., the outer door.", "look_continue")

func test_p26_checkpoint() -> void:
	var g := _routing_game()
	var r := r12(g)
	play(g, PATCH_SEVER + ["preview_sever"] + PATCH_CONTINUE)
	check(g.checkpoint.is_empty(), "no checkpoint before P26")
	var ev := g.dispatch("preview_continue")

	check(g.flag("P26") and r.state.p26_complete and r.stage() == "s2", "the second preview solves P26")
	check(story(ev) == CONTINUE_PREVIEW + P26_TAIL, "the P26 story lines (%s)" % [story(ev)])
	check(sfx_list(ev) == [["preview_key", 0.0], ["preview_move", 0.3], ["surface_withdraw", 11.2]], "the P26 sounds (%s)" % [sfx_list(ev)])
	var says_at := {}
	for e in ev:
		if e.type == "say":
			says_at[e.text] = _d(e.delay)
	check(says_at.get(CONSEQUENCES) == 8.4, "the consequences after the preview lines")
	check(not g.checkpoint.is_empty(), "the checkpoint is written")
	var snap := JSON.stringify(g.checkpoint)
	check(JSON.stringify(g.to_dict()) == snap, "the checkpoint is the state after the commit")
	for c in ["preview_sever", "preview_continue", "look_sever", "look_continue"]:
		check(says(g.dispatch(c)) != "" and g.flag("P26"), "after P26, %s still answers" % c)
	check(JSON.stringify(g.checkpoint) == snap, "a later preview keeps the checkpoint")
	play(g, ["back", "plate_sever"])
	check(says(g.dispatch("plate_sever")) == SEALED or r.local_view == "c_routing", "re-entering c_routing")
	play(g, ["back", "back", "window", "pressure"])
	check(JSON.stringify(g.checkpoint) == snap, "the checkpoint is written exactly once")
	# The checkpoint loads into the decision.
	var t := GameSim.new()
	check(t.from_dict(JSON.parse_string(snap)), "the checkpoint loads")
	var q := r12(t)
	check(t.state.room == ROOM and t.view == "room" and q.local_view == "room", "into the chamber, room view")
	check(t.flag("P26") and not t.flag("P27") and t.state.ending == "" and t.has_item(BRIDGE), "P26 set, P27 not, the bridge in hand")
	check(q.objective() == "decide", "the checkpoint stands at the decision")
	var a := GameSim.new()
	a.from_dict(JSON.parse_string(snap))
	play(a, ["to_routing", "contacts", "tray", "contacts", "preview", "btn_sever"])
	check(a.flag("P27") and r12(a).chosen() == "sever", "SEVER completes from the checkpoint")
	var b := GameSim.new()
	b.from_dict(JSON.parse_string(snap))
	play(b, P27_CONTINUE)
	check(b.flag("P27") and r12(b).chosen() == "continue", "CONTINUE completes from the checkpoint")

# ---------------------------------------------------------------------------------------------
# the eye: gaze, blinks, held breaths
# ---------------------------------------------------------------------------------------------
## The eye looks where its last eye_look sent it (state.eye_look): centred before she comes in,
## the door on arrival, the chair at the P25 commit, the routing wall at each P26 preview. gaze()
## is a pure function of state, so a load puts it back exactly; flags alone floor it.
func test_eye_gaze() -> void:
	check(R12Sim.PUPIL_OFFSET == {"centre": [0, 0], "door": [0, 40], "chair": [-150, 12], "routing": [95, 40],
		"final": [0, 60]}, "the five offsets: routing low enough to clear the conduit, final down at the switches")
	check(R12Sim.LOOK_ORDER == ["centre", "door", "chair", "routing", "final"], "the looks, in order")
	var g := _stair()
	var r := r12(g)
	check(r.gaze() == "centre" and r.pupil_offset() == Vector2.ZERO, "before she comes in: centred")
	g.dispatch("go:R12")
	check(r.gaze() == "door" and r.pupil_offset() == Vector2(0, 40), "arrival: the door")
	check(r12(roundtrip(g)).gaze() == "door", "the door survives a save")
	var ev := []
	for a in P25_ACTIONS:
		ev = g.dispatch(a)
	var looks := _fxs(ev, "eye_look")
	check(looks.size() == 1 and looks[0].get("target") == "chair" and looks[0].get("from") == "door",
		"P25 commit: eye_look chair (%s)" % [looks])
	check(r.gaze() == "chair" and r.pupil_offset() == Vector2(-150, 12), "P25: toward the chair")
	check(r12(roundtrip(g)).gaze() == "chair", "the chair survives a save")
	# the refused routes before it never turn it
	var h := _stair()
	h.dispatch("go:R12")
	var refused := 0
	for a in ["to_frames", "frame_body", "route", "rack_trace", "f_body", "route", "switch", "route"]:
		refused += _fxs(h.dispatch(a), "eye_look").size()
	check(refused == 0 and r12(h).gaze() == "door", "a refused ROUTE doesn't turn the eye")
	# P26: each preview, routing
	var pv := []
	for a in P26_ACTIONS:
		var e2 := g.dispatch(a)
		for x in _fxs(e2, "eye_look"):
			pv.append(x.get("target"))
		if a == "preview_sever":
			check(r.gaze() == "routing" and r12(roundtrip(g)).gaze() == "routing", "the first preview: routing, saved")
	check(pv == ["routing", "routing"], "P26: eye_look routing on each preview (%s)" % [pv])
	check(r.pupil_offset() == Vector2(95, 40), "P26: toward the routing wall")
	pv = []
	play(g, ["back", "back", "to_routing", "plate_sever"])
	for x in _fxs(g.dispatch("preview_continue"), "eye_look"):
		pv.append(x.get("target"))
	check(pv == ["routing"], "a preview again: routing again")
	# the final panel: the eye looks down at the switches, once, and stays there for a save
	play(g, ["back", "back", "to_routing"])
	var fl := _fxs(g.dispatch("handle"), "eye_look")
	check(r.local_view == "c_final" and fl.size() == 1 and fl[0].get("target") == "final" and fl[0].get("from") == "routing"
		and r.gaze() == "final" and r.pupil_offset() == Vector2(0, 60), "c_final: the eye looks down at the switches (%s)" % [fl])
	check(_fxs(g.dispatch("bridge_seat"), "eye_look").is_empty(), "inside c_final it stays put")
	check(r.bridge_seated() and r.gaze() == "final" and r12(roundtrip(g)).gaze() == "final", "the bridge seated: still the switches, saved")
	play(g, ["bridge_seat"])
	# a load: gaze() is what was saved, validated
	var t := roundtrip(g)
	check(r12(t).gaze() == r.gaze() and r12(t).pupil_offset() == r.pupil_offset(), "gaze() after a load matches")
	var d: Dictionary = r12(g).state.duplicate(true)
	for bad in [7, "sideways", null]:
		d.eye_look = bad
		r12(t).load_state(d)
		check(r12(t).gaze() == "routing", "a bad eye_look (%s) floors to where she has got" % [bad])
	d.eye_look = "terminal"
	r12(t).load_state(d)
	check(r12(t).gaze() == "routing", "'terminal' is read as 'routing'")
	d.eye_look = "final"
	r12(t).load_state(d)
	check(r12(t).gaze() == "final", "'final' loads as itself")
	var e := fresh()
	var de: Dictionary = r12(e).state.duplicate(true)
	de.eye_look = "chair"
	r12(e).load_state(de)
	check(r12(e).gaze() == "chair", "a saved look ahead of the floor is kept")
	# by flags alone, no actions
	var f := with_flags(["P24", "P25"], ROOM)
	r12(f).reconcile()
	check(r12(f).gaze() == "chair", "P25 by flag: the chair")
	for n in [0, 1, 2, 3, 4, 6]:
		var j := _jumped(n)
		var want := "centre" if n == 0 else ("routing" if n >= 2 else "chair")
		check(r12(j).gaze() == want, "jump %d: %s (%s)" % [n, want, r12(j).gaze()])
		check(r12(roundtrip(j)).gaze() == want, "jump %d: the gaze survives a save" % n)
	check(_jumped(1).room(ROOM).gaze() == "chair" and _jumped(2).room(ROOM).gaze() == "routing", "jumps 1, 2: chair, routing")

## The surface blinks exactly twice in a game: on the first arrival (with the line after
## 'Mine.') and when the strip types NINTH OBSERVER LOCATED. Never again, saved.
func test_blinks() -> void:
	var g := _stair()
	var r := r12(g)
	var blinks := []
	var ev := g.dispatch("go:R12")
	blinks.append_array(_fxs(ev, "blink"))
	check(blinks.size() == 1 and blinks[0].get("which") == "arrival" and _d(blinks[0].get("delay")) == 11.8
		and blinks[0].get("line") == BLINK_LINE, "the arrival blink, timed to its line (%s)" % [blinks])
	check(r.blinks() == ["arrival"] and r.has_seen("surface_blink"), "the arrival blink is spent and noted")
	# reload, leave, come back: no second arrival blink
	var t := roundtrip(g)
	var tr := r12(t)
	var after := []
	for a in ["go:R11", "go:R12", "window", "window", "window", "go:R11", "go:R12"]:
		after.append_array(_fxs(t.dispatch(a), "blink"))
	check(after.is_empty() and tr.blinks() == ["arrival"], "after a reload, no arrival blink again")
	# P25: the located blink, once
	var p25 := []
	for a in P25_ACTIONS:
		p25.append_array(_fxs(t.dispatch(a), "blink"))
	check(p25.size() == 1 and p25[0].get("which") == "located" and _d(p25[0].get("delay")) == 2.6
		and p25[0].get("line") == "The strip types, slowly: NINTH OBSERVER LOCATED.", "the located blink (%s)" % [p25])
	# the rest of the game: never again, through both endings and a reload
	var rest := []
	for a in P26_ACTIONS + P27_SEVER:
		rest.append_array(_fxs(t.dispatch(a), "blink"))
	var u := roundtrip(t)
	for i in 13:
		rest.append_array(_fxs(u.dispatch("ending_next"), "blink"))
	rest.append_array(_fxs(u.dispatch("return_decision"), "blink"))
	for a in P27_CONTINUE:
		rest.append_array(_fxs(u.dispatch(a), "blink"))
	for i in 11:
		rest.append_array(_fxs(u.dispatch("ending_next"), "blink"))
	check(rest.is_empty(), "no third blink anywhere (%s)" % [rest])
	check(after.size() + blinks.size() + p25.size() == 2, "exactly two blinks across the run")
	check(r12(u).blinks() == [] or r12(u).blinks().size() <= 2, "blinks saved")
	# one uninterrupted run counts two as well
	var h := _stair()
	var n := _fxs(h.dispatch("go:R12"), "blink").size()
	for a in P25_ACTIONS + P26_ACTIONS + P27_SEVER:
		n += _fxs(h.dispatch(a), "blink").size()
	check(n == 2, "a straight run blinks twice (%d)" % n)

## Each blink holds its breath with it; 'It's offering to sign for me.' holds 2.5 s; in the
## SEVER ending the room holds its breath 1.5 s before someone clears their throat.
func test_hold_breath() -> void:
	var g := _stair()
	var ev := g.dispatch("go:R12")
	var hb := _fxs(ev, "hold_breath")
	check(hb.size() == 1 and _d(hb[0].seconds) == 1.5 and _d(hb[0].delay) == 11.8 and hb[0].get("line") == BLINK_LINE,
		"arrival: hold_breath 1.5 s at the blink (%s)" % [hb])
	play(g, P25_ACTIONS.slice(0, P25_ACTIONS.size() - 1))
	ev = g.dispatch("route")
	hb = _fxs(ev, "hold_breath")
	check(hb.size() == 2, "P25: two held breaths (%s)" % [hb])
	var by_delay := {}
	for h in hb:
		by_delay[_d(h.delay)] = h
	check(by_delay.has(2.6) and _d(by_delay[2.6].seconds) == 1.5, "P25: 1.5 s with the located blink")
	check(by_delay.has(7.6) and _d(by_delay[7.6].seconds) == 2.5 and by_delay[7.6].get("line") == "It's offering to sign for me.",
		"P25: 2.5 s on 'It's offering to sign for me.'")
	var says_at := {}
	for e in ev:
		if e.type == "say":
			says_at[e.text] = _d(e.delay)
	check(says_at.get("It's offering to sign for me.") == 7.6, "the line is still at 7.6")
	# SEVER, the throat
	var s := _jumped(5)
	ev = s.dispatch("ending_next")
	check(fx(ev, "ending").get("tableau") == "m_funnels", "SEVER step 1: the funnels")
	hb = _fxs(ev, "hold_breath")
	var throat := -1.0
	for x in sfx_list(ev):
		if x[0] == "throat":
			throat = x[1]
	check(hb.size() == 1 and _d(hb[0].seconds) == 1.5 and _d(hb[0].delay) == _d(throat - 1.5) and hb[0].get("sfx") == "throat"
		and _d(hb[0].get("lead")) == 1.5, "SEVER: 1.5 s held, 1.5 s before the throat at %s (%s)" % [throat, hb])
	# no other SEVER page holds its breath
	var others := 0
	for i in 11:
		others += _fxs(s.dispatch("ending_next"), "hold_breath").size()
	check(others == 0, "only the throat page holds its breath")
	# CONTINUE: the kitchen page goes silent as its line goes up, so the end card comes in over silence
	var c := _jumped(6)
	var kettle_hb := []
	for i in 10:
		ev = c.dispatch("ending_next")
		var tab = fx(ev, "ending").get("tableau")
		var h := _fxs(ev, "hold_breath")
		if tab == "m_kettle":
			kettle_hb = h
		else:
			check(h.is_empty(), "CONTINUE page %s: no held breath" % tab)
	check(kettle_hb.size() == 1 and _d(kettle_hb[0].seconds) == 3.0 and _d(kettle_hb[0].delay) == 0.0,
		"the kettle page: hold_breath 3 s from its start (%s)" % [kettle_hb])

## On the stair landing, the chamber never yet entered, her trace stored, the bridge in hand.
func _stair() -> GameSim:
	var g := with_flags(["P04", "P24"], "R11")
	g.state.p05_trace = TRACE.duplicate()
	g.give(BRIDGE)
	return g

func _fxs(ev: Array, id: String) -> Array:
	var out := []
	for e in ev:
		if e.type == "fx" and e.get("id", "") == id:
			out.append(e)
	return out

# ---------------------------------------------------------------------------------------------
# P27
# ---------------------------------------------------------------------------------------------
func test_p27_gates() -> void:
	var g := p25_game()
	var r := r12(g)
	play(g, ["back", "back", "to_routing"])
	for h in ["handle", "yoke_tray", "contacts", "bridge_seat"]:
		g.dispatch(h)
		check(r.local_view == "routing", "c_final refused before P26 (%s)" % h)
	g.selected_item = BRIDGE
	var ev := g.dispatch("bridge_seat")
	check(says(ev) == "Not yet. I don't know yet what it would do." and g.has_item(BRIDGE) and not r.bridge_seated(),
		"the bridge is kept before P26")
	# After P26: first and later entries.
	var p := p26_game()
	var q := r12(p)
	p.dispatch("back")
	ev = p.dispatch("handle")
	check(says(ev) == "The feed contacts, my terminal, the preview lamps. Two buttons, each with its whole meaning printed on it."
		and q.local_view == "c_final", "first c_final entry")
	p.dispatch("back")
	check(says(p.dispatch("yoke_tray")) == "The yoke, the bridge, the two buttons." and q.local_view == "c_final", "later entries")

func test_p27_fittings() -> void:
	var g := final_game()
	var r := r12(g)
	var ev := g.dispatch("contacts")
	check(says(ev) == "Two feed contacts: FEED A, SUBJECTS 1 TO 4. FEED B, SUBJECTS 5 TO 8. The yoke would sit across both."
		and r.has_seen("feed_contacts"), "contacts with an empty hand")
	ev = g.dispatch("tray")
	check(says(ev) == "The severance yoke. Heavy, and insulated at the grips." and r.held_yoke(), "lift the yoke")
	ev = g.dispatch("tray")
	check(says(ev) == "Back in its tray." and not r.held_yoke() and r.yoke() == "tray", "put it back")
	play(g, ["tray"])
	ev = g.dispatch("contacts")
	check(says(ev) == "It drops across both feed contacts and seats." and r.yoke() == "contacts" and has_ev(ev, "fx", "yoke_fit"), "fit the yoke")
	check(says(g.dispatch("tray")) == "The tray is empty. The yoke is across the contacts.", "the tray is empty")
	g.dispatch("preview")
	check(r.final_preview() == "sever", "yoke preview")
	ev = g.dispatch("contacts")
	check(says(ev) == "I lift the yoke off. Back in its tray." and r.yoke() == "tray" and r.final_preview() == "", "lifting resets the preview")
	ev = g.dispatch("bridge_seat")
	check(says(ev) == "The bridge seats in my terminal. A. MERCER · WITNESS. The lamp beside it doesn't light. Not yet."
		and r.bridge_seated() and not g.has_item(BRIDGE) and has_ev(ev, "fx", "bridge_seat"), "seat the bridge")
	g.dispatch("preview")
	check(r.final_preview() == "continue", "bridge preview")
	ev = g.dispatch("bridge_seat")
	check(says(ev) == "I take the bridge out. It's still warm." and not r.bridge_seated() and g.has_item(BRIDGE)
		and r.final_preview() == "", "unseat resets the preview")
	g.take(BRIDGE)
	check(says(g.dispatch("bridge_seat")) == "The seat is empty. It wants the bridge from the model.", "no bridge anywhere")
	g.give(BRIDGE)
	# Both fitted.
	play(g, ["bridge_seat", "tray", "contacts"])
	check(r.yoke() == "contacts" and r.bridge_seated(), "both fitted")
	ev = g.dispatch("preview")
	check(says(ev) == ONE_OR_OTHER and r.final_preview() == "" and has_ev(ev, "sfx", "one_or_other"), "preview with both")
	for b in ["btn_sever", "btn_continue"]:
		check(says(g.dispatch(b)) == ONE_OR_OTHER and not g.flag("P27"), "%s with both: one or the other" % b)
	# Nothing fitted.
	play(g, ["contacts", "bridge_seat"])
	ev = g.dispatch("preview")
	check(says(ev) == "PREVIEW. Nothing fitted. The lamps show the chamber as it is." and r.final_preview() == "", "preview with nothing")
	play(g, ["tray", "contacts"])
	ev = g.dispatch("preview")
	check(says(ev) == "PREVIEW. The eight lines go out on the panel, one by one. In the preview only."
		and fx(ev, "final_preview").get("route") == "sever" and sfx_list(ev) == [["final_preview", 0.0], ["preview_out", 0.3]], "SEVER final preview")
	play(g, ["contacts", "bridge_seat"])
	ev = g.dispatch("preview")
	check(says(ev) == "PREVIEW. The lit line moves from E.V. to A.M. on the panel. In the preview only."
		and fx(ev, "final_preview").get("route") == "continue" and sfx_list(ev) == [["final_preview", 0.0], ["preview_move", 0.3]], "CONTINUE final preview")
	check(says(g.dispatch("look_lamps")) == "The preview lamps. They only show. They don't do.", "look_lamps")
	check(says(g.dispatch("look_handle")) == "The severance handle. It stays locked until BREAK CONNECTION AND LEAVE is pressed.", "look_handle")
	# The yoke in hand leaves with the close-up.
	play(g, ["bridge_seat", "tray", "back"])
	check(not r.held_yoke() and r.yoke() == "tray", "back puts the yoke in its tray")

func test_p27_buttons() -> void:
	var g := final_game()
	var r := r12(g)
	var seen_before := JSON.stringify(g.value("endings_seen"))
	check(says(g.dispatch("btn_sever")) == "The yoke isn't across the contacts.", "SEVER without the yoke")
	check(says(g.dispatch("btn_continue")) == "The bridge isn't in my terminal.", "CONTINUE without the bridge")
	play(g, ["tray", "contacts"])
	var ev := g.dispatch("btn_sever")
	check(says(ev) == PREVIEW_FIRST and r.refused_button == "sever" and has_ev(ev, "sfx", "button_refuse"), "SEVER without a preview")
	play(g, ["contacts", "bridge_seat"])
	check(says(g.dispatch("btn_continue")) == PREVIEW_FIRST and r.refused_button == "continue", "CONTINUE without a preview")
	# A preview of the other route doesn't satisfy a button.
	play(g, ["preview"])
	check(r.final_preview() == "continue", "CONTINUE previewed")
	play(g, ["bridge_seat", "tray", "contacts"])
	check(r.final_preview() == "" and says(g.dispatch("btn_sever")) == PREVIEW_FIRST, "the CONTINUE preview doesn't arm SEVER")
	play(g, ["preview", "contacts", "bridge_seat"])
	check(says(g.dispatch("btn_continue")) == PREVIEW_FIRST, "the SEVER preview doesn't arm CONTINUE")
	check(not g.flag("P27") and g.value("ending_choice") == "" and JSON.stringify(g.value("endings_seen")) == seen_before
		and r.local_view == "c_final" and r.chosen() == "", "nothing changes before a confirm")
	# Commit SEVER.
	play(g, ["bridge_seat", "tray", "contacts", "preview"])
	ev = g.dispatch("btn_sever")
	check(g.flag("P27") and r.chosen() == "sever" and r.local_view == "ending" and r.ending_step() == 0, "SEVER commits")
	check(not has_ev(ev, "fx", "tide"), "P27: the tide holds, no card")
	check(story(ev) == ["I pull the handle. It is heavier than it looks, and then it isn't.",
		"Above the frames the eight indicators go out. Not together. One, and a wait, and the next.",
		"Eight names on brass. Nothing behind any of them now."], "SEVER step 0: its last line is the new one")
	var said_at := []
	for x in ev:
		if x.type == "say":
			said_at.append(_d(x.delay))
	check(said_at == [0.0, 2.6, 18.2], "the new line 2 s after the eighth goes out (%s)" % [said_at])
	# each indicator goes out on a timed fx at its own sound's moment
	var outs := []
	for x in ev:
		if x.type == "fx" and str(x.id).begins_with("line_out_"):
			outs.append([x.id, _d(x.delay)])
	check(outs == expect_outs(), "a line_out_N fx with each line_out_N sound (%s)" % [outs])
	var expect := [["handle_pull", 0.0], ["line_out_1", 3.0], ["line_out_2", 3.8], ["line_out_3", 4.9],
		["line_out_4", 6.3], ["line_out_5", 8.0], ["line_out_6", 10.1], ["line_out_7", 12.6], ["line_out_8", 16.2]]
	check(sfx_list(ev) == expect, "the eight lines go out in turn, each wait longer (%s)" % [sfx_list(ev)])
	var gaps := []
	for i in range(2, expect.size()):
		gaps.append(_d(expect[i][1] - expect[i - 1][1]))
	for i in range(1, gaps.size()):
		check(gaps[i] > gaps[i - 1], "gap %d after line %d is longer than the one before (%s)" % [i, i + 1, gaps])
	var e := fx(ev, "ending")
	check(e.get("choice") == "sever" and e.get("step") == 0 and e.get("tableau") == "c_sever_wall" and e.get("change") == "", "ending fx step 0: the frames wall")

	check(g.value("ending_choice") == "" and g.view == "room", "the end card waits for the ending")
	check(r.hint_frozen() and r.objective() == "finale", "the hint freezes in the ending")

func test_endings_sever_and_replay() -> void:
	var g := game_at(9, ROOM)
	var r := r12(g)
	play(g, P25_ACTIONS)
	play(g, P26_ACTIONS)
	var ev := play(g, P27_SEVER)
	check(r.chosen() == "sever" and not has_ev(ev, "fx", "tide") and g.tide() == 9, "SEVER at tide IX: tide holds 9")
	var tabs := ["c_sever_wall"]
	for i in 12:
		ev = g.dispatch("ending_next")
		check(g.view == "room" and r.local_view == "ending" and r.ending_step() == i + 1, "SEVER step %d" % (i + 1))
		var e := fx(ev, "ending")
		check(e.get("step") == i + 1 and e.get("tableau") == R12Sim.ENDING_SEVER[i + 1].tableau, "SEVER fx step %d" % (i + 1))
		check(story(ev).size() == R12Sim.ENDING_SEVER[i + 1].lines.size() and not story(ev).is_empty(), "SEVER lines step %d" % (i + 1))
		check(e.get("change") == R12Sim.ENDING_SEVER[i + 1].change, "SEVER change step %d" % (i + 1))
		var ch: String = e.get("change")
		check(ch == "" or has_ev(ev, "sfx", ch), "SEVER change sfx plays at step %d" % (i + 1))
		tabs.append(e.get("tableau"))
		check(says(g.dispatch("back")) == "" and r.local_view == "ending", "Back does nothing in the ending")
		check(r.exit_block("R11") == "Not now. I've chosen.", "no leaving after the choice")
	check(tabs == ["c_sever_wall", "m_funnels", "m_diaphragm", "m_jars", "m_spoon", "m_bed", "m_pen", "b_dark", "a_day",
		"end_a_record", "end_a_jetty", "end_a_inquiry", "end_a_page"], "the SEVER tableaux (%s)" % [tabs])
	check(story(ev) == ["The corrected page dries on the sill in ordinary daylight.",
		"There's a small water stain at its corner. Nothing is reflected in it."], "the last SEVER page")
	g.dispatch("ending_next")
	check(g.view == "end" and g.value("ending_choice") == "sever" and "sever" in g.value("endings_seen"), "the 13th next finishes SEVER")
	ev = g.dispatch("return_decision")
	check(g.view == "room" and g.state.room == ROOM and g.flag("P26") and not g.flag("P27") and g.value("ending_choice") == "",
		"return to the decision")
	check(r.chosen() == "" and r.objective() == "decide" and g.has_item(BRIDGE), "back at the decision with the bridge")
	ev = play(g, P27_CONTINUE)
	check(r.chosen() == "continue" and r.local_view == "ending", "CONTINUE commits")
	check(story(ev) == ["I press it. The lit line leaves the terminal marked E.V. and comes into mine.",
		"It's warm. At my own temperature."] and sfx_list(ev).has(["feed_move", 0.0]) and sfx_list(ev).has(["terminal_on", 2.2]),
		"CONTINUE step 0")
	tabs = [fx(ev, "ending").get("tableau")]
	for i in 10:
		ev = g.dispatch("ending_next")
		tabs.append(fx(ev, "ending").get("tableau"))
		check(g.view == "room" and r.ending_step() == i + 1, "CONTINUE step %d" % (i + 1))
	check(tabs == ["c_continue", "m_funnel_venn", "m_coat", "a_sit", "end_b_terminal_1", "m_cup", "end_b_terminal_2",
		"a_morning", "end_b_wide", "m_kettle", "end_b_cover"], "the CONTINUE tableaux (%s)" % [tabs])
	check(story(ev).back() == "Nora Bell took her tea without sugar. Begin there.", "the last CONTINUE line")
	g.dispatch("ending_next")
	check(g.view == "end" and g.value("ending_choice") == "continue", "the 11th next finishes CONTINUE")
	check(sorted(g.value("endings_seen")) == ["continue", "sever"], "both endings seen")
	g.dispatch("new_game")
	check(sorted(g.value("endings_seen")) == ["continue", "sever"], "endings seen survive New game")

func test_seen_lines() -> void:
	var g := final_game()
	var r := r12(g)
	play(g, ["tray", "contacts", "preview", "btn_sever"])
	for i in 13:
		g.dispatch("ending_next")
	g.dispatch("return_decision")
	var ev := play(g, ["to_routing", "contacts"])
	check(r.local_view == "c_final" and "I've broken the line before. I remember the launch." in says(ev), "the launch remembered")
	check(r.has_seen("seen_sever") and not r.has_seen("seen_continue"), "seen_sever noted, continue not")
	g.dispatch("back")
	ev = g.dispatch("contacts")
	check(not "I've broken the line before" in says(ev), "the memory line once per replay")
	play(g, ["bridge_seat", "preview", "btn_continue"])
	for i in 11:
		g.dispatch("ending_next")
	g.dispatch("return_decision")
	ev = play(g, ["to_routing", "handle"])
	check("I've broken the line before. I remember the launch." in says(ev) and "I've stayed before. I remember the first correction." in says(ev),
		"both memories on the next replay, side by side")
	check(r.has_seen("seen_sever") and r.has_seen("seen_continue"), "both memories noted")

func test_bridge_net() -> void:
	# Without the bridge: arrival gives it once.
	var g := with_flags(["P04", "P24"], "R11")
	check(not g.has_item(BRIDGE), "no bridge before the chamber")
	g.dispatch("go:R12")
	check(bridges(g) == 1, "arrive gives the bridge")
	g.dispatch("go:R11")
	g.dispatch("go:R12")
	check(bridges(g) == 1, "no duplicate on re-arrival")
	# Reconcile also covers a save without it.
	var s := fresh(false)
	var t := roundtrip(s)
	check(bridges(t) == 1, "a P24 save without the bridge loads with it")
	# Seated: kept seated across saves.
	var f := final_game()
	f.dispatch("bridge_seat")
	t = roundtrip(f)
	check(r12(t).bridge_seated() and not t.has_item(BRIDGE), "a seated bridge stays seated and out of the inventory")
	# Both seated and in inventory: loads unseated.
	var d: Dictionary = JSON.parse_string(JSON.stringify(f.to_dict()))
	d.inventory.append(BRIDGE)
	var u := GameSim.new()
	u.from_dict(d)
	check(not r12(u).bridge_seated() and bridges(u) == 1, "a doubled bridge loads unseated, once")
	# No P24, no bridge net.
	var n := with_flags([], ROOM)
	r12(n).reconcile()
	check(not n.has_item(BRIDGE), "the net needs P24")

func test_ending_saves() -> void:
	var g := final_game()
	var r := r12(g)
	play(g, ["tray", "contacts", "preview", "btn_sever"])
	for i in 5:
		g.dispatch("ending_next")
	check(r.ending_step() == 5, "at SEVER step 5")
	var t := roundtrip(g)
	var q := r12(t)
	check(t.view == "room" and q.local_view == "ending" and t.state.room == ROOM and q.ending_step() == 5 and q.chosen() == "sever",
		"an ending save lands in the ending at its step")
	var before := JSON.stringify(t.to_dict())
	var ev := t.dispatch("go:R11")
	check(t.state.room == ROOM and q.local_view == "ending" and JSON.stringify(t.to_dict()) == before,
		"no leaving after a load either")
	check(q.exit_block("R11") == "Not now. I've chosen.", "the stair stays shut after a load")
	ev = t.dispatch("chair")
	check(q.local_view == "ending" and q.ending_step() == 5 and story(ev) == ["In the bunk room the hollows in the mattresses rise, one by one, until the beds are only made."],
		"a hotspot resumes at step 5 (%s)" % [story(ev)])
	check(fx(ev, "ending").get("step") == 5 and JSON.stringify(t.to_dict()) == before, "resume changes nothing")
	ev = t.dispatch("ending_next")
	check(q.ending_step() == 6, "and the ending goes on")
	# A control after a load resumes too.
	var u := roundtrip(g)
	ev = u.dispatch("btn_sever")
	check(r12(u).local_view == "ending" and fx(ev, "ending").get("step") == 5, "a control resumes the ending")

## A save taken mid-ending loads back into the ending, on the same page, and goes on.
func test_ending_reload() -> void:
	for choice in ["sever", "continue"]:
		var g := final_game()
		var r := r12(g)
		if choice == "sever":
			play(g, ["tray", "contacts", "preview", "btn_sever"])
		else:
			play(g, ["bridge_seat", "preview", "btn_continue"])
		check(r.state.chosen == choice and r.state.ending_step == 0, "%s: chosen and step set on the commit" % choice)
		g.dispatch("ending_next")
		var d := g.to_dict()
		check(d.rooms.R12.chosen == choice and d.rooms.R12.ending_step == 1, "%s: the save holds the choice and the page" % choice)
		var t := GameSim.new()
		t.load_settings(g.settings_dict())
		check(t.from_dict(JSON.parse_string(JSON.stringify(d))), "%s: loads" % choice)
		var q := r12(t)
		check(q.local_view == R12Sim.V_ENDING and q.ending_step() == 1 and q.chosen() == choice,
			"%s: the load lands in the ending on its page (%s, %d)" % [choice, q.local_view, q.ending_step()])
		check(q.resume_view() == R12Sim.V_ENDING, "%s: resume_view is the ending" % choice)
		var ev: Array = []
		check(q.resume(ev), "%s: the room takes the resume" % choice)
		check(not R12Sim.RESUME in says(ev) and fx(ev, "ending").get("step") == 1
			and story(ev).size() == R12Sim.steps(choice)[1].lines.size(), "%s: resume replays the page, no 'Back in'" % choice)
		check(q.ending_step() == 1, "%s: the resume changes nothing" % choice)
		ev = t.dispatch("ending_next")
		check(q.ending_step() == 2 and fx(ev, "ending").get("step") == 2, "%s: and ending_next goes on" % choice)
	var n := fresh()
	check(r12(n).resume_view() == "room" and not r12(n).resume([]), "before the choice a load resumes in the room")

## The sounds and silences the endings are timed to.
func test_ending_timings() -> void:
	var funnels: Dictionary = R12Sim.ENDING_SEVER[1]
	check(funnels.sfx == [["funnel_stop", 0.4], ["throat", 3.6]], "the throat clears at 3.6 s (%s)" % [funnels.sfx])
	var morning: Dictionary = R12Sim.ENDING_CONTINUE[7]
	check(morning.tableau == "a_morning" and morning.lines == [[0.0, "Morning reaches the windows."]],
		"the morning page: only 'Morning reaches the windows.'")
	var wide: Dictionary = R12Sim.ENDING_CONTINUE[8]
	check(wide.tableau == "end_b_wide" and wide.lines == [[0.0, "The station does not go back to the shore."],
		[2.8, "Out to the edge of the water, stations. Every window dark but one."]] and not wide.has("breath"),
		"the wide page keeps its first two lines, no held breath")
	var kettle: Dictionary = R12Sim.ENDING_CONTINUE[9]
	check(kettle.tableau == "m_kettle" and kettle.lines == [[0.0, "The kitchen. Someone has put the kettle on."]]
		and kettle.breath == [{"seconds": 3.0, "delay": 0.0}], "the kettle page after it: its line and its held breath")
	check(R12Sim.ENDING_CONTINUE.size() == 11 and R12Sim.ENDING_CONTINUE[10].tableau == "end_b_cover", "then the cover page")
	var sever0: Dictionary = R12Sim.ENDING_SEVER[0]
	check(sever0.tableau == "c_sever_wall" and sever0.lines.back() == [18.2, "Eight names on brass. Nothing behind any of them now."],
		"SEVER's first page ends on the brass names, 2 s after the eighth goes out")
	for st in R12Sim.ENDING_CONTINUE:
		for l in st.lines:
			check(not "Far out in the dark" in l[1] and not "more windows than I can count" in l[1], "the old wide lines are gone")
	check(R12Sim.end_still("continue") == "res://assets/stages/R12/end_b_card.png"
		and R12Sim.end_still("sever") == "res://assets/stages/R12/end_a_card.png", "the end stills")
	for still in [R12Sim.end_still("continue"), R12Sim.end_still("sever")]:
		var tex: Texture2D = load(still)
		check(tex != null and tex.get_size() == Vector2(1448, 1086), "%s: native 1448x1086" % still)

func test_use_item() -> void:
	var g := fresh()
	g.give("pencil")
	g.selected_item = "pencil"
	check(says(g.dispatch("chair")) == "That belongs upstairs." and g.has_item("pencil"), "other items belong upstairs")
	g.selected_item = BRIDGE
	check(says(g.dispatch("chair")) == "Not here. The bridge is for my terminal." and g.has_item(BRIDGE), "the bridge on the chair")
	g.dispatch("to_routing")
	g.selected_item = BRIDGE
	check(says(g.dispatch("contacts")) == "I'll need to open it first." and r12(g).local_view == "routing",
		"the bridge on the shut final hardware")
	check(not r12(g).use_item(BRIDGE, "go:R11", []), "the bridge on the stair exit is not handled")
	check(not r12(g).use_item(BRIDGE, "nowhere", []), "unknown targets are not handled")
	# A frame on the record wall (a card's place on the frame row): the frames open with the
	# item in hand, and it is applied there in the same action: they take only their own cards.
	for target in ["frame_body", "frame_place", "frame_name", "card_rack", "terminal"]:
		for item in [BRIDGE, "pencil"]:
			var f := fresh()
			f.give("pencil")
			f.dispatch("to_frames")
			f.selected_item = item
			var ev := f.dispatch(target)
			check(r12(f).local_view == "c_frames" and r12(f).has_seen("frames_procedure") and f.has_item(item)
				and says(ev) == "Nothing from my pocket goes in the frames. Only the cards in the rack.",
				"%s on %s: c_frames opens and refuses it there (%s)" % [item, target, says(ev)])
			f.selected_item = item
			check(says(f.dispatch("f_body")) == "Nothing from my pocket goes in the frames. Only the cards in the rack.",
				"%s on a frame inside c_frames" % item)
	# A routing plate: shut before P25 ("I'll need to open it first."); after, it opens and its
	# patch field takes only its own cords.
	var s := fresh()
	s.dispatch("to_routing")
	s.selected_item = BRIDGE
	check(says(s.dispatch("plate_sever")) == "I'll need to open it first." and r12(s).local_view == "routing", "a shut plate")
	var o := p25_game()
	play(o, ["back", "back", "to_routing"])
	o.selected_item = BRIDGE
	check(says(o.dispatch("plate_continue")) == "The patch field only takes its own cords." and r12(o).local_view == "c_routing"
		and o.has_item(BRIDGE), "a plate after P25: opens, refuses it there")
	o.selected_item = BRIDGE
	check(says(o.dispatch("jack_open")) == "The patch field only takes its own cords.", "the bridge on a socket")
	# After P26, from the routing wall: the terminal takes the bridge; it opens c_final and seats it.
	for wall in ["bridge_seat"]:
		var p := p26_game()
		var r := r12(p)
		p.dispatch("back")
		p.selected_item = BRIDGE
		var ev := p.dispatch(wall)
		check(r.local_view == "c_final" and r.bridge_seated() and not p.has_item(BRIDGE) and r.gaze() == "final",
			"the bridge seats from the wall, the eye on the switches (%s)" % says(ev))
	# Other final hardware from the wall: c_final opens and the bridge is refused there.
	for wall in ["handle", "yoke_tray", "contacts"]:
		var p := p26_game()
		var r := r12(p)
		p.dispatch("back")
		p.selected_item = BRIDGE
		var ev := p.dispatch(wall)
		var want := "The bridge goes in my terminal, not across the feed." if wall == "contacts" else "Not here. The bridge is for my terminal."
		check(r.local_view == "c_final" and not r.bridge_seated() and p.has_item(BRIDGE) and says(ev) == want,
			"the bridge on %s: c_final opens, the bridge stays in hand (%s)" % [wall, says(ev)])
	var q := p26_game()
	q.dispatch("back")
	q.selected_item = "pencil"
	q.give("pencil")
	check(says(q.dispatch("bridge_seat")) == "That belongs upstairs." and r12(q).local_view == "c_final", "a stray item at the terminal")

# ---------------------------------------------------------------------------------------------
# every hotspot and control answers
# ---------------------------------------------------------------------------------------------
func _jumped(n: int) -> GameSim:
	var g := GameSim.new()
	g.room(ROOM).debug_jump(n)
	return g

func test_answers() -> void:
	for n in [0, 1, 2]:
		var g := _jumped(n)
		var r := r12(g)
		check(r.stage() == ["s0", "s1", "s2"][n], "jump %d: stage" % n)
		for h in R12Sim.HOTSPOTS + R12Sim.FRAMES_HOTSPOTS + R12Sim.ROUTING_HOTSPOTS:
			check(says(g.dispatch(h)) != "", "s%d: %s answers" % [n, h])
		for cs in [["frame_body", R12Sim.FRAMES_CONTROLS, "c_frames"]]:
			g.dispatch(cs[0])
			for c in cs[1]:
				check(r.local_view == cs[2], "s%d: still in %s for %s" % [n, cs[2], c])
				check(says(g.dispatch(c)) != "", "s%d: %s answers" % [n, c])
		if n >= 1:
			g.dispatch("plate_sever")
			for c in R12Sim.ROUTING_CONTROLS:
				check(r.local_view == "c_routing", "s%d: in c_routing for %s" % [n, c])
				check(says(g.dispatch(c)) != "", "s%d: %s answers" % [n, c])
		if n == 2:
			g.dispatch("handle")
			for c in R12Sim.FINAL_CONTROLS:
				check(r.local_view == "c_final", "s2: in c_final for %s" % c)
				check(says(g.dispatch(c)) != "", "s2: %s answers" % c)
	# The configured states: fittings on, and the ending.
	for n in [3, 4, 5, 6]:
		var g := _jumped(n)
		var r := r12(g)
		if n <= 4:
			play(g, ["handle"])
			for c in R12Sim.FINAL_CONTROLS:
				if c in ["btn_sever", "btn_continue"]:
					continue
				check(says(g.dispatch(c)) != "", "jump %d: %s answers" % [n, c])
		else:
			for h in R12Sim.HOTSPOTS + R12Sim.ENDING_CONTROLS:
				check(says(g.dispatch(h)) != "" and r.local_view == "ending", "jump %d: %s answers in the ending" % [n, h])
	# Room view lines by stage.
	var a := _jumped(0)
	check(says(a.dispatch("chair")) == "A plain chair, bolted down, facing the instrument. The seat is worn pale in the shape of somebody.", "chair s0")
	check(says(a.dispatch("armatures")) == "Every arm ends at a part of whoever sits there. A cup for the back of the head. Two cuffs. Two plates for the feet.", "armatures first")
	check(says(a.dispatch("armatures")) == "Someone has adjusted them recently. The brass is bright at the joints.", "armatures later")
	check(says(a.dispatch("window")) == "The surface. It fills the glass. There's no edge to it, and no reflection of the room.", "window 1")
	check(says(a.dispatch("window")) == "It isn't water. Water moves. This is holding still, the way a held breath is still.", "window 2")
	check(says(a.dispatch("window")) == "A line has crossed it, slowly, top to bottom, like a lid. It isn't looking at the station. It's looking at the chair.", "window 3")
	check(says(a.dispatch("window")).begins_with("A line has crossed it") and r12(a).state.window_looks == 4, "window 4+")
	check(says(a.dispatch("pressure")) == "A pressure gauge, marked in tides. The needle rests on IX and trembles, as if something is leaning on it.", "pressure s0")
	check(says(a.dispatch("indicators")).begins_with("Eight indicators, shuttered. Under each, a name: ROOK, BELL, IVES, LUSK, PRYCE, DOANE, HART, TULL."), "indicators s0")
	check(says(a.dispatch("copy_port")) == "A socket marked COPY, under a brass dust cap on a chain. The cap is warm.", "copy port s0")
	check(says(a.dispatch("nameplate")) == "A brass plate over three empty frames: ADA MERCER. The engraving is fresh. There are brass filings still in the letters.", "nameplate")
	for o in ["chair", "armatures", "armatures_adjusted", "surface", "surface_lid", "pressure", "indicators", "copy_port", "nameplate"]:
		check(r12(a).has_seen(o), "s0 notes %s" % o)
	var b := _jumped(1)
	check(says(b.dispatch("chair")) == "The cushion is pressed down, as if someone has just sat. Nobody has. I haven't.", "chair s1")
	check(says(b.dispatch("armatures")) == "The head cup has come down. It's at my height now.", "armatures s1")
	check(says(b.dispatch("indicators")) == "The shutters have all turned a little. Toward my terminal.", "indicators s1")
	check(says(b.dispatch("copy_port")) == "The cap is off, hanging on its chain. I didn't take it off.", "copy port s1")
	for o in ["chair_pressed", "armatures_lowered", "shutters_turned", "copy_uncapped"]:
		check(r12(b).has_seen(o), "s1 notes %s" % o)
	var c := _jumped(2)
	check(says(c.dispatch("chair")) == "It's waiting. It doesn't mind how long.", "chair s2")
	check(says(c.dispatch("window")) == "It drew back from the glass. A margin of darker water at the edge. It made room.", "window s2")
	check(says(c.dispatch("pressure")) == "The needle has eased back a hair. Off IX, a little.", "pressure s2")
	check(says(c.dispatch("to_routing")) == "The routing wall." and r12(c).local_view == "routing", "to_routing")

func test_objectives_hints() -> void:
	var expect := {0: "frames", 1: "routing", 2: "decide", 3: "decide", 5: "finale", 8: "finale"}
	check(R12Sim.HINT_TIERS == 4, "four hint tiers")
	for n in expect:
		var g := _jumped(n)
		var r := r12(g)
		var o: String = expect[n]
		check(r.objective() == o, "jump %d: objective %s (got %s)" % [n, o, r.objective()])
		check(r.objective_text() == R12Sim.OBJECTIVES[o], "jump %d: objective text" % n)
		check(r.hint_tiers() == 4 and R12Sim.HINTS[o].size() == 4, "jump %d: a four-tier ladder" % n)
		for i in 4:
			var want: String = REF_HINTS[o][i]
			if o == "frames" and i == 3:
				want = frames_hint3(g)
			check(r.hint_at(i) == want, "jump %d: tier %d (%s)" % [n, i, r.hint_at(i)])
		# the core's levels: all four when it reads hint_tiers(); else the evidence is skipped
		var levels := [0, 1, 2, 3] if R12Sim.core_reads_tiers() else [0, 1, 3]
		for k in levels.size():
			check(r.hint_line(k) == r.hint_at(levels[k]), "jump %d: core level %d is tier %d" % [n, k, levels[k]])
	for o in ["frames", "routing", "decide"]:
		check(REF_HINTS[o][2] != REF_HINTS[o][1] and REF_HINTS[o][2] != REF_HINTS[o][3], "%s: the evidence tier is its own line" % o)
	check(R12Sim.OBJECTIVES == {"frames": "Give the chamber its record of me. Don't let it sign.",
		"routing": "Find out exactly what each route does.", "decide": "Choose: break the line, or stay as its witness.",
		"finale": "See it through.", "done_chamber": "It's done."}, "objective lines")
	var g := with_flags(["P24", "P25", "P26", "P27"], ROOM)
	r12(g).reconcile()
	check(r12(g).objective() == "done_chamber", "P27 by flags with no choice: done")
	# The hint ladder climbs in play and always reaches the solution.
	var h := fresh()
	var lines := []
	for i in (5 if R12Sim.core_reads_tiers() else 3):   # core p1: a confirmation before the last tier
		lines.append(says(h.dispatch("hint")))
	check(lines.back() == frames_hint3(h) and lines[0] == REF_HINTS.frames[0], "the frames ladder in play ends in the solution (%s)" % [lines])
	check(frames_hint3(h) == "The true cards: the MOVEMENT card reading 'Turned the zero wheel. Opened the hatch. Looked down the stair.' to BODY; 'Ninth position. Centre of the station outline.' to PLACE; 'Requested by E. Venn.' to NAME. Then the switch to WITNESS, and ROUTE.",
		"the solution names each true card and its frame")
	var e := _jumped(5)
	check(says(e.dispatch("hint")) == REF_HINTS.finale[0] and r12(e).hint_frozen(), "the ending: frozen hint")
	check(R12Sim.WAY_IN_HINT == "The lower door on the stair landing has opened. Below it, the chamber.", "way-in hint")

## P25's third hint, written out independently: each true card by its words, and its frame.
func frames_hint3(g: GameSim) -> String:
	var moves := []
	for t in g.value("p05_trace"):
		moves.append(GameSim.move_text(t))
	var body := "the MOVEMENT card reading '%s'" % " ".join(moves) if not moves.is_empty() \
		else "the MOVEMENT card that is my own departure record"
	return "The true cards: %s to BODY; 'Ninth position. Centre of the station outline.' to PLACE; 'Requested by E. Venn.' to NAME. Then the switch to WITNESS, and ROUTE." % body

func test_reconcile() -> void:
	var g := with_flags(["P24", "P25"], ROOM)
	var r := r12(g)
	r.reconcile()
	check(r.state.p25_complete and r.frames() == R12Sim.SOLUTION_FRAMES and r.switch() == "witness", "adopts P25")
	g = with_flags(["P24", "P25", "P26"], ROOM)
	r = r12(g)
	r.reconcile()
	check(r.state.p26_complete and r.state.previewed == ["sever", "continue"], "adopts P26")
	g = with_flags(["P24", "P25", "P26", "P27"], ROOM)
	r = r12(g)
	r.reconcile()
	check(r.state.p27_complete, "adopts P27")
	# P24 by flag: the built stair adopts it on load too, so let every room reconcile first.
	for rid in g.order:
		g.room(rid).reconcile()
	check(JSON.stringify(roundtrip(g).to_dict()) == JSON.stringify(g.to_dict()), "an adopted P27 round-trips")
	g = with_flags(["P24"], ROOM)
	r = r12(g)
	r.state.p25_complete = true
	r.state.p26_complete = true
	r.reconcile()
	check(g.flag("P25") and g.flag("P26") and not g.flag("P27"), "sets flags from state")
	check(r.p25_done() and r.p26_done() and not r.p27_done(), "done helpers")

func test_debug_jumps() -> void:
	for n in 9:
		var g := _jumped(n)
		var r := r12(g)
		var tag := "jump %d" % n
		check(g.state.room == ROOM and g.view == "room" and g.tide() == 9, "%s: in the chamber at IX" % tag)
		check(g.flag("P25") == (n >= 1) and g.flag("P26") == (n >= 2) and g.flag("P27") == (n >= 5), "%s: flags" % tag)
		check(r.state.noticed == (["arrival"] if n >= 1 else []), "%s: noticed" % tag)
		check(g.checkpoint.is_empty() == (n < 2), "%s: checkpoint" % tag)
		var yoke_on := n in [3, 5, 7]
		var seated := n in [4, 6, 8]
		check(r.yoke() == ("contacts" if yoke_on else "tray") and r.bridge_seated() == seated, "%s: fittings" % tag)
		check(g.has_item(BRIDGE) == (not seated), "%s: the bridge is in hand or seated" % tag)
		check(r.final_preview() == ("sever" if n in [3] else ("continue" if n in [4] else ("sever" if yoke_on else ("continue" if seated else "")))), "%s: preview" % tag)
		check(r.chosen() == ({5: "sever", 7: "sever", 6: "continue", 8: "continue"}.get(n, "")), "%s: chosen" % tag)
		check(r.ending_step() == ({7: 12, 8: 10}.get(n, 0)), "%s: ending step" % tag)
		check(r.local_view == ("ending" if n >= 5 else "room"), "%s: view" % tag)
		var t := roundtrip(g)
		check(JSON.stringify(t.to_dict()) == JSON.stringify(g.to_dict()), "%s: round-trips byte-identical" % tag)
	var f := _jumped(7)
	f.dispatch("ending_next")
	check(f.view == "end" and f.value("ending_choice") == "sever", "jump 7: one more next ends it")
	var c := _jumped(8)
	c.dispatch("ending_next")
	check(c.view == "end" and c.value("ending_choice") == "continue", "jump 8: one more next ends it")
	# debug_prepare: fresh at every tide.
	for t in [1, 5, 9]:
		var g := game_at(t, "R02")
		check(JSON.stringify(r12(g).state) == JSON.stringify(r12(g).initial_state()), "debug_prepare(%d) is fresh" % t)

func test_back() -> void:
	var g := _jumped(2)
	var r := r12(g)
	var walks := [["frame_body", "c_frames", "frames"], ["plate_sever", "c_routing", "routing"],
		["handle", "c_final", "routing"], ["to_frames", "frames", "room"], ["to_routing", "routing", "room"]]
	for w in walks:
		g.dispatch(w[0])
		check(r.local_view == w[1], "%s opens %s" % [w[0], w[1]])
		g.dispatch("back")
		check(r.local_view == w[2], "back from %s goes to %s (got %s)" % [w[1], w[2], r.local_view])
		g.dispatch("back")
		g.dispatch("back")
	var e := _jumped(5)
	e.dispatch("back")
	check(r12(e).local_view == "ending", "back in the ending stays")
	# Back clears what is in hand.
	var p := fresh()
	place(p, ["trace"])
	p.dispatch("rack_identity")
	p.dispatch("back")
	check(r12(p).held_card() == "" and r12(p).local_view == "frames", "back puts the card down")

# ---------------------------------------------------------------------------------------------
# the chain actions (handed to tests/chain_test.gd)
# ---------------------------------------------------------------------------------------------
func test_chain_actions() -> void:
	var g := game_at(9, "R11")
	var r := r12(g)
	g.dispatch("go:R12")
	check(g.state.room == ROOM, "chain: into the chamber")
	play(g, P25_ACTIONS)
	check(g.flag("P25") and r.local_view == "c_frames", "chain: P25")
	play(g, P26_ACTIONS)
	check(g.flag("P26") and not g.checkpoint.is_empty() and r.local_view == "c_routing", "chain: P26")
	var snap := JSON.stringify(g.checkpoint)
	play(g, P27_SEVER)
	check(g.flag("P27") and r.chosen() == "sever", "chain: P27 SEVER")
	check(R12Sim.ENDING_SEVER.size() == 13 and R12Sim.ENDING_CONTINUE.size() == 11, "13 SEVER pages, 11 CONTINUE pages")
	for i in 13:
		check(g.view == "room", "chain: SEVER step %d before the end" % i)
		g.dispatch("ending_next")
	check(g.view == "end" and g.value("ending_choice") == "sever", "chain: the 13th next finishes")
	g.dispatch("return_decision")
	check(JSON.stringify(g.to_dict()) == snap or g.flag("P26"), "chain: back at the checkpoint")
	play(g, P27_CONTINUE)
	check(r.chosen() == "continue", "chain: P27 CONTINUE")
	for i in 11:
		g.dispatch("ending_next")
	check(g.view == "end" and g.value("ending_choice") == "continue", "chain: the 11th next finishes")

	check(sorted(g.value("endings_seen")) == ["continue", "sever"], "chain: both endings seen")
	# The glance path: the core puts the close-up down with back until the room; the chain still works.
	var h := game_at(9, ROOM)
	play(h, P25_ACTIONS)
	play(h, P26_ACTIONS)
	for i in 4:
		if r12(h).local_view != "room":
			h.dispatch("back")
	check(r12(h).local_view == "room", "after the glance the room is up")
	play(h, P27_SEVER)
	check(h.flag("P27") and r12(h).chosen() == "sever", "P27 from the room after the glance")

# ---------------------------------------------------------------------------------------------
# the view (game/rooms/R12/R12_view.gd) on the real game scene
# ---------------------------------------------------------------------------------------------
const VIEW_TABLES := {
	"room": "HOTSPOTS", "frames": "FRAMES_HOTSPOTS", "routing": "ROUTING_HOTSPOTS",
	"c_frames": "FRAMES_CONTROLS", "c_routing": "ROUTING_CONTROLS", "c_final": "FINAL_CONTROLS",
}
## How to stand in each view from a debug jump.
const VIEW_PATHS := {
	"room": [0, []], "frames": [0, ["to_frames"]], "routing": [1, ["to_routing"]],
	"c_frames": [0, ["to_frames", "frame_body"]], "c_routing": [1, ["to_routing", "plate_sever"]],
	"c_final": [2, ["to_routing", "contacts"]],
}

func _scene_at(n: int, actions: Array) -> Node:
	var scene = new_scene("user://r12_view_test.json")
	await process_frame
	scene.room_jump(ROOM, n)
	for a in actions:
		scene.dispatch(a)
	return scene

func _state_key(scene: Node) -> String:
	var r: R12Sim = scene.sim.room(ROOM)
	return JSON.stringify(scene.sim.to_dict()) + r.local_view + r.held_card() + str(r.held_yoke())

## Every view's table: the sim's ids in order, at least 64x64, on the canvas, clear of the HUD,
## inventory and subtitles; each control answers at its centre (or a smaller one listed first does);
## the hit-tests change nothing.
func test_view_tables() -> void:
	var sim_ids := {"room": R12Sim.HOTSPOTS, "frames": R12Sim.FRAMES_HOTSPOTS, "routing": R12Sim.ROUTING_HOTSPOTS,
		"c_frames": R12Sim.FRAMES_CONTROLS, "c_routing": R12Sim.ROUTING_CONTROLS, "c_final": R12Sim.FINAL_CONTROLS}
	for v in VIEW_PATHS:
		var scene = await _scene_at(VIEW_PATHS[v][0], VIEW_PATHS[v][1])
		var r: R12Sim = scene.sim.room(ROOM)
		var view = scene.room_view
		check(r.local_view == v, "view test: standing in %s (got %s)" % [v, r.local_view])
		var rows: Array = view.closeup_controls(v)
		var ids := []
		for h in rows:
			ids.append(h[0])
		check(ids == sim_ids[v], "view %s: the controls are the sim's, in order (%s)" % [v, ids])
		var before := _state_key(scene)
		for h in rows:
			var rect: Rect2 = h[1]
			check(rect.size.x >= MIN_TARGET and rect.size.y >= MIN_TARGET, "view %s: %s is at least 64x64" % [v, h[0]])
			check(CANVAS.encloses(rect), "view %s: %s is on the canvas" % [v, h[0]])
			check(not rect.intersects(HUD_ZONE) and not rect.intersects(SUBTITLE_ZONE)
				and not rect.intersects(INVENTORY_ZONE), "view %s: %s keeps clear of the HUD and subtitles" % [v, h[0]])
			var hit: String = view.action_at(rect.get_center())
			check(hit == h[0] or _first_hit(rows, rect.get_center()) != h[0], "view %s: a click on %s reaches it (%s)" % [v, h[0], hit])
			check(view.hover_at(rect.get_center()) == hit, "view %s: hover names what a click would do on %s" % [v, h[0]])
			check(view.label_for(h[0]) != "", "view %s: %s has a hover label" % [v, h[0]])
			check(scene.action_at(rect.get_center()) == hit, "view %s: the scene routes %s to the room" % [v, h[0]])
		check(_state_key(scene) == before, "view %s: hit-tests change nothing" % v)
		check(view.dev_rects().size() == rows.size(), "view %s: F1 shows this view's rects" % v)
		await free_scene(scene)

## The core hooks per view.
func test_view_hooks() -> void:
	var expect := {
		"room": [false, "Back", "menu", true], "frames": [true, "◂ Chair", "back", false],
		"routing": [true, "◂ Chair", "back", false], "c_frames": [true, "Back", "back", false],
		"c_routing": [true, "Back", "back", false], "c_final": [true, "Back", "back", false],
	}
	for v in VIEW_PATHS:
		var scene = await _scene_at(VIEW_PATHS[v][0], VIEW_PATHS[v][1])
		var view = scene.room_view
		var e: Array = expect[v]
		check(view.back_visible() == e[0], "view %s: Back shown %s" % [v, e[0]])
		if e[0]:
			check(view.back_label() == e[1], "view %s: Back reads %s (got %s)" % [v, e[1], view.back_label()])
		check(view.esc_action() == e[2], "view %s: Esc does %s" % [v, e[2]])
		check(view.exits_active() == e[3], "view %s: exits active %s" % [v, e[3]])
		check(not view.hud_hidden() and view.chain_gates(), "view %s: HUD shown, chains gate clicks" % v)
		check(view.start_glance("window", Rect2(474, 96, 500, 290)) == (v == "room"),
			"view %s: the window glance is the room's own only in the room" % v)
		await free_scene(scene)
	check(load("res://game/rooms/R12/R12_view.gd").new().exit_arrow("R11") == "left", "view: the stair tab points left")
	# loops follow the stage
	var lt := {}
	for n in 3:
		var scene = await _scene_at(n, [])
		lt[n] = scene.room_view.loop_targets()
		await free_scene(scene)
	check(lt[0].r12_pressure > 0.0 and lt[0].r12_pressure_low == 0.0 and lt[0].r12_terminal == 0.0,
		"loops s0: pressure, no terminal")
	check(lt[1].r12_terminal > 0.0 and lt[1].r12_hum > lt[0].r12_hum, "loops s1: the terminal hums, the hum lifts")
	check(lt[2].r12_pressure == 0.0 and lt[2].r12_pressure_low > 0.0, "loops s2: the low pressure replaces the pressure")
	for id in R12_view_sfx():
		check(ResourceLoader.exists("res://assets/audio/R12/%s.wav" % id), "sound %s exists" % id)

func R12_view_sfx() -> Array:
	return load("res://game/rooms/R12/R12_view.gd").get_script_constant_map()["SFX_DB"].keys()

## The first arrival holds on the name frame; a click skips it; exits wait for it.
func test_view_arrival() -> void:
	var scene = new_scene("user://r12_view_test.json")
	await process_frame
	scene.tide_jump(9, "R11")
	scene.sim.state.visited.erase(ROOM)
	scene.dispatch("go:R12")
	var view = scene.room_view
	check(scene.sim.state.room == ROOM and view.hold_active(), "arrival: the name frame holds")
	check(not view.exits_active(), "arrival: no exits during the hold")
	check(view.consume_click(Vector2(700, 500)) and not view.hold_active(), "arrival: a click skips the hold")
	check(not view.consume_click(Vector2(700, 500)), "arrival: the next click is not eaten")
	check(view.exits_active(), "arrival: exits back after the hold")
	scene.dispatch("go:R11")
	scene.dispatch("go:R12")
	check(not scene.room_view.hold_active(), "arrival: the hold plays once")
	await free_scene(scene)

## The ending: a full-screen tableau, ending_next anywhere, no labels, HUD hidden.
func test_view_endings() -> void:
	for n in [5, 6, 7, 8]:
		var scene = await _scene_at(n, [])
		var view = scene.room_view
		var r: R12Sim = scene.sim.room(ROOM)
		check(r.local_view == "ending", "ending %d: in the ending" % n)
		# mid-page a click is the core's (it advances her lines); once the page is done, next anywhere
		scene.lines.clear()
		scene.pending_sfx.clear()
		scene.cur_text = ""
		scene.cur_story = false
		scene.time += 1.0
		view.tick(0.0)
		for p in [Vector2(10, 10), Vector2(724, 543), Vector2(1440, 1080), Vector2(1200, 40)]:
			check(view.action_at(p) == "ending_next" and view.hover_at(p) == "", "ending %d: next anywhere once the page is done, no label" % n)
		check(view.hud_hidden() and not view.back_visible() and view.esc_action() == "menu" and not view.exits_active(),
			"ending %d: HUD hidden, no Back, Esc is the menu" % n)
		var lt: Dictionary = view.loop_targets()
		if n == 7:
			check(lt.end_sea_day > 0.0 and lt.r12_hum == 0.0 and lt.r12_surface == 0.0, "ending sever, last step: the sea")
		if n == 8:
			check(lt.end_wide > 0.0 and lt.r12_hum == 0.0, "ending continue, last step: the wide dark")
		if n == 6:
			check(lt.r12_hum > 0.0 and lt.r12_terminal > 0.0 and lt.end_wide == 0.0, "ending continue, first step: the chamber hums")
		await free_scene(scene)

## The room view's wall of glass: the wide plate behind every hotspot, the eye over it, and no
## lid at all unless the sim blinks; the margin after P26; the window rect unchanged.
func test_view_surface() -> void:
	var view_script: Dictionary = load("res://game/rooms/R12/R12_view.gd").get_script_constant_map()
	check(view_script.HOTSPOTS[1] == ["window", Rect2(474, 96, 500, 290), "Window"], "the window hotspot is unchanged")
	check(ResourceLoader.exists("res://assets/rooms/R12/a_surface_wide.png")
		and ResourceLoader.exists("res://assets/rooms/R12/a_surface_eye_r3.png")
		and ResourceLoader.exists("res://assets/rooms/R12/a_pupil_r3.png")
		and ResourceLoader.exists("res://assets/stages/R12/end_b_wide_3.png"), "the plates exist")
	var scene = await _scene_at(0, [])
	var view = scene.room_view
	var g: Rect2 = view_script.GLASS_IN
	for m in [false, true]:
		scene.sim.settings.motion = m
		for k in 5:
			scene.time = 40.0 + 7.0 * k
			check(view.blink_k() == 0.0 and is_equal_approx(view.lid_bottom(), g.position.y), "no blink, no lid (motion %s, t %d)" % [m, k])
	var eye: Texture2D = load("res://assets/rooms/R12/a_surface_eye_r3.png")
	# wide and tall enough that, at any look and x1.15, it still covers the whole water
	for look in R12Sim.PUPIL_OFFSET:
		var o: Array = R12Sim.PUPIL_OFFSET[look]
		for sc in [1.0, 1.15]:
			var size: Vector2 = eye.get_size() * sc
			var rect := Rect2(view_script.EYE_C + Vector2(o[0], o[1]) - size / 2.0, size)
			check(rect.encloses(g), "the eye covers the water looking at %s, x%s" % [look, sc])
	var pupil: Texture2D = load("res://assets/rooms/R12/a_pupil_r3.png")
	check(absf(pupil.get_size().x - 272.0) < 1.0 and absf(pupil.get_size().y - 82.0) < 1.0, "the slit pupil: 260 x 70 and its rim")
	check(is_equal_approx(view.water_y(), 382.0), "s0: the water line low in the window")
	check(is_equal_approx(view.eye_scale(), 1.0), "s0: the eye at its size")
	await free_scene(scene)
	var s1 = await _scene_at(1, [])
	check(is_equal_approx(s1.room_view.water_y(), 302.0), "after P25: the water line 80 px higher")
	check(is_equal_approx(s1.room_view.eye_scale(), 1.0), "after P25: the eye not yet closer")
	await free_scene(s1)
	var s2 = await _scene_at(2, [])
	check(is_equal_approx(s2.room_view.water_y(), 302.0) and is_equal_approx(s2.room_view.eye_scale(), 1.15),
		"after P26: the eye x1.15")
	await free_scene(s2)

## The SEVER line-outs end in true silence; the wide CONTINUE page ducks its gap; the bed levels;
## the throat under soft audio.
func test_view_ending_sound() -> void:
	var lin := func(db: float) -> float: return db_to_linear(db)
	var s0 = await _scene_at(0, [])
	var lt: Dictionary = s0.room_view.loop_targets()
	check(is_equal_approx(lt.r12_hum, lin.call(-9.0)) and is_equal_approx(lt.r12_pressure, lin.call(-10.0))
		and is_equal_approx(lt.r12_surface, lin.call(-14.0)), "the bed: hum -9, pressure -10, surface -14 (%s)" % [lt])
	s0.sim.settings.soft_audio = false
	check(is_equal_approx(s0.sfx_db("throat"), -14.0), "the throat at -14")
	s0.sim.settings.soft_audio = true
	check(is_equal_approx(s0.sfx_db("throat"), -18.0), "soft audio caps the throat at -18")
	s0.sim.settings.soft_audio = false
	await free_scene(s0)
	var s2 = await _scene_at(2, [])
	check(is_equal_approx(s2.room_view.loop_targets().r12_pressure_low, lin.call(-10.0))
		and is_equal_approx(s2.room_view.loop_targets().r12_hum, lin.call(-8.0)), "s2: low pressure -10, hum -8")
	await free_scene(s2)
	# SEVER: a real commit, then the eighth line out
	var sc = await _scene_at(3, ["to_routing", "contacts"])
	var view = sc.room_view
	var r: R12Sim = sc.sim.room(ROOM)
	sc.dispatch("btn_sever")
	check(r.chosen() == "sever" and not view.sever_silence(), "SEVER: the hum still sounds before the lines go")
	for i in 7:
		view.on_sfx("line_out_%d" % (i + 1))
	var t7: Dictionary = view.loop_targets()
	check(is_equal_approx(t7.r12_hum, lin.call(-8.0) / 8.0) and t7.r12_pressure_low > 0.0, "seven out: an eighth of the hum, the bed on")
	check(is_equal_approx(view.loop_rates().r12_hum, lin.call(-8.0) / 8.0 / 0.5), "each eighth goes over half a second")
	view.on_sfx("line_out_8")
	var t8: Dictionary = view.loop_targets()
	var silent := true
	for id in ["r12_hum", "r12_pressure", "r12_pressure_low", "r12_surface", "r12_terminal"]:
		silent = silent and t8[id] == 0.0
	check(view.sever_silence() and silent, "after the eighth: every chamber loop at 0 (%s)" % [t8])
	check(is_equal_approx(view.loop_rates().r12_hum, lin.call(-8.0) / 8.0 / 0.5), "the last eighth also goes over half a second")
	sc.lines.clear()
	sc.pending_sfx.clear()
	sc.cur_text = ""
	sc.cur_story = false
	sc.dispatch("ending_next")
	check(r.ending_step() == 1 and view.sever_silence(), "the next page is silent until its first line types")
	view.tick(0.0)
	check(not view.sever_silence() and view.loop_targets().r12_pressure_low > 0.0, "its first line up: the bed comes back")
	await free_scene(sc)
	# CONTINUE's wide page: the wide dark under it; then the kitchen, silent for 3 s from its start
	var cc = await _scene_at(6, [])
	var cr: R12Sim = cc.sim.room(ROOM)
	cr.state.ending_step = 7
	cc.dispatch("ending_next")
	var cv = cc.room_view
	check(cr.tableau() == "end_b_wide" and cv.cur_tab == "end_b_wide", "on the wide page")
	cv.tick(0.0)
	check(is_equal_approx(cv.loop_targets().end_wide, lin.call(-14.0)) and not cv.breath_held(), "the wide dark under its lines")
	cc.lines.clear()
	cc.pending_sfx.clear()
	cc.cur_text = ""
	cc.cur_story = false
	cc.dispatch("ending_next")
	check(cr.tableau() == "m_kettle" and cv.cur_tab == "m_kettle", "on the kettle page")
	cv.tick(0.0)
	check(cv.breath_held() and cv.loop_targets().end_wide == 0.0, "the kitchen: silence from its start")
	cc.time += 3.1
	cv.tick(0.0)
	check(not cv.breath_held() and cv.loop_targets().end_wide > 0.0, "and the breath is let go after 3 s")
	await free_scene(cc)
	# the mid band: -6 dB, +2 after P25, +2 more after P26
	for n in 3:
		var sm = await _scene_at(n, [])
		check(is_equal_approx(sm.room_view.loop_targets().r12_mid, lin.call(-6.0 + 2.0 * n)),
			"s%d: r12_mid at %d dB" % [n, -6 + 2 * n])
		await free_scene(sm)

## The ending's 'continue' mark: once the page is done, pulsing (still with Motion off); and
## unanswered for 12 s it turns the page by itself, on both endings, to the end card.
func test_view_continue_mark() -> void:
	for n in [5, 6, 7, 8]:
		var scene = await _scene_at(n, [])
		var view = scene.room_view
		var r: R12Sim = scene.sim.room(ROOM)
		var step := r.ending_step()
		view.tick(0.0)
		check(view.page_finished() and view.cont_visible(), "ending %d: the finished page shows 'Go on'" % n)
		scene.sim.settings.motion = false
		check(is_equal_approx(view.cont_alpha(), 1.0), "ending %d: Motion off, 'Go on' is simply there" % n)
		scene.sim.settings.motion = true
		var t0: float = scene.time
		check(view.cont_alpha() < 0.05, "ending %d: with Motion it starts to fade in" % n)
		scene.time = t0 + 0.3
		check(view.cont_alpha() > 0.4 and view.cont_alpha() < 0.6, "ending %d: half in at 0.3 s" % n)
		var held := true
		for k in 9:
			scene.time = t0 + 0.6 + k * 0.25
			held = held and is_equal_approx(view.cont_alpha(), 1.0)
		check(held, "ending %d: then it stays, no pulse" % n)
		var vs: Dictionary = view.get_script().get_script_constant_map()
		check(vs.CAPTION_BAR.encloses(vs.CONT_RECT) and vs.CONT_RECT.end.x > vs.CAPTION_BAR.end.x - 30.0,
			"ending %d: 'Go on' at the subtitle bar's right end" % n)
		check(vs.CAPTION_X + vs.CAPTION_W / 2.0 < vs.CONT_RECT.position.x, "ending %d: her line wraps clear of it" % n)
		scene.time = t0 + 11.0
		view.tick(0.0)
		check(r.ending_step() == step and scene.sim.view == "room", "ending %d: no turn before 12 s" % n)
		scene.time = t0 + 12.1
		view.tick(0.0)
		if n in [7, 8]:
			check(scene.sim.view == "end", "ending %d: the last page turns to the end card by itself" % n)
		else:
			check(r.ending_step() == step + 1, "ending %d: the page turns by itself (%d)" % [n, r.ending_step()])
			check(not view.cont_visible(), "ending %d: the new page hides the mark while it plays" % n)
		await free_scene(scene)

## The ending's caption never runs out of step with its plate: mid-page a click advances her
## lines (the core's), never the page; once the page is done a click turns it.
func test_view_caption_desync() -> void:
	for n in [5, 6]:
		var scene = await _scene_at(n, [])
		var view = scene.room_view
		var r: R12Sim = scene.sim.room(ROOM)
		scene.dispatch("ending_next")
		var step := r.ending_step()
		var page: Array = []
		for l in R12Sim.steps(r.chosen())[step].lines:
			page.append(l[1])
		check(scene.chain_active() and not view.page_finished(), "ending %d: mid-caption on page %d" % [n, step])
		check(view.action_at(Vector2(724, 543)) == "", "ending %d: mid-caption a click is not the room's" % n)
		var guard := 0
		while scene.chain_active() and guard < 8:
			scene.click(Vector2(724, 543))
			check(r.ending_step() == step, "ending %d: a click mid-caption leaves the page (%d)" % [n, r.ending_step()])
			check(scene.cur_text == "" or scene.cur_text in page, "ending %d: the shown line is this page's (%s)" % [n, scene.cur_text])
			guard += 1
		# her lines all read, a sound still to come: the caption cannot desync, so the click is the page's
		if not scene.chain_active() and scene.lines.is_empty() and not scene.pending_sfx.is_empty():
			check(view.captions_done() and view.action_at(Vector2(724, 543)) == "ending_next", "ending %d: lines read, sounds pending: next" % n)
		# the page's sounds and its last line's read time
		scene.pending_sfx.clear()
		scene.lines.clear()
		scene.cur_text = ""
		scene.cur_story = false
		scene.time += 1.0
		view.tick(0.0)
		check(view.page_finished() and view.action_at(Vector2(724, 543)) == "ending_next", "ending %d: the finished page turns on a click" % n)
		scene.click(Vector2(724, 543))
		check(r.ending_step() == step + 1, "ending %d: and the click turns it" % n)
		await free_scene(scene)

## The eye in the window: the pupil follows R12Sim.pupil_offset() (snapped on entry, eased with
## Motion, still without); the arrival blink sweeps the lid when its line goes up, full alpha,
## shut the whole time with Motion off; and it holds the chamber's breath.
func test_view_eye() -> void:
	for n in [0, 1, 2, 4]:
		var scene = await _scene_at(n, [])
		var want: Vector2 = scene.sim.room(ROOM).pupil_offset()
		check(want == (Vector2(-150, 12) if n == 1 else (Vector2(95, 40) if n >= 2 else want)), "jump %d: the sim's look" % n)
		check(scene.room_view.gaze_at == want, "jump %d: the eye snapped to %s (%s)" % [n, want, scene.room_view.gaze_at])
		await free_scene(scene)
	# a preview turns it: 0.8 s eased in and out with Motion, at once without
	var sc = await _scene_at(1, ["to_routing", "plate_sever"] + PATCH_SEVER)
	var v = sc.room_view
	sc.sim.settings.motion = true
	check(v.gaze_at == Vector2(-150, 12), "P25: on the chair")
	sc.dispatch("preview_sever")
	check(v.look_running() and v.gaze_at == Vector2(-150, 12), "the preview: the eye starts to turn")
	var tl: float = sc.time
	sc.time = tl + 0.4
	v.tick(0.0)
	check(v.gaze_at.x > -60.0 and v.gaze_at.x < 0.0, "half way at 0.4 s (%s)" % [v.gaze_at])
	sc.time = tl + 0.1
	v.tick(0.0)
	check(v.gaze_at.x < -130.0, "eased: slow out of the chair (%s)" % [v.gaze_at])
	sc.time = tl + 0.81
	v.tick(0.0)
	check(v.gaze_at == Vector2(95, 40) and not v.look_running(), "and on the routing wall at 0.8 s")
	await free_scene(sc)
	var so = await _scene_at(1, ["to_routing", "plate_sever"] + PATCH_CONTINUE)
	so.sim.settings.motion = false
	so.dispatch("preview_continue")
	check(so.room_view.gaze_at == Vector2(95, 40) and not so.room_view.look_running(), "Motion off: it is simply where it looks")
	await free_scene(so)
	# arrival: it stays where it was until its line goes up, then turns to the door
	var sa = new_scene("user://r12_view_test.json")
	await process_frame
	sa.tide_jump(9, "R11")
	sa.sim.state.visited.erase(ROOM)
	sa.sim.settings.motion = false
	sa.dispatch("go:R12")
	var va = sa.room_view
	check(va.gaze_at == Vector2.ZERO and va.look_waits.size() == 1, "arrival: centred, the turn waits for its line")
	sa.cur_text = EYE_DOOR
	va.tick(0.0)
	check(va.gaze_at == Vector2(0, 40), "the line up: on the door")
	await free_scene(sa)
	# the arrival blink
	for m in [true, false]:
		var scene = new_scene("user://r12_view_test.json")
		await process_frame
		scene.tide_jump(9, "R11")
		scene.sim.state.visited.erase(ROOM)
		scene.sim.settings.motion = m
		scene.dispatch("go:R12")
		var view = scene.room_view
		view.consume_click(Vector2(700, 500))
		check(view.blink_waits.size() == 1 and view.blink_k() == 0.0, "motion %s: the blink waits for its line" % m)
		scene.cur_text = BLINK_LINE
		view.tick(0.0)
		var t0: float = scene.time
		check(view.breath_held(), "motion %s: the blink holds the chamber's breath" % m)
		var lt: Dictionary = view.loop_targets()
		var silent := true
		for id in lt:
			silent = silent and lt[id] == 0.0
		check(silent, "motion %s: every loop silent in the held breath" % m)
		scene.time = t0 + 0.5 + 0.1
		check(view.blink_k() == 1.0 and is_equal_approx(view.lid_bottom(), 418.0), "motion %s: shut all the way" % m)
		scene.time = t0 + 0.1
		check((view.blink_k() > 0.0 and view.blink_k() < 1.0) if m else view.blink_k() == 1.0,
			"motion %s: closing (%s)" % [m, view.blink_k()])
		scene.time = t0 + 1.6
		check(view.blink_k() == 0.0 and not view.breath_held(), "motion %s: open again, breath back" % m)
		await free_scene(scene)

## P26's previews in the window: shown on the window glance, the SEVER lamps going out one by
## one then the bowls, the CONTINUE feed moving to A.M. and the oilskin coming up; then gone.
func test_view_window_preview() -> void:
	for route in ["sever", "continue"]:
		var scene = await _scene_at(1, ["to_routing", "plate_sever"] + (PATCH_SEVER if route == "sever" else PATCH_CONTINUE)
			+ ["preview_" + route])
		var view = scene.room_view
		check(view.win_route == route and view.window_preview_a() == 0.0, "%s: waiting for the glance" % route)
		check(scene.pending_glance.get("target") == "window_" + route, "%s: the glance is pending" % route)
		check(not view.start_glance("window_" + route, Rect2(474, 96, 500, 290)), "%s: not from the close-up" % route)
		for i in 2:
			scene.dispatch("back")
		check(scene.sim.room(ROOM).local_view == "room" and view.start_glance("window_" + route, Rect2(474, 96, 500, 290)),
			"%s: the room shows the glance itself" % route)
		scene.sim.settings.motion = true
		var t0: float = scene.time
		scene.time = t0 + 1.0
		check(view.window_preview_a() > 0.99, "%s: up in the window" % route)
		if route == "sever":
			check(view.pupil_lamps() == [true, true], "sever: two lamps lit in the pupil")
			scene.time = t0 + 1.2
			check(view.window_lamps_out() == 1, "sever: the first portrait lamp out (%d)" % view.window_lamps_out())
			scene.time = t0 + 3.0
			check(view.pupil_lamps() == [false, true], "sever: one pupil lamp out (%s)" % [view.pupil_lamps()])
			scene.time = t0 + 4.5
			check(view.window_lamps_out() == 8, "sever: all eight out")
			check(view.pupil_lamps() == [false, false], "sever: both pupil lamps out")
		else:
			check(view.window_feed()[0] == 0.0, "continue: the feed at E.V.")
			check(view.pupil_lamps() == [true, true], "continue: his lamp and the kitchen's in the pupil")
			scene.time = t0 + 4.6
			check(view.window_feed() == [1.0, 1.0], "continue: the feed at A.M., the oilskin up")
			check(view.pupil_lamps() == [false, true], "continue: his out, the kitchen's lit")
		scene.time = t0 + 9.0
		view.tick(0.0)
		check(view.win_route == "" and view.window_preview_a() == 0.0, "%s: gone again" % route)
		scene.sim.settings.motion = false
		view.win_route = route
		view.win_t0 = scene.time
		scene.time += 4.0
		check(view.window_preview_a() == 1.0 and (view.window_lamps_out() == 8 if route == "sever" else view.window_feed() == [1.0, 1.0]),
			"%s: Motion off, the still state" % route)
		await free_scene(scene)
	# the completing preview also draws the surface back
	var sc = await _scene_at(1, ["to_routing", "plate_sever"] + PATCH_SEVER + ["preview_sever"] + PATCH_CONTINUE
		+ ["preview_continue"])

	var v = sc.room_view
	check(v.withdraw_pending, "P26: the surface waits for the glance to draw back")
	for i in 2:
		sc.dispatch("back")
	v.start_glance("window_continue", Rect2(474, 96, 500, 290))
	check(not v.withdraw_pending and v.withdraw_t0 >= 0.0 and v.win_route == "continue", "the glance: the preview and the withdrawal")
	await free_scene(sc)

## A held breath keyed to a sound starts `lead` s before it (the SEVER throat).
func test_view_hold_breath() -> void:
	var scene = await _scene_at(5, [])
	var view = scene.room_view
	scene.dispatch("ending_next")
	check(view.breath_waits.size() == 1 and not view.breath_held(), "SEVER step 1: a breath waits for the throat")
	view.on_sfx_pending("throat", 2.0)
	check(not view.breath_held(), "2 s before the throat: not yet")
	view.on_sfx_pending("throat", 1.5)
	check(view.breath_held() and view.breath_waits.is_empty(), "1.5 s before: held")
	var lt: Dictionary = view.loop_targets()
	check(lt.r12_hum == 0.0 and lt.r12_pressure_low == 0.0, "held: the chamber silent")
	scene.time += 1.6
	check(not view.breath_held(), "and let go after 1.5 s")
	await free_scene(scene)

## Legibility: the countersign plaque and the c_frames strip print every word of the strip in
## full (14 px floor, wrapped, never cut); card faces are at least 18 px.
func test_view_legibility() -> void:
	var vs: Dictionary = load("res://game/rooms/R12/R12_view.gd").get_script_constant_map()
	check(vs.CARD_BODY >= 18, "card body text at least 18 px")
	var scene = await _scene_at(1, ["to_frames"])
	var view = scene.room_view
	var lay: Dictionary = view.countersign_layout()
	check(lay.size >= 14 and " ".join(lay.rows) == " ".join(R12Sim.STRIP_DONE),
		"the countersign plaque: every word, at %d px (%s)" % [lay.size, lay.rows])
	var terminal := Rect2(130, 740, 340, 170)
	check(terminal.encloses(lay.rect), "the plaque on the terminal's face (%s)" % [lay.rect])
	for row in lay.rows:
		check(view._tw(str(row), lay.size, Ink.serif()) <= lay.rect.size.x - 16.0, "the plaque row fits: %s" % row)
	scene.dispatch("frame_body")
	var st: Dictionary = view.strip_layout()
	var joined := []
	for row in st.rows:
		joined.append(row[1])
	check(st.size >= 14 and " ".join(joined) == " ".join(R12Sim.STRIP_DONE), "the strip: every word (%s)" % [joined])
	for row in st.rows:
		check(view._tw(str(row[1]), st.size, Ink.serif()) <= st.rect.size.x - 16.0, "the strip row fits: %s" % row[1])
	check(st.rect.end.y < 700.0, "the strip clear of the switch")
	await free_scene(scene)
	var fit: Dictionary = load("res://game/rooms/R12/R12_view.gd").fit_rows(["A SHORT ONE", "AND A MUCH LONGER LINE THAN FITS"], 120.0, Ink.serif())
	check(fit.size == 14 and " ".join(fit.rows) == "A SHORT ONE AND A MUCH LONGER LINE THAN FITS", "fit_rows wraps at the floor, never cuts")

## P25's rack: every card's whole face at CARD_BODY (>= 18 px), wrapped inside the card, never
## cut, no category header; the longest trace the whitelist can make, turned, still fits.
func test_view_rack_faces() -> void:
	var vs: Dictionary = load("res://game/rooms/R12/R12_view.gd").get_script_constant_map()
	for trace in [TRACE, ["recording_played", "charts_aligned", "recording_played"]]:
		for turned in [false, true]:
			var scene = await _scene_at(0, ["to_frames", "frame_body"])
			scene.sim.state.p05_trace = trace.duplicate()
			scene.sim.set_flag("t1x_turned", turned)
			var view = scene.room_view
			var r: R12Sim = scene.sim.room(ROOM)
			for cid in R12Sim.CARD_IDS:
				var rows: Array = view.tab_rows(cid)
				var words := []
				for row in rows:
					words.append(row[0])
					check(view._tw(row[0], vs.CARD_BODY, Ink.serif()) <= vs.TAB.x - 2.0 * vs.TAB_PAD,
						"%s: '%s' fits the card's width" % [cid, row[0]])
					check(not "…" in str(row[0]) and not "..." in str(row[0]), "%s: no ellipsis" % cid)
				check(" ".join(words) == " ".join(r.card_text(cid)), "%s: the whole face, in order (%s)" % [cid, words])
				check(rows.back()[1] + 6.0 <= vs.TAB.y, "%s (%s, turned %s): the last row inside the card (%s)" % [cid, trace, turned, rows.back()[1]])
				for cat in ["MOVEMENT", "POSITION", "CONTRACT"]:
					check(not cat in " ".join(words), "%s: no %s header on the rack card" % [cid, cat])
			check(vs.CARD_BODY >= 18, "rack faces at 18 px or more")
			await free_scene(scene)
	# the rack's slots stay clear of the subtitles and of the strip column
	for h in vs.FRAMES_CONTROLS:
		if str(h[0]).begins_with("rack_"):
			check(h[1].end.y < 994.0 and h[1].end.x < 1110.0 and h[1].size == Vector2(130, 360), "%s: a tall slot" % h[0])
			check(not "MOVEMENT" in h[2] and not "POSITION" in h[2] and not "CONTRACT" in h[2], "%s: its label names no category" % h[0])

## P26's patch field on the real scene: the sockets answer as patches while a cord is in hand,
## the hover names the patch, its rect is the socket's; clicks patch; a wrong PREVIEW lights the
## plate. No control of c_routing or c_final overlaps another.
func test_view_patch() -> void:
	var scene = await _scene_at(1, ["to_routing", "plate_sever"])
	var view = scene.room_view
	var r: R12Sim = scene.sim.room(ROOM)
	var rect: Rect2 = view.control_rect("jack_open")
	check(view.action_at(rect.get_center()) == "jack_open", "an empty hand: the socket is a look")
	scene.click(view.control_rect("cord_feed_a").get_center())
	check(r.held_cord() == "feed_a", "a click on its contact lifts the FEED A cord")
	check(view.action_at(rect.get_center()) == "patch:feed_a:open" and view.hover_at(rect.get_center()) == "patch:feed_a:open",
		"with it in hand the socket is the patch")
	check(view.label_for("patch:feed_a:open") == "FEED A into OPEN" and view.control_rect("patch:feed_a:open") == rect,
		"the patch's label and rect")
	scene.click(rect.get_center())
	check(r.patch_of("feed_a") == "open" and r.held_cord() == "", "a click on OPEN patches it")
	scene.lines.clear()
	scene.cur_text = ""
	scene.cur_story = false
	scene.click(view.control_rect("preview_sever").get_center())
	check(r.incomplete_route == "sever" and not r.previewed("sever") and scene.pending_glance.is_empty(),
		"a wrong patch: ROUTE INCOMPLETE on the plate, no glance")
	var band: Rect2 = view.incomplete_rect("sever")
	check(Rect2(110, 100, 540, 360).encloses(band), "the lit band sits on the SEVER plate")
	for v in ["c_routing", "c_final"]:
		var rows: Array = view.closeup_controls(v)
		for i in rows.size():
			for j in range(i + 1, rows.size()):
				check(not rows[i][1].intersects(rows[j][1]), "%s: %s and %s don't overlap" % [v, rows[i][0], rows[j][0]])
	# every plug sits inside its cord's or its socket's control
	for c in R12Sim.CORDS:
		var j: String = r.patch_of(c)
		var where: Rect2 = view.control_rect("cord_" + c) if j == "home" else view.control_rect("jack_" + j)
		check(where.has_point(view.plug_at(c)), "%s: its plug drawn inside its %s" % [c, "contact" if j == "home" else "socket"])
	await free_scene(scene)

## P27's panel: the eye's strip across the top, the six panels 120 px lower than the first
## plate had them, the knife switches below them; the eye looks down at the switches.
func test_view_final() -> void:
	var vs: Dictionary = load("res://game/rooms/R12/R12_view.gd").get_script_constant_map()
	var old := {"contacts": Rect2(100, 140, 440, 260), "look_lamps": Rect2(560, 140, 328, 260),
		"bridge_seat": Rect2(908, 140, 440, 260), "tray": Rect2(100, 440, 440, 170), "preview": Rect2(604, 460, 240, 120),
		"look_handle": Rect2(908, 440, 440, 170), "btn_sever": Rect2(100, 700, 600, 200), "btn_continue": Rect2(748, 700, 600, 200)}
	var ids := []
	for h in vs.FINAL_CONTROLS:
		ids.append(h[0])
		var o: Rect2 = old[h[0]]
		if h[0] in ["btn_sever", "btn_continue"]:
			# the switches go as low as the subtitles allow under the lowered panels: same size
			check(h[1].size == o.size and h[1].position.x == o.position.x and h[1].position.y > o.position.y
				and h[1].end.y <= 994.0, "%s: same size, lower, clear of the subtitles (%s)" % [h[0], h[1]])
		else:
			check(h[1] == Rect2(o.position + Vector2(0, 120), o.size), "%s: the old rect shifted 120 px down (%s)" % [h[0], h[1]])
	check(ids == R12Sim.FINAL_CONTROLS, "the c_final controls, in the sim's order")
	check(vs.FINAL_STRIP == Rect2(0, 0, 1448, 300), "the eye's strip")
	check(ResourceLoader.exists("res://assets/rooms/R12/c_final_r2.png"), "the r2 plate exists")
	var scene = await _scene_at(2, ["to_routing", "contacts"])
	var view = scene.room_view
	scene.time += 1.0
	view.tick(0.0)
	check(scene.sim.room(ROOM).gaze() == "final" and view.gaze_at == Vector2(0, 60) or view.look_running(),
		"in c_final the eye turns down to the switches")
	scene.time += 1.0
	view.tick(0.0)
	check(view.gaze_at == Vector2(0, 60), "and is there (%s)" % [view.gaze_at])
	check(vs.FINAL_STRIP.has_point(view.final_pupil_centre()), "the pupil inside the strip (%s)" % [view.final_pupil_centre()])
	for route in R12Sim.ROUTES:
		var band: Rect2 = view.knife_band(route)
		var btn: Rect2 = view.control_rect("btn_" + route)
		check(btn.encloses(band), "%s: its lettering band on its switch plate" % route)
	await free_scene(scene)

## SEVER's first page: the frames wall, eight indicators each over 120 px across, every one on
## the canvas with its plate; each line_out_N fx puts out indicator N (and only the fx does);
## the plate's brass fill goes 0.6 s later, at once with Motion off.
func test_view_sever_wall() -> void:
	for m in [true, false]:
		var sc = await _scene_at(3, ["to_routing", "contacts"])
		sc.sim.settings.motion = m
		sc.dispatch("btn_sever")
		var view = sc.room_view
		var vs: Dictionary = view.get_script().get_script_constant_map()
		check(view.cur_tab == "c_sever_wall" and view.wall_dark() == 0, "motion %s: the frames wall, all eight lit" % m)
		check(vs.TIMED_FX.has("line_out_1") and vs.TIMED_FX.has("line_out_8"), "the line_out fx are held to their moment")
		for i in 8:
			var at: Vector2 = view.sever_wall_centre(i)
			check(2.0 * vs.WALL_R >= 120.0 and at.x - vs.WALL_R >= 0.0 and at.x + vs.WALL_R <= 1448.0 and at.y > 80.0,
				"indicator %d: over 120 px across, on the canvas (%s)" % [i + 1, at])
			if i > 0:
				check(at.x - view.sever_wall_centre(i - 1).x >= 152.0, "indicator %d: its plate clear of the last" % (i + 1))
		view.on_sfx("line_out_1")
		check(view.wall_dark() == 0, "the sound alone does not put a lamp out")
		for k in range(1, 9):
			view.play_fx("line_out_%d" % k, {"delay": 0.0})
			check(view.wall_dark() == k, "motion %s: after line_out_%d exactly %d dark (%d)" % [m, k, k, view.wall_dark()])
			check(view.wall_unfilled(k - 1) == (not m), "motion %s: indicator %d's letters %s" % [m, k, "hollow at once" if not m else "still brass"])
			sc.time += 0.61
			check(view.wall_unfilled(k - 1), "motion %s: indicator %d's letters hollow 0.6 s on" % [m, k])
			for j in range(k, 8):
				check(not view.wall_unfilled(j), "motion %s: indicator %d still lit and filled" % [m, j + 1])
		await free_scene(sc)
	# played in real time: the timed fx put them out in order, on their sounds' moments
	var rt = await _scene_at(3, ["to_routing", "contacts"])
	rt.dispatch("btn_sever")
	var rv = rt.room_view
	var seen := []
	for i in 400:
		rt._process(0.05)
		if seen.size() < rv.wall_dark():
			seen.append([rv.wall_dark(), snappedf(rt.time, 0.05)])
	check(rv.wall_dark() == 8 and seen.size() == 8, "in real time all eight go out, one at a time (%s)" % [seen])
	await free_scene(rt)

## CONTINUE's morning: the wash rises over 2 s from the page's start and never falls; Motion off
## it is simply there.
func test_view_morning() -> void:
	for m in [true, false]:
		var scene = await _scene_at(6, [])
		var r: R12Sim = scene.sim.room(ROOM)
		scene.sim.settings.motion = m
		r.state.ending_step = 6
		scene.dispatch("ending_next")
		var view = scene.room_view
		check(view.cur_tab == "a_morning", "motion %s: the morning page" % m)
		var last := -1.0
		var rising := true
		var t0: float = scene.time
		for k in 30:
			scene.time = t0 + 0.1 * k
			var w: float = view.morning_k()
			rising = rising and w >= last
			last = w
		check(rising and is_equal_approx(last, 1.0), "motion %s: it only brightens, to full" % m)
		scene.time = t0 + 1.0
		check(is_equal_approx(view.morning_k(), 0.5) if m else is_equal_approx(view.morning_k(), 1.0),
			"motion %s: half way at 1 s / there at once (%s)" % [m, view.morning_k()])
		check(vs_morning() == 0.25, "the wash is paper at 0.25")
		await free_scene(scene)

func vs_morning() -> float:
	return load("res://game/rooms/R12/R12_view.gd").get_script_constant_map().MORNING_WASH

## Every page of both endings, played in real time: once its lines are read, 'Go on' is up and a
## click at (724, 500) on the plate turns the page (the last to the end card).
func test_view_page_turns() -> void:
	for choice in ["sever", "continue"]:
		var scene = await _scene_at(2, ["to_routing", "contacts"])
		var r: R12Sim = scene.sim.room(ROOM)
		var view = scene.room_view
		if choice == "sever":
			for a in ["tray", "contacts", "preview", "btn_sever"]:
				scene.dispatch(a)
		else:
			for a in ["bridge_seat", "preview", "btn_continue"]:
				scene.dispatch(a)
		var n := R12Sim.steps(choice).size()
		var turned := 0
		for step in n:
			check(r.ending_step() == step and scene.sim.view == "room", "%s: on page %d" % [choice, step])
			var guard := 0
			while not view.captions_done() and guard < 900:
				scene._process(0.05)
				guard += 1
			check(view.captions_done(), "%s page %d (%s): its lines are read" % [choice, step, r.tableau()])
			scene._process(0.0)
			check(view.cont_visible(), "%s page %d (%s): 'Go on' as soon as the lines are read" % [choice, step, r.tableau()])
			check(view.action_at(Vector2(724, 500)) == "ending_next", "%s page %d (%s): the plate answers" % [choice, step, r.tableau()])
			scene.click(Vector2(724, 500))
			if step < n - 1:
				check(r.ending_step() == step + 1, "%s page %d (%s): a click at (724, 500) turns it (%d)" % [choice, step, R12Sim.steps(choice)[step].tableau, r.ending_step()])
			else:
				check(scene.sim.view == "end", "%s: the last page turns to the end card" % choice)
			if r.ending_step() == step + 1 or scene.sim.view == "end":
				turned += 1
			else:
				break
		check(turned == n, "%s: every page turned by a click on the plate (%d of %d)" % [choice, turned, n])
		await free_scene(scene)
