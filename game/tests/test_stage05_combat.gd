extends SceneTree

const Battle = preload("res://core/battle.gd")
const S5 = preload("res://core/stage05_encounter.gd")
const Wire = preload("res://core/wire.gd")
const Music = preload("res://core/campaign_music.gd")
const Audio = preload("res://render/stage05_audio.gd")
var checks := 0

func check(ok: bool, message: String) -> void:
	checks+=1
	assert(ok,message)

func node(number: int, players: int = 1) -> Battle:
	var sim := Battle.new()
	sim.reset_campaign("normal",players,["nobunaga","oichi"],5)
	for section in 5:
		for checkpoint in sim._campaign.segments[section].encounters.size():
			if int(sim._campaign.segments[section].encounters[checkpoint].node)==number:
				sim._enter_segment(section); sim._start_checkpoint(checkpoint)
				return sim
	return sim

func actor(sim, role: String) -> Dictionary:
	# These isolated move checks start with settled actors; entry is tested separately.
	var found: Array=sim.state.fighters.filter(func(f):return f.get("s05_role","")==role)
	if found.is_empty():
		var f:=S5.spawn(sim,role,float(sim.state.stage.encounter_start)+900,480,false,role=="militia")
		sim.state.fighters.append(f);found.append(f)
	found[0].entering=false;found[0].x=float(sim.state.stage.encounter_start)+900
	return found[0]

func _initialize() -> void:
	var sim := node(12,2)
	var boss := actor(sim,"kusei")
	var hero: Dictionary=sim.state.fighters[0]
	check(boss.max_hp==2040 and actor(node(12),"kusei").max_hp==1200,"fixed solo/coop HP proposal")
	S5.start(sim,boss,"s05_kusei_stomp",hero)
	check(boss.s05_stomp_ready_tick==sim.state.tick+1200,"Stomp reserves a twenty second cooldown")
	for tick in [0,39,93,147,201,255,299]:
		boss.action_tick=tick; boss.invuln=0
		var hp: int=boss.hp
		check(not sim._damage(boss,99,hero.id,true,true,true,true),"five-step direct immunity")
		check(not sim._damage(boss,3,hero.id,false,false),"five-step DOT immunity")
		sim._launch(boss,1,12,8)
		check(boss.hp==hp and boss.z==0 and boss.vz==0,"five-step cannot launch")
	for tick in [39,93,147,201,255]:
		boss.action_tick=tick
		hero.x=boss.x-30; hero.y=boss.y; hero.z=0; hero.action="down"; hero.stun=0; hero.invuln=999
		var hp: int=hero.hp
		S5.quake(sim,boss)
		check(hero.hp<hp and hero.airborne_lock and hero.vz>0,"downed target re-launched by each stomp")
	hero.x=boss.x+240;hero.invuln=0;hero.action="down"
	var hp: int=hero.hp
	S5.quake(sim,boss);check(hero.hp==hp,"outside quake radius is safe")
	boss.action_tick=300; S5.attack(sim,boss)
	check(boss.action=="idle" and not S5.invulnerable(boss),"five-second invulnerability ends independently of audio tail")
	hero.action="idle"
	S5.start(sim,boss,"s05_kusei_guard",hero);boss.action_tick=18
	check(not sim._damage(boss,30,hero.id,true),"guard rejects normal heavy")
	check(not sim._damage(boss,3,hero.id,false,false),"guard rejects DOT")
	var farmer := actor(sim,"militia")
	farmer.throw_ticks=20; farmer.thrown_by=hero.id
	var monk := actor(sim,"monk")
	monk.throw_ticks=20; monk.thrown_by=hero.id
	check(not sim._damage(boss,22,hero.id,false,true,false,false,farmer.x,farmer.y,"body_collision",24,"blunt",-1,-1,"",false,monk.id),"thrown monk cannot break guard")
	check(sim._damage(boss,22,hero.id,false,true,false,false,farmer.x,farmer.y,"body_collision",24,"blunt",-1,-1,"",false,farmer.id),"actual thrown farmer breaks guard")
	# Merely passing the old generic body-collision name does not bypass the guard.
	S5.start(sim,boss,"s05_kusei_guard",hero);boss.action_tick=20;boss.invuln=0
	check(not sim._damage(boss,22,hero.id,false,true,false,false,farmer.x,farmer.y,"body_collision"),"guard needs body identity")
	farmer.x=boss.x-10;farmer.y=boss.y;farmer.z=0;farmer.throw_hits=[]
	monk.throw_ticks=0;hp=boss.hp
	sim._resolve_throws()
	check(boss.hp<hp,"real thrown-body collision passes farmer identity through combat")
	check(Wire.valid_snapshot(sim.state),"guard collision state synchronizes")

	sim=node(12);boss=actor(sim,"kusei");hero=sim.state.fighters[0]
	hero.x=boss.x-500;hero.y=boss.y;hero.action="idle";hero.invuln=0
	S5.start(sim,boss,"s05_kusei_slash",hero);boss.action_tick=27;S5.attack(sim,boss)
	check(boss.s05_combo.is_empty(),"missed first slash does not lock")
	hero.x=boss.x-60;hp=hero.hp;boss.action_tick=48;S5.attack(sim,boss)
	check(hero.hp==hp,"second slash cannot acquire a new victim")
	S5.start(sim,boss,"s05_kusei_slash",hero);boss.action_tick=27;S5.attack(sim,boss)
	check(hero.id in boss.s05_combo and hero.stun>=30,"successful first slash locks victim")
	boss.action_tick=48;S5.attack(sim,boss);boss.action_tick=63;S5.attack(sim,boss)
	check(hero.airborne_lock and hero.vz>0,"third slash launches locked victim")

	sim=node(12,2);boss=actor(sim,"kusei");hero=sim.state.fighters[0]
	boss.hp=roundi(boss.max_hp*.09)
	for i in 3: S5.thresholds(sim,boss)
	check(sim.state.ikki.thresholds==[70,40,10] and sim.state.ikki.summons.size()==3,"all crossed thresholds queue once")
	check(Wire.valid_snapshot(sim.state),"all three numeric thresholds validate")
	sim.state.props.clear();sim.state.ikki.pending.clear()
	for i in 3:
		boss.action="idle"; S5.ai(sim,boss,hero)
		check(boss.action=="s05_kusei_summon","queued summon starts")
		boss.action_tick=60;S5.attack(sim,boss)
		check(sim.state.ikki.summon_count==i,"first clap does not spawn")
		boss.action_tick=99;S5.attack(sim,boss)
		check(sim.state.ikki.summon_count==i+1,"second clap queues four")
		check(boss.s05_summon_shield and sim.state.ikki.pending.filter(func(u):return u.elite).size()==4,"summoned monks lock boss HP even before entry")
		hp=boss.hp
		check(not sim._damage(boss,500,hero.id,true,true,true) and boss.hp==hp,"summon shield blocks direct damage")
		check(not sim._damage(boss,3,hero.id,false,false) and boss.hp==hp,"summon shield blocks damage over time")
		boss.action="idle";S5.ai(sim,boss,hero)
		check(boss.action!="s05_kusei_summon","next threshold waits until current monks are cleared")
		S5.tick(sim);check(boss.s05_summon_shield,"pending monks keep the shield active")
		for f in sim.state.fighters:
			if f.get("s05_role","")=="monk": f.hp=0;f.action="defeated"
		sim.state.ikki.pending=sim.state.ikki.pending.filter(func(u):return u.role!="monk")
		S5.tick(sim);check(not boss.s05_summon_shield,"all living and pending monks must clear before HP unlocks")
	check(sim.state.ikki.summon_count==3,"three cleared thresholds each summon four elites")
	var elite := S5.spawn(sim,"monk",500,500,true)
	var regular := S5.spawn(sim,"monk",500,500)
	check(elite.max_hp==regular.max_hp*1.5 and S5.Data.speed(elite)==1.5,"elite HP and speed are 150 percent")
	check(S5.Data.height(elite.s05_role)==S5.Data.height(regular.s05_role),"elite visuals and reach retain same size")
	sim.state.ikki.pending=sim.state.ikki.pending.filter(func(u):return u.source!="farmer")
	for f in sim.state.fighters:
		if f.get("s05_weak",false): f.hp=0
	for tick in range(121,1300): sim.state.tick=tick;S5.tick(sim)
	check(sim.state.fighters.filter(func(f):return f.get("s05_weak",false) and f.hp>0).size()==2,"weak farmers replenish through the entry queue while boss alive")
	boss.hp=0
	for f in sim.state.fighters:
		if f.get("s05_weak",false): f.hp=0
	for tick in range(1300,1600): sim.state.tick=tick;S5.tick(sim)
	check(not sim.state.fighters.any(func(f):return f.get("s05_weak",false) and f.hp>0) and not sim.state.ikki.pending.any(func(u):return u.weak),"farmer replenishment stops at boss death independently of banners")

	sim=node(10);boss=actor(sim,"natsume");hero=sim.state.fighters[0]
	hero.x=boss.x-210;hero.y=boss.y;boss.cooldown=0;hero.z=0;hero.vz=0
	S5.ai(sim,boss,hero);check(boss.action=="s05_natsume_ground","ground approach selects downward wave")
	boss.action="idle";boss.cooldown=0;hero.z=55;hero.vz=5
	S5.ai(sim,boss,hero);check(boss.action=="s05_natsume_diagonal","jump approach selects upward wave")
	check(Music.select(node(12).state,"")=="s05_kusei_intro","boss music selects intro")
	var music := Audio.music("s05_kusei_intro")
	check(music.loop_begin==1114105 and music.loop_end==2995705 and music.loop_mode==AudioStreamWAV.LOOP_FORWARD,"sample-exact intro into loop")
	for players in [1,2]:
		for number in range(1,13):
			sim=node(number,players)
			check(Wire.valid_snapshot(sim.state),"initial wire node %d players %d"%[number,players])
			for f in sim.state.fighters:
				if f.team==0: f.invuln=100000
			for tick in 420:
				sim.step([{"dx":1 if tick<110 else 0,"dy":0,"buttons":0},{"dx":1 if tick<110 else 0,"dy":0,"buttons":0}])
				check(Wire.valid_snapshot(sim.state),"live wire node %d tick %d players %d"%[number,tick,players])
			check(Wire.valid_snapshot(bytes_to_var(var_to_bytes(sim.state))),"RPC Variant client round trip")
	pressure()
	print("STAGE05_COMBAT_PASS %d checks"%checks)
	quit(0)

func pressure() -> void:
	var sim:=node(12,2)
	var boss:=actor(sim,"kusei")
	var party: Array=sim.state.fighters.filter(func(f):return f.team==0)
	sim.state.props.clear();sim.state.effects.clear();sim.state.ikki.pending.clear()
	sim.state.fighters=party+[boss]
	for i in party.size():
		party[i].x=boss.x-1000;party[i].y=480+i*100;party[i].invuln=0
	boss.y=480;boss.cooldown=60
	var before: float=boss.x
	S5.ai(sim,boss,party[0])
	check(is_equal_approx(absf(boss.x-before),2.4*1.15),"Kusei pursues fifteen percent faster")
	boss.cooldown=0;S5.ai(sim,boss,party[0])
	check(boss.action=="s05_kusei_roar","distant player triggers lion roar")
	check(boss.s05_roar_ready_tick==sim.state.tick+480,"Roar reserves an independent eight second cooldown")
	boss.action_tick=27;S5.attack(sim,boss);S5.attack(sim,boss)
	var waves: Array=sim.state.effects.filter(func(e):return e.type=="s05_roar")
	check(waves.size()==1,"one growing sound wave per roar")
	var wave: Dictionary=waves[0]
	check(wave.max_life*Vector2(wave.vx,wave.vy).length()>1280,"roar travels farther than a full viewport")
	for tick in 100: sim._tick_effects()
	check(wave.radius>=300,"sound wave expands across multiple ground lanes")
	for hero in party:
		check(hero.hp==hero.max_hp-12 and hero.stun==120 and hero.action=="stunned","wide roar hits each player once and stuns for two seconds")
	check(Wire.valid_snapshot(sim.state),"roar and full warehouses cross the wire")
	var bad:=sim.get_state()
	bad.effects[0].radius=361
	check(not Wire.valid_snapshot(bad),"oversized roar data is rejected at the network boundary")
	boss.action="idle";boss.cooldown=0;sim.state.tick=int(boss.s05_roar_ready_tick)-1
	S5.ai(sim,boss,party[0])
	check(boss.action=="idle","Distant players cannot trigger a roar before its cooldown")
	sim.state.tick+=1;S5.ai(sim,boss,party[0])
	check(boss.action=="s05_kusei_roar" and boss.s05_roar_ready_tick==sim.state.tick+480,"Roar becomes available only after eight seconds")
	party[0].x=boss.x-100;party[0].y=boss.y
	boss.action="idle";boss.cooldown=0;boss.ai_cycle=2
	S5.ai(sim,boss,party[0])
	check(boss.action=="s05_kusei_stomp","Ready stomp is still selected at close range")
	var stomp_ready: int=boss.s05_stomp_ready_tick
	boss.action="idle";boss.cooldown=0;boss.ai_cycle=2;sim.state.tick=stomp_ready-1
	S5.ai(sim,boss,party[0])
	check(boss.action=="s05_kusei_slash" and boss.s05_stomp_ready_tick==stomp_ready,"Cooling stomp is replaced by a slash without extending its cooldown")
	boss.action="idle";boss.cooldown=0;boss.ai_cycle=2;sim.state.tick=stomp_ready
	S5.ai(sim,boss,party[0])
	check(boss.action=="s05_kusei_stomp" and boss.s05_stomp_ready_tick==sim.state.tick+1200,"Stomp is available at its twenty second boundary")
	check(Wire.valid_snapshot(sim.state),"Stomp cooldown synchronizes")
	var bad_stomp:=sim.get_state()
	bad_stomp.fighters[-1].s05_stomp_ready_tick=-1
	check(not Wire.valid_snapshot(bad_stomp),"Negative stomp cooldown is rejected")
