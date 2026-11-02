class_name Scatter
extends RefCounted
## Starting displacements for loose pieces, so they begin spread around the board.

# Distinct from the cut's lattice stream (-1), so scatter never reuses a cut's random numbers.
const SCATTER_STREAM := -2


## One displacement per piece, in array order, used as the piece node's position.
## Each moved piece lies fully outside the board and inside the board grown by margin.
## Pieces may overlap each other.
static func scatter(pieces: Array[CutPiece], image_size: Vector2, margin: float, seed_value: int) -> PackedVector2Array:
	# Hashed because xorshift32's first draws from a small raw seed are tiny.
	var rng := SeededRng.new(SeededRng.hash2(seed_value, SCATTER_STREAM))
	var result := PackedVector2Array()
	result.resize(pieces.size())
	for i in pieces.size():
		var bounds := pieces[i].bounds()
		var target := _pick_position(bounds.size, image_size, margin, rng)
		result[i] = target - bounds.position
	return result


# Picks where the bounds' top-left lands. Top, bottom, left and right strips of the
# margin ring are chosen by area, so no rejection loop is needed.
static func _pick_position(size: Vector2, image_size: Vector2, margin: float, rng: SeededRng) -> Vector2:
	var low := Vector2(-margin, -margin)
	var high := image_size + Vector2(margin, margin) - size
	var strips: Array[Rect2] = [
		Rect2(low, Vector2(high.x - low.x, -size.y - low.y)),
		Rect2(Vector2(low.x, image_size.y), Vector2(high.x - low.x, high.y - image_size.y)),
		Rect2(low, Vector2(-size.x - low.x, high.y - low.y)),
		Rect2(Vector2(image_size.x, low.y), Vector2(high.x - image_size.x, high.y - low.y)),
	]
	var total := 0.0
	for strip in strips:
		if strip.size.x >= 0.0 and strip.size.y >= 0.0:
			total += strip.size.x * strip.size.y
	if total <= 0.0:
		# Margin too small for this piece; park it just outside the board's left edge.
		return Vector2(-size.x, 0.0)
	var roll := rng.next_float() * total
	var chosen := strips[0]
	for strip in strips:
		if strip.size.x < 0.0 or strip.size.y < 0.0:
			continue
		chosen = strip
		roll -= strip.size.x * strip.size.y
		if roll < 0.0:
			break
	return Vector2(
		rng.range_float(chosen.position.x, chosen.end.x),
		rng.range_float(chosen.position.y, chosen.end.y)
	)
