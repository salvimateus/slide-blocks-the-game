extends RefCounted
## The table of audio streams, the shared stream cache and the bus layout.
## Streams load with load() only when ResourceLoader.exists() is true: before the
## first import the files are absent, and each absent stream goes to missing().

const AudioTuning := preload("res://scripts/audio/audio_tuning.gd")

const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"
const SAMPLE_RATE := 44100

## base_hz: the pitch of the sample at pitch_scale 1. db: the default volume.
const SFX := {
	&"swipe": {"path": "res://audio/sfx/swipe.wav", "base_hz": 0.0, "db": -6.0},
	&"paint": {"path": "res://audio/sfx/paint.wav", "base_hz": 523.25, "db": -3.0},
	&"repaint": {"path": "res://audio/sfx/repaint.wav", "base_hz": 1100.0, "db": -10.0},
	&"squish": {"path": "res://audio/sfx/squish.wav", "base_hz": 0.0, "db": -2.0},
	&"bump": {"path": "res://audio/sfx/bump.wav", "base_hz": 0.0, "db": -5.0},
	&"glide": {"path": "res://audio/sfx/glide.wav", "base_hz": 0.0, "db": -6.0},
	&"thud": {"path": "res://audio/sfx/thud.wav", "base_hz": 0.0, "db": -4.0},
	&"star_lost": {"path": "res://audio/sfx/star_lost.wav", "base_hz": 0.0, "db": -4.0},
	&"tension": {"path": "res://audio/sfx/tension.wav", "base_hz": 0.0, "db": -4.0},
	&"ring": {"path": "res://audio/sfx/ring.wav", "base_hz": 523.25, "db": -4.0},
	&"glitter": {"path": "res://audio/sfx/glitter.wav", "base_hz": 1318.51, "db": -10.0},
	&"win": {"path": "res://audio/sfx/win.wav", "base_hz": 0.0, "db": -1.0},
	&"star": {"path": "res://audio/sfx/star.wav", "base_hz": 783.99, "db": -2.0},
	&"defeat": {"path": "res://audio/sfx/defeat.wav", "base_hz": 0.0, "db": -2.0},
	&"tap": {"path": "res://audio/sfx/tap.wav", "base_hz": 0.0, "db": -6.0},
	&"locked": {"path": "res://audio/sfx/locked.wav", "base_hz": 0.0, "db": -4.0},
	&"unlock": {"path": "res://audio/sfx/unlock.wav", "base_hz": 0.0, "db": -2.0},
}

## frames: the exact loop length that the bake writes (bars * 4 beats at bpm, 44,100 Hz).
const MUSIC := {
	&"calm": {"path": "res://audio/music/calm.wav", "bpm": AudioTuning.CALM_BPM, "bars": AudioTuning.CALM_BARS, "frames": 2016000},
	&"tense": {"path": "res://audio/music/tense.wav", "bpm": AudioTuning.TENSE_BPM, "bars": AudioTuning.TENSE_BARS, "frames": 814154},
}

static var _streams: Dictionary = {}
static var _missing: PackedStringArray = PackedStringArray()


## Loads each stream of the table (SFX or MUSIC) that exists. Absent streams stay null.
static func load_table(table: Dictionary) -> void:
	for key: StringName in table:
		if _streams.has(key):
			continue
		var path: String = table[key]["path"]
		var stream: AudioStream = null
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
		if stream == null:
			if not _missing.has(path):
				_missing.append(path)
		_streams[key] = stream


static func stream(key: StringName) -> AudioStream:
	return _streams.get(key, null)


static func volume_db(key: StringName) -> float:
	if SFX.has(key):
		return SFX[key]["db"]
	return 0.0


static func missing() -> PackedStringArray:
	return _missing.duplicate()


## The loop length of a music clip in seconds.
static func loop_seconds(clip: StringName) -> float:
	return float(MUSIC[clip]["frames"]) / float(SAMPLE_RATE)


static func is_dummy_driver() -> bool:
	return AudioServer.get_driver_name() == "Dummy"


## Makes the SFX and Music buses with their effects, and the master limiter. Safe to call again.
static func ensure_buses() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(master, AudioTuning.MASTER_DB)
	if _find_effect(master, "AudioEffectHardLimiter") < 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = AudioTuning.LIMITER_CEILING_DB
		AudioServer.add_bus_effect(master, limiter)
	_ensure_bus(SFX_BUS, AudioTuning.SFX_DB)
	var music := _ensure_bus(MUSIC_BUS, AudioTuning.MUSIC_DB)
	if _find_effect(music, "AudioEffectLowPassFilter") < 0:
		var filter := AudioEffectLowPassFilter.new()
		filter.cutoff_hz = AudioTuning.FILTER_MIN_HZ
		AudioServer.add_bus_effect(music, filter)


static func music_filter() -> AudioEffectLowPassFilter:
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	var index := _find_effect(bus, "AudioEffectLowPassFilter")
	if index < 0:
		return null
	return AudioServer.get_bus_effect(bus, index) as AudioEffectLowPassFilter


static func _ensure_bus(bus_name: StringName, db: float) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")
		AudioServer.set_bus_volume_db(index, db)
	return index


static func _find_effect(bus: int, type_name: String) -> int:
	for i: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i).is_class(type_name):
			return i
	return -1
