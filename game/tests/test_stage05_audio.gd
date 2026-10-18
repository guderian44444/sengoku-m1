extends SceneTree
const Data = preload("res://core/stage05_data.gd")
const S5 = preload("res://core/stage05_encounter.gd")
const Battle = preload("res://core/battle.gd")
const Audio = preload("res://render/combat_audio.gd")
const S5Audio = preload("res://render/stage05_audio.gd")
var checks := 0
func check(ok: bool, label: String) -> void:
	checks+=1;assert(ok,label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var audio := Audio.new();root.add_child(audio);await process_frame
	var engine: S5Audio=audio._ikki_audio
	var variants := {}
	for row in Data.read("audio/event-map.json"):
		for name in row.variants:
			variants[name]=true
			check(engine.stream("audio/wav/"+str(name)+".wav").get_length()>0,"SFX decodes")
	check(variants.size()==60,"60 unique supplied effects")
	check(Data.read("audio/event-map.json").size()==21,"21 bound effect events")
	for row in Data.read("audio/voice-event-map.json"):
		check(engine.stream("audio/"+str(row.wav)).get_length()>0,"voice decodes")
	check(Data.read("audio/voice-event-map.json").size()==7,"seven supplied voices")
	for key in Data.MUSIC:
		var stream := S5Audio.music(key)
		check(stream!=null and stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and stream.loop_end>stream.loop_begin,"music loop samples: "+key)
	var stomp := engine.stream("audio/tracks/kusei_stomp_v2_voiceA_full_5p65s.wav")
	check(absf(stomp.get_length()-5.65)<.01,"natural stomp tail remains 5.65s")
	audio.play_event({"type":"stage05_audio","cue":"kusei_stomp_full","actor":99,"id":1})
	var ongoing: AudioStreamPlayer=engine.players.back()
	audio.play_event({"type":"stage05_audio","cue":"kusei_fudo","actor":99,"id":2})
	check(engine.players.size()==1 and ongoing.stream==stomp,"voice cannot cut or overlap mixed stomp track")
	audio.set_music_paused(true);check(ongoing.stream_paused,"pause includes stage-five speech")
	audio.set_music_paused(false);audio.stop_speech()
	for seq in 5:
		var before: int=int(engine.last_choices.get("s05.farmer.hoe_swing",-1))
		audio.play_event({"type":"stage05_audio","cue":"s05.farmer.hoe_swing","actor":10,"id":3})
		check(engine.last_choices["s05.farmer.hoe_swing"]!=before,"no immediate repeated variation")
	# Check sound contact triggers through actual hit resolution, including a miss.
	for role in ["militia","monk"]:
		for contact in [false,true]:
			var sim := Battle.new();sim.reset_campaign("normal",1,["nobunaga"],5)
			var hero: Dictionary=sim.state.fighters[0]
			var enemy := S5.spawn(sim,role,600,500)
			sim.state.fighters=[hero,enemy];hero.y=500;hero.x=650 if contact else 1000
			var action := "s05_militia_attack" if role=="militia" else "s05_monk_quick_attack"
			S5.start(sim,enemy,action,hero);enemy.action_tick=16 if role=="militia" else 9
			S5.attack(sim,enemy)
			var cue := "s05.farmer.hoe_impact" if role=="militia" else "s05.monk.naginata_impact"
			check(sim.state.events.any(func(e):return e.get("cue","")==cue)==contact,"impact only after collision "+role)
	for asset in ["rice","wood","jar","militia_ragged"]:
		var sim := Battle.new();sim.reset_campaign("normal",1,["nobunaga"],5)
		var prop: Dictionary=sim.state.props[0];prop.s05_asset=asset
		sim._damage_prop(prop,1000,sim.state.fighters[0].id)
		var heard := []
		for tick in range(1,38):
			sim.state.tick=tick;sim.state.events=[];S5.tick(sim)
			for event in sim.state.events:
				if event.get("type","")=="stage05_audio": heard.append(tick)
		check(heard==([8,36] if asset=="militia_ragged" else [6]),"authored destruction sound timing "+asset)
	print("STAGE05_AUDIO_PASS %d checks; decoding/routing/timing, not a listening review"%checks)
	audio.queue_free();await process_frame;quit()
