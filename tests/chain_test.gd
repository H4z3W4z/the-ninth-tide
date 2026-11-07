extends "res://tests/rooms/room_test_base.gd"
## The canonical completion graph, title to both endings, on one GameSim.
## Built rooms are played by their own actions; puzzles in rooms not yet built are
## committed with game.solve() (flags only), always while standing in their room after
## walking there by open exits. Every gate is asserted on the way: each room opens at
## exactly the puzzle that opens it, the tide and weather band advance only on their
## puzzles, and every puzzle's prerequisites are behind her when it is committed.
## Extend PLAYED (and play_<pid>) as each wave lands a room. Run after an import:
##   godot --headless --path . --script tests/chain_test.gd

## [puzzle, room, prerequisites] in canonical order (flags.md section 2, GDD section 5).
const GRAPH := [
	["P01", "R02", []],
	# KNOWN GAP: T1X-closure.md and reconciliation.md D7 put P02/P03 before T1X (the
	# corridor opens on P01; T1X requires tide_done(1)). R02 as migrated still runs the
	# slice order: its exit_block keeps R03/R04 shut until T1X is finished, and T1X does
	# not wait for P02/P03. The chain follows what the build allows and asserts the latch
	# (play_p01); move T1X after P03 here when R02 is re-gated with the R03/R04 rooms.
	["T1X", "R02", ["P01"]],
	["P02", "R04", ["P01", "t1x_threshold_crossed"]],
	["P03", "R03", ["P01", "t1x_threshold_crossed"]],
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
const OPENS := {"R01": "", "R02": "", "R03": "P01", "R04": "P01", "R11": "P04", "R05": "P06",
	"R06": "P06", "R07": "P09", "R08": "P09", "R09": "P12", "R10": "P15", "R12": "P24"}

## Tide and weather band once each step is committed.
const TIDE_AFTER := {"P01": 1, "T1X": 1, "P02": 1, "P03": 2, "P06": 3, "P09": 4, "P12": 5,
	"P15": 6, "P17": 6, "P18": 7, "P21": 8, "P24": 9, "P27": 9}
const BAND_AFTER := {"P03": 0, "P06": 1, "P09": 2, "P12": 3, "P15": 4, "P18": 5, "P21": 6,
	"P24": 7, "P27": 7}

## Steps played by their room's real actions (everything else: flags only).
const PLAYED := ["P01", "T1X"]

var g: GameSim
var office: R02Sim

func run_tests() -> void:
	g = GameSim.new()
	office = g.room("R02")
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
			if pid == "P04":
				# R03 unbuilt: the movement events its dials and hatch would record.
				for m in ["interval_set", "hatch_opened", "stair_looked"]:
					g.record_move(m)
			if pid == "P05":
				check(g.freeze_p05_trace() == ["interval_set", "hatch_opened", "stair_looked"],
					"P05 freezes the golden-path trace")
			g.solve(pid, ev)
			g.solve(pid, ev)  # idempotent re-commit
			if pid == "P26":
				g.save_checkpoint()
		check(_done(pid), "%s committed" % pid)
		tide = TIDE_AFTER.get(pid, tide)
		band = BAND_AFTER.get(pid, band)
		check(g.tide() == tide, "after %s: tide %d (got %d)" % [pid, tide, g.tide()])
		check(g.weather_band() == band, "after %s: weather band %d (got %d)" % [pid, band, g.weather_band()])
		check(g.plan_unlocked() == g.flag("P05"), "after %s: the plan follows P05" % pid)
		_check_reach(pid)
	_endings()

## R02 P01, played: supply OFF, curved C refused, straight B fitted, supply ON.
func play_p01() -> void:
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
	var ev := g.dispatch("go:R03")
	check(g.state.room == "R02" and "latches let go" in says(ev),
		"KNOWN GAP: R02 still holds her in the office until T1X (%s)" % says(ev))

## R02 T1X, played: log, drawer, reread, chair, closure report, threshold, Go on.
func play_t1x() -> void:
	check(not g.flag("closure_report_filed"), "T1X: the report is not filed yet")
	office.dispatch("logbook")
	office.dispatch("back")
	office.dispatch("puddle")
	office.dispatch("drawer")
	_turn(office, "drawer_dial", "dial_", [1, 8, 5, 2])
	office.dispatch("try_drawer")
	check(office.state.drawer_open, "T1X: 1852 opens the drawer")
	office.dispatch("back")
	office.dispatch("logbook")
	office.dispatch("back")
	office.dispatch("chair")
	check(office.state.seat_wet, "T1X: the chair is wet")
	var ev := office.dispatch("door")
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
	check(g.flag("t1x_threshold_crossed") and not g.flag("t1x_turned"), "T1X: held still, crossed")
	office.dispatch("end_continue")
	check(office.view == "room", "T1X: Go on, back in the office")

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
