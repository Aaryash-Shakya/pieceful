extends SceneTree
## Saves Home, Pictures, Setup, the board, Pause, Complete and Settings as PNGs to check the look by eye: godot --path . --script tools/capture_screens.gd -- <out_dir>
## Run with a window, not headless, so something is drawn. Uses a throwaway save and settings path.

const SAVE := "user://capture/current.json"
const PHONE := Vector2i(540, 1200)

var _phone: SubViewport


func _init() -> void:
	await process_frame
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://capture"
	DirAccess.make_dir_recursive_absolute(out)
	var shell := (load("res://src/ui/app_shell.tscn") as PackedScene).instantiate() as AppShell
	shell.settings_path = "user://capture/settings.cfg"
	shell.save_path = SAVE
	# A phone-sized viewport of its own, so a window manager that resizes the window cannot change the shape.
	_phone = SubViewport.new()
	_phone.size = PHONE
	_phone.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_phone)
	_phone.add_child(shell)
	await _settle()
	_save(out.path_join("home.png"))
	var home := shell.top()
	var pictures_button := home.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.contains("picture") or b.text.contains("New puzzle"))
	if not pictures_button.is_empty():
		(pictures_button[0] as Button).pressed.emit()
		await _settle()
		_save(out.path_join("pictures.png"))
		var setup := SetupScreen.open(self, SAVE, CollectionLibrary.load_bundled())
		await _settle()
		_save(out.path_join("setup.png"))
		var board := setup.start()
		await _settle()
		(board.get_node("Feedback") as Feedback).sound_enabled = false
		_save(out.path_join("board.png"))
		var hud := board.get_node("Hud") as Hud
		hud.open_pause()
		await _settle()
		_save(out.path_join("pause.png"))
		hud.close_pause()
		board.puzzle_completed.emit()
		await _settle()
		_save(out.path_join("complete.png"))
		AppShell.reset_to(self, SettingsScreen.make_host(SAVE, CollectionLibrary.load_bundled(), quit))
		await _settle()
		_save(out.path_join("settings.png"))
	quit()


func _settle() -> void:
	for i in 20:
		await process_frame


func _save(path: String) -> void:
	_phone.get_texture().get_image().save_png(path)
	print("saved ", path)
