extends Node

const PLAYER_COLORS = {
	"red": Color(0.84, 0.22, 0.20, 1.0),
	"blue": Color(0.20, 0.48, 0.86, 1.0),
	"green": Color(0.22, 0.68, 0.34, 1.0),
	"yellow": Color(0.92, 0.76, 0.18, 1.0),
	"purple": Color(0.62, 0.32, 0.78, 1.0),
	"black": Color(0.16, 0.17, 0.20, 1.0)
}

const RESOURCE_COLORS = {
	"coal": Color(0.42, 0.26, 0.16, 1.0),
	"oil": Color(0.14, 0.16, 0.20, 1.0),
	"garbage": Color(0.76, 0.68, 0.20, 1.0),
	"uranium": Color(0.84, 0.20, 0.24, 1.0),
	"ecological": Color(0.24, 0.72, 0.45, 1.0),
	"step3": Color(0.70, 0.74, 0.80, 1.0)
}

var _house_textures = {}
var _resource_textures = {}
var _theme = null

func get_player_color(color_key):
	return PLAYER_COLORS.get(str(color_key), Color.WHITE)

func get_resource_color(resource_type):
	return RESOURCE_COLORS.get(str(resource_type), Color(0.5, 0.5, 0.5, 1.0))

func get_house_texture(color_key):
	var key = str(color_key)
	if _house_textures.has(key):
		return _house_textures[key]
	var asset_path = "res://asset/token/house_" + key + ".png"
	if ResourceLoader.exists(asset_path):
		var loaded = load(asset_path)
		if loaded != null:
			_house_textures[key] = loaded
			return loaded
	var fill_color = get_player_color(key)
	var border_color = fill_color.darkened(0.45)
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for row in range(4, 28):
		for column in range(4, 28):
			var inside_roof = row < 14 and abs(column - 15.5) <= (row - 3) * 1.15
			var inside_body = row >= 14 and column >= 7 and column <= 24
			if inside_roof or inside_body:
				var is_edge = (row == 27 or column == 7 or column == 24 or (row < 14 and abs(column - 15.5) >= (row - 3) * 1.15 - 1.6))
				image.set_pixel(column, row, border_color if is_edge else fill_color)
	var texture = ImageTexture.create_from_image(image)
	_house_textures[key] = texture
	return texture

func get_resource_texture(resource_type):
	var key = str(resource_type)
	if _resource_textures.has(key):
		return _resource_textures[key]
	var asset_path = "res://asset/icon/resource_" + key + ".png"
	if ResourceLoader.exists(asset_path):
		var loaded = load(asset_path)
		if loaded != null:
			_resource_textures[key] = loaded
			return loaded
	var fill_color = get_resource_color(key)
	var accent_color = fill_color.lightened(0.35)
	var image = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for row in range(2, 26):
		for column in range(2, 26):
			var distance_sq = (column - 13.5) * (column - 13.5) + (row - 13.5) * (row - 13.5)
			if distance_sq <= 110.0:
				var is_ring = distance_sq >= 78.0
				image.set_pixel(column, row, accent_color if is_ring else fill_color)
	var texture = ImageTexture.create_from_image(image)
	_resource_textures[key] = texture
	return texture

func get_theme():
	if _theme != null:
		return _theme
	var theme = Theme.new()
	theme.default_font_size = 16
	_theme = theme
	return _theme

func build_plant_card(plant_definition):
	var panel = VW.Chrome.panel_container(Vector2(170, 210), Color(0.13, 0.16, 0.22, 0.96), get_resource_color(plant_definition.fuel_type))
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)

	var header = Label.new()
	header.text = "STEP 3" if plant_definition.is_step_three else ("#" + str(plant_definition.number))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	layout.add_child(header)

	var fuel_row = HBoxContainer.new()
	fuel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fuel_row.add_theme_constant_override("separation", 6)
	layout.add_child(fuel_row)

	for fuel_name in plant_definition.accepted_fuels:
		var icon = TextureRect.new()
		icon.texture = get_resource_texture(fuel_name)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		fuel_row.add_child(icon)

	var fuel_label = Label.new()
	if plant_definition.is_step_three:
		fuel_label.text = "Trigger Step 3"
	elif plant_definition.is_ecological:
		fuel_label.text = "Ecological (0 fuel)"
	else:
		fuel_label.text = str(plant_definition.fuel_cost) + "x " + plant_definition.fuel_type
	fuel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(fuel_label)

	var power_label = Label.new()
	power_label.text = "Powers " + str(plant_definition.cities_powered) + " cities"
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(power_label)

	return panel

func build_city_marker(city_name, slot_costs = [10, 15, 20]):
	var panel = VW.Chrome.panel_container(Vector2(130, 74), Color(0.16, 0.19, 0.25, 0.96), Color(0.65, 0.72, 0.82, 0.95))
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	panel.add_child(layout)

	var name_label = Label.new()
	name_label.text = city_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(name_label)

	var slots_label = Label.new()
	var slot_texts = []
	for slot_cost in slot_costs:
		slot_texts.append(str(slot_cost))
	slots_label.text = " | ".join(slot_texts)
	slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(slots_label)
	return panel
