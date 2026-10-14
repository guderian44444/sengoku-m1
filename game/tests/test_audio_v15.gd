extends SceneTree

const Audio = preload("res://render/combat_audio.gd")
const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func arena(hero: String = "nobunaga"):
	var sim = Battle.new()
	sim.reset_training(hero)
	sim.state.props = []
	sim.state.drops = []
	sim.state.fighters.resize(1)
	sim.state.fighters[0].x = 1100.0
	return sim

func advance(sim, ticks: int) -> Array:
	var events := []
	for tick in range(ticks):
		sim.step([{"buttons":0,"dx":0,"dy":0}])
		check(Wire.valid_snapshot(sim.get_state()),"Actual release events remain valid for co-op snapshots")
		events.append_array(sim.state.events)
	return events

func test_release() -> void:
	var sim = arena()
	var hero: Dictionary = sim.state.fighters[0]
	hero.combo = 1
	sim._begin(hero,"light")
	check(sim.state.events.any(func(e): return e.type == "swing") and not sim.state.events.any(func(e): return e.type == "weapon_swing"),"Wind does not play at anticipation/voice onset")
	var early := advance(sim,5)
	check(not early.any(func(e): return e.type == "weapon_swing"),"A light sword waits until its real contact tick")
	var release := advance(sim,1)
	check(release.any(func(e): return e.type == "weapon_swing" and e.weapon == "sword" and e.action_tick == 6),"A missed light sword still makes wind at tick6")
	check(not release.any(func(e): return e.type in ["hit","heavy_hit"]),"An empty swing does not create a fake impact")
	sim = arena("oichi")
	hero = sim.state.fighters[0]
	hero.heavy_combo = 1
	sim._begin(hero,"heavy")
	check(not advance(sim,13).any(func(e): return e.type == "bow_release"),"Bow string waits for the actual release")
	release = advance(sim,1)
	check(release.filter(func(e): return e.type == "bow_release" and e.weapon == "arrow").size() == 1,"Oichi releases one arrow sound at tick14")
	# Change the owner state before a real collision: impact must retain projectile material.
	hero.action = "idle"
	var target: Dictionary = sim._make_fighter(1,"dummy",hero.x+180.0,hero.y,1000)
	target.home_x = target.x
	target.home_y = target.y
	sim.state.fighters.append(target)
	var impacts := advance(sim,5).filter(func(e): return e.type in ["hit","heavy_hit"])
	check(impacts.size() == 1 and impacts[0].weapon == "arrow" and Audio.sound_for_event(impacts[0]) == "arrow_hit","A delayed arrow hit keeps its own sound after the owner returns idle")
	for action in ["charged_slam","special","dash_heavy"]:
		sim = arena("oichi")
		hero = sim.state.fighters[0]
		sim._begin(hero,action)
		var ticks: int = 28 if action == "charged_slam" else (Battle.SPECIAL_HIT_TICKS.oichi[0] if action == "special" else 12)
		release = advance(sim,ticks)
		var volley: Array = sim.state.effects.filter(func(e): return e.type == "projectile")
		var sounds: Array = release.filter(func(e): return e.type in ["bow_release","weapon_swing"])
		check(volley.size() >= 3 and sounds.size() == 1,"One simultaneous " + action + " volley creates one release sound")
		check(not sounds.is_empty() and Audio.sound_for_event(sounds[0]) == ("needle_whoosh" if action == "dash_heavy" else "bow_release"),"The volley sound matches its actual weapon")
	# Enemy straight and arcing projectiles both carry material through the collision path.
	for weapon in ["bullet","arrow"]:
		sim = arena()
		hero = sim.state.fighters[0]
		var enemy: Dictionary = sim._make_fighter(1,"gunner" if weapon == "bullet" else "archer",hero.x-190.0,hero.y,100)
		enemy.face = 1
		enemy.action = "gun_shot" if weapon == "bullet" else "bow_shot"
		sim.state.fighters.append(enemy)
		sim.state.events.clear()
		sim._projectile(enemy,10,0,false,weapon)
		check(sim.state.events.size() == 1 and sim.state.events[0].type == ("gunshot" if weapon == "bullet" else "bow_release"),"Enemy projectile emits the matching weapon release")
		enemy.action = "idle"
		for tick in range(90): sim._tick_effects()
		impacts = sim.state.events.filter(func(e): return e.type in ["hit","heavy_hit"])
		check(impacts.size() == 1 and impacts[0].weapon == weapon and Audio.sound_for_event(impacts[0]) == weapon+"_hit","Enemy " + weapon + " impact retains its source despite later owner action")
	sim = arena()
	hero = sim.state.fighters[0]
	var body: Dictionary = sim._make_fighter(1,"soldier",hero.x+160.0,hero.y,100)
	var bystander: Dictionary = sim._make_fighter(1,"dummy",body.x+20.0,body.y,1000)
	body.thrown_by = hero.id
	body.throw_ticks = 8 # Throw recovery has ended while the body is still in flight.
	sim.state.fighters.append_array([body,bystander])
	sim._resolve_throws()
	impacts = sim.state.events.filter(func(e): return e.type in ["hit","heavy_hit"])
	check(hero.action == "idle" and bystander.hp == 978 and impacts.size() == 1,"A thrown body still damages its target after the owner recovers")
	check(impacts.size() == 1 and impacts[0].weapon == "blunt" and Audio.sound_for_event(impacts[0]) == "blunt_hit","A delayed body collision uses blunt impact instead of the owner's idle sword material")

func run() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	await process_frame
	var take_count := 0
	for kind in Audio.EVENT_SOUNDS:
		var variants: Array = audio._sound_variants[kind]
		var count := 5 if kind in ["hit","heavy_hit"] else 3
		check(variants.size() == count,"Requested distinct take count for " + kind)
		var hashes := []
		for variant in range(count):
			var sound: AudioStreamWAV = variants[variant]
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(sound.data)
			var hash := digest.finish().hex_encode()
			check(not hashes.has(hash),"Actual PCM differs for " + kind)
			hashes.append(hash)
			check(sound.data == audio._synthesize(kind,variant).data,"Every sound recipe is reproducible")
			var peak := 0
			var energy := 0.0
			for offset in range(0,sound.data.size(),2):
				var sample := sound.data.decode_s16(offset)
				peak = maxi(peak,absi(sample))
				energy += pow(float(sample)/32768.0,2)
			check(peak > 1000 and peak < 32767 and sqrt(energy/(sound.data.size()/2)) > .018,"Audible bounded PCM for " + kind)
			take_count += 1
		audio._rng.seed = 1234
		var previous := -1
		for bag_index in range(3):
			var heard := []
			for index in range(count):
				audio.play_event({"type":kind,"target_kind":"dummy","actor_kind":"dummy"})
				check(previous != audio.last_sound_variant,"No immediate repeat, including a refilled bag: " + kind)
				previous = audio.last_sound_variant
				heard.append(previous)
			heard.sort()
			check(heard == range(count),"Each random bag covers every take: " + kind)
	check(take_count == 109,"The thirty-five combat, healing and environment categories have 109 real PCM takes")
	var orders := []
	for seed_value in [71,903]:
		audio._rng.seed = seed_value
		audio._choice_bags.clear()
		audio._last_choices.clear()
		var order := []
		for i in range(15): order.append(audio._choose_variant("seed_test",5))
		orders.append(order)
	check(orders[0] != orders[1] and orders[0].slice(0,5) != [0,1,2,3,4],"Selection is randomized rather than a fixed sequential cycle")
	for weapon in ["arrow","bullet","needle","sword"]:
		check(Audio.sound_for_event({"type":"heavy_hit","weapon":weapon}) == (weapon+"_hit" if weapon != "sword" else "heavy_hit"),"Heavy impacts preserve material " + weapon)
	check(Audio.sound_for_event({"type":"swing"}) == "","An anticipation event cannot also trigger an early SFX")
	check(Audio.sound_for_event({"type":"weapon_swing","weapon":"kick"}) == "kick_whoosh","Oichi's real kick uses wind instead of a blade scrape")
	test_release()
	audio.stop_speech()
	check(not audio.speech_playing(),"The victory queue sees silence after stopping speech")
	audio.play_character("oichi","victory")
	check(audio.speech_playing(),"The victory queue detects a hero line")
	audio.stop_speech()
	var intro: Dictionary = audio.speech_manifest.boss_intros.mori
	audio.play_event({"type":"boss_intro","line_key":intro.line_key})
	check(audio.speech_playing(),"The victory queue also respects boss introductions")
	audio.stop_speech()
	if "--require-v15" in OS.get_cmdline_user_args():
		check(audio.speech_manifest.version in ["0.15","0.27","0.30","0.31"],"The final build loads v15 or a complete later voice revision")
	if audio.speech_manifest.version == "0.15":
		var short_count := 0
		var victory_count := 0
		for key in audio.speech_manifest.clips:
			var clip: Dictionary = audio.speech_manifest.clips[key]
			if clip.get("category","") == "short_burst":
				short_count += 1
				var stream: AudioStreamWAV = audio._speech_streams[key]
				check(stream.get_length() >= .30 and stream.get_length() <= .501,"Every new combat shout stays within 0.30–0.50 seconds")
				check(clip.has("raw_source") and clip.has("raw_sha256") and clip.has("sha256") and clip.has("seed"),"New combat takes retain raw provenance and reproducible seeds")
			elif clip.get("category","") == "victory_dialogue":
				victory_count += 1
				check(clip.has("subtitle") and not str(clip.subtitle).is_empty(),"Longer victory dialogue keeps its Traditional Chinese subtitle")
		check(short_count == 45 and victory_count == 6,"Exactly 45 approved combat bursts and six victory lines are installed")
		for actor in audio.speech_manifest.actors:
			var events := ["attack","heavy","hurt","special","guard","defeat"] if actor.begins_with("boss_") or actor in ["soldier","archer","gunner","flag","commander"] else (["attack","heavy","hurt","guard"] if actor in ["oichi","nobunaga"] else [])
			for event in events:
				var pool: Array = audio.speech_manifest.actors[actor][event]
				check(pool.size() >= 3 and pool.all(func(key): return audio.speech_manifest.clips[key].get("category","") == "short_burst"),"Actual combat pool uses only short bursts: " + actor + " " + event)
		check(audio.speech_manifest.actors.oichi.special == audio.speech_manifest.named_calls.oichi,"Oichi's true special keeps its named move call")
		audio.stop_speech()
		audio.play_event({"type":"special","actor_kind":"oichi"})
		check(audio.speech_manifest.named_calls.oichi.has(audio.last_spoken),"Only the true special event selects the named call")
		var previous_shared := ""
		for event in ["heavy","guard","heavy","guard","heavy","guard","heavy"]:
			audio.stop_speech()
			audio.play_character("oichi",event)
			check(audio.last_spoken != previous_shared,"Different events sharing the same pool still never immediately repeat its line")
			previous_shared = audio.last_spoken
		for actor in ["oichi","nobunaga","soldier","archer","gunner","flag","commander","boss_mori","boss_iga"]:
			var event := "victory" if actor in ["oichi","nobunaga"] else "attack"
			var pool: Array = audio.speech_manifest.actors[actor][event]
			check(pool.size() >= 3,"The v15 actor keeps a real varied pool: " + actor)
			var previous := ""
			for i in range(pool.size()*3):
				audio.stop_speech()
				audio.play_character(actor,event)
				check(audio.last_spoken != previous and pool.has(audio.last_spoken),"Voice random bags never immediately repeat: " + actor)
				previous = audio.last_spoken
		for actor in ["archer","gunner","flag","commander"]:
			audio.stop_speech()
			audio.play_event({"type":"swing","actor_kind":actor,"action":"bow_shot"})
			check(audio._speech_players.enemy.playing and audio.speech_manifest.actors[actor].attack.has(audio.last_spoken),"Ordinary enemy kind selects its intended voice without occupying a player channel")
	audio.stop_speech()
	for player in audio._voices: player.stop()
	await create_timer(.1).timeout
	audio.queue_free()
	await process_frame
	await create_timer(.3).timeout
	print("V15 AUDIO: %d checks, %d failures; sound/voice listening remains a human acceptance step" % [checks,failures])
	quit(0 if failures == 0 else 1)
