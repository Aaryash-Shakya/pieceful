extends "res://tests/base_test.gd"
## The Pictures tab: collection tabs, a grid of pictures, and Cut, which opens Setup on the chosen one.

const LogCapture := preload("res://tests/log_capture.gd")
const SAVE := "user://test_pictures/current.json"
const SHELL_SETTINGS := "user://test_pictures_shell.cfg"
const FIXTURE := "res://tests/fixtures/collection/manifest.json"

var _fixture := Collection.load_manifest(FIXTURE)
var _library: Collection
var _quits := 0


func _init() -> void:
	await process_frame
	_library = _two_parts(_fixture)
	_test_tap_guard()
	await _test_tabs_and_tiles()
	await _test_single_collection_has_no_tabs()
	await _test_select_collection()
	await _test_cut_opens_setup()
	await _test_chosen_picture_beats_save()
	await _test_back_from_setup()
	await _test_swipe_does_not_select()
	await _test_all_pictures_fail()
	await _test_back_goes_home()
	await _test_home_opens_pictures()
	await _test_layout()
	await _test_background()
	DirAccess.remove_absolute(SAVE.get_base_dir())
	finish()


func _frames() -> void:
	await process_frame
	await process_frame


func _two_parts(source: Collection) -> Collection:
	var first := Collection.new()
	first.id = "first"
	first.title = "First"
	var second := Collection.new()
	second.id = "second"
	second.title = "Second"
	for i in source.pictures.size():
		(first if i < 2 else second).pictures.append(source.pictures[i])
	var parts: Array[Collection] = [first, second]
	return CollectionLibrary.merge(parts)


func _pictures(source: Collection) -> PicturesScreen:
	var screen := PicturesScreen.new()
	screen.save_path = SAVE
	screen.collection = source
	screen.quit_app = func() -> void: _quits += 1
	return screen


func _mount(screen: PicturesScreen) -> Control:
	var frame := Control.new()
	frame.size = Vector2(540, 1200)
	root.add_child(frame)
	frame.add_child(TabHost.make(&"pictures", screen, {}))
	return frame


# A shell whose root screen is Pictures, as the app reaches it from Home.
func _shell_with_pictures(source: Collection) -> Array:
	var shell := (load("res://src/ui/app_shell.tscn") as PackedScene).instantiate() as AppShell
	shell.settings_path = SHELL_SETTINGS
	var made: Array[PicturesScreen] = []
	shell.make_home = func() -> Node:
		var screen := _pictures(source)
		made.append(screen)
		return TabHost.make(&"pictures", screen, {})
	root.add_child(shell)
	await _frames()
	return [shell, made[0]]


func _test_tap_guard() -> void:
	var guard := TapGuard.new()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = Vector2(100, 100)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.global_position = Vector2(100, 100 + TapGuard.SLOP + 1.0)
	guard.watch(press)
	guard.watch(release)
	check(guard.take_swipe(), "a release past the slop is a swipe")
	check(not guard.take_swipe(), "the swipe is read once")
	release.global_position = Vector2(100, 103)
	guard.watch(press)
	guard.watch(release)
	check(not guard.take_swipe(), "a small movement is a tap")


func _test_tabs_and_tiles() -> void:
	var screen := _pictures(_library)
	var frame := _mount(screen)
	await _frames()
	check(screen.sections.size() == 2 and screen.tab_buttons.size() == 2, "one tab per section")
	check(screen.tab_buttons[0].text == "First" and screen.tab_buttons[0].is_visible_in_tree(), "tabs show the section titles")
	check(screen.tiles.size() == 2 and screen.pictures.size() == 2, "the first section's pictures are tiled")
	check(screen.picture == screen.pictures[0] and screen.tiles[0].button_pressed, "the first picture is chosen")
	check(screen.cut_button.text == "Cut %s" % screen.picture.title and not screen.cut_button.disabled, "Cut names the picture")
	var grid := screen.tiles[0].get_parent().get_parent() as GridContainer
	check(grid != null and grid.columns == 2, "two fixed columns")
	check(not screen.empty_label.visible, "no empty message")
	check(screen.more_button.disabled and screen.more_button.text == "More pictures", "More pictures is disabled")
	check(screen.more_note.text == "Coming soon", "and says it is coming")
	frame.free()


func _test_single_collection_has_no_tabs() -> void:
	var screen := _pictures(_fixture)
	var frame := _mount(screen)
	await _frames()
	check(screen.sections.size() == 1 and screen.tab_buttons.size() == 1, "a plain collection is its own section")
	check(not screen.tab_buttons[0].is_visible_in_tree(), "one section needs no tab")
	check(screen.tiles.size() == _fixture.pictures.size(), "every picture has a tile")
	frame.free()


func _test_select_collection() -> void:
	var screen := _pictures(_library)
	var frame := _mount(screen)
	await _frames()
	screen.select_picture(1)
	check(screen.picture == screen.pictures[1] and screen.tiles[1].button_pressed and not screen.tiles[0].button_pressed, "select_picture moves the choice")
	screen.select_collection(1)
	await _frames()
	check(screen.section_index == 1 and screen.tab_buttons[1].button_pressed, "the tab is chosen")
	check(screen.tiles.size() == _library.parts[1].pictures.size(), "the tiles follow the tab")
	check(screen.picture == _library.parts[1].pictures[0], "the first picture of the tab is chosen")
	check(screen.cut_button.text == "Cut %s" % screen.picture.title, "Cut follows the choice")
	frame.free()


func _test_cut_opens_setup() -> void:
	var made: Array = await _shell_with_pictures(_library)
	var shell := made[0] as AppShell
	var screen := made[1] as PicturesScreen
	screen.select_collection(1)
	screen.select_picture(1)
	var chosen := screen.picture.id
	var setup := screen.cut()
	check(setup != null, "cut returns the Setup")
	check(screen.cut() == null, "a second cut opens nothing")
	screen.cut_button.pressed.emit()
	await _frames()
	check(shell.top() is SetupScreen and shell.top() == setup, "Setup is on top")
	check(shell.depth() == 2, "Setup is pushed over Pictures, not in place of it: %d" % shell.depth())
	var top := shell.top() as SetupScreen
	check(top.start_picture_id == chosen and top.picture.id == chosen, "Setup opens on the chosen picture")
	check(top.save_path == SAVE and top.collection == _library, "Setup gets the save path and collection")
	shell.free()


func _write_save_for(picture_id: String) -> void:
	var snapshot := SaveGame.Snapshot.new()
	var saved_picture := _fixture.find(picture_id)
	snapshot.puzzle.image_id = picture_id
	snapshot.puzzle.image_size = saved_picture.size()
	snapshot.puzzle.style = "regular"
	snapshot.puzzle.piece_count = 24
	snapshot.puzzle.cut_seed = 7
	for id in 24:
		var cluster := SaveGame.Cluster.new()
		cluster.root = id
		cluster.pieces = PackedInt32Array([id])
		snapshot.clusters.append(cluster)
	for s in PuzzleState.SLOT_COUNT:
		snapshot.slots.append(PackedInt32Array())
	SaveFile.write_atomic(SAVE, SaveGame.to_json(snapshot))


func _test_chosen_picture_beats_save() -> void:
	var a := _fixture.pictures[0]
	var b := _fixture.pictures[1]
	_write_save_for(a.id)
	var before := FileAccess.get_file_as_string(SAVE)
	var setup := (load(SetupScreen.SCENE) as PackedScene).instantiate() as SetupScreen
	setup.save_path = SAVE
	setup.collection = _fixture
	setup.quit_app = func() -> void: _quits += 1
	setup.start_picture_id = b.id
	root.add_child(setup)
	check(setup.picture != null and setup.picture.id == b.id, "Setup shows the chosen picture, not the saved one")
	check(not setup.resume_card.visible and setup.saved == null, "the resume card stays hidden")
	check(FileAccess.get_file_as_string(SAVE) == before and not FileAccess.file_exists(SaveFile.bad_path(SAVE)), "the save is untouched")
	setup.free()

	# The whole flow: Home, New puzzle, pick B, Cut.
	var shell := (load("res://src/ui/app_shell.tscn") as PackedScene).instantiate() as AppShell
	shell.settings_path = SHELL_SETTINGS
	shell.make_home = func() -> Node: return Control.new()
	root.add_child(shell)
	await _frames()
	var home := HomeScreen.open(self, SAVE, _fixture, func() -> void: _quits += 1)
	await _frames()
	home.new_button.pressed.emit()
	await _frames()
	var pictures_screen := (shell.top() as TabHost).body as PicturesScreen
	pictures_screen.select_picture(1)
	pictures_screen.cut()
	await _frames()
	var top := shell.top() as SetupScreen
	check(top != null and top.picture.id == b.id, "Home, Pictures, Cut lands on the picked picture")
	check(top != null and not top.resume_card.visible, "with no resume card")
	check(FileAccess.get_file_as_string(SAVE) == before, "and the save is still there")
	shell.free()
	SaveFile.remove(SAVE)


func _test_back_from_setup() -> void:
	var made: Array = await _shell_with_pictures(_library)
	var shell := made[0] as AppShell
	var screen := made[1] as PicturesScreen
	screen.select_collection(1)
	screen.select_picture(1)
	var chosen := screen.picture.id
	screen.cut()
	await _frames()
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames()
	check(shell.depth() == 1 and shell.top() is TabHost, "back from Setup returns to the Pictures tab")
	check(shell.get_child_count() == 1 and shell.top().is_inside_tree(), "Pictures is the only child, in the tree")
	check(screen.is_inside_tree() and screen.picture.id == chosen and screen.section_index == 1, "with the same choice")
	# Cut works again after coming back.
	var again := screen.cut()
	check(again != null, "Cut can be used again after back")
	await _frames()
	shell.free()


func _test_swipe_does_not_select() -> void:
	var screen := _pictures(_library)
	var frame := _mount(screen)
	await _frames()
	var before := screen.picture
	var tile := screen.tiles[1]
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = Vector2(200, 600)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.global_position = Vector2(200, 600 - 60)
	tile.gui_input.emit(press)
	tile.gui_input.emit(release)
	tile.pressed.emit()
	check(screen.picture == before and screen.tiles[0].button_pressed, "a tap that was a scroll does not select")
	tile.pressed.emit()
	check(screen.picture == screen.pictures[1], "the next plain tap does")
	frame.free()


func _test_all_pictures_fail() -> void:
	var broken := Collection.new()
	broken.id = "broken"
	broken.title = "Broken"
	var picture := Collection.Picture.new()
	picture.id = "broken-1"
	picture.title = "Gone"
	# Present but the wrong size, which fails with one warning and no engine error.
	picture.path = "res://tests/fixtures/collection/ember-rings.webp"
	picture.width = 100
	picture.height = 100
	broken.pictures.append(picture)
	var parts: Array[Collection] = [_library.parts[0], broken]
	var merged := CollectionLibrary.merge(parts)
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var screen := _pictures(merged)
	var frame := _mount(screen)
	await _frames()
	screen.select_collection(1)
	await _frames()
	OS.remove_logger(capture)
	check(screen.tiles.is_empty() and screen.picture == null, "no tile for a picture that fails")
	check(screen.empty_label.visible and screen.empty_label.text == "No pictures found", "the empty message shows")
	check(screen.cut_button.disabled, "Cut is disabled")
	check(screen.cut() == null, "cut does nothing with no picture")
	check(not capture.warnings.is_empty() and capture.errors.is_empty(), "only the expected warnings: %s %s" % [capture.warnings, capture.errors])
	screen.select_collection(0)
	await _frames()
	check(not screen.empty_label.visible and not screen.cut_button.disabled, "a collection that loads brings Cut back")
	frame.free()


func _test_back_goes_home() -> void:
	var made: Array = await _shell_with_pictures(_fixture)
	var shell := made[0] as AppShell
	var screen := made[1] as PicturesScreen
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames()
	var host := shell.top() as TabHost
	check(host != null and host.body is HomeScreen, "back from Pictures presents Home")
	shell.free()


func _test_home_opens_pictures() -> void:
	var shell := (load("res://src/ui/app_shell.tscn") as PackedScene).instantiate() as AppShell
	shell.settings_path = SHELL_SETTINGS
	shell.make_home = func() -> Node: return Control.new()
	root.add_child(shell)
	await _frames()
	var home := HomeScreen.open(self, SAVE, _fixture, func() -> void: _quits += 1)
	await _frames()
	check(not home.new_button.disabled, "New puzzle is enabled on a stock Home")
	home.new_button.pressed.emit()
	await _frames()
	var host := shell.top() as TabHost
	check(host != null and host.body is PicturesScreen, "New puzzle presents Pictures in a tab host")
	check(host != null and host.routes.has(&"home"), "Pictures can go back Home by the nav")
	host.routes[&"home"].call().free()
	shell.free()


func _test_layout() -> void:
	var screen := _pictures(_library)
	var frame := _mount(screen)
	await _frames()
	var host := screen.get_parent() as TabHost
	check(screen.bottom_pad.custom_minimum_size.y >= host.nav_clearance(), "content is padded past the nav")
	var cut_rect := screen.cut_button.get_global_rect()
	check(cut_rect.end.y <= 1200.0 - host.nav_clearance() + 0.5, "Cut sits above the nav")
	check(cut_rect.size.y >= 66.0, "Cut is at least 66 px tall")
	for tab in screen.tab_buttons:
		check(tab.size.y >= 66.0, "%s is at least 66 px tall" % tab.text)
	for tile in screen.tiles:
		check(tile.size.y >= 66.0, "a tile is at least 66 px tall")
	var wide := []
	var stack: Array[Node] = [screen]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is Control and (node as Control).is_visible_in_tree():
			var rect := (node as Control).get_global_rect()
			if rect.position.x < -0.5 or rect.end.x > 540.5:
				wide.append("%s %s" % [node.name, rect])
	check(wide.is_empty(), "nothing reaches past the viewport width: %s" % [wide])
	frame.free()


func _test_background() -> void:
	var screen := _pictures(_library)
	var frame := _mount(screen)
	await _frames()
	var back := screen.get_child(0) as ColorRect
	check(back != null and back.color == Palette.page_background(), "the backmost child is the page colour")
	check(back != null and back.get_global_rect().size.is_equal_approx(Vector2(540, 1200)), "the background covers the viewport")
	frame.free()
