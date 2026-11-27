extends Node

const GAMES_DIRECTORY = "user://games/"

const BUREAUCRACY_PAYOUTS = [
	10, 22, 33, 44, 54, 64, 73, 82, 90, 98,
	105, 112, 118, 124, 129, 134, 138, 142, 145, 148, 150
]

const RESOURCE_PRICES = [1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16]

var active_game = null

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
	VW.Database.ensure_loaded()
	var map_id = str(config.get("map_id", "germany"))
	var deck_id = str(config.get("deck_id", "base_game"))
	var map_definition = VW.Database.get_map(map_id)
	var deck = VW.Database.get_deck(deck_id)
	var seat_configs = config.get("seats", [])
	var seat_count = seat_configs.size()

	var players = []
	var turn_order = []
	for index in range(seat_count):
		var seat = seat_configs[index]
		players.append({
			seat_index = index,
			player_name = str(seat.get("player_name", "Player " + str(index + 1))),
			color = str(seat.get("color", "red")),
			control_mode = str(seat.get("control_mode", "local")),
			elektro = 50,
			plants = [],
			stored_resources = { coal = 0, oil = 0, garbage = 0, uranium = 0 },
			built_cities = []
		})
		turn_order.append(index)

	var actual_market = []
	var futures_market = []
	if deck != null:
		for card in deck.cards:
			if card.is_step_three:
				continue
			if actual_market.size() < 4:
				actual_market.append(card.number)
			elif futures_market.size() < 4:
				futures_market.append(card.number)
			else:
				break

	var active_regions = []
	if map_definition != null:
		var region_keys = map_definition.regions.keys()
		region_keys.sort()
		var target_region_count = region_keys.size()
		if map_definition.player_count_info.has(str(seat_count)):
			target_region_count = min(region_keys.size(), int(map_definition.player_count_info[str(seat_count)].get("regions", region_keys.size())))
		for region_index in range(target_region_count):
			active_regions.append(region_keys[region_index])

	var start_resources = [1, 3, 7, 14]
	if map_definition != null and map_definition.start_resources.size() >= 4:
		start_resources = map_definition.start_resources

	var game_id = "match_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)
	var game_state = {
		game_id = game_id,
		title = str(config.get("title", map_id.capitalize() + " (" + str(seat_count) + "P)")),
		map_id = map_id,
		deck_id = deck_id,
		updated_at = int(Time.get_unix_time_from_system()),
		step = 1,
		phase = 2,
		round_number = 1,
		active_regions = active_regions,
		turn_order = turn_order,
		active_turn_position = 0,
		players = players,
		actual_market = actual_market,
		futures_market = futures_market,
		city_occupancy = {},
		resource_market = {
			coal = _build_initial_bins("coal", int(start_resources[0])),
			oil = _build_initial_bins("oil", int(start_resources[1])),
			garbage = _build_initial_bins("garbage", int(start_resources[2])),
			uranium = _build_initial_bins("uranium", int(start_resources[3]))
		},
		auction = {
			active = false,
			plant_number = 0,
			current_bid = 0,
			high_bidder_seat = -1,
			passed_seats = []
		},
		finished = false,
		standings = []
	}
	active_game = game_state
	save_active_game()
	return active_game

func _build_initial_bins(resource_type, min_price):
	var bins = []
	for index in range(RESOURCE_PRICES.size()):
		var price = RESOURCE_PRICES[index]
		var capacity = 1 if resource_type == "uranium" else 3
		if resource_type == "uranium" and price < 10:
			capacity = 1
		var amount = capacity if price >= min_price else 0
		bins.append({
			price = price,
			capacity = capacity,
			amount = amount
		})
	return bins

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
