extends Node
## The win and defeat ceremonies of a BoardView. Emits the ceremony Bus signals; a tap calls `skip`.

## Emitted at the end, also after a skip.
signal finished(kind: StringName)
## Emitted when the wave reaches its middle ring. Game and the lab report `win_wave` or `defeat_wave` on it.
signal wave_middle(kind: StringName)

const BoardTuning := preload("res://scripts/board/board_tuning.gd")
const Palette := preload("res://scripts/core/palette.gd")

const GRAY := -2   # BoardView.GRAY

## The BoardView. The BoardView sets it.
var board: Node2D
## False for the demo board: no Bus signal.
var emit_bus := true
## False for the demo board: no scrim behind the board.
var use_scrim := true
## &"win", &"defeat", or &"" when no ceremony runs.
var kind: StringName = &""

var _tween: Tween


func is_running() -> bool:
	return kind != &""


## The win: tiles jump and flash ring by ring from `last_cell`, glitter pops on each ring,
## blocks jump with happy eyes, then a final burst.
func play_win(last_cell: int) -> void:
	stop()
	kind = &"win"
	if emit_bus:
		Bus.ceremony_started.emit(kind)
	if use_scrim:
		board.show_scrim(true)
	var motion := Feel.motion()
	var rings: Array = board.rings_from(last_cell)
	var block_ring := {}
	for b in board.blocks.size():
		board.blocks[b].set_mood(&"happy")
		var cell := _cell_at(board.blocks[b].position)
		block_ring[b] = -1
		for r in rings.size():
			if (rings[r] as PackedInt32Array).has(cell):
				block_ring[b] = r
				break
	_tween = board.create_tween().set_parallel(true)
	var t := BoardTuning.WIN_START_DELAY
	for r in rings.size():
		_tween.tween_callback(_win_ring.bind(r, rings[r], motion)).set_delay(t)
		for b in block_ring:
			if block_ring[b] == r:
				_tween.tween_callback(_block_jump.bind(b)).set_delay(t)
		if r == rings.size() / 2:
			_tween.tween_callback(_middle).set_delay(t)
		t += BoardTuning.WIN_RING_INTERVAL
	t += BoardTuning.WIN_BURST_DELAY
	_tween.tween_callback(_win_burst).set_delay(t)
	_tween.tween_callback(_end).set_delay(t + BoardTuning.WIN_HOLD_TIME + BoardTuning.WIN_BLOCK_JUMP_TIME)


## The defeat: blocks deflate with sad eyes, colors fade to gray from the edge to the center,
## and the unpainted tiles pulse in coral.
func play_defeat() -> void:
	stop()
	kind = &"defeat"
	if emit_bus:
		Bus.ceremony_started.emit(kind)
	if use_scrim:
		board.show_scrim(true)
	for bv in board.blocks:
		bv.deflate()
	var rings: Array = board.rings_from_edge()
	_tween = board.create_tween().set_parallel(true)
	var t := BoardTuning.DEFEAT_START_DELAY
	_tween.tween_callback(_defeat_start.bind(rings.size())).set_delay(t)
	for r in rings.size():
		_tween.tween_callback(_gray_ring.bind(rings[r])).set_delay(t)
		if r == rings.size() / 2:
			_tween.tween_callback(_middle).set_delay(t)
		t += BoardTuning.DEFEAT_RING_INTERVAL
	var pulse_end := BoardTuning.DEFEAT_START_DELAY + BoardTuning.DEFEAT_PULSE_TIME * BoardTuning.DEFEAT_PULSE_LOOPS
	var end := maxf(t + BoardTuning.DEFEAT_GRAY_TIME, pulse_end)
	_tween.tween_callback(_end).set_delay(end + BoardTuning.DEFEAT_HOLD_TIME)


## Jumps to the end state of the running ceremony and emits `finished`.
func skip() -> void:
	if not is_running():
		return
	var ended := kind
	if _tween != null:
		_tween.kill()
		_tween = null
	board.settle()
	if ended == &"defeat":
		for cell in board.floor_cells():
			if board.paint_hue[cell] >= 0:
				board.set_tile_paint(cell, GRAY)
		for bv in board.blocks:
			bv.deflate_now()
	else:
		for bv in board.blocks:
			bv.set_mood(&"happy")
	if use_scrim:
		board.set_scrim_now(true)
	_end()


## Kills the running ceremony with no signal. The board keeps its current look.
func stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	kind = &""


func _cell_at(pos: Vector2) -> int:
	for cell in board.floor_cells():
		if board.cell_pos(cell).distance_to(pos) < BoardTuning.PITCH * 0.5:
			return cell
	return -1


func _win_ring(r: int, ring: PackedInt32Array, motion: float) -> void:
	var height := BoardTuning.WIN_TILE_JUMP * BoardTuning.PITCH * motion
	for cell in ring:
		board.tile_jump(cell, height, BoardTuning.WIN_TILE_JUMP_TIME)
		board.tile_flash(cell, 0.85, BoardTuning.WIN_FLASH_TIME)
	var hue: int = board.hues[r % board.hues.size()]
	var count: int = board.fx.ring_glitter(board.ring_points(ring), hue)
	if emit_bus:
		Bus.ceremony_cue.emit(&"wave_ring", r)
		if count > 0:
			Bus.ceremony_cue.emit(&"glitter", count)


func _block_jump(b: int) -> void:
	board.blocks[b].hop(BoardTuning.WIN_BLOCK_JUMP * BoardTuning.PITCH, BoardTuning.WIN_BLOCK_JUMP_TIME)


func _win_burst() -> void:
	board.fx.burst(Vector2.ZERO, board.hues)
	board.pulse()
	for b in board.blocks.size():
		board.blocks[b].hop(BoardTuning.WIN_BLOCK_JUMP * BoardTuning.PITCH * 1.3, BoardTuning.WIN_BLOCK_JUMP_TIME * 1.15, b * 0.05)
	if emit_bus:
		Bus.ceremony_cue.emit(&"win_end", 0)


func _defeat_start(ring_count: int) -> void:
	for cell in board.floor_cells():
		if board.paint_hue[cell] == -1:
			board.tile_pulse(cell, Palette.CORAL, BoardTuning.DEFEAT_PULSE_ALPHA, BoardTuning.DEFEAT_PULSE_TIME, BoardTuning.DEFEAT_PULSE_LOOPS)
	if emit_bus:
		Bus.ceremony_cue.emit(&"defeat_wave", ring_count)


func _gray_ring(ring: PackedInt32Array) -> void:
	for cell in ring:
		if board.paint_hue[cell] >= 0:
			board.tile_crossfade(cell, GRAY, BoardTuning.DEFEAT_GRAY_TIME, 0.0)


func _middle() -> void:
	wave_middle.emit(kind)


func _end() -> void:
	var ended := kind
	_tween = null
	kind = &""
	if emit_bus:
		Bus.ceremony_finished.emit(ended)
	finished.emit(ended)
