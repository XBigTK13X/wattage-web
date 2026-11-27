extends Control

static func init_container():
	return Control.new()

var _event_label = null
var _mode_label = null

const TRACKED_ACTIONS = [
	"ui_up",
	"ui_down",
	"ui_left",
	"ui_right",
	"ui_accept",
	"ui_cancel",
	"pan_up",
	"pan_down",
	"pan_left",
	"pan_right",
	"next_panel",
	"previous_panel",
	"confirm_action",
	"pass_action",
	"quick_bid",
	"zoom_in",
	"zoom_out"
]

func _ready():
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(620, 320))
	center.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var title_label = Label.new()
	title_label.text = "Volt Web Input Verification"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title_label)

	_mode_label = Label.new()
	_mode_label.text = "Gamepad Active: " + str(VW.Chrome.is_gamepad_active())
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_mode_label)

	_event_label = Label.new()
	_event_label.text = "Press keyboard, mouse, or gamepad controls..."
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_event_label)

	var button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	layout.add_child(button_row)

	var back_button = VW.Chrome.styled_button("Framework Test")
	back_button.pressed.connect(func(): VW.Scenes.goto(VW.Scenes.FRAMEWORK_TEST))
	button_row.add_child(back_button)

	VW.Chrome.input_mode_changed.connect(_on_input_mode_changed)

func _on_input_mode_changed(gamepad_active):
	if is_instance_valid(_mode_label):
		_mode_label.text = "Gamepad Active: " + str(gamepad_active)

func _input(event):
	if _event_label == null:
		return
	for action_name in TRACKED_ACTIONS:
		if event.is_action_pressed(action_name):
			_event_label.text = "Triggered action: " + action_name + " (" + event.as_text() + ")"
			return
	if event is InputEventMouseButton and event.pressed:
		_event_label.text = "Mouse click: button " + str(event.button_index) + " at " + str(event.position)
