extends Control

const MapBoardView = preload("res://script/instance/ui/map_board_view.gd")
const PlantMarketPanel = preload("res://script/instance/ui/plant_market_panel.gd")
const ResourceMarketPanel = preload("res://script/instance/ui/resource_market_panel.gd")
const PlayerSummaryStrip = preload("res://script/instance/ui/player_summary_strip.gd")

static func init_container():
	return Control.new()

var _game_state = null
var _map_definition = null
var _map_view = null
var _plant_market_panel = null
var _resource_market_panel = null
var _player_strip = null

func _ready():
	VW.Database.ensure_loaded()
	_game_state = VW.GameLibrary.active_game
	if _game_state == null:
		VW.Scenes.goto(VW.Scenes.MAIN_MENU)
		return
	_map_definition = VW.Database.get_map(_game_state.map_id)
	_build_gui()
	_refresh_all()

func _build_gui():
	var root_box = VBoxContainer.new()
	root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 8)
	add_child(root_box)

	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	root_box.add_child(top_bar)

	var match_label = Label.new()
	match_label.text = str(_game_state.get("title", "Volt Web Match"))
	match_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(match_label)

	var advance_phase_button = VW.Chrome.styled_button("Advance Phase", 14)
	advance_phase_button.custom_minimum_size = Vector2(150, 36)
	advance_phase_button.pressed.connect(_on_advance_phase)
	top_bar.add_child(advance_phase_button)

	var end_game_button = VW.Chrome.styled_button("Simulate End-Game", 14)
	end_game_button.custom_minimum_size = Vector2(170, 36)
	end_game_button.pressed.connect(_on_simulate_end_game)
	top_bar.add_child(end_game_button)

	var menu_button = VW.Chrome.styled_button("Main Menu (Pause)", 14)
	menu_button.custom_minimum_size = Vector2(170, 36)
	menu_button.pressed.connect(_on_return_to_menu)
	top_bar.add_child(menu_button)

	var body_row = HBoxContainer.new()
	body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_row.add_theme_constant_override("separation", 8)
	root_box.add_child(body_row)

	_map_view = MapBoardView.new()
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.city_selected.connect(_on_city_selected)
	body_row.add_child(_map_view)

	var right_sidebar = VBoxContainer.new()
	right_sidebar.custom_minimum_size = Vector2(540, 0)
	right_sidebar.add_theme_constant_override("separation", 8)
	body_row.add_child(right_sidebar)

	_plant_market_panel = PlantMarketPanel.new()
	_plant_market_panel.plant_nominated.connect(_on_plant_nominated)
	_plant_market_panel.bid_placed.connect(_on_bid_placed)
	_plant_market_panel.auction_passed.connect(_on_auction_passed)
	right_sidebar.add_child(_plant_market_panel)

	_resource_market_panel = ResourceMarketPanel.new()
	_resource_market_panel.resource_clicked.connect(_on_resource_clicked)
	right_sidebar.add_child(_resource_market_panel)

	_player_strip = PlayerSummaryStrip.new()
	root_box.add_child(_player_strip)

func _refresh_all():
	_map_view.set_state(_map_definition, _game_state)
	_plant_market_panel.set_state(_game_state)
	_resource_market_panel.set_state(_game_state)
	_player_strip.set_state(_game_state)

func _active_seat():
	var order = _game_state.get("turn_order", [])
	var position = int(_game_state.get("active_turn_position", 0))
	if position >= 0 and position < order.size():
		return int(order[position])
	return 0

func _on_plant_nominated(plant_number):
	_game_state.phase = 2
	_game_state.auction = {
		active = true,
		plant_number = plant_number,
		current_bid = plant_number,
		high_bidder_seat = _active_seat(),
		passed_seats = []
	}
	VW.GameLibrary.save_active_game()
	_refresh_all()

func _on_bid_placed(increment):
	if not _game_state.auction.active:
		return
	_game_state.auction.current_bid += int(increment)
	var next_seat = (_game_state.auction.high_bidder_seat + 1) % _game_state.players.size()
	_game_state.auction.high_bidder_seat = next_seat
	VW.GameLibrary.save_active_game()
	_refresh_all()

func _on_auction_passed():
	if not _game_state.auction.active:
		return
	var winner_seat = int(_game_state.auction.high_bidder_seat)
	var plant_number = int(_game_state.auction.plant_number)
	if winner_seat >= 0 and winner_seat < _game_state.players.size():
		var player = _game_state.players[winner_seat]
		player.elektro = max(0, int(player.elektro) - int(_game_state.auction.current_bid))
		player.plants.append(plant_number)
	_game_state.actual_market.erase(plant_number)
	if not _game_state.futures_market.is_empty():
		_game_state.actual_market.append(_game_state.futures_market.pop_front())
		_game_state.actual_market.sort()
	_game_state.auction.active = false
	VW.GameLibrary.save_active_game()
	_refresh_all()

func _on_resource_clicked(resource_type):
	var bins = _game_state.resource_market.get(resource_type, [])
	for bin_entry in bins:
		if int(bin_entry.amount) > 0:
			var seat = _active_seat()
			var player = _game_state.players[seat]
			var price = int(bin_entry.price)
			if int(player.elektro) >= price:
				player.elektro -= price
				bin_entry.amount -= 1
				player.stored_resources[resource_type] = int(player.stored_resources.get(resource_type, 0)) + 1
				VW.GameLibrary.save_active_game()
				_refresh_all()
			return

func _on_city_selected(city_id):
	if int(_game_state.phase) != 4:
		return
	var seat = _active_seat()
	var occupants = _game_state.city_occupancy.get(city_id, [])
	if occupants.has(seat) or occupants.size() >= int(_game_state.step):
		return
	occupants.append(seat)
	_game_state.city_occupancy[city_id] = occupants
	_game_state.players[seat].built_cities.append(city_id)
	VW.GameLibrary.save_active_game()
	_refresh_all()

func _on_advance_phase():
	_game_state.phase = int(_game_state.phase) + 1
	if _game_state.phase > 5:
		_game_state.phase = 1
		_game_state.round_number = int(_game_state.round_number) + 1
	VW.GameLibrary.save_active_game()
	_refresh_all()

func _on_simulate_end_game():
	var standings = []
	for player in _game_state.players:
		standings.append({
			player_name = player.player_name,
			powered_cities = player.built_cities.size(),
			elektro = int(player.elektro),
			built_cities = player.built_cities.size()
		})
	standings.sort_custom(func(first, second):
		if first.powered_cities != second.powered_cities:
			return first.powered_cities > second.powered_cities
		if first.elektro != second.elektro:
			return first.elektro > second.elektro
		return first.built_cities > second.built_cities
	)
	_game_state.finished = true
	_game_state.standings = standings
	VW.GameLibrary.save_active_game()
	PlayerSummaryStrip.show_end_game_modal(self, _game_state)

func _on_return_to_menu():
	VW.GameLibrary.suspend_active_game()
	VW.Scenes.goto(VW.Scenes.MAIN_MENU)
