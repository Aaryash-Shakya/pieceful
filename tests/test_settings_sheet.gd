extends "res://tests/base_test.gd"

const PATH := "user://test_sheet_settings.cfg"


func _init() -> void:
	await process_frame
	DirAccess.remove_absolute(PATH)
	var sheet := SettingsSheet.new()
	sheet.path = PATH
	root.add_child(sheet)
	check(sheet.sound_check.button_pressed and sheet.vibration_check.button_pressed, "both are on by default")
	sheet.sound_check.button_pressed = false
	var saved := Settings.load_from(PATH)
	check(not saved.sound and saved.vibration, "switching sound off is written at once")
	sheet.vibration_check.button_pressed = false
	check(not Settings.load_from(PATH).vibration, "switching vibration off is written at once")
	sheet.free()
	var again := SettingsSheet.new()
	again.path = PATH
	root.add_child(again)
	check(not again.sound_check.button_pressed and not again.vibration_check.button_pressed, "a new sheet shows what was saved")
	again.free()
	DirAccess.remove_absolute(PATH)
	finish()
