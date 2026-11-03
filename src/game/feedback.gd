class_name Feedback
extends Node
## Plays the sound and vibration for the board's signals. It does nothing per frame.

const SOUND_PICK := &"pick"
const SOUND_JOIN := &"join"
const SOUND_LOCK := &"lock"
const SOUND_COMPLETE := &"complete"

const STREAMS := {
	SOUND_PICK: preload("res://assets/sounds/pick.wav"),
	SOUND_JOIN: preload("res://assets/sounds/join.wav"),
	SOUND_LOCK: preload("res://assets/sounds/lock.wav"),
	SOUND_COMPLETE: preload("res://assets/sounds/complete.wav"),
}
# Two quick drops must both play in full, so one player may mix several plays of its sound.
const MAX_POLYPHONY := 4

const JOIN_VIBRATION_MS := 12
const JOIN_VIBRATION_AMPLITUDE := 0.5
const LOCK_VIBRATION_MS := 25
const LOCK_VIBRATION_AMPLITUDE := 1.0
const COMPLETE_VIBRATION_MS := 60
const COMPLETE_VIBRATION_AMPLITUDE := 1.0

@export var board: Board

## Where the sound and vibration switches are read from when the node enters the tree.
var settings_path := Settings.DEFAULT_PATH
var sound_enabled := true
var vibration_enabled := true
# Seams for tests: called as play_sound.call(sound) and vibrate.call(duration_ms, amplitude).
var play_sound: Callable
var vibrate: Callable

var _players: Dictionary[StringName, AudioStreamPlayer] = {}


func _init() -> void:
	play_sound = _play
	vibrate = Input.vibrate_handheld


func _ready() -> void:
	var settings := Settings.load_from(settings_path)
	sound_enabled = settings.sound
	vibration_enabled = settings.vibration
	for key: StringName in STREAMS:
		var player := AudioStreamPlayer.new()
		player.name = String(key).capitalize()
		player.stream = STREAMS[key]
		player.max_polyphony = MAX_POLYPHONY
		add_child(player)
		_players[key] = player
	if board != null:
		attach(board)


func attach(target: Board) -> void:
	if board != null and board != target:
		_link(board, false)
	board = target
	_link(board, true)


# Safe to repeat: a signal is only connected or disconnected when it is not already so.
func _link(source: Board, connected: bool) -> void:
	var pairs: Array[Array] = [
		[source.cluster_lifted, _on_cluster_lifted],
		[source.pieces_joined, _on_pieces_joined],
		[source.cluster_locked, _on_cluster_locked],
		[source.puzzle_completed, _on_puzzle_completed],
		[source.stashed, _on_stashed],
	]
	for pair in pairs:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler) == connected:
			continue
		if connected:
			sig.connect(handler)
		else:
			sig.disconnect(handler)


func _play(sound: StringName) -> void:
	_players[sound].play()


func _on_cluster_lifted(_root: int, _count: int) -> void:
	_sound(SOUND_PICK)


func _on_pieces_joined(_root: int, _count: int, locked: bool) -> void:
	# A drop that joins and locks emits both signals; the lock that follows is the stronger feedback.
	if locked:
		return
	_sound(SOUND_JOIN)
	_buzz(JOIN_VIBRATION_MS, JOIN_VIBRATION_AMPLITUDE)


func _on_cluster_locked(_root: int, _count: int) -> void:
	_sound(SOUND_LOCK)
	_buzz(LOCK_VIBRATION_MS, LOCK_VIBRATION_AMPLITUDE)


func _on_stashed(_count: int) -> void:
	# The same light click as a join: putting a stack away is a small, certain act.
	_sound(SOUND_JOIN)
	_buzz(JOIN_VIBRATION_MS, JOIN_VIBRATION_AMPLITUDE)


func _on_puzzle_completed() -> void:
	_sound(SOUND_COMPLETE)
	_buzz(COMPLETE_VIBRATION_MS, COMPLETE_VIBRATION_AMPLITUDE)


func _sound(sound: StringName) -> void:
	if sound_enabled and not board.releasing_for_system:
		play_sound.call(sound)


func _buzz(duration_ms: int, amplitude: float) -> void:
	if vibration_enabled and not board.releasing_for_system:
		vibrate.call(duration_ms, amplitude)
