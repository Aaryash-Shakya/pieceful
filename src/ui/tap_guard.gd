class_name TapGuard
extends RefCounted
## Tells a tap from a scroll for buttons that sit in a ScrollContainer.

## How far a finger may travel and still tap. Further, it is a scroll, and the tile under it is not chosen.
const SLOP := 8.0

var _press_at := Vector2.ZERO
# Set on a release that travelled past SLOP, read by the pressed handler that follows it.
var _swiped := false
# Motion counts toward a swipe only while a press is down; a hovering mouse is not dragging.
var _pointer_down := false


## Read once, so a press that arrives without pointer input (a test, accessibility) is never
## mistaken for the last swipe.
func take_swipe() -> bool:
	var swiped := _swiped
	_swiped = false
	return swiped


## Connect to a button's gui_input. A button in a scroller still fires when the finger lifts over it
## after scrolling. The gui_input signal runs before the button's own handling, so the release is
## judged here and the pressed handler that follows undoes the toggle. The furthest point counts,
## so a swipe that comes back is still a swipe.
func watch(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button_event := event as InputEventMouseButton
		if button_event.pressed:
			_press_at = button_event.global_position
			_swiped = false
			_pointer_down = true
		elif _pointer_down:
			_pointer_down = false
			_note_travel(button_event.global_position)
	elif event is InputEventMouseMotion and _pointer_down:
		_note_travel((event as InputEventMouseMotion).global_position)


func _note_travel(at: Vector2) -> void:
	if at.distance_to(_press_at) > SLOP:
		_swiped = true
