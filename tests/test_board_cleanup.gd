extends "res://tests/board_test.gd"

# Member variables, not locals: the signal lambdas would capture locals by value.
var _lifted: Array[Vector2i] = []
var _joins := 0
var _locks := 0
var _before: Dictionary
var _r: PieceNode


func _init() -> void:
	await process_frame
	make_board()
	_show_everything()
	board.cluster_lifted.connect(func(root: int, count: int) -> void: _lifted.append(Vector2i(root, count)))
	board.pieces_joined.connect(func(_root: int, _count: int, _locked: bool) -> void: _joins += 1)
	board.cluster_locked.connect(func(_root: int, _count: int) -> void: _locks += 1)

	var pair := _loose_pair(PackedInt32Array())
	_move_by_touch(board.node_for(pair.x), board.node_for(pair.y).position)
	check(board.state.find(pair.x) == board.state.find(pair.y), "the setup joins one loose pair")
	for i in board.state.piece_count():
		if i != pair.x and i != pair.y and _is_loose_singleton(i) and _grab_point(board.node_for(i)) != Vector2.INF:
			_r = board.node_for(i)
			break
	_move_by_touch(_r, Vector2.ZERO)
	check(board.state.is_locked(_r.piece_id), "the setup locks one piece")
	_joins = 0
	_locks = 0

	_test_ignored_while_holding()
	_test_tidy_moves_state_at_once()
	await _test_tween_lands_exactly()
	_test_camera_reaches_every_cluster()
	_test_touch_finishes_animation()
	_test_pause_finishes_animation()
	await _test_second_press_mid_animation()
	_test_nothing_loose_does_nothing()

	board.free()
	finish()


func _test_ignored_while_holding() -> void:
	var n: PieceNode = null
	for i in board.state.piece_count():
		if _is_loose_singleton(i) and _grab_point(board.node_for(i)) != Vector2.INF:
			n = board.node_for(i)
			break
	var s := _grab_point(n)
	_touch(0, s, true)
	var positions := _positions()
	board.cleanup()
	check(not board.is_tidying(), "a tidy is ignored while a cluster is held")
	check(board._cleanup_count == 0, "an ignored tidy does not count")
	check(_positions() == positions, "an ignored tidy moves no node")
	_touch(0, s, false)


func _test_tidy_moves_state_at_once() -> void:
	_before = _snapshot()
	var e := _expected(0)
	var positions := _positions()
	board.cleanup()
	check(board.is_tidying(), "a tidy starts an animation")
	var roots := _loose_roots()
	var offsets_match := true
	for k in roots.size():
		if board.state.offset_of(roots[k]) != e.offsets[k]:
			offsets_match = false
	check(offsets_match, "the state takes the layout's offsets at once")
	check(board._bounds == board._base_bounds.merge(e.extent), "the camera bounds grow to the layout's extent")
	check(_positions() == positions, "the tween has not stepped")


func _test_tween_lands_exactly() -> void:
	await _land()
	check(not board.is_tidying(), "the animation ends")
	check(_nodes_match_state(), "every node lands exactly on its state offset")
	check(_r.position == Vector2.ZERO and _r.get_parent() == board.locked_pieces, "a locked piece stays at home on the locked layer")
	check(_snapshot() == _before, "a tidy joins, splits and locks nothing")
	check(_joins == 0 and _locks == 0, "a tidy reports no join or lock")
	var placed := _placed_rects()
	var board_rect := Rect2(Vector2.ZERO, Vector2(Board.IMAGE_SIZE))
	var overlap := false
	var on_board := false
	for i in placed.size():
		if placed[i].intersects(board_rect):
			on_board = true
		for j in range(i + 1, placed.size()):
			if placed[i].intersects(placed[j]):
				overlap = true
	check(not overlap, "no two tidied clusters overlap")
	check(not on_board, "no tidied cluster covers the board")
	var in_reach := false
	for i in board.state.piece_count():
		for q in board.cut[i].neighbours:
			if board.state.find(i) != board.state.find(q) and not board.state.is_locked(i) and not board.state.is_locked(q) \
					and board.state.offset_of(i).distance_to(board.state.offset_of(q)) <= board.state.tolerance:
				in_reach = true
	check(not in_reach, "no tidied cluster is within join reach of a neighbour")


func _test_camera_reaches_every_cluster() -> void:
	var reachable := true
	for rect in _placed_rects():
		var c := rect.get_center()
		if CameraRig.clamp_position(c, board._bounds) != c:
			reachable = false
	check(reachable, "the camera can centre on every tidied cluster")


func _test_touch_finishes_animation() -> void:
	var e := _expected(1)
	board.cleanup()
	check(e.offsets != _expected(0).offsets, "a second tidy deals a new order")
	var n: PieceNode = null
	for i in board.state.piece_count():
		if _is_loose_singleton(i):
			n = board.node_for(i)
			break
	var c := _inside_points(n)[0]
	var s := _to_screen(c + board.state.offset_of(n.piece_id))
	_touch(0, s, true)
	check(not board.is_tidying(), "a touch ends the animation")
	check(_nodes_match_state(), "a touch lands every node on its state offset")
	check(not _lifted.is_empty() and _lifted.back().x == board.state.find(n.piece_id), "the press lifts the cluster at its final place")
	_touch(0, s, false)


func _test_pause_finishes_animation() -> void:
	board.cleanup()
	board._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not board.is_tidying(), "a pause ends the animation")
	check(_nodes_match_state(), "a pause lands every node on its state offset")


func _test_second_press_mid_animation() -> void:
	# Lets the frame clock catch up first, so the frames below advance the tween only a little.
	await process_frame
	board.cleanup()
	await process_frame
	await process_frame
	check(board.is_tidying(), "the first tidy is still animating when the second press comes")
	var e := _expected(board._cleanup_count)
	board.cleanup()
	check(board.is_tidying(), "a second tidy mid-animation starts its own animation")
	check(board._tidy_nodes.size() == _loose_piece_count(), "the second tidy finishes the first before recording its own nodes")
	var roots := _loose_roots()
	var offsets_match := true
	for k in roots.size():
		if board.state.offset_of(roots[k]) != e.offsets[k]:
			offsets_match = false
	check(offsets_match, "a second tidy mid-animation deals the next layout")
	await _land()
	check(_nodes_match_state(), "a second tidy mid-animation lands every node on its state offset")


func _test_nothing_loose_does_nothing() -> void:
	for root in _loose_roots():
		board.state.move_cluster(root, Vector2.ZERO)
		board.state.drop(root)
	var count: int = board._cleanup_count
	var bounds_before: Rect2 = board._bounds
	var positions := _positions()
	board.cleanup()
	check(not board.is_tidying(), "a tidy with nothing loose starts no animation")
	check(board._cleanup_count == count, "a tidy with nothing loose does not count")
	check(board._bounds == bounds_before, "a tidy with nothing loose keeps the camera bounds")
	check(_positions() == positions, "a tidy with nothing loose moves no node")


func _loose_roots() -> PackedInt32Array:
	var result := PackedInt32Array()
	for root in board.state.roots():
		if not board.state.is_locked(root):
			result.append(root)
	return result


func _snapshot() -> Dictionary:
	var result := {}
	for root in board.state.roots():
		result[root] = [board.state.members(root), board.state.is_locked(root)]
	return result


func _home_rect(root: int) -> Rect2:
	var members := board.state.members(root)
	var rect := board.cut[members[0]].bounds()
	for id in members:
		rect = rect.merge(board.cut[id].bounds())
	return rect


func _expected(counter: int) -> CleanupLayout.Result:
	var rects: Array[Rect2] = []
	for root in _loose_roots():
		rects.append(_home_rect(root))
	var cell := sqrt(float(Board.IMAGE_SIZE.x) * Board.IMAGE_SIZE.y / board.cut.size())
	return CleanupLayout.layout(rects, Vector2(Board.IMAGE_SIZE), cell, Board.SEED, counter, board.state.tolerance)


func _loose_piece_count() -> int:
	var count := 0
	for root in _loose_roots():
		count += board.state.members(root).size()
	return count


func _placed_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for root in _loose_roots():
		var home := _home_rect(root)
		result.append(Rect2(home.position + board.state.offset_of(root), home.size))
	return result


func _land() -> void:
	var start := Time.get_ticks_msec()
	while board.is_tidying() and Time.get_ticks_msec() - start < 2000:
		await process_frame


func _nodes_match_state() -> bool:
	for i in board.state.piece_count():
		if board.node_for(i).position != board.state.offset_of(i):
			return false
	return true


func _positions() -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in board.state.piece_count():
		result.append(board.node_for(i).position)
	return result
