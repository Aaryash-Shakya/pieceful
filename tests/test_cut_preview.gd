extends "res://tests/base_test.gd"


func _init() -> void:
	_test_segments()
	_test_fit_rect()
	_test_show()
	finish()


# Every edge of every outline, keyed so that a shared edge read either way round is one key.
func _unique_edges(pieces: Array[CutPiece]) -> Dictionary:
	var edges := {}
	for piece in pieces:
		var o := piece.outline
		for k in o.size():
			edges[_key(o[k], o[(k + 1) % o.size()])] = true
	return edges


func _key(a: Vector2, b: Vector2) -> Array:
	return [a, b] if a < b else [b, a]


func _test_segments() -> void:
	var pieces := CutGenerator.generate_cut(300, 200, 6, "grid", 1)
	var segments := CutPreview.outline_segments(pieces)
	check(pieces.size() == 6 and pieces[0].outline.size() == 4, "precondition: a 3 x 2 grid of four-cornered pieces")
	# A 3 x 2 grid has 3 x 3 horizontal and 2 x 4 vertical edges.
	check(segments.size() == 2 * 17, "each edge is drawn once: %d pairs" % (segments.size() / 2))
	var outline := pieces[0].outline
	check(segments[0] == outline[0] and segments[1] == outline[1], "the first pair is the first edge")
	for style in ["regular", "irregular"]:
		var cut := CutGenerator.generate_cut(300, 200, 24, style, 3)
		var drawn := CutPreview.outline_segments(cut)
		var unique := _unique_edges(cut)
		var seen := {}
		var duplicates := 0
		for i in range(0, drawn.size(), 2):
			var key := _key(drawn[i], drawn[i + 1])
			if seen.has(key):
				duplicates += 1
			seen[key] = true
		check(duplicates == 0, "%s: no edge is drawn twice" % style)
		check(drawn.size() / 2 == unique.size(), "%s: one pair per unique edge: %d of %d" % [style, drawn.size() / 2, unique.size()])


func _test_fit_rect() -> void:
	var preview := CutPreview.new()
	preview.size = Vector2(500, 500)
	preview.image_size = Vector2i(300, 200)
	var r := preview.fit_rect()
	check(absf(r.position.x) < 0.01 and absf(r.position.y - 83.333) < 0.01, "a wide picture is centred vertically")
	check(absf(r.size.x - 500) < 0.01 and absf(r.size.y - 333.333) < 0.01, "a wide picture fills the width")
	preview.image_size = Vector2i(200, 300)
	r = preview.fit_rect()
	check(absf(r.size.x - 333.333) < 0.01 and absf(r.size.y - 500) < 0.01, "a tall picture fills the height")
	check(absf(r.position.x - 83.333) < 0.01 and absf(r.position.y) < 0.01, "a tall picture is centred horizontally")
	preview.free()


func _test_show() -> void:
	var preview := CutPreview.new()
	var texture := ImageTexture.create_from_image(Image.create(30, 20, false, Image.FORMAT_RGBA8))
	preview.show_picture(texture, Vector2i(30, 20))
	check(preview.texture == texture and preview.image_size == Vector2i(30, 20), "show_picture sets the picture")
	preview.show_cut(CutGenerator.generate_cut(30, 20, 6, "grid", 1))
	check(not preview.segments.is_empty(), "show_cut fills the segments")
	preview.show_picture(texture, Vector2i(30, 20))
	check(preview.segments.is_empty(), "show_picture clears the old lines")
	check(preview.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "the picture draws with mipmaps")
	preview.free()
