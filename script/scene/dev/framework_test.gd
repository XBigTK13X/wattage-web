extends Control

static func init_container():
	return Control.new()

func _ready():
	VW.Log.warn("Framework verification scene started")
	VW.EventLog.notify("Framework smoke test initialized")
	var saved_fullscreen = VW.Settings.fullscreen()
	VW.Settings.change("display", "fullscreen", saved_fullscreen)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(520, 260))
	center.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var title_label = Label.new()
	title_label.text = "Volt Web Framework Verification"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title_label)

	var status_label = Label.new()
	status_label.text = "EventLog entries: " + str(VW.EventLog.get_history().size()) + " | Audio enabled: " + str(VW.Settings.audio_enabled())
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(status_label)

	var reboot_button = VW.Chrome.styled_button("Reload Bootstrap")
	reboot_button.pressed.connect(func(): VW.Scenes.goto(VW.Scenes.BOOTSTRAP))
	layout.add_child(reboot_button)
