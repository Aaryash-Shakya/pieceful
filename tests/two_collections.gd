extends RefCounted
## Two collections made from the fixture, so the picker has something to switch between. The second
## has the same files under other ids. No class_name, so the exported class cache stays clean.

const FIXTURE := "res://tests/fixtures/collection/manifest.json"


## The fixture's manifest with every id prefixed by `id` in place of "fixture".
static func manifest(id: String, title: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	data.id = id
	data.title = title
	for picture: Dictionary in data.pictures:
		picture.id = (picture.id as String).replace("fixture-", id + "-")
	return data


static func second() -> Collection:
	return Collection.parse(manifest("second", "Second"), FIXTURE)


## The fixture, then the second collection, merged as the library does.
static func merged() -> Collection:
	var parts: Array[Collection] = [Collection.load_manifest(FIXTURE), second()]
	return CollectionLibrary.merge(parts)
