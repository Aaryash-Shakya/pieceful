extends BaseTest


func check_bounds(pts: PackedVector2Array, label: String) -> void:
	check(pts.size() == TabShape.POINTS_PER_EDGE, "%s: %d points" % [label, TabShape.POINTS_PER_EDGE])
	check(pts[0] == Vector2(0, 0) and pts[pts.size() - 1] == Vector2(100, 0), "%s: ends are exact" % label)
	var inside := true
	var snapped := true
	for p in pts:
		if p.x < 0.0 or p.x > 100.0 or absf(p.y) > 40.0:
			inside = false
		if absf(p.x - snappedf(p.x, 0.001)) > 1e-4 or absf(p.y - snappedf(p.y, 0.001)) > 1e-4:
			snapped = false
	check(inside, "%s: points stay within 0..100 along and 40 across" % label)
	check(snapped, "%s: points are snapped to 0.001" % label)
	check(absf(pts[13].y) >= 12.0, "%s: knob apex stands at least 12 off the line" % label)


func _init() -> void:
	var shape := TabShape.for_style("regular")
	var pts := shape.edge_points(Vector2(0, 0), Vector2(100, 0), 100.0, SeededRng.new(3))
	check_bounds(pts, "regular seed 3")
	check(shape.edge_points(Vector2(0, 0), Vector2(100, 0), 100.0, SeededRng.new(3)) == pts, "same seed gives same points")

	var up := 0
	var down := 0
	# Seeded through hash2 as shape_edges does: xorshift32's first draw from a small raw seed is
	# always tiny, so SeededRng.new(1..200) would flip every tab the same way.
	for s in range(1, 201):
		var apex := shape.edge_points(Vector2(0, 0), Vector2(100, 0), 100.0, SeededRng.new(SeededRng.hash2(1, s)))[13].y
		if apex > 0.0:
			up += 1
		elif apex < 0.0:
			down += 1
	check(up >= 50 and down >= 50, "tabs face both ways (%d up, %d down)" % [up, down])

	check_bounds(TabShape.for_style("irregular").edge_points(Vector2(0, 0), Vector2(100, 0), 100.0, SeededRng.new(3)), "irregular seed 3")

	check(shape.edge_points(Vector2(0, 0), Vector2(100, 0), 7.9, SeededRng.new(3)).size() == 2, "cramped edge stays straight")
	check(TabShape.for_style("grid") == null, "grid has no tabs")
	check(TabShape.for_style("bogus") == null, "unknown style has no tabs")

	finish()
