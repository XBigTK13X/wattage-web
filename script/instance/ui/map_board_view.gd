extends Control

signal city_selected(city_id)

var _map_definition = null
var _game_state = null
var _canvas = null
var _tooltip_label = null
var _camera_offset = Vector2(40, 40)
var _camera_zoom = 1.0
var _dragging = false
var _last_drag_position = Vector2.ZERO
var _city_buttons = {}

func _ready():
	clip_contents = true
	focus_mode = Control.FOCUS_ALL

	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	_tooltip_label = Label.new()
	_tooltip_label.position = Vector2(12, 12)
	_tooltip_label.add_theme_color_override("font_color", Color(0.96, 0.85, 0.45))
	add_child(_tooltip_label)

func set_state(map_definition, game_state):
	_map_definition = map_definition
	_game_state = game_state
	_rebuild_nodes()
	queue_redraw()

func _process(delta):
	var pan_speed = 360.0 * delta
	var moved = false
	if Input.is_action_pressed("pan_left"):
		_camera_offset.x += pan_speed
		moved = true
	if Input.is_action_pressed("pan_right"):
		_camera_offset.x -= pan_speed
		moved = true
	if Input.is_action_pressed("pan_up"):
		_camera_offset.y += pan_speed
		moved = true
	if Input.is_action_pressed("pan_down"):
		_camera_offset.y -= pan_speed
		moved = true
	if Input.is_action_just_pressed("zoom_in"):
		_set_zoom(_camera_zoom + 0.12)
	if Input.is_action_just_pressed("zoom_out"):
		_set_zoom(_camera_zoom - 0.12)
	if moved:
		_apply_transform()

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(_camera_zoom + 0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(_camera_zoom - 0.1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			_last_drag_position = event.position
	elif event is InputEventMouseMotion and _dragging:
		_camera_offset += event.position - _last_drag_position
		_last_drag_position = event.position
		_apply_transform()

func _set_zoom(next_zoom):
	_camera_zoom = clamp(next_zoom, 0.5, 2.2)
	_apply_transform()

func _apply_transform():
	if _canvas != null:
		_canvas.position = _camera_offset
		_canvas.scale = Vector2(_camera_zoom, _camera_zoom)
	queue_redraw()

func _rebuild_nodes():
	for child in _canvas.get_children():
		child.queue_free()
	_city_buttons.clear()
	if _map_definition == null or _game_state == null:
		return

	var active_regions = _game_state.get("active_regions", [])
	var occupancy = _game_state.get("city_occupancy", {})
	var players = _game_state.get("players", [])
	var current_phase = int(_game_state.get("phase", 1))
	var step = int(_game_state.get("step", 1))

	for city_id in _map_definition.cities.keys():
		var city = _map_definition.cities[city_id]
		var region_active = active_regions.has(city.region_id)
		var region_info = _map_definition.regions.get(city.region_id, {})
		var region_color = Color.html(str(region_info.get("color", "#4a6fa5")))
		if not region_active:
			region_color = Color(0.25, 0.27, 0.30, 0.5)

		var occupants = occupancy.get(city_id, [])
		var is_buildable = region_active and current_phase == 4 and occupants.size() < step
		var border_color = Color(0.35, 0.92, 0.45) if is_buildable else region_color

		var button = VW.Chrome.styled_button(city.name, 13)
		button.custom_minimum_size = Vector2(118, 48)
		button.position = city.position - Vector2(59, 24)
		button.modulate = Color(1, 1, 1, 1.0 if region_active else 0.45)
		button.add_theme_color_override("font_color", border_color.lightened(0.35))
		button.pressed.connect(func(): city_selected.emit(city_id))
		button.mouse_entered.connect(_on_city_focused.bind(city_id))
		button.focus_entered.connect(_on_city_focused.bind(city_id))
		_canvas.add_child(button)
		_city_buttons[city_id] = button

		for slot_index in range(occupants.size()):
			var seat_index = int(occupants[slot_index])
			if seat_index >= 0 and seat_index < players.size():
				var house = TextureRect.new()
				house.texture = VW.Assets.get_house_texture(players[seat_index].color)
				house.position = Vector2(8 + slot_index * 26, -24)
				house.mouse_filter = Control.MOUSE_FILTER_IGNORE
				button.add_child(house)

	_apply_transform()

func _on_city_focused(city_id):
	if _map_definition == null or _game_state == null:
		return
	var city = _map_definition.cities.get(city_id, null)
	if city == null:
		return
	var occupancy = _game_state.get("city_occupancy", {}).get(city_id, [])
	var step = int(_game_state.get("step", 1))
	var slot_cost_text = "Full"
	if occupancy.size() < step:
		slot_cost_text = str(10 + occupancy.size() * 5) + " Elektro"
	_tooltip_label.text = city.name + " (" + str(city.region_id).capitalize() + ") | Next slot: " + slot_cost_text

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.12, 1.0))
	if _map_definition == null:
		return
	for edge in _map_definition.connections:
		var source_city = _map_definition.cities.get(edge.from, null)
		var target_city = _map_definition.cities.get(edge.to, null)
		if source_city == null or target_city == null:
			continue
		var start_pos = source_city.position * _camera_zoom + _camera_offset
		var end_pos = target_city.position * _camera_zoom + _camera_offset
		draw_line(start_pos, end_pos, Color(0.45, 0.54, 0.68, 0.85), 3.0)
		var midpoint = (start_pos + end_pos) * 0.5
		draw_circle(midpoint, 12.0 * _camera_zoom, Color(0.12, 0.15, 0.21, 0.95))
		draw_string(ThemeDB.fallback_font, midpoint + Vector2(-8, 5), str(edge.cost), HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(0.96, 0.82, 0.35))
