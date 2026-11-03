class_name Hud
extends CanvasLayer
## Screen-space controls over the board. A CanvasLayer keeps them out of the world
## camera's zoom and pan.

const LAYER := 10
const CLEANUP_TEXT := "Tidy"
const BUTTON_SIZE := Vector2(120, 64)
const MARGIN_RIGHT := 16.0
const MARGIN_TOP := FpsCounter.MARGIN_TOP

@export var board: Board

var root_control: Control
var cleanup_button: Button


func _ready() -> void:
	layer = LAYER

	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.theme = UiTheme.build()
	add_child(root_control)

	cleanup_button = Button.new()
	cleanup_button.text = CLEANUP_TEXT
	cleanup_button.mouse_filter = Control.MOUSE_FILTER_STOP
	cleanup_button.focus_mode = Control.FOCUS_NONE
	cleanup_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cleanup_button.offset_left = -MARGIN_RIGHT - BUTTON_SIZE.x
	cleanup_button.offset_right = -MARGIN_RIGHT
	cleanup_button.offset_top = MARGIN_TOP
	cleanup_button.offset_bottom = MARGIN_TOP + BUTTON_SIZE.y
	root_control.add_child(cleanup_button)

	if board != null:
		attach(board)


# Safe to repeat and to re-point, as Feedback.attach is.
func attach(target: Board) -> void:
	var pressed := cleanup_button.pressed
	if board != null and board != target and pressed.is_connected(board.cleanup):
		pressed.disconnect(board.cleanup)
	board = target
	if not pressed.is_connected(board.cleanup):
		pressed.connect(board.cleanup)
