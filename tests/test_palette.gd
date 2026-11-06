extends "res://tests/base_test.gd"

const EXPECTED := {
	"midnight": [
		["#e7e9f0", "#f6f7fb", "#dbdfea", "#141b2d", "#566079", "#c9cfdd", "#e2a41f", "#2a1d00", "#a87612", "#223a63", "#2c4878"],
		["#0b1020", "#131a2e", "#1c2540", "#e9edf7", "#8d98b5", "#27314f", "#ffc857", "#2a1d00", "#b58712", "#14264a", "#1c3463"],
	],
	"orchard": [
		["#e6ece4", "#f5f8f3", "#d7e0d3", "#16241a", "#516052", "#c5d1c0", "#2f9e5b", "#ffffff", "#1f6e3f", "#2b5a3e", "#35704c"],
		["#0c150f", "#142019", "#1d2e23", "#e5f1e8", "#8aa493", "#27402f", "#6fdc97", "#06210f", "#3fa365", "#163524", "#1f4a31"],
	],
	"berry": [
		["#efe6ee", "#faf5fa", "#e3d5e2", "#2a1428", "#6b5068", "#d6c4d4", "#c4348f", "#ffffff", "#8d2266", "#4a2a5e", "#5b3873"],
		["#150a18", "#201125", "#2d1a34", "#f3e8f5", "#aa8fb0", "#3e2548", "#ff7ac8", "#2a0620", "#b8478f", "#2a1640", "#3b2260"],
	],
	"slate": [
		["#e8eaec", "#f7f8f9", "#dadde1", "#16191d", "#5c636b", "#cdd1d6", "#0f8f9a", "#ffffff", "#0b636b", "#2c3a45", "#3a4b58"],
		["#0c0f12", "#15191d", "#1f252b", "#e8ecef", "#8f98a1", "#2b333b", "#3fd1dc", "#03262a", "#26959e", "#18222a", "#243440"],
	],
}


func _init() -> void:
	Settings.use(Settings.new())
	check(Palette.felt(false) == Color.html("#223a63"), "felt light")
	check(Palette.felt(true) == Color.html("#14264a"), "felt dark")
	check(Palette.board(false) == Color.html("#2c4878"), "board light")
	check(Palette.board(true) == Color.html("#1c3463"), "board dark")
	check(Palette.accent(false) == Color.html("#e2a41f"), "accent light")
	check(Palette.accent(true) == Color.html("#ffc857"), "accent dark")
	check(is_equal_approx(Palette.outline().a, 0.8), "outline is 80% alpha")
	check(Palette.felt() == Palette.felt(Palette.is_dark()), "default argument follows the device mode")
	check(Palette.page_background(false) == Color.html("#e7e9f0"), "page_background light")
	check(Palette.page_background(true) == Color.html("#0b1020"), "page_background dark")
	check(Palette.surface(false) == Color.html("#f6f7fb"), "surface light")
	check(Palette.surface(true) == Color.html("#131a2e"), "surface dark")
	check(Palette.raised_surface(false) == Color.html("#dbdfea"), "raised_surface light")
	check(Palette.raised_surface(true) == Color.html("#1c2540"), "raised_surface dark")
	check(Palette.text(false) == Color.html("#141b2d"), "text light")
	check(Palette.text(true) == Color.html("#e9edf7"), "text dark")
	check(Palette.muted_text(false) == Color.html("#566079"), "muted_text light")
	check(Palette.muted_text(true) == Color.html("#8d98b5"), "muted_text dark")
	check(Palette.lines(false) == Color.html("#c9cfdd"), "lines light")
	check(Palette.lines(true) == Color.html("#27314f"), "lines dark")
	check(Palette.text_on_accent(false) == Color.html("#2a1d00"), "text_on_accent light")
	check(Palette.text_on_accent(true) == Color.html("#2a1d00"), "text_on_accent dark")
	check(Palette.accent_shadow(false) == Color.html("#a87612"), "accent_shadow light")
	check(Palette.accent_shadow(true) == Color.html("#b58712"), "accent_shadow dark")
	check(Palette.text() == Palette.text(Palette.is_dark()), "text follows the device mode")

	_test_themes()
	_test_unknown_theme()
	_test_settings_drive_palette()
	_test_mode()
	_test_accent_override()
	_test_accent_contrast()
	Settings.use(Settings.new())

	finish()


func _with(theme := "midnight", mode := "auto", accent := "") -> void:
	var s := Settings.new()
	s.theme = theme
	s.mode = mode
	s.accent = accent
	Settings.use(s)


func _test_themes() -> void:
	for id in EXPECTED:
		for m in 2:
			for role in 11:
				var want := Color.html(EXPECTED[id][m][role])
				check(PaletteThemes.color(id, m == 1, role) == want, "%s %s role %d" % [id, "dark" if m == 1 else "light", role])


func _test_unknown_theme() -> void:
	check(PaletteThemes.color("nope", false, PaletteThemes.Role.ACCENT) == Color.html("#e2a41f"), "unknown theme falls back to midnight")


func _test_settings_drive_palette() -> void:
	_with("berry")
	check(Palette.accent(true) == Color.html("#ff7ac8"), "berry accent dark")
	check(Palette.felt(false) == Color.html("#4a2a5e"), "berry felt light")
	Settings.use(Settings.new())


func _test_mode() -> void:
	_with("midnight", "dark")
	check(Palette.is_dark(), "mode dark")
	_with("midnight", "light")
	check(not Palette.is_dark(), "mode light")
	Settings.use(Settings.new())


func _test_accent_override() -> void:
	_with("midnight", "auto", "#6fdc97")
	var base := Color.html("#6fdc97")
	for dark in [false, true]:
		check(Palette.accent(dark) == base, "accent override %s" % dark)
		var sh := Palette.accent_shadow(dark)
		check(absf(sh.r - base.r * 0.62) < 0.001 and absf(sh.g - base.g * 0.62) < 0.001 and absf(sh.b - base.b * 0.62) < 0.001, "accent shadow %s" % dark)
	Settings.use(Settings.new())


func _test_accent_contrast() -> void:
	for dark in [false, true]:
		_with("midnight", "auto", "#ffc857")
		check(Palette.text_on_accent(dark) == Color.html("#1c1400"), "light accent gets dark text %s" % dark)
		_with("midnight", "auto", "#7a1fd6")
		check(Palette.text_on_accent(dark) == Color.WHITE, "dark accent gets white text %s" % dark)
	_with()
	check(Palette.text_on_accent(false) == Color.html("#2a1d00"), "no accent override restores theme text")
	Settings.use(Settings.new())
