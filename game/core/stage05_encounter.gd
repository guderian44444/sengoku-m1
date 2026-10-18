extends RefCounted

const Data = preload("res://core/stage05_data.gd")
# Initial balance choices; authored timings and requested mechanics are separate.
const HP := {"militia":66,"sickle_farmer":66,"hunting_bow_farmer":66,"monk":144,"hachiya":640,"natsume":760,"kusei":1200}
const CAP := 24
const ROAR_COOLDOWN_TICKS := 480
const STOMP_COOLDOWN_TICKS := 1200
const VOICES := {"s05_hachiya_rapid":"hachiya_tsuranuke","s05_hachiya_return":"hachiya_nigasan","s05_natsume_ground":"natsume_tatakikiru","s05_natsume_diagonal":"natsume_fukitobe","s05_natsume_sweep":"natsume_fukitobe","s05_kusei_guard":"kusei_fudo","s05_kusei_slash":"kusei_kiru","s05_kusei_summon":"kusei_kitare"}

static func begin(sim, spec: Dictionary) -> void:
	sim.state.fighters = sim.state.fighters.filter(func(f): return f.team == 0)
	sim.state.effects.clear(); sim.state.props.clear(); sim.state.wet_zones.clear()
	sim.state.ikki = {"node":int(spec.node),"phase":"combat","pending":[],"admit_tick":int(sim.state.tick)+12,"farmer_tick":0,"entry_seq":0,"boss":0,"thresholds":[],"summons":[],"summon_count":0}
	sim.state.stage.wave_total = 1
	for i in int(spec.garrison): queue(sim,str(spec.role),false,false,"banner",12+i*31)
	if str(spec.boss) != "":
		assert(admit(sim,str(spec.boss)))
	for i in spec.objects.size():
		var item: Dictionary = spec.objects[i]
		var flag := str(item.asset).contains("_")
		var hp := roundi(165 * 0.5) if flag else 65
		sim.state.props.append({"id":sim._next_id,"kind":"fence" if flag else "jar","s05_asset":item.asset,"s05_banner":flag,"x":item.x,"y":item.y,"hp":hp,"max_hp":hp,"width":52.5 if flag else 110.0,"depth":25.0 if flag else 45.0,"broken":false,"drop":"","mandatory":flag,"broken_tick":-1})
		sim._next_id+=1
	if spec.boss == "kusei":
		queue(sim,"militia",false,true,"farmer",60); queue(sim,"militia",false,true,"farmer",150)
		sim.state.ikki.farmer_tick = sim.state.tick+120

static func spawn(sim, role: String, x: float, y: float, elite: bool = false, weak: bool = false) -> Dictionary:
	var players: int = sim.state.fighters.filter(func(f): return f.team == 0).size()
	var boss := role in ["hachiya","natsume","kusei"]
	var hp := roundi((33.0 if weak else float(HP[role]))*(0.8 if role in Data.FARMERS else 1.0)*float(sim._difficulty.enemy_hp)*(1.5 if elite else 1.0)*(1.7 if boss and players>1 else 1.0))
	var f: Dictionary = sim._make_fighter(1,"boss" if boss else ("archer" if role=="hunting_bow_farmer" else "soldier"),x,y,hp)
	f.s05_role=role; f.s05_elite=elite; f.s05_weak=weak; f.s05_events=[]; f.s05_combo=[]; f.s05_root_px=0.0; f.s05_target=0
	f.s05_move_clip="walk"
	f.death_ticks=60; f.cooldown=45+int(f.id)%5*11; f.down_ticks=ceili(Data.duration(role,"down")*.06)
	if boss:
		f.display_name={"hachiya":"蜂屋貞次","natsume":"夏目吉信","kusei":"空誓"}[role]
		f.stage_boss=role=="kusei"; f.weight="heavy"
		if role=="kusei": f.s05_summon_shield=false;f.s05_roar_ready_tick=0;f.s05_stomp_ready_tick=0
	else: f.display_name="精銳僧兵" if elite else {"monk":"僧兵","militia":"鋤頭農民","sickle_farmer":"鐮刀農民","hunting_bow_farmer":"獵弓農民"}[role]
	return f

static func queue(sim, role: String, elite: bool, weak: bool, source: String, delay: int) -> void:
	if role=="militia": role=Data.FARMERS[(int(sim.state.ikki.entry_seq)+sim.state.ikki.pending.size())%Data.FARMERS.size()]
	sim.state.ikki.pending.append({"role":role,"elite":elite,"weak":weak,"source":source,"due":int(sim.state.tick)+delay})

static func banners(sim) -> int:
	return sim.state.props.filter(func(p):return p.get("s05_banner",false) and not p.broken).size()

static func admit(sim, role: String, elite: bool = false, weak: bool = false) -> bool:
	if sim.state.fighters.size() >= 48 or sim.state.fighters.filter(func(f):return f.team==1 and f.hp>0).size() >= CAP: return false
	var seq: int=sim.state.ikki.entry_seq
	var from_left: bool=[false,true,false,false,true,true,false][seq%7]
	var party: Array=sim.state.fighters.filter(func(f):return f.team==0 and f.hp>0)
	if party.is_empty(): return false
	var xs: Array=party.map(func(f):return float(f.x))
	# Main clamps its camera inside this envelope, including eased checkpoint scrolling.
	var visible_left := maxf(0,float(xs.max())-1200)
	var visible_right := minf(float(sim.state.stage.encounter_end),maxf(0,float(xs.min())-80)+1280)
	var margin := 320.0+float(seq%3)*53
	var x := visible_left-margin if from_left else visible_right+margin
	var y := float([382,548,432,586,474,404,522][(seq*3+int(sim.state.ikki.node))%7])
	var f := spawn(sim,role,x,y,elite,weak)
	f.entering=true;f.face=1 if from_left else -1
	f.entry_x=clampf(sim.camera_left(sim.state)+(130 if from_left else 1150),sim._left_edge()+50,sim._right_edge()-30)
	sim.state.fighters.append(f);sim.state.ikki.entry_seq+=1
	if f.kind=="boss": sim.state.ikki.boss=int(f.id)
	return true

static func tick(sim) -> void:
	var box: Dictionary=sim.state.ikki
	var spec: Dictionary=sim._campaign.segments[sim.state.stage.index].encounters[sim.state.stage.checkpoint]
	var boss: Dictionary=sim._fighter(int(box.boss))
	var alive_boss: bool = not boss.is_empty() and boss.hp>0
	var ordinary: Array=sim.state.fighters.filter(func(f): return f.team==1 and f.hp>0 and f.kind!="boss" and not f.get("s05_weak",false) and not f.get("s05_elite",false))
	if banners(sim)>0:
		var waiting: int=box.pending.filter(func(u):return u.source=="banner").size()
		for i in maxi(0,int(spec.garrison)-ordinary.size()-waiting):
			queue(sim,str(spec.role),false,false,"banner",45+(int(box.entry_seq)+i)*17%31)
	else:
		box.pending=box.pending.filter(func(u):return u.source!="banner")
	if alive_boss and boss.s05_role=="kusei":
		thresholds(sim,boss)
		var farmers: int=sim.state.fighters.filter(func(f):return f.get("s05_weak",false) and f.hp>0).size()+box.pending.filter(func(u):return u.source=="farmer").size()
		if farmers<2 and sim.state.tick>=box.farmer_tick:
			queue(sim,"militia",false,true,"farmer",45);box.farmer_tick=sim.state.tick+120
	else:
		box.summons.clear()
		box.pending=box.pending.filter(func(u):return u.source!="farmer")
	if not box.pending.is_empty() and sim.state.tick>=box.admit_tick:
		box.pending.sort_custom(func(a,b):return int(a.due)<int(b.due))
		var unit: Dictionary=box.pending[0]
		if sim.state.tick>=unit.due and admit(sim,unit.role,unit.elite,unit.weak):
			box.pending.pop_front();box.admit_tick=sim.state.tick+int([23,41,29,47,31][int(box.entry_seq)%5])
	if alive_boss and boss.get("s05_summon_shield",false):
		boss.s05_summon_shield=box.pending.any(func(u):return u.role=="monk") or sim.state.fighters.any(func(f):return f.get("s05_role","")=="monk" and f.hp>0)
	for prop in sim.state.props:
		if not prop.broken: continue
		if int(prop.broken_tick)<0: prop.broken_tick=sim.state.tick
		var age: int=sim.state.tick-int(prop.broken_tick)
		if str(prop.s05_asset).contains("_"):
			if age==8: audio(sim,"s05.prop.banner.wood_crack",0)
			if age==36: audio(sim,"s05.prop.banner.ground_contact",0)
		elif age==6:
			audio(sim,{"rice":"s05.prop.rice_sack.hit","wood":"s05.prop.firewood_basket.break","jar":"s05.prop.ceramic.break"}[prop.s05_asset],0)
	for hero in sim.state.fighters:
		if hero.team!=0 or int(hero.get("s05_combo_owner",0))==0: continue
		var owner: Dictionary=sim._fighter(int(hero.s05_combo_owner))
		if owner.is_empty() or owner.hp<=0 or owner.action!="s05_kusei_slash": hero.s05_combo_owner=0
	if banners(sim)==0 and box.pending.is_empty() and not sim.state.fighters.any(func(f):return f.team==1 and f.hp>0): box.phase="complete"

static func parries_light(f: Dictionary, attacker: Dictionary, action: String, attack_id: int) -> bool:
	if f.get("s05_role","")!="monk" or attacker.get("team",1)!=0 or action not in ["light","air_light"]: return false
	if f.held_by!=0 or f.z>0 or f.airborne_lock or f.freeze>0 or f.stun>0 or f.action in ["down","recovering","thrown","grabbed","defeated"]: return false
	# One replay-stable result per swing, including repeated contact callbacks.
	return (attack_id*73+int(f.id)*37+int(attacker.id)*17)%100<30

static func thresholds(sim, f: Dictionary) -> void:
	if f.hp<=0: return
	for threshold in [70,40,10]:
		if f.hp*100<=f.max_hp*threshold and threshold not in sim.state.ikki.thresholds:
			sim.state.ikki.thresholds.append(threshold)
			sim.state.ikki.summons.append(threshold)

static func start(sim, f: Dictionary, action: String, target: Dictionary = {}) -> void:
	f.s05_events=[]; f.s05_combo=[]; f.s05_root_px=float(Data.row(f.s05_role,action,0).get("root_motion_px",0))
	f.s05_target=int(target.get("id",0))
	if not target.is_empty(): f.face=1 if target.x>=f.x else -1
	sim._begin(f,action)
	f.attack_id=int(f.get("attack_id",0))+1
	if action=="s05_kusei_roar": f.s05_roar_ready_tick=int(sim.state.tick)+ROAR_COOLDOWN_TICKS
	if action=="s05_kusei_stomp":
		f.s05_stomp_ready_tick=int(sim.state.tick)+STOMP_COOLDOWN_TICKS
		f.stun=0; f.freeze=0; f.knockback=0.0; f.z=0.0; f.vz=0.0; f.airborne_lock=false
		audio(sim,"kusei_stomp_full",int(f.id))
	elif VOICES.has(action): audio(sim,VOICES[action],int(f.id))

static func ai(sim, f: Dictionary, target: Dictionary) -> bool:
	if not f.has("s05_role"): return false
	if f.action!="idle": return true
	var dx: float=target.x-f.x; var dy: float=target.y-f.y
	f.face=1 if dx>=0 else -1
	if f.s05_role=="kusei" and not f.get("s05_summon_shield",false) and not sim.state.ikki.summons.is_empty():
		sim.state.ikki.summons.pop_front(); start(sim,f,"s05_kusei_summon",target); return true
	if f.s05_role=="kusei" and Vector2(dx,dy).length()>300 and f.cooldown==0 and int(sim.state.tick)>=int(f.s05_roar_ready_tick):
		start(sim,f,"s05_kusei_roar",target); return true
	var reach: float={"militia":100.0,"sickle_farmer":100.0,"hunting_bow_farmer":420.0,"monk":155.0,"hachiya":210.0,"natsume":245.0,"kusei":225.0}[f.s05_role]
	if f.s05_role=="natsume" and absf(dy)<42 and (absf(dx)<=165 or ((target.z>12 or target.vz>0) and absf(dx)<=reach)):
		f.cooldown=0
	if absf(dx)<=reach and absf(dy)<42 and f.cooldown==0:
		var action := ""
		match f.s05_role:
			"militia": action="s05_militia_attack"
			"sickle_farmer": action="s05_sickle_farmer_attack"
			"hunting_bow_farmer": action="s05_hunting_bow_farmer_shot"
			"monk": action="s05_monk_quick_attack" if f.ai_cycle%3!=2 else "s05_monk_heavy_attack"
			"hachiya": action=["s05_hachiya_rapid","s05_hachiya_return","s05_hachiya_sweep"][f.ai_cycle%3]
			"natsume":
				# Lock a choice from the current target state, not later client inputs.
				action="s05_natsume_diagonal" if target.z>12 or target.vz>0 else ("s05_natsume_sweep" if absf(dx)<=165 else "s05_natsume_ground")
			"kusei":
				action=["s05_kusei_slash","s05_kusei_guard","s05_kusei_stomp"][f.ai_cycle%3]
				if action=="s05_kusei_stomp" and int(sim.state.tick)<int(f.s05_stomp_ready_tick): action="s05_kusei_slash"
		f.ai_cycle+=1; start(sim,f,action,target)
	else:
		var speed: float=(1.2 if f.s05_weak else (1.8 if f.kind!="boss" else 2.4))*Data.speed(f)
		var mx := signf(dx) if absf(dx)>reach*.78 else 0.0
		var my := signf(dy) if absf(dy)>6 else 0.0
		f.s05_move_clip="walk"
		if f.s05_role=="hachiya" and absf(dx)>320:
			f.s05_move_clip="run";speed=3.6
		elif f.s05_role=="kusei" and f.cooldown>20 and absf(dx)<110:
			mx=-float(f.face);f.face=int(mx);f.s05_move_clip="retreat_run";speed=3.0
		elif f.s05_role=="hunting_bow_farmer" and f.cooldown>20 and absf(dx)<145:
			mx=-float(f.face);f.s05_move_clip="retreat"
		if f.s05_role=="kusei": speed*=1.15
		var before: float=f.x
		sim._move_fighter(f,mx*speed,my*speed*.65)
		if mx!=0 and is_equal_approx(before,f.x): sim._move_fighter(f,0,(-1 if f.y>480 else 1)*speed)
		f.move_dx=int(mx); f.move_dy=int(my)
	return true

static func invulnerable(f: Dictionary) -> bool:
	return f.get("s05_role","")=="kusei" and (f.get("s05_summon_shield",false) or (f.action=="s05_kusei_stomp" and f.action_tick<300))

static func guard_active(f: Dictionary) -> bool:
	return f.get("s05_role","")=="kusei" and f.action=="s05_kusei_guard" and f.action_tick>=18 and f.action_tick<120

static func accepts_damage(sim, f: Dictionary, actor: int, source_body: int) -> bool:
	if invulnerable(f): return false
	if not guard_active(f): return true
	var body: Dictionary=sim._fighter(source_body)
	return not body.is_empty() and body.get("s05_role","") in Data.FARMERS and int(body.thrown_by)==actor and body.throw_ticks>0

static func audio(sim, cue: String, actor: int) -> void:
	var f: Dictionary=sim._fighter(actor)
	sim._event("stage05_audio",float(f.get("x",0)),float(f.get("y",480)),actor,0,{"cue":cue})

static func strike(sim, f: Dictionary, reach: float, depth: float, amount: int, launch: bool = false, locked: bool = false, excluded: Array = []) -> Array:
	var hit := []
	for target in sim.state.fighters:
		if target.team!=0 or target.hp<=0 or target.id in excluded: continue
		if locked:
			if target.id not in f.s05_combo: continue
		elif (target.x-f.x)*f.face < -22 or (target.x-f.x)*f.face>reach or absf(target.y-f.y)>depth or target.z>60: continue
		if sim._damage(target,maxi(1,roundi(amount*(0.7 if f.s05_role in Data.FARMERS else 1.0)*sim._difficulty.enemy_damage)),f.id,false,true,locked,launch,f.x,f.y,f.action,24,"spear" if f.s05_role=="hachiya" else "sword"):
			hit.append(int(target.id))
			if launch: sim._launch(target,f.face,9,8)
	return hit

static func quake(sim, f: Dictionary) -> void:
	# Deliberately bypass only prone protection for this exact boss action.
	for target in sim.state.fighters:
		if target.team!=0 or target.hp<=0: continue
		if Vector2(target.x-f.x,(target.y-f.y)/.55).length()>205: continue
		var amount := maxi(1,roundi(19*sim._difficulty.enemy_damage))
		if sim._damage(target,amount,f.id,false,true,true,true,f.x,f.y,"s05_kusei_stomp",24,"blunt"):
			var direction := 1 if target.x>=f.x else -1
			sim._launch(target,direction,9,6)

static func attack(sim, f: Dictionary) -> bool:
	if not f.has("s05_role") or not Data.HITS.has(f.action): return false
	if f.stun>0 or f.freeze>0: return true
	var action: String=f.action
	var tick: int=f.action_tick
	var speed := Data.speed(f)
	var row: Dictionary=Data.row(f.s05_role,action,tick*1000.0/60*speed)
	var root_px := float(row.get("root_motion_px",0))
	var delta := root_px-float(f.s05_root_px)
	if delta!=0: sim._move_fighter(f,delta*Data.height(f.s05_role)/float(row.body_height)*f.face)
	f.s05_root_px=root_px
	if action=="s05_kusei_guard":
		if Data.crossed(tick,300): audio(sim,"s05.kusei.guard_enter",f.id)
		if Data.crossed(tick,2000): audio(sim,"s05.kusei.guard_release",f.id)
	if action=="s05_hachiya_sweep" and Data.crossed(tick,420): audio(sim,"s05.hachiya.spear_sweep",f.id)
	if action=="s05_hachiya_return" and Data.crossed(tick,580): audio(sim,"s05.hachiya.return_thrust",f.id)
	if action=="s05_natsume_ground" and Data.crossed(tick,230): audio(sim,"s05.natsume.downstroke_whoosh",f.id)
	for i in Data.HITS[action].size():
		var event_key := "hit-%d"%i
		if not Data.crossed(tick,Data.HITS[action][i],speed) or event_key in f.s05_events: continue
		f.s05_events.append(event_key)
		match action:
			"s05_kusei_stomp": quake(sim,f)
			"s05_kusei_roar":
				var target: Dictionary=sim._fighter(int(f.s05_target))
				var direction := Vector2(float(target.get("x",f.x+f.face*900))-float(f.x),float(target.get("y",f.y))-float(f.y)).normalized()
				sim._effect("s05_roar",f.x+f.face*65,f.y,120,{"owner":f.id,"team":1,"face":f.face,"z":112.0,"vx":direction.x*16,"vy":direction.y*16,"radius":60.0,"hit_ids":[],"damage":maxi(1,roundi(12*sim._difficulty.enemy_damage)),"action":action})
				audio(sim,"kusei_roar",f.id)
			"s05_kusei_summon":
				audio(sim,"s05.kusei.palm_clap",f.id)
				if i==1:
					for n in 4: queue(sim,"monk",true,false,"summon",18+n*31)
					sim.state.ikki.summon_count+=1
					f.s05_summon_shield=true
			"s05_kusei_slash":
				audio(sim,"s05.kusei.blade_swing",f.id)
				var hit := strike(sim,f,225,58,18,i==2,i>0)
				if i==0: f.s05_combo=hit
				for id in hit:
					var target: Dictionary=sim._fighter(id)
					if i<2: target.stun=maxi(target.stun,30); target.s05_combo_owner=f.id
					else: target.s05_combo_owner=0
			"s05_hachiya_rapid","s05_hachiya_return":
				strike(sim,f,218,43,13 if action.ends_with("rapid") else 23)
				var tip: Array=row.get("weapon_tip",row.anchor)
				var scale := Data.height("hachiya")/float(row.body_height)
				sim._effect("s05_fx",f.x+(float(tip[0])-float(row.anchor[0]))*scale*f.face,f.y,8,{"s05_asset":"rapid" if action.ends_with("rapid") else "return","z":(float(row.anchor[1])-float(tip[1]))*scale,"owner":f.id,"face":f.face,"angle":float(row.get("weapon_angle_degrees",0))})
				if action.ends_with("rapid"): audio(sim,"s05.hachiya.fast_thrust",f.id)
			"s05_hachiya_sweep": strike(sim,f,225,75,22,true)
			"s05_natsume_ground","s05_natsume_diagonal","s05_natsume_sweep": wave(sim,f)
			"s05_militia_attack":
				audio(sim,"s05.farmer.hoe_swing",f.id)
				if not strike(sim,f,100,40,6 if f.s05_weak else 10).is_empty(): audio(sim,"s05.farmer.hoe_impact",f.id)
			"s05_sickle_farmer_attack": sim._weapon_release(f,"sword")
			"s05_hunting_bow_farmer_shot": farmer_arrow(sim,f,row)
			"s05_monk_quick_attack","s05_monk_heavy_attack":
				var heavy: bool=action.ends_with("heavy_attack")
				audio(sim,"s05.monk.naginata_heavy_sweep" if heavy else "s05.monk.naginata_quick_swing",f.id)
				if not strike(sim,f,160,47,19 if heavy else 12,heavy).is_empty(): audio(sim,"s05.monk.naginata_impact",f.id)
	if action=="s05_sickle_farmer_attack" and tick*1000.0/60>=260 and tick*1000.0/60<360:
		f.s05_combo.append_array(strike(sim,f,100,40,6 if f.s05_weak else 10,false,false,f.s05_combo))
	if tick>=int(Data.timing(f)[1]):
		f.cooldown=ceili((50 if f.kind=="boss" else 65)/speed)
		if f.s05_role=="natsume": f.cooldown=18
		if f.s05_role=="monk":
			# Increase full attack-cycle frequency while retaining the authored windup and contact frame.
			var original_ticks := ceili(Data.duration("monk",action)*.06)
			f.cooldown=maxi(1,ceili((original_ticks+65)/1.5/speed)-int(Data.timing(f)[1]))
		sim._begin(f,"idle")
	return true

static func farmer_arrow(sim, f: Dictionary, row: Dictionary) -> void:
	var scale := Data.height(f.s05_role)/float(row.body_height)
	var point: Array=row.projectile_spawn_estimate
	var arrow: Dictionary=Data.read("../stage5-farmers/arrow.json")
	var tip_offset := (float(arrow.tip_estimate[0])-float(arrow.anchor[0]))*scale
	var index: int=sim.state.effects.size()
	sim._projectile(f,maxi(1,roundi((6 if f.s05_weak else 10)*0.7*sim._difficulty.enemy_damage)),0,false,"arrow")
	if sim.state.effects.size()==index: return
	var shot: Dictionary=sim.state.effects[index]
	# Collision follows the arrow tip; the painted asset is anchored at its nock.
	shot.x=f.x+((float(point[0])-float(row.anchor[0]))*scale+tip_offset)*f.face
	shot.origin_x=shot.x;shot.z=(float(row.anchor[1])-float(point[1]))*scale
	shot.start_z=shot.z;shot.vx=(float(shot.target_x)-float(shot.origin_x))/int(shot.flight_ticks)
	shot.s05_arrow=true

static func wave(sim, f: Dictionary) -> void:
	var kind: String = f.action.trim_prefix("s05_natsume_")
	var scale := Data.height("natsume")/691.2
	var distance := (600.0 if kind=="diagonal" else 700.0)*scale
	var duration := 21
	var vz := (320.0*scale/duration) if kind=="diagonal" else 0.0
	sim._effect("s05_wave",f.x+f.face*70,f.y,duration,{"s05_asset":kind,"owner":f.id,"team":f.team,"face":f.face,"z":42.0 if kind=="diagonal" else 25.0,"vx":f.face*distance/duration,"vz":vz,"damage":maxi(1,roundi(23*sim._difficulty.enemy_damage)),"hit_ids":[],"action":f.action})
	audio(sim,"s05.natsume.wave_horizontal" if kind=="sweep" else ("s05.natsume.wave_diagonal" if kind=="diagonal" else "s05.natsume.wave_downward"),f.id)

static func projectile(sim, e: Dictionary) -> void:
	if e.type=="s05_roar":
		e.x+=e.vx;e.y+=e.vy
		e.radius=60.0+(int(e.max_life)-int(e.life))*2.5
		for target in sim.state.fighters:
			if target.team!=0 or target.hp<=0 or target.id in e.hit_ids: continue
			if absf(target.x-e.x)>e.radius*.7+25 or absf(target.y-e.y)>e.radius*.6+24 or absf(target.z+65-e.z)>e.radius+50: continue
			e.hit_ids.append(int(target.id))
			if sim._damage(target,e.damage,e.owner,false,true,false,false,e.x,e.y,e.action,24,"blunt"):
				target.stun=maxi(target.stun,120);sim._begin(target,"stunned")
		return
	var previous_x: float=e.x
	var previous_z: float=e.z
	e.x+=e.vx; e.z+=e.vz
	for target in sim.state.fighters:
		if target.team!=0 or target.hp<=0 or target.id in e.hit_ids: continue
		var t := clampf((target.x-previous_x)/float(e.vx),0,1)
		var z := lerpf(previous_z,e.z,t)
		if target.x<minf(previous_x,e.x)-38 or target.x>maxf(previous_x,e.x)+38 or absf(target.y-e.y)>46 or absf(target.z-z)>48: continue
		e.hit_ids.append(int(target.id))
		if sim._damage(target,e.damage,e.owner,false,true,false,true,e.x,e.y,e.action,24,"sword"):
			sim._launch(target,e.face,9,8)

static func reaction_tick(sim, f: Dictionary) -> bool:
	if not f.has("s05_role"): return false
	if f.action not in ["hurt","recovering"]: return false
	var clip := "recover" if f.action=="recovering" else "hurt"
	if f.action_tick>=ceili(Data.duration(f.s05_role,clip)*.06/Data.speed(f)): sim._begin(f,"idle")
	return true
