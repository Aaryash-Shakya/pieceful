class_name BoardTest
extends BaseTest
## Shared setup and input helpers for tests that drive a real Board.

var board: Board
var camera: Camera2D
var pieces: Node2D
var viewport_size: Vector2
var bounds: Rect2


# Root only enters the tree once the main loop starts and Board._ready needs it,
# so the caller awaits process_frame first.
func make_board() -> void:
	board = load("res://src/game/board.tscn").instantiate()
	root.add_child(board)
	camera = board.camera
	pieces = board.pieces
	viewport_size = board.get_viewport_rect().size
	bounds = Rect2(Vector2.ZERO, Vector2(Board.IMAGE_SIZE)).grow(Board.LOOSE_MARGIN)


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
