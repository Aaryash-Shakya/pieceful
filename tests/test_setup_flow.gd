extends "res://tests/base_test.gd"
## One trip through the app: setup, Start, Home, Resume and back, with real scene changes.

const LogCapture := preload("res://tests/log_capture.gd")
const SAVE := "user://test_setup/current.json"
const FIXTURE := "res://tests/fixtures/collection/manifest.json"
const Two := preload("res://tests/two_collections.gd")
const STYLES_INDEX := {"regular": 0, "irregular": 1}

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
	await _test_start_uses_the_shown_choices()
	await _test_unresumable_save_is_set_aside()
	await _test_unloadable_saved_picture()
	_test_save_kept_when_pictures_are_unavailable()
	await _test_completed_home_leaves_no_save()
	await _test_resume_in_another_collection()
	_test_no_save_no_card()
	_test_chosen_picture_still_judges_the_save()
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


func _open(collection := _fixture) -> SetupScreen:
	if is_instance_valid(current_scene):
		current_scene.free()
	var s := (load(SetupScreen.SCENE) as PackedScene).instantiate() as SetupScreen
	s.save_path = SAVE
	s.collection = collection
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


func _home_body() -> HomeScreen:
	var host := current_scene as TabHost
	return host.body as HomeScreen if host != null else null


# The board returns to Home. Setup is then opened over the same save, which later steps read.
func _go_home(source := _fixture) -> void:
	var board := current_scene as Board
	if board != null:
		board.go_home()
	await _frames()
	_open(source)


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
	var home := _home_body()
	check(home != null, "Home opens the Home screen")
	if home == null:
		return
	check(home.save_path == SAVE and home.collection == _fixture, "Home keeps the save path and collection")
	check(home.continue_button != null and home.title_label.text == "Confetti Field", "Home offers to continue the puzzle")
	var found := false
	var d := _saved()
	# JSON numbers read back as floats, and Array.has does not match an int against a float.
	for c in d.get("clusters", []):
		if (c.pieces as Array).has(float(_moved_id)):
			found = Vector2(c.offset[0], c.offset[1]) == _moved_offset
	check(found, "the moved piece is saved where it was left")
	var s := _open()
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
	check(_home_body() != null, "back on the board opens Home")
	check(_quits == 0, "back on the board does not quit")
	_home_body()._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(_quits == 1, "back on Home quits: %d" % _quits)
	_open()


func _test_back_on_setup_quits() -> void:
	current_scene._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(_quits == 2, "back on the setup screen quits: %d" % _quits)
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
	check(_children_of_type(TabHost) == 1, "one Home: %d" % _children_of_type(TabHost))
	check(_children_of_type(Board) == 0, "the board is gone")
	_open()


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


# Start while the preview still waits to settle: the board takes what the labels show, and no
# preview is drawn for a screen that is leaving.
func _test_start_uses_the_shown_choices() -> void:
	var s := current_scene as SetupScreen
	if s == null:
		check(false, "precondition: a setup screen")
		return
	s.preview_timer.timeout.emit()
	s.slider.value = (int(s.slider.value) + 3) % s.counts.size()
	check(not s.preview_timer.is_stopped(), "precondition: the preview is waiting to settle")
	var g := s.generations
	var board := s.start()
	check(board != null, "Start launches")
	check(s.generations == g and s.preview_timer.is_stopped(), "Start draws no preview and stops the timer")
	if board != null:
		var p := board.start_puzzle
		check(p.piece_count == s.count and s.count_label.text == "%d pieces" % p.piece_count, "Start launches the shown count")
		check(p.style == s.style and s.style_buttons[STYLES_INDEX[p.style]].button_pressed, "Start launches the shown style")
		check(p.image_id == s.picture.id and p.cut_seed == s.cut_seed, "Start launches the shown picture and seed")
	await _frames()
	if current_scene is Board:
		_quiet(current_scene as Board)
	await _go_home()


func _test_completed_home_leaves_no_save() -> void:
	_clear()
	var s := _open()
	s.start()
	await _frames()
	var board := current_scene as Board
	if board == null:
		check(false, "precondition: a board")
		return
	_quiet(board)
	for root in board.state.roots():
		if not board.state.is_locked(root):
			board.state.move_cluster(root, Vector2.ZERO)
			board.state.drop(root)
	check(board.state.is_complete(), "precondition: the puzzle is complete")
	var capture := LogCapture.new()
	OS.add_logger(capture)
	board.go_home()
	await _frames()
	OS.remove_logger(capture)
	var home := _home_body()
	check(home != null, "Home on a finished puzzle opens the Home screen")
	check(capture.warnings.is_empty() and capture.errors.is_empty(), "a finished puzzle logs nothing: %s %s" % [capture.warnings, capture.errors])
	check(not FileAccess.file_exists(SAVE), "a finished puzzle leaves no save")
	check(not FileAccess.file_exists(SaveFile.bad_path(SAVE)), "nothing is set aside")
	if home != null:
		check(home.continue_button == null, "no Continue for a finished puzzle")


# The picture's thumbnail loads, so its tile shows, but the full picture does not.
func _test_unloadable_saved_picture() -> void:
	DirAccess.remove_absolute(SaveFile.bad_path(SAVE))
	var s := _open()
	s.select_picture(3)
	s.start()
	await _frames()
	if current_scene is Board:
		_quiet(current_scene as Board)
	await _go_home()
	check(int(_saved().get("puzzle", {}).get("width", 0)) == 240 and _saved().puzzle.image_id == "fixture-confetti-field", "precondition: a confetti save")
	var text := FileAccess.get_file_as_string(SAVE)
	var broken := Collection.load_manifest(FIXTURE)
	broken.find("fixture-confetti-field").path = broken.find("fixture-tide-stripes").path
	var capture := LogCapture.new()
	OS.add_logger(capture)
	s = _open(broken)
	var launched := s.resume()
	await _frames()
	OS.remove_logger(capture)
	check(capture.warnings.size() == 2 and capture.warnings[0].begins_with("Collection: could not load picture")
			and capture.warnings[1].begins_with("SetupScreen: could not resume"), "the load and the screen warn once each: %s" % [capture.warnings])
	check(not s.resume_card.visible and s.saved == null, "no resume card")
	check(launched == null and current_scene == s and _children_of_type(Board) == 0, "no stand-in puzzle starts")
	check(s.picture != null and s.picture.id != "fixture-confetti-field", "another picture is selected")
	# The save is fine; only this run's picture failed, so it waits for a later launch.
	_check_kept(text, "a picture that fails to load")


func _check_kept(text: String, label: String) -> void:
	check(FileAccess.file_exists(SAVE) and FileAccess.get_file_as_string(SAVE) == text, "%s: the save is left untouched" % label)
	check(not FileAccess.file_exists(SaveFile.bad_path(SAVE)), "%s: nothing is set aside" % label)


# Runs on the confetti save the last test left in place.
func _test_save_kept_when_pictures_are_unavailable() -> void:
	var text := FileAccess.get_file_as_string(SAVE)
	check(text.contains("fixture-confetti-field"), "precondition: a confetti save")

	var empty := Collection.parse([], "res://none.json")
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var s := _open(empty)
	OS.remove_logger(capture)
	check(capture.warnings.size() == 1 and capture.warnings[0].begins_with("SetupScreen: could not resume"), "empty collection: one warning: %s" % [capture.warnings])
	check(not s.resume_card.visible and s.saved == null, "empty collection: no resume card")
	_check_kept(text, "empty collection")

	var no_thumb := Collection.load_manifest(FIXTURE)
	no_thumb.find("fixture-confetti-field").thumbnail_path = "res://tests/fixtures/collection/thumbs/gone.webp"
	capture = LogCapture.new()
	OS.add_logger(capture)
	s = _open(no_thumb)
	OS.remove_logger(capture)
	check(capture.warnings.size() == 1 and capture.warnings[0].begins_with("Collection: could not load thumbnail"), "failed thumbnail: only its warning: %s" % [capture.warnings])
	# The full picture stands in for the thumbnail, so the game can still be resumed.
	check(s.resume_card.visible and s.saved != null, "failed thumbnail: the resume card shows")
	_check_kept(text, "failed thumbnail")

	# Both fail, so the picture has no tile at all.
	no_thumb.find("fixture-confetti-field").path = no_thumb.find("fixture-tide-stripes").path
	capture = LogCapture.new()
	OS.add_logger(capture)
	s = _open(no_thumb)
	OS.remove_logger(capture)
	check(capture.warnings.size() == 3 and capture.warnings[2].begins_with("SetupScreen: could not resume"), "no tile: the loads and the screen warn: %s" % [capture.warnings])
	check(not s.resume_card.visible and s.saved == null and s.picture_buttons.size() == 5, "no tile: no resume card")
	_check_kept(text, "no tile")


# A chosen picture only hides a usable save; Start would overwrite an unusable one, so it is set aside.
func _test_chosen_picture_still_judges_the_save() -> void:
	_clear()
	SaveFile.write_atomic(SAVE, "{bad")
	if is_instance_valid(current_scene):
		current_scene.free()
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var s := (load(SetupScreen.SCENE) as PackedScene).instantiate() as SetupScreen
	s.save_path = SAVE
	s.collection = _fixture
	s.quit_app = func() -> void: _quits += 1
	s.start_picture_id = _fixture.pictures[1].id
	root.add_child(s)
	current_scene = s
	OS.remove_logger(capture)
	check(capture.warnings.size() == 1 and capture.warnings[0].begins_with("SetupScreen: could not resume"), "chosen picture, corrupt save: one warning: %s" % [capture.warnings])
	check(capture.errors.is_empty(), "chosen picture, corrupt save: no errors: %s" % [capture.errors])
	check(not FileAccess.file_exists(SAVE) and FileAccess.file_exists(SaveFile.bad_path(SAVE)), "chosen picture, corrupt save: moved aside")
	check(s.picture != null and s.picture.id == _fixture.pictures[1].id and not s.resume_card.visible, "chosen picture, corrupt save: the chosen picture is shown")
	_clear()


func _test_no_save_no_card() -> void:
	_clear()
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var s := _open()
	OS.remove_logger(capture)
	check(capture.warnings.is_empty() and capture.errors.is_empty(), "no save logs nothing: %s %s" % [capture.warnings, capture.errors])
	check(not s.resume_card.visible, "no save, no resume card")
	check(not FileAccess.file_exists(SaveFile.bad_path(SAVE)), "nothing is set aside")


func _test_resume_in_another_collection() -> void:
	_clear()
	var merged := Two.merged()
	var s := _open(merged)
	s.select_collection(1)
	s.select_picture(3)
	check(s.picture.id == "second-confetti-field", "precondition: a picture of the second collection")
	s.start_button.pressed.emit()
	await _frames()
	var board := current_scene as Board
	if board == null:
		check(false, "precondition: a board")
		return
	_quiet(board)
	check(board.puzzle.image_id == "second-confetti-field", "the board opens a picture of the second collection")
	board.go_home()
	await _frames()
	var landing := _home_body()
	check(landing != null and landing.collection == merged and landing.continue_button != null, "Home keeps the merged collection and offers Continue")
	var home := _open(merged)
	check(home.collection == merged and home.sections.size() == 2, "the screen keeps the merged collection")
	check(home.resume_card.visible and home.saved != null, "the resume card shows")
	check(home.section_index == 1 and home.collection_buttons[1].button_pressed, "the picker opens on the saved picture's collection")
	check(home.picture.id == "second-confetti-field" and home.picture_buttons[3].button_pressed, "the saved picture is chosen")
	check(home.resume_label.text.begins_with("Confetti Field"), "the card names the picture: %s" % home.resume_label.text)
	check(home.resume_thumb.texture != null, "the card shows its thumbnail")
	check(not FileAccess.file_exists(SaveFile.bad_path(SAVE)), "nothing is set aside")

	# A fresh launch reads the same save.
	var again := _open(merged)
	check(again.resume_card.visible and again.section_index == 1 and again.picture.id == "second-confetti-field", "a fresh launch opens on the saved collection")
	again.resume_button.pressed.emit()
	await _frames()
	board = current_scene as Board
	if board != null:
		_quiet(board)
		check(board.puzzle.image_id == "second-confetti-field", "Resume opens the saved picture")
		board.go_home()
		await _frames()
	_clear()


func _test_main_scene() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://src/ui/app_shell.tscn", "the app opens in the shell")
	# No collection handed in: the screen loads the bundled library.
	_clear()
	if is_instance_valid(current_scene):
		current_scene.free()
	var s := (load(SetupScreen.SCENE) as PackedScene).instantiate() as SetupScreen
	s.save_path = SAVE
	root.add_child(s)
	current_scene = s
	check(s.collection_buttons.size() == 4 and s.collection_buttons[0].text == "Abstract", "the bundled collections are offered")
	check(s.section_index == 0 and s.picture.id == "abstract-ember-rings", "the first collection's first picture is chosen")
