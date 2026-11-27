extends Node

var AUDIO_TEST = "dev/audio_test"
var BOOTSTRAP = "Bootstrap"
var CLIENT_PREVIEW = "dev/client_preview"
var CLIENT_SCREEN = "game/client_screen"
var DATABASE_TEST = "dev/database_test"
var FRAMEWORK_TEST = "dev/framework_test"
var HOST_BOARD = "game/host_board"
var INPUT_TEST = "dev/input_test"
var MAIN_MENU = "game/main_menu"
var MATCH_SETUP = "game/match_setup"
var NETWORK_TEST = "dev/network_test"
var RULES_TEST = "dev/rules_test"
var SAVE_TEST = "dev/save_test"
var SETTINGS_MENU = "game/settings_menu"
var UI_TEST = "dev/ui_test"

var FIRST_SCENE = SAVE_TEST

func quit():
	get_tree().quit()

func goto(scene_name):
	if scene_name == BOOTSTRAP:
		return call_deferred("bootstrap_again")
	var scene_path = "res://script/scene/" + scene_name + ".gd"
	call_deferred("_load_scene", scene_path)

func container():
	return get_node("/root/Container")

func bootstrap_again():
	var root = get_node("/root")
	var last_scene = root.get_node_or_null("Container")
	if last_scene != null:
		root.remove_child(last_scene)
		last_scene.call_deferred("free")
	return get_tree().change_scene_to_file("res://scene/Bootstrap/Bootstrap.tscn")

func _load_scene(scene_path):
	if VW.ActionQueue != null:
		VW.ActionQueue.clear()
	if VW.Loading != null:
		VW.Loading.show_progress("Loading scene...", 5.0)
	var root = get_node("/root")
	var last_scene = root.get_node_or_null("Container")
	if last_scene != null:
		root.remove_child(last_scene)
		last_scene.call_deferred("free")

	var scene_script = load(scene_path)
	var current_container = scene_script.init_container()
	current_container.name = "Container"
	if current_container is Control:
		current_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	current_container.set_script(scene_script)
	root.add_child(current_container)
	if VW.Loading != null:
		VW.Loading.call_deferred("hide_loading")
