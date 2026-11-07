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
	await test_scene_wiring()
	await test_presentation_cleanup()
	if failures.is_empty():
		print("PASS: office slice — playthrough, P01, drawer, log rewrite, gates, drift, evidence, story flags, saves, title menu, determinism, scene wiring, cleanup")
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
	check(has_ev(ev, "sfx", "knock_glass") and has_ev(ev, "sfx", "latch_near"), "knock and near latch follow")
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
	check(not bad.from_dict("junk"), "junk rejected")
	var tampered := OfficeSim.new()
	tampered.from_dict({"schema": 3, "started": true, "seat_wet": true, "seen": ["nope", 3]})
	check(not tampered.state.seat_wet, "orphan progress flags are dropped")
	check(tampered.state.seen.is_empty(), "unknown observations are dropped")
	var dials := OfficeSim.new()
	dials.from_dict({"schema": 3, "drawer_dial": [12, -3, 5, 2]})
	check(dials.state.drawer_dial == [9, 0, 5, 2], "dials clamp to 0-9")
	dials.from_dict({"schema": 3, "drawer_dial": [1, 2, 3]})
	check(dials.state.drawer_dial == [0, 0, 0, 0], "a short dial array is ignored")
	dials.from_dict({"schema": 3, "drawer_dial": ["1", 8, 5, 2]})
	check(dials.state.drawer_dial == [0, 0, 0, 0], "non-numeric dials are ignored")

func test_determinism() -> void:
	var script := ["begin", "lamp", "fit", "toggle_supply", "select_c", "fit", "select_b", "fit",
		"toggle_supply", "logbook", "back", "puddle", "drawer", "try_drawer"]
	for i in 1: script.append("dial_0")
	for i in 8: script.append("dial_1")
	for i in 5: script.append("dial_2")
	for i in 2: script.append("dial_3")
	script.append_array(["try_drawer", "back", "logbook", "back", "chair", "hint", "door", "continue"])
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
	dial_to(s, [0, 7, 1, 4])
	check("tomorrow" in says(s.dispatch("try_drawer")), "07:14 gets its own nudge")
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
	check(s.log_rows().size() == 13, "13 rows after the wet seat")
	check(s.log_rows()[12][3] == "She opens the door. It is already open.", "the final line foretells the door")
	ev = s.dispatch("logbook")
	check(s.state.foretold_door and has_ev(ev, "fx", "log_write") and says(ev) == "It has the next line already.", "foretold door once")
	s.dispatch("back")
	ev = s.dispatch("logbook")
	check(not has_ev(ev, "fx", "log_write"), "foretold door does not repeat")
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
	th.debug_jump(3)
	th.dispatch("door")
	check(th.view == "threshold", "door with the wet seat -> threshold")
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
	check(not th.is_closeup("threshold") and th.is_closeup("drawer"), "is_closeup: drawer yes, threshold no")

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
	for a in ["try_drawer", "back", "logbook", "back", "chair", "window", "hooks"]:
		s.dispatch(a)
	var missing := []
	for id in OfficeSim.OBSERVATIONS:
		if not s.has_seen(id):
			missing.append(id)
	check(missing.is_empty(), "every observation reachable in one run (missing: %s)" % [missing])
	check(s.state.seen.size() == OfficeSim.OBSERVATIONS.size(), "seen.size() == OBSERVATIONS.size()")
	var j := OfficeSim.new()
	j.debug_jump(3)
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
	check(say_ev(ev, "Three taps").get("story", false) and say_ev(ev, "unlatched").get("story", false), "knock lines are story")
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
	check(t.state.seat_wet and t.objective() == "leave", "seat_wet round-trips")
	s.dispatch("logbook")
	t = roundtrip(s)
	check(t.state.foretold_door, "foretold_door round-trips")
	s.dispatch("back"); s.dispatch("door")
	check(s.view == "threshold", "at the threshold")
	t = roundtrip(s)
	check(t.view == "room" and t.state.seat_wet and not t.state.finished, "a threshold save lands in the room")
	var bad := OfficeSim.new()
	bad.from_dict({"schema": 3, "started": true, "p01_complete": true, "log_read": true,
		"prints_seen": true, "log_rewritten": true})
	check(not bad.state.log_rewritten, "log_rewritten without drawer_open is dropped")
	bad.from_dict({"schema": 3, "started": true, "drawer_open": true})
	check(not bad.state.drawer_open, "drawer_open without log_read is dropped")
	bad.from_dict({"schema": 3, "started": true, "p01_complete": true, "log_read": true, "prints_seen": true,
		"drawer_open": true, "seat_wet": true, "foretold_door": true})
	check(not bad.state.seat_wet and not bad.state.foretold_door, "seat_wet needs log_rewritten; foretold needs seat_wet")
	bad.from_dict({"schema": 3, "initialled": true})
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
	check(scene.action_at(Vector2(484, 535)) == "dial_0", "dial 0")
	check(scene.action_at(Vector2(964, 535)) == "dial_3", "dial 3")
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
	# Threshold gate and the end-card grace.
	scene.debug_jump(3)
	scene.dispatch("door")
	check(scene.sim.view == "threshold", "scene reaches the threshold")
	check(scene.action_at(Vector2(700, 500)) == "", "no continue before 9.4 s")
	check(scene.action_at(Vector2(1180, 45)) == "notebook", "HUD still works at the threshold")
	scene.threshold_t = 9.5
	check(scene.action_at(Vector2(700, 500)) == "continue", "continue after 9.4 s")
	scene.dispatch("continue")
	check(scene.action_at(Vector2(700, 790)) == "", "Play again ignores the continue click")
	scene.end_t = 2.0
	check(scene.action_at(Vector2(700, 790)) == "restart", "Play again after the grace")
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
	check(scene.pending_sfx.size() == 2 and scene.lines.size() == 3, "chair queues knock, latch and three lines")
	check(scene.subtitle.text == "The seat is wet. Still warm underneath.", "first line shows at once")
	var dues := []
	var expect := [4.4, 6.6, 8.6]
	var dues_ok: bool = scene.lines.size() == 3
	for i in scene.lines.size():
		dues.append(scene.lines[i].due - scene.time)
		dues_ok = dues_ok and absf(dues[i] - expect[min(i, 2)]) < 0.001
	check(dues_ok, "delays are seconds after the click (%s)" % [dues])
	# A click inside the story line's read time queues behind it instead of cutting it off.
	scene.dispatch("mug")
	check(scene.subtitle.text == "The seat is wet. Still warm underneath.", "story line is not cut off early")
	check(scene.lines.size() == 4 and scene.lines[0].text.begins_with("Two rings"), "the click's line waits its turn")
	# Non-story chatter is dropped by the next click; story lines survive.
	scene.time += 10.0
	scene._tick_lines(0.0)
	scene.dispatch("stove")
	var story_left := 0
	for l in scene.lines:
		if l.story: story_left += 1
	check(story_left == scene.lines.size(), "only story lines stay queued after a click")
	# Two reveals back to back never interleave: the second waits for the first.
	scene.debug_jump(2)
	scene.sim.state.prints_seen = true
	scene.dispatch("drawer")
	for i in 4:
		for n in [1, 8, 5, 2][i]:
			scene.dispatch("dial_%d" % i)
	scene.dispatch("try_drawer")
	var drawer_last: float = scene.lines.back().due
	var drawer_count: int = scene.lines.size()
	scene.dispatch("back")
	scene.dispatch("logbook")
	check(scene.sim.state.log_rewritten, "scene: the log rewrites")
	var ordered := true
	for i in range(drawer_count, scene.lines.size()):
		ordered = ordered and scene.lines[i].due > drawer_last
	check(scene.lines.size() == drawer_count + 4 and ordered, "the log reveal queues after the drawer reveal")
	scene.dispatch("restart")
	check(scene.sim.view == "title", "restart returns to title")
	check(scene.pending_sfx.is_empty() and scene.lines.is_empty() and scene.subtitle.text == "", "restart clears lines and sounds")
	check(scene.oneshots.is_empty() and scene.lamp_glow.energy == 0.0, "restart stops one-shots and the lamp")
	check(scene.shadow_creep == 0 and scene.log_shown_hand == 0, "restart resets view state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.save_path))
	scene.queue_free()
	await process_frame
