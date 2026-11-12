extends Control
## Base of each UI screen: a full-screen Control that fades and slides in on open() and out on close().
## A screen builds its children in _init. Subclasses fill `_fill(data)` and can replace `_play_in()`.

const Palette := preload("res://scripts/core/palette.gd")
const Strings := preload("res://scripts/ui/strings.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiTuning := preload("res://scripts/ui/ui_tuning.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const JuicyButton := preload("res://scripts/ui/juicy_button.gd")
const Column := preload("res://scripts/ui/column.gd")

## Emitted when the open motion is at rest.
signal opened
## Emitted when the close motion ends and the screen is hidden.
signal closed

var is_open := false

var _screen_tween: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open(data: Dictionary = {}) -> void:
	is_open = true
	visible = true
	_fill(data)
	_kill_screen_tween()
	_play_in()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_kill_screen_tween()
	_screen_tween = create_tween().set_parallel()
	_screen_tween.tween_property(self, "modulate:a", 0.0, UiTuning.SCREEN_FADE_TIME)
	_screen_tween.chain().tween_callback(_on_closed)


func _fill(_data: Dictionary) -> void:
	pass


func _play_in() -> void:
	modulate.a = 0.0
	position.y = UiTuning.SCREEN_SLIDE * Feel.motion()
	_screen_tween = create_tween().set_parallel()
	_screen_tween.tween_property(self, "modulate:a", 1.0, UiTuning.SCREEN_FADE_TIME)
	_screen_tween.tween_property(self, "position:y", 0.0, UiTuning.SCREEN_FADE_TIME * 1.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_screen_tween.chain().tween_callback(opened.emit)


func _on_closed() -> void:
	visible = false
	position = Vector2.ZERO
	closed.emit()


func _kill_screen_tween() -> void:
	if _screen_tween:
		_screen_tween.kill()
		_screen_tween = null


func _button(kind: JuicyButton.Kind, text_key: String, icon_kind: StringName = &"", height: float = UiTuning.BUTTON_HEIGHT) -> Button:
	var text_value := Strings.t(text_key) if text_key != "" else ""
	return JuicyButton.new().setup(kind, text_value, icon_kind, height)


func _round_button(icon_kind: StringName) -> Button:
	return JuicyButton.new().setup(JuicyButton.Kind.ROUND, "", icon_kind, UiTuning.ICON_BUTTON_SIZE)
