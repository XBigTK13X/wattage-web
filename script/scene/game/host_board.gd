extends Control

const GameEngine = preload("res://script/instance/rules/game_engine.gd")
const AutomaController = preload("res://script/instance/rules/automa_controller.gd")
const NetworkProtocol = preload("res://script/instance/network/protocol.gd")
const MapBoardView = preload("res://script/instance/ui/map_board_view.gd")
const PlantMarketPanel = preload("res://script/instance/ui/plant_market_panel.gd")
const ResourceMarketPanel = preload("res://script/instance/ui/resource_market_panel.gd")
const PlayerSummaryStrip = preload("res://script/instance/ui/player_summary_strip.gd")
const RulesReferenceModal = preload("res://script/instance/ui/rules_reference_modal.gd")

static func init_container():
	return Control.new()

var _game_state = null
var _map_definition = null
var _map_view = null
var _plant_market_panel = null
var _resource_market_panel = null
var _player_strip = null
var _banner_label = null
var _confirm_dialog = null
var _pending_city_id = ""
var _last_phase = -1

func _ready():
	VW.Database.ensure_loaded()
	_game_state = VW.GameLibrary.active_game
	if _game_state == null:
		VW.Scenes.goto(VW.Scenes.MAIN_MENU)
		return
	_map_definition = VW.Database.get_map(_game_state.map_id)
	_last_phase = int(_game_state.get("phase", 1))
	_build_gui()
	VW.Network.peer_connected_to_host.connect(_on_peer_connected)
	VW.Network.peer_disconnected_from_host.connect(_on_peer_disconnected)
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
	match_label.text = str(_game_state.get("title", "Wattage Web Match"))
	match_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(match_label)

	var advance_phase_button = VW.Chrome.styled_button("Advance Phase", 14)
	advance_phase_button.custom_minimum_size = Vector2(150, 36)
	advance_phase_button.pressed.connect(_on_advance_phase)
	top_bar.add_child(advance_phase_button)

	var rules_button = VW.Chrome.styled_button("Rules & Log", 14)
	rules_button.custom_minimum_size = Vector2(130, 36)
	rules_button.pressed.connect(func(): RulesReferenceModal.open_modal(self, _game_state))
	top_bar.add_child(rules_button)

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

	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.28))
	root_box.add_child(_banner_label)

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.confirmed.connect(_on_city_build_confirmed)
	add_child(_confirm_dialog)

func _refresh_all():
	var guard_steps = 0
	while not bool(_game_state.get("finished", false)) and guard_steps < 12 and AutomaController.take_turn_if_automa(_game_state):
		guard_steps += 1
	var current_phase = int(_game_state.get("phase", 1))
	if current_phase != _last_phase:
		_last_phase = current_phase
		if _banner_label != null:
			_banner_label.text = "Entered Phase " + str(current_phase) + " (Round " + str(_game_state.get("round_number", 1)) + ")"
		VW.Audio.play_sound_effect("phase_change")
	_map_view.set_state(_map_definition, _game_state)
	_plant_market_panel.set_state(_game_state)
	_resource_market_panel.set_state(_game_state)
	_player_strip.set_state(_game_state)
	if bool(_game_state.get("finished", false)):
		PlayerSummaryStrip.show_end_game_modal(self, _game_state)

func _active_seat():
	return GameEngine.active_seat(_game_state)

func _commit_local_action(action_name, parameters = {}):
	var seat = _active_seat()
	var result = GameEngine.apply_action(_game_state, seat, action_name, parameters)
	if result.accepted:
		var history = _game_state.get("history", [])
		var entry = "Seat " + str(seat + 1) + ": " + str(result.get("message", action_name))
		history.append(entry)
		_game_state["history"] = history
		VW.EventLog.notify(entry)
		VW.GameLibrary.save_active_game()
		VW.Network.broadcast_state()
		_refresh_all()
	else:
		VW.Audio.play_sound_effect("action_invalid")
		if _banner_label != null:
			_banner_label.text = str(result.get("message", "Invalid action"))
	return result

func _on_city_selected(city_id):
	if int(_game_state.phase) != 4:
		return
	_pending_city_id = city_id
	_confirm_dialog.dialog_text = "Build in " + str(city_id).capitalize() + "?"
	_confirm_dialog.popup_centered()

func _on_city_build_confirmed():
	if _pending_city_id != "":
		_commit_local_action(NetworkProtocol.ACTION_BUILD_CITY, { city_id = _pending_city_id })
		_pending_city_id = ""

func _on_peer_connected(peer_id, device_info):
	var msg = "Client connected (peer " + str(peer_id) + ": " + str(device_info.get("device_name", "Client")) + ")"
	VW.EventLog.notify(msg)
	if _banner_label != null:
		_banner_label.text = msg

func _on_peer_disconnected(peer_id, seat_index):
	var msg = "Client disconnected (peer " + str(peer_id) + ", seat " + str(seat_index) + ") - awaiting reconnect"
	VW.EventLog.notify(msg)
	if _banner_label != null:
		_banner_label.text = msg

func _on_plant_nominated(plant_number):
	_commit_local_action(NetworkProtocol.ACTION_SELECT_PLANT_FOR_AUCTION, { plant_number = plant_number })

func _on_bid_placed(increment):
	_commit_local_action(NetworkProtocol.ACTION_PLACE_BID, { increment = increment })

func _on_auction_passed():
	_commit_local_action(NetworkProtocol.ACTION_PASS_AUCTION, {})

func _on_resource_clicked(resource_type):
	_commit_local_action(NetworkProtocol.ACTION_BUY_RESOURCE, { resource = resource_type, amount = 1 })

func _on_advance_phase():
	_commit_local_action(NetworkProtocol.ACTION_PASS_PHASE, {})

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
