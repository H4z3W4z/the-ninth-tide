extends "res://tests/rooms/room_test_base.gd"
## R11, the Dry Stair: P12 (the pressure gate) over every pressure x plate placement, P24 (the
## lower door) over every frame mapping, the two landings, the notices, saves and debug.
##   godot --headless --path . --script tests/rooms/R11_test.gd

const ROOM := "R11"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := ["P04"]
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 3

## Reference tables, written out independently of R11Sim.
const REF_P_ONLY := {
	"unequal": "Pressure not equal. The black needle's off the brass one.",
	"noref": "No reference. The brass needle has nothing to read from.",
}
const REF_L_ONLY := {
	"none": "NO CORRESPONDING LANDING.",
	"reversed": "Brackets face the wrong way across the boundary.",
	"incomplete": "It wants a plate in each slot.",
}
const REF_BOTH_P := {"unequal": "The pressure's not equal", "noref": "There's no reference"}
const REF_BOTH_L := {"none": "there's no landing for those plates", "reversed": "the brackets face the wrong way",
	"incomplete": "one slot's empty"}
const REF_FALSE := "Through the port: steps going down to a landing that ends in a wall of water. No door."
const REF_BELOW := "That's below the gate. I can't get down there."
const REF_LOCKED := "The glass is locked down. Stencilled under it: AWAITING PREPARED RECORD."
const NORA := ["nora_frame", "nora_spatial_strip", "amended_nora_card"]
const NORA_CAT := {"nora_frame": "BODY", "nora_spatial_strip": "PLACE", "amended_nora_card": "NAME"}
const FRAME_T := {"BODY": "frame_body", "PLACE": "frame_place", "NAME": "frame_name"}
const DOOR_ITEMS := ["nora_frame", "nora_spatial_strip", "amended_nora_card", "witness_bridge", "nora_register_card"]

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	test_constants()
	test_p12_unpowered()
	test_p12_no_reference()
	test_p12_exhaustive()
	test_p12_false_landing()
	test_p12_success()
	test_p12_idempotent()
	test_p12_parallel_pair()
	test_p12_save_load()
	test_p12_reachability()
	test_plate_grammar()
	test_landings()
	test_descend()
	test_notices()
	test_p24_locked()
	test_p24_mappings()
	test_p24_copy_blocks()
	test_p24_no_witness()
	test_p24_complete_card()
	test_p24_wrong_items()
	test_p24_inventory()
	test_p24_success()
	test_p24_bridge_forced()
	test_p24_save_load()
	test_p24_reachability()
	test_closeup_exit()
	test_room_lines()
	test_objectives()
	test_debug()
	if _view_ready():
		await view_checks(ROOM)
	else:
		print("SKIP: R11 view_checks: the R11 view does not yet declare rects for every sim hotspot (view team)")

# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
func r11(g: GameSim) -> R11Sim:
	return g.room(ROOM) as R11Sim

func _view_ready() -> bool:
	var m: Dictionary = load("res://game/rooms/R11/R11_view.gd").get_script_constant_map()
	var ids := []
	for h in m.get("HOTSPOTS", []):
		ids.append(h[0])
	for id in R11Sim.HOTSPOTS + R11Sim.L2_HOTSPOTS:
		if not id in ids:
			return false
	return true

## Another room's puzzle, granted by its flag and that room's own reconcile.
func grant(g: GameSim, rid: String, f: String) -> void:
	g.set_flag(f)
	g.room(rid).reconcile()

## Tide IV in the stair with the station feeding the gate (P10 + P11).
func gate_game() -> GameSim:
	var g := game_at(4, ROOM)
	grant(g, "R08", "P11")
	grant(g, "R07", "P10")
	return g

func roundtrip(g: GameSim) -> GameSim:
	var t := GameSim.new()
	check(t.from_dict(JSON.parse_string(JSON.stringify(g.to_dict()))), "the save loads")
	return t

func same_save(a: GameSim, b: GameSim) -> bool:
	return JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict())

func say_ev(ev: Array, text: String) -> Dictionary:
	for e in ev:
		if e.type == "say" and e.text == text:
			return e
	return {}

func ev_of(ev: Array, type: String, id: String) -> Dictionary:
	for e in ev:
		if e.type == type and e.get("id", "") == id:
			return e
	return {}

func count_ev(ev: Array, type: String, id: String) -> int:
	var k := 0
	for e in ev:
		if e.type == type and e.get("id", "") == id:
			k += 1
	return k

func notices_in(ev: Array) -> Array:
	var out := []
	for e in ev:
		if e.type == "fx" and e.get("id", "") == "notice":
			out.append(e.notice)
	return out

func use(g: GameSim, item: String, target: String) -> Array:
	g.dispatch("item:" + item)
	return g.dispatch(target)

## The expected flags for a powered, referenced pull.
func ref_flags(pressure: int, slots: Array) -> Dictionary:
	var p := "equal" if pressure == 2 else "unequal"
	var l := "ok"
	if slots[0] == "o2" or slots[1] == "o2":
		l = "none"
	elif slots[0] == "" or slots[1] == "":
		l = "incomplete"
	elif slots[0] == "c1" and slots[1] == "o1":
		l = "reversed"
	return {"p": p, "l": l}

func ref_line(p: String, l: String) -> String:
	if p != "equal" and l != "ok":
		return "%s, and %s." % [REF_BOTH_P[p], REF_BOTH_L[l]]
	if p != "equal":
		return REF_P_ONLY[p]
	return REF_L_ONLY[l]

## Every UPPER x LOWER placement: each in {"", o1, c1, o2}, non-empty ones distinct.
func placements() -> Array:
	var out := []
	for a in ["", "o1", "c1", "o2"]:
		for b in ["", "o1", "c1", "o2"]:
			if a != "" and a == b:
				continue
			out.append([a, b])
	return out

## Lays plates through the close-up's controls: clears both slots to the rack, then sets them.
func lay_plates(g: GameSim, slots: Array) -> void:
	var r := r11(g)
	for i in 2:
		if r.state.slots[i] != "":
			g.dispatch(["slot_upper", "slot_lower"][i])   # picks it up
			g.dispatch("plate_" + r.held_plate)           # puts it back on the rack
	for i in 2:
		if slots[i] != "":
			g.dispatch("plate_" + slots[i])
			g.dispatch(["slot_upper", "slot_lower"][i])

func wheel_to(g: GameSim, p: int) -> void:
	var r := r11(g)
	while int(r.state.pressure) < p:
		g.dispatch("wheel_up")
	while int(r.state.pressure) > p:
		g.dispatch("wheel_down")

func solve_p12(g: GameSim) -> Array:
	g.dispatch("gate")
	wheel_to(g, 2)
	lay_plates(g, ["o1", "c1"])
	return g.dispatch("lever_open")

## Tide VIII in the stair, P22 + P23 done, all four door items in hand, at the lower door.
func door_game(live := true) -> GameSim:
	var g := game_at(8, ROOM)
	if live:
		grant(g, "R06", "P22")
		g.set_flag("P23")
	for it in NORA + ["witness_bridge"]:
		g.give(it)
	g.dispatch("descend")
	g.dispatch("lower_door")
	return g

func mounted(r: R11Sim) -> Array:
	var out := []
	for f in R11Sim.FRAMES:
		if r.state.frames[f] != "":
			out.append(r.state.frames[f])
	if r.state.witness != "":
		out.append(r.state.witness)
	if r.state.copy != "":
		out.append(r.state.copy)
	return out

## No door item is ever lost or doubled: each one in hand xor on the door.
func inv_consistent(g: GameSim, items: Array) -> bool:
	var on := mounted(r11(g))
	for it in items:
		var n := (1 if g.has_item(it) else 0) + on.count(it)
		if n != 1:
			return false
	return true

## Takes everything off the door through bare clicks.
func clear_door(g: GameSim) -> void:
	var r := r11(g)
	for f in R11Sim.FRAMES:
		if r.state.frames[f] != "":
			g.dispatch(FRAME_T[f])
	if r.state.witness != "":
		g.dispatch("socket_witness")
	if r.state.copy != "":
		g.dispatch("port_copy")

# ---------------------------------------------------------------------------------------------
# constants and contract
# ---------------------------------------------------------------------------------------------
func test_constants() -> void:
	var g := GameSim.new()
	var r := r11(g)
	check(not r.c("SKELETON", false), "R11 is built (no SKELETON)")
	check(not g.is_unbuilt(ROOM), "the core sees R11 as built")
	check(r.c("TITLE") == "Dry Stair" and r.c("LOCKED") == "The observation hatch is shut.", "title and locked line")
	check(r.c("RESUME") == "Back on the dry stair.", "resume line")
	check(r.c("WAY_IN_HINT") == "The hatch in the chart room goes down to the dry stair.", "way-in hint")
	check(JSON.stringify(r.c("EXITS")) == JSON.stringify([["R03", "Chart room", []], ["R07", "Laboratory", ["P12"]],
		["R09", "Lantern gallery", []], ["R12", "Lower door", []]]), "exits as built")
	check(r.c("ITEMS") == {}, "R11 hands out no items")
	check(R11Sim.HOTSPOTS == ["gauge", "plates", "placard", "water_plane", "steps", "gate"], "landing 1 hotspots")
	check(R11Sim.L2_HOTSPOTS == ["shoes", "bell_sound", "ceiling", "return_door", "upper_stair", "lower_door"], "landing 2 hotspots")
	check(r.is_closeup("c_gate") and r.is_closeup("c_chamber_door") and not r.is_closeup("room"), "close-ups")
	for h in R11Sim.HOTSPOTS + R11Sim.L2_HOTSPOTS + R11Sim.GATE_CONTROLS + R11Sim.DOOR_CONTROLS:
		check(not h in R11Sim.NAV, "%s is not a nav action" % h)
	for n in R11Sim.NOTICES:
		for o in n[3]:
			check(R11Sim.OBSERVATIONS.has(o), "notice %s evidence %s is an observation" % [n[0], o])
	for o in ["tide_hatch", "plane_shelves", "finger_marks", "copy_refusal", "chamber_open", "false_landing"]:
		check(R11Sim.OBSERVATIONS.has(o), "observation %s declared" % o)
	for k in R11Sim.OBJECTIVES:
		check(R11Sim.HINTS.has(k) and R11Sim.HINTS[k].size() == 3, "objective %s has a three-step ladder" % k)
	check(R11Sim.HINTS.p12[2] == "Pressure 2. Bracket-1 plate in UPPER, its closing bracket in LOWER. Pull OPEN.", "P12 card hint 3")
	check(R11Sim.HINTS.p24[2] == "Frame to BODY, strip to PLACE, amended card to NAME, bridge to WITNESS, COPY empty, OPEN ACCESS.", "P24 card hint 3")
	var fresh := r.initial_state()
	check(fresh.pressure == 0 and fresh.slots == ["", ""] and fresh.witness == "" and fresh.copy == "", "initial state")

# ---------------------------------------------------------------------------------------------
# P12
# ---------------------------------------------------------------------------------------------
func test_p12_unpowered() -> void:
	var g := game_at(4, ROOM)
	var r := r11(g)
	check(not r.powered() and r.needle_pressure() == 0 and r.needle_reference() == -1, "unpowered: needles at rest")
	var ev := g.dispatch("gate")
	check(r.local_view == "c_gate" and "Nothing's feeding it." in says(ev), "gate: unpowered close-up")
	var before := JSON.stringify(g.to_dict())
	ev = g.dispatch("lever_open")
	check(says(ev) == "No pressure in the line.", "unpowered lever (%s)" % says(ev))
	check(has_ev(ev, "sfx", "r11_lever_refuse") and r.gate_note == {"p": "unpowered", "l": ""}, "unpowered: refusal sfx and NO PRESSURE")
	check(JSON.stringify(g.to_dict()) == before and not g.flag("P12"), "unpowered pull changes nothing")
	check(R11Sim.flag_text(r.flags_shown()) == "NO PRESSURE.", "flags read NO PRESSURE")
	ev = g.dispatch("wheel_up")
	check(r.state.pressure == 1 and r.needle_pressure() == 0, "the wheel turns; the needle doesn't")
	check(says(ev) == "It turns. The needle doesn't." and has_ev(ev, "sfx", "r11_wheel_dead"), "dead wheel line")
	ev = g.dispatch("wheel_up")
	check(r.state.pressure == 2 and says(ev) == "", "dead wheel line once")
	g.dispatch("wheel_down")
	g.dispatch("wheel_down")
	ev = g.dispatch("wheel_down")
	check(r.state.pressure == 0 and says(ev) == "It's at the stop.", "the bottom stop")
	for i in 6:
		ev = g.dispatch("wheel_up")
	check(r.state.pressure == 5 and says(ev) == "It's at the stop.", "the top stop")
	check(r.state.dead_wheel_said and roundtrip(g).room(ROOM).state.dead_wheel_said, "dead_wheel_said saves")
	check(says(g.dispatch("gauge_face")) == "The gauge is dead. No pressure in the line.", "dead gauge face")
	check(r.objective() == "wait_power", "unpowered: wait_power")

func test_p12_no_reference() -> void:
	var g := game_at(4, ROOM)
	grant(g, "R08", "P11")
	var r := r11(g)
	var ev := g.dispatch("gauge")
	check(says(ev) == "Live now. The black needle follows the wheel. The brass one lies on NO REFERENCE.", "powered gauge line")
	check(r.has_seen("gauge_powered") and not r.has_seen("gauge_reference"), "gauge_powered noted")
	ev = g.dispatch("wheel_up")
	check(has_ev(ev, "sfx", "r11_wheel_click") and says(ev) == "", "live wheel clicks")
	g.dispatch("wheel_up")
	check(r.needle_pressure() == 2 and r.needle_reference() == -1, "needle follows; brass at NO REFERENCE")
	lay_plates(g, ["o1", "c1"])
	ev = g.dispatch("lever_open")
	check(r.gate_note == {"p": "noref", "l": "ok"}, "noref flags (%s)" % [r.gate_note])
	check(says(ev) == REF_P_ONLY.noref and not g.flag("P12"), "no reference refuses")
	check(r.objective() == "wait_power", "P11 alone: still waiting")

func test_p12_exhaustive() -> void:
	var g := gate_game()
	var r := r11(g)
	check(r.needle_reference() == 2, "referenced: the brass needle at 2")
	check(r.objective() == "p12", "P10 + P11: the gate is the work")
	g.dispatch("gate")
	var inv := JSON.stringify(g.state.inventory)
	var flags := JSON.stringify(g.state.flags)
	var cases := 0
	var solving := []
	for p in range(0, 6):
		for pl in placements():
			if p == 2 and pl == ["o1", "c1"]:
				continue
			wheel_to(g, p)
			lay_plates(g, pl)
			cases += 1
			check(r.state.slots == pl and r.state.pressure == p, "arranged %d %s" % [p, pl])
			var ev := g.dispatch("lever_open")
			var want := ref_flags(p, pl)
			check(r.gate_note == want, "%d %s: flags %s (got %s)" % [p, pl, want, r.gate_note])
			check(says(ev).begins_with(ref_line(want.p, want.l)), "%d %s: line '%s' (got '%s')" % [p, pl, ref_line(want.p, want.l), says(ev)])
			check(has_ev(ev, "sfx", "r11_lever_pull") and has_ev(ev, "sfx", "r11_lever_refuse"), "%d %s: pull and refuse" % [p, pl])
			check(r.state.slots == pl and r.state.pressure == p, "%d %s: nothing moved" % [p, pl])
			check(JSON.stringify(g.state.inventory) == inv and JSON.stringify(g.state.flags) == flags, "%d %s: no flag or item change" % [p, pl])
			if g.flag("P12"):
				solving.append([p, pl])
	check(cases == 6 * 13 - 1, "all %d other cases covered (%d)" % [6 * 13 - 1, cases])
	check(solving.is_empty(), "nothing else solves (%s)" % [solving])
	# The only solution.
	wheel_to(g, 2)
	lay_plates(g, ["o1", "c1"])
	g.dispatch("lever_open")
	check(g.flag("P12") and r.state.p12_complete, "pressure 2 with [ 1 over ] 1 solves P12")
	# Both-wrong composition, spot-checked against the card's words.
	check(ref_line("unequal", "reversed") == "The pressure's not equal, and the brackets face the wrong way.", "composition reads")

func test_p12_false_landing() -> void:
	var g := gate_game()
	var r := r11(g)
	g.dispatch("gate")
	var stories := 0
	for pl in placements():
		if not "o2" in pl:
			continue
		for p in [2, 4]:
			wheel_to(g, p)
			lay_plates(g, pl)
			var ev := g.dispatch("lever_open")
			check(has_ev(ev, "fx", "false_landing"), "%s at %d: the false landing shows" % [pl, p])
			check(has_ev(ev, "sfx", "r11_port_open") and has_ev(ev, "sfx", "r11_false_water"), "%s: port sounds" % [pl])
			check(r.port_view() == "false", "%s: the port shows the false landing" % [pl])
			var s := say_ev(ev, REF_FALSE)
			if not s.is_empty():
				stories += 1
				check(s.story and is_equal_approx(float(s.delay), 1.2), "the false landing is a story line at 1.2")
	check(stories == 1, "the false landing's line comes once (%d)" % stories)
	check(r.has_seen("false_landing") and r.state.false_seen, "false_landing noted")
	check(says(g.dispatch("port")) == "Shuttered again. I know what's behind it.", "the port after")
	wheel_to(g, 2)
	lay_plates(g, ["o1", "c1"])
	var ev2 := g.dispatch("lever_open")
	check(g.flag("P12") and not has_ev(ev2, "fx", "false_landing"), "a correct pull shows no false landing")

func test_p12_success() -> void:
	var g := gate_game()
	var r := r11(g)
	check(g.weather_band() == 2 and g.tide() == 4, "tide IV, band 2")
	var ev := solve_p12(g)
	check(g.flag("P12") and g.tide_done(4) and g.weather_band() == 3, "P12: tide IV done, band 3")
	check(count_ev(ev, "fx", "tide") == 1, "one tide fx")
	var gl := ev_of(ev, "fx", "glance")
	check(gl.get("rect", []) == [386, 330, 140, 120] and gl.get("target", "") == "bell_sound", "glance at the bell (%s)" % [gl])
	check(r.landing == 2 and r.local_view == "room", "she is on the lower landing")
	check(r.has_seen("gate_opened") and r.has_seen("bell"), "gate_opened and bell noted")
	check(g.exit_open(ROOM, "R07") and g.exit_open(ROOM, "R09") and not g.exit_open(ROOM, "R12"), "R07 and R09 open; R12 shut")
	check("n_glass" in r.state.notices and "n_bell" in r.state.notices, "the commit marks its notices")
	var first := say_ev(ev, "PRESSURE EQUAL. LANDING 1 CORRESPONDS.")
	check(first.get("story", false) and is_equal_approx(float(first.get("delay", 0)), 0.2), "the flags line opens the chain")
	var bell := say_ev(ev, "There. It hangs stopped, halfway through a swing. It has no clapper.")
	check(bell.get("story", false) and is_equal_approx(float(bell.get("delay", 0)), 9.0), "the clapper line closes it")
	check(r.gate_up() and r.glass_mode() == "glass" and r.bell_dir() == "above" and r.port_view() == "true", "view helpers after P12")
	check(r.flags_shown() == {"p": "equal", "l": "ok"}, "the flags stay EQUAL / CORRESPONDS")
	check(g.state.inventory == roundtrip(g).state.inventory, "nothing given or taken")
	check(r.objective() == "wait_door", "after P12: wait_door")

func test_p12_idempotent() -> void:
	var g := gate_game()
	var r := r11(g)
	solve_p12(g)
	var flags := JSON.stringify(g.state.flags)
	g.dispatch("gate")
	check(r.local_view == "c_gate", "the gate close-up opens after P12")
	for a in ["lever_open", "wheel_up", "wheel_down", "slot_upper", "plate_o2"]:
		var ev := g.dispatch(a)
		check(says(ev) == "Open. I'm leaving it as it is.", "%s after P12 (%s)" % [a, says(ev)])
		check(not has_ev(ev, "fx", "tide"), "%s: no second tide" % a)
	check(says(g.dispatch("port")) == "The port shows the landing below. The real one.", "the real port")
	check(says(g.dispatch("flags")) == "PRESSURE EQUAL. LANDING 1 CORRESPONDS.", "the flags after P12")
	check(r.state.pressure == 2 and r.state.slots == ["o1", "c1"], "the arrangement holds")
	check(JSON.stringify(g.state.flags) == flags, "flags unchanged")

func test_p12_parallel_pair() -> void:
	var results := []
	for order in [[["R07", "P10"], ["R08", "P11"]], [["R08", "P11"], ["R07", "P10"]]]:
		var g := game_at(4, ROOM)
		for step in order:
			grant(g, step[0], step[1])
		var lab := JSON.stringify(g.room("R07").state)
		var mach := JSON.stringify(g.room("R08").state)
		var ev := solve_p12(g)
		check(g.flag("P10") and g.flag("P11") and g.flag("P12"), "P12 with %s first" % order[0][1])
		check(JSON.stringify(g.room("R07").state) == lab and JSON.stringify(g.room("R08").state) == mach,
			"P12 leaves R07 and R08 as they were (%s first)" % order[0][1])
		results.append([JSON.stringify(ev), JSON.stringify(g.room(ROOM).state), JSON.stringify(g.state.flags)])
	check(results[0][0] == results[1][0] and results[0][1] == results[1][1], "either order: identical P12 events and state")
	check(results[0][2] == results[1][2], "either order: identical flags")

func test_p12_save_load() -> void:
	var g := gate_game()
	var r := r11(g)
	g.dispatch("gate")
	wheel_to(g, 3)
	lay_plates(g, ["c1", ""])
	g.dispatch("plate_o1")
	check(r.held_plate == "o1", "a plate in hand")
	var t := roundtrip(g)
	var rt := r11(t)
	check(rt.state.pressure == 3 and rt.state.slots == ["c1", ""], "pressure and slots survive")
	check(rt.held_plate == "" and rt.local_view == "room" and rt.landing == 1, "the hand and close-up drop on load")
	check(rt.state.pressure is int, "pressure loads as an int")
	check(same_save(roundtrip(t), t), "the mid-puzzle save round-trips byte-identical")
	# Malformed saves.
	var cases := [
		[{"pressure": 9}, "pressure", 5],
		[{"pressure": 2.5}, "pressure", 0],
		[{"pressure": -3}, "pressure", 0],
		[{"pressure": "2"}, "pressure", 0],
		[{"slots": ["o1", "o1"]}, "slots", ["", ""]],
		[{"slots": ["o9", ""]}, "slots", ["", ""]],
		[{"slots": ["o1"]}, "slots", ["", ""]],
		[{"slots": ["", "o2"]}, "slots", ["", "o2"]],
		[{"notices": ["n_tide1", "n_bogus", "n_tide1", 4]}, "notices", ["n_tide1"]],
		[{"frames": {"BODY": "pencil", "PLACE": "", "NAME": ""}}, "frames", {"BODY": "", "PLACE": "", "NAME": ""}],
		[{"witness": "nora_frame"}, "witness", ""],
		[{"copy": "pencil"}, "copy", ""],
	]
	for cs in cases:
		var d: Dictionary = r.initial_state()
		for k in cs[0]:
			d[k] = cs[0][k]
		var s := game_at(4, ROOM)
		r11(s).load_state(d)
		check(JSON.stringify(r11(s).state[cs[1]]) == JSON.stringify(cs[2]), "malformed %s -> %s (got %s)" % [cs[0], cs[2], r11(s).state[cs[1]]])
	# Duplicate item across mounts: every mount defaults.
	var dup: Dictionary = r.initial_state()
	dup.frames = {"BODY": "nora_frame", "PLACE": "nora_spatial_strip", "NAME": ""}
	dup.copy = "nora_frame"
	dup.witness = "witness_bridge"
	var s2 := game_at(8, ROOM)
	r11(s2).load_state(dup)
	check(r11(s2).state.frames == {"BODY": "", "PLACE": "", "NAME": ""} and r11(s2).state.copy == "" and r11(s2).state.witness == "",
		"one item in two mounts rejects all mounts")
	# p24 without p12; p12 forces the arrangement.
	var d3: Dictionary = r.initial_state()
	d3.p24_complete = true
	d3.pressure = 4
	d3.frames = {"BODY": "nora_frame", "PLACE": "", "NAME": ""}
	var s3 := game_at(8, ROOM)
	r11(s3).load_state(d3)
	var st: Dictionary = r11(s3).state
	check(st.p12_complete and st.pressure == 2 and st.slots == ["o1", "c1"], "p24 implies p12 and its arrangement")
	check(st.frames.BODY == "" and r11(s3).landing == 2, "p24 empties the mounts; lands below")
	# A save whose room state lost P12 still opens it from the flag.
	var s4 := gate_game()
	solve_p12(s4)
	var raw: Dictionary = JSON.parse_string(JSON.stringify(s4.to_dict()))
	raw.rooms.R11.p12_complete = false
	var s5 := GameSim.new()
	s5.from_dict(raw)
	check(r11(s5).state.p12_complete and s5.flag("P12"), "the flag and state agree after load")
	raw.flags.erase("P12")
	var s6 := GameSim.new()
	s6.from_dict(raw)
	check(not s6.flag("P12") and not r11(s6).state.p12_complete, "no flag, no state: shut")

func test_p12_reachability() -> void:
	var g := gate_game()
	var before := g.reachable("R02")
	check(ROOM in before and not "R09" in before, "before P12: the stair, not the gallery")
	solve_p12(g)
	var reach := g.reachable("R02")
	check("R09" in reach and not "R10" in reach and not "R12" in reach, "after P12: R09 reachable; R10 and R12 not (%s)" % [reach])
	for rid in before:
		check(rid in reach, "after P12: %s still reachable" % rid)

func test_plate_grammar() -> void:
	var g := gate_game()
	var r := r11(g)
	g.dispatch("plates")
	check(r.local_view == "c_gate" and r.rack_plates() == ["o1", "c1", "o2"], "all three on the rack")
	var ev := g.dispatch("slot_upper")
	check(says(ev) == "An empty slot.", "empty slot")
	ev = g.dispatch("plate_o1")
	check(r.held_plate == "o1" and has_ev(ev, "sfx", "r11_plate_pick") and r.rack_plates() == ["c1", "o2"], "pick o1")
	g.dispatch("plate_o1")
	check(r.held_plate == "", "the same plate toggles back")
	g.dispatch("plate_o1")
	g.dispatch("plate_o2")
	check(r.held_plate == "o2" and "o1" in r.rack_plates(), "another plate: the first goes back to the rack")
	ev = g.dispatch("slot_upper")
	check(r.state.slots == ["o2", ""] and r.held_plate == "" and has_ev(ev, "sfx", "r11_plate_set"), "set o2 in UPPER")
	g.dispatch("plate_o1")
	g.dispatch("slot_upper")
	check(r.state.slots == ["o1", ""] and r.held_plate == "" and "o2" in r.rack_plates(), "a swap sends the old plate to the rack")
	g.dispatch("slot_upper")
	check(r.state.slots == ["", ""] and r.held_plate == "o1", "a bare slot click picks its plate")
	g.dispatch("slot_lower")
	g.dispatch("plate_o1")
	check(r.state.slots == ["", ""] and r.held_plate == "o1", "picking a slotted plate lifts it out")
	g.dispatch("back")
	check(r.local_view == "room" and r.held_plate == "" and r.rack_plates().size() == 3, "Back drops the hand")

# ---------------------------------------------------------------------------------------------
# landings
# ---------------------------------------------------------------------------------------------
func test_landings() -> void:
	var g := game_at(4, "R03")
	g.dispatch("go:R11")
	check(g.state.room == ROOM and r11(g).landing == 1, "from the chart room: landing 1")
	for from in ["R07", "R09"]:
		var h := game_at(5, from)
		h.dispatch("go:R11")
		check(h.state.room == ROOM and r11(h).landing == 2, "from %s after P12: landing 2" % from)
		h.dispatch("go:R03")
		check(h.state.room == "R03", "the hatch exit from below")
		h.dispatch("go:R11")
		check(r11(h).landing == 1, "back from R03: landing 1")
	var k := game_at(9, "R12")
	k.dispatch("go:R11")
	check(k.state.room == ROOM and r11(k).landing == 2, "from the chamber: landing 2")
	var p := game_at(5, "R02")
	p.dispatch("notebook")
	p.dispatch("plan:R11")
	check(p.state.room == ROOM and r11(p).landing == 2, "plan travel after P05 + P12: landing 2")
	var q := game_at(4, "R02")
	q.dispatch("notebook")
	q.dispatch("plan:R11")
	check(q.state.room == ROOM and r11(q).landing == 1, "plan travel before P12: landing 1")
	var s := game_at(5, ROOM)
	r11(s).landing = 1
	check(r11(roundtrip(s)).landing == 2, "a load lands on default_landing (2 after P12)")
	check(r11(roundtrip(game_at(4, ROOM))).landing == 1, "a load lands on default_landing (1 before P12)")

func test_descend() -> void:
	var g := game_at(4, ROOM)
	var r := r11(g)
	var before := JSON.stringify(g.to_dict())
	var ev := g.dispatch("descend")
	check(says(ev) == "The gate's down across the stair." and r.landing == 1, "descend before P12 refused")
	check(JSON.stringify(g.to_dict()) == before, "the refusal changes nothing")
	for h in R11Sim.L2_HOTSPOTS:
		ev = g.dispatch(h)
		check(says(ev) == REF_BELOW and r.landing == 1 and r.local_view == "room", "%s before P12 is below the gate" % h)
	ev = use(g, "inspection_lens", "shoes")
	check(says(ev) == REF_BELOW, "items on landing 2 before P12: below the gate")
	var s := game_at(5, ROOM)
	var rs := r11(s)
	s.dispatch("ascend")
	check(rs.landing == 1, "ascend")
	ev = s.dispatch("descend")
	check(rs.landing == 2 and says(ev).begins_with("Down, through the glass.") and has_ev(ev, "sfx", "r11_glass_pass"), "descend after P12")
	ev = s.dispatch("ascend")
	check(rs.landing == 1 and says(ev).begins_with("Back up to the gate."), "ascend line")
	ev = s.dispatch("steps")
	check(rs.landing == 2 and says(ev).begins_with("Down, through the glass."), "steps after P12 descend")

# ---------------------------------------------------------------------------------------------
# notices
# ---------------------------------------------------------------------------------------------
func test_notices() -> void:
	# Band 1, first real arrival at tide III.
	var g := game_at(3, "R03")
	var r := r11(g)
	g.state.visited.erase(ROOM)
	var ev := g.dispatch("go:R11")
	check(says(ev).begins_with("The steps go down through a sheet of water.") and notices_in(ev) == ["n_arrival"], "first visit: arrival")
	var st := say_ev(ev, "Below it they're dry. And there's no sound of water. None.")
	check(st.get("story", false) and is_equal_approx(float(st.get("delay", 0)), 2.4), "arrival's story line at 2.4")
	check(r.has_seen("steps") and r.has_seen("water_plane"), "arrival notes steps and water plane")
	g.dispatch("go:R03")
	ev = g.dispatch("go:R11")
	check(notices_in(ev) == ["n_tide1"] and "A line of salt on the wall" in says(ev), "band 1: the first salt line (%s)" % [notices_in(ev)])
	check(has_ev(ev, "sfx", "r11_salt_tick") and r.has_seen("tide_line"), "salt tick and tide_line")
	var line := say_ev(ev, "A line of salt on the wall, above the water. Nothing below it is wet.")
	check(line.get("story", false) and is_equal_approx(float(line.get("delay", 0)), 1.6), "notice line: story at 1.6")
	g.dispatch("go:R03")
	ev = g.dispatch("go:R11")
	check(notices_in(ev).is_empty(), "band 1 notice plays once")
	check(notices_in(roundtrip(g).dispatch("go:R03")).is_empty(), "loads cleanly")
	var t := roundtrip(g)
	t.dispatch("go:R03")
	ev = t.dispatch("go:R11")
	check(notices_in(ev).is_empty(), "the seen notice survives save/load")
	# Band 2.
	var h := game_at(4, "R03")
	h.dispatch("go:R11")
	h.dispatch("go:R03")
	check("n_tide2" in r11(h).state.notices, "band 2 plays")
	ev = h.dispatch("go:R11")
	check(notices_in(ev).is_empty(), "band 2 once")
	var h2 := game_at(4, "R03")
	ev = h2.dispatch("go:R11")
	check(notices_in(ev) == ["n_tide2"] and r11(h2).has_seen("tide_lines"), "band 2: the second salt line")
	var h3 := roundtrip(h2)
	h3.dispatch("go:R03")
	check(notices_in(h3.dispatch("go:R11")).is_empty(), "band 2 notice survives save/load")
	# Band 7 on landing 1: older notices settle silently, only the top line plays.
	var k := game_at(9, "R03")
	var rk := r11(k)
	rk.state.notices = []
	var keep := []
	for key in k.state.notebook:
		if not key in ["R11.tide_line", "R11.tide_lines", "R11.more_steps", "R11.plane_shelves", "R11.gate_opened"]:
			keep.append(key)
	k.state.notebook = keep
	ev = k.dispatch("go:R11")
	check(rk.landing == 1 and notices_in(ev) == ["n_tide_top"], "band 7 on landing 1: only n_tide_top (%s)" % [notices_in(ev)])
	for n in ["n_arrival", "n_tide1", "n_tide2", "n_glass", "n_more_steps", "n_shelves", "n_tide_top"]:
		check(n in rk.state.notices, "band 7: %s seen" % n)
	for o in ["tide_line", "tide_lines", "more_steps", "plane_shelves", "gate_opened", "tide_hatch"]:
		check(rk.has_seen(o), "band 7: %s noted" % o)
	check(says(ev) == "The salt line's up at the hatch.", "only the top line is said")
	# Band 7 on landing 2: nothing pending.
	var k2 := game_at(9, "R12")
	ev = k2.dispatch("go:R11")
	check(r11(k2).landing == 2 and notices_in(ev).is_empty(), "band 7 on landing 2: nothing pending (%s)" % [notices_in(ev)])
	for n in ["n_bell", "n_shoes_wet", "n_shoes_facing", "n_finger"]:
		check(n in r11(k2).state.notices, "band 7 landing 2: %s seen" % n)
	# n_shoes_facing: two story lines.
	var f := game_at(8, "R09")
	ev = f.dispatch("go:R11")
	check(notices_in(ev) == ["n_shoes_facing"], "band 6 below: the shoes face the stair (%s)" % [notices_in(ev)])
	var a := say_ev(ev, "The shoes are side by side now, facing the stair.")
	var b := say_ev(ev, "And the bell's coming from below. Through the lower door.")
	check(a.get("story", false) and b.get("story", false) and is_equal_approx(float(b.get("delay", 0)), 2.6), "two story lines, the second at 2.6")
	check(is_equal_approx(float(ev_of(ev, "sfx", "r11_shoe_set").get("delay", -1)), 0.5), "the shoe sound at 0.5")
	check(r11(f).has_seen("shoes_facing") and r11(f).has_seen("bell_below"), "both evidence ids noted")
	check("n_shoes_wet" in r11(f).state.notices and r11(f).has_seen("shoes_wet"), "the wet shoes are behind her")
	# Wet shoes at band 4.
	var w := game_at(6, "R09")
	ev = w.dispatch("go:R11")
	check(notices_in(ev) == ["n_shoes_wet"] and not has_ev(ev, "sfx", "r11_shoe_set"), "band 4 below: wet shoes, no sound")
	ev = w.dispatch("ascend")
	check(notices_in(ev) == ["n_more_steps"], "band 4 above: more steps (%s)" % [notices_in(ev)])
	var sh := game_at(7, "R09")
	sh.dispatch("go:R11")
	ev = sh.dispatch("ascend")
	check(notices_in(ev) == ["n_shelves"] and has_ev(ev, "sfx", "r11_shelf_hush"), "band 5 above: the shelves")
	# No notices once an ending is chosen.
	var e := game_at(9, "R03")
	r11(e).state.notices = []
	e.state.ending = "sever"
	ev = e.dispatch("go:R11")
	check(notices_in(ev).is_empty(), "no notices with ending_choice set")

# ---------------------------------------------------------------------------------------------
# P24
# ---------------------------------------------------------------------------------------------
func test_p24_locked() -> void:
	var g := door_game(false)
	var r := r11(g)
	check(r.local_view == "c_chamber_door", "the door close-up opens")
	check(not r.door_live(), "before P22 + P23 the door is dead")
	for it in NORA + ["witness_bridge"]:
		for target in ["frame_body", "frame_place", "frame_name", "socket_witness", "port_copy", "lever_access"]:
			var ev := use(g, it, target)
			check(says(ev) == REF_LOCKED and g.has_item(it), "%s on %s before P22/P23: refused, kept" % [it, target])
	check(mounted(r).is_empty(), "nothing mounted")
	var ev2 := g.dispatch("lever_access")
	check(says(ev2) == "The lever's locked. AWAITING PREPARED RECORD." and r.door_preview() == "AWAITING PREPARED RECORD", "dead lever")
	check(not g.flag("P24"), "no P24")
	check(r.objective() == "wait_door", "wait_door before P22/P23")

func test_p24_mappings() -> void:
	var g := door_game()
	var r := r11(g)
	check(r.door_live() and r.objective() == "p24", "the door is live")
	var tried := 0
	for a in [""] + NORA:
		for b in [""] + NORA:
			for c in [""] + NORA:
				var pick := [a, b, c]
				var used := []
				var ok := true
				for x in pick:
					if x != "":
						ok = ok and not x in used
						used.append(x)
				if not ok or pick == NORA:
					continue
				clear_door(g)
				for i in 3:
					if pick[i] != "":
						var ev := use(g, pick[i], FRAME_T[R11Sim.FRAMES[i]])
						check(says(ev) == "In the %s frame." % R11Sim.FRAMES[i], "mount %s" % pick[i])
				use(g, "witness_bridge", "socket_witness")
				var ev2 := g.dispatch("lever_access")
				tried += 1
				var empty := []
				for i in 3:
					if pick[i] == "":
						empty.append(R11Sim.FRAMES[i])
				var want := ""
				if not empty.is_empty():
					want = "RECORD INCOMPLETE: " + ", ".join(empty)
				else:
					for i in 3:
						var fr: String = R11Sim.FRAMES[i]
						if NORA_CAT[pick[i]] != fr:
							want = "%s FRAME: NOT A %s RECORD" % [fr, fr]
							break
				check(r.door_note == want, "%s: %s (got %s)" % [pick, want, r.door_note])
				check(not g.flag("P24") and has_ev(ev2, "sfx", "r11_access_lever"), "%s: no P24" % [pick])
				check(inv_consistent(g, NORA + ["witness_bridge"]), "%s: inventory consistent" % [pick])
				for i in 3:
					var fr2: String = R11Sim.FRAMES[i]
					var res := "EMPTY" if pick[i] == "" else ("ACCEPTED" if NORA_CAT[pick[i]] == fr2 else "NOT A %s RECORD" % fr2)
					check(r.frame_results[fr2] == res, "%s: %s result %s" % [pick, fr2, res])
	check(tried == 33, "every other mapping tried (%d)" % tried)
	clear_door(g)
	for i in 3:
		use(g, NORA[i], FRAME_T[R11Sim.FRAMES[i]])
	use(g, "witness_bridge", "socket_witness")
	g.dispatch("lever_access")
	check(g.flag("P24"), "the right mapping, the bridge and COPY bare: P24")

func set_correct(g: GameSim, except := "") -> void:
	for i in 3:
		if NORA[i] != except:
			use(g, NORA[i], FRAME_T[R11Sim.FRAMES[i]])
	if except != "witness_bridge":
		use(g, "witness_bridge", "socket_witness")

func test_p24_copy_blocks() -> void:
	for it in DOOR_ITEMS:
		var g := door_game()
		g.give("nora_register_card")
		var r := r11(g)
		set_correct(g, it)
		var ev := use(g, it, "port_copy")
		check(says(ev) == "The shutter snaps shut over it." and r.state.copy == it, "%s into COPY" % it)
		ev = g.dispatch("lever_access")
		check(r.door_note == "WOULD FINALIZE SUBJECT" and not g.flag("P24"), "%s in COPY: WOULD FINALIZE SUBJECT" % it)
		check(says(ev) == "WOULD FINALIZE SUBJECT. The lever won't move while anything's in COPY.", "COPY refusal line")
		check(r.has_seen("copy_refusal"), "copy_refusal noted")
		check(inv_consistent(g, DOOR_ITEMS), "%s: nothing taken or given by the refusal" % it)
		ev = g.dispatch("port_copy")
		check(says(ev) == "Out." and g.has_item(it), "%s back out of COPY" % it)

func test_p24_no_witness() -> void:
	var g := door_game()
	var r := r11(g)
	set_correct(g, "witness_bridge")
	var ev := g.dispatch("lever_access")
	check(r.door_note == "NO WITNESS. RECORD WILL CLOSE." and says(ev) == "Nothing in the witness socket. It would close on its own.", "no witness")
	check(not g.flag("P24"), "no witness: no P24")

func test_p24_complete_card() -> void:
	var g := door_game()
	g.give("nora_register_card")
	var r := r11(g)
	use(g, "nora_frame", "frame_body")
	use(g, "nora_spatial_strip", "frame_place")
	use(g, "nora_register_card", "frame_name")
	use(g, "witness_bridge", "socket_witness")
	var ev := g.dispatch("lever_access")
	check(r.door_note == "RECORD COMPLETE. ACCESS DENIED TO COMPLETE RECORDS.", "the unamended card: RECORD COMPLETE")
	check(says(ev) == "RECORD COMPLETE. ACCESS DENIED TO COMPLETE RECORDS. It won't open for a finished record.", "complete-record line")
	check(not g.flag("P24") and inv_consistent(g, DOOR_ITEMS), "nothing consumed")
	check(says(g.dispatch("preview")) == r.door_note, "the preview re-reads the note")

func test_p24_wrong_items() -> void:
	var g := door_game()
	var r := r11(g)
	g.give("pencil")
	for target in ["frame_body", "frame_place", "frame_name", "socket_witness", "port_copy"]:
		var ev := use(g, "pencil", target)
		check(says(ev) == "Not a record of her." and g.has_item("pencil"), "pencil on %s refused, kept" % target)
	check(mounted(r).is_empty(), "nothing mounted by a wrong item")
	var ev2 := use(g, "witness_bridge", "frame_body")
	check(says(ev2) == "It's a plug, not a record." and g.has_item("witness_bridge"), "the bridge isn't a record")
	ev2 = use(g, "nora_frame", "socket_witness")
	check(says(ev2) == "The socket takes a plug, not a record." and g.has_item("nora_frame"), "a record isn't a plug")
	ev2 = use(g, "inspection_lens", "port_copy")
	check(says(ev2) == "Through the lens the COPY port's shutter is worn bright at the edges.", "lens on the door")
	check(says(g.dispatch("frame_body")) == "An empty frame, labelled BODY. Glass front, spring clips.", "empty frame")
	check(says(g.dispatch("socket_witness")) == "A socket under a hollow circle: WITNESS. It takes a plug.", "empty socket")
	check(says(g.dispatch("port_copy")) == "COPY. AUTOMATIC. Its shutter is sprung open.", "empty port")
	check(says(g.dispatch("preview")) == "Blank.", "blank preview")
	check(says(g.dispatch("door_plate")).begins_with("INDEX ACCESS."), "door plate")

func test_p24_inventory() -> void:
	var g := door_game()
	var r := r11(g)
	var items := NORA + ["witness_bridge"]
	use(g, "amended_nora_card", "frame_body")
	check(r.state.frames.BODY == "amended_nora_card" and not g.has_item("amended_nora_card"), "any record mounts in any frame")
	check(inv_consistent(g, items), "mount: consistent")
	var ev := use(g, "nora_frame", "frame_body")
	check(r.state.frames.BODY == "nora_frame" and g.has_item("amended_nora_card") and has_ev(ev, "sfx", "r11_frame_mount"), "a swap gives the old record back")
	check(inv_consistent(g, items), "swap: consistent")
	use(g, "witness_bridge", "port_copy")
	use(g, "nora_spatial_strip", "port_copy")
	check(r.state.copy == "nora_spatial_strip" and g.has_item("witness_bridge"), "COPY swaps too")
	check(inv_consistent(g, items), "copy swap: consistent")
	use(g, "witness_bridge", "socket_witness")
	ev = g.dispatch("socket_witness")
	check(says(ev) == "Out." and g.has_item("witness_bridge") and r.state.witness == "" and has_ev(ev, "sfx", "r11_frame_unmount"), "unmount the bridge")
	g.dispatch("frame_body")
	g.dispatch("port_copy")
	check(mounted(r).is_empty() and inv_consistent(g, items), "everything back in hand")
	use(g, "nora_frame", "frame_body")
	g.dispatch("back")
	check(r.local_view == "room" and r.state.frames.BODY == "nora_frame", "mounts stay on the door after Back")
	check(inv_consistent(roundtrip(g), items), "consistent across a load")

func test_p24_success() -> void:
	var g := door_game()
	var r := r11(g)
	check(g.weather_band() == 6 and g.tide() == 8, "tide VIII, band 6")
	set_correct(g)
	var ev := g.dispatch("lever_access")
	check(g.flag("P24") and g.tide_done(8) and g.weather_band() == 7, "P24: tide VIII done, band 7")
	check(count_ev(ev, "fx", "tide") == 1, "one tide fx")
	for it in NORA + ["witness_bridge"]:
		check(g.has_item(it), "%s back in hand" % it)
	check(mounted(r).is_empty(), "the mounts are empty")
	var gl := ev_of(ev, "fx", "glance")
	check(gl.get("rect", []) == [320, 450, 280, 430] and gl.get("target", "") == "lower_door", "glance at the door (%s)" % [gl])
	check(g.exit_open(ROOM, "R12"), "the chamber is open")
	check(r.local_view == "room" and r.landing == 2 and r.door_open(), "back on the landing, the door open")
	check(r.has_seen("chamber_open") and r.has_seen("finger_marks") and "n_finger" in r.state.notices, "chamber_open, finger_marks, n_finger")
	check(r.door_preview() == "RECORD VALID. RECORD OPEN.", "the preview")
	var l := say_ev(ev, "Finger marks. Hundreds, worn into the paint. At the height of someone sitting, reaching up.")
	check(l.get("story", false) and is_equal_approx(float(l.get("delay", 0)), 10.0), "finger marks at 10.0")
	check(says(g.dispatch("lower_door")).begins_with("Open. The finger marks"), "the open door")
	check(says(use(g, "nora_frame", "lower_door")) == "It's open.", "items on the open door")
	check(r.objective() == "done", "done")
	ev = g.dispatch("lever_access")
	check(not has_ev(ev, "fx", "tide"), "no second commit")

func test_p24_bridge_forced() -> void:
	var g := door_game()
	var r := r11(g)
	use(g, "witness_bridge", "socket_witness")
	check(not g.has_item("witness_bridge"), "the bridge is in the socket")
	g.set_flag("P24")
	r.objective()
	check(g.has_item("witness_bridge") and mounted(r).is_empty(), "P24 from elsewhere: the bridge still comes back")
	# The commit gives the bridge even if it has somehow already left the socket.
	var h := door_game()
	var rh := r11(h)
	set_correct(h)
	rh.state.witness = "witness_bridge"
	h.give("witness_bridge")
	h.take("witness_bridge")
	h.dispatch("lever_access")
	check(h.has_item("witness_bridge"), "the bridge always returns at the commit")

func test_p24_save_load() -> void:
	var g := door_game()
	use(g, "nora_frame", "frame_body")
	use(g, "amended_nora_card", "frame_place")
	use(g, "witness_bridge", "socket_witness")
	use(g, "nora_spatial_strip", "port_copy")
	var t := roundtrip(g)
	check(same_save(t, g), "a save with records mounted round-trips byte-identical")
	check(r11(t).state.frames == r11(g).state.frames and r11(t).state.copy == "nora_spatial_strip", "mounts survive")
	check(same_save(roundtrip(t), t), "and again")
	check(inv_consistent(t, NORA + ["witness_bridge"]), "loaded inventory consistent")

func test_p24_reachability() -> void:
	var g := door_game()
	set_correct(g)
	g.dispatch("lever_access")
	var reach := g.reachable("R02")
	for rid in ["R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R10", "R11", "R12"]:
		check(rid in reach, "band 7: %s reachable (%s)" % [rid, reach])

# ---------------------------------------------------------------------------------------------
# room lines, close-ups, objectives, debug
# ---------------------------------------------------------------------------------------------
func test_closeup_exit() -> void:
	var g := gate_game()
	var r := r11(g)
	g.dispatch("gate")
	g.dispatch("plate_o1")
	var ev := g.dispatch("water_plane")
	check(r.local_view == "room" and says(ev) != "" and r.held_plate == "", "a hotspot from the gate close-up closes it and answers")
	var h := door_game()
	var rh := r11(h)
	ev = h.dispatch("steps")
	check(rh.local_view == "room" and rh.landing == 2 and says(ev) != "", "steps from the door close-up: down again, answered")
	h.dispatch("lower_door")
	ev = h.dispatch("ceiling")
	check(rh.local_view == "room" and rh.has_seen("ceiling") and says(ev) != "", "an L2 hotspot from the door close-up")
	h.dispatch("lower_door")
	ev = h.dispatch("gauge")
	check(rh.local_view == "c_gate" and rh.landing == 1, "an L1 hotspot from below goes up to the gate")

func test_room_lines() -> void:
	var g := game_at(3, ROOM)
	var r := r11(g)
	var ev := g.dispatch("steps")
	check(says(ev).begins_with("Limewashed steps, going down through the water."), "steps first time")
	var marks: Dictionary = ev[1] if ev.size() > 1 else {}
	check(marks.get("delay", 0) == 2.2 and not marks.get("story", true), "the marks line at 2.2, not story")
	check(g.has_seen("R03", "scratches") == ("The same marks as the hatch frame." in says(ev)), "the hatch marks echo follows R03's notebook")
	check(r.has_seen("stair_marks"), "stair_marks noted")
	check(says(g.dispatch("steps")) == "The marks again, down the jamb: bracket, linked strokes, circle.", "steps again")
	ev = g.dispatch("water_plane")
	check(says(ev) == "I put my hand flat on it. It's not cold. It's not anything. It just stops me." and has_ev(ev, "sfx", "r11_plane_touch"), "water plane first touch")
	check(says(g.dispatch("water_plane")) == "Flat to the jambs. Not a drop over the edge.", "water plane again")
	check(says(use(g, "inspection_lens", "water_plane")).begins_with("Through the lens there's no surface"), "lens on the plane")
	ev = g.dispatch("plates")
	check(says(ev).begins_with("Three landing plates. '[ 1', '] 1', '[ 2'. There's no '] 2'."), "plates")
	check(g.has_seen("R03", "plan") == ("pairs its landings" in says(ev)), "the plan echo follows R03's notebook")
	ev = g.dispatch("placard")
	check(r.has_seen("placard") and r.local_view == "c_gate", "placard")
	check(says(g.dispatch("placard_read")) == says(ev), "placard read")
	check(says(g.dispatch("flags")) == "Blank until I pull.", "blank flags")
	check(says(g.dispatch("port")) == "A sight port, shuttered from the inside.", "shuttered port")
	check(says(g.dispatch("gauge")) == "The gauge is dead. No pressure in the line.", "dead gauge")
	# After P12 and up the bands.
	var s := game_at(5, ROOM)
	check(says(s.dispatch("water_plane")) == "The flat one still stops my hand. The one in the gateway doesn't.", "the plane after P12")
	check(says(s.dispatch("gate")) == "Up in the lintel. The water stands where the bars were.", "the open gate")
	check(says(s.dispatch("gauge")) == "The brass needle's come up to 2. The laboratory jar's reading.", "referenced gauge")
	r11(s).state.notices = []   # quiet the next landing
	s.dispatch("descend")
	var rs := r11(s)
	var sh := game_at(5, ROOM)
	var rsh := r11(sh)
	sh.state.notebook.erase("R11.shoes")
	check(says(sh.dispatch("shoes")).begins_with("A pair of shoes under the office desk."), "shoes first")
	check(says(sh.dispatch("shoes")) == "Empty shoes. One's fallen on its side.", "shoes again")
	check(says(use(sh, "inspection_lens", "shoes")) == "The laces are still tied.", "lens on the shoes")
	check(says(use(sh, "inspection_lens", "bell_sound")) == "The staple's worn bright, as if something still strikes it.", "lens on the bell")
	check(says(sh.dispatch("bell_sound")).begins_with("Tipped up toward the office"), "bell above")
	check(says(sh.dispatch("ceiling")).begins_with("Overhead, the underside"), "ceiling")
	check(says(sh.dispatch("return_door")) == "The laboratory's STAIR door. From this side it's stencilled LABORATORY.", "return door")
	check(says(sh.dispatch("upper_stair")).begins_with("A short stair up"), "upper stair")
	check(says(sh.dispatch("lower_door")).begins_with("Three glazed frames: BODY, PLACE, NAME."), "lower door before P21")
	check(rsh.local_view == "c_chamber_door" and rsh.has_seen("lower_door") and rsh.has_seen("copy_port"), "door close-up and notes")
	sh.give("nora_frame")
	check(says(use(sh, "nora_frame", "frame_body")) == REF_LOCKED and sh.has_item("nora_frame"), "a dead door before P22/P23")
	check(rsh.shoes_state() == "dry" and rsh.bell_dir() == "above" and rsh.tide_lines() == 2, "band 3 helpers")
	var w := game_at(6, ROOM)
	check(says(w.dispatch("shoes")) == "The shoes are wet through. Water's run out of them across the boards." and r11(w).has_seen("shoes_wet"), "wet shoes")
	check(r11(w).shoes_state() == "wet" and r11(w).glass_mode() == "deep" and not r11(w).shelves_shown(), "band 4 helpers")
	var v := game_at(7, ROOM)
	check(says(v.dispatch("water_plane")).begins_with("Shelves in it.") and r11(v).has_seen("plane_shelves"), "shelves in the plane")
	var f := game_at(8, ROOM)
	check(says(f.dispatch("shoes")) == "Side by side now. Toes to the stair." and r11(f).has_seen("shoes_facing"), "facing shoes")
	check(says(f.dispatch("bell_sound")).begins_with("Tipped the other way now") and r11(f).has_seen("bell_below"), "bell below")
	check(says(f.dispatch("lower_door")) == "Three frames and a witness. The plan's procedure, in iron.", "the door after P21")
	grant(f, "R06", "P22")
	f.set_flag("P23")
	f.dispatch("back")
	check(says(f.dispatch("lower_door")) == "Her three records. The bridge. And the port I leave alone.", "the live door")
	check(r11(f).bell_dir() == "below" and r11(f).shoes_state() == "facing", "band 6 helpers")
	var top := game_at(9, ROOM)
	check(r11(top).tide_lines() == 5 and r11(top).door_open(), "band 7 helpers")
	check(rs.landing == 2, "descended")

func test_objectives() -> void:
	var g := game_at(3, "R03")
	g.dispatch("go:R11")
	var r := r11(g)
	check(r.objective() == "explore", "explore first (%s)" % r.objective())
	g.dispatch("gate")
	check(r.objective() == "wait_power", "seen the gate: wait_power")
	var g2 := game_at(4, ROOM)
	var r2 := r11(g2)
	check(r2.objective() == "wait_power", "tide IV: wait_power")
	grant(g2, "R08", "P11")
	check(r2.objective() == "wait_power", "P11 alone: wait_power")
	grant(g2, "R07", "P10")
	check(r2.objective() == "p12", "P10 + P11: p12")
	solve_p12(g2)
	check(r2.objective() == "wait_door", "after P12: wait_door")
	check(g2.work_elsewhere() != "", "wait_door points elsewhere (%s)" % g2.work_elsewhere())
	grant(g2, "R06", "P22")
	g2.set_flag("P23")
	check(r2.objective() == "p24", "P22 + P23: p24")
	g2.set_flag("P24")
	check(r2.objective() == "done", "P24: done")
	for o in ["wait_power", "wait_door", "done"]:
		check(GameSim._idle(o), "%s is idle for the core" % o)
	for o in ["explore", "p12", "p24"]:
		check(not GameSim._idle(o), "%s is work" % o)
	var h := game_at(4, ROOM)
	check(h.work_elsewhere() != "", "wait_power points at the station's work (%s)" % h.work_elsewhere())

func test_debug() -> void:
	var g := GameSim.new()
	var r := r11(g)
	r.debug_jump(1)
	check(g.state.room == ROOM and g.tide() == 3 and r.landing == 1 and not r.powered(), "jump 1: the threshold")
	r.debug_jump(2)
	check(g.tide() == 4 and not r.powered(), "jump 2: unpowered")
	r.debug_jump(3)
	check(r.powered() and not r.referenced() and g.room("R08").state.p11_complete, "jump 3: powered, no reference")
	r.debug_jump(4)
	check(r.referenced() and r.state.pressure == 2 and r.state.slots == ["o2", "c1"], "jump 4: false landing set")
	g.dispatch("gate")
	check(has_ev(g.dispatch("lever_open"), "fx", "false_landing"), "jump 4: pull shows the false landing")
	r.debug_jump(5)
	check(r.state.slots == ["o1", "c1"] and r.local_view == "room", "jump 5: ready")
	g.dispatch("gate")
	g.dispatch("lever_open")
	check(g.flag("P12"), "jump 5: OPEN solves")
	r.debug_jump(6)
	check(r.landing == 2 and g.weather_band() == 3 and r.state.p12_complete, "jump 6: band 3 below")
	r.debug_jump(7)
	check(r.landing == 2 and g.weather_band() == 4 and r.shoes_state() == "wet", "jump 7: wet shoes")
	r.debug_jump(8)
	check(g.weather_band() == 6 and r.door_live() and r.state.copy == "", "jump 8: live door, band 6")
	check(r.state.frames == {"BODY": "nora_frame", "PLACE": "nora_spatial_strip", "NAME": "amended_nora_card"} and r.state.witness == "witness_bridge", "jump 8: mounted")
	check(inv_consistent(g, NORA + ["witness_bridge"]), "jump 8: inventory consistent")
	check(same_save(roundtrip(g), g), "jump 8 round-trips")
	g.dispatch("descend")
	g.dispatch("lower_door")
	g.dispatch("lever_access")
	check(g.flag("P24") and g.has_item("witness_bridge"), "jump 8: OPEN ACCESS solves")
	r.debug_jump(9)
	check(r.door_open() and r.landing == 2 and g.has_item("witness_bridge"), "jump 9: door open, bridge in hand")
	# debug_tide prepares the room as real play leaves it.
	for t in range(1, 10):
		var h := game_at(t, ROOM if t >= 3 else "R02")
		var rh := r11(h)
		check(rh.state.p12_complete == (t >= 5) and rh.state.p24_complete == (t >= 9), "tide %d: P12/P24 state" % t)
		check(rh.landing == rh.default_landing(), "tide %d: default landing" % t)
		check(same_save(roundtrip(h), h), "tide %d save round-trips" % t)
		if t >= 4:
			check(rh.has_seen("gate") and rh.has_seen("plates"), "tide %d: survey done" % t)
		if t >= 9:
			check(h.has_item("witness_bridge") and rh.has_seen("finger_marks"), "tide IX: bridge and finger marks")
