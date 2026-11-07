extends "res://tests/rooms/room_test_base.gd"
## R05, the Kitchen and Mess: P07 (nine appetites), P09 (the meal they removed), Nora's book,
## the escalation notices on both sides, endings, saves, debug and the view's rects.
##   godot --headless --path . --script tests/rooms/R05_test.gd

const ROOM := "R05"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := ["P06"]
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 3

## The card strings, written out here independently of the sim.
const REF_HINTS := {
	"p07": ["Nora counted meals, not employees.",
		"Compare the portions she served with the bowls and places. One bowl has no name but has a mark.",
		"Set the table for nine: each bowl on its initials, the unsigned repaired bowl on the square-marked place. Tally 9, then COMPARE."],
	"p09": ["The kitchen's shift board wants both halves of the token and a correction.",
		"The rule says keep the original and add the missing person. Nora's book and Venn's seal say who.",
		"Fit both halves. Leave 8 alone. Add +1 / VENN / present. Seal selector to three cuts, then stamp."],
	"p07_drawer": ["Something let go in the kitchen when the table agreed.",
		"A brass rod runs from the service drawer back toward the mess table.",
		"Turn to the kitchen and open the service drawer under the shift board."],
	"wait_p08": ["The token in the drawer is only half.",
		"The other half belongs to the bunk side of the service.",
		"The bunk room: put each belonging in its owner's locker."],
	"done": ["Nothing in the kitchen is waiting on me.",
		"The service hatch is open to the lower passage.",
		"Through the hatch: the laboratory and the machine room."],
}
const SOL := ["b_sr", "b_at", "b_sh", "b_ml", "b_cd", "b_ti", "b_op", "b_nb", "b_sq"]
const HOME := ["b_ti", "b_sh", "b_sq", "b_sr", "b_cd", "b_at", "b_nb", "b_op", "b_ml"]
const TILES := ["BELL", "DOANE", "HART", "IVES", "LUSK", "MERCER", "PRYCE", "ROOK", "TULL", "VENN"]
const REJECT := "REJECTED: UNVERIFIABLE CORRECTION. ORIGINAL ENTRY MUST STAND."
const STAMPED := "Stamped. It's done."
const SET_LINE := "It's set for nine. I'll leave it set."
const WRONG_SEAL := "One cut is Bell's kitchen stamp. Two is the director's. Venn's has three."
const NAME_LINE := "The amendment has to name the person. Nora's note names him."
const NOTICE_A := {4: "inward", 5: "soup", 6: "chair", 7: "chair", 8: "towel", 9: "towel"}
const NOTICE_B := {4: "", 5: "", 6: "", 7: "card_breath", 8: "fog_wiped", 9: "warm_range"}
const KITCHEN_MAX_Y := 914.0

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	test_arrival()
	test_p07_golden()
	test_misplacements()
	test_tally()
	test_independent_compare()
	test_conservation()
	test_locked_after_p07()
	test_p07_save_load()
	test_p09_refusals()
	test_p09_success()
	test_order_permutations()
	test_p09_save_load()
	test_reconcile()
	test_evidence_ids()
	test_escalation()
	test_hotspots_and_endings()
	test_objectives_hints()
	test_debug_prepare_matches_play()
	test_debug_jumps()
	test_use_item()
	test_ledger()
	test_control_rects()
	test_kitchen_rects()
	if _view_ready():
		await view_checks(ROOM)
	else:
		print("SKIP: R05 view_checks: the R05 view does not yet declare rects for every sim hotspot (view team)")

# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
func r5(g: GameSim) -> R05Sim:
	return g.room(ROOM) as R05Sim

func fresh() -> GameSim:
	return with_flags(["P06"], ROOM)

func count_fx(ev: Array, id: String) -> int:
	var n := 0
	for e in ev:
		if e.type == "fx" and e.id == id:
			n += 1
	return n

func roundtrip(g: GameSim) -> GameSim:
	var t := GameSim.new()
	check(t.from_dict(JSON.parse_string(JSON.stringify(g.to_dict()))), "save loads")
	return t

func snap(g: GameSim) -> String:
	return JSON.stringify([g.state.flags, g.state.inventory, r5(g).state])

func sorted_inv(g: GameSim) -> Array:
	var a: Array = g.state.inventory.duplicate()
	a.sort()
	return a

func open_table(g: GameSim) -> void:
	if r5(g).local_view != "c_table":
		g.dispatch("bowl_stack")

## Lays an arrangement from a full rack by real clicks: arr[k] goes on place k+1 ("" = leave).
func lay(g: GameSim, arr: Array) -> void:
	open_table(g)
	for k in 9:
		var b: String = arr[k]
		if b != "":
			g.dispatch("slot_%d" % HOME.find(b))
			g.dispatch("place_%d" % (k + 1))

func set_tally(g: GameSim, n: int) -> void:
	open_table(g)
	var r := r5(g)
	var guard := 0
	while int(r.state.tally) != n and guard < 30:
		g.dispatch("tally_up" if int(r.state.tally) < n else "tally_down")
		guard += 1

func solve_p07(g: GameSim) -> Array:
	lay(g, SOL)
	set_tally(g, 9)
	return g.dispatch("compare")

func read_ledger(g: GameSim) -> void:
	g.dispatch("ledger")
	g.dispatch("back")

## Every bowl exactly once: in the rack, on a place, or in hand.
func conserved(r: R05Sim) -> bool:
	var all := []
	for b in r.rack_contents():
		if b != "": all.append(b)
	for b in r.state.places:
		if b != "": all.append(b)
	if r.held != "": all.append(r.held)
	all.sort()
	var want := SOL.duplicate()
	want.sort()
	return all == want

## Tide III, P07 solved by clicks, the drawer open, P08 simulated with its half in hand.
func ready_p09() -> GameSim:
	var g := game_at(3, ROOM)
	solve_p07(g)
	g.dispatch("service_drawer")
	g.set_flag("P08")
	g.give("token_bunk_half")
	return g

func fit(g: GameSim, item: String, target := "shift_board") -> Array:
	g.dispatch("item:" + item)
	return g.dispatch(target)

func fit_both_turn(g: GameSim) -> void:
	fit(g, "token_pantry_half")
	fit(g, "token_bunk_half")
	g.dispatch("socket_turn")

func compose(g: GameSim, count: String, name: String, status: String, seal: int) -> void:
	var r := r5(g)
	if r.local_view != "c_service_board":
		g.dispatch("shift_board")
	var guard := 0
	while r.state.amend.count != count and guard < 8:
		g.dispatch("f_count")
		guard += 1
	if name == "":
		if r.state.amend.name != "":
			g.dispatch("f_name")
	else:
		g.dispatch("tile_%d" % TILES.find(name))
	guard = 0
	while r.state.amend.status != status and guard < 8:
		g.dispatch("f_status")
		guard += 1
	g.dispatch("seal_%d" % seal)

## Both halves are either in hand or fitted, and a fitted one can come back out.
func tokens_recoverable(g: GameSim) -> bool:
	var r := r5(g)
	for h in ["pantry", "bunk"]:
		var item := "token_%s_half" % h
		if not (g.has_item(item) or r.state.fitted[h]):
			return false
		if g.has_item(item) and r.state.fitted[h]:
			return false
	return not g.flag("P09")

func _view_ready() -> bool:
	var m: Dictionary = load("res://game/rooms/R05/R05_view.gd").get_script_constant_map()
	var ids := []
	for h in m.get("HOTSPOTS", []):
		ids.append(h[0])
	for id in R05Sim.HOTSPOTS:
		if not id in ids:
			return false
	return true

# ---------------------------------------------------------------------------------------------
# (1) first arrival
# ---------------------------------------------------------------------------------------------
func test_arrival() -> void:
	var g := with_flags(["P06"], "R06")
	var ev := g.dispatch("go:R05")
	check(g.state.room == ROOM, "walks into the kitchen from the bunks")
	check(says(ev).begins_with(R05Sim.ARRIVAL) and R05Sim.ARRIVAL == "The mess. Eight places laid. Nine spoon marks pressed into the cloth.",
		"arrival line (%s)" % says(ev))
	check("Somewhere in the kitchen a kettle is ticking. Cooling." in says(ev), "arrival: the kettle line")
	check(has_ev(ev, "sfx", "kettle_tick") and r5(g).has_seen("spoon_marks"), "arrival: kettle tick, spoon marks noted")
	g.dispatch("go:R06")
	ev = g.dispatch("go:R05")
	check(not R05Sim.ARRIVAL in says(ev) and not has_ev(ev, "sfx", "kettle_tick"), "the arrival plays once")

# ---------------------------------------------------------------------------------------------
# (2) P07 golden path, the drawer and the token
# ---------------------------------------------------------------------------------------------
func test_p07_golden() -> void:
	var g := fresh()
	var r := r5(g)
	var ev := solve_p07(g)
	check(g.flag("P07") and r.state.p07_complete, "the table for nine solves P07")
	check(r.has_seen("headcount_nine"), "headcount_nine noted")
	check(count_fx(ev, "tide") == 0 and has_ev(ev, "fx", "p07_agree"), "P07 does not end a tide")
	check(has_ev(ev, "sfx", "drawer_unlatch") and has_ev(ev, "sfx", "spoon_china"), "P07: the latch, the spoon")
	check("The spoon at the square place lifted. Half an inch. It waited for someone. Then it put itself down." in says(ev),
		"P07: the spoon line")
	check(not g.has_item("token_pantry_half"), "P07: the token waits in the drawer")
	var t3 := game_at(3, ROOM)
	var ev3 := solve_p07(t3)
	check(t3.flag("P07") and count_fx(ev3, "tide") == 0 and t3.tide() == 3, "P07 at tide III: no tide card")
	g.dispatch("to_kitchen")
	ev = g.dispatch("service_drawer")
	check(g.has_item("token_pantry_half") and r.state.drawer_open and r.has_seen("drawer_note"), "the drawer gives the token")
	check(has_ev(ev, "sfx", "drawer_slide") and has_ev(ev, "fx", "drawer_open"), "the drawer slides")
	check("'E.V. ate. Rook says he did not. I count bowls, not opinions. — N.B.'" in says(ev), "Nora's note")
	ev = g.dispatch("service_drawer")
	check(says(ev) == "Her note, and the bed the token lay in." and g.state.inventory.count("token_pantry_half") == 1,
		"a second click grants nothing")
	var l := roundtrip(g)
	l.dispatch("service_drawer")
	check(l.state.inventory.count("token_pantry_half") == 1, "after a load: still one token")
	l.take("token_pantry_half")
	var l2 := roundtrip(l)
	l2.dispatch("service_drawer")
	check(not l2.has_item("token_pantry_half"), "a spent token never comes back from the drawer")

# ---------------------------------------------------------------------------------------------
# (3) every misplacement class
# ---------------------------------------------------------------------------------------------
func test_misplacements() -> void:
	var cases := [
		[["b_sr", "b_at", "b_sh", "", "b_cd", "b_ti", "b_op", "b_nb", "b_sq"], "M.L.'s place is empty."],
		[["b_sr", "b_at", "b_sh", "b_ml", "b_cd", "b_ti", "b_op", "b_nb", ""], "The square place is empty."],
		[["b_sr", "b_at", "b_ml", "b_sh", "b_cd", "b_ti", "b_op", "b_nb", "b_sq"], "S.H.'s bowl is at M.L.'s place."],
		[["b_sr", "b_sq", "b_sh", "b_ml", "b_cd", "b_ti", "b_op", "b_nb", "b_at"], "The unsigned bowl is at A.T.'s place."],
		[["b_sq", "b_at", "b_sh", "b_ml", "b_cd", "b_ti", "b_op", "b_nb", "b_sr"], "The unsigned bowl is at S.R.'s place."],
		[["b_sr", "b_at", "b_cd", "b_ml", "", "b_ti", "b_op", "b_nb", "b_sh"], "S.H.'s bowl is on the square-marked place."],
		[["b_sr", "b_at", "b_sh", "b_ml", "b_cd", "b_ti", "b_op", "b_sq", "b_nb"], "The unsigned bowl is at N.B.'s place."],
		[["", "", "", "", "", "", "", "", ""], "S.R.'s place is empty."],
		[["b_at", "", "", "", "", "", "", "", ""], "A.T.'s bowl is at S.R.'s place."],
	]
	for c in cases:
		var g := fresh()
		var r := r5(g)
		lay(g, c[0])
		set_tally(g, 9)
		check(r.state.places == c[0], "laid %s" % [c[0]])
		var ev := g.dispatch("compare")
		check(says(ev) == c[1], "misplacement: want '%s', got '%s'" % [c[1], says(ev)])
		check(not g.flag("P07") and r.last_compare.places == "disagree" and r.last_compare.portions == "agree",
			"misplacement %s: places disagree, portions agree" % c[1])
		check(has_ev(ev, "sfx", "compare_pull") and has_ev(ev, "sfx", "flag_flip") and has_ev(ev, "fx", "p07_compare"),
			"the compare lever's events")
		check(int(r.state.misses) == 1, "a miss is counted")
	# A held bowl counts as unplaced.
	var h := fresh()
	lay(h, SOL)
	set_tally(h, 9)
	h.dispatch("place_4")
	check(r5(h).held == "b_ml", "lifting a placed bowl holds it")
	check(says(h.dispatch("compare")) == "M.L.'s place is empty." and not h.flag("P07"), "a held bowl is unplaced")

# ---------------------------------------------------------------------------------------------
# (4) the tally
# ---------------------------------------------------------------------------------------------
func test_tally() -> void:
	for t in range(0, 13):
		var g := fresh()
		lay(g, SOL)
		set_tally(g, t)
		var ev := g.dispatch("compare")
		check(g.flag("P07") == (t == 9), "tally %d: P07 %s" % [t, t == 9])
		if t == 8:
			check(says(ev) == "Eight is the register's number. The tally wants what was served, and I haven't read what she served.",
				"tally 8, book unread (%s)" % says(ev))
		elif t != 9:
			check(says(ev) == "Portions disagree with what she served. Her book would know.", "tally %d, book unread" % t)
	var g8 := fresh()
	g8.dispatch("to_kitchen")
	read_ledger(g8)
	lay(g8, SOL)
	set_tally(g8, 8)
	check(says(g8.dispatch("compare")) == "That's the register's number. Nora's book says nine.", "tally 8, book read")
	set_tally(g8, 3)
	check(says(g8.dispatch("compare")) == "Nora served nine.", "tally 3, book read")
	var c := fresh()
	var r := r5(c)
	open_table(c)
	var ev := c.dispatch("tally_down")
	check(int(r.state.tally) == 0 and has_ev(ev, "sfx", "tally_click"), "the tally clamps at 0")
	for i in 15:
		c.dispatch("tally_up")
	check(int(r.state.tally) == 12, "the tally clamps at 12")
	check(says(c.dispatch("look_register")) == "REGISTER: 8. Rook's number.", "the register plate")

# ---------------------------------------------------------------------------------------------
# (5) PLACES and PORTIONS independently
# ---------------------------------------------------------------------------------------------
func test_independent_compare() -> void:
	var swapped := ["b_sr", "b_at", "b_ml", "b_sh", "b_cd", "b_ti", "b_op", "b_nb", "b_sq"]
	for places_ok in [true, false]:
		for portions_ok in [true, false]:
			var g := fresh()
			var r := r5(g)
			lay(g, SOL if places_ok else swapped)
			set_tally(g, 9 if portions_ok else 8)
			var ev := g.dispatch("compare")
			var want := {"places": "agree" if places_ok else "disagree", "portions": "agree" if portions_ok else "disagree"}
			check(r.last_compare == want, "compare %s/%s: %s" % [places_ok, portions_ok, r.last_compare])
			check(g.flag("P07") == (places_ok and portions_ok), "compare %s/%s: P07" % [places_ok, portions_ok])
			var n := 0
			for e in ev:
				if e.type == "say" and not e.story: n += 1
			if not places_ok and not portions_ok:
				check(n == 2 and ev.filter(func(e): return e.type == "say")[1].delay == 2.2, "both wrong: two lines, the second at 2.2")
			elif not (places_ok and portions_ok):
				check(n == 1, "one wrong: one line")

# ---------------------------------------------------------------------------------------------
# (6) bowl conservation
# ---------------------------------------------------------------------------------------------
func test_conservation() -> void:
	var g := fresh()
	var r := r5(g)
	open_table(g)
	var controls := []
	for k in 9:
		controls.append("slot_%d" % k)
		controls.append("place_%d" % (k + 1))
	var seed := 7
	var ok := true
	for i in 400:
		seed = (seed * 1103515245 + 12345) % 2147483648
		g.dispatch(controls[seed % controls.size()])
		ok = ok and conserved(r)
	check(ok, "every lift, set, swap and return keeps all nine bowls")
	# A swap: the held bowl goes down, the old one comes up.
	var s := fresh()
	var rs := r5(s)
	open_table(s)
	s.dispatch("slot_0")
	s.dispatch("place_3")
	s.dispatch("slot_1")
	var ev := s.dispatch("place_3")
	check(rs.state.places[2] == "b_sh" and rs.held == "b_ti" and has_ev(ev, "sfx", "bowl_set") and has_ev(ev, "sfx", "bowl_lift"),
		"a swap: S.H. down, T.I. in hand")
	check(conserved(rs), "the swap conserves")
	ev = s.dispatch("slot_5")
	check(rs.held == "" and has_ev(ev, "sfx", "bowl_rack") and rs.rack_contents()[0] == "b_ti", "a held bowl goes home to its own slot")
	check(says(s.dispatch("slot_1")) == "That one's at the table.", "a slot whose bowl is out")
	check(says(s.dispatch("slot_2")) == "The patched one. No name, only the square." and rs.held == "b_sq", "the patched bowl, first lift")
	s.dispatch("slot_2")
	check(says(s.dispatch("slot_2")) == "", "the patched-bowl line plays once")
	check(says(s.dispatch("place_1")) == "", "a bowl set down")
	check(says(s.dispatch("place_2")) == "A.T.'s place. Empty." and says(s.dispatch("place_9")) == "The square place. Empty, apart from the dent.",
		"empty places say so")
	s.dispatch("place_1")
	check(rs.held == "b_sq", "an occupied place lifts its bowl")
	s.dispatch("back")
	check(rs.held == "" and rs.local_view == "room" and conserved(rs), "Back puts the held bowl in the rack")
	open_table(s)
	s.dispatch("slot_0")
	s.dispatch("to_kitchen")
	check(rs.held == "" and rs.local_view == "kitchen" and conserved(rs), "turning to the kitchen returns the held bowl")

# ---------------------------------------------------------------------------------------------
# (7) locked after P07; COMPARE is idempotent
# ---------------------------------------------------------------------------------------------
func test_locked_after_p07() -> void:
	var g := fresh()
	var r := r5(g)
	solve_p07(g)
	var before := snap(g)
	for a in ["slot_0", "slot_4", "tally_up", "tally_down"]:
		check(says(g.dispatch(a)) == SET_LINE, "after P07 %s is set" % a)
	check(says(g.dispatch("place_3")) == "S.H.'s place. S.H.'s bowl.", "after P07 a place says whose")
	check(says(g.dispatch("place_9")) == "The square place. His bowl.", "after P07 the square place")
	check(snap(g) == before and r.held == "", "nothing moves after P07")
	var ev := g.dispatch("compare")
	check(says(ev) == "Nine. It still says nine." and has_ev(ev, "sfx", "compare_pull"), "a repeat COMPARE")
	check(count_fx(ev, "tide") == 0 and count_fx(ev, "p07_agree") == 0 and snap(g) == before, "COMPARE is idempotent")
	var b5 := game_at(5, ROOM)
	r5(b5).local_view = "c_table"
	var e5 := b5.dispatch("place_9")
	check(says(e5) == "A fresh tide line of soup round the inside of his bowl. Barley. Nobody has cooked." and r5(b5).has_seen("soup_line"),
		"band 3: soup in his bowl")

# ---------------------------------------------------------------------------------------------
# (8) saves mid-P07, malformed saves
# ---------------------------------------------------------------------------------------------
func test_p07_save_load() -> void:
	var g := fresh()
	lay(g, ["b_sr", "", "b_ml", "", "", "", "", "", "b_nb"])
	set_tally(g, 5)
	g.dispatch("slot_0")
	check(r5(g).held == "b_ti", "a bowl in hand before saving")
	var l := roundtrip(g)
	var r := r5(l)
	check(r.state.places == ["b_sr", "", "b_ml", "", "", "", "", "", "b_nb"] and int(r.state.tally) == 5, "places and tally survive")
	check(r.held == "" and r.local_view == "room" and conserved(r), "a load lands in the room, the held bowl racked")
	var base: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var bad := [
		["places", ["b_sr", "b_sr", "", "", "", "", "", "", ""], "places", ["", "", "", "", "", "", "", "", ""]],
		["places", ["b_xx", "", "", "", "", "", "", "", ""], "places", ["", "", "", "", "", "", "", "", ""]],
		["places", ["b_sr"], "places", ["", "", "", "", "", "", "", "", ""]],
		["tally", 99, "tally", 12],
		["tally", 3.5, "tally", 0],
		["tally", "9", "tally", 0],
		["board_count", -4, "board_count", 0],
		["seal", 7, "seal", 3],
	]
	for b in bad:
		var d: Dictionary = base.duplicate(true)
		d.rooms.R05[b[0]] = b[1]
		var t := GameSim.new()
		t.from_dict(d)
		var got = r5(t).state[b[2]]
		check(JSON.stringify(got) == JSON.stringify(b[3]), "malformed %s=%s -> %s (got %s)" % [b[0], b[1], b[3], got])
		if b[0] != "tally":
			check(int(r5(t).state.tally) == 5, "malformed %s leaves the tally alone" % b[0])
	var d2: Dictionary = base.duplicate(true)
	d2.rooms.R05.amend = {"count": "+7", "name": "ADA", "status": "present"}
	var t2 := GameSim.new()
	t2.from_dict(d2)
	check(r5(t2).state.amend == {"count": "", "name": "", "status": "present"}, "amendment fields validated one by one")
	var d3: Dictionary = base.duplicate(true)
	d3.rooms.R05.drawer_open = true
	d3.rooms.R05.socket_turned = true
	d3.rooms.R05.notices = ["arrival", "arrival", "bogus", "soup"]
	var t3 := GameSim.new()
	t3.from_dict(d3)
	check(not r5(t3).state.drawer_open and not r5(t3).state.socket_turned, "drawer needs P07; the socket needs both halves")
	check(r5(t3).state.notices == ["arrival", "soup"], "notices: known ids, deduped")

# ---------------------------------------------------------------------------------------------
# (9) P09 refusals
# ---------------------------------------------------------------------------------------------
func test_p09_refusals() -> void:
	var g := ready_p09()
	var r := r5(g)
	check(g.has_item("token_pantry_half") and g.has_item("token_bunk_half"), "both halves in hand")
	var ev := g.dispatch("shift_board")
	check(r.local_view == "c_service_board" and says(ev) == "Rook's eight. And a placard about corrections.", "first look at the board")
	check(r.has_seen("shift_board") and r.has_seen("amendment_rule"), "the board and its rule noted")
	check(says(g.dispatch("back")) == "" and r.local_view == "kitchen", "Back from the board to the kitchen")
	check(says(g.dispatch("shift_board")) == "The shift board.", "later looks")
	check(says(g.dispatch("socket_turn")) == "Nothing in it to turn.", "an empty socket")
	ev = fit(g, "token_pantry_half", "socket_bunk")
	check(r.state.fitted.pantry and not r.state.fitted.bunk and not g.has_item("token_pantry_half"), "the pantry half fits its own half")
	check(says(ev) == "The pantry half drops into the left of the socket." and has_ev(ev, "sfx", "token_seat"), "the pantry line")
	ev = g.dispatch("socket_turn")
	check(has_ev(ev, "sfx", "socket_jam") and says(ev) == "The socket will not turn. It wants both halves." and not r.state.socket_turned,
		"one half: the socket jams")
	ev = g.dispatch("stamp")
	check(says(ev) == "The stamp won't come down. The token socket's holding it." and has_ev(ev, "sfx", "stamp_locked"), "stamp before the turn")
	check(tokens_recoverable(g), "refused: tokens recoverable")
	ev = g.dispatch("socket_pantry")
	check(says(ev) == "Out it comes." and g.has_item("token_pantry_half") and not r.state.fitted.pantry, "a fitted half pulls out")
	check(says(g.dispatch("socket_bunk")) == "The bunk half of the socket. Empty.", "the empty bunk half")
	fit_both_turn(g)
	check(r.state.socket_turned, "both halves: the socket turns")
	check(says(g.dispatch("socket_pantry")) == "Locked in while the socket's turned.", "locked while turned")
	# Overwriting the 8 is always rejected and reverted.
	for d in [-1, 1, -8, 4]:
		for i in absi(d):
			g.dispatch("count_down" if d < 0 else "count_up")
		check(int(r.state.board_count) == 8 + d, "the count turns to %d" % (8 + d))
		ev = g.dispatch("stamp")
		check(REJECT in says(ev) and r.tape == REJECT and int(r.state.board_count) == 8, "overwrite %d: rejected, 8 back" % (8 + d))
		check(has_ev(ev, "sfx", "reject_tape") and has_ev(ev, "fx", "count_reset") and "The eight's put itself back." in says(ev),
			"overwrite %d: tape and reset" % (8 + d))
		check(tokens_recoverable(g), "overwrite: tokens kept")
	var stamp_line := func() -> String: return says(g.dispatch("stamp"))
	check(stamp_line.call() == "The amendment isn't finished. It wants a count, a name and a status.", "blank amendment")
	compose(g, "+1", "VENN", "", 3)
	check(stamp_line.call() == "The amendment isn't finished. It wants a count, a name and a status.", "blank status")
	compose(g, "", "VENN", "present", 3)
	check(stamp_line.call() == "The amendment isn't finished. It wants a count, a name and a status.", "blank count")
	compose(g, "+1", "", "present", 3)
	check(stamp_line.call() == "The amendment isn't finished. It wants a count, a name and a status.", "blank name")
	compose(g, "+2", "VENN", "present", 3)
	check(stamp_line.call() == "Nora served nine. Eight signed. That's one more, not two.", "+2")
	compose(g, "-1", "VENN", "present", 3)
	check(stamp_line.call() == "Taking one off is overwriting with extra steps.", "-1")
	for name in TILES:
		if name == "VENN":
			continue
		compose(g, "+1", name, "present", 3)
		var want := "I wasn't at that supper. " + NAME_LINE if name == "MERCER" else NAME_LINE
		check(stamp_line.call() == want, "name %s refused" % name)
		check(tokens_recoverable(g), "name %s: tokens kept" % name)
	compose(g, "+1", "VENN", "absent", 3)
	check(stamp_line.call() == "He ate. Nora counted his bowl. He was present.", "absent")
	compose(g, "+1", "VENN", "retained", 3)
	check(stamp_line.call() == "'Retained' is a word for a sample, not a man at supper.", "retained")
	for s in [1, 2]:
		compose(g, "+1", "VENN", "present", s)
		ev = g.dispatch("stamp")
		check(says(ev) == WRONG_SEAL and has_ev(ev, "sfx", "stamp_thud"), "seal %d refused" % s)
	check(int(r.state.stamp_misses) == 4 + 2 + 9 + 2 + 2, "stamp misses counted (%d)" % int(r.state.stamp_misses))
	check(tokens_recoverable(g) and not g.flag("P09"), "after every refusal: P09 unset, tokens recoverable")
	g.dispatch("socket_turn")
	g.dispatch("socket_pantry")
	g.dispatch("socket_bunk")
	check(g.has_item("token_pantry_half") and g.has_item("token_bunk_half"), "both halves come back out")
	# Tiles, fields, count, seal: the small lines.
	var f := ready_p09()
	f.dispatch("shift_board")
	ev = f.dispatch("tile_5")
	check(says(ev) == "MERCER. The brass on this one is newer than the rest." and r5(f).has_seen("name_tiles"), "the MERCER tile")
	check(says(f.dispatch("tile_5")) == "", "the MERCER line once")
	f.dispatch("f_name")
	check(r5(f).state.amend.name == "" and says(f.dispatch("f_name")) == "The name field. It takes a tile.", "the name field")
	check(says(f.dispatch("count_up")) == "It turns. Rook's eight could be anything.", "first count change")
	check(says(f.dispatch("look_count")) == "PRESENT: 9. That's not his number.", "the count read")
	f.dispatch("count_down")
	check(says(f.dispatch("count_up")) == "" and says(f.dispatch("count_down")) == "", "the count line once")
	check(says(f.dispatch("look_count")) == "PRESENT: 8. In his hand.", "his eight")
	check(says(f.dispatch("look_rule")) == R05Sim.RULE_TEXT, "the rule")
	f.dispatch("seal_2")
	check(int(r5(f).state.seal) == 2 and r5(f).has_seen("seal_selector"), "the seal selector")
	# Without P07 and P08 the count can't be corrected.
	var n := with_flags(["P06", "P07"], ROOM)
	var rn := r5(n)
	rn.state.fitted = {"pantry": true, "bunk": true}
	rn.state.socket_turned = true
	rn.state.amend = {"count": "+1", "name": "VENN", "status": "present"}
	rn.state.seal = 3
	rn.local_view = "c_service_board"
	check(says(n.dispatch("stamp")) == "I can't correct a count I haven't made." and not n.flag("P09"), "P09 needs P07 and P08")

# ---------------------------------------------------------------------------------------------
# (10) the correct stamp
# ---------------------------------------------------------------------------------------------
func test_p09_success() -> void:
	var g := ready_p09()
	var r := r5(g)
	check(not g.exit_open(ROOM, "R07") and not g.exit_open(ROOM, "R08"), "the hatch is shut before P09")
	fit_both_turn(g)
	compose(g, "+1", "VENN", "present", 3)
	var ev := g.dispatch("stamp")
	check(g.flag("P09") and r.state.p09_complete, "the amendment solves P09")
	check(count_fx(ev, "tide") == 1 and g.tide() == 4 and g.weather_band() == 2, "P09: Tide IV, band 2")
	check(has_ev(ev, "fx", "p09_reveal") and has_ev(ev, "sfx", "board_hinge") and has_ev(ev, "sfx", "fog_creep")
		and has_ev(ev, "sfx", "hatch_unlatch"), "P09: the reveal")
	check("'Eight retained. One witnessing.' I'm copying it down." in says(ev), "P09: the copy line")
	var ret := g.seen_in(ROOM).find("eight_retained")
	check(ret >= 0 and ret < g.seen_in(ROOM).find("hatch_open"), "eight_retained is noted before the fog")
	check(r.has_seen("amendment_rule") and r.has_seen("hatch_open"), "the rule and the hatch noted")
	check(not g.has_item("token_pantry_half") and not g.has_item("token_bunk_half"), "both halves spent")
	check(says(g.dispatch("socket_pantry")) == STAMPED and not g.has_item("token_pantry_half"), "a spent half can't be pulled")
	check(says(g.dispatch("socket_turn")) == STAMPED and r.state.socket_turned, "the socket stays turned")
	check(g.exit_open(ROOM, "R07") and g.exit_open(ROOM, "R08"), "the hatch opens the lab and the machine room")
	var before := snap(g)
	var nb: Array = g.state.notebook.duplicate()
	ev = g.dispatch("stamp")
	check(says(ev) == STAMPED and ev.size() == 1 and snap(g) == before and g.state.notebook == nb, "a repeat stamp changes nothing")
	check(says(g.dispatch("look_duplicate")) == "Fogged. I have the copy.", "the duplicate, fogged")
	check(r.fog_pose() == "full" and r.board_swung() and r.hatch_open(), "the board swung, fogged")
	g.dispatch("back")
	check(says(g.dispatch("shift_board")) == "Fogged from inside the wall. My copy's in the notebook.", "the board after P09")
	check(says(g.dispatch("back")) == "" and says(g.dispatch("service_hatch")) == "Open. The draught comes up out of it, steady as breath.",
		"the hatch after P09")

# ---------------------------------------------------------------------------------------------
# (11) P07/P08 order permutations
# ---------------------------------------------------------------------------------------------
func test_order_permutations() -> void:
	var a := game_at(3, ROOM)
	solve_p07(a)
	a.dispatch("service_drawer")
	a.set_flag("P08")
	a.give("token_bunk_half")
	var b := game_at(3, ROOM)
	b.set_flag("P08")
	b.give("token_bunk_half")
	solve_p07(b)
	b.dispatch("service_drawer")
	var same := func(tag: String) -> void:
		check(JSON.stringify(r5(a).state) == JSON.stringify(r5(b).state), "%s: rooms.R05 identical" % tag)
		check(JSON.stringify(a.state.flags) == JSON.stringify(b.state.flags), "%s: flags identical" % tag)
		check(sorted_inv(a) == sorted_inv(b), "%s: inventory identical" % tag)
	same.call("before P09")
	for g in [a, b]:
		fit_both_turn(g)
		compose(g, "+1", "VENN", "present", 3)
		g.dispatch("stamp")
	check(a.flag("P09") and b.flag("P09"), "both orders solve P09")
	same.call("after P09")

# ---------------------------------------------------------------------------------------------
# (12) saves mid-P09
# ---------------------------------------------------------------------------------------------
func test_p09_save_load() -> void:
	var g := ready_p09()
	fit_both_turn(g)
	compose(g, "+1", "VENN", "present", 3)
	var l := roundtrip(g)
	check(JSON.stringify(r5(l).state) == JSON.stringify(r5(g).state), "mid-P09 state round-trips")
	check(r5(l).local_view == "room" and r5(l).tape == "", "the load lands in the room")
	check(not l.has_item("token_pantry_half") and not l.has_item("token_bunk_half"), "fitted halves stay fitted")
	r5(l).local_view = "c_service_board"
	l.dispatch("stamp")
	check(l.flag("P09"), "a loaded board stamps")
	var d: Dictionary = JSON.parse_string(JSON.stringify(fresh().to_dict()))
	d.rooms.R05 = {"p09_complete": true}
	var t := GameSim.new()
	t.from_dict(d)
	var s: Dictionary = r5(t).state
	check(t.flag("P09") and t.flag("P07"), "a p09 save sets P07 and P09")
	check(s.places == SOL and int(s.tally) == 9 and s.drawer_open and s.fitted == {"pantry": true, "bunk": true}
		and s.socket_turned and s.amend == {"count": "+1", "name": "VENN", "status": "present"} and int(s.seal) == 3
		and int(s.board_count) == 8, "a p09 save derives the arrangement (%s)" % [s])

# ---------------------------------------------------------------------------------------------
# (13) reconcile
# ---------------------------------------------------------------------------------------------
func test_reconcile() -> void:
	var g := with_flags(["P06", "P07"], ROOM)
	var r := r5(g)
	r.reconcile()
	check(r.state.p07_complete and r.state.places == SOL and int(r.state.tally) == 9, "P07 set elsewhere syncs the table")
	check(not r.state.drawer_open and not g.has_item("token_pantry_half"), "sync never grants the token")
	g.dispatch("to_kitchen")
	g.dispatch("service_drawer")
	check(g.has_item("token_pantry_half"), "the drawer still opens for it")
	var h := with_flags(["P06", "P09"], ROOM)
	var rh := r5(h)
	rh.reconcile()
	check(rh.state.p09_complete and rh.state.p07_complete and h.flag("P07") and rh.state.drawer_open
		and rh.state.socket_turned and rh.state.amend.name == "VENN", "P09 set elsewhere syncs everything")
	check(not h.has_item("token_pantry_half") and not h.has_item("token_bunk_half"), "and grants nothing")
	var c := fresh()
	r5(c).state.p07_complete = true
	r5(c).reconcile()
	check(c.flag("P07"), "the flag follows the state")
	r5(c).state.p07_complete = false
	r5(c).reconcile()
	check(c.flag("P07") and r5(c).state.p07_complete, "a set flag is honoured, never cleared by a stale state")

# ---------------------------------------------------------------------------------------------
# (14) evidence ids
# ---------------------------------------------------------------------------------------------
func test_evidence_ids() -> void:
	var g := fresh()
	var r := r5(g)
	g.dispatch("to_kitchen")
	var ev := g.dispatch("ledger")
	check(g.has_seen(ROOM, "nora_ledger") and r.local_view == "c_ledger" and has_ev(ev, "sfx", "book_open"), "nora_ledger on the first open")
	check(says(ev) == "Nora's provisioning book. Open at the eighteenth of October, 1927.", "the book's first line")
	g.dispatch("back")
	ev = g.dispatch("work_card")
	check(g.has_seen(ROOM, "nora_work_card"), "nora_work_card on the first look")
	check(says(ev) == "A work card, stamped CALIBRATION 18 OCT 1927. A trace of her breathing: two short rises, a pause, one long rise.",
		"the work card line")
	var obj := r.objective()
	var flags_before: Dictionary = g.state.flags.duplicate()
	ev = g.dispatch("menu_note")
	check(g.flag("o02_found") and g.has_seen(ROOM, "menu_objections"), "the menu sets o02_found")
	check("'You have given him a biscuit with an opinion.'" in says(ev), "Nora's reply")
	flags_before["o02_found"] = true
	check(r.objective() == obj and g.state.flags == flags_before, "o02_found gates nothing")
	var p := ready_p09()
	fit_both_turn(p)
	compose(p, "+1", "VENN", "present", 3)
	p.dispatch("stamp")
	for id in ["headcount_nine", "amendment_rule", "eight_retained"]:
		check(p.has_seen(ROOM, id), "%s is noted under R05" % id)
	for id in R05Sim.OBSERVATIONS:
		check(R05Sim.OBSERVATIONS[id] != "", "observation %s has text" % id)
	var l := roundtrip(g)
	check(l.flag("o02_found"), "o02_found survives a load")

# ---------------------------------------------------------------------------------------------
# (15) escalation
# ---------------------------------------------------------------------------------------------
func test_escalation() -> void:
	var t3 := game_at(3, ROOM)
	check(r5(t3).current_notice_a() == "" and r5(t3).current_notice_b() == "", "tide III: no notice due")
	t3.dispatch("go:R06")
	var e3 := t3.dispatch("go:R05")
	for n in R05Sim.NOTICE_LINES:
		check(not R05Sim.NOTICE_LINES[n] in says(e3), "tide III: no %s" % n)
	for t in range(4, 10):
		var g := game_at(t, ROOM)
		var r := r5(g)
		check(r.band() == t - 2, "tide %d is band %d" % [t, t - 2])
		check(r.current_notice_a() == NOTICE_A[t] and r.current_notice_b() == NOTICE_B[t],
			"tide %d notices %s/%s (got %s/%s)" % [t, NOTICE_A[t], NOTICE_B[t], r.current_notice_a(), r.current_notice_b()])
		g.dispatch("go:R06")
		var ev := g.dispatch("go:R05")
		var a: String = NOTICE_A[t]
		check(R05Sim.NOTICE_LINES[a] in says(ev) and has_ev(ev, "fx", "notice_" + a), "tide %d: %s plays on arrival" % [t, a])
		check(r.has_seen(R05Sim.NOTICE_OBS[a]), "tide %d: %s noted" % [t, a])
		for i in R05Sim.NOTICES_A.find(a):
			check(R05Sim.NOTICES_A[i] in r.state.notices, "tide %d: older %s retired" % [t, R05Sim.NOTICES_A[i]])
		g.dispatch("go:R06")
		ev = g.dispatch("go:R05")
		check(not R05Sim.NOTICE_LINES[a] in says(ev), "tide %d: %s plays once" % [t, a])
		var b: String = NOTICE_B[t]
		ev = g.dispatch("to_kitchen")
		if b != "":
			check(R05Sim.NOTICE_LINES[b] in says(ev) and has_ev(ev, "fx", "notice_" + b) and r.has_seen(R05Sim.NOTICE_OBS[b]),
				"tide %d: %s plays in the kitchen" % [t, b])
			g.dispatch("to_mess")
			check(not R05Sim.NOTICE_LINES[b] in says(g.dispatch("to_kitchen")), "tide %d: %s once" % [t, b])
		else:
			check(says(ev) == "The kitchen.", "tide %d: the kitchen, no hold" % t)
	# An obsolete notice never plays later.
	var j := game_at(5, ROOM)
	for f in ["P13", "P14", "P15"]:
		j.set_flag(f)
	check(r5(j).band() == 4, "band 4 by flags")
	j.dispatch("go:R06")
	var je := j.dispatch("go:R05")
	check(R05Sim.NOTICE_LINES.chair in says(je) and "soup" in r5(j).state.notices, "chair plays; soup is retired unplayed")
	check(not r5(j).has_seen("soup_line"), "the retired notice wrote nothing")
	# Band 5: the spoon lifts once per visit, leaving a close-up.
	var s := game_at(7, ROOM)
	var rs := r5(s)
	s.dispatch("bowl_stack")
	var ev := s.dispatch("back")
	check(has_ev(ev, "fx", "spoon_lift") and has_ev(ev, "sfx", "spoon_china") and says(ev) == "Behind me, china. The spoon.",
		"band 5: the spoon lifts leaving c_table")
	check(rs.has_seen("spoon_waits"), "spoon_waits noted")
	s.dispatch("bowl_stack")
	check(not has_ev(s.dispatch("back"), "fx", "spoon_lift"), "once per visit")
	s.dispatch("go:R06")
	s.dispatch("go:R05")
	s.dispatch("to_kitchen")
	check(not has_ev(s.dispatch("back"), "fx", "spoon_lift"), "kitchen to mess is not a close-up")
	s.dispatch("to_kitchen")
	s.dispatch("ledger")
	ev = s.dispatch("back")
	check(has_ev(ev, "fx", "spoon_lift") and rs.local_view == "kitchen", "again after re-arrival, leaving c_ledger")
	var s4 := game_at(6, ROOM)
	s4.dispatch("bowl_stack")
	check(not has_ev(s4.dispatch("back"), "fx", "spoon_lift"), "band 4: the spoon stays down")
	var se := game_at(9, ROOM)
	se.state.ending = "sever"
	se.dispatch("bowl_stack")
	check(not has_ev(se.dispatch("back"), "fx", "spoon_lift"), "endings: the spoon stays down")
	# Presentation helpers by band.
	var want := {4: ["b2", true, false, false, "thirds", "full"], 5: ["b2", true, true, false, "thirds", "full"],
		6: ["b4", true, true, true, "thirds", "full"], 7: ["b4", false, true, true, "thirds", "full"],
		8: ["b6", false, true, true, "halves", "wiped"], 9: ["b7", false, true, true, "halves", "wiped"]}
	for t in want:
		var r := r5(game_at(t, ROOM))
		var got := [r.plate_stage(), r.rain_audible(), r.soup_shown(), r.chair_out(), r.towel_pose(), r.fog_pose()]
		check(JSON.stringify(got) == JSON.stringify(want[t]), "tide %d helpers %s (got %s)" % [t, want[t], got])
	var r9 := r5(game_at(9, ROOM))
	check(r9.range_lit() and r9.kettle_ticking() and r9.card_breathing() and r9.condensation_shown(), "band 7: range, kettle, card")
	check(r9.notebook_intrusion() == "Portions served: 10. Signed: 1.", "band 7: the notebook intrusion")
	var r3 := r5(game_at(3, ROOM))
	check(r3.plate_stage() == "b0" and r3.kettle_ticking() and not r3.range_lit() and r3.fog_pose() == "none"
		and r3.notebook_intrusion() == "" and not r3.drawer_open() and not r3.spoon_in_dent(), "tide III helpers")

# ---------------------------------------------------------------------------------------------
# (16) every hotspot at tides III..IX and in the endings
# ---------------------------------------------------------------------------------------------
func test_hotspots_and_endings() -> void:
	for t in range(3, 10):
		var g := game_at(t, ROOM)
		var r := r5(g)
		for h in R05Sim.HOTSPOTS:
			r.local_view = "room"
			check(says(g.dispatch(h)) != "", "tide %d mess hotspot %s answers" % [t, h])
		for h in R05Sim.KITCHEN_HOTSPOTS:
			r.local_view = "kitchen"
			check(says(g.dispatch(h)) != "", "tide %d kitchen hotspot %s answers" % [t, h])
	var f := fresh()
	for h in R05Sim.HOTSPOTS:
		r5(f).local_view = "room"
		check(says(f.dispatch(h)) != "", "first visit mess hotspot %s answers" % h)
	for h in R05Sim.KITCHEN_HOTSPOTS:
		r5(f).local_view = "kitchen"
		check(says(f.dispatch(h)) != "", "first visit kitchen hotspot %s answers" % h)
	for e in ["sever", "continue"]:
		var g := game_at(9, ROOM)
		var r := r5(g)
		g.state.ending = e
		check(r.current_notice_a() == "" and r.current_notice_b() == "", "%s: no notices" % e)
		var lines: Dictionary = R05Sim.SEVER_LINES if e == "sever" else R05Sim.CONTINUE_LINES
		for h in lines:
			r.local_view = "room" if h in R05Sim.HOTSPOTS else "kitchen"
			check(says(g.dispatch(h)) == lines[h], "%s: the %s line" % [e, h])
		for h in R05Sim.HOTSPOTS:
			r.local_view = "room"
			check(says(g.dispatch(h)) != "", "%s: mess hotspot %s answers" % [e, h])
		for h in R05Sim.KITCHEN_HOTSPOTS:
			r.local_view = "kitchen"
			check(says(g.dispatch(h)) != "", "%s: kitchen hotspot %s answers" % [e, h])
		g.dispatch("go:R06")
		var ev := g.dispatch("go:R05")
		var want := "Quiet. Just a kitchen." if e == "sever" else "The ring where her cup stood is warm."
		var obs := "spoon_settled" if e == "sever" else "ring_warm"
		check(says(ev) == want and r.has_seen(obs), "%s: the arrival" % e)
		g.dispatch("go:R06")
		check(says(g.dispatch("go:R05")) == "", "%s: the arrival once" % e)
		check(r.notebook_intrusion() == "", "%s: no intrusion" % e)
	var sv := r5(game_at(9, ROOM))
	sv.game.state.ending = "sever"
	check(sv.plate_stage() == "sever" and sv.fog_pose() == "dry" and sv.towel_pose() == "thirds" and not sv.chair_out()
		and sv.rain_audible() and not sv.range_lit() and not sv.kettle_ticking() and sv.spoon_in_dent(), "sever helpers")
	var cv := r5(game_at(9, ROOM))
	cv.game.state.ending = "continue"
	check(cv.plate_stage() == "b7" and cv.ring_pose() == "warm" and cv.spoon_raised_still() and cv.range_lit()
		and not cv.card_breathing() and not cv.condensation_shown(), "continue helpers")

# ---------------------------------------------------------------------------------------------
# (17) objectives and hints
# ---------------------------------------------------------------------------------------------
func test_objectives_hints() -> void:
	for k in REF_HINTS:
		check(R05Sim.HINTS.has(k) and R05Sim.HINTS[k] == REF_HINTS[k], "hint ladder %s verbatim" % k)
		check(R05Sim.OBJECTIVES.has(k), "objective %s has text" % k)
	var g := game_at(3, ROOM)
	var r := r5(g)
	var order := []
	order.append(r.objective())
	check(says(g.dispatch("hint")) == REF_HINTS.p07[0], "hint: the nudge")
	g.dispatch("hint")
	check(says(g.dispatch("hint")) == REF_HINTS.p07[2], "hint: the solution")
	solve_p07(g)
	order.append(r.objective())
	g.dispatch("service_drawer")
	order.append(r.objective())
	g.set_flag("P08")
	g.give("token_bunk_half")
	order.append(r.objective())
	fit_both_turn(g)
	compose(g, "+1", "VENN", "present", 3)
	g.dispatch("stamp")
	order.append(r.objective())
	check(order == ["p07", "p07_drawer", "wait_p08", "p09", "done"], "objective order %s" % [order])
	for k in REF_HINTS:
		for lvl in 3:
			check(REF_HINTS[k][lvl] in R05Sim.HINTS[k], "hint %s %d" % [k, lvl])
	check(r.objective_text() == "The board is amended. The hatch is open.", "done text")

# ---------------------------------------------------------------------------------------------
# (18) debug_prepare(4) is where play leaves the room
# ---------------------------------------------------------------------------------------------
func test_debug_prepare_matches_play() -> void:
	var a: Dictionary = r5(game_at(4, ROOM)).state.duplicate(true)
	var p := ready_p09()
	p.dispatch("bowl_stack")
	p.dispatch("unsigned_bowl")
	p.dispatch("tally")
	fit_both_turn(p)
	compose(p, "+1", "VENN", "present", 3)
	p.dispatch("stamp")
	var b: Dictionary = r5(p).state.duplicate(true)
	a.erase("notices")
	b.erase("notices")
	check(JSON.stringify(a) == JSON.stringify(b), "debug_prepare(4) matches play:\n%s\n%s" % [a, b])
	var t4 := game_at(4, ROOM)
	check(not t4.has_item("token_pantry_half") and not t4.has_item("token_bunk_half"), "tide IV: no halves in hand")
	for o in ["headcount_nine", "eight_retained", "hatch_open", "nora_ledger", "drawer_note"]:
		check(t4.has_seen(ROOM, o), "tide IV: %s noted" % o)
	for t in range(1, 10):
		var x := game_at(t, ROOM)
		var y := GameSim.new()
		y.from_dict(JSON.parse_string(JSON.stringify(x.to_dict())))
		check(JSON.stringify(r5(y).state) == JSON.stringify(r5(x).state), "tide %d: R05 state survives a load" % t)

# ---------------------------------------------------------------------------------------------
# (19) debug jumps
# ---------------------------------------------------------------------------------------------
func test_debug_jumps() -> void:
	var g := GameSim.new()
	var r := r5(g)
	for n in range(0, 12):
		r.debug_jump(n)
		check(g.state.room == ROOM and r.can_enter(), "jump %d: in the kitchen" % n)
		check(g.flag("P07") == r.state.p07_complete and g.flag("P09") == r.state.p09_complete, "jump %d: flags agree" % n)
		check(r.held == "" and r.tape == "" and r.last_compare == {"places": "", "portions": ""} and r.ledger_spread == 0,
			"jump %d: clean transients" % n)
		var v := R05Sim.new()
		v.load_state(JSON.parse_string(JSON.stringify(r.state)))
		check(JSON.stringify(v.state) == JSON.stringify(r.state), "jump %d: a valid state" % n)
		for h in ["pantry", "bunk"]:
			check(not (r.state.fitted[h] and g.has_item("token_%s_half" % h)), "jump %d: %s half in one place" % [n, h])
		match n:
			0:
				check(not g.flag("P07") and g.tide() == 3 and r.local_view == "room", "jump 0: fresh tide III")
			1:
				check(g.flag("P07") and not r.state.drawer_open and r.objective() == "p07_drawer", "jump 1: P07, drawer shut")
			2:
				check(r.state.drawer_open and g.flag("P08") and g.has_item("token_pantry_half") and g.has_item("token_bunk_half")
					and r.objective() == "p09", "jump 2: both halves in hand")
			3:
				check(r.local_view == "c_service_board" and r.state.socket_turned, "jump 3: ready to stamp")
				g.dispatch("stamp")
				check(g.flag("P09") and g.tide() == 4, "jump 3: the stamp lands")
			10, 11:
				check(r.ending() == ("sever" if n == 10 else "continue"), "jump %d: the ending" % n)
			_:
				check(r.band() == n - 2 and g.flag("P09"), "jump %d: band %d" % [n, n - 2])

# ---------------------------------------------------------------------------------------------
# (20) items
# ---------------------------------------------------------------------------------------------
func use(g: GameSim, item: String, target: String, view := "room") -> String:
	r5(g).local_view = view
	if not g.has_item(item):
		g.give(item)
	g.dispatch("item:" + item)
	return says(g.dispatch(target))

func test_use_item() -> void:
	var g := fresh()
	var lens := "Four rivets. And N.B. scratched small in one corner of the patch."
	check(use(g, "inspection_lens", "unsigned_bowl") == lens and r5(g).has_seen("lens_patch"), "the lens on the patch")
	check(use(g, "inspection_lens", "place_9") == lens, "the lens on the square place")
	check(use(g, "inspection_lens", "slot_3", "c_table") == lens, "the lens in c_table")
	check(use(g, "inspection_lens", "work_card", "kitchen") == "It isn't ink. It's a pressure line, pressed into the card.", "lens on the card")
	check(use(g, "inspection_lens", "ledger", "kitchen") == "Her hand. One soft pencil all through.", "lens on the book")
	check(use(game_at(5, ROOM), "inspection_lens", "ledger", "kitchen") == "Her hand. One soft pencil all through. The 1931 page too.",
		"lens on the book, band 3")
	check(use(g, "inspection_lens", "shift_board", "kitchen") == GameSim.GENERIC_WRONG_USE, "lens on the board before P09")
	check(use(game_at(4, ROOM), "inspection_lens", "shift_board", "kitchen") == "The fog's on the inside. There's no glass to be inside of.",
		"lens on the fogged board")
	check(use(g, "pencil", "shift_board", "kitchen") == "The amendment takes tiles, not pencil.", "pencil on the board")
	check(use(g, "pencil", "stamp", "c_service_board") == "The amendment takes tiles, not pencil.", "pencil in the board close-up")
	check(use(g, "pencil", "ledger", "kitchen") == "Not in her book.", "pencil on the book")
	check(use(g, "nora_register_card", "ledger", "kitchen") == "'No surviving personal effects.' Her book says otherwise: 'Cup, mine, mended 3 Feb.'",
		"register card on the book")
	check(use(g, "pencil", "towel") == GameSim.GENERIC_WRONG_USE and g.has_item("pencil"), "an unrelated use is generic")
	var t := fresh()
	check(use(t, "token_pantry_half", "towel") == "It's half a service token. The shift board has a socket for it."
		and t.has_item("token_pantry_half") and not r5(t).state.fitted.pantry, "a token on the wrong target is kept")
	check(use(t, "token_bunk_half", "seal_2", "c_service_board") == "The bunk half drops into the right."
		and r5(t).state.fitted.bunk and not t.has_item("token_bunk_half"), "a token on any board control fits its own half")

# ---------------------------------------------------------------------------------------------
# Nora's book
# ---------------------------------------------------------------------------------------------
func test_ledger() -> void:
	var g := fresh()
	var r := r5(g)
	g.dispatch("to_kitchen")
	g.dispatch("ledger")
	check(r.ledger_spread == 0, "the book opens at 18 Oct")
	check(says(g.dispatch("page_prev")) == "" and r.ledger_spread == 0, "page_prev clamps")
	var ev := g.dispatch("page_next")
	check(r.ledger_spread == 1 and has_ev(ev, "sfx", "page_turn") and says(ev) == "'It belongs to Rook.' Somebody had to laugh at him.",
		"spread 1 the first time")
	check(r.has_seen("rook_ration") and r.has_seen("ledger_stores"), "the ration and stores pages noted")
	ev = g.dispatch("page_next")
	check(r.ledger_spread == 2 and says(ev) == "Blank. Ruled for days nobody's written yet.", "spread 2 blank before band 3")
	g.dispatch("page_next")
	check(r.ledger_spread == 2, "page_next clamps")
	g.dispatch("page_prev")
	check(says(g.dispatch("page_next")) == "Blank. Ruled for days nobody's written yet.", "blank again")
	g.dispatch("page_prev")
	g.dispatch("page_prev")
	check("Portions served: 9" in says(g.dispatch("left_page")), "the left page reads aloud")
	check("Cup, mine, mended 3 Feb." in says(g.dispatch("right_page")), "the right page reads aloud")
	check(r.ledger_page(2).left.is_empty(), "no 1931 page before band 3")
	var b3 := game_at(5, ROOM)
	var r3 := r5(b3)
	b3.dispatch("to_kitchen")
	ev = b3.dispatch("ledger")
	check(r3.ledger_spread == 2 and r3.has_seen("ledger_1931")
		and says(ev) == "A new page. That's tonight. 'Signed: A.M.' I haven't signed anything. I haven't eaten.", "band 3: tonight's page")
	check(r3.ledger_page(2).left == R05Sim.LEDGER_1931, "band 3: the 1931 supper")
	b3.dispatch("back")
	b3.dispatch("ledger")
	check(r3.ledger_spread == 0, "band 3: later opens at 18 Oct")
	var b6 := game_at(8, ROOM)
	var r6 := r5(b6)
	b6.dispatch("to_kitchen")
	b6.dispatch("ledger")
	b6.dispatch("back")
	ev = b6.dispatch("ledger")
	check(r6.ledger_spread == 2 and r6.has_seen("ledger_1931_b6") and says(ev) == "Breakfast. Tomorrow. Ten. Eight, him, and me.",
		"band 6: tomorrow's breakfast")
	check(r6.ledger_page(2).left.size() == 7, "band 6: both 1931 entries")
	b6.dispatch("back")
	b6.dispatch("ledger")
	check(r6.ledger_spread == 0, "band 6: then 18 Oct again")

# ---------------------------------------------------------------------------------------------
# (21) close-up control rects, (22) kitchen hotspot rects (once the view declares them)
# ---------------------------------------------------------------------------------------------
## Every [id, Rect2, ...] row in the view's constants (or {id: Rect2}), except the base views.
func _view_rects(m: Dictionary) -> Dictionary:
	var out := {}
	for k in m:
		if k in ["HOTSPOTS", "KITCHEN_HOTSPOTS", "EXIT_RECTS"]:
			continue
		var v = m[k]
		if v is Array:
			for row in v:
				if row is Array and row.size() >= 2 and row[0] is String and row[1] is Rect2:
					out[row[0]] = row[1]
		elif v is Dictionary:
			for id in v:
				if id is String and v[id] is Rect2:
					out[id] = v[id]
	return out

func _rect_ok(tag: String, rr: Rect2) -> void:
	check(CANVAS.encloses(rr), "%s is on the canvas" % tag)
	check(rr.size.x >= MIN_TARGET and rr.size.y >= MIN_TARGET, "%s is at least 64x64" % tag)
	check(not rr.intersects(HUD_ZONE) and not rr.intersects(INVENTORY_ZONE) and not rr.intersects(SUBTITLE_ZONE),
		"%s keeps clear of the HUD, inventory and subtitles" % tag)

func test_control_rects() -> void:
	var m: Dictionary = load("res://game/rooms/R05/R05_view.gd").get_script_constant_map()
	var rects := _view_rects(m)
	var controls: Array = R05Sim.TABLE_CONTROLS + R05Sim.LEDGER_CONTROLS + R05Sim.BOARD_CONTROLS + R05Sim.BOARD_CONTROLS_AFTER
	var any := false
	for id in controls:
		any = any or rects.has(id)
	if not any:
		print("SKIP: R05 close-up rects: the R05 view does not yet declare close-up controls (view team)")
		return
	for id in controls:
		check(rects.has(id), "the view has a close-up rect for %s" % id)
		if rects.has(id):
			_rect_ok("control " + id, rects[id])

func test_kitchen_rects() -> void:
	var m: Dictionary = load("res://game/rooms/R05/R05_view.gd").get_script_constant_map()
	if not m.has("KITCHEN_HOTSPOTS"):
		print("SKIP: R05 kitchen rects: the R05 view does not yet declare KITCHEN_HOTSPOTS (view team)")
		return
	var ids := []
	var exits: Dictionary = m.get("EXIT_RECTS", {})
	for h in m.KITCHEN_HOTSPOTS:
		ids.append(h[0])
		var rr: Rect2 = h[1]
		_rect_ok("kitchen " + h[0], rr)
		for k in exits:
			check(not exits[k].intersects(rr), "kitchen %s clear of exit %s" % [h[0], k])
	for id in R05Sim.KITCHEN_HOTSPOTS:
		check(id in ids, "the view has a kitchen rect for %s" % id)
