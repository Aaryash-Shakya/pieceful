class_name UiTheme
extends RefCounted
## The one Theme every screen uses: bundled fonts, Midnight colours and the
## 3D-edged buttons from docs/visual-design.md. Built in code so the colours
## follow the palette functions instead of being copied into a .tres.

const BALOO_PATH := "res://assets/fonts/Baloo2-Variable.ttf"
const QUICKSAND_PATH := "res://assets/fonts/Quicksand-Variable.ttf"

const BODY_WEIGHT := 600
const BUTTON_WEIGHT := 700
const TITLE_WEIGHT := 800
const BODY_FONT_SIZE := 20
const BUTTON_FONT_SIZE := 22
const TITLE_FONT_SIZE := 28

const BUTTON_RADIUS := 8
const PANEL_RADIUS := 10
const SHEET_RADIUS := 14
const BUTTON_DEPTH := 5
const PRESSED_DEPTH := 1
const BUTTON_PADDING_X := 20
const BUTTON_PADDING_Y := 8
const PANEL_PADDING := 12
const SHEET_PADDING := 20
const LINE_WIDTH := 1
const OPTION_RADIUS := 9
const OPTION_PADDING := 8
const SLIDER_RADIUS := 6
const SLIDER_TRACK_MARGIN := 5
const GRABBER_SIZE := Vector2i(44, 30)
const DISABLED_ALPHA := 0.45

const TITLE := &"Title"
const SHEET := &"Sheet"
const OPTION := &"Option"


static func weighted(path: String, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = load(path)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font


static func scaled(base: int, roundness: int) -> int:
	return roundi(base * roundness / 100.0)


static func build(dark := Palette.is_dark(), roundness := Settings.current().roundness) -> Theme:
	var theme := Theme.new()
	theme.default_font = weighted(QUICKSAND_PATH, BODY_WEIGHT)
	theme.default_font_size = BODY_FONT_SIZE
	theme.set_color("font_color", "Label", Palette.text(dark))

	theme.add_type(TITLE)
	theme.set_type_variation(TITLE, &"Label")
	theme.set_font("font", TITLE, weighted(BALOO_PATH, TITLE_WEIGHT))
	theme.set_font_size("font_size", TITLE, TITLE_FONT_SIZE)
	theme.set_color("font_color", TITLE, Palette.text(dark))

	theme.set_font("font", "Button", weighted(BALOO_PATH, BUTTON_WEIGHT))
	theme.set_font_size("font_size", "Button", BUTTON_FONT_SIZE)
	for color_name in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "Button", Palette.text_on_accent(dark))
	var raised := _button_box(dark, BUTTON_DEPTH, scaled(BUTTON_RADIUS, roundness))
	theme.set_stylebox("normal", "Button", raised)
	theme.set_stylebox("hover", "Button", raised)
	var sunk := _button_box(dark, PRESSED_DEPTH, scaled(BUTTON_RADIUS, roundness))
	theme.set_stylebox("pressed", "Button", sunk)
	theme.set_stylebox("hover_pressed", "Button", sunk)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var faded := _button_box(dark, BUTTON_DEPTH, scaled(BUTTON_RADIUS, roundness))
	faded.bg_color.a = DISABLED_ALPHA
	faded.border_color.a = DISABLED_ALPHA
	theme.set_stylebox("disabled", "Button", faded)
	var faded_text := Palette.text_on_accent(dark)
	faded_text.a = DISABLED_ALPHA
	theme.set_color("font_disabled_color", "Button", faded_text)

	_add_option(theme, dark, roundness)
	_add_slider(theme, dark, roundness)

	theme.set_stylebox("panel", "PanelContainer", _panel_box(dark, scaled(PANEL_RADIUS, roundness), PANEL_PADDING))
	theme.add_type(SHEET)
	theme.set_type_variation(SHEET, &"PanelContainer")
	theme.set_stylebox("panel", SHEET, _panel_box(dark, scaled(SHEET_RADIUS, roundness), SHEET_PADDING))
	return theme


# A pressed button keeps its footprint: the top edge drops by the depth that was
# lost, so the label sinks while the bottom stays put.
static func _button_box(dark: bool, depth: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.accent(dark)
	box.border_color = Palette.accent_shadow(dark)
	box.border_width_bottom = depth
	box.set_corner_radius_all(radius)
	var sunk := BUTTON_DEPTH - depth
	box.expand_margin_top = -sunk
	box.content_margin_left = BUTTON_PADDING_X
	box.content_margin_right = BUTTON_PADDING_X
	box.content_margin_top = BUTTON_PADDING_Y + sunk
	box.content_margin_bottom = BUTTON_PADDING_Y + depth
	return box


static func _panel_box(dark: bool, radius: int, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.surface(dark)
	box.border_color = Palette.lines(dark)
	box.set_border_width_all(LINE_WIDTH)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	return box


# Option tiles (pictures, styles) keep one footprint on and off: equal content margins, and the
# accent's shadow edge is drawn inside the box where the off tile has its line.
static func _add_option(theme: Theme, dark: bool, roundness: int) -> void:
	theme.add_type(OPTION)
	theme.set_type_variation(OPTION, &"Button")
	var off := StyleBoxFlat.new()
	off.bg_color = Palette.raised_surface(dark)
	off.border_color = Palette.lines(dark)
	off.set_border_width_all(LINE_WIDTH)
	off.set_corner_radius_all(scaled(OPTION_RADIUS, roundness))
	off.set_content_margin_all(OPTION_PADDING)
	theme.set_stylebox("normal", OPTION, off)
	theme.set_stylebox("hover", OPTION, off)
	var on := _button_box(dark, BUTTON_DEPTH, scaled(OPTION_RADIUS, roundness))
	on.set_content_margin_all(OPTION_PADDING)
	theme.set_stylebox("pressed", OPTION, on)
	theme.set_stylebox("hover_pressed", OPTION, on)
	for color_name in ["font_color", "font_hover_color", "font_focus_color"]:
		theme.set_color(color_name, OPTION, Palette.text(dark))
	for color_name in ["font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(color_name, OPTION, Palette.text_on_accent(dark))


static func _add_slider(theme: Theme, dark: bool, roundness: int) -> void:
	var track := _flat(Palette.raised_surface(dark), scaled(SLIDER_RADIUS, roundness))
	theme.set_stylebox("slider", "HSlider", track)
	var fill := _flat(Palette.accent(dark), scaled(SLIDER_RADIUS, roundness))
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grabber := _rounded_tile(GRABBER_SIZE, scaled(OPTION_RADIUS, roundness), Palette.accent(dark))
	theme.set_icon("grabber", "HSlider", grabber)
	theme.set_icon("grabber_highlight", "HSlider", grabber)


# The slider takes the track's height from its content margins.
static func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_top = SLIDER_TRACK_MARGIN
	box.content_margin_bottom = SLIDER_TRACK_MARGIN
	return box


# Slider icons are textures, not styleboxes, so the rounded grabber is painted here. A corner pixel
# keeps the share of it inside the radius, which smooths the curve.
static func _rounded_tile(tile_size: Vector2i, radius: int, color: Color) -> ImageTexture:
	var image := Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	# The radius is capped at half the short side so a high roundness gives a pill, not a lopsided blob.
	# At radius 0 the coverage maths below would leave the corner pixels half clear.
	if radius <= 0:
		return ImageTexture.create_from_image(image)
	var r := float(mini(radius, mini(tile_size.x, tile_size.y) / 2))
	for y in tile_size.y:
		for x in tile_size.x:
			var p := Vector2(x + 0.5, y + 0.5)
			var centre := Vector2(clampf(p.x, r, tile_size.x - r), clampf(p.y, r, tile_size.y - r))
			var coverage := clampf(r - p.distance_to(centre) + 0.5, 0.0, 1.0)
			if coverage < 1.0:
				image.set_pixel(x, y, Color(color, color.a * coverage))
	return ImageTexture.create_from_image(image)
