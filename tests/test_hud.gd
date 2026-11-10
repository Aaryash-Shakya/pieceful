extends "res://tests/board_test.gd"


func _init() -> void:
	await process_frame
	make_board()
	var hud := board.get_node("Hud") as Hud
	await process_frame

	_test_hud_is_screen_space(hud)
	_test_button_uses_theme(hud)
	_test_button_placement(hud)
	await _test_button_does_not_zoom(hud)
	_test_button_touch_stays_in_hud(hud)
	_test_second_finger_tap_tidies(hud)
	_test_press_tidies(hud)
	_test_attach_is_guarded(hud)
	_test_hud_without_board()
	_test_home_button(hud)
	_test_home_press_goes_home(hud)
	_test_fps_counter_clears_the_buttons()

	board.free()
	finish()


# FpsCounter writes its margin out rather than reading the HUD's, so this keeps the two in step.
func _test_fps_counter_clears_the_buttons() -> void:
	check(FpsCounter.MARGIN_TOP >= Hud.MARGIN_TOP + Hud.BUTTON_SIZE.y, "the frame counter sits below the HUD buttons")


func _test_hud_is_screen_space(hud: Hud) -> void:
	check(hud is CanvasLayer, "the HUD is a canvas layer")
	check(hud.layer == Hud.LAYER, "the HUD sits on its layer")
	check(hud.layer < (board.get_node("FpsCounter") as CanvasLayer).layer, "the frame-rate counter draws above the HUD")
	check(hud.board == board, "the scene wires the board")
	check(hud.root_control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the HUD root lets touches through")
	check(hud.cleanup_button.mouse_filter == Control.MOUSE_FILTER_STOP, "the button stops touches")
	check(hud.cleanup_button.text == "Tidy", "the button says Tidy")


func _test_button_uses_theme(hud: Hud) -> void:
	var b := hud.cleanup_button
	check(b.theme_type_variation == Workshop.TOOL_BUTTON, "Tidy is a tool key")
	check(b.get_theme_font("font").resource_path == UiTheme.BUTTON_PATH, "the button uses Laila")
	var normal := b.get_theme_stylebox("normal") as StyleBoxFlat
	check(normal.bg_color == Workshop.TAB, "the key face is orange")
	check(normal.border_color == Workshop.TAB_LO, "the key edge is the darker orange")
	check(b.get_theme_color("font_color") == Color.WHITE, "the key text is white")
	check(hud.pause_button.theme_type_variation == Workshop.ROUND_BUTTON, "Pause is a round key")


# Pause sits top left under the status bar; Ghost and Tidy sit on the strip at the bottom, under the slots.
func _test_button_placement(hud: Hud) -> void:
	var p := hud.pause_button.get_global_rect()
	check(p.size.is_equal_approx(Hud.BUTTON_SIZE), "Pause is its fixed size")
	check(p.position.is_equal_approx(Vector2(Hud.MARGIN_LEFT, Hud.MARGIN_TOP)), "Pause sits top left, clear of the status bar")
	var label = board.get_node("FpsCounter")._label
	if label != null:
		check(not (label as Label).get_global_rect().intersects(p), "Pause does not cover the frame-rate counter")
	var strip := hud.tool_strip.get_global_rect()
	check(is_equal_approx(strip.end.y, viewport_size.y) and is_equal_approx(strip.size.x, viewport_size.x), "the tool strip spans the bottom edge")
	check(is_equal_approx(strip.size.y, Hud.TOOL_STRIP_HEIGHT), "the tool strip keeps its height: %s" % strip.size)
	for b: Button in [hud.ghost_button, hud.cleanup_button]:
		var r := b.get_global_rect()
		check(r.size.x >= Hud.TOOL_SIZE.x and r.size.y >= Hud.TOOL_SIZE.y, "%s is at least its key size" % b.text)
		check(strip.encloses(r), "%s sits on the strip" % b.text)
		for slot in hud.slot_tray.rects:
			check(not slot.intersects(r), "%s does not cover a slot" % b.text)
	check(not hud.ghost_button.get_global_rect().intersects(hud.cleanup_button.get_global_rect()), "Ghost and Tidy do not overlap")


func _test_button_does_not_zoom(hud: Hud) -> void:
	var r := hud.cleanup_button.get_global_rect()
	camera.zoom = camera.zoom * 2.0
	camera.position += Vector2(300, 200)
	await process_frame
	check(hud.cleanup_button.get_global_rect() == r, "zooming and panning never move the button")


func _push_touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	# Local coordinates: otherwise the window's stretch transform moves the touch off the button.
	root.push_input(event, true)


func _test_button_touch_stays_in_hud(hud: Hud) -> void:
	var at := hud.cleanup_button.get_global_rect().get_center()
	for pressed in [true, false]:
		_push_touch(0, at, pressed)
		if pressed:
			check(board._touches.is_empty(), "a touch on the button never reaches the board")
			check(board._mode == Board.Mode.IDLE, "a touch on the button starts no gesture")


# Through Input, as the phone delivers touches: finger 0 also produces an emulated mouse
# event, so this is the path where a tap could fire twice.
func _send_touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * at
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _test_second_finger_tap_tidies(hud: Hud) -> void:
	var button := hud.cleanup_button.get_global_rect()
	var felt := Vector2.INF
	for y in range(0, int(viewport_size.y), 20):
		for x in range(0, int(viewport_size.x), 20):
			var p := Vector2(x, y)
			if not button.grow(8).has_point(p) and board.piece_at(_to_world(p)) == null:
				felt = p
				break
		if felt != Vector2.INF:
			break
	check(felt != Vector2.INF, "found bare felt on screen")
	var at := button.get_center()

	var count := board._cleanup_count
	_send_touch(0, at, true)
	_send_touch(0, at, false)
	check(board._cleanup_count == count + 1, "a first-finger tap on the button tidies once")
	check(board._touches.is_empty(), "a first-finger tap on the button never reaches the board")
	board._notification(Node.NOTIFICATION_APPLICATION_PAUSED)

	count = board._cleanup_count
	_send_touch(0, felt, true)
	check(board._touches.has(0) and board._mode == Board.Mode.PANNING, "the first finger rests on the felt")
	_send_touch(1, at, true)
	check(not board._touches.has(1), "the second finger's press on the button never reaches the board")
	check(board._cleanup_count == count, "pressing the button does not tidy yet")
	_send_touch(1, at, false)
	check(board._cleanup_count == count + 1, "a second-finger tap on the button tidies once")
	check(not board._touches.has(1), "the second finger's release never reaches the board")
	_send_touch(0, felt, false)
	check(board._touches.is_empty(), "the first finger lifts from the felt")
	board._notification(Node.NOTIFICATION_APPLICATION_PAUSED)


func _test_attach_is_guarded(hud: Hud) -> void:
	var pressed := hud.cleanup_button.pressed
	hud.attach(board)
	check(pressed.get_connections().size() == 1, "attaching the same board twice connects once")
	var other := Board.new()
	hud.attach(other)
	check(hud.board == other, "attach re-points the HUD")
	check(pressed.is_connected(other.cleanup) and not pressed.is_connected(board.cleanup), "re-pointing disconnects the previous board")
	check(pressed.get_connections().size() == 1, "re-pointing leaves one connection")
	hud.attach(board)
	check(pressed.is_connected(board.cleanup) and not pressed.is_connected(other.cleanup), "attaching back restores the board")

	var home := hud.home_button.pressed
	hud.attach(board)
	check(home.get_connections().size() == 1, "attaching the same board twice connects Home once")
	hud.attach(other)
	check(home.is_connected(other.go_home) and not home.is_connected(board.go_home), "re-pointing moves Home to the new board")
	check(home.get_connections().size() == 1, "re-pointing leaves one Home connection")
	hud.attach(board)
	check(home.is_connected(board.go_home) and not home.is_connected(other.go_home), "attaching back restores Home")
	other.free()


func _test_press_tidies(hud: Hud) -> void:
	hud.cleanup_button.pressed.emit()
	check(board.is_tidying(), "pressing Tidy starts the animation")
	board._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not board.is_tidying(), "an app pause completes it")


# Home lives on the Pause card as Save and exit, so it is out of reach until Pause is pressed.
func _test_home_button(hud: Hud) -> void:
	var b := hud.home_button
	check(b.text == "Save and exit", "the leave button says Save and exit")
	check(b.theme_type_variation == Workshop.RED_BUTTON, "it is the red key")
	check(b.mouse_filter == Control.MOUSE_FILTER_STOP, "it stops touches")
	check(b.focus_mode == Control.FOCUS_NONE, "it takes no focus")
	check(not b.is_visible_in_tree() and not hud.pause_overlay.visible, "it waits on the hidden Pause card")
	board.elapsed = 10.0
	hud.pause_button.pressed.emit()
	check(hud.pause_overlay.visible and b.is_visible_in_tree(), "Pause shows the card with it")
	check(board.paused and hud.pause_time.text == "0:10", "Pause stops the clock and shows the time")
	check(hud.pause_overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "the card's dim keeps touches off the board")
	board._focused = true
	board._process(1.0)
	check(is_equal_approx(board.elapsed, 10.0), "the clock does not run while paused")
	hud.ghost_toggle.toggled.emit(false)
	check(not board.puzzle.ghost, "the Ghost switch on the card turns the ghost off")
	hud.ghost_toggle.toggled.emit(true)
	hud.resume_button.pressed.emit()
	check(not hud.pause_overlay.visible and not board.paused, "Resume closes the card and starts the clock")
	_test_restart(hud)


func _test_restart(hud: Hud) -> void:
	var asked: Array[SaveGame.Puzzle] = []
	var listen := func(p: SaveGame.Puzzle) -> void: asked.append(p)
	board.restart_requested.connect(listen)
	hud.restart_button.pressed.emit()
	hud.restart_button.pressed.emit()
	check(asked.size() == 1, "Restart asks once however often it is pressed in a frame")
	if asked.size() == 1:
		var p := asked[0]
		check(p.image_id == board.puzzle.image_id and p.piece_count == board.puzzle.piece_count and p.style == board.puzzle.style, "the same picture, count and style")
		check(p != board.puzzle, "a copy, not the board's own puzzle")
	board.restart_requested.disconnect(listen)
	board._release_home()


func _test_home_press_goes_home(hud: Hud) -> void:
	var count := [0]
	board.home_requested.connect(func() -> void: count[0] += 1)
	SaveFile.remove(TEST_SAVE_PATH)
	hud.home_button.pressed.emit()
	check(count[0] == 1, "pressing Home asks to go home once")
	check(FileAccess.file_exists(TEST_SAVE_PATH), "pressing Home saves")


func _test_hud_without_board() -> void:
	var h := Hud.new()
	root.add_child(h)
	check(h.board == null, "a bare HUD has no board")
	check(h.cleanup_button != null, "a bare HUD still builds its button")
	check(h.cleanup_button.pressed.get_connections().is_empty(), "a bare HUD connects nothing")
	h.free()
