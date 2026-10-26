extends Node
## Runs PR2 physics on scripted scenarios and prints the player state each frame.
##
## Usage: godot --headless res://character/tests/pr2_physics_runner.tscn -- a.json b.json
## The scenario format is shared with PR2's reference controller, so the two
## outputs can be compared frame by frame. A scenario with "live": true drives
## the real character loop with key presses instead.

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
	GameConfig.override_values["pr2_physics"] = true
	GameConfig.override_values["pr2_gravity"] = float(scenario.gravity)

	var tiles := Tiles.new()
	tiles.init_defaults()
	var layer: Layer = LAYER.instantiate()
	add_child(layer)
	layer.init(tiles)
	var tml: TileMapLayer = layer.get_node("TileMapLayer")
	for b in scenario.blocks:
		tml.set_cell(Vector2i(b[0], b[1]), 0, CoordinateUtils.to_atlas_coords(int(b[2])))

	var character: Character = CHARACTER.instantiate()
	character.position = Vector2(scenario.x, scenario.y) * Pr2Physics.PR4_PER_PR2
	layer.get_node("Players").add_child(character)
	character.init(tiles)
	character.set_depth(layer.depth)
	character.stats.speed = scenario.speed
	character.stats.accel = scenario.accel
	character.stats.jump = scenario.jump

	if scenario.get("live", false):
		await _run_live(character, scenario.inputs)
	else:
		_run_steps(character, tiles, scenario)
	layer.queue_free()
	await get_tree().process_frame


## Steps PR2 physics directly, starting from the exact scenario position.
func _run_steps(character: Character, tiles: Tiles, scenario: Dictionary) -> void:
	var pr2 := character.pr2_physics
	pr2.tiles = tiles
	pr2._bind_map()
	pr2._sync_from_character()
	pr2._set_player_pos(scenario.x, scenario.y)
	pr2.last_safe_x = pr2.x
	pr2.last_safe_y = pr2.y
	pr2.standing_tile_x = Pr2Physics._tile_index(pr2.x)
	pr2.standing_tile_y = Pr2Physics._tile_index(pr2.y)
	if scenario.get("item") != null:
		character.set_item(int(scenario.item))

	var inputs: Array = scenario.inputs
	for i in inputs.size():
		var keys: String = inputs[i]
		pr2.input = {
			"left": keys.contains("L"),
			"right": keys.contains("R"),
			"jump": keys.contains("J"),
			"down": keys.contains("D"),
			"item": keys.contains("I"),
		}
		pr2.step()
		print("%d %.12f %.12f %.12f %.12f %s %s %s %d" % [
			i, pr2.x, pr2.y, pr2.vx, pr2.vy, pr2.grounded, pr2.crouching, pr2.mode,
			pr2.course_rotation])


## Drives the real character loop with key presses, two physics ticks per input.
func _run_live(character: Character, inputs: Array) -> void:
	character.active = true
	var actions := {"L": "left", "R": "right", "J": "jump", "D": "down"}
	for i in inputs.size():
		var keys: String = inputs[i]
		for key in actions:
			if keys.contains(key):
				Input.action_press(actions[key])
			else:
				Input.action_release(actions[key])
		await get_tree().physics_frame
		await get_tree().physics_frame
		var pr2 := character.pr2_physics
		print("%d %.12f %.12f %.12f %.12f %s %s %s %d" % [
			i, pr2.x, pr2.y, pr2.vx, pr2.vy, pr2.grounded, pr2.crouching, pr2.mode,
			pr2.course_rotation])
	for action in actions.values():
		Input.action_release(action)
