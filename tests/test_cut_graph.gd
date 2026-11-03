extends "res://tests/base_test.gd"


func two_squares() -> CutGraph:
	var graph := CutGraph.new()
	graph.vertices = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(2, 0),
		Vector2(0, 1), Vector2(1, 1), Vector2(2, 1),
	])
	graph.add_face(PackedInt32Array([0, 1, 4, 3]))
	graph.add_face(PackedInt32Array([1, 2, 5, 4]))
	return graph


## Everything add_face may touch, as plain values that compare with ==.
func graph_state(graph: CutGraph) -> Array:
	var state := [graph.faces.duplicate(), graph._edge_ids.duplicate()]
	for edge in graph.edges:
		state.append([edge.id, edge.from_vertex, edge.to_vertex, edge.face_a, edge.face_b, edge.points])
	return state


func _init() -> void:
	var graph := CutGraph.new()
	graph.vertices = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(2, 0),
		Vector2(0, 1), Vector2(1, 1), Vector2(2, 1),
	])
	check(graph.add_face(PackedInt32Array([0, 1, 4, 3])) == 0, "first add_face returns 0")
	check(graph.add_face(PackedInt32Array([1, 2, 5, 4])) == 1, "second add_face returns 1")
	check(graph.edges.size() == 7, "two squares have seven edges")
	var border := 0
	for edge in graph.edges:
		if edge.is_border():
			border += 1
	check(border == 6, "six edges are on the border")

	check(graph.faces[0] == PackedInt32Array([0, 2, 4, 6]), "face 0 refs")
	check(graph.faces[1] == PackedInt32Array([8, 10, 12, 3]), "face 1 refs, the shared edge reversed")

	var shared := graph.edges[1]
	check(shared.from_vertex == 1 and shared.to_vertex == 4, "shared edge runs from vertex 1 to 4")
	check(shared.face_a == 0 and shared.face_b == 1, "shared edge faces")
	check(shared.points == PackedVector2Array([Vector2(1, 0), Vector2(1, 1)]), "shared edge starts straight")
	check(not shared.is_border(), "shared edge is interior")

	check(CutGraph.ref_edge(3) == 1, "ref_edge of a backward ref")
	check(CutGraph.ref_reversed(3), "ref 3 is reversed")
	check(not CutGraph.ref_reversed(2), "ref 2 is forward")
	check(is_equal_approx(graph.corner_area(0), 1.0), "corner_area of a unit square")
	check(is_equal_approx(graph.edge_room(1), 1.0), "edge_room of the shared edge")

	var pieces := graph.to_pieces()
	check(pieces.size() == 2, "two pieces")
	check(pieces[0].id == 0 and pieces[1].id == 1, "piece ids follow faces")
	check(pieces[0].outline == PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), "piece 0 outline")
	check(pieces[1].outline == PackedVector2Array([Vector2(1, 0), Vector2(2, 0), Vector2(2, 1), Vector2(1, 1)]), "piece 1 outline")
	check(pieces[0].neighbours == PackedInt32Array([1]), "piece 0 neighbours")
	check(pieces[1].neighbours == PackedInt32Array([0]), "piece 1 neighbours")

	shared.points = PackedVector2Array([Vector2(1, 0), Vector2(1.2, 0.5), Vector2(1, 1)])
	pieces = graph.to_pieces()
	check(pieces[0].outline == PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1.2, 0.5), Vector2(1, 1), Vector2(0, 1)]), "piece 0 follows the bent edge")
	check(pieces[1].outline == PackedVector2Array([Vector2(1, 0), Vector2(2, 0), Vector2(2, 1), Vector2(1, 1), Vector2(1.2, 0.5)]), "piece 1 follows the bent edge reversed")
	check(is_equal_approx(pieces[0].area() + pieces[1].area(), 2.0), "bent edge keeps the total area")

	# Room feeds every tab, so it must be the same 64-bit value on every CPU, not a 32-bit distance.
	var slanted := CutGraph.new()
	slanted.vertices = PackedVector2Array([
		Vector2(0, 0), Vector2(91.317, 3.211), Vector2(180.5, 0),
		Vector2(2.5, 77.123), Vector2(97.901, 83.777), Vector2(181.25, 79.5),
	])
	slanted.add_face(PackedInt32Array([0, 1, 4, 3]))
	slanted.add_face(PackedInt32Array([1, 2, 5, 4]))
	var a := slanted.vertices[1]
	var b := slanted.vertices[4]
	var dx: float = b.x - a.x
	var dy: float = b.y - a.y
	var length := sqrt(dx * dx + dy * dy)
	var expected := minf(length, minf(slanted.corner_area(0), slanted.corner_area(1)) / length)
	check(slanted.edge_room(1) == expected, "edge_room is computed in 64-bit (%.12f, expected %.12f)" % [slanted.edge_room(1), expected])
	var square := CutGraph.new()
	square.vertices = PackedVector2Array([
		Vector2(0, 0), Vector2(300.125, 0), Vector2(600.25, 0),
		Vector2(0, 0.375), Vector2(305.333, 13.417), Vector2(600.25, 0.5),
	])
	square.add_face(PackedInt32Array([0, 1, 4, 3]))
	square.add_face(PackedInt32Array([1, 2, 5, 4]))
	dx = square.vertices[4].x - square.vertices[1].x
	dy = square.vertices[4].y - square.vertices[1].y
	length = sqrt(dx * dx + dy * dy)
	check(square.edge_room(1) == length, "a short edge's room is its 64-bit length")

	# A rejected face must leave the graph exactly as it was. This one adds a new edge, then would
	# claim edge 3-4's free side, then clashes on its third edge (1-4 already has both faces).
	var clash := two_squares()
	clash.vertices.append(Vector2(2, 3))
	var before := graph_state(clash)
	check(clash.add_face(PackedInt32Array([6, 3, 4, 1])) == -1, "a face clashing on its third edge is rejected")
	check(graph_state(clash) == before, "a rejected face leaves edges, faces and every face_b unchanged")
	clash.vertices.append(Vector2(3, 0))
	check(clash.add_face(PackedInt32Array([2, 7, 5])) == 2, "the next face still gets the next index")
	check(clash.edges.size() == 9 and clash.edges[7].from_vertex == 2 and clash.edges[7].to_vertex == 7, "the next face's edges get the next ids")

	# Positive area, but walks edge 1-2 both ways itself.
	var twice := CutGraph.new()
	twice.vertices = PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2)])
	check(twice.add_face(PackedInt32Array([0, 1, 2, 1, 3])) == -1, "a face using one edge twice is rejected")
	check(twice.edges.is_empty() and twice.faces.is_empty(), "a face using one edge twice leaves the graph empty")

	# The winding contract is enforced when a face is added, so room can never come out negative.
	var wound := two_squares()
	wound.vertices.append_array(PackedVector2Array([Vector2(0, 2), Vector2(1, 2), Vector2(0, 3), Vector2(1, 3), Vector2(2, 2)]))
	var wound_before := graph_state(wound)
	check(wound.add_face(PackedInt32Array([6, 8, 9, 7])) == -1, "a face wound the wrong way is rejected")
	check(graph_state(wound) == wound_before, "a wrongly wound face leaves the graph unchanged")
	check(wound.add_face(PackedInt32Array([6, 7, 10])) == -1, "a face with zero area is rejected")
	check(graph_state(wound) == wound_before, "a zero-area face leaves the graph unchanged")
	check(wound.add_face(PackedInt32Array([6, 7, 9, 8])) == 2, "the same face wound the right way is accepted")

	# Collapse the shared edge and face 0 so the room would be 0 / 0.
	graph.vertices[3] = Vector2(0, 0)
	graph.vertices[4] = Vector2(1, 0)
	check(graph.edge_room(1) == 0.0, "edge_room of a zero-length edge is 0")

	finish()
