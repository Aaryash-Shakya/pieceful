class_name SetupScreen
extends Control
## Pick a picture, a style and a piece count, with the real cut previewed over the picture. Built
## in code like the HUD so every control takes its look from UiTheme.

const SCENE := "res://src/ui/setup_screen.tscn"
const BOARD_SCENE := "res://src/game/board.tscn"
const MIN_COUNT := 12
const MAX_COUNT := 400
const DEFAULT_COUNT := 54
const PREVIEW_DELAY := 0.15
const STYLES: Array[String] = [CutGenerator.STYLE_REGULAR, CutGenerator.STYLE_IRREGULAR]
const STYLE_NAMES := {"regular": "Regular", "irregular": "Irregular"}
const TITLE_TEXT := "Pieceful"
const START_TEXT := "Start"
const RESUME_TEXT := "Resume"
const EMPTY_TEXT := "No pictures found"
const MARGIN := 16
# Clears the Android status bar, as the HUD does.
const MARGIN_TOP := 56
const ROW_GAP := 12
const TILE_SIZE := Vector2(112, 84)
const STYLE_TILE_HEIGHT := 56
const START_HEIGHT := 64
const PREVIEW_MAX_HEIGHT := 420.0
const RESUME_THUMB_SIZE := Vector2(72, 54)
# A finger target: the slider takes a press anywhere in its rect, and the theme keeps the track 10 px.
const SLIDER_HEIGHT := 44
# How far a finger may travel and still tap. Further, it is a scroll, and the tile under it is not chosen.
const TAP_SLOP := 8.0

var save_path := SaveFile.DEFAULT_PATH
var collection: Collection = null
var quit_app: Callable

var pictures: Array[Collection.Picture] = []
var picture: Collection.Picture
var chosen_texture: Texture2D
var style := CutGenerator.STYLE_REGULAR
var counts: PackedInt32Array
var count := 0
var cut_seed := 0
var saved: SaveGame.Snapshot = null
var generations := 0

var preview: CutPreview
var preview_timer: Timer
var picture_buttons: Array[Button] = []
var style_buttons: Array[Button] = []
var slider: HSlider
var count_label: Label
var split_label: Label
var picture_label: Label
var empty_label: Label
var start_button: Button
var resume_card: PanelContainer
var resume_button: Button
var resume_label: Label
var resume_thumb: TextureRect

var _dragging := false
var _press_at := Vector2.ZERO
# Set on a release that travelled past TAP_SLOP, read by the pressed handler that follows it.
var _swiped := false
# Set by the first launch: a double tap or Start then Resume must not open two boards.
var _launched := false
var _picture_group := ButtonGroup.new()
var _style_group := ButtonGroup.new()
var _rows: VBoxContainer
var _strip: HBoxContainer
# Hidden together when the collection has no usable picture.
var _choice_rows: Array[Control] = []


static func fresh_seed(unix_ms: int, ticks_usec: int) -> int:
	return SeededRng.hash2(unix_ms, ticks_usec)


static func nearest_count(options: PackedInt32Array, target: int) -> int:
	var best := options[0]
	for option in options:
		if absi(option - target) < absi(best - target):
			best = option
	return best


## The save at path when it can be resumed with a picture of source at its saved size and a
## player-facing style, else null. Prints nothing, so the caller decides what to say.
static func resumable(path: String, source: Collection) -> SaveGame.Snapshot:
	if source == null:
		return null
	var file := SaveFile.read(path)
	if file.error != OK:
		return null
	var snapshot := SaveGame.from_json(file.text).snapshot
	if snapshot == null or not STYLES.has(snapshot.puzzle.style):
		return null
	var found := source.find(snapshot.puzzle.image_id)
	if found == null or found.size() != snapshot.puzzle.image_size:
		return null
	return snapshot


static func open(tree: SceneTree, path: String, source: Collection) -> SetupScreen:
	var screen := (load(SCENE) as PackedScene).instantiate() as SetupScreen
	screen.save_path = path
	screen.collection = source
	tree.change_scene_to_node(screen)
	return screen


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.page_background())
	theme = UiTheme.build()
	if collection == null:
		collection = Collection.load_manifest(Collection.DEFAULT_MANIFEST)
	if not quit_app.is_valid():
		quit_app = get_tree().quit
	cut_seed = fresh_seed(int(Time.get_unix_time_from_system() * 1000.0), Time.get_ticks_usec())

	preview_timer = Timer.new()
	preview_timer.one_shot = true
	preview_timer.wait_time = PREVIEW_DELAY
	preview_timer.timeout.connect(regenerate_preview)
	add_child(preview_timer)

	saved = resumable(save_path, collection)
	# Kept beside the save rather than deleted; it also clears an old test-picture save on first launch.
	if saved == null and FileAccess.file_exists(save_path):
		SaveFile.move_aside(save_path)
		push_warning("SetupScreen: could not resume the save at %s; moved it to %s" % [save_path, SaveFile.bad_path(save_path)])

	_build_ui()
	start_button.pressed.connect(start)
	resume_button.pressed.connect(_on_resume_pressed)

	if saved != null:
		var puzzle := saved.puzzle
		var saved_picture := collection.find(puzzle.image_id)
		resume_thumb.texture = collection.load_thumbnail(saved_picture)
		resume_label.text = "%s · %d pieces · %s" % [saved_picture.title, puzzle.piece_count, STYLE_NAMES[puzzle.style]]
		resume_card.visible = true
		style = puzzle.style
		count = puzzle.piece_count
		select_style(style)
		select_picture(maxi(0, pictures.find(collection.find(puzzle.image_id))))
	else:
		style = CutGenerator.STYLE_REGULAR
		count = DEFAULT_COUNT
		select_style(style)
		select_picture(0)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if quit_app.is_valid():
				quit_app.call()
		# A slider that is hidden or leaves the tree can lose its grab without drag_ended, which
		# would leave later track taps never scheduling a preview.
		NOTIFICATION_VISIBILITY_CHANGED:
			if _dragging and not is_visible_in_tree():
				_dragging = false
				_schedule_preview()
		NOTIFICATION_EXIT_TREE:
			_dragging = false


## A new game from the current choices and the previewed seed. It replaces any save.
func start() -> Board:
	if _launched or picture == null:
		return null
	var puzzle := SaveGame.Puzzle.new()
	puzzle.image_id = picture.id
	puzzle.image_size = picture.size()
	puzzle.style = style
	puzzle.piece_count = count
	puzzle.cut_seed = cut_seed
	return _launch(puzzle, false)


## Continues the save. The board checks it again; if it fails there, the saved picture starts fresh.
func resume() -> Board:
	if _launched or saved == null:
		return null
	var puzzle := SaveGame.Puzzle.new()
	puzzle.image_id = saved.puzzle.image_id
	puzzle.image_size = saved.puzzle.image_size
	puzzle.style = saved.puzzle.style
	puzzle.piece_count = saved.puzzle.piece_count
	puzzle.cut_seed = cut_seed
	return _launch(puzzle, true)


# The swap frees this screen, its timer and its textures. The board is freed in turn when it goes
# home, so its one-way home flag never needs resetting.
func _launch(puzzle: SaveGame.Puzzle, resume_save: bool) -> Board:
	_launched = true
	start_button.disabled = true
	resume_button.disabled = true
	preview_timer.stop()
	var board := (load(BOARD_SCENE) as PackedScene).instantiate() as Board
	board.save_path = save_path
	board.collection = collection
	board.start_puzzle = puzzle
	board.resume = resume_save
	var tree := get_tree()
	var path := save_path
	var source := collection
	# Handed on so a test's quit seam survives the round trip through the board.
	var quit := quit_app
	board.home_requested.connect(func() -> void: SetupScreen.open(tree, path, source).quit_app = quit)
	tree.change_scene_to_node(board)
	return board


func select_picture(index: int) -> void:
	if pictures.is_empty():
		_show_empty()
		return
	var candidate := pictures[index]
	var texture := collection.load_texture(candidate)
	if texture == null:
		pictures.remove_at(index)
		var button: Button = picture_buttons.pop_at(index)
		_strip.remove_child(button)
		button.queue_free()
		if pictures.is_empty():
			_show_empty()
		elif picture != null:
			# A tapped tile that fails leaves the player where they were.
			picture_buttons[pictures.find(picture)].button_pressed = true
		else:
			select_picture(mini(index, pictures.size() - 1))
		return

	picture = candidate
	chosen_texture = texture
	counts = CutGenerator.valid_counts(picture.width, picture.height, MIN_COUNT, MAX_COUNT)
	var target := nearest_count(counts, count)
	slider.min_value = 0
	slider.max_value = counts.size() - 1
	slider.set_value_no_signal(counts.find(target))
	count = target
	_update_count_labels()
	picture_label.text = picture.title
	preview.show_picture(chosen_texture, picture.size())
	_size_preview()
	picture_buttons[index].button_pressed = true
	_schedule_preview()


func select_style(value: String) -> void:
	style = value
	style_buttons[STYLES.find(value)].button_pressed = true
	_schedule_preview()


func regenerate_preview() -> void:
	if picture == null:
		return
	preview.show_cut(CutGenerator.generate_cut(picture.width, picture.height, count, style, cut_seed))
	generations += 1


func _schedule_preview() -> void:
	if picture != null:
		preview_timer.start()


func _show_empty() -> void:
	picture = null
	chosen_texture = null
	preview_timer.stop()
	for row in _choice_rows:
		row.visible = false
	empty_label.visible = true
	start_button.disabled = true


func _update_count_labels() -> void:
	count_label.text = "%d pieces" % count
	var split := CutGenerator.grid_split(picture.width, picture.height, count)
	split_label.text = "%d x %d grid" % [split.x, split.y]


func _on_slider_value_changed(value: float) -> void:
	if picture == null:
		return
	count = counts[int(value)]
	_update_count_labels()
	if not _dragging:
		_schedule_preview()


func _on_slider_drag_started() -> void:
	_dragging = true
	preview_timer.stop()


func _on_slider_drag_ended(_value_changed: bool) -> void:
	_dragging = false
	_schedule_preview()


func _on_picture_pressed(button: Button) -> void:
	if _take_swipe():
		if picture != null:
			picture_buttons[pictures.find(picture)].button_pressed = true
		return
	select_picture(picture_buttons.find(button))


func _on_style_pressed(value: String) -> void:
	if _take_swipe():
		style_buttons[STYLES.find(style)].button_pressed = true
		return
	select_style(value)


func _on_resume_pressed() -> void:
	if not _take_swipe():
		resume()


# Read once, so a press that arrives without pointer input (a test, accessibility) is never
# mistaken for the last swipe.
func _take_swipe() -> bool:
	var swiped := _swiped
	_swiped = false
	return swiped


# A button in a scroller still fires when the finger lifts over it after scrolling. The gui_input
# signal runs before the button's own handling, so the release is judged here and the pressed
# handler that follows undoes the toggle. The furthest point counts, so a swipe that comes back is
# still a swipe.
func _on_scrolled_button_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button_event := event as InputEventMouseButton
		if button_event.pressed:
			_press_at = button_event.global_position
			_swiped = false
		else:
			_note_travel(button_event.global_position)
	elif event is InputEventMouseMotion:
		_note_travel((event as InputEventMouseMotion).global_position)


func _note_travel(at: Vector2) -> void:
	if at.distance_to(_press_at) > TAP_SLOP:
		_swiped = true


# Fitted to the width and capped in height, so a tall picture does not push the choices away.
func _size_preview() -> void:
	if picture == null or preview.size.x <= 0.0:
		return
	var height := minf(preview.size.x * picture.height / picture.width, PREVIEW_MAX_HEIGHT)
	preview.custom_minimum_size = Vector2(0, height)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	page.offset_left = MARGIN
	page.offset_right = -MARGIN
	page.offset_top = MARGIN_TOP
	page.offset_bottom = -MARGIN
	page.add_theme_constant_override("separation", ROW_GAP)
	add_child(page)

	var title := Label.new()
	title.text = TITLE_TEXT
	title.theme_type_variation = UiTheme.TITLE
	page.add_child(title)

	var scroller := ScrollContainer.new()
	scroller.size_flags_vertical = SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroller.scroll_deadzone = int(TAP_SLOP)
	page.add_child(scroller)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", ROW_GAP)
	scroller.add_child(_rows)

	_build_resume_card()

	preview = CutPreview.new()
	preview.size_flags_horizontal = SIZE_EXPAND_FILL
	# It fills most of the scroller, so drags on it must reach the scroller.
	preview.mouse_filter = MOUSE_FILTER_PASS
	preview.resized.connect(_size_preview)
	_rows.add_child(preview)

	empty_label = Label.new()
	empty_label.text = EMPTY_TEXT
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.visible = false
	_rows.add_child(empty_label)

	picture_label = Label.new()
	_rows.add_child(picture_label)

	var strip_scroller := ScrollContainer.new()
	strip_scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	strip_scroller.scroll_deadzone = int(TAP_SLOP)
	_rows.add_child(strip_scroller)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", ROW_GAP)
	strip_scroller.add_child(_strip)
	for candidate in collection.pictures:
		var thumbnail := collection.load_thumbnail(candidate)
		if thumbnail == null:
			continue
		pictures.append(candidate)
		var button := _make_option(_picture_group)
		button.icon = thumbnail
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size = TILE_SIZE
		button.tooltip_text = candidate.title
		button.pressed.connect(_on_picture_pressed.bind(button))
		_strip.add_child(button)
		picture_buttons.append(button)

	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", ROW_GAP)
	_rows.add_child(style_row)
	for value in STYLES:
		var button := _make_option(_style_group)
		button.text = STYLE_NAMES[value]
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, STYLE_TILE_HEIGHT)
		button.pressed.connect(_on_style_pressed.bind(value))
		style_row.add_child(button)
		style_buttons.append(button)

	count_label = Label.new()
	count_label.theme_type_variation = UiTheme.TITLE
	_rows.add_child(count_label)
	split_label = Label.new()
	split_label.add_theme_color_override("font_color", Palette.muted_text())
	_rows.add_child(split_label)

	slider = HSlider.new()
	slider.min_value = 0
	slider.step = 1
	slider.focus_mode = FOCUS_NONE
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, SLIDER_HEIGHT)
	slider.value_changed.connect(_on_slider_value_changed)
	slider.drag_started.connect(_on_slider_drag_started)
	slider.drag_ended.connect(_on_slider_drag_ended)
	_rows.add_child(slider)

	_choice_rows = [preview, picture_label, strip_scroller, style_row, count_label, split_label, slider]

	start_button = Button.new()
	start_button.text = START_TEXT
	start_button.focus_mode = FOCUS_NONE
	start_button.custom_minimum_size = Vector2(0, START_HEIGHT)
	page.add_child(start_button)


# _ready fills and shows it when a resumable save exists.
func _build_resume_card() -> void:
	resume_card = PanelContainer.new()
	resume_card.visible = false
	resume_card.mouse_filter = MOUSE_FILTER_PASS
	_rows.add_child(resume_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	resume_card.add_child(row)
	resume_thumb = TextureRect.new()
	resume_thumb.name = "Thumbnail"
	resume_thumb.custom_minimum_size = RESUME_THUMB_SIZE
	resume_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	resume_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(resume_thumb)
	resume_label = Label.new()
	resume_label.size_flags_horizontal = SIZE_EXPAND_FILL
	resume_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resume_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(resume_label)
	resume_button = Button.new()
	resume_button.text = RESUME_TEXT
	resume_button.focus_mode = FOCUS_NONE
	resume_button.size_flags_vertical = SIZE_SHRINK_CENTER
	_pass_to_scroller(resume_button)
	row.add_child(resume_button)


func _make_option(group: ButtonGroup) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.theme_type_variation = UiTheme.OPTION
	button.focus_mode = FOCUS_NONE
	_pass_to_scroller(button)
	return button


# Every option tile sits in a scroller, which drag-scrolls only from events its children pass on.
func _pass_to_scroller(button: Button) -> void:
	button.mouse_filter = MOUSE_FILTER_PASS
	button.gui_input.connect(_on_scrolled_button_input)
