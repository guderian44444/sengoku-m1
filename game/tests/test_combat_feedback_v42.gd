extends SceneTree

const Battle = preload("res://core/battle.gd")
const Encounter = preload("res://core/stage04_encounter.gd")
const Art = preload("res://render/stage04_art.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func arena(role: String, distance: float, face: int = 1, hero_kind: String = "nobunaga") -> Battle:
	var sim := Battle.new()
	sim.reset_campaign("normal",1,[hero_kind],4)
	sim.state.props.clear()
	sim.state.fighters = sim.state.fighters.filter(func(f): return f.team==0)
	var hero: Dictionary = sim.state.fighters[0]
	hero.x = 1100.0+distance*face; hero.y = 510.0; hero.face = -face
	hero.hp = 100000; hero.max_hp = 100000
	var enemy := Encounter.spawn(sim,{"role":role,"kind":"boss" if role in ["kira","tominaga","udono"] else "soldier","x":1100,"y":510},1)
	enemy.hp = 100000; enemy.max_hp = 100000; enemy.face = face; enemy.cooldown = 0
	sim.state.fighters.append(enemy)
	return sim

func immediate_air() -> void:
	for face in [-1,1]:
		for altitude in [0.0,90.0,160.0]:
			var sim := arena("spear_kira",-300,face)
			var hero: Dictionary = sim.state.fighters[0]
			hero.face=face;hero.z=altitude;hero.vz=0
			var enemy: Dictionary = sim.state.fighters[1]
			enemy.x=hero.x+face*300; enemy.cooldown=1000
			sim.step([{"buttons":Battle.HEAVY | (Battle.JUMP if altitude==0 else 0)}])
			check(sim.state.effects.filter(func(e):return e.type=="blade_wave").size()==1,"air heavy wave on input tick")
			check(enemy.hp<enemy.max_hp,"air heavy damage on input tick")
			var swings: int = sim.state.events.filter(func(e):return e.type=="weapon_swing" and e.actor==hero.id).size()
			for tick in 80:
				sim.step([{}])
				swings += sim.state.events.filter(func(e):return e.type=="weapon_swing" and e.actor==hero.id).size()
			check(swings==1 and hero.action=="idle" and hero.z==0,"immediate wave does not duplicate or strand hero airborne")

func minibosses() -> void:
	for role in ["kira","tominaga"]:
		for face in [-1,1]:
			var sim := arena(role,500,face)
			var hero: Dictionary=sim.state.fighters[0]
			var boss: Dictionary=sim.state.fighters[1]
			if role=="kira":
				var archer := Encounter.spawn(sim,{"role":"archer_kira","kind":"archer","escort":true,"x":boss.x-face*100,"y":510},1)
				sim.state.fighters.append(archer)
			var calls := {}; var releases := {}; var actions := {}
			for tick in 600:
				sim.step([{}])
				actions[boss.action]=true
				for e in sim.state.events:
					if e.type=="mikawa_audio" and e.voice and e.actor==boss.id: calls[e.cue]=true
				for e in sim.state.effects:
					if e.type=="projectile": releases[e.get("mikawa_projectile",e.get("weapon",""))]=true
			check(releases.has("rain") and releases.has("arrow") if role=="kira" else releases.has("wave"),"distant miniboss actually releases ranged moves "+role)
			check(calls.has("kira_command") and calls.has("kira_arrow") if role=="kira" else calls.has("tominaga_heavy_chop"),"live AI emits authored voice events "+role)
			sim=arena(role,90,face);hero=sim.state.fighters[0];boss=sim.state.fighters[1]
			hero.action="light"
			sim._damage(boss,20,hero.id,false)
			check(boss.action=="idle","light cannot prevent miniboss from starting a counter")
			Encounter.ai(sim,boss,hero)
			var counter: String=boss.action
			check(counter in ["kira_counter","tominaga_sweep","tominaga_pursuit"],"close miniboss chooses push counter")
			for combo in [1,2,3]:
				boss.invuln=0;hero.action="light";hero.combo=combo
				var hp: int=boss.hp
				sim._damage(boss,20,hero.id,combo==3)
				check(boss.hp<hp and boss.action==counter,"light deals damage without cancelling committed counter")
			hero.action="idle"
			var separation := absf(hero.x-boss.x)
			var pushed := false
			for tick in 85:
				sim.step([{}])
				pushed = pushed or absf(hero.knockback)>0
			check(pushed and absf(hero.x-boss.x)>separation+100,"counter hits and retreats to open distance "+role)
			boss.invuln=0;boss.action=counter;hero.action="charged"
			sim._damage(boss,20,hero.id,true,true,false,true)
			check(boss.action=="hurt","charged attack still interrupts miniboss")

func shields_and_grabs() -> void:
	for face in [-1,1]:
		for action in ["light","heavy","air_light","air_heavy","dash_heavy"]:
			var sim:=arena("shield_udono",80,face)
			var hero: Dictionary=sim.state.fighters[0];var shield: Dictionary=sim.state.fighters[1]
			hero.action=action
			sim._begin(shield,"spear_butt")
			var hp: int=shield.hp
			sim._damage(shield,40,hero.id,true,true,false,true)
			sim._launch(shield,face,12,8)
			check(shield.hp==hp-20,"heavy shield takes half ordinary damage from either side")
			check(shield.action=="hurt" and not shield.airborne_lock and shield.knockback!=0,"heavy shield attack is interrupted while pushed")
		for action in ["charged","charge_rain"]:
			var sim:=arena("shield_udono",80,face)
			var hero: Dictionary=sim.state.fighters[0];var shield: Dictionary=sim.state.fighters[1]
			hero.action=action;var hp: int=shield.hp
			sim._damage(shield,40,hero.id,false)
			check(shield.hp==hp-40 and shield.action=="down","full charged hit knocks heavy shield down")
	var art:=Art.new()
	for hero_kind in Battle.PLAYABLE_HEROES:
		for role in Encounter.Data.ROLES:
			if role in ["kira","tominaga","udono"]: continue
			var sim:=arena(role,80,1,hero_kind)
			var hero: Dictionary=sim.state.fighters[0];var enemy: Dictionary=sim.state.fighters[1]
			hero.face=-1
			sim._try_grab(hero)
			if role in Encounter.Data.SHIELD_ROLES:
				check(hero.grab_target==0 and enemy.held_by==0,"heavy shield cannot be grabbed")
				continue
			check(hero.grab_target==enemy.id,"all heroes can grab "+role)
			var body_height := -1.0; var cell := -1
			for tick in [0,1,6,12,24,60,120]:
				enemy.action_tick=tick
				var sample:=art.sample(sim.state,enemy,0,tick)
				if body_height < 0: body_height=sample.frame_data.body_height;cell=sample.cell
				check(is_equal_approx(body_height,sample.frame_data.body_height),"held body keeps source calibration "+role)
				if role!="gunner": check(sample.cell==cell,"held pose never returns to unrelated standing body")
			if hero_kind=="hideyoshi": sim._begin(hero,"throw")
			sim._release_grab(hero,true)
			check(enemy.held_by==0 and enemy.airborne_lock and enemy.action=="thrown","all heroes can throw "+role)
			check(Wire.valid_snapshot(sim.state),"held and thrown state serializes")

func arrows_shields_and_udono() -> void:
	for face in [-1,1]:
		var sim:=arena("kira",500,face)
		var boss: Dictionary=sim.state.fighters[1]
		Encounter.start(sim,boss,"kira_arrow")
		var shots:=[]
		for tick in int(Encounter.Data.attack_timing(boss)[1]):
			boss.action_tick=tick+1;Encounter.attack(sim,boss)
			for e in sim.state.effects:
				if e.type=="projectile" and not shots.has(e):
					shots.append(e)
					check(e.vx==face*Battle.HERO_ARROW_SPEED and e.vy==0 and not e.get("arcing",false),"Kira uses Oichi speed and no lob trajectory")
					var x: float=e.x;var z: float=e.z
					sim._tick_effects()
					check(is_equal_approx(e.x-x,face*Battle.HERO_ARROW_SPEED) and e.z==z,"straight arrow advances without rising or falling")
		check(shots.size()==3,"Kira releases exactly three sequential arrows")
		sim=arena("shield_udono",80,face)
		var shield: Dictionary=sim.state.fighters[1]
		var hero: Dictionary=sim.state.fighters[0]
		var body:=Encounter.spawn(sim,{"role":"spear_kira","kind":"soldier","x":shield.x,"y":shield.y},1)
		body.throw_ticks=30;body.thrown_by=hero.id;body.knockback=10.0*face;body.z=40
		sim.state.fighters.append(body);sim._begin(shield,"spear_butt")
		var hp: int=shield.hp
		sim._resolve_throws()
		check(shield.hp==hp-11 and shield.action=="hurt" and not shield.airborne_lock,"thrown body deals half damage and interrupts shield without toppling it")
		sim=arena("udono",600,face);boss=sim.state.fighters[1];hero=sim.state.fighters[0]
		Encounter.ai(sim,boss,hero)
		check(boss.action=="udono_ranged_rock_volley","Udono chooses stones at long range without prior player hits")
		check(Encounter.Data.attack_timing(boss)[0]==44,"Udono release is 10 percent faster")
		Encounter.start(sim,boss,"udono_triplequake");hero.x=boss.x+100;hero.z=0;hero.y=boss.y
		var waves:=[]
		for tick in int(Encounter.Data.attack_timing(boss)[1]):
			boss.action_tick=tick+1;hero.action="idle";hero.invuln=0;hero.z=0
			hp=hero.hp;Encounter.attack(sim,boss)
			if hero.hp<hp: waves.append(tick+1)
		check(waves==[34,71,108],"three quakes have three separately synchronized hit windows")
		check(sim.state.effects.filter(func(e):return e.get("asset","")=="quake").size()==3,"three quake effects accompany three hits")

func _initialize() -> void:
	immediate_air()
	minibosses()
	shields_and_grabs()
	arrows_shields_and_udono()
	print("COMBAT FEEDBACK V42 PASS: %d checks"%checks)
	quit()
