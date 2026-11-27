extends Control

const ClientScreen = preload("res://script/scene/game/client_screen.gd")

static func init_container():
	return Control.new()

func _ready():
	VW.Database.ensure_loaded()
	var client = ClientScreen.new()
	client.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(client)

	var mock_public = {
		map_id = "sample_map",
		deck_id = "base_game",
		step = 1,
		phase = 4,
		active_seat = 1,
		active_regions = ["north", "south"],
		actual_market = [3, 4, 5, 6],
		city_occupancy = {
			alpha = [0],
			bravo = [1]
		},
		players = [
			{ seat_index = 0, player_name = "Host Local", color = "red" },
			{ seat_index = 1, player_name = "Android Player", color = "blue" }
		],
		auction = { active = false }
	}
	var mock_private = {
		seat_index = 1,
		player_name = "Android Player",
		color = "blue",
		elektro = 46,
		plants = [4, 13],
		stored_resources = { coal = 2, oil = 0, garbage = 0, uranium = 0 }
	}
	client.call_deferred("apply_state", mock_public, mock_private)
