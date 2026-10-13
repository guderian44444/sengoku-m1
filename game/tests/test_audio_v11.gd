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

func bass_fraction(stream: AudioStreamWAV) -> float:
	var filtered := 0.0
	var bass := 0.0
	var total := 0.0
	for offset in range(0, stream.data.size(), 2):
		var sample := stream.data.decode_s16(offset) / 32768.0
		filtered = lerpf(filtered, sample, 0.055)
		bass += filtered * filtered
		total += sample * sample
	return bass / maxf(total, 0.000001)

func run() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	await process_frame
	check(audio.speech_manifest.version in ["0.11","0.14","0.15","0.27","0.30"], "Expressive combat voices are installed")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/v11/manifest.json"))
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/v10/manifest.json"))
	var updated := 0
	var retained := 0
	for key in legacy.clips:
		var clip: Dictionary = legacy.clips[key]
		if clip.get("backend", "") == "Qwen3-TTS-12Hz-1.7B-VoiceDesign":
			updated += 1
			check(clip.instruction.contains("Shout") or clip.instruction.contains("shouted") or clip.instruction.contains("Shout".to_lower()), "Combat voice has delivery instructions")
			check(clip.seconds > 0.08 and clip.seconds < (4.0 if clip.event == "special" else 2.0), "Combat shout is compact")
			check(FileAccess.get_file_as_bytes("res://audio/v11/" + clip.file) != FileAccess.get_file_as_bytes("res://audio/v10/" + previous.clips[key].file), "Combat WAV was actually regenerated")
		else:
			retained += 1
			check(clip.file == "../v10/" + previous.clips[key].file and clip.seconds == previous.clips[key].seconds, "Existing dialogue keeps the original clip and timing")
	check(updated == 48, "Every hero and miniboss attack/special was resynthesized")
	check(retained == 78 and audio.speech_manifest.boss_intros == previous.boss_intros, "All existing dialogue and boss intro synchronization are preserved")
	for hero in Battle.HEROES:
		var sim := Battle.new()
		sim.reset_training(hero, "dummy", "mori")
		var fighter: Dictionary = sim.state.fighters[0]
		for combo in range(1, 4):
			audio.stop_speech()
			sim.state.events.clear()
			fighter.combo = combo
			sim._begin(fighter, "light")
			var events: Array = sim.state.events.filter(func(event): return event.type == "swing")
			check(events.size() == 1 and events[0].combo == combo, "Real battle event identifies combo stage")
			audio.play_event(events[0])
			check(audio._speech_players.hero0.playing == (combo == 3), hero + " only voices the final light hit")
		for action in ["heavy", "charged", "charged_upper", "charged_slam", "mixed_finisher", "mixed_rising"]:
			audio.stop_speech()
			audio.play_event({"type":"swing", "actor_kind":hero, "actor_slot":0, "action":action,"heavy_combo":2})
			check(audio._speech_players.hero0.playing and audio.speech_manifest.actors[hero].heavy.has(audio.last_spoken), hero + " voices " + action)
		for action in ["heavy", "ground_slam", "upper_heavy", "air_heavy", "dash_heavy", "rising", "low_sweep", "dash_strike", "air_light", "counter_cut"]:
			audio.stop_speech()
			audio.play_event({"type":"swing", "actor_kind":hero, "actor_slot":0, "action":action})
			check(not audio._speech_players.hero0.playing, hero + " keeps only weapon SFX for ordinary " + action)
		audio.play_event({"type":"special", "actor_kind":hero, "actor_slot":0})
		check(audio.speech_manifest.actors[hero].special.has(audio.last_spoken), hero + " shouts the move name")
	audio.stop_speech()
	audio.play_event({"type":"swing", "actor_kind":"nobunaga", "actor_slot":0, "action":"light", "combo":3})
	audio.play_event({"type":"swing", "actor_kind":"oichi", "actor_slot":1, "action":"heavy","heavy_combo":2})
	check(audio._speech_players.hero0.playing and audio._speech_players.hero1.playing, "Both local players can shout independently")
	for faction in Battle.FACTIONS:
		audio.stop_speech()
		audio.play_event({"type":"swing", "actor_kind":"boss", "actor_faction":faction, "action":"boss_thrust"})
		check(audio.speech_manifest.actors["boss_" + faction].attack.has(audio.last_spoken), "Miniboss basic attacks use short effort cries")
		audio.play_event({"type":"swing", "actor_kind":"boss", "actor_faction":faction, "action":"boss_slam"})
		check(audio.speech_manifest.actors["boss_" + faction].special.has(audio.last_spoken), "Miniboss specials interrupt with a move name")
	for variant in range(Audio.IMPACT_VARIANTS):
		var light: AudioStreamWAV = audio._impact_sounds.hit[variant]
		var heavy: AudioStreamWAV = audio._impact_sounds.heavy_hit[variant]
		check(heavy.get_length() > light.get_length() * 1.5, "Heavy impact has a longer body")
		check(bass_fraction(heavy) > bass_fraction(light) * 1.5, "Heavy impact has substantially more bass energy")
		for kind in ["hit", "heavy_hit"]:
			var stream: AudioStreamWAV = audio._impact_sounds[kind][variant]
			check(stream.data == audio._synthesize(kind, variant).data, "Impact generation is reproducible")
			var peak := 0
			for offset in range(0, stream.data.size(), 2): peak = maxi(peak, absi(stream.data.decode_s16(offset)))
			check(peak > 1000 and peak < 32767, "Impact is audible and unclipped")
			for other in range(variant):
				check(stream.data != audio._impact_sounds[kind][other].data, "Five distinct impact waveforms per weight")
	for kind in ["hit","heavy_hit"]:
		var sequence: Array[int] = []
		for index in range(15):
			audio.play_event({"type":kind, "target_kind":"dummy"})
			check(sequence.is_empty() or sequence.back() != audio.last_impact_variant, "Each weight selects without adjacent repeats")
			sequence.append(audio.last_impact_variant)
		for start in [0,5,10]:
			var bag := sequence.slice(start,start+5)
			bag.sort()
			check(bag == [0,1,2,3,4], "Every random bag includes all five textures")
	audio.stop_speech()
	for player in audio._voices: player.stop()
	await create_timer(.1).timeout
	audio.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("V11 AUDIO: %d checks, %d failures; delivery still requires listening review" % [checks, failures])
	quit(0 if failures == 0 else 1)
