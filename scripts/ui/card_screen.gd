extends "res://scripts/ui/screen.gd"
## Base of the result and defeat cards: a scrim, a card that springs in, and a tap that skips the intro.
## Subclasses add their rows to `stack`, and fill `_intro(tween)` and `_finish()`.

const LevelsData := preload("res://scripts/core/levels_data.gd")

## False when the caller already dims the screen behind the card.
var use_scrim := true

var stack: VBoxContainer

var _scrim: ColorRect
var _card: PanelContainer
var _animating := false
var _side_tweens: Array[Tween] = []


func _init() -> void:
	super()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim = ColorRect.new()
	_scrim.color = Color(Palette.SCRIM, Tuning.SCRIM_ALPHA)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scrim)
	var column := Column.new()
	add_child(column)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(center)
	_card = UiTheme.panel(UiTheme.pad(UiTheme.card_box(), UiTuning.CARD_PADDING, UiTuning.CARD_PADDING))
	_card.custom_minimum_size.x = minf(UiTuning.CARD_WIDTH, Tuning.COLUMN_WIDTH - UiTuning.GUTTER * 2.0)
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size / 2.0)
	center.add_child(_card)
	stack = UiTheme.vbox(18)
	_card.add_child(stack)


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tap and _animating:
		accept_event()
		skip()


## Ends the intro at once and shows the final state.
func skip() -> void:
	if not _animating:
		return
	_kill_screen_tween()
	for tween in _side_tweens:
		if tween.is_valid():
			tween.kill()
	_side_tweens.clear()
	modulate.a = 1.0
	_scrim.modulate.a = 1.0
	_card.scale = Vector2.ONE
	_card.rotation = 0.0
	_finish()
	_end_intro()


## Shows the card again at its final state with a plain fade: no intro, no count-up, no star signal.
func reopen() -> void:
	is_open = true
	visible = true
	_kill_screen_tween()
	_animating = false
	position = Vector2.ZERO
	_scrim.visible = use_scrim
	_scrim.modulate.a = 1.0
	_card.scale = Vector2.ONE
	_card.rotation = 0.0
	_card.modulate.a = 1.0
	_finish()
	modulate.a = 0.0
	_screen_tween = create_tween()
	_screen_tween.tween_property(self, "modulate:a", 1.0, UiTuning.SCREEN_FADE_TIME)
	_screen_tween.tween_callback(opened.emit)


func _play_in() -> void:
	_animating = true
	modulate.a = 1.0
	_scrim.visible = use_scrim
	_scrim.modulate.a = 0.0
	var motion := Feel.motion()
	_card.modulate.a = 0.0
	_card.scale = Vector2.ONE * lerpf(1.0, UiTuning.CARD_START_SCALE, motion)
	_card.rotation = deg_to_rad(-4.0) * motion
	_screen_tween = create_tween().set_parallel()
	_screen_tween.tween_property(_scrim, "modulate:a", 1.0, UiTuning.SCRIM_FADE_TIME)
	_screen_tween.tween_property(_card, "modulate:a", 1.0, UiTuning.SCREEN_FADE_TIME)
	_screen_tween.tween_property(_card, "scale", Vector2.ONE, UiTuning.CARD_SPRING_TIME * 1.4) \
		.set_trans(Tween.TRANS_ELASTIC if motion >= 1.0 else Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_screen_tween.tween_property(_card, "rotation", 0.0, UiTuning.CARD_SPRING_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro(_screen_tween, UiTuning.CARD_SPRING_TIME * 0.55)
	_screen_tween.chain().tween_callback(_end_intro)


## Adds the steps of the intro to `tween` (a parallel tween), starting at `start` seconds.
func _intro(_tween: Tween, _start: float) -> void:
	pass


## Sets each part to its final state, for a skip.
func _finish() -> void:
	pass


func _end_intro() -> void:
	if not _animating:
		return
	_animating = false
	opened.emit()


## The subtitle of a card summary: the level and its name, the one-jelly level, or the seed of a random level.
func _subtitle_for(data: Dictionary) -> String:
	var index: int = data.get("level_index", 0)
	match data.get("mode", &"normal"):
		&"random":
			return Strings.t("random_subtitle", {"seed": data.get("seed", 0)})
		&"solo":
			return Strings.t("level_subtitle_solo", {"n": index + 1})
	var def: Dictionary = LevelsData.LEVELS[clampi(index, 0, LevelsData.LEVELS.size() - 1)]
	return Strings.t("level_subtitle", {"n": index + 1, "name": Strings.t(def.name_key)})


## A pop from zero with an overshoot, for a star or a badge.
func _pop(node: Control, peak: float, time: float, spin: float = 0.0) -> void:
	var motion := Feel.motion()
	node.visible = true
	node.modulate.a = 1.0
	node.scale = Vector2.ONE * (1.0 - motion)
	node.rotation = spin * motion
	var tween := node.create_tween().set_parallel()
	tween.tween_property(node, "scale", Vector2.ONE * lerpf(1.0, peak, motion), time * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "rotation", 0.0, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(node, "scale", Vector2.ONE, time * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_side_tweens.append(tween)
