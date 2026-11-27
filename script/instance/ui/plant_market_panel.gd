extends PanelContainer

const GameEngine = preload("res://script/instance/rules/game_engine.gd")

signal plant_nominated(plant_number)
signal bid_placed(amount)
signal auction_passed()

var _actual_row = null
var _futures_row = null
var _step_label = null
var _auction_box = null
var _auction_info_label = null
var _bid_one_button = null
var _bid_five_button = null
var _pass_button = null
var _deck_id = "base_game"
var _game_state = null

func _ready():
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.10, 0.12, 0.17, 0.96)
	style_box.border_color = Color(0.85, 0.68, 0.25, 0.9)
	style_box.set_border_width_all(2)
	style_box.set_content_margin_all(12)
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

	var header_row = HBoxContainer.new()
	layout.add_child(header_row)

	var title_label = Label.new()
	title_label.text = "Power Plant Market"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	header_row.add_child(title_label)

	_step_label = Label.new()
	_step_label.text = "Step 1"
	header_row.add_child(_step_label)

	var actual_label = Label.new()
	actual_label.text = "Actual Market"
	layout.add_child(actual_label)

	_actual_row = HBoxContainer.new()
	_actual_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_actual_row.add_theme_constant_override("separation", 18)
	layout.add_child(_actual_row)

	var futures_label = Label.new()
	futures_label.text = "Futures Market"
	layout.add_child(futures_label)

	_futures_row = HBoxContainer.new()
	_futures_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_futures_row.add_theme_constant_override("separation", 18)
	layout.add_child(_futures_row)

	_auction_box = VW.Chrome.panel_container(Vector2(0, 110), Color(0.14, 0.17, 0.24, 0.98), Color(0.95, 0.78, 0.28, 1.0))
	_auction_box.visible = false
	layout.add_child(_auction_box)

	var auction_layout = VBoxContainer.new()
	auction_layout.add_theme_constant_override("separation", 8)
	_auction_box.add_child(auction_layout)

	_auction_info_label = Label.new()
	_auction_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	auction_layout.add_child(_auction_info_label)

	var bid_controls = HBoxContainer.new()
	bid_controls.add_theme_constant_override("separation", 10)
	auction_layout.add_child(bid_controls)

	_bid_one_button = VW.Chrome.styled_button("Bid +1", 14)
	_bid_one_button.custom_minimum_size = Vector2(110, 36)
	_bid_one_button.icon = VW.Assets.get_icon_texture("action_bid_plus1")
	_bid_one_button.expand_icon = true
	_bid_one_button.pressed.connect(func(): bid_placed.emit(1))
	bid_controls.add_child(_bid_one_button)

	_bid_five_button = VW.Chrome.styled_button("Bid +5", 14)
	_bid_five_button.custom_minimum_size = Vector2(110, 36)
	_bid_five_button.icon = VW.Assets.get_icon_texture("action_bid_plus5")
	_bid_five_button.expand_icon = true
	_bid_five_button.pressed.connect(func(): bid_placed.emit(5))
	bid_controls.add_child(_bid_five_button)

	_pass_button = VW.Chrome.styled_button("Pass", 14)
	_pass_button.custom_minimum_size = Vector2(100, 36)
	_pass_button.icon = VW.Assets.get_icon_texture("action_pass")
	_pass_button.expand_icon = true
	_pass_button.pressed.connect(func(): auction_passed.emit())
	bid_controls.add_child(_pass_button)

	layout.add_child(_build_payments_card())

func _build_payments_card():
	var card = VW.Chrome.panel_container(Vector2(0, 0), Color(0.14, 0.16, 0.21, 0.96), Color(0.85, 0.68, 0.25, 0.85))
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var card_layout = VBoxContainer.new()
	card_layout.add_theme_constant_override("separation", 8)
	card.add_child(card_layout)

	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	card_layout.add_child(header_row)

	var title_label = Label.new()
	title_label.text = "PAYMENTS (Bureaucracy Income)"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.28))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_label)

	var legend_label = Label.new()
	legend_label.text = "Cities Powered | Elektro Earned"
	legend_label.add_theme_font_size_override("font_size", 13)
	header_row.add_child(legend_label)

	var grid = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	card_layout.add_child(grid)

	var bg_texture = VW.Assets.get_ui_texture("payment_cell_bg")
	var house_texture = VW.Assets.get_token_texture("house_token")
	var badge_texture = VW.Assets.get_ui_texture("elektro_badge")
	var payouts = GameEngine.BUREAUCRACY_PAYOUTS
	for city_count in range(payouts.size()):
		var cell = Control.new()
		cell.custom_minimum_size = Vector2(164, 44)
		if bg_texture != null:
			var bg = TextureRect.new()
			bg.texture = bg_texture
			bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg.stretch_mode = TextureRect.STRETCH_SCALE
			cell.add_child(bg)
		else:
			var fallback_draw = _SlantedCellBackground.new()
			fallback_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
			fallback_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(fallback_draw)

		var cell_row = HBoxContainer.new()
		cell_row.set_anchors_preset(Control.PRESET_FULL_RECT)
		cell_row.add_theme_constant_override("separation", 0)
		cell.add_child(cell_row)

		var left_half = HBoxContainer.new()
		left_half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_half.alignment = BoxContainer.ALIGNMENT_CENTER
		left_half.add_theme_constant_override("separation", 5)
		cell_row.add_child(left_half)

		var cities_label = Label.new()
		cities_label.text = "20+" if city_count == 20 else str(city_count)
		cities_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cities_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cities_label.add_theme_font_size_override("font_size", 15)
		cities_label.add_theme_color_override("font_color", Color(0.84, 0.90, 0.98))
		left_half.add_child(cities_label)

		if house_texture != null:
			var house_icon = TextureRect.new()
			house_icon.texture = house_texture
			house_icon.custom_minimum_size = Vector2(18, 18)
			house_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			house_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			house_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			left_half.add_child(house_icon)

		var right_half = HBoxContainer.new()
		right_half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_half.alignment = BoxContainer.ALIGNMENT_CENTER
		right_half.add_theme_constant_override("separation", 5)
		cell_row.add_child(right_half)

		var payout_label = Label.new()
		payout_label.text = str(payouts[city_count])
		payout_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		payout_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		payout_label.add_theme_font_size_override("font_size", 15)
		payout_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.28))
		right_half.add_child(payout_label)

		if badge_texture != null:
			var badge = TextureRect.new()
			badge.texture = badge_texture
			badge.custom_minimum_size = Vector2(18, 18)
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			right_half.add_child(badge)

		grid.add_child(cell)

	return card

class _SlantedCellBackground extends Control:
	func _draw():
		var cell_width = size.x
		var cell_height = size.y
		if cell_width <= 0 or cell_height <= 0:
			return
		var mid_top = cell_width * 0.51
		var mid_bot = cell_width * 0.43
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(mid_top, 0), Vector2(mid_bot, cell_height), Vector2(0, cell_height)]), Color(0.14, 0.21, 0.32, 0.98))
		draw_colored_polygon(PackedVector2Array([Vector2(mid_top, 0), Vector2(cell_width, 0), Vector2(cell_width, cell_height), Vector2(mid_bot, cell_height)]), Color(0.24, 0.18, 0.09, 0.98))
		draw_line(Vector2(mid_top, 0), Vector2(mid_bot, cell_height), Color(0.88, 0.71, 0.28, 1.0), 2.0, true)
		draw_rect(Rect2(Vector2(1, 1), Vector2(cell_width - 2, cell_height - 2)), Color(0.53, 0.63, 0.78, 0.95), false, 2.0)

func set_state(game_state):
	_game_state = game_state
	_deck_id = str(game_state.get("deck_id", "base_game"))
	var step = int(game_state.get("step", 1))
	var phase = int(game_state.get("phase", 1))
	var auction = game_state.get("auction", {})
	var auction_active = bool(auction.get("active", false))
	var active_seat_index = GameEngine.active_seat(game_state)
	var players = game_state.get("players", [])
	var active_player = players[active_seat_index] if active_seat_index >= 0 and active_seat_index < players.size() else null
	var is_local_turn = active_player != null and str(active_player.get("control_mode", "local")) == "local"
	var surcharge = GameEngine._frida_surcharge_for_human(game_state) if phase == 2 and not auction_active else 0
	var active_elektro = int(active_player.get("elektro", 0)) if active_player != null else 0

	_step_label.text = "Step " + str(step) + (" (6-card market)" if step == 3 else "")

	for child in _actual_row.get_children():
		child.queue_free()
	for child in _futures_row.get_children():
		child.queue_free()

	for plant_number in game_state.get("actual_market", []):
		var num = int(plant_number)
		var can_nominate = phase == 2 and not auction_active and is_local_turn and active_elektro >= num + surcharge
		_actual_row.add_child(_make_market_card(num, can_nominate))
	for plant_number in game_state.get("futures_market", []):
		_futures_row.add_child(_make_market_card(int(plant_number), false))

	_auction_box.visible = auction_active
	if _auction_box.visible:
		var high_bidder_seat = int(auction.get("high_bidder_seat", -1))
		var current_bid = int(auction.get("current_bid", 0))
		var bidder_name = players[high_bidder_seat].player_name if high_bidder_seat >= 0 and high_bidder_seat < players.size() else "None"
		var active_bidder_name = active_player.player_name if active_player != null else "None"
		var passed_seats = auction.get("passed_seats", [])
		_auction_info_label.text = "Auctioning Plant #" + str(auction.get("plant_number", 0)) + " | High Bid: " + str(current_bid) + " Elektro (" + bidder_name + ") | Waiting on: " + active_bidder_name + " | Passed: " + str(passed_seats.size())
		_bid_one_button.disabled = not is_local_turn or active_elektro < current_bid + 1
		_bid_five_button.disabled = not is_local_turn or active_elektro < current_bid + 5
		_pass_button.disabled = not is_local_turn

func _make_market_card(plant_number, clickable):
	var plant = VW.Database.get_plant(_deck_id, plant_number)
	var card_texture = VW.Assets.get_plant_card_texture(_deck_id, plant)
	if card_texture != null:
		var texture_button = TextureButton.new()
		texture_button.texture_normal = card_texture
		texture_button.ignore_texture_size = true
		texture_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		texture_button.custom_minimum_size = Vector2(142, 186)
		texture_button.disabled = not clickable
		texture_button.modulate = Color(1, 1, 1, 1.0 if clickable else 0.72)
		texture_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
		VW.Chrome.attach_focus_ring(texture_button)
		if clickable:
			texture_button.pressed.connect(func(): plant_nominated.emit(plant_number))
		return texture_button

	var button = VW.Chrome.styled_button("#" + str(plant_number), 14)
	button.custom_minimum_size = Vector2(118, 76)
	if plant != null:
		button.text = "#" + str(plant.number) + "\n" + str(plant.fuel_cost) + " " + plant.fuel_type + "\n->" + str(plant.cities_powered) + " cities"
	button.disabled = not clickable
	if clickable:
		button.pressed.connect(func(): plant_nominated.emit(plant_number))
	return button
