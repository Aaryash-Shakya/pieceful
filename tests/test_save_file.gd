extends "res://tests/base_test.gd"

const LogCapture := preload("res://tests/log_capture.gd")

const DIR := "user://test_save_file"
const PATH := DIR + "/current.json"


func _init() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	_test_write_creates_directory()
	_test_write_replaces()
	_test_stale_temp_is_ignored()
	_test_read_missing()
	_test_read_unreadable()
	_test_remove()
	_test_move_aside()
	OS.remove_logger(capture)
	check(capture.warnings.is_empty() and capture.errors.is_empty(), "the file layer prints nothing")
	_test_write_failure()
	_test_failed_write_keeps_old_save()
	_test_rename_failure()
	_clean()
	finish()


func _clean() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for sub in DirAccess.get_directories_at(DIR):
		for file in DirAccess.get_files_at(DIR + "/" + sub):
			DirAccess.remove_absolute(DIR + "/" + sub + "/" + file)
		DirAccess.remove_absolute(DIR + "/" + sub)
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)
	DirAccess.remove_absolute(DIR)


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _test_write_creates_directory() -> void:
	_clean()
	check(SaveFile.write_atomic(PATH, "one") == OK, "first write succeeds")
	check(SaveFile.read(PATH).text == "one", "first write is read back")
	check(not FileAccess.file_exists(PATH + SaveFile.TEMP_SUFFIX), "no temp file after a write")


func _test_write_replaces() -> void:
	check(SaveFile.write_atomic(PATH, "two") == OK, "second write succeeds")
	check(SaveFile.read(PATH).text == "two", "second write replaces the first")
	check(not FileAccess.file_exists(PATH + SaveFile.TEMP_SUFFIX), "no temp file after a replace")


func _test_stale_temp_is_ignored() -> void:
	SaveFile.write_atomic(PATH, "good")
	_write_raw(PATH + SaveFile.TEMP_SUFFIX, "half")
	check(SaveFile.read(PATH).text == "good", "a stale temp file is never read")
	check(SaveFile.write_atomic(PATH, "three") == OK, "write over a stale temp file succeeds")
	check(SaveFile.read(PATH).text == "three", "the new write wins over the stale temp file")
	check(not FileAccess.file_exists(PATH + SaveFile.TEMP_SUFFIX), "the stale temp file is gone")


func _test_read_missing() -> void:
	SaveFile.remove(PATH)
	var r := SaveFile.read(PATH)
	check(r.text == "" and r.error == ERR_FILE_NOT_FOUND, "a missing file reads as not found")
	check(not FileAccess.file_exists(PATH), "reading does not create the file")
	SaveFile.write_atomic(PATH, "")
	r = SaveFile.read(PATH)
	check(r.text == "" and r.error == OK, "an empty file reads as empty, not missing")


# Linux only, like every machine the tests run on: chmod takes the read permission away.
func _test_read_unreadable() -> void:
	SaveFile.write_atomic(PATH, "kept")
	var global := ProjectSettings.globalize_path(PATH)
	OS.execute("chmod", ["000", global])
	var r := SaveFile.read(PATH)
	OS.execute("chmod", ["644", global])
	check(r.text == "" and r.error != OK and r.error != ERR_FILE_NOT_FOUND,
			"an unreadable file is told apart from a missing one (error %d)" % r.error)
	check(SaveFile.read(PATH).text == "kept", "reading an unreadable file leaves it alone")


func _test_move_aside() -> void:
	var bad := SaveFile.bad_path(PATH)
	check(bad == DIR + "/current.bad.json", "the bad path sits next to the save")
	SaveFile.write_atomic(PATH, "old bad")
	check(SaveFile.move_aside(PATH) == OK, "a first move aside succeeds")
	SaveFile.write_atomic(PATH, "newer bad")
	_write_raw(PATH + SaveFile.TEMP_SUFFIX, "half")
	check(SaveFile.move_aside(PATH) == OK, "a move aside over an older bad save succeeds")
	check(SaveFile.read(bad).text == "newer bad", "the newest bad save replaces the older one")
	check(not FileAccess.file_exists(PATH), "the save path is free after a move aside")
	check(not FileAccess.file_exists(PATH + SaveFile.TEMP_SUFFIX), "a move aside clears the temp file")
	DirAccess.remove_absolute(bad)


func _test_remove() -> void:
	_write_raw(PATH, "x")
	_write_raw(PATH + SaveFile.TEMP_SUFFIX, "y")
	SaveFile.remove(PATH)
	check(not FileAccess.file_exists(PATH), "remove deletes the save")
	check(not FileAccess.file_exists(PATH + SaveFile.TEMP_SUFFIX), "remove deletes the temp file")
	SaveFile.remove(PATH)
	check(not FileAccess.file_exists(PATH), "removing twice changes nothing")


func _test_write_failure() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_write_raw(DIR + "/blocker", "keep")
	check(SaveFile.write_atomic(DIR + "/blocker/x.json", "x") != OK, "a write under a file fails")
	check(SaveFile.read(DIR + "/blocker").text == "keep", "the blocking file is untouched")


func _test_failed_write_keeps_old_save() -> void:
	_clean()
	check(SaveFile.write_atomic(PATH, "good") == OK, "a good save is written")
	# A directory in the temp file's place makes the temp open fail.
	DirAccess.make_dir_recursive_absolute(PATH + SaveFile.TEMP_SUFFIX)
	check(SaveFile.write_atomic(PATH, "new") != OK, "a write that cannot create its temp file fails")
	check(SaveFile.read(PATH).text == "good", "the previous save survives a failed write")
	_clean()


func _test_rename_failure() -> void:
	_clean()
	var target := DIR + "/dir_save"
	DirAccess.make_dir_recursive_absolute(target)
	_write_raw(target + "/inner", "keep")
	check(SaveFile.write_atomic(target, "x") != OK, "a rename onto a non-empty directory fails")
	check(not FileAccess.file_exists(target + SaveFile.TEMP_SUFFIX), "the temp file is removed after a failed rename")
	check(DirAccess.dir_exists_absolute(target), "the directory is still there")
	check(FileAccess.file_exists(target + "/inner"), "the directory's contents are intact")
