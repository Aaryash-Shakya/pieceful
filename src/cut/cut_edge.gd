class_name CutEdge
extends RefCounted
## One edge shared by up to two faces. Both faces read the same points, one of them backwards.

var id: int
var from_vertex: int
var to_vertex: int
## The face that walks from_vertex to to_vertex.
var face_a: int
## The face that walks it backwards, or -1 on the border.
var face_b: int = -1
## Starts at from_vertex's position and ends at to_vertex's. A straight edge holds just those two.
var points: PackedVector2Array


func is_border() -> bool:
	return face_b == -1
