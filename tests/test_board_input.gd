extends BaseTest

var board: Board
var camera: Camera2D
var pieces: Node2D
var viewport_size: Vector2
var bounds: Rect2


func _init() -> void:
	# Root only enters the tree once the main loop starts, and Board._ready needs it.
	await process_frame
	board = load("res://src/game/board.tscn").instantiate()
	root.add_child(board)
	camera = board.camera
	pieces = board.pieces
	viewport_size = board.get_viewport_rect().size
	bounds = Rect2(Vector2.ZERO, Vector2(Board.IMAGE_SIZE)).grow(Board.LOOSE_MARGIN)

	_test_piece_drag()
	_test_pan_clamps()
	_test_second_finger_during_drag()
	_test_second_finger_pans_while_holding()
	_test_spread_zooms_while_holding()
	_test_drag_continues_after_second_finger_lifts()
	_test_first_finger_lifts_while_holding()
	_test_third_finger_while_holding()
	_test_no_edge_pan_while_second_finger_down()
	_test_cancel_while_holding_with_two_fingers()
	_test_pinch_lift_one_finger()
	_test_cancel_releases_piece()
	_test_pinch_zoom_clamps()
	_test_wheel_zooms_about_cursor()
	_test_edge_pan_carries_piece()
	_test_two_finger_pan()
	_test_pinch_ignores_zero_distance()
	_test_focus_loss_releases_piece(Node.NOTIFICATION_APPLICATION_FOCUS_OUT, "focus out")
	_test_focus_loss_releases_piece(Node.NOTIFICATION_APPLICATION_PAUSED, "pause")

	board.free()
	finish()


func _test_piece_drag() -> void:
	_show_everything()
	var hit := _find_covered_point()
	var piece: PieceNode = hit[1]
	var start := piece.position
	var relative := Vector2(12, -7)

	_touch(0, hit[0], true)
	check(_is_held(piece), "pressed piece is held")
	check(pieces.get_child(pieces.get_child_count() - 1) == piece, "pressed piece moves to the top")
	_drag(0, hit[0] + relative, relative)
	check(piece.position.is_equal_approx(start + relative / camera.zoom.x), "piece moves by relative over zoom")
	_touch(0, hit[0] + relative, false)
	check(not _is_held(piece), "piece is released on touch up")
	check(pieces.get_child(pieces.get_child_count() - 1) == piece, "released piece stays on top")


func _test_pan_clamps() -> void:
	_show_everything()
	var empty := _find_empty_point()
	var start := camera.position
	var relative := Vector2(30, 20)

	_touch(0, empty, true)
	_drag(0, empty + relative, relative)
	check(camera.position.is_equal_approx(start - relative / camera.zoom.x), "one finger on empty space pans")
	_drag(0, empty, Vector2(1e6, 1e6))
	check(camera.position.is_equal_approx(bounds.position), "a huge pan stops at the bounds corner")
	_drag(0, empty, Vector2(-1e7, -1e7))
	check(camera.position.is_equal_approx(bounds.end), "a huge pan the other way stops at the far corner")
	_touch(0, empty, false)


func _test_second_finger_during_drag() -> void:
	_show_everything()
	var hit := _find_covered_point()
	var piece: PieceNode = hit[1]
	var a: Vector2 = hit[0] + Vector2(5, 5)
	var b: Vector2 = hit[0] + Vector2(200, 0)

	_touch(0, hit[0], true)
	_drag(0, a, Vector2(5, 5))
	var dragged := piece.position
	_touch(1, b, true)
	check(_is_held(piece), "second finger keeps the piece held")
	check(pieces.get_child(pieces.get_child_count() - 1) == piece, "held piece stays on top when a second finger lands")
	check(piece.position == dragged, "second finger landing does not move the held piece")
	_touch(0, a, false)
	_touch(1, b, false)
	check(not _is_held(piece), "nothing is held after all fingers lift")


func _test_second_finger_pans_while_holding() -> void:
	_show_everything()
	var hit := _find_covered_point()
	var piece: PieceNode = hit[1]
	var a: Vector2 = hit[0]
	var b := a + Vector2(100, 0)
	var offset := piece.position - _to_world(a)
	var start := camera.position
	var zoom := camera.zoom.x

	_touch(0, a, true)
	_touch(1, b, true)
	# B swings round A at a fixed distance, so only the midpoint moves: a pure pan by half B's move.
	var relative := Vector2(-100, 100)
	_drag(1, b + relative, relative)
	check(camera.position.is_equal_approx(start - relative / 2.0 / zoom), "second finger alone pans the camera while a piece is held")
	check(is_equal_approx(camera.zoom.x, zoom), "second finger swinging at a fixed distance leaves the zoom unchanged")
	check(_is_held(piece), "piece stays held while the second finger pans")
	check(_near(piece.position, _to_world(a) + offset), "held piece stays under the first finger while the second pans")
	_touch(1, b + relative, false)
	_touch(0, a, false)


func _test_spread_zooms_while_holding() -> void:
	_show_everything()
	var hit := _find_covered_point()
	var piece: PieceNode = hit[1]
	var a: Vector2 = hit[0]
	var b := a + Vector2(100, 0)
	var offset := piece.position - _to_world(a)
	var zoom := camera.zoom.x

	_touch(0, a, true)
	_touch(1, b, true)
	# Off-axis moves: along the A-B line a pinch keeps the world under A fixed anyway, which would prove nothing.
	_drag(1, b + Vector2(100, 60), Vector2(100, 60))
	check(camera.zoom.x > zoom and camera.zoom.x <= CameraRig.MAX_ZOOM, "spreading the fingers zooms in while a piece is held")
	check(_near(piece.position, _to_world(a) + offset), "held piece stays under the first finger through a zoom")
	var moved := a + Vector2(-50, 40)
	_drag(0, moved, Vector2(-50, 40))
	check(_near(piece.position, _to_world(moved) + offset), "held piece stays under the first finger when it moves in a pinch")
	_drag(1, b + Vector2(1e6, 0), Vector2(1e6, 0))
	check(is_equal_approx(camera.zoom.x, CameraRig.MAX_ZOOM), "zoom while holding stops at MAX_ZOOM")
	check(_inside_bounds(camera.position), "camera stays inside bounds while holding")
	check(_near(piece.position, _to_world(moved) + offset), "held piece stays under the first finger at the zoom limit")
	_touch(0, moved, false)
	_touch(1, b, false)


func _test_drag_continues_after_second_finger_lifts() -> void:
	_show_everything()
	var hit := _find_covered_point()
	var piece: PieceNode = hit[1]
	var a: Vector2 = hit[0]
	var b := a + Vector2(100, 0)

	_touch(0, a, true)
	_touch(1, b, true)
	# Zoom first so the check below uses the new zoom, not the one at grab time.
	_drag(1, b + Vector2(100, 0), Vector2(100, 0))
	var before := piece.position
	_touch(1, b + Vector2(100, 0), false)
	check(_is_held(piece), "piece stays held after the second finger lifts")
	check(piece.position == before, "second finger lifting does not move the piece")
	var relative := Vector2(12, -7)
	_drag(0, a + relative, relative)
	check(_near(piece.position, before + relative / camera.zoom.x), "drag carries on by relative over zoom after the second finger lifts")
	_touch(0, a + relative, false)
	check(not _is_held(piece), "piece is released when the last finger lifts")


func _test_first_finger_lifts_while_holding() -> void:
	_show_everything()
	var hit := _find_covered_point()
	var piece: PieceNode = hit[1]
	var a: Vector2 = hit[0]
	var b := a + Vector2(100, 0)

	_touch(0, a, true)
	_touch(1, b, true)
	_drag(1, b + Vector2(0, 30), Vector2(0, 30))
	var placed := piece.position
	_touch(0, a, false)
	check(not _is_held(piece), "lifting the holding finger releases the piece")
	check(piece.position == placed, "lifting the holding finger leaves the piece where it is")

	var position := camera.position
	var zoom := camera.zoom
	_drag(1, b + Vector2(80, 40), Vector2(80, 10))
	check(camera.position == position, "leftover second finger does not pan")
	check(camera.zoom == zoom, "leftover second finger does not zoom")
	check(piece.position == placed, "leftover second finger does not move the released piece")
	_touch(1, b + Vector2(80, 40), false)

	var empty := _find_empty_point()
	position = camera.position
	_touch(0, empty, true)
	_drag(0, empty + Vector2(10, 0), Vector2(10, 0))
	check(camera.position.is_equal_approx(position - Vector2(10, 0) / camera.zoom.x), "a fresh touch after all fingers lift pans normally")
	_touch(0, empty + Vector2(10, 0), false)


func _test_third_finger_while_holding() -> void:
	_show_everything()
	var hit := _find_covered_point()
	var piece: PieceNode = hit[1]
	var a: Vector2 = hit[0]
	var b := a + Vector2(100, 0)
	var c := a + Vector2(0, 100)
	var offset := piece.position - _to_world(a)

	_touch(0, a, true)
	_touch(1, b, true)
	_touch(2, c, true)
	var position := camera.position
	var zoom := camera.zoom
	_drag(2, c + Vector2(30, 0), Vector2(30, 0))
	check(camera.position == position and camera.zoom == zoom, "a third finger does not move the camera while two are paired")
	_touch(1, b, false)
	check(camera.position == position and camera.zoom == zoom, "the paired finger lifting does not jump the camera")
	check(_is_held(piece), "piece stays held when a paired finger lifts with a third still down")
	_drag(2, c + Vector2(30, 60), Vector2(0, 60))
	check(camera.zoom.x > zoom.x, "the first finger re-pairs with the third")
	check(_near(piece.position, _to_world(a) + offset), "held piece stays under the first finger after re-pairing")
	_touch(0, a, false)
	check(not _is_held(piece), "lifting the holding finger releases the piece with a third finger down")
	_touch(2, c + Vector2(30, 60), false)


func _test_no_edge_pan_while_second_finger_down() -> void:
	_show_everything()
	var hit := _find_covered_point()
	var piece: PieceNode = hit[1]
	var offset := piece.position - _to_world(hit[0])
	var edge := Vector2(viewport_size.x, viewport_size.y / 2.0)
	var b := viewport_size / 2.0

	_touch(0, hit[0], true)
	_drag(0, edge, edge - hit[0])
	_touch(1, b, true)
	var camera_before := camera.position
	board._process(0.1)
	check(camera.position == camera_before, "no edge pan while a second finger is down")
	_touch(1, b, false)
	board._process(0.1)
	check(not camera.position.is_equal_approx(camera_before), "edge pan resumes once the second finger lifts")
	check(_near(piece.position, _to_world(edge) + offset), "edge pan keeps the held piece under the finger")
	_touch(0, edge, false)


func _test_cancel_while_holding_with_two_fingers() -> void:
	_show_everything()
	var hit := _find_covered_point()
	var piece: PieceNode = hit[1]
	var a: Vector2 = hit[0]

	_touch(0, a, true)
	_touch(1, a + Vector2(100, 0), true)
	_touch(1, a + Vector2(100, 0), false, true)
	check(not _is_held(piece), "a cancelled touch during a hold and pinch releases the piece")
	check(board._mode == Board.Mode.IDLE, "a cancelled touch during a hold and pinch goes idle")
	var placed := piece.position
	_drag(0, a + Vector2(30, 30), Vector2(30, 30))
	check(piece.position == placed, "drags after the cancel do not move the piece")

	for what: int in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_PAUSED]:
		hit = _find_covered_point()
		piece = hit[1]
		_touch(0, hit[0], true)
		_touch(1, hit[0] + Vector2(100, 0), true)
		board.notification(what)
		check(not _is_held(piece), "losing focus during a hold and pinch releases the piece")
		check(board._mode == Board.Mode.IDLE, "losing focus during a hold and pinch goes idle")


func _test_pinch_lift_one_finger() -> void:
	_fit_board()
	var a := viewport_size / 2.0 - Vector2(100, 0)
	var b := viewport_size / 2.0 + Vector2(100, 0)

	_touch(0, a, true)
	_touch(1, b, true)
	var zoom_before := camera.zoom
	_drag(1, b + Vector2(50, 0), Vector2(50, 0))
	check(camera.zoom.x > zoom_before.x, "spreading fingers zooms in")
	_touch(1, b + Vector2(50, 0), false)

	var position := camera.position
	var zoom := camera.zoom
	_drag(0, a + Vector2(80, 40), Vector2(80, 40))
	check(camera.position == position, "remaining finger does not pan after a pinch")
	check(camera.zoom == zoom, "remaining finger does not zoom after a pinch")
	_touch(0, a + Vector2(80, 40), false)

	var empty := _find_empty_point()
	position = camera.position
	_touch(0, empty, true)
	_drag(0, empty + Vector2(10, 0), Vector2(10, 0))
	check(not camera.position.is_equal_approx(position), "a fresh touch after all fingers lift pans again")
	_touch(0, empty + Vector2(10, 0), false)


func _test_cancel_releases_piece() -> void:
	_show_everything()
	var hit := _find_covered_point()
	var piece: PieceNode = hit[1]

	_touch(0, hit[0], true)
	_drag(0, hit[0] + Vector2(3, 3), Vector2(3, 3))
	var dragged := piece.position
	_touch(0, hit[0] + Vector2(3, 3), false, true)
	check(not _is_held(piece), "a cancelled touch releases the piece")
	_drag(0, hit[0] + Vector2(30, 30), Vector2(27, 27))
	check(piece.position == dragged, "drags after a cancel do not move the piece")

	# Cancel during a pinch, then a single finger must behave as a fresh first touch.
	hit = _find_covered_point()
	_touch(0, hit[0], true)
	_touch(1, hit[0] + Vector2(100, 0), true)
	_touch(0, hit[0], false, true)
	_touch(1, hit[0] + Vector2(100, 0), false, true)
	_touch(0, hit[0], true)
	check(_is_held(pieces.get_child(pieces.get_child_count() - 1)), "first touch after a cancelled pinch picks a piece")
	_touch(0, hit[0], false)


func _test_pinch_zoom_clamps() -> void:
	_fit_board()
	var centre := viewport_size / 2.0
	var a := centre - Vector2(10, 0)
	var b := centre + Vector2(10, 0)

	_touch(0, a, true)
	_touch(1, b, true)
	_drag(1, centre + Vector2(5000, 0), Vector2(4990, 0))
	check(is_equal_approx(camera.zoom.x, CameraRig.MAX_ZOOM), "pinch zoom stops at MAX_ZOOM")
	check(_inside_bounds(camera.position), "camera stays inside bounds after zooming in")
	_drag(1, centre + Vector2(10.01, 0), Vector2(-4989.99, 0))
	check(is_equal_approx(camera.zoom.x, CameraRig.MIN_ZOOM), "pinch zoom stops at MIN_ZOOM")
	check(camera.zoom.x == camera.zoom.y, "zoom stays uniform")
	_touch(0, centre, false)
	_touch(1, centre, false)

	var empty := _find_empty_point()
	_touch(0, empty, true)
	_drag(0, empty, Vector2(-1e7, 1e7))
	check(camera.position.is_equal_approx(Vector2(bounds.end.x, bounds.position.y)), "a huge pan at min zoom stays inside the bounds")
	_touch(0, empty, false)


func _test_wheel_zooms_about_cursor() -> void:
	_fit_board()
	var cursor := viewport_size / 2.0 + Vector2(120, -60)
	var world_before := _to_world(cursor)
	var zoom_before := camera.zoom.x

	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = cursor
	board._unhandled_input(wheel)
	check(camera.zoom.x > zoom_before, "wheel up zooms in")
	check(_to_world(cursor).is_equal_approx(world_before), "wheel zoom keeps the point under the cursor fixed")

	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for i in 100:
		board._unhandled_input(wheel)
	check(is_equal_approx(camera.zoom.x, CameraRig.MIN_ZOOM), "wheel zoom stops at MIN_ZOOM")
	check(_inside_bounds(camera.position), "wheel zoom keeps the camera inside bounds")

	# On the desktop the mouse is the finger, so a piece it holds must stay under it through a wheel zoom.
	_show_everything()
	var hit := _find_covered_point()
	var piece: PieceNode = hit[1]
	var offset := piece.position - _to_world(hit[0])
	_touch(0, hit[0], true)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.position = viewport_size / 2.0
	board._unhandled_input(wheel)
	check(_near(piece.position, _to_world(hit[0]) + offset), "wheel zoom keeps a held piece under the pointer")
	_touch(0, hit[0], false)


func _test_two_finger_pan() -> void:
	_fit_board()
	var a := viewport_size / 2.0 - Vector2(100, 0)
	var b := viewport_size / 2.0 + Vector2(100, 0)
	var delta := Vector2(40, 25)
	var start := camera.position
	var zoom := camera.zoom.x

	_touch(0, a, true)
	_touch(1, b, true)
	_drag(0, a + delta, delta)
	_drag(1, b + delta, delta)
	check(camera.position.is_equal_approx(start - delta / zoom), "two fingers moved together pan the camera by delta over zoom")
	check(is_equal_approx(camera.zoom.x, zoom), "two fingers moved together leave the zoom unchanged")

	_drag(0, a + Vector2(1e6, 1e6), Vector2(1e6, 1e6) - delta)
	_drag(1, b + Vector2(1e6, 1e6), Vector2(1e6, 1e6) - delta)
	check(_inside_bounds(camera.position), "a huge two-finger pan stays inside the bounds")
	_touch(0, a, false)
	_touch(1, b, false)


func _test_pinch_ignores_zero_distance() -> void:
	_fit_board()
	var a := viewport_size / 2.0 - Vector2(50, 0)
	var b := viewport_size / 2.0 + Vector2(50, 0)
	var zoom := camera.zoom.x

	_touch(0, a, true)
	_touch(1, b, true)
	_drag(1, a, a - b)
	check(is_equal_approx(camera.zoom.x, zoom), "fingers meeting do not collapse the zoom")
	_drag(1, b, b - a)
	check(is_equal_approx(camera.zoom.x, zoom), "fingers parting from one point do not jump the zoom")
	_touch(0, a, false)
	_touch(1, b, false)


func _test_focus_loss_releases_piece(what: int, label: String) -> void:
	_show_everything()
	var hit := _find_covered_point()
	var piece: PieceNode = hit[1]

	_touch(0, hit[0], true)
	_drag(0, hit[0] + Vector2(2, 2), Vector2(2, 2))
	board.notification(what)
	check(not _is_held(piece), "%s releases the held piece" % label)

	var empty := _find_empty_point()
	var start := camera.position
	_touch(0, empty, true)
	_drag(0, empty + Vector2(10, 0), Vector2(10, 0))
	check(camera.position.is_equal_approx(start - Vector2(10, 0) / camera.zoom.x), "a touch after %s pans normally" % label)
	_touch(0, empty + Vector2(10, 0), false)


func _test_edge_pan_carries_piece() -> void:
	_show_everything()
	var hit := _find_covered_point()
	var piece: PieceNode = hit[1]
	camera.position = bounds.get_center()

	_touch(0, hit[0], true)
	var edge := Vector2(viewport_size.x, viewport_size.y / 2.0)
	_drag(0, edge, Vector2.ZERO)
	var camera_before := camera.position
	var piece_before := piece.position
	board._process(0.1)
	var moved := camera.position - camera_before
	check(is_equal_approx(moved.x, 600.0 * 0.1 / camera.zoom.x), "edge pan moves the camera at max speed over zoom")
	check(piece.position.is_equal_approx(piece_before + moved), "edge pan carries the held piece with the camera")
	for i in 1000:
		board._process(0.1)
	check(camera.position.x == bounds.end.x, "edge pan stops at the bounds")
	_touch(0, edge, false)

	camera_before = camera.position
	board._process(0.1)
	check(camera.position == camera_before, "no edge pan once released")


func _touch(index: int, position: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	board._unhandled_input(event)


func _drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	board._unhandled_input(event)


func _is_held(piece: PieceNode) -> bool:
	return (piece.get_child(0) as Polygon2D).visible


func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.01


func _inside_bounds(point: Vector2) -> bool:
	return point.clamp(bounds.position, bounds.end) == point


func _to_world(screen: Vector2) -> Vector2:
	return camera.position + (screen - viewport_size / 2.0) / camera.zoom.x


func _to_screen(world: Vector2) -> Vector2:
	return (world - camera.position) * camera.zoom.x + viewport_size / 2.0


func _show_everything() -> void:
	camera.zoom = Vector2(CameraRig.MIN_ZOOM, CameraRig.MIN_ZOOM)
	camera.position = bounds.get_center()


func _fit_board() -> void:
	var fit := viewport_size.x / (Board.IMAGE_SIZE.x * Board.BORDER)
	camera.zoom = Vector2(fit, fit)
	camera.position = Vector2(Board.IMAGE_SIZE) / 2.0


# A screen point over a piece that is not already the top child, with the piece
# the board should pick there: the highest-index piece containing the point.
func _find_covered_point() -> Array:
	var last := pieces.get_child_count() - 1
	# Scan only where pieces can be, the loose area on screen, to keep the test fast.
	var low := _to_screen(bounds.position).max(Vector2.ZERO)
	var high := _to_screen(bounds.end).min(viewport_size)
	for y in range(int(low.y), int(high.y), 4):
		for x in range(int(low.x), int(high.x), 4):
			var screen := Vector2(x, y)
			var top := _top_piece_at(_to_world(screen))
			if top != null and top.get_index() != last:
				return [screen, top]
	check(false, "found a screen point over a piece")
	return [Vector2.ZERO, pieces.get_child(0)]


func _find_empty_point() -> Vector2:
	for y in range(0, int(viewport_size.y), 8):
		for x in range(0, int(viewport_size.x), 8):
			var screen := Vector2(x, y)
			if _top_piece_at(_to_world(screen)) == null:
				return screen
	check(false, "found an empty screen point")
	return Vector2.ZERO


func _top_piece_at(world: Vector2) -> PieceNode:
	for i in range(pieces.get_child_count() - 1, -1, -1):
		var piece := pieces.get_child(i) as PieceNode
		if piece.contains_point(world):
			return piece
	return null
