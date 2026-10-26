class_name AnimationController
## Controls character animations based on state.
## Handles animation selection, direction, and special effects like super jump.

var display: Node2D
var sjaura: Node2D
var shake: float = 0.0
var sjanim: float = 0.0


func _init(character_display: Node2D, super_jump_aura: Node2D):
	display = character_display
	sjaura = super_jump_aura


func process(character: Character, movement: MovementController, super_jump: SuperJump):
	# Face left or right
	var control_vector = Input.get_vector("left", "right", "up", "down")
	if !movement.hurt:
		display.scale.x = movement.facing
	else:
		if (movement.hitstun_duration - movement.hitstun_timer) < 0.4:
			display.play(CharacterDisplay.HURT_START)
		elif movement.hitstun_timer > 0.5:
			display.play(CharacterDisplay.HURT)
		else:
			display.play(CharacterDisplay.RECOVER)
	
	# Animation speed adjustment for frozen state
	if movement.frozen:
		display.set_speed_scale(1 - movement.frozen_display_node.modulate.a)
	else:
		display.set_speed_scale(1)
	
	var classic = character.classic_physics()
	var classic_charging: bool = classic != null and classic.is_charging_super_jump()
	var charging: bool = super_jump.is_locking() or classic_charging
	var charge: float = super_jump.charge_precentage()
	if classic_charging:
		charge = classic.super_jump_charge()
	
	# On ground
	if !movement.hurt and character.is_grounded():
		if charging:
			if charge < 1:
				display.play(CharacterDisplay.CHARGE)
			else:
				display.play(CharacterDisplay.CHARGE_HOLD)
			display.animations.seek(charge)
		elif !movement.hurt and movement.is_crouching:
			if control_vector.x != 0:
				display.play(CharacterDisplay.CRAWL)
			else:
				display.play(CharacterDisplay.CROUCH)
		elif control_vector.x != 0:
			display.play(CharacterDisplay.RUN)
		else:
			display.play(CharacterDisplay.IDLE)
	
	# In the air
	elif !movement.hurt and movement.swimming:
		display.play(CharacterDisplay.SWIM)
	elif !movement.hurt and movement.is_wall_sliding:
		display.play(CharacterDisplay.WALL_SLIDE)
	elif !movement.hurt:
		display.play(CharacterDisplay.JUMP)
	
	# Super jump charge effect
	shake = charge / 8
	sjanim = randf_range(1 - shake, 1 + shake)
	if charging:
		display.scale.y = sjanim
		if !movement.frozen:
			display.modulate.b = 1.0 - charge
		sjaura.modulate.a = charge / 2
		sjaura.scale.y = charge / 2
		if !sjaura.visible:
			sjaura.visible = true
	else:
		if sjaura.visible:
			sjaura.visible = false
		if !movement.frozen:
			display.modulate = Color(1.0, 1.0, 1.0)
		display.scale.y = 1
		if !movement.is_wall_sliding:
			display.scale.x = movement.facing
		shake = 0
