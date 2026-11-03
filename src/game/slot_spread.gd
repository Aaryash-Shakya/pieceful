class_name SlotSpread
extends RefCounted
## Where the clusters of a slot go when the player takes them out. Pure logic, no nodes.
## Both functions return, for each home rectangle, the offset that puts the middle of that
## cluster at a chosen spot, so the board only has to move clusters by those offsets.

const FAN_STEP := Vector2(14.0, 10.0)


## An even grid centred on the point. Every cell is as big as the biggest cluster plus the gap, and the gap is
## the same clearance Tidy leaves, so spreading never leaves two clusters close enough to join.
static func grid(home_bounds: Array[Rect2], center: Vector2, tolerance: float) -> PackedVector2Array:
	var count := home_bounds.size()
	var offsets := PackedVector2Array()
	if count == 0:
		return offsets
	var gap := CleanupLayout.JOIN_CLEARANCE * tolerance
	var cell := Vector2.ZERO
	for r in home_bounds:
		cell = cell.max(r.size)
	cell += Vector2(gap, gap)
	var columns := ceili(sqrt(float(count)))
	var rows := ceili(float(count) / columns)
	var origin := center - Vector2(columns, rows) * cell / 2.0 + cell / 2.0
	offsets.resize(count)
	for i in count:
		var at := origin + Vector2(i % columns, i / columns) * cell
		offsets[i] = at - home_bounds[i].get_center()
	return offsets


## A loose fan: each cluster a small step from the last, the middle one on the point.
static func fan(home_bounds: Array[Rect2], center: Vector2) -> PackedVector2Array:
	var count := home_bounds.size()
	var offsets := PackedVector2Array()
	offsets.resize(count)
	for i in count:
		var at := center + (i - (count - 1) / 2.0) * FAN_STEP
		offsets[i] = at - home_bounds[i].get_center()
	return offsets
