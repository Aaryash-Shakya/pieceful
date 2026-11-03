class_name CollectionLibrary
extends RefCounted
## The collections the app ships with. The board finds pictures through one Collection, so the library
## hands it one merged collection that also lists its parts for the setup screen's picker.

const BUNDLED: Array[String] = [
	"res://assets/collections/abstract/manifest.json",
	"res://assets/collections/geometry/manifest.json",
	"res://assets/collections/landscape/manifest.json",
	"res://assets/collections/pattern/manifest.json",
]
const ID := "library"
const TITLE := "Library"


static func load_bundled() -> Collection:
	var parts: Array[Collection] = []
	for path in BUNDLED:
		parts.append(Collection.load_manifest(path))
	return merge(parts)


## Every picture of every part, in order. A picture id already taken by an earlier part is skipped
## with one warning, so a saved id always names one picture. A part with no pictures is left out.
static func merge(parts: Array[Collection]) -> Collection:
	var merged := Collection.new()
	merged.id = ID
	merged.title = TITLE
	var owner_of := {}
	for part in parts:
		var kept := Collection.new()
		kept.id = part.id
		kept.title = part.title
		for picture in part.pictures:
			if owner_of.has(picture.id):
				push_warning("CollectionLibrary: skipping picture %s of %s: the id is already used by %s" % [picture.id, part.id, owner_of[picture.id]])
				continue
			owner_of[picture.id] = part.id
			kept.pictures.append(picture)
			merged.pictures.append(picture)
		if not kept.pictures.is_empty():
			merged.parts.append(kept)
	return merged
