extends BaseTest


func _init() -> void:
	check(FpsCounter.format_text(59, 60.0) == "59 fps  60 Hz", "fps and refresh rate")
	check(FpsCounter.format_text(120, 119.88) == "120 fps  120 Hz", "refresh rate is rounded")
	check(FpsCounter.format_text(30, -1.0) == "30 fps", "unknown refresh rate shows fps only")

	finish()
