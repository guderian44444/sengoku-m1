extends SceneTree

const Main = preload("res://main.gd")
const Audio = preload("res://render/combat_audio.gd")
const Battle = preload("res://core/battle.gd")
const Moves = preload("res://core/combat_moves.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Equipment = preload("res://core/equipment.gd")
var checks := 0

class App extends Main:
	func _set_game_focus(_focused: bool) -> void: pass

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok, label)

func _initialize() -> void: run.call_deferred()

func samples(audio: Audio) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Audio.WEAPON_AUDIO_ROOT+"manifest.json"))
	var unique := {}
	for cue in Audio.SAMPLED_CUES:
		var hashes := {}
		for take in manifest.cues[cue].variants:
			var path: String = Audio.WEAPON_AUDIO_ROOT+str(take.file)
			check(FileAccess.get_sha256(path)==take.sha256,"Recorded source hash: "+path)
			var stream := AudioStreamWAV.load_from_file(path)
			check(not stream.stereo and stream.mix_rate==44100 and stream.format==AudioStreamWAV.FORMAT_16_BITS,"PCM format: "+path)
			check(stream.get_length()>.05 and stream.get_length()<.8,"Short responsive foley: "+path)
			hashes[take.sha256]=true
			unique[take.file]=true
		check(hashes.size()==5,"Five different takes: "+cue)
		var previous := -1
		for cycle in range(4):
			var seen := {}
			for i in range(5):
				var selected := audio._choose_variant("test:"+cue,5)
				check(selected!=previous,"No adjacent repeated sound at bag boundary")
				previous=selected
				seen[selected]=true
			check(seen.size()==5,"Every take plays before recycling")
	check(unique.size()==75,"75 unique recordings, aliases reuse the same WAVs")
	for row in [
		["weapon_swing","sword","light","sword_whoosh"], ["weapon_swing","sword","charged","sword_heavy_whoosh"],
		["weapon_swing","blunt","heavy","blunt_whoosh"], ["weapon_swing","spear","light","spear_wind"],
		["hit","sword","","hit"], ["heavy_hit","sword","","heavy_hit"],
		["hit","blunt","","blunt_hit"], ["heavy_hit","blunt","","blunt_heavy_hit"],
		["hit","spear","","spear_hit"], ["heavy_hit","spear","","spear_heavy_hit"],
		["bow_release","arrow","heavy","bow_release"], ["bow_release","special_arrow","special","bow_heavy_release"], ["bow_release","arrow","charged","bow_heavy_release"],
		["hit","arrow","","arrow_hit"], ["shield_hit","arrow","","shield_hit"],
		["guard","sword","","guard"], ["weapon_swing","sword","boss_sword_wave","sword_air"]]:
		check(Audio.sound_for_event({"type":row[0],"weapon":row[1],"action":row[2]})==row[3],"Foley contract: "+str(row))

func combat() -> void:
	for hero in Moves.HEROES:
		for weapon in Weapons.ids_for(hero):
			var sim := Battle.new()
			sim.reset_training(hero,"dummy")
			sim.state.props.clear()
			var player: Dictionary = sim.state.fighters[0]
			Equipment.equip(player,Equipment.add(player,weapon))
			var target: Dictionary = sim.state.fighters[1]
			target.x=player.x+70; target.y=player.y; target.home_x=target.x; target.home_y=target.y
			target.hp=10000; target.max_hp=10000
			var expected := "kick" if hero=="oichi" else ("spear" if hero=="tadakatsu" else "sword")
			if hero=="mitsuhide": expected="spear" if weapon=="staff_approved03_naginata" or weapon.begins_with("spear_") else ("sword" if weapon.begins_with("sword_") else "blunt")
			sim._begin(player,"light")
			var releases := 0
			var contacts := 0
			for tick in range(65):
				sim.step([{}])
				for event in sim.state.events:
					if event.actor!=player.id: continue
					if event.type=="weapon_swing":
						releases+=1
						check(event.weapon==expected,"Equipped release material: "+hero+"/"+weapon)
					if event.type in ["hit","heavy_hit"]:
						contacts+=1
						check(event.weapon==expected and target.hp<10000,"Only confirmed damage emits contact: "+hero+"/"+weapon)
			check(releases==1 and contacts==1,"One wind and one contact in the live first attack: "+hero+"/"+weapon)
	var sim := Battle.new()
	sim.reset_training("oichi","dummy")
	var player: Dictionary = sim.state.fighters[0]
	player.action="air_heavy"
	sim.state.events.clear()
	sim._combat_contact_v33(player,"contact")
	var releases: Array = sim.state.events.filter(func(e): return e.type=="bow_release")
	check(releases.size()==1,"A three-arrow volley releases the bowstring once")
	var target: Dictionary = sim.state.fighters[1]
	player.action="light"
	sim._damage(target,10,player.id,false,true,true,false,NAN,NAN,"heavy",24,"arrow")
	check(sim.state.events[-1].weapon=="arrow","Delayed arrow impact retains projectile material after owner changes action")
	sim.reset_training("nobunaga","dummy")
	player=sim.state.fighters[0]
	sim.state.fighters=[player]
	sim.state.props.clear()
	player.action="light"
	sim.state.events.clear()
	sim._combat_contact_v33(player,"contact")
	check(sim.state.events.size()==1 and sim.state.events[0].type=="weapon_swing","A whiff has wind without a false hit")

func voices(app: App) -> void:
	var audio: Audio = app.audio
	for hero in Moves.HEROES:
		for event in ["intro","attack","heavy","hurt","special","victory","defeat","boss_defeat"]:
			var pool: Array = audio.speech_manifest.actors[hero][event]
			check(pool.size()==(3 if event in ["attack","heavy","hurt","victory"] else 1),"Complete voice pool: "+hero+"/"+event)
			for key in pool:
				check(audio._speech_streams.has(key) and audio.speech_manifest.clips[key].actor==hero,"Voice belongs to this actor: "+key)
				if hero in ["nobunaga","ieyasu","mitsuhide"]:
					check(key.begins_with(hero+"_v38_"),"Every mature male event uses the repaired performance")
				if hero=="oichi" and (event=="heavy" or event=="attack" and not key.ends_with("_0")):
					check(key.begins_with("oichi_v38_"),"Oichi's specified attacks use the forceful replacement")
				if key.contains("_v38_"):
					var clip: Dictionary = audio.speech_manifest.clips[key]
					check(FileAccess.get_sha256(clip.file)==clip.sha256 and absf(audio._speech_streams[key].get_length()-float(clip.seconds))<.005,"Decoder loads the current replacement recording")
			audio.stop_speech()
			audio.play_character(hero,event,1,true)
			check(audio.last_spoken in pool and audio._speech_players.hero1.playing and audio._speech_players.hero1.pitch_scale==1.0,"Actual 2P speech uses normal playback speed: "+hero+"/"+event)
		for combo in [1,2,3]:
			audio.stop_speech()
			audio.last_spoken=""
			audio.play_event({"type":"swing","actor_kind":hero,"action":"light","combo":combo})
			check((not audio.last_spoken.is_empty())==(combo==3),"Only the final light strike shouts: "+hero)
	app.sim.reset_campaign("normal",1,["nobunaga"],2)
	var found := {}
	for i in range(app.sim._campaign.segments.size()):
		app.sim._enter_segment(i)
		var encounters: Array = app.sim._campaign.segments[i].encounters
		for checkpoint in range(encounters.size()):
			var encounter: Dictionary = encounters[checkpoint]
			if not encounter.has("boss"): continue
			app.sim.state.stage.checkpoint=checkpoint
			app.sim.state.wave=encounter.waves.size()
			app.sim._spawn_segment_wave()
			var intro: Dictionary = app.sim.state.intro
			check(intro.name==encounter.boss.name and not intro.line_key.is_empty() and not intro.blocking,"Named chapter-two introduction is connected: "+encounter.boss.name)
			check(intro.duration>=ceili(audio._speech_streams[intro.line_key].get_length()*60),"Subtitle window covers the spoken line")
			app.sim.step([{}])
			app.last_event=-1
			app._events(app.sim.state.events)
			check(audio.last_spoken==intro.line_key and audio.intro_playing(),"Actual Main event dispatch speaks the boss introduction")
			found[intro.name]=true
			audio.stop_speech()
	check(found.size()==3,"All three chapter-two officers announce themselves")

func ownership(app: App) -> void:
	app.sim.reset_training("nobunaga","dummy")
	app.view._fx.reset_scene()
	app.sim.state.tick=100
	app.sim.state.events=[]
	app.view._fx.sync(app.sim.state,app.view)
	var player: Dictionary = app.sim.state.fighters[0]
	var target: Dictionary = app.sim.state.fighters[1]
	var event := {"id":10001,"type":"hit","weapon":"sword","actor":player.id,"target":target.id,"actor_kind":"nobunaga","target_kind":"dummy","x":target.x,"y":target.y}
	app.sim.state.events=[event]
	app.last_event=-1
	app._events([event])
	check(app.audio.last_sound=="hit" and app.view._fx.sound.players.is_empty() and not app.view._fx.origins.is_empty(),"Physical contact plays once while shared impact visuals remain")
	var cursor: int = app.audio._next_voice
	app._events([event])
	check(app.audio._next_voice==cursor,"Replayed snapshots do not play another impact")
	player.action="charge"
	app.sim.state.tick+=1
	app.sim.state.events=[]
	app.view._fx.sync(app.sim.state,app.view)
	check(app.view._fx.charges.has(player.id),"Charge audio instance starts")
	var cast: String = app.view._fx.charges[player.id]
	player.action="charged"
	app.sim.state.tick+=1
	var release := {"id":10002,"type":"weapon_swing","weapon":"sword","action":"charged","actor":player.id,"x":player.x,"y":player.y}
	app.sim.state.events=[release]
	app._events([release])
	check(app.audio.last_sound=="sword_heavy_whoosh" and not app.view._fx.sound.instances.has(cast) and not app.view._fx.charges.has(player.id),"Charged release stops its loop and plays physical wind once")
	app.audio.play_event({"type":"food_pickup"})
	for i in range(25): app.audio.play_event({"type":"heavy_hit","weapon":"blunt","target_kind":"dummy"})
	check(app.audio._food_player.playing and app.audio._voices.size()==6,"Crowded impacts preserve food confirmation and bounded polyphony")
	check(app.audio.set_category_volume("sfx",0)==OK and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Recorded weapon sounds obey the SFX volume setting")
	app.audio.set_category_volume("sfx",1)

func run() -> void:
	var app := App.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.set_process(false)
	app.testing=false
	samples(app.audio)
	combat()
	voices(app)
	ownership(app)
	app.audio.stop_speech()
	app.audio.stop_music()
	app.queue_free()
	await process_frame
	print("WEAPON AND VOICE V38 PASS: %d checks; subjective listening remains separate" % checks)
	quit()
