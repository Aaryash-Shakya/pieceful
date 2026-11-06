class_name Settings
extends RefCounted
## The player's sound, vibration and look choices, kept in one small file apart from the save, so
## resetting game progress never touches them. A missing or damaged file means the defaults.

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "feedback"
const LOOK_SECTION := "look"
const THEMES: Array[String] = ["midnight", "orchard", "berry", "slate"]
const MODES: Array[String] = ["auto", "light", "dark"]
const ROUNDNESS_MIN := 0
const ROUNDNESS_MAX := 250
const ROUNDNESS_DEFAULT := 100

var sound := true
var vibration := true
var theme := "midnight"
var mode := "auto"
## Empty means the theme's own accent, otherwise lowercase #rrggbb.
var accent := ""
var roundness := ROUNDNESS_DEFAULT

# Shared so the palette and theme read the live look without it being passed through every scene.
static var _current: Settings


static func current() -> Settings:
	if _current == null:
		_current = Settings.new()
	return _current


static func use(settings: Settings) -> void:
	_current = settings


static func is_valid_accent(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	return text.length() == 7 and text.begins_with("#") and text.is_valid_html_color()


static func load_from(path: String = DEFAULT_PATH) -> Settings:
	var settings := Settings.new()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return settings
	var sound_value: Variant = file.get_value(SECTION, "sound", true)
	var vibration_value: Variant = file.get_value(SECTION, "vibration", true)
	settings.sound = sound_value if sound_value is bool else true
	settings.vibration = vibration_value if vibration_value is bool else true
	var theme_value: Variant = file.get_value(LOOK_SECTION, "theme", "midnight")
	if theme_value is String and theme_value in THEMES:
		settings.theme = theme_value
	var mode_value: Variant = file.get_value(LOOK_SECTION, "mode", "auto")
	if mode_value is String and mode_value in MODES:
		settings.mode = mode_value
	var accent_value: Variant = file.get_value(LOOK_SECTION, "accent", "")
	if is_valid_accent(accent_value):
		settings.accent = String(accent_value).to_lower()
	var roundness_value: Variant = file.get_value(LOOK_SECTION, "roundness", ROUNDNESS_DEFAULT)
	if roundness_value is int or roundness_value is float:
		settings.roundness = clampi(int(roundness_value), ROUNDNESS_MIN, ROUNDNESS_MAX)
	return settings


## Returns the engine's error code, OK when written.
func save_to(path: String = DEFAULT_PATH) -> Error:
	var file := ConfigFile.new()
	file.set_value(SECTION, "sound", sound)
	file.set_value(SECTION, "vibration", vibration)
	file.set_value(LOOK_SECTION, "theme", theme)
	file.set_value(LOOK_SECTION, "mode", mode)
	file.set_value(LOOK_SECTION, "accent", accent)
	file.set_value(LOOK_SECTION, "roundness", roundness)
	return file.save(path)
