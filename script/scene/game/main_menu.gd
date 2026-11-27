extends Control

static func init_container():
	return Control.new()

var _games_list = null

func _ready():
	VW.Database.ensure_loaded()
	_build_gui()

func _build_gui():
	var root_center = CenterContainer.new()
	root_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_center)

	var main_panel = VW.Chrome.panel_container(Vector2(940, 620))
	root_center.add_child(main_panel)

	var outer_box = VBoxContainer.new()
	outer_box.add_theme_constant_override("separation", 18)
	main_panel.add_child(outer_box)

	var title_label = Label.new()
	title_label.text = "WATTAGE WEB"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.77, 0.26))
	outer_box.add_child(title_label)

	var subtitle_label = Label.new()
	subtitle_label.text = "Host Control & Stored Matches"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_box.add_child(subtitle_label)

	var content_row = HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 20)
	outer_box.add_child(content_row)

	var menu_column = VBoxContainer.new()
	menu_column.custom_minimum_size = Vector2(240, 0)
	menu_column.add_theme_constant_override("separation", 12)
	content_row.add_child(menu_column)

	var new_match_button = VW.Chrome.styled_button("New Match")
	new_match_button.pressed.connect(func(): VW.Scenes.goto(VW.Scenes.MATCH_SETUP))
	menu_column.add_child(new_match_button)

	var client_button = VW.Chrome.styled_button("Join as Client")
	client_button.pressed.connect(func(): VW.Scenes.goto(VW.Scenes.CLIENT_SCREEN))
	menu_column.add_child(client_button)

	var settings_button = VW.Chrome.styled_button("Settings")
	settings_button.pressed.connect(func(): VW.Scenes.goto(VW.Scenes.SETTINGS_MENU))
	menu_column.add_child(settings_button)

	var quit_button = VW.Chrome.styled_button("Quit")
	quit_button.pressed.connect(func(): VW.Scenes.quit())
	menu_column.add_child(quit_button)

	var library_panel = VW.Chrome.panel_container(Vector2(620, 420), Color(0.08, 0.10, 0.14, 0.95), Color(0.45, 0.52, 0.64, 0.9))
	library_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(library_panel)

	var library_box = VBoxContainer.new()
	library_box.add_theme_constant_override("separation", 10)
	library_panel.add_child(library_box)

	var library_header = Label.new()
	library_header.text = "Stored Games (Resume or Manage)"
	library_header.add_theme_font_size_override("font_size", 18)
	library_box.add_child(library_header)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_box.add_child(scroll)

	_games_list = VBoxContainer.new()
	_games_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_games_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_games_list)

	_refresh_games_list()

func _refresh_games_list():
	for child in _games_list.get_children():
		child.queue_free()
	var saved_games = VW.GameLibrary.list_saved_games()
	if saved_games.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No stored games yet. Click 'New Match' to start."
		_games_list.add_child(empty_label)
		return
	for game_entry in saved_games:
		var row_panel = VW.Chrome.panel_container(Vector2(0, 64), Color(0.14, 0.17, 0.23, 0.95), Color(0.35, 0.42, 0.54, 0.9))
		_games_list.add_child(row_panel)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row_panel.add_child(row)

		var info_label = Label.new()
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var seat_total = game_entry.get("players", []).size()
		info_label.text = str(game_entry.get("title", "Match")) + " | " + str(seat_total) + " seats | Step " + str(game_entry.get("step", 1)) + " Phase " + str(game_entry.get("phase", 1))
		row.add_child(info_label)

		var game_id = str(game_entry.get("game_id", ""))
		var resume_button = VW.Chrome.styled_button("Resume", 15)
		resume_button.custom_minimum_size = Vector2(110, 36)
		resume_button.pressed.connect(_on_resume_pressed.bind(game_id))
		row.add_child(resume_button)

		var delete_button = VW.Chrome.styled_button("Delete", 15)
		delete_button.custom_minimum_size = Vector2(96, 36)
		delete_button.pressed.connect(_on_delete_pressed.bind(game_id))
		row.add_child(delete_button)

func _on_resume_pressed(game_id):
	if VW.GameLibrary.resume_game(game_id) != null:
		VW.Scenes.goto(VW.Scenes.HOST_BOARD)

func _on_delete_pressed(game_id):
	VW.GameLibrary.delete_saved_game(game_id)
	_refresh_games_list()
