extends SceneTree
## Saves Home and Pictures as PNGs to check the look by eye: godot --path . --script tools/capture_screens.gd -- <out_dir>
## Run with a window, not headless, so something is drawn. Uses a throwaway save and settings path.

const SAVE := "user://capture/current.json"


func _init() -> void:
	await process_frame
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://capture"
	DirAccess.make_dir_recursive_absolute(out)
	var shell := (load("res://src/ui/app_shell.tscn") as PackedScene).instantiate() as AppShell
	shell.settings_path = "user://capture/settings.cfg"
	shell.save_path = SAVE
	root.add_child(shell)
	await _settle()
	_save(out.path_join("home.png"))
	var home := shell.top()
	var pictures_button := home.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.contains("picture"))
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
	quit()


func _settle() -> void:
	for i in 20:
		await process_frame


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
