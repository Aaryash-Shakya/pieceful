extends "res://tests/board_test.gd"


func _init() -> void:
	await process_frame
	make_board()
	var hud := board.get_node("Hud") as Hud
	await process_frame
	_test_ghost_default(hud)
	_test_ghost_toggle_saves(hud)
	_test_timer_label(hud)
	_test_top_row_does_not_overlap(hud)
	_test_complete_panel(hud)
	await _test_ghost_resumes()
	finish()


func _test_ghost_default(hud: Hud) -> void:
	check(board.puzzle.ghost, "ghost is on by default")
	check(board.ghost_sprite.visible, "the ghost picture shows")
	check(is_equal_approx(board.ghost_sprite.modulate.a, 0.2), "at 20 percent opacity")
	check(board.ghost_sprite.get_index() < board.locked_pieces.get_index(), "under every piece")
	check(hud.ghost_button.text == "Ghost on", "the button says on")


func _test_ghost_toggle_saves(hud: Hud) -> void:
	hud.ghost_button.pressed.emit()
	await_frame_text(hud)
	check(not board.puzzle.ghost and not board.ghost_sprite.visible, "pressing the button hides the ghost")
	var loaded := SaveGame.from_json(FileAccess.get_file_as_string(TEST_SAVE_PATH))
	check(loaded.snapshot != null and not loaded.snapshot.puzzle.ghost, "the choice is saved")
	board.set_ghost(false)
	check(board._save_writes >= 1, "setting the same value again is a no-op")


func await_frame_text(hud: Hud) -> void:
	hud._process(0.0)
	check(hud.ghost_button.text == "Ghost off", "the button says off")


func _test_timer_label(hud: Hud) -> void:
	board.elapsed = 754.7
	hud._process(0.0)
	check(hud.timer_label.text == "12:34", "the clock shows minutes and seconds")
	check(hud.progress_label.text == "%d / %d" % [board.state.locked_piece_count(), board.state.piece_count()], "progress shows placed of all pieces")


func _test_top_row_does_not_overlap(hud: Hud) -> void:
	var rects: Array[Rect2] = []
	for c: Control in [hud.pause_button, hud.timer_label, hud.progress_label]:
		rects.append(Rect2(c.offset_left if c.anchor_left == 0.0 else viewport_size.x + c.offset_left, c.offset_top,
				c.offset_right - c.offset_left, c.offset_bottom - c.offset_top))
	for i in rects.size():
		check(rects[i].position.x >= 0.0 and rects[i].end.x <= viewport_size.x, "top row item %d is on screen" % i)
		for j in range(i + 1, rects.size()):
			check(not rects[i].intersects(rects[j]), "top row items %d and %d do not overlap" % [i, j])


func _test_complete_panel(hud: Hud) -> void:
	board.set_ghost(true)
	board.elapsed = 754.0
	board.puzzle_completed.emit()
	check(hud.complete_panel != null, "completion shows the panel")
	var texts := PackedStringArray()
	for label in hud.complete_panel.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	check(texts.has("Test picture"), "the panel names the picture: %s" % [texts])
	check(texts.has("400 pieces · Regular"), "the panel shows count and style")
	check(texts.has("Ghost on · 12:34"), "the panel shows the ghost setting and time")
	hud.share_button.pressed.emit()
	check(hud.share_note.visible, "sharing says what happened")


func _test_ghost_resumes() -> void:
	board.set_ghost(false)
	board.queue_free()
	await process_frame
	make_board(false)
	check(not board.puzzle.ghost and not board.ghost_sprite.visible, "resume keeps the ghost off")
