extends "res://scripts/ui/screen.gd"
## The pause dialog: continue, levels, four settings, the one-jelly option, the language and the dark mode,
## and the font credit, on a dim scrim.
## It runs while the tree is paused. A long press on its title opens the performance panel.
## open() takes {"solo": the one-jelly state of the level (&"single", &"ready" or &"none"), "mode_solo": the mode in play};
## the note says when the level starts again on resume, or that the level has no one-jelly version.

const ToggleRow := preload("res://scripts/ui/toggle_row.gd")
const LanguageRow := preload("res://scripts/ui/language_row.gd")
const ThemeRow := preload("res://scripts/ui/theme_row.gd")

const SETTINGS: Array = [
	[&"music", "pause_music", &"music"],
	[&"sfx", "pause_sfx", &"speaker"],
	[&"haptics", "pause_haptics", &"vibrate"],
	[&"reduced_motion", "pause_reduced_motion", &"motion"],
]

var _scrim: ColorRect
var _card: PanelContainer
var _title: Label
var _rows: Array = []
var _solo_panel: PanelContainer
var _solo_note: Label
var _data: Dictionary = {}
var _press_serial := 0
var _title_tween: Tween


func _init() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim = ColorRect.new()
	_scrim.color = Color(Palette.SCRIM, Tuning.DIALOG_SCRIM_ALPHA)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scrim)

	var column := Column.new()
	add_child(column)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(center)
	_card = UiTheme.panel(UiTheme.pad(UiTheme.card_box(), UiTuning.CARD_PADDING, UiTuning.CARD_PADDING - 6))
	_card.custom_minimum_size.x = minf(UiTuning.CARD_WIDTH - 40.0, Tuning.COLUMN_WIDTH - UiTuning.GUTTER * 2.0)
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size / 2.0)
	center.add_child(_card)
	var stack := UiTheme.vbox(16)
	_card.add_child(stack)

	_title = UiTheme.label("", UiTuning.SIZE_HEADING, UiTuning.WEIGHT_BOLD, Palette.INK)
	Strings.bind(_title, "pause_title")
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.gui_input.connect(_on_title_input)
	_title.resized.connect(func() -> void: _title.pivot_offset = _title.size / 2.0)
	stack.add_child(_title)

	var resume := _button(JuicyButton.Kind.PRIMARY, "pause_continue", &"play", UiTuning.BUTTON_HEIGHT_HERO)
	resume.pressed.connect(func() -> void: Game.set_paused(false))
	stack.add_child(resume)
	var levels := _button(JuicyButton.Kind.SECONDARY, "pause_levels", &"grid")
	levels.pressed.connect(func() -> void: Game.open_levels())
	stack.add_child(levels)

	_solo_panel = UiTheme.panel(UiTheme.pad(UiTheme.box(Palette.MINT_LIGHT, UiTuning.CORNER_RADIUS, Palette.FLOOR_SHADOW, 2), 8, 6))
	stack.add_child(_solo_panel)
	var solo_box := UiTheme.vbox(0)
	_solo_panel.add_child(solo_box)
	var solo_row: Button = ToggleRow.new().setup_toggle(&"solo", "", &"jelly_happy")
	Strings.bind(solo_row.label, "pause_solo")
	solo_box.add_child(solo_row)
	_rows.append(solo_row)
	_solo_note = UiTheme.paragraph("", UiTuning.SIZE_TINY + 2, UiTuning.WEIGHT_BODY, Palette.INK_SOFT)
	_solo_note.visible = false
	solo_box.add_child(_solo_note)

	var settings := UiTheme.panel(UiTheme.pad(UiTheme.box(Palette.MINT_LIGHT, UiTuning.CORNER_RADIUS, Palette.FLOOR_SHADOW, 2), 8, 6))
	stack.add_child(settings)
	var rows := UiTheme.vbox(0)
	settings.add_child(rows)
	for entry: Array in SETTINGS:
		var row: Button = ToggleRow.new().setup_toggle(entry[0], "", entry[2])
		Strings.bind(row.label, entry[1])
		rows.add_child(row)
		_rows.append(row)
	var language: Button = LanguageRow.new().setup_language()
	rows.add_child(language)
	_rows.append(language)
	var theme_row: Button = ThemeRow.new().setup_theme()
	rows.add_child(theme_row)
	_rows.append(theme_row)

	var credit := UiTheme.paragraph("", UiTuning.SIZE_TINY, UiTuning.WEIGHT_BODY, Palette.INK_SOFT)
	Strings.bind(credit, "font_credit")
	stack.add_child(credit)


func _ready() -> void:
	Bus.setting_changed.connect(func(key: StringName, _value: bool) -> void:
		if key == &"solo":
			_update_solo_note())
	Bus.locale_changed.connect(func(_locale: StringName) -> void: _update_solo_note())


func _fill(data: Dictionary) -> void:
	_data = data
	_solo_panel.visible = data.get("solo", &"single") != &"single"
	for row in _rows:
		row.refresh()
	_update_solo_note()


func _update_solo_note() -> void:
	var key := ""
	if _data.get("solo", &"single") == &"none":
		key = "pause_solo_none"
	elif bool(Save.setting(&"solo")) != bool(_data.get("mode_solo", false)):
		key = "pause_solo_restart"
	_solo_note.visible = key != ""
	if key != "":
		_solo_note.text = Strings.t(key)


func _play_in() -> void:
	modulate.a = 0.0
	var motion := Feel.motion()
	_card.scale = Vector2.ONE * lerpf(1.0, UiTuning.CARD_START_SCALE + 0.15, motion)
	_screen_tween = create_tween().set_parallel()
	_screen_tween.tween_property(self, "modulate:a", 1.0, UiTuning.SCREEN_FADE_TIME)
	_screen_tween.tween_property(_card, "scale", Vector2.ONE, UiTuning.CARD_SPRING_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_screen_tween.chain().tween_callback(opened.emit)


func _on_title_input(event: InputEvent) -> void:
	var press := false
	var release := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		press = event.pressed
		release = not event.pressed
	elif event is InputEventScreenTouch and event.index == 0:
		press = event.pressed
		release = not event.pressed
	if press:
		_press_serial += 1
		_hold_title(_press_serial)
	elif release:
		_press_serial += 1
		_ease_title(1.0, 0.2)


# The title swells while the finger holds it, so the hidden gesture gives feedback.
func _hold_title(serial: int) -> void:
	_ease_title(1.12, Tuning.LONG_PRESS_TIME)
	await get_tree().create_timer(Tuning.LONG_PRESS_TIME, true, false, true).timeout
	if serial != _press_serial:
		return
	_press_serial += 1
	_ease_title(1.0, 0.3)
	Bus.ui_tap.emit()
	PerfPanel.toggle()


func _ease_title(value: float, time: float) -> void:
	if _title_tween:
		_title_tween.kill()
	_title_tween = create_tween().set_trans(Tween.TRANS_BACK if value <= 1.0 else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_title_tween.tween_property(_title, "scale", Vector2(value, value), time)
