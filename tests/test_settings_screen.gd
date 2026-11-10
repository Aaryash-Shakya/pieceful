extends "res://tests/base_test.gd"
## The Settings tab: reached from Home's nav, its switches write the shell's settings file.

const SETTINGS_PATH := "user://test_settings_screen.cfg"
const SAVE_PATH := "user://test_settings_screen/current.json"


func _init() -> void:
	await process_frame
	DirAccess.remove_absolute(SETTINGS_PATH)
	var shell := (load("res://src/ui/app_shell.tscn") as PackedScene).instantiate() as AppShell
	shell.settings_path = SETTINGS_PATH
	shell.save_path = SAVE_PATH
	root.add_child(shell)
	await process_frame
	var home_host := shell.top() as TabHost
	check(home_host != null and home_host.routes.has(&"settings"), "Home's nav has a Settings route")
	var nav := home_host.find_children("*", "FloatingNav", true, false)[0] as FloatingNav
	check(not (nav.buttons[&"settings"] as Button).disabled, "the Settings tab is enabled")
	nav.tab_pressed.emit(&"settings")
	await process_frame
	await process_frame
	var host := shell.top() as TabHost
	var screen := host.body as SettingsScreen if host != null else null
	check(screen != null, "the Settings tab opens the Settings screen")
	if screen != null:
		check(screen.sheet.path == SETTINGS_PATH, "the sheet writes the shell's settings file")
		check(not screen.sheet.heading.visible, "the page title replaces the sheet's heading")
		screen.sheet.sound_check.button_pressed = false
		check(not Settings.load_from(SETTINGS_PATH).sound, "switching sound off is written")
		check(host.routes.has(&"home") and host.routes.has(&"pictures"), "Home and Pictures are a tab away")
		screen._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		await process_frame
		await process_frame
		check((shell.top() as TabHost).body is HomeScreen, "back goes Home")
	shell.free()
	await process_frame
	DirAccess.remove_absolute(SETTINGS_PATH)
	finish()
