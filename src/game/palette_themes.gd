class_name PaletteThemes
extends RefCounted
## Theme colour tables from the UI flow reference. Each theme has a light and
## a dark list, in Role order.

enum Role { PAGE, SURFACE, RAISED, TEXT, MUTED, LINES, ACCENT, ON_ACCENT, ACCENT_SHADOW, FELT, BOARD }

const MIDNIGHT_LIGHT := ["#e7e9f0", "#f6f7fb", "#dbdfea", "#141b2d", "#566079", "#c9cfdd", "#e2a41f", "#2a1d00", "#a87612", "#223a63", "#2c4878"]
const MIDNIGHT_DARK := ["#0b1020", "#131a2e", "#1c2540", "#e9edf7", "#8d98b5", "#27314f", "#ffc857", "#2a1d00", "#b58712", "#14264a", "#1c3463"]
const ORCHARD_LIGHT := ["#e6ece4", "#f5f8f3", "#d7e0d3", "#16241a", "#516052", "#c5d1c0", "#2f9e5b", "#ffffff", "#1f6e3f", "#2b5a3e", "#35704c"]
const ORCHARD_DARK := ["#0c150f", "#142019", "#1d2e23", "#e5f1e8", "#8aa493", "#27402f", "#6fdc97", "#06210f", "#3fa365", "#163524", "#1f4a31"]
const BERRY_LIGHT := ["#efe6ee", "#faf5fa", "#e3d5e2", "#2a1428", "#6b5068", "#d6c4d4", "#c4348f", "#ffffff", "#8d2266", "#4a2a5e", "#5b3873"]
const BERRY_DARK := ["#150a18", "#201125", "#2d1a34", "#f3e8f5", "#aa8fb0", "#3e2548", "#ff7ac8", "#2a0620", "#b8478f", "#2a1640", "#3b2260"]
const SLATE_LIGHT := ["#e8eaec", "#f7f8f9", "#dadde1", "#16191d", "#5c636b", "#cdd1d6", "#0f8f9a", "#ffffff", "#0b636b", "#2c3a45", "#3a4b58"]
const SLATE_DARK := ["#0c0f12", "#15191d", "#1f252b", "#e8ecef", "#8f98a1", "#2b333b", "#3fd1dc", "#03262a", "#26959e", "#18222a", "#243440"]


static func color(theme_id: String, dark: bool, role: Role) -> Color:
	var list: Array
	match theme_id:
		"orchard":
			list = ORCHARD_DARK if dark else ORCHARD_LIGHT
		"berry":
			list = BERRY_DARK if dark else BERRY_LIGHT
		"slate":
			list = SLATE_DARK if dark else SLATE_LIGHT
		_:
			list = MIDNIGHT_DARK if dark else MIDNIGHT_LIGHT
	return Color.html(list[role])
