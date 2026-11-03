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
	if healthy:
		var back := read(temp)
		healthy = back.error == OK and back.text == text
	if not healthy:
		DirAccess.remove_absolute(temp)
		return ERR_FILE_CANT_WRITE
	# Renaming over an existing file replaces it in one step.
	var error := DirAccess.rename_absolute(temp, path)
	if error != OK:
		DirAccess.remove_absolute(temp)
	return error


## ERR_FILE_NOT_FOUND means there is no save. Any other error means a save exists that cannot be
## read right now, which must never be mistaken for no save.
class Read:
	var text := ""
	var error := OK


static func read(path: String) -> Read:
	var result := Read.new()
	if not FileAccess.file_exists(path):
		result.error = ERR_FILE_NOT_FOUND
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.error = FileAccess.get_open_error()
		# Never report a file that exists as missing.
		if result.error == OK or result.error == ERR_FILE_NOT_FOUND:
			result.error = ERR_FILE_CANT_READ
		return result
	result.text = file.get_as_text()
	return result


static func remove(path: String) -> void:
	for target in [path, path + TEMP_SUFFIX]:
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)


## Where a save the game cannot use is kept: current.json becomes current.bad.json.
static func bad_path(path: String) -> String:
	return path.get_basename() + ".bad.json"


## Renames the save to bad_path, replacing an older one, so a save the game cannot use is never lost.
static func move_aside(path: String) -> Error:
	var bad := bad_path(path)
	if FileAccess.file_exists(bad):
		DirAccess.remove_absolute(bad)
	var error := DirAccess.rename_absolute(path, bad)
	if FileAccess.file_exists(path + TEMP_SUFFIX):
		DirAccess.remove_absolute(path + TEMP_SUFFIX)
	return error
