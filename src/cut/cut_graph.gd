class_name CutGraph
extends RefCounted
## Vertices plus faces. Every face winds the same way, so a shared edge is walked in opposite directions.

var vertices: PackedVector2Array
var faces: Array[PackedInt32Array] = []


static func edge_key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


func edge_use_counts() -> Dictionary:
	var counts := {}
	for face in faces:
		var n := face.size()
		for i in n:
			var key := edge_key(face[i], face[(i + 1) % n])
			counts[key] = counts.get(key, 0) + 1
	return counts
