extends BoardTest

var feedback: Feedback
var _sounds: Array[StringName] = []
var _vibrations: Array[Vector2] = []
var _a := -1
var _b := -1


func _init() -> void:
	await process_frame
	make_board()
	_show_everything()
	feedback = board.get_node("Feedback") as Feedback
	feedback.play_sound = _record_sound
	feedback.vibrate = _record_vibration

	var locked_id := _test_touch_lift_and_lock()
	var spare: Array[int] = []
	for id in board.cut.size():
		if id != locked_id and spare.size() < 2:
			spare.append(id)
	_a = spare[0]
	_b = spare[1]

	_test_wiring()
	_test_default_seams()
	_test_pick_up()
	_test_join_only()
	_test_lock_only()
	_test_join_and_lock()
	_test_completion()
	_test_sound_off()
	_test_vibration_off()
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
	feedback.sound_enabled = true
	feedback.vibration_enabled = true


# Returns the id of the piece it locked.
func _test_touch_lift_and_lock() -> int:
	_reset()
	var l := pieces.get_child(pieces.get_child_count() - 1) as PieceNode
	var triangles := Geometry2D.triangulate_polygon(board.cut[l.piece_id].outline)
	var outline := board.cut[l.piece_id].outline
	var c := (outline[triangles[0]] + outline[triangles[1]] + outline[triangles[2]]) / 3.0
	_touch(0, _to_screen(c + l.position), true)
	check(_sounds == [Feedback.SOUND_PICK], "pressing a piece plays only the pick sound")
	check(_vibrations.is_empty(), "pressing a piece does not vibrate")
	_drag(0, _to_screen(c), Vector2.ZERO)
	_touch(0, _to_screen(c), false)
	check(_sounds == [Feedback.SOUND_PICK, Feedback.SOUND_LOCK], "dropping a piece on its place plays pick then lock only, got %s" % [_sounds])
	check(_vibrations == [Vector2(25, 1.0)], "dropping a piece on its place vibrates once, as a lock, got %s" % [_vibrations])
	return l.piece_id


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
	check(fresh.sound_enabled and fresh.vibration_enabled, "a fresh node has both switches on")
	fresh.free()


func _test_pick_up() -> void:
	_reset()
	board.cluster_lifted.emit(_a, 1)
	check(_sounds == [Feedback.SOUND_PICK], "pick-up plays the pick sound")
	check(_vibrations.is_empty(), "pick-up does not vibrate")


func _test_join_only() -> void:
	_reset()
	board.pieces_joined.emit(_a, 2)
	check(_sounds == [Feedback.SOUND_JOIN], "a join plays the join sound")
	check(_vibrations == [Vector2(12, 0.5)], "a join gives the light pulse")


func _test_lock_only() -> void:
	_reset()
	board.cluster_locked.emit(_b, 1)
	check(_sounds == [Feedback.SOUND_LOCK], "a lock plays the lock sound")
	check(_vibrations == [Vector2(25, 1.0)], "a lock gives the firm pulse")


func _test_join_and_lock() -> void:
	_reset()
	board.state.move_cluster(_b, Vector2.ZERO)
	board.state.drop(_b)
	check(board.state.is_locked(_b), "the test piece is locked in the state")
	board.pieces_joined.emit(_b, 1)
	board.cluster_locked.emit(_b, 1)
	check(_sounds == [Feedback.SOUND_LOCK], "a join that also locks plays only the lock sound")
	check(_vibrations == [Vector2(25, 1.0)], "a join that also locks gives only the firm pulse")


func _test_completion() -> void:
	_reset()
	board.cluster_locked.emit(_b, 1)
	board.puzzle_completed.emit()
	check(_sounds == [Feedback.SOUND_LOCK, Feedback.SOUND_COMPLETE], "completion plays lock then complete")
	check(_vibrations == [Vector2(25, 1.0), Vector2(60, 1.0)], "completion adds the long pulse")


func _emit_all_four() -> void:
	board.cluster_lifted.emit(_a, 1)
	board.pieces_joined.emit(_a, 2)
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


func _test_export_presets() -> void:
	var config := ConfigFile.new()
	check(config.load("res://export_presets.cfg") == OK, "export_presets.cfg loads")
	check(config.get_value("preset.0.options", "permissions/vibrate") == true, "the Android preset asks for the vibrate permission")
	check(config.get_value("preset.0.options", "package/unique_name") == "io.github.aaryash_shakya.pieceful", "the package name is unchanged")
	var exclude: String = config.get_value("preset.0", "exclude_filter", "")
	var patterns := Array(exclude.split(",")).map(func(p: String) -> String: return p.strip_edges())
	check(patterns.has("tools/*"), "tools are kept out of the APK")
	check(patterns.has("tests/*"), "tests are kept out of the APK")
