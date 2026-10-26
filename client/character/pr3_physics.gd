class_name Pr3Physics
## Platform Racing 3 player physics, used when a level turns on "pr3_physics"
## (or a PR3 physics switch block is touched).
##
## A line-by-line port of PR3's ActivePlayer.step / testBlocks / touchBlock /
## blockTests and LocalPlayer's overrides (game build 16_10_2026_b1), without
## hats, Lua and code blocks. PR3 moves in milliseconds at 27 steps a second
## on 40px blocks, with the player rotating instead of the level. Positions
## here are PR3 pixels in level space, converted to PR4 for display.

const BLOCK := 40.0
const PR4_PER_PR3 := 128.0 / 40.0 # PR4 pixels per PR3 pixel
const STEP_MS := 1000.0 / 27.0 # Settings.gameFPS = 27
const STEP_TIME := 1.0 / 27.0
const MAX_STEPS_PER_TICK := 4
const DEG_RAD := 0.0174533 # PR3's Maths.DEG_RAD (not exactly PI / 180)
const TWIPS_PER_PIXEL := 20.0

const HIT_WIDTH := 10.0
const HIT_HEIGHT := 60.0
const MAX_MOVE_PER_FRAME := 39.0
const DEFAULT_GRAVITY := 0.0005
const MAX_SUPER_JUMP_VEL := 0.61
const CHARGE_SJ_THRESHOLD := 0.1
const FALL_TOLERANCE := 400.0
const VANISH_DISAPPEAR_MS := 2000.0
const VANISH_RETRY_MS := 1000.0
const TELEPORT_COOLDOWN_MS := 3000.0
const PUSH_COOLDOWN_MS := 33.0
const RECOVERY_MS := 2500
const HURT_MS := 1950
# How long a portable block / mine takes to appear (BlockEffectGraphic).
const PORTABLE_BLOCK_FRAMES := 27

# PR3's item holder (Player graphic "item" clip x 0.4 scale) per pose, per frame.
const ITEM_POINTS := {
	"stand": [
		Vector2(18.9, -30.54)
	],
	"jump": [
		Vector2(18.9, -30.54), Vector2(18.9, -31.76), Vector2(18.9, -32.64), Vector2(18.94, -33),
		Vector2(18.9, -33.34), Vector2(18.92, -32.64), Vector2(18.94, -31.96),
		Vector2(18.92, -31.24), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54)
	],
	"crouch": [
		Vector2(18.9, -13.74)
	],
	"crawl": [
		Vector2(18.9, -14.94), Vector2(19.04, -14.74), Vector2(19.16, -14.54),
		Vector2(19.3, -14.34), Vector2(19.44, -14.14), Vector2(19.56, -13.94),
		Vector2(19.7, -13.74), Vector2(19.56, -13.94), Vector2(19.44, -14.14),
		Vector2(19.3, -14.34), Vector2(19.16, -14.54), Vector2(19.04, -14.74),
		Vector2(18.9, -14.94)
	],
	"swim": [
		Vector2(21.06, -28.62), Vector2(21.06, -28.48), Vector2(21.06, -28.36),
		Vector2(21.06, -28.22), Vector2(21.06, -28.08), Vector2(21.06, -27.96),
		Vector2(21.06, -27.82), Vector2(21.06, -27.96), Vector2(21.06, -28.08),
		Vector2(21.06, -28.22), Vector2(21.06, -28.36), Vector2(21.06, -28.48),
		Vector2(21.06, -28.62)
	],
	"chargeJump": [
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54), Vector2(18.9, -30.54),
		Vector2(18.9, -30.54), Vector2(18.9, -30.42), Vector2(18.9, -30.3), Vector2(18.9, -30.18),
		Vector2(18.9, -30.06), Vector2(18.9, -29.94), Vector2(18.9, -29.82), Vector2(18.9, -29.7),
		Vector2(18.9, -29.58), Vector2(18.9, -29.46), Vector2(18.9, -29.34), Vector2(18.9, -29.22),
		Vector2(18.9, -29.1), Vector2(18.9, -28.98), Vector2(18.9, -28.88), Vector2(18.9, -28.76),
		Vector2(18.9, -28.64), Vector2(18.9, -28.52), Vector2(18.9, -28.4), Vector2(18.9, -28.28),
		Vector2(18.9, -28.16), Vector2(18.9, -28.04), Vector2(18.9, -27.92), Vector2(18.9, -27.8),
		Vector2(18.9, -27.68), Vector2(18.9, -27.56), Vector2(18.9, -27.44), Vector2(18.9, -27.32),
		Vector2(18.9, -27.2), Vector2(18.9, -27.08), Vector2(18.9, -26.96), Vector2(18.9, -26.84),
		Vector2(18.9, -26.72), Vector2(18.9, -26.6), Vector2(18.9, -26.48), Vector2(18.9, -26.36),
		Vector2(18.9, -26.24), Vector2(18.9, -26.12), Vector2(18.9, -26), Vector2(18.9, -25.88),
		Vector2(18.9, -25.76), Vector2(18.9, -25.66), Vector2(18.9, -25.54), Vector2(18.9, -25.42),
		Vector2(18.9, -25.3), Vector2(18.9, -25.18), Vector2(18.9, -25.06), Vector2(18.9, -24.94),
		Vector2(18.9, -24.82), Vector2(18.9, -24.7), Vector2(18.9, -24.58), Vector2(18.9, -24.46),
		Vector2(18.9, -24.34), Vector2(18.9, -24.22), Vector2(18.9, -24.1), Vector2(18.9, -23.98),
		Vector2(18.9, -23.86), Vector2(18.9, -23.74), Vector2(18.9, -23.62), Vector2(18.9, -23.5),
		Vector2(18.9, -23.38), Vector2(18.9, -23.26), Vector2(18.9, -23.14), Vector2(18.9, -23.02),
		Vector2(18.9, -22.9), Vector2(18.9, -22.78), Vector2(18.9, -22.66), Vector2(18.9, -22.54),
		Vector2(18.9, -22.44), Vector2(18.9, -22.32), Vector2(18.9, -22.2), Vector2(18.9, -22.08),
		Vector2(18.9, -21.96), Vector2(18.9, -21.84), Vector2(18.9, -21.72), Vector2(18.9, -21.6),
		Vector2(18.9, -21.48), Vector2(18.9, -21.36), Vector2(18.9, -21.24), Vector2(18.9, -21.12),
		Vector2(18.9, -21), Vector2(18.9, -20.88), Vector2(18.9, -20.48), Vector2(18.9, -20.12),
		Vector2(18.9, -19.76), Vector2(18.9, -19.44), Vector2(18.9, -19.12), Vector2(18.9, -18.84),
		Vector2(18.9, -18.56), Vector2(18.9, -18.32), Vector2(18.9, -18.08), Vector2(18.9, -17.88),
		Vector2(18.9, -17.68), Vector2(18.9, -17.52), Vector2(18.9, -17.36), Vector2(18.9, -17.24),
		Vector2(18.9, -17.12), Vector2(18.9, -17.04), Vector2(18.9, -16.96), Vector2(18.9, -16.92),
		Vector2(18.9, -16.88), Vector2(18.9, -16.88)
	],
	"run": [
		Vector2(24.8, -31.42), Vector2(24.8, -31.82), Vector2(24.8, -31.42), Vector2(24.8, -31.02),
		Vector2(24.8, -30.62), Vector2(24.8, -30.22), Vector2(24.8, -29.82), Vector2(24.8, -30.22),
		Vector2(24.8, -30.62), Vector2(24.8, -31.02), Vector2(24.8, -31.42), Vector2(24.8, -31.82),
		Vector2(24.8, -31.42), Vector2(24.8, -31.02), Vector2(24.8, -30.62), Vector2(24.8, -30.22),
		Vector2(24.8, -29.82), Vector2(24.8, -29.82), Vector2(24.8, -30.22), Vector2(24.8, -30.62),
		Vector2(24.8, -31.02)
	],
}

# PR3 block types (BlockSettings)
const T_ACTIVE := "active"
const T_INACTIVE := "inactive"
const T_START := "start"
const T_WATER := "water"
const T_MOVE := "move"
const T_WEAK := "weak"
const T_IMPERVIOUS := "impervious"

# PR3 block side types (BlockSideSettings)
const S_ACTIVE := "active"
const S_INACTIVE := "inactive"
const S_EXPLODE := "explode"
const S_TELEPORT := "teleport"
const S_BOUNCE := "bounce"
const S_SAFETY := "safety"
const S_FINISH := "finish"
const S_CRUMBLE := "crumble"
const S_PUSH_UP := "pushUp"
const S_PUSH_RIGHT := "pushRight"
const S_PUSH_DOWN := "pushDown"
const S_PUSH_LEFT := "pushLeft"
const S_GIVE_ITEM := "giveItem"
const S_ROTATE_RIGHT := "rotateRight"
const S_ROTATE_LEFT := "rotateLeft"
const S_INC_STATS := "incStats"
const S_DEC_STATS := "decStats"
const S_INC_HEALTH := "incHealth"
const S_ICE := "ice"
const S_BE_PUSHED := "bePushed"
const S_SHATTER := "shatter"
const S_VANISH := "vanish"
const S_PR4 := "pr4" # a PR4-only block: its PR4 behavior runs on a fresh touch

const SIDES := ["top", "right", "bottom", "left"]
const PUSH_DIRECTIONS := [S_PUSH_UP, S_PUSH_RIGHT, S_PUSH_DOWN, S_PUSH_LEFT]

# PR4 item ids that use PR3's item rules in PR3 physics mode.
const ITEM_ANGEL_WINGS := 1
const ITEM_JETPACK := 4
const ITEM_LASER_GUN := 5
const ITEM_PORTABLE_BLOCK := 7
const ITEM_PORTABLE_MINE := 8
const ITEM_ROCKET_LAUNCHER := 9
const ITEM_SHIELD := 10
const ITEM_SPEED_BURST := 11
const ITEM_SUPER_JUMP := 12
const ITEM_SWORD := 13
const ITEM_TELEPORT := 14

# PR4 block ids
const B_CRUMBLE := 18
const B_MINE := 10
const B_WATER := 21
const B_SAFETY := 25

const BUMP_SOUND := preload("res://sounds/BumpSound.ogg")
const JUMP_SOUND := preload("res://sounds/JumpSound.ogg")
const SUPER_JUMP_SOUND := preload("res://sounds/SuperJumpSound.ogg")
const EXPLODE_EFFECT := preload("res://tiles/mine/explode_effect.tscn")
const MINE_SPAWN_EFFECT := preload("res://item_effects/portable_mine.tscn")
const BLOCK_SPAWN_EFFECT := preload("res://item_effects/portable_block.tscn")

# ActivePlayer state (PR3 names)
var real_x: float = 0
var real_y: float = 0
var vel_x: float = 0
var vel_y: float = 0
var move_x: float = 0
var move_y: float = 0
var rotated_move_x: float = 0
var rotated_move_y: float = 0
var rotated_vel_x: float = 0
var rotated_vel_y: float = 0
var shifted_x: float = 0
var shifted_y: float = 0
var shifted_move_x: float = 0
var shifted_move_y: float = 0
var shifted_vel_x: float = 0
var shifted_vel_y: float = 0
var rotation: float = 0 # degrees, Flash DisplayObject range (-180, 180]
var target_rot: float = 0 # vars.rot
var rotating := false
var rotation_amplifier: float = 1
var multiplier_x := 1
var multiplier_y := 1
var touching_ground := false
var crouching := false
var swimming := false
var on_ice := false
var still_holding_up := false
var remaining_jump_vel: float = 0
var super_jump_vel: float = 0
var charging_super_jump := false
var arrow_max_speed_boost: float = 0
var speed_burst_speed_boost: float = 0
var item_accel_boost: float = 1
var gravity: float = DEFAULT_GRAVITY
var hurt := false
var hurt_timer: float = 0
var recovery_timer: float = 0
var iced := false
var shield := false
var use_shifted_vel := true
var attempting_bump := false
var last_bump_key := ""
var facing_right := true
var jumped_time := 0
var pose := "stand" # Player.state, the animation playing
var pose_frame := 1
var pose_playing := false # chargeJump plays on from frame 100
var aborted := false # PR3's EndBlockTestPhysicFlowError
var safe_x: float = 0
var safe_y: float = 0
var got_an_item := false
var got_item_keys: Array = []
var input := {"up": false, "down": false, "left": false, "right": false, "space": false}

# Items (PR3 Item subclasses)
var item_node: Node
var item_id := -1
var item_uses := 0
var item_reload_ms: float = 0
var item_reload_until: float = -1
var jet_using := false
var jet_fuel_ms: float = 0
var wing_flaps := 0
var speed_burst_end: float = -1
var shield_end: float = -1
var projectiles: Array = []
var pending_blocks: Array = []

# Blocks
var block_states := {}
var teleport_lists := {}
var map_min := Vector2.ZERO
var map_max := Vector2.ZERO
var map_bounds_dirty := true
var time_ms: float = 0 # PR3 setTimeout clock

# Links to PR4
var character: Character
var tiles: Tiles
var main_map: TileMapLayer
var sub_maps: Array = []
var sub_maps_refresh := 0
var step_accumulator: float = 0
var initialized := false
var prev_display := Vector2.ZERO
var cur_display := Vector2.ZERO
var last_written_position := Vector2.ZERO
var last_written_velocity := Vector2.ZERO
var last_parent: Node
var carry_motion_on_sync := false # keep the character's speed and facing on the next sync

static var _vars_cache := {}


func _init(p_character: Character) -> void:
	character = p_character


# ---------------------------------------------------------------------------
# PR4 glue
# ---------------------------------------------------------------------------

func physics_tick(delta: float) -> void:
	tiles = character.tiles
	if not _bind_map():
		return
	if not initialized or _was_moved_externally():
		_sync_from_character()
	_absorb_external_velocity()

	step_accumulator += delta
	var steps := 0
	while step_accumulator >= STEP_TIME and steps < MAX_STEPS_PER_TICK:
		step_accumulator -= STEP_TIME
		steps += 1
		prev_display = cur_display
		_read_input()
		frame()
		cur_display = _display_position()
	if steps == MAX_STEPS_PER_TICK:
		step_accumulator = 0
	_write_to_character()


func invalidate(carry_motion: bool = false) -> void:
	initialized = false
	carry_motion_on_sync = carry_motion


var grounded: bool:
	get:
		return touching_ground


func is_charging_super_jump() -> bool:
	return charging_super_jump


func super_jump_charge() -> float:
	return clampf(super_jump_vel / MAX_SUPER_JUMP_VEL, 0, 1)


func _bind_map() -> bool:
	var layer := character.get_parent().get_parent() if character.get_parent() else null
	if not layer or not layer.has_node("TileMapLayer"):
		return false
	var tml := layer.get_node("TileMapLayer") as TileMapLayer
	if tml != main_map:
		main_map = tml
		sub_maps_refresh = 0
		map_bounds_dirty = true
		teleport_lists = {}
		initialized = false
	sub_maps_refresh -= 1
	if sub_maps_refresh <= 0:
		sub_maps_refresh = 60
		sub_maps = []
		_collect_sub_maps(layer)
	return true


func _collect_sub_maps(node: Node) -> void:
	for child in node.get_children():
		if child is TileMapLayer and child != main_map:
			sub_maps.push_back(child)
		if child.get_child_count() > 0 and child.name != "Players":
			_collect_sub_maps(child)


func _was_moved_externally() -> bool:
	if character.get_parent() != last_parent:
		return true
	return character.position.distance_squared_to(last_written_position) > 0.0001


func _sync_from_character() -> void:
	if not initialized:
		_reset_motion_state()
		var relative := rad_to_deg(character.rotation - main_map.rotation)
		_set_rotation(round(relative / 90.0) * 90.0)
		target_rot = rotation
		_update_multipliers()
	# ActivePlayer.init: defaultGravity times the level's gravity
	gravity = DEFAULT_GRAVITY * GameConfig.level_gravity
	var p := _from_pr4(character.position)
	real_x = p.x
	real_y = p.y
	if not initialized or character.get_parent() != last_parent:
		safe_x = real_x
		safe_y = real_y
	if carry_motion_on_sync:
		carry_motion_on_sync = false
		_carry_motion_from_character()
	initialized = true
	last_parent = character.get_parent()
	cur_display = _display_position()
	prev_display = cur_display
	last_written_position = character.position
	last_written_velocity = character.velocity


## Switching physics mode: keep the speed and facing the player already had.
func _carry_motion_from_character() -> void:
	var level := main_map.transform.basis_xform_inv(character.velocity) / (PR4_PER_PR3 * 1000.0)
	var v := _rotate_point(level.x, level.y, rotation)
	vel_x = v.x
	vel_y = v.y
	facing_right = character.movement.facing >= 0
	# Keep the safe spot the last physics mode had.
	var safe := _from_pr4(character.tile_interaction.last_safe_position)
	safe_x = safe.x
	safe_y = safe.y


## The safe spot in PR4 space, for the next physics mode.
func export_safe_spot() -> void:
	if initialized and main_map:
		character.tile_interaction.last_safe_position = _to_pr4(Vector2(safe_x, safe_y))


func _reset_motion_state() -> void:
	vel_x = 0
	vel_y = 0
	touching_ground = false
	crouching = false
	swimming = false
	still_holding_up = false
	remaining_jump_vel = 0
	super_jump_vel = 0
	charging_super_jump = false
	rotating = false
	rotation_amplifier = 1
	step_accumulator = 0
	last_bump_key = ""


func _absorb_external_velocity() -> void:
	var dv := character.velocity - last_written_velocity
	if dv.length_squared() < 0.000001:
		return
	var level := main_map.transform.basis_xform_inv(dv) / (PR4_PER_PR3 * 1000.0)
	var player_frame := _rotate_point(level.x, level.y, rotation)
	vel_x += player_frame.x
	vel_y += player_frame.y
	last_written_velocity = character.velocity


func _write_to_character() -> void:
	var alpha := clampf(step_accumulator / STEP_TIME, 0, 1)
	character.position = prev_display.lerp(cur_display, alpha)
	var level_vel := _rotate_point(vel_x, vel_y, -rotation)
	character.velocity = main_map.transform.basis_xform(level_vel) * PR4_PER_PR3 * 1000.0
	last_written_position = character.position
	last_written_velocity = character.velocity
	last_parent = character.get_parent()

	var visual_rotation := main_map.rotation + deg_to_rad(rotation)
	character.rotation = visual_rotation
	character.up_direction = Vector2(0, -1).rotated(visual_rotation)
	character.gravity.rotation = visual_rotation
	character.gravity.target_rotation = visual_rotation
	character.gravity.gravity_rotated = character.gravity.gravity.rotated(visual_rotation)

	var movement := character.movement
	movement.facing = 1 if facing_right else -1
	movement.is_crouching = crouching
	movement.swimming = swimming
	movement.is_wall_sliding = false
	movement.previous_velocity = character.velocity
	movement.last_velocity = character.velocity


## Flash display x/y are stored in twips.
func _display_position() -> Vector2:
	return _to_pr4(Vector2(_twip(real_x), _twip(real_y)))


func _mark_discontinuity() -> void:
	cur_display = _display_position()
	prev_display = cur_display


func _read_input() -> void:
	input.up = Input.is_action_pressed("jump")
	input.down = Input.is_action_pressed("down")
	input.left = Input.is_action_pressed("left")
	input.right = Input.is_action_pressed("right")
	input.space = Input.is_action_pressed("item") and not hurt


func _to_pr4(p: Vector2) -> Vector2:
	return main_map.transform * (p * PR4_PER_PR3)


func _from_pr4(p: Vector2) -> Vector2:
	return (main_map.transform.affine_inverse() * p) / PR4_PER_PR3


# ---------------------------------------------------------------------------
# One PR3 frame: items (ENTER_FRAME), then LocalPlayer.step
# ---------------------------------------------------------------------------

func frame() -> void:
	_advance_pose()
	_sync_held_item()
	_sync_status_from_pr4()
	if input.space:
		_try_to_use_item()
	_item_frame(STEP_MS)
	_update_projectiles()
	step(STEP_MS)
	_update_blocks(STEP_MS)
	time_ms += STEP_MS
	_sync_status_to_pr4()


## LocalPlayer.step, then ActivePlayer.step.
func step(ms: float) -> void:
	got_an_item = false
	if hurt and hurt_timer <= 0:
		hurt_timer = 0
		hurt = false
	if map_bounds_dirty:
		_update_map_bounds()
	var dx := _twip(real_x)
	var dy := _twip(real_y)
	if dx > map_max.x + FALL_TOLERANCE or dx < map_min.x - FALL_TOLERANCE \
			or dy > map_max.y + FALL_TOLERANCE \
			or (dy < map_min.y - FALL_TOLERANCE and rotation != 0):
		_goto_safe_position()
	_active_step(ms)
	if not got_an_item and not got_item_keys.is_empty():
		got_item_keys = []
	if swimming and not touching_ground:
		var block = _get_block(_twip(real_x), _twip(real_y))
		if block != null and _vars(block).type == T_WATER:
			_mark_safe_block(block, "top")


func _active_step(ms: float) -> void:
	if not attempting_bump:
		last_bump_key = ""
	attempting_bump = false
	if hurt:
		hurt_timer -= ms
	recovery_timer -= ms
	var vel_level := float(character.stats.speed)
	var accel_level := float(character.stats.accel)
	var jump_level := float(character.stats.jump)
	use_shifted_vel = true
	var gravity_add: float = 0

	if rotating:
		var change := _shortest_rot_change(target_rot, rotation)
		if change > 1 * rotation_amplifier:
			_set_rotation(rotation + 0.054 * rotation_amplifier * ms)
		elif change < -(1 * rotation_amplifier):
			_set_rotation(rotation - 0.054 * rotation_amplifier * ms)
		else:
			_set_rotation(target_rot)
			rotating = false
			rotation_amplifier = 1
			_update_multipliers()
		return

	var accel := (0.00005 + accel_level * 0.000018) * item_accel_boost
	var max_speed := 0.1 + arrow_max_speed_boost + speed_burst_speed_boost + vel_level * 0.002
	var target_vel: float = 0
	if on_ice:
		accel *= 0.2
	if iced and touching_ground:
		accel *= 0.4
	if crouching:
		accel *= 0.5
		max_speed *= 0.5
	if not hurt and not iced:
		if input.left:
			facing_right = false
			if not charging_super_jump:
				target_vel = -max_speed
		if input.right:
			facing_right = true
			if not charging_super_jump:
				target_vel = max_speed
		if input.up:
			if touching_ground or vel_y > 0:
				still_holding_up = false
			if swimming and not touching_ground:
				gravity_add -= 0.0024242
				still_holding_up = false
			elif (touching_ground and not crouching) or still_holding_up:
				if not still_holding_up:
					still_holding_up = true
					remaining_jump_vel = 0.25 + jump_level * 0.0037
					_play_sound(JUMP_SOUND)
				if still_holding_up:
					var jump := remaining_jump_vel * (1 - pow(1 - 10.0 / 27.0, 27 * ms / 1000))
					jump = clampf(jump, 0, remaining_jump_vel)
					remaining_jump_vel -= jump
					gravity_add -= jump / ms
		else:
			still_holding_up = false
		if input.down and not input.up:
			if touching_ground and not crouching:
				_charge_super_jump(ms)
			gravity_add += 0.001515
		else:
			if charging_super_jump:
				vel_y = -super_jump_vel
				gravity_add = 0
				still_holding_up = false
				_play_sound(SUPER_JUMP_SOUND)
			super_jump_vel = 0
			charging_super_jump = false
	if hurt:
		accel = accel / 100 if not touching_ground else accel / 2
	if vel_x > target_vel:
		accel *= -1
	var dv := accel * ms
	var diff := vel_x - target_vel
	if absf(dv) > absf(diff):
		var scale := absf(diff) / absf(dv)
		dv *= scale
		accel *= scale
	if swimming:
		gravity_add += gravity / 2
	else:
		gravity_add += gravity
	if swimming:
		gravity_add *= 0.5
	vel_x = clampf(vel_x, -1, 1)
	vel_y = clampf(vel_y, -1, 1)
	move_x = vel_x * ms + 0.5 * (accel * (ms * ms))
	vel_x += dv
	move_y = vel_y * ms + 0.5 * (gravity_add * (ms * ms))
	vel_y += gravity_add * ms
	if swimming:
		vel_x *= pow(0.9, 27 * ms / 1000)
		vel_y *= pow(0.9, 27 * ms / 1000)
		move_x = move_x * 0.75
		move_y = move_y * 0.75
	var rm := _rotate_point(move_x, move_y, -rotation)
	rotated_move_x = rm.x
	rotated_move_y = rm.y
	var rv := _rotate_point(vel_x, vel_y, -rotation)
	rotated_vel_x = rv.x
	rotated_vel_y = rv.y
	if _is_sideways():
		shifted_x = real_y
		shifted_y = real_x
		shifted_move_x = rotated_move_y
		shifted_move_y = rotated_move_x
		shifted_vel_x = rotated_vel_y
		shifted_vel_y = rotated_vel_x
	else:
		shifted_x = real_x
		shifted_y = real_y
		shifted_move_x = rotated_move_x
		shifted_move_y = rotated_move_y
		shifted_vel_x = rotated_vel_x
		shifted_vel_y = rotated_vel_y
	_test_blocks(ms)
	_determine_state(ms)
	if use_shifted_vel:
		if _is_sideways():
			real_y = shifted_x
			real_x = shifted_y
			rotated_move_x = shifted_move_y
			rotated_move_y = shifted_move_x
			rotated_vel_x = shifted_vel_y
			rotated_vel_y = shifted_vel_x
		else:
			real_x = shifted_x
			real_y = shifted_y
			rotated_move_x = shifted_move_x
			rotated_move_y = shifted_move_y
			rotated_vel_x = shifted_vel_x
			rotated_vel_y = shifted_vel_y
		var v := _rotate_point(rotated_vel_x, rotated_vel_y, rotation)
		vel_x = v.x
		vel_y = v.y
		real_x += clampf(rotated_move_x, -MAX_MOVE_PER_FRAME, MAX_MOVE_PER_FRAME)
		real_y += clampf(rotated_move_y, -MAX_MOVE_PER_FRAME, MAX_MOVE_PER_FRAME)


func _is_sideways() -> bool:
	return rotation == 90 or rotation == 270 or rotation == -90


func _update_multipliers() -> void:
	multiplier_y = -1 if rotation == 90 or rotation == -180 or rotation == 180 else 1
	multiplier_x = -1 if rotation == -90 or rotation == -180 or rotation == 180 else 1


func _charge_super_jump(ms: float) -> void:
	super_jump_vel += 0.000303 * ms
	if super_jump_vel > CHARGE_SJ_THRESHOLD:
		charging_super_jump = true
	if super_jump_vel > MAX_SUPER_JUMP_VEL:
		super_jump_vel = MAX_SUPER_JUMP_VEL


## The parts of determineState that change physics or where items are held.
func _determine_state(_ms: float) -> void:
	if input.up:
		jumped_time += 1
	else:
		jumped_time = 0
	if hurt:
		_set_pose("hurt" if hurt_timer > 495 else "recover")
	elif iced:
		_set_pose("stand")
	else:
		if not touching_ground:
			super_jump_vel = 0
			_set_pose("swim" if swimming else "jump")
		elif charging_super_jump:
			_set_pose("chargeJump")
		elif input.left or input.right:
			_set_pose("crawl" if crouching else "run")
		elif crouching:
			_set_pose("crouch")
		else:
			_set_pose("stand")
		if pose == "chargeJump":
			var charge_frame := int(ceil(super_jump_vel / MAX_SUPER_JUMP_VEL * 100))
			if charge_frame == 100:
				if pose_frame < charge_frame:
					pose_frame = 100
					pose_playing = true
			else:
				pose_frame = clampi(charge_frame, 1, 122)
				pose_playing = false


## Player.setState: a new animation starts on its first frame.
func _set_pose(new_pose: String) -> void:
	if new_pose != pose:
		pose = new_pose
		pose_frame = 1
		pose_playing = false


## Flash moves every animation on a frame before ENTER_FRAME code runs.
func _advance_pose() -> void:
	match pose:
		"run":
			pose_frame += 1
			if pose_frame == 21: # frame 21's script: gotoAndPlay(1)
				pose_frame = 1
		"jump":
			pose_frame = mini(pose_frame + 1, 50) # stops on frame 50
		"crawl", "swim":
			pose_frame = pose_frame % 13 + 1
		"chargeJump":
			if pose_playing:
				pose_frame = mini(pose_frame + 1, 122)


# ---------------------------------------------------------------------------
# testBlocks
# ---------------------------------------------------------------------------

func _test_blocks(ms: float) -> void:
	aborted = false
	touching_ground = false
	crouching = false
	on_ice = false
	arrow_max_speed_boost = 0
	var rot := -rotation
	var mx := multiplier_x
	var my := multiplier_y
	var future_x := (shifted_x + move_x * mx) * mx
	var future_y := (shifted_y + move_y * my) * my
	var bottom_left = _probe(-BLOCK, BLOCK, rot)
	var bottom_center = _probe(0, BLOCK, rot)
	var bottom_right = _probe(BLOCK, BLOCK, rot)
	var lower_left = _probe(-BLOCK, 0, rot)
	var lower_right = _probe(BLOCK, 0, rot)
	var mid_left = _probe(-BLOCK, -BLOCK, rot)
	var mid_center = _probe(0, -BLOCK, rot)
	var mid_right = _probe(BLOCK, -BLOCK, rot)
	var high_left = _probe(-BLOCK, -BLOCK * 2, rot)
	var high_center = _probe(0, -BLOCK * 2, rot)
	var high_right = _probe(BLOCK, -BLOCK * 2, rot)
	var boundary: float

	if move_y < 0 and not _can_pass(mid_center, "bottom"):
		shifted_move_y = 2 * my
		shifted_vel_y = 0.1 * my
	if move_y >= 0:
		var temp_bottom = bottom_center
		if _can_pass(bottom_center, "top"):
			if not _can_pass(bottom_right, "top") and _can_pass(lower_right, "left"):
				boundary = _boundary(bottom_right, "left")
				if future_x + HIT_WIDTH >= boundary * mx:
					temp_bottom = bottom_right
			if not _can_pass(bottom_left, "top") and _can_pass(lower_left, "right"):
				boundary = _boundary(bottom_left, "right")
				if future_x - HIT_WIDTH <= boundary * mx:
					temp_bottom = bottom_left
		if not _can_pass(temp_bottom, "top"):
			boundary = _boundary(temp_bottom, "top")
			if future_y >= boundary * my:
				_touch_block(temp_bottom, "top", ms)
			elif gravity == 0 and absf(future_y - boundary * my) <= 0.11:
				_touch_block(temp_bottom, "top", ms)
			if aborted:
				return
	if not _can_pass(mid_center, "bottom") and not _can_pass(bottom_center, "top") and move_y < 0:
		_touch_block(bottom_center, "top", ms)
		if aborted:
			return
	if touching_ground and not _can_pass(mid_center, "bottom"):
		crouching = true
		if input.up:
			_touch_block(mid_center, "bottom", ms)
			if aborted:
				return
			_touch_block(mid_center, "bump", ms)
			if aborted:
				return
	if move_x >= -1:
		var temp_right = lower_right
		if _can_pass(lower_right, "left") and _can_pass(mid_center, "bottom") \
				and not crouching and move_y < 0:
			temp_right = mid_right
		if not _can_pass(temp_right, "left"):
			boundary = _boundary(temp_right, "left")
			if future_x + HIT_WIDTH >= boundary * mx:
				_touch_block(temp_right, "left", ms)
				if aborted:
					return
	if move_x <= 1:
		var temp_left = lower_left
		if _can_pass(lower_left, "right") and _can_pass(mid_center, "bottom") \
				and not crouching and move_y < 0:
			temp_left = mid_left
		if not _can_pass(temp_left, "right"):
			boundary = _boundary(temp_left, "right")
			if future_x - HIT_WIDTH <= boundary * mx:
				_touch_block(temp_left, "right", ms)
				if aborted:
					return
	if move_y < 0:
		if crouching:
			rotated_move_y = 0
			vel_y = 0
		else:
			var temp_high = high_center
			if _can_pass(high_center, "bottom"):
				if not _can_pass(high_right, "bottom") and _can_pass(mid_right, "left") \
						and _can_pass(lower_right, "left"):
					boundary = _boundary(high_right, "left")
					if future_x + HIT_WIDTH >= boundary * mx:
						temp_high = high_right
				if not _can_pass(high_left, "bottom") and _can_pass(mid_left, "right") \
						and _can_pass(lower_left, "right"):
					boundary = _boundary(high_left, "right")
					if future_x - HIT_WIDTH <= boundary * mx:
						temp_high = high_left
			if not _can_pass(temp_high, "bottom"):
				boundary = _boundary(temp_high, "bottom")
				if (shifted_y - HIT_HEIGHT * my) * my + move_y <= boundary * my:
					_touch_block(temp_high, "bottom", ms)
					if aborted:
						return
					_touch_block(temp_high, "bump", ms)
					if aborted:
						return
	var lower_center = _get_block(real_x, real_y)
	if lower_center != null and _vars(lower_center).type == T_WATER:
		swimming = true
	else:
		swimming = false


func _probe(px: float, py: float, rot: float):
	var p := _rotate_point(px, py, rot)
	return _get_active_block(real_x + p.x, real_y + p.y)


func _can_pass(block, side: String) -> bool:
	return block == null or not _block_side_is_active(block, side)


func _block_side_is_active(block: Dictionary, side: String) -> bool:
	return _vars(block)[_rotate_side(side)] != S_INACTIVE


func _rotate_side(side: String) -> String:
	if side == "bump":
		return side
	return SIDES[_adjust_index_by_rotation(SIDES.find(side), rotation)]


static func _adjust_index_by_rotation(index: int, rot: float) -> int:
	var turns := rot / 90.0
	if turns < 0:
		turns = 4 + turns
	return int(fmod(index + turns, 4.0))


func _boundary(block: Dictionary, side: String) -> float:
	var pos: Vector2 = block.pos
	var edges := [pos.y, pos.x + BLOCK, pos.y + BLOCK, pos.x]
	return edges[_adjust_index_by_rotation(SIDES.find(side), rotation)]


# ---------------------------------------------------------------------------
# touchBlock (LocalPlayer override around ActivePlayer.touchBlock)
# ---------------------------------------------------------------------------

func _touch_block(block: Dictionary, side: String, ms: float) -> void:
	var fresh: bool = side != "bump" or block.key != last_bump_key
	_active_touch_block(block, side, ms)
	var vars := _vars(block)
	var side_type: String = vars[side] # LocalPlayer uses the unrotated side
	if not fresh:
		return
	var state := _state(block)
	if side_type == S_GIVE_ITEM:
		got_an_item = true
		if not block.key in got_item_keys:
			got_item_keys.push_back(block.key)
			_fire_pr4_event("bump", block)
	elif side_type == S_INC_STATS or side_type == S_DEC_STATS:
		if state.stat_supply > 0:
			state.stat_supply -= 1
			var sign := 1 if side_type == S_INC_STATS else -1
			var stats := character.stats
			stats.speed = int(clampf(stats.speed + 5 * sign, 0, 100))
			stats.accel = int(clampf(stats.accel + 5 * sign, 0, 100))
			stats.jump = int(clampf(stats.jump + 5 * sign, 0, 100))
			if state.stat_supply <= 0:
				_dull_out(block)
	elif side_type == S_INC_HEALTH or side_type == S_FINISH or side_type == S_PR4:
		_fire_pr4_event("bump" if side == "bump" else "any_side", block)
	elif side_type == S_EXPLODE:
		if not _is_removed(block):
			_be_hurt_by_block(block)
			_explode_block(block)
	elif side_type == S_SAFETY:
		_goto_safe_position()
		aborted = true
		return
	elif side_type == S_SHATTER:
		_shatter_block(block)
	elif side_type == S_TELEPORT:
		if _teleport(block, side):
			aborted = true
			return
	elif side_type == S_ROTATE_RIGHT:
		_set_target_rot(target_rot + 90)
	elif side_type == S_ROTATE_LEFT:
		_set_target_rot(target_rot - 90)
	if side == "top":
		if vars.type != T_MOVE and vars.type != T_WEAK and not _any_side_is(vars, [S_EXPLODE,
				S_VANISH, S_SAFETY, S_BE_PUSHED, S_CRUMBLE, S_SHATTER]):
			_mark_safe_block(block, "top")
		if vars.type == T_MOVE:
			_fire_pr4_event("stand", block)


func _active_touch_block(block: Dictionary, side: String, _ms: float) -> void:
	var rotated_side := _rotate_side(side)
	var vars := _vars(block)
	var side_type: String = vars[rotated_side]
	if side_type in PUSH_DIRECTIONS:
		_block_tests(block, side)
		var index := _adjust_index_by_rotation(PUSH_DIRECTIONS.find(side_type), -rotation)
		var direction: String = PUSH_DIRECTIONS[index]
		var power: float = 1.0 # arrowPower
		# Block.activateArrow
		var arrow_dirs := {S_PUSH_UP: Vector2.UP, S_PUSH_DOWN: Vector2.DOWN,
				S_PUSH_LEFT: Vector2.LEFT, S_PUSH_RIGHT: Vector2.RIGHT}
		Arrow.show_effect(block.tml, block.coords, arrow_dirs[side_type])
		var mx := multiplier_x
		var my := multiplier_y
		if direction == S_PUSH_UP:
			if side == "top":
				shifted_vel_y -= 0.3 * my * power
			elif side == "bottom":
				if not input.down:
					shifted_vel_y = -0.35 * my * power
			else:
				shifted_vel_y -= 0.04 * my * power
		elif direction == S_PUSH_DOWN:
			shifted_vel_y += 0.1 * my * power
		elif direction == S_PUSH_LEFT:
			shifted_vel_x -= 0.075 * mx * power
			arrow_max_speed_boost = 0.5
		elif direction == S_PUSH_RIGHT:
			shifted_vel_x += 0.075 * mx * power
			arrow_max_speed_boost = 0.5
	elif side_type == S_BOUNCE:
		var bounce_x: float = 0
		var bounce_y: float = 0
		if side == "left" or side == "right":
			bounce_x = shifted_vel_x * -1 * 1.0
		else:
			bounce_y = shifted_vel_y * -1 * 1.0
		_block_tests(block, side)
		shifted_vel_x += bounce_x
		shifted_vel_y += bounce_y
	elif side_type == S_CRUMBLE or vars.type == T_WEAK:
		var force: float
		if side == "top" or side == "bottom" or side == "bump":
			force = absf(vel_y * 0.75)
			shifted_vel_y *= 0.5
		else:
			force = absf(vel_x)
			shifted_vel_x *= 0.5
		var state := _state(block)
		if force > 0.07:
			state.health = int(state.health - force * 100) # Block.health is an int
			if state.health > 0:
				TileEffects.crumble(block.tml, block.coords)
		if state.health <= 0:
			_shatter_block(block)
		else:
			_block_tests(block, side)
	elif side_type == S_VANISH:
		_block_tests(block, side)
		_start_fade_out(block)
	elif side_type == S_ICE:
		on_ice = true
		_block_tests(block, side)
	elif side_type == S_BE_PUSHED:
		_block_tests(block, side)
		_move_block(block, rotated_side, PUSH_COOLDOWN_MS, 1024)
	elif side_type == S_ROTATE_RIGHT or side_type == S_ROTATE_LEFT:
		rotation_amplifier = 1.0 # rotationSpeed
		_block_tests(block, side)
	else:
		_block_tests(block, side)


func _block_tests(block: Dictionary, side: String) -> void:
	var vars := _vars(block)
	if vars.type in [T_INACTIVE, T_WATER, T_START]:
		return
	var mx := multiplier_x
	var my := multiplier_y
	if side == "left":
		shifted_move_x = 0
		shifted_x = _boundary(block, "left") - (0.1 + HIT_WIDTH) * mx
		shifted_vel_x *= -0.25
	if side == "right":
		shifted_move_x = 0
		shifted_x = _boundary(block, "right") + (0.1 + HIT_WIDTH) * mx
		shifted_vel_x *= -0.25
	if side == "top":
		if hurt:
			if vel_y > 0:
				shifted_vel_y *= -0.5
		elif vel_y > 0:
			shifted_vel_y = 0
		touching_ground = true
		shifted_move_y = 0
		shifted_y = _boundary(block, "top") - 0.001 * my
	if side == "bottom":
		if not crouching:
			shifted_move_y = 0
			shifted_y = _boundary(block, "bottom") + (HIT_HEIGHT + 0.1) * my
			if vel_y < 0:
				shifted_vel_y = 0
			still_holding_up = false
	if side == "bump" and vars.bump != S_PUSH_UP:
		attempting_bump = true
		if last_bump_key != block.key:
			var hit := _rotate_point(0, -20, -rotation)
			_hit_block(block, hit.x, hit.y)
			TileEffects.bump(character, block.tml, block.coords)
			_play_sound(BUMP_SOUND)
			last_bump_key = block.key
			still_holding_up = false


static func _any_side_is(vars: Dictionary, types: Array) -> bool:
	for side in ["top", "bottom", "left", "right", "bump"]:
		if vars[side] in types:
			return true
	return false


# ---------------------------------------------------------------------------
# Player effects (hit, safe spots, rotation, teleport)
# ---------------------------------------------------------------------------

## LocalPlayer.beHurtByBlock: pushed away from the block's display position.
func _be_hurt_by_block(block: Dictionary, power: float = 0.3) -> void:
	var head := _rotate_point(0, -30, -rotation)
	var display: Vector2 = block.pos + _state(block).get("disp", Vector2.ZERO)
	var dx := _twip(real_x) + head.x - (display.x + 20)
	var dy := _twip(real_y) + head.y - (display.y + 20)
	var angle := atan2(dy, dx)
	var push := _rotate_point(cos(angle) * power, sin(angle) * power, rotation)
	hit(push.x, push.y)


## LocalPlayer.hit (no hats).
func hit(push_x: float, push_y: float, no_knockback: bool = false) -> void:
	if not no_knockback:
		vel_x = push_x
		vel_y = push_y
		shifted_vel_x = push_x
		shifted_vel_y = push_y
		use_shifted_vel = false
	if recovery_timer <= 0 and not shield and not character.invincibility.is_active():
		_set_hurt()


func _set_hurt() -> void:
	hurt = true
	iced = false
	_play_sound(BUMP_SOUND)
	recovery_timer = RECOVERY_MS
	hurt_timer = HURT_MS


func _mark_safe_block(block: Dictionary, side: String) -> void:
	var px: float = block.pos.x
	var py: float = block.pos.y
	var half := BLOCK / 2
	var spots := {}
	if rotation == 0:
		spots = {"top": [px + half, py - 20], "bottom": [px + half, py + 40],
				"left": [px - 20, py + half], "right": [px + 40, py + half]}
	elif rotation == -90:
		spots = {"top": [px - 20, py + half], "bottom": [px + 40, py + half],
				"left": [px + half, py + 40], "right": [px + half, py - 20]}
	elif rotation == 180 or rotation == -180:
		spots = {"top": [px + half, py + 20 + BLOCK], "bottom": [px + half, py - 40],
				"left": [px + 20 + BLOCK, py + half], "right": [px - 20, py + half]}
	elif rotation == 90:
		spots = {"top": [px + 20 + BLOCK, py + half], "bottom": [px - 40, py + half],
				"left": [px + half, py - 20], "right": [px + half, py + 40]}
	if spots.has(side):
		safe_x = spots[side][0]
		safe_y = spots[side][1]


func _goto_safe_position() -> void:
	shifted_x = safe_x
	real_x = safe_x
	shifted_y = safe_y
	real_y = safe_y
	vel_x = 0
	vel_y = 0.01
	use_shifted_vel = false
	_mark_discontinuity()


## setVariable("rot", value)
func _set_target_rot(value: float) -> void:
	target_rot = fmod(value, 360.0)
	rotating = true


## LocalPlayer's teleport block handling. Returns true if the player moved.
func _teleport(block: Dictionary, side: String) -> bool:
	var list := _teleport_list(block)
	var state := _state(block)
	if list.is_empty() or not state.get("teleport_active", true):
		return false
	var index := list.find(block.coords)
	index = 0 if index + 1 == list.size() else index + 1
	var dest_coords: Vector2i = list[index]
	var dest = _main_block(dest_coords)
	if dest == null:
		return false
	if side == "bump":
		if rotation == 0:
			side = "bottom"
		elif rotation == 180 or rotation == -180:
			side = "top"
		elif rotation == 90 or rotation == -270:
			side = "right"
		elif rotation == -90 or rotation == 270:
			side = "left"
	var mx := multiplier_x
	var my := multiplier_y
	var half := BLOCK / 2
	if side == "left":
		shifted_x = _boundary(dest, "left") - half * mx
		shifted_y = _boundary(dest, "top") + half * my
	elif side == "right":
		shifted_x = _boundary(dest, "right") + half * mx
		shifted_y = _boundary(dest, "top") + half * my
	elif side == "top":
		shifted_x = _boundary(dest, "left") + half * mx
		shifted_y = _boundary(dest, "top") - half * my
	elif side == "bottom":
		shifted_x = _boundary(dest, "left") + half * mx
		shifted_y = _boundary(dest, "bottom") + half * my
	shifted_vel_x = 0
	shifted_vel_y = 0
	shifted_move_x = 0
	shifted_move_y = 0
	_deactivate_teleport(dest)
	_deactivate_teleport(block)
	still_holding_up = false
	_mark_discontinuity_after_step()
	return true


## Every block with the same id, in level order (GamePage.teleportArrays).
func _teleport_list(block: Dictionary) -> Array:
	if not block.main:
		return []
	if not teleport_lists.has(block.id):
		var list := []
		for coords in main_map.get_used_cells():
			if _cell_id(main_map, coords) == block.id:
				list.push_back(coords)
		list.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
		teleport_lists[block.id] = list
	return teleport_lists[block.id]


func _deactivate_teleport(block: Dictionary) -> void:
	var state := _state(block)
	state.teleport_active = false
	state.teleport_reactivate = time_ms + TELEPORT_COOLDOWN_MS
	_dull_out(block)


var _jump_display := false


func _mark_discontinuity_after_step() -> void:
	_jump_display = true


# ---------------------------------------------------------------------------
# Blocks
# ---------------------------------------------------------------------------

## PR3 settings for a PR4 block id (BlockManager.createDefaultBlocks).
func _vars(block: Dictionary) -> Dictionary:
	var id: int = block.id
	if _vars_cache.has(id):
		return _vars_cache[id]
	var v := {"type": T_ACTIVE, "top": S_ACTIVE, "bottom": S_ACTIVE, "left": S_ACTIVE,
			"right": S_ACTIVE, "bump": S_ACTIVE}
	var all := func(side_type: String) -> void:
		for side in ["top", "bottom", "left", "right", "bump"]:
			v[side] = side_type
	match id:
		1, 2, 3, 4, 15, 30, 14:
			pass
		5:
			v.bump = S_SHATTER
		6:
			all.call(S_PUSH_DOWN)
		7:
			all.call(S_PUSH_UP)
		8:
			all.call(S_PUSH_LEFT)
		9:
			all.call(S_PUSH_RIGHT)
		10:
			all.call(S_EXPLODE)
		11, 26:
			v.bump = S_GIVE_ITEM
		12:
			v.type = T_START
		13:
			for side in ["top", "bottom", "left", "right"]:
				v[side] = S_BOUNCE
		16:
			for side in ["top", "bottom", "left", "right"]:
				v[side] = S_ICE
		17:
			v.type = T_IMPERVIOUS
			v.bump = S_FINISH
		18:
			all.call(S_CRUMBLE)
		19:
			all.call(S_VANISH)
		20:
			v.type = T_MOVE
		21:
			v.type = T_WATER
		22:
			v.bump = S_ROTATE_RIGHT # PR4's clockwise block
		23:
			v.bump = S_ROTATE_LEFT
		24:
			for side in ["top", "bottom", "left", "right"]:
				v[side] = S_BE_PUSHED
		25:
			for side in ["top", "bottom", "left", "right"]:
				v[side] = S_SAFETY
		27:
			v.bump = S_INC_STATS
		28:
			v.bump = S_DEC_STATS
		29:
			v.bump = S_INC_HEALTH
		32, 33, 34:
			all.call(S_TELEPORT)
		_:
			if tiles and tiles.is_solid(id):
				v.bump = S_PR4
			else:
				v.type = T_INACTIVE
	_vars_cache[id] = v
	return v


func _is_active(block: Dictionary) -> bool:
	var vars := _vars(block)
	if vars.type in [T_INACTIVE, T_WATER, T_START]:
		return false
	return not _is_removed(block) and _state_value(block, "active", true)


func _get_active_block(px: float, py: float):
	var block = _get_block(px, py)
	if block != null and not _is_active(block):
		return null
	return block


## BlockMapLayer.getBlockAtPos, plus blocks on PR4's moving tile maps.
func _get_block(px: float, py: float):
	var block = _main_block(Vector2i(int(floor(px / BLOCK)), int(floor(py / BLOCK))))
	if block != null:
		return block
	return _sub_block_at(Vector2(px, py))


func _main_block(tile: Vector2i):
	var id := _cell_id(main_map, tile)
	if id == 0:
		return null
	return {"tml": main_map, "coords": tile, "id": id, "main": true,
			"pos": Vector2(tile) * BLOCK, "key": _state_key(main_map, tile)}


func _sub_block_at(level: Vector2):
	if sub_maps.is_empty():
		return null
	var layer_point: Vector2 = main_map.transform * (level * PR4_PER_PR3)
	var players := main_map.get_parent().get_node("Players")
	for tml in sub_maps:
		if not is_instance_valid(tml):
			continue
		var coords: Vector2i = tml.local_to_map(tml.to_local(players.to_global(layer_point)))
		var id := _cell_id(tml, coords)
		if id == 0:
			continue
		var half := Vector2(Settings.tile_size_half)
		var center: Vector2 = tml.map_to_local(coords)
		var top_left := Vector2(INF, INF)
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var g: Vector2 = players.to_local(tml.to_global(center + half * corner))
			var c := (main_map.transform.affine_inverse() * g) / PR4_PER_PR3
			top_left = Vector2(minf(top_left.x, c.x), minf(top_left.y, c.y))
		return {"tml": tml, "coords": coords, "id": id, "main": false, "pos": top_left,
				"key": _state_key(tml, coords)}
	return null


func _cell_id(tml: TileMapLayer, coords: Vector2i) -> int:
	if tml.get_cell_source_id(coords) == -1:
		return 0
	return CoordinateUtils.to_block_id(tml.get_cell_atlas_coords(coords))


func _state_key(tml: TileMapLayer, coords: Vector2i) -> String:
	return str(tml.get_instance_id()) + ":" + str(coords.x) + "," + str(coords.y)


func _state(block: Dictionary) -> Dictionary:
	if not block_states.has(block.key):
		block_states[block.key] = {"tml": block.tml, "coords": block.coords, "main": block.main,
				"pos": block.pos, "health": 100, "stat_supply": 1}
	return block_states[block.key]


func _state_value(block: Dictionary, field: String, default):
	if not block_states.has(block.key):
		return default
	return block_states[block.key].get(field, default)


func _is_removed(block: Dictionary) -> bool:
	var tml: TileMapLayer = block.tml
	return tml.get_cell_source_id(block.coords) == -1 or _cell_id(tml, block.coords) != block.id


## Block.hit: the display wobbles back to the block's spot.
func _hit_block(block: Dictionary, hx: float, hy: float) -> void:
	var state := _state(block)
	state.bump_vel = Vector2(hx, hy)
	if not state.has("disp"):
		state.disp = Vector2.ZERO


func _shatter_block(block: Dictionary) -> void:
	if _is_removed(block):
		return
	TileEffects.shatter(block.tml, block.coords)
	block_states.erase(block.key)


## GamePage.explodeBlock: impervious blocks stay.
func _explode_block(block: Dictionary) -> void:
	var effect := EXPLODE_EFFECT.instantiate()
	effect.position = Vector2(block.coords * Settings.tile_size) + Vector2(Settings.tile_size_half)
	block.tml.add_child(effect)
	if _vars(block).type != T_IMPERVIOUS:
		_shatter_block(block)


## Block.startFadeOut
func _start_fade_out(block: Dictionary) -> void:
	var state := _state(block)
	if not state.has("alpha"):
		state.alpha = 1.0
	state.fade = "out"


func _dull_out(block: Dictionary) -> void:
	var tml: TileMapLayer = block.tml
	if _is_removed(block):
		return
	var alt := tml.get_cell_alternative_tile(block.coords)
	if alt == Tile.VISIBLE_ALT_ID or alt == Tile.INVISIBLE_ALT_ID: # hidden while it bumps
		var dull := Tile.DEACTIVATED_ALT_ID if alt == Tile.VISIBLE_ALT_ID \
				else Tile.INVISIBLE_DEACTIVATED_ALT_ID
		tml.set_cell(block.coords, 0, tml.get_cell_atlas_coords(block.coords), dull)


func _un_dull_out(state: Dictionary) -> void:
	var tml: TileMapLayer = state.tml
	if not is_instance_valid(tml) or tml.get_cell_source_id(state.coords) == -1:
		return
	if tml.get_cell_alternative_tile(state.coords) == Tile.DEACTIVATED_ALT_ID:
		tml.set_cell(state.coords, 0, tml.get_cell_atlas_coords(state.coords), Tile.VISIBLE_ALT_ID)


## Block.move: pushes the block one tile away from the touched side. Push
## blocks in the way get pushed first; anything else stops it.
func _move_block(block: Dictionary, side: String, cooldown_ms: float, pushable_left: int) -> bool:
	if side == "bump" or not block.main:
		return false
	var state := _state(block)
	if state.get("move_ready", 0.0) > time_ms:
		return false
	var delta := Vector2i.ZERO
	match side:
		"top":
			delta.y = 1
		"bottom":
			delta.y = -1
		"left":
			delta.x = 1
		"right":
			delta.x = -1
	var dest: Vector2i = block.coords + delta
	var moved := false
	var other = _main_block(dest)
	if other == null:
		moved = true
	elif pushable_left > 0 and _vars(other)[side] == S_BE_PUSHED:
		moved = _move_block(other, side, cooldown_ms, pushable_left - 1)
	if not moved:
		return false
	var atlas := main_map.get_cell_atlas_coords(block.coords)
	var alt := main_map.get_cell_alternative_tile(block.coords)
	main_map.set_cell(block.coords, -1)
	main_map.set_cell(dest, 0, atlas, alt)
	block_states.erase(block.key)
	state.coords = dest
	state.pos = Vector2(dest) * BLOCK
	if cooldown_ms > 0:
		state.move_ready = time_ms + cooldown_ms
	block_states[_state_key(main_map, dest)] = state
	_grow_map_bounds(Vector2(dest) * BLOCK)
	return true


## ENTER_FRAME work and setTimeout callbacks for blocks.
func _update_blocks(_ms: float) -> void:
	for key in block_states.keys():
		if not block_states.has(key):
			continue
		var state: Dictionary = block_states[key]
		# Block.bumpAnim (display in twips)
		if state.has("bump_vel"):
			var pos: Vector2 = state.pos
			var bv: Vector2 = state.bump_vel * 0.5
			var disp: Vector2 = pos + state.disp
			disp.y = _twip(disp.y + bv.y)
			disp.y = _twip(disp.y + (pos.y - disp.y) * 0.35)
			disp.x = _twip(disp.x + bv.x)
			disp.x = _twip(disp.x + (pos.x - disp.x) * 0.35)
			state.bump_vel = bv
			state.disp = disp - pos
			if absf(pos.x - disp.x) < 0.25 and absf(pos.y - disp.y) < 0.25:
				state.disp = Vector2.ZERO
				state.erase("bump_vel")
		# Block.fadeOut / fadeIn (Flash alpha steps of 1/256)
		var fade: String = state.get("fade", "")
		if fade == "out":
			state.alpha = _flash_alpha(state.alpha - 0.1)
			if state.alpha <= 0:
				state.alpha = 0.0
				state.active = false
				state.fade = ""
				state.fade_in_at = time_ms + VANISH_DISAPPEAR_MS
				_set_block_visible(state, false)
		elif fade == "in":
			state.alpha = _flash_alpha(state.alpha + 0.1)
			if state.alpha >= 1:
				state.alpha = 1.0
				state.fade = ""
		# Block.startFadeIn: waits while a player's feet are on the spot.
		if state.has("fade_in_at") and time_ms >= state.fade_in_at:
			state.erase("fade_in_at")
			var pos: Vector2 = state.pos
			var px := _twip(real_x)
			var py := _twip(real_y)
			var near := px > pos.x - 5 and px < pos.x + BLOCK + 5 \
					and py > pos.y - 5 and py < pos.y + BLOCK + 5
			if not near:
				state.alpha = 0.2
				state.fade = "in"
				state.active = true
				_set_block_visible(state, true)
			else:
				state.fade_in_at = time_ms + VANISH_RETRY_MS
		if state.has("alpha") and is_instance_valid(state.tml):
			var shown: float = state.alpha if state.get("active", true) else 0.0
			if state.get("drawn_alpha", -1.0) != shown:
				state.drawn_alpha = shown
				Vanish.show_fade(state.tml, state.coords, shown)
		if state.has("teleport_reactivate") and time_ms >= state.teleport_reactivate:
			state.erase("teleport_reactivate")
			state.teleport_active = true
			_un_dull_out(state)


static func _flash_alpha(value: float) -> float:
	return floor(value * 256.0) / 256.0


func _set_block_visible(state: Dictionary, visible: bool) -> void:
	var tml: TileMapLayer = state.tml
	if not is_instance_valid(tml) or tml.get_cell_source_id(state.coords) == -1:
		return
	var atlas := tml.get_cell_atlas_coords(state.coords)
	var alt := tml.get_cell_alternative_tile(state.coords)
	var active := alt == Tile.VISIBLE_ALT_ID or alt == Tile.INVISIBLE_ALT_ID
	var new_alt: int
	if visible:
		new_alt = Tile.VISIBLE_ALT_ID if active else Tile.DEACTIVATED_ALT_ID
	else:
		new_alt = Tile.INVISIBLE_ALT_ID if active else Tile.INVISIBLE_DEACTIVATED_ALT_ID
	tml.set_cell(state.coords, 0, atlas, new_alt)


func _update_map_bounds() -> void:
	map_bounds_dirty = false
	var rect := main_map.get_used_rect()
	map_min = Vector2(rect.position) * BLOCK
	map_max = Vector2(rect.end - Vector2i.ONE) * BLOCK


## BlockMapLayer.adjustBoundries
func _grow_map_bounds(pos: Vector2) -> void:
	if map_bounds_dirty:
		_update_map_bounds()
	map_max = Vector2(maxf(map_max.x, pos.x), maxf(map_max.y, pos.y))
	map_min = Vector2(minf(map_min.x, pos.x), minf(map_min.y, pos.y))


## Calls a PR4 tile behavior (items, finish, hearts...). If it moves the
## character, PR3 state follows.
func _fire_pr4_event(event: String, block: Dictionary) -> void:
	var before_position := character.position
	var before_parent := character.get_parent()
	character.velocity = Vector2.ZERO
	tiles.on(event, block.id, character, block.tml, block.coords)
	var pushed := character.velocity
	character.velocity = last_written_velocity
	if pushed != Vector2.ZERO:
		var level := main_map.transform.basis_xform_inv(pushed) / (PR4_PER_PR3 * 1000.0)
		var v := _rotate_point(level.x, level.y, rotation)
		vel_x += v.x
		vel_y += v.y
	if character.get_parent() != before_parent or character.position != before_position:
		_bind_map()
		var p := _from_pr4(character.position)
		shifted_x = p.y if _is_sideways() else p.x
		shifted_y = p.x if _is_sideways() else p.y
		shifted_move_x = 0
		shifted_move_y = 0
		_jump_display = true
		if character.get_parent() != before_parent:
			last_parent = character.get_parent()


# ---------------------------------------------------------------------------
# Items (PR3 com.jiggmin.pr3.items)
# ---------------------------------------------------------------------------

static func handles_item(id: int) -> bool:
	return id in [ITEM_ANGEL_WINGS, ITEM_JETPACK, ITEM_LASER_GUN, ITEM_PORTABLE_BLOCK,
			ITEM_PORTABLE_MINE, ITEM_ROCKET_LAUNCHER, ITEM_SHIELD, ITEM_SPEED_BURST,
			ITEM_SUPER_JUMP, ITEM_SWORD, ITEM_TELEPORT]


func _sync_held_item() -> void:
	var manager = character.item_manager
	var node = manager.item if manager else null
	if node == item_node:
		return
	_end_item_effects()
	item_node = node
	item_id = manager.item_id if node and handles_item(manager.item_id) else -1
	item_reload_until = -1
	item_reload_ms = 0
	item_uses = 1
	match item_id:
		ITEM_LASER_GUN:
			item_uses = 3
			item_reload_ms = 800
		ITEM_SWORD:
			item_uses = 3
			item_reload_ms = 500
		ITEM_ANGEL_WINGS:
			item_uses = 3
		ITEM_JETPACK:
			jet_fuel_ms = 6600
		ITEM_PORTABLE_BLOCK, ITEM_PORTABLE_MINE:
			var preview = node.get_node_or_null("VisualAid")
			if preview:
				preview.visible = false


## Item.tryToUseItem: runs every frame the item key is held.
func _try_to_use_item() -> void:
	if item_id == -1:
		return
	if item_id == ITEM_JETPACK:
		jet_using = true
		return
	if item_uses <= 0 or time_ms < item_reload_until:
		return
	match item_id:
		ITEM_SUPER_JUMP:
			if crouching:
				return
			_play_sound(SUPER_JUMP_SOUND)
			if vel_y > 0:
				vel_y = 0
			vel_y -= 0.7
			_use_item()
		ITEM_SPEED_BURST:
			if speed_burst_end < 0:
				speed_burst_end = time_ms + 6000
				item_accel_boost = 2
				speed_burst_speed_boost = 0.2
				character.speed_particles.emitting = true
		ITEM_SHIELD:
			if shield_end < 0:
				shield_end = time_ms + 10000
				shield = true
				character.shielded = true
		ITEM_ANGEL_WINGS:
			if wing_flaps == 0:
				wing_flaps = 15
				_item_visual("flap")
		ITEM_TELEPORT:
			var offset := _rotate_point(40.0 * 3 * _facing(), 0, -rotation)
			var target = _get_block(real_x + offset.x, real_y + offset.y)
			if target == null or not _is_active(target):
				real_x += offset.x
				real_y += offset.y
				_mark_discontinuity()
				_use_item()
		ITEM_LASER_GUN:
			_item_visual("shoot")
			vel_x += 0.15 if not facing_right else -0.15
			var point := _item_point()
			_use_item()
			_spawn_projectile(point, 29.0, 100, 0, 0)
		ITEM_ROCKET_LAUNCHER:
			_item_visual("shoot")
			vel_x += 0.4 if not facing_right else -0.4
			var point := _item_point(Vector2(29 * _facing(), -15))
			_use_item()
			_spawn_projectile(point, 14.5, 100, 1.0, 20.5)
		ITEM_SWORD:
			vel_x += 0.3 if facing_right else -0.3
			_item_visual("slash")
			_slash()
			_use_item()
		ITEM_PORTABLE_BLOCK, ITEM_PORTABLE_MINE:
			var point := _item_point()
			var target := Vector2(floor(point.x / BLOCK) * BLOCK + BLOCK / 2,
					floor(point.y / BLOCK) * BLOCK + BLOCK / 2)
			var existing = _get_block(target.x, target.y)
			if existing == null or not _is_active(existing):
				var id := B_MINE if item_id == ITEM_PORTABLE_MINE else B_CRUMBLE
				var tile := Vector2i(int(floor(target.x / BLOCK)), int(floor(target.y / BLOCK)))
				var effect: Node2D = (MINE_SPAWN_EFFECT if id == B_MINE else BLOCK_SPAWN_EFFECT).instantiate()
				effect.position = main_map.map_to_local(tile)
				main_map.add_child(effect)
				effect.get_node("AnimationTimer").stop() # PR3 timing places the block
				pending_blocks.push_back({"pos": target, "frames": PORTABLE_BLOCK_FRAMES, "id": id,
						"effect": effect})
				_use_item()


## Item.useItem: one use gone, then reload or drop the item.
func _use_item() -> void:
	item_uses -= 1
	if item_uses <= 0:
		_drop_item()
	elif item_reload_ms >= 0:
		item_reload_until = time_ms + item_reload_ms


## Per-frame item work (JetPack / AngelWings / SpeedBurst / Shield timers).
func _item_frame(ms: float) -> void:
	if item_id == ITEM_JETPACK:
		if jet_using:
			jet_using = false
			if not crouching:
				if vel_y < -0.25:
					vel_y -= 0.01 / 33 * ms
				elif vel_y <= 0:
					vel_y -= 0.022 / 33 * ms
				else:
					vel_y -= 0.04 / 33 * ms
			jet_fuel_ms -= ms
			if jet_fuel_ms <= 0:
				_use_item()
	if wing_flaps > 0:
		if vel_y > 0:
			vel_y = 0
		if vel_y > -0.5:
			vel_y -= 0.03
		vel_x += 0.06 if facing_right else -0.06
		wing_flaps -= 1
		if wing_flaps <= 0:
			_use_item()
	if speed_burst_end >= 0 and time_ms >= speed_burst_end:
		_use_item()
	if shield_end >= 0 and time_ms >= shield_end:
		_use_item()
	var still_pending := []
	for pending in pending_blocks:
		pending.frames -= 1
		if pending.frames > 0:
			still_pending.push_back(pending)
			continue
		if is_instance_valid(pending.get("effect")):
			pending.effect.queue_free()
		var tile := Vector2i(int(floor(pending.pos.x / BLOCK)), int(floor(pending.pos.y / BLOCK)))
		block_states.erase(_state_key(main_map, tile))
		main_map.set_cell(tile, 0, CoordinateUtils.to_atlas_coords(pending.id))
		_grow_map_bounds(Vector2(tile) * BLOCK)
	pending_blocks = still_pending


func _end_item_effects() -> void:
	if speed_burst_end >= 0:
		speed_burst_end = -1
		item_accel_boost = 1
		speed_burst_speed_boost = 0
		character.speed_particles.emitting = false
	if shield_end >= 0:
		shield_end = -1
		shield = false
		character.shielded = false
	wing_flaps = 0
	jet_using = false


func _drop_item() -> void:
	_end_item_effects()
	item_id = -1
	item_uses = 0
	if character.item_manager and character.item_manager.item:
		character.item_manager.remove_item()
	item_node = null


func _facing() -> float:
	return 1.0 if facing_right else -1.0


## Item.getItemPoint: the item holder in level space. "extra" is in the
## holder's own space, which the player's 0.4 scale shrinks.
func _item_point(extra: Vector2 = Vector2.ZERO) -> Vector2:
	var points: Array = ITEM_POINTS.get(pose, ITEM_POINTS.stand)
	var held: Vector2 = points[clampi(pose_frame - 1, 0, points.size() - 1)] + extra * 0.4
	var local := Vector2(held.x * _facing(), held.y)
	var offset := _rotate_point(local.x, local.y, -rotation)
	return Vector2(_twip(real_x) + offset.x, _twip(real_y) + offset.y)


## LaserEffect / RocketEffect: tested where it starts, then flies along the
## player's facing, up to 39px a check.
func _spawn_projectile(point: Vector2, speed: float, life: int, accel: float, max_vel: float) -> void:
	var shot := {"x": point.x, "y": point.y, "rot": rotation, "vel": speed * _facing(),
			"life": life, "accel": accel, "max_vel": max_vel, "dir": _facing(), "last": "",
			"slash": false}
	_projectile_test_point(shot, shot.x, shot.y)
	if not shot.get("removed", false):
		projectiles.push_back(shot)


## Sword: SlashEffect tests six points, then drifts 5px a frame for 5 frames.
func _slash() -> void:
	var point := _item_point()
	var shot := {"x": point.x, "y": point.y, "rot": rotation, "vel": 5.0 * _facing(),
			"life": 5, "accel": 0.0, "max_vel": 0.0, "dir": _facing(), "last": "", "slash": true}
	var space := 39.0 * _facing()
	for offset in [Vector2(0, 14), Vector2(0, -14), Vector2(space, 14), Vector2(space, -14),
			Vector2(space * 2, 14), Vector2(space * 2, -14)]:
		var p := _rotate_point(offset.x, offset.y, -shot.rot)
		_projectile_test_point(shot, shot.x + p.x, shot.y + p.y)
	projectiles.push_back(shot)


func _update_projectiles() -> void:
	var alive := []
	for shot in projectiles:
		shot.life -= 1
		if shot.life <= 0 or shot.get("removed", false):
			continue
		if shot.max_vel > 0:
			if absf(shot.vel) < shot.max_vel:
				shot.vel += shot.accel * shot.dir
			else:
				shot.vel = shot.max_vel * shot.dir
		var remaining := int(shot.vel)
		while remaining != 0:
			var move := int(clampf(remaining, -39, 39))
			var p := _rotate_point(move, 0, -shot.rot)
			if not _projectile_test_point(shot, shot.x + p.x, shot.y + p.y):
				shot.x += p.x
				shot.y += p.y
			if shot.get("removed", false):
				break
			remaining -= move
		if not shot.get("removed", false):
			alive.push_back(shot)
	projectiles = alive


## ProjectileEffect.testPoint for blocks. Returns true if it stopped on a block.
func _projectile_test_point(shot: Dictionary, px: float, py: float) -> bool:
	var block = _get_block(px, py)
	if block == null or block.key == shot.last or not _is_active(block):
		return false
	var vars := _vars(block)
	var v := _rotate_point(shot.vel, 0, -shot.rot)
	var start := Vector2(px - v.x * 25, py - v.y * 25)
	var tested := Vector2(px, py)
	var pos: Vector2 = block.pos
	var corners := [pos, pos + Vector2(BLOCK, 0), pos + Vector2(BLOCK, BLOCK), pos + Vector2(0, BLOCK)]
	var hit_side := ""
	var collision = null
	if shot.vel != 0:
		for edge in [["top", 0, 1], ["right", 1, 2], ["bottom", 3, 2], ["left", 0, 3]]:
			collision = _lines_intersect(start, tested, corners[edge[1]], corners[edge[2]])
			if collision != null:
				hit_side = edge[0]
				break
	else:
		hit_side = "right" if shot.dir > 0 else "left"
	var side_type: String = vars[hit_side] if hit_side != "" else ""
	shot.last = block.key
	var wobble := _rotate_point(20 * shot.dir, 0, -shot.rot)
	_hit_block(block, wobble.x, wobble.y)
	TileEffects.bump(character, block.tml, block.coords)
	if vars.bump == S_EXPLODE or side_type == S_EXPLODE:
		_explode_block(block)
	elif vars.bump in [S_SHATTER, S_CRUMBLE] or side_type in [S_SHATTER, S_CRUMBLE] \
			or vars.type == T_WEAK:
		_shatter_block(block)
	if not _is_removed(block):
		if side_type == S_BE_PUSHED:
			_move_block(block, hit_side, PUSH_COOLDOWN_MS, 1024)
		elif side_type == S_VANISH:
			_start_fade_out(block)
	if shot.slash:
		return false
	shot.removed = true
	if collision != null:
		shot.x = collision.x
		shot.y = collision.y
		return true
	return false


## Data.linesIntersect (as segments)
static func _lines_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2):
	var a1 := b.y - a.y
	var b1 := a.x - b.x
	var c1 := b.x * a.y - a.x * b.y
	var a2 := d.y - c.y
	var b2 := c.x - d.x
	var c2 := d.x * c.y - c.x * d.y
	var denom := a1 * b2 - a2 * b1
	if denom == 0:
		return null
	var p := Vector2((b1 * c2 - b2 * c1) / denom, (a2 * c1 - a1 * c2) / denom)
	if pow(p.x - b.x + (p.y - b.y), 2) > pow(a.x - b.x + (a.y - b.y), 2):
		return null
	if pow(p.x - a.x + (p.y - a.y), 2) > pow(a.x - b.x + (a.y - b.y), 2):
		return null
	if pow(p.x - d.x + (p.y - d.y), 2) > pow(c.x - d.x + (c.y - d.y), 2):
		return null
	if pow(p.x - c.x + (p.y - c.y), 2) > pow(c.x - d.x + (c.y - d.y), 2):
		return null
	return p


func _item_visual(effect: String) -> void:
	if not is_instance_valid(item_node) or not Game.game:
		return
	if item_node.get("animtimer"):
		item_node.animtimer.start()
	if item_node.has_method(effect):
		item_node.call(effect)


# ---------------------------------------------------------------------------
# PR4 status links
# ---------------------------------------------------------------------------

func _sync_status_from_pr4() -> void:
	var movement := character.movement
	# PR4 freezes (ice wave) count as PR3's "iced"; PR4's own timer runs here.
	if movement.frozen:
		movement.frozen_timer -= STEP_TIME
		if movement.frozen_timer <= 0:
			movement.frozen = false
			if movement.frozen_display_node:
				movement.frozen_display_node.visible = false
			character.display.modulate = Color(1, 1, 1)
	iced = movement.frozen
	if movement.hurt and not hurt and recovery_timer <= 0:
		_set_hurt()


func _sync_status_to_pr4() -> void:
	var movement := character.movement
	if hurt:
		if not movement.hurt:
			movement.hurt = true
			movement.hitstun_duration = HURT_MS / 1000.0
		movement.hitstun_timer = maxf(hurt_timer, 0) / 1000.0
	elif movement.hurt:
		movement.hurt = false
		movement.hitstun_timer = 0
	character.display.modulate.a = 1.0 if recovery_timer <= 0 \
			else (0.25 if fmod(recovery_timer, 200) >= 100 else 0.5)
	if _jump_display:
		_jump_display = false
		_mark_discontinuity()


func _play_sound(stream: AudioStream) -> void:
	if character.audioplayer:
		character.audioplayer.set_stream(stream)
		character.audioplayer.set_volume_db(1)
		character.audioplayer.play()


# ---------------------------------------------------------------------------
# Number helpers matching Flash
# ---------------------------------------------------------------------------

## PR3's Data.rotatePoint, with Maths.DEG_RAD = 0.0174533.
static func _rotate_point(px: float, py: float, rot: float) -> Vector2:
	var r := DEG_RAD * -rot
	return Vector2(px * cos(r) - py * sin(r), py * cos(r) + px * sin(r))


static func _shortest_rot_change(a: float, b: float) -> float:
	var change := a - b
	var minus := fmod(change - 360, 360.0)
	var plus := fmod(change + 360, 360.0)
	if absf(minus) < absf(change):
		change = minus
	if absf(plus) < absf(change):
		change = plus
	return change


## Flash keeps DisplayObject.rotation in (-180, 180].
func _set_rotation(value: float) -> void:
	value = fmod(value, 360.0)
	if value > 180:
		value -= 360
	elif value < -180:
		value += 360
	rotation = value


static func _twip(value: float) -> float:
	return floor(value * TWIPS_PER_PIXEL) / TWIPS_PER_PIXEL
