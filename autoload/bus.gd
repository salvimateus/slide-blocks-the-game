extends Node

signal screen_changed(screen: StringName)
## Game, when a level is built. `info`: {"mode", "index", "seed", "solo", "name_key", "hint_key"};
## mode is &"normal", &"solo" or &"random", and index is -1 for a random level.
signal level_loaded(index: int, info: Dictionary)
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
## Save, after the UI text changes to a different locale.
signal locale_changed(locale: StringName)
## Game, when a level starts again from its first state (restart button, R key or retry).
signal level_restarted(index: int)
## Game, when a random level is ready, just before level_loaded.
signal level_generated(report: Dictionary)
## Game, when a replay starts (the board starts its rewind).
signal replay_started(total: int)
## Game: n = 0 when the board shows the start state, then n after each move of the replay.
signal replay_step(n: int, total: int)
## Game, once for each replay_started, on each path (end, tap, back, restart, leave).
## completed is false when the replay did not reach its last move. matched is true when the end state equals the played game.
signal replay_finished(completed: bool, matched: bool)
