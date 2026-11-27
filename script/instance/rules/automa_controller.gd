extends RefCounted

const GameEngine = preload("res://script/instance/rules/game_engine.gd")
const ResourceMarket = preload("res://script/instance/rules/resource_market.gd")
const PlantMarket = preload("res://script/instance/rules/plant_market.gd")
const MapGraph = preload("res://script/instance/rules/map_graph.gd")
const NetworkProtocol = preload("res://script/instance/network/protocol.gd")
const RobotsExpansion = preload("res://script/instance/rules/robots_expansion.gd")

const DIRECTION_VECTORS = {
	"n": Vector2(0.0, -1.0),
	"ne": Vector2(0.707, -0.707),
	"e": Vector2(1.0, 0.0),
	"se": Vector2(0.707, 0.707),
	"s": Vector2(0.0, 1.0),
	"sw": Vector2(-0.707, 0.707),
	"w": Vector2(-1.0, 0.0),
	"nw": Vector2(-0.707, -0.707)
}

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

static func _draw_one_frida_card(frida_state):
	if frida_state.draw_pile.is_empty():
		var next_pile = frida_state.discard_pile.duplicate(true)
		frida_state.discard_pile.clear()
		next_pile.shuffle()
		if next_pile.size() > 3:
			for _skip in range(3):
				frida_state.discard_pile.append(next_pile.pop_back())
		frida_state.draw_pile = next_pile
	if frida_state.draw_pile.is_empty():
		return null
	return frida_state.draw_pile.pop_front()

static func _draw_frida_round_cards(state):
	var frida_state = _ensure_frida_state(state)
	var current_round = int(state.get("round_number", 1))
	if int(frida_state.round_drawn) == current_round and frida_state.phase_cards.size() == 3:
		return frida_state.phase_cards
	if not frida_state.phase_cards.is_empty():
		frida_state.discard_pile.append_array(frida_state.phase_cards)
		frida_state.phase_cards = []
	for _card_index in range(3):
		var drawn = _draw_one_frida_card(frida_state)
		if drawn != null:
			frida_state.phase_cards.append(drawn)
	if current_round == 1 and not frida_state.phase_cards.is_empty():
		var guard = 0
		while guard < 24 and (int(frida_state.phase_cards[0].get("market1", -1)) <= 0 or int(frida_state.phase_cards[0].get("market2", -1)) <= 0):
			frida_state.discard_pile.append(frida_state.phase_cards[0])
			var replacement = _draw_one_frida_card(frida_state)
			if replacement == null:
				break
			frida_state.phase_cards[0] = replacement
			guard += 1
	frida_state.round_drawn = current_round
	return frida_state.phase_cards

static func _frida_side_for_seat(state, seat_index):
	var player = state.players[seat_index]
	var stored_side = int(player.get("frida_side", -1))
	if stored_side >= 0:
		return stored_side
	var automa_index = 0
	for some_player in state.players:
		if str(some_player.control_mode) == "automa_frida":
			if int(some_player.seat_index) == int(seat_index):
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

static func _has_eligible_humans_in_phase_two(state):
	for some_player in state.players:
		var mode = str(some_player.control_mode)
		if mode != "automa_frida" and mode != "automa_robots":
			var seat = int(some_player.seat_index)
			if not state.auction.bought_this_round.has(seat) and not state.auction.round_passed_seats.has(seat):
				return true
	return false

static func _frida_claim_plant_directly(state, seat_index, plant_number):
	var player = state.players[seat_index]
	if player.plants.is_empty():
		player.plants.append(plant_number)
	elif plant_number > int(player.plants[0]):
		player.plants.push_front(plant_number)
	else:
		player.plants.insert(1, plant_number)
	if player.plants.size() > 3:
		player.plants.pop_back()
	state.actual_market.erase(plant_number)
	PlantMarket.draw_replacement(state, GameEngine._max_connected_cities(state))
	state.auction.bought_this_round.append(seat_index)
	state.auction.any_plant_sold_this_round = true
	state.auction["last_winner_seat"] = seat_index
	GameEngine.record_history(state, seat_index, "Claimed Plant #" + str(plant_number))
	GameEngine._advance_phase_two_turn(state)

static func _act_frida(state, seat_index):
	var phase_cards = _draw_frida_round_cards(state)
	var side = _frida_side_for_seat(state, seat_index)
	var phase = int(state.phase)
	var player = state.players[seat_index]

	if phase == 2:
		if bool(state.auction.active):
			GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_AUCTION, {})
			return true
		var market_size = state.actual_market.size() + state.futures_market.size()
		if phase_cards.is_empty() or market_size <= 3:
			if not state.auction.round_passed_seats.has(seat_index):
				state.auction.round_passed_seats.append(seat_index)
			GameEngine.record_history(state, seat_index, "Passed Phase 2")
			GameEngine._advance_phase_two_turn(state)
			return true
		var auction_card = phase_cards[0]
		var market_choice = int(auction_card.get("market1" if side == 0 else "market2", -1))
		var ante = int(auction_card.get("ante1" if side == 0 else "ante2", 0))
		if market_choice > 0 and not state.actual_market.is_empty():
			var idx = clamp(market_choice - 1, 0, state.actual_market.size() - 1)
			var candidate = int(state.actual_market[idx])
			if int(state.round_number) == 1 or not _has_eligible_humans_in_phase_two(state):
				_frida_claim_plant_directly(state, seat_index, candidate)
			else:
				GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_SELECT_PLANT_FOR_AUCTION, {
					plant_number = candidate,
					bid = candidate + ante
				})
			return true
		if not state.auction.round_passed_seats.has(seat_index):
			state.auction.round_passed_seats.append(seat_index)
		GameEngine.record_history(state, seat_index, "Passed Phase 2")
		GameEngine._advance_phase_two_turn(state)
		return true

	if phase == 3:
		var removed_summary = []
		if phase_cards.size() >= 2:
			var resource_card = phase_cards[1]
			var resource_mode = int(resource_card.get("resource1" if side == 0 else "resource2", 0))
			if resource_mode > 0:
				var removed_counts = {}
				for plant_idx in range(player.plants.size()):
					var plant = VW.Database.get_plant(state.deck_id, int(player.plants[plant_idx]))
					if plant == null or plant.is_ecological:
						continue
					var multiplier = 2 if (resource_mode == 2 and plant_idx == 0) else 1
					var needed = int(plant.fuel_cost) * multiplier
					var chosen_fuel = ""
					if plant.is_hybrid:
						var coal_price = ResourceMarket.next_unit_price(state.resource_market, "coal")
						var oil_price = ResourceMarket.next_unit_price(state.resource_market, "oil")
						if coal_price >= 0 and (oil_price < 0 or coal_price <= oil_price):
							chosen_fuel = "coal"
						elif oil_price >= 0:
							chosen_fuel = "oil"
					else:
						chosen_fuel = str(plant.fuel_type)
					if chosen_fuel != "":
						for _unit in range(needed):
							if ResourceMarket.buy_one(state.resource_market, chosen_fuel) < 0:
								break
							removed_counts[chosen_fuel] = int(removed_counts.get(chosen_fuel, 0)) + 1
				for fuel_key in removed_counts.keys():
					removed_summary.append(str(removed_counts[fuel_key]) + " " + fuel_key)
		if not removed_summary.is_empty():
			GameEngine.record_history(state, seat_index, "Removed " + ", ".join(removed_summary) + " from market")
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
					player["city_score"] = int(player.get("city_score", player.built_cities.size())) + 1
					continue
				var build_result = GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_BUILD_CITY, { city_id = target_city })
				if not build_result.accepted:
					player["city_score"] = int(player.get("city_score", player.built_cities.size())) + 1
					continue
				state.frida_state.build_targets[str(seat_index)] = target_city
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_PHASE, {})
		return true

	if phase == 5:
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_POWER_PLANTS, { plants = [] })
		return true
	return false

static func _clockwise_angle_offset(from_vec, dir_vec):
	var from_angle = atan2(from_vec.y, from_vec.x)
	var dir_angle = atan2(dir_vec.y, dir_vec.x)
	var diff = dir_angle - from_angle
	while diff < 0.0:
		diff += TAU
	while diff >= TAU:
		diff -= TAU
	return diff

static func _pick_frida_city(state, seat_index, direction):
	var map_definition = VW.Database.get_map(state.map_id)
	if map_definition == null:
		return ""
	var player = state.players[seat_index]
	var dir_vec = DIRECTION_VECTORS.get(direction, Vector2(0.0, -1.0))

	if player.built_cities.is_empty():
		var start_city = str(map_definition.automa_start_cities.get(direction, ""))
		if start_city != "" and MapGraph.city_build_cost(map_definition, state, seat_index, start_city) >= 0:
			return start_city
		var center = Vector2.ZERO
		var count = 0
		for city_id in map_definition.cities.keys():
			var city = map_definition.cities[city_id]
			if state.active_regions.is_empty() or state.active_regions.has(city.region_id):
				center += city.position
				count += 1
		if count > 0:
			center /= float(count)
		var opposite_vec = -dir_vec
		var best_city = ""
		var best_score = -999999.0
		for city_id in map_definition.cities.keys():
			if MapGraph.city_build_cost(map_definition, state, seat_index, city_id) < 0:
				continue
			var pos = map_definition.cities[city_id].position
			var score = (pos - center).dot(opposite_vec)
			if score > best_score:
				best_score = score
				best_city = city_id
		return best_city

	var anchor = str(state.frida_state.build_targets.get(str(seat_index), player.built_cities[player.built_cities.size() - 1]))
	var visited = {}
	var queue = [anchor]
	visited[anchor] = true
	while not queue.is_empty():
		var current_id = queue.pop_front()
		if current_id != anchor and MapGraph.city_build_cost(map_definition, state, seat_index, current_id) >= 0:
			return current_id
		var current_pos = map_definition.cities[current_id].position
		var edges = map_definition.adjacency.get(current_id, []).duplicate()
		edges.sort_custom(func(edge_a, edge_b):
			var pos_a = map_definition.cities[edge_a.target].position - current_pos
			var pos_b = map_definition.cities[edge_b.target].position - current_pos
			return _clockwise_angle_offset(dir_vec, pos_a) < _clockwise_angle_offset(dir_vec, pos_b)
		)
		for edge in edges:
			var neighbor_id = str(edge.target)
			if visited.has(neighbor_id):
				continue
			var neighbor_city = map_definition.cities.get(neighbor_id, null)
			if neighbor_city == null:
				continue
			if not state.active_regions.is_empty() and not state.active_regions.has(neighbor_city.region_id):
				continue
			visited[neighbor_id] = true
			queue.append(neighbor_id)
	return ""

static func _act_robots(state, seat_index):
	var player = state.players[seat_index]
	var phase = int(state.phase)
	if phase == 2:
		if bool(state.auction.active):
			var plant_number = int(state.auction.plant_number)
			var next_bid = int(state.auction.current_bid) + 1
			var candidates = RobotsExpansion.filter_auction_candidates(state, player)
			var max_cap = RobotsExpansion.max_bid_for_plant(state, player, plant_number)
			var cost = RobotsExpansion.effective_bid_cost(player, next_bid)
			if candidates.has(plant_number) and next_bid <= max_cap and int(player.elektro) >= cost:
				GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PLACE_BID, { amount = next_bid })
			else:
				GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_AUCTION, {})
			return true
		var target_plant = RobotsExpansion.select_auction_target(state, player)
		if target_plant > 0:
			GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_SELECT_PLANT_FOR_AUCTION, { plant_number = target_plant })
			return true
		if int(state.round_number) == 1 and not state.actual_market.is_empty():
			var fallback = int(state.actual_market[0])
			if RobotsExpansion.effective_bid_cost(player, fallback) <= int(player.elektro):
				GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_SELECT_PLANT_FOR_AUCTION, { plant_number = fallback })
				return true
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_PHASE, {})
		return true

	if phase == 3:
		var before_stored = player.stored_resources.duplicate(true)
		RobotsExpansion.execute_phase_three(state, player)
		var bought_parts = []
		for fuel_key in ["coal", "oil", "garbage", "uranium"]:
			var delta = int(player.stored_resources.get(fuel_key, 0)) - int(before_stored.get(fuel_key, 0))
			if delta > 0:
				bought_parts.append(str(delta) + " " + fuel_key)
		if not bought_parts.is_empty():
			GameEngine.record_history(state, seat_index, "Bought " + ", ".join(bought_parts))
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_PHASE, {})
		return true

	if phase == 4:
		var guard = 0
		while guard < 42:
			guard += 1
			var target_city = RobotsExpansion.pick_next_city(state, player)
			if target_city == "":
				break
			var res = GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_BUILD_CITY, { city_id = target_city })
			if not res.accepted:
				break
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_PASS_PHASE, {})
		return true

	if phase == 5:
		var chosen_plants = RobotsExpansion.select_plants_to_power(state, player)
		GameEngine.apply_action(state, seat_index, NetworkProtocol.ACTION_POWER_PLANTS, { plants = chosen_plants })
		return true
	return false
