class_name SaveGame
extends RefCounted
## The save file as JSON text and back. Only what cannot be regenerated is stored: which image,
## style, count and seed make the cut, plus where the clusters are. Never any piece geometry.
## The file is untrusted input, so from_dict checks every key and type before using a value.

# 2 added puzzle.cut_checksum. The board sets aside a save whose cut no longer matches it, so a
# deliberate change to a golden cut checksum (tests/test_cut_generator.gd) loses no data, only that game.
# 3 added slots: four stacks of cluster roots, left out of loose_order.
# 4 added puzzle.ghost, the ghost-image overlay setting the result card reports.
const VERSION := 4
const MAX_PIECE_COUNT := 400
## About 31 years of play, far beyond any real game. A file claiming more is rejected rather than
## loaded, so the clock stays well inside the range the millisecond rounding keeps exact.
const MAX_ELAPSED := 1.0e9
## 2^53, the largest integer a JSON number holds exactly.
const MAX_EXACT_INT := 9007199254740992.0


class Puzzle:
	var image_id := ""
	var image_size := Vector2i.ZERO
	var style := ""
	var piece_count := 0
	var cut_seed := 0
	## CutGenerator.checksum of the cut these fields make, taken when the cut was generated.
	var cut_checksum := 0
	## The faint picture over the board. On by default, as the owner specified.
	var ghost := true

	func copy() -> Puzzle:
		var p := Puzzle.new()
		p.image_id = image_id
		p.image_size = image_size
		p.style = style
		p.piece_count = piece_count
		p.cut_seed = cut_seed
		p.cut_checksum = cut_checksum
		p.ghost = ghost
		return p


class Cluster:
	var root := -1
	var pieces := PackedInt32Array()
	var offset := Vector2.ZERO
	var locked := false


class Snapshot:
	var puzzle := Puzzle.new()
	var clusters: Array[Cluster] = []
	var loose_order := PackedInt32Array()
	## Four stacks of cluster roots, bottom first.
	var slots: Array[PackedInt32Array] = []
	var elapsed := 0.0
	var tidy_count := 0


## Exactly one of the two is set.
class Loaded:
	var snapshot: Snapshot = null
	var error := ""


static func to_dict(snapshot: Snapshot) -> Dictionary:
	var clusters := []
	for c in snapshot.clusters:
		clusters.append({
			"root": c.root,
			"pieces": Array(c.pieces),
			"offset": [c.offset.x, c.offset.y],
			"locked": c.locked,
		})
	var slot_lists := []
	for s in PuzzleState.SLOT_COUNT:
		slot_lists.append(Array(snapshot.slots[s]) if s < snapshot.slots.size() else [])
	return {
		"version": VERSION,
		"puzzle": {
			"image_id": snapshot.puzzle.image_id,
			"width": snapshot.puzzle.image_size.x,
			"height": snapshot.puzzle.image_size.y,
			"style": snapshot.puzzle.style,
			"piece_count": snapshot.puzzle.piece_count,
			"seed": snapshot.puzzle.cut_seed,
			"cut_checksum": snapshot.puzzle.cut_checksum,
			"ghost": snapshot.puzzle.ghost,
		},
		"clusters": clusters,
		"loose_order": Array(snapshot.loose_order),
		"slots": slot_lists,
		"elapsed": roundf(snapshot.elapsed * 1000.0) / 1000.0,
		"tidy_count": snapshot.tidy_count,
	}


# Full precision keeps the float32 offsets exact. Godot's number parser is not correctly rounded
# for long decimals, so the clock is kept to the millisecond, a short decimal that reads back exactly.
static func to_json(snapshot: Snapshot) -> String:
	return JSON.stringify(to_dict(snapshot), "\t", true, true)


static func from_json(text: String) -> Loaded:
	var json := JSON.new()
	var status := json.parse(text)
	if status != OK:
		return _fail("not valid JSON: %s (line %d)" % [json.get_error_message(), json.get_error_line()])
	return from_dict(json.data)


static func from_dict(data: Variant) -> Loaded:
	if not data is Dictionary:
		return _fail("save is not an object")
	var root: Dictionary = data
	if not _has_exactly(root, ["version", "puzzle", "clusters", "loose_order", "slots", "elapsed", "tidy_count"]):
		return _fail("save has missing or unknown keys")
	if not is_int(root.version) or int(root.version) != VERSION:
		return _fail("version")
	if not root.puzzle is Dictionary:
		return _fail("puzzle")
	var puzzle_data: Dictionary = root.puzzle
	if not _has_exactly(puzzle_data, ["image_id", "width", "height", "style", "piece_count", "seed", "cut_checksum", "ghost"]):
		return _fail("puzzle has missing or unknown keys")
	if not puzzle_data.ghost is bool:
		return _fail("puzzle.ghost")
	if not puzzle_data.image_id is String or (puzzle_data.image_id as String).is_empty():
		return _fail("puzzle.image_id")
	if not puzzle_data.style is String or not CutGenerator.STYLES.has(puzzle_data.style):
		return _fail("puzzle.style")
	if not is_int(puzzle_data.piece_count) or int(puzzle_data.piece_count) < 1 \
			or int(puzzle_data.piece_count) > MAX_PIECE_COUNT:
		return _fail("puzzle.piece_count")
	if not is_int(puzzle_data.width) or int(puzzle_data.width) < 1:
		return _fail("puzzle.width")
	if not is_int(puzzle_data.height) or int(puzzle_data.height) < 1:
		return _fail("puzzle.height")
	if not is_int(puzzle_data.seed):
		return _fail("puzzle.seed")
	if not is_int(puzzle_data.cut_checksum) or int(puzzle_data.cut_checksum) < 0 \
			or int(puzzle_data.cut_checksum) > SeededRng.MASK:
		return _fail("puzzle.cut_checksum")
	if not root.clusters is Array:
		return _fail("clusters")
	if not root.loose_order is Array:
		return _fail("loose_order")
	if not _is_number(root.elapsed) or float(root.elapsed) < 0.0 or float(root.elapsed) > MAX_ELAPSED:
		return _fail("elapsed")
	if not is_int(root.tidy_count) or int(root.tidy_count) < 0:
		return _fail("tidy_count")

	var snapshot := Snapshot.new()
	snapshot.puzzle.image_id = puzzle_data.image_id
	snapshot.puzzle.image_size = Vector2i(int(puzzle_data.width), int(puzzle_data.height))
	snapshot.puzzle.style = puzzle_data.style
	snapshot.puzzle.piece_count = int(puzzle_data.piece_count)
	snapshot.puzzle.cut_seed = int(puzzle_data.seed)
	snapshot.puzzle.cut_checksum = int(puzzle_data.cut_checksum)
	snapshot.puzzle.ghost = puzzle_data.ghost
	snapshot.elapsed = float(root.elapsed)
	snapshot.tidy_count = int(root.tidy_count)

	for i in (root.clusters as Array).size():
		var entry: Variant = root.clusters[i]
		if not entry is Dictionary:
			return _fail("clusters[%d]" % i)
		var cluster_data: Dictionary = entry
		if not _has_exactly(cluster_data, ["root", "pieces", "offset", "locked"]):
			return _fail("clusters[%d] has missing or unknown keys" % i)
		if not is_int(cluster_data.root):
			return _fail("clusters[%d].root" % i)
		var ids: Variant = _int_array(cluster_data.pieces)
		if ids == null:
			return _fail("clusters[%d].pieces" % i)
		if not cluster_data.offset is Array or (cluster_data.offset as Array).size() != 2 \
				or not _is_number(cluster_data.offset[0]) or not _is_number(cluster_data.offset[1]):
			return _fail("clusters[%d].offset" % i)
		if not cluster_data.locked is bool:
			return _fail("clusters[%d].locked" % i)
		var cluster := Cluster.new()
		cluster.root = int(cluster_data.root)
		cluster.pieces = ids
		cluster.offset = Vector2(float(cluster_data.offset[0]), float(cluster_data.offset[1]))
		# A finite double above float32's range becomes INF here.
		if not cluster.offset.is_finite():
			return _fail("clusters[%d].offset" % i)
		cluster.locked = cluster_data.locked
		snapshot.clusters.append(cluster)

	var order: Variant = _int_array(root.loose_order)
	if order == null:
		return _fail("loose_order")
	snapshot.loose_order = order

	if not root.slots is Array or (root.slots as Array).size() != PuzzleState.SLOT_COUNT:
		return _fail("slots")
	for i in PuzzleState.SLOT_COUNT:
		var stack: Variant = _int_array(root.slots[i])
		if stack == null:
			return _fail("slots[%d]" % i)
		snapshot.slots.append(stack)

	var loaded := Loaded.new()
	loaded.snapshot = snapshot
	return loaded


static func clusters_of(state: PuzzleState) -> Array[Cluster]:
	var result: Array[Cluster] = []
	for root in state.roots():
		var cluster := Cluster.new()
		cluster.root = root
		cluster.pieces = state.members(root)
		cluster.offset = state.offset_of(root)
		cluster.locked = state.is_locked(root)
		result.append(cluster)
	return result


static func state_from(clusters: Array[Cluster], pieces: Array[CutPiece], tolerance: float,
		slots: Array[PackedInt32Array] = []) -> PuzzleState:
	var roots := PackedInt32Array()
	var groups: Array[PackedInt32Array] = []
	var offsets := PackedVector2Array()
	var locked := PackedByteArray()
	for c in clusters:
		roots.append(c.root)
		groups.append(c.pieces)
		offsets.append(c.offset)
		locked.append(1 if c.locked else 0)
	return PuzzleState.restored(pieces, tolerance, roots, groups, offsets, locked, slots)


static func slots_of(state: PuzzleState) -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	for s in PuzzleState.SLOT_COUNT:
		result.append(state.slot_roots(s))
	return result


## True when the order lists every table piece of the state exactly once and nothing else.
## Locked pieces and pieces in a slot are not on the table.
static func loose_order_valid(order: PackedInt32Array, state: PuzzleState) -> bool:
	var count := state.piece_count()
	var seen := PackedByteArray()
	seen.resize(count)
	seen.fill(0)
	for id in order:
		if id < 0 or id >= count or seen[id] == 1 or state.is_locked(id) or state.slot_of(id) != -1:
			return false
		seen[id] = 1
	for id in count:
		if seen[id] == 0 and not state.is_locked(id) and state.slot_of(id) == -1:
			return false
	return true


static func _fail(message: String) -> Loaded:
	var loaded := Loaded.new()
	loaded.error = message
	return loaded


static func _has_exactly(data: Dictionary, keys: Array) -> bool:
	if data.size() != keys.size():
		return false
	for key in keys:
		if not data.has(key):
			return false
	return true


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


# Godot's JSON reader returns every number as a float, so a whole float counts as an integer.
# Native ints are held to the same 2^53 limit, so a value never changes when it goes through text.
static func is_int(value: Variant) -> bool:
	if value is int:
		return absi(value) <= int(MAX_EXACT_INT)
	return value is float and is_finite(value) and value == floorf(value) and absf(value) <= MAX_EXACT_INT


# Null when the value is not an Array of integers that fit a PackedInt32Array, which would
# otherwise wrap a huge id onto a valid one.
static func _int_array(value: Variant) -> Variant:
	if not value is Array:
		return null
	var result := PackedInt32Array()
	for item in value:
		if not is_int(item) or absf(float(item)) > 2147483647.0:
			return null
		result.append(int(item))
	return result
