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

	_touch(0, hit[0], true)
	_drag(0, hit[0] + Vector2(5, 5), Vector2(5, 5))
	var dragged := piece.position
	_touch(1, hit[0] + Vector2(200, 0), true)
	check(not _is_held(piece), "second finger releases the held piece")
	check(piece.position == dragged, "second finger leaves the piece where it was")
	_drag(0, hit[0] + Vector2(-40, 5), Vector2(-45, 0))
	check(piece.position == dragged, "pinching does not move the released piece")
	_touch(0, hit[0], false)
	_touch(1, hit[0] + Vector2(200, 0), false)
	check(not _is_held(piece), "nothing is held after all fingers lift")
	check(piece.position == dragged, "piece is still where it was after all fingers lift")


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
