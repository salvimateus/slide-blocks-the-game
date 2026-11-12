extends Node2D
## The live demo board of the Home screen: plays the demo solution, a win wave, then a restart to the start, in a loop.
## It emits no Bus signal and uses no hit-stop. Make it after the TextureBank bake.

## Named moments of the loop, for the dev lab.
signal event(name: String)

const BoardTuning := preload("res://scripts/board/board_tuning.gd")
const BoardView := preload("res://scripts/board/board_view.gd")
const LevelParser := preload("res://scripts/core/level_parser.gd")
const LevelsData := preload("res://scripts/core/levels_data.gd")
const Palette := preload("res://scripts/core/palette.gd")
const ParData := preload("res://scripts/core/par_data.gd")
const Session := preload("res://scripts/core/session.gd")
const SlideRules := preload("res://scripts/core/slide_rules.gd")

var board: Node2D
var _level: RefCounted
var _rng := RandomNumberGenerator.new()
var _rect := Rect2()
var _serial := 0
var _running := false


func _init() -> void:
	_rng.randomize()
	board = BoardView.new()
	board.player.emit_bus = false
	board.player.use_feel = false
	board.ceremonies.emit_bus = false
	board.ceremonies.use_scrim = false
	add_child(board)


## Builds the demo board, fits it into `rect` and starts the loop.
func start(rect: Rect2) -> void:
	stop()
	_rect = rect
	_level = LevelParser.parse(LevelsData.DEMO, -1)
	_running = true
	_run(_serial)


## Stops the loop. The board keeps its current look.
func stop() -> void:
	_serial += 1
	_running = false
	if board.level != null:
		board.player.stop()
		board.ceremonies.stop()


func is_running() -> bool:
	return _running


func fit(rect: Rect2) -> void:
	_rect = rect
	if board.level != null:
		board.fit(rect)


func _run(serial: int) -> void:
	var par: Dictionary = ParData.PAR[_level.id]
	var moves: String = par.solution
	var hues := _pick()
	board.build(_level, hues)
	board.fit(_rect)
	board.play_intro()
	await board.intro_finished
	while _alive(serial):
		var session := Session.new(_level, int(par.min), hues)
		event.emit("demo_ready")
		var last := {}
		for i in moves.length():
			if not await _wait(serial, BoardTuning.DEMO_MOVE_GAP):
				return
			last = session.swipe(SlideRules.dir_from_char(moves[i]))
			board.player.play(last)
			await board.player.finished
			if not _alive(serial):
				return
			event.emit("demo_move_%d" % (i + 1))
		if not await _wait(serial, BoardTuning.DEMO_WIN_DELAY):
			return
		board.ceremonies.play_win(int(last.get("last_cell", -1)))
		event.emit("demo_win")
		await board.ceremonies.finished
		if not await _wait(serial, BoardTuning.DEMO_HOLD_TIME):
			return
		hues = _pick()
		board.play_restart(hues)
		event.emit("demo_restart")
		await board.restart_finished
		if not _alive(serial):
			return


func _pick() -> PackedInt32Array:
	return Palette.pick_block_hues(_level.starts.size(), _rng)


func _alive(serial: int) -> bool:
	return serial == _serial and is_inside_tree()


func _wait(serial: int, seconds: float) -> bool:
	if not _alive(serial):
		return false
	await get_tree().create_timer(seconds).timeout
	return _alive(serial)
