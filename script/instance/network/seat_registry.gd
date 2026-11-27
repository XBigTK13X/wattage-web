extends RefCounted

const CONTROL_LOCAL = "local"
const CONTROL_REMOTE = "remote"
const CONTROL_AUTOMA_FRIDA = "automa_frida"
const CONTROL_AUTOMA_ROBOTS = "automa_robots"

var seats = []

func configure_seats(seat_configs):
	seats.clear()
	for index in range(seat_configs.size()):
		var config = seat_configs[index]
		seats.append({
			seat_index = index,
			player_name = str(config.get("player_name", "Player " + str(index + 1))),
			color = str(config.get("color", "red")),
			control_mode = str(config.get("control_mode", CONTROL_LOCAL)),
			device_id = str(config.get("device_id", "")),
			peer_id = int(config.get("peer_id", 0)),
			connected = str(config.get("control_mode", CONTROL_LOCAL)) != CONTROL_REMOTE
		})

func assign_peer_to_seat(peer_id, device_id, seat_index):
	if seat_index < 0 or seat_index >= seats.size():
		return false
	for seat in seats:
		if seat.peer_id == peer_id and seat.seat_index != seat_index:
			seat.peer_id = 0
			if seat.control_mode == CONTROL_REMOTE:
				seat.connected = false
	var target = seats[seat_index]
	target.control_mode = CONTROL_REMOTE
	target.device_id = str(device_id)
	target.peer_id = int(peer_id)
	target.connected = true
	return true

func rebind_on_reconnect(peer_id, device_id):
	var normalized_device = str(device_id)
	if normalized_device == "":
		return -1
	for seat in seats:
		if seat.control_mode == CONTROL_REMOTE and seat.device_id == normalized_device:
			seat.peer_id = int(peer_id)
			seat.connected = true
			return seat.seat_index
	return -1

func unbind_peer(peer_id):
	var unbound_seat = -1
	for seat in seats:
		if seat.peer_id == int(peer_id):
			seat.peer_id = 0
			if seat.control_mode == CONTROL_REMOTE:
				seat.connected = false
			unbound_seat = seat.seat_index
	return unbound_seat

func get_seat_for_peer(peer_id):
	for seat in seats:
		if seat.peer_id == int(peer_id):
			return seat
	return null

func get_seat(seat_index):
	if seat_index < 0 or seat_index >= seats.size():
		return null
	return seats[seat_index]

func to_public_list():
	var output = []
	for seat in seats:
		output.append({
			seat_index = seat.seat_index,
			player_name = seat.player_name,
			color = seat.color,
			control_mode = seat.control_mode,
			connected = seat.connected
		})
	return output
