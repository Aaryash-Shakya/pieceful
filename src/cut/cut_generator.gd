class_name CutGenerator
extends RefCounted

const STYLE_GRID := "grid"
const STYLE_REGULAR := "regular"
const PRECISION := 0.001
# Weight of cell squareness against hitting the requested piece count.
const ASPECT_WEIGHT := 0.5
const SCORE_SCALE := 1.0e9
# Widest cell aspect (as |ln(width / height)|) a count may have and still be offered to the player.
const MAX_ASPECT_ERROR := 0.18
# Four tabbed edges, each adding all its points but the last.
const MAX_OUTLINE_POINTS := 4 * (TabShape.POINTS_PER_EDGE - 1)


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
			# Quantised so libm rounding noise cannot flip exact ties (e.g. 9x6 vs 6x9 on a square
			# image). Rows ascend, so a tie goes to the fewer-rows split.
			var score := roundi((count_error + ASPECT_WEIGHT * absf(log(cell_aspect))) * SCORE_SCALE)
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
		var score := roundi(absf(log(cell_aspect)) * SCORE_SCALE)
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
	var stride := columns + 1
	for r in rows:
		for c in columns:
			var top_left := r * stride + c
			graph.add_face(PackedInt32Array([top_left, top_left + 1, top_left + stride + 1, top_left + stride]))
	return graph


## Gives every interior edge its tab. Border edges stay straight so the image keeps its frame.
static func shape_edges(graph: CutGraph, tabs: TabShape, seed_value: int) -> void:
	for edge in graph.edges:
		if edge.is_border():
			continue
		# Seeded by id alone, so one edge's draws never shift another's.
		var rng := SeededRng.new(SeededRng.hash2(seed_value, edge.id))
		edge.points = tabs.edge_points(graph.vertices[edge.from_vertex], graph.vertices[edge.to_vertex], graph.edge_room(edge.id), rng)


## Returns null after push_error on invalid input or an unknown style.
static func build_graph(width: int, height: int, target_count: int, style: String, seed_value: int) -> CutGraph:
	if width < 1 or height < 1 or target_count < 1:
		push_error("build_graph: width, height and target_count must be at least 1")
		return null
	if style != STYLE_GRID and style != STYLE_REGULAR:
		push_error("build_graph: unknown style '%s'" % style)
		return null
	var split := grid_split(width, height, target_count)
	var graph := build_grid_graph(width, height, split.x, split.y)
	if style == STYLE_REGULAR:
		shape_edges(graph, TabShape.for_style(style), seed_value)
	return graph


static func generate_cut(width: int, height: int, target_count: int, style: String, seed_value: int) -> Array[CutPiece]:
	var graph := build_graph(width, height, target_count, style, seed_value)
	if graph == null:
		return []
	return graph.to_pieces()
