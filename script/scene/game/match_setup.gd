extends Control

const SeatRegistry = preload("res://script/instance/network/seat_registry.gd")

static func init_container():
	return Control.new()

const RADIO_OPTIONS = [
	{ label = "Host", mode = SeatRegistry.CONTROL_LOCAL },
	{ label = "Guest", mode = SeatRegistry.CONTROL_REMOTE },
	{ label = "Frida", mode = SeatRegistry.CONTROL_AUTOMA_FRIDA },
	{ label = "Robot", mode = SeatRegistry.CONTROL_AUTOMA_ROBOTS }
]

var _map_option = null
var _deck_option = null
var _seats_option = null
var _seats_container = null
var _feedback_label = null
var _seat_rows = []
var _row_modes = []
var _updating_radios = false
var _selected_style = null
var _unselected_style = null
var _hover_style = null

func _ready():
	VW.Database.ensure_loaded()
	_init_segment_styles()
	_build_gui()

func _init_segment_styles():
	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color(0.86, 0.66, 0.18, 1.0)
	_selected_style.border_color = Color(1.0, 0.90, 0.48, 1.0)
	_selected_style.set_border_width_all(2)
	_selected_style.set_corner_radius_all(4)
	_selected_style.set_content_margin_all(6)

	_unselected_style = StyleBoxFlat.new()
	_unselected_style.bg_color = Color(0.13, 0.16, 0.22, 0.92)
	_unselected_style.border_color = Color(0.32, 0.38, 0.48, 0.85)
	_unselected_style.set_border_width_all(1)
	_unselected_style.set_corner_radius_all(4)
	_unselected_style.set_content_margin_all(6)

	_hover_style = StyleBoxFlat.new()
	_hover_style.bg_color = Color(0.20, 0.25, 0.34, 0.96)
	_hover_style.border_color = Color(0.55, 0.62, 0.74, 0.95)
	_hover_style.set_border_width_all(1)
	_hover_style.set_corner_radius_all(4)
	_hover_style.set_content_margin_all(6)

func _build_gui():
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(1020, 700))
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
		var map_def = VW.Database.get_map(map_id)
		var map_label = str(map_def.display_name) if map_def != null and str(map_def.display_name) != "" else str(map_id).replace("_", " ").capitalize()
		var item_idx = _map_option.item_count
		_map_option.add_item(map_label)
		_map_option.set_item_metadata(item_idx, map_id)
	VW.Chrome.attach_focus_ring(_map_option)
	grid.add_child(_map_option)

	grid.add_child(_make_label("Plant Deck:"))
	_deck_option = OptionButton.new()
	for deck_id in VW.Database.list_decks():
		var deck_data = VW.Database.get_deck(deck_id)
		var deck_label = str(deck_data.get("display_name", "")) if deck_data != null else ""
		if deck_label == "":
			deck_label = str(deck_id).replace("_", " ").capitalize()
		var item_idx = _deck_option.item_count
		_deck_option.add_item(deck_label)
		_deck_option.set_item_metadata(item_idx, deck_id)
	VW.Chrome.attach_focus_ring(_deck_option)
	grid.add_child(_deck_option)

	var last_seat_count = clamp(int(VW.Settings.get_value("match_setup", "seat_count", 4)), 2, 6)
	grid.add_child(_make_label("Total Table Seats (2-6):"))
	_seats_option = OptionButton.new()
	var selected_seat_idx = 0
	for idx in range(5):
		var seat_count = idx + 2
		_seats_option.add_item(str(seat_count) + " Seats", seat_count)
		if seat_count == last_seat_count:
			selected_seat_idx = idx
	_seats_option.select(selected_seat_idx)
	_seats_option.item_selected.connect(func(_idx): _rebuild_seat_rows())
	VW.Chrome.attach_focus_ring(_seats_option)
	grid.add_child(_seats_option)

	var seats_scroll = ScrollContainer.new()
	seats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	seats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(seats_scroll)

	_seats_container = VBoxContainer.new()
	_seats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seats_container.add_theme_constant_override("separation", 10)
	seats_scroll.add_child(_seats_container)

	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_color_override("font_color", Color(0.98, 0.45, 0.35))
	layout.add_child(_feedback_label)

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

	_rebuild_seat_rows()
	_map_option.call_deferred("grab_focus")

func _make_label(text_value):
	var label = Label.new()
	label.text = text_value
	return label

func _default_slot_name(seat_index):
	return str(VW.Settings.get_value("match_setup", "slot_" + str(seat_index) + "_name", "Player " + str(seat_index + 1)))

func _default_slot_color_index(seat_index, colors):
	var saved_color = str(VW.Settings.get_value("match_setup", "slot_" + str(seat_index) + "_color", ""))
	var found = colors.find(saved_color)
	if found >= 0:
		return found
	return seat_index % colors.size()

func _frida_count():
	var count = 0
	for mode in _row_modes:
		if mode == SeatRegistry.CONTROL_AUTOMA_FRIDA:
			count += 1
	return count

func _apply_segment_visual(btn, is_selected):
	if is_selected:
		btn.add_theme_stylebox_override("normal", _selected_style)
		btn.add_theme_stylebox_override("hover", _selected_style)
		btn.add_theme_stylebox_override("pressed", _selected_style)
		btn.add_theme_stylebox_override("focus", _selected_style)
		btn.add_theme_color_override("font_color", Color(0.08, 0.09, 0.12, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.08, 0.09, 0.12, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.08, 0.09, 0.12, 1.0))
		btn.add_theme_color_override("font_focus_color", Color(0.08, 0.09, 0.12, 1.0))
	else:
		btn.add_theme_stylebox_override("normal", _unselected_style)
		btn.add_theme_stylebox_override("hover", _hover_style)
		btn.add_theme_stylebox_override("pressed", _selected_style)
		btn.add_theme_stylebox_override("focus", _unselected_style)
		btn.add_theme_color_override("font_color", Color(0.70, 0.76, 0.85, 0.9))
		btn.add_theme_color_override("font_hover_color", Color(0.95, 0.97, 1.0, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.08, 0.09, 0.12, 1.0))
		btn.add_theme_color_override("font_focus_color", Color(0.70, 0.76, 0.85, 0.9))

func _sync_radio_states():
	_updating_radios = true
	for seat_index in range(_seat_rows.size()):
		var row_data = _seat_rows[seat_index]
		var mode = _row_modes[seat_index]
		var buttons = row_data.radio_buttons
		for option_idx in range(RADIO_OPTIONS.size()):
			var option_mode = RADIO_OPTIONS[option_idx].mode
			var btn = buttons[option_idx]
			var is_selected = (mode == option_mode)
			btn.button_pressed = is_selected
			_apply_segment_visual(btn, is_selected)
	_updating_radios = false

func _on_mode_radio_pressed(seat_index, chosen_mode):
	if _updating_radios:
		return
	if VW.Audio != null:
		VW.Audio.play_sound_effect("ui_click")
	if chosen_mode == SeatRegistry.CONTROL_AUTOMA_FRIDA and _row_modes[seat_index] != SeatRegistry.CONTROL_AUTOMA_FRIDA:
		if _frida_count() >= 2:
			_feedback_label.text = "At most two Frida players are allowed."
			_sync_radio_states()
			return
	_feedback_label.text = ""
	_row_modes[seat_index] = chosen_mode
	_sync_radio_states()

func _rebuild_seat_rows():
	var total_seats = _seats_option.get_selected_id()
	var previous_modes = _row_modes.duplicate()
	_row_modes.clear()
	for seat_index in range(total_seats):
		if seat_index < previous_modes.size():
			_row_modes.append(previous_modes[seat_index])
		else:
			_row_modes.append(SeatRegistry.CONTROL_LOCAL)

	var frida_seen = 0
	for seat_index in range(total_seats):
		if _row_modes[seat_index] == SeatRegistry.CONTROL_AUTOMA_FRIDA:
			frida_seen += 1
			if frida_seen > 2:
				_row_modes[seat_index] = SeatRegistry.CONTROL_LOCAL

	for child in _seats_container.get_children():
		child.queue_free()
	_seat_rows.clear()
	if _feedback_label != null:
		_feedback_label.text = ""

	var colors = VW.Assets.PLAYER_COLORS.keys()
	for seat_index in range(total_seats):
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_seats_container.add_child(row)

		var name_input = LineEdit.new()
		name_input.custom_minimum_size = Vector2(180, 0)
		name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_input.text = _default_slot_name(seat_index)
		VW.Chrome.attach_focus_ring(name_input)
		row.add_child(name_input)

		var color_option = OptionButton.new()
		color_option.custom_minimum_size = Vector2(115, 0)
		for color_key in colors:
			color_option.add_item(color_key.capitalize())
		color_option.select(_default_slot_color_index(seat_index, colors))
		VW.Chrome.attach_focus_ring(color_option)
		row.add_child(color_option)

		var radio_group = ButtonGroup.new()
		var radio_buttons = []
		var radio_row = HBoxContainer.new()
		radio_row.add_theme_constant_override("separation", 4)
		row.add_child(radio_row)

		for option_info in RADIO_OPTIONS:
			var radio = Button.new()
			radio.toggle_mode = true
			radio.text = option_info.label
			radio.custom_minimum_size = Vector2(88, 36)
			radio.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			radio.button_group = radio_group
			radio.pressed.connect(_on_mode_radio_pressed.bind(seat_index, option_info.mode))
			VW.Chrome.attach_focus_ring(radio)
			radio_row.add_child(radio)
			radio_buttons.append(radio)

		_seat_rows.append({
			name_input = name_input,
			color_option = color_option,
			radio_buttons = radio_buttons
		})

	_sync_radio_states()

func _on_start_match():
	var map_id = str(_map_option.get_item_metadata(_map_option.selected))
	var deck_id = str(_deck_option.get_item_metadata(_deck_option.selected))
	var total_seats = _seats_option.get_selected_id()
	var colors = VW.Assets.PLAYER_COLORS.keys()
	var seat_configs = []
	var frida_seen = 0

	VW.Settings.change("match_setup", "seat_count", total_seats)

	for seat_index in range(_seat_rows.size()):
		var row_data = _seat_rows[seat_index]
		var player_name = row_data.name_input.text.strip_edges()
		if player_name == "":
			player_name = "Player " + str(seat_index + 1)
		var color_key = colors[row_data.color_option.selected]
		var control_mode = _row_modes[seat_index]
		if control_mode == SeatRegistry.CONTROL_AUTOMA_FRIDA:
			frida_seen += 1
			if frida_seen > 2:
				control_mode = SeatRegistry.CONTROL_LOCAL

		VW.Settings.change("match_setup", "slot_" + str(seat_index) + "_name", player_name)
		VW.Settings.change("match_setup", "slot_" + str(seat_index) + "_color", color_key)

		seat_configs.append({
			player_name = player_name,
			color = color_key,
			control_mode = control_mode
		})

	VW.Network.seat_registry.configure_seats(seat_configs)
	VW.GameLibrary.create_new_game({
		map_id = map_id,
		deck_id = deck_id,
		seats = seat_configs
	})
	VW.Scenes.goto(VW.Scenes.HOST_BOARD)
