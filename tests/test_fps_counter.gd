extends BaseTest


func _init() -> void:
	check(FpsCounter.format_text(59, 60.0, 0.0094) == "59 fps  60 Hz  worst 9 ms", "fps, refresh rate and worst frame")
	check(FpsCounter.format_text(120, 119.88, 0.0083) == "120 fps  120 Hz  worst 8 ms", "refresh rate is rounded")
	check(FpsCounter.format_text(30, -1.0, 0.0334) == "30 fps  worst 33 ms", "unknown refresh rate leaves out Hz")
	check(FpsCounter.format_text(60, 60.0, 0.040) == "60 fps  60 Hz  worst 40 ms", "one hitch shows even when the average is 60")

	finish()
