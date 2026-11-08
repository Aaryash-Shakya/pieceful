class_name SlotTray
extends Control
## The four sorting slots along the bottom of the screen. Each shows its actual pieces, shrunk, so a
## stack of blue sky pieces reads as blue from across the screen. A small corner badge gives the count.
## The board hit-tests the rectangles from raw touches, so every touch has one path and this never takes input.

const SLOT_HEIGHT := 88.0
const GAP := 12.0
const MARGIN_SIDE := 16.0
const MARGIN_BOTTOM := 24.0
const BORDER_WIDTH := 2.0
const HOVER_BORDER_WIDTH := 4.0
const HOVER_TINT := 0.28
const INNER_PADDING := 6.0
# Fraction of its grid cell a shrunk cluster fills, so neighbours do not touch.
const CELL_FILL := 0.92
# Past this many drawn clusters or pieces a slot shows the newest, so a huge stack stays cheap to rebuild.
const MAX_MINI_CLUSTERS := 16
const MAX_MINI_PIECES := 80
const MINI_OUTLINE := 1.5
const BADGE_FONT_SIZE := 16
const BADGE_SIZE := Vector2(30, 20)
const BADGE_INSET := 4.0

var board: Board
var rects: Array[Rect2] = []
var counts := PackedInt32Array([0, 0, 0, 0])
## The slot a release would put the held pieces in, or -1.
var hover := -1
var _badges: Array[Label] = []
var _minis: Array[Node2D] = []


## The four slot rectangles for a viewport, left to right along the bottom edge.
static func rects_for(viewport: Vector2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var width := (viewport.x - 2.0 * MARGIN_SIDE - GAP * (PuzzleState.SLOT_COUNT - 1)) / PuzzleState.SLOT_COUNT
	var top := viewport.y - MARGIN_BOTTOM - SLOT_HEIGHT
	for s in PuzzleState.SLOT_COUNT:
		result.append(Rect2(MARGIN_SIDE + s * (width + GAP), top, width, SLOT_HEIGHT))
	return result


## Packs clusters into a grid inside the area and shrinks each to fit its cell. Entry k is the point
## the middle of cluster k's home rectangle goes to (x, y) and the scale to draw it at (z).
static func fit(home_rects: Array[Rect2], area: Rect2) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var count := home_rects.size()
	if count == 0:
		return result
	var columns := ceili(sqrt(float(count) * area.size.x / area.size.y))
	columns = clampi(columns, 1, count)
	var rows := ceili(float(count) / columns)
	var cell := Vector2(area.size.x / columns, area.size.y / rows)
	for i in count:
		var home := home_rects[i]
		var scale_to_fit := minf(cell.x / home.size.x, cell.y / home.size.y) * CELL_FILL
		var middle := area.position + Vector2(i % columns + 0.5, i / columns + 0.5) * cell
		result.append(Vector3(middle.x, middle.y, scale_to_fit))
	return result


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in PuzzleState.SLOT_COUNT:
		var mini := Node2D.new()
		add_child(mini)
		_minis.append(mini)
	for s in PuzzleState.SLOT_COUNT:
		var badge := Label.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font", load(UiTheme.BUTTON_PATH))
		badge.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
		# The tray sits on the navy table in both modes, so its text is the dark mode's.
		badge.add_theme_color_override("font_color", Palette.text(true))
		var pill := StyleBoxFlat.new()
		pill.bg_color = Color(Palette.page_background(true), 0.85)
		pill.set_corner_radius_all(int(BADGE_SIZE.y / 2.0))
		badge.add_theme_stylebox_override("normal", pill)
		add_child(badge)
		_badges.append(badge)
	resized.connect(_layout)
	_layout()


# Safe to repeat and to re-point, as Hud.attach is.
func attach(target: Board) -> void:
	if board != null and board != target:
		if board.slots_changed.is_connected(refresh):
			board.slots_changed.disconnect(refresh)
		if board.slot_hover_changed.is_connected(_on_hover):
			board.slot_hover_changed.disconnect(_on_hover)
	board = target
	if not board.slots_changed.is_connected(refresh):
		board.slots_changed.connect(refresh)
	if not board.slot_hover_changed.is_connected(_on_hover):
		board.slot_hover_changed.connect(_on_hover)
	board.slot_rects = rects
	refresh()


func refresh() -> void:
	var ready := board != null and board.state != null
	for s in PuzzleState.SLOT_COUNT:
		counts[s] = board.state.slot_piece_count(s) if ready else 0
		if s < _badges.size():
			_badges[s].text = str(counts[s])
			_badges[s].visible = counts[s] > 0
		if s < _minis.size():
			_rebuild_mini(s)
	queue_redraw()


# Redrawn from the state each time a slot changes, never per frame.
func _rebuild_mini(slot: int) -> void:
	var mini := _minis[slot]
	for child in mini.get_children():
		child.queue_free()
		mini.remove_child(child)
	if counts[slot] == 0 or slot >= rects.size():
		return
	var roots := board.state.slot_roots(slot)
	# Newest on top of the stack are last, so the tail is what stays when the slot is too full to show all.
	var first := maxi(0, roots.size() - MAX_MINI_CLUSTERS)
	var shown: Array[int] = []
	var drawn_pieces := 0
	for k in range(roots.size() - 1, first - 1, -1):
		var size := board.state.members(roots[k]).size()
		if not shown.is_empty() and drawn_pieces + size > MAX_MINI_PIECES:
			break
		shown.push_front(roots[k])
		drawn_pieces += size
	var homes: Array[Rect2] = []
	for root in shown:
		homes.append(board.cluster_home_rect(root))
	var area := Rect2(Vector2.ZERO, rects[slot].size).grow(-INNER_PADDING)
	var placement := fit(homes, area)
	for k in shown.size():
		var centre := Vector2(placement[k].x, placement[k].y) + rects[slot].position
		_add_cluster(mini, shown[k], homes[k].get_center(), centre, placement[k].z)


func _add_cluster(parent: Node2D, root: int, home_centre: Vector2, target: Vector2, scale_value: float) -> void:
	var holder := Node2D.new()
	holder.scale = Vector2(scale_value, scale_value)
	holder.position = target - home_centre * scale_value
	parent.add_child(holder)
	var texture := board.ghost_sprite.texture
	for id in board.state.members(root):
		var outline := board.cut[id].outline
		var body := Polygon2D.new()
		body.polygon = outline
		body.uv = outline
		body.texture = texture
		holder.add_child(body)
		var line := Line2D.new()
		line.points = outline
		line.closed = true
		# Constant on screen however far the cluster is shrunk.
		line.width = MINI_OUTLINE / scale_value
		line.default_color = Color(Palette.outline(), 0.8)
		holder.add_child(line)


func _layout() -> void:
	rects = rects_for(get_viewport_rect().size)
	for s in _badges.size():
		_badges[s].size = BADGE_SIZE
		_badges[s].position = Vector2(rects[s].end.x - BADGE_SIZE.x - BADGE_INSET, rects[s].position.y + BADGE_INSET)
	if board != null:
		board.slot_rects = rects
		refresh()
	queue_redraw()


func _on_hover(slot: int) -> void:
	hover = slot
	queue_redraw()


func _draw() -> void:
	for s in rects.size():
		var filled := counts[s] > 0
		var target := s == hover
		var box := StyleBoxFlat.new()
		# The slot a release would fill glows in the accent colour with a thick border.
		box.bg_color = Palette.surface(true).lerp(Palette.accent(), HOVER_TINT) if target else Palette.surface(true)
		box.border_color = Palette.accent() if filled or target else Palette.lines(true)
		box.set_border_width_all(int(HOVER_BORDER_WIDTH if target else BORDER_WIDTH))
		box.set_corner_radius_all(UiTheme.OPTION_RADIUS)
		draw_style_box(box, rects[s])
