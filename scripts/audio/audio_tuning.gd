extends RefCounted
## Audio knobs: bus levels, effect rate limits, paint ladder and music. Owned by the agent audio.

# Buses.
const MASTER_DB := 0.0
const SFX_DB := -3.0
const MUSIC_DB := -9.0
const LIMITER_CEILING_DB := -0.5

# Effects.
const POLYPHONY := 24
const PAINT_BASE_NOTE := 72            # MIDI number of C5
const PAINT_SEMITONES := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]
const REPAINT_DB := -8.0
const GLITTER_MAX := 6                 # pings in each window
const GLITTER_WINDOW_MS := 100
const STOP_PITCH_SPREAD := 0.06        # random pitch spread of the squish and the bump

# Music.
const CALM_BPM := 84
const TENSE_BPM := 104
const CALM_BARS := 16
const TENSE_BARS := 8
const BEATS_PER_BAR := 4
const SWITCH_FADE_TIME := 0.12
const FILTER_MIN_HZ := 1800.0
const FILTER_MAX_HZ := 14000.0
const FILTER_PAUSE_HZ := 900.0
const FILTER_GLIDE_TIME := 0.6
const WIN_DUCK_DB := -12.0
const WIN_DUCK_TIME := 0.3
const DEFEAT_TAPE_TIME := 0.9
const DEFEAT_RETURN_DB := -10.0
const DEFEAT_RETURN_TIME := 2.0
