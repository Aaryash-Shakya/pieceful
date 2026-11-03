class_name SlotTray
extends Control
## The four sorting slots along the bottom of the screen. It only draws and shows counts: the board
## hit-tests the rectangles from raw touches, so every touch has one path and this never takes input.

const SLOT_HEIGHT := 88.0
const GAP := 12.0
const MARGIN_SIDE := 16.0
const MARGIN_BOTTOM := 24.0
const STACK_TILES := 3
const TILE_STEP := Vector2(5.0, -5.0)
const BORDER_WIDTH := 2.0

var board: Board
var rects: Array[Rect2] = []
var counts := PackedInt32Array([0, 0, 0, 0])
var _badges: Array[Label] = []


## The four slot rectangles for a viewport, left to right along the bottom edge.
static func rects_for(viewport: Vector2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var width := (viewport.x - 2.0 * MARGIN_SIDE - GAP * (PuzzleState.SLOT_COUNT - 1)) / PuzzleState.SLOT_COUNT
	var top := viewport.y - MARGIN_BOTTOM - SLOT_HEIGHT
	for s in PuzzleState.SLOT_COUNT:
		result.append(Rect2(MARGIN_SIDE + s * (width + GAP), top, width, SLOT_HEIGHT))
	return result


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in PuzzleState.SLOT_COUNT:
		var badge := Label.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font", UiTheme.weighted(UiTheme.BALOO_PATH, UiTheme.BUTTON_WEIGHT))
		badge.add_theme_font_size_override("font_size", UiTheme.TITLE_FONT_SIZE)
		# The tray sits on the navy table in both modes, so its text is the dark mode's.
		badge.add_theme_color_override("font_color", Palette.text(true))
		add_child(badge)
		_badges.append(badge)
	resized.connect(_layout)
	_layout()


# Safe to repeat and to re-point, as Hud.attach is.
func attach(target: Board) -> void:
	if board != null and board != target and board.slots_changed.is_connected(refresh):
		board.slots_changed.disconnect(refresh)
	board = target
	if not board.slots_changed.is_connected(refresh):
		board.slots_changed.connect(refresh)
	board.slot_rects = rects
	refresh()


func refresh() -> void:
	for s in PuzzleState.SLOT_COUNT:
		counts[s] = board.state.slot_piece_count(s) if board != null and board.state != null else 0
		if s < _badges.size():
			_badges[s].text = str(counts[s]) if counts[s] > 0 else ""
	queue_redraw()


func _layout() -> void:
	rects = rects_for(get_viewport_rect().size)
	for s in _badges.size():
		_badges[s].position = rects[s].position
		_badges[s].size = rects[s].size
	if board != null:
		board.slot_rects = rects
	queue_redraw()


func _draw() -> void:
	for s in rects.size():
		var rect := rects[s]
		var filled := counts[s] > 0
		if filled:
			for t in range(STACK_TILES - 1, 0, -1):
				_panel(Rect2(rect.position + TILE_STEP * t, rect.size), Palette.raised_surface(true), Palette.lines(true))
		_panel(rect, Palette.surface(true), Palette.accent() if filled else Palette.lines(true))


func _panel(rect: Rect2, fill: Color, border: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(int(BORDER_WIDTH))
	box.set_corner_radius_all(UiTheme.OPTION_RADIUS)
	draw_style_box(box, rect)
