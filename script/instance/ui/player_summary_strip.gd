extends PanelContainer

const GameEngine = preload("res://script/instance/rules/game_engine.gd")

var _players_list = null

func _ready():
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.09, 0.11, 0.15, 0.96)
	style_box.border_color = Color(0.42, 0.50, 0.62, 0.9)
	style_box.set_border_width_all(2)
	style_box.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style_box)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_players_list = VBoxContainer.new()
	_players_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_players_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_players_list)

func set_state(game_state):
	for child in _players_list.get_children():
		child.queue_free()

	var players = game_state.get("players", [])
	var turn_order = game_state.get("turn_order", [])
	var active_seat = GameEngine.active_seat(game_state)
	var deck_id = str(game_state.get("deck_id", "base_game"))

	for order_pos in range(turn_order.size()):
		var seat_idx = int(turn_order[order_pos])
		if seat_idx < 0 or seat_idx >= players.size():
			continue
		var player = players[seat_idx]
		var is_active = seat_idx == active_seat
		var border_color = Color(0.98, 0.82, 0.25) if is_active else VW.Assets.get_player_color(player.color)
		var card = VW.Chrome.panel_container(Vector2(0, 128), Color(0.14, 0.17, 0.22, 0.96), border_color)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_players_list.add_child(card)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)

		var left_box = VBoxContainer.new()
		left_box.custom_minimum_size = Vector2(300, 0)
		left_box.add_theme_constant_override("separation", 6)
		row.add_child(left_box)

		var name_row = HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		left_box.add_child(name_row)

		var house = TextureRect.new()
		house.texture = VW.Assets.get_house_texture(player.color)
		house.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		name_row.add_child(house)

		if is_active:
			var turn_marker = VW.Assets.get_token_texture("turn_order_marker")
			if turn_marker != null:
				var marker_rect = TextureRect.new()
				marker_rect.texture = turn_marker
				marker_rect.custom_minimum_size = Vector2(20, 20)
				marker_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				marker_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				name_row.add_child(marker_rect)

		var name_label = Label.new()
		name_label.text = "#" + str(order_pos + 1) + " " + str(player.player_name) + " (" + str(player.control_mode) + ")"
		name_label.add_theme_font_size_override("font_size", 17)
		name_row.add_child(name_label)

		var elektro_row = HBoxContainer.new()
		elektro_row.add_theme_constant_override("separation", 6)
		left_box.add_child(elektro_row)

		var city_total = GameEngine.player_city_count(player)
		var elektro_label = Label.new()
		elektro_label.text = str(player.elektro)
		elektro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		elektro_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		elektro_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.28))
		elektro_row.add_child(elektro_label)

		var badge_texture = VW.Assets.get_ui_texture("elektro_badge")
		if badge_texture != null:
			var badge = TextureRect.new()
			badge.texture = badge_texture
			badge.custom_minimum_size = Vector2(18, 18)
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			elektro_row.add_child(badge)

		var separator_label = Label.new()
		separator_label.text = " | "
		separator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		separator_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		elektro_row.add_child(separator_label)

		var cities_label = Label.new()
		cities_label.text = str(city_total)
		cities_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cities_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		elektro_row.add_child(cities_label)

		var house_texture = VW.Assets.get_token_texture("house_token")
		if house_texture != null:
			var house_icon = TextureRect.new()
			house_icon.texture = house_texture
			house_icon.custom_minimum_size = Vector2(18, 18)
			house_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			house_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			house_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			elektro_row.add_child(house_icon)

		var stats_label = Label.new()
		var stored = player.get("stored_resources", {})
		stats_label.text = "Fuel: Coal " + str(int(stored.get("coal", 0))) + ", Oil " + str(int(stored.get("oil", 0))) + ", Garbage " + str(int(stored.get("garbage", 0))) + ", Uranium " + str(int(stored.get("uranium", 0)))
		left_box.add_child(stats_label)

		var plants_row = HBoxContainer.new()
		plants_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plants_row.add_theme_constant_override("separation", 10)
		row.add_child(plants_row)

		if player.plants.is_empty():
			var no_plants = Label.new()
			no_plants.text = "No power plants"
			no_plants.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			plants_row.add_child(no_plants)
		else:
			for plant_number in player.plants:
				var plant_def = VW.Database.get_plant(deck_id, int(plant_number))
				if plant_def != null:
					plants_row.add_child(VW.Assets.build_plant_card(plant_def, deck_id, Vector2(96, 126)))

static func show_end_game_modal(parent_node, game_state):
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.03, 0.05, 0.80)
	parent_node.add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(640, 420))
	center.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var title_label = Label.new()
	title_label.text = "Final Standings & Tiebreakers"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	layout.add_child(title_label)

	var standings = game_state.get("standings", [])
	for rank_index in range(standings.size()):
		var entry = standings[rank_index]
		var line = Label.new()
		line.text = "#" + str(rank_index + 1) + " " + str(entry.player_name) + " | Powered: " + str(entry.powered_cities) + " | Elektro: " + str(entry.elektro) + " | Built: " + str(entry.built_cities)
		layout.add_child(line)

	var menu_button = VW.Chrome.styled_button("Return to Main Menu")
	menu_button.pressed.connect(func():
		VW.GameLibrary.suspend_active_game()
		VW.Scenes.goto(VW.Scenes.MAIN_MENU)
	)
	layout.add_child(menu_button)
