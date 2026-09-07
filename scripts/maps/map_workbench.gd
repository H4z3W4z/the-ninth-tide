extends Control
## A reusable inspection/puzzle panel hosted by the asset preview.
## Room transitions, inventory and production saves remain the adventure engine's job.
signal closed
signal changed
const Viewer = preload("res://scripts/maps/map_viewer.gd")
const INK = Color("172b36")
const PAPER = Color("ded4ba")
const GOLD = Color("d2aa66")
var progress
var unlocked = false
var mode = "office_survey"
var viewer
var message = "Select a map to inspect its survey marks and annotations."
var buttons = {}
var status: Label
const TITLES = {"office_survey":"Greywake Sound / coastal survey", "office_survey_shifted":"Greywake Sound / altered survey", "tide_reference_17":"Interval reference / 17 October", "tide_sheet":"Restored tide survey", "composite":"Preserved composite / interval 3", "tide_example":"Reading the transect"}
const TRANSCRIPTS = {
	"office_survey":"Greywake Sound. Coastal survey, 1924. The lighthouse stands north-west of the station. Shoals: keep west of the bell. Venn: soundings checked twice.",
	"office_survey_shifted":"The same dated survey now places the lighthouse east of its earlier position. The old observed survey remains in the notebook. Its annotations have not changed.",
	"tide_reference_17":"17 October 1924. North points upward. A cross registers the lighthouse. Four bands numbered 1 to 4 run from top to bottom beside a dashed transect. Align with the survey, then read the band where its red trace crosses that transect.",
	"tide_sheet":"17 October 1924. North points upward. Coastline above, shoal contours through the middle, soundings below. Lighthouse, survey-post and sounding-buoy crosses are distinct registration locations. Compare against a reference with the same date and north direction.",
	"composite":"17 October 1924. The lighthouse crosses, north arrows and dates match. The red observed trace crosses the dashed transect in interval band 3. Calibration interval: 3. The recording's zero is still a separate observation.",
	"tide_example":"Match the cross, north arrow and date. Read the interval band at the trace's crossing of the marked transect. In this unrelated worked example, bands are 6 and 7 and the crossing reads 6."
}

func _ready():
	size = Vector2(1448,1086)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme = Theme.new()
	theme.default_font_size = 24
	for type in ["normal","hover","pressed","focus","disabled"]:
		var box = StyleBoxFlat.new()
		box.bg_color = Color("344f58") if type != "pressed" else Color("705b39")
		box.border_color = GOLD if type == "focus" else Color("738d89")
		box.set_border_width_all(4 if type == "focus" else 2)
		box.set_corner_radius_all(5)
		theme.set_stylebox(type,"Button",box)
	theme.set_color("font_color","Button",PAPER)
	theme.set_color("font_disabled_color","Button",Color("8ca09e"))
	self.theme = theme
	show_mode(mode)

func texture(id: String) -> Texture2D:
	return load("res://assets/maps/"+id+".png")

func _panel(rect: Rect2, color: Color):
	var panel = ColorRect.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.color = color
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel

func _label(value: String, rect: Rect2, font_size=24) -> Label:
	var label = Label.new()
	# Set wrapping before text/size so an unwrapped minimum cannot expand the panel.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = value
	label.position = rect.position
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",PAPER)
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _button(id: String, title: String, rect: Rect2, action: Callable, enabled=true) -> Button:
	var button = Button.new()
	button.name = id
	button.position = rect.position
	button.size = rect.size
	button.text = title
	button.disabled = not enabled
	button.pressed.connect(action)
	add_child(button)
	buttons[id] = button
	return button

func _image(tex: Texture2D, rect: Rect2):
	var image = TextureRect.new()
	# Ignore the source image's minimum size before assigning its display rectangle.
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = tex
	image.position = rect.position
	image.size = rect.size
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	return image

func show_mode(next_mode: String):
	if next_mode in ["chart_room","assemble","compare"] and not unlocked:
		message = "Restore the desk lamp to release the instrument-room latch."
		return
	if next_mode == "compare" and not progress.assembled():
		message = "First recover and assemble the torn tide sheet."
		return
	mode = next_mode
	for child in get_children():
		remove_child(child)
		child.queue_free()
	buttons.clear()
	viewer = null
	_panel(Rect2(0,0,1448,1086),INK)
	_button("close","Back to office",Rect2(30,24,240,64),func(): closed.emit())
	_button("office","Coastal map",Rect2(286,24,240,64),func(): show_mode(progress.office_version))
	_button("charts","Chart Room",Rect2(542,24,230,64),func(): show_mode("chart_room"),unlocked)
	_button("journal","Map notebook",Rect2(788,24,260,64),func(): show_mode("journal"))
	_label("THE NINTH TIDE",Rect2(1090,40,330,44),24)
	if mode == "chart_room": _room()
	elif mode == "assemble": _assembly()
	elif mode == "journal": _journal()
	else: _inspect()
	_panel(Rect2(24,962,1400,102),Color("263f49"))
	status = _label(message,Rect2(44,977,1360,78),25)
	buttons.close.grab_focus()

func _persist():
	changed.emit()
	if is_instance_valid(status): status.text = message

func _room():
	_label("Chart Room / the missing curve",Rect2(30,105,1020,45),30)
	_image(load("res://assets/backgrounds/chart_arrival.png"),Rect2(30,158,985,739))
	# Authored map faces cover the concept's decorative charts.
	_image(texture("tide_sheet" if progress.assembled() else "tide_fragment_0"),Rect2(418,253,231,177))
	_image(texture("tide_reference_17"),Rect2(610,283,139,164))
	_button("board","Torn chart",Rect2(394,194,220,64),func():
		progress.acquire(0)
		message = "A coastline fragment remains under the board's clip."
		_persist()
		show_mode("assemble"))
	_button("reference","Reference",Rect2(647,194,210,64),func(): show_mode("tide_reference_17"))
	_button("drawer","Chart drawer",Rect2(462,681,240,64),func(): _collect(1))
	_button("weight","Paper / weight",Rect2(592,556,250,64),func(): _collect(2))
	_label("THE PEN HAS NOT STOPPED",Rect2(1050,165,345,80),25)
	_label("The drum is still.\n\nA torn sheet is clipped to the board. Its other edges may survive among the station's papers.\n\nTouch either map to examine it.",Rect2(1050,255,345,310),25)
	_button("assemble","Assemble sheet",Rect2(1050,600,345,64),func(): show_mode("assemble"))
	_button("compare","Compare charts",Rect2(1050,680,345,64),func(): show_mode("compare"),progress.assembled())
	_button("guide","Reading guide",Rect2(1050,760,345,64),func(): show_mode("tide_example"))
	if progress.complete: message = "Interval 3 is preserved. The recording must supply the separate zero reference."

func _collect(index: int):
	if progress.acquired[index]:
		message = "The drawer is empty; its fragment is in your folio." if index == 1 else "The paper beneath the weight is already in your folio."
	else:
		progress.acquire(index)
		message = "Recovered the shoal fragment from the unlocked drawer." if index == 1 else "Recovered the soundings fragment from beneath the weight."
	_persist()

func _assembly():
	_label("Reconstruct the tide sheet",Rect2(30,108,950,44),32)
	_panel(Rect2(40,168,960,760),Color("4a5954"))
	_label("Match torn edges and continuing contour lines.",Rect2(63,178,910,50),23)
	for i in range(3):
		var slot = Rect2(74,239+i*213,890,205)
		_panel(slot,Color("adab90"))
		var target = _button("slot"+str(i),"Place here",slot,func(): _place(i),not progress.placed[i])
		if progress.placed[i]:
			var atlas = AtlasTexture.new()
			atlas.atlas = texture("tide_fragment_"+str(i))
			atlas.region = Rect2(0,maxi(0,i*300-25),1200,350 if i == 1 else 325)
			_image(atlas,slot)
			target.text = ""
	if progress.assembled(): _image(texture("tide_sheet"),Rect2(74,239,890,668))
	_label("RECOVERED FRAGMENTS",Rect2(1050,168,355,48),25)
	for i in range(3):
		var title = ["Coastline","Shoal","Soundings"][i]
		if progress.placed[i]: title += " / seated"
		elif not progress.acquired[i]: title += " / missing"
		elif progress.selected == i: title += " / selected"
		_button("piece"+str(i),title,Rect2(1050,230+i*78,345,64),func():
			progress.select_piece(i)
			message = "Rotate the selected fragment to match the sheet, then tap its board position."
			_persist()
			show_mode("assemble"),progress.acquired[i] and not progress.placed[i])
	if progress.selected >= 0:
		var atlas = AtlasTexture.new()
		atlas.atlas = texture("tide_fragment_"+str(progress.selected))
		atlas.region = Rect2(0,maxi(0,progress.selected*300-25),1200,350 if progress.selected == 1 else 325)
		var image = _image(atlas,Rect2(1100,508,245,85))
		image.pivot_offset = image.size/2.0
		image.rotation = progress.rotation_step*PI/2.0
	_button("rotate","Rotate 90 degrees",Rect2(1050,680,345,64),func():
		progress.rotation_step = (progress.rotation_step+1)%4
		_persist()
		show_mode("assemble")
		buttons.rotate.grab_focus(),progress.selected >= 0)
	_button("compare","Compare charts",Rect2(1050,760,345,64),func(): show_mode("compare"),progress.assembled())
	if progress.assembled():
		_button("restored","Inspect restored map",Rect2(1050,840,345,64),func(): show_mode("tide_sheet"))
	else:
		_button("hint","Hint",Rect2(1050,840,345,64),func():
			message = "Check the board, drawer and chart weight. Fit coastline above shoal above soundings, with north upward."
			_persist())

func _place(slot: int):
	message = progress.place(slot)
	_persist()
	show_mode("assemble")
	buttons["slot"+str(slot)].grab_focus()

func _inspect():
	var id = "tide_sheet" if mode == "compare" else mode
	if id == "composite" and not progress.complete:
		show_mode("journal")
		return
	if id == "tide_sheet" and not progress.assembled():
		show_mode("assemble")
		return
	_label("Align the two surveys" if mode == "compare" else TITLES.get(id,id),Rect2(30,105,1000,44),30)
	_panel(Rect2(30,163,985,730),Color("4a5954"))
	viewer = Viewer.new()
	viewer.position = Vector2(40,173)
	viewer.size = Vector2(965,710)
	add_child(viewer)
	viewer.show_map(texture("tide_sheet" if id == "composite" else id),texture("tide_reference_17") if id == "composite" else null)
	progress.observe(id)
	_persist()
	_button("zoom_out","-",Rect2(35,896,88,64),func(): viewer.zoom_at(1.0/1.3,viewer.size/2.0))
	_button("zoom_in","+",Rect2(135,896,88,64),func(): viewer.zoom_at(1.3,viewer.size/2.0))
	_button("fit","Fit",Rect2(235,896,130,64),func(): viewer.fit())
	for i in range(4):
		var directions = [Vector2(120,0),Vector2(-120,0),Vector2(0,120),Vector2(0,-120)]
		_button("pan"+str(i),["Left","Right","Up","Down"][i],Rect2(380+i*158,896,148,64),func(): viewer.pan(directions[i]))
	if mode == "compare":
		_update_reference()
		_label("REGISTRATION",Rect2(1050,164,350,45),25)
		_button("anchor",["Lighthouse cross","Survey-post cross","Sounding-buoy cross"][progress.anchor],Rect2(1050,222,345,64),func():
			progress.anchor = (progress.anchor+1)%3
			_persist()
			show_mode("compare")
			buttons.anchor.grab_focus(),not progress.complete)
		_button("north","Rotate reference 90",Rect2(1050,302,345,64),func():
			progress.north_step = (progress.north_step+1)%4
			_persist()
			show_mode("compare")
			buttons.north.grab_focus(),not progress.complete)
		_button("date","Date: "+str(progress.reference_day)+" October",Rect2(1050,382,345,64),func():
			progress.reference_day = 17 if progress.reference_day == 16 else 16
			_persist()
			show_mode("compare")
			buttons.date.grab_focus(),not progress.complete)
		_button("clip","Clip aligned sheets",Rect2(1050,462,345,64),func():
			message = progress.compare()
			_persist()
			show_mode("compare"),not progress.complete)
		_label("Match the printed lighthouse cross, north direction and date. Read the band at the red trace's crossing of the dashed transect.",Rect2(1050,550,345,230),25)
		_button("guide","Reading guide",Rect2(1050,814,345,64),func(): show_mode("tide_example"))
	else:
		_label("SURVEY TRANSCRIPT",Rect2(1050,164,350,45),25)
		_label(TRANSCRIPTS.get(id,""),Rect2(1050,230,345,490),25)
		_label("Pinch or use + / -.\nDrag or use pan buttons.\nKeyboard: arrows, + / -, Home.\nEscape returns to the office.",Rect2(1050,745,345,185),23)
	if id == "composite" or (mode == "compare" and progress.complete):
		message = TRANSCRIPTS.composite

func _update_reference():
	var delta = [Vector2.ZERO,Vector2(230,410),Vector2(485,-5)][progress.anchor]
	viewer.set_reference(texture("tide_reference_"+str(progress.reference_day)),delta,progress.north_step)

func _journal():
	_label("Map notebook / preserved observations",Rect2(40,132,1100,50),32)
	_label("Earlier surveys remain available when the station changes.",Rect2(40,198,1300,50),25)
	for i in range(progress.observed.size()):
		var id = progress.observed[i]
		_button("record"+str(i),TITLES.get(id,id),Rect2(60,270+i*88,940,70),func(): show_mode(id))
	if progress.observed.is_empty():
		_label("No maps examined yet. The office survey is available from the opening.",Rect2(60,280,1200,90),27)
	_label("P03 complete / interval 3" if progress.complete else "P03 interval not yet established",Rect2(60,883,1200,60),27)

func _unhandled_key_input(event):
	if event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()
