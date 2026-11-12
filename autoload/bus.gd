extends Node

signal screen_changed(screen: StringName)
signal level_loaded(index: int)
signal level_ready(index: int)
signal session_changed(snapshot: Dictionary)
signal star_lost(stars_left: int)
signal tension_changed(on: bool)
signal paused_changed(on: bool)
signal swipe_ignored(dir: int)
signal swipe_started(outcome: Dictionary)
signal tile_painted(cell: int, hue: int, fresh: bool, step: int)
signal block_turned(block: int, cell: int)
signal block_stopped(block: int, cell: int, dir: int, cause: StringName, power: float, last: bool)
signal swipe_finished(outcome: Dictionary)
signal ceremony_started(kind: StringName)
signal ceremony_cue(cue: StringName, value: int)
signal ceremony_finished(kind: StringName)
signal level_won(summary: Dictionary)
signal level_lost(summary: Dictionary)
signal star_shown(n: int)
signal ui_tap
signal ui_locked
signal level_unlocked(index: int)
signal music_beat(index: int, tense: bool)
signal setting_changed(key: StringName, value: bool)
## Game, when a level starts again from its first state (restart button, R key or retry).
signal level_restarted(index: int)
