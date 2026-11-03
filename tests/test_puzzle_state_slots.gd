extends "res://tests/base_test.gd"

var cut: Array[CutPiece] = CutGenerator.generate_cut(300, 200, 6, CutGenerator.STYLE_GRID, 1)


func _init() -> void:
	_test_put_and_take()
	_test_refuses_locked_and_repeats()
	_test_slotted_never_joins()
	_test_restore_with_slots()
	_test_restore_rejects_bad_slots()
	finish()


func _fresh(overrides: Dictionary = {}) -> PuzzleState:
	var offsets := PackedVector2Array()
	for i in cut.size():
		offsets.append(overrides.get(i, Vector2(1000 * (i + 1), 0)))
	return PuzzleState.new(cut, offsets, PuzzleState.tolerance_for(300, 200, 6))


func _singletons(locked_first := false) -> Array:
	var roots := PackedInt32Array()
	var groups: Array[PackedInt32Array] = []
	var offsets := PackedVector2Array()
	var locked := PackedByteArray()
	for i in 6:
		roots.append(i)
		groups.append(PackedInt32Array([i]))
		var is_locked := locked_first and i == 0
		offsets.append(Vector2.ZERO if is_locked else Vector2(1000, 0))
		locked.append(1 if is_locked else 0)
	return [roots, groups, offsets, locked]


func _test_put_and_take() -> void:
	var s := _fresh()
	check(s.slot_of(2) == -1, "a loose piece has no slot")
	check(s.put_in_slot(2, 1), "a loose piece goes into slot 1")
	check(s.put_in_slot(4, 1), "a second goes into the same slot")
	check(s.slot_of(2) == 1 and s.slot_of(4) == 1, "both report slot 1")
	check(s.slot_roots(1) == PackedInt32Array([2, 4]), "the stack keeps its order")
	check(s.slot_piece_count(1) == 2, "the count is pieces")
	check(s.slot_roots(0).is_empty() and s.slot_piece_count(0) == 0, "other slots stay empty")
	var taken := s.take_slot(1)
	check(taken == PackedInt32Array([2, 4]), "take returns the whole stack in order")
	check(s.slot_of(2) == -1 and s.slot_roots(1).is_empty(), "taking empties the slot")


func _test_refuses_locked_and_repeats() -> void:
	var s := _fresh({0: Vector2.ZERO})
	s.drop(0)
	check(s.is_locked(0), "fixture: piece 0 locked")
	check(not s.put_in_slot(0, 0), "a locked cluster cannot be slotted")
	check(s.put_in_slot(1, 0), "slot a loose piece")
	check(not s.put_in_slot(1, 2), "a slotted cluster cannot be slotted again")
	check(not s.put_in_slot(3, 4), "no such slot")
	check(not s.put_in_slot(3, -1), "negative slot")


func _test_slotted_never_joins() -> void:
	var s := _fresh({0: Vector2(500, 500), 1: Vector2(500, 500)})
	s.put_in_slot(1, 0)
	var result := s.drop(0)
	check(not result.joined, "a neighbour in a slot is not joined")
	check(s.members(0).size() == 1, "the dropped cluster stays alone")


func _test_restore_with_slots() -> void:
	var a := _singletons()
	var slots: Array[PackedInt32Array] = [PackedInt32Array([3]), PackedInt32Array(), PackedInt32Array([1, 5]), PackedInt32Array()]
	var r := PuzzleState.restored(cut, PuzzleState.tolerance_for(300, 200, 6), a[0], a[1], a[2], a[3], slots)
	check(r.piece_count() == 6, "restored with slots")
	check(r.slot_roots(2) == PackedInt32Array([1, 5]) and r.slot_of(3) == 0, "slots come back in order")


func _test_restore_rejects_bad_slots() -> void:
	var a := _singletons(true)
	var tol := PuzzleState.tolerance_for(300, 200, 6)
	var none := PackedInt32Array()
	var cases := {
		"locked": [PackedInt32Array([0]), none, none, none],
		"duplicate": [PackedInt32Array([1]), PackedInt32Array([1]), none, none],
		"out of range": [PackedInt32Array([9]), none, none, none],
		"three slots": [none, none, none],
	}
	for case_name in cases:
		var slots: Array[PackedInt32Array] = []
		for entry in cases[case_name]:
			slots.append(entry)
		var r := PuzzleState.restored(cut, tol, a[0], a[1], a[2], a[3], slots)
		check(r.piece_count() == 0, "restore rejects a %s slot" % case_name)
