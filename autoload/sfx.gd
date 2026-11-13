extends Node
## Sound effects: one AudioStreamPlayer with an AudioStreamPolyphonic on the bus SFX.
## Subscribes to the Bus signals by itself. On the Dummy driver it plays nothing.

const AudioBank := preload("res://scripts/audio/audio_bank.gd")
const AudioTuning := preload("res://scripts/audio/audio_tuning.gd")

const LADDERS := {
	&"paint": AudioTuning.PAINT_SEMITONES,
	&"ring": AudioTuning.RING_SEMITONES,
	&"star": AudioTuning.STAR_SEMITONES,
}

var _player: AudioStreamPlayer
var _playback: AudioStreamPlaybackPolyphonic
var _silent := true
var _rng := RandomNumberGenerator.new()
var _note_step := -1
var _tick_step := -1
var _glitter_times: Array[int] = []
var _stop_window_start := -1000000
var _stop_count := 0
## Added to each board sound: AudioTuning.REPLAY_BOARD_DB during a replay, else 0.
var _board_db := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	AudioBank.ensure_buses()
	AudioBank.load_table(AudioBank.SFX)
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = AudioTuning.POLYPHONY
	_player = AudioStreamPlayer.new()
	_player.name = "Voices"
	_player.bus = AudioBank.SFX_BUS
	_player.stream = poly
	add_child(_player)
	_silent = AudioBank.is_dummy_driver()
	if not _silent:
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamPlaybackPolyphonic
		_silent = _playback == null
	_set_muted(not Save.setting(&"sfx"))
	_connect_bus()


## Plays one effect. pitch is a pitch_scale, volume_db adds to the default volume of the sound.
func play(sound: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if Harness.has_arg("audio-log"):
		print("SFX %s pitch=%.3f db=%.1f" % [sound, pitch, AudioBank.volume_db(sound) + volume_db])
	if _silent:
		return
	var stream := AudioBank.stream(sound)
	if stream == null:
		return
	_playback.play_stream(stream, 0.0, AudioBank.volume_db(sound) + volume_db, maxf(pitch, 0.01))


## Plays step `step` (from 0) of the note ladder of a sound: paint, ring or star.
func note(sound: StringName, step: int, volume_db: float = 0.0) -> void:
	var ladder: Array = LADDERS.get(sound, [0])
	var semitones: int = ladder[clampi(step, 0, ladder.size() - 1)]
	play(sound, pow(2.0, semitones / 12.0), volume_db)


## One silent play of each effect, for the boot warm-up.
func warm_up() -> void:
	if _silent:
		return
	for sound: StringName in AudioBank.SFX:
		var stream := AudioBank.stream(sound)
		if stream != null:
			_playback.play_stream(stream, 0.0, AudioTuning.WARM_UP_DB, 1.0)


## Stops all voices. Game calls it before the app quits, so the audio server frees the voices.
func silence() -> void:
	if _player != null:
		_player.stop()


## The path of each stream (effects and music) that did not load.
func missing() -> PackedStringArray:
	return AudioBank.missing()


func _connect_bus() -> void:
	Bus.swipe_started.connect(_on_swipe_started)
	Bus.swipe_ignored.connect(_on_swipe_ignored)
	Bus.tile_painted.connect(_on_tile_painted)
	Bus.block_turned.connect(_on_block_turned)
	Bus.block_stopped.connect(_on_block_stopped)
	Bus.star_lost.connect(_on_star_lost)
	Bus.tension_changed.connect(_on_tension_changed)
	Bus.ceremony_started.connect(_on_ceremony_started)
	Bus.ceremony_cue.connect(_on_ceremony_cue)
	Bus.star_shown.connect(_on_star_shown)
	Bus.ui_tap.connect(play.bind(&"tap"))
	Bus.ui_locked.connect(play.bind(&"locked"))
	Bus.level_unlocked.connect(_on_level_unlocked)
	Bus.level_loaded.connect(_on_level_reset.unbind(1))
	Bus.level_restarted.connect(_on_level_reset)
	Bus.setting_changed.connect(_on_setting_changed)
	Bus.replay_started.connect(func(_total: int) -> void: _board_db = AudioTuning.REPLAY_BOARD_DB)
	Bus.replay_finished.connect(func(_completed: bool, _matched: bool) -> void: _board_db = 0.0)


func _set_muted(on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioBank.SFX_BUS), on)


func _on_swipe_started(outcome: Dictionary) -> void:
	_note_step = -1
	_tick_step = -1
	if outcome.get("moved", true):
		play(&"swipe", 1.0, _board_db)


func _on_swipe_ignored(_dir: int) -> void:
	play(&"thud", 1.0, _board_db)


## One note for each tick: the first fresh paint of a step plays the ladder note,
## and a repaint plays the soft tick only in a step that has no note.
func _on_tile_painted(_cell: int, _hue: int, fresh: bool, step: int) -> void:
	if fresh:
		if step != _note_step:
			_note_step = step
			var top := AudioTuning.PAINT_SEMITONES.size() - 1
			note(&"paint", step, AudioTuning.PAINT_STEP_DB * clampi(step, 0, top) + _board_db)
	elif step != _tick_step and step != _note_step:
		_tick_step = step
		play(&"repaint", 1.0, _board_db)


func _on_block_turned(_block: int, _cell: int) -> void:
	play(&"glide", 1.0 + _rng.randf_range(-0.03, 0.03), _board_db)


## Stops that start in one short window share it: the second one is softer and the rest are silent.
func _on_block_stopped(_block: int, _cell: int, _dir: int, cause: StringName, power: float, _last: bool) -> void:
	if power <= 0.0:
		return
	var now := Time.get_ticks_msec()
	if now - _stop_window_start >= AudioTuning.STOP_WINDOW_MS:
		_stop_window_start = now
		_stop_count = 0
	if _stop_count >= AudioTuning.STOP_VOICES:
		return
	var sound := &"bump" if cause == &"block" else &"squish"
	var gain := lerpf(AudioTuning.STOP_MIN_GAIN, 1.0, clampf(power, 0.0, 1.0))
	var spread := AudioTuning.STOP_PITCH_SPREAD
	play(sound, 1.0 + _rng.randf_range(-spread, spread), linear_to_db(gain) + AudioTuning.STOP_EXTRA_DB * _stop_count + _board_db)
	_stop_count += 1


func _on_star_lost(_stars_left: int) -> void:
	play(&"star_lost")


func _on_tension_changed(on: bool) -> void:
	if on:
		play(&"tension")


func _on_ceremony_started(kind: StringName) -> void:
	if kind == &"defeat":
		get_tree().create_timer(AudioTuning.DEFEAT_PHRASE_DELAY, true, false, true).timeout.connect(play.bind(&"defeat"))


func _on_ceremony_cue(cue: StringName, value: int) -> void:
	match cue:
		&"wave_ring":
			note(&"ring", value)
		&"glitter":
			_glitter()
		&"win_end":
			play(&"win")


func _on_star_shown(n: int) -> void:
	note(&"star", n - 1)


func _on_level_unlocked(_index: int) -> void:
	play(&"unlock")


func _on_level_reset(_index: int) -> void:
	_note_step = -1
	_tick_step = -1
	_stop_window_start = -1000000
	_stop_count = 0


func _on_setting_changed(key: StringName, value: bool) -> void:
	if key == &"sfx":
		_set_muted(not value)


## GLITTER_MAX pings in each GLITTER_WINDOW_MS at most, each on a random pentatonic pitch.
func _glitter() -> void:
	var now := Time.get_ticks_msec()
	while not _glitter_times.is_empty() and now - _glitter_times[0] >= AudioTuning.GLITTER_WINDOW_MS:
		_glitter_times.pop_front()
	if _glitter_times.size() >= AudioTuning.GLITTER_MAX:
		return
	_glitter_times.append(now)
	var ladder: Array = AudioTuning.GLITTER_SEMITONES
	var semitones: int = ladder[_rng.randi_range(0, ladder.size() - 1)]
	play(&"glitter", pow(2.0, semitones / 12.0))
