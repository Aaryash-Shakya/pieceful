extends "res://tests/base_test.gd"
## One trip through the app: setup, Start, Home, Resume and back, with real scene changes.

const LogCapture := preload("res://tests/log_capture.gd")
const SAVE := "user://test_setup/current.json"
const FIXTURE := "res://tests/fixtures/collection/manifest.json"

var _fixture := Collection.load_manifest(FIXTURE)
var _quits := 0
# Carried from one step to the next, as the steps are one trip.
var _count := 0
var _board_seed := 0
var _moved_id := -1
var _moved_offset := Vector2.ZERO


func _init() -> void:
	await process_frame
	_clear()
	await _test_start_builds_the_chosen_board()
	await _test_home_returns_and_saves()
	await _test_resume_restores()
	await _test_back_on_board_goes_home()
	_test_back_on_setup_quits()
	await _test_start_twice_launches_once()
	await _test_start_replaces_the_save()
	await _test_unresumable_save_is_set_aside()
	_test_no_save_no_card()
	_test_main_scene()
	if is_instance_valid(current_scene):
		current_scene.free()
	_clear()
	DirAccess.remove_absolute(SAVE.get_base_dir())
	finish()


func _clear() -> void:
	SaveFile.remove(SAVE)
	if FileAccess.file_exists(SaveFile.bad_path(SAVE)):
		DirAccess.remove_absolute(SaveFile.bad_path(SAVE))


func _open() -> SetupScreen:
	if is_instance_valid(current_scene):
		current_scene.free()
	var s := (load(SetupScreen.SCENE) as PackedScene).instantiate() as SetupScreen
	s.save_path = SAVE
	s.collection = _fixture
	s.quit_app = func() -> void: _quits += 1
	root.add_child(s)
	current_scene = s
	return s


func _frames() -> void:
	await process_frame
	await process_frame


# Real playback would leave the audio server holding streams when a headless test exits.
func _quiet(board: Board) -> void:
	var feedback := board.get_node("Feedback") as Feedback
	feedback.sound_enabled = false
	feedback.vibration_enabled = false


func _saved() -> Dictionary:
	if not FileAccess.file_exists(SAVE):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	return d if d is Dictionary else {}


func _children_of_type(type: Variant) -> int:
	var n := 0
	for child in root.get_children():
		if is_instance_of(child, type):
			n += 1
	return n


func _go_home() -> void:
	var board := current_scene as Board
	if board != null:
		board.go_home()
	await _frames()


func _test_start_builds_the_chosen_board() -> void:
	var s := _open()
	s.select_picture(3)
	s.select_style("irregular")
	s.slider.value = s.counts.find(SetupScreen.nearest_count(s.counts, 24))
	var cut_seed := s.cut_seed
	_count = s.count
	check(s.picture.id == "fixture-confetti-field" and _count != 54, "precondition: the choices changed")
	s.start_button.pressed.emit()
	await _frames()
	check(current_scene is Board, "Start opens the board")
	check(not is_instance_valid(s), "the setup screen is freed")
	var board := current_scene as Board
	if board == null:
		return
	_quiet(board)
	_board_seed = board.puzzle.cut_seed
	check(board.puzzle.image_id == "fixture-confetti-field", "the chosen picture")
	check(board.puzzle.image_size == Vector2i(240, 180), "the picture's size")
	check(board.puzzle.style == "irregular", "the chosen style")
	check(board.puzzle.piece_count == _count, "the chosen count")
	check(board.puzzle.cut_seed == cut_seed, "the previewed seed")
	check(board.cut.size() == _count, "the cut has the chosen count: %d" % board.cut.size())
	check(board.save_path == SAVE, "the board saves where the screen reads")
	var d := _saved()
	check(not d.is_empty() and int(d.puzzle.seed) == cut_seed, "the new game is saved at once")


func _test_home_returns_and_saves() -> void:
	var board := current_scene as Board
	if board == null:
		check(false, "precondition: a board")
		return
	var node := board.pieces.get_child(0) as PieceNode
	_moved_id = node.piece_id
	_moved_offset = board.state.offset_of(_moved_id) + Vector2(40, 0)
	board.state.move_cluster(_moved_id, _moved_offset)
	node.position = _moved_offset
	board.go_home()
	await _frames()
	check(current_scene is SetupScreen, "Home opens the setup screen")
	var s := current_scene as SetupScreen
	if s == null:
		return
	check(s.save_path == SAVE and s.collection == _fixture, "the screen keeps the save path and collection")
	var found := false
	var d := _saved()
	# JSON numbers read back as floats, and Array.has does not match an int against a float.
	for c in d.get("clusters", []):
		if (c.pieces as Array).has(float(_moved_id)):
			found = Vector2(c.offset[0], c.offset[1]) == _moved_offset
	check(found, "the moved piece is saved where it was left")
	check(s.resume_card.visible, "the resume card shows")
	check(s.resume_label.text == "Confetti Field · %d pieces · Irregular" % _count, "resume label: %s" % s.resume_label.text)
	check(s.resume_thumb.texture != null, "the resume card shows the thumbnail")
	check(s.picture != null and s.picture.id == "fixture-confetti-field" and s.picture_buttons[3].button_pressed, "the saved picture is selected")
	check(s.style == "irregular" and s.style_buttons[1].button_pressed, "the saved style is selected")
	check(s.count == _count and s.counts[int(s.slider.value)] == _count, "the saved count is selected")
	check(s.cut_seed != _board_seed, "a new visit draws a new seed")


func _test_resume_restores() -> void:
	var s := current_scene as SetupScreen
	if s == null:
		check(false, "precondition: a setup screen")
		return
	var capture := LogCapture.new()
	OS.add_logger(capture)
	s.resume_button.pressed.emit()
	await _frames()
	OS.remove_logger(capture)
	check(capture.warnings.is_empty() and capture.errors.is_empty(), "resume logs nothing: %s %s" % [capture.warnings, capture.errors])
	check(current_scene is Board, "Resume opens the board")
	var board := current_scene as Board
	if board == null:
		return
	_quiet(board)
	check(board.puzzle.cut_seed == _board_seed, "the saved seed, not the screen's")
	check(board.state.offset_of(_moved_id) == _moved_offset, "the moved piece is where it was left")


func _test_back_on_board_goes_home() -> void:
	current_scene._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames()
	check(current_scene is SetupScreen, "back on the board opens the setup screen")
	check(_quits == 0, "back on the board does not quit")


func _test_back_on_setup_quits() -> void:
	current_scene._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(_quits == 1, "back on the setup screen quits: %d" % _quits)
	check(current_scene is SetupScreen, "the runner did not quit")


func _test_start_twice_launches_once() -> void:
	var s := current_scene as SetupScreen
	if s == null:
		check(false, "precondition: a setup screen")
		return
	var b1 := s.start()
	var b2 := s.start()
	var b3 := s.resume()
	check(b1 != null, "the first Start launches")
	check(b2 == null and b3 == null, "later launches are refused")
	check(s.start_button.disabled and s.resume_button.disabled, "both buttons are disabled")
	await _frames()
	check(current_scene == b1, "the first board is the scene")
	check(_children_of_type(Board) == 1, "one board in the tree")
	if b1 == null:
		return
	_quiet(b1)
	b1.go_home()
	b1.go_home()
	b1._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames()
	check(_children_of_type(SetupScreen) == 1, "one setup screen: %d" % _children_of_type(SetupScreen))
	check(_children_of_type(Board) == 0, "the board is gone")


func _test_start_replaces_the_save() -> void:
	var s := current_scene as SetupScreen
	if s == null:
		check(false, "precondition: a setup screen")
		return
	check(s.resume_card.visible, "precondition: a resume card")
	var cut_seed := s.cut_seed
	s.start_button.pressed.emit()
	await _frames()
	var d := _saved()
	check(not d.is_empty() and int(d.puzzle.seed) == cut_seed, "Start replaces the save")
	check(not FileAccess.file_exists(SaveFile.bad_path(SAVE)), "the replaced save is not set aside")
	if current_scene is Board:
		_quiet(current_scene as Board)
	await _go_home()


func _test_unresumable_save_is_set_aside() -> void:
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var cases := {"broken JSON": "{bad"}
	var gradient := good.duplicate(true)
	gradient.puzzle.image_id = "test-gradient"
	gradient.puzzle.width = Board.IMAGE_SIZE.x
	gradient.puzzle.height = Board.IMAGE_SIZE.y
	cases["the test picture"] = JSON.stringify(gradient)
	var wrong_size := good.duplicate(true)
	wrong_size.puzzle.image_id = "fixture-ember-rings"
	wrong_size.puzzle.height = 161
	cases["a size mismatch"] = JSON.stringify(wrong_size)
	var grid := good.duplicate(true)
	grid.puzzle.style = "grid"
	cases["the grid style"] = JSON.stringify(grid)
	for label in cases:
		SaveFile.write_atomic(SAVE, cases[label])
		if is_instance_valid(current_scene):
			current_scene.free()
		var capture := LogCapture.new()
		OS.add_logger(capture)
		var s := _open()
		OS.remove_logger(capture)
		check(capture.warnings.size() == 1 and capture.warnings[0].begins_with("SetupScreen: could not resume"), "%s: one warning: %s" % [label, capture.warnings])
		check(capture.errors.is_empty(), "%s: no errors: %s" % [label, capture.errors])
		check(not s.resume_card.visible, "%s: no resume card" % label)
		check(not FileAccess.file_exists(SAVE) and FileAccess.file_exists(SaveFile.bad_path(SAVE)), "%s: the save is set aside" % label)
		s.start_button.pressed.emit()
		await _frames()
		check(FileAccess.file_exists(SAVE), "%s: Start saves a fresh game" % label)
		if current_scene is Board:
			_quiet(current_scene as Board)
		await _go_home()


func _test_no_save_no_card() -> void:
	_clear()
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var s := _open()
	OS.remove_logger(capture)
	check(capture.warnings.is_empty() and capture.errors.is_empty(), "no save logs nothing: %s %s" % [capture.warnings, capture.errors])
	check(not s.resume_card.visible, "no save, no resume card")
	check(not FileAccess.file_exists(SaveFile.bad_path(SAVE)), "nothing is set aside")


func _test_main_scene() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://src/ui/setup_screen.tscn", "the app opens on the setup screen")
