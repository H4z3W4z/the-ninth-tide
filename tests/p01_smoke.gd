extends SceneTree
var failures = []
func _initialize():
	call_deferred("run_checks")
func check(condition, message):
	if not condition:
		failures.append(message)
		push_error(message)
func run_checks():
	var scene = load("res://intake_preview.tscn").instantiate()
	scene.save_path = "user://p01_automated_test.json"
	root.add_child(scene)
	scene.dispatch("confirm_reset")
	scene.dispatch("select_b")
	scene.dispatch("fit")
	check(not scene.state.bridge_installed, "Cannot fit a bridge while supply is ON")
	scene.dispatch("toggle_supply")
	scene.dispatch("select_c")
	scene.dispatch("fit")
	check(not scene.state.bridge_installed, "Curved C must not solve the straight seat")
	scene.dispatch("select_b")
	scene.dispatch("fit")
	check(scene.state.bridge_installed and not scene.state.p01_complete, "Installation alone must not complete the repair")
	scene.dispatch("toggle_supply")
	check(scene.state.p01_complete, "B installed plus supply ON completes P01")
	scene.dispatch("weather_2")
	check(scene.state.p01_complete, "Weather review must preserve puzzle completion")
	var second = load("res://intake_preview.tscn").instantiate()
	second.save_path = scene.save_path
	root.add_child(second)
	check(second.state.p01_complete and second.state.weather == 2, "Completion and weather must survive reload")
	second.dispatch("notes")
	check(second.view == "note", "Solved pencil note must remain accessible")
	second.dispatch("confirm_reset")
	second.dispatch("weather_2")
	check(not second.state.p01_complete, "Weather selector must not solve P01")
	check(second.action_at(Vector2(300,550)) == "repair", "Lamp hotspot must open repair")
	DirAccess.remove_absolute(second.save_path)
	scene.queue_free()
	second.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS: P01 safety, wrong spare, solution, weather independence, persistence and hotspot checks")
	quit(0 if failures.is_empty() else 1)
