class_name Board
extends Node2D
## The world: the board rectangle, the loose pieces around it and the camera.

const IMAGE_SIZE := Vector2i(1536, 1024)
const PIECE_COUNT := 400
const SEED := 1
const STYLE := CutGenerator.STYLE_REGULAR
const LOOSE_MARGIN := 768.0
const BORDER := 1.08
const BOARD_OUTLINE_WIDTH := 3.0
const EDGE_PAN_MARGIN := 48.0
const EDGE_PAN_SPEED := 600.0
const WHEEL_ZOOM_STEP := 1.1

# HOLD_PINCHING: the dragging finger keeps its piece while it and one other finger move the camera.
enum Mode { IDLE, DRAGGING, PANNING, PINCHING, HOLD_PINCHING, PINCH_ENDED }

signal pieces_joined(cluster_root: int, piece_count: int)
signal cluster_locked(cluster_root: int, piece_count: int)
signal puzzle_completed

var camera: Camera2D
var cut: Array[CutPiece]
var state: PuzzleState
var locked_pieces: Node2D
var pieces: Node2D

var _bounds := Rect2(Vector2.ZERO, Vector2(IMAGE_SIZE)).grow(LOOSE_MARGIN)
var _mode := Mode.IDLE
var _touches: Dictionary[int, Vector2] = {}
var _nodes: Array[PieceNode] = []
var _held_root := -1
var _held_nodes: Array[PieceNode] = []
var _drag_index := -1
var _held_offset := Vector2.ZERO
var _pinch_a := -1
var _pinch_b := -1
var _pinch_distance := 0.0
var _pinch_mid := Vector2.ZERO


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.felt())

	var texture := _make_test_texture()
	cut = CutGenerator.generate_cut(IMAGE_SIZE.x, IMAGE_SIZE.y, PIECE_COUNT, STYLE, SEED)
	var offsets := Scatter.scatter(cut, Vector2(IMAGE_SIZE), LOOSE_MARGIN, SEED)
	state = PuzzleState.new(cut, offsets, PuzzleState.tolerance_for(IMAGE_SIZE.x, IMAGE_SIZE.y, cut.size()))

	# Added first so locked pieces draw below every loose one.
	locked_pieces = Node2D.new()
	locked_pieces.name = "LockedPieces"
	add_child(locked_pieces)
	pieces = Node2D.new()
	pieces.name = "Pieces"
	add_child(pieces)
	for i in cut.size():
		var node := PieceNode.new()
		node.setup(cut[i], texture, Palette.outline())
		node.position = offsets[i]
		pieces.add_child(node)
		_nodes.append(node)

	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	camera.position = Vector2(IMAGE_SIZE) / 2.0
	var fit := get_viewport_rect().size.x / (IMAGE_SIZE.x * BORDER)
	camera.zoom = Vector2(fit, fit)


func node_for(piece_id: int) -> PieceNode:
	return _nodes[piece_id]


## The topmost loose piece containing the world point, or null. Locked pieces are never picked.
func piece_at(world: Vector2) -> PieceNode:
	for i in range(pieces.get_child_count() - 1, -1, -1):
		var piece := pieces.get_child(i) as PieceNode
		if piece.contains_point(world):
			return piece
	return null


func _process(delta: float) -> void:
	if _mode != Mode.DRAGGING:
		return
	var velocity := CameraRig.edge_pan_velocity(_touches[_drag_index], get_viewport_rect().size, EDGE_PAN_MARGIN, EDGE_PAN_SPEED)
	if velocity == Vector2.ZERO:
		return
	_set_camera_position(camera.position + velocity / camera.zoom.x * delta)


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
		elif _mode == Mode.PINCHING or _mode == Mode.HOLD_PINCHING:
			# A third finger, or a paired finger pressed again after a lost release: restart from where the pair is now.
			_refresh_pinch()
		else:
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
		Mode.PINCHING:
			if event.index == _pinch_a or event.index == _pinch_b:
				_pinch_step()
		Mode.HOLD_PINCHING:
			if event.index == _drag_index:
				# Only the second finger moves the view, so the holding finger can place its piece precisely.
				_follow_held()
				_refresh_pinch()
			elif event.index == _pinch_b:
				_pinch_step()


func _on_wheel(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_about(camera.zoom.x * WHEEL_ZOOM_STEP, event.position)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_about(camera.zoom.x / WHEEL_ZOOM_STEP, event.position)


func _pinch_step() -> void:
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


func _begin_single(index: int, screen_position: Vector2) -> void:
	_release_held()
	var world := _to_world(screen_position)
	var piece := piece_at(world)
	if piece == null:
		_mode = Mode.PANNING
		return
	_held_root = state.find(piece.piece_id)
	for id in state.members(_held_root):
		_held_nodes.append(_nodes[id])
	_raise(_held_nodes)
	for node in _held_nodes:
		node.set_held(true)
	_drag_index = index
	_held_offset = state.offset_of(_held_root) - world
	_mode = Mode.DRAGGING


func _begin_pinch(index: int) -> void:
	_pair(index)
	_mode = Mode.PINCHING


# Pairs the given finger with another one that is down.
func _pair(index: int) -> void:
	_pinch_a = index
	for other in _touches:
		if other != index:
			_pinch_b = other
			break
	_refresh_pinch()


# Restarts the pinch from where the paired fingers are now, so the next step does not jump.
func _refresh_pinch() -> void:
	_pinch_distance = _touches[_pinch_a].distance_to(_touches[_pinch_b])
	_pinch_mid = (_touches[_pinch_a] + _touches[_pinch_b]) / 2.0


# The one way a held cluster moves: it keeps the offset it had from the finger at grab time,
# so it stays under that finger through drags, pans and zooms alike. Every camera move
# goes through _set_camera_position, which calls this.
func _follow_held() -> void:
	if _held_root == -1:
		return
	var offset := _to_world(_touches[_drag_index]) + _held_offset
	state.move_cluster(_held_root, offset)
	for node in _held_nodes:
		node.position = offset


func _cancel_gesture() -> void:
	_touches.clear()
	_end_gesture()


func _end_gesture() -> void:
	_release_held()
	_mode = Mode.IDLE


# Every release is a drop, however the finger went away, so the cluster always settles.
func _release_held() -> void:
	_drag_index = -1
	if _held_root == -1:
		return
	for node in _held_nodes:
		node.set_held(false)
	var result := state.drop(_held_root)
	_held_root = -1
	_held_nodes.clear()
	_settle(result)


func _settle(result: PuzzleState.DropResult) -> void:
	# A plain drop changes nothing: the held nodes already sit at the cluster offset.
	if not result.joined and not result.locked:
		return
	var offset := state.offset_of(result.root)
	var nodes: Array[PieceNode] = []
	for id in state.members(result.root):
		var node := _nodes[id]
		node.position = offset
		nodes.append(node)
	if result.locked:
		# Last child first, so no removal shifts the siblings still to go.
		nodes.sort_custom(func(a: PieceNode, b: PieceNode) -> bool: return a.get_index() > b.get_index())
		for node in nodes:
			node.reparent(locked_pieces, false)
	elif result.joined:
		_raise(nodes)
	if result.joined:
		pieces_joined.emit(result.root, nodes.size())
	if result.locked:
		cluster_locked.emit(result.root, nodes.size())
	if result.locked and state.is_complete():
		puzzle_completed.emit()


# Moves the nodes to the top of the loose layer, keeping their order among themselves.
func _raise(nodes: Array[PieceNode]) -> void:
	# Held shadows draw over other loose pieces only because the held nodes end up last in tree order before set_held raises their z_index.
	nodes.sort_custom(func(a: PieceNode, b: PieceNode) -> bool: return a.get_index() < b.get_index())
	# Members already at the tail in order stay put, and the rest slot in just before them,
	# so re-lifting the cluster just dropped moves nothing.
	var slot := pieces.get_child_count() - 1
	var placed := nodes.size()
	while placed > 0 and nodes[placed - 1].get_index() == slot:
		placed -= 1
		slot -= 1
	for k in placed:
		pieces.move_child(nodes[k], slot)


func _zoom_about(zoom: float, screen_anchor: Vector2) -> void:
	var new_zoom := CameraRig.clamp_zoom(zoom)
	var anchor_offset := screen_anchor - get_viewport_rect().size / 2.0
	camera.position = CameraRig.zoom_about(camera.position, camera.zoom.x, new_zoom, anchor_offset)
	camera.zoom = Vector2(new_zoom, new_zoom)
	_set_camera_position(camera.position)


func _set_camera_position(target: Vector2) -> void:
	camera.position = CameraRig.clamp_position(target, _bounds)
	_follow_held()


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
