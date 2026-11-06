extends "res://tests/base_test.gd"

var _fired: Array[StringName] = []


func _init() -> void:
	await process_frame
	_test_tabs()
	_test_set_active()
	_test_press_emits_once()
	_test_press_switches_tab()
	await _test_theme()
	finish()


func _make() -> FloatingNav:
	var nav := FloatingNav.new()
	nav.tab_pressed.connect(func(id: StringName) -> void: _fired.append(id))
	root.add_child(nav)
	return nav


func _test_tabs() -> void:
	var nav := _make()
	var names: Array[String] = []
	for tab in FloatingNav.TABS:
		var b := nav.buttons[tab[0]] as Button
		check(b != null and b.icon != null, "%s has an icon" % tab[1])
		check(b != null and b.text == tab[1], "%s has its label" % tab[1])
		names.append(b.text)
	check(names == ["Home", "Pictures", "Daily", "Settings"], "tabs are in order")
	var box := nav.get_child(0) as HBoxContainer
	check(box != null and box.get_child_count() == 4, "four buttons in a row")
	nav.free()


func _test_set_active() -> void:
	var nav := _make()
	_fired.clear()
	nav.set_active(&"daily")
	check(nav.active == &"daily", "daily is active")
	for id in nav.buttons:
		check((nav.buttons[id] as Button).button_pressed == (id == &"daily"), "only daily is pressed (%s)" % id)
	nav.set_active(&"nope")
	check(nav.active == &"daily" and (nav.buttons[&"daily"] as Button).button_pressed, "an unknown id changes nothing")
	check(_fired.is_empty(), "set_active does not emit")
	nav.free()


func _test_press_emits_once() -> void:
	var nav := _make()
	_fired.clear()
	var b := nav.buttons[&"pictures"] as Button
	b.button_pressed = true
	b.pressed.emit()
	check(_fired == [&"pictures"], "a press emits once with its id")
	check(nav.active == &"pictures", "a press makes it active")
	nav.free()


func _test_press_switches_tab() -> void:
	var nav := _make()
	nav.set_active(&"home")
	_fired.clear()
	var b := nav.buttons[&"settings"] as Button
	b.button_pressed = true
	b.pressed.emit()
	check(nav.active == &"settings", "active moves to the pressed tab")
	check(b.button_pressed and not (nav.buttons[&"home"] as Button).button_pressed, "the old tab is released")
	check(_fired == [&"settings"], "one signal with the new id")
	nav.free()


func _test_theme() -> void:
	var nav := _make()
	nav.theme = UiTheme.build(true)
	await process_frame
	check(nav.theme_type_variation == UiTheme.NAV, "panel uses the Nav variation")
	var box := nav.get_theme_stylebox("panel") as StyleBoxFlat
	check(box != null and box.bg_color == Palette.surface(true), "panel has the surface fill")
	var b := nav.buttons[&"home"] as Button
	check(b.theme_type_variation == UiTheme.NAV_BUTTON, "buttons use the NavButton variation")
	nav.free()
