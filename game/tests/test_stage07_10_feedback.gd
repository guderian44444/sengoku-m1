extends SceneTree
const Battle=preload("res://core/battle.gd")
const Stage=preload("res://core/stage07_10_encounter.gd")
const View=preload("res://render/battle_view.gd")
const Audio=preload("res://render/combat_audio.gd")
const Wire=preload("res://core/wire.gd")
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	assert(ok,label)
func clean(sim) -> void:
	sim.state.intro={};sim.state.expedition.pending=[];sim.state.expedition.wave=2
	sim.state.expedition.hazards=[];sim.state.expedition.next_reinforce=1000000
	sim.state.expedition.hold_ticks=0
	sim.state.fighters=sim.state.fighters.filter(func(f):return f.team==0)
	for p in sim.state.props: p.hp=0;p.broken=true
func run() -> void:
	var sim := Battle.new();sim.reset_campaign("normal",1,["nobunaga"],7);clean(sim)
	var hero: Dictionary=sim.state.fighters[0]
	hero.x=400;hero.y=480;hero.invuln=0;hero.z=0
	var enemy := Stage.spawn(sim,"spear",420,480);enemy.entering=false;enemy.armor=0
	sim.state.fighters.append(enemy)
	var hero_hp: int=hero.hp;var enemy_hp: int=enemy.hp
	Stage.hazard(sim,"rock",Vector2(410,480),80,40,48,24)
	for tick in 47: Stage.tick_hazards(sim)
	check(hero.hp==hero_hp and enemy.hp==enemy_hp,"Falling rocks warn both sides before contact")
	Stage.tick_hazards(sim)
	check(hero.hp<hero_hp and enemy.hp<enemy_hp,"The same boulder damages player and enemy")
	check(Wire.valid_snapshot(sim.state),"Friendly rock damage keeps a valid network state")
	sim.reset_campaign("normal",1,["nobunaga"],9)
	var identities: Array=sim.state.expedition.civilians.map(func(c):return c.kind)
	Stage.admit(sim);sim.state.tick=20;Stage.admit(sim)
	for tick in 1500: Stage.evacuate_civilians(sim)
	check(sim.state.expedition.rescued==3,"Civilian families flee around intact cover during combat")
	check(sim.state.expedition.civilians.map(func(c):return c.kind)==identities,"Running never changes civilian identities")
	var view := View.new();root.add_child(view)
	var troop_sets: Dictionary=view._stage0710_art.troops()
	check(troop_sets.size()==15,"Five newly authored troop roles exist for each of three factions")
	for key in troop_sets:
		var actor: Dictionary=troop_sets[key]
		check(actor.frames.size()==24,"Each troop has a complete consistent set of 24 poses")
		var unique := {}
		for i in actor.frames.size():
			var frame: Dictionary=view._stage0710_art.actor_frame(key,i)
			var signature := str(actor.frames[i].path)+str(frame.region)
			check(not unique.has(signature),"Every troop pose has its own authored source region")
			unique[signature]=true
			check(frame.region.size.y/float(frame.body_height)<1.8 and frame.region.size.x/float(frame.body_height)<2.8,"A pose contains one body, without joined neighbors")
			check(Rect2(Vector2.ZERO,frame.texture.get_size()).encloses(frame.region),"No troop pose samples outside its image")
	for chapter in Stage.Data.STAGES:
		sim.reset_campaign("normal",1,["nobunaga"],chapter)
		view.state=sim.state
		check(view._npc_samples(5.0).is_empty(),"New maps replace legacy ambient walkers with consistently drawn fleeing civilians")
		if chapter!=9:
			var first: Array=view._stage0710_art.civilian_samples(sim.state)
			check(first.size()==3,"Mountain, castle and retreat maps retain consistently drawn local civilians")
			check(sim.state.expedition.civilians.is_empty() and Stage.Data.valid_world(sim.state.expedition),"Decorative civilian sampling never mutates the authoritative world")
			var later: Dictionary=sim.state.duplicate(true);later.tick+=120
			var fleeing: Array=view._stage0710_art.civilian_samples(later)
			check(fleeing.size()==3 and fleeing[0].x>first[0].x and fleeing[0].mode=="run","Local civilians flee once fighting starts")
			later.tick+=2000
			check(view._stage0710_art.civilian_samples(later).is_empty(),"Escaped civilians never wrap around or reappear in the same scene")
		for role in Stage.Data.SOLDIERS:
			var troop := Stage.spawn(sim,role,700,480);troop.entering=false
			sim.state.fighters.append(troop);view.state=sim.state;view._update_motion()
			for action in ["idle","hurt","guard","down","recovering","dead","bow_shot" if role=="archer" else ("gun_shot" if role=="gunner" else ("commander_cut" if role=="raider" else "spear_thrust"))]:
				troop.action=action;troop.action_tick=8
				var sample: Dictionary=view._fighter_animation(troop)
				check(sample.source=="stage0710","All ordinary troop states use the new painted source")
				check(sample.frame_data.texture.get_width()>=1000,"Every normal and hurt state keeps the high resolution source")
			check(View.enemy_display_height(troop)>=160,"New troop scale is calibrated")
	var audio := Audio.new();root.add_child(audio)
	for role in Stage.Data.BOSSES:
		var spec: Dictionary=Stage.Data.BOSSES[role]
		var key := "s%02d_%s_intro"%[int(spec.stage),role]
		sim.boss_intros=audio.speech_manifest.stage_boss_intros
		sim.reset_campaign("normal",1,["nobunaga"],int(spec.stage))
		sim._enter_segment(4 if role in ["inaba","tatsuoki","iwanari","yoshikage"] else 2);sim._start_checkpoint(1)
		check(sim.state.intro.line_key==key and sim.state.intro.line==audio.speech_manifest.clips[key].subtitle,"Authored entrance routes to the correct subtitle and voice")
		check(sim.state.intro.duration>=ceili(audio._speech_streams[key].get_length()*60),"Dialogue remains on screen for the complete voice")
		sim.step([{"dx":0,"dy":0,"buttons":0}])
		audio.play_event(sim.state.events[0])
		check(audio.intro_playing(),"The real entrance event plays its voice")
		audio.stop_speech()
		sim.reset_campaign("normal",1,["nobunaga"],int(spec.stage));clean(sim)
		hero=sim.state.fighters[0];hero.x=300;hero.y=480
		var boss := Stage.spawn(sim,role,1000,480);boss.entering=false;boss.cooldown=0
		sim.state.fighters.append(boss)
		Stage.ai(sim,boss,hero)
		check(Stage.Data.ACTIONS.has(boss.action) and Stage.Data.ranged(Stage.Data.ACTIONS[boss.action]),"Every boss attacks at range instead of only running: "+role)
		check(audio._speech_streams.has(key) and audio._speech_streams[key].get_length()>2,"Every boss has a decoded full entrance line")
		boss.x=600;hero.x=540;boss.hp=10000;boss.max_hp=10000;boss.armor=0
		boss.expedition_combo=0;boss.expedition_break_ready=0;boss.expedition_break_until=0
		for hit in 3:
			sim.state.tick=100+hit*20;boss.invuln=0
			check(sim._damage(boss,1,hero.id,false,true,false,false,hero.x,hero.y,"light"),"Light combo lands before the break")
		check(boss.expedition_break_until>sim.state.tick and boss.action_tick==int(Stage.Data.ACTIONS[boss.action].hits[0])-18,"Three hits trigger a fast distinct counter: "+role)
		check(not Stage.accepts_damage(sim,boss,hero.id,hero.x,hero.y,false,"light"),"Repeated front light cannot interrupt the counter")
		check(Stage.accepts_damage(sim,boss,hero.id,boss.x-boss.face*80,boss.y,false,"light"),"Counter has a rear opening")
		check(Stage.accepts_damage(sim,boss,hero.id,hero.x,hero.y,true,"charged"),"Charged attacks can break the counter")
		check(Wire.valid_snapshot(sim.state),"Counter fields serialize safely")
		# Hold the fight at point-blank range while sending real repeated light inputs.
		sim.reset_campaign("normal",1,["nobunaga"],int(spec.stage));clean(sim)
		hero=sim.state.fighters[0];hero.y=480
		boss=Stage.spawn(sim,role,700,480);boss.hp=10000;boss.max_hp=10000;boss.entering=false;boss.cooldown=0
		sim.state.fighters.append(boss)
		var responses := 0
		for tick in 720:
			hero.hp=hero.max_hp;hero.x=boss.x-65;hero.y=boss.y;hero.face=1
			sim.step([{"dx":0,"dy":0,"buttons":Battle.LIGHT if tick%8==0 else 0}])
			responses+=sim.state.events.filter(func(e):return e.type in ["hit","heavy_hit"] and e.actor==boss.id and e.target==hero.id).size()
		check(boss.expedition_break_ready>0 and responses>0,"Continuous real light pressure still allows a boss counterattack: "+role)
		print("PRESSURE_PASS ",role," boss_hits=",responses)
	view.queue_free();audio.queue_free();await process_frame
	print("STAGE07_10_FEEDBACK_PASS %d checks"%checks);quit()
