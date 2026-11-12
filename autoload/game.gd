extends Node
## The game flow: boot, screens, levels, swipes, ceremonies and results.
## main.gd calls boot() after all autoloads are ready. Touch, keys and the harness share one swipe path.

const Palette := preload("res://scripts/core/palette.gd")
const LevelsData := preload("res://scripts/core/levels_data.gd")
const LevelParser := preload("res://scripts/core/level_parser.gd")
const ParData := preload("res://scripts/core/par_data.gd")
const Session := preload("res://scripts/core/session.gd")
const ScoreRules := preload("res://scripts/core/score_rules.gd")
const Strings := preload("res://scripts/ui/strings.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiTuning := preload("res://scripts/ui/ui_tuning.gd")
const TextureBank := preload("res://scripts/board/texture_bank.gd")
const Background := preload("res://scripts/board/background.gd")
const BoardView := preload("res://scripts/board/board_view.gd")
const DemoBoard := preload("res://scripts/board/demo_board.gd")
const FxPool := preload("res://scripts/board/fx_pool.gd")
const SwipeInput := preload("res://scripts/input/swipe_input.gd")
const HomeScreen := preload("res://scripts/ui/home_screen.gd")
const LevelSelectScreen := preload("res://scripts/ui/level_select_screen.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const PauseDialog := preload("res://scripts/ui/pause_dialog.gd")
const ResultCard := preload("res://scripts/ui/result_card.gd")
const DefeatCard := preload("res://scripts/ui/defeat_card.gd")

const ACTIONS := {
	&"swipe_up": [KEY_UP, KEY_W],
	&"swipe_down": [KEY_DOWN, KEY_S],
	&"swipe_left": [KEY_LEFT, KEY_A],
	&"swipe_right": [KEY_RIGHT, KEY_D],
	&"restart": [KEY_R],
	&"pause": [KEY_ESCAPE, KEY_P],
	&"toggle_perf": [KEY_F3],
}
const DIR_ACTIONS: Array[StringName] = [&"swipe_up", &"swipe_down", &"swipe_left", &"swipe_right"]

const UI_LAYER := 10
const COVER_LAYER := 50
const COVER_FADE_TIME := 0.3
const QUIT_AUDIO_DRAIN := 0.15
## The demo board sits between the Home title and the Home buttons.
const DEMO_TOP := 380.0
const DEMO_BOTTOM := 360.0
const DEMO_WIDTH := 640.0

var screen: StringName = &""
var level_index := -1

var _booted := false
var _host: Node
var _board: Node2D
var _demo: Node2D
var _background: Control
var _input: Node
var _home: Control
var _levels: Control
var _hud: Control
var _pause: Control
var _result: Control
var _defeat: Control

var _rng := RandomNumberGenerator.new()
var _level: RefCounted
var _session: RefCounted
## &"off" outside a level, then &"intro", &"play", &"ceremony", &"card".
var _phase: StringName = &"off"
var _swiping := false
var _queued := -1
var _last_outcome := {}
var _paused := false
var _time_start := 0
var _time_end := 0
var _pause_since := 0
var _pause_total := 0
var _card_serial := 0
var _quitting := false
## The tension state last sent on the Bus.
var _tense_on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	_register_actions()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			quit(0)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_back(true)
		NOTIFICATION_APPLICATION_PAUSED:
			if _in_play():
				set_paused(true)
			Save.flush()


func _unhandled_input(event: InputEvent) -> void:
	if not _booted or event is InputEventMouse or event is InputEventScreenDrag or event is InputEventScreenTouch:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_back(false)
	elif event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		if not _paused and _phase != &"off":
			restart()
	else:
		for dir in DIR_ACTIONS.size():
			if event.is_action_pressed(DIR_ACTIONS[dir]):
				get_viewport().set_input_as_handled()
				request_swipe(dir)
				return


# --- Boot --------------------------------------------------------------------

## Builds the game under `host` behind a boot cover, warms up, then opens Home.
func boot(host: Node) -> void:
	_host = host
	var seed_arg := Harness.arg("seed")
	if seed_arg != "":
		_rng.seed = seed_arg.to_int()
	else:
		_rng.randomize()
	get_tree().root.theme = UiTheme.build()
	ThemeDB.fallback_font = UiTheme.font(UiTuning.WEIGHT_BODY)
	var cover := _make_cover()
	var cover_start := Time.get_ticks_msec()

	var bank := TextureBank.new()
	host.add_child(bank)
	await bank.bake()

	var back := CanvasLayer.new()
	back.layer = -1
	host.add_child(back)
	_background = Background.new()
	back.add_child(_background)

	var world := Node2D.new()
	world.name = "World"
	host.add_child(world)
	_demo = DemoBoard.new()
	_demo.visible = false
	world.add_child(_demo)
	_board = BoardView.new()
	_board.visible = false
	world.add_child(_board)
	_board.player.finished.connect(_on_swipe_played)
	_board.intro_finished.connect(_on_intro_finished)
	_board.restart_finished.connect(_on_intro_finished)
	_board.ceremonies.finished.connect(_on_ceremony_finished)

	var ui := CanvasLayer.new()
	ui.layer = UI_LAYER
	host.add_child(ui)
	_hud = Hud.new()
	_home = HomeScreen.new()
	_levels = LevelSelectScreen.new()
	_result = ResultCard.new()
	_defeat = DefeatCard.new()
	_pause = PauseDialog.new()
	for node: Control in [_hud, _home, _levels, _result, _defeat, _pause]:
		ui.add_child(node)
	_hud.board_rect_changed.connect(_on_board_rect_changed)

	_input = SwipeInput.new()
	host.add_child(_input)
	_input.swiped.connect(request_swipe)
	_input.tapped.connect(_on_tapped)

	_apply_perf_option(&"particles", PerfPanel.option(&"particles"))
	_apply_perf_option(&"glow", PerfPanel.option(&"glow"))
	_apply_perf_option(&"background", PerfPanel.option(&"background"))
	PerfPanel.option_changed.connect(_apply_perf_option)
	get_tree().root.size_changed.connect(_on_window_resized)

	await _warm_up(ui)
	var left := Tuning.BOOT_COVER_MIN_TIME - (Time.get_ticks_msec() - cover_start) / 1000.0
	if left > 0.0:
		await get_tree().create_timer(left, true, false, true).timeout
	_booted = true
	open_home()
	var fade := cover.create_tween()
	fade.tween_property(cover.get_child(0), "modulate:a", 0.0, COVER_FADE_TIME)
	fade.tween_callback(cover.queue_free)
	Music.start()


func _make_cover() -> CanvasLayer:
	var cover := CanvasLayer.new()
	cover.layer = COVER_LAYER
	_host.add_child(cover)
	var face := ColorRect.new()
	face.color = Palette.CREAM
	face.mouse_filter = Control.MOUSE_FILTER_STOP
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(face)
	var title := UiTheme.label(Strings.t("app_title"), UiTuning.SIZE_TITLE - 24, UiTuning.WEIGHT_TITLE, Palette.INK, HORIZONTAL_ALIGNMENT_CENTER)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.add_child(title)
	return cover


## Behind the cover: one silent play of each effect, one emit of each emitter, the scrim,
## the HUD with its vignette, and the glyphs of all strings at each used size and weight.
func _warm_up(ui: CanvasLayer) -> void:
	Sfx.warm_up()
	var missing: PackedStringArray = Sfx.missing()
	if not missing.is_empty():
		push_error("Game: audio files did not load: %s" % ", ".join(missing))

	var level := LevelParser.parse(LevelsData.LEVELS[LevelsData.LEVELS.size() - 1], LevelsData.LEVELS.size() - 1)
	var hues := Palette.pick_block_hues(level.starts.size(), _rng)
	_board.build(level, hues)
	_board.fit(get_viewport().get_visible_rect())
	_board.visible = true
	_board.set_scrim_now(true)
	var center: Vector2 = _board.cell_pos(level.starts[0])
	var fx: Node = _board.fx
	fx.splash(center, 0, Palette.BODY[hues[0]], 6)
	fx.impact_ring(center, Palette.BODY[hues[0]], 1.0)
	fx.rail_spark(center)
	fx.ring_glitter(_board.ring_points(_board.rings_from(level.starts[0])[0]), hues[0])
	fx.burst(Vector2.ZERO, hues)
	for b in level.starts.size():
		fx.streak_on(b, true)
	_hud.open()

	var text := ""
	for key: String in Strings.TABLE:
		for c in String(Strings.TABLE[key]):
			if not text.contains(c):
				text += c
	text += "0123456789"
	var glyphs := VBoxContainer.new()
	glyphs.modulate.a = 0.01
	ui.add_child(glyphs)
	var sizes := [UiTuning.SIZE_TITLE, UiTuning.SIZE_STAT, UiTuning.SIZE_HEADING, UiTuning.SIZE_COUNTER, UiTuning.SIZE_BUTTON,
		UiTuning.SIZE_BODY + 2, UiTuning.SIZE_BODY, UiTuning.SIZE_SMALL + 2, UiTuning.SIZE_SMALL,
		UiTuning.SIZE_TINY + 2, UiTuning.SIZE_TINY + 1, UiTuning.SIZE_TINY]
	for weight in [UiTuning.WEIGHT_BODY, UiTuning.WEIGHT_BOLD, UiTuning.WEIGHT_TITLE]:
		for size: int in sizes:
			glyphs.add_child(UiTheme.label(text, size, weight))

	for i in 3:
		await get_tree().process_frame
	glyphs.queue_free()
	for b in level.starts.size():
		fx.streak_on(b, false)
	fx.clear()
	_board.set_scrim_now(false)
	_board.visible = false
	_hud.close()


func _register_actions() -> void:
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode: int in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode as Key
			InputMap.action_add_event(action, event)


# --- Screens -----------------------------------------------------------------

func open_home() -> void:
	if not _booted:
		return
	_leave_level()
	_levels.close()
	_demo.visible = true
	_demo.start(_demo_rect())
	_home.open()
	_set_screen(&"home")


func open_levels() -> void:
	if not _booted:
		return
	_leave_level()
	_home.close()
	_demo.stop()
	_demo.visible = false
	_levels.open()
	_set_screen(&"levels")


func start_level(index: int) -> void:
	if not _booted or index < 0 or index >= LevelsData.LEVELS.size():
		return
	_leave_level()
	_home.close()
	_levels.close()
	_demo.stop()
	_demo.visible = false
	level_index = index
	_level = LevelParser.parse(LevelsData.LEVELS[index], index)
	var hues := _pick_hues()
	_new_session(hues)
	_board.build(_level, hues)
	_board.visible = true
	_hud.open()
	Bus.level_loaded.emit(index)
	Bus.session_changed.emit(_session.snapshot())
	_set_screen(&"level")
	_phase = &"intro"
	# The HUD lays out its board area on the next frame.
	_board.modulate.a = 0.0
	await get_tree().process_frame
	if _level == null or level_index != index or _phase != &"intro":
		return
	_board.modulate.a = 1.0
	_board.fit(_hud.board_rect())
	_board.play_intro()


func restart() -> void:
	if not _booted or _level == null or _phase == &"off":
		return
	if _paused:
		_set_pause_state(false)
	_result.close()
	_defeat.close()
	var hues := _pick_hues()
	_new_session(hues)
	_phase = &"intro"
	_board.play_restart(hues)
	Bus.level_restarted.emit(level_index)
	_set_tension(false)
	Bus.session_changed.emit(_session.snapshot())
	if screen != &"level":
		_set_screen(&"level")


func next_level() -> void:
	if level_index + 1 < LevelsData.LEVELS.size():
		start_level(level_index + 1)


func set_paused(on: bool) -> void:
	if not _booted or on == _paused:
		return
	if on and not (screen == &"level" and _phase != &"off" and _phase != &"card"):
		return
	_set_pause_state(on)


func request_swipe(dir: int) -> void:
	if _phase != &"play" or _paused or _session == null or dir < 0 or dir > 3:
		return
	if _session.status == &"won" or _session.status == &"lost":
		return
	if _swiping:
		_queued = dir
		_board.player.speed_scale = Tuning.Board.BUFFERED_SPEED
		return
	_play_swipe(dir)


func skip_ceremony() -> void:
	if _phase == &"ceremony":
		_board.ceremonies.skip()
	elif _phase == &"card":
		if _result.is_open:
			_result.skip()
		if _defeat.is_open:
			_defeat.skip()


## Stops the audio, gives the audio server time to free its voices, then quits.
## Without the wait, a quit during a sound leaks the playing voices.
func quit(code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	Save.flush()
	Sfx.silence()
	Music.stop()
	await get_tree().create_timer(QUIT_AUDIO_DRAIN, true, false, true).timeout
	get_tree().quit(code)


func snapshot() -> Dictionary:
	if _session == null or _phase == &"off":
		return {"screen": screen}
	var data: Dictionary = _session.snapshot()
	data["screen"] = screen
	data["time_ms"] = _elapsed_ms()
	data["paused"] = _paused
	return data


# --- Level flow --------------------------------------------------------------

func _new_session(hues: PackedInt32Array) -> void:
	var par: Dictionary = ParData.PAR[_level.id]
	_session = Session.new(_level, int(par.min), hues)
	_swiping = false
	_queued = -1
	_last_outcome = {}
	_time_start = 0
	_time_end = 0
	_pause_total = 0
	_board.player.speed_scale = 1.0


func _pick_hues() -> PackedInt32Array:
	return Palette.pick_block_hues(_level.starts.size(), _rng)


func _play_swipe(dir: int) -> void:
	var outcome: Dictionary = _session.swipe(dir)
	if outcome.ignored:
		return
	_swiping = true
	_last_outcome = outcome
	if outcome.counted:
		if _time_start == 0:
			_time_start = Time.get_ticks_msec()
		Bus.session_changed.emit(_session.snapshot())
		if outcome.tier_dropped:
			Bus.star_lost.emit(int(outcome.stars))
		# On the losing move the tension stays until the defeat ceremony starts.
		if outcome.tense_changed and outcome.status != &"lost":
			_set_tension(bool(outcome.tense))
		if outcome.status == &"won" or outcome.status == &"lost":
			_queued = -1
	_board.player.play(outcome)


func _on_swipe_played(outcome: Dictionary) -> void:
	if _phase != &"play" or not is_same(outcome, _last_outcome):
		return
	_swiping = false
	_board.player.speed_scale = 1.0
	var status: StringName = _session.status
	if status == &"won" or status == &"lost":
		_end_level(status)
	elif _queued >= 0:
		var dir := _queued
		_queued = -1
		_play_swipe(dir)


func _on_intro_finished() -> void:
	if _phase != &"intro":
		return
	_phase = &"play"
	Bus.level_ready.emit(level_index)


func _end_level(status: StringName) -> void:
	_phase = &"ceremony"
	_queued = -1
	_time_end = Time.get_ticks_msec()
	if status == &"won":
		_board.ceremonies.play_win(int(_last_outcome.get("last_cell", -1)))
	else:
		_board.ceremonies.play_defeat()
		_set_tension(false)


func _on_ceremony_finished(_kind: StringName) -> void:
	if _phase != &"ceremony":
		return
	_phase = &"card"
	var won: bool = _session.status == &"won"
	var summary := _summary(won)
	if won:
		var next := level_index + 1
		var was_open := next < LevelsData.LEVELS.size() and Save.is_unlocked(next)
		var rec := Save.record(_level.id, int(summary.stars), int(summary.moves), int(summary.time_ms))
		summary["new_best"] = bool(rec.get("new_best", false))
		summary["next_unlocked"] = next < LevelsData.LEVELS.size() and Save.is_unlocked(next)
		if summary.next_unlocked and not was_open:
			Bus.level_unlocked.emit(next)
		Bus.level_won.emit(summary)
	else:
		Bus.level_lost.emit(summary)
	# One dim behind the card: the card scrim replaces the ceremony scrim.
	_board.show_scrim(false)
	var card: Control = _result if won else _defeat
	var value: StringName = &"result" if won else &"defeat"
	card.use_scrim = true
	_card_serial += 1
	card.opened.connect(_on_card_opened.bind(value, _card_serial), CONNECT_ONE_SHOT)
	card.open(summary)
	screen = value


## The card screen is announced when the card is at rest, so the harness events see the final card.
func _on_card_opened(value: StringName, serial: int) -> void:
	if serial == _card_serial and screen == value and _phase == &"card":
		Bus.screen_changed.emit(value)


func _summary(won: bool) -> Dictionary:
	var t: Dictionary = _session.thresholds
	var stars: int = _session.stars() if won else 0
	var span: Vector2i = ScoreRules.range_for(stars, t) if won else Vector2i(0, 0)
	var next := level_index + 1
	return {
		"level_index": level_index, "level_id": _level.id, "status": _session.status,
		"moves": _session.moves_used, "stars": stars, "range_lo": span.x, "range_hi": span.y,
		"time_ms": _elapsed_ms(), "min": t.min, "three_max": t.three_max, "two_max": t.two_max, "limit": t.limit,
		"painted": _session.painted_count, "floor": _level.floor_count,
		"new_best": false, "is_last": next >= LevelsData.LEVELS.size(),
		"next_unlocked": next < LevelsData.LEVELS.size() and Save.is_unlocked(next),
	}


## Closes the level screens and stops the board. No effect outside a level.
func _leave_level() -> void:
	if _paused:
		_set_pause_state(false)
	if _phase == &"off":
		return
	_phase = &"off"
	_swiping = false
	_queued = -1
	_board.player.stop()
	_board.ceremonies.stop()
	_board.set_scrim_now(false)
	_board.visible = false
	_hud.close()
	_result.close()
	_defeat.close()
	_session = null
	_level = null
	_set_tension(false)
	Music.unduck(Tuning.Audio.UNDUCK_TIME)


func _set_tension(on: bool) -> void:
	if on == _tense_on:
		return
	_tense_on = on
	Bus.tension_changed.emit(on)


func _set_screen(value: StringName) -> void:
	screen = value
	if value != &"level" and value != &"result" and value != &"defeat":
		Music.set_fill(1.0)
	Bus.screen_changed.emit(value)


func _set_pause_state(on: bool) -> void:
	_paused = on
	get_tree().paused = on
	if on:
		_pause_since = Time.get_ticks_msec()
		_pause.open()
	else:
		if _pause_since > 0:
			_pause_total += Time.get_ticks_msec() - _pause_since
		_pause_since = 0
		_pause.close()
	Bus.paused_changed.emit(on)


func _elapsed_ms() -> int:
	if _time_start == 0:
		return 0
	var end := _time_end if _time_end > 0 else Time.get_ticks_msec()
	var paused_now := 0
	if _pause_since > 0 and _time_end == 0:
		paused_now = Time.get_ticks_msec() - _pause_since
	return maxi(end - _time_start - _pause_total - paused_now, 0)


func _in_play() -> bool:
	return screen == &"level" and (_phase == &"intro" or _phase == &"play" or _phase == &"ceremony")


## Esc, P and the Android back key: the pause dialog in a level, one screen back elsewhere.
## The back key on Home quits the app; Esc on Home does nothing.
func _back(system: bool) -> void:
	if not _booted:
		return
	if PerfPanel.is_open():
		PerfPanel.toggle()
		return
	match screen:
		&"level":
			set_paused(not _paused)
		&"result", &"defeat":
			open_levels()
		&"levels":
			open_home()
		&"home":
			if system:
				quit(0)


func _on_tapped() -> void:
	if _phase == &"ceremony" and not _paused:
		_board.ceremonies.skip()


# --- Layout and options ------------------------------------------------------

func _on_board_rect_changed(rect: Rect2) -> void:
	if _phase != &"off" and _board.visible:
		_board.fit(rect)


func _on_window_resized() -> void:
	if screen == &"home" and _demo.visible:
		_demo.fit(_demo_rect())


func _demo_rect() -> Rect2:
	var view := _host.get_viewport().get_visible_rect()
	var width := minf(DEMO_WIDTH, view.size.x - UiTuning.GUTTER * 2.0)
	var top := view.position.y + DEMO_TOP
	var height := maxf(view.size.y - DEMO_TOP - DEMO_BOTTOM, 200.0)
	return Rect2(view.get_center().x - width / 2.0, top, width, height)


func _apply_perf_option(key: StringName, value: bool) -> void:
	match key:
		&"particles":
			FxPool.set_particles_enabled(value)
		&"glow":
			FxPool.set_glow_enabled(value)
		&"background":
			Background.decor_enabled = value
			if _background != null:
				_background.set_decor_enabled(value)
