extends RefCounted

const Level := preload("res://scripts/core/level.gd")

const MAX_FLOOR := 62
const MAX_CELLS := 255
const MAX_BLOCKS := 4
const DEFLECTOR_GLYPHS := "┌┐└┘"
const DIR_NAMES: Array[String] = ["north", "south", "west", "east"]
# Closed sides of each deflector kind (index = kind), as directions U, D, L, R.
const CLOSED_SIDES: Array = [[], [0, 2], [0, 3], [1, 2], [1, 3]]


# Rows and columns in the messages count from 1.
static func parse(def: Dictionary, index: int) -> RefCounted:
	var lv := Level.new()
	lv.id = String(def.get("id", ""))
	lv.index = index
	lv.name_key = String(def.get("name_key", ""))
	lv.hint_key = String(def.get("hint_key", ""))
	var lines: Array = def.get("rows", [])
	if lines.is_empty():
		lv.errors.append("map has no rows")
		return lv

	var width := 0
	for line in lines:
		width = maxi(width, String(line).length())
	var first_width := String(lines[0]).length()
	for y in lines.size():
		var w := String(lines[y]).length()
		if w != first_width:
			lv.errors.append(_at(y, mini(w, first_width), "row width is %d, expected %d" % [w, first_width]))

	lv.rows = lines.size()
	lv.cols = width
	lv.cells = lv.cols * lv.rows
	lv.floor_cells.resize(lv.cells)
	lv.obstacle.resize(lv.cells)
	lv.deflector.resize(lv.cells)
	lv.floor_bit.resize(lv.cells)
	lv.floor_bit.fill(-1)
	lv.step = PackedInt32Array([-lv.cols, lv.cols, -1, 1])

	var block_cells := {}
	for y in lv.rows:
		var line := String(lines[y])
		for x in lv.cols:
			var c := line[x] if x < line.length() else "#"
			var i := y * lv.cols + x
			if c == "#":
				continue
			if c == "X":
				lv.obstacle[i] = 1
				continue
			var kind := DEFLECTOR_GLYPHS.find(c)
			if kind >= 0:
				lv.deflector[i] = kind + 1
			elif c >= "1" and c <= "9":
				var b := c.to_int()
				if block_cells.has(b):
					lv.errors.append(_at(y, x, "block id %d is used more than once" % b))
				else:
					block_cells[b] = i
			elif c != ".":
				lv.errors.append(_at(y, x, "unknown glyph '%s'" % c))
				continue
			lv.floor_cells[i] = 1
			lv.floor_bit[i] = lv.floor_count
			lv.floor_count += 1
			if lv.floor_count == MAX_FLOOR + 1:
				lv.errors.append(_at(y, x, "more than %d floor cells" % MAX_FLOOR))
			if y == 0 or y == lv.rows - 1 or x == 0 or x == lv.cols - 1:
				lv.errors.append(_at(y, x, "floor on the border: the map is open"))

	if lv.cells > MAX_CELLS:
		lv.errors.append(_at_cell(lv, MAX_CELLS, "more than %d cells (%d x %d)" % [MAX_CELLS, lv.cols, lv.rows]))

	_check_blocks(lv, block_cells)
	_check_deflectors(lv)
	_check_connected(lv)
	return lv


static func _check_blocks(lv: Level, block_cells: Dictionary) -> void:
	var n := block_cells.size()
	if n == 0:
		lv.errors.append("map has no block")
		return
	for b in block_cells:
		var cell: int = block_cells[b]
		if b > MAX_BLOCKS:
			lv.errors.append(_at_cell(lv, cell, "block id %d is above %d" % [b, MAX_BLOCKS]))
		elif b > n:
			lv.errors.append(_at_cell(lv, cell, "block id %d with %d blocks: ids must be 1..%d" % [b, n, n]))
		if lv.deflector[cell] != Level.NONE:
			lv.errors.append(_at_cell(lv, cell, "block %d starts on a deflector" % b))
	lv.starts.resize(n)
	lv.starts.fill(-1)
	for b in block_cells:
		if b >= 1 and b <= n:
			lv.starts[b - 1] = block_cells[b]


static func _check_deflectors(lv: Level) -> void:
	for i in lv.cells:
		var kind := lv.deflector[i]
		if kind == Level.NONE:
			continue
		var closed: Array = CLOSED_SIDES[kind]
		for d in 4:
			var floor_side := _is_floor(lv, i, d)
			if d in closed and floor_side:
				lv.errors.append(_at_cell(lv, i, "deflector side %s must be void or obstacle" % DIR_NAMES[d]))
			elif not (d in closed) and not floor_side:
				lv.errors.append(_at_cell(lv, i, "deflector side %s must be floor" % DIR_NAMES[d]))


static func _check_connected(lv: Level) -> void:
	var first := lv.floor_cells.find(1)
	if first < 0:
		lv.errors.append("map has no floor")
		return
	var seen := PackedByteArray()
	seen.resize(lv.cells)
	seen[first] = 1
	var queue := PackedInt32Array([first])
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for d in 4:
			if not _is_floor(lv, cell, d):
				continue
			var t := cell + lv.step[d]
			if seen[t] == 0:
				seen[t] = 1
				queue.append(t)
	if queue.size() == lv.floor_count:
		return
	for i in lv.cells:
		if lv.floor_cells[i] == 1 and seen[i] == 0:
			lv.errors.append(_at_cell(lv, i, "floor is not connected to row %d col %d (%d of %d floor cells reached)" % [
				lv.row_of(first) + 1, lv.col_of(first) + 1, queue.size(), lv.floor_count]))
			return


static func _is_floor(lv: Level, cell: int, d: int) -> bool:
	var x := lv.col_of(cell)
	var y := lv.row_of(cell)
	match d:
		0:
			y -= 1
		1:
			y += 1
		2:
			x -= 1
		_:
			x += 1
	if x < 0 or y < 0 or x >= lv.cols or y >= lv.rows:
		return false
	return lv.floor_cells[y * lv.cols + x] == 1


static func _at(y: int, x: int, message: String) -> String:
	return "row %d col %d: %s" % [y + 1, x + 1, message]


static func _at_cell(lv: Level, cell: int, message: String) -> String:
	return _at(lv.row_of(cell), lv.col_of(cell), message)
