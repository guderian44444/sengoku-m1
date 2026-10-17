extends SceneTree
const Main = preload("res://main.gd")
const Audio = preload("res://render/combat_audio.gd")
const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0

class App extends Main:
	func _set_game_focus(_focused: bool) -> void: pass

func _initialize(): run.call_deferred()
func check(ok: bool, label: String):
	checks += 1
	assert(ok,label)

func run():
	var app := App.new()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.set_physics_process(false)
	app.audio.stop_music()
	var audio = app.audio
	var count := 0
	for cue in Audio.weapon_banks():
		var bank: Dictionary = Audio.weapon_banks()[cue]
		check(audio._sound_variants[cue].size()==bank.variants.size(),"Actual bank length: "+cue)
		for i in range(bank.variants.size()):
			var take: Dictionary = bank.variants[i]
			var stream: AudioStreamWAV = audio._sound_variants[cue][i]
			check(FileAccess.get_sha256(Audio.WEAPONS_V3_ROOT+take.file)==take.sha256,"Unmodified approved WAV: "+take.file)
			check(stream.mix_rate==48000 and not stream.stereo and stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.get_length()>.04,"Native decoder: "+take.file)
			count += 1
		if bank.loop:
			check(FileAccess.get_sha256(Audio.WEAPONS_V3_ROOT+bank.runtime_loop)==bank.runtime_loop_sha256,"Derived loop checksum: "+cue)
			var loop := AudioStreamWAV.load_from_file(Audio.WEAPONS_V3_ROOT+bank.runtime_loop)
			check(absf(audio._sound_variants[cue][0].get_length()-loop.get_length()-.02)<.0001,"20 ms overlap keeps original bank untouched")
		var previous := -1
		for cycle in range(3):
			var seen := {}
			for i in range(bank.variants.size()):
				var selected: int = audio._choose_variant("v40:"+cue,bank.variants.size())
				check(bank.variants.size()==1 or selected!=previous,"No adjacent variant repeats")
				seen[selected]=true; previous=selected
			check(seen.size()==bank.variants.size(),"Whole bank heard before refill")
	check(count==98,"All 98 new takes decode")
	app.sim.reset_training("ieyasu","dummy")
	var iaido: Dictionary = app.sim.state.fighters[0]
	iaido.action="charged"
	app.sim.state.events=[]
	app.sim._combat_contact_v33(iaido,"contact")
	var draws := 0
	for event in app.sim.state.events:
		if Audio.sound_for_event(event)=="sword_draw": draws+=1
	check(draws==1,"Iaido and its blade wave share one audible draw")
	for cue in Audio.V3_ALIASES:
		check(audio._sound_variants[cue]==audio._sound_variants[Audio.V3_ALIASES[cue]],"Old physical cue is now the new bank: "+cue)
	for row in [
		[{"type":"gunshot","actor_team":0},"musket_player_shot"], [{"type":"gunshot","actor_team":1},"musket_enemy_shot"],
		[{"type":"hit","weapon":"bullet","material":"armor"},"musket_hit_armor"], [{"type":"hit","weapon":"arrow","material":"armor"},"knife_hit_armor"],
		[{"type":"weapon_swing","weapon":"spear","weapon_id":"staff_approved03_naginata"},"polearm_sweep"],
		[{"type":"hit","weapon":"spear","weapon_id":"staff_approved03_naginata"},"polearm_hit_flesh"],
		[{"type":"prop_hit","weapon":"arrow","material":"wood"},"arrow_hit_wood"], [{"type":"prop_hit","weapon":"sword","material":"wood"},"wood_hit"],
		[{"type":"shield_hit","contact":"held_body","weapon":"sword"},"hit"], [{"type":"shield_hit","contact":"armor_absorb"},"shield_block"],
		[{"type":"weapon_swing","actor_kind":"ieyasu","action":"charged"},"sword_draw"],
		[{"type":"landing","body":true,"wet":true},"splash"], [{"type":"landing","body":true},"body_land"],
		[{"type":"heavy_hit","action":"throw"},""], [{"type":"hit","sound_suppressed":true},""],
		[{"type":"heavy_hit","spin_finish":true},"spin_finish"], [{"type":"run_bump"},"body_collision"]]:
		check(Audio.sound_for_event(row[0])==row[1],"Material/action route: "+str(row))
	for hero in Battle.CombatMoves.HEROES:
		app.sim.reset_training(hero,"dummy")
		var actor: Dictionary = app.sim.state.fighters[0]
		var target: Dictionary = app.sim.state.fighters[1]
		actor.action="grab_hit_1";actor.grab_target=target.id;target.held_by=actor.id
		app.sim._combat_contact_v33(actor,"contact_normal_hit")
		var contact: Dictionary = app.sim.state.events[-1]
		check(Audio.sound_for_event(contact)==("headbutt_hit" if hero in ["nobunaga","ieyasu","mitsuhide"] else "knee_hit"),"Live grab contact: "+hero)
		check(contact.attack_id==actor.attack_id and contact.contact=="held_body","Contact preserves attack and held-body semantics")
		check(Wire.valid_snapshot(app.sim.state),"Audio metadata round trips in co-op")
	app.sim.reset_training("nobunaga","dummy")
	app.sim.state.props.clear()
	var player: Dictionary = app.sim.state.fighters[0]
	var victim: Dictionary = app.sim.state.fighters[1]
	app.sim._damage(victim,10,player.id,false,true,true,false,NAN,NAN,"light",24,"bullet")
	app.sim._apply_element(victim,"fire",player.id)
	check(app.sim.state.events[-1].type=="element_hit" and Audio.sound_for_event(app.sim.state.events[-1])=="element_fire_hit","Actual elemental contact emits one layer")
	check(Wire.valid_snapshot(app.sim.state),"Element events accepted over network")
	var malformed: Dictionary = app.sim.state.duplicate(true)
	malformed.events[-1].element="unknown"
	check(not Wire.valid_snapshot(malformed),"Unknown network element rejected")
	var fx = app.view._fx
	app.view.state=app.sim.state
	fx.reset_scene();fx.set_paused(false);fx.muted=false
	app.sim.state.events=[];app.sim.state.tick=100
	player.action="charge";victim.burn=0
	fx.sync(app.sim.state,app.view)
	check(fx.sound.loops.size()==1,"Exactly one charge loop")
	var loop_player: AudioStreamPlayer = fx.sound.loops.values()[0]
	check(loop_player.stream.data==AudioStreamWAV.load_from_file(Audio.WEAPONS_V3_ROOT+"charge_hold_loop-loop.wav").data,"Charge uses the supplied bank with overlap seam")
	fx.sound._process(.03)
	check(is_equal_approx(loop_player.get_meta("fade"),.5),"Loop fades in over 60 ms")
	fx.set_paused(true);fx.sound._process(.2)
	check(loop_player.stream_paused and is_equal_approx(loop_player.get_meta("fade"),.5),"Pause freezes loop playback and envelope")
	fx.set_paused(false)
	player.action="idle";app.sim.state.tick+=1
	fx.sync(app.sim.state,app.view)
	check(fx.sound.loops.is_empty() and loop_player.get_meta("stopping"),"Cancel detaches and fades loop")
	fx.sound._process(.061)
	check(not fx.sound.players.has(loop_player),"No loop survives cancellation fade")
	player.action="charged";player.action_tick=20;app.sim.state.tick+=1
	fx.sync(app.sim.state,app.view)
	check(fx.continuous.get("spin:%d" % player.id)=="spin_swing_loop","Active rotation starts spin loop")
	player.hp=0;app.sim.state.tick+=1;fx.sync(app.sim.state,app.view);fx.sound._process(.061)
	check(fx.continuous.is_empty() and fx.sound.loops.is_empty(),"Death clears sustained sound")
	player.hp=100;player.action="charge";app.sim.state.tick+=1;fx.sync(app.sim.state,app.view)
	fx.reset_scene()
	check(fx.sound.players.is_empty() and fx.charges.is_empty(),"Scene reset stops all loops immediately")
	for weapon in ["bullet","needle","sword"]:
		var event := {"id":1000+checks,"type":"hit","weapon":weapon,"actor":player.id,"target":victim.id,"x":victim.x,"y":victim.y}
		check(not fx.accept_event(event,app.sim.state,app.view) and fx.sound.players.is_empty(),"Shared impact keeps visuals but gives audio to the new bank: "+weapon)
		var index: int = audio._next_voice
		audio.play_event(event)
		check(audio._voices[index].playing and audio._voices[index].stream.mix_rate==48000,"Physical player uses new WAV")
	var shot := {"id":2000,"type":"gunshot","weapon":"bullet","actor":player.id,"actor_team":0,"x":player.x,"y":player.y}
	check(not fx.accept_event(shot,app.sim.state,app.view) and fx.sound.players.is_empty(),"Muzzle VFX cannot double the new musket report")
	audio.play_event(shot)
	check(audio.last_sound=="musket_player_shot" and audio._sound_variants[audio.last_sound].size()==3,"Player musket uses all three delivered takes")
	app.queue_free()
	await process_frame
	print("AUDIO V40 PASS: %d checks; listening and hardware acceptance remain separate" % checks)
	quit()
