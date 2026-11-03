extends "res://tests/base_test.gd"

const LogCapture := preload("res://tests/log_capture.gd")
const Two := preload("res://tests/two_collections.gd")
const IDS: Array[String] = ["abstract", "geometry", "landscape", "pattern"]


func _init() -> void:
	_test_bundled_list()
	_test_bundled_manifests_load_whole()
	_test_bundled_pictures_have_counts()
	_test_load_bundled()
	_test_merge()
	_test_duplicate_id()
	_test_empty_part_is_left_out()
	finish()


func _test_bundled_list() -> void:
	check(CollectionLibrary.BUNDLED.size() == IDS.size(), "four bundled collections")
	for i in mini(IDS.size(), CollectionLibrary.BUNDLED.size()):
		check(CollectionLibrary.BUNDLED[i] == "res://assets/collections/%s/manifest.json" % IDS[i], "bundled path %d" % i)


# A skipped entry logs one warning and shrinks the collection, so both are checked.
func _test_bundled_manifests_load_whole() -> void:
	for path in CollectionLibrary.BUNDLED:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var capture := LogCapture.new()
		OS.add_logger(capture)
		var c := Collection.load_manifest(path)
		OS.remove_logger(capture)
		check(capture.warnings.is_empty() and capture.errors.is_empty(), "%s: nothing logged: %s %s" % [path, capture.warnings, capture.errors])
		check(c.id == data.id and c.title != "", "%s: id and title" % path)
		check(c.pictures.size() == (data.pictures as Array).size() and c.pictures.size() == 6, "%s: every picture loads, %d" % [path, c.pictures.size()])


func _test_bundled_pictures_have_counts() -> void:
	for path in CollectionLibrary.BUNDLED:
		var c := Collection.load_manifest(path)
		for p in c.pictures:
			var counts := CutGenerator.valid_counts(p.width, p.height, Collection.MIN_COUNT, Collection.MAX_COUNT)
			check(not counts.is_empty(), "%s: has valid counts" % p.id)
			if not counts.is_empty():
				check(counts[0] >= Collection.MIN_COUNT and counts[-1] <= Collection.MAX_COUNT, "%s: counts stay in range" % p.id)
			check(c.load_texture(p) != null, "%s: loads" % p.id)
			check(c.load_thumbnail(p) != null and p.thumbnail_path != "", "%s: has a thumbnail" % p.id)
			check(p.generated and p.licence == "CC-BY-4.0", "%s: generated and licensed" % p.id)


func _test_load_bundled() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var library := CollectionLibrary.load_bundled()
	OS.remove_logger(capture)
	check(capture.warnings.is_empty() and capture.errors.is_empty(), "load_bundled: nothing logged")
	check(library.parts.size() == 4, "four parts")
	check(library.pictures.size() == 24, "24 pictures in all: %d" % library.pictures.size())
	var ids: Array[String] = []
	for part in library.parts:
		ids.append(part.id)
	check(ids == IDS, "parts in order: %s" % [ids])
	var seen := {}
	for p in library.pictures:
		seen[p.id] = true
	check(seen.size() == library.pictures.size(), "picture ids are unique")
	check(library.find("pattern-brick-weave") != null and library.find("geometry-sunburst") != null, "find reaches every collection")
	check(library.find("abstract-ember-rings") == library.parts[0].find("abstract-ember-rings"), "a part and the merge share pictures")
	check(library.find("nope") == null, "find an unknown id")
	check(library.load_texture(library.find("landscape-low-sun")) != null, "a picture of a later collection loads")


func _test_merge() -> void:
	var m := Two.merged()
	check(m.id == CollectionLibrary.ID and m.parts.size() == 2, "merged has two parts")
	check(m.pictures.size() == 12, "twelve pictures")
	check(m.find("fixture-tide-stripes") != null and m.find("second-tide-stripes") != null, "find in either part")
	check(m.parts[1].find("second-tide-stripes") != null and m.parts[1].find("fixture-tide-stripes") == null, "a part keeps only its own")
	check(m.pictures[0].id == "fixture-ember-rings" and m.pictures[6].id == "second-ember-rings", "order is part by part")


func _test_duplicate_id() -> void:
	var data := Two.manifest("second", "Second")
	data.pictures[2].id = "fixture-tide-stripes"
	var parts: Array[Collection] = [Collection.load_manifest(Two.FIXTURE), Collection.parse(data, Two.FIXTURE)]
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var m := CollectionLibrary.merge(parts)
	OS.remove_logger(capture)
	check(capture.warnings.size() == 1 and capture.warnings[0].begins_with("CollectionLibrary: skipping picture fixture-tide-stripes"), "one warning: %s" % [capture.warnings])
	check(capture.errors.is_empty(), "no errors")
	check(m.pictures.size() == 11 and m.parts[1].pictures.size() == 5, "the duplicate is skipped, in the merge and its part")
	check(m.find("fixture-tide-stripes") == parts[0].find("fixture-tide-stripes"), "the first picture keeps the id")


func _test_empty_part_is_left_out() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var broken := Collection.parse([], "res://none.json")
	var parts: Array[Collection] = [broken, Two.second()]
	var m := CollectionLibrary.merge(parts)
	OS.remove_logger(capture)
	check(capture.warnings.size() == 1, "only the broken collection's warning: %s" % [capture.warnings])
	check(m.parts.size() == 1 and m.parts[0].id == "second", "the empty part has no chip")
	var none: Array[Collection] = []
	check(CollectionLibrary.merge(none).pictures.is_empty(), "merging nothing gives nothing")
