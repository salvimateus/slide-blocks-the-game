extends Control
## An on/off switch: a pill track and a knob that springs to its side. It only shows the state; the row handles taps.
## Off is a hollow gray pill with a gray knob and a ring; on is a filled violet pill with a light knob and a bar.
## The glyph sits in the empty half, so the state reads without color. set_glyphs() puts icons there instead.

const Palette := preload("res://scripts/core/palette.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiTuning := preload("res://scripts/ui/ui_tuning.gd")
const UiBake := preload("res://scripts/ui/ui_bake.gd")
const Icon := preload("res://scripts/ui/icon.gd")

const TRACK_SIZE := Vector2(96, 56)
const KNOB_INSET := 6.0
const EDGE := 3
const GLYPH_SIZE := 18.0
const ICON_SIZE := 26.0

var on := false

## The parts that show only when on; their alpha follows the state.
var _on_parts: Array[Control] = []
## The parts that show only when off.
var _off_parts: Array[Control] = []
var _glyph_on: Control
var _glyph_off: Control
var _knob: Control
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = TRACK_SIZE
	var radius := int(TRACK_SIZE.y / 2.0)
	# Baked boxes: the parts batch with the icons around them.
	var track_off := _part(UiTheme.box(Palette.SWITCH_OFF, radius, Palette.SWITCH_OFF_EDGE, EDGE), TRACK_SIZE)
	var track_on := _part(UiTheme.box(Palette.SWITCH_ON, radius, Palette.SWITCH_ON_EDGE, EDGE), TRACK_SIZE)
	add_child(track_off)
	add_child(track_on)
	_on_parts.append(track_on)
	# The glyphs: a bar in the left half for on, a ring in the right half for off.
	_glyph_on = _part(UiTheme.box(Palette.KNOB, 2), Vector2(EDGE + 1, GLYPH_SIZE))
	_glyph_off = _part(UiTheme.box(Color(Palette.SWITCH_OFF, 0.0), int(GLYPH_SIZE / 2.0), Palette.SWITCH_OFF_EDGE, EDGE),
		Vector2(GLYPH_SIZE, GLYPH_SIZE))
	_place_glyphs()
	var knob_size := TRACK_SIZE.y - KNOB_INSET * 2.0
	_knob = Control.new()
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob.size = Vector2(knob_size, knob_size)
	_knob.pivot_offset = _knob.size / 2.0
	add_child(_knob)
	var knob_off := _part(UiTheme.box(Palette.SWITCH_OFF_EDGE, int(knob_size / 2.0)), _knob.size)
	var knob_box := UiTheme.box(Palette.KNOB, int(knob_size / 2.0))
	knob_box.shadow_color = Color(Palette.SHADE, 0.25)
	knob_box.shadow_size = 3
	knob_box.shadow_offset = Vector2(0, 2)
	var knob_on := _part(knob_box, _knob.size)
	_knob.add_child(knob_off)
	_knob.add_child(knob_on)
	_on_parts.append(knob_on)
	set_on(false, false)


## Shows icons of `on_kind` and `off_kind` in place of the bar and the ring.
func set_glyphs(on_kind: StringName, off_kind: StringName) -> void:
	_glyph_on.queue_free()
	_glyph_off.queue_free()
	_glyph_on = Icon.new().setup(on_kind, ICON_SIZE, Palette.KNOB, Palette.KNOB)
	_glyph_off = Icon.new().setup(off_kind, ICON_SIZE, Palette.SWITCH_OFF_EDGE, Palette.SWITCH_OFF_EDGE)
	_place_glyphs()
	set_on(on, false)


func set_on(value: bool, animate: bool) -> void:
	on = value
	var knob_x := TRACK_SIZE.x - KNOB_INSET - _knob.size.x if on else KNOB_INSET
	var alpha := 1.0 if on else 0.0
	if _tween:
		_tween.kill()
	if not animate:
		_knob.position = Vector2(knob_x, KNOB_INSET)
		_set_alpha(alpha)
		return
	_tween = create_tween().set_parallel()
	_tween.tween_property(_knob, "position:x", knob_x, UiTuning.SWITCH_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for p in _on_parts:
		_tween.tween_property(p, "modulate:a", alpha, UiTuning.SWITCH_TIME * 0.7)
	for p in _off_parts:
		_tween.tween_property(p, "modulate:a", 1.0 - alpha, UiTuning.SWITCH_TIME * 0.7)
	var squash := 1.0 + 0.25 * Feel.motion()
	_knob.scale = Vector2(squash, 1.0 / squash)
	_tween.tween_property(_knob, "scale", Vector2.ONE, UiTuning.SWITCH_TIME * 1.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _part(sb: StyleBoxFlat, part_size: Vector2) -> Control:
	var face := UiBake.BoxFace.new(sb)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = part_size
	return face


## Centers each glyph in the half that the knob leaves empty, below the knob.
func _place_glyphs() -> void:
	var knob_size := TRACK_SIZE.y - KNOB_INSET * 2.0
	var free_width := TRACK_SIZE.x - KNOB_INSET * 2.0 - knob_size
	for g: Control in [_glyph_on, _glyph_off]:
		var center_x := KNOB_INSET + free_width / 2.0
		if g == _glyph_off:
			center_x += knob_size
		g.position = Vector2(center_x, TRACK_SIZE.y / 2.0) - g.size / 2.0
		add_child(g)
		if _knob:
			move_child(g, _knob.get_index())
	_on_parts = _on_parts.filter(func(p: Control) -> bool: return is_instance_valid(p) and not p.is_queued_for_deletion())
	_off_parts.clear()
	_on_parts.append(_glyph_on)
	_off_parts.append(_glyph_off)


func _set_alpha(alpha: float) -> void:
	for p in _on_parts:
		p.modulate.a = alpha
	for p in _off_parts:
		p.modulate.a = 1.0 - alpha
