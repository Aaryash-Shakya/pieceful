extends "res://tests/board_test.gd"

# Member variables, not locals: the signal lambdas would capture locals by value.
var _joined: Array[Vector2i] = []
var _joined_locked: Array[bool] = []
var _locked: Array[Vector2i] = []
var _lifted: Array[Vector2i] = []
var _completed := 0
var _loose_at_completion := -1
var tol: float
var _pair_1: Vector2i
var _pair_2: Vector2i
var _pair_3: Vector2i
var _pair_4: Vector2i
var _r: PieceNode
var _t: PieceNode
var _reorders := 0


func _init() -> void:
	await process_frame
	make_board()
	_show_everything()
	tol = board.state.tolerance
	board.pieces_joined.connect(func(root: int, count: int, locked: bool) -> void:
		_joined.append(Vector2i(root, count))
		_joined_locked.append(locked))
	board.cluster_locked.connect(func(root: int, count: int) -> void: _locked.append(Vector2i(root, count)))
	board.cluster_lifted.connect(func(root: int, count: int) -> void: _lifted.append(Vector2i(root, count)))
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
	_join_pair_3()
	_test_lift_raises_cluster_in_order()
	_test_hold_pinch_moves_cluster()
	_test_holding_finger_lift_joins()
	_test_holding_finger_lift_locks()
	_test_edge_pan_carries_cluster()
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
	var lifted_before := _lifted.size()
	_move_by_touch(p, q.position + Vector2(0.5, -0.3) * tol)
	check(board.state.find(p.piece_id) == board.state.find(q.piece_id), "a piece dropped beside its neighbour joins it")
	check(p.position == q.position, "the joined piece snaps to its neighbour's offset")
	check(q.position == q_before, "the neighbour it joined does not move")
	check(_joined.size() == 1 and _joined[0] == Vector2i(board.state.find(p.piece_id), 2), "a join reports the root and two pieces")
	check(_locked.is_empty(), "a join away from home does not lock")
	check(_joined_locked == [false], "a join away from home is not flagged as locked")
	check(_lifted.size() == lifted_before + 1 and _lifted.back() == Vector2i(_pair_1.x, 1), "the press lifted a singleton")
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
	check(_lifted.back() == Vector2i(board.state.find(q.piece_id), 2), "pressing a cluster lifts it with both pieces")
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
	if _r == null:
		check(false, "found a loose singleton to lock")
		return
	_move_by_touch(_r, Vector2(0.5, 0.4) * tol)
	check(board.state.is_locked(_r.piece_id), "a piece dropped near home locks")
	check(_r.position == Vector2.ZERO, "a locked piece sits exactly at home")
	check(_r.get_parent() == board.locked_pieces, "a locked piece moves under the locked layer")
	check(not _locked.is_empty() and _locked.back() == Vector2i(board.state.find(_r.piece_id), 1), "a lock reports the root and one piece")
	check(_completed == 0, "one lock does not complete the puzzle")


func _test_locked_piece_cannot_be_picked_up() -> void:
	if _r == null:
		return
	var c := Vector2.INF
	for point in _inside_points(_r):
		if _top_piece_at(point) == null:
			c = point
			break
	check(c != Vector2.INF, "found an uncovered point on the locked piece")
	var s := _to_screen(c)
	var n := _lifted.size()
	_touch(0, s, true)
	check(_lifted.size() == n, "pressing a locked piece lifts nothing")
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

	for what: int in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT]:
		var label := "a pause" if what == Node.NOTIFICATION_APPLICATION_PAUSED else "focus out"
		u = _next_loose_singleton()
		s = _grab_point(u)
		where = s + (Vector2(0.4 * tol, 0) - u.position) * camera.zoom.x
		_touch(0, s, true)
		_drag(0, where, where - s)
		board.notification(what)
		check(board.state.is_locked(u.piece_id), "%s drops the piece, so it locks near home" % label)
		check(u.position == Vector2.ZERO, "a piece dropped by %s sits at home" % label)
		check(u.get_parent() == board.locked_pieces, "a piece dropped by %s moves under the locked layer" % label)


func _join_pair_3() -> void:
	_pair_3 = _loose_pair(_used_ids())
	var p := board.node_for(_pair_3.x)
	var q := board.node_for(_pair_3.y)
	_move_by_touch(p, q.position)
	check(board.state.find(p.piece_id) == board.state.find(q.piece_id), "pair 3 joins for the cluster input tests")


func _test_lift_raises_cluster_in_order() -> void:
	_t = _next_loose_singleton()
	_move_by_touch(_t, _t.position + Vector2(300, 0))
	check(pieces.get_child(pieces.get_child_count() - 1) == _t, "a piece dropped alone ends on top")
	var first := board.node_for(_pair_3.x)
	var second := board.node_for(_pair_3.y)
	if first.get_index() > second.get_index():
		var swap := first
		first = second
		second = swap
	var s := _grab_point(second)
	_touch(0, s, true)
	check(board.held_layer.get_child_count() == 2 and board.held_layer.get_child(0) == first and board.held_layer.get_child(1) == second, "lifting a cluster raises it keeping its order")
	check(first.z_index == PieceNode.HELD_Z_INDEX and second.z_index == PieceNode.HELD_Z_INDEX, "every piece of a lifted cluster is lifted")
	check(_t.z_index == 0, "pieces outside the lifted cluster stay on the base layer")
	_touch(0, s, false)
	check(first.z_index == 0 and second.z_index == 0, "a dropped cluster returns to the base layer")

	# Lifting the cluster just dropped finds it already on top, so no other piece is reordered.
	var rest := pieces.get_children().slice(0, pieces.get_child_count() - 2)
	_touch(0, s, true)
	check(board.held_layer.get_child(0) == first and board.held_layer.get_child(1) == second, "a re-lifted cluster keeps its order")
	_touch(0, s, false)
	check(board.held_layer.get_child(0) == first and board.held_layer.get_child(1) == second, "a re-lifted cluster keeps its order")

	# Only the member already on top stays; the other slots in just below it.
	pieces.move_child(first, 0)
	_touch(0, s, true)
	check(board.held_layer.get_child(0) == first and board.held_layer.get_child(1) == second, "a partly raised cluster is lifted in order")
	_touch(0, s, false)


func _test_hold_pinch_moves_cluster() -> void:
	var p := board.node_for(_pair_3.x)
	var q := board.node_for(_pair_3.y)
	var a := _grab_point(q)
	var offset := q.position - _to_world(a)
	var b := a + Vector2(100, 0)
	_touch(0, a, true)
	var n := _lifted.size()
	_touch(1, b, true)
	var swing := Vector2(-100, 100)
	_drag(1, b + swing, swing)
	check(_lifted.size() == n, "a second finger lifts nothing")
	check(_near(q.position, _to_world(a) + offset), "a second finger pans with the cluster under the holding finger")
	check(_cluster_at_offset(p, q), "a hold and pan moves every piece of the cluster")

	var zoom := camera.zoom.x
	var spread := Vector2(100, 60)
	_drag(1, b + swing + spread, spread)
	check(camera.zoom.x > zoom, "a second finger moving away zooms while a cluster is held")
	check(_near(q.position, _to_world(a) + offset), "a hold and zoom keeps the cluster under the holding finger")
	check(_cluster_at_offset(p, q), "a hold and zoom moves every piece of the cluster")

	var before := q.position
	var delta := Vector2(-20, 15)
	_drag(0, a + delta, delta)
	check(_lifted.size() == n, "dragging during a pinch lifts nothing")
	check(_near(q.position, before + delta / camera.zoom.x), "the holding finger moves its cluster during a pinch")
	check(_cluster_at_offset(p, q), "the holding finger moves every piece of the cluster")
	_touch(0, a + delta, false)
	_touch(1, b + swing + spread, false)
	check(not _is_held(p) and not _is_held(q), "nothing is held after both fingers lift")
	_show_everything()


func _test_holding_finger_lift_joins() -> void:
	var used := _used_ids()
	used.append_array([_pair_3.x, _pair_3.y, _t.piece_id])
	_pair_4 = _loose_pair(used)
	var p := board.node_for(_pair_4.x)
	var q := board.node_for(_pair_4.y)
	var s := _grab_point(p)
	var relative := (q.position - p.position) * camera.zoom.x
	_touch(0, s, true)
	_touch(1, s + Vector2(100, 0), true)
	_drag(0, s + relative, relative)
	_touch(0, s + relative, false)
	_touch(1, s + Vector2(100, 0), false)
	check(board.state.find(p.piece_id) == board.state.find(q.piece_id), "lifting the holding finger during a pinch joins the neighbour")
	check(p.position == q.position, "a cluster joined during a pinch snaps together")
	check(not _joined.is_empty() and _joined.back() == Vector2i(board.state.find(p.piece_id), 2), "a join during a pinch is reported")


func _test_holding_finger_lift_locks() -> void:
	var p := board.node_for(_pair_4.x)
	var q := board.node_for(_pair_4.y)
	var s := _grab_point(p)
	var relative := (Vector2(0.3, 0.2) * tol - p.position) * camera.zoom.x
	_touch(0, s, true)
	_touch(1, s + Vector2(100, 0), true)
	_drag(0, s + relative, relative)
	_touch(0, s + relative, false)
	check(board.state.is_locked(p.piece_id) and board.state.is_locked(q.piece_id), "lifting the holding finger during a pinch near home locks the cluster")
	check(p.position == Vector2.ZERO and q.position == Vector2.ZERO, "a cluster locked during a pinch sits at home")
	check(p.get_parent() == board.locked_pieces and q.get_parent() == board.locked_pieces, "a cluster locked during a pinch moves under the locked layer")
	check(not _locked.is_empty() and _locked.back() == Vector2i(board.state.find(p.piece_id), 2), "a lock during a pinch is reported")
	_touch(1, s + Vector2(100, 0), false)


func _test_edge_pan_carries_cluster() -> void:
	var p := board.node_for(_pair_3.x)
	var q := board.node_for(_pair_3.y)
	camera.position = bounds.get_center()
	var s := _grab_point(q)
	var edge := Vector2(viewport_size.x, viewport_size.y / 2.0)
	_touch(0, s, true)
	_drag(0, edge, edge - s)
	var q_before := q.position
	var camera_before := camera.position
	board._process(0.1)
	check(camera.position != camera_before, "edge pan moves the camera while a cluster is held")
	check(_near(q.position, q_before + (camera.position - camera_before)), "edge pan carries the held cluster with the camera")
	check(_cluster_at_offset(p, q), "edge pan moves every piece of the cluster")
	_touch(0, edge, false)


func _count_reorder() -> void:
	_reorders += 1


# Ids the earlier tests chose, so later picks do not reuse them.
func _used_ids() -> PackedInt32Array:
	var used := PackedInt32Array([_pair_1.x, _pair_1.y, _pair_2.x, _pair_2.y])
	if _r != null:
		used.append(_r.piece_id)
	return used


# Members of a cluster share one offset, so equal positions that match the state mean none was left behind.
func _cluster_at_offset(p: PieceNode, q: PieceNode) -> bool:
	return p.position == q.position and q.position == board.state.offset_of(q.piece_id)


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


func _next_loose_singleton() -> PieceNode:
	for i in board.state.piece_count():
		if _is_loose_singleton(i) and _grab_point(board.node_for(i)) != Vector2.INF:
			return board.node_for(i)
	check(false, "found a loose singleton with a grab point")
	return board.node_for(0)
