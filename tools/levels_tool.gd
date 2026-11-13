extends SceneTree
# Solves the levels and the demo map, checks them, searches the one-block version of each level with two or more
# blocks, and writes both pars to scripts/core/par_data.gd.
# Args after "--": --write | --check, and optional --levels=<path of a levels_data script>.

const LevelParser := preload("res://scripts/core/level_parser.gd")
const Solver := preload("res://scripts/core/solver.gd")
const ScoreRules := preload("res://scripts/core/score_rules.gd")
const SoloVariant := preload("res://scripts/core/solo_variant.gd")
const SoloSearch := preload("res://tools/solo_search.gd")

const DEFAULT_LEVELS := "res://scripts/core/levels_data.gd"
const PAR_PATH := "res://scripts/core/par_data.gd"
# Index of l9. Before it the minimum must rise; from it on the minimum may go down, but not below the minimum of l9.
const FREE_CURVE_FROM := 8


func _init() -> void:
	var write := false
	var check := false
	var levels_path := DEFAULT_LEVELS
	for arg in OS.get_cmdline_user_args():
		if arg == "--write":
			write = true
		elif arg == "--check":
			check = true
		elif arg.begins_with("--levels="):
			levels_path = arg.trim_prefix("--levels=")
	if write == check:
		printerr("levels_tool: give exactly one of --write or --check")
		quit(1)
		return
	quit(_run(levels_path, write))


func _run(levels_path: String, write: bool) -> int:
	var data: Script = load(levels_path)
	if data == null:
		printerr("levels_tool: cannot load ", levels_path)
		return 1
	var defs: Array = data.LEVELS.duplicate()
	defs.append(data.DEMO)
	var failures := PackedStringArray()
	var par := []
	var prev_blocks := 0
	var prev_min := 0
	var floor_min := 0
	for index in defs.size():
		var def: Dictionary = defs[index]
		var is_demo := index == defs.size() - 1
		var label := "DEMO" if is_demo else "L%d" % (index + 1)
		var lv = LevelParser.parse(def, index)
		if not lv.errors.is_empty():
			for e in lv.errors:
				failures.append("%s (%s) parse: %s" % [label, def.get("id", "?"), e])
			print("%s parse error" % label)
			continue
		var s := Solver.solve(lv)
		if s.is_empty():
			failures.append("%s: not solvable" % label)
			print("%s floor=%d blocks=%d not solvable" % [label, lv.floor_count, lv.starts.size()])
			continue
		par.append([lv.id, s.min, s.solution])
		var line := "%s floor=%d blocks=%d min=%d" % [label, lv.floor_count, lv.starts.size(), s.min]
		if not is_demo:
			var t := ScoreRules.thresholds(s.min, index)
			var r3 := ScoreRules.range_for(3, t)
			var r2 := ScoreRules.range_for(2, t)
			var r1 := ScoreRules.range_for(1, t)
			line += " 3*=%d-%d 2*=%d-%d 1*=%d-%d limit=%d" % [r3.x, r3.y, r2.x, r2.y, r1.x, r1.y, t.limit]
		line += " solution=%s states=%d" % [s.solution, s.states]
		print(line)
		if Solver.has_loop(lv):
			failures.append("%s: a deflector loop" % label)
		if is_demo:
			continue
		if Solver.has_dead_end(lv):
			failures.append("%s: a dead end" % label)
		if lv.starts.size() < prev_blocks:
			failures.append("%s: block count %d is below the previous level (%d)" % [label, lv.starts.size(), prev_blocks])
		if index == FREE_CURVE_FROM:
			floor_min = s.min
		if index < FREE_CURVE_FROM and s.min < prev_min:
			failures.append("%s: minimum %d is below the previous level (%d)" % [label, s.min, prev_min])
		if index >= FREE_CURVE_FROM and s.min < floor_min:
			failures.append("%s: minimum %d is below the minimum of L%d (%d)" % [label, s.min, FREE_CURVE_FROM + 1, floor_min])
		prev_blocks = lv.starts.size()
		prev_min = s.min

	var solo := _solo_versions(data.LEVELS, failures)

	if failures.is_empty():
		var text := _par_text(par, solo)
		if write:
			var f := FileAccess.open(PAR_PATH, FileAccess.WRITE)
			if f == null:
				failures.append("cannot write %s: %s" % [PAR_PATH, error_string(FileAccess.get_open_error())])
			else:
				f.store_string(text)
				f.close()
				print("WROTE ", PAR_PATH)
		elif FileAccess.get_file_as_string(PAR_PATH) != text:
			failures.append("%s is stale: run levels_tool.gd -- --write" % PAR_PATH)

	for f in failures:
		printerr("FAIL ", f)
	if not failures.is_empty():
		print("LEVELS_FAIL %d" % failures.size())
		return 1
	print("LEVELS_OK %d" % par.size())
	return 0


# The one-block version of each level with two or more blocks, in level order: [id, keep, open text, walls, min, solution].
func _solo_versions(levels: Array, failures: PackedStringArray) -> Array:
	var solo := []
	var multi := 0
	for index in levels.size():
		var def: Dictionary = levels[index]
		var label := "L%d" % (index + 1)
		var lv = LevelParser.parse(def, index)
		if not lv.errors.is_empty() or lv.starts.size() < 2:
			continue
		multi += 1
		var t0 := Time.get_ticks_msec()
		var v := SoloSearch.search(def, index)
		var ms := Time.get_ticks_msec() - t0
		if v.is_empty():
			print("%s SOLO none ms=%d" % [label, ms])
			if SoloSearch.PINNED.has(def.id):
				failures.append("%s SOLO: the pinned version fails a check" % label)
			continue
		var version = LevelParser.parse(SoloVariant.make_def(def, v.keep, v.walls, v.open), index)
		var s := Solver.solve(version) if version.errors.is_empty() else {}
		if not version.errors.is_empty() or version.starts.size() != 1 or s.is_empty() or s.min != v.min:
			failures.append("%s SOLO: the version does not match the search" % label)
		elif Solver.has_trap(version):
			failures.append("%s SOLO: a trap (a reachable state that cannot paint the full floor)" % label)
		var t := ScoreRules.thresholds(v.min, index)
		var r3 := ScoreRules.range_for(3, t)
		var r2 := ScoreRules.range_for(2, t)
		var r1 := ScoreRules.range_for(1, t)
		var cells := PackedStringArray(v.walls.map(func(c: int) -> String: return str(c)))
		var walls := ",".join(cells)
		var open_cells := PackedStringArray(v.open.map(func(c: int) -> String: return str(c)))
		print("%s SOLO keep=%d open=[%s] walls=[%s] floor=%d min=%d 3*=%d-%d 2*=%d-%d 1*=%d-%d limit=%d solution=%s states=%d searched=%d deadend=%d ms=%d" % [
			label, v.keep, ",".join(open_cells), walls, v.floor, v.min, r3.x, r3.y, r2.x, r2.y, r1.x, r1.y, t.limit, v.solution, v.states, v.searched,
			int(v.dead_end), ms])
		var open_text := "\"open\": [%s], " % ", ".join(open_cells) if not v.open.is_empty() else ""
		solo.append([def.id, v.keep, open_text, ", ".join(cells), v.min, v.solution])
	print("SOLO_COUNT %d/%d" % [solo.size(), multi])
	return solo


func _par_text(par: Array, solo: Array) -> String:
	var text := "extends RefCounted\n\n# Generated by tools/levels_tool.gd -- --write. Do not edit by hand.\nconst PAR := {\n"
	for entry in par:
		text += "\t\"%s\": {\"min\": %d, \"solution\": \"%s\"},\n" % entry
	text += "}\n\n"
	text += "# The one-block version of each level with two or more blocks: the kept block id of the normal map,\n"
	text += "# the obstacle cells that become floor (when any), the wall cells (index y * cols + x of the map, ascending)\n"
	text += "# and the par of that version.\n"
	text += "const SOLO := {\n"
	for entry in solo:
		text += "\t\"%s\": {\"keep\": %d, %s\"walls\": [%s], \"min\": %d, \"solution\": \"%s\"},\n" % entry
	return text + "}\n"
