extends "res://tests/base_test.gd"
## Shared setup and input helpers for tests that drive a real Board.

const TEST_SAVE_PATH := "user://test_save/current.json"

var board: Board
var camera: Camera2D
var pieces: Node2D
var viewport_size: Vector2
var bounds: Rect2


# Root only enters the tree once the main loop starts and Board._ready needs it,
# so the caller awaits process_frame first.
## A fresh board starts with no save; otherwise it resumes whatever is at TEST_SAVE_PATH.
func make_board(fresh := true) -> void:
	board = load("res://src/game/board.tscn").instantiate()
	# Board tests never read or write the player's real save.
	board.save_path = TEST_SAVE_PATH
	if fresh:
		SaveFile.remove(TEST_SAVE_PATH)
	root.add_child(board)
	# Real playback would leave the audio server holding streams when a headless test exits.
	var feedback := board.get_node("Feedback") as Feedback
	feedback.sound_enabled = false
	feedback.vibration_enabled = false
	camera = board.camera
	pieces = board.pieces
	viewport_size = board.get_viewport_rect().size
	bounds = Rect2(Vector2.ZERO, Vector2(Board.IMAGE_SIZE)).grow(Board.LOOSE_MARGIN)


func finish() -> void:
	SaveFile.remove(TEST_SAVE_PATH)
	DirAccess.remove_absolute(TEST_SAVE_PATH.get_base_dir())
	super()


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


# The board's own picking rule, so tests cannot drift from it.
func _top_piece_at(world: Vector2) -> PieceNode:
	return board.piece_at(world)


func _inside_points(node: PieceNode) -> PackedVector2Array:
	var outline := board.cut[node.piece_id].outline
	var triangles := Geometry2D.triangulate_polygon(outline)
	var points := PackedVector2Array()
	for t in range(0, triangles.size(), 3):
		points.append((outline[triangles[t]] + outline[triangles[t + 1]] + outline[triangles[t + 2]]) / 3.0)
	return points


func _grab_point(node: PieceNode) -> Vector2:
	for c in _inside_points(node):
		if _top_piece_at(c + node.position) == node:
			return _to_screen(c + node.position)
	return Vector2.INF


func _is_loose_singleton(piece: int) -> bool:
	return not board.state.is_locked(piece) and board.state.members(piece).size() == 1


func _loose_pair(used: PackedInt32Array) -> Vector2i:
	for p in board.state.piece_count():
		if used.has(p) or not _is_loose_singleton(p) or _grab_point(board.node_for(p)) == Vector2.INF:
			continue
		for q in board.cut[p].neighbours:
			if not used.has(q) and _is_loose_singleton(q):
				return Vector2i(p, q)
	check(false, "found a loose pair of neighbours")
	return Vector2i(0, 1)


func _move_by_touch(node: PieceNode, target: Vector2) -> void:
	var s := _grab_point(node)
	var relative := (target - node.position) * camera.zoom.x
	_touch(0, s, true)
	_drag(0, s + relative, relative)
	_touch(0, s + relative, false)
