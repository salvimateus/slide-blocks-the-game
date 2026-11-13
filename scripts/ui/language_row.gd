extends "res://scripts/ui/juicy_button.gd"
## The language row: a globe, a name and a pill with the current language. A tap changes to the next language through Save.

const Strings := preload("res://scripts/ui/strings.gd")

var _value: Label


func setup_language() -> Button:
	setup_custom(Kind.ROW, UiTuning.TOGGLE_ROW_HEIGHT)
	content.add_theme_constant_override("margin_left", 12)
	content.add_theme_constant_override("margin_right", 12)
	var row := UiTheme.hbox(18)
	content.add_child(row)
	var pic := Icon.new().setup(&"globe", 40, Palette.INK, Palette.MINT_LIGHT)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	label = UiTheme.label("", UiTuning.SIZE_BODY, UiTuning.WEIGHT_BODY, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Strings.bind(label, "pause_language")
	row.add_child(label)
	var pill := UiTheme.panel(UiTheme.pad(UiTheme.box(Palette.CREAM_LIGHT, 22, Palette.FLOOR_SHADOW, 2), 16, 4))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pill)
	_value = UiTheme.label("", UiTuning.SIZE_SMALL, UiTuning.WEIGHT_BOLD, Palette.INK)
	pill.add_child(_value)
	refresh()
	pressed.connect(_on_language_pressed)
	Bus.locale_changed.connect(_on_locale_changed)
	return self


## Shows the current language.
func refresh() -> void:
	_value.text = Strings.t("language_" + String(Save.language()))


func _on_locale_changed(_locale: StringName) -> void:
	refresh()


func _on_language_pressed() -> void:
	var codes: Array = Strings.TABLES.keys()
	var next: StringName = codes[(codes.find(Save.language()) + 1) % codes.size()]
	Save.set_language(next)
