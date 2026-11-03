extends "res://tests/base_test.gd"

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
	_test_join_with_neighbour()
	_test_join_boundaries()
	_test_no_join_with_non_neighbour()
	_test_no_join_with_locked()
	_test_lock_wins_over_join()
	_test_multi_join_spreads()
	_test_largest_cluster_keeps_its_place()
	_test_join_then_lock()
	_test_drop_is_deterministic()
	_test_merge_keeps_joining_near_fits()
	_test_resting_cluster_keeps_its_place_on_later_passes()
	_test_invalid_input_is_rejected()
	_test_larger_dropped_cluster_moves_onto_absorbed()
	_test_neighbour_order_does_not_matter()
	finish()


func _fresh(overrides: Dictionary = {}) -> PuzzleState:
	var offsets := PackedVector2Array()
	for i in cut.size():
		offsets.append(overrides.get(i, Vector2(1000 * (i + 1), 0)))
	return PuzzleState.new(cut, offsets, PuzzleState.tolerance_for(300, 200, 6))


func _fixture_tolerance() -> float:
	return PuzzleState.tolerance_for(300, 200, 6)


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

	state.move_cluster(3, Vector2(tol, 0))
	check(state.drop(3).locked, "exactly on the tolerance locks")


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
		# A second drop of a locked piece must not count it twice.
		state.drop(i)
		check(state.is_complete() == (i == 5), "is_complete after drop %d" % i)


func _test_join_with_neighbour() -> void:
	var a := Vector2(500, 0)
	var state := _fresh({0: a})
	var tol := state.tolerance
	state.move_cluster(1, a + Vector2(0.7 * tol, -0.5 * tol))
	var result := state.drop(1)
	check(result.joined, "a drop near a neighbour joins")
	check(not result.locked, "a join far from zero does not lock")
	check(result.root == 0, "the lower id wins a tie of sizes")
	check(state.find(1) == 0, "piece 1 joined root 0")
	check(state.members(1) == PackedInt32Array([0, 1]), "the cluster holds 0 and 1")
	check(state.offset_of(1) == a, "the joined cluster takes the neighbour's offset exactly")
	check(state.offset_of(0) == a, "the neighbour keeps its offset")
	check(state.roots() == PackedInt32Array([0, 2, 3, 4, 5]), "root 1 is gone")


func _test_join_boundaries() -> void:
	var a := Vector2(500, 0)
	var state := _fresh({0: a})
	var tol := state.tolerance
	state.move_cluster(1, a + Vector2(1.01 * tol, 0))
	var result := state.drop(1)
	check(not result.joined, "just outside tolerance does not join")
	check(state.find(1) == 1, "piece 1 stays its own root")
	check(state.offset_of(1) == a + Vector2(1.01 * tol, 0), "a missed join leaves the offset alone")
	state.move_cluster(1, a + Vector2(0.99 * tol, 0))
	check(state.drop(1).joined, "just inside tolerance joins")


func _test_no_join_with_non_neighbour() -> void:
	var a := Vector2(500, 0)
	var state := _fresh({0: a})
	state.move_cluster(2, a + Vector2(1, 1))
	check(not state.drop(2).joined, "a piece two cells away does not join")
	state.move_cluster(4, a)
	check(not state.drop(4).joined, "a diagonal piece does not join")
	check(state.find(0) == 0, "piece 0 is unaffected")


func _test_no_join_with_locked() -> void:
	var state := _fresh()
	var tol := state.tolerance
	state.move_cluster(0, Vector2(1, 1))
	state.drop(0)
	state.move_cluster(1, Vector2(1.5 * tol, 0))
	var result := state.drop(1)
	check(not result.joined, "a locked neighbour is never joined")
	check(not result.locked, "piece 1 is outside the lock tolerance")
	check(state.find(1) == 1, "piece 1 stays its own root")


func _test_lock_wins_over_join() -> void:
	var state := _fresh({0: Vector2(1.2 * _fixture_tolerance(), 0)})
	var tol := state.tolerance
	state.move_cluster(1, Vector2(0.5 * tol, 0))
	var result := state.drop(1)
	check(result.locked, "a piece near zero locks")
	check(not result.joined, "locking takes precedence over joining")
	check(state.find(0) == 0, "the neighbour was not absorbed")
	check(state.offset_of(0) == Vector2(1.2 * tol, 0), "the neighbour did not move")
	check(not state.is_locked(0), "the neighbour stays loose")


func _test_multi_join_spreads() -> void:
	var a := Vector2(500, 0)
	var state := _fresh({0: a, 2: a + Vector2(5, 0), 5: a + Vector2(3, 4), 4: Vector2(900, 0)})
	state.move_cluster(1, a + Vector2(2, 2))
	var result := state.drop(1)
	check(result.joined, "the drop joins")
	check(result.root == 0, "the lowest id wins an all-singleton tie")
	check(state.members(1) == PackedInt32Array([0, 1, 2, 5]), "piece 5 joins through piece 2")
	for i in [0, 1, 2, 5]:
		check(state.offset_of(i) == a, "piece %d sits at the target" % i)
	check(state.find(4) == 4, "the distant piece 4 is left alone")
	check(state.offset_of(4) == Vector2(900, 0), "piece 4 did not move")


func _play(state: PuzzleState) -> void:
	state.move_cluster(4, Vector2(703, 0))
	state.drop(4)
	state.move_cluster(0, Vector2(701, 1))
	state.move_cluster(1, Vector2(702, 0))
	state.drop(1)
	state.move_cluster(5, Vector2(1, 1))
	state.drop(5)


func _test_largest_cluster_keeps_its_place() -> void:
	var state := _fresh({3: Vector2(700, 0)})
	state.move_cluster(4, Vector2(703, 0))
	var first := state.drop(4)
	check(first.joined and first.root == 3, "pieces 3 and 4 join under root 3")
	state.move_cluster(0, Vector2(701, 1))
	state.move_cluster(1, Vector2(702, 0))
	var result := state.drop(1)
	check(result.root == 3, "the biggest cluster supplies the root")
	check(state.members(1) == PackedInt32Array([0, 1, 3, 4]), "all four pieces are in one cluster")
	for i in [0, 1, 3, 4]:
		check(state.offset_of(i) == Vector2(700, 0), "piece %d sits where the biggest cluster was" % i)


func _test_join_then_lock() -> void:
	var state := _fresh({0: Vector2(0.6 * _fixture_tolerance(), 0)})
	var tol := state.tolerance
	state.move_cluster(1, Vector2(1.5 * tol, 0))
	var result := state.drop(1)
	check(result.joined and result.locked, "joining onto a cluster near zero also locks")
	check(state.offset_of(0) == Vector2.ZERO, "piece 0 snapped to zero")
	check(state.offset_of(1) == Vector2.ZERO, "piece 1 snapped to zero")
	check(state.is_locked(0) and state.is_locked(1), "both pieces are locked")
	check(not state.is_complete(), "two of six is not complete")


func _test_drop_is_deterministic() -> void:
	var first := _fresh({3: Vector2(700, 0)})
	var second := _fresh({3: Vector2(700, 0)})
	_play(first)
	_play(second)
	check(first.roots() == second.roots(), "same roots")
	for root in first.roots():
		check(first.members(root) == second.members(root), "same members for root %d" % root)
		check(first.offset_of(root) == second.offset_of(root), "same offset for root %d" % root)
		check(first.is_locked(root) == second.is_locked(root), "same lock for root %d" % root)


# A neighbour out of reach of the drop point but within reach of the merged cluster's new
# offset must still join, or a near fit would be left apart.
func _test_merge_keeps_joining_near_fits() -> void:
	var row := CutGenerator.generate_cut(300, 100, 3, CutGenerator.STYLE_GRID, 1)
	check(row.size() == 3 and _sorted(row[1].neighbours) == PackedInt32Array([0, 2]), "1x3 fixture: piece 1 sits between 0 and 2")
	var offsets := PackedVector2Array([Vector2(500, 0), Vector2(4000, 0), Vector2(509, 0)])
	var state := PuzzleState.new(row, offsets, 10.0)
	state.move_cluster(1, Vector2(498, 0))
	var result := state.drop(1)
	check(result.joined and not result.locked, "the drop joins without locking")
	check(result.root == 0, "root comes from the largest cluster")
	check(state.members(1) == PackedInt32Array([0, 1, 2]), "piece 2 joins at the merged cluster's new offset")
	# Pass 1 snaps piece 1 onto piece 0 at 500. Pass 2 absorbs the single piece 2, and the
	# merged pair is bigger, so the cluster stays at 500 and piece 2 moves onto it.
	check(state.offset_of(0) == Vector2(500, 0), "the merged pair keeps its place on the second pass")
	check(state.offset_of(2) == Vector2(500, 0), "piece 2 moves onto the bigger merged cluster")
	check(state.roots() == PackedInt32Array([0]), "one cluster remains")


# A cluster resting on the table that the drop reaches on the first pass must not jump to a
# single piece that only the second pass picks up.
func _test_resting_cluster_keeps_its_place_on_later_passes() -> void:
	var a := Vector2(500, 0)
	var state := _fresh({0: a})
	var tol := state.tolerance
	state.move_cluster(1, a + Vector2(1, 0))
	check(state.drop(1).joined, "pieces 0 and 1 rest together at a")
	# Placed without a drop: in reach of the pair, out of reach of where piece 4 lands.
	state.move_cluster(2, a - Vector2(0.7 * tol, 0))
	state.move_cluster(4, a + Vector2(0.7 * tol, 0))
	var result := state.drop(4)
	check(result.joined and not result.locked, "piece 4 joins the resting pair")
	check(result.root == 0, "the resting pair supplies the root")
	check(state.members(4) == PackedInt32Array([0, 1, 2, 4]), "the second pass picks up piece 2")
	for i in [0, 1, 2, 4]:
		check(state.offset_of(i) == a, "piece %d sits where the resting pair was" % i)


func _test_invalid_input_is_rejected() -> void:
	check(PuzzleState.tolerance_for(300, 200, 0) == PuzzleState.MIN_TOLERANCE, "no pieces gives the minimum tolerance")
	check(PuzzleState.tolerance_for(300, 200, -3) == PuzzleState.MIN_TOLERANCE, "a negative count gives the minimum tolerance")
	var short := PackedVector2Array([Vector2.ZERO])
	check(PuzzleState.new(cut, short, 22.0).piece_count() == 0, "offsets that do not match the pieces give an empty state")
	var shuffled := CutGenerator.generate_cut(300, 200, 6, CutGenerator.STYLE_GRID, 1)
	shuffled[2].id = 7
	var offsets := PackedVector2Array()
	offsets.resize(shuffled.size())
	check(PuzzleState.new(shuffled, offsets, 22.0).piece_count() == 0, "pieces whose ids are not their indices give an empty state")


func _test_larger_dropped_cluster_moves_onto_absorbed() -> void:
	var b := Vector2(900, 0)
	var state := _fresh({0: Vector2(500, 0), 2: b})
	state.move_cluster(1, Vector2(501, 0))
	check(state.drop(1).joined, "pieces 0 and 1 join")
	state.move_cluster(1, b + Vector2(5, 0))
	var result := state.drop(1)
	check(result.joined and not result.locked, "the pair joins piece 2")
	check(result.root == 0, "root comes from the larger dropped cluster")
	check(state.members(2) == PackedInt32Array([0, 1, 2]), "all three are one cluster")
	for i in 3:
		check(state.offset_of(i) == b, "piece %d takes the absorbed cluster's offset" % i)


# Pieces with their neighbour lists reversed or rotated must end in the same state.
func _test_neighbour_order_does_not_matter() -> void:
	var expected := _run_sequences(cut)
	for variant in 2:
		var reordered := CutGenerator.generate_cut(300, 200, 6, CutGenerator.STYLE_GRID, 1)
		for piece in reordered:
			var list := Array(piece.neighbours)
			if variant == 0:
				list.reverse()
			else:
				list.push_back(list.pop_front())
			piece.neighbours = PackedInt32Array(list)
		check(_run_sequences(reordered) == expected, "neighbour order variant %d gives the same state" % variant)


func _run_sequences(pieces: Array[CutPiece]) -> Array:
	var a := Vector2(500, 0)
	var snapshot: Array = []
	var multi := _state_for(pieces, {0: a, 2: a + Vector2(5, 0), 5: a + Vector2(3, 4), 4: Vector2(900, 0)})
	multi.move_cluster(1, a + Vector2(2, 2))
	multi.drop(1)
	multi.move_cluster(0, Vector2(1, 1))
	multi.drop(0)
	snapshot.append(_snapshot(multi))
	var chain := _state_for(pieces, {3: Vector2(700, 0)})
	_play(chain)
	snapshot.append(_snapshot(chain))
	return snapshot


func _state_for(pieces: Array[CutPiece], overrides: Dictionary) -> PuzzleState:
	var offsets := PackedVector2Array()
	for i in pieces.size():
		offsets.append(overrides.get(i, Vector2(1000 * (i + 1), 0)))
	return PuzzleState.new(pieces, offsets, _fixture_tolerance())


func _snapshot(state: PuzzleState) -> Array:
	var rows: Array = []
	for root in state.roots():
		rows.append([root, state.members(root), state.offset_of(root), state.is_locked(root)])
	return rows
