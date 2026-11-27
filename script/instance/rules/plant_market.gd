extends RefCounted

static func setup_deck_and_market(deck_id, removed_count):
	var deck = VW.Database.get_deck(deck_id)
	if deck == null:
		return { actual = [], futures = [], draw_pile = [] }

	var sorted_cards = []
	var step_three_present = false
	for card in deck.cards:
		if card.is_step_three:
			step_three_present = true
		else:
			sorted_cards.append(card.number)
	sorted_cards.sort()

	var actual = []
	var futures = []
	var pool = []
	var plant_thirteen_index = -1

	for index in range(sorted_cards.size()):
		var plant_number = sorted_cards[index]
		if index < 4:
			actual.append(plant_number)
		elif index < 8:
			futures.append(plant_number)
		else:
			if plant_number == 13 and plant_thirteen_index == -1:
				plant_thirteen_index = pool.size()
			pool.append(plant_number)

	var top_card = -1
	if plant_thirteen_index != -1:
		top_card = pool[plant_thirteen_index]
		pool.remove_at(plant_thirteen_index)

	pool.shuffle()
	var trim_amount = min(int(removed_count), pool.size())
	for _trim in range(trim_amount):
		pool.pop_back()

	if top_card != -1:
		pool.push_front(top_card)
	if step_three_present:
		pool.append(0)

	return {
		actual = actual,
		futures = futures,
		draw_pile = pool
	}

static func sort_market(state):
	var combined = []
	for plant_number in state.actual_market:
		if int(plant_number) > 0:
			combined.append(int(plant_number))
	for plant_number in state.futures_market:
		if int(plant_number) > 0:
			combined.append(int(plant_number))
	combined.sort()

	var step = int(state.step)
	var pending_step_three = bool(state.get("step_three_pending", false))
	state.actual_market.clear()
	state.futures_market.clear()
	if step == 3:
		for plant_number in combined:
			state.actual_market.append(plant_number)
	else:
		var actual_limit = min(4, combined.size())
		for index in range(combined.size()):
			if index < actual_limit:
				state.actual_market.append(combined[index])
			else:
				state.futures_market.append(combined[index])
		if pending_step_three and int(state.get("phase", 0)) == 2:
			state.futures_market.append(0)

static func draw_replacement(state, max_cities = 0):
	if state.draw_pile.is_empty():
		sort_market(state)
		return false
	var next_card = int(state.draw_pile.pop_front())
	if next_card == 0:
		var phase = int(state.get("phase", 2))
		state.draw_pile.shuffle()
		if phase == 2:
			state["step_three_pending"] = true
			sort_market(state)
			return true
		var combined = []
		for plant_number in state.actual_market:
			if int(plant_number) > 0:
				combined.append(int(plant_number))
		for plant_number in state.futures_market:
			if int(plant_number) > 0:
				combined.append(int(plant_number))
		combined.sort()
		if not combined.is_empty():
			combined.pop_front()
		state.actual_market = combined
		state.futures_market.clear()
		if phase == 4:
			state["step_three_pending"] = true
		else:
			state.step = 3
			state["step_three_pending"] = false
		sort_market(state)
		return true
	state.futures_market.append(next_card)
	sort_market(state)
	if max_cities > 0:
		remove_plants_at_or_below(state, max_cities)
	return false

static func finalize_step_three_if_pending(state):
	if not bool(state.get("step_three_pending", false)):
		return false
	var combined = []
	for plant_number in state.actual_market:
		if int(plant_number) > 0:
			combined.append(int(plant_number))
	for plant_number in state.futures_market:
		if int(plant_number) > 0:
			combined.append(int(plant_number))
	combined.sort()
	if int(state.get("phase", 2)) == 2 and not combined.is_empty():
		combined.pop_front()
	state.actual_market = combined
	state.futures_market.clear()
	state.step = 3
	state["step_three_pending"] = false
	sort_market(state)
	return true

static func remove_plants_at_or_below(state, threshold):
	var removed_any = false
	var target_size = 6 if int(state.step) == 3 else 8
	while true:
		var combined = state.actual_market + state.futures_market
		var kept = []
		var removed_pass = false
		for plant_number in combined:
			var num = int(plant_number)
			if num > 0 and num <= int(threshold):
				removed_pass = true
				removed_any = true
			elif num > 0:
				kept.append(num)
		if not removed_pass:
			break
		state.actual_market = kept
		state.futures_market.clear()
		sort_market(state)
		while state.actual_market.size() + state.futures_market.size() < target_size and not state.draw_pile.is_empty():
			var step_three_triggered = draw_replacement(state, 0)
			if step_three_triggered:
				target_size = 6
				break
		sort_market(state)
	return removed_any

static func cycle_bureaucracy_market(state):
	var combined = state.actual_market + state.futures_market
	combined.sort()
	if combined.is_empty():
		return
	if int(state.step) == 3:
		combined.pop_front()
		state.actual_market = combined
		state.futures_market.clear()
		draw_replacement(state)
	else:
		var highest = int(combined.pop_back())
		state.actual_market = combined
		state.futures_market.clear()
		state.draw_pile.append(highest)
		draw_replacement(state)
