extends "res://scripts/ui/card_screen.gd"
## The defeat card: a sad jujuba, the painted share that counts up, `Tentar de novo` and `Fases`.
## open() takes the summary dictionary of Bus.level_lost.

const LevelsData := preload("res://scripts/core/levels_data.gd")

const BAR_HEIGHT := 30.0

var _jelly: Control
var _subtitle: Label
var _painted_label: Label
var _track: Control
var _fill_bar: Panel
var _share := 0.0
var _summary: Dictionary = {}
var _wobble: Tween


func _init() -> void:
	super()
	var jelly_holder := CenterContainer.new()
	jelly_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(jelly_holder)
	_jelly = Icon.new().setup(&"jelly_sad", 140, Palette.INK, Palette.BODY[0])
	jelly_holder.add_child(_jelly)
	stack.add_child(UiTheme.paragraph(Strings.t("defeat_title"), UiTuning.SIZE_HEADING, UiTuning.WEIGHT_BOLD, Palette.INK))
	_subtitle = UiTheme.label("", UiTuning.SIZE_SMALL + 2, UiTuning.WEIGHT_BODY, Palette.INK_SOFT)
	stack.add_child(_subtitle)

	var pill := UiTheme.panel(UiTheme.pad(UiTheme.box(Palette.MINT_LIGHT, 24, Palette.FLOOR_SHADOW, 2, 4), 22, 16))
	stack.add_child(pill)
	var box := UiTheme.vbox(12)
	pill.add_child(box)
	_painted_label = UiTheme.paragraph("", UiTuning.SIZE_BODY, UiTuning.WEIGHT_BOLD, Palette.INK)
	box.add_child(_painted_label)
	_track = Control.new()
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.custom_minimum_size.y = BAR_HEIGHT
	var back := Panel.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", UiTheme.box(Palette.MINT, int(BAR_HEIGHT / 2.0), Palette.FLOOR_SHADOW, 2))
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_track.add_child(back)
	_fill_bar = Panel.new()
	_fill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_bar.add_theme_stylebox_override("panel", UiTheme.box(Palette.CORAL, int(BAR_HEIGHT / 2.0), Palette.CORAL_DEEP, 2))
	_track.add_child(_fill_bar)
	_track.resized.connect(_place_fill)
	box.add_child(_track)

	stack.add_child(UiTheme.spacer(4))
	var retry := _button(JuicyButton.Kind.PRIMARY, "defeat_retry", &"restart", UiTuning.BUTTON_HEIGHT_HERO)
	retry.pressed.connect(func() -> void: Game.restart())
	stack.add_child(retry)
	var levels := _button(JuicyButton.Kind.SECONDARY, "defeat_levels", &"grid")
	levels.pressed.connect(func() -> void: Game.open_levels())
	stack.add_child(levels)


func _fill_share(k: float) -> void:
	var painted: int = _summary.get("painted", 0)
	var floor_count := maxi(int(_summary.get("floor", 1)), 1)
	var target := float(painted) / floor_count
	_share = target * k
	@warning_ignore("integer_division")
	var percent := roundi(painted * 100 / floor_count * k)
	_painted_label.text = Strings.t("defeat_painted", {"p": percent})
	_place_fill()


func _place_fill() -> void:
	var h := _track.size.y
	var w := lerpf(h, _track.size.x, _share) if _share > 0.0 else 0.0
	_fill_bar.visible = w > 0.0
	_fill_bar.position = Vector2.ZERO
	_fill_bar.size = Vector2(w, h)


func _fill(data: Dictionary) -> void:
	_summary = data
	var index: int = data.get("level_index", 0)
	var def: Dictionary = LevelsData.LEVELS[clampi(index, 0, LevelsData.LEVELS.size() - 1)]
	_subtitle.text = Strings.t("level_subtitle", {"n": index + 1, "name": Strings.t(def.name_key)})
	_fill_share(0.0)
	if _wobble:
		_wobble.kill()
	_jelly.scale = Vector2.ONE


func _intro(tween: Tween, start: float) -> void:
	tween.tween_method(_fill_share, 0.0, 1.0, UiTuning.COUNT_UP_TIME * 1.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(start)
	tween.tween_callback(_start_wobble).set_delay(start)


func _finish() -> void:
	_fill_share(1.0)
	if _wobble == null or not _wobble.is_valid():
		_start_wobble()


# The sad jujuba breathes slowly, a soft squash and stretch.
func _start_wobble() -> void:
	var amount := 0.06 * Feel.motion()
	if amount <= 0.0:
		return
	_wobble = _jelly.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wobble.tween_property(_jelly, "scale", Vector2(1.0 + amount, 1.0 - amount), 0.9)
	_wobble.tween_property(_jelly, "scale", Vector2(1.0 - amount * 0.5, 1.0 + amount * 0.5), 0.9)


func _on_closed() -> void:
	if _wobble:
		_wobble.kill()
	super._on_closed()
