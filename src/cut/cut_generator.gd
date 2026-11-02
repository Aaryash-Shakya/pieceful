class_name CutGenerator
extends RefCounted

const STYLE_GRID := "grid"
const PRECISION := 0.001
# Weight of cell squareness against hitting the requested piece count.
const ASPECT_WEIGHT := 0.5
const SCORE_SCALE := 1.0e9


## Returns columns in x and rows in y. Never more columns than pixels wide or rows than pixels high,
## so every cell keeps at least one pixel and no piece can have zero area.
static func grid_split(width: int, height: int, target_count: int) -> Vector2i:
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
			graph.faces.append(PackedInt32Array([top_left, top_left + 1, top_left + stride + 1, top_left + stride]))
	return graph


@warning_ignore("shadowed_global_identifier", "unused_parameter")
static func generate_cut(width: int, height: int, target_count: int, style: String, seed: int) -> Array[CutPiece]:
	var pieces: Array[CutPiece] = []
	if width < 1 or height < 1 or target_count < 1:
		push_error("generate_cut: width, height and target_count must be at least 1")
		return pieces
	if style != STYLE_GRID:
		push_error("generate_cut: unknown style '%s'" % style)
		return pieces

	var split := grid_split(width, height, target_count)
	var graph := build_grid_graph(width, height, split.x, split.y)

	var edge_faces := {}
	for face_index in graph.faces.size():
		var face := graph.faces[face_index]
		var outline := PackedVector2Array()
		for vertex_index in face:
			outline.append(graph.vertices[vertex_index])
		var piece := CutPiece.new()
		piece.id = face_index
		piece.outline = outline
		piece.home = piece.bounds().get_center()
		pieces.append(piece)

		for i in face.size():
			var key := CutGraph.edge_key(face[i], face[(i + 1) % face.size()])
			if not edge_faces.has(key):
				edge_faces[key] = []
			edge_faces[key].append(face_index)

	for key in edge_faces:
		var sharing: Array = edge_faces[key]
		if sharing.size() == 2:
			pieces[sharing[0]].neighbours.append(sharing[1])
			pieces[sharing[1]].neighbours.append(sharing[0])
	return pieces
