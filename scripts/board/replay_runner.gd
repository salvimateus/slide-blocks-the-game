extends Node
## Plays a stored move list on the main board from the start state: the board rewinds with the same hues,
## then each move plays through the SwipePlayer, with a real-time gap between two moves.
## It emits no Bus signal itself; the SwipePlayer emits the visual-time signals of each swipe.

const BoardTuning := preload("res://scripts/board/board_tuning.gd")
const Session := preload("res://scripts/core/session.gd")
const SlideRules := preload("res://scripts/core/slide_rules.gd")

## n = 0 when the board shows the start state, then n after each played move.
signal stepped(n: int, total: int)
## completed is false after a stop. positions and painted are the state of the replay at its end.
signal finished(completed: bool, positions: PackedInt32Array, painted: int)

var _board: Node2D
var _session: RefCounted
var _moves := ""
var _next := 0
var _running := false
var _rewinding := false
var _serial := 0
var _outcome := {}


## Connects the board signals one time.
func setup(board: Node2D) -> void:
	_board = board
	_board.player.finished.connect(_on_move_played)
	_board.restart_finished.connect(_on_rewound)


## Rewinds the board and plays `moves` (SlideRules.DIR_CHARS letters) on a new Session of `level`.
func play(level: RefCounted, hues: PackedInt32Array, min_moves: int, moves: String) -> void:
	stop()
	_serial += 1
	_session = Session.new(level, min_moves, hues)
	_moves = moves
	_next = 0
	_outcome = {}
	_running = true
	_rewinding = true
	_board.player.use_feel = false
	_board.player.speed_scale = 1.0
	_board.play_restart(hues)


## Ends a running replay where it is. The current swipe completes at once, with no signal.
func stop() -> void:
	if not _running:
		return
	_serial += 1
	_board.player.stop()
	_end(false)


func is_running() -> bool:
	return _running


func _on_rewound() -> void:
	if not _running or not _rewinding:
		return
	_rewinding = false
	stepped.emit(0, _moves.length())
	_wait(BoardTuning.REPLAY_MOVE_GAP)


func _on_move_played(outcome: Dictionary) -> void:
	if not _running or not is_same(outcome, _outcome):
		return
	stepped.emit(_next, _moves.length())
	_wait(BoardTuning.REPLAY_END_HOLD if _next >= _moves.length() else BoardTuning.REPLAY_MOVE_GAP)


# A real-time wait: Feel never slows a replay.
func _wait(seconds: float) -> void:
	var serial := _serial
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if serial == _serial and _running:
			_advance())


func _advance() -> void:
	if _next >= _moves.length():
		_end(true)
		return
	_outcome = _session.swipe(SlideRules.dir_from_char(_moves[_next]))
	_next += 1
	_board.player.play(_outcome)


func _end(completed: bool) -> void:
	_running = false
	_rewinding = false
	_outcome = {}
	_board.player.use_feel = true
	finished.emit(completed, _session.positions, _session.painted_count)
