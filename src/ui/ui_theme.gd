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

const TITLE := &"Title"
const SHEET := &"Sheet"


static func weighted(path: String, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = load(path)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font


static func build(dark := Palette.is_dark()) -> Theme:
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
	var raised := _button_box(dark, BUTTON_DEPTH)
	theme.set_stylebox("normal", "Button", raised)
	theme.set_stylebox("hover", "Button", raised)
	var sunk := _button_box(dark, PRESSED_DEPTH)
	theme.set_stylebox("pressed", "Button", sunk)
	theme.set_stylebox("hover_pressed", "Button", sunk)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	theme.set_stylebox("panel", "PanelContainer", _panel_box(dark, PANEL_RADIUS, PANEL_PADDING))
	theme.add_type(SHEET)
	theme.set_type_variation(SHEET, &"PanelContainer")
	theme.set_stylebox("panel", SHEET, _panel_box(dark, SHEET_RADIUS, SHEET_PADDING))
	return theme


# A pressed button keeps its footprint: the top edge drops by the depth that was
# lost, so the label sinks while the bottom stays put.
static func _button_box(dark: bool, depth: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.accent(dark)
	box.border_color = Palette.accent_shadow(dark)
	box.border_width_bottom = depth
	box.set_corner_radius_all(BUTTON_RADIUS)
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
