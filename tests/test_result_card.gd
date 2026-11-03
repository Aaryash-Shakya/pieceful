extends "res://tests/base_test.gd"


func _init() -> void:
	check(ResultCard.format_time(0.0) == "0:00", "zero")
	check(ResultCard.format_time(59.99) == "0:59", "rounds down, never up")
	check(ResultCard.format_time(83.4) == "1:23", "minutes and seconds")
	check(ResultCard.format_time(754.0) == "12:34", "the owner's example time")
	check(ResultCard.format_time(3600.0) == "1:00:00", "an hour")
	check(ResultCard.format_time(3725.0) == "1:02:05", "hours, padded minutes and seconds")
	check(ResultCard.format_time(-5.0) == "0:00", "never negative")
	check(ResultCard.pieces_text(1) == "1 piece" and ResultCard.pieces_text(150) == "150 pieces", "plural")
	check(ResultCard.style_name("irregular") == "Irregular" and ResultCard.style_name("wild") == "Wild", "style names")

	var puzzle := SaveGame.Puzzle.new()
	puzzle.piece_count = 150
	puzzle.style = CutGenerator.STYLE_IRREGULAR
	check(puzzle.ghost, "ghost is on by default")
	var text := ResultCard.share_text("Ember Rings", puzzle, 754.2)
	check(text == "Pieceful\nEmber Rings\n150 pieces · Irregular\nGhost on · 12:34", "share text: %s" % text)
	puzzle.ghost = false
	check(ResultCard.share_text("Ember Rings", puzzle, 754.2).ends_with("Ghost off · 12:34"), "ghost off shows on the card")

	var path := "user://test_settings.cfg"
	DirAccess.remove_absolute(path)
	check(Settings.load_from(path).sound and Settings.load_from(path).vibration, "no file gives the defaults")
	var s := Settings.new()
	s.sound = false
	check(s.save_to(path) == OK, "settings save")
	var back := Settings.load_from(path)
	check(not back.sound and back.vibration, "settings come back")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[feedback]\nsound=3\nvibration=false\n")
	f.close()
	back = Settings.load_from(path)
	check(back.sound and not back.vibration, "a wrong type falls back to the default for that key only")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("not a config {")
	f.close()
	check(Settings.load_from(path).sound, "a damaged file gives the defaults")
	DirAccess.remove_absolute(path)

	check(not Share.available() or Engine.has_singleton(Share.PLUGIN), "share availability follows the plugin")
	finish()
