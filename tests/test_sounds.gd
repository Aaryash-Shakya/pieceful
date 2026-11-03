extends BaseTest

const Synth := preload("res://tools/sound_synth.gd")
const LENGTHS := {&"pick": 0.05, &"join": 0.07, &"lock": 0.12, &"complete": 0.93}


func _init() -> void:
	_test_render_format()
	_test_render_is_deterministic()
	_test_files_exist_and_load()
	_test_lengths()
	_test_onset()
	_test_files_match_generator()
	_test_licence_note()
	finish()


func _path(sound_name: StringName) -> String:
	return "res://assets/sounds/%s.wav" % sound_name


func _peak(stream: AudioStreamWAV, from_frame: int, to_frame: int) -> int:
	var peak := 0
	for i in range(from_frame, to_frame):
		peak = maxi(peak, absi(stream.data.decode_s16(2 * i)))
	return peak


func _test_render_format() -> void:
	for sound_name: StringName in Synth.SOUNDS:
		var s: AudioStreamWAV = Synth.render(sound_name)
		check(s.format == AudioStreamWAV.FORMAT_16_BITS, "%s is 16-bit" % sound_name)
		check(not s.stereo, "%s is mono" % sound_name)
		check(s.mix_rate == 44100, "%s mix rate is 44100" % sound_name)
		check(s.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s does not loop" % sound_name)


func _test_render_is_deterministic() -> void:
	for sound_name: StringName in Synth.SOUNDS:
		check(Synth.render(sound_name).data == Synth.render(sound_name).data, "%s renders the same twice" % sound_name)


func _test_files_exist_and_load() -> void:
	for sound_name: StringName in Synth.SOUNDS:
		var path := _path(sound_name)
		check(FileAccess.file_exists(path), "%s exists" % path)
		var loaded: Variant = load(path)
		check(loaded is AudioStreamWAV, "%s loads as AudioStreamWAV" % path)
		if loaded is AudioStreamWAV:
			var s: AudioStreamWAV = loaded
			check(s.format == AudioStreamWAV.FORMAT_16_BITS, "%s imports uncompressed" % path)
			check(not s.stereo, "%s imports mono" % path)
			check(s.mix_rate == 44100, "%s imports at 44100 Hz" % path)


func _test_lengths() -> void:
	for sound_name: StringName in Synth.SOUNDS:
		var loaded: Variant = load(_path(sound_name))
		if not loaded is AudioStreamWAV:
			check(false, "%s did not load" % sound_name)
			continue
		var s: AudioStreamWAV = loaded
		check(absf(s.get_length() - LENGTHS[sound_name]) <= 0.001, "%s length is %s s, got %s" % [sound_name, LENGTHS[sound_name], s.get_length()])
		if sound_name != &"complete":
			check(s.get_length() < 0.15, "%s is shorter than 150 ms" % sound_name)


func _test_onset() -> void:
	for sound_name: StringName in Synth.SOUNDS:
		var s: AudioStreamWAV = Synth.render(sound_name)
		var frames := s.data.size() / 2
		var whole := _peak(s, 0, frames)
		check(_peak(s, 0, 132) >= 0.1 * whole, "%s is audible within the first 3 ms" % sound_name)
		check(whole >= 1000, "%s is loud enough" % sound_name)


func _test_files_match_generator() -> void:
	for sound_name: StringName in Synth.SOUNDS:
		var loaded: Variant = load(_path(sound_name))
		if not loaded is AudioStreamWAV:
			check(false, "%s did not load" % sound_name)
			continue
		var from_file: AudioStreamWAV = loaded
		var rendered: AudioStreamWAV = Synth.render(sound_name)
		check(from_file.data.size() == rendered.data.size(), "%s file and generator have the same size" % sound_name)
		if from_file.data.size() != rendered.data.size():
			continue
		var worst := 0
		for i in range(from_file.data.size() / 2):
			worst = maxi(worst, absi(from_file.data.decode_s16(2 * i) - rendered.data.decode_s16(2 * i)))
		check(worst <= 1, "%s file matches the generator within 1 (worst %d)" % [sound_name, worst])


func _test_licence_note() -> void:
	var path := "res://assets/sounds/LICENSE.md"
	check(FileAccess.file_exists(path), "licence note exists")
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		check(text.contains("CC BY 4.0"), "licence note names CC BY 4.0")
		check(text.contains("tools/make_sounds.gd"), "licence note names the generator")
