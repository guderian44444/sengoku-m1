extends SceneTree

const Audio = preload("res://render/combat_audio.gd")
const Battle = preload("res://core/battle.gd")
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
	await process_frame
	check(audio.speech_manifest.version in ["0.14","0.15"],"Original voice takes load, including a newer installed revision")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/v14/manifest.json"))
	for actor in ["oichi","boss_mori"]:
		var events := ["attack","heavy","hurt"] if actor == "oichi" else ["attack","special"]
		for event in events:
			var pool: Array = legacy.actors[actor][event]
			var minimum := 4 if actor == "oichi" and event != "hurt" else 3
			check(pool.size() >= minimum,"The requested distinct voice pool exists: " + actor + " " + event)
			var waveforms := []
			var texts := []
			for key in pool:
				var clip: Dictionary = legacy.clips[key]
				var stream := AudioStreamWAV.load_from_file("res://audio/v14/" + clip.file)
				check(clip.backend == "Qwen3-TTS-12Hz-1.7B-VoiceDesign" and clip.has("raw_sha256"),"New takes preserve model provenance and raw-source hashes")
				check(stream.get_length() > .08 and stream.get_length() < (3.5 if event == "special" else 1.8),"Each take has a short bounded spoken delivery")
				check(not texts.has(clip.text) and not waveforms.has(stream.data),"Variants change words and actual waveforms, not just gain")
				texts.append(clip.text)
				waveforms.append(stream.data)
				var peak := 0
				for offset in range(0,stream.data.size(),2): peak = maxi(peak,absi(stream.data.decode_s16(offset)))
				check(peak > 600 and peak < 32767,"Voice is audible and unclipped")
			pool = audio.speech_manifest.actors[actor][event]
			var previous := ""
			var heard := []
			for repeat in range(pool.size()*2+1):
				audio.stop_speech()
				audio.play_character(actor,event)
				check(audio.last_spoken != previous,"Consecutive calls never repeat the same line")
				previous = audio.last_spoken
				if not heard.has(previous): heard.append(previous)
			check(heard.size() == pool.size(),"Rotation reaches every voice variant")
	for hero in Battle.HEROES:
		var sim := Battle.new()
		sim.reset_training(hero)
		var fighter: Dictionary = sim.state.fighters[0]
		for combo in [1,2]:
			audio.stop_speech()
			sim.state.events.clear()
			fighter.heavy_combo = combo
			sim._begin(fighter,"heavy")
			var event: Dictionary = sim.state.events.filter(func(e: Dictionary) -> bool: return e.type == "swing")[0]
			audio.play_event(event)
			check(audio._speech_players.hero0.playing == (combo == 2),hero + " only shouts on heavy combo two")
		for combo in [1,2,3]:
			audio.stop_speech()
			audio.play_event({"type":"swing","actor_kind":hero,"action":"light","combo":combo})
			check(audio._speech_players.hero0.playing == (combo == 3),hero + " only shouts on light combo three")
		for action in ["ground_slam","upper_heavy","air_heavy","dash_heavy"]:
			audio.stop_speech()
			sim.state.events.clear()
			sim._begin(fighter,action)
			var event: Dictionary = sim.state.events.filter(func(e: Dictionary) -> bool: return e.type == "swing")[0]
			audio.play_event(event)
			check(not audio._speech_players.hero0.playing,hero + " has no shout on ordinary uncharged " + action)
		for action in ["charged","charged_upper","charged_slam","mixed_finisher","mixed_rising"]:
			audio.stop_speech()
			audio.play_event({"type":"swing","actor_kind":hero,"action":action})
			check(audio._speech_players.hero0.playing,hero + " keeps a forceful shout for " + action)
		audio.stop_speech()
		audio.play_event({"type":"special","actor_kind":hero})
		check(audio._speech_players.hero0.playing and audio.speech_manifest.actors[hero].special.has(audio.last_spoken),hero + " keeps the special move call")
	for action in ["boss_sweep","boss_smash","boss_chain"]:
		audio.stop_speech()
		audio.play_event({"type":"swing","actor_kind":"boss","actor_faction":"mori","action":action})
		check(audio.speech_manifest.actors.boss_mori["special" if action == "boss_chain" else "attack"].has(audio.last_spoken),"Mori's actual moves reach both variation pools")
	var music: AudioStreamWAV = audio._music_player.stream
	check(music != null and music.stereo and music.get_length() >= 60 and music.get_length() <= 90,"Battle music is a full stereo 60-90 second arrangement")
	check(music.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.loop_begin == 0 and music.loop_end == music.data.size()/4,"The complete PCM score loops without a silent tail")
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/v14/music.json"))
	check(recipe.instruments.size() >= 5 and recipe.events.size() > 800 and recipe.sections.size() >= 3,"Music retains an original multivoice score with contrasting sections")
	for channel in range(2):
		var edge := absf(float(music.data.decode_s16(channel*2)-music.data.decode_s16(music.data.size()-4+channel*2))/32768.0)
		check(edge < .035,"The loop boundary has no large waveform discontinuity")
	audio.play_music()
	check(audio._music_player.playing,"Main can start music independently")
	audio.set_music_paused(true)
	check(audio._music_player.stream_paused,"Pause holds the current music position")
	audio.set_music_paused(false)
	check(not audio._music_player.stream_paused and audio._music_player.playing,"Resume continues the existing stream")
	audio.stop_music()
	check(not audio._music_player.playing,"Stop ends the music stream")
	audio.stop_speech()
	for player in audio._voices: player.stop()
	await create_timer(0.1).timeout
	audio.queue_free()
	await process_frame
	await create_timer(.3).timeout
	print("V14 AUDIO: %d checks, %d failures; expressive delivery and arrangement still require listening" % [checks,failures])
	quit(0 if failures == 0 else 1)
