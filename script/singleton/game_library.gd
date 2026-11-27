extends Node

const GameEngine = preload("res://script/instance/rules/game_engine.gd")

const GAMES_DIRECTORY = "user://games/"

var active_game = null

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_active_game()

func _ensure_directory():
	if not DirAccess.dir_exists_absolute(GAMES_DIRECTORY):
		DirAccess.make_dir_recursive_absolute(GAMES_DIRECTORY)

func _game_path(game_id):
	return GAMES_DIRECTORY + str(game_id) + ".json"

func list_saved_games():
	_ensure_directory()
	var directory = DirAccess.open(GAMES_DIRECTORY)
	if directory == null:
		return []
	var games = []
	directory.list_dir_begin()
	var entry = directory.get_next()
	while entry != "":
		if not directory.current_is_dir() and entry.ends_with(".json"):
			var file = FileAccess.open(GAMES_DIRECTORY + entry, FileAccess.READ)
			if file != null:
				var parsed = JSON.parse_string(file.get_as_text())
				if typeof(parsed) == TYPE_DICTIONARY and parsed.has("game_id"):
					games.append(parsed)
		entry = directory.get_next()
	directory.list_dir_end()
	games.sort_custom(func(first, second): return int(first.get("updated_at", 0)) > int(second.get("updated_at", 0)))
	return games

func create_new_game(config):
	active_game = GameEngine.create_match(config)
	save_active_game()
	return active_game

func save_active_game():
	if active_game == null:
		return false
	_ensure_directory()
	active_game["updated_at"] = int(Time.get_unix_time_from_system())
	var file = FileAccess.open(_game_path(active_game.game_id), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(active_game, "\t"))
	return true

func resume_game(game_id):
	var path = _game_path(game_id)
	if not FileAccess.file_exists(path):
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	active_game = parsed
	if VW.Network != null and active_game.has("players"):
		VW.Network.seat_registry.configure_seats(active_game.players)
		VW.Network.broadcast_state()
	return active_game

func suspend_active_game():
	if active_game != null:
		save_active_game()
		active_game = null

func delete_saved_game(game_id):
	var path = _game_path(game_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if active_game != null and active_game.game_id == game_id:
		active_game = null
