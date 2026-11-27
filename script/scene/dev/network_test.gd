extends Control

const NetworkProtocol = preload("res://script/instance/network/protocol.gd")
const SeatRegistry = preload("res://script/instance/network/seat_registry.gd")

static func init_container():
	return Control.new()

var _output_label = null
var _status_label = null

func _ready():
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(780, 520))
	center.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var title_label = Label.new()
	title_label.text = "Wattage Web Networking & Protocol Verification"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	layout.add_child(title_label)

	_status_label = Label.new()
	_status_label.text = "Mode: Idle"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_status_label)

	var buttons_row = HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 12)
	layout.add_child(buttons_row)

	var self_test_button = VW.Chrome.styled_button("Run Protocol & Seat Self-Test")
	self_test_button.pressed.connect(_run_self_test)
	buttons_row.add_child(self_test_button)

	var host_button = VW.Chrome.styled_button("Start Host (4242)")
	host_button.pressed.connect(_on_start_host)
	buttons_row.add_child(host_button)

	var client_button = VW.Chrome.styled_button("Connect Localhost")
	client_button.pressed.connect(_on_start_client)
	buttons_row.add_child(client_button)

	_output_label = Label.new()
	_output_label.text = "Click 'Run Protocol & Seat Self-Test' or test live ENet Host/Client."
	_output_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_output_label)

	VW.Network.client_connected.connect(func(): _status_label.text = "Mode: Client Connected")
	VW.Network.client_disconnected.connect(func(): _status_label.text = "Mode: Client Disconnected")

	_run_self_test()

func _on_start_host():
	var result = VW.Network.start_host(4242, "Wattage Web Test Host")
	_status_label.text = "Mode: Host (result=" + str(result) + ")"

func _on_start_client():
	var result = VW.Network.start_client("127.0.0.1", 4242, "local_android_test", "Test Android")
	_status_label.text = "Mode: Client Connecting (result=" + str(result) + ")"

func _run_self_test():
	var results = []
	var network = VW.Network
	network.seat_registry.configure_seats([
		{ player_name = "Host Local", color = "red", control_mode = SeatRegistry.CONTROL_LOCAL },
		{ player_name = "Phone A", color = "blue", control_mode = SeatRegistry.CONTROL_REMOTE },
		{ player_name = "Phone B", color = "green", control_mode = SeatRegistry.CONTROL_REMOTE }
	])
	network.seat_registry.assign_peer_to_seat(101, "dev_a", 1)
	network.seat_registry.assign_peer_to_seat(102, "dev_b", 2)

	var mock_state = {
		active_seat = 1,
		phase = "phase_2_auction",
		elektro = { 0: 50, 1: 42, 2: 12 }
	}
	network.set_action_validator(func(seat_index, action_name, parameters):
		if seat_index != mock_state.active_seat:
			return { accepted = false, error_code = NetworkProtocol.ERROR_NOT_YOUR_TURN, message = "Not your turn" }
		if action_name == NetworkProtocol.ACTION_BUY_RESOURCE:
			return { accepted = false, error_code = NetworkProtocol.ERROR_INVALID_PHASE, message = "Wrong phase" }
		if action_name == NetworkProtocol.ACTION_PLACE_BID and int(parameters.get("amount", 0)) > mock_state.elektro[seat_index]:
			return { accepted = false, error_code = NetworkProtocol.ERROR_INSUFFICIENT_ELEKTRO, message = "Not enough Elektro" }
		return { accepted = true, error_code = "", message = "OK" }
	)
	network.set_state_provider(func(seat_index):
		var public_view = { phase = mock_state.phase, active_seat = mock_state.active_seat, seats = network.seat_registry.to_public_list() }
		var private_view = {}
		if seat_index >= 0:
			private_view = { seat_index = seat_index, elektro = mock_state.elektro[seat_index] }
		return { public_state = public_view, private_state = private_view }
	)

	var valid_res = network.handle_host_message(101, NetworkProtocol.build_action_request("r1", NetworkProtocol.ACTION_PLACE_BID, { amount = 10 }))
	results.append("Valid bid accepted: " + str(valid_res.accepted == true))

	var wrong_turn = network.handle_host_message(102, NetworkProtocol.build_action_request("r2", NetworkProtocol.ACTION_PLACE_BID, { amount = 10 }))
	results.append("Wrong turn rejected (" + wrong_turn.error_code + "): " + str(wrong_turn.error_code == NetworkProtocol.ERROR_NOT_YOUR_TURN))

	var wrong_phase = network.handle_host_message(101, NetworkProtocol.build_action_request("r3", NetworkProtocol.ACTION_BUY_RESOURCE, { resource = "coal" }))
	results.append("Wrong phase rejected (" + wrong_phase.error_code + "): " + str(wrong_phase.error_code == NetworkProtocol.ERROR_INVALID_PHASE))

	var low_elektro = network.handle_host_message(101, NetworkProtocol.build_action_request("r4", NetworkProtocol.ACTION_PLACE_BID, { amount = 99 }))
	results.append("Insufficient Elektro rejected (" + low_elektro.error_code + "): " + str(low_elektro.error_code == NetworkProtocol.ERROR_INSUFFICIENT_ELEKTRO))

	var sync_one = network.build_state_payload_for_seat(1)
	var sync_two = network.build_state_payload_for_seat(2)
	var state_isolated = sync_one.private_state.elektro == 42 and sync_two.private_state.elektro == 12
	results.append("Public/Private state isolation: " + str(state_isolated))

	network.seat_registry.unbind_peer(101)
	var rebound_index = network.seat_registry.rebind_on_reconnect(205, "dev_a")
	results.append("Hot-swap reconnect seat 1: " + str(rebound_index == 1 and network.seat_registry.get_seat(1).peer_id == 205))

	_output_label.text = "\n".join(results)
