extends "res://tests/rooms/room_test_base.gd"
## R01, the Jetty: skeleton checks plus P06 and every jetty state.
##   godot --headless --path . --script tests/rooms/R01_test.gd

const ROOM := "R01"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := []
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 1
const STATES := ["arrival", "boat", "s1", "s2", "s3", "s4", "s5", "s6", "s7", "A"]

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	test_first_arrival()
	test_bells_before_boat()
	test_states_per_tide()
	test_tally_bell_matrix()
	test_refusal_then_lens()
	test_verified_never_advances()
	test_lens_and_peer()
	test_gangway()
	test_commit()
	test_capsule_and_objectives()
	test_save_mid_puzzle()
	test_malformed_saves()
	test_debug_prepare()
	test_notice_per_state()
	test_every_hotspot_every_state()
	test_wrong_items()
	test_hints()
	test_determinism()
	test_service_door()
	test_round_w1_lines()
	test_round_w2_lines()
	await view_checks(ROOM)
	await test_view_presentation()
	await test_view_w2()

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
func boat_game() -> GameSim:
	var g := with_flags(["P01", "P02", "P03", "closure_report_filed", "t1x_threshold_crossed",
		"P04", "P05"], "R01")
	g.give("inspection_lens")
	return g

func r01(g: GameSim) -> R01Sim:
	return g.room(ROOM) as R01Sim

## A boat game with the boat already looked at through the lens.
func lensed_game() -> GameSim:
	var g := boat_game()
	g.dispatch("item:inspection_lens")
	g.dispatch("launch")
	g.dispatch("back")
	return g

func ring(g: GameSim, tally: String, n: int) -> Array:
	var r := r01(g)
	r.local_view = R01Sim.C_PANEL
	r.state.panel_tally = tally
	return g.dispatch("bell_%d" % n)

## A game standing in R01 in jetty state `s`.
func game_in(s: String) -> GameSim:
	var g: GameSim
	match s:
		"arrival":
			g = game_at(1, ROOM)
		"boat":
			g = boat_game()
		"A":
			g = GameSim.new()
			r01(g).debug_jump(9)
		_:
			g = game_at(int(s.substr(1)) + 2, ROOM)
	return g

func count_tide_fx(ev: Array) -> int:
	var k := 0
	for e in ev:
		if e.type == "fx" and e.id == "tide":
			k += 1
	return k

# ---------------------------------------------------------------------------
# tests
# ---------------------------------------------------------------------------
func test_first_arrival() -> void:
	var g := GameSim.new()
	g.dispatch("begin")
	var ev := g.dispatch("go:R01")
	var s := says(ev)
	check(s.begins_with(R01Sim.ARRIVAL), "1: first arrival says ARRIVAL (%s)" % s)
	check(R01Sim.NOTICE.arrival in s, "1: first arrival says the arrival notice")
	check(r01(g).jetty_state() == "arrival" and not r01(g).boat_present(), "1: no boat on arrival")
	check(says(g.dispatch("launch")) == "Open water. Nothing's moored here.", "1: launch on arrival")
	g.dispatch("go:R02")
	ev = g.dispatch("go:R01")
	check(says(ev) == "", "1: a second entry says nothing (%s)" % says(ev))

func test_bells_before_boat() -> void:
	for tally in R01Sim.TALLIES:
		for n in range(1, 5):
			var g := game_at(1, ROOM)
			var ev := ring(g, tally, n)
			check(not g.flag("P06"), "2: before P05, %s + bell %d never solves" % [tally, n])
			check(not r01(g).has_seen("launch_mismatch"), "2: before P05 no launch_mismatch")
			check(says(ev) == "The bell rings out along the jetty. Nothing's moored to hear it.",
				"2: before P05 the bell rings to nothing (%s)" % says(ev))

func test_states_per_tide() -> void:
	check(r01(game_at(1, ROOM)).jetty_state() == "arrival", "3: tide I arrival")
	check(r01(game_at(2, ROOM)).jetty_state() == "arrival", "3: tide II start arrival")
	check(r01(boat_game()).jetty_state() == "boat", "3: P05 brings the boat")
	for t in range(3, 10):
		var g := game_at(t, ROOM)
		check(r01(g).jetty_state() == "s%d" % (t - 2) and g.weather_band() == t - 2,
			"3: tide %d is s%d (got %s, band %d)" % [t, t - 2, r01(g).jetty_state(), g.weather_band()])

func test_tally_bell_matrix() -> void:
	for tally in R01Sim.TALLIES:
		for n in range(1, 5):
			var g := lensed_game()
			var inv: Array = g.state.inventory.duplicate()
			var ev := ring(g, tally, n)
			var r := r01(g)
			var label := "4: %s + bell %d" % [tally if tally != "" else "none", n]
			if tally == "unverified" and n == 2:
				check(g.flag("P06"), label + " solves")
				continue
			check(not g.flag("P06"), label + " does not solve")
			check(g.state.inventory == inv, label + " keeps the inventory")
			match tally:
				"verified":
					check(r.tally() == "" and says(ev) == R01Sim.VERIFIED_MISS, label + " resets with the pennant line")
				"":
					check(says(ev) == R01Sim.NO_TALLY and r.tally() == "", label + " asks for a tally")
				_:
					check(r.tally() == "unverified" and says(ev) == R01Sim.BELL_MISS, label + " keeps the tally, says two")

func test_refusal_then_lens() -> void:
	var g := boat_game()
	var ev := ring(g, "unverified", 2)
	check(says(ev) == R01Sim.REFUSAL, "5: the contract quote refuses (%s)" % says(ev))
	check(not has_ev(ev, "sfx", "bell_pull"), "5: she stops her hand")
	check(r01(g).tally() == "unverified" and not g.flag("P06"), "5: tally stays, no P06")
	g.dispatch("back")
	g.dispatch("item:inspection_lens")
	g.dispatch("launch")
	check(r01(g).has_seen("launch_mismatch"), "5: the lens writes launch_mismatch")
	g.dispatch("back")
	g.dispatch("panel")
	ev = g.dispatch("bell_2")
	check(g.flag("P06"), "5: the next ring solves")

func test_verified_never_advances() -> void:
	var g := lensed_game()
	for rep in 3:
		for n in range(1, 5):
			ring(g, "verified", n)
	check(not g.flag("P06") and g.tide() == 2, "6: VERIFIED never advances (tide %d)" % g.tide())
	check(r01(g).state.misses == 12, "6: misses counted")

func test_lens_and_peer() -> void:
	var g := boat_game()
	g.take("inspection_lens")
	g.dispatch("item:inspection_lens")
	check(g.selected_item == "", "7: no lens, nothing selected")
	g.dispatch("launch")
	check(r01(g).local_view == "room" and not r01(g).has_seen("launch_mismatch"), "7: launch only looks")
	g = boat_game()
	g.dispatch("item:inspection_lens")
	var ev := g.dispatch("launch")
	var r := r01(g)
	check(r.local_view == R01Sim.C_WINDOW and r.has_seen("launch_mismatch"), "7: lens opens the window")
	check(has_ev(ev, "sfx", "lens_click") and r.state.lens_looks == 1, "7: lens look 1")
	ev = g.dispatch("peer")
	check(r.has_seen("window_figure") and r.state.lens_looks == 2 and r.figure_seen(), "7: peer finds the figure")
	check(has_ev(ev, "fx", "figure"), "7: figure fx")
	ev = g.dispatch("peer")
	check(r.state.lens_looks == 2 and says(ev) == "Still there. Still writing.", "7: the figure stays")
	g = boat_game()
	g.set_flag("t1x_turned")
	g.dispatch("item:inspection_lens")
	g.dispatch("launch")
	ev = g.dispatch("peer")
	check(r01(g).has_seen("window_figure_turned") and not r01(g).has_seen("window_figure"), "7: turned figure")
	check("They've turned round. They're looking out through the glass. At me." in says(ev), "7: turned line")
	# A second lens use also peers.
	g = boat_game()
	g.dispatch("item:inspection_lens")
	g.dispatch("launch")
	g.dispatch("back")
	g.dispatch("item:inspection_lens")
	g.dispatch("launch")
	check(r01(g).state.lens_looks == 2, "7: a second lens look peers")

func test_gangway() -> void:
	var g := boat_game()
	var ev := g.dispatch("gangway")
	var r := r01(g)
	check(r.state.gangway_loop and has_ev(ev, "fx", "gangway_loop") and r.has_seen("gangway_loop"), "8: the loop")
	ev = g.dispatch("gangway")
	check(says(ev) == "Once was enough." and not has_ev(ev, "fx", "gangway_loop") and ev.size() == 1, "8: once was enough")
	var b := GameSim.new()
	b.from_dict(g.to_dict())
	check(r01(b).state.gangway_loop, "8: gangway_loop survives a save")
	for gg in [game_at(1, ROOM), game_at(3, ROOM), game_at(9, ROOM)]:
		ev = gg.dispatch("gangway")
		check(not has_ev(ev, "fx", "gangway_loop") and not r01(gg).state.gangway_loop, "8: no loop outside the boat state")

func test_commit() -> void:
	var g := lensed_game()
	var inv: Array = g.state.inventory.duplicate()
	var ev := ring(g, "unverified", 2)
	var r := r01(g)
	check(has_ev(ev, "sfx", "station_bell_2_dead") and has_ev(ev, "fx", "withdraw") and has_ev(ev, "sfx", "capsule_rise"),
		"9: commit sounds and fx")
	var tide_ok := false
	for e in ev:
		tide_ok = tide_ok or (e.type == "fx" and e.id == "tide" and e.get("tide") == 3)
	check(tide_ok, "9: tide fx shows Tide III")
	check(r.local_view == "room" and "s1" in r.state.noticed, "9: back in the room, s1 noticed")
	check(g.tide() == 3 and g.weather_band() == 1, "9: tide III, band 1")
	check(r.has_seen("withdrew") and g.state.inventory == inv, "9: withdrew noted, no key yet")
	check("Someone's standing at the chart table in its window." in says(ev), "9: figure line before peering")
	# Peered first: the figure at the chart, and how far it has got.
	var gp := lensed_game()
	gp.dispatch("item:inspection_lens")
	gp.dispatch("launch")
	gp.dispatch("peer")
	gp.dispatch("back")
	var evp := ring(gp, "unverified", 2)
	check("Whoever's at my chart doesn't look up. They've reached the part where I came in." in says(evp),
		"9: the figure line after peering")
	check(not ("doesn't look up. |" in says(evp)), "9: the old short line is gone")
	ev = ring(g, "unverified", 2)
	check(count_tide_fx(ev) == 0 and g.state.inventory == inv, "9: a repeat ring gives nothing")
	check(says(ev) == "The boat's gone. I'm not calling it back.", "9: repeat line")
	ev = g.dispatch("tally_verified")
	check(r.tally() == "unverified" and says(ev) == "The tally's set. The boat's gone.", "9: tally locked after")

func test_capsule_and_objectives() -> void:
	var g := game_at(1, ROOM)
	check(r01(g).objective() == "explore", "10: explore (got %s)" % r01(g).objective())
	g = boat_game()
	var r := r01(g)
	check(r.objective() == "inspect", "10: inspect")
	g.dispatch("item:inspection_lens")
	g.dispatch("launch")
	g.dispatch("back")
	check(r.objective() == "signal", "10: signal")
	ring(g, "unverified", 2)
	check(r.objective() == "capsule" and r.capsule_state() == "closed", "10: capsule")
	g.dispatch("line")
	check(r.local_view == R01Sim.C_CAPSULE, "10: line opens the capsule")
	check(says(g.dispatch("key")) == R01Sim.CAP_ON and says(g.dispatch("note")) == R01Sim.CAP_ON, "10: cap on")
	g.dispatch("cap")
	check(r.state.capsule_opened and r.capsule_state() == "open", "10: cap off")
	var ev := g.dispatch("key")
	check(g.has_item("service_key") and has_ev(ev, "fx", "item_added"), "10: key given")
	g.dispatch("key")
	check(g.state.inventory.count("service_key") == 1, "10: key given once")
	g.dispatch("note")
	check(r.has_seen("venn_address_note"), "10: note read")
	check(r.objective() == "after", "10: after (got %s)" % r.objective())
	g.dispatch("back")
	check(says(g.dispatch("line")) == "Open. Empty.", "10: empty capsule")
	g.take("service_key")
	check(r.objective() == "done", "10: done")

func test_save_mid_puzzle() -> void:
	var g := GameSim.new()
	r01(g).debug_jump(2)
	r01(g).local_view = R01Sim.C_PANEL
	var b := GameSim.new()
	check(b.from_dict(g.to_dict()), "11: loads")
	var r := r01(b)
	check(r.local_view == "room" and r.tally() == "unverified" and r.has_seen("launch_mismatch"), "11: state persists")
	check(r.boat_present(), "11: boat still there")
	b.dispatch("panel")
	b.dispatch("bell_2")
	check(b.flag("P06"), "11: bell 2 solves after the load")

func test_malformed_saves() -> void:
	var g := boat_game()
	var d := g.to_dict()
	d.rooms.R01.panel_tally = "bogus"
	d.rooms.R01.lens_looks = 7
	d.rooms.R01.key_taken = true
	var b := GameSim.new()
	b.from_dict(d)
	var r := r01(b)
	check(r.tally() == "", "12: bogus tally rejected")
	check(r.state.lens_looks == 0, "12: lens_looks 7 clamps then reconciles to 0 (got %d)" % r.state.lens_looks)
	check(not r.state.key_taken, "12: key without the capsule rejected")
	var r2 := R01Sim.new()
	r2.load_state({"lens_looks": 7})
	check(r2.state.lens_looks == 2, "12: lens_looks clamps to 2")
	r2.load_state({"lens_looks": 1.5, "noticed": ["s1", "s1", "bogus", 3], "misses": 500})
	check(r2.state.lens_looks == 0 and r2.state.noticed == ["s1"] and r2.state.misses == 99, "12: floats, ids, clamps")
	r2.load_state({"p06_complete": true, "capsule_opened": true, "note_read": "yes"})
	check(r2.state.panel_tally == "unverified" and r2.state.lens_looks == 1 and not r2.state.note_read, "12: derived after p06")
	d = g.to_dict()
	d.flags["P06"] = true
	b = GameSim.new()
	b.from_dict(d)
	check(not b.flag("P06"), "12: P06 without local p06 is cleared")

func test_debug_prepare() -> void:
	var g := game_at(3, ROOM)
	# Integrated (Wave 1): R02's debug_prepare spends the key at the service door from Tide III.
	check(g.flag("P06") and r01(g).capsule_state() == "open" and not g.has_item("service_key")
		and "R05" in g.reachable("R02"), "13: tide III, key spent at the service door")
	g = game_at(4, ROOM)
	check(g.flag("P06") and not g.has_item("service_key"), "13: tide IV, key spent")
	check(r01(game_at(9, ROOM)).jetty_state() == "s7", "13: tide IX s7")
	for n in 10:
		var j := GameSim.new()
		r01(j).debug_jump(n)
		check(j.state.room == ROOM and j.view == "room", "13: jump %d stands on the jetty" % n)
	var j3 := GameSim.new()
	r01(j3).debug_jump(3)
	check(r01(j3).capsule_state() == "closed" and not j3.has_item("service_key"), "13: jump 3 capsule closed")

func test_notice_per_state() -> void:
	for t in range(4, 10):
		var g := game_at(t, "R02")
		var s := "s%d" % (t - 2)
		var ev := g.dispatch("go:R01")
		var ok := false
		for e in ev:
			ok = ok or (e.type == "fx" and e.id == "notice" and e.get("state") == s)
		check(ok and says(ev) == R01Sim.NOTICE[s], "14: %s notice (%s)" % [s, says(ev)])
		for o in R01Sim.NOTICE_OBS.get(s, []):
			check(r01(g).has_seen(o), "14: %s notes %s" % [s, o])
		if s == "s6":
			check(has_ev(ev, "sfx", "bell_low"), "14: s6 bell")
		g.dispatch("go:R02")
		ev = g.dispatch("go:R01")
		check(says(ev) == "", "14: %s second entry silent" % s)
		if s == "s6":
			check(has_ev(ev, "sfx", "bell_low"), "14: s6 bell every arrival")

func test_every_hotspot_every_state() -> void:
	for s in STATES:
		var g := game_in(s)
		check(r01(g).jetty_state() == s, "15: in state %s (got %s)" % [s, r01(g).jetty_state()])
		for h in R01Sim.HOTSPOTS:
			var ev := g.dispatch(h)
			check(says(ev) != "", "15: %s answers in %s" % [h, s])
			g.dispatch("back")

func test_wrong_items() -> void:
	for s in ["arrival", "boat", "s3", "s6", "s7"]:
		for h in R01Sim.HOTSPOTS:
			var g := game_in(s)
			if not g.has_item("inspection_lens"):
				g.give("inspection_lens")
			g.dispatch("item:inspection_lens")
			var ev := g.dispatch(h)
			check(says(ev) != "" and says(ev) != GameSim.GENERIC_WRONG_USE, "16: lens on %s in %s" % [h, s])
			g.give("service_key")
			g.dispatch("back")
			g.dispatch("item:service_key")
			ev = g.dispatch(h)
			check(says(ev) == R01Sim.KEY_LINE and g.has_item("service_key"), "16: key on %s in %s" % [h, s])

func test_hints() -> void:
	var games := {"explore": game_at(1, ROOM), "inspect": boat_game(), "signal": lensed_game()}
	var c := lensed_game()
	ring(c, "unverified", 2)
	games["capsule"] = c
	var after := game_at(3, ROOM)
	after.give("service_key")  # one step earlier: the key in hand, the service door still shut
	games["after"] = after
	games["done"] = game_at(5, ROOM)
	for o in R01Sim.HINTS:
		var g: GameSim = games[o]
		check(r01(g).objective() == o, "17: objective %s (got %s)" % [o, r01(g).objective()])
		var before := JSON.stringify(g.to_dict().rooms.R01)
		# With live work in a built room elsewhere the core sends her there first (GameSim._hint);
		# the jetty's own ladder is still what the room answers.
		var away := g.work_elsewhere()
		# Core w3: the ladder toward an unvisited room opens with a where-step, a visited one with
		# that room's own first line; either way it is the core's ladder, not the jetty's.
		var away_first: String = g._elsewhere_ladder(away)[0] if away != "" else ""
		for lvl in 3:
			check(r01(g).hint_line(lvl) == R01Sim.HINTS[o][lvl], "17: %s hint %d" % [o, lvl])
			var ev := g.dispatch("hint")
			if away == "":
				check(says(ev) == R01Sim.HINTS[o][lvl], "17: %s hint %d dispatched" % [o, lvl])
			elif lvl == 0:
				check(says(ev) == away_first and says(ev) != R01Sim.HINTS[o][0],
					"17: %s hint points to %s (got '%s')" % [o, away, says(ev)])
		check(JSON.stringify(g.to_dict().rooms.R01) == before, "17: hints change no room state")
		check(R01Sim.OBJECTIVES.has(o), "17: objective text for %s" % o)

func golden() -> Array:
	var g := boat_game()
	var evs := []
	for a in ["launch", "item:inspection_lens", "launch", "peer", "back", "panel", "tally_unverified",
			"bell_2", "back", "line", "cap", "key", "note"]:
		evs.append(g.dispatch(a))
	return [JSON.stringify(g.to_dict()), JSON.stringify(evs), g.flag("P06")]

func test_determinism() -> void:
	var a := golden()
	var b := golden()
	check(a[0] == b[0] and a[1] == b[1], "18: the golden run is deterministic")
	check(a[2], "18: the golden run solves P06")

func test_service_door() -> void:
	var g := game_at(3, "R02")
	var r02 = g.room("R02")
	var door: bool = "service_door" in r02.c("HOTSPOTS", []) or "service_door" in r02.c("HOTSPOTS_B", [])
	check(door, "19: R02 has a service door")
	if not door:
		return
	# The service door is on wall B: face it first, then use the key on it.
	g.dispatch("turn")
	check(r02.get("facing") == "B", "19: facing wall B")
	g.dispatch("item:service_key")
	g.dispatch("service_door")
	check(not g.has_item("service_key"), "19: the key is retired at the service door")
	check("R05" in g.reachable("R02"), "19: R05 reachable")
	var b := GameSim.new()
	b.from_dict(g.to_dict())
	check("R05" in b.reachable("R02") and not b.has_item("service_key"), "19: stays open after a load")

## Round w1: the boat's notice and notebook line, the dusk lighthouse, item names.
func test_round_w1_lines() -> void:
	const BOAT := "A boat at the jetty. The water moves. The boat doesn't. It has no reflection."
	check(R01Sim.OBSERVATIONS["boat"] == BOAT, "w1: the boat's notebook line")
	check(R01Sim.NOTICE["boat"] == BOAT, "w1: the boat's notice says the same")
	var g := boat_game()
	var r := r01(g)
	r.state.noticed = []
	var ev := g.dispatch("launch")
	check(r.has_seen("boat"), "w1: looking at the boat notes it")
	check(g.state.notebook.has(ROOM + ".boat") or r.has_seen("boat"), "w1: the line is in the notebook")
	ev = g.dispatch("lighthouse")
	check("Dark" in says(ev), "w1: at dusk the lighthouse is dark (%s)" % says(ev))
	var g4 := game_in("s4")
	ev = g4.dispatch("lighthouse")
	check("lean with the horizon" in says(ev), "w1: s4, the lighthouse leans with the sea")
	for id in R01Sim.ITEMS:
		var it: Dictionary = R01Sim.ITEMS[id]
		var shown: String = it.get("short", it.name)
		check(shown.length() <= 14, "w1: %s has a name of 14 characters or fewer" % id)

# ---------------------------------------------------------------------------
# view (presentation only: layer stacks, labels, mix, fx timelines)
# ---------------------------------------------------------------------------
## Puts a live scene's jetty in state `s` (through the room's own debug stages).
func scene_in(scene, s: String) -> void:
	match s:
		"arrival": scene.room_jump(ROOM, 0)
		"boat": scene.room_jump(ROOM, 1)
		"s1": scene.room_jump(ROOM, 3)
		"s2": scene.tide_jump(4, ROOM)
		"s3": scene.room_jump(ROOM, 5)
		"s4": scene.tide_jump(6, ROOM)
		"s5": scene.room_jump(ROOM, 6)
		"s6": scene.room_jump(ROOM, 7)
		"s7": scene.room_jump(ROOM, 8)
		"A": scene.room_jump(ROOM, 9)

func layer_ids(v) -> Array:
	var out := []
	for l in v.layer_stack():
		out.append(l[0])
	return out

func layer(v, id: String) -> Array:
	for l in v.layer_stack():
		if l[0] == id:
			return l
	return []

func test_view_presentation() -> void:
	var scene = new_scene("user://room_test_R01_view.json")
	await process_frame
	const BACK := {"arrival": "back_b0_dusk", "boat": "back_b0_dusk", "s1": "back_b1_mud", "s2": "back_b2_high",
		"s3": "back_b3", "s4": "back_b4", "s5": "back_b5", "s6": "back_b5", "s7": "back_b7",
		"A": "back_end_a"}
	for s in STATES:
		scene_in(scene, s)
		var v = scene.room_view
		var r: R01Sim = scene.sim.room(ROOM)
		check(r.jetty_state() == s, "V: the scene stands in %s (got %s)" % [s, r.jetty_state()])
		var ids := layer_ids(v)
		var n := R01Sim.rank(s)
		check(ids[0] == BACK[s], "V: %s backdrop is %s" % [s, BACK[s]])
		check(ids.has("fg_jetty") and ids.has("line"), "V: %s draws the jetty and the line" % s)
		check(ids.has("stump") == (n >= 3), "V: %s stump only from s3" % s)
		check(ids.has("bell_calm") == (s != "s7" and s != "A"), "V: %s bell calm rim (not s7, not the ending)" % s)
		check(ids.has("lighthouse_roof") == (s == "s6"), "V: %s roof lighthouse only at s6" % s)
		check(ids.has("surface_drift") == (s == "s7") and ids.has("station_window_figure") == (s == "s7"),
			"V: %s surface and office figure only at s7" % s)
		check(ids.has("launch_real") == (s == "A") and ids.has("boat") == (s == "boat"),
			"V: %s the right vessel" % s)
		check(ids.has("gangway_down") == (s == "boat") and (ids.has("gangway_up") != ids.has("gangway_down")),
			"V: %s one gangway, down only for the boat" % s)
		var rain := ids.filter(func(i): return i.begins_with("rain_"))
		var want := "" if (n == 0 or n == 7 or s == "A") else ("rain_light" if n == 1
			else ("rain_heavy" if n <= 4 else "rain_hang"))
		check((rain.is_empty() and want == "") or (rain.size() == 1 and rain[0].begins_with(want)),
			"V: %s rain %s" % [s, want])
		check(ids.has("station_lamp") == (scene.sim.flag("P01") and s != "A"), "V: %s office lamp follows P01" % s)
		check(ids.has("station_lamp") == false or ids.find("station_lamp") > ids.find("fg_jetty"),
			"V: %s the lamp sits over the painted station" % s)
		var cap := ids.has("capsule_closed") or ids.has("capsule_open")
		check(cap == (r.capsule_state() != "none"), "V: %s capsule drawn after P06" % s)
		for l in v.layer_stack():
			var m: Color = l[2]
			check(m.r >= 0.85, "V: %s %s modulate stays at or above 0.85" % [s, l[0]])
		var w := []
		for l in v.layer_stack():
			if str(l[0]).begins_with("waves_"):
				w = l
		if s == "s1":
			check(w.is_empty(), "V: s1 no waves: the sea's out")
		elif n <= 6 and s != "A":
			var a: float = w[2].a if not w.is_empty() else -1.0
			var wa := 1.0 if n <= 2 else (0.8 if n <= 4 else 0.5)
			check(is_equal_approx(a, wa), "V: %s waves alpha %.1f" % [s, wa])
		else:
			check(w.is_empty(), "V: %s no waves" % s)
		# The mix follows the state; a close-up keeps it at 0.7x.
		v.tick(0.016)
		var tg: Dictionary = v.mixer.last_targets
		check(tg == v.MIX[s], "V: %s loop targets" % s)
	# Labels per state.
	scene_in(scene, "boat")
	var v = scene.room_view
	check(v.label_for("launch") == "Boat" and v.label_for("stump") == "Tenth piling", "V: boat labels (after Tide I)")
	scene_in(scene, "arrival")
	check(scene.room_view.label_for("launch") == "Open water", "V: open water before the boat")
	check(scene.room_view.label_for("stump") == "Past the jetty's end", "V: nothing past the end before Tide I")
	scene_in(scene, "s3")
	check(scene.room_view.label_for("stump") == "Tenth piling" and scene.room_view.label_for("line") == "Capsule",
		"V: s3 labels")
	scene_in(scene, "s6")
	check(scene.room_view.label_for("roof_light") == "Lighthouse", "V: s6 roof label")
	scene_in(scene, "A")
	check(scene.room_view.label_for("launch") == "Launch", "V: A label")
	# Hotspots never move, and each answers at its centre in every state.
	for s in STATES:
		scene_in(scene, s)
		for h in scene.room_view.HOTSPOTS:
			check(scene.action_at(h[1].get_center()) == h[0], "V: %s %s answers at its centre" % [s, h[0]])
	# Motion: still alternatives.
	scene_in(scene, "s3")
	v = scene.room_view
	scene.sim.settings.motion = false
	check(v.reflection_dx("s3") == 6.0 and v.wave_frame("s3") == 0 and v.rain_frame("s3") == 0,
		"V: still s3 is displaced reflections, wave 0, rain 0")
	scene.sim.settings.motion = true
	# The arrival hold: exits off, hover off, a line up ends it, the timer ends it.
	v.play_fx("notice", {"state": "s3"})
	check(not v.exits_active() and v.hover_at(Vector2(700, 700)) == "", "V: the hold suppresses exits and hover")
	v.tick(1.6)
	check(v.exits_active(), "V: the hold ends after 1.5 s")
	v.play_fx("notice", {"state": "s3"})
	scene.cur_text = R01Sim.NOTICE["s3"]
	v.tick(0.01)
	check(not v.holding(), "V: the noticed line going up ends the hold")
	# The withdrawal, from the commit click.
	scene.room_jump(ROOM, 2)
	scene.dispatch("panel")
	scene.dispatch("bell_2")
	v = scene.room_view
	var r01s: R01Sim = scene.sim.room(ROOM)
	check(scene.sim.flag("P06") and v.withdrawing(), "V: the commit starts the withdrawal")
	check(v.tide_defer == 3 and scene.tide_card_t >= 99.0, "V: the TIDE III card is held off 'Bell two'")
	v.withdraw_t = 15.0
	v.tick(0.016)
	check(v.tide_defer == 3, "V: still held at the knock")
	v.withdraw_t = 15.7
	v.tick(0.016)
	check(v.tide_defer == 0 and scene.tide_card_n == 3 and scene.tide_card_t < 1.0, "V: the card comes up after the knock")
	check(r01s.jetty_state() == "s1", "V: the jetty is already s1 underneath")
	v.withdraw_t = 4.9
	var moored := layer(v, "boat")
	check(layer_ids(v).has("gangway_down") and moored[1] == Vector2.ZERO and moored[4] == 1.0, "V: moored until 5.0 s")
	check(layer_ids(v).find("boat") > layer_ids(v).find("fg_jetty"), "V: moored, it lies in front of the jetty")
	check(layer_ids(v).has("figure_window") or layer_ids(v).has("figure_window_turned"),
		"V: the figure is in the window during the withdrawal")
	# Its stern's waterline corner, where the transform puts it.
	var stern := func(l: Array) -> Vector2: return l[1] + v.BOAT_STERN * float(l[4])
	v.withdraw_t = 6.0
	var b6 := layer(v, "boat")
	v.withdraw_t = 8.0
	var b8 := layer(v, "boat")
	check(layer_ids(v).has("gangway_up") and b8[4] < b6[4] and b6[4] < 1.0, "V: it shrinks as it goes (%.2f, %.2f)" % [b6[4], b8[4]])
	var s6: Vector2 = stern.call(b6)
	var s8: Vector2 = stern.call(b8)
	check(s8.x > s6.x and s8.y < s6.y and s6.x >= 1290.0, "V: stern first, toward the horizon (%s -> %s)" % [s6, s8])
	check(layer_ids(v).find("boat") < layer_ids(v).find("fg_jetty"), "V: receding, it goes behind the jetty")
	check(layer(v, "boat_window_lit")[4] == b8[4] and layer(v, "boat_window_lit")[1] == b8[1], "V: its window goes with it")
	v.withdraw_t = 10.95
	var bend := layer(v, "boat")
	var send: Vector2 = stern.call(bend)
	check(bend[4] < 0.15 and send.distance_to(v.BOAT_END) < 12.0 and bend[2].a < 1.0,
		"V: it ends as the dot past the lighthouse (%.2f at %s)" % [bend[4], send])
	check(not layer_ids(v).has("capsule_closed"), "V: no capsule before the rise")
	v.withdraw_t = 11.2
	check(not layer_ids(v).has("boat"), "V: the boat has gone by 11 s")
	v.withdraw_t = 12.5
	var cl := layer(v, "capsule_closed")
	check(not cl.is_empty() and cl[1].y > 0.0 and cl[3] == 870.0, "V: the capsule rises, clipped at the waterline")
	v.withdraw_t = 14.9
	check(not v.exits_active(), "V: exits wait for 15 s")
	v.withdraw_t = 15.1
	check(v.exits_active() and layer(v, "capsule_closed")[1].y == 0.0, "V: the capsule at the cleat, exits back")
	# Hush, then restore.
	v.withdraw_t = 1.0
	v.tick(0.016)
	check(v.mixer.last_targets.is_empty(), "V: every loop hushes during the dead bell")
	# Still withdrawal.
	scene.sim.settings.motion = false
	v.withdraw_t = 6.0
	check(layer(v, "boat")[4] == v.BOAT_STILL_SCALE, "V: still, the boat stands off, small")
	v.withdraw_t = 8.5
	check(not layer_ids(v).has("boat"), "V: still, gone after 8 s")
	v.withdraw_t = 11.6
	check(layer(v, "capsule_closed")[1].y == 0.0, "V: still, the capsule appears at the top")
	scene.sim.settings.motion = true
	v.apply_instantly()
	check(not v.withdrawing() and layer(v, "capsule_closed")[1].y == 0.0, "V: entry snaps, no replay")
	# The gangway cut.
	scene.room_jump(ROOM, 1)
	scene.dispatch("gangway")
	v = scene.room_view
	var ids2 := layer_ids(v)
	check(ids2.has("ada_door") and ids2.has("gangway_up") and ids2.has("boat"), "V: the cut shows her at the door")
	v.tick(2.7)
	check(not layer_ids(v).has("ada_door") and layer_ids(v).has("gangway_down"), "V: and cuts back after 2.6 s")
	# Close-ups: controls, the mix at 0.7x, the note card.
	scene.room_jump(ROOM, 2)
	scene.dispatch("panel")
	v = scene.room_view
	check(scene.action_at(Vector2(500, 360)) == "tally_verified" and scene.action_at(Vector2(900, 360)) == "tally_unverified"
		and scene.action_at(Vector2(700, 600)) == "placard" and scene.action_at(Vector2(644, 800)) == "bell_2",
		"V: panel controls")
	v.tick(0.016)
	check(is_equal_approx(v.mixer.last_targets.get("sea_jetty", 0.0), 0.7), "V: close-ups keep the mix at 0.7x")
	scene.room_jump(ROOM, 3)
	scene.dispatch("line")
	scene.dispatch("cap")
	scene.dispatch("key")
	check(not scene.chain_active() and scene.lines.all(func(l): return not l.story),
		"V: the key's line is not queued behind a story chain from the cap")
	scene.room_jump(ROOM, 3)
	scene.dispatch("line")
	scene.dispatch("cap")
	scene.dispatch("note")
	v = scene.room_view
	check(v.note_open, "V: the note card opens")
	check(scene.room_view.action_at(Vector2(100, 900)) == "" and not v.note_open, "V: a click dismisses it")
	check(scene.action_at(Vector2(668, 200)) == "key", "V: the key standing in the capsule's mouth")
	await test_view_w1(scene)
	await free_scene(scene)

## Round w1 presentation: the dusk first visit, the band-4 tilt, hanging rain, the s7 mix,
## the chart room in the boat's window.
func test_view_w1(scene) -> void:
	for s in ["arrival", "boat"]:
		scene_in(scene, s)
		var v = scene.room_view
		var ids := layer_ids(v)
		check(v.BACKDROP[s] == "back_b0_dusk" and ids[0] == "back_b0_dusk", "W1: %s is dusk" % s)
		check(ids.has("reflections_dusk") and not ids.has("reflections"), "W1: %s every piling's reflection" % s)
		check(ids.has("dusk_lamps") and ids.find("dusk_lamps") > ids.find("fg_jetty"), "W1: %s lamps over the jetty" % s)
		# frozen sky, moving water: the backdrop never shifts, the wave frame does
		var frames := {}
		for t in [0.0, 0.5, 1.0, 1.5]:
			scene.time = t
			var st: Array = v.layer_stack()
			check(st[0][1] == Vector2.ZERO, "W1: %s the overcast doesn't drift" % s)
			for l in st:
				if str(l[0]).begins_with("waves_dusk_"):
					frames[l[0]] = true
		check(frames.size() == 3, "W1: %s the waves keep animating (%s)" % [s, frames.keys()])
		var fg: Color = layer(v, "fg_jetty")[2]
		var ln: Color = layer(v, "line")[2]
		check(is_equal_approx(ln.r, minf(1.0, fg.r * v.PROP_LIFT)) and ln.r > fg.r, "W1: %s props lifted over the dusk" % s)
	scene_in(scene, "boat")
	var vb = scene.room_view
	var ids_b := layer_ids(vb)
	check(ids_b.find("boat") > ids_b.find("reflections_dusk"), "W1: the boat lies over the reflections, with none of its own")
	check(ResourceLoader.exists("res://assets/rooms/R01/back_b0.png"), "W1: back_b0 is kept")
	# band 4: the waves turn about the jetty's end; the calm and causeway lie level over them
	scene_in(scene, "s4")
	var v4 = scene.room_view
	var w4 := []
	for l in v4.layer_stack():
		if str(l[0]).begins_with("waves_"):
			w4 = l
	check(w4.size() > 5 and is_equal_approx(w4[5], deg_to_rad(v4.TILT_DEG)), "W1: s4 waves turned 3 degrees")
	check(layer_ids(v4).find("b4_level") > layer_ids(v4).find(w4[0]), "W1: s4 the calm and causeway stay level over them")
	scene.sim.settings.motion = false
	var w4s := []
	for l in v4.layer_stack():
		if str(l[0]).begins_with("waves_"):
			w4s = l
	check(w4s.size() > 5 and w4s[5] == w4[5], "W1: s4 still is the same tilt")
	scene.sim.settings.motion = true
	for s in ["s3", "s5", "s6", "s7"]:
		scene_in(scene, s)
		for l in scene.room_view.layer_stack():
			check(l.size() <= 5 or l[5] == 0.0, "W1: %s nothing turned outside band 4" % s)
	# bands 5-6: the rain hangs, seeded per band, and is drawn in the tests' colour
	for s in ["s5", "s6"]:
		scene_in(scene, s)
		var v = scene.room_view
		var n := R01Sim.rank(s)
		var a: Array = v.layer_stack()
		scene.time = 3.7
		var b: Array = v.layer_stack()
		check(layer_ids(v).has("rain_hang_%d" % n), "W1: %s rain hangs" % s)
		check(is_equal_approx(layer(v, "rain_hang_%d" % n)[2].a, v.RAIN_HANG_ALPHA), "W1: %s at 70%%" % s)
		check(v.rain_frame(s) == 0, "W1: %s rain frames stop" % s)
		var d1: PackedVector2Array = v.rain_hang_dashes(n)
		v.rain_hang.clear()
		check(d1 == v.rain_hang_dashes(n) and d1.size() > 600, "W1: %s dashes are deterministic" % s)
		check(not v.MIX[s].has("rain_planks"), "W1: %s the rain is silent" % s)
	check(scene.room_view.rain_hang_dashes(5) != scene.room_view.rain_hang_dashes(6), "W1: seeded per band")
	# band 7: something under the hum that small speakers can play
	scene_in(scene, "s7")
	var m7: Dictionary = scene.room_view.MIX["s7"]
	check(is_equal_approx(m7.pressure_hum, 0.35) and is_equal_approx(m7.sea_thin, 0.2), "W1: s7 mix")
	# the lens on the boat's window: R03's chart room
	scene.room_jump(ROOM, 1)
	scene.dispatch("item:inspection_lens")
	scene.dispatch("launch")
	var vw = scene.room_view
	check(scene.sim.room(ROOM).local_view == R01Sim.C_WINDOW, "W1: the lens opens the window")
	for id in ["c_boat_window_chart", "c_boat_window_chart_figure", "c_boat_window_chart_figure_turned"]:
		check(vw._tex(id) != null, "W1: %s exists" % id)
	await process_frame


# ---------------------------------------------------------------------------
# round w2: the tenth piling, the storm bands, the capsule's rects
# ---------------------------------------------------------------------------
func test_round_w2_lines() -> void:
	# Before Tide I: nine pilings, nothing past the end.
	var g0 := game_at(1, ROOM)
	check(not g0.tide_done(1), "w2: the arrival game is in Tide I")
	var ev := g0.dispatch("pilings")
	check(says(ev) == "Nine pilings. From the launch I counted eight.", "w2: Tide I, nine pilings (%s)" % says(ev))
	ev = g0.dispatch("stump")
	check("but water" in says(ev), "w2: Tide I, nothing past the end")
	# After tide_done(1): ten, in every state before the stump.
	for s in ["boat", "s1", "s2"]:
		var g := game_in(s)
		var r := r01(g)
		check(g.tide_done(1), "w2: %s is after Tide I" % s)
		ev = g.dispatch("pilings")
		check(says(ev) == R01Sim.PILINGS_TEN and r.has_seen("pilings_ten"), "w2: %s ten pilings (%s)" % [s, says(ev)])
		check(R01Sim.PILINGS_TEN == "Ten pilings now. I counted eight from the launch.", "w2: the line, exactly")
		ev = g.dispatch("stump")
		check("holds nothing up" in says(ev) and r.has_seen("tenth_piling"), "w2: %s the tenth piling (%s)" % [s, says(ev)])
	# Arrival state but after Tide I (a revisit before P05): ten as well.
	var ga := with_flags(["P01", "P02", "P03"], ROOM)
	check(r01(ga).jetty_state() == "arrival" and ga.tide_done(1), "w2: arrival after Tide I")
	check(says(ga.dispatch("pilings")) == R01Sim.PILINGS_TEN, "w2: arrival after Tide I counts ten")
	# From band 3 it's a stump again (sawn).
	var g3 := game_in("s3")
	check("stump of a tenth" in says(g3.dispatch("pilings")), "w2: s3, nine and a stump")
	# The notebook keeps the earlier count.
	var gk := with_flags(["P01"], ROOM)
	gk.dispatch("pilings")
	for f in ["P02", "P03"]:
		gk.set_flag(f)
	gk.dispatch("pilings")
	check(r01(gk).has_seen("pilings") and r01(gk).has_seen("pilings_ten"), "w2: both counts stay in the notebook")
	# Bands 1-2: the lighthouse is dark; band 1 is mud.
	for s in ["s1", "s2"]:
		var g := game_in(s)
		ev = g.dispatch("lighthouse")
		check("Dark" in says(ev) and not "Lit" in says(ev), "w2: %s the lighthouse is unlit (%s)" % [s, says(ev)])
	check("Lit now" in says(game_in("s3").dispatch("lighthouse")), "w2: s3 lit again")
	var g1 := game_in("s1")
	ev = g1.dispatch("launch")
	check("Mud" in says(ev) and r01(g1).has_seen("sea_out"), "w2: s1 mud where the boat sat")
	ev = g1.dispatch("bell")
	check("gone out" in says(ev), "w2: s1 the water round the bell stays")
	ev = g1.dispatch("causeway")
	check("mud" in says(ev), "w2: s1 the causeway on the mud")
	var g2 := game_in("s2")
	check("higher" in says(g2.dispatch("bell")), "w2: s2 the sea back, higher")
	for k in R01Sim.OBSERVATIONS:
		check(R01Sim.OBSERVATIONS[k] != "", "w2: %s has notebook text" % k)

func test_view_w2() -> void:
	var scene = new_scene("user://room_test_R01_w2.json")
	await process_frame
	# Plates: new files, never the bright band plates.
	scene_in(scene, "s1")
	for id in ["back_b1_mud", "back_b1_sea", "back_b2_high", "high_water", "tenth_piling"]:
		check(scene.room_view._tex(id) != null, "W2: %s exists" % id)
	for s in ["s1", "s2"]:
		scene_in(scene, s)
		var v = scene.room_view
		var ids := layer_ids(v)
		check(not ids.has("back_b1") and not ids.has("back_b2") and not ids.has("reflections"),
			"W2: %s none of the bright band plates" % s)
		check(ids.has("tenth_piling") and ids.find("tenth_piling") > ids.find("fg_jetty"), "W2: %s the tenth piling shows" % s)
		check(ids.has("high_water") == (s == "s2"), "W2: %s high water only at band 2" % s)
		check(ids.has("bell_calm"), "W2: %s the bell keeps its water" % s)
	scene_in(scene, "s2")
	var ids2 := layer_ids(scene.room_view)
	check(ids2.find("high_water") < ids2.find("line") and ids2.find("high_water") < ids2.find("capsule_open"),
		"W2: s2 the line and capsule stay over the high water")
	check(ids2.has("reflections_dusk") and ids2.any(func(i): return str(i).begins_with("waves_dusk_")),
		"W2: s2 the storm sea's own dark marks")
	# The tenth piling: from tide_done(1) until the stump replaces it.
	scene_in(scene, "arrival")
	check(not layer_ids(scene.room_view).has("tenth_piling"), "W2: arrival in Tide I, nine")
	scene_in(scene, "boat")
	check(layer_ids(scene.room_view).has("tenth_piling"), "W2: boat (after Tide I), ten")
	for s in ["s3", "s5", "s7", "A"]:
		scene_in(scene, s)
		var ids := layer_ids(scene.room_view)
		check(not ids.has("tenth_piling") and ids.has("stump"), "W2: %s the stump, not the whole piling" % s)
	# The drain: the sea is in through the withdrawal, then goes out under the card.
	scene.room_jump(ROOM, 2)
	scene.dispatch("panel")
	scene.dispatch("bell_2")
	var v = scene.room_view
	check(scene.sim.room(ROOM).jetty_state() == "s1" and v.withdrawing(), "W2: withdrawing at s1")
	for t in [0.0, 11.5, 14.5, 15.9]:
		v.withdraw_t = t
		var ids := layer_ids(v)
		check(ids[0] == "back_b1_sea" and layer(v, "back_b1_mud")[2].a == 0.0, "W2: %.1f s the sea is still in" % t)
		check(ids.any(func(i): return str(i).begins_with("waves_dusk_")), "W2: %.1f s waves on it" % t)
	v.withdraw_t = 18.0
	var mid: float = layer(v, "back_b1_mud")[2].a
	check(mid > 0.0 and mid < 1.0, "W2: 18 s the mud is coming up (%.2f)" % mid)
	v.withdraw_t = 20.5
	check(layer_ids(v)[0] == "back_b1_mud" and not layer_ids(v).any(func(i): return str(i).begins_with("waves_")),
		"W2: 20.5 s the sea is out")
	scene.sim.settings.motion = false
	v.withdraw_t = 15.9
	check(v.drain_k() == 0.0, "W2: motion off, the sea is in before the cut")
	v.withdraw_t = 16.0
	check(v.drain_k() == 1.0, "W2: motion off, a cut at DRAIN_AT")
	scene.sim.settings.motion = true
	v.apply_instantly()
	check(v.drain_k() == 1.0 and layer_ids(v)[0] == "back_b1_mud", "W2: a revisit is mud at once")
	check(v.TIDE_CARD_AT < v.DRAIN_AT, "W2: the drain starts after the card is up")
	# Capsule close-up: with the cap off, the note wins over the cap's old rect.
	scene.room_jump(ROOM, 3)
	scene.dispatch("line")
	v = scene.room_view
	var note_c: Vector2 = v.CAPSULE_RECTS["note"].get_center()
	var overlap := Vector2(776, 270)   # the note's lower half, where the closed cap's drum was
	check(v.CAPSULE_RECTS["cap"].has_point(overlap) and v.CAPSULE_RECTS["note"].has_point(overlap),
		"W2: the closed cap's rect overlaps the note's")
	check(scene.action_at(overlap) == "cap", "W2: closed, the drum is the cap")
	scene.dispatch("cap")
	check(scene.action_at(overlap) == "note", "W2: open, the note wins where they overlapped")
	check(scene.action_at(note_c) == "note", "W2: open, the note at its centre")
	check(scene.action_at(Vector2(650, 270)) == "key", "W2: open, the key below its tag")
	check(scene.action_at(Vector2(926, 470)) == "cap", "W2: open, the cap hanging on its chain")
	check(scene.action_at(Vector2(700, 320)) == "", "W2: open, the empty mouth is not the cap")
	check(v.dev_rects().size() == 3 and v.dev_rects()[0] == v.CAPSULE_RECTS_OPEN["note"], "W2: dev rects follow")
	scene.dispatch("note")
	check(v.note_open, "W2: the overlap click reads the note")
	await free_scene(scene)
