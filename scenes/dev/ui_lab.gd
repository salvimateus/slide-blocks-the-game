extends Control
## UI lab: shows one screen with realistic fake data, chosen by --ui-screen=<name>,
## and reports Harness.mark(<name>) when the screen is at rest.
## Names: home, levels, hud, hud_tense, pause, result, result_last, defeat, loading, replay.
## --ui-script=<abs path> runs a check script (a Node with run() -> int) with the autoloads present, then quits.

const Palette := preload("res://scripts/core/palette.gd")
const LevelsData := preload("res://scripts/core/levels_data.gd")
const LevelParser := preload("res://scripts/core/level_parser.gd")
const ParData := preload("res://scripts/core/par_data.gd")
const LevelModes := preload("res://scripts/core/level_modes.gd")
const ScoreRules := preload("res://scripts/core/score_rules.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiTuning := preload("res://scripts/ui/ui_tuning.gd")
const LevelThumb := preload("res://scripts/ui/level_thumb.gd")
const HomeScreen := preload("res://scripts/ui/home_screen.gd")
const LevelSelectScreen := preload("res://scripts/ui/level_select_screen.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const PauseDialog := preload("res://scripts/ui/pause_dialog.gd")
const ResultCard := preload("res://scripts/ui/result_card.gd")
const DefeatCard := preload("res://scripts/ui/defeat_card.gd")
const LoadingScreen := preload("res://scripts/ui/loading_screen.gd")
const ReplayOverlay := preload("res://scripts/ui/replay_overlay.gd")
const AudioTuning := preload("res://scripts/audio/audio_tuning.gd")

const LAB_SAVE := "user://ui_lab_save.cfg"
const FAKE_BEAT := 60.0 / AudioTuning.TENSE_BPM

var _board_layer: Control
var _ui_layer: CanvasLayer
var _beat := 0


func _ready() -> void:
	get_tree().root.theme = UiTheme.build()
	ThemeDB.fallback_font = UiTheme.font(UiTuning.WEIGHT_BODY)
	var background := ColorRect.new()
	background.color = Palette.CREAM
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_board_layer = Control.new()
	_board_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_board_layer)
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)
	if Harness.has_arg("ui-script"):
		_run_script(Harness.arg("ui-script"))
		return
	_fake_progress()
	var which := Harness.arg("ui-screen", "home")
	match which:
		"home":
			await _show_home()
		"levels":
			await _show_levels()
		"hud":
			await _show_hud(0, 0)
		"hud_tense":
			await _show_tense_hud()
		"pause":
			await _show_pause()
		"result":
			await _show_card(ResultCard.new(), _summary(1, 11, 42_300, true, &"won"))
		"result_last":
			await _show_card(ResultCard.new(), _summary(LevelsData.LEVELS.size() - 1, 27, 95_000, false, &"won"))
		"defeat":
			await _show_card(DefeatCard.new(), _summary(4, 29, 61_000, false, &"lost"))
		"loading":
			await _show_loading()
		"replay":
			await _show_replay()
		_:
			push_warning("ui_lab: unknown --ui-screen '%s'" % which)
			return
	Harness.mark(which)


# Levels 1 to 4 played, level 5 open and new, the levels after it locked.
func _fake_progress() -> void:
	if FileAccess.file_exists(LAB_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LAB_SAVE))
	Save.use_path(LAB_SAVE)
	var stars := [3, 2, 3, 1]
	for i in stars.size():
		Save.record(LevelsData.LEVELS[i].id, stars[i], 10 + i, 30_000 + i * 5_000)


func _show_home() -> void:
	_add_thumb(LevelsData.DEMO, 0, Rect2(Vector2(70, 420), Vector2(580, 440)))
	var screen := HomeScreen.new()
	_ui_layer.add_child(screen)
	screen.open()
	await screen.opened
	await _wait(0.5)


func _show_levels() -> void:
	var screen := LevelSelectScreen.new()
	_ui_layer.add_child(screen)
	screen.open()
	await screen.opened
	await _wait(0.8)


func _show_hud(index: int, moves: int) -> Control:
	var hud := Hud.new()
	_ui_layer.add_child(hud)
	hud.open()
	Bus.level_loaded.emit(index, LevelModes.info(index, false))
	Bus.session_changed.emit(_snapshot(index, 0))
	await hud.opened
	_add_thumb(LevelsData.LEVELS[index], index, hud.board_rect().grow(-24.0))
	if moves > 0:
		Bus.session_changed.emit(_snapshot(index, moves))
		await _wait(0.4)
	return hud


func _show_tense_hud() -> void:
	var index := 4
	await _show_hud(index, 19)
	Bus.session_changed.emit(_snapshot(index, 26))
	Bus.star_lost.emit(1)
	Bus.tension_changed.emit(true)
	var beats := Timer.new()
	beats.wait_time = FAKE_BEAT
	beats.timeout.connect(func() -> void:
		_beat += 1
		Bus.music_beat.emit(_beat, true))
	add_child(beats)
	beats.start()
	await _wait(FAKE_BEAT * 2.0 + 0.05)


func _show_pause() -> void:
	await _show_hud(2, 4)
	var dialog := PauseDialog.new()
	_ui_layer.add_child(dialog)
	dialog.open()
	await dialog.opened
	await _wait(0.2)


func _show_card(card: Control, summary: Dictionary) -> void:
	await _show_hud(summary.level_index, summary.moves)
	_ui_layer.add_child(card)
	card.open(summary)
	await card.opened
	await _wait(0.4)


func _show_loading() -> void:
	_add_thumb(LevelsData.LEVELS[4], 4, Rect2(Vector2(40, 300), Vector2(640, 700)))
	var screen := LoadingScreen.new()
	_ui_layer.add_child(screen)
	screen.open({"seed": 123456})
	screen.reveal()
	await screen.opened
	await _wait(0.2)


func _show_replay() -> void:
	_add_thumb(LevelsData.LEVELS[4], 4, Rect2(Vector2(40, 200), Vector2(640, 840)))
	var overlay := ReplayOverlay.new()
	_ui_layer.add_child(overlay)
	overlay.open({"total": 14})
	overlay.set_step(5, 14)
	await _wait(0.4)


func _add_thumb(def: Dictionary, index: int, rect: Rect2) -> void:
	var thumb := LevelThumb.new().setup(def, index)
	thumb.position = rect.position
	thumb.size = rect.size
	_board_layer.add_child(thumb)


func _thresholds(index: int) -> Dictionary:
	var id: String = LevelsData.LEVELS[index].id
	return ScoreRules.thresholds(ParData.PAR[id].min, index)


func _snapshot(index: int, moves: int) -> Dictionary:
	var def: Dictionary = LevelsData.LEVELS[index]
	var level := LevelParser.parse(def, index)
	var t := _thresholds(index)
	var floor_count: int = level.floor_count
	@warning_ignore("integer_division")
	var painted := mini(level.starts.size() + moves * floor_count / maxi(t.limit, 1), floor_count - 3)
	return {
		"level_index": index, "level_id": def.id, "status": &"playing",
		"moves_used": moves, "min": t.min, "three_max": t.three_max, "two_max": t.two_max, "limit": t.limit,
		"tension_moves": t.tension_moves, "moves_left": t.limit - moves, "stars": maxi(ScoreRules.stars_for(moves, t), 1),
		"painted": painted, "floor": floor_count, "tense": ScoreRules.is_tense(moves, t), "positions": [],
	}


func _summary(index: int, moves: int, time_ms: int, new_best: bool, status: StringName) -> Dictionary:
	var def: Dictionary = LevelsData.LEVELS[index]
	var level := LevelParser.parse(def, index)
	var t := _thresholds(index)
	var won := status == &"won"
	var stars := ScoreRules.stars_for(moves, t) if won else 0
	var span := ScoreRules.range_for(stars, t)
	return {
		"level_index": index, "level_id": def.id, "status": status, "moves": moves, "stars": stars,
		"range_lo": span.x, "range_hi": span.y, "time_ms": time_ms,
		"min": t.min, "three_max": t.three_max, "two_max": t.two_max, "limit": t.limit,
		"painted": level.floor_count if won else level.floor_count - 7, "floor": level.floor_count,
		"new_best": new_best, "is_last": index == LevelsData.LEVELS.size() - 1, "next_unlocked": won,
	}


func _run_script(path: String) -> void:
	var script := load(path) as Script
	if script == null:
		push_error("ui_lab: cannot load %s" % path)
		Harness.finish(1)
		return
	var node: Node = script.new()
	add_child(node)
	var failures: int = await node.run()
	print("UI_SCRIPT failures=%d" % failures)
	Harness.finish(1 if failures > 0 else 0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
