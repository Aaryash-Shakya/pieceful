class_name CutPiece
extends RefCounted
## One piece of a cut. Geometry is never saved; it is regenerated from the seed.

var id: int
var outline: PackedVector2Array
var home: Vector2
var neighbours: PackedInt32Array


func area() -> float:
	var sum := 0.0
	var n := outline.size()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		sum += a.x * b.y - b.x * a.y
	return absf(sum) * 0.5


func bounds() -> Rect2:
	if outline.is_empty():
		return Rect2()
	var rect := Rect2(outline[0], Vector2.ZERO)
	for p in outline:
		rect = rect.expand(p)
	return rect
