extends "res://scripts/ui/screen.gd"
## The layer over the board during a replay: a title pill with the move count, and a note that a tap goes back.
## A tap anywhere emits `stop_requested`; the caller stops the replay.

signal stop_requested

const ICON_SIZE := 46.0

var _counter: Label
var _n := 0
var _total := 0
var _stop_sent := false
var _counter_tween: Tween


func _init() -> void:
	super()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := Column.new()
	column.pad_top = 16.0
	column.pad_bottom = 20.0
	add_child(column)
	var stack := UiTheme.vbox(14)
	column.add_child(stack)

	var pill := UiTheme.panel(UiTheme.pad(UiTheme.box(Palette.MINT_LIGHT, UiTuning.CORNER_RADIUS, Palette.FLOOR_SHADOW, 3, 6), 22, 14))
	stack.add_child(pill)
	var row := UiTheme.hbox(14)
	pill.add_child(row)
	var pic := Icon.new().setup(&"replay", ICON_SIZE, Palette.INK, Palette.MINT_LIGHT)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	var title := UiTheme.label("", UiTuning.SIZE_BODY + 2, UiTuning.WEIGHT_BOLD, Palette.INK, HORIZONTAL_ALIGNMENT_LEFT)
	Strings.bind(title, "replay_title")
	row.add_child(title)
	row.add_child(UiTheme.spacer(0, true))
	_counter = UiTheme.label("", UiTuning.SIZE_COUNTER, UiTuning.WEIGHT_BOLD, Palette.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_counter.resized.connect(func() -> void: _counter.pivot_offset = _counter.size * Vector2(1.0, 0.5))
	row.add_child(_counter)

	stack.add_child(UiTheme.spacer(0, true))

	var hint_area := CenterContainer.new()
	hint_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_area.custom_minimum_size.y = UiTuning.HINT_AREA_HEIGHT
	stack.add_child(hint_area)
	var hint_pill := UiTheme.panel(UiTheme.pad(UiTheme.box(Palette.CREAM_LIGHT, 24, Palette.CREAM_SHADOW, 3, 4), 24, 10))
	hint_area.add_child(hint_pill)
	var hint := UiTheme.label("", UiTuning.SIZE_SMALL + 2, UiTuning.WEIGHT_BODY, Palette.INK)
	Strings.bind(hint, "replay_tap")
	hint_pill.add_child(hint)


func _ready() -> void:
	Bus.locale_changed.connect(func(_locale: StringName) -> void: _set_counter_text())


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not tap:
		return
	accept_event()
	# A touch also arrives as an emulated mouse press: one stop for each open.
	if is_open and not _stop_sent:
		_stop_sent = true
		stop_requested.emit()


func _fill(data: Dictionary) -> void:
	_stop_sent = false
	set_step(0, int(data.get("total", 0)))


## Shows move `n` of `total`. A step after the first one pops the counter.
func set_step(n: int, total: int) -> void:
	_n = n
	_total = total
	_set_counter_text()
	if n <= 0:
		if _counter_tween:
			_counter_tween.kill()
		_counter.scale = Vector2.ONE
		return
	var motion := Feel.motion()
	var peak := UiTuning.COUNTER_POP * motion + (1.0 - motion)
	if _counter_tween:
		_counter_tween.kill()
	_counter_tween = create_tween()
	_counter_tween.tween_property(_counter, "scale", Vector2(peak, peak), UiTuning.COUNTER_POP_TIME * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_counter_tween.tween_property(_counter, "scale", Vector2.ONE, UiTuning.COUNTER_POP_TIME * 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_counter_text() -> void:
	_counter.text = Strings.t("replay_count", {"n": _n, "total": _total})
