extends SceneTree
## Writes the four snap sounds to assets/sounds. Run: godot --headless --script tools/make_sounds.gd

const Synth := preload("res://tools/sound_synth.gd")


func _init() -> void:
	for sound_name: StringName in Synth.SOUNDS:
		var path := "res://assets/sounds/%s.wav" % sound_name
		var err := Synth.render(sound_name).save_to_wav(path)
		if err != OK:
			printerr("make_sounds: could not save %s (error %d)" % [path, err])
			quit(1)
			return
		print("wrote ", path)
	quit(0)
