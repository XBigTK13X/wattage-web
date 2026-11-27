extends ColorRect

const GameEngine = preload("res://script/instance/rules/game_engine.gd")

static func open_modal(parent_node, game_state):
	var modal = new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.color = Color(0.02, 0.03, 0.05, 0.80)
	parent_node.add_child(modal)
	modal._build(game_state)
	return modal

func _build(game_state):
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(760, 540))
	center.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var title_label = Label.new()
	title_label.text = "Rules Reference & Turn Log"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	layout.add_child(title_label)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	var map_id = str(game_state.get("map_id", "germany"))
	var map_def = VW.Database.get_map(map_id)
	var seat_count = game_state.get("players", []).size()
	var step = int(game_state.get("step", 1))
	var info = GameEngine._player_count_info(map_def, seat_count)
	var refill = info.get("refill", [[3, 2, 1, 1], [4, 2, 2, 1], [3, 4, 3, 1]])
	var step_rates = refill[clamp(step - 1, 0, refill.size() - 1)]

	var rules_label = Label.new()
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.text = (
		"Map: " + (map_def.display_name if map_def != null else map_id) +
		" | Seats: " + str(seat_count) +
		" | Active Regions: " + str(info.get("regions", 3)) +
		"\nStep 2 Threshold: " + str(info.get("step_two_cities", 7)) + " cities" +
		" | End-Game Threshold: " + str(info.get("end_game_cities", 17)) + " cities" +
		"\nCurrent Step " + str(step) + " Refill (Coal / Oil / Garbage / Uranium): " +
		str(step_rates[0]) + " / " + str(step_rates[1]) + " / " + str(step_rates[2]) + " / " + str(step_rates[3]) +
		"\nBureaucracy Payouts (0..20 cities): 10, 22, 33, 44, 54, 64, 73, 82, 90, 98, 105, 112, 118, 124, 129, 134, 138, 142, 145, 148, 150"
	)
	content.add_child(rules_label)

	var log_header = Label.new()
	log_header.text = "Recent Turn & Action Log"
	log_header.add_theme_font_size_override("font_size", 17)
	content.add_child(log_header)

	var history_lines = game_state.get("history", [])
	if history_lines.is_empty():
		history_lines = VW.EventLog.get_history()
	var log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.text = "\n".join(history_lines.slice(-20)) if not history_lines.is_empty() else "No actions recorded yet."
	content.add_child(log_label)

	var close_button = VW.Chrome.styled_button("Close", 15)
	close_button.pressed.connect(func(): queue_free())
	layout.add_child(close_button)
