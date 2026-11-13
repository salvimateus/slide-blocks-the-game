extends Node
## Bakes every board visual one time into one atlas texture, then serves regions of it.
## Use: add an instance to the tree, `await bank.bake()`, then call the static getters from any script.
## After a Palette theme change, `await bank.rebake()` draws the atlas again into the same textures,
## so each sprite, region and emitter that holds one shows the new colors with no change.
## The bake draws in a SubViewport, then a second pass turns the premultiplied result into straight alpha.

signal baked

const BoardTuning := preload("res://scripts/board/board_tuning.gd")

const ATLAS_SIZE := BoardTuning.ATLAS_SIZE
const CELL := BoardTuning.ATLAS_CELL
const SMALL := BoardTuning.ATLAS_SMALL
const SMALL_ROW_Y := CELL * 2
const SMALL_PER_ROW := 28
const PATTERN_SIZE := 288
const PATTERN_ORIGIN := Vector2i(0, CELL * 4)

const BIG_ROW_0: Array[StringName] = [
	&"tile_empty", &"tile_paint_0", &"tile_paint_1", &"tile_paint_2", &"tile_paint_3", &"tile_paint_4",
	&"tile_paint_5", &"tile_paint_6", &"tile_paint_7", &"tile_gray", &"tile_mask", &"obstacle", &"rail", &"block_shadow",
]
const BIG_ROW_1: Array[StringName] = [
	&"block_0", &"block_1", &"block_2", &"block_3", &"block_4", &"block_5", &"block_6", &"block_7",
	&"block_mask", &"ring",
]
const SMALL_NAMES: Array[StringName] = [
	&"eye_open", &"eye_squint", &"eye_happy", &"eye_sad", &"sparkle", &"droplet", &"dot", &"confetti",
	&"glitter_0", &"glitter_1", &"glitter_2", &"glitter_3", &"glitter_4", &"glitter_5", &"glitter_6", &"glitter_7",
]
## CPUParticles2D cannot draw an atlas region, so the particle textures also get their own texture.
const STANDALONE: Array[StringName] = [
	&"ring", &"sparkle", &"droplet", &"dot", &"confetti",
	&"glitter_0", &"glitter_1", &"glitter_2", &"glitter_3", &"glitter_4", &"glitter_5", &"glitter_6", &"glitter_7",
]

const UNPREMULTIPLY_SHADER := """
shader_type canvas_item;
render_mode blend_disabled, unshaded;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
"""

static var _atlas: Texture2D
static var _regions := {}
static var _cache := {}
static var _standalone := {}
static var _pattern: Texture2D
static var _soft: Texture2D


static func is_baked() -> bool:
	return _atlas != null


## The AtlasTexture of one named region.
static func tex(key: StringName) -> Texture2D:
	var cached: Texture2D = _cache.get(key)
	if cached != null:
		return cached
	if not _regions.has(key):
		push_error("TextureBank: no region '%s' (bake first)" % key)
		return null
	var region := AtlasTexture.new()
	region.atlas = _atlas
	region.region = Rect2(_regions[key])
	region.filter_clip = true
	_cache[key] = region
	return region


static func paint_tile(hue: int) -> Texture2D:
	return tex(StringName("tile_paint_%d" % hue))


static func block(hue: int) -> Texture2D:
	return tex(StringName("block_%d" % hue))


## A standalone texture for a particle emitter.
static func particle(key: StringName) -> Texture2D:
	var t: Texture2D = _standalone.get(key)
	if t == null:
		push_error("TextureBank: no particle texture '%s' (bake first)" % key)
	return t


static func glitter(hue: int) -> Texture2D:
	return particle(StringName("glitter_%d" % hue))


## The seamless background pattern, for a repeated TextureRect.
static func pattern() -> Texture2D:
	return _pattern


## A soft white radial dot, for glow particles and background blobs.
static func soft() -> Texture2D:
	if _soft == null:
		_soft = _make_soft()
	return _soft


## Draws the atlas one time. In a headless run it stores a white placeholder at once.
func bake() -> void:
	if is_baked():
		return
	await _bake()


## Draws the atlas again in the current Palette colors, into the textures of the first bake.
func rebake() -> void:
	await _bake()


func _bake() -> void:
	if DisplayServer.get_name() == "headless":
		var blank := Image.create(ATLAS_SIZE.x, ATLAS_SIZE.y, false, Image.FORMAT_RGBA8)
		blank.fill(Color.WHITE)
		_store(blank)
		baked.emit()
		return
	var source := _make_viewport()
	var painter := Painter.new()
	painter.layout = _layout()
	source.add_child(painter)
	add_child(source)
	await RenderingServer.frame_post_draw
	var resolve := _make_viewport()
	var view := TextureRect.new()
	view.texture = source.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.size = Vector2(ATLAS_SIZE)
	var shader := Shader.new()
	shader.code = UNPREMULTIPLY_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	view.material = material
	resolve.add_child(view)
	add_child(resolve)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := resolve.get_texture().get_image()
	resolve.queue_free()
	source.queue_free()
	_store(image)
	baked.emit()


func _make_viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = ATLAS_SIZE
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return vp


static func _layout() -> Dictionary:
	var out := {}
	for i in BIG_ROW_0.size():
		out[BIG_ROW_0[i]] = Rect2i(i * CELL, 0, CELL, CELL)
	for i in BIG_ROW_1.size():
		out[BIG_ROW_1[i]] = Rect2i(i * CELL, CELL, CELL, CELL)
	for i in SMALL_NAMES.size():
		out[SMALL_NAMES[i]] = Rect2i((i % SMALL_PER_ROW) * SMALL, SMALL_ROW_Y + floori(i / float(SMALL_PER_ROW)) * SMALL, SMALL, SMALL)
	out[&"pattern"] = Rect2i(PATTERN_ORIGIN, Vector2i(PATTERN_SIZE, PATTERN_SIZE))
	return out


## The first store makes the textures. A later store writes into them, because nodes and regions hold them.
static func _store(image: Image) -> void:
	var again := _atlas != null
	if not again:
		_regions = _layout()
		_cache.clear()
		_standalone.clear()
	if image.has_mipmaps():
		image.clear_mipmaps()
	image.fix_alpha_edges()
	for key in STANDALONE:
		var part := image.get_region(_regions[key])
		part.generate_mipmaps()
		if again:
			(_standalone[key] as ImageTexture).update(part)
		else:
			_standalone[key] = ImageTexture.create_from_image(part)
	var pattern_image := image.get_region(_regions[&"pattern"])
	if again:
		(_pattern as ImageTexture).update(pattern_image)
	else:
		_pattern = ImageTexture.create_from_image(pattern_image)
	image.generate_mipmaps()
	if again:
		(_atlas as ImageTexture).update(image)
	else:
		_atlas = ImageTexture.create_from_image(image)


static func _make_soft() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = gradient
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## Draws each region of the atlas in one boot-time _draw call.
class Painter extends Node2D:
	const BT := preload("res://scripts/board/board_tuning.gd")
	const Pal := preload("res://scripts/core/palette.gd")

	var layout: Dictionary
	var _boxes: Array[StyleBoxFlat] = []

	func _draw() -> void:
		for key: StringName in layout:
			_paint(String(key), Rect2(layout[key]))

	func _paint(key: String, r: Rect2) -> void:
		var c := r.get_center()
		if key == "tile_empty":
			_tile_empty(c)
		elif key.begins_with("tile_paint_"):
			var h := key.trim_prefix("tile_paint_").to_int()
			_tile_raised(c, Pal.PAINT[h], Pal.OUTLINE[h], 0.85)
		elif key == "tile_gray":
			_tile_raised(c, Pal.GRAY_TILE, Pal.GRAY_TILE.darkened(0.24), 0.3)
		elif key == "tile_mask":
			_rrect(_raised_rect(c), BT.TILE_RADIUS, Color.WHITE)
		elif key == "obstacle":
			_obstacle(c)
		elif key == "rail":
			_rail(c)
		elif key == "block_shadow":
			for i in 5:
				_ellipse(c, 54.0 - i * 5.0, 15.0 - i * 2.0, Color(Pal.SHADE, 0.065))
		elif key.begins_with("block_") and key != "block_mask":
			_block(c, key.trim_prefix("block_").to_int())
		elif key == "block_mask":
			_rrect(Rect2(c - BT.BLOCK_SIZE * 0.5, BT.BLOCK_SIZE), 40.0, Color.WHITE)
		elif key == "ring":
			draw_arc(c, 56.0, 0.0, TAU, 72, Color.WHITE, 7.0, true)
			draw_arc(c, 61.0, 0.0, TAU, 72, Color(Pal.SHADE, 0.25), 2.5, true)
		elif key.begins_with("eye_"):
			_eye(c, key)
		elif key == "sparkle":
			_halo_star(c, 20.0, 4.5, 4, 0.0, Color.WHITE)
			draw_circle(c, 4.0, Color.WHITE, true, -1.0, true)
		elif key == "droplet":
			draw_circle(c, 13.0, Color(0.78, 0.78, 0.78), true, -1.0, true)
			draw_circle(c + Vector2(0, -1), 10.5, Color(0.93, 0.93, 0.93), true, -1.0, true)
			draw_circle(c + Vector2(-4, -5), 3.4, Color.WHITE, true, -1.0, true)
		elif key == "dot":
			for ring in [[29.0, 0.12], [26.0, 0.25], [23.0, 0.5], [20.0, 1.0]]:
				draw_circle(c, ring[0], Color(1, 1, 1, ring[1]), true, -1.0, true)
		elif key == "confetti":
			_rrect(Rect2(c - Vector2(11, 6), Vector2(22, 12)), 4.0, Color.WHITE)
			_rrect(Rect2(c + Vector2(-11, 0), Vector2(22, 6)), 3.0, Color(0.82, 0.82, 0.82))
		elif key.begins_with("glitter_"):
			_glitter(c, key.trim_prefix("glitter_").to_int())
		elif key == "pattern":
			_pattern(r.position)

	# --- Shapes ---

	func _rrect(rect: Rect2, radius: float, color: Color) -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(roundi(radius))
		box.corner_detail = 16
		box.anti_aliasing = true
		box.anti_aliasing_size = 1.0
		_boxes.append(box)
		box.draw(get_canvas_item(), rect)

	func _fill(points: PackedVector2Array, color: Color) -> void:
		draw_colored_polygon(points, color)
		var loop := points.duplicate()
		loop.append(points[0])
		draw_polyline(loop, color, 1.0, true)

	func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
		_fill(_ellipse_points(c, rx, ry), color)

	func _ellipse_points(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		return pts

	func _star_points(c: Vector2, r_out: float, r_in: float, points: int, rot: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in points * 2:
			var a := rot + PI * i / points
			var radius := r_out if i % 2 == 0 else r_in
			pts.append(c + Vector2(cos(a), sin(a)) * radius)
		return pts

	func _halo_star(c: Vector2, r_out: float, r_in: float, points: int, rot: float, color: Color) -> void:
		for step in [[1.55, 0.05], [1.32, 0.08], [1.14, 0.12]]:
			_fill(_star_points(c, r_out * step[0], r_in * step[0], points, rot), Color(Pal.SHADE, step[1]))
		_fill(_star_points(c, r_out, r_in, points, rot), color)

	func _round_line(points: PackedVector2Array, color: Color, width: float) -> void:
		draw_polyline(points, color, width, true)
		for p in points:
			draw_circle(p, width * 0.5, color, true, -1.0, true)

	func _round_arc(c: Vector2, radius: float, a0: float, a1: float, width: float, color: Color) -> void:
		draw_arc(c, radius, a0, a1, 24, color, width, true)
		draw_circle(c + Vector2(cos(a0), sin(a0)) * radius, width * 0.5, color, true, -1.0, true)
		draw_circle(c + Vector2(cos(a1), sin(a1)) * radius, width * 0.5, color, true, -1.0, true)

	# --- Tiles and tray parts ---

	func _raised_rect(c: Vector2) -> Rect2:
		var half := BT.TILE * 0.5
		return Rect2(c.x - half, c.y - half - BT.TILE_RAISE, BT.TILE, BT.TILE + BT.TILE_RAISE)

	func _tile_empty(c: Vector2) -> void:
		var half := BT.TILE * 0.5
		var r := Rect2(c.x - half, c.y - half, BT.TILE, BT.TILE)
		_rrect(r, BT.TILE_RADIUS, Pal.FLOOR_SHADOW)
		_rrect(Rect2(r.position + Vector2(3, 8), r.size - Vector2(6, 11)), BT.TILE_RADIUS - 3.0, Pal.MINT)
		draw_circle(c + Vector2(0, 2), 12.5, Pal.FLOOR_DIMPLE, true, -1.0, true)
		draw_circle(c + Vector2(0, 4.5), 10.5, Pal.MINT.lerp(Pal.FLOOR_DIMPLE, 0.35), true, -1.0, true)

	func _tile_raised(c: Vector2, face_color: Color, lip_color: Color, gloss_alpha: float) -> void:
		var lip := _raised_rect(c)
		var face := Rect2(lip.position, Vector2(BT.TILE, BT.TILE - BT.TILE_RAISE))
		_rrect(lip, BT.TILE_RADIUS, lip_color)
		_rrect(face, BT.TILE_RADIUS, face_color)
		_rrect(Rect2(face.position + Vector2(7, 6), Vector2(BT.TILE - 14.0, BT.TILE * 0.4)), BT.TILE_RADIUS - 6.0, Color(1, 1, 1, 0.12))
		var gloss := Color(1, 1, 1, gloss_alpha)
		_round_arc(face.position + Vector2(25, 25), 14.0, deg_to_rad(190), deg_to_rad(258), 5.0, gloss)
		draw_circle(face.position + Vector2(47, 11.5), 3.0, gloss, true, -1.0, true)

	## An obstacle is a raised block of the tray wall: a deep periwinkle top on a darker side, darker than every
	## paint color and block body, so it never reads as a tile.
	func _obstacle(c: Vector2) -> void:
		var w := BT.PITCH + 8.0
		var x := c.x - w * 0.5
		var top_y := c.y - 70.0
		_rrect(Rect2(x + 2.0, c.y - 56.0, w - 4.0, 127.0), 20.0, Color(Pal.SHADE, 0.22))
		_rrect(Rect2(x, top_y, w, 136.0), 20.0, Pal.OBSTACLE_SIDE)
		_rrect(Rect2(x, top_y, w, 116.0), 20.0, Pal.OBSTACLE_EDGE)
		_rrect(Rect2(x + 3.0, top_y + 4.0, w - 6.0, 109.0), 17.0, Pal.OBSTACLE_TOP)
		_rrect(Rect2(x + 14.0, top_y + 12.0, w - 28.0, 12.0), 6.0, Color(Pal.OBSTACLE_EDGE, 0.55))
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var p: Vector2 = c + Vector2(0, -10) + corner * Vector2(30.0, 24.0)
			draw_circle(p, 6.5, Pal.OBSTACLE_SIDE, true, -1.0, true)
			draw_circle(p + Vector2(-1.5, -1.5), 3.0, Color(Pal.OBSTACLE_EDGE, 0.8), true, -1.0, true)

	## The rail of a NW deflector: a fillet in the closed corner, along the arc that the blocks follow.
	func _rail(c: Vector2) -> void:
		var center := c + Vector2(BT.PITCH, BT.PITCH) * 0.5
		var radius := BT.PITCH * 0.5 + 54.0
		var edge := BT.PITCH * 0.5 + 3.0
		var pts := PackedVector2Array()
		for i in 33:
			var a := lerpf(PI, PI * 1.5, i / 32.0)
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		pts.append(Vector2(center.x, c.y - edge))
		pts.append(Vector2(c.x - edge, c.y - edge))
		pts.append(Vector2(c.x - edge, center.y))
		draw_arc(center, radius - 3.0, PI, PI * 1.5, 40, Color(Pal.SHADE, 0.14), 8.0, true)
		draw_arc(center, radius - 7.0, PI, PI * 1.5, 40, Color(Pal.SHADE, 0.06), 6.0, true)
		_fill(pts, Pal.CREAM_LIGHT)
		draw_arc(center, radius + 2.0, PI, PI * 1.5, 40, Pal.CREAM_SHADOW, 5.0, true)
		draw_arc(center, radius + 10.0, PI, PI * 1.5, 40, Pal.CORAL, 8.0, true)
		draw_arc(center, radius + 11.0, PI * 1.03, PI * 1.47, 40, Color(1, 1, 1, 0.5), 2.5, true)
		for a in [PI * 1.18, PI * 1.25, PI * 1.32]:
			var rr := radius + (30.0 if is_equal_approx(a, PI * 1.25) else 24.0)
			draw_circle(center + Vector2(cos(a), sin(a)) * rr, 5.0, Color(Pal.CORAL, 0.85), true, -1.0, true)

	# --- Blocks and eyes ---

	func _block(c: Vector2, h: int) -> void:
		var size := BT.BLOCK_SIZE
		var body := Rect2(c - size * 0.5, size)
		_rrect(body, 40.0, Pal.OUTLINE[h])
		_rrect(body.grow(-5.0), 35.0, Pal.BODY[h])
		_rrect(Rect2(body.position + Vector2(10, size.y * 0.62), Vector2(size.x - 20.0, size.y * 0.3)), 24.0, Color(Pal.OUTLINE[h], 0.2))
		_rrect(Rect2(body.position + Vector2(12, 10), Vector2(size.x - 24.0, size.y * 0.46)), 28.0, Color(Pal.PAINT[h], 0.5))
		var shine := Color(1, 1, 1, 0.92)
		_round_arc(body.position + Vector2(36, 36), 21.0, deg_to_rad(198), deg_to_rad(248), 7.5, shine)
		draw_circle(body.position + Vector2(62, 15.5), 4.5, shine, true, -1.0, true)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 10:
			var p := c + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
			if absf(p.y - c.y + 5.0) < 16.0 and absf(absf(p.x - c.x) - 21.0) < 14.0:
				continue
			draw_circle(p, rng.randf_range(1.4, 2.2), Color(1, 1, 1, 0.45), true, -1.0, true)
		var blush := Color("#FF8FA3", 0.42)
		_ellipse(c + Vector2(-32, 14), 9.0, 5.0, blush)
		_ellipse(c + Vector2(32, 14), 9.0, 5.0, blush)

	func _eye(c: Vector2, key: String) -> void:
		var ink := Pal.SHADE
		match key:
			"eye_open":
				_ellipse(c, 9.5, 12.5, ink)
				draw_circle(c + Vector2(3.4, -5.0), 3.4, Color.WHITE, true, -1.0, true)
				draw_circle(c + Vector2(-2.6, 4.6), 1.6, Color(1, 1, 1, 0.7), true, -1.0, true)
			"eye_squint":
				_round_line(PackedVector2Array([c + Vector2(-7, -9), c + Vector2(7, 0), c + Vector2(-7, 9)]), ink, 5.5)
			"eye_happy":
				_round_arc(c + Vector2(0, 6), 10.0, deg_to_rad(200), deg_to_rad(340), 5.5, ink)
			"eye_sad":
				var lid := PackedVector2Array([c + Vector2(-20, 1.7), c + Vector2(20, -11.7), c + Vector2(20, 24), c + Vector2(-20, 24)])
				for part in Geometry2D.intersect_polygons(_ellipse_points(c + Vector2(0, 2), 9.5, 12.0), lid):
					_fill(part, ink)
				draw_circle(c + Vector2(2.5, 4.0), 2.4, Color.WHITE, true, -1.0, true)
				_round_line(PackedVector2Array([c + Vector2(-10, -14), c + Vector2(9, -19)]), ink, 3.5)

	func _glitter(c: Vector2, h: int) -> void:
		_halo_star(c, 19.0, 8.5, 5, -PI * 0.5, Pal.BODY[h])
		_fill(_star_points(c, 9.0, 3.8, 5, -PI * 0.5), Color.WHITE)

	# --- Background pattern: nothing crosses the edges, so the tile repeats with no seam ---

	func _pattern(o: Vector2) -> void:
		_bean(o + Vector2(70, 62), 0.5, Color(Pal.CREAM_SHADOW, 0.6))
		_bean(o + Vector2(160, 200), -0.4, Color(Pal.CORAL, 0.15))
		_bean(o + Vector2(236, 92), 1.3, Color(Pal.PERIWINKLE, 0.16))
		draw_circle(o + Vector2(186, 50), 7.0, Color(Pal.MINT.darkened(0.04), 0.95), true, -1.0, true)
		draw_circle(o + Vector2(46, 186), 5.0, Color(Pal.CREAM_SHADOW, 0.7), true, -1.0, true)
		draw_circle(o + Vector2(252, 252), 4.0, Color(Pal.PERIWINKLE, 0.22), true, -1.0, true)
		draw_circle(o + Vector2(108, 132), 3.5, Color(Pal.CORAL, 0.2), true, -1.0, true)
		_fill(_star_points(o + Vector2(232, 168), 12.0, 3.2, 4, 0.0), Color(Pal.PERIWINKLE, 0.24))
		_fill(_star_points(o + Vector2(60, 250), 9.0, 2.6, 4, 0.3), Color(Pal.CREAM_SHADOW, 0.75))
		_fill(_star_points(o + Vector2(126, 34), 7.0, 2.2, 4, 0.0), Color(Pal.CORAL, 0.2))

	func _bean(c: Vector2, angle: float, color: Color) -> void:
		draw_set_transform(c, angle)
		_rrect(Rect2(-19, -11, 38, 22), 11.0, color)
		draw_set_transform(Vector2.ZERO)
