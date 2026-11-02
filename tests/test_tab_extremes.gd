extends BaseTest
## Outlines must stay simple even when every tab draw lands on an extreme: a crossing outline fails
## triangulation and its piece would not draw. For a given lattice the tab draws are exhaustive: a
## crossing between two curves depends only on the draws those two curves read, so checking every curve
## pair in every combination of its own draws covers every tab combination of the whole cut. Lattices
## are sampled: real seeded cuts, plus 8 lattices with every lattice draw on an extreme.

const SHAPES: Array[Vector2i] = [Vector2i(1536, 1024), Vector2i(1024, 1536), Vector2i(1000, 1000), Vector2i(2048, 900)]
# Draws in TabShape.edge_points order: flip, size, shift, a, c, d, e.
const DRAWS := 7
# The draws each of the three curves reads: shoulder, knob, shoulder.
const CURVE_MASKS: Array[int] = [0b0111111, 0b0110111, 0b1110111]
# Each curve's first and last point among an edge's TabShape.POINTS_PER_EDGE.
const CURVE_FIRST: Array[int] = [0, 8, 18]
const CURVE_LAST: Array[int] = [8, 18, 26]
const LATTICE_SEEDS := 8


## Gives each draw the lowest or highest value SeededRng can return, one bit per draw.
class ExtremeRng extends SeededRng:
	const HIGH := 4294967295.0 / 4294967296.0
	var bits: int
	var draw := 0

	func _init(bits_value: int) -> void:
		super(1)
		bits = bits_value

	func next_float() -> float:
		var high := ((bits >> draw) & 1) == 1
		draw += 1
		return HIGH if high else 0.0


## Lands every draw on an extreme, picking which from its own sequence, so a lattice gets its
## widest size spread and its sharpest corners.
class CoinRng extends SeededRng:
	const HIGH := 4294967295.0 / 4294967296.0

	func next_float() -> float:
		return HIGH if ((next_u32() >> 16) & 1) == 1 else 0.0


## One curve of an edge in every combination of the draws it reads.
class TabCurve:
	var polylines: Array[PackedVector2Array] = []
	var boxes: Array[Rect2] = []
	var union: Rect2

	func add(points: PackedVector2Array) -> void:
		var box := Rect2(points[0], Vector2.ZERO)
		for p in points:
			box = box.expand(p)
		union = box if polylines.is_empty() else union.merge(box)
		polylines.append(points)
		boxes.append(box)


## Fills full with the edge's whole polyline for every draw combination.
func edge_curves(graph: CutGraph, edge_id: int, tabs: TabShape, full: Array[PackedVector2Array]) -> Array[TabCurve]:
	var edge := graph.edges[edge_id]
	var from := graph.vertices[edge.from_vertex]
	var to := graph.vertices[edge.to_vertex]
	var room := graph.edge_room(edge_id)
	var curves: Array[TabCurve] = []
	if edge.is_border() or room < TabShape.MIN_ROOM:
		var straight := TabCurve.new()
		straight.add(PackedVector2Array([from, to]))
		curves.append(straight)
		full.append(PackedVector2Array([from, to]))
		return curves
	for k in 3:
		curves.append(TabCurve.new())
	for bits in 1 << DRAWS:
		var points := tabs.edge_points(from, to, room, ExtremeRng.new(bits))
		full.append(points)
		for k in 3:
			if bits & ~CURVE_MASKS[k] == 0:
				curves[k].add(points.slice(CURVE_FIRST[k], CURVE_LAST[k] + 1))
	return curves


## Whether two polylines meet anywhere except where segment skip_p of p meets segment skip_q of q.
func polylines_cross(p: PackedVector2Array, q: PackedVector2Array, q_box: Rect2, skip_p: int, skip_q: int) -> bool:
	for i in p.size() - 1:
		var a := p[i]
		var b := p[i + 1]
		var box := Rect2(a, Vector2.ZERO).expand(b)
		if not box.intersects(q_box, true):
			continue
		for j in q.size() - 1:
			if i == skip_p and j == skip_q:
				continue
			var c := q[j]
			var d := q[j + 1]
			if not box.intersects(Rect2(c, Vector2.ZERO).expand(d), true):
				continue
			if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
				return true
	return false


## Whether a polyline meets itself anywhere but between consecutive segments.
func polyline_crosses_itself(p: PackedVector2Array) -> bool:
	var n := p.size() - 1
	for i in n:
		var a := p[i]
		var b := p[i + 1]
		var box := Rect2(a, Vector2.ZERO).expand(b)
		for j in range(i + 2, n):
			var c := p[j]
			var d := p[j + 1]
			if not box.intersects(Rect2(c, Vector2.ZERO).expand(d), true):
				continue
			if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
				return true
	return false


## The segment of curve k that touches vertex, or -1.
func incident_segment(edge: CutEdge, curves: Array[TabCurve], k: int, vertex: int) -> int:
	if edge.from_vertex == vertex and k == 0:
		return 0
	if edge.to_vertex == vertex and k == curves.size() - 1:
		return curves[k].polylines[0].size() - 2
	return -1


## Counts outline crossings over every face and every extreme draw combination.
func count_crossings(graph: CutGraph, tabs: TabShape) -> int:
	var curves: Array = []
	var crossings := 0
	for id in graph.edges.size():
		var full: Array[PackedVector2Array] = []
		curves.append(edge_curves(graph, id, tabs, full))
		for points in full:
			if polyline_crosses_itself(points):
				crossings += 1
	for refs in graph.faces:
		for i in refs.size():
			for j in range(i + 1, refs.size()):
				var ea := graph.edges[CutGraph.ref_edge(refs[i])]
				var eb := graph.edges[CutGraph.ref_edge(refs[j])]
				var shared := -1
				for v in [ea.from_vertex, ea.to_vertex]:
					if v == eb.from_vertex or v == eb.to_vertex:
						shared = v
				var ca: Array[TabCurve] = curves[ea.id]
				var cb: Array[TabCurve] = curves[eb.id]
				for ka in ca.size():
					for kb in cb.size():
						crossings += count_curve_crossings(ca[ka], cb[kb], incident_segment(ea, ca, ka, shared), incident_segment(eb, cb, kb, shared))
	return crossings


func count_curve_crossings(a: TabCurve, b: TabCurve, skip_a: int, skip_b: int) -> int:
	if not a.union.intersects(b.union, true):
		return 0
	var crossings := 0
	for va in a.polylines.size():
		if not a.boxes[va].intersects(b.union, true):
			continue
		for vb in b.polylines.size():
			if not a.boxes[va].intersects(b.boxes[vb], true):
				continue
			if polylines_cross(a.polylines[va], b.polylines[vb], b.boxes[vb], skip_a if skip_b >= 0 else -1, skip_b if skip_a >= 0 else -1):
				crossings += 1
	return crossings


## The smallest interior angle of any face corner, in degrees.
func sharpest_corner(graph: CutGraph) -> float:
	var sharpest := 180.0
	for refs in graph.faces:
		var corners := PackedVector2Array()
		for ref in refs:
			var edge := graph.edges[CutGraph.ref_edge(ref)]
			corners.append(graph.vertices[edge.to_vertex if CutGraph.ref_reversed(ref) else edge.from_vertex])
		var n := corners.size()
		for i in n:
			var along := corners[(i + 1) % n] - corners[i]
			var back := corners[(i + n - 1) % n] - corners[i]
			sharpest = minf(sharpest, rad_to_deg(absf(along.angle_to(back))))
	return sharpest


func check_simple(graph: CutGraph, tabs: TabShape, label: String) -> void:
	var crossings := count_crossings(graph, tabs)
	check(crossings == 0, "%s: no outline crosses itself at extreme draws (%d crossings)" % [label, crossings])


func _init() -> void:
	var probe := ExtremeRng.new(0b10)
	check(probe.range_float(-1.0, 1.0) == -1.0 and probe.range_float(-1.0, 1.0) > 0.999, "ExtremeRng drives range_float to its ends")
	# Positive control: the first Irregular values crossed in plain square cells, so a detector that
	# finds nothing here is broken, not passing.
	var old_irregular := TabShape.new(0.10, 0.15, 0.08, 0.06)
	var old_crossings := count_crossings(CutGenerator.build_grid_graph(300, 300, 3, 3), old_irregular)
	check(old_crossings > 0, "the old Irregular tabs cross on a 3x3 grid (%d crossings)" % old_crossings)

	for style in ["regular", "irregular"]:
		var tabs := TabShape.for_style(style)
		# Square cells are where the knobs have the most room, then the widest cells a count allows.
		check_simple(CutGenerator.build_grid_graph(300, 300, 3, 3), tabs, "%s square cells" % style)
		check_simple(CutGenerator.build_grid_graph(360, 300, 3, 3), tabs, "%s 1.2:1 cells" % style)
		check_simple(CutGenerator.build_grid_graph(600, 300, 3, 3), tabs, "%s 2:1 cells" % style)

	var irregular := TabShape.for_style("irregular")
	for shape in SHAPES:
		for count in [12, 54]:
			for seed_value in [1, 2]:
				var label := "irregular %dx%d count %d seed %d" % [shape.x, shape.y, count, seed_value]
				check_simple(CutGenerator.build_graph(shape.x, shape.y, count, "irregular", seed_value), irregular, label)
	check_simple(CutGenerator.build_graph(1536, 1024, 150, "irregular", 3), irregular, "irregular 1536x1024 count 150 seed 3")

	# Lattices with every width, height and corner draw on an extreme as well as every tab draw.
	var sharpest := 180.0
	for seed_value in range(1, LATTICE_SEEDS + 1):
		var columns := 5 if seed_value % 2 == 0 else 7
		var graph := CutGenerator.build_irregular_graph(200 * columns, 1000, columns, 5, CoinRng.new(seed_value))
		sharpest = minf(sharpest, sharpest_corner(graph))
		check_simple(graph, irregular, "extreme irregular lattice %d" % seed_value)
	# Guards the case above: it only pins anything if its corners are as sharp as the lattice allows.
	check(sharpest < 72.0, "extreme lattices reach sharp corners (%.1f degrees)" % sharpest)

	finish()
