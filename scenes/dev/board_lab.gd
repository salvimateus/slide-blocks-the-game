extends Node2D
## Dev lab of the board. Arguments after `--`:
##   --lab-level=<n>    level from 1 (default 1): intro, the baked solution, then the win ceremony
##   --lab-defeat       three moves, then the defeat ceremony
##   --lab-demo         the Home demo board
##   --lab-nudge        a swipe that moves no block, before the moves
##   --lab-restart      after the ceremony, the restart wave
##   --lab-skip         a skip during the ceremony
##   --lab-speed=<f>    playback speed scale
##   --lab-seed=<n>     block color seed
##   --lab-frame-log    real frame times above 25 ms and draw calls after level_ready, printed as LAB_FRAMES
## Events go to Harness.mark: level_ready, nudge, move_<n>_mid, move_<n>_end, win_wave, win_end,
## defeat_wave, defeat_end, restart_mid, restart_end, and demo_* for the demo.

const Background := preload("res://scripts/board/background.gd")
const BoardView := preload("res://scripts/board/board_view.gd")
const DemoBoard := preload("res://scripts/board/demo_board.gd")
const LevelParser := preload("res://scripts/core/level_parser.gd")
const LevelsData := preload("res://scripts/core/levels_data.gd")
const Palette := preload("res://scripts/core/palette.gd")
const ParData := preload("res://scripts/core/par_data.gd")
const Session := preload("res://scripts/core/session.gd")
const SlideRules := preload("res://scripts/core/slide_rules.gd")
const TextureBank := preload("res://scripts/board/texture_bank.gd")

const FIT_RECT := Rect2(16, 230, 688, 880)
const DEMO_RECT := Rect2(16, 120, 688, 1040)
const MOVE_GAP := 0.25
const SLOW_FRAME_MS := 25.0

var _args := {}
var _board: Node2D
var _rng := RandomNumberGenerator.new()
var _log_on := false
var _last_us := 0
var _frames := 0
var _slow: Array = []
var _draw_max := 0
var _draw_sum := 0


func _ready() -> void:
	set_process(false)
	_args = _parse(OS.get_cmdline_user_args())
	var bank := TextureBank.new()
	add_child(bank)
	await bank.bake()
	var back := CanvasLayer.new()
	back.layer = -1
	add_child(back)
	back.add_child(Background.new())
	if _args.has("lab-demo"):
		_run_demo()
	else:
		_run_level()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		var ms := (now - _last_us) / 1000.0
		_frames += 1
		if ms > SLOW_FRAME_MS:
			_slow.append(snappedf(ms, 0.1))
	_last_us = now
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	_draw_max = maxi(_draw_max, calls)
	_draw_sum += calls


func _run_demo() -> void:
	var demo := DemoBoard.new()
	add_child(demo)
	demo.event.connect(_mark)
	demo.start(DEMO_RECT)


func _run_level() -> void:
	var n := int(_args.get("lab-level", "1"))
	var level := LevelParser.parse(LevelsData.LEVELS[n - 1], n - 1)
	var par: Dictionary = ParData.PAR[level.id]
	_rng.seed = int(_args.get("lab-seed", str(n * 31)))
	var hues := Palette.pick_block_hues(level.starts.size(), _rng)
	var session := Session.new(level, int(par.min), hues)
	_board = BoardView.new()
	add_child(_board)
	_board.build(level, hues)
	_board.fit(FIT_RECT)
	_board.player.speed_scale = float(_args.get("lab-speed", "1.0"))
	_board.ceremonies.wave_middle.connect(_on_wave_middle)
	_board.play_intro()
	await _board.intro_finished
	if _args.has("lab-frame-log"):
		_log_on = true
		set_process(true)
	_mark("level_ready")

	if _args.has("lab-nudge"):
		for d in 4:
			var probe := session.swipe(d)
			if not probe.moved:
				_board.player.play(probe)
				await get_tree().create_timer(_board.player.duration(probe) * 0.35).timeout
				_mark("nudge")
				await _board.player.finished
				break

	var moves: String = par.solution
	if _args.has("lab-defeat"):
		moves = moves.substr(0, 3)
	var last := {}
	for i in moves.length():
		await get_tree().create_timer(MOVE_GAP).timeout
		last = session.swipe(SlideRules.dir_from_char(moves[i]))
		_board.player.play(last)
		var half: float = _board.player.duration(last) * 0.5 / _board.player.speed_scale
		get_tree().create_timer(half).timeout.connect(_mark.bind("move_%d_mid" % (i + 1)))
		await _board.player.finished
		_mark("move_%d_end" % (i + 1))
	await get_tree().create_timer(0.3).timeout

	var defeat := _args.has("lab-defeat")
	if not defeat and last.get("status", &"") != &"won":
		print("LAB the solution did not win: ", last.get("status", &""))
	if defeat:
		_board.ceremonies.play_defeat()
	else:
		_board.ceremonies.play_win(int(last.get("last_cell", -1)))
	if _args.has("lab-skip"):
		get_tree().create_timer(0.45).timeout.connect(_board.ceremonies.skip)
	await _board.ceremonies.finished
	if _log_on:
		_print_frames()
	_mark("defeat_end" if defeat else "win_end")

	if _args.has("lab-restart"):
		await get_tree().create_timer(0.4).timeout
		_board.play_restart(Palette.pick_block_hues(level.starts.size(), _rng))
		get_tree().create_timer(0.22).timeout.connect(_mark.bind("restart_mid"))
		await _board.restart_finished
		await get_tree().create_timer(0.2).timeout
		_mark("restart_end")
	if Harness.active():
		await get_tree().create_timer(0.3).timeout
		get_tree().quit(0)


func _on_wave_middle(kind: StringName) -> void:
	_mark("win_wave" if kind == &"win" else "defeat_wave")


func _mark(event: String) -> void:
	print("LAB ", event)
	Harness.mark(event)


func _print_frames() -> void:
	var summary := {
		"frames": _frames,
		"slow_frames_ms": _slow,
		"draw_calls_max": _draw_max,
		"draw_calls_avg": snappedf(float(_draw_sum) / maxi(_frames, 1), 0.1),
	}
	print("LAB_FRAMES ", JSON.stringify(summary))


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
