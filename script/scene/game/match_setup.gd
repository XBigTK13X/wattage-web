extends Control

const SeatRegistry = preload("res://script/instance/network/seat_registry.gd")

static func init_container():
	return Control.new()

var _map_option = null
var _deck_option = null
var _seats_option = null
var _humans_option = null
var _automa_option = null
var _seats_container = null
var _seat_rows = []

func _ready():
	VW.Database.ensure_loaded()
	_build_gui()

func _build_gui():
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(920, 680))
	center.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var title_label = Label.new()
	title_label.text = "New Match Configuration"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	layout.add_child(title_label)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	layout.add_child(grid)

	grid.add_child(_make_label("Map:"))
	_map_option = OptionButton.new()
	for map_id in VW.Database.list_maps():
		_map_option.add_item(map_id)
	grid.add_child(_map_option)

	grid.add_child(_make_label("Plant Deck:"))
	_deck_option = OptionButton.new()
	for deck_id in VW.Database.list_decks():
		_deck_option.add_item(deck_id)
	grid.add_child(_deck_option)

	grid.add_child(_make_label("Total Table Seats (2-6):"))
	_seats_option = OptionButton.new()
	for seat_count in [2, 3, 4, 5, 6]:
		_seats_option.add_item(str(seat_count) + " Seats", seat_count)
	_seats_option.select(2)
	_seats_option.item_selected.connect(func(_idx): _sync_human_options())
	grid.add_child(_seats_option)

	grid.add_child(_make_label("Human Players:"))
	_humans_option = OptionButton.new()
	_humans_option.item_selected.connect(func(_idx): _rebuild_seat_rows())
	grid.add_child(_humans_option)

	grid.add_child(_make_label("Automa for Empty Seats:"))
	_automa_option = OptionButton.new()
	_automa_option.add_item("Frida (Print & Play)", 0)
	_automa_option.add_item("Robots (Official Expansion)", 1)
	_automa_option.item_selected.connect(func(_idx): _rebuild_seat_rows())
	grid.add_child(_automa_option)

	var seats_scroll = ScrollContainer.new()
	seats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(seats_scroll)

	_seats_container = VBoxContainer.new()
	_seats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seats_container.add_theme_constant_override("separation", 8)
	seats_scroll.add_child(_seats_container)

	var buttons_row = HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 18)
	layout.add_child(buttons_row)

	var back_button = VW.Chrome.styled_button("Cancel")
	back_button.pressed.connect(func(): VW.Scenes.goto(VW.Scenes.MAIN_MENU))
	buttons_row.add_child(back_button)

	var start_button = VW.Chrome.styled_button("Start Match")
	start_button.pressed.connect(_on_start_match)
	buttons_row.add_child(start_button)

	_sync_human_options()

func _make_label(text_value):
	var label = Label.new()
	label.text = text_value
	return label

func _sync_human_options():
	var total_seats = _seats_option.get_selected_id()
	var previous_humans = _humans_option.get_selected_id() if _humans_option.item_count > 0 else 2
	_humans_option.clear()
	for human_count in range(1, total_seats + 1):
		_humans_option.add_item(str(human_count) + " Human(s)", human_count)
	var target_index = clamp(previous_humans - 1, 0, total_seats - 1)
	_humans_option.select(target_index)
	_rebuild_seat_rows()

func _rebuild_seat_rows():
	for child in _seats_container.get_children():
		child.queue_free()
	_seat_rows.clear()
	var total_seats = _seats_option.get_selected_id()
	var human_count = _humans_option.get_selected_id()
	var automa_mode = SeatRegistry.CONTROL_AUTOMA_FRIDA if _automa_option.get_selected_id() == 0 else SeatRegistry.CONTROL_AUTOMA_ROBOTS
	var automa_label = "Frida" if automa_mode == SeatRegistry.CONTROL_AUTOMA_FRIDA else "Robots"
	var colors = VW.Assets.PLAYER_COLORS.keys()

	for seat_index in range(total_seats):
		var is_human = seat_index < human_count
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_seats_container.add_child(row)

		var name_input = LineEdit.new()
		name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_input.text = ("Player " + str(seat_index + 1)) if is_human else (automa_label + " " + str(seat_index + 1))
		row.add_child(name_input)

		var color_option = OptionButton.new()
		for color_key in colors:
			color_option.add_item(color_key.capitalize())
		color_option.select(seat_index % colors.size())
		row.add_child(color_option)

		var control_option = OptionButton.new()
		if is_human:
			control_option.add_item("Local Host", 0)
			control_option.add_item("Remote Client", 1)
		else:
			control_option.add_item("Automa (" + automa_label + ")", 2)
			control_option.disabled = true
		row.add_child(control_option)

		_seat_rows.append({
			name_input = name_input,
			color_option = color_option,
			control_option = control_option,
			automa_mode = automa_mode,
			is_human = is_human
		})

func _on_start_match():
	var map_id = _map_option.get_item_text(_map_option.selected)
	var deck_id = _deck_option.get_item_text(_deck_option.selected)
	var colors = VW.Assets.PLAYER_COLORS.keys()
	var seat_configs = []
	for row_data in _seat_rows:
		var control_mode = row_data.automa_mode
		if row_data.is_human:
			control_mode = SeatRegistry.CONTROL_LOCAL if row_data.control_option.get_selected_id() == 0 else SeatRegistry.CONTROL_REMOTE
		seat_configs.append({
			player_name = row_data.name_input.text,
			color = colors[row_data.color_option.selected],
			control_mode = control_mode
		})
	VW.Network.seat_registry.configure_seats(seat_configs)
	VW.GameLibrary.create_new_game({
		map_id = map_id,
		deck_id = deck_id,
		seats = seat_configs
	})
	VW.Scenes.goto(VW.Scenes.HOST_BOARD)
