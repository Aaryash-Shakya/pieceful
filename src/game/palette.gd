class_name Palette
## Colours for the current theme, mode and accent in Settings. The default
## Midnight table is in docs/visual-design.md. Felt and board stay dark-toned
## in every theme; only the shade changes.


static func is_dark() -> bool:
	match Settings.current().mode:
		"dark":
			return true
		"light":
			return false
	if not DisplayServer.is_dark_mode_supported():
		return false
	return DisplayServer.is_dark_mode()


static func luminance(color: Color) -> float:
	var channels := [color.r, color.g, color.b]
	for i in 3:
		var v: float = channels[i]
		channels[i] = v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


static func _role(dark: bool, role: PaletteThemes.Role) -> Color:
	return PaletteThemes.color(Settings.current().theme, dark, role)


static func page_background(dark := is_dark()) -> Color:
	return _role(dark, PaletteThemes.Role.PAGE)


static func surface(dark := is_dark()) -> Color:
	return _role(dark, PaletteThemes.Role.SURFACE)


static func raised_surface(dark := is_dark()) -> Color:
	return _role(dark, PaletteThemes.Role.RAISED)


static func text(dark := is_dark()) -> Color:
	return _role(dark, PaletteThemes.Role.TEXT)


static func muted_text(dark := is_dark()) -> Color:
	return _role(dark, PaletteThemes.Role.MUTED)


static func lines(dark := is_dark()) -> Color:
	return _role(dark, PaletteThemes.Role.LINES)


static func text_on_accent(dark := is_dark()) -> Color:
	var override := Settings.current().accent
	if override.is_empty():
		return _role(dark, PaletteThemes.Role.ON_ACCENT)
	return Color.html("#1c1400") if luminance(Color.html(override)) > 0.35 else Color.WHITE


static func accent_shadow(dark := is_dark()) -> Color:
	var override := Settings.current().accent
	if override.is_empty():
		return _role(dark, PaletteThemes.Role.ACCENT_SHADOW)
	var c := Color.html(override)
	return Color(c.r * 0.62, c.g * 0.62, c.b * 0.62)


static func felt(dark := is_dark()) -> Color:
	return _role(dark, PaletteThemes.Role.FELT)


static func board(dark := is_dark()) -> Color:
	return _role(dark, PaletteThemes.Role.BOARD)


static func accent(dark := is_dark()) -> Color:
	var override := Settings.current().accent
	if override.is_empty():
		return _role(dark, PaletteThemes.Role.ACCENT)
	return Color.html(override)


static func outline() -> Color:
	return Color(0.05, 0.08, 0.16, 0.8)
