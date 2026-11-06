extends "res://tests/base_test.gd"

const PATH := "user://test_settings_look.cfg"


func _init() -> void:
	await process_frame
	DirAccess.remove_absolute(PATH)
	_test_defaults()
	_test_round_trip()
	_test_bad_values()
	_test_accent_normalised()
	_test_current()
	DirAccess.remove_absolute(PATH)
	finish()


func _write(values: Dictionary) -> void:
	var file := ConfigFile.new()
	for key in values:
		file.set_value("look", key, values[key])
	file.save(PATH)


func _test_defaults() -> void:
	DirAccess.remove_absolute(PATH)
	var s := Settings.load_from(PATH)
	check(s.theme == "midnight" and s.mode == "auto", "theme and mode default")
	check(s.accent == "" and s.roundness == 100, "accent and roundness default")
	check(s.sound and s.vibration, "sound and vibration stay on")


func _test_round_trip() -> void:
	var s := Settings.new()
	s.theme = "berry"
	s.mode = "dark"
	s.accent = "#6fdc97"
	s.roundness = 160
	s.sound = false
	check(s.save_to(PATH) == OK, "saves")
	var back := Settings.load_from(PATH)
	check(back.theme == "berry", "theme round-trips")
	check(back.mode == "dark", "mode round-trips")
	check(back.accent == "#6fdc97", "accent round-trips")
	check(back.roundness == 160, "roundness round-trips")
	check(not back.sound, "sound round-trips")


func _test_bad_values() -> void:
	_write({"theme": "neon", "mode": 5, "accent": "red", "roundness": 900})
	var s := Settings.load_from(PATH)
	check(s.theme == "midnight", "unknown theme falls back")
	check(s.mode == "auto", "non-string mode falls back")
	check(s.accent == "", "bad accent falls back")
	check(s.roundness == 250, "roundness clamps high")
	_write({"roundness": -4})
	check(Settings.load_from(PATH).roundness == 0, "roundness clamps low")
	_write({"roundness": "wide"})
	check(Settings.load_from(PATH).roundness == 100, "non-number roundness falls back")


func _test_accent_normalised() -> void:
	_write({"accent": "#FFC857"})
	check(Settings.load_from(PATH).accent == "#ffc857", "accent is lowercased")
	check(not Settings.is_valid_accent("#ffc85"), "short accent is invalid")
	check(Settings.is_valid_accent("#ffc857"), "full accent is valid")
	check(not Settings.is_valid_accent(3), "non-string accent is invalid")


func _test_current() -> void:
	var first := Settings.current()
	check(first != null and Settings.current() == first, "current is stable")
	var s := Settings.new()
	Settings.use(s)
	check(Settings.current() == s, "use replaces current")
	Settings.use(Settings.new())
