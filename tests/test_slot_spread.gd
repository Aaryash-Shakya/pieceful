extends "res://tests/base_test.gd"


func _init() -> void:
	var rects: Array[Rect2] = []
	for i in 7:
		rects.append(Rect2(Vector2(40 * i, 10 * i), Vector2(30 + 5 * i, 50)))
	var center := Vector2(500, 300)
	var tol := 10.0

	check(SlotSpread.grid([], center, tol).is_empty(), "an empty grid has no offsets")

	var offsets := SlotSpread.grid(rects, center, tol)
	check(offsets.size() == 7, "one offset per cluster")
	var placed: Array[Rect2] = []
	var sum := Vector2.ZERO
	for i in 7:
		var r := Rect2(rects[i].position + offsets[i], rects[i].size)
		placed.append(r)
		sum += r.get_center()
	for i in 7:
		for j in range(i + 1, 7):
			var gapped := placed[i].grow(CleanupLayout.JOIN_CLEARANCE * tol / 2.0 - 0.001)
			check(not gapped.intersects(placed[j]), "clusters %d and %d keep their clearance" % [i, j])
	# 7 clusters make 3 columns by 3 rows, with 2 cells empty, so the mean sits near the centre.
	check(sum.distance_to(center * 7.0) < 120.0 * 7.0, "the grid is centred on the point")
	var again := SlotSpread.grid(rects, center, tol)
	check(again == offsets, "the same input gives the same grid")

	var single: Array[Rect2] = [Rect2(Vector2(5, 5), Vector2(20, 20))]
	var one := SlotSpread.grid(single, center, tol)
	check((single[0].get_center() + one[0]).is_equal_approx(center), "a lone cluster sits on the point")

	var fan := SlotSpread.fan(rects, center)
	var middle := rects[3].get_center() + fan[3]
	check(middle.is_equal_approx(center), "the middle of the fan is on the point")
	var step := (rects[4].get_center() + fan[4]) - (rects[3].get_center() + fan[3])
	check(step.is_equal_approx(SlotSpread.FAN_STEP), "fan clusters sit one step apart")
	finish()
