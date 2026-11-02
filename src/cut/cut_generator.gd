class_name CutGenerator
extends RefCounted

const STYLE_GRID := "grid"
const STYLE_REGULAR := "regular"
const STYLE_IRREGULAR := "irregular"
const STYLES: Array[String] = [STYLE_GRID, STYLE_REGULAR, STYLE_IRREGULAR]
const PRECISION := 0.001
const LN2 := 0.6931471805599453
const SQRT2 := 1.4142135623730951
const SQRT_HALF := 0.7071067811865476
# Series terms for ln: |s| <= 0.1716, so the 13th term is below 1e-18 of the first.
const LN_TERMS := 13
# Irregular column widths and row heights vary by this fraction before being scaled to fill the image.
const IRREGULAR_UNEVEN := 0.25
# Interior Irregular corners move by up to this fraction of the smaller neighbouring column or row.
# Kept small: corners sharper than about 70 degrees let two inward knobs touch (tests/test_tab_extremes.gd).
const IRREGULAR_CORNER_JITTER := 0.08
# Stream id for the Irregular lattice's generator. Edge ids are never negative, so no edge shares it.
const LATTICE_STREAM := -1
# Weight of cell squareness against hitting the requested piece count.
const ASPECT_WEIGHT := 0.5
const SCORE_SCALE := 1.0e9
# Widest cell aspect (as |ln(width / height)|) a count may have and still be offered to the player.
const MAX_ASPECT_ERROR := 0.18
# Four tabbed edges, each adding all its points but the last.
const MAX_OUTLINE_POINTS := 4 * (TabShape.POINTS_PER_EDGE - 1)


## Natural log of a positive x using only 64-bit + - * /, so every device scores splits identically.
## libm's log is not guaranteed to round the same on bionic and glibc.
static func ln(x: float) -> float:
	# Halving and doubling are exact, so m * 2^k == x with m in [sqrt(0.5), sqrt(2)).
	var k := 0
	var m := x
	while m >= SQRT2:
		m *= 0.5
		k += 1
	while m < SQRT_HALF:
		m *= 2.0
		k -= 1
	# ln(m) = 2 * atanh(s) = 2 * (s + s^3 / 3 + s^5 / 5 + ...), summed from the smallest term.
	var s := (m - 1.0) / (m + 1.0)
	var s2 := s * s
	var sum := 0.0
	for i in range(LN_TERMS - 1, -1, -1):
		sum = sum * s2 + 1.0 / (2 * i + 1)
	return k * LN2 + 2.0 * s * sum


## Returns columns in x and rows in y. Never more columns than pixels wide or rows than pixels high,
## so every cell keeps at least one pixel and no piece can have zero area.
static func grid_split(width: int, height: int, target_count: int) -> Vector2i:
	var exact := _exact_split(width, height, target_count)
	if exact != Vector2i.ZERO:
		return exact
	var best := Vector2i(1, 1)
	var best_score := 1 << 62
	for rows in range(1, mini(height, target_count) + 1):
		var base := target_count / rows
		for columns in [base, base + 1]:
			columns = clampi(columns, 1, width)
			var cell_aspect := (width / float(columns)) / (height / float(rows))
			var count_error := absf(columns * rows - target_count) / float(target_count)
			# Quantised so rounding noise cannot flip exact ties (e.g. 9x6 vs 6x9 on a square
			# image). Rows ascend, so a tie goes to the fewer-rows split.
			var score := roundi((count_error + ASPECT_WEIGHT * absf(ln(cell_aspect))) * SCORE_SCALE)
			if score < best_score:
				best_score = score
				best = Vector2i(columns, rows)
	return best


## Counts in min_count..max_count that factor into a grid with near-square cells, ascending.
## Built on _exact_split so grid_split always returns exactly the count the player picked.
static func valid_counts(width: int, height: int, min_count: int, max_count: int) -> PackedInt32Array:
	var counts := PackedInt32Array()
	for count in range(maxi(1, min_count), max_count + 1):
		if _exact_split(width, height, count) != Vector2i.ZERO:
			counts.append(count)
	return counts


## Columns in x and rows in y of the squarest exact rows-by-columns split of count, or
## Vector2i.ZERO when none has an acceptable cell aspect.
static func _exact_split(width: int, height: int, count: int) -> Vector2i:
	var best := Vector2i.ZERO
	var best_score := 1 << 62
	for rows in range(1, mini(height, count) + 1):
		if count % rows != 0:
			continue
		var columns := count / rows
		if columns > width:
			continue
		var cell_aspect := (width / float(columns)) / (height / float(rows))
		var score := roundi(absf(ln(cell_aspect)) * SCORE_SCALE)
		# Strict: rows ascend, so a tie goes to fewer rows.
		if score < best_score:
			best_score = score
			best = Vector2i(columns, rows)
	if best_score > roundi(MAX_ASPECT_ERROR * SCORE_SCALE):
		return Vector2i.ZERO
	return best


static func build_grid_graph(width: int, height: int, columns: int, rows: int) -> CutGraph:
	var graph := CutGraph.new()
	for r in rows + 1:
		var y := roundi(r * height / float(rows))
		for c in columns + 1:
			var x := roundi(c * width / float(columns))
			graph.vertices.append(Vector2(snappedf(x, PRECISION), snappedf(y, PRECISION)))
	return graph if _add_lattice_faces(graph, columns, rows) else null


## The grid's vertices in the same order, with uneven columns and rows and jittered interior corners.
## The order of rng draws is part of the cut format: changing it changes every saved puzzle.
static func build_irregular_graph(width: int, height: int, columns: int, rows: int, rng: SeededRng) -> CutGraph:
	var cw := _uneven_sizes(columns, rng)
	var rh := _uneven_sizes(rows, rng)
	var cw_sum := _sum(cw)
	var rh_sum := _sum(rh)
	var xs := _lattice_lines(cw, cw_sum, width)
	var ys := _lattice_lines(rh, rh_sum, height)
	var graph := CutGraph.new()
	for r in rows + 1:
		for c in columns + 1:
			var x := xs[c]
			var y := ys[r]
			if r > 0 and r < rows and c > 0 and c < columns:
				var jx := IRREGULAR_CORNER_JITTER * minf(cw[c - 1], cw[c]) / cw_sum * width
				x += rng.range_float(-jx, jx)
				var jy := IRREGULAR_CORNER_JITTER * minf(rh[r - 1], rh[r]) / rh_sum * height
				y += rng.range_float(-jy, jy)
			graph.vertices.append(Vector2(snappedf(x, PRECISION), snappedf(y, PRECISION)))
	return graph if _add_lattice_faces(graph, columns, rows) else null


static func _uneven_sizes(count: int, rng: SeededRng) -> PackedFloat64Array:
	var sizes := PackedFloat64Array()
	for i in count:
		sizes.append(1.0 + rng.range_float(-IRREGULAR_UNEVEN, IRREGULAR_UNEVEN))
	return sizes


static func _sum(values: PackedFloat64Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total


## Where each column or row starts, with the first line at 0 and the last exactly at extent.
static func _lattice_lines(sizes: PackedFloat64Array, total: float, extent: int) -> PackedFloat64Array:
	var lines := PackedFloat64Array([0.0])
	var prefix := 0.0
	for i in range(1, sizes.size()):
		prefix += sizes[i - 1]
		lines.append(extent * prefix / total)
	lines.append(float(extent))
	return lines


## False after push_error if any cell is rejected, since later faces would then get the wrong index.
static func _add_lattice_faces(graph: CutGraph, columns: int, rows: int) -> bool:
	var stride := columns + 1
	for r in rows:
		for c in columns:
			var top_left := r * stride + c
			if graph.add_face(PackedInt32Array([top_left, top_left + 1, top_left + stride + 1, top_left + stride])) == -1:
				push_error("build_graph: lattice cell %d, %d was rejected" % [c, r])
				return false
	return true


## Gives every interior edge its tab. Border edges stay straight so the image keeps its frame.
static func shape_edges(graph: CutGraph, tabs: TabShape, seed_value: int) -> void:
	for edge in graph.edges:
		if edge.is_border():
			continue
		# Seeded by id alone, so one edge's draws never shift another's.
		var rng := SeededRng.new(SeededRng.hash2(seed_value, edge.id))
		edge.points = tabs.edge_points(graph.vertices[edge.from_vertex], graph.vertices[edge.to_vertex], graph.edge_room(edge.id), rng)


## Returns null after push_error on invalid input, an unknown style or a lattice that fails to build.
static func build_graph(width: int, height: int, target_count: int, style: String, seed_value: int) -> CutGraph:
	if width < 1 or height < 1 or target_count < 1:
		push_error("build_graph: width, height and target_count must be at least 1")
		return null
	if not STYLES.has(style):
		push_error("build_graph: unknown style '%s'" % style)
		return null
	var split := grid_split(width, height, target_count)
	var lattice_rng := SeededRng.new(SeededRng.hash2(seed_value, LATTICE_STREAM))
	var graph := build_irregular_graph(width, height, split.x, split.y, lattice_rng) if style == STYLE_IRREGULAR else build_grid_graph(width, height, split.x, split.y)
	if graph == null:
		return null
	var tabs := TabShape.for_style(style)
	if tabs:
		shape_edges(graph, tabs, seed_value)
	return graph


static func generate_cut(width: int, height: int, target_count: int, style: String, seed_value: int) -> Array[CutPiece]:
	var graph := build_graph(width, height, target_count, style, seed_value)
	if graph == null:
		return []
	return graph.to_pieces()
