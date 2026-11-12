extends Node
## Wave 0 stub with the final signatures. The agent owner writes the full game in Wave 2.
## The input actions are final: labs and the harness need them now.

const ACTIONS := {
	&"swipe_up": [KEY_UP, KEY_W],
	&"swipe_down": [KEY_DOWN, KEY_S],
	&"swipe_left": [KEY_LEFT, KEY_A],
	&"swipe_right": [KEY_RIGHT, KEY_D],
	&"restart": [KEY_R],
	&"pause": [KEY_ESCAPE, KEY_P],
	&"toggle_perf": [KEY_F3],
}

var screen: StringName = &""
var level_index := -1


func _ready() -> void:
	_register_actions()


func open_home() -> void:
	pass


func open_levels() -> void:
	pass


func start_level(_index: int) -> void:
	pass


func restart() -> void:
	pass


func next_level() -> void:
	pass


func set_paused(_on: bool) -> void:
	pass


func request_swipe(_dir: int) -> void:
	pass


func skip_ceremony() -> void:
	pass


func snapshot() -> Dictionary:
	return {"screen": screen}


func _register_actions() -> void:
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode: int in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode as Key
			InputMap.action_add_event(action, event)
