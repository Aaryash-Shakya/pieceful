extends "res://tests/base_test.gd"
## One trip through the shell: open on Home, pick a picture, cut, start, come back Home and resume.

const SAVE := "user://test_home_flow/current.json"
const SHELL_SETTINGS := "user://test_home_flow_shell.cfg"
const FIXTURE := "res://tests/fixtures/collection/manifest.json"

var _fixture := Collection.load_manifest(FIXTURE)
var _quits := 0


func _init() -> void:
	await process_frame
	_clear()
	await _test_default_home()
	await _test_flow()
	await _test_back_steps()
	_clear()
	DirAccess.remove_absolute(SAVE.get_base_dir())
	finish()


func _clear() -> void:
	SaveFile.remove(SAVE)
	if FileAccess.file_exists(SaveFile.bad_path(SAVE)):
		DirAccess.remove_absolute(SaveFile.bad_path(SAVE))
	if FileAccess.file_exists(SHELL_SETTINGS):
		DirAccess.remove_absolute(SHELL_SETTINGS)


func _frames() -> void:
	await process_frame
	await process_frame


# Home built with the test save and collection, so the real save is never read or written.
func _shell(use_default := false) -> AppShell:
	var shell := (load("res://src/ui/app_shell.tscn") as PackedScene).instantiate() as AppShell
	shell.settings_path = SHELL_SETTINGS
	if not use_default:
		shell.make_home = func() -> Node:
			return HomeScreen.make_host(SAVE, _fixture, func() -> void: _quits += 1)
	root.add_child(shell)
	return shell


func _end(shell: AppShell) -> void:
	root.remove_child(shell)
	shell.free()
	Settings.use(Settings.new())
	_clear()


func _quiet(board: Board) -> void:
	# Real playback would leave the audio server holding streams when a headless test exits.
	var feedback := board.get_node("Feedback") as Feedback
	feedback.sound_enabled = false
	feedback.vibration_enabled = false


func _home_body(shell: AppShell) -> HomeScreen:
	var host := shell.top() as TabHost
	return host.body as HomeScreen if host != null else null


func _test_default_home() -> void:
	var shell := _shell(true)
	await _frames()
	check(shell.depth() == 1 and shell.top() is TabHost, "the app opens on a tab host")
	check(_home_body(shell) != null, "whose body is the Home screen")
	_end(shell)


func _test_flow() -> void:
	var shell := _shell()
	await _frames()
	var home := _home_body(shell)
	check(home != null and home.continue_button == null, "first launch: Home has no Continue")
	home.new_button.pressed.emit()
	await _frames()
	var pictures := (shell.top() as TabHost).body as PicturesScreen
	check(pictures != null, "New puzzle opens Pictures")
	var chosen := _fixture.pictures[1].id
	pictures.select_picture(1)
	pictures.cut()
	await _frames()
	var setup := shell.top() as SetupScreen
	check(setup != null and setup.picture.id == chosen, "Cut opens Setup on the picture")
	var board := setup.start()
	await _frames()
	check(board != null and shell.top() == board, "Start opens the board")
	_quiet(board)
	board.home_requested.emit()
	await _frames()
	var back := _home_body(shell)
	check(back != null and back.continue_button != null, "the board returns to Home with Continue")
	check(back != null and back.title_label.text == _fixture.find(chosen).title, "Home shows the puzzle just started")
	var resumed := back.continue_game()
	await _frames()
	check(resumed != null and shell.top() == resumed and resumed.resume, "Continue opens the board again")
	_quiet(resumed)
	resumed.home_requested.emit()
	await _frames()
	check(_home_body(shell) != null, "and the board goes Home again")
	_end(shell)


func _test_back_steps() -> void:
	_quits = 0
	var shell := _shell()
	await _frames()
	_home_body(shell).new_button.pressed.emit()
	await _frames()
	var pictures := (shell.top() as TabHost).body as PicturesScreen
	pictures.cut()
	await _frames()
	var setup := shell.top() as SetupScreen
	setup._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames()
	check(shell.top() is TabHost and (shell.top() as TabHost).body == pictures and _quits == 0, "back from Setup returns to Pictures")
	pictures._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames()
	check(_home_body(shell) != null and _quits == 0, "back from Pictures returns to Home")
	_home_body(shell)._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(_quits == 1, "back from Home quits")
	_end(shell)
