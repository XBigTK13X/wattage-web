extends Control

const GameEngine = preload("res://script/instance/rules/game_engine.gd")
const ResourceMarket = preload("res://script/instance/rules/resource_market.gd")
const MapGraph = preload("res://script/instance/rules/map_graph.gd")
const AutomaController = preload("res://script/instance/rules/automa_controller.gd")
const NetworkProtocol = preload("res://script/instance/network/protocol.gd")

static func init_container():
	return Control.new()

func _ready():
	VW.Database.ensure_loaded()
	var results = []

	var two_player = GameEngine.create_match({
		map_id = "germany",
		deck_id = "base_game",
		preserve_initial_order = true,
		seats = [
			{ player_name = "P1", color = "red", control_mode = "local" },
			{ player_name = "P2", color = "blue", control_mode = "local" }
		]
	})
	results.append("2P regions=3: " + str(two_player.active_regions.size() == 3))

	var four_player = GameEngine.create_match({
		map_id = "germany",
		deck_id = "base_game",
		preserve_initial_order = true,
		seats = [
			{ player_name = "P1", color = "red", control_mode = "local" },
			{ player_name = "P2", color = "blue", control_mode = "local" },
			{ player_name = "P3", color = "green", control_mode = "local" },
			{ player_name = "P4", color = "yellow", control_mode = "local" }
		]
	})
	results.append("4P regions=4, coal=24: " + str(four_player.active_regions.size() == 4 and ResourceMarket.total_stock(four_player.resource_market, "coal") == 24))

	four_player.players[0].built_cities = ["flensburg"]
	four_player.players[1].built_cities = ["kiel"]
	four_player.players[0].plants = [4]
	four_player.players[1].plants = [9]
	var order = GameEngine.determine_player_order(four_player)
	results.append("Phase 1 tiebreaker (P2 > P1): " + str(order[0] == 1 and order[1] == 0))

	var auction_match = GameEngine.create_match({
		map_id = "sample_map",
		deck_id = "base_game",
		preserve_initial_order = true,
		seats = [
			{ player_name = "A", color = "red", control_mode = "local" },
			{ player_name = "B", color = "blue", control_mode = "local" }
		]
	})
	var nom_res = GameEngine.apply_action(auction_match, 0, NetworkProtocol.ACTION_SELECT_PLANT_FOR_AUCTION, { plant_number = 4 })
	var bid_res = GameEngine.apply_action(auction_match, 1, NetworkProtocol.ACTION_PLACE_BID, { amount = 5 })
	var pass_res = GameEngine.apply_action(auction_match, 0, NetworkProtocol.ACTION_PASS_AUCTION, {})
	results.append("Phase 2 auction & pass: " + str(nom_res.accepted and bid_res.accepted and pass_res.accepted and auction_match.players[1].plants.has(4)))

	var can_store = ResourceMarket.can_store_resource(auction_match.players[1], "base_game", "coal", 4)
	var over_store = ResourceMarket.can_store_resource(auction_match.players[1], "base_game", "coal", 5)
	results.append("Phase 3 storage cap (4 ok, 5 blocked): " + str(can_store and not over_store))

	var sample_map = VW.Database.get_map("sample_map")
	var first_city_cost = MapGraph.city_build_cost(sample_map, auction_match, 0, "alpha")
	auction_match.players[0].built_cities = ["alpha"]
	var second_city_cost = MapGraph.city_build_cost(sample_map, auction_match, 0, "bravo")
	results.append("Phase 4 Dijkstra (alpha=10, bravo=18): " + str(first_city_cost == 10 and second_city_cost == 18))

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
	while automa_steps < 16 and AutomaController.take_turn_if_automa(automa_match):
		automa_steps += 1
	results.append("Automa Frida & Robots simulation (" + str(automa_steps) + " steps): " + str(automa_steps > 0))

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(760, 420))
	center.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var title_label = Label.new()
	title_label.text = "Wattage Web Core Rules Engine Verification"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	layout.add_child(title_label)

	var output_label = Label.new()
	output_label.text = "\n".join(results)
	output_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(output_label)

	var menu_button = VW.Chrome.styled_button("Open Main Menu")
	menu_button.pressed.connect(func(): VW.Scenes.goto(VW.Scenes.MAIN_MENU))
	layout.add_child(menu_button)
