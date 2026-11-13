extends RefCounted
## Audio knobs: bus levels, effect rate limits, note ladders and music. Owned by the agent audio.

# Buses.
const MASTER_DB := 0.0
const SFX_DB := -8.0
const MUSIC_DB := -13.02
const LIMITER_CEILING_DB := -1.0   # a safety net: normal play stays below it

# Effects.
const POLYPHONY := 24
const PAINT_SEMITONES := [-7, -5, -3, 0, 2, 5, 7, 9, 12, 14]   # F4 to D6 (F major pentatonic) over C5, the base of paint.wav
const RING_SEMITONES := [-3, 0, 2, 5, 7, 9, 12, 14, 17, 19]    # A4 to G6 (F major pentatonic) over C5, the base of ring.wav
const STAR_SEMITONES := [0, 4, 7]                               # F5, A5, C6 over F5, the base of star.wav
const GLITTER_SEMITONES := [-5, -2, 0, 3, 5]                    # A5, C6, D6, F6, G6 over D6, the base of glitter.wav
const GLITTER_MAX := 3                 # pings in each window
const GLITTER_WINDOW_MS := 100
const STOP_PITCH_SPREAD := 0.06        # random pitch spread of the squish and the bump
const STOP_MIN_GAIN := 0.4             # gain of a stop at power 0; power 1 gives full gain
const PAINT_STEP_DB := -0.3            # each paint ladder step is this much softer, as a higher note sounds louder
const STOP_WINDOW_MS := 45             # stop sounds that start in one window stack
const STOP_VOICES := 2                 # stop sounds in each window at most
const STOP_EXTRA_DB := -6.0            # added once for each earlier stop sound of the window
const WARM_UP_DB := -80.0
const DEFEAT_PHRASE_DELAY := 0.45      # seconds after the tape stop starts
const REPLAY_BOARD_DB := -6.0          # board sounds during a replay

# Music.
const CALM_BPM := 80
const TENSE_BPM := 112
const CALM_BARS := 32
const TENSE_BARS := 16
const BEATS_PER_BAR := 4
const SWITCH_FADE_TIME := 0.2
const SILENT_DB := -60.0
const FILTER_MIN_HZ := 3000.0
const FILTER_MAX_HZ := 15000.0
const FILTER_PAUSE_HZ := 1100.0
const FILTER_GLIDE_TIME := 0.6
const WIN_DUCK_DB := -8.0
const WIN_DUCK_TIME := 0.3
const UNDUCK_TIME := 0.5
const DEFEAT_TAPE_TIME := 0.9
const TAPE_END_PITCH := 0.08
const DEFEAT_RETURN_DB := -10.0
const DEFEAT_RETURN_TIME := 2.0
