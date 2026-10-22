extends SceneTree

const Battle = preload("res://core/battle.gd")
const Stage = preload("res://core/stage07_10_encounter.gd")
const Wire = preload("res://core/wire.gd")

func _initialize() -> void:
	for chapter in Stage.Data.STAGES:
		var sim := Battle.new()
		sim.reset_campaign("normal",2,["nobunaga","oichi"],chapter)
		assert(sim._campaign.segments.size()==5)
		assert(Wire.valid_snapshot(sim.state),"Initial snapshot stage %d"%chapter)
		for s in 5:
			sim._enter_segment(s)
			for c in 2:
				sim._start_checkpoint(c)
				assert(int(sim.state.expedition.node)==s*2+c+1)
				assert(Wire.valid_snapshot(sim.state),"Every authored checkpoint has a valid snapshot")
		print("STAGE0710_SCHEMA_PASS ",chapter)
	test_hazards()
	test_objectives()
	test_bosses()
	test_replay()
	print("STAGE0710_PASS")
	quit()

func clean(sim) -> void:
	sim.state.intro={}
	sim.state.fighters=sim.state.fighters.filter(func(f):return f.team==0)
	sim.state.expedition.pending=[]
	sim.state.expedition.hazards=[]
	for prop in sim.state.props: prop.broken=true;prop.hp=0

func test_hazards() -> void:
	var sim := Battle.new()
	sim.reset_campaign("normal",1,["nobunaga"],7)
	sim.state.intro={}
	Stage.environment_hazard(sim)
	assert(sim.state.expedition.hazards.size()==1,"Intact supports trigger rocks")
	for p in sim.state.props:
		if p.expedition_asset=="rock_support": p.broken=true
	sim.state.expedition.hazards=[]
	Stage.environment_hazard(sim)
	assert(sim.state.expedition.hazards.is_empty(),"Breaking support disables environmental rockfall")
	clean(sim)
	var hero: Dictionary=sim.state.fighters[0]
	hero.invuln=0;hero.x=300;hero.y=480;hero.hp=hero.max_hp
	var hp := int(hero.hp)
	Stage.hazard(sim,"rock",Vector2(hero.x,hero.y),80,40,85,20)
	for i in 84: Stage.tick_hazards(sim)
	assert(hero.hp==hp,"A warning never inflicts early damage")
	Stage.tick_hazards(sim)
	assert(hero.hp<hp,"Rock lands exactly after the warning")
	hero.hp=hp;hero.invuln=0;hero.z=100;sim.state.expedition.hazards=[]
	Stage.hazard(sim,"quake",Vector2(hero.x,hero.y),80,40,1,20)
	Stage.tick_hazards(sim)
	assert(hero.hp==hp,"Jump clears a ground fissure")
	sim.reset_campaign("normal",1,["nobunaga"],9)
	clean(sim);hero=sim.state.fighters[0];hero.x=600;hero.y=480;hero.z=0;hero.invuln=0
	var cover := {"id":9000,"kind":"barricade","expedition_asset":"barricade","x":800.0,"y":480.0,"hp":100,"max_hp":100,"width":100.0,"depth":60.0,"broken":false,"drop":"","mandatory":false,"broken_tick":-1}
	sim.state.props.append(cover)
	assert(Stage.cover_between(sim,hero,1100),"A barrier between the shooter and player stops right-to-left fire")
	assert(not Stage.cover_between(sim,hero,100),"A barrier behind the player does not stop left-to-right fire")
	Stage.hazard(sim,"fireline",Vector2(hero.x,hero.y),100,30,1,20,0,1100)
	hp=int(hero.hp);Stage.tick_hazards(sim)
	assert(hero.hp==hp,"The actual projectile source determines cover")
	var malformed: Dictionary=sim.state.expedition.duplicate(true)
	malformed.objective="gate"
	assert(not Stage.Data.valid_world(malformed),"Objective cannot spoof another stage")
	malformed=sim.state.expedition.duplicate(true);malformed.hazards[0].radius=INF
	assert(not Stage.Data.valid_world(malformed),"Non-finite hazard rejected")
	print("STAGE0710_HAZARDS_PASS")

func test_objectives() -> void:
	var sim := Battle.new()
	sim.reset_campaign("normal",2,["nobunaga","oichi"],9)
	clean(sim);sim.state.expedition.wave=2
	for prop in sim.state.props:
		if prop.expedition_asset=="supplies": prop.broken=false;prop.hp=prop.max_hp
	for i in 1200: Stage.evacuate_civilians(sim)
	assert(sim.state.expedition.rescued==3,"Optional supplies never block the third civilian group")
	assert(sim.state.fighters[0].gold==300 and sim.state.fighters[1].gold==300,"Both players receive the escort reward")
	sim.reset_campaign("normal",1,["nobunaga"],7)
	clean(sim);sim.state.expedition.wave=2;sim.state.expedition.admit_tick=0
	Stage.queue(sim,"spear",false)
	Stage.tick(sim)
	assert(sim.state.expedition.phase=="combat" and sim.state.fighters.any(func(f):return f.team==1 and f.hp>0),"Admitting the last reserved soldier cannot clear a checkpoint")
	sim.reset_campaign("normal",2,["nobunaga","oichi"],10)
	clean(sim);sim.state.expedition.wave=2;sim.state.expedition.elapsed=sim.state.expedition.hold_ticks-2;sim.state.expedition.next_reinforce=1800
	for hero in sim.state.fighters: hero.x=1300;hero.z=0
	Stage.tick(sim)
	assert(sim.state.expedition.phase!="complete","Retreat does not bypass the hold timer")
	sim.state.fighters[1].x=800
	Stage.tick(sim)
	assert(sim.state.expedition.phase=="evacuating","All players must reach the exit")
	sim.state.fighters[1].x=1300
	Stage.tick(sim)
	assert(sim.state.expedition.phase=="complete","Both living players reaching the exit completes the node")
	print("STAGE0710_OBJECTIVES_PASS")

func test_bosses() -> void:
	var actions := []
	for role in Stage.Data.BOSSES:
		var spec: Dictionary=Stage.Data.BOSSES[role]
		var sim := Battle.new()
		sim.reset_campaign("normal",1,["nobunaga"],int(spec.stage));clean(sim)
		var boss := Stage.spawn(sim,role,650,480)
		sim.state.fighters.append(boss)
		var hero: Dictionary=sim.state.fighters[0]
		hero.x=780;hero.y=480
		for action in spec.actions:
			actions.append(action);boss.hp=boss.max_hp;boss.stun=0;boss.freeze=0
			hero.hp=hero.max_hp;hero.invuln=0;hero.stun=0;hero.action="idle";hero.z=0
			Stage.start(sim,boss,action,hero)
			assert(Stage.Data.ACTIONS[action].art_clip in ["attack_a","attack_b","attack_c"])
			for tick in int(Stage.Data.ACTIONS[action].duration):
				boss.action_tick=tick+1
				if Stage.Data.ACTIONS[action].kind=="turn" and tick==22: hero.x=boss.x-boss.face*100
				Stage.attack(sim,boss)
				if tick+1 in Stage.Data.ACTIONS[action].hits and Stage.Data.ACTIONS[action].kind not in ["burst","rain","powder","crossfire","reinforce"]:
					var notices: Array=sim.state.effects.filter(func(e):return e.get("expedition_warning",false) and e.get("owner",0)==boss.id)
					assert(not notices.is_empty(),"Every melee strike retains its telegraph")
					var notice: Dictionary=notices[-1]
					var tip: float=boss.x+boss.face*float(Stage.Data.ACTIONS[action].reach)
					assert(absf(tip-notice.x)<=notice.radius+.01,"Advance and turn strikes stay inside their warning")
					assert(absf(boss.y-notice.y)+float(Stage.Data.ACTIONS[action].depth)<=notice.depth+.01,"Warning depth covers the actual lane")
			assert(boss.action=="idle" and boss.cooldown>0,"Every move exposes a recovery and returns to idle")
			assert(boss.expedition_events.size()==Stage.Data.ACTIONS[action].hits.size(),"Every strike executes once")
			assert(Wire.valid_snapshot(sim.state),"Boss move preserves snapshot schema: "+action)
			if Stage.Data.ACTIONS[action].kind=="counter":
				Stage.start(sim,boss,action,hero);boss.action_tick=20
				assert(not Stage.accepts_damage(sim,boss,hero.id,boss.x+boss.face*80,boss.y,false,"light"),"Front light attack is guarded")
				assert(Stage.accepts_damage(sim,boss,hero.id,boss.x-boss.face*80,boss.y,false,"light"),"Rear attack breaks the defensive line")
				assert(Stage.accepts_damage(sim,boss,hero.id,boss.x+boss.face*80,boss.y,true,"charged"),"Charged attack breaks the guard")
	assert(actions.size()==24,"Eight distinct officers with three authored moves each")
	print("STAGE0710_BOSSES_PASS")

func test_replay() -> void:
	for chapter in Stage.Data.STAGES:
		var a := Battle.new();var b := Battle.new()
		a.reset_campaign("normal",2,["nobunaga","oichi"],chapter)
		b.reset_campaign("normal",2,["nobunaga","oichi"],chapter)
		for tick in 600:
			var frame := [{"dx":1 if tick%200<100 else -1,"dy":1 if tick%120<60 else -1,"buttons":Battle.LIGHT if tick%3==0 else 0},{"dx":1,"dy":0,"buttons":Battle.HEAVY if tick%17==0 else 0}]
			a.step(frame);b.step(frame)
			if tick%120==0: assert(Wire.valid_snapshot(a.state),"Live snapshot is valid")
		assert(JSON.stringify(a.state)==JSON.stringify(b.state),"Replay is deterministic including hazards and entry order")
	print("STAGE0710_REPLAY_PASS")
