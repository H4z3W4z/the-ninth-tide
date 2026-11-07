extends "res://tests/rooms/room_test_base.gd"
## The canonical completion graph, title to both endings, on one GameSim.
## Built rooms are played by their own actions; puzzles in rooms not yet built are
## committed with game.solve() (flags only), always while standing in their room after
## walking there by open exits. Every gate is asserted on the way: each room opens at
## exactly the puzzle that opens it, the tide and weather band advance only on their
## puzzles, and every puzzle's prerequisites are behind her when it is committed.
## Items an unbuilt room would hand out are given at that room's step.
## Extend PLAYED (and play_<pid>) as each wave lands a room. Run after an import:
##   godot --headless --path . --script tests/chain_test.gd
##
## Wave 1 (Tide I hub): R01, R02, R03 and R04 are played: P01, the drawer (P03 part 1),
## P02, P03, T1X, P04, P05, P06 (and the service door), P17, P19, P20, P21.

## [step, room, prerequisites] in canonical order (flags.md section 2, GDD section 5,
## T1X-closure.md: the corridor opens on P01 and T1X waits for tide_done(1)).
const GRAPH := [
	["P01", "R02", []],
	["P03a", "R02", ["P01"]],
	["P02", "R04", ["P01"]],
	["P03", "R03", ["P01"]],
	["T1X", "R02", ["P01", "P02", "P03"]],
	["P04", "R03", ["P02", "P03", "closure_report_filed", "t1x_threshold_crossed"]],
	["P05", "R03", ["P04"]],
	["P06", "R01", ["P05"]],
	["P07", "R05", ["P06"]],
	["P08", "R06", ["P06"]],
	["P09", "R05", ["P07", "P08"]],
	["P10", "R07", ["P09"]],
	["P11", "R08", ["P09"]],
	["P12", "R11", ["P10", "P11"]],
	["P13", "R07", ["P12"]],
	["P14", "R07", ["P13"]],
	["P15", "R09", ["P14"]],
	["P16", "R10", ["P15"]],
	["P17", "R04", ["P16"]],
	["P18", "R10", ["P16"]],
	["P19", "R04", ["P17", "P18"]],
	["P20", "R02", ["P17", "P18"]],
	["P21", "R03", ["P19", "P20"]],
	["P22", "R06", ["P21"]],
	["P23", "R10", ["P21"]],
	["P24", "R11", ["P22", "P23"]],
	["P25", "R12", ["P24"]],
	["P26", "R12", ["P25"]],
	["P27", "R12", ["P26"]],
]

## The step after which each room first becomes reachable from the office ("" = from the start).
## R05/R06 also need the service door, opened in play_p06 right after P06.
const OPENS := {"R01": "", "R02": "", "R03": "P01", "R04": "P01", "R11": "P04", "R05": "P06",
	"R06": "P06", "R07": "P09", "R08": "P09", "R09": "P12", "R10": "P15", "R12": "P24"}

## Tide and weather band once each step is committed.
const TIDE_AFTER := {"P01": 1, "P03a": 1, "P02": 1, "P03": 1, "T1X": 2, "P04": 2, "P06": 3,
	"P09": 4, "P12": 5, "P15": 6, "P17": 6, "P18": 7, "P21": 8, "P24": 9, "P27": 9}
const BAND_AFTER := {"T1X": 0, "P06": 1, "P09": 2, "P12": 3, "P15": 4, "P18": 5, "P21": 6,
	"P24": 7, "P27": 7}

## Steps played by their room's real actions (everything else: flags only).
const PLAYED := ["P01", "P03a", "P02", "P03", "T1X", "P04", "P05", "P06", "P17", "P19", "P20", "P21"]

## Items a not-yet-built room hands out at its step (flags.md section 4).
const GIVES := {"P16": ["contact_sheet"], "P18": ["venn_correspondence"]}

var g: GameSim
var office: R02Sim
var chart: R03Sim
var listen: R04Sim
var jetty: R01Sim

func run_tests() -> void:
	g = GameSim.new()
	office = g.room("R02")
	chart = g.room("R03")
	listen = g.room("R04")
	jetty = g.room("R01")
	check(g.view == "title" or office.view == "title", "the game starts on the title")
	g.dispatch("begin")
	check(g.state.started and g.state.room == "R02" and g.tide() == 1 and g.weather_band() == 0,
		"begin: in the office, tide I, band 0")
	_check_reach("")
	var tide := 1
	var band := 0
	for step in GRAPH:
		var pid: String = step[0]
		var rid: String = step[1]
		for p in step[2]:
			check(g.flag(p), "%s: prerequisite %s is behind her" % [pid, p])
		check(not _done(pid), "%s not done before its step" % pid)
		_walk_to(rid)
		check(g.state.room == rid, "%s: walked to %s by open exits (at %s)" % [pid, rid, g.state.room])
		if pid in PLAYED:
			call("play_" + pid.to_lower())
		else:
			var ev: Array = []
			g.solve(pid, ev)
			g.solve(pid, ev)  # idempotent re-commit
			for item in GIVES.get(pid, []):
				g.give(item)
			if pid == "P26":
				g.save_checkpoint()
		check(_done(pid), "%s committed" % pid)
		tide = TIDE_AFTER.get(pid, tide)
		band = BAND_AFTER.get(pid, band)
		check(g.tide() == tide, "after %s: tide %d (got %d)" % [pid, tide, g.tide()])
		check(g.weather_band() == band, "after %s: weather band %d (got %d)" % [pid, band, g.weather_band()])
		check(g.plan_unlocked() == g.flag("P05"), "after %s: the plan follows P05" % pid)
		_check_reach(pid)
		_check_save(pid)
	_endings()

# ---------------------------------------------------------------------------
# Tide I
# ---------------------------------------------------------------------------
## R02 P01, played: supply OFF, curved C refused, straight B fitted, supply ON.
func play_p01() -> void:
	var ev := g.dispatch("go:R03")
	check(g.state.room == "R02" and says(ev) == "The corridor is pitch black. Light first.",
		"before P01: the corridor is dark")
	office.dispatch("papers")
	office.dispatch("read_contract")
	office.dispatch("back")
	office.dispatch("lamp")
	check(office.view == "repair", "P01: the lamp opens the repair")
	office.dispatch("toggle_supply")
	office.dispatch("select_c")
	office.dispatch("fit")
	check(not g.flag("P01"), "P01: the curved spare is refused")
	office.dispatch("select_b")
	office.dispatch("fit")
	office.dispatch("toggle_supply")
	check(g.flag("P01") and office.view == "room", "P01: supply on with B seated")
	check(not g.room_open("R05") and not g.room_open("R11"), "P01 opens nothing past the corridor")
	check(g.exit_open("R02", "R03") and g.exit_open("R02", "R04"), "P01 unlocks the corridor exits")
	check(office.exit_block("R03") == "" and office.exit_block("R04") == "",
		"P01: the office no longer holds the corridor (T1X re-time)")
	ev = g.dispatch("go:R05")
	check(g.state.room == "R02" and says(ev) == R02Sim.SERVICE_NO_KEY, "the service door stays shut before P06")

## R02 drawer (P03 part 1): log, prints, 1852; the sheet and lens. The log waits for Tide I.
func play_p03a() -> void:
	office.dispatch("logbook")
	office.dispatch("back")
	office.dispatch("puddle")
	office.dispatch("drawer")
	_turn(office, "drawer_dial", "dial_", [1, 8, 5, 2])
	office.dispatch("try_drawer")
	check(office.state.drawer_open, "drawer: 1852 opens it")
	office.dispatch("back")
	check(g.has_item("venn_tide_sheet") and g.has_item("inspection_lens"), "drawer: his tide sheet and the lens")
	office.dispatch("logbook")
	office.dispatch("back")
	check(not office.state.log_rewritten, "drawer: the log does not rewrite before Tide I's instruments")
	office.dispatch("chair")
	check(not office.state.seat_wet, "drawer: the chair stays dry before Tide I's instruments")

func _done_p03a() -> bool:
	return office.state.drawer_open

## R04 P02: the cylinder bands C-A-B at I, III, II, then PLAY.
func play_p02() -> void:
	g.dispatch("spindle")
	for b in ["C", "A", "B"]:
		g.dispatch("tray_" + b)
	var rots := {"C": 0, "A": 2, "B": 1}
	for b in ["C", "A", "B"]:
		var k: int = listen.state.spindle.find(b)
		for i in posmod(int(rots[b]) - int(listen.state.band_rot[b]), 3):
			g.dispatch("rot_up_%d" % k)
	var ev := g.dispatch("play")
	check(g.flag("P02") and listen.has_seen("calibration_zero"), "P02: the recording gives the zero")
	check(not has_ev(ev, "fx", "tide"), "P02 alone does not finish Tide I")
	g.dispatch("back")

## R03 P03 part 2: Venn's sheet registered on base 17, north up, lighthouse; clipped.
func play_p03() -> void:
	var ev := g.dispatch("recorder")
	ev = g.dispatch("rec_calibrate")
	check(not g.flag("P04") and says(ev) == "It won't pull. Not with his seal across it.",
		"P04 before the threshold: sealed")
	g.dispatch("back")
	ev = g.dispatch("clip_tin")
	check(g.has_item("chart_clips"), "P03: the clips from the tin")
	g.dispatch("sheet_table")
	g.dispatch("reg_lay")
	g.dispatch("reg_base_17")
	var guard := 0
	while int(chart.state.reg_rot) != 0 and guard < 8:
		g.dispatch("reg_rot_cw")
		guard += 1
	g.dispatch("reg_snap_lighthouse")
	ev = g.dispatch("reg_clip")
	check(g.flag("P03") and g.tide_done(1), "P03: the composite closes Tide I's instruments")
	check(not g.has_item("venn_tide_sheet") and g.has_item("chart_clips"), "P03: sheet taken, clips kept")
	check("The office will want to know." in says(ev), "P03: the office line")
	check(g.tide() == 1, "P03: tide I holds until the threshold")
	g.dispatch("back")

## R02 T1X, played: reread, chair, closure report, threshold, Go on.
func play_t1x() -> void:
	check(not g.flag("closure_report_filed"), "T1X: the report is not filed yet")
	var ev := office.dispatch("logbook")
	check(office.state.log_rewritten, "T1X: with Tide I done the log rewrites itself")
	office.dispatch("back")
	office.dispatch("chair")
	check(office.state.seat_wet, "T1X: the chair is wet")
	ev = office.dispatch("door")
	check("Latched" in says(ev) and g.state.room == "R02", "T1X: the room keeps her before the report")
	ev = g.dispatch("go:R03")
	check(g.state.room == "R02", "T1X: no way out to the chart room during the report")
	office.dispatch("papers")
	check(office.view == "report", "T1X: the papers open the closure report (view %s)" % office.view)
	_turn(office, "report_fields", "field_", R02Sim.REPORT_ANSWER)
	_turn(office, "report_time", "rtime_", R02Sim.REPORT_TIME_ANSWER)
	office.dispatch("file_report")
	check(g.flag("closure_report_filed"), "T1X: the closure report is filed")
	check(g.tide() == 1, "T1X: tide I holds until the threshold")
	office.dispatch("back")
	office.dispatch("door")
	check(office.view == "threshold", "T1X: the corridor door opens on the threshold")
	office.dispatch("continue")
	check(not g.flag("t1x_turned"), "T1X: held still")
	ev = office.dispatch("end_continue")
	check(g.flag("t1x_threshold_crossed") and has_ev(ev, "fx", "tide"), "T1X: crossed; the Tide II card")
	check(g.state.room == "R03", "T1X: Go on lands her in the chart room")

## R03 P04: zero 4 (from the recording), interval 3 (from the composite), pull.
func play_p04() -> void:
	g.dispatch("recorder")
	g.dispatch("rec_seal")
	_wheel("zero", "rec_zero_down", R03Sim.ZERO_ANSWER)
	_wheel("interval", "rec_int_up", R03Sim.INTERVAL_ANSWER)
	var ev := g.dispatch("rec_calibrate")
	check(g.flag("P04") and has_ev(ev, "fx", "drum_turn"), "P04: the drum turns")
	check(g.exit_open("R03", "R11"), "P04: the hatch exit opens")
	g.dispatch("back")

## R03 P05: look down the stair, then BOUNDARY, RELATION, OBSERVER, RECORD.
func play_p05() -> void:
	g.dispatch("hatch")
	g.dispatch("back")
	g.dispatch("recorder")
	var order := ["boundary", "relation", "observer"]
	for i in 3:
		g.dispatch("rec_plate_" + order[i])
		g.dispatch("rec_slot_%d" % i)
	g.dispatch("rec_record")
	check(g.flag("P05"), "P05: recorded")
	check(g.value("p05_trace") == ["interval_set", "hatch_opened", "stair_looked"],
		"P05 freezes the golden-path trace (%s)" % [g.value("p05_trace")])
	check(chart.strip_lines()[-1] == "COLLECTION ANSWERS. ATTEND JETTY.", "P05: the strip sends her to the jetty")
	g.dispatch("back")

# ---------------------------------------------------------------------------
# Tide II
# ---------------------------------------------------------------------------
## R01 P06: the boat through the lens, ring the unverified tally, the capsule; then the
## kitchen key at the office's service door.
func play_p06() -> void:
	for a in ["launch", "item:inspection_lens", "launch", "peer", "back", "panel", "tally_unverified"]:
		g.dispatch(a)
	check(not g.flag("P06"), "P06: not before the bell")
	var ev := g.dispatch("bell_2")
	check(g.flag("P06") and has_ev(ev, "fx", "tide"), "P06: the boat withdraws; the Tide III card")
	for a in ["back", "line", "cap", "key", "note", "back"]:
		g.dispatch(a)
	check(g.has_item("service_key") and jetty.has_seen("venn_address_note"), "P06: the key and Venn's note")
	check(g.has_item("inspection_lens"), "the lens is durable")
	_walk_to("R02")
	ev = g.dispatch("go:R05")
	check(g.state.room == "R02" and says(ev).begins_with("Locked."), "the service door: locked with the key held")
	office.dispatch("turn")
	office.dispatch("item:service_key")
	office.dispatch("service_door")
	check(not g.has_item("service_key") and office.state.service_unlocked, "the key is spent at the service door")
	office.dispatch("turn")
	_walk_to("R01")

# ---------------------------------------------------------------------------
# Tides VI-VII
# ---------------------------------------------------------------------------
## R04 P17: the session spool on the mixer, offset -2, each voice alone.
func play_p17() -> void:
	g.dispatch("to_board")
	g.dispatch("mixer")
	check(listen.local_view == "c_mixer", "P17: P16 and the contact sheet open the mixer")
	while int(listen.state.offset) > -2:
		g.dispatch("off_left")
	while int(listen.state.offset) < -2:
		g.dispatch("off_right")
	g.dispatch("play")
	check(not g.flag("P17"), "P17: the combined sentence never commits")
	_solo(true, false)
	g.dispatch("play")
	_solo(false, true)
	g.dispatch("play")
	check(g.flag("P17") and listen.has_seen("witness_procedure"), "P17: both voices alone")
	g.dispatch("back")
	g.dispatch("back")

func _solo(venn: bool, nora: bool) -> void:
	if listen.state.venn_on != venn:
		g.dispatch("toggle_venn")
	if listen.state.nora_on != nora:
		g.dispatch("toggle_nora")

## R04 P19: motor off, A and B closed, C open, WITNESS; the three questions.
func play_p19() -> void:
	g.dispatch("to_board")
	g.dispatch("witness_key")
	if listen.state.motor_on: g.dispatch("motor")
	if listen.state.ch_open.A: g.dispatch("key_a")
	if listen.state.ch_open.B: g.dispatch("key_b")
	if not listen.state.ch_open.C: g.dispatch("key_c")
	g.dispatch("witness")
	check(listen.state.witness_open and not g.flag("P19"), "P19: channel C opens; not yet solved")
	for q in R04Sim.QUESTIONS:
		g.dispatch(q)
	check(g.flag("P19"), "P19: three questions answered")
	g.dispatch("back")
	g.dispatch("back")

## R02 P20: his letters on the board, the contract's name thread, REQUESTED BY VENN.
func play_p20() -> void:
	office.dispatch("turn")
	office.dispatch("item:venn_correspondence")
	office.dispatch("board")
	check(office.state.board_loaded, "P20: the letters go on the board")
	office.dispatch("board")
	for m in R02Sim.BOARD_ANSWER:
		office.dispatch(m)
	office.dispatch(R02Sim.BOARD_STAMP)
	var ev := office.dispatch("provenance")
	check(g.flag("P20") and office.has_seen("why_ada"), "P20: the thread and stamp")
	check(not has_ev(ev, "fx", "tide"), "P20: Tide VII waits for the plan")
	office.dispatch("back")
	office.dispatch("turn")

## R03 P21: the station plan, four tiles placed, FIX.
func play_p21() -> void:
	g.dispatch("plan_wall")
	for t in R03Sim.TILES:
		g.dispatch("plan_tile_" + t)
		g.dispatch("plan_zone_" + R03Sim.PLAN_ANSWER[t])
	var ev := g.dispatch("plan_fix")
	check(g.flag("P21") and has_ev(ev, "fx", "tide"), "P21: the plan resolves; the Tide VIII card")
	check("ADA MERCER" in says(ev), "P21: her name in the witness frame")
	g.dispatch("back")

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
func _wheel(key: String, action: String, want: int) -> void:
	var guard := 0
	while int(chart.state[key]) != want and guard < 10:
		g.dispatch(action)
		guard += 1

## Clicks control <prefix><i> until state[key][i] reads want[i] (each wraps within 10).
func _turn(s: R02Sim, key: String, prefix: String, want: Array) -> void:
	for i in want.size():
		var guard := 0
		while int(s.state[key][i]) != int(want[i]) and guard < 10:
			s.dispatch("%s%d" % [prefix, i])
			guard += 1

func _done(pid: String) -> bool:
	if pid == "T1X":
		return g.flag("t1x_threshold_crossed")
	if pid == "P03a":
		return _done_p03a()
	return g.flag(pid)

func _walk_to(rid: String) -> void:
	for hop in _path(g, g.state.room, rid):
		g.dispatch("go:" + hop)

## Every room opens exactly at its step: reachable now iff its opening step is behind her.
func _check_reach(after: String) -> void:
	var reach := g.reachable("R02")
	for rid in OPENS:
		var opener: String = OPENS[rid]
		var should: bool = opener == "" or _done(opener)
		check((rid in reach) == should, "after %s: %s %s" % [after if after != "" else "begin", rid,
			"reachable" if should else "still shut"])

## Each step survives a save: flags, tide, band, room and inventory come back identical.
func _check_save(after: String) -> void:
	var t := GameSim.new()
	check(t.from_dict(JSON.parse_string(JSON.stringify(g.to_dict()))), "after %s: the save loads" % after)
	check(JSON.stringify(t.state.flags) == JSON.stringify(g.state.flags) and t.tide() == g.tide()
		and t.weather_band() == g.weather_band() and t.state.room == g.state.room
		and t.state.inventory == g.state.inventory, "after %s: the save round-trips the story" % after)

## P26's checkpoint replays to both endings; endings_seen keeps both.
func _endings() -> void:
	g.finish("sever")
	check(g.value("ending_choice") == "sever" and g.view == "end", "ending: sever")
	g.dispatch("return_decision")
	check(g.flag("P26") and g.value("ending_choice") == "", "replay returns to the P26 decision")
	g.finish("continue")
	var seen: Array = g.value("endings_seen")
	check(g.value("ending_choice") == "continue" and "sever" in seen and "continue" in seen,
		"ending: continue; both endings seen (%s)" % [seen])
