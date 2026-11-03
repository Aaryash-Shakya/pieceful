class_name SettingsSheet
extends PanelContainer
## Sound and vibration switches. Each change is written at once, so there is nothing to confirm
## and nothing lost if the app is closed.

var path := Settings.DEFAULT_PATH
var settings: Settings
var sound_check: CheckBox
var vibration_check: CheckBox


func _ready() -> void:
	theme_type_variation = UiTheme.SHEET
	settings = Settings.load_from(path)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var heading := Label.new()
	heading.text = "Settings"
	heading.theme_type_variation = UiTheme.TITLE
	column.add_child(heading)
	sound_check = _make_check("Sound", settings.sound, _on_sound_toggled, column)
	vibration_check = _make_check("Vibration", settings.vibration, _on_vibration_toggled, column)


func _make_check(text: String, on: bool, handler: Callable, parent: Control) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = on
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(handler)
	parent.add_child(check)
	return check


func _on_sound_toggled(on: bool) -> void:
	settings.sound = on
	_write()


func _on_vibration_toggled(on: bool) -> void:
	settings.vibration = on
	_write()


func _write() -> void:
	var err := settings.save_to(path)
	if err != OK:
		push_warning("SettingsSheet: could not save settings to %s (error %d)" % [path, err])
