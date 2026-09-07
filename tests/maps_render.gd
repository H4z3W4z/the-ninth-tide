extends SceneTree
## CI requires a real display (Xvfb). --input-only is a separate headless check.
var scene
const SAVE = "user://maps_render_test.json"
var input_only = "--input-only" in OS.get_cmdline_user_args()

func require(condition: bool, message: String) -> bool:
	if not condition:
		push_error("FAIL: " + message)
		quit(1)
	return condition

func window_point(point: Vector2) -> Vector2:
	# parse_input_event takes window pixels; test points use the design canvas.
	return root.get_final_transform() * point

func _initialize(): call_deferred("run_capture")

func click_at(point: Vector2):
	for down in [true,false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = window_point(point)
		event.global_position = event.position
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func capture(name: String) -> bool:
	if input_only: return true
	await process_frame
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	if not require(picture != null and not picture.is_empty(), "Rendering must produce an actual image"): return false
	return require(picture.save_png("res://build/map-review/"+name+".png") == OK, "Save capture: " + name)

func exercise_input(window_size: Vector2i) -> bool:
	root.size = window_size
	await process_frame
	await process_frame
	# Deliberately do not move the cursor: the click carries its own position.
	await click_at(Vector2(240,300))
	if not require(is_instance_valid(scene.map_widget), "Wall-map click opens viewer at " + str(window_size)): return false
	await click_at(Vector2(180,925))
	if not require(scene.map_widget.viewer.zoom > 1.0, "Native Button input zooms the map"): return false
	if window_size == Vector2i(1448,1086):
		if not await capture("office-map-zoom"): return false
	var panel = scene.map_widget
	await click_at(panel.buttons.fit.get_global_rect().get_center())
	if not require(is_equal_approx(panel.viewer.zoom, 1.0), "Native Fit button resets zoom"): return false
	var before = panel.viewer.zoom
	for i in range(2):
		var touch = InputEventScreenTouch.new()
		touch.index = i
		touch.position = window_point(Vector2(250+i*130,400))
		touch.pressed = true
		Input.parse_input_event(touch)
		await process_frame
	var drag = InputEventScreenDrag.new()
	drag.index = 1
	drag.position = window_point(Vector2(480,400))
	drag.relative = window_point(Vector2(480,400)) - window_point(Vector2(380,400))
	Input.parse_input_event(drag)
	await process_frame
	if not require(panel.viewer.zoom > before, "Native touch dispatch reaches pinch handler"): return false
	for i in range(2):
		var touch = InputEventScreenTouch.new()
		touch.index = i
		touch.pressed = false
		touch.position = window_point(Vector2(250+i*230,400))
		Input.parse_input_event(touch)
		await process_frame
	if not require(panel.viewer.touches.is_empty(), "Released fingers clear pinch state"): return false
	await click_at(panel.buttons.close.get_global_rect().get_center())
	if not require(not is_instance_valid(scene.map_widget), "Native Back button closes viewer"): return false
	print("PASS: native click, zoom, Fit, pinch and close at ", window_size)
	return true

func run_capture():
	# A script error can strand a coroutine; always fail before the outer CI timeout.
	create_timer(45.0).timeout.connect(func(): require(false, "Map render harness exceeded 45 seconds"))
	if not require(input_only or DisplayServer.get_name() != "headless", "Rendered suite requires a real display; use --input-only for dispatch checks"): return
	DirAccess.make_dir_recursive_absolute("res://build/map-review")
	DirAccess.remove_absolute(SAVE)
	scene = load("res://intake_preview.tscn").instantiate()
	scene.save_path = SAVE
	root.add_child(scene)
	await process_frame
	for window_size in [Vector2i(1024,768), Vector2i(1448,1086)]:
		if not await exercise_input(window_size): return
	for action in ["repair","toggle_supply","select_b","fit","toggle_supply","back"]: scene.dispatch(action)
	scene.dispatch("chart_room")
	if not await capture("chart-room"): return
	var panel = scene.map_widget
	for i in range(3): scene.map_progress.acquire(i)
	scene.map_progress.select_piece(0)
	scene.map_progress.rotation_step = 0
	scene.map_progress.place(0)
	scene.map_progress.select_piece(1)
	panel.show_mode("assemble")
	if not await capture("partial-assembly"): return
	for i in [1,2]:
		scene.map_progress.select_piece(i)
		scene.map_progress.rotation_step = 0
		scene.map_progress.place(i)
	scene.map_progress.anchor = 0
	scene.map_progress.north_step = 0
	scene.map_progress.reference_day = 17
	scene.map_progress.compare()
	panel.show_mode("compare")
	if not await capture("completed-comparison"): return
	panel.show_mode("composite")
	if not await capture("notebook-composite"): return
	panel.closed.emit()
	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE)
	if input_only:
		print("PASS: native input dispatch only; rendering and screenshots were not tested")
	else:
		print("PASS: real renderer, native mouse/touch dispatch at two sizes and five review screenshots")
	quit()
