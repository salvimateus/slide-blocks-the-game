extends Control
## A vector icon. It draws one time in a 100 x 100 box scaled to the control, and again only when its look changes.
## Kinds: pause, restart, lock, star, star_empty, speaker, music, vibrate, motion, back, play, grid, knob, touch,
## chevrons_left, jelly_sad, jelly_happy, globe, replay, dice.

const Palette := preload("res://scripts/core/palette.gd")
const UiBake := preload("res://scripts/ui/ui_bake.gd")

const STAR_POINTS := 5
## Room around the 100 x 100 box for strokes that pass its edge, as a share of the icon size.
const BAKE_MARGIN := 0.08

var kind: StringName = &"":
	set(value):
		if kind != value:
			kind = value
			queue_redraw()
var color := Palette.INK:
	set(value):
		if color != value:
			color = value
			queue_redraw()
## Second color: the star fill, the jelly body, the keyhole.
var accent := Palette.STAR:
	set(value):
		if accent != value:
			accent = value
			queue_redraw()
## Draws the icon mirrored left to right. The baked texture is the same, so a mirrored icon costs no new bake.
## A container resets the scale of its children, so a negative scale cannot do this.
var mirrored := false:
	set(value):
		if mirrored != value:
			mirrored = value
			queue_redraw()
## False for the copy that the baker draws in vector form.
var bakeable := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(icon_kind: StringName, px: float, icon_color: Color = Palette.INK, icon_accent: Color = Palette.STAR) -> Control:
	kind = icon_kind
	color = icon_color
	accent = icon_accent
	custom_minimum_size = Vector2(px, px)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	return self


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0


## Asks the baker for the current look, and for the other star look of a star.
func prewarm() -> void:
	_fetch(kind, null)
	if kind == &"star":
		_fetch(&"star_empty", null)
	elif kind == &"star_empty":
		_fetch(&"star", null)


func _fetch(look: StringName, waiter: CanvasItem) -> Texture2D:
	if look == &"" or size.x <= 0.0 or size.y <= 0.0:
		return null
	var key := "icon|%s|%s|%s" % [look, color.to_html(), accent.to_html()]
	return UiBake.fetch(key, _bake_rect(), _make_copy.bind(look), waiter)


func _bake_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(maxf(size.x, size.y) * BAKE_MARGIN)


func _make_copy(look: StringName) -> CanvasItem:
	var copy: Control = get_script().new()
	copy.bakeable = false
	copy.kind = look
	copy.color = color
	copy.accent = accent
	copy.size = size
	return copy


func _draw() -> void:
	var s := minf(size.x, size.y) / 100.0
	if s <= 0.0:
		return
	var flip := Transform2D(Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(size.x, 0.0)) if mirrored else Transform2D.IDENTITY
	if bakeable:
		var tex := _fetch(kind, self)
		if tex != null:
			draw_set_transform_matrix(flip)
			draw_texture_rect(tex, _bake_rect(), false)
			return
	draw_set_transform_matrix(flip * Transform2D(0.0, Vector2(s, s), 0.0, (size - Vector2(100.0, 100.0) * s) / 2.0))
	match kind:
		&"pause":
			_rbox(Rect2(26, 18, 17, 64), 7, color)
			_rbox(Rect2(57, 18, 17, 64), 7, color)
		&"restart":
			_draw_restart()
		&"lock":
			_draw_lock()
		&"star":
			_draw_star(true)
		&"star_empty":
			_draw_star(false)
		&"speaker":
			_poly([Vector2(14, 38), Vector2(32, 38), Vector2(54, 18), Vector2(54, 82), Vector2(32, 62), Vector2(14, 62)], color)
			draw_arc(Vector2(56, 50), 16, -0.9, 0.9, 16, color, 8, true)
			draw_arc(Vector2(56, 50), 31, -0.9, 0.9, 20, color, 8, true)
		&"music":
			_draw_music()
		&"vibrate":
			_rbox(Rect2(32, 14, 36, 72), 9, color)
			_rbox(Rect2(38, 22, 24, 50), 4, accent)
			for x: float in [20.0, 80.0]:
				_round_line(Vector2(x, 36), Vector2(x, 64), 7)
			for x: float in [8.0, 92.0]:
				_round_line(Vector2(x, 42), Vector2(x, 58), 6)
		&"motion":
			draw_circle(Vector2(70, 50), 17, color, true, -1.0, true)
			_round_line(Vector2(16, 33), Vector2(42, 33), 8)
			_round_line(Vector2(8, 50), Vector2(42, 50), 8)
			_round_line(Vector2(16, 67), Vector2(42, 67), 8)
		&"back":
			_round_line(Vector2(56, 22), Vector2(28, 50), 13)
			_round_line(Vector2(28, 50), Vector2(56, 78), 13)
			_round_line(Vector2(30, 50), Vector2(78, 50), 13)
		&"play":
			_poly([Vector2(32, 18), Vector2(82, 50), Vector2(32, 82)], color)
			for p: Vector2 in [Vector2(36, 24), Vector2(76, 50), Vector2(36, 76)]:
				draw_circle(p, 6, color, true, -1.0, true)
		&"grid":
			for r: Rect2 in [Rect2(16, 16, 30, 30), Rect2(54, 16, 30, 30), Rect2(16, 54, 30, 30), Rect2(54, 54, 30, 30)]:
				_rbox(r, 8, color)
		&"knob":
			draw_circle(Vector2(50, 50), 48, Palette.CREAM_LIGHT, true, -1.0, true)
			draw_circle(Vector2(50, 50), 33, color, true, -1.0, true)
		&"touch":
			draw_circle(Vector2(50, 50), 48, Color(color, 0.22), true, -1.0, true)
			draw_circle(Vector2(50, 50), 30, Color(color, 0.85), true, -1.0, true)
			draw_circle(Vector2(50, 50), 30, Palette.CREAM_LIGHT, false, 5.0, true)
		&"chevrons_left":
			for x: float in [30.0, 62.0]:
				_round_line(Vector2(x + 18, 24), Vector2(x - 8, 50), 11)
				_round_line(Vector2(x - 8, 50), Vector2(x + 18, 76), 11)
		&"jelly_sad":
			_draw_jelly(false)
		&"jelly_happy":
			_draw_jelly(true)
		&"globe":
			draw_arc(Vector2(50, 50), 36, 0.0, TAU, 48, color, 7, true)
			_ellipse_outline(Vector2(50, 50), Vector2(16, 36), 6)
			_round_line(Vector2(14, 50), Vector2(86, 50), 6)
		&"replay":
			_draw_restart()
			_poly([Vector2(43, 37), Vector2(43, 63), Vector2(65, 50)], color)
		&"dice":
			var face := Rect2(16, 16, 68, 68)
			_rbox(face.grow(3.5), 19.5, color)
			_rbox(face.grow(-3.5), 12.5, accent)
			for p: Vector2 in [Vector2(34, 34), Vector2(66, 34), Vector2(50, 50), Vector2(34, 66), Vector2(66, 66)]:
				draw_circle(p, 7, color, true, -1.0, true)


func _draw_restart() -> void:
	var c := Vector2(50, 52)
	var r := 29.0
	var start := -PI / 2.0 + 0.45
	var finish := -PI / 2.0 + TAU - 0.55
	draw_arc(c, r, start, finish, 40, color, 12, true)
	draw_circle(c + Vector2(cos(start), sin(start)) * r, 6, color, true, -1.0, true)
	var radial := Vector2(cos(finish), sin(finish))
	var tangent := Vector2(-radial.y, radial.x)
	var p := c + radial * r
	_poly([p + tangent * 17.0, p + radial * 16.0 - tangent * 3.0, p - radial * 16.0 - tangent * 3.0], color)


func _draw_lock() -> void:
	draw_arc(Vector2(50, 42), 17, PI, TAU, 24, color, 10, true)
	_round_line(Vector2(33, 42), Vector2(33, 50), 10)
	_round_line(Vector2(67, 42), Vector2(67, 50), 10)
	_rbox(Rect2(22, 46, 56, 42), 11, color)
	draw_circle(Vector2(50, 62), 6.5, accent, true, -1.0, true)
	_rbox(Rect2(47, 63, 6, 14), 3, accent)


func _star_points(outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var c := Vector2(50, 53)
	for i in STAR_POINTS * 2:
		var a := -PI / 2.0 + i * PI / STAR_POINTS
		var r := outer if i % 2 == 0 else inner
		points.append(c + Vector2(cos(a), sin(a)) * r)
	return points


func _draw_star(filled: bool) -> void:
	if filled:
		_poly(_star_points(49, 25), Palette.STAR_DEEP)
		_poly(_star_points(39, 20), accent)
		draw_arc(Vector2(43, 44), 12, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.7), 4, true)
		return
	var points := _star_points(44, 22)
	draw_colored_polygon(points, Color(color, 0.12))
	points.append(points[0])
	draw_polyline(points, color, 6.0, true)


func _draw_music() -> void:
	draw_circle(Vector2(31, 74), 12, color, true, -1.0, true)
	draw_circle(Vector2(69, 66), 12, color, true, -1.0, true)
	_round_line(Vector2(41, 72), Vector2(41, 26), 8)
	_round_line(Vector2(79, 64), Vector2(79, 18), 8)
	_poly([Vector2(37, 22), Vector2(83, 12), Vector2(83, 28), Vector2(37, 38)], color)


func _draw_jelly(happy: bool) -> void:
	var outline := Palette.OUTLINE[0]
	_rbox(Rect2(8, 16, 84, 78), 30, outline)
	_rbox(Rect2(12, 14, 76, 72), 27, accent)
	draw_arc(Vector2(34, 36), 12, PI * 1.05, PI * 1.5, 10, Color(1, 1, 1, 0.75), 5, true)
	if happy:
		draw_arc(Vector2(37, 50), 7, PI * 1.1, PI * 1.9, 10, Palette.INK, 5, true)
		draw_arc(Vector2(63, 50), 7, PI * 1.1, PI * 1.9, 10, Palette.INK, 5, true)
		draw_arc(Vector2(50, 60), 9, 0.25, PI - 0.25, 12, Palette.INK, 5, true)
		return
	draw_circle(Vector2(37, 52), 6.5, Palette.INK, true, -1.0, true)
	draw_circle(Vector2(63, 52), 6.5, Palette.INK, true, -1.0, true)
	_round_line(Vector2(27, 43), Vector2(40, 37), 4)
	_round_line(Vector2(73, 43), Vector2(60, 37), 4)
	draw_arc(Vector2(50, 76), 9, PI * 1.15, PI * 1.85, 12, Palette.INK, 5, true)


func _rbox(rect: Rect2, radius: float, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 8
	sb.anti_aliasing = true
	draw_style_box(sb, rect)


func _round_line(a: Vector2, b: Vector2, width: float) -> void:
	draw_line(a, b, color, width, true)
	draw_circle(a, width / 2.0, color, true, -1.0, true)
	draw_circle(b, width / 2.0, color, true, -1.0, true)


func _ellipse_outline(center: Vector2, radii: Vector2, width: float) -> void:
	var points := PackedVector2Array()
	var segments := 40
	for i in segments + 1:
		var a := TAU * i / segments
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_polyline(points, color, width, true)


func _poly(points: Variant, c: Color) -> void:
	var list := PackedVector2Array(points)
	draw_colored_polygon(list, c)
	list.append(list[0])
	draw_polyline(list, c, 1.5, true)
