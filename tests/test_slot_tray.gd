extends "res://tests/board_test.gd"


func _init() -> void:
	await process_frame
	_test_fit()
	make_board()
	_fit_board()
	_test_shows_the_pieces()
	finish()


func _test_fit() -> void:
	var area := Rect2(0, 0, 100, 60)
	check(SlotTray.fit([], area).is_empty(), "nothing to fit")
	var one: Array[Rect2] = [Rect2(10, 10, 50, 50)]
	var placed := SlotTray.fit(one, area)
	check(placed.size() == 1 and Vector2(placed[0].x, placed[0].y).is_equal_approx(area.get_center()), "a lone cluster sits in the middle")
	check(placed[0].z <= 60.0 / 50.0 and placed[0].z > 1.0, "it is scaled to fill the height")
	var many: Array[Rect2] = []
	for i in 9:
		many.append(Rect2(Vector2(i * 7, i * 3), Vector2(40 + i, 30)))
	placed = SlotTray.fit(many, area)
	var boxes: Array[Rect2] = []
	for i in 9:
		var size := many[i].size * placed[i].z
		boxes.append(Rect2(Vector2(placed[i].x, placed[i].y) - size / 2.0, size))
		check(area.encloses(boxes[i]), "cluster %d stays inside the area" % i)
	for i in 9:
		for j in range(i + 1, 9):
			check(not boxes[i].intersects(boxes[j]), "clusters %d and %d do not overlap" % [i, j])


func _put(piece: int, slot: int) -> void:
	var s := _grab_point(board.node_for(piece))
	_touch(0, s, true)
	var to := board.slot_rects[slot].get_center()
	_drag(0, to, to - s)
	_touch(0, to, false)


func _polygons(tray: SlotTray, slot: int) -> int:
	return tray._minis[slot].find_children("*", "Polygon2D", true, false).size()


func _test_shows_the_pieces() -> void:
	var tray := (board.get_node("Hud") as Hud).slot_tray
	check(_polygons(tray, 0) == 0 and not tray._badges[0].visible, "an empty slot shows nothing")
	_put(0, 0)
	_put(1, 0)
	_put(2, 3)
	check(_polygons(tray, 0) == 2, "slot 0 draws its two pieces")
	check(_polygons(tray, 3) == 1, "slot 3 draws its piece")
	check(tray._badges[0].visible and tray._badges[0].text == "2", "the badge counts pieces")
	var area := board.slot_rects[0]
	for holder in tray._minis[0].get_children():
		var inside := true
		for body in holder.find_children("*", "Polygon2D", true, false):
			for p in (body as Polygon2D).polygon:
				inside = inside and area.grow(1.0).has_point((holder as Node2D).position + p * (holder as Node2D).scale.x)
		check(inside, "the drawn pieces stay inside their slot")
	# Taking the stack out empties the picture.
	var centre := board.slot_rects[0].get_center()
	_touch(0, centre, true)
	check(_polygons(tray, 0) == 0 and not tray._badges[0].visible, "a slot that was emptied shows nothing")
	_touch(0, centre, false)
	check(_polygons(tray, 0) == 2, "the returned stack shows again")
