extends RefCounted

const GameEngine = preload("res://script/instance/rules/game_engine.gd")
const ResourceMarket = preload("res://script/instance/rules/resource_market.gd")
const MapGraph = preload("res://script/instance/rules/map_graph.gd")
const NetworkProtocol = preload("res://script/instance/network/protocol.gd")

static func take_turn_if_automa(state):
	var seat_index = GameEngine.active_seat(state)
	if seat_index < 0 or seat_index >= state.players.size():
		return false
	var player = state.players[seat_index]
	var mode = str(player.control_mode)
	if mode != "automa_frida" and mode != "automa_robots":
		return false

	var phase = int(state.phase)
	if phase == 2:
		return _act_phase_two(state, seat_index, mode)
	if phase == 3:
		return _act_phase_three(state, seat_index)
	if phase == 4:
		return _act_phase_four(state, seat_index)
	if phase == 5:
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_POWER_PLANTS, { plants = player.plants })
		return true
	return false

static func _act_phase_two(state, seat_index, mode):
	var player = state.players[seat_index]
	if bool(state.auction.active):
		var plant_number = int(state.auction.plant_number)
		var next_bid = int(state.auction.current_bid) + 1
		var max_cap = plant_number + (4 if mode == "automa_frida" else 6)
		if next_bid <= max_cap and int(player.elektro) >= next_bid:
			GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PLACE_BID, { amount = next_bid })
		else:
			GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_AUCTION, {})
		return true

	if not state.actual_market.is_empty():
		var target_index = 0 if mode == "automa_frida" else min(1, state.actual_market.size() - 1)
		var candidate = int(state.actual_market[target_index])
		if int(player.elektro) >= candidate and (player.plants.size() < 3 or candidate > int(player.plants[0])):
			GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_SELECT_PLANT_FOR_AUCTION, { plant_number = candidate })
			return true
	GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_PHASE, {})
	return true

static func _act_phase_three(state, seat_index):
	var player = state.players[seat_index]
	for plant_number in player.plants:
		var plant = VW.Database.get_plant(state.deck_id, int(plant_number))
		if plant == null or plant.is_ecological:
			continue
		for fuel_type in plant.accepted_fuels:
			for _attempt in range(int(plant.fuel_cost)):
				if ResourceMarket.can_store_resource(player, state.deck_id, fuel_type, 1):
					var price = ResourceMarket.next_unit_price(state.resource_market, fuel_type)
					if price >= 0 and int(player.elektro) >= price:
						GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_BUY_RESOURCE, { resource = fuel_type, amount = 1 })
						break
	GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_PHASE, {})
	return true

static func _act_phase_four(state, seat_index):
	var player = state.players[seat_index]
	var map_definition = VW.Database.get_map(state.map_id)
	var best_city = ""
	var best_cost = 999999
	for city_id in map_definition.cities.keys():
		var cost = MapGraph.city_build_cost(map_definition, state, seat_index, city_id)
		if cost >= 0 and cost < best_cost:
			best_cost = cost
			best_city = city_id
	if best_city != "" and int(player.elektro) >= best_cost:
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_BUILD_CITY, { city_id = best_city })
	GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_PHASE, {})
	return true
