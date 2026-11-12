extends Node
## Touch swipes from the first finger. A drag past the threshold on its dominant axis emits one swipe,
## then the finger is ignored until it lifts. A lift with almost no motion emits a tap.
## Touches that a Control takes (a button) never reach _unhandled_input, so they are not swipes.

const UP := 0
const DOWN := 1
const LEFT := 2
const RIGHT := 3

signal swiped(dir: int)
signal tapped

var enabled := true:
	set(value):
		enabled = value
		_tracking = false

var _tracking := false
var _fired := false
var _start := Vector2.ZERO
var _travel := 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			_tracking = true
			_fired = false
			_start = event.position
			_travel = 0.0
		elif _tracking:
			_tracking = false
			var moved := maxf(_travel, (event.position - _start).length())
			if not _fired and moved < Tuning.TAP_SLOP:
				tapped.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index != 0 or not _tracking:
			return
		get_viewport().set_input_as_handled()
		if _fired:
			return
		var delta: Vector2 = event.position - _start
		_travel = maxf(_travel, delta.length())
		var dir := direction_of(delta, Tuning.SWIPE_THRESHOLD)
		if dir >= 0:
			_fired = true
			swiped.emit(dir)


## The direction of a drag on its dominant axis, or -1 when it is shorter than `threshold`.
static func direction_of(delta: Vector2, threshold: float) -> int:
	var ax := absf(delta.x)
	var ay := absf(delta.y)
	if maxf(ax, ay) < threshold:
		return -1
	if ax > ay:
		return RIGHT if delta.x > 0.0 else LEFT
	return DOWN if delta.y > 0.0 else UP
