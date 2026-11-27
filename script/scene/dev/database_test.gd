extends Control

static func init_container():
	return Control.new()

func _ready():
	VW.Database.load_all()
	var lines = []
	for map_check in [
		{ id = "sample_map", cities = 6, regions = 2 },
		{ id = "germany", cities = 42, regions = 6 },
		{ id = "united_states", cities = 42, regions = 6 }
	]:
		var loaded_map = VW.Database.get_map(map_check.id)
		if loaded_map == null:
			lines.append("FAIL: " + map_check.id + " not loaded")
		else:
			var city_count = loaded_map.cities.size()
			var region_count = loaded_map.regions.size()
			var symmetric = loaded_map.is_adjacency_symmetric()
			lines.append("Map '" + map_check.id + "': " + str(city_count) + "/" + str(map_check.cities) + " cities, " + str(region_count) + "/" + str(map_check.regions) + " regions, symmetric=" + str(symmetric))

	var expected_decks = {
		"base_game": 43,
		"new_plants_1": 43,
		"new_plants_2": 43
	}
	for deck_id in expected_decks.keys():
		var deck = VW.Database.get_deck(deck_id)
		if deck == null:
			lines.append("FAIL: deck " + deck_id + " missing")
			continue
		var has_step_three = false
		for card in deck.cards:
			if card.is_step_three:
				has_step_three = true
				break
		lines.append("Deck '" + deck_id + "': " + str(deck.cards.size()) + " cards (expected " + str(expected_decks[deck_id]) + "), step3=" + str(has_step_three))

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(680, 320))
	center.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var title_label = Label.new()
	title_label.text = "Wattage Web Database Verification"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title_label)

	var output_label = Label.new()
	output_label.text = "\n".join(lines)
	output_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(output_label)

	var ui_button = VW.Chrome.styled_button("Open UI Showcase")
	ui_button.pressed.connect(func(): VW.Scenes.goto(VW.Scenes.UI_TEST))
	layout.add_child(ui_button)
