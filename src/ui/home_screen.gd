class_name HomeScreen
extends Control
## The Home tab: the saved game to continue, or a first-launch welcome, with the way to Pictures.
## It only reads the save; setting one aside is left to the screens that start a game.

const CONTINUE_TEXT := "Continue"
const RESUME_TEXT := "Resume"
const FIRST_EYEBROW := "Free · no ads · works offline"
const FIRST_TITLE := "Let's make a puzzle"
const PICK_TEXT := "Pick a picture"
const NEW_TEXT := "New puzzle\nPick a picture"
const DAILY_TEXT := "Daily puzzle\nComing soon"
const EMPTY_NOTE_TEXT := "Start a new one"
const TITLE_TEXT := "Pieceful"
const SIDE_MARGIN := 24
const GAP := 18
const HERO_HEIGHT := 640
const HERO_TEXT_BOTTOM := 12
const LOGO_TOP := 24
const BUTTON_HEIGHT := 72
const TILE_HEIGHT := 120
const BAR_HEIGHT := 14
const HEADLINE_SIZE := 46
const EYEBROW_SIZE := 18

var save_path := SaveFile.DEFAULT_PATH
var collection: Collection = null
var quit_app: Callable
## Returns the Pictures screen. While it is empty the buttons that lead there stay disabled.
var open_pictures: Callable

var background: ColorRect
var hero: TextureRect
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
	return TabHost.make(&"home", home, {&"pictures": pictures})


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
	var scroller := ScrollContainer.new()
	scroller.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroller.scroll_deadzone = int(SetupScreen.TAP_SLOP)
	add_child(scroller)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", GAP)
	scroller.add_child(_content)

	var resuming := not _summary.is_empty()
	_build_hero(resuming)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", GAP)
	_content.add_child(_inset(actions))

	empty_note = Label.new()
	empty_note.text = EMPTY_NOTE_TEXT
	empty_note.add_theme_color_override("font_color", Palette.muted_text())
	empty_note.visible = not resuming and FileAccess.file_exists(save_path)
	actions.add_child(empty_note)

	if resuming:
		continue_button = _button(CONTINUE_TEXT, continue_game)
		actions.add_child(continue_button)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", GAP)
		actions.add_child(row)
		daily_tile = _tile(DAILY_TEXT)
		new_button = _tile(NEW_TEXT)
		new_button.pressed.connect(show_pictures)
		row.add_child(daily_tile)
		row.add_child(new_button)
	else:
		new_button = _button(PICK_TEXT, show_pictures)
		actions.add_child(new_button)
		daily_tile = _tile(DAILY_TEXT)
		actions.add_child(daily_tile)
	new_button.disabled = not open_pictures.is_valid()
	daily_tile.disabled = true
	daily_tile.add_theme_stylebox_override("disabled", daily_tile.get_theme_stylebox("normal"))
	daily_tile.add_theme_color_override("font_disabled_color", Palette.muted_text())

	bottom_pad = Control.new()
	bottom_pad.mouse_filter = MOUSE_FILTER_IGNORE
	_content.add_child(bottom_pad)


func _build_hero(resuming: bool) -> void:
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(0, HERO_HEIGHT)
	frame.clip_contents = true
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	_content.add_child(frame)

	hero = TextureRect.new()
	hero.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero.mouse_filter = MOUSE_FILTER_IGNORE
	hero.texture = _summary.texture if resuming else _first_picture_texture()
	frame.add_child(hero)

	# The picture fades into the page colour so the text below it sits on a plain ground.
	var page := Palette.page_background()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(page, 0.0), Color(page, 1.0)])
	var fade_texture := GradientTexture2D.new()
	fade_texture.gradient = gradient
	fade_texture.fill_from = Vector2(0, 0)
	fade_texture.fill_to = Vector2(0, 1)
	var fade := TextureRect.new()
	fade.texture = fade_texture
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	fade.anchor_top = 0.4
	fade.offset_top = 0
	fade.mouse_filter = MOUSE_FILTER_IGNORE
	frame.add_child(fade)

	var logo := Label.new()
	logo.text = TITLE_TEXT
	logo.theme_type_variation = UiTheme.TITLE
	logo.add_theme_color_override("font_color", Color.WHITE)
	logo.add_theme_color_override("font_shadow_color", Palette.outline())
	logo.position = Vector2(SIDE_MARGIN, LOGO_TOP + SafeArea.current(get_tree()).y)
	frame.add_child(logo)

	var text := VBoxContainer.new()
	text.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	text.anchor_top = 1.0
	text.offset_left = SIDE_MARGIN
	text.offset_right = -SIDE_MARGIN
	text.offset_bottom = -HERO_TEXT_BOTTOM
	text.grow_vertical = GROW_DIRECTION_BEGIN
	text.alignment = BoxContainer.ALIGNMENT_END
	text.mouse_filter = MOUSE_FILTER_IGNORE
	frame.add_child(text)

	eyebrow_label = Label.new()
	eyebrow_label.add_theme_font_size_override("font_size", EYEBROW_SIZE)
	eyebrow_label.add_theme_color_override("font_color", Palette.muted_text())
	text.add_child(eyebrow_label)
	title_label = Label.new()
	title_label.theme_type_variation = UiTheme.TITLE
	title_label.add_theme_font_size_override("font_size", HEADLINE_SIZE)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(title_label)

	if resuming:
		eyebrow_label.text = RESUME_TEXT if not _summary.has("played") else "%s · %s played" % [RESUME_TEXT, _summary.played]
		title_label.text = _summary.title
		progress_bar = _progress_row(text, _summary.progress)
	else:
		eyebrow_label.text = FIRST_EYEBROW
		title_label.text = FIRST_TITLE


func _progress_row(parent: Control, fraction: float) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	parent.add_child(row)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = roundf(fraction * 100.0)
	bar.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.size_flags_vertical = SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	var radius := UiTheme.scaled(UiTheme.SLIDER_RADIUS, Settings.current().roundness)
	bar.add_theme_stylebox_override("background", _bar_box(Palette.raised_surface(), radius))
	bar.add_theme_stylebox_override("fill", _bar_box(Palette.accent(), radius))
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var percent := Label.new()
	percent.theme_type_variation = UiTheme.TITLE
	percent.text = "%d%%" % int(bar.value)
	row.add_child(percent)
	return bar


func _bar_box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box


# The first picture that loads, so a failed one does not leave the hero bare when another would do.
func _first_picture_texture() -> Texture2D:
	for picture in collection.pictures:
		var texture := collection.load_texture(picture)
		if texture != null:
			return texture
	return null


func _inset(child: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN)
	margin.add_child(child)
	return margin


func _button(label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = FOCUS_NONE
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.pressed.connect(action)
	return button


func _tile(label: String) -> Button:
	var tile := Button.new()
	tile.text = label
	tile.theme_type_variation = UiTheme.OPTION
	tile.focus_mode = FOCUS_NONE
	tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tile.size_flags_horizontal = SIZE_EXPAND_FILL
	tile.custom_minimum_size = Vector2(0, TILE_HEIGHT)
	return tile
