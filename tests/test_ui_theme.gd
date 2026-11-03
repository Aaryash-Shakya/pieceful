extends "res://tests/base_test.gd"


func _init() -> void:
	_test_font_files()
	_test_font_licence()
	_test_fonts_ship()
	_test_weighted()
	_test_theme(false)
	_test_theme(true)
	_test_modes_differ()
	finish()


func _test_font_files() -> void:
	for path in [UiTheme.BALOO_PATH, UiTheme.QUICKSAND_PATH]:
		check(FileAccess.file_exists(path), "%s exists" % path)
		check(load(path) is FontFile, "%s loads as FontFile" % path)
	for path in ["res://assets/fonts/OFL-Baloo2.txt", "res://assets/fonts/OFL-Quicksand.txt"]:
		check(FileAccess.file_exists(path), "%s exists" % path)
		check(FileAccess.get_file_as_string(path).contains("SIL OPEN FONT LICENSE"), "%s holds the licence" % path)


func _test_font_licence() -> void:
	var path := "res://assets/fonts/LICENSE.md"
	check(FileAccess.file_exists(path), "fonts LICENSE.md exists")
	var text := FileAccess.get_file_as_string(path)
	for needle in ["SIL Open Font License", "Baloo 2", "Quicksand", "github.com/google/fonts"]:
		check(text.contains(needle), "LICENSE.md mentions %s" % needle)
	for font in [UiTheme.BALOO_PATH, UiTheme.QUICKSAND_PATH]:
		check(text.contains(FileAccess.get_sha256(font)), "recorded sum matches %s" % font)


func _test_fonts_ship() -> void:
	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "export presets load")
	check(String(cfg.get_value("preset.0", "include_filter", "")).contains("assets/fonts/*.txt"), "licence texts are exported")


func _wght() -> int:
	return TextServerManager.get_primary_interface().name_to_tag("wght")


func _test_weighted() -> void:
	var f := UiTheme.weighted(UiTheme.QUICKSAND_PATH, 600)
	check(f.base_font.resource_path == UiTheme.QUICKSAND_PATH, "weighted base font path")
	check(f.variation_opentype[_wght()] == 600, "weighted wght axis")


func _weight_of(font: Font) -> int:
	return (font as FontVariation).variation_opentype[_wght()]


func _base_path_of(font: Font) -> String:
	return (font as FontVariation).base_font.resource_path


func _test_theme(dark: bool) -> void:
	var tag := "(dark=%s) " % dark
	var t := UiTheme.build(dark)
	var n := t.get_stylebox("normal", "Button") as StyleBoxFlat
	var p := t.get_stylebox("pressed", "Button") as StyleBoxFlat
	check(n != null and p != null, tag + "button styleboxes are flat")
	if n == null or p == null:
		return

	check(_base_path_of(t.default_font) == UiTheme.QUICKSAND_PATH, tag + "default font is Quicksand")
	check(_weight_of(t.default_font) == 600, tag + "default weight")
	check(t.default_font_size == 20, tag + "default size")
	check(t.get_color("font_color", "Label") == Palette.text(dark), tag + "label colour")

	var bf := t.get_font("font", "Button")
	check(_base_path_of(bf) == UiTheme.BALOO_PATH, tag + "button font is Baloo")
	check(_weight_of(bf) == 700, tag + "button weight")
	check(t.get_font_size("font_size", "Button") == 22, tag + "button size")
	check(t.get_color("font_color", "Button") == Palette.text_on_accent(dark), tag + "button font colour")
	check(t.get_color("font_pressed_color", "Button") == Palette.text_on_accent(dark), tag + "button pressed font colour")

	check(n.bg_color == Palette.accent(dark), tag + "button fill")
	check(n.border_color == Palette.accent_shadow(dark), tag + "button shadow")
	check(n.border_width_bottom == 5, tag + "button depth")
	check(n.border_width_top == 0, tag + "button top border")
	check(n.corner_radius_top_left == 8 and n.corner_radius_bottom_right == 8, tag + "button radius")

	check(p.border_width_bottom == 1, tag + "pressed depth")
	check(p.expand_margin_top == -4, tag + "pressed expand margin top")
	check(p.content_margin_top - n.content_margin_top == 4, tag + "pressed text sinks")
	check(p.content_margin_top + p.content_margin_bottom == n.content_margin_top + n.content_margin_bottom, tag + "pressed keeps height")
	check(p.bg_color == n.bg_color, tag + "pressed fill")

	var h := t.get_stylebox("hover", "Button") as StyleBoxFlat
	check(h != null and h.bg_color == n.bg_color, tag + "hover matches normal")
	var hp := t.get_stylebox("hover_pressed", "Button") as StyleBoxFlat
	check(hp != null and hp.border_width_bottom == p.border_width_bottom and hp.expand_margin_top == p.expand_margin_top \
			and hp.content_margin_top == p.content_margin_top, tag + "hover pressed matches pressed")
	check(t.get_stylebox("focus", "Button") is StyleBoxEmpty, tag + "focus is empty")

	var panel := t.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	check(panel != null and panel.bg_color == Palette.surface(dark), tag + "panel fill")
	if panel != null:
		check(panel.border_color == Palette.lines(dark), tag + "panel line")
		check(panel.border_width_left == 1, tag + "panel border")
		check(panel.corner_radius_top_left == 10, tag + "panel radius")
	check(t.get_type_variation_base(UiTheme.SHEET) == &"PanelContainer", tag + "Sheet variation base")
	var sheet := t.get_stylebox("panel", "Sheet") as StyleBoxFlat
	check(sheet != null and sheet.corner_radius_top_left == 14, tag + "sheet radius")
	check(sheet != null and sheet.bg_color == Palette.surface(dark), tag + "sheet fill")

	check(t.get_type_variation_base(UiTheme.TITLE) == &"Label", tag + "Title variation base")
	var tf := t.get_font("font", "Title")
	check(_base_path_of(tf) == UiTheme.BALOO_PATH, tag + "title font")
	check(_weight_of(tf) == 800, tag + "title weight")
	check(t.get_font_size("font_size", "Title") == 28, tag + "title size")


func _test_modes_differ() -> void:
	var a := UiTheme.build(false).get_stylebox("normal", "Button") as StyleBoxFlat
	var b := UiTheme.build(true).get_stylebox("normal", "Button") as StyleBoxFlat
	check(a.bg_color != b.bg_color, "light and dark buttons differ")
