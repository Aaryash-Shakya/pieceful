extends "res://tests/base_test.gd"


func _init() -> void:
	var size := Vector2(1536, 1024)
	var margin := 768.0
	var board := Rect2(Vector2.ZERO, size)
	var outer := board.grow(margin)
	var pieces := CutGenerator.generate_cut(1536, 1024, 400, CutGenerator.STYLE_GRID, 1)

	var offsets := Scatter.scatter(pieces, size, margin, 1)
	check(offsets.size() == pieces.size(), "one displacement per piece")

	var off_board := true
	var inside_outer := true
	for i in mini(offsets.size(), pieces.size()):
		var moved := pieces[i].bounds()
		moved.position += offsets[i]
		if moved.intersects(board):
			off_board = false
		if not outer.encloses(moved):
			inside_outer = false
	check(off_board, "no scattered piece touches the board")
	check(inside_outer, "every scattered piece stays within the margin")

	check(offsets == Scatter.scatter(pieces, size, margin, 1), "same seed gives same result")
	check(offsets != Scatter.scatter(pieces, size, margin, 2), "different seeds differ")

	# Small raw seeds make xorshift32's first draws tiny, which once pinned the first piece top-left.
	var strips := {}
	for s in range(1, 21):
		var first := pieces[0].bounds()
		first.position += Scatter.scatter(pieces, size, margin, s)[0]
		if first.end.y <= 0.0:
			strips["top"] = true
		elif first.position.y >= size.y:
			strips["bottom"] = true
		elif first.end.x <= 0.0:
			strips["left"] = true
		else:
			strips["right"] = true
	check(strips.size() > 1, "the first piece does not land in the same strip for every seed")

	finish()
