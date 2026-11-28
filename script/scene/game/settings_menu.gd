extends Control

static func init_container():
	return Control.new()

var _keybind_buttons = {}
var _gamepad_buttons = {}
var _keybinds = {}
var _gamepad_binds = {}
var _listening_action = null
var _listening_mode = ""

func _add_volume_slider(layout, label_prefix, setting_key, initial_percent):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	layout.add_child(row)

	var volume_label = Label.new()
	volume_label.text = label_prefix
	volume_label.custom_minimum_size = Vector2(200, 0)
	row.add_child(volume_label)

	var volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 5
	volume_slider.value = initial_percent
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	VW.Chrome.attach_focus_ring(volume_slider)
	row.add_child(volume_slider)

	var value_label = Label.new()
	value_label.text = str(initial_percent) + "%"
	value_label.custom_minimum_size = Vector2(56, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	volume_slider.value_changed.connect(func(value):
		var rounded = int(value)
		VW.Settings.change("game", setting_key, rounded)
		VW.Audio.apply_volume_settings()
		value_label.text = str(rounded) + "%"
	)

func _keyboard_label(key_code):
	if int(key_code) < 0:
		return "Unbound"
	return OS.get_keycode_string(int(key_code))

func _refresh_binding_buttons():
	for action_name in _keybind_buttons.keys():
		_keybind_buttons[action_name].text = _keyboard_label(_keybinds.get(action_name, -1))
	for action_name in _gamepad_buttons.keys():
		_gamepad_buttons[action_name].text = VW.Settings.gamepad_button_name(_gamepad_binds.get(action_name, -1))

func _restore_listening_button_text():
	if _listening_action == null:
		return
	if _listening_mode == "gamepad" and _gamepad_buttons.has(_listening_action):
		_gamepad_buttons[_listening_action].text = VW.Settings.gamepad_button_name(_gamepad_binds.get(_listening_action, -1))
	elif _keybind_buttons.has(_listening_action):
		_keybind_buttons[_listening_action].text = _keyboard_label(_keybinds.get(_listening_action, -1))

func _on_bind_button_pressed(action_name, mode):
	_restore_listening_button_text()
	_listening_action = action_name
	_listening_mode = mode
	if mode == "gamepad":
		_gamepad_buttons[action_name].text = "Press a button..."
	else:
		_keybind_buttons[action_name].text = "Press a key..."

func _on_reset_bindings_pressed():
	_restore_listening_button_text()
	_listening_action = null
	_listening_mode = ""
	VW.Settings.reset_bindings_to_default()
	_keybinds = VW.Settings.get_keybinds()
	_gamepad_binds = VW.Settings.get_gamepad_binds()
	_refresh_binding_buttons()

func _input(event):
	if _listening_action == null:
		return
	if _listening_mode == "gamepad":
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_restore_listening_button_text()
			_listening_action = null
			_listening_mode = ""
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton and event.pressed:
			_gamepad_binds[_listening_action] = event.button_index
			VW.Settings.change("gamepad_controls", _listening_action, int(event.button_index))
			VW.Settings.apply_keybinds()
			_restore_listening_button_text()
			_listening_action = null
			_listening_mode = ""
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode != KEY_ESCAPE:
			_keybinds[_listening_action] = event.keycode
			VW.Settings.change("controls", _listening_action, int(event.keycode))
			VW.Settings.apply_keybinds()
		_restore_listening_button_text()
		_listening_action = null
		_listening_mode = ""
		get_viewport().set_input_as_handled()

func _ready():
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(760, 680))
	center.add_child(panel)

	var outer_layout = VBoxContainer.new()
	outer_layout.add_theme_constant_override("separation", 14)
	panel.add_child(outer_layout)

	var title_label = Label.new()
	title_label.text = "Settings"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	outer_layout.add_child(title_label)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_layout.add_child(scroll)

	var layout = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	scroll.add_child(layout)

	var fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.text = "Fullscreen"
	fullscreen_toggle.button_pressed = VW.Settings.fullscreen()
	fullscreen_toggle.toggled.connect(func(enabled):
		VW.Settings.change("display", "fullscreen", enabled)
		VW.Settings.apply_display_settings()
	)
	VW.Chrome.attach_focus_ring(fullscreen_toggle)
	layout.add_child(fullscreen_toggle)

	var inactive_regions_toggle = CheckButton.new()
	inactive_regions_toggle.text = "Show Inactive Regions & Connections"
	inactive_regions_toggle.button_pressed = VW.Settings.show_inactive_regions()
	inactive_regions_toggle.toggled.connect(func(enabled):
		VW.Settings.change("game", "show_inactive_regions", enabled)
	)
	VW.Chrome.attach_focus_ring(inactive_regions_toggle)
	layout.add_child(inactive_regions_toggle)

	_add_volume_slider(layout, "Master Volume", "audio_volume_master_percent", VW.Settings.master_volume_percent())
	_add_volume_slider(layout, "Music Volume", "audio_volume_music_percent", VW.Settings.music_volume_percent())
	_add_volume_slider(layout, "Sound Effects Volume", "audio_volume_sound_effects_percent", VW.Settings.sound_effects_volume_percent())

	var bindings_header = Label.new()
	bindings_header.text = "Bindings (click to rebind, Esc to cancel)"
	bindings_header.add_theme_font_size_override("font_size", 20)
	bindings_header.add_theme_color_override("font_color", Color(0.96, 0.80, 0.28))
	layout.add_child(bindings_header)

	_keybinds = VW.Settings.get_keybinds()
	_gamepad_binds = VW.Settings.get_gamepad_binds()

	var bindings_grid = GridContainer.new()
	bindings_grid.columns = 3
	bindings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bindings_grid.add_theme_constant_override("h_separation", 18)
	bindings_grid.add_theme_constant_override("v_separation", 8)
	layout.add_child(bindings_grid)

	for column_title in ["Command", "Keyboard", "Gamepad"]:
		var col_label = Label.new()
		col_label.text = column_title
		col_label.add_theme_font_size_override("font_size", 16)
		col_label.add_theme_color_override("font_color", Color(0.85, 0.68, 0.25))
		bindings_grid.add_child(col_label)

	for action_name in VW.Settings.get_all_bindable_actions():
		var action_label = Label.new()
		action_label.text = action_name.replace("_", " ").capitalize()
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bindings_grid.add_child(action_label)

		var key_button = VW.Chrome.styled_button(_keyboard_label(_keybinds.get(action_name, -1)), 15)
		key_button.custom_minimum_size = Vector2(180, 34)
		key_button.pressed.connect(_on_bind_button_pressed.bind(action_name, "keyboard"))
		bindings_grid.add_child(key_button)
		_keybind_buttons[action_name] = key_button

		var gamepad_button = VW.Chrome.styled_button(VW.Settings.gamepad_button_name(_gamepad_binds.get(action_name, -1)), 15)
		gamepad_button.custom_minimum_size = Vector2(180, 34)
		gamepad_button.pressed.connect(_on_bind_button_pressed.bind(action_name, "gamepad"))
		bindings_grid.add_child(gamepad_button)
		_gamepad_buttons[action_name] = gamepad_button

	var footer_row = HBoxContainer.new()
	footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_row.add_theme_constant_override("separation", 16)
	outer_layout.add_child(footer_row)

	var reset_button = VW.Chrome.styled_button("Reset Bindings", 16)
	reset_button.pressed.connect(_on_reset_bindings_pressed)
	footer_row.add_child(reset_button)

	var back_button = VW.Chrome.styled_button("Back to Main Menu", 16)
	back_button.pressed.connect(func(): VW.Scenes.goto(VW.Scenes.MAIN_MENU))
	footer_row.add_child(back_button)

	fullscreen_toggle.call_deferred("grab_focus")
