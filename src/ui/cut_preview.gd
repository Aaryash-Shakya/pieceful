class_name CutPreview
extends Control
## The chosen picture fitted into this control with the cut's outlines drawn over it, a dark line
## under a light one so the cut reads on any picture.

const DARK_LINE := Color(0, 0, 0, 0.45)
const LIGHT_LINE := Color(1, 1, 1, 0.92)
const DARK_WIDTH := 3.0
const LIGHT_WIDTH := 1.6

var texture: Texture2D
var image_size := Vector2i.ZERO
var segments := PackedVector2Array()


func _init() -> void:
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func outline_segments(pieces: Array[CutPiece]) -> PackedVector2Array:
	var total := 0
	for piece in pieces:
		total += piece.outline.size()
	var out := PackedVector2Array()
	out.resize(2 * total)
	var i := 0
	for piece in pieces:
		var outline := piece.outline
		var n := outline.size()
		for k in n:
			out[i] = outline[k]
			out[i + 1] = outline[(k + 1) % n]
			i += 2
	return out


func show_picture(picture_texture: Texture2D, picture_size: Vector2i) -> void:
	texture = picture_texture
	image_size = picture_size
	segments = PackedVector2Array()
	queue_redraw()


func show_cut(pieces: Array[CutPiece]) -> void:
	segments = outline_segments(pieces)
	queue_redraw()


func fit_rect() -> Rect2:
	if image_size.x <= 0 or image_size.y <= 0:
		return Rect2()
	var scale_factor := minf(size.x / image_size.x, size.y / image_size.y)
	var fitted := Vector2(image_size) * scale_factor
	return Rect2((size - fitted) * 0.5, fitted)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var rect := fit_rect()
	draw_texture_rect(texture, rect, false)
	if segments.is_empty() or rect.size.x <= 0.0:
		return
	# Mapped into screen pixels rather than drawn under a scaled transform, so the line widths and
	# their antialiasing stay in screen pixels.
	var scale_factor := rect.size.x / image_size.x
	var mapped := Transform2D(0.0, Vector2(scale_factor, scale_factor), 0.0, rect.position) * segments
	draw_multiline(mapped, DARK_LINE, DARK_WIDTH, true)
	draw_multiline(mapped, LIGHT_LINE, LIGHT_WIDTH, true)
