class_name SaveFile
extends RefCounted
## Reads and writes the save text. A write goes to a temporary file first and is then renamed over
## the real one, so a crash mid-write never leaves a half-written save. Godot has no fsync, so after
## a power loss right after a save the file can still be lost on some filesystems (the next launch
## then warns once and starts fresh).

const DEFAULT_PATH := "user://save/current.json"
const TEMP_SUFFIX := ".tmp"


static func write_atomic(path: String, text: String) -> Error:
	# The result is ignored on purpose: opening the temp file below reports the real error.
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temp := path + TEMP_SUFFIX
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	# store_string only proves the bytes were buffered; a full disk shows up at flush or on re-reading,
	# and a truncated temp file must never replace the good save.
	var stored := file.store_string(text)
	file.flush()
	var healthy := stored and file.get_error() == OK
	file.close()
	if not healthy or _read_file(temp) != text:
		DirAccess.remove_absolute(temp)
		return ERR_FILE_CANT_WRITE
	# Renaming over an existing file replaces it in one step.
	var error := DirAccess.rename_absolute(temp, path)
	if error != OK:
		DirAccess.remove_absolute(temp)
	return error


## A missing file and an unreadable existing file both give "": callers treat both as no save.
static func read(path: String) -> String:
	return _read_file(path)


static func remove(path: String) -> void:
	for target in [path, path + TEMP_SUFFIX]:
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)


static func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
