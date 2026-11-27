extends RefCounted

const GameEngine = preload("res://script/instance/rules/game_engine.gd")
const ResourceMarket = preload("res://script/instance/rules/resource_market.gd")
const MapGraph = preload("res://script/instance/rules/map_graph.gd")
const NetworkProtocol = preload("res://script/instance/network/protocol.gd")

static func _ensure_frida_state(state):
	if state.has("frida_state"):
		return state.frida_state
	var cards = VW.Database.get_frida_cards()
	cards.shuffle()
	var discard = []
	if cards.size() > 3:
		for _skip in range(3):
			discard.append(cards.pop_back())
	var frida_state = {
		draw_pile = cards,
		discard_pile = discard,
		round_drawn = -1,
		phase_cards = [],
		build_targets = {}
	}
	state["frida_state"] = frida_state
	return frida_state

static func _draw_frida_round_cards(state):
	var frida_state = _ensure_frida_state(state)
	var current_round = int(state.get("round_number", 1))
	if int(frida_state.round_drawn) == current_round and frida_state.phase_cards.size() == 3:
		return frida_state.phase_cards
	if not frida_state.phase_cards.is_empty():
		frida_state.discard_pile.append_array(frida_state.phase_cards)
		frida_state.phase_cards = []
	for _card_index in range(3):
		if frida_state.draw_pile.is_empty():
			var next_pile = frida_state.discard_pile.duplicate(true)
			frida_state.discard_pile.clear()
			next_pile.shuffle()
			if next_pile.size() > 3:
				for _skip in range(3):
					frida_state.discard_pile.append(next_pile.pop_back())
			frida_state.draw_pile = next_pile
		if not frida_state.draw_pile.is_empty():
			frida_state.phase_cards.append(frida_state.draw_pile.pop_front())
	frida_state.round_drawn = current_round
	return frida_state.phase_cards

static func _frida_side_for_seat(state, seat_index):
	var automa_index = 0
	for player in state.players:
		if str(player.control_mode) == "automa_frida":
			if int(player.seat_index) == int(seat_index):
				return automa_index % 2
			automa_index += 1
	return 0

static func take_turn_if_automa(state):
	var seat_index = GameEngine.active_seat(state)
	if seat_index < 0 or seat_index >= state.players.size():
		return false
	var player = state.players[seat_index]
	var mode = str(player.control_mode)
	if mode != "automa_frida" and mode != "automa_robots":
		return false

	if mode == "automa_frida":
		return _act_frida(state, seat_index)
	return _act_robots(state, seat_index)

static func _act_frida(state, seat_index):
	var phase_cards = _draw_frida_round_cards(state)
	var side = _frida_side_for_seat(state, seat_index)
	var phase = int(state.phase)
	var player = state.players[seat_index]

	if phase == 2:
		if phase_cards.is_empty():
			GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_PHASE, {})
			return true
		var auction_card = phase_cards[0]
		var market_choice = int(auction_card.get("market1" if side == 0 else "market2", -1))
		var ante = int(auction_card.get("ante1" if side == 0 else "ante2", 0))
		if bool(state.auction.active):
			var plant_number = int(state.auction.plant_number)
			var next_bid = int(state.auction.current_bid) + 1
			var max_cap = plant_number + ante
			if next_bid <= max_cap and int(player.elektro) >= next_bid:
				GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PLACE_BID, { amount = next_bid })
			else:
				GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_AUCTION, {})
			return true
		if market_choice > 0 and market_choice <= state.actual_market.size():
			var candidate = int(state.actual_market[market_choice - 1])
			if int(player.elektro) >= candidate:
				GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_SELECT_PLANT_FOR_AUCTION, { plant_number = candidate })
				return true
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_PHASE, {})
		return true

	if phase == 3:
		if phase_cards.size() >= 2:
			var resource_card = phase_cards[1]
			var resource_mode = int(resource_card.get("resource1" if side == 0 else "resource2", 0))
			if resource_mode > 0:
				var sorted_plants = player.plants.duplicate()
				sorted_plants.sort()
				sorted_plants.reverse()
				for plant_idx in range(sorted_plants.size()):
					var plant = VW.Database.get_plant(state.deck_id, int(sorted_plants[plant_idx]))
					if plant == null or plant.is_ecological:
						continue
					var multiplier = 2 if (resource_mode == 2 and plant_idx == 0) else 1
					var needed = int(plant.fuel_cost) * multiplier
					for _unit in range(needed):
						for fuel_type in plant.accepted_fuels:
							if ResourceMarket.can_store_resource(player, state.deck_id, fuel_type, 1):
								var price = ResourceMarket.next_unit_price(state.resource_market, fuel_type)
								if price >= 0 and int(player.elektro) >= price:
									GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_BUY_RESOURCE, { resource = fuel_type, amount = 1 })
									break
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_PHASE, {})
		return true

	if phase == 4:
		if phase_cards.size() >= 3:
			var build_card = phase_cards[2]
			var direction = str(build_card.get("compass_direction_1" if side == 0 else "compass_direction_2", "n"))
			var build_count = int(build_card.get("build1" if side == 0 else "build2", 1))
			for _step in range(build_count):
				var target_city = _pick_frida_city(state, seat_index, direction)
				if target_city == "":
					break
				var build_result = GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_BUILD_CITY, { city_id = target_city })
				if not build_result.accepted:
					break
				state.frida_state.build_targets[str(seat_index)] = target_city
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_PHASE, {})
		return true

	if phase == 5:
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_POWER_PLANTS, { plants = player.plants })
		return true
	return false

static func _pick_frida_city(state, seat_index, direction):
	var map_definition = VW.Database.get_map(state.map_id)
	if map_definition == null:
		return ""
	var player = state.players[seat_index]
	if player.built_cities.is_empty():
		var start_city = str(map_definition.automa_start_cities.get(direction, ""))
		if start_city != "" and MapGraph.city_build_cost(map_definition, state, seat_index, start_city) >= 0:
			return start_city
	var anchor = str(state.frida_state.build_targets.get(str(seat_index), ""))
	if anchor != "":
		for edge in map_definition.adjacency.get(anchor, []):
			if str(edge.direction) == direction:
				var neighbor_cost = MapGraph.city_build_cost(map_definition, state, seat_index, edge.target)
				if neighbor_cost >= 0 and int(player.elektro) >= neighbor_cost:
					return edge.target
	var best_city = ""
	var best_cost = 999999
	for city_id in map_definition.cities.keys():
		var cost = MapGraph.city_build_cost(map_definition, state, seat_index, city_id)
		if cost >= 0 and cost < best_cost and int(player.elektro) >= cost:
			best_cost = cost
			best_city = city_id
	return best_city

static func _act_robots(state, seat_index):
	var player = state.players[seat_index]
	var phase = int(state.phase)
	if phase == 2:
		if bool(state.auction.active):
			var plant_number = int(state.auction.plant_number)
			var next_bid = int(state.auction.current_bid) + 1
			if next_bid <= plant_number + 6 and int(player.elektro) >= next_bid:
				GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PLACE_BID, { amount = next_bid })
			else:
				GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_AUCTION, {})
			return true
		if not state.actual_market.is_empty():
			var candidate = int(state.actual_market[min(1, state.actual_market.size() - 1)])
			if int(player.elektro) >= candidate and (player.plants.size() < 3 or candidate > int(player.plants[0])):
				GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_SELECT_PLANT_FOR_AUCTION, { plant_number = candidate })
				return true
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_PHASE, {})
		return true
	if phase == 3:
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
	if phase == 4:
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
	if phase == 5:
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_POWER_PLANTS, { plants = player.plants })
		return true
	return false
