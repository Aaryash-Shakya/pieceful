extends "res://tests/base_test.gd"


func _init() -> void:
	_test_segments()
	_test_fit_rect()
	_test_show()
	finish()


func _test_segments() -> void:
	var pieces := CutGenerator.generate_cut(300, 200, 6, "grid", 1)
	var segments := CutPreview.outline_segments(pieces)
	var total := 0
	for piece in pieces:
		total += piece.outline.size()
	check(total > 0, "the grid cut has outlines")
	check(segments.size() == 2 * total, "one pair per outline point")
	var outline := pieces[0].outline
	var last := 2 * outline.size() - 2
	check(segments[last] == outline[outline.size() - 1] and segments[last + 1] == outline[0], "the outline closes last to first")
	check(segments[0] == outline[0] and segments[1] == outline[1], "the first pair is the first edge")


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
