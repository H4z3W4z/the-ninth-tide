extends SceneTree
## Headless tests for the Intake Office slice: logic (OfficeSim) and the
## scene's hit-testing/save/presentation wiring. Run after an import:
##   godot --headless --path . --script tests/office_sim_test.gd

var failures: Array = []

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		push_error(msg)

func says(ev: Array) -> String:
	var out := []
	for e in ev:
		if e.type == "say": out.append(e.text)
	return " | ".join(out)

func has_ev(ev: Array, type: String, id: String) -> bool:
	for e in ev:
		if e.type == type and e.get("id", "") == id: return true
	return false

func say_ev(ev: Array, fragment: String) -> Dictionary:
	for e in ev:
		if e.type == "say" and fragment in e.text: return e
	return {}

func dial_to(s: OfficeSim, code: Array) -> void:
	for i in 4:
		while int(s.state.drawer_dial[i]) != code[i]:
			s.dispatch("dial_%d" % i)

## Opens the closure report, enters the right answer by clicks, and files it.
func file_report(s: OfficeSim) -> Array:
	s.dispatch("papers")
	for i in OfficeSim.REPORT_FIELDS.size():
		while int(s.state.report_fields[i]) != OfficeSim.REPORT_ANSWER[i]:
			s.dispatch("field_%d" % i)
	return s.dispatch("file_report")

## Builds the state just before the wet seat, by real actions.
func sim_before_chair() -> OfficeSim:
	var s := OfficeSim.new()
	s.debug_jump(2)
	s.dispatch("puddle")
	s.dispatch("drawer")
	dial_to(s, [1, 8, 5, 2])
	s.dispatch("try_drawer")
	s.dispatch("back")
	s.dispatch("logbook")
	s.dispatch("back")
	return s

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
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
	await test_scene_wiring()
	await test_presentation_cleanup()
	await test_scheduler()
	await test_breath_and_knock()
	await test_threshold_scene()
	await test_end_scene()
	if failures.is_empty():
		print("PASS: office slice — playthrough, P01, drawer, tide rhythm, log rewrite, closure report, history, soundings, revisits, gates, drift, evidence, story flags, saves, title menu, determinism, threshold, end card, scene wiring, scheduler, breath, cleanup")
	else:
		print("FAIL (%d): %s" % [failures.size(), "; ".join(failures)])
	# Let freed scenes and players go before exit, so there are no leak warnings.
	for i in 10:
		await process_frame
	quit(0 if failures.is_empty() else 1)

func test_full_playthrough() -> void:
	var s := OfficeSim.new()
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
	check(s.view == "room" and s.objective() == "reread", "objective -> reread")
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
	check(s.state.report_filed and has_ev(ev, "sfx", "latch_near") and s.view == "room", "filing the report unlatches the door")
	check(s.objective() == "leave", "objective -> leave")
	ev = s.dispatch("door")
	check(s.view == "threshold" and not s.state.finished, "door -> threshold")
	check(has_ev(ev, "fx", "threshold") and has_ev(ev, "sfx", "door") and says(ev) == "", "threshold: door + fx, no line")
	s.dispatch("continue")
	check(s.view == "end" and s.state.finished, "continue ends the slice")
	s.dispatch("restart")
	check(s.view == "title" and not s.state.p01_complete, "restart from end card resets")

func test_p01_rules() -> void:
	var s := OfficeSim.new()
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
	var s := OfficeSim.new()
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
	var s := OfficeSim.new()
	s.dispatch("begin")
	var h1 := says(s.dispatch("hint"))
	var h2 := says(s.dispatch("hint"))
	var h3 := says(s.dispatch("hint"))
	var h4 := says(s.dispatch("hint"))
	check(h1 != h2 and h2 != h3 and h3 == h4, "hints escalate and cap at the solution")
	check("bridge B" in h3, "final lamp hint gives the solution")
	s.debug_jump(1)
	check(says(s.dispatch("hint")) == OfficeSim.HINTS["log"][0], "hints reset for the new objective")
	for obj in ["drawer", "reread", "chair", "leave"]:
		check(OfficeSim.HINTS.has(obj) and OfficeSim.HINTS[obj].size() == 3, "three hints for " + obj)
	check("1-8-5-2" in OfficeSim.HINTS["drawer"][2], "drawer hint 3 gives the code")

func test_save_roundtrip_and_tamper() -> void:
	var s := OfficeSim.new()
	s.debug_jump(2)
	s.dispatch("puddle")
	var d = JSON.parse_string(JSON.stringify(s.to_dict()))
	var t := OfficeSim.new()
	check(t.from_dict(d), "save loads")
	check(t.state.prints_seen and t.state.log_read and t.state.p01_complete, "progress survives")
	check(t.has_seen("prints"), "observations survive")
	check(t.view == "room", "load lands in the room")
	var bad := OfficeSim.new()
	check(not bad.from_dict({"schema": 1}), "schema 1 rejected")
	check(not bad.from_dict({"schema": 2, "started": true}), "schema 2 rejected")
	check(not bad.from_dict({"schema": 3, "started": true}), "schema 3 rejected")
	check(not bad.from_dict("junk"), "junk rejected")
	var tampered := OfficeSim.new()
	tampered.from_dict({"schema": 4, "started": true, "seat_wet": true, "seen": ["nope", 3]})
	check(not tampered.state.seat_wet, "orphan progress flags are dropped")
	check(tampered.state.seen.is_empty(), "unknown observations are dropped")
	var dials := OfficeSim.new()
	dials.from_dict({"schema": 4, "drawer_dial": [12, -3, 5, 2]})
	check(dials.state.drawer_dial == [9, 0, 5, 2], "dials clamp to 0-9")
	dials.from_dict({"schema": 4, "drawer_dial": [1, 2, 3]})
	check(dials.state.drawer_dial == [0, 0, 0, 0], "a short dial array is ignored")
	dials.from_dict({"schema": 4, "drawer_dial": ["1", 8, 5, 2]})
	check(dials.state.drawer_dial == [0, 0, 0, 0], "non-numeric dials are ignored")

func test_determinism() -> void:
	var script := ["begin", "lamp", "fit", "toggle_supply", "select_c", "fit", "select_b", "fit",
		"toggle_supply", "logbook", "back", "puddle", "drawer", "try_drawer"]
	for i in 1: script.append("dial_0")
	for i in 8: script.append("dial_1")
	for i in 5: script.append("dial_2")
	for i in 2: script.append("dial_3")
	script.append_array(["try_drawer", "look_photo", "look_photo", "back", "map", "logbook", "back", "chair",
		"coat", "window", "door", "papers", "file_report", "field_0", "field_0", "field_1", "field_2",
		"field_3", "file_report", "logbook", "back", "hint", "door", "hint", "continue"])
	var a := OfficeSim.new()
	var b := OfficeSim.new()
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
	var s := OfficeSim.new()
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
	var w := OfficeSim.new()
	w.debug_jump(1)
	w.dispatch("drawer")
	for i in 9: w.dispatch("dial_2")
	check(int(w.state.drawer_dial[2]) == 9, "dial counts up")
	ev = w.dispatch("dial_2")
	check(int(w.state.drawer_dial[2]) == 0 and has_ev(ev, "sfx", "dial") and says(ev) == "", "dial wraps 9 -> 0 silently with a click")
	# Right code before the log is read.
	var early := OfficeSim.new()
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
	check(says(s.dispatch("look_photo")) == "Me, from outside. From the sea side.", "look at the photo")
	s.dispatch("back")
	ev = s.dispatch("drawer")
	check("back of my own head" in says(ev), "open drawer revisit line")
	var closed := OfficeSim.new()
	closed.debug_jump(2)
	closed.dispatch("drawer")
	check(closed.dispatch("look_watch").is_empty(), "nothing to look at in a locked drawer")

# ---------------------------------------------------------------------------
# Log rows
# ---------------------------------------------------------------------------
func test_log_rows() -> void:
	var s := OfficeSim.new()
	s.debug_jump(2)
	check(s.log_rows().size() == 9, "9 log rows before the rewrite")
	s.dispatch("puddle")
	s.dispatch("logbook")
	check(not s.state.log_rewritten and s.log_rows().size() == 9, "no rewrite without the drawer")
	s.dispatch("back")
	var nodrawer := OfficeSim.new()
	nodrawer.debug_jump(2)
	nodrawer.dispatch("drawer")
	dial_to(nodrawer, [1, 8, 5, 2])
	nodrawer.dispatch("try_drawer")
	nodrawer.dispatch("back")
	nodrawer.dispatch("logbook")
	check(nodrawer.state.drawer_open and not nodrawer.state.log_rewritten, "no rewrite without the prints")
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
	file_report(s)
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
	for r in OfficeSim.LOG_LATER:
		check(r[4] == true, "later rows are in her hand")

# ---------------------------------------------------------------------------
# Gates
# ---------------------------------------------------------------------------
func test_new_gates() -> void:
	var s := OfficeSim.new()
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
	var t := OfficeSim.new()
	for a in ["door", "continue", "chair", "drawer"]:
		t.dispatch(a)
	check(t.view == "title" and not t.state.finished, "threshold unreachable from the title")
	var th := OfficeSim.new()
	th.debug_jump(4)
	th.dispatch("door")
	check(th.view == "threshold", "door with the report filed -> threshold")
	th.dispatch("back")
	check(th.view == "threshold", "no going back from the threshold")
	th.dispatch("chair")
	check(th.view == "threshold", "room hotspots do nothing at the threshold")
	th.dispatch("notebook")
	check(th.view == "notebook" and th.return_view == "threshold", "notebook works at the threshold")
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
		var s := OfficeSim.new()
		s.debug_jump(st)
		window.append(says(s.dispatch("window")))
		maps.append(says(s.dispatch("map")))
	check(window[0] != window[1] and window[1] != window[2] and window[0] != window[2], "window line drifts across stages 1-3")
	check(maps[0] != maps[1], "map line drifts between stages 1 and 2")
	var s3 := OfficeSim.new()
	s3.debug_jump(3)
	s3.dispatch("hooks")
	check(s3.has_seen("tag") and s3.has_seen("hooks"), "hooks at stage 3 records the tag")
	var w3 := s3.dispatch("window")
	check(s3.has_seen("horizon") and s3.has_seen("eye"), "window at stage 3 records horizon + eye")
	check("eye keeps" in says(w3), "the eye line")
	var p := OfficeSim.new()
	p.debug_jump(1)
	var ev := p.dispatch("papers")
	check(p.has_seen("note") and "Lamp service completed. A.M." in says(ev), "papers after the lamp: the A.M. line")
	p.dispatch("back")
	ev = p.dispatch("papers")
	check(not "A.M." in says(ev) and says(ev) == "In the lamplight there's pencil beneath the duty card.", "A.M. line plays once")
	var d := OfficeSim.new()
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
func test_notebook_keeps_evidence() -> void:
	# One scripted run that sees everything there is to see.
	var s := OfficeSim.new()
	s.dispatch("begin")
	for a in ["coat", "hooks", "map", "mug", "stove", "papers", "back"]:
		s.dispatch(a)
	for a in ["lamp", "toggle_supply", "select_b", "fit", "toggle_supply"]:
		s.dispatch(a)
	for a in ["papers", "back", "chair", "logbook", "back", "window", "map", "puddle", "drawer"]:
		s.dispatch(a)
	dial_to(s, [1, 8, 5, 2])
	for a in ["try_drawer", "look_photo", "look_photo", "back", "map", "logbook", "back", "chair",
			"window", "hooks"]:
		s.dispatch(a)
	file_report(s)
	var missing := []
	for id in OfficeSim.OBSERVATIONS:
		if not s.has_seen(id):
			missing.append(id)
	check(missing.is_empty(), "every observation reachable in one run (missing: %s)" % [missing])
	check(s.state.seen.size() == OfficeSim.OBSERVATIONS.size(), "seen.size() == OBSERVATIONS.size()")
	var j := OfficeSim.new()
	j.debug_jump(4)
	var had: Array = j.state.seen.duplicate()
	for id in OfficeSim.ROOM_IDS:
		j.dispatch(id)
		j.dispatch("back")
	for id in had:
		check(j.has_seen(id), "evidence kept after the sweep: " + id)

# ---------------------------------------------------------------------------
# Story flags
# ---------------------------------------------------------------------------
func test_story_flags() -> void:
	var s := OfficeSim.new()
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
	var d := OfficeSim.new()
	d.debug_jump(2)
	d.dispatch("drawer")
	dial_to(d, [1, 8, 5, 2])
	ev = d.dispatch("try_drawer")
	var all_story := true
	for e in ev:
		if e.type == "say" and not e.story:
			all_story = false
	check(all_story and says(ev).split(" | ").size() == 7, "all seven drawer lines are story")
	var b := OfficeSim.new()
	ev = b.dispatch("begin")
	check(ev[1].delay == 3.2, "opening second line at 3.2 s")

# ---------------------------------------------------------------------------
# Saves at each new milestone
# ---------------------------------------------------------------------------
func roundtrip(s: OfficeSim) -> OfficeSim:
	var t := OfficeSim.new()
	check(t.from_dict(JSON.parse_string(JSON.stringify(s.to_dict()))), "milestone save loads")
	return t

func test_milestone_saves() -> void:
	var s := OfficeSim.new()
	s.debug_jump(2)
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
	file_report(s)
	t = roundtrip(s)
	check(t.state.report_filed and t.objective() == "leave" and t.has_seen("report"), "report_filed round-trips")
	s.dispatch("logbook")
	t = roundtrip(s)
	check(t.state.foretold_door, "foretold_door round-trips")
	s.dispatch("back"); s.dispatch("door")
	check(s.view == "threshold", "at the threshold")
	t = roundtrip(s)
	check(t.view == "room" and t.state.seat_wet and not t.state.finished, "a threshold save lands in the room")
	var bad := OfficeSim.new()
	bad.from_dict({"schema": 4, "started": true, "p01_complete": true, "log_read": true,
		"prints_seen": true, "log_rewritten": true})
	check(not bad.state.log_rewritten, "log_rewritten without drawer_open is dropped")
	bad.from_dict({"schema": 4, "started": true, "drawer_open": true})
	check(not bad.state.drawer_open, "drawer_open without log_read is dropped")
	bad.from_dict({"schema": 4, "started": true, "p01_complete": true, "log_read": true, "prints_seen": true,
		"drawer_open": true, "seat_wet": true, "foretold_door": true})
	check(not bad.state.seat_wet and not bad.state.foretold_door, "seat_wet needs log_rewritten; foretold needs seat_wet")
	bad.from_dict({"schema": 4, "initialled": true})
	check(not bad.state.initialled, "initialled needs the lamp")

# ---------------------------------------------------------------------------
# Title menu
# ---------------------------------------------------------------------------
func test_title_menu() -> void:
	var s := OfficeSim.new()
	s.dispatch("menu")
	check(s.view == "menu" and s.return_view == "title", "menu from the title")
	s.dispatch("toggle_motion")
	check(not s.state.motion, "settings work before the opening")
	s.dispatch("notebook")
	s.dispatch("hint")
	check(s.view == "menu" and not s.state.started, "story actions do nothing in the title menu")
	s.dispatch("resume")
	check(s.view == "title" and not s.state.started, "resume returns to the title")
	s.dispatch("menu")
	s.dispatch("back")
	check(s.view == "title", "back from the title menu returns to the title")
	s.dispatch("begin")
	check(s.view == "room" and not s.state.motion, "the setting survives into the game")

# ---------------------------------------------------------------------------
# Scene wiring
# ---------------------------------------------------------------------------
func new_scene(path: String) -> Node:
	var scene = load("res://game/intake_office.tscn").instantiate()
	scene.save_path = path
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
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
	again.sim.reset()
	again._load_progress()
	check(again.sim.state.p01_complete and again.sim.view == "room", "scene reload restores P01")
	# Corrupt save: no engine error, falls back to the title.
	var f := FileAccess.open("user://office_corrupt_test.json", FileAccess.WRITE)
	f.store_string("{not json")
	f = null
	var corrupt = load("res://game/intake_office.tscn").instantiate()
	corrupt.save_path = "user://office_corrupt_test.json"
	root.add_child(corrupt)
	await process_frame
	check(corrupt.sim.view == "title", "corrupt save falls back to the title")
	# The report gate in the scene: rows and the sign button.
	scene.debug_jump(3)
	scene.dispatch("door")
	check(scene.sim.view == "room", "scene: the door is latched until the report is filed")
	scene.dispatch("papers")
	check(scene.sim.view == "report", "scene: papers open the closure report")
	check(scene.action_at(Vector2(700, 350)) == "field_0" and scene.action_at(Vector2(1100, 740)) == "field_3",
		"report rows are clickable across their width")
	check(scene.action_at(Vector2(724, 888)) == "file_report", "sign and file")
	check(scene.action_at(Vector2(1000, 45)) == "back", "Back in the report")
	# Threshold gate and the end-card grace.
	scene.debug_jump(4)
	scene.dispatch("door")
	check(scene.sim.view == "threshold", "scene reaches the threshold")
	check(scene.action_at(Vector2(700, 500)) == "", "no continue before she holds still")
	check(scene.action_at(Vector2(1180, 45)) == "notebook", "HUD still works at the threshold")
	scene.continue_ready = true
	check(scene.action_at(Vector2(700, 500)) == "continue", "continue once ready")
	scene.dispatch("continue")
	check(scene.action_at(Vector2(700, 910)) == "", "Play again ignores the continue click")
	scene.end_t = 60.0
	check(scene.action_at(Vector2(700, 910)) == "restart", "Play again once the card has finished")
	check(scene.action_at(Vector2(700, 790)) == "", "the old button spot is never restart")
	# Drawer open: watch and photo.
	scene.debug_jump(3)
	scene.dispatch("drawer")
	check(scene.action_at(Vector2(560, 600)) == "look_watch", "watch in the open drawer")
	check(scene.action_at(Vector2(920, 620)) == "look_photo", "photo in the open drawer")
	for p in [scene.save_path, again.save_path, corrupt.save_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	scene.queue_free()
	again.queue_free()
	corrupt.queue_free()
	await process_frame

## The subtitle scheduler and restart cleanup.
func test_presentation_cleanup() -> void:
	var scene = new_scene("user://office_present_test.json")
	await process_frame
	scene.debug_jump(2)
	var s: OfficeSim = scene.sim
	s.state.prints_seen = true; s.state.drawer_open = true; s.state.log_rewritten = true
	scene.dispatch("chair")
	check(scene.sim.state.seat_wet, "scene: chair wets the seat")
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
	# A click inside the story line's read time queues behind it instead of cutting it off.
	scene.dispatch("mug")
	check(scene.subtitle.text == "The seat is wet. Still warm underneath.", "story line is not cut off early")
	check(scene.lines.size() == 3 and scene.lines[0].text.begins_with("Two rings"), "the click's line goes to the front")
	# Older chatter is dropped by the next click; story lines and the click's own line survive.
	scene.time += 10.0
	scene._tick_lines(0.0)
	scene.dispatch("stove")
	var kept_ok := true
	for l in scene.lines:
		kept_ok = kept_ok and (l.story or l.click == scene.click_id)
	check(kept_ok, "only story lines and this click's line stay queued after a click")
	# Two reveals back to back never interleave: the second waits for the first.
	scene.debug_jump(2)
	scene.sim.state.prints_seen = true
	scene.dispatch("drawer")
	for i in 4:
		for n in [1, 8, 5, 2][i]:
			scene.dispatch("dial_%d" % i)
	scene.dispatch("try_drawer")
	var drawer_count: int = scene.lines.size()
	var drawer_texts := []
	for l in scene.lines:
		drawer_texts.append(l.text)
	scene.dispatch("back")
	scene.dispatch("logbook")
	check(scene.sim.state.log_rewritten, "scene: the log rewrites")
	# The rewrite starts within BEAT_MAX_WAIT; the drawer lines that didn't fit follow it.
	var order := []
	var squeezed := true
	var dues_sorted := true
	var prev_due := -1.0
	for l in scene.lines:
		order.append("D" if l.text in drawer_texts else "L")
		if l.text in drawer_texts:
			squeezed = squeezed and absf(l.hold - scene.min_read(l.text) * 0.6) < 0.001
		dues_sorted = dues_sorted and l.due >= prev_due
		prev_due = l.due
	var runs := "".join(order)
	var first_log := runs.find("L")
	check(scene.lines.size() == drawer_count + 4, "every drawer line is kept and the rewrite adds four")
	check(runs.count("LLLL") == 1 and dues_sorted, "the rewrite's four lines stay together, in order (%s)" % runs)
	check(first_log >= 0 and scene.lines[first_log].due - scene.time <= scene.BEAT_MAX_WAIT + 0.001,
		"the new reveal starts within 3 s of its click")
	var kept_order := true
	var di := 0
	for l in scene.lines:
		if l.text in drawer_texts:
			kept_order = kept_order and l.text == drawer_texts[di]
			di += 1
	check(kept_order, "the drawer lines keep their order around it")
	check(squeezed, "the older reveal is squeezed back to back")
	scene.dispatch("restart")
	check(scene.sim.view == "title", "restart returns to title")
	check(scene.pending_sfx.is_empty() and scene.lines.is_empty() and scene.subtitle.text == "", "restart clears lines and sounds")
	check(scene.oneshots.is_empty() and scene.lamp_glow.energy == 0.0, "restart stops one-shots and the lamp")
	check(scene.shadow_creep == 0 and scene.log_shown_hand == 0, "restart resets view state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.save_path))
	scene.queue_free()
	await process_frame

# ---------------------------------------------------------------------------
# C1: closure report gate
# ---------------------------------------------------------------------------
func set_fields(s: OfficeSim, want: Array) -> void:
	for i in want.size():
		while int(s.state.report_fields[i]) != want[i]:
			s.dispatch("field_%d" % i)

func test_report_gate() -> void:
	var s := OfficeSim.new()
	s.debug_jump(3)
	var ev := s.dispatch("door")
	check(s.view == "room" and "Latched" in says(ev), "report gate: the door is latched at stage 3")
	ev = s.dispatch("papers")
	check(s.view == "report" and "closure report" in says(ev) and has_ev(ev, "sfx", "page"), "papers open the closure report")
	ev = s.dispatch("field_0")
	check(int(s.state.report_fields[0]) == 1 and has_ev(ev, "sfx", "nib"), "a field turns with a nib tick")
	# Every combination but one is rejected, and none says which line is wrong.
	var accepted := []
	var all_quiet := true
	for a in 3:
		for b in 3:
			for c in 2:
				for d in 2:
					var t := OfficeSim.new()
					t.debug_jump(3)
					t.dispatch("papers")
					set_fields(t, [a, b, c, d])
					var fe := t.dispatch("file_report")
					if t.state.report_filed:
						accepted.append([a, b, c, d])
					elif says(fe) != "Something here doesn't reconcile." or t.view != "report":
						all_quiet = false
	check(accepted == [OfficeSim.REPORT_ANSWER], "only the right report files (accepted %s)" % [accepted])
	check(all_quiet, "a wrong report says only that it doesn't reconcile, and stays open")
	# Wrong, then right.
	set_fields(s, [0, 0, 0, 0])
	ev = s.dispatch("file_report")
	check(not s.state.report_filed and "doesn't reconcile" in says(ev), "a wrong file leaves the report unfiled")
	set_fields(s, [2, 1, 0, 0])
	var mid := OfficeSim.new()
	check(mid.from_dict(JSON.parse_string(JSON.stringify(s.to_dict()))) and mid.state.report_fields == [2, 1, 0, 0]
		and not mid.state.report_filed, "report fields round-trip mid-entry")
	set_fields(s, OfficeSim.REPORT_ANSWER)
	ev = s.dispatch("file_report")
	check(s.state.report_filed and s.has_seen("report") and has_ev(ev, "sfx", "latch_near") and has_ev(ev, "sfx", "sign"),
		"the right report files, signs and unlatches")
	check(s.view == "room", "filing returns to the room")
	check(say_ev(ev, "without counting").get("story", false) and say_ev(ev, "unlatched itself").get("story", false),
		"filing lines are story")
	ev = s.dispatch("file_report")
	check(ev.is_empty(), "file_report outside the report does nothing")
	s.dispatch("papers")
	ev = s.dispatch("field_0")
	check(ev.is_empty() and s.state.report_fields == OfficeSim.REPORT_ANSWER, "a filed report can't be changed")
	s.dispatch("back")
	s.dispatch("door")
	check(s.view == "threshold", "after filing, the door -> threshold")
	var t := OfficeSim.new()
	check(t.from_dict(JSON.parse_string(JSON.stringify(s.to_dict()))) and t.state.report_filed, "report_filed round-trips")
	var bad := OfficeSim.new()
	bad.from_dict({"schema": 4, "started": true, "p01_complete": true, "log_read": true, "prints_seen": true,
		"drawer_open": true, "log_rewritten": true, "seat_wet": true, "report_filed": true,
		"report_fields": [0, 1, 1, 1], "foretold_door": true, "finished": true})
	check(bad.state.seat_wet and not bad.state.report_filed and not bad.state.foretold_door and not bad.state.finished,
		"a tampered save with the wrong fields loads unfiled")
	bad.from_dict({"schema": 4, "report_fields": [7, -2, 1.5, "x"]})
	check(bad.state.report_fields == [0, 0, 0, 0], "malformed report fields are ignored")
	bad.from_dict({"schema": 4, "report_fields": [9, 9, 9, 9]})
	check(bad.state.report_fields == [2, 2, 1, 1], "report fields clamp to their option counts")
	var j3 := OfficeSim.new()
	j3.debug_jump(3)
	var j4 := OfficeSim.new()
	j4.debug_jump(4)
	check(not j3.state.report_filed and j4.state.report_filed and j4.has_seen("report") and j4.objective() == "leave",
		"debug_jump(3) is unfiled; debug_jump(4) is filed")
	var h := OfficeSim.new()
	h.debug_jump(3)
	var h1 := says(h.dispatch("hint"))
	check(h1 == OfficeSim.HINTS["report"][0], "the report has its own hints")
	check("Pilings 10" in OfficeSim.HINTS["report"][2], "report hint 3 gives the answer")

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
func history_run() -> OfficeSim:
	var s := OfficeSim.new()
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
	check(tail == [OfficeSim.HISTORY_TEXT["coat"], OfficeSim.HISTORY_TEXT["window"], OfficeSim.HISTORY_TEXT["mug"]],
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
	file_report(s)
	rows = s.log_rows()
	check(rows[rows.size() - 2] == OfficeSim.HISTORY_CLOSE and rows.back() == OfficeSim.LOG_FINAL,
		"after filing: HISTORY_CLOSE then LOG_FINAL")
	s.dispatch("coat")
	check(s.state.history.size() == 3 and s.log_rows().size() == rows.size(), "nothing is recorded after filing")
	var lamp := OfficeSim.new()
	lamp.debug_jump(3)
	for a in ["lamp", "back", "tray", "back", "chair"]:
		lamp.dispatch(a)
	check(lamp.state.history == ["lamp", "chair"], "lamp and tray share one line")
	var fresh := sim_before_chair()
	fresh.dispatch("chair")
	check(fresh.state.history.is_empty(), "the click that wets the seat is not recorded")
	var t := OfficeSim.new()
	t.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(t.state.history == s.state.history and t.state.history_seen, "history round-trips")
	t.from_dict({"schema": 4, "history": ["coat"], "history_seen": true})
	check(t.state.history.is_empty() and not t.state.history_seen, "history needs the wet seat")
	t.from_dict({"schema": 4, "started": true, "p01_complete": true, "log_read": true, "prints_seen": true,
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
	var s := OfficeSim.new()
	s.debug_jump(1)
	check(s.log_rows()[OfficeSim.BLOTTED_ROW][1] == "", "the hour she mends the lamp is blotted")
	check(OfficeSim.LOG_ENTRIES[OfficeSim.BLOTTED_ROW][1] == "18:52", "...and it is 18:52 under the stain")
	# Every high water is 12 h 21 m after the last; low water 6 h 19 m after high.
	var hw := []
	var period_ok := true
	for i in OfficeSim.LOG_ENTRIES.size():
		var e: Array = OfficeSim.LOG_ENTRIES[i]
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
	check((minutes("18:52") + 12 * 60 + 21) % 1440 == minutes(OfficeSim.LOG_ENTRIES[8][1]), "18:52 + 12:21 == 07:13 next day")
	check(OfficeSim.LOG_LATER[0][1] == "07:13", "the later row agrees: 07:13")
	var ev := s.dispatch("logbook")
	check(is_equal_approx(say_ev(ev, "tide-stain").get("delay", -1.0), 3.0), "the first read points at the stain")
	s.dispatch("back")
	s.dispatch("drawer")
	dial_to(s, [1, 8, 5, 2])
	s.dispatch("try_drawer")
	check(s.state.drawer_open and s.log_rows()[OfficeSim.BLOTTED_ROW][1] == "18:52", "after the drawer the hour reads 18:52")
	check(OfficeSim.HINTS["drawer"][1].contains("margin") and "1-8-5-2" in OfficeSim.HINTS["drawer"][2],
		"drawer hints: the margin, then the code")
	# Dials turn both ways.
	var w := OfficeSim.new()
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
	var early := OfficeSim.new()
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
		var s := OfficeSim.new()
		s.debug_jump(2)
		s.dispatch("drawer")
		dial_to(s, cs[0])
		var ev := s.dispatch("try_drawer")
		check(says(ev) == cs[1] and not s.state.drawer_open and has_ev(ev, "sfx", "clunk"),
			"near miss %s: %s" % [cs[0], says(ev)])

func test_photo_behind() -> void:
	var s := OfficeSim.new()
	s.debug_jump(2)
	s.dispatch("drawer")
	dial_to(s, [1, 8, 5, 2])
	s.dispatch("try_drawer")
	var ev := s.dispatch("look_photo")
	check(says(ev) == "Me, from outside. From the sea side." and not s.has_seen("behind"), "first look at the photo")
	ev = s.dispatch("look_photo")
	check(s.has_seen("behind") and "someone behind me" in says(ev), "second look: someone behind her")
	var n: int = s.state.seen.size()
	s.dispatch("look_photo")
	check(s.state.seen.size() == n and s.state.seen.count("behind") == 1, "'behind' is recorded once")
	for i in 12:
		s.dispatch("look_photo")
	check(int(s.state.photo_looks) == 9, "photo looks are capped")
	var t := OfficeSim.new()
	t.from_dict({"schema": 4, "photo_looks": 40})
	check(int(t.state.photo_looks) == 9, "photo_looks clamps on load")

# ---------------------------------------------------------------------------
# C3: soundings, and every revisit made worse
# ---------------------------------------------------------------------------
func test_soundings() -> void:
	var s := OfficeSim.new()
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
	ev = s.dispatch("map")
	check(says(ev) == "The chart has been corrected. In pencil. Nine.", "the soundings beat fires once")
	var t := OfficeSim.new()
	t.debug_jump(3)
	ev = t.dispatch("map")
	lines = says(ev).split(" | ")
	check(lines.size() == 4 and "tenth piling" in lines[3] and is_equal_approx(say_ev(ev, "tenth").delay, 9.0),
		"at s3 the 4th soundings line is the tenth piling")
	var one := OfficeSim.new()
	one.debug_jump(1)
	one.dispatch("map")
	check(not one.state.soundings_heard, "no soundings at stage 1")
	var bad := OfficeSim.new()
	bad.from_dict({"schema": 4, "started": true, "p01_complete": true, "log_read": true, "soundings_heard": true})
	check(not bad.state.soundings_heard, "soundings_heard needs the drawer open")

func test_revisits() -> void:
	var s1 := OfficeSim.new()
	s1.debug_jump(1)
	check(says(s1.dispatch("door")) == "Two latches let go somewhere below. I'd rather know what's in this room first.", "door at s1")
	var s2 := OfficeSim.new()
	s2.debug_jump(2)
	check(says(s2.dispatch("door")) == "The latches downstairs let go when the lamp came on. Something wanted the doors open before I did.", "door at s2")
	check(says(s2.dispatch("coat")) == "Still dripping. Onto the same spot, every time. Like it's being counted.", "coat at s2")
	check(says(s2.dispatch("hooks")) == "Nine hooks. The ninth is wet again. I dried it with my sleeve an hour ago.", "hooks at s2")
	var s3 := OfficeSim.new()
	s3.debug_jump(3)
	var ev := s3.dispatch("puddle")
	check(says(ev) == "There are two trails now. | One goes to the drawer. One comes from the drawer to the door. The second one is my size.",
		"puddle at s3: two trails")
	check(is_equal_approx(say_ev(ev, "my size").delay, 2.0) and say_ev(ev, "my size").story, "the second trail line is story at 2.0 s")
	# The window only shows the palms after the knock.
	var w := OfficeSim.new()
	w.debug_jump(3)
	ev = w.dispatch("window")
	check(not w.has_seen("palms") and say_ev(ev, "heel of a hand").is_empty(), "no palms at s3 without the knock")
	var k := sim_before_chair()
	k.dispatch("chair")
	ev = k.dispatch("window")
	check(k.has_seen("palms") and is_equal_approx(say_ev(ev, "heel of a hand").delay, 8.4), "palms after the knock, at 8.4 s")
	check(k.has_seen("eye") and "eye keeps" in says(ev), "the eye line is kept")
	# The log-rewrite beat.
	var r := OfficeSim.new()
	r.debug_jump(2)
	r.dispatch("puddle")
	r.dispatch("drawer")
	dial_to(r, [1, 8, 5, 2])
	r.dispatch("try_drawer")
	r.dispatch("back")
	ev = r.dispatch("logbook")
	check(not "I am going to have to look at it" in says(ev) and "Something is rising under it" in says(ev)
		and "forty years" in says(ev), "the rewrite beat: rising, not 'have to look'")
	check(is_equal_approx(say_ev(ev, "rising under it").delay, 7.4), "'Something is rising' at 7.4 s")

# ---------------------------------------------------------------------------
# C4 (sim): '...Listen.' plays once
# ---------------------------------------------------------------------------
func test_listen_once() -> void:
	var s := OfficeSim.new()
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
	var t := OfficeSim.new()
	t.from_dict({"schema": 4, "heard_silence": true})
	check(not t.state.heard_silence, "heard_silence needs the log read")

# ---------------------------------------------------------------------------
# C6 (sim): the threshold
# ---------------------------------------------------------------------------
func test_threshold_sim() -> void:
	check(OfficeSim.THRESHOLD_LINES == [
		[0.8, "The corridor is dark. It goes on further than the station does."],
		[3.4, "Something down there breathes in. Outside, the tide draws back off the pilings."],
		[7.6, "It breathes out, and the sea comes in."]], "threshold lines are exact")
	check(OfficeSim.THRESHOLD_STILL_LINE == "I hold my breath. So does the sea.", "the still line exists")
	var s := OfficeSim.new()
	s.debug_jump(4)
	s.dispatch("door")
	var others: Array = OfficeSim.ROOM_IDS.duplicate()
	others.append_array(["back", "resume", "toggle_motion", "toggle_soft", "dial_0", "dial_down_0",
		"try_drawer", "field_0", "file_report", "look_photo", "look_watch", "toggle_supply", "select_b", "fit"])
	var stayed := true
	for a in others:
		s.dispatch(a)
		stayed = stayed and s.view == "threshold" and not s.state.finished
	check(stayed, "at the threshold only continue/notebook/menu/hint do anything")
	var level: int = s.state.hint_level
	var ev := s.dispatch("hint")
	check(says(ev) == OfficeSim.THRESHOLD_HINT and s.state.hint_level == level and s.view == "threshold",
		"hint at the threshold: hold still, ladder untouched")
	s.dispatch("continue")
	check(s.view == "end" and s.state.finished, "continue is the only way to the end")

# ---------------------------------------------------------------------------
# C7 (sim): the end lines and the notebook intrusion
# ---------------------------------------------------------------------------
func test_end_lines() -> void:
	var s := OfficeSim.new()
	s.debug_jump(4)
	check(s.end_lines() == [OfficeSim.END_LINE, OfficeSim.END_CONTINUES], "end lines without everything seen")
	for id in OfficeSim.OBSERVATIONS:
		s._observe(id)
	check(s.end_lines() == [OfficeSim.END_LINE, OfficeSim.END_ALL_SEEN, OfficeSim.END_CONTINUES],
		"with everything seen: observers remaining, in the middle")
	var n := OfficeSim.new()
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
	# (a) A fast clicker opens the drawer: the reveal starts within 4 s, not after the backlog.
	scene.debug_jump(2)
	scene.sim.state.prints_seen = false
	scene.dispatch("puddle")
	advance(scene, 0.2)
	scene.dispatch("drawer")
	advance(scene, 0.2)
	for i in 4:
		for n in [1, 8, 5, 2][i]:
			scene.dispatch("dial_%d" % i)
	advance(scene, 0.2)
	scene.dispatch("try_drawer")
	var shown: float = time_to_show(scene, "It gives.", 4.0)
	check(shown >= 0.0, "'It gives.' within 4 s of the click (%.2f)" % shown)
	# (b) Feedback is never starved: a wrong try's clunk line shows within 1.5 s.
	scene.debug_jump(2)
	scene.sim.state.prints_seen = false
	scene.dispatch("puddle")
	advance(scene, 0.1)
	scene.dispatch("drawer")
	advance(scene, 0.1)
	scene.dispatch("try_drawer")
	shown = time_to_show(scene, "The drawer doesn't give.", 1.5)
	check(shown >= 0.0, "the clunk line within 1.5 s (%.2f)" % shown)
	# A click's line stays up at least 1.2 s before the next click replaces it.
	scene.debug_jump(1)
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.save_path))
	scene.queue_free()
	await process_frame

# ---------------------------------------------------------------------------
# C5 (view): breathing room, the knock lands
# ---------------------------------------------------------------------------
func test_breath_and_knock() -> void:
	var scene = new_scene("user://office_breath_test.json")
	await process_frame
	# At 4.0 the exhale starts at build_audio's 1.1 peak; everything that uses it clamps to 0..1.
	check(is_equal_approx(scene._breath_env(0.0), 0.0) and is_equal_approx(clampf(scene._breath_env(4.0), 0.0, 1.0), 1.0)
		and is_equal_approx(scene._breath_env(3.9999), 1.0) and is_equal_approx(scene._breath_env(4.0), scene.BREATH_OUT_PEAK)
		and absf(scene._breath_env(8.8)) < 1e-6 and is_equal_approx(scene._breath_env(10.0), 0.0), "breath envelope")
	scene.debug_jump(2)
	var s: OfficeSim = scene.sim
	s.state.prints_seen = true; s.state.drawer_open = true; s.state.log_rewritten = true
	scene.dispatch("chair")
	var played := false
	var hush_ok := false
	var silent_ok := false
	var dt := 1.0 / 60.0
	for i in 600:
		scene.time += dt
		scene._tick_stage(dt)
		scene._tick_sfx(dt)
		scene._tick_audio(dt)
		if not scene._knock_pending():
			played = true
			hush_ok = scene.hush > 0.0
			silent_ok = true
			for k in scene.last_targets:
				if k != "ring" and scene.last_targets[k] != 0.0:
					silent_ok = false
			break
	check(played and hush_ok, "the room is hushed when the knock plays")
	check(silent_ok and is_equal_approx(scene.last_targets.get("ring", 0.0), 0.10), "every mix target but the ring is 0 at the knock")
	check(scene.palms_armed, "the knock leaves marks on the glass")
	check(scene.last_targets.get("heartbeat", 1.0) == 0.0, "no heartbeat: the breath took its place")
	s.state.soft_audio = true
	check(is_equal_approx(scene.sfx_db("knock_glass"), -11.0), "softened knock is -11 dB")
	check(is_equal_approx(scene.sfx_db("door"), -18.0), "other sudden sounds keep the -12 cut")
	s.state.soft_audio = false
	check(is_equal_approx(scene.sfx_db("sign"), -8.0) and is_equal_approx(scene.sfx_db("nib"), -14.0), "sign and nib levels")
	scene.debug_jump(3)
	check(scene.palms_k == 1.0, "palms are there on a stage-3 jump")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.save_path))
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
	scene.debug_jump(4)
	scene.dispatch("door")
	check(scene.sim.view == "threshold", "scene: at the threshold")
	check(scene.action_at(Vector2(700, 500)) == "", "no continue before she holds still")
	var still := OfficeSim.THRESHOLD_STILL_LINE
	# Moving before STILL_AFTER doesn't count; then holding still for 3 s does.
	scene.threshold_t = OfficeSim.THRESHOLD_STILL_AFTER
	for i in 20:
		scene.threshold_t += 0.1
		scene._tick_still(0.1, Vector2(700 + i * 10, 500))
	check(not scene.continue_ready and scene.still_t == 0.0, "a moving cursor resets the stillness")
	for i in 32:
		scene.threshold_t += 0.1
		scene._tick_still(0.1, Vector2(890, 500) + Vector2(1, 1) * (i % 2))
	check(scene.continue_ready and count_line(scene, still) == 1, "holding still 3 s: the still line, once")
	check(scene.action_at(Vector2(700, 500)) == "continue", "continue after the still line")
	for i in 40:
		scene.threshold_t += 0.1
		scene._tick_still(0.1, Vector2(890, 500))
	check(count_line(scene, still) == 1, "the still line is queued exactly once")
	scene._tick_audio(0.1)
	check(scene.last_targets.get("breath", 1.0) == 0.0, "after the line the breath stays stopped")
	# The fallback.
	scene.debug_jump(4)
	scene.dispatch("door")
	scene.threshold_t = OfficeSim.THRESHOLD_FALLBACK
	scene._tick_still(0.1, Vector2(100, 100))
	scene._tick_still(0.1, Vector2(900, 900))
	check(scene.continue_ready and count_line(scene, still) == 1, "the fallback also lets her go on")
	# The phase lock.
	scene.debug_jump(4)
	scene.dispatch("door")
	check(is_equal_approx(scene.breath_clock, scene.THRESHOLD_BREATH_SEEK), "the breath is phase-locked at the door")
	check(not scene.continue_ready and scene.still_t == 0.0 and not scene.still_spoken, "stillness resets at the door")
	scene.threshold_t = 1.0
	scene._tick_audio(0.1)
	check(scene.last_targets.get("breath", 1.0) == 0.0, "no breath before 2.8 s")
	scene.threshold_t = 3.0
	scene._tick_audio(0.1)
	check(is_equal_approx(scene.last_targets.get("breath", 0.0), 0.55), "breath 0.55 from 2.8 s")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.save_path))
	scene.queue_free()
	await process_frame

# ---------------------------------------------------------------------------
# C7 (view): the end card
# ---------------------------------------------------------------------------
func test_end_scene() -> void:
	check(not FileAccess.get_file_as_string("res://game/intake_office.gd").contains("You noted"), "no 'You noted' on the end card")
	var scene = new_scene("user://office_end_test.json")
	await process_frame
	scene.debug_jump(4)
	scene.dispatch("door")
	scene.continue_ready = true
	scene.dispatch("continue")
	check(scene.sim.view == "end", "scene: the end card")
	scene.end_t = 1.0
	check(scene.action_at(Vector2(700, 910)) == "", "no restart while the card writes")
	scene.end_t = 4.0
	check(scene._end_row_writing(), "the log row writes itself from 3 s")
	scene._tick_audio(0.1)
	check(is_equal_approx(scene.last_targets.get("pen", 0.0), 0.45), "the pen scratches while it writes")
	var sch: Dictionary = scene._end_schedule()
	scene.end_t = sch.cont - 0.1
	check(scene.action_at(Vector2(700, 910)) == "", "no restart before 'Tide I continues.'")
	scene.end_t = sch.cont + 0.1
	check(scene.action_at(Vector2(700, 910)) == "restart" and scene.action_at(Vector2(700, 790)) == "",
		"restart only on the button, once the card is done")
	scene.sim.state.motion = false
	scene.end_t = 1.0
	check(scene.action_at(Vector2(700, 910)) == "", "Motion off: the grace still applies")
	scene.end_t = 1.6
	check(scene.action_at(Vector2(700, 910)) == "restart", "Motion off: restart after the grace")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.save_path))
	scene.queue_free()
	await process_frame
