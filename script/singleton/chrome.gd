extends Node

signal input_mode_changed(gamepad_active)

const JOY_MOTION_THRESHOLD = 0.35

var hidden_button_style = null
var _gamepad_active = false

func is_gamepad_active():
	return _gamepad_active

func set_gamepad_active(active):
	var next_state = bool(active)
	if _gamepad_active == next_state:
		return
	_gamepad_active = next_state
	input_mode_changed.emit(_gamepad_active)

func _input(event):
	if event is InputEventJoypadButton and event.pressed:
		set_gamepad_active(true)
	elif event is InputEventJoypadMotion and abs(event.axis_value) >= JOY_MOTION_THRESHOLD:
		set_gamepad_active(true)
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		set_gamepad_active(false)

func attach_focus_ring(control):
	if control == null or not is_instance_valid(control):
		return control
	if control.focus_mode == Control.FOCUS_NONE:
		control.focus_mode = Control.FOCUS_ALL
	if control.has_node("_FocusRing"):
		return control
	var ring = ReferenceRect.new()
	ring.name = "_FocusRing"
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.border_color = Color(1.0, 0.85, 0.30, 0.95)
	ring.border_width = 3.0
	ring.editor_only = false
	ring.visible = control.has_focus() and _gamepad_active
	control.add_child(ring)
	var update_ring = func():
		if is_instance_valid(ring) and is_instance_valid(control):
			ring.visible = _gamepad_active and control.has_focus()
	control.focus_entered.connect(update_ring)
	control.focus_exited.connect(update_ring)
	var mode_handler = func(_active): update_ring.call()
	input_mode_changed.connect(mode_handler)
	control.tree_exited.connect(func():
		if input_mode_changed.is_connected(mode_handler):
			input_mode_changed.disconnect(mode_handler)
	)
	return control

func panel_container(minimum_size = Vector2(420, 260), background_color = Color(0.11, 0.13, 0.18, 0.95), border_color = Color(0.85, 0.68, 0.25, 0.95)):
	var panel = PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = background_color
	style_box.border_color = border_color
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(6)
	style_box.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style_box)
	return panel

func invisible_button():
	var node = Button.new()
	if hidden_button_style == null:
		hidden_button_style = StyleBoxFlat.new()
		hidden_button_style.bg_color = Color(0, 0, 0, 0)
	node.add_theme_stylebox_override("normal", hidden_button_style)
	node.add_theme_stylebox_override("hover", hidden_button_style)
	node.add_theme_stylebox_override("focus", hidden_button_style)
	node.add_theme_stylebox_override("pressed", hidden_button_style)
	node.add_theme_stylebox_override("disabled", hidden_button_style)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	attach_focus_ring(node)
	return node

func styled_button(text_value, font_size = 18):
	var button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(160, 42)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", font_size)
	var normal_box = StyleBoxFlat.new()
	normal_box.bg_color = Color(0.18, 0.22, 0.30, 1.0)
	normal_box.border_color = Color(0.85, 0.68, 0.25, 0.9)
	normal_box.set_border_width_all(2)
	normal_box.set_corner_radius_all(4)
	normal_box.content_margin_left = 18
	normal_box.content_margin_right = 18
	normal_box.content_margin_top = 8
	normal_box.content_margin_bottom = 8
	var hover_box = normal_box.duplicate()
	hover_box.bg_color = Color(0.24, 0.29, 0.39, 1.0)
	var pressed_box = normal_box.duplicate()
	pressed_box.bg_color = Color(0.13, 0.16, 0.22, 1.0)
	button.add_theme_stylebox_override("normal", normal_box)
	button.add_theme_stylebox_override("hover", hover_box)
	button.add_theme_stylebox_override("pressed", pressed_box)
	button.add_theme_stylebox_override("focus", hover_box)
	attach_focus_ring(button)
	return button
