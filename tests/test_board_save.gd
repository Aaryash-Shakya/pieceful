extends "res://tests/board_test.gd"

const LogCapture := preload("res://tests/log_capture.gd")

# Member variables, not locals: the signal lambda would capture a local by value.
var _completed := 0
var capture: LogCapture
# Every piece a test has moved, so later tests pick untouched pieces.
var _used := PackedInt32Array()


func _init() -> void:
	await process_frame
	make_board()
	_show_everything()
	board.puzzle_completed.connect(func() -> void: _completed += 1)
	capture = LogCapture.new()
	OS.add_logger(capture)

	_test_fresh_identity()
	_test_plain_drag_and_join_do_not_save()
	_test_lock_saves()
	_test_file_matches_snapshot()
	_test_snapshot_contents()
	_test_no_geometry_keys()
	_test_identical_bytes()
	_test_notification_saves(Node.NOTIFICATION_APPLICATION_FOCUS_OUT, "focus out")
	_test_notification_saves(Node.NOTIFICATION_APPLICATION_PAUSED, "pause")
	_test_notification_saves(Node.NOTIFICATION_WM_CLOSE_REQUEST, "close request")
	_test_notification_saves(Node.NOTIFICATION_WM_GO_BACK_REQUEST, "back request")
	_test_forced_join_is_saved()
	_test_tidy_does_not_save()
	await _test_elapsed_counts()
	_test_completion_deletes_save()
	_test_pause_completing_drop_leaves_no_save()

	board.free()
	OS.remove_logger(capture)
	check(capture.warnings.is_empty() and capture.errors.is_empty(), "saving prints no warning or error")
	finish()


func _saved() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))


func _cluster_of(saved: Dictionary, piece: int) -> Dictionary:
	for cluster: Dictionary in saved.clusters:
		if (cluster.pieces as Array).has(float(piece)):
			return cluster
	check(false, "the save has a cluster holding piece %d" % piece)
	return {}


func _saved_offset(saved: Dictionary, piece: int) -> Vector2:
	var offset: Array = _cluster_of(saved, piece).get("offset", [INF, INF])
	return Vector2(offset[0], offset[1])


func _temp_exists() -> bool:
	return FileAccess.file_exists(TEST_SAVE_PATH + SaveFile.TEMP_SUFFIX)


# The first half of _move_by_touch: the finger stays down.
func _hold(node: PieceNode, target: Vector2) -> Vector2:
	var s := _grab_point(node)
	var relative := (target - node.position) * camera.zoom.x
	_touch(0, s, true)
	_drag(0, s + relative, relative)
	return s + relative


func _first_loose_singleton() -> PieceNode:
	for i in board.state.piece_count():
		if not _used.has(i) and _is_loose_singleton(i) and _grab_point(board.node_for(i)) != Vector2.INF:
			_used.append(i)
			return board.node_for(i)
	check(false, "found an untouched loose singleton")
	return null


func _lock_all_loose_but(keep: int) -> void:
	for root in board.state.roots():
		if board.state.is_locked(root) or board.state.find(root) == board.state.find(keep):
			continue
		board.state.move_cluster(root, Vector2.ZERO)
		board.state.drop(root)


func _test_fresh_identity() -> void:
	var p := board.puzzle
	check(p.image_id == Board.IMAGE_ID, "the fresh puzzle uses the test image")
	check(p.image_size == Board.IMAGE_SIZE, "the fresh puzzle uses the image size")
	check(p.style == Board.STYLE, "the fresh puzzle uses the style")
	check(p.piece_count == Board.PIECE_COUNT, "the fresh puzzle uses the piece count")
	check(p.cut_seed == Board.SEED, "the fresh puzzle uses the seed")
	check(board.elapsed == 0.0, "the clock starts at zero")
	check(not FileAccess.file_exists(TEST_SAVE_PATH), "starting does not save")


func _test_plain_drag_and_join_do_not_save() -> void:
	var n := _first_loose_singleton()
	_move_by_touch(n, n.position + Vector2(5, 5))
	check(board.state.members(n.piece_id).size() == 1 and not board.state.is_locked(n.piece_id),
			"the plain drag neither joins nor locks")
	check(not FileAccess.file_exists(TEST_SAVE_PATH), "a plain drag does not save")

	var pair := _loose_pair(_used)
	_used.append(pair.x)
	_used.append(pair.y)
	_move_by_touch(board.node_for(pair.x), board.node_for(pair.y).position)
	check(board.state.find(pair.x) == board.state.find(pair.y), "the pair joins")
	check(not FileAccess.file_exists(TEST_SAVE_PATH), "a join does not save")


func _test_lock_saves() -> void:
	var n := _first_loose_singleton()
	_move_by_touch(n, Vector2.ZERO)
	check(board.state.is_locked(n.piece_id), "the piece locks")
	check(FileAccess.file_exists(TEST_SAVE_PATH), "a lock saves")
	check(_cluster_of(_saved(), n.piece_id).get("locked") == true, "the save holds the lock")
	check(not _temp_exists(), "a lock leaves no temp file")


func _test_file_matches_snapshot() -> void:
	check(FileAccess.get_file_as_string(TEST_SAVE_PATH) == SaveGame.to_json(board.snapshot()),
			"the file is the snapshot's JSON")


func _test_snapshot_contents() -> void:
	var s := board.snapshot()
	var order := PackedInt32Array()
	for child in board.pieces.get_children():
		order.append((child as PieceNode).piece_id)
	check(s.loose_order == order, "the loose order is the draw order")
	var roots := PackedInt32Array()
	for c in s.clusters:
		roots.append(c.root)
	check(roots == board.state.roots(), "the snapshot holds every cluster")
	check(s.tidy_count == board._cleanup_count, "the snapshot holds the tidy counter")
	check(s.elapsed == board.elapsed, "the snapshot holds the clock")
	check(s.puzzle == board.puzzle, "the snapshot holds the puzzle")


func _test_no_geometry_keys() -> void:
	var keys := {}
	_collect_keys(_saved(), keys)
	var found: Array = keys.keys()
	found.sort()
	check(found == ["clusters", "elapsed", "height", "image_id", "locked", "loose_order", "offset", "piece_count",
			"pieces", "puzzle", "root", "seed", "style", "tidy_count", "version", "width"],
			"the save holds no geometry: %s" % [found])
	check(FileAccess.get_file_as_bytes(TEST_SAVE_PATH).size() < 131072, "the save stays small")


func _collect_keys(value: Variant, keys: Dictionary) -> void:
	if value is Dictionary:
		for key in value:
			keys[key] = true
			_collect_keys(value[key], keys)
	elif value is Array:
		for item in value:
			_collect_keys(item, keys)


func _test_identical_bytes() -> void:
	board.save_game()
	var first := FileAccess.get_file_as_bytes(TEST_SAVE_PATH)
	board.save_game()
	check(FileAccess.get_file_as_bytes(TEST_SAVE_PATH) == first, "saving twice writes identical bytes")


func _test_notification_saves(what: int, label: String) -> void:
	SaveFile.remove(TEST_SAVE_PATH)
	var n := _first_loose_singleton()
	_hold(n, n.position + Vector2(0, 40))
	check(_is_held(n), "%s: the piece is held" % label)
	board._notification(what)
	check(not _is_held(n), "%s: the piece is dropped" % label)
	check(FileAccess.file_exists(TEST_SAVE_PATH), "%s saves" % label)
	check(not _temp_exists(), "%s leaves no temp file" % label)
	check(_saved_offset(_saved(), n.piece_id) == board.state.offset_of(n.piece_id),
			"%s: the save holds the forced drop" % label)
	board._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)


# A plain drop changes no offset, so only a drop that joins shows the save came after it.
func _test_forced_join_is_saved() -> void:
	SaveFile.remove(TEST_SAVE_PATH)
	var pair := _loose_pair(_used)
	_used.append(pair.x)
	_used.append(pair.y)
	_hold(board.node_for(pair.x), board.node_for(pair.y).position)
	board._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(board.state.find(pair.x) == board.state.find(pair.y), "the forced drop joins the pair")
	check(not board.state.is_locked(pair.x), "the forced join does not lock")
	check((_cluster_of(_saved(), pair.x).get("pieces", []) as Array).has(float(pair.y)),
			"the save holds the join the forced drop made")
	board._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)


func _test_tidy_does_not_save() -> void:
	SaveFile.remove(TEST_SAVE_PATH)
	board.cleanup()
	check(board.is_tidying(), "the tidy runs")
	check(not FileAccess.file_exists(TEST_SAVE_PATH), "a tidy does not save")
	board.save_game()
	var saved := _saved()
	var all_final := true
	for root in board.state.roots():
		if not board.state.is_locked(root) and _saved_offset(saved, root) != board.state.offset_of(root):
			all_final = false
	check(all_final, "a save mid-tidy holds the final offsets")
	board._finish_cleanup()


func _test_elapsed_counts() -> void:
	var e := board.elapsed
	board._process(0.1)
	check(is_equal_approx(board.elapsed, e + 0.1), "the clock adds the frame time")
	e = board.elapsed
	board._process(5.0)
	check(board.elapsed == e + Board.ELAPSED_STEP_LIMIT, "a long frame adds at most the step limit")

	for leave: Array in [
		[Node.NOTIFICATION_APPLICATION_FOCUS_OUT, "focus out"],
		[Node.NOTIFICATION_APPLICATION_PAUSED, "pause"],
	]:
		board._notification(leave[0])
		e = board.elapsed
		board._process(0.1)
		check(board.elapsed == e, "the clock stops on %s" % leave[1])
		# Android can resume the app behind the lock screen or in multi-window without focus.
		board._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		board._process(0.1)
		check(board.elapsed == e, "resuming without focus does not start the clock after %s" % leave[1])
		board._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		board._process(0.1)
		check(is_equal_approx(board.elapsed, e + 0.1), "focus starts the clock again after %s" % leave[1])

	e = board.elapsed
	for i in 3:
		await process_frame
	check(board.elapsed > e, "it counts on real frames")


func _test_completion_deletes_save() -> void:
	board.save_game()
	check(FileAccess.file_exists(TEST_SAVE_PATH), "the setup saves")
	var n := _first_loose_singleton()
	_lock_all_loose_but(n.piece_id)
	_move_by_touch(n, Vector2.ZERO)
	check(_completed == 1, "the last lock completes the puzzle")
	check(not FileAccess.file_exists(TEST_SAVE_PATH), "completion deletes the save")
	check(not _temp_exists(), "completion leaves no temp file")
	var e := board.elapsed
	board._process(0.1)
	check(board.elapsed == e, "the clock stops on completion")
	check(board.save_game(), "saving a complete puzzle succeeds")
	check(not FileAccess.file_exists(TEST_SAVE_PATH), "saving a complete puzzle writes nothing")
	board._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not FileAccess.file_exists(TEST_SAVE_PATH), "pausing a complete puzzle writes nothing")


func _test_pause_completing_drop_leaves_no_save() -> void:
	board.free()
	make_board()
	_show_everything()
	board.puzzle_completed.connect(func() -> void: _completed += 1)
	_completed = 0
	_used = PackedInt32Array()
	var n := _first_loose_singleton()
	_lock_all_loose_but(n.piece_id)
	board.save_game()
	check(FileAccess.file_exists(TEST_SAVE_PATH), "the second setup saves")
	_hold(n, Vector2.ZERO)
	board._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(board.state.is_complete(), "the forced drop completes the puzzle")
	check(_completed == 1, "the forced drop reports completion")
	check(not FileAccess.file_exists(TEST_SAVE_PATH), "a pause that completes leaves no save")
	check(not _temp_exists(), "a pause that completes leaves no temp file")
