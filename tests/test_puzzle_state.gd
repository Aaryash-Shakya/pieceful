extends BaseTest

var cut: Array[CutPiece] = CutGenerator.generate_cut(300, 200, 6, CutGenerator.STYLE_GRID, 1)


func _init() -> void:
	_test_fixture()
	_test_tolerance()
	_test_initial_state()
	_test_move_cluster()
	_test_lock_boundaries()
	_test_minimum_tolerance_on_tiny_cells()
	_test_locked_cluster_is_frozen()
	_test_completion()
	finish()


func _fresh(overrides: Dictionary = {}) -> PuzzleState:
	var offsets := PackedVector2Array()
	for i in cut.size():
		offsets.append(overrides.get(i, Vector2(1000 * (i + 1), 0)))
	return PuzzleState.new(cut, offsets, PuzzleState.tolerance_for(300, 200, 6))


func _sorted(values: PackedInt32Array) -> PackedInt32Array:
	var copy := values.duplicate()
	copy.sort()
	return copy


func _test_fixture() -> void:
	check(cut.size() == 6, "fixture has 6 pieces")
	check(_sorted(cut[0].neighbours) == PackedInt32Array([1, 3]), "piece 0 neighbours are 1 and 3")
	check(_sorted(cut[1].neighbours) == PackedInt32Array([0, 2, 4]), "piece 1 neighbours are 0, 2 and 4")
	check(_sorted(cut[5].neighbours) == PackedInt32Array([2, 4]), "piece 5 neighbours are 2 and 4")


func _test_tolerance() -> void:
	check(is_equal_approx(PuzzleState.tolerance_for(300, 200, 6), 22.0), "tolerance on 100-pixel cells is 22")
	check(absf(PuzzleState.tolerance_for(1536, 1024, 400) - 13.7955) < 1e-3, "tolerance for 1536x1024 at 400 pieces")
	check(is_equal_approx(PuzzleState.tolerance_for(1000, 1000, 400), 11.0), "tolerance for 1000x1000 at 400 pieces")
	check(PuzzleState.tolerance_for(100, 100, 400) == 10.0, "tolerance never drops below the minimum")
	check(is_equal_approx(PuzzleState.tolerance_for(2000, 2000, 4), 220.0), "tolerance for 2000x2000 at 4 pieces")


func _test_initial_state() -> void:
	var state := _fresh()
	check(state.piece_count() == 6, "piece_count is 6")
	for i in 6:
		check(state.find(i) == i, "piece %d starts as its own root" % i)
		check(state.members(i) == PackedInt32Array([i]), "piece %d starts alone" % i)
		check(state.offset_of(i) == Vector2(1000 * (i + 1), 0), "piece %d starts at its offset" % i)
		check(not state.is_locked(i), "piece %d starts loose" % i)
	check(state.roots() == PackedInt32Array([0, 1, 2, 3, 4, 5]), "every piece is a root at the start")
	check(not state.is_complete(), "fresh state is not complete")
	check(is_equal_approx(state.tolerance, 22.0), "state keeps the tolerance it was given")


func _test_move_cluster() -> void:
	var state := _fresh()
	var before := state.offset_of(1)
	state.move_cluster(2, Vector2(5, 6))
	check(state.offset_of(2) == Vector2(5, 6), "move_cluster sets the offset")
	check(state.offset_of(1) == before, "move_cluster leaves other pieces alone")


func _test_lock_boundaries() -> void:
	var state := _fresh()
	var tol := state.tolerance
	state.move_cluster(0, Vector2(0.99 * tol, 0))
	var result := state.drop(0)
	check(result.root == 0, "drop reports the root")
	check(result.locked, "just inside tolerance locks")
	check(not result.joined, "locking alone is not a join")
	check(state.offset_of(0) == Vector2.ZERO, "locking snaps the offset to zero")
	check(state.is_locked(0), "piece 0 is locked")

	state.move_cluster(1, Vector2(0, 1.01 * tol))
	result = state.drop(1)
	check(not result.locked, "just outside tolerance does not lock")
	check(state.offset_of(1) == Vector2(0, 1.01 * tol), "a missed drop leaves the offset alone")

	state.move_cluster(2, Vector2(0.6 * tol, 0.6 * tol))
	result = state.drop(2)
	check(result.locked, "a diagonal offset of 0.85 tolerance locks")


func _test_minimum_tolerance_on_tiny_cells() -> void:
	var tiny := CutGenerator.generate_cut(100, 100, 400, CutGenerator.STYLE_GRID, 1)
	var offsets := PackedVector2Array()
	for i in tiny.size():
		offsets.append(Vector2(5000, 0))
	var state := PuzzleState.new(tiny, offsets, PuzzleState.tolerance_for(100, 100, 400))
	state.move_cluster(0, Vector2(9.5, 0))
	check(state.drop(0).locked, "9.5 pixels locks under the 10 pixel minimum")
	state.move_cluster(1, Vector2(10.5, 0))
	check(not state.drop(1).locked, "10.5 pixels does not lock")


func _test_locked_cluster_is_frozen() -> void:
	var state := _fresh()
	state.move_cluster(0, Vector2(1, 1))
	state.drop(0)
	state.move_cluster(0, Vector2(50, 50))
	check(state.offset_of(0) == Vector2.ZERO, "a locked cluster ignores move_cluster")
	var result := state.drop(0)
	check(result.root == 0, "dropping a locked cluster reports its root")
	check(not result.locked, "dropping a locked cluster does not lock again")
	check(not result.joined, "dropping a locked cluster does not join")
	check(state.is_locked(0), "the cluster stays locked")


func _test_completion() -> void:
	var state := _fresh()
	for i in 6:
		state.move_cluster(i, Vector2(1, 1))
		state.drop(i)
		check(state.is_complete() == (i == 5), "is_complete after drop %d" % i)
