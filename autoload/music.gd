extends Node
## Music: a calm clip and a tense clip, one AudioStreamPlayer each, on the bus Music.
## The change between the clips starts on a beat of the clip that plays. The clock
## reads the playback position, or a virtual clock on the Dummy driver and when a
## stream is absent, so the beat signal and state() also work in scripted runs.

const AudioBank := preload("res://scripts/audio/audio_bank.gd")
const AudioTuning := preload("res://scripts/audio/audio_tuning.gd")

const CALM := &"calm"
const TENSE := &"tense"

var _players: Dictionary = {}           # clip -> AudioStreamPlayer
var _virtual := true
var _playing := false
var _clip := CALM
var _want := CALM
var _vpos := 0.0
var _rate := 1.0
var _beat := -1
var _announced := &""
var _last_usec := 0
var _frame_time := 1.0 / 60.0
var _fill := 0.0
var _paused := false
var _cutoff := AudioTuning.FILTER_MIN_HZ
var _duck_db := 0.0
var _tape_active := false
var _filter: AudioEffectLowPassFilter
var _filter_tween: Tween
var _duck_tween: Tween
var _tape_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioBank.ensure_buses()
	AudioBank.load_table(AudioBank.MUSIC)
	_virtual = AudioBank.is_dummy_driver()
	for clip: StringName in AudioBank.MUSIC:
		var player := AudioStreamPlayer.new()
		player.name = String(clip).capitalize()
		player.bus = AudioBank.MUSIC_BUS
		var stream := AudioBank.stream(clip) as AudioStreamWAV
		if stream == null:
			_virtual = true
		else:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = AudioBank.MUSIC[clip]["frames"]
			player.stream = stream
		add_child(player)
		_players[clip] = player
	_filter = AudioBank.music_filter()
	_set_cutoff(_cutoff)
	_set_muted(not Save.setting(&"music"))
	_connect_bus()
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - _last_usec) / 1000000.0
	_last_usec = now
	_frame_time = clampf(dt, 1.0 / 240.0, 1.0 / 20.0)
	if not _playing:
		return
	if _virtual:
		_vpos = fposmod(_vpos + dt * _rate, AudioBank.loop_seconds(_clip))
	var pos := _clock()
	var beat_len := 60.0 / _bpm(_clip)
	if _want != _clip and not _tape_active:
		var to_next := (floorf(pos / beat_len) + 1.0) * beat_len - pos
		if to_next <= _frame_time:
			_switch(_want)
			return
	var beat := floori(pos / beat_len) % _beats_in_loop(_clip)
	if beat != _beat:
		_beat = beat
		Bus.music_beat.emit(beat, _clip == TENSE)


func start() -> void:
	if _playing:
		return
	_playing = true
	_set_clip(_want)
	_restart_clip()


func stop() -> void:
	_playing = false
	_end_tape(false)
	_beat = -1
	_announced = &""
	for player: AudioStreamPlayer in _players.values():
		player.stop()


func set_tense(on: bool) -> void:
	_want = TENSE if on else CALM
	if not _playing:
		_set_clip(_want)


func set_fill(ratio: float) -> void:
	_fill = clampf(ratio, 0.0, 1.0)
	if not _paused:
		_glide_filter(_fill_cutoff())


func duck(db: float, seconds: float) -> void:
	_tween_duck(db, seconds)


func unduck(seconds: float) -> void:
	_tween_duck(0.0, seconds)


## Slows the clip that plays to a stop, then the calm clip starts again at a low level.
func tape_stop(seconds: float) -> void:
	if not _playing:
		return
	_end_tape(false)
	_tape_active = true
	_want = CALM
	_tape_tween = _new_tween()
	_tape_tween.tween_method(_apply_rate, 1.0, AudioTuning.TAPE_END_PITCH, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tape_tween.parallel().tween_property(_players[_clip], "volume_db", AudioTuning.SILENT_DB, seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tape_tween.tween_callback(_after_tape)


func state() -> Dictionary:
	return {
		"playing": _playing,
		"clip": String(_clip),
		"bpm": _bpm(_clip),
		"cutoff_hz": _cutoff,
		"beat": maxi(_beat, 0),
	}


func _connect_bus() -> void:
	Bus.tension_changed.connect(set_tense)
	Bus.session_changed.connect(_on_session_changed)
	Bus.ceremony_started.connect(_on_ceremony_started)
	Bus.ceremony_finished.connect(_on_ceremony_finished)
	Bus.level_loaded.connect(_on_level_reset)
	Bus.level_restarted.connect(_on_level_reset)
	Bus.paused_changed.connect(_on_paused_changed)
	Bus.setting_changed.connect(_on_setting_changed)


# --- Clock and clips ---------------------------------------------------------

func _clock() -> float:
	if _virtual:
		return _vpos
	var player: AudioStreamPlayer = _players[_clip]
	if not player.playing:
		return 0.0
	var pos := player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return fposmod(pos, AudioBank.loop_seconds(_clip))


func _bpm(clip: StringName) -> int:
	return AudioBank.MUSIC[clip]["bpm"]


func _beats_in_loop(clip: StringName) -> int:
	return int(AudioBank.MUSIC[clip]["bars"]) * AudioTuning.BEATS_PER_BAR


func _set_clip(clip: StringName) -> void:
	_clip = clip
	if clip == _announced:
		return
	_announced = clip
	if Harness.has_arg("audio-log"):
		print("MUSIC clip=%s bpm=%d" % [clip, _bpm(clip)])


## Starts the current clip at 0 with no fade and stops the other clip.
func _restart_clip() -> void:
	_vpos = 0.0
	_beat = -1
	if _virtual:
		return
	for clip: StringName in _players:
		var player: AudioStreamPlayer = _players[clip]
		if clip == _clip:
			player.volume_db = 0.0
			player.pitch_scale = 1.0
			player.play(0.0)
		else:
			player.stop()


## The beat change: the new clip starts at 0, the old clip fades out.
func _switch(clip: StringName) -> void:
	var old: StringName = _clip
	_beat = -1
	_set_clip(clip)
	_vpos = 0.0
	if not _virtual:
		var player: AudioStreamPlayer = _players[clip]
		player.volume_db = 0.0
		player.pitch_scale = 1.0
		player.play(0.0)
		var leaving: AudioStreamPlayer = _players[old]
		var fade := _new_tween()
		fade.tween_property(leaving, "volume_db", AudioTuning.SILENT_DB, AudioTuning.SWITCH_FADE_TIME)
		fade.tween_callback(_stop_if_idle.bind(old))
	_beat = 0
	Bus.music_beat.emit(0, _clip == TENSE)


func _stop_if_idle(clip: StringName) -> void:
	if clip != _clip:
		(_players[clip] as AudioStreamPlayer).stop()


func _apply_rate(rate: float) -> void:
	_rate = rate
	if not _virtual:
		(_players[_clip] as AudioStreamPlayer).pitch_scale = rate


func _after_tape() -> void:
	_tape_active = false
	_rate = 1.0
	_beat = -1
	_set_clip(CALM)
	_restart_clip()
	_apply_duck(AudioTuning.SILENT_DB)
	_tween_duck(AudioTuning.DEFEAT_RETURN_DB, AudioTuning.DEFEAT_RETURN_TIME)


## Ends a tape stop at once. With `restart`, the calm clip starts again at 0.
func _end_tape(restart: bool) -> void:
	if _tape_tween != null and _tape_tween.is_valid():
		_tape_tween.kill()
	if not _tape_active:
		return
	_tape_active = false
	_apply_rate(1.0)
	_set_clip(CALM)
	if restart:
		_restart_clip()


# --- Filter and level --------------------------------------------------------

func _fill_cutoff() -> float:
	var lo := AudioTuning.FILTER_MIN_HZ
	return lo * pow(AudioTuning.FILTER_MAX_HZ / lo, _fill)


func _glide_filter(hz: float) -> void:
	if _filter_tween != null and _filter_tween.is_valid():
		_filter_tween.kill()
	var from := _filter.cutoff_hz if _filter != null else _cutoff
	_cutoff = hz
	_filter_tween = _new_tween()
	_filter_tween.tween_method(_set_cutoff, from, hz, AudioTuning.FILTER_GLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_cutoff(hz: float) -> void:
	if _filter != null:
		_filter.cutoff_hz = hz


func _tween_duck(db: float, seconds: float) -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	if seconds <= 0.0:
		_apply_duck(db)
		return
	_duck_tween = _new_tween()
	_duck_tween.tween_method(_apply_duck, _duck_db, db, seconds)


func _apply_duck(db: float) -> void:
	_duck_db = db
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(AudioBank.MUSIC_BUS), AudioTuning.MUSIC_DB + db)


func _set_muted(on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioBank.MUSIC_BUS), on)


func _new_tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)


# --- Bus ---------------------------------------------------------------------

func _on_session_changed(snapshot: Dictionary) -> void:
	var floor_count := int(snapshot.get("floor", 0))
	if floor_count > 0:
		set_fill(float(snapshot.get("painted", 0)) / float(floor_count))


func _on_ceremony_started(kind: StringName) -> void:
	if kind == &"win":
		duck(AudioTuning.WIN_DUCK_DB, AudioTuning.WIN_DUCK_TIME)
	elif kind == &"defeat":
		tape_stop(AudioTuning.DEFEAT_TAPE_TIME)


func _on_ceremony_finished(kind: StringName) -> void:
	if kind == &"win":
		unduck(AudioTuning.UNDUCK_TIME)


func _on_level_reset(_index: int) -> void:
	_end_tape(_playing)
	set_tense(false)
	unduck(AudioTuning.UNDUCK_TIME)
	set_fill(0.0)
	start()


func _on_paused_changed(on: bool) -> void:
	_paused = on
	_glide_filter(AudioTuning.FILTER_PAUSE_HZ if on else _fill_cutoff())


func _on_setting_changed(key: StringName, value: bool) -> void:
	if key == &"music":
		_set_muted(not value)
