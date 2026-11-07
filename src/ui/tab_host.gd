class_name TabHost
extends Control
## The frame for a tab screen: its body fills the screen and the floating nav sits over the bottom.

const SIDE_MARGIN := 16.0
const BOTTOM_MARGIN := 16.0
## The prototype's 66 px nav at the 1.5 scale to Godot pixels.
const NAV_HEIGHT := 99.0

## Tab id to a Callable that returns the screen to open for it. Tabs without a route stay disabled.
var routes := {}
var body: Control
var _nav: FloatingNav
var _active := &""
var _switching := false


static func make(active: StringName, screen_body: Control, tab_routes: Dictionary) -> TabHost:
	var host := TabHost.new()
	host._active = active
	host.body = screen_body
	host.routes = tab_routes
	return host


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(body)
	_nav = FloatingNav.new()
	add_child(_nav)
	for id in _nav.buttons:
		(_nav.buttons[id] as Button).disabled = id != _active and not routes.has(id)
	_nav.set_active(_active)
	_nav.tab_pressed.connect(_on_tab_pressed)
	var height := maxf(NAV_HEIGHT, _nav.get_combined_minimum_size().y)
	var bottom := -(SafeArea.current(get_tree()).w + BOTTOM_MARGIN)
	_nav.anchor_left = 0.0
	_nav.anchor_right = 1.0
	_nav.anchor_top = 1.0
	_nav.anchor_bottom = 1.0
	_nav.offset_left = SIDE_MARGIN
	_nav.offset_right = -SIDE_MARGIN
	_nav.offset_bottom = bottom
	_nav.offset_top = bottom - height
	tree_exiting.connect(func() -> void: _switching = false)


## Bottom padding for a body's scrolling content so nothing ends up under the nav.
func nav_clearance() -> float:
	return -_nav.offset_top


func _on_tab_pressed(id: StringName) -> void:
	if id == _active or _switching or not routes.has(id):
		return
	_switching = true
	AppShell.present(get_tree(), (routes[id] as Callable).call())
