extends "res://tests/base_test.gd"


func _init() -> void:
	_test_font_files()
	_test_font_licence()
	_test_fonts_ship()
	_test_weighted()
	_test_theme(false)
	_test_theme(true)
	_test_modes_differ()
	_test_option_and_slider()
	_test_setup_styles()
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


func _test_option_and_slider() -> void:
	for dark in [false, true]:
		var tag := "(dark=%s) " % dark
		var t := UiTheme.build(dark)
		check(t.get_type_variation_base(UiTheme.OPTION) == &"Button", tag + "Option variation base")
		var n := t.get_stylebox("normal", UiTheme.OPTION) as StyleBoxFlat
		check(n != null, tag + "option normal is flat")
		if n != null:
			check(n.bg_color == Palette.raised_surface(dark), tag + "option fill")
			check(n.border_color == Palette.lines(dark), tag + "option line")
			check(n.corner_radius_top_left == 9, tag + "option radius")
		var p := t.get_stylebox("pressed", UiTheme.OPTION) as StyleBoxFlat
		check(p != null, tag + "option pressed is flat")
		if p != null:
			check(p.bg_color == Palette.accent(dark), tag + "option pressed fill")
			check(p.border_color == Palette.accent_shadow(dark), tag + "option pressed edge")
		check(t.get_color("font_color", UiTheme.OPTION) == Palette.text(dark), tag + "option text")
		check(t.get_color("font_pressed_color", UiTheme.OPTION) == Palette.text_on_accent(dark), tag + "option pressed text")

		var grabber := t.get_icon("grabber", "HSlider")
		check(grabber != null and grabber.get_size() == Vector2(44, 30), tag + "grabber size")
		if grabber != null:
			var image := grabber.get_image()
			check(image.get_pixel(22, 15).is_equal_approx(Palette.accent(dark)), tag + "grabber centre is the accent")
			check(image.get_pixel(0, 0).a == 0.0, tag + "grabber corner is clear")
		var area := t.get_stylebox("grabber_area", "HSlider") as StyleBoxFlat
		check(area != null and area.bg_color == Palette.accent(dark), tag + "slider fill is the accent")
		var track := t.get_stylebox("slider", "HSlider") as StyleBoxFlat
		check(track != null and track.bg_color == Palette.raised_surface(dark), tag + "slider track")


func _test_setup_styles() -> void:
	for dark in [false, true]:
		var tag := "(dark=%s) " % dark
		var t := UiTheme.build(dark)
		var n := t.get_stylebox("normal", UiTheme.OPTION) as StyleBoxFlat
		var h := t.get_stylebox("hover", UiTheme.OPTION) as StyleBoxFlat
		var p := t.get_stylebox("pressed", UiTheme.OPTION) as StyleBoxFlat
		var hp := t.get_stylebox("hover_pressed", UiTheme.OPTION) as StyleBoxFlat
		check(n != null and h != null and p != null and hp != null, tag + "option styleboxes are flat")
		if n == null or h == null or p == null or hp == null:
			continue
		check(h.bg_color == n.bg_color and h.border_color == n.border_color and h.border_width_left == 1, tag + "option hover matches normal")
		check(n.border_width_left == UiTheme.LINE_WIDTH and n.border_width_bottom == UiTheme.LINE_WIDTH, tag + "option line width")
		check(p.corner_radius_top_left == 9 and p.corner_radius_bottom_right == 9, tag + "option pressed radius")
		check(p.border_width_bottom == UiTheme.BUTTON_DEPTH, tag + "option pressed shadow edge")
		check(hp.bg_color == p.bg_color and hp.border_color == p.border_color and hp.corner_radius_top_left == 9 \
				and hp.border_width_bottom == p.border_width_bottom, tag + "option hover pressed matches pressed")
		check(p.content_margin_top == n.content_margin_top and p.content_margin_bottom == n.content_margin_bottom \
				and p.content_margin_left == n.content_margin_left, tag + "option keeps its footprint when pressed")
		check(t.get_color("font_hover_color", UiTheme.OPTION) == Palette.text(dark), tag + "option hover text")
		check(t.get_color("font_hover_pressed_color", UiTheme.OPTION) == Palette.text_on_accent(dark), tag + "option hover pressed text")

		var track := t.get_stylebox("slider", "HSlider") as StyleBoxFlat
		check(track != null and track.content_margin_top == 5 and track.content_margin_bottom == 5, tag + "slider track is 10 px")
		check(track != null and track.corner_radius_top_left == 6, tag + "slider track radius")
		var highlight_area := t.get_stylebox("grabber_area_highlight", "HSlider") as StyleBoxFlat
		check(highlight_area != null and highlight_area.bg_color == Palette.accent(dark), tag + "slider highlight fill")
		var highlight := t.get_icon("grabber_highlight", "HSlider")
		check(highlight != null and highlight.get_size() == Vector2(UiTheme.GRABBER_SIZE), tag + "grabber highlight size")
		if highlight != null:
			var image := highlight.get_image()
			check(image.get_pixel(22, 15).is_equal_approx(Palette.accent(dark)), tag + "grabber highlight is the accent")
			check(image.get_pixel(43, 29).a == 0.0, tag + "grabber highlight corner is clear")

		var disabled := t.get_stylebox("disabled", "Button") as StyleBoxFlat
		check(disabled != null, tag + "disabled button is flat")
		if disabled != null:
			check(is_equal_approx(disabled.bg_color.a, UiTheme.DISABLED_ALPHA), tag + "disabled button fades")
			check(Color(disabled.bg_color, 1.0) == Palette.accent(dark), tag + "disabled button keeps the accent")
			check(disabled.corner_radius_top_left == UiTheme.BUTTON_RADIUS, tag + "disabled button radius")
		var faded := t.get_color("font_disabled_color", "Button")
		check(is_equal_approx(faded.a, UiTheme.DISABLED_ALPHA) and Color(faded, 1.0) == Palette.text_on_accent(dark), tag + "disabled button text")
