extends RefCounted

const Level := preload("res://scripts/core/level.gd")
const SlideRules := preload("res://scripts/core/slide_rules.gd")


static func pack(pos: PackedInt32Array) -> int:
	var k := 0
	for i in pos.size():
		k |= pos[i] << (8 * i)
	return k


# Exact BFS over (positions, paint mask). Returns {} when not solvable or above the cap.
static func solve(level: Level, cap: int = 3000000) -> Dictionary:
	var full := (1 << level.floor_count) - 1
	var mask0 := 0
	for p in level.starts:
		mask0 |= 1 << level.floor_bit[p]
	var s_key := PackedInt64Array([pack(level.starts)])
	var s_mask := PackedInt64Array([mask0])
	var s_parent := PackedInt32Array([-1])
	var s_dir := PackedByteArray([0])
	var seen := {s_key[0]: {mask0: true}}
	var cache := {}
	var head := 0
	var goal := -1
	while head < s_key.size() and goal < 0:
		var m := s_mask[head]
		if m == full:
			goal = head
			break
		var tr := _transitions(level, cache, s_key[head])
		for dir in 4:
			var nk := tr[dir * 2]
			if nk < 0:
				continue
			var nm := m | tr[dir * 2 + 1]
			var bucket: Dictionary
			if seen.has(nk):
				bucket = seen[nk]
			else:
				bucket = {}
				seen[nk] = bucket
			if bucket.has(nm):
				continue
			bucket[nm] = true
			s_key.append(nk)
			s_mask.append(nm)
			s_parent.append(head)
			s_dir.append(dir)
			if nm == full:
				goal = s_key.size() - 1
				break
			if s_key.size() > cap:
				return {}
		head += 1
	if goal < 0:
		return {}
	var path := ""
	var i := goal
	while s_parent[i] >= 0:
		path = SlideRules.DIR_CHARS[s_dir[i]] + path
		i = s_parent[i]
	return {"min": path.length(), "solution": path, "states": s_key.size()}


# True when a position set reachable from the start cannot return to the start.
static func has_dead_end(level: Level) -> bool:
	var cache := {}
	var start := pack(level.starts)
	var nodes := {start: true}
	var reverse := {}
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var key: int = queue.pop_back()
		var tr := _transitions(level, cache, key)
		for dir in 4:
			var nk := tr[dir * 2]
			if nk < 0:
				continue
			if not reverse.has(nk):
				reverse[nk] = PackedInt64Array()
			reverse[nk].append(key)
			if not nodes.has(nk):
				nodes[nk] = true
				queue.append(nk)
	var back := {start: true}
	queue = [start]
	while not queue.is_empty():
		var key: int = queue.pop_back()
		if not reverse.has(key):
			continue
		for p in reverse[key]:
			if not back.has(p):
				back[p] = true
				queue.append(p)
	return back.size() != nodes.size()


# True when a reachable state (positions, paint mask) can no longer reach a full paint.
# A dead end is harmless when no such state exists. Above the cap it returns true, to stay on the safe side.
static func has_trap(level: Level, cap: int = 3000000) -> bool:
	var full := (1 << level.floor_count) - 1
	var mask0 := 0
	for p in level.starts:
		mask0 |= 1 << level.floor_bit[p]
	var keys := PackedInt64Array([pack(level.starts)])
	var masks := PackedInt64Array([mask0])
	var index_of := {keys[0]: {mask0: 0}}
	var succ := PackedInt32Array()
	var cache := {}
	var head := 0
	while head < keys.size():
		var m := masks[head]
		var tr := _transitions(level, cache, keys[head])
		for dir in 4:
			var nk := tr[dir * 2]
			if nk < 0 or m == full:
				succ.append(-1)
				continue
			var nm := m | tr[dir * 2 + 1]
			var bucket: Dictionary = index_of.get(nk, {})
			if bucket.is_empty():
				index_of[nk] = bucket
			var j: int = bucket.get(nm, -1)
			if j < 0:
				if keys.size() >= cap:
					return true
				j = keys.size()
				bucket[nm] = j
				keys.append(nk)
				masks.append(nm)
			succ.append(j)
		head += 1
	# Reverse edges in CSR form, then a backward search from the full-paint states.
	var n := keys.size()
	var first := PackedInt32Array()
	first.resize(n + 1)
	for j in succ:
		if j >= 0:
			first[j + 1] += 1
	for i in n:
		first[i + 1] += first[i]
	var fill := first.duplicate()
	var rev := PackedInt32Array()
	rev.resize(first[n])
	for e in succ.size():
		var j := succ[e]
		if j >= 0:
			@warning_ignore("integer_division")
			rev[fill[j]] = e / 4
			fill[j] += 1
	var good := PackedByteArray()
	good.resize(n)
	var stack := PackedInt32Array()
	for i in n:
		if masks[i] == full:
			good[i] = 1
			stack.append(i)
	while not stack.is_empty():
		var s := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		for e in range(first[s], first[s + 1]):
			var p := rev[e]
			if good[p] == 0:
				good[p] = 1
				stack.append(p)
	return good.find(0) >= 0


# True when a lone block that starts on a deflector, in any direction, hits the loop guard.
static func has_loop(level: Level) -> bool:
	var pos := PackedInt32Array([0])
	var out := PackedInt32Array([0])
	for cell in level.cells:
		if level.deflector[cell] == Level.NONE:
			continue
		pos[0] = cell
		for dir in 4:
			var events := []
			SlideRules.resolve(level, pos, dir, out, events)
			for e in events:
				if e.t == "stop" and e.cause == "loop":
					return true
	return false


# For one position set: [next key or -1, paint mask] for each of the 4 directions.
static func _transitions(level: Level, cache: Dictionary, key: int) -> PackedInt64Array:
	if cache.has(key):
		return cache[key]
	var n := level.starts.size()
	var pos := PackedInt32Array()
	pos.resize(n)
	for i in n:
		pos[i] = (key >> (8 * i)) & 0xFF
	var out := PackedInt32Array()
	out.resize(n)
	var tr := PackedInt64Array()
	tr.resize(8)
	for dir in 4:
		var paint := SlideRules.resolve(level, pos, dir, out)
		var nk := pack(out)
		tr[dir * 2] = -1 if nk == key else nk
		tr[dir * 2 + 1] = paint
	cache[key] = tr
	return tr
