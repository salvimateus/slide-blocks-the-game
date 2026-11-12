extends Node
## Plays one Session.swipe outcome on its BoardView, and emits the Bus signals of the swipe at visual time.
## All motion of one swipe is one parallel Tween, so `speed_scale` speeds up the whole playback.

signal finished(outcome: Dictionary)

const BoardTuning := preload("res://scripts/board/board_tuning.gd")
const Palette := preload("res://scripts/core/palette.gd")

const DIRS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

## The BoardView that this player drives. The BoardView sets it.
var board: Node2D
## False for the demo board: no Bus signal.
var emit_bus := true
## False for the demo board: no hit-stop and no haptics.
var use_feel := true
## Playback speed. Set BoardTuning.BUFFERED_SPEED while a swipe waits, and 1.0 after.
var speed_scale := 1.0: set = set_speed_scale

var _tween: Tween
var _outcome := {}
var _paints_done := 0
var _playing := false


func set_speed_scale(value: float) -> void:
	speed_scale = maxf(value, 0.01)
	if _tween != null and _tween.is_valid():
		_tween.set_speed_scale(speed_scale)


func is_playing() -> bool:
	return _playing


## Seconds of the playback of `outcome` at speed 1.
func duration(outcome: Dictionary) -> float:
	if outcome.get("ignored", false):
		return 0.0
	if not outcome.get("moved", false):
		return BoardTuning.NUDGE_TIME
	return int(outcome.ticks) * BoardTuning.STEP_TIME + BoardTuning.SETTLE_TIME


## Plays an outcome. A moved outcome slides the blocks; an outcome with `moved` false plays the nudge.
## Emits `finished` at the end, also for an ignored outcome (on the next idle frame).
func play(outcome: Dictionary) -> void:
	stop()
	_outcome = outcome
	_playing = true
	_paints_done = 0
	if outcome.get("ignored", false):
		_on_done.call_deferred()
		return
	var dir: int = outcome.dir
	_tween = board.create_tween()
	_tween.set_speed_scale(speed_scale)
	if not outcome.moved:
		board.nudge(dir)
		if emit_bus:
			Bus.swipe_ignored.emit(dir)
		_tween.tween_interval(BoardTuning.NUDGE_TIME)
		_tween.tween_callback(_on_done)
		return
	if emit_bus:
		Bus.swipe_started.emit(outcome)
	_tween.set_parallel(true)
	_schedule(outcome)
	_tween.tween_callback(_on_done).set_delay(duration(outcome))


## Ends the current playback at once in its final state, with no signal.
func stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if not _playing:
		return
	_playing = false
	if _outcome.get("moved", false):
		_complete_silently()


func _complete_silently() -> void:
	var paints: Array = _outcome.paints
	for i in range(_paints_done, paints.size()):
		var p: Dictionary = paints[i]
		board.set_tile_paint(int(p.cell), int(p.hue))
	_paints_done = paints.size()
	_snap()


func _snap() -> void:
	var positions: PackedInt32Array = _outcome.positions
	for b in board.blocks.size():
		board.blocks[b].position = board.cell_pos(positions[b])
		board.fx.streak_on(b, false)


func _on_done() -> void:
	if not _playing:
		return
	_playing = false
	_tween = null
	if _outcome.get("moved", false):
		_snap()
		if emit_bus:
			Bus.swipe_finished.emit(_outcome)
	finished.emit(_outcome)


# --- Schedule ---


func _schedule(outcome: Dictionary) -> void:
	var step_time := BoardTuning.STEP_TIME
	var level = board.level
	var n: int = board.blocks.size()
	var dir: int = outcome.dir
	var events: Array = outcome.events
	var steps: Array = []
	for b in n:
		steps.append([])
	var cur := PackedInt32Array()
	cur.resize(n)
	cur.fill(-1)
	for e: Dictionary in events:
		var b: int = e.block
		if cur[b] == -1:
			cur[b] = int(e.from) if e.t == "step" else int(e.cell)
		if e.t == "step":
			steps[b].append(e)
	for b in n:
		board.blocks[b].look(dir)

	# Stops, with the blocker of each block stop. In one tick the stop events come before the steps.
	var stops: Array = []
	var last_index := -1
	var last_tick := -1
	for e: Dictionary in events:
		if e.t == "step":
			cur[int(e.block)] = int(e.to)
			continue
		if int(e.travelled) == 0:
			continue
		var blocker := -1
		if e.cause == "block":
			blocker = cur.find(int(e.cell) + level.step[int(e.dir)])
		stops.append({"event": e, "blocker": blocker})
		if int(e.tick) >= last_tick:
			last_tick = int(e.tick)
			last_index = stops.size() - 1

	for b in n:
		_schedule_motion(b, steps[b], step_time)

	for p: Dictionary in outcome.paints:
		_tween.tween_callback(_paint.bind(p)).set_delay((int(p.tick) - 1.0 + BoardTuning.PAINT_AT) * step_time)

	for i in stops.size():
		var e: Dictionary = stops[i].event
		_tween.tween_callback(_stop.bind(e, i == last_index, int(stops[i].blocker))).set_delay(int(e.tick) * step_time)


func _schedule_motion(b: int, steps: Array, step_time: float) -> void:
	if steps.is_empty():
		return
	var bv: Node2D = board.blocks[b]
	var streak: Node2D = board.fx.streak(b)
	var level = board.level
	var first: Dictionary = steps[0]
	var start_time := (int(first.tick) - 1) * step_time
	_tween.tween_callback(_motion_start.bind(b, int(first.dir))).set_delay(start_time)

	# Segments: [kind, t0, t1, p0, p1, extra]. Kind 0 is a line, kind 1 is a rail arc.
	var segs: Array = []
	var arc_exit := -1.0
	for k in steps.size():
		var s: Dictionary = steps[k]
		var ta := (int(s.tick) - 1) * step_time
		var tb := int(s.tick) * step_time
		var pa: Vector2 = board.cell_pos(int(s.from))
		var pb: Vector2 = board.cell_pos(int(s.to))
		if s.turned:
			_tween.tween_callback(_turn.bind(b, int(s.from))).set_delay(ta)
		if arc_exit >= 0.0:
			_add_line(segs, arc_exit, tb, (pa + pb) * 0.5, pb, int(s.dir))
			arc_exit = -1.0
			continue
		var next: Dictionary = steps[k + 1] if k + 1 < steps.size() else {}
		var arcs: bool = not next.is_empty() and next.turned and int(next.from) == int(s.to) \
			and int(next.tick) == int(s.tick) + 1 and level.deflector[int(s.to)] != 0
		if not arcs:
			_add_line(segs, ta, tb, pa, pb, int(s.dir))
			continue
		var pc: Vector2 = board.cell_pos(int(next.to))
		var entry := (pa + pb) * 0.5
		var exit := (pb + pc) * 0.5
		var corner := entry + exit - pb
		var a0 := (entry - corner).angle()
		var a1 := a0 + wrapf((exit - corner).angle() - a0, -PI, PI)
		var mid := ta + step_time * 0.5
		_add_line(segs, ta, mid, pa, entry, int(s.dir))
		segs.append([1, mid, mid + step_time, entry, exit, [corner, (entry - corner).length(), a0, a1, int(next.dir)]])
		arc_exit = mid + step_time

	for seg: Array in segs:
		var t0: float = seg[1]
		var length: float = seg[2] - t0
		if seg[0] == 0:
			_tween.tween_property(bv, "position", seg[4], length).from(seg[3]).set_delay(t0)
			_tween.tween_property(streak, "position", seg[4], length).from(seg[3]).set_delay(t0)
		else:
			var arc: Array = seg[5]
			_tween.tween_method(_arc_step.bind(bv, streak, arc[0], arc[1], arc[2], arc[3]), 0.0, 1.0, length).set_delay(t0)
			_tween.tween_callback(bv.turn_motion.bind(int(arc[4]), length)).set_delay(t0)


## Adds a line segment, merged into the previous one when both go the same way without a break.
func _add_line(segs: Array, t0: float, t1: float, p0: Vector2, p1: Vector2, dir: int) -> void:
	if not segs.is_empty():
		var prev: Array = segs[-1]
		if prev[0] == 0 and is_equal_approx(prev[2], t0) and prev[5] == dir and (prev[4] as Vector2).is_equal_approx(p0):
			prev[2] = t1
			prev[4] = p1
			return
	segs.append([0, t0, t1, p0, p1, dir])


func _arc_step(f: float, bv: Node2D, streak: Node2D, center: Vector2, radius: float, a0: float, a1: float) -> void:
	var a := lerpf(a0, a1, f)
	var p := center + Vector2(cos(a), sin(a)) * radius
	bv.position = p
	streak.position = p


# --- Visual-time callbacks ---


func _motion_start(b: int, dir: int) -> void:
	var streak: Node2D = board.fx.streak(b)
	streak.position = board.blocks[b].position
	board.blocks[b].start_motion(dir)
	board.fx.streak_on(b, true)


func _paint(p: Dictionary) -> void:
	var cell: int = p.cell
	var hue: int = p.hue
	var fresh: bool = p.fresh
	board.paint_tile(cell, hue, fresh)
	_paints_done += 1
	if emit_bus:
		Bus.tile_painted.emit(cell, hue, fresh, int(p.tick) - 1)


func _turn(b: int, cell: int) -> void:
	board.rail_pop(cell)
	if emit_bus:
		Bus.block_turned.emit(b, cell)


func _stop(e: Dictionary, last: bool, blocker: int) -> void:
	var b: int = e.block
	var cell: int = e.cell
	var dir: int = e.dir
	var tiles: int = e.travelled
	var cause := StringName(e.cause)
	var power := clampf(tiles / BoardTuning.POWER_FULL_TILES, 0.0, 1.0)
	var bv: Node2D = board.blocks[b]
	var color: Color = Palette.BODY[bv.hue]
	var amount := minf(BoardTuning.SQUASH_BASE + BoardTuning.SQUASH_PER_TILE * tiles, BoardTuning.SQUASH_MAX)
	bv.squash(dir, amount * Feel.motion())
	board.fx.streak_on(b, false)
	var contact: Vector2 = board.cell_pos(cell) + DIRS[dir] * BoardTuning.PITCH * 0.5
	board.fx.splash(contact, dir, color, tiles)
	board.fx.impact_ring(contact, color, power)
	if blocker >= 0:
		board.blocks[blocker].jiggle(dir, power)
	if cause == &"wall" or last:
		board.kick(dir, tiles)
	if last and use_feel:
		if tiles >= BoardTuning.HIT_STOP_MIN_TILES:
			Feel.hit_stop(BoardTuning.HIT_STOP_MS)
		Feel.vibrate(&"stop")
	if emit_bus:
		Bus.block_stopped.emit(b, cell, dir, cause, power, last)
