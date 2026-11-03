extends "res://tests/base_test.gd"

const LogCapture := preload("res://tests/log_capture.gd")
const FIXTURE := "res://tests/fixtures/collection/manifest.json"
const DIR := "res://tests/fixtures/collection"


func _init() -> void:
	_test_good()
	_test_missing_keys()
	_test_bad_values()
	_test_missing_file()
	_test_bad_licence()
	_test_extra_keys_are_ignored()
	_test_bad_manifest()
	_test_textures()
	finish()


func _good() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


func _parse(data: Variant) -> Array:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var collection := Collection.parse(data, FIXTURE)
	OS.remove_logger(capture)
	return [collection, capture]


func _expect_skipped(data: Variant, label: String, prefix := "Collection: skipping picture") -> Array:
	var result := _parse(data)
	var collection: Collection = result[0]
	var capture = result[1]
	check(collection.pictures.size() == 5, "%s: five pictures" % label)
	check(capture.warnings.size() == 1 and capture.warnings[0].begins_with(prefix), "%s: one warning %s" % [label, capture.warnings])
	check(capture.errors.is_empty(), "%s: no errors" % label)
	return result


func _test_good() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var c := Collection.load_manifest(FIXTURE)
	OS.remove_logger(capture)
	check(capture.warnings.is_empty() and capture.errors.is_empty(), "good: nothing logged")
	check(c.id == "fixture" and c.title == "Fixture", "good: id and title")
	check(c.pictures.size() == 6, "good: six pictures")
	var p := c.pictures[0]
	check(p.id == "fixture-ember-rings", "good: first id")
	check(p.size() == Vector2i(240, 160), "good: size")
	check(p.path == DIR + "/ember-rings.webp", "good: path")
	check(p.thumbnail_path == DIR + "/thumbs/ember-rings.webp", "good: thumbnail path")
	check(p.licence == "CC-BY-4.0" and p.generated, "good: licence and generated")
	check(c.find("fixture-tide-stripes").size() == Vector2i(240, 240), "good: find")
	check(c.find("nope") == null, "good: find unknown")


func _test_missing_keys() -> void:
	for key in ["id", "title", "file", "width", "height", "credit", "licence", "generated"]:
		var data := _good()
		data.pictures[0].erase(key)
		var result := _expect_skipped(data, "missing %s" % key)
		for p in (result[0] as Collection).pictures:
			check(p.title != "Ember Rings", "missing %s: skipped picture gone" % key)
		check(result[1].warnings[0].begins_with("Collection: skipping picture 0"), "missing %s: names index 0" % key)


func _test_bad_values() -> void:
	# The valid-count check cannot fire inside MIN_SIDE..MAX_SIDE (even 4096x64 has stops), so the
	# test pins that fact; the check stays as a guard if the generator tightens.
	for size in [Vector2i(4096, 64), Vector2i(64, 4096), Vector2i(2048, 64)]:
		check(not CutGenerator.valid_counts(size.x, size.y, 12, 400).is_empty(), "%s has a valid count" % size)
	var cases := [
		["width 1.5", "width", 1.5],
		["width 63", "width", 63],
		["height 4097", "height", 4097],
		["width string", "width", "240"],
		["empty title", "title", ""],
		["credit int", "credit", 3],
		["generated string", "generated", "yes"],
		["file with ..", "file", "../ember-rings.webp"],
		["file with /", "file", "sub/ember-rings.webp"],
		["file with backslash", "file", "sub\\ember-rings.webp"],
	]
	for case in cases:
		var data := _good()
		data.pictures[0][case[1]] = case[2]
		_expect_skipped(data, case[0])
	var dup := _good()
	dup.pictures[1].id = dup.pictures[0].id
	var result := _expect_skipped(dup, "duplicate id")
	check(result[1].warnings[0].begins_with("Collection: skipping picture 1"), "duplicate id: skips index 1")
	check((result[0] as Collection).find(dup.pictures[0].id).title == "Ember Rings", "duplicate id: first one kept")


func _test_missing_file() -> void:
	var data := _good()
	data.pictures[0].file = "missing.webp"
	var result := _expect_skipped(data, "missing file")
	check(result[1].warnings[0].contains("picture 0"), "missing file: names the index")


func _test_bad_licence() -> void:
	for licence in ["CC-BY-NC-4.0", "", "cc0-1.0"]:
		var data := _good()
		data.pictures[0].licence = licence
		_expect_skipped(data, "licence '%s'" % licence)


func _test_extra_keys_are_ignored() -> void:
	var data := _good()
	data["cover"] = "x"
	data.pictures[0]["tags"] = ["a"]
	var result := _parse(data)
	check((result[0] as Collection).pictures.size() == 6, "extra keys: six pictures")
	check(result[1].warnings.is_empty() and result[1].errors.is_empty(), "extra keys: nothing logged")


func _test_bad_manifest() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var results: Array[Collection] = [
		Collection.parse([], FIXTURE),
		Collection.parse({"id": "x", "title": "X"}, FIXTURE),
		Collection.parse({"id": "", "title": "X", "pictures": []}, FIXTURE),
		Collection.load_manifest("res://tests/fixtures/none.json"),
	]
	OS.remove_logger(capture)
	for c in results:
		check(c.pictures.is_empty(), "bad manifest: empty")
	check(capture.warnings.size() == results.size(), "bad manifest: one warning each, got %s" % capture.warnings)
	for w in capture.warnings:
		check(w.begins_with("Collection: could not use"), "bad manifest: warning text")
	check(capture.errors.is_empty(), "bad manifest: no errors")


func _test_textures() -> void:
	var c := Collection.load_manifest(FIXTURE)
	for p in c.pictures:
		check(c.load_texture(p).get_size() == Vector2(p.size()), "texture size %s" % p.id)
		check(maxf(c.load_thumbnail(p).get_size().x, c.load_thumbnail(p).get_size().y) == 120.0, "thumbnail size %s" % p.id)
	var data := _good()
	data.pictures[0].width = 200
	var wrong := (_parse(data)[0] as Collection)
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var tex := wrong.load_texture(wrong.pictures[0])
	OS.remove_logger(capture)
	check(tex == null, "wrong size: null")
	check(capture.warnings.size() == 1 and capture.warnings[0].begins_with("Collection: could not load picture"), "wrong size: one warning %s" % capture.warnings)
	var p := c.pictures[0]
	p.thumbnail_path = ""
	check(c.load_thumbnail(p).get_size() == Vector2(p.size()), "no thumbnail: full texture")
	# A thumbnail that is gone, or is not a texture, must not drop the picture from the strip.
	for bad in [DIR + "/thumbs/gone.webp", FIXTURE]:
		p.thumbnail_path = bad
		capture = LogCapture.new()
		OS.add_logger(capture)
		var fallback := c.load_thumbnail(p)
		OS.remove_logger(capture)
		check(fallback != null and fallback.get_size() == Vector2(p.size()), "broken thumbnail %s: full texture" % bad)
		check(capture.warnings.size() == 1 and capture.warnings[0] == "Collection: could not load thumbnail %s" % bad, "broken thumbnail %s: one warning %s" % [bad, capture.warnings])
		check(capture.errors.is_empty(), "broken thumbnail %s: no errors %s" % [bad, capture.errors])
