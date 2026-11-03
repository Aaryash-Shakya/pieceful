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
	board = target
	board.cluster_lifted.connect(_on_cluster_lifted)
	board.pieces_joined.connect(_on_pieces_joined)
	board.cluster_locked.connect(_on_cluster_locked)
	board.puzzle_completed.connect(_on_puzzle_completed)


func _play(sound: StringName) -> void:
	_players[sound].play()


func _on_cluster_lifted(_root: int, _count: int) -> void:
	_sound(SOUND_PICK)


func _on_pieces_joined(root: int, _count: int) -> void:
	# A drop that joins and locks emits both signals; the lock that follows is the stronger feedback.
	if board.state.is_locked(root):
		return
	_sound(SOUND_JOIN)
	_buzz(JOIN_VIBRATION_MS, JOIN_VIBRATION_AMPLITUDE)


func _on_cluster_locked(_root: int, _count: int) -> void:
	_sound(SOUND_LOCK)
	_buzz(LOCK_VIBRATION_MS, LOCK_VIBRATION_AMPLITUDE)


func _on_puzzle_completed() -> void:
	_sound(SOUND_COMPLETE)
	_buzz(COMPLETE_VIBRATION_MS, COMPLETE_VIBRATION_AMPLITUDE)


func _sound(sound: StringName) -> void:
	if sound_enabled:
		play_sound.call(sound)


func _buzz(duration_ms: int, amplitude: float) -> void:
	if vibration_enabled:
		vibrate.call(duration_ms, amplitude)
