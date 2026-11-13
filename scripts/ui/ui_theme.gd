extends RefCounted
## Fonts, the shared Theme and the style helpers of all UI code.

const Palette := preload("res://scripts/core/palette.gd")
const UiTuning := preload("res://scripts/ui/ui_tuning.gd")
const NUNITO := preload("res://ui/fonts/Nunito-VariableFont_wght.ttf")

# Meter zones, derived from the palette. `build()` sets them again after a theme change.
static var ZONE_THREE := Palette.METER_GOLD
static var ZONE_TWO := Palette.TRAY_HIGHLIGHT
static var ZONE_ONE := Palette.CORAL_SOFT

const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const FONT_COLOR_STATES: Array[String] = [
	"font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color",
]

static var _fonts: Dictionary = {}


## Nunito at `weight`. The raw FontFile opens at weight 200, so each use goes through this variation.
static func font(weight: int) -> FontVariation:
	if _fonts.has(weight):
		return _fonts[weight]
	var variation := FontVariation.new()
	variation.base_font = NUNITO
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_fonts[weight] = variation
	return variation


## The one Theme of the game, in the colors of the current Palette theme. Game sets it on the root window
## at boot and after a theme change.
static func build() -> Theme:
	ZONE_THREE = Palette.METER_GOLD
	ZONE_TWO = Palette.TRAY_HIGHLIGHT
	ZONE_ONE = Palette.CORAL_SOFT
	var theme := Theme.new()
	theme.default_font = font(UiTuning.WEIGHT_BODY)
	theme.default_font_size = UiTuning.SIZE_BODY
	theme.set_color("font_color", "Label", Palette.INK)
	theme.set_font("font", "Button", font(UiTuning.WEIGHT_BOLD))
	theme.set_font_size("font_size", "Button", UiTuning.SIZE_BUTTON)
	for state in FONT_COLOR_STATES:
		theme.set_color(state, "Button", Palette.INK)
	var empty := StyleBoxEmpty.new()
	for state in BUTTON_STATES:
		theme.set_stylebox(state, "Button", empty)
	theme.set_stylebox("panel", "PanelContainer", empty)
	theme.set_stylebox("panel", "Panel", empty)
	return theme


## A rounded box. `lip` draws a lower lip of `lip_color` inside the box, as on a candy button.
static func box(color: Color, radius: int = UiTuning.CORNER_RADIUS, border_color: Color = Color.TRANSPARENT,
		border: int = 0, lip: int = 0, lip_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 10
	sb.anti_aliasing = true
	if border > 0:
		sb.border_color = border_color
		sb.set_border_width_all(border)
	if lip > 0:
		sb.border_color = lip_color if border <= 0 else border_color
		sb.border_width_bottom = lip + border
	return sb


## A card face: cream_light, cream_shadow border, and a soft drop shadow below.
static func card_box(radius: int = UiTuning.CORNER_RADIUS + 8) -> StyleBoxFlat:
	var sb := box(Palette.CREAM_LIGHT, radius, Palette.CREAM_SHADOW, 3)
	sb.border_width_bottom = 9
	sb.shadow_color = Color(Palette.TRAY_SHADOW, 0.18)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 10)
	return sb


static func pad(sb: StyleBox, horizontal: float, vertical: float) -> StyleBox:
	sb.content_margin_left = horizontal
	sb.content_margin_right = horizontal
	sb.content_margin_top = vertical
	sb.content_margin_bottom = vertical
	return sb


static func label(text: String, size: int, weight: int, color: Color = Palette.INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(lbl, size, weight, color)
	return lbl


static func style_label(lbl: Label, size: int, weight: int, color: Color) -> void:
	lbl.add_theme_font_override("font", font(weight))
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)


## A label that wraps inside its container width.
static func paragraph(text: String, size: int, weight: int, color: Color = Palette.INK) -> Label:
	var lbl := label(text, size, weight, color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size.x = 1.0
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


static func vbox(separation: int) -> VBoxContainer:
	var box_node := VBoxContainer.new()
	box_node.add_theme_constant_override("separation", separation)
	box_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box_node


static func hbox(separation: int) -> HBoxContainer:
	var box_node := HBoxContainer.new()
	box_node.add_theme_constant_override("separation", separation)
	box_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box_node


static func panel(sb: StyleBox) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func spacer(height: float = 0.0, expand: bool = false) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(0, height)
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func time_text(ms: int, template: String) -> String:
	@warning_ignore("integer_division")
	var total := maxi(ms, 0) / 1000
	@warning_ignore("integer_division")
	return template.format({"m": total / 60, "s": "%02d" % (total % 60)})


## The parts of the screen that the notch and the system bars cover, in canvas units.
## Only mobile devices report a safe area that belongs to the game window.
static func safe_insets(node: CanvasItem) -> Dictionary:
	var out := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if not OS.has_feature("mobile") or not node.is_inside_tree():
		return out
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return out
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var k := node.get_viewport_rect().size / win
	out.left = maxf(safe.position.x, 0.0) * k.x
	out.top = maxf(safe.position.y, 0.0) * k.y
	out.right = maxf(win.x - safe.end.x, 0.0) * k.x
	out.bottom = maxf(win.y - safe.end.y, 0.0) * k.y
	return out
