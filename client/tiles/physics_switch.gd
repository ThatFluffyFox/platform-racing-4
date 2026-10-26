extends Tile
class_name PhysicsSwitch
## Solid block that switches the player who bumps it to another physics mode
## ("pr2", "pr3" or "pr4") for the rest of the run.

var mode := "pr4"


func _init(p_mode: String = "pr4") -> void:
	mode = p_mode


func init() -> void:
	matter_type = Tile.SOLID
	bump.push_back(switch_physics)


func switch_physics(player: Node2D, _tile_map_layer: TileMapLayer, _coords: Vector2i) -> void:
	if player.has_method("set_physics_mode"):
		player.set_physics_mode(mode)
