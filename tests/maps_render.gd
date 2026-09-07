extends SceneTree
## Run with a real display (CI uses Xvfb), never the headless dummy renderer.
var scene
const SAVE = "user://maps_render_test.json"

func _initialize(): call_deferred("run_capture")

func click_at(point: Vector2):
	for down in [true,false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func capture(name: String):
	await process_frame
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	assert(not picture.is_empty(),"Rendering must produce an actual image")
	assert(picture.save_png("res://build/map-review/"+name+".png") == OK)

func run_capture():
	root.size = Vector2i(1448,1086)
	DirAccess.make_dir_recursive_absolute("res://build/map-review")
	DirAccess.remove_absolute(SAVE)
	scene = load("res://intake_preview.tscn").instantiate()
	scene.save_path = SAVE
	root.add_child(scene)
	await process_frame
	await click_at(Vector2(240,300))
	assert(is_instance_valid(scene.map_widget),"Rendered wall-map hotspot opens viewer")
	await click_at(Vector2(180,925))
	assert(scene.map_widget.viewer.zoom > 1.0,"Native Button input zooms the map")
	await capture("office-map-zoom")
	var panel = scene.map_widget
	panel.buttons.fit.pressed.emit()
	var before = panel.viewer.zoom
	for i in range(2):
		var touch = InputEventScreenTouch.new()
		touch.index = i
		touch.position = Vector2(250+i*130,400)
		touch.pressed = true
		Input.parse_input_event(touch)
		await process_frame
	var drag = InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(480,400)
	drag.relative = Vector2(100,0)
	Input.parse_input_event(drag)
	await process_frame
	assert(panel.viewer.zoom > before,"Native touch dispatch reaches pinch handler")
	for i in range(2):
		var touch = InputEventScreenTouch.new()
		touch.index = i
		touch.pressed = false
		touch.position = Vector2(250+i*230,400)
		Input.parse_input_event(touch)
		await process_frame
	panel.closed.emit()
	await process_frame
	for action in ["repair","toggle_supply","select_b","fit","toggle_supply","back"]: scene.dispatch(action)
	scene.dispatch("chart_room")
	await capture("chart-room")
	panel = scene.map_widget
	for i in range(3): scene.map_progress.acquire(i)
	scene.map_progress.select_piece(0)
	scene.map_progress.rotation_step = 0
	scene.map_progress.place(0)
	scene.map_progress.select_piece(1)
	panel.show_mode("assemble")
	await capture("partial-assembly")
	for i in [1,2]:
		scene.map_progress.select_piece(i)
		scene.map_progress.rotation_step = 0
		scene.map_progress.place(i)
	scene.map_progress.anchor = 0
	scene.map_progress.north_step = 0
	scene.map_progress.reference_day = 17
	scene.map_progress.compare()
	panel.show_mode("compare")
	await capture("completed-comparison")
	panel.show_mode("composite")
	await capture("notebook-composite")
	panel.closed.emit()
	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE)
	print("PASS: real renderer, native mouse/touch dispatch and five review screenshots")
	quit()
