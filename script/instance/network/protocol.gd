extends RefCounted

const ACTION_SELECT_PLANT_FOR_AUCTION = "select_plant_for_auction"
const ACTION_PLACE_BID = "place_bid"
const ACTION_PASS_AUCTION = "pass_auction"
const ACTION_BUY_RESOURCE = "buy_resource"
const ACTION_BUILD_CITY = "build_city"
const ACTION_POWER_PLANTS = "power_plants"
const ACTION_PASS_PHASE = "pass_phase"

const VALID_ACTIONS = [
	ACTION_SELECT_PLANT_FOR_AUCTION,
	ACTION_PLACE_BID,
	ACTION_PASS_AUCTION,
	ACTION_BUY_RESOURCE,
	ACTION_BUILD_CITY,
	ACTION_POWER_PLANTS,
	ACTION_PASS_PHASE
]

const MESSAGE_HANDSHAKE = "handshake"
const MESSAGE_HANDSHAKE_ACK = "handshake_ack"
const MESSAGE_ACTION_REQUEST = "action_request"
const MESSAGE_ACTION_RESULT = "action_result"
const MESSAGE_STATE_SYNC = "state_sync"
const MESSAGE_SEAT_ASSIGNED = "seat_assigned"

const ERROR_UNKNOWN_ACTION = "UNKNOWN_ACTION"
const ERROR_NO_SEAT_ASSIGNED = "NO_SEAT_ASSIGNED"
const ERROR_NOT_YOUR_TURN = "NOT_YOUR_TURN"
const ERROR_INVALID_PHASE = "INVALID_PHASE"
const ERROR_INSUFFICIENT_ELEKTRO = "INSUFFICIENT_ELEKTRO"
const ERROR_ILLEGAL_ACTION = "ILLEGAL_ACTION"

static func is_valid_action_name(action_name):
	return VALID_ACTIONS.has(str(action_name))

static func build_handshake(device_id, device_name):
	return {
		type = MESSAGE_HANDSHAKE,
		device_id = str(device_id),
		device_name = str(device_name)
	}

static func build_action_request(request_id, action_name, parameters = {}):
	return {
		type = MESSAGE_ACTION_REQUEST,
		request_id = str(request_id),
		action = str(action_name),
		parameters = parameters.duplicate(true)
	}

static func build_action_result(request_id, accepted, error_code = "", message = ""):
	return {
		type = MESSAGE_ACTION_RESULT,
		request_id = str(request_id),
		accepted = bool(accepted),
		error_code = str(error_code),
		message = str(message)
	}

static func build_state_sync(public_state, private_state):
	return {
		type = MESSAGE_STATE_SYNC,
		public_state = public_state.duplicate(true),
		private_state = private_state.duplicate(true)
	}
