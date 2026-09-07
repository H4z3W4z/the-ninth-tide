extends Node2D
## Asset assembly sample for P01. Weather buttons are review tools, not story progress.
const SIZE = Vector2(1448, 1086)
const DEFAULT_SAVE_PATH = "user://intake_asset_preview_v1.json"
const PAPER = Color("ded4ba")
const INK = Color("172b36")
const GOLD = Color("d2aa66")
const MapProgress = preload("res://scripts/maps/map_progress.gd")
const MapWorkbench = preload("res://scripts/maps/map_workbench.gd")
var map_progress = MapProgress.new()
var map_widget
var save_path = DEFAULT_SAVE_PATH
var textures = {}
var state = {"schema": 1, "supply_on": true, "bridge_installed": false,
	"p01_complete": false, "weather": 0, "motion": true}
var selected = ""
var view = "room"
var hint_level = 0
var rain_frame = 0
var feedback = "Inventory the station. Begin with the desk lamp."
var feedback_label: Label
var tick: Timer

func _ready():
	var manifest_file = FileAccess.open("res://asset_manifest.json", FileAccess.READ)
	var manifest = JSON.parse_string(manifest_file.get_as_text())
	for asset in manifest.assets:
		if asset.path.ends_with(".png"):
			textures[asset.id] = load("res://" + asset.path)
	load_progress()
	feedback_label = Label.new()
	feedback_label.position = Vector2(40, 1009)
	feedback_label.size = Vector2(1368, 60)
	feedback_label.add_theme_font_size_override("font_size", 25)
	feedback_label.add_theme_color_override("font_color", PAPER)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feedback_label)
	tick = Timer.new()
	tick.wait_time = 0.24
	tick.timeout.connect(_advance_rain)
	add_child(tick)
	tick.start()
	refresh()

func _advance_rain():
	if state.motion and int(state.weather) > 0:
		rain_frame = (rain_frame + 1) % 3
		queue_redraw()

func tex(id, rect):
	if textures.has(id):
		draw_texture_rect(textures[id], rect, false)

func button(rect, label, active=false):
	draw_style_box(_button_style(active), rect)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(18, 43), label,
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 26, 23, PAPER)

func _button_style(active):
	var style = StyleBoxFlat.new()
	style.bg_color = Color("786440") if active else Color("263f49")
	style.border_color = GOLD if active else Color("8ba19a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style

func _draw():
	if textures.is_empty():
		return
	if view == "room":
		var backgrounds = ["office_arrival", "office_rain", "office_ominous"]
		tex(backgrounds[int(state.weather)], Rect2(Vector2.ZERO, SIZE))
		tex(map_progress.office_version, Rect2(145,196,227,251))
		tex("lamp_off", Rect2(242, 469, 192, 288))
		if state.supply_on and state.bridge_installed:
			tex("lamp_light", Rect2(242, 469, 192, 288))
		tex("spares_tray", Rect2(341, 666, 128, 64))
		if state.motion and int(state.weather) > 0:
			tex("rain_" + str(rain_frame), Rect2(Vector2.ZERO, SIZE))
		draw_rect(Rect2(20, 18, 1408, 85), Color(0.08, 0.15, 0.18, 0.94))
		button(Rect2(40, 30, 150, 64), "Arrival", state.weather == 0)
		button(Rect2(205, 30, 150, 64), "Tide III", state.weather == 1)
		button(Rect2(370, 30, 150, 64), "Tide VI", state.weather == 2)
		button(Rect2(535, 30, 175, 64), "Motion " + ("on" if state.motion else "off"))
		button(Rect2(725, 30, 160, 64), "Maps")
		button(Rect2(900, 30, 150, 64), "Notebook")
		button(Rect2(1065, 30, 145, 64), "Hint")
		button(Rect2(1225, 30, 165, 64), "Reset P01")
		button(Rect2(38, 922, 215, 64), "Chart Room")
	elif view == "repair":
		tex("repair_panel", Rect2(Vector2.ZERO, SIZE))
		tex("switch_on" if state.supply_on else "switch_off", Rect2(Vector2.ZERO, SIZE))
		if state.bridge_installed:
			tex("bridge_b_installed", Rect2(Vector2.ZERO, SIZE))
		else:
			tex("bridge_b", Rect2(106, 868, 240, 120))
		tex("bridge_c", Rect2(396, 868, 240, 120))
		if state.bridge_installed and state.supply_on:
			tex("indicator_on", Rect2(Vector2.ZERO, SIZE))
		if selected != "":
			var selection_rect = Rect2(88, 867, 278, 122) if selected == "B" else Rect2(376, 867, 278, 122)
			draw_rect(selection_rect, GOLD, false, 5)
		button(Rect2(1180, 75, 185, 64), "Back")
	elif view == "reset_confirm":
		draw_rect(Rect2(Vector2.ZERO, SIZE), INK)
		draw_string(ThemeDB.fallback_font, Vector2(260, 390), "Reset this preview's lamp puzzle?", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, PAPER)
		button(Rect2(400, 520, 260, 75), "Keep progress")
		button(Rect2(730, 520, 260, 75), "Reset puzzle")
	else:
		draw_rect(Rect2(Vector2.ZERO, SIZE), INK)
		var card_id = "chart_note" if view == "note" else "duty_card"
		tex(card_id, Rect2(244, 180, 960, 780))
		button(Rect2(1160, 75, 205, 64), "Back")
		button(Rect2(875, 75, 255, 64), "Map notebook")
	draw_rect(Rect2(20, 994, 1408, 80), Color(0.08, 0.15, 0.18, 0.97))

func _unhandled_input(event):
	if is_instance_valid(map_widget): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var p = get_global_mouse_position()
		var action = action_at(p)
		if action != "":
			dispatch(action)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		dispatch("back")
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M: dispatch("maps")
		elif event.keycode == KEY_C: dispatch("chart_room")
		elif event.keycode == KEY_N: dispatch("map_notes")

func action_at(p):
	if view == "room":
		var buttons = [[Rect2(40,30,150,64),"weather_0"],[Rect2(205,30,150,64),"weather_1"],
			[Rect2(370,30,150,64),"weather_2"],[Rect2(535,30,175,64),"motion"],
			[Rect2(725,30,160,64),"maps"],[Rect2(900,30,150,64),"notes"],
			[Rect2(1065,30,145,64),"hint"],[Rect2(1225,30,165,64),"reset"]]
		for entry in buttons:
			if entry[0].has_point(p):
				return entry[1]
		if Rect2(127,179,263,290).has_point(p): return "maps"
		if Rect2(38,922,215,64).has_point(p): return "chart_room"
		if Rect2(242,469,230,265).has_point(p): return "repair"
		if Rect2(726,625,180,110).has_point(p): return "duty"
		if Rect2(420,80,440,526).has_point(p): return "window"
		if Rect2(1016,280,184,650).has_point(p): return "coat"
		if Rect2(1189,124,258,780).has_point(p): return "door"
	elif view == "repair":
		if Rect2(1180,75,185,64).has_point(p): return "back"
		if Rect2(260,582,370,126).has_point(p): return "toggle_supply"
		if Rect2(250,435,415,132).has_point(p): return "fit"
		if Rect2(88,855,278,139).has_point(p): return "select_b"
		if Rect2(376,855,278,139).has_point(p): return "select_c"
	elif view == "reset_confirm":
		if Rect2(400,520,260,75).has_point(p): return "back"
		if Rect2(730,520,260,75).has_point(p): return "confirm_reset"
	else:
		if Rect2(1160,75,205,64).has_point(p): return "back"
		if Rect2(875,75,255,64).has_point(p): return "map_notes"
	return ""

func dispatch(action):
	match action:
		"maps": open_maps(map_progress.office_version)
		"map_notes": open_maps("journal")
		"chart_room":
			if state.p01_complete: open_maps("chart_room")
			else: feedback = "Restore the desk lamp to release the instrument-room latch."
		"repair":
			view = "repair"
			feedback = "Inspect the repair card. Select a spare, then tap the contact socket."
		"back":
			view = "room"
			feedback = "Lamp repaired. The chart and listening rooms are now available." if state.p01_complete else "Inventory the station. Begin with the desk lamp."
		"toggle_supply":
			state.supply_on = not state.supply_on
			feedback = "Supply OFF. It is safe to fit the bridge." if not state.supply_on else "Supply ON. The circuit is still open."
			if state.supply_on and state.bridge_installed:
				state.p01_complete = true
				feedback = "The lamp works. A pencil note is now preserved in the notebook."
		"select_b":
			if not state.bridge_installed:
				selected = "B"
				feedback = "Straight bridge B selected. Tap the socket to fit it."
			else:
				feedback = "Bridge B is already installed."
		"select_c":
			selected = "C"
			feedback = "Curved spare C selected. Compare its shape with the repair sketch."
		"fit":
			if state.bridge_installed:
				feedback = "The bridge is seated. Use the supply switch."
			elif state.supply_on:
				feedback = "Switch the supply OFF before fitting a part."
			elif selected == "B":
				state.bridge_installed = true
				selected = ""
				feedback = "Bridge B seated. Switch the supply ON to test the lamp."
			elif selected == "C":
				feedback = "The curved bridge does not match the straight contact seat."
			else:
				feedback = "Select a spare from the tray first."
		"duty": view = "duty"
		"notes":
			view = "note" if state.p01_complete else "duty"
			feedback = "The pencil note remains available after weather changes." if state.p01_complete else "The closure duty card is your first recorded observation."
		"hint":
			var hints = ["Look at the lamp and the spare parts beside it.", "The maintenance sketch specifies a straight bridge and an isolated supply.", "Open the lamp, switch OFF, select B, tap the socket, then switch ON."]
			feedback = hints[mini(hint_level,2)]
			hint_level += 1
		"motion": state.motion = not state.motion
		"window":
			feedback = ["The lighthouse is visible beyond the jetty.","Rain is erasing the coast.","The rain is visible. Why can I no longer hear it?"][int(state.weather)]
		"coat":
			feedback = "The coat hangs empty. Its shadow does not." if state.weather == 2 else "A wet coat. Nobody came to collect it."
		"door":
			feedback = "The service door remains locked until P06. P01 opens the instrument rooms elsewhere; those scenes are outside this asset preview."
		"reset": view = "reset_confirm"
		"confirm_reset":
			state.supply_on = true
			state.bridge_installed = false
			state.p01_complete = false
			selected = ""
			hint_level = 0
			view = "room"
			feedback = "Lamp puzzle reset. Weather review setting retained."
		_:
			if action.begins_with("weather_"):
				state.weather = clampi(int(action.trim_prefix("weather_")),0,2)
				feedback = "Art review only: this weather selector does not advance the story."
	save_progress()
	refresh()

func refresh():
	if is_instance_valid(feedback_label):
		feedback_label.text = feedback
	queue_redraw()

func save_progress():
	state["maps"] = map_progress.snapshot()
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state))
	else:
		feedback = "Progress could not be saved. Keep this session open."

func load_progress():
	if not FileAccess.file_exists(save_path): return
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file: return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("schema",0) != 1: return
	for key in ["supply_on","bridge_installed","p01_complete","motion"]:
		if parsed.get(key) is bool: state[key] = parsed[key]
	state.weather = clampi(int(parsed.get("weather",0)),0,2)
	map_progress.restore(parsed.get("maps",{}))
	if state.p01_complete: state.bridge_installed = true
	if state.p01_complete: feedback = "Welcome back. The lamp repair and pencil note are saved."

func open_maps(initial_mode: String):
	if is_instance_valid(map_widget): return
	map_widget = MapWorkbench.new()
	map_widget.progress = map_progress
	map_widget.unlocked = state.p01_complete
	map_widget.mode = initial_mode
	map_widget.changed.connect(save_progress)
	map_widget.closed.connect(func():
		var previous = map_widget
		map_widget = null
		previous.queue_free()
		save_progress()
		refresh())
	add_child(map_widget)
