extends SceneTree

const GameEngine = preload("res://script/instance/rules/game_engine.gd")
const ResourceMarket = preload("res://script/instance/rules/resource_market.gd")
const MapGraph = preload("res://script/instance/rules/map_graph.gd")
const AutomaController = preload("res://script/instance/rules/automa_controller.gd")
const NetworkProtocol = preload("res://script/instance/network/protocol.gd")
const SeatRegistry = preload("res://script/instance/network/seat_registry.gd")

var _failures = 0

func _initialize():
	call_deferred("_run_all")

func _assert_true(condition, label):
	if condition:
		print("PASS: " + label)
	else:
		_failures += 1
		printerr("FAIL: " + label)

func _run_all():
	VW.reset()
	VW.Database.load_all()

	var germany = VW.Database.get_map("germany")
	var united_states = VW.Database.get_map("united_states")
	_assert_true(germany != null and germany.cities.size() == 42 and germany.is_adjacency_symmetric(), "Germany map 42 cities symmetric")
	_assert_true(united_states != null and united_states.cities.size() == 42 and united_states.is_adjacency_symmetric(), "United States map 42 cities symmetric")
	_assert_true(not VW.Database.list_maps().has("sample_map"), "sample_map hidden from default list_maps()")
	_assert_true(VW.Database.get_deck("base_game").cards.size() == 43, "base_game deck 43 cards")

	var match_state = GameEngine.create_match({
		map_id = "germany",
		deck_id = "base_game",
		preserve_initial_order = true,
		seats = [
			{ player_name = "Alice", color = "red", control_mode = "local" },
			{ player_name = "Bob", color = "blue", control_mode = "local" }
		]
	})
	_assert_true(match_state.active_regions.size() == 3, "2P Germany uses 3 active regions")
	var nom = GameEngine.apply_action(match_state, 0, NetworkProtocol.ACTION_SELECT_PLANT_FOR_AUCTION, { plant_number = 4 })
	var bid = GameEngine.apply_action(match_state, 1, NetworkProtocol.ACTION_PLACE_BID, { amount = 5 })
	var pas = GameEngine.apply_action(match_state, 0, NetworkProtocol.ACTION_PASS_AUCTION, {})
	_assert_true(nom.accepted and bid.accepted and pas.accepted and match_state.players[1].plants.has(4), "Phase 2 auction completes")
	_assert_true(ResourceMarket.can_store_resource(match_state.players[1], "base_game", "coal", 4), "Coal storage allows 4")
	_assert_true(not ResourceMarket.can_store_resource(match_state.players[1], "base_game", "coal", 5), "Coal storage blocks 5")

	var sample_map = VW.Database.get_map("sample_map")
	_assert_true(MapGraph.city_build_cost(sample_map, match_state, 0, "alpha") == 10, "First city build cost is 10")

	var registry = SeatRegistry.new()
	registry.configure_seats([
		{ player_name = "Local", color = "red", control_mode = SeatRegistry.CONTROL_LOCAL },
		{ player_name = "Remote", color = "blue", control_mode = SeatRegistry.CONTROL_REMOTE }
	])
	registry.assign_peer_to_seat(77, "phone_1", 1)
	registry.unbind_peer(77)
	_assert_true(registry.rebind_on_reconnect(88, "phone_1") == 1, "Seat hot-swap reconnects to seat 1")

	var automa_match = GameEngine.create_match({
		map_id = "germany",
		deck_id = "base_game",
		preserve_initial_order = true,
		seats = [
			{ player_name = "Frida", color = "red", control_mode = "automa_frida" },
			{ player_name = "Robot", color = "blue", control_mode = "automa_robots" }
		]
	})
	var automa_steps = 0
	while automa_steps < 12 and AutomaController.take_turn_if_automa(automa_match):
		automa_steps += 1
	_assert_true(automa_steps > 0, "Automa simulation advances turns")

	print("Headless suite finished with " + str(_failures) + " failure(s).")
	quit(1 if _failures > 0 else 0)
