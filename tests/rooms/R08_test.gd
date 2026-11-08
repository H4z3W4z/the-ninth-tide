extends "res://tests/rooms/room_test_base.gd"
## R08, the Machine Room: P11 (something still breathing) over all 16 valve states, the
## INDEX hold, the commit chain, O04's repair tags, the escalation matrix, saves and debug.
##   godot --headless --path . --script tests/rooms/R08_test.gd

const ROOM := "R08"
## Flags that must all be set to enter (GDD section 5 traversal topology).
const EXPECT_REQUIRES := ["P09"]
## First tide at whose start the room is reachable from the office by real gates.
const OPEN_TIDE := 4

const VALVES := ["SUPPLY", "GATE", "RETURN", "INDEX"]
const SOLUTION := {"SUPPLY": true, "GATE": true, "RETURN": true, "INDEX": false}
## Reference fault lines and pump refusals, written out independently of R08Sim.
const REF_FIRST := {
	"no_supply": "No pressure. The pump would turn over on nothing.",
	"index": "It runs straight up the sealed line.",
	"gate_shut": "It stops short of the gate.",
	"dead_gate": "It reaches the gate and has no way back.",
	"loop": "Out through the gate and back. The sealed line stays dry.",
}
const REF_AGAIN := {
	"no_supply": "Still no pressure.",
	"index": "Into the sealed line again.",
	"gate_shut": "Dead before the gate.",
	"dead_gate": "Nothing coming back.",
	"loop": "The loop's clean.",
}
const REF_NAMES := {
	"no_supply": "NO PRESSURE",
	"index": "DIVERTED TO SEALED STUB",
	"gate_shut": "DEAD END BEFORE GATE",
	"dead_gate": "DEAD END AT GATE",
	"loop": "LOOP COMPLETE",
}
const REF_PUMP := {
	"index": ["pawl_lock", "It would feed the sealed line."],
	"no_supply": ["lever_spring", "Nothing to pump. It springs back."],
	"gate_shut": ["lever_spring", "Dead end before the gate. It springs back."],
	"dead_gate": ["lever_spring", "Dead end at the gate. It springs back."],
}
const REF_RESPIRATION := "With the gate loop running, one belt stopped. The diaphragm kept breathing without it. Under the belt, a nameplate: REFERENCE RESPIRATION."
const REF_HINTS := [
	"The drawing above the valve board is the circuit: a pump, four valves, the stair gate, and one capped stub.",
	"The capped stub on the drawing is the line that must never be fed. Find its valve.",
	"The drawing names nothing. The valve heads carry the same bands. And Venn tagged one of them 'Do not open.'",
	"07, 12 and 31 open, 44 shut. Then the pump.",
]
## The words the drawing may never carry: the lines' names live only on Venn's tags.
const LINE_NAMES := ["SUPPLY", "RETURN", "INDEX"]
const REF_DRAWING := "From the pump, a green-banded run out to the stair gate, a brass run on, a brown run back. A hatched stub hangs off the loop, capped."
## The band on each run of the drawing and on its valve's head, and the board's shuffled order.
const REF_BANDS := {"SUPPLY": "sea-glass", "GATE": "brass", "RETURN": "brown", "INDEX": "hatched navy"}
const REF_BOARD_ORDER := ["INDEX", "SUPPLY", "RETURN", "GATE"]
## The stamped tag number on each toggle, and the four valve tags, written out independently.
const REF_VALVE_TAGS := {"SUPPLY": "07", "GATE": "12", "RETURN": "31", "INDEX": "44"}
const REF_TAG_LINES := [
	"No. 07: SUPPLY valve reseated, 11 Jan 1926. E.V.",
	"No. 12: GATE valve repacked, 3 Mar 1926. E.V.",
	"No. 31: RETURN line flushed, 9 Sep 1927. E.V.",
	"No. 44: INDEX resealed. Wire cut again. Do not open. E.V.",
]
const EXHALE := "It's breathing out. It never used to."
const BULGE := "r08_room_s4_bulge"
## The P11 reveal chain, [text, delay], in order.
const REF_CHAIN := [
	["It takes. The gate line's holding pressure.", 0.6],
	["One of the belts is stopping.", 3.6],
	["The diaphragm didn't.", 8.4],
	["It breathed in. The dust came to it. Sideways.", 10.8],
	["There's a plate where the belt was. REFERENCE RESPIRATION.", 12.8],
]

func run_tests() -> void:
	skeleton_checks(ROOM, EXPECT_REQUIRES, OPEN_TIDE)
	test_all_states()
	test_circuit_static()
	test_index_refusal()
	test_commit_chain()
	test_idempotent()
	test_index_hunger()
	test_board_first_open()
	test_save_load()
	test_malformed()
	test_parallel_pair()
	test_repair_tags()
	test_nameplate()
	test_escalation()
	test_notices_once()
	test_first_arrival()
	test_hints_objective()
	test_use_item()
	test_room_lines()
	test_exhale()
	test_debug()
	test_p01_untouched()
	test_valve_tags()
	test_way_in_hint()
	test_view_static()
	if _view_ready():
		await view_checks(ROOM)
		await test_view_live()
		await test_view_hold_breath()
		await test_view_reveal_clock()
		await test_view_breathing_boss()
	else:
		print("SKIP: R08 view_checks: the R08 view does not yet declare rects for every sim hotspot (view team)")

# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
func r08(g: GameSim) -> R08Sim:
	return g.room(ROOM) as R08Sim

func _view_ready() -> bool:
	var m: Dictionary = load("res://game/rooms/R08/R08_view.gd").get_script_constant_map()
	var ids := []
	for h in m.get("HOTSPOTS", []):
		ids.append(h[0])
	for id in R08Sim.HOTSPOTS:
		if not id in ids:
			return false
	return true

## Every flag real play has at the start of tide IV.
func tide4_flags() -> Array:
	var out := ["closure_report_filed", "t1x_threshold_crossed"]
	for i in range(1, 10):
		out.append("P%02d" % i)
	return out

## State `i` (0..15) as toggles: bit 3 SUPPLY, bit 2 GATE, bit 1 RETURN, bit 0 INDEX.
func state_of(i: int) -> Dictionary:
	return {"SUPPLY": i & 8 != 0, "GATE": i & 4 != 0, "RETURN": i & 2 != 0, "INDEX": i & 1 != 0}

## The circuit, by reading the drawing: supply first, then the sealed branch before the gate,
## then the gate, then the way back.
func ref_code(t: Dictionary) -> String:
	if not t.SUPPLY:
		return "no_supply"
	if t.INDEX:
		return "index"
	if not t.GATE:
		return "gate_shut"
	if not t.RETURN:
		return "dead_gate"
	return "loop"

## Flip toggles on the open board until they match `want`.
func set_toggles(g: GameSim, want: Dictionary) -> void:
	var r := r08(g)
	for v in VALVES:
		if r.state.toggles[v] != want[v]:
			g.dispatch("tog_" + v.to_lower())

func solve_p11(g: GameSim) -> Array:
	g.dispatch("valve_board")
	set_toggles(g, SOLUTION)
	return g.dispatch("pump")

func ev_delay(ev: Array, type: String, id: String) -> float:
	for e in ev:
		if e.type == type and e.get("id", "") == id:
			return float(e.delay)
	return -1.0

func say_ev(ev: Array, text: String) -> Dictionary:
	for e in ev:
		if e.type == "say" and e.text == text:
			return e
	return {}

func ending_game(which: String) -> GameSim:
	var g := game_at(9, ROOM)
	g.set_flag("P27")
	g.state.ending = which
	return g

# ---------------------------------------------------------------------------------------------
# (2) all 16 valve states: PREVIEW names the fault; PUMP solves only the loop
# ---------------------------------------------------------------------------------------------
func test_all_states() -> void:
	for i in 16:
		var want := state_of(i)
		var code := ref_code(want)
		var g := game_at(4, ROOM)
		var r := r08(g)
		g.dispatch("valve_board")
		set_toggles(g, want)
		check(JSON.stringify(r.state.toggles) == JSON.stringify(want), "state %d: toggles set" % i)
		var inv: Array = g.state.inventory.duplicate()
		var ev := g.dispatch("preview")
		check(r.trace == code and r.trace_kind == "preview", "state %d: preview traces %s (got %s)" % [i, code, r.trace])
		check(says(ev) == REF_FIRST[code], "state %d: preview says '%s' (got '%s')" % [i, REF_FIRST[code], says(ev)])
		check(has_ev(ev, "sfx", "fault_buzz") == (code != "loop"), "state %d: fault buzz only on a fault" % i)
		check(not g.flag("P11"), "state %d: preview never solves" % i)
		check(says(g.dispatch("preview")) == REF_AGAIN[code], "state %d: second preview line" % i)
		ev = g.dispatch("pump")
		check(r.trace == code and r.trace_kind == "pump", "state %d: pump traces %s" % [i, code])
		if code == "loop":
			check(i == 14, "only SUPPLY+GATE+RETURN, INDEX shut is a loop")
			check(g.flag("P11") and r.state.p11_complete, "state %d: the loop solves P11" % i)
			check(has_ev(ev, "fx", "p11_reveal"), "state %d: reveal plays" % i)
		else:
			check(not g.flag("P11"), "state %d (%s): pump does not solve" % [i, code])
			check(JSON.stringify(r.state.toggles) == JSON.stringify(want), "state %d: pump leaves the toggles" % i)
			check(g.state.inventory == inv, "state %d: nothing is taken" % i)
			check(not has_ev(ev, "fx", "p11_reveal") and not has_ev(ev, "fx", "tide")
				and not has_ev(ev, "fx", "hold_breath"), "state %d: no solve event" % i)
			check(says(ev) == REF_PUMP[code][1] and has_ev(ev, "sfx", REF_PUMP[code][0]),
				"state %d: pump refusal for %s" % [i, code])
			check(r.view == "c_valves", "state %d: still at the board" % i)
			check(int(r.state.misses) == 3, "state %d: two previews and a pump are three misses" % i)

# ---------------------------------------------------------------------------------------------
# (3) the circuit table
# ---------------------------------------------------------------------------------------------
func test_circuit_static() -> void:
	var counts := {}
	for i in 16:
		var code := R08Sim.circuit(state_of(i))
		check(code == ref_code(state_of(i)), "circuit(%d) == %s" % [i, ref_code(state_of(i))])
		counts[code] = counts.get(code, 0) + 1
	check(counts == {"no_supply": 8, "index": 4, "gate_shut": 2, "dead_gate": 1, "loop": 1},
		"circuit counts 8/4/2/1/1 (got %s)" % counts)
	check(R08Sim.FAULT_NAMES == REF_NAMES, "fault names exact")
	for code in REF_FIRST:
		check(R08Sim.FAULT_LINES[code] == [REF_FIRST[code], REF_AGAIN[code]], "fault lines for %s" % code)

# ---------------------------------------------------------------------------------------------
# (4) INDEX open never engages
# ---------------------------------------------------------------------------------------------
func test_index_refusal() -> void:
	for gate in [false, true]:
		for ret in [false, true]:
			var g := game_at(4, ROOM)
			g.dispatch("valve_board")
			set_toggles(g, {"SUPPLY": true, "GATE": gate, "RETURN": ret, "INDEX": true})
			var ev := g.dispatch("pump")
			check(has_ev(ev, "sfx", "pawl_lock"), "INDEX open: pawl locks")
			check(says(ev) == "It would feed the sealed line.", "INDEX open: card line exact")
			check(not g.flag("P11"), "INDEX open never engages")

# ---------------------------------------------------------------------------------------------
# (5) the commit chain
# ---------------------------------------------------------------------------------------------
func test_commit_chain() -> void:
	var g := game_at(4, ROOM)
	var r := r08(g)
	var ev := solve_p11(g)
	check(g.flag("P11"), "the loop and PUMP solve P11")
	check(ev_delay(ev, "sfx", "pump_engage") == 0.0, "pump_engage at 0.0")
	check(ev_delay(ev, "sfx", "belt_wind_down") > ev_delay(ev, "sfx", "pump_engage"), "the belt winds down after the pump engages")
	check(ev_delay(ev, "sfx", "breath_alone") > ev_delay(ev, "sfx", "belt_drop"), "the breath comes after the belt drops")
	var said := []
	for e in ev:
		if e.type == "say":
			said.append([e.text, float(e.delay)])
			check(e.story, "reveal line '%s' is a story line" % e.text)
	check(said == REF_CHAIN, "the reveal's lines, in order, at their times (got %s)" % [said])
	check(ev_delay(ev, "sfx", "belt_drop") == 6.6, "belt_drop at 6.6")
	check(ev_delay(ev, "sfx", "breath_alone") == 8.2, "breath_alone at 8.2, after the silence")
	check(ev_delay(ev, "sfx", "dust_drag") == R08Sim.DUST_DRAG_AT and VIEW.RV_DUST == R08Sim.DUST_DRAG_AT
		and VIEW.RV_INHALE == ev_delay(ev, "sfx", "breath_alone"), "dust_drag rides the reveal's inhale")
	check(VIEW.RV_DUST > VIEW.RV_INHALE and VIEW.RV_DUST < VIEW.RV_INHALE + VIEW.RV_INHALE_TIME, "the dust moves inside the inhale")
	var order := []
	for e in ev:
		if e.type == "sfx" and e.id in ["belt_drop", "breath_alone"]:
			order.append([e.id, float(e.delay)])
		if e.type == "say" and e.text in ["One of the belts is stopping.", "The diaphragm didn't."]:
			order.append([e.text, float(e.delay)])
	order.sort_custom(func(a, b): return a[1] < b[1])
	check(order.map(func(x): return x[0]) == ["One of the belts is stopping.", "belt_drop", "breath_alone",
		"The diaphragm didn't."], "belt line, drop, breath alone, then 'The diaphragm didn't.'")
	check(r.OBSERVATIONS.reference_respiration == REF_RESPIRATION, "reference_respiration exact")
	check(r.has_seen("reference_respiration"), "the R08 page has reference_respiration")
	check(has_ev(ev, "fx", "p11_reveal"), "fx p11_reveal")
	check(r.local_view == "room", "the commit returns to the room")
	check("breathes_alone" in r.state.notices, "the commit retires the breathes_alone notice")
	check(r.state.toggles == SOLUTION, "the board stays in the loop")
	check(not has_ev(ev, "fx", "tide"), "P11 alone does not end tide IV")
	# SILENCE: the last line opens a held breath of 1.8 s, timed to that line's delay
	var hb := {}
	for e in ev:
		if e.type == "fx" and e.id == "hold_breath":
			check(hb.is_empty(), "one hold_breath")
			hb = e
	check(not hb.is_empty(), "fx hold_breath")
	check(is_equal_approx(float(hb.get("seconds", 0.0)), 1.8), "hold_breath lasts 1.8 s")
	check(is_equal_approx(float(hb.get("delay", -1.0)), REF_CHAIN[-1][1]) and R08Sim.REVEAL_LAST_AT == REF_CHAIN[-1][1],
		"hold_breath lands with the last line (%s)" % hb.get("delay"))
	check(JSON.parse_string(JSON.stringify(hb)) is Dictionary, "hold_breath is JSON-safe")

# ---------------------------------------------------------------------------------------------
# (6) idempotent after solving
# ---------------------------------------------------------------------------------------------
func test_idempotent() -> void:
	var g := game_at(4, ROOM)
	var r := r08(g)
	solve_p11(g)
	var ev := g.dispatch("valve_board")
	check(says(ev) == "The board's locked under pressure.", "board locked line on reopening")
	ev = g.dispatch("pump")
	check(g.flag("P11") and not has_ev(ev, "fx", "p11_reveal") and not has_ev(ev, "fx", "hold_breath"),
		"a second PUMP is no second solve, and no second held breath")
	check(says(ev) == "It's running. The gate line holds." and has_ev(ev, "sfx", "gauge_rise"), "second PUMP line")
	for v in VALVES:
		ev = g.dispatch("tog_" + v.to_lower())
		check(has_ev(ev, "sfx", "board_locked") and says(ev) == "It's under pressure. It won't move now.",
			"tog_%s after solving is locked" % v.to_lower())
	check(r.state.toggles == SOLUTION, "toggles unchanged after solving")
	check(says(g.dispatch("preview")) == REF_FIRST.loop, "preview after solving shows the loop")

# ---------------------------------------------------------------------------------------------
# (7) the INDEX hold
# ---------------------------------------------------------------------------------------------
func test_index_hunger() -> void:
	var g := game_at(4, ROOM)
	var r := r08(g)
	g.dispatch("valve_board")
	check(not r.held(), "not held at the start")
	var ev := g.dispatch("tog_supply")
	check(r.held(), "SUPPLY into an open INDEX holds the machine")
	check(has_ev(ev, "sfx", "cycle_stop") and ev_delay(ev, "sfx", "cycle_stop") == 0.0, "cycle_stop at 0.0")
	check(has_ev(ev, "fx", "hold") and has_ev(ev, "sfx", "toggle_open"), "hold fx and the toggle")
	check(r.has_seen("index_hunger"), "index_hunger observed")
	check(say_ev(ev, "Everything stopped. Behind me, the flywheel too.").get("story", false)
		and say_ev(ev, "It's holding its breath. Like it's listening.").get("story", false), "two story lines")
	ev = g.dispatch("tog_index")
	check(not r.held(), "shutting INDEX lets go")
	check(has_ev(ev, "sfx", "cycle_resume") and has_ev(ev, "fx", "release") and has_ev(ev, "sfx", "toggle_shut"), "release events")
	check(says(ev) == "It let go when the line shut.", "release line")
	var before := r.seen().size()
	ev = g.dispatch("tog_index")
	check(r.held() and says(ev) == "It's holding again.", "held again: short line")
	check(r.seen().size() == before, "no new observation when it holds again")
	ev = g.dispatch("tog_supply")
	check(not r.held() and says(ev) == "" and has_ev(ev, "sfx", "cycle_resume"), "second release is silent")
	g.dispatch("tog_supply")
	check(says(g.dispatch("belt")) == "Stopped mid-stroke. All three.", "belt while held")
	check(r.local_view == "room", "a room hotspot from the board returns to the room")
	check(says(g.dispatch("flywheel")) == "Stopped dead. A wheel that size shouldn't stop like that.", "flywheel while held")
	check(says(g.dispatch("dust")) == "The dust isn't moving. Nothing is.", "dust while held")
	check(says(g.dispatch("diaphragm")) == "It's holding. Full.", "diaphragm while held")

# ---------------------------------------------------------------------------------------------
# (8) first board open
# ---------------------------------------------------------------------------------------------
func test_board_first_open() -> void:
	for h in ["valve_board", "drawing"]:
		var g := game_at(4, ROOM)
		var r := r08(g)
		check(r.state.toggles.INDEX == true, "INDEX starts OPEN")
		var ev := g.dispatch(h)
		check(r.view == "c_valves", "%s opens c_valves" % h)
		check(r.has_seen("valve_board") and r.has_seen("drawing") and r.has_seen("index_seal_cut"),
			"%s first open observes board, drawing and the cut seal" % h)
		check(says(ev) == "No names on the toggles, only stamped numbers. Someone left 44 open. Its seal wire has been cut.", "first-open line")
		g.dispatch("back")
		check(r.view == "room", "back from c_valves")
		check(says(g.dispatch(h)) == "", "reopening the board is silent")
	var g := game_at(4, ROOM)
	g.dispatch("valve_board")
	check(says(g.dispatch("look_drawing")) == REF_DRAWING, "look_drawing")
	g.dispatch("preview")
	g.dispatch("back")
	check(r08(g).trace == "" and r08(g).trace_kind == "", "back clears the trace")

# ---------------------------------------------------------------------------------------------
# (9) save and load
# ---------------------------------------------------------------------------------------------
func test_save_load() -> void:
	var g := game_at(4, ROOM)
	g.dispatch("valve_board")
	set_toggles(g, {"SUPPLY": true, "GATE": false, "RETURN": true, "INDEX": false})
	g.dispatch("preview")
	var want := {"SUPPLY": true, "GATE": false, "RETURN": true, "INDEX": false}
	var g2 := GameSim.new()
	check(g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict()))), "mid-puzzle save loads")
	var r2 := r08(g2)
	check(g2.state.room == ROOM, "loads in the machine room")
	check(JSON.stringify(r2.state.toggles) == JSON.stringify(want), "toggles kept across a save")
	check(r2.local_view == "room" and r2.trace == "", "load lands in the room with no trace")
	check(r2.state.index_offered and r2.state.released_once, "hold history kept")
	check("gate_shut" in r2.state.previewed_codes, "previewed codes kept")
	check(says(g2.dispatch("valve_board")) == "", "the board was already opened")
	check(says(g2.dispatch("preview")) == REF_AGAIN.gate_shut, "a previewed circuit stays previewed")
	# The same game reloaded: the transient trace is gone.
	check(g.from_dict(g.to_dict()) and r08(g).trace == "" and r08(g).trace_kind == "", "reload clears the trace")
	# Solved: the board and tags survive.
	var s := game_at(4, ROOM)
	solve_p11(s)
	s.dispatch("repair_tags")
	for i in 3:
		s.dispatch("tag_next")
	var s2 := GameSim.new()
	s2.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(s2.flag("P11") and s2.flag("o04_found") and r08(s2).state.tag == 3, "solved save keeps P11, O04 and the page")

func test_malformed() -> void:
	var base := game_at(4, ROOM)
	var d: Dictionary = base.to_dict()
	var cases := [
		[{"toggles": {"SUPPLY": "yes"}}, "toggles"],
		[{"toggles": {"SUPPLY": true, "GATE": true, "RETURN": true, "INDEX": false, "EXTRA": true}}, "toggles"],
		[{"toggles": [true, true, true, false]}, "toggles"],
	]
	for c in cases:
		var dd: Dictionary = d.duplicate(true)
		dd.rooms[ROOM] = c[0]
		var g := GameSim.new()
		g.from_dict(dd)
		check(r08(g).state.toggles == r08(g).initial_state().toggles, "malformed %s -> default (%s)" % [c[1], c[0]])
	var dd: Dictionary = d.duplicate(true)
	dd.rooms[ROOM] = {"p11_complete": true, "tags_opened": true, "tag": 99, "tag_max": 2,
		"notices": ["bogus", "cycle_pause", "cycle_pause"], "misses": 5000, "previewed_codes": ["loop", "x", "loop"],
		"toggles": {"SUPPLY": false, "GATE": false, "RETURN": false, "INDEX": true}}
	var g := GameSim.new()
	g.from_dict(dd)
	var r := r08(g)
	check(r.state.tag == R08Sim.TAG_LAST and r.state.tag_max == R08Sim.TAG_LAST, "tag 99 -> the last page, tag_max follows")
	check(r.state.notices == ["cycle_pause"], "unknown and duplicate notices dropped")
	check(r.state.misses == 999, "misses clamped")
	check(r.state.previewed_codes == ["loop"], "previewed codes validated")
	check(r.state.toggles == SOLUTION, "p11_complete forces the solved board")
	check(g.flag("P11") and g.flag("o04_found"), "P11 and O04 follow the state after reconcile")
	dd.rooms[ROOM] = {"notices": ["bogus"], "tags_opened": true, "tag": 1.5, "misses": -3, "p11_complete": "yes"}
	g = GameSim.new()
	g.from_dict(dd)
	r = r08(g)
	check(r.state.notices == [] and r.state.tag == 0 and r.state.misses == 0, "bogus notices, fractional tag, negative misses")
	check(not r.state.p11_complete and r.state.tags_opened and not g.flag("o04_found"), "tags read before P11 load; O04 needs P11")
	check(not g.flag("P11"), "a non-bool p11_complete is ignored")
	g = GameSim.new()
	dd.rooms[ROOM] = "garbage"
	g.from_dict(dd)
	check(r08(g).state == r08(g).initial_state(), "a non-dict room state is the default")
	# o04_found set elsewhere (tests, debug) is honoured once P11 is done, and only then.
	var o := game_at(5, ROOM)
	o.set_flag("o04_found")
	var o2 := GameSim.new()
	o2.from_dict(o.to_dict())
	check(o2.flag("o04_found") and r08(o2).state.tags_opened, "o04_found with P11 survives a save")
	var n := game_at(4, ROOM)
	n.set_flag("o04_found")
	var n2 := GameSim.new()
	n2.from_dict(n.to_dict())
	check(not n2.flag("o04_found"), "o04_found without P11 follows the room")

# ---------------------------------------------------------------------------------------------
# (10) the parallel pair P10 / P11
# ---------------------------------------------------------------------------------------------
func test_parallel_pair() -> void:
	for order in ["p10_first", "p11_first"]:
		var flags := tide4_flags()
		if order == "p10_first":
			flags.append("P10")
		var g := with_flags(flags, ROOM)
		check(g.tide() == 4, "%s: tide IV" % order)
		solve_p11(g)
		if order == "p11_first":
			g.set_flag("P10")
		check(g.flag("P10") and g.flag("P11"), "%s: both set" % order)
		check(not g.flag("P12"), "%s: P12 stays false" % order)
		check(g.tide() == 4, "%s: still tide IV" % order)
		check(g.exit_open(ROOM, "R07") and g.exit_open(ROOM, "R05"), "%s: both exits open" % order)

# ---------------------------------------------------------------------------------------------
# (11) O04: the repair tags
# ---------------------------------------------------------------------------------------------
func test_repair_tags() -> void:
	var g := game_at(4, ROOM)
	var r := r08(g)
	# The tags are the key to P11: readable past the running belt, before the commit.
	var ev := g.dispatch("repair_tags")
	check(r.view == "c_tags" and has_ev(ev, "sfx", "tag_lift"), "c_tags opens before P11")
	check(says(ev) == "A ring of brass tags behind the belt. I can reach it past the lacing. His repair tags.", "tags line before P11")
	check(r.has_seen("o04_tags") and r.has_seen("tag_07") and not g.flag("o04_found"), "first tag read; O04 waits for P11")
	g.dispatch("back")
	solve_p11(g)
	check(g.flag("o04_found"), "tags read before the commit: O04 found at P11")
	var f := game_at(4, ROOM)
	var rf := r08(f)
	solve_p11(f)
	check(not f.flag("o04_found"), "tags unread: no O04 at the commit")
	ev = f.dispatch("repair_tags")
	check(f.flag("o04_found") and rf.view == "c_tags", "O04 found on opening the tags after P11")
	check(says(ev) == "His repair tags. Years of them.", "first tags line after P11")
	g.dispatch("repair_tags")
	for i in R08Sim.TAG_LAST:
		ev = g.dispatch("tag_next")
		check(has_ev(ev, "sfx", "tag_flip"), "page flips")
		if i + 1 == R08Sim.TAG_KEEPS_TIME - 1:
			check(not r.has_seen("o04_keeps_time"), "keeps_time waits for 4 JUN 30")
		if i + 1 == R08Sim.TAG_KEEPS_TIME:
			check(r.has_seen("o04_keeps_time"), "4 JUN 30 observes keeps_time")
	check(r.TAGS[R08Sim.TAG_KEEPS_TIME].begins_with("4 JUN 30.") and r.TAGS[R08Sim.TAG_LEANING].begins_with("14 OCT 31."),
		"keeps_time and leaning pages")
	check(r.state.tag == R08Sim.TAG_LAST and r.state.tag_max == R08Sim.TAG_LAST, "nexts reach the last page")
	check(r.has_seen("o04_keeps_time") and r.has_seen("o04_leaning") and r.has_seen("o04_new_tag"), "tag observations")
	check(says(ev) == "New brass. Dated tomorrow. Nothing written on it." and has_ev(ev, "sfx", "tag_settle"), "page 8 line")
	check(r.tag_stamp() == ["18 OCT 31"] and not r.has_seen("o04_am"), "no A.M. at band 2")
	g.dispatch("tag_next")
	check(r.state.tag == R08Sim.TAG_LAST, "a next past the end stays on the last page")
	g.dispatch("tag_prev")
	check(r.state.tag == R08Sim.TAG_LAST - 1 and r.state.tag_max == R08Sim.TAG_LAST, "tag_prev steps back")
	check(says(g.dispatch("tag")) == "", "the last page again says nothing new")
	check(r.TAGS.size() == 13 and r.TAGS[11] == "14 OCT 31. Rim rebolted. It is not pushing. It is leaning. E.V.", "tag text")
	g.dispatch("back")
	check(r.view == "room", "back from c_tags")
	check(says(g.dispatch("repair_tags")) == "", "reopening the tags is quiet")
	# Band 7: the stamp.
	var t := game_at(9, ROOM)
	var rt := r08(t)
	t.dispatch("repair_tags")
	for i in R08Sim.TAG_LAST:
		ev = t.dispatch("tag_next")
	check(rt.has_seen("o04_am") and "A.M." in rt.tag_stamp(), "band 7: page 8 stamped A.M.")
	check(says(ev).ends_with("Someone has stamped it again. A.M."), "A.M. line")
	check(not "A.M." in ending_game("continue").room(ROOM).tag_stamp(), "no A.M. after an ending")
	g.dispatch("back")
	var page: int = r.state.tag
	g.dispatch("tag_prev")
	check(r.local_view == "room" and r.state.tag == page, "tag controls outside c_tags do nothing")

# ---------------------------------------------------------------------------------------------
# (12) the nameplate
# ---------------------------------------------------------------------------------------------
func test_nameplate() -> void:
	var g := game_at(4, ROOM)
	var r := r08(g)
	var before := r.seen().size()
	var ev := g.dispatch("nameplate")
	check(says(ev) == "Something's riveted to the frame behind the belt. I can't read it with the belt running over it.", "nameplate before P11")
	check(r.seen().size() == before and not r.nameplate_shown(), "nameplate unseen before P11")
	solve_p11(g)
	ev = g.dispatch("nameplate")
	check(says(ev) == "REFERENCE RESPIRATION." and has_ev(ev, "sfx", "nameplate_tap"), "nameplate after P11")
	check(r.nameplate_shown(), "nameplate shown after P11")

# ---------------------------------------------------------------------------------------------
# (13) the escalation matrix
# ---------------------------------------------------------------------------------------------
func test_escalation() -> void:
	var solved := game_at(4, ROOM)
	solve_p11(solved)
	var cases := [
		["pre", game_at(4, ROOM), [true, true, true], "cycle", "even", false, "", "room", "cycle_pause"],
		["p11", solved, [true, false, true], "alone", "streaks", false, "", "room", "breathes_alone"],
		["b3", game_at(5, ROOM), [true, false, true], "alone", "lines", false, "", "room_s3", "dust_lines"],
		["b4", game_at(6, ROOM), [true, false, true], "alone", "lines", true, "", BULGE, "bolts_out"],
		["b5", game_at(7, ROOM), [true, false, true], "nora", "raked", true, "", BULGE, "breath_nora"],
		["b6", game_at(8, ROOM), [false, false, false], "nora", "raked", true, "late", BULGE, "late_reflection"],
		["b7", game_at(9, ROOM), [false, false, false], "nora", "raked", true, "late", BULGE, "far_horizon"],
		["sever", ending_game("sever"), [false, false, false], "still", "flat", false, "", "room_sever", "end_sever"],
		["continue", ending_game("continue"), [false, false, false], "even", "raked", true, "now", BULGE, "end_continue"],
	]
	for c in cases:
		var r := r08(c[1])
		check(r.belts_running() == c[2], "%s belts %s (got %s)" % [c[0], c[2], r.belts_running()])
		check(r.breath_mode() == c[3], "%s breath %s (got %s)" % [c[0], c[3], r.breath_mode()])
		check(r.dust_mode() == c[4], "%s dust %s (got %s)" % [c[0], c[4], r.dust_mode()])
		check(r.bolts_out_shown() == c[5], "%s bolts_out %s" % [c[0], c[5]])
		check(r.reflection_mode() == c[6], "%s reflection '%s' (got '%s')" % [c[0], c[6], r.reflection_mode()])
		check(r.stage_plate() == c[7], "%s plate %s (got %s)" % [c[0], c[7], r.stage_plate()])
		check(r.bulging() == (c[7] == BULGE), "%s bulging only with the bulge plate" % c[0])
		check(r.current_notice() == c[8], "%s notice %s (got %s)" % [c[0], c[8], r.current_notice()])
		check(r.nameplate_shown() == (c[0] != "pre") and r.gauge_powered() == (c[0] != "pre"), "%s nameplate/gauge" % c[0])
		check(r.pump_on() == (c[0] in ["p11", "b3", "b4", "b5"]), "%s pump_on" % c[0])
	# held() freezes the presentation, not the belts.
	var h := game_at(4, ROOM)
	h.dispatch("valve_board")
	h.dispatch("tog_supply")
	check(r08(h).held() and r08(h).belts_running() == [true, true, true], "held keeps belts_running")
	check(R08Sim.NOTICE_LINES.late_reflection == "The room is in its surface. A moment late.", "band 6 notice line")
	check(R08Sim.NOTICE_LINES.far_horizon == "Further back than the wall goes. A long way further.", "band 7 notice line")
	# Weather is progress, not a clock: the same flags give the same matrix.
	check(r08(game_at(7, ROOM)).breath_mode() == r08(game_at(7, ROOM)).breath_mode(), "deterministic")

# ---------------------------------------------------------------------------------------------
# (14) notices play once
# ---------------------------------------------------------------------------------------------
func test_notices_once() -> void:
	var g := game_at(7, ROOM)
	var r := r08(g)
	check(not "breath_nora" in r.state.notices, "breath_nora pending at tide VI")
	g.dispatch("go:R07")
	var ev := g.dispatch("go:R08")
	check(g.state.room == ROOM, "back in R08")
	check(says(ev).contains("It is breathing like her.") and has_ev(ev, "fx", "notice_breath_nora"), "breath_nora on the first return")
	check(r.has_seen("breath_nora"), "breath_nora observed")
	g.dispatch("go:R07")
	ev = g.dispatch("go:R08")
	check(not says(ev).contains("It is breathing like her.") and not has_ev(ev, "fx", "notice_breath_nora"), "breath_nora plays once")
	# Every stage's notice plays on a return, once.
	for t in range(5, 10):
		var s := game_at(t, ROOM)
		var n := r08(s).current_notice()
		s.dispatch("go:R07")
		ev = s.dispatch("go:R08")
		check(say_ev(ev, R08Sim.NOTICE_LINES[n]).get("delay", -1.0) == 1.6, "tide %d: notice %s at 1.6" % [t, n])
		check(r08(s).has_seen(n), "tide %d: %s observed" % [t, n])
	# After the commit the breathes_alone notice is behind her.
	var p := game_at(4, ROOM)
	solve_p11(p)
	p.dispatch("go:R07")
	ev = p.dispatch("go:R08")
	check(not has_ev(ev, "fx", "notice_breathes_alone"), "breathes_alone already seen at the commit")

func test_first_arrival() -> void:
	var g := game_at(4, "R05")
	g.state.visited.erase(ROOM)
	var ev := g.dispatch("go:R08")
	var r := r08(g)
	check(g.state.room == ROOM, "walked in from the kitchen")
	check(say_ev(ev, R08Sim.ARRIVAL).get("delay", -1.0) == 0.0, "arrival line")
	check(say_ev(ev, "The cycle has a pause in it.").get("delay", -1.0) == 3.2, "cycle pause at 3.2")
	check(has_ev(ev, "fx", "notice_cycle_pause"), "cycle pause fx")
	check(r.has_seen("diaphragm") and r.has_seen("cycle_pause") and "cycle_pause" in r.state.notices, "arrival notes")
	g.dispatch("go:R05")
	ev = g.dispatch("go:R08")
	check(says(ev) == "", "nothing new on the next return")
	# A first visit after P11 also plays the current notice.
	var late := game_at(6, "R05")
	late.state.visited.erase(ROOM)
	r08(late).state.notices = []
	ev = late.dispatch("go:R08")
	check(says(ev).begins_with(R08Sim.ARRIVAL) and says(ev).contains(R08Sim.NOTICE_LINES.bolts_out), "late first visit plays the current notice")

# ---------------------------------------------------------------------------------------------
# (15) hints and objective
# ---------------------------------------------------------------------------------------------
func test_hints_objective() -> void:
	var g := game_at(4, ROOM)
	var r := r08(g)
	check(r.objective() == "p11" and r.objective_text() == "Route the pump to the stair gate without feeding the sealed line.", "p11 objective")
	check(r.hint_tiers() == 4, "P11's ladder has four tiers: nudge, relationship, evidence, solution")
	check(r.hint_line(2) == REF_HINTS[2] and r.hint_line(3) == REF_HINTS[3], "P11: evidence, then solution")
	# pressed in the room: three tiers, the core's confirmation, then the solution
	var confirm: String = GameSim.HINT_CONFIRM
	for i in 3:
		check(says(g.dispatch("hint")) == REF_HINTS[i], "hint %d exact" % i)
	check(says(g.dispatch("hint")) == confirm, "the core asks before the solution")
	check(says(g.dispatch("hint")) == REF_HINTS[3], "then the solution")
	check(says(g.dispatch("hint")) == REF_HINTS[3], "the ladder stops at the solution")
	# every tier says something new (the second and third most of all)
	for i in 4:
		for j in range(i + 1, 4):
			check(GameSim._hint_key(REF_HINTS[i]) != GameSim._hint_key(REF_HINTS[j]), "hint tiers %d and %d differ" % [i + 1, j + 1])
	check(REF_HINTS[1] == "The capped stub on the drawing is the line that must never be fed. Find its valve.", "tier 2 points at the capped stub")
	# no room-side bridge: the core's ladder is the room's HINTS, press by press
	check(not (load("res://game/rooms/R08/R08_sim.gd") as Script).source_code.contains("func hint_line("),
		"R08 does not override hint_line")
	for i in 4:
		check(r.hint_line(i) == REF_HINTS[i], "hint_line(%d) is the ladder's tier, whatever was pressed" % i)
	# the evidence tier names what's on the tags and the drawing, not the switch positions
	check(not "open" in REF_HINTS[2].to_lower().replace("do not open", "")
		and not "shut" in REF_HINTS[2].to_lower(), "the evidence tier doesn't set the board")
	# away from the machine room its ladder stays in order (no early solution)
	var away := game_at(4, ROOM)
	var ra := r08(away)
	away.state.hint = {"for": "R05:p09", "level": 3}
	check(ra.hint_line(2) == REF_HINTS[2], "another room's hint level never skips P11's evidence tier")
	solve_p11(g)
	check(r.objective() == "done", "objective done after P11")
	check(r.HINTS.done.size() == 3 and r.hint_tiers() == 3, "done ladder keeps three tiers")
	var f := game_at(4, ROOM)
	f.set_flag("P11")
	check(r08(f).objective() == "done" and r08(f).state.toggles == SOLUTION, "a P11 flag set elsewhere is honoured")

# ---------------------------------------------------------------------------------------------
# (16) items
# ---------------------------------------------------------------------------------------------
func use(g: GameSim, item: String, target: String) -> Array:
	if not g.has_item(item):
		g.give(item, [])
	g.dispatch("item:" + item)
	return g.dispatch(target)

func test_use_item() -> void:
	var g := game_at(4, ROOM)
	var r := r08(g)
	var ev := use(g, "inspection_lens", "diaphragm")
	check(says(ev) == "Under the lens it isn't rubber. It has pores, and they close when it breathes in.", "lens on the diaphragm")
	check(r.has_seen("lens_pores") and g.has_item("inspection_lens"), "lens_pores observed; lens kept")
	for item in ["token_pantry_half", "token_bunk_half", "pencil", "venn_tide_sheet"]:
		ev = use(g, item, "diaphragm")
		check(says(ev) == "I'm not feeding it anything.", "%s on the diaphragm refused" % item)
		check(g.has_item(item), "%s kept" % item)
	ev = use(g, "inspection_lens", "drawing")
	check(says(ev) == "The capped stub is drawn in a different ink. Added after, then capped." and r.has_seen("lens_index_ink"), "lens on the drawing")
	check(says(use(g, "inspection_lens", "dust")) == "Grey grains, every one lying the same way. Toward it.", "lens on dust pre-P11")
	check(says(use(g, "inspection_lens", "nameplate")) == "Not through a running belt.", "lens on nameplate pre-P11")
	check(says(use(g, "inspection_lens", "bolts")) == "The paint stripe is unbroken on all twelve.", "lens on bolts at band 2")
	check(says(use(g, "inspection_lens", "belt")) == "The lacing is all one hand.", "lens on belt")
	check(says(use(g, "inspection_lens", "flywheel")) == "Oil and old paint. Nothing to see but it turning.", "lens on flywheel")
	check(says(use(g, "inspection_lens", "repair_tags")) == "The writing slopes backwards. Left-handed. Venn.", "lens on tags before P11")
	check(says(use(g, "pencil", "drawing")) == "I won't add anything to his drawing.", "pencil on the drawing")
	check(says(use(g, "pencil", "bolts")) == "That isn't what it's for.", "pencil elsewhere is generic")
	solve_p11(g)
	check(says(use(g, "inspection_lens", "dust")) == "Every grain lies with its long side toward the ring.", "lens on dust after P11")
	check(says(use(g, "inspection_lens", "nameplate")) == "The plate is older than the frame. The rivets were set round it.", "lens on nameplate after P11")
	check(says(use(g, "inspection_lens", "repair_tags")) == "The writing slopes backwards. Left-handed. Venn.", "lens on tags after P11")
	g.dispatch("repair_tags")
	for i in R08Sim.TAG_LAST:
		g.dispatch("tag_next")
	check(says(use(g, "pencil", "tag")) == "Not yet. I don't know what was repaired.", "pencil on the new tag")
	check(g.has_item("pencil"), "pencil kept")
	var b := game_at(6, ROOM)
	check(says(use(b, "inspection_lens", "bolts")) == "Bright thread, no rust. That metal hasn't seen air in four years.", "lens on bolts at band 4")

# ---------------------------------------------------------------------------------------------
# room lines across the stages
# ---------------------------------------------------------------------------------------------
func test_room_lines() -> void:
	var g := game_at(4, ROOM)
	check(says(g.dispatch("diaphragm")) == "It draws in when the belt pulls and lets go when it slacks. A pump. It's only a pump.", "diaphragm first look")
	check(says(g.dispatch("diaphragm")) == "In. And out. With the belt.", "diaphragm again")
	var ev := g.dispatch("bolts")
	check(has_ev(ev, "sfx", "bolt_tap") and says(ev) == "Twelve bolts. A white paint stripe across every head, so you'd see if one turned. None has.", "bolts base")
	check(says(g.dispatch("belt")) == "The middle belt runs down to the diaphragm's crank. Laced and relaced.", "belt base")
	check(says(g.dispatch("flywheel")) == "A flywheel taller than I am. Slow and even, and then the hitch.", "flywheel base")
	check(says(g.dispatch("dust")) == "Swept, and settled again. Nobody's walked through it but me.", "dust base")
	for h in ["belt", "flywheel", "bolts", "dust", "diaphragm"]:
		check(r08(g).has_seen(h), "%s observed" % h)
	solve_p11(g)
	check(says(g.dispatch("diaphragm")) == "Nothing drives it now. It breathes anyway. | " + EXHALE, "diaphragm after P11, first look")
	check(says(g.dispatch("diaphragm")) == "Nothing drives it now. It breathes anyway.", "diaphragm after P11")
	check(says(g.dispatch("belt")) == "The middle belt's stopped. Slipped off its drum and hanging.", "belt after P11")
	check(says(g.dispatch("flywheel")) == "Still turning. It drives the pump now.", "flywheel after P11")
	check(says(g.dispatch("dust")) == "Dragged into streaks. Toward it.", "dust after P11")
	var lines := {
		5: {"diaphragm": "Every grain of dust on the floor points at it.", "dust": "Lines, all pointing at it."},
		6: {"diaphragm": "A finger's width further out than it was. I can see the bolts' threads.",
			"bolts": "The paint's cracked on every one. They haven't turned. They've been pushed."},
		7: {"diaphragm": "Two short. A pause. One long. I know that breath.", "dust": "Raked: two short marks, a gap, one long."},
		8: {"diaphragm": "Everything else has stopped. In its surface there's a horizon where the room should be.",
			"belt": "All three belts, still.", "flywheel": "Still."},
		9: {"diaphragm": "Nine pale points along that horizon. It goes back further than the wall does."},
	}
	for t in lines:
		var s := game_at(t, ROOM)
		for h in lines[t]:
			var want: String = lines[t][h] + (" | " + EXHALE if h == "diaphragm" else "")
			check(says(s.dispatch(h)) == want, "tide %d %s" % [t, h])
	var b6 := game_at(8, ROOM)
	b6.dispatch("diaphragm")
	b6.dispatch("belt")
	check(r08(b6).has_seen("late_reflection") and r08(b6).has_seen("belts_still"), "band 6: the horizon and the still belts noted")
	check(r08(game_at(6, ROOM)).has_seen("bolts_out") == false, "bolts_out waits for a look or a return")
	var b4 := game_at(6, ROOM)
	b4.dispatch("bolts")
	check(r08(b4).has_seen("bolts_out"), "bolts at band 4 observe bolts_out")
	var sv := ending_game("sever")
	check(says(sv.dispatch("diaphragm")) == "Slack. It hangs in its ring like a wet sail.", "sever diaphragm")
	check(says(sv.dispatch("bolts")) == "Just bolts.", "sever bolts")
	check(says(sv.dispatch("dust")) == "Flat. Settled.", "sever dust")
	check(says(sv.dispatch("belt")) == "All three belts, still.", "sever belt")
	var cn := ending_game("continue")
	check(says(cn.dispatch("diaphragm")) == "It breathes. Evenly. Not behind any more.", "continue diaphragm")
	check(r08(cn).has_seen("end_continue"), "continue diaphragm observed")
	# Every observation id this room records is declared.
	for s in [g, sv, cn]:
		for o in r08(s).seen():
			check(R08Sim.OBSERVATIONS.has(o), "observation %s is declared" % o)

## The first diaphragm look after P11 says, verbatim, that it breathes out; once, saved, never
## before P11 and never at an ending.
func test_exhale() -> void:
	check(R08Sim.EXHALE_LINE == EXHALE, "the exhale line is verbatim")
	var g := game_at(4, ROOM)
	check(not says(g.dispatch("diaphragm")).contains(EXHALE), "no exhale before P11")
	g.dispatch("valve_board")
	g.dispatch("tog_supply")
	check(not says(g.dispatch("diaphragm")).contains(EXHALE), "no exhale while it is held")
	check(not r08(g).state.exhale_said, "the flag waits for P11")
	g.dispatch("tog_supply")
	solve_p11(g)
	var ev := g.dispatch("diaphragm")
	var e := say_ev(ev, EXHALE)
	check(not e.is_empty() and e.story and float(e.delay) == R08Sim.EXHALE_DELAY, "first look after P11: the exhale, a story line after the stage line")
	check(say_ev(ev, "Nothing drives it now. It breathes anyway.").get("story", false), "the stage line is part of the same story chain")
	check(r08(g).state.exhale_said, "exhale_said set")
	check(not says(g.dispatch("diaphragm")).contains(EXHALE), "said once")
	# saved: a reload never says it again
	var g2 := GameSim.new()
	check(g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict()))), "save loads")
	check(r08(g2).state.exhale_said, "exhale_said survives a save")
	check(not says(g2.dispatch("diaphragm")).contains(EXHALE), "not after a reload")
	var bad := g.to_dict()
	bad.rooms[ROOM].exhale_said = "yes"
	var g3 := GameSim.new()
	g3.from_dict(bad)
	check(r08(g3).state.exhale_said == false, "a malformed exhale_said loads false")
	# a later first look (band 4, the bulge): the band line, then the exhale
	var b4 := game_at(6, ROOM)
	check(says(b4.dispatch("diaphragm")) == "A finger's width further out than it was. I can see the bolts' threads. | " + EXHALE,
		"band 4 first look: bolts line, then the exhale")
	check(r08(b4).has_seen("bolts_out"), "band 4 first look still notes bolts_out")
	# not at the endings
	for which in ["sever", "continue"]:
		var en := ending_game(which)
		check(not says(en.dispatch("diaphragm")).contains(EXHALE), "%s: no exhale" % which)
		check(not r08(en).state.exhale_said, "%s: flag untouched" % which)
	# the bulge plate is new stage art and loads
	check(ResourceLoader.exists("res://assets/stages/R08/%s.png" % BULGE), "the bulge plate exists")
	for id in ["r08_boss_rest", "r08_boss_sunk", "r08_diaphragm_bulge"]:
		check(ResourceLoader.exists("res://assets/stages/R08/%s.png" % id), "%s exists" % id)
	check(not r08(game_at(5, ROOM)).bulging(), "band 3: not yet bulging")

# ---------------------------------------------------------------------------------------------
# (17) debug
# ---------------------------------------------------------------------------------------------
func test_debug() -> void:
	var a := game_at(4, ROOM)
	check(not a.flag("P11") and not r08(a).state.p11_complete, "debug_tide(4): P11 open")
	var b := game_at(5, ROOM)
	check(b.flag("P11") and r08(b).state.p11_complete and r08(b).has_seen("reference_respiration"), "debug_tide(5): P11 done")
	check(r08(b).state.toggles == SOLUTION, "debug_tide(5): the board in the loop")
	check("breathes_alone" in r08(b).state.notices and not "dust_lines" in r08(b).state.notices, "debug_tide(5): notices prepared")
	var expect := {0: [false, 2, ""], 1: [false, 2, ""], 2: [true, 2, ""], 3: [true, 3, ""], 4: [true, 4, ""],
		5: [true, 5, ""], 6: [true, 6, ""], 7: [true, 7, ""], 8: [true, 7, "sever"], 9: [true, 7, "continue"]}
	for n in expect:
		var g := GameSim.new()
		var r := r08(g)
		r.debug_jump(n)
		r = r08(g)
		check(g.state.room == ROOM, "jump %d in R08" % n)
		check(g.flag("P11") == expect[n][0], "jump %d P11 %s" % [n, expect[n][0]])
		check(g.weather_band() == expect[n][1], "jump %d band %d (got %d)" % [n, expect[n][1], g.weather_band()])
		check(r.ending() == expect[n][2], "jump %d ending '%s'" % [n, expect[n][2]])
		check(not r.current_notice() in r.state.notices or n in [1, 2], "jump %d: current notice still pending" % n)
		if n == 1:
			check(r.held() and r.state.index_offered and r.has_seen("index_hunger"), "jump 1 holds")
		if n == 2:
			check(r.has_seen("reference_respiration"), "jump 2 has reference_respiration")
	var ns := game_at(9, ROOM)
	for h in R08Sim.HOTSPOTS:
		check(says(ns.dispatch(h)) != "", "tide IX %s answers" % h)

# ---------------------------------------------------------------------------------------------
# (18) P01 untouched (tests/p01_smoke.gd runs in the suite; here, the gate still holds)
# ---------------------------------------------------------------------------------------------
func test_p01_untouched() -> void:
	var g := game_at(9, ROOM)
	check(g.flag("P01") and g.room("R02") != null, "P01 belongs to R02 and is still set by the office")
	var f := with_flags(["P01", "P02", "P03", "P06"], "R05")
	check(not f.room(ROOM).can_enter() and says(f.dispatch("go:R08")) == R08Sim.LOCKED, "sealed without P09")

# ---------------------------------------------------------------------------------------------
# P11: the tags are the key
# ---------------------------------------------------------------------------------------------
func test_valve_tags() -> void:
	check(R08Sim.VALVE_TAGS == REF_VALVE_TAGS, "toggles stamped 07, 12, 31, 44")
	# every toggle's number names exactly one tag on the ring, and that tag names its valve
	var used := []
	for v in VALVES:
		var num: String = REF_VALVE_TAGS[v]
		var hits := []
		for i in R08Sim.TAGS.size():
			if R08Sim.tag_number(i) == num:
				hits.append(i)
		check(hits.size() == 1, "tag No. %s hangs on the ring exactly once (got %s)" % [num, hits])
		if hits.size() == 1:
			var text: String = R08Sim.TAGS[hits[0]]
			check(text.begins_with("No. %s: %s " % [num, v]), "tag No. %s names %s ('%s')" % [num, v, text])
			check(R08Sim.valve_for_tag(num) == v, "valve_for_tag(%s) == %s" % [num, v])
			used.append(hits[0])
	var numbered := 0
	for i in R08Sim.TAGS.size():
		if R08Sim.tag_number(i) != "":
			numbered += 1
	check(numbered == 4 and used.size() == 4, "four valve tags, one per toggle: a 1:1 map")
	for line in REF_TAG_LINES:
		check(line in R08Sim.TAGS, "tag text exact: %s" % line)
	# the old tags keep their order, and the new brass is still last
	check(R08Sim.TAGS[R08Sim.TAG_LAST] == "18 OCT 31", "the stamped tag is last")
	check(R08Sim.TAGS.find("3 NOV 27. Fitted restraining bolts, twelve. Rim weeps oil. E.V.") < R08Sim.TAGS.find(
		"30 JAN 29. Replaced bolt 5, sheared. Sheared outward. E.V."), "dated tags in order")
	# the drawing is topology and bands only: no numbers, no line names, no warning words,
	# in its line, its notebook entry, its lens entry or the fault window printed on it
	check(R08Sim.DRAWING_LINE == REF_DRAWING, "DRAWING_LINE exact")
	var on_drawing := [R08Sim.DRAWING_LINE, R08Sim.OBSERVATIONS.drawing, R08Sim.OBSERVATIONS.lens_index_ink,
		R08Sim.OBJECTIVES.p11]
	for code in R08Sim.FAULT_NAMES:
		on_drawing.append("FAULT: " + R08Sim.FAULT_NAMES[code])
	for text in on_drawing:
		for n in LINE_NAMES:
			check(not text.contains(n), "the drawing never names %s: %s" % [n, text])
	for num in ["07", "12", "31", "44"]:
		check(not R08Sim.DRAWING_LINE.contains(num) and not R08Sim.OBSERVATIONS.drawing.contains(num)
			and not R08Sim.OBSERVATIONS.lens_index_ink.contains(num), "the drawing carries no valve number %s" % num)
	for text in [R08Sim.DRAWING_LINE, R08Sim.OBSERVATIONS.drawing]:
		check(not text.contains("SEALED") and not text.contains("NEVER FEED"), "the drawing's stub carries no words: %s" % text)
		for word in ["green", "brass", "brown", "hatched", "capped"]:
			check(text.to_lower().contains(word), "the drawing shows the %s band: %s" % [word, text])
	check(R08Sim.OBSERVATIONS.drawing.contains("STAIR GATE"), "the drawing keeps the stair gate box")
	check(R08Sim.OBSERVATIONS.drawing.ends_with(R08Sim.DRAWING_LINE.trim_prefix("From the pump, a green-banded run out to the stair gate, a brass run on, a brown run back. ")),
		"the notebook's drawing entry says what the drawing line says")
	# the board: the same bands on the valve heads, shuffled against the drawing
	check(R08Sim.VALVE_BANDS == REF_BANDS, "each valve's band matches its run")
	check(R08Sim.BOARD_ORDER == REF_BOARD_ORDER, "board order 44, 07, 31, 12")
	var nums := []
	for v in R08Sim.BOARD_ORDER:
		nums.append(R08Sim.VALVE_TAGS[v])
	check(nums == ["44", "07", "31", "12"], "the board reads 44, 07, 31, 12")
	check(R08Sim.OBSERVATIONS.valve_board.contains("No. 44, No. 07, No. 31, No. 12")
		and R08Sim.OBSERVATIONS.valve_board.contains("hatched navy, green, brown, brass"), "the notebook keeps the board's order and bands")
	var xs := []
	for v in R08Sim.BOARD_ORDER:
		xs.append(VIEW.C_SOCKETS[v])
	check(xs == [305.0, 495.0, 685.0, 875.0], "the view seats the toggles in board order")
	for h in VIEW.VALVE_CONTROLS:
		if (h[0] as String).begins_with("tog_"):
			var v: String = (h[0] as String).trim_prefix("tog_").to_upper()
			check((h[1] as Rect2).has_point(Vector2(VIEW.C_SOCKETS[v], VIEW.C_SOCKET_Y)) and h[2] == "Toggle No. " + R08Sim.VALVE_TAGS[v],
				"%s's control covers its socket and names its number" % h[0])
	var run_valves := []
	for run in VIEW.RUNS:
		run_valves.append(run[0])
	run_valves.sort()
	var sorted_valves := VALVES.duplicate()
	sorted_valves.sort()
	check(run_valves == sorted_valves, "the drawing bands one run per valve")
	# the hatched band leads to the tag that says 'Do not open.', and that is the valve to shut
	var hatched := ""
	for v in R08Sim.VALVE_BANDS:
		if R08Sim.VALVE_BANDS[v].begins_with("hatched"):
			hatched = v
	check(hatched == "INDEX" and "No. %s: INDEX resealed. Wire cut again. Do not open. E.V." % R08Sim.VALVE_TAGS[hatched] in R08Sim.TAGS
		and not SOLUTION[hatched], "the hatched head is 'Do not open.' and is the one left shut")
	# the hints never name a line either: names come from the tags alone
	for h in R08Sim.HINTS.p11:
		for n in LINE_NAMES:
			check(not h.contains(n), "P11 hint names no line: %s" % h)
	# reading the ring: each valve tag goes into the notebook with its number and line
	var g := game_at(4, ROOM)
	var r := r08(g)
	g.dispatch("repair_tags")
	for i in R08Sim.TAG_LAST:
		g.dispatch("tag_next")
	for v in VALVES:
		var id: String = "tag_" + REF_VALVE_TAGS[v]
		check(r.has_seen(id) and R08Sim.OBSERVATIONS[id].contains("No. " + REF_VALVE_TAGS[v]) and R08Sim.OBSERVATIONS[id].contains(v),
			"notebook keeps %s" % id)
	check(not g.flag("P11"), "reading the tags solves nothing")
	# the solution is unchanged: 07, 12 and 31 open, 44 shut, then PUMP
	g.dispatch("back")
	g.dispatch("valve_board")
	for v in VALVES:
		var open: bool = R08Sim.VALVE_TAGS[v] in ["07", "12", "31"]
		if r.state.toggles[v] != open:
			g.dispatch("tog_" + v.to_lower())
	check(r.state.toggles == SOLUTION, "07, 12, 31 open and 44 shut is the solution")
	g.dispatch("pump")
	check(g.flag("P11"), "then PUMP solves P11")
	# the hints start at the drawing
	check(R08Sim.HINTS.p11[0].contains("drawing") and R08Sim.HINTS.p11 == REF_HINTS, "hints start at the drawing")

func test_way_in_hint() -> void:
	check(R08Sim.WAY_IN_HINT == "The hatch in the kitchen floor is open: the laboratory and the machine room.", "WAY_IN_HINT exact")

# ---------------------------------------------------------------------------------------------
# the view (presentation only)
# ---------------------------------------------------------------------------------------------
const VIEW := preload("res://game/rooms/R08/R08_view.gd")

## The view's breath envelopes are the audio contract's keyframes, eased the same way.
func test_view_static() -> void:
	check(is_equal_approx(VIEW.envelope(VIEW.BREATH_CYCLE, 0.0), 0.0), "cycle breath starts empty")
	check(is_equal_approx(VIEW.envelope(VIEW.BREATH_CYCLE, 3.6), 1.0), "cycle breath is full at 3.6 s")
	check(is_equal_approx(VIEW.envelope(VIEW.BREATH_CYCLE, 3.8), 1.0), "cycle breath holds full to 4.0 s")
	check(is_equal_approx(VIEW.envelope(VIEW.BREATH_CYCLE, 6.4), 0.15), "cycle breath at the hitch is 0.15")
	check(is_equal_approx(VIEW.envelope(VIEW.BREATH_CYCLE, 1.8), 0.5), "cosine easing: half way is half")
	check(is_equal_approx(VIEW.envelope(VIEW.BREATH_NORA, 0.7), 0.45), "Nora's first short rise")
	check(is_equal_approx(VIEW.envelope(VIEW.BREATH_NORA, 6.6), 1.0), "Nora's long rise")
	check(is_equal_approx(VIEW.envelope(VIEW.BREATH_EVEN, 4.0), 0.8), "the even breath peaks at 0.8")
	check(is_equal_approx(VIEW.envelope(VIEW.BREATH_EVEN, 12.0), 0.8), "envelopes repeat every 8 s")
	# the hitch: the machine runs x0.2 from 6.4 to 7.6 s, and the crank still turns once per cycle
	check(is_equal_approx(VIEW.machine_units(6.4), 6.4), "machine time is real time before the hitch")
	check(is_equal_approx(VIEW.machine_units(7.6), 6.64), "machine time crawls through the hitch")
	check(is_equal_approx(VIEW.machine_units(8.0), VIEW.CYCLE_UNITS), "one cycle is CYCLE_UNITS of machine time")
	# every audio id the view levels is a file the audio team built
	for id in VIEW.SFX_DB:
		check(ResourceLoader.exists("res://assets/audio/R08/%s.wav" % id), "R08 one-shot %s exists" % id)
	for id in VIEW.LOOPS:
		check(ResourceLoader.exists("res://assets/audio/R08/%s.wav" % id), "R08 loop %s exists" % id)
	for id in VIEW.SFX_SOFT:
		check(VIEW.SFX_DB.has(id), "soft sound %s has a level" % id)
	# hotspots and close-up controls stay on the canvas, at least 64 px, and the order puts the
	# small objects on the column before the belt that covers them
	var ids := []
	for h in VIEW.HOTSPOTS:
		ids.append(h[0])
	check(ids.find("repair_tags") < ids.find("belt") and ids.find("nameplate") < ids.find("belt"),
		"tags and nameplate are matched before the belt")
	for table in [VIEW.VALVE_CONTROLS, VIEW.TAG_CONTROLS]:
		for h in table:
			var r: Rect2 = h[1]
			check(CANVAS.encloses(r) and r.size.x >= 64 and r.size.y >= 64, "control %s is on canvas and >= 64 px" % h[0])

## The belt drop's silence, driven frame by frame from the view's own hooks.
func test_view_drop() -> void:
	var scene = await _scene_at(0)
	var v = scene.room_view
	check(not "DUCK_IDS" in load("res://game/rooms/R08/R08_view.gd").get_script_constant_map(), "the old breath_alone duck is gone")
	scene.dispatch("valve_board")
	for t in ["tog_supply", "tog_gate", "tog_return", "tog_index"]:
		scene.dispatch(t)
	scene.dispatch("pump")
	await process_frame
	v.on_sfx("belt_drop")
	check(v.drop_t == 0.0 and is_equal_approx(v.drop_in, 0.25), "belt_drop starts the duck over 0.25 s")
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < 0.3:
		v._tick_audio(dt)
		t += dt
	for id in VIEW.LOOPS:
		check(v.mixer.mix.get(id, 0.0) <= db_to_linear(-59.0), "after 0.25 s %s is at -60 dB (%f)" % [id, v.mixer.mix.get(id, 0.0)])
	check(v.drop_silent(), "the room is held silent")
	while t < 1.6:
		v._tick_audio(dt)
		t += dt
	check(v.drop_silent(), "still silent 1.6 s after the drop")
	v.on_sfx("breath_alone")
	var target: float = v.loop_targets()["r08_breath"]
	t = 0.0
	while t < 1.05:
		v._tick_audio(dt)
		t += dt
	check(absf(v.mixer.mix["r08_breath"] - target) < 0.01, "r08_breath back to its target in 1.0 s")
	check(v.mixer.mix["r08_room"] <= db_to_linear(-59.0), "the other loops stay down while the reveal's lines remain")
	check(v.room_back_t < 0.0, "the room waits for the last line")
	# the last line goes up: the room comes back over 3.0 s
	scene.lines = scene.lines.filter(func(l): return int(l.click) != v.reveal_click)
	v._tick_audio(dt)
	check(v.room_back_t >= 0.0, "the room starts back after the last line")
	t = 0.0
	while t < 1.5:
		v._tick_audio(dt)
		t += dt
	var room_target: float = v.loop_targets()["r08_room"]
	var mid: float = v.mixer.mix["r08_room"]
	check(mid > db_to_linear(-59.0) and mid < room_target, "half way back at 1.5 s (%f)" % mid)
	while t < 3.1:
		v._tick_audio(dt)
		t += dt
	check(v.drop_t < 0.0 and absf(v.mixer.mix["r08_room"] - room_target) < 0.01, "back at target after 3.0 s")
	# Soften sudden sounds: a gentler 0.6 s duck
	scene.sim.settings.soft_audio = true
	v.on_sfx("belt_drop")
	check(is_equal_approx(v.drop_in, 0.6), "soft audio ducks over 0.6 s")
	v._tick_audio(0.25)
	check(v.mixer.mix["r08_room"] > db_to_linear(-59.0), "soft duck still on its way down at 0.25 s")
	scene.sim.settings.soft_audio = false
	v.apply_instantly()
	check(v.drop_t < 0.0, "apply_instantly clears the duck")
	await free_scene(scene)

## SILENCE: {fx hold_breath} waits for the last line's delay, then holds every loop silent
## for 1.8 s with the membrane and wheels still, and lets go; soft audio ducks more gently.
func test_view_hold_breath() -> void:
	var scene = await _scene_at(0)
	var v = scene.room_view
	var dt := 1.0 / 60.0
	for id in VIEW.LOOPS:
		v.mixer.mix[id] = float(v.loop_targets().get(id, 0.0))
	v.play_fx("hold_breath", {"type": "fx", "id": "hold_breath", "seconds": 1.8, "delay": 0.5})
	check(is_equal_approx(v.hb_wait, 0.5) and v.hb_t < 0.0 and is_equal_approx(v.hb_len, 1.8), "armed for its delay")
	var t := 0.0
	while t < 0.45:
		v.tick(dt)
		t += dt
	check(v.hb_t < 0.0 and v.hold_breath_gain() == 1.0, "nothing held before the line")
	check(v.mixer.mix["r08_breath"] > db_to_linear(-59.0), "the breath still sounds before the line")
	while t < 0.5 + VIEW.HB_IN + 0.05:
		v.tick(dt)
		t += dt
	check(v.hold_breath_silent(), "the line opens the held breath")
	for id in VIEW.LOOPS:
		check(v.mixer.mix.get(id, 0.0) <= db_to_linear(-59.0), "held: %s is silent (%f)" % [id, v.mixer.mix.get(id, 0.0)])
	var mem: float = v.v
	var fly: float = v.fly_a
	while t < 0.5 + 1.7:
		v.tick(dt)
		t += dt
	check(v.hold_breath_silent(), "still held 1.7 s in")
	check(is_equal_approx(v.v, mem) and absf(v.fly_a - fly) < 0.001, "the membrane and the flywheel hold still")
	for id in VIEW.LOOPS:
		check(v.mixer.mix.get(id, 0.0) <= db_to_linear(-59.0), "1.7 s in: %s still silent" % id)
	while t < 0.5 + 1.8 + VIEW.HB_OUT + 0.1:
		v.tick(dt)
		t += dt
	check(v.hb_t < 0.0, "the held breath lets go")
	var target: float = v.loop_targets()["r08_breath"]
	check(absf(v.mixer.mix["r08_breath"] - target) < 0.05, "the breath is back (%f of %f)" % [v.mixer.mix["r08_breath"], target])
	# Soften sudden sounds: the duck takes HB_IN_SOFT, not a cut
	scene.sim.settings.soft_audio = true
	for id in VIEW.LOOPS:
		v.mixer.mix[id] = float(v.loop_targets().get(id, 0.0))
	v.play_fx("hold_breath", {"type": "fx", "id": "hold_breath", "seconds": 1.8, "delay": 0.0})
	check(v.hold_breath_silent() and is_equal_approx(v.hb_in, VIEW.HB_IN_SOFT), "soft audio: a 0.5 s duck")
	v._tick_audio(0.0)
	v.hb_t = 0.2
	v._tick_audio(dt)
	check(v.mixer.mix["r08_breath"] > db_to_linear(-59.0), "soft duck still on its way down at 0.2 s")
	scene.sim.settings.soft_audio = false
	v.apply_instantly()
	check(v.hb_t < 0.0 and v.hb_wait < 0.0, "apply_instantly clears the held breath")
	# the real commit arms it at the last line's time
	scene.room_jump(ROOM, 0)
	await process_frame
	v = scene.room_view
	scene.dispatch("valve_board")
	for tg in ["tog_supply", "tog_gate", "tog_return", "tog_index"]:
		scene.dispatch(tg)
	scene.dispatch("pump")
	await process_frame
	await process_frame
	var last_due := INF
	for l in scene.lines:
		if l.text == R08Sim.REVEAL_LAST_SAY:
			last_due = l.due
	# Core p1: hold_breath is a core timed fx (CORE_TIMED_FX): the core holds it in
	# pending_fx and hands it to the view (play_fx) at its moment, the last line's.
	var fx_in := -1.0
	for p in scene.pending_fx:
		if p[0].get("id", "") == "hold_breath":
			fx_in = float(p[1])
	var armed: float = fx_in if fx_in > 0.0 else float(v.hb_wait)
	check(armed > 0.0 and absf((scene.time + armed) - last_due) < 0.1,
		"PUMP arms the held breath for the last line (in %f, line at %f)" % [armed, last_due - scene.time])
	# ... and the view's own hold starts when the core delivers it.
	for i in 200:
		if v.hb_t >= 0.0 or v.hold_breath_silent():
			break
		scene._process(0.1)
	check(v.hb_t >= 0.0 or v.hold_breath_silent(), "the view's held breath runs once the core delivers it")
	await free_scene(scene)

func _scene_at(n: int) -> Node:
	var scene = new_scene("user://room_test_R08_view.json")
	await process_frame
	scene.room_jump(ROOM, n)
	await process_frame
	return scene

func test_view_live() -> void:
	# arrival: driven, labels hidden behind the belt, the driven loops up
	var scene = await _scene_at(0)
	var v = scene.room_view
	check(v.label_for("nameplate") == "Behind the belt", "before P11 the nameplate is 'Behind the belt'")
	check(v.label_for("repair_tags") == "Tags behind the belt", "before P11 the tags are behind the belt")
	var t: Dictionary = v.loop_targets()
	check(t["r08_cycle"] > 0.0 and t["r08_breath"] > 0.0 and t["r08_hold"] == 0.0, "arrival: cycle and breath loops")
	check(v.belts() == [true, true, true], "arrival: every belt runs")
	check(v.exits_active(), "arrival: exits live")
	# the notice glance (the flywheel's): a soft surround that fades in and out, no frame
	var was_motion: bool = v.motion
	v.motion = true
	v._start_hold("cycle_pause")
	check(v.hold_active() and v.focus_alpha() == 0.0, "the glance starts unfocused")
	v.hold_t = v.HOLD_TIME / 2.0
	check(is_equal_approx(v.focus_alpha(), 1.0), "mid-glance the surround is full")
	v.hold_t = v.FOCUS_OUT * 0.25
	check(v.focus_alpha() < 0.25, "the surround fades out before the glance ends")
	v.hold_t = 0.0
	check(v.focus_alpha() == 0.0, "after the glance nothing frames the flywheel")
	var src: String = (v.get_script() as Script).source_code
	var body := src.substr(src.find("func _draw_focus"))
	body = body.substr(0, body.find("\nfunc ", 1))
	check(not body.contains(", false, "), "_draw_focus strokes no frame round the object")
	v.motion = was_motion
	# the valve board: controls, Back, Esc
	scene.dispatch("valve_board")
	await process_frame
	check(v.back_visible() and v.esc_action() == "back", "c_valves: Back and Esc go back")
	check(not v.exits_active(), "c_valves: no exits")
	check(v.action_at(Vector2(305, 750)) == "tog_index", "c_valves: No. 44 is the first toggle")
	check(v.action_at(Vector2(495, 750)) == "tog_supply", "c_valves: SUPPLY toggle answers")
	check(v.action_at(Vector2(1200, 800)) == "pump", "c_valves: PUMP answers")
	check(v.action_at(Vector2(1060, 830)) == "preview", "c_valves: PREVIEW answers")
	check(v.action_at(Vector2(700, 300)) == "look_drawing", "c_valves: the drawing answers")
	check(v.hover_at(Vector2(875, 750)) == "tog_gate", "c_valves: hover mirrors the click")
	check(v.label_for("tog_gate") == "Toggle No. 12", "c_valves: hover label is the stamped number")
	# SUPPLY open with INDEX open: the hold
	scene.dispatch("tog_supply")
	await process_frame
	t = v.loop_targets()
	check(t["r08_hold"] > 0.0 and t["r08_cycle"] == 0.0 and t["r08_breath"] == 0.0, "held: only the hold loop breathes")
	await create_timer(0.8).timeout
	check(v.hold_k > 0.9 and v.v > 0.9, "held: the membrane eases full and stays")
	var fly: float = v.fly_a
	for i in 10:
		await process_frame
	check(is_equal_approx(v.fly_a, fly), "held: the flywheel is frozen")
	# the trace is cleared by a toggle and drawn by PREVIEW
	scene.dispatch("tog_index")
	scene.dispatch("preview")
	await process_frame
	check(v._shown_trace() == "gate_shut", "PREVIEW traces the current circuit")
	scene.dispatch("tog_gate")
	await process_frame
	check(v._shown_trace() == "", "a toggle clears the trace")
	# the commit: the close-up stays on screen, exits wait for the belt, then the room settles
	scene.dispatch("tog_return")
	scene.dispatch("pump")
	await process_frame
	check(v.reveal_t >= 0.0, "P11 starts the reveal")
	# the hold's story lines were still queued: the reveal flushes them and keeps its own times
	var held_left := false
	var first_due := INF
	for l in scene.lines:
		if l.text in ["It's holding its breath. Like it's listening.", "Everything stopped. Behind me, the flywheel too."]:
			held_left = true
		if l.text == "It takes. The gate line's holding pressure.":
			first_due = l.due
	check(not held_left, "the reveal flushes the hold's pending lines")
	check(absf(first_due - (scene.time + R08Sim.REVEAL_FIRST_SAY)) < 0.1, "the reveal's first line keeps its own time")
	for l in scene.lines:
		if l.text == "One of the belts is stopping.":
			check(absf(l.due - first_due - 3.0) < 0.05, "the belt line lands with the belt")
	check(not v.exits_active(), "no exits while the belt is still stopping")
	check(v.action_at(Vector2(700, 300)) == "", "the room isn't clickable under the fading close-up")
	check(v.belts() == [true, true, true], "the room is drawn driven before the drop")
	v.apply_instantly()
	check(v.reveal_t < 0.0 and v.belts() == [true, false, true], "apply_instantly ends the reveal at the stopped belt")
	check(v.exits_active(), "exits back once the reveal is done")
	check(v.label_for("nameplate") == "Nameplate", "after P11 the nameplate is named")
	check(v.nameplate_alpha() == 1.0, "after P11 the nameplate is engraved at full contrast")
	check(v.dust_layers() == [["dust_streaks", 1.0]], "after P11 the dragged dust is a still at full alpha")
	t = v.loop_targets()
	check(t["r08_cycle"] == 0.0 and t["r08_cycle_two"] > 0.0 and is_equal_approx(t["r08_breath"], 0.75),
		"after P11: the pump cycle and the breath alone")
	await free_scene(scene)
	await test_view_drop()
	# the tags: arrows hidden at the ends
	scene = await _scene_at(2)
	v = scene.room_view
	scene.dispatch("repair_tags")
	await process_frame
	check(v.action_at(Vector2(240, 500)) == "", "c_tags: no Previous on the first tag")
	check(v.action_at(Vector2(1200, 500)) == "tag_next", "c_tags: Next answers")
	for i in R08Sim.TAG_LAST:
		scene.dispatch("tag_next")
	await process_frame
	check(v.action_at(Vector2(1200, 500)) == "", "c_tags: no Next on the last tag")
	check(v.action_at(Vector2(240, 500)) == "tag_prev", "c_tags: Previous answers")
	await free_scene(scene)
	# escalation loops and hotspots that never move
	var expect := {5: "r08_breath_nora", 6: "r08_late", 7: "r08_late", 8: "r08_drip", 9: "r08_breath_even"}
	for n in expect:
		scene = await _scene_at(n)
		v = scene.room_view
		t = v.loop_targets()
		check(t[expect[n]] > 0.0, "stage %d plays %s" % [n, expect[n]])
		check(t["r08_cycle"] == 0.0, "stage %d: no driven cycle" % n)
		check(v.dev_rects().size() == VIEW.HOTSPOTS.size(), "stage %d: every hotspot rect is live" % n)
		await free_scene(scene)
	# every later visit keeps the fan of dust and the plate; from band 6 the surface holds the horizon
	for n in range(2, 8):
		scene = await _scene_at(n)
		v = scene.room_view
		var layers: Array = v.dust_layers()
		var fan := false
		for l in layers:
			fan = fan or (l[0] in ["dust_streaks", "dust_lines"] and l[1] == 1.0)
		check(fan, "stage %d: the dust fan is drawn still at full alpha (%s)" % [n, layers])
		check(v.nameplate_alpha() == 1.0, "stage %d: the nameplate at full alpha" % n)
		check((v.r.reflection_mode() == "late") == (n >= 6), "stage %d: the horizon only from band 6" % n)
		check(v._tex("a_surface_horizon_b6") != null, "the horizon plate loads")
		await free_scene(scene)

## The P11 reveal is timed on RoomView.time (the core's story clock), never on frame dt or
## game.time: a tick whose clock does not move leaves it where it is.
func test_view_reveal_clock() -> void:
	var src: String = (VIEW as Script).source_code
	check(not src.contains("reveal_t +="), "reveal_t is not summed from dt")
	check(not src.contains("reveal_t0 = game.time") and src.contains("reveal_t0 = time"), "the reveal starts on RoomView.time")
	var scene = await _scene_at(0)
	var v = scene.room_view
	v.play_fx("p11_reveal", {})
	var t0: float = v.time
	check(v.reveal_t == 0.0 and v.reveal_t0 == t0, "the reveal starts at RoomView.time")
	# frames with no clock: however large dt is, the reveal holds
	for i in 5:
		v.tick(2.0)
	check(v.reveal_t == 0.0, "ticks without RoomView.time moving hold the reveal (%f)" % v.reveal_t)
	check(v.belts() == [true, true, true] and not v.exits_active(), "still before the drop")
	# the clock moves: the reveal follows it exactly
	for i in 8:
		scene._process(0.25)
	check(v.time > t0 and absf(v.reveal_t - (v.time - t0)) < 0.0001,
		"reveal_t reads RoomView.time (%f vs %f)" % [v.reveal_t, v.time - t0])
	var at: float = v.reveal_t
	v.tick(5.0)
	check(is_equal_approx(v.reveal_t, at), "a stray dt after the clock moved changes nothing")
	# and ends on it
	while v.time - t0 < VIEW.RV_END + 0.1:
		scene._process(0.5)
	check(v.reveal_t < 0.0, "the reveal ends at RV_END on RoomView.time")
	await free_scene(scene)

## The boss's two-frame breath and the band 4+ bulge, in the view.
func test_view_breathing_boss() -> void:
	var scene = await _scene_at(2)
	var v = scene.room_view
	var was: bool = scene.sim.settings.motion
	check(v._tex("r08_boss_rest") != null and v._tex("r08_boss_sunk") != null, "the boss frames load from assets/stages/R08")
	check(v._tex("r08_boss_sunk").get_size() == Vector2(400, 400), "the boss frames register on the membrane sprite")
	scene.sim.settings.motion = true
	v.v = 0.0
	check(v.boss_sink() == 0.0, "breathed out: the boss at rest")
	v.v = 1.0
	check(v.boss_sink() == 1.0, "drawn in: the boss sunk")
	v.v = 0.5
	var mid: float = v.boss_sink()
	check(mid > 0.0 and mid < 1.0, "the swap crosses with the breath")
	scene.sim.settings.motion = false
	check(not v.motion, "Motion & flicker off")
	for x in [0.0, 0.3, 1.0]:
		v.v = x
		check(v.boss_sink() == 1.0, "Motion off holds the boss drawn in (v %f)" % x)
	scene.sim.settings.motion = was
	check(not v.r.bulging() and v.r.stage_plate() == "room", "P11 at band 2: no bulge yet")
	await free_scene(scene)
	for n in [4, 7, 9]:
		scene = await _scene_at(n)
		v = scene.room_view
		check(v.r.bulging() and v.r.stage_plate() == BULGE, "stage %d bulges" % n)
		var plate = v._tex(v.r.stage_plate())
		check(plate != null and plate.get_size() == Vector2(1448, 1086), "stage %d: the bulge plate loads at native size" % n)
		check(v._tex("r08_diaphragm_bulge") != null, "the bulge overlay loads")
		check(v.dev_rects().size() == VIEW.HOTSPOTS.size(), "stage %d: every hotspot stays live" % n)
		await free_scene(scene)
	scene = await _scene_at(8)
	check(not scene.room_view.r.bulging() and scene.room_view.r.stage_plate() == "room_sever", "sever: slack, no bulge")
	await free_scene(scene)
