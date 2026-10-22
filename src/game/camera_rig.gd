class_name CameraRig
extends RefCounted
## Pure zoom, clamp and edge-pan math for the world camera, kept free of nodes so it can be tested headless.

const MIN_ZOOM := 0.15
const MAX_ZOOM := 3.0


static func clamp_zoom(zoom: float) -> float:
	return clampf(zoom, MIN_ZOOM, MAX_ZOOM)


## Keeps the camera centre inside bounds so the board and loose pieces can never be lost.
static func clamp_position(position: Vector2, bounds: Rect2) -> Vector2:
	return position.clamp(bounds.position, bounds.end)


## New camera position that keeps the world point under the anchor fixed.
## anchor_offset is the anchor's screen position minus the viewport centre.
static func zoom_about(camera_position: Vector2, old_zoom: float, new_zoom: float, anchor_offset: Vector2) -> Vector2:
	return camera_position + anchor_offset * (1.0 / old_zoom - 1.0 / new_zoom)


## Screen pixels per second toward the edge being approached: zero beyond margin from
## every edge, max_speed at the edge, linear in between.
static func edge_pan_velocity(screen_position: Vector2, viewport_size: Vector2, margin: float, max_speed: float) -> Vector2:
	return Vector2(
		_edge_axis(screen_position.x, viewport_size.x, margin, max_speed),
		_edge_axis(screen_position.y, viewport_size.y, margin, max_speed)
	)


static func _edge_axis(coord: float, extent: float, margin: float, max_speed: float) -> float:
	var near_low := clampf((margin - coord) / margin, 0.0, 1.0)
	var near_high := clampf((margin - (extent - coord)) / margin, 0.0, 1.0)
	return (near_high - near_low) * max_speed
