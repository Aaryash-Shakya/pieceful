extends BoardTest

# Member variables, not locals: the signal lambdas would capture locals by value.
var _joined: Array[Vector2i] = []
var _locked: Array[Vector2i] = []
var _completed := 0
var _loose_at_completion := -1
var tol: float
var _pair_1: Vector2i
var _pair_2: Vector2i
var _r: PieceNode


func _init() -> void:
	await process_frame
	make_board()
	_show_everything()
	tol = board.state.tolerance
	board.pieces_joined.connect(func(root: int, count: int) -> void: _joined.append(Vector2i(root, count)))
	board.cluster_locked.connect(func(root: int, count: int) -> void: _locked.append(Vector2i(root, count)))
	board.puzzle_completed.connect(func() -> void:
		_completed += 1
		_loose_at_completion = pieces.get_child_count())

	_test_starts_loose()
	_test_drop_beside_neighbour_joins()
	_test_drop_outside_tolerance_stays_apart()
	_test_dragging_one_piece_moves_the_cluster()
	_test_drop_near_home_locks()
	_test_locked_piece_cannot_be_picked_up()
	_test_cluster_locks_as_one()
	_test_release_by_cancel_or_pause_drops()
	_test_completion()

	board.free()
	finish()


func _test_starts_loose() -> void:
	check(board.state.piece_count() == 400, "the state tracks every piece")
	var all_loose := true
	for i in board.state.piece_count():
		if board.state.find(i) != i or board.node_for(i).position != board.state.offset_of(i):
			all_loose = false
	check(all_loose, "every piece starts as its own cluster at its scatter offset")
	check(board.locked_pieces.get_child_count() == 0, "nothing starts locked")
	check(board.locked_pieces.get_index() < pieces.get_index(), "locked pieces draw below loose ones")
	check(absf(tol - 13.7955) < 1e-3, "tolerance comes from the image size and piece count")


func _test_drop_beside_neighbour_joins() -> void:
	_pair_1 = _loose_pair(PackedInt32Array())
	var p := board.node_for(_pair_1.x)
	var q := board.node_for(_pair_1.y)
	var q_before := q.position
	_move_by_touch(p, q.position + Vector2(0.5, -0.3) * tol)
	check(board.state.find(p.piece_id) == board.state.find(q.piece_id), "a piece dropped beside its neighbour joins it")
	check(p.position == q.position, "the joined piece snaps to its neighbour's offset")
	check(q.position == q_before, "the neighbour it joined does not move")
	check(_joined.size() == 1 and _joined[0] == Vector2i(board.state.find(p.piece_id), 2), "a join reports the root and two pieces")
	check(_locked.is_empty(), "a join away from home does not lock")
	var last := pieces.get_child_count() - 1
	var top := [pieces.get_child(last), pieces.get_child(last - 1)]
	check(top.has(p) and top.has(q), "the joined cluster is on top")


func _test_drop_outside_tolerance_stays_apart() -> void:
	_pair_2 = _loose_pair(PackedInt32Array([_pair_1.x, _pair_1.y]))
	var p := board.node_for(_pair_2.x)
	var q := board.node_for(_pair_2.y)
	var target := q.position + Vector2(1.5 * tol, 0)
	_move_by_touch(p, target)
	check(board.state.find(p.piece_id) != board.state.find(q.piece_id), "a piece dropped beyond tolerance stays apart")
	check(_near(p.position, target), "a piece that does not join stays where it was dropped")
	check(_joined.size() == 1, "no join is reported beyond tolerance")


func _test_dragging_one_piece_moves_the_cluster() -> void:
	var p := board.node_for(_pair_1.x)
	var q := board.node_for(_pair_1.y)
	var start := q.position
	var s := _grab_point(q)
	var relative := Vector2(12, -7)
	_touch(0, s, true)
	_drag(0, s + relative, relative)
	check(_near(q.position, start + relative / camera.zoom.x), "the dragged piece follows the finger")
	check(p.position == q.position, "its cluster moves with it")
	check(_is_held(p) and _is_held(q), "every piece of the cluster is held")
	_touch(0, s + relative, false)
	check(not _is_held(p) and not _is_held(q), "the cluster is released on touch up")
	check(p.position == q.position, "the released cluster stays together")
	check(_joined.size() == 1, "moving a cluster alone joins nothing")


func _test_drop_near_home_locks() -> void:
	var used := [_pair_1.x, _pair_1.y, _pair_2.x, _pair_2.y]
	for i in board.state.piece_count():
		if not used.has(i) and _is_loose_singleton(i) and _grab_point(board.node_for(i)) != Vector2.INF:
			_r = board.node_for(i)
			break
	_move_by_touch(_r, Vector2(0.5, 0.4) * tol)
	check(board.state.is_locked(_r.piece_id), "a piece dropped near home locks")
	check(_r.position == Vector2.ZERO, "a locked piece sits exactly at home")
	check(_r.get_parent() == board.locked_pieces, "a locked piece moves under the locked layer")
	check(not _locked.is_empty() and _locked.back() == Vector2i(board.state.find(_r.piece_id), 1), "a lock reports the root and one piece")
	check(_completed == 0, "one lock does not complete the puzzle")


func _test_locked_piece_cannot_be_picked_up() -> void:
	var c := Vector2.INF
	for point in _inside_points(_r):
		if _top_piece_at(point) == null:
			c = point
			break
	check(c != Vector2.INF, "found an uncovered point on the locked piece")
	var s := _to_screen(c)
	_touch(0, s, true)
	check(board._mode == Board.Mode.PANNING, "pressing a locked piece pans")
	check(not _is_held(_r), "a locked piece is not picked up")
	var before := camera.position
	_drag(0, s + Vector2(10, 0), Vector2(10, 0))
	check(camera.position != before, "dragging over a locked piece moves the camera")
	check(_r.position == Vector2.ZERO, "dragging over a locked piece leaves it at home")
	_touch(0, s + Vector2(10, 0), false)


func _test_cluster_locks_as_one() -> void:
	var p := board.node_for(_pair_1.x)
	var q := board.node_for(_pair_1.y)
	_move_by_touch(p, Vector2(0.3, 0.3) * tol)
	check(board.state.is_locked(p.piece_id) and board.state.is_locked(q.piece_id), "a cluster dropped near home locks as one")
	check(p.position == Vector2.ZERO and q.position == Vector2.ZERO, "every piece of a locked cluster sits at home")
	check(p.get_parent() == board.locked_pieces and q.get_parent() == board.locked_pieces, "every piece of a locked cluster moves under the locked layer")
	check(not _locked.is_empty() and _locked.back() == Vector2i(board.state.find(p.piece_id), 2), "a cluster lock reports the root and two pieces")


func _test_release_by_cancel_or_pause_drops() -> void:
	var u := _next_loose_singleton()
	var s := _grab_point(u)
	var where := s + (Vector2(0.4 * tol, 0) - u.position) * camera.zoom.x
	_touch(0, s, true)
	_drag(0, where, where - s)
	_touch(0, where, false, true)
	check(board.state.is_locked(u.piece_id), "a cancelled touch drops the piece, so it locks near home")
	check(u.position == Vector2.ZERO, "a piece dropped by a cancel sits at home")
	check(u.get_parent() == board.locked_pieces, "a piece dropped by a cancel moves under the locked layer")

	u = _next_loose_singleton()
	s = _grab_point(u)
	where = s + (Vector2(0.4 * tol, 0) - u.position) * camera.zoom.x
	_touch(0, s, true)
	_drag(0, where, where - s)
	board.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(board.state.is_locked(u.piece_id), "a pause drops the piece, so it locks near home")
	check(u.position == Vector2.ZERO, "a piece dropped by a pause sits at home")
	check(u.get_parent() == board.locked_pieces, "a piece dropped by a pause moves under the locked layer")


func _test_completion() -> void:
	var rounds := 0
	while pieces.get_child_count() > 0 and rounds < 400:
		rounds += 1
		var l := pieces.get_child(pieces.get_child_count() - 1) as PieceNode
		var c := _inside_points(l)[0]
		var from := _to_screen(c + l.position)
		var to := _to_screen(c)
		_touch(0, from, true)
		_drag(0, to, to - from)
		_touch(0, to, false)
	check(pieces.get_child_count() == 0, "every piece leaves the loose layer")
	check(board.locked_pieces.get_child_count() == 400, "every piece ends in the locked layer")
	check(board.state.is_complete(), "the state is complete")
	check(_completed == 1, "completion is reported once")
	check(_loose_at_completion == 0, "completion is reported after the last piece settles")
	var total := 0
	for entry in _locked:
		total += entry.y
	check(total == 400, "lock counts add up to every piece")


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


func _next_loose_singleton() -> PieceNode:
	for i in board.state.piece_count():
		if _is_loose_singleton(i) and _grab_point(board.node_for(i)) != Vector2.INF:
			return board.node_for(i)
	check(false, "found a loose singleton with a grab point")
	return board.node_for(0)


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
