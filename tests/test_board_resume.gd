extends "res://tests/board_test.gd"

const LogCapture := preload("res://tests/log_capture.gd")

var _fresh_offsets: PackedVector2Array
var _good: Dictionary
var _text_a := ""


func _init() -> void:
	await process_frame
	_test_round_trip()
	_test_resave_is_identical()
	_test_plays_on()
	_test_tidy_mid_animation()
	_test_other_identity()
	_test_sizes_follow_the_puzzle()
	_test_missing_file_starts_fresh()

	var bad_cases := {}
	bad_cases["corrupt"] = "{not json"
	bad_cases["empty"] = ""
	var good_text := JSON.stringify(_good, "\t", true, true)
	bad_cases["truncated"] = good_text.substr(0, good_text.length() / 2)
	bad_cases["array"] = "[]"
	var c := _good.duplicate(true)
	c.version = SaveGame.VERSION - 1
	bad_cases["older version"] = _text(c)
	c = _good.duplicate(true)
	c.version = SaveGame.VERSION + 1
	bad_cases["newer version"] = _text(c)
	c = _good.duplicate(true)
	c.puzzle.cut_checksum = (int(c.puzzle.cut_checksum) + 1) % 4294967296
	bad_cases["cut drift"] = _text(c)
	c = _good.duplicate(true)
	c.clusters[0].offset = [1.0e30, 0.0]
	bad_cases["far offset"] = _text(c)
	c = _good.duplicate(true)
	c.clusters[0].offset = [0.0, -8.0 * Board.IMAGE_SIZE.x - 1.0]
	bad_cases["offset just past the limit"] = _text(c)
	c = _good.duplicate(true)
	c.erase("loose_order")
	bad_cases["missing key"] = _text(c)
	c = _good.duplicate(true)
	c.puzzle.style = "wild"
	bad_cases["unknown style"] = _text(c)
	c = _good.duplicate(true)
	c.puzzle.image_id = "cats-01"
	bad_cases["unknown image"] = _text(c)
	c = _good.duplicate(true)
	c.puzzle.width = 2048
	bad_cases["wrong size"] = _text(c)
	c = _good.duplicate(true)
	c.puzzle.piece_count = 54
	bad_cases["wrong count"] = _text(c)
	c = _good.duplicate(true)
	c.clusters[1].pieces.append(c.clusters[0].pieces[0])
	bad_cases["piece in two clusters"] = _text(c)
	c = _good.duplicate(true)
	c.clusters.pop_back()
	bad_cases["piece in no cluster"] = _text(c)
	c = _good.duplicate(true)
	c.clusters[0].locked = true
	c.clusters[0].offset = [3.0, 0.0]
	bad_cases["locked with an offset"] = _text(c)
	c = _good.duplicate(true)
	for cluster: Dictionary in c.clusters:
		cluster.locked = true
		cluster.offset = [0.0, 0.0]
	c.loose_order = []
	bad_cases["complete"] = _text(c)
	c = _good.duplicate(true)
	c.loose_order.append(c.loose_order[0])
	bad_cases["bad draw order"] = _text(c)
	for label: String in bad_cases:
		_test_bad_file(label, bad_cases[label])
	_test_unreadable_file()

	board.free()
	finish()


func _text(data: Dictionary) -> String:
	return JSON.stringify(data, "\t", true, true)


# Resumes from TEST_SAVE_PATH with a logger attached, and returns what it caught.
func _resume() -> LogCapture:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	make_board(false)
	OS.remove_logger(capture)
	return capture


func _quiet(capture: LogCapture, label: String) -> void:
	check(capture.warnings.is_empty() and capture.errors.is_empty(),
			"%s: no warning or error (%s %s)" % [label, capture.warnings, capture.errors])


func _record() -> Dictionary:
	var s := board.state
	var clusters := {}
	for r in s.roots():
		clusters[r] = {"members": s.members(r), "offset": s.offset_of(r), "locked": s.is_locked(r)}
	var positions := PackedVector2Array()
	for id in s.piece_count():
		positions.append(board.node_for(id).position)
	var loose := PackedInt32Array()
	for child in board.pieces.get_children():
		loose.append((child as PieceNode).piece_id)
	var locked_layer := PackedInt32Array()
	for child in board.locked_pieces.get_children():
		locked_layer.append((child as PieceNode).piece_id)
	locked_layer.sort()
	return {
		"roots": s.roots(),
		"clusters": clusters,
		"positions": positions,
		"loose": loose,
		"locked_layer": locked_layer,
		"elapsed": board.elapsed,
		"tidy_count": board._cleanup_count,
		"bounds": board._bounds,
	}


func _first_loose_singleton(used: PackedInt32Array) -> PieceNode:
	for i in board.state.piece_count():
		if not used.has(i) and _is_loose_singleton(i) and _grab_point(board.node_for(i)) != Vector2.INF:
			return board.node_for(i)
	check(false, "found a loose singleton")
	return null


func _saved_cluster_of(piece: int) -> Dictionary:
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))
	for cluster: Dictionary in saved.clusters:
		if (cluster.pieces as Array).has(float(piece)):
			return cluster
	return {}


func _test_round_trip() -> void:
	make_board()
	_show_everything()
	_fresh_offsets = Scatter.scatter(board.cut, Vector2(Board.IMAGE_SIZE), Board.LOOSE_MARGIN, Board.SEED)
	var used := PackedInt32Array()
	var pair := _loose_pair(used)
	used.append(pair.x)
	used.append(pair.y)
	_move_by_touch(board.node_for(pair.x), board.node_for(pair.y).position)
	check(board.state.find(pair.x) == board.state.find(pair.y), "the setup joins a pair")
	var locked := _first_loose_singleton(used)
	used.append(locked.piece_id)
	_move_by_touch(locked, Vector2.ZERO)
	check(board.state.is_locked(locked.piece_id), "the setup locks a piece")
	var lifted := _first_loose_singleton(used)
	_move_by_touch(lifted, lifted.position + Vector2(30, 0))
	check(board.pieces.get_child(board.pieces.get_child_count() - 1) == lifted, "the lifted piece is on top")
	board.cleanup()
	board._finish_cleanup()
	board._process(0.2)
	board._process(0.17)

	var a := _record()
	board.save_game()
	_text_a = FileAccess.get_file_as_string(TEST_SAVE_PATH)
	board.free()
	_quiet(_resume(), "resume")
	var b := _record()

	check(b.roots == a.roots, "the same roots come back")
	var clusters_match := true
	for r in a.roots:
		var ca: Dictionary = a.clusters[r]
		var cb: Dictionary = b.clusters.get(r, {})
		if cb.get("members") != ca.members or cb.get("offset") != ca.offset or cb.get("locked") != ca.locked:
			clusters_match = false
	check(clusters_match, "every cluster comes back with its members, offset and lock")
	check(b.positions == a.positions, "every node comes back where it was")
	check(b.loose == a.loose, "the loose draw order comes back")
	check(b.locked_layer == a.locked_layer, "the locked layer comes back")
	# The file keeps the clock to the millisecond.
	check(b.elapsed == roundf(a.elapsed * 1000.0) / 1000.0, "the clock comes back")
	check(a.tidy_count == 1 and b.tidy_count == 1, "the tidy counter comes back")
	check((b.bounds as Rect2).position.is_equal_approx((a.bounds as Rect2).position)
			and (b.bounds as Rect2).size.is_equal_approx((a.bounds as Rect2).size),
			"the camera bounds take in the tidied bands: %s vs %s" % [b.bounds, a.bounds])
	check(board.puzzle.piece_count == Board.PIECE_COUNT, "the saved puzzle comes back")
	check(not board.is_tidying(), "a restore does not animate")


func _test_resave_is_identical() -> void:
	board.save_game()
	check(FileAccess.get_file_as_string(TEST_SAVE_PATH) == _text_a, "saving the restored board writes the same text")


func _test_plays_on() -> void:
	_show_everything()
	var n := _first_loose_singleton(PackedInt32Array())
	_move_by_touch(n, Vector2.ZERO)
	check(board.state.is_locked(n.piece_id), "a restored board locks a piece")
	check(n.get_parent() == board.locked_pieces, "the locked node moves to the locked layer")
	check(_saved_cluster_of(n.piece_id).get("locked") == true, "the lock is saved")
	board.cleanup()
	check(board._cleanup_count == 2, "the tidy counter carries on")
	board._finish_cleanup()


func _test_tidy_mid_animation() -> void:
	board.cleanup()
	check(board.is_tidying(), "the tidy runs")
	board.save_game()
	var expected := PackedVector2Array()
	for id in board.state.piece_count():
		expected.append(board.state.offset_of(id))
	board.free()
	_quiet(_resume(), "resume after a tidy")
	check(not board.is_tidying(), "a restored tidy does not animate")
	var landed := true
	for id in board.state.piece_count():
		if board.node_for(id).position != expected[id]:
			landed = false
	check(landed, "restore lands a tidy at its final offsets")


func _test_other_identity() -> void:
	var cut55 := CutGenerator.generate_cut(1536, 1024, 55, CutGenerator.STYLE_REGULAR, 7)
	check(cut55.size() == 54, "55 asked gives a 54-piece cut")
	var s := SaveGame.Snapshot.new()
	s.puzzle.image_id = Board.IMAGE_ID
	s.puzzle.image_size = Board.IMAGE_SIZE
	s.puzzle.style = "regular"
	s.puzzle.piece_count = 55
	s.puzzle.cut_seed = 7
	s.puzzle.cut_checksum = CutGenerator.checksum(cut55)
	for i in cut55.size():
		var cluster := SaveGame.Cluster.new()
		cluster.root = i
		cluster.pieces = PackedInt32Array([i])
		cluster.offset = Vector2(-400 - 3 * i, -300)
		s.clusters.append(cluster)
	for i in range(cut55.size() - 1, -1, -1):
		s.loose_order.append(i)
	s.elapsed = 9.5
	s.tidy_count = 0
	SaveFile.write_atomic(TEST_SAVE_PATH, SaveGame.to_json(s))
	board.free()
	_quiet(_resume(), "resume another identity")
	check(board.cut.size() == 54, "the cut is regenerated from the saved identity")
	check(board.pieces.get_child_count() == 54, "one node per saved piece")
	check(board.puzzle.piece_count == 55 and board.puzzle.cut_seed == 7, "the saved identity is kept")
	var placed := true
	for i in 54:
		if board.node_for(i).position != Vector2(-400 - 3 * i, -300):
			placed = false
	check(placed, "every node sits at its saved offset")
	check((board.pieces.get_child(0) as PieceNode).piece_id == 53, "the saved draw order is kept")
	check(board.elapsed == 9.5, "the saved clock is kept")
	board.save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))
	check(saved.puzzle.piece_count == 55, "a resave keeps the requested count")


# The restore path accepts only the test image at IMAGE_SIZE, so another size goes through the hook
# _ready uses, on a board whose puzzle claims it.
func _test_sizes_follow_the_puzzle() -> void:
	var size := Vector2i(1024, 1536)
	board.puzzle.image_size = size
	board._apply_image_size()
	var base := Rect2(Vector2.ZERO, Vector2(size)).grow(Board.LOOSE_MARGIN)
	check(board._base_bounds == base, "the base bounds follow the puzzle's size")
	check(board._bounds.encloses(base), "the camera bounds take in the base bounds")
	check(board._texture.width == size.x and board._texture.height == size.y, "the image follows the puzzle's size")
	check(is_equal_approx(board.camera.zoom.x, board.get_viewport_rect().size.x / (size.x * Board.BORDER)),
			"the camera fits the puzzle's width")
	check(board.camera.position == Vector2(size) / 2.0, "the camera centres on the puzzle's board")

	var roots := PackedInt32Array()
	var rects: Array[Rect2] = []
	for r in board.state.roots():
		if not board.state.is_locked(r):
			roots.append(r)
			rects.append(board.cluster_home_rect(r))
	var cell := sqrt(float(size.x) * size.y / board.cut.size())
	var expected := CleanupLayout.layout(rects, Vector2(size), cell, board.puzzle.cut_seed, board._cleanup_count,
			board.state.tolerance)
	board.cleanup()
	var offsets_match := true
	for k in roots.size():
		if board.state.offset_of(roots[k]) != expected.offsets[k]:
			offsets_match = false
	check(offsets_match, "a tidy lays out around the puzzle's size")
	check(board._bounds == base.merge(expected.extent), "a tidy's bounds use the puzzle's size")
	board._finish_cleanup()
	# This board's puzzle now claims a size its cut was not made for. Nothing saves before
	# _test_missing_file_starts_fresh frees it and makes the next board, so the size is never written.


func _test_missing_file_starts_fresh() -> void:
	board.free()
	SaveFile.remove(TEST_SAVE_PATH)
	DirAccess.remove_absolute(SaveFile.bad_path(TEST_SAVE_PATH))
	_quiet(_resume(), "no save")
	check(_is_fresh(), "no save starts a fresh puzzle")
	check(not FileAccess.file_exists(SaveFile.bad_path(TEST_SAVE_PATH)), "no save sets nothing aside")
	_good = SaveGame.to_dict(board.snapshot())


func _test_bad_file(label: String, text: String) -> void:
	board.free()
	SaveFile.write_atomic(TEST_SAVE_PATH, text)
	_check_set_aside(label, text, _resume())


func _check_set_aside(label: String, text: String, capture: LogCapture) -> void:
	check(capture.warnings.size() == 1 and capture.warnings[0].begins_with("Board: could not use the save at"),
			"%s: one warning (%s)" % [label, capture.warnings])
	check(capture.errors.is_empty(), "%s: no error (%s)" % [label, capture.errors])
	check(not FileAccess.file_exists(TEST_SAVE_PATH), "%s: the save path is free" % label)
	var bad := SaveFile.read(SaveFile.bad_path(TEST_SAVE_PATH))
	check(bad.error == OK and bad.text == text, "%s: the save survives, set aside" % label)
	check(_is_fresh(), "%s: a fresh puzzle starts" % label)


# Linux only: chmod takes the read permission away, and the move aside keeps it.
func _test_unreadable_file() -> void:
	board.free()
	var text := _text(_good)
	SaveFile.write_atomic(TEST_SAVE_PATH, text)
	OS.execute("chmod", ["000", ProjectSettings.globalize_path(TEST_SAVE_PATH)])
	var capture := _resume()
	OS.execute("chmod", ["644", ProjectSettings.globalize_path(SaveFile.bad_path(TEST_SAVE_PATH))])
	_check_set_aside("unreadable", text, capture)


func _is_fresh() -> bool:
	if board.cut.size() != Board.PIECE_COUNT or board.pieces.get_child_count() != Board.PIECE_COUNT:
		return false
	if board.locked_pieces.get_child_count() != 0 or board.state.roots().size() != Board.PIECE_COUNT:
		return false
	for id in Board.PIECE_COUNT:
		if board.node_for(id).position != _fresh_offsets[id]:
			return false
	return board.elapsed == 0.0 and board._cleanup_count == 0 and board.puzzle.cut_seed == Board.SEED
