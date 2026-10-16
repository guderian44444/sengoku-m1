extends SceneTree

const Audio = preload("res://render/combat_audio.gd")
const Battle = preload("res://core/battle.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func run() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	await process_frame
	check(audio.speech_manifest.version == "0.31", "The complete revision with per-event performance instructions is active")
	check(audio._speech_streams.size() == audio.speech_manifest.clips.size(), "All new and inherited speech files decode")
	var pcm_owners := {}
	var references := []
	var speakers := []
	var active := 0
	for hero in Battle.HEROES:
		check(audio.speech_manifest.hero_voice_profiles.has(hero), hero+" has a documented individual voice")
		speakers.append(str(audio.speech_manifest.hero_voice_profiles[hero].speaker))
		var events: Dictionary = audio.speech_manifest.actors[hero]
		var reference: String = events.intro[0]
		references.append(audio.speech_manifest.clips[reference].sha256)
		var seen := []
		for event in ["intro","attack","heavy","hurt","guard","special","victory","defeat","boss_defeat"]:
			var pool: Array = events[event]
			check(pool.size() == (3 if event in ["attack","heavy","hurt","guard","victory"] else 1), hero+" has its complete varied "+event+" pool")
			for key in pool:
				var clip: Dictionary = audio.speech_manifest.clips[key]
				check(clip.actor == hero and str(clip.file).begins_with(hero+"_v31_"), hero+" never borrows another actor or an early generic TTS file")
				var performed_event: String = "heavy" if event == "guard" else event
				var identity: String = audio.speech_manifest.hero_voice_profiles[hero].description
				check(clip.backend == "Qwen3-TTS-12Hz-1.7B-CustomVoice" and clip.performance_event == performed_event and clip.identity_description == identity and clip.speaker == audio.speech_manifest.hero_voice_profiles[hero].speaker, hero+" directs the correct performance with its fixed voice identity")
				check(clip.instruction == identity+" Fixed speaker preset "+str(audio.speech_manifest.hero_voice_profiles[hero].speaker)+". Performance: "+str(audio.speech_manifest.performance_delivery[performed_event]), hero+" uses a real event-specific generation instruction")
				var stream: AudioStreamWAV = audio._speech_streams[key]
				var digest := HashingContext.new()
				digest.start(HashingContext.HASH_SHA256)
				digest.update(stream.data)
				var hash := digest.finish().hex_encode()
				check(not pcm_owners.has(hash) or pcm_owners[hash] == hero, hero+" owns its actual PCM independently")
				pcm_owners[hash] = hero
				check(not stream.stereo and stream.mix_rate == 22050 and absf(stream.get_length()-float(clip.seconds)) < .001, hero+" cue length matches native playback")
				if event in ["attack","heavy","hurt","guard"]:
					check(stream.get_length() >= .30 and stream.get_length() <= .50, hero+" short cue has a complete compact duration")
				if not seen.has(key): seen.append(key); active += 1
			var last := ""
			for index in range(pool.size()*2):
				audio.stop_speech()
				audio.play_character(hero,event,1,true)
				check(pool.has(audio.last_spoken) and audio._speech_players.hero1.stream == audio._speech_streams[audio.last_spoken], hero+" event reaches its own native channel")
				check(pool.size() == 1 or last != audio.last_spoken, hero+" does not repeat adjacent short takes")
				check(audio._speech_players.hero1.pitch_scale == 1.0, hero+" identity is in the recording rather than a runtime pitch disguise")
				last = audio.last_spoken
	check(active == 96 and pcm_owners.size() == 96, "Six complete heroes have ninety-six unique recordings")
	check(references.size() == 6 and references.all(func(hash): return references.count(hash) == 1), "Every hero has a different reference recording")
	check(speakers.size() == 6 and speakers.all(func(speaker): return speakers.count(speaker)==1),"Six characters use six fixed speaker identities")
	for attacker in Battle.HEROES:
		for victim in Battle.HEROES:
			audio.stop_speech()
			audio.play_event({"type":"swing","actor_kind":attacker,"actor_slot":0,"action":"light","combo":3})
			var attacking: AudioStream = audio._speech_players.hero0.stream
			audio.play_event({"type":"hit","actor_kind":attacker,"actor_slot":0,"target_kind":victim,"target_slot":1})
			check(audio._speech_players.hero0.playing and audio._speech_players.hero0.stream == attacking and audio._speech_players.hero1.playing, "Co-op attacker and victim keep independent channels: "+attacker+" / "+victim)
			check(audio.speech_manifest.actors[victim].hurt.has(audio.last_spoken), "Damage always uses the victim's voice")
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/v27/manifest.json"))
	for actor in previous.actors:
		if actor in Battle.HEROES: continue
		check(audio.speech_manifest.actors[actor] == previous.actors[actor], "Existing enemy voice route remains intact: "+actor)
	check(audio.speech_manifest.boss_intros == previous.boss_intros and audio.speech_manifest.stage_boss_intros == previous.stage_boss_intros, "Boss dialogue and timing metadata remain intact")
	audio.stop_speech()
	audio.queue_free()
	await process_frame
	print("VOICE V31 %s: %d checks, %d failures; human audition remains separate" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
