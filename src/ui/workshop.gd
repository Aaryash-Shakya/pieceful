class_name Workshop
extends RefCounted
## The Workshop look's parts from docs/prototype/workshop.html: peach paper, chocolate wells, wooden
## frames, ribbons and chunky coloured keys. The mockup is one deliberate world, so these colours are
## fixed here rather than read from the palette, which still sets the page, text and accent roles.

const RUST_HI := Color("#e0662c")
const RUST := Color("#a8380f")
const RUST_LO := Color("#7a2608")
const PEACH_HI := Color("#ffe0ac")
const PEACH := Color("#fdc47a")
const PEACH_LO := Color("#e9a352")
const PEACH_EDGE := Color("#c47f2f")
const CHOC := Color("#43160a")
const CHOC_2 := Color("#5e2410")
const CHOC_3 := Color("#7a3418")
const RIM := Color("#d27a2a")
const WOOD := Color("#c97a35")
const WOOD_LO := Color("#8a4a1c")
const LIME := Color("#4cc417")
const LIME_LO := Color("#2c8209")
const ORANGE := Color("#e5612a")
const ORANGE_LO := Color("#a33e12")
const TAB := Color("#e07a2c")
const TAB_LO := Color("#a3480f")
const SUN := Color("#ffd21f")
const SUN_LO := Color("#c79b00")
const RED := Color("#f0321e")
const RED_LO := Color("#a3150a")
const INK := Color("#4a1d08")
## A groove cut into a chocolate well, for bars and slider tracks.
const GROOVE := Color("#260a03")
const CREAM := Color("#fff3dc")
const CREAM_DIM := Color("#f3cfa3")

const ORANGE_BUTTON := &"OrangeButton"
const SUN_BUTTON := &"SunButton"
const RED_BUTTON := &"RedButton"
## A round lime key holding one icon.
const ROUND_BUTTON := &"RoundButton"
## A round key for a switch: chocolate when off, lime when on.
const ROUND_TOGGLE := &"RoundToggle"
## The board's tool keys: an orange square with an icon over a short label.
const TOOL_BUTTON := &"ToolButton"
## A picture in a wooden frame; the chosen one wears a sun-yellow ring.
const PICTURE_TILE := &"PictureTile"
## Collection chips on peach paper.
const CHIP := &"Chip"
const FRAME := &"Frame"
const PAPER := &"Paper"
## A pressed-in strip on paper, for a settings row.
const LINE := &"Line"
const RIBBON := &"Ribbon"
const PILL := &"Pill"
## The chocolate name strip under a framed picture.
const STRIP := &"Strip"
const INK_TITLE := &"InkTitle"
const INK_LABEL := &"InkLabel"

const KEY_DEPTH := 5
const KEY_RADIUS := 12
const ROUND_PADDING := 14
const ROUND_ICON := 34
const ROUND_SIZE := 64
const FRAME_PADDING := 6
const FRAME_RADIUS := 12
const RING_WIDTH := 5
const RIBBON_FONT_SIZE := 28
const RIBBON_OUTLINE := 6
## Room a card leaves above its body for the half of the ribbon that hangs inside it.
const RIBBON_ROOM := 14
const PILL_FONT_SIZE := 20
const STRIP_FONT_SIZE := 17
const INK_TITLE_SIZE := 36
const TOGGLE_SIZE := Vector2i(68, 40)
const TOGGLE_INSET := 4
const BAR_RADIUS := 8


static func add_to(theme: Theme) -> void:
	_add_key(theme, ORANGE_BUTTON, ORANGE, ORANGE_LO, Color.WHITE)
	_add_key(theme, SUN_BUTTON, SUN, SUN_LO, INK)
	_add_key(theme, RED_BUTTON, RED, RED_LO, Color.WHITE)
	_add_key(theme, ROUND_BUTTON, LIME, LIME_LO, Color.WHITE, 999, ROUND_PADDING)
	_add_key(theme, ROUND_TOGGLE, CHOC_3, CHOC, Color.WHITE, 999, ROUND_PADDING)
	# A toggle shows its state with the pressed box, so on is lime and stays raised.
	var on := _key_box(LIME, LIME_LO, KEY_DEPTH, 999, ROUND_PADDING)
	theme.set_stylebox("pressed", ROUND_TOGGLE, on)
	theme.set_stylebox("hover_pressed", ROUND_TOGGLE, on)
	_add_key(theme, TOOL_BUTTON, TAB, TAB_LO, Color.WHITE)
	theme.set_font_size("font_size", TOOL_BUTTON, PILL_FONT_SIZE)

	_add_key(theme, CHIP, PEACH_LO, PEACH_EDGE, INK)
	var chosen := _key_box(ORANGE, ORANGE_LO, KEY_DEPTH, KEY_RADIUS, UiTheme.BUTTON_PADDING_X)
	theme.set_stylebox("pressed", CHIP, chosen)
	theme.set_stylebox("hover_pressed", CHIP, chosen)
	for color_name in ["font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(color_name, CHIP, Color.WHITE)

	theme.add_type(PICTURE_TILE)
	theme.set_type_variation(PICTURE_TILE, &"Button")
	var framed := frame_box(CHOC, 2)
	theme.set_stylebox("normal", PICTURE_TILE, framed)
	theme.set_stylebox("hover", PICTURE_TILE, framed)
	var ringed := frame_box(SUN, RING_WIDTH)
	theme.set_stylebox("pressed", PICTURE_TILE, ringed)
	theme.set_stylebox("hover_pressed", PICTURE_TILE, ringed)

	_add_panel(theme, FRAME, frame_box(WOOD_LO, 2))
	var paper := _flat(PEACH, UiTheme.SHEET_RADIUS, UiTheme.SHEET_PADDING)
	paper.set_content_margin_all(UiTheme.SHEET_PADDING)
	paper.border_color = RIM
	paper.set_border_width_all(UiTheme.RIM_WIDTH)
	_add_panel(theme, PAPER, paper)
	var line := _flat(PEACH_LO, UiTheme.OPTION_RADIUS, UiTheme.PANEL_PADDING)
	line.border_color = PEACH_EDGE
	line.border_width_bottom = 3
	_add_panel(theme, LINE, line)

	var ribbon := _key_box(TAB, TAB_LO, 4, 6, 28)
	_add_label(theme, RIBBON, ribbon, load(UiTheme.TITLE_PATH), RIBBON_FONT_SIZE, Color.WHITE)
	theme.set_color("font_outline_color", RIBBON, CHOC)
	theme.set_constant("outline_size", RIBBON, RIBBON_OUTLINE)
	var pill := _flat(CHOC_2, 999, 14)
	pill.border_color = RIM
	pill.set_border_width_all(2)
	_add_label(theme, PILL, pill, load(UiTheme.BUTTON_PATH), PILL_FONT_SIZE, CREAM)
	var strip := _flat(CHOC, 0, 8)
	strip.corner_radius_bottom_left = FRAME_RADIUS - FRAME_PADDING
	strip.corner_radius_bottom_right = FRAME_RADIUS - FRAME_PADDING
	_add_label(theme, STRIP, strip, null, STRIP_FONT_SIZE, CREAM)

	theme.add_type(INK_TITLE)
	theme.set_type_variation(INK_TITLE, UiTheme.TITLE)
	theme.set_color("font_color", INK_TITLE, INK)
	theme.set_font_size("font_size", INK_TITLE, INK_TITLE_SIZE)
	theme.add_type(INK_LABEL)
	theme.set_type_variation(INK_LABEL, &"Label")
	theme.set_color("font_color", INK_LABEL, INK)

	theme.set_stylebox("background", "ProgressBar", _flat(GROOVE, BAR_RADIUS, 0))
	theme.set_stylebox("fill", "ProgressBar", _flat(SUN, BAR_RADIUS, 0))
	# Switches sit on peach strips, so they drop the green key box Button would lend them.
	theme.set_icon("checked", "CheckButton", toggle_icon(true))
	theme.set_icon("unchecked", "CheckButton", toggle_icon(false))
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		theme.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	for color_name in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "CheckButton", INK)


## A full-screen ground: rust with a warm glow, or peach paper. Ignores touches.
static func backdrop(paper := false) -> TextureRect:
	var gradient := Gradient.new()
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	if paper:
		gradient.colors = PackedColorArray([PEACH_HI, PEACH])
		texture.fill_from = Vector2(0.5, 0.0)
		texture.fill_to = Vector2(0.5, 1.0)
	else:
		gradient.colors = PackedColorArray([RUST_HI, RUST, RUST_LO])
		gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.25)
		texture.fill_to = Vector2(1.25, 1.0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A chocolate well, or a peach sheet, with a ribbon title across its top edge. ribbon_of() finds
## the ribbon again so the caller can change the title.
static func card(title: String, body: Control, paper := false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = PAPER if paper else UiTheme.SHEET
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTheme.PANEL_PADDING)
	panel.add_child(column)
	var room := Control.new()
	room.custom_minimum_size.y = RIBBON_ROOM
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(room)
	column.add_child(body)
	var ribbon := Label.new()
	ribbon.theme_type_variation = RIBBON
	ribbon.text = title
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.set_anchors_preset(Control.PRESET_CENTER_TOP)
	ribbon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	room.add_child(ribbon)
	# Centred on the panel's top edge: up past the padding, then up half the ribbon's height. Offsets,
	# not position, so a later layout of the card keeps it there.
	ribbon.resized.connect(func() -> void:
		ribbon.offset_top = -UiTheme.SHEET_PADDING - ribbon.size.y / 2.0
		ribbon.offset_bottom = ribbon.offset_top + ribbon.size.y)
	return panel


static func ribbon_of(card_panel: PanelContainer) -> Label:
	return card_panel.get_child(0).get_child(0).get_child(0) as Label


## A picture in a wooden frame, cropped to fill the given height.
static func framed(texture: Texture2D, height: float) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.theme_type_variation = FRAME
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.custom_minimum_size = Vector2(0, height)
	picture.clip_contents = true
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(picture)
	return frame


static func icon(name: String) -> Texture2D:
	return load("res://assets/icons/%s.svg" % name)


static func round_button(icon_name: String, variation := ROUND_BUTTON) -> Button:
	var button := Button.new()
	button.theme_type_variation = variation
	button.icon = icon(icon_name)
	button.focus_mode = Control.FOCUS_NONE
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", ROUND_ICON)
	button.custom_minimum_size = Vector2(ROUND_SIZE, ROUND_SIZE)
	return button


static func pill(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = PILL
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func frame_box(rim: Color, width: int) -> StyleBoxFlat:
	var box := _flat(WOOD, FRAME_RADIUS, FRAME_PADDING)
	box.border_color = rim
	box.set_border_width_all(width)
	# The ring is drawn outside the wood, so a chosen tile keeps its picture where it was.
	box.expand_margin_left = width
	box.expand_margin_right = width
	box.expand_margin_top = width
	box.expand_margin_bottom = width
	box.set_content_margin_all(FRAME_PADDING)
	return box


## A chunky switch: a chocolate or lime pill with a white knob at the off or on end.
static func toggle_icon(on: bool) -> ImageTexture:
	var image := Image.create(TOGGLE_SIZE.x, TOGGLE_SIZE.y, false, Image.FORMAT_RGBA8)
	var track := LIME if on else CHOC_3
	var r := TOGGLE_SIZE.y / 2.0
	var knob_r := r - TOGGLE_INSET
	var knob := Vector2(TOGGLE_SIZE.x - r if on else r, r)
	for y in TOGGLE_SIZE.y:
		for x in TOGGLE_SIZE.x:
			var p := Vector2(x + 0.5, y + 0.5)
			var centre := Vector2(clampf(p.x, r, TOGGLE_SIZE.x - r), r)
			var pill_cover := clampf(r - p.distance_to(centre) + 0.5, 0.0, 1.0)
			var knob_cover := clampf(knob_r - p.distance_to(knob) + 0.5, 0.0, 1.0)
			var colour := track.lerp(Color.WHITE, knob_cover)
			image.set_pixel(x, y, Color(colour, pill_cover))
	return ImageTexture.create_from_image(image)


static func _key_box(fill: Color, edge: Color, depth: int, radius: int, padding_x: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.border_width_bottom = depth
	box.set_corner_radius_all(radius)
	var sunk := KEY_DEPTH - depth
	box.expand_margin_top = -sunk
	box.content_margin_left = padding_x
	box.content_margin_right = padding_x
	box.content_margin_top = UiTheme.BUTTON_PADDING_Y + sunk
	box.content_margin_bottom = UiTheme.BUTTON_PADDING_Y + depth
	return box


# A pressed key keeps its footprint, as UiTheme's buttons do.
static func _add_key(theme: Theme, variation: StringName, fill: Color, edge: Color, text: Color, radius := KEY_RADIUS, padding_x := UiTheme.BUTTON_PADDING_X) -> void:
	theme.add_type(variation)
	theme.set_type_variation(variation, &"Button")
	var raised := _key_box(fill, edge, KEY_DEPTH, radius, padding_x)
	theme.set_stylebox("normal", variation, raised)
	theme.set_stylebox("hover", variation, raised)
	var sunk := _key_box(fill, edge, 1, radius, padding_x)
	theme.set_stylebox("pressed", variation, sunk)
	theme.set_stylebox("hover_pressed", variation, sunk)
	var faded := _key_box(fill, edge, KEY_DEPTH, radius, padding_x)
	faded.bg_color.a = UiTheme.DISABLED_ALPHA
	faded.border_color.a = UiTheme.DISABLED_ALPHA
	theme.set_stylebox("disabled", variation, faded)
	for color_name in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, variation, text)
	theme.set_color("font_disabled_color", variation, Color(text, UiTheme.DISABLED_ALPHA))


static func _add_panel(theme: Theme, variation: StringName, box: StyleBoxFlat) -> void:
	theme.add_type(variation)
	theme.set_type_variation(variation, &"PanelContainer")
	theme.set_stylebox("panel", variation, box)


static func _add_label(theme: Theme, variation: StringName, box: StyleBoxFlat, font: Font, font_size: int, color: Color) -> void:
	theme.add_type(variation)
	theme.set_type_variation(variation, &"Label")
	theme.set_stylebox("normal", variation, box)
	if font != null:
		theme.set_font("font", variation, font)
	theme.set_font_size("font_size", variation, font_size)
	theme.set_color("font_color", variation, color)


static func _flat(color: Color, radius: int, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding / 2.0 if padding > 0 else 0.0
	box.content_margin_bottom = padding / 2.0 if padding > 0 else 0.0
	return box
