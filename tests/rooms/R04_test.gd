extends "res://tests/rooms/room_test_base.gd"
## R04, the Listening Room: P02 (tomorrow's recording), P17 (two people in one sentence),
## P19 (speak to the empty channel), the escalation matrix, saves and the two views.
##   godot --headless --path . --script tests/rooms/R04_test.gd

const ROOM := "R04"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := ["P01"]
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 2

## The six orders of the canonical three bands (the start-notch refusal sweep uses these).
const ORDERS := [["C", "A", "B"], ["C", "B", "A"], ["A", "B", "C"], ["A", "C", "B"],
	["B", "A", "C"], ["B", "C", "A"]]
## Every way to put three of the four bands on the spindle: 24 orders.
const ALL_BANDS := ["B", "D", "A", "C"]
const INIT_ROT := {"C": 1, "A": 0, "B": 2, "D": 0}
## Reference seam, written out band by band (independent of R04Sim.SEAM): the phase where
## each band meets its left / right neighbour at rotation 0, I .. 2, III. C and D carry START
## notches; D is scratched 14 OCT, the wrong day.
const REF_LEFT := {"C": [0, 1, 2], "A": [2, 0, 1], "B": [1, 2, 0], "D": [1, 2, 0]}
const REF_RIGHT := {"C": [1, 2, 0], "A": [0, 1, 2], "B": [], "D": [0, 1, 2]}
const WRONG_DAY := "VENN: Greywake, fourteenth October... | That's the wrong day."
const REF_LINES := {
	"start_end": "The start notch is at the wrong end.",
	"start_arrow": "It jumps right at the start. The notch isn't on the arrow.",
	"join1": "It jumps at the first join. The seam doesn't carry on.",
	"join2": "It jumps at the second join. The seam doesn't carry on.",
	"wrong_day": WRONG_DAY,
}
const PRESERVE := "'Preserve the recording before winding again.' I'll leave it as it is."
const BOARD_MAX_Y := 914.0
## A quarter of the transcript's 7 s breath: the lift at its peak.
const PAPER_QUARTER := 1.75

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	test_p02_exhaustive()
	test_p02_refusals()
	test_p02_success()
	test_p02_p03_orders()
	test_p02_save_load()
	test_malformed_saves()
	test_p17()
	test_p19_switches()
	test_p19_questions()
	test_p19_save_load()
	test_escalation()
	test_views_and_back()
	test_hotspots_tide_ix()
	test_endings()
	test_items_objectives_hints()
	test_debug_jumps()
	test_w1_lines()
	test_w1_decoy()
	test_w1_funnel5()
	await test_board_rects()
	if _view_ready():
		await view_checks(ROOM)
	else:
		print("SKIP: R04 view_checks: the R04 view does not yet declare rects for every sim hotspot (view team)")
	await test_view_scene()
	await test_w1_view()

# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
func r04(g: GameSim) -> R04Sim:
	return g.room(ROOM) as R04Sim

func fresh() -> GameSim:
	return with_flags(["P01"], ROOM)

func flags_upto(n: int) -> Array:
	var out := []
	for i in range(1, n + 1):
		out.append("P%02d" % i)
	return out

func snapshot(g: GameSim) -> String:
	return JSON.stringify([g.state.flags, g.state.inventory, g.state.notebook, g.state.movement_events])

func count_fx(ev: Array, id: String) -> int:
	var n := 0
	for e in ev:
		if e.type == "fx" and e.id == id:
			n += 1
	return n

## Builds an arrangement on the spindle by real clicks.
func build(g: GameSim, order: Array, rots: Dictionary) -> void:
	var r := r04(g)
	if r.local_view != "c_spindle":
		g.dispatch("spindle")
	for b in order:
		g.dispatch("tray_" + b)
	for b in order:
		var k: int = r.state.spindle.find(b)
		for i in posmod(int(rots[b]) - int(r.state.band_rot[b]), 3):
			g.dispatch("rot_up_%d" % k)

func ref_failure(order: Array, rots: Dictionary) -> String:
	var first: String = order[0]
	if not first in ["C", "D"]:
		return "start_end"
	if REF_LEFT[first][rots[first]] != 0:
		return "start_arrow"
	for j in 2:
		var a: String = order[j]
		var b: String = order[j + 1]
		if a == "B" or b in ["C", "D"] or REF_RIGHT[a][rots[a]] != REF_LEFT[b][rots[b]]:
			return "join%d" % (j + 1)
	return "wrong_day" if first == "D" else ""

func all_orders() -> Array:
	var out := []
	for a in ALL_BANDS:
		for b in ALL_BANDS:
			for c in ALL_BANDS:
				if a != b and b != c and a != c:
					out.append([a, b, c])
	return out

func solve_p02(g: GameSim) -> Array:
	build(g, ["C", "A", "B"], {"C": 0, "A": 2, "B": 1})
	return g.dispatch("play")

## A game at tide VI with the session spool threaded and the contact sheet in hand, at the mixer.
func mixer_game() -> GameSim:
	var g := game_at(6, ROOM)
	g.set_flag("P16")
	g.give("contact_sheet")
	g.dispatch("to_board")
	g.dispatch("mixer")
	return g

func set_offset(g: GameSim, o: int) -> void:
	var r := r04(g)
	while int(r.state.offset) > o:
		g.dispatch("off_left")
	while int(r.state.offset) < o:
		g.dispatch("off_right")

func set_solo(g: GameSim, venn: bool, nora: bool) -> void:
	var r := r04(g)
	if r.state.venn_on != venn:
		g.dispatch("toggle_venn")
	if r.state.nora_on != nora:
		g.dispatch("toggle_nora")

func channels_game(flags: Array) -> GameSim:
	var g := with_flags(flags, ROOM)
	g.dispatch("to_board")
	g.dispatch("witness_key")
	return g

## Motor off, A and B closed, C open, WITNESS, by real clicks from the starting switches.
func open_witness(g: GameSim) -> Array:
	var r := r04(g)
	if r.local_view != "c_channels":
		g.dispatch("to_board")
		g.dispatch("witness_key")
	if r.state.motor_on: g.dispatch("motor")
	if r.state.ch_open.A: g.dispatch("key_a")
	if r.state.ch_open.B: g.dispatch("key_b")
	if not r.state.ch_open.C: g.dispatch("key_c")
	return g.dispatch("witness")

func _view_ready() -> bool:
	var m: Dictionary = load("res://game/rooms/R04/R04_view.gd").get_script_constant_map()
	var ids := []
	for h in m.get("HOTSPOTS", []):
		ids.append(h[0])
	for id in R04Sim.HOTSPOTS:
		if not id in ids:
			return false
	return true

# ---------------------------------------------------------------------------------------------
# (a) P02: all 648 arrangements (three of four bands, 24 orders x 27 rotations)
# ---------------------------------------------------------------------------------------------
func test_p02_exhaustive() -> void:
	var solved := []
	var wrong_day := []
	var orders := all_orders()
	check(orders.size() == 24, "P02: 24 orders of three bands from four")
	for order in orders:
		for code in 27:
			var rots := {order[0]: code % 3, order[1]: (code / 3) % 3, order[2]: code / 9}
			var g := fresh()
			var r := r04(g)
			build(g, order, rots)
			var label := "%s %s" % ["".join(order), rots]
			check(r.state.spindle == order, "P02 %s: built by clicks" % label)
			var before := snapshot(g)
			var ev := g.dispatch("play")
			var want := ref_failure(order, rots)
			if g.flag("P02"):
				solved.append(label)
				check(want == "", "P02 %s: solves only when the reference agrees" % label)
				continue
			check(want != "", "P02 %s: the reference solves it, the room does not" % label)
			check(says(ev) == REF_LINES.get(want, "?"), "P02 %s: says the first break (%s), got '%s'" % [label, want, says(ev)])
			check(r.seam_break == want and has_ev(ev, "fx", "seam_break"), "P02 %s: highlights %s" % [label, want])
			check(snapshot(g) == before, "P02 %s: a failed play gains nothing" % label)
			check(r.state.spindle == order, "P02 %s: nothing is consumed" % label)
			var tl := r.transcript_lines()
			if want == "wrong_day":
				wrong_day.append(label)
				check(tl == ["VENN: Greywake, fourteenth October..."], "P02 %s: the transcript prints the 14th" % label)
				for e in ev:
					if e.type == "say": check(e.story, "P02 %s: the wrong day plays as a held line" % label)
			else:
				check(tl.size() == 1 and "— seam —" in tl[0], "P02 %s: the transcript breaks at the seam" % label)
				if want == "join2" and order[0] == "D":
					check("fourteenth" in tl[0], "P02 %s: D's broken seam already gives its day" % label)
	check(solved.size() == 1 and solved[0].begins_with("CAB"), "P02: exactly one of 648 solves (%s)" % [solved])
	check(wrong_day.size() == 1 and wrong_day[0].begins_with("DAB"), "P02: only D-A-B carries the seam, on the wrong day (%s)" % [wrong_day])

# ---------------------------------------------------------------------------------------------
# (b) refusals
# ---------------------------------------------------------------------------------------------
func test_p02_refusals() -> void:
	var g := fresh()
	var r := r04(g)
	g.dispatch("spindle")
	check(r.local_view == "c_spindle", "the spindle opens c_spindle")
	check(says(g.dispatch("play")) == "The spindle takes three bands.", "empty spindle refuses")
	g.dispatch("tray_C")
	g.dispatch("tray_A")
	check(says(g.dispatch("play")) == "The spindle takes three bands.", "partial spindle refuses")
	check(not g.flag("P02") and r.seam_break == "", "a refusal changes nothing")
	check(says(g.dispatch("tray_C")) != "" and r.state.spindle == ["C", "A", ""], "a placed band can't go on twice")
	g.dispatch("tray_B")
	check(says(g.dispatch("tray_A")) == "The spindle's full.", "a full spindle refuses")
	var ev := g.dispatch("slot_1")
	check(r.state.spindle == ["C", "", "B"] and has_ev(ev, "sfx", "band_lift"), "a slot lifts its band")
	check(says(ev) == "I take band A back off.", "lifting a band is never silent: the line names it")
	check(not r.state.spindle.has("A"), "the lifted band goes back to the tray")
	check(says(g.dispatch("tray_A")) == "" and r.state.spindle == ["C", "A", "B"], "the lifted band can be seated again")
	ev = g.dispatch("slot_1")
	check(says(ev) == "I take band A back off." and r.state.spindle == ["C", "", "B"], "and lifted again, aloud")
	ev = g.dispatch("rot_up_1")
	check(ev.is_empty() and r.state.band_rot == INIT_ROT, "an empty slot doesn't turn")
	ev = g.dispatch("rot_down_0")
	check(r.state.band_rot.C == 0 and has_ev(ev, "sfx", "band_click"), "rot_down turns -1 mod 3")
	g.dispatch("rot_down_0")
	check(r.state.band_rot.C == 2, "rotation wraps")
	check(says(g.dispatch("look_arrow")) == "START, and an arrow. The left end.", "the arrow")
	# Motor off (P19 leaves it off): the spindle can't play.
	var m := fresh()
	r = r04(m)
	build(m, ["C", "A", "B"], {"C": 0, "A": 2, "B": 1})
	r.state.motor_on = false
	ev = m.dispatch("play")
	check(says(ev) == "The motor's off. The board's through there." and ev.size() == 1 and not m.flag("P02"),
		"motor off: one line, nothing else")
	# START at the wrong end for every order whose first slot isn't C, at any rotation.
	for order in ORDERS:
		if order[0] == "C":
			continue
		for code in [0, 13, 26]:
			var w := fresh()
			build(w, order, {order[0]: code % 3, order[1]: (code / 3) % 3, order[2]: code / 9})
			check(says(w.dispatch("play")) == REF_LINES.start_end, "%s: start notch at the wrong end" % "".join(order))

# ---------------------------------------------------------------------------------------------
# (c) success
# ---------------------------------------------------------------------------------------------
func test_p02_success() -> void:
	var g := fresh()
	var r := r04(g)
	var ev := solve_p02(g)
	check(g.flag("P02") and r.state.p02_complete, "C-A-B at I, III, II solves P02")
	check(r.has_seen("recording_tomorrow") and r.has_seen("calibration_zero"), "P02 logs the recording and zero")
	var moves: Array = g.value("movement_events")
	check(not moves.is_empty() and moves[-1] == "recording_played", "P02 records recording_played")
	check(has_ev(ev, "sfx", "recording_p02") and has_ev(ev, "sfx", "cylinder_coast") and has_ev(ev, "fx", "cylinder_coast"),
		"the recording plays and the cylinder coasts")
	check("VENN: Eighteenth October. Mercer will be standing at the chart table." in says(ev), "the dated line plays")
	check("The eighteenth. That's tomorrow." in says(ev), "Ada notices the date")
	check(r.transcript_lines().size() == 4, "the transcript prints four lines")
	var story := true
	for e in ev:
		if e.type == "say": story = story and e.story
	check(story, "every recording line is a story line")
	var notebook: Array = g.state.notebook.duplicate()
	var before := snapshot(g)
	ev = g.dispatch("play")
	check(snapshot(g) == before and g.state.notebook == notebook, "a repeat play adds nothing")
	check(not has_ev(ev, "fx", "tide") and has_ev(ev, "sfx", "recording_p02") and has_ev(ev, "sfx", "cylinder_coast"),
		"a repeat play replays without a tide card")
	check("VENN: Greywake" in says(ev) and not "That's tomorrow" in says(ev), "the replay is the recording alone")
	for a in ["tray_C", "slot_0", "rot_up_1", "rot_down_2"]:
		check(says(g.dispatch(a)) == PRESERVE, "after P02 %s says the preserve line" % a)
	check(r.state.spindle == ["C", "A", "B"] and r.state.band_rot == {"C": 0, "A": 2, "B": 1, "D": 0}, "the bands stay put")

# ---------------------------------------------------------------------------------------------
# (d) P02 and P03 in either order
# ---------------------------------------------------------------------------------------------
func test_p02_p03_orders() -> void:
	var a := fresh()
	var ev_a := solve_p02(a)
	a.set_flag("P03")
	var b := fresh()
	b.set_flag("P03")
	var ev_b := solve_p02(b)
	check(a.tide_done(1) and b.tide_done(1), "both orders finish Tide I")
	check(snapshot(a) == snapshot(b), "both orders leave identical outputs")
	check(a.tide() == b.tide() and a.weather_band() == b.weather_band(), "both orders: same tide and band")
	check(not a.flag("closure_report_filed") and not a.flag("t1x_threshold_crossed") and a.flag("P01"),
		"the office's flags are untouched")
	check("I haven't been near the chart table yet." in says(ev_a) and "I've already stood at the chart table." in says(ev_b),
		"only the last line differs")
	test_p02_chart_table_line()

## "I haven't been near the chart table yet." is said only when it is true: R03 unvisited, or
## visited without the table's first look ("sheets"). Otherwise the chain ends on the last
## RECORDING_AFTER line with no trailing gap.
func test_p02_chart_table_line() -> void:
	const NOT_YET := "I haven't been near the chart table yet."
	var last_after: float = R04Sim.RECORDING_AFTER[-1][1]
	# R03 visited, table looked at, P03 unsolved: the line is omitted.
	var g := fresh()
	g.state.visited.append("R03")
	g.observe("R03", "sheets")
	var ev := solve_p02(g)
	check(not NOT_YET in says(ev) and not "I've already stood at the chart table." in says(ev), "seen the table: no chart-table line")
	var last_say := -1.0
	for e in ev:
		if e.type == "say": last_say = maxf(last_say, float(e.get("delay", 0.0)))
	check(is_equal_approx(last_say, last_after), "seen the table: the chain ends on the last recording-after line")
	check(R04Sim.RECORDING_AFTER[-1][0] in says(ev), "seen the table: the recording-after chain is intact")
	# R03 visited but the table never looked at: the line stays.
	var h := fresh()
	h.state.visited.append("R03")
	check(NOT_YET in says(solve_p02(h)), "visited R03 without the table: the line is said")
	# The observation alone, R03 not visited: the line stays.
	var k := fresh()
	k.observe("R03", "sheets")
	check(NOT_YET in says(solve_p02(k)), "R03 unvisited: the line is said")

# ---------------------------------------------------------------------------------------------
# (e) save/load mid-P02 and malformed saves
# ---------------------------------------------------------------------------------------------
func test_p02_save_load() -> void:
	var g := fresh()
	var r := r04(g)
	build(g, ["C", "B", "A"], {"C": 0, "A": 1, "B": 2})
	g.dispatch("play")
	check(r.seam_break == "join1", "C-B-A breaks at the first join")
	g.dispatch("slot_2")
	g.dispatch("tray_A")
	g.dispatch("play")
	check(r.seam_break != "", "a broken play leaves a highlight")
	var d := g.to_dict()
	check(not d.rooms.R04.has("seam_break") and not d.rooms.R04.has("mix_result") and not d.rooms.R04.has("board_tape"),
		"transient highlights are not saved")
	var g2 := GameSim.new()
	check(g2.from_dict(JSON.parse_string(JSON.stringify(d))), "the save loads through JSON")
	var r2 := r04(g2)
	check(r2.state.spindle == r.state.spindle and r2.state.band_rot == r.state.band_rot, "spindle and rotations survive")
	check(r2.seam_break == "" and r2.local_view == "room", "a load lands in the room with no highlight")
	# A partial spindle survives too, then can be finished.
	g2.dispatch("spindle")
	g2.dispatch("slot_1")
	g2.dispatch("slot_2")
	var d2 := g2.to_dict()
	var g3 := GameSim.new()
	g3.from_dict(JSON.parse_string(JSON.stringify(d2)))
	var r3 := r04(g3)
	check(r3.state.spindle == ["C", "", ""], "a partial spindle survives a load")
	build(g3, ["A", "B"], {"C": 0, "A": 2, "B": 1})
	g3.dispatch("play")
	check(g3.flag("P02"), "the loaded partial spindle can be finished")
	# A load after P02 keeps it.
	var g4 := GameSim.new()
	g4.from_dict(JSON.parse_string(JSON.stringify(g3.to_dict())))
	check(g4.flag("P02") and r04(g4).state.p02_complete, "P02 survives a load")

func test_malformed_saves() -> void:
	var g := fresh()
	var r := r04(g)
	r.load_state({"spindle": ["C", "C", ""], "band_rot": {"C": 7, "A": -4, "B": 1.5}, "offset": 9.5,
		"asked": ["q_where"], "notices": ["throat", "bogus"], "motor_on": "yes", "p17_complete": 1})
	check(r.state.spindle == ["", "", ""], "duplicate bands reset the spindle")
	check(r.state.band_rot == {"C": 2, "A": 0, "B": 2, "D": 0}, "rotations clamp; fractions are refused")
	check(r.state.offset == 0, "a fractional offset is refused")
	check(r.state.motor_on == true and r.state.p17_complete == false, "non-bools are refused")
	check(r.state.asked.is_empty(), "questions need an open witness line")
	check(r.state.notices == ["throat"], "unknown notices are dropped")
	r.load_state({"spindle": ["Q", "", ""]})
	check(r.state.spindle == ["", "", ""], "unknown bands reset the spindle")
	r.load_state({"spindle": ["C", "A"], "offset": 12})
	check(r.state.spindle == ["", "", ""] and r.state.offset == 3, "a short spindle resets; offset clamps")
	r.load_state({"motor_on": false, "ch_open": {"A": false, "B": false, "C": true}, "witness_open": true,
		"p17_complete": true, "asked": ["q_where", "q_bogus", "q_where", 4]})
	check(r.state.witness_open and r.state.asked == ["q_where"], "asked keeps known questions once")
	check(r.state.offset == -2 and r.state.heard_venn and r.state.heard_nora and r.state.p02_complete,
		"P17 forces its arrangement and P02's")
	r.load_state({"motor_on": true, "ch_open": {"A": false, "B": false, "C": true}, "witness_open": true,
		"p17_complete": true})
	check(not r.state.witness_open, "an open witness line needs the motor off")
	r.load_state({"p19_complete": true, "witness_open": true, "asked": []})
	check(r.state.p19_complete and r.state.asked == R04Sim.QUESTIONS and not r.state.witness_open and r.state.p17_complete,
		"P19 forces every question asked and the line closed")
	r.load_state("garbage")
	check(r.state == r.initial_state(), "a non-dict loads fresh")
	r.load_state({"p02_complete": true, "spindle": ["A", "B", "C"]})
	var solved_rot := {"D": 0}
	solved_rot.merge(R04Sim.SOLUTION_ROT)
	check(r.state.spindle == ["C", "A", "B"] and r.state.band_rot == solved_rot, "P02 forces the solution")
	r.load_state({"spindle": ["D", "A", "B"], "band_rot": {"D": 2, "A": 0, "B": 2}})
	check(r.state.spindle == ["D", "A", "B"] and r.state.band_rot.D == 2, "the decoy band loads like the others")

# ---------------------------------------------------------------------------------------------
# (f) P17
# ---------------------------------------------------------------------------------------------
func test_p17() -> void:
	var g := fresh()
	var r := r04(g)
	g.dispatch("to_board")
	var ev := g.dispatch("mixer")
	check(r.local_view == "board" and says(ev) == "A two-track mixer. Both spools are empty.", "the mixer is shut before P16")
	g.give("contact_sheet")
	g.dispatch("item:contact_sheet")
	g.dispatch("mixer")
	check(r.local_view == "board", "the contact sheet doesn't open it before P16")
	# Opening with P16.
	var m := mixer_game()
	r = r04(m)
	check(r.local_view == "c_mixer" and r.has_seen("session_spool") and r.has_seen("bell_peaks"), "P16 threads the spool")
	# All seven offsets, both channels on: only -2 lands together.
	for o in range(-3, 4):
		var t := mixer_game()
		var tr := r04(t)
		set_offset(t, o)
		ev = t.dispatch("play")
		if o == -2:
			check(tr.mix_result == "combined" and "VENN / NORA: Leave the witness line... I was here." in says(ev),
				"offset -2: one sentence, two voices")
		else:
			check(tr.mix_result == "overlap" and says(ev) == "The bells don't land together." and tr.mix_transcript().size() == 2,
				"offset %d: the bells don't land together" % o)
		for solo in [[true, false], [false, true]]:
			set_solo(t, solo[0], solo[1])
			t.dispatch("play")
			check((tr.mix_result in ["venn", "nora"]) == (o == -2), "offset %d solo: separates only at -2" % o)
		check(t.flag("P17") == (o == -2), "offset %d: P17 only at -2" % o)
	set_offset(m, -3)
	check(says(m.dispatch("off_left")) == "" and r.state.offset == -3, "the slider clamps at -3")
	# Both solo orders commit.
	for first_venn in [true, false]:
		var t := mixer_game()
		var tr := r04(t)
		set_offset(t, -2)
		set_solo(t, first_venn, not first_venn)
		t.dispatch("play")
		check(not t.flag("P17"), "one solo isn't enough")
		set_solo(t, not first_venn, first_venn)
		var cev := t.dispatch("play")
		check(t.flag("P17") and tr.state.p17_complete, "both solos commit (venn first: %s)" % first_venn)
		check(tr.has_seen("witness_procedure") and "Channel C is my station now. E.V." in says(cev), "the margin note")
		check("c_presence" in tr.state.notices and has_ev(cev, "fx", "c_presence"), "channel C gets its presence")
		var nb := snapshot(t)
		var rev := t.dispatch("play")
		check(snapshot(t) == nb and says(rev) == ("NORA: Tell them I was here." if first_venn else "VENN: Leave the witness line open."),
			"a repeat solo replays its line only")
		set_solo(t, true, true)
		t.dispatch("play")
		check(snapshot(t) == nb, "a repeat combined play adds nothing")
		# The breath, once, on stepping back to the board.
		var bev := t.dispatch("back")
		check(tr.local_view == "board" and has_ev(bev, "sfx", "breath_c") and "...Channel C just drew breath." in says(bev),
			"channel C draws breath on the way back")
		t.dispatch("mixer")
		bev = t.dispatch("back")
		check(not has_ev(bev, "sfx", "breath_c"), "the breath comes once")
		t.dispatch("mixer")
		check(says(t.dispatch("off_right")) != "" and tr.state.offset == -2, "the aligned slider stays put")
	# Combined only never commits.
	var c := mixer_game()
	set_offset(c, -2)
	for i in 3:
		c.dispatch("play")
	check(not c.flag("P17") and r04(c).state.heard_combined, "the combined sentence never commits")
	# Refusals.
	var n := mixer_game()
	set_solo(n, false, false)
	ev = n.dispatch("play")
	check(says(ev) == "Both channels are off." and r04(n).mix_result == "silent", "neither channel on")
	var s := mixer_game()
	s.take("contact_sheet")
	set_offset(s, -2)
	check(says(s.dispatch("play")) == "I'd want the contact sheet in front of me for this.", "no contact sheet")
	check(says(s.dispatch("look_sheet")) == "Nothing pinned here.", "nothing pinned without the sheet")
	var mo := mixer_game()
	check(says(mo.dispatch("look_sheet")) == "Sync: bell.", "the sheet's note")
	r04(mo).state.motor_on = false
	check(says(mo.dispatch("play")) == "The motor's off. The board's switch.", "motor off")
	# Heard flags survive a misaligned play.
	var h := mixer_game()
	var hr := r04(h)
	set_offset(h, -2)
	set_solo(h, true, false)
	h.dispatch("play")
	set_offset(h, 1)
	set_solo(h, false, true)
	h.dispatch("play")
	check(hr.state.heard_venn and not hr.state.heard_nora and hr.mix_result == "overlap", "heard Venn survives a misaligned play")
	set_offset(h, -2)
	h.dispatch("play")
	check(h.flag("P17"), "then Nora alone commits")
	# The contact sheet on the mixer from the funnel wall.
	var u := game_at(6, ROOM)
	u.set_flag("P16")
	u.give("contact_sheet")
	u.dispatch("item:contact_sheet")
	ev = u.dispatch("mixer")
	check(r04(u).local_view == "c_mixer" and says(ev) == "Sync: bell. There's a bell on both tracks." and u.has_item("contact_sheet"),
		"the contact sheet on the mixer opens it and stays in hand")

# ---------------------------------------------------------------------------------------------
# (g) P19
# ---------------------------------------------------------------------------------------------
func test_p19_switches() -> void:
	var ready := flags_upto(18)
	for code in 16:
		var motor := code & 1 != 0
		var a := code & 2 != 0
		var b := code & 4 != 0
		var cc := code & 8 != 0
		var g := channels_game(ready)
		var r := r04(g)
		if r.state.motor_on != motor: g.dispatch("motor")
		if r.state.ch_open.A != a: g.dispatch("key_a")
		if r.state.ch_open.B != b: g.dispatch("key_b")
		if r.state.ch_open.C != cc: g.dispatch("key_c")
		check(r.board_tape == "", "switching clears the tape")
		var ev := g.dispatch("witness")
		var want := ""
		if motor: want = "LIVE PLAYBACK NOT ISOLATED."
		elif a: want = "CHANNEL A LIVE."
		elif b: want = "CHANNEL B LIVE."
		var label := "motor %s A %s B %s C %s" % [motor, a, b, cc]
		if want != "":
			check(says(ev) == want and r.board_tape == want and has_ev(ev, "sfx", "reject_buzz"), "%s: %s" % [label, want])
			g.dispatch("key_c")
			check(r.board_tape == "", "%s: a switch clears the tape" % label)
		elif not cc:
			check(says(ev) == "The key clicks. Nothing answers." and not r.state.witness_open, "%s: nothing answers" % label)
		else:
			check(r.state.witness_open and "VENN (channel C): Ask, then. I'll answer what I can." in says(ev)
				and has_ev(ev, "fx", "c_open"), "%s: channel C opens" % label)
		check(r.state.witness_open == (not motor and not a and not b and cc), "%s: opens only isolated" % label)
		check(not g.flag("P19"), "%s: WITNESS alone doesn't solve P19" % label)
	var no18 := channels_game(flags_upto(17))
	check(says(open_witness(no18)) == "The key clicks. Nothing answers." and not r04(no18).state.witness_open,
		"without P18 nothing answers")
	var g := channels_game(ready)
	var r := r04(g)
	open_witness(g)
	for t in ["motor", "key_a", "key_b", "key_c"]:
		var before: String = JSON.stringify([r.state.motor_on, r.state.ch_open])
		check(says(g.dispatch(t)) == "Not while he's on the line." and JSON.stringify([r.state.motor_on, r.state.ch_open]) == before,
			"%s is refused mid-exchange" % t)
	check(says(g.dispatch("witness")) == "He's listening.", "WITNESS again while open")
	var q := channels_game(ready)
	check(says(q.dispatch("q_where")) == "Nobody's on the line." and r04(q).state.asked.is_empty(), "no questions before the line opens")
	check(says(q.dispatch("procedure")) == "'Isolate live playback before addressing a witness: motor off, live channels closed.'",
		"the procedure")

const Q_ORDERS := [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]

func test_p19_questions() -> void:
	for order in Q_ORDERS:
		var g := channels_game(flags_upto(18))
		var r := r04(g)
		open_witness(g)
		var ev := []
		for k in 3:
			var q: String = R04Sim.QUESTIONS[order[k]]
			check(not g.flag("P19") and not r.has_seen("venn_answers"), "%s: not solved before question %d" % [order, k + 1])
			ev = g.dispatch(q)
			check(has_ev(ev, "sfx", "venn_answer_" + q.substr(2)), "%s: %s answers" % [order, q])
			if k == 1:
				g.dispatch(q)
				check(r.state.asked.size() == 2 and not g.flag("P19"), "%s: re-asking doesn't count twice" % [order])
		check(g.flag("P19") and r.state.p19_complete and not r.state.witness_open, "%s: P19 after the third question" % [order])
		check(g.state.notebook.count("R04.venn_answers") == 1 and r.has_seen("funnel_voice") and r.has_seen("speaker_wet"),
			"%s: answers and the funnel voice logged once" % [order])
		check("You'll want to be angry with me." in says(ev) and has_ev(ev, "fx", "c_dark") and has_ev(ev, "sfx", "venn_funnel"),
			"%s: the funnel speaks after channel C goes dark" % [order])
		check(not r.indicator_lit("C") and r.needle_mode("C") == "rest", "%s: channel C is dark" % [order])
		var before := snapshot(g)
		for q in R04Sim.QUESTIONS:
			var rev := g.dispatch(q)
			check(has_ev(rev, "sfx", "venn_answer_" + q.substr(2)) and "VENN:" in says(rev) and not has_ev(rev, "fx", "c_dark"),
				"%s: %s replays" % [order, q])
		check(snapshot(g) == before, "%s: replays add nothing" % [order])
		check(says(g.dispatch("witness")) == "The key clicks. Channel C is dark.", "%s: WITNESS after P19" % [order])
	# The letter variant.
	var l := channels_game(flags_upto(18) + ["P20"])
	open_witness(l)
	var lev := []
	for q in R04Sim.QUESTIONS:
		lev = l.dispatch(q)
	check("You've read the letter. Good. Stay angry; it keeps the record open." in says(lev) and r04(l).has_seen("funnel_voice_letter")
		and not r04(l).has_seen("funnel_voice"), "with P20 the funnel mentions the letter")

func test_p19_save_load() -> void:
	var g := game_at(7, ROOM)
	check(g.flag("P17") and g.flag("P18") and not g.flag("P19"), "tide VII: P19 is ready")
	var ev := open_witness(g)
	check(r04(g).state.witness_open, "the line opens at tide VII")
	g.dispatch("q_whole")
	var g2 := GameSim.new()
	check(g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict()))), "mid-exchange save loads")
	var r2 := r04(g2)
	check(r2.state.witness_open and r2.state.asked == ["q_whole"] and r2.local_view == "room", "witness line and asked survive")
	check(r2.objective() == "p19_ask", "the objective is still the questions")
	g2.dispatch("to_board")
	g2.dispatch("witness_key")
	var nb: Array = g2.state.notebook.duplicate()
	ev = g2.dispatch("q_whole")
	check("VENN: They answer. That's all I can tell you." in says(ev) and g2.state.notebook == nb and r2.state.asked == ["q_whole"],
		"a loaded question replays without duplicates")
	g2.dispatch("q_need")
	g2.dispatch("q_where")
	check(g2.flag("P19"), "the loaded exchange finishes")
	var g3 := GameSim.new()
	g3.from_dict(JSON.parse_string(JSON.stringify(g2.to_dict())))
	var before := snapshot(g3)
	g3.dispatch("to_board")
	g3.dispatch("witness_key")
	for q in R04Sim.QUESTIONS:
		ev = g3.dispatch(q)
		check("VENN:" in says(ev), "after a load %s replays" % q)
	check(snapshot(g3) == before and g3.flag("P19"), "replays after a load add nothing")

# ---------------------------------------------------------------------------------------------
# (h) escalation
# ---------------------------------------------------------------------------------------------
## t -> [band, notice, turned, rings, bulge, A lit, B lit, C needle]
const MATRIX := {
	1: [0, "", false, false, false, true, true, "rest"],
	2: [0, "", false, false, false, true, true, "rest"],
	3: [1, "leak_wind", false, false, false, true, true, "rest"],
	4: [2, "leak_wind", false, false, false, true, true, "rest"],
	5: [3, "leak_silence", false, true, false, true, true, "rest"],
	6: [4, "funnels_turned", true, true, false, true, true, "rest"],
	7: [5, "c_presence", true, true, false, true, true, "tremble"],
	8: [6, "funnels_turned", true, true, false, false, false, "rest"],
	9: [7, "plaster_bulge", true, true, true, false, false, "rest"],
}

func test_escalation() -> void:
	for t in range(1, 10):
		var g := game_at(t, ROOM)
		var r := r04(g)
		var row: Array = MATRIX[t]
		var got := [r.band(), r.current_notice(), r.funnels_turned_shown(), r.stool_rings_shown(), r.bulge_shown(),
			r.indicator_lit("A"), r.indicator_lit("B"), r.needle_mode("C")]
		check(JSON.stringify(got) == JSON.stringify(row), "tide %d escalation %s (got %s)" % [t, row, got])
		check(not r.indicator_lit("C"), "tide %d: channel C is dark" % t)
		var n: String = row[1]
		var ev := []
		r.arrive(ev, false)
		if n != "":
			check(has_ev(ev, "fx", "notice_" + n) and says(ev) == R04Sim.NOTICE_LINES[n], "tide %d: notice %s plays" % [t, n])
			for e in ev:
				if e.type == "say": check(not e.story and is_equal_approx(e.delay, 1.6), "tide %d: the notice is a held aside" % t)
		else:
			check(says(ev) == "", "tide %d: no notice" % t)
		check(has_ev(ev, "sfx", "motor_click") == (row[0] <= 2), "tide %d: motor click only while the weather is mild" % t)
		ev = []
		r.arrive(ev, false)
		check(says(ev) == "" and not has_ev(ev, "fx", "notice_" + n), "tide %d: the notice plays once" % t)
	# First arrival: the throat, then nothing new on the next entry.
	var ev := []
	var fresh_g := GameSim.new()
	fresh_g.reset()
	fresh_g.set_flag("P01")
	var fe := []
	r04(fresh_g).arrive(fe, true)
	check(says(fe) == R04Sim.ARRIVAL and has_ev(fe, "sfx", "throat_clear") and has_ev(fe, "sfx", "motor_click")
		and r04(fresh_g).has_seen("throat") and r04(fresh_g).state.notices == ["throat"], "first arrival logs the throat")
	# Skipping bands: a notice that's gone stale never plays.
	var s := game_at(3, ROOM)
	var sr := r04(s)
	for p in flags_upto(18):
		s.set_flag(p)
	sr.reconcile()
	check(sr.current_notice() == "c_presence", "skip to P17: channel C's presence is due")
	ev = []
	sr.arrive(ev, false)
	check(count_fx(ev, "notice_c_presence") == 1 and not has_ev(ev, "fx", "notice_leak_wind"), "only the latest notice plays")
	for p in flags_upto(21):
		s.set_flag(p)
	sr.reconcile()
	check(sr.current_notice() == "funnels_turned", "after P19 the funnels are the notice")
	ev = []
	sr.arrive(ev, false)
	check(not has_ev(ev, "fx", "notice_funnels_turned") and says(ev) == "", "an obsolete notice is never replayed")
	# Room lines follow the band.
	var lines := {0: "Six brass ear trumpets", 1: "Wind is coming out of number five", 2: "Rain in number two",
		3: "Nothing from any of them now", 4: "They've turned", 7: "Every pipe has the plaster"}
	for t in [2, 3, 4, 5, 6, 9]:
		var g := game_at(t, ROOM)
		var b := g.weather_band()
		check(lines[b] in says(g.dispatch("funnels")), "band %d: the funnels line" % b)
	var g9 := game_at(9, ROOM)
	var pev := g9.dispatch("printer")
	check("MERCER, it says." in says(pev) and "MERCER: (breathing)" in says(pev) and r04(g9).has_seen("printer_mercer"),
		"band 7: the printer types her questions and her breathing")
	check("bulges round the pipes" in says(g9.dispatch("plaster")) and r04(g9).has_seen("plaster_bulge"), "band 7 plaster")
	check(says(g9.dispatch("stool")) == "Every funnel points at the seat. I don't sit down.", "band 7 stool")
	var g5 := game_at(5, ROOM)
	g5.dispatch("stool")
	check(r04(g5).has_seen("stool_rings"), "band 3 stool rings")

# ---------------------------------------------------------------------------------------------
# (i) views, back, board rects
# ---------------------------------------------------------------------------------------------
func test_views_and_back() -> void:
	var g := fresh()
	var r := r04(g)
	check(not r.is_closeup("board") and not r.is_closeup("room") and r.is_closeup("c_spindle") and r.is_closeup("c_mixer")
		and r.is_closeup("c_channels"), "board is a base view; the c_* are close-ups")
	var ev := g.dispatch("to_board")
	check(r.local_view == "board" and says(ev) == "The channel board.", "to the board")
	ev = g.dispatch("to_funnels")
	check(r.local_view == "room" and says(ev) == "The funnels.", "back to the funnels")
	ev = g.dispatch("to_board")
	check(r.local_view == "board" and says(ev) == "The board.", "the board, again")
	g.dispatch("back")
	check(r.local_view == "room", "Back from the board goes to the funnel wall")
	g.dispatch("channel_b")
	check(r.local_view == "c_channels" and r.has_seen("board") and r.has_seen("socket_cuts") and r.has_seen("procedure"),
		"a board hotspot from the funnel wall goes straight to the board close-up")
	g.dispatch("back")
	check(r.local_view == "board", "Back from c_channels goes to the board")
	g.dispatch("spindle")
	g.dispatch("back")
	check(r.local_view == "room", "Back from c_spindle goes to the room")
	g.dispatch("speaker")
	check(r.local_view == "board" and r.has_seen("speaker"), "the speaker, no close-up")
	check(says(g.dispatch("printer")) == "A transcript printer. The roll is blank to the end." and r.local_view == "room",
		"the blank roll before P02")

func test_board_rects() -> void:
	var m: Dictionary = load("res://game/rooms/R04/R04_view.gd").get_script_constant_map()
	if not m.has("BOARD_HOTSPOTS"):
		print("SKIP: R04 board rects: the R04 view does not yet declare BOARD_HOTSPOTS (view team)")
		return
	var ids := []
	for h in m.BOARD_HOTSPOTS:
		ids.append(h[0])
		var rr: Rect2 = h[1]
		check(CANVAS.encloses(rr), "board %s is on the canvas" % h[0])
		check(rr.size.x >= MIN_TARGET and rr.size.y >= MIN_TARGET, "board %s is at least 64x64" % h[0])
		check(not rr.intersects(HUD_ZONE) and not rr.intersects(INVENTORY_ZONE) and not rr.intersects(SUBTITLE_ZONE),
			"board %s keeps clear of the HUD, inventory and subtitles" % h[0])
		check(rr.end.y <= BOARD_MAX_Y, "board %s stays above the exit tabs" % h[0])
	for id in R04Sim.BOARD_HOTSPOTS:
		check(id in ids, "the view has a board rect for %s" % id)

# ---------------------------------------------------------------------------------------------
# (j) every hotspot at tide IX, (k) endings
# ---------------------------------------------------------------------------------------------
func test_hotspots_tide_ix() -> void:
	var g := game_at(9, ROOM)
	var r := r04(g)
	for h in R04Sim.HOTSPOTS:
		r.local_view = "room"
		check(says(g.dispatch(h)) != "", "tide IX room hotspot %s answers" % h)
	for h in R04Sim.BOARD_HOTSPOTS:
		r.local_view = "board"
		check(says(g.dispatch(h)) != "", "tide IX board hotspot %s answers" % h)
	# And the same from a fresh first visit.
	var f := fresh()
	for h in R04Sim.HOTSPOTS:
		r04(f).local_view = "room"
		check(says(f.dispatch(h)) != "", "Tide I room hotspot %s answers" % h)
	for h in R04Sim.BOARD_HOTSPOTS:
		r04(f).local_view = "board"
		check(says(f.dispatch(h)) != "", "Tide I board hotspot %s answers" % h)

func test_endings() -> void:
	for e in ["sever", "continue"]:
		var g := game_at(9, ROOM)
		var r := r04(g)
		r.state.motor_on = true
		r.state.ch_open = {"A": true, "B": true, "C": true}
		g.finish(e)
		check(r.ending() == e, "%s: the ending is read" % e)
		for ch in ["A", "B", "C"]:
			check(not r.indicator_lit(ch) and r.needle_mode(ch) == "rest", "%s: indicator %s off" % [e, ch])
		check(r.current_notice() == "", "%s: no notice" % e)
		check(r.bulge_shown() == (e == "continue"), "%s: the bulge" % e)
		check(r.funnels_turned_shown() == (e == "continue"), "%s: the funnels turned" % e)
		check(r.stool_rings_shown(), "%s: the wax dust stays" % e)
		var w := game_at(9, ROOM)   # walking the room after the end card
		w.state.ending = e
		for h in ["funnels", "plaster", "stool"]:
			var said := says(w.dispatch(h))
			check((said == R04Sim.SEVER_LINES[h]) == (e == "sever"), "%s: the %s line (%s)" % [e, h, said])
	var s := game_at(9, ROOM)
	s.state.ending = "continue"
	check(not r04(s).indicator_lit("A") and r04(s).current_notice() == "", "ending set in state: indicators off")

# ---------------------------------------------------------------------------------------------
# items, objectives, hints, debug
# ---------------------------------------------------------------------------------------------
func test_items_objectives_hints() -> void:
	var g := fresh()
	var r := r04(g)
	g.give("inspection_lens")
	g.give("chart_clips")
	g.give("contact_sheet")
	var uses := [["inspection_lens", "funnels", "Through the lens the pipes meet the plaster"],
		["inspection_lens", "spindle", "one cut, made in one pass"],
		["chart_clips", "band_tray", "Clips are for paper. These are wax."],
		["contact_sheet", "stool", "Nothing to sync here. The mixer, maybe."]]
	for u in uses:
		r.local_view = "room"
		g.dispatch("item:" + u[0])
		check(u[2] in says(g.dispatch(u[1])) and g.has_item(u[0]), "%s on %s" % [u[0], u[1]])
	check(r.has_seen("lens_pipes"), "the lens logs the pipes")
	r.local_view = "room"
	g.dispatch("item:inspection_lens")
	check(says(g.dispatch("stool")) == GameSim.GENERIC_WRONG_USE, "the lens on the stool before band 3 is generic")
	var g5 := game_at(5, ROOM)
	g5.give("inspection_lens")
	g5.dispatch("item:inspection_lens")
	check(says(g5.dispatch("stool")) == "The rings are wax dust, settled the way water settles.", "the lens on the rings")
	r.local_view = "room"
	g.dispatch("item:chart_clips")
	check(says(g.dispatch("printer")) == GameSim.GENERIC_WRONG_USE, "clips on the printer are generic")
	# Objectives through the room's life.
	check(r.objective() == "p02" and r.objective_text() == R04Sim.OBJECTIVES.p02, "objective: P02")
	var hint := g.dispatch("hint")
	check(says(hint) == R04Sim.HINTS.p02[0], "hint ladder starts at the nudge")
	g.dispatch("hint")
	check(says(g.dispatch("hint")) == R04Sim.HINTS.p02[2], "hint ladder reaches the solution")
	solve_p02(g)
	check(r.objective() == "away" and r.objective_text() == "Nothing here needs me yet. The horns are listening anyway.",
		"after P02: away until P16")
	var m := mixer_game()
	check(r04(m).objective() == "p17", "objective: P17")
	set_offset(m, -2)
	set_solo(m, true, false)
	m.dispatch("play")
	set_solo(m, false, true)
	m.dispatch("play")
	check(r04(m).objective() == "wait_p18", "objective: wait for P18")
	m.set_flag("P18")
	check(r04(m).objective() == "p19", "objective: P19")
	open_witness(m)
	check(r04(m).objective() == "p19_ask", "objective: ask")
	for q in R04Sim.QUESTIONS:
		m.dispatch(q)
	check(r04(m).objective() == "done" and r04(m).objective_text() == "The board is quiet.", "objective: done")
	for k in R04Sim.HINTS:
		check(R04Sim.OBJECTIVES.has(k) and R04Sim.HINTS[k].size() == 3, "hint ladder %s has three levels" % k)

func test_debug_jumps() -> void:
	var g := GameSim.new()
	var r := r04(g)
	var want := {
		0: [false, false, false, false],
		1: [true, false, false, false],
		2: [true, false, false, false],
		3: [true, true, false, false],
		4: [true, true, false, false],
		5: [true, true, true, false],
		6: [true, true, false, true],
		7: [true, true, false, true],
	}
	for n in range(0, 8):
		r.debug_jump(n)
		var got := [g.flag("P02"), g.flag("P17"), r.state.witness_open, g.flag("P19")]
		check(g.state.room == ROOM and g.flag("P01") and r.can_enter(), "jump %d: in the listening room" % n)
		check(JSON.stringify(got) == JSON.stringify(want[n]), "jump %d: %s (got %s)" % [n, want[n], got])
		check(r.local_view == "room" and r.seam_break == "", "jump %d: clean view" % n)
	r.debug_jump(2)
	check(g.flag("P16") and r.objective() == "p17", "jump 2: the mixer is live")
	r.debug_jump(4)
	check(g.flag("P18") and r.objective() == "p19", "jump 4: P19 is ready")
	r.debug_jump(5)
	check(r.objective() == "p19_ask", "jump 5: the line is open")
	r.debug_jump(7)
	check(g.weather_band() == 7, "jump 7: band 7")
	# Debug state survives a save round trip.
	for t in range(1, 10):
		var a := game_at(t, ROOM)
		var b := GameSim.new()
		b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
		check(JSON.stringify(r04(b).state) == JSON.stringify(r04(a).state), "tide %d: R04 state survives a load" % t)

# ---------------------------------------------------------------------------------------------
# the view: routing, close-up controls, holds, lamps, loops, still poses
# ---------------------------------------------------------------------------------------------
func _view_at(scene) -> RoomView:
	return scene.room_view

func test_view_scene() -> void:
	var scene = new_scene("user://room_test_R04_view.json")
	await process_frame
	scene.room_jump(ROOM, 0)
	await process_frame
	var v = scene.room_view
	var r := scene.room_sim() as R04Sim
	check(v != null and v.rid == ROOM, "view: mounts")
	if v == null:
		await free_scene(scene)
		return
	# view A, then view B: the board's hotspots answer only on the board
	check(v.exits_active() and not v.back_visible() and v.esc_action() == "menu", "view: room shows exits, no Back")
	scene.dispatch("to_board")
	check(r.local_view == "board" and not v.exits_active() and v.back_visible() and v.esc_action() == "back",
		"view: the board has Back, no exits")
	for h in v.BOARD_HOTSPOTS:
		check(scene.action_at(h[1].get_center()) == h[0], "view: board click reaches %s" % h[0])
		check(v.label_for(h[0]) == h[2], "view: board label %s" % h[0])
	scene.dispatch("back")
	check(r.local_view == "room", "view: Back from the board")
	# c_spindle: every control is reachable, and real clicks solve P02
	scene.dispatch("spindle")
	check(r.local_view == "c_spindle" and v.back_visible() and v.esc_action() == "back", "view: c_spindle is a close-up")
	for h in v.spindle_controls():
		check(scene.action_at(h[1].get_center()) == h[0], "view: c_spindle click reaches %s" % h[0])
	for id in ["tray_C", "tray_A", "tray_B", "rot_down_0", "rot_down_1", "rot_down_2"]:
		scene.click(_rect_of(v.spindle_controls(), id).get_center())
		scene.advance()
	check(r.state.spindle == ["C", "A", "B"] and r.evaluate() == "", "view: the bands set by clicks")
	scene.lines.clear()
	scene.cur_text = ""
	scene.dispatch("play")
	check(scene.room_sim().state.p02_complete and v.arm_target == 1.0, "view: PLAY lowers the arm")
	v.on_sfx("recording_p02")
	check(v._recording(), "view: the recording plays from its sound")
	v.on_sfx("cylinder_coast")
	check(v.arm_target == 0.0 and v.coast_t == 0.0, "view: the coast starts with its sound and lifts the arm")
	scene.dispatch("back")
	# notice hold: input-free, a click skips it
	v.play_fx("notice_leak_wind", {})
	check(v.hold_active() and v.hover_at(Vector2(260, 760)) == "", "view: a notice holds input")
	check(scene.action_at(Vector2(260, 760)) == "" and not v.hold_active(), "view: a click skips the hold")
	check(scene.action_at(Vector2(260, 760)) == "stool", "view: then the room answers again")
	# lamps: C lit at band 0, A/B with the motor
	check(v.lamp_lit("C") and v.lamp_lit("A") and v.lamp_lit("B"), "view: band 0, every lamp lit")
	# loops at band 0
	var t: Dictionary = v.loop_targets()
	check(t.r04_room > 0.0 and t.r04_motor > 0.0 and t.r04_leak_wind == 0.0 and t.r04_pressure == 0.0,
		"view: band 0 loops")
	# P19's last answer: C holds lit until the relay drops, then silence round the funnel voice
	scene.room_jump(ROOM, 5)
	await process_frame
	v = scene.room_view
	r = scene.room_sim() as R04Sim
	scene.dispatch("to_board")
	scene.dispatch("motor")
	check(r.local_view == "c_channels", "view: c_channels")
	for h in v.CHANNEL_CONTROLS:
		check(scene.action_at(h[1].get_center()) == h[0], "view: c_channels click reaches %s (line open)" % h[0])
	for q in ["q_where", "q_whole", "q_need"]:
		scene.dispatch(q)
	check(r.state.p19_complete and v.lamp_lit("C"), "view: C stays lit through the last answer")
	v.on_sfx("relay_off")
	check(not v.lamp_lit("C") and v.dark_t > 0.0, "view: the relay drops C at once")
	t = v.loop_targets()
	var others := 0.0
	for id in t:
		if id != "r04_room":
			others += t[id]
	check(others == 0.0 and t.r04_room > 0.0, "view: only the room tone under the funnel voice")
	# endings: every indicator off, only the room tone
	for e in ["continue", "sever"]:
		scene.tide_jump(9, ROOM)
		await process_frame
		v = scene.room_view
		scene.sim.state.ending = e
		t = v.loop_targets()
		var rest := 0.0
		for id in t:
			if id != "r04_room":
				rest += t[id]
		check(rest == 0.0 and t.r04_room > 0.0, "view: %s keeps only the room tone" % e)
		check(not v.lamp_lit("A") and not v.lamp_lit("B") and not v.lamp_lit("C"), "view: %s, lamps off" % e)
		check(v.stage() == ("sever" if e == "sever" else "s4"), "view: %s light stage" % e)
		check(v.plate_id() == ("room_a_sever" if e == "sever" else "room_a_s4"), "view: %s plate" % e)
		check(v.turned() == (e == "continue"), "view: %s, the bells' aim" % e)
		scene.sim.state.ending = ""
	# stage plates and light maps by band, both views; every one is painted
	var want_a := ["room_a", "room_a", "room_a", "room_a_s2", "room_a_turned", "room_a_s3", "room_a_s3", "room_a_s4"]
	var want_s := ["s1", "s1", "s1", "s2", "s2", "s3", "s3", "s4"]
	for tide in range(1, 10):
		scene.tide_jump(tide, ROOM)
		await process_frame
		v = scene.room_view
		r = scene.room_sim() as R04Sim
		var bnd := r.band()
		check(v.plate_id() == want_a[bnd] and v.stage() == want_s[bnd] and v.turned() == (bnd >= 4),
			"view: tide %d (band %d) plate %s" % [tide, bnd, v.plate_id()])
		check(v.light_id("add") == "a_glow_" + v.stage() and v._tex(v.light_id("add")) != null
			and v._tex(v.light_id("mul")) != null, "view: funnel wall light at tide %d" % tide)
		check(v._tex(v.plate_id()) != null, "view: plate %s painted" % v.plate_id())
		if bnd >= 3:
			check(v._tex("a_damp_b%d" % bnd) != null and v._tex("b_damp_b%d" % bnd) != null, "view: band %d damp painted" % bnd)
		scene.dispatch("to_board")
		check(v.plate_id().begins_with("room_b") and v._tex(v.plate_id()) != null, "view: board plate at tide %d" % tide)
		check(v.light_id("add") == "" and v._tex(v.light_id("mul")) != null, "view: the board has no warm light at tide %d" % tide)
		scene.dispatch("back")
	for id in ["room_a_sever", "a_dew", "a_dew_turned", "a_printout_long", "a_mul_sever", "a_glow_sever",
			"b_mul_sever", "stain_seated", "stain_seated_turned", "a_eyes", "c_spindle_four", "c_channels_log"]:
		check(v._tex(id) != null, "view: %s painted" % id)
	# deadpan loops at tide IX: the plaster breathes and the transcript lifts with motion on;
	# with motion off both hold still
	scene.tide_jump(9, ROOM)
	await process_frame
	v = scene.room_view
	scene.time = PAPER_QUARTER
	check(v._breath(v.PAPER_PERIOD) > 0.9, "view: the transcript lifts with motion on")
	scene.sim.settings.motion = false
	check(v._breath(v.PAPER_PERIOD) == 0.0, "view: still alternative, the transcript at rest")
	scene.sim.settings.motion = true
	# Motion & flicker off: still poses, no timed motion
	scene.room_jump(ROOM, 0)
	await process_frame
	v = scene.room_view
	scene.sim.settings.motion = false
	v.play_fx("needle_down", {})
	check(v.arm_k == 1.0, "view: still arm drops without animating")
	v.on_sfx("cylinder_coast")
	check(v.arm_k == 0.0 and v.coasted and v.coast_t < 0.0, "view: still coast holds the moved seam mark")
	v.on_sfx("needle_skip")
	check(v.jolt_t == 0.0, "view: no jolt without motion")
	v.reset_presentation()
	check(not v.coasted and v.rec_start < 0.0 and not v.hold_active(), "view: reset clears the timed presentation")
	scene.sim.settings.motion = true
	await free_scene(scene)

func _rect_of(table: Array, id: String) -> Rect2:
	for h in table:
		if h[0] == id:
			return h[1]
	return Rect2()

# ---------------------------------------------------------------------------------------------
# round w1 (fixer): first-entry wrongness, the decoy band, funnel 5, the seance, levels
# ---------------------------------------------------------------------------------------------
func test_w1_lines() -> void:
	check(R04Sim.ARRIVAL == "The listening room. Six ear trumpets, all pointing at one damp patch in the plaster. It's the shape of someone sitting.",
		"w1: the arrival names the seated stain")
	var g := GameSim.new()
	g.reset()
	g.set_flag("P01")
	var ev := []
	r04(g).arrive(ev, true)
	check(r04(g).has_seen("stain_seated"), "w1: the first arrival logs the stain")
	check(R04Sim.RECORDING[2][0] == "[a chair creaks on the cylinder. Then, close to the horn, someone who is not Venn breathes in.]",
		"w1: the breath caption")
	var obs: String = R04Sim.OBSERVATIONS.recording_tomorrow
	check("someone who is not Venn breathes in" in obs and not "unattributed" in obs, "w1: the notebook matches the caption")
	var need: String = R04Sim.ANSWERS.q_need[3]
	check(need == "VENN: Physically. Here. A witness, not a signature. Three days I have stood where you are standing. There is less of me each tide.",
		"w1: Venn's last answer")
	check("Three days I have stood where you are standing. There is less of me each tide." in R04Sim.OBSERVATIONS.venn_answers
		and not "wearing out" in R04Sim.OBSERVATIONS.venn_answers, "w1: the notebook keeps his last answer")
	var a := channels_game(flags_upto(18))
	open_witness(a)
	check(need in says(a.dispatch("q_need")), "w1: the answer plays")
	# idle objectives: away before P16 and between P17 and P18 never, done after P19
	check(R04Sim.OBJECTIVES.away == "Nothing here needs me yet. The horns are listening anyway." and R04Sim.OBJECTIVES.done == "The board is quiet.",
		"w1: idle objective lines")
	check(R04Sim.HINTS.away.size() == 3 and R04Sim.HINTS.done.size() == 3, "w1: idle hint ladders")
	check(r04(game_at(9, ROOM)).objective() == "done", "w1: tide IX is done")
	var t3 := game_at(3, ROOM)
	check(r04(t3).objective() == "away", "w1: tide III, nothing here yet")
	for key in R04Sim.ITEMS:
		var it: Dictionary = R04Sim.ITEMS[key]
		check(str(it.name).length() <= 14 or it.has("short"), "w1: item %s has a short name" % key)

func test_w1_decoy() -> void:
	check(R04Sim.BANDS == ["B", "D", "A", "C"], "w1: the tray reads B, D, A, C")
	var g := fresh()
	var r := r04(g)
	g.dispatch("spindle")
	check(r.has_seen("band_tray") and "14 OCT" in R04Sim.OBSERVATIONS.band_tray and "17 OCT" in R04Sim.OBSERVATIONS.spindle,
		"w1: the notebook has both days")
	build(g, ["D", "A", "B"], {"D": 2, "A": 0, "B": 2})
	var before := snapshot(g)
	var ev := g.dispatch("play")
	check(says(ev) == WRONG_DAY and r.seam_break == "wrong_day" and not g.flag("P02"), "w1: D-A-B plays the fourteenth, the wrong day")
	check(snapshot(g) == before and r.state.spindle == ["D", "A", "B"], "w1: the wrong day costs nothing")
	check(has_ev(ev, "sfx", "wax_fragment_2") and not has_ev(ev, "sfx", "recording_p02"), "w1: only a fragment plays")
	# swap D for C and fix the rotations: the canonical path still solves
	g.dispatch("slot_0")
	g.dispatch("tray_C")
	check(r.state.spindle == ["C", "A", "B"], "w1: C goes into the freed seat")
	build(g, ["C", "A", "B"], {"C": 0, "A": 2, "B": 1})
	g.dispatch("play")
	check(g.flag("P02") and r.state.band_rot.D == 2, "w1: then C-A-B at I, III, II solves; D keeps its turn")
	check(R04Sim.HINTS.p02[2] == "Place C, then A, then B from the start end. Turn them to I, III, II so the seam is continuous. Then play.",
		"w1: the explicit hint is unchanged")

func test_w1_funnel5() -> void:
	var g := fresh()
	check(r04(g).funnel5_pose() == "rest", "w1: funnel 5 faces the wall at first")
	g.set_flag("P04")
	check(r04(g).funnel5_pose() == "half", "w1: after P04 it has turned partway")
	var t6 := game_at(6, ROOM)
	check(r04(t6).band() >= 4 and r04(t6).funnel5_pose() == "turned", "w1: band 4+, at the seat with the others")
	var t7 := game_at(7, ROOM)
	check(r04(t7).funnel5_pose() == "turned", "w1: tide VII before P19")
	open_witness(t7)
	for q in R04Sim.QUESTIONS:
		t7.dispatch(q)
	check(r04(t7).funnel5_pose() == "facing", "w1: after P19 it faces her")
	var l := GameSim.new()
	l.from_dict(JSON.parse_string(JSON.stringify(t7.to_dict())))
	check(r04(l).funnel5_pose() == "facing", "w1: the facing pose survives a load")
	t7.dispatch("back")
	t7.dispatch("to_funnels")
	var fev := t7.dispatch("funnels")
	check("looking straight at me" in says(fev) and r04(t7).has_seen("five_facing"), "w1: the funnels line while it faces her")
	t7.set_flag("P21")
	check(r04(t7).funnel5_pose() == "turned", "w1: the next tide it turns back with the others")
	var s := game_at(9, ROOM)
	s.state.ending = "sever"
	check(r04(s).funnel5_pose() == "rest", "w1: released, it hangs as it was hung")

func test_w1_view() -> void:
	var scene = new_scene("user://room_test_R04_w1.json")
	await process_frame
	scene.room_jump(ROOM, 0)
	await process_frame
	var v = scene.room_view
	if v == null:
		await free_scene(scene)
		return
	# levels: room tone -3/-7/-5 dB, motor -14 dB
	var t: Dictionary = v.loop_targets()
	check(is_equal_approx(t.r04_room, db_to_linear(-3.0)) and is_equal_approx(t.r04_motor, db_to_linear(-14.0)),
		"w1 view: band 0 room tone -3 dB, motor -14 dB")
	# the grade: eight even steps to (0.80, 0.84, 0.90)
	check(v.TINT.size() == 8 and v.TINT[0] == Color(1, 1, 1) and v.TINT[7].is_equal_approx(Color(0.80, 0.84, 0.90)),
		"w1 view: tint grade ends storm-cold")
	for i in 7:
		check(v.TINT[i + 1].r < v.TINT[i].r and v.TINT[i + 1].b < v.TINT[i].b, "w1 view: tint step %d cools" % i)
	# the tray: four cradles, one row, no overlaps, every one clickable
	var rows := {}
	for b in R04Sim.BANDS:
		rows[v.TRAY_RECTS[b].position.y] = true
		for o in R04Sim.BANDS:
			if o != b:
				check(not v.TRAY_RECTS[b].intersects(v.TRAY_RECTS[o]), "w1 view: tray %s clear of %s" % [b, o])
	check(rows.size() == 1, "w1 view: the tray is one row")
	check(v.TRAY_RECTS.B.position.x < v.TRAY_RECTS.D.position.x and v.TRAY_RECTS.D.position.x < v.TRAY_RECTS.A.position.x
		and v.TRAY_RECTS.A.position.x < v.TRAY_RECTS.C.position.x, "w1 view: tray order B, D, A, C")
	# the session log: three written lines, stacked, inside the sheet, no overlaps
	var qs := []
	for h in v.CHANNEL_CONTROLS:
		if str(h[0]).begins_with("q_"):
			qs.append(h[1])
			check(Rect2(150, 798, 1150, 174).encloses(h[1]), "w1 view: %s on the log sheet" % h[0])
	check(qs.size() == 3 and not qs[0].intersects(qs[1]) and not qs[1].intersects(qs[2]) and qs[0].position.y < qs[2].position.y,
		"w1 view: three separate lines")
	# funnel 5: the P19 turn waits for the wall, then turns over 1.5 s and holds
	scene.room_jump(ROOM, 5)
	await process_frame
	v = scene.room_view
	scene.dispatch("to_board")
	scene.dispatch("motor")
	var pre: Vector2 = v.f5_pose()
	for q in ["q_where", "q_whole", "q_need"]:
		scene.dispatch(q)
	v.play_fx("funnel_voice", {})
	check(v.f5_pending and v.f5_k == 0.0 and is_equal_approx(v.f5_pose().y, pre.y), "w1 view: the turn waits off screen")
	v.tick(1.0)
	check(v.f5_pending and v.f5_k == 0.0, "w1 view: still waiting in the close-up")
	scene.dispatch("back")
	scene.dispatch("to_funnels")
	v.tick(0.75)
	check(not v.f5_pending and v.f5_k > 0.4 and v.f5_k < 0.6 and v.f5_pose().y > pre.y and v.f5_pose().y < 1.0,
		"w1 view: halfway round after 0.75 s")
	v.tick(1.0)
	check(v.f5_k == 1.0 and is_equal_approx(v.f5_pose().y, 1.0), "w1 view: facing her after 1.5 s")
	v.reset_presentation()
	check(is_equal_approx(v.f5_pose().y, 1.0), "w1 view: the pose is the state's, not the animation's")
	scene.sim.settings.motion = false
	v.play_fx("funnel_voice", {})
	v.tick(0.016)
	check(v.f5_k == 1.0, "w1 view: motion off, the turn snaps")
	scene.sim.settings.motion = true
	await free_scene(scene)
