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
	check(audio.speech_manifest.actors.size() >= 19, "Six heroes, soldiers and twelve boss voices remain installed")
	check(audio._speech_streams.size() == audio.speech_manifest.clips.size(), "Every Japanese line loads into a WAV stream")
	for key in audio._speech_streams:
		var stream: AudioStreamWAV = audio._speech_streams[key]
		check(stream.get_length() > 0.08 and stream.get_length() < 18, "Bounded speech duration: " + key)
		check(absf(stream.get_length() - float(audio.speech_manifest.clips[key].seconds)) < 0.04, "PCM length matches intro metadata: " + key)
		var peak := 0
		for offset in range(0, stream.data.size(), 2): peak = maxi(peak, absi(stream.data.decode_s16(offset)))
		check(peak > 600 and peak < 32767, "Non-silent unclipped voice: " + key)
	for hero in Battle.HEROES:
		for event in ["attack", "hurt", "guard", "heavy", "special", "victory", "defeat"]:
			audio.stop_speech()
			audio.play_character(hero, event)
			check(audio.speech_manifest.actors[hero][event].has(audio.last_spoken), hero+" speaks "+event)
	audio.stop_speech()
	audio.play_event({"type":"swing", "actor_kind":"hideyoshi", "actor_slot":1, "action":"light", "combo":3})
	check(audio._speech_players.hero1.playing and not audio._speech_players.hero0.playing, "Co-op hero speech channels are independent")
	audio.play_event({"type":"hit", "target_kind":"hideyoshi", "target_slot":1})
	check(audio.speech_manifest.actors.hideyoshi.hurt.has(audio.last_spoken), "Damage interrupts the target's attack shout with pain")
	audio.play_character("soldier", "attack")
	audio.play_event({"type":"shield_hit", "target_kind":"soldier"})
	check(audio.speech_manifest.actors.soldier.hurt.has(audio.last_spoken), "A held soldier cries when the meat shield takes damage")
	for faction in Battle.FACTIONS:
		var profile: Dictionary=Battle.BOSS_PROFILES[Battle.FACTIONS[faction].boss]
		var special_actions: Array=profile.actions.filter(func(action):return action not in ["boss_thrust","boss_double"] and not (faction == "mori" and action in ["boss_sweep","boss_smash"]))
		check(not special_actions.is_empty(),"Each boss has voiced special attacks")
		audio.stop_speech()
		audio.play_event({"type":"swing","actor_kind":"boss","actor_faction":faction,"action":special_actions[0]})
		check(audio.speech_manifest.actors["boss_" + faction].special.has(audio.last_spoken),faction+" special speech routes to own line")
	for faction in audio.speech_manifest.boss_intros:
		var intro: Dictionary = audio.speech_manifest.boss_intros[faction]
		audio.play_event({"type":"boss_intro", "line_key":intro.line_key})
		check(audio.intro_playing() and audio.last_spoken == intro.line_key, faction+" plays its own intro")
		var token: String=audio._intro_token
		audio.play_event({"type":"boss_intro", "line_key":intro.line_key})
		check(audio._intro_token==token,"Reliable/snapshot duplicate intro is deduplicated")
		audio.play_character("nobunaga", "special", 0, true)
		check(audio.last_spoken == intro.line_key, "Hero attacks cannot interrupt boss speech")
		audio.stop_speech()
		check(not audio.intro_playing(), "Reset stops introduction")
	var sim := Battle.new()
	sim.boss_intros = audio.speech_manifest.boss_intros.duplicate(true)
	sim.reset_training("nobunaga", "boss", "mori")
	sim.step([{"dx":1,"dy":0,"buttons":1}])
	var intro_event: Dictionary = sim.state.events.filter(func(e):return e.type=="boss_intro")[0]
	audio.play_event(intro_event)
	var before: Dictionary = sim.state.fighters[0].duplicate(true)
	for i in range(10): sim.step([{"dx":1,"dy":0,"buttons":1}])
	check(sim.state.fighters[0].x == before.x and sim.state.fighters[0].hp == before.hp, "Real voice event freezes combat")
	check(audio.intro_playing(), "Audio remains in progress while combat is frozen")
	audio.stop_speech()
	audio.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("V10 AUDIO: %d checks, %d failures; listening requires human review" % [checks, failures])
	quit(0 if failures == 0 else 1)
