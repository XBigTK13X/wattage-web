extends RefCounted

const OPPOSITE_DIRECTIONS = {
	"n": "s",
	"s": "n",
	"e": "w",
	"w": "e",
	"ne": "sw",
	"sw": "ne",
	"nw": "se",
	"se": "nw"
}

var id = ""
var display_name = ""
var is_dev = false
var start_resources = []
var player_count_info = {}
var regions = {}
var region_connections = []
var cities = {}
var connections = []
var adjacency = {}
var automa_start_cities = {}
var rule_overrides = {}

static func from_dictionary(payload):
	var definition = new()
	definition.id = str(payload.get("id", ""))
	definition.display_name = str(payload.get("display_name", definition.id))
	definition.is_dev = bool(payload.get("is_dev", false))
	definition.start_resources = payload.get("start_resources", [1, 3, 7, 14]).duplicate()
	definition.player_count_info = payload.get("player_count_info", {}).duplicate(true)
	definition.regions = payload.get("regions", {}).duplicate(true)
	definition.region_connections = payload.get("region_connections", []).duplicate(true)
	definition.automa_start_cities = payload.get("automa_start_cities", {}).duplicate(true)
	definition.rule_overrides = payload.get("rule_overrides", {}).duplicate(true)

	for city_entry in payload.get("cities", []):
		var city_id = str(city_entry.get("id", ""))
		if city_id == "":
			continue
		var raw_position = city_entry.get("position", [0.0, 0.0])
		var city_position = Vector2(float(raw_position[0]), float(raw_position[1]))
		definition.cities[city_id] = {
			id = city_id,
			name = str(city_entry.get("name", city_id)),
			region_id = str(city_entry.get("region_id", "")),
			position = city_position,
			max_connections = int(city_entry.get("max_connections", 0))
		}
		definition.adjacency[city_id] = []

	for edge in payload.get("connections", []):
		var source_city = str(edge.get("from", ""))
		var target_city = str(edge.get("to", ""))
		var direction = str(edge.get("direction", ""))
		var cost = int(edge.get("cost", 0))
		if not definition.cities.has(source_city) or not definition.cities.has(target_city):
			continue
		definition.connections.append({
			from = source_city,
			to = target_city,
			direction = direction,
			cost = cost
		})
		definition._add_neighbor(source_city, target_city, direction, cost)
		var reverse_direction = OPPOSITE_DIRECTIONS.get(direction, "")
		definition._add_neighbor(target_city, source_city, reverse_direction, cost)

	return definition

func _add_neighbor(source_city, target_city, direction, cost):
	for existing in adjacency[source_city]:
		if existing.target == target_city:
			return
	adjacency[source_city].append({
		target = target_city,
		direction = direction,
		cost = cost
	})

func is_adjacency_symmetric():
	for source_city in adjacency.keys():
		for edge in adjacency[source_city]:
			var found_reverse = false
			for reverse_edge in adjacency.get(edge.target, []):
				if reverse_edge.target == source_city and reverse_edge.cost == edge.cost:
					found_reverse = true
					break
			if not found_reverse:
				return false
	return true
