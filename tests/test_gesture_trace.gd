extends "res://tests/base_test.gd"

const PATH := "user://test_gesture_trace.txt"


func _init() -> void:
	_test_ring_keeps_the_newest()
	_test_tail()
	_test_describe()
	_test_save_round_trip()
	_test_stale_fingers()
	_test_report()
	finish()


func _test_ring_keeps_the_newest() -> void:
	var trace := GestureTrace.new()
	for i in GestureTrace.CAPACITY + 5:
		trace.record(float(i), "event %d" % i)
	var lines := trace.lines()
	check(lines.size() == GestureTrace.CAPACITY, "the trace holds at most CAPACITY lines")
	check(lines[0].ends_with("event 5"), "the oldest lines are dropped first")
	check(lines[lines.size() - 1].ends_with("event %d" % (GestureTrace.CAPACITY + 4)), "the newest line is last")


func _test_tail() -> void:
	var trace := GestureTrace.new()
	trace.record(1.0, "a")
	trace.record(2.0, "b")
	check(trace.tail(5).size() == 2, "tail of a short trace is the whole trace")
	check(trace.tail(1).size() == 1 and trace.tail(1)[0].ends_with("b"), "tail returns the newest lines")
	check(trace.tail(0).is_empty(), "tail of zero is empty")


func _test_describe() -> void:
	var text := GestureTrace.describe("press", 1, Vector2(120.4, 300.6), "DRAGGING", 2)
	check(text == "press #1 at (120, 301) mode DRAGGING fingers 2", "a touch line names the finger, place, mode and finger count")


func _test_save_round_trip() -> void:
	var trace := GestureTrace.new()
	trace.record(1.5, "first")
	trace.record(2.5, "second")
	check(trace.save_to(PATH) == OK, "the trace saves")
	var text := FileAccess.get_file_as_string(PATH)
	check(text.contains("first") and text.contains("second"), "the saved file holds the lines")
	check(text.find("first") < text.find("second"), "the saved file keeps the order")
	DirAccess.remove_absolute(PATH)


func _test_stale_fingers() -> void:
	var now := 100.0
	check(GestureTrace.stale_fingers({0: 99.9, 1: 99.8}, now).is_empty(), "two fresh fingers are not stale")
	check(GestureTrace.stale_fingers({0: 90.0}, now).is_empty(), "a lone finger is never called stale, it may just be resting")
	check(GestureTrace.stale_fingers({0: 90.0, 1: 99.9}, now) == PackedInt32Array([0]), "a finger silent for seconds while another moves is stale")
	check(GestureTrace.stale_fingers({0: 97.5, 1: 99.9}, now).is_empty(), "a finger silent for under the limit is not stale")
	check(GestureTrace.stale_fingers({0: 90.0, 1: 95.0}, now).is_empty(), "when every finger is quiet nothing is stale")
	check(GestureTrace.stale_fingers({0: 80.0, 1: 85.0, 2: 99.9}, now) == PackedInt32Array([0, 1]), "several stale fingers are all reported, in index order")


func _test_report() -> void:
	var text := GestureTrace.report("PANNING", {0: 99.0, 2: 99.9}, 100.0, 5, 17)
	check(text.contains("PANNING"), "the report names the mode")
	check(text.contains("#0 1.0s") and text.contains("#2 0.1s"), "the report lists each finger's silence")
	check(text.contains("held 5") and text.contains("locked 17"), "the report shows the held and locked counts")
	check(GestureTrace.report("IDLE", {}, 100.0, 0, 0).contains("no fingers"), "the report says when no finger is down")
