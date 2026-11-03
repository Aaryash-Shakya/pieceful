class_name PuzzleState
extends RefCounted
## Which pieces are joined into clusters, where each loose cluster sits, and which are locked.
## Pure logic with no nodes, so the board can drive it and a later save can read it.
## A cluster's offset is the displacement of all its pieces from their home positions.

const TOLERANCE_FRACTION := 0.22
const MIN_TOLERANCE := 10.0


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


func _init(pieces: Array[CutPiece], offsets: PackedVector2Array, tolerance_value: float) -> void:
	_pieces = pieces
	tolerance = tolerance_value
	_offsets = offsets.duplicate()
	var count := pieces.size()
	_parents.resize(count)
	_locked.resize(count)
	_members.resize(count)
	for i in count:
		_parents[i] = i
		_members[i] = PackedInt32Array([i])


## Snap distance in pixels: a fraction of the cell size, never below a thumb-friendly minimum.
static func tolerance_for(width: int, height: int, piece_count: int) -> float:
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


func is_complete() -> bool:
	return _locked_pieces == _parents.size()


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
	while true:
		var absorbed := _absorbable_roots(root)
		if absorbed.is_empty():
			break
		root = _merge(root, absorbed)
		result.joined = true
	result.root = root
	if result.joined and _offsets[root].length() <= tolerance:
		_lock(root)
		result.locked = true
	return result


# Joins the absorbed clusters into root's and returns the new root. Both picks scan every
# candidate and break ties by id, so neither depends on the order neighbours were visited in.
func _merge(root: int, absorbed: Array[int]) -> int:
	var joining := absorbed.duplicate()
	joining.append(root)
	var new_root := _largest(joining)
	var target := _offsets[_largest(absorbed)]
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
				if seen.has(r) or _locked[r] == 1:
					continue
				if _offsets[r].distance_to(dropped) <= tolerance:
					seen[r] = true
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
