class_name Hud
extends CanvasLayer
## Screen-space controls over the board. A CanvasLayer keeps them out of the world
## camera's zoom and pan. The top bar has Pause, the clock and progress; Ghost and Tidy are
## keys on a peach strip under the slot shelf; Pause and Complete are cards over a dimmed board.

const LAYER := 10
const CLEANUP_TEXT := "Tidy"
const HOME_TEXT := "Save and exit"
const RESUME_TEXT := "Resume"
const RESTART_TEXT := "Restart"
const PAUSED_TEXT := "Paused"
const COMPLETE_TEXT := "Complete!"
const SHARE_TEXT := "Share"
const SOUND_TEXT := "Sound"
const VIBRATE_TEXT := "Vibrate"
const GHOST_TEXT := "Ghost"
## The round keys in the top bar.
const BUTTON_SIZE := Vector2(72, 72)
const PILL_HEIGHT := 52.0
const TIMER_WIDTH := 132.0
const PROGRESS_WIDTH := 150.0
const BAR_GAP := 12.0
const TOOL_SIZE := Vector2(150, 92)
const TOOL_ICON_SIZE := 36
const TOOL_GAP := 32
## The peach strip at the very bottom that holds the tool keys. The slot shelf sits on it.
const TOOL_STRIP_HEIGHT := 148.0
const TOOL_STRIP_PADDING := 8.0
const CARD_WIDTH := 456.0
const CARD_GAP := 14
const CARD_BUTTON_HEIGHT := 68
const BIG_TIME_SIZE := 64
const PICTURE_HEIGHT := 240
const DIM := Color(0.1, 0.024, 0.0, 0.62)
const MARGIN_LEFT := 16.0
const MARGIN_RIGHT := 16.0
# Clears the Android status bar, which sits over the top of the viewport.
const MARGIN_TOP := 56.0

@export var board: Board

var root_control: Control
var pause_button: Button
var timer_label: Label
var progress_label: Label
var tool_strip: PanelContainer
var ghost_button: Button
var cleanup_button: Button
var slot_tray: SlotTray
## The Pause card and the dim behind it; hidden until Pause is pressed.
var pause_overlay: Control
var pause_time: Label
var pause_note: Label
var sound_toggle: Button
var vibration_toggle: Button
var ghost_toggle: Button
var resume_button: Button
var restart_button: Button
## Saves and leaves, from the Pause card.
var home_button: Button
var complete_panel: PanelContainer
var share_button: Button
var share_note: Label
var _complete_overlay: Control


func _ready() -> void:
	layer = LAYER

	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.theme = UiTheme.build()
	add_child(root_control)

	slot_tray = SlotTray.new()
	root_control.add_child(slot_tray)

	pause_button = Workshop.round_button("pause")
	pause_button.tooltip_text = PAUSED_TEXT
	_place(pause_button, MARGIN_LEFT, BUTTON_SIZE)
	pause_button.pressed.connect(open_pause)
	root_control.add_child(pause_button)

	timer_label = Workshop.pill("0:00")
	_place(timer_label, MARGIN_LEFT + BUTTON_SIZE.x + BAR_GAP, Vector2(TIMER_WIDTH, PILL_HEIGHT))
	timer_label.offset_top = MARGIN_TOP + (BUTTON_SIZE.y - PILL_HEIGHT) / 2.0
	timer_label.offset_bottom = timer_label.offset_top + PILL_HEIGHT
	root_control.add_child(timer_label)

	progress_label = Workshop.pill("0 / 0")
	progress_label.add_theme_color_override("font_color", Workshop.SUN)
	progress_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	progress_label.offset_right = -MARGIN_RIGHT
	progress_label.offset_left = progress_label.offset_right - PROGRESS_WIDTH
	progress_label.offset_top = timer_label.offset_top
	progress_label.offset_bottom = timer_label.offset_bottom
	root_control.add_child(progress_label)

	_build_tool_strip()
	_build_pause()

	if board != null:
		attach(board)


# Safe to repeat and to re-point, as Feedback.attach is.
func attach(target: Board) -> void:
	if board != null and board != target:
		_disconnect(cleanup_button.pressed, board.cleanup)
		_disconnect(home_button.pressed, board.go_home)
		_disconnect(restart_button.pressed, board.restart)
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
	if not restart_button.pressed.is_connected(board.restart):
		restart_button.pressed.connect(board.restart)


# The board builds its puzzle after this node is ready, so the clock and labels follow it each frame.
func _process(_delta: float) -> void:
	if board == null or board.puzzle == null:
		return
	var clock := ResultCard.format_time(board.elapsed)
	if timer_label.text != clock:
		timer_label.text = clock
	var ghost := ResultCard.ghost_text(board.puzzle.ghost)
	if ghost_button.text != ghost:
		ghost_button.text = ghost
	if board.state != null:
		var placed := "%d / %d" % [board.state.locked_piece_count(), board.state.piece_count()]
		if progress_label.text != placed:
			progress_label.text = placed


## Stops the clock and shows the Pause card with the current time and switches.
func open_pause() -> void:
	if board == null or board.puzzle == null or pause_overlay.visible:
		return
	board.paused = true
	pause_time.text = ResultCard.format_time(board.elapsed)
	if board.state != null:
		pause_note.text = "%s · %d of %d placed" % [board.picture_title(), board.state.locked_piece_count(), board.state.piece_count()]
	var feedback := _feedback()
	sound_toggle.set_pressed_no_signal(feedback == null or feedback.sound_enabled)
	vibration_toggle.set_pressed_no_signal(feedback == null or feedback.vibration_enabled)
	ghost_toggle.set_pressed_no_signal(board.puzzle.ghost)
	pause_overlay.visible = true


func close_pause() -> void:
	pause_overlay.visible = false
	if board != null:
		board.paused = false


func _toggle_ghost() -> void:
	board.set_ghost(not board.puzzle.ghost)


func _feedback() -> Feedback:
	return board.get_node_or_null("Feedback") as Feedback if board != null else null


# The switch changes this board's feedback at once and is written for the boards after it.
func _set_feedback(on: bool, sound: bool) -> void:
	var feedback := _feedback()
	if feedback == null:
		return
	if sound:
		feedback.sound_enabled = on
	else:
		feedback.vibration_enabled = on
	var settings := Settings.load_from(feedback.settings_path)
	if sound:
		settings.sound = on
	else:
		settings.vibration = on
	var err := settings.save_to(feedback.settings_path)
	if err != OK:
		push_warning("Hud: could not save settings to %s (error %d)" % [feedback.settings_path, err])


func _build_tool_strip() -> void:
	tool_strip = PanelContainer.new()
	var paper := StyleBoxFlat.new()
	paper.bg_color = Workshop.PEACH
	paper.border_color = Workshop.RIM
	paper.border_width_top = UiTheme.RIM_WIDTH
	paper.content_margin_top = TOOL_STRIP_PADDING
	paper.content_margin_bottom = TOOL_STRIP_PADDING
	tool_strip.add_theme_stylebox_override("panel", paper)
	tool_strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tool_strip.offset_top = -TOOL_STRIP_HEIGHT
	tool_strip.offset_bottom = 0.0
	tool_strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# The strip is the HUD's, so a touch between the keys never reaches the board.
	tool_strip.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(tool_strip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", TOOL_GAP)
	tool_strip.add_child(row)
	ghost_button = _tool("eye", ResultCard.ghost_text(true))
	row.add_child(ghost_button)
	cleanup_button = _tool("tidy", CLEANUP_TEXT)
	row.add_child(cleanup_button)


func _tool(icon_name: String, text: String) -> Button:
	var button := Button.new()
	button.theme_type_variation = Workshop.TOOL_BUTTON
	button.text = text
	button.icon = Workshop.icon(icon_name)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.add_theme_constant_override("icon_max_width", TOOL_ICON_SIZE)
	button.custom_minimum_size = TOOL_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	return button


func _build_pause() -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", CARD_GAP)
	pause_time = Label.new()
	pause_time.theme_type_variation = Workshop.INK_TITLE
	pause_time.add_theme_font_size_override("font_size", BIG_TIME_SIZE)
	pause_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(pause_time)
	pause_note = Label.new()
	pause_note.theme_type_variation = Workshop.INK_LABEL
	pause_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(pause_note)

	var line := PanelContainer.new()
	line.theme_type_variation = Workshop.LINE
	body.add_child(line)
	var switches := HBoxContainer.new()
	switches.alignment = BoxContainer.ALIGNMENT_CENTER
	switches.add_theme_constant_override("separation", TOOL_GAP)
	line.add_child(switches)
	sound_toggle = _switch(switches, "sound", SOUND_TEXT)
	sound_toggle.toggled.connect(_set_feedback.bind(true))
	vibration_toggle = _switch(switches, "buzz", VIBRATE_TEXT)
	vibration_toggle.toggled.connect(_set_feedback.bind(false))
	ghost_toggle = _switch(switches, "eye", GHOST_TEXT)
	ghost_toggle.toggled.connect(func(on: bool) -> void: board.set_ghost(on))

	resume_button = _card_button(body, RESUME_TEXT, "play", &"")
	resume_button.pressed.connect(close_pause)
	restart_button = _card_button(body, RESTART_TEXT, "redo", Workshop.ORANGE_BUTTON)
	home_button = _card_button(body, HOME_TEXT, "exit", Workshop.RED_BUTTON)
	pause_overlay = _overlay(Workshop.card(PAUSED_TEXT, body, true))
	pause_overlay.visible = false


func _switch(parent: Control, icon_name: String, text: String) -> Button:
	var column := VBoxContainer.new()
	parent.add_child(column)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = Workshop.INK_LABEL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	var toggle := Workshop.round_button(icon_name, Workshop.ROUND_TOGGLE)
	toggle.toggle_mode = true
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(toggle)
	return toggle


func _card_button(parent: Control, text: String, icon_name: String, variation: StringName) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = Workshop.icon(icon_name)
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0, CARD_BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button


# A card centred over a dim that takes every touch, so the board under it stays still.
func _overlay(card: PanelContainer) -> Control:
	var overlay := ColorRect.new()
	overlay.color = DIM
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(overlay)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(centre)
	card.custom_minimum_size.x = CARD_WIDTH
	centre.add_child(card)
	return overlay


# Built when the puzzle is finished, from the board's own puzzle, so it always shows the real result.
func _show_complete() -> void:
	if _complete_overlay != null:
		_complete_overlay.queue_free()
	close_pause()
	var card := ResultCard.lines(board.picture_title(), board.puzzle, board.elapsed)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", CARD_GAP)
	body.add_child(Workshop.framed(board.ghost_sprite.texture, PICTURE_HEIGHT))
	var heading := Label.new()
	heading.text = card[0]
	heading.theme_type_variation = UiTheme.TITLE
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(heading)
	var time := Label.new()
	time.text = ResultCard.format_time(board.elapsed)
	time.theme_type_variation = UiTheme.TITLE
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time.add_theme_font_size_override("font_size", BIG_TIME_SIZE)
	time.add_theme_color_override("font_color", Workshop.SUN)
	time.add_theme_color_override("font_shadow_color", Color.BLACK)
	time.add_theme_constant_override("shadow_offset_y", 3)
	body.add_child(time)
	for i in range(1, card.size()):
		var pill := Workshop.pill(card[i])
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(pill)
	share_note = Label.new()
	share_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	share_note.visible = false
	body.add_child(share_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", TOOL_GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	var done := Workshop.round_button("home48")
	done.tooltip_text = "Home"
	done.pressed.connect(board.go_home)
	row.add_child(done)
	var again := Workshop.round_button("redo")
	again.tooltip_text = "Play again"
	again.pressed.connect(board.restart)
	row.add_child(again)
	share_button = Workshop.round_button("share")
	share_button.tooltip_text = SHARE_TEXT
	share_button.pressed.connect(_share)
	row.add_child(share_button)
	complete_panel = Workshop.card(COMPLETE_TEXT, body)
	_complete_overlay = _overlay(complete_panel)


func _share() -> void:
	var text := ResultCard.share_text(board.picture_title(), board.puzzle, board.elapsed)
	var outcome := Share.send(text)
	share_note.text = "Copied to the clipboard" if outcome == Share.Outcome.COPIED else "Shared"
	share_note.visible = true


func _disconnect(pressed: Signal, handler: Callable) -> void:
	if pressed.is_connected(handler):
		pressed.disconnect(handler)


# A top-bar item at the top margin. Touches on a button stop there and it never takes focus.
func _place(control: Control, left: float, item_size: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = left
	control.offset_right = left + item_size.x
	control.offset_top = MARGIN_TOP
	control.offset_bottom = MARGIN_TOP + item_size.y
	if control is Button:
		control.mouse_filter = Control.MOUSE_FILTER_STOP
