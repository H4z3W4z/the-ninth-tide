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
	"unequal": "Pressure not equal. The needle's on the wrong tick.",
	"noref": "No reference. The gate has nothing to measure the line against.",
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
## Plates naming a landing the chart room plan doesn't mark: '[ 2' (no closing plate) and landing 3.
const FALSE_SET := ["o2", "o3", "c3"]
const DOOR_ITEMS := ["nora_frame", "nora_spatial_strip", "amended_nora_card", "witness_bridge", "nora_register_card"]
## What she can still move at the live door: BODY and PLACE come pre-seated.
const LOOSE := ["amended_nora_card", "witness_bridge", "nora_register_card"]
const SEATED_FRAMES := {"BODY": "nora_frame", "PLACE": "nora_spatial_strip", "NAME": ""}
const REF_SEATED := "Her trace and her bearing are already in the frames. The folders sent them down."
const REF_P24_EVIDENCE := "Two NAME cards: the one the COPY port pushed out, and the one I amended in the bunk room."

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	test_constants()
	test_p12_unpowered()
	test_p12_no_reference()
	test_p12_exhaustive()
	test_p12_false_landing()
	test_p12_landing_three()
	test_p12_flags_blank()
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
	test_p24_original_card()
	test_door_plate()
	test_hint_tiers()
	test_p24_wrong_items()
	test_p24_inventory()
	test_p24_success()
	test_p24_bridge_forced()
	test_p24_save_load()
	test_p24_preview_live()
	test_p24_reachability()
	test_closeup_exit()
	test_room_lines()
	test_objectives()
	test_debug()
	if _view_ready():
		await view_checks(ROOM)
		await test_view_rects()
		await test_view_hits()
		await test_view_exits()
		await test_view_p12_clicks()
		await test_view_p24_clicks()
		await test_view_presentation()
		await test_view_gauge_and_bell()
		await test_view_water_slab()
		await test_view_name_shutter()
		await test_view_esc_in_cut()
		await test_view_late_wash()
		await test_view_waterline()
	else:
		print("SKIP: R11 view_checks: the R11 view does not yet declare rects for every sim hotspot (view team)")

# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
func key(scene: Node, code: Key) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	scene._unhandled_input(k)

func r11(g: GameSim) -> R11Sim:
	return g.room(ROOM) as R11Sim

func _view_ready() -> bool:
	var m: Dictionary = load("res://game/rooms/R11/R11_view.gd").get_script_constant_map()
	var ids := []
	for h in m.get("HOTSPOTS", []) + m.get("L2_HOTSPOTS", []):
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
	if slots[0] in FALSE_SET or slots[1] in FALSE_SET:
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

## Every UPPER x LOWER placement: each in {"", o1, c1, o3, c3, o2}, non-empty ones distinct.
func placements() -> Array:
	var out := []
	for a in ["", "o1", "c1", "o3", "c3", "o2"]:
		for b in ["", "o1", "c1", "o3", "c3", "o2"]:
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
		grant(g, "R10", "P23")
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
	check(r.hint_tiers() == 4, "four hint tiers")
	for k in R11Sim.OBJECTIVES:
		check(R11Sim.HINTS.has(k) and R11Sim.HINTS[k].size() == 4, "objective %s has a four-step ladder" % k)
	check(R11Sim.HINTS.p12[0] == "The gate on the dry stair needs pressure and a landing.", "P12 card hint 1")
	check(R11Sim.HINTS.p12[3] == "Pressure 2. Bracket-1 plate in UPPER, its closing bracket in LOWER. Pull OPEN.", "P12 card hint 3, as the fourth tier")
	check(R11Sim.HINTS.p24[2] == REF_P24_EVIDENCE, "P24 evidence tier: the two NAME cards")
	check(R11Sim.HINTS.p24[3] == "Amended card to NAME, bridge to WITNESS, COPY empty, OPEN ACCESS.", "P24 card hint 3, as the fourth tier")
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
	check(says(ev) == "Live now. The black needle follows the wheel, a tick a turn. Four ticks. No numbers.", "powered gauge line")
	check(not "2" in says(ev) and not "REFERENCE" in says(ev), "the powered gauge gives no number")
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
	check(placements().size() == 31 and cases == 6 * 31 - 1, "all %d other cases covered (%d)" % [6 * 31 - 1, cases])
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
		if not (pl[0] in FALSE_SET or pl[1] in FALSE_SET):
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
	check(gl.get("rect", []) == [366, 334, 220, 170] and gl.get("target", "") == "bell_sound", "glance at the bell (%s)" % [gl])
	check(r.landing == 2 and r.local_view == "room", "she is on the lower landing")
	check(r.has_seen("gate_opened") and r.has_seen("bell"), "gate_opened and bell noted")
	check(g.exit_open(ROOM, "R07") and g.exit_open(ROOM, "R09") and not g.exit_open(ROOM, "R12"), "R07 and R09 open; R12 shut")
	check("n_glass" in r.state.notices and "n_bell" in r.state.notices, "the commit marks its notices")
	var first := say_ev(ev, "PRESSURE EQUAL. LANDING 1 CORRESPONDS.")
	check(first.get("story", false) and is_equal_approx(float(first.get("delay", 0)), 0.2), "the flags line opens the chain")
	var bell := say_ev(ev, "There. It hangs stopped, halfway through a swing. It has no clapper.")
	check(bell.get("story", false) and is_equal_approx(float(bell.get("delay", 0)), 11.6), "the clapper line closes it, after the cut")
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
	check(r.local_view == "c_gate" and r.rack_plates() == ["o1", "c1", "o3", "c3", "o2"], "all five on the rack")
	var ev := g.dispatch("slot_upper")
	check(says(ev) == "An empty slot.", "empty slot")
	ev = g.dispatch("plate_o1")
	check(r.held_plate == "o1" and has_ev(ev, "sfx", "r11_plate_pick") and r.rack_plates() == ["c1", "o3", "c3", "o2"], "pick o1")
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
	check(r.local_view == "room" and r.held_plate == "" and r.rack_plates().size() == 5, "Back drops the hand")

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
	check(r.state.frames == SEATED_FRAMES, "BODY and PLACE pre-seated (%s)" % [r.state.frames])
	check(not g.has_item("nora_frame") and not g.has_item("nora_spatial_strip"), "taken from her hand")
	check(r.seated("BODY") and r.seated("PLACE") and not r.seated("NAME"), "seated()")
	# Every NAME choice x every place for the bridge: only the amended card with the bridge in
	# WITNESS opens; the original card and anything in COPY keep their own refusals.
	var tried := 0
	for name in ["", "amended_nora_card", "nora_register_card"]:
		for bridge in ["", "witness", "copy"]:
			if name == "amended_nora_card" and bridge == "witness":
				continue
			clear_door(g)
			check(r.state.frames == SEATED_FRAMES, "clearing leaves the seated frames")
			if name != "":
				check(says(use(g, name, "frame_name")) == "In the NAME frame.", "mount %s" % name)
			if bridge == "witness":
				use(g, "witness_bridge", "socket_witness")
			elif bridge == "copy":
				use(g, "witness_bridge", "port_copy")
			var ev := g.dispatch("lever_access")
			tried += 1
			var want := ""
			if bridge == "copy":
				want = "WOULD FINALIZE SUBJECT"
			elif name == "nora_register_card":
				want = "RECORD CLOSED. ACCESS REFUSED."
			elif name == "":
				want = "RECORD INCOMPLETE: NAME"
			else:
				want = "NO WITNESS. RECORD WILL CLOSE."
			check(r.door_note == want, "%s/%s: %s (got %s)" % [name, bridge, want, r.door_note])
			check(not g.flag("P24") and has_ev(ev, "sfx", "r11_access_lever"), "%s/%s: no P24" % [name, bridge])
			check(inv_consistent(g, DOOR_ITEMS), "%s/%s: inventory consistent" % [name, bridge])
			check(r.frame_results.BODY == "ACCEPTED" and r.frame_results.PLACE == "ACCEPTED", "%s/%s: the seated frames accepted" % [name, bridge])
			var res := "EMPTY" if name == "" else ("RECORD CLOSED" if name == "nora_register_card" else "ACCEPTED")
			check(r.frame_results.NAME == res, "%s/%s: NAME result %s" % [name, bridge, res])
	check(tried == 8, "every other arrangement tried (%d)" % tried)
	clear_door(g)
	use(g, "amended_nora_card", "frame_name")
	use(g, "witness_bridge", "socket_witness")
	g.dispatch("lever_access")
	check(g.flag("P24"), "the amended card, the bridge in WITNESS and COPY bare: P24")

## The amended card in NAME and the bridge in WITNESS, but for `except`.
func set_correct(g: GameSim, except := "") -> void:
	if except != "amended_nora_card":
		use(g, "amended_nora_card", "frame_name")
	if except != "witness_bridge":
		use(g, "witness_bridge", "socket_witness")

func test_p24_copy_blocks() -> void:
	for it in LOOSE:
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
	var r := r11(g)
	check(g.has_item("nora_register_card") and g.has_item("amended_nora_card"), "both of her NAME cards in hand")
	var ev := use(g, "nora_register_card", "frame_name")
	check(says(ev) == "In the NAME frame." and r.frame_item("NAME") == "nora_register_card", "the door takes the original card")
	use(g, "witness_bridge", "socket_witness")
	check(not r.name_shut(), "no shutter before a pull")
	ev = g.dispatch("lever_access")
	check(r.door_note == "RECORD CLOSED. ACCESS REFUSED.", "the original card: RECORD CLOSED. ACCESS REFUSED. (%s)" % r.door_note)
	check(says(ev) == "RECORD CLOSED. ACCESS REFUSED. A shutter drops over her name.", "closed-record line (%s)" % says(ev))
	check(r.name_shut() and has_ev(ev, "sfx", "r11_shutter_drop") and has_ev(ev, "fx", "name_shutter"), "the shutter drops")
	check(r.frame_results.NAME == "RECORD CLOSED" and r.frame_results.BODY == "ACCEPTED", "the NAME tag says so")
	check(r.has_seen("record_closed"), "record_closed noted")
	check(not g.flag("P24") and inv_consistent(g, DOOR_ITEMS), "nothing consumed")
	check(says(g.dispatch("preview")) == r.door_note, "the preview re-reads the note")
	# The same refusal with the witness out, or with COPY loaded: COPY still speaks first.
	g.dispatch("socket_witness")
	check(r.door_note == "RECORD CLOSED. ACCESS REFUSED." and r.name_shut(), "witness out: still closed")
	use(g, "witness_bridge", "port_copy")
	check(r.door_note == "WOULD FINALIZE SUBJECT" and not r.name_shut(), "COPY loaded: the copy refusal, shutter up")
	g.dispatch("port_copy")
	use(g, "witness_bridge", "socket_witness")
	check(r.name_shut(), "COPY bare again: closed again")
	# Reversible: take the original out, the shutter lifts, the card comes back.
	ev = g.dispatch("frame_name")
	check(says(ev) == "Out." and g.has_item("nora_register_card") and not r.name_shut(), "the card out, the shutter up")
	check(has_ev(ev, "sfx", "r11_shutter_lift") and has_ev(ev, "fx", "name_shutter"), "the shutter winds up")
	check(r.door_note == "RECORD INCOMPLETE: NAME", "the strip reprints for an empty NAME")
	# Swapping in the amended card lifts it too, and gives the original back.
	use(g, "nora_register_card", "frame_name")
	g.dispatch("lever_access")
	check(r.name_shut(), "closed again")
	ev = use(g, "amended_nora_card", "frame_name")
	check(not r.name_shut() and g.has_item("nora_register_card") and r.frame_item("NAME") == "amended_nora_card",
		"the amended card swapped in: the original back in hand, the shutter up")
	check(inv_consistent(g, DOOR_ITEMS), "consistent after the swap")
	ev = g.dispatch("lever_access")
	check(g.flag("P24"), "only the amended card opens the door")
	check(g.has_item("nora_register_card") and g.has_item("amended_nora_card"), "both cards still hers after P24")
	check(not r.name_shut(), "no shutter on the open door")
	# The shutter is presentation of a refusal: it is never saved.
	var h := door_game()
	use(h, "nora_register_card", "frame_name")
	use(h, "witness_bridge", "socket_witness")
	h.dispatch("lever_access")
	var t := roundtrip(h)
	check(not r11(t).name_shut() and r11(t).frame_item("NAME") == "nora_register_card" and inv_consistent(t, DOOR_ITEMS),
		"a load: the card still mounted, the shutter up until the next pull")

## R06's P22 turns her register card into the amended one. The live door's COPY port then
## gives her the card as first printed, once; she keeps it alongside the amended card.
func test_p24_original_card() -> void:
	var g := game_at(8, ROOM)
	var r := r11(g)
	grant(g, "R06", "P22")
	grant(g, "R10", "P23")
	check(g.has_item("amended_nora_card") and not g.has_item("nora_register_card"), "after P22: only the amended card")
	for it in ["nora_frame", "nora_spatial_strip", "witness_bridge"]:
		g.give(it)
	g.dispatch("descend")
	var ev := g.dispatch("lower_door")
	check(g.has_item("nora_register_card") and g.has_item("amended_nora_card"), "the COPY port gives the original card")
	check(R11Sim.COPY_OUT_LINES[0] in says(ev) and has_ev(ev, "sfx", "r11_copy_out") and r.has_seen("copy_card"),
		"said, heard and noted (%s)" % says(ev))
	var seat := say_ev(ev, REF_SEATED)
	var out := say_ev(ev, R11Sim.COPY_OUT_LINES[0])
	check(not seat.is_empty() and float(out.get("delay", 0)) > float(seat.get("delay", 0)), "her trace and bearing first, then the COPY port")
	check(r.state.frames == SEATED_FRAMES and not g.has_item("nora_frame") and not g.has_item("nora_spatial_strip"),
		"the trace and the bearing seated from her hand")
	check(r.state.original_kept, "kept")
	g.dispatch("back")
	ev = g.dispatch("lower_door")
	check(not R11Sim.COPY_OUT_LINES[0] in says(ev), "once only")
	# R06 files the original under the amended card whenever it reconciles; she keeps it, in place.
	var before: Array = g.state.inventory.duplicate()
	var t := roundtrip(g)
	check(t.state.inventory == before, "a load keeps the original card in its place (%s vs %s)" % [t.state.inventory, before])
	check(same_save(t, g), "and round-trips byte-identical")
	# A dead door gives nothing; neither does a door she reaches already holding the original.
	var d := door_game(false)
	check(not r11(d).state.original_kept and not r11(d).has_seen("copy_card"), "a dead door: nothing comes out")
	var k := game_at(8, ROOM)
	k.give("nora_register_card")
	grant(k, "R10", "P23")
	k.set_flag("P22")
	k.give("amended_nora_card")
	k.dispatch("descend")
	ev = k.dispatch("lower_door")
	check(not R11Sim.COPY_OUT_LINES[0] in says(ev) and r11(k).state.original_kept, "held already: nothing comes out")
	check(k.state.inventory.count("nora_register_card") == 1, "one original card")
	# Through to the end: after P24 she keeps both.
	set_correct(g)
	g.dispatch("lever_access")
	check(g.flag("P24") and g.has_item("nora_register_card") and g.has_item("amended_nora_card"), "after P24: both cards")
	check(same_save(roundtrip(g), g), "after P24: round-trips byte-identical")

## The INDEX ACCESS plate carries the port labels and no rules.
func test_door_plate() -> void:
	var g := door_game()
	var line := says(g.dispatch("door_plate"))
	check(line == "INDEX ACCESS. Two ports, labelled: WITNESS. COPY.", "the plate's line (%s)" % line)
	for w in ["person present", "acknowledgement", "admitted", "agree"]:
		check(not w in line, "no rule text: %s" % w)

## Four tiers on the Hint, the evidence tier third, the solution fourth: hint_line(level) says
## exactly that level's tier, whatever the core has saved.
func test_hint_tiers() -> void:
	var g := door_game()
	var r := r11(g)
	check(r.objective() == "p24", "at the live door")
	var got := []
	for i in 5:
		got.append(says(g.dispatch("hint")))
	check(got == GameSim.with_confirmation(R11Sim.HINTS.p24), "five asks: the four tiers in order, the confirmation before the last (%s)" % [got])
	check(says(g.dispatch("hint")) == R11Sim.HINTS.p24[3], "a fifth ask repeats the solution")
	for o in ["explore", "wait_power", "p12", "wait_door", "p24"]:
		var ladder: Array = R11Sim.HINTS[o]
		check(ladder[2] != ladder[3] and ladder[2] != ladder[1], "%s: an evidence tier of its own" % o)
		for i in 4:
			for j in 4:
				if i < j:
					check(GameSim._hint_key(ladder[i]) != GameSim._hint_key(ladder[j]), "%s: tiers %d and %d differ" % [o, i, j])
	for i in 4:
		check(r.hint_line(i) == R11Sim.HINTS.p24[i], "hint_line(%d) is tier %d, the saved level notwithstanding" % [i, i])
		check(r._hint_tier(i) == i, "_hint_tier(%d) passes the level through" % i)
	check(g.state.hint.level == GameSim.HINT_LEVEL_MAX, "the core's saved level is at the top")
	check(r.hint_line(0) == R11Sim.HINTS.p24[0] and r.hint_line(2) == REF_P24_EVIDENCE, "a saved level never lifts a lower tier")
	var p := gate_game()
	grant(p, "R08", "P11")
	grant(p, "R07", "P10")
	var pl := []
	for i in 5:
		pl.append(says(p.dispatch("hint")))
	check(pl == GameSim.with_confirmation(R11Sim.HINTS.p12), "P12: four tiers in order (%s)" % [pl])

func test_p24_wrong_items() -> void:
	var g := door_game()
	var r := r11(g)
	g.give("pencil")
	for target in ["frame_body", "frame_place", "frame_name", "socket_witness", "port_copy"]:
		var ev := use(g, "pencil", target)
		check(says(ev) == "Not a record of her." and g.has_item("pencil"), "pencil on %s refused, kept" % target)
	check(mounted(r) == ["nora_frame", "nora_spatial_strip"], "nothing mounted by a wrong item")
	var ev2 := use(g, "witness_bridge", "frame_name")
	check(says(ev2) == "It's a plug, not a record." and g.has_item("witness_bridge"), "the bridge isn't a record")
	ev2 = use(g, "amended_nora_card", "socket_witness")
	check(says(ev2) == "The socket takes a plug, not a record." and g.has_item("amended_nora_card"), "a record isn't a plug")
	for f in ["BODY", "PLACE"]:
		ev2 = use(g, "amended_nora_card", FRAME_T[f])
		check(says(ev2) == R11Sim.SEATED_FULL[f] and g.has_item("amended_nora_card") and r.state.frames == SEATED_FRAMES,
			"%s is already full: the card stays in hand" % f)
		ev2 = g.dispatch(FRAME_T[f])
		check(says(ev2) == R11Sim.SEATED_STAY[f] and r.state.frames == SEATED_FRAMES, "%s's record stays seated" % f)
	ev2 = use(g, "inspection_lens", "port_copy")
	check(says(ev2) == "Through the lens the COPY port's shutter is worn bright at the edges.", "lens on the door")
	check(says(g.dispatch("frame_name")) == "An empty frame, labelled NAME. Glass front, spring clips.", "empty frame")
	check(says(g.dispatch("socket_witness")) == "A socket under a hollow circle: WITNESS. It takes a plug.", "empty socket")
	check(says(g.dispatch("port_copy")) == "COPY. AUTOMATIC. Its shutter is sprung open.", "empty port")
	check(says(g.dispatch("preview")) == "Blank.", "blank preview")
	check(says(g.dispatch("door_plate")).begins_with("INDEX ACCESS."), "door plate")
func test_p24_inventory() -> void:
	var g := door_game()
	var r := r11(g)
	var items := DOOR_ITEMS
	check(inv_consistent(g, items), "seated: consistent")
	use(g, "nora_register_card", "frame_name")
	check(r.state.frames.NAME == "nora_register_card" and not g.has_item("nora_register_card"), "a NAME card mounts")
	check(inv_consistent(g, items), "mount: consistent")
	var ev := use(g, "amended_nora_card", "frame_name")
	check(r.state.frames.NAME == "amended_nora_card" and g.has_item("nora_register_card") and has_ev(ev, "sfx", "r11_frame_mount"), "a swap gives the old card back")
	check(inv_consistent(g, items), "swap: consistent")
	use(g, "witness_bridge", "port_copy")
	use(g, "nora_register_card", "port_copy")
	check(r.state.copy == "nora_register_card" and g.has_item("witness_bridge"), "COPY swaps too")
	check(inv_consistent(g, items), "copy swap: consistent")
	use(g, "witness_bridge", "socket_witness")
	ev = g.dispatch("socket_witness")
	check(says(ev) == "Out." and g.has_item("witness_bridge") and r.state.witness == "" and has_ev(ev, "sfx", "r11_frame_unmount"), "unmount the bridge")
	g.dispatch("frame_name")
	g.dispatch("port_copy")
	check(mounted(r) == ["nora_frame", "nora_spatial_strip"] and inv_consistent(g, items), "everything loose back in hand")
	use(g, "amended_nora_card", "frame_name")
	g.dispatch("back")
	check(r.local_view == "room" and r.state.frames.NAME == "amended_nora_card" and r.seated("BODY"), "mounts stay on the door after Back")
	check(inv_consistent(roundtrip(g), items), "consistent across a load")
	# She reaches the live door without the trace or the bearing in hand: drawn seated anyway.
	var h := game_at(8, ROOM)
	grant(h, "R06", "P22")
	grant(h, "R10", "P23")
	for it in ["nora_frame", "nora_spatial_strip"]:
		if h.has_item(it):
			h.take(it)
	h.give("witness_bridge")
	h.dispatch("descend")
	ev = h.dispatch("lower_door")
	check(r11(h).state.frames == SEATED_FRAMES and says(ev).begins_with(REF_SEATED), "not held: simply seated (%s)" % says(ev))
	ev = h.dispatch("back")
	ev = h.dispatch("lower_door")
	check(not REF_SEATED in says(ev), "said once, when they settle")
	# An older save with something else in BODY: the seat hands it back.
	var k := door_game()
	var rk := r11(k)
	var raw: Dictionary = JSON.parse_string(JSON.stringify(k.to_dict()))
	raw.rooms.R11.frames = {"BODY": "amended_nora_card", "PLACE": "", "NAME": ""}
	raw.inventory.erase("amended_nora_card")
	var t := GameSim.new()
	check(t.from_dict(raw), "the older save loads")
	t.dispatch("descend")
	t.dispatch("lower_door")
	check(r11(t).state.frames == SEATED_FRAMES and t.has_item("amended_nora_card") and inv_consistent(t, DOOR_ITEMS),
		"the stray card back in hand, the records seated")
	check(rk.state.frames == SEATED_FRAMES, "the source game untouched")
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
	check(r.state.frames == {"BODY": "", "PLACE": "", "NAME": ""}, "the seated records came out with the rest")
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
	use(g, "amended_nora_card", "frame_name")
	use(g, "witness_bridge", "port_copy")
	var t := roundtrip(g)
	check(same_save(t, g), "a save with records mounted round-trips byte-identical")
	check(r11(t).state.frames == r11(g).state.frames and r11(t).state.copy == "witness_bridge", "mounts survive")
	check(r11(t).seated("BODY") and r11(t).seated("PLACE"), "the seated records survive")
	check(same_save(roundtrip(t), t), "and again")
	check(inv_consistent(t, DOOR_ITEMS), "loaded inventory consistent")
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
	check(says(ev) == "Five landing plates. Brackets, and numbers.", "plates (%s)" % says(ev))
	check(R11Sim.OBSERVATIONS.plates == "Five landing plates in a rack: '[ 1', '] 1', '[ 2', '[ 3', '] 3', each bracket printed with the word BOUNDARY.", "plates observation")
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
	var gl := says(s.dispatch("gauge"))
	check(gl == "The line's steady now: the laboratory's on it too. Four ticks, no numbers. The number's somewhere else.", "referenced gauge")
	check(not "2" in gl, "the referenced gauge gives no number")
	for o in ["gauge", "gauge_powered", "gauge_reference"]:
		check(not "2" in R11Sim.OBSERVATIONS[o] and not "brass" in R11Sim.OBSERVATIONS[o].to_lower(), "%s notes no number and no brass needle" % o)
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
	check(says(f.dispatch("lower_door")).begins_with(REF_SEATED), "the live door: her trace and bearing already seated")
	f.dispatch("back")
	check(says(f.dispatch("lower_door")).begins_with("Her trace. Her bearing. The NAME frame, the bridge"), "the live door again")
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

# ---------------------------------------------------------------------------------------------
# the view: rects per landing, hit tests, exits per landing, P12 and P24 as real clicks, cuts,
# holds, loops and the still alternatives
# ---------------------------------------------------------------------------------------------
func view_scene(stage: int) -> Node:
	var scene = new_scene("user://room_test_R11_view.json")
	await process_frame
	scene.room_jump(ROOM, stage)
	await process_frame
	return scene

func rect_ok(name: String, r: Rect2) -> void:
	check(CANVAS.encloses(r), "R11 %s is on the canvas" % name)
	check(r.size.x >= MIN_TARGET and r.size.y >= MIN_TARGET, "R11 %s is at least 64x64" % name)
	check(not r.intersects(HUD_ZONE) and not r.intersects(SUBTITLE_ZONE) and not r.intersects(INVENTORY_ZONE),
		"R11 %s keeps clear of the HUD, inventory and subtitles" % name)

func test_view_rects() -> void:
	var m: Dictionary = load("res://game/rooms/R11/R11_view.gd").get_script_constant_map()
	var l2_ids := []
	for h in m.L2_HOTSPOTS:
		l2_ids.append(h[0])
		rect_ok(h[0], h[1])
	for id in R11Sim.L2_HOTSPOTS:
		check(id in l2_ids, "R11 view has a lower-landing rect for %s" % id)
	for k in m.NAV_RECTS:
		rect_ok(k, m.NAV_RECTS[k])
	var gate_ids := []
	for h in m.GATE_CONTROLS:
		gate_ids.append(h[0])
		rect_ok(h[0], h[1])
	for id in R11Sim.GATE_CONTROLS:
		check(id in gate_ids, "c_gate has a control for %s" % id)
	var door_ids := []
	for h in m.DOOR_CONTROLS:
		door_ids.append(h[0])
		rect_ok(h[0], h[1])
	for id in R11Sim.DOOR_CONTROLS:
		check(id in door_ids, "c_chamber_door has a control for %s" % id)
	# Each landing's live exits and plaque keep off its own hotspots.
	for k in ["R07", "R09", "R12"]:
		for h in m.L2_HOTSPOTS:
			check(not m.EXIT_RECTS[k].intersects(h[1]), "lower landing: exit %s does not overlap %s" % [k, h[0]])
		check(not m.EXIT_RECTS[k].intersects(m.NAV_RECTS.ascend), "lower landing: exit %s clear of the plaque" % k)
	for h in m.L2_HOTSPOTS:
		check(not m.NAV_RECTS.ascend.intersects(h[1]), "ascend plaque clear of %s" % h[0])
	for h in m.HOTSPOTS:
		check(not m.NAV_RECTS.descend.intersects(h[1]), "descend plaque clear of %s" % h[0])
	check(not m.EXIT_RECTS.R03.intersects(m.NAV_RECTS.descend), "gate landing: exit clear of the plaque")
	# Close-up controls never overlap one another (a click means one thing).
	for list in [m.GATE_CONTROLS, m.DOOR_CONTROLS]:
		for i in list.size():
			for j in range(i + 1, list.size()):
				check(not list[i][1].intersects(list[j][1]), "controls %s and %s do not overlap" % [list[i][0], list[j][0]])

func first_of(list: Array, p: Vector2) -> String:
	for h in list:
		if h[1].has_point(p):
			return h[0]
	return ""

func test_view_hits() -> void:
	var scene = await view_scene(5)   # tide IV, ready to OPEN, gate landing
	var v = scene.room_view
	var r := scene.room_sim() as R11Sim
	check(v != null and r != null and r.landing == 1, "R11 view mounts at stage 5 on the gate landing")
	if v == null:
		await free_scene(scene)
		return
	for h in v.HOTSPOTS:
		var c: Vector2 = h[1].get_center()
		check(v.action_at(c) == first_of(v.HOTSPOTS, c), "gate landing: %s hits %s" % [h[0], first_of(v.HOTSPOTS, c)])
		check(v.hover_at(c) == v.action_at(c), "gate landing: hover mirrors %s" % h[0])
		check(v.label_for(h[0]) == h[2] and v.hotspot_rect(h[0]) == h[1], "gate landing: %s labelled and found" % h[0])
	check(v.action_at(v.NAV_RECTS.descend.get_center()) != "descend", "no way down before P12")
	check(v.action_at(v.NAV_RECTS.ascend.get_center()) != "ascend", "no ascend plaque on the gate landing")
	check(v.label_for("descend") == "Lower landing ▾" and v.label_for("ascend") == "◂ Gate landing", "plaque labels")
	# c_gate: every control at its centre.
	r.local_view = "c_gate"
	for h in v.GATE_CONTROLS:
		check(v.action_at(h[1].get_center()) == h[0], "c_gate: %s is clickable" % h[0])
		check(v.control_rect(h[0]) == h[1] and v.label_for(h[0]) == h[2], "c_gate: %s rect and label" % h[0])
	check(v.action_at(v.HOTSPOTS[0][1].get_center()) != "gauge", "c_gate: room hotspots are not live")
	check(v.back_visible() and v.esc_action() == "back" and not v.exits_active(), "c_gate: Back on, exits off")
	r.local_view = "room"
	check(v.exits_active() and not v.back_visible() and v.esc_action() == "menu", "room: exits on, Esc is the menu")
	# After P12: the plaque goes down; below, the lower landing's list and the way up.
	scene.room_jump(ROOM, 6)
	await process_frame
	v = scene.room_view
	r = scene.room_sim() as R11Sim
	check(r.landing == 2, "stage 6 stands on the lower landing")
	for h in v.L2_HOTSPOTS:
		var c: Vector2 = h[1].get_center()
		check(v.action_at(c) == first_of(v.L2_HOTSPOTS, c), "lower landing: %s hits %s" % [h[0], first_of(v.L2_HOTSPOTS, c)])
		check(v.label_for(h[0]) == h[2] and v.hotspot_rect(h[0]) == h[1], "lower landing: %s labelled and found" % h[0])
	check(v.action_at(v.NAV_RECTS.ascend.get_center()) == "ascend", "lower landing: the way up is clickable")
	check(v.action_at(v.NAV_RECTS.descend.get_center()) == "", "lower landing: no way further down")
	var dr: Array = v.dev_rects()
	check(v.NAV_RECTS.ascend in dr and v.L2_HOTSPOTS[0][1] in dr, "dev rects show the landing in view")
	scene.dispatch("ascend")
	check(r.landing == 1 and v.action_at(v.NAV_RECTS.descend.get_center()) == "descend", "after P12 the gate landing has the way down")
	r.local_view = "c_chamber_door"
	for h in v.DOOR_CONTROLS:
		check(v.action_at(h[1].get_center()) == h[0], "c_chamber_door: %s is clickable" % h[0])
	r.local_view = "room"
	await free_scene(scene)

func test_view_exits() -> void:
	var scene = await view_scene(5)
	var v = scene.room_view
	check(v.exit_rects().size() == 4, "exit_rects keeps all four")
	check(v.live_exit_rects().keys() == ["R03"], "gate landing: only the chart room (%s)" % [v.live_exit_rects().keys()])
	check(v.exit_arrow("R07") == "left" and v.exit_arrow("R09") == "right" and v.exit_arrow("R12") == "down"
		and v.exit_arrow("R03") == "", "exit arrows")
	scene.room_jump(ROOM, 6)
	await process_frame
	v = scene.room_view
	var live: Dictionary = v.live_exit_rects()
	check(live.has("R07") and live.has("R09") and not live.has("R12") and not live.has("R03"),
		"lower landing before P24: laboratory and gallery, no lower door tab (%s)" % [live.keys()])
	check(scene.action_at(live.R07.get_center()) == "go:R07" and scene.action_at(live.R09.get_center()) == "go:R09",
		"lower landing: both exits click")
	scene.room_jump(ROOM, 9)
	await process_frame
	v = scene.room_view
	live = v.live_exit_rects()
	check(live.has("R12") and scene.action_at(live.R12.get_center()) == "go:R12", "after P24 the lower door's tab is live")
	await free_scene(scene)

## A click on `action` as a player would make it: wait out holds, cuts and chains (clicking
## through them) until action_at says it and the click lands.
func click_on(scene, action: String) -> bool:
	var v = scene.room_view
	var p: Vector2 = v.control_rect(action).get_center()
	for i in 300:
		var a: String = scene.action_at(p)
		if a == action:
			var id0: int = scene.click_id
			scene.click(p)
			if scene.click_id != id0:
				scene._process(0.05)
				return true
		elif a == "":
			scene.click(p)
		scene._process(0.1)
	check(false, "'%s' never landed (view %s)" % [action, scene.room_sim().local_view])
	return false

func test_view_p12_clicks() -> void:
	var scene = await view_scene(4)   # P10 + P11, pressure 2, '[ 2' in UPPER: the false landing
	var v = scene.room_view
	var r := scene.room_sim() as R11Sim
	click_on(scene, "gate")
	check(r.local_view == "c_gate", "the gate opens its close-up")
	click_on(scene, "lever_open")
	check(not scene.sim.flag("P12") and v.port_t >= 0.0, "'[ 2' set: refused, the port opens on the false landing")
	check(R11Sim.flag_text(r.flags_shown()).contains("NO CORRESPONDING LANDING"), "the flags say so")
	for i in 32:
		scene._process(0.1)
	check(v.port_t < 0.0, "the port closes again after 3 s")
	click_on(scene, "plate_o1")
	check(r.held_plate == "o1", "the '[ 1' plate comes off its hook")
	click_on(scene, "slot_upper")
	check(r.state.slots == ["o1", "c1"] and "o2" in r.rack_plates(), "'[ 1' in UPPER, '[ 2' back on the rack")
	click_on(scene, "lever_open")
	check(scene.sim.flag("P12"), "P12 by clicks on c_gate")
	check(v.cut_playing() and v.cut == "p12", "the P12 cut plays")
	check(v.action_at(Vector2(700, 500)) == "" and not v.exits_active() and v.esc_action() == "menu",
		"nothing answers during the cut but Esc, which is the menu")
	var t: Dictionary = v.audio_targets()
	check(t.r11_air == 0.0 and t.r11_glass > 0.0, "only the glass sounds in the cut")
	for i in 20:
		scene._process(0.1)
	check(v.cut_playing() and v.cut_t >= 1.8, "the cut is past the gate at 2 s")
	check(v.consume_click(Vector2(700, 500)) and not v.cut_playing(), "a click skips the rest of the cut")
	check(r.landing == 2 and r.local_view == "room", "the lower landing after the cut")
	check(not v.live_exit_rects().has("R12"), "no lower door tab yet")
	await free_scene(scene)
	# The cut runs out on its own.
	scene = await view_scene(5)
	v = scene.room_view
	click_on(scene, "gate")
	click_on(scene, "lever_open")
	check(v.cut_playing(), "stage 5: the cut plays")
	for i in 40:
		scene._process(0.1)
	check(v.cut_playing() and v.cut_t < v.CUT_GRILLE and v.grille_rise() > 0.0 and v.grille_rise() < 1.0,
		"at 4 s the grille is still going up into the lintel: the bolts and grille come before the hand")
	for i in 60:
		scene._process(0.1)
	check(not v.cut_playing() and v.close.modulate.a == 1.0, "the cut ends by itself at 9.6 s")
	await free_scene(scene)

func test_view_p24_clicks() -> void:
	var scene = await view_scene(8)   # tide VIII, the door ready
	var v = scene.room_view
	var r := scene.room_sim() as R11Sim
	click_on(scene, "lower_door")
	check(r.local_view == "c_chamber_door", "the lower door opens its close-up")
	# BODY stays seated; the NAME card out and in again, by clicks.
	click_on(scene, "frame_body")
	check(r.frame_item("BODY") == "nora_frame" and not scene.sim.has_item("nora_frame"), "the seated trace stays")
	click_on(scene, "frame_name")
	check(r.frame_item("NAME") == "" and scene.sim.has_item("amended_nora_card"), "the NAME card comes out")
	scene.dispatch("item:amended_nora_card")
	click_on(scene, "frame_name")
	check(r.frame_item("NAME") == "amended_nora_card", "and goes back into NAME")
	click_on(scene, "lever_access")
	check(scene.sim.flag("P24"), "P24 by clicks on c_chamber_door")
	check(v.cut == "door" and v.finger_k == 0.0, "the door cut plays; the finger marks wait for the glance")
	for i in 30:
		scene._process(0.1)
	check(v.cut == "door" and v.close.modulate.a == 1.0, "the door close-up holds to 4.4 s")
	for i in 20:
		scene._process(0.1)
	check(v.close.modulate.a < 1.0, "then dissolves")
	for i in 20:
		scene._process(0.1)
	check(not v.cut_playing() and r.landing == 2, "the lower landing, the door open")
	check(v.live_exit_rects().has("R12"), "the lower door's tab after P24")
	check(not v.start_glance("lower_door", Rect2(320, 450, 280, 430)) == false, "the view shows the finger marks itself")
	check(v.start_glance("bell_sound", Rect2(366, 334, 220, 170)) == false, "the bell lets the core bracket it")
	await free_scene(scene)

func test_view_presentation() -> void:
	var m: Dictionary = load("res://game/rooms/R11/R11_view.gd").get_script_constant_map()
	for b in 8:
		check(m.MODULATE_L1[b] >= 0.78 and m.MODULATE_L2[b] >= 0.78, "band %d: never darker than 0.78" % b)
	var scene = await view_scene(3)   # powered, no reference
	var v = scene.room_view
	var r := scene.room_sim() as R11Sim
	var t: Dictionary = v.audio_targets()
	check(t.r11_air == 0.55 and t.r11_line_pulse == 0.35 and t.r11_glass == 0.0, "gate landing, powered: the line pulses")
	check(v.status_text() == "", "no reference: the window is blank")
	scene.room_jump(ROOM, 2)
	check(v.status_text() == "NO PRESSURE", "unpowered: NO PRESSURE")
	scene.room_jump(ROOM, 5)
	v = scene.room_view
	check(v.status_text() == "", "referenced: still no number on the face")
	# Holds: a notice holds the room; a click skips it.
	v.play_fx("notice", {"notice": "n_tide1"})
	check(v.holding() and v.action_at(v.HOTSPOTS[0][1].get_center()) == "" and not v.exits_active(), "a notice holds the room")
	check(v.consume_click(Vector2(10, 500)) and not v.holding(), "a click skips the hold")
	v.play_fx("notice", {"notice": "n_tide1"})
	for i in 20:
		scene._process(0.1)
	check(not v.holding(), "the hold ends by itself after 1.5 s")
	v.play_fx("notice", {"notice": "n_unknown"})
	check(not v.holding(), "an unknown notice holds nothing")
	# Still alternatives.
	scene.sim.settings.motion = false
	check(v.glint_x() == 700.0, "still: the water's glint is fixed")
	v.play_fx("false_landing", {})
	check(v.port_t == 0.0, "the port opens on a false landing")
	v.reset_presentation()
	check(v.port_t < 0.0 and not v.cut_playing() and not v.holding(), "reset clears port, cut and hold")
	scene.sim.settings.motion = true
	# Bands: bells and pressure.
	scene.room_jump(ROOM, 6)   # tide V
	v = scene.room_view
	r = scene.room_sim() as R11Sim
	scene.tide_jump(5, ROOM)
	v = scene.room_view
	r = scene.room_sim() as R11Sim
	var band: int = scene.sim.weather_band()
	t = v.audio_targets()
	if band >= 3 and band <= 5:
		check(t.r11_bell_above == (0.55 if r.landing == 2 else 0.25) and t.r11_bell_below == 0.0, "bands 3-5: the bell above")
	scene.tide_jump(9, ROOM)
	v = scene.room_view
	r = scene.room_sim() as R11Sim
	r.landing = 2
	t = v.audio_targets()
	check(t.r11_bell_below == 0.6 and t.r11_bell_above == 0.0 and t.r11_pressure == 0.4, "band 7 below: the bell below, pressure")
	check(is_equal_approx(v.shade_value(), 0.78), "band 7 lower landing at 0.78")
	await free_scene(scene)

# ---------------------------------------------------------------------------------------------
# w3 fixes
# ---------------------------------------------------------------------------------------------
## Landing 3 has no mark on the chart room plan: '[ 3' over '] 3' is refused like '[ 2', and
## with the pressure wrong too the composed line says there's no landing for those plates.
func test_p12_landing_three() -> void:
	var g := gate_game()
	var r := r11(g)
	g.dispatch("gate")
	check(R11Sim.PLATES == ["o1", "c1", "o3", "c3", "o2"], "five plates in rack order")
	check(R11Sim.PLATE_TEXT.o3 == "[ 3" and R11Sim.PLATE_TEXT.c3 == "] 3", "the landing-3 plates")
	check("plate_o3" in R11Sim.GATE_CONTROLS and "plate_c3" in R11Sim.GATE_CONTROLS, "both are gate controls")
	wheel_to(g, 4)
	lay_plates(g, ["o3", "c3"])
	check(r.state.slots == ["o3", "c3"], "'[ 3' over '] 3' set")
	var ev := g.dispatch("lever_open")
	check(r.gate_note == {"p": "unequal", "l": "none"}, "landing 3: no corresponding landing (%s)" % [r.gate_note])
	check(says(ev).begins_with("The pressure's not equal, and there's no landing for those plates."), "BOTH_L none (%s)" % says(ev))
	wheel_to(g, 2)
	ev = g.dispatch("lever_open")
	check(says(ev).begins_with("NO CORRESPONDING LANDING.") and not g.flag("P12"), "landing 3 at pressure 2 refused")
	check(has_ev(ev, "fx", "false_landing"), "landing 3 shows the false landing too")
	for pl in [["o1", "c3"], ["o3", "c1"], ["c3", "o3"]]:
		lay_plates(g, pl)
		g.dispatch("lever_open")
		check(r.gate_note.l == "none" and not g.flag("P12"), "%s: no corresponding landing" % [pl])
	# The new plates load from a save; the old solution still stands alone.
	lay_plates(g, ["o3", "c3"])
	var t := roundtrip(g)
	check(r11(t).state.slots == ["o3", "c3"], "o3/c3 survive a save")
	var bad := GameSim.new()
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	d.rooms[ROOM].slots = ["o3", "o3"]
	bad.from_dict(d)
	check(r11(bad).state.slots == ["", ""], "a doubled o3 is rejected on load")
	wheel_to(g, 2)
	lay_plates(g, ["o1", "c1"])
	g.dispatch("lever_open")
	check(g.flag("P12"), "pressure 2 with '[ 1' over '] 1' still opens")

## The flag windows show nothing until OPEN is pulled, only that pull's verdict, and go blank
## when the arrangement changes. The success line appears only on a correct OPEN.
func test_p12_flags_blank() -> void:
	var g := gate_game()
	var r := r11(g)
	g.dispatch("gate")
	check(r.flags_shown() == {"p": "", "l": ""} and R11Sim.flag_text(r.flags_shown()) == "", "blank before any pull")
	wheel_to(g, 2)
	lay_plates(g, ["o1", "c1"])
	check(R11Sim.flag_text(r.flags_shown()) == "", "the right arrangement, unpulled: still blank")
	check(says(g.dispatch("flags")) == "Blank until I pull.", "the flags say nothing")
	g.dispatch("wheel_up")
	g.dispatch("lever_open")
	check(R11Sim.flag_text(r.flags_shown()) == "PRESSURE NOT EQUAL. LANDING 1 CORRESPONDS.", "a refused pull shows its verdict")
	g.dispatch("wheel_down")
	check(R11Sim.flag_text(r.flags_shown()) == "", "turning the wheel blanks the flags")
	g.dispatch("lever_open")
	check(g.flag("P12"), "the correct pull opens")
	check(R11Sim.flag_text(r.flags_shown()) == "PRESSURE EQUAL. LANDING 1 CORRESPONDS.", "the success shows after the correct OPEN")
	# A plate moved after a refusal blanks them too.
	var h := gate_game()
	var rh := r11(h)
	h.dispatch("gate")
	lay_plates(h, ["o2", "c1"])
	h.dispatch("lever_open")
	check(rh.flags_shown().l == "none", "refused: NO CORRESPONDING LANDING")
	h.dispatch("slot_upper")
	check(rh.flags_shown() == {"p": "", "l": ""}, "lifting a plate out blanks the flags")
	# Nothing else ever printed the success before a correct OPEN.
	for pr in range(0, 6):
		for pl in placements():
			if pr == 2 and pl == ["o1", "c1"]:
				continue
			wheel_to(h, pr)
			lay_plates(h, pl)
			h.dispatch("lever_open")
			check(R11Sim.flag_text(rh.flags_shown()) != "PRESSURE EQUAL. LANDING 1 CORRESPONDS.", "%d %s: no success flags" % [pr, pl])

## The preview strip is live: once printed, it reprints whenever a mount changes, so it never
## says a frame is empty after that frame has been filled.
func test_p24_preview_live() -> void:
	var g := door_game()
	var r := r11(g)
	use(g, "witness_bridge", "socket_witness")
	g.dispatch("lever_access")
	check(r.door_preview() == "RECORD INCOMPLETE: NAME" and r.frame_results.NAME == "EMPTY", "NAME empty: incomplete")
	use(g, "nora_register_card", "frame_name")
	check(r.door_preview() == "RECORD CLOSED. ACCESS REFUSED.", "the original in NAME: reprinted (%s)" % r.door_preview())
	check(r.frame_results.NAME == "RECORD CLOSED" and r.frame_results.BODY == "ACCEPTED", "the frame tags follow")
	check(says(g.dispatch("preview")) == "RECORD CLOSED. ACCESS REFUSED.", "PREVIEW reads the live strip")
	g.dispatch("frame_name")
	check(r.door_preview() == "RECORD INCOMPLETE: NAME", "back to NAME empty (%s)" % r.door_preview())
	use(g, "amended_nora_card", "frame_name")
	check(r.door_preview() == "" and says(g.dispatch("preview")) == "Blank.", "a record that would open: the strip goes blank")
	g.dispatch("socket_witness")
	check(r.door_preview() == "NO WITNESS. RECORD WILL CLOSE.", "the bridge out: reprinted (%s)" % r.door_preview())
	use(g, "witness_bridge", "port_copy")
	check(r.door_preview() == "WOULD FINALIZE SUBJECT", "the bridge in COPY: reprinted (%s)" % r.door_preview())
	g.dispatch("port_copy")
	use(g, "witness_bridge", "socket_witness")
	g.dispatch("lever_access")
	check(g.flag("P24") and r.door_preview() == "RECORD VALID. RECORD OPEN.", "the lever still opens it")
	# Before any pull the strip stays blank while mounting.
	var h := door_game()
	use(h, "amended_nora_card", "frame_name")
	check(r11(h).door_preview() == "", "unpulled: blank")
## The gauge faces carry no number and no reference; the plates' new hooks; the bell's ring.
func test_view_gauge_and_bell() -> void:
	var scene = await view_scene(5)
	var v = scene.room_view
	var r := scene.room_sim() as R11Sim
	for id in ["pane_slab", "pane_files", "bell_frozen", "stairwell_fill", "c_gauge_face", "L1_gauge_face"]:
		check(v.textures.has(id), "texture %s loads" % id)
	check(v.status_text() == "" and r.referenced(), "referenced: no REFERENCE 2 on the face")
	check(not v.has_method("ref_deg"), "no reference needle")
	check(v.GATE_HOOKS.o1 == Vector2(659, 716) and v.GATE_HOOKS.c1 == Vector2(859, 716) and v.GATE_HOOKS.o2 == Vector2(1059, 716),
		"the first three hooks have not moved")
	check(v.GATE_HOOKS.has("o3") and v.GATE_HOOKS.has("c3") and v.L1_HOOKS.has("o3") and v.L1_HOOKS.has("c3"), "hooks for landing 3")
	r.local_view = "c_gate"
	for pid in ["o3", "c3"]:
		check(v.action_at(v.control_rect("plate_" + pid).get_center()) == "plate_" + pid, "plate_%s clickable" % pid)
	r.local_view = "room"
	# The bell: one ring off its first sounding (the reveal), expanding and fading (Motion on) or
	# still and fading (Motion off), 1.5 s; the loop's later tolls draw none.
	scene.room_jump(ROOM, 6)
	await process_frame
	v = scene.room_view
	r = scene.room_sim() as R11Sim
	check(r.landing == 2 and r.bell_dir() == "above" and not v.bell_mirrored(), "tide V: the bell tips toward the office")
	v.ring_t = -1.0
	check(v.ring_now().is_empty(), "no ring before it sounds")
	v.on_sfx("r11_bell_up")
	var r0: Array = v.ring_now()
	scene._process(0.75)
	var r1: Array = v.ring_now()
	check(not r0.is_empty() and not r1.is_empty() and r1[0] > r0[0] and r1[1] < r0[1], "the ring expands and fades (%s -> %s)" % [r0, r1])
	scene._process(0.8)
	check(v.ring_now().is_empty(), "gone after 1.5 s")
	scene.sim.settings.motion = false
	v.on_sfx("r11_bell_up")
	scene._process(0.5)
	var s0: Array = v.ring_now()
	scene._process(0.5)
	var s1: Array = v.ring_now()
	check(not s0.is_empty() and not s1.is_empty() and s0[0] == v.RING_STILL_R and s1[0] == s0[0] and s1[1] < s0[1],
		"Motion off: one still ring, fading (%s -> %s)" % [s0, s1])
	scene._process(0.6)
	check(v.ring_now().is_empty(), "Motion off: gone after 1.5 s")
	# The toll in the bell loop leaves the bell bare, Motion on or off: no outline lingers round
	# it. (Headless, the loops' playback never advances: stop them so the view's own 16 s clock
	# keeps the toll.)
	for id in ["r11_bell_above", "r11_bell_below"]:
		if v.mixer.players.has(id):
			v.mixer.players[id].stop()
	for m in [false, true]:
		scene.sim.settings.motion = m
		v.ring_t = -1.0
		var rang := false
		for i in 200:
			scene._process(0.1)
			rang = rang or not v.ring_now().is_empty()
		check(not rang, "the loop's tolls draw no ring round the bell (Motion %s)" % m)
	scene.sim.settings.motion = true
	scene.tide_jump(9, ROOM)
	v = scene.room_view
	r = scene.room_sim() as R11Sim
	r.landing = 2
	check(v.bell_mirrored() and v.bell_centre().x > v.BELL_PIVOT.x, "band 7: the same bell, tipped toward the lower door")
	await free_scene(scene)

# ---------------------------------------------------------------------------------------------
# p1 fixes
# ---------------------------------------------------------------------------------------------
## P12's visible wrongness: the water standing in the gateway as a slab, from the cut's line on.
func test_view_water_slab() -> void:
	check(FileAccess.file_exists("res://assets/stages/R11/p12_water_slab.png"), "the slab overlay is on disk")
	var scene = await view_scene(5)   # ready to OPEN: no slab yet
	var v = scene.room_view
	var r := scene.room_sim() as R11Sim
	check(v.textures.has("p12_water_slab"), "the slab overlay loads")
	check(not r.water_slab(), "before P12: no slab")
	var ev: Array = scene.sim.dispatch("gate")
	ev = scene.sim.dispatch("lever_open")
	check(scene.sim.flag("P12") and r.water_slab(), "after P12: the slab stands")
	var line := say_ev(ev, "The water's standing up in the gateway. Thick as glass. My hand goes through it, and comes out dry.")
	check(not line.is_empty() and is_equal_approx(float(line.get("delay", 0)), v.SLAB_AT),
		"the slab arrives with its line (%s vs %s)" % [line.get("delay", -1), v.SLAB_AT])
	var tex: Texture2D = v.textures.get("p12_water_slab")
	check(tex != null and tex.get_size() == Vector2(1448, 1086), "the overlay is a full plate")
	if tex:
		var img := tex.get_image()
		var c := img.get_pixelv(v.WATER_SLAB.get_center())
		check(c.a > 0.6, "the slab is solid where it stands (alpha %.2f)" % c.a)
		check(img.get_pixel(int(v.WATER_SLAB.get_center().x), 200).a == 0.0, "its top stands clear of the lintel")
		check(img.get_pixel(40, 600).a == 0.0, "nothing outside the gateway")
	scene.sim.settings.motion = false
	check(v.shimmer_k() == -1.0, "Motion off: no shimmer, the slab is static")
	scene.sim.settings.motion = true
	check(v.shimmer_k() >= 0.0 and v.shimmer_k() < 1.0, "Motion on: a slow shimmer")
	# On the gate landing after P12, at every later band.
	for t in [5, 7, 9]:
		scene.tide_jump(t, ROOM)
		await process_frame
		r = scene.room_sim() as R11Sim
		check(r.water_slab(), "tide %d: the slab still stands" % t)
	await free_scene(scene)

## The NAME shutter drops over the refused original and winds up again (Motion off: at once).
func test_view_name_shutter() -> void:
	var scene = await view_scene(8)
	var v = scene.room_view
	var r := scene.room_sim() as R11Sim
	scene.sim.dispatch("descend")
	scene.sim.dispatch("lower_door")
	check(scene.sim.has_item("nora_register_card"), "the original card is in hand at the live door")
	scene.sim.dispatch("frame_name")
	scene.sim.dispatch("item:nora_register_card")
	scene.sim.dispatch("frame_name")
	check(r.frame_item("NAME") == "nora_register_card", "the original in NAME")
	scene.sim.dispatch("lever_access")
	check(r.name_shut() and v.shutter_k == 0.0, "refused: the shutter starts down")
	scene._process(0.1)
	check(v.shutter_k > 0.0 and v.shutter_k < 1.0, "dropping (%.2f)" % v.shutter_k)
	scene._process(0.3)
	check(v.shutter_k == 1.0, "down")
	check(v.textures.has("c_name_shutter"), "the shutter sprite loads")
	check(v.action_at(v.control_rect("frame_name").get_center()) == "frame_name", "the NAME frame stays clickable under it")
	scene.sim.dispatch("frame_name")
	scene._process(0.1)
	check(v.shutter_k < 1.0 and v.shutter_k > 0.0, "winding up")
	scene._process(0.6)
	check(v.shutter_k == 0.0, "up")
	scene.sim.settings.motion = false
	scene.sim.dispatch("item:nora_register_card")
	scene.sim.dispatch("frame_name")
	scene.sim.dispatch("lever_access")
	scene._process(0.016)
	check(v.shutter_k == 1.0, "Motion off: down at once")
	v.reset_presentation()
	check(v.shutter_k == 1.0, "reset keeps the state's shutter")
	scene.sim.settings.motion = true
	await free_scene(scene)

## Esc during the P12 cut opens the menu (never Back, never nothing); the cut stands still
## under the menu and Resume carries on from exactly where it stopped. The same for a hold.
func test_view_esc_in_cut() -> void:
	var scene = await view_scene(5)
	var v = scene.room_view
	var r := scene.room_sim() as R11Sim
	click_on(scene, "gate")
	click_on(scene, "lever_open")
	check(v.cut_playing() and v.cut == "p12", "esc: the P12 cut plays")
	for i in 30:
		scene._process(0.1)
	var t0: float = v.cut_t
	check(t0 > v.CUT_GATE and t0 < v.CUT_END, "esc: mid-cut (%.2f s)" % t0)
	check(v.esc_action() == "menu", "esc: Esc in the cut is the menu")
	key(scene, KEY_ESCAPE)
	check(scene.sim.view == "menu", "esc: Esc opens the menu during the cut")
	check(v.cut_playing() and is_equal_approx(v.cut_t, t0), "esc: Esc does not skip the cut")
	for i in 120:
		scene._process(0.1)
	check(v.cut_playing() and is_equal_approx(v.cut_t, t0), "esc: the cut stands still under the menu (%.2f vs %.2f)" % [v.cut_t, t0])
	scene.dispatch("resume")
	check(scene.sim.view == "room" and v.cut_playing() and is_equal_approx(v.cut_t, t0), "esc: Resume comes back to the same moment")
	scene._process(0.5)
	check(v.cut_playing() and is_equal_approx(v.cut_t, t0 + 0.5), "esc: and the cut carries on from there (%.2f)" % v.cut_t)
	for i in 100:
		scene._process(0.1)
	check(not v.cut_playing() and r.landing == 2, "esc: the cut still ends on its own, on the lower landing")
	# A hold: the same.
	v.hold_id = "n_bell"
	v.hold_t = 0.5
	check(v.holding() and v.esc_action() == "menu", "esc: Esc in a hold is the menu")
	key(scene, KEY_ESCAPE)
	check(scene.sim.view == "menu", "esc: Esc opens the menu during a hold")
	for i in 30:
		scene._process(0.1)
	check(v.holding() and is_equal_approx(v.hold_t, 0.5), "esc: the hold waits under the menu")
	scene.dispatch("resume")
	for i in 20:
		scene._process(0.1)
	check(not v.holding(), "esc: and finishes after Resume")
	await free_scene(scene)

## Band 6+: the late wash, drawn by state alone. Lower landing (b6_wash): the wall under the
## glass shelf down to the dado goes storm navy; gate landing (b6_wash_L1): the wall above the
## horizontal pane's line. Off the band each overlay is clear, and on it every object keeps
## its plate's own full-ink contour.
func test_view_late_wash() -> void:
	var scene = await view_scene(5)
	var v = scene.room_view
	var navy := Color("22384a")
	# [overlay, its plate, a wall point in the wash, a point off the band, an ink contour, an object face]
	var cases := [
		["b6_wash", "L2_base", Vector2i(450, 450), Vector2i(450, 200), Vector2i(1108, 500), Vector2i(700, 550)],
		["b6_wash_L1", "L1_base", Vector2i(1300, 140), Vector2i(1300, 700), Vector2i(1171, 300), Vector2i(300, 300)],
	]
	for c in cases:
		check(FileAccess.file_exists("res://assets/stages/R11/%s.png" % c[0]), "wash: %s is on disk" % c[0])
		check(v.textures.has(c[0]), "wash: %s loads" % c[0])
		var tex: Texture2D = v.textures.get(c[0])
		var base: Texture2D = v.textures.get(c[1])
		if tex == null or base == null:
			continue
		var img := tex.get_image()
		var bimg := base.get_image()
		check(tex.get_size() == Vector2(1448, 1086), "wash: %s is a full plate" % c[0])
		var w := img.get_pixelv(c[2])
		var b := bimg.get_pixelv(c[2])
		check(w.a == 1.0 and w.get_luminance() < b.get_luminance() * 0.6,
			"wash: %s darkens the wall (%.2f vs %.2f)" % [c[0], w.get_luminance(), b.get_luminance()])
		check(w.b > w.r + 0.05 and absf(w.get_luminance() - navy.get_luminance()) < 0.12, "wash: %s toward storm navy" % c[0])
		check(img.get_pixelv(c[3]).a == 0.0, "wash: %s is clear off its band" % c[0])
		var ink_w := img.get_pixelv(c[4])
		var ink_b := bimg.get_pixelv(c[4])
		check(ink_b.get_luminance() < 0.3 and absf(ink_w.get_luminance() - ink_b.get_luminance()) < 0.02,
			"wash: %s keeps an object's contour at full ink (%.3f vs %.3f)" % [c[0], ink_w.get_luminance(), ink_b.get_luminance()])
		check(img.get_pixelv(c[5]).is_equal_approx(bimg.get_pixelv(c[5])) or
			absf(img.get_pixelv(c[5]).get_luminance() - bimg.get_pixelv(c[5]).get_luminance()) < 0.02,
			"wash: %s leaves the object's face as painted" % c[0])
	for t in [5, 6, 7]:
		scene.tide_jump(t + 2, ROOM)   # tide t+2 starts at band t
		await process_frame
		v = scene.room_view
		check(scene.sim.weather_band() == t, "wash: tide %d is band %d" % [t + 2, t])
		check(v.wash_shown() == (t >= v.WASH_BAND), "wash: band %d %s" % [t, "washed" if t >= 6 else "dry"])
	await free_scene(scene)

## Band 2+: the waterline at 0.55 of the plate on both landings, drawn by state alone. Below
## it the wall is multiplied toward storm navy and a hard navy line marks it; above it, and on
## every object below it, the overlay is clear or the plate's own pixel. The hotspots never move.
func test_view_waterline() -> void:
	var scene = await view_scene(1)
	var v = scene.room_view
	var wl := int(v.WATERLINE_Y)
	check(wl == roundi(0.55 * 1086), "waterline: at 0.55 of the plate (y %d)" % wl)
	# [overlay, its plate, a wall point under the line, a point above it, an object face under it]
	var cases := [
		["wl_L1", "L1_base", Vector2i(1300, 760), Vector2i(1300, 500), Vector2i(300, 620)],
		["wl_L2", "L2_base", Vector2i(450, 760), Vector2i(450, 500), Vector2i(150, 700)],
		["wl_L2_wash", "L2_base", Vector2i(450, 760), Vector2i(450, 500), Vector2i(150, 700)],
	]
	for c in cases:
		check(FileAccess.file_exists("res://assets/stages/R11/%s.png" % c[0]), "waterline: %s is on disk" % c[0])
		var tex: Texture2D = v.textures.get(c[0])
		var base: Texture2D = v.textures.get(c[1])
		check(tex != null, "waterline: %s loads" % c[0])
		if tex == null or base == null:
			continue
		check(tex.get_size() == Vector2(1448, 1086), "waterline: %s is a full plate" % c[0])
		var img := tex.get_image()
		var bimg := base.get_image()
		var w := img.get_pixelv(c[2])
		var b := bimg.get_pixelv(c[2])
		check(w.a == 1.0 and w.get_luminance() < b.get_luminance() * 0.5,
			"waterline: %s sinks the wall (%.2f vs %.2f)" % [c[0], w.get_luminance(), b.get_luminance()])
		check(w.b >= w.r, "waterline: %s toward storm navy" % c[0])
		check(img.get_pixelv(c[3]).a == 0.0, "waterline: %s leaves the art above the line" % c[0])
		var o := img.get_pixelv(c[4])
		check(o.a == 0.0 or absf(o.get_luminance() - bimg.get_pixelv(c[4]).get_luminance()) < 0.02,
			"waterline: %s leaves an object under the line as painted" % c[0])
		var line := img.get_pixel(c[2].x, wl)
		check(line.a == 1.0 and line.get_luminance() < 0.2, "waterline: %s draws a hard navy line" % c[0])
		check(img.get_pixel(c[2].x, wl + 3).get_luminance() > img.get_pixel(c[2].x, wl + 8).get_luminance() + 0.3,
			"waterline: %s has a pale skin under the line" % c[0])
	var rects_before := {1: v.HOTSPOTS.duplicate(true), 2: v.L2_HOTSPOTS.duplicate(true)}
	for t in [3, 4, 5, 6, 7, 8, 9]:
		scene.tide_jump(t, ROOM)   # tide t starts at band t - 2 (R11 is first reached at tide III)
		await process_frame
		v = scene.room_view
		var band: int = scene.sim.weather_band()
		check(band == t - 2, "waterline: tide %d is band %d" % [t, t - 2])
		check(v.waterline_shown() == (band >= 2), "waterline: band %d %s" % [band, "flooded" if band >= 2 else "dry"])
		if band == 2:
			check(not scene.sim.flag("P12"), "waterline: band 2 is before P12")
		var r: R11Sim = v.r11
		r.landing = 1
		check(v.waterline_plate() == "wl_L1", "waterline: the gate landing's overlay")
		r.landing = 2
		check(v.waterline_plate() == ("wl_L2_wash" if v.wash_shown() else "wl_L2"),
			"waterline: band %d lower landing uses %s" % [band, v.waterline_plate()])
	check(v.HOTSPOTS == rects_before[1] and v.L2_HOTSPOTS == rects_before[2], "waterline: hotspot rects unchanged")
	await free_scene(scene)
