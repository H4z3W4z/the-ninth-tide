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
	await test_view_presentation()

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
	const BACK := {"arrival": "back_b0", "boat": "back_b0", "s1": "back_b1", "s2": "back_b2",
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
		var want := "" if (n == 0 or n == 7 or s == "A") else ("rain_light" if n == 1 else "rain_heavy")
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
		var w := layer(v, "waves_0") if not layer(v, "waves_0").is_empty() else []
		for k in 3:
			if w.is_empty():
				w = layer(v, "waves_%d" % k)
		if n <= 6 and s != "A":
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
	check(v.label_for("launch") == "Boat" and v.label_for("stump") == "Past the jetty's end", "V: boat labels")
	scene_in(scene, "arrival")
	check(scene.room_view.label_for("launch") == "Open water", "V: open water before the boat")
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
	await free_scene(scene)
