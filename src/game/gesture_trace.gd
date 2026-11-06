class_name GestureTrace
extends RefCounted
## The last few touch events with the board's mode beside each, so a stuck gesture can be read
## back from a phone. It records and formats only; the board decides what to record.

const CAPACITY := 40
# A finger that has said nothing for this long while another finger is moving is suspect: its
# release may have been lost, and the board would then treat every new touch as a second finger.
const STALE_AFTER := 3.0
const FRESH_WITHIN := 0.5

var _lines: Array[String] = []


## One touch line, such as "press #1 at (120, 301) mode DRAGGING fingers 2".
static func describe(kind: String, index: int, position: Vector2, mode_name: String, finger_count: int) -> String:
	return "%s #%d at (%d, %d) mode %s fingers %d" % [kind, index, roundi(position.x), roundi(position.y), mode_name, finger_count]


## Fingers silent for STALE_AFTER seconds while another finger spoke within FRESH_WITHIN, by index.
## A lone finger is never stale, because a finger held still sends nothing.
static func stale_fingers(last_seen: Dictionary, now: float) -> PackedInt32Array:
	var stale := PackedInt32Array()
	var someone_fresh := false
	for index in last_seen:
		if now - float(last_seen[index]) <= FRESH_WITHIN:
			someone_fresh = true
	if not someone_fresh:
		return stale
	for index in last_seen:
		if now - float(last_seen[index]) >= STALE_AFTER:
			stale.append(index)
	stale.sort()
	return stale


## The overlay text: mode, how long each finger has been silent, and the held and locked counts.
static func report(mode_name: String, last_seen: Dictionary, now: float, held: int, locked: int) -> String:
	var fingers := "no fingers"
	if not last_seen.is_empty():
		var parts: PackedStringArray = []
		var indices := last_seen.keys()
		indices.sort()
		for index in indices:
			parts.append("#%d %.1fs" % [index, now - float(last_seen[index])])
		fingers = "fingers " + "  ".join(parts)
	return "mode %s  %s  held %d  locked %d" % [mode_name, fingers, held, locked]


func record(time: float, text: String) -> void:
	_lines.append("%.2f %s" % [time, text])
	if _lines.size() > CAPACITY:
		_lines.remove_at(0)


func lines() -> PackedStringArray:
	return PackedStringArray(_lines)


## The newest count lines, oldest first.
func tail(count: int) -> PackedStringArray:
	if count <= 0:
		return PackedStringArray()
	return PackedStringArray(_lines.slice(maxi(0, _lines.size() - count)))


func save_to(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(_lines) + "\n")
	return OK
