extends RefCounted

const STANDARD_PRICES = [1, 2, 3, 4, 5, 6, 7, 8]
const URANIUM_PRICES = [1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16]

static func create_market(start_resources):
	var coal_start = int(start_resources[0]) if start_resources.size() > 0 else 1
	var oil_start = int(start_resources[1]) if start_resources.size() > 1 else 3
	var garbage_start = int(start_resources[2]) if start_resources.size() > 2 else 7
	var uranium_start = int(start_resources[3]) if start_resources.size() > 3 else 14
	return {
		coal = _build_bins(STANDARD_PRICES, 3, coal_start),
		oil = _build_bins(STANDARD_PRICES, 3, oil_start),
		garbage = _build_bins(STANDARD_PRICES, 3, garbage_start),
		uranium = _build_bins(URANIUM_PRICES, 1, uranium_start)
	}

static func _build_bins(prices, capacity, minimum_fill_price):
	var bins = []
	for price in prices:
		bins.append({
			price = price,
			capacity = capacity,
			amount = capacity if price >= minimum_fill_price else 0
		})
	return bins

static func next_unit_price(market, resource_type):
	var bins = market.get(resource_type, [])
	for bin_entry in bins:
		if int(bin_entry.amount) > 0:
			return int(bin_entry.price)
	return -1

static func total_stock(market, resource_type):
	var total = 0
	for bin_entry in market.get(resource_type, []):
		total += int(bin_entry.amount)
	return total

static func buy_one(market, resource_type):
	var bins = market.get(resource_type, [])
	for bin_entry in bins:
		if int(bin_entry.amount) > 0:
			bin_entry.amount = int(bin_entry.amount) - 1
			return int(bin_entry.price)
	return -1

static func restock(market, resource_type, refill_amount, held_by_players):
	var max_supply = 12 if resource_type == "uranium" else 24
	var current_market_stock = total_stock(market, resource_type)
	var available_supply = max(0, max_supply - current_market_stock - int(held_by_players))
	var to_add = min(int(refill_amount), available_supply)
	var bins = market.get(resource_type, [])
	var index = bins.size() - 1
	while index >= 0 and to_add > 0:
		var bin_entry = bins[index]
		var space = int(bin_entry.capacity) - int(bin_entry.amount)
		if space > 0:
			var added = min(space, to_add)
			bin_entry.amount = int(bin_entry.amount) + added
			to_add -= added
		index -= 1

static func can_store_resource(player, deck_id, resource_type, add_amount = 1):
	var stored = player.get("stored_resources", {})
	var next_coal = int(stored.get("coal", 0)) + (add_amount if resource_type == "coal" else 0)
	var next_oil = int(stored.get("oil", 0)) + (add_amount if resource_type == "oil" else 0)
	var next_garbage = int(stored.get("garbage", 0)) + (add_amount if resource_type == "garbage" else 0)
	var next_uranium = int(stored.get("uranium", 0)) + (add_amount if resource_type == "uranium" else 0)

	var pure_coal_cap = 0
	var pure_oil_cap = 0
	var pure_garbage_cap = 0
	var pure_uranium_cap = 0
	var hybrid_oil_coal_cap = 0
	var hybrid_oil_garbage_cap = 0

	for plant_number in player.get("plants", []):
		var plant = VW.Database.get_plant(deck_id, int(plant_number))
		if plant == null:
			continue
		var cap = int(plant.fuel_cost) * 2
		if plant.fuel_type == "coal":
			pure_coal_cap += cap
		elif plant.fuel_type == "oil":
			pure_oil_cap += cap
		elif plant.fuel_type == "garbage":
			pure_garbage_cap += cap
		elif plant.fuel_type == "uranium":
			pure_uranium_cap += cap
		elif plant.fuel_type == "hybrid_oil_coal":
			hybrid_oil_coal_cap += cap
		elif plant.fuel_type == "hybrid_oil_garbage":
			hybrid_oil_garbage_cap += cap

	if next_uranium > pure_uranium_cap:
		return false
	var overflow_coal = max(0, next_coal - pure_coal_cap)
	var overflow_garbage = max(0, next_garbage - pure_garbage_cap)
	if overflow_coal > hybrid_oil_coal_cap:
		return false
	if overflow_garbage > hybrid_oil_garbage_cap:
		return false
	var remaining_hybrid_for_oil = (hybrid_oil_coal_cap - overflow_coal) + (hybrid_oil_garbage_cap - overflow_garbage)
	return next_oil <= pure_oil_cap + remaining_hybrid_for_oil

static func clamp_stored_resources(player, deck_id):
	var stored = player.get("stored_resources", {})
	var pure_coal_cap = 0
	var pure_oil_cap = 0
	var pure_garbage_cap = 0
	var pure_uranium_cap = 0
	var hybrid_oil_coal_cap = 0
	var hybrid_oil_garbage_cap = 0

	for plant_number in player.get("plants", []):
		var plant = VW.Database.get_plant(deck_id, int(plant_number))
		if plant == null:
			continue
		var cap = int(plant.fuel_cost) * 2
		if plant.fuel_type == "coal":
			pure_coal_cap += cap
		elif plant.fuel_type == "oil":
			pure_oil_cap += cap
		elif plant.fuel_type == "garbage":
			pure_garbage_cap += cap
		elif plant.fuel_type == "uranium":
			pure_uranium_cap += cap
		elif plant.fuel_type == "hybrid_oil_coal":
			hybrid_oil_coal_cap += cap
		elif plant.fuel_type == "hybrid_oil_garbage":
			hybrid_oil_garbage_cap += cap

	stored["uranium"] = min(int(stored.get("uranium", 0)), pure_uranium_cap)
	stored["coal"] = min(int(stored.get("coal", 0)), pure_coal_cap + hybrid_oil_coal_cap)
	stored["garbage"] = min(int(stored.get("garbage", 0)), pure_garbage_cap + hybrid_oil_garbage_cap)
	var overflow_coal = max(0, int(stored.get("coal", 0)) - pure_coal_cap)
	var overflow_garbage = max(0, int(stored.get("garbage", 0)) - pure_garbage_cap)
	var remaining_hybrid_for_oil = (hybrid_oil_coal_cap - overflow_coal) + (hybrid_oil_garbage_cap - overflow_garbage)
	stored["oil"] = min(int(stored.get("oil", 0)), pure_oil_cap + remaining_hybrid_for_oil)
