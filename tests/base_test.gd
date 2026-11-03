extends SceneTree

var _failures: int = 0


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func finish() -> void:
	print("%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
