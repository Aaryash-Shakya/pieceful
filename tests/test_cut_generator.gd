extends BaseTest

const SHAPES: Array[Vector2i] = [Vector2i(1536, 1024), Vector2i(1024, 1536), Vector2i(1000, 1000), Vector2i(2048, 900)]
const COUNTS: Array[int] = [12, 54, 150]
const MIN_AREA_FRACTION := {"grid": 0.5, "regular": 0.5, "irregular": 0.25}


func check_cut(w: int, h: int, count: int, style: String, seed_value: int) -> void:
	var label := "%s %dx%d count %d seed %d" % [style, w, h, count, seed_value]
	var graph := CutGenerator.build_graph(w, h, count, style, seed_value)
	check(graph != null, "%s: build_graph is not null" % label)
	if graph == null:
		return
	var pieces := graph.to_pieces()
	check(pieces.size() == graph.faces.size() and pieces.size() > 0, "%s: one piece per face" % label)
	var ids_ok := true
	for i in pieces.size():
		if pieces[i].id != i:
			ids_ok = false
	check(ids_ok, "%s: piece id is its index" % label)

	# Where each directed ref is used, so a ref appearing twice or in the wrong face is caught.
	var ref_faces := {}
	var duplicate_ref := false
	for face_index in graph.faces.size():
		for ref in graph.faces[face_index]:
			if ref_faces.has(ref):
				duplicate_ref = true
			ref_faces[ref] = face_index
	check(not duplicate_ref, "%s: no directed edge is used twice" % label)
	var refs_ok := true
	var border := 0
	for edge in graph.edges:
		if ref_faces.get(2 * edge.id, -1) != edge.face_a:
			refs_ok = false
		if edge.is_border():
			border += 1
			if ref_faces.has(2 * edge.id + 1):
				refs_ok = false
		elif ref_faces.get(2 * edge.id + 1, -1) != edge.face_b:
			refs_ok = false
		if edge.points[0] != graph.vertices[edge.from_vertex] or edge.points[edge.points.size() - 1] != graph.vertices[edge.to_vertex]:
			refs_ok = false
	check(refs_ok, "%s: edge refs and end points match their faces" % label)
	var split := CutGenerator.grid_split(w, h, count)
	check(border == 2 * (split.x + split.y), "%s: border edge count" % label)

	var total := 0.0
	var min_area := INF
	for p in pieces:
		total += p.area()
		min_area = minf(min_area, p.area())
	check(absf(total - w * h) <= 1e-6 * w * h, "%s: areas sum to image area" % label)
	check(min_area >= MIN_AREA_FRACTION[style] * w * h / pieces.size(), "%s: no piece below its minimum area" % label)

	var shape_ok := true
	var count_ok := true
	var symmetric := true
	for p in pieces:
		if signed_area(p.outline) <= 0.0 or not outline_is_simple(p.outline):
			shape_ok = false
		if Geometry2D.triangulate_polygon(p.outline).size() != (p.outline.size() - 2) * 3:
			shape_ok = false
		if p.outline.size() > CutGenerator.MAX_OUTLINE_POINTS:
			shape_ok = false
		for point in p.outline:
			if point.x < 0.0 or point.x > w or point.y < 0.0 or point.y > h:
				shape_ok = false
		var expected := 0
		for ref in graph.faces[p.id]:
			expected += graph.edges[CutGraph.ref_edge(ref)].points.size() - 1
		if p.outline.size() != expected:
			count_ok = false
		var seen := {}
		for n in p.neighbours:
			if n == p.id or seen.has(n) or not pieces[n].neighbours.has(p.id):
				symmetric = false
			seen[n] = true
	check(shape_ok, "%s: outlines are counter-clockwise, simple, triangulable and inside the image" % label)
	check(count_ok, "%s: outline size matches the face's edge points" % label)
	check(symmetric, "%s: neighbours are symmetric, never self, no duplicates" % label)


func same_cut(a: Array[CutPiece], b: Array[CutPiece]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i].outline != b[i].outline or a[i].neighbours != b[i].neighbours:
			return false
	return true


func signed_area(outline: PackedVector2Array) -> float:
	var sum := 0.0
	var n := outline.size()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


## False if two non-adjacent segments meet or two consecutive points are equal.
func outline_is_simple(outline: PackedVector2Array) -> bool:
	var n := outline.size()
	for i in n:
		if outline[i] == outline[(i + 1) % n]:
			return false
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var box := Rect2(a, Vector2.ZERO).expand(b)
		for j in range(i + 2, n):
			if i == 0 and j == n - 1:
				continue
			var c := outline[j]
			var d := outline[(j + 1) % n]
			if not box.intersects(Rect2(c, Vector2.ZERO).expand(d), true):
				continue
			if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
				return false
	return true


func _init() -> void:
	for count in [1, 12, 54, 150, 400]:
		check(CutGenerator.generate_cut(1536, 1024, count, "grid", 1).size() > 0, "count %d returns pieces" % count)
		check_cut(1536, 1024, count, "grid", 1)

	for shape in SHAPES:
		for count in COUNTS:
			check_cut(shape.x, shape.y, count, "grid", 1)

	check(CutGenerator.grid_split(1500, 1000, 54) == Vector2i(9, 6), "grid_split 54 is 9x6")
	check(CutGenerator.grid_split(1500, 1000, 150) == Vector2i(15, 10), "grid_split 150 is 15x10")

	# Exact ties on a square image: fewer rows must always win.
	check(CutGenerator.grid_split(1000, 1000, 54) == Vector2i(7, 7), "square 54 pins to 7x7")
	check(CutGenerator.grid_split(1000, 1000, 20) == Vector2i(5, 4), "square 20 pins to 5x4")
	check(CutGenerator.grid_split(1000, 1000, 30) == Vector2i(6, 5), "square 30 pins to 6x5")
	check(CutGenerator.grid_split(1000, 1000, 12) == Vector2i(4, 3), "square 12 pins to 4x3")
	check(CutGenerator.grid_split(1000, 1000, 6) == Vector2i(3, 2), "square 6 pins to 3x2")

	var s := CutGenerator.grid_split(1536, 1024, 400)
	check(absi(s.x * s.y - 400) <= 40, "grid_split 400 product within 40")
	var aspect := (1536.0 / s.x) / (1024.0 / s.y)
	check(aspect >= 0.8 and aspect <= 1.25, "grid_split 400 cells near square")

	check(CutGenerator.generate_cut(10000, 100, 50, "grid", 1).size() > 0, "10000x100 returns pieces")
	check_cut(10000, 100, 50, "grid", 1)

	check(CutGenerator.generate_cut(10, 10, 100000, "grid", 1).size() > 0, "oversize count returns pieces")
	check_cut(10, 10, 100000, "grid", 1)
	check(CutGenerator.generate_cut(10, 10, 100000, "grid", 1).size() <= 100, "oversize count is capped by the pixel grid")

	var first := CutGenerator.generate_cut(1500, 1000, 54, "grid", 1)
	check(first[0].outline == PackedVector2Array([Vector2(0, 0), Vector2(167, 0), Vector2(167, 167), Vector2(0, 167)]), "grid piece 0 outline is unchanged")

	var a := CutGenerator.generate_cut(1536, 1024, 54, "grid", 7)
	var b := CutGenerator.generate_cut(1536, 1024, 54, "grid", 7)
	check(same_cut(a, b), "same inputs give same outlines and neighbours")

	for shape in SHAPES:
		for count in COUNTS:
			check_cut(shape.x, shape.y, count, "regular", 1)
	check_cut(1536, 1024, 400, "regular", 1)
	check_cut(160, 120, 400, "regular", 1)
	check_cut(10, 10, 100000, "regular", 1)
	check_cut(10000, 100, 50, "regular", 1)
	check_cut(1000, 3000, 400, "regular", 1)
	for seed_value in [0, -5, 7]:
		check_cut(1536, 1024, 54, "regular", seed_value)

	var regular := CutGenerator.generate_cut(1536, 1024, 54, "regular", 7)
	check(same_cut(regular, CutGenerator.generate_cut(1536, 1024, 54, "regular", 7)), "regular: same seed gives same cut")
	check(not same_cut(regular, CutGenerator.generate_cut(1536, 1024, 54, "regular", 8)), "regular: seeds 7 and 8 differ")
	var tabbed := false
	for p in CutGenerator.generate_cut(1536, 1024, 400, "regular", 1):
		if p.outline.size() > 4:
			tabbed = true
	check(tabbed, "regular 400 has tabbed outlines")

	var graph := CutGenerator.build_graph(1536, 1024, 54, "regular", 7)
	var tabs := TabShape.for_style("regular")
	var per_edge := true
	for k in graph.edges.size():
		var edge := graph.edges[k]
		if edge.is_border():
			continue
		var expected := tabs.edge_points(graph.vertices[edge.from_vertex], graph.vertices[edge.to_vertex], graph.edge_room(k), SeededRng.new(SeededRng.hash2(7, k)))
		if edge.points != expected:
			per_edge = false
	check(per_edge, "regular: each edge depends only on its own id")

	check(CutGenerator.generate_cut(1536, 1024, 54, "bogus", 1).is_empty(), "unknown style is empty")
	check(CutGenerator.build_graph(1536, 1024, 54, "bogus", 1) == null, "unknown style gives no graph")
	check(CutGenerator.generate_cut(0, 1024, 54, "grid", 1).is_empty(), "width 0 is empty")
	check(CutGenerator.generate_cut(1536, 1024, 0, "grid", 1).is_empty(), "target 0 is empty")

	finish()
