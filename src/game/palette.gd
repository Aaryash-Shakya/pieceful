class_name Palette
## Midnight table colours from docs/visual-design.md. The felt and board stay
## navy in both modes; only the shade changes.


static func is_dark() -> bool:
	if not DisplayServer.is_dark_mode_supported():
		return false
	return DisplayServer.is_dark_mode()


static func felt(dark := is_dark()) -> Color:
	return Color.html("#14264a" if dark else "#223a63")


static func board(dark := is_dark()) -> Color:
	return Color.html("#1c3463" if dark else "#2c4878")


static func accent(dark := is_dark()) -> Color:
	return Color.html("#ffc857" if dark else "#e2a41f")


static func outline() -> Color:
	return Color(0.05, 0.08, 0.16, 0.8)
