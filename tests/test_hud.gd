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
	_test_press_tidies(hud)
	_test_hud_without_board()

	board.free()
	finish()


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
	check(is_equal_approx(r.position.y, FpsCounter.MARGIN_TOP), "the button clears the status bar")
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


func _test_button_touch_stays_in_hud(hud: Hud) -> void:
	var at := hud.cleanup_button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = pressed
		# Local coordinates: otherwise the window's stretch transform moves the touch off the button.
		root.push_input(event, true)
		if pressed:
			check(board._touches.is_empty(), "a touch on the button never reaches the board")
			check(board._mode == Board.Mode.IDLE, "a touch on the button starts no gesture")


func _test_press_tidies(hud: Hud) -> void:
	hud.cleanup_button.pressed.emit()
	check(board.is_tidying(), "pressing Tidy starts the animation")
	board._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not board.is_tidying(), "an app pause completes it")


func _test_hud_without_board() -> void:
	var h := Hud.new()
	root.add_child(h)
	check(h.board == null, "a bare HUD has no board")
	check(h.cleanup_button != null, "a bare HUD still builds its button")
	check(h.cleanup_button.pressed.get_connections().is_empty(), "a bare HUD connects nothing")
	h.free()
