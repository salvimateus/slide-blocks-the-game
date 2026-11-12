extends SceneTree
## Synthesizes all sound effects and the two music loops into 16-bit WAV files.
##   -- --out=<absolute dir>   root folder (default res://audio): writes sfx/*.wav and music/*.wav
##   -- --check                reads the files in the root folder and verifies them

const Synth := preload("res://tools/audio/synth.gd")
const Score := preload("res://tools/audio/score.gd")

const DEFAULT_OUT := "res://audio"
const EFFECTS: PackedStringArray = [
	"swipe", "paint", "repaint", "squish", "bump", "glide", "thud", "star_lost", "tension",
	"ring", "glitter", "win", "star", "defeat", "tap", "locked", "unlock",
]
const EFFECT_PEAK := {
	"swipe": 0.45, "paint": 0.8, "repaint": 0.4, "squish": 0.85, "bump": 0.6, "glide": 0.55,
	"thud": 0.7, "star_lost": 0.7, "tension": 0.7, "ring": 0.75, "glitter": 0.5, "win": 0.85,
	"star": 0.8, "defeat": 0.8, "tap": 0.5, "locked": 0.6, "unlock": 0.8,
}
const MUSIC_PEAK := 0.9
const TAIL_SECONDS := 4.0
const LOOP_SECONDS := {"calm": 45.714, "tense": 18.462}
const MAX_PEAK := 0.98
const MIN_RMS := 0.01
const MAX_DC := 0.005
const SEAM_WINDOW := 512  # samples on each side of the loop seam

# Base pitches of the samples that the game transposes with pitch_scale.
const PAINT_HZ := 523.25   # C5
const RING_HZ := 523.25    # C5
const STAR_HZ := 783.99    # G5
const GLITTER_HZ := 1318.51  # E6


func _initialize() -> void:
	var out := DEFAULT_OUT
	var check := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6).replace("\\", "/").rstrip("/")
		elif arg == "--check":
			check = true
		else:
			printerr("bake_audio: unknown argument ", arg)
			quit(1)
			return
	quit(_check(out) if check else _bake(out))


# --- Bake ------------------------------------------------------------------

func _bake(out: String) -> int:
	var t0 := Time.get_ticks_msec()
	for sub in ["sfx", "music"]:
		var err := DirAccess.make_dir_recursive_absolute(out + "/" + sub)
		if err != OK:
			printerr("bake_audio: cannot make folder ", out + "/" + sub, " (error ", err, ")")
			return 1
	var fails := 0
	for sound in EFFECTS:
		var t := Time.get_ticks_msec()
		var buf: PackedFloat32Array = call("_sfx_" + sound)
		Synth.highpass(buf, 20.0)
		Synth.fade_out(buf, 0.02)
		Synth.normalize(buf, EFFECT_PEAK[sound])
		fails += _write(out + "/sfx/" + sound + ".wav", buf, PackedFloat32Array(), t)
	for score: Dictionary in [Score.CALM, Score.TENSE]:
		var t := Time.get_ticks_msec()
		var lr := _render_music(score)
		fails += _write(out + "/music/" + str(score["name"]) + ".wav", lr[0], lr[1], t)
	print("BAKE_TIME %.1f s, %d files, %d failed" % [(Time.get_ticks_msec() - t0) / 1000.0, EFFECTS.size() + 2, fails])
	return 0 if fails == 0 else 1


func _write(path: String, left: PackedFloat32Array, right: PackedFloat32Array, t_start: int) -> int:
	if Synth.has_nan(left) or Synth.has_nan(right):
		printerr("bake_audio: NaN or Inf in ", path)
		return 1
	var err := Synth.to_stream(left, right).save_to_wav(path)
	if err != OK:
		printerr("bake_audio: cannot write ", path, " (error ", err, ")")
		return 1
	print("WROTE %-26s %7.3f s  %d ms" % [path.get_file(), float(left.size()) / Synth.SR_F, Time.get_ticks_msec() - t_start])
	return 0


# --- Effect building blocks --------------------------------------------------

func _tone(seconds: float, f_start: float, f_end: float, glide: float, ratios: Array, amps: Array, taus: Array, attack: float, wobble: Vector3 = Vector3.ZERO) -> PackedFloat32Array:
	var freq := Synth.pitch_curve(Synth.count(seconds), f_start, f_end, glide, wobble.x, wobble.y, wobble.z)
	var buf := Synth.partials(freq, PackedFloat32Array(ratios), PackedFloat32Array(amps), PackedFloat32Array(taus))
	Synth.fade_in(buf, attack)
	# The tail of a voice must reach zero, or its end is a click.
	return Synth.fade_out(buf, minf(0.25 * seconds, 0.3))


func _pluck(f: float, seconds: float, ring: float) -> PackedFloat32Array:
	return _tone(seconds, f, f, 0.0, [1.0, 2.0, 3.0, 4.6], [1.0, 0.22, 0.07, 0.04], [0.5 * ring, 0.2 * ring, 0.08 * ring, 0.02], 0.003)


func _bell(f: float, seconds: float, ring: float) -> PackedFloat32Array:
	return _tone(seconds, f, f, 0.0, [1.0, 2.0, 3.0, 4.1, 0.5], [1.0, 0.3, 0.12, 0.05, 0.15], [0.9 * ring, 0.4 * ring, 0.2 * ring, 0.08 * ring, 0.5 * ring], 0.003)


func _ping(f: float) -> PackedFloat32Array:
	return _tone(0.3, f, f, 0.0, [1.0, 2.0], [1.0, 0.06], [0.07, 0.03], 0.002)


func _warm(seconds: float, f: float, attack: float, release: float) -> PackedFloat32Array:
	var buf := Synth.warm_osc(Synth.count(seconds), f, 0.2, 0.05)
	Synth.fade_in(buf, attack)
	return Synth.fade_out(buf, release)


func _noise(seconds: float, noise_seed: int) -> PackedFloat32Array:
	return Synth.noise(Synth.count(seconds), noise_seed)


func _place(dst: PackedFloat32Array, src: PackedFloat32Array, at_seconds: float, g: float) -> void:
	Synth.add(dst, src, Synth.count(at_seconds), g)


## Adds a mono reverb whose RMS is wet_ratio times the RMS of the dry signal.
func _room(buf: PackedFloat32Array, wet_ratio: float, room: float, damp: float) -> PackedFloat32Array:
	var wet := Synth.reverb(buf, room, damp, 0)
	Synth.add(buf, wet, 0, wet_ratio * Synth.rms(buf) / maxf(Synth.rms(wet), 0.000000001))
	return buf


# --- Effects -----------------------------------------------------------------

func _sfx_swipe() -> PackedFloat32Array:
	var buf := _noise(0.34, 3)
	Synth.bandpass_sweep(buf, 350.0, 1500.0, 1.2)
	Synth.fade_in(buf, 0.07)
	Synth.decay(buf, 0.07, 0.07)
	Synth.normalize(buf, 1.0)
	_place(buf, _tone(0.34, 200.0, 420.0, 0.1, [1.0], [1.0], [0.12], 0.04), 0.0, 0.15)
	return Synth.lowpass(buf, 3000.0)


func _sfx_paint() -> PackedFloat32Array:
	# A small upward scoop into the note gives the jelly "bloop".
	var buf := _tone(0.9, PAINT_HZ * 0.9, PAINT_HZ, 0.012, [1.0, 2.0, 3.0, 4.6], [1.0, 0.16, 0.05, 0.1], [0.42, 0.16, 0.07, 0.012], 0.003)
	Synth.lowpass(buf, 6000.0)
	return _room(buf, 0.18, 0.5, 0.6)


func _sfx_repaint() -> PackedFloat32Array:
	var buf := _tone(0.16, 1250.0, 1100.0, 0.006, [1.0, 2.0], [1.0, 0.1], [0.03, 0.015], 0.002)
	var click := _noise(0.16, 5)
	Synth.lowpass(click, 2500.0)
	Synth.decay(click, 0.006)
	Synth.normalize(click, 1.0)
	_place(buf, click, 0.0, 0.25)
	return buf


func _sfx_squish() -> PackedFloat32Array:
	var body := _tone(0.45, 380.0, 150.0, 0.05, [1.0, 2.0, 3.0], [1.0, 0.3, 0.08], [0.16, 0.08, 0.05], 0.004, Vector3(16.0, 0.1, 0.1))
	var squelch := _noise(0.45, 11)
	Synth.bandpass_sweep(squelch, 1400.0, 300.0, 0.8)
	Synth.decay(squelch, 0.05)
	Synth.fade_in(squelch, 0.003)
	Synth.normalize(squelch, 1.0)
	_place(body, squelch, 0.0, 0.28)
	_place(body, _tone(0.45, 120.0, 60.0, 0.03, [1.0], [1.0], [0.09], 0.002), 0.0, 0.5)
	return Synth.lowpass(body, 3500.0)


func _sfx_bump() -> PackedFloat32Array:
	var body := _tone(0.3, 540.0, 310.0, 0.03, [1.0, 2.0], [1.0, 0.25], [0.1, 0.05], 0.003, Vector3(22.0, 0.07, 0.06))
	var squelch := _noise(0.3, 13)
	Synth.bandpass_sweep(squelch, 1800.0, 600.0, 0.9)
	Synth.decay(squelch, 0.03)
	Synth.fade_in(squelch, 0.002)
	Synth.normalize(squelch, 1.0)
	_place(body, squelch, 0.0, 0.15)
	_place(body, _tone(0.3, 170.0, 95.0, 0.02, [1.0], [1.0], [0.06], 0.002), 0.0, 0.4)
	return Synth.lowpass(body, 4000.0)


func _sfx_glide() -> PackedFloat32Array:
	var buf := _tone(0.32, 520.0, 880.0, 0.05, [1.0, 2.0], [1.0, 0.15], [0.14, 0.07], 0.01)
	var rub := _noise(0.32, 17)
	Synth.bandpass_sweep(rub, 900.0, 2600.0, 0.5)
	Synth.decay(rub, 0.09)
	Synth.fade_in(rub, 0.01)
	Synth.normalize(rub, 1.0)
	_place(buf, rub, 0.0, 0.15)
	Synth.lowpass(buf, 5000.0)
	return _room(buf, 0.15, 0.4, 0.6)


func _sfx_thud() -> PackedFloat32Array:
	var buf := _tone(0.3, 140.0, 70.0, 0.04, [1.0, 2.0], [1.0, 0.2], [0.12, 0.05], 0.003)
	var dust := _noise(0.3, 19)
	Synth.lowpass(dust, 400.0)
	Synth.decay(dust, 0.03)
	Synth.fade_in(dust, 0.002)
	Synth.normalize(dust, 1.0)
	_place(buf, dust, 0.0, 0.35)
	return Synth.lowpass(buf, 1200.0)


func _sfx_star_lost() -> PackedFloat32Array:
	var buf := Synth.silence(Synth.count(0.85))
	_place(buf, _tone(0.7, 587.33, 572.0, 0.08, [1.0, 2.0], [1.0, 0.12], [0.22, 0.1], 0.006), 0.0, 0.8)
	_place(buf, _tone(0.7, 440.0, 425.0, 0.12, [1.0, 2.0], [1.0, 0.12], [0.3, 0.12], 0.006), 0.15, 1.0)
	return _room(buf, 0.2, 0.5, 0.6)


func _sfx_tension() -> PackedFloat32Array:
	var dur := 1.3
	var buf := Synth.silence(Synth.count(dur))
	for f: float in [110.0, 220.0, 261.63]:
		var voice := _tone(dur, f * 0.97, f, 0.4, [1.0, 2.0, 3.0], [1.0, 0.25, 0.06], [0.0, 0.0, 0.0], 0.0)
		Synth.fade_in(voice, 0.45)
		Synth.fade_out(voice, 0.6)
		_place(buf, voice, 0.0, 0.4)
	Synth.tremolo(buf, 6.5, 0.4)
	_place(buf, _tone(dur, 95.0, 50.0, 0.04, [1.0], [1.0], [0.15], 0.003), 0.0, 0.6)
	Synth.lowpass(buf, 2000.0)
	return _room(buf, 0.15, 0.6, 0.6)


func _sfx_ring() -> PackedFloat32Array:
	var buf := _tone(1.4, RING_HZ, RING_HZ, 0.0, [1.0, 2.0, 3.0, 4.2], [1.0, 0.35, 0.1, 0.05], [0.7, 0.35, 0.15, 0.08], 0.004)
	Synth.lowpass(buf, 7000.0)
	return _room(buf, 0.25, 0.6, 0.5)


func _sfx_glitter() -> PackedFloat32Array:
	var buf := _ping(GLITTER_HZ)
	return _room(buf, 0.2, 0.4, 0.5)


func _sfx_win() -> PackedFloat32Array:
	var buf := Synth.silence(Synth.count(2.6))
	var arp := [72, 76, 79, 84]
	for i: int in arp.size():
		_place(buf, _pluck(Synth.hz(arp[i]), 1.0, 1.0), 0.09 * i, 0.55)
	var chord := [72, 76, 79, 84, 88]
	for i: int in chord.size():
		_place(buf, _pluck(Synth.hz(chord[i]), 2.1, 2.2), 0.42 + 0.018 * i, 0.32)
	for note: int in [60, 64, 67]:
		_place(buf, _warm(2.0, Synth.hz(note), 0.3, 1.2), 0.38, 0.12)
	var sparkles := [[0.5, 88], [0.58, 91], [0.66, 93], [0.8, 96]]
	for s: Array in sparkles:
		_place(buf, _ping(Synth.hz(s[1])), s[0], 0.12)
	Synth.lowpass(buf, 7000.0)
	return _room(buf, 0.3, 0.7, 0.5)


func _sfx_star() -> PackedFloat32Array:
	var buf := _bell(STAR_HZ, 1.8, 1.0)
	Synth.lowpass(buf, 7500.0)
	return _room(buf, 0.25, 0.6, 0.5)


func _sfx_defeat() -> PackedFloat32Array:
	var buf := Synth.silence(Synth.count(2.8))
	var phrase := [[0.0, 659.26, 0.6], [0.28, 587.33, 0.6], [0.56, 523.25, 0.6]]
	for p: Array in phrase:
		var f: float = p[1]
		_place(buf, _tone(p[2], f, f * 0.985, 0.2, [1.0, 2.0], [1.0, 0.14], [0.35, 0.12], 0.01), p[0], 0.5)
	_place(buf, _tone(1.9, 440.0, 430.0, 0.4, [1.0, 2.0], [1.0, 0.14], [0.8, 0.25], 0.01, Vector3(5.0, 0.006, 0.0)), 0.84, 0.6)
	for f: float in [220.0, 261.63, 329.63]:
		_place(buf, _warm(2.6, f, 0.6, 1.2), 0.0, 0.08)
	Synth.lowpass(buf, 4000.0)
	return _room(buf, 0.25, 0.6, 0.5)


func _sfx_tap() -> PackedFloat32Array:
	return _tone(0.12, 760.0, 520.0, 0.01, [1.0, 2.0], [1.0, 0.1], [0.035, 0.02], 0.001)


func _sfx_locked() -> PackedFloat32Array:
	var buf := Synth.silence(Synth.count(0.38))
	_place(buf, _tone(0.2, 330.0, 300.0, 0.02, [1.0, 2.0, 3.0], [1.0, 0.25, 0.12], [0.07, 0.05, 0.03], 0.003), 0.0, 1.0)
	_place(buf, _tone(0.25, 262.0, 240.0, 0.02, [1.0, 2.0, 3.0], [1.0, 0.25, 0.12], [0.08, 0.05, 0.03], 0.003), 0.11, 1.0)
	return Synth.lowpass(buf, 1500.0)


func _sfx_unlock() -> PackedFloat32Array:
	var buf := Synth.silence(Synth.count(1.6))
	var notes := [79, 84, 88, 91]
	for i: int in notes.size():
		_place(buf, _bell(Synth.hz(notes[i]), 1.3, 0.6), 0.07 * i, 0.4)
	_place(buf, _ping(Synth.hz(96)), 0.3, 0.12)
	_place(buf, _ping(Synth.hz(100)), 0.38, 0.1)
	Synth.lowpass(buf, 7000.0)
	return _room(buf, 0.3, 0.7, 0.5)


# --- Music -------------------------------------------------------------------

func _render_music(score: Dictionary) -> Array[PackedFloat32Array]:
	var bpm: float = score["bpm"]
	var bars: int = score["bars"]
	var bright: bool = score["pad_tone"] == "bright"
	var step := Synth.SR_F * 60.0 / bpm / 4.0
	var loop_len := _loop_samples(score)
	var n := loop_len + Synth.count(TAIL_SECONDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = score["seed"]
	var cache := {}
	var l := Synth.silence(n)
	var r := Synth.silence(n)
	var pad_l := Synth.silence(n)
	var pad_r := Synth.silence(n)
	var verb := Synth.silence(n)
	var echo := Synth.silence(n)
	var chords: Array = score["chords"]

	var pad_gain := 0.055 if bright else 0.06
	for chord: Dictionary in chords:
		var start := int(round(float(chord["bar"]) * 16.0 * step))
		var length := int(round(float(chord["bars"]) * 16.0 * step))
		for note: int in chord["pad"]:
			var pair := _pad_note(cache, note, length, bright)
			Synth.add_pan(pad_l, pad_r, verb, pair[0], start, pad_gain, -0.55, 0.5)
			Synth.add_pan(pad_l, pad_r, verb, pair[1], start, pad_gain, 0.55, 0.5)
	if bright:
		Synth.pump(pad_l, 4.0 * step, 0.3, 0.14)
		Synth.pump(pad_r, 4.0 * step, 0.3, 0.14)
	Synth.add(l, pad_l, 0, 1.0)
	Synth.add(r, pad_r, 0, 1.0)

	var motifs: Dictionary = score["motifs"]
	for place: Array in score["melody"]:
		var bar0: int = place[0]
		var motif: Array = motifs[place[1]]
		for ev: Array in motif:
			var at := _at(bar0 * 16 + int(ev[0]), step, rng, 90)
			var src := _keys(cache, ev[1], false)
			var vel: float = float(ev[3]) * rng.randf_range(0.92, 1.0)
			var damp := int(float(ev[2]) * step) + Synth.count(0.25)
			Synth.add_pan(l, r, verb, src, at, 0.34 * vel, 0.15, 0.45, damp, Synth.count(0.25))
			Synth.add(echo, src, at, 0.1 * vel, damp, Synth.count(0.25))

	var comp: Array = score["comp"]
	var ostinato: Array = score["ostinato"]
	var bass: Array = score["bass"]
	for bar: int in bars:
		var chord := _chord_at(chords, bar)
		if comp.size() > 0:
			for ev: Array in comp[bar % comp.size()]:
				var note: int = chord["pad"][ev[1]]
				var at := _at(bar * 16 + int(ev[0]), step, rng, 120)
				var vel: float = float(ev[2]) * rng.randf_range(0.9, 1.0)
				Synth.add_pan(l, r, verb, _keys(cache, note, false), at, 0.15 * vel, -0.35, 0.5, int(4.0 * step), Synth.count(0.3))
		if ostinato.size() > 0:
			var k := 0
			for ev: Array in ostinato[bar % ostinato.size()]:
				var note: int = chord["arp"][ev[1]]
				var at := _at(bar * 16 + int(ev[0]), step, rng, 60)
				var vel: float = float(ev[2]) * rng.randf_range(0.92, 1.0)
				var src := _keys(cache, note, true)
				var pan := -0.3 if k % 2 == 0 else 0.3
				Synth.add_pan(l, r, verb, src, at, 0.24 * vel, pan, 0.3, int(2.0 * step), Synth.count(0.08))
				Synth.add(echo, src, at, 0.03 * vel, int(2.0 * step), Synth.count(0.08))
				k += 1
		for ev: Array in bass[bar % bass.size()]:
			var note: int = int(chord["root"]) + int(ev[1])
			var at := _at(bar * 16 + int(ev[0]), step, rng, 0)
			var src := _bass(cache, note, int(float(ev[2]) * step), bright)
			Synth.add_pan(l, r, verb, src, at, 0.3 * float(ev[3]), 0.0, 0.05)

	var perc: Dictionary = score["perc"]
	var kicks: Array = perc["kick"]
	var shakers: Array = perc["shaker"]
	var kick := _kick(cache)
	var stock := _shaker_stock(int(score["seed"]))
	for bar: int in bars:
		if kicks.size() > 0:
			var pattern: String = kicks[bar % kicks.size()]
			for s: int in 16:
				if pattern[s] != ".":
					Synth.add_pan(l, r, verb, kick, _at(bar * 16 + s, step, rng, 0), 0.55 * int(pattern[s]) / 9.0, 0.0, 0.0)
		if shakers.size() > 0:
			var pattern: String = shakers[bar % shakers.size()]
			for s: int in 16:
				if pattern[s] != ".":
					var hit := _shaker_hit(stock, rng, 0.028 if bright else 0.035)
					Synth.add_pan(l, r, verb, hit, _at(bar * 16 + s, step, rng, 40), 0.2 * int(pattern[s]) / 9.0, 0.3, 0.15)

	var echoes := Synth.ping_pong(echo, int(3.0 * step), 0.35, 2600.0)
	Synth.add(l, echoes[0], 0, 1.0)
	Synth.add(r, echoes[1], 0, 1.0)

	var wet_l := Synth.reverb(verb, 0.82, 0.5, 0)
	var wet_r := Synth.reverb(verb, 0.82, 0.5, 1)
	var wet_ratio := 0.35 if bright else 0.5
	var k_wet := wet_ratio * Synth.rms(l) / maxf(Synth.rms(wet_l), 0.000000001)
	var predelay := Synth.count(0.018)
	Synth.add(l, wet_l, predelay, k_wet)
	Synth.add(r, wet_r, predelay, k_wet)

	Synth.lowpass(l, 11000.0)
	Synth.lowpass(r, 11000.0)
	Synth.fold_loop(l, loop_len)
	Synth.fold_loop(r, loop_len)
	Synth.remove_mean(l)
	Synth.remove_mean(r)
	var g := MUSIC_PEAK / maxf(maxf(Synth.peak(l), Synth.peak(r)), 0.000000001)
	Synth.gain(l, g)
	Synth.gain(r, g)
	return [l, r]


func _loop_samples(score: Dictionary) -> int:
	var bpm: float = score["bpm"]
	var bars: int = score["bars"]
	return int(round(float(bars) * 4.0 * 60.0 / bpm * Synth.SR_F))


func _at(step_index: int, step: float, rng: RandomNumberGenerator, jitter: int) -> int:
	return int(round(float(step_index) * step)) + (rng.randi_range(0, jitter) if jitter > 0 else 0)


func _chord_at(chords: Array, bar: int) -> Dictionary:
	for chord: Dictionary in chords:
		var first: int = chord["bar"]
		if bar >= first and bar < first + int(chord["bars"]):
			return chord
	return chords[0]


func _pad_note(cache: Dictionary, note: int, length: int, bright: bool) -> Array[PackedFloat32Array]:
	var key := "pad:%d:%d:%d" % [note, length, int(bright)]
	if cache.has(key):
		return cache[key]
	var f := Synth.hz(note)
	var attack := 0.35 if bright else 0.9
	var release := 0.6 if bright else 1.3
	var h2 := 0.4 if bright else 0.18
	var h3 := 0.18 if bright else 0.04
	var total := length + Synth.count(release)
	var pair: Array[PackedFloat32Array] = []
	for side: int in 2:
		var detune := 1.0023 if side == 0 else 0.9977
		var osc := Synth.warm_osc(total, f * detune, h2, h3, 1.3 * side)
		Synth.tremolo(osc, 0.17 + 0.06 * side, 0.12)
		Synth.fade_in(osc, attack)
		Synth.fade_out(osc, release)
		pair.append(osc)
	cache[key] = pair
	return pair


func _keys(cache: Dictionary, note: int, bright: bool) -> PackedFloat32Array:
	var key := "keys:%d:%d" % [note, int(bright)]
	if cache.has(key):
		return cache[key]
	var f := Synth.hz(note)
	var buf: PackedFloat32Array
	if bright:
		buf = _tone(1.0, f, f, 0.0, [1.0, 2.0, 3.0, 5.4], [1.0, 0.3, 0.1, 0.04], [0.4, 0.15, 0.06, 0.02], 0.002)
	else:
		buf = _tone(2.0, f, f, 0.0, [1.0, 2.0, 3.0, 5.4], [1.0, 0.2, 0.05, 0.05], [0.85, 0.3, 0.12, 0.025], 0.003)
	cache[key] = buf
	return buf


func _bass(cache: Dictionary, note: int, length: int, short: bool) -> PackedFloat32Array:
	var key := "bass:%d:%d:%d" % [note, length, int(short)]
	if cache.has(key):
		return cache[key]
	var release := 0.08
	var buf := Synth.warm_osc(length + Synth.count(release), Synth.hz(note), 0.22, 0.06)
	Synth.fade_in(buf, 0.012 if short else 0.02)
	Synth.decay(buf, 0.35 if short else 1.1)
	Synth.fade_out(buf, release)
	cache[key] = buf
	return buf


func _kick(cache: Dictionary) -> PackedFloat32Array:
	if cache.has("kick"):
		return cache["kick"]
	var buf := _tone(0.45, 125.0, 46.0, 0.035, [1.0, 2.0], [1.0, 0.08], [0.2, 0.05], 0.0015)
	Synth.lowpass(buf, 900.0)
	cache["kick"] = buf
	return buf


func _shaker_stock(noise_seed: int) -> PackedFloat32Array:
	var buf := _noise(2.0, noise_seed)
	Synth.highpass(buf, 3800.0)
	Synth.lowpass(buf, 8000.0)
	Synth.lowpass(buf, 8000.0)
	return Synth.normalize(buf, 1.0)


func _shaker_hit(stock: PackedFloat32Array, rng: RandomNumberGenerator, tau: float) -> PackedFloat32Array:
	var length := Synth.count(0.12)
	var start := rng.randi_range(0, stock.size() - length - 1)
	var hit := stock.slice(start, start + length)
	Synth.fade_in(hit, 0.004)
	Synth.decay(hit, tau)
	return Synth.fade_out(hit, 0.01)


# --- Check -------------------------------------------------------------------

func _check(out: String) -> int:
	var fails := 0
	for sound in EFFECTS:
		var info := _read_wav(out + "/sfx/" + sound + ".wav")
		fails += _report(sound, info, 1, -1.0)
	for score: Dictionary in [Score.CALM, Score.TENSE]:
		var clip: String = score["name"]
		var info := _read_wav(out + "/music/" + clip + ".wav")
		fails += _report(clip, info, 2, LOOP_SECONDS[clip])
		if not info.is_empty():
			var frames: int = info["frames"]
			if frames != _loop_samples(score):
				print("  FAIL %s: %d frames, the score needs %d" % [clip, frames, _loop_samples(score)])
				fails += 1
	var calm_rate := _events_per_bar(Score.CALM)
	var tense_rate := _events_per_bar(Score.TENSE)
	var kick_ok := _kick_on_each_beat(Score.TENSE)
	print("SCORE calm %.2f events/bar, tense %.2f events/bar, tense kick on each beat: %s" % [calm_rate, tense_rate, kick_ok])
	if tense_rate <= calm_rate or not kick_ok:
		print("  FAIL score: the tense loop must be denser and have a kick on each beat")
		fails += 1
	print("CHECK %s, %d failed" % ["OK" if fails == 0 else "FAILED", fails])
	return 0 if fails == 0 else 1


## Prints one line for a file and returns the number of failed checks.
func _report(label: String, info: Dictionary, channels: int, loop_seconds: float) -> int:
	if info.is_empty():
		print("  FAIL %s: missing or not a 16-bit 44100 Hz PCM WAV" % label)
		return 1
	var fails := 0
	var notes := PackedStringArray()
	var seconds: float = info["seconds"]
	var pk: float = info["peak"]
	var level: float = info["rms"]
	var dc: float = info["dc"]
	if int(info["channels"]) != channels:
		notes.append("channels %d" % int(info["channels"]))
	if pk > MAX_PEAK:
		notes.append("peak above %.2f" % MAX_PEAK)
	if level < MIN_RMS:
		notes.append("rms below %.2f" % MIN_RMS)
	if absf(dc) > MAX_DC:
		notes.append("dc offset")
	var seam := ""
	if loop_seconds > 0.0:
		if absf(seconds - loop_seconds) >= 0.0005:
			notes.append("loop length, expected %.3f s" % loop_seconds)
		var jump: float = info["seam_jump"]
		var edge_step: float = info["edge_step"]
		seam = "  seam %.4f (mean step %.4f, max step near seam %.4f)" % [jump, info["mean_step"], edge_step]
		if jump > edge_step:
			notes.append("loop seam click")
	fails = notes.size()
	print("%s %-10s %7.3f s  ch %d  peak %.3f  rms %.3f  dc %+.5f%s%s" % [
		"  OK  " if fails == 0 else "  FAIL", label, seconds, int(info["channels"]), pk, level, dc, seam,
		"" if fails == 0 else "  <- " + ", ".join(notes)])
	return fails


## Parses a PCM WAV and returns its stats, or {} when it is not 16-bit 44100 Hz.
func _read_wav(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return {}
	var channels := 0
	var rate := 0
	var bits := 0
	var data_at := -1
	var data_size := 0
	var pos := 12
	while pos + 8 <= bytes.size():
		var id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		if id == "fmt ":
			channels = bytes.decode_u16(pos + 10)
			rate = bytes.decode_u32(pos + 12)
			bits = bytes.decode_u16(pos + 22)
		elif id == "data":
			data_at = pos + 8
			data_size = mini(size, bytes.size() - data_at)
		pos += 8 + size + (size & 1)
	if data_at < 0 or bits != 16 or rate != Synth.SR or channels < 1 or channels > 2:
		return {}
	var frames := floori(float(data_size) / float(2 * channels))
	var pk := 0.0
	var sum := 0.0
	var sq := 0.0
	var step_sum := 0.0
	var edge_step := 0.0
	var seam := 0.0
	for c: int in channels:
		var prev := 0.0
		var first := 0.0
		var o := data_at + 2 * c
		for i: int in frames:
			var x := bytes.decode_s16(o) / 32768.0
			o += 2 * channels
			pk = maxf(pk, absf(x))
			sum += x
			sq += x * x
			if i == 0:
				first = x
			else:
				var d := absf(x - prev)
				step_sum += d
				if i < SEAM_WINDOW or i >= frames - SEAM_WINDOW:
					edge_step = maxf(edge_step, d)
			prev = x
		seam = maxf(seam, absf(prev - first))
	var total := float(maxi(frames * channels, 1))
	return {
		"channels": channels, "frames": frames, "seconds": float(frames) / Synth.SR_F,
		"peak": pk, "rms": sqrt(sq / total), "dc": sum / total,
		"seam_jump": seam, "mean_step": step_sum / total, "edge_step": edge_step,
	}


func _events_per_bar(score: Dictionary) -> float:
	var bars: int = score["bars"]
	var total: int = (score["chords"] as Array).size()
	var motifs: Dictionary = score["motifs"]
	for place: Array in score["melody"]:
		total += (motifs[place[1]] as Array).size()
	for key in ["comp", "ostinato", "bass"]:
		var patterns: Array = score[key]
		if patterns.size() > 0:
			for bar: int in bars:
				total += (patterns[bar % patterns.size()] as Array).size()
	var perc: Dictionary = score["perc"]
	for key: String in perc:
		var patterns: Array = perc[key]
		if patterns.size() > 0:
			for bar: int in bars:
				var pattern: String = patterns[bar % patterns.size()]
				total += pattern.length() - pattern.count(".")
	return float(total) / float(bars)


func _kick_on_each_beat(score: Dictionary) -> bool:
	var kicks: Array = score["perc"]["kick"]
	if kicks.is_empty():
		return false
	for bar: int in int(score["bars"]):
		var pattern: String = kicks[bar % kicks.size()]
		for beat: int in 4:
			if pattern[beat * 4] == ".":
				return false
	return true
