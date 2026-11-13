extends RefCounted

const Level := preload("res://scripts/core/level.gd")
const SlideRules := preload("res://scripts/core/slide_rules.gd")
const ScoreRules := preload("res://scripts/core/score_rules.gd")

var level: Level
var thresholds: Dictionary
var hues: PackedInt32Array
var positions: PackedInt32Array
var paint_hue: PackedInt32Array
var painted_count: int
var moves_used: int
var status: StringName = &"ready"
var tense := false
## One SlideRules.DIR_CHARS letter for each counted swipe, in play order.
var history := ""


func _init(p_level: Level, min_moves: int, p_hues: PackedInt32Array) -> void:
	level = p_level
	thresholds = ScoreRules.thresholds(min_moves, level.index)
	hues = p_hues
	positions = level.starts.duplicate()
	paint_hue.resize(level.cells)
	paint_hue.fill(-1)
	for b in positions.size():
		paint_hue[positions[b]] = hues[b]
	painted_count = positions.size()


func is_complete() -> bool:
	return painted_count == level.floor_count


func stars() -> int:
	if status == &"lost":
		return 0
	return ScoreRules.stars_for(moves_used, thresholds)


# A swipe counts only when the end positions differ from the start positions, as in the solver.
func swipe(dir: int) -> Dictionary:
	if status == &"won" or status == &"lost":
		return {"ignored": true, "moved": false, "counted": false}
	var out := PackedInt32Array()
	out.resize(positions.size())
	var events := []
	SlideRules.resolve(level, positions, dir, out, events)
	var outcome := {
		"ignored": false, "dir": dir, "moved": false, "counted": false,
		"events": events, "paints": [], "positions": positions.duplicate(), "ticks": 0,
		"status": status, "moves_used": moves_used, "stars": stars(),
		"tense": tense, "tense_changed": false, "tier_dropped": false, "last_cell": -1,
	}
	if out == positions:
		return outcome

	var stars_before := stars()
	var paints: Array = []
	var ticks := 0
	var last_cell := -1
	for e in events:
		if e.t != "step":
			continue
		var cell: int = e.to
		var hue := hues[e.block]
		var fresh := paint_hue[cell] == -1
		if fresh:
			painted_count += 1
			last_cell = cell
		paint_hue[cell] = hue
		paints.append({"tick": e.tick, "block": e.block, "cell": cell, "hue": hue, "fresh": fresh})
		ticks = maxi(ticks, e.tick)
	positions = out
	moves_used += 1
	history += SlideRules.DIR_CHARS[dir]
	if is_complete():
		status = &"won"
	elif moves_used >= thresholds.limit:
		status = &"lost"
	else:
		status = &"playing"
	var was_tense := tense
	tense = status == &"playing" and ScoreRules.is_tense(moves_used, thresholds)
	var stars_now := stars()

	outcome.moved = true
	outcome.counted = true
	outcome.paints = paints
	outcome.positions = positions.duplicate()
	outcome.ticks = ticks
	outcome.status = status
	outcome.moves_used = moves_used
	outcome.stars = stars_now
	outcome.tense = tense
	outcome.tense_changed = tense != was_tense
	outcome.tier_dropped = status != &"lost" and stars_now < stars_before
	outcome.last_cell = last_cell
	return outcome


func snapshot() -> Dictionary:
	var cols_rows: Array = []
	for p in positions:
		cols_rows.append([level.col_of(p), level.row_of(p)])
	return {
		"level_index": level.index, "level_id": level.id, "status": status,
		"moves_used": moves_used, "min": thresholds.min, "three_max": thresholds.three_max,
		"two_max": thresholds.two_max, "limit": thresholds.limit, "tension_moves": thresholds.tension_moves,
		"moves_left": thresholds.limit - moves_used, "stars": stars(), "painted": painted_count,
		"floor": level.floor_count, "tense": tense, "positions": cols_rows,
	}
