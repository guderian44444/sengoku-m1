extends SceneTree

const Battle = preload("res://core/battle.gd")
const Encounter = preload("res://core/stage04_encounter.gd")
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func arena(hero_kind: String, role: String, face: int) -> Battle:
	var sim := Battle.new()
	sim.reset_campaign("normal",1,[hero_kind],4)
	if role=="shield_udono": sim._enter_segment(4)
	var hero: Dictionary=sim.state.fighters[0]
	var shield: Dictionary=sim.state.fighters.filter(func(f):return f.get("mikawa_role","")==role)[0]
	# Keep the real chapter-spawned actor; isolate contacts from unrelated reinforcements.
	sim.state.fighters=[hero,shield];sim.state.props.clear();sim.state.intro.clear()
	sim.state.mikawa.next_batch=sim._campaign.segments[sim.state.stage.index].encounters[0].batches.size()
	hero.x=900;hero.y=510;hero.face=face;hero.hp=1000;hero.max_hp=1000
	shield.x=hero.x+face*90;shield.y=hero.y;shield.face=-face
	shield.hp=1000;shield.max_hp=1000;shield.cooldown=10000
	return sim

func inputs() -> void:
	for role in ["shield_kira","shield_udono"]:
		for hero_kind in Battle.PLAYABLE_HEROES:
			for face in [-1,1]:
				for move in ["grab","light","heavy","air_heavy"]:
					var sim:=arena(hero_kind,role,face)
					var hero: Dictionary=sim.state.fighters[0];var shield: Dictionary=sim.state.fighters[1]
					var start_hp: int=shield.hp
					for tick in 160:
						var buttons := 0
						if tick==0:
							buttons={"grab":Battle.GRAB,"light":Battle.LIGHT,"heavy":Battle.HEAVY,"air_heavy":Battle.JUMP|Battle.HEAVY}[move]
						elif move=="light" and tick%24==0: buttons=Battle.LIGHT
						elif move=="grab" and tick==30: buttons=Battle.LIGHT
						sim.step([{"buttons":buttons}])
						check(shield.held_by==0 and hero.grab_target==0,"chapter shield cannot be grabbed: "+role+" / "+hero_kind)
						check(not shield.airborne_lock and shield.action not in ["down","launched","thrown","grabbed","recovering"],"ordinary input never topples shield: "+role+" / "+hero_kind+" / "+move)
					if move!="grab": check(shield.hp<start_hp,"ordinary input really hit shield: "+role+" / "+hero_kind+" / "+move)

func reactions() -> void:
	for role in ["shield_kira","shield_udono"]:
		for face in [-1,1]:
			for action in ["light","heavy","air_heavy","dash_heavy","special","body_collision","charged","charge_rain"]:
				var sim:=arena("nobunaga",role,face)
				var hero: Dictionary=sim.state.fighters[0];var shield: Dictionary=sim.state.fighters[1]
				hero.action="idle";Encounter.start(sim,shield,"spear_butt")
				var charged: bool=action in ["charged","charge_rain"]
				sim._damage(shield,40,hero.id,true,true,false,true,hero.x,hero.y,action)
				check(shield.hp==1000-(40 if charged else 20),"actual source move controls mitigation "+role+" / "+action)
				if charged: check(shield.action=="down","charged exception still knocks down "+role)
				else:
					sim._launch(shield,face)
					check(shield.action=="hurt" and not shield.airborne_lock and shield.knockback!=0,"ordinary hits interrupt retaliation "+role)
			var sim:=arena("nobunaga",role,face)
			var shield: Dictionary=sim.state.fighters[1];var hero: Dictionary=sim.state.fighters[0]
			var body:=Encounter.spawn(sim,{"role":"spear_kira","kind":"soldier","x":shield.x,"y":shield.y},1)
			body.thrown_by=hero.id;body.throw_ticks=32;body.knockback=10.0*face;body.z=40
			sim.state.fighters.append(body);Encounter.start(sim,shield,"spear_butt")
			sim._resolve_throws()
			check(shield.hp==989 and shield.action=="hurt" and not shield.airborne_lock,"thrown soldier cannot topple either shield")

func conversion_distance() -> void:
	for role in Encounter.Data.SHIELD_ROLES:
		for face in [-1,1]:
			for hero_kind in Battle.PLAYABLE_HEROES:
				var moves := ["light","finisher","heavy","air_heavy","dash_heavy"]
				if hero_kind in ["nobunaga","ieyasu"]: moves.append("wave")
				for move in moves:
					var sim:=arena(hero_kind,role,face)
					sim.state.mikawa.mud=[]
					var hero:Dictionary=sim.state.fighters[0];var shield:Dictionary=sim.state.fighters[1]
					var action: String="light" if move=="finisher" else ("heavy" if move=="wave" else move)
					hero.combo=3 if move=="finisher" else 1
					if move=="wave": shield.x=hero.x+face*(270 if hero_kind=="nobunaga" else 200)
					if action=="air_heavy": hero.z=60
					sim._begin(hero,action);Encounter.start(sim,shield,"spear_butt")
					sim._combat_contact_v33(hero,"contact")
					for tick in 100:
						if shield.hp<1000: break
						sim._tick_effects()
					var label: String=role+" / "+hero_kind+" / "+move+" / "+str(face)
					check(shield.hp<1000 and shield.action=="hurt" and not shield.airborne_lock,"real move interrupts without launching: "+label)
					var strong: bool=move!="light" and not (hero_kind=="oichi" and move in ["heavy","air_heavy"])
					check(is_equal_approx(shield.knockback,face*(12.0 if strong else 6.0)),"launching move becomes stronger standing push: "+label)
					var start:float=shield.x
					for tick in 80:sim._tick_motion(shield)
					check(absf((shield.x-start)*face-(119.057 if strong else 59.015))<0.01,"measured standing push distance: "+label)
			var sim:=arena("nobunaga",role,face)
			sim.state.mikawa.mud=[]
			var hero:Dictionary=sim.state.fighters[0];var shield:Dictionary=sim.state.fighters[1]
			# Direction follows the thrown body even when the thrower has moved past the shield.
			hero.x=shield.x+face*80
			var body:=Encounter.spawn(sim,{"role":"spear_kira","kind":"soldier","x":shield.x,"y":shield.y},1)
			body.thrown_by=hero.id;body.throw_ticks=32;body.knockback=10.0*face;body.z=40
			sim.state.fighters.append(body);Encounter.start(sim,shield,"spear_butt")
			sim._resolve_throws()
			check(shield.hp==989 and shield.action=="hurt" and shield.knockback==face*12 and not shield.airborne_lock,"body collision interrupts and gives a strong grounded push in flight direction")
			var start:float=shield.x
			for tick in 80:sim._tick_motion(shield)
			check(absf((shield.x-start)*face-119.057)<0.01,"thrown body pushes twice the ordinary distance")
			for knockdown in [false,true]:
				sim=arena("mitsuhide",role,face);hero=sim.state.fighters[0];shield=sim.state.fighters[1]
				Encounter.start(sim,shield,"spear_butt")
				sim._effect("shockwave",hero.x,hero.y,30,{"radius":300.0,"hit_ids":[],"team":0,"owner":hero.id,"face":face,"damage":20,"action":"ground_slam","knockdown":knockdown})
				var wave:Dictionary=sim.state.effects[-1]
				wave.life=1;sim._tick_shockwave(wave)
				check(shield.hp==990 and shield.action=="hurt" and not shield.airborne_lock,"shockwave interrupts with half damage and no launch")
				check(shield.knockback==face*(12.0 if knockdown else 6.0),"shockwave preserves original knockdown intent before shield conversion")
			# A hit just before contact must cancel that strike, but recovery permits a new attack.
			sim=arena("nobunaga",role,face);hero=sim.state.fighters[0];shield=sim.state.fighters[1]
			Encounter.start(sim,shield,"spear_butt")
			shield.action_tick=Battle.enemy_timing(shield)[0]-1
			sim._damage(shield,20,hero.id,false)
			for tick in 18:sim._tick_fighter(shield)
			check(shield.action=="idle" and hero.hp==1000,"interrupted attack never reaches contact and recovers after hurt")
			Encounter.start(sim,shield,"spear_butt")
			for tick in int(Battle.enemy_timing(shield)[0]):sim._tick_fighter(shield)
			check(hero.hp<1000,"shield can attack again after the interruption")

func oichi_arrows() -> void:
	for role in Encounter.Data.SHIELD_ROLES:
		for face in [-1,1]:
			for move in ["heavy","charged","charge_rain"]:
				var sim:=arena("oichi",role,face)
				var hero:Dictionary=sim.state.fighters[0];var shield:Dictionary=sim.state.fighters[1]
				var saw_push:=false;var saw_down:=false;var saw_rain:=false
				for tick in 220:
					var buttons:int=Battle.HEAVY if tick==0 or (move!="heavy" and tick<=65) else 0
					sim.step([{"buttons":buttons,"dy":-1 if move=="charge_rain" and tick==66 else 0}])
					saw_push=saw_push or absf(shield.knockback)>0.1
					saw_down=saw_down or shield.action=="down"
					saw_rain=saw_rain or sim.state.effects.any(func(e):return e.type=="arrow_rain")
					if move!="charge_rain":check(not shield.airborne_lock and shield.action not in ["down","launched","recovering"],"Oichi straight arrow never topples shield: "+move+" / "+role)
				check(shield.hp==1000-(12 if move=="heavy" else 43),"arrow damage remains half for ordinary / full for charged: "+move)
				if move=="charge_rain":check(saw_rain and saw_down,"real overhead rain still knocks down both shield types")
				else:check(saw_push and not saw_down,"ordinary and charged straight arrows only push")

func _initialize() -> void:
	inputs()
	reactions()
	conversion_distance()
	oichi_arrows()
	print("STAGE04 SHIELDS PASS: %d checks"%checks)
	quit()
