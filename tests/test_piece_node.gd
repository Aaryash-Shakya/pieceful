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

	# The shadow is the first child, added before the body.
	var shadow := node.get_child(0) as Polygon2D
	check(not shadow.visible, "shadow is hidden after setup")
	node.set_held(true)
	check(shadow.visible, "shadow shows while held")
	node.set_held(false)
	check(not shadow.visible, "shadow hides again when released")

	# A tab's notch is inside the bounds but outside the piece.
	var notched := CutPiece.new()
	notched.id = 4
	notched.outline = PackedVector2Array([
		Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(6, 10),
		Vector2(6, 4), Vector2(4, 4), Vector2(4, 10), Vector2(0, 10),
	])
	var notched_node := PieceNode.new()
	notched_node.setup(notched, GradientTexture2D.new(), Color.BLACK)
	root.add_child(notched_node)
	notched_node.position = Vector2.ZERO
	check(not notched_node.contains_point(Vector2(5, 8)), "point inside the notch misses")
	check(notched_node.contains_point(Vector2(2, 8)), "point beside the notch hits")
	check(notched_node.contains_point(Vector2(5, 2)), "point above the notch hits")

	finish()
