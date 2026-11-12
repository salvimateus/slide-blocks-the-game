extends Node
## Global knobs. Each domain owns its own tuning file, preloaded here.

const Board := preload("res://scripts/board/board_tuning.gd")
const Audio := preload("res://scripts/audio/audio_tuning.gd")
const Ui := preload("res://scripts/ui/ui_tuning.gd")

# Layout, in base units.
const BASE_SIZE := Vector2(720, 1280)
const COLUMN_WIDTH := 720.0

# Input.
const SWIPE_THRESHOLD := 48.0          # drag distance on the dominant axis that emits a swipe
const TAP_SLOP := 14.0                 # a release under this distance is a tap
const SWIPE_BUFFER_SIZE := 1
const LONG_PRESS_TIME := 0.8           # long press on the pause title opens the performance panel

# Motion.
const REDUCED_MOTION_SCALE := 0.35     # one scale for kick, wave, hit-stop and particle counts
const HIT_STOP_TIME_SCALE := 0.05      # Engine.time_scale during a hit-stop, as a factor of the base scale

# Haptics: duration in ms and amplitude from 0 to 1.
const HAPTIC_MS := {&"stop": 14, &"win": 70, &"defeat": 110}
const HAPTIC_AMPLITUDE := {&"stop": 0.35, &"win": 0.7, &"defeat": 0.55}

# Ceremony and dialog dim.
const SCRIM_ALPHA := 0.45
const DIALOG_SCRIM_ALPHA := 0.55

# Boot cover: shortest time on screen, so the warm-up never flashes.
const BOOT_COVER_MIN_TIME := 0.35
