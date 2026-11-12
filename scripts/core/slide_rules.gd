extends RefCounted

const Level := preload("res://scripts/core/level.gd")

const UP := 0
const DOWN := 1
const LEFT := 2
const RIGHT := 3
const DIR_CHARS := "UDLR"
const DIR_VECTORS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
# Index = deflector kind * 4 + direction. Kinds: 1 NW, 2 NE, 3 SW, 4 SE.
const TURN: Array[int] = [-1, -1, -1, -1, 3, -1, 1, -1, 2, -1, -1, 1, -1, 3, 0, -1, -1, 2, -1, 0]


static func dir_from_char(c: String) -> int:
	return DIR_CHARS.find(c)


# Returns the mask of the floor bits that the blocks entered and writes the end positions to `out`.
# When `events` is an Array, it gets the step and stop events in tick order.
static func resolve(level: Level, pos: PackedInt32Array, dir: int, out: PackedInt32Array, events = null) -> int:
	var rec := events is Array
	var cells := level.cells
	var floor_cells := level.floor_cells
	var deflector := level.deflector
	var floor_bit := level.floor_bit
	var step := level.step
	var n := pos.size()
	var d := PackedInt32Array()
	d.resize(n)
	d.fill(dir)
	var moving := PackedByteArray()
	moving.resize(n)
	moving.fill(1)
	var target := PackedInt32Array()
	target.resize(n)
	var blocked := PackedByteArray()
	blocked.resize(n)
	var visited := PackedByteArray()
	visited.resize(n * cells * 4)
	for i in n:
		out[i] = pos[i]
	var turned := PackedByteArray()
	var travelled := PackedInt32Array()
	var last_tick := PackedInt32Array()
	if rec:
		turned.resize(n)
		travelled.resize(n)
		last_tick.resize(n)
	var paint := 0
	var tick := 0
	var guard := cells * 4 + 8
	while guard > 0:
		guard -= 1
		tick += 1
		var any := false
		for i in n:
			target[i] = -1
			if moving[i] == 0:
				continue
			var kind := deflector[out[i]]
			if rec:
				turned[i] = 0
			if kind != 0:
				var new_dir := TURN[kind * 4 + d[i]]
				if new_dir >= 0:
					d[i] = new_dir
					if rec:
						turned[i] = 1
			var vk := (i * cells + out[i]) * 4 + d[i]
			if visited[vk] == 1:
				moving[i] = 0
				if rec:
					_stop(events, i, out[i], d[i], "loop", travelled, last_tick)
				continue
			visited[vk] = 1
			var t := out[i] + step[d[i]]
			if floor_cells[t] == 0:
				moving[i] = 0
				if rec:
					_stop(events, i, out[i], d[i], "wall", travelled, last_tick)
				continue
			target[i] = t
			any = true
		if not any:
			break
		blocked.fill(0)
		var changed := true
		while changed:
			changed = false
			for i in n:
				if moving[i] == 0 or blocked[i] == 1:
					continue
				var b := false
				for j in n:
					if j == i:
						continue
					if out[j] == target[i]:
						if moving[j] == 0 or blocked[j] == 1 or target[j] == out[i]:
							b = true
					if moving[j] == 1 and target[j] == target[i] and j < i:
						b = true
					if b:
						break
				if b:
					blocked[i] = 1
					changed = true
		if rec:
			for i in n:
				if moving[i] == 1 and blocked[i] == 1:
					_stop(events, i, out[i], d[i], "block", travelled, last_tick)
		for i in n:
			if moving[i] == 0:
				continue
			if blocked[i] == 1:
				moving[i] = 0
				continue
			if rec:
				events.append({"t": "step", "tick": tick, "block": i, "from": out[i], "to": target[i], "dir": d[i], "turned": turned[i] == 1})
				travelled[i] += 1
				last_tick[i] = tick
			out[i] = target[i]
			paint |= 1 << floor_bit[out[i]]
	if rec:
		for i in n:
			if moving[i] == 1:
				_stop(events, i, out[i], d[i], "loop", travelled, last_tick)
	return paint


static func _stop(events: Array, block: int, cell: int, dir: int, cause: String, travelled: PackedInt32Array, last_tick: PackedInt32Array) -> void:
	events.append({"t": "stop", "tick": last_tick[block], "block": block, "cell": cell, "dir": dir, "cause": cause, "travelled": travelled[block]})
