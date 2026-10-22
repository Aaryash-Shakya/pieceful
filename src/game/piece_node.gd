class_name PieceNode
extends Node2D
## One puzzle piece. Outlines are in image coordinates, so `position` is the
## displacement from home and a solved piece sits at Vector2.ZERO.

const OUTLINE_WIDTH := 2.3
const SHADOW_OFFSET := Vector2(4, 5)
const SHADOW_COLOR := Color(0, 0, 0, 0.35)

var piece_id: int

var _outline: PackedVector2Array
var _shadow: Polygon2D


func setup(piece: CutPiece, texture: Texture2D, outline_color: Color) -> void:
	piece_id = piece.id
	_outline = piece.outline

	_shadow = Polygon2D.new()
	_shadow.polygon = _outline
	_shadow.color = SHADOW_COLOR
	_shadow.position = SHADOW_OFFSET
	_shadow.visible = false
	add_child(_shadow)

	# uv equals the outline, so the full image is the texture and no baking is needed.
	var body := Polygon2D.new()
	body.polygon = _outline
	body.uv = _outline
	body.texture = texture
	add_child(body)

	var line := Line2D.new()
	line.points = _outline
	line.closed = true
	line.width = OUTLINE_WIDTH
	line.default_color = Color(outline_color, 0.8)
	line.antialiased = true
	add_child(line)


func contains_point(world_point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(world_point), _outline)


func set_held(held: bool) -> void:
	_shadow.visible = held
