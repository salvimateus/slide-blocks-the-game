extends Control
## A small picture of a board, drawn one time from the level data: tray, tiles, obstacles, rails and blocks.
## It can hold a second level (the alternate look, for example the one-jelly version) and show it with `alt`.

const Palette := preload("res://scripts/core/palette.gd")
const LevelParser := preload("res://scripts/core/level_parser.gd")
const Level := preload("res://scripts/core/level.gd")
const UiBake := preload("res://scripts/ui/ui_bake.gd")
const UiTuning := preload("res://scripts/ui/ui_tuning.gd")

const RIM := 0.32                      # rim width, as a share of the cell
const GAP := 0.1                       # gap between tiles, as a share of the cell
const TILE_RADIUS := 0.24
const RAIL_WIDTH := 0.14

## A muted thumbnail draws each color faded toward the card, opaque, for a locked level.
var muted := false:
	set(value):
		if muted != value:
			muted = value
			queue_redraw()

## Shows the alternate level when there is one. A muted thumbnail always shows the normal level.
var alt := false:
	set(value):
		if alt != value:
			alt = value
			queue_redraw()

## False for the copy that the baker draws in vector form.
var bakeable := true

var _level: RefCounted
var _hues := PackedInt32Array()
var _def := {}
var _alt_level: RefCounted
var _alt_hues := PackedInt32Array()
var _alt_def := {}
var _index := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `def` is an entry of LevelsData. The block colors follow the level index, so a thumbnail never changes.
## `alt_def`, when not empty, is the level of the alternate look, with block colors from the same rule.
func setup(def: Dictionary, index: int, alt_def: Dictionary = {}) -> Control:
	_def = def
	_index = index
	_level = LevelParser.parse(def, index)
	_hues = _hues_for(_level, index)
	_alt_def = alt_def
	_alt_level = null
	_alt_hues = PackedInt32Array()
	if not alt_def.is_empty():
		_alt_level = LevelParser.parse(alt_def, index)
		_alt_hues = _hues_for(_alt_level, index)
	queue_redraw()
	return self


func has_alt() -> bool:
	return _alt_level != null


static func _hues_for(lv: Level, index: int) -> PackedInt32Array:
	var hues := PackedInt32Array()
	for b in lv.starts.size():
		hues.append((index * 3 + b * 2) % Palette.FAMILY_SIZE)
	return hues


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## Asks the baker for each look that can show: normal muted, normal, and the alternate one (never muted).
func prewarm() -> void:
	_fetch(false, false, null)
	_fetch(false, true, null)
	if has_alt():
		_fetch(true, false, null)


func _shows_alt() -> bool:
	return alt and has_alt() and not muted


func _fetch(look_alt: bool, look_muted: bool, waiter: CanvasItem) -> Texture2D:
	if _level == null or size.x <= 0.0 or size.y <= 0.0:
		return null
	var key := "thumb|%d|%s|%s" % [_index, "alt" if look_alt else "base", look_muted]
	return UiBake.fetch(key, Rect2(Vector2.ZERO, size).grow(2.0), _make_copy.bind(look_alt, look_muted), waiter,
		UiTuning.THUMB_MAX_PIXEL_SCALE)


func _make_copy(look_alt: bool, look_muted: bool) -> CanvasItem:
	var copy: Control = get_script().new()
	copy.bakeable = false
	copy.setup(_def, _index, _alt_def if look_alt else {})
	copy.alt = look_alt
	copy.muted = look_muted
	copy.size = size
	return copy


func _draw() -> void:
	var look_alt := _shows_alt()
	var lv: Level = _alt_level if look_alt else _level
	if lv == null or lv.cells == 0:
		return
	if bakeable:
		var tex := _fetch(look_alt, muted, self)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size).grow(2.0), false)
			return
	var hues := _alt_hues if look_alt else _hues
	var bounds := _used_bounds(lv)
	var span := Vector2(bounds.size) + Vector2(RIM * 2.0, RIM * 2.0)
	var cell := minf(size.x / span.x, size.y / span.y)
	if cell <= 0.0:
		return
	var origin := (size - span * cell) / 2.0 + Vector2(RIM, RIM) * cell - Vector2(bounds.position) * cell
	var rim := RIM * cell
	# The tray: rim, then the well, as one shape grown from the used cells.
	for pass_index in 2:
		var grow := rim if pass_index == 0 else rim * 0.45
		var c := Palette.PERIWINKLE if pass_index == 0 else Palette.TRAY_WELL
		for i in lv.cells:
			if lv.floor_cells[i] == 0 and lv.obstacle[i] == 0:
				continue
			var r := _cell_rect(lv, i, origin, cell).grow(grow)
			_rbox(r, cell * (0.42 if pass_index == 0 else 0.2), c)
	for i in lv.cells:
		var r := _cell_rect(lv, i, origin, cell).grow(-cell * GAP / 2.0)
		if lv.obstacle[i] == 1:
			_rbox(r, cell * TILE_RADIUS, Palette.TRAY_SHADOW)
			_rbox(Rect2(r.position, r.size - Vector2(0, cell * 0.1)), cell * TILE_RADIUS, Palette.PERIWINKLE)
		elif lv.floor_cells[i] == 1:
			var painted := lv.starts.find(i)
			var face := Palette.MINT if painted < 0 else Palette.PAINT[hues[painted]]
			_rbox(r, cell * TILE_RADIUS, Palette.FLOOR_SHADOW if painted < 0 else Palette.OUTLINE[hues[painted]])
			_rbox(Rect2(r.position, r.size - Vector2(0, cell * 0.07)), cell * TILE_RADIUS, face)
			if lv.deflector[i] != Level.NONE:
				_draw_rail(lv.deflector[i], r, cell)
	for b in lv.starts.size():
		_draw_block(_cell_rect(lv, lv.starts[b], origin, cell), cell, hues[b])


func _used_bounds(lv: Level) -> Rect2i:
	var lo := Vector2i(lv.cols, lv.rows)
	var hi := Vector2i(-1, -1)
	for i in lv.cells:
		if lv.floor_cells[i] == 0 and lv.obstacle[i] == 0:
			continue
		var p := Vector2i(lv.col_of(i), lv.row_of(i))
		lo = lo.min(p)
		hi = hi.max(p)
	if hi.x < 0:
		return Rect2i(0, 0, 1, 1)
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _cell_rect(lv: Level, i: int, origin: Vector2, cell: float) -> Rect2:
	return Rect2(origin + Vector2(lv.col_of(i), lv.row_of(i)) * cell, Vector2(cell, cell))


# A rail is a rounded fillet that hugs the closed corner of the tile.
func _draw_rail(kind: int, r: Rect2, cell: float) -> void:
	var radius := r.size.x * 0.5
	var inset := r.size.x * 0.16
	var center: Vector2
	var start: float
	match kind:
		Level.NW:
			center = r.position + Vector2(radius + inset, radius + inset)
			start = PI
		Level.NE:
			center = Vector2(r.end.x - radius - inset, r.position.y + radius + inset)
			start = PI * 1.5
		Level.SW:
			center = Vector2(r.position.x + radius + inset, r.end.y - radius - inset)
			start = PI * 0.5
		_:
			center = r.end - Vector2(radius + inset, radius + inset)
			start = 0.0
	var width := cell * RAIL_WIDTH
	draw_arc(center, radius, start, start + PI / 2.0, 16, _tone(Palette.CREAM_LIGHT), width * 1.8, true)
	draw_arc(center, radius, start, start + PI / 2.0, 16, _tone(Palette.CORAL), width, true)


func _draw_block(r: Rect2, cell: float, hue: int) -> void:
	var body := r.grow(-cell * 0.1)
	_rbox(body, cell * 0.3, Palette.OUTLINE[hue])
	_rbox(Rect2(body.position, body.size - Vector2(0, cell * 0.08)), cell * 0.3, Palette.BODY[hue])
	var eye_y := body.position.y + body.size.y * 0.45
	var eye_r := maxf(cell * 0.07, 0.8)
	draw_circle(Vector2(body.position.x + body.size.x * 0.34, eye_y), eye_r, _tone(Palette.INK), true, -1.0, true)
	draw_circle(Vector2(body.position.x + body.size.x * 0.66, eye_y), eye_r, _tone(Palette.INK), true, -1.0, true)


func _rbox(rect: Rect2, radius: float, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = _tone(c)
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 6
	sb.anti_aliasing = true
	draw_style_box(sb, rect)


func _tone(c: Color) -> Color:
	return c.lerp(Palette.CREAM_SHADOW, 0.72) if muted else c
