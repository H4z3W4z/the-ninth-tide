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
	"A": "It stayed level with the plumb bob. GRAVITY.",
	"B": "It turned with the jar. JAR.",
	"C": "It stayed square with the room, whatever the jar did. DATUM.",
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
const KITCHEN := "I don't know her breath yet. Her work card hangs in the kitchen, by the range."
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
	if _view_ready():
		await view_checks(ROOM)
		await test_view_scene()
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
	check(ev_delay(b, "sfx", "water_lean") == 0.8 and says(b) == "...It leaned. The water in C leaned toward me. | Now it's level with the brass again.",
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
	check(int(r.state.step) == 0 and r.state.holder == "" and says(ev) == "Back in the register.", "removing the card resets")
	g.dispatch("reg_bell")
	play(g, ["key_address"])
	g.dispatch("pan")
	check(int(r.state.step) == 0 and r.state.pan == "", "removing the sample resets")
	check(says(g.dispatch("pan")) == "The pan's empty.", "the pan's empty")
	check(says(g.dispatch("holder")) == "Back in the register." and says(g.dispatch("holder")) == "The holder's empty. Names are in the register along the bottom.",
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
	check(says(s.dispatch("ref_card")) == "Her work card: two short rises, a pause, one long rise.", "ref_card seen")

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
	check(says(ev).ends_with("The label was printed before I came: CATEGORY: BODY."), "the label without the belt")
	var b := g.dispatch("back")
	check(r.local_view == "bench" and count_ev(b, "fx", "notice_fog") == 1 and count_ev(b, "sfx", "breath_hiss") == 1,
		"back plays the fog once")
	check(ev_delay(b, "sfx", "breath_hiss") == 0.8 and says(b).ends_with("'Retention is not resuscitation.'"), "the fog's lines")
	check(r.has_seen("inscription") and r.state.fog_seen and r.fog_shown(), "inscription noted")
	check(says(g.dispatch("frame_stand")) == "The stand's empty. Her frame is with me." and r.local_view == "bench", "the stand after")
	var b2 := g.dispatch("back")
	check(r.local_view == "room" and not has_ev(b2, "fx", "notice_fog"), "no second fog")
	# With the respiration reference from the machine room, the belt line follows.
	var h := frame_game()
	h.observe("R08", "reference_respiration")
	place(h, REF_SOLUTION)
	complete_frame(h)
	check(says(h.dispatch("seal")).ends_with("CATEGORY: BODY. Like the nameplate under the belt."), "the label with the belt")

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
	check(g.state.room == ROOM and says(ev).begins_with(R07Sim.ARRIVAL) and has_ev(ev, "sfx", "slosh_c"), "first arrival")
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
	"p10": ["The laboratory's three jars don't agree about level.",
		"The card wants a surface that follows the brass datum line, whatever the jar does. Test each one.",
		"Test all three. C stays parallel to the datum. Put C in the reference socket."],
	"wait_p12": ["The laboratory has given the stair what it needs.", "The stair gate wants the socket's target: 2.",
		"Take target 2 to the dry stair gate, through the chart room hatch."],
	"p13": ["The balance in the laboratory compares samples against an empty tray.",
		"One sample changes only when it is addressed. Its stamp matches one card in the register.",
		"Put N on the balance, address it as NORA BELL, release, then RECORD 0 / 3 / 0."],
	"p14": ["The specimen frame wants a trace, a name and the measurement.",
		"Nora's work card shows the order of her breath. The register card gives the name; the balance gave the strip.",
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
		for lvl in 3:
			check(r.hint_line(lvl) == REF_HINTS[s[1]][lvl], "jump %d: hint %d" % [s[0], lvl])

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
	check(scene.action_at(v.hotspot_rect("vault_door").get_center()) == "go:R10", "view: vault_door after P15 goes to R10")
	var soft: Array = v.c("SFX_SOFT", [])
	for id in ["breath_hiss", "socket_refuse", "key_refuse", "door_rattle"]:
		check(id in soft, "SFX_SOFT has %s" % id)
	await free_scene(scene)
