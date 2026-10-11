extends SceneTree

const Audio = preload("res://render/combat_audio.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://").get_base_dir().path_join("../artifacts/native-v20").simplify_path()
	DirAccess.make_dir_recursive_absolute(directory)
	var settings_file := directory.path_join("audio-settings-test-%d.cfg" % OS.get_process_id())
	var audio := Audio.new()
	audio.settings_path = settings_file
	root.add_child(audio)
	audio.set_process(false)
	for category in Audio.CATEGORY_BUSES:
		check(audio.get_category_volume(category) == 1.0, category + " preserves the existing default mix")
	check(audio._music_player.bus == "Music" and audio._music_tail.bus == "Music", "Both sides of a crossfade use the music bus")
	check(audio._food_player.bus == "SFX", "Food pickup uses the SFX bus")
	for player in audio._voices: check(player.bus == "SFX", "Every impact and weapon player uses the SFX bus")
	for player in audio._speech_players.values(): check(player.bus == "Voice", "Every hero and enemy speaker uses the voice bus")
	check(audio._intro_player.bus == "Voice", "Boss introduction also uses the voice bus")
	var music_bus := AudioServer.get_bus_index("Music")
	var effects_bus := AudioServer.get_bus_index("SFX")
	var voice_bus := AudioServer.get_bus_index("Voice")
	check(audio.set_category_volume("music", .25) == OK, "Changing music volume persists successfully")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_bus)), .25), "Music level reaches the native mixer")
	check(is_zero_approx(AudioServer.get_bus_volume_db(effects_bus)) and is_zero_approx(AudioServer.get_bus_volume_db(voice_bus)), "Changing music does not change voice or SFX")
	check(audio.set_category_volume("sfx", 0.0) == OK and AudioServer.is_bus_mute(effects_bus), "Zero SFX volume really mutes its mixer bus")
	check(not AudioServer.is_bus_mute(music_bus) and not AudioServer.is_bus_mute(voice_bus), "Muting effects leaves music and speech audible")
	check(audio.set_category_volume("voice", .4) == OK and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(voice_bus)), .4), "Voice has an independent native mixer level")
	check(audio.set_category_volume("unknown", .5) == ERR_INVALID_PARAMETER and audio.set_category_volume("voice", NAN) == ERR_INVALID_PARAMETER and audio.set_category_volume("voice", INF) == ERR_INVALID_PARAMETER, "Invalid category and nonfinite levels are rejected")
	check(is_equal_approx(audio.get_category_volume("voice"), .4), "Invalid settings do not alter the last valid voice volume")
	var restored := Audio.new()
	restored.settings_path = settings_file
	root.add_child(restored)
	check(is_equal_approx(restored.get_category_volume("music"), .25) and restored.get_category_volume("sfx") == 0 and is_equal_approx(restored.get_category_volume("voice"), .4), "All three levels restore in a new audio instance")
	restored.queue_free()
	await process_frame
	check(audio.set_category_volume("sfx", 1.5) == OK and audio.get_category_volume("sfx") == 1.0 and not AudioServer.is_bus_mute(effects_bus), "Raising a muted slider restores effects and clamps the upper limit")
	var config := ConfigFile.new()
	config.load(settings_file)
	config.set_value("other", "keep", "preserved")
	config.save(settings_file)
	check(audio.set_category_volume("voice", -.2) == OK and audio.get_category_volume("voice") == 0.0, "Negative input clamps to mute")
	config.load(settings_file)
	check(config.get_value("other", "keep", "") == "preserved", "Saving audio settings preserves unrelated configuration")
	# Cross the actual WAV boundary twice per score, without replacing the playback object.
	for key in Audio.STAGE_MUSIC:
		audio.stop_music()
		audio.sync_stage_music({"stage": {"music": key}})
		audio.play_music()
		var player: AudioStreamPlayer = audio._music_player
		var stream: AudioStreamWAV = player.stream
		var playback := player.get_stream_playback()
		for lap in range(2):
			player.seek(stream.get_length() - .15)
			playback = player.get_stream_playback()
			await create_timer(.8).timeout
			check(player.playing and player.get_playback_position() < 2.0 and player.get_stream_playback() == playback, "%s wraps boundary %d continuously in the native audio engine" % [key, lap + 1])
		var position := player.get_playback_position()
		for i in range(120): audio.sync_stage_music({"stage": {"music": key}})
		check(audio._music_player == player and player.get_stream_playback() == playback and player.get_playback_position() >= position, key + " keeps its position when GO enters another area using the same score")
		player.stop()
		audio._process(.016)
		check(player.playing, key + " recovers an unexpectedly stopped active stream")
		audio.set_music_paused(true)
		audio._process(.5)
		check(player.stream_paused, key + " recovery does not override an explicit API pause")
		audio.set_music_paused(false)
	audio.sync_stage_music({"stage": {"music": "town"}})
	audio._process(Audio.MUSIC_FADE_SECONDS * .5)
	check(audio._music_player.playing and audio._music_tail.playing and audio._music_player.volume_linear > 0 and audio._music_tail.volume_linear > 0, "Changing regions overlaps both scores at the saved music level")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_bus)), .25), "Crossfade does not overwrite the player's music slider")
	audio.set_category_volume("music", 0.0)
	audio._process(Audio.MUSIC_FADE_SECONDS * .5)
	check(AudioServer.is_bus_mute(music_bus) and audio._music_player.playing and not audio._music_tail.playing, "Muting during a fade leaves the loop running and releases only its outgoing score")
	audio.set_category_volume("music", 1.0)
	check(not AudioServer.is_bus_mute(music_bus) and audio._music_player.playing, "Restoring volume continues the same loop")
	audio.stop_music()
	audio._process(1.0)
	check(not audio._music_player.playing and not audio._music_tail.playing, "Explicit stop is not undone by active-stream recovery")
	audio.queue_free()
	await process_frame
	await create_timer(.3).timeout
	check(DirAccess.remove_absolute(settings_file) == OK, "The isolated test leaves the player's settings untouched")
	print("AUDIO V20: %d checks, %d failures; native loop boundaries and mixer settings only, live listening remains pending" % [checks, failures])
	quit(0 if failures == 0 else 1)
