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
	return sim.state.fighters.filter(func(f):return f.get("s05_role","")==role)[0]

func _initialize() -> void:
	var sim := node(12,2)
	var boss := actor(sim,"kusei")
	var hero: Dictionary=sim.state.fighters[0]
	check(boss.max_hp==2040 and actor(node(12),"kusei").max_hp==1200,"fixed solo/coop HP proposal")
	S5.start(sim,boss,"s05_kusei_stomp",hero)
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
	for i in 3:
		boss.action="idle"; S5.ai(sim,boss,hero)
		check(boss.action=="s05_kusei_summon","queued summon starts")
		boss.action_tick=60;S5.attack(sim,boss)
		check(sim.state.ikki.summon_count==i,"first clap does not spawn")
		boss.action_tick=99;S5.attack(sim,boss)
		check(sim.state.ikki.summon_count==i+1,"second clap queues four")
	check(sim.state.ikki.pending.size()==12,"three thresholds total twelve elites")
	var elite := S5.spawn(sim,"monk",500,500,true)
	var regular := S5.spawn(sim,"monk",500,500)
	check(elite.max_hp==regular.max_hp*1.5 and S5.Data.speed(elite)==1.5,"elite HP and speed are 150 percent")
	check(S5.Data.height(elite.s05_role)==S5.Data.height(regular.s05_role),"elite visuals and reach retain same size")
	var before: int=sim.state.fighters.size()
	for f in sim.state.fighters:
		if f.get("s05_weak",false): f.hp=0
	sim.state.tick=121; S5.tick(sim)
	check(sim.state.fighters.size()>before,"weak farmers replenish while boss alive")
	boss.hp=0;sim.state.ikki.pending.clear();sim.state.ikki.next_batch=2
	before=sim.state.fighters.size();sim.state.tick=1000;S5.tick(sim)
	check(sim.state.fighters.size()==before,"farmer replenishment stops at boss death")

	sim=node(10);boss=actor(sim,"natsume");hero=sim.state.fighters[0]
	hero.x=boss.x-150;hero.y=boss.y;boss.cooldown=0;hero.z=0;hero.vz=0
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
	print("STAGE05_COMBAT_PASS %d checks"%checks)
	quit(0)
