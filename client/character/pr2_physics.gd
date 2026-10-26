class_name Pr2Physics
## Platform Racing 2 player physics, used when a level turns on "pr2_physics".
##
## This is a line-by-line port of PR2's LocalPlayerController (the Haxe remake of
## Flash's LocalCharacter). It keeps PR2's point-probe tile collision, frame
## order, rounding and 30 fps step, so PR2 movement tricks and clips work the
## same way. Everything runs in PR2 units (30px tiles, pixels per frame) in the
## player's gravity frame, then gets converted to PR4 space for display.

const TILE := 30.0
const PR4_PER_PR2 := 128.0 / 30.0 # PR4 pixels per PR2 pixel
const VELOCITY_SCALE := 128.0 # PR4 px/s per PR2 px/frame (PR4_PER_PR2 * 30)
const STEP_TIME := 1.0 / 30.0
const MAX_STEPS_PER_TICK := 4

const STANDING_HEIGHT := 55.0
const HALF_WIDTH := 10.0
const BASE_ACCEL_FACTOR := 0.35
const FRICTION := 0.985
const MAX_SPEED := 28.0
const MAP_RETURN_MARGIN := 500.0
const DEFAULT_GRAVITY := 0.7
const MINE_HIT_SPEED := 50.0
const VELOCITY_ZERO_EPSILON := 1e-9
const TWIPS_PER_PIXEL := 20.0
const ROTATE_FRAMES := 30
const HURT_FRAMES := 60
const FROZEN_SOLID_FRAMES := 54
const CRUMBLE_INITIAL_LIFE := 10
const VANISH_FADE_FRAMES := 10
const VANISH_REAPPEAR_FRAMES := 54
const BOUNCE_BLOCK_MULTIPLIER := 1.1
const LASER_RECOIL := 15.0
const SWORD_LUNGE := 8.0
const SUPER_JUMP_ITEM_SPEED := 25.0
const TELEPORT_ITEM_DISTANCE := 120.0
const SPEED_BURST_FRAMES := 135
const JET_PACK_TOTAL_FUEL := 200
const FAST_ITEM_RELOAD_FRAMES := 22
const LASER_SHOT_SPEED := 29.0
const LASER_SHOT_FRAMES := 100
const SHOT_EFFECT_DEFAULT_SPEED := 5.0
const MINE_APPEAR_FRAMES := 33
# Where PR2 places a mine from: its weapon hand in the standing pose.
const MINE_HAND_OFFSET := Vector2(7.757170104980469, -23.49652557373047)
# Landing on a bounce block slower than this (in gravity steps) doesn't bounce,
# so walking across bounce blocks feels like PR4.
const BOUNCE_MIN_GRAVITY_STEPS := 1.5

# PR4 item ids that use PR2's item rules in PR2 physics mode.
const ITEM_JETPACK := 4
const ITEM_LASER_GUN := 5
const ITEM_PORTABLE_MINE := 8
const ITEM_SPEED_BURST := 11
const ITEM_SUPER_JUMP := 12
const ITEM_SWORD := 13
const ITEM_TELEPORT := 14

const MODE_LAND := "land"
const MODE_WATER := "water"
const MODE_PAUSE := "freeze"
const MODE_FROZEN_SOLID := "frozenSolid"
const MODE_HURT := "hurt"

# PR4 block ids. PR2 block codes map to these as (code - 99).
const B_BRICK := 5
const B_ARROW_DOWN := 6
const B_ARROW_LEFT := 8
const B_ARROW_RIGHT := 9
const B_MINE := 10
const B_BOUNCE := 13
const B_ICE := 16
const B_CRUMBLE := 18
const B_VANISH := 19
const B_MOVE := 20
const B_WATER := 21
const B_ROTATE_CW := 22 # PR2 "rotate left" (the importer swaps them)
const B_ROTATE_CCW := 23 # PR2 "rotate right"
const B_PUSH := 24
const B_SAFETY := 25
const B_TELEPORT_BLUE := 32
const B_TELEPORT_YELLOW := 34

const BUMP_SOUND := preload("res://sounds/BumpSound.ogg")
const JUMP_SOUND := preload("res://sounds/JumpSound.ogg")
const SUPER_JUMP_SOUND := preload("res://sounds/SuperJumpSound.ogg")
const EXPLODE_EFFECT := preload("res://tiles/mine/explode_effect.tscn")
const MINE_SPAWN_EFFECT := preload("res://item_effects/portable_mine.tscn")

# PR2 state, in PR2 pixels inside the gravity frame.
var x: float = 0
var y: float = 0
var vx: float = 0
var vy: float = 0
var grounded := false
var crouching := false
var mode := MODE_LAND
var target_vel_x: float = 0
var accel_factor: float = BASE_ACCEL_FACTOR
var jump_held := false
var jump_vel_boost: float = 0
var crouch_charge: float = 0
var water_ticks: float = 0
var hurt_frames_remaining := 0
var frozen_solid_frames_remaining := 0
var facing := 1
var course_rotation := 0
var rotate_frames_remaining := 0
var rotate_direction := 0
var course_tween_rotation := 0
var last_safe_x: float = 0
var last_safe_y: float = 0
var standing_tile_x := 0
var standing_tile_y := 0
var accel: float = 0
var max_vel_x: float = 0
var jump_velocity: float = 0
var gravity: float = DEFAULT_GRAVITY

# PR2 item state for the held item (see _use_held_item).
var item_node: Node
var item_id := -1
var item_uses := 0
var item_reload := 0
var item_reload_frames := 0
var item_available := false
var jet_pack_fuel := 0
var speed_burst_frames := 0
var laser_shots: Array = [] # in-flight shots that damage the first block they hit
var pending_mines: Array = [] # mines that appear MINE_APPEAR_FRAMES after use

# Per-block runtime state (crumble life, vanish timers, bump wobble).
var block_states := {}

# Links to PR4.
var character: Character
var tiles: Tiles
var main_map: TileMapLayer
var sub_maps: Array = []
var sub_maps_refresh := 0
var map_min := Vector2.ZERO
var map_max := Vector2.ZERO
var map_bounds_dirty := true # PR2 measures the level once, when it starts
var input := {"left": false, "right": false, "jump": false, "down": false, "item": false}
var step_accumulator: float = 0
var initialized := false
var prev_display := Vector2.ZERO
var cur_display := Vector2.ZERO
var last_written_position := Vector2.ZERO
var last_written_velocity := Vector2.ZERO
var last_parent: Node


static func is_enabled() -> bool:
	return bool(GameConfig.get_value("pr2_physics"))


func _init(p_character: Character) -> void:
	character = p_character


# ---------------------------------------------------------------------------
# PR4 glue
# ---------------------------------------------------------------------------

## Runs once per PR4 physics tick. Steps PR2 physics at 30 fps and smooths the
## displayed position between steps.
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
		step()
		cur_display = _display_position()
	if steps == MAX_STEPS_PER_TICK:
		step_accumulator = 0

	_write_to_character()


## Called when PR4 physics took over for a tick (lightbreak), so the next PR2
## tick starts from wherever PR4 left the character.
func invalidate() -> void:
	initialized = false


func is_charging_super_jump() -> bool:
	return crouch_charge > 25


func super_jump_charge() -> float:
	return clampf((crouch_charge - 25) / 75.0, 0, 1)


func _bind_map() -> bool:
	var layer := character.get_parent().get_parent() if character.get_parent() else null
	if not layer or not layer.has_node("TileMapLayer"):
		return false
	var tml := layer.get_node("TileMapLayer") as TileMapLayer
	if tml != main_map:
		main_map = tml
		sub_maps_refresh = 0
		map_bounds_dirty = true
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


## Rebuilds PR2 state from the character's PR4 position and rotation.
func _sync_from_character() -> void:
	if not initialized:
		_reset_motion_state()
		var relative := rad_to_deg(main_map.rotation - character.rotation)
		course_rotation = _normalize_rotation(int(round(relative / 90.0)) * 90)
	var g := _from_pr4(character.position)
	_set_player_pos(g.x, g.y)
	if not initialized:
		last_safe_x = x
		last_safe_y = y
		standing_tile_x = _tile_index(x)
		standing_tile_y = _tile_index(y)
	elif character.get_parent() != last_parent:
		last_safe_x = x
		last_safe_y = y
	initialized = true
	last_parent = character.get_parent()
	cur_display = _display_position()
	prev_display = cur_display
	last_written_position = character.position
	last_written_velocity = character.velocity


func _reset_motion_state() -> void:
	vx = 0
	vy = 0
	grounded = false
	crouching = false
	mode = MODE_LAND
	target_vel_x = 0
	accel_factor = BASE_ACCEL_FACTOR
	jump_held = false
	jump_vel_boost = 0
	crouch_charge = 0
	water_ticks = 0
	rotate_frames_remaining = 0
	rotate_direction = 0
	course_tween_rotation = 0
	step_accumulator = 0


## Items, mines and other PR4 code push the character by changing its velocity.
## Fold those changes into PR2 velocity.
func _absorb_external_velocity() -> void:
	var dv := character.velocity - last_written_velocity
	if dv.length_squared() < 0.000001:
		return
	var g := _vec_from_pr4(dv) / VELOCITY_SCALE
	vx += g.x
	vy += g.y
	last_written_velocity = character.velocity


func _write_to_character() -> void:
	var alpha := clampf(step_accumulator / STEP_TIME, 0, 1)
	character.position = prev_display.lerp(cur_display, alpha)
	character.velocity = _vec_to_pr4(Vector2(vx, vy)) * VELOCITY_SCALE
	last_written_position = character.position
	last_written_velocity = character.velocity
	last_parent = character.get_parent()

	var visual_rotation := main_map.rotation - deg_to_rad(course_rotation + course_tween_rotation)
	character.rotation = visual_rotation
	character.up_direction = Vector2(0, -1).rotated(visual_rotation)
	character.gravity.rotation = visual_rotation
	character.gravity.target_rotation = visual_rotation
	character.gravity.gravity_rotated = character.gravity.gravity.rotated(visual_rotation)

	var movement := character.movement
	movement.facing = facing
	movement.is_crouching = crouching
	movement.swimming = mode == MODE_WATER
	movement.is_wall_sliding = false
	movement.previous_velocity = character.velocity
	movement.last_velocity = character.velocity


func _display_position() -> Vector2:
	return _to_pr4(Vector2(x, y))


func _mark_discontinuity() -> void:
	cur_display = _display_position()
	prev_display = cur_display


func _read_input() -> void:
	input.left = Input.is_action_pressed("left")
	input.right = Input.is_action_pressed("right")
	input.jump = Input.is_action_pressed("jump")
	input.down = Input.is_action_pressed("down")
	input.item = Input.is_action_pressed("item")


func _read_stats() -> void:
	var stats := character.stats
	var speed_stat := clampf(stats.speed, 0, 100)
	var accel_stat := clampf(stats.accel, 0, 100)
	var jump_stat := clampf(stats.jump, 0, 100)
	max_vel_x = 2 + speed_stat / 10.0
	accel = 0.2 + accel_stat / 60.0
	jump_velocity = 2 + jump_stat / 40.0
	if speed_burst_frames > 0:
		accel *= 2
		max_vel_x *= 2
	gravity = DEFAULT_GRAVITY * float(GameConfig.get_value("pr2_gravity"))


# Gravity frame (PR2 px) <-> PR4 position in the character's parent space.
func _to_pr4(g: Vector2) -> Vector2:
	var c := _rotate_exact(g, course_rotation)
	return main_map.transform * (c * PR4_PER_PR2)


func _from_pr4(p: Vector2) -> Vector2:
	var c := (main_map.transform.affine_inverse() * p) / PR4_PER_PR2
	return _rotate_exact(c, -course_rotation)


func _vec_to_pr4(g: Vector2) -> Vector2:
	return main_map.transform.basis_xform(_rotate_exact(g, course_rotation))


func _vec_from_pr4(v: Vector2) -> Vector2:
	return _rotate_exact(main_map.transform.basis_xform_inv(v), -course_rotation)


# ---------------------------------------------------------------------------
# PR2 frame step (LocalPlayerController.step)
# ---------------------------------------------------------------------------

func step() -> void:
	_read_stats()
	_set_player_pos(_haxe_round(x), _haxe_round(y))
	if rotate_frames_remaining > 0:
		_update_rotation()
	hurt_frames_remaining -= 1
	var ready_mines := _tick_pending_mines()
	_update_laser_shots()
	_sync_held_item()
	if item_reload > 0:
		item_reload -= 1
	if input.right:
		facing = 1
	if input.left:
		facing = -1
	_sync_status_from_pr4()
	if mode != MODE_HURT:
		_use_held_item()

	if mode == MODE_PAUSE:
		pass
	elif mode == MODE_FROZEN_SOLID:
		_frozen_solid_step()
	elif mode == MODE_HURT:
		_hurt_step()
	elif mode == MODE_WATER:
		_water_step()
	else:
		_land_step()

	_update_speed_burst()
	_update_block_states()
	_place_mines(ready_mines)
	_sync_status_to_pr4()


func _land_step() -> void:
	if input.right:
		target_vel_x += accel
	if input.left:
		target_vel_x -= accel
	if not input.right and not input.left:
		target_vel_x = 0

	if input.jump:
		if grounded and not crouching:
			jump_held = true
			vy -= jump_velocity
			jump_vel_boost = -jump_velocity
			_play_sound(JUMP_SOUND)
		elif jump_held:
			vy += jump_vel_boost
			jump_vel_boost *= 0.75
	else:
		jump_held = false

	if input.down:
		if not crouching:
			if not grounded:
				vy += 0.5
				crouch_charge = 0
			else:
				if crouch_charge < 100:
					crouch_charge += 2
				if crouch_charge > 25:
					target_vel_x = 0
	else:
		if crouch_charge > 25:
			vy = -crouch_charge * 0.24
			jump_held = false
			_play_sound(SUPER_JUMP_SOUND)
		crouch_charge = 0

	_position()
	_process_blocks()


func _water_step() -> void:
	if input.right:
		vx += accel * 0.5
	if input.left:
		vx -= accel * 0.5
	if input.down:
		vy += accel * 0.65
	if input.jump:
		vy -= accel * 0.65
	vy += DEFAULT_GRAVITY * 0.25
	vx *= 0.92
	vy *= 0.92
	vx = clampf(vx, -MAX_SPEED, MAX_SPEED)
	vy = clampf(vy, -MAX_SPEED, MAX_SPEED)
	_move_player_by(vx, vy)
	_process_blocks()
	# Like PR2, this runs even if a rotate block paused physics this frame.
	water_ticks -= 1
	if water_ticks <= 0:
		if input.jump:
			vy -= jump_velocity * 0.5
			jump_vel_boost = -jump_velocity * 0.5
			jump_held = true
		_set_mode(MODE_LAND)


func _hurt_step() -> void:
	target_vel_x = 0
	_position()
	_process_blocks()
	if hurt_frames_remaining <= 0:
		_set_mode(MODE_LAND)


func _frozen_solid_step() -> void:
	target_vel_x = 0
	_position()
	_process_blocks()
	if input.jump and grounded and not crouching:
		vy -= jump_velocity
	frozen_solid_frames_remaining -= 1
	if frozen_solid_frames_remaining <= 0:
		_set_mode(MODE_LAND)


func _position() -> void:
	vy += gravity
	if absf(vy) < VELOCITY_ZERO_EPSILON:
		vy = 0
	var target := target_vel_x * FRICTION
	if crouching:
		target *= 0.7
	target_vel_x = clampf(target, -max_vel_x, max_vel_x)
	var velocity_ratio := 1 - absf(vx) / MAX_SPEED
	velocity_ratio = velocity_ratio * 0.9 + 0.1
	vx = clampf(vx + (target_vel_x - vx) * accel_factor * velocity_ratio, -MAX_SPEED, MAX_SPEED)
	vy = clampf(vy, -MAX_SPEED, MAX_SPEED)
	_move_player_by(vx, vy)
	if _is_past_map_return_boundary():
		_return_to_last_safe_spot()
	accel_factor = BASE_ACCEL_FACTOR


func _set_mode(new_mode: String) -> void:
	if mode != new_mode:
		mode = new_mode
		target_vel_x = 0


# ---------------------------------------------------------------------------
# Collision (LocalPlayerController.processBlocks)
# ---------------------------------------------------------------------------

func _process_blocks() -> void:
	var refs := _refresh_block_refs()
	if _update_grounded(refs):
		refs = _refresh_block_refs()

	if vx >= -1 and refs.wall_right and _get_block_left_of(refs.wall_right) == null:
		_on_left_hit(refs.wall_right)
		refs = _refresh_block_refs()
	if vx <= 1 and refs.wall_left and _get_block_right_of(refs.wall_left) == null:
		_on_right_hit(refs.wall_left)
		refs = _refresh_block_refs()

	if vy < 0:
		if grounded:
			crouching = true
		var bump_block = null if mode == MODE_WATER else _block_with_open_space_below(refs.ceiling)
		if bump_block == null and mode != MODE_WATER:
			bump_block = _block_with_open_space_below(refs.head_block)
		if bump_block == null:
			bump_block = _block_with_open_space_below(refs.top_block)
		if bump_block != null:
			_on_bump(bump_block)
			refs = _refresh_block_refs()

	if not grounded:
		if _update_grounded(refs):
			refs = _refresh_block_refs()

	crouching = false
	if grounded:
		var top_block = _get_block_at_pixel(x, y - 40)
		var body_block = _get_block_at_pixel(x, y - 10)
		if top_block != null and body_block == null:
			crouching = true
			if input.jump:
				var y_prior_to_bump := y
				_on_bump(top_block)
				if not _is_teleport(top_block.id):
					_set_player_y(y_prior_to_bump)
				vy = 0
			if vy < 0:
				vy = 0

	_touch_at(x, y - 15)
	if not crouching:
		_touch_at(x, y - 45)


func _refresh_block_refs() -> Dictionary:
	return {
		"floor_center": _get_block_at_pixel(x, y),
		"wall_left": _get_block_at_pixel(x - HALF_WIDTH, y - 10),
		"wall_right": _get_block_at_pixel(x + HALF_WIDTH, y - 10),
		"ceiling": _get_block_at_pixel(x, y - 30),
		"head_block": _get_block_at_pixel(x, y - STANDING_HEIGHT + 30),
		"top_block": _get_block_at_pixel(x, y - STANDING_HEIGHT),
	}


func _update_grounded(refs: Dictionary) -> bool:
	if refs.floor_center != null and refs.ceiling == null:
		_on_stand(refs.floor_center)
		return true
	grounded = false
	return false


func _touch_at(px: float, py: float) -> void:
	var block = _block_at_pixel_any(px, py)
	if block == null:
		return
	match block.id:
		B_MINE:
			_hit_mine(block)
		B_WATER:
			if not grounded and mode != MODE_PAUSE and mode != MODE_HURT:
				_set_mode(MODE_WATER)
				water_ticks = 2
			else:
				target_vel_x *= 0.9
				accel_factor = 0.1
			_update_safe_spot(block, true)
		B_SAFETY:
			if standing_tile_x != block.x or standing_tile_y < block.y \
					or standing_tile_y > block.y + 2:
				_return_to_last_safe_spot()


func _on_stand(block: Dictionary) -> void:
	var pre_vy := vy
	var stand_force := int(_haxe_round(vy * 2))
	if block.id == B_CRUMBLE:
		_apply_crumble_force(block, stand_force)
		if _is_block_removed(block):
			grounded = false
			return
	_set_player_y(_rotated_block_pos(block).y)
	vy = 0
	grounded = true
	if _is_safe_stand_block(block):
		_update_safe_spot(block, false)
	_apply_stand_effect(block, pre_vy)


func _on_bump(block: Dictionary) -> void:
	var pre_vy := vy
	var bump_force := int(_haxe_round(-vy))
	var pre_bump_y := y
	if block.id == B_CRUMBLE:
		_apply_crumble_force(block, bump_force)
		if _is_block_removed(block):
			return
	var bounce_offset := _block_bounce_offset(block)
	var height := STANDING_HEIGHT / 2 if crouching else STANDING_HEIGHT
	_set_player_y(_rotated_block_pos(block).y + bounce_offset.y + TILE + height)
	vy *= -0.25
	jump_vel_boost = 0
	if not _is_arrow(block.id):
		_start_block_bounce(block, 0, -15)
		TileEffects.bump(character, block.tml, block.coords)
		_play_sound(BUMP_SOUND)
	_apply_bump_effect(block, pre_bump_y, pre_vy)


func _on_left_hit(block: Dictionary) -> void:
	var pre_vx := vx
	var side_force := int(_haxe_round(absf(vx) * 1.75))
	if block.id == B_CRUMBLE:
		_apply_crumble_force(block, side_force)
		if _is_block_removed(block):
			return
	_set_player_x(_rotated_block_pos(block).x - HALF_WIDTH)
	if vx > 0:
		vx *= -0.05
	if target_vel_x > 0:
		target_vel_x = 0
	_apply_side_hit_effect(block, -1, pre_vx)


func _on_right_hit(block: Dictionary) -> void:
	var pre_vx := vx
	var side_force := int(_haxe_round(absf(vx) * 1.75))
	if block.id == B_CRUMBLE:
		_apply_crumble_force(block, side_force)
		if _is_block_removed(block):
			return
	_set_player_x(_rotated_block_pos(block).x + TILE + HALF_WIDTH)
	if vx < 0:
		vx *= -0.05
	if target_vel_x < 0:
		target_vel_x = 0
	_apply_side_hit_effect(block, 1, pre_vx)


# ---------------------------------------------------------------------------
# Block effects
# ---------------------------------------------------------------------------

func _apply_stand_effect(block: Dictionary, pre_vy: float) -> void:
	if _is_arrow(block.id):
		var rotation := _arrow_effective_rotation(block.id)
		if rotation == 0 and not crouching:
			vy -= 10
		else:
			_push_arrow(rotation)
		return
	match block.id:
		B_VANISH:
			_activate_vanish(block)
		B_MINE:
			_hit_mine(block)
		B_PUSH:
			_push_block(block, 0, 1)
		B_ICE:
			accel_factor = 0.05
		B_BOUNCE:
			if absf(pre_vy) > gravity * BOUNCE_MIN_GRAVITY_STEPS:
				vy = -absf(pre_vy) * BOUNCE_BLOCK_MULTIPLIER
				grounded = false
		B_MOVE:
			_fire_pr4_event("stand", block)
		_:
			if _is_teleport(block.id):
				_fire_pr4_event("any_side", block)


func _apply_bump_effect(block: Dictionary, pre_bump_y: float, pre_vy: float) -> void:
	if _is_arrow(block.id):
		var rotation := _arrow_effective_rotation(block.id)
		if rotation == 0:
			vy = -14 if not input.down and not crouching else 0
		else:
			_push_arrow(rotation)
		return
	match block.id:
		B_BRICK:
			_remove_block(block)
		B_VANISH:
			_activate_vanish(block)
		B_MINE:
			_hit_mine(block)
		B_PUSH:
			_push_block(block, 0, -1)
		B_ROTATE_CW:
			_start_rotate(block, -1)
		B_ROTATE_CCW:
			_start_rotate(block, 1)
		B_BOUNCE:
			vy = absf(pre_vy) * BOUNCE_BLOCK_MULTIPLIER
		_:
			if _is_teleport(block.id):
				if crouching:
					_set_player_y(pre_bump_y)
				_fire_pr4_event("any_side", block)
			else:
				# Finish, items, happy/sad, heart, mega/mini and other PR4 blocks.
				_fire_pr4_event("bump", block)


func _apply_side_hit_effect(block: Dictionary, player_tile_offset: int, pre_vx: float) -> void:
	if _is_arrow(block.id):
		_push_arrow(_arrow_effective_rotation(block.id))
		return
	match block.id:
		B_VANISH:
			_activate_vanish(block)
		B_MINE:
			_hit_mine(block)
		B_PUSH:
			_push_block(block, -player_tile_offset, 0)
		B_BOUNCE:
			vx = -pre_vx * BOUNCE_BLOCK_MULTIPLIER
		_:
			if _is_teleport(block.id):
				_fire_pr4_event("any_side", block)


func _push_arrow(rotation: int) -> void:
	if rotation == 0 and not crouching:
		vy -= 1.2
	if absi(rotation) == 180:
		vy += 5
	if rotation == -90:
		vx -= 3
	if rotation == 90:
		vx += 3


func _arrow_effective_rotation(id: int) -> int:
	var base := 0
	match id:
		B_ARROW_DOWN:
			base = 180
		B_ARROW_LEFT:
			base = -90
		B_ARROW_RIGHT:
			base = 90
	return _normalize_rotation(course_rotation + base)


func _hit_mine(block: Dictionary) -> void:
	if _is_block_removed(block):
		return
	var center: Vector2 = Vector2(block.x, block.y) * TILE + Vector2(TILE / 2, TILE / 2)
	# PR2 compares the unrotated mine position with the rotated player position,
	# which on a rotated course gives a direction that depends on where the
	# level sits. Rotating the mine into the player's frame keeps the blast
	# pointing away from the mine; unrotated courses are unchanged.
	center = _rotate_exact(center, -course_rotation)
	var angle := atan2((y - STANDING_HEIGHT / 2) - center.y, x - center.x)
	var invincible: bool = character.invincibility.is_active()
	if not invincible:
		vx += cos(angle) * MINE_HIT_SPEED
		vy += sin(angle) * MINE_HIT_SPEED
	var effect := EXPLODE_EFFECT.instantiate()
	effect.position = Vector2(block.coords * Settings.tile_size) + Vector2(Settings.tile_size_half)
	block.tml.add_child(effect)
	_remove_block(block)
	if mode != MODE_PAUSE and not invincible:
		_set_mode(MODE_HURT)
		_begin_hurt_recovery()


func _begin_hurt_recovery() -> void:
	if hurt_frames_remaining > 0:
		return
	hurt_frames_remaining = HURT_FRAMES


func _apply_crumble_force(block: Dictionary, force: int) -> void:
	if _is_block_removed(block):
		return
	var damage := int(floor(force / 4.0))
	if damage <= 0:
		return
	var state := _block_state(block)
	state.crumble_life = state.get("crumble_life", CRUMBLE_INITIAL_LIFE) - damage
	if state.crumble_life <= 0:
		_remove_block(block)
	else:
		TileEffects.crumble(block.tml, block.coords)


func _activate_vanish(block: Dictionary) -> void:
	var state := _block_state(block)
	var idle := not state.has("vanish_reappear") and not state.has("vanish_fade") \
			and not state.has("vanish_fade_in")
	if idle:
		state.vanish_fade = VANISH_FADE_FRAMES + 1


func _push_block(block: Dictionary, dx: int, dy: int) -> void:
	if not block.main:
		return
	var rotated := _rotate_point(dx, dy, course_rotation)
	if not _can_move_block_chain(block.x, block.y, int(rotated.x), int(rotated.y)):
		return
	_move_block_chain(block.x, block.y, int(rotated.x), int(rotated.y))


func _can_move_block_chain(bx: int, by: int, dx: int, dy: int) -> bool:
	var dest := Vector2i(bx + dx, by + dy)
	var dest_id := _cell_id(main_map, dest)
	if dest_id != 0:
		if dest_id != B_PUSH:
			return false
		if not _can_move_block_chain(dest.x, dest.y, dx, dy):
			return false
	return not _player_occupies_tile(dest.x, dest.y)


func _move_block_chain(bx: int, by: int, dx: int, dy: int) -> void:
	var from := Vector2i(bx, by)
	var dest := Vector2i(bx + dx, by + dy)
	if _cell_id(main_map, dest) == B_PUSH:
		_move_block_chain(dest.x, dest.y, dx, dy)
	var atlas := main_map.get_cell_atlas_coords(from)
	var alt := main_map.get_cell_alternative_tile(from)
	main_map.set_cell(from, -1)
	main_map.set_cell(dest, 0, atlas, alt)
	var from_key := _state_key(main_map, from)
	if block_states.has(from_key):
		block_states[_state_key(main_map, dest)] = block_states[from_key]
		block_states.erase(from_key)


func _start_rotate(block: Dictionary, direction: int) -> void:
	if rotate_frames_remaining > 0:
		return
	_set_mode(MODE_PAUSE)
	vx = 0
	vy = 0
	target_vel_x = 0
	grounded = false
	rotate_direction = direction
	rotate_frames_remaining = ROTATE_FRAMES
	course_tween_rotation = 0


func _update_rotation() -> void:
	course_tween_rotation += rotate_direction * 3
	rotate_frames_remaining -= 1
	if rotate_frames_remaining == 0:
		_finish_rotation()


func _finish_rotation() -> void:
	if rotate_direction > 0:
		var previous_x := x
		_set_player_pos(-y, previous_x)
		var safe_x := -last_safe_y
		last_safe_y = last_safe_x
		last_safe_x = safe_x
		course_rotation = _normalize_rotation(course_rotation + 90)
	else:
		var previous_x := x
		_set_player_pos(y, -previous_x)
		var safe_x := last_safe_y
		last_safe_y = -last_safe_x
		last_safe_x = safe_x
		course_rotation = _normalize_rotation(course_rotation - 90)
	rotate_direction = 0
	course_tween_rotation = 0
	_set_mode(MODE_LAND)
	_mark_discontinuity()


func _remove_block(block: Dictionary) -> void:
	if block.tml.get_cell_source_id(block.coords) == -1:
		return
	TileEffects.shatter(block.tml, block.coords)
	block_states.erase(_state_key(block.tml, block.coords))


## Calls a PR4 tile behavior (items, finish, teleports...). If it moves the
## character, PR2 state follows.
func _fire_pr4_event(event: String, block: Dictionary) -> void:
	var before_position := character.position
	var before_parent := character.get_parent()
	character.velocity = Vector2.ZERO
	tiles.on(event, block.id, character, block.tml, block.coords)
	var pushed := character.velocity
	character.velocity = last_written_velocity
	if pushed != Vector2.ZERO:
		var g := _vec_from_pr4(pushed) / VELOCITY_SCALE
		vx += g.x
		vy += g.y
	if character.get_parent() != before_parent or character.position != before_position:
		_bind_map()
		var keep_v := Vector2(vx, vy)
		var parent_changed := character.get_parent() != before_parent
		_sync_from_character()
		vx = keep_v.x
		vy = keep_v.y
		if parent_changed:
			standing_tile_x = _tile_index(x)
			standing_tile_y = _tile_index(y)


# ---------------------------------------------------------------------------
# Timed block state (BlockController.update)
# ---------------------------------------------------------------------------

func _update_block_states() -> void:
	# Three passes, in PR2's order.
	for key in block_states.keys():
		var state: Dictionary = block_states[key]
		if state.has("vanish_fade"):
			var frames: int = state.vanish_fade - 1
			if frames <= 0:
				state.erase("vanish_fade")
				state.removed = true
				state.vanish_reappear = VANISH_REAPPEAR_FRAMES
				_set_block_visible(state, false)
			else:
				state.vanish_fade = frames
	for key in block_states.keys():
		var state: Dictionary = block_states[key]
		if state.has("vanish_fade_in"):
			var frames: int = state.vanish_fade_in - 1
			if frames <= 0:
				state.erase("vanish_fade_in")
			else:
				state.vanish_fade_in = frames
	for key in block_states.keys():
		var state: Dictionary = block_states[key]
		if state.has("vanish_reappear"):
			var frames: int = state.vanish_reappear - 1
			if frames > 0:
				state.vanish_reappear = frames
			elif not (state.main and _player_occupies_tile(state.coords.x, state.coords.y)):
				state.erase("vanish_reappear")
				state.removed = false
				state.vanish_fade_in = VANISH_FADE_FRAMES - 2
				_set_block_visible(state, true)
			else:
				state.vanish_reappear = VANISH_REAPPEAR_FRAMES

	for key in block_states.keys():
		var state: Dictionary = block_states[key]
		if not state.has("bounce_vx"):
			continue
		state.bounce_vx *= 0.5
		state.bounce_vy *= 0.5
		state.bounce_x += state.bounce_vx
		state.bounce_y += state.bounce_vy
		state.bounce_x += -state.bounce_x * 0.35
		state.bounce_y += -state.bounce_y * 0.35
		if absf(state.bounce_x) < 0.25 and absf(state.bounce_y) < 0.25:
			state.bounce_x = 0.0
			state.bounce_y = 0.0
			state.erase("bounce_vx")
			state.erase("bounce_vy")


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


func _start_block_bounce(block: Dictionary, hit_x: float, hit_y: float) -> void:
	var velocity := _rotate_point(hit_x, hit_y, course_rotation)
	var state := _block_state(block)
	if not state.has("bounce_x"):
		state.bounce_x = 0.0
		state.bounce_y = 0.0
	state.bounce_vx = velocity.x
	state.bounce_vy = velocity.y


func _block_bounce_offset(block: Dictionary) -> Vector2:
	var key := _state_key(block.tml, block.coords)
	if not block_states.has(key) or not block_states[key].has("bounce_x"):
		return Vector2.ZERO
	var state: Dictionary = block_states[key]
	return _rotate_point(state.bounce_x, state.bounce_y, course_rotation)


func _block_state(block: Dictionary) -> Dictionary:
	var key := _state_key(block.tml, block.coords)
	if not block_states.has(key):
		block_states[key] = {"tml": block.tml, "coords": block.coords, "main": block.main}
	return block_states[key]


func _state_key(tml: TileMapLayer, coords: Vector2i) -> String:
	return str(tml.get_instance_id()) + ":" + str(coords.x) + "," + str(coords.y)


func _is_block_removed(block: Dictionary) -> bool:
	var tml: TileMapLayer = block.tml
	if tml.get_cell_source_id(block.coords) == -1 or _cell_id(tml, block.coords) != block.id:
		return true
	if tml.get_cell_alternative_tile(block.coords) > Tile.INVISIBLE_DEACTIVATED_ALT_ID:
		return true
	var key := _state_key(tml, block.coords)
	return block_states.has(key) and block_states[key].get("removed", false)


# ---------------------------------------------------------------------------
# Safe spots and map bounds
# ---------------------------------------------------------------------------

func _is_safe_stand_block(block: Dictionary) -> bool:
	if block.id in [B_BRICK, B_CRUMBLE, B_VANISH, B_MINE, B_MOVE, B_PUSH, B_WATER, B_SAFETY]:
		return false
	if _is_teleport(block.id):
		return false
	return block.main


func _update_safe_spot(block: Dictionary, center_y: bool) -> void:
	var pos := _rotated_block_pos(block)
	last_safe_x = pos.x + TILE / 2
	last_safe_y = pos.y + (TILE / 2 if center_y else 0.0)
	standing_tile_x = block.x
	standing_tile_y = block.y


func _return_to_last_safe_spot() -> void:
	_set_player_pos(last_safe_x, last_safe_y)
	vx = 0
	vy = 0
	if hurt_frames_remaining <= 0:
		hurt_frames_remaining = HURT_FRAMES
	_mark_discontinuity()


func _is_past_map_return_boundary() -> bool:
	if map_bounds_dirty:
		_update_map_bounds()
	var p := _rotate_to_level(x, y, course_rotation)
	return (course_rotation == 0 and p.y > map_max.y + MAP_RETURN_MARGIN) \
		or (absi(course_rotation) == 180 and p.y < map_min.y - MAP_RETURN_MARGIN) \
		or (course_rotation == 90 and p.x > map_max.x + MAP_RETURN_MARGIN) \
		or (course_rotation == -90 and p.x < map_min.x - MAP_RETURN_MARGIN)


func _update_map_bounds() -> void:
	map_bounds_dirty = false
	var rect := main_map.get_used_rect()
	map_min = Vector2(rect.position) * TILE
	map_max = Vector2(rect.end - Vector2i.ONE) * TILE


## PR2 checks the feet tile and the one above it, even while crouched.
func _player_occupies_tile(target_x: int, target_y: int) -> bool:
	var seg1 := _rotate_point(_tile_index(x), _tile_index(y), course_rotation)
	var seg1_x := int(seg1.x)
	var seg1_y := int(seg1.y)
	var seg2_x := seg1_x
	var seg2_y := seg1_y - 1
	if course_rotation == 90:
		seg1_x -= 1
		seg2_x -= 1
	elif absi(course_rotation) == 180:
		seg1_x -= 1
		seg2_x -= 1
		seg1_y += 1
		seg2_y += 1
	elif course_rotation == -90:
		seg1_y += 1
		seg2_y += 1
	return (seg1_x == target_x and seg1_y == target_y) \
			or (seg2_x == target_x and seg2_y == target_y)


# ---------------------------------------------------------------------------
# Tile lookups
# ---------------------------------------------------------------------------

## A block is a Dictionary: {tml, coords, id, x, y, main}. x/y are the block's
## tile coordinates in PR2's level frame. For blocks on gears and other moving
## tile maps they are the nearest equivalent tile.
func _get_block_at_pixel(px: float, py: float):
	var c := _rotate_to_level(px, py, course_rotation)
	var tile := Vector2i(_tile_index(c.x), _tile_index(c.y))
	var block = _main_block(tile)
	if block != null:
		return block if _is_solid_block(block) else null
	return _sub_block_at(c, true)


func _block_at_pixel_any(px: float, py: float):
	var c := _rotate_to_level(px, py, course_rotation)
	var tile := Vector2i(_tile_index(c.x), _tile_index(c.y))
	var block = _main_block(tile)
	if block == null:
		block = _sub_block_at(c, false)
	if block == null or _is_block_removed(block):
		return null
	return block


func _main_block(tile: Vector2i):
	var id := _cell_id(main_map, tile)
	if id == 0:
		return null
	return {"tml": main_map, "coords": tile, "id": id, "x": tile.x, "y": tile.y, "main": true}


func _sub_block_at(canonical: Vector2, solid_only: bool):
	if sub_maps.is_empty():
		return null
	var layer_point: Vector2 = main_map.transform * (canonical * PR4_PER_PR2)
	for tml in sub_maps:
		if not is_instance_valid(tml):
			continue
		var local: Vector2 = tml.to_local(_layer_to_global(layer_point))
		var coords: Vector2i = tml.local_to_map(local)
		var id := _cell_id(tml, coords)
		if id == 0:
			continue
		var center := _from_layer_to_canonical(tml.to_global(tml.map_to_local(coords)))
		var block := {
			"tml": tml, "coords": coords, "id": id,
			"x": _tile_index(center.x), "y": _tile_index(center.y), "main": false,
		}
		if solid_only and not _is_solid_block(block):
			continue
		return block
	return null


func _layer_to_global(p: Vector2) -> Vector2:
	return main_map.get_parent().get_node("Players").to_global(p)


func _from_layer_to_canonical(global_point: Vector2) -> Vector2:
	var p: Vector2 = main_map.get_parent().get_node("Players").to_local(global_point)
	return (main_map.transform.affine_inverse() * p) / PR4_PER_PR2


func _is_solid_block(block: Dictionary) -> bool:
	return tiles.is_solid(block.id) and not _is_block_removed(block)


func _cell_id(tml: TileMapLayer, coords: Vector2i) -> int:
	if tml.get_cell_source_id(coords) == -1:
		return 0
	return CoordinateUtils.to_block_id(tml.get_cell_atlas_coords(coords))


func _block_with_open_space_below(block):
	if block == null:
		return null
	return block if _get_block_below(block) == null else null


# PR2 passes level-frame tile positions here as if they were gravity-frame
# pixels. Once the course is rotated, that points far outside any PR2 level
# (PR2 levels sit at large positive coordinates), so PR2 always finds nothing.
# PR4 levels sit around 0, where the same math can hit real blocks, so a
# rotated course returns nothing directly, like PR2.
func _get_block_left_of(block: Dictionary):
	if course_rotation != 0:
		return null
	return _get_block_at_pixel(block.x * TILE - TILE, block.y * TILE)


func _get_block_right_of(block: Dictionary):
	if course_rotation != 0:
		return null
	return _get_block_at_pixel(block.x * TILE + TILE, block.y * TILE)


func _get_block_below(block: Dictionary):
	if course_rotation != 0:
		return null
	return _get_block_at_pixel(block.x * TILE, block.y * TILE + TILE)


## Top-left of a block in the gravity frame (Flash Block.getRotatedPos).
func _rotated_block_pos(block: Dictionary) -> Vector2:
	if not block.main:
		return _sub_block_top_left(block)
	var offset := Vector2.ZERO
	if course_rotation == 90:
		offset.y = TILE
	elif absi(course_rotation) == 180:
		offset = Vector2(TILE, TILE)
	elif course_rotation == -90:
		offset.x = TILE
	return _rotate_point(block.x * TILE + offset.x, block.y * TILE + offset.y, -course_rotation)


func _sub_block_top_left(block: Dictionary) -> Vector2:
	var tml: TileMapLayer = block.tml
	var half := Vector2(Settings.tile_size_half)
	var center: Vector2 = tml.map_to_local(block.coords)
	var result := Vector2(INF, INF)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var c := _from_layer_to_canonical(tml.to_global(center + half * corner))
		var g := _rotate_exact(c, -course_rotation)
		result.x = minf(result.x, g.x)
		result.y = minf(result.y, g.y)
	return result


func _is_arrow(id: int) -> bool:
	return id >= B_ARROW_DOWN and id <= B_ARROW_RIGHT


func _is_teleport(id: int) -> bool:
	return id >= B_TELEPORT_BLUE and id <= B_TELEPORT_YELLOW


# ---------------------------------------------------------------------------
# Items (PR2's ItemController)
# ---------------------------------------------------------------------------

## True for PR4 items whose physics follow PR2's rules in this mode.
static func handles_item(id: int) -> bool:
	return id in [ITEM_JETPACK, ITEM_LASER_GUN, ITEM_PORTABLE_MINE, ITEM_SPEED_BURST,
			ITEM_SUPER_JUMP, ITEM_SWORD, ITEM_TELEPORT]


## Sets up PR2 item state when the character picks up a new item.
func _sync_held_item() -> void:
	var manager = character.item_manager
	var node = manager.item if manager else null
	if node == item_node:
		return
	item_node = node
	item_id = manager.item_id if node and handles_item(manager.item_id) else -1
	item_available = false # PR2 items wait for the item key to be released once
	item_reload = 0
	item_reload_frames = 0
	item_uses = 1
	match item_id:
		ITEM_LASER_GUN, ITEM_SWORD:
			item_uses = 3
			item_reload_frames = FAST_ITEM_RELOAD_FRAMES
		ITEM_JETPACK:
			jet_pack_fuel = JET_PACK_TOTAL_FUEL
		ITEM_PORTABLE_MINE:
			# PR4's placement preview points at PR4's tile, not PR2's.
			var preview = node.get_node_or_null("VisualAid")
			if preview:
				preview.visible = false


## PR2's Item.setSpace: fires on a fresh press once reloaded (jet pack: while held).
func _use_held_item() -> void:
	if item_id == -1:
		return
	if item_id == ITEM_JETPACK and input.item:
		_use_jet_pack()
		return
	if not input.item:
		item_available = true
		return
	if item_uses <= 0 or item_reload > 0 or not item_available:
		return
	match item_id:
		ITEM_LASER_GUN:
			vx += LASER_RECOIL if facing < 0 else -LASER_RECOIL
			_item_visual("shoot")
			_fire_laser_shot()
			_consume_item_use()
		ITEM_SWORD:
			vx += -SWORD_LUNGE if facing < 0 else SWORD_LUNGE
			_item_visual("slash")
			_consume_item_use()
		ITEM_SUPER_JUMP:
			if crouching:
				return
			vy -= SUPER_JUMP_ITEM_SPEED
			_play_sound(SUPER_JUMP_SOUND)
			_consume_item_use()
		ITEM_TELEPORT:
			var dest_x := x + TELEPORT_ITEM_DISTANCE * facing
			if _get_block_at_pixel(dest_x, y - 5) != null:
				return
			_set_player_x(dest_x)
			_mark_discontinuity()
			_consume_item_use()
		ITEM_PORTABLE_MINE:
			_use_mine_item()
		ITEM_SPEED_BURST:
			if speed_burst_frames > 0:
				return
			speed_burst_frames = SPEED_BURST_FRAMES
			accel *= 2
			max_vel_x *= 2
			character.speed_particles.emitting = true


## PR2's mine item: picks the tile at an offset from the weapon hand and, if
## it's empty, a mine appears there 33 frames later.
func _use_mine_item() -> void:
	var hand := Vector2(x + facing * MINE_HAND_OFFSET.x, y + MINE_HAND_OFFSET.y)
	var probe := _rotate_point(_haxe_round(hand.x + 15), _haxe_round(hand.y + 10), course_rotation)
	var tile := Vector2i(_tile_index(probe.x), _tile_index(probe.y))
	if _cell_id(main_map, tile) != 0:
		return
	var effect := MINE_SPAWN_EFFECT.instantiate()
	effect.position = main_map.map_to_local(tile)
	main_map.add_child(effect)
	effect.get_node("AnimationTimer").stop() # PR2 timing places the block, not the effect
	pending_mines.push_back({"tile": tile, "frames": MINE_APPEAR_FRAMES, "effect": effect})
	_consume_item_use()


## Counts down pending mines; returns the ones due this frame.
func _tick_pending_mines() -> Array:
	var ready := []
	var still_pending := []
	for mine in pending_mines:
		mine.frames -= 1
		if mine.frames <= 0:
			ready.push_back(mine)
		else:
			still_pending.push_back(mine)
	pending_mines = still_pending
	return ready


func _place_mines(ready: Array) -> void:
	for mine in ready:
		if is_instance_valid(mine.effect):
			mine.effect.queue_free()
		if _cell_id(main_map, mine.tile) != 0:
			continue # something else got there first
		block_states.erase(_state_key(main_map, mine.tile))
		main_map.set_cell(mine.tile, 0, CoordinateUtils.to_atlas_coords(B_MINE))


## PR2's laser shot: checks right next to the player first, then flies at
## 29px a frame for up to 100 frames.
func _fire_laser_shot() -> void:
	var shot_x := x + (-20.0 if facing < 0 else 20.0)
	var shot_y := y - 25
	var block = _get_block_at_pixel(shot_x, shot_y)
	if block != null:
		_damage_block_from_item(block)
		return
	laser_shots.push_back({
		"x": shot_x, "y": shot_y,
		"vx": -LASER_SHOT_SPEED if facing < 0 else LASER_SHOT_SPEED,
		"frames": LASER_SHOT_FRAMES,
	})


func _update_laser_shots() -> void:
	if laser_shots.is_empty():
		return
	var still_flying := []
	for shot in laser_shots:
		shot.x += shot.vx
		shot.frames -= 1
		var block = _get_block_at_pixel(shot.x, shot.y)
		if block != null:
			_damage_block_from_item(block)
		elif shot.frames > 0:
			still_flying.push_back(shot)
	laser_shots = still_flying


func _damage_block_from_item(block: Dictionary) -> void:
	match block.id:
		B_BRICK:
			_remove_block(block)
		B_CRUMBLE:
			_apply_crumble_force(block, 5)
		B_MINE:
			var effect := EXPLODE_EFFECT.instantiate()
			effect.position = Vector2(block.coords * Settings.tile_size) \
					+ Vector2(Settings.tile_size_half)
			block.tml.add_child(effect)
			_remove_block(block)
		B_VANISH:
			_activate_vanish(block)


func _use_jet_pack() -> void:
	if jet_pack_fuel <= 0 or crouching:
		return
	vy -= 1.25 if vy > -5 else 0.5
	jet_pack_fuel -= 1
	if jet_pack_fuel <= 0:
		_drop_item()


func _consume_item_use() -> void:
	item_uses -= 1
	if item_uses <= 0:
		_drop_item()
	else:
		item_reload = item_reload_frames


## Speed burst runs out after 135 frames, and the item goes with it.
func _update_speed_burst() -> void:
	if speed_burst_frames <= 0:
		return
	speed_burst_frames -= 1
	if speed_burst_frames <= 0:
		character.speed_particles.emitting = false
		if item_id == ITEM_SPEED_BURST:
			_drop_item()


func _drop_item() -> void:
	item_id = -1
	item_uses = 0
	jet_pack_fuel = 0
	if character.item_manager and character.item_manager.item:
		character.item_manager.remove_item()
	item_node = null


## Plays the PR4 item's shot or slash effect without its PR4 physics.
func _item_visual(effect: String) -> void:
	if not is_instance_valid(item_node) or not Game.game:
		return
	if item_node.get("animtimer"):
		item_node.animtimer.start()
	if item_node.has_method(effect):
		item_node.call(effect)


# ---------------------------------------------------------------------------
# PR4 status links (hurt, freeze, animation)
# ---------------------------------------------------------------------------

func _sync_status_from_pr4() -> void:
	var movement := character.movement
	if movement.frozen and mode != MODE_FROZEN_SOLID and mode != MODE_PAUSE:
		_set_mode(MODE_FROZEN_SOLID)
		frozen_solid_frames_remaining = FROZEN_SOLID_FRAMES
	if movement.hurt and mode != MODE_HURT and mode != MODE_PAUSE:
		_set_mode(MODE_HURT)
		hurt_frames_remaining = maxi(hurt_frames_remaining, int(ceil(movement.hitstun_timer * 30)))


func _sync_status_to_pr4() -> void:
	var movement := character.movement
	if mode == MODE_HURT:
		if not movement.hurt:
			movement.hurt = true
			movement.hitstun_duration = HURT_FRAMES / 30.0
		movement.hitstun_timer = maxf(hurt_frames_remaining, 0) / 30.0
	elif movement.hurt:
		movement.hurt = false
		movement.hitstun_timer = 0
	if mode == MODE_FROZEN_SOLID:
		movement.frozen = true
		movement.frozen_timer = frozen_solid_frames_remaining / 30.0
		if movement.frozen_display_node:
			var amount := frozen_solid_frames_remaining / float(FROZEN_SOLID_FRAMES)
			movement.frozen_display_node.visible = true
			movement.frozen_display_node.modulate.a = amount
			movement.frozen_display_node.scale.y = 0.65 * amount
			character.display.modulate = Color(1.0 - amount / 2, 1.0, 1.0)
	elif movement.frozen:
		movement.frozen = false
		movement.frozen_timer = 0
		if movement.frozen_display_node:
			movement.frozen_display_node.visible = false
		character.display.modulate = Color(1, 1, 1)


func _play_sound(stream: AudioStream) -> void:
	if character.audioplayer:
		character.audioplayer.set_stream(stream)
		character.audioplayer.set_volume_db(1)
		character.audioplayer.play()


# ---------------------------------------------------------------------------
# Number helpers that match Flash/Haxe exactly
# ---------------------------------------------------------------------------

func _set_player_x(value: float) -> void:
	x = _flash_coordinate(value)


func _set_player_y(value: float) -> void:
	y = _flash_coordinate(value)


func _set_player_pos(px: float, py: float) -> void:
	_set_player_x(px)
	_set_player_y(py)


func _move_player_by(dx: float, dy: float) -> void:
	_set_player_pos(x + dx, y + dy)


## Flash stores display positions in twips (1/20 px).
static func _flash_coordinate(value: float) -> float:
	return floor(value * TWIPS_PER_PIXEL) / TWIPS_PER_PIXEL


## Haxe Math.round: rounds .5 up, including for negative numbers.
static func _haxe_round(value: float) -> float:
	return floor(value + 0.5)


static func _tile_index(value: float) -> int:
	return int(floor(value / TILE))


## PR2's Data.rotatePoint, including AS3 int truncation toward zero.
static func _rotate_point(px: float, py: float, rotation: int) -> Vector2:
	if rotation > 180:
		rotation -= 360
	elif rotation < -180:
		rotation += 360
	var rx := _as3_int(px)
	var ry := _as3_int(py)
	if rotation == 90:
		rx = _as3_int(py)
		ry = _as3_int(-px)
	elif absi(rotation) == 180:
		rx = _as3_int(-px)
		ry = _as3_int(-py)
	elif rotation == -90:
		rx = _as3_int(-py)
		ry = _as3_int(px)
	return Vector2(rx, ry)


## Gravity-frame pixel -> level pixel for tile lookups. PR2 truncates toward
## zero here, which is the same as rounding down because PR2 levels always sit
## at positive coordinates. PR4 levels sit around 0, where truncating would
## look up the wrong tile, so this rounds down.
static func _rotate_to_level(px: float, py: float, rotation: int) -> Vector2:
	var v := _rotate_exact(Vector2(px, py), rotation)
	return Vector2(floor(v.x), floor(v.y))


## Same rotation without truncation, for converting positions to and from PR4.
static func _rotate_exact(v: Vector2, rotation: int) -> Vector2:
	rotation = _normalize_rotation(rotation)
	if rotation == 90:
		return Vector2(v.y, -v.x)
	if absi(rotation) == 180:
		return Vector2(-v.x, -v.y)
	if rotation == -90:
		return Vector2(-v.y, v.x)
	return v


static func _as3_int(value: float) -> int:
	if is_nan(value) or is_inf(value) or value == 0:
		return 0
	return int(value)


static func _normalize_rotation(rotation: int) -> int:
	var normalized := rotation % 360
	if normalized > 180:
		normalized -= 360
	elif normalized < -180:
		normalized += 360
	return normalized
