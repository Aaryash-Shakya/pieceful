extends "res://tests/board_test.gd"


func _init() -> void:
	await process_frame
	make_board()

	_test_msaa_is_on()
	_test_zoomed_out_lines_stay_visible()
	_test_zoomed_in_lines_keep_their_width()
	_test_small_zoom_steps_leave_the_lines_alone()
	_test_every_piece_follows()
	_test_pieces_report_their_width()

	board.free()
	finish()


func _center() -> Vector2:
	return viewport_size / 2.0


func _widths_match(expected: float) -> bool:
	for i in board.state.piece_count():
		if not is_equal_approx(board.node_for(i).outline_width(), expected):
			return false
	return true


func _test_msaa_is_on() -> void:
	check(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", 0)) >= 1, "2D multisampling is on, so piece edges are smoothed")


func _test_zoomed_out_lines_stay_visible() -> void:
	board._zoom_about(CameraRig.MIN_ZOOM, _center())
	var expected := Board.MIN_LINE_PIXELS / CameraRig.MIN_ZOOM
	check(expected > PieceNode.OUTLINE_WIDTH, "at the widest view the minimum on-screen width is the larger one")
	check(_widths_match(expected), "zoomed out, outlines widen so they stay about 1.5 screen pixels")


func _test_zoomed_in_lines_keep_their_width() -> void:
	board._zoom_about(CameraRig.MAX_ZOOM, _center())
	check(_widths_match(PieceNode.OUTLINE_WIDTH), "zoomed in, outlines are back at their normal width")


func _test_small_zoom_steps_leave_the_lines_alone() -> void:
	board._zoom_about(CameraRig.MIN_ZOOM, _center())
	var before := board.node_for(0).outline_width()
	board._zoom_about(CameraRig.MIN_ZOOM * 1.06, _center())
	check(is_equal_approx(board.node_for(0).outline_width(), before), "a small zoom step does not rebuild 400 outlines")
	board._zoom_about(CameraRig.MIN_ZOOM * 1.4, _center())
	check(not is_equal_approx(board.node_for(0).outline_width(), before), "a large zoom step updates the outlines")
	check(is_equal_approx(board.node_for(0).outline_width(), Board.MIN_LINE_PIXELS / (CameraRig.MIN_ZOOM * 1.4)), "the update lands on the width for the new zoom")


func _test_every_piece_follows() -> void:
	board._zoom_about(CameraRig.MIN_ZOOM, _center())
	var locked := -1
	for i in board.state.piece_count():
		if _is_loose_singleton(i) and _grab_point(board.node_for(i)) != Vector2.INF:
			locked = i
			break
	var node := board.node_for(locked)
	board.state.move_cluster(locked, Vector2.ZERO)
	board._settle(board.state.drop(locked))
	check(board.state.is_locked(locked), "a piece is locked for the check")
	board._zoom_about(CameraRig.MAX_ZOOM, _center())
	check(is_equal_approx(node.outline_width(), PieceNode.OUTLINE_WIDTH), "locked pieces follow the zoom too")
	check(_widths_match(PieceNode.OUTLINE_WIDTH), "every piece follows the zoom")


func _test_pieces_report_their_width() -> void:
	var node := board.node_for(0)
	node.set_outline_width(7.5)
	check(is_equal_approx(node.outline_width(), 7.5), "a piece reports the width it was given")
	node.set_outline_width(PieceNode.OUTLINE_WIDTH)
