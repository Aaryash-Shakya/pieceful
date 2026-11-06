extends "res://tests/board_test.gd"

const TRACE_PATH := "user://test_board_trace.txt"


func _init() -> void:
	await process_frame
	make_board()
	board.trace_path = TRACE_PATH
	DirAccess.remove_absolute(TRACE_PATH)
	_show_everything()

	_test_touches_are_traced()
	_test_report_follows_the_gesture()
	_test_drag_lines_are_thinned()
	_test_cancel_forgets_fingers()
	_test_stale_finger_is_noted_once_and_saved()
	_test_locked_count_is_reported()

	board.free()
	DirAccess.remove_absolute(TRACE_PATH)
	finish()


func _loose_target() -> PieceNode:
	for i in board.state.piece_count():
		if _is_loose_singleton(i) and _grab_point(board.node_for(i)) != Vector2.INF:
			return board.node_for(i)
	check(false, "found a loose piece to press")
	return null


func _last_line() -> String:
	var tail := board.trace.tail(1)
	return tail[0] if not tail.is_empty() else ""


func _test_touches_are_traced() -> void:
	var node := _loose_target()
	var s := _grab_point(node)
	_touch(0, s, true)
	check(_last_line().contains("press #0") and _last_line().contains("DRAGGING"), "a press is traced with the mode it leaves the board in")
	_touch(0, s, false)
	check(_last_line().contains("release #0") and _last_line().contains("IDLE"), "a release is traced with the mode it leaves the board in")
	_touch(1, Vector2(5, 5), true)
	_touch(1, Vector2(5, 5), false, true)
	check(_last_line().contains("cancel #1"), "a cancelled touch is traced as a cancel")


func _test_report_follows_the_gesture() -> void:
	check(board.gesture_report().contains("no fingers") and board.gesture_report().contains("mode IDLE"), "the report starts idle with no fingers")
	var node := _loose_target()
	var s := _grab_point(node)
	_touch(0, s, true)
	var report := board.gesture_report()
	check(report.contains("mode DRAGGING") and report.contains("#0") and report.contains("held 1"), "the report shows a held piece and its finger")
	_touch(0, s, false)
	check(board.gesture_report().contains("no fingers") and board.gesture_report().contains("held 0"), "the report is idle again after the release")


func _test_drag_lines_are_thinned() -> void:
	var node := _loose_target()
	var s := _grab_point(node)
	_touch(0, s, true)
	var before := board.trace.lines().size()
	for k in 30:
		_drag(0, s + Vector2(k, 0), Vector2(1, 0))
	var drag_lines := 0
	for line in board.trace.lines():
		if line.contains("drag #0"):
			drag_lines += 1
	check(drag_lines <= 2, "thirty drags in one instant leave at most two drag lines")
	check(board.trace.lines().size() - before <= 2, "dragging does not flood the trace")
	_touch(0, s + Vector2(30, 0), false)


func _test_cancel_forgets_fingers() -> void:
	_touch(0, Vector2(5, 5), true)
	_touch(1, Vector2(50, 50), true)
	check(board._last_seen.size() == 2, "each finger down is remembered")
	_touch(1, Vector2(50, 50), false)
	check(board._last_seen.size() == 1, "a release forgets that finger")
	_touch(0, Vector2(5, 5), false, true)
	check(board._last_seen.is_empty(), "a cancel forgets every finger")


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _test_stale_finger_is_noted_once_and_saved() -> void:
	_touch(0, Vector2(5, 5), true)
	_touch(1, Vector2(50, 50), true)
	board._last_seen[0] = _now() - 10.0
	board._last_seen[1] = _now()
	board._process(0.016)
	check(_last_line().contains("STALE") and _last_line().contains("#0"), "a finger silent for seconds beside a live one is noted")
	check(FileAccess.file_exists(TRACE_PATH), "the trace is saved when a stale finger is noted")
	check(FileAccess.get_file_as_string(TRACE_PATH).contains("STALE"), "the saved trace holds the note")
	var count := board.trace.lines().size()
	board._last_seen[1] = _now()
	board._process(0.016)
	check(board.trace.lines().size() == count, "the same stale finger is not noted again")
	check(board.gesture_report().contains("#0 1"), "the report shows the silent finger's age")
	_touch(1, Vector2(50, 50), false)
	_touch(0, Vector2(5, 5), false)
	board._process(0.016)
	_touch(0, Vector2(5, 5), true)
	_touch(1, Vector2(50, 50), true)
	board._last_seen[0] = _now() - 10.0
	board._last_seen[1] = _now()
	board._process(0.016)
	check(board.trace.tail(1)[0].contains("STALE"), "a later stale finger is noted again once the first is gone")
	_touch(1, Vector2(50, 50), false)
	_touch(0, Vector2(5, 5), false)


func _test_locked_count_is_reported() -> void:
	var node := _loose_target()
	var tol := board.state.tolerance
	_move_by_touch(node, Vector2(0.3, 0.3) * tol)
	check(board.state.is_locked(node.piece_id), "the piece locked near home")
	check(board.state.locked_piece_count() == 1, "the state counts locked pieces")
	check(board.gesture_report().contains("locked 1"), "the report shows the locked count")
