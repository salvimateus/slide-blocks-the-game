extends RefCounted
## Board knobs: atlas, layout, playback, block juice, tile juice, board juice and ceremonies. Owned by the agent board.
## Board units: one atlas texel is one board unit. BoardView scales the board units into the fit rect.

# Atlas.
const ATLAS_SIZE := Vector2i(2048, 1024)
const ATLAS_CELL := 144
const ATLAS_SMALL := 72

# Layout, in board units.
const PITCH := 128.0                   # distance between two tile centers
const TILE_GAP := 0.0625               # gap between tiles, as a share of the pitch
const TILE := PITCH * (1.0 - TILE_GAP)
const TILE_RADIUS := 22.0
const TILE_RAISE := 4.0                # a painted tile stands this much above an empty tile
const BLOCK_SIZE := Vector2(112, 108)
const BLOCK_SHADOW_Y := 44.0
const WELL_PAD := 8.0                  # tray well around the outer tiles
const RIM := 34.0                      # rim width
const RIM_LIP := 12.0                  # lower lip of the rim
const RIM_SHADOW := 22.0               # drop shadow below the rim
const RIM_ROUND_CONVEX := 22.0
const RIM_ROUND_CONCAVE := 30.0
const WELL_ROUND_CONVEX := 18.0
const WELL_ROUND_CONCAVE := 12.0

# Fit, in base units.
const MAX_PITCH_BASE := 108.0          # largest tile pitch on screen

# Playback.
const STEP_TIME := 0.075               # seconds for one tick of a swipe
const PAINT_AT := 0.65                 # share of a tick at which the entered tile gets its paint
const SETTLE_TIME := 0.05              # wait after the last stop before `finished`
const BUFFERED_SPEED := 1.5            # playback speed while a swipe waits in the buffer
const NUDGE_DISTANCE := 0.08           # no-move nudge, as a share of the pitch
const NUDGE_TIME := 0.2
const POWER_FULL_TILES := 6.0          # a slide of this many tiles gives a stop power of 1

# Block: stretch, squash and jiggle.
const STRETCH := 0.16                  # stretch along the motion while a block moves
const STRETCH_TIME := 0.07
const SQUASH_BASE := 0.12
const SQUASH_PER_TILE := 0.035
const SQUASH_MAX := 0.34
const SQUASH_SPREAD := 0.65            # side bulge, as a share of the squash
const SQUASH_RETURN_TIME := 0.55       # elastic return after a stop
const BUMP_JIGGLE := 0.09              # jiggle of a neighbor block that gets hit
const BUMP_PUSH := 0.05                # push of a neighbor block, as a share of the pitch
const BUMP_JIGGLE_TIME := 0.4

# Eyes.
const EYE_LOOK := 0.07                 # face offset along the swipe, as a share of the pitch
const EYE_SQUINT_TIME := 0.2
const BLINK_INTERVAL_MIN := 2.4
const BLINK_INTERVAL_MAX := 5.6
const BLINK_TIME := 0.12
const BLINK_DOUBLE_CHANCE := 0.25

# Tile.
const PAINT_POP := 1.06
const PAINT_POP_FRESH := 1.16
const PAINT_POP_TIME := 0.26
const FLASH_BODY_TIME := 0.04
const FLASH_WHITE := 0.7
const FLASH_REPAINT_WHITE := 0.45
const FLASH_FADE_TIME := 0.18
const RAIL_POP := 1.14
const RAIL_POP_TIME := 0.24

# Particles: counts at full motion.
const STREAK_AMOUNT := 40
const STREAK_LIFETIME := 0.34
const SPLASH_BASE := 6
const SPLASH_PER_TILE := 2
const SPLASH_MAX := 16
const RAIL_SPARKS := 7
const WIN_GLITTER_PER_TILE := 2
const WIN_GLITTER_RING_MAX := 22
const WIN_BURST := 60
const WIN_BURST_SPARKLES := 24

# Board.
const KICK_BASE := 5.0                 # base units
const KICK_PER_TILE := 1.8
const KICK_MAX := 18.0
const KICK_RETURN_TIME := 0.42
const HIT_STOP_MIN_TILES := 4
const HIT_STOP_MS := 60
const PULSE_SCALE := 1.035

# Level start and restart.
const INTRO_TRAY_TIME := 0.28
const INTRO_TILE_STAGGER := 0.016
const INTRO_TILE_TIME := 0.32
const INTRO_BLOCK_DELAY := 0.3
const INTRO_BLOCK_STAGGER := 0.07
const INTRO_BLOCK_DROP := 160.0        # base units
const INTRO_BLOCK_TIME := 0.42
const RESTART_WAVE_STAGGER := 0.014
const RESTART_FADE_TIME := 0.2
const RESTART_BLOCK_DELAY := 0.06
const RESTART_BLOCK_TIME := 0.34
const RESTART_HOP := 0.45              # as a share of the pitch

# Ceremonies.
const SCRIM_FADE_TIME := 0.3

# Win ceremony.
const WIN_START_DELAY := 0.2
const WIN_RING_INTERVAL := 0.075
const WIN_TILE_JUMP := 0.14            # as a share of the pitch
const WIN_TILE_JUMP_TIME := 0.3
const WIN_FLASH_TIME := 0.22
const WIN_BLOCK_JUMP := 0.35           # as a share of the pitch
const WIN_BLOCK_JUMP_TIME := 0.42
const WIN_BURST_DELAY := 0.2           # after the last ring
const WIN_HOLD_TIME := 0.5             # pause after the final burst, before the card

# Defeat ceremony.
const DEFEAT_START_DELAY := 0.25
const DEFEAT_DEFLATE := 0.72
const DEFEAT_DEFLATE_TIME := 0.5
const DEFEAT_RING_INTERVAL := 0.06
const DEFEAT_GRAY_TIME := 0.3
const DEFEAT_PULSE_TIME := 0.6
const DEFEAT_PULSE_LOOPS := 3
const DEFEAT_PULSE_ALPHA := 0.55
const DEFEAT_HOLD_TIME := 0.6

# Demo board.
const DEMO_MOVE_GAP := 0.55
const DEMO_WIN_DELAY := 0.25
const DEMO_HOLD_TIME := 1.1
