extends Node
## Scripted runs: the screenshot service, scripted play, logs and the watchdog.
## Arguments come after `--` on the Godot command line, in the form --key=value or --flag.
## The harness does nothing when no argument is present, and stays silent in a `--script` tool run.
## It reads the game only through the Game API and the Bus signals.
## Language and screen: --lang=<pt|en> forces the UI language for this run, with no write to the save.
## --screen=levels --page=<n> opens page n (from 1) of the level select screen.
## --set-lang=<pt|en> changes the language at run time through Save, when the run is at its last state
## (the --screen screen, the pause dialog of --screen=pause, or the end of the scripted play), then marks `lang`.
## It writes the choice into the save file, so it needs --save.
## Modes: --solo turns the one-jelly setting on through Save (needs --save); --solve and --play-all then play the
## one-jelly version of each level that has one. --random[=<seed>] plays a random level (no value: a new seed);
## it does not combine with --level, --play-all or --screen. --random-hold=<ms> holds the ready level that long, so the
## loading screen shows (mark `loading`). --random-map prints `RANDOM_MAP <row>` for each row of the map.
## Each random level prints `RANDOM <report json>` and marks `random_ready`.
## Replay: --replay plays the replay of the game when its card is at rest (needs --level or --random, not --play-all),
## and the run goes on after it. --replay-stop-at=<n> stops it at move n. Marks `replay_start`, `replay_move_<n>` (from 0)
## and `replay_end`, after the line `HARNESS REPLAY completed=<bool> matched=<bool>`.

const LevelsData := preload("res://scripts/core/levels_data.gd")

const DEFAULT_SHOT_FRAMES := 60
const DEFAULT_TIMEOUT := 60.0
const DEFAULT_MOVE_GAP_MS := 250
const ALL_EVENTS := "*"
const DIR_CHARS := "UDLR"
const DIR_ACTIONS: Array[StringName] = [&"swipe_up", &"swipe_down", &"swipe_left", &"swipe_right"]
const DIR_VECTORS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
## Injected touch events carry this device id, injected key events carry INJECTED_META.
const INJECTED_DEVICE := 7357
const INJECTED_META := &"harness_injected"
## The scripted drag, in base units: total length and the number of drag frames.
const DRAG_LENGTH := 160.0
const DRAG_STEPS := 4
const FRAME_LOG_MS := 25.0
## Frames to wait for a card to open after the level ends, before the run goes on without it.
const CARD_WAIT_FRAMES := 240
## Frames from the last state to the --set-lang change, so an open motion is at rest, and from the change to the `lang` mark.
const SET_LANG_WAIT_FRAMES := 45
const SET_LANG_SETTLE_FRAMES := 10

var _args: Dictionary = {}
var _tool_run := false
var _shots_dir := ""
var _shot_on := PackedStringArray()
var _single_shot_path := ""
var _single_shot_frames := 0
var _frames := 0
var _pending_shots := 0
var _quit_code := -1

var _watchdog_serial := 0
var _booted := false
var _perf_started := false
var _perf_printed := false
var _blocks_input := false
var _move_gap := DEFAULT_MOVE_GAP_MS / 1000.0
var _failures := PackedStringArray()
var _failures_printed := false

# Per swipe.
var _move_n := 0
var _swipe_open := false
var _swipe_done := false
var _mid_marked := false
var _paints_target := 0
var _paints_seen := 0

# Per level.
var _level_ended := false
var _level_status := ""
var _card_shown := false
var _tense_marked := false
var _wave_marked := false
var _defeat_wave_marked := false


func _init() -> void:
	_tool_run = _is_tool_run(OS.get_cmdline_args())
	if not _tool_run:
		_args = _parse(OS.get_cmdline_user_args())


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_process_input(false)
	if not active():
		return
	var headless := DisplayServer.get_name() == "headless"
	if headless and (has_arg("shot") or has_arg("shots")):
		push_error("Harness: the headless renderer draws nothing, run the screenshot windowed (remove --headless)")
		finish(1)
		return
	if has_arg("shots"):
		_shots_dir = _os_path(arg("shots"))
		_shot_on = arg("shot-on").split(",", false)
		if _shot_on.is_empty():
			push_warning("Harness: --shots has no effect without --shot-on")
	elif has_arg("shot-on"):
		push_warning("Harness: --shot-on has no effect without --shots")
	if has_arg("shot"):
		_single_shot_path = _os_path(arg("shot"))
		_single_shot_frames = maxi(arg("frames", str(DEFAULT_SHOT_FRAMES)).to_int(), 1)
		set_process(true)
	elif has_arg("frames"):
		push_warning("Harness: --frames has no effect without --shot")
	_restart_watchdog()
	_apply_setup()
	# Deferred: PerfPanel is the next autoload and is not ready yet.
	_begin_perf.call_deferred(false)
	if has_arg("freeze-at"):
		var freeze_at := maxf(arg("freeze-at").to_float(), 0.0)
		get_tree().create_timer(freeze_at, true, false, false).timeout.connect(_on_freeze)
	_move_gap = maxf(arg("move-gap", str(DEFAULT_MOVE_GAP_MS)).to_float(), 0.0) / 1000.0
	_blocks_input = _scripts_input()
	set_process_input(_blocks_input)
	_connect_bus()
	_run_script()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < _single_shot_frames:
		return
	set_process(false)
	_capture(_single_shot_path)
	finish(0)


## Blocks real input in a scripted run. The harness moves itself to the end of the root, so its _input runs first.
func _input(event: InputEvent) -> void:
	if event.device == INJECTED_DEVICE or event.has_meta(INJECTED_META):
		return
	get_viewport().set_input_as_handled()


## True when any harness argument is present.
func active() -> bool:
	return not _args.is_empty()


func has_arg(key: String) -> bool:
	return _args.has(key)


## The value of --key=value, "" for a bare --key, or `fallback` when the key is absent.
func arg(key: String, fallback: String = "") -> String:
	return _args.get(key, fallback)


## Saves <shots dir>/<name>.png after the next frame. No effect without --shots.
func shot(name: String) -> void:
	if _shots_dir == "":
		return
	_capture(_shots_dir.path_join(name + ".png"))


## Reports a named event: takes the --shot-on screenshot and honors --quit-at.
func mark(event: String) -> void:
	if not active():
		return
	print("HARNESS MARK ", event)
	if _shot_on.has(event) or _shot_on.has(ALL_EVENTS):
		shot(event)
	if has_arg("quit-at") and arg("quit-at") == event:
		finish(0)


## Quits with `code` once the pending screenshots are saved.
func finish(code: int) -> void:
	if _quit_code >= 0:
		return
	_print_failures()
	_quit_code = 1 if code == 0 and _failures.size() > 0 else code
	_print_perf_summary()
	if _pending_shots == 0:
		Game.quit(code)


func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Harness: the headless renderer draws nothing, run the screenshot windowed: %s" % path)
		_quit_code = -1
		finish(1)
		return
	_pending_shots += 1
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := _save_viewport(path)
	print("HARNESS SHOT %s err=%d" % [path, err])
	_pending_shots -= 1
	if err != OK and _quit_code <= 0:
		_quit_code = -1
		finish(1)
	elif _quit_code >= 0 and _pending_shots == 0:
		Game.quit(_quit_code)


func _save_viewport(path: String) -> Error:
	var dir_err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if dir_err != OK:
		push_error("Harness: cannot create the folder of the screenshot: %s" % path)
		return dir_err
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Harness: the viewport gave no image for: %s" % path)
		return ERR_CANT_ACQUIRE_RESOURCE
	return image.save_png(path)


# --- Setup -------------------------------------------------------------------

func _apply_setup() -> void:
	if has_arg("save"):
		Save.use_path(_os_path(arg("save")))
	if has_arg("lang"):
		Save.force_language(StringName(arg("lang")))
	if has_arg("unlock-all"):
		Save.unlock_all()
	if has_arg("reduced-motion"):
		Save.set_setting(&"reduced_motion", true)
	if has_arg("solo") and has_arg("save"):
		Save.set_setting(&"solo", true)
	if has_arg("random-hold"):
		Game.set_random_hold(arg("random-hold").to_int())
	if has_arg("time-scale"):
		Feel.set_base_time_scale(arg("time-scale").to_float())


## The watchdog. --play-all starts it again at each level, so the limit applies to each level.
func _restart_watchdog() -> void:
	var timeout := arg("timeout", str(DEFAULT_TIMEOUT)).to_float()
	if timeout <= 0.0:
		return
	_watchdog_serial += 1
	var serial := _watchdog_serial
	get_tree().create_timer(timeout, true, false, true).timeout.connect(func() -> void:
		if serial == _watchdog_serial:
			_on_timeout()
	)


func _on_timeout() -> void:
	print("HARNESS TIMEOUT")
	_print_perf_summary()
	Game.quit(2)


func _on_freeze() -> void:
	print("HARNESS FREEZE ", arg("freeze-at"))
	get_tree().paused = true


func _scripts_input() -> bool:
	return has_arg("moves") or has_arg("keys") or has_arg("solve") or has_arg("play-all")


## The run starts with the harness, and starts again one time when the play starts, so the load stays out of it.
func _begin_perf(play_start: bool) -> void:
	if not (has_arg("perf-summary") or has_arg("frame-log")):
		return
	if play_start:
		if _perf_started:
			return
		_perf_started = true
	PerfPanel.begin_run(FRAME_LOG_MS if has_arg("frame-log") else 0.0)


func _print_perf_summary() -> void:
	if _perf_printed or not has_arg("perf-summary"):
		return
	_perf_printed = true
	print("PERF_SUMMARY ", JSON.stringify(PerfPanel.run_summary()))


# --- Bus events --------------------------------------------------------------

func _connect_bus() -> void:
	Bus.screen_changed.connect(_on_screen_changed)
	Bus.level_ready.connect(_on_level_ready)
	Bus.tension_changed.connect(_on_tension_changed)
	Bus.paused_changed.connect(_on_paused_changed)
	Bus.swipe_started.connect(_on_swipe_started)
	Bus.tile_painted.connect(_on_tile_painted)
	Bus.swipe_finished.connect(_on_swipe_finished)
	Bus.swipe_ignored.connect(_on_swipe_ignored)
	Bus.ceremony_started.connect(_on_ceremony_started)
	Bus.ceremony_cue.connect(_on_ceremony_cue)
	Bus.level_won.connect(_on_level_end)
	Bus.level_lost.connect(_on_level_end)
	Bus.level_generated.connect(_on_level_generated)
	Bus.replay_started.connect(_on_replay_started)
	Bus.replay_step.connect(_on_replay_step)
	Bus.replay_finished.connect(_on_replay_finished)


func _on_screen_changed(screen: StringName) -> void:
	_booted = true
	match screen:
		&"home", &"levels":
			mark(String(screen))
		&"result":
			_card_shown = true
			mark("result")
		&"defeat":
			_card_shown = true
			mark("defeat_card")
		&"loading":
			mark("loading")


func _on_level_ready(_index: int) -> void:
	_begin_perf(true)
	mark("level_ready")


func _on_tension_changed(on: bool) -> void:
	if on and not _tense_marked:
		_tense_marked = true
		mark("tense")


func _on_paused_changed(on: bool) -> void:
	if on:
		mark("pause")


func _on_swipe_started(outcome: Dictionary) -> void:
	if not _swipe_open:
		return
	var paints: Array = outcome.get("paints", [])
	_paints_target = maxi((paints.size() + 1) / 2, 1)
	_paints_seen = 0


func _on_tile_painted(_cell: int, _hue: int, _fresh: bool, _step: int) -> void:
	if not _swipe_open or _mid_marked:
		return
	_paints_seen += 1
	if _paints_seen >= _paints_target:
		_mark_mid()


func _on_swipe_finished(outcome: Dictionary) -> void:
	_end_swipe(bool(outcome.get("counted", false)))


func _on_swipe_ignored(_dir: int) -> void:
	_end_swipe(false)


func _on_ceremony_started(_kind: StringName) -> void:
	_wave_marked = false
	_defeat_wave_marked = false


func _on_ceremony_cue(cue: StringName, _value: int) -> void:
	if cue == &"wave_ring" and not _wave_marked:
		_wave_marked = true
		mark("win_wave")
	elif cue == &"defeat_wave" and not _defeat_wave_marked:
		_defeat_wave_marked = true
		mark("defeat_wave")


func _on_level_end(summary: Dictionary) -> void:
	_level_ended = true
	_level_status = String(summary.get("status", ""))
	if has_arg("state-log"):
		var result := {}
		for key: String in ["status", "moves", "stars", "range_lo", "range_hi", "time_ms"]:
			result[key] = summary.get(key)
		print("RESULT ", JSON.stringify(result))


func _on_level_generated(report: Dictionary) -> void:
	var line := report.duplicate()
	line.erase("map")
	print("RANDOM ", JSON.stringify(line))
	if has_arg("random-map"):
		for row: String in report.get("map", []):
			print("RANDOM_MAP ", row)
	mark("random_ready")


func _on_replay_started(_total: int) -> void:
	mark("replay_start")


func _on_replay_step(n: int, _total: int) -> void:
	mark("replay_move_%d" % n)
	if has_arg("replay-stop-at") and arg("replay-stop-at").to_int() == n:
		Game.stop_replay()


func _on_replay_finished(completed: bool, matched: bool) -> void:
	print("HARNESS REPLAY completed=%s matched=%s" % [completed, matched])
	if completed and not matched:
		_failures.append("replay: the end state differs from the game")
	mark("replay_end")


func _mark_mid() -> void:
	_mid_marked = true
	mark("move_%d_mid" % _move_n)


func _end_swipe(counted: bool) -> void:
	if not _swipe_open:
		return
	if not _mid_marked:
		_mark_mid()
	_swipe_open = false
	_swipe_done = true
	if has_arg("state-log"):
		var state := Game.snapshot()
		var music := Music.state()
		state["counted"] = counted
		state["music"] = {"clip": music.get("clip"), "bpm": music.get("bpm"), "cutoff_hz": music.get("cutoff_hz")}
		print("STATE ", JSON.stringify(state))
	mark("move_%d_end" % _move_n)


# --- Script ------------------------------------------------------------------

func _run_script() -> void:
	var plan := _plan()
	if plan.is_empty():
		return
	while not _booted:
		await get_tree().process_frame
		if _stopped():
			return
	await get_tree().process_frame
	if _blocks_input:
		get_tree().root.move_child(self, -1)
	if plan.levels.is_empty() and not plan.random:
		_begin_perf(true)
		if plan.screen == "levels":
			Game.open_levels(arg("page", "0").to_int() - 1)
		elif Game.screen != &"home":
			Game.open_home()
		await _set_lang_live()
		return
	if plan.random:
		await _play_level(Game.start_random.bind(plan.seed), "random level", plan)
		if _stopped():
			return
	for i in plan.levels.size():
		var index: int = plan.levels[i]
		if i > 0:
			_restart_watchdog()
		await _play_level(Game.start_level.bind(index), "level %d" % (index + 1), plan)
		if _stopped():
			return
	if plan.screen == "pause":
		Game.set_paused(true)
		await _set_lang_live()
		return
	await _set_lang_live()
	if _stopped():
		return
	_print_failures()
	if _blocks_input and not has_arg("quit-at") and not has_arg("shot"):
		finish(1 if _failures.size() > 0 else 0)


## {"levels": [index, ...], "random": bool, "seed": int, "moves": String, "solve": bool, "keys": bool, "screen": String},
## or {} with no scripted play.
func _plan() -> Dictionary:
	if has_arg("set-lang") and not has_arg("save"):
		return _plan_error("--set-lang writes the language into the save: add --save=<file>")
	if has_arg("solo") and not has_arg("save"):
		return _plan_error("--solo writes the one-jelly setting into the save: add --save=<file>")
	var random := has_arg("random")
	if random and (has_arg("level") or has_arg("play-all") or has_arg("screen")):
		return _plan_error("--random does not combine with --level, --play-all or --screen")
	if has_arg("replay") and (has_arg("play-all") or not (has_arg("level") or random)):
		return _plan_error("--replay needs --level or --random, and does not combine with --play-all")
	if has_arg("replay-stop-at") and not has_arg("replay"):
		return _plan_error("--replay-stop-at needs --replay")
	var screen := arg("screen")
	if has_arg("page") and screen != "levels":
		push_warning("Harness: --page has no effect without --screen=levels")
	if screen != "" and not (screen in ["home", "levels", "pause"]):
		return _plan_error("--screen must be home, levels or pause (got '%s')" % screen)
	var plays := has_arg("level") or random or _scripts_input() or screen == "pause"
	if screen in ["home", "levels"] and plays:
		return _plan_error("--screen=%s does not combine with --level, --moves, --keys, --solve or --play-all" % screen)
	if has_arg("moves") and has_arg("keys"):
		return _plan_error("use --moves or --keys, not both")
	var plan := {
		"levels": [], "random": random, "seed": arg("random").to_int() if arg("random") != "" else -1,
		"moves": "", "solve": has_arg("solve") or has_arg("play-all"), "keys": has_arg("keys"), "screen": screen,
	}
	if not plays:
		if screen == "" and has_arg("set-lang"):
			push_warning("Harness: --set-lang has no effect without --screen or --level")
		return plan if screen != "" else {}
	if plan.solve and has_arg("moves"):
		return _plan_error("--solve and --play-all play the baked solution: remove --moves")
	if not plan.solve:
		plan.moves = arg("moves", arg("keys")).to_upper()
	for c in plan.moves:
		if not DIR_CHARS.contains(c):
			return _plan_error("the swipe list may hold only U, D, L and R (got '%s')" % plan.moves)
	if random:
		return plan
	if has_arg("play-all"):
		if has_arg("level"):
			return _plan_error("--play-all plays each level: remove --level")
		for i in LevelsData.LEVELS.size():
			plan.levels.append(i)
		return plan
	var number := arg("level", "1").to_int()
	if number < 1 or number > LevelsData.LEVELS.size():
		return _plan_error("--level must be 1 to %d (got '%s')" % [LevelsData.LEVELS.size(), arg("level")])
	plan.levels.append(number - 1)
	return plan


## The runtime language change of --set-lang, at the last state of the run.
func _set_lang_live() -> void:
	if not has_arg("set-lang"):
		return
	for i in SET_LANG_WAIT_FRAMES:
		await get_tree().process_frame
		if _stopped():
			return
	Save.set_language(StringName(arg("set-lang")))
	for i in SET_LANG_SETTLE_FRAMES:
		await get_tree().process_frame
		if _stopped():
			return
	mark("lang")


func _plan_error(message: String) -> Dictionary:
	push_error("Harness: " + message)
	finish(1)
	return {}


func _print_failures() -> void:
	if _failures_printed or _failures.is_empty():
		return
	_failures_printed = true
	for line in _failures:
		print("HARNESS FAIL ", line)


## Starts a level with `start`, plays the moves of the plan (the solution of the level with --solve), waits for its card,
## then plays its replay with --replay. `label` names the level in a failure.
func _play_level(start: Callable, label: String, plan: Dictionary) -> void:
	_level_ended = false
	_level_status = ""
	_card_shown = false
	_tense_marked = false
	var ready_seen := [false]
	var on_ready := func(_i: int) -> void: ready_seen[0] = true
	Bus.level_ready.connect(on_ready)
	start.call()
	while not ready_seen[0]:
		await get_tree().process_frame
		if _stopped():
			Bus.level_ready.disconnect(on_ready)
			return
	Bus.level_ready.disconnect(on_ready)
	var keys: bool = plan.keys
	var moves: String = Game.current_solution() if plan.solve else plan.moves
	for c in moves:
		if _level_ended or _game_over():
			break
		await get_tree().create_timer(_move_gap, true, false, false).timeout
		if _stopped():
			return
		await _swipe(DIR_CHARS.find(c), keys)
		if _stopped():
			return
	var solve := has_arg("solve") or has_arg("play-all")
	if not _game_over() and not _level_ended:
		if solve:
			_failures.append("%s: the solution did not complete the level" % label)
		await get_tree().create_timer(_move_gap, true, false, false).timeout
		return
	while not _level_ended:
		await get_tree().process_frame
		if _stopped():
			return
	var waited := 0
	while not _card_shown and waited < CARD_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
		if _stopped():
			return
	if solve and _level_status != "won":
		_failures.append("%s: status %s after the solution" % [label, _level_status])
	await get_tree().create_timer(_move_gap, true, false, false).timeout
	if has_arg("replay") and not _stopped():
		await _play_replay()


## Plays the replay of the open card and waits for its end.
func _play_replay() -> void:
	if not Game.can_replay():
		_failures.append("replay: the card offers no replay")
		return
	var done := [false]
	var on_end := func(_completed: bool, _matched: bool) -> void: done[0] = true
	Bus.replay_finished.connect(on_end)
	Game.play_replay()
	while not done[0]:
		await get_tree().process_frame
		if _stopped():
			break
	Bus.replay_finished.disconnect(on_end)
	if not _stopped():
		await get_tree().create_timer(_move_gap, true, false, false).timeout


func _swipe(dir: int, keys: bool) -> void:
	_move_n += 1
	_swipe_open = true
	_swipe_done = false
	_mid_marked = false
	_paints_target = 1
	_paints_seen = 0
	if keys:
		await _send_key(dir)
	else:
		await _send_drag(dir)
	while not _swipe_done:
		await get_tree().process_frame
		if _stopped():
			return


func _send_key(dir: int) -> void:
	var source: InputEventKey = null
	for event in InputMap.action_get_events(DIR_ACTIONS[dir]):
		if event is InputEventKey:
			source = event
			break
	if source == null:
		push_error("Harness: the action %s has no key event" % DIR_ACTIONS[dir])
		finish(1)
		return
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = source.physical_keycode
		key.keycode = source.keycode if source.keycode != KEY_NONE else source.physical_keycode
		key.pressed = pressed
		key.set_meta(INJECTED_META, true)
		Input.parse_input_event(key)
		await get_tree().process_frame


## A touch press at the center of the screen, a drag in DRAG_STEPS frames, then the release.
func _send_drag(dir: int) -> void:
	var to_window := get_viewport().get_final_transform()
	var center := get_viewport().get_visible_rect().get_center()
	var step := DIR_VECTORS[dir] * (DRAG_LENGTH / DRAG_STEPS)
	var window_step := to_window.basis_xform(step)
	var pos := to_window * center
	var press := InputEventScreenTouch.new()
	press.device = INJECTED_DEVICE
	press.index = 0
	press.pressed = true
	press.position = pos
	Input.parse_input_event(press)
	await get_tree().process_frame
	for i in DRAG_STEPS:
		pos += window_step
		var drag := InputEventScreenDrag.new()
		drag.device = INJECTED_DEVICE
		drag.index = 0
		drag.position = pos
		drag.relative = window_step
		drag.screen_relative = window_step
		drag.velocity = window_step * Engine.get_frames_per_second()
		drag.screen_velocity = drag.velocity
		Input.parse_input_event(drag)
		await get_tree().process_frame
	var release := InputEventScreenTouch.new()
	release.device = INJECTED_DEVICE
	release.index = 0
	release.pressed = false
	release.position = pos
	Input.parse_input_event(release)
	await get_tree().process_frame


func _game_over() -> bool:
	var status := String(Game.snapshot().get("status", ""))
	return status == "won" or status == "lost"


func _stopped() -> bool:
	return _quit_code >= 0


# --- Parse -------------------------------------------------------------------

## True in a `--script` tool run: the harness then stays silent and inactive.
static func _is_tool_run(list: PackedStringArray) -> bool:
	for item in list:
		if item == "--":
			return false
		if item == "--script" or item == "-s":
			return true
	return false


static func _parse(list: PackedStringArray) -> Dictionary:
	var out := {}
	for item in list:
		if not item.begins_with("--"):
			continue
		var body := item.substr(2)
		var eq := body.find("=")
		if eq < 0:
			out[body] = ""
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out


## Accepts a Windows path or a WSL /mnt/<drive>/ path, and gives the form that this OS opens.
static func _os_path(path: String) -> String:
	var p := path.replace("\\", "/")
	if OS.has_feature("windows") and p.begins_with("/mnt/") and p.length() > 6 and p[6] == "/":
		p = p[5].to_upper() + ":" + p.substr(6)
	return p
