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
## Wave 2 (station interior): R05, R06, R07 and R08 are played too: P07, P08, P09, P10,
## P11, P13, P14 and P22.
## Wave 3 (depths and endings): R09, R10, R11 and R12 are played too: P12, P15, P16, P18,
## P23, P24, P25, P26 and P27 (SEVER first, then the checkpoint replays to CONTINUE).
## Every puzzle is now played by its room; GIVES and the flag path stay for a future room.

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
const PLAYED := ["P01", "P03a", "P02", "P03", "T1X", "P04", "P05", "P06", "P07", "P08", "P09", "P10",
	"P11", "P12", "P13", "P14", "P15", "P16", "P17", "P18", "P19", "P20", "P21", "P22", "P23", "P24",
	"P25", "P26", "P27"]

## Items a not-yet-built room hands out at its step (flags.md section 4).
const GIVES := {}

## A capture driver (tools-side, under .panel/) may hand in the scene's own GameSim and an
## awaited hook(pid, rid, phase) called on arrival ("at") and after each commit ("done").
var external_game: GameSim = null
var step_hook := Callable()
## tests/click_chain_test.gd hands in an object whose qd(action) -> Array carries each action
## out as a real click on the game scene. Without one, actions go straight to the sim.
var clicker: Object = null
## Tests that need the state real play leaves after a step set this to stop there (run_tests
## then returns with `g` standing where that step left her).
var stop_after := ""

var g: GameSim
var office: R02Sim
var chart: R03Sim
var listen: R04Sim
var jetty: R01Sim
var kitchen: R05Sim
var bunks: R06Sim
var lab: R07Sim
var machine: R08Sim
var gallery: R09Sim
var vault: R10Sim
var stair: R11Sim
var chamber: R12Sim

func run_tests() -> void:
	g = external_game if external_game != null else GameSim.new()
	office = g.room("R02")
	chart = g.room("R03")
	listen = g.room("R04")
	jetty = g.room("R01")
	kitchen = g.room("R05")
	bunks = g.room("R06")
	lab = g.room("R07")
	machine = g.room("R08")
	gallery = g.room("R09")
	vault = g.room("R10")
	stair = g.room("R11")
	chamber = g.room("R12")
	check(g.view == "title" or office.view == "title", "the game starts on the title")
	_qd("begin")
	check(g.state.started and g.state.room == "R02" and g.tide() == 1 and g.weather_band() == 0,
		"begin: in the office, tide I, band 0")
	_check_reach("")
	var tide := 1
	var band := 0
	var notes: Array = []   # every notebook note seen so far (QA p2 nbmono, folded in)
	for step in GRAPH:
		var pid: String = step[0]
		var rid: String = step[1]
		for p in step[2]:
			check(g.flag(p), "%s: prerequisite %s is behind her" % [pid, p])
		check(not _done(pid), "%s not done before its step" % pid)
		_walk_to(rid)
		check(g.state.room == rid, "%s: walked to %s by open exits (at %s)" % [pid, rid, g.state.room])
		notes = _check_notes(notes, pid + " (arriving)")
		if step_hook.is_valid():
			await step_hook.call(pid, rid, "at")
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
		notes = _check_notes(notes, pid)
		if step_hook.is_valid():
			await step_hook.call(pid, rid, "done")
		tide = TIDE_AFTER.get(pid, tide)
		band = BAND_AFTER.get(pid, band)
		check(g.tide() == tide, "after %s: tide %d (got %d)" % [pid, tide, g.tide()])
		check(g.weather_band() == band, "after %s: weather band %d (got %d)" % [pid, band, g.weather_band()])
		check(g.plan_unlocked() == g.flag("P05"), "after %s: the plan follows P05" % pid)
		check(g.state.inventory.size() <= 6, "after %s: at most six items in hand (%s)" % [pid, g.state.inventory])
		for item in GameSim.ITEM_RETIRES_AFTER:
			if g._spent(item):
				check(not g.has_item(item), "after %s: spent %s is off the bar" % [pid, item])
		var open_p := false
		for p in GameSim.tide_puzzles(g.tide()):
			open_p = open_p or not g.flag(p)
		if open_p:
			var now := g.objective_text()
			check(now != "" and now != GameSim.NOTHING_HERE, "after %s: Now: is never empty (%s)" % [pid, now])
		_check_reach(pid)
		_check_save(pid)
		if pid == stop_after:
			return
	# Every item with a last use was filed in the notebook at that use, and nowhere else.
	var filed: Array = g.retired()
	filed.sort()
	var spent: Array = GameSim.ITEM_RETIRES_AFTER.keys()
	spent.sort()
	check(filed == spent, "the end: every spent item filed in the notebook (%s)" % [filed])
	_endings()

# ---------------------------------------------------------------------------
# Tide I
# ---------------------------------------------------------------------------
## R02 P01, played: supply OFF, curved C refused, straight B fitted, supply ON.
func play_p01() -> void:
	var ev := _qd("go:R03")
	check(g.state.room == "R02" and says(ev) == "The corridor is pitch black. Light first.",
		"before P01: the corridor is dark")
	_qd("papers")
	_qd("read_contract")
	_qd("back")
	_qd("lamp")
	check(office.view == "repair", "P01: the lamp opens the repair")
	_qd("toggle_supply")
	_qd("select_c")
	_qd("fit")
	check(not g.flag("P01"), "P01: the curved spare is refused")
	_qd("select_b")
	_qd("fit")
	_qd("toggle_supply")
	check(g.flag("P01") and office.view == "room", "P01: supply on with B seated")
	check(not g.room_open("R05") and not g.room_open("R11"), "P01 opens nothing past the corridor")
	check(g.exit_open("R02", "R03") and g.exit_open("R02", "R04"), "P01 unlocks the corridor exits")
	check(office.exit_block("R03") == "" and office.exit_block("R04") == "",
		"P01: the office no longer holds the corridor (T1X re-time)")
	ev = _qd("go:R05")
	check(g.state.room == "R02" and says(ev) == R02Sim.SERVICE_NO_KEY, "the service door stays shut before P06")

## R02 drawer (P03 part 1): log, prints, 1852; the sheet and lens. The log waits for Tide I.
func play_p03a() -> void:
	_qd("logbook")
	_qd("back")
	_qd("puddle")
	_qd("drawer")
	_turn(office, "drawer_dial", "dial_", [1, 8, 5, 2])
	var ev := _qd("try_drawer")
	check(office.state.drawer_open, "drawer: 1852 opens it")
	check(R02Sim.PHOTO_BEFORE_LINE in says(ev), "drawer: she has seen the picture before")
	_qd("back")
	check(g.has_item("venn_tide_sheet") and g.has_item("inspection_lens"), "drawer: his tide sheet and the lens")
	_qd("logbook")
	_qd("back")
	check(not office.state.log_rewritten, "drawer: the log does not rewrite before Tide I's instruments")
	_qd("chair")
	check(not office.state.seat_wet, "drawer: the chair stays dry before Tide I's instruments")

func _done_p03a() -> bool:
	return office.state.drawer_open

## R04 P02: the cylinder bands C-A-B at I, III, II, then PLAY.
func play_p02() -> void:
	_qd("spindle")
	for b in ["C", "A", "B"]:
		_qd("tray_" + b)
	var rots := {"C": 0, "A": 2, "B": 1}
	for b in ["C", "A", "B"]:
		var k: int = listen.state.spindle.find(b)
		for i in posmod(int(rots[b]) - int(listen.state.band_rot[b]), 3):
			_qd("rot_up_%d" % k)
	var ev := _qd("play")
	check(g.flag("P02") and listen.has_seen("calibration_zero"), "P02: the recording gives the zero")
	check(not has_ev(ev, "fx", "tide"), "P02 alone does not finish Tide I")
	_qd("back")

## R03 P03 part 2: Venn's sheet registered on base 17, north up, lighthouse; clipped.
func play_p03() -> void:
	var ev := _qd("recorder")
	ev = _qd("rec_calibrate")
	check(not g.flag("P04") and says(ev) == "It won't pull. Not with his seal across it.",
		"P04 before the threshold: sealed")
	_qd("back")
	ev = _qd("clip_tin")
	check(g.has_item("chart_clips"), "P03: the clips from the tin")
	_qd("sheet_table")
	ev = _qd("reg_table")
	check(not chart.state.reg_laid and says(ev) == R03Sim.REG_HAS_SHEET,
		"P03: a bare click on the table says the sheet is in her pocket")
	_qd("item:venn_tide_sheet")
	_qd("reg_table")
	check(chart.state.reg_laid, "P03: his sheet is laid by using it on the table")
	_qd("reg_base_17")
	var guard := 0
	while int(chart.state.reg_rot) != 0 and guard < 8:
		_qd("reg_rot_cw")
		guard += 1
	_qd("reg_snap_lighthouse")
	ev = _qd("reg_clip")
	check(not g.flag("P03") and says(ev) == R03Sim.REG_HAS_CLIPS, "P03: the bare rail is empty")
	_qd("item:chart_clips")
	ev = _qd("reg_clip")
	check(g.flag("P03") and g.tide_done(1), "P03: the composite closes Tide I's instruments")
	check(not g.has_item("venn_tide_sheet") and g.has_item("chart_clips"), "P03: sheet taken, clips kept")
	check(R03Sim.RECONCILE_LINE in says(ev), "P03: the office line")
	check(g.tide() == 1, "P03: tide I holds until the threshold")
	_qd("back")

## R02 T1X, played: reread, chair, closure report, threshold, Go on.
func play_t1x() -> void:
	check(not g.flag("closure_report_filed"), "T1X: the report is not filed yet")
	var ev := _qd("logbook")
	check(office.state.log_rewritten, "T1X: with Tide I done the log rewrites itself")
	_qd("back")
	_qd("chair")
	check(office.state.seat_wet, "T1X: the chair is wet")
	ev = _qd("door")
	check("Latched" in says(ev) and g.state.room == "R02", "T1X: the room keeps her before the report")
	ev = _qd("go:R03")
	check(g.state.room == "R02", "T1X: no way out to the chart room during the report")
	_qd("papers")
	check(office.view == "report", "T1X: the papers open the closure report (view %s)" % office.view)
	_turn(office, "report_fields", "field_", R02Sim.REPORT_ANSWER)
	_turn(office, "report_time", "rtime_", R02Sim.REPORT_TIME_ANSWER)
	_qd("file_report")
	check(g.flag("closure_report_filed"), "T1X: the closure report is filed")
	check(g.tide() == 1, "T1X: tide I holds until the threshold")
	_qd("back")
	_qd("door")
	check(office.view == "threshold", "T1X: the corridor door opens on the threshold")
	_qd("continue")
	check(not g.flag("t1x_turned"), "T1X: held still")
	ev = _qd("end_continue")
	check(g.flag("t1x_threshold_crossed") and has_ev(ev, "fx", "tide"), "T1X: crossed; the Tide II card")
	check(g.state.room == "R03", "T1X: Go on lands her in the chart room")

## R03 P04: zero 4 (from the recording), interval 3 (from the composite), pull.
func play_p04() -> void:
	_qd("recorder")
	_qd("rec_seal")
	_wheel("zero", "rec_zero_down", R03Sim.ZERO_ANSWER)
	_wheel("interval", "rec_int_up", R03Sim.INTERVAL_ANSWER)
	var ev := _qd("rec_calibrate")
	check(g.flag("P04") and has_ev(ev, "fx", "drum_turn"), "P04: the drum turns")
	check(g.exit_open("R03", "R11"), "P04: the hatch exit opens")
	_qd("back")

## R03 P05: look down the stair, then BOUNDARY, RELATION, OBSERVER, RECORD.
func play_p05() -> void:
	_qd("hatch")
	_qd("back")
	_qd("recorder")
	var order := ["boundary", "relation", "observer"]
	for i in 3:
		_qd("rec_plate_" + order[i])
		_qd("rec_slot_%d" % i)
	_qd("rec_record")
	check(g.flag("P05"), "P05: recorded")
	check(g.value("p05_trace") == ["interval_set", "hatch_opened", "stair_looked"],
		"P05 freezes the golden-path trace (%s)" % [g.value("p05_trace")])
	check(chart.strip_lines()[-1] == "COLLECTION ANSWERS. ATTEND JETTY.", "P05: the strip sends her to the jetty")
	_qd("back")

# ---------------------------------------------------------------------------
# Tide II
# ---------------------------------------------------------------------------
## R01 P06: the boat through the lens, read the placard, set the unverified tally and ring
## the bell under the broken pennant (the placard names pennants, not numbers); the capsule;
## then the kitchen key at the office's service door.
func play_p06() -> void:
	check(jetty.drained(), "P06: Tide II, the sea is out from the jetty")
	for a in ["launch", "item:inspection_lens", "launch", "peer", "back", "panel"]:
		_qd(a)
	var placard := says(_qd("placard"))
	check("broken pennant" in placard and not "bell 2" in placard, "P06: the placard names the pennant (%s)" % placard)
	_qd("tally_unverified")
	check(not g.flag("P06"), "P06: not before the bell")
	var ev := _qd("bell_%d" % (R01Sim.BELL_PENNANTS.find("broken") + 1))
	check(g.flag("P06") and has_ev(ev, "fx", "tide"), "P06: the boat withdraws; the Tide III card")
	for a in ["back", "line", "cap", "key", "note", "back"]:
		_qd(a)
	check(g.has_item("service_key") and jetty.has_seen("venn_address_note"), "P06: the key and Venn's note")
	check(g.has_item("inspection_lens"), "the lens is durable")
	_walk_to("R02")
	ev = _qd("go:R05")
	check(g.state.room == "R02" and says(ev).begins_with("Locked."), "the service door: locked with the key held")
	_qd("turn")
	_qd("item:service_key")
	_qd("service_door")
	check(not g.has_item("service_key") and office.state.service_unlocked, "the key is spent at the service door")
	_qd("turn")
	_walk_to("R01")

# ---------------------------------------------------------------------------
# Tides III-V (wave 2: the station interior)
# ---------------------------------------------------------------------------
## R05 P07: nine bowls on their marks, the tally at nine, COMPARE; then Nora's book, her
## work card and the service drawer's pantry half.
func play_p07() -> void:
	check(not g.exit_open("R05", "R07") and not g.exit_open("R05", "R08"), "P07: the hatch is shut")
	_qd("bowl_stack")
	check(kitchen.local_view == "c_table", "P07: the bowl stack opens the table")
	for k in 9:
		_qd("slot_%d" % R05Sim.RACK_HOME.find(R05Sim.SOLUTION[k]))
		_qd("place_%d" % (k + 1))
	var guard := 0
	while int(kitchen.state.tally) != R05Sim.SOLUTION_TALLY and guard < 30:
		_qd("tally_up" if int(kitchen.state.tally) < R05Sim.SOLUTION_TALLY else "tally_down")
		guard += 1
	var ev := _qd("compare")
	check(g.flag("P07") and kitchen.has_seen("headcount_nine"), "P07: the table for nine")
	check(not has_ev(ev, "fx", "tide"), "P07 does not end a tide")
	_qd("back")
	for a in ["to_kitchen", "ledger", "back", "work_card"]:
		_qd(a)
	check(kitchen.has_seen("nora_ledger") and kitchen.has_seen("nora_work_card"), "P07: her book and her work card")
	_qd("service_drawer")
	check(g.has_item("token_pantry_half") and kitchen.has_seen("drawer_note"), "P07: the pantry half")
	_qd("to_mess")

## R06 P08: each belonging home on its owner's shelf; the bunk half from the compartment.
func play_p08() -> void:
	_qd("belongings_shelf")
	check(bunks.local_view == "c_lockers", "P08: the belongings shelf opens the lockers")
	var ev: Array = []
	for o in R06Sim.OWNER:
		_qd("obj_" + o)
		ev = _qd("shelf_" + R06Sim.OWNER[o])
	check(g.flag("P08") and g.has_item("token_bunk_half"), "P08: the bunk half")
	check(bunks.has_seen("venn_seal"), "P08: Venn's seal, three cuts")
	check(not has_ev(ev, "fx", "tide") and not g.flag("P09"), "P08 alone does not finish Tide III")
	_qd("back")

## R05 P09: both halves in the socket, turned; +1 VENN present under seal 3; STAMP.
func play_p09() -> void:
	_qd("to_kitchen")
	for half in ["pantry", "bunk"]:
		_qd("item:token_%s_half" % half)
		# The first half opens the board; the second goes in its own socket there.
		_qd("shift_board" if kitchen.local_view != "c_service_board" else "socket_" + half)
	_qd("socket_turn")
	check(kitchen.local_view == "c_service_board", "P09: the shift board is open")
	var want: Dictionary = R05Sim.SOLUTION_AMEND
	var guard := 0
	while kitchen.state.amend.count != want.count and guard < 8:
		_qd("f_count")
		guard += 1
	_qd("tile_%d" % R05Sim.NAME_TILES.find(want.name))
	guard = 0
	while kitchen.state.amend.status != want.status and guard < 8:
		_qd("f_status")
		guard += 1
	_qd("seal_3")
	var ev := _qd("stamp")
	check(g.flag("P09") and has_ev(ev, "fx", "tide"), "P09: the amendment stands; the Tide IV card")
	check(not g.has_item("token_pantry_half") and not g.has_item("token_bunk_half"), "P09: both halves spent")
	check(kitchen.has_seen("eight_retained"), "P09: eight retained, one witnessing")
	check(g.exit_open("R05", "R07") and g.exit_open("R05", "R08"), "P09: the hatch opens the lab and the machine room")
	_qd("back")
	_qd("to_mess")

## R07 P10: tilt the rack, rest jar C, tip, seat it in the reference socket.
func play_p10() -> void:
	for a in ["tilt_rack", "rest_c", "tip", "seat"]:
		_qd(a)
	check(g.flag("P10") and lab.has_seen("datum_target"), "P10: jar C seats; stair pressure 2")
	_qd("back")
	check(lab.has_seen("lean"), "P10: the water leaned")
	check(not g.flag("P12"), "P10 alone does not open the stair work")

## R08 P11: SUPPLY, GATE, RETURN open, INDEX shut; the pump.
## Played as she would: the drawing shows numbers only, and the capped stub's number is the
## toggle to shut; every other numbered valve opens. The lines' names never enter into it.
func play_p11() -> void:
	_qd("valve_board")
	var drawing := says(_qd("look_drawing"))
	for name in ["SUPPLY", "RETURN", "INDEX"]:
		check(not drawing.contains(name), "P11: the drawing doesn't name %s" % name)
	var at := drawing.find("stub off ")
	check(at >= 0, "P11: the drawing shows a capped stub")
	var stub := drawing.substr(at + 9, 2)
	for v in R08Sim.VALVES:
		var open: bool = R08Sim.VALVE_TAGS[v] != stub
		if machine.state.toggles[v] != open:
			_qd("tog_" + v.to_lower())
	_qd("pump")
	check(g.flag("P11"), "P11: the gate loop runs")
	_qd("back")

## R07 P13: the tube whose number is on her kitchen work card (R05, the only number-to-name
## link), addressed to BELL, released, recorded; her register card.
func play_p13() -> void:
	_qd("to_bench")
	var ev := _qd("balance")
	check(lab.beam_unlocked(), "P13: P12's stair pressure frees the beam")
	check(kitchen.has_seen("nora_work_card"), "P13: her work card was read in the kitchen")
	var tube := ""
	for s in R07Sim.SAMPLES:
		if R05Sim.CARD_STAMP.ends_with("SPECIMEN " + R07Sim.SPECIMEN[s]):
			tube = s
	check(tube == "N", "P13: the work card's stamp names one tube, 27-11")
	for a in ["smp_" + tube.to_lower(), "reg_bell", "key_address", "key_release", "key_record"]:
		ev = _qd(a)
	check(g.flag("P13") and g.has_item("nora_register_card"), "P13: her mass recorded; her card")
	check(lab.has_seen("thumb"), "P13: the thumb in the felt")
	_qd("back")

## R07 P14: short, pause, long (her work card); her name tab; the strip; SEAL.
func play_p14() -> void:
	# a reloaded save may stand her at the tank wall: the frame is on the bench
	if lab.local_view != "bench":
		_qd("to_bench")
	_qd("frame_stand")
	check(lab.local_view == "c_frame", "P14: P13 opens the frame")
	# a wrong order first: the frame prints a composite that is not hers, and nothing is used
	var wrong := ["long", "short", "pause"]
	for k in 3:
		_qd("sec_" + wrong[k])
		_qd("slot_%d" % k)
	var inv := JSON.stringify(g.state.inventory)
	var miss := _qd("seal")
	if lab.reference_seen():
		check(says(miss) == R07Sim.WRONG_BREATH and lab.frame_print == wrong,
			"P14: a wrong order prints a non-matching composite (got %s)" % says(miss))
	check(not g.flag("P14") and JSON.stringify(g.state.inventory) == inv and not _story(miss),
		"P14: a wrong order consumes nothing and tells no story")
	for k in 3:
		_qd("slot_%d" % k)
	check(lab.state.slots == ["", "", ""] and lab.frame_print == [], "P14: the sections back in the tray")
	for k in 3:
		_qd("sec_" + R07Sim.SOLUTION_SLOTS[k])
		_qd("slot_%d" % k)
	_qd("item:nora_register_card")
	_qd("name_tab")
	_qd("strip_clip")
	var ev := _qd("seal")
	check(g.flag("P14") and g.has_item("nora_frame") and g.has_item("nora_register_card"),
		"P14: her frame sealed; the card kept")
	check(not has_ev(ev, "fx", "tide"), "P14: Tide V waits for the bearing")
	_qd("back")
	_qd("back")
	check(lab.local_view == "room", "P14: back in the laboratory")

## R09 P15: her frame on the scope's clamp, STATION 3, the patch under the lens, RECORD
## BEARING. The strip prints, the frame comes back, and leaving the scope stands the sea up.
func play_p15() -> void:
	if g.state.room != "R09":
		_qd("go:R09")
	var gallery: R09Sim = g.room("R09")
	_qd("scope")
	check(gallery.local_view == "c_scope", "P15: the scope opens")
	_qd("item:nora_frame")
	_qd("mount")
	check(gallery.state.frame_mounted and not g.has_item("nora_frame"), "P15: her frame in the clamp")
	# every aperture holds a bowl; the lens reads each rim, and only STATION 3's is the square patch
	_qd("sel_1")
	_qd("item:inspection_lens")
	_qd("scope_view")
	check(gallery.rim_shown() == "round" and not gallery.state.patch_confirmed, "P15: LAND 1's bowl has a round patch")
	_qd("sel_2")
	_qd("item:inspection_lens")
	_qd("scope_view")
	check(gallery.rim_shown() == "crack" and not gallery.state.patch_confirmed, "P15: SEA 2's bowl has a crack, no patch")
	_qd("sel_3")
	var refused := _qd("record")
	check(not g.flag("P15") and R09Sim.UNCONFIRMED in says(refused) and not gallery.relation_lit()
		and gallery.state.frame_mounted and g.has_item("inspection_lens"),
		"P15: RECORD on STATION 3 before the lens prints SUBJECT UNCONFIRMED: INSPECT; nothing consumed; the mark stays dark")
	_qd("item:inspection_lens")
	_qd("scope_view")
	check(gallery.state.patch_confirmed and gallery.rim_shown() == "square" and gallery.relation_lit(),
		"P15: the square riveted patch under the lens")
	var ev := _qd("record")
	check(g.flag("P15") and g.has_item("nora_spatial_strip") and g.has_item("nora_frame"),
		"P15: her bearing recorded; the strip printed; her frame back")
	check(has_ev(ev, "fx", "tide"), "P15: Tide V closes on the bearing")
	var up := _qd("back")
	check(gallery.local_view == "room" and gallery.state.reveal_seen, "P15: the sea stood up")
	var told := []
	var breath := -1.0
	for e in up:
		if e.type == "say" and e.get("story", false):
			told.append([e.text, e.delay])
		elif e.type == "fx" and e.id == "hold_breath":
			breath = float(e.get("delay", -1.0))
	check(told.size() >= 2 and told[told.size() - 2][0] == "It hasn't closed again."
		and told[told.size() - 1][0] == "One of the lit windows is this one. Someone in it is standing at the rail."
		and is_equal_approx(breath, told[told.size() - 1][1]),
		"P15: the reveal ends on the lit window with someone at its rail, and the breath held on it")

# ---------------------------------------------------------------------------
# Tide IV: the pressure gate
# ---------------------------------------------------------------------------
## R11 P12: the gate's wheel to EQUAL (2), plate O1 in UPPER and C1 in LOWER, OPEN. The
## gate lifts and she is on the lower landing, under the stopped bell.
func play_p12() -> void:
	check(stair.landing == 1, "P12: she comes in on the upper landing, at the gate")
	_qd("gate")
	check(stair.local_view != "room", "P12: the gate opens its close-up")
	var guard := 0
	while int(stair.state.pressure) != 2 and guard < 8:
		_qd("wheel_up" if int(stair.state.pressure) < 2 else "wheel_down")
		guard += 1
	for i in 2:
		var want: String = ["o1", "c1"][i]
		if stair.state.slots[i] != want:
			if stair.state.slots[i] != "":
				_qd(["slot_upper", "slot_lower"][i])
				_qd("plate_" + stair.held_plate)
			_qd("plate_" + want)
			_qd(["slot_upper", "slot_lower"][i])
	check(stair.state.slots == ["o1", "c1"] and int(stair.state.pressure) == 2, "P12: EQUAL, O1 over C1")
	var ev := _qd("lever_open")
	check(g.flag("P12") and has_ev(ev, "fx", "tide"), "P12: the gate opens; the Tide V card")
	check(stair.landing == 2 and stair.local_view == "room", "P12: down on the lower landing")
	check(g.exit_open("R11", "R07") and g.exit_open("R11", "R09") and not g.exit_open("R11", "R12"),
		"P12: the laboratory door and the gallery open; the chamber stays shut")

# ---------------------------------------------------------------------------
# Tides VI-VII: the records vault
# ---------------------------------------------------------------------------
## R10 P16: the four loose panels in order B D A C, her clips across them, the cover off.
func play_p16() -> void:
	_r10_base("room")
	_qd("contact_table")
	check(vault.local_view == "c_contact", "P16: the contact table opens")
	var order := ["B", "D", "A", "C"]
	for k in order.size():
		_qd("loose_" + order[k].to_lower())
		_qd("slot_%d" % (k + 1))
	_qd("item:chart_clips")
	_qd("clip")
	var ev := _qd("cover")
	check(g.flag("P16") and g.has_item("contact_sheet") and not g.has_item("chart_clips")
		and "chart_clips" in g.retired(), "P16: the contact sheet; the spent clips filed in the notebook")
	check(says(ev).ends_with(GameSim.FILED_LINE), "P16: 'Filed in the notebook.' ends the chain (%s)" % says(ev))
	check(vault.has_seen("contact_sheet_1927"), "P16: the film edge is dated 1927")
	check(not has_ev(ev, "fx", "tide"), "P16 alone does not close Tide VI")
	_qd("back")

## R10 P18: her three records in BODY, PLACE and NAME, the dial to 18 OCT 1927, COMPARE.
## The folders give everything back with Venn's letters.
func play_p18() -> void:
	_r10_base("catalogue")
	_qd("folders")
	check(vault.local_view == "c_folders", "P18: the folders open")
	var homes := {"nora_frame": "fold_body", "nora_spatial_strip": "fold_place", "nora_register_card": "fold_name"}
	for rec in homes:
		_qd("item:" + rec)
		_qd(homes[rec])
	check(vault.state.filed.values() == ["nora_frame", "nora_spatial_strip", "nora_register_card"],
		"P18: her three records filed")
	_qd("day_up")
	for i in 4:
		_qd("year_dn")
	check(int(vault.state.day) == 18 and int(vault.state.year) == 1927, "P18: the dial at 18 OCT 1927")
	var ev := _qd("compare")
	check(g.flag("P18") and g.has_item("venn_correspondence"), "P18: SUBJECT COMPLETE; Venn's letters")
	for rec in homes:
		check(g.has_item(rec), "P18: %s back in hand" % rec)
	check(has_ev(ev, "fx", "tide"), "P18: Tide VI closes on the folders")
	_qd("back")

# ---------------------------------------------------------------------------
# Tide VIII
# ---------------------------------------------------------------------------
## R10 P23: the model's shutter open after P21; the lead INPUT to WITNESS, TEST. RECORD OPEN,
## and the witness bridge comes out of the model.
func play_p23() -> void:
	_r10_base("catalogue")
	_qd("model")
	check(vault.local_view == "c_model" and vault.shutter_open(), "P23: the model's shutter is open")
	# The terminals carry marks, not words; the two to join are the session log's margin marks,
	# which the notebook kept from P17.
	check(listen.has_seen("witness_procedure") and R04Sim.OBSERVATIONS.witness_procedure.find("solid triangle") >= 0
		and R04Sim.OBSERVATIONS.witness_procedure.find("hollow circle") >= 0, "P23: the margin's two marks are in the notebook")
	var marks := []
	for t in ["input", "witness"]:
		marks.append(R10Sim.TERMINAL_GLYPHS[t])
	check(marks == R04Sim.MARGIN_MARKS, "P23: the triangle and the circle are the terminals to join")
	_qd("t_input")
	_qd("t_witness")
	var ev := _qd("test")
	check(g.flag("P23") and g.has_item("witness_bridge") and vault.state.stamp == "open",
		"P23: RECORD OPEN; the witness bridge")
	check(not has_ev(ev, "fx", "tide"), "P23: Tide VIII waits for the lower door")
	_qd("back")

## Stands in R10's base view `want` ("room" = the shelves, "catalogue"), with no close-up up.
func _r10_base(want: String) -> void:
	if vault.is_closeup():
		_qd("back")
	if vault.local_view != want:
		_qd("to_catalogue" if want == "catalogue" else "to_shelves")
	check(vault.local_view == want, "R10: at the %s" % want)

## R11 P24: down to the lower door, where her trace and bearing come pre-seated in BODY and
## PLACE; the COPY port's original card in NAME is refused (near miss); the amended card in
## NAME, the witness bridge in WITNESS, OPEN ACCESS. Everything comes back; the chamber opens.
func play_p24() -> void:
	if stair.landing != 2:
		_qd("descend")
	check(stair.landing == 2, "P24: on the lower landing")
	_qd("lower_door")
	check(stair.state.frames == {"BODY": "nora_frame", "PLACE": "nora_spatial_strip", "NAME": ""}
		and not g.has_item("nora_frame") and not g.has_item("nora_spatial_strip"),
		"P24: her trace and her bearing already seated")
	check(g.has_item("nora_register_card") and g.has_item("amended_nora_card"), "P24: both NAME cards in hand")
	# A near miss first: the card the COPY port pushed out closes her record.
	for a in ["item:nora_register_card", "frame_name", "item:witness_bridge", "socket_witness", "lever_access"]:
		_qd(a)
	check(not g.flag("P24") and stair.name_shut(), "P24: the original card refused, the shutter down")
	for a in ["item:amended_nora_card", "frame_name"]:
		_qd(a)
	check(stair.state.frames.NAME == "amended_nora_card" and stair.state.witness == "witness_bridge"
		and stair.state.copy == "" and g.has_item("nora_register_card"), "P24: the amended card and the witness")
	var ev := _qd("lever_access")
	check(g.flag("P24") and has_ev(ev, "fx", "tide"), "P24: OPEN ACCESS; the Tide IX card")
	for it in ["nora_frame", "nora_spatial_strip", "amended_nora_card", "nora_register_card", "witness_bridge"]:
		check(g.has_item(it), "P24: %s back in hand" % it)
	check(g.exit_open("R11", "R12") and stair.local_view == "room", "P24: the chamber door stands open")

# ---------------------------------------------------------------------------
# Tide IX: the observation chamber
# ---------------------------------------------------------------------------
## R12 P25: seven cards in her name. A near miss first (the swapped MOVEMENT run lights the BODY
## plate: DOES NOT CORRESPOND TO OBSERVER); then TRACE, POSITION and IDENTITY in BODY, PLACE and
## NAME; the switch to WITNESS; ROUTE.
func play_p25() -> void:
	for a in ["to_frames", "frame_body", "rack_trace_a", "f_body"]:
		_qd(a)
	check(chamber.plate_mismatch("body"), "P25: a decoy MOVEMENT card lights the BODY plate")
	for a in ["rack_trace", "f_body", "rack_position", "f_place", "rack_identity", "f_name", "switch"]:
		_qd(a)
	check(not chamber.plate_mismatch("body") and chamber.card_in_rack("trace_a"), "P25: the true card displaces it")
	var ev := _qd("route")
	check(g.flag("P25") and chamber.frames() == R12Sim.SOLUTION_FRAMES and chamber.switch() == "witness",
		"P25: her record routed to the witness line")
	check(not has_ev(ev, "fx", "tide"), "P25: no tide past IX")
	check(has_ev(ev, "fx", "eye_look") and chamber.gaze() == "chair", "P25: the eye in the window turns to the chair")

## Backs out of R12's frames, routing and close-ups to the chamber itself.
func _r12_room() -> void:
	var guard := 0
	while chamber.local_view != "room" and guard < 4:
		_qd("back")
		guard += 1
	check(chamber.local_view == "room", "R12: in the chamber")

## R12 P26: preview both routes and watch each in the window; the second preview is P26.
## The checkpoint.
func play_p26() -> void:
	_r12_room()
	var ev := []
	for a in ["to_routing", "plate_sever", "preview_sever"]:
		ev = _qd(a)
	check(not g.flag("P26") and chamber.previewed("sever"), "P26: one route seen is not enough")
	check(has_ev(ev, "fx", "eye_look") and chamber.gaze() == "routing", "P26: a preview turns the eye to the routing wall")
	_r12_room()   # the SEVER preview's window glance may have put the close-up down
	for a in ["to_routing", "plate_continue", "preview_continue"]:
		_qd(a)
	check(g.flag("P26") and chamber.previewed("sever") and chamber.previewed("continue"), "P26: both routes seen")
	check(not g.checkpoint.is_empty(), "P26: the pre-ending checkpoint is stored")

## R12 P27, played as SEVER: the yoke across the feed contacts, preview, SEVER; then every
## page of the ending to the end card. _endings() replays the checkpoint to CONTINUE.
func play_p27() -> void:
	_r12_room()   # the P26 glance may already have put the routing close-up down
	for a in ["to_routing", "contacts", "tray", "contacts", "preview"]:
		_qd(a)
	_qd("btn_sever")
	check(g.flag("P27") and chamber.chosen() == "sever", "P27: SEVER pressed")
	var guard := 0
	while g.view != "end" and guard < 20:
		_qd("ending_next")
		guard += 1
	check(g.view == "end" and g.value("ending_choice") == "sever", "P27: the SEVER ending reaches its end card")

## R06 P22: her card on the record rest, her sketch beside it, NO SURVIVING EFFECTS amended
## to REPAIRED CUP, NORA BELL; APPEND with her pencil; the amended card comes off the rest on Back.
func play_p22() -> void:
	_qd("slope")
	_qd("item:nora_register_card")
	_qd("rest_record")
	_qd("rest_evidence")
	check(bunks.state.card_on_rest and bunks.state.sketch_on_rest, "P22: card and sketch on the rests")
	var names := ["fin_next", "obj_next", "own_next"]
	for i in 3:
		var guard := 0
		while int(bunks.state.wheels[i]) != int(R06Sim.WHEEL_SOLUTION[i]) and guard < 8:
			_qd(names[i])
			guard += 1
	_qd("item:pencil")
	var ev := _qd("append")
	check(g.flag("P22") and bunks.state.card_on_rest and not g.has_item("nora_register_card"),
		"P22: the record amended, the card still on the rest")
	check(not has_ev(ev, "fx", "tide"), "P22: Tide VIII waits for the witness bridge")
	_qd("back")
	check(not g.has_item("pencil") and "pencil" in g.retired() and says(ev).ends_with(GameSim.FILED_LINE),
		"P22: the pencil's last use: filed in the notebook (%s)" % says(ev))
	check(g.has_item("amended_nora_card"), "P22: Back takes the amended card")

# ---------------------------------------------------------------------------
# Tides VI-VII
# ---------------------------------------------------------------------------
## R04 P17: the session spool on the mixer, offset -2, each voice alone.
func play_p17() -> void:
	_qd("to_board")
	_qd("mixer")
	check(listen.local_view == "c_mixer", "P17: P16 and the contact sheet open the mixer")
	while int(listen.state.offset) > -2:
		_qd("off_left")
	while int(listen.state.offset) < -2:
		_qd("off_right")
	_qd("play")
	check(not g.flag("P17"), "P17: the combined sentence never commits")
	_solo(true, false)
	_qd("play")
	_solo(false, true)
	_qd("play")
	check(g.flag("P17") and listen.has_seen("witness_procedure"), "P17: both voices alone")
	_qd("back")
	_qd("back")

func _solo(venn: bool, nora: bool) -> void:
	if listen.state.venn_on != venn:
		_qd("toggle_venn")
	if listen.state.nora_on != nora:
		_qd("toggle_nora")

## R04 P19: motor off, A and B closed, C open, WITNESS; the three questions.
func play_p19() -> void:
	_qd("to_board")
	_qd("witness_key")
	# taught by failure: the procedure only asks for a quiet line; the line says what's on it
	if listen.state.motor_on:
		check(says(_qd("witness")).ends_with(R04Sim.LINE_OCCUPIED) and not g.flag("P19"),
			"P19: motor on, Rook's dictation occupies the line")
		_qd("motor")
	if listen.state.ch_open.A or listen.state.ch_open.B:
		check(says(_qd("witness")).ends_with(R04Sim.LINE_CROWDED) and not listen.state.witness_open,
			"P19: A or B open, the session voices crowd him out")
	if listen.state.ch_open.A: _qd("key_a")
	if listen.state.ch_open.B: _qd("key_b")
	if not listen.state.ch_open.C: _qd("key_c")
	_qd("witness")
	check(listen.state.witness_open and not g.flag("P19"), "P19: channel C opens; not yet solved")
	for q in R04Sim.QUESTIONS:
		_qd(q)
	check(g.flag("P19"), "P19: three questions answered")
	_qd("back")
	_qd("back")

## R02 P20: his letters on the board, the contract's name thread, REQUESTED BY VENN.
func play_p20() -> void:
	_qd("turn")
	_qd("item:venn_correspondence")
	_qd("board")
	check(office.state.board_loaded, "P20: the letters go on the board")
	if office.local_view != "board":
		_qd("board")
	var ev := []
	for m in R02Sim.BOARD_ANSWER:
		ev = _qd(m)
	check(says(ev) == "Thread: contract addressee → dissent signatory → quoted sentence", "P20: the thread, said")
	_qd(R02Sim.BOARD_STAMP)
	ev = _qd("provenance")
	check(g.flag("P20") and office.has_seen("why_ada"), "P20: the thread and stamp")
	check(not has_ev(ev, "fx", "tide"), "P20: Tide VII waits for the plan")
	_qd("back")
	_qd("turn")

## R03 P21: the station plan, four tiles placed, FIX.
func play_p21() -> void:
	_qd("plan_wall")
	for t in R03Sim.TILES:
		_qd("plan_tile_" + t)
		_qd("plan_zone_" + R03Sim.PLAN_ANSWER[t])
	var ev := _qd("plan_fix")
	check(g.flag("P21") and has_ev(ev, "fx", "tide"), "P21: the plan resolves; the Tide VIII card")
	check("ADA MERCER" in says(ev), "P21: her name in the witness frame")
	_qd("back")

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
func _wheel(key: String, action: String, want: int) -> void:
	var guard := 0
	while int(chart.state[key]) != want and guard < 10:
		_qd(action)
		guard += 1

## Clicks control <prefix><i> until state[key][i] reads want[i] (each wraps within 10).
func _turn(s: R02Sim, key: String, prefix: String, want: Array) -> void:
	for i in want.size():
		var guard := 0
		while int(s.state[key][i]) != int(want[i]) and guard < 10:
			_qd("%s%d" % [prefix, i])
			guard += 1

func _done(pid: String) -> bool:
	if pid == "T1X":
		return g.flag("t1x_threshold_crossed")
	if pid == "P03a":
		return _done_p03a()
	return g.flag(pid)

## Notebook evidence never disappears: every note seen before (each room's observations and
## the items filed after their last use) is still there, so the count never falls. Returns
## the notes now.
func _check_notes(before: Array, after: String) -> Array:
	var now: Array = []
	for rid in g.order:
		var r: RoomSim = g.room(rid)
		for id in r.c("OBSERVATIONS", {}):
			if r.has_seen(id):
				now.append(rid + "." + id)
	for item in g.retired():
		now.append("filed:" + item)
	for k in before:
		check(k in now, "after %s: the note %s is still in the notebook" % [after, k])
	check(now.size() >= before.size(), "after %s: the notebook never shrinks (%d -> %d)" % [after, before.size(), now.size()])
	return now

func _walk_to(rid: String) -> void:
	for hop in _path(g, g.state.room, rid):
		_qd("go:" + hop)

## Every room opens exactly at its step: reachable now iff its opening step is behind her.
func _check_reach(after: String) -> void:
	var reach := g.reachable("R02")
	for rid in OPENS:
		var opener: String = OPENS[rid]
		var should: bool = opener == "" or _done(opener)
		check((rid in reach) == should, "after %s: %s %s" % [after if after != "" else "begin", rid,
			"reachable" if should else "still shut"])

## Each step survives a save: the whole saved state (flags, tide, band, room, inventory,
## notebook, every room's local state) comes back byte-identical, and so do tide and band.
func _check_save(after: String) -> void:
	var t := GameSim.new()
	var saved := JSON.stringify(g.to_dict())
	check(t.from_dict(JSON.parse_string(saved)), "after %s: the save loads" % after)
	check(t.tide() == g.tide() and t.weather_band() == g.weather_band(), "after %s: tide and band survive a save" % after)
	var again := JSON.stringify(t.to_dict())
	if again != saved:
		var a: Dictionary = JSON.parse_string(saved)
		var b: Dictionary = JSON.parse_string(again)
		var diff := []
		for k in a:
			if k == "rooms":
				for rid in a.rooms:
					if JSON.stringify(a.rooms[rid]) != JSON.stringify(b.rooms.get(rid)):
						for f in a.rooms[rid]:
							if JSON.stringify(a.rooms[rid][f]) != JSON.stringify(b.rooms.get(rid, {}).get(f)):
								diff.append("%s.%s" % [rid, f])
			elif JSON.stringify(a[k]) != JSON.stringify(b.get(k)):
				diff.append(k)
		check(false, "after %s: the save round-trips byte-identical (differs in %s)" % [after, diff])

## P26's checkpoint replays to both endings; endings_seen keeps both.
func _endings() -> void:
	check(g.value("ending_choice") == "sever" and g.view == "end", "ending: sever")
	_qd("return_decision")
	check(g.flag("P26") and not g.flag("P27") and g.value("ending_choice") == "" and g.state.room == "R12",
		"replay returns to the P26 decision")
	check(g.has_item("witness_bridge"), "replay: the bridge is back in hand")
	_r12_room()   # the checkpoint is taken at the second preview, on the routing wall
	for a in ["to_routing", "bridge_seat", "bridge_seat", "preview"]:
		_qd(a)
	_qd("btn_continue")
	check(chamber.chosen() == "continue", "ending: CONTINUE pressed")
	var guard := 0
	while g.view != "end" and guard < 20:
		_qd("ending_next")
		guard += 1
	var seen: Array = g.value("endings_seen")
	check(g.value("ending_choice") == "continue" and "sever" in seen and "continue" in seen,
		"ending: continue; both endings seen (%s)" % [seen])

## True when any line in `ev` is a story line.
func _story(ev: Array) -> bool:
	for e in ev:
		if e.type == "say" and bool(e.get("story", false)):
			return true
	return false

## One action: a real click when a clicker drives the scene, else straight to the sim.
func _qd(action: String) -> Array:
	if clicker != null:
		return clicker.qd(action)
	return g.dispatch(action)
