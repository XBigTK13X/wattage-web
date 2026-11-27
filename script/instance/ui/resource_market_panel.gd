extends PanelContainer

signal resource_clicked(resource_type)

var _phase_label = null
var _order_label = null
var _bins_container = null
var _payout_label = null

func _ready():
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.10, 0.12, 0.17, 0.96)
	style_box.border_color = Color(0.45, 0.56, 0.72, 0.9)
	style_box.set_border_width_all(2)
	style_box.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style_box)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)

	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", 17)
	layout.add_child(_phase_label)

	_order_label = Label.new()
	_order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_order_label)

	_bins_container = VBoxContainer.new()
	_bins_container.add_theme_constant_override("separation", 6)
	layout.add_child(_bins_container)

	_payout_label = Label.new()
	_payout_label.text = "Bureaucracy Payout: 0->10, 1->22, 2->33, 3->44, 5->64, 10->105, 15->134, 20->150"
	_payout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_payout_label)

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

	for child in _bins_container.get_children():
		child.queue_free()

	var market = game_state.get("resource_market", {})
	for resource_type in ["coal", "oil", "garbage", "uranium"]:
		var bins = market.get(resource_type, [])
		var stock = 0
		var next_price = -1
		for bin_entry in bins:
			var amount = int(bin_entry.get("amount", 0))
			stock += amount
			if amount > 0 and next_price == -1:
				next_price = int(bin_entry.get("price", 0))

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_bins_container.add_child(row)

		var icon = TextureRect.new()
		icon.texture = VW.Assets.get_resource_texture(resource_type)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(icon)

		var info = Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var price_text = (str(next_price) + "E") if next_price != -1 else "Empty"
		info.text = resource_type.capitalize() + " | Stock: " + str(stock) + " | Next: " + price_text
		row.add_child(info)

		var buy_button = VW.Chrome.styled_button("Buy 1", 13)
		buy_button.custom_minimum_size = Vector2(82, 30)
		buy_button.disabled = next_price == -1 or phase != 3
		buy_button.pressed.connect(func(): resource_clicked.emit(resource_type))
		row.add_child(buy_button)

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
