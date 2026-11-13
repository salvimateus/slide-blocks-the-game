extends RefCounted
# Offline search of the one-block version of a level. Only tools/levels_tool.gd calls it.
# A version keeps one block, which must paint the full floor of the version: up to SEARCHED_WALLS floor cells
# become walls to change the slides, then each floor cell that the lone block still cannot enter becomes a wall too.

const Level := preload("res://scripts/core/level.gd")
const LevelParser := preload("res://scripts/core/level_parser.gd")
const Solver := preload("res://scripts/core/solver.gd")
const SlideRules := preload("res://scripts/core/slide_rules.gd")
const SoloVariant := preload("res://scripts/core/solo_variant.gd")

const SEARCHED_WALLS := 2
const LAST_TIER_SEARCHED_WALLS := 5
const MAX_WALL_SHARE := 0.4
const MIN_MOVES := 6
# A fixed version for a level whose searched version is too easy: the search does not reach it, because it needs
# more searched walls, or obstacle cells ("open") that turn into floor. It must pass the same checks.
const PINNED := {"l22": {"keep": 1, "open": [58], "walls": [14, 38, 51, 85]}}


## The one-block version of a map with two or more blocks, or {} when no version passes.
## A version with a dead end is a last resort: only when no candidate of the map is free of dead ends,
## and only with no trap (a reachable state that can no longer paint the full floor).
## {"keep": int, "walls": Array (ascending cell indices), "open": Array (ascending cell indices), "min": int,
## "solution": String, "states": int, "floor": int, "searched": int, "dead_end": bool}
static func search(def: Dictionary, index: int) -> Dictionary:
	if PINNED.has(def.id):
		return _pinned(def, index)
	var strict := _search(def, index, false, SEARCHED_WALLS)
	return strict if not strict.is_empty() else _search(def, index, true, LAST_TIER_SEARCHED_WALLS)


static func _search(def: Dictionary, index: int, allow_dead_end: bool, searched_walls: int) -> Dictionary:
	var base: Level = LevelParser.parse(def, index)
	var n := base.starts.size()
	if not base.errors.is_empty() or n < 2:
		return {}
	var best_total := 1 << 30
	var best: Array[Dictionary] = []
	for k in n:
		var rows_k: Array = SoloVariant.make_def(def, k + 1, []).rows
		var lv: Level = LevelParser.parse({"id": def.id, "rows": rows_k}, index)
		if not lv.errors.is_empty():
			continue
		var full: int = (1 << lv.floor_count) - 1
		var max_walls := floori(MAX_WALL_SHARE * lv.floor_count)
		var cell_of_bit := PackedInt32Array()
		cell_of_bit.resize(lv.floor_count)
		for c in lv.cells:
			if lv.floor_bit[c] >= 0:
				cell_of_bit[lv.floor_bit[c]] = c
		var removed := {}
		var candidates := PackedInt32Array()
		for b in n:
			if b != k:
				candidates.append(base.starts[b])
				removed[base.starts[b]] = true
		for c in lv.cells:
			if lv.floor_cells[c] == 1 and lv.deflector[c] == Level.NONE and c != lv.starts[0] and not removed.has(c):
				candidates.append(c)
		var m := candidates.size()
		for d in range(0, mini(searched_walls, m) + 1):
			var combo := PackedInt32Array()
			for i in d:
				combo.append(i)
			while true:
				var dmask := 0
				for i in combo:
					lv.floor_cells[candidates[i]] = 0
					dmask |= 1 << lv.floor_bit[candidates[i]]
				var reach := _reach(lv)
				for i in combo:
					lv.floor_cells[candidates[i]] = 1
				var unreached: int = full & ~reach & ~dmask
				var total := d + _bit_count(unreached)
				if total <= best_total and total <= max_walls:
					var walls: Array = []
					var wall_mask: int = dmask | unreached
					for bit in lv.floor_count:
						if wall_mask & (1 << bit):
							walls.append(cell_of_bit[bit])
					walls.sort()
					var found := _validate(def, k + 1, walls, [], index, allow_dead_end)
					if not found.is_empty():
						var on_starts := 0
						for c in walls:
							if removed.has(c):
								on_starts += 1
						found.merge({"keep": k + 1, "walls": walls, "open": [], "searched": d, "on_starts": on_starts})
						if total < best_total:
							best_total = total
							best.clear()
							best.append(found)
						elif not _listed(best, k + 1, walls):
							best.append(found)
				if not _next_combination(combo, m):
					break
	if best.is_empty():
		return {}
	var pick: Dictionary = best[0]
	for entry in best:
		if entry.on_starts != pick.on_starts:
			if entry.on_starts > pick.on_starts:
				pick = entry
		elif entry.min > pick.min:
			pick = entry
	var result := pick.duplicate()
	result.erase("on_starts")
	return result


# The floor bits that a lone block can paint from its start, over each position that it can reach.
static func _reach(lv: Level) -> int:
	var start: int = lv.starts[0]
	var seen := {start: true}
	var stack: Array[int] = [start]
	var mask: int = 1 << lv.floor_bit[start]
	var pos := PackedInt32Array([0])
	var out := PackedInt32Array([0])
	while not stack.is_empty():
		var p: int = stack.pop_back()
		for dir in 4:
			pos[0] = p
			mask |= SlideRules.resolve(lv, pos, dir, out)
			if not seen.has(out[0]):
				seen[out[0]] = true
				stack.append(out[0])
	return mask


# The PINNED version of the level, or {} when it fails a check.
static func _pinned(def: Dictionary, index: int) -> Dictionary:
	var pin: Dictionary = PINNED[def.id]
	var found := _validate(def, pin.keep, pin.walls, pin.open, index, true)
	if found.is_empty():
		return {}
	found.merge({"keep": pin.keep, "walls": pin.walls, "open": pin.open, "searched": -1})
	return found


static func _validate(def: Dictionary, keep: int, walls: Array, opened: Array, index: int, allow_dead_end: bool) -> Dictionary:
	var v: Level = LevelParser.parse(SoloVariant.make_def(def, keep, walls, opened), index)
	if not v.errors.is_empty() or Solver.has_loop(v):
		return {}
	var s := Solver.solve(v)
	if s.is_empty() or s.min < MIN_MOVES:
		return {}
	var dead_end := Solver.has_dead_end(v)
	if dead_end and (not allow_dead_end or Solver.has_trap(v)):
		return {}
	return {"min": s.min, "solution": s.solution, "states": s.states, "floor": v.floor_count, "dead_end": dead_end}


static func _listed(best: Array[Dictionary], keep: int, walls: Array) -> bool:
	for entry in best:
		if entry.keep == keep and entry.walls == walls:
			return true
	return false


# Steps `combo` to the next combination of its size over 0..m-1 in lexicographic order. False after the last one.
static func _next_combination(combo: PackedInt32Array, m: int) -> bool:
	var d := combo.size()
	var i := d - 1
	while i >= 0 and combo[i] == m - d + i:
		i -= 1
	if i < 0:
		return false
	combo[i] += 1
	for j in range(i + 1, d):
		combo[j] = combo[j - 1] + 1
	return true


static func _bit_count(mask: int) -> int:
	var count := 0
	while mask != 0:
		count += mask & 1
		mask >>= 1
	return count
