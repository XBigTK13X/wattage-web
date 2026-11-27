extends Control

static func init_container():
	return Control.new()

func _ready():
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(560, 420))
	center.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)

	var title_label = Label.new()
	title_label.text = "Settings"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	layout.add_child(title_label)

	var audio_toggle = CheckButton.new()
	audio_toggle.text = "Audio Enabled"
	audio_toggle.button_pressed = VW.Settings.audio_enabled()
	audio_toggle.toggled.connect(func(enabled):
		VW.Settings.change("game", "audio_enabled", enabled)
		VW.Audio.apply_volume_settings()
	)
	layout.add_child(audio_toggle)

	var fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.text = "Fullscreen"
	fullscreen_toggle.button_pressed = VW.Settings.fullscreen()
	fullscreen_toggle.toggled.connect(func(enabled):
		VW.Settings.change("display", "fullscreen", enabled)
		VW.Settings.apply_display_settings()
	)
	layout.add_child(fullscreen_toggle)

	var volume_label = Label.new()
	volume_label.text = "Master Volume: " + str(VW.Settings.master_volume_percent()) + "%"
	layout.add_child(volume_label)

	var volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 5
	volume_slider.value = VW.Settings.master_volume_percent()
	volume_slider.value_changed.connect(func(value):
		VW.Settings.change("game", "audio_volume_master_percent", int(value))
		VW.Audio.apply_volume_settings()
		volume_label.text = "Master Volume: " + str(int(value)) + "%"
	)
	layout.add_child(volume_slider)

	var back_button = VW.Chrome.styled_button("Back to Main Menu")
	back_button.pressed.connect(func(): VW.Scenes.goto(VW.Scenes.MAIN_MENU))
	layout.add_child(back_button)
