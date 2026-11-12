extends Control
## An on/off switch: a pill track and a knob that springs to its side. It only shows the state; the row handles taps.

const Palette := preload("res://scripts/core/palette.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiTuning := preload("res://scripts/ui/ui_tuning.gd")

const TRACK_SIZE := Vector2(96, 56)
const KNOB_INSET := 6.0

var on := false

var _track_on: Panel
var _knob: Panel
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = TRACK_SIZE
	var radius := int(TRACK_SIZE.y / 2.0)
	var track_off := Panel.new()
	track_off.add_theme_stylebox_override("panel", UiTheme.box(Palette.FLOOR_SHADOW, radius))
	_track_on = Panel.new()
	_track_on.add_theme_stylebox_override("panel", UiTheme.box(Palette.PERIWINKLE, radius, Palette.TRAY_SHADOW, 3))
	_knob = Panel.new()
	var knob_size := TRACK_SIZE.y - KNOB_INSET * 2.0
	var knob_box := UiTheme.box(Palette.CREAM_LIGHT, int(knob_size / 2.0))
	knob_box.shadow_color = Color(Palette.INK, 0.25)
	knob_box.shadow_size = 3
	knob_box.shadow_offset = Vector2(0, 2)
	_knob.add_theme_stylebox_override("panel", knob_box)
	_knob.size = Vector2(knob_size, knob_size)
	_knob.pivot_offset = _knob.size / 2.0
	for p: Panel in [track_off, _track_on]:
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.size = TRACK_SIZE
		add_child(p)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_knob)
	set_on(false, false)


func set_on(value: bool, animate: bool) -> void:
	on = value
	var knob_x := TRACK_SIZE.x - KNOB_INSET - _knob.size.x if on else KNOB_INSET
	var alpha := 1.0 if on else 0.0
	if _tween:
		_tween.kill()
	if not animate:
		_knob.position = Vector2(knob_x, KNOB_INSET)
		_track_on.modulate.a = alpha
		return
	_tween = create_tween().set_parallel()
	_tween.tween_property(_knob, "position:x", knob_x, UiTuning.SWITCH_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_track_on, "modulate:a", alpha, UiTuning.SWITCH_TIME * 0.7)
	var squash := 1.0 + 0.25 * Feel.motion()
	_knob.scale = Vector2(squash, 1.0 / squash)
	_tween.tween_property(_knob, "scale", Vector2.ONE, UiTuning.SWITCH_TIME * 1.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
