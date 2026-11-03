extends "res://tests/base_test.gd"


func _init() -> void:
	check(Palette.felt(false) == Color.html("#223a63"), "felt light")
	check(Palette.felt(true) == Color.html("#14264a"), "felt dark")
	check(Palette.board(false) == Color.html("#2c4878"), "board light")
	check(Palette.board(true) == Color.html("#1c3463"), "board dark")
	check(Palette.accent(false) == Color.html("#e2a41f"), "accent light")
	check(Palette.accent(true) == Color.html("#ffc857"), "accent dark")
	check(is_equal_approx(Palette.outline().a, 0.8), "outline is 80% alpha")
	check(Palette.felt() == Palette.felt(Palette.is_dark()), "default argument follows the device mode")

	finish()
