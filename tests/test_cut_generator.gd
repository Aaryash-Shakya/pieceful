extends BaseTest


func check_cut(pieces: Array[CutPiece], w: int, h: int, count: int, label: String) -> void:
	var split := CutGenerator.grid_split(w, h, count)
	var total := 0.0
	var min_area := INF
	for p in pieces:
		total += p.area()
		min_area = minf(min_area, p.area())
	check(is_equal_approx(total, float(w * h)), "%s: areas sum to image area" % label)
	check(min_area >= 0.5 * w * h / pieces.size(), "%s: no piece below half the mean area" % label)
	check(min_area > 0.0, "%s: no zero-area piece" % label)

	var symmetric := true
	for p in pieces:
		for n in p.neighbours:
			if n == p.id or not pieces[n].neighbours.has(p.id):
				symmetric = false
	check(symmetric, "%s: neighbours are symmetric and never self" % label)

	var graph := CutGenerator.build_grid_graph(w, h, split.x, split.y)
	var counts := graph.edge_use_counts()
	var boundary := 0
	var counts_ok := true
	for key in counts:
		var c: int = counts[key]
		if c == 1:
			boundary += 1
		elif c != 2:
			counts_ok = false
	check(counts_ok, "%s: every edge is used by 1 or 2 faces" % label)
	check(boundary == 2 * (split.x + split.y), "%s: boundary edge count" % label)


func _init() -> void:
	for count in [1, 12, 54, 150, 400]:
		var pieces := CutGenerator.generate_cut(1536, 1024, count, CutGenerator.STYLE_GRID, 1)
		check(pieces.size() > 0, "count %d returns pieces" % count)
		check_cut(pieces, 1536, 1024, count, "1536x1024 count %d" % count)

	check(CutGenerator.grid_split(1500, 1000, 54) == Vector2i(9, 6), "grid_split 54 is 9x6")
	check(CutGenerator.grid_split(1500, 1000, 150) == Vector2i(15, 10), "grid_split 150 is 15x10")

	var s := CutGenerator.grid_split(1536, 1024, 400)
	check(absi(s.x * s.y - 400) <= 40, "grid_split 400 product within 40")
	var aspect := (1536.0 / s.x) / (1024.0 / s.y)
	check(aspect >= 0.8 and aspect <= 1.25, "grid_split 400 cells near square")

	var wide := CutGenerator.generate_cut(10000, 100, 50, "grid", 1)
	check(wide.size() > 0, "10000x100 returns pieces")
	check_cut(wide, 10000, 100, 50, "10000x100 count 50")

	var oversize := CutGenerator.generate_cut(10, 10, 100000, "grid", 1)
	check(oversize.size() > 0, "oversize count returns pieces")
	check_cut(oversize, 10, 10, 100000, "10x10 count 100000")
	check(oversize.size() <= 100, "oversize count is capped by the pixel grid")

	var a := CutGenerator.generate_cut(1536, 1024, 54, "grid", 7)
	var b := CutGenerator.generate_cut(1536, 1024, 54, "grid", 7)
	var same := a.size() == b.size()
	if same:
		for i in a.size():
			if a[i].outline != b[i].outline or a[i].neighbours != b[i].neighbours:
				same = false
	check(same, "same inputs give same outlines and neighbours")

	check(CutGenerator.generate_cut(1536, 1024, 54, "bogus", 1).is_empty(), "unknown style is empty")
	check(CutGenerator.generate_cut(0, 1024, 54, "grid", 1).is_empty(), "width 0 is empty")
	check(CutGenerator.generate_cut(1536, 1024, 0, "grid", 1).is_empty(), "target 0 is empty")

	finish()
