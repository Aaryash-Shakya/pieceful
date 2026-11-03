class_name Board
extends Node2D
## The world: the board rectangle, the loose pieces around it and the camera.

const IMAGE_ID := "test-gradient"
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
const CLEANUP_DURATION := 0.4
# A hitch or a frame the system held back counts no more than this toward the clock.
const ELAPSED_STEP_LIMIT := 0.25

# HOLD_PINCHING: the dragging finger keeps its piece while it and one other finger move the camera.
enum Mode { IDLE, DRAGGING, PANNING, PINCHING, HOLD_PINCHING, PINCH_ENDED }

signal cluster_lifted(cluster_root: int, piece_count: int)
# locked: the same drop also locked the joined cluster, so cluster_locked follows.
signal pieces_joined(cluster_root: int, piece_count: int, locked: bool)
signal cluster_locked(cluster_root: int, piece_count: int)
signal puzzle_completed


# One cluster's glide during a tidy. Its members share one offset, so they share one path.
class TidyMove:
	var nodes: Array[PieceNode] = []
	var from: Vector2
	var to: Vector2

## Set before the board enters the tree.
var save_path := SaveFile.DEFAULT_PATH
var puzzle: SaveGame.Puzzle
## Seconds of play, counted only while the app has focus and the puzzle is unfinished.
var elapsed := 0.0
var camera: Camera2D
var cut: Array[CutPiece]
var state: PuzzleState
var locked_pieces: Node2D
var pieces: Node2D
# True only while the system forces a drop (focus loss, pause, close, back). The signals still fire, but feedback stays silent.
var releasing_for_system := false

# Both are set from the puzzle's image size in _apply_image_size.
var _base_bounds: Rect2
var _bounds: Rect2
var _texture: GradientTexture2D
# Each tidy deals a new order, so pressing it again reshuffles.
var _cleanup_count := 0
var _tidy_tween: Tween
var _tidy_moves: Array[TidyMove] = []
var _mode := Mode.IDLE
var _touches: Dictionary[int, Vector2] = {}
var _nodes: Array[PieceNode] = []
# Outline bounds at home, by piece id, so a tidy never walks the outlines.
var _piece_bounds: Array[Rect2] = []
var _held_root := -1
var _held_nodes: Array[PieceNode] = []
var _drag_index := -1
var _held_offset := Vector2.ZERO
var _pinch_a := -1
var _pinch_b := -1
var _pinch_distance := 0.0
var _pinch_mid := Vector2.ZERO
var _focused := true


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.felt())

	var loose_order := _restore()
	if state == null:
		loose_order = _start_fresh()

	_texture = _make_test_texture()
	# Added first so locked pieces draw below every loose one.
	locked_pieces = Node2D.new()
	locked_pieces.name = "LockedPieces"
	add_child(locked_pieces)
	pieces = Node2D.new()
	pieces.name = "Pieces"
	add_child(pieces)
	for i in cut.size():
		var node := PieceNode.new()
		node.setup(cut[i], _texture, Palette.outline())
		node.position = state.offset_of(i)
		_nodes.append(node)
		_piece_bounds.append(cut[i].bounds())
		if state.is_locked(i):
			locked_pieces.add_child(node)
	for id in loose_order:
		pieces.add_child(_nodes[id])

	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	_apply_image_size()


# Loads the save into puzzle, cut and state and returns its loose draw order. With no save, or
# one that fails a check, state stays null and the board starts fresh. Restoring emits no signal.
func _restore() -> PackedInt32Array:
	if not FileAccess.file_exists(save_path):
		return PackedInt32Array()
	var loaded := SaveGame.from_json(SaveFile.read(save_path))
	if loaded.snapshot == null:
		_discard_save(loaded.error)
		return PackedInt32Array()
	var saved := loaded.snapshot
	var p := saved.puzzle
	# Until real images arrive, the board can draw only its test image at its one size.
	if p.image_id != IMAGE_ID or p.image_size != IMAGE_SIZE:
		_discard_save("unknown image %s at %dx%d" % [p.image_id, p.image_size.x, p.image_size.y])
		return PackedInt32Array()
	var saved_cut := CutGenerator.generate_cut(p.image_size.x, p.image_size.y, p.piece_count, p.style, p.cut_seed)
	var tolerance := PuzzleState.tolerance_for(p.image_size.x, p.image_size.y, saved_cut.size())
	var saved_state := SaveGame.state_from(saved.clusters, saved_cut, tolerance)
	# A broken partition gives the empty state, which counts as complete; a finished puzzle never has a save.
	if saved_state.is_complete():
		_discard_save("the clusters do not fit the cut or the puzzle is complete")
		return PackedInt32Array()
	if not SaveGame.loose_order_valid(saved.loose_order, saved_state):
		_discard_save("the draw order does not list every loose piece once")
		return PackedInt32Array()
	puzzle = p
	cut = saved_cut
	state = saved_state
	elapsed = saved.elapsed
	_cleanup_count = saved.tidy_count
	return saved.loose_order


func _discard_save(reason: String) -> void:
	push_warning("Board: discarding the save at %s: %s" % [save_path, reason])
	SaveFile.remove(save_path)


# A new puzzle from the constants, scattered around the board. Returns its draw order: by id.
func _start_fresh() -> PackedInt32Array:
	puzzle = SaveGame.Puzzle.new()
	puzzle.image_id = IMAGE_ID
	puzzle.image_size = IMAGE_SIZE
	puzzle.style = STYLE
	puzzle.piece_count = PIECE_COUNT
	puzzle.cut_seed = SEED
	var size := puzzle.image_size
	cut = CutGenerator.generate_cut(size.x, size.y, puzzle.piece_count, puzzle.style, puzzle.cut_seed)
	var offsets := Scatter.scatter(cut, Vector2(size), LOOSE_MARGIN, puzzle.cut_seed)
	state = PuzzleState.new(cut, offsets, PuzzleState.tolerance_for(size.x, size.y, cut.size()))
	var order := PackedInt32Array()
	for i in cut.size():
		order.append(i)
	return order


# Everything sized from the image follows the puzzle, not the constants. The camera bounds take in
# every loose cluster, so a tidied band from a restored save stays reachable.
func _apply_image_size() -> void:
	var size := Vector2(puzzle.image_size)
	_texture.width = puzzle.image_size.x
	_texture.height = puzzle.image_size.y
	_base_bounds = Rect2(Vector2.ZERO, size).grow(LOOSE_MARGIN)
	_bounds = _base_bounds
	for root in state.roots():
		if not state.is_locked(root):
			var rect := cluster_home_rect(root)
			_bounds = _bounds.merge(Rect2(rect.position + state.offset_of(root), rect.size))
	camera.position = size / 2.0
	var fit := get_viewport_rect().size.x / (size.x * BORDER)
	camera.zoom = Vector2(fit, fit)
	queue_redraw()


func node_for(piece_id: int) -> PieceNode:
	return _nodes[piece_id]


## The topmost loose piece containing the world point, or null. Locked pieces are never picked.
## A running tidy lands first, so the pick sees each piece where the state says it is.
func piece_at(world: Vector2) -> PieceNode:
	_finish_cleanup()
	for i in range(pieces.get_child_count() - 1, -1, -1):
		var piece := pieces.get_child(i) as PieceNode
		if piece.contains_point(world):
			return piece
	return null


## Deals every loose cluster into the bands above and below the board. The state takes the
## new offsets at once; only the nodes animate, and anything that needs them exact lands them first.
func cleanup() -> void:
	_finish_cleanup()
	if _held_root != -1:
		return
	var roots := PackedInt32Array()
	for root in state.roots():
		if not state.is_locked(root):
			roots.append(root)
	if roots.is_empty():
		return
	var rects: Array[Rect2] = []
	for root in roots:
		rects.append(cluster_home_rect(root))
	var size := Vector2(puzzle.image_size)
	var cell := sqrt(size.x * size.y / cut.size())
	var result := CleanupLayout.layout(rects, size, cell, puzzle.cut_seed, _cleanup_count, state.tolerance)
	_cleanup_count += 1
	for k in roots.size():
		var move := TidyMove.new()
		for id in state.members(roots[k]):
			move.nodes.append(_nodes[id])
		move.from = move.nodes[0].position
		move.to = result.offsets[k]
		_tidy_moves.append(move)
		state.move_cluster(roots[k], move.to)
	_bounds = _base_bounds.merge(result.extent)
	_set_camera_position(camera.position)

	_tidy_tween = create_tween()
	_tidy_tween.tween_method(_step_cleanup, 0.0, 1.0, CLEANUP_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tidy_tween.finished.connect(_finish_cleanup)


func is_tidying() -> bool:
	return _tidy_tween != null and _tidy_tween.is_running()


## The union of the cluster's pieces' outline bounds at home (offset zero).
func cluster_home_rect(root: int) -> Rect2:
	var members := state.members(root)
	var rect := _piece_bounds[members[0]]
	for id in members:
		rect = rect.merge(_piece_bounds[id])
	return rect


func _step_cleanup(t: float) -> void:
	for move in _tidy_moves:
		var at := move.from.lerp(move.to, t)
		for node in move.nodes:
			node.position = at


# The last eased step need not land exactly on the target, so every node is set from the state.
func _finish_cleanup() -> void:
	if _tidy_tween == null:
		return
	_tidy_tween.kill()
	_tidy_tween = null
	for move in _tidy_moves:
		for node in move.nodes:
			node.position = state.offset_of(node.piece_id)
	_tidy_moves.clear()


## Reads the state, never the nodes, so a save during a tidy holds where the tidy lands.
func snapshot() -> SaveGame.Snapshot:
	var s := SaveGame.Snapshot.new()
	s.puzzle = puzzle
	s.clusters = SaveGame.clusters_of(state)
	for child in pieces.get_children():
		s.loose_order.append((child as PieceNode).piece_id)
	s.elapsed = elapsed
	s.tidy_count = _cleanup_count
	return s


## Writes the game, or deletes the save once the puzzle is complete. False when nothing could be saved.
func save_game() -> bool:
	if state == null:
		return false
	if state.is_complete():
		SaveFile.remove(save_path)
		return true
	var err := SaveFile.write_atomic(save_path, SaveGame.to_json(snapshot()))
	if err != OK:
		push_warning("Board: could not save to %s (error %d)" % [save_path, err])
		return false
	return true


func _process(delta: float) -> void:
	if _focused and not state.is_complete():
		elapsed += minf(delta, ELAPSED_STEP_LIMIT)
	if _mode != Mode.DRAGGING:
		return
	var velocity := CameraRig.edge_pan_velocity(_touches[_drag_index], get_viewport_rect().size, EDGE_PAN_MARGIN, EDGE_PAN_SPEED)
	if velocity == Vector2.ZERO:
		return
	_set_camera_position(camera.position + velocity / camera.zoom.x * delta)


func _notification(what: int) -> void:
	match what:
		# Not on RESUMED: Android can resume the app behind the lock screen or in multi-window without focus.
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_focused = false
			_leave()
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			_leave()


# Touch-up events can be lost while the app is in the background, so nothing may stay held.
# The drop comes before the save, so the save holds where the piece landed.
func _leave() -> void:
	_finish_cleanup()
	releasing_for_system = true
	_cancel_gesture()
	releasing_for_system = false
	save_game()


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
	cluster_lifted.emit(_held_root, _held_nodes.size())


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
		pieces_joined.emit(result.root, nodes.size(), result.locked)
	if result.locked:
		cluster_locked.emit(result.root, nodes.size())
	if result.locked and state.is_complete():
		puzzle_completed.emit()
	if result.locked:
		save_game()


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


func _board_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(puzzle.image_size))


func _draw() -> void:
	var rect := _board_rect()
	draw_rect(rect, Palette.board())
	draw_rect(rect, Palette.accent(), false, BOARD_OUTLINE_WIDTH)


# Sized by _apply_image_size, so it always matches the puzzle's image.
func _make_test_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	gradient.colors = PackedColorArray([
		Color.RED, Color.YELLOW, Color.GREEN, Color.CYAN, Color.BLUE, Color.MAGENTA,
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 1)
	return texture
