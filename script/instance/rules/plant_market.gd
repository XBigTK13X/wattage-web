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
		combined.append(int(plant_number))
	for plant_number in state.futures_market:
		combined.append(int(plant_number))
	combined.sort()

	var step = int(state.step)
	state.actual_market.clear()
	state.futures_market.clear()
	if step == 3:
		for plant_number in combined:
			if plant_number > 0:
				state.actual_market.append(plant_number)
	else:
		var actual_limit = min(4, combined.size())
		for index in range(combined.size()):
			if index < actual_limit:
				state.actual_market.append(combined[index])
			else:
				state.futures_market.append(combined[index])

static func draw_replacement(state):
	if state.draw_pile.is_empty():
		sort_market(state)
		return false
	var next_card = int(state.draw_pile.pop_front())
	if next_card == 0:
		state.step = 3
		sort_market(state)
		if state.actual_market.size() + state.futures_market.size() > 6:
			var combined = state.actual_market + state.futures_market
			combined.sort()
			if not combined.is_empty():
				combined.pop_front()
			state.actual_market = combined
			state.futures_market.clear()
		return true
	state.futures_market.append(next_card)
	sort_market(state)
	return false

static func remove_plants_at_or_below(state, threshold):
	var removed_any = false
	var combined = state.actual_market + state.futures_market
	var kept = []
	for plant_number in combined:
		if int(plant_number) <= int(threshold):
			removed_any = true
		else:
			kept.append(int(plant_number))
	if not removed_any:
		return false
	state.actual_market = kept
	state.futures_market.clear()
	var target_size = 6 if int(state.step) == 3 else 8
	while state.actual_market.size() + state.futures_market.size() < target_size and not state.draw_pile.is_empty():
		var step_three_triggered = draw_replacement(state)
		if step_three_triggered:
			break
	sort_market(state)
	return true

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
