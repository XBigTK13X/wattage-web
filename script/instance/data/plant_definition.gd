extends RefCounted

var number = 0
var fuel_type = ""
var accepted_fuels = []
var fuel_cost = 0
var cities_powered = 0
var is_step_three = false
var is_ecological = false
var is_hybrid = false

static func from_dictionary(payload):
	var definition = new()
	definition.number = int(payload.get("number", 0))
	definition.fuel_type = str(payload.get("fuel_type", ""))
	definition.accepted_fuels = payload.get("accepted_fuels", []).duplicate()
	definition.fuel_cost = int(payload.get("fuel_cost", 0))
	definition.cities_powered = int(payload.get("cities_powered", 0))
	definition.is_step_three = bool(payload.get("is_step_three", false))
	definition.is_ecological = bool(payload.get("is_ecological", false))
	definition.is_hybrid = bool(payload.get("is_hybrid", false))
	return definition
