class_name Character
extends CharacterBody2D
## Main player character with physics, items, and movement controls
##
## Handles all character physics, movement, animation, 
## item management and interaction with game tiles.

signal position_changed(x: float, y: float)

@onready var hitbox := $CharacterHitbox
@onready var light := $Light
@onready var camera := $Camera
@onready var sun_particles := $SunParticles
@onready var moon_particles := $MoonParticles
@onready var speed_particles := $SpeedParticles
@onready var low_area := $LowArea
@onready var high_area := $HighArea
@onready var item_manager := $ItemManager
@onready var ice := $Ice
@onready var invincibility := $Invincibility
@onready var display := $Display
@onready var sjaura := $SuperJumpAura
@onready var animations: AnimationPlayer = $Display/Animations
@onready var audioplayer: AudioStreamPlayer2D = $AudioPlayer

var active := false
var item: Node2D
var game: Node2D
var shielded: bool = false
var tiles: Tiles

# Component controllers
var stats: Stats = Stats.new()
var gravity: Gravity = Gravity.new()
var super_jump: SuperJump = SuperJump.new()
var camera_controller: CameraController
var lightbreak: LightbreakController
var movement: MovementController
var animation: AnimationController
var tile_interaction: TileInteractionController
var pr2_physics: Pr2Physics
var pr3_physics: Pr3Physics
var physics_override := "" # set by physics switch blocks; "" = the level's choice
var control_vector: Vector2


func _ready() -> void:
	item_manager.item_holder = $Display/ItemHolder
	# Initialize all the controllers
	camera_controller = CameraController.new(camera)
	lightbreak = LightbreakController.new(light, sun_particles, moon_particles)
	movement = MovementController.new(ice)
	animation = AnimationController.new(display, sjaura)
	pr2_physics = Pr2Physics.new(self)
	pr3_physics = Pr3Physics.new(self)
	

func init(tiles_node: Tiles) -> void:
	tiles = tiles_node
	tile_interaction = TileInteractionController.new(tiles, low_area, high_area)
	tile_interaction.last_safe_position = Vector2(position)


func _physics_process(delta: float) -> void:
	if not active or not tile_interaction:
		return
	
	# Update hitbox based on crouch state and size
	movement.is_crouching = tile_interaction.should_crouch(self)
	hitbox.run(self)
	low_area.scale = movement.size
	high_area.scale = movement.size
	
	# PR2/PR3 physics mode, unless a lightbreak needs PR4 movement this tick
	var classic = classic_physics()
	if classic:
		if not lightbreak.is_active():
			_classic_physics_process(classic, delta)
			return
		classic.invalidate()
	
	# Process gravity
	gravity.run(self, delta)
	
	# Update velocity from super jump
	if not movement.hurt and gravity.not_rotating(delta):
		super_jump.run(self, delta)
	
	# Process item forces
	_process_item_forces(delta)
	
	# Process movement
	velocity = movement.process(delta, self, stats, gravity, super_jump)
	
	# Process lightbreak
	control_vector = Input.get_vector("left", "right", "up", "down")
	var lightbreak_velocity := lightbreak.process(delta, control_vector, self)
	if lightbreak_velocity != Vector2.ZERO:
		velocity = lightbreak_velocity
	
	# Move the character if we're not rotating
	if gravity.not_rotating(delta):
		movement.previous_velocity = velocity
		move_and_slide()
	
	# Interact with tiles
	tile_interaction.interact_with_incoporeal_tiles(self)
	var hit_something := tile_interaction.interact_with_solid_tiles(self, lightbreak)
	
	# End lightbreak if we hit something
	if hit_something and lightbreak.direction.length() > 0:
		lightbreak.end_lightbreak()
	
	# Item usage
	_process_items(delta)
	
	# Update camera
	camera_controller.process(delta, position, lightbreak.is_active())
	
	# Update animations
	scale = movement.size
	animation.process(self, movement, super_jump)
	
	# Check boundaries
	tile_interaction.check_out_of_bounds(self)


## Runs a tick of PR2 or PR3 physics (the "classic" modes).
func _classic_physics_process(classic, delta: float) -> void:
	if not classic.handles_item(item_manager.item_id) or not item_manager.item:
		_process_item_forces(delta)
	classic.physics_tick(delta)

	# Gas tiles (lights, switches). PR2/PR3 physics handle water and safety nets.
	_interact_with_gas_tiles()

	control_vector = Input.get_vector("left", "right", "up", "down")
	lightbreak.process(delta, control_vector, self)
	_process_items(delta)
	camera_controller.process(delta, position, lightbreak.is_active())
	scale = movement.size
	animation.process(self, movement, super_jump)


func _interact_with_gas_tiles() -> void:
	for tile in tile_interaction.get_tiles_overlapping_area(low_area):
		if tile.block_id == Pr2Physics.B_WATER or tile.block_id == Pr2Physics.B_SAFETY:
			continue
		tiles.on("area", tile.block_id, self, tile.tile_map_layer, tile.coords)


## "pr2", "pr3" or "pr4": the level's choice, unless a switch block changed it.
func physics_mode() -> String:
	if physics_override != "":
		return physics_override
	if GameConfig.get_value("pr3_physics"):
		return "pr3"
	if GameConfig.get_value("pr2_physics"):
		return "pr2"
	return "pr4"


## Called by the PR2/PR3/PR4 physics switch blocks.
func set_physics_mode(mode: String) -> void:
	if mode == physics_mode():
		return
	physics_override = mode
	# The new mode picks up the player's position, rotation, speed and facing.
	if pr2_physics:
		pr2_physics.invalidate(true)
	if pr3_physics:
		pr3_physics.invalidate(true)


func uses_pr2_physics() -> bool:
	return pr2_physics != null and physics_mode() == "pr2"


func uses_pr3_physics() -> bool:
	return pr3_physics != null and physics_mode() == "pr3"


## The PR2 or PR3 physics object in use, or null for PR4 physics.
func classic_physics():
	if uses_pr2_physics():
		return pr2_physics
	if uses_pr3_physics():
		return pr3_physics
	return null


## On the ground, for any physics mode.
func is_grounded() -> bool:
	var classic = classic_physics()
	if classic and not lightbreak.is_active():
		return classic.grounded
	return is_on_floor()


func _process_item_forces(delta: float) -> void:
	var item_force := Vector2.ZERO
	if item_manager.item:
		item_force = item_manager.get_item_force(delta)
	
	if item_force != Vector2.ZERO:
		var item_force_x: float = item_force.x * display.scale.x
		var item_force_y := item_force.y
		velocity += Vector2(item_force_x, item_force_y).rotated(rotation)


func _process_items(delta: float) -> void:
	# Use items (in PR2/PR3 physics mode, their items are used inside their step)
	var classic = classic_physics()
	var classic_item: bool = classic != null and classic.handles_item(item_manager.item_id)
	if not movement.hurt and Input.is_action_pressed("item") and not classic_item:
		item_manager.use(delta)
	
	# Check item state
	if not movement.hurt and item:
		item_manager.check_item(delta)


# Public methods maintained for compatibility with existing code

func _bump_tile_covering_high_area() -> void:
	tile_interaction.bump_tile_covering_high_area(self)


func freeze() -> void:
	movement.freeze(stats.get_skill_bonus())


func hitstun(base_hitstun_time: float) -> void:
	movement.hitstun((base_hitstun_time * 2) / stats.get_skill_bonus(), shielded)


func is_in_solid() -> bool:
	return tile_interaction.is_in_solid(self)


func end_lightbreak() -> void:
	lightbreak.end_lightbreak()
	modulate.a = 1


func set_depth(depth: int) -> void:
	tile_interaction.set_depth(self, depth)


func set_item(new_item_id: int) -> void:
	item_manager.set_item_id(new_item_id, self)


func get_tiles_overlapping_area(area: Area2D) -> Array:
	return tile_interaction.get_tiles_overlapping_area(area)
