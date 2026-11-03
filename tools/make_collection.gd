extends SceneTree
## Writes one placeholder collection (abstract, geometry, landscape or pattern): pictures, thumbnails and manifest.json.
## Run: godot --headless --script tools/make_collection.gd [-- --out res://dir --id abstract --title Abstract --long-edge 2048]

const ArtSynth := preload("res://tools/art_synth.gd")


func _init() -> void:
	var out := "res://assets/collections/abstract"
	var id := "abstract"
	var title := "Abstract"
	var long_edge := ArtSynth.LONG_EDGE
	var args := OS.get_cmdline_user_args()
	for i in range(0, args.size() - 1, 2):
		match args[i]:
			"--out":
				out = args[i + 1]
			"--id":
				id = args[i + 1]
			"--title":
				title = args[i + 1]
			"--long-edge":
				long_edge = int(args[i + 1])

	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out + "/thumbs"))
	if err != OK:
		_fail("could not create %s (error %d)" % [out, err])
		return
	var thumb_edge := mini(ArtSynth.THUMB_LONG_EDGE, long_edge / 2)
	for spec in ArtSynth.specs_for(id):
		var image := ArtSynth.render(spec, ArtSynth.size_for(spec.aspect, long_edge))
		if not _save(image, "%s/%s.webp" % [out, spec.slug]):
			return
		var thumb := image.duplicate() as Image
		var thumb_size := ArtSynth.size_for(spec.aspect, thumb_edge)
		thumb.resize(thumb_size.x, thumb_size.y, Image.INTERPOLATE_LANCZOS)
		if not _save(thumb, "%s/thumbs/%s.webp" % [out, spec.slug]):
			return

	var path := out + "/manifest.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("could not write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(ArtSynth.manifest(id, title, long_edge), "\t", true) + "\n")
	file.close()
	print("wrote ", path)
	quit(0)


func _save(image: Image, path: String) -> bool:
	var err := image.save_webp(path, true, ArtSynth.WEBP_QUALITY)
	if err != OK:
		_fail("could not save %s (error %d)" % [path, err])
		return false
	print("wrote ", path)
	return true


func _fail(message: String) -> void:
	printerr("make_collection: " + message)
	quit(1)
