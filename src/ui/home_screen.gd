class_name HomeScreen
extends Control
## The Home tab: the saved game to continue, or a first-launch welcome, with the way to Pictures.
## It only reads the save; setting one aside is left to the screens that start a game.

const CONTINUE_TEXT := "Continue"
const RESUME_TEXT := "Resume"
const RESUME_RIBBON := "Keep going"
const FIRST_RIBBON := "Welcome"
const FIRST_EYEBROW := "Free · no ads · works offline"
const FIRST_TITLE := "Let's make a puzzle"
const PICK_TEXT := "Pick a picture"
const NEW_TEXT := "New puzzle"
const DAILY_TEXT := "Daily puzzle\nComing soon"
const EMPTY_NOTE_TEXT := "Start a new one"
const TITLE_TEXT := "Pieceful"
const LOGO_SIZE := 72
const LOGO_OUTLINE := 8
const LOGO_COLOR := Color("#ffd21f")
const SIDE_MARGIN := 24
const GAP := 18
const HERO_HEIGHT := 300
const LOGO_TOP := 28
const CARD_TOP := 36
const BUTTON_HEIGHT := 76
const TILE_HEIGHT := 92
const BAR_HEIGHT := 24
const BAR_FONT_SIZE := 16
const HEADLINE_SIZE := 34
const EYEBROW_SIZE := 18

var save_path := SaveFile.DEFAULT_PATH
var collection: Collection = null
var quit_app: Callable
## Returns the Pictures screen. While it is empty the buttons that lead there stay disabled.
var open_pictures: Callable

var background: ColorRect
var hero: TextureRect
var card: PanelContainer
var eyebrow_label: Label
var title_label: Label
var progress_bar: ProgressBar
var continue_button: Button
var new_button: Button
var daily_tile: Button
var empty_note: Label
## Keeps the last row clear of the floating nav; sized once the host has built it.
var bottom_pad: Control

var _summary := {}
var _launched := false
var _content: VBoxContainer
var _opening := false


## Empty when the save cannot be resumed or its picture cannot be loaded. Prints nothing itself.
static func summary(path: String, source: Collection) -> Dictionary:
	var snapshot := SetupScreen.resumable(path, source)
	if snapshot == null:
		return {}
	var picture := source.find(snapshot.puzzle.image_id)
	var texture := source.load_texture(picture)
	if texture == null:
		return {}
	var locked := 0
	for cluster in snapshot.clusters:
		if cluster.locked:
			locked += cluster.pieces.size()
	var result := {
		"title": picture.title,
		"piece_count": snapshot.puzzle.piece_count,
		"placed": locked,
		"style_name": SetupScreen.STYLE_NAMES[snapshot.puzzle.style],
		"saved": snapshot,
		"texture": texture,
		"progress": float(locked) / snapshot.puzzle.piece_count,
	}
	if snapshot.elapsed > 0.0:
		result["played"] = format_played(snapshot.elapsed)
	return result


static func format_played(seconds: float) -> String:
	var total := int(seconds)
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var secs := total % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%d:%02d" % [minutes, secs]


## The tab host for Home, not yet presented, so a route can hand it to the shell.
static func make_host(path: String, source: Collection, quit: Callable) -> TabHost:
	var home := HomeScreen.new()
	home.save_path = path
	home.collection = source
	home.quit_app = quit
	# Built when called, so Home and Pictures can each open the other without a load-time cycle.
	var pictures := func() -> Node: return PicturesScreen.make_host(path, source, quit)
	home.open_pictures = pictures
	return TabHost.make(&"home", home, {&"pictures": pictures, &"settings": SettingsScreen.route(path, source, quit)})


static func open(tree: SceneTree, path: String, source: Collection, quit: Callable) -> HomeScreen:
	var host := make_host(path, source, quit)
	# Home is a root, so whatever was under the screen it replaces goes too.
	AppShell.reset_to(tree, host)
	return host.body as HomeScreen


func _ready() -> void:
	if collection == null:
		collection = CollectionLibrary.load_bundled()
	if not quit_app.is_valid():
		quit_app = get_tree().quit
	_summary = summary(save_path, collection)
	_build_ui()
	# The host builds its nav after this body is ready, so the clearance is read when it is done.
	var host := get_parent() as TabHost
	if host != null:
		host.ready.connect(func() -> void: bottom_pad.custom_minimum_size.y = host.nav_clearance())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and quit_app.is_valid():
		quit_app.call()


## Continues the saved game with a fresh cut seed. The board checks the save again.
func continue_game() -> Board:
	if _launched or _summary.is_empty():
		return null
	_launched = true
	var puzzle := (_summary.saved as SaveGame.Snapshot).puzzle.copy()
	puzzle.cut_seed = SetupScreen.fresh_seed(int(Time.get_unix_time_from_system() * 1000.0), Time.get_ticks_usec())
	return BoardLaunch.launch(get_tree(), save_path, collection, puzzle, true, quit_app)


func show_pictures() -> void:
	if _opening or not open_pictures.is_valid():
		return
	_opening = true
	AppShell.present(get_tree(), open_pictures.call())


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	# The board leaves the clear colour on felt, so Home paints its own ground.
	background = ColorRect.new()
	background.color = Palette.page_background()
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	add_child(Workshop.backdrop())
	var scroller := ScrollContainer.new()
	scroller.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroller.scroll_deadzone = int(SetupScreen.TAP_SLOP)
	add_child(scroller)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", LOGO_TOP + int(SafeArea.current(get_tree()).y))
	scroller.add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", GAP)
	margin.add_child(_content)

	_content.add_child(_logo())
	var spacer := Control.new()
	spacer.custom_minimum_size.y = CARD_TOP - GAP
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	_content.add_child(spacer)

	var resuming := not _summary.is_empty()
	_build_card(resuming)

	empty_note = Label.new()
	empty_note.text = EMPTY_NOTE_TEXT
	empty_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_note.add_theme_color_override("font_color", Workshop.CREAM_DIM)
	empty_note.visible = not resuming and FileAccess.file_exists(save_path)
	_content.add_child(empty_note)

	daily_tile = _tile(DAILY_TEXT, Workshop.SUN_BUTTON)
	daily_tile.disabled = true
	if resuming:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", GAP)
		_content.add_child(row)
		new_button = _tile(NEW_TEXT, Workshop.ORANGE_BUTTON)
		new_button.pressed.connect(show_pictures)
		row.add_child(new_button)
		row.add_child(daily_tile)
	else:
		_content.add_child(daily_tile)
	# Read once in the tree, where the theme's sun key resolves; it stays bright while it waits.
	daily_tile.add_theme_stylebox_override("disabled", daily_tile.get_theme_stylebox("normal"))
	daily_tile.add_theme_color_override("font_disabled_color", Color(Workshop.INK, 0.7))
	new_button.disabled = not open_pictures.is_valid()

	bottom_pad = Control.new()
	bottom_pad.mouse_filter = MOUSE_FILTER_IGNORE
	_content.add_child(bottom_pad)


# A sign-painted logo: sun yellow, a dark rim and a drop below it.
func _logo() -> Label:
	var logo := Label.new()
	logo.text = TITLE_TEXT
	logo.theme_type_variation = UiTheme.TITLE
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", LOGO_SIZE)
	logo.add_theme_color_override("font_color", LOGO_COLOR)
	logo.add_theme_color_override("font_outline_color", Workshop.CHOC)
	logo.add_theme_constant_override("outline_size", LOGO_OUTLINE)
	logo.add_theme_color_override("font_shadow_color", Color(Workshop.CHOC, 0.6))
	logo.add_theme_constant_override("shadow_offset_y", LOGO_OUTLINE)
	logo.mouse_filter = MOUSE_FILTER_IGNORE
	return logo


# The puzzle in progress in a wooden frame inside a chocolate well, or the first picture as a welcome.
func _build_card(resuming: bool) -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", UiTheme.PANEL_PADDING)
	var frame := Workshop.framed(_summary.texture if resuming else _first_picture_texture(), HERO_HEIGHT)
	hero = frame.get_child(0) as TextureRect
	body.add_child(frame)

	eyebrow_label = Label.new()
	eyebrow_label.add_theme_font_size_override("font_size", EYEBROW_SIZE)
	eyebrow_label.add_theme_color_override("font_color", Workshop.CREAM_DIM)
	title_label = Label.new()
	title_label.theme_type_variation = UiTheme.TITLE
	title_label.add_theme_font_size_override("font_size", HEADLINE_SIZE)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title_label)
	body.add_child(eyebrow_label)

	if resuming:
		eyebrow_label.text = "%s · %d pieces · %s" % [RESUME_TEXT, _summary.piece_count, _summary.style_name]
		if _summary.has("played"):
			eyebrow_label.text += " · %s played" % _summary.played
		title_label.text = _summary.title
		progress_bar = _progress_bar(_summary.progress, "%d / %d" % [_summary.placed, _summary.piece_count])
		body.add_child(progress_bar)
		continue_button = _button(CONTINUE_TEXT, continue_game)
		continue_button.icon = Workshop.icon("play")
		body.add_child(continue_button)
	else:
		eyebrow_label.text = FIRST_EYEBROW
		title_label.text = FIRST_TITLE
		new_button = _button(PICK_TEXT, show_pictures)
		body.add_child(new_button)
	card = Workshop.card(RESUME_RIBBON if resuming else FIRST_RIBBON, body)
	_content.add_child(card)


func _progress_bar(fraction: float, text: String) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = roundf(fraction * 100.0)
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", BAR_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Workshop.CHOC)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(label)
	return bar


# The first picture that loads, so a failed one does not leave the hero bare when another would do.
func _first_picture_texture() -> Texture2D:
	for picture in collection.pictures:
		var texture := collection.load_texture(picture)
		if texture != null:
			return texture
	return null


func _button(label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = FOCUS_NONE
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.pressed.connect(action)
	return button


func _tile(label: String, variation: StringName) -> Button:
	var tile := Button.new()
	tile.text = label
	tile.theme_type_variation = variation
	tile.focus_mode = FOCUS_NONE
	tile.size_flags_horizontal = SIZE_EXPAND_FILL
	tile.custom_minimum_size = Vector2(0, TILE_HEIGHT)
	return tile
