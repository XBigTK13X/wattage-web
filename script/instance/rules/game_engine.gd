extends RefCounted

const ResourceMarket = preload("res://script/instance/rules/resource_market.gd")
const PlantMarket = preload("res://script/instance/rules/plant_market.gd")
const MapGraph = preload("res://script/instance/rules/map_graph.gd")
const NetworkProtocol = preload("res://script/instance/network/protocol.gd")

const BUREAUCRACY_PAYOUTS = [
	10, 22, 33, 44, 54, 64, 73, 82, 90, 98,
	105, 112, 118, 124, 129, 134, 138, 142, 145, 148, 150
]

static func create_match(config):
	VW.Database.ensure_loaded()
	var map_id = str(config.get("map_id", "germany"))
	var deck_id = str(config.get("deck_id", "base_game"))
	var map_definition = VW.Database.get_map(map_id)
	var seat_configs = config.get("seats", [])
	var seat_count = seat_configs.size()

	var count_info = _player_count_info(map_definition, seat_count)
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

	if not bool(config.get("preserve_initial_order", false)):
		turn_order.shuffle()

	var active_regions = _select_active_regions(map_definition, int(count_info.get("regions", 6)))
	var deck_setup = PlantMarket.setup_deck_and_market(deck_id, int(count_info.get("removed_plants", 0)))
	var start_resources = map_definition.start_resources if map_definition != null else [1, 3, 7, 14]

	var game_id = "match_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)
	return {
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
		actual_market = deck_setup.actual,
		futures_market = deck_setup.futures,
		draw_pile = deck_setup.draw_pile,
		city_occupancy = {},
		resource_market = ResourceMarket.create_market(start_resources),
		auction = {
			active = false,
			plant_number = 0,
			current_bid = 0,
			high_bidder_seat = -1,
			passed_seats = [],
			bought_this_round = [],
			round_passed_seats = [],
			any_plant_sold_this_round = false
		},
		phase_done_seats = [],
		end_game_triggered = false,
		finished = false,
		standings = []
	}

static func _player_count_info(map_definition, seat_count):
	if map_definition != null and map_definition.player_count_info.has(str(seat_count)):
		return map_definition.player_count_info[str(seat_count)]
	return {
		regions = 3,
		removed_plants = 8,
		max_plants = 4 if seat_count <= 2 else 3,
		step_two_cities = 10 if seat_count <= 2 else 7,
		end_game_cities = 21 if seat_count <= 2 else 17,
		refill = [[3, 2, 1, 1], [4, 2, 2, 1], [3, 4, 3, 1]]
	}

static func _select_active_regions(map_definition, target_count):
	if map_definition == null:
		return []
	var region_keys = map_definition.regions.keys()
	region_keys.sort()
	var selected = []
	for index in range(min(target_count, region_keys.size())):
		selected.append(region_keys[index])
	return selected

static func determine_player_order(state):
	var order = state.turn_order.duplicate()
	var players = state.players
	order.sort_custom(func(seat_first, seat_second):
		var player_first = players[seat_first]
		var player_second = players[seat_second]
		var cities_first = player_first.built_cities.size()
		var cities_second = player_second.built_cities.size()
		if cities_first != cities_second:
			return cities_first > cities_second
		var max_plant_first = _highest_plant(player_first)
		var max_plant_second = _highest_plant(player_second)
		return max_plant_first > max_plant_second
	)
	state.turn_order = order
	return order

static func _highest_plant(player):
	var best = 0
	for plant_number in player.plants:
		best = max(best, int(plant_number))
	return best

static func active_seat(state):
	if int(state.phase) == 2 and bool(state.auction.get("active", false)):
		return int(state.auction.get("current_bidder_seat", -1))
	var order = state.get("turn_order", [])
	var position = int(state.get("active_turn_position", 0))
	if position >= 0 and position < order.size():
		return int(order[position])
	return -1

static func apply_action(state, seat_index, action_name, parameters = {}):
	if bool(state.get("finished", false)):
		return { accepted = false, error_code = NetworkProtocol.ERROR_ILLEGAL_ACTION, message = "Match is already finished" }
	if seat_index != active_seat(state):
		return { accepted = false, error_code = NetworkProtocol.ERROR_NOT_YOUR_TURN, message = "Not your turn" }

	var phase = int(state.phase)
	if action_name == NetworkProtocol.ACTION_SELECT_PLANT_FOR_AUCTION:
		return _handle_select_plant(state, seat_index, parameters)
	if action_name == NetworkProtocol.ACTION_PLACE_BID:
		return _handle_place_bid(state, seat_index, parameters)
	if action_name == NetworkProtocol.ACTION_PASS_AUCTION:
		return _handle_pass_auction(state, seat_index)
	if action_name == NetworkProtocol.ACTION_BUY_RESOURCE:
		if phase != 3:
			return { accepted = false, error_code = NetworkProtocol.ERROR_INVALID_PHASE, message = "Not in Phase 3" }
		return _handle_buy_resource(state, seat_index, parameters)
	if action_name == NetworkProtocol.ACTION_BUILD_CITY:
		if phase != 4:
			return { accepted = false, error_code = NetworkProtocol.ERROR_INVALID_PHASE, message = "Not in Phase 4" }
		return _handle_build_city(state, seat_index, parameters)
	if action_name == NetworkProtocol.ACTION_POWER_PLANTS:
		if phase != 5:
			return { accepted = false, error_code = NetworkProtocol.ERROR_INVALID_PHASE, message = "Not in Phase 5" }
		return _handle_power_plants(state, seat_index, parameters)
	if action_name == NetworkProtocol.ACTION_PASS_PHASE:
		return _handle_pass_phase(state, seat_index)
	return { accepted = false, error_code = NetworkProtocol.ERROR_UNKNOWN_ACTION, message = "Unknown action" }

static func _handle_select_plant(state, seat_index, parameters):
	if int(state.phase) != 2 or bool(state.auction.active):
		return { accepted = false, error_code = NetworkProtocol.ERROR_INVALID_PHASE, message = "Cannot nominate plant now" }
	var plant_number = int(parameters.get("plant_number", 0))
	if not state.actual_market.has(plant_number):
		return { accepted = false, error_code = NetworkProtocol.ERROR_ILLEGAL_ACTION, message = "Plant not in Actual Market" }
	var opening_bid = int(parameters.get("bid", plant_number))
	if opening_bid < plant_number:
		opening_bid = plant_number
	var player = state.players[seat_index]
	if int(player.elektro) < opening_bid:
		return { accepted = false, error_code = NetworkProtocol.ERROR_INSUFFICIENT_ELEKTRO, message = "Insufficient Elektro" }

	state.auction.active = true
	state.auction.plant_number = plant_number
	state.auction.current_bid = opening_bid
	state.auction.high_bidder_seat = seat_index
	state.auction.passed_seats = []
	for done_seat in state.auction.bought_this_round:
		state.auction.passed_seats.append(done_seat)
	for passed_seat in state.auction.round_passed_seats:
		if not state.auction.passed_seats.has(passed_seat):
			state.auction.passed_seats.append(passed_seat)
	_advance_auction_bidder(state)
	return { accepted = true, error_code = "", message = "Plant #" + str(plant_number) + " nominated" }

static func _handle_place_bid(state, seat_index, parameters):
	if int(state.phase) != 2 or not bool(state.auction.active):
		return { accepted = false, error_code = NetworkProtocol.ERROR_INVALID_PHASE, message = "No active auction" }
	var increment = int(parameters.get("increment", 1))
	var next_bid = int(parameters.get("amount", int(state.auction.current_bid) + increment))
	if next_bid <= int(state.auction.current_bid):
		return { accepted = false, error_code = NetworkProtocol.ERROR_ILLEGAL_ACTION, message = "Bid must exceed current bid" }
	var player = state.players[seat_index]
	if int(player.elektro) < next_bid:
		return { accepted = false, error_code = NetworkProtocol.ERROR_INSUFFICIENT_ELEKTRO, message = "Insufficient Elektro" }
	state.auction.current_bid = next_bid
	state.auction.high_bidder_seat = seat_index
	_advance_auction_bidder(state)
	return { accepted = true, error_code = "", message = "Bid placed: " + str(next_bid) }

static func _handle_pass_auction(state, seat_index):
	if int(state.phase) != 2 or not bool(state.auction.active):
		return { accepted = false, error_code = NetworkProtocol.ERROR_INVALID_PHASE, message = "No active auction" }
	if not state.auction.passed_seats.has(seat_index):
		state.auction.passed_seats.append(seat_index)
	_advance_auction_bidder(state)
	return { accepted = true, error_code = "", message = "Passed auction" }

static func _advance_auction_bidder(state):
	var order = state.turn_order
	var high_seat = int(state.auction.high_bidder_seat)
	var eligible = []
	for seat in order:
		if not state.auction.passed_seats.has(seat):
			eligible.append(seat)
	if eligible.size() <= 1:
		_complete_auction(state)
		return
	var current_bidder = int(state.auction.get("current_bidder_seat", high_seat))
	var start_idx = order.find(current_bidder)
	for offset in range(1, order.size() + 1):
		var candidate = int(order[(start_idx + offset) % order.size()])
		if not state.auction.passed_seats.has(candidate) and candidate != high_seat:
			state.auction["current_bidder_seat"] = candidate
			return
	_complete_auction(state)

static func _complete_auction(state):
	var winner_seat = int(state.auction.high_bidder_seat)
	var plant_number = int(state.auction.plant_number)
	var cost = int(state.auction.current_bid)
	var player = state.players[winner_seat]
	player.elektro = int(player.elektro) - cost

	var map_definition = VW.Database.get_map(state.map_id)
	var count_info = _player_count_info(map_definition, state.players.size())
	var max_plants = int(count_info.get("max_plants", 3))
	if player.plants.size() >= max_plants:
		player.plants.sort()
		player.plants.pop_front()
	player.plants.append(plant_number)
	player.plants.sort()

	state.actual_market.erase(plant_number)
	PlantMarket.draw_replacement(state)
	state.auction.active = false
	state.auction.bought_this_round.append(winner_seat)
	state.auction.any_plant_sold_this_round = true
	_advance_phase_two_turn(state)

static func _advance_phase_two_turn(state):
	var order = state.turn_order
	for index in range(order.size()):
		var candidate = int(order[index])
		if not state.auction.bought_this_round.has(candidate) and not state.auction.round_passed_seats.has(candidate):
			state.active_turn_position = index
			return
	if not bool(state.auction.any_plant_sold_this_round):
		var combined = state.actual_market + state.futures_market
		combined.sort()
		if not combined.is_empty():
			var lowest = int(combined[0])
			state.actual_market.erase(lowest)
			state.futures_market.erase(lowest)
			PlantMarket.draw_replacement(state)
	if int(state.round_number) == 1:
		determine_player_order(state)
	state.phase = 3
	state.phase_done_seats = []
	state.active_turn_position = state.turn_order.size() - 1

static func _handle_buy_resource(state, seat_index, parameters):
	var resource_type = str(parameters.get("resource", ""))
	var amount = max(1, int(parameters.get("amount", 1)))
	var player = state.players[seat_index]
	for _unit in range(amount):
		if not ResourceMarket.can_store_resource(player, state.deck_id, resource_type, 1):
			return { accepted = false, error_code = NetworkProtocol.ERROR_ILLEGAL_ACTION, message = "Storage capacity full for " + resource_type }
		var price = ResourceMarket.next_unit_price(state.resource_market, resource_type)
		if price < 0:
			return { accepted = false, error_code = NetworkProtocol.ERROR_ILLEGAL_ACTION, message = "No " + resource_type + " remaining" }
		if int(player.elektro) < price:
			return { accepted = false, error_code = NetworkProtocol.ERROR_INSUFFICIENT_ELEKTRO, message = "Insufficient Elektro" }
		ResourceMarket.buy_one(state.resource_market, resource_type)
		player.elektro -= price
		player.stored_resources[resource_type] = int(player.stored_resources.get(resource_type, 0)) + 1
	return { accepted = true, error_code = "", message = "Bought " + str(amount) + " " + resource_type }

static func _handle_build_city(state, seat_index, parameters):
	var city_id = str(parameters.get("city_id", ""))
	var map_definition = VW.Database.get_map(state.map_id)
	var total_cost = MapGraph.city_build_cost(map_definition, state, seat_index, city_id)
	if total_cost < 0:
		return { accepted = false, error_code = NetworkProtocol.ERROR_ILLEGAL_ACTION, message = "Cannot build in " + city_id }
	var player = state.players[seat_index]
	if int(player.elektro) < total_cost:
		return { accepted = false, error_code = NetworkProtocol.ERROR_INSUFFICIENT_ELEKTRO, message = "Insufficient Elektro (need " + str(total_cost) + ")" }

	player.elektro -= total_cost
	player.built_cities.append(city_id)
	var occupants = state.city_occupancy.get(city_id, [])
	occupants.append(seat_index)
	state.city_occupancy[city_id] = occupants

	var max_cities = 0
	for some_player in state.players:
		max_cities = max(max_cities, some_player.built_cities.size())
	PlantMarket.remove_plants_at_or_below(state, max_cities)

	var count_info = _player_count_info(map_definition, state.players.size())
	if int(state.step) == 1 and max_cities >= int(count_info.get("step_two_cities", 7)):
		state.step = 2
		var combined = state.actual_market + state.futures_market
		combined.sort()
		if not combined.is_empty():
			var lowest = int(combined[0])
			state.actual_market.erase(lowest)
			state.futures_market.erase(lowest)
			PlantMarket.draw_replacement(state)
	if max_cities >= int(count_info.get("end_game_cities", 17)):
		state.end_game_triggered = true

	return { accepted = true, error_code = "", message = "Built " + city_id + " for " + str(total_cost) + "E" }

static func _handle_power_plants(state, seat_index, parameters):
	var player = state.players[seat_index]
	var selected_plants = parameters.get("plants", player.plants)
	var powered_count = 0
	for plant_number in selected_plants:
		if not player.plants.has(int(plant_number)):
			continue
		var plant = VW.Database.get_plant(state.deck_id, int(plant_number))
		if plant == null:
			continue
		if _consume_fuel_for_plant(player, plant):
			powered_count += int(plant.cities_powered)
	var capped_powered = min(powered_count, player.built_cities.size())
	player["last_powered_cities"] = capped_powered
	if not bool(state.end_game_triggered):
		var payout_index = clamp(capped_powered, 0, BUREAUCRACY_PAYOUTS.size() - 1)
		player.elektro += BUREAUCRACY_PAYOUTS[payout_index]
	_advance_reverse_or_forward_turn(state)
	return { accepted = true, error_code = "", message = "Powered " + str(capped_powered) + " cities" }

static func _consume_fuel_for_plant(player, plant):
	if plant.is_ecological:
		return true
	var needed = int(plant.fuel_cost)
	var stored = player.stored_resources
	if plant.fuel_type == "hybrid_oil_coal":
		var oil_avail = int(stored.get("oil", 0))
		var coal_avail = int(stored.get("coal", 0))
		if oil_avail + coal_avail < needed:
			return false
		var use_oil = min(oil_avail, needed)
		stored["oil"] = oil_avail - use_oil
		stored["coal"] = coal_avail - (needed - use_oil)
		return true
	if plant.fuel_type == "hybrid_oil_garbage":
		var oil_avail = int(stored.get("oil", 0))
		var garbage_avail = int(stored.get("garbage", 0))
		if oil_avail + garbage_avail < needed:
			return false
		var use_oil = min(oil_avail, needed)
		stored["oil"] = oil_avail - use_oil
		stored["garbage"] = garbage_avail - (needed - use_oil)
		return true
	var avail = int(stored.get(plant.fuel_type, 0))
	if avail < needed:
		return false
	stored[plant.fuel_type] = avail - needed
	return true

static func _handle_pass_phase(state, seat_index):
	var phase = int(state.phase)
	if phase == 2:
		if bool(state.auction.active):
			return _handle_pass_auction(state, seat_index)
		if not state.auction.round_passed_seats.has(seat_index):
			state.auction.round_passed_seats.append(seat_index)
		_advance_phase_two_turn(state)
		return { accepted = true, error_code = "", message = "Passed Phase 2" }
	if phase == 5:
		return _handle_power_plants(state, seat_index, { plants = [] })
	_advance_reverse_or_forward_turn(state)
	return { accepted = true, error_code = "", message = "Ended turn in Phase " + str(phase) }

static func _advance_reverse_or_forward_turn(state):
	var phase = int(state.phase)
	if phase == 3 or phase == 4:
		if int(state.active_turn_position) > 0:
			state.active_turn_position = int(state.active_turn_position) - 1
			return
		if phase == 3:
			state.phase = 4
			state.active_turn_position = state.turn_order.size() - 1
			return
		state.phase = 5
		state.active_turn_position = 0
		return
	if phase == 5:
		if int(state.active_turn_position) < state.turn_order.size() - 1:
			state.active_turn_position = int(state.active_turn_position) + 1
			return
		if bool(state.end_game_triggered):
			_finalize_end_game(state)
			return
		_restock_resources_and_cycle_market(state)
		state.round_number = int(state.round_number) + 1
		determine_player_order(state)
		state.phase = 2
		state.active_turn_position = 0
		state.auction.bought_this_round = []
		state.auction.round_passed_seats = []
		state.auction.any_plant_sold_this_round = false

static func _restock_resources_and_cycle_market(state):
	var map_definition = VW.Database.get_map(state.map_id)
	var count_info = _player_count_info(map_definition, state.players.size())
	var refill_table = count_info.get("refill", [[3, 2, 1, 1], [4, 2, 2, 1], [3, 4, 3, 1]])
	var step_index = clamp(int(state.step) - 1, 0, refill_table.size() - 1)
	var rates = refill_table[step_index]
	var resource_names = ["coal", "oil", "garbage", "uranium"]
	for idx in range(4):
		var resource_type = resource_names[idx]
		var held = 0
		for player in state.players:
			held += int(player.stored_resources.get(resource_type, 0))
		ResourceMarket.restock(state.resource_market, resource_type, int(rates[idx]), held)
	PlantMarket.cycle_bureaucracy_market(state)

static func _finalize_end_game(state):
	var standings = []
	for player in state.players:
		standings.append({
			seat_index = player.seat_index,
			player_name = player.player_name,
			powered_cities = int(player.get("last_powered_cities", 0)),
			elektro = int(player.elektro),
			built_cities = player.built_cities.size()
		})
	standings.sort_custom(func(first, second):
		if first.powered_cities != second.powered_cities:
			return first.powered_cities > second.powered_cities
		if first.elektro != second.elektro:
			return first.elektro > second.elektro
		return first.built_cities > second.built_cities
	)
	state.finished = true
	state.standings = standings
