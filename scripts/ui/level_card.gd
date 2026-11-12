extends "res://scripts/ui/juicy_button.gd"
## One card of the level select screen: the thumbnail, the level number and name, the best stars, or a lock.

const Strings := preload("res://scripts/ui/strings.gd")
const LevelThumb := preload("res://scripts/ui/level_thumb.gd")

signal chosen(index: int)

var index := 0
var locked := false

var _thumb: Control
var _lock: Control
var _number: Label
var _name: Label
var _stars: Array[Control] = []
var _badge: PanelContainer


func setup_card(def: Dictionary, level_index: int) -> Button:
	index = level_index
	setup_custom(Kind.CARD, 220.0)
	content.add_theme_constant_override("margin_left", 16)
	content.add_theme_constant_override("margin_right", 16)
	content.add_theme_constant_override("margin_top", 14)
	content.add_theme_constant_override("margin_bottom", 12)
	var stack := UiTheme.vbox(6)
	content.add_child(stack)

	var thumb_box := Control.new()
	thumb_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb_box.custom_minimum_size.y = 90.0
	stack.add_child(thumb_box)
	_thumb = LevelThumb.new().setup(def, level_index)
	_thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thumb_box.add_child(_thumb)
	_lock = Icon.new().setup(&"lock", 72, Palette.INK, Palette.CREAM_LIGHT)
	_lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	thumb_box.add_child(_lock)
	_badge = UiTheme.panel(UiTheme.pad(UiTheme.box(Palette.CORAL_SOFT, 14, Palette.CORAL, 2), 12, 0))
	_badge.add_child(UiTheme.label(Strings.t("level_new"), UiTuning.SIZE_TINY, UiTuning.WEIGHT_BOLD, Palette.INK))
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	thumb_box.add_child(_badge)

	var head := UiTheme.hbox(4)
	stack.add_child(head)
	_number = UiTheme.label(Strings.t("level_number", {"n": level_index + 1}), UiTuning.SIZE_BODY,
		UiTuning.WEIGHT_BOLD, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT)
	_number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_number)
	for i in 3:
		var star := Icon.new().setup(&"star_empty", 30, Palette.INK_SOFT, Palette.STAR)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(star)
		_stars.append(star)
	_name = UiTheme.label(Strings.t(def.name_key), UiTuning.SIZE_TINY + 1, UiTuning.WEIGHT_BODY, Palette.INK_SOFT,
		HORIZONTAL_ALIGNMENT_LEFT)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.custom_minimum_size.x = 1.0
	stack.add_child(_name)
	pressed.connect(_on_card_pressed)
	return self


## Shows the stored progress of this level.
func refresh(def: Dictionary) -> void:
	locked = not Save.is_unlocked(index)
	tap_sound = not locked
	var stars: int = Save.best(def.id).stars
	_lock.visible = locked
	_thumb.muted = locked
	_badge.visible = not locked and stars == 0
	_name.text = Strings.t("level_locked") if locked else Strings.t(def.name_key)
	for i in 3:
		_stars[i].visible = not locked
		_stars[i].kind = &"star" if i < stars else &"star_empty"
	var face := Palette.CREAM if locked else Palette.CREAM_LIGHT
	for state in ["normal", "hover"]:
		var sb := get_theme_stylebox(state) as StyleBoxFlat
		sb.bg_color = face if state == "normal" else face.lightened(0.06)


func _on_card_pressed() -> void:
	if locked:
		shake()
		_lock.scale = Vector2(1.3, 1.3)
		_lock.create_tween().tween_property(_lock, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Bus.ui_locked.emit()
		return
	chosen.emit(index)
