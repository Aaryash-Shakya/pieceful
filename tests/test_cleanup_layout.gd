extends "res://tests/base_test.gd"

const BOARD := Vector2(1536, 1024)
const CELL := sqrt(1536.0 * 1024.0 / 400.0)

var _cut_rects: Array[Rect2] = []


func _init() -> void:
	for piece in CutGenerator.generate_cut(1536, 1024, 400, CutGenerator.STYLE_REGULAR, 1):
		_cut_rects.append(piece.bounds())
	_test_empty()
	_test_every_cluster_placed()
	_test_no_overlap_with_gap()
	_test_outside_board()
	_test_two_bands_balanced()
	_test_inside_band_width()
	_test_small_input_one_row_each()
	_test_bands_grow_outward()
	_test_wide_cluster()
	_test_extent()
	_test_deterministic()
	_test_counter_and_seed_change_order()
	finish()


func _placed(home: Array[Rect2], r: CleanupLayout.Result) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for i in home.size():
		result.append(Rect2(home[i].position + r.offsets[i], home[i].size))
	return result


func _squares(count: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for i in count:
		result.append(Rect2(Vector2(i * CELL, 0), Vector2(CELL, CELL)))
	return result


func _run(home: Array[Rect2], seed_value := 1, counter := 0) -> CleanupLayout.Result:
	return CleanupLayout.layout(home, BOARD, CELL, seed_value, counter)


func _gap() -> float:
	return CleanupLayout.GAP_FRACTION * CELL


func _board_gap() -> float:
	return CleanupLayout.BOARD_GAP_FRACTION * CELL


func _band() -> float:
	return CleanupLayout.BAND_WIDTH_FRACTION * BOARD.x


func _test_empty() -> void:
	var empty: Array[Rect2] = []
	var r := _run(empty)
	check(r.offsets.is_empty(), "empty input gives no offsets")
	check(r.extent == Rect2(), "empty input gives an empty extent")


func _test_every_cluster_placed() -> void:
	check(_run(_cut_rects).offsets.size() == 400, "one offset per cluster")


func _test_no_overlap_with_gap() -> void:
	var placed := _placed(_cut_rects, _run(_cut_rects))
	var half := _gap() / 2.0 - 0.01
	var failing := 0
	for i in placed.size():
		for j in range(i + 1, placed.size()):
			if placed[i].grow(half).intersects(placed[j].grow(half)):
				failing += 1
	check(failing == 0, "no two placed clusters overlap or come closer than the gap (%d pairs)" % failing)


func _test_outside_board() -> void:
	var bg := _board_gap()
	var bad := 0
	for p in _placed(_cut_rects, _run(_cut_rects)):
		if not (p.end.y <= -bg + 0.01 or p.position.y >= BOARD.y + bg - 0.01):
			bad += 1
	check(bad == 0, "every placed cluster is clear of the board (%d not)" % bad)


func _test_two_bands_balanced() -> void:
	var gap := _gap()
	var placed := _placed(_cut_rects, _run(_cut_rects))
	var total := 0.0
	var largest := 0.0
	var above_area := 0.0
	var above := 0
	var below := 0
	for p in placed:
		var a := (p.size.x + gap) * (p.size.y + gap)
		total += a
		largest = maxf(largest, a)
		if p.end.y <= 0.0:
			above += 1
			above_area += a
		else:
			below += 1
	check(above > 0 and below > 0, "both bands are used")
	check(above_area >= total / 2.0, "top band holds at least half the area")
	check(above_area - largest < total / 2.0, "top band is the shortest prefix reaching half the area")


func _test_inside_band_width() -> void:
	var band := _band()
	var bad := 0
	for p in _placed(_cut_rects, _run(_cut_rects)):
		if p.position.x < (BOARD.x - band) / 2.0 - 0.01 or p.end.x > (BOARD.x + band) / 2.0 + 0.01:
			bad += 1
	check(bad == 0, "every placed cluster is inside the band width (%d not)" % bad)


func _test_small_input_one_row_each() -> void:
	var home := _squares(4)
	var placed := _placed(home, _run(home))
	var bg := _board_gap()
	var top: Array[Rect2] = []
	var bottom: Array[Rect2] = []
	for p in placed:
		if is_equal_approx(p.end.y, -bg):
			top.append(p)
		elif is_equal_approx(p.position.y, BOARD.y + bg):
			bottom.append(p)
	check(top.size() == 2 and bottom.size() == 2, "four squares make one row of two on each side")
	for row in [top, bottom]:
		if row.size() != 2:
			continue
		var l: Rect2 = row[0] if row[0].position.x < row[1].position.x else row[1]
		var r: Rect2 = row[1] if row[0].position.x < row[1].position.x else row[0]
		check(is_equal_approx(r.position.x - l.end.x, _gap()), "row neighbours sit one gap apart")
		check(is_equal_approx((l.position.x + r.end.x) / 2.0, BOARD.x / 2.0), "row is centred on the board")


func _test_bands_grow_outward() -> void:
	var r := _run(_cut_rects)
	var bg := _board_gap()
	check(r.extent.position.y < -bg - 3.0 * CELL, "top band stacks several rows upward")
	check(r.extent.end.y > BOARD.y + bg + 3.0 * CELL, "bottom band stacks several rows downward")
	var top_edge := -INF
	var bottom_edge := INF
	for p in _placed(_cut_rects, r):
		if p.end.y <= 0.0:
			top_edge = maxf(top_edge, p.end.y)
		else:
			bottom_edge = minf(bottom_edge, p.position.y)
	check(is_equal_approx(top_edge, -bg), "top row 0 sits against the board gap")
	check(is_equal_approx(bottom_edge, BOARD.y + bg), "bottom row 0 sits against the board gap")


func _test_wide_cluster() -> void:
	var home := _squares(6)
	home.append(Rect2(Vector2.ZERO, Vector2(2.0 * _band(), CELL)))
	var placed := _placed(home, _run(home))
	var wide := placed[6]
	check(is_equal_approx(wide.get_center().x, BOARD.x / 2.0), "a cluster wider than the band is centred")
	var shares_row := false
	var failing := 0
	var half := _gap() / 2.0 - 0.01
	for i in placed.size():
		if i < 6 and placed[i].position.y < wide.end.y and placed[i].end.y > wide.position.y:
			shares_row = true
		for j in range(i + 1, placed.size()):
			if placed[i].grow(half).intersects(placed[j].grow(half)):
				failing += 1
	check(not shares_row, "a wide cluster gets a row to itself")
	check(failing == 0, "wide cluster does not overlap its neighbours (%d pairs)" % failing)


func _test_extent() -> void:
	var r := _run(_cut_rects)
	var placed := _placed(_cut_rects, r)
	var merged := placed[0]
	var encloses_all := true
	for p in placed:
		merged = merged.merge(p)
		if not r.extent.grow(0.001).encloses(p):
			encloses_all = false
	check(r.extent == merged, "extent is the merge of every placed rect")
	check(encloses_all, "extent encloses every placed rect (to float rounding)")


func _test_deterministic() -> void:
	check(_run(_cut_rects).offsets == _run(_cut_rects).offsets, "same arguments give the same layout")


func _test_counter_and_seed_change_order() -> void:
	var home := _squares(10)
	check(_run(home, 1, 0).offsets != _run(home, 1, 1).offsets, "another counter reshuffles")
	check(_run(home, 1, 0).offsets != _run(home, 2, 0).offsets, "another seed reshuffles")
