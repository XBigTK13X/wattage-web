extends Control

func _ready():
	call_deferred("_init_global_state")

func _init_global_state():
	VW.reset()
	if VW.Settings != null and VW.Settings.has_method("load"):
		VW.Settings.load()
	randomize()
	VW.Scenes.goto(VW.Scenes.FIRST_SCENE)
