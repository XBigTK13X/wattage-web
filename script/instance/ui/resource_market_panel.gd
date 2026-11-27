extends PanelContainer

const GameEngine = preload("res://script/instance/rules/game_engine.gd")
const ResourceMarket = preload("res://script/instance/rules/resource_market.gd")

signal resource_clicked(resource_type)

const ALL_PRICES = [1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16]
const RESOURCE_TYPES = ["coal", "oil", "garbage", "uranium"]

var _phase_label = null
var _order_label = null
var _track_grid = null
var _buy_rows_container = null

func _ready():
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.10, 0.12, 0.17, 0.96)
	style_box.border_color = Color(0.45, 0.56, 0.72, 0.9)
	style_box.set_border_width_all(2)
	style_box.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style_box)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var layout = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 14)
	scroll.add_child(layout)

	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(_phase_label)

	_order_label = Label.new()
	_order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_order_label)

	_track_grid = GridContainer.new()
	_track_grid.columns = ALL_PRICES.size() + 1
	_track_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track_grid.add_theme_constant_override("h_separation", 6)
	_track_grid.add_theme_constant_override("v_separation", 8)
	layout.add_child(_track_grid)

	_buy_rows_container = HBoxContainer.new()
	_buy_rows_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_buy_rows_container.add_theme_constant_override("separation", 18)
	layout.add_child(_buy_rows_container)

func set_state(game_state):
	var phase = int(game_state.get("phase", 1))
	var round_number = int(game_state.get("round_number", 1))
	_phase_label.text = "Round " + str(round_number) + " | Phase " + str(phase) + ": " + _phase_title(phase)

	var players = game_state.get("players", [])
	var order_names = []
	for seat_index in game_state.get("turn_order", []):
		if seat_index >= 0 and seat_index < players.size():
			order_names.append(players[seat_index].player_name)
	_order_label.text = "Turn Order: " + " > ".join(order_names)

	for child in _track_grid.get_children():
		child.queue_free()
	for child in _buy_rows_container.get_children():
		child.queue_free()

	var corner = Label.new()
	corner.text = "Price"
	corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	corner.add_theme_color_override("font_color", Color(0.96, 0.80, 0.28))
	_track_grid.add_child(corner)

	for price in ALL_PRICES:
		var price_cell = VW.Chrome.panel_container(Vector2(0, 34), Color(0.16, 0.19, 0.26, 0.95), Color(0.85, 0.68, 0.25, 0.8))
		price_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var price_row = HBoxContainer.new()
		price_row.alignment = BoxContainer.ALIGNMENT_CENTER
		price_row.add_theme_constant_override("separation", 3)
		price_cell.add_child(price_row)
		var price_label = Label.new()
		price_label.text = str(price)
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		price_label.add_theme_font_size_override("font_size", 15)
		price_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.28))
		price_row.add_child(price_label)
		var badge_texture = VW.Assets.get_ui_texture("elektro_badge")
		if badge_texture != null:
			var badge = TextureRect.new()
			badge.texture = badge_texture
			badge.custom_minimum_size = Vector2(16, 16)
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			price_row.add_child(badge)
		_track_grid.add_child(price_cell)

	var deck_id = str(game_state.get("deck_id", "base_game"))
	var active_seat_index = GameEngine.active_seat(game_state)
	var active_player = players[active_seat_index] if active_seat_index >= 0 and active_seat_index < players.size() else null
	var is_local_turn = active_player != null and str(active_player.get("control_mode", "local")) == "local"
	var market = game_state.get("resource_market", {})

	for resource_type in RESOURCE_TYPES:
		var bins = market.get(resource_type, [])
		var bin_by_price = {}
		var stock = 0
		var next_price = -1
		for bin_entry in bins:
			var p_val = int(bin_entry.get("price", 0))
			var amt = int(bin_entry.get("amount", 0))
			bin_by_price[p_val] = bin_entry
			stock += amt
			if amt > 0 and next_price == -1:
				next_price = p_val

		var row_header = HBoxContainer.new()
		row_header.add_theme_constant_override("separation", 6)
		var res_icon = TextureRect.new()
		res_icon.texture = VW.Assets.get_resource_texture(resource_type)
		res_icon.custom_minimum_size = Vector2(28, 28)
		res_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		res_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row_header.add_child(res_icon)
		var res_name = Label.new()
		res_name.text = resource_type.capitalize()
		res_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_header.add_child(res_name)
		_track_grid.add_child(row_header)

		for price in ALL_PRICES:
			if bin_by_price.has(price):
				var entry = bin_by_price[price]
				var capacity = int(entry.get("capacity", 0))
				var amount = int(entry.get("amount", 0))
				var is_cheapest = (price == next_price)
				var border_col = Color(0.35, 0.92, 0.45, 0.95) if is_cheapest else Color(0.35, 0.42, 0.54, 0.85)
				var space_panel = VW.Chrome.panel_container(Vector2(0, 68), Color(0.13, 0.16, 0.22, 0.95), border_col)
				space_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var slot_box = VBoxContainer.new()
				slot_box.alignment = BoxContainer.ALIGNMENT_CENTER
				slot_box.add_theme_constant_override("separation", 2)
				space_panel.add_child(slot_box)
				for slot_idx in range(capacity):
					var token_icon = TextureRect.new()
					token_icon.texture = VW.Assets.get_resource_texture(resource_type)
					token_icon.custom_minimum_size = Vector2(18, 18)
					token_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					token_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					token_icon.modulate = Color(1, 1, 1, 1.0) if slot_idx < amount else Color(0.3, 0.3, 0.35, 0.28)
					slot_box.add_child(token_icon)
				_track_grid.add_child(space_panel)
			else:
				var unused_panel = VW.Chrome.panel_container(Vector2(0, 68), Color(0.06, 0.07, 0.10, 0.65), Color(0.18, 0.21, 0.27, 0.4))
				unused_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_track_grid.add_child(unused_panel)

		var can_buy = phase == 3 and is_local_turn and next_price != -1 and int(active_player.get("elektro", 0)) >= next_price and ResourceMarket.can_store_resource(active_player, deck_id, resource_type, 1)
		var buy_card = VW.Chrome.panel_container(Vector2(210, 80), Color(0.13, 0.16, 0.22, 0.95), Color(0.85, 0.68, 0.25, 0.85) if can_buy else Color(0.35, 0.42, 0.54, 0.7))
		var buy_box = VBoxContainer.new()
		buy_box.add_theme_constant_override("separation", 6)
		buy_card.add_child(buy_box)
		var stock_row = HBoxContainer.new()
		stock_row.alignment = BoxContainer.ALIGNMENT_CENTER
		stock_row.add_theme_constant_override("separation", 4)
		buy_box.add_child(stock_row)
		var stock_label = Label.new()
		var price_text = str(next_price) if next_price != -1 else "Empty"
		stock_label.text = resource_type.capitalize() + " (" + str(stock) + ") | Next: " + price_text
		stock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stock_row.add_child(stock_label)
		if next_price != -1:
			var next_badge_texture = VW.Assets.get_ui_texture("elektro_badge")
			if next_badge_texture != null:
				var next_badge = TextureRect.new()
				next_badge.texture = next_badge_texture
				next_badge.custom_minimum_size = Vector2(16, 16)
				next_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				next_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				next_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				stock_row.add_child(next_badge)
		var buy_button = VW.Chrome.styled_button("Buy 1 " + resource_type.capitalize(), 14)
		buy_button.custom_minimum_size = Vector2(180, 34)
		buy_button.disabled = not can_buy
		buy_button.pressed.connect(func(): resource_clicked.emit(resource_type))
		buy_box.add_child(buy_button)
		_buy_rows_container.add_child(buy_card)

func _phase_title(phase):
	match phase:
		1:
			return "Determine Player Order"
		2:
			return "Auction Power Plants"
		3:
			return "Buy Resources"
		4:
			return "Building"
		5:
			return "Bureaucracy"
		_:
			return "Unknown"
