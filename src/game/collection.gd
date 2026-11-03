class_name Collection
extends RefCounted
## A folder of pictures described by a manifest. Bad entries are skipped with one warning, so a
## broken picture never stops the game from starting.

const LICENCES: Array[String] = ["CC0-1.0", "public-domain", "CC-BY-4.0"]
const MIN_SIDE := 64
const MAX_SIDE := 4096
const MIN_COUNT := 12
const MAX_COUNT := SaveGame.MAX_PIECE_COUNT
const THUMBS_DIR := "thumbs"

const _PICTURE_KEYS: Array[String] = ["id", "title", "file", "width", "height", "credit", "licence", "generated"]


class Picture:
	var id := ""
	var title := ""
	var file := ""
	var path := ""
	var thumbnail_path := ""
	var width := 0
	var height := 0
	var credit := ""
	var licence := ""
	var generated := false

	func size() -> Vector2i:
		return Vector2i(width, height)


var id := ""
var title := ""
var pictures: Array[Picture] = []
## Set only on a merged collection (see CollectionLibrary): the collections its pictures came from.
var parts: Array[Collection] = []


static func load_manifest(manifest_path: String) -> Collection:
	if not FileAccess.file_exists(manifest_path):
		return _unusable(manifest_path, "file not found")
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(manifest_path)) != OK:
		return _unusable(manifest_path, "not valid JSON")
	return parse(json.data, manifest_path)


static func parse(data: Variant, manifest_path: String) -> Collection:
	if not data is Dictionary:
		return _unusable(manifest_path, "not an object")
	var root: Dictionary = data
	if not root.get("id") is String or (root.id as String).is_empty():
		return _unusable(manifest_path, "id")
	if not root.get("title") is String or (root.title as String).is_empty():
		return _unusable(manifest_path, "title")
	if not root.get("pictures") is Array:
		return _unusable(manifest_path, "pictures")
	var collection := Collection.new()
	collection.id = root.id
	collection.title = root.title
	var folder := manifest_path.get_base_dir()
	var seen := {}
	var index := 0
	for entry in root.pictures:
		var picture: Variant = _read_picture(entry, folder, seen)
		if picture is String:
			push_warning("Collection: skipping picture %d in %s: %s" % [index, manifest_path, picture])
		else:
			seen[picture.id] = true
			collection.pictures.append(picture)
		index += 1
	return collection


func find(picture_id: String) -> Picture:
	for picture in pictures:
		if picture.id == picture_id:
			return picture
	return null


func load_texture(picture: Picture) -> Texture2D:
	var texture := load(picture.path) as Texture2D
	if texture == null or texture.get_size() != Vector2(picture.size()):
		push_warning("Collection: could not load picture %s" % picture.path)
		return null
	return texture


## The thumbnail, or the full picture when there is none or it fails, so the picture keeps its tile.
func load_thumbnail(picture: Picture) -> Texture2D:
	if picture.thumbnail_path != "":
		# Checked first: load() on a missing path logs an engine error.
		var thumbnail: Texture2D = null
		if ResourceLoader.exists(picture.thumbnail_path):
			thumbnail = load(picture.thumbnail_path) as Texture2D
		if thumbnail != null:
			return thumbnail
		push_warning("Collection: could not load thumbnail %s" % picture.thumbnail_path)
	return load_texture(picture)


static func _unusable(manifest_path: String, reason: String) -> Collection:
	push_warning("Collection: could not use %s: %s" % [manifest_path, reason])
	return Collection.new()


# A Picture, or the reason it cannot be used.
static func _read_picture(entry: Variant, folder: String, seen: Dictionary) -> Variant:
	if not entry is Dictionary:
		return "not an object"
	var d: Dictionary = entry
	for key in _PICTURE_KEYS:
		if not d.has(key):
			return "missing %s" % key
	if not _is_text(d.id):
		return "id"
	if seen.has(d.id):
		return "duplicate id %s" % d.id
	if not _is_text(d.title):
		return "title"
	if not _is_text(d.credit):
		return "credit"
	var file: Variant = d.file
	if not _is_text(file) or (file as String).contains("/") or (file as String).contains("\\") \
			or (file as String).contains(".."):
		return "file"
	for key in ["width", "height"]:
		if not SaveGame.is_int(d[key]) or int(d[key]) < MIN_SIDE or int(d[key]) > MAX_SIDE:
			return key
	if not d.licence is String or not LICENCES.has(d.licence):
		return "licence"
	if not d.generated is bool:
		return "generated"
	if CutGenerator.valid_counts(int(d.width), int(d.height), MIN_COUNT, MAX_COUNT).is_empty():
		return "no piece count fits %dx%d" % [int(d.width), int(d.height)]
	var picture := Picture.new()
	picture.id = d.id
	picture.title = d.title
	picture.file = file
	picture.path = "%s/%s" % [folder, file]
	# ResourceLoader, not FileAccess: an exported build keeps only the imported texture.
	if not ResourceLoader.exists(picture.path):
		return "%s does not exist" % picture.path
	var thumbnail := "%s/%s/%s" % [folder, THUMBS_DIR, file]
	picture.thumbnail_path = thumbnail if ResourceLoader.exists(thumbnail) else ""
	picture.width = int(d.width)
	picture.height = int(d.height)
	picture.credit = d.credit
	picture.licence = d.licence
	picture.generated = d.generated
	return picture


static func _is_text(value: Variant) -> bool:
	return value is String and not (value as String).is_empty()
