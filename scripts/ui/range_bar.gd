extends Control
## A bar with the three star ranges of a level and a marker at a move count.
## Meter mode (HUD): the bar runs from 0 to the limit, the marker shows the moves used.
## Result mode: the bar runs from the minimum to the limit, each range has a label, and a bubble shows the moves.

const Palette := preload("res://scripts/core/palette.gd")
const Strings := preload("res://scripts/ui/strings.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiTuning := preload("res://scripts/ui/ui_tuning.gd")
const Icon := preload("res://scripts/ui/icon.gd")

const ZONE_COLORS: Array[Color] = [UiTheme.ZONE_THREE, UiTheme.ZONE_TWO, UiTheme.ZONE_ONE]
const METER_BAR_HEIGHT := 26.0
const RESULT_BAR_HEIGHT := 34.0
const BUBBLE_HEIGHT := 46.0
const LABEL_HEIGHT := 36.0
const GAP := 10.0
const ZONE_GAP := 4.0
const TRACK_PAD := 4.0
const METER_MIN_SHARE := 0.12
const RESULT_MIN_SHARE := 0.3
const LABEL_GAP := 10.0

var _result_mode := false
var _bounds := PackedFloat32Array([0, 1, 2, 3])   # move value at each zone edge
var _edges := PackedFloat32Array([0, 1, 2, 3])    # share of the bar at each zone edge
var _moves := 0
var _active_zone := -1
var _marker: Control
var _bubble: PanelContainer
var _bubble_label: Label
var _zone_labels: Array[Control] = []
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker = Icon.new().setup(&"knob", METER_BAR_HEIGHT + 14.0, Palette.INK)
	add_child(_marker)


func setup(t: Dictionary, result_mode: bool) -> void:
	_result_mode = result_mode
	if result_mode:
		_bounds = PackedFloat32Array([t.min - 0.5, t.three_max + 0.5, t.two_max + 0.5, t.limit + 0.5])
	else:
		_bounds = PackedFloat32Array([0.0, t.three_max, t.two_max, t.limit])
	_edges = _shares(_bounds, RESULT_MIN_SHARE if result_mode else METER_MIN_SHARE)
	var bar_h := _bar_height()
	_marker.setup(&"knob", bar_h + 14.0, Palette.INK)
	custom_minimum_size.y = BUBBLE_HEIGHT + GAP + bar_h + GAP + LABEL_HEIGHT if result_mode else bar_h + 14.0
	for node in _zone_labels:
		node.queue_free()
	_zone_labels.clear()
	if _bubble:
		_bubble.queue_free()
		_bubble = null
	if result_mode:
		_build_result_parts(t)
	_active_zone = -1
	_layout()
	queue_redraw()


func set_moves(moves: int, animate: bool) -> void:
	_moves = moves
	var zone := -1
	if _result_mode:
		for z in 3:
			if moves <= _bounds[z + 1]:
				zone = z
				break
		if _bubble_label:
			_bubble_label.text = str(moves)
	if zone != _active_zone:
		_active_zone = zone
		queue_redraw()
	var target := _marker_position()
	if _tween:
		_tween.kill()
	if not animate:
		_marker.position = target
		_place_bubble()
		return
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_marker, "position", target, UiTuning.METER_MARKER_TIME)
	if _bubble:
		_tween.parallel().tween_method(func(_v: float) -> void: _place_bubble(), 0.0, 1.0, UiTuning.METER_MARKER_TIME)


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
	var side := (bar_h + 14.0) / 2.0
	return Rect2(side, top, maxf(size.x - side * 2.0, 1.0), bar_h)


func _marker_position() -> Vector2:
	var track := _track_rect()
	return Vector2(x_for(_moves), track.get_center().y) - _marker.size / 2.0


func _place_bubble() -> void:
	if _bubble == null:
		return
	var w := _bubble.get_combined_minimum_size().x
	var cx := _marker.position.x + _marker.size.x / 2.0
	_bubble.size = Vector2(w, BUBBLE_HEIGHT)
	_bubble.position = Vector2(clampf(cx - w / 2.0, 0.0, maxf(size.x - w, 0.0)), 0.0)


func _layout() -> void:
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
	if _tween == null or not _tween.is_running():
		_marker.position = _marker_position()
		_place_bubble()


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
	add_child(_bubble)


func _draw() -> void:
	var track := _track_rect()
	var outer := track.grow(TRACK_PAD)
	draw_style_box(UiTheme.box(Palette.MINT, int(outer.size.y / 2.0), Palette.FLOOR_SHADOW, 2), outer)
	var radius := int(track.size.y / 2.0)
	for z in 3:
		var x0 := track.position.x + _edges[z] * track.size.x + (ZONE_GAP / 2.0 if z > 0 else 0.0)
		var x1 := track.position.x + _edges[z + 1] * track.size.x - (ZONE_GAP / 2.0 if z < 2 else 0.0)
		var sb := UiTheme.box(ZONE_COLORS[z], 0)
		sb.corner_radius_top_left = radius if z == 0 else 6
		sb.corner_radius_bottom_left = radius if z == 0 else 6
		sb.corner_radius_top_right = radius if z == 2 else 6
		sb.corner_radius_bottom_right = radius if z == 2 else 6
		if z == _active_zone:
			sb.border_color = Palette.INK
			sb.set_border_width_all(3)
		draw_style_box(sb, Rect2(x0, track.position.y, maxf(x1 - x0, 1.0), track.size.y))


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
