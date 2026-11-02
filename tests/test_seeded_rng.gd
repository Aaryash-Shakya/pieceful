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

	finish()
