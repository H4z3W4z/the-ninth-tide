extends "res://tests/rooms/room_test_base.gd"
## R03, the Chart Room: skeleton checks plus P03 part 2, P04, P05, P21, walls, notices,
## save/load and debug stages.
##   godot --headless --path . --script tests/rooms/R03_test.gd

const ROOM := "R03"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := ["P01"]
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 2
const VIEW_SCRIPT := preload("res://game/rooms/R03/R03_view.gd")

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	test_walls_const()
	test_p03_matrix()
	test_p03_gates()
	test_p03_success()
	test_clip_tin_and_prophecy()
	test_p04_matrix()
	test_p04_gates_and_wheels()
	test_p04_success()
	test_p05_orders()
	test_p05_trace_and_strip()
	test_p05_shutter()
	test_p21_matrix()
	test_p21_actions()
	test_p21_gates_and_outputs()
	test_save_load()
	test_notice_order_survives()
	test_reconcile_keeps_flags()
	test_notices()
	test_sea_low_and_knot()
	test_stair_looked()
	test_hotspots_everywhere()
	test_turns()
	test_items()
	test_objectives()
	test_debug_jumps()
	test_round_p1_hints()
	test_round_p2_lighthouse_out()
	test_round_p2_plate_words()
	test_round_p3_hints()
	test_round_p3_overlay()
	test_geometry()
	await view_checks(ROOM)
	await test_view()

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
func r3(g: GameSim) -> R03Sim:
	return g.room(ROOM) as R03Sim

## A game at room stage n (R03Sim.debug_jump).
func stage(n: int) -> GameSim:
	var g := GameSim.new()
	r3(g).debug_jump(n)
	return g

func count_says(ev: Array, text: String) -> int:
	var n := 0
	for e in ev:
		if e.type == "say" and e.text == text:
			n += 1
	return n

func sfx_index(ev: Array, id: String) -> int:
	for i in ev.size():
		if ev[i].type == "sfx" and ev[i].id == id:
			return i
	return -1

func notice_fx(ev: Array) -> Array:
	var out := []
	for e in ev:
		if e.type == "fx" and e.id == "notice":
			out.append(e.notice)
	return out

func tide_fx(ev: Array) -> int:
	var n := 0
	for e in ev:
		if e.type == "fx" and e.id == "tide":
			n += 1
	return n

## Lays Venn's sheet in the registration close-up of a stage-1 game.
func laid_game() -> GameSim:
	var g := stage(1)
	g.dispatch("sheet_table")
	lay(g)
	return g

## His sheet laid the only way it is: the item, used on the light table.
func lay(g: GameSim) -> Array:
	g.dispatch("item:venn_tide_sheet")
	return g.dispatch("reg_table")

## The clips used on the clip rail (the commit).
func clip(g: GameSim) -> Array:
	g.dispatch("item:chart_clips")
	return g.dispatch("reg_clip")

func set_rot(g: GameSim, rot: int) -> void:
	var r := r3(g)
	while int(r.state.reg_rot) != rot:
		g.dispatch("reg_rot_cw")

## A game with P04 solved, standing at the recorder close-up.
func record_game() -> GameSim:
	var g := stage(4)
	g.dispatch("recorder")
	return g

func place(g: GameSim, order: Array) -> void:
	for i in order.size():
		if order[i] != "":
			g.dispatch("rec_plate_" + order[i])
			g.dispatch("rec_slot_%d" % i)

const PERMS := [["boundary", "relation", "observer"], ["boundary", "observer", "relation"],
	["relation", "boundary", "observer"], ["relation", "observer", "boundary"],
	["observer", "boundary", "relation"], ["observer", "relation", "boundary"]]

# ---------------------------------------------------------------------------
# walls
# ---------------------------------------------------------------------------
func test_walls_const() -> void:
	var n := 0
	for w in R03Sim.WALL_HOTSPOTS:
		for h in R03Sim.WALL_HOTSPOTS[w]:
			n += 1
			check(R03Sim.WALL_OF.get(h, "") == w, "WALL_OF[%s] is %s" % [h, w])
	check(n == R03Sim.WALL_OF.size(), "WALL_OF covers exactly the wall hotspots")
	check(R03Sim.WALL_HOTSPOTS.A == R03Sim.HOTSPOTS, "wall A is HOTSPOTS")
	check(GameSim.new().room(ROOM).wall == "A", "a fresh sim faces wall A")

func test_turns() -> void:
	var g := stage(0)
	var r := r3(g)
	var seq := []
	for i in 3:
		var ev := g.dispatch("turn_right")
		check(has_ev(ev, "sfx", "turn"), "a turn plays the turn sfx")
		seq.append(r.wall)
	check(seq == ["B", "C", "A"], "turning right: A B C A (%s)" % [seq])
	seq = []
	for i in 3:
		g.dispatch("turn_left")
		seq.append(r.wall)
	check(seq == ["C", "B", "A"], "turning left: A C B A (%s)" % [seq])
	g.dispatch("plan_wall")
	var ev := g.dispatch("turn_left")
	check(r.local_view == "c_plan" and r.wall == "A" and ev.is_empty(), "no turning inside a close-up")
	g.dispatch("back")
	check(r.local_view == "room" and r.wall == "A", "Back from the plan faces wall A")

func test_hotspots_everywhere() -> void:
	for n in [1, 3, 5, 8]:
		var g := stage(n)
		var r := r3(g)
		for start in R03Sim.WALLS:
			for h in R03Sim.WALL_OF:
				r.local_view = "room"
				r.wall = start
				var ev := g.dispatch(h)
				check(says(ev) != "", "stage %d: %s answers from wall %s" % [n, h, start])
				check(r.wall == R03Sim.WALL_OF[h], "stage %d: %s faces its wall from %s" % [n, h, start])
		for cu in ["sheet_table", "recorder", "plan_wall"]:
			for h in R03Sim.WALL_OF:
				r.local_view = "room"
				g.dispatch(cu)
				check(r.is_closeup(), "stage %d: %s opens a close-up" % [n, cu])
				r.held_plate = "observer"
				r.held_pin = true
				var ev := g.dispatch(h)
				check(says(ev) != "", "stage %d: %s answers from inside %s" % [n, h, cu])
				check(r.wall == R03Sim.WALL_OF[h], "stage %d: %s from %s faces its wall" % [n, h, cu])
				if not h in ["sheet_table", "recorder", "plan_wall", "seal", "plate_rack"]:
					check(r.local_view == "room" and r.held_plate == "" and not r.held_pin,
						"stage %d: %s from %s leaves the close-up, hand empty" % [n, h, cu])

# ---------------------------------------------------------------------------
# P03 part 2
# ---------------------------------------------------------------------------
func test_p03_matrix() -> void:
	var refuse: Dictionary = R03Sim.REG_REFUSE
	for base in ["14", "17"]:
		for rot in 4:
			for snap in ["", "lighthouse", "buoy", "datum"]:
				var g := laid_game()
				var r := r3(g)
				g.dispatch("reg_base_" + base)
				set_rot(g, rot)
				if snap != "":
					g.dispatch("reg_snap_" + snap)
				var ev := clip(g)
				var want := ""
				if base != "17": want = refuse.date
				elif rot != 0: want = refuse.north
				elif snap == "": want = refuse.no_snap
				elif snap != "lighthouse": want = refuse.cross
				var tag := "%s/%d/%s" % [base, rot, snap]
				if want == "":
					check(g.flag("P03") and r.state.p03_complete, "%s solves P03" % tag)
				else:
					check(not g.flag("P03") and says(ev) == want, "%s refuses '%s' (got '%s')" % [tag, want, says(ev)])
					check(has_ev(ev, "sfx", "clip_refuse") and r.state.clip_misses == 1, "%s: clip_refuse, one miss" % tag)
					check(r.state.reg_base == base and r.state.reg_rot == rot and r.state.reg_snap == snap,
						"%s: the arrangement stays" % tag)
					check(g.has_item("venn_tide_sheet") and g.has_item("chart_clips"), "%s: a wrong clip consumes nothing" % tag)

func test_p03_gates() -> void:
	var refuse: Dictionary = R03Sim.REG_REFUSE
	# Without Venn's sheet.
	var g := stage(0)
	var r := r3(g)
	g.dispatch("clip_tin")
	g.dispatch("sheet_table")
	var ev := g.dispatch("reg_lay")
	check(says(ev) == refuse.no_sheet and not r.state.reg_laid, "no sheet to lay: with E.V.")
	ev = g.dispatch("reg_table")
	check(says(ev) == refuse.no_sheet and not r.state.reg_laid, "the bare table: with E.V.")
	ev = g.dispatch("reg_clip")
	check(says(ev) == R03Sim.REG_HAS_CLIPS and r.state.clip_misses == 0, "the bare rail: the clips are in her pocket")
	ev = clip(g)
	check(says(ev) == refuse.no_sheet and not g.flag("P03"), "clip without the sheet: with E.V.")
	check(g.has_item("chart_clips"), "a refused clip keeps the clips")
	for a in ["reg_rot_cw", "reg_rot_ccw", "reg_snap_lighthouse"]:
		ev = g.dispatch(a)
		check(says(ev) == R03Sim.REG_NOT_LAID, "%s needs the sheet laid" % a)
	check(r.state.reg_rot == 2 and r.state.reg_snap == "", "nothing turned or pinned")
	# Even a forced arrangement can't complete without the sheet.
	r.state.reg_laid = true; r.state.reg_base = "17"; r.state.reg_rot = 0; r.state.reg_snap = "lighthouse"
	ev = clip(g)
	check(not g.flag("P03") and says(ev) == refuse.no_sheet, "P03 can't complete without venn_tide_sheet")
	# Sheet in hand, not laid.
	g = stage(1)
	r = r3(g)
	g.dispatch("sheet_table")
	ev = g.dispatch("reg_lay")
	check(says(ev) == R03Sim.REG_HAS_SHEET and not r.state.reg_laid, "the bare tray doesn't lay his sheet")
	ev = g.dispatch("reg_table")
	check(says(ev) == R03Sim.REG_HAS_SHEET and not r.state.reg_laid, "nor does the bare table")
	ev = clip(g)
	check(says(ev) == refuse.not_laid, "sheet in inventory but not laid")
	ev = lay(g)
	check(r.state.reg_laid and r.has_seen("venn_sheet") and g.has_item("venn_tide_sheet"), "his sheet, used on the table, is laid")
	ev = lay(g)
	check(says(ev) == R03Sim.REG_LAID_ALREADY, "laying twice: already there")
	# Laid, no clips.
	g = stage(1)
	g.take("chart_clips")
	g.dispatch("sheet_table")
	lay(g)
	g.dispatch("reg_base_17"); set_rot(g, 0); g.dispatch("reg_snap_lighthouse")
	ev = g.dispatch("reg_clip")
	check(says(ev) == refuse.no_clips and refuse.no_clips == "Nothing to hold them with. There was a tin."
		and not g.flag("P03"), "no clips: there was a tin")
	check(g.has_item("venn_tide_sheet"), "the refused clip keeps the sheet")
	# Lift clears the pin, keeps the rest.
	g = laid_game()
	r = r3(g)
	g.dispatch("reg_snap_buoy")
	g.dispatch("reg_lift")
	check(not r.state.reg_laid and r.state.reg_snap == "", "lifting the sheet unpins it")
	ev = g.dispatch("reg_example")
	check(r.has_seen("example") and says(ev).ends_with("through band 1."), "the worked example")

func test_p03_success() -> void:
	var g := laid_game()
	var r := r3(g)
	check(r.has_seen("venn_sheet"), "laying observes venn_sheet")
	g.dispatch("reg_base_17"); set_rot(g, 0); g.dispatch("reg_snap_lighthouse")
	var ev := g.dispatch("reg_clip")
	check(not g.flag("P03") and says(ev) == R03Sim.REG_HAS_CLIPS, "a bare click on the rail doesn't clip")
	ev = clip(g)
	check(g.flag("P03") and r.state.p03_complete, "17 / north up / lighthouse solves")
	check(not g.has_item("venn_tide_sheet") and g.has_item("chart_clips"), "the sheet is taken, the clips kept")
	check(r.has_seen("calibration_interval") and r.has_seen("composite_chart"), "calibration_interval and composite_chart")
	check(g.value("movement_events").back() == "charts_aligned", "charts_aligned recorded")
	check(has_ev(ev, "fx", "composite") and has_ev(ev, "sfx", "clip_snap"), "composite fx and clip snap")
	check(R03Sim.CURVE_LINE in says(ev) and not "three" in says(ev) and not "3" in says(ev), "the curve line names no band")
	check(not R03Sim.RECONCILE_LINE in says(ev), "no reconcile line without P02")
	for o in ["calibration_interval", "composite_chart"]:
		var t: String = r.observation_text(o)
		check(not "3" in t and not "three" in t.to_lower() and not "Interval:" in t, "%s speaks no interval number" % o)
	check("numbered band" in r.observation_text("composite_chart"), "the composite names his numbered bands")
	var moves: Array = g.value("movement_events")
	var nb: int = g.state.notebook.size()
	ev = clip(g)
	check(says(ev) == R03Sim.REG_CLIPPED and not has_ev(ev, "fx", "composite"), "a repeat clip doesn't re-solve")
	ev = g.dispatch("reg_clip")
	check(says(ev) == R03Sim.REG_CLIPPED, "a bare repeat: clipped")
	check(g.value("movement_events") == moves and g.state.notebook.size() == nb, "a repeat clip duplicates nothing")
	for a in ["reg_base_14", "reg_lift", "reg_rot_cw", "reg_snap_buoy", "reg_lay"]:
		ev = g.dispatch(a)
		check(says(ev) == R03Sim.REG_CLIPPED, "%s after P03: clipped" % a)
	check(r.state.reg_base == "17" and r.state.reg_laid and r.state.reg_rot == 0, "the composite stays")
	g.dispatch("back")
	ev = g.dispatch("sheet_table")
	check(says(ev).begins_with("The composite, clipped."), "later: the composite")
	# With P02 the tide closes: the reconcile line.
	g = laid_game()
	g.set_flag("P02")
	g.dispatch("reg_base_17"); set_rot(g, 0); g.dispatch("reg_snap_lighthouse")
	ev = clip(g)
	check(R03Sim.RECONCILE_LINE in says(ev) and g.tide_done(1), "tide I done: the office line")
	# Using the sheet on the table opens and lays it.
	g = stage(1)
	r = r3(g)
	g.dispatch("item:venn_tide_sheet")
	ev = g.dispatch("sheet_table")
	check(r.local_view == "c_registration" and r.state.reg_laid, "the sheet on the table opens and lays")
	check(g.has_item("venn_tide_sheet"), "laying doesn't consume the sheet")

func test_clip_tin_and_prophecy() -> void:
	var g := stage(0)
	var r := r3(g)
	var ev := g.dispatch("clip_tin")
	check(g.has_item("chart_clips") and r.state.clips_taken and has_ev(ev, "sfx", "tin_open"), "the tin grants the clips")
	check(r.has_seen("clip_tin"), "clip_tin observed")
	ev = g.dispatch("clip_tin")
	check(says(ev) == "The tin's empty. I have the clips." and g.state.inventory.count("chart_clips") == 1, "only once")
	g.take("chart_clips")
	g.dispatch("clip_tin")
	check(not g.has_item("chart_clips"), "an empty tin gives nothing more")
	# Prophecy: once, only with P02.
	g = stage(0)
	r = r3(g)
	ev = g.dispatch("sheet_table")
	check(says(ev) == "The chart table. Two sheets, the 14th and the 17th, and an empty clip for a third.", "first open")
	check(not "standing at the chart table" in says(ev) and not r.state.prophecy_seen, "no prophecy without P02")
	g.dispatch("back")
	g.set_flag("P02")
	ev = g.dispatch("sheet_table")
	check(says(ev).begins_with("His chart table.") and "'Mercer will be standing at the chart table.' I am." in says(ev), "the prophecy with P02")
	var line: Dictionary = ev.filter(func(e): return e.type == "say" and "Mercer" in e.text)[0]
	check(line.story and is_equal_approx(line.delay, 1.2), "the prophecy is a story line at 1.2")
	g.dispatch("back")
	ev = g.dispatch("sheet_table")
	check(not "Mercer" in says(ev), "the prophecy comes once")

# ---------------------------------------------------------------------------
# P04
# ---------------------------------------------------------------------------
func test_p04_matrix() -> void:
	var g := game_at(2, ROOM)
	var r := r3(g)
	g.dispatch("recorder")
	var misses := 0
	for z in 10:
		for i in 10:
			if z == 4 and i == 3:
				continue
			r.state.zero = z
			r.state.interval = i
			var ev := g.dispatch("rec_calibrate")
			misses += 1
			var want := ["ok" if z == 4 else "mismatch", "ok" if i == 3 else "mismatch"]
			check(r.state.gauges == want, "%d/%d gauges %s (got %s)" % [z, i, want, r.state.gauges])
			var line := "Both out." if z != 4 and i != 3 else ("The zero's out." if z != 4 else "The interval's out.")
			check(says(ev) == line and has_ev(ev, "sfx", "lever_refuse"), "%d/%d: %s" % [z, i, line])
			check(not g.flag("P04"), "%d/%d doesn't solve" % [z, i])
	check(r.state.pull_misses == misses, "every wrong pull is a miss")
	r.state.zero = 4
	r.state.interval = 3
	g.dispatch("rec_calibrate")
	check(g.flag("P04") and r.state.gauges == ["ok", "ok"], "4/3 solves")

func test_p04_gates_and_wheels() -> void:
	# Before the threshold: the seal.
	var g := stage(2)
	var r := r3(g)
	check(not g.flag("t1x_threshold_crossed"), "stage 2 is before the threshold")
	g.dispatch("recorder")
	for a in ["rec_zero_up", "rec_zero_down", "rec_int_up", "rec_int_down", "rec_seal"]:
		var ev := g.dispatch(a)
		check(says(ev) == R03Sim.SEAL_LINE, "%s before the threshold: the seal" % a)
	check(r.has_seen("seal"), "the seal observed")
	var ev := g.dispatch("rec_calibrate")
	check(says(ev) == "It won't pull. Not with his seal across it." and not g.flag("P04"), "won't pull under the seal")
	check(r.state.zero == 7 and r.state.interval == 2, "the wheels stay at the worked example")
	g.dispatch("back")
	ev = g.dispatch("seal")
	check(says(ev) == R03Sim.SEAL_LINE and r.local_view == "room", "the sealed seal doesn't open the recorder")
	# After: wheels turn mod 10, record moves (collapsed), reset gauges.
	g = game_at(2, ROOM)
	r = r3(g)
	g.dispatch("recorder")
	r.state.gauges = ["ok", "mismatch"]
	ev = g.dispatch("rec_zero_down")
	check(r.state.zero == 6 and r.state.gauges == ["", ""] and has_ev(ev, "sfx", "wheel_click"), "zero down, gauges reset")
	for i in 7:
		g.dispatch("rec_zero_down")
	check(r.state.zero == 9, "the zero wheel wraps (6 - 7 = 9)")
	g.dispatch("rec_int_up")
	g.dispatch("rec_int_up")
	check(r.state.interval == 4, "interval up")
	for i in 7:
		g.dispatch("rec_int_up")
	check(r.state.interval == 1, "the interval wheel wraps")
	var m: Array = g.value("movement_events")
	check(m.slice(-2) == ["zero_turned", "interval_set"] and m.count("zero_turned") == 1, "wheel moves collapse (%s)" % [m])
	ev = g.dispatch("rec_plate_info")
	check(r.has_seen("calibration_plate") and says(ev).begins_with("ZERO and INTERVAL are separate"), "the calibration plate")
	ev = g.dispatch("rec_seal")
	check(says(ev) == R03Sim.SEAL_BROKEN_LINE, "the broken seal")
	# Without P02 (debug only).
	g = game_at(2, ROOM)
	r = r3(g)
	g.set_flag("P02", false)
	g.dispatch("recorder")
	r.state.zero = 4; r.state.interval = 3
	ev = g.dispatch("rec_calibrate")
	check(says(ev).begins_with("I don't have a zero") and not g.flag("P04"), "no zero without P02")

func test_p04_success() -> void:
	var g := game_at(2, ROOM)
	var r := r3(g)
	g.dispatch("recorder")
	for i in 3: g.dispatch("rec_zero_down")
	g.dispatch("rec_int_up")
	var ev := g.dispatch("rec_calibrate")
	check(g.flag("P04") and r.state.p04_complete, "4/3 by the wheels solves P04")
	check(g.value("movement_events").back() == "hatch_opened", "hatch_opened recorded")
	check(r.has_seen("stair_threshold") and has_ev(ev, "fx", "drum_turn"), "stair_threshold and drum_turn")
	var ratchet := sfx_index(ev, "calibrate_ratchet")
	var hatch := sfx_index(ev, "hatch_open")
	check(ratchet >= 0 and hatch > ratchet and ev[ratchet].delay < ev[hatch].delay, "the ratchet before the hatch")
	check(sfx_index(ev, "lever_refuse") < 0, "no refusal sound on success")
	check(g.exit_open(ROOM, "R11"), "the hatch exit opens")
	var moves: Array = g.value("movement_events")
	for a in ["rec_calibrate", "rec_zero_up", "rec_int_down"]:
		ev = g.dispatch(a)
		check(says(ev) == R03Sim.CALIBRATED and not has_ev(ev, "fx", "drum_turn"), "%s after P04: calibrated" % a)
	check(g.value("movement_events") == moves and r.state.zero == 4, "a repeat pull duplicates nothing")
	check(r.drum_turning(), "the drum turns")

# ---------------------------------------------------------------------------
# P05
# ---------------------------------------------------------------------------
func test_p05_orders() -> void:
	for order in PERMS:
		var g := record_game()
		var r := r3(g)
		place(g, order)
		check(r.state.slots == order and r.held_plate == "", "%s placed" % [order])
		var ev := g.dispatch("rec_record")
		var want := ""
		if order[0] != "boundary": want = R03Sim.REFUSE_BOUNDARY
		elif order[1] != "relation": want = R03Sim.REFUSE_RELATION
		if want == "":
			check(g.flag("P05") and r.state.record_refusal == "", "%s records" % [order])
		else:
			check(not g.flag("P05") and r.state.record_refusal == want, "%s refuses: %s" % [order, want])
			check(r.refusal_text() == want and says(ev) == "It printed why.", "%s: printed, Ada" % [order])
			check(has_ev(ev, "sfx", "record_key") and has_ev(ev, "sfx", "record_refuse"), "%s: refusal sounds" % [order])
			check(r.state.slots == order, "%s: the plates stay put after a refusal" % [order])
	# Every partial fill.
	var g := record_game()
	var r := r3(g)
	var n := 0
	var fills := [[]]
	for i in 3:
		var nxt := []
		for f in fills:
			for p in ["", "boundary", "relation", "observer"]:
				if p == "" or not p in f:
					nxt.append(f + [p])
		fills = nxt
	for f in fills:
		if not "" in f:
			continue
		r.state.slots = f.duplicate()
		var ev := g.dispatch("rec_record")
		check(r.state.record_refusal == R03Sim.REFUSE_INCOMPLETE and not g.flag("P05"), "%s: INCOMPLETE" % [f])
		check(r.state.slots == f, "%s: plates stay" % [f])
		check(says(ev) == R03Sim.RECORD_MISS_LINES[n % 3], "Ada rotates (%d)" % n)
		n += 1
	check(n == 28 and r.state.record_misses == n, "every partial fill refused (%d)" % n)
	# Hand: pick, put back, swap, slot pickup.
	g = record_game()
	r = r3(g)
	check(r.rack_plates() == ["observer", "boundary", "relation"], "the rack in home order")
	g.dispatch("rec_plate_boundary")
	check(r.held_plate == "boundary" and r.rack_plates() == ["observer", "", "relation"] and r.has_seen("plates"), "pick a plate")
	g.dispatch("rec_plate_boundary")
	check(r.held_plate == "" and r.rack_plates()[1] == "boundary", "put it back")
	g.dispatch("rec_plate_relation"); g.dispatch("rec_slot_0")
	g.dispatch("rec_plate_boundary"); g.dispatch("rec_slot_0")
	check(r.state.slots[0] == "boundary" and r.rack_plates() == ["observer", "", "relation"], "seating over a plate returns it to the rack")
	g.dispatch("rec_slot_0")
	check(r.held_plate == "boundary" and r.state.slots[0] == "", "an occupied slot hands its plate back")
	g.dispatch("back")
	check(r.held_plate == "" and r.rack_plates()[1] == "boundary", "Back puts the held plate on the rack")
	g.dispatch("recorder")
	var ev := g.dispatch("rec_miniature")
	check(r.has_seen("miniature") and says(ev) == R03Sim.MINIATURE, "the miniature")
	for t in [says(ev), r.observation_text("miniature"), R03Sim.MINIATURE_CARD]:
		check(not "BOUNDARY" in t and not "RELATION" in t and not "OBSERVER" in t, "the miniature doesn't print the answer")
	check("PILE → SPAN → LAMP" in R03Sim.MINIATURE_CARD and R03Sim.MINIATURE.ends_with(R03Sim.MINIATURE_CARD + "\""),
		"the duty card's own example")
	check(R03Sim.HINTS.record[1] == "The hatch frame is carved. Read it the way you'd meet it going down.", "hint 2 points at the hatch")
	# After the miniature, the hatch marks get one quiet line.
	g.dispatch("back")
	ev = g.dispatch("hatch_scratches")
	check(R03Sim.SCRATCHES_AFTER_MINIATURE in says(ev), "the hatch: not his example")
	var line: Dictionary = ev.filter(func(e): return e.type == "say" and e.text == R03Sim.SCRATCHES_AFTER_MINIATURE)[0]
	check(not line.get("story", false), "a quiet (feedback) line")
	g = record_game()
	ev = g.dispatch("hatch_scratches")
	check(not R03Sim.SCRATCHES_AFTER_MINIATURE in says(ev), "not before the miniature is read")

func test_p05_trace_and_strip() -> void:
	for turned in [false, true]:
		var g := stage(4)
		var r := r3(g)
		if turned:
			(g.room("R02") as R02Sim).state.turned = true
			g.room("R02").reconcile()
		check(g.flag("t1x_turned") == turned, "t1x_turned %s" % turned)
		g.dispatch("hatch")   # stair_looked
		g.dispatch("recorder")
		place(g, ["boundary", "relation", "observer"])
		var before: Array = g.value("movement_events").slice(-3)
		var ev := g.dispatch("rec_record")
		check(g.flag("P05") and before == ["interval_set", "hatch_opened", "stair_looked"], "recorded (%s)" % [before])
		check(g.value("p05_trace") == before, "p05_trace is the last three moves at RECORD")
		var l4 := R03Sim.LINE4_TURNED if turned else R03Sim.LINE4_STILL
		var strip := r.strip_lines()
		check(strip == ["DEPARTURE OBSERVATION", "Set the interval.", "Opened the hatch.", "Looked down the stair.", l4,
			"COLLECTION ANSWERS. ATTEND JETTY."], "the strip (%s)" % [strip])
		check("'" + l4 + "'" in says(ev), "line 4 is said (turned %s)" % turned)
		check("It's printing what I did: 'Set the interval. Opened the hatch. Looked down the stair.'" in says(ev), "the moves are said")
		check(has_ev(ev, "fx", "strip_print") and sfx_index(ev, "far_bell") >= 0 and sfx_index(ev, "strip_print_last") >= 0, "the strip fx and sounds")
		check(r.has_seen("departure_record") and r.has_seen("relay"), "departure_record and relay")
		var text := r.observation_text("departure_record")
		check(text == "The recorder wrote down the last three things I did, in order: '" + " ".join(strip.slice(1, 4))
			+ "' Then: '" + strip[4] + "'", "observation_text matches the strip")
		check(r.observation_text("relay") == R03Sim.OBSERVATIONS.relay, "other ids are the constants")
		# More moves, re-freeze: unchanged.
		g.dispatch("back")
		g.record_move("held_still")
		g.record_move("turned_round")
		g.freeze_p05_trace()
		check(g.value("p05_trace") == before and r.strip_lines() == strip, "the trace never changes afterwards")
		g.dispatch("recorder")
		for a in ["rec_record", "rec_plate_observer", "rec_slot_0", "rec_shutter"]:
			ev = g.dispatch(a)
			check(says(ev) == R03Sim.RECORDED and not g.value("p05_trace").is_empty(), "%s after P05: recorded" % a)
		check(r.state.slots == ["boundary", "relation", "observer"], "the plates stay after P05")
		# Save and load: identical strip and notebook text.
		var b := GameSim.new()
		check(b.from_dict(g.to_dict()), "loads")
		check(r3(b).strip_lines() == strip and r3(b).observation_text("departure_record") == text,
			"strip and notebook text survive save/load (turned %s)" % turned)
		# Looking behind once, after P05.
		g.dispatch("back")
		r.wall = "B"
		ev = g.dispatch("turn_right")
		var want := "Nothing behind me. Once was enough." if turned else "Nothing behind me. The room's as I left it."
		check(want in says(ev) and r.state.looked_behind, "she looks behind her once (turned %s)" % turned)
		r.wall = "B"
		ev = g.dispatch("turn_left")
		check(not "Nothing behind me" in says(ev), "only once")

func test_p05_shutter() -> void:
	var g := game_at(2, ROOM)
	var r := r3(g)
	g.dispatch("recorder")
	for a in ["rec_shutter", "rec_plate_boundary", "rec_slot_0", "rec_miniature", "rec_record"]:
		var ev := g.dispatch(a)
		check(says(ev) == R03Sim.SHUTTERED, "%s before P04: shuttered" % a)
	check(r.held_plate == "" and r.state.slots == ["", "", ""] and not g.flag("P05"), "nothing moves under the shutter")
	g.dispatch("back")
	var ev := g.dispatch("plate_rack")
	check(r.local_view == "c_recorder" and r.has_seen("plates"), "the plate rack opens the recorder")

# ---------------------------------------------------------------------------
# P21
# ---------------------------------------------------------------------------
func test_p21_matrix() -> void:
	# Every registration: rotation x pin. Only north with the plan's north (one quarter clockwise)
	# and his lighthouse on the plan's registers; everything else says the one line and keeps all.
	for rot in 4:
		for snap in ["", "lighthouse", "buoy", "datum"]:
			var g := stage(6)
			var r := r3(g)
			g.dispatch("plan_wall")
			g.dispatch("plan_lay")
			while int(r.state.plan_rot) != rot:
				g.dispatch("plan_rotate_cw")
			if snap != "":
				g.dispatch("plan_snap_" + snap)
			var items_before: Array = g.state.inventory.duplicate()
			var notes_before := r.seen().size()
			var ev := g.dispatch("plan_clip")
			var tag := "plan %d/%s" % [rot, snap]
			if rot == R03Sim.PLAN_ROT and snap == "lighthouse":
				check(r.state.plan_registered and not g.flag("P21") and r.has_seen("plan_registered"),
					"%s registers (P21 waits for the pin)" % tag)
				check(has_ev(ev, "fx", "plan_register") and has_ev(ev, "sfx", "clip_snap"), "%s: the outline fills" % tag)
			else:
				check(not r.state.plan_registered and says(ev) == R03Sim.PLAN_WRONG, "%s refuses (got '%s')" % [tag, says(ev)])
				check(has_ev(ev, "sfx", "clip_refuse") and not has_ev(ev, "fx", "plan_register"), "%s: clip_refuse" % tag)
				check(r.state.plan_laid and r.state.plan_rot == rot and r.state.plan_snap == snap, "%s: the arrangement stays" % tag)
				check(g.state.inventory == items_before and r.seen().size() == notes_before and not g.flag("P21"),
					"%s: a wrong registration consumes nothing" % tag)
	# The pin: every zone and margin, only the centre chamber completes.
	for z in R03Sim.ZONES + R03Sim.MARGINS:
		var g := stage(6)
		var r := r3(g)
		register_plan(g)
		g.dispatch("plan_pin")
		check(r.held_pin, "%s: the pin is in the hand" % z)
		var ev := g.dispatch(z if z.begins_with("plan_margin") else "plan_zone_" + z)
		if z == "centre":
			check(g.flag("P21") and not r.held_pin, "the pin in the centre chamber solves P21")
		else:
			check(not g.flag("P21") and r.held_pin, "%s: refused, the pin stays in the hand" % z)
			var want: String = R03Sim.PIN_PEOPLE if z.begins_with("plan_margin") else R03Sim.PIN_REFUSE[z]
			check(says(ev) == want, "%s: '%s' (got '%s')" % [z, want, says(ev)])

## Lays, turns, pins and clips his composite on the plan (a stage-6 game).
func register_plan(g: GameSim) -> Array:
	g.dispatch("plan_wall")
	g.dispatch("plan_lay")
	while int(r3(g).state.plan_rot) != R03Sim.PLAN_ROT:
		g.dispatch("plan_rotate_cw")
	g.dispatch("plan_snap_lighthouse")
	return g.dispatch("plan_clip")

func solve_p21(g: GameSim) -> Array:
	register_plan(g)
	g.dispatch("plan_pin")
	return g.dispatch("plan_zone_centre")

func test_p21_actions() -> void:
	var g := stage(6)
	var r := r3(g)
	var ev := g.dispatch("plan_wall")
	check("The lid's screws are out. Someone lined them up on the frame. Nine of them." in says(ev) and r.state.plan_lid_seen, "the lid line")
	g.dispatch("back")
	ev = g.dispatch("plan_wall")
	check(not "screws" in says(ev), "the lid line once")
	for a in ["plan_rotate_cw", "plan_snap_lighthouse", "plan_clip"]:
		ev = g.dispatch(a)
		check(says(ev) == R03Sim.PLAN_NOT_LAID and not r.state.plan_laid, "%s before laying: nothing laid" % a)
	ev = g.dispatch("plan_pin")
	check(says(ev) == R03Sim.PIN_NOT_YET and not r.held_pin, "the pin before registration: not yet")
	ev = g.dispatch("plan_zone_centre")
	check(says(ev) == R03Sim.ZONE_DESC.centre, "an empty hand on a zone describes it")
	ev = g.dispatch("plan_margin_kitchen")
	check(says(ev).begins_with("PERSONAL EVIDENCE"), "the margin without the pin")
	ev = g.dispatch("plan_lay")
	check(r.state.plan_laid and r.state.plan_rot == R03Sim.PLAN_ROT_START and r.state.plan_snap == "", "his composite laid, north up")
	check(has_ev(ev, "sfx", "sheet_slide") and "North up" in says(ev), "laid with a slide")
	g.dispatch("plan_rotate_ccw")
	check(r.state.plan_rot == 3, "turn left from north up")
	g.dispatch("plan_rotate")
	g.dispatch("plan_rotate")
	check(r.state.plan_rot == 1, "plan_rotate turns right")
	g.dispatch("plan_snap_buoy")
	check(r.state.plan_snap == "buoy", "pinned by his buoy")
	ev = g.dispatch("plan_clip")
	check(says(ev) == "The line runs through walls. Not like that.", "the wrong registration line")
	g.dispatch("plan_lift")
	check(not r.state.plan_laid and r.state.plan_snap == "", "lifted: the pin comes out")
	g.dispatch("plan_lay")
	check(r.state.plan_rot == R03Sim.PLAN_ROT_START, "laid again: north up again")
	g.dispatch("plan_rotate_cw")
	g.dispatch("plan_snap_lighthouse")
	check(r.plan_in_register(), "in register")
	# Her own clips, from the inventory, do what the plan's clip does.
	g.dispatch("item:chart_clips")
	ev = g.dispatch("plan_clip")
	check(r.state.plan_registered and g.has_item("chart_clips"), "her clips clip it; she keeps them")
	var lines := says(ev)
	for w in ["lantern gallery", "chart room", "listening room", "laboratory", "office and the vault", "chamber"]:
		check(w in lines, "the registration names '%s'" % w)
	for a in ["plan_rotate_cw", "plan_snap_buoy", "plan_clip", "plan_lift"]:
		ev = g.dispatch(a)
		check(says(ev) == R03Sim.PLAN_CLIPPED and r.plan_in_register(), "%s after the clip: it stays" % a)
	g.dispatch("plan_pin")
	g.dispatch("plan_pin")
	check(not r.held_pin, "the pin goes back to its slot")
	g.dispatch("plan_pin")
	g.dispatch("back")
	check(not r.held_pin and r.state.plan_registered, "Back returns the pin; the registration stays")
	g.dispatch("plan_wall")
	g.dispatch("plan_pin")
	ev = g.dispatch("plan_zone_centre")
	check(g.flag("P21"), "the pin in the chamber by hand solves")

func test_p21_gates_and_outputs() -> void:
	for flags in [[], ["P19"], ["P20"]]:
		var g := game_at(7, ROOM)
		var r := r3(g)
		g.set_flag("P19", "P19" in flags)
		g.set_flag("P20", "P20" in flags)
		var ev := g.dispatch("plan_wall")
		check(not "screws" in says(ev), "%s: no lid line" % [flags])
		for a in ["plan_lay", "plan_rotate_cw", "plan_snap_lighthouse", "plan_clip", "plan_pin"]:
			ev = g.dispatch(a)
			check(says(ev) == R03Sim.PLAN_LID and not r.state.plan_laid and not r.held_pin, "%s %s: screwed down" % [flags, a])
		ev = g.dispatch("plan_zone_centre")
		check(says(ev) == R03Sim.ZONE_DESC.centre, "%s: zones still describe" % [flags])
		check(not g.flag("P21"), "%s: refused before P19 and P20" % [flags])
	# P19 and P20, but no composite in the notebook: nothing of his to lay.
	var g0 := stage(6)
	var r0 := r3(g0)
	g0.state.notebook.erase("R03.composite_chart")
	check(not r0.has_composite(), "the composite is out of the notebook")
	g0.dispatch("plan_wall")
	var ev0 := g0.dispatch("plan_lay")
	check(says(ev0) == R03Sim.PLAN_NO_COMPOSITE and not r0.state.plan_laid, "no composite: nothing to lay")
	var g := stage(6)
	var r := r3(g)
	check(g.tide() == 7 and g.weather_band() == 5, "stage 6 is tide VII, band 5")
	var ev := register_plan(g)
	check(not g.flag("P21") and tide_fx(ev) == 0, "registration alone doesn't close Tide VII")
	g.dispatch("plan_pin")
	ev = g.dispatch("plan_zone_centre")
	check(g.flag("P21") and r.state.p21_complete, "P21 solves")
	check(r.has_seen("station_outline") and r.has_seen("plan_name") and "n_b6" in r.state.notices, "outputs, n_b6 seen")
	check(r.observation_text("station_outline") == R03Sim.OBSERVATIONS.station_outline
		and "Body: lab and listening. Place: chart and lantern. Name: office and vault." in r.observation_text("station_outline"),
		"station_outline reads as P22-P24 expect")
	check(has_ev(ev, "fx", "plan_resolve") and tide_fx(ev) == 1 and g.tide() == 8 and g.weather_band() == 6, "the tide fx, band 6")
	check("ADA MERCER" in says(ev), "her name in the witness frame")
	for a in ["plan_clip", "plan_pin", "plan_lay"]:
		ev = g.dispatch(a)
		check(says(ev) == R03Sim.PLAN_FIXED and tide_fx(ev) == 0, "%s after P21: fixed, no re-solve" % a)
	ev = g.dispatch("plan_zone_centre")
	check(says(ev) == R03Sim.ZONE_DESC.centre and tide_fx(ev) == 0, "a zone after P21 describes")
	g.dispatch("back")
	ev = g.dispatch("plan_wall")
	check(says(ev) == "It's a body, sitting. My name where its heart would be.", "the plan after P21")

# ---------------------------------------------------------------------------
# save / load
# ---------------------------------------------------------------------------
func roundtrip(g: GameSim) -> GameSim:
	var b := GameSim.new()
	check(b.from_dict(JSON.parse_string(JSON.stringify(g.to_dict()))), "a JSON round trip loads")
	return b

func test_save_load() -> void:
	# P03 mid-puzzle.
	var g := laid_game()
	g.dispatch("reg_base_17")
	g.dispatch("reg_rot_cw")
	g.dispatch("reg_snap_buoy")
	var b := roundtrip(g)
	var s: Dictionary = r3(b).state
	check(s.reg_base == "17" and s.reg_laid and s.reg_rot == 3 and s.reg_snap == "buoy", "the registration survives a load")
	check(r3(b).local_view == "room" and r3(b).wall == "A" and b.has_item("venn_tide_sheet"), "lands in the room, wall A")
	# Laid without the sheet (impossible): reconcile lifts it.
	g.take("venn_tide_sheet")
	b = roundtrip(g)
	check(not r3(b).state.reg_laid and r3(b).state.reg_snap == "", "laid without the sheet is lifted")
	# P04 mid-puzzle.
	g = game_at(2, ROOM)
	g.dispatch("recorder")
	g.dispatch("rec_zero_up")
	g.dispatch("rec_calibrate")
	b = roundtrip(g)
	check(r3(b).state.zero == 8 and r3(b).state.interval == 2 and r3(b).state.gauges == ["mismatch", "mismatch"]
		and r3(b).state.pull_misses == 1, "the wheels and gauges survive")
	# P05 mid-puzzle: the hand clears, plates kept.
	g = record_game()
	var r := r3(g)
	place(g, ["relation", "", ""])
	g.dispatch("rec_plate_observer")
	g.dispatch("rec_record")
	check(r.held_plate == "observer", "holding a plate")
	g.from_dict(g.to_dict())
	check(r.held_plate == "" and r.state.slots == ["relation", "", ""] and r.state.record_refusal == R03Sim.REFUSE_INCOMPLETE,
		"slots and refusal kept, hand cleared (%s)" % [r.state.slots])
	check(r.rack_plates() == ["observer", "boundary", ""], "the held plate is back on the rack")
	# P21 mid-puzzle.
	g = stage(6)
	r = r3(g)
	g.dispatch("plan_wall")
	g.dispatch("plan_wall")
	g.dispatch("plan_lay")
	g.dispatch("plan_rotate_ccw")
	g.dispatch("plan_snap_datum")
	g.from_dict(g.to_dict())
	check(r.state.plan_laid and r.state.plan_rot == 3 and r.state.plan_snap == "datum" and not r.state.plan_registered,
		"his composite on the plan survives a load")
	g = stage(6)
	r = r3(g)
	register_plan(g)
	g.dispatch("plan_pin")
	g.from_dict(g.to_dict())
	check(r.state.plan_registered and r.plan_in_register() and not r.held_pin and not g.flag("P21"),
		"registered survives, the pin is back in its slot")
	g.state.notebook.erase("R03.composite_chart")
	g.from_dict(g.to_dict())
	check(not r.state.plan_laid and not r.state.plan_registered and r.state.plan_snap == "",
		"laid without the composite in the notebook (impossible) is lifted")
	# Malformed, field by field.
	g = stage(0)
	var d := g.to_dict()
	d.rooms.R03 = {
		"clips_taken": "yes", "reg_laid": 1, "reg_base": "15", "reg_rot": 2.5, "reg_snap": "moon",
		"zero": 12, "interval": -1, "gauges": ["ok", "bad"], "pull_misses": 1.5, "clip_misses": -2,
		"record_misses": 3, "slots": ["boundary", "boundary", "x"], "record_refusal": "NO",
		"plan_laid": "yes", "plan_rot": 7, "plan_snap": "moon", "plan_registered": 1,
		"notices": ["n_b3", "zzz"], "prophecy_seen": true,
	}
	b = GameSim.new()
	b.from_dict(d)
	s = r3(b).state
	check(not s.clips_taken and not s.reg_laid and s.reg_base == "14" and s.reg_rot == 2 and s.reg_snap == "", "bad P03 fields rejected")
	check(s.zero == 7 and s.interval == 2 and s.gauges == ["ok", ""] and s.pull_misses == 0 and s.clip_misses == 0, "bad P04 fields rejected")
	check(s.record_misses == 3 and s.prophecy_seen, "good fields kept")
	check(s.slots == ["boundary", "", ""] and s.record_refusal == "", "duplicate and unknown plates dropped")
	check(not s.plan_laid and s.plan_rot == R03Sim.PLAN_ROT_START and s.plan_snap == "" and not s.plan_registered,
		"bad P21 fields rejected")
	check(s.notices == ["n_b3"], "lists filtered to known ids")
	d.rooms.R03 = {"plan_snap": "buoy", "plan_rot": 2, "reg_snap": "buoy"}
	b.from_dict(d)
	check(r3(b).state.plan_snap == "" and r3(b).state.plan_rot == 2 and r3(b).state.reg_snap == "",
		"no pin without a laid sheet, on the table or the plan")
	d.rooms.R03 = {"plan_tiles": {"body": "lab", "place": "chart", "name": "office", "witness": "centre"}}
	b.from_dict(d)
	check(not r3(b).state.has("plan_tiles") and not r3(b).state.p21_complete, "an old tile layout is ignored")
	d.rooms.R03 = "junk"
	check(b.from_dict(d) and r3(b).state == r3(b).initial_state(), "a non-dict room state is fresh")
	# Derived fixes.
	d.rooms.R03 = {"p03_complete": true, "p04_complete": true, "p05_complete": true, "p21_complete": true,
		"reg_base": "14", "zero": 1, "slots": ["", "", ""], "plan_rot": 3}
	b.from_dict(d)
	check(not r3(b).state.p03_complete and not b.flag("P03") and not r3(b).state.p21_complete,
		"a completion the save's flags don't carry is not restored")
	for p in ["P03", "P04", "P05", "P21"]:
		d.flags[p] = true
	b.from_dict(d)
	s = r3(b).state
	check(s.clips_taken and s.reg_base == "17" and s.reg_laid and s.reg_rot == 0 and s.reg_snap == "lighthouse", "p03 derives the composite")
	check(s.zero == 4 and s.interval == 3 and s.gauges == ["ok", "ok"], "p04 derives the calibration")
	check(s.slots == R03Sim.PLATES and s.plan_registered and s.plan_laid and s.plan_rot == R03Sim.PLAN_ROT
		and s.plan_snap == R03Sim.PLAN_SNAP, "p05 / p21 derive")
	check(b.flag("P03") and b.flag("P04") and b.flag("P05") and b.flag("P21"), "and set their flags")
	check(b.value("p05_trace").size() <= 3, "a trace is frozen for a loaded P05")

## The notices keep the order she met them in, through a save, not NOTICES' order.
func test_notice_order_survives() -> void:
	var g := stage(6)
	check(g.flag("P19"), "stage 6 is after P19")
	var r := r3(g)
	solve_p21(g)
	g.dispatch("back")
	check(g.flag("P21") and "n_b6" in r.state.notices, "P21 solved, n_b6 met")
	var b := roundtrip(g)
	# stage() sets other rooms' flags without deriving their state, so R03's dict is compared here
	# and the whole save from the first load on.
	check(JSON.stringify(b.to_dict().rooms.R03) == JSON.stringify(g.to_dict().rooms.R03),
		"a save after P19/P21 loads to the identical R03 dict")
	check(JSON.stringify(roundtrip(b).to_dict()) == JSON.stringify(b.to_dict()), "and the whole save is a fixed point")
	check(r3(b).state.notices == r.state.notices, "notice order kept (%s)" % [r3(b).state.notices])
	# An order unlike NOTICES' own survives, with junk, doubles and non-strings dropped in place.
	var d := g.to_dict()
	var met: Array = r.state.notices.duplicate()
	met.reverse()
	var dirty: Array = met.duplicate()
	dirty.insert(1, "zzz")
	dirty.insert(2, 7)
	dirty.append(met[0])
	d.rooms.R03.notices = dirty
	b = GameSim.new()
	check(b.from_dict(JSON.parse_string(JSON.stringify(d))), "the reordered save loads")
	check(r3(b).state.notices == met, "reversed order kept, junk dropped (%s vs %s)" % [r3(b).state.notices, met])

func test_reconcile_keeps_flags() -> void:
	var g := with_flags(["P01", "P03", "P04", "P05", "P21"], ROOM)
	var r := r3(g)
	r.reconcile()
	for p in ["P03", "P04", "P05", "P21"]:
		check(g.flag(p), "reconcile keeps %s" % p)
	check(r.state.p03_complete and r.state.p04_complete and r.state.p05_complete and r.state.p21_complete, "and mirrors them")
	g = with_flags(["P01"], ROOM)
	r = r3(g)
	r.state.p04_complete = true
	r.reconcile()
	check(g.flag("P04") and not g.flag("P03"), "state sets its own flag only")

# ---------------------------------------------------------------------------
# notices
# ---------------------------------------------------------------------------
func test_notices() -> void:
	# First arrival (tide I).
	var g := stage(0)
	var r := r3(g)
	var ev: Array = []
	r.arrive(ev, true)
	check(r.wall == "B" and notice_fx(ev) == ["n_arrival"], "the first arrival faces B")
	check(count_says(ev, R03Sim.ARRIVAL) == 1 and r.has_seen("recorder"), "the arrival line once, recorder noted")
	ev = []
	r.arrive(ev, false)
	check(notice_fx(ev).is_empty() and r.wall == "A", "nothing pending: wall A")
	# The threshold arrival.
	g = game_at(2)
	r = r3(g)
	ev = g.dispatch("go:R03")
	check(g.state.room == ROOM, "walked in at tide II")
	check(r.wall == "B" and notice_fx(ev) == ["n_threshold"] and r.has_seen("seal_broken"), "the threshold arrival faces B")
	check("n_arrival" in r.state.notices and r.has_seen("recorder"), "the superseded arrival notice keeps its evidence")
	check("from inside." in says(ev), "the threshold line")
	# Tide II: after the seal, the window. Story, once, after the seal line.
	check(r.sea_low() and count_says(ev, R03Sim.LAMP_OUT_LINE) == 1, "the lighthouse is out (story line)")
	var lines: Array = ev.filter(func(e): return e.type == "say")
	var i_seal := -1
	var i_lamp := -1
	for i in lines.size():
		if "from inside." in lines[i].text: i_seal = i
		if lines[i].text == R03Sim.LAMP_OUT_LINE: i_lamp = i
	check(i_seal >= 0 and i_lamp > i_seal and lines[i_lamp].story and lines[i_seal].story
		and lines[i_lamp].delay > lines[i_seal].delay, "the lamp line follows the seal line in one chain")
	check(r.state.lamp_out_said and r.has_seen("sea_low"), "said once, sea_low noted")
	ev = g.dispatch("sea_window")
	check("lighthouse is out" in says(ev), "the window at tide II: the lighthouse is out")
	g.dispatch("go:R02")
	ev = g.dispatch("go:R03")
	check(count_says(ev, R03Sim.LAMP_OUT_LINE) == 0, "the lamp line plays once")
	check(roundtrip(g).room(ROOM).state.lamp_out_said, "lamp_out_said saves")
	# After P04, Back from the recorder faces C.
	g.dispatch("recorder")
	r.state.zero = 4; r.state.interval = 3
	g.dispatch("rec_calibrate")
	ev = g.dispatch("back")
	check(r.wall == "C" and notice_fx(ev) == ["n_p04"] and "Air in the hatch." in says(ev), "after P04, Back turns to wall C")
	ev = g.dispatch("turn_left")
	check(r.wall == "B" and notice_fx(ev).is_empty(), "nothing more on B")
	# Tide IX: C first, A for the turn.
	g = game_at(9)
	r = r3(g)
	ev = g.dispatch("go:R03")
	check(g.state.room == ROOM and r.wall == "C" and notice_fx(ev) == ["n_b7"], "tide IX arrives facing C (%s)" % [notice_fx(ev)])
	check(r.has_seen("water_standing") and "n_p04" in r.state.notices and r.has_seen("stair_threshold"), "n_p04 superseded, evidence kept")
	check(r.pending_notice("A") == "n_b6" and r.pending_notice("B") == "n_b5", "A and B still pending")
	check("n_b3" in r.state.notices and r.has_seen("vis_nil") and r.has_seen("seal_broken"), "older B notices superseded with evidence")
	check(r.has_seen("compass_bent") and r.has_seen("standing"), "older A notices superseded with evidence")
	ev = g.dispatch("turn_right")
	check(r.wall == "A" and notice_fx(ev) == ["n_b6"], "turning to A plays n_b6")
	ev = g.dispatch("turn_right")
	check(r.wall == "B" and notice_fx(ev) == ["n_b5"] and r.has_seen("attending"), "then B plays n_b5")
	# Each plays once.
	for a in ["turn_right", "turn_right", "turn_right", "sheet_table", "back", "recorder", "back"]:
		ev = g.dispatch(a)
		check(notice_fx(ev).is_empty(), "no notice replays (%s)" % a)
	g.dispatch("go:R02")
	ev = g.dispatch("go:R03")
	check(notice_fx(ev).is_empty() and r.wall == "A", "a later visit faces A with nothing new")
	# A notice survives a load as seen.
	var b := roundtrip(g)
	check(r3(b).state.notices.size() == r.state.notices.size() and r3(b).pending_notice("C") == "", "notices saved")

## Tide II on arrival: the sea is low and the lamp out only after the threshold, until tide II is done.
func test_sea_low_and_knot() -> void:
	var g := stage(0)
	var r := r3(g)
	check(not r.sea_low(), "before the threshold the sea is ordinary")
	check(r.solved_count() == 1 and is_equal_approx(r.ink_knot_radius(), 10.0), "P01 alone: a 10 px knot")
	var g2 := game_at(2)
	check(r3(g2).sea_low(), "tide II start: the sea is low")
	var g3 := game_at(3)
	check(not r3(g3).sea_low(), "tide III: the weather moves on")
	var g0 := with_flags([])
	check(r3(g0).solved_count() == 0 and is_equal_approx(r3(g0).ink_knot_radius(), 6.0), "nothing solved: 6 px")
	var all := []
	for i in range(1, 28):
		all.append("P%02d" % i)
	check(is_equal_approx(r3(with_flags(all)).ink_knot_radius(), 60.0), "the knot is capped at 60 px")
	var prev := 0.0
	for n in range(0, 20):
		var rad := minf(60.0, 6.0 + 4.0 * n)
		var pts: PackedVector2Array = _knot(rad, n)
		var far := 0.0
		for p in pts:
			far = maxf(far, p.length())
		check(far <= rad + 0.001, "knot %d stays within %.0f px" % [n, rad])
		check(pts.size() >= prev, "the knot never thins (%d)" % n)
		prev = pts.size()
	check(_knot(20.0, 3) == _knot(20.0, 3), "the knot is deterministic")
	var small := _knot(10.0, 1)
	var big := _knot(30.0, 6)
	var grows := true
	for i in small.size():
		grows = grows and (small[i] * 3.0).distance_to(big[i]) < 0.01
	check(grows, "a bigger knot is the same knot, grown: it never redraws")

func _knot(radius: float, solved: int) -> PackedVector2Array:
	return VIEW_SCRIPT.knot_points(radius, solved)

func test_stair_looked() -> void:
	for first in ["hatch", "outer_window"]:
		var g := stage(4)
		var r := r3(g)
		var ev := g.dispatch(first)
		check(r.state.stair_looked and g.value("movement_events").back() == "stair_looked", "%s records stair_looked" % first)
		g.record_move("held_still")
		g.dispatch("hatch")
		g.dispatch("outer_window")
		check(g.value("movement_events").count("stair_looked") == 1, "%s: stair_looked once" % first)
	var g := stage(3)
	g.dispatch("hatch")
	g.dispatch("outer_window")
	check(not r3(g).state.stair_looked and not "stair_looked" in g.value("movement_events"), "no stair before P04")
	var ev := g.dispatch("hatch")
	check(says(ev).begins_with("The observation hatch. Iron"), "the shut hatch")
	g = stage(4)
	g.dispatch("hatch")
	ev = g.dispatch("hatch")
	check(says(ev) == "The stair goes down. The hatch tab will take me." and g.state.room == ROOM, "the hatch never travels")

# ---------------------------------------------------------------------------
# items, objectives, debug
# ---------------------------------------------------------------------------
func use(g: GameSim, item: String, target: String) -> Array:
	g.give(item)
	g.dispatch("item:" + item)
	return g.dispatch(target)

func test_items() -> void:
	var g := stage(4)
	var r := r3(g)
	var cases := {
		["inspection_lens", "outer_window"]: "Through the lens there's no glass in the frame. Just water, standing in it.",
		["inspection_lens", "pen_drum"]: "The nib is wet. Salt dries white along the line it writes.",
		["inspection_lens", "hatch_scratches"]: "Cut from the stair side. The burr curls toward this room.",
		["inspection_lens", "sheet_table"]: "Every cross is pricked through with a pin. Many times.",
		["inspection_lens", "compass"]: "The needle is steady. It isn't the compass.",
		["pencil", "sheet_table"]: "I don't amend his charts.",
		["chart_clips", "sheet_table"]: "The clips go on the rail, once the sheets are in register.",
	}
	for k in cases:
		var inv: Array = g.state.inventory.duplicate()
		var ev := use(g, k[0], k[1])
		check(says(ev) == cases[k], "%s on %s" % k)
		check(r.wall == R03Sim.WALL_OF[k[1]], "%s on %s faces its wall" % k)
		check(g.has_item(k[0]), "%s is not consumed" % k[0])
	check(r.has_seen("lens_window"), "lens_window")
	var ev := use(g, "pencil", "hatch")
	check(says(ev) == GameSim.GENERIC_WRONG_USE and g.has_item("pencil"), "other uses: the generic refusal")
	ev = use(g, "inspection_lens", "seal")
	check(says(ev) == GameSim.GENERIC_WRONG_USE and g.has_item("inspection_lens"), "lens elsewhere: generic")
	# From inside a close-up, the lens on a wall object leaves it.
	g.dispatch("recorder")
	ev = use(g, "inspection_lens", "compass")
	check(r.local_view == "room" and r.wall == "A", "a wall use leaves the close-up")

func test_objectives() -> void:
	var expect := {0: "sheet_missing", 1: "register", 2: "office", 3: "calibrate", 4: "record", 5: "away", 6: "plan", 7: "done", 8: "done"}
	for n in expect:
		var g := stage(n)
		check(r3(g).objective() == expect[n], "stage %d objective %s (got %s)" % [n, expect[n], r3(g).objective()])
		var tiers := 4 if expect[n] in ["register", "calibrate", "record", "plan"] else 3
		check(r3(g).objective_text() != "" and R03Sim.HINTS[expect[n]].size() == tiers and r3(g).hint_tiers() == tiers,
			"stage %d: text and %d hints" % [n, tiers])
	var g := with_flags(["P01", "P03"], ROOM)
	check(r3(g).objective() == "zero", "P03 without P02: zero")
	g = with_flags(["P01", "P02", "P03", "t1x_threshold_crossed", "P04", "P05"], ROOM)
	check(r3(g).objective() == "jetty", "after P05: the jetty")
	check(r3(g).hint_line(2) == "Go out to the jetty through the office.", "hint ladder")
	for k in R03Sim.HINTS:
		check(R03Sim.OBJECTIVES.has(k), "objective %s has text" % k)
	check(R03Sim.HINTS.sheet_missing[2].begins_with("Drawer: 1-8-5-2."), "the P03 card ladder")

## Round p1: P04, P05 and P21 gain an evidence tier between the relationship and the answer
## (round p3 rewrote P21's ladder for the composite overlay and gave P03's register one too).
func test_round_p1_hints() -> void:
	var cases := {3: ["calibrate", R03Sim.EVIDENCE_CALIBRATE], 4: ["record", R03Sim.EVIDENCE_RECORD],
		6: ["plan", R03Sim.EVIDENCE_PLAN]}
	var cards := {
		"calibrate": ["The recorder in the chart room has two wheels and a lever.",
			"One wheel takes the recording's zero, the other the chart's interval.",
			"Set ZERO to 4 and INTERVAL to 3, then pull CALIBRATE."],
		"record": ["The recorder's other panel takes three plates.",
			"The hatch frame is carved. Read it the way you'd meet it going down.",
			"Slots left to right: BOUNDARY, RELATION, OBSERVER. Press RECORD."],
		"plan": ["The station plan on the chart wall. Its lid is open now.",
			"His chart and the plan share a cross.",
			R03Sim.PLAN_ANSWER_HINT],
	}
	for n in cases:
		var o: String = cases[n][0]
		var evidence: String = cases[n][1]
		var r := r3(stage(n))
		check(r.objective() == o and r.hint_tiers() == 4, "p1: %s has four tiers" % o)
		var card: Array = cards[o]
		check(r.hint_line(0) == card[0] and r.hint_line(1) == card[1], "p1: %s keeps the card's first two tiers" % o)
		check(r.hint_line(2) == evidence, "p1: %s evidence is tier 3" % o)
		check(r.hint_line(3) == card[2] and r.hint_line(9) == card[2], "p1: %s still ends on the card's answer" % o)
		var keys := {}
		for i in 4:
			keys[GameSim._hint_key(r.hint_line(i))] = true
		check(keys.size() == 4, "p1: %s tiers are all different lines" % o)
	# The evidence names what she has seen, never the answer itself.
	for w in ["4", "3", "ZERO", "INTERVAL", "CALIBRATE"]:
		check(not w in R03Sim.EVIDENCE_CALIBRATE, "p1: calibrate evidence doesn't say %s" % w)
	check("recording" in R03Sim.EVIDENCE_CALIBRATE and "band" in R03Sim.EVIDENCE_CALIBRATE, "p1: calibrate evidence points at both sources")
	check(R03Sim.EVIDENCE_RECORD.begins_with("The recorder printed what you actually did."), "p1: the recorder printed it")
	for w in ["BOUNDARY", "RELATION", "OBSERVER", "RECORD."]:
		check(not w in R03Sim.EVIDENCE_RECORD, "p1: record evidence doesn't say %s" % w)
	check("bracket" in R03Sim.EVIDENCE_RECORD and "circle" in R03Sim.EVIDENCE_RECORD, "p1: record evidence reads the hatch marks")
	for w in ["WITNESS", "lantern", "chamber", "centre", "clip", "turn", "right", "pin"]:
		check(not w in R03Sim.EVIDENCE_PLAN, "p3: plan evidence doesn't say %s" % w)
	check("composite chart" in R03Sim.EVIDENCE_PLAN and "notebook" in R03Sim.EVIDENCE_PLAN, "p3: plan evidence is the composite in the notebook")
	# Every other ladder keeps three tiers.
	for o in R03Sim.HINTS:
		var want := 4 if o in ["register", "calibrate", "record", "plan"] else 3
		check(R03Sim.HINTS[o].size() == want, "p1: %s has %d tiers" % [o, want])
	for n in [0, 2, 5, 7]:
		check(r3(stage(n)).hint_tiers() == 3, "p1: stage %d has three tiers" % n)
	# Dispatched in play: nudge, relationship, evidence, the core's confirmation, answer, then the answer again. Asking
	# changes nothing in the room. The core walks all four tiers; hint_line has no bridge.
	for n in cases:
		var o: String = cases[n][0]
		var g := stage(n)
		g.state.room = ROOM
		g.view = "room"
		check(g.work_elsewhere() == "", "p1: %s is work here" % o)
		var before := JSON.stringify(g.to_dict().rooms.R03)
		var want: Array = [cards[o][0], cards[o][1], cases[n][1], GameSim.HINT_CONFIRM, cards[o][2], cards[o][2]]
		for i in want.size():
			var got := says(g.dispatch("hint"))
			check(got == want[i], "p1: %s hint %d dispatched (%s)" % [o, i, got])
		check(JSON.stringify(g.to_dict().rooms.R03) == before, "p1: %s hints change no room state" % o)
	# hint_line is a pure function of level: a stored core level (any room's) never shifts a tier.
	for n in cases:
		var o: String = cases[n][0]
		var g := stage(n)
		g.state.hint = {"for": "R03:" + o, "level": 3}
		check(r3(g).hint_line(2) == cases[n][1], "p2: %s tier 3 stays the evidence at a stored level 3" % o)
		g.state.hint = {"for": "R02:->R03", "level": 3}
		check(r3(g).hint_line(2) == cases[n][1], "p2: %s tier 3 ignores another room's stored level" % o)

## Round p3: P03's register ladder gains an evidence tier (index 2) before the solution; P21's
## ladder is location, the shared cross, the composite in the notebook, the solution.
func test_round_p3_hints() -> void:
	var r := r3(stage(1))
	check(r.objective() == "register" and r.hint_tiers() == 4, "p3: register has four tiers")
	check(r.hint_line(2) == "The table has two sheets for the 17th. His sheet's north arrow is pointing somewhere else.",
		"p3: P03 tier 2 is the evidence line")
	check(r.hint_line(3).begins_with("Choose the 17 Oct table sheet") and r.hint_line(9) == r.hint_line(3),
		"p3: P03 tier 3 is still the solution")
	check(r.hint_line(2) != r.hint_line(3) and r.hint_line(2) != r.hint_line(1), "p3: P03 tier 2 differs from tiers 1 and 3")
	var keys := {}
	for i in 4:
		keys[GameSim._hint_key(r.hint_line(i))] = true
	check(keys.size() == 4, "p3: P03's four tiers are different lines")
	check(R03Sim.HINTS.sheet_missing.size() == 3, "p3: the missing-sheet ladder keeps three tiers")
	var g := stage(1)
	g.state.room = ROOM
	g.view = "room"
	var want: Array = [R03Sim.HINTS.register[0], R03Sim.HINTS.register[1], R03Sim.EVIDENCE_REGISTER,
		GameSim.HINT_CONFIRM, R03Sim.HINTS.register[3]]
	for i in want.size():
		var got := says(g.dispatch("hint"))
		check(got == want[i], "p3: register hint %d dispatched (%s)" % [i, got])
	var p := r3(stage(6))
	check(p.objective() == "plan" and p.hint_tiers() == 4, "p3: plan has four tiers")
	check("station plan" in p.hint_line(0), "p3: plan tier 0 is the location")
	check(p.hint_line(1) == "His chart and the plan share a cross.", "p3: plan tier 1")
	check(p.hint_line(2) == R03Sim.EVIDENCE_PLAN, "p3: plan tier 2 is the evidence")
	for w in ["composite", "north", "lighthouse cross", "lantern gallery", "clip", "WITNESS", "centre chamber"]:
		check(w in p.hint_line(3), "p3: the plan solution says '%s'" % w)
	for w in ["BODY", "PLACE", "NAME", "FIX", "tile"]:
		for i in 4:
			check(not w in p.hint_line(i), "p3: plan tier %d no longer says %s" % [i, w])

## Round p3: the overlay is painted where the registered line crosses (sampled from the PNG).
func test_round_p3_overlay() -> void:
	var m: Dictionary = (VIEW_SCRIPT as Script).get_script_constant_map()
	check(m.PLAN_BODY_FILE == "res://assets/stages/R03/p21_body_overlay.png", "p3: the outline is a stage overlay")
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(m.PLAN_BODY_FILE))
	check(err == OK and img.get_width() == 1448 and img.get_height() == 1086, "p3: the overlay is a native 1448x1086 PNG")
	if err != OK:
		return
	var rooms := {}
	for rm in m.PLAN_ROOMS:
		rooms[rm[0]] = rm[1]
	for n in m.PLAN_CROSSED:
		var c: Vector2 = rooms[n].get_center()
		check(img.get_pixelv(Vector2i(c)).a > 0.5, "p3: %s fills with the outline" % n)
	for n in m.PLAN_OUTSIDE:
		var r: Rect2 = rooms[n]
		for p in [r.get_center(), r.position + Vector2(8, 8), r.end - Vector2(8, 8)]:
			check(img.get_pixelv(Vector2i(p)).a < 0.02, "p3: %s lies outside the outline at %s" % [n, p])
	check(img.get_pixelv(Vector2i(m.PLAN_CHAMBER.get_center())).a < 0.05, "p3: the witness chamber stays hollow")
	for n in ["KITCHEN & MESS", "BUNK ROOM", "JETTY", "MACHINE ROOM"]:
		check(img.get_pixelv(Vector2i(rooms[n].get_center())).a < 0.02, "p3: %s is not part of the outline" % n)
	# Contour: navy ink somewhere round the head (a ring of opaque dark pixels above the lantern).
	var top := img.get_pixel(790, 153)
	check(top.a > 0.8 and top.r < 0.25 and top.b < 0.3, "p3: the outline has a flat navy contour (%s)" % [top])
	var fill := img.get_pixel(880, 560)
	check(fill.a > 0.4 and fill.g > fill.r, "p3: the fill is matte sea-glass (%s)" % [fill])

## The PLAN_ROOMS names the composite's curve passes through where it lies now (2 px samples).
func _curve_rooms(v) -> Array:
	var pts: PackedVector2Array = v.plan_curve_points()
	var out := []
	for i in pts.size() - 1:
		var n := int(ceil(pts[i].distance_to(pts[i + 1]) / 2.0))
		for k in n + 1:
			var p := pts[i].lerp(pts[i + 1], float(k) / maxf(1.0, n))
			for rm in v.PLAN_ROOMS:
				if rm[1].has_point(p) and not rm[0] in out:
					out.append(rm[0])
	return out

## Round p2: from Tide II the lighthouse is out, one sprite R01 can reuse.
func test_round_p2_lighthouse_out() -> void:
	var m: Dictionary = (VIEW_SCRIPT as Script).get_script_constant_map()
	check(m.LIGHTHOUSE_OUT_FILE == "res://assets/stages/R03/lighthouse_out_r3.png", "p2: the overlay is published")
	check(m.LIGHTHOUSE_OUT_RECT == Rect2(287, 295, 26, 58) and m.LIGHTHOUSE_OUT_FOOT == Vector2(13, 55),
		"p2: the overlay rect and foot are published")
	# Before the threshold nothing is out; after it, every band whose window shows a tower covers it.
	for b in 8:
		check(VIEW_SCRIPT.lighthouse_out_placement(b, false).is_empty(), "p2: band %d lit or absent before Tide II" % b)
		var at: Array = VIEW_SCRIPT.lighthouse_out_placement(b, true)
		check(at.is_empty() == (not b in [0, 1, 2, 6]), "p2: band %d %s the dead tower" % [b, "draws" if not at.is_empty() else "has no"])
	for b in [0, 1, 2]:
		var at: Array = VIEW_SCRIPT.lighthouse_out_placement(b, true)
		check(at[0] == Vector2(300, 350) and at[1] == 0.0 and at[2] == 1.0 and at[3] >= 0.85,
			"p2: band %d stands the dead tower on the plate's" % b)
		check(Rect2(at[0] - m.LIGHTHOUSE_OUT_FOOT, m.LIGHTHOUSE_OUT_RECT.size) == m.LIGHTHOUSE_OUT_RECT,
			"p2: band %d draws at the published rect" % b)
	var b6: Array = VIEW_SCRIPT.lighthouse_out_placement(6, true)
	check(b6[0] == Vector2(196, 250) and b6[1] == 30.0 and is_equal_approx(b6[2], 46.0 / 30.0), "p2: band 6 covers the leaning tower")
	# The painted sprite: 4x the rect, black lamp room, brass rail, navy tower, no amber, no glow.
	var img := Image.load_from_file(ProjectSettings.globalize_path(m.LIGHTHOUSE_OUT_FILE))
	check(img != null and img.get_size() == Vector2i(104, 232), "p2: the sprite is 104x232")
	if img == null:
		return
	var amber := 0
	var outside := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.r > 0.6 and c.g > 0.45 and c.b < 0.4 and c.r - c.b > 0.4 and (y > 104 or (y > 40 and y < 70 and x > 32 and x < 72)):
				amber += 1
			if c.a > 0.05 and (y < 2 or y > 229 or x < 2 or x > 101):
				outside += 1
	check(amber == 0, "p2: no amber in the lamp room or on the tower")
	check(outside == 0, "p2: no glow bleeds to the sprite's edge")
	for p in [Vector2i(52, 64), Vector2i(40, 64), Vector2i(64, 64)]:
		var c := img.get_pixel(p.x, p.y)
		check(c.a > 0.99 and c.get_luminance() < 0.08, "p2: the lamp room is empty and black at %s" % p)
	var tower := img.get_pixel(52, 150)
	check(tower.a > 0.99 and tower.b > tower.r and tower.get_luminance() < 0.2, "p2: the tower is flat storm navy")
	var rail := 0
	for x in range(16, 88):
		var c := img.get_pixel(x, 74)
		if c.r > c.b + 0.2:
			rail += 1
	check(rail > 40, "p2: the gallery rail stays visible in brass")

## Round p2: plate words fit inside their brass plates (10 px floor, then an ellipsis).
func test_round_p2_plate_words() -> void:
	var f: Font = VIEW_SCRIPT.narrow()
	var pad: float = VIEW_SCRIPT.PLATE_WORD_PAD
	# Wall slots, rack homes, the close-up sprite (130 grown by -14) at their call sizes.
	for spec in [[70.0, 16], [74.0, 16], [102.0, 20]]:
		var room: float = spec[0] - 2.0 * pad
		for word in VIEW_SCRIPT.PLATE_WORDS.values():
			var fit: Array = VIEW_SCRIPT.fit_plate_word(f, word, spec[1], room)
			var w := f.get_string_size(fit[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fit[1]).x
			check(w <= room and fit[1] >= 10, "p2: %s fits a %d px plate (%d px at %d)" % [word, spec[0], w, fit[1]])
			check(fit[0] == word or (fit[1] == 10 and fit[0].ends_with("…")), "p2: %s shrinks before it ellipsizes" % word)
	# Too narrow even at 10 px: the word ends in an ellipsis and still fits.
	var tight: Array = VIEW_SCRIPT.fit_plate_word(f, "OBSERVER", 16, 30.0)
	check(tight[1] == 10 and tight[0].ends_with("…") and tight[0].begins_with("O"), "p2: tight plate ellipsizes (%s)" % tight[0])
	check(f.get_string_size(tight[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= 30.0, "p2: the ellipsized word fits")
	# Roomy plates keep the asked size.
	check(VIEW_SCRIPT.fit_plate_word(f, "OBSERVER", 16, 400.0) == ["OBSERVER", 16], "p2: a roomy plate keeps 16 px")

func test_debug_jumps() -> void:
	for n in 9:
		var g := stage(n)
		var r := r3(g)
		check(g.state.room == ROOM and r.local_view == "room" and r.wall == "A" and g.view == "room", "stage %d: in the room" % n)
		for pair in R03Sim.OWNED:
			check(g.flag(pair[0]) == r.state[pair[1]], "stage %d: %s agrees with its state" % [n, pair[0]])
		check(g.flag("P01"), "stage %d: the lamp is mended" % n)
		var b := roundtrip(g)
		check(r3(b).state == r.state, "stage %d: state survives save/load" % n)
		match n:
			0: check(not g.flag("P03") and not g.has_item("venn_tide_sheet"), "stage 0: P01 only")
			1: check(g.has_item("venn_tide_sheet") and g.has_item("inspection_lens") and g.has_item("chart_clips"), "stage 1: P03 ready")
			2: check(g.flag("P02") and g.flag("P03") and not g.flag("t1x_threshold_crossed") and g.has_item("chart_clips"), "stage 2: before the threshold")
			3: check(g.tide() == 2 and not g.flag("P04"), "stage 3: P04 ready")
			4: check(g.flag("P04") and not g.flag("P05") and g.exit_open(ROOM, "R11"), "stage 4: P05 ready")
			5: check(g.tide() == 3 and g.flag("P05") and g.value("p05_trace").size() == 3, "stage 5: tide III with a trace")
			6: check(g.tide() == 7 and r.plan_unlocked() and not g.flag("P21"), "stage 6: P21 ready")
			7: check(g.tide() == 8 and g.flag("P21") and r.state.plan_registered and r.plan_in_register(), "stage 7: tide VIII")
			8: check(g.tide() == 9 and g.weather_band() == 7, "stage 8: tide IX")
		var pending := 0
		for w in R03Sim.WALLS:
			if r.pending_notice(w) != "": pending += 1
		check(n == 0 or pending >= 1, "stage %d: notices left for the arrival" % n)
	# The view's helpers follow the bands.
	check(r3(stage(2)).pen_text() == "" and r3(stage(3)).pen_text() == "10 · 2 · 19:34 · 9.9", "pen: nothing, then her report")
	check(r3(stage(5)).pen_text() == "" and r3(stage(5)).drum_turning(), "pen: the tide line, drum turning")
	check(r3(stage(8)).pen_text() == "SEA STATE: ATTENDING" and not r3(stage(8)).drum_turning(), "pen: attending, drum still")
	var g := game_at(5, ROOM)
	check(g.weather_band() == 3 and r3(g).pen_text() == "VIS 0.0 NM", "band 3: VIS 0.0 NM")

# ---------------------------------------------------------------------------
# geometry (the view's rects for walls B and C, and the turn arrows)
# ---------------------------------------------------------------------------
func _rect_list(v: Variant) -> Array:
	var out := []
	if v is Dictionary:
		for k in v:
			out.append([k, v[k]])
	elif v is Array:
		for e in v:
			out.append([e[0], e[1]])
	return out

func _zone_ok(tag: String, r: Rect2) -> void:
	check(CANVAS.encloses(r), "%s is on the canvas" % tag)
	check(r.size.x >= MIN_TARGET and r.size.y >= MIN_TARGET, "%s is at least 64x64" % tag)
	check(not r.intersects(HUD_ZONE) and not r.intersects(SUBTITLE_ZONE) and not r.intersects(INVENTORY_ZONE),
		"%s keeps clear of the HUD, inventory and subtitles" % tag)

func test_geometry() -> void:
	var m: Dictionary = load("res://game/rooms/R03/R03_view.gd").get_script_constant_map()
	var walls = m.get("WALL_HOTSPOTS", null)
	var turns = m.get("TURN_RECTS", null)
	var exits: Dictionary = m.get("EXIT_RECTS", {})
	check(walls is Dictionary, "R03 view declares WALL_HOTSPOTS {wall: [[id, Rect2, label]]}")
	check(turns != null, "R03 view declares TURN_RECTS")
	if not walls is Dictionary or turns == null:
		return
	var all := {"A": _rect_list(m.get("HOTSPOTS", []))}
	for w in ["B", "C"]:
		all[w] = _rect_list(walls.get(w, []))
	for w in R03Sim.WALLS:
		var ids := []
		for h in all[w]:
			ids.append(h[0])
			_zone_ok("R03 wall %s %s" % [w, h[0]], h[1])
			for k in exits:
				check(not exits[k].intersects(h[1]), "R03 exit %s does not overlap %s" % [k, h[0]])
		for h in R03Sim.WALL_HOTSPOTS[w]:
			check(h in ids, "R03 view has a wall %s rect for %s" % [w, h])
	var tl := _rect_list(turns)
	var tids := []
	for t in tl:
		tids.append(t[0])
		_zone_ok("R03 %s" % t[0], t[1])
		for k in exits:
			check(not exits[k].intersects(t[1]), "R03 exit %s does not overlap %s" % [k, t[0]])
		for w in R03Sim.WALLS:
			for h in all[w]:
				check(not h[1].intersects(t[1]), "R03 %s does not overlap wall %s %s" % [t[0], w, h[0]])
	check("turn_left" in tids and "turn_right" in tids, "R03 view has both turn arrows")

# ---------------------------------------------------------------------------
# the view: per-wall hit tests, turn plaques, notice hold, registration geometry, close-up
# controls, loop targets, presentation-only hooks
# ---------------------------------------------------------------------------
func test_view() -> void:
	var scene = new_scene("user://room_test_R03_view.json")
	await process_frame
	scene.room_jump(ROOM, 4)   # tide II, P04 done: every wall live
	await process_frame
	var v = scene.room_view
	var r := scene.room_sim() as R03Sim
	check(v != null and r != null, "R03 view mounts at stage 4")
	if v == null:
		await free_scene(scene)
		return
	# Each wall answers with its own list, small objects first; turns everywhere.
	for w in R03Sim.WALLS:
		r.wall = w
		for h in v.WALL_HOTSPOTS[w]:
			var a: String = v.action_at(h[1].get_center())
			var first := ""
			for k in v.WALL_HOTSPOTS[w]:
				if k[1].has_point(h[1].get_center()):
					first = k[0]
					break
			check(a == first, "wall %s: the centre of %s hits %s (got %s)" % [w, h[0], first, a])
		for t in v.TURN_RECTS:
			check(v.action_at(v.TURN_RECTS[t].get_center()) == t, "wall %s: %s is clickable" % [w, t])
		check(v.label_for("turn_left").begins_with("◂ ") and v.label_for("turn_right").ends_with(" ▸"),
			"wall %s: turn plaques name their direction" % w)
	r.wall = "A"
	check(v.label_for("turn_left") == "◂ Hatch wall" and v.label_for("turn_right") == "Recorder wall ▸",
		"wall A turns to the hatch wall (left) and the recorder wall (right)")
	r.wall = "B"
	check(v.label_for("turn_left") == "◂ Chart wall" and v.label_for("turn_right") == "Hatch wall ▸",
		"wall B turns to the chart wall (left) and the hatch wall (right)")
	check(v.exits_active() and v.esc_action() == "menu" and not v.back_visible(), "walls: exits on, Esc is the menu")
	# The turn plaques and their hover labels fit the 1448 px plate on every wall. The plaque names
	# run up inside the plaque (as draw_hud draws them); the hover label, clamped to the right
	# edge by the core, still fits whole beside the right plaque's edge margin.
	var f := Ink.serif()
	for t in v.TURN_RECTS:
		var tr: Rect2 = v.TURN_RECTS[t]
		check(tr.position.x >= 16 and tr.end.x <= 1448 - 16, "%s sits inside the plate" % t)
		for w in ["A", "B", "C"]:
			r.wall = w
			var dest: String = R03Sim.TURNS[w][t]
			var nw := f.get_string_size(v.WALL_NAMES[dest], HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
			check(nw <= tr.size.y - 52 - 8, "wall %s %s: '%s' (%d px) fits up its plaque" % [w, t, v.WALL_NAMES[dest], nw])
			var lw := f.get_string_size(v.label_for(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 20
			check(lw <= tr.position.x - 16 or t == "turn_left", "wall %s %s: hover '%s' (%d px) fits left of the plaque when clamped" % [w, t, v.label_for(t), lw])
			check(lw <= 1448 - 32, "wall %s %s: hover label fits the plate" % [w, t])
	r.wall = "B"
	# The notice hold: input ignored except a click, which skips it.
	r.wall = "C"
	v.play_fx("notice", {"notice": "n_p04"})
	check(v.holding(), "a notice starts a hold")
	check(v.hover_at(Vector2(700, 600)) == "" and not v.exits_active() and v.esc_action() == "",
		"during the hold, hover, exits and Esc are ignored")
	check(v.action_at(Vector2(700, 600)) == "" and v.action_at(v.TURN_RECTS.turn_left.get_center()) == ""
		and v.holding(), "during the hold, action_at answers nothing and is pure")
	check(v.consume_click(Vector2(700, 600)) and not v.holding(), "a click skips the hold and does nothing else")
	check(not v.consume_click(Vector2(700, 600)), "with no hold, a click is not consumed")
	check(v.action_at(v.TURN_RECTS.turn_left.get_center()) == "turn_left", "after the skip, clicks act again")
	v.play_fx("notice", {"notice": "n_b7"})
	for i in 120:
		v.tick(1.0 / 60.0)
	check(not v.holding(), "the hold ends by itself after about 1.5 s")
	v.play_fx("notice", {"notice": "bogus"})
	check(not v.holding(), "an unknown notice holds nothing")
	# The scratches sit on the jamb, inside the hatch-frame hotspot.
	var frame: Rect2 = v.WALL_HOTSPOTS.C[0][1]
	for stroke in v.scratch_strokes():
		for p in stroke:
			check(frame.grow(2).has_point(p), "scratch point %s is on the jamb" % [p])
	# Repaint: the painted door on wall A is the office exit; lights follow wall and state only.
	r.wall = "A"
	check(v.action_at(Vector2(1240, 650)) == "go:R02" and v.hover_at(Vector2(1240, 650)) == "go:R02",
		"wall A's painted door is the way back to the office")
	r.wall = "B"
	check(v.action_at(Vector2(1240, 650)) != "go:R02", "the door is only on wall A")
	r.wall = "A"
	var le: Dictionary = v.light_energies(0)
	check(is_equal_approx(le.lamp, 0.6) and le.window == 0.0 and le.hatch == 0.0, "wall A: the chart lamp alone, 0.6")
	check(is_equal_approx(v.light_energies(7).lamp, 0.35), "the lamp falls to 0.35 by band 7, never off")
	r.wall = "B"
	check(v.light_energies(0).window > 0.25 and v.light_energies(0).lamp == 0.0, "wall B: the sea window lights it")
	r.wall = "C"
	check(v.light_energies(3).hatch > 0.0, "wall C after P04: cold light from the open hatch")
	for b in 7:
		check(v.float_y(b + 1) < v.float_y(b), "the float rides higher at band %d" % (b + 1))
	check(v.FLOAT_WELL.has_point(Vector2(1016, v.float_y(7) + 48)) and v.FLOAT_WELL.has_point(Vector2(1016, v.float_y(0) + 48)),
		"the float stays inside the well's glass, above the subtitle bar")
	for w in ["A", "B", "C"]:
		for b in range(2, 8):
			check(v._tex("%s_damp_%d" % [w, b]) != null, "damp tide-mark %s band %d is painted" % [w, b])
	for id in ["A_buckle", "A_fog", "B_float", "C_rope_0", "C_rope_1", "C_rope_2", "C_beads", "cu_rec_fog", "cu_rec_brown"]:
		check(v._tex(id) != null, "%s is painted" % id)
	check(v._tex("B_window_t2") != null, "the tide II window is painted")
	check(R03Sim.REG_SLOT_LABELS == {"14": "SPARE: 14 OCT", "17": "TABLE: 17 OCT"}, "the base slots are labelled by id")
	for c0 in v.REG_CONTROLS:
		if c0[0].begins_with("reg_base_"):
			check(c0[2] == R03Sim.REG_SLOT_LABELS[c0[0].substr(9)], "%s is labelled %s" % [c0[0], c0[2]])
	check(v.TIDE_SCALE.has_point(Vector2(v.TIDE_SCALE.get_center().x, v.MUD_Y)) and v.MUD_Y < 522.0,
		"his MUD mark is on the scale, above where the tide II sea lies")
	check(v.WINDOW_GLASS.encloses(v.TIDE_SCALE), "the tide scale is on the glass")
	# Loop targets follow state and wall, never a clock.
	r.wall = "B"
	var t: Dictionary = v.audio_targets()
	check(is_equal_approx(t.r03_drum, 0.45) and is_equal_approx(t.r03_scratch, 0.0), "P04 on wall B: the drum, no scratch")
	r.wall = "C"
	t = v.audio_targets()
	check(t.r03_sea == 0.0 and is_equal_approx(t.r03_stair_air, 0.25), "P04 on wall C: no sea, stair air")
	# Registration: the answer lands his sheet exactly on the table's.
	r.state.reg_rot = 0
	r.state.reg_snap = "lighthouse"
	var xf: Transform2D = v.venn_xform()
	for k in v.CROSSES:
		check((xf * v.CROSSES[k]).distance_to(v.CROSSES[k]) < 0.01, "in register, his %s is on the table's" % k)
	r.state.reg_rot = 2
	r.state.reg_snap = ""
	xf = v.venn_xform()
	check((xf * v.CROSSES.lighthouse).distance_to(v.CROSSES.lighthouse) > 30.0, "loose and upside down, it's out of register")
	r.state.reg_rot = 1
	r.state.reg_snap = "buoy"
	xf = v.venn_xform()
	check((xf * v.CROSSES.buoy).distance_to(v.CROSSES.lighthouse) < 0.01, "pinned by his buoy, the buoy is on the table's lighthouse")
	# The composite lies in band 3 between x 250 and 580.
	for p in v.VENN_BRACKET + v.VENN_LINKED + v.VENN_EXIT + [v.VENN_LOOP_C]:
		check(p.y >= 272 and p.y <= 368 and p.x >= 250 and p.x <= 580, "composite point %s is in band 3" % [p])
	# Close-up controls.
	r.state.reg_rot = 0
	r.state.reg_snap = ""
	r.local_view = "c_registration"
	r.state.reg_laid = false
	check(v.action_at(Vector2(204, 475)) == "reg_lay", "unlaid: the lay control lays")
	r.state.reg_laid = true
	check(v.action_at(Vector2(204, 475)) == "reg_lift", "laid: the same control lifts")
	check(v.action_at(Vector2(1264, 790)) == "reg_clip" and v.action_at(Vector2(700, 760)) == "reg_table",
		"CLIP and the light table answer")
	var lh: Vector2 = v._venn_screen_xform() * v.CROSSES.datum
	check(v.action_at(lh) == "reg_table", "after P03 his crosses no longer pin")
	r.state.p03_complete = false
	check(v.action_at(lh) == "reg_snap_datum", "clicking his visible cross pins by it")
	r.state.p03_complete = true
	check(v.back_visible() and v.esc_action() == "back" and not v.exits_active(), "close-up: Back, Esc backs out, no exits")
	r.local_view = "c_recorder"
	check(v.action_at(Vector2(329, 484)) == "rec_zero_up" and v.action_at(Vector2(569, 710)) == "rec_int_down",
		"the wheel buttons answer after the threshold")
	check(v.action_at(Vector2(989, 565)) == "rec_slot_0" and v.action_at(Vector2(1154, 885)) == "rec_record",
		"after P04 the record panel is open")
	check(v.action_at(Vector2(989, 745)) == "rec_plate_observer", "the rack's first home holds OBSERVER")
	r.local_view = "c_plan"
	for c0 in v.PLAN_CONTROLS:
		check(v.action_at(c0[1].get_center()) == c0[0], "c_plan: %s answers" % c0[0])
		check(c0[1].size.x >= 44 and c0[1].size.y >= 44 and not c0[1].intersects(v.PLAN_PAPER), "c_plan: %s is a fair target off the plan" % c0[0])
	check(v.action_at(v.PLAN_CHAMBER.get_center()) == "plan_zone_centre", "the chamber is the centre zone")
	r.state.plan_laid = true
	r.state.plan_rot = 0
	r.state.plan_snap = ""
	check(v.action_at(v.PLAN_CONTROLS[0][1].get_center()) == "plan_lift", "laid: the chart slot lifts")
	var hc: Vector2 = v.plan_xform() * v.CROSSES.datum
	check(v.action_at(hc) == "plan_snap_datum", "clicking his visible cross on the plan pins by it")
	r.state.plan_rot = R03Sim.PLAN_ROT
	r.state.plan_snap = "lighthouse"
	r.state.plan_registered = true
	check(v.action_at(v.PLAN_CONTROLS[0][1].get_center()) == "plan_lay", "registered: the slot no longer lifts")
	check(v.action_at(v.plan_xform() * v.CROSSES.datum) != "plan_snap_datum", "registered: his crosses no longer pin")
	r.state.plan_laid = false
	r.state.plan_snap = ""
	r.state.plan_registered = false
	r.state.plan_rot = R03Sim.PLAN_ROT_START
	# Geometry: in register, his lighthouse sits on the plan's, and the curve runs through the
	# lantern gallery, the chart room, the listening room and the laboratory, never through the
	# office or the vault; his hollow circle falls in the witness chamber. Any other pin or turn
	# moves the line off that path.
	r.state.plan_laid = true
	r.state.plan_rot = R03Sim.PLAN_ROT
	r.state.plan_snap = "lighthouse"
	check((v.plan_xform() * v.CROSSES.lighthouse).distance_to(v.PLAN_LH) < 0.01, "p3: his lighthouse on the plan's")
	var north: Vector2 = v.plan_xform().basis_xform(Vector2(0, -1))
	check(north.distance_to(Vector2(1, 0)) < 0.01, "p3: in register his north points the plan's way (right)")
	var hit := _curve_rooms(v)
	for n in v.PLAN_CROSSED:
		check(n in hit, "p3: the registered line runs through %s (%s)" % [n, hit])
	for n in v.PLAN_OUTSIDE + ["KITCHEN & MESS", "BUNK ROOM", "MACHINE ROOM", "JETTY"]:
		check(not n in hit, "p3: the registered line stays out of %s" % n)
	check(v.PLAN_CHAMBER.has_point(v.plan_xform() * v.VENN_LOOP_C), "p3: his hollow circle is in the chamber")
	check(v.PLAN_PAPER.encloses(Rect2(v.plan_xform() * Vector2.ZERO, Vector2.ZERO).expand(v.plan_xform() * Vector2(600, 560))),
		"p3: the registered composite lies on the plan paper")
	for rot in 4:
		for snap in ["lighthouse", "buoy", "datum"]:
			if rot == R03Sim.PLAN_ROT and snap == "lighthouse":
				continue
			r.state.plan_rot = rot
			r.state.plan_snap = snap
			check(not v.PLAN_CHAMBER.has_point(v.plan_xform() * v.VENN_LOOP_C) or not "LANTERN GALLERY" in _curve_rooms(v),
				"p3: %d/%s does not draw the body" % [rot, snap])
	check(v._tex("p21_body_overlay") != null, "p3: the outline overlay is loaded")
	r.state.plan_laid = false
	r.state.plan_snap = ""
	r.state.plan_rot = R03Sim.PLAN_ROT_START
	r.local_view = "room"
	# Presentation only: the view's hooks leave the story alone.
	var before: Dictionary = scene.sim.to_dict()
	v.apply_instantly()
	v.reset_presentation()
	for fx in ["composite", "drum_turn", "strip_print", "plan_resolve", "item_added"]:
		v.play_fx(fx, {})
	for sfx in ["strip_print", "strip_print_last", "relay_clack", "name_print", "plan_resolve"]:
		v.on_sfx(sfx)
	for i in 30:
		v.tick(1.0 / 60.0)
	check(JSON.stringify(scene.sim.to_dict()) == JSON.stringify(before), "the view's hooks never change story state")
	# The strip types only on its cues.
	scene.room_jump(ROOM, 5)
	await process_frame
	v = scene.room_view
	r = scene.room_sim() as R03Sim
	check(v.strip_visible().size() == 6, "a loaded strip shows all six lines")
	v.play_fx("strip_print", {})
	check(v.strip_visible().is_empty(), "printing starts blank")
	for i in 60:
		v.tick(1.0 / 60.0)
	check(v.strip_visible().is_empty(), "nothing types before the print cue")
	v.on_sfx("strip_print")
	for i in 900:
		v.tick(1.0 / 60.0)
	check(v.strip_visible().size() == 4, "the first print types the head and her three moves, and waits")
	v.on_sfx("strip_print_last")
	v.on_sfx("relay_clack")
	for i in 900:
		v.tick(1.0 / 60.0)
	check(v.strip_visible().size() == 6, "line 4 and the relay's reply follow their cues")
	await free_scene(scene)
