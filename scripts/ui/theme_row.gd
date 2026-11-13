extends "res://scripts/ui/toggle_row.gd"
## The dark mode row: a moon, a name and a switch with a sun (light) and a moon (dark). A tap changes the theme through Save, and Game then builds the UI again.

const Strings := preload("res://scripts/ui/strings.gd")


func setup_theme() -> Button:
	setup_toggle(&"theme", "", &"moon")
	_switch.set_glyphs(&"moon", &"sun")
	Strings.bind(label, "pause_dark_mode")
	return self


## Shows the current theme, with no motion.
func refresh() -> void:
	_switch.set_on(Save.theme() == &"dark", false)


func _on_toggle() -> void:
	var dark := Save.theme() != &"dark"
	_switch.set_on(dark, true)
	Save.set_theme(&"dark" if dark else &"light")
