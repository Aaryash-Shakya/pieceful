class_name TabShape
extends RefCounted
## A classic jigsaw knob on one edge: shoulder, knob, shoulder as three cubic curves.

const SEGMENTS: Array[int] = [8, 10, 8]
const POINTS_PER_EDGE := 27
# Below this many image pixels of room a knob would be too small to see or grab.
const MIN_ROOM := 8.0

## Knob size as a fraction of the edge's room.
var size: float
## Relative spread of the knob size.
var size_jitter: float
## How far the knob may slide off the middle, as a fraction of the edge length.
var shift: float
## Random offset of the control points, as a fraction of the room.
var wobble: float


func _init(size_value: float, size_jitter_value: float, shift_value: float, wobble_value: float) -> void:
	size = size_value
	size_jitter = size_jitter_value
	shift = shift_value
	wobble = wobble_value


## Null for styles without tabs.
static func for_style(style: String) -> TabShape:
	match style:
		CutGenerator.STYLE_REGULAR:
			return TabShape.new(0.10, 0.05, 0.03, 0.02)
		CutGenerator.STYLE_IRREGULAR:
			# Bounded by the lattice's sharpest corners (about 68 degrees), where two inward knobs shifted
			# toward the corner can touch. Checked exhaustively in tests/test_tab_extremes.gd.
			return TabShape.new(0.10, 0.10, 0.04, 0.02)
	return null


## The order of rng draws is part of the cut format: changing it changes every saved puzzle.
func edge_points(from: Vector2, to: Vector2, room: float, rng: SeededRng) -> PackedVector2Array:
	if room < MIN_ROOM:
		return PackedVector2Array([from, to])
	# All arithmetic is on GDScript floats: 64-bit, rounded after every operation on every CPU.
	# Vector2 math is 32-bit C++ that arm64 builds may fuse into multiply-adds, so a phone and a
	# desktop could disagree by a snap step.
	var dx: float = to.x - from.x
	var dy: float = to.y - from.y
	var length := sqrt(dx * dx + dy * dy)
	var ux := dx / length
	var uy := dy / length
	var flip := 1.0 if rng.next_float() < 0.5 else -1.0
	# The unit normal, u.orthogonal() * flip.
	var nx := uy * flip
	var ny := -ux * flip
	var t := size * room * (1.0 + rng.range_float(-size_jitter, size_jitter))
	var m := length * (0.5 + rng.range_float(-shift, shift))
	var w := wobble * room
	var a := rng.range_float(-w, w)
	var c := rng.range_float(-w, w)
	var d := rng.range_float(-w, w)
	var e := rng.range_float(-w, w)
	# Control points along the edge (qx) and across it (qy). PackedFloat64Array keeps them 64-bit.
	var qx := PackedFloat64Array([0.0, 0.2 * length, m + d, m - t, m - 2.0 * t - d, m + 2.0 * t - d, m + t, m + d, 0.8 * length, length])
	var qy := PackedFloat64Array([0.0, a, -t + c, t + c, 3.0 * t + c, 3.0 * t + c, t + c, -t + c, e, 0.0])
	var points := PackedVector2Array([from])
	for curve in SEGMENTS.size():
		var segments := SEGMENTS[curve]
		var k := 3 * curve
		for i in range(1, segments + 1):
			# Cubic Bernstein weights.
			var s := i / float(segments)
			var r := 1.0 - s
			var b0 := r * r * r
			var b1 := 3.0 * r * r * s
			var b2 := 3.0 * r * s * s
			var b3 := s * s * s
			var lx := b0 * qx[k] + b1 * qx[k + 1] + b2 * qx[k + 2] + b3 * qx[k + 3]
			var ly := b0 * qy[k] + b1 * qy[k + 1] + b2 * qy[k + 2] + b3 * qy[k + 3]
			var px := from.x + ux * lx + nx * ly
			var py := from.y + uy * lx + ny * ly
			# Snapped while still 64-bit, so the 32-bit Vector2 gets the same value everywhere.
			points.append(Vector2(snappedf(px, CutGenerator.PRECISION), snappedf(py, CutGenerator.PRECISION)))
	points[points.size() - 1] = to
	return points
