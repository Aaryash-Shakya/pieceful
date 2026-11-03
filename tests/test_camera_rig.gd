extends "res://tests/base_test.gd"


func _init() -> void:
	check(CameraRig.zoom_about(Vector2(100, 50), 1.0, 2.0, Vector2(40, 20)) == Vector2(120, 60), "zoom_about keeps the anchored world point fixed")
	check(CameraRig.zoom_about(Vector2(100, 50), 2.0, 2.0, Vector2(40, 20)) == Vector2(100, 50), "unchanged zoom leaves the camera where it was")

	check(CameraRig.clamp_zoom(0.01) == CameraRig.MIN_ZOOM, "zoom clamps to the minimum")
	check(CameraRig.clamp_zoom(99.0) == CameraRig.MAX_ZOOM, "zoom clamps to the maximum")
	check(CameraRig.clamp_zoom(1.0) == 1.0, "zoom inside the range is unchanged")

	var bounds := Rect2(-100, -100, 200, 200)
	check(CameraRig.clamp_position(Vector2(500, -500), bounds) == Vector2(100, -100), "position clamps to the bounds")
	check(CameraRig.clamp_position(Vector2(10, 20), bounds) == Vector2(10, 20), "position inside the bounds is unchanged")

	var view := Vector2(540, 1200)
	var left := CameraRig.edge_pan_velocity(Vector2(5, 600), view, 48.0, 600.0)
	check(is_equal_approx(left.x, -537.5) and left.y == 0.0, "left edge pans left, linear in the margin")
	check(CameraRig.edge_pan_velocity(Vector2(270, 600), view, 48.0, 600.0) == Vector2.ZERO, "no pan away from the edges")
	var corner := CameraRig.edge_pan_velocity(Vector2(535, 1195), view, 48.0, 600.0)
	check(corner.x > 0.0 and corner.y > 0.0, "bottom-right corner pans both ways")
	var at_edge := CameraRig.edge_pan_velocity(Vector2(0, 600), view, 48.0, 600.0)
	check(is_equal_approx(at_edge.x, -600.0), "full speed at the very edge")

	finish()
