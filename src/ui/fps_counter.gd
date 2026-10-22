class_name FpsCounter
extends CanvasLayer
## Debug-only frame-rate readout. A CanvasLayer keeps it in screen space, so it
## does not zoom with the world camera.

const REFRESH_INTERVAL := 0.25
const FONT_SIZE := 22
const MARGIN_LEFT := 16
# Clears the Android status bar, which sits over the top of the viewport.
const MARGIN_TOP := 56

var _label: Label
var _timer: Timer


static func format_text(fps: int, refresh_rate: float) -> String:
	if refresh_rate <= 0.0:
		return "%d fps" % fps
	return "%d fps  %d Hz" % [fps, roundi(refresh_rate)]


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	_label = Label.new()
	_label.position = Vector2(MARGIN_LEFT, MARGIN_TOP)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Palette.accent())
	_label.add_theme_color_override("font_outline_color", Palette.outline())
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)

	_timer = Timer.new()
	_timer.wait_time = REFRESH_INTERVAL
	_timer.timeout.connect(_refresh)
	add_child(_timer)
	_timer.start()
	_refresh()


func _refresh() -> void:
	_label.text = format_text(roundi(Engine.get_frames_per_second()), DisplayServer.screen_get_refresh_rate())
