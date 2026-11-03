class_name Settings
extends RefCounted
## The player's sound and vibration switches, kept in one small file apart from the save, so
## resetting game progress never touches them. A missing or damaged file means the defaults.

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "feedback"

var sound := true
var vibration := true


static func load_from(path: String = DEFAULT_PATH) -> Settings:
	var settings := Settings.new()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return settings
	var sound_value: Variant = file.get_value(SECTION, "sound", true)
	var vibration_value: Variant = file.get_value(SECTION, "vibration", true)
	settings.sound = sound_value if sound_value is bool else true
	settings.vibration = vibration_value if vibration_value is bool else true
	return settings


## Returns the engine's error code, OK when written.
func save_to(path: String = DEFAULT_PATH) -> Error:
	var file := ConfigFile.new()
	file.set_value(SECTION, "sound", sound)
	file.set_value(SECTION, "vibration", vibration)
	return file.save(path)
