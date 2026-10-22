class_name Board
extends Node2D
## The world: the board rectangle, the loose pieces around it and the camera.

const IMAGE_SIZE := Vector2i(1536, 1024)
const PIECE_COUNT := 400
const SEED := 1
const LOOSE_MARGIN := 768.0
const BORDER := 1.08
const BOARD_OUTLINE_WIDTH := 3.0

var camera: Camera2D
var pieces: Node2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.felt())

	var texture := _make_test_texture()
	var cut := CutGenerator.generate_cut(IMAGE_SIZE.x, IMAGE_SIZE.y, PIECE_COUNT, CutGenerator.STYLE_GRID, SEED)
	var offsets := Scatter.scatter(cut, Vector2(IMAGE_SIZE), LOOSE_MARGIN, SEED)

	pieces = Node2D.new()
	pieces.name = "Pieces"
	add_child(pieces)
	for i in cut.size():
		var node := PieceNode.new()
		node.setup(cut[i], texture, Palette.outline())
		node.position = offsets[i]
		pieces.add_child(node)

	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	camera.position = Vector2(IMAGE_SIZE) / 2.0
	var fit := get_viewport_rect().size.x / (IMAGE_SIZE.x * BORDER)
	camera.zoom = Vector2(fit, fit)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(IMAGE_SIZE))
	draw_rect(rect, Palette.board())
	draw_rect(rect, Palette.accent(), false, BOARD_OUTLINE_WIDTH)


func _make_test_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	gradient.colors = PackedColorArray([
		Color.RED, Color.YELLOW, Color.GREEN, Color.CYAN, Color.BLUE, Color.MAGENTA,
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = IMAGE_SIZE.x
	texture.height = IMAGE_SIZE.y
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 1)
	return texture
