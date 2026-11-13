extends "res://scripts/ui/screen.gd"
## The level HUD: pause, level name, restart, the move meter with its stars, the moves left, the paint progress,
## the level hint and the tension vignette. It reads Bus signals only.

const LevelModes := preload("res://scripts/core/level_modes.gd")
const RangeBar := preload("res://scripts/ui/range_bar.gd")

## Emitted when the free area for the board changes, with the new rect in base units (see board_rect).
signal board_rect_changed(rect: Rect2)

const STAR_SIZE := 46.0
const HINT_DOT_SIZE := 72.0

var _vignette: TextureRect
var _top_row: HBoxContainer
var _level_label: Label
var _name_label: Label
var _meter_panel: PanelContainer
var _meter_box: StyleBoxFlat
var _stars: Array[Control] = []
var _counter: Label
var _meter: Control
var _board_area: Control
var _hint_pill: PanelContainer
var _hint_label: Label
var _progress_track: Control
var _progress_fill: Panel
var _progress_label: Label
var _swipe_hint: Control
var _swipe_dot: Control
var _swipe_arrows: Control

var _meter_key := Vector3i(-1, -1, -1)
## The level info of Bus.level_loaded.
var _info: Dictionary = {}
var _hint_key := ""
var _snapshot: Dictionary = {}
var _last_moves := 0
var _progress_share := 0.0
var _tense := false
var _swipe_hint_on := false
var _counter_tween: Tween
var _vignette_tween: Tween
var _progress_tween: Tween
var _hint_tween: Tween
var _swipe_tween: Tween


func _init() -> void:
	super()
	_vignette = TextureRect.new()
	_vignette.texture = _vignette_texture()
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.modulate.a = 0.0
	add_child(_vignette)

	var column := Column.new()
	column.pad_top = 16.0
	column.pad_bottom = 20.0
	add_child(column)
	var stack := UiTheme.vbox(14)
	column.add_child(stack)

	_top_row = UiTheme.hbox(16)
	_top_row.resized.connect(func() -> void: _top_row.pivot_offset = Vector2(_top_row.size.x / 2.0, 0.0))
	stack.add_child(_top_row)
	var pause_button := _round_button(&"pause")
	pause_button.pressed.connect(func() -> void: Game.set_paused(true))
	_top_row.add_child(pause_button)
	var titles := UiTheme.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	_level_label = UiTheme.label("", UiTuning.SIZE_SMALL, UiTuning.WEIGHT_BOLD, Palette.INK_SOFT)
	_name_label = UiTheme.label("", UiTuning.SIZE_BODY + 2, UiTuning.WEIGHT_BOLD, Palette.INK)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.custom_minimum_size.x = 1.0
	titles.add_child(_level_label)
	titles.add_child(_name_label)
	_top_row.add_child(titles)
	var restart_button := _round_button(&"restart")
	restart_button.pressed.connect(func() -> void: Game.restart())
	_top_row.add_child(restart_button)

	_meter_box = UiTheme.pad(UiTheme.box(Palette.MINT_LIGHT, UiTuning.CORNER_RADIUS, Palette.FLOOR_SHADOW, 3, 6), 22, 14)
	_meter_panel = UiTheme.panel(_meter_box)
	_meter_panel.resized.connect(func() -> void: _meter_panel.pivot_offset = Vector2(_meter_panel.size.x / 2.0, 0.0))
	stack.add_child(_meter_panel)
	var meter_stack := UiTheme.vbox(8)
	_meter_panel.add_child(meter_stack)
	var meter_head := UiTheme.hbox(6)
	meter_stack.add_child(meter_head)
	for i in 3:
		var star := Icon.new().setup(&"star", STAR_SIZE, Palette.INK_SOFT, Palette.STAR)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meter_head.add_child(star)
		_stars.append(star)
	meter_head.add_child(UiTheme.spacer(0, true))
	_counter = UiTheme.label("", UiTuning.SIZE_COUNTER, UiTuning.WEIGHT_BOLD, Palette.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_counter.resized.connect(func() -> void: _counter.pivot_offset = _counter.size * Vector2(1.0, 0.5))
	meter_head.add_child(_counter)
	_meter = RangeBar.new()
	meter_stack.add_child(_meter)

	_board_area = UiTheme.spacer(0, true)
	_board_area.resized.connect(_on_board_area_resized)
	stack.add_child(_board_area)

	var hint_area := CenterContainer.new()
	hint_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_area.custom_minimum_size.y = UiTuning.HINT_AREA_HEIGHT
	stack.add_child(hint_area)
	_hint_pill = UiTheme.panel(UiTheme.pad(UiTheme.box(Palette.CREAM_LIGHT, 24, Palette.CREAM_SHADOW, 3, 4), 24, 10))
	_hint_pill.custom_minimum_size.x = 640.0
	_hint_label = UiTheme.paragraph("", UiTuning.SIZE_SMALL + 2, UiTuning.WEIGHT_BODY, Palette.INK)
	_hint_pill.add_child(_hint_label)
	_hint_pill.visible = false
	hint_area.add_child(_hint_pill)

	var progress_panel := UiTheme.panel(UiTheme.pad(UiTheme.box(Palette.MINT_LIGHT, 24, Palette.FLOOR_SHADOW, 3, 4), 22, 12))
	stack.add_child(progress_panel)
	var progress_row := UiTheme.hbox(18)
	progress_panel.add_child(progress_row)
	_progress_track = Control.new()
	_progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_track.custom_minimum_size.y = 22.0
	var track_panel := Panel.new()
	track_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_panel.add_theme_stylebox_override("panel", UiTheme.box(Palette.MINT, 11, Palette.FLOOR_SHADOW, 2))
	track_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_progress_track.add_child(track_panel)
	_progress_fill = Panel.new()
	_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_fill.add_theme_stylebox_override("panel", UiTheme.box(Palette.PERIWINKLE, 11, Palette.TRAY_SHADOW, 2))
	_progress_track.add_child(_progress_fill)
	_progress_track.resized.connect(_place_progress)
	progress_row.add_child(_progress_track)
	_progress_label = UiTheme.label("", UiTuning.SIZE_SMALL, UiTuning.WEIGHT_BOLD, Palette.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_progress_label.custom_minimum_size.x = 190.0
	progress_row.add_child(_progress_label)

	_swipe_hint = Control.new()
	_swipe_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swipe_hint.visible = false
	add_child(_swipe_hint)
	_swipe_arrows = Icon.new().setup(&"chevrons_left", 76, Color(Palette.INK, 0.75))
	_swipe_hint.add_child(_swipe_arrows)
	_swipe_dot = Icon.new().setup(&"touch", HINT_DOT_SIZE, Palette.INK)
	_swipe_hint.add_child(_swipe_dot)


func _ready() -> void:
	Bus.level_loaded.connect(_on_level_loaded)
	Bus.session_changed.connect(_on_session_changed)
	Bus.star_lost.connect(_on_star_lost)
	Bus.swipe_started.connect(_on_swipe_started)
	Bus.tension_changed.connect(_on_tension_changed)
	Bus.music_beat.connect(_on_music_beat)
	Bus.locale_changed.connect(_on_locale_changed)


## The free area between the top cluster and the hint area, in base units of the HUD layer.
## Game fits the board into it.
func board_rect() -> Rect2:
	return Rect2(_board_area.global_position - global_position, _board_area.size)


func _on_board_area_resized() -> void:
	var area := board_rect()
	_swipe_hint.position = Vector2(area.get_center().x, area.position.y + area.size.y * 0.72)
	board_rect_changed.emit(area)


func _play_in() -> void:
	modulate.a = 0.0
	var motion := Feel.motion()
	var drop := 1.0 - 0.1 * motion
	for node: Control in [_top_row, _meter_panel]:
		node.scale = Vector2(drop, drop)
	_screen_tween = create_tween().set_parallel()
	_screen_tween.tween_property(self, "modulate:a", 1.0, UiTuning.SCREEN_FADE_TIME)
	for node: Control in [_top_row, _meter_panel]:
		_screen_tween.tween_property(node, "scale", Vector2.ONE, UiTuning.CARD_SPRING_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_screen_tween.chain().tween_callback(opened.emit)


func _on_level_loaded(index: int, info: Dictionary) -> void:
	_info = info if not info.is_empty() else LevelModes.info(index, false)
	_hint_key = String(_info.hint_key)
	_set_level_texts()
	_meter_key = Vector3i(-1, -1, -1)
	_last_moves = 0
	_reset_stars()
	_set_tense(false, false)
	_show_hint(_hint_key)


func _on_session_changed(snap: Dictionary) -> void:
	if not snap.has("limit"):
		return
	_snapshot = snap
	var key := Vector3i(snap.three_max, snap.two_max, snap.limit)
	var fresh := key != _meter_key
	if fresh:
		_meter_key = key
		_meter.setup(snap, false)
	var moves: int = snap.moves_used
	_set_session_texts()
	_meter.set_moves(moves, not fresh)
	if moves == 0:
		_reset_stars()
	else:
		for i in 3:
			if i >= int(snap.stars) and _stars[i].kind == &"star":
				_stars[i].kind = &"star_empty"
	if moves > _last_moves:
		_pop_counter(UiTuning.COUNTER_POP * Feel.motion() + (1.0 - Feel.motion()), UiTuning.COUNTER_POP_TIME)
	_last_moves = moves
	var floor_count := maxi(int(snap.floor), 1)
	var share := clampf(float(snap.painted) / floor_count, 0.0, 1.0)
	_set_progress(share, not fresh)


# The text of the level: its number and mode, its name (the seed for a random level) and its hint.
func _set_level_texts() -> void:
	if _info.is_empty():
		return
	match _info.mode:
		&"random":
			_level_label.text = Strings.t("hud_random_solo" if _info.solo else "hud_random")
			_name_label.text = Strings.t("random_seed", {"seed": _info.seed})
		&"solo":
			_level_label.text = Strings.t("hud_level_solo", {"n": int(_info.index) + 1})
			_name_label.text = Strings.t(_info.name_key)
		_:
			_level_label.text = Strings.t("hud_level", {"n": int(_info.index) + 1})
			_name_label.text = Strings.t(_info.name_key)
	if _hint_key != "":
		_hint_label.text = Strings.t(_hint_key)


# The text of the last snapshot: the moves left and the painted share.
func _set_session_texts() -> void:
	if _snapshot.is_empty():
		return
	var left: int = _snapshot.moves_left
	_counter.text = Strings.t("hud_moves_left_one" if left == 1 else "hud_moves_left", {"n": left})
	var floor_count := maxi(int(_snapshot.floor), 1)
	@warning_ignore("integer_division")
	_progress_label.text = Strings.t("hud_painted", {"p": int(_snapshot.painted) * 100 / floor_count})


# Only the text changes: no motion, no star reset, no meter setup.
func _on_locale_changed(_locale: StringName) -> void:
	_set_level_texts()
	_set_session_texts()


func _on_star_lost(stars_left: int) -> void:
	if stars_left < 0 or stars_left > 2:
		return
	var star := _stars[stars_left]
	star.kind = &"star_empty"
	var ghost := Icon.new().setup(&"star", STAR_SIZE, Palette.INK_SOFT, Palette.STAR)
	add_child(ghost)
	ghost.position = star.global_position - global_position
	var motion := Feel.motion()
	var tween := ghost.create_tween().set_parallel()
	ghost.scale = Vector2(1.3, 1.3)
	tween.tween_property(ghost, "scale", Vector2(0.8, 0.8), UiTuning.STAR_FALL_TIME)
	tween.tween_property(ghost, "position:y", ghost.position.y + UiTuning.STAR_FALL_DISTANCE * maxf(motion, 0.3),
		UiTuning.STAR_FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(ghost, "position:x", ghost.position.x + 26.0 * motion, UiTuning.STAR_FALL_TIME)
	tween.tween_property(ghost, "rotation", UiTuning.STAR_FALL_SPIN * motion, UiTuning.STAR_FALL_TIME)
	tween.tween_property(ghost, "modulate:a", 0.0, UiTuning.STAR_FALL_TIME * 0.5).set_delay(UiTuning.STAR_FALL_TIME * 0.5)
	tween.chain().tween_callback(ghost.queue_free)
	star.scale = Vector2(0.6, 0.6)
	star.create_tween().tween_property(star, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_swipe_started(_outcome: Dictionary) -> void:
	if _swipe_hint_on:
		_hide_hint()


func _on_tension_changed(on: bool) -> void:
	_set_tense(on, true)


func _on_music_beat(_index: int, _tense_clip: bool) -> void:
	if not _tense or not visible:
		return
	_pop_counter(lerpf(1.0, UiTuning.HEARTBEAT_SCALE, Feel.motion()), UiTuning.HEARTBEAT_TIME)
	if _vignette_tween:
		_vignette_tween.kill()
	_vignette.modulate.a = UiTuning.VIGNETTE_BEAT_ALPHA
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_vignette, "modulate:a", UiTuning.VIGNETTE_ALPHA, UiTuning.HEARTBEAT_TIME * 2.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_tense(on: bool, animate: bool) -> void:
	_tense = on
	var target := UiTuning.VIGNETTE_ALPHA if on else 0.0
	if _vignette_tween:
		_vignette_tween.kill()
	if animate:
		_vignette_tween = create_tween()
		_vignette_tween.tween_property(_vignette, "modulate:a", target, UiTuning.VIGNETTE_FADE_TIME)
	else:
		_vignette.modulate.a = target
	_counter.add_theme_color_override("font_color", Palette.CORAL_DEEP if on else Palette.INK)
	_meter_box.border_color = Palette.CORAL if on else Palette.FLOOR_SHADOW


func _pop_counter(peak: float, time: float) -> void:
	if _counter_tween:
		_counter_tween.kill()
	_counter_tween = create_tween()
	_counter_tween.tween_property(_counter, "scale", Vector2(peak, peak), time * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_counter_tween.tween_property(_counter, "scale", Vector2.ONE, time * 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reset_stars() -> void:
	for star in _stars:
		star.kind = &"star"
		star.scale = Vector2.ONE


func _set_progress(share: float, animate: bool) -> void:
	if _progress_tween:
		_progress_tween.kill()
	if not animate:
		_progress_share = share
		_place_progress()
		return
	_progress_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_progress_tween.tween_method(func(v: float) -> void:
		_progress_share = v
		_place_progress(), _progress_share, share, UiTuning.PROGRESS_TIME)


func _place_progress() -> void:
	var h := _progress_track.size.y
	var w := lerpf(h, _progress_track.size.x, _progress_share) if _progress_share > 0.0 else 0.0
	_progress_fill.visible = w > 0.0
	_progress_fill.position = Vector2.ZERO
	_progress_fill.size = Vector2(w, h)


func _show_hint(hint_key: String) -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint_pill.visible = hint_key != ""
	_hint_pill.modulate.a = 1.0
	_swipe_hint_on = hint_key == "hint_swipe"
	_swipe_hint.modulate.a = 1.0
	_swipe_hint.visible = _swipe_hint_on
	if _swipe_hint_on:
		_start_swipe_hint()
	elif _swipe_tween:
		_swipe_tween.kill()


func _hide_hint() -> void:
	_swipe_hint_on = false
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween().set_parallel()
	_hint_tween.tween_property(_hint_pill, "modulate:a", 0.0, UiTuning.HINT_FADE_TIME)
	_hint_tween.tween_property(_swipe_hint, "modulate:a", 0.0, UiTuning.HINT_FADE_TIME)
	_hint_tween.chain().tween_callback(func() -> void:
		_hint_pill.visible = false
		_swipe_hint.visible = false
		if _swipe_tween:
			_swipe_tween.kill())


# A finger dot slides left over the lower part of the board, again and again, until the first swipe.
func _start_swipe_hint() -> void:
	if _swipe_tween:
		_swipe_tween.kill()
	var distance := UiTuning.SWIPE_HINT_DISTANCE
	_on_board_area_resized()
	var start := Vector2(distance / 2.0, 0.0) - _swipe_dot.size / 2.0
	var finish := start - Vector2(distance, 0.0)
	_swipe_arrows.position = Vector2(-distance / 2.0 - 70.0, 0.0) - _swipe_arrows.size / 2.0
	var loop := UiTuning.SWIPE_HINT_LOOP
	_swipe_tween = create_tween().set_loops()
	_swipe_tween.tween_callback(func() -> void:
		_swipe_dot.position = start
		_swipe_dot.modulate.a = 0.0
		_swipe_dot.scale = Vector2(0.6, 0.6)
		_swipe_arrows.modulate.a = 0.3)
	_swipe_tween.tween_property(_swipe_dot, "modulate:a", 1.0, loop * 0.12)
	_swipe_tween.parallel().tween_property(_swipe_dot, "scale", Vector2.ONE, loop * 0.12)
	_swipe_tween.tween_property(_swipe_dot, "position", finish, loop * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_swipe_tween.parallel().tween_property(_swipe_arrows, "modulate:a", 1.0, loop * 0.4)
	_swipe_tween.tween_property(_swipe_dot, "modulate:a", 0.0, loop * 0.16)
	_swipe_tween.parallel().tween_property(_swipe_arrows, "modulate:a", 0.3, loop * 0.16)
	_swipe_tween.tween_interval(loop * 0.32)


static func _vignette_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(Palette.CORAL, 0.0), Color(Palette.CORAL, 0.0), Color(Palette.CORAL, 1.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.1, 0.5)
	tex.width = 256
	tex.height = 256
	return tex
