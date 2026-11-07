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
	_test_rejected_resume_loads_nothing()
	_test_unloadable_picture_is_set_aside()
	_test_round_trip_inexact_count()
	_test_unusable_start_puzzle()
	_test_bad_style_or_count()
	_test_fallback_never_saves()
	_test_test_picture()
	board.free()
	await _test_launch_helper()
	await _test_start_picture()
	await _test_setup_back()
	finish()


const SHELL_SETTINGS := "user://test_board_launch_shell.cfg"
const LAUNCH_SAVE := "user://test_board_launch/current.json"
var _quits := 0


func _shell() -> AppShell:
	var shell := (load("res://src/ui/app_shell.tscn") as PackedScene).instantiate() as AppShell
	shell.settings_path = SHELL_SETTINGS
	shell.make_home = func() -> Node: return Control.new()
	root.add_child(shell)
	return shell


func _end_shell(shell: AppShell) -> void:
	root.remove_child(shell)
	shell.free()
	Settings.use(Settings.new())
	if FileAccess.file_exists(SHELL_SETTINGS):
		DirAccess.remove_absolute(SHELL_SETTINGS)


func _test_launch_helper() -> void:
	SaveFile.remove(LAUNCH_SAVE)
	var shell := _shell()
	var puzzle := _puzzle("fixture-ember-rings", Vector2i(240, 160), "regular", 12, 7)
	var launched := BoardLaunch.launch(shell.get_tree(), LAUNCH_SAVE, _fixture, puzzle, false, func() -> void: _quits += 1)
	await process_frame
	check(launched != null and launched.start_puzzle == puzzle and not launched.resume, "launch: the board gets the puzzle")
	check(launched.save_path == LAUNCH_SAVE and launched.collection == _fixture, "launch: the board gets the save path and collection")
	check(shell.top() == launched, "launch: the board is the shell's top")
	var feedback := launched.get_node("Feedback") as Feedback
	feedback.sound_enabled = false
	feedback.vibration_enabled = false
	launched.home_requested.emit()
	await process_frame
	await process_frame
	check(shell.top() != null and not (shell.top() is Board), "launch: home leaves a non-board screen on top")
	_end_shell(shell)
	SaveFile.remove(LAUNCH_SAVE)
	DirAccess.remove_absolute(LAUNCH_SAVE.get_base_dir())


func _setup(tree_parent: Node = null) -> SetupScreen:
	var s := (load(SetupScreen.SCENE) as PackedScene).instantiate() as SetupScreen
	s.save_path = "user://test_board_launch/none.json"
	s.collection = _fixture
	s.quit_app = func() -> void: _quits += 1
	return s


func _test_start_picture() -> void:
	var second := _fixture.pictures[1]
	var s := _setup()
	s.start_picture_id = second.id
	root.add_child(s)
	check(s.picture != null and s.picture.id == second.id, "start picture: the chosen picture is selected")
	s.free()
	var unknown := _setup()
	unknown.start_picture_id = "fixture-gone"
	root.add_child(unknown)
	check(unknown.picture != null and unknown.picture.id == _fixture.pictures[0].id, "start picture: an unknown id falls back to the first")
	unknown.free()


func _test_setup_back() -> void:
	var shell := _shell()
	var s := _setup()
	shell.push(s)
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	check(shell.depth() == 1 and _quits == 0, "back: setup above the root pops")
	check(shell.get_child_count() == 1 and shell.top().is_inside_tree(), "back: the root screen is back in the tree")
	_end_shell(shell)
	var alone := _setup()
	root.add_child(alone)
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(_quits == 1, "back: setup with no shell quits")
	alone.free()
	var root_shell := _shell()
	var at_root := _setup()
	root_shell.replace(at_root)
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(_quits == 2 and root_shell.depth() == 1, "back: setup at depth 1 quits")
	_end_shell(root_shell)


# Lists a real picture under another picture's id and size, so the manifest check passes but the load fails.
func _broken_collection() -> Collection:
	var broken := Collection.new()
	var picture := Collection.Picture.new()
	picture.id = "fixture-confetti-field"
	picture.path = _fixture.find("fixture-tide-stripes").path
	picture.width = 240
	picture.height = 180
	broken.pictures.append(picture)
	return broken


func _puzzle(id: String, size: Vector2i, style: String, count: int, cut_seed: int) -> SaveGame.Puzzle:
	var p := SaveGame.Puzzle.new()
	p.image_id = id
	p.image_size = size
	p.style = style
	p.piece_count = count
	p.cut_seed = cut_seed
	return p


func _launch(puzzle: SaveGame.Puzzle, resume: bool, fresh: bool, source: Collection = null) -> void:
	if board != null:
		board.free()
		board = null
	var used := source if source != null else _fixture
	make_board(fresh, true, func(b: Board) -> void:
		b.collection = used
		b.start_puzzle = puzzle
		b.resume = resume)


func _captured_launch(puzzle: SaveGame.Puzzle, resume: bool, fresh: bool, source: Collection = null) -> LogCapture:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	_launch(puzzle, resume, fresh, source)
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
	check(board._base_bounds == Rect2(0, 0, 240, 160).grow(Board.LOOSE_MARGIN) and bounds == board._base_bounds,
			"start: the bounds follow the picture (%s)" % board._base_bounds)
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
	_show_everything()
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
	check(board._base_bounds == Rect2(0, 0, 240, 240).grow(Board.LOOSE_MARGIN) and bounds == board._base_bounds,
			"resume: the bounds follow the saved picture (%s)" % board._base_bounds)


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


# The board left by _test_rejected_resume_falls_back is a saved fixture-confetti-field game.
func _test_rejected_resume_loads_nothing() -> void:
	_edited(func(d: Dictionary) -> void:
		d.puzzle.cut_checksum = (int(d.puzzle.cut_checksum) + 1) % 4294967296)
	var capture := _captured_launch(null, true, false, _broken_collection())
	_check_one_set_aside("rejected before loading", capture, "no longer matches")


func _test_unloadable_picture_is_set_aside() -> void:
	_launch(_puzzle("fixture-confetti-field", Vector2i(240, 180), "regular", 12, 8), false, true)
	var capture := _captured_launch(null, true, false, _broken_collection())
	var set_aside := PackedStringArray()
	for w in capture.warnings:
		if w.begins_with("Board: could not use the save at"):
			set_aside.append(w)
	check(set_aside.size() == 1 and set_aside[0].contains("could not load image fixture-confetti-field"),
			"unloadable picture: the save is set aside with its own reason (%s)" % capture.warnings)
	check(FileAccess.file_exists(SaveFile.bad_path(TEST_SAVE_PATH)), "unloadable picture: the save is kept aside")
	check(board.puzzle.image_id == Board.IMAGE_ID, "unloadable picture: the test puzzle starts")


# 23 has no rows-by-columns split, so the cut has another count and the save keeps the one asked.
func _test_round_trip_inexact_count() -> void:
	_launch(_puzzle("fixture-ember-rings", Vector2i(240, 160), "regular", 23, 6), false, true)
	var pieces_cut := board.cut.size()
	check(pieces_cut != 23, "inexact count: the cut snaps to a valid split (%d)" % pieces_cut)
	var capture := _captured_launch(_puzzle("fixture-tide-stripes", Vector2i(240, 240), "regular", 16, 1), true, false)
	check(capture.warnings.is_empty() and capture.errors.is_empty(),
			"inexact count: resumes quietly (%s %s)" % [capture.warnings, capture.errors])
	check(board.puzzle.image_id == "fixture-ember-rings" and board.puzzle.piece_count == 23
			and board.puzzle.cut_seed == 6, "inexact count: the asked count comes back")
	check(board.cut.size() == pieces_cut, "inexact count: the same cut comes back")
	check(board._base_bounds == Rect2(0, 0, 240, 160).grow(Board.LOOSE_MARGIN), "inexact count: the bounds follow the picture")


func _test_bad_style_or_count() -> void:
	var cases := [["wild", 12], ["regular", 0], ["regular", SaveGame.MAX_PIECE_COUNT + 1]]
	for c: Array in cases:
		var label := "%s %d" % [c[0], c[1]]
		var capture := _captured_launch(_puzzle("fixture-ember-rings", Vector2i(240, 160), c[0], c[1], 2), false, true)
		check(capture.warnings.size() == 1 and capture.warnings[0].begins_with("Board: could not start fixture-ember-rings"),
				"%s: one warning (%s)" % [label, capture.warnings])
		check(capture.errors.is_empty(), "%s: no error (%s)" % [label, capture.errors])
		check(board.puzzle.image_id == Board.IMAGE_ID, "%s: the test puzzle starts" % label)


# The stand-in test puzzle must never overwrite the player's real save, on pause or on a lock.
func _test_fallback_never_saves() -> void:
	_launch(_puzzle("fixture-ember-rings", Vector2i(240, 160), "regular", 12, 9), false, true)
	var real := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	check(real != "", "fallback: a real save exists")
	_launch(_puzzle("fixture-gone", Vector2i(240, 160), "regular", 12, 1), false, false)
	check(board.puzzle.image_id == Board.IMAGE_ID, "fallback: the test puzzle starts")
	board._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_show_everything()
	var locked: PieceNode = null
	for i in board.state.piece_count():
		if _is_loose_singleton(i) and _grab_point(board.node_for(i)) != Vector2.INF:
			locked = board.node_for(i)
			break
	if locked != null:
		_move_by_touch(locked, Vector2.ZERO)
	check(locked != null and board.state.is_locked(locked.piece_id), "fallback: a piece locks")
	check(not board.save_game(), "fallback: save_game refuses")
	check(FileAccess.get_file_as_string(TEST_SAVE_PATH) == real, "fallback: the real save is untouched")


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
