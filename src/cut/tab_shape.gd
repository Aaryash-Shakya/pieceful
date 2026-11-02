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
		"regular":
			return TabShape.new(0.10, 0.05, 0.03, 0.02)
		"irregular":
			return TabShape.new(0.10, 0.15, 0.08, 0.06)
	return null


## The order of rng draws is part of the cut format: changing it changes every saved puzzle.
func edge_points(from: Vector2, to: Vector2, room: float, rng: SeededRng) -> PackedVector2Array:
	if room < MIN_ROOM:
		return PackedVector2Array([from, to])
	var length := from.distance_to(to)
	var u := (to - from) / length
	var flip := 1.0 if rng.next_float() < 0.5 else -1.0
	var n := u.orthogonal() * flip
	var t := size * room * (1.0 + rng.range_float(-size_jitter, size_jitter))
	var m := length * (0.5 + rng.range_float(-shift, shift))
	var w := wobble * room
	var a := rng.range_float(-w, w)
	var c := rng.range_float(-w, w)
	var d := rng.range_float(-w, w)
	var e := rng.range_float(-w, w)
	# Along the edge in x, across it in y.
	var q := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.2 * length, a), Vector2(m + d, -t + c), Vector2(m - t, t + c),
		Vector2(m - 2.0 * t - d, 3.0 * t + c), Vector2(m + 2.0 * t - d, 3.0 * t + c), Vector2(m + t, t + c),
		Vector2(m + d, -t + c), Vector2(0.8 * length, e), Vector2(length, 0.0),
	])
	var points := PackedVector2Array([from])
	for curve in SEGMENTS.size():
		var segments := SEGMENTS[curve]
		var p0 := q[3 * curve]
		var p1 := q[3 * curve + 1]
		var p2 := q[3 * curve + 2]
		var p3 := q[3 * curve + 3]
		for i in range(1, segments + 1):
			var local := p0.bezier_interpolate(p1, p2, p3, i / float(segments))
			var p := from + u * local.x + n * local.y
			points.append(Vector2(snappedf(p.x, CutGenerator.PRECISION), snappedf(p.y, CutGenerator.PRECISION)))
	points[0] = from
	points[points.size() - 1] = to
	return points
