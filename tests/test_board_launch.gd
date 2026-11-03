extends "res://tests/board_test.gd"

const LogCapture := preload("res://tests/log_capture.gd")

var _fixture := Collection.load_manifest("res://tests/fixtures/collection/manifest.json")


func _init() -> void:
	await process_frame
	_test_start_puzzle()
	_test_start_ignores_the_save()
	_test_resume_collection_picture()
	_test_unknown_picture_is_set_aside()
	_test_size_mismatch_is_set_aside()
	_test_rejected_resume_falls_back()
	_test_unusable_start_puzzle()
	_test_test_picture()
	board.free()
	finish()


func _puzzle(id: String, size: Vector2i, style: String, count: int, cut_seed: int) -> SaveGame.Puzzle:
	var p := SaveGame.Puzzle.new()
	p.image_id = id
	p.image_size = size
	p.style = style
	p.piece_count = count
	p.cut_seed = cut_seed
	return p


func _launch(puzzle: SaveGame.Puzzle, resume: bool, fresh: bool) -> void:
	if board != null:
		board.free()
		board = null
	make_board(fresh, true, func(b: Board) -> void:
		b.collection = _fixture
		b.start_puzzle = puzzle
		b.resume = resume)


func _captured_launch(puzzle: SaveGame.Puzzle, resume: bool, fresh: bool) -> LogCapture:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	_launch(puzzle, resume, fresh)
	OS.remove_logger(capture)
	return capture


func _saved() -> Dictionary:
	if not FileAccess.file_exists(TEST_SAVE_PATH):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))
	return d if d is Dictionary else {}


# Never edits board.snapshot().puzzle: it is the board's own puzzle object.
func _edited(change: Callable) -> void:
	board.save_game()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))
	change.call(d)
	SaveFile.write_atomic(TEST_SAVE_PATH, JSON.stringify(d, "\t", true, true))


func _check_one_set_aside(label: String, capture: LogCapture, reason: String) -> void:
	check(capture.warnings.size() == 1 and capture.warnings[0].begins_with("Board: could not use the save at")
			and capture.warnings[0].contains(reason), "%s: one set-aside warning (%s)" % [label, capture.warnings])
	check(capture.errors.is_empty(), "%s: no error (%s)" % [label, capture.errors])
	check(FileAccess.file_exists(SaveFile.bad_path(TEST_SAVE_PATH)), "%s: the save is set aside" % label)


func _test_start_puzzle() -> void:
	var capture := _captured_launch(_puzzle("fixture-ember-rings", Vector2i(240, 160), "irregular", 24, 99), false, true)
	check(capture.warnings.is_empty() and capture.errors.is_empty(),
			"start: no warning or error (%s %s)" % [capture.warnings, capture.errors])
	var p := board.puzzle
	check(p.image_id == "fixture-ember-rings", "start: the picture is the caller's")
	check(p.image_size == Vector2i(240, 160), "start: the size is the caller's")
	check(p.style == "irregular", "start: the style is the caller's")
	check(p.piece_count == 24, "start: the count is the caller's")
	check(p.cut_seed == 99, "start: the seed is the caller's")
	check(board.cut.size() == 24, "start: the cut has the asked count")
	check(p.cut_checksum == CutGenerator.checksum(CutGenerator.generate_cut(240, 160, 24, "irregular", 99)),
			"start: the checksum is computed")
	check(board._texture.resource_path == _fixture.find("fixture-ember-rings").path, "start: the picture is drawn")
	check((board.node_for(0).get_child(1) as Polygon2D).texture == board._texture, "start: pieces use the picture")
	var saved := _saved()
	check(not saved.is_empty() and saved.puzzle.image_id == "fixture-ember-rings" and int(saved.puzzle.seed) == 99,
			"a new game saves at once")


func _test_start_ignores_the_save() -> void:
	_launch(_puzzle("fixture-tide-stripes", Vector2i(240, 240), "regular", 16, 5), false, false)
	check(board.puzzle.image_id == "fixture-tide-stripes", "start ignores the save")
	var saved := _saved()
	check(not saved.is_empty() and saved.puzzle.image_id == "fixture-tide-stripes", "Start replaces the save")
	check(not FileAccess.file_exists(SaveFile.bad_path(TEST_SAVE_PATH)), "start sets nothing aside")


func _test_resume_collection_picture() -> void:
	camera.zoom = Vector2(CameraRig.MIN_ZOOM, CameraRig.MIN_ZOOM)
	camera.position = Vector2(board.puzzle.image_size) / 2.0
	var moved: PieceNode = null
	for i in board.state.piece_count():
		if _is_loose_singleton(i) and _grab_point(board.node_for(i)) != Vector2.INF:
			moved = board.node_for(i)
			break
	check(moved != null, "resume: found a loose piece to move")
	if moved == null:
		return
	var id := moved.piece_id
	var before := board.state.offset_of(id)
	_move_by_touch(moved, moved.position + Vector2(40, 0))
	check(board.state.offset_of(id) != before, "resume: the piece moved")
	board.save_game()
	var expected := board.state.offset_of(id)

	var capture := _captured_launch(_puzzle("fixture-ember-rings", Vector2i(240, 160), "regular", 12, 1), true, false)
	check(capture.warnings.is_empty(), "resume: no warning (%s)" % capture.warnings)
	check(board.puzzle.image_id == "fixture-tide-stripes", "resume: the saved picture comes back")
	check(board.puzzle.cut_seed == 5, "resume: the saved seed comes back")
	check(board.state.offset_of(id) == expected, "resume: the moved piece comes back where it was")
	check(board._texture.resource_path == _fixture.find("fixture-tide-stripes").path, "resume: the saved picture is drawn")


func _test_unknown_picture_is_set_aside() -> void:
	_edited(func(d: Dictionary) -> void: d.puzzle.image_id = "fixture-gone")
	var capture := _captured_launch(_puzzle("fixture-ember-rings", Vector2i(240, 160), "regular", 12, 3), true, false)
	_check_one_set_aside("unknown picture", capture, "unknown image")
	check(board.puzzle.image_id == "fixture-ember-rings" and board.puzzle.cut_seed == 3,
			"unknown picture: the caller's puzzle starts")


func _test_size_mismatch_is_set_aside() -> void:
	_edited(func(d: Dictionary) -> void: d.puzzle.height = 161)
	var capture := _captured_launch(_puzzle("fixture-ember-rings", Vector2i(240, 160), "regular", 12, 4), true, false)
	_check_one_set_aside("size mismatch", capture, "unknown image")
	check(board.puzzle.image_id == "fixture-ember-rings" and board.puzzle.image_size == Vector2i(240, 160)
			and board.puzzle.cut_seed == 4, "size mismatch: the caller's puzzle starts")


func _test_rejected_resume_falls_back() -> void:
	_launch(_puzzle("fixture-confetti-field", Vector2i(240, 180), "regular", 12, 8), false, true)
	_edited(func(d: Dictionary) -> void:
		d.puzzle.cut_checksum = (int(d.puzzle.cut_checksum) + 1) % 4294967296)
	var capture := _captured_launch(_puzzle("fixture-confetti-field", Vector2i(240, 180), "irregular", 48, 77), true, false)
	_check_one_set_aside("cut drift", capture, "no longer matches")
	var p := board.puzzle
	check(p.image_id == "fixture-confetti-field" and p.style == "irregular" and p.piece_count == 48
			and p.cut_seed == 77, "cut drift: the caller's puzzle starts")
	check(board.cut.size() == 48, "cut drift: the caller's cut is built")


func _test_unusable_start_puzzle() -> void:
	var capture := _captured_launch(_puzzle("fixture-gone", Vector2i(240, 160), "regular", 24, 1), false, true)
	check(capture.warnings.size() == 1 and capture.warnings[0].begins_with("Board: could not start fixture-gone"),
			"unusable start: one warning (%s)" % capture.warnings)
	check(board.puzzle.image_id == Board.IMAGE_ID, "unusable start: the test picture starts")
	check(board.cut.size() == Board.PIECE_COUNT, "unusable start: the test cut is built")
	check(not FileAccess.file_exists(TEST_SAVE_PATH), "the test puzzle does not save at start")


func _test_test_picture() -> void:
	check(board.picture_texture(Board.IMAGE_ID, Board.IMAGE_SIZE) is GradientTexture2D, "the test picture resolves")
	check(board.picture_texture(Board.IMAGE_ID, Vector2i(10, 10)) == null, "the test picture at another size does not")
	board.collection = null
	check(board.picture_texture("fixture-ember-rings", Vector2i(240, 160)) == null,
			"with no collection a collection picture does not resolve")
