class_name SettingsScreen
extends Control
## The Settings tab: the sound and vibration switches on peach paper. The look settings exist in
## the file but no screen offers them yet.

const TITLE_TEXT := "Settings"
const SIDE_MARGIN := 24
const TOP_MARGIN := 24
const GAP := 18

var save_path := SaveFile.DEFAULT_PATH
var collection: Collection = null
var quit_app: Callable
var settings_path := Settings.DEFAULT_PATH

var sheet: SettingsSheet
var footer: Label
var _leaving := false


## The tab route Home and Pictures hand their nav. Built when pressed, like their own routes.
static func route(path: String, source: Collection, quit: Callable) -> Callable:
	return func() -> Node: return make_host(path, source, quit)


static func make_host(path: String, source: Collection, quit: Callable) -> TabHost:
	var screen := SettingsScreen.new()
	screen.save_path = path
	screen.collection = source
	screen.quit_app = quit
	return TabHost.make(&"settings", screen, {
		&"home": func() -> Node: return HomeScreen.make_host(path, source, quit),
		&"pictures": func() -> Node: return PicturesScreen.make_host(path, source, quit),
	})


func _ready() -> void:
	if collection == null:
		collection = CollectionLibrary.load_bundled()
	if not quit_app.is_valid():
		quit_app = get_tree().quit
	var shell := AppShell.find(get_tree())
	if shell != null:
		settings_path = shell.settings_path
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(Workshop.backdrop(true))
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	column.offset_left = SIDE_MARGIN
	column.offset_right = -SIDE_MARGIN
	column.offset_top = TOP_MARGIN + SafeArea.current(get_tree()).y
	column.add_theme_constant_override("separation", GAP)
	add_child(column)
	var title := Label.new()
	title.text = TITLE_TEXT
	title.theme_type_variation = Workshop.INK_TITLE
	column.add_child(title)
	sheet = SettingsSheet.new()
	sheet.path = settings_path
	# The paper is the panel here; the sheet's own well and heading would double them.
	sheet.ready.connect(func() -> void:
		sheet.heading.visible = false
		sheet.add_theme_stylebox_override("panel", StyleBoxEmpty.new()))
	column.add_child(sheet)
	footer = Label.new()
	footer.text = "Pieceful · free, no ads, works offline"
	footer.theme_type_variation = Workshop.INK_LABEL
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.modulate.a = 0.7
	column.add_child(footer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _leaving:
		_leaving = true
		HomeScreen.open(get_tree(), save_path, collection, quit_app)
