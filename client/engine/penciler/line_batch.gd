class_name LineBatch
extends MeshInstance2D
## Draws many art lines as one mesh, in order.
##
## Levels imported from PR2 can hold tens of thousands of strokes (pixel art
## made of 2px dots); one Line2D node each is far too slow. A batch keeps the
## line data (for saving and the eraser tool) and draws round-capped,
## round-jointed strokes like Flash's lineStyle. Erase batches cut their shape
## out of the art below them (the Lines node is a CanvasGroup).

const MAX_LINES := 3000
const MAX_VERTICES := 250000

static var erase_material := _make_erase_material()
static var _circles := {}

var erase := false
var lines: Array = [] # {pos: Vector2, points: PackedVector2Array (from pos), color, width}
var vertex_count := 0
var _dirty := false


## Adds a line to the last batch in `holder` (or a new one) and redraws it at
## the end of the frame. `points` start at the line's position (0, 0).
static func add_line(holder: Node, pos: Vector2, points: PackedVector2Array, color: Color,
		width: float, is_erase: bool) -> void:
	var batch: LineBatch = null
	if holder.get_child_count() > 0:
		var last := holder.get_child(holder.get_child_count() - 1)
		if last is LineBatch and last.erase == is_erase and last.lines.size() < MAX_LINES \
				and last.vertex_count < MAX_VERTICES:
			batch = last
	if batch == null:
		batch = LineBatch.new()
		batch.erase = is_erase
		if is_erase:
			batch.material = erase_material
		holder.add_child(batch)
	var line_color := Color.WHITE if is_erase else color
	batch.lines.push_back({"pos": pos, "points": points, "color": line_color, "width": width})
	batch.vertex_count += _estimate_vertices(points.size(), width)
	batch.mark_dirty()


static func _make_erase_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
	return material


func mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		_rebuild.call_deferred()


## The line data in the saved level format.
func encode() -> Array:
	var result := []
	for line in lines:
		var points := []
		var line_points: PackedVector2Array = line.points
		for i in range(1, line_points.size()):
			points.push_back({"x": line_points[i].x, "y": line_points[i].y})
		var data := {"x": line.pos.x, "y": line.pos.y, "points": points,
				"color": line.color.to_html(), "thickness": line.width}
		if erase:
			data.mode = "erase"
		result.push_back(data)
	return result


## Removes lines within `radius` of `center` (Lines-local). Returns true if any went.
func erase_near(center: Vector2, radius: float) -> bool:
	var kept := []
	for line in lines:
		if not _line_touches(line, center, radius):
			kept.push_back(line)
	if kept.size() == lines.size():
		return false
	lines = kept
	vertex_count = 0
	for line in lines:
		vertex_count += _estimate_vertices(line.points.size(), line.width)
	if lines.is_empty():
		queue_free()
	else:
		mark_dirty()
	return true


static func _line_touches(line: Dictionary, center: Vector2, radius: float) -> bool:
	var points: PackedVector2Array = line.points
	var pos: Vector2 = line.pos
	if points.size() == 1:
		return (pos + points[0]).distance_to(center) <= radius
	for i in range(1, points.size()):
		var closest := Geometry2D.get_closest_point_to_segment(center, pos + points[i - 1],
				pos + points[i])
		if closest.distance_to(center) <= radius:
			return true
	return false


func _rebuild() -> void:
	_dirty = false
	if not is_inside_tree() and lines.is_empty():
		return
	var verts := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for line in lines:
		_add_stroke(line, verts, colors, indices)
	if verts.is_empty():
		mesh = null
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh


## One stroke: a quad per segment plus a circle at every point (round caps
## and joins, and a dot for a single point).
static func _add_stroke(line: Dictionary, verts: PackedVector2Array, colors: PackedColorArray,
		indices: PackedInt32Array) -> void:
	var pos: Vector2 = line.pos
	var points: PackedVector2Array = line.points
	var color: Color = line.color
	var half: float = maxf(line.width, 0.5) / 2.0
	var circle := _circle(line.width)
	var previous := Vector2.INF
	for i in points.size():
		var p := pos + points[i]
		if i > 0 and p != previous:
			var normal := (p - previous).orthogonal().normalized() * half
			var base := verts.size()
			verts.append_array([previous + normal, previous - normal, p - normal, p + normal])
			colors.append_array([color, color, color, color])
			indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
		if i == 0 or p != previous:
			var center := verts.size()
			verts.push_back(p)
			colors.push_back(color)
			for corner in circle:
				verts.push_back(p + corner * half)
				colors.push_back(color)
			var count: int = circle.size()
			for k in count:
				indices.append_array([center, center + 1 + k, center + 1 + (k + 1) % count])
		previous = p


## Unit circle points, with more of them for thicker lines.
static func _circle(width: float) -> PackedVector2Array:
	var count := clampi(int(width * 1.5), 8, 40)
	if not _circles.has(count):
		var points := PackedVector2Array()
		for k in count:
			points.push_back(Vector2.from_angle(TAU * k / count))
		_circles[count] = points
	return _circles[count]


static func _estimate_vertices(point_count: int, width: float) -> int:
	return point_count * (clampi(int(width * 1.5), 8, 40) + 5)
