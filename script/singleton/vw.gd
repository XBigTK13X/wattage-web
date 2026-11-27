extends Node

var ActionQueue
var AssetCache
var Audio
var Chrome
var DataStructure
var EventLog
var Loading
var Log
var Math
var Scenes
var Settings

func _singleton(file_name):
	var script_path = "res://script/singleton/" + file_name + ".gd"
	if not ResourceLoader.exists(script_path):
		return null
	var node = load(script_path).new()
	node.name = file_name
	add_child(node)
	return node

func reset():
	for child in get_children():
		remove_child(child)
		child.queue_free()
	Log = _singleton("log")
	Math = _singleton("math")
	DataStructure = _singleton("data_structure")
	EventLog = _singleton("event_log")
	Settings = _singleton("settings")
	ActionQueue = _singleton("action_queue")
	AssetCache = _singleton("asset_cache")
	Audio = _singleton("audio")
	Chrome = _singleton("chrome")
	Loading = _singleton("loading")
	Scenes = _singleton("scenes")
