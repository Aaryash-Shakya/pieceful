extends "res://tests/base_test.gd"
## Touches go through the real viewport here, as on a phone, so a control in the shell that
## swallows them shows up. Board tests call _unhandled_input directly and cannot see that.

const SETTINGS_PATH := "user://test_shell_touch.cfg"
const SAVE_PATH := "user://test_shell_touch/current.json"


func _init() -> void:
	await process_frame
	var shell := (load("res://src/ui/app_shell.tscn") as PackedScene).instantiate() as AppShell
	shell.settings_path = SETTINGS_PATH
	root.add_child(shell)
	await process_frame
	var setup := shell.top() as SetupScreen
	setup.save_path = SAVE_PATH
	setup.start()
	for k in 3:
		await process_frame
	var board := shell.top() as Board
	check(board != null, "the board is the shell's screen")
	if board != null:
		# Real playback would leave the audio server holding streams when a headless test exits.
		var feedback := board.get_node("Feedback") as Feedback
		feedback.sound_enabled = false
		feedback.vibration_enabled = false
		check(shell.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the shell takes no touches of its own")
		_test_touches_reach_the_board(board)
	shell.free()
	# The setup screen the board replaced is queued for deletion; let it go before exiting.
	await process_frame
	SaveFile.remove(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH.get_base_dir())
	DirAccess.remove_absolute(SETTINGS_PATH)
	finish()


func _test_touches_reach_the_board(board: Board) -> void:
	var viewport := root.get_viewport()
	var size := viewport.get_visible_rect().size
	var buttons: Array[Rect2] = []
	for node in board.find_children("*", "Button", true, false):
		buttons.append((node as Button).get_global_rect())
	var missed := 0
	var tried := 0
	for fy in range(1, 10):
		for fx in range(1, 10):
			var at := Vector2(size.x * fx / 10.0, size.y * fy / 10.0)
			if buttons.any(func(r: Rect2) -> bool: return r.has_point(at)):
				continue
			tried += 1
			var down := InputEventScreenTouch.new()
			down.index = 0
			down.position = at
			down.pressed = true
			viewport.push_input(down, true)
			var tail := board.trace.tail(1)
			if tail.is_empty() or not tail[0].contains("press #0 at (%d, %d)" % [roundi(at.x), roundi(at.y)]):
				missed += 1
			var up := down.duplicate() as InputEventScreenTouch
			up.pressed = false
			viewport.push_input(up, true)
	check(tried > 50, "the grid covers the screen")
	check(missed == 0, "every touch off the HUD buttons reaches the board (%d of %d missed)" % [missed, tried])
