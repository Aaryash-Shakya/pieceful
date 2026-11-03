class_name Hud
extends CanvasLayer
## Screen-space controls over the board. A CanvasLayer keeps them out of the world
## camera's zoom and pan.

const LAYER := 10
const CLEANUP_TEXT := "Tidy"
const HOME_TEXT := "Home"
const BUTTON_SIZE := Vector2(120, 64)
const MARGIN_LEFT := 16.0
const MARGIN_RIGHT := 16.0
# Clears the Android status bar, which sits over the top of the viewport.
const MARGIN_TOP := 56.0

@export var board: Board

var root_control: Control
var cleanup_button: Button
var home_button: Button


func _ready() -> void:
	layer = LAYER

	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.theme = UiTheme.build()
	add_child(root_control)

	cleanup_button = _make_button(CLEANUP_TEXT)
	cleanup_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cleanup_button.offset_left = -MARGIN_RIGHT - BUTTON_SIZE.x
	cleanup_button.offset_right = -MARGIN_RIGHT
	cleanup_button.offset_top = MARGIN_TOP
	cleanup_button.offset_bottom = MARGIN_TOP + BUTTON_SIZE.y

	home_button = _make_button(HOME_TEXT)
	home_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	home_button.offset_left = MARGIN_LEFT
	home_button.offset_right = MARGIN_LEFT + BUTTON_SIZE.x
	home_button.offset_top = MARGIN_TOP
	home_button.offset_bottom = MARGIN_TOP + BUTTON_SIZE.y

	if board != null:
		attach(board)


# Safe to repeat and to re-point, as Feedback.attach is.
func attach(target: Board) -> void:
	if board != null and board != target:
		_disconnect(cleanup_button.pressed, board.cleanup)
		_disconnect(home_button.pressed, board.go_home)
	board = target
	if not cleanup_button.pressed.is_connected(board.cleanup):
		cleanup_button.pressed.connect(board.cleanup)
	if not home_button.pressed.is_connected(board.go_home):
		home_button.pressed.connect(board.go_home)


func _disconnect(pressed: Signal, handler: Callable) -> void:
	if pressed.is_connected(handler):
		pressed.disconnect(handler)


# Touches on a button stop there, and it never takes focus, so it never reaches the board.
func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	root_control.add_child(button)
	return button
