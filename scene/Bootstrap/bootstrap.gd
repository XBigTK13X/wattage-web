extends Control

func _ready():
	call_deferred("_init_global_state")

func _init_global_state():
	VW.reset()
	if VW.Settings != null and VW.Settings.has_method("load"):
		VW.Settings.load()
	if VW.Audio != null and VW.Audio.has_method("setup"):
		VW.Audio.setup(VW.Audio)
	randomize()
	VW.Scenes.goto(VW.Scenes.FIRST_SCENE)
