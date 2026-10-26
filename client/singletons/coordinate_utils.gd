extends Node
## Provides utility functions for coordinate conversions.

func to_atlas_coords(block_id: int) -> Vector2i:
	if block_id == 0:
		return Vector2i(-1, -1)
	var id := block_id - 1
	var x := id % 10
	var y := id / 10
	return Vector2i(x, y)


func to_block_id(atlas_coords: Vector2i) -> int:
	return (atlas_coords.y * 10) + atlas_coords.x + 1


## The tile a slide collision hit. Godot 4.5 merges tile collision into
## quadrants, so get_coords_for_body_rid() no longer names the cell; this
## steps from the contact point into the tile instead.
func collision_coords(tile_map_layer: TileMapLayer, collision: KinematicCollision2D) -> Vector2i:
	var inside := collision.get_position() - collision.get_normal() * 4.0
	var coords := tile_map_layer.local_to_map(tile_map_layer.to_local(inside))
	if tile_map_layer.get_cell_source_id(coords) == -1:
		coords = tile_map_layer.get_coords_for_body_rid(collision.get_collider_rid())
	return coords
