extends "res://tests/rooms/room_test_base.gd"
## R07, the Wet Laboratory: P10 (the jar that follows the datum), P13 (the mass that answers
## to a name), P14 (Nora's breath in the specimen frame), the escalation matrix, saves, debug
## stages and the two base views.
##   godot --headless --path . --script tests/rooms/R07_test.gd

const ROOM := "R07"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := ["P09"]
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 4
const VIEW_PATH := "res://game/rooms/R07/R07_view.gd"

## Reference tables written from the cards, independent of R07Sim's constants.
const REF_RULE := {"A": "gravity", "B": "jar", "C": "datum"}
const REF_TIP := {
	"A": "It stayed level with the plumb bob.",
	"B": "It turned with the jar.",
	"C": "It stayed square with the room, whatever the jar did.",
}
## A jar tipped to 90 degrees: where its surface lies against the room.
const REF_DEG := {"A": -8.0, "B": 90.0, "C": 0.0}
const REF_READ := {"N": [0, 3, 0], "W": [0, 0, 0], "F": [2, 2, 2]}
const REF_SOLUTION := ["short", "pause", "long"]
const REF_NAMES := ["BELL", "DOANE", "HART", "IVES", "LUSK", "PRYCE", "ROOK", "TULL"]
const UNTESTED := " The socket's tag says UNTESTED. Tip it on the rack first."
const TAKEN := "The socket's taken. Jar C stays."
const TAG := "A tag drops out of the slot: DATUM READING STABLE. STAIR PRESSURE TARGET: 2."
const BEAM := "The beam's pinned. It needs stair pressure."
const INCOMPLETE := "RECORD INCOMPLETE. Address it, release it, then record."
const ENV := "Environmental. It doesn't answer to a name."
const FLAT_TRACE := "A flat trace. That name doesn't answer to it."
const RECORDED := "Recorded. I'll leave it as it is."
const KITCHEN := "I need her trace to compare. It's on the nail by the range."
const STARTS := "Her breath starts with the short rises."
const PAUSE_AFTER := "The pause comes after the short rises."
const SEQS := [["record"], ["address", "record"], ["release", "record"], ["address", "release", "record"],
	["release", "address", "record"], ["address", "address", "release", "record"],
	["address", "release", "release", "record"], ["address", "record", "release", "record"]]
const JAR_ORDERS := [["A", "B", "C"], ["A", "C", "B"], ["B", "A", "C"], ["B", "C", "A"],
	["C", "A", "B"], ["C", "B", "A"]]
const SEC_ORDERS := [["short", "pause", "long"], ["short", "long", "pause"], ["pause", "short", "long"],
	["pause", "long", "short"], ["long", "short", "pause"], ["long", "pause", "short"]]

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	test_p10_results()
	test_p10_refusals()
	test_p10_success()
	test_p10_idempotent()
	test_p10_p11_orders()
	test_p13_beam_lock()
	test_p13_exhaustive()
	test_p13_resets()
	test_p13_consequence()
	test_p13_save_load()
	test_p14_gating()
	test_p14_orders()
	test_p14_unseen_reference()
	test_p14_refusals()
	test_p14_empty_slot()
	test_p14_items()
	test_p14_fog()
	test_p14_swaps()
	test_malformed_saves()
	test_reconcile_sync()
	test_escalation()
	test_notices()
	test_objectives_hints()
	test_use_item()
	test_bench_hotspots()
	test_doors()
	test_debug_prepare_items()
	test_debug_jumps()
	test_chain_scripts()
	test_tide_round_trips()
	test_w2_p10_neutral()
	test_w2_silent_vault()
	test_w2_lines()
	test_w2_glances()
	test_w2_no_printed_answers()
	test_w3_visual_results()
	test_w3_holder_names()
	test_p1_lines()
	test_p1_specimens()
	test_p1_lean_sim()
	if _view_ready():
		await view_checks(ROOM)
		await test_view_scene()
		await test_w2_view()
		await test_w3_view()
		await test_p1_view()
	else:
		print("SKIP: R07 view_checks and scene test: the R07 view does not yet declare rects for every sim hotspot (view team)")

# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
func r07(g: GameSim) -> R07Sim:
	return g.room(ROOM) as R07Sim

func fresh() -> GameSim:
	return with_flags(["P09"], ROOM)

func flags_upto(n: int) -> Array:
	var out := []
	for i in range(1, n + 1):
		out.append("P%02d" % i)
	return out

func snapshot(g: GameSim) -> String:
	return JSON.stringify([g.state.flags, g.state.inventory, g.state.notebook])

func count_ev(ev: Array, type: String, id: String) -> int:
	var n := 0
	for e in ev:
		if e.type == type and e.get("id", "") == id:
			n += 1
	return n

func ev_index(ev: Array, type: String, id: String) -> int:
	for i in ev.size():
		if ev[i].type == type and ev[i].get("id", "") == id:
			return i
	return -1

func ev_delay(ev: Array, type: String, id: String) -> float:
	var i := ev_index(ev, type, id)
	return float(ev[i].delay) if i >= 0 else -1.0

func play(g: GameSim, actions: Array) -> Array:
	var ev: Array = []
	for a in actions:
		ev = g.dispatch(a)
	return ev

func use(g: GameSim, item: String, target: String) -> Array:
	g.dispatch("item:" + item)
	return g.dispatch(target)

## A game at the start of tide V (P12 done), at the balance.
func balance_game() -> GameSim:
	var g := with_flags(flags_upto(12), ROOM)
	play(g, ["to_bench", "balance"])
	return g

## P13 solved (card given), standing at the open frame.
func frame_game(ref_seen := true) -> GameSim:
	var g := GameSim.new()
	r07(g).debug_jump(6)
	# The built kitchen and machine room prepare what real play leaves seen; this fixture
	# controls the two cross-room reads itself.
	g.state.notebook.erase("R05.nora_work_card")
	g.state.notebook.erase("R08.reference_respiration")
	if ref_seen:
		g.observe("R05", "nora_work_card")
	play(g, ["to_bench", "frame_stand"])
	return g

func place(g: GameSim, order: Array) -> void:
	for k in order.size():
		if order[k] != "":
			g.dispatch("sec_" + order[k])
			g.dispatch("slot_%d" % k)

func complete_frame(g: GameSim) -> void:
	use(g, "nora_register_card", "name_tab")
	g.dispatch("strip_clip")

func _view_ready() -> bool:
	var m: Dictionary = load(VIEW_PATH).get_script_constant_map()
	var ids := []
	for h in m.get("HOTSPOTS", []):
		ids.append(h[0])
	for id in R07Sim.HOTSPOTS:
		if not id in ids:
			return false
	return true

# ---------------------------------------------------------------------------------------------
# P10: three jars, three rules
# ---------------------------------------------------------------------------------------------
func test_p10_results() -> void:
	for order in JAR_ORDERS:
		var g := fresh()
		var r := r07(g)
		g.dispatch("tilt_rack")
		check(r.local_view == "c_tilt_rack", "tilt_rack opens the close-up")
		for pass_n in 2:
			for j in order:
				g.dispatch("rest_" + j.to_lower())
				check(r.state.cradle == j, "%s: jar %s in the cradle" % [order, j])
				var ev := g.dispatch("tip")
				check(says(ev) == REF_TIP[j], "%s pass %d: tipping %s says %s (got %s)" % [order, pass_n, j, REF_TIP[j], says(ev)])
				check(r.has_seen("test_" + j.to_lower()), "%s: tipping %s notes test_%s" % [order, j, j.to_lower()])
				check(r.last_test == j and has_ev(ev, "fx", "tip"), "%s: %s animates" % [order, j])
				check(ev_delay(ev, "sfx", "test_pen") == 1.3 and ev_delay(ev, "sfx", "rack_tip") == 0.0, "%s: tip sounds" % [order])
				check(R07Sim.surface_deg(REF_RULE[j], 90.0) == REF_DEG[j],
					"%s follows %s" % [j, REF_RULE[j]])
		check(not r.has_seen("datum_target") and not g.flag("P10"), "%s: tipping never writes datum_target" % [order])
		check(JSON.stringify(r.state.tested) == JSON.stringify({"A": true, "B": true, "C": true}), "%s: all tested" % [order])

func test_p10_refusals() -> void:
	var cases := [
		["A", false, "This one follows gravity. The card wants the datum." + UNTESTED],
		["B", false, "This one follows the jar." + UNTESTED],
		["C", false, "It sits square with the brass line." + UNTESTED],
		["A", true, "This one follows gravity. The card wants the datum."],
		["B", true, "This one follows the jar."],
	]
	for c in cases:
		var g := fresh()
		var r := r07(g)
		g.dispatch("tilt_rack")
		g.dispatch("rest_" + c[0].to_lower())
		if c[1]:
			g.dispatch("tip")
		var before := snapshot(g)
		var ev := g.dispatch("seat")
		var tag := "%s %s" % [c[0], "tested" if c[1] else "untested"]
		check(says(ev) == c[2], "%s refusal line (got %s)" % [tag, says(ev)])
		check(has_ev(ev, "sfx", "socket_refuse"), "%s refusal sound" % tag)
		check(not g.flag("P10") and r.state.socket == "" and r.state.cradle == c[0], "%s: nothing seated" % tag)
		check(snapshot(g) == before, "%s: inventory and notebook unchanged" % tag)
	var g := fresh()
	g.dispatch("tilt_rack")
	check(says(g.dispatch("seat")) == "The cradle's empty. A jar goes in the cradle, then the socket.", "seat with an empty cradle")
	check(says(g.dispatch("tip")) == "The cradle's empty.", "tip with an empty cradle")

func solve_p10(g: GameSim) -> Array:
	return play(g, ["tilt_rack", "rest_c", "tip", "seat"])

func test_p10_success() -> void:
	var g := fresh()
	var r := r07(g)
	var ev := solve_p10(g)
	check(g.flag("P10") and r.state.p10_complete and r.state.socket == "C" and r.state.cradle == "", "C seats: P10")
	check(r.has_seen("datum_target"), "datum_target noted")
	var ci := ev_index(ev, "sfx", "socket_click")
	var ti := ev_index(ev, "sfx", "tag_drop")
	check(ci >= 0 and ti > ci and ev_delay(ev, "sfx", "socket_click") == 0.0 and ev_delay(ev, "sfx", "tag_drop") == 1.2,
		"socket_click at 0 before tag_drop at 1.2")
	check(says(ev) == "It seats. The socket takes the reading. | " + TAG, "success lines (got %s)" % says(ev))
	check(not has_ev(ev, "sfx", "water_lean") and not has_ev(ev, "fx", "notice_lean"), "nothing uncanny at the seat")
	var b := g.dispatch("back")
	check(r.local_view == "room" and count_ev(b, "fx", "notice_lean") == 1 and count_ev(b, "sfx", "water_lean") == 1,
		"back plays the lean once")
	check(ev_delay(b, "sfx", "water_lean") == 0.8 and says(b) == "...The water in C leaned toward me. | Now it's level again. It took longer than water should.",
		"the lean's lines (got %s)" % says(b))
	check(r.has_seen("lean") and r.state.lean_seen, "lean noted")
	var b2 := g.dispatch("back")
	check(not has_ev(b2, "fx", "notice_lean"), "a second back has no lean")
	g.dispatch("tilt_rack")
	var b3 := g.dispatch("back")
	check(not has_ev(b3, "fx", "notice_lean") and not has_ev(b3, "sfx", "water_lean"), "re-entering has no lean")
	check(r.reflection_jars() == 2 and r.jar_rest_rot("C") == 0.0 and r.jar_rest_rot("A") == 12.0, "C square in the socket")
	check(says(g.dispatch("jar_c")) == "Where jar C stood. A ring of salt in the cradle." and r.local_view == "room",
		"jar_c after P10 is the empty seat")
	check(says(g.dispatch("reference_socket")).begins_with("Jar C, in the socket."), "the socket after P10")

func test_p10_idempotent() -> void:
	var g := fresh()
	var r := r07(g)
	solve_p10(g)
	for j in ["a", "b"]:
		g.dispatch("rest_" + j)
		g.dispatch("tip")
		var before := JSON.stringify(g.to_dict())
		var ev := g.dispatch("seat")
		check(says(ev) == TAKEN and ev.size() == 1, "re-seat %s: %s (got %s)" % [j, TAKEN, says(ev)])
		check(not has_ev(ev, "fx", "tide") and JSON.stringify(g.to_dict()) == before, "re-seat %s changes nothing" % j)
	check(says(g.dispatch("rest_c")) == "Jar C is in the socket.", "C stays in the socket")
	check(says(g.dispatch("rest_b")) == "Back on the shelf." and r.state.cradle == "", "B back on the shelf")
	check(says(g.dispatch("rest_b")) == "Jar B in the cradle.", "B in the cradle again")
	check(says(g.dispatch("tip")) == REF_TIP.B, "tipping still works for B after P10")

func test_p10_p11_orders() -> void:
	var a := fresh()
	solve_p10(a)
	a.dispatch("back")
	a.set_flag("P11")
	var b := fresh()
	b.set_flag("P11")
	solve_p10(b)
	b.dispatch("back")
	check(a.flag("P10") and b.flag("P10") and a.has_seen("R07", "datum_target") and b.has_seen("R07", "datum_target"),
		"P10 either side of P11")
	check(JSON.stringify(r07(a).state) == JSON.stringify(r07(b).state), "identical R07 state either order")

# ---------------------------------------------------------------------------------------------
# P13: the balance
# ---------------------------------------------------------------------------------------------
func test_p13_beam_lock() -> void:
	var g := with_flags(["P09", "P10", "P11"], ROOM)
	var r := r07(g)
	var ev := play(g, ["to_bench", "balance"])
	check(r.local_view == "c_balance" and r.has_seen("beam_locked"), "the balance before P12")
	ev = play(g, ["smp_n", "reg_bell"])
	check(not has_ev(g.dispatch("smp_w"), "sfx", "strip_print"), "nothing prints with the beam pinned")
	g.dispatch("smp_n")
	for k in ["key_address", "key_release", "key_record"]:
		ev = g.dispatch(k)
		check(says(ev) == BEAM and r.balance_note == "BEAM LOCKED." and has_ev(ev, "sfx", "key_refuse"), "%s: beam locked" % k)
		check(r.strip_cells() == ["", "", ""] and int(r.state.step) == 0, "%s: nothing prints" % k)
	check(says(g.dispatch("gauge")) == "Stair pressure: 0.", "gauge 0 before P12")
	check(not g.flag("P13"), "no P13 before P12")

func expect_steps(seq: Array, has_name: bool) -> int:
	var step := 0
	for k in seq:
		if k == "address" and has_name:
			step = 1
		elif k == "release" and step == 1:
			step = 2
	return step

func test_p13_exhaustive() -> void:
	for s in ["N", "W", "F"]:
		for name in [""] + REF_NAMES:
			for seq in SEQS:
				var g := balance_game()
				var r := r07(g)
				g.dispatch("smp_" + s.to_lower())
				if name != "":
					g.dispatch("reg_" + name.to_lower())
				var ev: Array = []
				var addr_line := ""
				for k in seq:
					ev = g.dispatch("key_" + k)
					if k == "address" and addr_line == "":
						addr_line = says(ev)
				var tag := "%s/%s/%s" % [s, name if name != "" else "-", seq]
				var step := expect_steps(seq, name != "")
				var win: bool = step == 2 and s == "N" and name == "BELL"
				check(g.flag("P13") == win and r.state.p13_complete == win, "%s: P13 %s" % [tag, win])
				check(g.has_item("nora_register_card") == win, "%s: card %s" % [tag, win])
				var want_line := ""
				var want_note := ""
				if step < 2:
					want_line = INCOMPLETE
					want_note = "RECORD INCOMPLETE."
				elif s != "N":
					want_line = ENV
					want_note = "CONSTANT"
				elif name != "BELL":
					want_line = FLAT_TRACE
					want_note = "NO CORRESPONDENCE"
				if win:
					check(says(ev).begins_with("Recorded. Nought, three, nought."), "%s: recorded (got %s)" % [tag, says(ev)])
					check(r.strip_note() == "RECORDED" and r.strip_cells() == ["0 dr", "3 dr", "0 dr"], "%s: strip recorded" % tag)
				else:
					check(says(ev) == want_line and r.balance_note == want_note, "%s: %s / %s (got %s / %s)" % [tag, want_line, want_note, says(ev), r.balance_note])
					var cells := r.strip_cells()
					var rd: Array = REF_READ[s] if (s != "N" or name == "BELL") else [0, 0, 0]
					for k in 3:
						var want := ("%d dr" % rd[k]) if k <= step else ""
						check(cells[k] == want, "%s: cell %d %s (got %s)" % [tag, k, want, cells[k]])
				if "address" in seq:
					var want_addr := ""
					if name == "":
						want_addr = "ADDRESS wants a name in the holder. The register's along the bottom."
					elif s != "N":
						want_addr = ENV
					elif name == "BELL":
						want_addr = "Three drams. On an empty tube."
					else:
						want_addr = "Nothing. NO CORRESPONDENCE."
					check(addr_line == want_addr, "%s: address line %s (got %s)" % [tag, want_addr, addr_line])
				if win:
					for i in 2:
						check(says(g.dispatch("key_record")) == RECORDED, "%s: a repeated record" % tag)
					check(g.state.inventory.count("nora_register_card") == 1, "%s: exactly one card" % tag)
	var g := balance_game()
	check(says(g.dispatch("key_address")) == "Nothing on the pan to address.", "address with an empty pan")
	check(says(g.dispatch("key_release")) == "Nothing's addressed to release.", "release unaddressed")
	check(says(g.dispatch("gauge")) == "Stair pressure: 2.", "gauge 2 after P12")

func test_p13_resets() -> void:
	var g := balance_game()
	var r := r07(g)
	play(g, ["smp_n", "reg_bell", "key_address"])
	check(int(r.state.step) == 1 and r.strip_cells() == ["0 dr", "3 dr", ""], "addressed")
	g.dispatch("smp_w")
	check(int(r.state.step) == 0 and r.strip_cells() == ["0 dr", "", ""], "swapping the sample resets the step")
	play(g, ["smp_n", "key_address", "key_release"])
	check(int(r.state.step) == 2, "released")
	g.dispatch("reg_hart")
	check(int(r.state.step) == 0 and r.state.holder == "HART", "swapping the holder resets the step")
	play(g, ["key_address"])
	var ev := g.dispatch("holder")
	check(int(r.state.step) == 0 and r.state.holder == "" and says(ev) == "I take Hart's card back out.", "removing the card resets, and names it")
	g.dispatch("reg_bell")
	play(g, ["key_address"])
	g.dispatch("pan")
	check(int(r.state.step) == 0 and r.state.pan == "", "removing the sample resets")
	check(says(g.dispatch("pan")) == "The pan's empty.", "the pan's empty")
	check(says(g.dispatch("holder")) == "I take Bell's card back out." and says(g.dispatch("holder")) == "The holder's empty. Names are in the register along the bottom.",
		"the holder's empty")
	check(not g.has_item("nora_register_card"), "selecting never gives the card")

func test_p13_consequence() -> void:
	var g := balance_game()
	var r := r07(g)
	var ev := play(g, ["smp_n", "reg_bell", "key_address", "key_release", "key_record"])
	var si := ev_index(ev, "sfx", "strip_print")
	var fi := ev_index(ev, "sfx", "felt_press")
	check(si >= 0 and fi > si and ev_delay(ev, "sfx", "felt_press") == 3.6 and ev_delay(ev, "sfx", "strip_print") < 3.6,
		"felt_press at 3.6 after the strip prints")
	check(has_ev(ev, "fx", "thumb") and has_ev(ev, "fx", "strip_recorded"), "the thumb and the strip fx")
	for o in ["thumb", "nora_mass_trace", "register_bell"]:
		check(r.has_seen(o), "%s noted" % o)
	check(r.state.thumb_seen and r.state.holder == "" and r.thumb_shown(), "the thumb is shown, the holder empty")
	check(says(g.dispatch("tray")) == "Her thumb. In felt nobody has touched.", "the tray after")
	check(says(g.dispatch("reg_bell")) == "Her card's with me." and says(g.dispatch("smp_w")) == RECORDED, "after P13")
	g.dispatch("back")
	check(r.local_view == "bench", "back from the balance to the bench")
	check(says(g.dispatch("control_tray")) == "A thumbprint in the felt. Small. Pressed down hard.", "the control tray hotspot after")

func test_p13_save_load() -> void:
	var g := balance_game()
	play(g, ["smp_n", "reg_bell", "key_address"])
	var t := GameSim.new()
	check(t.from_dict(JSON.parse_string(JSON.stringify(g.to_dict()))), "mid-P13 save loads")
	var r := r07(t)
	check(r.state.pan == "N" and r.state.holder == "BELL" and int(r.state.step) == 1 and r.local_view == "room",
		"the balance survives the load")
	play(t, ["to_bench", "balance", "key_release", "key_record"])
	check(t.flag("P13") and t.has_item("nora_register_card"), "release and record after the load completes")

# ---------------------------------------------------------------------------------------------
# P14: the specimen frame
# ---------------------------------------------------------------------------------------------
func test_p14_gating() -> void:
	var g := balance_game()
	var r := r07(g)
	g.dispatch("back")
	var ev := g.dispatch("frame_stand")
	check(r.local_view == "bench" and says(ev).ends_with("OPENS ON A RECORDED MASS."), "the frame is locked before P13")
	check(says(g.dispatch("sec_short")) == "" and r.held == "", "frame controls do nothing outside the close-up")

func test_p14_orders() -> void:
	for order in SEC_ORDERS:
		var g := frame_game()
		var r := r07(g)
		check(r.local_view == "c_frame", "%s: the frame opens" % [order])
		place(g, order)
		complete_frame(g)
		var ev := g.dispatch("seal")
		var win: bool = order == REF_SOLUTION
		check(g.flag("P14") == win and g.has_item("nora_frame") == win, "%s: P14 %s" % [order, win])
		if win:
			check(says(ev).begins_with("Sealed. Her breath, her name, her weight, in one frame."), "%s: sealed" % [order])
			check(r.has_seen("nora_breath_trace"), "nora_breath_trace noted")
			continue
		var miss := []
		for k in 3:
			if order[k] != REF_SOLUTION[k]:
				miss.append(k)
		var want := STARTS if order[0] != "short" else PAUSE_AFTER
		check(says(ev) == want and has_ev(ev, "sfx", "key_refuse"), "%s: %s (got %s)" % [order, want, says(ev)])
		check(r.frame_miss == miss, "%s: frame_miss %s (got %s)" % [order, miss, r.frame_miss])
		if order == ["short", "long", "pause"]:
			check(r.frame_miss == [1, 2], "short/long/pause misses [1, 2]")

func test_p14_unseen_reference() -> void:
	for order in SEC_ORDERS:
		var g := frame_game(false)
		var r := r07(g)
		place(g, order)
		complete_frame(g)
		var ev := g.dispatch("seal")
		if order == REF_SOLUTION:
			check(g.flag("P14"), "the right order succeeds with the reference unseen")
		else:
			check(says(ev) == KITCHEN and r.frame_miss == [] and not g.flag("P14"), "%s unseen: the kitchen line (got %s)" % [order, says(ev)])
	var g := frame_game(false)
	check(says(g.dispatch("ref_card")) == "Her work card isn't here. It hangs in the kitchen, by the range.", "ref_card unseen")
	var s := frame_game(true)
	check(says(s.dispatch("ref_card")) == "Her work card's trace, copied beside the frame. The sections have to match it.",
		"ref_card seen")

func test_p14_refusals() -> void:
	var g := frame_game()
	place(g, REF_SOLUTION)
	var ev := g.dispatch("seal")
	check(says(ev) == "The name tab is blank. Her register card has the name." and not g.flag("P14"), "name tab missing")
	check(says(g.dispatch("name_tab")) == "The name tab's blank. Her register card has the name.", "the blank tab with the card in hand")
	use(g, "nora_register_card", "name_tab")
	check(says(g.dispatch("name_tab")) == "BELL, N. Copied from her register card.", "the tab written")
	ev = g.dispatch("seal")
	check(says(ev) == "The clip's empty. The balance strip goes there." and not g.flag("P14"), "strip missing")
	check(says(g.dispatch("strip_clip")) == "The balance strip, nought, three, nought, under the clip.", "clip the strip")
	check(says(g.dispatch("strip_clip")) == "Clipped.", "clipped")
	g.dispatch("seal")
	check(g.flag("P14"), "then it seals")
	check(says(g.dispatch("slot_0")) == "It's sealed.", "every control after the seal")

func test_p14_empty_slot() -> void:
	var g := frame_game()
	var r := r07(g)
	complete_frame(g)
	place(g, ["short", "", ""])
	var ev := g.dispatch("seal")
	check(says(ev) == "There are three slots. All three want a section." and r.frame_miss == [1, 2], "empty slots refused")
	g.dispatch("sec_pause")
	g.dispatch("slot_1")
	check(r.frame_miss == [], "a move clears the misses")
	check(says(g.dispatch("slot_2")) == "An empty slot.", "an empty slot")

func test_p14_items() -> void:
	var g := frame_game()
	place(g, REF_SOLUTION)
	var ev := use(g, "nora_register_card", "name_tab")
	check(says(ev) == "I copy it from her register card: BELL, N. The card stays with me." and r07(g).state.name_tab,
		"the card writes the tab")
	check(g.has_item("nora_register_card"), "the card stays in inventory")
	g.dispatch("strip_clip")
	ev = g.dispatch("seal")
	check(count_ev(ev, "fx", "item_added") == 1 and g.has_item("nora_frame"), "nora_frame given once")
	var inv := JSON.stringify(g.state.inventory)
	ev = g.dispatch("seal")
	check(says(ev) == "It's sealed." and JSON.stringify(g.state.inventory) == inv, "a re-seal adds nothing")
	check(g.has_item("nora_register_card"), "the card is never taken")

func test_p14_fog() -> void:
	var g := frame_game()
	var r := r07(g)
	place(g, REF_SOLUTION)
	complete_frame(g)
	var ev := g.dispatch("seal")
	check(not has_ev(ev, "fx", "notice_fog"), "no fog at the seal")
	check(says(ev).ends_with(P14_TAIL), "the P14 tail line")
	var b := g.dispatch("back")
	check(r.local_view == "bench" and count_ev(b, "fx", "notice_fog") == 1 and count_ev(b, "sfx", "breath_hiss") == 1,
		"back plays the fog once")
	check(ev_delay(b, "sfx", "breath_hiss") == 0.8 and says(b).contains("'Retention is not resuscitation.'"), "the fog's lines")
	var last: Dictionary = {}
	for e in b:
		if e.type == "say":
			last = e
	check(last.get("text", "") == "All of it leans the same way. Down." and bool(last.get("story", false)),
		"the reveal chain ends: all of it leans the same way, down")
	check(says(b).find("Retention is not resuscitation.") < says(b).find("All of it leans"), "after the inscription")
	check(r.has_seen("inscription") and r.has_seen("down") and r.state.fog_seen and r.fog_shown(), "inscription and the lean noted")
	check(R07Sim.OBSERVATIONS.down.contains("All of it leans the same way. Down"), "the notebook keeps the line")
	check(says(g.dispatch("frame_stand")) == "The stand's empty. Her frame is with me." and r.local_view == "bench", "the stand after")
	var b2 := g.dispatch("back")
	check(r.local_view == "room" and not has_ev(b2, "fx", "notice_fog"), "no second fog")
	# The tail line is the same with the machine room's respiration reference seen.
	var h := frame_game()
	h.observe("R08", "reference_respiration")
	place(h, REF_SOLUTION)
	complete_frame(h)
	check(says(h.dispatch("seal")).ends_with(P14_TAIL), "the tail line, belt reference seen")

func test_p14_swaps() -> void:
	var g := frame_game()
	var r := r07(g)
	check(r.tray_sections() == ["pause", "long", "short"], "the tray starts out of order")
	g.dispatch("sec_short")
	check(r.held == "short", "short held")
	g.dispatch("sec_short")
	check(r.held == "", "short put down again")
	place(g, ["short"])
	check(r.state.slots == ["short", "", ""] and r.tray_sections() == ["pause", "long", ""], "short in slot 0")
	g.dispatch("sec_pause")
	g.dispatch("slot_0")
	check(r.state.slots == ["pause", "", ""] and r.tray_sections() == ["", "long", "short"],
		"tray section into an occupied slot sends the occupant to the tray")
	g.dispatch("sec_long")
	g.dispatch("slot_1")
	g.dispatch("sec_pause")
	g.dispatch("slot_1")
	check(r.state.slots == ["long", "pause", ""], "slot to slot swaps (got %s)" % [r.state.slots])
	g.dispatch("slot_0")
	check(r.state.slots == ["", "pause", ""] and r.tray_sections() == ["", "long", "short"], "an empty hand returns a slot to the tray")

# ---------------------------------------------------------------------------------------------
# saves, reconcile
# ---------------------------------------------------------------------------------------------
func load_with(patch: Dictionary) -> R07Sim:
	var g := game_at(4, ROOM)
	var d := g.to_dict()
	for k in patch:
		d.rooms[ROOM][k] = patch[k]
	var t := GameSim.new()
	check(t.from_dict(d), "patched save loads %s" % [patch.keys()])
	return r07(t)

func test_malformed_saves() -> void:
	var init := JSON.stringify(R07Sim.new().initial_state())
	var r := load_with({"cradle": 5, "tested": "x", "socket": true, "pan": 3, "holder": [], "step": "2",
		"slots": "abc", "notices": "x", "bench_notices": 1, "p10_complete": "yes", "tap_on": 1})
	check(JSON.stringify(r.state) == init, "wrong types load as fresh (got %s)" % JSON.stringify(r.state))
	r = load_with({"cradle": "D", "pan": "Q", "holder": "SMITH", "tested": {"A": true, "B": 2, "Z": true},
		"notices": ["bogus", "tank_lag", "tank_lag"], "bench_notices": ["shells_rings", "x"]})
	check(r.state.cradle == "" and r.state.pan == "" and r.state.holder == "", "unknown ids dropped")
	check(JSON.stringify(r.state.tested) == JSON.stringify({"A": true, "B": false, "C": false}), "tested per jar")
	check(r.state.notices == ["tank_lag"] and r.state.bench_notices == ["shells_rings"], "notices whitelisted and deduped")
	r = load_with({"slots": ["short", "short", ""]})
	check(r.state.slots == ["", "", ""], "duplicate slots reset")
	r = load_with({"slots": ["long", "", "short"]})
	check(r.state.slots == ["long", "", "short"], "valid partial slots kept")
	r = load_with({"slots": ["short", "pause"]})
	check(r.state.slots == ["", "", ""], "short slots reset")
	r = load_with({"socket": "A"})
	check(r.state.socket == "", "socket A refused")
	r = load_with({"socket": "C", "lean_seen": true, "thumb_seen": true, "fog_seen": true, "name_tab": true, "strip_clipped": true})
	check(r.state.socket == "" and not r.state.lean_seen and not r.state.thumb_seen and not r.state.fog_seen
		and not r.state.name_tab and not r.state.strip_clipped, "unearned progress cleared")
	r = load_with({"step": 7, "pan": "N", "holder": "BELL"})
	check(int(r.state.step) == 2, "step clamped to 2")
	r = load_with({"step": 7, "pan": "N"})
	check(int(r.state.step) == 0, "step needs a holder")
	r = load_with({"step": 1.5, "pan": "N", "holder": "BELL"})
	check(int(r.state.step) == 0, "fractional step refused")
	r = load_with({"p14_complete": true, "p10_complete": false, "cradle": "C", "holder": "HART", "pan": "W"})
	check(r.state.p10_complete and r.state.p13_complete and r.state.socket == "C" and r.state.tested.C
		and r.state.cradle == "" and r.state.holder == "" and r.state.pan == "N" and int(r.state.step) == 2
		and r.state.slots == ["short", "pause", "long"] and r.state.name_tab and r.state.strip_clipped
		and r.state.frame_opened, "p14 implies p13, p10 and their arrangements")
	check(r.game.flag("P10") and r.game.flag("P13") and r.game.flag("P14"), "and the flags follow")
	check(not r.game.has_item("nora_register_card") and not r.game.has_item("nora_frame"), "a repair gives no items")
	r = load_with({"p10_complete": true, "cradle": "C"})
	check(r.state.cradle == "" and r.state.socket == "C", "C can't be in the cradle and the socket")

func test_reconcile_sync() -> void:
	var g := with_flags(["P09", "P10"], ROOM)
	var r := r07(g)
	r.reconcile()
	check(r.state.p10_complete and r.state.socket == "C" and r.state.tested.C, "P10 from outside seats C")
	g = with_flags(["P09", "P10", "P11", "P12", "P13"], ROOM)
	r = r07(g)
	r.reconcile()
	check(r.state.p13_complete and r.state.holder == "" and r.state.pan == "N" and int(r.state.step) == 2,
		"P13 from outside")
	check(not g.has_item("nora_register_card"), "sync never grants the card")
	g = with_flags(["P09", "P13"], ROOM)
	r = r07(g)
	check(r.objective() != "p10" and r.state.p10_complete, "objective() syncs too")
	r.reconcile()
	check(g.flag("P10"), "P13 pulls P10 along on reconcile")
	g = fresh()
	r = r07(g)
	r.state.p10_complete = true
	r.reconcile()
	check(g.flag("P10"), "state sets the flag")

# ---------------------------------------------------------------------------------------------
# escalation and notices
# ---------------------------------------------------------------------------------------------
func test_escalation() -> void:
	var want := {
		4: ["", "gravity", 3, false, false, false, false],
		5: ["", "gravity", 3, false, true, false, false],
		6: ["", "gravity", 3, true, true, false, true],
		7: ["vault", "gravity", 3, true, true, false, true],
		8: ["vault", "pane", 3, true, true, true, true],
		9: ["ada", "pane", 3, true, true, true, true],
	}
	for t in range(4, 10):
		var g := game_at(t, ROOM)
		var r := r07(g)
		var got := [r.anomaly(), r.tank_mode(), r.reflection_jars(), r.vault_ajar(), r.return_unbolted(),
			r.drip_hangs(), r.shells_aligned()]
		check(JSON.stringify(got) == JSON.stringify(want[t]), "tide %d (band %d): %s (got %s)" % [t, r.band(), want[t], got])
	var g := GameSim.new()
	var r := r07(g)
	r.debug_jump(3)
	check(r.reflection_jars() == 2 and not r.reflection_lag(), "band 2 after P10: two jars in the reflection")
	g = game_at(9, ROOM)
	r = r07(g)
	g.finish("sever")
	check(r.ending() == "sever" and r.anomaly() == "level" and r.tank_mode() == "level" and not r.reflection_lag()
		and r.reflection_jars() == 2 and not r.drip_hangs() and not r.shells_aligned() and not r.thumb_shown()
		and r.fog_shown() and r.current_notice() == "" and r.current_bench_notice() == "", "sever releases the room")
	g.view = "room"
	for h in ["jar_a", "jar_b", "jar_c", "tilt_rack", "reference_socket", "tank", "datum_line"]:
		r.local_view = "room"
		check(says(g.dispatch(h)) == R07Sim.SEVER_LINES[h], "sever line for %s" % h)
	for h in ["sealed_jar", "sample_rack"]:
		r.local_view = "bench"
		check(says(g.dispatch(h)) == R07Sim.SEVER_LINES[h], "sever line for %s" % h)
	var c := game_at(9, ROOM)
	c.finish("continue")
	check(r07(c).anomaly() == "ada" and r07(c).current_notice() == "", "continue: the jars still face her, no notice")
	# Tank lines by band.
	for pair in [[4, "Ordinary water."], [5, "It still shows jar C in the rack."], [8, "Like a pane."]]:
		var tg := game_at(pair[0], ROOM)
		check(says(tg.dispatch("tank")).ends_with(pair[1]), "tank at tide %d" % pair[0])
	var bg := game_at(8, ROOM)
	check(says(bg.dispatch("basin")) == "The drop at the tap doesn't fall. It hangs there." and r07(bg).has_seen("drip_hangs"), "the drip hangs")
	var fg := game_at(4, ROOM)
	check(says(fg.dispatch("basin")) == "The tap runs. The water falls at a slant, along the plumb line." and r07(fg).state.tap_on, "tap on")
	check(says(fg.dispatch("basin")) == "Off. It still drips, at the same slant." and r07(fg).has_seen("basin_drip"), "tap off")

func test_notices() -> void:
	var g := with_flags(["P09"], "R05")
	var ev := g.dispatch("go:R07")
	var r := r07(g)
	var want_arrival: String = R07Sim.ARRIVAL_WET if r.band() >= 2 else R07Sim.ARRIVAL
	check(g.state.room == ROOM and says(ev).begins_with(want_arrival) and has_ev(ev, "sfx", "slosh_c"), "first arrival")
	check(says(ev).ends_with("The tank isn't level either. Or the room isn't.") and r.has_seen("angles")
		and r.state.notices == ["angles"], "the arrival beat")
	g = game_at(5, "R05")
	r = r07(g)
	var steps := [[[], "tank_lag"], [["P13", "P14", "P15"], "vault_ajar"], [["P16", "P17", "P18"], "jars_to_vault"],
		[["P19", "P20", "P21"], "tank_pane"], [["P22", "P23", "P24"], "jars_face"]]
	for s in steps:
		for f in s[0]:
			g.set_flag(f)
		ev = g.dispatch("go:R07")
		var n: String = s[1]
		check(count_ev(ev, "fx", "notice_" + n) == 1 and r.has_seen(n), "notice %s plays (got %s)" % [n, says(ev)])
		check(r.state.notices == R07Sim.NOTICES.slice(0, R07Sim.NOTICES.find(n) + 1), "%s retires the older ones" % n)
		check(has_ev(ev, "sfx", "vault_settle") == (n == "vault_ajar"), "%s vault sound" % n)
		g.dispatch("go:R05")
		ev = g.dispatch("go:R07")
		check(not has_ev(ev, "fx", "notice_" + n) and says(ev) == "", "%s only once" % n)
		g.dispatch("go:R05")
	for t in range(5, 10):
		var j := game_at(t, "R05")
		var cur := r07(j).current_notice()
		ev = j.dispatch("go:R07")
		check(count_ev(ev, "fx", "notice_" + cur) == 1, "debug tide %d: the current notice %s still plays" % [t, cur])
		var fxs := 0
		for e in ev:
			if e.type == "fx" and str(e.id).begins_with("notice_"):
				fxs += 1
		check(fxs == 1, "tide %d: only one notice" % t)
	# The bench notice at band 4.
	g = game_at(6, ROOM)
	r = r07(g)
	ev = g.dispatch("to_bench")
	check(count_ev(ev, "fx", "notice_shells_rings") == 1 and says(ev) == "The shells have lined up."
		and float(ev[-1].delay) == 0.6, "shells_rings on to_bench")
	check(r.has_seen("shells_rings") and r.state.bench_notices == ["shells_rings"], "shells_rings noted")
	g.dispatch("to_tank")
	check(says(g.dispatch("to_bench")) == "The bench.", "the bench notice plays once")
	g = game_at(6, ROOM)
	r07(g).state.bench_seen = false
	ev = g.dispatch("to_bench")
	check(says(ev) == "The bench. A balance, a register, a specimen frame. And a jar on its own, sealed, with nothing in it. | The shells have lined up."
		and has_ev(ev, "fx", "notice_shells_rings") and float(ev[-1].delay) == 2.2, "first bench entry, then the notice")
	g = game_at(5, ROOM)
	ev = g.dispatch("to_bench")
	check(not has_ev(ev, "fx", "notice_shells_rings"), "no shells before band 4")

# ---------------------------------------------------------------------------------------------
# objectives, hints, items
# ---------------------------------------------------------------------------------------------
const REF_HINTS := {
	"p10": ["The laboratory's three jars look alike at rest. The tilt rack tests them.",
		"The card wants the brass: a surface that keeps the datum's level, whatever the jar does. Tip each one.",
		"The reference card on the rack says which line to trust.",
		"Test all three. C stays parallel to the datum. Put C in the reference socket."],
	"wait_p12": ["The laboratory has given the stair what it needs.", "The stair gate wants the socket's target: 2.",
		"Take target 2 to the dry stair gate, through the chart room hatch."],
	"p13": ["The balance in the laboratory compares samples against an empty tray.",
		"Her work card from the kitchen carries a specimen number.",
		"The sample cards by the balance give each sample's specimen number. One is hers, and her register card carries it too.",
		"Put specimen 27-11 on the balance, address it as NORA BELL, release, then RECORD 0 / 3 / 0."],
	"p14": ["The specimen frame wants a trace, a name and the measurement.",
		"Nora's work card shows the shape of her breath. Match the sections to it. The register card gives the name; the balance gave the strip.",
		"Her work card is in the notebook: read its trace left to right and lay the tray's sections in that order.",
		"Short rises, pause, long rise. Name tab from her card, clip the 0/3/0 strip, seal the frame."],
	"done": ["The laboratory is finished with me.", "Nora's frame belongs at the lantern.",
		"Take the frame up the stair to the lantern gallery."],
}
const REF_OBJ := {
	"p10": "Find the jar whose water follows the station datum, and seat it in the reference socket.",
	"wait_p12": "The socket gave the stair its target: 2. The stair gate comes next.",
	"p13": "Weigh the samples against the empty tray. One of them answers to a name.",
	"p14": "Build Nora's breath into the specimen frame, with her name and her weight.",
	"done": "Nora's frame is made. The laboratory has nothing more for me.",
}

func test_objectives_hints() -> void:
	var stages := [[1, "p10"], [3, "wait_p12"], [4, "p13"], [5, "p13"], [6, "p14"], [7, "p14"], [8, "done"], [9, "done"]]
	for s in stages:
		var g := GameSim.new()
		var r := r07(g)
		r.debug_jump(s[0])
		var o := r.objective()
		check(o == s[1], "jump %d: objective %s (got %s)" % [s[0], s[1], o])
		check(r.objective_text() == REF_OBJ[s[1]], "jump %d: objective text" % s[0])
		var ladder: Array = REF_HINTS[s[1]]
		for lvl in r.hint_tiers():
			check(r.hint_line(lvl) == ladder[mini(lvl, ladder.size() - 1)], "jump %d: hint %d" % [s[0], lvl])
		if s[1] in ["p10", "p13", "p14"]:
			check(r.hint_tiers() == 4 and R07Sim.HINTS[s[1]].size() == 4, "%s: four tiers, the evidence before the solution" % s[1])

func test_use_item() -> void:
	var g := game_at(4, ROOM)
	var r := r07(g)
	for it in ["inspection_lens", "pencil", "nora_register_card", "nora_frame", "chart_clips"]:
		g.give(it)
	var cases := [
		["inspection_lens", "datum_line", "Under the lens the plumb line is a single hair."],
		["inspection_lens", "tank", "Through the lens the ripples go the way ripples go."],
		["inspection_lens", "jar_b", "A hairline is etched round each jar at the half."],
		["inspection_lens", "rest_a", "A hairline is etched round each jar at the half."],
		["inspection_lens", "basin", "The drops leave the tap already slanted."],
		["inspection_lens", "sealed_jar", "Etched letters, on the inside of the glass."],
		["inspection_lens", "control_tray", "Clean felt."],
		["inspection_lens", "sample_rack", "Ordinary shell. Limpet, mussel."],
		["inspection_lens", "reg_rook", "The stamps were inked the same day, from the same pad."],
		["inspection_lens", "smp_n", "The tube is empty. Nothing, even under the lens."],
		["pencil", "name_tab", "I'd be writing from memory. Her register card has it exactly."],
		["pencil", "register", "Not mine to amend. Not yet."],
		["nora_register_card", "holder", "She's been weighed already."],
		["nora_register_card", "register", "I'll keep it. The register can stay one card short."],
		["nora_frame", "frame_stand", "It stays sealed. The lantern is where it's used."],
		["chart_clips", "strip_clip", "The frame has its own clip."],
	]
	for c in cases:
		var inv := JSON.stringify(g.state.inventory)
		var ev := use(g, c[0], c[1])
		check(says(ev).begins_with(c[2]), "%s on %s (got %s)" % [c[0], c[1], says(ev)])
		check(JSON.stringify(g.state.inventory) == inv, "%s on %s keeps the inventory" % [c[0], c[1]])
	var inv2 := JSON.stringify(g.state.inventory)
	check(says(use(g, "pencil", "tank")) == GameSim.GENERIC_WRONG_USE and JSON.stringify(g.state.inventory) == inv2,
		"a wrong item gets the generic line and keeps everything")
	check(says(use(g, "inspection_lens", "reference_socket")) == GameSim.GENERIC_WRONG_USE, "the lens on the empty socket")
	# Later states.
	var h := game_at(9, ROOM)
	h.give("inspection_lens")
	check(says(use(h, "inspection_lens", "tank")) == "No ripples at all. It's a surface, not water.", "lens on the pane")
	check(says(use(h, "inspection_lens", "socket")) == "Through the lens, C's surface is perfectly flat. Not a tremor.", "lens on C")
	check(says(use(h, "inspection_lens", "sealed_jar")) == "'Retention is not resuscitation.' Cut from the inside.", "lens on the jar after")
	check(says(use(h, "inspection_lens", "tray")) == "A fleck of flour in the print." and r07(h).has_seen("thumb_flour"), "lens on the thumb")
	check(says(use(h, "inspection_lens", "sample_rack")) == "Shell. Only shell. They grew into rings.", "lens on the rings")
	var m := game_at(6, ROOM)
	m.give("inspection_lens")
	check(says(use(m, "inspection_lens", "tank")) == "In the lens the reflection's ripples run the other way to the water's.", "lens on the lag")
	check(r.local_view == "room", "lens uses leave the view alone")

func test_bench_hotspots() -> void:
	var g := game_at(9, ROOM)
	var r := r07(g)
	check(not r.is_closeup("bench") and not r.is_closeup("room") and r.is_closeup("c_frame"), "bench is a base view")
	for h in R07Sim.BENCH_HOTSPOTS:
		r.local_view = "bench"
		check(says(g.dispatch(h)) != "", "tide IX bench hotspot %s answers" % h)
	var f := fresh()
	for h in R07Sim.BENCH_HOTSPOTS:
		r07(f).local_view = "bench"
		check(says(f.dispatch(h)) != "", "first visit bench hotspot %s answers" % h)
	r.local_view = "room"
	g.dispatch("to_bench")
	check(r.local_view == "bench", "to_bench")
	check(says(g.dispatch("to_tank")) == "The tank wall." and r.local_view == "room", "to_tank")
	g.dispatch("to_bench")
	g.dispatch("back")
	check(r.local_view == "room", "back from the bench")
	g.dispatch("register")
	check(r.local_view == "c_balance", "the register opens the balance")
	g.dispatch("back")
	check(r.local_view == "bench", "back to the bench")

func test_doors() -> void:
	var g := game_at(4, ROOM)
	var ev := g.dispatch("vault_door")
	check(says(ev) == "A steel door marked RECORDS. Latched from the far side." and has_ev(ev, "sfx", "door_rattle"), "vault latched")
	ev = g.dispatch("return_door")
	check(says(ev) == "A door marked STAIR. Dry, and cold. It opens from the other side." and has_ev(ev, "sfx", "door_rattle"), "stair shut")
	check(r07(g).has_seen("vault_door") and r07(g).has_seen("return_door"), "doors noted")
	g = game_at(5, ROOM)
	check(says(g.dispatch("return_door")) == "The stair's through here." and g.exit_open(ROOM, "R11"), "stair after P12")
	check(says(g.dispatch("vault_door")).begins_with("A steel door"), "vault still latched at tide V")
	g = game_at(6, ROOM)
	ev = g.dispatch("vault_door")
	check(says(ev) == VAULT_AJAR and not has_ev(ev, "sfx", "door_rattle") and r07(g).state.vault_ajar_said,
		"vault after P15: the silent notice's line on the first click (got %s)" % says(ev))
	ev = g.dispatch("vault_door")
	check(says(ev) == "The vault's through here." and not has_ev(ev, "sfx", "door_rattle") and g.exit_open(ROOM, "R10"), "vault after P15")

func test_debug_prepare_items() -> void:
	var g := game_at(6, ROOM)
	check(g.has_item("nora_frame") and g.has_item("nora_register_card"), "tide VI: frame and card")
	check(g.state.inventory.count("nora_frame") == 1, "one frame")
	g = game_at(9, ROOM)
	check(g.has_item("nora_frame") and not g.has_item("nora_register_card"), "tide IX: no original card from R07")
	g = game_at(5, ROOM)
	var r := r07(g)
	check(r.state.p10_complete and r.state.lean_seen and r.has_seen("datum_target") and not g.has_item("nora_register_card"),
		"tide V: P10 behind her")

func test_debug_jumps() -> void:
	var g := GameSim.new()
	var r := r07(g)
	var want := {
		1: [4, false, false, false], 2: [4, false, false, false], 3: [4, true, false, false],
		4: [5, true, false, false], 5: [5, true, false, false], 6: [5, true, true, false],
		7: [5, true, true, false], 8: [5, true, true, true], 9: [9, true, true, true],
	}
	for n in range(1, 10):
		r.last_test = "A"
		r.held = "short"
		r.frame_miss = [1]
		r.balance_note = "CONSTANT"
		r.debug_jump(n)
		var got := [g.tide(), g.flag("P10"), g.flag("P13"), g.flag("P14")]
		check(JSON.stringify(got) == JSON.stringify(want[n]), "jump %d: %s (got %s)" % [n, want[n], got])
		check(g.state.room == ROOM and r.local_view == "room" and r.last_test == "" and r.held == ""
			and r.frame_miss == [] and r.balance_note == "", "jump %d: clean" % n)
	r.debug_jump(1)
	check(r.state.cradle == "" and not r.state.tested.A, "jump 1: fresh")
	r.debug_jump(2)
	check(r.state.cradle == "C" and r.state.tested.A and r.state.tested.B and r.state.tested.C, "jump 2: ready to seat")
	g.dispatch("tilt_rack")
	g.dispatch("seat")
	check(g.flag("P10"), "jump 2: seat solves")
	r.debug_jump(3)
	check(r.state.lean_seen and r.state.socket == "C", "jump 3: lean seen")
	r.debug_jump(4)
	check(r.state.pan == "" and r.objective() == "p13", "jump 4: fresh balance")
	r.debug_jump(5)
	check(r.state.pan == "N" and r.state.holder == "BELL" and int(r.state.step) == 1, "jump 5: addressed")
	play(g, ["to_bench", "balance", "key_release", "key_record"])
	check(g.flag("P13"), "jump 5: release and record solve")
	r.debug_jump(6)
	check(g.has_item("nora_register_card") and r.state.thumb_seen, "jump 6: card given")
	r.debug_jump(7)
	check(r.state.slots == ["short", "pause", "long"] and r.state.name_tab and r.state.strip_clipped and r.state.frame_opened,
		"jump 7: ready to seal")
	play(g, ["to_bench", "frame_stand", "seal"])
	check(g.flag("P14") and g.has_item("nora_frame"), "jump 7: seal solves")
	r.debug_jump(8)
	check(r.state.fog_seen and g.has_item("nora_frame") and r.has_seen("inscription"), "jump 8: fog seen")
	r.debug_jump(9)
	check(g.weather_band() == 7, "jump 9: band 7")

## The lead's chain_test play_p10/p13/p14 scripts, on one game.
func test_chain_scripts() -> void:
	var g := with_flags(["P09"], ROOM)
	play(g, ["tilt_rack", "rest_c", "tip", "seat", "back"])
	check(g.flag("P10") and r07(g).local_view == "room", "chain P10")
	g.set_flag("P11")
	g.set_flag("P12")
	play(g, ["to_bench", "balance", "smp_n", "reg_bell", "key_address", "key_release", "key_record", "back"])
	check(g.flag("P13") and g.has_item("nora_register_card") and r07(g).local_view == "bench", "chain P13")
	play(g, ["frame_stand", "sec_short", "slot_0", "sec_pause", "slot_1", "sec_long", "slot_2",
		"item:nora_register_card", "name_tab", "strip_clip", "seal", "back"])
	check(g.flag("P14") and g.has_item("nora_frame") and g.has_item("nora_register_card"), "chain P14")
	for o in ["datum_target", "nora_mass_trace", "nora_breath_trace", "inscription"]:
		check(g.has_seen(ROOM, o), "chain: %s noted" % o)

func test_tide_round_trips() -> void:
	for t in range(1, 10):
		var a := game_at(t, ROOM)
		var b := GameSim.new()
		b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
		check(JSON.stringify(r07(b).state) == JSON.stringify(r07(a).state), "tide %d: R07 state survives a load" % t)
	for n in range(1, 10):
		var a := GameSim.new()
		r07(a).debug_jump(n)
		var b := GameSim.new()
		b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
		check(JSON.stringify(r07(b).state) == JSON.stringify(r07(a).state), "jump %d: R07 state survives a load" % n)

# ---------------------------------------------------------------------------------------------
# the view (guarded: the view team owns R07_view.gd)
# ---------------------------------------------------------------------------------------------
const CLOSEUP_CONSTS := {"c_tilt_rack": "RACK_CONTROLS", "c_balance": "BALANCE_CONTROLS", "c_frame": "FRAME_CONTROLS"}

func _controls(v: RoomView, cid: String) -> Array:
	if v.has_method("closeup_controls"):
		return v.closeup_controls(cid)
	return v.c(CLOSEUP_CONSTS[cid], [])

func _check_rect(tag: String, rr: Rect2) -> void:
	check(CANVAS.encloses(rr), "%s is on the canvas" % tag)
	check(rr.size.x >= MIN_TARGET and rr.size.y >= MIN_TARGET, "%s is at least 64x64" % tag)
	check(not rr.intersects(HUD_ZONE) and not rr.intersects(INVENTORY_ZONE) and not rr.intersects(SUBTITLE_ZONE),
		"%s keeps clear of the HUD, inventory and subtitles" % tag)

func test_view_scene() -> void:
	var scene = new_scene("user://room_test_R07_view.json")
	await process_frame
	scene.room_jump(ROOM, 4)
	await process_frame
	var v: RoomView = scene.room_view
	var r := scene.room_sim() as R07Sim
	var bench: Array = v.c("BENCH_HOTSPOTS", [])
	if bench.is_empty():
		print("SKIP: R07 bench rects: the view does not yet declare BENCH_HOTSPOTS (view team)")
	else:
		var ids := []
		for h in bench:
			ids.append(h[0])
			_check_rect("bench " + h[0], h[1])
		for id in R07Sim.BENCH_HOTSPOTS:
			check(id in ids, "the view has a bench rect for %s" % id)
		r.local_view = "bench"
		for h in bench:
			check(scene.action_at(h[1].get_center()) == h[0], "view: bench click reaches %s" % h[0])
	for cid in R07Sim.CLOSEUPS:
		var table := _controls(v, cid)
		if table.is_empty():
			print("SKIP: R07 %s control rects: the view does not declare them (view team)" % cid)
			continue
		var ids := []
		for h in table:
			ids.append(h[0])
			_check_rect("%s %s" % [cid, h[0]], h[1])
		var sim_ids: Array = {"c_tilt_rack": R07Sim.RACK_CONTROLS, "c_balance": R07Sim.BALANCE_CONTROLS,
			"c_frame": R07Sim.FRAME_CONTROLS}[cid]
		for id in sim_ids:
			check(id in ids, "the view has a %s rect for %s" % [cid, id])
		r.local_view = cid
		for h in table:
			check(scene.action_at(h[1].get_center()) == h[0], "view: %s click reaches %s" % [cid, h[0]])
	r.local_view = "room"
	# Doors: the stair opens at P12 (tide V), the vault at P15 (tide VI).
	var vd: Rect2 = v.hotspot_rect("vault_door")
	var rd: Rect2 = v.hotspot_rect("return_door")
	check(scene.action_at(vd.get_center()) != "go:R10", "view: vault_door before P15 is not a way out")
	check(scene.action_at(rd.get_center()) == "go:R11", "view: return_door after P12 goes to R11")
	scene.room_jump(ROOM, 1)
	await process_frame
	v = scene.room_view
	check(scene.action_at(v.hotspot_rect("return_door").get_center()) != "go:R11", "view: return_door before P12")
	scene.tide_jump(6, ROOM)
	await process_frame
	v = scene.room_view
	var vc: Vector2 = v.hotspot_rect("vault_door").get_center()
	check(scene.action_at(vc) == "vault_door", "view: the first vault_door click after P15 says the silent notice's line")
	scene.dispatch("vault_door")
	check(scene.action_at(vc) == "go:R10", "view: then vault_door goes to R10")
	var soft: Array = v.c("SFX_SOFT", [])
	for id in ["breath_hiss", "socket_refuse", "key_refuse", "door_rattle"]:
		check(id in soft, "SFX_SOFT has %s" % id)
	await free_scene(scene)

# ---------------------------------------------------------------------------------------------
# round w2 fixes
# ---------------------------------------------------------------------------------------------
const P14_TAIL := "CATEGORY: BODY. Printed, not written. The frame was waiting to be filled."
const VAULT_AJAR := "The vault door's open a hand's width."
const RULE_WORDS := ["GRAVITY", "JAR", "DATUM"]
const REF_CARD_W2 := "A valid sample keeps the station's own level: the brass, not the bob, not the glass."

func _has_rule_word(t: String) -> bool:
	for w in RULE_WORDS:
		if t.to_upper().contains(w):
			return true
	return false

## P10 is a test, not a word match: the looks are neutral, the rest angle is one angle, and the
## card names the brass, not a rule word.
func test_w2_p10_neutral() -> void:
	for j in R07Sim.JARS:
		var g := fresh()
		var ev := g.dispatch("jar_" + j.to_lower())
		check(says(ev) == "Jar %s. Half full. Sealed with wax." % j, "jar %s: the neutral look (got %s)" % [j, says(ev)])
		check(not says(ev).contains("slant") and not says(ev).contains("square"), "jar %s: no rule in the look" % j)
	check(R07Sim.REF_CARD == REF_CARD_W2, "the reference card")
	check(R07Sim.OBSERVATIONS.reference_card.contains("'" + REF_CARD_W2 + "'"), "the notebook quotes the card")
	check(not _has_rule_word(R07Sim.REF_CARD), "the card carries no rule word")
	var rest := R07Sim.rack_rest_deg("A")
	check(rest == R07Sim.surface_deg(R07Sim.JAR_RULE.A, R07Sim.RACK_CANT_DEG), "the rest angle is jar A's")
	check(R07Sim.rack_rest_deg("B") == rest and R07Sim.rack_rest_deg("C") == rest, "the rack rest angle is the same for A, B and C")
	# the tank's own look still names the slant
	var t := fresh()
	check(says(t.dispatch("tank")).contains("plumb bob's slant"), "the tank's look stays")
	# the answer is still C; the wrong-seat lines are unchanged
	var g := fresh()
	solve_p10(g)
	check(g.flag("P10"), "seat C solves")

## vault_ajar arrives silent (fx and sound only); its line is said on her first click on the
## door, once, and the flag saves and loads.
func test_w2_silent_vault() -> void:
	var g := game_at(5, "R05")
	var r := r07(g)
	for f in ["P13", "P14", "P15"]:
		g.set_flag(f)
	var ev := g.dispatch("go:R07")
	check(count_ev(ev, "fx", "notice_vault_ajar") == 1 and has_ev(ev, "sfx", "vault_settle"), "vault_ajar: the visual and the sound")
	check(not says(ev).contains(VAULT_AJAR), "vault_ajar: no line on arrival (got %s)" % says(ev))
	check(r.has_seen("vault_ajar") and not r.state.vault_ajar_said, "noted, not yet said")
	# a save before the click keeps it unsaid
	var b := GameSim.new()
	b.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(not r07(b).state.vault_ajar_said, "unsaid survives a load")
	ev = g.dispatch("vault_door")
	check(says(ev) == VAULT_AJAR and r.state.vault_ajar_said, "the first click says it (got %s)" % says(ev))
	check(says(g.dispatch("vault_door")) == "The vault's through here.", "then the door is a way through")
	var c := GameSim.new()
	c.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(r07(c).state.vault_ajar_said, "said survives a load")
	c.state.room = ROOM
	check(says(c.dispatch("vault_door")) == "The vault's through here.", "and is never said twice")
	var m := load_with({"vault_ajar_said": "yes"})
	check(m.state.vault_ajar_said == false, "a malformed said flag is dropped")
	check(R07Sim.NOTICE_LINES.vault_ajar == VAULT_AJAR, "the terser notice line")

func test_w2_lines() -> void:
	check(R07Sim.LEAN_LINES == ["...The water in C leaned toward me.", "Now it's level again. It took longer than water should."],
		"the lean pair")
	var g := balance_game()
	var ev := play(g, ["smp_n", "reg_bell", "key_address", "key_release", "key_record"])
	check(says(ev).ends_with("Pressed into the felt. The nap hasn't risen back yet."), "the thumb follow-up (got %s)" % says(ev))
	var f := frame_game(false)
	place(f, ["long", "pause", "short"])
	complete_frame(f)
	check(says(f.dispatch("seal")) == "I need her trace to compare. It's on the nail by the range.", "the seen-gate line")

## Rewards are seen: each commit chain ends with a glance fx at the socket / the bench frame.
func test_w2_glances() -> void:
	var g := fresh()
	var ev := solve_p10(g)
	var gi := ev_index(ev, "fx", "glance")
	check(gi >= 0 and ev[gi].get("glance") == "p10" and ev[gi].get("rect") == Rect2(716, 318, 130, 362), "P10 glances at the socket")
	check(gi > ev_index(ev, "fx", "tag") and gi == ev.size() - 1, "the P10 glance ends the chain")
	var f := frame_game()
	place(f, REF_SOLUTION)
	complete_frame(f)
	ev = f.dispatch("seal")
	gi = ev_index(ev, "fx", "glance")
	check(gi >= 0 and ev[gi].get("glance") == "p14" and ev[gi].get("rect") == Rect2(720, 330, 250, 270),
		"P14 glances at the bench frame")
	check(gi == ev.size() - 1, "the P14 glance ends the chain")
	check(not has_ev(f.dispatch("seal"), "fx", "glance"), "a re-seal has no glance")
	check(R07Sim.WAY_IN_HINT == "The hatch in the kitchen floor is open: the laboratory and the machine room.", "WAY_IN_HINT")

## P13 and P14 without printed answers: the cards' line and notebook carry no readings, the
## sections no names.
func test_w2_no_printed_answers() -> void:
	for t in [R07Sim.SAMPLE_CARDS_LINE, R07Sim.OBSERVATIONS.sample_cards]:
		for pat in ["0 → 3", "3 → 0", "nought, three", "2 → 2", "two all"]:
			check(not t.contains(pat), "sample cards carry no reading: %s" % pat)
	check(JSON.stringify(R07Sim.SPECIMEN) == JSON.stringify({"W": "27-03", "N": "27-11", "F": "27-19"}),
		"the samples carry specimen numbers only")
	var f := frame_game()
	for s in ["short", "pause", "long"]:
		var line := says(f.dispatch("sec_" + s))
		check(line == "A trace section.", "picking up %s names nothing (got %s)" % [s, line])
	for w in ["SHORT RISES", "LONG RISE", "PAUSE"]:
		check(not R07Sim.OBSERVATIONS.frame_stand.contains(w), "the frame_stand note names no section: %s" % w)

## View-side: nothing in the test cells spells a rule; rest surfaces agree; the frame's tiles
## carry no words; the RECORDS and STAIR exits point at their doors; a glance brackets.
func test_w2_view() -> void:
	var scene = new_scene("user://room_test_R07_w2.json")
	await process_frame
	scene.room_jump(ROOM, 2)
	await process_frame
	var v: RoomView = scene.room_view
	var r := scene.room_sim() as R07Sim
	var words: Dictionary = v.c("REF_WORD", {})
	r.local_view = "c_tilt_rack"
	for j in R07Sim.JARS:
		r.state.cradle = j
		scene.dispatch("tip")
		for t in v.test_cell_texts():
			for w in words.values():
				check(not str(t).contains(w), "after tipping %s, test cell text %s has no %s" % [j, t, w])
		check(is_nan(v.test_surface_deg(j)) or v.test_surface_deg(j) == v.REF_ANGLES[R07Sim.JAR_RULE[j]],
			"%s: the pen draws its surface" % j)
	# rest surfaces agree, on the rack and in the close-up
	var a: float = v.jar_surface_deg("A", Vector2(916, 668), 12.0)
	check(v.jar_surface_deg("B", Vector2(1028, 668), 12.0) == a and v.jar_surface_deg("C", Vector2(1140, 668), 12.0) == a,
		"room rack: the three surfaces agree at rest")
	check(v._close_theta("A", 12.0, Vector2(190, 690)) == v._close_theta("B", 12.0, Vector2(390, 690))
		and v._close_theta("C", 12.0, Vector2(590, 690)) == v._close_theta("A", 12.0, Vector2(190, 690)),
		"close-up: the three surfaces agree at rest")
	check(v._close_theta("B", 90.0, Vector2(860, 600), 1.0) == 90.0 and v._close_theta("C", 90.0, Vector2(860, 600), 1.0) == 0.0,
		"only the tip shows a jar's own rule")
	# the frame's sections: no labels
	for s in R07Sim.SECTIONS:
		check(v.label_for("sec_" + s) == "Trace section", "hover on %s names nothing" % s)
	# exit arrows
	check(v.exit_arrow("R10") == "right" and v.exit_arrow("R11") == "left" and v.exit_arrow("R05") == "",
		"exit arrows point to the painted doors")
	# a glance: the hold's brackets on the socket (in the close-up, on the close layer)
	r.local_view = "c_tilt_rack"
	check(v.start_glance("p10", Rect2(716, 318, 130, 362)) and v.hold_active(), "start_glance holds")
	check(v.hold_close == Rect2(1110, 380, 240, 400), "in the rack close-up the glance brackets the socket there")
	v.reset_presentation()
	r.local_view = "room"
	v.play_fx("glance", {"id": "glance", "glance": "p14", "rect": Rect2(720, 330, 250, 270), "delay": 0.5})
	check(not v.hold_active(), "a glance waits for its delay")
	v.tick(0.6)
	check(v.hold_active() and v.hold_rect == Rect2(720, 330, 250, 270), "then holds on its rect")
	# sounds: the louder bed, the ducks kept
	var lt: Dictionary = v.loop_targets()
	check(absf(linear_to_db(lt["r07_room"]) - (-6.0)) < 0.01, "r07_room at -6 dB in the room")
	var sdb: Dictionary = v.c("SFX_DB", {})
	for id in sdb:
		check(float(sdb[id]) <= 0.0, "SFX %s capped at 0 dB" % id)
	check(float(sdb.get("socket_click", -99)) == -1.0 and float(sdb.get("breath_hiss", -99)) == 0.0, "SFX raised 6 dB, capped")
	r.local_view = "c_tilt_rack"
	lt = v.loop_targets()
	check(linear_to_db(lt["r07_tank_hum"]) <= -13.99, "the close-up duck is kept (-4 dB)")
	r.local_view = "room"
	await free_scene(scene)

# ---------------------------------------------------------------------------------------------
# w3: the tip result is seen, not named; taking a card out is never silent
# ---------------------------------------------------------------------------------------------
func test_w3_visual_results() -> void:
	for j in R07Sim.JARS:
		var line: String = R07Sim.TIP_LINES[j]
		for w in ["GRAVITY", "JAR.", "DATUM", "follows"]:
			check(not line.contains(w), "tip line %s names no answer: %s" % [j, w])
	var obs: Dictionary = R07Sim.OBSERVATIONS
	check(obs.test_a.ends_with("its surface stayed on the solid line."), "test_a ends on the solid line")
	check(obs.test_c.ends_with("square with the room, whatever the jar did."), "test_c ends square with the room")
	for k in ["test_a", "test_b", "test_c"]:
		for w in ["A follows gravity.", "C follows the datum.", "follows its jar."]:
			check(not obs[k].contains(w), "%s names no rule: %s" % [k, w])
	check(R07Sim.OBSERVATIONS.rack.contains("GRAVITY (solid), JAR (dashed), DATUM (dot-dash)"),
		"the test card keeps its three printed lines")

func test_w3_holder_names() -> void:
	for n in REF_NAMES:
		var g := balance_game()
		var r := r07(g)
		play(g, ["smp_n", "reg_" + n.to_lower(), "key_address"])
		var ev := g.dispatch("holder")
		var want: String = "I take %s's card back out." % (n.substr(0, 1) + n.substr(1).to_lower())
		check(says(ev) == want, "removing %s names it (got %s)" % [n, says(ev)])
		check(has_ev(ev, "sfx", "card_flick"), "removing %s is heard" % n)
		check(r.state.holder == "" and int(r.state.step) == 0, "removing %s empties the holder" % n)
		check(not g.has_item("nora_register_card"), "removing %s gives nothing" % n)

func test_w3_view() -> void:
	var scene = new_scene("user://room_test_R07_w3.json")
	await process_frame
	scene.room_jump(ROOM, 2)
	await process_frame
	var v: RoomView = scene.room_view
	# tide t opens band t-2; R07 is reachable from tide 4 (band 2)
	var want := {4: [], 5: [], 6: ["waterline"], 7: ["waterline"], 8: ["waterline", "ceiling_rings"],
		9: ["waterline", "ceiling_rings", "wall_hand"]}
	for t in range(4, 10):
		scene.sim.debug_tide(t, ROOM)
		await process_frame
		var r := scene.room_sim() as R07Sim
		var got: Array = v.deep_layers()
		check(JSON.stringify(got) == JSON.stringify(want[t]), "tide %d (band %d): deep layers %s (got %s)" % [t, r.band(), want[t], got])
		for id in got:
			check(v._tex(id) != null, "%s loads" % id)
		if r.band() >= 4:
			check(v.plumb_deg() == R07Sim.GRAVITY_DEG and R07Sim.GRAVITY_DEG == -8.0,
				"band %d: the GRAVITY tag hangs eight degrees off the square waterline" % r.band())
	# every hotspot rect is unchanged by the water
	for id in R07Sim.HOTSPOTS:
		check(v.hotspot_rect(id).size.x > 0.0, "hotspot %s keeps its rect under the water" % id)
	scene.sim.finish("sever")
	await process_frame
	check(v.deep_layers().is_empty(), "sever drains the room")
	await free_scene(scene)

# ---------------------------------------------------------------------------------------------
# round p1: dread during the puzzles, the leaning water, specimen numbers, evidence hints
# ---------------------------------------------------------------------------------------------
const ARRIVAL_P1 := "The wet laboratory. Three sealed jars of seawater on a canted rack. The water in all three leans toward the stair door."
## The hotspot rects as approved (the overlays never move one).
const REF_ROOM_RECTS := {
	"jar_a": Rect2(860, 572, 112, 196), "jar_b": Rect2(972, 572, 112, 196), "jar_c": Rect2(1084, 572, 112, 196),
	"reference_socket": Rect2(716, 318, 130, 362), "datum_line": Rect2(866, 252, 190, 296),
	"basin": Rect2(198, 520, 152, 260), "tilt_rack": Rect2(848, 552, 352, 244), "tank": Rect2(366, 400, 340, 428),
	"vault_door": Rect2(1208, 318, 155, 534), "return_door": Rect2(26, 330, 152, 522),
	"to_bench": Rect2(600, 850, 248, 64),
}
const REF_BENCH_RECTS := {
	"control_tray": Rect2(540, 470, 140, 110), "balance": Rect2(300, 300, 380, 300),
	"sample_cards": Rect2(60, 160, 220, 200), "register": Rect2(80, 640, 300, 150),
	"frame_stand": Rect2(720, 330, 250, 270), "sealed_jar": Rect2(974, 396, 204, 204),
	"sample_rack": Rect2(1190, 360, 220, 240), "to_tank": Rect2(600, 850, 248, 64),
}

func test_p1_lines() -> void:
	check(R07Sim.ARRIVAL_WET == ARRIVAL_P1, "the band >= 2 arrival line")
	check(R07Sim.ARRIVAL == "The wet laboratory. Three sealed jars of seawater on a canted rack, all half full.",
		"the band < 2 arrival line is kept")
	# Real play: the hatch opens at P09, the start of tide IV, band 2.
	var g := game_at(4, "R05")
	var r := r07(g)
	r.state.notices = []
	g.state.visited.erase(ROOM)
	var ev := g.dispatch("go:R07")
	check(r.band() == 2 and says(ev).begins_with(ARRIVAL_P1), "band 2: the water leans toward the stair door (got %s)" % says(ev))
	check(not says(ev).contains("all half full"), "band 2: not the old line")
	# Below band 2 (a debug fixture) the old line stands.
	var low := with_flags(["P09"], "R05")
	if r07(low).band() < 2:
		check(says(low.dispatch("go:R07")).begins_with(R07Sim.ARRIVAL), "band < 2: the old arrival line")
	else:
		print("SKIP: no band < 2 fixture reaches R07")
	# The socket says what C's water does now.
	var t6 := game_at(6, ROOM)
	check(says(t6.dispatch("reference_socket")) == "Even C's water leans toward the stair door now. The tag still says 2.",
		"band 4: the socket line")
	var t7 := game_at(7, ROOM)
	check(says(t7.dispatch("reference_socket")) == "Even C's water leans to the vault door now. The tag still says 2.",
		"band 5: the vault line is kept")
	# The P14 line is in the notebook from the debug stages too.
	var j := GameSim.new()
	r07(j).debug_jump(8)
	check(r07(j).has_seen("down"), "jump 8: the lean is in the notebook")

func test_p1_specimens() -> void:
	var visible := [R07Sim.SAMPLE_CARDS_LINE, R07Sim.OBSERVATIONS.sample_cards, R07Sim.OBSERVATIONS.nora_mass_trace,
		R07Sim.OBSERVATIONS.register, R07Sim.STAMP_N]
	for s in R07Sim.SAMPLES:
		visible.append(R07Sim.SAMPLE_LINES[s])
		visible.append(R07Sim.SPECIMEN[s])
		visible.append(R07Sim.CARD_CONTENTS[s])
	for t in visible:
		for pat in ["N-27", "W-27", "F-27", "Sample N", "Sample W", "Sample F", "sample N", " N,", " W,", " F,"]:
			check(not str(t).contains(pat), "no sample letter in '%s' (%s)" % [t, pat])
	check(R07Sim.STAMP_N == "SPECIMEN 27-11" and R07Sim.SPECIMEN.N == "27-11", "Nora's is 27-11")
	check(R07Sim.OBSERVATIONS.register.ends_with("Only Nora Bell's also carries SPECIMEN 27-11."), "the register carries it")
	check(R07Sim.SAMPLE_ORDER == ["W", "N", "F"], "stands and cards in specimen order")
	for i in R07Sim.SAMPLE_ORDER.size() - 1:
		check(R07Sim.SPECIMEN[R07Sim.SAMPLE_ORDER[i]] < R07Sim.SPECIMEN[R07Sim.SAMPLE_ORDER[i + 1]], "ascending order")
	# The solution item and its outcome are unchanged.
	var g := balance_game()
	var ev := play(g, ["smp_n"])
	check(says(ev) == "Specimen 27-11. A stoppered tube. It looks empty.", "27-11 on the pan (got %s)" % says(ev))
	ev = play(g, ["reg_bell"])
	check(says(ev).ends_with("and SPECIMEN 27-11."), "her register card carries 27-11 (got %s)" % says(ev))
	play(g, ["key_address", "key_release", "key_record"])
	check(g.flag("P13") and g.has_item("nora_register_card") and r07(g).has_seen("nora_mass_trace"), "27-11 + BELL records")

func test_p1_lean_sim() -> void:
	for t in range(4, 10):
		var g := game_at(t, ROOM)
		var r := r07(g)
		var want: bool = r.band() >= 4 and r.band() <= 6
		check(r.stair_lean() == want, "tide %d band %d: stair lean %s" % [t, r.band(), want])
	var g := game_at(9, ROOM)
	g.finish("sever")
	check(not r07(g).stair_lean(), "sever: no lean")
	check(R07Sim.STAIR_LEAN_DEG == -12.0 and R07Sim.RACK_CANT_DEG == 12.0 and R07Sim.GRAVITY_DEG == -8.0
		and R07Sim.DATUM_DEG == 0.0, "the lean is 12 degrees; the rack, gravity and datum keep theirs")

func test_p1_view() -> void:
	var scene = new_scene("user://room_test_R07_p1.json")
	await process_frame
	scene.room_jump(ROOM, 2)
	await process_frame
	var v: RoomView = scene.room_view
	for id in REF_ROOM_RECTS:
		check(v.hotspot_rect(id) == REF_ROOM_RECTS[id], "room rect %s unchanged" % id)
	for h in v.c("BENCH_HOTSPOTS", []):
		check(REF_BENCH_RECTS.get(h[0]) == h[1], "bench rect %s unchanged" % h[0])
	var want := {
		4: [["b2_tidemark"], ["b2_tidemark_bench"]],
		5: [["b2_tidemark"], ["b2_tidemark_bench"]],
		6: [["b2_tidemark", "b4_water_lean"], ["b2_tidemark_bench", "b4_lamp_pool"]],
		7: [["b2_tidemark", "b4_water_lean"], ["b2_tidemark_bench", "b4_lamp_pool"]],
		8: [["b2_tidemark", "b4_water_lean"], ["b2_tidemark_bench", "b4_lamp_pool"]],
		9: [["b2_tidemark"], ["b2_tidemark_bench", "b4_lamp_pool"]],
	}
	for t in range(4, 10):
		scene.sim.debug_tide(t, ROOM)
		await process_frame
		v = scene.room_view
		var r := scene.room_sim() as R07Sim
		r.local_view = "room"
		var a: Array = v.stage_overlays()
		r.local_view = "bench"
		var b: Array = v.stage_overlays()
		r.local_view = "c_balance"
		var cb: Array = v.stage_overlays()
		r.local_view = "room"
		check(JSON.stringify([a, b]) == JSON.stringify(want[t]), "tide %d band %d: overlays %s (got %s)" % [t, r.band(), want[t], [a, b]])
		check(cb == b, "the bench overlays stand behind c_balance")
		for id in a + b:
			check(v._tex(id) != null, "%s loads" % id)
			check(ResourceLoader.exists("res://assets/stages/R07/%s.png" % id), "%s is a stage file" % id)
		check(v.TINT[r.band()] == 1.0, "band %d: ambient held at full" % r.band())
		# the water: band 4-6 every surface in the room leans 12 degrees toward the stair door
		var deg := []
		for j in R07Sim.JARS:
			var centre: Vector2 = v.JAR_POS[j]
			if j == "C" and r.state.socket == "C":
				centre = v.SOCKET_POS
			deg.append(v.jar_surface_deg(j, centre, r.jar_rest_rot(j)))
		if r.band() == 4:
			check(deg == [-12.0, -12.0, -12.0] and r.state.socket == "C", "band 4: A, B and C in the socket lean 12 (got %s)" % [deg])
		if r.band() <= 3:
			var c_rest: float = 0.0 if r.state.socket == "C" else -8.0
			check(deg == [-8.0, -8.0, c_rest], "band %d: the rest angles stand (got %s)" % [r.band(), deg])
		if r.band() <= 4:
			# the close-up keeps P10's geometry: the tip still shows each jar's own rule
			check(v._close_theta("B", 90.0, Vector2(860, 600), 1.0) == 90.0
				and v._close_theta("C", 90.0, Vector2(860, 600), 1.0) == 0.0, "band %d: c_tilt_rack untouched" % r.band())
		var tank: float = v.tank_surface_deg()
		var want_tank: float = {2: -8.0, 3: -8.0, 4: -12.0, 5: -12.0, 6: R07Sim.PANE_DEG}.get(r.band(), tank)
		check(tank == want_tank, "band %d: tank surface %s (got %s)" % [r.band(), want_tank, tank])
		for id in REF_ROOM_RECTS:
			check(v.hotspot_rect(id) == REF_ROOM_RECTS[id], "tide %d: %s keeps its rect" % [t, id])
	# c_balance: no sample letter in a hover label or on the stands
	for row in v.closeup_controls("c_balance"):
		if str(row[0]).begins_with("smp_"):
			check(str(row[2]).begins_with("Specimen 27-"), "%s is labelled by number (%s)" % [row[0], row[2]])
	check(v.label_for("smp_n") == "Specimen 27-11", "27-11 is the N sample")
	scene.sim.finish("sever")
	await process_frame
	check(v.stage_overlays().is_empty(), "sever releases the overlays")
	await free_scene(scene)
