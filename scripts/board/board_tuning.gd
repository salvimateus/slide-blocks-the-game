extends RefCounted
## Board knobs: playback, block juice, tile juice, board juice and ceremonies. Owned by the agent board.

# Atlas and layout.
const ATLAS_SIZE := Vector2i(2048, 1024)
const ATLAS_CELL := 144
const BOARD_MARGIN := 24.0             # base units between the tray rim and its fit rect
const TILE_GAP := 0.06                 # gap between tiles, as a share of the tile size

# Playback.
const STEP_TIME := 0.075               # seconds for one tick of a swipe
const BUFFERED_SPEED := 1.5            # playback speed while a swipe waits in the buffer
const NUDGE_DISTANCE := 0.08           # no-move nudge, as a share of the tile size
const NUDGE_TIME := 0.16

# Block: stretch, squash and jiggle.
const STRETCH := 0.16                  # stretch along the motion while a block moves
const SQUASH_BASE := 0.12
const SQUASH_PER_TILE := 0.035
const SQUASH_MAX := 0.34
const SQUASH_RETURN_TIME := 0.5        # elastic return after a stop
const BUMP_JIGGLE := 0.08              # jiggle of a neighbor block that gets hit
const BUMP_JIGGLE_TIME := 0.35

# Eyes.
const EYE_LOOK := 0.07                 # pupil offset along the swipe, as a share of the tile size
const EYE_SQUINT_TIME := 0.18
const BLINK_INTERVAL_MIN := 2.4
const BLINK_INTERVAL_MAX := 5.6
const BLINK_TIME := 0.12

# Tile.
const PAINT_POP := 1.07
const PAINT_POP_FRESH := 1.16
const PAINT_POP_TIME := 0.24
const FLASH_BODY_TIME := 0.04
const FLASH_WHITE := 0.7
const FLASH_FADE_TIME := 0.16
const STREAK_RATE := 28                # streak particles each second of motion
const SPLASH_BASE := 6
const SPLASH_PER_TILE := 2
const SPLASH_MAX := 16
const RAIL_POP := 1.14
const RAIL_POP_TIME := 0.2
const RAIL_SPARKS := 6

# Board.
const KICK_BASE := 5.0                 # base units
const KICK_PER_TILE := 1.8
const KICK_MAX := 18.0
const KICK_RETURN_TIME := 0.38
const HIT_STOP_MIN_TILES := 4
const HIT_STOP_MS := 60

# Level start and restart.
const INTRO_TILE_STAGGER := 0.016
const INTRO_TILE_TIME := 0.32
const INTRO_BLOCK_DROP := 160.0
const INTRO_BLOCK_TIME := 0.45
const RESTART_WAVE_STAGGER := 0.014
const RESTART_FADE_TIME := 0.2
const RESTART_BLOCK_TIME := 0.32

# Win ceremony.
const WIN_RING_INTERVAL := 0.075
const WIN_TILE_JUMP := 0.14            # as a share of the tile size
const WIN_FLASH_TIME := 0.18
const WIN_GLITTER_PER_RING := 6
const WIN_BLOCK_JUMP := 0.35
const WIN_BURST := 42
const WIN_HOLD_TIME := 0.5             # pause after the final burst, before the card

# Defeat ceremony.
const DEFEAT_DEFLATE := 0.72
const DEFEAT_DEFLATE_TIME := 0.5
const DEFEAT_RING_INTERVAL := 0.06
const DEFEAT_PULSE_TIME := 0.6
const DEFEAT_HOLD_TIME := 0.6
