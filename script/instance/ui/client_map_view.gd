extends Control

signal city_build_requested(city_id)

var _map_definition = null
var _public_state = {}
var _canvas = null
var _inspect_label = null
var _build_button = null
var _selected_city_id = ""
var _camera_offset = Vector2(40, 40)
var _camera_zoom = 1.0
var _touch_points = {}
var _last_pinch_distance = 0.0
var _mouse_dragging = false
var _last_mouse_position = Vector2.ZERO

func _ready():
	clip_contents = true

	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	var zoom_controls = HBoxContainer.new()
	zoom_controls.position = Vector2(12, 12)
	zoom_controls.add_theme_constant_override("separation", 8)
	add_child(zoom_controls)

	var zoom_in_button = VW.Chrome.styled_button("+", 18)
	zoom_in_button.custom_minimum_size = Vector2(48, 44)
	zoom_in_button.pressed.connect(func(): _set_zoom(_camera_zoom + 0.2))
	zoom_controls.add_child(zoom_in_button)

	var zoom_out_button = VW.Chrome.styled_button("-", 18)
	zoom_out_button.custom_minimum_size = Vector2(48, 44)
	zoom_out_button.pressed.connect(func(): _set_zoom(_camera_zoom - 0.2))
	zoom_controls.add_child(zoom_out_button)

	var reset_button = VW.Chrome.styled_button("Reset", 14)
	reset_button.custom_minimum_size = Vector2(76, 44)
	reset_button.pressed.connect(_reset_camera)
	zoom_controls.add_child(reset_button)

	var bottom_bar = VW.Chrome.panel_container(Vector2(0, 74), Color(0.10, 0.12, 0.17, 0.95), Color(0.85, 0.68, 0.25, 0.9))
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -78
	add_child(bottom_bar)

	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	bottom_bar.add_child(bottom_row)

	_inspect_label = Label.new()
	_inspect_label.text = "Drag to pan, pinch or +/- to zoom. Tap any city to inspect."
	_inspect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_row.add_child(_inspect_label)

	_build_button = VW.Chrome.styled_button("Build Here", 15)
	_build_button.custom_minimum_size = Vector2(120, 42)
	_build_button.visible = false
	_build_button.pressed.connect(func():
		if _selected_city_id != "":
			city_build_requested.emit(_selected_city_id)
	)
	bottom_row.add_child(_build_button)

func update_state(public_state):
	_public_state = public_state
	var map_id = str(public_state.get("map_id", "sample_map"))
	_map_definition = VW.Database.get_map(map_id)
	_rebuild_cities()
	queue_redraw()

func _reset_camera():
	_camera_offset = Vector2(40, 64)
	_camera_zoom = 1.0
	_apply_transform()

func _set_zoom(next_zoom):
	_camera_zoom = clamp(next_zoom, 0.45, 2.5)
	_apply_transform()

func _apply_transform():
	if _canvas != null:
		_canvas.position = _camera_offset
		_canvas.scale = Vector2(_camera_zoom, _camera_zoom)
	queue_redraw()

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
			_last_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		_touch_points[event.index] = event.position
		if _touch_points.size() == 1:
			_camera_offset += event.relative
			_apply_transform()
		elif _touch_points.size() >= 2:
			var keys = _touch_points.keys()
			var current_distance = _touch_points[keys[0]].distance_to(_touch_points[keys[1]])
			if _last_pinch_distance > 0.0:
				var ratio = current_distance / _last_pinch_distance
				_set_zoom(_camera_zoom * ratio)
			_last_pinch_distance = current_distance
	elif event is InputEventMagnifyGesture:
		_set_zoom(_camera_zoom * event.factor)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(_camera_zoom + 0.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(_camera_zoom - 0.12)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_dragging = event.pressed
			_last_mouse_position = event.position
	elif event is InputEventMouseMotion and _mouse_dragging:
		_camera_offset += event.position - _last_mouse_position
		_last_mouse_position = event.position
		_apply_transform()

func _rebuild_cities():
	for child in _canvas.get_children():
		child.queue_free()
	if _map_definition == null:
		return

	var active_regions = _public_state.get("active_regions", [])
	var occupancy = _public_state.get("city_occupancy", {})
	var players = _public_state.get("players", [])

	var show_inactive = VW.Settings != null and VW.Settings.show_inactive_regions()
	for city_id in _map_definition.cities.keys():
		var city = _map_definition.cities[city_id]
		var region_active = active_regions.is_empty() or active_regions.has(city.region_id)
		if not region_active and not show_inactive:
			continue
		var region_info = _map_definition.regions.get(city.region_id, {})
		var region_color = Color.html(str(region_info.get("color", "#4a6fa5")))
		var button = VW.Chrome.styled_button(city.name, 13)
		button.custom_minimum_size = Vector2(114, 46)
		button.position = city.position - Vector2(57, 23)
		button.modulate = Color(1, 1, 1, 1.0 if region_active else 0.45)
		button.add_theme_color_override("font_color", region_color.lightened(0.35) if region_active else Color(0.55, 0.58, 0.62))
		button.pressed.connect(_on_city_tapped.bind(city_id))
		_canvas.add_child(button)

		var occupants = occupancy.get(city_id, [])
		for slot_index in range(occupants.size()):
			var seat_index = int(occupants[slot_index])
			if seat_index >= 0 and seat_index < players.size():
				var house = TextureRect.new()
				house.texture = VW.Assets.get_house_texture(players[seat_index].color)
				house.position = Vector2(8 + slot_index * 26, -24)
				house.mouse_filter = Control.MOUSE_FILTER_IGNORE
				button.add_child(house)

	_apply_transform()

func _on_city_tapped(city_id):
	_selected_city_id = city_id
	if _map_definition == null:
		return
	var city = _map_definition.cities.get(city_id, null)
	if city == null:
		return
	var occupancy = _public_state.get("city_occupancy", {}).get(city_id, [])
	var step = int(_public_state.get("step", 1))
	var next_cost = "Full" if occupancy.size() >= step else (str(10 + occupancy.size() * 5) + "E")
	_inspect_label.text = city.name + " (" + str(city.region_id).capitalize() + ") | Next Slot: " + next_cost + " | Built: " + str(occupancy.size()) + "/" + str(step)
	var phase = int(_public_state.get("phase", 1))
	_build_button.visible = (phase == 4 and occupancy.size() < step)

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.08, 0.11, 1.0))
	if _map_definition == null:
		return
	var base_texture = VW.Assets.get_map_base_texture(_map_definition.id)
	if base_texture != null:
		draw_texture_rect(base_texture, Rect2(_camera_offset, base_texture.get_size() * _camera_zoom), false)
	var badge_texture = VW.Assets.get_token_texture("connection_badge")
	var active_regions = _public_state.get("active_regions", [])
	var show_inactive = VW.Settings != null and VW.Settings.show_inactive_regions()
	for edge in _map_definition.connections:
		var source_city = _map_definition.cities.get(edge.from, null)
		var target_city = _map_definition.cities.get(edge.to, null)
		if source_city == null or target_city == null:
			continue
		var both_active = active_regions.is_empty() or (active_regions.has(source_city.region_id) and active_regions.has(target_city.region_id))
		if not both_active and not show_inactive:
			continue
		var start_pos = source_city.position * _camera_zoom + _camera_offset
		var end_pos = target_city.position * _camera_zoom + _camera_offset
		var line_color = Color(0.45, 0.54, 0.68, 0.85) if both_active else Color(0.28, 0.32, 0.38, 0.35)
		draw_line(start_pos, end_pos, line_color, 3.0)
		var midpoint = (start_pos + end_pos) * 0.5
		var badge_radius = 17.0 * _camera_zoom
		var cost_font_size = max(10, int(round(13.0 * _camera_zoom)))
		if badge_texture != null:
			draw_texture_rect(badge_texture, Rect2(midpoint - Vector2(badge_radius, badge_radius), Vector2(badge_radius * 2.0, badge_radius * 2.0)), false)
		else:
			draw_circle(midpoint, badge_radius, Color(0.12, 0.15, 0.21, 0.95))
		draw_string(ThemeDB.fallback_font, midpoint + Vector2(-badge_radius, cost_font_size * 0.38), str(edge.cost), HORIZONTAL_ALIGNMENT_CENTER, badge_radius * 2.0, cost_font_size, Color(0.96, 0.82, 0.35))
