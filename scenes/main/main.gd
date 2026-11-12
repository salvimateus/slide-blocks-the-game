extends Node
## The main scene. It runs after all autoloads, so the boot reads the settings that the harness applied.


func _ready() -> void:
	Game.boot(self)
