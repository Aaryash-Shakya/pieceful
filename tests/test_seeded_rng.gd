extends BaseTest


func _init() -> void:
	check(SeededRng.new(1).next_u32() == 270369, "seed 1 first u32 is 270369")

	var a := SeededRng.new(42)
	var b := SeededRng.new(42)
	var same := true
	for i in 5:
		if a.next_u32() != b.next_u32():
			same = false
	check(same, "same seed gives same first 5 values")

	var rng := SeededRng.new(7)
	var in_range := true
	for i in 1000:
		var f := rng.next_float()
		if f < 0.0 or f >= 1.0:
			in_range = false
	check(in_range, "next_float stays in [0, 1)")

	var ints := SeededRng.new(7)
	var seen := {}
	var int_ok := true
	for i in 1000:
		var n := ints.range_int(3, 5)
		seen[n] = true
		if n < 3 or n > 5:
			int_ok = false
	check(int_ok, "range_int(3, 5) stays within 3..5")
	check(seen.size() == 3, "range_int(3, 5) returns all of 3, 4, 5")

	check(SeededRng.hash2(1, 2) == 3749358279, "hash2(1, 2) is pinned")
	check(SeededRng.hash2(7, 0) == 3190417882, "hash2(7, 0) is pinned")
	check(SeededRng.hash2(-5, 3) == 3280828902, "hash2(-5, 3) is pinned")
	check(SeededRng.hash2(1, -1) == 3238652418, "hash2(1, -1) is pinned")
	var hash_ok := true
	for x in 100:
		for y in 10:
			var h := SeededRng.hash2(x, y)
			if h < 0 or h > SeededRng.MASK:
				hash_ok = false
	check(hash_ok, "hash2 stays within 0..MASK")

	finish()
