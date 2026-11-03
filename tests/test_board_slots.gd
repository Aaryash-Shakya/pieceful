extends "res://tests/board_test.gd"


var _stashed: Array[int] = []


func _init() -> void:
	await process_frame
	make_board()
	board.stashed.connect(func(n: int) -> void: _stashed.append(n))
	_fit_board()
	_test_tray_geometry()
	_test_drop_on_slot_stashes()
	_test_stack_comes_out_whole_and_returns()
	_test_release_away_spreads()
	_test_system_release_returns_the_stack()
	_test_tidy_skips_slotted()
	await _test_save_and_resume()
	finish()


func _slot_center(s: int) -> Vector2:
	return board.slot_rects[s].get_center()


# A table spot in the middle of the screen, clear of the tray, as a screen point.
func _table_spot() -> Vector2:
	return Vector2(viewport_size.x / 2.0, viewport_size.y * 0.4)


func _put(piece: int, slot: int) -> void:
	var node := board.node_for(piece)
	var s := _grab_point(node)
	check(s != Vector2.INF, "piece %d can be grabbed" % piece)
	_touch(0, s, true)
	_drag(0, _slot_center(slot), _slot_center(slot) - s)
	_touch(0, _slot_center(slot), false)


func _test_tray_geometry() -> void:
	check(board.slot_rects.size() == 4, "the HUD gave the board four slot rectangles")
	for s in 4:
		check(board.slot_rects[s].end.y <= viewport_size.y, "slot %d is on screen" % s)
		if s > 0:
			check(board.slot_rects[s].position.x > board.slot_rects[s - 1].end.x, "slot %d is right of slot %d" % [s, s - 1])
	check(board.slot_at(_slot_center(2)) == 2 and board.slot_at(_table_spot()) == -1, "slot_at finds a slot or nothing")


func _test_drop_on_slot_stashes() -> void:
	_put(0, 1)
	check(board.state.slot_of(0) == 1, "a piece dropped on slot 1 is in it")
	check(board.state.slot_piece_count(1) == 1, "the slot counts one piece")
	check(board.node_for(0).get_parent() == board.stash, "its node is in the stash")
	check(not board.stash.visible, "the stash is hidden")
	check(not _is_held(board.node_for(0)), "the stashed piece is no longer lifted")
	check(board.piece_at(board.node_for(0).position + board.cut[0].bounds().get_center()) != board.node_for(0), "a stashed piece cannot be picked from the table")


func _test_stack_comes_out_whole_and_returns() -> void:
	_put(1, 1)
	check(board.state.slot_piece_count(1) == 2, "two pieces in slot 1")
	var order := board.state.slot_roots(1)
	var home := _slot_center(1)
	_touch(0, home, true)
	check(board.state.slot_piece_count(1) == 0, "touching the slot takes the whole stack out")
	check(board.node_for(0).get_parent() == board.pieces and board.node_for(1).get_parent() == board.pieces, "both pieces are on the table")
	check(_is_held(board.node_for(0)) and _is_held(board.node_for(1)), "the stack is lifted")
	var finger := home + Vector2(0, -200)
	_drag(0, finger, Vector2(0, -200))
	var near := _to_world(finger)
	check(board.node_for(0).position.distance_to(board.node_for(1).position) < 40.0, "the stack fans near the finger")
	check((board.node_for(0).position + board.cut[0].bounds().get_center()).distance_to(near) < 60.0, "the fan follows the finger")
	_drag(0, home + Vector2(10, -20), Vector2.ZERO)
	_touch(0, home + Vector2(10, -20), false)
	check(board.state.slot_roots(1) == order, "released near the slot, the stack returns in order")
	check(board.state.slot_piece_count(1) == 2, "the count is back")
	check(board.node_for(0).get_parent() == board.stash, "nodes are back in the stash")


func _test_release_away_spreads() -> void:
	var spot := _table_spot()
	_touch(0, _slot_center(1), true)
	_drag(0, spot, spot - _slot_center(1))
	_touch(0, spot, false)
	check(_stashed == [1, 1, 2], "stashed fired for each put and the return, not the spread: %s" % [_stashed])
	check(board.state.slot_piece_count(1) == 0, "the slot is empty after a spread")
	check(board.state.slot_of(0) == -1 and board.state.slot_of(1) == -1, "the pieces are loose again")
	var a := board.node_for(0)
	var b := board.node_for(1)
	check(a.get_parent() == board.pieces and b.get_parent() == board.pieces, "both pieces are back on the table")
	check(not _is_held(a) and not _is_held(b), "the spread pieces are put down")
	check(board.state.offset_of(0) == a.position and board.state.offset_of(1) == b.position, "the state agrees with the nodes")
	var ac := a.position + board.cut[0].bounds().get_center()
	var bc := b.position + board.cut[1].bounds().get_center()
	check(ac.distance_to(bc) > 1.0, "the two pieces do not sit on each other")
	check(((ac + bc) / 2.0).distance_to(_to_world(spot)) < 200.0, "the grid is centred where the finger lifted")


func _test_system_release_returns_the_stack() -> void:
	_put(2, 3)
	_touch(0, _slot_center(3), true)
	check(board.state.slot_piece_count(3) == 0, "taken out")
	board._leave()
	check(board.state.slot_of(2) == 3, "a system release puts the stack back")
	check(_stashed == [1, 1, 2, 1], "a system release makes no stash feedback: %s" % [_stashed])
	check(board.node_for(2).get_parent() == board.stash, "and hides it")
	_touch(0, _slot_center(3), false)
	check(board.state.slot_of(2) == 3, "the late touch-up changes nothing")


func _test_tidy_skips_slotted() -> void:
	board.cleanup()
	board._finish_cleanup()
	check(board.state.slot_of(2) == 3, "tidy leaves slotted clusters alone")
	check(board.node_for(2).get_parent() == board.stash, "the stashed node stays put")


func _test_save_and_resume() -> void:
	check(board.save_game(), "saved with a slot full")
	var text := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	var loaded := SaveGame.from_json(text)
	check(loaded.snapshot != null and loaded.snapshot.slots[3] == PackedInt32Array([2]), "the save holds slot 3 = [2]")
	board.queue_free()
	await process_frame
	make_board(false)
	check(board.state.slot_of(2) == 3 and board.state.slot_piece_count(3) == 1, "resume restores the slot")
	check(board.node_for(2).get_parent() == board.stash, "resume hides the slotted piece")
	check(board.pieces.get_child_count() + board.locked_pieces.get_child_count() + board.stash.get_child_count() == board.cut.size(), "every piece is in exactly one layer")
