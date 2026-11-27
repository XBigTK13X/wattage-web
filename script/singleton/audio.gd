extends Node

const SOUND_EFFECT_POOL_SIZE = 12

var _music_player = null
var _current_stream = null
var _next_loop_stream = null
var _root = null
var _state = States.Stopped
var _sound_effect_players = []
var _sound_effect_next_index = 0
var _cue_paths = {}

enum States {
	Playing,
	Stopped
}

func _resolve_bus(bus_name):
	if AudioServer.get_bus_index(bus_name) != -1:
		return bus_name
	return &"Master"

func _apply_bus_volume(bus_name, percent):
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	var clamped = clamp(int(percent), 0, 100)
	AudioServer.set_bus_mute(bus_index, clamped <= 0)
	if clamped > 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(float(clamped) / 100.0))

func apply_volume_settings():
	if VW.Settings == null:
		return
	_apply_bus_volume(&"Master", VW.Settings.master_volume_percent())
	_apply_bus_volume(&"Music", VW.Settings.music_volume_percent())
	_apply_bus_volume(&"Sound", VW.Settings.sound_effects_volume_percent())
	_apply_bus_volume(&"Dialogue", VW.Settings.dialogue_volume_percent())

func apply_preview_volumes(master_percent, music_percent, sound_effects_percent, dialogue_percent):
	_apply_bus_volume(&"Master", master_percent)
	_apply_bus_volume(&"Music", music_percent)
	_apply_bus_volume(&"Sound", sound_effects_percent)
	_apply_bus_volume(&"Dialogue", dialogue_percent)

func register_cue(cue_name, resource_path):
	_cue_paths[str(cue_name)] = str(resource_path)

func register_default_cues():
	var default_cues = [
		"bid_placed",
		"auction_won",
		"resource_bought",
		"city_built",
		"phase_change",
		"turn_alert",
		"step_transition",
		"power_up",
		"action_invalid",
		"ui_click",
		"ui_hover"
	]
	for cue_name in default_cues:
		register_cue(cue_name, "res://asset/audio/" + cue_name + ".wav")

func _clear_sound_effect_pool():
	for player in _sound_effect_players:
		if is_instance_valid(player):
			player.stop()
			if player.get_parent() != null:
				player.get_parent().remove_child(player)
			player.queue_free()
	_sound_effect_players.clear()
	_sound_effect_next_index = 0

func _setup_sound_effect_pool(target_parent):
	_clear_sound_effect_pool()
	var sound_bus = _resolve_bus(&"Sound")
	for index in range(SOUND_EFFECT_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = sound_bus
		target_parent.add_child(player)
		_sound_effect_players.append(player)

func setup(root):
	_root = root
	register_default_cues()
	var target_parent = root if root != null else self
	if VW.Settings == null or VW.Settings.audio_enabled():
		if _music_player != null:
			_music_player.stop()
			if _music_player.get_parent() != null:
				_music_player.get_parent().remove_child(_music_player)
			_music_player.queue_free()
		_current_stream = null
		_next_loop_stream = null
		_music_player = AudioStreamPlayer.new()
		_music_player.bus = _resolve_bus(&"Music")
		_music_player.finished.connect(_on_music_finished)
		target_parent.add_child(_music_player)
		_setup_sound_effect_pool(target_parent)
		apply_volume_settings()
		_state = States.Stopped

func stop():
	_state = States.Stopped
	_next_loop_stream = null
	if _music_player != null:
		_music_player.stop()
	for player in _sound_effect_players:
		if is_instance_valid(player):
			player.stop()

func _on_music_finished():
	if _state != States.Playing or _next_loop_stream == null or _music_player == null:
		return
	var loop_stream = _next_loop_stream
	_next_loop_stream = null
	_current_stream = loop_stream
	_music_player.stream = loop_stream
	_music_player.play()

func play(audio_stream, loop_stream = null):
	if _music_player == null:
		setup(_root)
	if VW.Settings == null or VW.Settings.audio_enabled():
		_next_loop_stream = loop_stream
		if audio_stream != _current_stream:
			_current_stream = audio_stream
			_music_player.stream = audio_stream
			_music_player.play()
		if _state != States.Playing:
			_music_player.play()
			_state = States.Playing

func _acquire_sound_effect_player():
	for player in _sound_effect_players:
		if is_instance_valid(player) and not player.playing:
			return player
	if _sound_effect_players.is_empty():
		return null
	var player = _sound_effect_players[_sound_effect_next_index]
	_sound_effect_next_index = (_sound_effect_next_index + 1) % _sound_effect_players.size()
	if is_instance_valid(player):
		player.stop()
		return player
	return null

func play_sound_effect(cue_name):
	if VW.Settings != null and not VW.Settings.audio_enabled():
		return false
	if _sound_effect_players.is_empty():
		setup(_root if _root != null else self)
	if _sound_effect_players.is_empty():
		return false
	var volume_percent = 100
	if VW.Settings != null:
		volume_percent = VW.Settings.sound_effects_volume_percent()
	if volume_percent <= 0:
		return false
	var resource_path = _cue_paths.get(str(cue_name), "")
	if resource_path == "" or not ResourceLoader.exists(resource_path):
		return false
	var stream = load(resource_path)
	if stream == null:
		return false
	var player = _acquire_sound_effect_player()
	if player == null:
		return false
	apply_volume_settings()
	if AudioServer.get_bus_index(&"Sound") == -1:
		player.volume_db = linear_to_db(float(volume_percent) / 100.0)
	else:
		player.volume_db = 0.0
	player.stream = stream
	player.play()
	return true
