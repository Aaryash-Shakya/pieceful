class_name SafeArea
extends RefCounted
## Notch and gesture-bar insets in viewport units, so screens can pad themselves clear of them.


## (left, top, right, bottom). The OS reports the safe rect in window pixels; the UI lives in viewport units.
static func insets(window_size: Vector2i, safe_rect: Rect2i, viewport_size: Vector2) -> Vector4:
	if window_size.x <= 0 or window_size.y <= 0 or safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return Vector4.ZERO
	var safe := safe_rect.intersection(Rect2i(Vector2i.ZERO, window_size))
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var scale := viewport_size / Vector2(window_size)
	return Vector4(
		safe.position.x * scale.x,
		safe.position.y * scale.y,
		(window_size.x - safe.end.x) * scale.x,
		(window_size.y - safe.end.y) * scale.y)


static func current(tree: SceneTree) -> Vector4:
	return insets(
		DisplayServer.window_get_size(),
		DisplayServer.get_display_safe_area(),
		tree.root.get_visible_rect().size)
