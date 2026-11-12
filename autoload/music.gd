extends Node
## Wave 0 stub with the final signatures. The agent audio replaces it in Wave 1.

var _playing := false
var _tense := false
var _fill := 0.0


func start() -> void:
	_playing = true


func stop() -> void:
	_playing = false


func set_tense(on: bool) -> void:
	_tense = on


func set_fill(ratio: float) -> void:
	_fill = clampf(ratio, 0.0, 1.0)


func duck(_db: float, _seconds: float) -> void:
	pass


func unduck(_seconds: float) -> void:
	pass


func tape_stop(_seconds: float) -> void:
	pass


func state() -> Dictionary:
	return {
		"playing": _playing,
		"clip": "tense" if _tense else "calm",
		"bpm": Tuning.Audio.TENSE_BPM if _tense else Tuning.Audio.CALM_BPM,
		"cutoff_hz": lerpf(Tuning.Audio.FILTER_MIN_HZ, Tuning.Audio.FILTER_MAX_HZ, _fill),
		"beat": 0,
	}
