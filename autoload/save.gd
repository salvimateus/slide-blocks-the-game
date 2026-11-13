extends Node
## Progress and settings in a ConfigFile at user://save.cfg.
## [meta] version, [level.<id>] stars, best_moves, best_time_ms, [settings] music, sfx, haptics, reduced_motion, solo, language.
## A one-jelly version keeps its own record in [level.<id>_solo]; the best moves of the two versions never mix.
## `solo` is the wish of the player for one jelly; a level with no one-jelly version plays its normal map.
## `language` is "pt" or "en"; with no key the UI follows the device language.
## A read error gives default data in memory; an unreadable file is kept next to the save as <name>.bad.

const LevelsData := preload("res://scripts/core/levels_data.gd")
const Strings := preload("res://scripts/ui/strings.gd")
const LevelModes := preload("res://scripts/core/level_modes.gd")
const SoloVariant := preload("res://scripts/core/solo_variant.gd")

const VERSION := 1
const DEFAULT_PATH := "user://save.cfg"
const DEFAULT_SETTINGS := {&"music": true, &"sfx": true, &"haptics": true, &"reduced_motion": false, &"solo": false}
const NO_RECORD := {"stars": 0, "best_moves": 0, "best_time_ms": 0}

var _path := DEFAULT_PATH
var _records: Dictionary = {}       # level id -> {"stars", "best_moves", "best_time_ms"}
var _settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var _language: StringName = &""          # the stored choice; &"" follows the device
var _forced_language: StringName = &""   # this run only (harness)
var _unlock_all := false
var _dirty := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_apply_language()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		flush()


## Stores the result of a won level. Each field keeps its better value. A result with no star stores nothing.
## "new_best" is true when the level had a record and this result has more stars or fewer moves.
## An id that is not a version of a level of LevelsData (for example a random level) stores nothing.
func record(level_id: String, stars: int, moves: int, time_ms: int) -> Dictionary:
	if not LevelModes.is_level_id(level_id):
		push_warning("Save: no record for '%s'" % level_id)
		return {"new_best": false}
	if stars <= 0:
		return {"new_best": false}
	var old := best(level_id)
	var had := int(old.stars) > 0
	var entry := {
		"stars": maxi(int(old.stars), clampi(stars, 1, 3)),
		"best_moves": moves if not had or moves < int(old.best_moves) else int(old.best_moves),
		"best_time_ms": time_ms if not had or time_ms < int(old.best_time_ms) else int(old.best_time_ms),
	}
	_records[level_id] = entry
	_dirty = true
	flush()
	return {"new_best": had and (stars > int(old.stars) or moves < int(old.best_moves))}


## Level 0 is always open. Level n opens when level n - 1 has one star or more, in its normal or its one-jelly record.
func is_unlocked(index: int) -> bool:
	if index < 0 or index >= LevelsData.LEVELS.size():
		return false
	if index == 0 or _unlock_all:
		return true
	var prev: String = LevelsData.LEVELS[index - 1].id
	return int(best(prev).stars) >= 1 or int(best(prev + SoloVariant.SUFFIX).stars) >= 1


func best(level_id: String) -> Dictionary:
	return _records.get(level_id, NO_RECORD).duplicate()


func highest_unlocked() -> int:
	var highest := 0
	for i in LevelsData.LEVELS.size():
		if is_unlocked(i):
			highest = i
	return highest


func setting(key: StringName) -> bool:
	return _settings.get(key, false)


func set_setting(key: StringName, value: bool) -> void:
	if not DEFAULT_SETTINGS.has(key):
		push_warning("Save: unknown setting '%s'" % key)
		return
	if _settings[key] == value:
		return
	_settings[key] = value
	_dirty = true
	flush()
	Bus.setting_changed.emit(key, value)


## The locale of the UI: the forced language of this run, else the stored choice, else the device language.
func language() -> StringName:
	if _forced_language != &"":
		return _forced_language
	if _language != &"":
		return _language
	return Strings.locale_for(OS.get_locale_language())


## Stores the choice of the player and changes the UI text to it.
func set_language(code: StringName) -> void:
	if not Strings.TABLES.has(code):
		push_warning("Save: unknown language '%s'" % code)
		return
	_forced_language = &""
	if _language != code:
		_language = code
		_dirty = true
		flush()
	_apply_language()


## Changes the UI text for this run only, with no write. The harness uses it.
func force_language(code: StringName) -> void:
	if not Strings.TABLES.has(code):
		push_warning("Save: unknown language '%s'" % code)
		return
	_forced_language = code
	_apply_language()


## Points the store to a different file and reads it. The harness uses it for a clean save.
func use_path(path: String) -> void:
	flush()
	_path = path
	_load()
	_apply_language()


## Opens all levels, in memory only.
func unlock_all() -> void:
	_unlock_all = true


func flush() -> void:
	if not _dirty:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	for id: String in _records:
		var entry: Dictionary = _records[id]
		for field: String in entry:
			cfg.set_value("level." + id, field, entry[field])
	for key: StringName in _settings:
		cfg.set_value("settings", String(key), _settings[key])
	if _language != &"":
		cfg.set_value("settings", "language", String(_language))
	var dir_err := DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	if dir_err != OK and not DirAccess.dir_exists_absolute(_path.get_base_dir()):
		push_warning("Save: cannot create the folder of %s (error %d)" % [_path, dir_err])
		return
	var err := cfg.save(_path)
	if err != OK:
		push_warning("Save: cannot write %s (error %d)" % [_path, err])
		return
	_dirty = false


func _apply_language() -> void:
	var code := language()
	if code == Strings.locale():
		return
	Strings.set_locale(code)
	Bus.locale_changed.emit(code)


func _load() -> void:
	_records.clear()
	_settings = DEFAULT_SETTINGS.duplicate()
	_language = &""
	_dirty = false
	if not FileAccess.file_exists(_path):
		return
	var cfg := ConfigFile.new()
	var err := cfg.load(_path)
	if err != OK:
		push_warning("Save: cannot read %s (error %d), using default data" % [_path, err])
		DirAccess.rename_absolute(_path, _path + ".bad")
		return
	for key: StringName in DEFAULT_SETTINGS:
		var value: Variant = cfg.get_value("settings", String(key), DEFAULT_SETTINGS[key])
		if typeof(value) == TYPE_BOOL:
			_settings[key] = value
	var language_value: Variant = cfg.get_value("settings", "language", "")
	if typeof(language_value) == TYPE_STRING and Strings.TABLES.has(StringName(language_value)):
		_language = StringName(language_value)
	for i in LevelsData.LEVELS.size():
		var id := String(LevelsData.LEVELS[i].id)
		_load_record(cfg, id)
		if LevelModes.solo_state(i) == &"ready":
			_load_record(cfg, id + SoloVariant.SUFFIX)


func _load_record(cfg: ConfigFile, id: String) -> void:
	var section := "level." + id
	if not cfg.has_section(section):
		return
	var stars := clampi(_read_int(cfg, section, "stars"), 0, 3)
	if stars == 0:
		return
	_records[id] = {
		"stars": stars,
		"best_moves": maxi(_read_int(cfg, section, "best_moves"), 0),
		"best_time_ms": maxi(_read_int(cfg, section, "best_time_ms"), 0),
	}


static func _read_int(cfg: ConfigFile, section: String, key: String) -> int:
	var value: Variant = cfg.get_value(section, key, 0)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return 0
