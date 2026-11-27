extends PanelContainer

var _players_row = null

func _ready():
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.09, 0.11, 0.15, 0.96)
	style_box.border_color = Color(0.42, 0.50, 0.62, 0.9)
	style_box.set_border_width_all(2)
	style_box.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style_box)

	_players_row = HBoxContainer.new()
	_players_row.add_theme_constant_override("separation", 12)
	add_child(_players_row)

func set_state(game_state):
	for child in _players_row.get_children():
		child.queue_free()

	var players = game_state.get("players", [])
	var turn_order = game_state.get("turn_order", [])
	var active_turn_pos = int(game_state.get("active_turn_position", 0))
	var active_seat = turn_order[active_turn_pos] if active_turn_pos >= 0 and active_turn_pos < turn_order.size() else -1

	for player in players:
		var is_active = int(player.seat_index) == active_seat
		var border_color = Color(0.98, 0.82, 0.25) if is_active else VW.Assets.get_player_color(player.color)
		var card = VW.Chrome.panel_container(Vector2(210, 86), Color(0.14, 0.17, 0.22, 0.96), border_color)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_players_row.add_child(card)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)

		var house = TextureRect.new()
		house.texture = VW.Assets.get_house_texture(player.color)
		house.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(house)

		var info = Label.new()
		info.text = str(player.player_name) + ("\n*" if is_active else "\n") + str(player.elektro) + "E | Cities: " + str(player.built_cities.size()) + " | Plants: " + str(player.plants.size())
		row.add_child(info)

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
