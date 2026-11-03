extends "res://tests/base_test.gd"

const ArtSynth := preload("res://tools/art_synth.gd")
const DIR := "res://assets/collections/abstract"
const FIXTURE_DIR := "res://tests/fixtures/collection"


func _init() -> void:
	_test_sizes()
	_test_render_is_deterministic()
	_test_manifest_matches_files()
	_test_import_settings()
	_test_pictures_are_rich()
	_test_fixture_collection()
	finish()


func _read_manifest(dir: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/manifest.json"))
	if parsed is Dictionary:
		return parsed
	return {}


func _test_sizes() -> void:
	check(ArtSynth.size_for(Vector2i(3, 2), 2048) == Vector2i(2048, 1365), "3:2 at 2048")
	check(ArtSynth.size_for(Vector2i(2, 3), 2048) == Vector2i(1365, 2048), "2:3 at 2048")
	check(ArtSynth.size_for(Vector2i(1, 1), 2048) == Vector2i(2048, 2048), "1:1 at 2048")
	check(ArtSynth.size_for(Vector2i(4, 3), 2048) == Vector2i(2048, 1536), "4:3 at 2048")
	check(ArtSynth.size_for(Vector2i(16, 9), 2048) == Vector2i(2048, 1152), "16:9 at 2048")
	check(ArtSynth.size_for(Vector2i(9, 16), 240) == Vector2i(135, 240), "9:16 at 240")


func _test_render_is_deterministic() -> void:
	var first_data := PackedByteArray()
	for i in ArtSynth.SPECS.size():
		var spec: Dictionary = ArtSynth.SPECS[i]
		var a: Image = ArtSynth.render(spec, Vector2i(96, 64))
		var b: Image = ArtSynth.render(spec, Vector2i(96, 64))
		check(a.get_data() == b.get_data(), "%s: same raw pixels" % spec.slug)
		check(a.get_format() == Image.FORMAT_RGB8, "%s: RGB8" % spec.slug)
		check(
			a.save_webp_to_buffer(true, ArtSynth.WEBP_QUALITY) == b.save_webp_to_buffer(true, ArtSynth.WEBP_QUALITY),
			"%s: same encoded bytes in one build" % spec.slug)
		if i == 0:
			first_data = a.get_data()
		elif i == 1:
			check(first_data != a.get_data(), "different specs give different pixels")


func _test_manifest_matches_files() -> void:
	var m := _read_manifest(DIR)
	check(m.get("id") == "abstract", "manifest id")
	check(m.get("title") == "Abstract", "manifest title")
	var pictures: Array = m.get("pictures", [])
	check(pictures.size() == ArtSynth.SPECS.size(), "six pictures")
	for i in mini(pictures.size(), ArtSynth.SPECS.size()):
		var spec: Dictionary = ArtSynth.SPECS[i]
		var p: Dictionary = pictures[i]
		var slug: String = spec.slug
		check(p.get("id") == "abstract-" + slug, "%s: id" % slug)
		check(p.get("file") == slug + ".webp", "%s: file" % slug)
		check(p.get("credit") == ArtSynth.CREDIT, "%s: credit" % slug)
		check(p.get("licence") == "CC-BY-4.0", "%s: licence" % slug)
		check(p.get("generated") == true, "%s: generated" % slug)
		var size := Vector2i(int(p.get("width", 0)), int(p.get("height", 0)))
		check(size == ArtSynth.size_for(spec.aspect, 2048), "%s: manifest size" % slug)
		var path: String = "%s/%s" % [DIR, p.get("file", "")]
		var thumb_path: String = "%s/thumbs/%s" % [DIR, p.get("file", "")]
		check(ResourceLoader.exists(path), "%s: picture exists" % slug)
		check(ResourceLoader.exists(thumb_path), "%s: thumbnail exists" % slug)
		var tex := load(path) as Texture2D
		check(tex != null and tex.get_size() == Vector2(size), "%s: texture size" % slug)
		var thumb := load(thumb_path) as Texture2D
		if thumb != null:
			var ts := thumb.get_size()
			check(maxf(ts.x, ts.y) == 256.0, "%s: thumbnail long side" % slug)
			var ratio := (ts.x / ts.y) / (float(size.x) / size.y)
			check(absf(ratio - 1.0) < 0.01, "%s: thumbnail aspect" % slug)
		else:
			check(false, "%s: thumbnail loads" % slug)
		var bytes := FileAccess.get_file_as_bytes(path).size()
		check(bytes >= 100000 and bytes <= 900000, "%s: source size %d" % [slug, bytes])


func _test_import_settings() -> void:
	for p: Dictionary in _read_manifest(DIR).get("pictures", []):
		var path: String = "%s/%s" % [DIR, p.file]
		var tex := load(path) as Texture2D
		check(tex != null and tex.get_image().has_mipmaps(), "%s: has mipmaps" % p.id)
		var import_text := FileAccess.get_file_as_string(path + ".import")
		check(import_text.contains("compress/mode=1"), "%s: lossy import" % p.id)
		check(import_text.contains("mipmaps/generate=true"), "%s: mipmaps on" % p.id)


func _test_pictures_are_rich() -> void:
	for p: Dictionary in _read_manifest(DIR).get("pictures", []):
		var img := (load("%s/%s" % [DIR, p.file]) as Texture2D).get_image()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGB8)
		var w := img.get_width()
		var h := img.get_height()

		var bins := PackedInt32Array()
		bins.resize(64)
		var samples := 0
		for y in range(0, h, 8):
			for x in range(0, w, 8):
				var c := img.get_pixel(x, y)
				var qr := mini(int(c.r * 4.0), 3)
				var qg := mini(int(c.g * 4.0), 3)
				var qb := mini(int(c.b * 4.0), 3)
				bins[qr * 16 + qg * 4 + qb] += 1
				samples += 1
		var populated := 0
		var biggest := 0
		for n in bins:
			if n >= samples * 0.005:
				populated += 1
			biggest = maxi(biggest, n)
		check(populated >= 16, "%s: %d colour bins populated" % [p.id, populated])
		check(biggest <= samples * 0.2, "%s: biggest bin holds %.1f%%" % [p.id, 100.0 * biggest / samples])

		var tiles := 0
		var textured := 0
		for ty in range(0, h - 31, 32):
			for tx in range(0, w - 31, 32):
				var sum := 0.0
				var sum_sq := 0.0
				for sy in 8:
					for sx in 8:
						var c := img.get_pixel(tx + sx * 4, ty + sy * 4)
						var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
						sum += lum
						sum_sq += lum * lum
				var mean := sum / 64.0
				var deviation := sqrt(maxf(sum_sq / 64.0 - mean * mean, 0.0))
				tiles += 1
				if deviation >= 0.01:
					textured += 1
		check(textured >= tiles * 0.95, "%s: %d of %d tiles have texture" % [p.id, textured, tiles])


func _test_fixture_collection() -> void:
	var m := _read_manifest(FIXTURE_DIR)
	check(m.get("id") == "fixture", "fixture id")
	var pictures: Array = m.get("pictures", [])
	check(pictures.size() == ArtSynth.SPECS.size(), "fixture has six pictures")
	for i in mini(pictures.size(), ArtSynth.SPECS.size()):
		var p: Dictionary = pictures[i]
		var size := Vector2i(int(p.get("width", 0)), int(p.get("height", 0)))
		check(size == ArtSynth.size_for(ArtSynth.SPECS[i].aspect, 240), "fixture %s: size" % p.get("id"))
		check(ResourceLoader.exists("%s/%s" % [FIXTURE_DIR, p.get("file", "")]), "fixture %s: picture" % p.get("id"))
		check(ResourceLoader.exists("%s/thumbs/%s" % [FIXTURE_DIR, p.get("file", "")]), "fixture %s: thumbnail" % p.get("id"))
