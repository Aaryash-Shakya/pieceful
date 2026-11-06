extends "res://tests/base_test.gd"
## The shell that holds the screen stack: push, pop, replace, the look and the scene-swap fallback.

const PATH := "user://test_app_shell.cfg"

var _looks := 0


func _init() -> void:
	await process_frame
	_remove()
	await _test_ready()
	await _test_push_pop()
	await _test_pop_at_root()
	await _test_push_same_screen()
	await _test_replace_frees_old()
	await _test_node2d_screen()
	await _test_apply_look()
	await _test_present()
	await _test_present_during_back()
	await _test_push_lower_screen()
	await _test_free_releases_hidden()
	_remove()
	Settings.use(Settings.new())
	finish()


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func _shell(home: Control) -> AppShell:
	var shell := (load("res://src/ui/app_shell.tscn") as PackedScene).instantiate() as AppShell
	shell.settings_path = PATH
	shell.make_home = func() -> Node: return home
	root.add_child(shell)
	return shell


func _finish_shell(shell: AppShell) -> void:
	root.remove_child(shell)
	shell.free()


func _test_ready() -> void:
	var saved := Settings.new()
	saved.theme = "berry"
	saved.save_to(PATH)
	var home := Control.new()
	var shell := _shell(home)
	check(shell.depth() == 1, "the shell starts with the home screen")
	check(shell.top() == home and home.is_inside_tree(), "home is the top and in the tree")
	check(AppShell.find(self) == shell, "the shell is found by group")
	check(Settings.current().theme == "berry", "the saved settings are loaded")
	_finish_shell(shell)
	_remove()
	Settings.use(Settings.new())


func _test_push_pop() -> void:
	var home := Control.new()
	var shell := _shell(home)
	var second := Control.new()
	shell.push(second)
	check(shell.depth() == 2 and shell.top() == second, "push adds a screen")
	check(not home.is_inside_tree() and is_instance_valid(home), "the pushed-over screen is out of the tree but kept")
	check(shell.pop(), "pop returns true above the root")
	check(second.get_parent() == null, "the popped screen leaves the shell at once")
	check(shell.get_child_count() == 1, "only the restored screen is a child right after pop")
	check(not is_instance_valid(second) or second.is_queued_for_deletion(), "the popped screen is freed")
	check(home.is_inside_tree() and shell.top() == home, "home is back")
	await process_frame
	_finish_shell(shell)


func _test_pop_at_root() -> void:
	var home := Control.new()
	var shell := _shell(home)
	check(not shell.pop(), "pop at the root returns false")
	check(shell.depth() == 1 and home.is_inside_tree(), "the root stays")
	_finish_shell(shell)


func _test_push_same_screen() -> void:
	var home := Control.new()
	var shell := _shell(home)
	shell.push(home)
	check(shell.depth() == 1, "pushing the top again does nothing")
	_finish_shell(shell)


func _test_replace_frees_old() -> void:
	var home := Control.new()
	var shell := _shell(home)
	var next := Control.new()
	shell.replace(next)
	check(shell.depth() == 1 and shell.top() == next, "replace keeps the depth")
	check(not home.is_inside_tree() and shell.get_child_count() == 1, "only the new screen is a child before the frame ends")
	await process_frame
	check(not is_instance_valid(home), "the replaced screen is freed")
	check(shell.get_child_count() == 1, "one screen child remains")
	_finish_shell(shell)


func _test_node2d_screen() -> void:
	var shell := _shell(Control.new())
	var board := Node2D.new()
	shell.replace(board)
	check(board.get_parent() == shell and shell.top() == board, "a Node2D screen is a child of the shell")
	_finish_shell(shell)


func _test_apply_look() -> void:
	var shell := _shell(Control.new())
	_looks = 0
	shell.look_applied.connect(func() -> void: _looks += 1)
	Settings.current().theme = "orchard"
	shell.apply_look()
	check(_looks == 1, "look_applied fires once")
	check(shell.theme.get_stylebox("normal", "Button").bg_color == Palette.accent(), "buttons take the accent")
	_finish_shell(shell)
	Settings.use(Settings.new())


func _test_present() -> void:
	var shell := _shell(Control.new())
	var a := Control.new()
	AppShell.present(self, a)
	await process_frame
	check(shell.top() == a, "present replaces the shell's top")
	_finish_shell(shell)
	var b := Control.new()
	AppShell.present(self, b)
	await process_frame
	check(current_scene == b, "without a shell present changes the scene")
	b.free()
	current_scene = null
	await process_frame


class BackScreen extends Node2D:
	var next: Node

	func _notification(what: int) -> void:
		if what == NOTIFICATION_WM_GO_BACK_REQUEST:
			AppShell.present(get_tree(), next)


# The board swaps screens from inside the back notification, where the tree refuses child changes.
func _test_present_during_back() -> void:
	var shell := _shell(Control.new())
	var board := BackScreen.new()
	var next := Control.new()
	board.next = next
	shell.replace(board)
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	check(shell.get_child_count() == 1 and shell.get_child(0) == next, "the new screen is the shell's only child")
	check(shell.top() == next and shell.depth() == 1, "the stack names the new screen")
	_finish_shell(shell)


func _test_push_lower_screen() -> void:
	var home := Control.new()
	var shell := _shell(home)
	var second := Control.new()
	shell.push(second)
	shell.push(home)
	check(shell.depth() == 2 and shell.top() == second, "pushing a screen already in the stack does nothing")
	_finish_shell(shell)


func _test_free_releases_hidden() -> void:
	var home := Control.new()
	var shell := _shell(home)
	shell.push(Control.new())
	shell.push(Control.new())
	_finish_shell(shell)
	check(not is_instance_valid(home), "freeing the shell frees screens that were pushed over")
