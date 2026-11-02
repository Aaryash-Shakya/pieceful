class_name Board
extends Node2D
## The world: the board rectangle, the loose pieces around it and the camera.

const IMAGE_SIZE := Vector2i(1536, 1024)
const PIECE_COUNT := 400
const SEED := 1
const LOOSE_MARGIN := 768.0
const BORDER := 1.08
const BOARD_OUTLINE_WIDTH := 3.0
const EDGE_PAN_MARGIN := 48.0
const EDGE_PAN_SPEED := 600.0
const WHEEL_ZOOM_STEP := 1.1

# HOLD_PINCHING: the dragging finger keeps its piece while it and one other finger move the camera.
enum Mode { IDLE, DRAGGING, PANNING, PINCHING, HOLD_PINCHING, PINCH_ENDED }

var camera: Camera2D
var pieces: Node2D

var _bounds := Rect2(Vector2.ZERO, Vector2(IMAGE_SIZE)).grow(LOOSE_MARGIN)
var _mode := Mode.IDLE
var _touches: Dictionary[int, Vector2] = {}
var _held: PieceNode
var _drag_index := -1
var _held_offset := Vector2.ZERO
var _pinch_a := -1
var _pinch_b := -1
var _pinch_distance := 0.0
var _pinch_mid := Vector2.ZERO


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.felt())

	var texture := _make_test_texture()
	var cut := CutGenerator.generate_cut(IMAGE_SIZE.x, IMAGE_SIZE.y, PIECE_COUNT, CutGenerator.STYLE_GRID, SEED)
	var offsets := Scatter.scatter(cut, Vector2(IMAGE_SIZE), LOOSE_MARGIN, SEED)

	pieces = Node2D.new()
	pieces.name = "Pieces"
	add_child(pieces)
	for i in cut.size():
		var node := PieceNode.new()
		node.setup(cut[i], texture, Palette.outline())
		node.position = offsets[i]
		pieces.add_child(node)

	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	camera.position = Vector2(IMAGE_SIZE) / 2.0
	var fit := get_viewport_rect().size.x / (IMAGE_SIZE.x * BORDER)
	camera.zoom = Vector2(fit, fit)


func _process(delta: float) -> void:
	if _mode != Mode.DRAGGING:
		return
	var velocity := CameraRig.edge_pan_velocity(_touches[_drag_index], get_viewport_rect().size, EDGE_PAN_MARGIN, EDGE_PAN_SPEED)
	if velocity == Vector2.ZERO:
		return
	_set_camera_position(camera.position + velocity / camera.zoom.x * delta)
	_follow_held()


# Touch-up events can be lost while the app is in the background, so nothing may stay held.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_cancel_gesture()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton:
		_on_wheel(event)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.canceled:
		# The system took the gesture (a notification pulled down, say), so every finger is gone.
		_cancel_gesture()
		return

	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_begin_single(event.index, event.position)
		elif _mode == Mode.DRAGGING:
			_pair(_drag_index)
			_mode = Mode.HOLD_PINCHING
		elif _mode != Mode.PINCHING and _mode != Mode.HOLD_PINCHING:
			_begin_pinch(event.index)
		return

	if not _touches.erase(event.index):
		return
	if _touches.is_empty():
		_end_gesture()
	elif _mode == Mode.HOLD_PINCHING and event.index == _pinch_b:
		# The holding finger stays down, so it re-pairs or drags on alone from where the piece is.
		if _touches.size() >= 2:
			_pair(_drag_index)
		else:
			_mode = Mode.DRAGGING
	elif (_mode == Mode.PINCHING or _mode == Mode.HOLD_PINCHING) and (event.index == _pinch_a or event.index == _pinch_b):
		# In HOLD_PINCHING this is the holding finger lifting, so the piece drops where it is.
		_release_held()
		if _touches.size() >= 2:
			_begin_pinch(_touches.keys()[0])
		else:
			_mode = Mode.PINCH_ENDED


func _on_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	_touches[event.index] = event.position
	match _mode:
		Mode.DRAGGING:
			if event.index == _drag_index:
				_follow_held()
		Mode.PANNING:
			_set_camera_position(camera.position - event.relative / camera.zoom.x)
		Mode.PINCHING, Mode.HOLD_PINCHING:
			if event.index != _pinch_a and event.index != _pinch_b:
				return
			var a := _touches[_pinch_a]
			var b := _touches[_pinch_b]
			var distance := a.distance_to(b)
			var mid := (a + b) / 2.0
			# Pan first so the world follows the fingers, then zoom about where they are now.
			_set_camera_position(camera.position - (mid - _pinch_mid) / camera.zoom.x)
			if distance > 0.0 and _pinch_distance > 0.0:
				_zoom_about(camera.zoom.x * distance / _pinch_distance, mid)
			_pinch_distance = distance
			_pinch_mid = mid
			_follow_held()


func _on_wheel(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_about(camera.zoom.x * WHEEL_ZOOM_STEP, event.position)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_about(camera.zoom.x / WHEEL_ZOOM_STEP, event.position)
	# The mouse stands in for a finger on the desktop, so a piece held by it must follow the zoom.
	_follow_held()


func _begin_single(index: int, screen_position: Vector2) -> void:
	_release_held()
	var world := _to_world(screen_position)
	for i in range(pieces.get_child_count() - 1, -1, -1):
		var piece := pieces.get_child(i) as PieceNode
		if piece.contains_point(world):
			_held = piece
			_drag_index = index
			_held_offset = piece.position - world
			pieces.move_child(piece, -1)
			piece.set_held(true)
			_mode = Mode.DRAGGING
			return
	_mode = Mode.PANNING


# A camera pinch with nothing held: a piece still held is dropped where it is.
func _begin_pinch(index: int) -> void:
	_release_held()
	_pair(index)
	_mode = Mode.PINCHING


# Pairs the given finger with another one that is down, starting from where they are now so nothing jumps.
func _pair(index: int) -> void:
	_pinch_a = index
	for other in _touches:
		if other != index:
			_pinch_b = other
			break
	_pinch_distance = _touches[_pinch_a].distance_to(_touches[_pinch_b])
	_pinch_mid = (_touches[_pinch_a] + _touches[_pinch_b]) / 2.0


# The one way a held piece moves: it keeps the offset it had from the finger at grab time,
# so it stays under that finger through drags, pans and zooms alike.
func _follow_held() -> void:
	if _held != null:
		_held.position = _to_world(_touches[_drag_index]) + _held_offset


func _cancel_gesture() -> void:
	_touches.clear()
	_end_gesture()


func _end_gesture() -> void:
	_release_held()
	_mode = Mode.IDLE


func _release_held() -> void:
	if _held != null:
		_held.set_held(false)
		_held = null
	_drag_index = -1


func _zoom_about(zoom: float, screen_anchor: Vector2) -> void:
	var new_zoom := CameraRig.clamp_zoom(zoom)
	var anchor_offset := screen_anchor - get_viewport_rect().size / 2.0
	camera.position = CameraRig.zoom_about(camera.position, camera.zoom.x, new_zoom, anchor_offset)
	camera.zoom = Vector2(new_zoom, new_zoom)
	_set_camera_position(camera.position)


func _set_camera_position(target: Vector2) -> void:
	camera.position = CameraRig.clamp_position(target, _bounds)


func _to_world(screen_position: Vector2) -> Vector2:
	return camera.position + (screen_position - get_viewport_rect().size / 2.0) / camera.zoom.x


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(IMAGE_SIZE))
	draw_rect(rect, Palette.board())
	draw_rect(rect, Palette.accent(), false, BOARD_OUTLINE_WIDTH)


func _make_test_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	gradient.colors = PackedColorArray([
		Color.RED, Color.YELLOW, Color.GREEN, Color.CYAN, Color.BLUE, Color.MAGENTA,
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = IMAGE_SIZE.x
	texture.height = IMAGE_SIZE.y
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 1)
	return texture
