extends SceneTree

const Audio = preload("res://render/combat_audio.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.set_process(false)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/v35/music.json"))
	check(manifest.tracks.size() == 10 and Audio.STAGE_MUSIC.size() == 10,"All scenes and menu use the ten new acoustic scores")
	audio.play_music()
	for key in Audio.STAGE_MUSIC:
		var path: String = Audio.STAGE_MUSIC[key]
		check(path.begins_with("res://audio/v35/"),"No synthetic legacy score remains in live routing: "+key)
		check(FileAccess.get_sha256(path) == manifest.tracks[key].sha256,"Exact rendered audio is loaded: "+key)
		audio.sync_stage_music({"stage":{"music":key}})
		audio._process(Audio.MUSIC_FADE_SECONDS)
		var player: AudioStreamPlayer = audio._music_player
		var stream: AudioStreamWAV = player.stream
		check(stream.stereo and stream.mix_rate == 44100 and stream.get_length()>40,"Stereo full-length acoustic score: "+key)
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end == stream.data.size()/4,"Full PCM loop: "+key)
		var playback := player.get_stream_playback()
		for frame in range(60): audio.sync_stage_music({"stage":{"music":key}})
		check(player == audio._music_player and playback == player.get_stream_playback(),"Snapshots do not restart the score: "+key)
		player.seek(stream.get_length()-.08)
		var loop_playback := player.get_stream_playback()
		await create_timer(.75).timeout
		check(player.playing and player.get_playback_position()<2.0 and loop_playback == player.get_stream_playback(),"Actual playback wraps its loop without restart: %s at %.3f" % [key,player.get_playback_position()])
	for chapter in [1,2]:
		var stage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stage-%02d.json" % chapter))
		for segment in stage.segments:
			var expected: String = Audio.SCENE_MUSIC.get(segment.theme,segment.music)
			var world := {"stage":segment,"fighters":[]}
			audio.sync_stage_music(world)
			check(audio._music_key == expected,"Background selects its score: "+segment.name)
			world.fighters = [{"team":1,"kind":"boss","hp":100,"stage_boss":false}]
			audio.sync_stage_music(world)
			check(audio._music_key == "miniboss","Live officer overrides scene score: "+segment.name)
			world.fighters.append({"team":1,"kind":"boss","hp":200,"stage_boss":true})
			audio.sync_stage_music(world)
			check(audio._music_key == "boss","Final boss wins priority: "+segment.name)
			for fighter in world.fighters: fighter.hp=0
			audio.sync_stage_music(world)
			check(audio._music_key == expected,"After battle the actual background music returns: "+segment.name)
	audio.sync_stage_music({"stage":{"music":"town"}})
	audio._process(.2)
	audio.sync_stage_music({"stage":{"music":"siege"}})
	check(audio._music_tail.playing and audio._music_player.playing,"A fast scene change keeps a two-player crossfade")
	var held := float(audio._music_fade)
	audio.set_music_paused(true)
	audio._process(2)
	check(audio._music_fade == held and audio._music_tail.stream_paused,"Paused crossfade holds its position")
	audio.set_music_paused(false)
	audio._process(Audio.MUSIC_FADE_SECONDS)
	check(not audio._music_tail.playing and audio._music_tail.stream == null,"Crossfade releases outgoing audio")
	var music := audio._music_player
	audio.play_event({"type":"hit"})
	check(audio._music_player == music and music.playing,"Combat effect leaves music on its own channel")
	audio.stop_music()
	check(audio._music_key == "legacy" and not audio._music_player.playing and not audio._music_tail.playing,"Leaving restores the menu selection and releases both players")
	audio.play_music()
	check(audio._music_player.stream == audio._load_music("legacy") and audio._music_player.playing,"Returning to menu plays its new theme")
	audio.stop_music()
	for player in audio._voices: player.stop()
	audio.queue_free()
	await process_frame
	print("MUSIC V35 %s: %d checks, %d failures; listening acceptance remains pending" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
