extends Node
## Wave 0 stub with the final signatures. The agent ui replaces it in Wave 1.

const DEFAULT_SETTINGS := {&"music": true, &"sfx": true, &"haptics": true, &"reduced_motion": false}

var _settings := DEFAULT_SETTINGS.duplicate()


func record(_level_id: String, _stars: int, _moves: int, _time_ms: int) -> Dictionary:
	return {"new_best": false}


func is_unlocked(index: int) -> bool:
	return index == 0


func best(_level_id: String) -> Dictionary:
	return {"stars": 0, "best_moves": 0, "best_time_ms": 0}


func highest_unlocked() -> int:
	return 0


func setting(key: StringName) -> bool:
	return _settings.get(key, false)


func set_setting(key: StringName, value: bool) -> void:
	_settings[key] = value
	Bus.setting_changed.emit(key, value)


func use_path(_path: String) -> void:
	pass


func unlock_all() -> void:
	pass


func flush() -> void:
	pass
