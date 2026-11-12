extends "res://scripts/ui/juicy_button.gd"
## One setting row: an icon, a name and a switch. A tap flips the setting through Save.

const Switch := preload("res://scripts/ui/switch.gd")

var key: StringName
var _switch: Control


func setup_toggle(setting_key: StringName, text_value: String, icon_kind: StringName) -> Button:
	key = setting_key
	setup_custom(Kind.ROW, UiTuning.TOGGLE_ROW_HEIGHT)
	content.add_theme_constant_override("margin_left", 12)
	content.add_theme_constant_override("margin_right", 12)
	var row := UiTheme.hbox(18)
	content.add_child(row)
	var pic := Icon.new().setup(icon_kind, 40, Palette.INK, Palette.MINT_LIGHT)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	label = UiTheme.label(text_value, UiTuning.SIZE_BODY, UiTuning.WEIGHT_BODY, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_switch = Switch.new()
	_switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_switch)
	pressed.connect(_on_toggle)
	return self


## Shows the stored value, with no motion.
func refresh() -> void:
	_switch.set_on(Save.setting(key), false)


func _on_toggle() -> void:
	var value := not Save.setting(key)
	Save.set_setting(key, value)
	_switch.set_on(value, true)
