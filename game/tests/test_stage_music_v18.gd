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
	var audio := Audio.new()
	root.add_child(audio)
	audio.set_process(false)
	var legacy: AudioStreamWAV = audio._music_player.stream
	audio.play_music()
	audio.sync_stage_music({})
	check(audio._music_key == "legacy" and audio._music_player.stream == legacy, "Existing arenas retain the original BGM")
	for key in ["siege", "town", "castle", "boss"]:
		var previous: AudioStreamPlayer = audio._music_player
		audio.sync_stage_music({"stage": {"music": key}})
		var current: AudioStreamPlayer = audio._music_player
		var playback := current.get_stream_playback()
		var stream: AudioStreamWAV = current.stream
		check(audio._music_key == key and current.playing and audio._music_tail == previous and previous.playing, key + " starts with the prior score still playing")
		check(is_zero_approx(current.volume_linear), key + " begins from silence for the crossfade")
		check(stream.stereo and stream.get_length() >= 32 and stream.get_length() <= 80, key + " uses a complete stereo arrangement")
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_begin == 0 and stream.loop_end == stream.data.size() / 4, key + " repeats the full seamless PCM loop")
		for frame in range(120): audio.sync_stage_music({"stage": {"music": key}})
		check(audio._music_player == current and current.get_stream_playback() == playback and is_zero_approx(audio._music_fade), key + " is not restarted by repeated state sync")
		audio._process(Audio.MUSIC_FADE_SECONDS * .5)
		check(current.volume_linear > 0 and previous.volume_linear > 0, key + " and outgoing score overlap during the transition")
		var held: float = audio._music_fade
		audio.set_music_paused(true)
		audio._process(1.0)
		check(current.stream_paused and previous.stream_paused and audio._music_fade == held, "Pause holds both scores and the fade position")
		audio.set_music_paused(false)
		audio._process(Audio.MUSIC_FADE_SECONDS * .5)
		check(current.playing and not previous.playing and previous.stream == null, key + " releases the outgoing score after the fade")
		check(is_equal_approx(current.volume_db, Audio.MUSIC_VOLUME_DB), key + " returns to the normal music level")
	# A quick area transition during a fade must not leave a third score behind.
	audio.sync_stage_music({"stage": {"music": "town"}})
	audio._process(.1)
	audio.sync_stage_music({"stage": {"music": "castle"}})
	check(audio._music_key == "castle" and audio._music_player.playing and audio._music_tail.playing, "An interrupted fade keeps only two music players")
	audio.play_event({"type": "weapon_swing", "weapon": "sword"})
	var impact: AudioStreamPlayer = audio._voices[0]
	audio.play_character("nobunaga", "heavy", 0, true)
	check(impact.playing and audio._speech_players.hero0.playing, "Area music leaves short speech and effects on their own channels")
	audio.stop_music()
	check(not audio._music_player.playing and not audio._music_tail.playing and audio._music_tail.stream == null, "Returning to the menu stops both sides of an unfinished fade")
	check(audio._music_key == "legacy" and audio._music_player.stream == legacy and not audio._music_paused, "Stop resets the score selection for the next mode")
	check(impact.playing and audio._speech_players.hero0.playing, "Stopping BGM does not terminate voice or impact channels")
	audio.sync_stage_music({"stage": {"music": "siege"}})
	check(not audio._music_player.playing and not audio._music_tail.playing, "State sync while music is stopped does not start audio in a menu")
	audio.play_music()
	check(audio._music_key == "siege" and audio._music_player.playing, "An area selected before starting plays the selected score")
	audio.sync_stage_music({"stage": {"music": "unknown"}})
	check(audio._music_key == "legacy", "Unknown area music safely falls back to the existing score")
	audio.sync_stage_music({"stage": null})
	check(audio._music_key == "legacy", "Absent stage metadata safely retains the existing score")
	audio.stop_music()
	audio.stop_speech()
	for player in audio._voices: player.stop()
	await create_timer(.1).timeout
	audio.queue_free()
	await process_frame
	await create_timer(.3).timeout
	print("STAGE MUSIC V18: %d checks, %d failures; live listening remains pending" % [checks, failures])
	quit(0 if failures == 0 else 1)
