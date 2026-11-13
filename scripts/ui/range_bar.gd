extends Control
## A bar with the three star ranges of a level, cut in one segment for each move. The segments up to a move count
## are lit in the color of their zone; the others are faded.
## Meter mode (HUD): the segments go from move 1 to the limit, and a move lights its segment with a pop.
## Result mode: the segments go from the minimum to the limit, each range has a label, and a bubble shows the moves.

const Palette := preload("res://scripts/core/palette.gd")
const Strings := preload("res://scripts/ui/strings.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiTuning := preload("res://scripts/ui/ui_tuning.gd")
const Icon := preload("res://scripts/ui/icon.gd")

const METER_BAR_HEIGHT := 26.0
const RESULT_BAR_HEIGHT := 34.0
const BUBBLE_HEIGHT := 46.0
const LABEL_HEIGHT := 36.0
const GAP := 10.0
const TRACK_PAD := 4.0
const SIDE_PAD := 6.0
const METER_MIN_SHARE := 0.12
const RESULT_MIN_SHARE := 0.3
const LABEL_GAP := 10.0
const SEGMENT_GAP := 3.0
const ZONE_GAP := 10.0
## Below this width a segment holds more than one move, so a long level stays readable.
const SEGMENT_MIN_WIDTH := 6.0
const SEGMENT_RADIUS := 5
## The share of the bar height that a faded segment keeps, so lit and faded differ by shape and not only by color.
const FADED_HEIGHT := 0.56
const FADED_MIX := 0.62
const LIT_RIM := 2
const LIT_RIM_DARKEN := 0.3
const POINTER_SIZE := Vector2(20.0, 9.0)

var _result_mode := false
var _bounds := PackedFloat32Array([0, 1, 2, 3])   # move value at each zone edge
var _edges := PackedFloat32Array([0, 1, 2, 3])    # share of the bar at each zone edge
var _zone_lo := PackedInt32Array([1, 2, 3])       # first move of each zone
var _zone_hi := PackedInt32Array([1, 2, 3])       # last move of each zone
var _moves := 0
## The segments, in parallel arrays: x range, first move, move count and zone.
var _seg_x0 := PackedFloat32Array()
var _seg_x1 := PackedFloat32Array()
var _seg_first := PackedInt32Array()
var _seg_count := PackedInt32Array()
var _seg_zone := PackedInt32Array()
var _pop: Panel
var _pop_box: StyleBoxFlat
var _pop_tween: Tween
var _bubble: PanelContainer
var _bubble_label: Label
var _zone_labels: Array[Control] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop_box = UiTheme.box(Color.WHITE, SEGMENT_RADIUS)
	_pop = Panel.new()
	_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop.add_theme_stylebox_override("panel", _pop_box)
	_pop.visible = false
	add_child(_pop)


func setup(t: Dictionary, result_mode: bool) -> void:
	_result_mode = result_mode
	var first: int = t.min if result_mode else 1
	_zone_lo = PackedInt32Array([first, t.three_max + 1, t.two_max + 1])
	_zone_hi = PackedInt32Array([t.three_max, t.two_max, t.limit])
	if result_mode:
		_bounds = PackedFloat32Array([t.min - 0.5, t.three_max + 0.5, t.two_max + 0.5, t.limit + 0.5])
	else:
		_bounds = PackedFloat32Array([0.0, t.three_max, t.two_max, t.limit])
	_edges = _shares(_bounds, RESULT_MIN_SHARE if result_mode else METER_MIN_SHARE)
	var bar_h := _bar_height()
	custom_minimum_size.y = BUBBLE_HEIGHT + GAP + bar_h + GAP + LABEL_HEIGHT if result_mode else bar_h + TRACK_PAD * 2.0 + 6.0
	for node in _zone_labels:
		node.queue_free()
	_zone_labels.clear()
	if _bubble:
		_bubble.queue_free()
		_bubble = null
		_bubble_label = null
	if result_mode:
		_build_result_parts(t)
	_moves = first - 1
	_stop_pop()
	_layout()
	queue_redraw()


## Lights the segments up to `moves`. With `animate`, a move that lights a new segment pops it.
func set_moves(moves: int, animate: bool) -> void:
	var shown := clampi(moves, _zone_lo[0] - 1, _zone_hi[2])
	if _bubble_label:
		_bubble_label.text = str(moves)
	if shown == _moves:
		return
	var grew := shown > _moves
	_moves = shown
	_place_bubble()
	queue_redraw()
	if animate and grew and Feel.motion() >= 1.0:
		_pop_segment(_segment_at(shown))
	elif not grew:
		_stop_pop()


## The x of a move count on the bar, in local units. The count grows in each zone in a straight line.
func x_for(moves: float) -> float:
	var share := _edges[0]
	if moves <= _bounds[0]:
		share = _edges[0]
	elif moves >= _bounds[3]:
		share = _edges[3]
	else:
		for z in 3:
			if moves <= _bounds[z + 1]:
				var k := (moves - _bounds[z]) / maxf(_bounds[z + 1] - _bounds[z], 0.001)
				share = lerpf(_edges[z], _edges[z + 1], k)
				break
	var track := _track_rect()
	return track.position.x + share * track.size.x


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
		queue_redraw()


func _bar_height() -> float:
	return RESULT_BAR_HEIGHT if _result_mode else METER_BAR_HEIGHT


func _track_rect() -> Rect2:
	var bar_h := _bar_height()
	var top := BUBBLE_HEIGHT + GAP if _result_mode else (size.y - bar_h) / 2.0
	return Rect2(SIDE_PAD, top, maxf(size.x - SIDE_PAD * 2.0, 1.0), bar_h)


# Cuts each zone in segments of `step` moves, with the smallest step that keeps each segment readable.
func _build_segments() -> void:
	var track := _track_rect()
	var spans: Array[Vector2] = []
	for z in 3:
		var x0 := track.position.x + _edges[z] * track.size.x + (ZONE_GAP / 2.0 if z > 0 else 0.0)
		var x1 := track.position.x + _edges[z + 1] * track.size.x - (ZONE_GAP / 2.0 if z < 2 else 0.0)
		spans.append(Vector2(x0, maxf(x1, x0 + 1.0)))
	var step := 1
	while step < 8 and _thinnest(spans, step) < SEGMENT_MIN_WIDTH:
		step += 1
	_seg_x0.clear()
	_seg_x1.clear()
	_seg_first.clear()
	_seg_count.clear()
	_seg_zone.clear()
	for z in 3:
		var moves := maxi(_zone_hi[z] - _zone_lo[z] + 1, 0)
		if moves == 0:
			continue
		var n := ceili(float(moves) / step)
		var w := (spans[z].y - spans[z].x - SEGMENT_GAP * (n - 1)) / n
		for i in n:
			var x := spans[z].x + i * (w + SEGMENT_GAP)
			_seg_x0.append(x)
			_seg_x1.append(x + maxf(w, 1.0))
			_seg_first.append(_zone_lo[z] + i * step)
			_seg_count.append(mini(step, _zone_hi[z] - (_zone_lo[z] + i * step) + 1))
			_seg_zone.append(z)


func _thinnest(spans: Array[Vector2], step: int) -> float:
	var thinnest := INF
	for z in 3:
		var moves := _zone_hi[z] - _zone_lo[z] + 1
		if moves <= 0:
			continue
		var n := ceili(float(moves) / step)
		thinnest = minf(thinnest, (spans[z].y - spans[z].x - SEGMENT_GAP * (n - 1)) / n)
	return thinnest


# The index of the segment that holds `moves`, or -1.
func _segment_at(moves: int) -> int:
	for i in _seg_first.size():
		if moves >= _seg_first[i] and moves < _seg_first[i] + _seg_count[i]:
			return i
	return -1


func _segment_rect(i: int) -> Rect2:
	var track := _track_rect()
	return Rect2(_seg_x0[i], track.position.y, _seg_x1[i] - _seg_x0[i], track.size.y)


func _pop_segment(i: int) -> void:
	if i < 0:
		return
	_stop_pop()
	var rect := _segment_rect(i)
	_pop_box.bg_color = _lit_colors()[_seg_zone[i]].lightened(0.25)
	_pop.position = rect.position
	_pop.size = rect.size
	_pop.pivot_offset = rect.size / 2.0
	_pop.scale = Vector2(UiTuning.METER_POP_SCALE, UiTuning.METER_POP_SCALE)
	_pop.modulate.a = 1.0
	_pop.visible = true
	_pop_tween = _pop.create_tween().set_parallel()
	_pop_tween.tween_property(_pop, "scale", Vector2.ONE, UiTuning.METER_POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(_pop, "modulate:a", 0.0, UiTuning.METER_POP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pop_tween.chain().tween_callback(_pop.hide)


func _stop_pop() -> void:
	if _pop_tween:
		_pop_tween.kill()
		_pop_tween = null
	_pop.visible = false


# The bubble sits above the last lit segment and stays inside the bar.
func _place_bubble() -> void:
	if _bubble == null:
		return
	var w := _bubble.get_combined_minimum_size().x
	var cx := _pointer_x()
	_bubble.size = Vector2(w, BUBBLE_HEIGHT)
	_bubble.position = Vector2(clampf(cx - w / 2.0, 0.0, maxf(size.x - w, 0.0)), 0.0)


func _pointer_x() -> float:
	var i := _segment_at(_moves)
	if i < 0:
		return x_for(_moves)
	return (_seg_x0[i] + _seg_x1[i]) / 2.0


func _layout() -> void:
	_build_segments()
	if _zone_labels.size() == 3:
		var track := _track_rect()
		var free_x := 0.0
		for z in 3:
			var node := _zone_labels[z]
			var w := node.get_combined_minimum_size().x
			var cx := track.position.x + (_edges[z] + _edges[z + 1]) / 2.0 * track.size.x
			var x := clampf(cx - w / 2.0, free_x, maxf(size.x - w, free_x))
			node.size = Vector2(w, LABEL_HEIGHT)
			node.position = Vector2(x, track.end.y + GAP)
			free_x = x + w + LABEL_GAP
	_place_bubble()
	if _pop_tween and _pop_tween.is_running():
		_stop_pop()


func _build_result_parts(t: Dictionary) -> void:
	var ranges := [Vector2i(t.min, t.three_max), Vector2i(t.three_max + 1, t.two_max), Vector2i(t.two_max + 1, t.limit)]
	for z in 3:
		var row := UiTheme.hbox(2)
		for s in 3 - z:
			row.add_child(Icon.new().setup(&"star", 19, Palette.INK, Palette.STAR))
		var r: Vector2i = ranges[z]
		var text := str(r.x) if r.x == r.y else Strings.t("range_span", {"lo": r.x, "hi": r.y})
		row.add_child(UiTheme.label(text, UiTuning.SIZE_TINY, UiTuning.WEIGHT_BOLD, Palette.INK_SOFT))
		add_child(row)
		_zone_labels.append(row)
	var sb := UiTheme.pad(UiTheme.box(Palette.CREAM_LIGHT, 16, Palette.INK, 3), 14, 2)
	_bubble = UiTheme.panel(sb)
	_bubble_label = UiTheme.label("0", UiTuning.SIZE_SMALL, UiTuning.WEIGHT_BOLD, Palette.INK)
	_bubble.add_child(_bubble_label)
	_bubble.resized.connect(queue_redraw)
	add_child(_bubble)


func _lit_colors() -> Array[Color]:
	return [UiTheme.ZONE_THREE_LIT, UiTheme.ZONE_TWO_LIT, UiTheme.ZONE_ONE_LIT]


func _draw() -> void:
	var track := _track_rect()
	var outer := track.grow(TRACK_PAD)
	outer.position.x = 0.0
	outer.size.x = size.x
	draw_style_box(UiTheme.box(Palette.MINT, int(outer.size.y / 2.0), Palette.FLOOR_SHADOW, 2), outer)
	var lit_colors := _lit_colors()
	var lit_boxes: Array[StyleBoxFlat] = []
	var faded_boxes: Array[StyleBoxFlat] = []
	var thinnest := INF
	for i in _seg_first.size():
		thinnest = minf(thinnest, _seg_x1[i] - _seg_x0[i])
	# Thin segments get a smaller corner and rim, so they do not turn into rings.
	var radius := clampi(int(thinnest * 0.3), 2, SEGMENT_RADIUS)
	var rim := LIT_RIM if thinnest >= 12.0 else 1
	for z in 3:
		lit_boxes.append(UiTheme.box(lit_colors[z], radius, lit_colors[z].darkened(LIT_RIM_DARKEN), rim))
		faded_boxes.append(UiTheme.box(lit_colors[z].lerp(Palette.MINT, FADED_MIX), radius))
	var faded_h := track.size.y * FADED_HEIGHT
	var faded_y := track.position.y + (track.size.y - faded_h) / 2.0
	for i in _seg_first.size():
		var z := _seg_zone[i]
		var used := clampi(_moves - _seg_first[i] + 1, 0, _seg_count[i])
		var w := _seg_x1[i] - _seg_x0[i]
		if used < _seg_count[i]:
			draw_style_box(faded_boxes[z], Rect2(_seg_x0[i], faded_y, w, faded_h))
		if used > 0:
			var lit_w := maxf(w * used / _seg_count[i], minf(w, radius * 2.0))
			draw_style_box(lit_boxes[z], Rect2(_seg_x0[i], track.position.y, lit_w, track.size.y))
	if _bubble:
		var cx := clampf(_pointer_x(), _bubble.position.x + 16.0, _bubble.position.x + _bubble.size.x - 16.0)
		var base_y := BUBBLE_HEIGHT - 4.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - POINTER_SIZE.x / 2.0, base_y), Vector2(cx + POINTER_SIZE.x / 2.0, base_y),
			Vector2(cx, base_y + POINTER_SIZE.y)]), Palette.INK)


static func _shares(bounds: PackedFloat32Array, min_share: float) -> PackedFloat32Array:
	var total := maxf(bounds[3] - bounds[0], 0.001)
	var widths := PackedFloat32Array()
	var sum := 0.0
	for z in 3:
		var w := maxf((bounds[z + 1] - bounds[z]) / total, min_share)
		widths.append(w)
		sum += w
	var edges := PackedFloat32Array([0.0])
	var acc := 0.0
	for z in 3:
		acc += widths[z] / sum
		edges.append(acc)
	edges[3] = 1.0
	return edges
