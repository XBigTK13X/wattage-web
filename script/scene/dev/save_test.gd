extends Control

const GameEngine = preload("res://script/instance/rules/game_engine.gd")
const NetworkProtocol = preload("res://script/instance/network/protocol.gd")

static func init_container():
	return Control.new()

func _ready():
	VW.Database.ensure_loaded()
	var results = []

	var game_a = VW.GameLibrary.create_new_game({
		map_id = "germany",
		deck_id = "base_game",
		title = "Save Test Match A",
		preserve_initial_order = true,
		seats = [
			{ player_name = "Alice", color = "red", control_mode = "local" },
			{ player_name = "Bob", color = "blue", control_mode = "local" }
		]
	})
	var game_a_id = game_a.game_id
	GameEngine.apply_action(game_a, 0, NetworkProtocol.ACTION_SELECT_PLANT_FOR_AUCTION, { plant_number = 4 })
	GameEngine.apply_action(game_a, 1, NetworkProtocol.ACTION_PASS_AUCTION, {})
	VW.GameLibrary.save_active_game()
	VW.GameLibrary.suspend_active_game()
	results.append("Suspended Game A (" + game_a_id + ")")

	var game_b = VW.GameLibrary.create_new_game({
		map_id = "united_states",
		deck_id = "base_game",
		title = "Save Test Match B",
		seats = [
			{ player_name = "Cara", color = "green", control_mode = "local" },
			{ player_name = "Dan", color = "yellow", control_mode = "local" }
		]
	})
	var game_b_id = game_b.game_id
	VW.GameLibrary.suspend_active_game()

	var resumed_a = VW.GameLibrary.resume_game(game_a_id)
	var match_ok = resumed_a != null and resumed_a.players[0].plants.has(4) and resumed_a.players[0].elektro == 46
	results.append("Resumed Game A with identical state: " + str(match_ok))

	VW.GameLibrary.delete_saved_game(game_a_id)
	VW.GameLibrary.delete_saved_game(game_b_id)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(680, 320))
	center.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var title_label = Label.new()
	title_label.text = "Wattage Web Persistence & Resume Verification"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title_label)

	var output_label = Label.new()
	output_label.text = "\n".join(results)
	output_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(output_label)

	var menu_button = VW.Chrome.styled_button("Open Main Menu")
	menu_button.pressed.connect(func(): VW.Scenes.goto(VW.Scenes.MAIN_MENU))
	layout.add_child(menu_button)
