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
const ARRIVAL_STORY := [
	"The chamber. A chair faces an instrument. Nothing in here is dusty.",
	"Every arm of the instrument ends where a part of a seated person would be. Head. Hands. Feet.",
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
	"routing": ["Before choosing, make sure you know what each choice does.",
		"Each plate has a PREVIEW key. Press it, then watch the window.",
		"Venn said breaking the line ends every trace. The witness test said someone must remain. The previews show what that means.",
		"Press PREVIEW on the SEVER plate and PREVIEW on the CONTINUE plate, and watch the window each time."],
	"decide": ["Both choices are ready. The chamber is waiting for your hands.",
		"The yoke goes across the feed contacts. The bridge goes in your terminal. Preview before you confirm.",
		"The window showed me: SEVER puts out the eight lamps and the bowls; CONTINUE moves the feed to A.M. and empties his coat.",
		"To leave: yoke on the contacts, preview, BREAK CONNECTION AND LEAVE. To stay: bridge in your terminal, preview, REMAIN AS WITNESS."],
	"finale": ["I've chosen. All that's left is to watch it happen.",
		"I've chosen. All that's left is to watch it happen.",
		"I've chosen. All that's left is to watch it happen.",
		"I've chosen. All that's left is to watch it happen."],
}
const P25_ACTIONS := ["to_frames", "frame_body", "rack_trace", "f_body", "rack_position", "f_place",
	"rack_identity", "f_name", "switch", "route"]
const P26_ACTIONS := ["back", "back", "to_routing", "plate_sever", "preview_sever", "preview_continue"]
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
	else:
		print("SKIP: R12 view_checks: the R12 view does not yet declare rects for every sim hotspot (view team)")

# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
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
	check(st.slice(0, 5) == ARRIVAL_STORY, "the arrival chain, the blink line last (%s)" % [st])
	var says_at := {}
	for e2 in ev:
		if e2.type == "say":
			says_at[e2.text] = _d(e2.delay)
	check(says_at.get(BLINK_LINE) == 9.0 and says_at.get("Mine.") == 7.2, "the blink line at 9.0, after 'Mine.' at 7.2")
	check(says_at.get("The bridge is in my pocket. The door gave it back.") == 11.4, "the bridge line after the blink")
	check(fx_count(ev, "notice") == 1 and fx(ev, "notice").get("which") == "name_frame", "notice fx: the name frame")
	check(r12(g).has_seen("chamber"), "arrival notes the chamber")
	check(bridges(g) == 1 and "The bridge is in my pocket. The door gave it back." in says(ev),
		"the bridge net hands back a missing bridge on arrival")
	check(has_ev(ev, "fx", "item_added"), "the bridge arrives with item_added")
	g.dispatch("go:R11")
	ev = g.dispatch("go:R12")
	check(story(ev).is_empty() and fx_count(ev, "notice") == 0, "the arrival chain plays once")
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
	check(says(ev) == "A MOVEMENT card: 'Turned the zero wheel. Opened the hatch. Looked down the stair.' And under them: 'Observer has not yet looked behind her.'",
		"the trace card reads the stored trace (%s)" % says(ev))
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
	check(says(ev) == "A POSITION card: 'Ninth position. Centre of the station outline.'" and r.has_seen("card_position"), "position card")
	ev = g.dispatch("rack_position")
	check(says(ev) == "Back in the rack." and r.held_card() == "" and has_ev(ev, "sfx", "card_return"), "lift twice puts it back")
	check(says(g.dispatch("rack_position")) == "A POSITION card: 'Ninth position. Centre of the station outline.'",
		"a second lift reads the card again")
	ev = g.dispatch("rack_identity")
	check(says(ev) == "A CONTRACT card: 'Miss Ada Mercer, cataloguer. Requested by E. Venn.'" and r.held_card() == "identity",
		"lifting another card swaps it silently")
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
	check(r.card_header("trace") == "MOVEMENT · A. MERCER" and r.card_header("identity") == "CONTRACT · A. MERCER",
		"card headers")
	check(r.card_text("position") == ["Ninth position. Centre of the station outline."], "position card text")
	check(r.card_text("trace") == r.body_card_lines(), "the trace card is the body card")
	check(not g.has_item("trace") and g.state.inventory == [BRIDGE], "the cards never enter the inventory")

## The decoy MOVEMENT runs: for every trace record_move can leave (consecutive duplicates
## collapsed, 1 to 8 events) over a sample of the whitelist, neither decoy repeats the trace or
## the other decoy; with three or more events they are the two swaps whenever those differ.
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
				var a: Array = t.duplicate()
				a[0] = t[1]
				a[1] = t[0]
				if a != t and d[0] != a:
					bad.append(["first swap", t])
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
	check(r.movement_of("trace_a") == ["hatch_opened", "zero_turned", "zero_turned"]
		and r.movement_of("trace_b") == ["zero_turned", "zero_turned", "hatch_opened"], "decoys: the two swaps")
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
	check(r.card_text("position_b") == ["Eighth position. Seat beside the window."]
		and r.card_text("identity_b") == ["Miss Ada Mercer, cataloguer. Requested by S. Rook."], "decoy faces")
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
	check(says(h.dispatch("rack_trace")).ends_with("'Observer has looked behind her once.'"), "the turned fourth line on the card")

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
	check(r.chosen() == "continue" and r.ending_step() == 9, "ending_step clamps to the choice's steps")
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
	check(says(p.dispatch("plate_continue")) == "Two plates, SEVER and CONTINUE, each with a PREVIEW key. Nothing to sign, nothing to slot. It only wants me to watch."
		and q.local_view == "c_routing", "first c_routing entry")
	p.dispatch("back")
	check(says(p.dispatch("cards")) == "The routing plates." and q.local_view == "c_routing", "later entries")
	p.dispatch("back")
	for h in ["handle", "yoke_tray", "contacts", "bridge_seat"]:
		check(says(p.dispatch(h)) == LATER and q.local_view == "routing", "after P25, %s waits for P26" % h)

func _routing_game() -> GameSim:
	var g := p25_game()
	play(g, ["back", "back", "to_routing", "plate_sever"])
	return g

## P26 completes when both routes have been previewed, in either order, and only then: a
## repeated preview of one route never does; the looks never do.
func test_p26_both_previews() -> void:
	check(R12Sim.ROUTING_CONTROLS == ["look_sever", "look_continue", "preview_sever", "preview_continue"],
		"c_routing: two looks and two PREVIEW keys, no cards, no CONFIRM")
	for order in [["preview_sever", "preview_continue"], ["preview_continue", "preview_sever"]]:
		var g := _routing_game()
		var r := r12(g)
		var ev := g.dispatch(order[0])
		check(not g.flag("P26") and not r.state.p26_complete and g.checkpoint.is_empty(), "%s alone: not yet" % order[0])
		ev = g.dispatch(order[0])
		check(not g.flag("P26") and g.checkpoint.is_empty(), "%s twice: still not" % order[0])
		for c in ["look_sever", "look_continue"]:
			g.dispatch(c)
		check(not g.flag("P26"), "%s + looks: still not" % order[0])
		var before := flags_json(g)
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
	h.dispatch("preview_continue")
	var q := roundtrip(h)
	play(q, ["back", "back", "to_routing", "plate_sever"])
	q.dispatch("preview_sever")
	check(q.flag("P26"), "one preview, a save, the other: P26")

func test_p26_previews() -> void:
	var g := _routing_game()
	var r := r12(g)
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
	ev = g.dispatch("preview_continue")
	check(story(ev).slice(0, 3) == CONTINUE_PREVIEW, "first CONTINUE preview")
	check(sfx_list(ev).slice(0, 2) == [["preview_key", 0.0], ["preview_move", 0.3]] and fx(ev, "preview").get("route") == "continue", "CONTINUE preview sounds/fx")
	check(fx(ev, "window_preview").get("route") == "continue" and fx(ev, "glance").get("target") == "window_continue",
		"the window shows the CONTINUE preview")
	check(says(g.dispatch("preview_continue")) == "The eight stay lit. His lamp out, mine on.", "repeat CONTINUE preview")
	check(says(g.dispatch("look_sever")) == "SEVER. Subject lines one to eight, the witness feed, the outer door. Each with a lamp.", "look_sever")
	check(says(g.dispatch("look_continue")) == "CONTINUE. Subject lines one to eight, the witness feed from E.V. to A.M., the outer door.", "look_continue")

func test_p26_checkpoint() -> void:
	var g := _routing_game()
	var r := r12(g)
	g.dispatch("preview_sever")
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
## The pupil's offset is a pure function of the flags (and the seated bridge): centred before
## P25, toward the chair after, toward her terminal once P26 is done and the bridge is in it.
func test_eye_gaze() -> void:
	check(R12Sim.PUPIL_OFFSET == {"centre": [0, 0], "chair": [-40, 0], "terminal": [40, 0]}, "the three offsets")
	var g := fresh()
	var r := r12(g)
	check(r.gaze() == "centre" and r.pupil_offset() == Vector2.ZERO, "before P25: centred")
	play(g, P25_ACTIONS)
	check(r.gaze() == "chair" and r.pupil_offset() == Vector2(-40, 0), "P25: toward the chair")
	play(g, P26_ACTIONS)
	check(r.gaze() == "chair", "P26 alone: still the chair")
	play(g, ["back", "bridge_seat", "bridge_seat"])
	check(r.bridge_seated() and r.gaze() == "terminal" and r.pupil_offset() == Vector2(40, 0), "the bridge seated: toward her terminal")
	g.dispatch("bridge_seat")
	check(not r.bridge_seated() and r.gaze() == "chair", "the bridge out: back to the chair")
	# by flags alone, no actions
	var f := with_flags(["P24", "P25"], ROOM)
	r12(f).reconcile()
	check(r12(f).gaze() == "chair", "P25 by flag: the chair")
	for n in [0, 1, 2, 3, 4, 6]:
		var j := _jumped(n)
		var want := "centre" if n == 0 else ("terminal" if n in [4, 6] else "chair")
		check(r12(j).gaze() == want, "jump %d: %s (%s)" % [n, want, r12(j).gaze()])
		check(r12(roundtrip(j)).gaze() == want, "jump %d: the gaze survives a save" % n)

## The surface blinks exactly twice in a game: on the first arrival (with the line after
## 'Mine.') and when the strip types NINTH OBSERVER LOCATED. Never again, saved.
func test_blinks() -> void:
	var g := _stair()
	var r := r12(g)
	var blinks := []
	var ev := g.dispatch("go:R12")
	blinks.append_array(_fxs(ev, "blink"))
	check(blinks.size() == 1 and blinks[0].get("which") == "arrival" and _d(blinks[0].get("delay")) == 9.0
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
	for i in 10:
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
	check(hb.size() == 1 and _d(hb[0].seconds) == 1.5 and _d(hb[0].delay) == 9.0 and hb[0].get("line") == BLINK_LINE,
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
	# no other page holds its breath
	var others := 0
	for i in 11:
		others += _fxs(s.dispatch("ending_next"), "hold_breath").size()
	check(others == 0, "only the throat page holds its breath")

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
		"Above the frames the eight indicators go out. Not together. One, and a wait, and the next."], "SEVER step 0")
	var expect := [["handle_pull", 0.0], ["line_out_1", 3.0], ["line_out_2", 3.8], ["line_out_3", 4.9],
		["line_out_4", 6.3], ["line_out_5", 8.0], ["line_out_6", 10.1], ["line_out_7", 12.6], ["line_out_8", 16.2]]
	check(sfx_list(ev) == expect, "the eight lines go out in turn, each wait longer (%s)" % [sfx_list(ev)])
	var gaps := []
	for i in range(2, expect.size()):
		gaps.append(_d(expect[i][1] - expect[i - 1][1]))
	for i in range(1, gaps.size()):
		check(gaps[i] > gaps[i - 1], "gap %d after line %d is longer than the one before (%s)" % [i, i + 1, gaps])
	var e := fx(ev, "ending")
	check(e.get("choice") == "sever" and e.get("step") == 0 and e.get("tableau") == "c_sever" and e.get("change") == "", "ending fx step 0")
	check(g.value("ending_choice") == "" and g.view == "room", "the end card waits for the ending")
	check(r.hint_frozen() and r.objective() == "finale", "the hint freezes in the ending")

func test_endings_sever_and_replay() -> void:
	var g := game_at(9, ROOM)
	var r := r12(g)
	play(g, P25_ACTIONS)
	play(g, P26_ACTIONS)
	var ev := play(g, P27_SEVER)
	check(r.chosen() == "sever" and not has_ev(ev, "fx", "tide") and g.tide() == 9, "SEVER at tide IX: tide holds 9")
	var tabs := ["c_sever"]
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
	check(tabs == ["c_sever", "m_funnels", "m_diaphragm", "m_jars", "m_spoon", "m_bed", "m_pen", "b_dark", "a_day",
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
	for i in 9:
		ev = g.dispatch("ending_next")
		tabs.append(fx(ev, "ending").get("tableau"))
		check(g.view == "room" and r.ending_step() == i + 1, "CONTINUE step %d" % (i + 1))
	check(tabs == ["c_continue", "m_funnel_venn", "m_coat", "a_sit", "end_b_terminal_1", "m_cup", "end_b_terminal_2",
		"a_morning", "end_b_wide", "end_b_cover"], "the CONTINUE tableaux (%s)" % [tabs])
	check(story(ev).back() == "Nora Bell took her tea without sugar. Begin there.", "the last CONTINUE line")
	g.dispatch("ending_next")
	check(g.view == "end" and g.value("ending_choice") == "continue", "the 10th next finishes CONTINUE")
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
	for i in 10:
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
	var wide: Dictionary = R12Sim.ENDING_CONTINUE[8]
	check(wide.tableau == "end_b_wide" and wide.lines == [[0.0, "Far out in the dark, one small lit window. The kitchen."],
		[4.2, "Around it, more windows than I can count. None of them lit."]], "the wide page: both lines, 1.2 s more silence")

func test_use_item() -> void:
	var g := fresh()
	g.give("pencil")
	g.selected_item = "pencil"
	check(says(g.dispatch("chair")) == "That belongs upstairs." and g.has_item("pencil"), "other items belong upstairs")
	g.selected_item = BRIDGE
	check(says(g.dispatch("chair")) == "Not here. The bridge is for my terminal." and g.has_item(BRIDGE), "the bridge on the chair")
	g.dispatch("to_routing")
	g.selected_item = BRIDGE
	check(says(g.dispatch("contacts")) == "The bridge goes in my terminal, not across the feed.", "the bridge on the contacts")
	check(not r12(g).use_item(BRIDGE, "go:R11", []), "the bridge on the stair exit is not handled")
	check(not r12(g).use_item(BRIDGE, "nowhere", []), "unknown targets are not handled")
	# After P26, from the routing wall: opens c_final and seats it.
	var p := p26_game()
	var r := r12(p)
	p.dispatch("back")
	p.selected_item = BRIDGE
	var ev := p.dispatch("bridge_seat")
	check(r.local_view == "c_final" and r.bridge_seated() and not p.has_item(BRIDGE), "the bridge seats from the wall (%s)" % says(ev))

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
	for i in (4 if R12Sim.core_reads_tiers() else 3):
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
		check(r.ending_step() == ({7: 12, 8: 9}.get(n, 0)), "%s: ending step" % tag)
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
	for i in 13:
		check(g.view == "room", "chain: SEVER step %d before the end" % i)
		g.dispatch("ending_next")
	check(g.view == "end" and g.value("ending_choice") == "sever", "chain: the 13th next finishes")
	g.dispatch("return_decision")
	check(JSON.stringify(g.to_dict()) == snap or g.flag("P26"), "chain: back at the checkpoint")
	play(g, P27_CONTINUE)
	check(r.chosen() == "continue", "chain: P27 CONTINUE")
	for i in 10:
		g.dispatch("ending_next")
	check(g.view == "end" and g.value("ending_choice") == "continue", "chain: the 10th next finishes")
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
		and ResourceLoader.exists("res://assets/rooms/R12/a_surface_eye.png")
		and ResourceLoader.exists("res://assets/stages/R12/end_b_wide_2.png"), "the plates exist")
	var scene = await _scene_at(0, [])
	var view = scene.room_view
	var g: Rect2 = view_script.GLASS_IN
	for m in [false, true]:
		scene.sim.settings.motion = m
		for k in 5:
			scene.time = 40.0 + 7.0 * k
			check(view.blink_k() == 0.0 and is_equal_approx(view.lid_bottom(), g.position.y), "no blink, no lid (motion %s, t %d)" % [m, k])
	var eye: Texture2D = load("res://assets/rooms/R12/a_surface_eye.png")
	check(eye.get_size() == g.size, "the eye overlay is GLASS_IN-sized")
	await free_scene(scene)

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
	# CONTINUE's wide page
	var cc = await _scene_at(6, [])
	var cr: R12Sim = cc.sim.room(ROOM)
	cr.state.ending_step = 7
	cc.dispatch("ending_next")
	var cv = cc.room_view
	check(cr.tableau() == "end_b_wide" and cv.cur_tab == "end_b_wide", "on the wide page")
	cv.tick(0.0)
	check(is_equal_approx(cv.loop_targets().end_wide, lin.call(-14.0)), "the first line over the wide dark")
	cc.time += 3.2
	cv.tick(0.0)
	check(cv.wide_duck() and is_equal_approx(cv.loop_targets().end_wide, lin.call(-40.0)), "the gap: ducked to -40 dB")
	cc.cur_text = R12Sim.ENDING_CONTINUE[8].lines[1][1]
	cv.tick(0.0)
	check(not cv.wide_duck() and is_equal_approx(cv.loop_targets().end_wide, lin.call(-14.0)), "the count: the dark comes back")
	await free_scene(cc)

## The ending's 'continue' mark: once the page is done, pulsing (still with Motion off); and
## unanswered for 12 s it turns the page by itself, on both endings, to the end card.
func test_view_continue_mark() -> void:
	for n in [5, 6, 7, 8]:
		var scene = await _scene_at(n, [])
		var view = scene.room_view
		var r: R12Sim = scene.sim.room(ROOM)
		var step := r.ending_step()
		view.tick(0.0)
		check(view.page_finished() and view.cont_visible(), "ending %d: the finished page shows the mark" % n)
		scene.sim.settings.motion = false
		check(is_equal_approx(view.cont_alpha(), 0.8), "ending %d: Motion off, the mark is still at 0.8" % n)
		scene.sim.settings.motion = true
		var lo := 1.0
		var hi := 0.0
		var t0: float = scene.time
		for k in 9:
			scene.time = t0 + k * 0.25
			lo = minf(lo, view.cont_alpha())
			hi = maxf(hi, view.cont_alpha())
		check(lo >= 0.45 - 0.001 and lo < 0.5 and hi > 0.95 and hi <= 1.0, "ending %d: it pulses 0.45-1.0 (%s-%s)" % [n, lo, hi])
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
		var want := Vector2.ZERO if n == 0 else (Vector2(40, 0) if n == 4 else Vector2(-40, 0))
		check(scene.room_view.gaze_at == want, "jump %d: the pupil at %s (%s)" % [n, want, scene.room_view.gaze_at])
		await free_scene(scene)
	var sc = await _scene_at(2, ["to_routing", "contacts", "bridge_seat"])
	var v = sc.room_view
	check(sc.sim.room(ROOM).gaze() == "terminal", "the bridge seated: the sim looks at her terminal")
	sc.sim.settings.motion = true
	v.tick(0.5)
	check(v.gaze_at.x > -40.0 and v.gaze_at.x < 40.0, "with Motion the pupil travels (%s)" % [v.gaze_at])
	for i in 6:
		v.tick(0.5)
	check(v.gaze_at == Vector2(40, 0), "and arrives at her terminal")
	sc.dispatch("bridge_seat")
	sc.sim.settings.motion = false
	v.tick(0.0)
	check(v.gaze_at == Vector2(-40, 0), "Motion off: it is simply where it looks")
	await free_scene(sc)
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
		var scene = await _scene_at(1, ["to_routing", "plate_sever", "preview_" + route])
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
			scene.time = t0 + 1.2
			check(view.window_lamps_out() == 1, "sever: the first portrait lamp out (%d)" % view.window_lamps_out())
			scene.time = t0 + 4.5
			check(view.window_lamps_out() == 8, "sever: all eight out")
		else:
			check(view.window_feed()[0] == 0.0, "continue: the feed at E.V.")
			scene.time = t0 + 4.6
			check(view.window_feed() == [1.0, 1.0], "continue: the feed at A.M., the oilskin up")
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
	var sc = await _scene_at(1, ["to_routing", "plate_sever", "preview_sever", "preview_continue"])
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
