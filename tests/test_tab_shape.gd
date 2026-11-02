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


## The tab contract written out in 64-bit scalars, one rounding per operation, as every CPU computes
## GDScript floats. Pins both the draw order and the arithmetic.
func reference_points(shape: TabShape, from: Vector2, to: Vector2, room: float, rng: SeededRng) -> PackedVector2Array:
	var dx: float = to.x - from.x
	var dy: float = to.y - from.y
	var length := sqrt(dx * dx + dy * dy)
	var ux := dx / length
	var uy := dy / length
	var flip := 1.0 if rng.next_float() < 0.5 else -1.0
	var nx := uy * flip
	var ny := -ux * flip
	var t := shape.size * room * (1.0 + rng.range_float(-shape.size_jitter, shape.size_jitter))
	var m := length * (0.5 + rng.range_float(-shape.shift, shape.shift))
	var w := shape.wobble * room
	var a := rng.range_float(-w, w)
	var c := rng.range_float(-w, w)
	var d := rng.range_float(-w, w)
	var e := rng.range_float(-w, w)
	var qx: Array[float] = [0.0, 0.2 * length, m + d, m - t, m - 2.0 * t - d, m + 2.0 * t - d, m + t, m + d, 0.8 * length, length]
	var qy: Array[float] = [0.0, a, -t + c, t + c, 3.0 * t + c, 3.0 * t + c, t + c, -t + c, e, 0.0]
	var points := PackedVector2Array([from])
	for curve in 3:
		var segments := TabShape.SEGMENTS[curve]
		for i in range(1, segments + 1):
			var s := i / float(segments)
			var r := 1.0 - s
			var b0 := r * r * r
			var b1 := 3.0 * r * r * s
			var b2 := 3.0 * r * s * s
			var b3 := s * s * s
			var k := 3 * curve
			var lx := b0 * qx[k] + b1 * qx[k + 1] + b2 * qx[k + 2] + b3 * qx[k + 3]
			var ly := b0 * qy[k] + b1 * qy[k + 1] + b2 * qy[k + 2] + b3 * qy[k + 3]
			var px := from.x + ux * lx + nx * ly
			var py := from.y + uy * lx + ny * ly
			points.append(Vector2(snappedf(px, 0.001), snappedf(py, 0.001)))
	points[points.size() - 1] = to
	return points


func _init() -> void:
	var matches := 0
	var cases := 0
	for style in ["regular", "irregular"]:
		var tabs := TabShape.for_style(style)
		for s in range(1, 101):
			var from := Vector2(13.375 * s, 250.5)
			var to := from + Vector2(140.25, 10.4 * (s % 7) - 30.0)
			var got := tabs.edge_points(from, to, 90.0 + s, SeededRng.new(SeededRng.hash2(5, s)))
			cases += 1
			if got == reference_points(tabs, from, to, 90.0 + s, SeededRng.new(SeededRng.hash2(5, s))):
				matches += 1
	check(matches == cases, "edge_points matches the 64-bit reference on %d of %d slanted edges" % [matches, cases])

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
