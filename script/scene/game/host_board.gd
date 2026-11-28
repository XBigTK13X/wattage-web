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
var _tab_container = null
var _map_view = null
var _plant_market_panel = null
var _resource_market_panel = null
var _player_strip = null
var _stage_label = null
var _turn_label = null
var _phase_action_button = null
var _banner_label = null
var _toast_panel = null
var _toast_label = null
var _toast_tween = null
var _last_action_seq = 0
var _automa_pending = false
var _confirm_dialog = null
var _pending_city_id = ""
var _last_phase = -1
var _last_step = -1
var _last_turn_seat = -1

func _ready():
	VW.Database.ensure_loaded()
	_game_state = VW.GameLibrary.active_game
	if _game_state == null:
		VW.Scenes.goto(VW.Scenes.MAIN_MENU)
		return
	VW.Audio.set_client_mode(false)
	VW.Audio.play_map_music(_game_state.get("map_id", ""))
	_map_definition = VW.Database.get_map(_game_state.map_id)
	_last_phase = int(_game_state.get("phase", 1))
	_last_step = int(_game_state.get("step", 1))
	_last_turn_seat = _active_seat()
	_build_gui()
	VW.Network.peer_connected_to_host.connect(_on_peer_connected)
	VW.Network.peer_disconnected_from_host.connect(_on_peer_disconnected)
	_refresh_all()

func _build_gui():
	var root_margin = MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 12)
	root_margin.add_theme_constant_override("margin_right", 12)
	root_margin.add_theme_constant_override("margin_top", 10)
	root_margin.add_theme_constant_override("margin_bottom", 10)
	add_child(root_margin)

	var root_box = VBoxContainer.new()
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 8)
	root_margin.add_child(root_box)

	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	root_box.add_child(top_bar)

	var match_label = Label.new()
	match_label.text = str(_game_state.get("title", "Wattage Web Match"))
	match_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(match_label)

	_phase_action_button = VW.Chrome.styled_button("Done", 14)
	_phase_action_button.custom_minimum_size = Vector2(230, 36)
	_phase_action_button.pressed.connect(_on_phase_action_pressed)
	top_bar.add_child(_phase_action_button)

	var rules_button = VW.Chrome.styled_button("Rules & Log", 14)
	rules_button.custom_minimum_size = Vector2(130, 36)
	rules_button.pressed.connect(func(): RulesReferenceModal.open_modal(self, _game_state))
	top_bar.add_child(rules_button)

	var menu_button = VW.Chrome.styled_button("Main Menu (Pause)", 14)
	menu_button.custom_minimum_size = Vector2(170, 36)
	menu_button.pressed.connect(_on_return_to_menu)
	top_bar.add_child(menu_button)

	var status_bar = VW.Chrome.panel_container(Vector2(0, 48), Color(0.11, 0.14, 0.20, 0.96), Color(0.85, 0.68, 0.25, 0.9))
	root_box.add_child(status_bar)

	var status_row = HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 16)
	status_bar.add_child(status_row)

	_stage_label = Label.new()
	_stage_label.add_theme_font_size_override("font_size", 16)
	_stage_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.28))
	status_row.add_child(_stage_label)

	_turn_label = Label.new()
	_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_turn_label.clip_text = true
	_turn_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_turn_label.add_theme_font_size_override("font_size", 16)
	status_row.add_child(_turn_label)

	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_theme_font_size_override("font_size", 16)
	VW.Chrome.attach_focus_ring(_tab_container.get_tab_bar())
	root_box.add_child(_tab_container)

	_map_view = MapBoardView.new()
	_map_view.name = "Map"
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.city_selected.connect(_on_city_selected)
	_tab_container.add_child(_map_view)

	_plant_market_panel = PlantMarketPanel.new()
	_plant_market_panel.name = "Plant Market"
	_plant_market_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plant_market_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_plant_market_panel.plant_nominated.connect(_on_plant_nominated)
	_plant_market_panel.bid_placed.connect(_on_bid_placed)
	_plant_market_panel.auction_passed.connect(_on_auction_passed)
	_tab_container.add_child(_plant_market_panel)

	_resource_market_panel = ResourceMarketPanel.new()
	_resource_market_panel.name = "Resource Market"
	_resource_market_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resource_market_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_resource_market_panel.resource_clicked.connect(_on_resource_clicked)
	_tab_container.add_child(_resource_market_panel)

	_player_strip = PlayerSummaryStrip.new()
	_player_strip.name = "Players"
	_player_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(_player_strip)

	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.clip_text = true
	_banner_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_banner_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.28))
	root_box.add_child(_banner_label)

	_toast_panel = VW.Chrome.panel_container(Vector2(560, 56), Color(0.12, 0.16, 0.23, 0.96), Color(0.98, 0.82, 0.25, 1.0))
	_toast_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toast_panel.offset_left = 140
	_toast_panel.offset_right = -140
	_toast_panel.offset_top = -98
	_toast_panel.offset_bottom = -42
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 16)
	_toast_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.45))
	_toast_panel.add_child(_toast_label)

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.confirmed.connect(_on_city_build_confirmed)
	add_child(_confirm_dialog)

	_select_tab_for_phase(int(_game_state.get("phase", 2)))
	_tab_container.get_tab_bar().call_deferred("grab_focus")

func _unhandled_input(event):
	if _tab_container == null:
		return
	var tab_count = _tab_container.get_tab_count()
	if tab_count <= 0:
		return
	if event.is_action_pressed("next_panel"):
		_tab_container.current_tab = (_tab_container.current_tab + 1) % tab_count
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("previous_panel"):
		_tab_container.current_tab = (_tab_container.current_tab - 1 + tab_count) % tab_count
		get_viewport().set_input_as_handled()

func _refresh_all():
	var current_step = int(_game_state.get("step", 1))
	var current_phase = int(_game_state.get("phase", 1))
	var current_seat = _active_seat()
	var transition_played = false
	if current_step != _last_step:
		_last_step = current_step
		VW.Audio.play_sound_effect("step_transition")
		transition_played = true
	if current_phase != _last_phase:
		_last_phase = current_phase
		if not transition_played:
			VW.Audio.play_sound_effect("phase_change")
			transition_played = true
		_select_tab_for_phase(current_phase)
	if current_seat != _last_turn_seat:
		_last_turn_seat = current_seat
		if not transition_played and current_seat >= 0:
			var players = _game_state.get("players", [])
			if current_seat < players.size() and str(players[current_seat].get("control_mode", "local")) == "local":
				VW.Audio.play_sound_effect("turn_alert")
	_map_view.set_state(_map_definition, _game_state)
	_plant_market_panel.set_state(_game_state)
	_resource_market_panel.set_state(_game_state)
	_player_strip.set_state(_game_state)
	_update_turn_banner_and_controls()
	_update_action_feed_and_toast()
	if bool(_game_state.get("finished", false)):
		PlayerSummaryStrip.show_end_game_modal(self, _game_state)
		return
	_schedule_next_automa_step_if_needed()

func _schedule_next_automa_step_if_needed():
	if _automa_pending or bool(_game_state.get("finished", false)):
		return
	var seat = _active_seat()
	var players = _game_state.get("players", [])
	if seat < 0 or seat >= players.size():
		return
	var mode = str(players[seat].get("control_mode", "local"))
	if mode != "automa_frida" and mode != "automa_robots":
		return
	_automa_pending = true
	var timer = get_tree().create_timer(0.55)
	timer.timeout.connect(_on_automa_step_timeout)

func _on_automa_step_timeout():
	_automa_pending = false
	if not is_inside_tree() or _game_state == null or bool(_game_state.get("finished", false)):
		return
	if AutomaController.take_turn_if_automa(_game_state):
		VW.GameLibrary.save_active_game()
		VW.Network.broadcast_state()
		_refresh_all()

func _update_action_feed_and_toast():
	var history = _game_state.get("history", [])
	if not history.is_empty() and _banner_label != null:
		var recent = history.slice(-2)
		_banner_label.text = "  |  ".join(recent)
	var seq = int(_game_state.get("action_seq", 0))
	if seq > _last_action_seq:
		_last_action_seq = seq
		var event_data = _game_state.get("last_action_event", {})
		_play_sfx_for_action_event(str(event_data.get("message", "")))
		var text = str(event_data.get("entry", ""))
		if text != "":
			_play_action_toast(text)

func _play_sfx_for_action_event(message_text):
	if message_text == "":
		return
	if message_text.begins_with("Won Plant #") or message_text.begins_with("Claimed Plant #"):
		VW.Audio.play_sound_effect("auction_won")
	elif message_text.begins_with("Bid placed:") or message_text.ends_with("nominated"):
		VW.Audio.play_sound_effect("bid_placed")
	elif message_text.begins_with("Bought "):
		VW.Audio.play_sound_effect("resource_bought")
	elif message_text.begins_with("Built "):
		VW.Audio.play_sound_effect("city_built")
	elif message_text.begins_with("Powered ") or message_text.contains(" powered "):
		VW.Audio.play_sound_effect("power_up")

func _play_action_toast(message):
	if _toast_panel == null or _toast_label == null:
		return
	_toast_label.text = message
	_toast_panel.visible = true
	_toast_panel.modulate = Color(1, 1, 1, 0.0)
	_toast_panel.scale = Vector2(0.96, 0.96)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.16)
	_toast_tween.tween_property(_toast_panel, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(1.4)
	_toast_tween.chain().tween_property(_toast_panel, "modulate:a", 0.0, 0.35)
	_toast_tween.chain().tween_callback(func():
		if is_instance_valid(_toast_panel):
			_toast_panel.visible = false
	)

func _select_tab_for_phase(phase):
	if _tab_container == null:
		return
	if phase == 2:
		_tab_container.current_tab = 1
	elif phase == 3:
		_tab_container.current_tab = 2
	elif phase == 4:
		_tab_container.current_tab = 0
	elif phase == 5:
		_tab_container.current_tab = 3

func _phase_title(phase):
	match phase:
		1:
			return "Determine Player Order"
		2:
			return "Auction Power Plants"
		3:
			return "Buy Resources"
		4:
			return "Build Cities"
		5:
			return "Bureaucracy"
		_:
			return "Game Over"

func _update_turn_banner_and_controls():
	var round_num = int(_game_state.get("round_number", 1))
	var step_num = int(_game_state.get("step", 1))
	var phase = int(_game_state.get("phase", 1))
	var auction_active = bool(_game_state.get("auction", {}).get("active", false))
	var seat = _active_seat()
	var players = _game_state.get("players", [])
	var active_player = players[seat] if seat >= 0 and seat < players.size() else null
	var is_local = active_player != null and str(active_player.get("control_mode", "local")) == "local"

	_stage_label.text = "Round " + str(round_num) + " | Step " + str(step_num) + " | Phase " + str(phase) + ": " + _phase_title(phase)

	if active_player == null:
		_turn_label.text = "Match Complete"
		_phase_action_button.visible = false
		return

	var player_label = str(active_player.player_name) + (" (Local)" if is_local else " (Remote Client)")
	var instruction = ""
	if not is_local:
		instruction = "Waiting for remote player..."
		_phase_action_button.visible = false
	elif phase == 2:
		if auction_active:
			instruction = "Bid or Pass on Plant #" + str(_game_state.auction.plant_number)
			_phase_action_button.visible = false
		elif round_num == 1:
			instruction = "Select a plant in Actual Market (Round 1 mandatory buy)"
			_phase_action_button.visible = false
		else:
			instruction = "Select a plant in Actual Market or Pass Phase 2"
			_phase_action_button.text = "Pass Phase 2"
			_phase_action_button.visible = true
	elif phase == 3:
		instruction = "Buy resources or finish Phase 3"
		_phase_action_button.text = "Done Buying Resources"
		_phase_action_button.visible = true
	elif phase == 4:
		instruction = "Click a green city on map or finish Phase 4"
		_phase_action_button.text = "Done Building Cities"
		_phase_action_button.visible = true
	elif phase == 5:
		instruction = "Power plants to collect Bureaucracy income"
		_phase_action_button.text = "Power Plants & Collect"
		_phase_action_button.visible = true
	else:
		_phase_action_button.visible = false

	_turn_label.text = "Turn: " + player_label + " - " + instruction

func _active_seat():
	return GameEngine.active_seat(_game_state)

func _commit_local_action(action_name, parameters = {}):
	var seat = _active_seat()
	var players = _game_state.get("players", [])
	if seat < 0 or seat >= players.size() or str(players[seat].get("control_mode", "local")) != "local":
		VW.Audio.play_sound_effect("action_invalid")
		return { accepted = false, message = "Waiting for non-local player" }
	var result = GameEngine.apply_action(_game_state, seat, action_name, parameters)
	if result.accepted:
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

func _on_phase_action_pressed():
	if int(_game_state.get("phase", 1)) == 5:
		var seat = _active_seat()
		var players = _game_state.get("players", [])
		if seat >= 0 and seat < players.size():
			_commit_local_action(NetworkProtocol.ACTION_POWER_PLANTS, { plants = players[seat].plants })
			return
	_commit_local_action(NetworkProtocol.ACTION_PASS_PHASE, {})

func _on_return_to_menu():
	VW.GameLibrary.suspend_active_game()
	VW.Scenes.goto(VW.Scenes.MAIN_MENU)
