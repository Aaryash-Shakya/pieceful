extends BaseTest


func _init() -> void:
	var piece := CutPiece.new()
	piece.id = 3
	piece.outline = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])

	var node := PieceNode.new()
	node.setup(piece, GradientTexture2D.new(), Color.BLACK)
	root.add_child(node)
	node.position = Vector2(100, 0)

	check(node.piece_id == 3, "piece id is kept")
	check(node.contains_point(Vector2(105, 5)), "point over the displaced piece hits")
	check(not node.contains_point(Vector2(5, 5)), "point over the home position misses")

	node.set_held(true)
	node.set_held(false)
	check(true, "set_held toggles without error")

	finish()
