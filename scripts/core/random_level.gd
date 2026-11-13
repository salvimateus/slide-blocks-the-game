extends RefCounted
# The deterministic random level generator. Pure: no node, no autoload, no static state, so it runs on a worker thread.
# Each limit is an attempt count or a state count, never a time, so a seed gives the same level on each device.
# A change of this file changes the level of each seed.

const Level := preload("res://scripts/core/level.gd")
const LevelParser := preload("res://scripts/core/level_parser.gd")
const Solver := preload("res://scripts/core/solver.gd")
const SlideRules := preload("res://scripts/core/slide_rules.gd")

const SEED_MIN := 1
const SEED_MAX := 999999
## The level index for ScoreRules.thresholds.
const SCORE_INDEX := 5
const LEVEL_ID := "random"

const INNER_COLS_MIN := 6
const INNER_COLS_MAX := 8
const INNER_ROWS_MIN := 7
const INNER_ROWS_MAX := 9
const FLOOR_MIN := 24
const FLOOR_MAX := 42
const WALK_STEPS_MAX := 80
const SEG_LEN_MAX := 6
const DEFLECTOR_CHANCE := 0.15
const MAX_DEFLECTORS := 2
## Weights of 1 and 2 blocks.
const BLOCK_WEIGHTS: Array[int] = [2, 3]
const MIN_MOVES := 8
const MAX_MOVES := 24
const MIN_STATES := 120
const STATE_CAP := 60000
## Attempts with the picked block count; after them, as many attempts with one block.
const MAX_ATTEMPTS := 48

# Cell kinds of the carve grid.
const OPEN := 0
const FLOOR := 1
const LOCKED := 2
const BORDER := 3


class Cancel extends RefCounted:
	var cancelled := false


## The random level of `seed_value`. With `solo`, the level has one block.
## Result: {"level": Level, "def": Dictionary, "min": int, "solution": String, "states": int, "attempts": int,
## "blocks": int, "deflectors": int, "seed": int, "solo": bool}; {"cancelled": true} after a cancel; {} when no attempt passes.
static func generate(seed_value: int, solo: bool, cancel: Cancel = null) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var blocks := 1 if solo else _pick_weighted(rng, BLOCK_WEIGHTS) + 1
	for attempt in MAX_ATTEMPTS * 2:
		if cancel != null and cancel.cancelled:
			return {"cancelled": true}
		# A one-block carve is solvable by construction.
		if attempt == MAX_ATTEMPTS:
			blocks = 1
		var candidate := _attempt(rng, blocks)
		if candidate.is_empty():
			continue
		var level: Level = LevelParser.parse(candidate.def, SCORE_INDEX)
		if not level.is_valid() or level.floor_count < FLOOR_MIN or Solver.has_loop(level):
			continue
		var s := Solver.solve(level, STATE_CAP)
		if s.is_empty() or s.min < MIN_MOVES or s.min > MAX_MOVES or s.states < MIN_STATES:
			continue
		if Solver.has_dead_end(level):
			continue
		return {
			"level": level, "def": candidate.def, "min": s.min, "solution": s.solution, "states": s.states,
			"attempts": attempt + 1, "blocks": level.starts.size(), "deflectors": candidate.deflectors,
			"seed": seed_value, "solo": solo,
		}
	return {}


static func _pick_weighted(rng: RandomNumberGenerator, weights: Array[int]) -> int:
	var total := 0
	for w in weights:
		total += w
	var r := rng.randi_range(0, total - 1)
	for i in weights.size():
		if r < weights[i]:
			return i
		r -= weights[i]
	return weights.size() - 1


static func _shuffled_dirs(rng: RandomNumberGenerator) -> PackedInt32Array:
	var dirs := PackedInt32Array([0, 1, 2, 3])
	for i in range(3, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := dirs[i]
		dirs[i] = dirs[j]
		dirs[j] = tmp
	return dirs


static func _turn_kind(d: int, d2: int) -> int:
	for k in range(1, 5):
		if SlideRules.TURN[k * 4 + d] == d2:
			return k
	return Level.NONE


# One carve walk of a lone block, then the extra blocks on cells where the walk stopped.
static func _attempt(rng: RandomNumberGenerator, blocks: int) -> Dictionary:
	var ic := rng.randi_range(INNER_COLS_MIN, INNER_COLS_MAX)
	var ir := rng.randi_range(INNER_ROWS_MIN, INNER_ROWS_MAX)
	var cols := ic + 2
	var rows := ir + 2
	var n := cols * rows
	var step := PackedInt32Array([-cols, cols, -1, 1])
	var kind := PackedByteArray()
	kind.resize(n)
	var defl := PackedByteArray()
	defl.resize(n)
	for y in rows:
		for x in cols:
			if x == 0 or y == 0 or x == cols - 1 or y == rows - 1:
				kind[y * cols + x] = BORDER
	var start := rng.randi_range(1, ir) * cols + rng.randi_range(1, ic)
	kind[start] = FLOOR
	var floor_n := 1
	var target := rng.randi_range(FLOOR_MIN, FLOOR_MAX)
	var p := start
	var last_dir := -1
	var rests := PackedInt32Array()
	var deflectors := 0
	for i in WALK_STEPS_MAX:
		if floor_n >= target:
			break
		var moved := false
		for d in _shuffled_dirs(rng):
			if d == last_dir:
				continue
			var lens := _valid_lengths(kind, defl, step, p, d)
			if lens.is_empty():
				continue
			var length := lens[rng.randi_range(0, lens.size() - 1)]
			var end := p + step[d] * length
			var fresh_end := kind[end] == OPEN
			# A rail turn at a fresh end cell, when its closed sides can stay walls and the turn can go on.
			if fresh_end and end != start and deflectors < MAX_DEFLECTORS and rng.randf() < DEFLECTOR_CHANCE:
				var d2: int = (2 if rng.randf() < 0.5 else 3) if d < 2 else (0 if rng.randf() < 0.5 else 1)
				var k := _turn_kind(d, d2)
				var ok := k != Level.NONE
				if ok:
					for c in LevelParser.CLOSED_SIDES[k]:
						if kind[end + step[c]] == FLOOR:
							ok = false
				if ok:
					var legal := _second_leg_lengths(kind, defl, step, p, d, length, d2)
					if legal.is_empty():
						ok = false
					else:
						floor_n += _carve(kind, step, p, d, length)
						defl[end] = k
						for c in LevelParser.CLOSED_SIDES[k]:
							_lock(kind, end + step[c])
						var l2 := legal[rng.randi_range(0, legal.size() - 1)]
						floor_n += _carve(kind, step, end, d2, l2)
						_lock(kind, end + step[d2] * (l2 + 1))
						p = end + step[d2] * l2
						last_dir = d2
						deflectors += 1
						rests.append(p)
						moved = true
						break
			floor_n += _carve(kind, step, p, d, length)
			_lock(kind, end + step[d])
			p = end
			last_dir = d
			rests.append(p)
			moved = true
			break
		if not moved:
			break
	if floor_n < FLOOR_MIN:
		return {}
	var starts := PackedInt32Array([start])
	var pool := PackedInt32Array()
	for c in rests:
		if c != start and defl[c] == Level.NONE and not (c in pool):
			pool.append(c)
	for b in range(1, blocks):
		if pool.is_empty():
			return {}
		var pick := rng.randi_range(0, pool.size() - 1)
		starts.append(pool[pick])
		pool.remove_at(pick)
	return {"def": _rows_def(kind, defl, starts, cols, rows), "deflectors": deflectors}


# The lengths L >= 1 of a straight leg from `p` in `d`: each cell on the way is not a wall and not a rail,
# and the cell after the end is not floor, so the block stops there.
static func _valid_lengths(kind: PackedByteArray, defl: PackedByteArray, step: PackedInt32Array, p: int, d: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var q := p
	for l in range(1, SEG_LEN_MAX + 1):
		q += step[d]
		if kind[q] >= LOCKED or defl[q] != Level.NONE:
			break
		if kind[q + step[d]] != FLOOR:
			out.append(l)
	return out


# The lengths of the leg after a rail turn at the end of the first leg. The first leg is not carved yet,
# so a second leg that crosses its cells is refused.
static func _second_leg_lengths(kind: PackedByteArray, defl: PackedByteArray, step: PackedInt32Array, p: int, d: int, length: int, d2: int) -> PackedInt32Array:
	var end := p + step[d] * length
	var legal := PackedInt32Array()
	for l2 in _valid_lengths(kind, defl, step, end, d2):
		var crosses := false
		for j in range(1, l2 + 2):
			var c2 := end + step[d2] * j
			for j1 in range(1, length + 1):
				if c2 == p + step[d] * j1:
					crosses = true
		if not crosses:
			legal.append(l2)
	return legal


static func _carve(kind: PackedByteArray, step: PackedInt32Array, p: int, d: int, length: int) -> int:
	var fresh := 0
	var q := p
	for i in length:
		q += step[d]
		if kind[q] == OPEN:
			kind[q] = FLOOR
			fresh += 1
	return fresh


static func _lock(kind: PackedByteArray, cell: int) -> void:
	if kind[cell] == OPEN:
		kind[cell] = LOCKED


# Walls that touch the outside become void, enclosed walls become obstacles. The map is cut to the used box.
static func _rows_def(kind: PackedByteArray, defl: PackedByteArray, starts: PackedInt32Array, cols: int, rows: int) -> Dictionary:
	var n := cols * rows
	var outside := PackedByteArray()
	outside.resize(n)
	var queue := PackedInt32Array()
	for c in n:
		if kind[c] == BORDER:
			outside[c] = 1
			queue.append(c)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var x := c % cols
		@warning_ignore("integer_division")
		var y := c / cols
		for v in SlideRules.DIR_VECTORS:
			var nx: int = x + v.x
			var ny: int = y + v.y
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var t := ny * cols + nx
			if outside[t] == 0 and kind[t] != FLOOR:
				outside[t] = 1
				queue.append(t)
	var x0 := cols
	var y0 := rows
	var x1 := -1
	var y1 := -1
	for c in n:
		if outside[c] == 0:
			var x := c % cols
			@warning_ignore("integer_division")
			var y := c / cols
			x0 = mini(x0, x)
			y0 = mini(y0, y)
			x1 = maxi(x1, x)
			y1 = maxi(y1, y)
	var lines := []
	for y in range(y0 - 1, y1 + 2):
		var line := ""
		for x in range(x0 - 1, x1 + 2):
			var c := y * cols + x
			if outside[c] == 1:
				line += "#"
			elif kind[c] != FLOOR:
				line += "X"
			elif c in starts:
				line += str(starts.find(c) + 1)
			elif defl[c] != Level.NONE:
				line += LevelParser.DEFLECTOR_GLYPHS[defl[c] - 1]
			else:
				line += "."
		lines.append(line)
	return {"id": LEVEL_ID, "name_key": "", "hint_key": "", "rows": lines}
