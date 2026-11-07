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
	await view_checks(ROOM)

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
	check(g.flag("P06") and r01(g).capsule_state() == "open" and g.has_item("service_key"), "13: tide III")
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
	games["after"] = game_at(3, ROOM)
	games["done"] = game_at(5, ROOM)
	for o in R01Sim.HINTS:
		var g: GameSim = games[o]
		check(r01(g).objective() == o, "17: objective %s (got %s)" % [o, r01(g).objective()])
		var before := JSON.stringify(g.to_dict().rooms.R01)
		for lvl in 3:
			var ev := g.dispatch("hint")
			check(says(ev) == R01Sim.HINTS[o][lvl], "17: %s hint %d" % [o, lvl])
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
	var door: bool = "service_door" in g.room("R02").c("HOTSPOTS", [])
	if not door:
		print("SKIP R01 test 19: R02 service_door not built yet")
		return
	g.dispatch("item:service_key")
	g.dispatch("service_door")
	check(not g.has_item("service_key"), "19: the key is retired at the service door")
	check("R05" in g.reachable("R02"), "19: R05 reachable")
	var b := GameSim.new()
	b.from_dict(g.to_dict())
	check("R05" in b.reachable("R02") and not b.has_item("service_key"), "19: stays open after a load")
