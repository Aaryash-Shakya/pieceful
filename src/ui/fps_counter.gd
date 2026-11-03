class_name FpsCounter
extends CanvasLayer
## Debug-only frame-rate readout. A CanvasLayer keeps it in screen space, so it
## does not zoom with the world camera.

const REFRESH_INTERVAL := 0.25
const FONT_SIZE := 22
const MARGIN_LEFT := 16
# Below the HUD's button row (Hud.MARGIN_TOP + Hud.BUTTON_SIZE.y + 12), written out so this debug
# counter does not depend on the HUD class.
const MARGIN_TOP := 132

var _label: Label
var _timer: Timer
# Longest frame since the last refresh. The fps figure is a one-second average, so
# a single hitch only shows up here.
var _worst_frame := 0.0


static func format_text(fps: int, refresh_rate: float, worst_frame: float) -> String:
	var worst_ms := roundi(worst_frame * 1000.0)
	if refresh_rate <= 0.0:
		return "%d fps  worst %d ms" % [fps, worst_ms]
	return "%d fps  %d Hz  worst %d ms" % [fps, roundi(refresh_rate), worst_ms]


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
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


func _process(delta: float) -> void:
	_worst_frame = maxf(_worst_frame, delta)


func _refresh() -> void:
	_label.text = format_text(roundi(Engine.get_frames_per_second()), DisplayServer.screen_get_refresh_rate(), _worst_frame)
	_worst_frame = 0.0
