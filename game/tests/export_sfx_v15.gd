extends SceneTree

const Audio = preload("res://render/combat_audio.gd")

func _initialize() -> void:
	var directory := ProjectSettings.globalize_path("res://audio/v15/sfx")
	DirAccess.make_dir_recursive_absolute(directory)
	var audio := Audio.new()
	var manifest := {"version":"0.15", "sample_rate":Audio.SAMPLE_RATE, "format":"PCM signed 16-bit mono", "generator":"game/render/combat_audio.gd::_synthesize", "generator_sha256":FileAccess.get_sha256("res://render/combat_audio.gd"), "selection":"random shuffle bags; no immediate repeat, including bag boundaries", "listening_review":"not performed by agent; preview WAVs are available for human audition", "clips":{}}
	for kind in Audio.EVENT_SOUNDS:
		var clips := []
		for variant in range(Audio.IMPACT_VARIANTS if kind in ["hit","heavy_hit"] else Audio.SFX_VARIANTS):
			var filename := "%s-%d.wav" % [kind,variant+1]
			var sound: AudioStreamWAV = audio._synthesize(kind,variant)
			assert(sound.save_to_wav(directory.path_join(filename)) == OK)
			clips.append({"file":filename,"variant":variant,"seconds":sound.get_length(),"sha256":FileAccess.get_sha256(directory.path_join(filename))})
		manifest.clips[kind] = clips
	var output := FileAccess.open(directory.path_join("manifest.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest,"\t"))
	output.close()
	audio.free()
	print("V15 SFX EXPORTED: %d categories to %s" % [manifest.clips.size(),directory])
	quit()
