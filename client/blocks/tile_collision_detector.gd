class_name TileCollisionDetector extends Node
## Generic tile collision detector for any PhysicsBody2D
##
## Add as child to any physics object to enable tile behavior interactions.
## Detects collisions with ConfigurableTileMapLayer and tells the layer to
## trigger block behaviors.
##
## For CharacterBody2D: Uses get_last_slide_collision() in _physics_process
## For RigidBody2D: Uses body_shape_entered signal

var _parent: PhysicsBody2D


func _ready() -> void:
	_parent = get_parent() as PhysicsBody2D
	assert(_parent, "TileCollisionDetector must be child of PhysicsBody2D")

	# Connect to RigidBody2D signals if parent is a RigidBody2D
	if _parent is RigidBody2D:
		_setup_rigidbody_signals()


func _setup_rigidbody_signals() -> void:
	var rigid_body := _parent as RigidBody2D
	rigid_body.contact_monitor = true
	rigid_body.max_contacts_reported = 10
	rigid_body.body_shape_entered.connect(_on_body_shape_entered)


func _physics_process(_delta: float) -> void:
	# For CharacterBody2D, detect collisions using get_last_slide_collision
	if _parent is CharacterBody2D:
		_detect_character_body_collisions()


func _detect_character_body_collisions() -> void:
	var character_body := _parent as CharacterBody2D
	var collision: KinematicCollision2D = character_body.get_last_slide_collision()

	if not collision:
		return

	var tile_map_layer := collision.get_collider()
	if not (tile_map_layer is ConfigurableTileMapLayer):
		return

	var normal := collision.get_normal()
	var coords: Vector2i = CoordinateUtils.collision_coords(tile_map_layer, collision)

	_notify_collision(tile_map_layer, coords, normal)


func _on_body_shape_entered(
	body_rid: RID,
	body: Node,
	_body_shape_index: int,
	_local_shape_index: int
) -> void:
	# For RigidBody2D, detect collisions using body_shape_entered signal
	if not (body is ConfigurableTileMapLayer):
		return

	var tile_map_layer := body as ConfigurableTileMapLayer

	# Calculate the collision tile position
	# We need to determine which tile was actually hit based on the collision normal direction
	var body_global := _parent.global_position
	var tile_position := tile_map_layer.map_to_local(tile_map_layer.local_to_map(tile_map_layer.to_local(body_global)))
	var tile_global := tile_map_layer.to_global(tile_position)
	var direction := (body_global - tile_global).normalized()

	# Determine collision side to find the adjacent tile
	# Offset body position toward the collision direction to find the hit tile
	var offset := Vector2.ZERO
	if abs(direction.x) > abs(direction.y):
		# Horizontal collision - offset horizontally
		offset = Vector2(sign(direction.x) * 64, 0)
	else:
		# Vertical collision - offset vertically
		offset = Vector2(0, sign(direction.y) * 64)

	var contact_point := body_global + offset
	var body_local := tile_map_layer.to_local(contact_point)
	var coords: Vector2i = tile_map_layer.local_to_map(body_local)

	# Normal is based on the offset direction
	var normal := Vector2.ZERO
	if abs(direction.x) > abs(direction.y):
		normal = Vector2(sign(direction.x), 0)
	else:
		normal = Vector2(0, sign(direction.y))

	_notify_collision(tile_map_layer, coords, normal)


func _notify_collision(
	tile_map_layer: ConfigurableTileMapLayer,
	coords: Vector2i,
	normal: Vector2
) -> void:
	# Determine which event(s) to trigger based on collision normal
	var events: Array[String] = []

	if abs(normal.x) > abs(normal.y):
		if normal.x > 0:
			events.append("left")
		else:
			events.append("right")
		events.append("any_side")
	else:
		if normal.y > 0:
			events.append("bottom")
			events.append("bump")
		else:
			events.append("top")
			events.append("stand")
		events.append("any_side")

	# Delegate to the tile map layer to handle behaviors
	tile_map_layer.trigger_tile_behaviors(_parent, coords, events)
