extends SceneTree
var failures = []
const Progress = preload("res://scripts/maps/map_progress.gd")
const SAVE = "user://maps_automated_test.json"

func _initialize(): call_deferred("run_checks")
func check(ok, label):
	if not ok:
		failures.append(label)
		push_error(label)

func tap(panel, id):
	check(panel.buttons.has(id),"Button exists: "+id)
	if panel.buttons.has(id): panel.buttons[id].pressed.emit()

func run_checks():
	DirAccess.remove_absolute(SAVE)
	var scene = load("res://intake_preview.tscn").instantiate()
	scene.save_path = SAVE
	root.add_child(scene)
	check(scene.action_at(Vector2(240,300)) == "maps","Office map has a room hotspot")
	scene.dispatch("chart_room")
	check(not is_instance_valid(scene.map_widget),"Chart Room remains locked before P01")
	scene.dispatch("maps")
	var panel = scene.map_widget
	check(panel.mode == "office_survey","Atmospheric map opens without P01")
	check("office_survey" in scene.map_progress.observed,"Atmospheric survey is preserved")
	tap(panel,"zoom_in")
	check(panel.viewer.zoom > 1,"Zoom button enlarges map")
	tap(panel,"pan0")
	check(panel.viewer.offset.x > 0,"Pan button moves enlarged map")
	tap(panel,"fit")
	check(panel.viewer.zoom == 1 and panel.viewer.offset == Vector2.ZERO,"Fit resets framing")
	var key = InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_PLUS
	panel.viewer._gui_input(key)
	check(panel.viewer.zoom > 1,"Keyboard zoom works")
	panel.viewer.fit()
	for i in range(2):
		var touch = InputEventScreenTouch.new()
		touch.index = i
		touch.position = Vector2(200+100*i,200)
		touch.pressed = true
		panel.viewer._gui_input(touch)
	var drag = InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(370,200)
	panel.viewer._gui_input(drag)
	check(panel.viewer.zoom > 1,"Two-finger pinch enlarges map")
	panel.closed.emit()
	await process_frame
	for action in ["repair","toggle_supply","select_b","fit","toggle_supply","back"]: scene.dispatch(action)
	scene.dispatch("chart_room")
	panel = scene.map_widget
	tap(panel,"drawer")
	tap(panel,"weight")
	tap(panel,"board")
	check(scene.map_progress.acquired == [true,true,true],"All fragments recoverable after P01")
	tap(panel,"piece0")
	tap(panel,"slot1")
	check(not scene.map_progress.placed[1] and scene.map_progress.acquired[0],"Wrong slot never consumes a fragment")
	tap(panel,"slot0")
	check(not scene.map_progress.placed[0],"Wrong orientation is rejected")
	while scene.map_progress.rotation_step != 0: tap(panel,"rotate")
	tap(panel,"slot0")
	tap(panel,"piece1")
	tap(panel,"rotate")
	var partial = scene.map_progress.snapshot()
	panel.closed.emit()
	await process_frame
	var restored = load("res://intake_preview.tscn").instantiate()
	restored.save_path = SAVE
	root.add_child(restored)
	check(restored.map_progress.snapshot() == partial,"Acquisition, partial placement and selected rotation survive reload")
	restored.dispatch("chart_room")
	panel = restored.map_widget
	panel.show_mode("assemble")
	for i in [1,2]:
		tap(panel,"piece"+str(i))
		while restored.map_progress.rotation_step != 0: tap(panel,"rotate")
		tap(panel,"slot"+str(i))
	check(restored.map_progress.assembled() and not restored.map_progress.complete,"Assembly alone does not award interval 3")
	tap(panel,"compare")
	tap(panel,"clip")
	check(not restored.map_progress.complete,"Wrong registration cannot complete P03")
	while restored.map_progress.anchor != 0: tap(panel,"anchor")
	tap(panel,"clip")
	check(not restored.map_progress.complete,"Wrong north direction cannot complete P03")
	while restored.map_progress.north_step != 0: tap(panel,"north")
	tap(panel,"clip")
	check(not restored.map_progress.complete,"Wrong date cannot complete P03")
	tap(panel,"date")
	tap(panel,"clip")
	check(restored.map_progress.complete and "composite" in restored.map_progress.observed,"Clipping matched sheets preserves interval and composite")
	var evidence_count = restored.map_progress.observed.size()
	restored.map_progress.compare()
	check(evidence_count == restored.map_progress.observed.size(),"Repeated solution does not duplicate evidence")
	restored.map_progress.set_office_version("office_survey_shifted")
	restored.save_progress()
	var saved = Progress.new()
	saved.restore(JSON.parse_string(FileAccess.get_file_as_string(SAVE)).maps)
	check(saved.complete and "office_survey" in saved.observed and saved.office_version == "office_survey_shifted","Solved comparison and earlier map survive a version change and reload")
	var invalid = Progress.new()
	invalid.restore({"schema":1,"acquired":[false,false,false],"placed":[true,true,true],"complete":true,"selected":999,"rotation_step":"bad","observed":["unknown","composite"]})
	check(not invalid.complete and not invalid.assembled() and invalid.selected == -1,"Malformed or impossible save cannot grant P03")
	var legacy = Progress.new()
	legacy.restore({})
	check(not legacy.complete,"Legacy P01 save starts with clean map state")
	panel.closed.emit()
	restored.dispatch("weather_2")
	check(restored.map_progress.office_version == "office_survey_shifted" and restored.map_progress.complete,"Weather review does not rewrite map story state")
	scene.queue_free()
	restored.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE)
	if failures.is_empty(): print("PASS: map hotspots, buttons, zoom, pan, pinch, fragment recovery, wrong attempts, comparison, persistence and historical evidence")
	quit(0 if failures.is_empty() else 1)
