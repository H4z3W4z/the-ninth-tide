extends SceneTree
## Headless tests for the Intake Office slice: logic (OfficeSim) and the
## scene's hit-testing/save wiring. Run after an import:
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

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	test_full_playthrough()
	test_p01_rules()
	test_gating()
	test_hints_progress()
	test_save_roundtrip_and_tamper()
	test_determinism()
	await test_scene_wiring()
	if failures.is_empty():
		print("PASS: office slice — playthrough, P01 rules, gating, hints, saves, determinism, scene wiring")
	else:
		print("FAIL (%d): %s" % [failures.size(), "; ".join(failures)])
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
	ev = s.dispatch("chair")
	check(s.has_seen("shadow"), "chair after lamp records wrong shadow")
	s.dispatch("logbook")
	check(s.state.log_read and s.has_seen("handwriting"), "log read records handwriting")
	ev = s.dispatch("back")
	check(has_ev(ev, "fx", "sea_fade"), "leaving the log fades the sea")
	check(s.objective() == "changed", "objective -> changed")
	s.dispatch("window")
	check(s.has_seen("silent"), "window notices the silent sea")
	ev = s.dispatch("back")
	check(not has_ev(ev, "fx", "sea_fade"), "sea fade plays once")
	s.dispatch("puddle")
	check(s.state.prints_seen, "puddle reveals prints after the log")
	ev = s.dispatch("chair")
	check(s.state.seat_wet and has_ev(ev, "sfx", "sting"), "chair after prints: wet seat + sting")
	check(s.objective() == "leave", "objective -> leave")
	s.dispatch("door")
	check(s.view == "end" and s.state.finished, "door ends the slice")
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
	check(not bad.from_dict({"schema": 1}), "old schema rejected")
	check(not bad.from_dict("junk"), "junk rejected")
	var tampered := OfficeSim.new()
	tampered.from_dict({"schema": 2, "started": true, "seat_wet": true, "seen": ["nope", 3]})
	check(not tampered.state.seat_wet, "orphan progress flags are dropped")
	check(tampered.state.seen.is_empty(), "unknown observations are dropped")

func test_determinism() -> void:
	var script := ["begin", "lamp", "fit", "toggle_supply", "select_c", "fit", "select_b", "fit",
		"toggle_supply", "logbook", "back", "puddle", "chair", "hint", "door"]
	var a := OfficeSim.new()
	var b := OfficeSim.new()
	var log_a := []
	var log_b := []
	for act in script:
		log_a.append(a.dispatch(act))
		log_b.append(b.dispatch(act))
	check(JSON.stringify(log_a) == JSON.stringify(log_b), "same actions -> same events")
	check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "same actions -> same state")

func test_scene_wiring() -> void:
	var scene = load("res://game/intake_office.tscn").instantiate()
	scene.save_path = "user://office_wiring_test.json"
	if FileAccess.file_exists(scene.save_path):
		DirAccess.remove_absolute(scene.save_path)
	root.add_child(scene)
	await process_frame
	check(scene.action_at(Vector2(700, 500)) == "begin", "title click begins")
	scene.dispatch("begin")
	check(scene.action_at(Vector2(330, 560)) == "lamp", "lamp hotspot")
	check(scene.action_at(Vector2(950, 690)) == "mug", "mug beats papers/desk")
	check(scene.action_at(Vector2(1300, 500)) == "door", "door hotspot")
	check(scene.action_at(Vector2(1180, 45)) == "notebook", "HUD notebook beats hotspots")
	scene.dispatch("lamp")
	check(scene.action_at(Vector2(400, 640)) == "toggle_supply", "repair supply switch")
	check(scene.action_at(Vector2(200, 920)) == "select_b", "repair spare B")
	scene.dispatch("toggle_supply"); scene.dispatch("select_b"); scene.dispatch("fit"); scene.dispatch("toggle_supply")
	var again = load("res://game/intake_office.tscn").instantiate()
	again.save_path = scene.save_path
	root.add_child(again)
	await process_frame
	check(again.sim.state.p01_complete and again.sim.view == "room", "scene reload restores P01")
	DirAccess.remove_absolute(scene.save_path)
	scene.queue_free()
	again.queue_free()
	await process_frame
