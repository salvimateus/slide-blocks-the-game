extends Control
## The app background behind the board: cream, a slow diagonal drift of soft candy shapes and a few breathing blobs.
## Add it after the TextureBank bake (the pattern comes from the atlas). Only native tweens animate it.

const Palette := preload("res://scripts/core/palette.gd")
const TextureBank := preload("res://scripts/board/texture_bank.gd")

const DRIFT_TIME := 48.0               # seconds for the pattern to move one tile

## The default for new instances. The performance panel sets it with `set_decor_enabled`.
static var decor_enabled := true

var _decor: Control
var _blobs_spec: Array = blob_specs()
var _pattern: TextureRect
var _blobs: Array[TextureRect] = []
var _tweens: Array[Tween] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Palette.CREAM
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	_decor = Control.new()
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_decor.clip_contents = true
	add_child(_decor)
	var tinted := _tinted_blobs()
	for i in _blobs_spec.size():
		var spec: Array = _blobs_spec[i]
		var blob := TextureRect.new()
		blob.texture = tinted[i]
		blob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		blob.stretch_mode = TextureRect.STRETCH_SCALE
		blob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blob.size = Vector2.ONE * float(spec[1])
		blob.pivot_offset = blob.size * 0.5
		_decor.add_child(blob)
		_blobs.append(blob)
	if TextureBank.pattern() != null:
		_pattern = TextureRect.new()
		_pattern.texture = TextureBank.pattern()
		_pattern.stretch_mode = TextureRect.STRETCH_TILE
		_pattern.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_pattern.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_decor.add_child(_pattern)
	resized.connect(_layout)
	_layout()
	set_decor_enabled(decor_enabled)


## [center as a share of the size, diameter in base units, color, breath period] of each blob,
## in the colors of the current Palette theme.
static func blob_specs() -> Array:
	return [
		[Vector2(0.12, 0.16), 520.0, Color(Palette.MINT, 0.75), 9.0],
		[Vector2(0.92, 0.38), 460.0, Color(Palette.PERIWINKLE, 0.13), 11.0],
		[Vector2(0.18, 0.78), 480.0, Color(Palette.CORAL, 0.09), 13.0],
		[Vector2(0.86, 0.92), 540.0, Color(Palette.MINT, 0.6), 10.0],
	]


## Shows or hides the decoration. The cream stays. Hidden decoration runs no tween.
func set_decor_enabled(on: bool) -> void:
	decor_enabled = on
	if _decor == null:
		return
	_decor.visible = on
	for tw in _tweens:
		if on:
			tw.play()
		else:
			tw.pause()


## One texture with the soft dot in the color of each blob. The blobs keep a white modulate,
## so they draw in one batch; a different modulate on each blob breaks the batch.
func _tinted_blobs() -> Array[Texture2D]:
	var source := TextureBank.soft().get_image()
	source.convert(Image.FORMAT_RGBA8)
	var w := source.get_width()
	var h := source.get_height()
	var sheet := Image.create(w * _blobs_spec.size(), h, false, Image.FORMAT_RGBA8)
	for i in _blobs_spec.size():
		var tint: Color = _blobs_spec[i][2]
		for y in h:
			for x in w:
				sheet.set_pixel(i * w + x, y, source.get_pixel(x, y) * tint)
	var atlas := ImageTexture.create_from_image(sheet)
	var out: Array[Texture2D] = []
	for i in _blobs_spec.size():
		var region := AtlasTexture.new()
		region.atlas = atlas
		region.region = Rect2(i * w, 0, w, h)
		region.filter_clip = true
		out.append(region)
	return out


func _layout() -> void:
	for tw in _tweens:
		tw.kill()
	_tweens.clear()
	var area := size if size.x > 0.0 else get_viewport_rect().size
	for i in _blobs.size():
		var blob := _blobs[i]
		var spec: Array = _blobs_spec[i]
		var center: Vector2 = area * (spec[0] as Vector2)
		blob.position = center - blob.size * 0.5
		var period: float = spec[3]
		var tw := create_tween().set_loops()
		tw.tween_property(blob, "scale", Vector2.ONE * 1.12, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(blob, "position", blob.position + Vector2(18, -14), period * 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(blob, "scale", Vector2.ONE, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(blob, "position", blob.position, period * 0.5).set_trans(Tween.TRANS_SINE)
		_tweens.append(tw)
	if _pattern != null:
		var tile := _pattern.texture.get_size()
		_pattern.size = area + tile
		var tw := create_tween().set_loops()
		tw.tween_property(_pattern, "position", -tile, DRIFT_TIME).from(Vector2.ZERO)
		_tweens.append(tw)
	if not decor_enabled:
		for tw in _tweens:
			tw.pause()
