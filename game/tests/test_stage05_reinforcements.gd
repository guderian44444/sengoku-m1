extends SceneTree
const Battle = preload("res://core/battle.gd")
const S5 = preload("res://core/stage05_encounter.gd")
const Wire = preload("res://core/wire.gd")
const Objective = preload("res://ui/objective_scroll.gd")
var checks := 0

func check(ok: bool, label: String) -> void:
	checks+=1;assert(ok,label)

func node(number: int, players: int) -> Battle:
	var sim:=Battle.new();sim.reset_campaign("normal",players,["nobunaga","oichi"],5)
	for section in 5:
		for index in sim._campaign.segments[section].encounters.size():
			if int(sim._campaign.segments[section].encounters[index].node)==number:
				sim._enter_segment(section);sim._start_checkpoint(index)
				for hero in sim.state.fighters.filter(func(f):return f.team==0): hero.invuln=1000000
				return sim
	return sim

func regular(sim) -> Array:
	return sim.state.fighters.filter(func(f):return f.team==1 and f.hp>0 and f.kind!="boss" and not f.s05_elite and not f.s05_weak)

func check_new(sim, seen: Dictionary) -> void:
	var camera: float=Battle.camera_left(sim.state)
	var xs: Array=sim.state.fighters.filter(func(f):return f.team==0 and f.hp>0).map(func(f):return float(f.x))
	var low:=maxf(0,float(xs.max())-1200)
	var high:=minf(float(sim.state.stage.encounter_end),maxf(0,float(xs.min())-80)+1280)
	for f in sim.state.fighters:
		if f.team==0 or seen.has(f.id): continue
		check(f.entering and f.y>=360 and f.y<=600,"Every new enemy enters on valid ground")
		check(f.x+250<low or f.x-250>high,"Whole actor starts beyond every possible eased-camera edge")
		check(f.x+250<camera or f.x-250>camera+1280,"No visible-screen spawn")
		seen[f.id]=sim.state.tick

func advance(sim, seen: Dictionary, ticks: int) -> void:
	for i in ticks:
		for hero in sim.state.fighters.filter(func(f):return f.team==0): hero.hp=hero.max_hp;hero.invuln=1000000
		sim.step([{},{}]);check_new(sim,seen)
		check(Wire.valid_snapshot(sim.state),"Entry, pending flags and summons synchronize")

func banner_checks() -> void:
	for players in [1,2]:
		for number in range(1,13):
			var sim:=node(number,players);var seen: Dictionary={}
			check_new(sim,seen)
			var spec: Dictionary=sim._campaign.segments[sim.state.stage.index].encounters[sim.state.stage.checkpoint]
			check(Objective.objective(sim.state).order.begins_with("破旗斷援"),"Order explains the reinforcement objective")
			for flag in sim.state.props.filter(func(p):return p.s05_banner):
				check(flag.max_hp==165 and flag.mandatory,"Banner HP triples once and blocks advance")
				check(flag.x>=sim.state.stage.encounter_start+100 and flag.x<=sim._right_edge()-90,"Every controlling flag is reachable before the checkpoint unlocks")
			advance(sim,seen,650)
			check(regular(sim).size()==spec.garrison,"Initial staggered garrison reaches the configured count")
			var before:=seen.size();var victim: Dictionary=regular(sim)[0]
			victim.hp=0;victim.damage_tick=sim.state.tick
			advance(sim,seen,1)
			check(regular(sim).size()==spec.garrison-1,"Replacement is delayed after one death")
			advance(sim,seen,120)
			check(regular(sim).size()==spec.garrison and seen.size()==before+1,"One death produces exactly one replacement")
			for enemy in regular(sim).slice(0,2): enemy.hp=0;enemy.damage_tick=sim.state.tick
			advance(sim,seen,120)
			check(regular(sim).size()==spec.garrison,"Two deaths restore only two garrison slots")
			var times: Array=seen.values();var sorted_times:=times.duplicate();sorted_times.sort()
			for i in range(1,sorted_times.size()): check(sorted_times[i]>sorted_times[i-1],"Admissions are split across ticks")
			var live_flags: Array=sim.state.props.filter(func(p):return p.s05_banner and not p.broken)
			for flag in live_flags.slice(0,live_flags.size()-1): sim._damage_prop(flag,10000,sim.state.fighters[0].id)
			check(S5.banners(sim)==1,"One remaining flag still controls reinforcements")
			victim=regular(sim)[0];victim.hp=0;victim.damage_tick=sim.state.tick
			advance(sim,seen,1)
			check(sim.state.ikki.pending.any(func(u):return u.source=="banner"),"Last flag still reserves the lost soldier")
			sim._damage_prop(live_flags.back(),10000,sim.state.fighters[0].id)
			var count:=regular(sim).size()
			advance(sim,seen,160)
			check(regular(sim).size()==count and not sim.state.ikki.pending.any(func(u):return u.source=="banner"),"Final flag cancels queued ordinary replacements")
			check(not sim.state.stage.go,"Surviving enemies keep the checkpoint locked after flags break")
			if number==12:
				for enemy in sim.state.fighters:
					if enemy.get("s05_weak",false): enemy.hp=0;enemy.damage_tick=sim.state.tick
				advance(sim,seen,360)
				check(sim.state.fighters.filter(func(f):return f.get("s05_weak",false) and f.hp>0).size()==2,"Kusei's throwable farmers replenish after all banners are gone")
			for enemy in sim.state.fighters:
				if enemy.team==1: enemy.hp=0;enemy.damage_tick=sim.state.tick
			advance(sim,seen,100)
			check(sim.state.stage.go or sim.state.phase=="won","Flags plus remaining enemies clear the current checkpoint")

func monk_checks() -> void:
	var sim:=node(6,1);var hero: Dictionary=sim.state.fighters[0]
	check(S5.spawn(sim,"militia",500,480).max_hp==66 and S5.spawn(sim,"militia",500,480,false,true).max_hp==33,"Farmer HP is baseline times 1.5 exactly once")
	for elite in [false,true]:
		var monk:=S5.spawn(sim,"monk",600,480,elite);sim.state.fighters=[hero,monk]
		check(monk.max_hp==(216 if elite else 144),"Monk HP doubles, elite retains relative 1.5 HP")
		for move in ["heavy","air_heavy","charged","charged_upper","charge_rain","body_collision"]:
			monk.hp=monk.max_hp;monk.invuln=0;monk.freeze=0;hero.action=move;hero.x=520;hero.y=480
			check(sim._damage(monk,1,hero.id,true,true,true,true,hero.x,hero.y,move),"Monk takes damage from "+move)
			sim._launch(monk,1,12,8)
			check(monk.z==0 and monk.vz==0 and not monk.airborne_lock and monk.action not in ["down","launched","recovering"],"Monk cannot be knocked down or airborne by "+move)
			check(monk.knockback>0,"Monk still receives horizontal knockback")
		for action in ["down","launched","thrown","recovering"]:
			sim._begin(monk,action);check(monk.action=="hurt" and monk.z==0,"Direct move transitions retain standing resistance")
		monk.hp=0;sim._begin(monk,"defeated");check(monk.action=="defeated","Standing resistance does not prevent death")
	var counts:=[]
	for elite in [false,true]:
		sim=node(6,1);hero=sim.state.fighters[0];hero.x=650;hero.y=480;hero.invuln=100000
		var monk:=S5.spawn(sim,"monk",600,480,elite);monk.cooldown=0
		sim.state.fighters=[hero,monk];sim.state.props=[];sim.state.ikki.pending=[]
		var starts:=0;var previous:=0
		for tick in 6000:
			sim.step([{}])
			if int(monk.get("attack_id",0))>previous: starts+=1;previous=int(monk.attack_id)
		counts.append(starts)
		check(S5.Data.timing({"s05_role":"monk","s05_elite":elite,"action":"s05_monk_heavy_attack"})[0]==(12 if elite else 18),"Heavy windup/contact stays at authored normal or elite timing")
	check(absf(float(counts[0])/(6000.0*3/291)-1.5)<.05,"Normal monk sustained attack frequency increases by about 50 percent")
	check(absf(float(counts[1])/counts[0]-1.5)<.06,"Elite sustained frequency remains about 1.5 times the revised ordinary monk")
	print("MONK_CADENCE normal=",counts[0]," elite=",counts[1]," over 6000 ticks")

func _initialize() -> void:
	banner_checks();monk_checks()
	print("STAGE05_REINFORCEMENTS_PASS %d checks"%checks)
	quit()
