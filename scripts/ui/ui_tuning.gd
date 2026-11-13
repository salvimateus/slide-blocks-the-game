extends RefCounted
## UI knobs: type, HUD juice, tension, cards and screen motion. Owned by the agent ui.

# Type.
const WEIGHT_BODY := 600
const WEIGHT_BOLD := 800
const WEIGHT_TITLE := 900
const SIZE_TITLE := 116
const SIZE_HEADING := 48
const SIZE_BUTTON := 40
const SIZE_BODY := 30
const SIZE_SMALL := 24
const SIZE_TINY := 20
const SIZE_COUNTER := 44
const SIZE_STAT := 46

# Layout.
const GUTTER := 24.0
const BUTTON_HEIGHT := 96.0
const BUTTON_HEIGHT_HERO := 112.0
const ICON_BUTTON_SIZE := 88.0
const CORNER_RADIUS := 28
const BUTTON_LIP := 8                  # lower lip of a button, in base px
const BUTTON_LIP_PRESSED := 2
const CARD_WIDTH := 640.0
const CARD_PADDING := 36
const HINT_AREA_HEIGHT := 92.0         # always reserved below the board, so the board rect does not change between levels
const TOGGLE_ROW_HEIGHT := 80.0

# HUD juice.
const COUNTER_POP := 1.25
const COUNTER_POP_TIME := 0.25
const STAR_FALL_DISTANCE := 120.0
const STAR_FALL_TIME := 0.7
const STAR_FALL_SPIN := 1.6            # radians
const METER_POP_SCALE := 1.45          # the pop of a segment that a move lights
const METER_POP_TIME := 0.24
const PROGRESS_TIME := 0.3

# Tension.
const VIGNETTE_ALPHA := 0.35
const VIGNETTE_BEAT_ALPHA := 0.5
const VIGNETTE_FADE_TIME := 0.5
const HEARTBEAT_SCALE := 1.12
const HEARTBEAT_TIME := 0.18

# Hints.
const SWIPE_HINT_LOOP := 1.6
const SWIPE_HINT_DISTANCE := 160.0
const HINT_FADE_TIME := 0.3

# Cards.
const CARD_SPRING_TIME := 0.55
const CARD_START_SCALE := 0.7
const STAR_POP_INTERVAL := 0.28
const STAR_POP_SCALE := 1.35
const STAR_POP_TIME := 0.45
const STAR_POP_SPIN := 0.5             # radians
const COUNT_UP_TIME := 0.7
const BADGE_POP_TIME := 0.4
const SCRIM_FADE_TIME := 0.25

# Screens and buttons.
const SCREEN_FADE_TIME := 0.22
const SCREEN_SLIDE := 36.0
const BUTTON_PRESS_SCALE := 0.94
const BUTTON_PRESS_TIME := 0.08
const BUTTON_RELEASE_TIME := 0.45
const LOCKED_SHAKE := 14.0
const LOCKED_SHAKE_TIME := 0.35
const CARD_STAGGER := 0.04             # level select cards pop in a stagger
const CARD_POP_TIME := 0.35
const LEVELS_PAGE_SIZE := 8            # level select cards on one page: 2 columns x 4 rows
const THUMB_MAX_PIXEL_SCALE := 1.25    # level thumbnails bake at most at this pixel scale, so all looks fit one atlas
const LEVELS_PAGE_GAP := 48.0          # space between two pages of the strip, so a sliding page never shows its neighbour
const LEVELS_PAGE_TIME := 0.32
const PAGE_DOT_SIZE := 16.0
const SWITCH_TIME := 0.22

# Random level loading.
const RANDOM_LOADING_DELAY := 0.25     # real seconds before the loading screen fades in
const LOADING_BOB := 12.0
const LOADING_BOB_TIME := 0.45

# Home title.
const TITLE_DROP := 120.0
const TITLE_LETTER_STAGGER := 0.045
const TITLE_BOB := 7.0
const TITLE_BOB_TIME := 1.1
