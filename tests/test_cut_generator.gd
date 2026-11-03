extends "res://tests/base_test.gd"

const SHAPES: Array[Vector2i] = [Vector2i(1536, 1024), Vector2i(1024, 1536), Vector2i(1000, 1000), Vector2i(2048, 900)]
const COUNTS: Array[int] = [12, 54, 150]
const MIN_AREA_FRACTION := {"grid": 0.5, "regular": 0.5, "irregular": 0.25}
# The golden slanted tab (see the end of _init). Changing these points means every saved puzzle changes.
const GOLDEN_ROOM := 80.0
var golden_points := PackedVector2Array([
	Vector2(10.5, 20.25), Vector2(20.174, 26.182), Vector2(30.22, 33.118), Vector2(40.155, 40.224),
	Vector2(49.495, 46.667), Vector2(57.757, 51.61), Vector2(64.457, 54.221), Vector2(69.112, 53.664),
	Vector2(71.24, 49.105), Vector2(72.512, 44.661), Vector2(74.927, 42.097), Vector2(78.067, 41.15),
	Vector2(81.512, 41.56), Vector2(84.846, 43.064), Vector2(87.649, 45.4), Vector2(89.502, 48.307),
	Vector2(89.989, 51.522), Vector2(88.689, 54.784), Vector2(85.185, 57.832), Vector2(81.647, 61.513),
	Vector2(82.357, 65.442), Vector2(86.51, 69.641), Vector2(93.302, 74.133), Vector2(101.927, 78.942),
	Vector2(111.58, 84.091), Vector2(121.456, 89.602), Vector2(130.75, 95.5),
])


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
	check(shape_ok, "%s: outlines have positive area in image coordinates (clockwise on screen), are simple, triangulable and inside the image" % label)
	check(count_ok, "%s: outline size matches the face's edge points" % label)
	check(symmetric, "%s: neighbours are symmetric, never self, no duplicates" % label)


## Chains SeededRng.hash2 from 0 over every outline point's x then y, in thousandths, in piece order.
func cut_checksum(pieces: Array[CutPiece]) -> int:
	var h := 0
	for p in pieces:
		for point in p.outline:
			h = SeededRng.hash2(h, roundi(point.x * 1000.0))
			h = SeededRng.hash2(h, roundi(point.y * 1000.0))
	return h


func same_cut(a: Array[CutPiece], b: Array[CutPiece]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i].outline != b[i].outline or a[i].neighbours != b[i].neighbours:
			return false
	return true


## Irregular keeps the grid's topology: convex quads, border corners on the border, jittered inside.
func check_four_sided(graph: CutGraph, w: int, h: int, label: String) -> void:
	# Face 0's corners are 0, 1, stride + 1, stride, as in build_grid_graph.
	var stride := graph.edges[CutGraph.ref_edge(graph.faces[0][3])].from_vertex
	var columns := stride - 1
	var rows := graph.vertices.size() / stride - 1
	check(columns * rows == graph.faces.size(), "%s: lattice is columns by rows" % label)

	var convex := true
	for refs in graph.faces:
		if refs.size() != 4:
			convex = false
			continue
		var corners := PackedVector2Array()
		for ref in refs:
			var edge := graph.edges[CutGraph.ref_edge(ref)]
			corners.append(graph.vertices[edge.to_vertex if CutGraph.ref_reversed(ref) else edge.from_vertex])
		for i in 4:
			var a := corners[(i + 1) % 4] - corners[i]
			var b := corners[(i + 2) % 4] - corners[(i + 1) % 4]
			if a.cross(b) <= 0.0:
				convex = false
	check(convex, "%s: every face is a strictly convex quad" % label)

	var on_border := true
	var jittered := false
	for r in rows + 1:
		for c in columns + 1:
			var v := graph.vertices[r * stride + c]
			if (r == 0 and v.y != 0.0) or (r == rows and v.y != h) or (c == 0 and v.x != 0.0) or (c == columns and v.x != w):
				on_border = false
			if r > 0 and r < rows and v.x != graph.vertices[c].x:
				jittered = true
	check(on_border, "%s: border corners stay on the border" % label)
	check(jittered, "%s: interior corners are jittered" % label)
	var uneven := false
	for c in range(1, columns):
		var left := graph.vertices[c].x - graph.vertices[c - 1].x
		var right := graph.vertices[c + 1].x - graph.vertices[c].x
		if absf(left - right) > 1e-3:
			uneven = true
	check(uneven or columns == 1, "%s: column widths are uneven" % label)


func check_per_edge_seeding(style: String) -> void:
	var graph := CutGenerator.build_graph(1536, 1024, 54, style, 7)
	var tabs := TabShape.for_style(style)
	var per_edge := true
	for k in graph.edges.size():
		var edge := graph.edges[k]
		if edge.is_border():
			continue
		var expected := tabs.edge_points(graph.vertices[edge.from_vertex], graph.vertices[edge.to_vertex], graph.edge_room(k), SeededRng.new(SeededRng.hash2(7, k)))
		if edge.points != expected:
			per_edge = false
	check(per_edge, "%s: each edge depends only on its own id" % style)


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

	check_per_edge_seeding("regular")

	for shape in SHAPES:
		for count in COUNTS:
			check_cut(shape.x, shape.y, count, "irregular", 1)
			for seed_value in [1, 2]:
				var label := "irregular %dx%d count %d seed %d" % [shape.x, shape.y, count, seed_value]
				check_four_sided(CutGenerator.build_graph(shape.x, shape.y, count, "irregular", seed_value), shape.x, shape.y, label)
	check_cut(1536, 1024, 400, "irregular", 1)
	check_cut(160, 120, 400, "irregular", 1)
	check_cut(10, 10, 100000, "irregular", 1)
	check_cut(10000, 100, 50, "irregular", 1)
	check_cut(1000, 3000, 400, "irregular", 1)
	for seed_value in [0, -5, 7]:
		check_cut(1536, 1024, 54, "irregular", seed_value)

	var irregular := CutGenerator.generate_cut(1536, 1024, 54, "irregular", 7)
	check(same_cut(irregular, CutGenerator.generate_cut(1536, 1024, 54, "irregular", 7)), "irregular: same seed gives same cut")
	check(not same_cut(irregular, CutGenerator.generate_cut(1536, 1024, 54, "irregular", 8)), "irregular: seeds 7 and 8 differ")
	check(not same_cut(irregular, regular), "irregular and regular differ for the same seed")
	check_per_edge_seeding("irregular")
	var regular_graph := CutGenerator.build_graph(1536, 1024, 54, "regular", 7)
	var irregular_graph := CutGenerator.build_graph(1536, 1024, 54, "irregular", 7)
	var same_ids := regular_graph.edges.size() == irregular_graph.edges.size()
	for k in mini(regular_graph.edges.size(), irregular_graph.edges.size()):
		var re := regular_graph.edges[k]
		var ie := irregular_graph.edges[k]
		if re.from_vertex != ie.from_vertex or re.to_vertex != ie.to_vertex:
			same_ids = false
	check(same_ids, "irregular edge ids match regular for the same split")

	# Golden values. Saves and daily puzzles store only the seed and regenerate the cut, so if one of
	# these numbers changes, every saved puzzle changes. Do not update them to make a test pass.
	check(cut_checksum(CutGenerator.generate_cut(1536, 1024, 400, "regular", 1)) == 1775637367, "regular 1536x1024 400 seed 1 matches its golden checksum (got %d)" % cut_checksum(CutGenerator.generate_cut(1536, 1024, 400, "regular", 1)))
	check(cut_checksum(CutGenerator.generate_cut(1536, 1024, 400, "irregular", 1)) == 3022635426, "irregular 1536x1024 400 seed 1 matches its golden checksum (got %d)" % cut_checksum(CutGenerator.generate_cut(1536, 1024, 400, "irregular", 1)))
	# Every bit of one slanted tab, so a run on an arm64 phone can confirm it computes the same points.
	var golden_edge := TabShape.for_style("regular").edge_points(Vector2(10.5, 20.25), Vector2(130.75, 95.5), GOLDEN_ROOM, SeededRng.new(SeededRng.hash2(1, 0)))
	check(golden_edge == golden_points, "regular slanted edge matches its golden points (got %s)" % str(golden_edge))

	# The project's own ln, so the split choice cannot depend on a platform's libm.
	var ln_ok := true
	var worst := 0.0
	var x := 1.0e-6
	while x < 1.0e6:
		var err := absf(CutGenerator.ln(x) - log(x))
		worst = maxf(worst, err)
		if err > 1e-12:
			ln_ok = false
		x *= 1.0137
	for value in [1.5, 2.0 / 3.0, 0.5, 2.0, 1.2, 1.0 / 1.2, 0.7071067811865476, 1.4142135623730951, 1.0 + 1e-12, 1.0 - 1e-12]:
		var err := absf(CutGenerator.ln(value) - log(value))
		worst = maxf(worst, err)
		if err > 1e-12:
			ln_ok = false
	check(ln_ok, "CutGenerator.ln matches log within 1e-12 (worst %s)" % str(worst))
	check(CutGenerator.ln(1.0) == 0.0, "ln(1) is exactly 0")

	# A lattice whose cells collapse (more columns than pixels) must fail loudly, not half-build.
	check(CutGenerator.build_grid_graph(2, 2, 4, 1) == null, "a lattice with a rejected face gives no graph")

	check(CutGenerator.generate_cut(1536, 1024, 54, "bogus", 1).is_empty(), "unknown style is empty")
	check(CutGenerator.build_graph(1536, 1024, 54, "bogus", 1) == null, "unknown style gives no graph")
	check(CutGenerator.generate_cut(0, 1024, 54, "grid", 1).is_empty(), "width 0 is empty")
	check(CutGenerator.generate_cut(1536, 1024, 0, "grid", 1).is_empty(), "target 0 is empty")

	finish()
