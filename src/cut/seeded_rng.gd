class_name SeededRng
extends RefCounted
## xorshift32. Own generator so cuts are identical on every device and engine version.

const MASK: int = 0xFFFFFFFF

var _state: int


func _init(seed_value: int) -> void:
	_state = seed_value & MASK
	if _state == 0:
		_state = 1


## Mixes two ints into one 32-bit seed, so an edge's generator depends only on the cut seed and its id.
static func hash2(a: int, b: int) -> int:
	# Ints are signed 64-bit: each multiply keeps one side under 2^31 and the other masked to 32 bits.
	var h := ((a & MASK) * 0x27d4eb2d + (b & MASK)) & MASK
	h ^= h >> 15
	h = (h * 0x2c1b3c6d) & MASK
	h ^= h >> 12
	h = (h * 0x297a2d39) & MASK
	h ^= h >> 15
	return h


func next_u32() -> int:
	# GDScript ints are 64-bit, so mask after each step to emulate 32-bit overflow.
	var x := _state
	x = (x ^ (x << 13)) & MASK
	x = x ^ (x >> 17)
	x = (x ^ (x << 5)) & MASK
	_state = x
	return x


func next_float() -> float:
	return next_u32() / 4294967296.0


func range_float(from: float, to: float) -> float:
	return from + (to - from) * next_float()


func range_int(from: int, to_inclusive: int) -> int:
	return from + next_u32() % (to_inclusive - from + 1)
