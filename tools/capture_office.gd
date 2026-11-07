extends SceneTree
## Renders the office slice at key beats and saves PNGs, for visual review.
## Needs a display (not --headless):
##   godot --path . --fixed-fps 60 --disable-vsync --script tools/capture_office.gd -- <out_dir> [shots.json]
## --fixed-fps makes every frame exactly 1/60 s, so a shot's settle time is scene time and
## captures are deterministic; --disable-vsync keeps it fast when a locked session throttles
## the window to ~1 fps. Without the flags it still works, just slowly on a locked desktop.
## Each shot: [file, setup actions, mouse position, seconds to settle].
## Actions are sim actions ("begin", "lamp", "fit"...), "@N" = dev jump to stage N (0-4, 4 = report
## filed), or "@seen" = mark every observation seen (for the full-notebook layout check).
## Actions go straight to scene.dispatch, so time-gated clicks ("continue") work at once.
## shots.json (optional) replaces the default list:
##   [{"name": "x", "actions": ["begin","coat"], "mouse": [700,500], "settle": 1.0}]

## The drawer code by up-dial clicks from 0-0-0-0 (the code is still 1-8-5-2).
const DIAL_1852 := ["dial_0", "dial_1", "dial_1", "dial_1", "dial_1", "dial_1", "dial_1", "dial_1",
	"dial_1", "dial_2", "dial_2", "dial_2", "dial_2", "dial_2", "dial_3", "dial_3"]
## The closure report's answer (2, 1, 1, 1) by clicks, then filed.
const REPORT_RIGHT := ["papers", "field_0", "field_0", "field_1", "field_2", "field_3", "file_report"]

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
	["13_end", ["@4", "door"], Vector2(700, 500), 0.6],
	["14_menu", ["begin", "menu"], Vector2(700, 500), 0.3],
	["15_drawer_locked", ["@2", "puddle", "drawer"], Vector2(700, 900), 0.6],
	["16_drawer_open", ["@2", "puddle", "drawer"] + DIAL_1852 + ["try_drawer"], Vector2(700, 900), 1.5],
	["17_log_rewritten", ["@2", "puddle", "drawer"] + DIAL_1852 + ["try_drawer", "back", "logbook"],
		Vector2(700, 1040), 3.0],
	["18_stage3_room", ["@3"], Vector2(640, 650), 7.0],
	["19_threshold", ["@4", "door"], Vector2(700, 500), 6.0],
	["19b_threshold_still", ["@4", "door"], Vector2(700, 500), 13.0],
	["20_end", ["@4", "door", "continue"], Vector2(700, 500), 14.0],
	["21_log_blot", ["@1", "logbook"], Vector2(700, 1040), 3.0],
	["22_drawer_brass", ["@2", "puddle", "drawer"], Vector2(700, 900), 0.6],
	["23_photo_behind", ["@2", "puddle", "drawer"] + DIAL_1852 + ["try_drawer", "look_photo", "look_photo"],
		Vector2(700, 1040), 1.5],
	["24_report_blank", ["@3", "papers"], Vector2(700, 1040), 0.6],
	["25_report_filed", ["@4", "papers"], Vector2(700, 1040), 0.6],
	["26_stage3_palms", ["@3", "chair"], Vector2(640, 500), 8.0],
	["27_soundings_map", ["@2", "drawer"] + DIAL_1852 + ["try_drawer", "back", "map"], Vector2(250, 330), 8.0],
	["28_notebook_full", ["@4", "@seen", "notebook"], Vector2(700, 1040), 0.6],
	["29_log_full", ["@3", "toggle_motion", "coat", "window", "mug"] + REPORT_RIGHT + ["logbook"],
		Vector2(700, 1040), 0.6],
	["30_stage3_left", ["@3"], Vector2(100, 500), 7.0],
	["31_stage3_static", ["@3", "toggle_motion"], Vector2(640, 650), 2.0],
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
	# Per-output save file, so parallel capture runs never share progress.
	var save_path := "user://capture_%d.json" % absi(out.hash())
	for shot in shots:
		_remove(save_path)
		var scene = load("res://game/intake_office.tscn").instantiate()
		scene.save_path = save_path
		root.add_child(scene)
		await process_frame
		for a in shot[1]:
			if a == "@seen":
				for id in OfficeSim.OBSERVATIONS:
					scene.sim._observe(id)
			elif a.begins_with("@"):
				scene.debug_jump(int(a.substr(1)))
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
		_remove(save_path)
	quit(0)

func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
