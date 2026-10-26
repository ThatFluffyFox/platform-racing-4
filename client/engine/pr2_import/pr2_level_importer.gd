class_name Pr2LevelImporter
## Loads Platform Racing 2 levels from pr2hub.com and converts them to PR4 levels.
##
## Desktop builds and the Godot editor fetch straight from pr2hub.com. Browser
## builds can't (pr2hub.com doesn't allow cross-site requests), so they go
## through the PR4 API, which runs the same conversion on the server
## (api/internal/pr2_level_import). This file is a port of that Go code.

const PR2HUB_URL := "https://pr2hub.com"
const UPSCALE_RATIO := 4.2666666667 # PR4 tile size / PR2 tile size (128 / 30)
const HASH_LENGTH := 32
const BLOCK_CHUNK_SIZE := 8
const MODE_DRAW := "draw"

const MUSIC := {
	"1": "orbital-trance", "2": "code", "3": "paradise-on-e", "4": "crying-soul",
	"5": "my-vision", "6": "switchblade", "7": "the-wires", "8": "before-mydnite",
	"10": "broked-it", "11": "hello", "12": "pyrokinesis", "13": "flowerz-n-herbz",
	"14": "instrumental-4", "15": "prismatic", "17": "oodaloo", "18": "night-shade",
	"19": "blizzard", "20": "pasture-instrumental", "21": "sunset-raiders",
}
const BACKGROUNDS := {
	"BG1": "field", "201": "field", "BG2": "generic", "202": "generic",
	"BG3": "lake", "203": "lake", "BG4": "desert", "204": "desert",
	"BG5": "dots", "205": "dots", "BG6": "space", "206": "space",
	"BG7": "skyscraper", "207": "skyscraper",
}


static func fetches_directly() -> bool:
	return not OS.has_feature("web")


static func level_url(level_id: String) -> String:
	if fetches_directly():
		return PR2HUB_URL + "/levels/" + level_id + ".txt"
	return ApiManager.get_base_url() + "/pr2/level/" + level_id


## Level list pages, e.g. type "newest", "best", "best_today", "campaign".
static func list_url(list_type: String, page: int) -> String:
	var base := PR2HUB_URL if fetches_directly() else ApiManager.get_base_url()
	return base + "/files/lists/" + list_type + "/" + str(page)


## Downloads and converts a PR2 level. Returns the PR4 level, or a Dictionary
## with an "error" message. `holder` is any node in the scene tree.
static func fetch(holder: Node, level_id: String) -> Dictionary:
	level_id = level_id.strip_edges()
	if not level_id.is_valid_int() or int(level_id) <= 0:
		return {"error": "\"%s\" is not a PR2 level ID." % level_id}

	var http := HTTPRequest.new()
	holder.add_child(http)
	var error := http.request(level_url(level_id))
	if error != OK:
		http.queue_free()
		return {"error": "Couldn't start the download (error %d)." % error}
	var response: Array = await http.request_completed
	http.queue_free()

	var result: int = response[0]
	var code: int = response[1]
	var body: PackedByteArray = response[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Couldn't reach the level server (result %d)." % result}
	if code != 200:
		return {"error": "Level %s wasn't found (HTTP %d)." % [level_id, code]}

	var level: Dictionary
	if fetches_directly():
		level = convert_level(body.get_string_from_utf8())
	else:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		level = parsed if parsed is Dictionary else {}
	if level.is_empty() or level.has("error"):
		return {"error": level.get("error", "Level %s couldn't be read." % level_id)}

	# PR2 levels play with PR2 physics unless the creator turns it off.
	var properties: Dictionary = level.get("properties", {})
	var overrides: Dictionary = properties.get("game_config_overrides", {})
	if not overrides.has("pr2_physics"):
		overrides["pr2_physics"] = true
	properties["game_config_overrides"] = overrides
	level["properties"] = properties
	return level


# ---------------------------------------------------------------------------
# Conversion (port of api/internal/pr2_level_import)
# ---------------------------------------------------------------------------

## Converts the text of a pr2hub.com level file into a PR4 level Dictionary.
static func convert_level(text: String) -> Dictionary:
	var pr2 := parse_level(text)
	if pr2.data == "":
		return {"error": "That isn't a PR2 level file."}
	var sections := _parse_main_sections(pr2.data)

	var art_layers := []
	for art in sections.art_layers:
		art_layers.push_back(_parse_art(art))

	var block_chunks := _parse_blocks(sections.blocks)
	var layers := []
	if art_layers.size() >= 6:
		layers = [
			_layer("Art 1", art_layers[3], 10, UPSCALE_RATIO),
			{"name": "Blocks", "chunks": block_chunks, "lines": [], "depth": 10, "scale": 1},
			_layer("Art 2", art_layers[4], 5, UPSCALE_RATIO),
			_layer("Art 3", art_layers[5], 2, UPSCALE_RATIO),
		]
	if art_layers.size() >= 10:
		layers.push_back(_layer("Art 0", art_layers[8], 10, UPSCALE_RATIO))
		layers.push_back(_layer("Art 00", art_layers[9], 16, UPSCALE_RATIO))

	return {
		"layers": layers,
		"properties": {
			"title": pr2.title,
			"items": _parse_items(pr2.items),
			"note": pr2.note,
			"gravity": pr2.gravity.to_float() if pr2.gravity != "" else 1.0,
			"music": MUSIC.get(pr2.song, ""),
			"levelId": pr2.level_id.to_float(),
			"background": BACKGROUNDS.get(sections.bg, "blank"),
			"fadeColor": sections.fade_color,
		},
	}


static func _layer(name: String, lines: Array, depth: int, scale: float) -> Dictionary:
	return {"name": name, "chunks": [], "lines": lines, "depth": depth, "scale": scale}


## Splits a level file into its fields. The last 32 characters are a hash.
static func parse_level(text: String) -> Dictionary:
	text = text.strip_edges()
	var fields := {}
	if text.length() > HASH_LENGTH:
		text = text.substr(0, text.length() - HASH_LENGTH)
	for pair in text.split("&"):
		var eq := pair.find("=")
		if eq <= 0:
			continue
		var key := pair.substr(0, eq)
		if not fields.has(key):
			fields[key] = pair.substr(eq + 1).replace("+", " ").uri_decode()
	return {
		"title": fields.get("title", ""),
		"items": fields.get("items", ""),
		"note": fields.get("note", ""),
		"gravity": fields.get("gravity", ""),
		"song": fields.get("song", ""),
		"level_id": fields.get("level_id", fields.get("levelId", "0")),
		"data": fields.get("data", ""),
	}


static func _parse_main_sections(data: String) -> Dictionary:
	var parts := data.split("`")
	parts.remove_at(0) # file version, e.g. "m3"
	while parts.size() < 9:
		parts.push_back("")
	var art_layers := [
		_safe_split(parts[2]), # objects 1
		_safe_split(parts[3]), # objects 2
		_safe_split(parts[4]), # objects 3
		_safe_split(parts[5]), # lines 1
		_safe_split(parts[6]), # lines 3
		_safe_split(parts[7]), # lines 2
	]
	if parts.size() > 12:
		art_layers.append_array([
			_safe_split(parts[9]), # objects 0
			_safe_split(parts[10]), # objects 00
			_safe_split(parts[11]), # lines 0
			_safe_split(parts[12]), # lines 00
		])
	return {
		"fade_color": parts[0],
		"blocks": _safe_split(parts[1]),
		"bg": parts[8],
		"art_layers": art_layers,
	}


static func _safe_split(text: String) -> Array:
	if text == "":
		return []
	return Array(text.split(","))


static func _parse_items(text: String) -> Array:
	if text == "":
		return []
	return Array(text.split("`"))


## Blocks are "dx;dy[;code[;options]]", relative to the previous block.
static func _parse_blocks(commands: Array) -> Array:
	var chunks := {}
	var x := 0
	var y := 0
	var tile_id := 0
	for command in commands:
		if command == "":
			continue
		var parts: PackedStringArray = command.split(";")
		x += parts[0].to_int()
		if parts.size() > 1:
			y += parts[1].to_int()
		if parts.size() > 2 and parts[2] != "":
			var code := parts[2].to_int()
			tile_id = code - 99 if code >= 100 else code + 1
			if tile_id == 13 or tile_id == 14 or tile_id == 15:
				tile_id = 12 # extra start positions become start #1
			elif tile_id == 22:
				tile_id = 23 # PR2's rotate right is PR4's counterclockwise
			elif tile_id == 23:
				tile_id = 22
		_place_tile(chunks, x, y, tile_id)
	return chunks.values()


static func _place_tile(chunks: Dictionary, x: int, y: int, tile_id: int) -> void:
	var size := BLOCK_CHUNK_SIZE
	var chunk_x := floori(x / float(size)) * size
	var chunk_y := floori(y / float(size)) * size
	var key := str(chunk_x) + "," + str(chunk_y)
	if not chunks.has(key):
		var data := []
		data.resize(size * size)
		data.fill(0)
		chunks[key] = {"x": chunk_x, "y": chunk_y, "width": size, "height": size, "data": data}
	chunks[key].data[(y - chunk_y) * size + (x - chunk_x)] = tile_id


# ---------------------------------------------------------------------------
# Art lines
# ---------------------------------------------------------------------------

static func _parse_art(commands: Array) -> Array:
	var color := "000000"
	var mode := MODE_DRAW
	var thickness := 4
	var lines := []
	for command in commands:
		if command == "":
			continue
		var content: String = command.substr(1)
		match command[0]:
			"c":
				color = content.lpad(6, "0")
			"t":
				thickness = content.to_int()
			"d":
				lines.push_back(_parse_line(content, color, thickness, mode))
			"m":
				mode = content
	# Eraser strokes stay in order as "erase" lines: like Flash PR2, they cut
	# their shape out of whatever this layer drew before them.
	return lines


static func _parse_line(text: String, color: String, thickness: int, mode: String) -> Dictionary:
	var values := text.split(";")
	var points := []
	var x := 0
	var y := 0
	var i := 2
	while i + 1 < values.size():
		var dx := values[i].to_int()
		var dy := values[i + 1].to_int()
		if dx != 0 or dy != 0:
			x += dx
			y += dy
			points.push_back({"x": float(x), "y": float(y)})
		i += 2
	return {
		"x": float(values[0].to_int()),
		"y": float(values[1].to_int()) if values.size() > 1 else 0.0,
		"points": points,
		"color": color.rpad(6, "0"),
		"thickness": thickness,
		"mode": "erase" if mode == "erase" else MODE_DRAW,
	}
