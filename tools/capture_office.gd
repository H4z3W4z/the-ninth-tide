extends SceneTree
## Renders the office slice at key beats and saves PNGs, for visual review.
## Needs a display (not --headless):
##   godot --path . --script tools/capture_office.gd -- <out_dir> [shots.json]
## Each shot: [file, setup actions, mouse position, seconds to settle].
## Actions are sim actions ("begin", "lamp", "fit"...) or "@N" = dev jump to stage N.
## shots.json (optional) replaces the default list:
##   [{"name": "x", "actions": ["begin","coat"], "mouse": [700,500], "settle": 1.0}]

var shots := [
	["01_title", [], Vector2(700, 500), 0.3],
	["02_arrival_dusk", ["begin"], Vector2(1080, 560), 1.0],
	["03_hover_coat", ["begin"], Vector2(1080, 560), 1.0],
	["04_repair", ["begin", "lamp"], Vector2(400, 640), 0.4],
	["05_spark", ["begin", "lamp", "select_b", "fit"], Vector2(450, 500), 0.05],
	["06_lamp_lit", ["@1"], Vector2(640, 660), 2.5],
	["07_logbook", ["@1", "logbook"], Vector2(700, 600), 0.6],
	["08_log_dark", ["begin", "logbook"], Vector2(700, 500), 0.4],
	["09_after_log", ["@2"], Vector2(1100, 920), 2.5],
	["10_prints", ["@2", "puddle"], Vector2(1100, 920), 2.0],
	["11_seat_wet", ["@3"], Vector2(640, 650), 2.5],
	["12_notebook", ["@3", "notebook"], Vector2(700, 500), 0.4],
	["13_end", ["@3", "door"], Vector2(700, 500), 0.6],
	["14_menu", ["begin", "menu"], Vector2(700, 500), 0.3],
]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://captures"
	if args.size() > 1:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
		if parsed is Array:
			shots = []
			for d in parsed:
				var m: Array = d.get("mouse", [700, 500])
				shots.append([str(d.name), d.get("actions", []), Vector2(m[0], m[1]), float(d.get("settle", 1.0))])
	DirAccess.make_dir_recursive_absolute(out)
	for shot in shots:
		var scene = load("res://game/intake_office.tscn").instantiate()
		scene.save_path = "user://capture_tmp.json"
		if FileAccess.file_exists(scene.save_path):
			DirAccess.remove_absolute(scene.save_path)
		root.add_child(scene)
		await process_frame
		for a in shot[1]:
			if a.begins_with("@"):
				scene.sim.debug_jump(int(a.substr(1)))
				scene._apply_stage_instantly()
				scene._redraw()
			else:
				scene.dispatch(a)
		if shot[0] == "03_hover_coat":
			scene.hover_id = "coat"
		root.warp_mouse(shot[2])
		var t := 0.0
		while t < shot[3]:
			await process_frame
			t += 1.0 / 60.0
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(out.path_join(shot[0] + ".png"))
		print("captured ", shot[0])
		scene.queue_free()
		await process_frame
	DirAccess.remove_absolute("user://capture_tmp.json")
	quit(0)
