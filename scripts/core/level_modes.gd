extends RefCounted
# The playable versions of each level of LevelsData: the normal map and, when ParData.SOLO has one, the one-block map.

const LevelsData := preload("res://scripts/core/levels_data.gd")
const ParData := preload("res://scripts/core/par_data.gd")
const SoloVariant := preload("res://scripts/core/solo_variant.gd")


## &"single" when the map has one block, &"ready" when ParData.SOLO has a version, else &"none".
static func solo_state(index: int) -> StringName:
	var def: Dictionary = LevelsData.LEVELS[index]
	if ParData.SOLO.has(def.id):
		return &"ready"
	var digits := {}
	for line in def.rows:
		for ch in String(line):
			if ch >= "1" and ch <= "9":
				digits[ch] = true
	return &"single" if digits.size() <= 1 else &"none"


## The definition to play: the one-block version when `solo` is true and the state is &"ready", else the normal one.
static func def_for(index: int, solo: bool) -> Dictionary:
	var def: Dictionary = LevelsData.LEVELS[index]
	if solo and ParData.SOLO.has(def.id):
		var entry: Dictionary = ParData.SOLO[def.id]
		return SoloVariant.make_def(def, entry.keep, entry.walls)
	return def


## {"min", "solution"} for an id that def_for gives ("l4" or "l4_solo"). {} for an unknown id.
static func par_for(level_id: String) -> Dictionary:
	var entry: Dictionary = {}
	if level_id.ends_with(SoloVariant.SUFFIX):
		entry = ParData.SOLO.get(level_id.trim_suffix(SoloVariant.SUFFIX), {})
	else:
		entry = ParData.PAR.get(level_id, {})
	if entry.is_empty():
		return {}
	return {"min": entry.min, "solution": entry.solution}


## The Save record id of the version that def_for gives.
static func record_id(index: int, solo: bool) -> String:
	var id: String = LevelsData.LEVELS[index].id
	return id + SoloVariant.SUFFIX if solo and ParData.SOLO.has(id) else id


## True for each id that def_for can give.
static func is_level_id(level_id: String) -> bool:
	var base := level_id.trim_suffix(SoloVariant.SUFFIX) if level_id.ends_with(SoloVariant.SUFFIX) else level_id
	if base != level_id and not ParData.SOLO.has(base):
		return false
	for def in LevelsData.LEVELS:
		if def.id == base:
			return true
	return false


## The level info (second argument of the level_loaded signal) for a level of LevelsData.
static func info(index: int, solo: bool) -> Dictionary:
	var def: Dictionary = LevelsData.LEVELS[index]
	var is_solo := solo and ParData.SOLO.has(def.id)
	return {
		"mode": &"solo" if is_solo else &"normal",
		"index": index,
		"seed": 0,
		"solo": is_solo,
		"name_key": String(def.get("name_key", "")),
		"hint_key": "" if is_solo else String(def.get("hint_key", "")),
	}
