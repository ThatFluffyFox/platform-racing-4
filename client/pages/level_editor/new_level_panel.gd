extends PanelContainer
## Level editor panel for starting a new level, as a PR4 or a PR2 level.
##
## A PR2 level is laid out where PR2's own editor puts a new level (far from
## 0, 0) and uses PR2 physics, so PR2's position-dependent quirks behave
## exactly like in PR2.

signal level_chosen(level: Dictionary)

const START_BLOCK := 12
const CHUNK_SIZE := 8
# PR2's editor adds its four start blocks at x = code * 30 + 10000 (codes
# 111-114) and y = 60 + 10000 pixels, i.e. tiles 444-447 on row 335.
const PR2_START_TILES: Array[Vector2i] = [
	Vector2i(444, 335), Vector2i(445, 335), Vector2i(446, 335), Vector2i(447, 335),
]


func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Start a new level? This replaces the level you're editing."
	column.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_add_button(row, "New PR4 level", func(): _choose(pr4_level()))
	_add_button(row, "New PR2 level", func(): _choose(pr2_level()))
	_add_button(row, "Cancel", close)

	var note := Label.new()
	note.text = "PR2 levels use PR2 physics and PR2's level coordinates."
	note.modulate = Color(1, 1, 1, 0.7)
	column.add_child(note)

	hide()


func _add_button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)


func initialize() -> void:
	show()


func close() -> void:
	hide()


func _choose(level: Dictionary) -> void:
	close()
	level_chosen.emit(level)


static func pr4_level() -> Dictionary:
	return {
		"layers": [{"name": "Layer 1", "chunks": [], "rotation": 0, "depth": 10}],
	}


static func pr2_level() -> Dictionary:
	var chunks := {}
	for tile in PR2_START_TILES:
		var origin := Vector2i(
				floori(tile.x / float(CHUNK_SIZE)) * CHUNK_SIZE,
				floori(tile.y / float(CHUNK_SIZE)) * CHUNK_SIZE)
		var key := str(origin)
		if not chunks.has(key):
			var data := []
			data.resize(CHUNK_SIZE * CHUNK_SIZE)
			data.fill(0)
			chunks[key] = {
				"x": origin.x, "y": origin.y,
				"width": CHUNK_SIZE, "height": CHUNK_SIZE, "data": data,
			}
		var local := tile - origin
		chunks[key].data[local.y * CHUNK_SIZE + local.x] = START_BLOCK
	return {
		"layers": [{"name": "Blocks", "chunks": chunks.values(), "rotation": 0, "depth": 10}],
		"properties": {"game_config_overrides": {"pr2_physics": true}},
	}
