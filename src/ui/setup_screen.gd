class_name SetupScreen
extends Control
## Pick a picture, a style and a piece count, with the real cut previewed over the picture. Built
## in code like the HUD so every control takes its look from UiTheme.

const SCENE := "res://src/ui/setup_screen.tscn"
const DEFAULT_COUNT := 54
# The slider offers about this many counts, not every valid split.
const SLIDER_STEPS := 20
const PREVIEW_DELAY := 0.15
# The least time between preview redraws while the slider is being dragged.
const DRAG_PREVIEW_INTERVAL := 0.12
const STYLES: Array[String] = [CutGenerator.STYLE_REGULAR, CutGenerator.STYLE_IRREGULAR]
const STYLE_NAMES := {"regular": "Regular", "irregular": "Irregular"}
const TITLE_TEXT := "Pieceful"
const START_TEXT := "Start"
const SETTINGS_TEXT := "Settings"
const RESUME_TEXT := "Resume"
const EMPTY_TEXT := "No pictures found"
const MARGIN := 16
# Clears the Android status bar, as the HUD does.
const MARGIN_TOP := 56
const ROW_GAP := 12
const TILE_SIZE := Vector2(112, 84)
const STYLE_TILE_HEIGHT := 56
const CHIP_HEIGHT := 44
const START_HEIGHT := 64
const PREVIEW_MAX_HEIGHT := 420.0
const RESUME_THUMB_SIZE := Vector2(72, 54)
# A finger target: the slider takes a press anywhere in its rect, and the theme keeps the track 10 px.
const SLIDER_HEIGHT := 44
const TAP_SLOP := TapGuard.SLOP

var save_path := SaveFile.DEFAULT_PATH
var collection: Collection = null
var quit_app: Callable
## Picture to start on when there is no save to resume; an id the collection lacks means the first.
var start_picture_id := ""

## What the picker offers: the parts of a merged collection, or the collection itself.
var sections: Array[Collection] = []
var section_index := 0
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
var collection_buttons: Array[Button] = []
var style_buttons: Array[Button] = []
var slider: HSlider
var count_label: Label
var split_label: Label
var picture_label: Label
var empty_label: Label
var start_button: Button
var settings_button: Button
## Sound and vibration switches; hidden until the Settings button is pressed.
var settings_sheet: SettingsSheet
var resume_card: PanelContainer
var resume_button: Button
var resume_label: Label
var resume_thumb: TextureRect

var _dragging := false
var _last_preview_ms := -1000000
var _taps := TapGuard.new()
# Set by the first launch: a double tap or Start then Resume must not open two boards.
var _launched := false
var _picture_group := ButtonGroup.new()
var _collection_group := ButtonGroup.new()
var _style_group := ButtonGroup.new()
var _rows: VBoxContainer
var _strip: HBoxContainer
var _collection_scroller: ScrollContainer
# Hidden together when the collection has no usable picture.
var _choice_rows: Array[Control] = []


static func fresh_seed(unix_ms: int, ticks_usec: int) -> int:
	return SeededRng.hash2(unix_ms, ticks_usec)


## About `steps` of the valid counts, evenly spaced on a log scale from the smallest to the largest,
## so each slider step is a similar jump in difficulty. Every returned count is a valid split.
static func step_counts(options: PackedInt32Array, steps: int) -> PackedInt32Array:
	if options.size() <= steps or steps < 2:
		return options
	var first := float(options[0])
	var last := float(options[options.size() - 1])
	var result := PackedInt32Array()
	for k in steps:
		var target := roundi(first * pow(last / first, float(k) / (steps - 1)))
		var pick := nearest_count(options, target)
		if result.is_empty() or result[result.size() - 1] != pick:
			result.append(pick)
	return result


static func nearest_count(options: PackedInt32Array, target: int) -> int:
	# The collection only lists pictures with a valid count, so this is a guard, not a path.
	if options.is_empty():
		push_warning("SetupScreen: no valid piece count; keeping %d" % target)
		return target
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
	AppShell.present(tree, screen)
	return screen


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.page_background())
	theme = UiTheme.build()
	if collection == null:
		collection = CollectionLibrary.load_bundled()
	if not quit_app.is_valid():
		quit_app = get_tree().quit
	cut_seed = fresh_seed(int(Time.get_unix_time_from_system() * 1000.0), Time.get_ticks_usec())

	preview_timer = Timer.new()
	preview_timer.one_shot = true
	preview_timer.wait_time = PREVIEW_DELAY
	preview_timer.timeout.connect(regenerate_preview)
	add_child(preview_timer)

	saved = resumable(save_path, collection)
	if saved == null and FileAccess.file_exists(save_path):
		# With no pictures at all the save cannot be judged, so it waits for a launch that has them.
		if collection.pictures.is_empty():
			_keep_save("no pictures are available")
		else:
			_set_save_aside()

	if collection.parts.is_empty():
		sections.append(collection)
	else:
		sections = collection.parts
	_build_ui()
	start_button.pressed.connect(start)
	resume_button.pressed.connect(_on_resume_pressed)

	if saved != null:
		var puzzle := saved.puzzle
		style = puzzle.style
		count = puzzle.piece_count
		select_style(style)
		_show_section(_section_of(puzzle.image_id))
		select_picture(maxi(0, pictures.find(collection.find(puzzle.image_id))))
		# Selecting loads the picture, the last check: one that cannot load would make Resume start
		# the board's stand-in puzzle instead.
		if picture != null and picture.id == puzzle.image_id:
			resume_thumb.texture = picture_buttons[pictures.find(picture)].icon
			resume_label.text = "%s · %d pieces · %s" % [picture.title, puzzle.piece_count, STYLE_NAMES[puzzle.style]]
			resume_card.visible = true
		else:
			# The save itself is fine; only this run's picture failed.
			saved = null
			_keep_save("picture %s did not load" % puzzle.image_id)
	else:
		style = CutGenerator.STYLE_REGULAR
		count = DEFAULT_COUNT
		select_style(style)
		var chosen := collection.find(start_picture_id) if start_picture_id != "" else null
		_show_section(_section_of(start_picture_id) if chosen != null else 0)
		select_picture(maxi(0, pictures.find(chosen)) if chosen != null else 0)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			var shell := AppShell.find(get_tree())
			if shell != null and shell.depth() > 1:
				shell.pop()
			elif quit_app.is_valid():
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
	var puzzle := saved.puzzle.copy()
	puzzle.cut_seed = cut_seed
	return _launch(puzzle, true)


func _keep_save(reason: String) -> void:
	push_warning("SetupScreen: could not resume the save at %s: %s; left it in place" % [save_path, reason])


# Only for a save that is unusable in itself: unreadable, malformed, or naming a picture the loaded
# collection does not have at that size. Kept beside the save rather than deleted; it also clears an
# old test-picture save on first launch.
func _set_save_aside() -> void:
	SaveFile.move_aside(save_path)
	push_warning("SetupScreen: could not resume the save at %s; moved it to %s" % [save_path, SaveFile.bad_path(save_path)])


# The swap frees this screen, its timer and its textures. The board is freed in turn when it goes
# home, so its one-way home flag never needs resetting.
func _launch(puzzle: SaveGame.Puzzle, resume_save: bool) -> Board:
	_launched = true
	start_button.disabled = true
	resume_button.disabled = true
	preview_timer.stop()
	return BoardLaunch.launch(get_tree(), save_path, collection, puzzle, resume_save, quit_app)


## Shows another collection and chooses its first picture. The count stays the nearest valid one.
func select_collection(index: int) -> void:
	if index == section_index:
		return
	_show_section(index)
	select_picture(0)
	if not pictures.is_empty() and not _launched:
		# The empty state of a collection whose pictures all failed to load ends here.
		for row in _choice_rows:
			row.visible = true
		empty_label.visible = false
		start_button.disabled = false


# Fills the strip with the section's pictures that have a thumbnail. Choosing one is left to the caller.
func _show_section(index: int) -> void:
	section_index = index
	collection_buttons[index].button_pressed = true
	picture = null
	pictures.clear()
	picture_buttons.clear()
	for child in _strip.get_children():
		_strip.remove_child(child)
		child.queue_free()
	for candidate in sections[index].pictures:
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


func _section_of(image_id: String) -> int:
	for i in sections.size():
		if sections[i].find(image_id) != null:
			return i
	return 0


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
	counts = step_counts(CutGenerator.valid_counts(picture.width, picture.height, Collection.MIN_COUNT, Collection.MAX_COUNT), SLIDER_STEPS)
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
	_last_preview_ms = Time.get_ticks_msec()


func _schedule_preview() -> void:
	if picture != null:
		preview_timer.start(PREVIEW_DELAY)


# While the slider moves the preview follows each step, but never faster than DRAG_PREVIEW_INTERVAL,
# since a big cut costs real time on a phone. A step skipped by the limit is drawn by the trailing
# timer, so the last step of a drag always shows.
func _preview_while_dragging() -> void:
	if picture == null:
		return
	var wait := DRAG_PREVIEW_INTERVAL - (Time.get_ticks_msec() - _last_preview_ms) / 1000.0
	if wait <= 0.0:
		preview_timer.stop()
		regenerate_preview()
	else:
		preview_timer.start(wait)


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
	if _dragging:
		_preview_while_dragging()
	else:
		_schedule_preview()


func _on_slider_drag_started() -> void:
	_dragging = true


func _on_slider_drag_ended(_value_changed: bool) -> void:
	_dragging = false
	_schedule_preview()


func _on_picture_pressed(button: Button) -> void:
	if _taps.take_swipe():
		if picture != null:
			picture_buttons[pictures.find(picture)].button_pressed = true
		return
	select_picture(picture_buttons.find(button))


func _on_collection_pressed(index: int) -> void:
	if _taps.take_swipe():
		collection_buttons[section_index].button_pressed = true
		return
	select_collection(index)


func _on_style_pressed(value: String) -> void:
	if _taps.take_swipe():
		style_buttons[STYLES.find(style)].button_pressed = true
		return
	select_style(value)


func _on_resume_pressed() -> void:
	if not _taps.take_swipe():
		resume()


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

	var title_row := HBoxContainer.new()
	page.add_child(title_row)
	var title := Label.new()
	title.text = TITLE_TEXT
	title.theme_type_variation = UiTheme.TITLE
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title_row.add_child(title)
	settings_button = Button.new()
	settings_button.text = SETTINGS_TEXT
	settings_button.focus_mode = FOCUS_NONE
	title_row.add_child(settings_button)

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
	settings_sheet = SettingsSheet.new()
	settings_sheet.visible = false
	_rows.add_child(settings_sheet)
	settings_button.pressed.connect(func() -> void: settings_sheet.visible = not settings_sheet.visible)

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

	_collection_scroller = _make_scroller()
	_rows.add_child(_collection_scroller)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", ROW_GAP)
	_collection_scroller.add_child(chips)
	for i in sections.size():
		var chip := _make_option(_collection_group)
		chip.text = sections[i].title
		chip.custom_minimum_size = Vector2(0, CHIP_HEIGHT)
		chip.pressed.connect(_on_collection_pressed.bind(i))
		chips.add_child(chip)
		collection_buttons.append(chip)
	# One collection needs no choosing.
	_collection_scroller.visible = sections.size() > 1

	var strip_scroller := _make_scroller()
	_rows.add_child(strip_scroller)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", ROW_GAP)
	strip_scroller.add_child(_strip)

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


func _make_scroller() -> ScrollContainer:
	var scroller := ScrollContainer.new()
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroller.scroll_deadzone = int(TAP_SLOP)
	return scroller


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
	button.gui_input.connect(_taps.watch)
