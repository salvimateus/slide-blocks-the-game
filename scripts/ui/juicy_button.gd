extends Button
## A candy button: a fast press, a spring release and a tap sound on Bus.ui_tap.
## The content (an icon, a label, or any control from the caller) lives in `content`.

const Palette := preload("res://scripts/core/palette.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiTuning := preload("res://scripts/ui/ui_tuning.gd")
const Icon := preload("res://scripts/ui/icon.gd")

enum Kind { PRIMARY, SECONDARY, ROUND, ROW, CARD }

## False when the caller plays a different sound (for example, a locked card).
var tap_sound := true
## The box that holds the content. Its offset follows the lip when the button is down.
var content: MarginContainer
var label: Label
var icon_node: Control

var _kind := Kind.PRIMARY
var _scale_tween: Tween


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	content = MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(_on_pressed)


## A button with a centered icon and text. Give "" for no text or &"" for no icon.
func setup(kind: Kind, text_value: String, icon_kind: StringName = &"", height: float = UiTuning.BUTTON_HEIGHT) -> Button:
	_kind = kind
	_apply_styles()
	custom_minimum_size.y = height
	var row := UiTheme.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)
	if icon_kind != &"":
		var px := height * (0.5 if kind == Kind.ROUND else 0.4)
		icon_node = Icon.new().setup(icon_kind, px, Palette.INK, Palette.CREAM_LIGHT if kind == Kind.PRIMARY else Palette.MINT_LIGHT)
		icon_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon_node)
	if text_value != "":
		label = UiTheme.label(text_value, UiTuning.SIZE_BUTTON, UiTuning.WEIGHT_BOLD)
		row.add_child(label)
	if kind == Kind.ROUND:
		custom_minimum_size.x = height
	return self


## A button that holds custom content, laid out by the caller in `content`.
func setup_custom(kind: Kind, height: float) -> Button:
	_kind = kind
	_apply_styles()
	custom_minimum_size.y = height
	return self


func _apply_styles() -> void:
	var face: Color
	var lip_color: Color
	var border := 0
	match _kind:
		Kind.PRIMARY:
			face = Palette.PERIWINKLE
			lip_color = Palette.TRAY_SHADOW
		Kind.SECONDARY, Kind.CARD:
			face = Palette.CREAM_LIGHT
			lip_color = Palette.CREAM_SHADOW
			border = 3
		Kind.ROUND:
			face = Palette.MINT_LIGHT
			lip_color = Palette.FLOOR_SHADOW
			border = 3
		Kind.ROW:
			face = Color(Palette.MINT_LIGHT, 0.0)
			lip_color = Color(Palette.FLOOR_SHADOW, 0.0)
	var radius := UiTuning.CORNER_RADIUS
	if _kind == Kind.ROUND:
		radius = int(UiTuning.ICON_BUTTON_SIZE / 2.0)
	var normal := UiTheme.box(face, radius, lip_color, border, UiTuning.BUTTON_LIP, lip_color)
	var hover := UiTheme.box(face.lightened(0.06) if _kind != Kind.ROW else Color(Palette.MINT_LIGHT, 0.6),
		radius, lip_color, border, UiTuning.BUTTON_LIP, lip_color)
	var down := UiTheme.box(face.darkened(0.06) if _kind != Kind.ROW else Palette.MINT_LIGHT,
		radius, lip_color, border, UiTuning.BUTTON_LIP_PRESSED, lip_color)
	down.expand_margin_top = -float(UiTuning.BUTTON_LIP - UiTuning.BUTTON_LIP_PRESSED)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", down)
	add_theme_stylebox_override("hover_pressed", down)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_stylebox_override("disabled", normal)
	_set_content_shift(false)


func _set_content_shift(down: bool) -> void:
	var lip := float(UiTuning.BUTTON_LIP)
	var shift := lip - UiTuning.BUTTON_LIP_PRESSED if down else 0.0
	content.offset_top = shift
	content.offset_bottom = shift - lip


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0


func _on_down() -> void:
	_set_content_shift(true)
	_scale_to(lerpf(1.0, UiTuning.BUTTON_PRESS_SCALE, Feel.motion()), UiTuning.BUTTON_PRESS_TIME, Tween.TRANS_QUAD)


func _on_up() -> void:
	_set_content_shift(false)
	_scale_to(1.0, UiTuning.BUTTON_RELEASE_TIME, Tween.TRANS_ELASTIC if Feel.motion() >= 1.0 else Tween.TRANS_BACK)


func _on_pressed() -> void:
	if tap_sound:
		Bus.ui_tap.emit()


func _scale_to(value: float, time: float, trans: Tween.TransitionType) -> void:
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2(value, value), time)


## A side shake, for a tap that the game refuses.
func shake() -> void:
	var tween := create_tween()
	var amount := UiTuning.LOCKED_SHAKE * Feel.motion()
	var step := UiTuning.LOCKED_SHAKE_TIME / 6.0
	var base_rotation := rotation
	for i in 5:
		var side := -1.0 if i % 2 == 0 else 1.0
		var fade := 1.0 - i / 5.0
		tween.tween_property(self, "rotation", base_rotation + deg_to_rad(side * amount * 0.25 * fade), step)
	tween.tween_property(self, "rotation", base_rotation, step)
