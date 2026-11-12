extends Node
## Wave 0 boot: a cream screen with the title. The agent owner writes the final boot in Wave 2.

const Palette := preload("res://scripts/core/palette.gd")
const Strings := preload("res://scripts/ui/strings.gd")
const NUNITO := preload("res://ui/fonts/Nunito-VariableFont_wght.ttf")


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Palette.CREAM
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var font := FontVariation.new()
	font.base_font = NUNITO
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): Tuning.Ui.WEIGHT_TITLE}

	var title := Label.new()
	title.text = Strings.t("app_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", Tuning.Ui.SIZE_TITLE)
	title.add_theme_color_override("font_color", Palette.INK)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(title)
