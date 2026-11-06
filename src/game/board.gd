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
# A restored loose offset beyond this many longest image sides is damage, not play.
const FAR_OFFSET_FACTOR := 8
# A stack released this close to its own slot, in screen units, goes back into it.
const NEAR_SLOT_MARGIN := 48.0
const GHOST_OPACITY := 0.2
# Drags are noted at most this often, so the trace keeps the presses and releases around them.
const DRAG_TRACE_INTERVAL := 0.3
# Above the HUD (10) and below the frame counter (100).
const HELD_LAYER := 11

# HOLD_PINCHING: the dragging finger keeps its piece while it and one other finger move the camera.
# SLOT_DRAGGING: a whole slot's stack is fanned out under one finger; other fingers are ignored.
enum Mode { IDLE, DRAGGING, PANNING, PINCHING, HOLD_PINCHING, PINCH_ENDED, SLOT_DRAGGING }

signal cluster_lifted(cluster_root: int, piece_count: int)
# locked: the same drop also locked the joined cluster, so cluster_locked follows.
signal pieces_joined(cluster_root: int, piece_count: int, locked: bool)
signal cluster_locked(cluster_root: int, piece_count: int)
signal puzzle_completed
## What a slot holds changed (a stack went in or out, or the board just started).
signal slots_changed
## A cluster or a whole stack went into a slot, with this many pieces. Not emitted for a system release.
signal stashed(piece_count: int)
## The slot that releasing the held pieces now would put them in, or -1 for none.
signal slot_hover_changed(slot: int)
signal ghost_changed(on: bool)
## The player asked to leave the board, by Home or back. The game is already saved.
signal home_requested


# One cluster's glide during a tidy. Its members share one offset, so they share one path.
class TidyMove:
	var nodes: Array[PieceNode] = []
	var from: Vector2
	var to: Vector2

## Set before the board enters the tree.
var save_path := SaveFile.DEFAULT_PATH
## Where puzzle pictures come from. Without it only the test picture can be drawn.
var collection: Collection = null
## The puzzle to start when there is no save to resume, or resume is off.
var start_puzzle: SaveGame.Puzzle = null
## Off when the player chose a new puzzle: the save is ignored, and the new game replaces it.
var resume := true
var puzzle: SaveGame.Puzzle
## Seconds of play, counted only while the app has focus and the puzzle is unfinished.
var elapsed := 0.0
var camera: Camera2D
var cut: Array[CutPiece]
var state: PuzzleState
var locked_pieces: Node2D
var pieces: Node2D
## The whole picture at low opacity over the board, under the pieces.
var ghost_sprite: Sprite2D
## Where the pieces under a finger live while held, above the HUD.
var held_layer: CanvasLayer
## Holds the nodes of pieces that sit in a slot. Hidden, and never searched by piece_at.
var stash: Node2D
## The four slots' screen rectangles, set by the HUD's tray. The board hit-tests them from raw touches.
var slot_rects: Array[Rect2] = []
# True only while the system forces a drop (focus loss, pause, close, back). The signals still fire, but feedback stays silent.
var releasing_for_system := false

# Both are set from the puzzle's image size in _apply_image_size.
var _base_bounds: Rect2
var _bounds: Rect2
var _texture: Texture2D
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
# Where the dragging finger is on screen, kept so a drop over a slot still knows it after the touch is gone.
var _held_screen := Vector2.ZERO
# The stack taken out of a slot: cluster roots, the slot it came from, and their home rectangles.
var _slot_held := PackedInt32Array()
var _slot_held_from := -1
var _hover_slot := -1
var _slot_held_rects: Array[Rect2] = []
var _pinch_a := -1
var _pinch_b := -1
var _pinch_distance := 0.0
var _pinch_mid := Vector2.ZERO
var _focused := false
# The text of the last successful write, so a second leave in one trip writes nothing.
var _last_saved_text := ""
# Successful writes, so tests can tell a skipped write from a repeated one.
var _save_writes := 0
# Set when the caller's puzzle could not start and the test puzzle stands in for it.
var _saving_disabled := false
var _going_home := false
## The last touch events with the board's mode beside each, so a stuck gesture can be read back
## from a phone. Saved to trace_path when a finger goes silent while another one is moving.
var trace := GestureTrace.new()
var trace_path := "user://gesture_trace.txt"
# When each finger that is down last sent anything, in seconds, by finger index.
var _last_seen := {}
var _stale_noted := PackedInt32Array()
var _last_drag_note := -1.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.felt())
	# The app can start behind the lock screen; the clock waits for real focus.
	_focused = get_window().has_focus()

	var loose_order := _restore() if resume else PackedInt32Array()
	var from_caller := false
	if state == null:
		var texture: Texture2D = null
		if start_puzzle != null:
			var p := start_puzzle
			if CutGenerator.STYLES.has(p.style) and p.piece_count >= 1 and p.piece_count <= SaveGame.MAX_PIECE_COUNT:
				texture = picture_texture(p.image_id, p.image_size)
			if texture == null:
				push_warning("Board: could not start %s; starting the test puzzle" % p.image_id)
				# The player's save is still on disk; this stand-in game must never overwrite it.
				_saving_disabled = true
		from_caller = texture != null
		if from_caller:
			loose_order = _start_fresh(start_puzzle)
			_texture = texture
		else:
			loose_order = _start_fresh(null)
			_texture = _make_test_texture()

	# The faint picture goes in first, so it draws under every piece, locked or loose.
	ghost_sprite = Sprite2D.new()
	ghost_sprite.name = "Ghost"
	ghost_sprite.texture = _texture
	ghost_sprite.centered = false
	ghost_sprite.modulate.a = GHOST_OPACITY
	ghost_sprite.visible = puzzle.ghost and not state.is_complete()
	add_child(ghost_sprite)
	# Added first so locked pieces draw below every loose one.
	locked_pieces = Node2D.new()
	locked_pieces.name = "LockedPieces"
	add_child(locked_pieces)
	pieces = Node2D.new()
	pieces.name = "Pieces"
	add_child(pieces)
	# Held pieces ride a layer above the HUD, so a lifted piece is drawn over the slot tray. Following the
	# viewport keeps that layer in world space, under the camera.
	held_layer = CanvasLayer.new()
	held_layer.name = "HeldLayer"
	held_layer.layer = HELD_LAYER
	held_layer.follow_viewport_enabled = true
	add_child(held_layer)
	stash = Node2D.new()
	stash.name = "Stash"
	stash.visible = false
	add_child(stash)
	for i in cut.size():
		var node := PieceNode.new()
		node.setup(cut[i], _texture, Palette.outline())
		node.position = state.offset_of(i)
		_nodes.append(node)
		_piece_bounds.append(cut[i].bounds())
		if state.is_locked(i):
			locked_pieces.add_child(node)
		elif state.slot_of(i) != -1:
			stash.add_child(node)
	for id in loose_order:
		pieces.add_child(_nodes[id])

	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	_apply_image_size()
	if OS.is_debug_build():
		var overlay := GestureOverlay.new()
		overlay.name = "GestureOverlay"
		overlay.board = self
		add_child(overlay)
	# A chosen puzzle is the player's game from its first frame, so it replaces any older save now.
	if from_caller:
		save_game()
	slots_changed.emit()


# Loads the save into puzzle, cut and state and returns its loose draw order. With no save, or
# one that fails a check, state stays null and the board starts fresh. Restoring emits no signal.
func _restore() -> PackedInt32Array:
	var file := SaveFile.read(save_path)
	if file.error == ERR_FILE_NOT_FOUND:
		return PackedInt32Array()
	if file.error != OK:
		_set_save_aside("it could not be read (error %d)" % file.error)
		return PackedInt32Array()
	var loaded := SaveGame.from_json(file.text)
	if loaded.snapshot == null:
		_set_save_aside(loaded.error)
		return PackedInt32Array()
	var saved := loaded.snapshot
	var p := saved.puzzle
	# Only whether the picture exists here: loading a full picture waits until every cheaper check passes.
	if not has_picture(p.image_id, p.image_size):
		_set_save_aside("unknown image %s at %dx%d" % [p.image_id, p.image_size.x, p.image_size.y])
		return PackedInt32Array()
	var saved_cut := CutGenerator.generate_cut(p.image_size.x, p.image_size.y, p.piece_count, p.style, p.cut_seed)
	if CutGenerator.checksum(saved_cut) != p.cut_checksum:
		_set_save_aside("the cut no longer matches the one it was saved with")
		return PackedInt32Array()
	var tolerance := PuzzleState.tolerance_for(p.image_size.x, p.image_size.y, saved_cut.size())
	var saved_state := SaveGame.state_from(saved.clusters, saved_cut, tolerance, saved.slots)
	# A broken partition gives the empty state, which counts as complete; a finished puzzle never has a save.
	if saved_state.is_complete():
		_set_save_aside("the clusters do not fit the cut or the puzzle is complete")
		return PackedInt32Array()
	# A damaged offset far out would stretch the camera bounds and strand the piece out of reach.
	var reach := FAR_OFFSET_FACTOR * maxi(p.image_size.x, p.image_size.y)
	for root in saved_state.roots():
		if not saved_state.is_locked(root) and saved_state.slot_of(root) == -1 \
				and saved_state.offset_of(root).length() > reach:
			_set_save_aside("cluster %d lies too far from the board" % root)
			return PackedInt32Array()
	if not SaveGame.loose_order_valid(saved.loose_order, saved_state):
		_set_save_aside("the draw order does not list every loose piece once")
		return PackedInt32Array()
	var texture := picture_texture(p.image_id, p.image_size)
	if texture == null:
		_set_save_aside("could not load image %s" % p.image_id)
		return PackedInt32Array()
	puzzle = p
	cut = saved_cut
	state = saved_state
	elapsed = saved.elapsed
	_cleanup_count = saved.tidy_count
	_texture = texture
	# The file already holds this game, so leaving again before anything changes writes nothing.
	_last_saved_text = file.text
	return saved.loose_order


# A save the game cannot use may still be wanted (a newer version wrote it, or the read failed
# only this once), so it is kept beside the save path instead of deleted.
func _set_save_aside(reason: String) -> void:
	var error := SaveFile.move_aside(save_path)
	var outcome := "moved it to %s" % SaveFile.bad_path(save_path) if error == OK \
			else "could not move it aside (error %d)" % error
	push_warning("Board: could not use the save at %s: %s; %s" % [save_path, reason, outcome])


# A new puzzle from the given identity, or from the constants when it is null, scattered around
# the board. Returns its draw order: by id.
func _start_fresh(from: SaveGame.Puzzle) -> PackedInt32Array:
	# A copy, so the caller's puzzle never takes this board's checksum.
	if from != null:
		puzzle = from.copy()
	else:
		puzzle = SaveGame.Puzzle.new()
		puzzle.image_id = IMAGE_ID
		puzzle.image_size = IMAGE_SIZE
		puzzle.style = STYLE
		puzzle.piece_count = PIECE_COUNT
		puzzle.cut_seed = SEED
	var size := puzzle.image_size
	cut = CutGenerator.generate_cut(size.x, size.y, puzzle.piece_count, puzzle.style, puzzle.cut_seed)
	puzzle.cut_checksum = CutGenerator.checksum(cut)
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
	# Only the generated test picture can be resized; a collection picture already has its size.
	if _texture is GradientTexture2D:
		var gradient := _texture as GradientTexture2D
		gradient.width = puzzle.image_size.x
		gradient.height = puzzle.image_size.y
	_base_bounds = Rect2(Vector2.ZERO, size).grow(LOOSE_MARGIN)
	_bounds = _base_bounds
	for root in state.roots():
		if not state.is_locked(root) and state.slot_of(root) == -1:
			var rect := cluster_home_rect(root)
			_bounds = _bounds.merge(Rect2(rect.position + state.offset_of(root), rect.size))
	camera.position = size / 2.0
	var fit := get_viewport_rect().size.x / (size.x * BORDER)
	camera.zoom = Vector2(fit, fit)
	queue_redraw()


## Shows or hides the ghost picture. The choice is part of the puzzle, so it is saved and goes on the result card.
func set_ghost(on: bool) -> void:
	if puzzle.ghost == on:
		return
	puzzle.ghost = on
	ghost_sprite.visible = on and not state.is_complete()
	ghost_changed.emit(on)
	save_game()


## The picture's name for the completion screen.
func picture_title() -> String:
	if puzzle.image_id == IMAGE_ID:
		return "Test picture"
	var picture := collection.find(puzzle.image_id) if collection != null else null
	return picture.title if picture != null else puzzle.image_id


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
		if not state.is_locked(root) and state.slot_of(root) == -1:
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
	# A piece held right now is still a loose piece, drawn last.
	for child in pieces.get_children() + held_layer.get_children():
		s.loose_order.append((child as PieceNode).piece_id)
	s.slots = SaveGame.slots_of(state)
	s.elapsed = elapsed
	s.tidy_count = _cleanup_count
	return s


## Writes the game, or deletes the save once the puzzle is complete. False when nothing could be saved.
func save_game() -> bool:
	if state == null or _saving_disabled:
		return false
	if state.is_complete():
		SaveFile.remove(save_path)
		_last_saved_text = ""
		return true
	var text := SaveGame.to_json(snapshot())
	# One trip to the background sends several notifications; only the first needs the write.
	if text == _last_saved_text and FileAccess.file_exists(save_path):
		return true
	var err := SaveFile.write_atomic(save_path, text)
	if err != OK:
		push_warning("Board: could not save to %s (error %d)" % [save_path, err])
		return false
	_last_saved_text = text
	_save_writes += 1
	return true


func _process(delta: float) -> void:
	if _focused and not state.is_complete():
		elapsed += minf(delta, ELAPSED_STEP_LIMIT)
	_check_stale_fingers()
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
		NOTIFICATION_WM_CLOSE_REQUEST:
			_leave()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_home()


## Saves and asks to leave. Only the first call in a frame counts: a double tap or a back press
## while the caller is already switching screens must not save or leave twice.
func go_home() -> void:
	if _going_home:
		return
	_going_home = true
	_leave()
	home_requested.emit()
	_release_home.call_deferred()


# A board nobody swapped away (no listener, or the swap failed) must answer Home and back again.
# A board the swap took out of the tree stays latched until it is freed.
func _release_home() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		_going_home = false


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


## The overlay text: the mode, how long each finger has been silent, and the held and locked counts.
func gesture_report() -> String:
	return GestureTrace.report(Mode.keys()[_mode], _last_seen, _now(), _held_nodes.size(), state.locked_piece_count())


## True while a finger has been noted as silent beside a moving one.
func has_stale_finger() -> bool:
	return not _stale_noted.is_empty()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# A finger silent for seconds beside a moving one may have lost its release, and the board would then
# read every new touch as a second finger. Noted once, and the trace is saved while it is fresh.
func _check_stale_fingers() -> void:
	if _last_seen.size() < 2:
		_stale_noted.clear()
		return
	var stale := GestureTrace.stale_fingers(_last_seen, _now())
	if stale == _stale_noted:
		return
	_stale_noted = stale
	if stale.is_empty():
		return
	var names: PackedStringArray = []
	for index in stale:
		names.append("#%d" % index)
	trace.record(_now(), "STALE %s silent while another finger moves, mode %s" % [" ".join(names), Mode.keys()[_mode]])
	trace.save_to(trace_path)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.canceled:
		_last_seen.clear()
	elif event.pressed:
		_last_seen[event.index] = _now()
	else:
		_last_seen.erase(event.index)
	_handle_touch(event)
	var kind := "cancel" if event.canceled else ("press" if event.pressed else "release")
	trace.record(_now(), GestureTrace.describe(kind, event.index, event.position, Mode.keys()[_mode], _touches.size()))


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.canceled:
		# The system took the gesture (a notification pulled down, say), so every finger is gone.
		_cancel_gesture()
		return

	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_begin_single(event.index, event.position)
		elif _mode == Mode.SLOT_DRAGGING:
			pass
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
	elif _mode == Mode.SLOT_DRAGGING:
		# The stack follows its own finger; losing that one drops it and the rest are ignored.
		if event.index == _drag_index:
			_release_held()
			_mode = Mode.PINCH_ENDED
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
	var now := _now()
	_last_seen[event.index] = now
	if now - _last_drag_note >= DRAG_TRACE_INTERVAL:
		_last_drag_note = now
		trace.record(now, GestureTrace.describe("drag", event.index, event.position, Mode.keys()[_mode], _touches.size()))
	match _mode:
		Mode.DRAGGING, Mode.SLOT_DRAGGING:
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
	var slot := slot_at(screen_position)
	if slot != -1:
		# The tray is not part of the world: a touch on it never pans or picks a table piece.
		if state.slot_piece_count(slot) > 0:
			_begin_slot_drag(index, slot, screen_position)
		else:
			_mode = Mode.IDLE
		return
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
		node.reparent(held_layer, false)
	_drag_index = index
	_held_screen = screen_position
	_held_offset = state.offset_of(_held_root) - world
	_mode = Mode.DRAGGING
	cluster_lifted.emit(_held_root, _held_nodes.size())


## The slot whose rectangle holds the screen point, or -1.
func slot_at(screen_position: Vector2) -> int:
	for s in slot_rects.size():
		if slot_rects[s].has_point(screen_position):
			return s
	return -1


# Takes the whole stack out of its slot and fans it under the finger.
func _begin_slot_drag(index: int, slot: int, screen_position: Vector2) -> void:
	_finish_cleanup()
	_slot_held = state.take_slot(slot)
	_slot_held_from = slot
	_slot_held_rects.clear()
	var piece_total := 0
	for root in _slot_held:
		_slot_held_rects.append(cluster_home_rect(root))
		piece_total += state.members(root).size()
		for id in state.members(root):
			var node := _nodes[id]
			node.reparent(held_layer, false)
			node.set_held(true)
	_drag_index = index
	_held_screen = screen_position
	_mode = Mode.SLOT_DRAGGING
	_follow_held()
	slots_changed.emit()
	cluster_lifted.emit(_slot_held[0], piece_total)


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
	if not _slot_held.is_empty():
		_held_screen = _touches[_drag_index]
		_place_stack(SlotSpread.fan(_slot_held_rects, _to_world(_held_screen)))
		var over := slot_at(_held_screen)
		var near_home := _slot_held_from >= 0 and _slot_held_from < slot_rects.size() \
				and slot_rects[_slot_held_from].grow(NEAR_SLOT_MARGIN).has_point(_held_screen)
		_set_hover(over if over != -1 else (_slot_held_from if near_home else -1))
		return
	if _held_root == -1:
		return
	_held_screen = _touches[_drag_index]
	var offset := _to_world(_touches[_drag_index]) + _held_offset
	state.move_cluster(_held_root, offset)
	for node in _held_nodes:
		node.position = offset
	_set_hover(slot_at(_held_screen))


# The slot that letting go now would put the held pieces into, or -1. The tray lights it up.
func _set_hover(slot: int) -> void:
	if slot == _hover_slot:
		return
	_hover_slot = slot
	slot_hover_changed.emit(slot)


func _cancel_gesture() -> void:
	_touches.clear()
	_end_gesture()


func _end_gesture() -> void:
	_release_held()
	_mode = Mode.IDLE


# Every release is a drop, however the finger went away, so the cluster always settles.
func _release_held() -> void:
	_drag_index = -1
	_set_hover(-1)
	if not _slot_held.is_empty():
		_release_stack()
		return
	if _held_root == -1:
		return
	for node in _held_nodes:
		node.set_held(false)
	var over := slot_at(_held_screen)
	if over != -1 and not releasing_for_system:
		var piece_total := state.members(_held_root).size()
		_stash(_held_root, over)
		stashed.emit(piece_total)
		_held_root = -1
		_held_nodes.clear()
		slots_changed.emit()
		save_game()
		return
	# Back on the table, last in draw order, where the lift left them.
	for node in _held_nodes:
		node.reparent(pieces, false)
	var result := state.drop(_held_root)
	_held_root = -1
	_held_nodes.clear()
	_settle(result)


# Moves each cluster of the held stack by its offset, so the nodes and the state agree.
func _place_stack(offsets: PackedVector2Array) -> void:
	for k in _slot_held.size():
		state.move_cluster(_slot_held[k], offsets[k])
		for id in state.members(_slot_held[k]):
			_nodes[id].position = offsets[k]


# Puts a cluster's pieces away in a slot: hidden, off the table, and out of reach of joins.
func _stash(root: int, slot: int) -> void:
	state.put_in_slot(root, slot)
	for id in state.members(root):
		var node := _nodes[id]
		node.set_held(false)
		node.reparent(stash, false)


# The held stack is let go. Near its own slot, or on any slot, it goes in; anywhere else it spreads
# into an even grid where the finger lifted. A system release always puts it back, never scatters it.
func _release_stack() -> void:
	var roots := _slot_held
	var from := _slot_held_from
	var rects := _slot_held_rects
	_slot_held = PackedInt32Array()
	_slot_held_from = -1
	_slot_held_rects = []
	var dest := slot_at(_held_screen)
	var near_home := from >= 0 and from < slot_rects.size() and slot_rects[from].grow(NEAR_SLOT_MARGIN).has_point(_held_screen)
	if releasing_for_system or dest != -1 or near_home:
		var into := from if releasing_for_system or dest == -1 else dest
		var piece_total := 0
		for root in roots:
			piece_total += state.members(root).size()
			_stash(root, into)
		if not releasing_for_system:
			stashed.emit(piece_total)
	else:
		var offsets := SlotSpread.grid(rects, _to_world(_held_screen), state.tolerance)
		for k in roots.size():
			state.move_cluster(roots[k], offsets[k])
			for id in state.members(roots[k]):
				_nodes[id].position = offsets[k]
				_nodes[id].set_held(false)
				_nodes[id].reparent(pieces, false)
		# Each cluster settles as a normal drop, so one that lands on its place locks.
		for root in roots:
			_settle(state.drop(root))
	slots_changed.emit()
	save_game()


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
		ghost_sprite.visible = false
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


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(puzzle.image_size))
	draw_rect(rect, Palette.board())
	draw_rect(rect, Palette.accent(), false, BOARD_OUTLINE_WIDTH)


## The picture for an image id at the given size, or null when neither the test picture nor the
## collection has it at that size.
func picture_texture(image_id: String, size: Vector2i) -> Texture2D:
	if not has_picture(image_id, size):
		return null
	if image_id == IMAGE_ID:
		return _make_test_texture()
	return collection.load_texture(collection.find(image_id))


## Whether picture_texture can be asked for this picture, without loading it.
func has_picture(image_id: String, size: Vector2i) -> bool:
	if image_id == IMAGE_ID:
		return size == IMAGE_SIZE
	if collection == null:
		return false
	var picture := collection.find(image_id)
	return picture != null and picture.size() == size


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
