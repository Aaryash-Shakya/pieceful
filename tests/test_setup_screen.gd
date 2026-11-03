extends "res://tests/base_test.gd"

const LogCapture := preload("res://tests/log_capture.gd")
const SAVE := "user://test_setup/current.json"
const FIXTURE := "res://tests/fixtures/collection/manifest.json"
const Two := preload("res://tests/two_collections.gd")

var _fixture := Collection.load_manifest(FIXTURE)
var _screen: SetupScreen = null
var _quits := [0]


func _init() -> void:
	await process_frame
	_test_opens()
	await _test_layout()
	_test_slider_offers_valid_counts()
	_test_drag_does_not_generate()
	await _test_changes_coalesce()
	_test_picture_change_keeps_nearest()
	_test_preview_uses_the_seed()
	_test_one_collection_has_no_picker()
	_test_picker_switches_collections()
	await _test_picker_layout_and_touch()
	_test_broken_picture_is_dropped()
	_test_broken_thumbnail_keeps_the_tile()
	_test_nearest_count_without_options()
	_test_hover_is_not_a_swipe()
	_test_drag_resets()
	await _test_touch()
	await _test_empty_collection()
	_close()
	DirAccess.remove_absolute(SAVE.get_base_dir())
	finish()


func _close() -> void:
	if _screen != null:
		_screen.free()
		_screen = null


func _open(collection := _fixture) -> SetupScreen:
	_close()
	SaveFile.remove(SAVE)
	_screen = (load("res://src/ui/setup_screen.tscn") as PackedScene).instantiate() as SetupScreen
	_screen.save_path = SAVE
	_screen.collection = collection
	_screen.quit_app = func() -> void: _quits[0] += 1
	root.add_child(_screen)
	return _screen


func _test_opens() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var s := _open()
	OS.remove_logger(capture)
	check(capture.warnings.is_empty() and capture.errors.is_empty(), "the screen opens without warnings or errors: %s %s" % [capture.warnings, capture.errors])
	check(RenderingServer.get_default_clear_color() == Palette.page_background(), "the page background is the clear colour")
	check(s.picture_buttons.size() == 6, "one tile per picture")
	check(s.picture_buttons.size() > 0 and s.picture_buttons[0].button_pressed, "the first tile is pressed")
	check(s.picture != null and s.picture.id == "fixture-ember-rings", "the first picture is chosen")
	check(s.style == "regular", "Regular is the first style")
	check(s.style_buttons.size() == 2, "two style tiles")
	if s.style_buttons.size() == 2:
		check(s.style_buttons[0].text == "Regular" and s.style_buttons[1].text == "Irregular", "style tile texts")
		check(s.style_buttons[0].button_pressed and not s.style_buttons[1].button_pressed, "the Regular tile is pressed")
	check(s.count == 54, "the count starts at 54")
	check(s.count_label.text == "54 pieces", "count label")
	var split := CutGenerator.grid_split(240, 160, 54)
	check(split == Vector2i(9, 6) and s.split_label.text == "9 x 6 grid", "split label: %s" % s.split_label.text)
	check(s.picture_label.text == "Ember Rings", "picture label")
	check(not s.resume_card.visible, "no resume card without a save")
	check(s.start_button.text == "Start" and not s.start_button.disabled, "Start is offered")
	check(not s.empty_label.visible, "the empty message is hidden")
	check(s.generations == 0 and not s.preview_timer.is_stopped(), "the first cut waits for the timer")
	check(s.picture_buttons[0].theme_type_variation == UiTheme.OPTION, "picture tiles are option tiles")
	check(s.style_buttons[0].theme_type_variation == UiTheme.OPTION, "style tiles are option tiles")
	check(s.picture_buttons[0].icon != null and s.picture_buttons[0].expand_icon, "picture tiles show the thumbnail")


func _test_layout() -> void:
	# The headless window is not the phone's shape, so the screen is laid out in a phone-sized viewport.
	var phone := SubViewport.new()
	phone.size = Vector2i(540, 1200)
	root.add_child(phone)
	var s := _open()
	s.reparent(phone)
	await process_frame
	await process_frame
	var view := Rect2(Vector2.ZERO, Vector2(phone.size))
	check(s.size == view.size, "the screen fills the phone viewport: %s" % s.size)
	var controls: Array[Control] = [s.preview, s.picture_label, s.count_label, s.split_label, s.slider, s.start_button]
	controls.append_array(s.style_buttons)
	controls.append(s.picture_buttons[0])
	for c in controls:
		var r := c.get_global_rect()
		check(r.size.x > 0 and r.size.y > 0, "%s has a size" % c.get_class())
		check(view.encloses(r), "%s is on screen: %s" % [c.get_class(), r])
		check(r.position.y >= SetupScreen.MARGIN_TOP, "%s clears the status bar" % c.get_class())
	check(s.preview.size.y > 100 and s.preview.size.y <= SetupScreen.PREVIEW_MAX_HEIGHT, "the preview has a capped height: %s" % s.preview.size)
	check(is_equal_approx(s.preview.fit_rect().size.x, s.preview.size.x), "a wide picture fills the preview width")
	check(s.start_button.get_global_rect().end.y <= view.end.y - SetupScreen.MARGIN + 0.5, "Start sits above the bottom margin")
	check(is_equal_approx(s.start_button.size.x, view.size.x - 2 * SetupScreen.MARGIN), "Start is full width")
	var slider_rect := s.slider.get_global_rect()
	check(slider_rect.size.y >= UiTheme.GRABBER_SIZE.y, "the slider fits its grabber")
	check(slider_rect.end.y <= s.start_button.get_global_rect().position.y, "every row fits above Start without scrolling")
	check(slider_rect.size.y >= 44.0, "the slider is a 44 px touch target: %s" % slider_rect.size)
	var scrolled: Array[Control] = [s.preview, s.resume_card, s.resume_button]
	scrolled.append_array(s.picture_buttons)
	scrolled.append_array(s.style_buttons)
	for c in scrolled:
		check(c.mouse_filter == Control.MOUSE_FILTER_PASS, "%s passes drags to its scroller" % c.get_class())
	_close()
	phone.free()


func _press(phone: SubViewport, at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.position = at
	e.global_position = at
	phone.push_input(e, true)


func _move(phone: SubViewport, from: Vector2, to: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = to
	e.global_position = to
	e.relative = to - from
	phone.push_input(e, true)


# Press, move through each point in turn, release at the last one.
func _gesture(phone: SubViewport, points: Array[Vector2]) -> void:
	_press(phone, points[0], true)
	for i in range(1, points.size()):
		_move(phone, points[i - 1], points[i])
	_press(phone, points[-1], false)


func _test_touch() -> void:
	var phone := SubViewport.new()
	phone.size = Vector2i(540, 1200)
	root.add_child(phone)
	var s := _open()
	s.reparent(phone)
	await process_frame
	await process_frame

	var c1 := s.picture_buttons[1].get_global_rect().get_center()
	_gesture(phone, [c1, c1 + Vector2(20, 0)])
	check(s.picture.id == "fixture-ember-rings", "a swipe over a tile does not choose it")
	check(s.picture_buttons[0].button_pressed and not s.picture_buttons[1].button_pressed, "the chosen tile stays pressed after a swipe")
	_gesture(phone, [c1, c1 + Vector2(-20, 0), c1])
	check(s.picture.id == "fixture-ember-rings", "a swipe that comes back is still a swipe")
	check(s.picture_buttons[0].button_pressed and not s.picture_buttons[1].button_pressed, "still one tile pressed")
	_gesture(phone, [c1, c1 + Vector2(3, 2)])
	check(s.picture.id == "fixture-stained-glass", "a tap with a little jitter chooses the tile")
	check(s.picture_buttons[1].button_pressed and not s.picture_buttons[0].button_pressed, "the tapped tile is pressed")
	var c2 := s.picture_buttons[2].get_global_rect().get_center()
	_gesture(phone, [c2])
	check(s.picture.id == "fixture-tide-stripes", "a plain tap chooses the tile")

	var irregular := s.style_buttons[1].get_global_rect().get_center()
	_gesture(phone, [irregular, irregular + Vector2(0, -20)])
	check(s.style == "regular" and s.style_buttons[0].button_pressed, "a vertical swipe over a style tile does not choose it")
	_gesture(phone, [irregular])
	check(s.style == "irregular" and s.style_buttons[1].button_pressed, "a tap chooses the style")

	s.preview_timer.stop()
	var r := s.slider.get_global_rect()
	var before := s.slider.value
	_gesture(phone, [Vector2(r.end.x - 4, r.position.y + 3)])
	check(s.slider.value != before and s.slider.value == s.slider.max_value, "a tap near the slider's top edge moves it: %s" % s.slider.value)
	check(not s.preview_timer.is_stopped(), "the tap schedules the cut")
	_close()
	phone.free()


func _test_slider_offers_valid_counts() -> void:
	var s := _open()
	check(s.counts == CutGenerator.valid_counts(240, 160, 12, 400), "the slider offers the valid counts")
	check(s.slider.min_value == 0 and s.slider.max_value == s.counts.size() - 1 and s.slider.step == 1, "the slider is an index")
	var all_match := true
	for i in s.counts.size():
		s.slider.value = i
		all_match = all_match and s.count == s.counts[i]
	check(all_match, "every stop is a valid count")
	s.slider.value = 2.6
	check(int(s.slider.value) == 3 and s.count == s.counts[3], "a fractional value snaps to a stop")


func _test_drag_does_not_generate() -> void:
	var s := _open()
	s.preview_timer.timeout.emit()
	var g := s.generations
	check(g == 1, "a timeout generates once")
	s.slider.drag_started.emit()
	for i in [1, 4, 7, 2, 5]:
		s.slider.value = i
	check(s.preview_timer.is_stopped(), "a drag stops the timer")
	check(s.generations == g, "a drag never generates")
	check(s.count_label.text == "%d pieces" % s.counts[5], "the label follows the drag")
	s.slider.drag_ended.emit(true)
	check(not s.preview_timer.is_stopped() and s.generations == g, "a release schedules the cut")
	s.preview_timer.timeout.emit()
	check(s.generations == g + 1, "the release generates once")
	var expected := CutPreview.outline_segments(CutGenerator.generate_cut(240, 160, s.count, "regular", s.cut_seed))
	check(s.preview.segments == expected, "the preview is the cut for the screen's seed")


func _test_changes_coalesce() -> void:
	var s := _open()
	var g := s.generations
	for i in [3, 6, 9]:
		s.slider.value = i
	s.select_style("irregular")
	check(s.style == "irregular" and s.style_buttons[1].button_pressed, "Irregular is pressed")
	check(not s.preview_timer.is_stopped() and s.generations == g, "changes wait for the timer")
	s.preview_timer.timeout.emit()
	check(s.generations == g + 1, "several changes give one generation")
	var expected := CutPreview.outline_segments(CutGenerator.generate_cut(240, 160, s.counts[9], "irregular", s.cut_seed))
	check(s.preview.segments == expected, "the preview is the irregular cut at the last count")
	g = s.generations
	s.slider.value = 4
	await create_timer(0.3).timeout
	check(s.generations == g + 1, "the real timer fires once: %d" % (s.generations - g))


func _test_picture_change_keeps_nearest() -> void:
	check(SetupScreen.nearest_count(PackedInt32Array([48, 50, 56, 60]), 54) == 56, "nearest count")
	check(SetupScreen.nearest_count(PackedInt32Array([48, 52, 56]), 54) == 52, "a tie goes to the smaller")
	check(SetupScreen.nearest_count(PackedInt32Array([16, 25]), 400) == 25, "beyond the range gives the largest")
	var s := _open()
	check(s.count == 54, "precondition: 54")
	var square := CutGenerator.valid_counts(240, 240, 12, 400)
	check(not square.has(54), "precondition: 54 is not a square count")
	s.preview_timer.timeout.emit()
	s.select_picture(2)
	check(s.picture.id == "fixture-tide-stripes" and s.picture_buttons[2].button_pressed, "the square picture is chosen")
	var kept := SetupScreen.nearest_count(square, 54)
	check(s.count == kept, "the count moves to the nearest valid one")
	check(s.counts[int(s.slider.value)] == s.count, "the slider points at the count")
	check(s.preview.segments.is_empty() and s.preview.image_size == Vector2i(240, 240), "the new picture shows without lines")
	s.select_picture(0)
	var wide := CutGenerator.valid_counts(240, 160, 12, 400)
	check(s.count == SetupScreen.nearest_count(wide, kept), "going back keeps the nearest count")
	check(s.picture_buttons[0].button_pressed and not s.picture_buttons[2].button_pressed, "one tile pressed at a time")


func _test_preview_uses_the_seed() -> void:
	check(SetupScreen.fresh_seed(5, 7) == SeededRng.hash2(5, 7), "fresh_seed hashes its inputs")
	var a := _open().cut_seed
	check(0 <= a and a <= 0xFFFFFFFF, "the seed is 32-bit")
	var b := _open().cut_seed
	check(a != b, "each visit draws a new seed")


func _test_broken_picture_is_dropped() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	data.pictures[0].width = 200
	var broken := Collection.parse(data, FIXTURE)
	check(broken.pictures.size() == 6, "precondition: validation passes")
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var s := _open(broken)
	OS.remove_logger(capture)
	check(capture.warnings.size() == 1 and capture.warnings[0].begins_with("Collection: could not load picture"), "one load warning: %s" % capture.warnings)
	check(s.picture_buttons.size() == 5 and s.pictures.size() == 5, "the broken picture is dropped")
	check(s.picture != null and s.picture.id == "fixture-stained-glass", "the next picture is chosen")
	check(s.picture_buttons[0].button_pressed, "its tile is pressed")

	data = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	data.pictures[3].width = 200
	broken = Collection.parse(data, FIXTURE)
	check(broken.pictures.size() == 6, "precondition: a later broken picture passes validation")
	s = _open(broken)
	s.select_picture(2)
	var count := s.count
	capture = LogCapture.new()
	OS.add_logger(capture)
	# As a tap would leave it: the broken tile toggled on before its picture fails.
	s.picture_buttons[3].button_pressed = true
	s.select_picture(3)
	OS.remove_logger(capture)
	check(capture.warnings.size() == 1, "one load warning for the tapped picture: %s" % capture.warnings)
	check(s.picture_buttons.size() == 5 and s.pictures.size() == 5, "the broken tile is removed")
	check(s.picture.id == "fixture-tide-stripes", "a broken tap goes back to the previous picture")
	check(s.picture_buttons[2].button_pressed, "the previous tile is pressed again")
	check(s.count == count and s.preview.image_size == Vector2i(240, 240), "the previous choice is untouched")


func _test_drag_resets() -> void:
	var s := _open()
	s.slider.drag_started.emit()
	s.hide()
	s.show()
	s.preview_timer.stop()
	s.slider.value = 2
	check(not s.preview_timer.is_stopped(), "hiding the screen ends a drag the slider lost")
	s.slider.drag_started.emit()
	root.remove_child(s)
	root.add_child(s)
	s.preview_timer.stop()
	s.slider.value = 4
	check(not s.preview_timer.is_stopped(), "leaving the tree ends a drag the slider lost")


func _test_nearest_count_without_options() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var n := SetupScreen.nearest_count(PackedInt32Array(), 54)
	OS.remove_logger(capture)
	check(n == 54, "no options keeps the target: %d" % n)
	check(capture.warnings.size() == 1 and capture.errors.is_empty(), "no options warns once: %s %s" % [capture.warnings, capture.errors])
	check(SetupScreen.nearest_count(PackedInt32Array([16]), 54) == 16, "one option is the answer")


# A mouse that moves over a tile without a button held is not dragging it.
func _test_hover_is_not_a_swipe() -> void:
	var s := _open()
	var tile := s.picture_buttons[2]
	for x in [0.0, 60.0, 120.0]:
		var motion := InputEventMouseMotion.new()
		motion.global_position = Vector2(x, 400.0)
		motion.position = motion.global_position
		tile.gui_input.emit(motion)
	tile.pressed.emit()
	check(s.picture.id == "fixture-tide-stripes", "a press after hovering chooses the tile")


func _test_broken_thumbnail_keeps_the_tile() -> void:
	var broken := Collection.load_manifest(FIXTURE)
	broken.pictures[1].thumbnail_path = "res://tests/fixtures/collection/thumbs/gone.webp"
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var s := _open(broken)
	OS.remove_logger(capture)
	check(capture.warnings.size() == 1 and capture.warnings[0].begins_with("Collection: could not load thumbnail"), "one thumbnail warning: %s" % [capture.warnings])
	check(s.picture_buttons.size() == 6, "the picture keeps its tile")
	check(s.picture_buttons.size() == 6 and s.picture_buttons[1].icon != null, "the tile shows the full picture instead")


func _test_empty_collection() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var s := _open(Collection.parse([], "res://none.json"))
	OS.remove_logger(capture)
	check(capture.warnings.size() == 1 and capture.errors.is_empty(), "only the collection's warning: %s %s" % [capture.warnings, capture.errors])
	check(s.empty_label.visible and s.empty_label.text == "No pictures found", "the empty message shows")
	check(s.start_button.disabled, "Start is disabled")
	check(s.picture_buttons.is_empty(), "no tiles")
	await create_timer(0.3).timeout
	check(s.generations == 0, "nothing is generated")


func _test_one_collection_has_no_picker() -> void:
	var s := _open()
	check(s.sections.size() == 1 and s.sections[0] == _fixture, "a plain collection is its own section")
	check(s.collection_buttons.size() == 1 and not s._collection_scroller.visible, "one collection needs no picker")
	check(s.picture_buttons.size() == 6, "all its pictures show")


func _test_picker_switches_collections() -> void:
	var s := _open(Two.merged())
	check(s.sections.size() == 2 and s.collection_buttons.size() == 2, "a chip per collection")
	check(s._collection_scroller.visible, "the picker shows")
	check(s.collection_buttons[0].text == "Fixture" and s.collection_buttons[1].text == "Second", "chips carry the collection titles")
	check(s.collection_buttons[0].button_pressed and not s.collection_buttons[1].button_pressed, "the first collection is open")
	check(s.collection_buttons[0].theme_type_variation == UiTheme.OPTION, "chips are option tiles")
	check(s.picture.id == "fixture-ember-rings" and s.picture_buttons.size() == 6, "the first collection's first picture")
	s.select_picture(2)
	check(s.picture.id == "fixture-tide-stripes", "a later picture is chosen")
	var stale := s.picture_buttons[0]

	s.collection_buttons[1].pressed.emit()
	check(s.section_index == 1 and s.collection_buttons[1].button_pressed and not s.collection_buttons[0].button_pressed, "the chip is pressed")
	check(s.picture.id == "second-ember-rings", "the new collection's first picture is chosen: %s" % s.picture.id)
	check(s.pictures.size() == 6 and s.picture_buttons.size() == 6, "the strip shows the new pictures")
	check(s.picture_buttons[0].button_pressed and s.picture_buttons[0] != stale, "the first tile is pressed")
	check(s._strip.get_child_count() == s.picture_buttons.size(), "no tile is left behind")
	check(s.count == 54 and s.counts == CutGenerator.valid_counts(240, 160, 12, 400), "the count carries over")
	check(s.picture_label.text == "Ember Rings", "the label follows")
	check(not s.preview_timer.is_stopped(), "the cut is previewed again")

	s.slider.value = 0
	var low := s.count
	s.collection_buttons[0].pressed.emit()
	check(s.picture.id == "fixture-ember-rings" and s.count == low, "switching back keeps the count: %d" % s.count)
	var before := s.picture
	s.collection_buttons[0].pressed.emit()
	check(s.picture == before, "pressing the open collection again changes nothing")

	# The square second picture takes the nearest count of its own.
	s.select_collection(1)
	s.select_picture(2)
	s.slider.value = s.counts.size() - 1
	var high := s.count
	s.select_collection(0)
	check(s.counts.has(s.count) and s.count == SetupScreen.nearest_count(s.counts, high), "the nearest valid count is kept: %d" % s.count)


func _test_picker_layout_and_touch() -> void:
	var phone := SubViewport.new()
	phone.size = Vector2i(540, 1200)
	root.add_child(phone)
	var s := _open(Two.merged())
	s.reparent(phone)
	await process_frame
	await process_frame
	var view := Rect2(Vector2.ZERO, Vector2(phone.size))
	for chip in s.collection_buttons:
		var r := chip.get_global_rect()
		check(view.encloses(r) and r.size.y >= 44.0, "a chip is on screen and a finger target: %s" % r)
		check(chip.mouse_filter == Control.MOUSE_FILTER_PASS, "a chip passes drags to its scroller")
	check(s.collection_buttons[0].get_global_rect().end.y <= s.picture_buttons[0].get_global_rect().position.y, "the chips sit above the picture strip")
	check(s.slider.get_global_rect().end.y <= s.start_button.get_global_rect().position.y, "every row still fits above Start")

	var chip_centre := s.collection_buttons[1].get_global_rect().get_center()
	_gesture(phone, [chip_centre, chip_centre + Vector2(-20, 0)])
	check(s.section_index == 0 and s.collection_buttons[0].button_pressed, "a swipe over a chip does not open it")
	_gesture(phone, [chip_centre, chip_centre + Vector2(2, 2)])
	check(s.section_index == 1 and s.picture.id == "second-ember-rings", "a tap on a chip opens it")
	_close()
	phone.free()
