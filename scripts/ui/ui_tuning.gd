extends RefCounted
## UI knobs: type, HUD juice, tension, cards and screen motion. Owned by the agent ui.

# Type.
const WEIGHT_BODY := 600
const WEIGHT_BOLD := 800
const WEIGHT_TITLE := 900
const SIZE_TITLE := 92
const SIZE_HEADING := 48
const SIZE_BUTTON := 40
const SIZE_BODY := 30
const SIZE_SMALL := 24
const SIZE_COUNTER := 56

# Layout.
const GUTTER := 24.0
const HUD_HEIGHT := 200.0
const BUTTON_HEIGHT := 96.0
const CORNER_RADIUS := 28

# HUD juice.
const COUNTER_POP := 1.25
const COUNTER_POP_TIME := 0.25
const STAR_FALL_DISTANCE := 120.0
const STAR_FALL_TIME := 0.7
const METER_MARKER_TIME := 0.25

# Tension.
const VIGNETTE_ALPHA := 0.35
const VIGNETTE_FADE_TIME := 0.5
const HEARTBEAT_SCALE := 1.12
const HEARTBEAT_TIME := 0.18

# Hints.
const SWIPE_HINT_LOOP := 1.6
const SWIPE_HINT_DISTANCE := 160.0

# Cards.
const CARD_SPRING_TIME := 0.55
const STAR_POP_INTERVAL := 0.28
const STAR_POP_SCALE := 1.35
const COUNT_UP_TIME := 0.7

# Screens and buttons.
const SCREEN_FADE_TIME := 0.22
const BUTTON_PRESS_SCALE := 0.94
const BUTTON_PRESS_TIME := 0.08
const LOCKED_SHAKE := 14.0
const LOCKED_SHAKE_TIME := 0.35
const CARD_STAGGER := 0.04             # level select cards pop in a stagger
