extends RefCounted

const PLAYER_COLORS = {
	"red": Color(0.8392, 0.2196, 0.2000, 1.0000),
	"blue": Color(0.2000, 0.4784, 0.8588, 1.0000),
	"green": Color(0.2196, 0.6784, 0.3412, 1.0000),
	"yellow": Color(0.9216, 0.7608, 0.1804, 1.0000),
	"purple": Color(0.6196, 0.3216, 0.7804, 1.0000),
	"black": Color(0.1647, 0.1804, 0.2118, 1.0000)
}

const RESOURCE_COLORS = {
	"coal": Color(0.4392, 0.2745, 0.1725, 1.0000),
	"oil": Color(0.1255, 0.1412, 0.1804, 1.0000),
	"garbage": Color(0.7608, 0.6784, 0.2000, 1.0000),
	"uranium": Color(0.8392, 0.2000, 0.2392, 1.0000),
	"ecological": Color(0.2118, 0.6863, 0.4235, 1.0000),
	"hybrid_oil_coal": Color(0.2902, 0.2196, 0.1961, 1.0000),
	"hybrid_oil_garbage": Color(0.4314, 0.4078, 0.1882, 1.0000),
	"step3": Color(0.6980, 0.7373, 0.7961, 1.0000)
}

const UI_COLORS = {
	"bg_deep": Color(0.0588, 0.0784, 0.1098, 1.0000),
	"bg_panel": Color(0.1020, 0.1255, 0.1725, 1.0000),
	"bg_panel_alt": Color(0.1333, 0.1608, 0.2196, 1.0000),
	"bg_button_normal": Color(0.1804, 0.2196, 0.2980, 1.0000),
	"bg_button_hover": Color(0.2431, 0.2902, 0.3882, 1.0000),
	"bg_button_pressed": Color(0.1294, 0.1608, 0.2196, 1.0000),
	"bg_button_disabled": Color(0.1333, 0.1490, 0.1804, 1.0000),
	"border_brass": Color(0.8471, 0.6784, 0.2510, 1.0000),
	"border_brass_bright": Color(0.9608, 0.8078, 0.3608, 1.0000),
	"border_brass_dark": Color(0.5490, 0.4314, 0.1176, 1.0000),
	"border_steel": Color(0.5490, 0.6275, 0.7451, 1.0000),
	"border_muted": Color(0.3765, 0.4000, 0.4471, 1.0000),
	"text_primary": Color(0.9412, 0.9569, 0.9804, 1.0000),
	"text_secondary": Color(0.7216, 0.7686, 0.8471, 1.0000),
	"text_accent": Color(0.9608, 0.7725, 0.2588, 1.0000),
	"text_dark": Color(0.0784, 0.0941, 0.1255, 1.0000),
	"card_bg": Color(0.1176, 0.1451, 0.2039, 1.0000),
	"card_step3_bg": Color(0.2118, 0.1647, 0.0941, 1.0000),
	"map_ocean": Color(0.0510, 0.0745, 0.1059, 1.0000),
	"map_grid": Color(0.0980, 0.1373, 0.1961, 1.0000),
	"map_edge_casing": Color(0.0471, 0.0627, 0.0902, 1.0000),
	"map_edge_line": Color(0.4510, 0.5412, 0.6588, 1.0000)
}

const MAP_RENDER_SIZES = {
	"australia": Vector2i(1200, 820),
	"baden_wurttemberg": Vector2i(1200, 820),
	"benelux": Vector2i(1200, 820),
	"brazil": Vector2i(1200, 820),
	"central_europe": Vector2i(1200, 820),
	"china": Vector2i(1200, 820),
	"europe": Vector2i(1200, 820),
	"france": Vector2i(1200, 820),
	"germany": Vector2i(1700, 2100),
	"india": Vector2i(1200, 820),
	"italy": Vector2i(1200, 820),
	"japan": Vector2i(1200, 820),
	"korea": Vector2i(1200, 820),
	"middle_east": Vector2i(1200, 820),
	"north_america": Vector2i(1200, 820),
	"northern_europe": Vector2i(1200, 820),
	"quebec": Vector2i(1200, 820),
	"russia": Vector2i(1200, 820),
	"sample_map": Vector2i(1200, 820),
	"south_africa": Vector2i(1200, 820),
	"spain_portugal": Vector2i(1200, 820),
	"uk_ireland": Vector2i(1200, 820),
	"united_states": Vector2i(2200, 1450)
}

const DECK_IDS = ["base_game", "new_plants_1", "new_plants_2"]
const HOUSES_PER_PLAYER = 22
const STARTING_ELEKTRO = 50
const CARD_DIMENSIONS = Vector2i(160, 210)
