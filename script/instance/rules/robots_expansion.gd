extends RefCounted

const ResourceMarket = preload("res://script/instance/rules/resource_market.gd")
const MapGraph = preload("res://script/instance/rules/map_graph.gd")

const FIRST_CITY_LAST_CHOICE = "FIRST_CITY_LAST_CHOICE"
const FIRST_CITY_RANDOM_CHOICE = "FIRST_CITY_RANDOM_CHOICE"
const FIRST_CITY_EARLY_CHOICE_ALL = "FIRST_CITY_EARLY_CHOICE_ALL"
const FIRST_CITY_PLAYERS_CHOICE = "FIRST_CITY_PLAYERS_CHOICE"
const FIRST_CITY_BIDDING_CHOICE = "FIRST_CITY_BIDDING_CHOICE"
const FIRST_CITY_DECIDING_CHOICE = "FIRST_CITY_DECIDING_CHOICE"

const AUCTION_CHEAPEST_RESOURCES = "AUCTION_CHEAPEST_RESOURCES"
const AUCTION_FIRST_CHOICE_MIN_BID = "AUCTION_FIRST_CHOICE_MIN_BID"
const AUCTION_MOST_CITIES = "AUCTION_MOST_CITIES"
const AUCTION_HIGHEST_NUMBER = "AUCTION_HIGHEST_NUMBER"
const AUCTION_SECOND_SMALLEST = "AUCTION_SECOND_SMALLEST"
const AUCTION_ALL_PLANTS = "AUCTION_ALL_PLANTS"

const RESOURCE_NORMAL_AND_UNDER_5 = "RESOURCE_NORMAL_AND_UNDER_5"
const RESOURCE_ALL = "RESOURCE_ALL"
const RESOURCE_LAST_ALL_ELSE_NORMAL = "RESOURCE_LAST_ALL_ELSE_NORMAL"
const RESOURCE_NORMAL = "RESOURCE_NORMAL"
const RESOURCE_NORMAL_AND_LEAST_AVAILABLE = "RESOURCE_NORMAL_AND_LEAST_AVAILABLE"
const RESOURCE_ODD_NORMAL_EVEN_ALL = "RESOURCE_ODD_NORMAL_EVEN_ALL"

const BUILD_LAST_PLAYER_CHOOSES = "BUILD_LAST_PLAYER_CHOOSES"
const BUILD_MAX_FIRST_PLAYER = "BUILD_MAX_FIRST_PLAYER"
const BUILD_ONLY_SUPPLIED = "BUILD_ONLY_SUPPLIED"
const BUILD_STEP1_UNDER_7_NEVER_FIRST = "BUILD_STEP1_UNDER_7_NEVER_FIRST"
const BUILD_STEP_1_2_3 = "BUILD_STEP_1_2_3"
const BUILD_ALL_CITIES = "BUILD_ALL_CITIES"

const ABILITY_START_100_ELEKTRO = "ABILITY_START_100_ELEKTRO"
const ABILITY_ALWAYS_LAST_ORDER = "ABILITY_ALWAYS_LAST_ORDER"
const ABILITY_HALF_BID = "ABILITY_HALF_BID"
const ABILITY_CITIES_COST_10 = "ABILITY_CITIES_COST_10"
const ABILITY_FIRST_CITY_FREE = "ABILITY_FIRST_CITY_FREE"
const ABILITY_INCOME_PLUS_1 = "ABILITY_INCOME_PLUS_1"

const SLOT_ONE_POOL = [
	FIRST_CITY_LAST_CHOICE,
	FIRST_CITY_RANDOM_CHOICE,
	FIRST_CITY_EARLY_CHOICE_ALL,
	FIRST_CITY_PLAYERS_CHOICE,
	FIRST_CITY_BIDDING_CHOICE,
	FIRST_CITY_DECIDING_CHOICE
]

const SLOT_TWO_POOL = [
	AUCTION_CHEAPEST_RESOURCES,
	AUCTION_FIRST_CHOICE_MIN_BID,
	AUCTION_MOST_CITIES,
	AUCTION_HIGHEST_NUMBER,
	AUCTION_SECOND_SMALLEST,
	AUCTION_ALL_PLANTS
]

const SLOT_THREE_POOL = [
	RESOURCE_NORMAL_AND_UNDER_5,
	RESOURCE_ALL,
	RESOURCE_LAST_ALL_ELSE_NORMAL,
	RESOURCE_NORMAL,
	RESOURCE_NORMAL_AND_LEAST_AVAILABLE,
	RESOURCE_ODD_NORMAL_EVEN_ALL
]

const SLOT_FOUR_POOL = [
	BUILD_LAST_PLAYER_CHOOSES,
	BUILD_MAX_FIRST_PLAYER,
	BUILD_ONLY_SUPPLIED,
	BUILD_STEP1_UNDER_7_NEVER_FIRST,
	BUILD_STEP_1_2_3,
	BUILD_ALL_CITIES
]

const SLOT_FIVE_POOL = [
	ABILITY_START_100_ELEKTRO,
	ABILITY_ALWAYS_LAST_ORDER,
	ABILITY_HALF_BID,
	ABILITY_CITIES_COST_10,
	ABILITY_FIRST_CITY_FREE,
	ABILITY_INCOME_PLUS_1
]

static func create_default_profile(robot_index):
	var idx = int(robot_index) % 6
	return {
		first_city = SLOT_ONE_POOL[idx],
		auction = SLOT_TWO_POOL[idx],
		resource = SLOT_THREE_POOL[idx],
		build = SLOT_FOUR_POOL[idx],
		ability = SLOT_FIVE_POOL[idx]
	}

static func create_random_profiles(robot_count):
	var pool_one = SLOT_ONE_POOL.duplicate()
	if robot_count >= 2:
		pool_one.erase(FIRST_CITY_EARLY_CHOICE_ALL)
	var pool_two = SLOT_TWO_POOL.duplicate()
	var pool_three = SLOT_THREE_POOL.duplicate()
	var pool_four = SLOT_FOUR_POOL.duplicate()
	var pool_five = SLOT_FIVE_POOL.duplicate()
	pool_one.shuffle()
	pool_two.shuffle()
	pool_three.shuffle()
	pool_four.shuffle()
	pool_five.shuffle()
	var profiles = []
	for index in range(robot_count):
		profiles.append({
			first_city = pool_one[index % pool_one.size()],
			auction = pool_two[index % pool_two.size()],
			resource = pool_three[index % pool_three.size()],
			build = pool_four[index % pool_four.size()],
			ability = pool_five[index % pool_five.size()]
		})
	return profiles

static func has_ability(player, ability_name):
	var profile = player.get("robot_profile", {})
	return str(profile.get("ability", "")) == ability_name

static func effective_bid_cost(player, bid_amount):
	if has_ability(player, ABILITY_HALF_BID):
		return int(floor(float(bid_amount) / 2.0))
	return int(bid_amount)

static func total_power_capacity(state, player):
	var total = 0
	for plant_number in player.get("plants", []):
		var plant = VW.Database.get_plant(state.deck_id, int(plant_number))
		if plant != null:
			total += int(plant.cities_powered)
	return total

static func filter_auction_candidates(state, player):
	var candidates = []
	var min_owned_number = 999999
	var min_owned_cities = 999999
	for owned_number in player.get("plants", []):
		min_owned_number = min(min_owned_number, int(owned_number))
		var owned_plant = VW.Database.get_plant(state.deck_id, int(owned_number))
		if owned_plant != null:
			min_owned_cities = min(min_owned_cities, int(owned_plant.cities_powered))

	for plant_number in state.actual_market:
		var num = int(plant_number)
		if num <= 0:
			continue
		var plant = VW.Database.get_plant(state.deck_id, num)
		if plant == null:
			continue
		if not player.plants.is_empty() and num < min_owned_number:
			continue
		if player.plants.size() >= 3 and int(plant.cities_powered) < min_owned_cities:
			continue
		if effective_bid_cost(player, num) > int(player.elektro):
			continue
		candidates.append(num)
	return candidates

static func max_bid_for_plant(state, player, plant_number):
	var profile = player.get("robot_profile", {})
	var auction_rule = str(profile.get("auction", AUCTION_CHEAPEST_RESOURCES))
	var base_num = int(plant_number)
	if auction_rule == AUCTION_CHEAPEST_RESOURCES:
		return base_num + 5
	if auction_rule == AUCTION_FIRST_CHOICE_MIN_BID:
		return base_num
	if auction_rule == AUCTION_MOST_CITIES:
		return base_num + 10
	if auction_rule == AUCTION_HIGHEST_NUMBER:
		return base_num + player.built_cities.size()
	if auction_rule == AUCTION_SECOND_SMALLEST:
		return base_num
	if auction_rule == AUCTION_ALL_PLANTS:
		return base_num + 1
	return base_num

static func _plant_cheapest_fuel_unit_cost(state, plant):
	if plant.is_ecological:
		return 0
	var best = 999999
	for fuel_type in plant.accepted_fuels:
		var price = ResourceMarket.next_unit_price(state.resource_market, fuel_type)
		if price >= 0 and price < best:
			best = price
	return best

static func select_auction_target(state, player):
	if total_power_capacity(state, player) >= player.built_cities.size() + 2:
		return -1
	var candidates = filter_auction_candidates(state, player)
	if candidates.is_empty():
		return -1
	if candidates.size() == 1:
		return candidates[0]
	var profile = player.get("robot_profile", {})
	var auction_rule = str(profile.get("auction", AUCTION_CHEAPEST_RESOURCES))
	if auction_rule == AUCTION_CHEAPEST_RESOURCES:
		candidates.sort_custom(func(first_num, second_num):
			var first_plant = VW.Database.get_plant(state.deck_id, first_num)
			var second_plant = VW.Database.get_plant(state.deck_id, second_num)
			var first_cost = _plant_cheapest_fuel_unit_cost(state, first_plant)
			var second_cost = _plant_cheapest_fuel_unit_cost(state, second_plant)
			if first_cost != second_cost:
				return first_cost < second_cost
			return first_num > second_num
		)
		return candidates[0]
	if auction_rule == AUCTION_MOST_CITIES:
		candidates.sort_custom(func(first_num, second_num):
			var first_plant = VW.Database.get_plant(state.deck_id, first_num)
			var second_plant = VW.Database.get_plant(state.deck_id, second_num)
			if int(first_plant.cities_powered) != int(second_plant.cities_powered):
				return int(first_plant.cities_powered) > int(second_plant.cities_powered)
			return first_num > second_num
		)
		return candidates[0]
	if auction_rule == AUCTION_HIGHEST_NUMBER:
		candidates.sort()
		return candidates[candidates.size() - 1]
	if auction_rule == AUCTION_SECOND_SMALLEST:
		candidates.sort()
		return candidates[1]
	candidates.sort()
	return candidates[0]

static func _refill_rate_for_resource(state, resource_type):
	var map_definition = VW.Database.get_map(state.map_id)
	var seat_count = str(state.players.size())
	var refill = [[3, 2, 1, 1], [4, 2, 2, 1], [3, 4, 3, 1]]
	if map_definition != null and map_definition.player_count_info.has(seat_count):
		refill = map_definition.player_count_info[seat_count].get("refill", refill)
	var step_idx = clamp(int(state.step) - 1, 0, refill.size() - 1)
	var rates = refill[step_idx]
	var order = ["coal", "oil", "garbage", "uranium"]
	var resource_idx = order.find(resource_type)
	if resource_idx >= 0 and resource_idx < rates.size():
		return int(rates[resource_idx])
	return 99

static func _sorted_plants_for_resources(state, player):
	var single_plants = []
	var hybrid_plants = []
	for plant_number in player.get("plants", []):
		var plant = VW.Database.get_plant(state.deck_id, int(plant_number))
		if plant == null or plant.is_ecological or int(plant.fuel_cost) <= 0:
			continue
		if plant.is_hybrid:
			hybrid_plants.append(plant)
		else:
			single_plants.append(plant)

	var priority_order = ["coal", "oil", "uranium", "garbage"]
	var comparator = func(first_plant, second_plant):
		if int(first_plant.cities_powered) != int(second_plant.cities_powered):
			return int(first_plant.cities_powered) > int(second_plant.cities_powered)
		var first_cost = _plant_cheapest_fuel_unit_cost(state, first_plant) * int(first_plant.fuel_cost)
		var second_cost = _plant_cheapest_fuel_unit_cost(state, second_plant) * int(second_plant.fuel_cost)
		if first_cost != second_cost:
			return first_cost < second_cost
		var first_fuel = str(first_plant.accepted_fuels[0]) if not first_plant.accepted_fuels.is_empty() else "coal"
		var second_fuel = str(second_plant.accepted_fuels[0]) if not second_plant.accepted_fuels.is_empty() else "coal"
		var first_refill = _refill_rate_for_resource(state, first_fuel)
		var second_refill = _refill_rate_for_resource(state, second_fuel)
		if first_refill != second_refill:
			return first_refill < second_refill
		return priority_order.find(first_fuel) < priority_order.find(second_fuel)

	single_plants.sort_custom(comparator)
	hybrid_plants.sort_custom(comparator)
	return single_plants + hybrid_plants

static func _cheapest_fuel_for_plant(state, plant):
	var best_fuel = ""
	var best_price = 999999
	for fuel_type in plant.accepted_fuels:
		var price = ResourceMarket.next_unit_price(state.resource_market, fuel_type)
		if price >= 0 and price < best_price:
			best_price = price
			best_fuel = fuel_type
	return best_fuel

static func _buy_cheapest_token_for_plant(state, player, plant, max_price = 999999):
	var best_fuel = _cheapest_fuel_for_plant(state, plant)
	if best_fuel == "":
		return false
	var price = ResourceMarket.next_unit_price(state.resource_market, best_fuel)
	if price < 0 or price > max_price or int(player.elektro) < price:
		return false
	if not ResourceMarket.can_store_resource(player, state.deck_id, best_fuel, 1):
		return false
	ResourceMarket.buy_one(state.resource_market, best_fuel)
	player.elektro -= price
	player.stored_resources[best_fuel] = int(player.stored_resources.get(best_fuel, 0)) + 1
	return true

static func execute_phase_three(state, player):
	var profile = player.get("robot_profile", {})
	var rule = str(profile.get("resource", RESOURCE_NORMAL))
	if rule == RESOURCE_LAST_ALL_ELSE_NORMAL:
		var is_last = not state.turn_order.is_empty() and int(state.turn_order[state.turn_order.size() - 1]) == int(player.seat_index)
		rule = RESOURCE_ALL if is_last else RESOURCE_NORMAL
	elif rule == RESOURCE_ODD_NORMAL_EVEN_ALL:
		rule = RESOURCE_NORMAL if int(state.round_number) % 2 == 1 else RESOURCE_ALL

	var ordered_plants = _sorted_plants_for_resources(state, player)
	var remaining_needed = {}
	for plant in ordered_plants:
		remaining_needed[plant.number] = int(plant.fuel_cost)

	var simulated_stored = player.stored_resources.duplicate(true)
	for plant in ordered_plants:
		var need = int(plant.fuel_cost)
		if not plant.is_hybrid:
			var fuel = str(plant.fuel_type)
			var have = int(simulated_stored.get(fuel, 0))
			var used = min(have, need)
			simulated_stored[fuel] = have - used
			remaining_needed[plant.number] = need - used
	for plant in ordered_plants:
		if plant.is_hybrid:
			var need = int(plant.fuel_cost)
			var used_total = 0
			for fuel in plant.accepted_fuels:
				var have = int(simulated_stored.get(fuel, 0))
				var used = min(have, need - used_total)
				simulated_stored[fuel] = have - used
				used_total += used
			remaining_needed[plant.number] = need - used_total

	for plant in ordered_plants:
		var to_buy = int(remaining_needed.get(plant.number, 0))
		for _unit in range(to_buy):
			if not _buy_cheapest_token_for_plant(state, player, plant):
				break

	if rule == RESOURCE_NORMAL:
		return

	if rule == RESOURCE_ALL or rule == RESOURCE_NORMAL_AND_UNDER_5:
		var price_cap = 4 if rule == RESOURCE_NORMAL_AND_UNDER_5 else 999999
		while true:
			var bought_any = false
			var best_plant = null
			var best_fuel = ""
			var best_price = 999999
			for plant in ordered_plants:
				var fuel = _cheapest_fuel_for_plant(state, plant)
				if fuel == "":
					continue
				var price = ResourceMarket.next_unit_price(state.resource_market, fuel)
				if price >= 0 and price <= price_cap and int(player.elektro) >= price and ResourceMarket.can_store_resource(player, state.deck_id, fuel, 1):
					if price < best_price:
						best_price = price
						best_fuel = fuel
						best_plant = plant
			if best_plant != null and best_fuel != "":
				ResourceMarket.buy_one(state.resource_market, best_fuel)
				player.elektro -= best_price
				player.stored_resources[best_fuel] = int(player.stored_resources.get(best_fuel, 0)) + 1
				bought_any = true
			if not bought_any:
				break
	elif rule == RESOURCE_NORMAL_AND_LEAST_AVAILABLE:
		var counts = {
			coal = ResourceMarket.total_stock(state.resource_market, "coal"),
			oil = ResourceMarket.total_stock(state.resource_market, "oil"),
			garbage = ResourceMarket.total_stock(state.resource_market, "garbage"),
			uranium = ResourceMarket.total_stock(state.resource_market, "uranium") * 3
		}
		var lowest_val = 999999
		var lowest_type = ""
		var tied = false
		for key in counts.keys():
			var val = int(counts[key])
			if val < lowest_val:
				lowest_val = val
				lowest_type = key
				tied = false
			elif val == lowest_val:
				tied = true
		if not tied and lowest_type != "":
			while true:
				var price = ResourceMarket.next_unit_price(state.resource_market, lowest_type)
				if price < 0 or int(player.elektro) < price:
					break
				if not ResourceMarket.can_store_resource(player, state.deck_id, lowest_type, 1):
					break
				ResourceMarket.buy_one(state.resource_market, lowest_type)
				player.elektro -= price
				player.stored_resources[lowest_type] = int(player.stored_resources.get(lowest_type, 0)) + 1

static func _first_human_player(state):
	for seat in state.turn_order:
		var candidate = state.players[int(seat)]
		var mode = str(candidate.control_mode)
		if mode != "automa_frida" and mode != "automa_robots":
			return candidate
	return null

static func _city_cost_for_robot(map_definition, state, player, city_id, forbid_pass_through_available = false):
	var occupants = state.city_occupancy.get(city_id, [])
	var step = int(state.step)
	if occupants.has(player.seat_index) or occupants.size() >= step:
		return -1
	var connection_cost = 0
	if not player.built_cities.is_empty():
		if forbid_pass_through_available:
			connection_cost = _restricted_connection_cost(map_definition, state, player, city_id)
		else:
			connection_cost = MapGraph.shortest_connection_cost(map_definition, player.built_cities, city_id, state.active_regions)
	if connection_cost >= MapGraph.INFINITY_COST:
		return -1
	var slot_cost = 10 if has_ability(player, ABILITY_CITIES_COST_10) else (10 + occupants.size() * 5)
	if has_ability(player, ABILITY_FIRST_CITY_FREE) and int(player.get("built_this_round", 0)) == 0:
		return 0
	return connection_cost + slot_cost

static func _restricted_connection_cost(map_definition, state, player, target_city_id):
	var distances = {}
	var unvisited = []
	for city_id in map_definition.cities.keys():
		distances[city_id] = MapGraph.INFINITY_COST
		unvisited.append(city_id)
	for owned_city in player.built_cities:
		distances[owned_city] = 0
	while not unvisited.is_empty():
		var best_index = 0
		var best_distance = distances[unvisited[0]]
		for index in range(1, unvisited.size()):
			var cand_dist = distances[unvisited[index]]
			if cand_dist < best_distance:
				best_distance = cand_dist
				best_index = index
		var current_city = unvisited[best_index]
		unvisited.remove_at(best_index)
		if best_distance >= MapGraph.INFINITY_COST:
			break
		if current_city == target_city_id:
			return best_distance
		if not player.built_cities.has(current_city):
			var occ = state.city_occupancy.get(current_city, [])
			if occ.size() < int(state.step) and not occ.has(player.seat_index):
				continue
		for edge in map_definition.adjacency.get(current_city, []):
			var neighbor_id = edge.target
			var neighbor_city = map_definition.cities.get(neighbor_id, null)
			if neighbor_city == null:
				continue
			if not state.active_regions.is_empty() and not state.active_regions.has(neighbor_city.region_id):
				continue
			var alternative = best_distance + int(edge.cost)
			if alternative < distances[neighbor_id]:
				distances[neighbor_id] = alternative
	return distances.get(target_city_id, MapGraph.INFINITY_COST)

static func pick_next_city(state, player):
	var map_definition = VW.Database.get_map(state.map_id)
	if map_definition == null:
		return ""
	var profile = player.get("robot_profile", {})
	var build_rule = str(profile.get("build", BUILD_ALL_CITIES))
	var built_this_round = int(player.get("built_this_round", 0))
	var first_human = _first_human_player(state)

	if build_rule == BUILD_MAX_FIRST_PLAYER and first_human != null:
		if player.built_cities.size() >= first_human.built_cities.size():
			return ""
	if build_rule == BUILD_ONLY_SUPPLIED:
		if player.built_cities.size() >= total_power_capacity(state, player):
			return ""
	if build_rule == BUILD_STEP1_UNDER_7_NEVER_FIRST:
		if int(state.step) == 1 and player.built_cities.size() >= 6:
			return ""
	if build_rule == BUILD_STEP_1_2_3:
		if built_this_round >= int(state.step):
			return ""

	var forbid_pass_through = (build_rule == BUILD_LAST_PLAYER_CHOOSES)
	var first_human_cities = first_human.built_cities if first_human != null else []

	if int(state.round_number) == 1 and player.built_cities.is_empty():
		var first_city_rule = str(profile.get("first_city", FIRST_CITY_RANDOM_CHOICE))
		if first_city_rule == FIRST_CITY_RANDOM_CHOICE and not state.active_regions.is_empty():
			var region_id = state.active_regions[randi() % state.active_regions.size()]
			var region_cities = []
			for city_id in map_definition.cities.keys():
				if map_definition.cities[city_id].region_id == region_id:
					var cost = _city_cost_for_robot(map_definition, state, player, city_id, forbid_pass_through)
					if cost >= 0 and int(player.elektro) >= cost:
						if build_rule == BUILD_STEP1_UNDER_7_NEVER_FIRST and first_human_cities.has(city_id):
							continue
						region_cities.append(city_id)
			if not region_cities.is_empty():
				return region_cities[randi() % region_cities.size()]

	var best_cost = 999999
	var tied_cities = []
	for city_id in map_definition.cities.keys():
		if build_rule == BUILD_STEP1_UNDER_7_NEVER_FIRST and first_human_cities.has(city_id):
			continue
		var cost = _city_cost_for_robot(map_definition, state, player, city_id, forbid_pass_through)
		if cost < 0 or int(player.elektro) < cost:
			continue
		if cost < best_cost:
			best_cost = cost
			tied_cities = [city_id]
		elif cost == best_cost:
			tied_cities.append(city_id)
	if tied_cities.is_empty():
		return ""
	return tied_cities[randi() % tied_cities.size()]

static func select_plants_to_power(state, player):
	var ordered = _sorted_plants_for_resources(state, player)
	var ecological = []
	for plant_number in player.get("plants", []):
		var plant = VW.Database.get_plant(state.deck_id, int(plant_number))
		if plant != null and plant.is_ecological:
			ecological.append(int(plant_number))
	var chosen = ecological.duplicate()
	var powered = 0
	for plant_number in ecological:
		var eco_plant = VW.Database.get_plant(state.deck_id, plant_number)
		if eco_plant != null:
			powered += int(eco_plant.cities_powered)
	var target = player.built_cities.size()
	var sim_stored = player.stored_resources.duplicate(true)
	for plant in ordered:
		if powered >= target:
			break
		var needed = int(plant.fuel_cost)
		if not plant.is_hybrid:
			var fuel = str(plant.fuel_type)
			if int(sim_stored.get(fuel, 0)) >= needed:
				sim_stored[fuel] = int(sim_stored.get(fuel, 0)) - needed
				chosen.append(int(plant.number))
				powered += int(plant.cities_powered)
		else:
			var avail = 0
			for fuel in plant.accepted_fuels:
				avail += int(sim_stored.get(fuel, 0))
			if avail >= needed:
				var rem = needed
				for fuel in plant.accepted_fuels:
					var take = min(int(sim_stored.get(fuel, 0)), rem)
					sim_stored[fuel] = int(sim_stored.get(fuel, 0)) - take
					rem -= take
				chosen.append(int(plant.number))
				powered += int(plant.cities_powered)
	return chosen
