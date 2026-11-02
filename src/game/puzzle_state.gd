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
		_offsets[root] = Vector2.ZERO
		_locked[root] = 1
		_locked_pieces += _members[root].size()
		result.locked = true
	return result
