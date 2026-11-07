extends "res://tests/rooms/room_test_base.gd"
## R02, the Intake Office: the slice tests (rounds 1-3) that still hold, re-timed to the
## cards' T1X, plus view B, P20, the look-away and notice escalation across every tide.
## Logic (R02Sim inside a GameSim) and the game scene's hit-testing/save/presentation
## wiring with R02 mounted. Run after an import:
##   godot --headless --path . --script tests/rooms/R02_test.gd

## A fresh game; the office sim inside it (the slice's OfficeSim.new()).
func new_sim() -> R02Sim:
	return GameSim.new().room("R02")

## Tide I's instruments done (P02 in the listening room, P03 in the chart room).
func tide1(s: R02Sim) -> void:
	s.game.set_flag("P02")
	s.game.set_flag("P03")

func office(g: GameSim) -> R02Sim:
	return g.room("R02") as R02Sim

func count_ev(ev: Array, type: String, id: String) -> int:
	var n := 0
	for e in ev:
		if e.type == type and e.get("id", "") == id: n += 1
	return n

func fx_ev(ev: Array, id: String) -> Array:
	var out := []
	for e in ev:
		if e.type == "fx" and e.id == id: out.append(e)
	return out

func say_ev(ev: Array, fragment: String) -> Dictionary:
	for e in ev:
		if e.type == "say" and fragment in e.text: return e
	return {}

func dial_to(s: R02Sim, code: Array) -> void:
	for i in 4:
		while int(s.state.drawer_dial[i]) != code[i]:
			s.dispatch("dial_%d" % i)

## Opens the closure report, enters the right answer by clicks, and files it. The view
## stays on the report: the door only answers once she steps back (file_and_back).
func file_report(s: R02Sim) -> Array:
	s.dispatch("papers")
	set_fields(s, R02Sim.REPORT_ANSWER)
	set_time(s, R02Sim.REPORT_TIME_ANSWER)
	return s.dispatch("file_report")

## Files the report and steps back from it, so the door unlatches. Returns both clicks' events.
func file_and_back(s: R02Sim) -> Array:
	var ev := file_report(s)
	ev.append_array(s.dispatch("back"))
	return ev

func set_time(s: R02Sim, want: Array) -> void:
	for i in 4:
		while int(s.state.report_time[i]) != want[i]:
			s.dispatch("rtime_%d" % i)

func count_say(ev: Array, text: String) -> int:
	var n := 0
	for e in ev:
		if e.type == "say" and e.text == text: n += 1
	return n

## Builds the state just before the wet seat, by real actions.
func sim_before_chair() -> R02Sim:
	var s := new_sim()
	s.debug_jump(2)
	tide1(s)
	s.dispatch("puddle")
	s.dispatch("drawer")
	dial_to(s, [1, 8, 5, 2])
	s.dispatch("try_drawer")
	s.dispatch("back")
	s.dispatch("logbook")
	s.dispatch("back")
	return s

func run_tests() -> void:
	skeleton_checks("R02", [], 1)
	test_full_playthrough()
	test_p01_rules()
	test_gating()
	test_hints_progress()
	test_save_roundtrip_and_tamper()
	test_determinism()
	test_drawer_puzzle()
	test_log_rows()
	test_new_gates()
	test_stage_text_drift()
	test_notebook_keeps_evidence()
	test_story_flags()
	test_milestone_saves()
	test_title_menu()
	test_report_gate()
	test_chair_knock()
	test_history()
	test_tide_rhythm()
	test_drawer_near_misses()
	test_photo_behind()
	test_soundings()
	test_revisits()
	test_listen_once()
	test_threshold_sim()
	test_end_lines()
	test_unlatch_on_back()
	test_report_time()
	test_report_misses()
	test_report_saves()
	test_round3_determinism()
	test_story_text_r3()
	test_contours()
	test_chart_tenth()
	test_look_away()
	test_continuity()
	test_endings()
	test_corridor_opens_on_lamp()
	test_drawer_items()
	test_rewrite_needs_tide1()
	test_callback()
	test_t1x_latch()
	test_threshold_converges()
	test_facing()
	test_look_away_bands()
	test_notices()
	test_hotspots_every_tide()
	test_photo_states()
	test_service_door()
	test_receipt()
	test_contract()
	test_p20()
	test_apply_ending()
	test_debug_prepare()
	test_debug_jumps()
	test_record_moves()
	test_all_observations()
	test_clock_and_needle()
	await test_scene_wiring()
	await test_presentation_cleanup()
	await test_scheduler()
	await test_breath_and_knock()
	await test_threshold_scene()
	await test_end_scene()
	await test_click_driver()
	await test_chain_gate_chair()
	await test_chain_gate_drawer()
	await test_hint_after_chain()
	await test_qa_nits()
	await view_checks("R02")
	await test_view_b()
	await test_view_escalation()
	await test_view_notice_and_board()

func test_full_playthrough() -> void:
	var s := new_sim()
	check(s.view == "title", "starts on title")
	s.dispatch("begin")
	check(s.view == "room" and s.objective() == "lamp", "begin -> room, objective lamp")
	for a in ["coat", "hooks", "map", "mug", "stove", "window", "papers", "back"]:
		s.dispatch(a)
	check(s.view == "room", "papers close-up returns to room")
	s.dispatch("lamp")
	check(s.view == "repair", "lamp opens repair")
	s.dispatch("toggle_supply")
	s.dispatch("select_b")
	s.dispatch("fit")
	var ev := s.dispatch("toggle_supply")
	check(s.state.p01_complete and s.view == "room", "P01 completes and returns to room")
	check(has_ev(ev, "fx", "lamp_on") and has_ev(ev, "sfx", "latch_far"), "lamp_on + distant latches")
	check(s.objective() == "log", "objective -> log")
	s.dispatch("chair")
	check(s.has_seen("shadow"), "chair after lamp records wrong shadow")
	s.dispatch("logbook")
	check(s.state.log_read and s.has_seen("handwriting"), "log read records handwriting")
	ev = s.dispatch("back")
	check(has_ev(ev, "fx", "sea_fade"), "leaving the log fades the sea")
	check(s.objective() == "changed", "objective -> changed")
	s.dispatch("window")
	check(s.has_seen("silent") and s.has_seen("piling"), "window: silent sea and the ninth piling")
	ev = s.dispatch("back")
	check(not has_ev(ev, "fx", "sea_fade"), "sea fade plays once")
	s.dispatch("puddle")
	check(s.state.prints_seen, "puddle reveals prints after the log")
	check(s.objective() == "drawer", "objective -> drawer")
	s.dispatch("drawer")
	check(s.view == "drawer", "drawer close-up opens")
	ev = s.dispatch("try_drawer")
	check(not s.state.drawer_open and has_ev(ev, "sfx", "clunk"), "wrong try clunks")
	dial_to(s, [1, 8, 5, 2])
	ev = s.dispatch("try_drawer")
	check(s.state.drawer_open and has_ev(ev, "sfx", "drawer") and has_ev(ev, "fx", "drawer_open"), "1852 opens the drawer")
	s.dispatch("back")
	check(s.view == "room" and s.objective() == "instruments", "objective -> instruments (Tide I's two jobs)")
	check(s.game.has_item("venn_tide_sheet") and s.game.has_item("inspection_lens"), "the drawer hands over his sheet and lens")
	s.dispatch("logbook")
	check(not s.state.log_rewritten, "no rewrite before the instruments")
	s.dispatch("back")
	tide1(s)
	check(s.objective() == "reread", "objective -> reread")
	ev = s.dispatch("logbook")
	check(s.state.log_rewritten and has_ev(ev, "fx", "log_write"), "the log rewrites itself")
	s.dispatch("back")
	check(s.objective() == "chair", "objective -> chair")
	ev = s.dispatch("chair")
	check(s.state.seat_wet and has_ev(ev, "sfx", "sting"), "wet seat + sting")
	check(has_ev(ev, "sfx", "knock_glass") and not has_ev(ev, "sfx", "latch_near"), "the knock follows; the latch does not")
	check(s.objective() == "report", "objective -> report")
	ev = s.dispatch("door")
	check(s.view == "room" and "Latched" in says(ev), "chair then door at once: still latched")
	ev = file_report(s)
	check(s.state.report_filed and not has_ev(ev, "sfx", "latch_near") and s.view == "report", "filing keeps the report open")
	check(s.objective() == "filed", "objective -> filed")
	ev = s.dispatch("back")
	check(has_ev(ev, "sfx", "latch_near") and s.view == "room", "stepping back unlatches the door")
	check(s.objective() == "leave", "objective -> leave")
	ev = s.dispatch("door")
	check(s.view == "threshold" and not s.state.finished, "door -> threshold")
	check(has_ev(ev, "fx", "threshold") and has_ev(ev, "sfx", "door") and says(ev) == "", "threshold: door + fx, no line")
	s.dispatch("continue")
	check(s.view == "end" and s.state.finished, "continue reaches the end card")
	check(s.game.flag("closure_report_filed") and not s.game.flag("t1x_threshold_crossed"),
		"the report flag is recorded; the threshold flag waits for the card")
	check(s.game.value("movement_events") == ["lamp_mended", "log_read", "drawer_opened", "report_signed", "held_still"],
		"the office records its movement events in order (%s)" % [s.game.value("movement_events")])
	ev = s.dispatch("end_continue")
	check(s.game.state.room == "R03" and s.state.finished and s.game.tide() == 2, "Go on: Tide II, in the chart room")
	check(s.game.flag("t1x_threshold_crossed"), "the threshold flag is recorded")
	check(s.game.exit_open("R02", "R03") and s.game.exit_open("R02", "R04"), "the corridor opens on the instrument rooms")
	s.game.dispatch("go:R02")
	check(s.game.state.room == "R02" and s.objective() == "away_t2", "back in the office: the objective points away")
	ev = s.dispatch("door")
	check(s.view == "room" and says(ev).begins_with("A corridor."), "the door is only a door afterwards")
	s.dispatch("restart")
	check(s.view == "title" and not s.state.p01_complete, "restart resets")

func test_p01_rules() -> void:
	var s := new_sim()
	s.dispatch("begin"); s.dispatch("lamp")
	var ev := s.dispatch("fit")
	check(not s.state.bridge_installed and "spare" in says(ev), "fit with nothing selected asks for a spare")
	s.dispatch("select_b")
	ev = s.dispatch("fit")
	check(not s.state.bridge_installed and has_ev(ev, "fx", "spark"), "fit with supply ON sparks, installs nothing")
	s.dispatch("toggle_supply")
	s.dispatch("select_c")
	s.dispatch("fit")
	check(not s.state.bridge_installed, "curved C never seats")
	check(s.selected == "C", "C is not consumed")
	s.dispatch("select_b")
	s.dispatch("fit")
	check(s.state.bridge_installed and not s.state.p01_complete, "installation alone does not complete P01")
	s.dispatch("toggle_supply")
	check(s.state.p01_complete, "B + supply ON completes P01")

func test_gating() -> void:
	var s := new_sim()
	s.dispatch("begin")
	s.dispatch("logbook")
	check(not s.state.log_read, "log unreadable before the lamp")
	s.dispatch("back")
	s.dispatch("puddle")
	check(not s.state.prints_seen, "no prints before the log")
	s.dispatch("chair")
	check(not s.state.seat_wet, "no wet seat before prints")
	s.dispatch("door")
	check(s.view == "room", "door does not end the slice early")
	s.dispatch("hint")
	check(s.view == "room", "hint does not navigate")

func test_hints_progress() -> void:
	var s := new_sim()
	s.dispatch("begin")
	var h1 := says(s.dispatch("hint"))
	var h2 := says(s.dispatch("hint"))
	var h3 := says(s.dispatch("hint"))
	var h4 := says(s.dispatch("hint"))
	check(h1 != h2 and h2 != h3 and h3 == h4, "hints escalate and cap at the solution")
	check("bridge B" in h3, "final lamp hint gives the solution")
	s.debug_jump(1)
	check(says(s.dispatch("hint")) == R02Sim.HINTS["log"][0], "hints reset for the new objective")
	for obj in ["drawer", "reread", "chair", "report", "filed", "leave"]:
		check(R02Sim.HINTS.has(obj) and R02Sim.HINTS[obj].size() == 3, "three hints for " + obj)
	check("1-8-5-2" in R02Sim.HINTS["drawer"][2], "drawer hint 3 gives the code")

func test_save_roundtrip_and_tamper() -> void:
	var s := new_sim()
	s.debug_jump(2)
	s.dispatch("puddle")
	var d = JSON.parse_string(JSON.stringify(s.to_dict()))
	var t := new_sim()
	check(t.from_dict(d), "save loads")
	check(t.state.prints_seen and t.state.log_read and t.state.p01_complete, "progress survives")
	check(t.has_seen("prints"), "observations survive")
	check(t.view == "room", "load lands in the room")
	var bad := new_sim()
	check(not bad.from_dict({"schema": 1}), "schema 1 rejected")
	check(not bad.from_dict({"schema": 2, "started": true}), "schema 2 rejected")
	check(not bad.from_dict({"schema": 3, "started": true}), "schema 3 rejected")
	check(not bad.from_dict({"schema": 4, "started": true}), "schema 4 rejected: old saves fall back to the title")
	check(not bad.from_dict("junk"), "junk rejected")
	var tampered := new_sim()
	tampered.from_dict({"schema": 5, "started": true, "seat_wet": true, "seen": ["nope", 3]})
	check(not tampered.state.seat_wet, "orphan progress flags are dropped")
	check(tampered.seen().is_empty(), "unknown observations are dropped")
	var dials := new_sim()
	dials.from_dict({"schema": 5, "drawer_dial": [12, -3, 5, 2]})
	check(dials.state.drawer_dial == [9, 0, 5, 2], "dials clamp to 0-9")
	dials.from_dict({"schema": 5, "drawer_dial": [1, 2, 3]})
	check(dials.state.drawer_dial == [0, 0, 0, 0], "a short dial array is ignored")
	dials.from_dict({"schema": 5, "drawer_dial": ["1", 8, 5, 2]})
	check(dials.state.drawer_dial == [0, 0, 0, 0], "non-numeric dials are ignored")

func test_determinism() -> void:
	var script := ["begin", "lamp", "fit", "toggle_supply", "select_c", "fit", "select_b", "fit",
		"toggle_supply", "logbook", "back", "puddle", "drawer", "try_drawer"]
	for i in 1: script.append("dial_0")
	for i in 8: script.append("dial_1")
	for i in 5: script.append("dial_2")
	for i in 2: script.append("dial_3")
	script.append_array(["try_drawer", "look_photo", "photo", "back", "back", "map", "logbook", "back", "chair",
		"coat", "window", "door", "papers", "file_report", "field_0", "field_0", "field_1", "field_2",
		"rtime_0"])
	for i in 9: script.append("rtime_1")
	for i in 3: script.append("rtime_2")
	for i in 4: script.append("rtime_3")
	script.append_array(["file_report", "logbook", "back", "hint", "door", "hint", "continue"])
	var a := new_sim()
	var b := new_sim()
	tide1(a)
	tide1(b)
	var log_a := []
	var log_b := []
	for act in script:
		log_a.append(a.dispatch(act))
		log_b.append(b.dispatch(act))
	check(a.view == "end", "determinism script reaches the end card")
	check(JSON.stringify(log_a) == JSON.stringify(log_b), "same actions -> same events")
	check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "same actions -> same state")

# ---------------------------------------------------------------------------
# P-DRAWER
# ---------------------------------------------------------------------------
func test_drawer_puzzle() -> void:
	var s := new_sim()
	s.debug_jump(2)
	s.dispatch("puddle")
	var ev := s.dispatch("drawer")
	check(s.view == "drawer" and has_ev(ev, "sfx", "dial") and "Four brass dials" in says(ev), "drawer opens its close-up")
	var before := JSON.stringify(s.to_dict())
	ev = s.dispatch("try_drawer")
	check(JSON.stringify(s.to_dict()) == before, "a wrong try changes no state")
	check(has_ev(ev, "sfx", "clunk") and says(ev) == "The drawer doesn't give.", "wrong try: clunk only")
	dial_to(s, [0, 7, 1, 3])
	check("tomorrow" in says(s.dispatch("try_drawer")), "07:13 gets its own nudge")
	dial_to(s, [1, 9, 3, 1])
	check("year" in says(s.dispatch("try_drawer")), "1931 gets its own nudge")
	check(not s.state.drawer_open, "near misses don't open")
	# Wrap 9 -> 0
	var w := new_sim()
	w.debug_jump(1)
	w.dispatch("drawer")
	for i in 9: w.dispatch("dial_2")
	check(int(w.state.drawer_dial[2]) == 9, "dial counts up")
	ev = w.dispatch("dial_2")
	check(int(w.state.drawer_dial[2]) == 0 and has_ev(ev, "sfx", "dial") and says(ev) == "", "dial wraps 9 -> 0 silently with a click")
	# Right code before the log is read.
	var early := new_sim()
	early.debug_jump(1)
	early.dispatch("drawer")
	dial_to(early, [1, 8, 5, 2])
	ev = early.dispatch("try_drawer")
	check(not early.state.drawer_open and "I don't know it yet" in says(ev), "1852 before the log does not open")
	# Right code after the log.
	dial_to(s, [1, 8, 5, 2])
	ev = s.dispatch("try_drawer")
	check(s.state.drawer_open and s.has_seen("watch") and s.has_seen("photo"), "1852 after the log opens, records watch + photo")
	check("It gives." in says(ev) and "nothing outside this window" in says(ev), "drawer reveal lines")
	var code := JSON.stringify(s.state.drawer_dial)
	ev = s.dispatch("dial_0")
	check(JSON.stringify(s.state.drawer_dial) == code and ev.is_empty(), "dials ignore input once open")
	check(says(s.dispatch("look_watch")) == "Stopped at 18:52.", "look at the watch")
	check(says(s.dispatch("look_photo")) == "Me, from outside. From the sea side." and s.view == "photo", "look at the photo")
	s.dispatch("back")
	check(s.view == "drawer", "back from the photograph returns to the drawer")
	s.dispatch("back")
	ev = s.dispatch("drawer")
	check("back of my own head" in says(ev), "open drawer revisit line")
	var closed := new_sim()
	closed.debug_jump(2)
	closed.dispatch("drawer")
	check(closed.dispatch("look_watch").is_empty(), "nothing to look at in a locked drawer")

# ---------------------------------------------------------------------------
# Log rows
# ---------------------------------------------------------------------------
func test_log_rows() -> void:
	var s := new_sim()
	s.debug_jump(2)
	tide1(s)
	check(s.log_rows().size() == 9, "9 log rows before the rewrite")
	s.dispatch("puddle")
	s.dispatch("logbook")
	check(not s.state.log_rewritten and s.log_rows().size() == 9, "no rewrite without the drawer")
	s.dispatch("back")
	var nodrawer := new_sim()
	nodrawer.debug_jump(2)
	nodrawer.dispatch("drawer")
	dial_to(nodrawer, [1, 8, 5, 2])
	nodrawer.dispatch("try_drawer")
	nodrawer.dispatch("back")
	nodrawer.dispatch("logbook")
	check(nodrawer.state.drawer_open and not nodrawer.state.log_rewritten, "no rewrite before tide_done(1)")
	s.dispatch("drawer")
	dial_to(s, [1, 8, 5, 2])
	s.dispatch("try_drawer")
	s.dispatch("back")
	check(not s.state.log_rewritten, "the rewrite waits for a logbook open")
	s.dispatch("window")
	s.dispatch("hint")
	check(not s.state.log_rewritten, "nothing else triggers the rewrite")
	var ev := s.dispatch("logbook")
	check(s.state.log_rewritten and s.log_rows().size() == 12, "12 rows after the rewrite")
	check(s.has_seen("rewritten") and "ink is still wet" in says(ev), "rewrite records + speaks")
	s.dispatch("back")
	ev = s.dispatch("logbook")
	check(not has_ev(ev, "fx", "log_write") and "only one here to locate" in says(ev), "rewrite happens once")
	s.dispatch("back")
	s.dispatch("chair")
	check(s.log_rows().size() == 12, "still 12 rows after the wet seat: the door line waits for the report")
	ev = s.dispatch("logbook")
	check(not s.state.foretold_door and not has_ev(ev, "fx", "log_write"), "no foretelling before the report")
	s.dispatch("back")
	file_and_back(s)
	check(s.log_rows().size() == 13, "13 rows once the report is filed")
	check(s.log_rows()[12][3] == "She opens the door. It is already open.", "the final line foretells the door")
	ev = s.dispatch("logbook")
	check(s.state.foretold_door and has_ev(ev, "fx", "log_write") and says(ev) == "It has the next line already.", "foretold door once")
	s.dispatch("back")
	ev = s.dispatch("logbook")
	check(not has_ev(ev, "fx", "log_write") and "dry now" in says(ev), "foretold door does not repeat; the line has dried")
	var a := sim_before_chair()
	var b := sim_before_chair()
	check(JSON.stringify(a.log_rows()) == JSON.stringify(b.log_rows()), "two sims give identical rows")
	for r in R02Sim.LOG_LATER:
		check(r[4] == true, "later rows are in her hand")

# ---------------------------------------------------------------------------
# Gates
# ---------------------------------------------------------------------------
func test_new_gates() -> void:
	var s := new_sim()
	s.debug_jump(2)
	s.dispatch("puddle")
	var ev := s.dispatch("chair")
	check(not s.state.seat_wet and "Not yet" in says(ev), "chair before the rewrite stays dry, even with prints")
	s.dispatch("drawer")
	dial_to(s, [1, 8, 5, 2])
	s.dispatch("try_drawer")
	s.dispatch("back")
	s.dispatch("chair")
	check(not s.state.seat_wet, "chair stays dry with the drawer open but the log unread")
	s.dispatch("door")
	check(s.view == "room", "door does not reach threshold before the wet seat")
	s.dispatch("continue")
	check(s.view == "room" and not s.state.finished, "continue does nothing in the room")
	var t := new_sim()
	for a in ["door", "continue", "chair", "drawer"]:
		t.dispatch(a)
	check(t.view == "title" and not t.state.finished, "threshold unreachable from the title")
	var th := new_sim()
	th.debug_jump(4)
	th.dispatch("door")
	check(th.view == "threshold", "door with the report filed -> threshold")
	th.dispatch("back")
	check(th.view == "threshold", "no going back from the threshold")
	th.dispatch("chair")
	check(th.view == "threshold", "room hotspots do nothing at the threshold")
	th.dispatch("notebook")
	check(th.view == "notebook" and th.return_view == "room" and th.local_view == "threshold", "notebook works at the threshold")
	th.dispatch("back")
	check(th.view == "threshold", "notebook returns to the threshold")
	th.dispatch("menu")
	th.dispatch("resume")
	check(th.view == "threshold", "menu returns to the threshold")
	check(not th.is_closeup("threshold") and th.is_closeup("drawer") and th.is_closeup("report"),
		"is_closeup: drawer and report yes, threshold no")

# ---------------------------------------------------------------------------
# Stage text drift
# ---------------------------------------------------------------------------
func test_stage_text_drift() -> void:
	var window := []
	var maps := []
	for st in [1, 2, 3]:
		var s := new_sim()
		s.debug_jump(st)
		window.append(says(s.dispatch("window")))
		maps.append(says(s.dispatch("map")))
	check(window[0] != window[1] and window[1] != window[2] and window[0] != window[2], "window line drifts across stages 1-3")
	check(maps[0] != maps[1], "map line drifts between stages 1 and 2")
	var s3 := new_sim()
	s3.debug_jump(3)
	s3.dispatch("hooks")
	check(not s3.has_seen("tag") and s3.has_seen("hooks"), "hooks at T1X: no tag yet")
	var w3 := s3.dispatch("window")
	check(not s3.has_seen("horizon") and not s3.has_seen("eye") and s3.has_seen("silent"), "window at T1X: silent, no horizon or eye")
	check(says(w3) == "Nine pilings. The sea moving against them, without a sound.", "the T1X window line")
	var p := new_sim()
	p.debug_jump(1)
	var ev := p.dispatch("papers")
	check(p.has_seen("note") and "Lamp service completed. A.M." in says(ev), "papers after the lamp: the A.M. line")
	p.dispatch("back")
	ev = p.dispatch("papers")
	check(not "A.M." in says(ev) and says(ev) == "In the lamplight there's pencil beneath the duty card.", "A.M. line plays once")
	var d := new_sim()
	d.debug_jump(2)
	var before_drawer := says(d.dispatch("window"))
	d.dispatch("drawer")
	dial_to(d, [1, 8, 5, 2])
	d.dispatch("try_drawer")
	d.dispatch("back")
	check(says(d.dispatch("window")) != before_drawer, "the ninth piling line changes once the drawer is open")

# ---------------------------------------------------------------------------
# Notebook keeps evidence
# ---------------------------------------------------------------------------
## One real Tide I run sees every observation Tide I can show (REACHABLE_BY_T1X).
func t1x_full_run() -> R02Sim:
	var s := new_sim()
	tide1(s)
	s.dispatch("begin")
	for a in ["coat", "hooks", "map", "mug", "stove", "papers", "read_contract", "back"]:
		s.dispatch(a)
	for a in ["lamp", "toggle_supply", "select_b", "fit", "toggle_supply"]:
		s.dispatch(a)
	for a in ["papers", "back", "chair", "logbook", "back", "window", "map", "puddle", "drawer"]:
		s.dispatch(a)
	dial_to(s, [1, 8, 5, 2])
	for a in ["try_drawer", "look_photo", "photo", "back", "back", "map", "logbook", "back", "chair",
			"window", "hooks", "map", "puddle"]:
		s.dispatch(a)
	file_and_back(s)
	return s

func test_notebook_keeps_evidence() -> void:
	var s := t1x_full_run()
	var missing := []
	for id in R02Sim.REACHABLE_BY_T1X:
		if not s.has_seen(id):
			missing.append(id)
	check(missing.is_empty(), "every Tide I observation reachable in one run (missing: %s)" % [missing])
	for id in R02Sim.REACHABLE_BY_T1X:
		check(R02Sim.OBSERVATIONS.has(id), "REACHABLE_BY_T1X id %s is an observation" % id)
	s.dispatch("door")
	s.dispatch("continue")
	check(R02Sim.END_ALL_SEEN in s.end_lines(), "the card says nothing went unrecorded")
	var j := new_sim()
	j.debug_jump(4)
	var had: Array = j.seen().duplicate()
	for id in R02Sim.ROOM_IDS:
		j.dispatch(id)
		j.dispatch("back")
	j.dispatch("turn")
	for id in R02Sim.HOTSPOTS_B:
		j.dispatch(id)
		j.dispatch("back")
	for id in had:
		check(j.has_seen(id), "evidence kept after the sweep: " + id)

# ---------------------------------------------------------------------------
# Story flags
# ---------------------------------------------------------------------------
func test_story_flags() -> void:
	var s := new_sim()
	s.dispatch("begin")
	for a in ["lamp", "toggle_supply", "select_b", "fit"]:
		s.dispatch(a)
	var ev := s.dispatch("toggle_supply")
	var latch := say_ev(ev, "two latches")
	check(latch.get("story", false) and is_equal_approx(latch.delay, 1.6), "latch line is story at 1.6 s")
	check(say_ev(ev, "Light.").get("story", false), "'Light.' is story")
	s.dispatch("logbook")
	ev = s.dispatch("back")
	check(say_ev(ev, "Listen").get("story", false), "Listen is story")
	var c := sim_before_chair()
	ev = c.dispatch("chair")
	check(say_ev(ev, "Three taps").get("story", false) and say_ev(ev, "Low down").get("story", false), "knock lines are story")
	var d := new_sim()
	d.debug_jump(2)
	d.dispatch("drawer")
	dial_to(d, [1, 8, 5, 2])
	ev = d.dispatch("try_drawer")
	var all_story := true
	for e in ev:
		if e.type == "say" and not e.story:
			all_story = false
	check(all_story and says(ev).split(" | ").size() == 7, "all seven drawer lines are story")
	var b := new_sim()
	ev = b.dispatch("begin")
	check(ev[1].delay == 3.2, "opening second line at 3.2 s")

# ---------------------------------------------------------------------------
# Saves at each new milestone
# ---------------------------------------------------------------------------
func roundtrip(s: R02Sim) -> R02Sim:
	var t := new_sim()
	check(t.from_dict(JSON.parse_string(JSON.stringify(s.to_dict()))), "milestone save loads")
	return t

func test_milestone_saves() -> void:
	var s := new_sim()
	s.debug_jump(2)
	tide1(s)
	s.dispatch("puddle")
	s.dispatch("drawer")
	dial_to(s, [1, 8, 5, 2])
	s.dispatch("try_drawer")
	var t := roundtrip(s)
	check(t.state.drawer_open and t.state.drawer_dial == [1, 8, 5, 2] and t.has_seen("photo"), "drawer_open round-trips")
	check(t.view == "room", "a drawer save lands in the room")
	s.dispatch("back"); s.dispatch("logbook")
	t = roundtrip(s)
	check(t.state.log_rewritten and t.log_rows().size() == 12, "log_rewritten round-trips")
	s.dispatch("back"); s.dispatch("chair")
	t = roundtrip(s)
	check(t.state.seat_wet and t.objective() == "report", "seat_wet round-trips")
	file_and_back(s)
	t = roundtrip(s)
	check(t.state.report_filed and t.objective() == "leave" and t.has_seen("report"), "report_filed round-trips")
	s.dispatch("logbook")
	t = roundtrip(s)
	check(t.state.foretold_door, "foretold_door round-trips")
	s.dispatch("back"); s.dispatch("door")
	check(s.view == "threshold", "at the threshold")
	t = roundtrip(s)
	check(t.view == "room" and t.state.seat_wet and not t.state.finished, "a threshold save lands in the room")
	var bad := new_sim()
	bad.from_dict({"schema": 5, "started": true, "p01_complete": true, "log_read": true,
		"prints_seen": true, "log_rewritten": true})
	check(not bad.state.log_rewritten, "log_rewritten without drawer_open is dropped")
	bad.from_dict({"schema": 5, "started": true, "p01_complete": true, "log_read": true,
		"drawer_open": true, "log_rewritten": true})
	check(bad.state.log_rewritten, "log_rewritten no longer needs prints_seen")
	bad.from_dict({"schema": 5, "started": true, "drawer_open": true})
	check(not bad.state.drawer_open, "drawer_open without log_read is dropped")
	bad.from_dict({"schema": 5, "started": true, "p01_complete": true, "log_read": true, "prints_seen": true,
		"drawer_open": true, "seat_wet": true, "foretold_door": true})
	check(not bad.state.seat_wet and not bad.state.foretold_door, "seat_wet needs log_rewritten; foretold needs seat_wet")
	bad.from_dict({"schema": 5, "initialled": true})
	check(not bad.state.initialled, "initialled needs the lamp")

# ---------------------------------------------------------------------------
# Title menu
# ---------------------------------------------------------------------------
func test_title_menu() -> void:
	var s := new_sim()
	s.dispatch("menu")
	check(s.view == "menu" and s.return_view == "title", "menu from the title")
	s.dispatch("toggle_motion")
	check(not s.game.settings.motion, "settings work before the opening")
	s.dispatch("notebook")
	s.dispatch("hint")
	check(s.view == "menu" and not s.game.state.started, "story actions do nothing in the title menu")
	s.dispatch("resume")
	check(s.view == "title" and not s.game.state.started, "resume returns to the title")
	s.dispatch("menu")
	s.dispatch("back")
	check(s.view == "title", "back from the title menu returns to the title")
	s.dispatch("begin")
	check(s.view == "room" and not s.game.settings.motion, "the setting survives into the game")

# ---------------------------------------------------------------------------
# Scene wiring
# ---------------------------------------------------------------------------
func new_scene(path: String) -> Node:
	var scene = load("res://game/core/game.tscn").instantiate()
	scene.save_path = path
	scene.migrate_slice_save = false
	GameView.remove_saves(path)
	root.add_child(scene)
	return scene

func test_scene_wiring() -> void:
	var scene = new_scene("user://office_wiring_test.json")
	await process_frame
	check(scene.action_at(Vector2(700, 500)) == "begin", "title click begins")
	scene.dispatch("begin")
	check(scene.action_at(Vector2(330, 560)) == "lamp", "lamp hotspot")
	check(scene.action_at(Vector2(950, 690)) == "mug", "mug beats papers/desk")
	check(scene.action_at(Vector2(1300, 500)) == "door", "door hotspot")
	check(scene.action_at(Vector2(900, 860)) == "drawer", "drawer hotspot")
	check(scene.action_at(Vector2(1110, 915)) == "puddle", "puddle hotspot")
	check(scene.action_at(Vector2(1180, 45)) == "notebook", "HUD notebook beats hotspots")
	check(scene.action_at(Vector2(1000, 45)) == "", "no Back in the room")
	scene.dispatch("lamp")
	check(scene.action_at(Vector2(400, 640)) == "toggle_supply", "repair supply switch")
	check(scene.action_at(Vector2(200, 920)) == "select_b", "repair spare B")
	check(scene.action_at(Vector2(1000, 45)) == "back", "Back in the repair close-up")
	scene.dispatch("toggle_supply"); scene.dispatch("select_b"); scene.dispatch("fit"); scene.dispatch("toggle_supply")
	scene.dispatch("logbook")
	check(scene.action_at(Vector2(1000, 45)) == "back", "Back in the logbook")
	scene.dispatch("back")
	scene.dispatch("drawer")
	check(scene.action_at(Vector2(484, 500)) == "dial_0", "top of dial 0 turns it up")
	check(scene.action_at(Vector2(964, 500)) == "dial_3", "top of dial 3 turns it up")
	check(scene.action_at(Vector2(484, 600)) == "dial_down_0", "bottom of dial 0 turns it down")
	check(scene.action_at(Vector2(724, 728)) == "try_drawer", "try the drawer")
	check(scene.action_at(Vector2(1000, 45)) == "back", "Back in the drawer")
	scene.dispatch("back")
	scene.dispatch("notebook")
	check(scene.action_at(Vector2(1000, 45)) == "back", "Back in the notebook")
	scene.dispatch("back")
	scene.dispatch("menu")
	check(scene.action_at(Vector2(1180, 45)) == "", "HUD buttons ignored in the menu")
	scene.dispatch("resume")
	var again = new_scene("user://office_wiring_test_2.json")
	again.save_path = scene.save_path
	again.room_sim().reset()
	again._load_progress()
	check(again.room_sim().state.p01_complete and again.room_sim().view == "room", "scene reload restores P01")
	# Corrupt save: no engine error, falls back to the title.
	var f := FileAccess.open("user://office_corrupt_test.json", FileAccess.WRITE)
	f.store_string("{not json")
	f = null
	var corrupt = load("res://game/core/game.tscn").instantiate()
	corrupt.save_path = "user://office_corrupt_test.json"
	root.add_child(corrupt)
	await process_frame
	check(corrupt.room_sim().view == "title", "corrupt save falls back to the title")
	# The report gate in the scene: rows and the sign button.
	scene.room_jump("R02", 3)
	scene.dispatch("door")
	check(scene.room_sim().view == "room", "scene: the door is latched until the report is filed")
	scene.dispatch("papers")
	check(scene.room_sim().view == "report", "scene: papers open the closure report")
	check(scene.action_at(Vector2(700, 312)) == "field_0" and scene.action_at(Vector2(1100, 442)) == "field_1"
		and scene.action_at(Vector2(1100, 702)) == "field_2", "report rows are clickable across their width")
	check(scene.action_at(Vector2(848, 540)) == "rtime_0" and scene.action_at(Vector2(848, 600)) == "rtime_down_0"
		and scene.action_at(Vector2(1068, 540)) == "rtime_3" and scene.action_at(Vector2(1068, 600)) == "rtime_down_3",
		"the time dials: top half up, bottom half down")
	check(scene.action_at(Vector2(700, 572)) == "", "the time row's label is not a field")
	check(scene.action_at(Vector2(724, 888)) == "file_report", "sign and file")
	check(scene.action_at(Vector2(1000, 45)) == "back", "Back in the report")
	# Threshold gate and the end-card grace.
	scene.room_jump("R02", 4)
	scene.dispatch("door")
	check(scene.room_sim().view == "threshold", "scene reaches the threshold")
	check(scene.action_at(Vector2(1300, 500)) == "", "no continue before she holds still")
	check(scene.action_at(Vector2(640, 650)) == "turn", "the chair turns her round, at any time")
	check(scene.action_at(Vector2(1180, 45)) == "notebook", "HUD still works at the threshold")
	scene.room_view.continue_ready = true
	check(scene.action_at(Vector2(1300, 500)) == "continue", "continue once ready, through the doorway")
	check(scene.action_at(Vector2(700, 400)) == "", "elsewhere is nothing at the threshold")
	scene.dispatch("continue")
	check(scene.action_at(Vector2(700, 910)) == "", "Play again ignores the continue click")
	scene.room_view.end_t = 60.0
	check(scene.action_at(Vector2(700, 910)) == "end_continue", "Go on once the card has finished")
	check(scene.action_at(Vector2(700, 790)) == "", "the old button spot is never Go on")
	# Drawer open: watch and photo.
	scene.room_jump("R02", 3)
	scene.dispatch("drawer")
	check(scene.action_at(Vector2(560, 600)) == "look_watch", "watch in the open drawer")
	check(scene.action_at(Vector2(920, 620)) == "look_photo", "photo in the open drawer")
	for p in [scene.save_path, again.save_path, corrupt.save_path]:
		GameView.remove_saves(p)
	scene.queue_free()
	again.queue_free()
	corrupt.queue_free()
	await process_frame

## The subtitle scheduler and restart cleanup.
func test_presentation_cleanup() -> void:
	var scene = new_scene("user://office_present_test.json")
	await process_frame
	scene.room_jump("R02", 2)
	var s: R02Sim = scene.room_sim()
	s.state.prints_seen = true; s.state.drawer_open = true; s.state.log_rewritten = true
	scene.dispatch("chair")
	check(scene.room_sim().state.seat_wet, "scene: chair wets the seat")
	check(scene.pending_sfx.size() == 1 and scene.pending_sfx[0][0] == "knock_glass" and scene.lines.size() == 2,
		"chair queues the knock and two lines")
	check(scene.subtitle.text == "The seat is wet. Still warm underneath.", "first line shows at once")
	var dues := []
	var expect := [4.4, 6.6]
	var dues_ok: bool = scene.lines.size() == 2
	for i in scene.lines.size():
		dues.append(scene.lines[i].due - scene.time)
		dues_ok = dues_ok and absf(dues[i] - expect[min(i, 1)]) < 0.001
	check(dues_ok, "delays are seconds after the click (%s)" % [dues])
	# A line that arrives (by dispatch) while the chain plays never cuts it off and is never
	# squeezed in: it waits after the chain's last line.
	scene.dispatch("mug")
	check(scene.subtitle.text == "The seat is wet. Still warm underneath.", "story line is not cut off early")
	check(scene.lines.size() == 3 and scene.lines.back().text.begins_with("Two rings")
		and scene.lines.back().due >= scene.lines[1].due + scene.lines[1].hold - 0.001, "the click's line waits after the chain")
	# Two reveals back to back never interleave: if a second arrives while the first is
	# queued, it is appended after it, whole, and nothing older is re-timed.
	scene.room_jump("R02", 2)
	scene.room_sim().state.prints_seen = true
	tide1(scene.room_sim())
	scene.dispatch("drawer")
	for i in 4:
		for n in [1, 8, 5, 2][i]:
			scene.dispatch("dial_%d" % i)
	scene.dispatch("try_drawer")
	var drawer_texts := []
	var drawer_dues := []
	for l in scene.lines:
		drawer_texts.append(l.text)
		drawer_dues.append(l.due)
	scene.dispatch("back")
	scene.dispatch("logbook")
	check(scene.room_sim().state.log_rewritten, "scene: the log rewrites")
	var order := []
	var dues_sorted := true
	var prev_due := -1.0
	for l in scene.lines:
		order.append("D" if l.text in drawer_texts else "L")
		dues_sorted = dues_sorted and l.due >= prev_due
		prev_due = l.due
	var runs := "".join(order)
	check(runs == "D".repeat(drawer_texts.size()) + "LLLL" and dues_sorted,
		"the rewrite's four lines follow the drawer's, whole and in order (%s)" % runs)
	var untouched := true
	for i in drawer_texts.size():
		untouched = untouched and is_equal_approx(scene.lines[i].due, drawer_dues[i])
	check(untouched, "the older chain is not re-timed")
	scene.dispatch("restart")
	check(scene.room_sim().view == "title", "restart returns to title")
	check(scene.pending_sfx.is_empty() and scene.lines.is_empty() and scene.subtitle.text == "", "restart clears lines and sounds")
	check(scene.oneshots.is_empty() and scene.room_view.lamp_glow.energy == 0.0, "restart stops one-shots and the lamp")
	check(scene.room_view.shadow_creep == 0 and scene.room_view.log_shown_hand == 0, "restart resets view state")
	GameView.remove_saves(scene.save_path)
	scene.queue_free()
	await process_frame

# ---------------------------------------------------------------------------
# C1: closure report gate
# ---------------------------------------------------------------------------
func set_fields(s: R02Sim, want: Array) -> void:
	for i in want.size():
		while int(s.state.report_fields[i]) != want[i]:
			s.dispatch("field_%d" % i)

func test_report_gate() -> void:
	var s := new_sim()
	s.debug_jump(3)
	var ev := s.dispatch("door")
	check(s.view == "room" and "Latched" in says(ev), "report gate: the door is latched at stage 3")
	ev = s.dispatch("papers")
	check(s.view == "report" and "closure report" in says(ev) and has_ev(ev, "sfx", "page"), "papers open the closure report")
	ev = s.dispatch("field_0")
	check(int(s.state.report_fields[0]) == 1 and has_ev(ev, "sfx", "nib"), "a field turns with a nib tick")
	# Every field combination but one is rejected with the right time; none says which line
	# is wrong, and the report stays open.
	var accepted := []
	var all_quiet := true
	for a in 3:
		for b in 3:
			for c in 2:
				var t := new_sim()
				t.debug_jump(3)
				t.dispatch("papers")
				set_fields(t, [a, b, c])
				set_time(t, R02Sim.REPORT_TIME_ANSWER)
				var fe := t.dispatch("file_report")
				if t.state.report_filed:
					accepted.append([a, b, c])
				elif not says(fe).begins_with("Something here doesn't reconcile.") or t.view != "report":
					all_quiet = false
	check(accepted == [R02Sim.REPORT_ANSWER], "only the right report files (accepted %s)" % [accepted])
	check(all_quiet, "a wrong report says only that it doesn't reconcile, and stays open")
	# Wrong, then right.
	set_fields(s, [0, 0, 0])
	ev = s.dispatch("file_report")
	check(not s.state.report_filed and "doesn't reconcile" in says(ev), "a wrong file leaves the report unfiled")
	set_fields(s, [2, 1, 0])
	var mid := new_sim()
	check(mid.from_dict(JSON.parse_string(JSON.stringify(s.to_dict()))) and mid.state.report_fields == [2, 1, 0]
		and not mid.state.report_filed, "report fields round-trip mid-entry")
	set_fields(s, R02Sim.REPORT_ANSWER)
	set_time(s, R02Sim.REPORT_TIME_ANSWER)
	ev = s.dispatch("file_report")
	check(s.state.report_filed and s.has_seen("report") and has_ev(ev, "sfx", "sign") and has_ev(ev, "sfx", "motif_short"),
		"the right report files and signs")
	check(s.view == "report", "filing keeps the report in front of her")
	check(say_ev(ev, "without counting").get("story", false), "filing lines are story")
	ev = s.dispatch("field_0")
	check(ev.is_empty() and s.state.report_fields == R02Sim.REPORT_ANSWER, "a filed report can't be changed")
	ev = s.dispatch("rtime_0")
	check(ev.is_empty() and s.state.report_time == R02Sim.REPORT_TIME_ANSWER, "a filed time can't be changed")
	s.dispatch("back")
	ev = s.dispatch("file_report")
	check(ev.is_empty(), "file_report outside the report does nothing")
	s.dispatch("door")
	check(s.view == "threshold", "after filing, the door -> threshold")
	var t := new_sim()
	check(t.from_dict(JSON.parse_string(JSON.stringify(s.to_dict()))) and t.state.report_filed, "report_filed round-trips")
	var bad := new_sim()
	bad.from_dict({"schema": 5, "started": true, "p01_complete": true, "log_read": true, "prints_seen": true,
		"drawer_open": true, "log_rewritten": true, "seat_wet": true, "report_filed": true,
		"report_fields": [0, 1, 1], "report_time": [1, 9, 3, 4], "foretold_door": true, "finished": true})
	check(bad.state.seat_wet and not bad.state.report_filed and not bad.state.foretold_door and not bad.state.finished,
		"a tampered save with the wrong fields loads unfiled")
	bad.from_dict({"schema": 5, "report_fields": [7, -2, "x"]})
	check(bad.state.report_fields == [0, 0, 0], "malformed report fields are ignored")
	bad.from_dict({"schema": 5, "report_fields": [9, 9, 9]})
	check(bad.state.report_fields == [2, 2, 1], "report fields clamp to their option counts")
	bad.from_dict({"schema": 5, "report_fields": [2, 1, 1, 1]})
	check(bad.state.report_fields == [0, 0, 0], "a round-2 four-field report is ignored")
	var j3 := new_sim()
	j3.debug_jump(3)
	var j4 := new_sim()
	j4.debug_jump(4)
	check(not j3.state.report_filed and j4.state.report_filed and j4.has_seen("report") and j4.objective() == "leave",
		"debug_jump(3) is unfiled; debug_jump(4) is filed")
	var h := new_sim()
	h.debug_jump(3)
	var h1 := says(h.dispatch("hint"))
	check(h1 == R02Sim.HINTS["report"][0], "the report has its own hints")
	check("Pilings 10" in R02Sim.HINTS["report"][2], "report hint 3 gives the answer")

# ---------------------------------------------------------------------------
# C1: the knock no longer unlatches the door
# ---------------------------------------------------------------------------
func test_chair_knock() -> void:
	var s := sim_before_chair()
	var ev := s.dispatch("chair")
	var knock_ok := false
	for e in ev:
		if e.type == "sfx" and e.id == "knock_glass" and is_equal_approx(e.delay, 3.4):
			knock_ok = true
	check(knock_ok, "knock_glass at 3.4 s")
	check(is_equal_approx(say_ev(ev, "Three taps on the glass.").get("delay", -1.0), 4.4), "'Three taps on the glass.' at 4.4 s")
	check(is_equal_approx(say_ev(ev, "Where the wall goes straight down").get("delay", -1.0), 6.6), "the wall line at 6.6 s")
	check(not has_ev(ev, "sfx", "latch_near") and say_ev(ev, "unlatched").is_empty(), "the chair no longer unlatches the door")
	check(s.has_seen("knock"), "the knock is noted")

# ---------------------------------------------------------------------------
# C1: the log records her clicks
# ---------------------------------------------------------------------------
func history_run() -> R02Sim:
	var s := new_sim()
	s.debug_jump(3)
	for a in ["coat", "window", "mug", "stove"]:
		s.dispatch(a)
		s.dispatch("back")
	return s

func test_history() -> void:
	var s := history_run()
	check(s.state.history == ["coat", "window", "mug"], "history keeps the first three clicks in order (%s)" % [s.state.history])
	var rows := s.log_rows()
	var tail := []
	for r in rows.slice(rows.size() - 3):
		tail.append(r[3])
	check(tail == [R02Sim.HISTORY_TEXT["coat"], R02Sim.HISTORY_TEXT["window"], R02Sim.HISTORY_TEXT["mug"]],
		"the log ends with what she did")
	check(rows.back()[4] == true, "history rows are in her hand")
	var b := history_run()
	check(JSON.stringify(b.log_rows()) == JSON.stringify(rows), "two identical runs give identical rows")
	var ev := s.dispatch("logbook")
	check(s.state.history_seen and has_ev(ev, "fx", "log_write") and "written down what I did" in says(ev),
		"the log shows her what it recorded")
	s.dispatch("back")
	ev = s.dispatch("logbook")
	check(not has_ev(ev, "fx", "log_write") and not "written down" in says(ev), "the history beat fires once")
	s.dispatch("back")
	file_and_back(s)
	rows = s.log_rows()
	check(rows[rows.size() - 2] == R02Sim.HISTORY_CLOSE and rows.back() == R02Sim.LOG_FINAL,
		"after filing: HISTORY_CLOSE then LOG_FINAL")
	s.dispatch("coat")
	check(s.state.history.size() == 3 and s.log_rows().size() == rows.size(), "nothing is recorded after filing")
	var lamp := new_sim()
	lamp.debug_jump(3)
	for a in ["lamp", "back", "tray", "back", "chair"]:
		lamp.dispatch(a)
	check(lamp.state.history == ["lamp", "chair"], "lamp and tray share one line")
	var fresh := sim_before_chair()
	fresh.dispatch("chair")
	check(fresh.state.history.is_empty(), "the click that wets the seat is not recorded")
	var t := new_sim()
	t.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(t.state.history == s.state.history and t.state.history_seen, "history round-trips")
	t.from_dict({"schema": 5, "history": ["coat"], "history_seen": true})
	check(t.state.history.is_empty() and not t.state.history_seen, "history needs the wet seat")
	t.from_dict({"schema": 5, "started": true, "p01_complete": true, "log_read": true, "prints_seen": true,
		"drawer_open": true, "log_rewritten": true, "seat_wet": true,
		"history": ["coat", "coat", "nope", 3, "lamp", "tray", "mug", "stove"]})
	check(t.state.history == ["coat", "lamp", "mug"], "history: known ids, unique lines, at most three")

# ---------------------------------------------------------------------------
# C2: the drawer is a deduction from the tide rhythm
# ---------------------------------------------------------------------------
func minutes(hhmm: String) -> int:
	var parts := hhmm.split(":")
	return int(parts[0]) * 60 + int(parts[1])

func day(date: String) -> int:
	return int(date.split(" ")[0])

func test_tide_rhythm() -> void:
	var s := new_sim()
	s.debug_jump(1)
	check(s.log_rows()[R02Sim.BLOTTED_ROW][1] == "", "the hour she mends the lamp is blotted")
	check(R02Sim.LOG_ENTRIES[R02Sim.BLOTTED_ROW][1] == "18:52", "...and it is 18:52 under the stain")
	# Every high water is 12 h 21 m after the last; low water 6 h 19 m after high.
	var hw := []
	var period_ok := true
	for i in R02Sim.LOG_ENTRIES.size():
		var e: Array = R02Sim.LOG_ENTRIES[i]
		var abs_min := day(e[0]) * 1440 + minutes(e[1])
		if e[2].begins_with("HW"):
			hw.append(abs_min)
		else:
			period_ok = period_ok and abs_min - hw.back() == 6 * 60 + 19
	for i in range(1, hw.size()):
		var gap: int = hw[i] - hw[i - 1]
		period_ok = period_ok and gap % (12 * 60 + 21) == 0 and gap > 0
	check(period_ok, "the log is strictly periodic")
	check(hw[1] - hw[0] == 24 * 60 + 42 and hw[2] - hw[1] == 24 * 60 + 42 and hw[3] - hw[2] == 24 * 60 + 42,
		"consecutive morning high waters are 24 h 42 m apart")
	check(minutes("06:31") + 12 * 60 + 21 == minutes("18:52"), "06:31 + 12:21 == 18:52")
	check((minutes("18:52") + 12 * 60 + 21) % 1440 == minutes(R02Sim.LOG_ENTRIES[8][1]), "18:52 + 12:21 == 07:13 next day")
	check(R02Sim.LOG_LATER[0][1] == "07:13", "the later row agrees: 07:13")
	var ev := s.dispatch("logbook")
	check(is_equal_approx(say_ev(ev, "tide-stain").get("delay", -1.0), 3.0), "the first read points at the stain")
	s.dispatch("back")
	s.dispatch("drawer")
	dial_to(s, [1, 8, 5, 2])
	s.dispatch("try_drawer")
	check(s.state.drawer_open and s.log_rows()[R02Sim.BLOTTED_ROW][1] == "18:52", "after the drawer the hour reads 18:52")
	check(R02Sim.HINTS["drawer"][1].contains("margin") and "1-8-5-2" in R02Sim.HINTS["drawer"][2],
		"drawer hints: the margin, then the code")
	# Dials turn both ways.
	var w := new_sim()
	w.debug_jump(1)
	w.dispatch("drawer")
	var dv := w.dispatch("dial_down_0")
	check(int(w.state.drawer_dial[0]) == 9 and has_ev(dv, "sfx", "dial"), "dial_down wraps 0 -> 9 with a click")
	w.dispatch("dial_down_0")
	check(int(w.state.drawer_dial[0]) == 8, "dial_down counts down")
	var code := JSON.stringify(s.state.drawer_dial)
	s.dispatch("drawer")
	check(s.dispatch("dial_down_2").is_empty() and JSON.stringify(s.state.drawer_dial) == code, "dial_down ignored once open")
	# The right code still needs the log.
	var early := new_sim()
	early.debug_jump(1)
	early.dispatch("drawer")
	dial_to(early, [1, 8, 5, 2])
	early.dispatch("try_drawer")
	check(not early.state.drawer_open, "1852 still needs the log read")

func test_drawer_near_misses() -> void:
	var cases := [
		[[1, 2, 5, 0], "Twelve fifty is low water. The lamp was mended on the flood."],
		[[0, 6, 3, 1], "06:31 is the morning tide. I came in on the evening one."],
		[[1, 8, 5, 0], "Eighteen fifty-something. The last figure is under the stain. His margin gives it to the minute."],
		[[1, 8, 5, 9], "Eighteen fifty-something. The last figure is under the stain. His margin gives it to the minute."],
		[[1, 8, 5, 4], "Close. His arithmetic is better than mine."],
		[[0, 7, 1, 3], "07:13 is tomorrow. He wants the hour it already happened."],
		[[1, 9, 3, 1], "The year won't do it. He wants an hour."],
		[[4, 4, 4, 4], "The drawer doesn't give."],
	]
	for cs in cases:
		var s := new_sim()
		s.debug_jump(2)
		s.dispatch("drawer")
		dial_to(s, cs[0])
		var ev := s.dispatch("try_drawer")
		check(says(ev) == cs[1] and not s.state.drawer_open and has_ev(ev, "sfx", "clunk"),
			"near miss %s: %s" % [cs[0], says(ev)])

func test_photo_behind() -> void:
	var s := new_sim()
	s.debug_jump(2)
	s.dispatch("drawer")
	dial_to(s, [1, 8, 5, 2])
	s.dispatch("try_drawer")
	var ev := s.dispatch("look_photo")
	check(says(ev) == "Me, from outside. From the sea side." and not s.has_seen("behind") and s.view == "photo",
		"first look at the photo opens it")
	ev = s.dispatch("photo")
	check(s.has_seen("behind") and says(ev) == "I hold his lens over it. There is someone behind me in this. There is no one behind me now.",
		"second look: someone behind her")
	var n: int = s.seen().size()
	s.dispatch("photo")
	check(s.seen().size() == n and s.seen().count("behind") == 1, "'behind' is recorded once")
	for i in 12:
		s.dispatch("photo")
	check(int(s.state.photo_looks) == 9, "photo looks are capped")
	var t := new_sim()
	t.from_dict({"schema": 5, "photo_looks": 40})
	check(int(t.state.photo_looks) == 9, "photo_looks clamps on load")

# ---------------------------------------------------------------------------
# C3: soundings, and every revisit made worse
# ---------------------------------------------------------------------------
func test_soundings() -> void:
	var s := new_sim()
	s.debug_jump(2)
	var ev := s.dispatch("map")
	check(says(ev) == "The chart has been corrected. In pencil. Nine." and not s.state.soundings_heard,
		"map at s2 before the drawer: the old line")
	s.dispatch("drawer")
	dial_to(s, [1, 8, 5, 2])
	s.dispatch("try_drawer")
	s.dispatch("back")
	ev = s.dispatch("map")
	var lines := says(ev).split(" | ")
	check(s.state.soundings_heard and lines.size() == 3 and "re-sounded" in lines[0] and "Line came up warm" in lines[2],
		"the soundings beat with the drawer open at s2")
	check(s.has_seen("chart") and s.has_seen("soundings"), "soundings records chart + soundings")
	check(say_ev(ev, "same amount").get("story", false), "soundings lines are story")
	var deep_ok := false
	for e in ev:
		if e.type == "sfx" and e.id == "deep" and is_equal_approx(e.delay, 5.6):
			deep_ok = true
	check(deep_ok, "the soundings beat sounds the deep at 5.6 s")
	ev = s.dispatch("map")
	check(says(ev) == "The chart has been corrected. In pencil. Nine.", "the soundings beat fires once")
	var t := new_sim()
	t.debug_jump(3)
	ev = t.dispatch("map")
	lines = says(ev).split(" | ")
	check(lines.size() == 4 and "tenth piling" in lines[3] and is_equal_approx(say_ev(ev, "tenth").delay, 9.0),
		"at s3 the 4th soundings line is the tenth piling")
	var one := new_sim()
	one.debug_jump(1)
	one.dispatch("map")
	check(not one.state.soundings_heard, "no soundings at stage 1")
	var bad := new_sim()
	bad.from_dict({"schema": 5, "started": true, "p01_complete": true, "log_read": true, "soundings_heard": true})
	check(not bad.state.soundings_heard, "soundings_heard needs the drawer open")

func test_revisits() -> void:
	var s1 := new_sim()
	s1.debug_jump(1)
	check(says(s1.dispatch("door")) == "The corridor. The latches down there let go when the lamp came on.", "door at s1")
	var s2 := new_sim()
	s2.debug_jump(2)
	check(says(s2.dispatch("door")) == "The latches downstairs let go when the lamp came on. Something wanted the doors open before I did.", "door at s2")
	check(says(s2.dispatch("coat")) == "Still dripping. Onto the same spot, every time. Like it's being counted.", "coat at s2")
	check(says(s2.dispatch("hooks")) == "Nine hooks. The ninth is wet again. I dried it with my sleeve an hour ago.", "hooks at s2")
	var s3 := new_sim()
	s3.debug_jump(3)
	var ev := s3.dispatch("puddle")
	check(says(ev) == "There are two trails now. | One goes to the drawer. One comes from the drawer to the door. The second one is my size.",
		"puddle at s3: two trails")
	check(is_equal_approx(say_ev(ev, "my size").delay, 2.0) and say_ev(ev, "my size").story, "the second trail line is story at 2.0 s")
	# The window only shows the palms after the knock.
	var w := new_sim()
	w.debug_jump(3)
	ev = w.dispatch("window")
	check(not w.has_seen("palms") and say_ev(ev, "heel of a hand").is_empty(), "no palms at s3 without the knock")
	var k := sim_before_chair()
	k.dispatch("chair")
	ev = k.dispatch("window")
	check(k.has_seen("palms") and is_equal_approx(say_ev(ev, "heel of a hand").delay, 2.8) and say_ev(ev, "heel of a hand").story,
		"palms after the knock, 2.8 s after the window line")
	check(say_ev(k.dispatch("window"), "heel of a hand").is_empty(), "the palms line once")
	# The log-rewrite beat.
	var r := new_sim()
	r.debug_jump(2)
	tide1(r)
	r.dispatch("puddle")
	r.dispatch("drawer")
	dial_to(r, [1, 8, 5, 2])
	r.dispatch("try_drawer")
	r.dispatch("back")
	ev = r.dispatch("logbook")
	check(not "Something is rising" in says(ev) and "I check the date on it. Tomorrow." in says(ev)
		and "forty years" in says(ev), "the rewrite beat: the date, not the explanation")
	check(is_equal_approx(say_ev(ev, "Tomorrow.").delay, 7.4), "'Tomorrow.' at 7.4 s")

# ---------------------------------------------------------------------------
# C4 (sim): '...Listen.' plays once
# ---------------------------------------------------------------------------
func test_listen_once() -> void:
	var s := new_sim()
	s.debug_jump(1)
	var fades := 0
	var listens := 0
	var all_ev := []
	all_ev.append_array(s.dispatch("logbook"))
	all_ev.append_array(s.dispatch("back"))
	all_ev.append_array(s.dispatch("drawer"))
	all_ev.append_array(s.dispatch("back"))
	for i in 3:
		all_ev.append_array(s.dispatch("logbook"))
		all_ev.append_array(s.dispatch("back"))
	for e in all_ev:
		if e.type == "fx" and e.id == "sea_fade": fades += 1
		if e.type == "say" and e.text == "...Listen.": listens += 1
	check(fades == 1 and listens == 1 and s.state.heard_silence, "one sea_fade and one '...Listen.' (%d, %d)" % [fades, listens])
	var t := new_sim()
	t.from_dict({"schema": 5, "heard_silence": true})
	check(not t.state.heard_silence, "heard_silence needs the log read")

# ---------------------------------------------------------------------------
# C6 (sim): the threshold
# ---------------------------------------------------------------------------
func test_threshold_sim() -> void:
	check(R02Sim.THRESHOLD_LINES == [
		[0.8, "The corridor is dark. It goes on further than the station does."],
		[3.4, "Something down there breathes in. The tide goes out with it, as far as the lighthouse."],
		[7.6, "It breathes out. Every piling in the Sound goes under at once."]], "threshold lines are exact")
	check(R02Sim.THRESHOLD_STILL_LINE == "I hold my breath. So does the sea.", "the still line exists")
	var s := new_sim()
	s.debug_jump(4)
	s.dispatch("door")
	var others: Array = R02Sim.ROOM_IDS.duplicate()
	others.append_array(["back", "resume", "toggle_motion", "toggle_soft", "dial_0", "dial_down_0",
		"try_drawer", "field_0", "file_report", "look_photo", "look_watch", "toggle_supply", "select_b", "fit"])
	var stayed := true
	for a in others:
		s.dispatch(a)
		stayed = stayed and s.view == "threshold" and not s.state.finished
	check(stayed, "at the threshold only continue/turn/notebook/menu/hint do anything")
	var level: int = s.game.state.hint.level
	var ev := s.dispatch("hint")
	check(says(ev) == R02Sim.THRESHOLD_HINT and s.game.state.hint.level == level and s.view == "threshold",
		"hint at the threshold: hold still, ladder untouched")
	ev = s.dispatch("continue")
	check(s.view == "end" and s.state.finished and not s.state.turned, "continue goes on to the end")
	check(has_ev(ev, "sfx", "motif"), "continue sounds the motif")

# ---------------------------------------------------------------------------
# C7 (sim): the end lines and the notebook intrusion
# ---------------------------------------------------------------------------
func test_end_lines() -> void:
	var s := new_sim()
	s.debug_jump(4)
	check(s.end_lines() == [R02Sim.END_ON_STATION], "end lines without everything seen")
	for id in R02Sim.REACHABLE_BY_T1X:
		if id != "behind":
			s._observe(id)
	check(s.end_lines() == [R02Sim.END_ON_STATION], "one Tide I observation missing: no all-seen line")
	s._observe("behind")
	check(s.end_lines() == [R02Sim.END_ON_STATION, R02Sim.END_ALL_SEEN],
		"with everything Tide I can show seen: nothing went unrecorded")
	check(not "Tide I continues." in s.end_lines(), "the card never says Tide I continues")
	var n := new_sim()
	n.debug_jump(2)
	check(n.notebook_intrusion() == "", "no intrusion before the log rewrites")
	n.debug_jump(3)
	check(n.notebook_intrusion() == "She will not finish this page.", "the notebook intrusion after the rewrite")

# ---------------------------------------------------------------------------
# C4 (view): the subtitle scheduler
# ---------------------------------------------------------------------------
func advance(scene: Node, seconds: float, dt := 0.05) -> void:
	var t := 0.0
	while t < seconds:
		scene.time += dt
		scene._tick_lines(dt)
		t += dt

## Seconds from now until `text` is on screen, or -1 within `limit`.
func time_to_show(scene: Node, text: String, limit: float, dt := 0.05) -> float:
	var t := 0.0
	while t <= limit:
		if scene.subtitle.text == text:
			return t
		scene.time += dt
		scene._tick_lines(dt)
		t += dt
	return -1.0

func test_scheduler() -> void:
	var scene = new_scene("user://office_sched_test.json")
	await process_frame
	# (a) A fast clicker: every click during the prints' chain brings its next line up at
	# once, and the click after it is a click again. The drawer's reveal then starts at once.
	scene.room_jump("R02", 2)
	scene.room_sim().state.prints_seen = false
	scene.click(Vector2(1117, 915))
	check(scene.subtitle.text.begins_with("Bare feet"), "the prints' first line at once")
	advance(scene, 0.5)
	scene.click(Vector2(908, 865))
	check(scene.subtitle.text == "They don't come back." and scene.room_sim().view == "room",
		"a click during the chain advances it and does not open the drawer")
	advance(scene, 0.5)
	scene.click(Vector2(908, 865))
	check(scene.room_sim().view == "room" and not scene.chain_active(), "the next click releases the last line")
	scene.click(Vector2(908, 865))
	check(scene.room_sim().view == "drawer", "...and the one after it opens the drawer")
	for i in 4:
		for n in [1, 8, 5, 2][i]:
			scene.dispatch("dial_%d" % i)
	advance(scene, 0.2)
	scene.click(Vector2(724, 728))
	var shown: float = time_to_show(scene, "It gives.", 1.2)
	check(shown >= 0.0, "'It gives.' within the feedback hold (%.2f)" % shown)
	# (b) Feedback is never starved: a wrong try's clunk line shows within 1.5 s.
	scene.room_jump("R02", 2)
	scene.dispatch("drawer")
	advance(scene, 0.1)
	scene.dispatch("try_drawer")
	shown = time_to_show(scene, "The drawer doesn't give.", 1.5)
	check(shown >= 0.0, "the clunk line within 1.5 s (%.2f)" % shown)
	# A click's line stays up at least 1.2 s before the next click replaces it.
	scene.room_jump("R02", 1)
	scene.dispatch("mug")
	advance(scene, 0.3)
	scene.dispatch("stove")
	check(scene.subtitle.text.begins_with("A chipped green mug"), "a click's line is not replaced before 1.2 s")
	shown = time_to_show(scene, scene.lines[0].text if not scene.lines.is_empty() else "", 1.2)
	check(shown >= 0.8 and shown <= 1.0, "the next click's line follows at 1.2 s (%.2f)" % shown)
	# (d) Long lines get the smaller size.
	scene._show_line("x".repeat(115), false)
	check(scene.subtitle.get_theme_font_size("font_size") == 24, "a 115-character line is set at 24")
	scene._show_line("Short.", false)
	check(scene.subtitle.get_theme_font_size("font_size") == 27, "a short line is set at 27")
	check(scene.subtitle.position == Vector2(48, 996) and scene.subtitle.size == Vector2(1352, 76), "subtitle box")
	GameView.remove_saves(scene.save_path)
	scene.queue_free()
	await process_frame

# ---------------------------------------------------------------------------
# C5 (view): breathing room, the knock lands
# ---------------------------------------------------------------------------
func test_breath_and_knock() -> void:
	var scene = new_scene("user://office_breath_test.json")
	await process_frame
	# At 4.0 the exhale starts at build_audio's 1.1 peak; everything that uses it clamps to 0..1.
	check(is_equal_approx(scene.room_view._breath_env(0.0), 0.0) and is_equal_approx(clampf(scene.room_view._breath_env(4.0), 0.0, 1.0), 1.0)
		and is_equal_approx(scene.room_view._breath_env(3.9999), 1.0) and is_equal_approx(scene.room_view._breath_env(4.0), scene.room_view.BREATH_OUT_PEAK)
		and absf(scene.room_view._breath_env(8.8)) < 1e-6 and is_equal_approx(scene.room_view._breath_env(10.0), 0.0), "breath envelope")
	scene.room_jump("R02", 2)
	var s: R02Sim = scene.room_sim()
	s.state.prints_seen = true; s.state.drawer_open = true; s.state.log_rewritten = true
	scene.dispatch("chair")
	var played := false
	var hush_ok := false
	var silent_ok := false
	var dt := 1.0 / 60.0
	for i in 600:
		scene.time += dt
		scene.room_view._tick_stage(dt)
		scene._tick_sfx(dt)
		scene.room_view._tick_audio(dt)
		if not scene.room_view._knock_pending():
			played = true
			hush_ok = scene.room_view.hush > 0.0
			silent_ok = true
			for k in scene.room_view.last_targets:
				if k != "ring" and scene.room_view.last_targets[k] != 0.0:
					silent_ok = false
			break
	check(played and hush_ok, "the room is hushed when the knock plays")
	check(silent_ok and is_equal_approx(scene.room_view.last_targets.get("ring", 0.0), 0.10), "every mix target but the ring is 0 at the knock")
	check(scene.room_view.palms_armed, "the knock leaves marks on the glass")
	check(scene.room_view.last_targets.get("heartbeat", 1.0) == 0.0, "no heartbeat: the breath took its place")
	s.game.settings.soft_audio = true
	check(is_equal_approx(scene.sfx_db("knock_glass"), -11.0), "softened knock is -11 dB")
	check(is_equal_approx(scene.sfx_db("door"), -18.0), "other sudden sounds keep the -12 cut")
	s.game.settings.soft_audio = false
	check(is_equal_approx(scene.sfx_db("sign"), -8.0) and is_equal_approx(scene.sfx_db("nib"), -14.0), "sign and nib levels")
	scene.room_jump("R02", 3)
	check(scene.room_view.palms_k == 1.0, "palms are there on a stage-3 jump")
	GameView.remove_saves(scene.save_path)
	scene.queue_free()
	await process_frame

# ---------------------------------------------------------------------------
# C6 (view): the stillness test
# ---------------------------------------------------------------------------
func count_line(scene: Node, text: String) -> int:
	var n: int = 1 if scene.cur_text == text else 0
	for l in scene.lines:
		if l.text == text:
			n += 1
	return n

func test_threshold_scene() -> void:
	var scene = new_scene("user://office_still_test.json")
	await process_frame
	scene.room_jump("R02", 4)
	scene.dispatch("door")
	check(scene.room_sim().view == "threshold", "scene: at the threshold")
	check(scene.action_at(Vector2(1300, 500)) == "", "no continue before she holds still")
	var still := R02Sim.THRESHOLD_STILL_LINE
	# Moving before STILL_AFTER doesn't count; then holding still for 3 s does.
	scene.room_view.threshold_t = R02Sim.THRESHOLD_STILL_AFTER
	for i in 20:
		scene.room_view.threshold_t += 0.1
		scene.room_view._tick_still(0.1, Vector2(700 + i * 10, 500))
	check(not scene.room_view.continue_ready and scene.room_view.still_t == 0.0, "a moving cursor resets the stillness")
	for i in 32:
		scene.room_view.threshold_t += 0.1
		scene.room_view._tick_still(0.1, Vector2(890, 500) + Vector2(1, 1) * (i % 2))
	check(scene.room_view.continue_ready and count_line(scene, still) == 1, "holding still 3 s: the still line, once")
	check(scene.action_at(Vector2(1300, 500)) == "continue", "continue after the still line")
	var still_after := true
	for l in scene.lines:
		if l.text == still:
			for m in scene.lines:
				if m.story and m.text != still:
					still_after = still_after and m.due <= l.due
	check(still_after, "the still line waits after anything still being said")
	for i in 40:
		scene.room_view.threshold_t += 0.1
		scene.room_view._tick_still(0.1, Vector2(890, 500))
	check(count_line(scene, still) == 1, "the still line is queued exactly once")
	scene.room_view._tick_audio(0.1)
	check(scene.room_view.last_targets.get("breath", 1.0) == 0.0, "after the line the breath stays stopped")
	# The fallback.
	scene.room_jump("R02", 4)
	scene.dispatch("door")
	scene.room_view.threshold_t = R02Sim.THRESHOLD_FALLBACK
	scene.room_view._tick_still(0.1, Vector2(100, 100))
	scene.room_view._tick_still(0.1, Vector2(900, 900))
	check(scene.room_view.continue_ready and count_line(scene, still) == 1, "the fallback also lets her go on")
	# The phase lock.
	scene.room_jump("R02", 4)
	scene.dispatch("door")
	check(is_equal_approx(scene.room_view.breath_clock, scene.room_view.THRESHOLD_BREATH_SEEK), "the breath is phase-locked at the door")
	check(not scene.room_view.continue_ready and scene.room_view.still_t == 0.0 and not scene.room_view.still_spoken, "stillness resets at the door")
	scene.room_view.threshold_t = 1.0
	scene.room_view._tick_audio(0.1)
	check(scene.room_view.last_targets.get("breath", 1.0) == 0.0, "no breath before 2.8 s")
	scene.room_view.threshold_t = 3.0
	scene.room_view._tick_audio(0.1)
	check(is_equal_approx(scene.room_view.last_targets.get("breath", 0.0), 0.55), "breath 0.55 from 2.8 s")
	GameView.remove_saves(scene.save_path)
	scene.queue_free()
	await process_frame

# ---------------------------------------------------------------------------
# C7 (view): the end card
# ---------------------------------------------------------------------------
func test_end_scene() -> void:
	check(not FileAccess.get_file_as_string("res://game/rooms/R02/R02_view.gd").contains("You noted"), "no 'You noted' on the end card")
	var scene = new_scene("user://office_end_test.json")
	await process_frame
	scene.room_jump("R02", 4)
	scene.dispatch("door")
	scene.room_view.continue_ready = true
	scene.dispatch("continue")
	check(scene.room_sim().view == "end", "scene: the end card")
	scene.room_view.end_t = 1.0
	check(scene.action_at(Vector2(700, 910)) == "", "no restart while the card writes")
	scene.room_view.end_t = 4.0
	check(scene.room_view._end_row_writing(), "the log row writes itself from 3 s")
	scene.room_view._tick_audio(0.1)
	check(is_equal_approx(scene.room_view.last_targets.get("pen", 0.0), 0.45), "the pen scratches while it writes")
	var sch: Dictionary = scene.room_view._end_schedule()
	scene.room_view.end_t = (sch.r1_done + sch.r2_start) / 2.0
	check(not scene.room_view._end_row_writing(), "the pen rests between the rows")
	scene.room_view.end_t = sch.r2_start + 0.5
	check(scene.room_view._end_row_writing(), "the second row writes itself 2 s after the first")
	check(is_equal_approx(sch.r2_start, sch.r1_done + 2.0) and is_equal_approx(sch.lines[0], sch.r2_done + 1.5)
		and sch.lines.size() == scene.room_sim().end_lines().size(), "end-card schedule")
	scene.room_view.end_t = sch.done - 0.1
	check(scene.action_at(Vector2(700, 910)) == "", "no restart before the last line is in")
	scene.room_view.end_t = sch.done + 0.1
	check(scene.action_at(Vector2(700, 910)) == "end_continue" and scene.action_at(Vector2(700, 790)) == "",
		"Go on only on the button, once the card is done")
	scene.room_sim().game.settings.motion = false
	scene.room_view.end_t = 1.0
	check(scene.action_at(Vector2(700, 910)) == "", "Motion off: the grace still applies")
	scene.room_view.end_t = 1.6
	check(scene.action_at(Vector2(700, 910)) == "end_continue", "Motion off: Go on after the grace")
	GameView.remove_saves(scene.save_path)
	scene.queue_free()
	await process_frame

# ---------------------------------------------------------------------------
# Round 3, C1: the report unlatches on Back; the evening tide; misses in her hand
# ---------------------------------------------------------------------------
const UNLATCH_LINE := "Behind me, the corridor door unlatched itself."

func test_unlatch_on_back() -> void:
	var s := new_sim()
	s.debug_jump(3)
	var ev := file_report(s)
	check(s.view == "report" and s.state.report_filed and not s.state.heard_unlatch, "filing keeps view 'report'")
	check(not has_ev(ev, "sfx", "latch_near") and count_say(ev, UNLATCH_LINE) == 0, "no unlatch while she is at the desk")
	check(count_say(ev, "The two is in my hand. I wrote it without counting.") == 1
		and is_equal_approx(say_ev(ev, "without counting").delay, 2.2), "the two, at 2.2 s")
	var dr := new_sim()
	dr.debug_jump(3)
	file_report(dr)
	ev = dr.dispatch("door")
	check(dr.view == "threshold" and dr.state.heard_unlatch and count_say(ev, UNLATCH_LINE) == 1,
		"'door' sent from the report steps back first (the unlatch), then opens the door")
	check(s.objective() == "filed" and says(s.dispatch("hint")) == R02Sim.HINTS["filed"][0], "objective 'filed' has hints")
	ev = s.dispatch("back")
	check(s.state.heard_unlatch and s.view == "room", "back from the signed report: heard_unlatch")
	var latch_ok := false
	for e in ev:
		if e.type == "sfx" and e.id == "latch_near" and is_equal_approx(e.delay, 0.2):
			latch_ok = true
	check(latch_ok and count_say(ev, UNLATCH_LINE) == 1 and say_ev(ev, UNLATCH_LINE).story
		and is_equal_approx(say_ev(ev, UNLATCH_LINE).delay, 0.6), "latch_near at 0.2 s and the unlatch line at 0.6 s")
	check(s.objective() == "leave", "objective -> leave")
	s.dispatch("door")
	check(s.view == "threshold", "then 'door' -> threshold")
	# Twice back: the unlatch is heard once.
	var t := new_sim()
	t.debug_jump(3)
	var all := file_report(t)
	all.append_array(t.dispatch("back"))
	all.append_array(t.dispatch("papers"))
	all.append_array(t.dispatch("back"))
	var latches := 0
	for e in all:
		if e.type == "sfx" and e.id == "latch_near": latches += 1
	check(latches == 1 and count_say(all, UNLATCH_LINE) == 1, "filing then back twice: one unlatch")
	# The door before she steps back is still latched (a save can't get here, but a sim can).
	var u := new_sim()
	u.debug_jump(3)
	file_report(u)
	u.view = "room"
	u.dispatch("door")
	check(u.view == "room", "the threshold needs heard_unlatch too")
	var j := new_sim()
	j.debug_jump(4)
	check(j.state.heard_unlatch and j.state.report_time == R02Sim.REPORT_TIME_ANSWER, "debug_jump(4) has heard the unlatch")

func test_report_time() -> void:
	check(R02Sim.REPORT_FIELDS.size() == 3 and R02Sim.REPORT_ANSWER == [2, 1, 1], "three choice fields")
	check(R02Sim.REPORT_FIELDS[1][1] == ["1", "2", "3"], "observers 1-3")
	check(minutes("07:13") + 12 * 60 + 21 == minutes("19:34") and R02Sim.REPORT_TIME_ANSWER == [1, 9, 3, 4],
		"the evening tide is 07:13 + 12 h 21 m = 19:34")
	var s := new_sim()
	s.debug_jump(3)
	s.dispatch("papers")
	var ev := s.dispatch("rtime_1")
	check(s.state.report_time == [0, 1, 0, 0] and has_ev(ev, "sfx", "dial"), "a time dial turns up with a dial click")
	ev = s.dispatch("rtime_down_0")
	check(s.state.report_time == [9, 1, 0, 0] and has_ev(ev, "sfx", "dial"), "and down, wrapping 0 -> 9")
	for i in 10: s.dispatch("rtime_3")
	check(int(s.state.report_time[3]) == 0, "ten clicks come round")
	# A right time with a wrong field, and a wrong time with right fields, never file.
	var a := new_sim()
	a.debug_jump(3)
	a.dispatch("papers")
	set_fields(a, [1, 1, 1])
	set_time(a, R02Sim.REPORT_TIME_ANSWER)
	a.dispatch("file_report")
	var b := new_sim()
	b.debug_jump(3)
	b.dispatch("papers")
	set_fields(b, R02Sim.REPORT_ANSWER)
	set_time(b, [1, 9, 3, 3])
	b.dispatch("file_report")
	check(not a.state.report_filed and not b.state.report_filed, "a right time with a wrong field, or the reverse, never files")
	# Every near-miss time has its own line.
	var all_ok := true
	for key in R02Sim.REPORT_TIME_MISSES:
		var m := new_sim()
		m.debug_jump(3)
		m.dispatch("papers")
		set_fields(m, R02Sim.REPORT_ANSWER)
		var want: Array = []
		for ch in key: want.append(int(ch))
		set_time(m, want)
		var fe := m.dispatch("file_report")
		var line: String = R02Sim.REPORT_TIME_MISSES[key]
		all_ok = all_ok and count_say(fe, line) == 1 and not m.state.report_filed and has_ev(fe, "sfx", "page")
	check(all_ok, "every REPORT_TIME_MISSES line fires")
	var g := new_sim()
	g.debug_jump(3)
	g.dispatch("papers")
	check(says(g.dispatch("back")) == "", "back from a blank report says nothing")
	g.dispatch("papers")
	g.dispatch("rtime_0")
	g.dispatch("back")
	check(says(g.dispatch("papers")) == "His closure report. Half reconciled.", "a touched report is half reconciled")
	var h := new_sim()
	h.debug_jump(3)
	check(says(h.dispatch("papers")).begins_with("Under the duty card"), "an untouched report is blank")
	check(R02Sim.HINTS["report"][2] == "Pilings 10. Observers 2. High water 19:34 (07:13 plus 12 h 21 m). Height 9.9 m. Then sign it.",
		"report hint 3 gives the answer and the arithmetic")
	check(R02Sim.OBSERVATIONS["report"] == "Closure report, filed in my hand: pilings 10; observers on station 2; high water 18 Oct 19:34, 9.9 m.",
		"the filed report's notebook line")

func wrong_file(s: R02Sim) -> Array:
	return s.dispatch("file_report")

func test_report_misses() -> void:
	var s := new_sim()
	s.debug_jump(3)
	s.dispatch("papers")
	var sizes := [s.log_rows().size()]
	var ev := wrong_file(s)
	check(s.state.history == ["miss0"] and s.report_misses() == 1, "the first miss is written down")
	check(says(ev).begins_with("Something here doesn't reconcile.") and has_ev(ev, "fx", "log_write")
		and is_equal_approx(say_ev(ev, "a pen is moving").delay, 1.6) and say_ev(ev, "a pen is moving").story,
		"first miss: the pen moves, at 1.6 s")
	sizes.append(s.log_rows().size())
	ev = wrong_file(s)
	check(s.state.history == ["miss0", "miss1"] and say_ev(ev, "a pen is moving").is_empty()
		and not has_ev(ev, "fx", "log_write"), "the second miss: no pen line")
	sizes.append(s.log_rows().size())
	ev = wrong_file(s)
	check(s.state.history == ["miss0", "miss1", "miss2"] and is_equal_approx(say_ev(ev, "writing down my mistakes").delay, 2.0),
		"the third miss: it is writing down my mistakes, at 2.0 s")
	sizes.append(s.log_rows().size())
	ev = wrong_file(s)
	check(s.report_misses() == 3 and s.state.history.size() == 3 and say_ev(ev, "writing down my mistakes").is_empty(),
		"a fourth miss adds nothing")
	sizes.append(s.log_rows().size())
	var tail := []
	var rows := s.log_rows()
	for r in rows.slice(rows.size() - 3):
		tail.append(r[3])
	check(tail == [R02Sim.HISTORY_TEXT["miss0"], R02Sim.HISTORY_TEXT["miss1"], R02Sim.HISTORY_TEXT["miss2"]],
		"miss rows in the order they happened")
	# Misses don't use up the room's three history lines.
	s.dispatch("back")
	for a in ["coat", "window", "mug", "stove"]:
		s.dispatch(a)
		s.dispatch("back")
		sizes.append(s.log_rows().size())
	check(s.state.history == ["miss0", "miss1", "miss2", "coat", "window", "mug"], "room clicks still get three lines")
	var prev_rows := s.log_rows()
	file_and_back(s)
	check(s.state.report_filed, "a correct filing still works after three misses")
	sizes.append(s.log_rows().size())
	var grows := true
	for i in range(1, sizes.size()):
		grows = grows and sizes[i] >= sizes[i - 1]
	var prefix_ok := JSON.stringify(s.log_rows().slice(0, prev_rows.size())) == JSON.stringify(prev_rows)
	check(grows and prefix_ok, "log_rows only ever grows, append-only (%s)" % [sizes])

func test_report_saves() -> void:
	var s := new_sim()
	s.debug_jump(3)
	s.dispatch("papers")
	wrong_file(s)
	wrong_file(s)
	set_time(s, [1, 9, 3, 0])
	var t := roundtrip(s)
	check(t.state.report_time == [1, 9, 3, 0] and t.state.history == ["miss0", "miss1"] and not t.state.heard_unlatch,
		"report_time and the miss ids round-trip")
	file_and_back(s)
	t = roundtrip(s)
	check(t.state.report_filed and t.state.heard_unlatch and t.view == "room", "heard_unlatch round-trips (derived)")
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	d.rooms.R02.report_time = [1, 9, 3, 3]
	var bad := new_sim()
	bad.from_dict(d)
	check(not bad.state.report_filed and not bad.state.heard_unlatch, "tamper: filed with a wrong time is rejected")
	bad.from_dict({"schema": 5, "report_time": [12, -1, 3, 4.5]})
	check(bad.state.report_time == [0, 0, 0, 0], "a malformed time is ignored")
	bad.from_dict({"schema": 5, "report_time": [12, -1, 3, 4]})
	check(bad.state.report_time == [9, 0, 3, 4], "the time clamps to 0-9")
	var w := {"schema": 5, "started": true, "p01_complete": true, "log_read": true, "prints_seen": true,
		"drawer_open": true, "log_rewritten": true, "seat_wet": true,
		"history": ["miss1", "miss0", "coat", "miss1", "miss2", "miss0", "lamp", "mug", "stove"]}
	bad.from_dict(w)
	check(bad.state.history == ["miss0", "coat", "miss1", "miss2", "lamp", "mug"], "misses load in order, at most three (%s)" % [bad.state.history])
	w.seat_wet = false
	bad.from_dict(w)
	check(bad.state.history.is_empty(), "misses need the wet seat")
	var dry := {"schema": 5, "started": true, "report_filed": true, "heard_unlatch": true}
	bad.from_dict(dry)
	check(not bad.state.heard_unlatch, "heard_unlatch needs a filed report")

func test_round3_determinism() -> void:
	var script := ["papers", "file_report", "rtime_0", "field_1", "file_report", "back", "coat", "back",
		"window", "back", "map", "map", "notebook", "back", "mug", "papers"]
	for i in 2: script.append("field_0")
	script.append("field_2")
	for i in 9: script.append("rtime_1")
	for i in 3: script.append("rtime_2")
	for i in 4: script.append("rtime_3")
	script.append_array(["file_report", "door", "back", "door", "turn"])
	var a := new_sim()
	var b := new_sim()
	a.debug_jump(3)
	b.debug_jump(3)
	var log_a := []
	var log_b := []
	for act in script:
		log_a.append(a.dispatch(act))
		log_b.append(b.dispatch(act))
	check(a.view == "end" and a.state.turned, "the round-3 script reaches the turned ending")
	check(JSON.stringify(log_a) == JSON.stringify(log_b) and JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()),
		"round 3: the same script twice gives identical state and events")

# ---------------------------------------------------------------------------
# Round 3, C2: less explaining, the contours, look-away, continuity, two endings
# ---------------------------------------------------------------------------
func test_story_text_r3() -> void:
	var s := office(game_at(6))
	var ev := s.dispatch("window")
	check(is_equal_approx(say_ev(ev, "I step to the left. It is still in the middle of the glass.").delay, 2.6),
		"window band 4: the eye line at 2.6 s")
	var h := office(game_at(8))
	check(says(h.dispatch("hooks")).ends_with("The ninth says A.M. It hangs at the height of my collar."),
		"the tag line")
	check(R02Sim.OBSERVATIONS["tag"] == "A brass tag on the ninth hook, stamped A.M. It hangs at the height of my collar.",
		"the tag observation")
	check(R02Sim.OBSERVATIONS.size() >= 35, "about 35 observations (%d)" % R02Sim.OBSERVATIONS.size())

func test_contours() -> void:
	var t1x := new_sim()
	t1x.debug_jump(3)
	t1x.dispatch("map")
	t1x.dispatch("map")
	check(t1x.state.soundings_heard and not t1x.state.contours_seen, "no contours at T1X")
	var early := office(game_at(6))
	var ev := early.dispatch("map")
	check(early.state.soundings_heard and not early.state.contours_seen, "at band 4 the first map is the soundings")
	ev = early.dispatch("map")
	check(early.state.contours_seen and early.has_seen("contours") and has_ev(ev, "fx", "contours"), "the second map: contours")
	var deep_ok := false
	for e in ev:
		if e.type == "sfx" and e.id == "deep" and is_equal_approx(e.delay, 4.8):
			deep_ok = true
	check(deep_ok and say_ev(ev, "They go round.").story and is_equal_approx(say_ev(ev, "Like a lash").delay, 5.4),
		"contours: the deep at 4.8 s, three story lines")
	ev = early.dispatch("map")
	check(not has_ev(ev, "fx", "contours"), "contours once only")
	var s2 := new_sim()
	s2.debug_jump(2)
	s2.dispatch("drawer")
	dial_to(s2, [1, 8, 5, 2])
	s2.dispatch("try_drawer")
	s2.dispatch("back")
	s2.dispatch("map")
	s2.dispatch("map")
	check(s2.state.soundings_heard and not s2.state.contours_seen, "no contours at s2")
	var none := office(game_at(6))
	check(not none.state.soundings_heard and not has_ev(none.dispatch("window"), "fx", "contours")
		and not none.has_seen("through"), "no 'through' before the contours")
	ev = early.dispatch("window")
	check(early.has_seen("through") and count_say(ev, R02Sim.OBSERVATIONS["through"]) == 1
		and is_equal_approx(say_ev(ev, "what it looks through").delay, 2.6 + 2.8), "'through' after the contours, 2.8 s after the chain")
	ev = early.dispatch("window")
	check(say_ev(ev, "what it looks through").is_empty(), "'through' once")
	var bad := new_sim()
	bad.from_dict({"schema": 5, "started": true, "p01_complete": true, "log_read": true, "drawer_open": true,
		"soundings_heard": true, "contours_seen": true})
	check(not bad.state.contours_seen, "contours_seen needs the threshold behind her")
	var t := roundtrip(early)
	check(t.state.contours_seen, "contours_seen round-trips")

func test_chart_tenth() -> void:
	var s := new_sim()
	s.dispatch("begin")
	for a in ["map", "lamp", "toggle_supply", "select_b", "fit", "toggle_supply", "map", "logbook", "back",
			"map", "puddle", "drawer"]:
		s.dispatch(a)
	dial_to(s, [1, 8, 5, 2])
	for a in ["try_drawer", "back", "map", "map"]:
		s.dispatch(a)
	check(s.has_seen("chart") and s.has_seen("soundings") and not s.has_seen("chart_tenth"), "chart_tenth never before s3")
	check(R02Sim.OBSERVATIONS["chart"] == "The chart has been corrected in pencil: nine pilings.", "the chart line spoils nothing")
	var t := new_sim()
	t.debug_jump(3)
	t.dispatch("map")
	check(t.has_seen("chart_tenth"), "the s3 soundings line notes the tenth piling")

func test_look_away() -> void:
	# The slice's stage-3 look-aways are gone: nothing changes during Tide I.
	var s := new_sim()
	s.debug_jump(3)
	for a in ["papers", "back", "notebook", "back", "logbook", "back", "drawer", "back"]:
		s.dispatch(a)
	check(s.state.look_away_applied.is_empty() and not s.state.has("returns"), "no look-away in T1X; no returns counter")
	check(not R02Sim.ROOM_IDS.has("turn"), "'turn' is not a room id")

func test_continuity() -> void:
	var s := new_sim()
	s.debug_jump(1)
	s.dispatch("lamp")
	var ev := s.dispatch("toggle_supply")
	check(s.state.supply_on and s.state.p01_complete and says(ev) == "Leave it. I want the light."
		and not has_ev(ev, "sfx", "switch"), "after the repair the supply stays on")
	var d := new_sim()
	d.debug_jump(2)
	d.dispatch("drawer")
	dial_to(d, [4, 4, 4, 4])
	var got := []
	for i in 4:
		got.append(says(d.dispatch("try_drawer")))
	check(got == ["The drawer doesn't give.", "Still nothing.", "The dials are cold. The drawer isn't.", "The drawer doesn't give."],
		"the drawer's refusal rotates (%s)" % [got])
	check(not d.to_dict().has("drawer_miss_n"), "the rotation is not saved")
	var r := new_sim()
	r.debug_jump(2)
	tide1(r)
	r.dispatch("puddle")
	r.dispatch("drawer")
	dial_to(r, [1, 8, 5, 2])
	ev = r.dispatch("try_drawer")
	var drawer_motif := false
	for e in ev:
		if e.type == "sfx" and e.id == "motif_short" and is_equal_approx(e.delay, 1.0): drawer_motif = true
	r.dispatch("back")
	ev = r.dispatch("logbook")
	var log_motif := false
	for e in ev:
		if e.type == "sfx" and e.id == "motif_short" and is_equal_approx(e.delay, 0.4): log_motif = true
	check(drawer_motif and log_motif, "stingers: the drawer at 1.0 s, the log rewrite at 0.4 s")

func test_endings() -> void:
	check(minutes("19:34") + 12 * 60 + 21 - 1440 == minutes("07:55"), "07:55 is 19:34 + 12:21")
	check("07:55" in R02Sim.END_NEXT_ROW and "07:55" in R02Sim.END_NEXT_TURNED and "19:34" in R02Sim.END_LOG_ROW,
		"the end rows carry the arithmetic")
	var s := new_sim()
	s.debug_jump(4)
	var ev0 := s.dispatch("turn")
	check(s.facing == "B" and s.view == "room" and has_ev(ev0, "sfx", "turn"), "'turn' in the room faces the entry wall")
	s.dispatch("turn")
	check(s.facing == "A", "and back to the desk")
	s.dispatch("papers")
	check(s.dispatch("turn").is_empty() and s.view == "report", "'turn' does nothing in a close-up")
	s.dispatch("back")
	s.dispatch("door")
	var ev := s.dispatch("hint")
	check(says(ev) == R02Sim.THRESHOLD_HINT and not "turn" in says(ev).to_lower(), "the threshold hint never mentions turning")
	ev = s.dispatch("turn")
	check(s.view == "end" and s.state.turned and s.state.finished, "turn at the threshold ends the slice")
	var motif_ok := false
	for e in ev:
		if e.type == "sfx" and e.id == "motif" and is_equal_approx(e.delay, 1.4): motif_ok = true
	check(has_ev(ev, "sfx", "exhale_near") and motif_ok and has_ev(ev, "fx", "turn"), "turn: exhale, motif at 1.4 s, fx")
	check(s.end_rows() == [[R02Sim.END_TURN_ROW, "her"], [R02Sim.END_NEXT_TURNED, "her"]], "turned: both rows in her hand")
	check(s.end_lines() == [R02Sim.END_ON_STATION], "turned: end lines")
	var t := roundtrip(s)
	check(t.state.turned and t.view == "room", "turned round-trips; a save lands in the office")
	check(s.game.flag("t1x_turned") and t.game.flag("t1x_turned") and t.game.flag("t1x_threshold_crossed")
		and not s.game.flag("t1x_threshold_crossed"),
		"t1x_turned and the threshold follow the office's state through a save")
	check(s.game.value("movement_events").back() == "turned_round", "turning round is a recorded move")
	var n := new_sim()
	n.debug_jump(4)
	n.dispatch("door")
	n.dispatch("continue")
	check(n.view == "end" and not n.state.turned, "continue: the other ending")
	check(n.end_rows() == [[R02Sim.END_LOG_ROW, "her"], [R02Sim.END_NEXT_ROW, "venn"]], "not turned: hers, then his")
	var bad := new_sim()
	bad.from_dict({"schema": 5, "started": true, "turned": true})
	check(not bad.state.turned, "turned needs finished")

# ---------------------------------------------------------------------------
# Round 3, C3: chains are atomic and the player sets their speed
# ---------------------------------------------------------------------------
func step(scene: Node, seconds: float, dt := 0.05) -> void:
	var t := 0.0
	while t < seconds - 1e-6:
		scene.time += dt
		scene.room_view._tick_stage(dt)
		scene._tick_lines(dt)
		scene._tick_sfx(dt)
		t += dt

func hs(scene: Node, id: String) -> Vector2:
	return scene.room_view._hotspot_rect(id).get_center()

## Clicks `p` once a second until the click dispatches (rather than advancing a chain).
## Collects every sim event it causes. Returns false if it never got through.
func click_through(scene: Node, p: Vector2, events: Array, limit := 40) -> bool:
	for i in limit:
		var before: int = scene.click_id
		scene.click(p)
		if scene.click_id != before:
			events.append_array(scene.last_events)
			step(scene, 1.0)
			return true
		step(scene, 1.0)
	return false

func test_click_driver() -> void:
	var scene = new_scene("user://office_driver_test.json")
	await process_frame
	tide1(scene.room_sim())
	var ev: Array = []
	var ok := true
	var dial_up := func(i: int) -> Vector2: return scene.room_view._dial_up_rect(i).get_center()
	var rtime_up := func(i: int) -> Vector2:
		var r: Rect2 = scene.room_view._rtime_rect(i)
		return r.position + Vector2(r.size.x / 2.0, r.size.y / 4.0)
	var row := func(k: int) -> Vector2: return scene.room_view._report_row(k).get_center()
	var back: Vector2 = scene.BACK_RECT.get_center()
	var plan: Array = [Vector2(700, 500), hs(scene, "lamp"), Vector2(400, 640), Vector2(200, 920),
		Vector2(450, 500), Vector2(400, 640), hs(scene, "logbook"), back, hs(scene, "puddle"), hs(scene, "drawer")]
	for i in 4:
		for n in [1, 8, 5, 2][i]:
			plan.append(dial_up.call(i))
	plan.append_array([scene.room_view.DRAWER_TRY.get_center(), back, hs(scene, "logbook"), back, hs(scene, "chair"),
		hs(scene, "map"), hs(scene, "map"), hs(scene, "window"), hs(scene, "papers"),
		row.call(0), row.call(0), row.call(1), row.call(3)])
	for i in 4:
		for n in [1, 9, 3, 4][i]:
			plan.append(rtime_up.call(i))
	plan.append_array([scene.room_view.REPORT_SIGN.get_center(), back])
	for p in plan:
		ok = ok and click_through(scene, p, ev)
	check(ok, "driver: every click got through")
	check(scene.room_sim().state.report_filed and scene.room_sim().state.heard_unlatch, "driver: the report is filed and heard")
	var unlatch_before := false
	for i in 30:
		if scene.room_sim().view == "threshold":
			break
		unlatch_before = UNLATCH_LINE in scene.shown_log
		scene.click(hs(scene, "door"))
		if scene.click_id > 0 and not scene.last_events.is_empty() and scene.room_sim().view == "threshold":
			ev.append_array(scene.last_events)
		step(scene, 1.0)
	check(scene.room_sim().view == "threshold" and unlatch_before, "the unlatch line shows before the threshold")
	step(scene, 20.0)
	ok = click_through(scene, hs(scene, "door"), ev)
	check(ok and scene.room_sim().view == "end" and not scene.room_sim().state.turned, "driver reaches the end card")
	var missing := []
	for e in ev:
		if e.type == "say" and e.get("story", false) and not e.text in scene.shown_log:
			missing.append(e.text)
	check(missing.is_empty(), "every story line the sim emitted was shown (missing %s)" % [missing])
	GameView.remove_saves(scene.save_path)
	scene.queue_free()
	await process_frame

func chair_scene(path: String) -> Node:
	var scene = new_scene(path)
	scene.room_jump("R02", 2)
	var s: R02Sim = scene.room_sim()
	s.state.prints_seen = true; s.state.drawer_open = true; s.state.log_rewritten = true
	return scene

func test_chain_gate_chair() -> void:
	var scene = chair_scene("user://office_gate_chair.json")
	await process_frame
	scene.click(hs(scene, "chair"))
	check(scene.room_sim().state.seat_wet and scene.chain_active(), "the chair beat plays")
	step(scene, 0.5)
	scene.click(hs(scene, "window"))
	check(scene.room_sim().view == "room" and scene.room_sim().state.seat_wet and not scene.room_sim().has_seen("horizon")
		and not "The horizon isn't level. The house is." in scene.shown_log, "a window click 0.5 s in only advances the chain")
	var taps: int = scene.shown_log.find("Three taps on the glass.")
	var knock_at := -1
	for p in scene.played_log:
		if p[0] == "knock_glass":
			knock_at = p[1]
	check(taps >= 0 and knock_at >= 0 and knock_at <= taps, "knock_glass plays before 'Three taps' shows (%d, %d)" % [knock_at, taps])
	check(scene.room_view.hush > 0.0, "the room hushes for the advanced knock")
	GameView.remove_saves(scene.save_path)
	scene.queue_free()
	await process_frame

func test_chain_gate_drawer() -> void:
	var scene = new_scene("user://office_gate_drawer.json")
	await process_frame
	scene.room_jump("R02", 2)
	scene.dispatch("drawer")
	for i in 4:
		for n in [1, 8, 5, 2][i]:
			scene.dispatch("dial_%d" % i)
	scene.click(scene.room_view.DRAWER_TRY.get_center())
	check(scene.room_sim().state.drawer_open, "the drawer opens")
	var photo: Vector2 = scene.room_view.PHOTO_RECT.get_center()
	var looks_ok := true
	for i in 12:
		step(scene, 0.5)
		var was: bool = scene.chain_active()
		scene.click(photo)
		if was:
			looks_ok = looks_ok and int(scene.room_sim().state.photo_looks) == 0
		if int(scene.room_sim().state.photo_looks) > 0:
			break
	check(looks_ok, "look_photo clicks during the chain only advance it")
	var a: int = scene.shown_log.find("And a photograph.")
	var b: int = scene.shown_log.find("Me, from outside. From the sea side.")
	check(a >= 0 and b > a, "'And a photograph.' shows before 'Me, from outside...' (%d, %d)" % [a, b])
	check(scene.shown_log.find("There is nothing outside this window to stand on.") < b, "the whole chain shows first")
	GameView.remove_saves(scene.save_path)
	scene.queue_free()
	await process_frame

func test_hint_after_chain() -> void:
	var scene = chair_scene("user://office_gate_hint.json")
	await process_frame
	scene.click(hs(scene, "chair"))
	step(scene, 0.4)
	scene.click(scene.HUD_BUTTONS[1][1].get_center())
	var hint: String = R02Sim.HINTS["report"][0]
	check(scene.room_sim().game.state.hint.level == 1 and not hint in scene.shown_log, "the hint dispatches but waits")
	step(scene, 15.0)
	var last: int = scene.shown_log.find("Low down. Below the sill. Where the wall goes straight down into the water.")
	var h: int = scene.shown_log.find(hint)
	check(last >= 0 and h > last, "a hint during a chain shows after its last line (%d, %d)" % [last, h])
	GameView.remove_saves(scene.save_path)
	scene.queue_free()
	await process_frame

# ---------------------------------------------------------------------------
# Round 3, C7: QA nits
# ---------------------------------------------------------------------------
func test_qa_nits() -> void:
	var scene = new_scene("user://office_nits_test.json")
	await process_frame
	var mapping_ok := true
	for v in 10:
		var s := new_sim()
		s.debug_jump(1)
		s.dispatch("drawer")
		dial_to(s, [v, 0, 0, 0])
		var digits: Array = scene.room_view.dial_digits(v)
		s.dispatch("dial_0")
		var up := int(s.state.drawer_dial[0])
		s.dispatch("dial_down_0")
		s.dispatch("dial_down_0")
		mapping_ok = mapping_ok and digits[0] == up and digits[1] == v and digits[2] == int(s.state.drawer_dial[0])
	check(mapping_ok, "each dial half shows where a click on it goes")
	# Restart takes two clicks within 3 s.
	scene.room_jump("R02", 2)
	scene.dispatch("menu")
	var restart: Vector2 = scene._menu_rect(3).get_center()
	scene.click(restart)
	check(scene.room_sim().view == "menu" and scene.room_sim().state.log_read and scene._restart_armed(), "one restart click only asks")
	scene.time += 3.1
	scene.click(restart)
	check(scene.room_sim().view == "menu" and scene.room_sim().state.log_read, "one click and 3.1 s: no restart")
	scene.time += 0.5
	scene.click(restart)
	check(scene.room_sim().view == "title" and not scene.room_sim().state.log_read, "two quick clicks restart")
	# Voice cap.
	scene.room_jump("R02", 1)
	for i in 10:
		scene._play_sfx_now("page")
	var pages := 0
	for p in scene.oneshots:
		if is_instance_valid(p) and p.get_meta("sfx_id", "") == "page":
			pages += 1
	check(pages <= 2, "10 rapid pages leave at most 2 live ones (%d)" % pages)
	# The slab fades when nothing is said, and comes back for a line.
	scene._show_line("A line.", false)
	advance(scene, 0.3)
	check(scene.slab_a >= 0.99, "the slab is up while a line shows")
	advance(scene, scene.cur_hold + scene.LINE_LINGER + 1.0)
	check(scene.cur_text == "" and scene.slab_a == 0.0, "with nothing said, the line clears and the slab fades")
	GameView.remove_saves(scene.save_path)
	scene.queue_free()
	await process_frame

# ---------------------------------------------------------------------------
# The full game: T1X re-timed (room-contract section 8)
# ---------------------------------------------------------------------------
const PITCH_BLACK := "The corridor is pitch black. Light first."

func test_corridor_opens_on_lamp() -> void:
	var g := GameSim.new()
	g.dispatch("begin")
	for to in ["R03", "R04"]:
		var ev := g.dispatch("go:" + to)
		check(g.state.room == "R02" and says(ev) == PITCH_BLACK, "before P01 go:%s is refused (%s)" % [to, says(ev)])
	var s := office(g)
	for a in ["lamp", "toggle_supply", "select_b", "fit", "toggle_supply"]:
		g.dispatch(a)
	check(g.flag("P01"), "the lamp is mended")
	var ev := g.dispatch("go:R03")
	check(g.state.room == "R03" and not "rather know" in says(ev), "after P01 go:R03 lands in R03, no hold")
	g.dispatch("go:R02")
	check(g.state.room == "R02" and s.facing == "A", "and back to the office")
	ev = g.dispatch("go:R04")
	check(g.state.room == "R04", "and the listening room")

func test_drawer_items() -> void:
	var s := new_sim()
	s.debug_jump(2)
	s.dispatch("drawer")
	check(not s.game.has_item("venn_tide_sheet"), "no sheet before the drawer")
	var all: Array = []
	for code in [[4, 4, 4, 4], [0, 7, 1, 3], [1, 8, 5, 4], [1, 8, 5, 0]]:
		dial_to(s, code)
		all.append_array(s.dispatch("try_drawer"))
	check(fx_ev(all, "item_added").is_empty() and s.game.state.inventory == [], "near misses grant nothing")
	dial_to(s, [1, 8, 5, 2])
	all.append_array(s.dispatch("try_drawer"))
	all.append_array(s.dispatch("try_drawer"))
	s.dispatch("back")
	all.append_array(s.dispatch("drawer"))
	var got := []
	for e in fx_ev(all, "item_added"):
		got.append(e.item)
	check(got == ["venn_tide_sheet", "inspection_lens"], "the drawer grants the sheet and the lens exactly once (%s)" % [got])
	check(s.game.has_item("venn_tide_sheet") and s.game.has_item("inspection_lens"), "both are held")
	var t := roundtrip(s)
	check(t.game.has_item("inspection_lens"), "the lens survives a save")

func drawer_open_sim(prints: bool) -> R02Sim:
	var s := new_sim()
	s.debug_jump(2)
	if prints:
		s.dispatch("puddle")
	s.dispatch("drawer")
	dial_to(s, [1, 8, 5, 2])
	s.dispatch("try_drawer")
	s.dispatch("back")
	return s

func test_rewrite_needs_tide1() -> void:
	for only in ["P02", "P03"]:
		var s := drawer_open_sim(true)
		s.game.set_flag(only)
		s.dispatch("logbook")
		check(not s.state.log_rewritten and s.objective() == "instruments", "only %s: no rewrite" % only)
	for order in [["P02", "P03"], ["P03", "P02"]]:
		var s := drawer_open_sim(false)
		s.game.set_flag(order[0])
		s.dispatch("logbook")
		s.dispatch("back")
		check(not s.state.log_rewritten, "%s alone: no rewrite" % order[0])
		s.game.set_flag(order[1])
		check(s.objective() == "reread", "both done: objective reread")
		var ev := s.dispatch("logbook")
		check(s.state.log_rewritten and not s.state.prints_seen and has_ev(ev, "fx", "log_write"),
			"%s then %s: the log rewrites, without the prints" % order)
	check(R02Sim.HINTS["reread"] == ["Something in the office has changed.", "Venn's log is not finished with you.",
		"Go back to the Intake Office and open the tide log."], "reread hints")
	check(R02Sim.OBJECTIVES["reread"] == "Something on the desk has changed.", "reread objective")
	check(R02Sim.HINTS["instruments"].size() == 3 and "chart room" in R02Sim.HINTS["instruments"][2], "instruments hints")
	var bad := new_sim()
	bad.from_dict({"schema": 5, "started": true, "p01_complete": true, "log_read": true, "log_rewritten": true})
	check(not bad.state.log_rewritten, "a rewrite needs the drawer open")

func test_callback() -> void:
	var s := drawer_open_sim(true)
	var ev := s.game.dispatch("go:R01")
	ev = s.game.dispatch("go:R02")
	check(not has_ev(ev, "fx", "notice"), "no callback before tide_done(1)")
	tide1(s)
	s.game.dispatch("go:R01")
	ev = s.game.dispatch("go:R02")
	var n := fx_ev(ev, "notice")
	var pen := false
	for e in ev:
		if e.type == "sfx" and e.id == "pen_far" and is_equal_approx(e.delay, 0.4): pen = true
	check(n.size() == 1 and n[0].key == "callback" and pen and says(ev) == "", "the callback: a pen at 0.4 s and one notice, no line")
	check(s.state.callback_heard and "callback" in s.state.notices_seen, "callback heard and noted")
	s.game.dispatch("go:R01")
	ev = s.game.dispatch("go:R02")
	check(not has_ev(ev, "fx", "notice") and not has_ev(ev, "sfx", "pen_far"), "the callback fires once")
	var r := drawer_open_sim(true)
	tide1(r)
	r.dispatch("logbook")
	r.dispatch("back")
	r.game.dispatch("go:R01")
	ev = r.game.dispatch("go:R02")
	check(not has_ev(ev, "sfx", "pen_far"), "no callback once the log has rewritten")
	var t := roundtrip(s)
	check(t.state.callback_heard, "callback_heard round-trips")
	t.from_dict({"schema": 5, "started": true, "p01_complete": true, "log_read": true, "callback_heard": true})
	check(not t.state.callback_heard, "callback_heard needs the drawer open")

func test_t1x_latch() -> void:
	var s := sim_before_chair()
	s.dispatch("chair")
	s.game.set_flag("P06")
	var got := []
	for to in ["R01", "R03", "R04", "R05", "R06"]:
		got.append(says(s.game.dispatch("go:" + to)))
		check(s.game.state.room == "R02", "T1X: go:%s refused" % to)
	check(got == [R02Sim.LATCHED_LINE, "Latched.", "Latched.", "Latched.", "Latched."], "latched, announced once (%s)" % [got])
	var d := sim_before_chair()
	d.dispatch("chair")
	check(says(d.dispatch("door")) == R02Sim.LATCHED_LINE, "the corridor door announces the latch")
	d.dispatch("turn")
	check(says(d.dispatch("outer_door")) == "Latched.", "the outer door shares the announcement")
	check(says(d.game.dispatch("go:R01")) == "Latched." and d.game.state.room == "R02", "and so does the exit")
	var o := sim_before_chair()
	o.dispatch("chair")
	o.dispatch("turn")
	check(says(o.dispatch("outer_door")) == R02Sim.LATCHED_LINE, "the outer door first: the rule")
	o.dispatch("turn")
	check(says(o.dispatch("door")) == "Latched.", "then the corridor door: just the latch")
	var t := roundtrip(o)
	check(t.state.latch_announced and says(t.game.dispatch("go:R01")) == "Latched.", "latch_announced round-trips")
	t.from_dict({"schema": 5, "latch_announced": true})
	check(not t.state.latch_announced, "latch_announced needs the wet seat")
	# T1X is completable with R02 actions only.
	var c := sim_before_chair()
	c.dispatch("chair")
	file_and_back(c)
	c.dispatch("door")
	c.dispatch("continue")
	c.dispatch("end_continue")
	check(c.game.state.room == "R03" and c.game.flag("t1x_threshold_crossed") and c.game.tide() == 2,
		"T1X completes from the office alone")
	c.game.dispatch("go:R02")
	check(c.game.dispatch("go:R01").size() > 0 and c.game.state.room == "R01", "after the threshold the doors are normal")

func threshold_run(mode: String) -> R02Sim:
	var s := new_sim()
	s.debug_jump(4)
	tide1(s)
	s.dispatch("door")
	s.dispatch(mode)
	return s

func test_threshold_converges() -> void:
	var flags := {}
	var reach := {}
	for mode in ["continue", "turn"]:
		var s := threshold_run(mode)
		check(s.state.finished and s.view == "end" and not s.game.flag("t1x_threshold_crossed"), "%s: finished, no flag yet" % mode)
		check(not "Tide I continues." in s.end_lines(), "%s: the card never says Tide I continues" % mode)
		var ev := s.dispatch("end_continue")
		var tides := fx_ev(ev, "tide")
		check(tides.size() == 1 and tides[0].tide == 2, "%s: exactly one tide card, Tide II" % mode)
		check(s.game.flag("t1x_threshold_crossed") and s.game.state.room == "R03" and s.facing == "A" and s.local_view == "room",
			"%s: crossed, in R03" % mode)
		check(has_ev(ev, "fx", "travel"), "%s: travels" % mode)
		var f: Dictionary = s.game.state.flags.duplicate()
		f.erase("t1x_turned")
		flags[mode] = f
		reach[mode] = s.game.reachable("R02")
		check(s.game.flag("t1x_turned") == (mode == "turn"), "%s: t1x_turned" % mode)
		check(s.dispatch("end_continue").is_empty() or s.game.state.room == "R03", "end_continue outside the card does nothing")
	check(flags["continue"] == flags["turn"], "both paths give the same flags apart from t1x_turned")
	check(reach["continue"] == reach["turn"], "both paths reach the same rooms")

func test_facing() -> void:
	var s := new_sim()
	s.debug_jump(1)
	check(s.facing == "A", "a jump faces the desk")
	var ev := s.dispatch("turn")
	check(s.facing == "B" and says(ev) == "The entry wall. The way I came in." and has_ev(ev, "sfx", "turn"), "first turn: the B line")
	check(s.state.b_seen, "b_seen")
	check(s.dispatch("mug").is_empty() and not s.has_seen("mug"), "A ids are ignored facing B")
	check(says(s.dispatch("barometer")) != "", "B ids answer facing B")
	ev = s.dispatch("turn")
	check(s.facing == "A" and says(ev) == "", "turn back: no line")
	check(s.dispatch("barometer").is_empty(), "B ids are ignored facing A")
	ev = s.dispatch("turn")
	check(s.facing == "B" and says(ev) == "", "the B line once")
	var t := roundtrip(s)
	check(t.facing == "A" and t.state.b_seen, "a load faces the desk; b_seen round-trips")
	s.game.dispatch("go:R01")
	s.game.dispatch("go:R02")
	check(s.facing == "A", "an arrival faces the desk")
	s.dispatch("turn")
	s.dispatch("lamp")
	check(s.view == "room", "lamp is ignored facing B")

## A look-away-ready office at band b: every earlier tide done, nothing applied yet.
func away_sim(t: int) -> R02Sim:
	var s := office(game_at(t))
	s.state.look_away_applied = []
	return s

func test_look_away_bands() -> void:
	for t in [2, 3]:
		var s := away_sim(t)
		var ev: Array = []
		ev.append_array(s.dispatch("papers")); ev.append_array(s.dispatch("back"))
		ev.append_array(s.dispatch("notebook")); ev.append_array(s.dispatch("back"))
		s.game.dispatch("go:R01"); ev.append_array(s.game.dispatch("go:R02"))
		check(s.state.look_away_applied.is_empty() and not has_ev(ev, "fx", "look_away"), "no look-away at band %d" % s.band())
	var b2 := office(game_at(3))
	b2.game.set_flag("P09")
	check(b2.band() == 2, "P09 brings band 2")
	b2.game.dispatch("go:R01")
	var ev := b2.game.dispatch("go:R02")
	var la := fx_ev(ev, "look_away")
	check(la.size() == 1 and la[0].change == "mug" and b2.has_seen("away_mug") and b2.look_away("mug"), "band 2: the mug on arrival")
	check(says(b2.dispatch("mug")) == "His mug is full to the brim. Seawater. I didn't fill it.", "the brimming mug")
	# Band 7: one change per return, in order.
	var s := away_sim(9)
	check(s.band() == 7, "tide IX is band 7")
	var none: Array = []
	s.dispatch("turn")
	s.dispatch("board")
	check(s.view == "board", "the solved board opens")
	none.append_array(s.dispatch("back"))
	check(s.view == "room" and s.facing == "B", "back from the board faces the entry wall")
	none.append_array(s.dispatch("notebook")); none.append_array(s.dispatch("back"))
	none.append_array(s.dispatch("menu")); none.append_array(s.dispatch("resume"))
	none.append_array(s.dispatch("turn"))
	none.append_array(s.dispatch("menu")); none.append_array(s.dispatch("back"))
	check(s.facing == "A" and s.state.look_away_applied.is_empty() and not has_ev(none, "fx", "look_away"),
		"board, notebook facing B, turning B to A and the menu change nothing")
	var order := []
	var per_return_ok := true
	var steps := [["papers", "back"], ["notebook", "back"], ["@arrive"], ["drawer", "back"], ["notebook", "back"], ["@arrive"]]
	for st in steps:
		var e: Array = []
		if st[0] == "@arrive":
			s.game.dispatch("go:R01")
			e = s.game.dispatch("go:R02")
		else:
			for a in st:
				e.append_array(s.dispatch(a))
		var got := fx_ev(e, "look_away")
		per_return_ok = per_return_ok and got.size() == 1
		if got.size() == 1:
			order.append(got[0].change)
	check(per_return_ok and order == ["mug", "door", "stove", "window", "puddle", "coat"], "one change per return, in order (%s)" % [order])
	for id in order:
		check(s.has_seen("away_" + id), "away_%s noted" % id)
	var e2 := s.dispatch("logbook")
	e2.append_array(s.dispatch("back"))
	check(not has_ev(e2, "fx", "look_away"), "nothing left to change")
	check(says(s.dispatch("door")) == "Water is coming under the door from the corridor side. The corridor floor beyond is dry.", "the seeping door")
	check(says(s.dispatch("stove")).begins_with("Water is seeping round the stove door."), "the flooded stove")
	var pe := s.dispatch("puddle")
	check(says(pe) == "The puddle. Two trails, dried to salt. One of them is mine. | Wet footprints go up the wall beside the door. They don't come down."
		and is_equal_approx(say_ev(pe, "up the wall").delay, 2.0), "the footprints up the wall")
	var ce := s.dispatch("coat")
	check(says(ce) == "The hood is up. It's facing the desk. | There are shoulders in it. Nobody is wearing it.", "the hood")
	check(say_ev(s.dispatch("window"), "fourth hand").get("story", false), "the fourth hand")
	# Saves.
	var t := roundtrip(s)
	check(t.state.look_away_applied == ["mug", "door", "stove", "window", "puddle", "coat"], "look_away_applied round-trips")
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	for bad_list in [["door"], ["mug", "stove"], ["mug", "nope"], ["mug", 3], ["mug", "door", "stove", "window", "puddle", "coat", "mug"]]:
		d.rooms.R02.look_away_applied = bad_list
		var b := new_sim()
		b.from_dict(d)
		check(b.state.look_away_applied.is_empty(), "a non-prefix look-away list is rejected (%s)" % [bad_list])
	d.rooms.R02.look_away_applied = ["mug", "door"]
	var p := new_sim()
	p.from_dict(d)
	check(p.state.look_away_applied == ["mug", "door"], "a prefix is accepted")

func notice_keys(ev: Array) -> Array:
	var out := []
	for e in fx_ev(ev, "notice"):
		out.append(e.key)
	return out

func test_notices() -> void:
	for t in range(3, 10):
		var s := office(game_at(t))
		var b := s.band()
		s.state.notices_seen = ["callback"]
		s.game.dispatch("go:R01")
		var ev := s.game.dispatch("go:R02")
		check(notice_keys(ev) == ["b%d" % b] and says(ev) == "", "band %d: one notice, no line" % b)
		check(has_ev(ev, "sfx", "clock_stop") == (b == 6), "clock_stop only with b6 (band %d)" % b)
		var want := ["callback"]
		for n in range(1, b + 1):
			want.append("b%d" % n)
		check(s.state.notices_seen == want, "skipped bands are marked seen (band %d: %s)" % [b, s.state.notices_seen])
		s.game.dispatch("go:R01")
		ev = s.game.dispatch("go:R02")
		check(notice_keys(ev).is_empty(), "band %d: the notice once" % b)
	var g := office(game_at(2))
	g.game.dispatch("go:R01")
	check(notice_keys(g.game.dispatch("go:R02")).is_empty(), "band 0 after the threshold: no notice")
	var l := new_sim()
	l.from_dict({"schema": 6, "started": true, "rooms": {"R02": {"notices_seen": ["b1", "b1", "zz", 4, "callback"]}}})
	check(l.state.notices_seen == ["b1", "callback"], "notices_seen: known keys, deduplicated (%s)" % [l.state.notices_seen])

func sweep(s: R02Sim) -> Array:
	var empty := []
	for h in R02Sim.HOTSPOTS:
		if s.facing != "A": s.dispatch("turn")
		if says(s.dispatch(h)) == "": empty.append(h)
		s.dispatch("back")
		if s.view != "room": s.view = "room"
	for h in R02Sim.HOTSPOTS_B:
		if s.facing != "B": s.dispatch("turn")
		if says(s.dispatch(h)) == "": empty.append(h)
		s.dispatch("back")
		if s.view != "room": s.view = "room"
	return empty

func test_hotspots_every_tide() -> void:
	var t1x := new_sim()
	t1x.debug_jump(3)
	var e := sweep(t1x)
	check(e.is_empty(), "T1X: every A and B hotspot answers (%s)" % [e])
	t1x.dispatch("turn")
	for t in range(2, 10):
		var s := office(game_at(t))
		e = sweep(s)
		check(e.is_empty(), "tide %d: every A and B hotspot answers (%s)" % [t, e])
	for t in range(2, 10):
		var s := office(game_at(t))
		var b := s.band()
		s.dispatch("window")
		check(s.has_seen("horizon") == (b >= 3) and s.has_seen("eye") == (b >= 4), "window at band %d: horizon %s eye %s" % [b, b >= 3, b >= 4])
		s.dispatch("map")
		check(s.state.soundings_heard, "band %d: the first map is the soundings" % b)
		var ev := s.dispatch("map")
		check(s.state.contours_seen == (b >= 4) and has_ev(ev, "fx", "contours") == (b >= 4), "contours at band %d: %s" % [b, b >= 4])
		ev = s.dispatch("hooks")
		check(s.has_seen("tag") == (b >= 6) and s.has_seen("hook_measures") == (b >= 6) and s.state.hook_tags_seen == (b >= 6),
			"hook tags at band %d: %s" % [b, b >= 6])
		if b >= 6:
			check(says(ev).split(" | ").size() == 4 and say_ev(ev, "ZERO 4").story and is_equal_approx(say_ev(ev, "A.M.").delay, 8.6),
				"the hook-tag chain")
			var n: int = s.seen().size()
			check(says(s.dispatch("hooks")) == "My numbers on his hooks. The ninth one is mine." and s.seen().size() == n,
				"the hook tags once")
		else:
			check(says(ev) == "Nine hooks. The ninth is wet again. Nothing has hung on it.", "hooks at band %d" % b)
	check(says(t1x.dispatch("hooks")) == "Nine hooks. The ninth is wet again. Nothing has hung on it.", "hooks at T1X")

func test_photo_states() -> void:
	var s := office(game_at(3))
	check(s.photo_variant() == "after", "band 1, not turned: after")
	s.dispatch("drawer")
	var ev := s.dispatch("look_photo")
	check(s.view == "photo" and s.photo_from == "drawer", "the photograph opens from the drawer")
	check(says(ev) == "The photograph has changed. The chair in it is empty. | In the lower pane there's a lit window. In the window, this photograph."
		and is_equal_approx(say_ev(ev, "lower pane").delay, 2.4) and s.state.photo_changed_seen, "after: the empty chair")
	check(says(s.dispatch("photo")) == "The photograph. It stays changed.", "the change once")
	s.dispatch("turn_over")
	check(not s.photo_back, "turn_over before P20 does nothing")
	s.game.set_flag("P20")
	check(says(s.dispatch("turn_over")) == "His hand, on the back." and s.photo_back, "turn_over after P20")
	s.dispatch("turn_over")
	check(not s.photo_back, "and back to the front")
	s.dispatch("turn_over")
	s.dispatch("back")
	check(s.view == "drawer" and not s.photo_back, "back from the photograph: the drawer, front up")
	check(says(s.dispatch("look_photo")) == "The photograph has gone from the drawer. It's on the board, by the door." and s.view == "drawer",
		"after P20 the photograph is not in the drawer")
	var tr := office(game_at(3))
	tr.state.turned = true
	tr.reconcile()
	check(tr.photo_variant() == "turned", "band 1, turned: turned")
	tr.dispatch("drawer")
	ev = tr.dispatch("look_photo")
	check(says(ev) == "The photograph has changed. In it I have turned round in the chair, to face the camera. | There is nothing on the front of my head.",
		"turned: she faces the camera")
	var b0 := new_sim()
	b0.debug_jump(3)
	check(b0.photo_variant() == "drawer", "Tide I: the drawer print")
	var lens := drawer_open_sim(false)
	lens.dispatch("drawer")
	lens.dispatch("look_photo")
	lens.dispatch("item:inspection_lens")
	ev = lens.dispatch("photo")
	check(lens.has_seen("behind") and "someone behind me" in says(ev), "the lens on the photograph: behind")
	tr.dispatch("item:inspection_lens")
	check(says(tr.dispatch("photo")) == "Through the lens: the same changed print. Sharper." and tr.game.has_item("inspection_lens"),
		"the lens on a changed print; durable")
	var rt := roundtrip(s)
	check(rt.state.photo_changed_seen, "photo_changed_seen round-trips")

func test_service_door() -> void:
	var g := with_flags(["P01"])
	var s := office(g)
	check(says(g.dispatch("go:R05")) == R02Sim.SERVICE_NO_KEY and g.state.room == "R02", "without P06: refused")
	s.dispatch("turn")
	check(says(s.dispatch("service_door")) == R02Sim.SERVICE_NO_KEY, "the service door without P06")
	var k := with_flags(["P01", "P06"])
	var o := office(k)
	k.give("service_key")
	check(o.service_locked(), "locked with the key held")
	check(says(k.dispatch("go:R05")) == "Locked. The kitchen key from the capsule should fit it." and k.state.room == "R02", "go:R05 refused")
	check(says(k.dispatch("go:R06")) != "" and k.state.room == "R02" and k.has_item("service_key"), "go:R06 refused; key kept")
	k.dispatch("item:service_key")
	check(says(k.dispatch("door")) == "Wrong door. This one has no keyhole on this side." and k.has_item("service_key"), "key on the corridor door")
	o.dispatch("turn")
	check(says(o.dispatch("service_door")) == "Locked from the kitchen side. The key from the capsule should fit.", "the locked service door")
	k.dispatch("item:service_key")
	check(says(k.dispatch("outer_door")) == "That door isn't locked." and k.has_item("service_key"), "key on the outer door")
	k.dispatch("item:service_key")
	check(says(k.dispatch("barometer")) == GameSim.GENERIC_WRONG_USE and k.has_item("service_key"), "key on the barometer: generic, kept")
	k.dispatch("item:service_key")
	var ev := k.dispatch("service_door")
	check(not k.has_item("service_key") and o.state.service_unlocked and has_ev(ev, "sfx", "lock_turn")
		and says(ev).begins_with("The key turns.") and is_equal_approx(say_ev(ev, "smell of soup").delay, 1.6), "the key turns")
	check(not o.service_locked(), "unlocked")
	check(says(o.dispatch("service_door")) == "The service door, unlocked. The passage beyond smells of soup.", "the open service door")
	k.dispatch("go:R05")
	check(k.state.room == "R05", "go:R05 succeeds")
	k.dispatch("go:R02")
	k.dispatch("go:R06")
	check(k.state.room == "R06", "go:R06 succeeds")
	var t := roundtrip(o)
	check(t.state.service_unlocked and not t.service_locked(), "service_unlocked round-trips")
	var n := with_flags(["P01", "P06"])
	n.dispatch("go:R05")
	check(n.state.room == "R05", "P06 with no key held: open")
	# The objective after the threshold.
	var p := office(game_at(3))
	p.game.give("service_key")
	p.state.service_unlocked = false
	check(p.objective() == "service" and R02Sim.HINTS["service"][2] == "Select the kitchen service key, then the service door.", "objective service")

func test_receipt() -> void:
	var s := new_sim()
	s.dispatch("begin")
	s.dispatch("turn")
	check(says(s.dispatch("receipt")) == "A paper pinned by the door. Too dark to read." and not s.game.flag("o01_found"), "no flag before P01")
	var l := new_sim()
	l.debug_jump(1)
	l.dispatch("turn")
	var ev := l.dispatch("receipt")
	check(l.game.flag("o01_found") and has_ev(ev, "sfx", "page") and says(ev).split(" | ").size() == 3
		and is_equal_approx(say_ev(ev, "He paid").delay, 2.6), "o01_found after P01, with the chain")
	ev = l.dispatch("receipt")
	check(says(ev) == "The mug receipt. One and four, to keep a chipped mug.", "the receipt again")

func test_contract() -> void:
	var s := new_sim()
	s.dispatch("begin")
	s.dispatch("papers")
	check(s.view == "duty", "the duty card")
	var ev := s.dispatch("read_contract")
	check(s.has_seen("contract") and has_ev(ev, "sfx", "page") and says(ev).split(" | ").size() == 3
		and say_ev(ev, "two stripes").story, "read_contract from the duty card")
	check(says(s.dispatch("read_contract")) == "My contract. Two stripes on the pennant. Do not certify what I have not seen.", "and again")
	var n := new_sim()
	n.debug_jump(1)
	n.dispatch("papers")
	check(n.view == "note", "the note")
	n.dispatch("read_contract")
	check(n.has_seen("contract"), "read_contract from the note")
	check(n.dispatch("read_contract").size() == 1, "the later line is one line")
	var r := new_sim()
	r.dispatch("begin")
	check(r.dispatch("read_contract").is_empty(), "read_contract in the room does nothing")

## The board at Tide VII, loaded by real actions.
func board_sim() -> R02Sim:
	var s := office(game_at(7))
	s.game.give("venn_correspondence")
	s._observe("contract")
	s.dispatch("turn")
	s.dispatch("item:venn_correspondence")
	s.dispatch("board")
	return s

func expected_refusal(pins: Array, stamp: String) -> String:
	if pins.size() < 3: return "The thread has to run all the way. Three pins first."
	if "m_callis" in pins or "m_orme" in pins: return "Their signatures don't carry the sentence. Mine does."
	if "m_countersign" in pins: return "That's his name, not mine. The thread follows mine."
	if pins != R02Sim.BOARD_ANSWER: return "The name went from the contract, to the inquiry, to his letter. The thread should go the same way."
	if stamp == "stamp_board": return "The Board didn't assign me. He asked."
	if stamp == "stamp_unknown": return "It isn't unknown. It's in his letter, in his hand."
	return ""

func test_p20() -> void:
	# Loading the board.
	var early := office(game_at(6))
	early.game.give("venn_correspondence")
	early.dispatch("turn")
	check(says(early.dispatch("board")) == "A comparison board. Venn's letters would go on it, side by side with the contract.", "board with the letters")
	early.dispatch("item:venn_correspondence")
	check(says(early.dispatch("board")) == "Not yet. I don't know what I'm comparing them against." and not early.state.board_loaded, "before tide_done(6)")
	var c := office(game_at(7))
	c.dispatch("turn")
	check(says(c.dispatch("board")) == "A comparison board. Cork, three pins, a rail of rubber stamps. Nothing pinned to it.", "the empty board")
	c.game.give("venn_correspondence")
	c.dispatch("item:venn_correspondence")
	check(says(c.dispatch("board")).begins_with("His letters are all about a name.") and not c.state.board_loaded, "needs the contract")
	c._observe("contract")
	c.dispatch("item:venn_correspondence")
	var ev := c.dispatch("board")
	check(c.state.board_loaded and c.view == "board" and count_ev(ev, "sfx", "pin") == 3 and c.game.has_item("venn_correspondence"),
		"loading: three pins, the board opens, the letters are kept")
	c.dispatch("back")
	check(c.view == "room" and c.facing == "B", "back from the board faces B")
	c.dispatch("item:venn_correspondence")
	check(says(c.dispatch("board")) == "They're already on the board.", "already loaded")
	check(c.objective() == "board" and R02Sim.HINTS["board"].size() == 3, "objective board")
	check(says(c.dispatch("board")) == "His letters, the inquiry clipping and the contract. Three pins and a thread." and c.view == "board", "the loaded board")
	# Reading.
	for a in ["read_contract", "read_clipping", "read_letter", "seal"]:
		check(says(c.dispatch(a)) != "", "board %s answers" % a)
	check(says(c.dispatch("seal")) == "Sealed with his three-cut seal. It won't lift.", "the seal before")
	check(says(c.dispatch("provenance")) == "Pick a stamp from the rack first.", "no stamp")
	check(c.dispatch("stamp_board").is_empty() and c.held_stamp == "stamp_board", "a stamp is picked up silently")
	c.dispatch("stamp_board")
	check(c.held_stamp == "", "the same stamp again puts it down")
	# Pins: a 4th is refused; unpinning compacts.
	for m in ["m_callis", "m_orme", "m_mercer"]:
		ev = c.dispatch(m)
		check(has_ev(ev, "sfx", "pin") and says(ev) == "", "pin %s" % m)
	var before: Array = c.state.board_pins.duplicate()
	check(says(c.dispatch("m_sentence")) == "Three pins. Take one out first." and c.state.board_pins == before, "a 4th pin is refused")
	ev = c.dispatch("m_orme")
	check(has_ev(ev, "sfx", "unpin") and c.state.board_pins == ["m_callis", "m_mercer"], "unpinning compacts")
	c.dispatch("slot_0")
	check(c.state.board_pins == ["m_mercer"], "slot_0 unpins and compacts")
	check(c.dispatch("slot_2").is_empty() and c.state.board_pins == ["m_mercer"], "an empty slot does nothing")
	# Persistence.
	c.dispatch("back")
	c.dispatch("board")
	check(c.state.board_pins == ["m_mercer"], "pins persist across back")
	var rt := roundtrip(c)
	check(rt.state.board_pins == ["m_mercer"] and rt.state.board_loaded and rt.facing == "A", "pins round-trip")
	# Exhaustive: every ordered 3-pin chain x every stamp, and every 0-2 pin state.
	var s := board_sim()
	var ids: Array = R02Sim.MARKS.keys()
	var cases := [[]]
	for a in ids:
		cases.append([a])
		for b in ids:
			if b == a: continue
			cases.append([a, b])
			for d in ids:
				if d == a or d == b: continue
				cases.append([a, b, d])
	check(cases.size() == 1 + 6 + 30 + 120, "157 pin states")
	var all_ok := true
	var solvers := []
	var bad_msgs := []
	for pins in cases:
		for st in R02Sim.STAMPS:
			var want := expected_refusal(pins, st)
			if want == "":
				solvers.append([pins, st])
				continue
			s.state.board_pins = []
			for m in pins:
				s.dispatch(m)
			s.dispatch(st)
			var snap := JSON.stringify(s.to_dict())
			var e := s.dispatch("provenance")
			var ok: bool = says(e) == want and has_ev(e, "sfx", "stamp_dry") and s.held_stamp == "" \
				and JSON.stringify(s.to_dict()) == snap and not s.game.flag("P20")
			if not ok and bad_msgs.size() < 3:
				bad_msgs.append("%s %s: %s" % [pins, st, says(e)])
			all_ok = all_ok and ok
	check(all_ok, "every wrong board is refused by the first rule and changes nothing (%s)" % [bad_msgs])
	check(solvers == [[R02Sim.BOARD_ANSWER, "stamp_venn"]], "only the answer with REQUESTED BY VENN can solve (%s)" % [solvers])
	# The solve.
	s.state.board_pins = []
	for m in R02Sim.BOARD_ANSWER:
		s.dispatch(m)
	s.dispatch("stamp_venn")
	var tide_before: int = s.game.tide()
	ev = s.dispatch("provenance")
	check(s.game.flag("P20") and s.state.board_stamped and s.board_solved() and s.has_seen("why_ada") and s.held_stamp == "",
		"the right thread and stamp solve P20")
	check(not has_ev(ev, "fx", "tide") and s.game.tide() == tide_before, "P20 alone does not finish Tide VII")
	check(has_ev(ev, "fx", "p20_solved") and has_ev(ev, "sfx", "stamp") and has_ev(ev, "sfx", "seal") and has_ev(ev, "sfx", "oilskin"),
		"the solve's sounds")
	check(says(ev).split(" | ").size() == 9 and is_equal_approx(say_ev(ev, "'Yes.'").delay, 11.4)
		and is_equal_approx(say_ev(ev, "developing tray").delay, 19.6) and say_ev(ev, "You could have asked.").story, "the reveal chain")
	check("developing tray on the 15th" in R02Sim.OBSERVATIONS["why_ada"] and "She will need to see herself from outside" in R02Sim.OBSERVATIONS["why_ada"],
		"why_ada carries the photograph's back")
	var again := s.dispatch("provenance")
	again.append_array(s.dispatch("m_orme"))
	again.append_array(s.dispatch("slot_0"))
	again.append_array(s.dispatch("stamp_board"))
	check(count_say(again, R02Sim.BOARD_DONE) == 4 and s.state.board_pins == R02Sim.BOARD_ANSWER and s.seen().count("why_ada") == 1,
		"after the solve: it's done, nothing changes")
	check(says(s.dispatch("seal")) == "'You have already refused to make a person disappear for the convenience of a form.'", "the seal after")
	s.dispatch("photo")
	check(s.view == "photo" and s.photo_from == "board", "the photograph on the board")
	s.dispatch("turn_over")
	check(s.photo_back, "turn it over")
	s.dispatch("back")
	check(s.view == "board" and not s.photo_back, "back from the photograph: the board")
	var be := s.dispatch("back")
	check(s.view == "room" and s.facing == "B" and not has_ev(be, "fx", "look_away"), "back from the board: room, facing B")
	s.dispatch("turn")
	check(says(s.dispatch("coat")) == "It said yes. I'm not going to ask it anything else.", "the coat after the board")
	s.dispatch("drawer")
	check(says(s.game.dispatch("back")) == "" and says(s.dispatch("drawer")) == "His watch. The photograph has gone from the drawer.", "the drawer after the board")
	var t := roundtrip(s)
	check(t.state.board_stamped and t.board_solved() and t.game.flag("P20"), "the solved board round-trips")
	# Loads.
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	d.rooms.R02.board_pins = []
	d.rooms.R02.board_stamped = false
	d.rooms.R02.board_loaded = false
	var l := new_sim()
	l.from_dict(d)
	check(l.board_solved() and l.state.board_pins == R02Sim.BOARD_ANSWER and l.state.board_stamped and l.state.board_loaded,
		"a save with P20 and an empty board loads solved")
	d.flags.erase("P20")
	d.rooms.R02.board_stamped = true
	d.rooms.R02.board_pins = ["m_callis", "m_mercer", "m_sentence"]
	l.from_dict(d)
	check(not l.state.board_stamped and l.state.board_loaded and not l.game.flag("P20"), "a stamp on the wrong thread is dropped")
	d.rooms.R02.board_pins = ["m_mercer", "m_mercer", "nope", 3, "m_orme", "m_callis", "m_sentence"]
	l.from_dict(d)
	check(l.state.board_pins == ["m_mercer", "m_orme", "m_callis"], "pins: known marks, no duplicates, at most three (%s)" % [l.state.board_pins])
	check(office(with_flags(["P20"])).board_solved(), "with_flags P20 gives board_solved")

func test_apply_ending() -> void:
	var s := office(game_at(9))
	s.apply_ending("sever")
	check(not s.has_seen("coat_collapsed"), "sever: no coat_collapsed")
	s.apply_ending("continue")
	check(s.has_seen("coat_collapsed"), "continue: coat_collapsed")

func test_debug_prepare() -> void:
	for t in range(1, 10):
		var g := game_at(t)
		var s := office(g)
		var b := g.weather_band()
		check(g.has_item("pencil"), "t%d: pencil" % t)
		check(s.state.finished == (t >= 2) and g.has_item("inspection_lens") == (t >= 2), "t%d: office chain and lens" % t)
		if t >= 2:
			var want := ["callback"]
			for n in range(1, b + 1):
				want.append("b%d" % n)
			check(s.state.notices_seen == want, "t%d: notices %s" % [t, s.state.notices_seen])
			var la := []
			for e in R02Sim.LOOK_AWAY:
				if e[1] <= mini(maxi(0, t - 2), 7):
					la.append(e[0])
			check(s.state.look_away_applied == la, "t%d: look-away %s" % [t, s.state.look_away_applied])
			for id in la:
				check(s.has_seen("away_" + id), "t%d: away_%s noted" % [t, id])
		check(s.state.service_unlocked == (t >= 3) and not g.has_item("service_key"), "t%d: service door" % t)
		check(s.state.board_stamped == (t >= 8) and s.board_solved() == (t >= 8), "t%d: board" % t)
		if t >= 8:
			check(s.has_seen("contract") and s.has_seen("why_ada") and g.flag("P20"), "t%d: contract and why_ada" % t)
		check(not s.state.hook_tags_seen, "t%d: hook tags unread" % t)
		check(s.facing == "A", "t%d: facing the desk" % t)
		check(R02Sim.OBJECTIVES.has(s.objective()) and R02Sim.HINTS.has(s.objective()), "t%d: objective %s has text and hints" % [t, s.objective()])
	check(office(game_at(5)).objective() == "away_t5", "away objective by tide")

func test_debug_jumps() -> void:
	var s := new_sim()
	s.debug_jump(6)
	check(s.game.tide() == 7 and s.facing == "B" and s.state.board_loaded and not s.board_solved(), "jump 6: the board ready")
	check(s.has_seen("contract"), "jump 6: the contract read")
	s.dispatch("board")
	check(s.view == "board", "jump 6: the board opens")
	var t := new_sim()
	t.debug_jump(7)
	check(t.game.tide() == 8 and t.facing == "B" and t.board_solved(), "jump 7: the solved board")
	for n in range(0, 6):
		var j := new_sim()
		j.debug_jump(n)
		check(j.stage() == mini(n, 3) and j.state.finished == (n >= 5), "jump %d keeps its stage" % n)

func test_record_moves() -> void:
	var allowed := ["lamp_mended", "log_read", "drawer_opened", "report_signed", "held_still", "turned_round"]
	var src := FileAccess.get_file_as_string("res://game/rooms/R02/R02_sim.gd")
	var re := RegEx.new()
	re.compile("record_move\\(\"([a-z_]+)\"\\)")
	var found := []
	for m in re.search_all(src):
		found.append(m.get_string(1))
	var ok := not found.is_empty()
	for f in found:
		ok = ok and f in allowed
	check(ok and found.size() == 6, "R02 records only its six moves (%s)" % [found])
	for mode in ["continue", "turn"]:
		var s := t1x_full_run()
		s.dispatch("door")
		s.dispatch(mode)
		var moves: Array = s.game.value("movement_events")
		var in_list := true
		for m in moves:
			in_list = in_list and m in allowed
		check(in_list and moves.back() == ("held_still" if mode == "continue" else "turned_round"), "%s: moves %s" % [mode, moves])

## Every observation the office has, reached by play and flags alone.
func test_all_observations() -> void:
	var s := t1x_full_run()
	s.dispatch("door")
	s.dispatch("continue")
	s.dispatch("end_continue")
	var g := s.game
	g.dispatch("go:R02")
	for n in range(2, 9):
		for p in GameSim.TIDE_DONE[n - 1]:
			g.set_flag(p)
		g.dispatch("go:R01")
		g.dispatch("go:R02")
		for a in ["map", "map", "window", "hooks"]:
			s.dispatch(a)
		for i in 2:
			s.dispatch("papers")
			s.dispatch("back")
		if n == 7:
			g.give("venn_correspondence")
			s.dispatch("turn")
			s.dispatch("item:venn_correspondence")
			s.dispatch("board")
			for m in R02Sim.BOARD_ANSWER:
				s.dispatch(m)
			s.dispatch("stamp_venn")
			s.dispatch("provenance")
			s.dispatch("back")
			s.dispatch("turn")
	for a in ["mug", "stove", "coat", "door", "puddle", "window"]:
		s.dispatch(a)
	s.apply_ending("continue")
	var missing := []
	for id in R02Sim.OBSERVATIONS:
		if not s.has_seen(id):
			missing.append(id)
	check(missing.is_empty(), "every office observation is reachable (missing %s)" % [missing])
	check(s.seen().size() == R02Sim.OBSERVATIONS.size(), "seen() == OBSERVATIONS")

func test_clock_and_needle() -> void:
	var s := new_sim()
	s.dispatch("begin")
	check(s.clock() == [6, 40, true] and s.needle() == 0, "s0 clock")
	s.dispatch("turn")
	var ev := s.dispatch("barometer")
	check(has_ev(ev, "sfx", "baro_tap") and "Twenty to seven" in says(ev), "the barometer at s0")
	var l := new_sim()
	l.debug_jump(3)
	check(l.clock() == [6, 52, true], "Tide I after P01")
	var want_clock := [[7, 34, true], [9, 10, true], [11, 25, true], [1, 50, true], [3, 15, true], [5, 40, true], [7, 13, false], [7, 13, false]]
	var want_needle := [0, -55, -80, -118, -150, -168, 180, 180]
	for t in range(2, 10):
		var o := office(game_at(t))
		var b := o.band()
		check(o.clock() == want_clock[b] and o.needle() == want_needle[b], "band %d clock %s needle %d" % [b, o.clock(), o.needle()])
	var e := office(game_at(9))
	e.game.state.ending = "sever"
	check(e.clock() == [7, 13, true] and e.needle() == 30, "sever: clock going, needle FAIR side")
	e.dispatch("turn")
	check(says(e.dispatch("barometer")) == "The clock is going again.", "the barometer after an ending")
	check(says(e.dispatch("outer_door")) == "Grey water. A launch with two stripes on its pennant.", "the outer door after sever")
	e.dispatch("turn")
	check(says(e.dispatch("coat")) == "An ordinary wet coat.", "the coat after sever")
	e.game.state.ending = "continue"
	check(e.clock() == [7, 13, true] and e.needle() == 180, "continue: needle down")
	var ce := e.dispatch("coat")
	check(says(ce) == "It has gone slack on the hook. An ordinary wet coat. Nobody is in it." and e.has_seen("coat_collapsed"), "the coat after continue")
	check(says(e.dispatch("window")) == "The dark surface, close to the glass. The desk is lit.", "the window after continue")

# ---------------------------------------------------------------------------
# View B in the scene
# ---------------------------------------------------------------------------
func test_view_b() -> void:
	var scene = new_scene("user://office_view_b.json")
	await process_frame
	scene.enter_jump("R02")
	await process_frame
	var v: RoomView = scene.room_view
	var hb: Array = v.c("HOTSPOTS_B", [])
	var turn_rect = v.c("TURN_RECT", null)
	if hb.is_empty() or not turn_rect is Rect2:
		# The R02 view is another team's file; it has not yet declared view B.
		print("SKIP: R02 view has no HOTSPOTS_B / TURN_RECT yet; view-B rect checks pending")
		await free_scene(scene)
		return
	var s: R02Sim = scene.room_sim()
	var rects := {"turn": turn_rect}
	for h in hb:
		rects[h[0]] = h[1]
	for id in R02Sim.HOTSPOTS_B:
		check(rects.has(id), "view B has a rect for %s" % id)
	var exits: Dictionary = v.exit_rects()
	for k in rects:
		var r: Rect2 = rects[k]
		check(CANVAS.encloses(r) and r.size.x >= MIN_TARGET and r.size.y >= MIN_TARGET, "%s is on the canvas and at least 64x64" % k)
		check(not r.intersects(HUD_ZONE) and not r.intersects(INVENTORY_ZONE) and not r.intersects(SUBTITLE_ZONE), "%s clear of the HUD" % k)
		for e in exits:
			check(not r.intersects(exits[e]), "%s clear of exit %s" % [k, e])
		for k2 in rects:
			if k2 != k:
				check(not r.intersects(rects[k2]), "%s clear of %s" % [k, k2])
	check(scene.action_at(turn_rect.get_center()) == "turn", "the turn rect facing A")
	s.facing = "B"
	check(scene.action_at(turn_rect.get_center()) == "turn", "the turn rect facing B")
	for id in R02Sim.HOTSPOTS_B:
		if rects.has(id):
			check(scene.action_at(rects[id].get_center()) == id, "facing B, the centre of %s is %s" % [id, id])
	await free_scene(scene)

# ---------------------------------------------------------------------------
# View: escalation by band, light floors, the mix, the arrival hold, the board
# ---------------------------------------------------------------------------
func test_view_escalation() -> void:
	var scene = new_scene("user://office_view_bands.json")
	await process_frame
	var plates := {2: "office_arrival", 3: "office_rain", 4: "office_rain", 5: "office_s2", 6: "office_s3",
		7: "office_s3", 8: "office_s3", 9: "office_ominous"}
	var entry := {2: "R02/entry_wall", 4: "R02/entry_wall", 5: "R02/entry_wall_damp", 8: "R02/entry_wall_damp",
		9: "R02/entry_wall_ominous"}
	var floors := {0: Color(0.46, 0.44, 0.50), 1: Color(0.58, 0.60, 0.68), 2: Color(0.56, 0.58, 0.66),
		3: Color(0.55, 0.56, 0.65), 4: Color(0.54, 0.56, 0.66), 5: Color(0.54, 0.55, 0.64),
		6: Color(0.54, 0.54, 0.62), 7: Color(0.56, 0.55, 0.62)}
	var rain := [0.0, 0.30, 0.40, 0.34, 0.30, 0.0, 0.0, 0.0]
	for t in range(2, 10):
		scene.tide_jump(t, "R02")
		await process_frame
		var v = scene.room_view
		var s: R02Sim = scene.room_sim()
		var b := s.band()
		check(b == t - 2, "tide %d is band %d" % [t, t - 2])
		check(v._base_plate() == plates[t], "tide %d desk plate %s (got %s)" % [t, plates[t], v._base_plate()])
		if entry.has(t):
			check(v._entry_plate() == entry[t], "tide %d entry plate %s" % [t, entry[t]])
		var m: Color = v.shade.color
		var f: Color = floors[b]
		check(m.r >= f.r - 0.001 and m.g >= f.g - 0.001 and m.b >= f.b - 0.001, "band %d light is at least its floor" % b)
		check(is_equal_approx(v.lamp_glow.texture_scale, 1.6), "band %d lamp pool 1.6" % b)
		check(v._tilted() == (b >= 3), "band %d horizon tilt" % b)
		v._tick_audio(1.0 / 60.0)
		var tg: Dictionary = v.last_targets
		check(is_equal_approx(tg.rain_glass, rain[b]), "band %d rain on glass %.2f" % [b, rain[b]])
		check(is_equal_approx(tg.late_wave, 0.28 if b == 3 else 0.0), "band %d late wave" % b)
		check(is_equal_approx(tg.pressure, 0.35 if b == 7 else 0.0), "band %d pressure" % b)
		check(is_equal_approx(tg.clock, 0.0 if b >= 6 else 0.16), "band %d clock facing A" % b)
		check(is_equal_approx(tg.drone, 0.30 if b >= 2 else 0.0), "band %d drone" % b)
		check(tg.wind == 0.0 or b < 5, "band %d wind gone from 5" % b)
		check(is_equal_approx(tg.hum, 0.18), "band %d hum" % b)
		s.facing = "B"
		v._tick_audio(1.0 / 60.0)
		check(is_equal_approx(v.last_targets.clock, 0.0 if b >= 6 else 0.26), "band %d clock facing B" % b)
		check(is_equal_approx(v.last_targets.kitchen_air, 0.08 if b >= 1 and b <= 6 else 0.0),
			"band %d kitchen air through the open service door" % b)
		check(v.hover_at(R02View_TURN) == "turn" and v.label_for("turn") == "Desk wall", "facing B the tab says Desk wall")
		s.facing = "A"
		check(v.label_for("turn") == "Entry wall", "facing A the tab says Entry wall")
	# Tide I: the arrival plate throughout, the slice's light, plus the clock.
	scene.room_jump("R02", 3)
	await process_frame
	var v3 = scene.room_view
	check(v3._base_plate() == "office_arrival" and not v3._tilted(), "T1X stays on the arrival plate, level")
	check(v3.shade.color.is_equal_approx(Color(0.40, 0.39, 0.48)), "T1X light")
	v3._tick_audio(1.0 / 60.0)
	# The drone breathes with the room at T1X (0.5 at the top of the breath).
	check(v3.last_targets.drone > 0.27 and v3.last_targets.drone <= 0.5 and is_equal_approx(v3.last_targets.clock, 0.16),
		"T1X drone 0.5 swelling, clock 0.16")
	# Endings.
	for e in [["sever", "office_rain", "R02/entry_wall_day", Color(0.95, 0.95, 0.93)],
			["continue", "office_ominous", "R02/entry_wall_ominous", Color(0.56, 0.55, 0.62)]]:
		scene.tide_jump(9, "R02")
		scene.sim.state.ending = e[0]
		scene._reset_presentation()
		await process_frame
		var ve = scene.room_view
		check(ve._base_plate() == e[1] and ve._entry_plate() == e[2], "%s ending plates" % e[0])
		check(ve.shade.color.is_equal_approx(e[3]), "%s ending light" % e[0])
		ve._tick_audio(1.0 / 60.0)
		var tg: Dictionary = ve.last_targets
		check(is_equal_approx(tg.clock, 0.2), "%s ending: the clock runs" % e[0])
		check(is_equal_approx(tg.gulls, 0.35 if e[0] == "sever" else 0.0), "%s ending gulls" % e[0])
		check(is_equal_approx(tg.sea, 0.5 if e[0] == "sever" else 0.0), "%s ending sea" % e[0])
		check(is_equal_approx(tg.pressure, 0.12 if e[0] == "continue" else 0.0), "%s ending pressure" % e[0])
	check("lock_turn" in scene.room_view.SFX_SOFT and "seal" in scene.room_view.SFX_SOFT, "lock_turn and seal are sudden")
	check(is_equal_approx(scene.sfx_db("stamp"), -6.0) and is_equal_approx(scene.sfx_db("turn"), -14.0), "board and turn levels")
	await free_scene(scene)

const R02View_TURN := Vector2(784, 954)

func test_view_notice_and_board() -> void:
	var scene = new_scene("user://office_view_notice.json")
	await process_frame
	# The arrival hold: entering from the jetty after band 2 arrives holds on the mug; a click ends it.
	scene.tide_jump(4, "R01")
	scene.sim.room("R02").state.notices_seen.erase("b2")
	scene.dispatch("go:R02")
	await process_frame
	var v = scene.room_view
	check(v._notice_active() and v.notice_rect == Rect2(915, 662, 82, 62), "band 2 arrival holds on the mug")
	var mug: Vector2 = Rect2(915, 662, 82, 64).get_center()
	check(scene.action_at(mug) == "" and not v._notice_active(), "a click ends the hold and does nothing else")
	check(scene.action_at(mug) == "mug", "the next click is a click")
	v.play_fx("notice", {"key": "b6"})
	for i in 100:
		v._tick_stage(1.0 / 60.0)
	check(not v._notice_active(), "the hold lets go by itself after 1.5 s")
	check(v.away_alpha.is_empty() or v.away_alpha.values().max() >= 1.0, "the look-away fade is done")
	# The board: the photograph waits for its pin.
	scene.room_jump("R02", 6)
	await process_frame
	scene.dispatch("board")
	v = scene.room_view
	var s: R02Sim = scene.room_sim()
	for a in ["m_addressee", "m_mercer", "m_sentence", "stamp_venn", "provenance"]:
		scene.dispatch(a)
	check(s.board_solved() and v.photo_armed, "P20 solved: the photograph is not on the board yet")
	check(scene.action_at(Vector2(1240, 160)) != "photo", "no photograph to click before the pin")
	v.on_sfx("pin")
	check(not v.photo_armed and scene.action_at(Vector2(1240, 160)) == "photo", "the pin lands: the photograph is there")
	scene.dispatch("photo")
	check(s.local_view == "photo", "the photograph opens c_photo")
	check(scene.action_at(Vector2(724, 838)) == "turn_over", "Turn it over")
	await free_scene(scene)
