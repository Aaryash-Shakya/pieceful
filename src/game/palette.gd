class_name Palette
## Midnight table colours from docs/visual-design.md. The felt and board stay
## navy in both modes; only the shade changes.


static func is_dark() -> bool:
	if not DisplayServer.is_dark_mode_supported():
		return false
	return DisplayServer.is_dark_mode()


static func page_background(dark := is_dark()) -> Color:
	return Color.html("#0b1020" if dark else "#e7e9f0")


static func surface(dark := is_dark()) -> Color:
	return Color.html("#131a2e" if dark else "#f6f7fb")


static func raised_surface(dark := is_dark()) -> Color:
	return Color.html("#1c2540" if dark else "#dbdfea")


static func text(dark := is_dark()) -> Color:
	return Color.html("#e9edf7" if dark else "#141b2d")


static func muted_text(dark := is_dark()) -> Color:
	return Color.html("#8d98b5" if dark else "#566079")


static func lines(dark := is_dark()) -> Color:
	return Color.html("#27314f" if dark else "#c9cfdd")


static func text_on_accent(_dark := is_dark()) -> Color:
	return Color.html("#2a1d00")


static func accent_shadow(dark := is_dark()) -> Color:
	return Color.html("#b58712" if dark else "#a87612")


static func felt(dark := is_dark()) -> Color:
	return Color.html("#14264a" if dark else "#223a63")


static func board(dark := is_dark()) -> Color:
	return Color.html("#1c3463" if dark else "#2c4878")


static func accent(dark := is_dark()) -> Color:
	return Color.html("#ffc857" if dark else "#e2a41f")


static func outline() -> Color:
	return Color(0.05, 0.08, 0.16, 0.8)
