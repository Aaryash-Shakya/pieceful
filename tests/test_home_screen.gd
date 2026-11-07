extends "res://tests/base_test.gd"
## The Home tab: the resume hero, the first-launch state, and the way out to a board.

const LogCapture := preload("res://tests/log_capture.gd")
const SAVE := "user://test_home/current.json"
const SHELL_SETTINGS := "user://test_home_shell.cfg"
const FIXTURE := "res://tests/fixtures/collection/manifest.json"
const PICTURE_ID := "fixture-ember-rings"

var _fixture := Collection.load_manifest(FIXTURE)
var _quits := 0
var _opened := 0


func _init() -> void:
	await process_frame
	_clear()
	_test_summary_without_a_save()
	_test_summary_of_a_save()
	await _test_first_launch_form()
	await _test_resume_form()
	await _test_missing_picture_save()
	await _test_continue_once()
	await _test_pictures_route()
	await _test_back_quits()
	await _test_layout()
	_clear()
	DirAccess.remove_absolute(SAVE.get_base_dir())
	finish()


func _clear() -> void:
	SaveFile.remove(SAVE)
	if FileAccess.file_exists(SaveFile.bad_path(SAVE)):
		DirAccess.remove_absolute(SaveFile.bad_path(SAVE))


func _frames() -> void:
	await process_frame
	await process_frame


# Hand-made, so the progress numbers are known: 6 of 24 pieces locked, 125 s played.
func _write_save(picture_id := PICTURE_ID) -> void:
	var snapshot := SaveGame.Snapshot.new()
	snapshot.puzzle.image_id = picture_id
	snapshot.puzzle.image_size = Vector2i(240, 160)
	snapshot.puzzle.style = "regular"
	snapshot.puzzle.piece_count = 24
	snapshot.puzzle.cut_seed = 7
	for id in 24:
		var cluster := SaveGame.Cluster.new()
		cluster.root = id
		cluster.pieces = PackedInt32Array([id])
		cluster.locked = id < 6
		snapshot.clusters.append(cluster)
	for s in PuzzleState.SLOT_COUNT:
		snapshot.slots.append(PackedInt32Array())
	snapshot.elapsed = 125.0
	SaveFile.write_atomic(SAVE, SaveGame.to_json(snapshot))


func _home() -> HomeScreen:
	var home := HomeScreen.new()
	home.save_path = SAVE
	home.collection = _fixture
	home.quit_app = func() -> void: _quits += 1
	return home


func _mount(home: HomeScreen) -> Control:
	var frame := Control.new()
	frame.size = Vector2(540, 1200)
	root.add_child(frame)
	frame.add_child(TabHost.make(&"home", home, {}))
	return frame


func _shell() -> AppShell:
	var shell := (load("res://src/ui/app_shell.tscn") as PackedScene).instantiate() as AppShell
	shell.settings_path = SHELL_SETTINGS
	shell.make_home = func() -> Node: return Control.new()
	root.add_child(shell)
	return shell


func _test_summary_without_a_save() -> void:
	check(HomeScreen.summary(SAVE, _fixture).is_empty(), "no save gives an empty summary")


func _test_summary_of_a_save() -> void:
	_write_save()
	var s := HomeScreen.summary(SAVE, _fixture)
	check(s.get("title") == "Ember Rings", "the summary has the picture title: %s" % [s])
	check(s.get("piece_count") == 24 and s.get("style_name") == "Regular", "the summary has count and style")
	check(is_equal_approx(s.get("progress", -1.0), 0.25), "progress is locked pieces over the count")
	check(s.get("played") == "2:05", "played is m:ss: %s" % s.get("played"))
	check(s.get("saved") is SaveGame.Snapshot, "the summary carries the snapshot")
	check(HomeScreen.format_played(3725.0) == "1:02:05", "an hour or more shows h:mm:ss")
	_clear()


func _test_first_launch_form() -> void:
	_clear()
	var home := _home()
	var frame := _mount(home)
	await _frames()
	check(home.continue_button == null, "no Continue without a save")
	check(home.title_label.text == "Let's make a puzzle", "first-launch headline")
	check(home.eyebrow_label.text == "Free · no ads · works offline", "first-launch eyebrow")
	check(not home.empty_note.visible, "no extra line without a save file")
	check(home.new_button.text == "Pick a picture", "Pick a picture is the primary button")
	check(home.daily_tile.disabled and home.daily_tile.text.contains("Coming soon"), "the daily tile is disabled and says so")
	var first := _fixture.pictures[0]
	check(home.hero.texture != null and Vector2i(home.hero.texture.get_size()) == first.size(), "the hero is the first bundled picture")
	frame.free()


func _test_resume_form() -> void:
	_write_save()
	var home := _home()
	var frame := _mount(home)
	await _frames()
	check(home.continue_button != null and home.continue_button.visible, "Continue shows for a save")
	check(home.title_label.text == "Ember Rings", "the picture title")
	check(home.eyebrow_label.text.begins_with("Resume") and home.eyebrow_label.text.contains("2:05 played"), "the eyebrow reads Resume and the time: %s" % home.eyebrow_label.text)
	check(home.progress_bar != null and is_equal_approx(home.progress_bar.value, 25.0), "the bar shows 25 percent")
	check(not home.empty_note.visible, "no extra line when the save works")
	check(home.new_button.text.begins_with("New puzzle"), "New puzzle tile")
	frame.free()
	_clear()


func _test_missing_picture_save() -> void:
	_write_save("no-such-picture")
	var before := FileAccess.get_file_as_string(SAVE)
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var home := _home()
	var frame := _mount(home)
	await _frames()
	OS.remove_logger(capture)
	check(capture.warnings.is_empty() and capture.errors.is_empty(), "Home logs nothing: %s %s" % [capture.warnings, capture.errors])
	check(home.continue_button == null, "no Continue for a save it cannot use")
	check(home.title_label.text == "Let's make a puzzle", "first-launch form")
	check(home.empty_note.visible and home.empty_note.text == "Start a new one", "the Start a new one line")
	check(FileAccess.file_exists(SAVE) and FileAccess.get_file_as_string(SAVE) == before, "the save is untouched")
	check(not FileAccess.file_exists(SaveFile.bad_path(SAVE)), "nothing is set aside")
	frame.free()
	_clear()


func _test_continue_once() -> void:
	# A real save, written by a real board.
	var shell := _shell()
	await _frames()
	var puzzle := SaveGame.Puzzle.new()
	puzzle.image_id = PICTURE_ID
	puzzle.image_size = Vector2i(240, 160)
	puzzle.style = "regular"
	puzzle.piece_count = 24
	puzzle.cut_seed = 5
	BoardLaunch.launch(self, SAVE, _fixture, puzzle, false, func() -> void: pass)
	await _frames()
	shell.free()
	check(FileAccess.file_exists(SAVE), "precondition: the board saved")

	shell = _shell()
	await _frames()
	var home := HomeScreen.open(self, SAVE, _fixture, func() -> void: _quits += 1)
	await _frames()
	check(shell.top() is TabHost and home.continue_button != null, "Home is presented in a tab host")
	var board := home.continue_game()
	check(board != null and board.resume and board.start_puzzle.image_id == PICTURE_ID, "Continue resumes the save")
	check(home.continue_game() == null, "a second press launches nothing")
	home.continue_button.pressed.emit()
	await _frames()
	check(shell.top() is Board and (shell.top() as Board).resume, "the board is on top")
	check(shell.get_child_count() == 1, "one board only")
	if shell.top() is Board:
		var feedback := (shell.top() as Board).get_node("Feedback") as Feedback
		feedback.sound_enabled = false
		feedback.vibration_enabled = false
	shell.free()
	_clear()


func _test_pictures_route() -> void:
	var shell := _shell()
	await _frames()
	var bare := _home()
	shell.add_child(bare)
	await _frames()
	check(bare.new_button.disabled, "Pick a picture is disabled without a Pictures screen")
	bare.free()

	_opened = 0
	var home := _home()
	home.open_pictures = func() -> Node:
		_opened += 1
		var screen := Control.new()
		screen.name = "FakePictures"
		return screen
	shell.add_child(home)
	await _frames()
	check(not home.new_button.disabled, "enabled once Pictures can open")
	home.new_button.pressed.emit()
	home.new_button.pressed.emit()
	await _frames()
	check(_opened == 1, "pressing twice opens Pictures once")
	check(shell.top() != null and shell.top().name == "FakePictures", "the Pictures screen is presented")
	shell.free()


func _test_back_quits() -> void:
	_quits = 0
	var home := _home()
	var frame := _mount(home)
	await _frames()
	home.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(_quits == 1, "back quits from Home")
	frame.free()


func _test_layout() -> void:
	_write_save()
	var home := _home()
	var frame := _mount(home)
	await _frames()
	var host := home.get_parent() as TabHost
	check(is_equal_approx(home.bottom_pad.custom_minimum_size.y, host.nav_clearance()), "content is padded by the nav clearance")
	var wide := []
	var stack: Array[Node] = [home]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is Control and (node as Control).is_visible_in_tree():
			var rect := (node as Control).get_global_rect()
			if rect.position.x < -0.5 or rect.end.x > 540.5:
				wide.append("%s %s" % [node.name, rect])
	check(wide.is_empty(), "nothing reaches past the viewport width: %s" % [wide])
	for button in [home.continue_button, home.new_button]:
		check(button.size.y >= 66.0, "%s is at least 66 px tall" % button.text)
	frame.free()
	_clear()
