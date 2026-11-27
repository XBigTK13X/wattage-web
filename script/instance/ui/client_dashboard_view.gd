extends VBoxContainer

signal action_requested(action_name, parameters)

var _status_label = null
var _elektro_label = null
var _plants_container = null
var _resources_label = null
var _phase_hint_label = null
var _phase_actions_box = null

func _ready():
	add_theme_constant_override("separation", 12)

	var header_panel = VW.Chrome.panel_container(Vector2(0, 88), Color(0.11, 0.14, 0.20, 0.96), Color(0.85, 0.68, 0.25, 0.95))
	add_child(header_panel)

	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	header_panel.add_child(header_row)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 18)
	header_row.add_child(_status_label)

	var elektro_box = HBoxContainer.new()
	elektro_box.add_theme_constant_override("separation", 6)
	header_row.add_child(elektro_box)

	var elektro_texture = VW.Assets.get_ui_texture("elektro_badge")
	if elektro_texture != null:
		var badge = TextureRect.new()
		badge.texture = elektro_texture
		badge.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		elektro_box.add_child(badge)

	_elektro_label = Label.new()
	_elektro_label.add_theme_font_size_override("font_size", 24)
	_elektro_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.28))
	elektro_box.add_child(_elektro_label)

	var storage_panel = VW.Chrome.panel_container(Vector2(0, 64), Color(0.10, 0.12, 0.17, 0.95), Color(0.45, 0.56, 0.72, 0.9))
	add_child(storage_panel)

	_resources_label = Label.new()
	_resources_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resources_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	storage_panel.add_child(_resources_label)

	var plants_panel = VW.Chrome.panel_container(Vector2(0, 170), Color(0.10, 0.12, 0.17, 0.95), Color(0.45, 0.56, 0.72, 0.9))
	plants_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(plants_panel)

	var plants_scroll = ScrollContainer.new()
	plants_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plants_panel.add_child(plants_scroll)

	_plants_container = HBoxContainer.new()
	_plants_container.add_theme_constant_override("separation", 10)
	plants_scroll.add_child(_plants_container)

	var actions_panel = VW.Chrome.panel_container(Vector2(0, 190), Color(0.12, 0.15, 0.21, 0.97), Color(0.85, 0.68, 0.25, 0.9))
	add_child(actions_panel)

	var actions_layout = VBoxContainer.new()
	actions_layout.add_theme_constant_override("separation", 10)
	actions_panel.add_child(actions_layout)

	var actions_title = Label.new()
	actions_title.text = "Available Actions"
	actions_title.add_theme_font_size_override("font_size", 16)
	actions_layout.add_child(actions_title)

	_phase_hint_label = Label.new()
	_phase_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phase_hint_label.visible = false
	actions_layout.add_child(_phase_hint_label)

	_phase_actions_box = HFlowContainer.new()
	_phase_actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phase_actions_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_phase_actions_box.add_theme_constant_override("h_separation", 10)
	_phase_actions_box.add_theme_constant_override("v_separation", 10)
	actions_layout.add_child(_phase_actions_box)

func update_state(public_state, private_state):
	var player_name = str(private_state.get("player_name", "Unassigned Seat"))
	var seat_index = int(private_state.get("seat_index", -1))
	var active_seat = int(public_state.get("active_seat", -1))
	var phase = int(public_state.get("phase", 1))
	var step = int(public_state.get("step", 1))
	var is_my_turn = seat_index >= 0 and seat_index == active_seat
	var turn_badge = "YOUR TURN" if is_my_turn else "Waiting"

	_status_label.text = player_name + " (" + turn_badge + ") | Step " + str(step) + " Phase " + str(phase)
	_elektro_label.text = str(private_state.get("elektro", 0)) + "E"

	var stored = private_state.get("stored_resources", {})
	_resources_label.text = "Stored Fuel -> Coal: " + str(stored.get("coal", 0)) + " | Oil: " + str(stored.get("oil", 0)) + " | Garbage: " + str(stored.get("garbage", 0)) + " | Uranium: " + str(stored.get("uranium", 0))

	for child in _plants_container.get_children():
		child.queue_free()

	var deck_id = str(public_state.get("deck_id", "base_game"))
	var owned_plants = private_state.get("plants", [])
	if owned_plants.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No power plants owned yet."
		_plants_container.add_child(empty_label)
	else:
		for plant_number in owned_plants:
			var plant_def = VW.Database.get_plant(deck_id, int(plant_number))
			if plant_def != null:
				_plants_container.add_child(VW.Assets.build_plant_card(plant_def, deck_id, Vector2(128, 168)))

	_rebuild_phase_actions(public_state, private_state, is_my_turn)

func _rebuild_phase_actions(public_state, _private_state, is_my_turn):
	for child in _phase_actions_box.get_children():
		child.queue_free()
	_phase_hint_label.visible = false
	_phase_hint_label.text = ""

	if not is_my_turn:
		_phase_hint_label.text = "Waiting for active player..."
		_phase_hint_label.visible = true
		return

	var phase = int(public_state.get("phase", 1))
	var auction = public_state.get("auction", {})

	if phase == 2:
		if bool(auction.get("active", false)):
			var bid_one = VW.Chrome.styled_button("Bid +1", 16)
			bid_one.custom_minimum_size = Vector2(130, 50)
			bid_one.icon = VW.Assets.get_icon_texture("action_bid_plus1")
			bid_one.expand_icon = true
			bid_one.pressed.connect(func(): action_requested.emit("place_bid", { increment = 1 }))
			_phase_actions_box.add_child(bid_one)

			var bid_five = VW.Chrome.styled_button("Bid +5", 16)
			bid_five.custom_minimum_size = Vector2(130, 50)
			bid_five.icon = VW.Assets.get_icon_texture("action_bid_plus5")
			bid_five.expand_icon = true
			bid_five.pressed.connect(func(): action_requested.emit("place_bid", { increment = 5 }))
			_phase_actions_box.add_child(bid_five)

			var pass_bid = VW.Chrome.styled_button("Pass Bid", 16)
			pass_bid.custom_minimum_size = Vector2(130, 50)
			pass_bid.icon = VW.Assets.get_icon_texture("action_pass")
			pass_bid.expand_icon = true
			pass_bid.pressed.connect(func(): action_requested.emit("pass_auction", {}))
			_phase_actions_box.add_child(pass_bid)
		else:
			for plant_number in public_state.get("actual_market", []):
				var nominate_button = VW.Chrome.styled_button("Nominate #" + str(plant_number), 15)
				nominate_button.custom_minimum_size = Vector2(148, 50)
				nominate_button.pressed.connect(func(): action_requested.emit("select_plant_for_auction", { plant_number = int(plant_number) }))
				_phase_actions_box.add_child(nominate_button)
	elif phase == 3:
		for resource_type in ["coal", "oil", "garbage", "uranium"]:
			var buy_button = VW.Chrome.styled_button("Buy " + resource_type.capitalize(), 15)
			buy_button.custom_minimum_size = Vector2(154, 50)
			buy_button.icon = VW.Assets.get_resource_texture(resource_type)
			buy_button.expand_icon = true
			buy_button.pressed.connect(func(): action_requested.emit("buy_resource", { resource = resource_type, amount = 1 }))
			_phase_actions_box.add_child(buy_button)
	elif phase == 4:
		_phase_hint_label.text = "Switch to 'Map Inspection' view and tap a city to build."
		_phase_hint_label.visible = true
	elif phase == 5:
		var power_button = VW.Chrome.styled_button("Power All Cities", 16)
		power_button.custom_minimum_size = Vector2(196, 50)
		power_button.icon = VW.Assets.get_icon_texture("power_bolt")
		power_button.expand_icon = true
		power_button.pressed.connect(func(): action_requested.emit("power_plants", {}))
		_phase_actions_box.add_child(power_button)

	var pass_phase_button = VW.Chrome.styled_button("End Phase", 15)
	pass_phase_button.custom_minimum_size = Vector2(136, 50)
	pass_phase_button.pressed.connect(func(): action_requested.emit("pass_phase", {}))
	_phase_actions_box.add_child(pass_phase_button)
