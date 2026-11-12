extends RefCounted
## Offline DSP helpers for the audio bake. Buffers are mono PackedFloat32Array
## at SR; functions that change a buffer change it in place and also return it.

const SR := 44100
const SR_F := 44100.0
const NYQUIST_GUARD := 16000.0

const COMBS_L: PackedInt32Array = [1116, 1277, 1422, 1557]
const COMBS_R: PackedInt32Array = [1188, 1356, 1491, 1617]
const ALLPASS_L: PackedInt32Array = [556, 441]
const ALLPASS_R: PackedInt32Array = [579, 464]


static func count(seconds: float) -> int:
	return int(round(seconds * SR_F))


static func hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func silence(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	return out


# --- Sources ---------------------------------------------------------------

## Frequency for each sample: exponential glide from f_start to f_end with the
## time constant glide_tau, times a vibrato that fades with wobble_tau.
static func pitch_curve(n: int, f_start: float, f_end: float, glide_tau: float, wobble_hz: float = 0.0, wobble_depth: float = 0.0, wobble_tau: float = 0.0) -> PackedFloat32Array:
	var out := silence(n)
	var g := 1.0 if glide_tau > 0.0 else 0.0
	var gk := exp(-1.0 / (glide_tau * SR_F)) if glide_tau > 0.0 else 0.0
	var df := f_start - f_end
	var wd := wobble_depth
	var wk := exp(-1.0 / (wobble_tau * SR_F)) if wobble_tau > 0.0 else 1.0
	var ww := TAU * wobble_hz / SR_F
	var wph := 0.0
	for i: int in n:
		out[i] = (f_end + df * g) * (1.0 + wd * sin(wph))
		g *= gk
		wd *= wk
		wph += ww
	return out


## Additive partials on a pitch curve. Each partial has a frequency ratio, an
## amplitude and its own exponential decay (tau <= 0 holds the level).
static func partials(freq: PackedFloat32Array, ratios: PackedFloat32Array, amps: PackedFloat32Array, taus: PackedFloat32Array) -> PackedFloat32Array:
	var n := freq.size()
	var out := silence(n)
	if n == 0:
		return out
	var k := TAU / SR_F
	for p: int in ratios.size():
		var ratio := ratios[p]
		if ratio * freq[0] > NYQUIST_GUARD:
			continue
		var w := k * ratio
		var a := amps[p]
		var dec := exp(-1.0 / (taus[p] * SR_F)) if taus[p] > 0.0 else 1.0
		var ph := 0.0
		for i: int in n:
			out[i] += a * sin(ph)
			ph += w * freq[i]
			a *= dec
			if a < 0.000001 and a > -0.000001:
				break
	return out


## One oscillator with harmonics 2 and 3 from one sine (Chebyshev shaping), so
## long sustained voices cost one sin() for each sample. The output does not
## start at zero: always give it a fade_in.
static func warm_osc(n: int, f: float, h2: float, h3: float, phase: float = 0.0) -> PackedFloat32Array:
	var out := silence(n)
	var w := TAU * f / SR_F
	var ph := phase
	for i: int in n:
		var s := sin(ph)
		out[i] = s + h2 * (1.0 - 2.0 * s * s) + h3 * (3.0 * s - 4.0 * s * s * s)
		ph += w
	return out


static func noise(n: int, noise_seed: int) -> PackedFloat32Array:
	var out := silence(n)
	var s := (noise_seed * 2654435761 + 12345) & 0xFFFFFFFF
	for i: int in n:
		s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
		out[i] = float(s) / 2147483648.0 - 1.0
	return out


# --- Envelopes -------------------------------------------------------------

## Raised-cosine fade in over the first `seconds`.
static func fade_in(buf: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var m := mini(count(seconds), buf.size())
	if m <= 0:
		return buf
	for i: int in m:
		buf[i] *= 0.5 - 0.5 * cos(PI * float(i) / float(m))
	return buf


## Raised-cosine fade out over the last `seconds`.
static func fade_out(buf: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var n := buf.size()
	var m := mini(count(seconds), n)
	if m <= 0:
		return buf
	var start := n - m
	for i: int in m:
		buf[start + i] *= 0.5 + 0.5 * cos(PI * float(i + 1) / float(m))
	return buf


## Exponential decay that starts at `start` seconds.
static func decay(buf: PackedFloat32Array, tau: float, start: float = 0.0) -> PackedFloat32Array:
	var k := exp(-1.0 / (tau * SR_F))
	var g := 1.0
	for i: int in range(count(start), buf.size()):
		buf[i] *= g
		g *= k
	return buf


## Amplitude modulation: depth 0 is no change, depth 1 goes to silence.
static func tremolo(buf: PackedFloat32Array, rate_hz: float, depth: float) -> PackedFloat32Array:
	var w := TAU * rate_hz / SR_F
	for i: int in buf.size():
		buf[i] *= 1.0 - depth * (0.5 - 0.5 * cos(w * float(i)))
	return buf


## Gain dip at each beat that recovers with `recover` seconds (a soft pump).
## The dip goes in over a few milliseconds, so the gain never steps.
static func pump(buf: PackedFloat32Array, beat_samples: float, depth: float, recover: float) -> PackedFloat32Array:
	var k := exp(-1.0 / (recover * SR_F))
	var ka := 1.0 - exp(-1.0 / (0.006 * SR_F))
	var next_beat := 0.0
	var dip := 0.0
	var env := 0.0
	for i: int in buf.size():
		if float(i) >= next_beat:
			dip = depth
			next_beat += beat_samples
		env += ka * (dip - env)
		buf[i] *= 1.0 - env
		dip *= k
	return buf


static func gain(buf: PackedFloat32Array, g: float) -> PackedFloat32Array:
	for i: int in buf.size():
		buf[i] *= g
	return buf


# --- Filters ---------------------------------------------------------------

static func lowpass(buf: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff / SR_F)
	var y := 0.0
	for i: int in buf.size():
		y += a * (buf[i] - y)
		buf[i] = y
	return buf


static func highpass(buf: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff / SR_F)
	var y := 0.0
	for i: int in buf.size():
		y += a * (buf[i] - y)
		buf[i] -= y
	return buf


## State-variable band-pass (Chamberlin) with an exponential center sweep.
## `damping` is 1/Q: a low value rings, a high value is broad.
static func bandpass_sweep(buf: PackedFloat32Array, c_start: float, c_end: float, damping: float) -> PackedFloat32Array:
	var n := buf.size()
	if n == 0:
		return buf
	var r := pow(c_end / c_start, 1.0 / float(n))
	var c := c_start
	var low := 0.0
	var band := 0.0
	var k := PI / SR_F
	for i: int in n:
		var f := 2.0 * sin(k * minf(c, 7000.0))
		low += f * band
		var high := buf[i] - low - damping * band
		band += f * high
		buf[i] = band
		c *= r
	return buf


# --- Space -----------------------------------------------------------------

## Wet signal of a small Schroeder reverb (four damped combs, two all-passes).
## `side` 0 or 1 picks a decorrelated delay set for the left or right channel.
static func reverb(src: PackedFloat32Array, room: float, damp: float, side: int) -> PackedFloat32Array:
	var n := src.size()
	var acc := silence(n)
	var combs := COMBS_L if side == 0 else COMBS_R
	var passes := ALLPASS_L if side == 0 else ALLPASS_R
	var fb := 0.7 + 0.28 * room
	var d1 := damp * 0.4
	var d2 := 1.0 - d1
	for c: int in combs.size():
		var d := combs[c]
		var line := silence(d)
		var idx := 0
		var store := 0.0
		for i: int in n:
			var o := line[idx]
			store = o * d2 + store * d1
			line[idx] = src[i] + store * fb
			acc[i] += o
			idx += 1
			if idx == d:
				idx = 0
	for a: int in passes.size():
		var d := passes[a]
		var line := silence(d)
		var idx := 0
		for i: int in n:
			var o := line[idx]
			var x := acc[i]
			line[idx] = x + o * 0.5
			acc[i] = o - x
			idx += 1
			if idx == d:
				idx = 0
	return acc


## Ping-pong echo of a mono send. Returns [left, right] wet buffers.
static func ping_pong(src: PackedFloat32Array, delay_samples: int, feedback: float, cutoff: float) -> Array[PackedFloat32Array]:
	var n := src.size()
	var yl := silence(n)
	var yr := silence(n)
	var a := 1.0 - exp(-TAU * cutoff / SR_F)
	var lp_l := 0.0
	var lp_r := 0.0
	for i: int in range(delay_samples, n):
		var j := i - delay_samples
		lp_r += a * (yr[j] - lp_r)
		lp_l += a * (yl[j] - lp_l)
		yl[i] = src[j] + feedback * lp_r
		yr[i] = feedback * lp_l
	return [yl, yr]


# --- Mixing ----------------------------------------------------------------

## Adds src into dst at offset. After `damp_at` samples of src, a linear fade of
## `damp_len` samples ends the voice (damp_at < 0 keeps the whole voice).
static func add(dst: PackedFloat32Array, src: PackedFloat32Array, offset: int, g: float, damp_at: int = -1, damp_len: int = 1) -> void:
	var n := src.size()
	if damp_at >= 0:
		n = mini(n, damp_at + damp_len)
	var first := maxi(0, -offset)
	var last := mini(n, dst.size() - offset)
	var inv := 1.0 / float(maxi(damp_len, 1))
	for j: int in range(first, last):
		var e := g
		if damp_at >= 0 and j > damp_at:
			e = g * (1.0 - float(j - damp_at) * inv)
		dst[offset + j] += src[j] * e


## Adds a mono voice to a stereo pair with an equal-power pan (-1 left, 1 right)
## and to a mono send bus.
static func add_pan(dl: PackedFloat32Array, dr: PackedFloat32Array, send: PackedFloat32Array, src: PackedFloat32Array, offset: int, g: float, pan: float, send_g: float, damp_at: int = -1, damp_len: int = 1) -> void:
	var angle := (clampf(pan, -1.0, 1.0) + 1.0) * PI * 0.25
	add(dl, src, offset, g * cos(angle), damp_at, damp_len)
	add(dr, src, offset, g * sin(angle), damp_at, damp_len)
	if send_g > 0.0:
		add(send, src, offset, g * send_g, damp_at, damp_len)


## Adds the part of buf past loop_len back to its start, then cuts it to loop_len.
static func fold_loop(buf: PackedFloat32Array, loop_len: int) -> PackedFloat32Array:
	for i: int in range(loop_len, buf.size()):
		buf[(i - loop_len) % loop_len] += buf[i]
	buf.resize(loop_len)
	return buf


static func remove_mean(buf: PackedFloat32Array) -> PackedFloat32Array:
	var n := buf.size()
	if n == 0:
		return buf
	var s := 0.0
	for i: int in n:
		s += buf[i]
	var m := s / float(n)
	for i: int in n:
		buf[i] -= m
	return buf


static func peak(buf: PackedFloat32Array) -> float:
	var p := 0.0
	for i: int in buf.size():
		p = maxf(p, absf(buf[i]))
	return p


static func rms(buf: PackedFloat32Array) -> float:
	var n := buf.size()
	if n == 0:
		return 0.0
	var s := 0.0
	for i: int in n:
		s += buf[i] * buf[i]
	return sqrt(s / float(n))


static func has_nan(buf: PackedFloat32Array) -> bool:
	for i: int in buf.size():
		if is_nan(buf[i]) or is_inf(buf[i]):
			return true
	return false


## Scales so the buffer peak equals target.
static func normalize(buf: PackedFloat32Array, target: float) -> PackedFloat32Array:
	var p := peak(buf)
	if p > 0.0:
		gain(buf, target / p)
	return buf


# --- Output ----------------------------------------------------------------

## 16-bit AudioStreamWAV. Pass an empty right buffer for mono.
static func to_stream(left: PackedFloat32Array, right: PackedFloat32Array) -> AudioStreamWAV:
	var stereo := right.size() > 0
	var n := left.size()
	var ch := 2 if stereo else 1
	var data := PackedByteArray()
	data.resize(n * ch * 2)
	var o := 0
	for i: int in n:
		data.encode_s16(o, int(round(clampf(left[i], -1.0, 1.0) * 32767.0)))
		o += 2
		if stereo:
			data.encode_s16(o, int(round(clampf(right[i], -1.0, 1.0) * 32767.0)))
			o += 2
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SR
	stream.stereo = stereo
	stream.data = data
	return stream
