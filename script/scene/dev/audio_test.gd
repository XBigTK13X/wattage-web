extends Control

static func init_container():
	return Control.new()

var _status_label = null

func _ready():
	VW.Audio.setup(self)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(620, 440))
	center.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var title_label = Label.new()
	title_label.text = "Volt Web Audio Cue Verification"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title_label)

	_status_label = Label.new()
	_status_label.text = "Click a cue to test playback"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_status_label)

	var cue_names = [
		"bid_placed",
		"auction_won",
		"resource_bought",
		"city_built",
		"phase_change",
		"turn_alert"
	]
	for cue_name in cue_names:
		var cue_button = VW.Chrome.styled_button("Play: " + cue_name)
		cue_button.pressed.connect(_on_cue_pressed.bind(cue_name))
		layout.add_child(cue_button)

	var mute_button = VW.Chrome.styled_button("Toggle Audio Mute")
	mute_button.pressed.connect(_on_mute_toggled)
	layout.add_child(mute_button)

func _on_cue_pressed(cue_name):
	var played = VW.Audio.play_sound_effect(cue_name)
	_status_label.text = "Cue '" + cue_name + "' played=" + str(played)

func _on_mute_toggled():
	var next_enabled = not VW.Settings.audio_enabled()
	VW.Settings.change("game", "audio_enabled", next_enabled)
	_status_label.text = "Audio enabled: " + str(next_enabled)
