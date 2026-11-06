extends "res://tests/board_test.gd"


func _init() -> void:
	await process_frame
	make_board()
	board.trace_path = "user://test_gesture_overlay.txt"
	_show_everything()

	var overlay := board.get_node_or_null("GestureOverlay") as GestureOverlay
	check(overlay != null, "a debug build shows the gesture overlay")
	if overlay != null:
		overlay.refresh()
		check(overlay.text().contains("mode IDLE") and overlay.text().contains("no fingers"), "the overlay starts idle")
		check(overlay.text().contains("fps") == false, "the overlay shows gesture state, not the frame counter")
		var node: PieceNode = null
		for i in board.state.piece_count():
			if _is_loose_singleton(i) and _grab_point(board.node_for(i)) != Vector2.INF:
				node = board.node_for(i)
				break
		var s := _grab_point(node)
		_touch(0, s, true)
		overlay.refresh()
		check(overlay.text().contains("mode DRAGGING") and overlay.text().contains("press #0"), "the overlay shows the mode and the latest touch lines")
		_touch(0, s, false)
		overlay.refresh()
		check(overlay.text().contains("release #0"), "the overlay follows the release")
		check(overlay.text().split("\n").size() <= 1 + GestureOverlay.TRACE_LINES, "the overlay shows the report and a few trace lines only")
		check(overlay.layer == 99, "the overlay sits under the frame counter and over the HUD")

	board.free()
	DirAccess.remove_absolute("user://test_gesture_overlay.txt")
	finish()
