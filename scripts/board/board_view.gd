extends Node2D
## The tray, tiles, rails, obstacles and blocks of one level, with the board juice. Reused for every level.
## Make it after the TextureBank bake. Board units: one tile pitch is BoardTuning.PITCH; `fit` scales them.
## Children: a scrim (behind the board), then the kick node with the tray, tiles, rails, streaks, blocks, fx and glow.

signal intro_finished
signal restart_finished

const BoardTuning := preload("res://scripts/board/board_tuning.gd")
const Palette := preload("res://scripts/core/palette.gd")
const TextureBank := preload("res://scripts/board/texture_bank.gd")
const BlockView := preload("res://scripts/board/block_view.gd")
const FxPool := preload("res://scripts/board/fx_pool.gd")
const SwipePlayer := preload("res://scripts/board/swipe_player.gd")
const Ceremonies := preload("res://scripts/board/ceremonies.gd")

const DIRS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
const GRAY := -2
const RAIL_ROTATION := [0.0, 0.0, PI * 0.5, PI * 1.5, PI]   # by deflector kind: NW, NE, SW, SE
const SCRIM_EXTENT := 6000.0
const CH_SCALE := 0
const CH_POS := 1
const CH_OVERLAY := 2
const CH_DECOR := 3

var level: RefCounted
var hues := PackedInt32Array()
## Visual paint of each cell: -1 none, GRAY after a defeat, else a palette index.
var paint_hue := PackedInt32Array()
## BlockView nodes by block id.
var blocks: Array = []
var player: Node
var ceremonies: Node
var fx: Node

var _scrim: ColorRect
var _kick: Node2D
var _tray: Node2D
var _tiles_layer: Node2D
var _decor_layer: Node2D
var _fx_under: Node2D
var _blocks_layer: Node2D
var _fx_over: Node2D
var _glow_layer: Node2D
var _tiles: Array = []
var _overlays: Array = []
var _rails: Array = []
var _decor: Array = []          # [sprite, cell] of rails and obstacles
var _floor := PackedInt32Array()
var _tile_tw := {}
var _origin := Vector2.ZERO
var _grid_size := Vector2.ZERO  # board units of the non-void bounding box
var _scrim_tw: Tween
var _kick_tw: Tween
var _pulse_tw: Tween
var _tray_tw: Tween
var _seq_tw: Tween


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_scrim = ColorRect.new()
	_scrim.color = Color(Palette.SCRIM, 0.0)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.position = -Vector2.ONE * SCRIM_EXTENT
	_scrim.size = Vector2.ONE * SCRIM_EXTENT * 2.0
	_scrim.visible = false
	add_child(_scrim)
	_kick = Node2D.new()
	add_child(_kick)
	_tray = _layer()
	_tiles_layer = _layer()
	_decor_layer = _layer()
	_fx_under = _layer()
	_blocks_layer = _layer()
	_fx_over = _layer()
	_glow_layer = _layer()
	fx = FxPool.new()
	add_child(fx)
	player = SwipePlayer.new()
	player.board = self
	add_child(player)
	ceremonies = Ceremonies.new()
	ceremonies.board = self
	add_child(ceremonies)


func _layer() -> Node2D:
	var n := Node2D.new()
	_kick.add_child(n)
	return n


# --- Build and layout ---


## Builds the board of `p_level` (a Level) with one palette index for each block. All tiles show their final state.
func build(p_level: RefCounted, p_hues: PackedInt32Array) -> void:
	_stop_all()
	if not fx.is_attached():
		fx.attach(_fx_under, _fx_over, _glow_layer)
	for layer in [_tray, _tiles_layer, _decor_layer, _blocks_layer]:
		for child in layer.get_children():
			child.free()
	level = p_level
	hues = p_hues.duplicate()
	blocks.clear()
	_decor.clear()
	_tile_tw.clear()
	_tiles.resize(level.cells)
	_tiles.fill(null)
	_overlays.resize(level.cells)
	_overlays.fill(null)
	_rails.resize(level.cells)
	_rails.fill(null)
	paint_hue.resize(level.cells)
	paint_hue.fill(-1)
	_floor.clear()
	var solid := _solid_cells()
	_measure(solid)
	_build_tray(solid)
	_build_cells(solid)
	for b in level.starts.size():
		var bv := BlockView.new()
		_blocks_layer.add_child(bv)
		bv.setup(hues[b], level.index * 977 + b * 131 + 7)
		bv.position = cell_pos(level.starts[b])
		blocks.append(bv)
		fx.set_streak_color(b, Palette.BODY[hues[b]])
		set_tile_paint(level.starts[b], hues[b])
	_kick.position = Vector2.ZERO
	_kick.scale = Vector2.ONE
	_tray.modulate = Color.WHITE
	_tray.scale = Vector2.ONE
	_scrim.visible = false
	_scrim.color.a = 0.0


## Scales and centers the board into `rect`, in the coordinates of the parent.
func fit(rect: Rect2) -> void:
	var content := content_size()
	var s := minf(rect.size.x / content.x, rect.size.y / content.y)
	s = minf(s, BoardTuning.MAX_PITCH_BASE / BoardTuning.PITCH)
	scale = Vector2(s, s)
	position = rect.get_center() - Vector2(0, BoardTuning.RIM_SHADOW * 0.5 * s)
	fx.set_board_scale(s)


## Board units of the tray with its rim and drop shadow.
func content_size() -> Vector2:
	var border := 2.0 * (BoardTuning.WELL_PAD + BoardTuning.RIM)
	return _grid_size + Vector2(border, border + BoardTuning.RIM_SHADOW)


## The center of `cell` in board units.
func cell_pos(cell: int) -> Vector2:
	return Vector2(level.col_of(cell) + 0.5, level.row_of(cell) + 0.5) * BoardTuning.PITCH - _origin


## The center of `cell` in canvas coordinates, for UI hints.
func cell_global(cell: int) -> Vector2:
	return _kick.get_global_transform() * cell_pos(cell)


## The tray rect in canvas coordinates.
func board_rect_global() -> Rect2:
	var content := content_size()
	var local := Rect2(-content * 0.5, content)
	return get_global_transform() * local


func floor_cells() -> PackedInt32Array:
	return _floor


# --- Tiles ---


## Shows the paint of `cell` with no animation.
func set_tile_paint(cell: int, hue: int) -> void:
	paint_hue[cell] = hue
	var s: Sprite2D = _tiles[cell]
	s.texture = TextureBank.paint_tile(hue) if hue >= 0 else (TextureBank.tex(&"tile_gray") if hue == GRAY else TextureBank.tex(&"tile_empty"))


## Paint juice: tint, a pop that is stronger on the first paint, and a flash (body color, 70% white, paint).
func paint_tile(cell: int, hue: int, fresh: bool) -> void:
	set_tile_paint(cell, hue)
	var s: Sprite2D = _tiles[cell]
	var pop := (BoardTuning.PAINT_POP_FRESH if fresh else BoardTuning.PAINT_POP) - 1.0
	pop *= Feel.motion()
	var tw := _tile_tween(cell, CH_SCALE)
	s.scale = Vector2.ONE * (1.0 - pop * 0.6)
	tw.tween_property(s, "scale", Vector2.ONE * (1.0 + pop), BoardTuning.PAINT_POP_TIME * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", Vector2.ONE, BoardTuning.PAINT_POP_TIME * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var ov: Sprite2D = _overlays[cell]
	ov.texture = TextureBank.tex(&"tile_mask")
	ov.visible = true
	var otw := _tile_tween(cell, CH_OVERLAY)
	if fresh:
		ov.modulate = Palette.BODY[hue]
		otw.tween_interval(BoardTuning.FLASH_BODY_TIME)
		otw.tween_callback(ov.set_modulate.bind(Color(1, 1, 1, BoardTuning.FLASH_WHITE)))
	else:
		ov.modulate = Color(1, 1, 1, BoardTuning.FLASH_REPAINT_WHITE)
	otw.tween_property(ov, "modulate:a", 0.0, BoardTuning.FLASH_FADE_TIME)
	otw.tween_callback(ov.hide)


## A white flash on `cell` that fades in `time`.
func tile_flash(cell: int, alpha: float, time: float) -> void:
	var ov: Sprite2D = _overlays[cell]
	ov.texture = TextureBank.tex(&"tile_mask")
	ov.modulate = Color(1, 1, 1, alpha)
	ov.visible = true
	var tw := _tile_tween(cell, CH_OVERLAY)
	tw.tween_property(ov, "modulate:a", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ov.hide)


## A jump of the tile of `cell`, `height` in board units.
func tile_jump(cell: int, height: float, time: float) -> void:
	var s: Sprite2D = _tiles[cell]
	var base := cell_pos(cell)
	var tw := _tile_tween(cell, CH_POS)
	tw.tween_property(s, "position", base - Vector2(0, height), time * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position", base, time * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fades `cell` from its current look to `target_hue` (a palette index, GRAY or -1) in `time` after `delay`.
func tile_crossfade(cell: int, target_hue: int, time: float, delay: float) -> void:
	var s: Sprite2D = _tiles[cell]
	var ov: Sprite2D = _overlays[cell]
	var tw := _tile_tween(cell, CH_OVERLAY)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(_crossfade_start.bind(cell, target_hue))
	tw.tween_property(ov, "modulate:a", 0.0, time).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(ov.hide)
	var stw := _tile_tween(cell, CH_SCALE)
	if delay > 0.0:
		stw.tween_interval(delay)
	stw.tween_property(s, "scale", Vector2.ONE * 0.93, time * 0.4)
	stw.tween_property(s, "scale", Vector2.ONE, time * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _crossfade_start(cell: int, target_hue: int) -> void:
	var s: Sprite2D = _tiles[cell]
	var ov: Sprite2D = _overlays[cell]
	ov.texture = s.texture
	ov.modulate = Color.WHITE
	ov.visible = true
	set_tile_paint(cell, target_hue)


## A coral pulse on `cell`, `loops` times.
func tile_pulse(cell: int, color: Color, alpha: float, period: float, loops: int) -> void:
	var ov: Sprite2D = _overlays[cell]
	ov.texture = TextureBank.tex(&"tile_mask")
	ov.modulate = Color(color, 0.0)
	ov.visible = true
	var tw := _tile_tween(cell, CH_OVERLAY)
	for i in loops:
		tw.tween_property(ov, "modulate:a", alpha, period * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(ov, "modulate:a", 0.0, period * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(ov.hide)


## The pop of the rail of `cell`, and its sparks.
func rail_pop(cell: int) -> void:
	var r: Sprite2D = _rails[cell]
	if r == null:
		return
	var pop := 1.0 + (BoardTuning.RAIL_POP - 1.0) * Feel.motion()
	var tw := _tile_tween(cell, CH_DECOR)
	r.scale = Vector2.ONE * pop
	tw.tween_property(r, "scale", Vector2.ONE, BoardTuning.RAIL_POP_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var kind: int = level.deflector[cell]
	var corner := Vector2(-1, -1).rotated(RAIL_ROTATION[kind])
	fx.rail_spark(cell_pos(cell) + corner * BoardTuning.PITCH * 0.3)


## Kills the tweens of all tiles and blocks and puts them at rest. The paint stays.
func settle() -> void:
	for tw in _tile_tw.values():
		if tw != null:
			tw.kill()
	_tile_tw.clear()
	for cell in _floor:
		var s: Sprite2D = _tiles[cell]
		s.position = cell_pos(cell)
		s.scale = Vector2.ONE
		_overlays[cell].visible = false
	for pair in _decor:
		pair[0].scale = Vector2.ONE
	for bv in blocks:
		bv.settle()


# --- Board juice ---


## A kick toward `dir` with a spring return, stronger for a longer slide.
func kick(dir: int, tiles: int) -> void:
	var amount := minf(BoardTuning.KICK_BASE + BoardTuning.KICK_PER_TILE * tiles, BoardTuning.KICK_MAX) * Feel.motion()
	_kick.position = DIRS[dir] * amount / maxf(scale.x, 0.01)
	_kick_tw = _renew(_kick_tw)
	_kick_tw.tween_property(_kick, "position", Vector2.ZERO, BoardTuning.KICK_RETURN_TIME).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


## A short scale pulse of the whole board.
func pulse() -> void:
	_kick.scale = Vector2.ONE * (1.0 + (BoardTuning.PULSE_SCALE - 1.0) * Feel.motion())
	_pulse_tw = _renew(_pulse_tw)
	_pulse_tw.tween_property(_kick, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## The nudge of all blocks for a swipe that moves no block.
func nudge(dir: int) -> void:
	for bv in blocks:
		bv.nudge(dir)


## Fades the scrim behind the board in or out.
func show_scrim(on: bool, time: float = BoardTuning.SCRIM_FADE_TIME) -> void:
	if not on and not _scrim.visible:
		return
	_scrim_tw = _renew(_scrim_tw)
	if on:
		_scrim.visible = true
		_scrim_tw.tween_property(_scrim, "color:a", Tuning.SCRIM_ALPHA, time)
	else:
		_scrim_tw.tween_property(_scrim, "color:a", 0.0, time)
		_scrim_tw.tween_callback(_scrim.hide)


func set_scrim_now(on: bool) -> void:
	if _scrim_tw != null:
		_scrim_tw.kill()
	_scrim.visible = on
	_scrim.color.a = Tuning.SCRIM_ALPHA if on else 0.0


# --- Intro and restart ---


## Level start: the tray fades in, tiles pop in a stagger, blocks drop in and paint their start tiles.
## Emits `intro_finished`.
func play_intro() -> void:
	_stop_all()
	var motion := Feel.motion()
	_tray.modulate.a = 0.0
	_tray.scale = Vector2.ONE * 0.94
	_tray_tw = _renew(_tray_tw).set_parallel(true)
	_tray_tw.tween_property(_tray, "modulate:a", 1.0, BoardTuning.INTRO_TRAY_TIME)
	_tray_tw.tween_property(_tray, "scale", Vector2.ONE, BoardTuning.INTRO_TRAY_TIME + 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var first := _min_diagonal()
	var tiles_end := 0.0
	for cell in _floor:
		var delay := (_diagonal(cell) - first) * BoardTuning.INTRO_TILE_STAGGER
		tiles_end = maxf(tiles_end, delay + BoardTuning.INTRO_TILE_TIME)
		_pop_in(_tiles[cell], _tile_tween(cell, CH_SCALE), delay, BoardTuning.INTRO_TILE_TIME)
		if paint_hue[cell] != -1:
			set_tile_paint(cell, -1)
	for pair in _decor:
		var delay: float = (_diagonal(pair[1]) - first) * BoardTuning.INTRO_TILE_STAGGER + 0.05
		_pop_in(pair[0], _tile_tween(pair[1], CH_DECOR), delay, BoardTuning.INTRO_TILE_TIME)
	var drop := BoardTuning.INTRO_BLOCK_DROP * motion / maxf(scale.x, 0.01)
	var blocks_end := 0.0
	for b in blocks.size():
		var delay := BoardTuning.INTRO_BLOCK_DELAY + b * BoardTuning.INTRO_BLOCK_STAGGER
		blocks_end = delay + BoardTuning.INTRO_BLOCK_TIME
		blocks[b].drop_in(drop, BoardTuning.INTRO_BLOCK_TIME, delay, paint_tile.bind(level.starts[b], hues[b], true))
	_seq_tw = _renew(_seq_tw)
	_seq_tw.tween_interval(maxf(tiles_end, blocks_end + 0.08))
	_seq_tw.tween_callback(intro_finished.emit)


## Restart: the paint fades in a reverse wave and the blocks hop back to their starts in the new colors.
## Emits `restart_finished`.
func play_restart(p_hues: PackedInt32Array) -> void:
	_stop_all()
	hues = p_hues.duplicate()
	show_scrim(false, 0.2)
	var last := _max_diagonal()
	var wave_end := 0.0
	for cell in _floor:
		if paint_hue[cell] == -1:
			continue
		var delay := (last - _diagonal(cell)) * BoardTuning.RESTART_WAVE_STAGGER
		wave_end = maxf(wave_end, delay + BoardTuning.RESTART_FADE_TIME)
		tile_crossfade(cell, -1, BoardTuning.RESTART_FADE_TIME, delay)
	var blocks_end := 0.0
	for b in blocks.size():
		var start: int = level.starts[b]
		var delay := BoardTuning.RESTART_BLOCK_DELAY * (b + 1)
		blocks_end = delay + BoardTuning.RESTART_BLOCK_TIME
		fx.set_streak_color(b, Palette.BODY[hues[b]])
		blocks[b].hop_to(cell_pos(start), BoardTuning.RESTART_BLOCK_TIME, delay, hues[b], _land_start.bind(b))
	_seq_tw = _renew(_seq_tw)
	_seq_tw.tween_interval(maxf(wave_end, blocks_end + 0.06))
	_seq_tw.tween_callback(restart_finished.emit)


## Instant restart with new colors: no animation, no signal.
func reset(p_hues: PackedInt32Array) -> void:
	build(level, p_hues)


func _land_start(b: int) -> void:
	var start: int = level.starts[b]
	paint_tile(start, hues[b], true)


func _pop_in(node: Node2D, tw: Tween, delay: float, time: float) -> void:
	node.scale = Vector2.ZERO
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(node, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stop_all() -> void:
	if player != null:
		player.stop()
	if ceremonies != null:
		ceremonies.stop()
	for tw in [_seq_tw, _tray_tw, _kick_tw, _pulse_tw]:
		if tw != null:
			tw.kill()
	if level != null:
		settle()
	_kick.position = Vector2.ZERO
	_kick.scale = Vector2.ONE
	_tray.modulate = Color.WHITE
	_tray.scale = Vector2.ONE
	fx.clear()


# --- Rings for the ceremonies ---


## Floor cells grouped by their walk distance from `cell`, nearest first.
func rings_from(cell: int) -> Array:
	if cell < 0 or level.floor_cells[cell] == 0:
		cell = _floor[0]
	return _rings(PackedInt32Array([cell]))


## Floor cells grouped by their walk distance from the tray edge, edge first.
func rings_from_edge() -> Array:
	var edge := PackedInt32Array()
	for cell in _floor:
		for d in 4:
			if level.floor_cells[cell + level.step[d]] == 0:
				edge.append(cell)
				break
	return _rings(edge)


func ring_points(ring: PackedInt32Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for cell in ring:
		pts.append(cell_pos(cell))
	return pts


func _rings(sources: PackedInt32Array) -> Array:
	var dist := PackedInt32Array()
	dist.resize(level.cells)
	dist.fill(-1)
	var queue := PackedInt32Array()
	for s in sources:
		if dist[s] == -1:
			dist[s] = 0
			queue.append(s)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for d in 4:
			var t: int = cell + level.step[d]
			if level.floor_cells[t] == 1 and dist[t] == -1:
				dist[t] = dist[cell] + 1
				queue.append(t)
	var rings: Array = []
	for cell in queue:
		var r := dist[cell]
		while rings.size() <= r:
			rings.append(PackedInt32Array())
		var ring: PackedInt32Array = rings[r]
		ring.append(cell)
		rings[r] = ring
	return rings


# --- Construction helpers ---


## Floor, obstacle and enclosed void cells: everything that sits inside the tray.
func _solid_cells() -> PackedByteArray:
	var outside := PackedByteArray()
	outside.resize(level.cells)
	var queue := PackedInt32Array()
	for cell in level.cells:
		var c: int = level.col_of(cell)
		var r: int = level.row_of(cell)
		var border: bool = c == 0 or r == 0 or c == level.cols - 1 or r == level.rows - 1
		if border and level.floor_cells[cell] == 0 and level.obstacle[cell] == 0:
			outside[cell] = 1
			queue.append(cell)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		var c: int = level.col_of(cell)
		var r: int = level.row_of(cell)
		for n in [Vector2i(c, r - 1), Vector2i(c, r + 1), Vector2i(c - 1, r), Vector2i(c + 1, r)]:
			if n.x < 0 or n.y < 0 or n.x >= level.cols or n.y >= level.rows:
				continue
			var t: int = n.y * level.cols + n.x
			if outside[t] == 0 and level.floor_cells[t] == 0 and level.obstacle[t] == 0:
				outside[t] = 1
				queue.append(t)
	var solid := PackedByteArray()
	solid.resize(level.cells)
	for cell in level.cells:
		solid[cell] = 0 if outside[cell] == 1 else 1
	return solid


func _measure(solid: PackedByteArray) -> void:
	var lo := Vector2i(level.cols, level.rows)
	var hi := Vector2i(-1, -1)
	for cell in level.cells:
		if solid[cell] == 0:
			continue
		var p := Vector2i(level.col_of(cell), level.row_of(cell))
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
		hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	_grid_size = Vector2(hi - lo + Vector2i.ONE) * BoardTuning.PITCH
	_origin = Vector2(lo) * BoardTuning.PITCH + _grid_size * 0.5


func _build_tray(solid: PackedByteArray) -> void:
	for poly in _union_polygons(solid):
		var rim := _smooth(poly, BoardTuning.WELL_PAD + BoardTuning.RIM, BoardTuning.RIM_ROUND_CONVEX, BoardTuning.RIM_ROUND_CONCAVE)
		var well := _smooth(poly, BoardTuning.WELL_PAD, BoardTuning.WELL_ROUND_CONVEX, BoardTuning.WELL_ROUND_CONCAVE)
		_poly(rim, Color(Palette.INK, 0.13), Vector2(0, BoardTuning.RIM_SHADOW))
		_poly(rim, Palette.TRAY_SHADOW, Vector2(0, BoardTuning.RIM_LIP))
		_poly(rim, Palette.TRAY_HIGHLIGHT, Vector2.ZERO)
		_poly(_offset(rim, -4.0), Palette.PERIWINKLE, Vector2(0, 4))
		_poly(well, Palette.TRAY_SHADOW, Vector2.ZERO)
		_poly(_offset(well, -4.0), Palette.TRAY_WELL, Vector2(0, 4))


func _build_cells(solid: PackedByteArray) -> void:
	for cell in level.cells:
		if solid[cell] == 0:
			continue
		var pos := cell_pos(cell)
		if level.floor_cells[cell] == 1:
			_floor.append(cell)
			var s := Sprite2D.new()
			s.texture = TextureBank.tex(&"tile_empty")
			s.position = pos
			_tiles_layer.add_child(s)
			_tiles[cell] = s
			var ov := Sprite2D.new()
			ov.visible = false
			s.add_child(ov)
			_overlays[cell] = ov
			var kind: int = level.deflector[cell]
			if kind != 0:
				var rail := Sprite2D.new()
				rail.texture = TextureBank.tex(&"rail")
				rail.rotation = RAIL_ROTATION[kind]
				rail.position = pos
				_decor_layer.add_child(rail)
				_rails[cell] = rail
				_decor.append([rail, cell])
		else:
			var o := Sprite2D.new()
			o.texture = TextureBank.tex(&"obstacle")
			o.position = pos
			_decor_layer.add_child(o)
			_decor.append([o, cell])


## One polygon for each connected group of solid cells, built by merging cell squares in walk order.
func _union_polygons(solid: PackedByteArray) -> Array:
	var seen := PackedByteArray()
	seen.resize(level.cells)
	var out: Array = []
	for first in level.cells:
		if solid[first] == 0 or seen[first] == 1:
			continue
		seen[first] = 1
		var queue := PackedInt32Array([first])
		var head := 0
		var union := PackedVector2Array()
		while head < queue.size():
			var cell := queue[head]
			head += 1
			var square := _square(cell)
			union = square if union.is_empty() else _largest(Geometry2D.merge_polygons(union, square))
			var c: int = level.col_of(cell)
			var r: int = level.row_of(cell)
			for n in [Vector2i(c, r - 1), Vector2i(c, r + 1), Vector2i(c - 1, r), Vector2i(c + 1, r)]:
				if n.x < 0 or n.y < 0 or n.x >= level.cols or n.y >= level.rows:
					continue
				var t: int = n.y * level.cols + n.x
				if solid[t] == 1 and seen[t] == 0:
					seen[t] = 1
					queue.append(t)
		out.append(union)
	return out


func _square(cell: int) -> PackedVector2Array:
	var c := cell_pos(cell)
	var h := BoardTuning.PITCH * 0.5 + 0.5
	return PackedVector2Array([c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(h, h), c + Vector2(-h, h)])


## Grows `poly` by `grow`, with round convex and concave corners.
func _smooth(poly: PackedVector2Array, grow: float, convex: float, concave: float) -> PackedVector2Array:
	var opened := _offset(poly, -convex)
	var grown := _offset(opened, convex + grow + concave)
	return _offset(grown, -concave)


func _offset(poly: PackedVector2Array, delta: float) -> PackedVector2Array:
	return _largest(Geometry2D.offset_polygon(poly, delta, Geometry2D.JOIN_ROUND))


static func _largest(polys: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := -1.0
	for p: PackedVector2Array in polys:
		var area := absf(_area(p))
		if area > best_area:
			best_area = area
			best = p
	return best


static func _area(p: PackedVector2Array) -> float:
	var sum := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


func _poly(points: PackedVector2Array, color: Color, offset: Vector2) -> void:
	if points.size() < 3:
		return
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = offset
	p.antialiased = true
	_tray.add_child(p)


func _diagonal(cell: int) -> int:
	return level.col_of(cell) + level.row_of(cell)


func _min_diagonal() -> int:
	var best := 1 << 30
	for cell in _floor:
		best = mini(best, _diagonal(cell))
	return best


func _max_diagonal() -> int:
	var best := 0
	for cell in _floor:
		best = maxi(best, _diagonal(cell))
	return best


func _tile_tween(cell: int, channel: int) -> Tween:
	var key := cell * 4 + channel
	var old: Tween = _tile_tw.get(key)
	if old != null:
		old.kill()
	var tw := create_tween()
	_tile_tw[key] = tw
	return tw


func _renew(tw: Tween) -> Tween:
	if tw != null:
		tw.kill()
	return create_tween()
