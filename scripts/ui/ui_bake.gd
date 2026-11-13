extends Node
## Bakes vector UI art (icons, level thumbnails, title letters) into shared atlas textures at the pixel scale
## of the screen. A baked item draws as one textured rect, so neighbor items of one atlas batch into one
## draw call. Game adds one baker at boot. Without a baker (headless runs, labs), each item keeps its vector
## drawing. The bake draws in a SubViewport, then a second pass turns the premultiplied result into straight alpha.

const ATLAS_WIDTH := 2048
const ATLAS_MAX_HEIGHT := 2048
const GAP := 2

const UNPREMULTIPLY_SHADER := """
shader_type canvas_item;
render_mode blend_disabled, unshaded;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
"""

static var _active: Node = null
static var _cache := {}
static var _pending := {}
## Jobs of the batch that bakes now. A fetch of one of them joins it, so a look never bakes twice.
static var _in_flight := {}
static var _busy := false


## A Control that shows the baked look of its parent Label and hides the parent text once the bake is ready.
class LabelFace extends Control:
	const Bake := preload("res://scripts/ui/ui_bake.gd")

	var _label: Label
	var _margin := 0.0

	func _init(label: Label) -> void:
		_label = label
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shadow := Vector2(_label.get_theme_constant("shadow_offset_x"), _label.get_theme_constant("shadow_offset_y"))
		_margin = _label.get_theme_constant("outline_size") + absf(shadow.x) + absf(shadow.y) + 4.0
		_label.resized.connect(queue_redraw)

	func _draw() -> void:
		var area := Rect2(Vector2.ZERO, _label.size)
		if area.size.x <= 0.0 or area.size.y <= 0.0:
			return
		var rect := area.grow(_margin)
		var tex := Bake.fetch(_key(), rect, _make, self)
		_label.visible_characters = 0 if tex != null else -1
		if tex != null:
			draw_texture_rect(tex, rect, false)

	func _key() -> String:
		var font := _label.get_theme_font("font")
		return "label|%s|%d|%d|%s|%s|%s|%d|%s" % [
			_label.text, font.get_instance_id(), _label.get_theme_font_size("font_size"),
			_label.get_theme_color("font_color").to_html(), _label.get_theme_color("font_outline_color").to_html(),
			_label.get_theme_color("font_shadow_color").to_html(), _label.get_theme_constant("outline_size"),
			str(Vector2(_label.get_theme_constant("shadow_offset_x"), _label.get_theme_constant("shadow_offset_y")))]

	func _make() -> CanvasItem:
		var copy: Label = _label.duplicate(0)
		for child in copy.get_children():
			child.free()
		copy.set_anchors_preset(Control.PRESET_TOP_LEFT)
		copy.position = Vector2.ZERO
		copy.size = _label.size
		copy.scale = Vector2.ONE
		copy.rotation = 0.0
		copy.modulate = Color.WHITE
		copy.self_modulate = Color.WHITE
		copy.visible = true
		copy.visible_characters = -1
		return copy


## A rounded box of fixed size, drawn from the baker atlas once baked, so it batches with icons.
class BoxFace extends Control:
	const Bake := preload("res://scripts/ui/ui_bake.gd")

	var box: StyleBoxFlat
	## False for the copy that the baker draws in vector form.
	var bakeable := true

	func _init(p_box: StyleBoxFlat) -> void:
		box = p_box
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func prewarm() -> void:
		_fetch(null)

	func _rect() -> Rect2:
		var margin := box.shadow_size + absf(box.shadow_offset.x) + absf(box.shadow_offset.y) + 2.0
		return Rect2(Vector2.ZERO, size).grow(margin)

	func _fetch(waiter: CanvasItem) -> Texture2D:
		if size.x <= 0.0 or size.y <= 0.0:
			return null
		return Bake.fetch("box|%d" % box.get_instance_id(), _rect(), _make, waiter)

	func _make() -> CanvasItem:
		var copy: Control = get_script().new(box)
		copy.bakeable = false
		copy.size = size
		return copy

	func _draw() -> void:
		if bakeable:
			var tex := _fetch(self)
			if tex != null:
				draw_texture_rect(tex, _rect(), false)
				return
		draw_style_box(box, Rect2(Vector2.ZERO, size))


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() != "headless":
		_active = self


func _exit_tree() -> void:
	if _active == self:
		_active = null


func _process(_delta: float) -> void:
	if not _busy and not _pending.is_empty():
		_bake_batch()


## True when no bake waits or runs.
static func is_idle() -> bool:
	return _active == null or (not _busy and _pending.is_empty())


## Drops every baked look, for example after a Palette theme change. The next draw of each item asks for a new bake.
## Call it only when is_idle() is true: a batch that bakes during the call stores its looks after the clear.
static func clear() -> void:
	_cache.clear()
	_pending.clear()


## Shows the baked look of `label` (text, outline and shadow) as one textured rect.
static func flatten_label(label: Label) -> void:
	label.add_child(LabelFace.new(label))


## The baked texture of `key`, or null while it is not baked. `rect` is the drawing area in local base units;
## it can extend past the item for outlines. `make` returns a new CanvasItem that draws the art in vector form
## with its origin at the item origin. `waiter`, when given, gets queue_redraw() when the texture is ready.
## `max_scale`, when above 0, caps the bake pixel scale of this item, so large art leaves room in the atlas.
static func fetch(key: String, rect: Rect2, make: Callable, waiter: CanvasItem = null, max_scale := 0.0) -> Texture2D:
	if _active == null:
		return null
	# Layout and tweens leave float noise in sizes: the key uses quarter units.
	var grid := Vector2(0.25, 0.25)
	var s := pixel_scale() if max_scale <= 0.0 else minf(pixel_scale(), max_scale)
	var full := "%s@%.3f|%s|%s" % [key, s, str(rect.position.snapped(grid)), str(rect.size.snapped(grid))]
	var tex: Texture2D = _cache.get(full)
	if tex != null:
		return tex
	var job: Dictionary = _pending.get(full, _in_flight.get(full, {}))
	if job.is_empty():
		job = {"make": make, "rect": rect, "scale": s, "waiters": []}
		_pending[full] = job
	if waiter != null:
		job.waiters.append(weakref(waiter))
	return null


## Screen pixels for one base unit.
static func pixel_scale() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	return maxf(tree.root.get_final_transform().get_scale().x, 0.01)


func _bake_batch() -> void:
	_busy = true
	var jobs: Array = []
	var x := 0
	var y := 0
	var row := 0
	var width := 0
	for key: String in _pending.keys():
		var job: Dictionary = _pending[key]
		# The item that asked for this look is gone: drop the job.
		if not (job.make as Callable).is_valid():
			_pending.erase(key)
			continue
		var px := Vector2i((job.rect.size * job.scale).ceil()) + Vector2i(GAP, GAP)
		if x > 0 and x + px.x > ATLAS_WIDTH:
			x = 0
			y += row
			row = 0
		if y + px.y > ATLAS_MAX_HEIGHT:
			break
		job["slot"] = Vector2i(x, y)
		job["key"] = key
		jobs.append(job)
		x += px.x
		width = maxi(width, x)
		row = maxi(row, px.y)
	for job: Dictionary in jobs:
		_pending.erase(job.key)
		_in_flight[job.key] = job
	if jobs.is_empty():
		_busy = false
		return
	var atlas_size := Vector2i(maxi(width, 1), maxi(y + row, 1))

	var source := _viewport(atlas_size)
	for job: Dictionary in jobs:
		var holder := Node2D.new()
		holder.scale = Vector2(job.scale, job.scale)
		holder.position = Vector2(job.slot) - job.rect.position * job.scale
		holder.add_child(job.make.call())
		source.add_child(holder)
	add_child(source)
	await RenderingServer.frame_post_draw
	var resolve := _viewport(atlas_size)
	var view := TextureRect.new()
	view.texture = source.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.size = Vector2(atlas_size)
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
	# Transparent texels take the color of their neighbors, so linear filtering adds no dark fringe.
	image.fix_alpha_edges()
	var atlas := ImageTexture.create_from_image(image)
	for job: Dictionary in jobs:
		var region := AtlasTexture.new()
		region.atlas = atlas
		region.region = Rect2(Vector2(job.slot), job.rect.size * job.scale)
		region.filter_clip = true
		_cache[job.key] = region
		_in_flight.erase(job.key)
		for ref: WeakRef in job.waiters:
			var item := ref.get_ref() as CanvasItem
			if item != null:
				item.queue_redraw()
	_busy = false


func _viewport(atlas_size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = atlas_size
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return vp
