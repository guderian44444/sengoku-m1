extends RefCounted

const Data = preload("res://core/stage07_10_data.gd")
const CAP := 12

static func begin(sim, spec: Dictionary) -> void:
	sim.state.fighters = sim.state.fighters.filter(func(f): return f.team==0)
	sim.state.props.clear(); sim.state.effects.clear(); sim.state.wet_zones.clear()
	var stage := int(sim.state.stage.id)
	sim.state.expedition = {"stage":stage,"node":int(spec.node),"phase":"combat","objective":str(spec.objective),"elapsed":0,"pending":[],"wave":1,"admit_tick":int(sim.state.tick)+10,"entry_seq":0,"boss":0,"hazards":[],"next_hazard":100,"hold_ticks":int(spec.hold_ticks),"civilians":[],"rescued":0,"civilian_total":0,"next_reinforce":300,"reinforcement_calls":0,"hint":str(spec.hint)}
	sim.state.stage.wave_total=2
	for i in spec.waves[0].size(): queue(sim,str(spec.waves[0][i]),stage==10 or i%3==2)
	for item in spec.objects:
		var kind := "gate" if item.asset=="gate" else str(item.asset)
		var shape: Array = {"gate":[100.0,85.0],"rock_support":[90.0,36.0],"signal":[55.0,36.0],"barricade":[150.0,58.0],"supplies":[72.0,38.0]}[kind]
		sim.state.props.append({"id":sim._next_id,"kind":"barricade" if kind in ["gate","barricade"] else ("crate" if kind=="supplies" else "fence"),"expedition_asset":kind,"x":float(item.x),"y":float(item.y),"hp":int(item.hp),"max_hp":int(item.hp),"width":shape[0],"depth":shape[1],"broken":false,"drop":"food" if kind=="supplies" else "","food_id":"rice" if kind=="supplies" else "","mandatory":bool(item.mandatory),"broken_tick":-1})
		sim._next_id+=1
	if str(spec.boss)!="":
		var boss := spawn(sim,str(spec.boss),minf(float(spec.end)-220,sim.camera_left(sim.state)+990),480)
		sim._place_enemy(boss);sim.state.fighters.append(boss)
		sim.state.expedition.boss=int(boss.id)
		sim.state.intro={"actor":boss.id,"name":boss.display_name,"line_key":"s%02d_%s_intro"%[stage,str(spec.boss)],"line":str(Data.BOSSES[spec.boss].line),"duration":90,"remaining_ticks":90,"announced":false,"blocking":true}
	if stage==9:
		for i in 3:
			sim.state.expedition.civilians.append({"x":float(sim.state.stage.encounter_start)+200+i*36,"y":float([390,480,570][i]),"safe":false,"walking":false})
		sim.state.expedition.civilian_total=3

static func spawn(sim, role: String, x: float, y: float) -> Dictionary:
	var boss := Data.BOSSES.has(role)
	var kind: String = "boss" if boss else {"spear":"soldier","archer":"archer","gunner":"gunner","shield":"shield_spear","raider":"raider"}[role]
	var hp := int(Data.BOSSES[role].hp) if boss else int({"spear":90,"archer":70,"gunner":82,"shield":130,"raider":104}[role])
	var players: int=sim.state.fighters.filter(func(f):return f.team==0).size()
	hp=roundi(hp*float(sim._difficulty.enemy_hp)*(1.65 if boss and players>1 else 1.0))
	var f: Dictionary=sim._make_fighter(1,kind,x,y,hp)
	f.expedition_role=role;f.expedition_stage=int(sim.state.stage.id);f.expedition_sequence=0;f.expedition_events=[];f.expedition_cooldown=0;f.expedition_target=0
	f.death_ticks=66;f.cooldown=55+int(f.id)%4*13
	if boss:
		f.display_name=str(Data.BOSSES[role].name);f.boss_variant=str(Data.BOSSES[role].variant)
		f.stage_boss=role in ["inaba","tatsuoki","iwanari","yoshikage"]
		f.weight="heavy";f.render_scale=1.24 if f.stage_boss else 1.1
	else: f.display_name={"spear":"長槍足輕","archer":"弓足輕","gunner":"鐵砲足輕","shield":"持盾槍兵","raider":"拔刀突擊兵"}[role]
	return f

static func queue(sim, role: String, left: bool) -> void:
	if sim.state.expedition.pending.size()<32: sim.state.expedition.pending.append({"role":role,"left":left})

static func admit(sim) -> void:
	var box: Dictionary=sim.state.expedition
	if box.pending.is_empty() or int(sim.state.tick)<int(box.admit_tick) or sim.state.fighters.size()>=48: return
	if sim.state.fighters.filter(func(f):return f.team==1 and f.hp>0).size()>=CAP: return
	var unit: Dictionary=box.pending.pop_front()
	var sequence: int=box.entry_seq
	var lane := float([392,568,440,520,480][sequence%5])
	var f := spawn(sim,str(unit.role),0,lane)
	sim._stage_entry(f,1 if unit.left else 0)
	sim.state.fighters.append(f)
	box.entry_seq+=1;box.admit_tick=int(sim.state.tick)+26+(sequence%3)*9

static func tick(sim) -> void:
	if sim.state.intro.get("blocking",false) and int(sim.state.intro.get("remaining_ticks",0))>0: return
	var box: Dictionary=sim.state.expedition
	if box.phase=="complete": return
	box.elapsed+=1
	var spec: Dictionary=sim._campaign.segments[sim.state.stage.index].encounters[sim.state.stage.checkpoint]
	for prop in sim.state.props:
		if prop.broken and int(prop.broken_tick)<0: prop.broken_tick=int(sim.state.tick)
	var alive: Array=sim.state.fighters.filter(func(f):return f.team==1 and f.hp>0)
	if box.wave==1 and box.pending.is_empty() and alive.filter(func(f):return f.kind!="boss").size()<=2:
		box.wave=2;sim.state.wave=2
		for i in spec.waves[1].size(): queue(sim,str(spec.waves[1][i]),box.stage==10 or i%2==0)
	admit(sim)
	if int(box.elapsed)>=int(box.next_hazard) and box.phase=="combat":
		box.next_hazard=int(box.elapsed)+int(spec.hazard_interval)
		environment_hazard(sim)
	tick_hazards(sim)
	if box.stage==9: evacuate_civilians(sim)
	if box.stage==10 and box.elapsed<box.hold_ticks and box.elapsed>=box.next_reinforce:
		box.next_reinforce+=300;box.reinforcement_calls+=1
		queue(sim,"raider",true);queue(sim,"spear",true)
	var clear: bool=box.wave==2 and box.pending.is_empty() and not sim.state.fighters.any(func(f):return f.team==1 and f.hp>0) and not sim.state.props.any(func(p):return p.mandatory and not p.broken)
	if not clear: return
	if box.stage==9 and box.rescued<box.civilian_total: return
	if box.stage==10:
		if box.elapsed<box.hold_ticks: return
		box.phase="evacuating";box.hazards.clear();box.hint="追兵已壓制：全隊前往右側撤離旗，不要留人殿後。"
		for hero in sim.state.fighters:
			if hero.team==0 and hero.hp>0 and (hero.x<float(sim.state.stage.encounter_end)-180 or hero.z>0): return
	box.phase="complete";box.hazards.clear()

static func focus(sim) -> Vector2:
	var party: Array=sim.state.fighters.filter(func(f):return f.team==0 and f.hp>0)
	var point := Vector2(sim.camera_left(sim.state)+640,480)
	if not party.is_empty():
		var target: Dictionary=party[int(sim.state.expedition.entry_seq)%party.size()]
		point=Vector2(target.x,target.y)
	return point

static func hazard(sim, kind: String, point: Vector2, radius: float, depth: float, warning: int, damage: int, owner: int=0, from_x: float=NAN) -> void:
	if sim.state.expedition.hazards.size()>=24: return
	point.x=clampf(point.x,float(sim.state.stage.encounter_start)+40,float(sim.state.stage.encounter_end)-40)
	point.y=clampf(point.y,365,595)
	sim.state.expedition.hazards.append({"kind":kind,"x":point.x,"y":point.y,"radius":radius,"depth":depth,"age":0,"warning":warning,"life":warning+30,"owner":owner,"damage":damage,"hit":false,"from_x":point.x-20 if not is_finite(from_x) else from_x})

static func environment_hazard(sim) -> void:
	var box: Dictionary=sim.state.expedition
	var target := focus(sim)
	match int(box.stage):
		7:
			if not sim.state.props.any(func(p):return p.expedition_asset=="rock_support" and not p.broken): return
			hazard(sim,"rock",target,86,43,85,22)
			if int(box.node)>=5: hazard(sim,"rock",target+Vector2(170,-100 if target.y>480 else 100),74,38,112,20)
		8:
			if not sim.state.props.any(func(p):return p.expedition_asset=="signal" and not p.broken): return
			var safe_lane := (int(box.elapsed)/int(sim._campaign.segments[sim.state.stage.index].encounters[sim.state.stage.checkpoint].hazard_interval))%3
			for lane in 3:
				if lane!=safe_lane: hazard(sim,"arrows",Vector2(target.x,[395,480,565][lane]),300,30,90,16)
		9:
			if not sim.state.fighters.any(func(f):return f.team==1 and f.hp>0 and f.kind=="gunner"): return
			var lane := float([400,480,560][int(box.entry_seq)%3])
			hazard(sim,"fireline",Vector2(sim.camera_left(sim.state)+640,lane),620,24,82,18,0,sim.camera_left(sim.state)+(-100 if int(box.entry_seq)%2==0 else 1380))
		10:
			if box.elapsed>=box.hold_ticks or not sim.state.fighters.any(func(f):return f.team==1 and f.hp>0): return
			hazard(sim,"arrows",target,160,44,92,18)

static func tick_hazards(sim) -> void:
	var box: Dictionary=sim.state.expedition
	for h in box.hazards:
		h.age+=1
		if h.owner>0:
			var owner: Dictionary=sim._fighter(int(h.owner))
			if owner.is_empty() or owner.hp<=0: h.life=0;continue
		if h.age!=h.warning or h.hit: continue
		h.hit=true
		var effect := "slam" if h.kind in ["rock","powder","quake"] else "arrow_impact"
		sim._effect(effect,h.x,h.y,24,{"radius":h.radius,"wet":false})
		for hero in sim.state.fighters:
			if hero.team!=0 or hero.hp<=0: continue
			if absf(hero.x-h.x)>float(h.radius)+20 or absf(hero.y-h.y)>float(h.depth)+12: continue
			if hero.z>(35 if h.kind=="quake" else 90): continue
			if h.kind=="fireline" and cover_between(sim,hero,float(h.from_x)): continue
			sim._damage(hero,roundi(int(h.damage)*float(sim._difficulty.enemy_damage)),int(h.owner),false,true,false,false,float(h.from_x),float(h.y),"",24,"blunt" if h.kind in ["rock","quake"] else ("bullet" if h.kind=="fireline" else "arrow"))
	box.hazards=box.hazards.filter(func(h):return h.age<h.life)

static func cover_between(sim, hero: Dictionary, from_x: float) -> bool:
	return sim.state.props.any(func(p):return not p.broken and p.expedition_asset=="barricade" and absf(p.y-hero.y)<p.depth*.5+12 and p.x>minf(from_x,hero.x) and p.x<maxf(from_x,hero.x))

static func evacuate_civilians(sim) -> void:
	var box: Dictionary=sim.state.expedition
	var enemies: Array=sim.state.fighters.filter(func(f):return f.team==1 and f.hp>0 and not f.get("entering",false))
	var party: Array=sim.state.fighters.filter(func(f):return f.team==0 and f.hp>0)
	for c in box.civilians:
		if c.safe: continue
		var enemy_near: bool=enemies.any(func(f):return absf(f.x-c.x)<165 and absf(f.y-c.y)<65)
		var covered: bool=party.any(func(f):return absf(f.x-c.x)<420)
		var blocked: bool=sim.state.props.any(func(p):return not p.broken and p.expedition_asset!="supplies" and absf(p.x-c.x)<p.width*.5+18 and absf(p.y-c.y)<p.depth*.5+10)
		var warned: bool=box.hazards.any(func(h):return h.age<h.warning and absf(h.x-c.x)<h.radius and absf(h.y-c.y)<h.depth+12)
		c.walking=not enemy_near and not blocked and not warned and (covered or enemies.is_empty())
		if c.walking: c.x+=1.8
		if c.x>=float(sim.state.stage.encounter_end)-170:
			c.safe=true;c.walking=false;box.rescued+=1
			sim._event("challenge_complete",c.x,c.y,0,0,{"amount":100})
			for hero in party: hero.gold=mini(1000000000,int(hero.gold)+100)

static func start(sim, f: Dictionary, action: String, target: Dictionary) -> void:
	f.expedition_sequence+=1;f.expedition_events=[];f.expedition_target=int(target.id)
	f.target_x=float(target.x);f.target_y=float(target.y);f.face=1 if target.x>=f.x else -1
	f.attack_id=int(f.get("attack_id",0))+1
	sim._begin(f,action)
	var move: Dictionary=Data.ACTIONS[action]
	if move.kind=="reinforce": f.expedition_cooldown=int(sim.state.tick)+1200
	sim._event("swing",f.x,f.y,f.id,0,{"action":action,"combo":0,"heavy_combo":0,"finisher":false})
	if move.kind not in ["burst","rain","powder","crossfire","reinforce"]: warning(sim,f,move)

static func warning(sim, f: Dictionary, move: Dictionary) -> void:
	sim.state.effects=sim.state.effects.filter(func(e):return not (e.get("expedition_warning",false) and e.get("owner",0)==f.id))
	var advance := 108.0 if move.kind in ["charge","draw"] else (3.8*(float(move.hits[0])-24) if move.kind=="flank" else (1.8*(float(move.hits[-1])-float(move.hits[0])+11) if move.kind=="advance" else 0.0))
	var reach := float(move.reach)+advance
	var depth := float(move.depth)+(absf(float(f.target_y)-float(f.y)) if move.kind=="flank" else 0.0)
	sim._effect("warning",f.x+f.face*(reach-15)*.5,f.y,maxi(1,int(move.hits[-1])-int(f.action_tick)),{"owner":f.id,"radius":(reach+15)*.5,"depth":depth,"face":f.face,"expedition_warning":true})

static func ai(sim, f: Dictionary, target: Dictionary) -> bool:
	if not f.has("expedition_role") or not Data.BOSSES.has(str(f.expedition_role)): return false
	if f.action!="idle" or f.freeze>0 or f.stun>0: return true
	var dx: float=target.x-f.x;var dy: float=target.y-f.y
	f.face=1 if dx>=0 else -1
	var actions: Array=Data.BOSSES[f.expedition_role].actions
	var action := str(actions[int(f.ai_cycle)%actions.size()])
	if Data.ACTIONS[action].kind=="reinforce" and (int(sim.state.tick)<int(f.expedition_cooldown) or int(sim.state.expedition.reinforcement_calls)>=4): action=str(actions[0])
	var move: Dictionary=Data.ACTIONS[action]
	var ranged: bool=move.kind in ["burst","rain","powder","crossfire","reinforce"]
	var reach: float=float(move.reach) if ranged else (float(move.reach)+160 if move.kind in ["charge","draw","flank"] else float(move.reach)*.9)
	if absf(dx)<=reach and (ranged or absf(dy)<60) and f.cooldown==0:
		f.ai_cycle+=1;start(sim,f,action,target)
	else:
		var mx := signf(dx) if absf(dx)>reach*.75 else 0.0
		if ranged and absf(dx)<180 and f.cooldown>15: mx=-float(f.face)
		var my := signf(dy) if absf(dy)>8 else 0.0
		var before: float=f.x
		sim._move_fighter(f,mx*2.25,my*1.65)
		if mx!=0 and is_equal_approx(before,f.x): sim._move_fighter(f,0,(-1 if f.y>480 else 1)*2.1)
		f.move_dx=int(mx);f.move_dy=int(my)
	return true

static func accepts_damage(sim, f: Dictionary, actor: int, source_x: float=NAN, source_y: float=NAN, heavy: bool=false, source_action: String="") -> bool:
	if not f.has("expedition_role") or not Data.ACTIONS.has(str(f.action)): return true
	var move: Dictionary=Data.ACTIONS[f.action]
	if move.kind!="counter" or f.action_tick<12 or f.action_tick>=int(move.hits[0])-12 or f.stun>0 or f.freeze>0: return true
	if heavy or source_action in ["charged","dash_heavy","air_heavy","throw","body_collision","charged_upper","charged_slam"]: return true
	var attacker: Dictionary=sim._fighter(actor)
	if not is_finite(source_x): source_x=float(attacker.get("x",f.x))
	if not is_finite(source_y): source_y=float(attacker.get("y",f.y))
	if (source_x-f.x)*f.face<=0 or absf(source_y-f.y)>90: return true
	if f.guard_hit_tick==0:
		sim._effect("guard",f.x,f.y,12,{"target":f.id,"face":f.face})
		sim._event("guard",f.x,f.y,actor,f.id)
	f.guard_hit_tick=10
	return false

static func attack(sim, f: Dictionary) -> bool:
	if not f.has("expedition_role") or not Data.ACTIONS.has(str(f.action)): return false
	if f.stun>0 or f.freeze>0: return true
	var move: Dictionary=Data.ACTIONS[f.action]
	var tick := int(f.action_tick)
	var first := int(move.hits[0])
	if move.kind in ["charge","draw"] and tick>=first-18 and tick<first: sim._move_fighter(f,f.face*6.0,0,true)
	if move.kind=="flank" and tick>=16 and tick<first-8:
		sim._move_fighter(f,f.face*3.8,signf(float(f.target_y)-f.y)*3.0,true)
	if move.kind=="advance" and tick>=first-10 and tick<=int(move.hits[-1]): sim._move_fighter(f,f.face*1.8,0,true)
	if move.kind=="withdraw" and tick>int(move.hits[-1])+5 and tick<int(move.duration)-10: sim._move_fighter(f,-f.face*3.5,0,true)
	if move.kind=="turn" and tick==24:
		var target: Dictionary=sim._fighter(int(f.expedition_target))
		if not target.is_empty(): f.face=1 if target.x>=f.x else -1;f.target_y=target.y
		warning(sim,f,move)
	for index in move.hits.size():
		if tick!=int(move.hits[index]) or index in f.expedition_events: continue
		f.expedition_events.append(index)
		release(sim,f,move,index)
	if tick>=int(move.duration):
		f.cooldown=38 if not f.stage_boss else 32
		sim._begin(f,"idle")
	return true

static func release(sim, f: Dictionary, move: Dictionary, index: int) -> void:
	var point := Vector2(f.target_x,f.target_y)
	match str(move.kind):
		"burst":
			# Three fixed, visibly staggered shots; later shots do not track a dodging player.
			var lane := float(f.target_y)+(index-1)*34
			hazard(sim,"fireline",Vector2((float(f.x)+float(f.target_x))*.5,lane),absf(float(f.target_x)-float(f.x))*.5+180,14,24,int(move.damage),int(f.id),float(f.x))
			sim._event("gunshot",f.x,f.y,f.id,0)
		"powder":
			hazard(sim,"powder",point,110,62,68,int(move.damage),int(f.id))
		"rain":
			var safe_lane := (int(f.expedition_sequence)+index)%3
			for lane in 3:
				if lane!=safe_lane: hazard(sim,"arrows",Vector2(point.x+index*55,[395,480,565][lane]),260,28,65,int(move.damage),int(f.id))
			sim._event("bow_release",f.x,f.y,f.id,0)
		"crossfire":
			var lane := float([405,555,480][index%3])
			hazard(sim,"fireline",Vector2(sim.camera_left(sim.state)+640,lane),620,22,60,int(move.damage),int(f.id),sim.camera_left(sim.state)+(-100 if index%2==0 else 1380))
			sim._event("gunshot",f.x,f.y,f.id,0)
		"reinforce":
			if sim.state.expedition.reinforcement_calls<4:
				queue(sim,"shield",false);queue(sim,"raider",true)
				sim.state.expedition.reinforcement_calls+=1
			hazard(sim,"arrows",point,160,45,75,int(move.damage),int(f.id))
		"quake":
			sim._enemy_melee(f,float(move.reach),float(move.depth),int(move.damage),"down")
			for n in 3: hazard(sim,"quake",Vector2(f.x+f.face*(120+n*120),f.y),90,54,18+n*14,18,int(f.id))
		_:
			sim._enemy_melee(f,float(move.reach),float(move.depth),int(move.damage),"push" if move.kind in ["low","cross","advance","charge","draw"] else "")
			if move.kind=="hook":
				for hero in sim.state.fighters:
					if hero.team==0 and hero.hp>0 and hero.damage_tick==sim.state.tick and hero.z<45 and absf(hero.y-f.y)<float(move.depth) and (hero.x-f.x)*f.face>0 and absf(hero.x-f.x)<float(move.reach): hero.knockback=-f.face*10.0
