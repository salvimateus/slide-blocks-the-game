extends SceneTree
# Checks the random level generator on a seed range: each seed must give a level, two times the same one,
# and a worker thread must give the same level as the main thread.
# Args after "--": --from=<seed> (default 1), --count=<n> (default 200), --solo, --map (print the rows),
# --seed=<n> (one seed, the same as --from=<n> --count=1 --map).

const RandomLevel := preload("res://scripts/core/random_level.gd")
const ScoreRules := preload("res://scripts/core/score_rules.gd")


func _init() -> void:
	var from := 1
	var count := 200
	var solo := false
	var show_map := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--from="):
			from = arg.trim_prefix("--from=").to_int()
		elif arg.begins_with("--count="):
			count = arg.trim_prefix("--count=").to_int()
		elif arg == "--solo":
			solo = true
		elif arg == "--map":
			show_map = true
		elif arg.begins_with("--seed="):
			from = arg.trim_prefix("--seed=").to_int()
			count = 1
			show_map = true
	if count < 1:
		printerr("random_tool: --count must be 1 or more")
		quit(1)
		return
	quit(_run(from, count, solo, show_map))


func _run(from: int, count: int, solo: bool, show_map: bool) -> int:
	var failures := PackedStringArray()
	var times: Array[float] = []
	var mins: Array[int] = []
	var by_blocks := {}
	var max_attempts := 0
	var max_states := 0
	for seed_value in range(from, from + count):
		var t0 := Time.get_ticks_usec()
		var r := RandomLevel.generate(seed_value, solo)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		times.append(ms)
		if r.is_empty():
			print("SEED %d FAIL ms=%.1f" % [seed_value, ms])
			failures.append("seed %d: no level" % seed_value)
			continue
		if not _same(r, RandomLevel.generate(seed_value, solo)):
			failures.append("seed %d: not deterministic" % seed_value)
		var level = r.level
		var t := ScoreRules.thresholds(r.min, RandomLevel.SCORE_INDEX)
		by_blocks[r.blocks] = int(by_blocks.get(r.blocks, 0)) + 1
		max_attempts = maxi(max_attempts, r.attempts)
		max_states = maxi(max_states, r.states)
		mins.append(r.min)
		print("SEED %d blocks=%d size=%dx%d floor=%d defl=%d min=%d 3*<=%d limit=%d states=%d attempts=%d ms=%.1f" % [
			seed_value, r.blocks, level.cols, level.rows, level.floor_count, r.deflectors, r.min, t.three_max, t.limit,
			r.states, r.attempts, ms])
		if show_map:
			print("SOLUTION ", r.solution)
			for row in r.def.rows:
				print("    ", row)

	var thread := Thread.new()
	thread.start(Callable(RandomLevel, "generate").bind(from, solo))
	var threaded: Dictionary = thread.wait_to_finish()
	if not _same(threaded, RandomLevel.generate(from, solo)):
		failures.append("seed %d: thread result differs" % from)
	var cancel := RandomLevel.Cancel.new()
	cancel.cancelled = true
	if not RandomLevel.generate(from, solo, cancel).get("cancelled", false):
		failures.append("seed %d: a cancel does not stop the generator" % from)

	times.sort()
	mins.sort()
	print("SUMMARY count=%d fails=%d blocks=%s p50_ms=%.1f p90_ms=%.1f p99_ms=%.1f max_ms=%.1f max_attempts=%d max_states=%d min_p50=%d" % [
		count, failures.size(), by_blocks, _percentile(times, 0.5), _percentile(times, 0.9), _percentile(times, 0.99),
		times[times.size() - 1], max_attempts, max_states, mins[int(mins.size() * 0.5)] if not mins.is_empty() else 0])
	for f in failures:
		printerr("FAIL ", f)
	if not failures.is_empty():
		print("RANDOM_FAIL %d" % failures.size())
		return 1
	print("RANDOM_OK %d" % count)
	return 0


func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return a.is_empty() and b.is_empty()
	return a.def.rows == b.def.rows and a.min == b.min and a.solution == b.solution


func _percentile(sorted: Array[float], share: float) -> float:
	return sorted[mini(int(sorted.size() * share), sorted.size() - 1)]
