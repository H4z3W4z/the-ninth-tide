extends SceneTree
## Renders the game at chosen beats and saves PNGs, for visual review. Any room.
## Needs a display (not --headless):
##   godot --path . --fixed-fps 60 --disable-vsync --script tools/capture.gd -- <out_dir> [shots.json]
## --fixed-fps makes every frame exactly 1/60 s, so a shot's settle time is scene time and
## captures are deterministic; --disable-vsync keeps it fast when a locked session throttles
## the window. Without the flags it still works, just slowly on a locked desktop.
##
## A shot is {name, room, actions, mouse, settle}:
##   room     the room the "@N" stage jumps apply to (default "R02")
##   actions  dispatched in order. Special forms:
##              "@N"          the room's own debug stage N (R02: 0-3 stages, 4 report filed, 5 threshold passed)
##              "@tide:N"     the start of tide N (1-9), standing in `room`
##              "@enter:RID"  go straight to a room, ignoring gates
##              "@seen"       note every observation of the current room
##              "click:X,Y"   a real click at X,Y (advances chains like the mouse does)
##              anything else goes to scene.dispatch (sim actions, "go:R03", ...)
##   mouse    [x, y] cursor position; settle: seconds to run before the capture
## shots.json (optional) replaces the default list:
##   [{"name": "x", "room": "R05", "actions": ["@tide:3"], "mouse": [700,500], "settle": 1.0}]

## The drawer code by up-dial clicks from 0-0-0-0 (the code is still 1-8-5-2).
const DIAL_1852 := ["dial_0", "dial_1", "dial_1", "dial_1", "dial_1", "dial_1", "dial_1", "dial_1",
	"dial_1", "dial_2", "dial_2", "dial_2", "dial_2", "dial_2", "dial_3", "dial_3"]
## The evening tide on the report's time dials, by up clicks from 00:00: 19:34.
const TIME_1934 := ["rtime_0", "rtime_1", "rtime_1", "rtime_1", "rtime_1", "rtime_1", "rtime_1", "rtime_1",
	"rtime_1", "rtime_1", "rtime_2", "rtime_2", "rtime_2", "rtime_3", "rtime_3", "rtime_3", "rtime_3"]
## The closure report's answer (fields 2, 1, 1; high water 19:34) by clicks, filed, then
## Back, which is when the door unlatches.
var REPORT_RIGHT: Array = ["papers", "field_0", "field_0", "field_1", "field_2"] + TIME_1934 + ["file_report", "back"]
## Six looks away at stage 3: every change the room makes while she isn't watching.
const LOOK_AWAY_ALL := ["papers", "back", "papers", "back", "papers", "back", "papers", "back",
	"papers", "back", "papers", "back"]

## Default: the office at every stage (the slice's review set), then every room at its
## opening tide. [file, actions, mouse, settle, room]
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
	["20_end", ["@4", "door", "continue"], Vector2(700, 500), 19.0],
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
	["32_report_time", ["@3", "papers", "field_0", "field_0", "field_1"] + TIME_1934, Vector2(700, 1040), 0.6],
	["33_report_miss_log", ["@3", "toggle_motion", "papers", "file_report", "file_report", "file_report", "back", "logbook"],
		Vector2(700, 1040), 1.0],
	["34_contours", ["@3", "map", "map"], Vector2(250, 330), 8.0],
	["35_lookaway_all", ["@3"] + LOOK_AWAY_ALL, Vector2(640, 650), 3.0],
	["36_threshold_turned_end", ["@4", "door", "turn"], Vector2(700, 500), 16.0],
	["37_stage2_cold", ["@2"], Vector2(640, 650), 2.5],
	["38_threshold_mid", ["@4", "door"], Vector2(700, 500), 9.5],
	["39_end_card_go_on", ["@4", "door", "continue"], Vector2(700, 910), 25.0],
	["40_office_after", ["@5"], Vector2(640, 650), 2.0],
	["41_office_tide2_exits", ["@tide:2"], Vector2(350, 950), 2.0],
	["R01_jetty", ["@tide:1", "go:R01"], Vector2(700, 500), 1.0, "R02"],
	["R03_chart_room", ["@tide:2", "go:R03"], Vector2(700, 500), 1.0],
	["R04_listening_room", ["@tide:2", "go:R04"], Vector2(700, 500), 1.0],
	["R05_kitchen", ["@tide:3", "go:R05"], Vector2(700, 500), 1.0],
	["R06_bunks", ["@tide:3", "go:R06"], Vector2(700, 500), 1.0],
	["R07_wet_lab", ["@tide:4", "@enter:R07"], Vector2(700, 500), 1.0],
	["R08_machine_room", ["@tide:4", "@enter:R08"], Vector2(700, 500), 1.0],
	["R09_lantern_gallery", ["@tide:5", "@enter:R09"], Vector2(700, 500), 1.0],
	["R10_records_vault", ["@tide:6", "@enter:R10"], Vector2(700, 500), 1.0],
	["R11_dry_stair", ["@tide:3", "@enter:R11"], Vector2(700, 500), 1.0],
	["R12_chamber", ["@tide:9", "@enter:R12"], Vector2(700, 500), 1.0],
	["R07_notebook_plan", ["@tide:6", "@enter:R07", "notebook", "tab:plan"], Vector2(700, 500), 0.6],
	["R05_hint", ["@tide:3", "@enter:R05", "hint"], Vector2(700, 500), 1.0],
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
				shots.append([str(d.name), d.get("actions", []), Vector2(m[0], m[1]), float(d.get("settle", 1.0)),
					str(d.get("room", "R02"))])
	DirAccess.make_dir_recursive_absolute(out)
	# Per-output save file, so parallel capture runs never share progress.
	var save_path := "user://capture_%d.json" % absi(out.hash())
	for shot in shots:
		GameView.remove_saves(save_path)
		var scene = load("res://game/core/game.tscn").instantiate()
		scene.save_path = save_path
		scene.migrate_slice_save = false
		root.add_child(scene)
		await process_frame
		var rid: String = shot[4] if shot.size() > 4 else "R02"
		for a in shot[1]:
			if a == "@seen":
				var r = scene.room_sim()
				for id in r.c("OBSERVATIONS", {}):
					r._observe(id)
			elif a.begins_with("@tide:"):
				scene.tide_jump(int(a.substr(6)), rid)
			elif a.begins_with("@enter:"):
				scene.enter_jump(a.substr(7))
			elif a.begins_with("@"):
				scene.room_jump(rid, int(a.substr(1)))
			elif a.begins_with("click:"):
				var xy: PackedStringArray = a.substr(6).split(",")
				scene.click(Vector2(float(xy[0]), float(xy[1])))
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
		GameView.remove_saves(save_path)
	# Let the audio server release the freed players' playbacks before exit (no leak warnings).
	for i in 60:
		await process_frame
	quit(0)
