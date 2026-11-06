extends "res://tests/base_test.gd"
## Safe-area insets: window pixels in, viewport units out, never negative.


func _init() -> void:
	await process_frame
	_test_notch()
	_test_sides()
	_test_no_safe_area()
	_test_oversized_safe_rect()
	_test_current_is_not_negative()
	finish()


func _test_notch() -> void:
	var got := SafeArea.insets(Vector2i(1080, 2400), Rect2i(0, 90, 1080, 2250), Vector2(540, 1200))
	check(got == Vector4(0, 45, 0, 30), "notch insets scale to viewport units, got %s" % got)


func _test_sides() -> void:
	var got := SafeArea.insets(Vector2i(1080, 2400), Rect2i(40, 0, 1020, 2400), Vector2(540, 1200))
	check(got == Vector4(20, 0, 10, 0), "side insets, got %s" % got)


func _test_no_safe_area() -> void:
	check(SafeArea.insets(Vector2i(1080, 2400), Rect2i(), Vector2(540, 1200)) == Vector4.ZERO, "empty safe rect gives zero")
	check(SafeArea.insets(Vector2i.ZERO, Rect2i(0, 0, 10, 10), Vector2(540, 1200)) == Vector4.ZERO, "zero window gives zero")


func _test_oversized_safe_rect() -> void:
	var got := SafeArea.insets(Vector2i(1080, 2400), Rect2i(-50, -50, 2000, 3000), Vector2(540, 1200))
	check(got == Vector4.ZERO, "oversized safe rect is clamped, got %s" % got)


func _test_current_is_not_negative() -> void:
	var got := SafeArea.current(self)
	check(got.x >= 0.0 and got.y >= 0.0 and got.z >= 0.0 and got.w >= 0.0, "current insets are not negative, got %s" % got)
