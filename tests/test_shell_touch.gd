extends "res://tests/base_test.gd"
## Touches go through the real viewport here, as on a phone, so a control in the shell that
## swallows them shows up. Board tests hand events to the board directly and cannot see that.

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


# A finger that starts on a piece belongs to the board until it lifts, even when a control that takes
# touches (a sheet, a toast, a new tab bar) lies under where it moves or lets go.
func _test_a_drag_survives_a_control_over_the_finger(board: Board, shell: AppShell) -> void:
	var viewport_size := root.get_viewport().get_visible_rect().size
	var to_screen := func(world: Vector2) -> Vector2:
		return (world - board.camera.position) * board.camera.zoom.x + viewport_size / 2.0
	var node: PieceNode = null
	var start := Vector2.INF
	for child in board.pieces.get_children():
		var piece := child as PieceNode
		var outline := board.cut[piece.piece_id].outline
		var tri := Geometry2D.triangulate_polygon(outline)
		var world := (outline[tri[0]] + outline[tri[1]] + outline[tri[2]]) / 3.0 + piece.position
		var screen: Vector2 = to_screen.call(world)
		if board.piece_at(world) == piece and board.slot_at(screen) == -1 \
				and Rect2(Vector2.ZERO, viewport_size).grow(-80).has_point(screen):
			node = piece
			start = screen
			break
	check(node != null, "found a loose piece on screen")
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
