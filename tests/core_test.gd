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
	await test_tide_card_waits()
	await test_tide_card_closeup()
	await test_clicks_never_eaten()
	await test_hover_label_rects()
	await test_glance()
	await test_consume_click()
	await test_room_hooks()
	await test_cinematic_keys()
	if failures.is_empty():
		print("PASS: core — discovery, topology, gates per tide, tides and weather, travel, latched office, inventory, notebook, hints, saves, slice migration, debug jumps, plan travel, endings, events, objective elsewhere, objective every tide, plan from a close-up, load behind a gate, scene rooms, scene saves, inventory paging, notebook pages, hover and back, travel fade, card and slab, placeholder, item on exit, item labels, hint ladder, build end, tide card waits, tide card in a close-up, clicks never eaten, hover labels, glance, consume_click, room hooks, cinematic keys")
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
	check(not s.to_dict().has("settings") and s.settings_dict() == {"motion": false, "soft_audio": true, "endings_seen": []},
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
	check(scene.cur_text != "", "hint in a skeleton room")
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
	scene._process(0.05)
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
	var ev := g.dispatch("hint")
	check(says(ev) == "Something in the intake office has changed.", "hint 1: where (%s)" % says(ev))
	check(g.state.hint["for"] == "R04:->R02", "the hint key names the room it points at")
	ev = g.dispatch("hint")
	check(says(ev) == g.room("R02").hint_line(0), "hint 2: the office's own first rung")
	g.dispatch("hint")
	ev = g.dispatch("hint")
	check(says(ev) == g.room("R02").hint_line(2), "hint 4: the office's solution")
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
	check(GameView.TIDE_CARD_RECT == Rect2(324, 120, 800, 110) and GameView.TIDE_CARD_TIME == 3.0, "card rect and time")
	scene.tide_card_n = 2
	for pair in [[0.0, 0.0], [0.25, 0.5], [1.5, 1.0], [2.75, 0.5], [3.0, 0.0]]:
		scene.tide_card_t = pair[0]
		check(absf(scene.tide_card_alpha() - pair[1]) < 0.01, "card alpha at %.2f s" % pair[0])
	scene.sim.settings.motion = false
	for pair in [[0.0, 1.0], [2.4, 1.0], [2.6, 0.0]]:
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

## An unbuilt room shows its card with one way back; its hotspots stay live.
func test_placeholder() -> void:
	var scene = new_scene("user://core_ph_test.json")
	await process_frame
	# Wave 2 built R05-R08: the stair landing (R11) is the unbuilt room off a built one.
	scene.tide_jump(4, "R03")
	scene.dispatch("go:R11")
	check(scene.room_view.rid == "R11" and scene.room_view.is_skeleton(), "the stair landing is a skeleton")
	var live: Dictionary = scene.room_view.live_exit_rects()
	check(live.keys() == ["R03"], "one exit, back to the chart room (%s)" % [live.keys()])
	check(scene.action_at(live["R03"].get_center()) == "go:R03", "the way back answers")
	var other: Rect2 = scene.room_view.exit_rects()["R09"]
	check(scene.action_at(other.get_center()) == "", "the other exits are shut on the card")
	var hs: Array = scene.room_view.c("HOTSPOTS")
	check(scene.action_at(hs[0][1].get_center()) == hs[0][0], "the hotspots stay live")
	scene.tide_jump(9, "R11")
	scene.dispatch("go:R12")
	check(scene.sim.state.room == "R12", "the sim still walks on (chain_test)")
	check(scene.room_view.live_exit_rects().keys() == ["R11"], "the chamber offers the way back to the stair")
	var built: RoomView = load("res://game/rooms/R02/R02_view.tscn").instantiate()
	check(not built.is_skeleton(), "a built room is not a skeleton")
	built.free()
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
	var want: String = r5.c("WAY_IN_HINT", "The way into the %s is open now." % str(r5.c("TITLE")).to_lower())
	var ev := g.dispatch("hint")
	check(says(ev) == want, "an unvisited room: its way in (%s)" % says(ev))
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
	for presses in [1, 2, 3, 6]:
		var h := GameSim.new()
		h.debug_tide(1, "R02")
		h.dispatch("begin")
		for i in presses:
			h.dispatch("hint")
		var lv: int = h.state.hint.level
		check(lv <= 3, "the hint level stays clamped (%d after %d presses)" % [lv, presses])
		check(roundtrip(h).state.hint.level == lv, "a save keeps hint.level %d" % lv)

## Unbuilt rooms: marked exits, never offered as work; the build's end is said plainly.
func test_build_end() -> void:
	var g := GameSim.new()
	for rid in ["R09", "R10", "R11", "R12"]:
		check(g.is_unbuilt(rid), "%s is not built yet" % rid)
	for rid in ["R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08"]:
		check(not g.is_unbuilt(rid), "%s is built" % rid)
	g = await chain_at("P11")
	check(g.objective_text() == GameSim.BUILD_END_NOW, "after P11, Now: names the build's end (%s)" % g.objective_text())
	check(says(g.dispatch("hint")) == GameSim.BUILD_END_HINT, "after P11, the Hint says so too")
	for rid in g.order:
		if g.is_unbuilt(rid):
			check(g.elsewhere(true) != rid, "an unbuilt room is never the work elsewhere")
	g.debug_enter("R11")
	check(g.objective_text() == GameSim.BUILD_END_NOW, "standing in the stair: the same end")
	var scene = new_scene("user://core_unbuilt_test.json")
	await process_frame
	scene.tide_jump(2, "R03")
	var label: String = scene.exit_tab_label("R11")
	check("not yet built" in label, "the chart room's stair tab says not yet built (%s)" % label)
	check(not "not yet built" in scene.exit_tab_label("R02"), "a built room's tab is plain")
	check("not yet built" in scene._hover_label("go:R11") or "locked" in scene._hover_label("go:R11"),
		"the stair's hover label is marked (%s)" % scene._hover_label("go:R11"))
	await free_scene(scene)

## The tide card waits for the reveal that earned it: P09's chain plays out first.
func test_tide_card_waits() -> void:
	var g: GameSim = await chain_at("P08")
	var scene = await scene_with("user://core_card_wait_test.json", g)
	var sim: GameSim = scene.sim
	var k: R05Sim = sim.room("R05")
	for a in ["go:R05", "to_kitchen"]:
		sim.dispatch(a)
	check(sim.state.room == "R05", "in the kitchen for P09")
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
	check(sim.flag("P09") and sim.tide() == 4, "the stamp solves P09 (Tide IV)")
	check(scene.tide_card_alpha() == 0.0 and scene.tide_card_pending == 4, "the card waits")
	var bolts_at := -1.0
	var chain_end := -1.0
	var card_at := -1.0
	var early := false
	for i in 400:
		scene._process(0.1)
		var shown := false
		for l in scene.shown_log:
			shown = shown or "bolts drew back" in l
		if shown and bolts_at < 0.0:
			bolts_at = scene.time
		if not shown and scene.tide_card_alpha() > 0.0:
			early = true
		if shown and not scene.chain_active() and chain_end < 0.0:
			chain_end = scene.time
		if scene.tide_card_alpha() > 0.0 and card_at < 0.0:
			card_at = scene.time
	check(bolts_at > 0.0, "the hatch line went up")
	check(not early, "no tide card before 'bolts drew back' is on screen")
	check(chain_end > 0.0 and card_at > 0.0 and card_at >= chain_end
		and card_at <= chain_end + GameView.TIDE_CARD_QUIET + GameView.TIDE_CARD_FADE + 0.11,
		"the card follows the chain (chain ends %.1f, card %.1f)" % [chain_end, card_at])
	check(scene.tide_card_n == 4, "it is the Tide IV card")
	# Travel starts a waiting card at once; a reset clears it.
	scene.play_events([{"type": "say", "text": "A long story line that is still being read.", "delay": 0.0, "story": true},
		{"type": "fx", "id": "tide", "tide": 5}])
	check(scene.tide_card_pending == 5 and scene.tide_card_alpha() == 0.0, "a new card waits behind its line")
	scene.play_events([{"type": "fx", "id": "travel", "from": "R05", "to": "R05"}])
	check(scene.tide_card_pending == 0 and scene.tide_card_n == 5 and scene.tide_card_t == 0.0, "travel starts it on arrival")
	scene.play_events([{"type": "say", "text": "Another line.", "delay": 0.0, "story": true}, {"type": "fx", "id": "tide", "tide": 6}])
	scene._reset_presentation()
	check(scene.tide_card_pending == 0 and scene.tide_card_alpha() == 0.0, "a reset drops a waiting card")
	await free_scene(scene)

## A tide card over a close-up sits in the band above the subtitles, clear of its controls.
func test_tide_card_closeup() -> void:
	var scene = new_scene("user://core_card_cu_test.json")
	await process_frame
	scene.tide_jump(5, "R07")
	var v: RoomView = scene.room_view
	check(v.has_method("closeup_controls"), "the laboratory lists its close-up controls")
	for cid in R07Sim.CLOSEUPS:
		scene.room_sim().local_view = cid
		scene._reset_presentation()
		scene.room_sim().local_view = cid
		scene.play_events([{"type": "fx", "id": "tide", "tide": 6}])
		scene._process(0.05)
		scene._process(0.05)
		check(scene.tide_card_alpha() > 0.0 and scene.tide_card_closeup, "%s: the card starts, low" % cid)
		var r: Rect2 = scene.tide_card_rect()
		check(r.position.x == GameView.TIDE_CARD_CLOSEUP_RECT.position.x and r.end.y <= 994.0 and r.position.y >= 84.0,
			"%s: a band clear of the HUD and the subtitles (%s)" % [cid, r])
		for h in v.closeup_controls(cid):
			check(not r.intersects(h[1]), "%s: the card clears %s" % [cid, h[0]])
	scene.room_sim().local_view = "room"
	scene._reset_presentation()
	scene.play_events([{"type": "fx", "id": "tide", "tide": 6}])
	scene._process(0.05)
	scene._process(0.05)
	check(scene.tide_card_rect() == GameView.TIDE_CARD_RECT, "in the room the card sits high")
	# A close-up with nothing under the band keeps the band itself (R02's lamp repair).
	scene.tide_jump(1, "R02")
	scene.dispatch("lamp")
	scene.play_events([{"type": "fx", "id": "tide", "tide": 2}])
	scene._process(0.05)
	scene._process(0.05)
	var free_band := true
	for h in scene.room_view.control_rows():
		free_band = free_band and not GameView.TIDE_CARD_CLOSEUP_RECT.intersects(h[1])
	check(not free_band or scene.tide_card_rect() == GameView.TIDE_CARD_CLOSEUP_RECT, "a clear close-up keeps the band above the subtitles")
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
	check(scene.sim.state.room == "R02" and scene.sim.view == "room", "one click on the Office row travels (%s)" % scene.sim.state.room)
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
