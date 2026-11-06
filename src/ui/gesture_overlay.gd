class_name GestureOverlay
extends CanvasLayer
## Debug-only readout of what the board thinks the fingers are doing: its mode, how long each
## finger has been silent, and the last few touch lines. A screenshot of it, or the saved trace,
## shows a lost release. Sits just under the frame counter.

const REFRESH_INTERVAL := 0.1
const FONT_SIZE := 18
const TRACE_LINES := 5
const MARGIN_LEFT := 16
const MARGIN_TOP := FpsCounter.MARGIN_TOP + 36
const STALE_COLOR := Color(1.0, 0.35, 0.3)

var board: Board

var _label: Label
var _timer: Timer


func _ready() -> void:
	if not OS.is_debug_build() or board == null:
		queue_free()
		return
	layer = 99
	_label = Label.new()
	_label.position = Vector2(MARGIN_LEFT, MARGIN_TOP)
	_label.custom_minimum_size.x = 540 - 2 * MARGIN_LEFT
	_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Palette.accent())
	_label.add_theme_color_override("font_outline_color", Palette.outline())
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_timer = Timer.new()
	_timer.wait_time = REFRESH_INTERVAL
	_timer.timeout.connect(refresh)
	add_child(_timer)
	_timer.start()
	refresh()


func refresh() -> void:
	_label.text = board.gesture_report() + "\n" + "\n".join(board.trace.tail(TRACE_LINES))
	_label.add_theme_color_override("font_color", STALE_COLOR if board.has_stale_finger() else Palette.accent())


func text() -> String:
	return _label.text
