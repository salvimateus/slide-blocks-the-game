extends "res://scripts/ui/screen.gd"
## Home: the bouncing title, `Jogar` and `Fases`. The background stays clear: Game shows the live demo board behind it.

var _letters: Array[Label] = []
var _play_button: Button
var _levels_button: Button
var _bob_tweens: Array[Tween] = []


func _init() -> void:
	super()
	var column := Column.new()
	column.pad_top = 96.0
	column.pad_bottom = 64.0
	add_child(column)
	var stack := UiTheme.vbox(0)
	column.add_child(stack)

	var title := UiTheme.vbox(-28)
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(title)
	var title_font := UiTheme.font(UiTuning.WEIGHT_TITLE)
	for word in Strings.t("app_title").split(" ", false):
		var row := UiTheme.hbox(0)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		title.add_child(row)
		for i in word.length():
			var holder := Control.new()
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.custom_minimum_size = title_font.get_string_size(word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTuning.SIZE_TITLE)
			row.add_child(holder)
			var letter := UiTheme.label(word[i], UiTuning.SIZE_TITLE, UiTuning.WEIGHT_TITLE, Palette.INK)
			letter.add_theme_color_override("font_shadow_color", Palette.TRAY_HIGHLIGHT)
			letter.add_theme_constant_override("shadow_offset_x", 0)
			letter.add_theme_constant_override("shadow_offset_y", 8)
			letter.add_theme_color_override("font_outline_color", Palette.CREAM_LIGHT)
			letter.add_theme_constant_override("outline_size", 14)
			letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			letter.resized.connect(func() -> void: letter.pivot_offset = letter.size * Vector2(0.5, 1.0))
			holder.add_child(letter)
			_letters.append(letter)

	stack.add_child(UiTheme.spacer(0, true))

	var buttons := UiTheme.vbox(22)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(buttons)
	_play_button = _button(JuicyButton.Kind.PRIMARY, "home_play", &"play", UiTuning.BUTTON_HEIGHT_HERO)
	_play_button.custom_minimum_size.x = 440.0
	_play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play_button.pressed.connect(func() -> void: Game.start_level(Save.highest_unlocked()))
	buttons.add_child(_play_button)
	_levels_button = _button(JuicyButton.Kind.SECONDARY, "home_levels", &"grid")
	_levels_button.custom_minimum_size.x = 440.0
	_levels_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_levels_button.pressed.connect(func() -> void: Game.open_levels())
	buttons.add_child(_levels_button)


func _play_in() -> void:
	for tween in _bob_tweens:
		tween.kill()
	_bob_tweens.clear()
	modulate.a = 0.0
	var motion := Feel.motion()
	_screen_tween = create_tween().set_parallel()
	_screen_tween.tween_property(self, "modulate:a", 1.0, UiTuning.SCREEN_FADE_TIME)
	var last := 0.0
	for i in _letters.size():
		var letter := _letters[i]
		var delay := i * UiTuning.TITLE_LETTER_STAGGER
		letter.position.y = -UiTuning.TITLE_DROP * motion
		letter.modulate.a = 0.0
		_screen_tween.tween_property(letter, "position:y", 0.0, UiTuning.CARD_SPRING_TIME) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(delay)
		_screen_tween.tween_property(letter, "modulate:a", 1.0, UiTuning.SCREEN_FADE_TIME).set_delay(delay)
		last = delay + UiTuning.CARD_SPRING_TIME
	var button_delay := last * 0.5
	for button: Control in [_play_button, _levels_button]:
		button.scale = Vector2(0.6, 0.6)
		_screen_tween.tween_property(button, "scale", Vector2.ONE, UiTuning.CARD_SPRING_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(button_delay)
		button_delay += 0.08
	_screen_tween.chain().tween_callback(_start_bob)


# An idle wave runs through the letters while Home is open.
func _start_bob() -> void:
	var amount := UiTuning.TITLE_BOB * Feel.motion()
	if amount > 0.0:
		for i in _letters.size():
			var letter := _letters[i]
			var tween := letter.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(letter, "position:y", -amount, UiTuning.TITLE_BOB_TIME)
			tween.tween_property(letter, "position:y", 0.0, UiTuning.TITLE_BOB_TIME)
			tween.custom_step(fmod(i * 0.16, UiTuning.TITLE_BOB_TIME * 2.0))
			_bob_tweens.append(tween)
	opened.emit()


func _on_closed() -> void:
	for tween in _bob_tweens:
		tween.kill()
	_bob_tweens.clear()
	super._on_closed()
