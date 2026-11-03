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
	check((b.get_theme_font("font") as FontVariation).base_font.resource_path == UiTheme.BALOO_PATH, "the button uses Baloo 2")
	check(b.get_theme_font_size("font_size") == UiTheme.BUTTON_FONT_SIZE, "the button uses the button font size")
	var normal := b.get_theme_stylebox("normal") as StyleBoxFlat
	check(normal.bg_color == Palette.accent(), "the button face is the accent")
	check(normal.border_color == Palette.accent_shadow(), "the button edge is the accent shadow")
	check(b.get_theme_color("font_color") == Palette.text_on_accent(), "the button text is on-accent")


func _test_button_placement(hud: Hud) -> void:
	var r := hud.cleanup_button.get_global_rect()
	check(r.size.is_equal_approx(Hud.BUTTON_SIZE), "the button is its fixed size")
	check(is_equal_approx(r.end.x, viewport_size.x - Hud.MARGIN_RIGHT), "the button sits at the right margin")
	check(is_equal_approx(r.position.y, Hud.MARGIN_TOP), "the button clears the status bar")
	check(r.end.y <= viewport_size.y * 0.25, "the bottom stays free for slots")
	var label = board.get_node("FpsCounter")._label
	if label != null:
		check(not (label as Label).get_global_rect().intersects(r), "the button does not cover the frame-rate counter")


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


func _test_home_button(hud: Hud) -> void:
	var b := hud.home_button
	check(b.text == "Home", "the Home button says Home")
	check(b.mouse_filter == Control.MOUSE_FILTER_STOP, "the Home button stops touches")
	check(b.focus_mode == Control.FOCUS_NONE, "the Home button takes no focus")
	var r := b.get_global_rect()
	check(r.size.is_equal_approx(Hud.BUTTON_SIZE), "the Home button is its fixed size")
	check(r.position.is_equal_approx(Vector2(Hud.MARGIN_LEFT, Hud.MARGIN_TOP)), "the Home button sits top left")
	check(not r.intersects(hud.cleanup_button.get_global_rect()), "Home does not cover Tidy")
	var label = board.get_node("FpsCounter")._label
	if label != null:
		check(not (label as Label).get_global_rect().intersects(r), "Home does not cover the frame-rate counter")
	check(r.end.y <= viewport_size.y * 0.25, "Home leaves the bottom free for slots")
	var normal := b.get_theme_stylebox("normal") as StyleBoxFlat
	var tidy := hud.cleanup_button.get_theme_stylebox("normal") as StyleBoxFlat
	check(normal.bg_color == tidy.bg_color and normal.border_color == tidy.border_color, "Home is styled like Tidy")


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
