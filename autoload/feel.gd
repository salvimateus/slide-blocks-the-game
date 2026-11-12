extends Node
## Hit-stop, haptics and the reduced-motion scale.

## The time scale that a hit-stop returns to. The harness sets it with --time-scale.
var base_time_scale := 1.0

var _hit_stop_serial := 0
var _hit_stop_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Lowers Engine.time_scale for `ms` real milliseconds (scaled by motion()).
## A new hit-stop during an active one replaces its end time.
func hit_stop(ms: int) -> void:
	var real_ms := roundi(ms * motion())
	if real_ms <= 0:
		return
	_hit_stop_serial += 1
	var serial := _hit_stop_serial
	_hit_stop_active = true
	Engine.time_scale = base_time_scale * Tuning.HIT_STOP_TIME_SCALE
	await get_tree().create_timer(real_ms / 1000.0, true, false, true).timeout
	if serial != _hit_stop_serial:
		return
	_hit_stop_active = false
	Engine.time_scale = base_time_scale


## Sets the base time scale and applies it at once, unless a hit-stop is active.
func set_base_time_scale(scale: float) -> void:
	base_time_scale = maxf(scale, 0.01)
	if not _hit_stop_active:
		Engine.time_scale = base_time_scale


func vibrate(kind: StringName) -> void:
	if not Save.setting(&"haptics") or not OS.has_feature("mobile"):
		return
	if not Tuning.HAPTIC_MS.has(kind):
		push_warning("Feel: unknown haptic kind '%s'" % kind)
		return
	Input.vibrate_handheld(Tuning.HAPTIC_MS[kind], Tuning.HAPTIC_AMPLITUDE[kind])


func motion() -> float:
	return Tuning.REDUCED_MOTION_SCALE if Save.setting(&"reduced_motion") else 1.0
