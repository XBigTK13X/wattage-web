extends Node

var _settings = null
var settings_path = "user://wattage-web-settings.ini"

const DEFAULT_KEYBINDS = {
	"pan_up": KEY_W,
	"pan_down": KEY_S,
	"pan_left": KEY_A,
	"pan_right": KEY_D,
	"next_panel": KEY_TAB,
	"confirm_action": KEY_SPACE,
	"pass_action": KEY_P,
	"zoom_in": KEY_EQUAL,
	"zoom_out": KEY_MINUS
}

const DEFAULT_GAMEPAD_BINDS = {
	"pan_up": JOY_BUTTON_DPAD_UP,
	"pan_down": JOY_BUTTON_DPAD_DOWN,
	"pan_left": JOY_BUTTON_DPAD_LEFT,
	"pan_right": JOY_BUTTON_DPAD_RIGHT,
	"next_panel": JOY_BUTTON_RIGHT_SHOULDER,
	"previous_panel": JOY_BUTTON_LEFT_SHOULDER,
	"confirm_action": JOY_BUTTON_A,
	"pass_action": JOY_BUTTON_B,
	"quick_bid": JOY_BUTTON_X
}

const GAMEPAD_BUTTON_NAMES = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-Pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad Right"
}

func load():
	var config = ConfigFile.new()
	var error = config.load(settings_path)
	if error == OK or error == ERR_FILE_NOT_FOUND:
		if not config.has_section_key("game", "audio_volume_master_percent"):
			config.set_value("game", "audio_volume_master_percent", 100)
		if not config.has_section_key("game", "audio_volume_music_percent"):
			config.set_value("game", "audio_volume_music_percent", 100)
		if not config.has_section_key("game", "audio_volume_sound_effects_percent"):
			config.set_value("game", "audio_volume_sound_effects_percent", 100)
		if not config.has_section_key("game", "audio_volume_dialogue_percent"):
			config.set_value("game", "audio_volume_dialogue_percent", 100)
		if not config.has_section_key("game", "show_inactive_regions"):
			config.set_value("game", "show_inactive_regions", false)
		if not config.has_section_key("display", "fullscreen"):
			config.set_value("display", "fullscreen", false)
		for action_name in DEFAULT_KEYBINDS.keys():
			if not config.has_section_key("controls", action_name):
				config.set_value("controls", action_name, DEFAULT_KEYBINDS[action_name])
		for action_name in DEFAULT_GAMEPAD_BINDS.keys():
			if not config.has_section_key("gamepad_controls", action_name):
				config.set_value("gamepad_controls", action_name, DEFAULT_GAMEPAD_BINDS[action_name])
		config.save(settings_path)
	_settings = config
	apply_display_settings()
	apply_keybinds()

func change(section, key, value):
	if _settings == null:
		return
	_settings.set_value(section, key, value)
	_settings.save(settings_path)

func get_value(section, key, default_value = null):
	if _settings == null:
		return default_value
	return _settings.get_value(section, key, default_value)

func master_volume_percent():
	return int(get_value("game", "audio_volume_master_percent", 100))

func music_volume_percent():
	return int(get_value("game", "audio_volume_music_percent", 100))

func sound_effects_volume_percent():
	return int(get_value("game", "audio_volume_sound_effects_percent", 100))

func dialogue_volume_percent():
	return int(get_value("game", "audio_volume_dialogue_percent", 100))

func fullscreen():
	return bool(get_value("display", "fullscreen", false))

func show_inactive_regions():
	return bool(get_value("game", "show_inactive_regions", false))

func apply_display_settings():
	if _settings == null or DisplayServer.get_name() == "headless":
		return
	if fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func get_all_bindable_actions():
	var actions = []
	for action_name in DEFAULT_KEYBINDS.keys():
		if not actions.has(action_name):
			actions.append(action_name)
	for action_name in DEFAULT_GAMEPAD_BINDS.keys():
		if not actions.has(action_name):
			actions.append(action_name)
	return actions

func get_keybinds():
	var binds = {}
	for action_name in get_all_bindable_actions():
		var default_code = DEFAULT_KEYBINDS.get(action_name, -1)
		var code = default_code
		if _settings != null:
			code = int(_settings.get_value("controls", action_name, default_code))
		binds[action_name] = code
	return binds

func get_gamepad_binds():
	var binds = {}
	for action_name in get_all_bindable_actions():
		var default_code = DEFAULT_GAMEPAD_BINDS.get(action_name, -1)
		var button_index = default_code
		if _settings != null:
			button_index = int(_settings.get_value("gamepad_controls", action_name, default_code))
		binds[action_name] = button_index
	return binds

func gamepad_button_name(button_index):
	var idx = int(button_index)
	if idx < 0:
		return "Unbound"
	if GAMEPAD_BUTTON_NAMES.has(idx):
		return GAMEPAD_BUTTON_NAMES[idx]
	return "Button " + str(idx)

func reset_bindings_to_default():
	if _settings == null:
		return
	for action_name in get_all_bindable_actions():
		_settings.set_value("controls", action_name, DEFAULT_KEYBINDS.get(action_name, -1))
		_settings.set_value("gamepad_controls", action_name, DEFAULT_GAMEPAD_BINDS.get(action_name, -1))
	_settings.save(settings_path)
	apply_keybinds()

func apply_keybinds():
	if _settings == null:
		return
	var keybinds = get_keybinds()
	var gamepad_binds = get_gamepad_binds()
	for action_name in get_all_bindable_actions():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var existing_events = InputMap.action_get_events(action_name)
		for event in existing_events:
			if event is InputEventKey or event is InputEventJoypadButton:
				InputMap.action_erase_event(action_name, event)
		var key_code = int(keybinds.get(action_name, -1))
		if key_code >= 0:
			var key_event = InputEventKey.new()
			key_event.keycode = key_code
			InputMap.action_add_event(action_name, key_event)
		var button_index = int(gamepad_binds.get(action_name, -1))
		if button_index >= 0:
			var joypad_event = InputEventJoypadButton.new()
			joypad_event.button_index = button_index
			InputMap.action_add_event(action_name, joypad_event)
	_sync_ui_gamepad_action("ui_accept", int(gamepad_binds.get("confirm_action", -1)))
	_sync_ui_gamepad_action("ui_cancel", int(gamepad_binds.get("pass_action", -1)))

func _sync_ui_gamepad_action(ui_action_name, button_index):
	if not InputMap.has_action(ui_action_name):
		return
	for event in InputMap.action_get_events(ui_action_name):
		if event is InputEventJoypadButton:
			InputMap.action_erase_event(ui_action_name, event)
	if button_index >= 0:
		var joypad_event = InputEventJoypadButton.new()
		joypad_event.button_index = button_index
		InputMap.action_add_event(ui_action_name, joypad_event)
