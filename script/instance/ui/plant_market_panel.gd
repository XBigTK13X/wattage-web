extends PanelContainer

signal plant_nominated(plant_number)
signal bid_placed(amount)
signal auction_passed()

var _actual_row = null
var _futures_row = null
var _step_label = null
var _auction_box = null
var _auction_info_label = null
var _deck_id = "base_game"
var _game_state = null

func _ready():
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.10, 0.12, 0.17, 0.96)
	style_box.border_color = Color(0.85, 0.68, 0.25, 0.9)
	style_box.set_border_width_all(2)
	style_box.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style_box)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)

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
	_actual_row.add_theme_constant_override("separation", 8)
	layout.add_child(_actual_row)

	var futures_label = Label.new()
	futures_label.text = "Futures Market"
	layout.add_child(futures_label)

	_futures_row = HBoxContainer.new()
	_futures_row.add_theme_constant_override("separation", 8)
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

	var bid_one_button = VW.Chrome.styled_button("Bid +1", 14)
	bid_one_button.custom_minimum_size = Vector2(110, 36)
	bid_one_button.icon = VW.Assets.get_icon_texture("action_bid_plus1")
	bid_one_button.expand_icon = true
	bid_one_button.pressed.connect(func(): bid_placed.emit(1))
	bid_controls.add_child(bid_one_button)

	var bid_five_button = VW.Chrome.styled_button("Bid +5", 14)
	bid_five_button.custom_minimum_size = Vector2(110, 36)
	bid_five_button.icon = VW.Assets.get_icon_texture("action_bid_plus5")
	bid_five_button.expand_icon = true
	bid_five_button.pressed.connect(func(): bid_placed.emit(5))
	bid_controls.add_child(bid_five_button)

	var pass_button = VW.Chrome.styled_button("Pass", 14)
	pass_button.custom_minimum_size = Vector2(100, 36)
	pass_button.icon = VW.Assets.get_icon_texture("action_pass")
	pass_button.expand_icon = true
	pass_button.pressed.connect(func(): auction_passed.emit())
	bid_controls.add_child(pass_button)

func set_state(game_state):
	_game_state = game_state
	_deck_id = str(game_state.get("deck_id", "base_game"))
	var step = int(game_state.get("step", 1))
	_step_label.text = "Step " + str(step) + (" (6-card market)" if step == 3 else "")

	for child in _actual_row.get_children():
		child.queue_free()
	for child in _futures_row.get_children():
		child.queue_free()

	for plant_number in game_state.get("actual_market", []):
		_actual_row.add_child(_make_market_card(int(plant_number), true))
	for plant_number in game_state.get("futures_market", []):
		_futures_row.add_child(_make_market_card(int(plant_number), false))

	var auction = game_state.get("auction", {})
	_auction_box.visible = bool(auction.get("active", false))
	if _auction_box.visible:
		var high_bidder_seat = int(auction.get("high_bidder_seat", -1))
		var players = game_state.get("players", [])
		var bidder_name = players[high_bidder_seat].player_name if high_bidder_seat >= 0 and high_bidder_seat < players.size() else "None"
		var passed_seats = auction.get("passed_seats", [])
		_auction_info_label.text = "Auctioning Plant #" + str(auction.get("plant_number", 0)) + " | High Bid: " + str(auction.get("current_bid", 0)) + " Elektro (" + bidder_name + ") | Passed seats: " + str(passed_seats.size())

func _make_market_card(plant_number, clickable):
	var plant = VW.Database.get_plant(_deck_id, plant_number)
	var card_texture = VW.Assets.get_plant_card_texture(_deck_id, plant)
	if card_texture != null:
		var texture_button = TextureButton.new()
		texture_button.texture_normal = card_texture
		texture_button.ignore_texture_size = true
		texture_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		texture_button.custom_minimum_size = Vector2(104, 136)
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
