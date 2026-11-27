extends Node

var _settings = null
var settings_path = "user://volt-web-settings.ini"

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

func load():
	var config = ConfigFile.new()
	var error = config.load(settings_path)
	if error == OK or error == ERR_FILE_NOT_FOUND:
		if not config.has_section_key("game", "audio_enabled"):
			config.set_value("game", "audio_enabled", true)
		if not config.has_section_key("game", "audio_volume_master_percent"):
			config.set_value("game", "audio_volume_master_percent", 100)
		if not config.has_section_key("game", "audio_volume_music_percent"):
			config.set_value("game", "audio_volume_music_percent", 100)
		if not config.has_section_key("game", "audio_volume_sound_effects_percent"):
			config.set_value("game", "audio_volume_sound_effects_percent", 100)
		if not config.has_section_key("game", "audio_volume_dialogue_percent"):
			config.set_value("game", "audio_volume_dialogue_percent", 100)
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

func audio_enabled():
	return bool(get_value("game", "audio_enabled", true))

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

func apply_display_settings():
	if _settings == null or DisplayServer.get_name() == "headless":
		return
	if fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func apply_keybinds():
	if _settings == null:
		return
	for action_name in DEFAULT_KEYBINDS.keys():
		var key_code = int(_settings.get_value("controls", action_name, DEFAULT_KEYBINDS[action_name]))
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var existing_events = InputMap.action_get_events(action_name)
		for event in existing_events:
			if event is InputEventKey:
				InputMap.action_erase_event(action_name, event)
		var key_event = InputEventKey.new()
		key_event.keycode = key_code
		InputMap.action_add_event(action_name, key_event)
	for action_name in DEFAULT_GAMEPAD_BINDS.keys():
		var button_index = int(_settings.get_value("gamepad_controls", action_name, DEFAULT_GAMEPAD_BINDS[action_name]))
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var existing_events = InputMap.action_get_events(action_name)
		for event in existing_events:
			if event is InputEventJoypadButton:
				InputMap.action_erase_event(action_name, event)
		var joypad_event = InputEventJoypadButton.new()
		joypad_event.button_index = button_index
		InputMap.action_add_event(action_name, joypad_event)
