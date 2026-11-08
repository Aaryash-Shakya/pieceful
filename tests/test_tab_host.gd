extends "res://tests/base_test.gd"
## The frame for the tab screens: a body, the floating nav, and tab switching through the shell.

const PATH := "user://test_tab_host.cfg"

var _built := 0


func _init() -> void:
	await process_frame
	_test_enabled_tabs()
	await _test_layout()
	await _test_switch_once()
	await _test_active_tab_ignored()
	finish()


func _factory() -> Callable:
	return func() -> Node:
		_built += 1
		var screen := Control.new()
		screen.name = "Built"
		return screen


func _shell(host: TabHost) -> AppShell:
	var shell := (load("res://src/ui/app_shell.tscn") as PackedScene).instantiate() as AppShell
	shell.settings_path = PATH
	shell.make_home = func() -> Node: return host
	root.add_child(shell)
	return shell


func _nav(host: TabHost) -> FloatingNav:
	for child in host.get_children():
		if child is FloatingNav:
			return child
	return null


func _test_enabled_tabs() -> void:
	var host := TabHost.make(&"home", Control.new(), {&"pictures": _factory()})
	root.add_child(host)
	var nav := _nav(host)
	check(nav != null, "the host mounts a floating nav")
	check((nav.buttons[&"home"] as Button).button_pressed, "home is pressed")
	check(not (nav.buttons[&"home"] as Button).disabled, "the active tab stays enabled")
	check(not (nav.buttons[&"pictures"] as Button).disabled, "a routed tab is enabled")
	check((nav.buttons[&"daily"] as Button).disabled, "daily is disabled without a route")
	check((nav.buttons[&"settings"] as Button).disabled, "settings is disabled without a route")
	host.free()


func _test_layout() -> void:
	var body := Control.new()
	var host := TabHost.make(&"home", body, {})
	var frame := Control.new()
	frame.size = Vector2(540, 1200)
	root.add_child(frame)
	frame.add_child(host)
	await process_frame
	var nav := _nav(host)
	check(body.get_parent() == host and body.size == host.size, "the body fills the host")
	check(host.get_child(0) == body, "the nav floats above the body")
	check(nav.position.x == 16.0 and is_equal_approx(nav.size.x, 540.0 - 32.0), "nav keeps a 16 px side margin")
	check(nav.size.y >= 66.0, "nav buttons are at least 66 px tall")
	var inset := SafeArea.current(get_root_tree()).w
	check(is_equal_approx(nav.position.y + nav.size.y, 1200.0 - inset - 16.0), "nav sits 16 px above the bottom inset")
	check(host.nav_clearance() >= nav.size.y, "clearance covers the nav")
	check(is_equal_approx(host.nav_clearance(), nav.size.y + inset + 16.0), "clearance is nav height plus inset plus 16")
	frame.free()


func get_root_tree() -> SceneTree:
	return root.get_tree()


func _test_switch_once() -> void:
	_built = 0
	var host := TabHost.make(&"home", Control.new(), {&"pictures": _factory()})
	var shell := _shell(host)
	await process_frame
	var nav := _nav(host)
	(nav.buttons[&"pictures"] as Button).pressed.emit()
	(nav.buttons[&"pictures"] as Button).pressed.emit()
	await process_frame
	check(_built == 1, "pressing twice builds one screen")
	check(shell.top() != null and shell.top().name == "Built", "the new screen is on top")
	shell.free()


func _test_active_tab_ignored() -> void:
	_built = 0
	var host := TabHost.make(&"home", Control.new(), {&"home": _factory(), &"pictures": _factory()})
	var shell := _shell(host)
	await process_frame
	(_nav(host).buttons[&"home"] as Button).pressed.emit()
	await process_frame
	check(_built == 0 and shell.top() == host, "pressing the active tab does nothing")
	shell.free()
