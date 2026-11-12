extends RefCounted
## Music as data. Times are sixteenth steps (16 to a bar). Notes are MIDI.
## Each pattern list is cycled by bar index (bar % size).
##   chords:  {"bar", "bars", "name", "root", "pad": [notes], "arp": [notes]}
##   motifs:  [step from motif start, note, length in steps, velocity]
##   melody:  [bar, motif name]
##   comp:    [step, index into "pad" of the chord, velocity]
##   ostinato:[step, index into "arp" of the chord, velocity]
##   bass:    [step, semitones over root, length in steps, velocity]
##   perc:    one character for each step: "." is no hit, "1" to "9" is velocity

const CALM := {
	"name": "calm",
	"bpm": 84,
	"bars": 16,
	"seed": 1607,
	"pad_tone": "soft",
	"chords": [
		{"bar": 0, "bars": 2, "name": "Cmaj7", "root": 48, "pad": [55, 60, 64, 71], "arp": []},
		{"bar": 2, "bars": 2, "name": "Am7", "root": 45, "pad": [57, 60, 64, 67], "arp": []},
		{"bar": 4, "bars": 2, "name": "Fmaj7", "root": 41, "pad": [53, 57, 60, 64], "arp": []},
		{"bar": 6, "bars": 2, "name": "Gadd9", "root": 43, "pad": [55, 59, 62, 69], "arp": []},
		{"bar": 8, "bars": 2, "name": "Cmaj7", "root": 48, "pad": [55, 60, 64, 71], "arp": []},
		{"bar": 10, "bars": 2, "name": "Am7", "root": 45, "pad": [57, 60, 64, 67], "arp": []},
		{"bar": 12, "bars": 2, "name": "Fmaj7", "root": 41, "pad": [53, 57, 60, 64], "arp": []},
		{"bar": 14, "bars": 2, "name": "Gadd9", "root": 43, "pad": [55, 59, 62, 69], "arp": []},
	],
	"motifs": {
		"a": [
			[0, 76, 4, 0.85], [4, 79, 4, 0.75], [8, 74, 2, 0.65], [10, 76, 6, 0.8],
			[22, 72, 2, 0.55], [24, 71, 8, 0.7],
			[32, 72, 4, 0.8], [36, 76, 4, 0.7], [40, 74, 2, 0.6], [42, 72, 4, 0.65],
			[48, 69, 8, 0.75], [60, 67, 4, 0.5],
		],
		"b": [
			[0, 81, 3, 0.8], [3, 79, 3, 0.7], [6, 76, 2, 0.65], [8, 72, 8, 0.75],
			[20, 74, 2, 0.55], [22, 76, 2, 0.6], [24, 77, 8, 0.65],
			[32, 74, 4, 0.8], [36, 79, 4, 0.7], [40, 81, 2, 0.65], [42, 79, 6, 0.7],
			[48, 74, 6, 0.65], [56, 71, 4, 0.55], [60, 74, 4, 0.5],
		],
	},
	"melody": [[0, "a"], [4, "b"], [8, "a"], [12, "b"]],
	"comp": [
		[[2, 0, 0.55], [6, 1, 0.5], [10, 2, 0.5], [14, 3, 0.45]],
		[[2, 1, 0.5], [6, 2, 0.45], [10, 3, 0.45], [13, 2, 0.35]],
	],
	"ostinato": [],
	"bass": [
		[[0, 0, 10, 0.9], [10, 7, 6, 0.6]],
		[[0, 0, 8, 0.85], [8, 7, 8, 0.65]],
	],
	"perc": {
		"kick": [],
		"shaker": ["..4...2...4...2.", "..4...2...4..32."],
	},
}

const TENSE := {
	"name": "tense",
	"bpm": 104,
	"bars": 8,
	"seed": 2203,
	"pad_tone": "bright",
	"chords": [
		{"bar": 0, "bars": 2, "name": "Am", "root": 45, "pad": [57, 60, 64, 69], "arp": [69, 72, 76, 81]},
		{"bar": 2, "bars": 2, "name": "F", "root": 41, "pad": [53, 57, 60, 65], "arp": [65, 69, 72, 77]},
		{"bar": 4, "bars": 2, "name": "Dm", "root": 38, "pad": [50, 57, 62, 65], "arp": [62, 65, 69, 74]},
		{"bar": 6, "bars": 2, "name": "E7", "root": 40, "pad": [52, 56, 59, 62], "arp": [64, 68, 71, 74]},
	],
	"motifs": {},
	"melody": [],
	"comp": [],
	"ostinato": [
		[[0, 0, 0.8], [2, 1, 0.55], [4, 2, 0.65], [6, 1, 0.5], [8, 3, 0.7], [10, 2, 0.55], [12, 1, 0.6], [14, 2, 0.5]],
		[[0, 0, 0.75], [2, 2, 0.55], [4, 1, 0.6], [6, 2, 0.5], [8, 3, 0.7], [10, 1, 0.55], [12, 2, 0.6], [14, 3, 0.55]],
	],
	"bass": [
		[[0, 0, 2, 1.0], [2, 0, 2, 0.55], [4, 12, 2, 0.7], [6, 0, 2, 0.55], [8, 0, 2, 0.9], [10, 0, 2, 0.55], [12, 12, 2, 0.7], [14, 7, 2, 0.6]],
	],
	"perc": {
		"kick": ["9...8...9...8..."],
		"shaker": ["3.6.3.6.3.6.3.6.", "3.6.3.6.3.6.3.66"],
	},
}
