extends Node

const NetworkProtocol = preload("res://script/instance/network/protocol.gd")
const SeatRegistry = preload("res://script/instance/network/seat_registry.gd")

const DEFAULT_PORT = 4242
const DISCOVERY_PORT = 4243
const DISCOVERY_MAGIC = "WATTAGE_WEB_DISCOVER"

enum Mode {
	NONE,
	HOST,
	CLIENT
}

signal peer_connected_to_host(peer_id, device_info)
signal peer_disconnected_from_host(peer_id, seat_index)
signal client_connected()
signal client_disconnected()
signal state_received(public_state, private_state)
signal action_result_received(result)
signal lan_host_discovered(host_info)

var mode = Mode.NONE
var seat_registry = SeatRegistry.new()
var connected_peers = {}
var local_device_id = ""
var local_device_name = "Client Device"
var last_public_state = {}
var last_private_state = {}

var _peer = null
var _discovery_server = null
var _discovery_client = null
var _discovery_active = false
var _action_validator = Callable()
var _state_provider = Callable()
var _host_title = "Wattage Web Match"
var _host_port = DEFAULT_PORT

func _ready():
	if local_device_id == "":
		local_device_id = "device_" + str(OS.get_unique_id()).sha256_text().substr(0, 12)
	set_process(true)

func _process(_delta):
	if mode == Mode.HOST:
		_poll_discovery_server()
	if _discovery_active:
		_poll_discovery_client()

func set_action_validator(validator):
	_action_validator = validator

func set_state_provider(provider):
	_state_provider = provider

func start_host(port = DEFAULT_PORT, host_title = "Wattage Web Match"):
	stop_network()
	_host_port = int(port)
	_host_title = str(host_title)
	var enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_server(_host_port, 16)
	if error != OK:
		return error
	_peer = enet_peer
	multiplayer.multiplayer_peer = _peer
	mode = Mode.HOST
	_connect_multiplayer_signals()
	_start_discovery_server()
	return OK

func start_client(host_address, port = DEFAULT_PORT, device_id = "", device_name = "Android Client"):
	stop_network()
	if device_id != "":
		local_device_id = str(device_id)
	if device_name != "":
		local_device_name = str(device_name)
	var enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_client(str(host_address), int(port))
	if error != OK:
		return error
	_peer = enet_peer
	multiplayer.multiplayer_peer = _peer
	mode = Mode.CLIENT
	_connect_multiplayer_signals()
	return OK

func stop_network():
	_disconnect_multiplayer_signals()
	if _peer != null:
		_peer.close()
		_peer = null
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	if _discovery_server != null:
		_discovery_server.close()
		_discovery_server = null
	connected_peers.clear()
	mode = Mode.NONE

func begin_lan_discovery():
	if _discovery_client != null:
		_discovery_client.close()
	_discovery_client = PacketPeerUDP.new()
	_discovery_client.set_broadcast_enabled(true)
	if _discovery_client.bind(0) == OK:
		_discovery_client.set_dest_address("255.255.255.255", DISCOVERY_PORT)
		_discovery_client.put_packet(DISCOVERY_MAGIC.to_utf8_buffer())
		_discovery_active = true

func stop_lan_discovery():
	_discovery_active = false
	if _discovery_client != null:
		_discovery_client.close()
		_discovery_client = null

func send_action_request(action_name, parameters = {}):
	var request_id = str(Time.get_ticks_usec())
	var payload = NetworkProtocol.build_action_request(request_id, action_name, parameters)
	if mode == Mode.CLIENT:
		_receive_client_packet.rpc_id(1, JSON.stringify(payload))
		return request_id
	if mode == Mode.HOST:
		var result = handle_host_action_from_seat(0, payload)
		action_result_received.emit(result)
		return request_id
	return ""

func broadcast_state():
	if mode != Mode.HOST:
		return
	var public_state = _build_public_state()
	for peer_id in connected_peers.keys():
		var seat = seat_registry.get_seat_for_peer(peer_id)
		var private_state = _build_private_state(seat.seat_index if seat != null else -1)
		var sync_payload = NetworkProtocol.build_state_sync(public_state, private_state)
		_receive_host_packet.rpc_id(peer_id, JSON.stringify(sync_payload))

func handle_host_message(peer_id, payload):
	var message_type = str(payload.get("type", ""))
	if message_type == NetworkProtocol.MESSAGE_HANDSHAKE:
		var device_id = str(payload.get("device_id", ""))
		var device_name = str(payload.get("device_name", "Remote Client"))
		connected_peers[peer_id] = {
			peer_id = peer_id,
			device_id = device_id,
			device_name = device_name
		}
		var rebound_seat = seat_registry.rebind_on_reconnect(peer_id, device_id)
		peer_connected_to_host.emit(peer_id, connected_peers[peer_id])
		var ack = {
			type = NetworkProtocol.MESSAGE_HANDSHAKE_ACK,
			peer_id = peer_id,
			seat_index = rebound_seat,
			host_title = _host_title
		}
		_send_to_peer(peer_id, ack)
		if rebound_seat != -1:
			var public_state = _build_public_state()
			var private_state = _build_private_state(rebound_seat)
			_send_to_peer(peer_id, NetworkProtocol.build_state_sync(public_state, private_state))
		return ack
	if message_type == NetworkProtocol.MESSAGE_ACTION_REQUEST:
		var seat = seat_registry.get_seat_for_peer(peer_id)
		var request_id = str(payload.get("request_id", ""))
		if seat == null:
			var denied = NetworkProtocol.build_action_result(request_id, false, NetworkProtocol.ERROR_NO_SEAT_ASSIGNED, "No seat assigned to this client")
			_send_to_peer(peer_id, denied)
			return denied
		var result = handle_host_action_from_seat(seat.seat_index, payload)
		_send_to_peer(peer_id, result)
		if result.accepted:
			broadcast_state()
		return result
	return {}

func handle_host_action_from_seat(seat_index, payload):
	var request_id = str(payload.get("request_id", ""))
	var action_name = str(payload.get("action", ""))
	if not NetworkProtocol.is_valid_action_name(action_name):
		return NetworkProtocol.build_action_result(request_id, false, NetworkProtocol.ERROR_UNKNOWN_ACTION, "Unsupported action: " + action_name)
	if _action_validator.is_valid():
		var validation = _action_validator.call(seat_index, action_name, payload.get("parameters", {}))
		var accepted = bool(validation.get("accepted", false))
		var error_code = str(validation.get("error_code", ""))
		var message = str(validation.get("message", ""))
		return NetworkProtocol.build_action_result(request_id, accepted, error_code, message)
	return NetworkProtocol.build_action_result(request_id, true, "", "Action accepted")

func build_state_payload_for_seat(seat_index):
	return NetworkProtocol.build_state_sync(_build_public_state(), _build_private_state(seat_index))

func _build_public_state():
	if _state_provider.is_valid():
		var provided = _state_provider.call(-1)
		if typeof(provided) == TYPE_DICTIONARY and provided.has("public_state"):
			return provided.public_state
	return {
		host_title = _host_title,
		seats = seat_registry.to_public_list(),
		phase = "setup",
		step = 1
	}

func _build_private_state(seat_index):
	if seat_index < 0:
		return {}
	if _state_provider.is_valid():
		var provided = _state_provider.call(seat_index)
		if typeof(provided) == TYPE_DICTIONARY and provided.has("private_state"):
			return provided.private_state
	var seat = seat_registry.get_seat(seat_index)
	if seat == null:
		return {}
	return {
		seat_index = seat_index,
		player_name = seat.player_name,
		color = seat.color,
		elektro = 50,
		plants = [],
		legal_actions = []
	}

func _send_to_peer(peer_id, payload):
	if mode == Mode.HOST and multiplayer.has_multiplayer_peer() and connected_peers.has(peer_id):
		if multiplayer.get_peers().has(peer_id):
			_receive_host_packet.rpc_id(peer_id, JSON.stringify(payload))

@rpc("any_peer", "reliable")
func _receive_client_packet(json_text):
	if mode != Mode.HOST:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	handle_host_message(sender_id, parsed)

@rpc("authority", "reliable")
func _receive_host_packet(json_text):
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var message_type = str(parsed.get("type", ""))
	if message_type == NetworkProtocol.MESSAGE_STATE_SYNC:
		last_public_state = parsed.get("public_state", {})
		last_private_state = parsed.get("private_state", {})
		state_received.emit(last_public_state, last_private_state)
	elif message_type == NetworkProtocol.MESSAGE_ACTION_RESULT:
		action_result_received.emit(parsed)

func _connect_multiplayer_signals():
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _disconnect_multiplayer_signals():
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)

func _on_peer_connected(peer_id):
	if mode == Mode.HOST:
		connected_peers[peer_id] = {
			peer_id = peer_id,
			device_id = "",
			device_name = "Pending Handshake"
		}

func _on_peer_disconnected(peer_id):
	if mode == Mode.HOST:
		connected_peers.erase(peer_id)
		var unbound_seat = seat_registry.unbind_peer(peer_id)
		peer_disconnected_from_host.emit(peer_id, unbound_seat)

func _on_connected_to_server():
	if mode == Mode.CLIENT:
		var handshake = NetworkProtocol.build_handshake(local_device_id, local_device_name)
		_receive_client_packet.rpc_id(1, JSON.stringify(handshake))
		client_connected.emit()

func _on_server_disconnected():
	if mode == Mode.CLIENT:
		client_disconnected.emit()

func _start_discovery_server():
	_discovery_server = PacketPeerUDP.new()
	_discovery_server.bind(DISCOVERY_PORT)

func _poll_discovery_server():
	if _discovery_server == null:
		return
	while _discovery_server.get_available_packet_count() > 0:
		var packet_text = _discovery_server.get_packet().get_string_from_utf8()
		var remote_ip = _discovery_server.get_packet_ip()
		var remote_port = _discovery_server.get_packet_port()
		if packet_text == DISCOVERY_MAGIC:
			var response = JSON.stringify({
				host_title = _host_title,
				port = _host_port,
				seat_count = seat_registry.seats.size()
			})
			_discovery_server.set_dest_address(remote_ip, remote_port)
			_discovery_server.put_packet(response.to_utf8_buffer())

func _poll_discovery_client():
	if _discovery_client == null:
		return
	while _discovery_client.get_available_packet_count() > 0:
		var packet_text = _discovery_client.get_packet().get_string_from_utf8()
		var remote_ip = _discovery_client.get_packet_ip()
		var parsed = JSON.parse_string(packet_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			parsed["address"] = remote_ip
			lan_host_discovered.emit(parsed)
