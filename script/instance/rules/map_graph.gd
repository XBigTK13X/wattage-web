extends RefCounted

const INFINITY_COST = 999999

static func shortest_connection_cost(map_definition, player_cities, target_city_id, active_regions):
	if map_definition == null or not map_definition.cities.has(target_city_id):
		return INFINITY_COST
	var target_city = map_definition.cities[target_city_id]
	if not active_regions.is_empty() and not active_regions.has(target_city.region_id):
		return INFINITY_COST
	if player_cities.is_empty():
		return 0
	if player_cities.has(target_city_id):
		return INFINITY_COST

	var distances = {}
	var unvisited = []
	for city_id in map_definition.cities.keys():
		distances[city_id] = INFINITY_COST
		unvisited.append(city_id)
	for owned_city in player_cities:
		distances[owned_city] = 0

	while not unvisited.is_empty():
		var best_index = 0
		var best_distance = distances[unvisited[0]]
		for index in range(1, unvisited.size()):
			var candidate_distance = distances[unvisited[index]]
			if candidate_distance < best_distance:
				best_distance = candidate_distance
				best_index = index
		var current_city = unvisited[best_index]
		unvisited.remove_at(best_index)
		if best_distance >= INFINITY_COST:
			break
		if current_city == target_city_id:
			return best_distance
		for edge in map_definition.adjacency.get(current_city, []):
			var neighbor_id = edge.target
			var neighbor_city = map_definition.cities.get(neighbor_id, null)
			if neighbor_city == null:
				continue
			if not active_regions.is_empty() and not active_regions.has(neighbor_city.region_id):
				continue
			var alternative = best_distance + int(edge.cost)
			if alternative < distances[neighbor_id]:
				distances[neighbor_id] = alternative
	return distances.get(target_city_id, INFINITY_COST)

static func city_build_cost(map_definition, game_state, seat_index, target_city_id):
	var occupants = game_state.city_occupancy.get(target_city_id, [])
	var step = int(game_state.step)
	if occupants.has(seat_index) or occupants.size() >= step:
		return -1
	var player = game_state.players[seat_index]
	var connection_cost = shortest_connection_cost(map_definition, player.built_cities, target_city_id, game_state.active_regions)
	if connection_cost >= INFINITY_COST:
		return -1
	var slot_cost = 10 + occupants.size() * 5
	return connection_cost + slot_cost
