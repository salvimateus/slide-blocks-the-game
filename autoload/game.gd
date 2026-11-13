extends Node
## The game flow: boot, screens, levels, swipes, ceremonies and results, the one-jelly mode, the random level job
## and the replay of the last game. main.gd calls boot() after all autoloads are ready.
## Touch, keys and the harness share one swipe path. A replay plays on the board with no rule-time signal.
## A theme change (Bus.theme_changed) builds the visuals again behind a cover and opens the same screen again.

const Palette := preload("res://scripts/core/palette.gd")
const LevelsData := preload("res://scripts/core/levels_data.gd")
const LevelParser := preload("res://scripts/core/level_parser.gd")
const ParData := preload("res://scripts/core/par_data.gd")
const Session := preload("res://scripts/core/session.gd")
const ScoreRules := preload("res://scripts/core/score_rules.gd")
const LevelModes := preload("res://scripts/core/level_modes.gd")
const RandomLevel := preload("res://scripts/core/random_level.gd")
const Strings := preload("res://scripts/ui/strings.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiTuning := preload("res://scripts/ui/ui_tuning.gd")
const TextureBank := preload("res://scripts/board/texture_bank.gd")
const Background := preload("res://scripts/board/background.gd")
const BoardView := preload("res://scripts/board/board_view.gd")
const DemoBoard := preload("res://scripts/board/demo_board.gd")
const FxPool := preload("res://scripts/board/fx_pool.gd")
const ReplayRunner := preload("res://scripts/board/replay_runner.gd")
const SwipeInput := preload("res://scripts/input/swipe_input.gd")
const HomeScreen := preload("res://scripts/ui/home_screen.gd")
const LevelSelectScreen := preload("res://scripts/ui/level_select_screen.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const PauseDialog := preload("res://scripts/ui/pause_dialog.gd")
const ResultCard := preload("res://scripts/ui/result_card.gd")
const DefeatCard := preload("res://scripts/ui/defeat_card.gd")
const LoadingScreen := preload("res://scripts/ui/loading_screen.gd")
const ReplayOverlay := preload("res://scripts/ui/replay_overlay.gd")
const UiBake := preload("res://scripts/ui/ui_bake.gd")

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
const THEME_COVER_IN_TIME := 0.18
const THEME_COVER_BLEND_TIME := 0.15
## Frames to wait for the baker, or for the reopened screen to come to rest, after a theme change.
const THEME_WAIT_FRAMES := 240
const QUIT_AUDIO_DRAIN := 0.15
## The demo board sits between the Home title and the Home buttons.
const DEMO_TOP := 380.0
const DEMO_BOTTOM := 360.0
const DEMO_WIDTH := 640.0

var screen: StringName = &""
var level_index := -1

var _booted := false
var _host: Node
var _bank: Node
var _back_layer: CanvasLayer
var _ui: CanvasLayer
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
var _loading: Control
var _replay_overlay: Control
var _replay: Node

var _rng := RandomNumberGenerator.new()
var _level: RefCounted
var _session: RefCounted
## {"min", "solution"} of the current level.
var _par: Dictionary = {}
## &"normal", &"solo" or &"random".
var _mode: StringName = &"normal"
var _seed := 0
## The block rule of the current random level: true for one block.
var _random_solo := false
## &"off" outside a level, then &"intro", &"play", &"ceremony", &"card", and &"replay" while a replay plays over the card.
var _phase: StringName = &"off"
var _swiping := false
var _queued := -1
var _last_outcome := {}
var _paused := false
var _time_start := 0
var _time_end := 0
var _pause_since := 0
var _pause_total := 0
var _announce_serial := 0
var _announce_pending := false
var _quitting := false
var _cover_up := false
## The tension state last sent on the Bus.
var _tense_on := false
## The summary that the open result or defeat card shows.
var _card_summary := {}
## The level info of the last Bus.level_loaded, the seed of the random level job and the last replay step,
## so a theme change can show them again.
var _level_info := {}
var _job_seed := 0
var _replay_n := 0
var _replay_total := 0
## The Palette theme of the visuals that are on screen, and true while a theme change runs.
var _built_theme: StringName = &""
var _theme_busy := false
## False until the screen that a theme change opens again comes to rest.
var _at_rest := true

# Replay.
var _replay_card: Control
## The end of a replay waits for its card to be at rest; restart, leave and a new replay send it at once.
var _replay_end_pending := false
var _replay_end_completed := false
var _replay_end_matched := false

# Random level job.
var _job_active := false
var _job_serial := 0
var _job_cancel: RefCounted
var _job_prev_screen: StringName = &""
var _threads: Array[Thread] = []
var _random_hold_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	_register_actions()
	Bus.theme_changed.connect(_on_theme_changed)


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
	if not _booted or _theme_busy or event is InputEventMouse or event is InputEventScreenDrag or event is InputEventScreenTouch:
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
	Palette.apply(Save.theme())
	_built_theme = Palette.theme
	get_tree().root.theme = UiTheme.build()
	ThemeDB.fallback_font = UiTheme.font(UiTuning.WEIGHT_BODY)
	var cover := _make_cover()
	var cover_start := Time.get_ticks_msec()

	host.add_child(UiBake.new())
	_bank = TextureBank.new()
	host.add_child(_bank)
	await _bank.bake()

	_back_layer = CanvasLayer.new()
	_back_layer.layer = -1
	host.add_child(_back_layer)
	_background = Background.new()
	_back_layer.add_child(_background)

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
	_replay = ReplayRunner.new()
	world.add_child(_replay)
	_replay.setup(_board)
	_replay.stepped.connect(_on_replay_stepped)
	_replay.finished.connect(_on_replay_finished)

	_ui = CanvasLayer.new()
	_ui.layer = UI_LAYER
	host.add_child(_ui)
	_make_screens()

	_input = SwipeInput.new()
	host.add_child(_input)
	_input.swiped.connect(request_swipe)
	_input.tapped.connect(_on_tapped)

	_apply_perf_option(&"particles", PerfPanel.option(&"particles"))
	_apply_perf_option(&"glow", PerfPanel.option(&"glow"))
	_apply_perf_option(&"background", PerfPanel.option(&"background"))
	PerfPanel.option_changed.connect(_apply_perf_option)
	get_tree().root.size_changed.connect(_on_window_resized)

	await _warm_up(_ui)
	var left := Tuning.BOOT_COVER_MIN_TIME - (Time.get_ticks_msec() - cover_start) / 1000.0
	if left > 0.0:
		await get_tree().create_timer(left, true, false, true).timeout
	_booted = true
	# The first screen is announced when the cover is gone and Home is at rest, so the harness never acts below it.
	_cover_up = true
	open_home()
	var fade := cover.create_tween()
	fade.tween_property(cover.get_child(0), "modulate:a", 0.0, COVER_FADE_TIME)
	fade.tween_callback(cover.queue_free)
	fade.tween_callback(_on_cover_gone)
	Music.start()
	# A theme change during the boot builds again now.
	if Save.theme() != _built_theme:
		_switch_theme()


func _on_cover_gone() -> void:
	_cover_up = false
	if _announce_pending:
		_announce_pending = false
		Bus.screen_changed.emit(screen)


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
## the HUD with its vignette, the glyphs of all strings at each used size and weight, and the UI bake.
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

	var text := Strings.all_text() + "0123456789"
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
	await _warm_up_bake(level, hues)
	_hide_now(_hud)


func _make_screens() -> void:
	_hud = Hud.new()
	_home = HomeScreen.new()
	_levels = LevelSelectScreen.new()
	_result = ResultCard.new()
	_defeat = DefeatCard.new()
	_pause = PauseDialog.new()
	_replay_overlay = ReplayOverlay.new()
	_loading = LoadingScreen.new()
	for node: Control in [_hud, _replay_overlay, _home, _levels, _result, _defeat, _pause, _loading]:
		_ui.add_child(node)
	_hud.board_rect_changed.connect(_on_board_rect_changed)
	_replay_overlay.stop_requested.connect(stop_replay)
	_loading.cancel_requested.connect(cancel_random)
	_loading.opened.connect(_on_loading_opened)
	_result.opened.connect(_emit_replay_end)
	_defeat.opened.connect(_emit_replay_end)


## Hides a screen at once, with no fade, so nothing of the warm-up shows when the cover lifts.
func _hide_now(node: Control) -> void:
	node.call("_kill_screen_tween")
	node.is_open = false
	node.visible = false
	node.modulate.a = 1.0
	node.position = Vector2.ZERO


## Shows each screen at almost zero opacity, with sample data, so the baker draws every icon,
## thumbnail and title letter before the cover lifts.
func _warm_up_bake(level: RefCounted, hues: PackedInt32Array) -> void:
	var par: Dictionary = ParData.PAR[level.id]
	var session: RefCounted = Session.new(level, int(par.min), hues)
	var t: Dictionary = session.thresholds
	var sample := {
		"level_index": level.index, "level_id": level.id, "status": &"won", "moves": t.min, "stars": 3,
		"range_lo": t.min, "range_hi": t.three_max, "time_ms": 0, "min": t.min, "three_max": t.three_max,
		"two_max": t.two_max, "limit": t.limit, "painted": level.floor_count, "floor": level.floor_count,
		"new_best": true, "is_last": false, "next_unlocked": true, "mode": &"normal", "seed": 0, "can_replay": true,
	}
	_hud.call("_on_session_changed", session.snapshot())
	_result.call("_fill", sample)
	_defeat.call("_fill", sample)
	_pause.call("_fill", {"solo": &"ready", "mode_solo": false})
	# The HUD is open at boot. After a theme change it is new and hidden, so it shows here with the screens.
	var screens: Array[Control] = [_home, _levels, _result, _defeat, _pause, _replay_overlay, _loading]
	if not _hud.visible:
		screens.append(_hud)
	for node in screens:
		node.visible = true
		node.modulate.a = 0.01
	for i in 2:
		await get_tree().process_frame
	for node: Control in screens:
		_prewarm_tree(node)
	if not screens.has(_hud):
		_prewarm_tree(_hud)
	# The rows of a random level show only then: lay them out and ask for their icons too.
	var random_sample := sample.duplicate()
	random_sample.merge({"mode": &"random", "level_index": -1, "seed": RandomLevel.SEED_MAX, "next_unlocked": false}, true)
	_result.call("_fill", random_sample)
	_defeat.call("_fill", random_sample)
	for i in 2:
		await get_tree().process_frame
	_prewarm_tree(_result)
	_prewarm_tree(_defeat)
	var frames := 0
	while not UiBake.is_idle() and frames < 240:
		await get_tree().process_frame
		frames += 1
	for node in screens:
		_hide_now(node)


func _prewarm_tree(node: Node) -> void:
	if node.has_method("prewarm"):
		node.call("prewarm")
	for child in node.get_children():
		_prewarm_tree(child)


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
	if _job_active:
		cancel_random()
	_leave_level()
	_levels.close()
	_demo.visible = true
	_demo.start(_demo_rect())
	_home.open()
	_set_screen(&"home", false)
	_announce_on_open(_home, &"home")


## Opens the level select screen. A `page` below 0 opens the page of the highest open level.
func open_levels(page: int = -1) -> void:
	if not _booted:
		return
	if _job_active:
		cancel_random()
	_leave_level()
	_home.close()
	_demo.stop()
	_demo.visible = false
	if page >= 0:
		_levels.open({"page": page})
	else:
		_levels.open()
	_set_screen(&"levels", false)
	_announce_on_open(_levels, &"levels")


## Starts a level of LevelsData in the mode of the `solo` setting: its one-jelly version when it has one.
func start_level(index: int) -> void:
	if not _booted or index < 0 or index >= LevelsData.LEVELS.size():
		return
	if _job_active:
		cancel_random()
	var solo: bool = Save.setting(&"solo")
	var level := LevelParser.parse(LevelModes.def_for(index, solo), index)
	_begin_level(level, LevelModes.par_for(level.id), index, LevelModes.info(index, solo))


## Makes the random level of `seed_value` on a worker thread, then starts it. A seed below
## RandomLevel.SEED_MIN takes a new seed. The block rule follows the `solo` setting.
## The screen below stays open; the loading screen blocks input, and shows only when the job takes time.
func start_random(seed_value: int = -1) -> void:
	if not _booted or _job_active or _phase == &"replay":
		return
	var seed_used := seed_value
	if seed_used < RandomLevel.SEED_MIN:
		seed_used = _rng.randi_range(RandomLevel.SEED_MIN, RandomLevel.SEED_MAX)
	_job_prev_screen = screen
	_job_active = true
	_job_seed = seed_used
	_job_serial += 1
	_job_cancel = RandomLevel.Cancel.new()
	var serial := _job_serial
	var thread := Thread.new()
	_threads.append(thread)
	thread.start(_run_job.bind(serial, seed_used, bool(Save.setting(&"solo")), _job_cancel, thread))
	_loading.open({"seed": seed_used})
	get_tree().create_timer(UiTuning.RANDOM_LOADING_DELAY, true, false, true).timeout.connect(_reveal_loading.bind(serial))


## Stops the random level job. The screen below the loading screen stays as it was.
func cancel_random() -> void:
	if not _job_active:
		return
	_job_cancel.cancelled = true
	_job_active = false
	_job_serial += 1
	_close_loading()
	screen = _job_prev_screen


## Holds a ready random level this long before it starts, so a run can see the loading screen. Harness only.
func set_random_hold(ms: int) -> void:
	_random_hold_ms = maxi(ms, 0)


func restart() -> void:
	if not _booted or _level == null or _phase == &"off" or _job_active:
		return
	_abort_replay(true)
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
	if _mode == &"random":
		return
	if level_index + 1 < LevelsData.LEVELS.size():
		start_level(level_index + 1)


## A change of the `solo` setting in the pause dialog applies when the play goes on: the level starts again in the new mode.
func set_paused(on: bool) -> void:
	if not _booted or on == _paused:
		return
	if on and not (screen == &"level" and _phase != &"off" and _phase != &"card"):
		return
	_set_pause_state(on)
	if on or not _mode_change_pending():
		return
	if _mode == &"random":
		start_random(_seed)
	else:
		start_level(level_index)


func request_swipe(dir: int) -> void:
	if _phase != &"play" or _paused or _theme_busy or _session == null or dir < 0 or dir > 3:
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


## True when the open card can show a replay of its game.
func can_replay() -> bool:
	return _phase == &"card" and _session != null and _session.history != "" and not _job_active and not _paused


## Plays the moves of the last game on the board, from its start state, over the card. The card returns at the end.
func play_replay() -> void:
	if not can_replay():
		return
	_emit_replay_end()
	_replay_card = _result if _result.is_open else _defeat
	var total: int = _session.history.length()
	_replay_card.close()
	_hud.close()
	_replay_n = 0
	_replay_total = total
	_phase = &"replay"
	_set_screen(&"replay", false)
	_replay_overlay.open({"total": total})
	Bus.replay_started.emit(total)
	_replay.play(_level, _session.hues, int(_par.min), _session.history)


## Ends the replay where it is; the card returns.
func stop_replay() -> void:
	if _phase == &"replay":
		_replay.stop()


## The moves of the baked or generated solution of the current level, "" outside a level.
func current_solution() -> String:
	return String(_par.get("solution", ""))


## Stops the audio, gives the audio server time to free its voices, then quits.
## Without the wait, a quit during a sound leaks the playing voices.
func quit(code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	if _job_cancel != null:
		_job_cancel.cancelled = true
	_job_active = false
	for thread in _threads:
		if thread.is_started():
			thread.wait_to_finish()
	_threads.clear()
	Save.flush()
	Sfx.silence()
	Music.stop()
	await get_tree().create_timer(QUIT_AUDIO_DRAIN, true, false, true).timeout
	get_tree().quit(code)


## The rect of a named button in base units of the viewport, for a scripted tap, or an empty rect when it is
## not on screen. Names: theme (the theme button of Home).
func button_rect(button: StringName) -> Rect2:
	var node: Control = null
	match button:
		&"theme":
			if screen == &"home" and _home.is_open:
				node = _home.theme_button
	if node == null or not node.is_visible_in_tree():
		return Rect2()
	return node.get_global_rect()


func snapshot() -> Dictionary:
	if _session == null or _phase == &"off":
		return {"screen": screen}
	var data: Dictionary = _session.snapshot()
	data["screen"] = screen
	data["time_ms"] = _elapsed_ms()
	data["paused"] = _paused
	data["mode"] = _mode
	data["seed"] = _seed
	return data


# --- Level flow --------------------------------------------------------------

## Builds `level` and plays its intro. `info` is the level info of Bus.level_loaded.
func _begin_level(level: RefCounted, par: Dictionary, index: int, info: Dictionary) -> void:
	_leave_level()
	_close_loading()
	_home.close()
	_levels.close()
	_demo.stop()
	_demo.visible = false
	level_index = index
	_level = level
	_par = par
	_mode = info.mode
	_level_info = info
	_seed = int(info.seed)
	_random_solo = bool(info.solo)
	var hues := _pick_hues()
	_new_session(hues)
	_board.build(_level, hues)
	_board.visible = true
	_hud.open()
	Bus.level_loaded.emit(index, info)
	Bus.session_changed.emit(_session.snapshot())
	_set_screen(&"level")
	_phase = &"intro"
	# The HUD lays out its board area on the next frame.
	_board.modulate.a = 0.0
	await get_tree().process_frame
	if not is_same(_level, level) or _phase != &"intro":
		return
	_board.modulate.a = 1.0
	_board.fit(_hud.board_rect())
	_board.play_intro()


func _new_session(hues: PackedInt32Array) -> void:
	_session = Session.new(_level, int(_par.min), hues)
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


## Game is the only caller of Save.record. A random level has no record and opens no level.
## A one-jelly win opens the next level as a normal win does.
func _on_ceremony_finished(_kind: StringName) -> void:
	if _phase != &"ceremony":
		return
	_phase = &"card"
	var won: bool = _session.status == &"won"
	var summary := _summary(won)
	if won:
		if _mode != &"random":
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
	_card_summary = summary
	card.open(summary)
	screen = value
	_announce_on_open(card, value)


## Home, level select and the cards are announced when the screen is at rest (and the boot cover is gone),
## so the harness events see only the final screen.
func _announce_on_open(node: Control, value: StringName) -> void:
	_announce_serial += 1
	node.opened.connect(_on_screen_opened.bind(value, _announce_serial), CONNECT_ONE_SHOT)


func _on_screen_opened(value: StringName, serial: int) -> void:
	if serial != _announce_serial or screen != value:
		return
	if _cover_up:
		_announce_pending = true
	else:
		Bus.screen_changed.emit(value)


func _summary(won: bool) -> Dictionary:
	var t: Dictionary = _session.thresholds
	var stars: int = _session.stars() if won else 0
	var span: Vector2i = ScoreRules.range_for(stars, t) if won else Vector2i(0, 0)
	var random := _mode == &"random"
	var next := level_index + 1
	return {
		"level_index": level_index, "level_id": _level.id, "status": _session.status,
		"moves": _session.moves_used, "stars": stars, "range_lo": span.x, "range_hi": span.y,
		"time_ms": _elapsed_ms(), "min": t.min, "three_max": t.three_max, "two_max": t.two_max, "limit": t.limit,
		"painted": _session.painted_count, "floor": _level.floor_count,
		"new_best": false, "is_last": not random and next >= LevelsData.LEVELS.size(),
		"next_unlocked": not random and next < LevelsData.LEVELS.size() and Save.is_unlocked(next),
		"mode": _mode, "seed": _seed, "can_replay": _session.history != "",
	}


## Closes the level screens and stops the board. No effect outside a level.
func _leave_level() -> void:
	_abort_replay(false)
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


func _set_screen(value: StringName, announce: bool = true) -> void:
	screen = value
	if not (value in [&"level", &"result", &"defeat", &"replay", &"loading"]):
		Music.set_fill(1.0)
	if announce and not _cover_up:
		Bus.screen_changed.emit(value)


func _set_pause_state(on: bool) -> void:
	_paused = on
	get_tree().paused = on
	if on:
		_pause_since = Time.get_ticks_msec()
		_pause.open(_pause_data())
	else:
		if _pause_since > 0:
			_pause_total += Time.get_ticks_msec() - _pause_since
		_pause_since = 0
		_pause.close()
	Bus.paused_changed.emit(on)


## {"solo": the one-jelly state of the level, "mode_solo": true when the level plays its one-jelly version}.
## A random level can always change its block rule.
func _pause_data() -> Dictionary:
	if _mode == &"random":
		return {"solo": &"ready", "mode_solo": _random_solo}
	return {"solo": LevelModes.solo_state(level_index), "mode_solo": _mode == &"solo"}


func _mode_change_pending() -> bool:
	if _level == null:
		return false
	var solo: bool = Save.setting(&"solo")
	if _mode == &"random":
		return solo != _random_solo
	if LevelModes.solo_state(level_index) != &"ready":
		return false
	return solo != (_mode == &"solo")


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
## The back key on Home quits the app; Esc on Home does nothing. A random level job and a replay stop first.
func _back(system: bool) -> void:
	if not _booted:
		return
	if PerfPanel.is_open():
		PerfPanel.toggle()
		return
	if _job_active:
		cancel_random()
		return
	match screen:
		&"level":
			set_paused(not _paused)
		&"replay":
			stop_replay()
		&"result", &"defeat":
			if _mode == &"random":
				open_home()
			else:
				open_levels()
		&"levels":
			open_home()
		&"home":
			if system:
				quit(0)


func _on_tapped() -> void:
	if _phase == &"ceremony" and not _paused:
		_board.ceremonies.skip()


# --- Replay ------------------------------------------------------------------

func _on_replay_stepped(n: int, total: int) -> void:
	if _phase != &"replay":
		return
	_replay_n = n
	_replay_total = total
	if not _theme_busy:
		_replay_overlay.set_step(n, total)
	Bus.replay_step.emit(n, total)


func _on_replay_finished(completed: bool, positions: PackedInt32Array, painted: int) -> void:
	# The screens are not there while a theme change builds them again.
	while _theme_busy:
		await get_tree().process_frame
	if _phase != &"replay":
		return
	_phase = &"card"
	_replay_overlay.close()
	_hud.open()
	screen = &"result" if _replay_card == _result else &"defeat"
	_replay_end_pending = true
	_replay_end_completed = completed
	_replay_end_matched = completed and positions == _session.positions and painted == _session.painted_count
	_replay_card.reopen()


## Sends the pending end of a replay; a card emits `opened` when it is at rest again.
func _emit_replay_end() -> void:
	if not _replay_end_pending:
		return
	_replay_end_pending = false
	Bus.replay_finished.emit(_replay_end_completed, _replay_end_matched)


## Ends a replay at once for a restart or a leave, with no card. `for_restart` opens the HUD again.
func _abort_replay(for_restart: bool) -> void:
	if _phase != &"replay":
		_emit_replay_end()
		return
	_phase = &"card"
	_replay.stop()
	_replay_overlay.close()
	if for_restart:
		_hud.open()
	Bus.replay_finished.emit(false, false)


# --- Random level ------------------------------------------------------------

## Runs on the worker thread: it reads no member and touches no node.
func _run_job(serial: int, seed_value: int, solo: bool, cancel: RefCounted, thread: Thread) -> void:
	var start := Time.get_ticks_msec()
	var result: Dictionary = RandomLevel.generate(seed_value, solo, cancel)
	result["ms"] = Time.get_ticks_msec() - start
	_on_job_done.call_deferred(serial, seed_value, result, thread)


func _on_job_done(serial: int, seed_value: int, result: Dictionary, thread: Thread) -> void:
	if thread.is_started():
		thread.wait_to_finish()
	_threads.erase(thread)
	if serial != _job_serial or not _job_active or result.has("cancelled"):
		return
	# The screens are not there while a theme change builds them again.
	while _theme_busy:
		await get_tree().process_frame
	if serial != _job_serial or not _job_active:
		return
	if result.size() <= 1:
		push_error("Game: no random level for seed %d" % seed_value)
		_job_active = false
		_close_loading()
		screen = _job_prev_screen
		return
	if _random_hold_ms > 0:
		await get_tree().create_timer(_random_hold_ms / 1000.0, true, false, true).timeout
		if serial != _job_serial or not _job_active:
			return
	while _theme_busy:
		await get_tree().process_frame
	if serial != _job_serial or not _job_active:
		return
	_job_active = false
	var level: RefCounted = result.level
	var t := ScoreRules.thresholds(int(result.min), RandomLevel.SCORE_INDEX)
	Bus.level_generated.emit({
		"seed": seed_value, "solo": result.solo, "blocks": result.blocks, "cols": level.cols, "rows": level.rows,
		"floor": level.floor_count, "deflectors": result.deflectors, "min": result.min, "three_max": t.three_max,
		"two_max": t.two_max, "limit": t.limit, "tension_moves": t.tension_moves, "states": result.states,
		"attempts": result.attempts, "ms": result.ms, "map": result.def.rows,
	})
	_begin_level(level, {"min": result.min, "solution": result.solution}, -1, {
		"mode": &"random", "index": -1, "seed": seed_value, "solo": result.solo, "name_key": "", "hint_key": "",
	})


func _reveal_loading(serial: int) -> void:
	if _job_active and serial == _job_serial:
		_loading.reveal()


func _on_loading_opened() -> void:
	if _job_active:
		_set_screen(&"loading")


func _close_loading() -> void:
	if _loading.is_open:
		_loading.close()


# --- Theme -------------------------------------------------------------------

func _on_theme_changed(_theme: StringName) -> void:
	if _booted and not _theme_busy:
		_switch_theme()


## Fades in a cover in the old colors, applies Save.theme() to the Palette, builds the Theme, the atlases,
## the background, the tray and the screens again, opens the same screen in the same state, then lifts the cover.
## The Palette changes only below the cover, so no frame shows parts of two themes.
## A change that comes while this runs starts one more pass at the end.
func _switch_theme() -> void:
	_theme_busy = true
	var old_cream := Palette.CREAM
	var cover := CanvasLayer.new()
	cover.layer = COVER_LAYER
	cover.process_mode = Node.PROCESS_MODE_ALWAYS
	_host.add_child(cover)
	var face := ColorRect.new()
	face.color = Color(old_cream, 0.0)
	face.mouse_filter = Control.MOUSE_FILTER_STOP
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(face)
	var fade := cover.create_tween()
	fade.tween_property(face, "color:a", 1.0, THEME_COVER_IN_TIME)
	await fade.finished

	while Save.theme() != _built_theme:
		_built_theme = Save.theme()
		Palette.apply(_built_theme)
		await _rebuild_visuals()

	var lift := cover.create_tween()
	lift.tween_property(face, "color", Palette.CREAM, THEME_COVER_BLEND_TIME)
	lift.tween_property(face, "color:a", 0.0, COVER_FADE_TIME)
	await lift.finished
	cover.queue_free()
	await _wait_for_rest()
	_theme_busy = false
	Bus.theme_applied.emit(_built_theme)
	if Save.theme() != _built_theme:
		_switch_theme()


## The old screens stay until the new ones are made, so a call that comes during the awaits always finds a live
## screen. The state that the new screens show comes from Game, not from the old screens.
func _rebuild_visuals() -> void:
	get_tree().root.theme = UiTheme.build()
	var frames := 0
	while not UiBake.is_idle() and frames < THEME_WAIT_FRAMES:
		await get_tree().process_frame
		frames += 1
	UiBake.clear()
	await _bank.rebake()
	_background.queue_free()
	_background = Background.new()
	_back_layer.add_child(_background)
	_board.refresh_theme()
	_demo.board.refresh_theme()
	var page: int = _levels.current_page()
	var revealed: bool = _loading.is_revealed()
	var old: Array[Control] = [_hud, _replay_overlay, _home, _levels, _result, _defeat, _pause, _loading]
	_make_screens()
	for node in old:
		_ui.remove_child(node)
		node.queue_free()
	var level := LevelParser.parse(LevelsData.LEVELS[LevelsData.LEVELS.size() - 1], LevelsData.LEVELS.size() - 1)
	await _warm_up_bake(level, Palette.pick_block_hues(level.starts.size(), _rng))
	_hide_now(_hud)
	_reopen_screens(page, revealed)


## Opens the screens of the current state again: Home or the level select (at `page`) with their open motion,
## the HUD at rest with the session state, the card at its final state, the pause dialog, the replay overlay
## at its step, and the loading screen of a random level job (shown when it was `revealed`).
func _reopen_screens(page: int, revealed: bool) -> void:
	_at_rest = false
	if _phase != &"off" and _session != null:
		_hud.restore(level_index, _level_info, _session.snapshot(), _tense_on)
		if _phase != &"replay":
			_hud.open()
			var intro: Tween = _hud.get("_screen_tween")
			if intro != null:
				intro.custom_step(60.0)
	var target: Control = null
	# The loading screen of a random level job opens over the screen that started the job.
	match _job_prev_screen if screen == &"loading" else screen:
		&"home":
			target = _home
		&"levels":
			target = _levels
		&"result":
			target = _result
		&"defeat":
			target = _defeat
	if _phase == &"replay":
		# The card of the replay waits, closed and filled, until the replay ends and reopens it.
		_replay_card = _result if _card_summary.get("status") == &"won" else _defeat
		_replay_card.use_scrim = true
		_replay_card.call("_fill", _card_summary)
		target = _replay_overlay
	if _paused:
		target = _pause
	if target != null:
		target.opened.connect(func() -> void: _at_rest = true, CONNECT_ONE_SHOT)
		if target == _result or target == _defeat:
			target.use_scrim = true
			target.open(_card_summary)
			target.skip()
		elif target == _levels:
			_levels.open({"page": page})
		elif target == _pause:
			_pause.open(_pause_data())
		elif target == _replay_overlay:
			_replay_overlay.open({"total": _replay_total})
			if _replay_n > 0:
				_replay_overlay.set_step(_replay_n, _replay_total)
		else:
			target.open()
	else:
		_at_rest = true
	if _job_active:
		_loading.open({"seed": _job_seed})
		if revealed:
			_loading.reveal()


func _wait_for_rest() -> void:
	var frames := 0
	while not _at_rest and frames < THEME_WAIT_FRAMES:
		await get_tree().process_frame
		frames += 1


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
