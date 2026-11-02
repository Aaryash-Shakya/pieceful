extends BaseTest

const AGREEMENT_SHAPES: Array[Vector2i] = [Vector2i(1536, 1024), Vector2i(1024, 1536), Vector2i(1000, 1000), Vector2i(2048, 900), Vector2i(10000, 100)]


func is_ascending(counts: PackedInt32Array) -> bool:
	for i in range(1, counts.size()):
		if counts[i] <= counts[i - 1]:
			return false
	return true


func _init() -> void:
	var landscape := CutGenerator.valid_counts(1536, 1024, 12, 400)
	check(landscape.size() == 67, "1536x1024 has 67 counts, got %d" % landscape.size())
	check(landscape.slice(0, 5) == PackedInt32Array([12, 15, 24, 28, 35]), "1536x1024 first five, got %s" % landscape.slice(0, 5))
	check(landscape[landscape.size() - 1] == 400, "1536x1024 last is 400")
	for n in [54, 96, 150, 300, 400]:
		check(landscape.has(n), "1536x1024 contains %d" % n)
	for n in [200, 250]:
		check(not landscape.has(n), "1536x1024 does not contain %d" % n)

	var portrait := CutGenerator.valid_counts(1024, 1536, 12, 400)
	check(portrait.size() == 67, "1024x1536 has 67 counts, got %d" % portrait.size())

	var square := CutGenerator.valid_counts(1000, 1000, 12, 400)
	check(square.size() == 43, "1000x1000 has 43 counts, got %d" % square.size())
	check(square[0] == 16, "1000x1000 first is 16, got %d" % square[0])
	check(square[square.size() - 1] == 400, "1000x1000 last is 400")

	var wide := CutGenerator.valid_counts(10000, 100, 12, 400)
	check(wide[0] == 84, "10000x100 first is 84, got %d" % wide[0])

	var limit := exp(CutGenerator.MAX_ASPECT_ERROR)
	for shape in AGREEMENT_SHAPES:
		var counts := CutGenerator.valid_counts(shape.x, shape.y, 12, 400)
		var label := "%dx%d" % [shape.x, shape.y]
		check(is_ascending(counts), "%s is strictly ascending" % label)
		for n in counts:
			var split := CutGenerator.grid_split(shape.x, shape.y, n)
			check(split.x * split.y == n, "%s count %d: grid_split %s is exact" % [label, n, split])
			var cell_aspect := (shape.x / float(split.x)) / (shape.y / float(split.y))
			check(cell_aspect >= 1.0 / limit and cell_aspect <= limit, "%s count %d: cell aspect %f in range" % [label, n, cell_aspect])

	check(CutGenerator.valid_counts(1536, 1024, 400, 12).is_empty(), "min above max is empty")
	check(CutGenerator.valid_counts(3, 2, 12, 400).is_empty(), "3x2 image is empty")
	finish()
