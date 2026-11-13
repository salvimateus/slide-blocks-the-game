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
	"swipe": 0.45, "paint": 0.70, "repaint": 0.50, "squish": 0.70, "bump": 0.60, "glide": 0.55,
	"thud": 0.60, "star_lost": 0.65, "tension": 0.65, "ring": 0.60, "glitter": 0.45, "win": 0.80,
	"star": 0.75, "defeat": 0.75, "tap": 0.50, "locked": 0.60, "unlock": 0.75,
}
const EFFECT_PEAK_TOLERANCE := 0.01
const MUSIC_LEVEL_TOLERANCE_DB := 1.0
const WEIGHT_HIGHPASS_HZ := 200.0
const TAIL_SECONDS := 4.0
const LOOP_SECONDS := {"calm": 96.0, "tense": 34.286}
const MAX_PEAK := 0.98
const MIN_RMS := 0.01
const MAX_DC := 0.005
const SEAM_WINDOW := 512  # samples on each side of the loop seam

# Base pitches of the samples that the game transposes with pitch_scale.
const PAINT_HZ := 523.25   # C5
const RING_HZ := 523.25    # C5
const STAR_HZ := 698.46    # F5
const GLITTER_HZ := 1174.66  # D6

# Gain of one event = part gain x velocity. 0.0: the tone does not use the part.
const MIX := {
	"soft": {"pad": 0.030, "comp": 0.135, "ostinato": 0.0, "bass": 0.146, "kick": 0.188, "rim": 1.13, "shaker": 1.20, "tick": 0.0, "tock": 0.0},
	"bright": {"pad": 0.022, "comp": 0.0, "ostinato": 0.22, "bass": 0.111, "kick": 0.151, "rim": 0.0, "shaker": 1.0, "tick": 0.20, "tock": 0.20},
}
# The bright shaker is darker on top and fuller from 2 to 5 kHz, where the tense clip has no rim.
const SHAKER_BAND := {
	"soft": Vector2(3800.0, 8000.0),
	"bright": Vector2(2600.0, 5000.0),
}
const PERC := {
	"kick": {"pan": 0.0, "verb": 0.0, "jitter": 0},
	"rim": {"pan": -0.2, "verb": 0.25, "jitter": 30},
	"shaker": {"pan": 0.3, "verb": 0.15, "jitter": 40},
	"tick": {"pan": 0.4, "verb": 0.3, "jitter": 20},
	"tock": {"pan": -0.4, "verb": 0.3, "jitter": 20},
}
const TICK_HZ := 1174.66  # D6
const TOCK_HZ := 880.0    # A5


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
	return _tone(0.25, f, f, 0.0, [1.0, 2.0], [1.0, 0.05], [0.05, 0.02], 0.003)


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
	Synth.bandpass_sweep(buf, 300.0, 1100.0, 1.2)
	Synth.fade_in(buf, 0.08)
	Synth.decay(buf, 0.07, 0.07)
	Synth.normalize(buf, 1.0)
	_place(buf, _tone(0.34, 200.0, 420.0, 0.1, [1.0], [1.0], [0.12], 0.04), 0.0, 0.15)
	return Synth.lowpass(buf, 2200.0)


func _sfx_paint() -> PackedFloat32Array:
	# A fast scoop up into the note and a breath of noise give the bubble pop.
	var buf := _tone(0.26, PAINT_HZ * 0.62, PAINT_HZ, 0.014, [1.0, 2.0, 3.0], [1.0, 0.16, 0.04], [0.055, 0.03, 0.018], 0.005)
	var puff := _noise(0.26, 23)
	Synth.lowpass(puff, 1400.0)
	Synth.highpass(puff, 300.0)
	Synth.fade_in(puff, 0.002)
	Synth.decay(puff, 0.009)
	Synth.normalize(puff, 1.0)
	_place(buf, puff, 0.0, 0.10)
	Synth.lowpass(buf, 4500.0)
	return _room(buf, 0.10, 0.3, 0.7)


func _sfx_repaint() -> PackedFloat32Array:
	var buf := _tone(0.09, 392.0, 349.23, 0.01, [1.0, 2.0], [1.0, 0.08], [0.02, 0.01], 0.004)
	var tick := _noise(0.09, 5)
	Synth.lowpass(tick, 1800.0)
	Synth.fade_in(tick, 0.002)
	Synth.decay(tick, 0.006)
	Synth.normalize(tick, 1.0)
	_place(buf, tick, 0.0, 0.12)
	return Synth.lowpass(buf, 2500.0)


func _sfx_squish() -> PackedFloat32Array:
	var body := _tone(0.30, 330.0, 174.61, 0.035, [1.0, 2.0, 3.0], [1.0, 0.25, 0.06], [0.085, 0.05, 0.03], 0.006, Vector3(14.0, 0.06, 0.08))
	var squelch := _noise(0.30, 11)
	Synth.bandpass_sweep(squelch, 900.0, 320.0, 0.9)
	Synth.decay(squelch, 0.035)
	Synth.fade_in(squelch, 0.004)
	Synth.normalize(squelch, 1.0)
	_place(body, squelch, 0.0, 0.16)
	_place(body, _tone(0.30, 110.0, 70.0, 0.03, [1.0], [1.0], [0.06], 0.004), 0.0, 0.25)
	return Synth.lowpass(body, 2200.0)


func _sfx_bump() -> PackedFloat32Array:
	var body := _tone(0.2, 466.16, 349.23, 0.025, [1.0, 2.0], [1.0, 0.2], [0.06, 0.03], 0.005, Vector3(20.0, 0.05, 0.05))
	var squelch := _noise(0.2, 13)
	Synth.bandpass_sweep(squelch, 1200.0, 500.0, 1.0)
	Synth.decay(squelch, 0.02)
	Synth.fade_in(squelch, 0.003)
	Synth.normalize(squelch, 1.0)
	_place(body, squelch, 0.0, 0.10)
	_place(body, _tone(0.2, 150.0, 98.0, 0.02, [1.0], [1.0], [0.045], 0.004), 0.0, 0.3)
	return Synth.lowpass(body, 2800.0)


func _sfx_glide() -> PackedFloat32Array:
	var buf := _tone(0.28, 523.25, 783.99, 0.05, [1.0, 2.0], [1.0, 0.12], [0.11, 0.05], 0.012)
	var rub := _noise(0.28, 17)
	Synth.bandpass_sweep(rub, 800.0, 1800.0, 0.5)
	Synth.decay(rub, 0.09)
	Synth.fade_in(rub, 0.01)
	Synth.normalize(rub, 1.0)
	_place(buf, rub, 0.0, 0.10)
	Synth.lowpass(buf, 3500.0)
	return _room(buf, 0.12, 0.4, 0.6)


func _sfx_thud() -> PackedFloat32Array:
	var buf := _tone(0.3, 140.0, 70.0, 0.04, [1.0, 2.0], [1.0, 0.2], [0.12, 0.05], 0.003)
	var dust := _noise(0.3, 19)
	Synth.lowpass(dust, 400.0)
	Synth.decay(dust, 0.03)
	Synth.fade_in(dust, 0.002)
	Synth.normalize(dust, 1.0)
	_place(buf, dust, 0.0, 0.35)
	# A phone speaker cannot play the body, so a short knock above it carries the hit.
	_place(buf, _tone(0.12, 220.0, 165.0, 0.02, [1.0], [1.0], [0.035], 0.004), 0.0, 0.35)
	return Synth.lowpass(buf, 1200.0)


func _sfx_star_lost() -> PackedFloat32Array:
	var buf := Synth.silence(Synth.count(0.85))
	_place(buf, _tone(0.7, 587.33, 572.0, 0.08, [1.0, 2.0], [1.0, 0.12], [0.22, 0.1], 0.01), 0.0, 0.8)
	_place(buf, _tone(0.7, 440.0, 425.0, 0.12, [1.0, 2.0], [1.0, 0.12], [0.3, 0.12], 0.01), 0.15, 1.0)
	return _room(buf, 0.2, 0.5, 0.6)


func _sfx_tension() -> PackedFloat32Array:
	var dur := 1.3
	var buf := Synth.silence(Synth.count(dur))
	for f: float in [146.83, 220.0, 293.66]:
		var voice := _tone(dur, f * 0.97, f, 0.4, [1.0, 2.0, 3.0], [1.0, 0.25, 0.06], [0.0, 0.0, 0.0], 0.0)
		Synth.fade_in(voice, 0.45)
		Synth.fade_out(voice, 0.6)
		_place(buf, voice, 0.0, 0.4)
	Synth.tremolo(buf, 6.5, 0.4)
	_place(buf, _tone(dur, 95.0, 50.0, 0.04, [1.0], [1.0], [0.15], 0.003), 0.0, 0.6)
	Synth.lowpass(buf, 1800.0)
	return _room(buf, 0.15, 0.6, 0.6)


func _sfx_ring() -> PackedFloat32Array:
	var buf := _tone(0.7, RING_HZ, RING_HZ, 0.0, [1.0, 2.0, 3.0], [1.0, 0.22, 0.06], [0.22, 0.11, 0.06], 0.006)
	Synth.lowpass(buf, 5000.0)
	return _room(buf, 0.2, 0.6, 0.5)


func _sfx_glitter() -> PackedFloat32Array:
	var buf := _ping(GLITTER_HZ)
	return _room(buf, 0.2, 0.4, 0.5)


func _sfx_win() -> PackedFloat32Array:
	var buf := Synth.silence(Synth.count(2.6))
	var arp := [72, 77, 81, 84]
	for i: int in arp.size():
		_place(buf, _pluck(Synth.hz(arp[i]), 1.0, 1.0), 0.09 * i, 0.5)
	var chord := [65, 72, 77, 81, 84]
	for i: int in chord.size():
		_place(buf, _pluck(Synth.hz(chord[i]), 2.1, 2.2), 0.42 + 0.018 * i, 0.3)
	for note: int in [53, 57, 60]:
		_place(buf, _warm(2.0, Synth.hz(note), 0.3, 1.2), 0.38, 0.12)
	var sparkles := [[0.5, 81], [0.58, 84], [0.66, 86], [0.8, 89]]
	for s: Array in sparkles:
		_place(buf, _ping(Synth.hz(s[1])), s[0], 0.10)
	Synth.lowpass(buf, 6000.0)
	return _room(buf, 0.3, 0.7, 0.5)


func _sfx_star() -> PackedFloat32Array:
	var buf := _bell(STAR_HZ, 1.2, 0.6)
	Synth.lowpass(buf, 6000.0)
	return _room(buf, 0.22, 0.6, 0.5)


func _sfx_defeat() -> PackedFloat32Array:
	var buf := Synth.silence(Synth.count(2.8))
	var phrase := [[0.0, 698.46, 0.6], [0.28, 659.26, 0.6], [0.56, 587.33, 0.6]]
	for p: Array in phrase:
		var f: float = p[1]
		_place(buf, _tone(p[2], f, f * 0.985, 0.2, [1.0, 2.0], [1.0, 0.14], [0.35, 0.12], 0.01), p[0], 0.5)
	_place(buf, _tone(1.9, 440.0, 430.0, 0.4, [1.0, 2.0], [1.0, 0.14], [0.8, 0.25], 0.01, Vector3(5.0, 0.006, 0.0)), 0.84, 0.6)
	for f: float in [146.83, 174.61, 220.0]:
		_place(buf, _warm(2.6, f, 0.6, 1.2), 0.0, 0.08)
	Synth.lowpass(buf, 3500.0)
	return _room(buf, 0.25, 0.6, 0.5)


func _sfx_tap() -> PackedFloat32Array:
	return Synth.lowpass(_tone(0.10, 587.33, 440.0, 0.012, [1.0, 2.0], [1.0, 0.08], [0.028, 0.014], 0.003), 3000.0)


func _sfx_locked() -> PackedFloat32Array:
	var buf := Synth.silence(Synth.count(0.38))
	_place(buf, _tone(0.2, 293.66, 277.18, 0.02, [1.0, 2.0, 3.0], [1.0, 0.25, 0.12], [0.07, 0.05, 0.03], 0.005), 0.0, 1.0)
	_place(buf, _tone(0.25, 220.0, 207.65, 0.02, [1.0, 2.0, 3.0], [1.0, 0.25, 0.12], [0.08, 0.05, 0.03], 0.005), 0.11, 1.0)
	return Synth.lowpass(buf, 1500.0)


func _sfx_unlock() -> PackedFloat32Array:
	var buf := Synth.silence(Synth.count(1.6))
	var notes := [77, 81, 84, 89]
	for i: int in notes.size():
		_place(buf, _bell(Synth.hz(notes[i]), 1.3, 0.6), 0.07 * i, 0.4)
	_place(buf, _ping(Synth.hz(93)), 0.3, 0.10)
	_place(buf, _ping(Synth.hz(96)), 0.38, 0.08)
	Synth.lowpass(buf, 6000.0)
	return _room(buf, 0.3, 0.7, 0.5)


# --- Music -------------------------------------------------------------------

func _render_music(score: Dictionary) -> Array[PackedFloat32Array]:
	var bpm: float = score["bpm"]
	var bars: int = score["bars"]
	var swing: float = score["swing"]
	var tone: String = score["tone"]
	var bright := tone == "bright"
	var mix: Dictionary = MIX[tone]
	var seed: int = score["seed"]
	var step := Synth.SR_F * 60.0 / bpm / 4.0
	var loop_len := _loop_samples(score)
	var n := loop_len + Synth.count(TAIL_SECONDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cache := {}
	var l := Synth.silence(n)
	var r := Synth.silence(n)
	var pad_l := Synth.silence(n)
	var pad_r := Synth.silence(n)
	var ep := Synth.silence(n)
	var verb := Synth.silence(n)
	var echo := Synth.silence(n)
	var table: Dictionary = score["chord_table"]
	var chords: Array = score["chords"]

	# One pad span for each run of bars with the same chord name.
	var pad_gain: float = mix["pad"]
	var bar := 0
	while bar < bars:
		var chord_name: String = chords[bar]
		var run := 1
		while bar + run < bars and chords[bar + run] == chord_name:
			run += 1
		var start := int(round(float(bar) * 16.0 * step))
		var length := int(round(float(bar + run) * 16.0 * step)) - start
		for note: int in table[chord_name]["pad"]:
			var pair := _pad_note(cache, note, length, bright)
			Synth.add_pan(pad_l, pad_r, verb, pair[0], start, pad_gain, -0.55, 0.5)
			Synth.add_pan(pad_l, pad_r, verb, pair[1], start, pad_gain, 0.55, 0.5)
		bar += run
	if bright:
		Synth.pump(pad_l, 4.0 * step, 0.3, 0.14)
		Synth.pump(pad_r, 4.0 * step, 0.3, 0.14)
	Synth.add(l, pad_l, 0, 1.0)
	Synth.add(r, pad_r, 0, 1.0)

	var motifs: Dictionary = score["motifs"]
	var ring_tail := Synth.count(0.25)
	for line: Dictionary in score["lines"]:
		var voice: String = line["voice"]
		var line_gain: float = line["gain"]
		var pan: float = line["pan"]
		var verb_send: float = line["verb"]
		var echo_send: float = line["echo"]
		for place: Array in line["places"]:
			var bar0: int = place[0]
			for ev: Array in motifs[place[1]]:
				var at := _at(bar0 * 16 + int(ev[0]), step, swing, rng, 90)
				var length := int(float(ev[2]) * step)
				var g: float = line_gain * float(ev[3])
				if voice == "ocarina":
					var src := _ocarina(cache, int(ev[1]), length, seed)
					Synth.add_pan(l, r, verb, src, at, g, pan, verb_send)
					Synth.add(echo, src, at, g * echo_send)
				else:
					var src := _voice(cache, voice, int(ev[1]))
					Synth.add_pan(l, r, verb, src, at, g, pan, verb_send, length + ring_tail, ring_tail)
					Synth.add(echo, src, at, g * echo_send, length + ring_tail, ring_tail)

	var comp: Dictionary = score["comp"]
	var ostinato: Dictionary = score["ostinato"]
	var bass: Dictionary = score["bass"]
	var comp_damp := Synth.count(0.3)
	var ost_damp := Synth.count(0.08)
	var bass_tau := 0.3 if bright else 0.9
	for b: int in bars:
		var chord: Dictionary = table[chords[b]]
		var comp_events: Variant = _pattern(comp, b)
		if comp_events != null:
			for ev: Array in comp_events:
				var at := _at(b * 16 + int(ev[0]), step, swing, rng, 120)
				var src := _voice(cache, "rhodes", int(chord["keys"][ev[1]]))
				Synth.add(ep, src, at, float(mix["comp"]) * float(ev[3]), int(float(ev[2]) * step), comp_damp)
		var ost_events: Variant = _pattern(ostinato, b)
		if ost_events != null:
			var k := 0
			for ev: Array in ost_events:
				var at := _at(b * 16 + int(ev[0]), step, swing, rng, 60)
				var src := _voice(cache, "marimba", int(chord["keys"][ev[1]]))
				var g: float = float(mix["ostinato"]) * float(ev[2])
				var pan := -0.3 if k % 2 == 0 else 0.3
				Synth.add_pan(l, r, verb, src, at, g, pan, 0.3, int(2.0 * step), ost_damp)
				Synth.add(echo, src, at, g * 0.03, int(2.0 * step), ost_damp)
				k += 1
		var bass_events: Variant = _pattern(bass, b)
		if bass_events != null:
			for ev: Array in bass_events:
				var at := _at(b * 16 + int(ev[0]), step, swing, rng, 0)
				var src := _bass(cache, int(chord["bass"][ev[1]]), int(float(ev[2]) * step), bass_tau)
				Synth.add_pan(l, r, verb, src, at, float(mix["bass"]) * float(ev[3]), 0.0, 0.04)

	var perc: Dictionary = score["perc"]
	var stock := _shaker_stock(seed, SHAKER_BAND[tone])
	var shaker_tau := 0.028 if bright else 0.035
	for part_name: String in perc:
		var part: Dictionary = perc[part_name]
		var setup: Dictionary = PERC[part_name]
		var part_gain: float = mix[part_name]
		var jitter: int = setup["jitter"]
		var hit := PackedFloat32Array()
		match part_name:
			"kick":
				hit = _kick(cache, bright)
			"rim":
				hit = _rim(cache, seed)
			"tick":
				hit = _click(cache, TICK_HZ)
			"tock":
				hit = _click(cache, TOCK_HZ)
		for b: int in bars:
			var pattern: Variant = _pattern(part, b)
			if pattern == null:
				continue
			var hits: String = pattern
			for s: int in 16:
				if hits[s] == ".":
					continue
				var src: PackedFloat32Array = _shaker_hit(stock, rng, shaker_tau) if part_name == "shaker" else hit
				var at := _at(b * 16 + s, step, swing, rng, jitter)
				Synth.add_pan(l, r, verb, src, at, part_gain * int(hits[s]) / 9.0, setup["pan"], setup["verb"])

	# The comp bus: one mono sum, then a stereo tremolo in opposite phase.
	var ep_l := ep.duplicate()
	var ep_r := ep.duplicate()
	Synth.tremolo(ep_l, 4.2, 0.28, 0.0)
	Synth.tremolo(ep_r, 4.2, 0.28, PI)
	Synth.add(l, ep_l, 0, 1.0)
	Synth.add(r, ep_r, 0, 1.0)
	Synth.add(verb, ep, 0, 0.35)

	var echoes := Synth.ping_pong(echo, int(3.0 * step), 0.35, 2600.0)
	Synth.add(l, echoes[0], 0, 1.0)
	Synth.add(r, echoes[1], 0, 1.0)

	var wet_l := Synth.reverb(verb, 0.82, 0.5, 0)
	var wet_r := Synth.reverb(verb, 0.82, 0.5, 1)
	var wet_ratio := 0.30 if bright else 0.42
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

	# Loudness is set on the level above 200 Hz, which a phone speaker plays.
	var hl := Synth.highpass(l.duplicate(), WEIGHT_HIGHPASS_HZ)
	var hr := Synth.highpass(r.duplicate(), WEIGHT_HIGHPASS_HZ)
	var weighted := sqrt((pow(Synth.rms(hl), 2.0) + pow(Synth.rms(hr), 2.0)) * 0.5)
	var g := float(score["level"]) / maxf(weighted, 0.000000001)
	Synth.gain(l, g)
	Synth.gain(r, g)
	Synth.soft_ceiling(l, 0.6, 0.9)
	Synth.soft_ceiling(r, 0.6, 0.9)
	return [l, r]


func _loop_samples(score: Dictionary) -> int:
	var bpm: float = score["bpm"]
	var bars: int = score["bars"]
	return int(round(float(bars) * 4.0 * 60.0 / bpm * Synth.SR_F))


## Sample offset of a step: odd steps are late by `swing` of a step, plus a random jitter.
func _at(step_index: int, step: float, swing: float, rng: RandomNumberGenerator, jitter: int) -> int:
	var t := float(step_index) + (swing if step_index % 2 == 1 else 0.0)
	return int(round(t * step)) + (rng.randi_range(0, jitter) if jitter > 0 else 0)


## The pattern that a part plays in a bar, or null for a rest.
func _pattern(part: Dictionary, bar: int) -> Variant:
	var bars: String = part["bars"]
	if bar >= bars.length() or bars[bar] == ".":
		return null
	return part["patterns"][bars[bar]]


func _pad_note(cache: Dictionary, note: int, length: int, bright: bool) -> Array[PackedFloat32Array]:
	var key := "pad:%d:%d:%d" % [note, length, int(bright)]
	if cache.has(key):
		return cache[key]
	var f := Synth.hz(note)
	var attack := 0.35 if bright else 0.6
	var release := 0.6 if bright else 1.3
	var h2 := 0.30 if bright else 0.18
	var h3 := 0.10 if bright else 0.04
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


## A struck voice of one note: the comp, the ostinato and the melodic lines.
func _voice(cache: Dictionary, voice: String, note: int) -> PackedFloat32Array:
	var key := "%s:%d" % [voice, note]
	if cache.has(key):
		return cache[key]
	var f := Synth.hz(note)
	var buf: PackedFloat32Array
	match voice:
		"rhodes":
			buf = _tone(2.4, f, f, 0.0, [1.0, 2.0, 3.0, 4.0, 7.0], [1.0, 0.42, 0.10, 0.05, 0.07], [1.1, 0.7, 0.45, 0.3, 0.06], 0.006)
			Synth.normalize(buf, 1.0)
			Synth.saturate(buf, 1.5)
		"kalimba":
			buf = _tone(1.6, f, f, 0.0, [1.0, 2.0, 3.0, 5.4], [1.0, 0.25, 0.06, 0.09], [0.7, 0.28, 0.12, 0.03], 0.003)
		"kalimba_bright":
			buf = _tone(1.0, f, f, 0.0, [1.0, 2.0, 3.0, 5.4], [1.0, 0.3, 0.1, 0.04], [0.4, 0.15, 0.06, 0.02], 0.002)
		"celesta":
			buf = _tone(1.4, f, f, 0.0, [1.0, 2.0, 3.0, 4.1], [1.0, 0.3, 0.12, 0.05], [0.5, 0.22, 0.11, 0.05], 0.003)
		"marimba":
			buf = _tone(0.6, f, f, 0.0, [1.0, 4.0, 9.2], [1.0, 0.22, 0.05], [0.22, 0.05, 0.02], 0.002)
		_:
			push_error("bake_audio: unknown voice " + voice)
			return PackedFloat32Array()
	cache[key] = buf
	return buf


## A held wind voice: no decay, so the fade out is its only release.
func _ocarina(cache: Dictionary, note: int, length: int, noise_seed: int) -> PackedFloat32Array:
	var key := "ocarina:%d:%d" % [note, length]
	if cache.has(key):
		return cache[key]
	var f := Synth.hz(note)
	var n := length + Synth.count(0.18)
	var freq := Synth.pitch_curve(n, f * 0.985, f, 0.03, 5.2, 0.006, 0.0)
	var buf := Synth.partials(freq, PackedFloat32Array([1.0, 2.0, 3.0]), PackedFloat32Array([1.0, 0.10, 0.04]), PackedFloat32Array([0.0, 0.0, 0.0]))
	var breath := Synth.noise(n, noise_seed + note)
	Synth.bandpass_sweep(breath, f * 2.0, f * 2.0, 0.6)
	Synth.normalize(breath, 1.0)
	Synth.add(buf, breath, 0, 0.035)
	Synth.fade_in(buf, 0.07)
	Synth.fade_out(buf, 0.18)
	cache[key] = buf
	return buf


func _bass(cache: Dictionary, note: int, length: int, tau: float) -> PackedFloat32Array:
	var key := "bass:%d:%d:%.2f" % [note, length, tau]
	if cache.has(key):
		return cache[key]
	var release := 0.08
	var buf := Synth.warm_osc(length + Synth.count(release), Synth.hz(note), 0.35, 0.12)
	Synth.fade_in(buf, 0.012)
	Synth.decay(buf, tau)
	Synth.fade_out(buf, release)
	cache[key] = buf
	return buf


func _kick(cache: Dictionary, bright: bool) -> PackedFloat32Array:
	var key := "kick:%d" % int(bright)
	if cache.has(key):
		return cache[key]
	var buf: PackedFloat32Array
	if bright:
		buf = _tone(0.45, 125.0, 46.0, 0.035, [1.0, 2.0], [1.0, 0.08], [0.2, 0.05], 0.0015)
		Synth.lowpass(buf, 900.0)
	else:
		buf = _tone(0.32, 110.0, 48.0, 0.03, [1.0, 2.0], [1.0, 0.08], [0.14, 0.04], 0.003)
		Synth.lowpass(buf, 700.0)
	# A knock in the band that a phone speaker can play.
	_place(buf, _tone(0.09, 240.0, 150.0, 0.012, [1.0], [1.0], [0.03], 0.002), 0.0, 0.35)
	cache[key] = buf
	return buf


func _rim(cache: Dictionary, noise_seed: int) -> PackedFloat32Array:
	if cache.has("rim"):
		return cache["rim"]
	var buf := Synth.noise(Synth.count(0.09), noise_seed + 7)
	Synth.bandpass_sweep(buf, 1900.0, 1500.0, 0.9)
	Synth.fade_in(buf, 0.002)
	Synth.decay(buf, 0.028)
	Synth.normalize(buf, 1.0)
	_place(buf, _tone(0.09, 430.0, 400.0, 0.01, [1.0], [1.0], [0.022], 0.001), 0.0, 0.5)
	Synth.fade_out(buf, 0.01)
	cache["rim"] = buf
	return buf


## The wood click of the tick and the tock.
func _click(cache: Dictionary, f: float) -> PackedFloat32Array:
	var key := "click:%.2f" % f
	if cache.has(key):
		return cache[key]
	var buf := _tone(0.08, f, f * 0.97, 0.01, [1.0, 2.7], [1.0, 0.3], [0.02, 0.008], 0.001)
	cache[key] = buf
	return buf


## band: the high-pass and the low-pass cutoff in Hz.
func _shaker_stock(noise_seed: int, band: Vector2) -> PackedFloat32Array:
	var buf := _noise(2.0, noise_seed)
	Synth.highpass(buf, band.x)
	Synth.lowpass(buf, band.y)
	Synth.lowpass(buf, band.y)
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
		fails += _report(sound, info, 1, -1.0, EFFECT_PEAK[sound], -1.0)
	for score: Dictionary in [Score.CALM, Score.TENSE]:
		var clip: String = score["name"]
		var info := _read_wav(out + "/music/" + clip + ".wav")
		fails += _report(clip, info, 2, LOOP_SECONDS[clip], -1.0, score["level"])
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
## A negative expected_peak or expected_level skips that check.
func _report(label: String, info: Dictionary, channels: int, loop_seconds: float, expected_peak: float, expected_level: float) -> int:
	if info.is_empty():
		print("  FAIL %s: missing or not a 16-bit 44100 Hz PCM WAV" % label)
		return 1
	var fails := 0
	var notes := PackedStringArray()
	var seconds: float = info["seconds"]
	var pk: float = info["peak"]
	var level: float = info["rms"]
	var weighted: float = info["weighted"]
	var dc: float = info["dc"]
	if int(info["channels"]) != channels:
		notes.append("channels %d" % int(info["channels"]))
	if pk > MAX_PEAK:
		notes.append("peak above %.2f" % MAX_PEAK)
	if expected_peak >= 0.0 and absf(pk - expected_peak) > EFFECT_PEAK_TOLERANCE:
		notes.append("peak not %.2f" % expected_peak)
	if level < MIN_RMS:
		notes.append("rms below %.2f" % MIN_RMS)
	if absf(dc) > MAX_DC:
		notes.append("dc offset")
	var extra := ""
	if expected_level > 0.0:
		extra = "  weighted %.4f" % weighted
		if absf(20.0 * log(maxf(weighted, 0.000000001) / expected_level) / log(10.0)) > MUSIC_LEVEL_TOLERANCE_DB:
			notes.append("weighted level not %.3f" % expected_level)
	if loop_seconds > 0.0:
		if absf(seconds - loop_seconds) >= 0.0005:
			notes.append("loop length, expected %.3f s" % loop_seconds)
		var jump: float = info["seam_jump"]
		var edge_step: float = info["edge_step"]
		extra += "  seam %.4f (mean step %.4f, max step near seam %.4f)" % [jump, info["mean_step"], edge_step]
		if jump > edge_step:
			notes.append("loop seam click")
	fails = notes.size()
	print("%s %-10s %7.3f s  ch %d  peak %.3f  rms %.3f  dc %+.5f%s%s" % [
		"  OK  " if fails == 0 else "  FAIL", label, seconds, int(info["channels"]), pk, level, dc, extra,
		"" if fails == 0 else "  <- " + ", ".join(notes)])
	return fails


## Parses a PCM WAV and returns its stats, or {} when it is not 16-bit 44100 Hz.
## `weighted` is the RMS after a one-pole high-pass at WEIGHT_HIGHPASS_HZ.
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
	var hp_a := 1.0 - exp(-TAU * WEIGHT_HIGHPASS_HZ / Synth.SR_F)
	var pk := 0.0
	var sum := 0.0
	var sq := 0.0
	var hp_sq := 0.0
	var step_sum := 0.0
	var edge_step := 0.0
	var seam := 0.0
	for c: int in channels:
		var prev := 0.0
		var first := 0.0
		var lp := 0.0
		var o := data_at + 2 * c
		for i: int in frames:
			var x := bytes.decode_s16(o) / 32768.0
			o += 2 * channels
			pk = maxf(pk, absf(x))
			sum += x
			sq += x * x
			lp += hp_a * (x - lp)
			var h := x - lp
			hp_sq += h * h
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
		"peak": pk, "rms": sqrt(sq / total), "weighted": sqrt(hp_sq / total), "dc": sum / total,
		"seam_jump": seam, "mean_step": step_sum / total, "edge_step": edge_step,
	}


func _events_per_bar(score: Dictionary) -> float:
	var bars: int = score["bars"]
	var chords: Array = score["chords"]
	var total := 0
	for bar: int in bars:
		if bar == 0 or chords[bar] != chords[bar - 1]:
			total += 1
	var motifs: Dictionary = score["motifs"]
	for line: Dictionary in score["lines"]:
		for place: Array in line["places"]:
			total += (motifs[place[1]] as Array).size()
	for key: String in ["comp", "ostinato", "bass"]:
		for bar: int in bars:
			var events: Variant = _pattern(score[key], bar)
			if events != null:
				total += (events as Array).size()
	var perc: Dictionary = score["perc"]
	for key: String in perc:
		for bar: int in bars:
			var hits: Variant = _pattern(perc[key], bar)
			if hits != null:
				total += (hits as String).length() - (hits as String).count(".")
	return float(total) / float(bars)


func _kick_on_each_beat(score: Dictionary) -> bool:
	var kick: Dictionary = score["perc"]["kick"]
	var bars: int = score["bars"]
	if bars == 0:
		return false
	for bar: int in bars:
		var hits: Variant = _pattern(kick, bar)
		if hits == null:
			return false
		for beat: int in 4:
			if (hits as String)[beat * 4] == ".":
				return false
	return true
