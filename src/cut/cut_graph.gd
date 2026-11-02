class_name CutGraph
extends RefCounted
## Vertices, shared edges and the faces between them. Every face winds the same way, so a shared edge
## is walked in opposite directions. A face lists directed edge refs: 2 * id forward, 2 * id + 1 backward.

var vertices: PackedVector2Array
var edges: Array[CutEdge] = []
var faces: Array[PackedInt32Array] = []

var _edge_ids := {}


static func edge_key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


static func ref_edge(ref: int) -> int:
	return ref >> 1


static func ref_reversed(ref: int) -> bool:
	return (ref & 1) == 1


## Adds a face given by its corner vertices and returns its index. Returns -1 and leaves the graph
## untouched if the corners do not have positive signed area (the shared winding), or if an edge
## would be used by a third face, twice in the same direction, or twice by this face.
func add_face(corners: PackedInt32Array) -> int:
	var n := corners.size()
	var area := 0.0
	var seen := {}
	for i in n:
		var from_vertex := corners[i]
		var to_vertex := corners[(i + 1) % n]
		var a := vertices[from_vertex]
		var b := vertices[to_vertex]
		area += a.x * b.y - b.x * a.y
		var key := edge_key(from_vertex, to_vertex)
		if seen.has(key):
			push_error("CutGraph.add_face: the face uses edge %d-%d twice" % [from_vertex, to_vertex])
			return -1
		seen[key] = true
		if _edge_ids.has(key):
			var existing := edges[_edge_ids[key]]
			if existing.from_vertex != to_vertex or existing.face_b != -1:
				push_error("CutGraph.add_face: edge %d-%d is already used that way" % [from_vertex, to_vertex])
				return -1
	if area <= 0.0:
		push_error("CutGraph.add_face: corners must have positive signed area, got %f" % (area * 0.5))
		return -1

	var face_index := faces.size()
	var refs := PackedInt32Array()
	for i in n:
		var from_vertex := corners[i]
		var to_vertex := corners[(i + 1) % n]
		var key := edge_key(from_vertex, to_vertex)
		if not _edge_ids.has(key):
			var edge := CutEdge.new()
			edge.id = edges.size()
			edge.from_vertex = from_vertex
			edge.to_vertex = to_vertex
			edge.face_a = face_index
			edge.points = PackedVector2Array([vertices[from_vertex], vertices[to_vertex]])
			_edge_ids[key] = edge.id
			edges.append(edge)
			refs.append(2 * edge.id)
			continue
		var existing := edges[_edge_ids[key]]
		existing.face_b = face_index
		refs.append(2 * existing.id + 1)
	faces.append(refs)
	return face_index


## Signed area of the face's corner polygon, ignoring the points between corners.
func corner_area(face: int) -> float:
	var refs := faces[face]
	var sum := 0.0
	for ref in refs:
		var edge := edges[ref_edge(ref)]
		var a := vertices[edge.to_vertex if ref_reversed(ref) else edge.from_vertex]
		var b := vertices[edge.from_vertex if ref_reversed(ref) else edge.to_vertex]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


## How far an interior edge can bulge sideways before it risks crossing into a neighbour's body.
func edge_room(edge_id: int) -> float:
	var edge := edges[edge_id]
	if edge.is_border():
		return 0.0
	# 64-bit GDScript floats, not Vector2.distance_to, so every CPU gets the same room (see TabShape).
	var a := vertices[edge.from_vertex]
	var b := vertices[edge.to_vertex]
	var dx: float = b.x - a.x
	var dy: float = b.y - a.y
	var length := sqrt(dx * dx + dy * dy)
	if length == 0.0:
		return 0.0
	return minf(length, minf(corner_area(edge.face_a), corner_area(edge.face_b)) / length)


func to_pieces() -> Array[CutPiece]:
	var pieces: Array[CutPiece] = []
	for face_index in faces.size():
		var piece := CutPiece.new()
		piece.id = face_index
		var outline := PackedVector2Array()
		for ref in faces[face_index]:
			var edge := edges[ref_edge(ref)]
			var points := edge.points.duplicate()
			if ref_reversed(ref):
				points.reverse()
			points.resize(points.size() - 1)
			outline.append_array(points)
			if not edge.is_border():
				piece.neighbours.append(edge.face_a if ref_reversed(ref) else edge.face_b)
		piece.outline = outline
		piece.home = piece.bounds().get_center()
		pieces.append(piece)
	return pieces
