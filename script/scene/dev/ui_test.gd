extends Control

static func init_container():
	return Control.new()

func _ready():
	VW.Database.ensure_loaded()
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = VW.Chrome.panel_container(Vector2(980, 620))
	center.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	panel.add_child(layout)

	var title_label = Label.new()
	title_label.text = "Volt Web Clean-Room UI & Board Graphics"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	layout.add_child(title_label)

	var houses_row = HBoxContainer.new()
	houses_row.alignment = BoxContainer.ALIGNMENT_CENTER
	houses_row.add_theme_constant_override("separation", 18)
	layout.add_child(houses_row)
	for color_key in VW.Assets.PLAYER_COLORS.keys():
		var item_box = VBoxContainer.new()
		var house_rect = TextureRect.new()
		house_rect.texture = VW.Assets.get_house_texture(color_key)
		house_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		item_box.add_child(house_rect)
		var color_label = Label.new()
		color_label.text = color_key.capitalize()
		color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_box.add_child(color_label)
		houses_row.add_child(item_box)

	var resources_row = HBoxContainer.new()
	resources_row.alignment = BoxContainer.ALIGNMENT_CENTER
	resources_row.add_theme_constant_override("separation", 24)
	layout.add_child(resources_row)
	for resource_key in ["coal", "oil", "garbage", "uranium"]:
		var resource_box = VBoxContainer.new()
		var resource_rect = TextureRect.new()
		resource_rect.texture = VW.Assets.get_resource_texture(resource_key)
		resource_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		resource_box.add_child(resource_rect)
		var resource_label = Label.new()
		resource_label.text = resource_key.capitalize()
		resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		resource_box.add_child(resource_label)
		resources_row.add_child(resource_box)

	var cards_row = HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 16)
	layout.add_child(cards_row)
	for plant_number in [4, 5, 11, 13]:
		var plant = VW.Database.get_plant("base_game", plant_number)
		if plant != null:
			cards_row.add_child(VW.Assets.build_plant_card(plant))

	var city_row = HBoxContainer.new()
	city_row.alignment = BoxContainer.ALIGNMENT_CENTER
	city_row.add_theme_constant_override("separation", 16)
	layout.add_child(city_row)
	city_row.add_child(VW.Assets.build_city_marker("Sample City", [10, 15, 20]))

	var audio_button = VW.Chrome.styled_button("Open Audio Test")
	audio_button.pressed.connect(func(): VW.Scenes.goto(VW.Scenes.AUDIO_TEST))
	layout.add_child(audio_button)
