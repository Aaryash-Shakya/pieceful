class_name CleanupLayout
extends RefCounted
## Where loose clusters go when the player asks for a tidy-up: shuffled, packed row by row
## into two bands, one above and one below the board. Pure logic, so it is testable without nodes.

# Distinct from the cut's lattice (-1) and scatter (-2) streams.
const CLEANUP_STREAM := -3
const GAP_FRACTION := 0.14
const BOARD_GAP_FRACTION := 0.7
const BAND_WIDTH_FRACTION := 1.45
# Gap as a multiple of the join tolerance. Neighbours' home rects touch, so a gap wider than the
# tolerance keeps their offsets out of join reach however shallow the tabs are.
const JOIN_CLEARANCE := 1.25


class Result:
	var offsets := PackedVector2Array()
	var extent := Rect2()


## offsets[i] moves home_bounds[i] to its tidy spot. cell is the average piece side;
## counter makes each press of the button deal a new order. tolerance is the join tolerance,
## which the gap between clusters always exceeds.
static func layout(home_bounds: Array[Rect2], board_size: Vector2, cell: float, seed_value: int, counter: int, tolerance := 0.0) -> Result:
	var result := Result.new()
	var count := home_bounds.size()
	if count == 0:
		return result
	var gap := maxf(GAP_FRACTION * cell, JOIN_CLEARANCE * tolerance)
	var board_gap := BOARD_GAP_FRACTION * cell
	var band := BAND_WIDTH_FRACTION * board_size.x

	# Hashed because xorshift32's first draws from a small raw seed are skewed.
	var rng := SeededRng.new(SeededRng.hash2(SeededRng.hash2(seed_value, CLEANUP_STREAM), counter))
	var order: Array[int] = []
	for i in count:
		order.append(i)
	for i in range(count - 1, 0, -1):
		var j := rng.range_int(0, i)
		var swap := order[i]
		order[i] = order[j]
		order[j] = swap

	var total := 0.0
	for r in home_bounds:
		total += (r.size.x + gap) * (r.size.y + gap)
	var split := 0
	var running := 0.0
	while split < count and running < total / 2.0:
		var r := home_bounds[order[split]]
		running += (r.size.x + gap) * (r.size.y + gap)
		split += 1

	var placed: Array[Rect2] = []
	placed.resize(count)
	_pack(home_bounds, order.slice(0, split), board_size.x, band, gap, -board_gap, true, placed)
	_pack(home_bounds, order.slice(split), board_size.x, band, gap, board_size.y + board_gap, false, placed)

	result.offsets.resize(count)
	for i in count:
		result.offsets[i] = placed[i].position - home_bounds[i].position
		# Rebuilt from the offset so the extent encloses exactly what callers will draw.
		var drawn := Rect2(home_bounds[i].position + result.offsets[i], home_bounds[i].size)
		result.extent = drawn if i == 0 else result.extent.merge(drawn)
	return result


# Fills rows outward from edge: the top band grows upward from its bottom edge, the bottom band
# downward from its top edge. A cluster wider than the band still gets a row of its own.
static func _pack(home_bounds: Array[Rect2], items: Array[int], board_width: float, band: float,
		gap: float, edge: float, upward: bool, placed: Array[Rect2]) -> void:
	var rows: Array[Array] = []
	var row: Array[int] = []
	var row_width := 0.0
	for i in items:
		var w := home_bounds[i].size.x
		if not row.is_empty() and row_width + gap + w > band:
			rows.append(row)
			row = []
		row_width = w if row.is_empty() else row_width + gap + w
		row.append(i)
	if not row.is_empty():
		rows.append(row)

	var cursor := edge
	for members: Array in rows:
		var width := gap * (members.size() - 1)
		var height := 0.0
		for i: int in members:
			width += home_bounds[i].size.x
			height = maxf(height, home_bounds[i].size.y)
		var top := cursor - height if upward else cursor
		var x := board_width / 2.0 - width / 2.0
		for i: int in members:
			var size := home_bounds[i].size
			placed[i] = Rect2(Vector2(x, top + (height - size.y) / 2.0), size)
			x += size.x + gap
		cursor = top - gap if upward else top + height + gap
