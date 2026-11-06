class_name PuzzleState
extends RefCounted
## Which pieces are joined into clusters, where each loose cluster sits, and which are locked.
## Pure logic with no nodes, so the board can drive it and a later save can read it.
## A cluster's offset is the displacement of all its pieces from their home positions.

const TOLERANCE_FRACTION := 0.22
const MIN_TOLERANCE := 10.0
const SLOT_COUNT := 4


class DropResult:
	var root := -1
	var joined := false
	var locked := false


var tolerance: float

var _pieces: Array[CutPiece]
var _parents := PackedInt32Array()
# Offsets, member lists and lock flags are only meaningful at a cluster's root.
var _offsets := PackedVector2Array()
var _members: Array[PackedInt32Array] = []
var _locked := PackedByteArray()
var _locked_pieces := 0
# Slot index by root, -1 when loose on the table. A slotted cluster never joins or locks.
var _slot_of := PackedInt32Array()
var _slots: Array[PackedInt32Array] = []


# Invalid input gives an empty state, so nothing indexes past the offsets or by a wrong id.
func _init(pieces: Array[CutPiece], offsets: PackedVector2Array, tolerance_value: float) -> void:
	tolerance = tolerance_value
	if offsets.size() != pieces.size():
		push_error("PuzzleState: %d offsets for %d pieces" % [offsets.size(), pieces.size()])
		return
	for i in pieces.size():
		if pieces[i].id != i:
			push_error("PuzzleState: piece at index %d has id %d" % [i, pieces[i].id])
			return
	_pieces = pieces
	_offsets = offsets.duplicate()
	var count := pieces.size()
	_parents.resize(count)
	_locked.resize(count)
	_locked.fill(0)
	_members.resize(count)
	_slot_of.resize(count)
	_slot_of.fill(-1)
	_slots.resize(SLOT_COUNT)
	for i in count:
		_parents[i] = i
		_members[i] = PackedInt32Array([i])


## Rebuilds a state from saved clusters: entry k of the four arrays is one cluster's root, member
## ids, offset and lock flag. The input comes from a file, so anything inconsistent gives the
## empty state without logging; pieces with bad ids still reach _init's error.
static func restored(pieces: Array[CutPiece], tolerance_value: float, roots: PackedInt32Array,
		groups: Array[PackedInt32Array], offsets: PackedVector2Array, locked: PackedByteArray,
		slots: Array[PackedInt32Array] = []) -> PuzzleState:
	var empty_pieces: Array[CutPiece] = []
	var empty := PuzzleState.new(empty_pieces, PackedVector2Array(), tolerance_value)
	var count := pieces.size()
	if roots.size() != groups.size() or offsets.size() != groups.size() or locked.size() != groups.size():
		return empty
	var seen := PackedByteArray()
	seen.resize(count)
	seen.fill(0)
	var placed := 0
	for k in groups.size():
		var group := groups[k]
		if group.is_empty() or not group.has(roots[k]) or locked[k] > 1:
			return empty
		# A non-finite offset can never join or lock, so the puzzle could not be finished.
		if not offsets[k].is_finite():
			return empty
		if locked[k] == 1 and offsets[k] != Vector2.ZERO:
			return empty
		for id in group:
			if id < 0 or id >= count or seen[id] == 1:
				return empty
			seen[id] = 1
		placed += group.size()
	if placed != count:
		return empty
	var zeros := PackedVector2Array()
	zeros.resize(count)
	var state := PuzzleState.new(pieces, zeros, tolerance_value)
	if state.piece_count() != count:
		return empty
	for k in groups.size():
		var sorted_group := groups[k].duplicate()
		sorted_group.sort()
		var root := roots[k]
		for id in sorted_group:
			state._parents[id] = root
			state._members[id] = PackedInt32Array()
		state._members[root] = sorted_group
		# A locked offset is exactly zero, so a -0.0 from the file is not kept.
		state._offsets[root] = Vector2.ZERO if locked[k] == 1 else offsets[k]
		state._locked[root] = locked[k]
		if locked[k] == 1:
			state._locked_pieces += sorted_group.size()
	if not slots.is_empty():
		if slots.size() != SLOT_COUNT:
			return empty
		for s in SLOT_COUNT:
			for root in slots[s]:
				if root < 0 or root >= count or state._parents[root] != root \
						or state._locked[root] == 1 or state._slot_of[root] != -1:
					return empty
				state._slot_of[root] = s
				state._slots[s].append(root)
	return state


## Snap distance in pixels: a fraction of the cell size, never below a thumb-friendly minimum.
static func tolerance_for(width: int, height: int, piece_count: int) -> float:
	if piece_count <= 0:
		push_error("PuzzleState.tolerance_for: piece_count must be at least 1, got %d" % piece_count)
		return MIN_TOLERANCE
	return maxf(MIN_TOLERANCE, TOLERANCE_FRACTION * sqrt(float(width) * height / piece_count))


func piece_count() -> int:
	return _parents.size()


func find(piece: int) -> int:
	var node := piece
	while _parents[node] != node:
		_parents[node] = _parents[_parents[node]]
		node = _parents[node]
	return node


## Ids of the piece's cluster, ascending.
func members(piece: int) -> PackedInt32Array:
	return _members[find(piece)].duplicate()


func roots() -> PackedInt32Array:
	var result := PackedInt32Array()
	for i in _parents.size():
		if _parents[i] == i:
			result.append(i)
	return result


func offset_of(piece: int) -> Vector2:
	return _offsets[find(piece)]


func is_locked(piece: int) -> bool:
	return _locked[find(piece)] == 1


func locked_piece_count() -> int:
	return _locked_pieces


func is_complete() -> bool:
	return _locked_pieces == _parents.size()


## The slot holding the piece's cluster, or -1.
func slot_of(piece: int) -> int:
	return _slot_of[find(piece)]


## Cluster roots in a slot, bottom of the stack first.
func slot_roots(slot: int) -> PackedInt32Array:
	return _slots[slot].duplicate()


func slot_piece_count(slot: int) -> int:
	var total := 0
	for root in _slots[slot]:
		total += _members[root].size()
	return total


## False when the cluster is locked, already in a slot, or the slot does not exist.
func put_in_slot(piece: int, slot: int) -> bool:
	var root := find(piece)
	if slot < 0 or slot >= SLOT_COUNT or _locked[root] == 1 or _slot_of[root] != -1:
		return false
	_slot_of[root] = slot
	_slots[slot].append(root)
	return true


## Empties a slot and returns the roots it held, bottom first.
func take_slot(slot: int) -> PackedInt32Array:
	var taken := _slots[slot]
	_slots[slot] = PackedInt32Array()
	for root in taken:
		_slot_of[root] = -1
	return taken


func move_cluster(piece: int, offset: Vector2) -> void:
	var root := find(piece)
	if _locked[root] == 0:
		_offsets[root] = offset


func drop(piece: int) -> DropResult:
	var result := DropResult.new()
	var root := find(piece)
	result.root = root
	if _locked[root] == 1:
		return result
	if _offsets[root].length() <= tolerance:
		_lock(root)
		result.locked = true
		return result
	# The merged cluster moves, so a neighbour out of reach of the drop point can be in reach
	# of the new offset. Each pass starts from the merged cluster, so the result stays
	# deterministic; the loop ends because every pass removes at least one cluster.
	var first_pass := true
	while true:
		var absorbed := _absorbable_roots(root)
		if absorbed.is_empty():
			break
		var before := _offsets[root]
		root = _merge(root, absorbed, first_pass)
		result.joined = true
		first_pass = false
		# Each spread is complete for the offset it measured against, so another pass can
		# only find something if the merged cluster moved.
		if _offsets[root] == before:
			break
	result.root = root
	if result.joined and _offsets[root].length() <= tolerance:
		_lock(root)
		result.locked = true
	return result


# Joins the absorbed clusters into root's and returns the new root. Both picks scan every
# candidate and break ties by id, so neither depends on the order neighbours were visited in.
# On the first pass the dropped cluster snaps onto what it was dropped against. Later passes
# start from a cluster already resting there, so it keeps its place unless something bigger joins.
func _merge(root: int, absorbed: Array[int], first_pass: bool) -> int:
	var joining := absorbed.duplicate()
	joining.append(root)
	var new_root := _largest(joining)
	var target := _offsets[_largest(absorbed if first_pass else joining)]
	var merged := PackedInt32Array()
	for r in joining:
		merged.append_array(_members[r])
		if r != new_root:
			_parents[r] = new_root
			_members[r] = PackedInt32Array()
	merged.sort()
	_members[new_root] = merged
	_offsets[new_root] = target
	return new_root


func _lock(root: int) -> void:
	_offsets[root] = Vector2.ZERO
	_locked[root] = 1
	_locked_pieces += _members[root].size()


# Loose clusters reachable from the dropped cluster through neighbouring pieces whose
# offset is within tolerance of the starting cluster's offset. Measuring against that
# offset, not the neighbour's, makes the result a fixed point independent of visit order.
func _absorbable_roots(root: int) -> Array[int]:
	var dropped := _offsets[root]
	var seen := {root: true}
	var absorbed: Array[int] = []
	var pending: Array[int] = [root]
	while not pending.is_empty():
		var current: int = pending.pop_back()
		for piece in _members[current]:
			for q in _pieces[piece].neighbours:
				var r := find(q)
				if seen.has(r):
					continue
				# Offsets do not change during a pass, so a rejected root stays rejected
				# and is recorded too, never measured twice.
				seen[r] = true
				if _locked[r] == 0 and _slot_of[r] == -1 and _offsets[r].distance_to(dropped) <= tolerance:
					absorbed.append(r)
					pending.append(r)
	return absorbed


# The root with the most pieces; ties go to the lowest root id.
func _largest(roots_to_scan: Array[int]) -> int:
	var best := -1
	for r in roots_to_scan:
		if best == -1 or _members[r].size() > _members[best].size() \
				or (_members[r].size() == _members[best].size() and r < best):
			best = r
	return best
