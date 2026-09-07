extends Control
## Zoomable, clipped image surface shared by every map. No story or save logic.
var sheet: TextureRect
var overlay: TextureRect
var zoom = 1.0
var offset = Vector2.ZERO
var page_size = Vector2(1200,900)
var touches = {}
var overlay_offset = Vector2.ZERO
var overlay_quarters = 0

func _ready():
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	sheet = TextureRect.new()
	overlay = TextureRect.new()
	for node in [sheet,overlay]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(node)
	resized.connect(_layout)

func show_map(texture: Texture2D, reference: Texture2D = null):
	sheet.texture = texture
	overlay.texture = reference
	overlay.visible = reference != null
	page_size = texture.get_size()
	fit()

func fit():
	zoom = 1.0
	offset = Vector2.ZERO
	_layout()

func zoom_at(factor: float, point: Vector2):
	var old_zoom = zoom
	zoom = clampf(zoom * factor,1.0,4.0)
	offset = (offset - (point-size/2.0)) * (zoom/old_zoom) + point-size/2.0
	_layout()

func pan(delta: Vector2):
	offset += delta
	_layout()

func set_reference(texture: Texture2D, delta: Vector2, quarters: int):
	overlay.texture = texture
	overlay.visible = texture != null
	overlay_offset = delta
	overlay_quarters = quarters
	_layout()

func _layout():
	if not is_instance_valid(sheet): return
	var scale_factor = minf(size.x/page_size.x,size.y/page_size.y)*zoom
	var extent = page_size*scale_factor
	var limits = ((extent-size)/2.0).max(Vector2.ZERO)
	offset = offset.clamp(-limits,limits)
	sheet.size = extent
	sheet.position = (size-extent)/2.0+offset
	overlay.size = extent
	overlay.pivot_offset = extent/2.0
	overlay.position = sheet.position+overlay_offset*scale_factor
	overlay.rotation = overlay_quarters*PI/2.0

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed: grab_focus()
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_at(1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.2,event.position)
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT and touches.is_empty():
		pan(event.relative)
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed: touches[event.index] = event.position
		else: touches.erase(event.index)
		accept_event()
	elif event is InputEventScreenDrag and touches.has(event.index):
		if touches.size() == 2:
			var other = touches.keys().filter(func(key): return key != event.index)[0]
			var previous_distance = touches[event.index].distance_to(touches[other])
			var next_distance = event.position.distance_to(touches[other])
			if previous_distance > 8: zoom_at(next_distance/previous_distance,(event.position+touches[other])/2.0)
		else: pan(event.relative)
		touches[event.index] = event.position
		accept_event()
	elif event is InputEventMagnifyGesture:
		zoom_at(event.factor,event.position)
		accept_event()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_PLUS,KEY_EQUAL,KEY_KP_ADD: zoom_at(1.2,size/2.0)
			KEY_MINUS,KEY_KP_SUBTRACT: zoom_at(1.0/1.2,size/2.0)
			KEY_LEFT: pan(Vector2(90,0))
			KEY_RIGHT: pan(Vector2(-90,0))
			KEY_UP: pan(Vector2(0,90))
			KEY_DOWN: pan(Vector2(0,-90))
			KEY_HOME: fit()
			_: return
		accept_event()
