class_name Hud
extends CanvasLayer
## Screen-space controls over the board. A CanvasLayer keeps them out of the world
## camera's zoom and pan.

const LAYER := 10
const CLEANUP_TEXT := "Tidy"
const HOME_TEXT := "Home"
const COMPLETE_TEXT := "Puzzle complete"
const SHARE_TEXT := "Share"
const BUTTON_SIZE := Vector2(120, 64)
const GHOST_BUTTON_WIDTH := 140.0
const BUTTON_GAP := 8.0
const TIMER_WIDTH := 124.0
const MARGIN_LEFT := 16.0
const MARGIN_RIGHT := 16.0
# Clears the Android status bar, which sits over the top of the viewport.
const MARGIN_TOP := 56.0

@export var board: Board

var root_control: Control
var cleanup_button: Button
var home_button: Button
var ghost_button: Button
var timer_label: Label
var slot_tray: SlotTray
var complete_panel: PanelContainer
var share_button: Button
var share_note: Label


func _ready() -> void:
	layer = LAYER

	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.theme = UiTheme.build()
	add_child(root_control)

	slot_tray = SlotTray.new()
	root_control.add_child(slot_tray)

	cleanup_button = _make_button(CLEANUP_TEXT)
	cleanup_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cleanup_button.offset_left = -MARGIN_RIGHT - BUTTON_SIZE.x
	cleanup_button.offset_right = -MARGIN_RIGHT
	cleanup_button.offset_top = MARGIN_TOP
	cleanup_button.offset_bottom = MARGIN_TOP + BUTTON_SIZE.y

	ghost_button = _make_button(ResultCard.ghost_text(true))
	ghost_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ghost_button.offset_right = -MARGIN_RIGHT - BUTTON_SIZE.x - BUTTON_GAP
	ghost_button.offset_left = ghost_button.offset_right - GHOST_BUTTON_WIDTH
	ghost_button.offset_top = MARGIN_TOP
	ghost_button.offset_bottom = MARGIN_TOP + BUTTON_SIZE.y

	timer_label = Label.new()
	timer_label.theme_type_variation = UiTheme.TITLE
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	timer_label.offset_left = MARGIN_LEFT + BUTTON_SIZE.x + BUTTON_GAP
	timer_label.offset_right = timer_label.offset_left + TIMER_WIDTH
	timer_label.offset_top = MARGIN_TOP
	timer_label.offset_bottom = MARGIN_TOP + BUTTON_SIZE.y
	# On the navy table in both modes, so the light-mode text colour would vanish.
	timer_label.add_theme_color_override("font_color", Palette.text(true))
	root_control.add_child(timer_label)

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
		_disconnect(board.puzzle_completed, _show_complete)
		_disconnect(ghost_button.pressed, _toggle_ghost)
	board = target
	slot_tray.attach(board)
	if not board.puzzle_completed.is_connected(_show_complete):
		board.puzzle_completed.connect(_show_complete)
	if not ghost_button.pressed.is_connected(_toggle_ghost):
		ghost_button.pressed.connect(_toggle_ghost)
	if not cleanup_button.pressed.is_connected(board.cleanup):
		cleanup_button.pressed.connect(board.cleanup)
	if not home_button.pressed.is_connected(board.go_home):
		home_button.pressed.connect(board.go_home)


# The board builds its puzzle after this node is ready, so the clock and the ghost label follow it each frame.
func _process(_delta: float) -> void:
	if board == null or board.puzzle == null:
		return
	var clock := ResultCard.format_time(board.elapsed)
	if timer_label.text != clock:
		timer_label.text = clock
	var ghost := ResultCard.ghost_text(board.puzzle.ghost)
	if ghost_button.text != ghost:
		ghost_button.text = ghost


func _toggle_ghost() -> void:
	board.set_ghost(not board.puzzle.ghost)


# Built when the puzzle is finished, from the board's own puzzle, so it always shows the real result.
func _show_complete() -> void:
	if complete_panel != null:
		complete_panel.queue_free()
	var card := ResultCard.lines(board.picture_title(), board.puzzle, board.elapsed)
	complete_panel = PanelContainer.new()
	complete_panel.set_anchors_preset(Control.PRESET_CENTER)
	complete_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	complete_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	complete_panel.theme_type_variation = UiTheme.SHEET
	complete_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	complete_panel.add_child(column)
	var heading := Label.new()
	heading.text = COMPLETE_TEXT
	heading.theme_type_variation = UiTheme.TITLE
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	for line in card:
		var label := Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	share_note = Label.new()
	share_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	share_note.visible = false
	column.add_child(share_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	share_button = Button.new()
	share_button.text = SHARE_TEXT
	share_button.focus_mode = Control.FOCUS_NONE
	share_button.pressed.connect(_share)
	row.add_child(share_button)
	var done := Button.new()
	done.text = HOME_TEXT
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(board.go_home)
	row.add_child(done)
	root_control.add_child(complete_panel)


func _share() -> void:
	var text := ResultCard.share_text(board.picture_title(), board.puzzle, board.elapsed)
	var outcome := Share.send(text)
	share_note.text = "Copied to the clipboard" if outcome == Share.Outcome.COPIED else "Shared"
	share_note.visible = true


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
