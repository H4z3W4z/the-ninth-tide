extends SceneTree
## Core tests: room discovery, tides and weather, travel and the GDD traversal gates,
## inventory, notebook, hints, saves (schema, tamper, slice migration, settings apart),
## debug jumps, endings, and the game scene hosting rooms. Run after an import:
##   godot --headless --path . --script tests/core_test.gd

const FIXTURES := "res://tests/fixtures/rooms"
const ALL := ["R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R10", "R11", "R12"]

## Traversal topology (GDD section 5 as refined by docs/design/puzzle-cards/rooms.md), as
## undirected pairs. The passage strips join their rooms: R03-R04, R05-R06, R07-R08.
const TOPOLOGY := [["R01", "R02"], ["R02", "R03"], ["R02", "R04"], ["R02", "R05"], ["R02", "R06"],
	["R03", "R04"], ["R03", "R11"], ["R05", "R06"], ["R05", "R07"], ["R05", "R08"], ["R07", "R08"],
	["R07", "R10"], ["R07", "R11"], ["R09", "R11"], ["R11", "R12"]]
const CARDS := "res://docs/design/puzzle-cards/"

## Rooms reachable from the office at the start of each tide (by real gates).
const REACH := {
	1: ["R01", "R02"],
	2: ["R01", "R02", "R03", "R04"],
	3: ["R01", "R02", "R03", "R04", "R05", "R06", "R11"],
	4: ["R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R11"],
	5: ["R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R11"],
	6: ["R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R10", "R11"],
	7: ["R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R10", "R11"],
	8: ["R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R10", "R11"],
	9: ALL,
}

var failures: Array = []

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		push_error(msg)

func says(ev: Array) -> String:
	var out := []
	for e in ev:
		if e.type == "say": out.append(e.text)
	return " | ".join(out)

func has_ev(ev: Array, type: String, id: String) -> bool:
	for e in ev:
		if e.type == type and e.get("id", "") == id: return true
	return false

func count_ev(ev: Array, type: String, id: String) -> int:
	var n := 0
	for e in ev:
		if e.type == type and e.get("id", "") == id: n += 1
	return n

func sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	test_discovery()
	test_topology()
	test_reach_per_tide()
	test_tides_and_weather()
	test_card_flags()
	test_movement_trace()
	test_travel()
	test_latched_office()
	test_inventory_and_use()
	test_notebook_and_hints()
	test_saves()
	test_slice_migration()
	test_debug_tide()
	test_plan_travel()
	test_endings()
	test_events_shape()
	test_objective_elsewhere()
	test_objective_every_tide()
	test_plan_from_closeup()
	test_load_behind_gate()
	await test_scene_rooms()
	await test_scene_saves()
	await test_inventory_paging()
	await test_notebook_pages()
	await test_hover_and_back()
	await test_travel_fade()
	await test_card_and_slab()
	await test_placeholder()
	test_item_on_exit()
	test_item_labels()
	await test_hint_ladder()
	await test_build_end()
	await test_clicks_never_eaten()
	await test_hover_label_rects()
	await test_glance()
	await test_consume_click()
	await test_room_hooks()
	await test_cinematic_keys()
	await test_closeup_now_and_plan()
	test_end_card_lines()
	await test_end_clears_lines()
	test_resume_view()
	await test_travel_outside_graph()
	test_retired_items()
	test_plan_equals_walking()
	await test_plan_button()
	await test_reveal_leak()
	await test_hotspot_click_acts()
	await test_plan_slot()
	test_hint_tiers()
	await test_tide_card_rules()
	await test_end_card_panel()
	await test_title_screen()
	await test_hold_breath()
	await test_hud_at_once()
	await test_hint_card()
	await test_disarm()
	await test_ghost_slots()
	await test_exit_rush()
	await test_hint_ladder_every_step()
	await test_bed_loudness()
	await test_now_plan()
	await test_hover_anchor()
	await test_glance_clears()
	if failures.is_empty():
		print("PASS: core — discovery, topology, gates per tide, tides and weather, travel, latched office, inventory, notebook, hints, saves, slice migration, debug jumps, plan travel, endings, events, objective elsewhere, objective every tide, plan from a close-up, load behind a gate, scene rooms, scene saves, inventory paging, notebook pages, hover and back, travel fade, card and slab, placeholder, item on exit, item labels, hint ladder, build end, clicks never eaten, hover labels, glance, consume_click, room hooks, cinematic keys, Now: after P02, end card lines, end clears lines, resume view, travel outside the graph, retired items, plan equals walking, plan button, reveal leak, hotspot clicks act, plan slot, hint tiers, tide card rules, end card panel, title screen, hold breath, HUD at once, hint card, disarm, ghost slots, exit rush, hint ladder every step, bed loudness, Now: via the plan, hover anchor, glance clears")
	else:
		print("FAIL (%d): %s" % [failures.size(), "; ".join(failures)])
	for i in 10:
		await process_frame
	quit(0 if failures.is_empty() else 1)

func test_discovery() -> void:
	check(GameSim.discover() == ALL, "discovers R01-R12 from game/rooms (got %s)" % [GameSim.discover()])
	var g := GameSim.new()
	for rid in ALL:
		check(g.room(rid) != null and g.room(rid).id() == rid, "%s's ID matches its directory" % rid)
		check(g.state.rooms.has(rid), "%s has a local state slot" % rid)
	var f := GameSim.new(FIXTURES)
	check(f.order == ["Z01", "Z02"], "a room is discovered from its directory alone (%s)" % [f.order])
	check(f.start_room == "Z01", "without R02 the first room starts")
	check(not g.rooms.has("Z01"), "fixture rooms stay out of the game")

func test_topology() -> void:
	var g := GameSim.new()
	var pairs := []
	for rid in g.order:
		for e in g.exits(rid):
			var p := [rid, e[0]]
			p.sort()
			if not p in pairs:
				pairs.append(p)
			var back := false
			for b in g.exits(e[0]):
				back = back or b[0] == rid
			check(back, "%s -> %s has a way back" % [rid, e[0]])
	pairs.sort()
	var want := TOPOLOGY.duplicate()
	want.sort()
	check(pairs == want, "exits match the GDD topology (%s)" % [pairs])

func test_reach_per_tide() -> void:
	for t in REACH:
		var g := GameSim.new()
		g.debug_tide(t)
		check(sorted(g.reachable("R02")) == REACH[t], "tide %d reaches %s (got %s)" % [t, REACH[t], sorted(g.reachable("R02"))])
		check(g.tide() == t, "debug_tide(%d) lands in tide %d (got %d)" % [t, t, g.tide()])
	# Each gate, flag by flag.
	var g := GameSim.new()
	g.debug_enter("R02")
	check(not g.exit_open("R02", "R03"), "chart room shut at the start")
	g.set_flag("P01")
	check(g.exit_open("R02", "R03") and g.exit_open("R02", "R04"), "the lamp opens the instrument rooms (rooms.md)")
	check(g.exit_open("R03", "R04") and g.exit_open("R04", "R03"), "the upper passage joins chart and listening rooms")
	check(not g.exit_open("R02", "R05") and not g.exit_open("R02", "R06"), "service door shut before P06")
	g.set_flag("P06")
	check(g.exit_open("R02", "R05") and g.exit_open("R02", "R06"), "P06 opens kitchen and bunks")
	check(g.exit_open("R05", "R06") and g.exit_open("R06", "R05"), "the service passage joins kitchen and bunks")
	check(not g.exit_open("R03", "R11"), "hatch shut before P04")
	g.set_flag("P04")
	check(g.exit_open("R03", "R11"), "P04 opens the hatch onto the stair threshold")
	check(not g.exit_open("R11", "R07") and not g.exit_open("R11", "R09"), "descent shut before P12")
	check(not g.exit_open("R05", "R07"), "kitchen service access shut before P09")
	g.set_flag("P09")
	check(g.exit_open("R05", "R07") and g.exit_open("R05", "R08"), "P09 opens lab and machine room")
	check(g.exit_open("R07", "R08") and g.exit_open("R08", "R07"), "the lower passage joins lab and machine room")
	check(not g.exit_open("R07", "R11"), "the lab's stair door stays shut until P12")
	g.set_flag("P12")
	check(g.exit_open("R11", "R07") and g.exit_open("R07", "R11") and g.exit_open("R11", "R09"), "P12 opens the stair both ways and the gallery")
	check(not g.exit_open("R07", "R10"), "vault shut before P15")
	g.set_flag("P15")
	check(g.exit_open("R07", "R10"), "P15 opens the vault")
	check(not g.exit_open("R11", "R12"), "chamber shut before P24")
	g.set_flag("P24")
	check(g.exit_open("R11", "R12"), "P24 opens the chamber")

func test_tides_and_weather() -> void:
	var g := GameSim.new()
	check(g.tide() == 1 and g.weather_band() == 0, "tide I, weather 0 at the start")
	var ev: Array = []
	g.solve("P01", ev); g.solve("P02", ev)
	check(ev.is_empty() and g.tide() == 1, "no tide change mid-tide")
	g.solve("P03", ev)
	check(g.tide_done(1) and g.tide() == 1 and ev.is_empty(), "P02 + P03 finish tide I's puzzles; Tide II waits for the threshold")
	g.solve("closure_report_filed", ev)
	check(g.tide() == 1 and ev.is_empty(), "the filed report alone is not the threshold")
	g.solve("t1x_threshold_crossed", ev)
	check(g.tide() == 2 and count_ev(ev, "fx", "tide") == 1 and ev[0].tide == 2, "crossing the threshold begins Tide II")
	ev.clear()
	g.solve("P03", ev)
	check(ev.is_empty() and g.tide() == 2, "a repeated solve neither re-rewards nor re-advances")
	check(g.weather_band() == 0, "Tide I complete: still the arrival weather")
	var early := GameSim.new()
	early.set_flag("t1x_threshold_crossed")
	early.set_flag("P02")
	check(early.tide() == 1, "the threshold without both instruments stays tide I")
	for p in ["P04", "P05"]:
		g.solve(p, ev)
	check(g.tide() == 2, "tide II is done by P06, not P04/P05")
	g.solve("P06", ev)
	check(g.tide() == 3 and g.weather_band() == 1, "Tide II complete: weather 1")
	g.solve("P08", ev)
	check(g.tide() == 3, "a later puzzle out of order doesn't skip a tide")
	var six := GameSim.new()
	for p in ["P02", "P03", "t1x_threshold_crossed", "P06", "P09", "P12", "P15", "P17"]:
		six.set_flag(p)
	check(six.tide() == 6 and six.weather_band() == 4, "tide VI needs both P17 and P18")
	six.set_flag("P18")
	check(six.tide() == 7 and six.weather_band() == 5, "P17 + P18 finish tide VI")
	var all := GameSim.new()
	for n in range(1, 10):
		for p in GameSim.tide_puzzles(n):
			all.set_flag(p)
	all.set_flag("t1x_threshold_crossed")
	check(all.tide() == 9 and all.tides_completed() == 9 and all.weather_band() == 7, "after IX: tide 9, weather holds at 7")
	check(all.plan_unlocked() and not GameSim.new().plan_unlocked(), "the plan unlocks with P05")
	check(all.room_open("R12") and not GameSim.new().room_open("R12") and not all.room_open("R99"), "room_open")
	check(GameSim.tide_puzzles(9) == ["P25", "P26", "P27"], "tide IX is P25-P27")
	check(g.tide_title(2) == "Tide II  ·  The Boat at the Window", "tide titles")

## Every cross-room id in the cards' flags.md is settable and readable through the core API,
## in the cards' own spelling; every movement event the cards whitelist is the core's.
func test_card_flags() -> void:
	var text := FileAccess.get_file_as_string(CARDS + "flags.md")
	check(text != "", "flags.md is readable")
	var bools := []
	var values := []
	var section := ""
	var row := RegEx.create_from_string("^\\| `([a-z0-9_]+)` \\|")
	for line in text.split("\n"):
		if line.begins_with("## "):
			section = line.substr(3, 2)
		var m := row.search(line)
		if m == null:
			continue
		if section == "2." or section == "6.":
			var id := m.get_string(1)
			if id in ["p05_trace", "movement_events", "ending_choice", "endings_seen"]:
				values.append(id)
			else:
				bools.append(id)
	check(bools.size() == 36, "flags.md lists 27 completion, 3 transition and 6 optional flags (got %d)" % bools.size())
	var g := GameSim.new()
	for id in bools:
		g.set_flag(id)
		check(g.flag(id), "card flag %s is settable" % id)
	var t := roundtrip(g)
	# P01 and the Tide I transition flags follow R02's state on load (tested in R02_test).
	# P06 follows R01's state the same way (tested in R01_test).
	var derived := ["p01_complete", "p06_complete", "closure_report_filed", "t1x_threshold_crossed", "t1x_turned"]
	for id in bools:
		check(t.flag(id) != (id in derived), "card flag %s survives a save (or follows its owner)" % id)
		t.set_flag(id, false)
		check(not t.flag(id), "card flag %s clears" % id)
	check(g.flag("P07") and g.flag("p07_complete") and GameSim.canon_flag("p07_complete") == "P07",
		"the cards' p07_complete is the core's P07")
	check(sorted(values) == ["ending_choice", "endings_seen", "movement_events", "p05_trace"],
		"flags.md's non-bool values (got %s)" % [values])
	for id in values:
		check(g.value(id) != null, "card value %s is readable" % id)
	var before: int = g.state.flags.size()
	g.set_flag("p28_complete")
	g.set_flag("threshold_crossed")
	check(g.state.flags.size() == before, "an id not in the cards is refused")
	# The movement whitelist (section 3) is the core's, word for word.
	var moves := {}
	var mrow := RegEx.create_from_string("^\\| `([a-z_]+)` \\| [^|]+ \\| (.+?) \\|$")
	section = ""
	for line in text.split("\n"):
		if line.begins_with("## "):
			section = line.substr(3, 2)
		var m := mrow.search(line)
		if m != null and section == "3.":
			moves[m.get_string(1)] = m.get_string(2)
	check(moves == GameSim.MOVES, "the movement whitelist matches flags.md (%s)" % [moves])
	# Items (section 4): each is declared by the room the card says it is found in. The P01
	# bridges stay R02 tray parts (P01 is unchanged), so they are not inventory items.
	var irow := RegEx.create_from_string("^\\| `([a-z_]+)` \\| [^|]+ \\| ([^|]+) \\|")
	var want := {}
	section = ""
	for line in text.split("\n"):
		if line.begins_with("## "):
			section = line.substr(3, 2)
		var m := irow.search(line)
		if m != null and section == "4." and not m.get_string(1) in ["bridge_b", "spare_c"]:
			var found := m.get_string(2)
			var r := RegEx.create_from_string("R\\d\\d").search(found)
			var p := RegEx.create_from_string("P\\d\\d").search(found)
			want[m.get_string(1)] = r.get_string() if r else ("start" if p == null else p.get_string())
	var defs := g.item_defs()
	check(sorted(defs.keys()) == sorted(want.keys()), "declared items match flags.md (%s vs %s)" % [sorted(defs.keys()), sorted(want.keys())])
	var puzzle_room := {"P06": "R01", "P07": "R05", "P08": "R06", "P13": "R07", "P14": "R07", "P15": "R09",
		"P16": "R10", "P18": "R10", "P22": "R06", "P23": "R10", "start": "R02"}
	for id in want:
		var where: String = puzzle_room.get(want[id], want[id])
		check(defs.has(id) and defs[id].room == where, "%s is declared by %s (got %s)" % [id, where, defs.get(id, {}).get("room", "-")])

func test_movement_trace() -> void:
	var g := GameSim.new()
	g.record_move("lamp_mended")
	g.record_move("lamp_mended")
	g.record_move("not_a_move")
	check(g.value("movement_events") == ["lamp_mended"], "duplicates collapse, unknown ids are refused")
	for m in ["log_read", "drawer_opened", "recording_played", "charts_aligned", "report_signed",
			"held_still", "zero_turned", "interval_set", "zero_turned", "hatch_opened"]:
		g.record_move(m)
	var ev: Array = g.value("movement_events")
	check(ev.size() == GameSim.MOVES_MAX and ev[-1] == "hatch_opened" and ev[0] == "recording_played",
		"the trace keeps the last eight (%s)" % [ev])
	check(g.freeze_p05_trace() == ["interval_set", "zero_turned", "hatch_opened"], "P05 freezes the last three")
	g.record_move("stair_looked")
	check(g.freeze_p05_trace() == ["interval_set", "zero_turned", "hatch_opened"], "a frozen trace never changes")
	var t := roundtrip(g)
	check(t.value("p05_trace") == g.value("p05_trace") and t.value("movement_events") == g.value("movement_events"),
		"trace and frozen P05 trace survive a save")
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	d.p05_trace = ["junk"]
	d.movement_events = ["lamp_mended", "junk", 4]
	var b := GameSim.new()
	b.from_dict(d)
	check(b.value("p05_trace") == [] and b.value("movement_events") == ["lamp_mended"], "unknown trace ids are dropped")
	check(GameSim.move_text("held_still") == "Held still.", "the recorder's printed text")

func test_travel() -> void:
	var g := GameSim.new()
	g.dispatch("begin")
	check(g.state.room == "R02" and g.state.visited == ["R02"], "begin in the office")
	var ev := g.dispatch("go:R03")
	# The office answers first: its corridor is dark until the lamp (R02 exit_block).
	check(g.state.room == "R02" and says(ev) == "The corridor is pitch black. Light first.", "before the lamp: the dark corridor")
	check(g.room("R03").locked_line().begins_with("The chart room door is latched"), "before the lamp: the chart room is latched")
	ev = g.dispatch("go:R01")
	check(g.state.room == "R01" and has_ev(ev, "fx", "travel"), "the jetty is open from the start")
	check(says(ev).begins_with(g.room("R01").c("ARRIVAL")), "arrival line on the first visit")
	ev = g.dispatch("go:R02")
	check(g.state.room == "R02" and says(ev) == "", "the office says nothing on a return")
	ev = g.dispatch("go:R01")
	check(says(ev) == "", "no arrival line the second time")
	check(g.state.visited == ["R02", "R01"], "visited in order")
	g.dispatch("go:R09")
	check(g.state.room == "R01", "no travel to a room that isn't connected")
	g.dispatch("go:R02")
	g.dispatch("lamp")
	check(g.room().local_view == "repair", "a close-up")
	g.dispatch("go:R01")
	check(g.state.room == "R02", "no travel from a close-up")
	g.dispatch("back")
	var s := g.room("R02") as R02Sim
	s.state.p01_complete = true
	s.reconcile()
	ev = g.dispatch("go:R03")
	# Re-timed (T1X-closure.md): the corridor opens on P01.
	check(g.state.room == "R03" and has_ev(ev, "fx", "travel"), "after the lamp, the corridor opens to the chart room")

func test_latched_office() -> void:
	var g := GameSim.new()
	var s := g.room("R02") as R02Sim
	s.debug_jump(3)
	var ev := g.dispatch("go:R01")
	check(g.state.room == "R02" and says(ev) == R02Sim.LATCHED_LINE, "seat wet: every exit is latched")
	s.debug_jump(5)
	check(g.flag("P01") and g.flag("closure_report_filed") and g.flag("t1x_threshold_crossed"),
		"debug 5: lamp, report and threshold flags")
	ev = g.dispatch("go:R04")
	check(g.state.room == "R04" and says(ev) == g.room("R04").c("ARRIVAL"), "through the corridor to the listening room")

func test_inventory_and_use() -> void:
	var g := GameSim.new(FIXTURES)
	g.dispatch("begin")
	check(g.state.room == "Z01", "fixture start")
	var ev := g.dispatch("item:key")
	check(g.selected_item == "", "can't select an item she doesn't have")
	ev = g.dispatch("shelf")
	check(g.has_item("key") and has_ev(ev, "fx", "item_added"), "the shelf gives the key")
	g.dispatch("shelf")
	check(g.state.inventory == ["key"], "an item is held once")
	g.dispatch("item:key")
	check(g.selected_item == "key", "select the key")
	g.dispatch("item:key")
	check(g.selected_item == "", "select again: put it away")
	g.dispatch("item:key")
	ev = g.dispatch("lever")
	check(says(ev) == GameSim.GENERIC_WRONG_USE and g.has_item("key") and g.selected_item == "",
		"the wrong target refuses, keeps the item and lets go")
	check(int(g.room().state.pulls) == 0, "a refused use is not also a click")
	g.dispatch("item:key")
	ev = g.dispatch("box")
	check(g.room().state.box_open and not g.has_item("key"), "the key opens the box and is used up")
	check(count_ev(ev, "fx", "tide") == 1 and g.tide() == 2, "the fixture's solves complete tide I")
	check(g.has_seen("Z01", "box") and g.room().seen() == ["shelf", "box"], "observations in order")
	ev = g.dispatch("go:Z02")
	check(g.state.room == "Z02", "a REQUIRES flag opens the next room")
	check(g.item_defs()["key"]["name"] == "Brass key" and g.item_defs()["key"]["room"] == "Z01", "item registry")

func test_notebook_and_hints() -> void:
	var g := GameSim.new(FIXTURES)
	g.dispatch("begin")
	var ev := g.dispatch("hint")
	check(says(ev) == "a" and g.state.hint.level == 1, "hint ladder level 1")
	g.dispatch("hint"); g.dispatch("hint")
	ev = g.dispatch("hint")
	check(says(ev) == "c", "the ladder stops at the solution")
	g.dispatch("shelf")
	ev = g.dispatch("hint")
	check(says(ev) == "d", "a new objective restarts the ladder")
	g.dispatch("notebook")
	check(g.view == "notebook" and g.return_view == "room", "notebook")
	ev = g.dispatch("hint")
	check(says(ev) == "e", "hint from the notebook")
	g.dispatch("tab:Z01")
	check(g.nb_tab == "Z01", "notebook tabs")
	g.dispatch("back")
	check(g.view == "room" and g.nb_tab == "Z01", "back from the notebook")
	g.observe("Z01", "box")
	g.observe("Z01", "box")
	check(g.state.notebook.count("Z01.box") == 1, "an observation is noted once")

func roundtrip(g: GameSim) -> GameSim:
	var t := GameSim.new()
	check(t.from_dict(JSON.parse_string(JSON.stringify(g.to_dict()))), "save loads")
	return t

func test_saves() -> void:
	var g := GameSim.new()
	g.debug_tide(4, "R05")
	g.dispatch("go:R07")
	g.record_move("charts_aligned")
	var t := roundtrip(g)
	check(JSON.stringify(t.to_dict()) == JSON.stringify(g.to_dict()), "a save round-trips exactly")
	check(t.state.room == "R07" and t.view == "room" and t.tide() == 4, "room, view and tide survive")
	check(t.value("movement_events") == ["charts_aligned"], "the movement trace survives")
	check(t.to_dict().schema == GameSim.SCHEMA and GameSim.SCHEMA == 6, "schema 6")
	var bad := GameSim.new()
	check(not bad.from_dict({"schema": 1}), "a flat dict with no rooms is rejected")
	check(not bad.from_dict({"schema": 7, "rooms": {}}), "a future schema is rejected")
	check(not bad.from_dict("junk") and not bad.from_dict([1, 2]), "junk rejected")
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	d.flags["P99"] = true
	d.flags["X01.y"] = true
	d.flags["P05"] = "yes"
	d.inventory = ["nothing", 3]
	d.notebook = ["R02.coat", "R02.nope", "Q.x", 4]
	d.room = "R77"
	d.visited = ["R01", "R77", 5]
	bad.from_dict(d)
	check(not bad.flag("P99") and not bad.flag("X01.y") and bad.flag("P04"), "unknown flags are dropped, real ones kept")
	check(not bad.flag("P05"), "a non-bool flag is dropped")
	check(bad.state.inventory.is_empty(), "unknown items are dropped")
	# Rooms re-note what their state implies (R01 at tide IV); unknown ids never survive.
	check("R02.coat" in bad.state.notebook and not "R02.nope" in bad.state.notebook
		and not "Q.x" in bad.state.notebook and not 4 in bad.state.notebook,
		"unknown observations are dropped (%s)" % [bad.state.notebook])
	check(bad.state.room == "R02", "an unknown room falls back to the office")
	check(not "R77" in bad.state.visited, "unknown visited rooms are dropped")
	# Settings are saved apart from the story and survive a restart.
	var s := GameSim.new()
	s.dispatch("menu"); s.dispatch("toggle_motion"); s.dispatch("toggle_soft")
	check(not s.to_dict().has("settings") and s.settings_dict() == {"motion": false, "soft_audio": true, "endings_seen": [], "plan_nudged": false},
		"settings apart")
	s.dispatch("resume"); s.dispatch("begin"); s.dispatch("restart")
	check(s.view == "title" and not s.settings.motion, "a restart keeps the settings")
	var u := GameSim.new()
	u.load_settings({"motion": "no", "soft_audio": true})
	check(u.settings.motion and u.settings.soft_audio, "malformed settings are ignored")
	# Derived flags follow the rooms that own them.
	var e: Dictionary = JSON.parse_string(JSON.stringify(GameSim.new().to_dict()))
	e.started = true
	e.flags = {"P01": true}
	var v := GameSim.new()
	v.from_dict(e)
	check(not v.flag("P01"), "P01 without the office's lamp is not restored")

func test_slice_migration() -> void:
	var slice := {"schema": 5, "started": true, "supply_on": true, "bridge_installed": true,
		"p01_complete": true, "log_read": true, "seen": ["lamp", "handwriting", "nope"],
		"motion": false, "soft_audio": true, "drawer_dial": [1, 8, 0, 0], "hint_level": 2}
	var g := GameSim.new()
	check(g.from_dict(slice), "a slice save (schema 5) loads")
	var s := g.room("R02") as R02Sim
	check(g.state.started and g.state.room == "R02" and g.view == "room", "migrated into the office")
	check(s.state.p01_complete and s.state.log_read and g.flag("P01"), "slice progress and P01 carried over")
	check(s.state.drawer_dial == [1, 8, 0, 0], "local state carried over")
	check(s.seen() == ["lamp", "handwriting"], "observations carried, unknown dropped")
	check(not g.settings.motion and g.settings.soft_audio, "slice settings carried over")
	check(g.state.visited == ["R02"], "the office counts as visited")
	var m := GameSim.migrate_slice({"schema": 5, "started": false})
	check(m.progress.schema == GameSim.SCHEMA and m.progress.visited.is_empty(), "migrate_slice output shape")
	check(not GameSim.new().from_dict({"schema": 4, "started": true}), "pre-slice saves are still rejected")

func test_debug_tide() -> void:
	for t in range(1, 10):
		var g := GameSim.new()
		g.debug_tide(t)
		check(g.tide() == t and g.state.started and g.view == "room" and g.state.room == "R02", "debug_tide %d" % t)
		var s := g.room("R02") as R02Sim
		check(s.state.finished == (t >= 2), "tide %d: the office chain is behind her iff t >= 2" % t)
		var r := roundtrip(g)
		check(r.tide() == t and r.state.visited == g.state.visited, "debug_tide %d survives a save" % t)
	var g := GameSim.new()
	g.debug_tide(5, "R09")
	check(g.state.room == "R09" and "R09" in g.state.visited, "debug_tide lands in the named room")
	g.debug_enter("R12")
	check(g.state.room == "R12" and g.flag("P12") and not g.flag("P24"), "debug_enter ignores gates, keeps flags")

func test_plan_travel() -> void:
	var g := GameSim.new()
	g.debug_tide(5)
	g.state.visited = ["R02", "R03", "R07"]
	g.dispatch("notebook")
	check(g.flag("P05"), "P05 is set by tide V")
	g.dispatch("plan:R07")
	check(g.state.room == "R07" and g.view == "room", "plan travel to a visited, reachable room")
	g.dispatch("notebook")
	g.dispatch("plan:R09")
	check(g.state.room == "R07" and g.view == "notebook", "no plan travel to an unvisited room")
	var h := GameSim.new()
	h.debug_tide(2)
	h.state.visited = ["R02", "R01"]
	h.dispatch("notebook")
	h.dispatch("plan:R01")
	check(h.state.room == "R02", "no plan before P05")

func test_endings() -> void:
	var g := GameSim.new()
	g.debug_tide(9, "R12")
	g.save_checkpoint()
	g.finish("sever")
	check(g.view == "end" and g.state.ending == "sever" and g.value("endings_seen") == ["sever"], "the severance ending")
	check(g.value("ending_choice") == "sever", "ending_choice reads the ending")
	var t := roundtrip(g)
	check(t.view == "end" and t.state.ending == "sever", "an ending save reopens its card")
	var ev := g.dispatch("return_decision")
	check(g.view == "room" and g.state.room == "R12" and g.state.ending == "" and g.value("endings_seen") == ["sever"],
		"return to the final decision keeps the endings seen")
	g.finish("continue")
	check(sorted(g.value("endings_seen")) == ["continue", "sever"], "both endings seen")
	g.finish("witness")
	check(g.state.ending == "continue", "only the cards' ending ids exist")
	g.dispatch("new_game")
	check(g.view == "title" and not g.state.started, "new game from the end card")
	check(sorted(g.value("endings_seen")) == ["continue", "sever"], "endings seen survive New game (flags.md)")
	var gs := GameSim.new()
	gs.load_settings(JSON.parse_string(JSON.stringify(g.settings_dict())))
	check(sorted(gs.value("endings_seen")) == ["continue", "sever"], "endings seen are saved with the settings")
	var bad: Dictionary = JSON.parse_string(JSON.stringify(GameSim.new().to_dict()))
	bad.started = true
	bad.ending = "sever"
	var b := GameSim.new()
	b.from_dict(bad)
	check(b.view == "room" and b.state.ending == "", "an ending without tide VIII complete is not restored")

func test_events_shape() -> void:
	var g := GameSim.new()
	var all: Array = []
	all.append_array(g.dispatch("begin"))
	for a in ["lamp", "toggle_supply", "select_b", "fit", "toggle_supply", "logbook", "back", "go:R01", "bell", "go:R02", "hint", "notebook", "back"]:
		all.append_array(g.dispatch(a))
	var ok := true
	for e in all:
		match e.type:
			"say":
				ok = ok and e.text is String and e.text != "" and (e.delay is float or e.delay is int) and e.story is bool
			"sfx":
				ok = ok and e.id is String and (e.delay is float or e.delay is int)
			"fx":
				ok = ok and e.id is String
			_:
				ok = false
	check(ok and all.size() > 10, "every event is say/sfx/fx with its fields")

# ---------------------------------------------------------------------------
# the game scene
# ---------------------------------------------------------------------------
func new_scene(path: String) -> Node:
	var scene = load("res://game/core/game.tscn").instantiate()
	scene.save_path = path
	scene.migrate_slice_save = false
	GameView.remove_saves(path)
	root.add_child(scene)
	return scene

func test_scene_rooms() -> void:
	var scene = new_scene("user://core_scene_test.json")
	await process_frame
	check(scene.room_view != null and scene.room_view.rid == "R02", "the office is mounted at the title")
	check(scene.action_at(Vector2(700, 500)) == "begin", "title click begins")
	scene.dispatch("begin")
	check(scene.action_at(Vector2(120, 950)) == "go:R01", "the jetty tab")
	check(scene.action_at(Vector2(330, 560)) == "lamp", "office hotspots still answer")
	scene.click(Vector2(120, 950))
	await process_frame
	check(scene.sim.state.room == "R01" and scene.room_view.rid == "R01", "travel swaps the room view")
	check(scene.room_view.get_script().resource_path.ends_with("R01_view.gd"), "the room's own view")
	var queued := [scene.cur_text]
	for l in scene.lines:
		queued.append(l.text)
	check(scene.sim.room("R01").c("ARRIVAL") in queued, "the arrival line is on screen or next")
	var bell: Rect2 = scene.room_view.hotspot_rect("bell")
	check(scene.action_at(bell.get_center()) == "bell", "skeleton hotspot")
	scene.tide_jump(9, "R12")
	await process_frame
	check(scene.room_view.rid == "R12" and scene.sim.tide() == 9, "tide jump mounts the chamber")
	scene.dispatch("go:R11")
	check(scene.room_view.rid == "R11", "R12 -> R11")
	for rid in ["R09", "R11", "R07", "R10", "R07", "R05", "R08", "R05", "R02", "R06", "R02", "R03", "R02", "R04"]:
		scene.dispatch("go:" + rid)
	check(scene.room_view.rid == "R04" and scene.sim.state.room == "R04", "walked every room at tide IX")
	scene.dispatch("hint")
	check(scene.hint_card_text() != "", "hint in a skeleton room")
	scene.dispatch("notebook")
	check(scene.action_at(scene.BACK_RECT.get_center()) == "back", "notebook Back")
	var tabs: Array = scene._notebook_tabs()
	check(tabs.size() >= 12 and tabs.back()[0] == "plan", "a tab per visited room, then the plan (%d)" % tabs.size())
	scene.dispatch("tab:plan")
	var row: Array = []
	for r in scene._plan_rows():
		if r[0] == "R02":
			row = r
	check(not row.is_empty() and scene.action_at(row[1].get_center()) == "plan:R02", "plan rows travel")
	scene.dispatch("plan:R02")
	await process_frame
	check(scene.sim.state.room == "R02" and scene.room_view.rid == "R02" and scene.sim.view == "room", "plan travel mounts the office")
	# The tide card on a tide change.
	scene.tide_jump(1)
	var s: R02Sim = scene.room_sim()
	s.debug_jump(5)
	scene.sim.set_flag("P02")
	var ev: Array = []
	scene.sim.solve("P03", ev)
	scene.play_events(ev)
	for i in 100:
		scene._process(0.1)
		if scene.tide_card_alpha() > 0.0:
			break
	check(scene.tide_card_n == 2 and scene.tide_card_t < scene.TIDE_CARD_TIME, "the tide card shows tide II")
	# Inventory slots (no room hands out items yet: the HUD is ready for them).
	check(scene._inv_rect(0) == Rect2(20, 22, 140, 50) and not scene._inv_rect(5).intersects(scene.BACK_RECT), "inventory slots clear of Back")
	GameView.remove_saves(scene.save_path)
	scene.queue_free()
	await process_frame

func test_scene_saves() -> void:
	var path := "user://core_save_test.json"
	var scene = new_scene(path)
	await process_frame
	scene.tide_jump(4, "R07")
	scene.dispatch("menu")
	scene.dispatch("toggle_motion")
	scene.dispatch("resume")
	check(FileAccess.file_exists(path) and FileAccess.file_exists(path.get_basename() + GameView.SETTINGS_SUFFIX), "progress and settings files")
	var again = load("res://game/core/game.tscn").instantiate()
	again.save_path = path
	again.migrate_slice_save = false
	root.add_child(again)
	await process_frame
	check(again.sim.state.room == "R07" and again.room_view.rid == "R07" and again.sim.tide() == 4, "reload lands in the lab at tide IV")
	check(not again.sim.settings.motion, "settings reload")
	check(again.lines.size() + (1 if again.cur_text != "" else 0) >= 1, "a resume line is queued")
	# A corrupt save falls back to the previous valid one.
	scene.dispatch("go:R05")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f = null
	var third = load("res://game/core/game.tscn").instantiate()
	third.save_path = path
	third.migrate_slice_save = false
	root.add_child(third)
	await process_frame
	check(third.sim.state.started and third.sim.tide() == 4, "a corrupt save falls back to the previous one")
	GameView.remove_saves(path)
	for n in [scene, again, third]:
		n.queue_free()
	await process_frame

# ---------------------------------------------------------------------------
# w1 core fixes
# ---------------------------------------------------------------------------
## P02 and P03 done, standing in the listening room (nothing left there), the log not
## re-read: "Now:" and the Hint point at the office.
func test_objective_elsewhere() -> void:
	var g := GameSim.new()
	g.dispatch("begin")
	(g.room("R02") as R02Sim).debug_jump(2)
	g.room("R04").state.p02_complete = true
	g.room("R03").state.p03_complete = true
	for rid in g.order:
		g.rooms[rid].reconcile()
	g.dispatch("go:R04")
	check(g.state.room == "R04" and g.tide_done(1) and not g.room("R02").state.log_rewritten, "fixture: Tide I's instruments done, in R04")
	var idle := g.room().objective()
	check(idle == "" or GameSim._idle(idle), "the listening room has nothing to do (%s)" % idle)
	var now := g.objective_text()
	check(now != "" and now.begins_with("Intake Office: "), "Now: names the Intake Office (%s)" % now)
	check(now == "Intake Office: " + g.room("R02").objective_text(), "Now: carries the office's own objective")
	# She has been in the office: no where-step (Now: names it), and none of its own
	# "Something ... has changed." tiers; straight to its ladder.
	var want := []
	for lv in g.room("R02").hint_tiers():
		var l: String = g.room("R02").hint_line(lv)
		if not GameSim._changed_line(l) and not l in want:
			want.append(l)
	want = GameSim.with_confirmation(want)   # the last tier waits for a second Hint
	var got := []
	for i in want.size():
		got.append(says(g.dispatch("hint")))
	check(got == want, "hints from R04: the office's own ladder, no stale room news (%s vs %s)" % [got, want])
	check(g.state.hint["for"] == "R04:->R02", "the hint key names the room it points at")
	for l in got:
		check(not GameSim._changed_line(l), "no 'Something in the ... has changed.' toward a visited room (%s)" % l)
	var ev: Array
	g.dispatch("go:R02")
	ev = g.dispatch("hint")
	check(says(ev) == g.room("R02").hint_line(0), "in the office the ladder starts over, on its own objective")
	var z := GameSim.new(FIXTURES)
	z.dispatch("begin")
	check(z.objective_text() != "", "a room with its own objective keeps it")

## At the start of every tide, wherever she stands, "Now:" and the Hint say something useful.
func test_objective_every_tide() -> void:
	for t in range(1, 10):
		var g := GameSim.new()
		g.debug_tide(t)
		for rid in g.reachable(g.start_room):
			g.debug_enter(rid)
			var open_p := false
			for p in GameSim.tide_puzzles(t):
				open_p = open_p or not g.flag(p)
			if not open_p:
				continue
			var now := g.objective_text()
			check(now != "" and now != GameSim.NOTHING_HERE, "tide %d in %s: Now: is not empty (%s)" % [t, rid, now])
			var ev := g.dispatch("hint")
			check(says(ev) != "" and says(ev) != GameSim.NOTHING_HERE, "tide %d in %s: the Hint says something" % [t, rid])

## The plan travels from a close-up: the close-up is put down first.
func test_plan_from_closeup() -> void:
	var g := GameSim.new()
	g.debug_tide(5)
	g.dispatch("lamp")
	check(g.room().local_view != "room", "fixture: the lamp close-up is open")
	g.dispatch("notebook")
	var ev := g.dispatch("plan:R04")
	check(g.state.room == "R04" and g.view == "room" and g.room().local_view == "room",
		"plan:R04 from the lamp close-up lands in R04's room view")
	check(g.room("R02").local_view == "room", "the office close-up was put down")
	check(has_ev(ev, "fx", "travel"), "a travel fx")

## A save standing behind a gate she hasn't opened loads in the office.
func test_load_behind_gate() -> void:
	var g := GameSim.new()
	g.dispatch("begin")
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	d.room = "R12"
	d.visited = ["R02", "R12"]
	var t := GameSim.new()
	check(t.from_dict(d), "the save loads")
	check(t.state.room == "R02", "R12 without P24 loads into the office (got %s)" % t.state.room)
	var h := GameSim.new()
	h.debug_tide(9, "R12")
	check(roundtrip(h).state.room == "R12", "R12 with P24 stays in R12")

## Every item in the game fits the bar: five to a page and a pager once there are more than six.
func test_inventory_paging() -> void:
	var scene = new_scene("user://core_inv_test.json")
	await process_frame
	scene.tide_jump(2)
	await process_frame
	var hud_rects := [scene.BACK_RECT]
	for b in scene.HUD_BUTTONS:
		hud_rects.append(b[1])
	# Six items: exactly as before, no pager.
	var defs: Dictionary = scene.sim.item_defs()
	var ids: Array = defs.keys()
	check(ids.size() > 6, "the game declares more than six items (%d)" % ids.size())
	scene.sim.state.inventory.clear()
	for i in 6:
		scene.sim.give(ids[i])
	var lay: Array = scene._inv_layout()
	check(lay.size() == 6, "six items: six slots")
	for i in 6:
		check(lay[i][0] == GameView._slot_rect(i) and lay[i][1] == "item:" + ids[i], "six items: slot %d unchanged" % i)
		check(scene.action_at(GameView._slot_rect(i).get_center()) == "item:" + ids[i], "six items: slot %d clicks its item" % i)
	# All of them.
	for id in ids:
		scene.sim.give(id)
	var pages: int = scene._inv_pages()
	check(pages == ceili(float(ids.size()) / 5.0), "pages of five (%d)" % pages)
	lay = scene._inv_layout()
	check(lay.size() == 6 and lay[5][1] == "inv_page" and lay[5][0] == GameView._slot_rect(5), "the pager is the sixth slot")
	var all_rects := []
	for slot in lay:
		check(not slot[0] in all_rects, "slot rects are unique")
		all_rects.append(slot[0])
		for r in hud_rects:
			check(not slot[0].intersects(r), "slot %s clear of Back and the HUD buttons" % slot[0])
	for id in ids:
		var found := false
		for k in pages + 1:
			for slot in scene._inv_layout():
				if slot[1] == "item:" + id and scene.action_at(slot[0].get_center()) == "item:" + id:
					found = true
			if found:
				break
			scene.click(GameView._slot_rect(5).get_center())
		check(found, "%s is reachable by paging" % id)
	check(scene.action_at(GameView._slot_rect(5).get_center()) == "inv_page", "the pager answers inv_page")
	check(scene._hover_label("item:" + ids[0]) == defs[ids[0]].name, "the tooltip has the full name")
	# Selecting keeps its page; using items up clamps the page.
	scene.inv_page = 0
	var last: String = ids[-1]
	scene.dispatch("item:" + last)
	check(scene._inv_page_shown() == pages - 1, "the selected item's page is shown")
	scene.dispatch("item:" + last)
	scene.inv_page = pages - 1
	for i in range(ids.size() - 1, 5, -1):
		scene.sim.take(ids[i])
	await process_frame
	check(scene._inv_page_shown() == 0 and scene.inv_page == 0 and scene._inv_layout().size() == 6, "used up: back to one page")
	check(not scene.sim.to_dict().has("inv_page"), "the inventory page is never saved")
	await free_scene(scene)

## Every note of the office and the chart room is drawn on some page, at 17 px or more, and
## no two overlap.
func test_notebook_pages() -> void:
	var scene = new_scene("user://core_nb_test.json")
	await process_frame
	scene.tide_jump(2)
	var g: GameSim = scene.sim
	for rid in ["R02", "R03"]:
		if not rid in g.state.visited:
			g.state.visited.append(rid)
		for id in g.room(rid).c("OBSERVATIONS", {}):
			g.observe(rid, id)
	scene.dispatch("notebook")
	var multi := false
	for rid in ["R02", "R03"]:
		scene.dispatch("tab:" + rid)
		var info: Dictionary = scene._nb_pagination(rid)
		var obs: Dictionary = g.room(rid).c("OBSERVATIONS", {})
		var drawn := []
		check(info.layout[0] >= 17, "%s: entries at 17 px or more (%d)" % [rid, info.layout[0]])
		for i in info.pages.size():
			var last: bool = i == info.pages.size() - 1
			var flow: Dictionary = scene._notebook_flow(scene.over, obs, info.pages[i], info.layout, info.top,
				info.bottom - (info.room_for if last else 0.0), GameView.NOTEBOOK_PAGE.position.x, false)
			check(flow.fits, "%s page %d fits" % [rid, i + 1])
			var rects: Array = flow.rects
			for a in rects.size():
				drawn.append(rects[a][0])
				check(GameView.NOTEBOOK_PAGE.encloses(rects[a][1]), "%s %s is on the page" % [rid, rects[a][0]])
				for b in range(a + 1, rects.size()):
					check(not rects[a][1].intersects(rects[b][1]), "%s: %s and %s don't overlap" % [rid, rects[a][0], rects[b][0]])
		check(sorted(drawn) == sorted(obs.keys()), "%s: every entry is on some page (%d of %d)" % [rid, drawn.size(), obs.size()])
		if info.pages.size() > 1:
			multi = true
			var newest: String = g.room(rid).seen()[-1]
			check(newest in info.pages[info.shown], "%s opens on the page with the newest entry" % rid)
			var btns: Array = scene._nb_page_buttons()
			check(btns.size() == 2, "%s: page buttons" % rid)
			scene.nb_page = 0
			check(scene.action_at(btns[1][0].get_center()) == "nbpage:next", "the next-page button")
			scene.click(btns[1][0].get_center())
			check(scene._nb_pagination(rid).shown == 1, "next page")
			scene.click(btns[0][0].get_center())
			check(scene._nb_pagination(rid).shown == 0, "previous page")
			for b in btns:
				check(not b[0].intersects(scene.BACK_RECT), "page buttons clear of Back")
		scene.over.queue_redraw()
		await process_frame
	check(multi, "at least one of the rooms needs more than one page")
	await free_scene(scene)

## A close-up re-reads the hover; Back in a close-up is one click even while a line types.
func test_hover_and_back() -> void:
	var scene = new_scene("user://core_hover_test.json")
	await process_frame
	scene.dispatch("begin")
	scene.hover_id = "lamp"
	scene.dispatch("lamp")
	check(scene.room_sim().local_view == "repair", "the lamp close-up")
	var p: Vector2 = scene.get_global_mouse_position()
	check(scene.hover_id == "" or scene.hover_id == scene.room_view.action_at(p),
		"no stale room label over the close-up (%s)" % scene.hover_id)
	scene._show_line("A long story line that is still typing itself out on the screen.", true)
	scene._queue_line("And another after it.", 0.5, true)
	check(scene.chain_active(), "a story line is playing")
	scene.click(scene.BACK_RECT.get_center())
	check(scene.room_sim().local_view == "room", "one click on Back leaves the close-up")
	var queued := false
	for l in scene.lines:
		queued = queued or l.text == "And another after it."
	check(queued or scene.cur_text == "And another after it.", "the story still queued keeps playing")
	await free_scene(scene)

## Between rooms: the old loops fade out under the game, the new ones start from silence.
func test_travel_fade() -> void:
	var scene = new_scene("user://core_fade_test.json")
	await process_frame
	scene.dispatch("begin")
	for i in 3:
		await process_frame
	var old: Array = GameView._mixers_in(scene.room_view)
	check(not old.is_empty(), "the office has loops")
	scene.cur_text = "A feedback line."
	scene.cur_story = false
	scene.dispatch("go:R01")
	check(scene.room_view.rid == "R01", "travel to the jetty")
	for m in old:
		check(is_instance_valid(m) and m.get_parent() == scene and not scene.world.is_ancestor_of(m),
			"the office's mixer is handed to the game, not left under the world")
	var fresh: Array = GameView._mixers_in(scene.room_view)
	check(not fresh.is_empty(), "the jetty has loops")
	for m in fresh:
		for id in m.mix:
			check(m.mix[id] == 0.0, "the jetty's %s starts from silence" % id)
	check(scene.travel_dip_t == 0.0, "the storm-navy dip starts")
	check(scene.cur_text != "A feedback line.", "the office's feedback line stays behind")
	check(scene.came_from == "R02", "she came from the office")
	scene._tick_fading_mixers(0.5)
	check(scene.fading_mixers.is_empty(), "the old loops are gone after the fade")
	scene.sim.settings.motion = false
	scene.travel_dip_t = 5.0
	scene.dispatch("go:R02")
	check(scene.travel_dip_t == 5.0, "Motion off: no dip")
	scene.sim.settings.motion = true
	await free_scene(scene)

## The tide card sits high and is brief; the subtitle slab is only up when a line is.
func test_card_and_slab() -> void:
	var scene = new_scene("user://core_card_test.json")
	await process_frame
	scene.dispatch("begin")
	check(GameView.TIDE_CARD_RECT == Rect2(40, 840, 560, 110) and GameView.TIDE_CARD_TIME == 2.2, "card rect and time")
	scene.tide_card_n = 2
	for pair in [[0.0, 0.0], [0.25, 0.5], [1.1, 1.0], [1.95, 0.5], [2.2, 0.0]]:
		scene.tide_card_t = pair[0]
		check(absf(scene.tide_card_alpha() - pair[1]) < 0.01, "card alpha at %.2f s" % pair[0])
	scene.sim.settings.motion = false
	for pair in [[0.0, 1.0], [2.1, 1.0], [2.3, 0.0]]:
		scene.tide_card_t = pair[0]
		check(scene.tide_card_alpha() == pair[1], "Motion off: card alpha at %.1f s" % pair[0])
	scene.sim.settings.motion = true
	scene._reset_presentation()
	scene.slab_a = 1.0
	scene._queue_line("Later.", 3.0)
	for i in 10:
		scene.time += 0.1
		scene._tick_lines(0.1)
	check(scene.slab_a == 0.0 and scene.cur_text == "", "no slab while the next line is seconds away")
	for i in 20:
		scene.time += 0.1
		scene._tick_lines(0.1)
	check(scene.cur_text == "Later." and scene.slab_a > 0.0, "the slab comes up with the line")
	await free_scene(scene)

## Wave 3 built R09-R12: no room shows the placeholder card. The card itself stays for a
## bare RoomView (a room whose view scene is missing).
func test_placeholder() -> void:
	var bare := RoomView.new()
	check(bare.is_skeleton(), "a bare RoomView is still a skeleton (the placeholder card)")
	bare.free()
	for rid in GameSim.new().order:
		var v: RoomView = load("res://game/rooms/%s/%s_view.tscn" % [rid, rid]).instantiate()
		check(not v.is_skeleton(), "%s's view is built" % rid)
		v.free()
	var scene = new_scene("user://core_ph_test.json")
	await process_frame
	scene.tide_jump(4, "R03")
	scene.dispatch("go:R11")
	check(scene.room_view.rid == "R11" and not scene.room_view.is_skeleton(), "the stair landing is built")
	for i in 60:   # past the stair's first-arrival hold
		scene._process(0.1)
	var live: Dictionary = scene.room_view.live_exit_rects()
	check(live.has("R03") and scene.action_at(live["R03"].get_center()) == "go:R03", "the way back to the chart room answers")
	scene.tide_jump(9, "R11")
	scene.dispatch("go:R12")
	check(scene.sim.state.room == "R12" and not scene.room_view.is_skeleton(), "the chamber is built")
	check(scene.room_view.live_exit_rects().has("R11"), "the chamber offers the way back to the stair")
	scene.over.queue_redraw()
	await process_frame
	await free_scene(scene)

func free_scene(scene: Node) -> void:
	GameView.remove_saves(scene.save_path)
	scene.queue_free()
	await process_frame

# ---------------------------------------------------------------------------
# wave 2 core fixes
# ---------------------------------------------------------------------------
## The state real play leaves after chain step `pid` (tests/chain_test.gd stopped there).
func chain_at(pid: String) -> GameSim:
	var ch = load("res://tests/chain_test.gd").new()
	ch.stop_after = pid
	await ch.run_tests()
	check(ch.failures.is_empty(), "the chain plays to %s (%s)" % [pid, ch.failures])
	var g: GameSim = ch.g
	ch.free()
	return g

## A scene whose sim is `g` (a played state), with clean presentation.
func scene_with(path: String, g: GameSim) -> Node:
	var scene = new_scene(path)
	await process_frame
	scene.sim.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	scene._mount_room()
	scene._reset_presentation()
	return scene

## An item in hand on an exit tab: the room may take it; else she puts it away and goes.
func test_item_on_exit() -> void:
	var g := GameSim.new(FIXTURES)
	g.dispatch("begin")
	g.dispatch("shelf")
	g.dispatch("item:key")
	var ev := g.dispatch("go:Z02")
	check(g.state.room == "Z01" and g.selected_item == "" and not has_ev(ev, "fx", "travel")
		and says(ev) == "The key is for the box, not the door.", "the room takes the key at its exit: no travel, item put away")
	var o := GameSim.new()
	o.debug_tide(2, "R02")
	o.give("pencil")
	o.dispatch("item:pencil")
	o.dispatch("go:R01")
	check(o.state.room == "R01" and o.selected_item == "", "an item the room doesn't take: put away, and she goes")

## Inventory slots stay legible: every item's slot label (short, else name) is 14 or fewer.
## KNOWN lists room items still too long, each a bug for its room team; an entry that has
## been fixed fails here too, so the list only shrinks.
const ITEM_LABEL_MAX := 14
const ITEM_LABEL_KNOWN := {}

func test_item_labels() -> void:
	var defs := GameSim.new().item_defs()
	for id in defs:
		var d: Dictionary = defs[id]
		var label: String = d.get("short", d.get("name", id))
		var ok := label.length() <= ITEM_LABEL_MAX
		if ITEM_LABEL_KNOWN.has(id):
			check(not ok, "%s's slot label is short now: drop it from ITEM_LABEL_KNOWN" % id)
			if not ok:
				print("ROOM BUG (%s): item %s's slot label '%s' is %d characters (max %d)" % [d.room, id, label, label.length(), ITEM_LABEL_MAX])
		else:
			check(ok, "%s (%s): slot label '%s' is %d characters (max %d)" % [id, d.room, label, label.length(), ITEM_LABEL_MAX])

## The way into a room she hasn't been in; no step says the same thing twice; saves keep the level.
func test_hint_ladder() -> void:
	var g: GameSim = await chain_at("P06")
	check(g.work_elsewhere() == "R05" and not "R05" in g.state.visited, "after P06 the work is in the unvisited kitchen")
	var r5: RoomSim = g.room("R05")
	var want := "The kitchen and mess is through the intake office."
	var ev := g.dispatch("hint")
	check(says(ev) == want, "an unvisited room: through the visited room that leads there (%s)" % says(ev))
	# With no visited neighbour, the room's own WAY_IN_HINT.
	var lone := GameSim.new()
	lone.debug_tide(3, "R02")
	lone.state.visited = ["R01"]
	var wl: Array = lone._elsewhere_ladder("R05")
	check(wl[0] == r5.c("WAY_IN_HINT", "The way into the kitchen and mess is open now."),
		"no visited neighbour: the way-in hint (%s)" % wl[0])
	g = await chain_at("P03")
	g.debug_enter("R04")
	var lines := []
	for i in 4:
		lines.append(says(g.dispatch("hint")))
	for i in 3:
		check(lines[i] == lines[-1] or GameSim._hint_key(lines[i]) != GameSim._hint_key(lines[i + 1]),
			"after P03 in R04: hint %d and %d differ (%s)" % [i, i + 1, lines])
	check(not ("Something in the intake office has changed." in lines and "Something in the office has changed." in lines),
		"the ladder says where once (%s)" % [lines])
	var trimmed := lines.duplicate()   # the ladder may stop on its last rung; nothing else repeats
	while trimmed.size() > 1 and trimmed[-1] == trimmed[-2]:
		trimmed.pop_back()
	for i in trimmed.size():
		check(trimmed.find(trimmed[i]) == i, "no hint line repeats (%s)" % [lines])
	for presses in [1, 2, 3, 6]:
		var h := GameSim.new()
		h.debug_tide(1, "R02")
		h.dispatch("begin")
		for i in presses:
			h.dispatch("hint")
		var lv: int = h.state.hint.level
		check(lv <= GameSim.HINT_LEVEL_MAX, "the hint level stays clamped (%d after %d presses)" % [lv, presses])
		check(roundtrip(h).state.hint.level == lv, "a save keeps hint.level %d" % lv)

## Every room is built: no exit is marked, and "Now:" never names the build's end.
func test_build_end() -> void:
	var g := GameSim.new()
	for rid in g.order:
		check(not g.is_unbuilt(rid), "%s is built" % rid)
	g = await chain_at("P11")
	var now := g.objective_text()
	check(now != GameSim.BUILD_END_NOW and now.begins_with("Dry Stair: "), "after P11, Now: points at the stair (%s)" % now)
	check(says(g.dispatch("hint")) != GameSim.BUILD_END_HINT, "after P11, the Hint is a real step")
	g.debug_enter("R11")
	check(g.objective_text() != GameSim.BUILD_END_NOW, "standing in the stair: real work")
	var scene = new_scene("user://core_unbuilt_test.json")
	await process_frame
	scene.tide_jump(2, "R03")
	for rid in ["R02", "R04", "R11"]:
		check(not "not yet built" in scene.exit_tab_label(rid), "the chart room's %s tab is plain (%s)" % [rid, scene.exit_tab_label(rid)])
	check(not "not yet built" in scene._hover_label("go:R11"), "the stair's hover label is plain (%s)" % scene._hover_label("go:R11"))
	await free_scene(scene)

func key(scene: Node, code: Key) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	scene._unhandled_input(k)

## Exits, Back, the inventory and the notebook's rows always act, chain or no chain.
func test_clicks_never_eaten() -> void:
	var scene = new_scene("user://core_clicks_test.json")
	await process_frame
	scene.tide_jump(8, "R04")
	scene.click(scene.room_view.hotspot_rect("printer").get_center())
	check(scene.chain_active(), "the printer's transcript is a story chain")
	key(scene, KEY_N)
	check(scene.sim.view == "notebook", "N opens the notebook during the chain")
	var tab := Rect2()
	for t in scene._notebook_tabs():
		if t[0] == "plan":
			tab = t[1]
	scene.click(tab.get_center())
	check(scene.sim.nb_tab == "plan", "one click on the plan tab during the chain")
	var row := Rect2()
	for r in scene._plan_rows():
		if r[0] == "R02":
			row = r[1]
	check(scene.chain_active(), "the chain is still playing")
	scene.click(row.get_center())
	check(scene.pending_travel == "plan:R02" or (scene.sim.state.room == "R02" and scene.sim.view == "room"),
		"one click on the Office row: she goes once the transcript has played (%s)" % scene.pending_travel)
	for i in 300:
		if scene.sim.state.room == "R02":
			break
		scene._process(0.1)
	check(scene.sim.state.room == "R02" and scene.sim.view == "room", "the Office row travels (%s)" % scene.sim.state.room)
	# A double click on an exit moves one room.
	scene.tide_jump(2, "R02")
	var tab_r: Rect2 = scene.room_view.live_exit_rects()["R04"]
	scene.click(tab_r.get_center())
	check(scene.sim.state.room == "R04", "the exit click travels")
	scene.time += 0.1
	scene.click(tab_r.get_center())
	var exits: Dictionary = scene.room_view.live_exit_rects()
	var p: Vector2 = exits[exits.keys()[0]].get_center()
	scene.click(p)
	check(scene.sim.state.room == "R04", "a second exit click within 0.4 s is ignored")
	scene.time += 0.5
	scene.click(p)
	check(scene.sim.state.room != "R04", "after 0.4 s the exits answer again")
	# Back right after opening a close-up, chain or not, is one click.
	for c in [[2, "R03", "recorder"], [2, "R04", "spindle"], [2, "R03", "plate_rack"], [5, "R03", "recorder"]]:
		scene.tide_jump(c[0], c[1])
		scene.dispatch(c[2])
		check(scene.room_sim().is_closeup(), "%s %s opens its close-up" % [c[1], c[2]])
		scene.click(scene.BACK_RECT.get_center())
		check(scene.room_sim().local_view == "room", "%s %s: Back works on the first click" % [c[1], c[2]])
		scene.dispatch(c[2])
		scene._show_line("A story line still being read on the screen.", true)
		scene._queue_line("And one more after it.", 0.5, true)
		scene.click(scene.BACK_RECT.get_center())
		check(scene.room_sim().local_view == "room", "%s %s: Back during a chain is one click" % [c[1], c[2]])
	# An item slot during a chain: the chain advances and the item is in hand.
	scene.tide_jump(3, "R02")
	scene._show_line("A story line still being read on the screen.", true)
	scene._queue_line("And one more after it.", 0.5, true)
	scene.time += 1.0
	var slot: Array = scene._inv_layout()[0]
	scene.click(slot[0].get_center())
	check(scene.sim.selected_item == slot[1].substr(5), "an inventory click during a chain selects the item")
	check(scene.cur_text == "A story line still being read on the screen." and scene.pending_action == "",
		"and the chain is neither advanced nor waited on (%s)" % scene.cur_text)
	await free_scene(scene)

## Hover labels sit clear of the controls they name.
func test_hover_label_rects() -> void:
	var scene = new_scene("user://core_hover_rects_test.json")
	await process_frame
	for c in [[4, "R05", "c_service_board"], [4, "R05", "c_ledger"], [3, "R06", "c_lockers"], [5, "R07", "c_frame"]]:
		scene.tide_jump(c[0], c[1])
		scene.room_sim().local_view = c[2]
		var v: RoomView = scene.room_view
		var rows: Array = v.closeup_controls(c[2]) if v.has_method("closeup_controls") else v.call("_controls")
		check(not rows.is_empty(), "%s %s has controls" % [c[1], c[2]])
		for h in rows:
			var r: Rect2 = h[1]
			check(scene.hover_target_rect(h[0]) == r, "%s %s: %s's rect is found" % [c[1], c[2], h[0]])
			for m in [r.get_center(), r.position + Vector2(2, 2), r.end - Vector2(2, 2)]:
				var box: Rect2 = scene.hover_label_rect(h[0], m)
				if box.size == Vector2.ZERO:
					continue
				check(not box.intersects(r), "%s %s: %s's label clears it" % [c[1], c[2], h[0]])
				check(GameView.SIZE.x - box.end.x >= GameView.HOVER_MARGIN - 0.01 and box.position.x >= GameView.HOVER_MARGIN - 0.01
					and box.position.y >= 0.0 and box.end.y <= GameView.SIZE.y, "%s %s: %s's label is on screen" % [c[1], c[2], h[0]])
	# An exit label near the right edge stays on screen.
	scene.tide_jump(2, "R02")
	for to in scene.room_view.live_exit_rects():
		var box: Rect2 = scene.hover_label_rect("go:" + to, Vector2(1440, 960))
		check(box.end.x <= GameView.SIZE.x - GameView.HOVER_MARGIN + 0.01 and box.end.y <= GameView.SIZE.y,
			"the %s exit label stays on screen" % to)
	# Travel clears the hover.
	scene.hover_id = "go:R01"
	scene.dispatch("go:R01")
	check(scene.hover_id == "", "travel clears the hover label")
	await free_scene(scene)

const SPY_VIEW := """extends RoomView
var glances := []
var consume := false
var own_glance := true
func start_glance(id: String, r: Rect2) -> bool:
	glances.append([id, r])
	return own_glance
func consume_click(_p: Vector2) -> bool:
	return consume
func back_label() -> String:
	return "Stand up"
func exit_arrow(to: String) -> String:
	return "down" if to == "R01" else ""
var asked := 0
var answer := ""
func action_at(p: Vector2) -> String:
	asked += 1
	return answer if answer != "" else super(p)
"""

## A spy view standing in for the current room's own (same sim, same rid).
func spy_view(scene: Node) -> RoomView:
	var s := GDScript.new()
	s.source_code = SPY_VIEW
	s.reload()
	var v: RoomView = s.new()
	var old: RoomView = scene.room_view
	v.game = scene
	v.rid = old.rid
	v.sim = old.sim
	scene.world.remove_child(old)
	old.queue_free()
	scene.world.add_child(v)
	scene.room_view = v
	return v

## The glance: after its chain, the close-up is put down and the reward is shown.
func test_glance() -> void:
	var scene = new_scene("user://core_glance_test.json")
	await process_frame
	scene.dispatch("begin")
	scene.dispatch("lamp")
	check(scene.room_sim().local_view == "repair", "in the lamp close-up")
	var v := spy_view(scene)
	var ev: Array = []
	var fake := RoomSim.new()
	fake._say(ev, "The drawer is deeper than the desk.", 0.0, true)
	fake._say(ev, "It goes on under the floor.", 1.0, true)
	fake._fx(ev, "glance", {"rect": [200, 300, 240, 160], "id": "drawer"})
	check(ev[-1].get("target") == "drawer" and ev[-1].id == "glance" and ev[-1].rect == [200, 300, 240, 160],
		"RoomSim._fx carries extras (an extra id as target)")
	scene.play_events(ev)
	for i in 3:
		scene._process(0.1)
	check(scene.chain_active() and v.glances.is_empty() and scene.room_sim().local_view == "repair",
		"no glance while the chain plays")
	for i in 100:
		scene._process(0.1)
	check(scene.room_sim().local_view == "room", "after the chain the close-up is put down")
	check(v.glances.size() == 1 and v.glances[0] == ["drawer", Rect2(200, 300, 240, 160)], "start_glance once, with the rect (%s)" % [v.glances])
	check(scene.glance_alpha() == 0.0, "the room showed it: no core brackets")
	# A room without a glance of its own: the core's brackets.
	v.own_glance = false
	scene.play_events([{"type": "fx", "id": "glance", "rect": [10, 20, 30, 40], "target": "x"}])
	scene._process(0.1)
	scene._process(0.1)
	check(scene.glance_rect == Rect2(10, 20, 30, 40) and scene.glance_alpha() > 0.0, "the core brackets the rect")
	scene.sim.settings.motion = false
	check(scene.glance_alpha() == 1.0, "Motion off: the brackets are simply there")
	scene.sim.settings.motion = true
	for i in 30:
		scene._process(0.1)
	check(scene.glance_alpha() == 0.0, "gone after GLANCE_TIME")
	scene.play_events([{"type": "fx", "id": "glance", "rect": [10, 20, 30, 40], "target": "x"},
		{"type": "fx", "id": "travel", "from": "R02", "to": "R02"}])
	check(scene.pending_glance.is_empty(), "travel drops a waiting glance")
	await free_scene(scene)

## The room sees its click first; action_at stays pure.
func test_consume_click() -> void:
	var scene = new_scene("user://core_consume_test.json")
	await process_frame
	scene.dispatch("begin")
	var lamp: Vector2 = scene.room_view.hotspot_rect("lamp").get_center()
	var v := spy_view(scene)
	check(RoomView.new().consume_click(Vector2.ZERO) == false, "consume_click takes nothing by default")
	v.consume = true
	v.answer = "lamp"
	var id0: int = scene.click_id
	scene.click(lamp)
	check(scene.click_id == id0 and scene.room_sim().local_view == "room" and v.asked == 0,
		"a consumed click does nothing more (the room's action_at is not even asked)")
	scene.click(GameView.HUD_BUTTONS[0][1].get_center())
	check(scene.sim.view == "notebook", "the HUD answers before the room sees the click")
	scene.dispatch("back")
	v.consume = false
	scene.click(lamp)
	check(scene.room_sim().local_view == "repair", "an unconsumed click reaches the hotspot")
	scene.click(scene.BACK_RECT.get_center())
	check(scene.room_sim().local_view == "room", "Back")
	await free_scene(scene)

## back_label and exit_arrow; their defaults.
func test_room_hooks() -> void:
	var base := RoomView.new()
	check(base.back_label() == "Back" and base.exit_arrow("R01") == "" and not base.start_glance("", Rect2()),
		"the RoomView defaults")
	base.free()
	var scene = new_scene("user://core_hooks_test.json")
	await process_frame
	scene.tide_jump(2, "R02")
	var plain: String = scene.exit_tab_label("R01")
	check(plain.begins_with("◂ ") or plain.ends_with(" ▸"), "the default arrow follows the tab's side (%s)" % plain)
	var v := spy_view(scene)
	check(scene.exit_tab_label("R01").begins_with("▾ "), "exit_arrow down (%s)" % scene.exit_tab_label("R01"))
	check(v.back_label() == "Stand up", "back_label")
	scene.hud.queue_redraw()
	await process_frame
	await free_scene(scene)

## A full-screen moment (R02's Tide I end card): no notebook, hint or menu from keys or the HUD.
func test_cinematic_keys() -> void:
	var scene = new_scene("user://core_cine_test.json")
	await process_frame
	scene.room_jump("R02", 5)
	scene.room_sim().local_view = "end"
	check(scene.room_view.hud_hidden(), "the end view hides the HUD")
	var sub: String = scene.subtitle.text
	key(scene, KEY_N)
	key(scene, KEY_H)
	check(scene.sim.view == "room" and scene.room_sim().local_view == "end" and scene.subtitle.text == sub
		and scene.cur_text == "" , "N and H do nothing during the end card")
	for b in GameView.HUD_BUTTONS:
		scene.click(b[1].get_center())
		check(scene.sim.view == "room" and scene.room_sim().local_view == "end", "the hidden HUD's %s does nothing" % b[0])
	scene.room_sim().local_view = "room"
	await free_scene(scene)

# ---------------------------------------------------------------------------
# wave 3 core fixes
# ---------------------------------------------------------------------------
## After P01 and P02, with P03 open, "Now:" from the listening room points at the chart room.
func test_closeup_now_and_plan() -> void:
	var g: GameSim = await chain_at("P02")
	check(g.flag("P01") and g.flag("P02") and not g.flag("P03"), "fixture: P01, P02 done, P03 open")
	g.debug_enter("R04")
	var now := g.objective_text()
	check(now.begins_with("Chart Room:"), "Now: after P02 from R04 names the chart room (%s)" % now)
	check(g.objective_puzzle("R03") == "P03" and g.puzzle_open("P03"), "R03's objective is the open P03")
	check(not g.puzzle_open("P02") and not g.puzzle_open("P04"), "solved and gated puzzles are not open")

func test_end_card_lines() -> void:
	check(GameSim.ENDINGS.sever.lines == ["I write eight names. Then his.", "\"I cannot certify their absence.\""],
		"the severance card's lines")
	check(GameSim.ENDINGS.continue.lines.size() == 2, "the continuation card keeps its lines")
	check(GameSim.ENDINGS.sever.still == ["res://assets/stages/R12/r12_sever_office_r2.png", "res://assets/rooms/R12/end_a_page.png"]
		and GameSim.ENDINGS.continue.still == ["res://assets/stages/R12/end_b_wide_3.png", "res://assets/rooms/R12/end_b_field.png"],
		"each ending prefers R12's newer still, then the earlier one")
	for id in GameSim.ENDINGS:
		var paths: Array = GameSim.ENDINGS[id].still
		var want: String = paths[0] if ResourceLoader.exists(paths[0]) else (paths[1] if ResourceLoader.exists(paths[1]) else "")
		check(GameView.end_still_path(id) == want, "%s: the first still that exists is drawn (%s)" % [id, GameView.end_still_path(id)])

## An ending's lines still queued when the card goes up never follow her back into R12.
func test_end_clears_lines() -> void:
	var scene = new_scene("user://core_end_lines_test.json")
	await process_frame
	scene.tide_jump(9, "R12")
	scene.sim.save_checkpoint()
	scene._show_line("An ending line, still on the screen.", true)
	scene._queue_line("An ending line, still queued.", 1.5, true)
	scene.sim.finish("sever")
	scene._mount_room()
	scene.end_t = 2.0
	check(scene.end_still("sever") != null, "the severance still loads")
	check(scene.end_still("nowhere") == null, "a missing still is nothing")
	scene._redraw()
	await process_frame   # the card draws, still and all
	scene.dispatch("return_decision")
	check(scene.sim.view == "room" and scene.sim.state.room == "R12", "back at the decision")
	var stale := false
	for l in scene.lines:
		stale = stale or l.text.begins_with("An ending line")
	check(not stale and not scene.cur_text.begins_with("An ending line") and not scene.subtitle.text.begins_with("An ending line"),
		"no ending line survives return_decision (%s / %s)" % [scene.cur_text, scene.lines])
	await free_scene(scene)

## A load lands in resume_view(): "room" for every room unless it overrides it.
func test_resume_view() -> void:
	var g := GameSim.new()
	for rid in g.order:
		check(g.room(rid).resume_view() == "room", "%s: a fresh game resumes in 'room' (%s)" % [rid, g.room(rid).resume_view()])
		check(g.room(rid).local_view == "room", "%s: a fresh game is at 'room'" % rid)
	var h := GameSim.new()
	h.debug_tide(5, "R02")
	h.dispatch("lamp")
	var t := roundtrip(h)
	for rid in t.order:
		if rid != t.state.room:
			check(t.room(rid).local_view == "room", "%s: a load leaves other rooms at 'room'" % rid)

## A "go:X" that is no way out of here does nothing; no say ever has empty text.
func test_travel_outside_graph() -> void:
	var g: GameSim = await chain_at("P26")
	check(g.state.room == "R12", "fixture: in the chamber after P26")
	var r12: RoomSim = g.room("R12")
	for i in 4:
		if r12.local_view != "room":
			g.dispatch("back")
	for a in ["to_routing", "contacts", "tray", "contacts", "preview", "btn_sever", "ending_next"]:
		g.dispatch(a)
	check(g.view == "room" and g.flag("P27"), "fixture: mid-ending in R12 (%s/%s)" % [g.view, r12.local_view])
	var latch: String = g.room("R03").locked_line()
	for to in ["R03", "R02"]:
		var ev := g.dispatch("go:" + to)
		var empty := false
		for e in ev:
			empty = empty or (e.type == "say" and e.text == "")
		check(not empty, "mid-ending go:%s: no empty say" % to)
		check(not latch in says(ev), "mid-ending go:%s: no Tide I latch line (%s)" % [to, says(ev)])
		check(g.state.room == "R12" and not has_ev(ev, "fx", "travel"), "mid-ending go:%s: she stays" % to)
		check(ev.is_empty(), "go:%s is no exit of R12: no events (%s)" % [to, ev])
	# Every room of a fully flagged game: every hotspot, exit and core action has words or none.
	for rid in GameSim.new().order:
		var f := GameSim.new()
		f.debug_tide(9, rid)
		var acts: Array = f.room().c("HOTSPOTS", []).duplicate()
		for e in f.exits():
			acts.append("go:" + e[0])
		acts.append_array(["go:R99", "go:" + rid, "hint", "back", "nonsense"])
		for a in acts:
			f.debug_enter(rid)
			for e in f.dispatch(a):
				if e.type == "say":
					check(e.text != "", "%s %s: a say with empty text" % [rid, a])

## Spent items are filed in the notebook: off the bar, never handed back, saved, shown.
func test_retired_items() -> void:
	var g := GameSim.new()
	g.debug_tide(7, "R02")
	g.give("pencil")
	check(g.has_item("venn_correspondence") and g.has_item("pencil"), "fixture: the letters and the pencil in hand")
	g.set_flag("P20")
	g.set_flag("P22")
	check(g.dispatch("hint").all(func(e): return e.get("text", "") != GameSim.FILED_LINE),
		"flags set before the action (a debug jump) file nothing")
	g.state.flags.erase("P20")
	g.state.flags.erase("P22")
	var snap := g._spent_snapshot()
	g.set_flag("P20")
	g.set_flag("P22")
	var ev := [{"type": "say", "text": "A commit's last line.", "delay": 1.2, "story": true}]
	g._file_spent(snap, ev)
	var filed := 0
	for e in ev:
		if e.type == "say" and e.text == GameSim.FILED_LINE:
			filed += 1
			check(not e.story, "the filed line is not a story line")
	check(filed == 1, "two items filed, one line (%d)" % filed)
	check(ev[-1].type == "say" and ev[-1].text == GameSim.FILED_LINE and ev[-1].delay > 1.2, "the filed line ends the chain")
	check(not g.has_item("venn_correspondence") and not g.has_item("pencil"), "both spent items leave the bar")
	check(g.retired().slice(-2) == ["venn_correspondence", "pencil"], "retired, in order (%s)" % [g.retired()])
	g.give("pencil")
	check(not g.has_item("pencil"), "a retired item is never handed back")
	for rid in g.order:
		g.rooms[rid].reconcile()
	check(not g.has_item("pencil") and not g.has_item("venn_correspondence"), "reconciles don't hand them back")
	var t := roundtrip(g)
	check(t.retired() == g.retired() and not t.has_item("pencil"), "a save keeps state.retired")
	var bad: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	bad.inventory.append("pencil")
	bad.retired.append("not_an_item")
	var b := GameSim.new()
	b.from_dict(bad)
	check(not b.has_item("pencil") and b.retired() == g.retired(), "a tampered save can't hold a retired item")
	check(says(g.dispatch("hint")).find(GameSim.FILED_LINE) < 0, "the filed line is said once")
	for item in GameSim.ITEM_RETIRES_AFTER:
		check(g.item_defs().has(item), "%s is a real item" % item)

## Plan travel lands exactly where walking the exits does.
func test_plan_equals_walking() -> void:
	var a := GameSim.new()
	a.debug_tide(7, "R10")
	var b := GameSim.new()
	b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	var trace: Array = a.value("p05_trace")
	check(a.plan_unlocked() and "R04" in a.state.visited, "fixture: the plan is hers, R04 visited")
	a.dispatch("notebook")
	var ev_plan := a.dispatch("plan:R04")
	var ev_walk: Array = []
	var hops := _hops(b, "R10", "R04")
	check(not hops.is_empty(), "R04 is walkable from R10")
	for hop in hops:
		ev_walk = b.dispatch("go:" + hop)
	check(a.state.room == "R04" and b.state.room == "R04", "both in R04 (%s, %s)" % [a.state.room, b.state.room])
	check(JSON.stringify(a.room("R04").state) == JSON.stringify(b.room("R04").state), "the same R04 state (notices included)")
	check(sorted(a.state.visited) == sorted(b.state.visited), "the same visited set")
	check(says(ev_plan) == says(ev_walk), "the same arrival (%s vs %s)" % [says(ev_plan), says(ev_walk)])
	check(a.value("p05_trace") == trace and b.value("p05_trace") == trace, "P05's frozen trace is unaffected")

func _hops(g: GameSim, from: String, to: String) -> Array:
	var prev := {from: ""}
	var queue := [from]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for e in g.exits(cur):
			if not prev.has(e[0]) and g.exit_open(cur, e[0]):
				prev[e[0]] = cur
				queue.append(e[0])
	if not prev.has(to):
		return []
	var out := []
	var cur := to
	while cur != from:
		out.push_front(cur)
		cur = prev[cur]
	return out

## The Plan button: only once the plan is hers, never over the title, menu, end or a
## cinematic; one click opens the notebook on the plan.
func test_plan_button() -> void:
	var scene = new_scene("user://core_plan_button_test.json")
	await process_frame
	var p: Vector2 = GameView.PLAN_BUTTON[1].get_center()
	scene.tide_jump(2, "R02")
	check(not scene.plan_button_shown() and scene.action_at(p) != "plan", "no Plan before P05")
	scene.tide_jump(4, "R02")
	check(scene.plan_button_shown() and scene.action_at(p) == "plan", "the Plan after P05")
	scene.click(p)
	check(scene.sim.view == "notebook" and scene._nb_page() == "plan", "one click: the notebook on the plan")
	check(not scene.plan_button_shown() and scene.action_at(p) != "plan", "the notebook has its Plan tab, Back its place")
	scene.dispatch("back")
	scene.dispatch("lamp")
	check(scene.room_sim().is_closeup() and not scene.plan_button_shown(), "no Plan over a close-up (Back's place)")
	scene.dispatch("back")
	scene.dispatch("menu")
	check(not scene.plan_button_shown(), "no Plan over the menu")
	scene.dispatch("resume")
	check(scene.plan_button_shown(), "the Plan is back with the room")
	# Its rect is clear of every room's exit tabs and room hotspots wherever it shows.
	for rid in scene.sim.order:
		scene.tide_jump(9, rid)
		for r in scene.room_view.live_exit_rects().values():
			check(not r.intersects(GameView.PLAN_BUTTON[1]), "%s: an exit tab under the Plan button" % rid)
		var hit := ""
		var pr: Rect2 = GameView.PLAN_BUTTON[1]
		for y in range(int(pr.position.y) + 4, int(pr.end.y), 6):
			for x in range(int(pr.position.x) + 4, int(pr.end.x), 6):
				var a: String = scene.room_view.action_at(Vector2(x, y))
				if a != "" and hit == "":
					hit = a
		check(hit == "" or PLAN_OVERLAP_KNOWN.get(rid, []).has(hit), "%s: room hotspot '%s' under the Plan button" % [rid, hit])
	scene.sim.view = "title"
	check(not scene.plan_button_shown(), "no Plan on the title")
	scene.tide_jump(9, "R12")
	scene.sim.finish("sever")
	check(not scene.plan_button_shown(), "no Plan on the end card")
	# Rows she can travel by are marked; the plan draws.
	scene.tide_jump(7, "R10")
	scene.dispatch("notebook")
	scene.dispatch("tab:plan")
	scene._redraw()
	await process_frame
	await free_scene(scene)

# ---------------------------------------------------------------------------
# fix p1 core
# ---------------------------------------------------------------------------
## Carries chain_test's actions out on a game scene (dispatch, with presentation), and keeps
## the events of the action that committed `pid`.
class SceneClicker:
	var scene
	var pid := ""
	var commit_ev: Array = []
	func qd(action: String) -> Array:
		var before: bool = scene.sim.flag(pid)
		scene.dispatch(action)
		if not before and scene.sim.flag(pid) and commit_ev.is_empty():
			commit_ev = scene.last_events
		return scene.last_events

## The texts of the story lines in `ev`.
static func story_lines(ev: Array) -> Array:
	var out := []
	for e in ev:
		if e.type == "say" and e.get("story", false):
			out.append(e.text)
	return out

## Plays the chain to `pid` on a scene through its real actions, and right after the step
## (the commit and the step's own Backs) clicks the exit to `to` (twice when `double`). Then
## runs the clock. Returns {scene, reveal (the commit's story lines), from, exit_found,
## pending, travelled_at_once, arrival_ev}; the scene's shown_log/shown_rooms tell the rest.
func reveal_then_leave(pid: String, to: String, double := false) -> Dictionary:
	var scene = new_scene("user://core_reveal_leave_%s.json" % pid)
	await process_frame
	var clicker := SceneClicker.new()
	clicker.scene = scene
	clicker.pid = pid
	var out := {"scene": scene, "reveal": [], "arrival": "", "pending": "", "travelled_at_once": false}
	var ch = load("res://tests/chain_test.gd").new()
	ch.external_game = scene.sim
	ch.clicker = clicker
	ch.stop_after = pid
	ch.step_hook = func(step: String, rid: String, phase: String) -> void:
		if step != pid:
			return
		if phase == "at":
			scene._reset_presentation()   # what this step says, from a clean screen
			return
		out.reveal = story_lines(clicker.commit_ev)
		out.from = rid
		var rects: Dictionary = scene.room_view.live_exit_rects() if scene.room_view else {}
		out.exit_found = rects.has(to) and scene.action_at(rects[to].get_center()) == "go:" + to
		if not out.exit_found:
			return
		scene.click(rects[to].get_center())
		out.pending = scene.pending_travel
		if double:
			scene.time += 0.1
			scene.click(rects[to].get_center())
			out.travelled_at_once = scene.sim.state.room == to
		var travel_at := -1
		for i in 900:
			if scene.sim.state.room == to and travel_at < 0:
				travel_at = scene.shown_log.size()
				out.arrival_ev = scene.last_events
			if travel_at >= 0 and i > 0 and scene.lines.is_empty() and scene.cur_text == "":
				break
			scene._process(0.1)
		if travel_at < 0 and scene.sim.state.room == to:
			travel_at = scene.shown_log.size()
	await ch.run_tests()
	for f in ch.failures:
		check(false, "%s chain: %s" % [pid, f])
	ch.free()
	return out

## Checks one reveal_then_leave run: the reveal is read in its own room, nothing of it
## follows her, and the new room's first line is its arrival.
func check_reveal_left(o: Dictionary, pid: String, to: String, read := true) -> void:
	var scene = o.scene
	check(o.get("exit_found", false), "%s: the exit to %s is clickable after the step" % [pid, to])
	if not o.get("exit_found", false):
		return
	var from: String = o.from
	check(not o.reveal.is_empty(), "%s: the commit says a story chain (%s)" % [pid, o.reveal])
	var log: Array = scene.shown_log
	var rooms: Array = scene.shown_rooms
	for line in o.reveal:
		var where := []
		for i in log.size():
			if log[i] == line:
				where.append(rooms[i])
		if read:
			check(where.has(from), "%s: '%s' went up in %s (%s)" % [pid, line.substr(0, 40), from, where])
		check(not where.has(to), "%s: '%s' never shows in %s" % [pid, line.substr(0, 40), to])
	var first_after := ""
	for i in rooms.size():
		if rooms[i] == to:
			first_after = log[i]
			break
	var arrival := ""
	for e in o.get("arrival_ev", []):
		if e.type == "say":
			arrival = e.text
			break
	check(scene.sim.state.room == to, "%s: she reached %s (%s)" % [pid, to, scene.sim.state.room])
	check(arrival == "" or first_after == arrival, "%s: %s's arrival is the first line there ('%s' vs '%s')" % [pid, to, first_after, arrival])
	if arrival == "":
		check(first_after == "" or not first_after in o.reveal, "%s: nothing of the reveal after travel" % pid)

## P0: an exit clicked mid-reveal lets the reveal finish where it was said, then travels.
func test_reveal_leak() -> void:
	for c in [["P08", "R02"], ["P19", "R02"], ["P15", "R11"]]:
		var o: Dictionary = await reveal_then_leave(c[0], c[1])
		check(o.pending == "go:" + c[1] or o.reveal.is_empty(), "%s: the exit click waits for the reveal (%s)" % [c[0], o.pending])
		check_reveal_left(o, c[0], c[1])
		await free_scene(o.scene)
	# A double exit click goes at once: the arrival is first; the reveal's notes are kept.
	var d: Dictionary = await reveal_then_leave("P08", "R02", true)
	check(d.travelled_at_once, "P08: a second exit click travels at once")
	check_reveal_left(d, "P08", "R02", false)
	var sim: GameSim = d.scene.sim
	check(sim.has_seen("R06", "venn_seal"), "P08: the reveal's notes are in the notebook")
	var last_old := -1
	for i in d.scene.shown_rooms.size():
		if d.scene.shown_rooms[i] == "R06":
			last_old = i
	for i in range(last_old + 1, d.scene.shown_rooms.size()):
		check(d.scene.shown_rooms[i] == "R02", "after the double click every line is the office's")
	await free_scene(d.scene)
	# The re-timing: the line on screen squeezed, the last two at their full read time, and she
	# goes once the last has had its hold.
	var scene = new_scene("user://core_retime_test.json")
	await process_frame
	scene.tide_jump(2, "R02")
	scene._show_line("One.", true)
	scene._insert_line("Two.", scene.time + 3.0, true, 7)
	scene._insert_line("Three.", scene.time + 9.0, true, 7)
	scene.pending_sfx.append(["knock", 9.0, 7])
	var exit_r: Rect2 = scene.room_view.live_exit_rects()["R01"]
	var t0: float = scene.cur_since
	scene.click(exit_r.get_center())
	check(scene.pending_travel == "go:R01" and scene.sim.state.room == "R02", "the exit waits")
	var h1 := GameView.rush_hold("One.")
	var h2 := GameView.min_read("Two.")
	var h3 := GameView.min_read("Three.")
	check(is_equal_approx(scene.lines[0].due, t0 + h1) and is_equal_approx(scene.lines[1].due, t0 + h1 + h2),
		"the rest due back to back (%s)" % [scene.lines])
	check(is_equal_approx(scene.lines[0].hold, h2) and is_equal_approx(scene.lines[1].hold, h3), "the last two keep their full read")
	check(is_equal_approx(scene.pending_sfx[0][1], h1 + h2), "the beat's sound moves with its line (%s)" % [scene.pending_sfx])
	var went := -1.0
	# Small steps: each queued line goes up on the first frame after it is due, so a coarse
	# step adds up to one step of lateness per line (three lines at 0.1 s missed the 0.15 s
	# window by the phase of the scene clock alone).
	for i in 400:
		scene._process(0.01)
		if scene.sim.state.room == "R01" and went < 0.0:
			went = scene.time
	var want := t0 + h1 + h2 + h3
	check(went > 0.0 and went >= want - 0.001 and went <= want + 0.15, "she went after the last line's hold (%.2f after, want %.2f)" % [went - t0, want - t0])
	check(scene.shown_rooms.count("R02") >= 3, "all three lines went up in the office (%s)" % [scene.shown_log])
	# A view change to the notebook drops a deferred exit.
	scene.tide_jump(2, "R02")
	scene._show_line("One.", true)
	scene._insert_line("Two.", scene.time + 3.0, true, 7)
	scene.click(exit_r.get_center())
	scene.dispatch("notebook")
	check(scene.pending_travel == "", "the notebook drops the deferred exit")
	await free_scene(scene)

## A hotspot click is never eaten by a leftover line.
func test_hotspot_click_acts() -> void:
	var scene = new_scene("user://core_hotspot_click_test.json")
	await process_frame
	scene.tide_jump(1, "R02")
	scene._reset_presentation()
	scene.sim.state.started = false
	scene.sim.view = "title"
	scene.dispatch("begin")
	var last_arrival := ""
	for e in scene.last_events:
		if e.type == "say":
			last_arrival = e.text
	for i in 200:
		if scene.cur_text == last_arrival:
			break
		scene._process(0.1)
	scene._process(0.5)
	check(scene.cur_text == last_arrival, "the last arrival line is up (%s)" % scene.cur_text)
	var log_r: Rect2 = scene.room_view.hotspot_rect("logbook")
	var n: int = scene.shown_log.size()
	scene.click(log_r.get_center())
	check(scene.room_sim().local_view != "room", "one click on the tide log opens it (%s)" % scene.room_sim().local_view)
	for i in 30:
		scene._process(0.1)
	check(scene.shown_log.size() > n, "the log's line is shown")
	scene.dispatch("back")
	# A story line alone on screen: finished, and the hotspot acts in the same press.
	scene._reset_presentation()
	scene._show_line("A story line still typing out across the screen.", true)
	scene.time += 0.5
	scene.click(log_r.get_center())
	check(scene.room_sim().local_view != "room", "with only the line on screen left, the hotspot acts at once")
	scene.dispatch("back")
	# More of the chain queued: the rest is rushed where it was said, the hotspot shows pressed
	# and acts when the chain ends.
	scene._reset_presentation()
	var first := "A story line still typing out across the screen."
	scene._show_line(first, true)
	scene._queue_line("And one more after it.", 6.0, true)
	scene.time += 0.5
	var t_click: float = scene.time
	scene.click(log_r.get_center())
	check(scene.room_sim().local_view == "room" and scene.pending_action == "logbook"
		and scene.cur_text == first, "the hotspot waits; the line on screen stays (%s)" % scene.pending_action)
	check(is_equal_approx(scene.cur_hold, GameView.rush_hold(first)) and scene.lines[0].due < t_click + 6.0,
		"the rest of the chain is rushed (%.2f, due %.2f)" % [scene.cur_hold, scene.lines[0].due - t_click])
	var seen_second := false
	for i in 60:
		scene._process(0.1)
		seen_second = seen_second or scene.cur_text == "And one more after it."
		if scene.room_sim().local_view != "room":
			break
	check(seen_second, "the rushed line still went up")
	check(scene.room_sim().local_view != "room" and not scene.chain_active(), "the hotspot acts when the chain ends")
	scene.dispatch("back")
	# A second click on the waiting hotspot acts at once; the chain still plays out after.
	scene._reset_presentation()
	scene._show_line(first, true)
	scene._queue_line("And one more after it.", 6.0, true)
	scene.time += 0.5
	scene.click(log_r.get_center())
	scene.time += 0.1
	scene.click(log_r.get_center())
	check(scene.room_sim().local_view != "room" and scene.pending_action == "", "the second click acts at once")
	var all_said := false
	for i in 80:
		scene._process(0.1)
		all_said = all_said or scene.cur_text == "And one more after it."
	check(all_said, "the chain's last line is never dropped")
	scene.dispatch("back")
	# A glance due at the same chain's end lands first; the held hotspot acts after it.
	scene._reset_presentation()
	scene._show_line("A story line still typing out across the screen.", true)
	scene._queue_line("And one more after it.", 1.0, true)
	scene.pending_glance = {"type": "fx", "id": "glance", "rect": [500, 684, 205, 64], "target": "logbook"}
	scene.time += 0.5
	scene.click(log_r.get_center())
	for i in 60:
		scene._process(0.1)
	check(scene.pending_glance.is_empty() and scene.room_sim().local_view != "room",
		"the glance lands, then the held hotspot opens (%s)" % scene.room_sim().local_view)
	scene.dispatch("back")
	# The subtitle bar only advances.
	scene._reset_presentation()
	scene._show_line("A story line still typing out across the screen.", true)
	scene._queue_line("And one more after it.", 1.0, true)
	scene.time += 0.5
	scene.click(Vector2(724, 1040))
	check(scene.pending_action == "" and scene.cur_text == "And one more after it.", "a subtitle-bar click only advances")
	await free_scene(scene)

## Room hotspots known to reach under the Plan button, {rid: [hotspot ids]}, each a bug for
## its room team (the HUD takes the click there; the hotspot answers everywhere else). A
## fixed entry fails here too, so the list only shrinks.
const PLAN_OVERLAP_KNOWN := {"R11": ["ceiling"]}

## The Plan button has a slot of its own; a Plan press right after Back is ignored.
func test_plan_slot() -> void:
	var scene = new_scene("user://core_plan_slot_test.json")
	await process_frame
	var plan: Rect2 = GameView.PLAN_BUTTON[1]
	check(not plan.intersects(GameView.BACK_RECT), "the Plan clears Back")
	for b in GameView.HUD_BUTTONS:
		check(not plan.intersects(b[1]), "the Plan clears the %s button" % b[0])
	var hits := []
	for rid in scene.sim.order:
		for t in range(1, 10):
			scene.tide_jump(t, rid)
			for r in scene.room_view.live_exit_rects().values():
				if r.intersects(plan): hits.append("%s T%d exit" % [rid, t])
			for h in scene.room_view.c("HOTSPOTS", []):
				if h is Array and h.size() >= 2 and h[1] is Rect2 and h[1].intersects(plan): hits.append("%s T%d %s" % [rid, t, h[0]])
			for h in scene.room_view.control_rows():
				if h[1].intersects(plan): hits.append("%s T%d %s" % [rid, t, h[0]])
			for y in range(int(plan.position.y), int(plan.end.y) + 1, 5):
				for x in range(int(plan.position.x), int(plan.end.x) + 1, 5):
					var a: String = scene.room_view.action_at(Vector2(x, y))
					if a != "" and not ("%s T%d %s" % [rid, t, a]) in hits: hits.append("%s T%d %s" % [rid, t, a])
			for slot in scene._inv_layout():
				if slot[0].intersects(plan): hits.append("%s T%d slot" % [rid, t])
	var known_seen := {}
	var real := []
	for h in hits:
		var parts: PackedStringArray = h.split(" ")
		if PLAN_OVERLAP_KNOWN.get(parts[0], []).has(parts[2]):
			known_seen[parts[0] + " " + parts[2]] = true
		else:
			real.append(h)
	check(real.is_empty(), "nothing under the Plan rect %s: %s" % [plan, real])
	for rid in PLAN_OVERLAP_KNOWN:
		for id in PLAN_OVERLAP_KNOWN[rid]:
			check(known_seen.has(rid + " " + id), "%s's %s is clear of the Plan now: drop it from PLAN_OVERLAP_KNOWN" % [rid, id])
			if known_seen.has(rid + " " + id):
				print("ROOM BUG (%s): hotspot '%s' reaches under the Plan button %s" % [rid, id, plan])
	for i in range(0, 8):
		check(not GameView._slot_rect(i).intersects(plan), "inventory slot %d clears the Plan" % i)
	# Back, then Plan 0.2 s later: the second half of a double click.
	scene.tide_jump(4, "R02")
	scene.dispatch("lamp")
	scene.dispatch("back")
	scene.time += 0.2
	check(scene.plan_button_shown(), "the Plan is up again with the room")
	scene.click(plan.get_center())
	check(scene.sim.view == "room", "a Plan click 0.2 s after Back is ignored")
	scene.time += 0.3
	scene.click(plan.get_center())
	check(scene.sim.view == "notebook" and scene._nb_page() == "plan", "after 0.4 s the Plan answers")
	await free_scene(scene)

## A ladder with four lines has four tiers; the last tier always waits for a confirmation.
func test_hint_tiers() -> void:
	var g := GameSim.new(FIXTURES)
	g.dispatch("begin")
	var got := []
	for i in 4:
		got.append(says(g.dispatch("hint")))
	check(got == ["a", "b", GameSim.HINT_CONFIRM, "c"], "a 3-line ladder: tier1, tier2, confirm, tier3 (%s)" % [got])
	check(g.room("Z01").hint_tiers() == 3, "a 3-line room has 3 tiers")
	g.dispatch("shelf")
	g.dispatch("item:key")
	g.dispatch("box")
	g.dispatch("go:Z02")
	check(g.state.room == "Z02" and g.room().hint_tiers() == 4, "the hall's ladder has four tiers")
	got = []
	for i in 6:
		got.append(says(g.dispatch("hint")))
	check(got == ["tier1", "tier2", "tier3", GameSim.HINT_CONFIRM, "tier4", "tier4"],
		"a 4-line ladder: tier1-3, confirm, tier4 (%s)" % [got])
	check(int(g.state.hint.level) == 4 and roundtrip(g).state.hint.level == 4, "level 4 is saved")
	var bad: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	bad.hint.level = 9
	var b := GameSim.new(FIXTURES)
	b.from_dict(bad)
	check(int(b.state.hint.level) == 4, "a saved level is clamped to 0..4 (%s)" % b.state.hint.level)
	check(GameSim.with_confirmation(["x", "x"]) == ["x", "x"], "no confirmation before a line already said")

## The tide card waits for close-ups and reveals, and sits clear of exits and the glance.
func test_tide_card_rules() -> void:
	var g: GameSim = await chain_at("P08")
	var scene = await scene_with("user://core_card_rules_test.json", g)
	var sim: GameSim = scene.sim
	var k: R05Sim = sim.room("R05")
	for a in ["go:R05", "to_kitchen"]:
		sim.dispatch(a)
	for half in ["pantry", "bunk"]:
		sim.dispatch("item:token_%s_half" % half)
		sim.dispatch("shift_board" if k.local_view != "c_service_board" else "socket_" + half)
	sim.dispatch("socket_turn")
	var want: Dictionary = R05Sim.SOLUTION_AMEND
	for i in 8:
		if k.state.amend.count != want.count: sim.dispatch("f_count")
	sim.dispatch("tile_%d" % R05Sim.NAME_TILES.find(want.name))
	for i in 8:
		if k.state.amend.status != want.status: sim.dispatch("f_status")
	sim.dispatch("seal_3")
	scene._mount_room()
	scene._reset_presentation()
	scene.dispatch("stamp")
	check(sim.flag("P09") and scene.tide_card_pending == 4, "P09: the card is pending")
	var early := false
	var started := false
	for i in 600:
		scene._process(0.1)
		var blocked: bool = scene.room_sim().is_closeup() or scene._story_queued() or scene.chain_active()
		if scene.tide_card_alpha() > 0.0:
			started = true
			if blocked and scene.tide_card_t < 0.15:
				early = true
		if i == 100 and scene.room_sim().is_closeup() and not started:
			# Still over the close-up long after the reveal: the card keeps waiting.
			check(scene.tide_card_pending == 4, "P09: no card over the close-up")
			scene.dispatch("back")
		if started and scene.tide_card_alpha() == 0.0:
			break
	check(started and not early, "P09: the card starts only with no close-up and no reveal queued")
	for r in scene.room_view.live_exit_rects().values():
		check(not scene.tide_card_rect().intersects(r), "P09: the card clears the exit tabs")
	# Travel no longer forces the card: it waits for the arrival chain.
	scene._reset_presentation()
	scene.play_events([{"type": "say", "text": "A story line that is still being read.", "delay": 0.0, "story": true},
		{"type": "fx", "id": "tide", "tide": 5}])
	scene.dispatch("go:R06")
	check(scene.sim.state.room == "R06" and scene.tide_card_pending == 5 and scene.tide_card_alpha() == 0.0,
		"travel leaves the card waiting")
	var arrival_up := false
	for i in 200:
		scene._process(0.1)
		var arrival_on := false
		for l in scene.lines:
			arrival_on = arrival_on or l.click == scene.arrival_click
		arrival_on = arrival_on or (scene.cur_text != "" and scene.cur_click == scene.arrival_click
			and scene.time < scene.cur_since + scene.cur_hold)
		if arrival_on:
			arrival_up = true
			check(scene.tide_card_alpha() == 0.0, "no card while the arrival chain is up")
		if scene.tide_card_alpha() > 0.0:
			break
	check(scene.tide_card_n == 5 and scene.tide_card_alpha() > 0.0, "the card comes after the arrival")
	# After P03 (Tide I -> II) the card clears the room's controls and exit tabs.
	scene.tide_jump(1)
	var s: R02Sim = scene.room_sim()
	s.debug_jump(5)
	scene.sim.set_flag("P02")
	var ev: Array = []
	scene.sim.solve("P03", ev)
	scene.play_events(ev)
	for i in 100:
		scene._process(0.1)
		if scene.tide_card_alpha() > 0.0:
			break
	check(scene.tide_card_n == 2 and scene.tide_card_alpha() > 0.0, "the Tide II card shows")
	var cr: Rect2 = scene.tide_card_rect()
	for r in scene.room_view.live_exit_rects().values():
		check(not cr.intersects(r), "Tide II: the card clears the exit tabs (%s)" % cr)
	for id in ["recorder", "logbook", "drawer"]:
		var hr: Rect2 = scene.room_view.hotspot_rect(id)
		check(hr.size == Vector2.ZERO or not cr.intersects(hr), "Tide II: the card clears the %s" % id)
	# The low rect is used when nothing is under it; the upper band when an exit is.
	check(GameView.TIDE_CARD_RECT == Rect2(40, 840, 560, 110) and GameView.TIDE_CARD_UPPER_RECT == Rect2(40, 110, 560, 110),
		"the card's two places")
	scene.glance_rect = Rect2(100, 860, 100, 60)
	scene.glance_t = 0.0
	check(scene._card_rect_now() == GameView.TIDE_CARD_UPPER_RECT, "a glance under the low rect: the upper band")
	await free_scene(scene)

## The end card: a panel under the words, a title that fits, legible colours.
func test_end_card_panel() -> void:
	var scene = new_scene("user://core_end_panel_test.json")
	await process_frame
	check(GameView.END_STILL_ALPHA == 1.0 and GameView.END_TEXT_FADE == 1.0, "the still at full strength, text in by 1.0 s")
	for id in GameSim.ENDINGS:
		var lay: Dictionary = scene.end_layout(id)
		var e: Dictionary = GameSim.ENDINGS[id]
		var w: float = scene.serif.get_string_size(e.title, HORIZONTAL_ALIGNMENT_LEFT, -1, lay.title_size).x
		check(w <= 820.0 and lay.title_size >= 34 and lay.title_size <= 40, "%s: the title fits (%.0f px at %d)" % [id, w, lay.title_size])
		var panel: Rect2 = lay.panel
		check(panel.position == Vector2(274, 760) and panel.size.x == 900.0, "%s: the panel sits in the lower band (%s)" % [id, panel])
		check(lay.title_y == 812.0 and lay.line_ys[0] == 868.0 and lay.line_ys[1] == 908.0, "%s: title 812, lines 868 + 40" % id)
		check(panel.end.y <= GameView.END_BUTTONS[0][1].position.y and GameView.END_BUTTONS[0][1].end.y <= GameView.SIZE.y,
			"%s: the buttons under the panel, on screen" % id)
		var texts := [[lay.title_y, lay.title_size]]
		for y in lay.line_ys:
			texts.append([y, GameView.END_LINE_SIZE])
		texts.append([lay.seen_y, GameView.END_SEEN_SIZE])
		for t in texts:
			check(panel.has_point(Vector2(724, t[0])) and panel.has_point(Vector2(724, t[0] - t[1])),
				"%s: text at y %.0f inside the panel" % [id, t[0]])
		check(is_equal_approx(panel.end.y, lay.seen_y + 40.0), "%s: the panel ends 40 px under 'Endings seen'" % id)
		check(lay.seen_y > lay.line_ys[-1], "%s: 'Endings seen' under the last line" % id)
		for b in GameView.END_BUTTONS:
			check(b[1].position.y >= panel.end.y, "%s: the %s button is below the panel" % [id, b[0]])
		for i in lay.line_ys.size():
			var lw: float = scene.hand.get_string_size(e.lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, GameView.END_LINE_SIZE).x
			check(lw <= panel.size.x - 40.0, "%s: quote line %d fits the panel (%.0f)" % [id, i, lw])
	# Navy ink on the paper panel (0.8 over a black still, the darkest case) is AA.
	var worst: Color = Ink.BLACK.lerp(GameView.CARD_PAPER, GameView.END_PANEL_ALPHA)
	check(contrast(Ink.INK, worst) >= 4.5, "INK on the end panel is AA (%.2f)" % contrast(Ink.INK, worst))
	# Both cards draw.
	for id in ["sever", "continue"]:
		scene.tide_jump(9, "R12")
		scene.sim.finish(id)
		scene._mount_room()
		scene.end_t = 1.2
		scene._redraw()
		await process_frame
	await free_scene(scene)

## WCAG relative luminance contrast of two opaque colours.
static func contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

static func _lum(c: Color) -> float:
	var ch := []
	for v in [c.r, c.g, c.b]:
		ch.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]

## The title: the photograph behind the words, drifting only with Motion on; the thin sea.
func test_title_screen() -> void:
	var scene = new_scene("user://core_title_test.json")
	await process_frame
	check(scene.sim.view == "title", "the game opens on the title")
	check(scene.title_plate() != null, "the title plate loads (%s)" % GameView.TITLE_PLATE)
	for motion in [true, false]:
		scene.sim.settings.motion = motion
		var rects := []
		for t in [0.0, 10.0, 20.0, 30.0]:
			scene.time = t
			var r: Rect2 = scene.title_plate_rect()
			rects.append(r)
			check(r.position.x <= 0.0 and r.position.y <= 0.0 and r.end.x >= 1448.0 and r.end.y >= 1086.0,
				"motion %s t %.0f: the plate covers the screen (%s)" % [motion, t, r])
		var base: Rect2 = rects[0]
		for r in rects:
			check(absf(r.get_center().x - base.get_center().x) <= 12.0 and absf(r.get_center().y - base.get_center().y) <= 12.0,
				"motion %s: the drift stays small" % motion)
			check(r.size.x <= base.size.x * 1.0101 and r.size.x >= base.size.x / 1.0101, "motion %s: scale within 1%%" % motion)
		if not motion:
			check(rects.all(func(r): return r == base), "Motion off: the plate is still")
		else:
			check(rects[1] != rects[0], "Motion on: the plate drifts")
		scene.over.queue_redraw()
		await process_frame
	scene.sim.settings.motion = true
	scene._process(0.1)
	check(is_equal_approx(linear_to_db(scene.title_mixer.last_targets.get("sea", 0.0)), GameView.TITLE_LOOP_DB),
		"the title's sea at -24 dB (%s)" % [scene.title_mixer.last_targets])
	check(scene.title_mixer.players.has("sea"), "the sea loop is loaded")
	scene.dispatch("begin")
	scene._process(0.1)
	check(scene.title_loop_target() == 0.0 and not scene.title_mixer.last_targets.has("sea"), "after begin the sea is removed")
	for i in 6:
		scene._process(0.1)
	check(scene.title_mixer.mix.get("sea", 0.0) == 0.0, "it has faded out within MIXER_FADE")
	await free_scene(scene)

## hold_breath: a timed fx ducks the beds to silence (soft: -18 dB), holds, comes back.
func test_hold_breath() -> void:
	var scene = new_scene("user://core_breath_test.json")
	await process_frame
	scene.tide_jump(1, "R02")
	for i in 3:
		await process_frame
	var mixers: Array = scene.bed_mixers()
	check(not mixers.is_empty(), "the office has beds")
	for soft in [false, true]:
		scene._reset_presentation()
		scene.sim.settings.soft_audio = soft
		var t0: float = scene.time
		scene.play_events([{"type": "say", "text": "Listen.", "delay": 0.0, "story": true},
			{"type": "fx", "id": "hold_breath", "seconds": 2.0, "delay": 1.0}])
		var floor_k := db_to_linear(-18.0) if soft else 0.0
		var at := {}
		for i in 50:
			scene._process(0.1)
			at[roundi((scene.time - t0) * 10.0)] = scene.breath_gain()
		check(is_equal_approx(at[9], 1.0), "soft %s: full at 0.9 s (%.3f)" % [soft, at[9]])
		for t in [12, 15, 20, 25, 30]:
			check(absf(at[t] - floor_k) < 0.01, "soft %s: ducked at %.1f s (%.3f)" % [soft, t / 10.0, at[t]])
		check(is_equal_approx(at[43], 1.0), "soft %s: full again at 4.3 s (%.3f)" % [soft, at[43]])
		check(at[36] > floor_k + 0.05 and at[36] < 1.0, "soft %s: coming back at 3.6 s" % soft)
	scene.sim.settings.soft_audio = false
	# The beds follow; a hold mid-way is applied to the mixers' players.
	scene._reset_presentation()
	scene.play_events([{"type": "fx", "id": "hold_breath", "seconds": 2.0}])
	for i in 3:
		scene._process(0.1)
	for m in scene.bed_mixers():
		check(m.duck < 0.01, "the bed mixer is ducked")
		for id in m.players:
			check(m.players[id].volume_db <= -79.0, "%s is silent" % id)
	# Overlapping holds run to the later end.
	scene.hold_breath(3.0)
	var end_at: float = scene.breath_end
	scene.hold_breath(0.5)
	check(scene.breath_end == end_at, "a shorter hold doesn't cut a longer one short")
	# One-shots still play during a hold.
	scene.play_events([{"type": "sfx", "id": "page", "delay": 0.0}])
	check(scene.played_log.size() > 0 and scene.played_log[-1][0] == "page", "a one-shot plays during the hold")
	# Travel cancels it.
	scene.dispatch("go:R01")
	check(scene.sim.state.room == "R01" and scene.breath_gain() == 1.0, "travel cancels the hold")
	for m in scene.bed_mixers():
		check(m.duck == 1.0, "no bed stays ducked after travel")
	# A room fx the view doesn't list in TIMED_FX keeps its delay and comes at once (R10).
	scene._reset_presentation()
	scene.play_events([{"type": "fx", "id": "some_room_fx", "delay": 2.0}])
	check(scene.pending_fx.is_empty() and not scene.fx_timed_by_core("some_room_fx") and scene.fx_timed_by_core("hold_breath"),
		"only hold_breath and a view's TIMED_FX wait in the core")
	# A timed fx is delivered with its delay plus the chain offset.
	scene._reset_presentation()
	scene._show_line("A story line being read.", true)
	scene._queue_line("Its next line.", 2.0, true)
	scene.play_events([{"type": "say", "text": "Later.", "delay": 1.0, "story": true},
		{"type": "fx", "id": "hold_breath", "seconds": 0.5, "delay": 1.0}], true)
	check(scene.pending_fx.size() == 1 and scene.pending_fx[0][1] > 1.0, "a timed fx waits behind the chain (%s)" % [scene.pending_fx])
	await free_scene(scene)

# ---------------------------------------------------------------------------
# fix p2 core
# ---------------------------------------------------------------------------
const STORY_A := "A story line still being read on the screen."
const STORY_B := "And one more after it."

func hud_rect(id: String) -> Rect2:
	for b in GameView.HUD_BUTTONS:
		if b[0] == id:
			return b[1]
	return Rect2()

## A scene in the office at tide III with a two-line story chain playing, past the swallow.
func chain_scene(path: String) -> Node:
	var scene = new_scene(path)
	await process_frame
	scene.tide_jump(3, "R02")
	scene.time += 1.0
	scene._show_line(STORY_A, true)
	scene._queue_line(STORY_B, 3.0, true)
	scene.time += 0.5
	return scene

## P0: the HUD and the inventory act on the press; a chain is neither advanced nor waited on.
func test_hud_at_once() -> void:
	var scene = await chain_scene("user://core_hud_now_test.json")
	scene.click(hud_rect("hint").get_center())
	check(scene.cur_text == STORY_A and scene.lines.size() == 1 and scene.pending_action == "",
		"Hint: the chain neither advances nor waits (%s)" % scene.cur_text)
	check(scene.hint_card_text() != "", "Hint: the reply is up at once")
	var slot: Array = scene._inv_layout()[0]
	scene.click(slot[0].get_center())
	check(scene.sim.selected_item == slot[1].substr(5) and scene.cur_text == STORY_A and scene.pending_action == "",
		"an inventory slot: selected at once, the chain untouched")
	scene.click(slot[0].get_center())
	check(scene.sim.selected_item == "", "the slot again puts it back")
	scene.click(hud_rect("notebook").get_center())
	check(scene.sim.view == "notebook" and scene.cur_text == STORY_A and scene.pending_action == "",
		"Notebook: open at once, the chain untouched")
	scene.dispatch("back")
	scene.click(hud_rect("menu").get_center())
	check(scene.sim.view == "menu" and scene.cur_text == STORY_A, "Menu: open at once, the chain untouched")
	var due: float = scene.lines[0].due
	var since: float = scene.cur_since
	scene._process(1.0)
	check(is_equal_approx(scene.lines[0].due, due + 1.0) and is_equal_approx(scene.cur_since, since + 1.0) and scene.cur_text == STORY_A,
		"the pause menu holds the chain where it was")
	scene.dispatch("resume")
	await free_scene(scene)

## P0: the Hint's reply is a card under the Hint button, never a subtitle; each press
## replaces it with this press's answer, the confirmation and the answer included.
func test_hint_card() -> void:
	var scene = await chain_scene("user://core_hint_card_test.json")
	var twin := GameSim.new()
	twin.from_dict(JSON.parse_string(JSON.stringify(scene.sim.to_dict())))
	var lines_before: int = scene.lines.size()
	var log_before: int = scene.shown_log.size()
	for i in 6:
		var want := says(twin.dispatch("hint"))
		scene.click(hud_rect("hint").get_center())
		check(scene.hint_card_text() == want, "press %d: the card answers this press ('%s' vs '%s')" % [i, scene.hint_card_text(), want])
		var r: Rect2 = scene.hint_card_rect()
		check(is_equal_approx(r.end.x, GameView.HINT_CARD_RIGHT) and r.position.y == GameView.HINT_CARD_TOP
			and r.size.x <= GameView.HINT_CARD_MAX_W + 0.01 and r.size.y >= GameView.HINT_CARD_SIZE,
			"press %d: the card under the Hint button (%s)" % [i, r])
		scene.time += 0.4
	check(GameSim.HINT_CONFIRM in scene.hint_log, "the confirmation is on the card too (%s)" % [scene.hint_log])
	check(scene.shown_log.size() == log_before and scene.lines.size() == lines_before,
		"no hint line ever enters the subtitle queue (%s)" % [scene.lines])
	# The card stays up its read time, at least HINT_CARD_MIN.
	scene.click(hud_rect("hint").get_center())
	var text: String = scene.hint_card_text()
	var hold := maxf(GameView.min_read(text) + GameView.HINT_CARD_EXTRA, GameView.HINT_CARD_MIN)
	scene.time += hold - 0.1
	check(scene.hint_card_text() == text, "the card is up for its read time")
	scene.time += 0.2
	check(scene.hint_card_text() == "", "then it is gone (%.2f s)" % hold)
	# The next click anywhere puts it away; H answers the same way.
	key(scene, KEY_H)
	check(scene.hint_card_text() != "", "H shows the card")
	scene.click(Vector2(724, 1040))
	check(scene.hint_card_text() == "", "the next click anywhere puts the card away")
	scene.dispatch("hint")
	check(scene.hint_card_text() != "" and scene.cur_text != scene.hint_card_text(), "dispatch('hint') goes to the card too")
	await free_scene(scene)

## P0: the item in hand is a banner, and Esc or the right button puts it away ("disarm").
func test_disarm() -> void:
	var g := GameSim.new()
	g.debug_tide(3, "R02")
	g.selected_item = g.state.inventory[0]
	var ev := g.dispatch("disarm")
	check(ev.is_empty() and g.selected_item == "", "disarm: put away, nothing said (%s)" % [ev])
	check(g.dispatch("disarm").is_empty(), "disarm with nothing in hand: nothing")
	var scene = new_scene("user://core_disarm_test.json")
	await process_frame
	scene.tide_jump(3, "R02")
	check(scene.arm_banner_text() == "" and scene.arm_banner_rect() == Rect2(), "no banner with nothing in hand")
	var slot: Array = scene._inv_layout()[0]
	scene.click(slot[0].get_center())
	var item: String = slot[1].substr(5)
	var d: Dictionary = scene.sim.item_defs()[item]
	check(scene.arm_banner_text() == "Using: %s   (Esc or right-click to put away)" % d.get("short", d.name),
		"the banner names it (%s)" % scene.arm_banner_text())
	var br: Rect2 = scene.arm_banner_rect()
	check(br.position == GameView.ARM_BANNER_POS and br.end.x <= GameView.SIZE.x - 16.0, "the banner in the HUD band, on screen (%s)" % br)
	key(scene, KEY_ESCAPE)
	check(scene.sim.selected_item == "" and scene.sim.view == "room", "Esc puts the item away, nothing else")
	key(scene, KEY_ESCAPE)
	check(scene.sim.view == "menu", "Esc with nothing in hand: its usual menu")
	scene.dispatch("resume")
	scene.click(slot[0].get_center())
	var rb := InputEventMouseButton.new()
	rb.button_index = MOUSE_BUTTON_RIGHT
	rb.pressed = true
	scene._unhandled_input(rb)
	check(scene.sim.selected_item == "" and scene.sim.view == "room", "the right button puts it away")
	await free_scene(scene)

## P0: an item used up in a close-up leaves a ghost slot; nothing moves until Back.
func test_ghost_slots() -> void:
	var scene = new_scene("user://core_ghost_test.json")
	await process_frame
	scene.tide_jump(2, "R03")
	var items := []
	for id in scene.sim.item_defs():
		if items.size() < 4 and not id in scene.sim.state.retired:
			items.append(id)
	scene.sim.state.inventory = items.duplicate()
	scene._process(0.1)
	scene.dispatch("recorder")
	check(scene.room_sim().is_closeup(), "the recorder close-up is open")
	var rects := {}
	for slot in scene._inv_layout():
		rects[slot[1]] = slot[0]
	for k in 3:
		scene.sim.take(items[k])   # seated in the close-up, in order
		scene._process(0.1)
		var lay: Array = scene._inv_layout()
		check(lay.size() == 4, "seat %d: four slots still (%d)" % [k + 1, lay.size()])
		for j in range(k + 1, 4):
			check(lay[j][1] == "item:" + items[j] and lay[j][0] == rects["item:" + items[j]],
				"seat %d: %s keeps slot %d" % [k + 1, items[j], j])
		for j in k + 1:
			check(lay[j][1] == "", "seat %d: slot %d is a ghost" % [k + 1, j])
			check(scene.action_at(lay[j][0].get_center()) == "", "seat %d: the ghost slot does nothing" % [k + 1])
	# A click just after the bar changed is ignored; a moment later it acts.
	scene.sim.take(items[2])
	var last: Rect2 = rects["item:" + items[3]]
	scene.click(last.get_center())
	check(scene.sim.selected_item == "", "a click within 0.3 s of the bar changing is ignored")
	scene.time += GameView.INV_GUARD + 0.05
	scene.click(last.get_center())
	check(scene.sim.selected_item == items[3], "after the guard the slot acts")
	scene.dispatch("item:" + items[3])
	scene.dispatch("back")
	var lay2: Array = scene._inv_layout()
	check(lay2.size() == 1 and lay2[0][1] == "item:" + items[3], "Back compacts the bar (%s)" % [lay2])
	await free_scene(scene)

## P1: an exit pressed mid-reveal rushes the reveal; no line is up for less than its
## squeezed read time, the last two for less than their full one; the tab shows pressed.
func test_exit_rush() -> void:
	var scene = new_scene("user://core_exit_rush_test.json")
	await process_frame
	scene.tide_jump(2, "R02")
	var texts := ["The first line of the reveal, forty-odd chars.",
		"Second: the tide table has a column I never ruled.",
		"Third, and the column is in my own hand, dated tomorrow.",
		"Fourth: the ink is still wet where the date should be.",
		"Fifth. Somebody has signed it for two of us, not one.",
		"Sixth and last: the second name is the sea's own name."]
	var ev := []
	for i in texts.size():
		check(texts[i].length() >= 40 and texts[i].length() <= 60, "fixture line %d is 40-60 chars" % i)
		ev.append({"type": "say", "text": texts[i], "delay": 4.0 * i, "story": true})
	scene.play_events(ev)
	scene._process(0.5)
	var exit_r: Rect2 = scene.room_view.live_exit_rects()["R01"]
	scene.click(exit_r.get_center())
	check(scene.pending_travel == "go:R01", "the exit waits for the rushed reveal")
	var up := {texts[0]: scene.cur_since}
	var last_text: String = scene.cur_text
	var gone_at := -1.0
	for i in 600:
		scene._process(0.02)
		if scene.sim.state.room != "R02":
			gone_at = scene.time
			break
		if scene.cur_text != last_text:
			last_text = scene.cur_text
			up[last_text] = scene.time
	check(gone_at > 0.0, "she went")
	check(up.size() == texts.size(), "every line went up before she left (%d)" % up.size())
	for i in texts.size():
		if not up.has(texts[i]):
			continue
		var end: float = up[texts[i + 1]] if i + 1 < texts.size() and up.has(texts[i + 1]) else gone_at
		var need := GameView.min_read(texts[i]) if i >= texts.size() - GameView.EXIT_FULL_LAST \
			else GameView.min_read(texts[i]) * GameView.BACKLOG_SQUEEZE
		check(end - up[texts[i]] >= need - 0.021, "line %d up %.2f s, needs %.2f" % [i, end - up[texts[i]], need])
	await free_scene(scene)

## P1: the Hint ladder at every chain step whose room has four tiers ends HINT_CONFIRM, then
## the last tier; tiers 2 and 3 of every ladder say different things.
func test_hint_ladder_every_step() -> void:
	var g := GameSim.new()
	var ch = load("res://tests/chain_test.gd").new()
	ch.external_game = g
	var probed := [0]
	ch.step_hook = func(pid: String, _rid: String, phase: String) -> void:
		if g.view != "room" or g.room().is_closeup() or g.room().hint_tiers() < 4:
			return
		var snap := g.to_dict()
		var said := []
		for i in 6:
			said.append(says(g.dispatch("hint")))
		var uniq := []
		for x in said:
			if uniq.is_empty() or uniq[-1] != x:
				uniq.append(x)
		probed[0] += 1
		check(uniq.size() >= 2 and uniq[-2] == GameSim.HINT_CONFIRM,
			"%s/%s in %s: HINT_CONFIRM right before the last tier (%s)" % [pid, phase, g.state.room, uniq])
		g.from_dict(snap)
	await ch.run_tests()
	check(ch.failures.is_empty(), "the chain plays with the ladder probes (%s)" % [ch.failures])
	check(probed[0] > 0, "some step stands in a four-tier room")
	ch.free()
	for rid in g.order:
		var hints: Dictionary = g.room(rid).c("HINTS", {})
		for o in hints:
			var l: Array = hints[o]
			if l.size() >= 3:
				check(GameSim._hint_key(l[1]) != GameSim._hint_key(l[2]),
					"%s %s: hint tiers 2 and 3 say different things ('%s')" % [rid, o, l[1]])

## P1: the loudness ladder. Every bed loop is trimmed per room; from Tide IV on no room is
## quieter than the opening rooms less 3 dB; silence only ever comes from hold_breath.
func test_bed_loudness() -> void:
	var scene = new_scene("user://core_loudness_test.json")
	await process_frame
	var m := LoopMixer.new()
	m.trim = db_to_linear(6.0)
	check(is_equal_approx(m.gain(), db_to_linear(6.0)), "the trim applies with the beds up")
	m.duck = 0.0
	check(m.gain() == 0.0, "and none of it while a breath is held")
	m.free()
	var table := {}
	var ref := []
	for rid in ["R01", "R02", "R03"]:
		scene.tide_jump(1, rid)
		for i in 5:
			scene._process(0.1)
		var l: Dictionary = scene.bed_loudness()
		ref.append(l.db)
	var ref_db: float = (ref[0] + ref[1] + ref[2]) / 3.0
	var rows := ["room      t1      t3      t5      t7      t9"]
	for rid in ALL:
		var row: String = rid + " "
		for t in [1, 3, 5, 7, 9]:
			if not rid in REACH[t]:
				row += "    --  "
				continue
			scene.tide_jump(t, rid)
			for i in 5:
				scene._process(0.1)
			var l: Dictionary = scene.bed_loudness()
			for mx in GameView._mixers_in(scene.room_view):
				check(is_equal_approx(mx.trim, scene.room_trim(rid)), "%s t%d: the bed carries its room trim" % [rid, t])
			check(l.live > 0, "%s t%d: the bed is never silent (%d of %d loops up)" % [rid, t, l.live, l.loops])
			if t >= 5:
				check(l.db >= ref_db - 3.0, "%s t%d: %.1f dB, no quieter than the opening rooms less 3 dB (%.1f)" % [rid, t, l.db, ref_db - 3.0])
			row += "%7.1f " % l.db
		rows.append(row)
	print("bed loudness (dB re full scale; opening rooms R01-R03 at tide I: %.1f)\n  %s" % [ref_db, "\n  ".join(rows)])
	await free_scene(scene)

## P2: "Now:" offers the plan when it is hers and the work is 3 or more exits away.
func test_now_plan() -> void:
	var g := GameSim.new()
	var on := 0
	var off_unlocked := 0
	for t in range(1, 10):
		for rid in REACH[t]:
			g.debug_tide(t, rid)
			var to := g.objective_room()
			var want: bool = g.plan_unlocked() and to != "" and g.hops(rid, to) >= 3
			check(g.now_via_plan() == want, "t%d %s -> %s (%d hops): the (Plan) suffix %s" % [t, rid, to, g.hops(rid, to), want])
			if want:
				on += 1
			elif g.plan_unlocked():
				off_unlocked += 1
	check(on > 0 and off_unlocked > 0, "both cases occur (%d on, %d off)" % [on, off_unlocked])
	check(g.hops("R01", "R07") == 3 and g.hops("R02", "R02") == 0, "hops are open exits")
	g.debug_tide(9, "R01")
	g.set_flag("P05", false)
	check(not g.now_via_plan(), "no suffix before the plan is hers")
	# The scene: the suffix is a link to the plan, its pin pulsing.
	var scene = new_scene("user://core_now_plan_test.json")
	await process_frame
	var found := false
	for t in range(3, 10):
		for rid in REACH[t]:
			if found:
				break
			scene.tide_jump(t, rid)
			if not scene.sim.now_via_plan():
				continue
			found = true
			scene.dispatch("notebook")
			check(scene.now_line().ends_with(" (Plan)"), "the notebook's Now: ends ' (Plan)' (%s)" % scene.now_line())
			var link: Rect2 = scene.now_plan_rect()
			check(scene.action_at(link.get_center()) == "nbnow:plan", "the suffix is a click target")
			scene.click(link.get_center())
			check(scene._nb_page() == "plan" and scene.plan_pulse != "" and scene.plan_pulse in scene.sim.state.visited,
				"one click: the plan, with a pin pulsing (%s)" % scene.plan_pulse)
			scene._redraw()
			await process_frame
	check(found, "some start of tide offers the plan link")
	scene.tide_jump(2, "R02")
	scene.dispatch("notebook")
	check(not scene.now_line().ends_with(" (Plan)") and scene.now_plan_rect() == Rect2(), "no link before P05")
	await free_scene(scene)
	# The first walk of 3 or more exits says so, once.
	var w := GameSim.new()
	w.debug_tide(4, "R01")
	var said := ""
	for to in ["R02", "R05", "R07"]:
		said += says(w.dispatch("go:" + to)) + " | "
	check(said.count(GameSim.PLAN_NUDGE) == 1 and w.settings.plan_nudged, "the 3-exit walk: the nudge once (%s)" % said)
	for to in ["R05", "R02", "R01", "R02", "R05", "R07"]:
		check(not GameSim.PLAN_NUDGE in says(w.dispatch("go:" + to)), "never again")
	var n := GameSim.new()
	n.debug_tide(4, "R01")
	n.set_flag("P05", false)
	var said2 := ""
	for to in ["R02", "R05", "R07"]:
		said2 += says(n.dispatch("go:" + to))
	check(not GameSim.PLAN_NUDGE in said2, "no nudge before the plan is hers")
	var s := GameSim.new()
	s.load_settings({"plan_nudged": true})
	check(s.settings.plan_nudged, "the nudge is remembered with the settings")

## P2: hover labels sit on their target's rect, never in the HUD band or on the tide card.
const TOP_VIEW := """extends RoomView
const HOTSPOTS := [["top", Rect2(600, 20, 160, 64), "A thing at the top"], ["low", Rect2(60, 900, 200, 70), "A thing low down"]]
"""

func test_hover_anchor() -> void:
	var scene = new_scene("user://core_hover_anchor_test.json")
	await process_frame
	scene.tide_jump(2, "R02")
	var s := GDScript.new()
	s.source_code = TOP_VIEW
	s.reload()
	var v: RoomView = s.new()
	var old: RoomView = scene.room_view
	v.game = scene
	v.rid = old.rid
	v.sim = old.sim
	scene.world.remove_child(old)
	old.queue_free()
	scene.world.add_child(v)
	scene.room_view = v
	var a: Rect2 = scene.hover_label_rect("top", Vector2(610, 30))
	var b: Rect2 = scene.hover_label_rect("top", Vector2(750, 80))
	check(a.position.y >= 80.0, "a hotspot at y=20: its label top is >= 80 (%s)" % a)
	check(a == b, "the label is anchored to the rect, not the pointer")
	check(is_equal_approx(a.get_center().x, 680.0) and not a.intersects(Rect2(600, 20, 160, 64)), "centred on it, clear of it")
	var low: Rect2 = scene.hover_label_rect("low", Vector2(100, 950))
	check(low.end.y <= 900.0 and is_equal_approx(low.get_center().x, 160.0), "a low hotspot: centred above it (%s)" % low)
	scene.tide_card_n = 2
	scene.tide_card_t = 1.0
	scene.tide_card_at = GameView.TIDE_CARD_RECT
	var lc: Rect2 = scene.hover_label_rect("low", Vector2(100, 950))
	check(not lc.intersects(GameView.TIDE_CARD_RECT) and lc.position.y >= 80.0 and not lc.intersects(Rect2(60, 900, 200, 70)),
		"with the tide card up, the label clears it (%s)" % lc)
	scene.tide_card_t = 99.0
	await free_scene(scene)
	# A close-up opening, and travel, clear the hover.
	var sc = new_scene("user://core_hover_clear_test.json")
	await process_frame
	sc.tide_jump(2, "R03")
	sc.hover_id = "recorder"
	sc.dispatch("recorder")
	sc._process(0.1)
	check(sc.room_sim().is_closeup() and sc.hover_id == "", "a close-up opening clears the hover")
	await free_scene(sc)

## P2: the core's glance brackets fade out, and nothing of them survives travel, the
## notebook or a close-up.
func test_glance_clears() -> void:
	var scene = new_scene("user://core_glance_clear_test.json")
	await process_frame
	scene.tide_jump(2, "R03")
	scene.glance_rect = Rect2(10, 120, 300, 200)
	scene.glance_t = GameView.GLANCE_TIME - GameView.GLANCE_FADE * 0.5
	var mid: float = scene.glance_alpha()
	check(mid > 0.3 and mid < 0.7, "the brackets fade over their last 0.4 s (%.2f)" % mid)
	scene.glance_t = 1.0
	check(scene.glance_alpha() == 1.0, "and are full in the middle")
	scene.dispatch("go:R02")
	check(scene.glance_alpha() == 0.0 and scene.glance_rect == Rect2(), "after travel, no glance draws")
	scene.tide_jump(2, "R03")
	scene.glance_rect = Rect2(10, 120, 300, 200)
	scene.glance_t = 1.0
	scene.dispatch("notebook")
	check(scene.glance_alpha() == 0.0, "the notebook clears it")
	scene.dispatch("back")
	scene.glance_rect = Rect2(10, 120, 300, 200)
	scene.glance_t = 1.0
	scene.dispatch("recorder")
	check(scene.room_sim().is_closeup() and scene.glance_alpha() == 0.0, "a close-up opening clears it")
	await free_scene(scene)
