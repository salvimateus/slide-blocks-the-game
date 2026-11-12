extends MarginContainer
## A full-screen box that keeps its content in the centered column of Tuning.COLUMN_WIDTH base units,
## inside the safe area, with a gutter on each side.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiTuning := preload("res://scripts/ui/ui_tuning.gd")

var gutter := UiTuning.GUTTER
var pad_top := UiTuning.GUTTER
var pad_bottom := UiTuning.GUTTER


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	get_viewport().size_changed.connect(refit)
	refit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		refit()


func refit() -> void:
	if not is_inside_tree():
		return
	var insets := UiTheme.safe_insets(self)
	var side := maxf((size.x - Tuning.COLUMN_WIDTH) / 2.0, 0.0) + gutter
	add_theme_constant_override("margin_left", int(maxf(side, insets.left + gutter)))
	add_theme_constant_override("margin_right", int(maxf(side, insets.right + gutter)))
	add_theme_constant_override("margin_top", int(insets.top + pad_top))
	add_theme_constant_override("margin_bottom", int(insets.bottom + pad_bottom))
