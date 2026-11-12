extends "res://tests/base_test.gd"
## Touches go through the real viewport here, as on a phone, so a control in the shell that
## swallows them shows up. Board tests hand events to the board directly and cannot see that.

const SETTINGS_PATH := "user://test_shell_touch.cfg"
const SAVE_PATH := "user://test_shell_touch/current.json"


func _init() -> void:
	await process_frame
	var shell := (load("res://src/ui/app_shell.tscn") as PackedScene).instantiate() as AppShell
	shell.settings_path = SETTINGS_PATH
	shell.save_path = SAVE_PATH
	root.add_child(shell)
	await process_frame
	# The shell opens on Home; the board is reached through Setup as from Pictures.
	var setup := SetupScreen.open(self,SAVE_PATH, CollectionLibrary.load_bundled())
	await process_frame
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
		_test_buttons_keep_their_presses(board)
		_test_a_drag_survives_a_control_over_the_finger(board, shell)
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
	# The HUD's own controls keep their touches: its buttons and the tool strip they sit on.
	var buttons: Array[Rect2] = []
	for node in board.get_node("Hud").find_children("*", "Control", true, false):
		var control := node as Control
		if control.is_visible_in_tree() and control.mouse_filter == Control.MOUSE_FILTER_STOP:
			buttons.append(control.get_global_rect())
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


func _push_touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	root.get_viewport().push_input(event, true)


func _push_drag(index: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = relative
	root.get_viewport().push_input(event, true)


func _test_buttons_keep_their_presses(board: Board) -> void:
	var button := board.find_children("*", "Button", true, false)[0] as Button
	var at := button.get_global_rect().get_center()
	_push_touch(0, at, true)
	var reached := false
	for line in board.trace.lines():
		reached = reached or line.contains("press #0 at (%d, %d)" % [roundi(at.x), roundi(at.y)])
	_push_touch(0, at, false)
	check(not reached, "a press on a HUD button never reaches the board")
	check(board.gesture_report().contains("no fingers"), "the button's finger is not left down on the board")
	# The first button is Pause, so the tap opened the card over the board; the next test needs it gone.
	(board.get_node("Hud") as Hud).close_pause()


# A finger that starts on a piece belongs to the board until it lifts, even when a control that takes
# touches (a sheet, a toast, a new tab bar) lies under where it moves or lets go.
func _test_a_drag_survives_a_control_over_the_finger(board: Board, shell: AppShell) -> void:
	var viewport_size := root.get_viewport().get_visible_rect().size
	var to_screen := func(world: Vector2) -> Vector2:
		return (world - board.camera.position) * board.camera.zoom.x + viewport_size / 2.0
	# The setup screen picks a fresh seed, so the scatter differs every run. The topmost loose piece is
	# moved under the screen centre, away from its home so it cannot lock, where nothing covers it.
	var node := board.pieces.get_child(board.pieces.get_child_count() - 1) as PieceNode
	var outline := board.cut[node.piece_id].outline
	var tri := Geometry2D.triangulate_polygon(outline)
	var inside := (outline[tri[0]] + outline[tri[1]] + outline[tri[2]]) / 3.0
	var home_far := Vector2(board.puzzle.image_size).length()
	board.camera.position = inside + Vector2(home_far, 0)
	board.state.move_cluster(node.piece_id, Vector2(home_far, 0))
	node.position = Vector2(home_far, 0)
	var start: Vector2 = to_screen.call(inside + node.position)
	check(board.piece_at(inside + node.position) == node and board.slot_at(start) == -1, "a loose piece is under the screen centre")
	if node == null:
		return
	var from := board.state.offset_of(node.piece_id)
	_push_touch(0, start, true)
	check(board.gesture_report().contains("held 1"), "the press lifts the piece")
	var cover := Control.new()
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(cover)
	shell.add_child(layer)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var step := Vector2(30, 20)
	_push_drag(0, start + step, step)
	check(board.state.offset_of(node.piece_id).distance_to(from + step / board.camera.zoom.x) < 0.5, "the piece follows the finger over the control")
	_push_touch(0, start + step, false)
	check(board.gesture_report().contains("held 0") and board.gesture_report().contains("mode IDLE"), "the release over the control drops the piece")
	check(board.gesture_report().contains("no fingers"), "no finger is left down")
	layer.free()
