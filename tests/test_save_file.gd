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
	_test_remove()
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
	check(SaveFile.read(PATH) == "one", "first write is read back")
	check(not FileAccess.file_exists(PATH + SaveFile.TEMP_SUFFIX), "no temp file after a write")


func _test_write_replaces() -> void:
	check(SaveFile.write_atomic(PATH, "two") == OK, "second write succeeds")
	check(SaveFile.read(PATH) == "two", "second write replaces the first")
	check(not FileAccess.file_exists(PATH + SaveFile.TEMP_SUFFIX), "no temp file after a replace")


func _test_stale_temp_is_ignored() -> void:
	SaveFile.write_atomic(PATH, "good")
	_write_raw(PATH + SaveFile.TEMP_SUFFIX, "half")
	check(SaveFile.read(PATH) == "good", "a stale temp file is never read")
	check(SaveFile.write_atomic(PATH, "three") == OK, "write over a stale temp file succeeds")
	check(SaveFile.read(PATH) == "three", "the new write wins over the stale temp file")
	check(not FileAccess.file_exists(PATH + SaveFile.TEMP_SUFFIX), "the stale temp file is gone")


func _test_read_missing() -> void:
	SaveFile.remove(PATH)
	check(SaveFile.read(PATH) == "", "a missing file reads as empty")
	check(not FileAccess.file_exists(PATH), "reading does not create the file")


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
	check(SaveFile.read(DIR + "/blocker") == "keep", "the blocking file is untouched")


func _test_failed_write_keeps_old_save() -> void:
	_clean()
	check(SaveFile.write_atomic(PATH, "good") == OK, "a good save is written")
	# A directory in the temp file's place makes the temp open fail.
	DirAccess.make_dir_recursive_absolute(PATH + SaveFile.TEMP_SUFFIX)
	check(SaveFile.write_atomic(PATH, "new") != OK, "a write that cannot create its temp file fails")
	check(SaveFile.read(PATH) == "good", "the previous save survives a failed write")
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
