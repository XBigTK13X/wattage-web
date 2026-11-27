extends Node

const GameEngine = preload("res://script/instance/rules/game_engine.gd")
const ResourceMarket = preload("res://script/instance/rules/resource_market.gd")
const PlantMarket = preload("res://script/instance/rules/plant_market.gd")
const MapGraph = preload("res://script/instance/rules/map_graph.gd")
const AutomaController = preload("res://script/instance/rules/automa_controller.gd")
const RobotsExpansion = preload("res://script/instance/rules/robots_expansion.gd")
const NetworkProtocol = preload("res://script/instance/network/protocol.gd")
const SeatRegistry = preload("res://script/instance/network/seat_registry.gd")

var _failures = 0

func _ready():
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

	_test_maps_and_decks()
	_test_base_game_v1()
	_test_frida_automa()
	_test_robots_expansion()
	_test_networking_and_default_scene()

	print("Headless suite finished with " + str(_failures) + " failure(s).")
	get_tree().quit(1 if _failures > 0 else 0)

func _test_maps_and_decks():
	var germany = VW.Database.get_map("germany")
	var united_states = VW.Database.get_map("united_states")
	_assert_true(germany != null and germany.cities.size() == 42 and germany.is_adjacency_symmetric(), "Germany map 42 cities symmetric")
	_assert_true(united_states != null and united_states.cities.size() == 42 and united_states.is_adjacency_symmetric(), "United States map 42 cities symmetric")
	_assert_true(not VW.Database.list_maps().has("sample_map"), "sample_map hidden from default list_maps()")
	_assert_true(VW.Database.get_deck("base_game").cards.size() == 43, "base_game deck 43 cards")
	_assert_true(int(germany.player_count_info["5"].refill[1][3]) == 2 and int(germany.player_count_info["5"].refill[2][3]) == 3, "Germany 5P refill matches v1 rules")
	_assert_true(int(united_states.player_count_info["5"].refill[1][3]) == 2 and int(united_states.player_count_info["5"].refill[2][3]) == 3, "USA 5P refill matches v1 rules")

func _test_base_game_v1():
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
	_assert_true(match_state.actual_market == [3, 4, 5, 6] and match_state.futures_market == [7, 8, 9, 10], "Initial plant market 3-6 actual, 7-10 future")
	_assert_true(int(match_state.draw_pile[0]) == 13 and int(match_state.draw_pile[match_state.draw_pile.size() - 1]) == 0, "Plant 13 on top and Step 3 on bottom of draw pile")

	var pass_r1 = GameEngine.apply_action(match_state, 0, NetworkProtocol.ACTION_PASS_PHASE, {})
	_assert_true(not pass_r1.accepted, "Round 1 mandatory buy blocks passing Phase 2")

	var nom = GameEngine.apply_action(match_state, 0, NetworkProtocol.ACTION_SELECT_PLANT_FOR_AUCTION, { plant_number = 4 })
	var bid = GameEngine.apply_action(match_state, 1, NetworkProtocol.ACTION_PLACE_BID, { amount = 5 })
	var pas = GameEngine.apply_action(match_state, 0, NetworkProtocol.ACTION_PASS_AUCTION, {})
	_assert_true(nom.accepted and bid.accepted and pas.accepted and match_state.players[1].plants.has(4), "Phase 2 auction completes")
	_assert_true(GameEngine.active_seat(match_state) == 0, "Auctioneer retains turn when another player wins")
	_assert_true(ResourceMarket.can_store_resource(match_state.players[1], "base_game", "coal", 4), "Coal storage allows 4")
	_assert_true(not ResourceMarket.can_store_resource(match_state.players[1], "base_game", "coal", 5), "Coal storage blocks 5")

	var nom2 = GameEngine.apply_action(match_state, 0, NetworkProtocol.ACTION_SELECT_PLANT_FOR_AUCTION, { plant_number = 3 })
	_assert_true(nom2.accepted and int(match_state.phase) == 3, "Phase 2 completes after all buy in Round 1")

	match_state.phase = 2
	match_state.step = 1
	match_state.draw_pile = [0, 20, 21]
	PlantMarket.draw_replacement(match_state, 0)
	_assert_true(int(match_state.step) == 1 and bool(match_state.step_three_pending) and match_state.futures_market.has(0), "Step 3 card drawn in Phase 2 defers Step 3 until end of Phase 2")
	PlantMarket.finalize_step_three_if_pending(match_state)
	_assert_true(int(match_state.step) == 3 and not bool(match_state.step_three_pending) and match_state.futures_market.is_empty(), "Step 3 activates and clears futures market")

	var sample_map = VW.Database.get_map("sample_map")
	var sample_match = GameEngine.create_match({
		map_id = "sample_map",
		deck_id = "base_game",
		preserve_initial_order = true,
		seats = [
			{ player_name = "Alice", color = "red", control_mode = "local" },
			{ player_name = "Bob", color = "blue", control_mode = "local" }
		]
	})
	_assert_true(MapGraph.city_build_cost(sample_map, sample_match, 0, "alpha") == 10, "First city build cost is 10")

func _test_frida_automa():
	var frida_match = GameEngine.create_match({
		map_id = "germany",
		deck_id = "base_game",
		seats = [
			{ player_name = "Human", color = "yellow", control_mode = "local" },
			{ player_name = "Frida L", color = "red", control_mode = "automa_frida" },
			{ player_name = "Frida R", color = "blue", control_mode = "automa_frida" }
		]
	})
	_assert_true(frida_match.active_regions.size() == 3, "1P + 2 Frida uses 3P regions")
	var left_ran = AutomaController.take_turn_if_automa(frida_match)
	_assert_true(left_ran and frida_match.players[1].plants.size() == 1, "Frida Left claims Turn 1 plant before human")
	_assert_true(GameEngine.active_seat(frida_match) == 0, "Human acts after Frida Left in Turn 1")

	var frida_player = frida_match.players[1]
	frida_player.plants = [10]
	frida_match.actual_market = [5, 15, 16, 17]
	AutomaController._frida_claim_plant_directly(frida_match, 1, 5)
	_assert_true(frida_player.plants == [10, 5], "Frida tucks lower plant underneath top plant")
	AutomaController._frida_claim_plant_directly(frida_match, 1, 15)
	_assert_true(frida_player.plants == [15, 10, 5], "Frida places higher plant on top of stack")
	AutomaController._frida_claim_plant_directly(frida_match, 1, 16)
	_assert_true(frida_player.plants == [16, 15, 10], "Frida discards bottom plant when exceeding 3")

	var initial_coal = ResourceMarket.total_stock(frida_match.resource_market, "coal")
	frida_match.phase = 3
	frida_match.active_turn_position = frida_match.turn_order.find(1)
	frida_match.frida_state.phase_cards[1] = { resource1 = 1, resource2 = 1 }
	frida_player.plants = [4]
	AutomaController.take_turn_if_automa(frida_match)
	_assert_true(ResourceMarket.total_stock(frida_match.resource_market, "coal") < initial_coal, "Frida Phase 3 removes coal from market")
	_assert_true(int(frida_player.stored_resources.coal) == 0, "Frida does not store personal resource tokens")

func _test_robots_expansion():
	var profiles = RobotsExpansion.create_random_profiles(2)
	_assert_true(profiles.size() == 2 and profiles[0].first_city != RobotsExpansion.FIRST_CITY_EARLY_CHOICE_ALL and profiles[1].first_city != RobotsExpansion.FIRST_CITY_EARLY_CHOICE_ALL, "2+ Robots exclude FIRST_CITY_EARLY_CHOICE_ALL")

	var robot_match = GameEngine.create_match({
		map_id = "united_states",
		deck_id = "base_game",
		preserve_initial_order = true,
		seats = [
			{
				player_name = "Robot 1",
				color = "red",
				control_mode = "automa_robots",
				robot_profile = RobotsExpansion.create_default_profile(0)
			},
			{
				player_name = "Robot 2",
				color = "blue",
				control_mode = "automa_robots",
				robot_profile = RobotsExpansion.create_default_profile(1)
			},
			{
				player_name = "Robot 3",
				color = "green",
				control_mode = "automa_robots",
				robot_profile = RobotsExpansion.create_default_profile(2)
			}
		]
	})
	_assert_true(int(robot_match.players[0].elektro) == 100, "ABILITY_START_100_ELEKTRO initializes Robot with 100E")
	GameEngine.determine_player_order(robot_match)
	_assert_true(int(robot_match.turn_order[robot_match.turn_order.size() - 1]) == 1, "ABILITY_ALWAYS_LAST_ORDER places Robot 2 last in turn order")

	var steps = 0
	while steps < 25 and not bool(robot_match.finished) and AutomaController.take_turn_if_automa(robot_match):
		steps += 1
	_assert_true(steps > 10 and int(robot_match.round_number) >= 2, "Robots expansion simulates full round cleanly")

func _test_networking_and_default_scene():
	var registry = SeatRegistry.new()
	registry.configure_seats([
		{ player_name = "Local", color = "red", control_mode = SeatRegistry.CONTROL_LOCAL },
		{ player_name = "Remote", color = "blue", control_mode = SeatRegistry.CONTROL_REMOTE }
	])
	registry.assign_peer_to_seat(77, "phone_1", 1)
	registry.unbind_peer(77)
	_assert_true(registry.rebind_on_reconnect(88, "phone_1") == 1, "Seat hot-swap reconnects to seat 1")
	_assert_true(VW.Scenes.FIRST_SCENE == VW.Scenes.MAIN_MENU, "Default FIRST_SCENE is MAIN_MENU")
