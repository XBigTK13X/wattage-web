extends Node

const MapDefinition = preload("res://script/instance/data/map_definition.gd")
const PlantDefinition = preload("res://script/instance/data/plant_definition.gd")

const MAPS_DIRECTORY = "res://data/maps/"
const DECKS_DIRECTORY = "res://data/decks/"
const FRIDA_CARDS_PATH = "res://data/automa/frida_cards.json"

var _maps = {}
var _decks = {}
var _frida_cards = []
var _loaded = false

func ensure_loaded():
	if not _loaded:
		load_all()

func load_all():
	_maps.clear()
	_decks.clear()
	_frida_cards.clear()
	_load_maps_directory()
	_load_decks_directory()
	_load_frida_cards()
	_loaded = true

func _load_json_file(file_path):
	if not FileAccess.file_exists(file_path):
		return null
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed

func _list_json_files(directory_path):
	var directory = DirAccess.open(directory_path)
	if directory == null:
		return []
	var results = []
	directory.list_dir_begin()
	var entry = directory.get_next()
	while entry != "":
		if not directory.current_is_dir() and entry.ends_with(".json"):
			results.append(directory_path + entry)
		entry = directory.get_next()
	directory.list_dir_end()
	results.sort()
	return results

func _load_maps_directory():
	for file_path in _list_json_files(MAPS_DIRECTORY):
		var payload = _load_json_file(file_path)
		if payload == null:
			continue
		var map_definition = MapDefinition.from_dictionary(payload)
		if map_definition.id != "":
			_maps[map_definition.id] = map_definition

func _load_decks_directory():
	for file_path in _list_json_files(DECKS_DIRECTORY):
		var payload = _load_json_file(file_path)
		if payload == null:
			continue
		var deck_id = str(payload.get("id", ""))
		if deck_id == "":
			continue
		var cards = []
		var by_number = {}
		for card_payload in payload.get("cards", []):
			var plant = PlantDefinition.from_dictionary(card_payload)
			cards.append(plant)
			by_number[plant.number] = plant
		_decks[deck_id] = {
			id = deck_id,
			cards = cards,
			by_number = by_number
		}

func list_maps(include_dev = false):
	ensure_loaded()
	var keys = []
	for map_id in _maps.keys():
		var map_definition = _maps[map_id]
		if include_dev or not map_definition.is_dev:
			keys.append(map_id)
	keys.sort()
	return keys

func get_map(map_id):
	ensure_loaded()
	return _maps.get(str(map_id), null)

func list_decks():
	ensure_loaded()
	var keys = _decks.keys()
	keys.sort()
	return keys

func get_deck(deck_id):
	ensure_loaded()
	return _decks.get(str(deck_id), null)

func get_plant(deck_id, plant_number):
	var deck = get_deck(deck_id)
	if deck == null:
		return null
	return deck.by_number.get(int(plant_number), null)

func _load_frida_cards():
	var payload = _load_json_file(FRIDA_CARDS_PATH)
	if payload == null:
		return
	for card in payload.get("cards", []):
		_frida_cards.append(card)

func get_frida_cards():
	ensure_loaded()
	return _frida_cards.duplicate(true)
