class_name SetupScreen
extends Control
## Pick a picture, a style and a piece count, with the real cut previewed over the picture. Built
## in code like the HUD so every control takes its look from UiTheme.

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

var _dragging := false
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

	_build_ui()

	if saved != null:
		var puzzle := saved.puzzle
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
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and quit_app.is_valid():
		quit_app.call()


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
	select_picture(picture_buttons.find(button))


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
	page.add_child(scroller)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", ROW_GAP)
	scroller.add_child(_rows)

	_build_resume_card()

	preview = CutPreview.new()
	preview.size_flags_horizontal = SIZE_EXPAND_FILL
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
		button.pressed.connect(select_style.bind(value))
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


# Task 6 fills and shows it when a resumable save exists.
func _build_resume_card() -> void:
	resume_card = PanelContainer.new()
	resume_card.visible = false
	_rows.add_child(resume_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	resume_card.add_child(row)
	var thumb := TextureRect.new()
	thumb.name = "Thumbnail"
	thumb.custom_minimum_size = RESUME_THUMB_SIZE
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(thumb)
	resume_label = Label.new()
	resume_label.size_flags_horizontal = SIZE_EXPAND_FILL
	resume_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resume_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(resume_label)
	resume_button = Button.new()
	resume_button.text = RESUME_TEXT
	resume_button.focus_mode = FOCUS_NONE
	resume_button.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(resume_button)


func _make_option(group: ButtonGroup) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.theme_type_variation = UiTheme.OPTION
	button.focus_mode = FOCUS_NONE
	return button
