extends "res://tests/board_test.gd"

var feedback: Feedback
var _sounds: Array[StringName] = []
var _vibrations: Array[Vector2] = []
var _locks: Array[int] = []
var _join_flags: Array[bool] = []
var _fresh_sounds: Array[StringName] = []
var _a := -1
var _b := -1


func _init() -> void:
	await process_frame
	make_board()
	_show_everything()
	feedback = board.get_node("Feedback") as Feedback
	feedback.play_sound = _record_sound
	feedback.vibrate = _record_vibration
	board.cluster_locked.connect(func(root: int, _count: int) -> void: _locks.append(root))
	board.pieces_joined.connect(func(_root: int, _count: int, locked: bool) -> void: _join_flags.append(locked))

	var first := _test_touch_lift_and_lock()
	var used := _test_join_and_lock_through_drop()
	used.append(first)
	var spare: Array[int] = []
	for id in board.cut.size():
		if not used.has(id) and spare.size() < 2:
			spare.append(id)
	_a = spare[0]
	_b = spare[1]

	_test_wiring()
	_test_default_seams()
	_test_attach_never_double_connects()
	_test_pick_up()
	_test_join_only()
	_test_lock_only()
	_test_join_flagged_as_locked()
	_test_completion()
	_test_sound_off()
	_test_vibration_off()
	_test_system_release("focus out", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_test_system_release("pause", Node.NOTIFICATION_APPLICATION_PAUSED)
	_test_drop_after_system_release_plays()
	_test_export_presets()
	board.free()
	finish()


func _record_sound(sound: StringName) -> void:
	_sounds.append(sound)


func _record_vibration(duration_ms: int, amplitude: float) -> void:
	_vibrations.append(Vector2(duration_ms, amplitude))


func _reset() -> void:
	_sounds.clear()
	_vibrations.clear()
	_locks.clear()
	_join_flags.clear()
	feedback.sound_enabled = true
	feedback.vibration_enabled = true


func _top_loose() -> PieceNode:
	return pieces.get_child(pieces.get_child_count() - 1) as PieceNode


# A point inside the piece's outline, in the piece's own coordinates.
func _inside(piece: PieceNode) -> Vector2:
	var outline := board.cut[piece.piece_id].outline
	var triangles := Geometry2D.triangulate_polygon(outline)
	return (outline[triangles[0]] + outline[triangles[1]] + outline[triangles[2]]) / 3.0


# Presses the piece and drags it onto its place without lifting the finger.
func _press_and_drag_home(piece: PieceNode) -> void:
	var c := _inside(piece)
	_touch(0, _to_screen(c + piece.position), true)
	_drag(0, _to_screen(c), Vector2.ZERO)


# Returns the id of the piece it locked.
func _test_touch_lift_and_lock() -> int:
	_reset()
	var l := _top_loose()
	var c := _inside(l)
	_touch(0, _to_screen(c + l.position), true)
	check(_sounds == [Feedback.SOUND_PICK], "pressing a piece plays only the pick sound")
	check(_vibrations.is_empty(), "pressing a piece does not vibrate")
	_drag(0, _to_screen(c), Vector2.ZERO)
	_touch(0, _to_screen(c), false)
	check(_sounds == [Feedback.SOUND_PICK, Feedback.SOUND_LOCK], "dropping a piece on its place plays pick then lock only, got %s" % [_sounds])
	check(_vibrations == [Vector2(25, 1.0)], "dropping a piece on its place vibrates once, as a lock, got %s" % [_vibrations])
	return l.piece_id


# A real drop that joins a loose neighbour resting within tolerance of its place, so the join also locks.
# Staging that neighbour is the only shortcut: it moves in the state and on screen together, and the
# drop itself goes through the touch path, so the board stays consistent. Returns the two piece ids.
func _test_join_and_lock_through_drop() -> Array[int]:
	_reset()
	var tolerance := board.state.tolerance
	var rest := -1
	var dropped := -1
	for node in pieces.get_children():
		var id := (node as PieceNode).piece_id
		for other in board.cut[id].neighbours:
			if not board.state.is_locked(other) and not board.state.is_locked(id):
				rest = id
				dropped = other
				break
		if rest != -1:
			break
	check(rest != -1, "there are two loose neighbours")
	if rest == -1:
		return []
	var resting := Vector2(0.5 * tolerance, 0)
	board.state.move_cluster(rest, resting)
	board.node_for(rest).position = resting

	var node := board.node_for(dropped)
	# Only the order among loose siblings changes, so the press cannot land on a piece above it.
	pieces.move_child(node, -1)
	var c := _inside(node)
	_touch(0, _to_screen(c + node.position), true)
	_drag(0, _to_screen(c + Vector2(1.4 * tolerance, 0)), Vector2.ZERO)
	_touch(0, _to_screen(c + Vector2(1.4 * tolerance, 0)), false)
	check(board.state.is_locked(dropped), "the dropped piece locked")
	check(board.state.find(dropped) == board.state.find(rest), "the dropped piece joined its neighbour")
	check(_join_flags == [true], "the board flags the join as also locked, got %s" % [_join_flags])
	check(_sounds == [Feedback.SOUND_PICK, Feedback.SOUND_LOCK], "a drop that joins and locks plays only the lock, got %s" % [_sounds])
	check(_vibrations == [Vector2(25, 1.0)], "a drop that joins and locks gives only the firm pulse, got %s" % [_vibrations])
	return [rest, dropped]



func _test_wiring() -> void:
	_reset()
	check(feedback.board == board, "feedback points at the board")
	check(feedback.sound_enabled and feedback.vibration_enabled, "both switches start on")
	check(feedback._players.size() == 4, "there is one player per sound")
	for key: StringName in Feedback.STREAMS:
		var player: AudioStreamPlayer = feedback._players[key]
		check(player.stream == Feedback.STREAMS[key], "%s player uses its stream" % key)
		check(player.max_polyphony == 4, "%s player allows 4 overlapping plays" % key)
		check(player.get_parent() == feedback, "%s player is a child of the feedback node" % key)
		check(Feedback.STREAMS[key] is AudioStreamWAV, "%s stream is an AudioStreamWAV" % key)


func _test_default_seams() -> void:
	var fresh := Feedback.new()
	check(fresh.play_sound.is_valid(), "play_sound has a default")
	check(fresh.vibrate.is_valid(), "vibrate has a default")
	check(fresh.play_sound.get_method() == &"_play", "play_sound defaults to the player method")
	check(fresh.vibrate.get_method() == &"vibrate_handheld", "vibrate defaults to Input.vibrate_handheld")
	check(fresh.sound_enabled and fresh.vibration_enabled, "a fresh node has both switches on")
	fresh.free()


func _count_fresh_sound(sound: StringName) -> void:
	_fresh_sounds.append(sound)


func _test_attach_never_double_connects() -> void:
	_reset()
	var fresh := Feedback.new()
	fresh.play_sound = _count_fresh_sound
	fresh.attach(board)
	fresh.attach(board)
	board.cluster_lifted.emit(_a, 1)
	check(_fresh_sounds == [Feedback.SOUND_PICK], "attaching twice connects once, got %s" % [_fresh_sounds])

	_fresh_sounds.clear()
	var other := Board.new()
	fresh.attach(other)
	check(fresh.board == other, "attach re-points the node")
	board.cluster_lifted.emit(_a, 1)
	check(_fresh_sounds.is_empty(), "a node pointed elsewhere no longer hears the old board")
	other.cluster_lifted.emit(_a, 1)
	check(_fresh_sounds == [Feedback.SOUND_PICK], "a node pointed elsewhere hears the new board once")
	fresh.free()
	other.free()
	_sounds.clear()


func _test_pick_up() -> void:
	_reset()
	board.cluster_lifted.emit(_a, 1)
	check(_sounds == [Feedback.SOUND_PICK], "pick-up plays the pick sound")
	check(_vibrations.is_empty(), "pick-up does not vibrate")


func _test_join_only() -> void:
	_reset()
	board.pieces_joined.emit(_a, 2, false)
	check(_sounds == [Feedback.SOUND_JOIN], "a join plays the join sound")
	check(_vibrations == [Vector2(12, 0.5)], "a join gives the light pulse")


func _test_lock_only() -> void:
	_reset()
	board.cluster_locked.emit(_b, 1)
	check(_sounds == [Feedback.SOUND_LOCK], "a lock plays the lock sound")
	check(_vibrations == [Vector2(25, 1.0)], "a lock gives the firm pulse")


func _test_join_flagged_as_locked() -> void:
	_reset()
	board.pieces_joined.emit(_b, 2, true)
	board.cluster_locked.emit(_b, 2)
	check(_sounds == [Feedback.SOUND_LOCK], "a join flagged as locked plays only the lock sound")
	check(_vibrations == [Vector2(25, 1.0)], "a join flagged as locked gives only the firm pulse")


func _test_completion() -> void:
	_reset()
	board.cluster_locked.emit(_b, 1)
	board.puzzle_completed.emit()
	check(_sounds == [Feedback.SOUND_LOCK, Feedback.SOUND_COMPLETE], "completion plays lock then complete")
	check(_vibrations == [Vector2(25, 1.0), Vector2(60, 1.0)], "completion adds the long pulse")


func _emit_all_four() -> void:
	board.cluster_lifted.emit(_a, 1)
	board.pieces_joined.emit(_a, 2, false)
	board.cluster_locked.emit(_b, 1)
	board.puzzle_completed.emit()


func _test_sound_off() -> void:
	_reset()
	feedback.sound_enabled = false
	_emit_all_four()
	check(_sounds.is_empty(), "no sound plays with sound off")
	check(_vibrations == [Vector2(12, 0.5), Vector2(25, 1.0), Vector2(60, 1.0)], "vibration still plays with sound off")


func _test_vibration_off() -> void:
	_reset()
	feedback.vibration_enabled = false
	_emit_all_four()
	check(_sounds == [Feedback.SOUND_PICK, Feedback.SOUND_JOIN, Feedback.SOUND_LOCK, Feedback.SOUND_COMPLETE], "sounds still play with vibration off")
	check(_vibrations.is_empty(), "no vibration with vibration off")


# The game signals still fire, so a later save can follow every lock, but a drop the system forced stays silent.
func _test_system_release(label: String, what: int) -> void:
	_reset()
	var node := _top_loose()
	var id := node.piece_id
	_press_and_drag_home(node)
	_sounds.clear()
	board.notification(what)
	check(board.state.is_locked(id), "a %s drop near home locks the piece" % label)
	check(_locks.has(board.state.find(id)), "a %s drop still emits cluster_locked" % label)
	check(_sounds.is_empty(), "a %s drop plays no sound, got %s" % [label, _sounds])
	check(_vibrations.is_empty(), "a %s drop does not vibrate, got %s" % [label, _vibrations])
	check(not board.releasing_for_system, "the system-release flag is cleared after a %s" % label)


func _test_drop_after_system_release_plays() -> void:
	_reset()
	var node := _top_loose()
	_press_and_drag_home(node)
	_touch(0, _to_screen(_inside(node)), false)
	check(_sounds == [Feedback.SOUND_PICK, Feedback.SOUND_LOCK], "a normal drop plays again after a system release, got %s" % [_sounds])
	check(_vibrations == [Vector2(25, 1.0)], "a normal drop vibrates again after a system release")


func _test_export_presets() -> void:
	var config := ConfigFile.new()
	check(config.load("res://export_presets.cfg") == OK, "export_presets.cfg loads")
	check(config.get_value("preset.0.options", "permissions/vibrate") == true, "the Android preset asks for the vibrate permission")
	check(config.get_value("preset.0.options", "package/unique_name") == "io.github.aaryash_shakya.pieceful", "the package name is unchanged")
	var exclude: String = config.get_value("preset.0", "exclude_filter", "")
	var patterns := Array(exclude.split(",")).map(func(p: String) -> String: return p.strip_edges())
	check(patterns.has("tools/*"), "tools are kept out of the APK")
	check(patterns.has("tests/*"), "tests are kept out of the APK")
