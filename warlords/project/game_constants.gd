const ARENA_W := 16.0
const ARENA_H := 9.58
const WALL_THICK := 0.08
const WALL_HEIGHT := 0.35

const CASTLE_W := 4.8
const CASTLE_H := 2.4
const BRICK_W := 0.55
const BRICK_H := 0.25
const BRICK_D := 0.25
const BRICK_GAP := 0.05
const KING_RADIUS := 0.3

const BALL_RADIUS := 0.15
const BALL_SPEED := 10.0

const PADDLE_OFFSET := 0.80
const PADDLE_LENGTH := 1.0

const CATCH_MAX_TIME := 3.0
const CATCH_COOLDOWN := 10.0
const CATCH_IMMUNITY_TIME := 0.15

const POWERUP_COUNT := 12
const POWERUP_DRIFT_SPEED := 3.0
const POWERUP_EFFECT_DURATION := 12.0
const ROCKET_SPEED := 18.0
const MAX_ROCKETS := 2
const MOLOTOV_FLIGHT_TIME := 3.0
const MOLOTOV_ARC_HEIGHT := 1.5
const PADDLE_FIRE_DURATION := 7.0

const MIN_ANGLE := 0.35
const SFX_POOL_SIZE := 8

const PLAYER_COLORS := [
	Color(0.9, 0.15, 0.15),  # P1 red (top-left)
	Color(0.15, 0.4, 0.9),   # P2 blue (top-right)
	Color(0.15, 0.8, 0.2),   # P3 green (bottom-right)
	Color(0.9, 0.75, 0.1),   # P4 yellow (bottom-left)
]

const CORNERS := [
	[-1, -1],  # P1: top-left
	[ 1, -1],  # P2: top-right
	[ 1,  1],  # P3: bottom-right
	[-1,  1],  # P4: bottom-left
]

enum GameState { TITLE, PLAYING, ROUND_END, GAME_OVER }
enum PowerupType { ENLARGE, SHRINK, ROCKET, MOLOTOV }
