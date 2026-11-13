extends "res://scripts/ui/card_screen.gd"
## The win card: stars that pop one by one, the time and the moves that count up, the range bar with a marker,
## the range sentence and the next steps. open() takes the summary dictionary of Bus.level_won.
## A random level offers a new random level and Home in place of the next level and the level select.

const RangeBar := preload("res://scripts/ui/range_bar.gd")

const STAR_SIZES: Array[float] = [104.0, 132.0, 104.0]
const STAR_LIFT := 22.0

var _subtitle: Label
var _star_fills: Array[Control] = []
var _badge: PanelContainer
var _badge_holder: CenterContainer
var _time_value: Label
var _moves_value: Label
var _bar: Control
var _sentence: Label
var _all_done: Label
var _next_button: Button
var _new_random_button: Button
var _replay_button: Button
var _levels_button: Button
var _home_button: Button
var _summary: Dictionary = {}


func _init() -> void:
	super()
	var title := UiTheme.label("", UiTuning.SIZE_HEADING, UiTuning.WEIGHT_BOLD, Palette.INK)
	Strings.bind(title, "result_title")
	stack.add_child(title)
	_subtitle = UiTheme.label("", UiTuning.SIZE_SMALL + 2, UiTuning.WEIGHT_BODY, Palette.INK_SOFT)
	stack.add_child(_subtitle)

	var stars_row := UiTheme.hbox(6)
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(stars_row)
	for i in 3:
		var px: float = STAR_SIZES[i]
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.custom_minimum_size = Vector2(px, STAR_SIZES[1] + STAR_LIFT)
		stars_row.add_child(holder)
		var top := 0.0 if i == 1 else STAR_LIFT + (STAR_SIZES[1] - px) / 2.0
		var empty := Icon.new().setup(&"star_empty", px, Palette.INK_SOFT)
		empty.position = Vector2(0, top)
		holder.add_child(empty)
		var fill := Icon.new().setup(&"star", px, Palette.INK_SOFT, Palette.STAR)
		fill.position = Vector2(0, top)
		holder.add_child(fill)
		_star_fills.append(fill)

	_badge_holder = CenterContainer.new()
	_badge_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_holder.custom_minimum_size.y = 44.0
	stack.add_child(_badge_holder)
	_badge = UiTheme.panel(UiTheme.pad(UiTheme.box(UiTheme.ZONE_THREE, 22, Palette.STAR_DEEP, 3), 20, 2))
	var badge_label := UiTheme.label("", UiTuning.SIZE_SMALL, UiTuning.WEIGHT_BOLD, Palette.INK)
	Strings.bind(badge_label, "result_new_best")
	_badge.add_child(badge_label)
	_badge.resized.connect(func() -> void: _badge.pivot_offset = _badge.size / 2.0)
	_badge_holder.add_child(_badge)

	var stats := UiTheme.hbox(16)
	stack.add_child(stats)
	_time_value = _stat(stats, "result_time")
	_moves_value = _stat(stats, "result_moves")

	_bar = RangeBar.new()
	stack.add_child(_bar)
	_sentence = UiTheme.paragraph("", UiTuning.SIZE_SMALL, UiTuning.WEIGHT_BODY, Palette.INK)
	stack.add_child(_sentence)
	_all_done = UiTheme.paragraph("", UiTuning.SIZE_BODY, UiTuning.WEIGHT_BOLD, Palette.INK)
	Strings.bind(_all_done, "result_all_done")
	stack.add_child(_all_done)

	stack.add_child(UiTheme.spacer(2))
	_next_button = _button(JuicyButton.Kind.PRIMARY, "result_next", &"play", UiTuning.BUTTON_HEIGHT_HERO)
	_next_button.pressed.connect(func() -> void: Game.next_level())
	stack.add_child(_next_button)
	_new_random_button = _button(JuicyButton.Kind.PRIMARY, "random_new", &"dice", UiTuning.BUTTON_HEIGHT_HERO)
	_new_random_button.pressed.connect(func() -> void: Game.start_random())
	stack.add_child(_new_random_button)
	_replay_button = _button(JuicyButton.Kind.SECONDARY, "replay_button", &"replay")
	_replay_button.pressed.connect(func() -> void: Game.play_replay())
	stack.add_child(_replay_button)
	var row := UiTheme.hbox(16)
	stack.add_child(row)
	var retry := _button(JuicyButton.Kind.SECONDARY, "result_retry", &"restart")
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(func() -> void: Game.restart())
	row.add_child(retry)
	_levels_button = _button(JuicyButton.Kind.SECONDARY, "result_levels", &"grid")
	_levels_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_levels_button.pressed.connect(func() -> void: Game.open_levels())
	row.add_child(_levels_button)
	_home_button = _button(JuicyButton.Kind.SECONDARY, "random_home", &"back")
	_home_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_button.pressed.connect(func() -> void: Game.open_home())
	row.add_child(_home_button)


func _stat(parent: Control, key: String) -> Label:
	var pill := UiTheme.panel(UiTheme.pad(UiTheme.box(Palette.MINT_LIGHT, 24, Palette.FLOOR_SHADOW, 2, 4), 16, 8))
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pill)
	var box := UiTheme.vbox(-4)
	pill.add_child(box)
	var name_label := UiTheme.label("", UiTuning.SIZE_TINY + 2, UiTuning.WEIGHT_BOLD, Palette.INK_SOFT)
	Strings.bind(name_label, key)
	box.add_child(name_label)
	var value := UiTheme.label("", UiTuning.SIZE_STAT, UiTuning.WEIGHT_BOLD, Palette.INK)
	box.add_child(value)
	return value


func _fill(data: Dictionary) -> void:
	_summary = data
	_subtitle.text = _subtitle_for(data)
	var stars: int = data.get("stars", 0)
	var vars := {"stars": stars, "lo": data.get("range_lo", 0), "hi": data.get("range_hi", 0), "moves": data.get("moves", 0)}
	_sentence.text = Strings.t("result_range_one" if stars == 1 else "result_range", vars)
	var random: bool = data.get("mode", &"normal") == &"random"
	var is_last: bool = data.get("is_last", false)
	_next_button.visible = not random and not is_last and data.get("next_unlocked", false)
	_all_done.visible = not random and is_last
	_new_random_button.visible = random
	_levels_button.visible = not random
	_home_button.visible = random
	_replay_button.visible = data.get("can_replay", false)
	_bar.setup(data, true)
	_set_counts(0.0)
	for fill in _star_fills:
		fill.visible = false
	_badge.visible = data.get("new_best", false)
	_badge_holder.visible = _badge.visible
	_badge.modulate.a = 0.0


func _intro(tween: Tween, start: float) -> void:
	var stars: int = _summary.get("stars", 0)
	tween.tween_method(_set_counts, 0.0, 1.0, UiTuning.COUNT_UP_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(start)
	var at := start + 0.1
	for i in mini(stars, 3):
		tween.tween_callback(_show_star.bind(i)).set_delay(at)
		at += UiTuning.STAR_POP_INTERVAL
	if _badge.visible:
		tween.tween_callback(_pop.bind(_badge, 1.2, UiTuning.BADGE_POP_TIME, 0.0)).set_delay(at)
		at += UiTuning.BADGE_POP_TIME
	tween.tween_interval(maxf(at, start + UiTuning.COUNT_UP_TIME))


func _finish() -> void:
	_set_counts(1.0)
	var stars: int = _summary.get("stars", 0)
	for i in 3:
		var fill := _star_fills[i]
		fill.visible = i < stars
		fill.scale = Vector2.ONE
		fill.rotation = 0.0
		fill.modulate.a = 1.0
	_badge.modulate.a = 1.0
	_badge.scale = Vector2.ONE


func _show_star(i: int) -> void:
	_pop(_star_fills[i], UiTuning.STAR_POP_SCALE, UiTuning.STAR_POP_TIME, UiTuning.STAR_POP_SPIN * (1.0 if i % 2 == 0 else -1.0))
	Bus.star_shown.emit(i + 1)


# Counts the time and the moves from zero, and lights the bar with the moves.
func _set_counts(k: float) -> void:
	var moves: int = _summary.get("moves", 0)
	var shown := roundi(lerpf(0.0, moves, k))
	_moves_value.text = str(shown)
	_time_value.text = UiTheme.time_text(roundi(lerpf(0.0, _summary.get("time_ms", 0), k)), Strings.t("result_time_value"))
	if _summary.has("limit"):
		_bar.set_moves(maxi(shown, int(_summary.get("min", 0))), false)
