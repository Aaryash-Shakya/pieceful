extends BaseTest


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

	finish()
