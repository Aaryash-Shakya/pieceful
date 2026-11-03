extends "res://tests/base_test.gd"

const SCRIPT := "res://tools/build_apk.sh"


func _init() -> void:
	_test_exists_and_runs()
	_test_ignored_and_exported()
	finish()


func _test_exists_and_runs() -> void:
	check(FileAccess.file_exists(SCRIPT), "the build script exists")
	var path := ProjectSettings.globalize_path(SCRIPT)
	check(FileAccess.get_unix_permissions(path) & FileAccess.UNIX_EXECUTE_OWNER != 0, "the script is executable")
	var text := FileAccess.get_file_as_string(SCRIPT)
	check(text.begins_with("#!/usr/bin/env bash\n"), "the script starts with the bash shebang")
	for needle in ["set -euo pipefail", "--export-debug \"Android\"", "build/pieceful-debug.apk", "install -r", "--no-install", "ANDROID_SERIAL"]:
		check(text.contains(needle), "the script contains " + needle)
	check(OS.execute("bash", ["-n", path]) == 0, "the script parses")


func _test_ignored_and_exported() -> void:
	var ignore_lines := FileAccess.get_file_as_string("res://.gitignore").split("\n")
	check("/build/" in ignore_lines, ".gitignore ignores /build/")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(presets.contains("include_filter=\"assets/fonts/*.txt, assets/collections/*/manifest.json\""), "the manifests are exported")
	check(presets.contains("exclude_filter=\"tools/*, tests/*\""), "tools and tests stay out of the export")
