extends Node
## Runs PR3 physics on scripted scenarios and prints the player state each frame.
##
## Usage: godot --headless res://character/tests/pr3_physics_runner.tscn -- a.json b.json
## Scenario: {"x", "y" (PR3 pixels, feet), "speed", "accel", "jump", "blocks":
## [[tile_x, tile_y, pr4_block_id], ...], "inputs": ["LRJDI" letters per frame],
## "item": optional PR4 item id}. Each output line: frame, x, y, velX, velY
## (player frame), grounded, crouching, swimming, rotation.

const LAYER = preload("res://layers/layer.tscn")
const CHARACTER = preload("res://character/character.tscn")


func _ready() -> void:
	await get_tree().process_frame
	for path in OS.get_cmdline_user_args():
		print("# " + path)
		var text := FileAccess.get_file_as_string(path)
		await _run_scenario(JSON.parse_string(text))
	get_tree().quit()


func _run_scenario(scenario: Dictionary) -> void:
	GameConfig.clear_overrides()
	GameConfig.override_values["pr3_physics"] = true

	var tiles := Tiles.new()
	tiles.init_defaults()
	var layer: Layer = LAYER.instantiate()
	add_child(layer)
	layer.init(tiles)
	var tml: TileMapLayer = layer.get_node("TileMapLayer")
	for b in scenario.blocks:
		tml.set_cell(Vector2i(b[0], b[1]), 0, CoordinateUtils.to_atlas_coords(int(b[2])))

	var character: Character = CHARACTER.instantiate()
	character.position = Vector2(scenario.x, scenario.y) * Pr3Physics.PR4_PER_PR3
	layer.get_node("Players").add_child(character)
	character.init(tiles)
	character.set_depth(layer.depth)
	character.stats.speed = scenario.speed
	character.stats.accel = scenario.accel
	character.stats.jump = scenario.jump

	var pr3 := character.pr3_physics
	pr3.tiles = tiles
	pr3._bind_map()
	pr3._sync_from_character()
	pr3.real_x = scenario.x
	pr3.real_y = scenario.y
	pr3.safe_x = pr3.real_x
	pr3.safe_y = pr3.real_y
	if scenario.get("item") != null:
		character.set_item(int(scenario.item))

	var inputs: Array = scenario.inputs
	for i in inputs.size():
		var keys: String = inputs[i]
		pr3.input = {
			"left": keys.contains("L"),
			"right": keys.contains("R"),
			"up": keys.contains("J"),
			"down": keys.contains("D"),
			"space": keys.contains("I") and not pr3.hurt,
		}
		pr3.frame()
		print("%d %.6f %.6f %.6f %.6f %s %s %s %.3f" % [
			i, pr3.real_x, pr3.real_y, pr3.vel_x, pr3.vel_y, pr3.touching_ground,
			pr3.crouching, pr3.swimming, pr3.rotation])
	var cells := []
	for coords in tml.get_used_cells():
		if coords.y != 10 or CoordinateUtils.to_block_id(tml.get_cell_atlas_coords(coords)) != 1:
			cells.push_back([coords.x, coords.y, CoordinateUtils.to_block_id(tml.get_cell_atlas_coords(coords))])
	print("# blocks off the floor row: ", cells)
	layer.queue_free()
	await get_tree().process_frame
