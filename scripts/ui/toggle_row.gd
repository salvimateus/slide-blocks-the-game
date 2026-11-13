extends "res://scripts/ui/juicy_button.gd"
## One setting row: an icon, a name and a switch. A tap flips the setting through Save.
## The compact form is a small secondary button that fits a screen header.

const Switch := preload("res://scripts/ui/switch.gd")

var key: StringName
var _switch: Control


func setup_toggle(setting_key: StringName, text_value: String, icon_kind: StringName, compact := false) -> Button:
	key = setting_key
	if compact:
		setup_custom(Kind.SECONDARY, UiTuning.ICON_BUTTON_SIZE)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# A Button does not take its width from its children: follow the content, also after a language change.
		content.minimum_size_changed.connect(_fit_content)
	else:
		setup_custom(Kind.ROW, UiTuning.TOGGLE_ROW_HEIGHT)
	content.add_theme_constant_override("margin_left", 12)
	content.add_theme_constant_override("margin_right", 12)
	var row := UiTheme.hbox(8 if compact else 18)
	content.add_child(row)
	# A jelly icon keeps a light body with dark eyes in both themes.
	var accent := Palette.JELLY_FACE if String(icon_kind).begins_with("jelly") else Palette.MINT_LIGHT
	var pic := Icon.new().setup(icon_kind, 36 if compact else 40, Palette.INK, accent)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	if compact:
		label = UiTheme.label(text_value, UiTuning.SIZE_TINY + 2, UiTuning.WEIGHT_BOLD, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT)
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		label = UiTheme.label(text_value, UiTuning.SIZE_BODY, UiTuning.WEIGHT_BODY, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_switch = Switch.new()
	_switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_switch)
	pressed.connect(_on_toggle)
	if compact:
		_fit_content()
	return self


## Shows the stored value, with no motion.
func refresh() -> void:
	_switch.set_on(Save.setting(key), false)


func _fit_content() -> void:
	custom_minimum_size.x = content.get_combined_minimum_size().x


func _on_toggle() -> void:
	var value := not Save.setting(key)
	Save.set_setting(key, value)
	_switch.set_on(value, true)
