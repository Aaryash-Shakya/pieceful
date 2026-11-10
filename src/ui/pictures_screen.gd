class_name PicturesScreen
extends Control
## The Pictures tab: pick a picture from a collection, then Cut opens setup on it.

const TITLE_TEXT := "Pictures"
const MORE_TEXT := "More pictures"
const MORE_NOTE_TEXT := "Coming soon"
const EMPTY_TEXT := "No pictures found"
const SIDE_MARGIN := 24
const TOP_MARGIN := 24
const GAP := 18
const GRID_GAP := 12
const COLUMNS := 2
const TILE_HEIGHT := 190
const STRIP_HEIGHT := 34
const TAB_HEIGHT := 66
const BUTTON_HEIGHT := 76

var save_path := SaveFile.DEFAULT_PATH
var collection: Collection = null
var quit_app: Callable

## What the tabs offer: the parts of a merged collection, or the collection itself.
var sections: Array[Collection] = []
var section_index := 0
var pictures: Array[Collection.Picture] = []
var picture: Collection.Picture

var background: ColorRect
var more_button: Button
var more_note: Label
var tab_buttons: Array[Button] = []
var tiles: Array[Button] = []
var empty_label: Label
var cut_button: Button
## Keeps the last row clear of the Cut button and the floating nav; sized once the host has built it.
var bottom_pad: Control

var _taps := TapGuard.new()
var _tab_group := ButtonGroup.new()
var _tile_group := ButtonGroup.new()
var _tab_scroller: ScrollContainer
var _grid: GridContainer
var _setup: SetupScreen = null
var _leaving := false


## The tab host for this screen, not yet presented, so a route can hand it to the shell.
static func make_host(path: String, source: Collection, quit: Callable) -> TabHost:
	var screen := PicturesScreen.new()
	screen.save_path = path
	screen.collection = source
	screen.quit_app = quit
	return TabHost.make(&"pictures", screen, {
		&"home": func() -> Node: return HomeScreen.make_host(path, source, quit),
		&"settings": SettingsScreen.route(path, source, quit),
	})


static func open(tree: SceneTree, path: String, source: Collection, quit: Callable) -> PicturesScreen:
	var host := make_host(path, source, quit)
	AppShell.present(tree, host)
	return host.body as PicturesScreen


func _ready() -> void:
	if collection == null:
		collection = CollectionLibrary.load_bundled()
	if not quit_app.is_valid():
		quit_app = get_tree().quit
	if collection.parts.is_empty():
		sections.append(collection)
	else:
		sections = collection.parts
	_build_ui()
	_show_section(0)
	select_picture(0)
	# The host builds its nav after this body is ready, so the clearance is read when it is done.
	var host := get_parent() as TabHost
	if host != null:
		host.ready.connect(_place_below_nav.bind(host))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _leaving:
		_leaving = true
		HomeScreen.open(get_tree(), save_path, collection, quit_app)


## Shows another collection and chooses its first picture.
func select_collection(index: int) -> void:
	if index == section_index:
		return
	_show_section(index)
	select_picture(0)


## Chooses a tile of the shown collection; out of range clears the choice.
func select_picture(index: int) -> void:
	if index < 0 or index >= pictures.size():
		picture = null
	else:
		picture = pictures[index]
		tiles[index].button_pressed = true
	var any := picture != null
	cut_button.disabled = not any
	cut_button.text = "Cut %s" % picture.title if any else "Cut"
	empty_label.visible = pictures.is_empty()


## Opens setup on the chosen picture, over this screen so back returns here. Null when there is no
## picture, or setup is already opening or open.
func cut() -> SetupScreen:
	if picture == null or (is_instance_valid(_setup) and not _setup.is_queued_for_deletion()):
		return null
	var screen := (load(SetupScreen.SCENE) as PackedScene).instantiate() as SetupScreen
	screen.save_path = save_path
	screen.collection = collection
	screen.quit_app = quit_app
	screen.start_picture_id = picture.id
	_setup = screen
	var shell := AppShell.find(get_tree())
	if shell != null:
		shell.push(screen)
	else:
		AppShell.present(get_tree(), screen)
	return screen


func _place_below_nav(host: TabHost) -> void:
	var clearance := host.nav_clearance()
	cut_button.offset_bottom = -(clearance + GAP)
	cut_button.offset_top = cut_button.offset_bottom - BUTTON_HEIGHT
	bottom_pad.custom_minimum_size.y = clearance + GAP + BUTTON_HEIGHT + GAP


# Fills the grid with the section's pictures that load. Choosing one is left to the caller.
func _show_section(index: int) -> void:
	section_index = index
	tab_buttons[index].button_pressed = true
	picture = null
	pictures.clear()
	tiles.clear()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for candidate in sections[index].pictures:
		var thumbnail := collection.load_thumbnail(candidate)
		if thumbnail == null:
			continue
		pictures.append(candidate)
		_grid.add_child(_make_cell(candidate, thumbnail))


# A wooden frame holding the picture over a chocolate name strip. The chosen one wears a yellow ring.
func _make_cell(candidate: Collection.Picture, thumbnail: Texture2D) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = SIZE_EXPAND_FILL
	var tile := Button.new()
	tile.toggle_mode = true
	tile.button_group = _tile_group
	tile.theme_type_variation = Workshop.PICTURE_TILE
	tile.focus_mode = FOCUS_NONE
	tile.custom_minimum_size = Vector2(0, TILE_HEIGHT + STRIP_HEIGHT)
	tile.tooltip_text = candidate.title
	# In a scroller, the button must pass its events on so a drag can scroll.
	tile.mouse_filter = MOUSE_FILTER_PASS
	tile.gui_input.connect(_taps.watch)
	tile.pressed.connect(_on_tile_pressed.bind(tile))
	cell.add_child(tile)
	tiles.append(tile)
	var inside := VBoxContainer.new()
	# Inset by the frame's padding by hand: a Button does not lay out its children.
	inside.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, Workshop.FRAME_PADDING)
	inside.add_theme_constant_override("separation", 0)
	inside.mouse_filter = MOUSE_FILTER_IGNORE
	tile.add_child(inside)
	var picture_rect := TextureRect.new()
	picture_rect.texture = thumbnail
	picture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture_rect.size_flags_vertical = SIZE_EXPAND_FILL
	picture_rect.clip_contents = true
	picture_rect.mouse_filter = MOUSE_FILTER_IGNORE
	inside.add_child(picture_rect)
	var label := Label.new()
	label.text = candidate.title
	label.theme_type_variation = Workshop.STRIP
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = MOUSE_FILTER_IGNORE
	inside.add_child(label)
	return cell


func _on_tile_pressed(tile: Button) -> void:
	if _taps.take_swipe():
		# The press toggled it already; put the choice back.
		if picture != null:
			tiles[pictures.find(picture)].button_pressed = true
		return
	select_picture(tiles.find(tile))


func _on_tab_pressed(index: int) -> void:
	if _taps.take_swipe():
		tab_buttons[section_index].button_pressed = true
		return
	select_collection(index)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	# The board leaves the clear colour on felt, so this screen paints its own ground.
	background = ColorRect.new()
	background.color = Palette.page_background()
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	add_child(Workshop.backdrop(true))
	var scroller := ScrollContainer.new()
	scroller.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroller.scroll_deadzone = int(TapGuard.SLOP)
	add_child(scroller)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", TOP_MARGIN + int(SafeArea.current(get_tree()).y))
	scroller.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", GAP)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = TITLE_TEXT
	title.theme_type_variation = Workshop.INK_TITLE
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	# Collections to download arrive with the Store; until then the pill only says so.
	var more := VBoxContainer.new()
	header.add_child(more)
	more_button = Button.new()
	more_button.text = MORE_TEXT
	more_button.disabled = true
	more_button.focus_mode = FOCUS_NONE
	more_button.theme_type_variation = Workshop.CHIP
	more.add_child(more_button)
	more_note = Label.new()
	more_note.text = MORE_NOTE_TEXT
	more_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	more_note.theme_type_variation = Workshop.INK_LABEL
	more.add_child(more_note)

	_tab_scroller = ScrollContainer.new()
	_tab_scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_tab_scroller.scroll_deadzone = int(TapGuard.SLOP)
	content.add_child(_tab_scroller)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", GRID_GAP)
	_tab_scroller.add_child(tabs)
	for i in sections.size():
		var tab := Button.new()
		tab.text = sections[i].title
		tab.toggle_mode = true
		tab.button_group = _tab_group
		tab.theme_type_variation = Workshop.CHIP
		tab.focus_mode = FOCUS_NONE
		tab.custom_minimum_size = Vector2(0, TAB_HEIGHT)
		tab.mouse_filter = MOUSE_FILTER_PASS
		tab.gui_input.connect(_taps.watch)
		tab.pressed.connect(_on_tab_pressed.bind(i))
		tabs.add_child(tab)
		tab_buttons.append(tab)
	# One collection needs no choosing.
	_tab_scroller.visible = sections.size() > 1

	empty_label = Label.new()
	empty_label.text = EMPTY_TEXT
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.theme_type_variation = Workshop.INK_LABEL
	empty_label.visible = false
	content.add_child(empty_label)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_grid.add_theme_constant_override("v_separation", GRID_GAP)
	content.add_child(_grid)

	bottom_pad = Control.new()
	bottom_pad.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(bottom_pad)

	# Fixed above the nav, so Cut is always in reach however long the grid is.
	cut_button = Button.new()
	cut_button.focus_mode = FOCUS_NONE
	cut_button.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	cut_button.offset_left = SIDE_MARGIN
	cut_button.offset_right = -SIDE_MARGIN
	cut_button.pressed.connect(cut)
	add_child(cut_button)
