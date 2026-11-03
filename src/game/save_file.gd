class_name SaveFile
extends RefCounted
## Reads and writes the save text. A write goes to a temporary file first and is then renamed over
## the real one, so a crash mid-write never leaves a half-written save.

const DEFAULT_PATH := "user://save/current.json"
const TEMP_SUFFIX := ".tmp"


static func write_atomic(path: String, text: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temp := path + TEMP_SUFFIX
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored := file.store_string(text)
	file.close()
	if not stored:
		DirAccess.remove_absolute(temp)
		return ERR_FILE_CANT_WRITE
	# Renaming over an existing file replaces it in one step.
	var error := DirAccess.rename_absolute(temp, path)
	if error != OK:
		DirAccess.remove_absolute(temp)
	return error


static func read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


static func remove(path: String) -> void:
	for target in [path, path + TEMP_SUFFIX]:
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)
