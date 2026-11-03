extends "res://tests/base_test.gd"

const LogCapture := preload("res://tests/log_capture.gd")

var cut: Array[CutPiece] = CutGenerator.generate_cut(300, 200, 6, CutGenerator.STYLE_GRID, 1)
var tolerance := PuzzleState.tolerance_for(300, 200, 6)


func _init() -> void:
	_test_clusters_of()
	_test_dict_shape()
	_test_json_round_trip_is_exact()
	_test_json_is_stable()
	_test_state_from()
	_test_rejects_bad_data()
	_test_loose_order_valid()
	_test_elapsed_is_kept_to_the_millisecond()
	_test_number_ranges()
	finish()


func _played() -> PuzzleState:
	var offsets := PackedVector2Array()
	for i in cut.size():
		offsets.append(Vector2(1000 * (i + 1), 0))
	var state := PuzzleState.new(cut, offsets, tolerance)
	state.move_cluster(4, Vector2(703, 0))
	state.drop(4)
	state.move_cluster(0, Vector2(701, 1))
	state.move_cluster(1, Vector2(702, 0))
	state.drop(1)
	state.move_cluster(5, Vector2(1, 1))
	state.drop(5)
	state.move_cluster(2, Vector2(-612.4567, 0.1))
	state.move_cluster(3, Vector2(1e-7, 3.3333333))
	return state


func _sample() -> SaveGame.Snapshot:
	var snapshot := SaveGame.Snapshot.new()
	snapshot.puzzle.image_id = "test-gradient"
	snapshot.puzzle.image_size = Vector2i(300, 200)
	snapshot.puzzle.style = "grid"
	snapshot.puzzle.piece_count = 6
	snapshot.puzzle.cut_seed = 1
	snapshot.clusters = SaveGame.clusters_of(_played())
	snapshot.loose_order = PackedInt32Array([3, 2, 0, 1, 4])
	snapshot.elapsed = 754.2166666666667
	snapshot.tidy_count = 2
	return snapshot


func _test_clusters_of() -> void:
	var state := _played()
	var clusters := SaveGame.clusters_of(state)
	var roots := PackedInt32Array()
	for c in clusters:
		roots.append(c.root)
	check(roots == state.roots(), "clusters_of lists the roots in ascending order")
	for c in clusters:
		check(c.pieces == state.members(c.root), "members of root %d" % c.root)
		check(c.offset == state.offset_of(c.root), "offset of root %d" % c.root)
		check(c.locked == state.is_locked(c.root), "lock of root %d" % c.root)


func _test_dict_shape() -> void:
	var d := SaveGame.to_dict(_sample())
	check(_sorted_keys(d) == ["clusters", "elapsed", "loose_order", "puzzle", "tidy_count", "version"], "top-level keys")
	check(_sorted_keys(d.puzzle) == ["height", "image_id", "piece_count", "seed", "style", "width"], "puzzle keys")
	var found_locked := false
	for c in d.clusters:
		check(_sorted_keys(c) == ["locked", "offset", "pieces", "root"], "cluster keys")
		if c.root == 5:
			found_locked = true
			check(c.locked == true and Vector2(c.offset[0], c.offset[1]) == Vector2.ZERO, "locked cluster sits at zero")
	check(found_locked, "the locked cluster is saved")
	check(d.version == 1, "version is 1")
	check(d.puzzle.seed == 1, "seed saved")
	check(d.puzzle.width == 300, "width saved")


func _sorted_keys(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys


func _test_json_round_trip_is_exact() -> void:
	var s := _sample()
	var text := SaveGame.to_json(s)
	var l := SaveGame.from_json(text)
	check(l.error == "", "round trip loads, error: %s" % l.error)
	if l.snapshot == null:
		return
	var p := l.snapshot.puzzle
	check(p.image_id == s.puzzle.image_id and p.image_size == s.puzzle.image_size and p.style == s.puzzle.style \
			and p.piece_count == s.puzzle.piece_count and p.cut_seed == s.puzzle.cut_seed, "puzzle fields round trip")
	check(l.snapshot.clusters.size() == s.clusters.size(), "cluster count round trips")
	if l.snapshot.clusters.size() == s.clusters.size():
		for i in s.clusters.size():
			var a := s.clusters[i]
			var b := l.snapshot.clusters[i]
			check(a.root == b.root and a.pieces == b.pieces and a.locked == b.locked, "cluster %d identity round trips" % i)
			check(a.offset == b.offset, "cluster %d offset is exact" % i)
	check(l.snapshot.loose_order == s.loose_order, "loose order round trips")
	check(l.snapshot.elapsed == roundf(s.elapsed * 1000.0) / 1000.0, "elapsed is kept to the millisecond")
	check(l.snapshot.tidy_count == s.tidy_count, "tidy count round trips")
	check(SaveGame.to_json(l.snapshot) == text, "re-encoding gives the same text")
	check(SaveGame.from_dict(SaveGame.to_dict(s)).error == "", "integers as int are accepted")


func _test_json_is_stable() -> void:
	var text := SaveGame.to_json(_sample())
	check(text == SaveGame.to_json(_sample()), "same snapshot gives the same text")
	for word in ["outline", "bounds", "home"]:
		check(not text.contains("\"%s\"" % word), "no %s in the file" % word)


func _test_state_from() -> void:
	var r := SaveGame.state_from(_sample().clusters, cut, tolerance)
	var expected := _played()
	check(r.piece_count() == 6, "restored state has 6 pieces")
	check(r.roots() == expected.roots(), "restored roots match")
	for root in expected.roots():
		check(r.members(root) == expected.members(root), "restored members of %d" % root)
		check(r.offset_of(root) == expected.offset_of(root), "restored offset of %d" % root)
		check(r.is_locked(root) == expected.is_locked(root), "restored lock of %d" % root)


func _test_rejects_bad_data() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var base := SaveGame.to_dict(_sample())
	var cases := {}
	cases["not a Dictionary"] = []
	var c := base.duplicate(true)
	c.version = 2
	cases["version 2"] = c
	c = base.duplicate(true)
	c.version = "1"
	cases["version string"] = c
	c = base.duplicate(true)
	c.erase("version")
	cases["version missing"] = c
	c = base.duplicate(true)
	c["outline"] = []
	cases["extra top-level key"] = c
	c = base.duplicate(true)
	c.erase("clusters")
	cases["clusters missing"] = c
	c = base.duplicate(true)
	c.puzzle.erase("seed")
	cases["seed missing"] = c
	c = base.duplicate(true)
	c.puzzle.seed = 1.5
	cases["seed 1.5"] = c
	c = base.duplicate(true)
	c.puzzle.style = "wild"
	cases["style wild"] = c
	c = base.duplicate(true)
	c.puzzle.style = 3
	cases["style number"] = c
	c = base.duplicate(true)
	c.puzzle.piece_count = 0
	cases["piece_count 0"] = c
	c = base.duplicate(true)
	c.puzzle.piece_count = 401
	cases["piece_count 401"] = c
	c = base.duplicate(true)
	c.puzzle.piece_count = 12.5
	cases["piece_count 12.5"] = c
	c = base.duplicate(true)
	c.puzzle.width = 0
	cases["width 0"] = c
	c = base.duplicate(true)
	c.puzzle.height = -1
	cases["height -1"] = c
	c = base.duplicate(true)
	c.puzzle.image_id = 5
	cases["image_id number"] = c
	c = base.duplicate(true)
	c.puzzle.image_id = ""
	cases["image_id empty"] = c
	c = base.duplicate(true)
	c.clusters = {}
	cases["clusters a Dictionary"] = c
	c = base.duplicate(true)
	c.clusters[0] = 7
	cases["cluster a number"] = c
	c = base.duplicate(true)
	c.clusters[0].erase("root")
	cases["cluster missing root"] = c
	c = base.duplicate(true)
	c.clusters[0]["home"] = [0, 0]
	cases["cluster extra key"] = c
	c = base.duplicate(true)
	c.clusters[0].pieces = [1.5]
	cases["pieces holding 1.5"] = c
	c = base.duplicate(true)
	c.clusters[0].pieces = "abc"
	cases["pieces a String"] = c
	c = base.duplicate(true)
	c.clusters[0].root = 1e300
	cases["root 1e300"] = c
	c = base.duplicate(true)
	c.clusters[0].offset = [1.0]
	cases["offset one element"] = c
	c = base.duplicate(true)
	c.clusters[0].offset = ["x", 0.0]
	cases["offset holding a String"] = c
	c = base.duplicate(true)
	c.clusters[0].offset = [INF, 0.0]
	cases["offset INF"] = c
	c = base.duplicate(true)
	c.clusters[0].offset = [NAN, 0.0]
	cases["offset NAN"] = c
	c = base.duplicate(true)
	c.clusters[0].locked = "yes"
	cases["locked a String"] = c
	c = base.duplicate(true)
	c.loose_order = ["3"]
	cases["loose_order holding a String"] = c
	c = base.duplicate(true)
	c.elapsed = -1
	cases["elapsed -1"] = c
	c = base.duplicate(true)
	c.elapsed = INF
	cases["elapsed INF"] = c
	c = base.duplicate(true)
	c.elapsed = 1.0e9 + 1.0
	cases["elapsed above 1e9"] = c
	c = base.duplicate(true)
	c.tidy_count = -1
	cases["tidy_count -1"] = c
	c = base.duplicate(true)
	c.tidy_count = 0.5
	cases["tidy_count 0.5"] = c
	for label in cases:
		var loaded := SaveGame.from_dict(cases[label])
		check(loaded.snapshot == null and loaded.error != "", "rejects: %s" % label)
	var at_limit := base.duplicate(true)
	at_limit.elapsed = SaveGame.MAX_ELAPSED
	check(SaveGame.from_dict(at_limit).snapshot != null, "accepts elapsed at the limit")
	var text := SaveGame.to_json(_sample())
	var texts := {"empty": "", "bad json": "{bad", "truncated": text.substr(0, text.length() >> 1),
			"array": "[]", "null": "null"}
	for label in texts:
		var loaded := SaveGame.from_json(texts[label])
		check(loaded.snapshot == null and loaded.error != "", "rejects text: %s" % label)
	OS.remove_logger(capture)
	check(capture.warnings.is_empty() and capture.errors.is_empty(), "bad saves are rejected silently")


func _test_loose_order_valid() -> void:
	var state := _played()
	var valid := [[3, 2, 0, 1, 4], [0, 1, 2, 3, 4]]
	var invalid := {"missing": [3, 2, 0, 1], "twice": [3, 2, 0, 1, 4, 4], "locked piece": [3, 2, 0, 1, 4, 5],
			"out of range": [3, 2, 0, 1, 6], "negative": [3, 2, 0, 1, -1]}
	for order in valid:
		check(SaveGame.loose_order_valid(PackedInt32Array(order), state), "valid order %s" % [order])
	for label in invalid:
		check(not SaveGame.loose_order_valid(PackedInt32Array(invalid[label]), state), "invalid order: %s" % label)


# Godot's number parser is not correctly rounded for long decimals, so the clock is stored as a
# short millisecond decimal, which parses back exactly.
func _test_elapsed_is_kept_to_the_millisecond() -> void:
	for x in [1234.5678901234567, 0.1 + 0.2, 86399.9995, 0.0, 754.2166666666667, 3.0e6 + 0.0004]:
		var s := _sample()
		s.elapsed = x
		var expected := roundf(x * 1000.0) / 1000.0
		var text := SaveGame.to_json(s)
		var l := SaveGame.from_json(text)
		check(l.snapshot != null and l.snapshot.elapsed == expected, "elapsed %s reads back as %s" % [x, expected])
		if l.snapshot != null:
			check(SaveGame.to_json(l.snapshot) == text, "elapsed %s re-encodes to the same text" % x)


func _test_number_ranges() -> void:
	var base := SaveGame.to_dict(_sample())
	var limit := int(SaveGame.MAX_EXACT_INT)
	var cases := {
		"seed 2^53": [_with_puzzle(base, "seed", limit), true],
		"seed 2^53 + 2": [_with_puzzle(base, "seed", limit + 2), false],
		"seed -2^53": [_with_puzzle(base, "seed", -limit), true],
		"piece_count 1": [_with_puzzle(base, "piece_count", 1), true],
		"piece_count 400": [_with_puzzle(base, "piece_count", 400), true],
		"piece_count 401": [_with_puzzle(base, "piece_count", 401), false],
		"piece id 2^32 + 3": [_with_piece(base, (1 << 32) + 3), false],
		"piece id 2^31 - 1": [_with_piece(base, (1 << 31) - 1), true],
		"loose_order 2^32 + 3": [_with_loose(base, (1 << 32) + 3), false],
		"offset 1e300": [_with_offset(base, 1e300), false],
	}
	for label in cases:
		var data: Dictionary = cases[label][0]
		var want: bool = cases[label][1]
		# Through text, as a real file arrives: every number is a float there.
		var loaded := SaveGame.from_json(JSON.stringify(data))
		check((loaded.snapshot != null) == want and (loaded.error == "") == want, "%s through text, error: %s" % [label, loaded.error])
	# A native int above 2^53 is rejected too, not only the floats text gives.
	check(SaveGame.from_dict(_with_puzzle(base, "seed", limit + 1)).snapshot == null, "native seed 2^53 + 1 is rejected")


func _with_puzzle(base: Dictionary, key: String, value: Variant) -> Dictionary:
	var d := base.duplicate(true)
	d.puzzle[key] = value
	return d


func _with_piece(base: Dictionary, value: int) -> Dictionary:
	var d := base.duplicate(true)
	d.clusters[0].pieces = [value]
	return d


func _with_loose(base: Dictionary, value: int) -> Dictionary:
	var d := base.duplicate(true)
	d.loose_order = [value]
	return d


func _with_offset(base: Dictionary, value: float) -> Dictionary:
	var d := base.duplicate(true)
	d.clusters[0].offset = [value, 0.0]
	return d
