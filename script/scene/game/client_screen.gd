extends Control

const ClientDashboardView = preload("res://script/instance/ui/client_dashboard_view.gd")
const ClientMapView = preload("res://script/instance/ui/client_map_view.gd")

static func init_container():
	return Control.new()

var _connection_panel = null
var _host_ip_input = null
var _discovered_list = null
var _feedback_label = null
var _views_root = null
var _dashboard_view = null
var _map_view = null
var _dashboard_tab_button = null
var _map_tab_button = null

func _ready():
	VW.Database.ensure_loaded()
	if DisplayServer.get_name() != "headless":
		DisplayServer.screen_set_keep_on(true)
	_build_gui()
	VW.Network.client_connected.connect(_on_connected)
	VW.Network.client_disconnected.connect(_on_disconnected)
	VW.Network.state_received.connect(_on_state_received)
	VW.Network.action_result_received.connect(_on_action_result)
	VW.Network.lan_host_discovered.connect(_on_host_discovered)

func _exit_tree():
	if DisplayServer.get_name() != "headless":
		DisplayServer.screen_set_keep_on(false)

func _build_gui():
	var root_box = VBoxContainer.new()
	root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 8)
	add_child(root_box)

	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	root_box.add_child(top_bar)

	_dashboard_tab_button = VW.Chrome.styled_button("Dashboard & Actions", 15)
	_dashboard_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dashboard_tab_button.pressed.connect(func(): _switch_view(0))
	top_bar.add_child(_dashboard_tab_button)

	_map_tab_button = VW.Chrome.styled_button("Map Inspection", 15)
	_map_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_tab_button.pressed.connect(func(): _switch_view(1))
	top_bar.add_child(_map_tab_button)

	var exit_button = VW.Chrome.styled_button("Menu", 14)
	exit_button.custom_minimum_size = Vector2(90, 42)
	exit_button.pressed.connect(func():
		VW.Network.stop_network()
		VW.Scenes.goto(VW.Scenes.MAIN_MENU)
	)
	top_bar.add_child(exit_button)

	_feedback_label = Label.new()
	_feedback_label.text = "Not connected to a host."
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(_feedback_label)

	_connection_panel = VW.Chrome.panel_container(Vector2(0, 180))
	root_box.add_child(_connection_panel)

	var connect_box = VBoxContainer.new()
	connect_box.add_theme_constant_override("separation", 10)
	_connection_panel.add_child(connect_box)

	var connect_row = HBoxContainer.new()
	connect_row.add_theme_constant_override("separation", 8)
	connect_box.add_child(connect_row)

	_host_ip_input = LineEdit.new()
	_host_ip_input.placeholder_text = "Host IP (e.g. 192.168.1.10 or 127.0.0.1)"
	_host_ip_input.text = "127.0.0.1"
	_host_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connect_row.add_child(_host_ip_input)

	var connect_button = VW.Chrome.styled_button("Connect", 15)
	connect_button.custom_minimum_size = Vector2(110, 40)
	connect_button.pressed.connect(func():
		VW.Network.start_client(_host_ip_input.text, VW.Network.DEFAULT_PORT, "", "Android Client")
		_feedback_label.text = "Connecting to " + _host_ip_input.text + "..."
	)
	connect_row.add_child(connect_button)

	var scan_button = VW.Chrome.styled_button("Scan LAN", 15)
	scan_button.custom_minimum_size = Vector2(110, 40)
	scan_button.pressed.connect(func():
		VW.Network.begin_lan_discovery()
		_feedback_label.text = "Scanning LAN for hosts..."
	)
	connect_row.add_child(scan_button)

	_discovered_list = HFlowContainer.new()
	_discovered_list.add_theme_constant_override("h_separation", 8)
	connect_box.add_child(_discovered_list)

	_views_root = Control.new()
	_views_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(_views_root)

	_dashboard_view = ClientDashboardView.new()
	_dashboard_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dashboard_view.action_requested.connect(_on_action_requested)
	_views_root.add_child(_dashboard_view)

	_map_view = ClientMapView.new()
	_map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_view.visible = false
	_map_view.city_build_requested.connect(func(city_id): _on_action_requested("build_city", { city_id = city_id }))
	_views_root.add_child(_map_view)

	_switch_view(0)

func _switch_view(view_index):
	_dashboard_view.visible = (view_index == 0)
	_map_view.visible = (view_index == 1)
	_dashboard_tab_button.modulate = Color(1.0, 1.0, 1.0) if view_index == 0 else Color(0.7, 0.7, 0.7)
	_map_tab_button.modulate = Color(1.0, 1.0, 1.0) if view_index == 1 else Color(0.7, 0.7, 0.7)

func apply_state(public_state, private_state):
	_dashboard_view.update_state(public_state, private_state)
	_map_view.update_state(public_state)

func _on_connected():
	_connection_panel.visible = false
	_feedback_label.text = "Connected to host. Waiting for seat assignment..."

func _on_disconnected():
	_connection_panel.visible = true
	_feedback_label.text = "Disconnected from host."

func _on_state_received(public_state, private_state):
	_connection_panel.visible = false
	apply_state(public_state, private_state)

func _on_action_result(result):
	if bool(result.get("accepted", false)):
		_feedback_label.text = "Action accepted."
	else:
		_feedback_label.text = "Rejected (" + str(result.get("error_code", "")) + "): " + str(result.get("message", ""))

func _on_host_discovered(host_info):
	var address = str(host_info.get("address", ""))
	var title = str(host_info.get("host_title", "Volt Web Host"))
	var join_button = VW.Chrome.styled_button("Join " + title + " (" + address + ")", 14)
	join_button.pressed.connect(func():
		_host_ip_input.text = address
		VW.Network.start_client(address, int(host_info.get("port", VW.Network.DEFAULT_PORT)), "", "Android Client")
	)
	_discovered_list.add_child(join_button)

func _on_action_requested(action_name, parameters):
	VW.Network.send_action_request(action_name, parameters)
	_feedback_label.text = "Sent action: " + str(action_name)
