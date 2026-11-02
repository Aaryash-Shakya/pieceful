extends BaseTest


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

	# Collapse the shared edge and face 0 so the room would be 0 / 0.
	graph.vertices[3] = Vector2(0, 0)
	graph.vertices[4] = Vector2(1, 0)
	check(graph.edge_room(1) == 0.0, "edge_room of a zero-length edge is 0")

	finish()
