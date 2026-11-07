class_name BoardLaunch
extends RefCounted
## The one way a board is opened, so every screen that starts a puzzle hands it the same things and
## the board comes back to the same place.

const BOARD_SCENE := "res://src/game/board.tscn"


static func launch(tree: SceneTree, save_path: String, source: Collection, puzzle: SaveGame.Puzzle, resume_save: bool, quit: Callable) -> Board:
	var board := (load(BOARD_SCENE) as PackedScene).instantiate() as Board
	board.save_path = save_path
	board.collection = source
	board.start_puzzle = puzzle
	board.resume = resume_save
	# Static and bound to values, so it never reaches the launching screen, which is freed by then.
	board.home_requested.connect(BoardLaunch._return_home.bind(tree, save_path, source, quit))
	AppShell.present(tree, board)
	return board


# The quit seam is handed on so a test's seam survives the round trip.
static func _return_home(tree: SceneTree, path: String, source: Collection, quit: Callable) -> void:
	HomeScreen.open(tree, path, source, quit)
