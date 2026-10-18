extends RefCounted

const Data = preload("res://core/stage05_data.gd")
# Initial balance choices; authored timings and requested mechanics are separate.
const HP := {"militia":44,"monk":72,"hachiya":640,"natsume":760,"kusei":1200}
const CAP := 24
const VOICES := {"s05_hachiya_rapid":"hachiya_tsuranuke","s05_hachiya_return":"hachiya_nigasan","s05_natsume_ground":"natsume_tatakikiru","s05_natsume_diagonal":"natsume_fukitobe","s05_natsume_sweep":"natsume_fukitobe","s05_kusei_guard":"kusei_fudo","s05_kusei_slash":"kusei_kiru","s05_kusei_summon":"kusei_kitare"}

static func begin(sim, spec: Dictionary) -> void:
	sim.state.fighters = sim.state.fighters.filter(func(f): return f.team == 0)
	sim.state.effects.clear(); sim.state.props.clear(); sim.state.wet_zones.clear()
	sim.state.ikki = {"node":int(spec.node),"phase":"combat","next_batch":1,"pending":[],"admit_tick":0,"farmer_tick":0,"boss":0,"thresholds":[],"summons":[],"summon_count":0}
	sim.state.stage.wave_total = 1
	for i in int(spec.units_per_batch):
		if not admit(sim,str(spec.role),false,false,i): sim.state.ikki.pending.append({"role":str(spec.role),"elite":false})
	if str(spec.boss) != "":
		var boss := spawn(sim,str(spec.boss),float(sim.state.stage.encounter_start)+980,480)
		sim.state.fighters.append(boss); sim.state.ikki.boss = int(boss.id)
	for i in spec.objects.size():
		var item: Dictionary = spec.objects[i]
		var flag := str(item.asset).contains("_")
		var hp := 55 if flag else 65
		sim.state.props.append({"id":sim._next_id,"kind":"fence" if flag else "jar","s05_asset":item.asset,"x":item.x,"y":item.y,"hp":hp,"max_hp":hp,"width":52.5 if flag else 110.0,"depth":25.0 if flag else 45.0,"broken":false,"drop":"","mandatory":false,"broken_tick":-1})
		sim._next_id+=1
	if spec.boss == "kusei":
		admit(sim,"militia",false,true,0); admit(sim,"militia",false,true,1)
		sim.state.ikki.farmer_tick = sim.state.tick+120

static func spawn(sim, role: String, x: float, y: float, elite: bool = false, weak: bool = false) -> Dictionary:
	var players: int = sim.state.fighters.filter(func(f): return f.team == 0).size()
	var boss := role in ["hachiya","natsume","kusei"]
	var hp := roundi((22.0 if weak else float(HP[role]))*float(sim._difficulty.enemy_hp)*(1.5 if elite else 1.0)*(1.7 if boss and players>1 else 1.0))
	var f: Dictionary = sim._make_fighter(1,"boss" if boss else "soldier",x,y,hp)
	f.s05_role=role; f.s05_elite=elite; f.s05_weak=weak; f.s05_events=[]; f.s05_combo=[]; f.s05_root_px=0.0; f.s05_target=0
	f.s05_move_clip="walk"
	f.death_ticks=60; f.cooldown=45+int(f.id)%5*11; f.down_ticks=ceili(Data.duration(role,"down")*.06)
	if boss:
		f.display_name={"hachiya":"蜂屋貞次","natsume":"夏目吉信","kusei":"空誓"}[role]
		f.stage_boss=role=="kusei"; f.weight="heavy"
	else: f.display_name="精銳僧兵" if elite else ("僧兵" if role=="monk" else "農夫")
	return f

static func admit(sim, role: String, elite: bool = false, weak: bool = false, slot: int = 0) -> bool:
	if sim.state.fighters.size() >= 48 or sim.state.fighters.filter(func(f):return f.team==1 and f.hp>0).size() >= CAP: return false
	var left: float=sim.state.stage.encounter_start
	var right: float=sim.state.stage.encounter_end
	var x := clampf(maxf(sim.camera_left(sim.state)+900,left+720)+(slot/3)*115,left+160,right-90)
	var y := 385.0+float(slot%3)*90
	# Search deterministic local cells, keep all unadmitted units queued.
	for i in 24:
		var candidate := Vector2(clampf(x-(i/3)*92,left+100,right-70),385+(i+slot)%3*90)
		if sim.state.fighters.any(func(f): return f.hp>0 and absf(f.x-candidate.x)<70 and absf(f.y-candidate.y)<48): continue
		var f := spawn(sim,role,candidate.x,candidate.y,elite,weak)
		sim.state.fighters.append(f)
		return true
	return false

static func tick(sim) -> void:
	var box: Dictionary=sim.state.ikki
	var spec: Dictionary=sim._campaign.segments[sim.state.stage.index].encounters[sim.state.stage.checkpoint]
	var boss: Dictionary=sim._fighter(int(box.boss))
	var alive_boss: bool = not boss.is_empty() and boss.hp>0
	var ordinary: Array=sim.state.fighters.filter(func(f): return f.team==1 and f.hp>0 and f.kind!="boss" and not f.get("s05_weak",false) and not f.get("s05_elite",false))
	if int(box.next_batch)<int(spec.finite_batches) and ordinary.size()<=2 and box.pending.is_empty():
		for i in int(spec.units_per_batch): box.pending.append({"role":str(spec.role),"elite":false})
		box.next_batch+=1
	if not box.pending.is_empty() and sim.state.tick>=box.admit_tick:
		var unit: Dictionary=box.pending[0]
		if admit(sim,unit.role,unit.elite,false,int(sim.state.tick)%9): box.pending.pop_front(); box.admit_tick=sim.state.tick+12
	if alive_boss and boss.s05_role=="kusei":
		thresholds(sim,boss)
		var farmers: int=sim.state.fighters.filter(func(f):return f.get("s05_weak",false) and f.hp>0).size()
		if farmers<2 and sim.state.tick>=box.farmer_tick:
			if admit(sim,"militia",false,true,farmers): box.farmer_tick=sim.state.tick+120
	else:
		box.summons.clear()
		# Reinforcements requested before death finish entering; the infinite pool stops.
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
	if box.next_batch==spec.finite_batches and box.pending.is_empty() and not sim.state.fighters.any(func(f):return f.team==1 and f.hp>0): box.phase="complete"

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
	if action=="s05_kusei_stomp":
		f.stun=0; f.freeze=0; f.knockback=0.0; f.z=0.0; f.vz=0.0; f.airborne_lock=false
		audio(sim,"kusei_stomp_full",int(f.id))
	elif VOICES.has(action): audio(sim,VOICES[action],int(f.id))

static func ai(sim, f: Dictionary, target: Dictionary) -> bool:
	if not f.has("s05_role"): return false
	if f.action!="idle": return true
	var dx: float=target.x-f.x; var dy: float=target.y-f.y
	f.face=1 if dx>=0 else -1
	if f.s05_role=="kusei" and not sim.state.ikki.summons.is_empty():
		sim.state.ikki.summons.pop_front(); start(sim,f,"s05_kusei_summon",target); return true
	var reach: float={"militia":100.0,"monk":155.0,"hachiya":210.0,"natsume":245.0,"kusei":225.0}[f.s05_role]
	if absf(dx)<=reach and absf(dy)<42 and f.cooldown==0:
		var action := ""
		match f.s05_role:
			"militia": action="s05_militia_attack"
			"monk": action="s05_monk_quick_attack" if f.ai_cycle%3!=2 else "s05_monk_heavy_attack"
			"hachiya": action=["s05_hachiya_rapid","s05_hachiya_return","s05_hachiya_sweep"][f.ai_cycle%3]
			"natsume":
				# Lock a choice from the current target state, not later client inputs.
				action="s05_natsume_diagonal" if target.z>12 or target.vz>0 else ("s05_natsume_sweep" if absf(dx)<115 and f.ai_cycle%3==2 else "s05_natsume_ground")
			"kusei": action=["s05_kusei_slash","s05_kusei_guard","s05_kusei_stomp"][f.ai_cycle%3]
		f.ai_cycle+=1; start(sim,f,action,target)
	else:
		var speed: float=(1.2 if f.s05_weak else (1.8 if f.kind!="boss" else 2.4))*Data.speed(f)
		var mx := signf(dx) if absf(dx)>reach*.78 else 0.0
		var my := signf(dy) if absf(dy)>6 else 0.0
		f.s05_move_clip="walk"
		if f.s05_role=="hachiya" and absf(dx)>320:
			f.s05_move_clip="run";speed=3.6
		elif f.s05_role in ["natsume","kusei"] and f.cooldown>20 and absf(dx)<110:
			mx=-float(f.face);f.face=int(mx);f.s05_move_clip="retreat_run";speed=3.0
		var before: float=f.x
		sim._move_fighter(f,mx*speed,my*speed*.65)
		if mx!=0 and is_equal_approx(before,f.x): sim._move_fighter(f,0,(-1 if f.y>480 else 1)*speed)
		f.move_dx=int(mx); f.move_dy=int(my)
	return true

static func invulnerable(f: Dictionary) -> bool:
	return f.get("s05_role","")=="kusei" and f.action=="s05_kusei_stomp" and f.action_tick<300

static func guard_active(f: Dictionary) -> bool:
	return f.get("s05_role","")=="kusei" and f.action=="s05_kusei_guard" and f.action_tick>=18 and f.action_tick<120

static func accepts_damage(sim, f: Dictionary, actor: int, source_body: int) -> bool:
	if invulnerable(f): return false
	if not guard_active(f): return true
	var body: Dictionary=sim._fighter(source_body)
	return not body.is_empty() and body.get("s05_role","")=="militia" and int(body.thrown_by)==actor and body.throw_ticks>0

static func audio(sim, cue: String, actor: int) -> void:
	var f: Dictionary=sim._fighter(actor)
	sim._event("stage05_audio",float(f.get("x",0)),float(f.get("y",480)),actor,0,{"cue":cue})

static func strike(sim, f: Dictionary, reach: float, depth: float, amount: int, launch: bool = false, locked: bool = false) -> Array:
	var hit := []
	for target in sim.state.fighters:
		if target.team!=0 or target.hp<=0: continue
		if locked:
			if target.id not in f.s05_combo: continue
		elif (target.x-f.x)*f.face < -22 or (target.x-f.x)*f.face>reach or absf(target.y-f.y)>depth or target.z>60: continue
		if sim._damage(target,maxi(1,roundi(amount*sim._difficulty.enemy_damage)),f.id,false,true,locked,launch,f.x,f.y,f.action,24,"spear" if f.s05_role=="hachiya" else "sword"):
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
	if action=="s05_natsume_ground" and Data.crossed(tick,420): audio(sim,"s05.natsume.downstroke_whoosh",f.id)
	for i in Data.HITS[action].size():
		if not Data.crossed(tick,Data.HITS[action][i],speed): continue
		match action:
			"s05_kusei_stomp": quake(sim,f)
			"s05_kusei_summon":
				audio(sim,"s05.kusei.palm_clap",f.id)
				if i==1:
					for n in 4: sim.state.ikki.pending.append({"role":"monk","elite":true})
					sim.state.ikki.summon_count+=1
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
			"s05_monk_quick_attack","s05_monk_heavy_attack":
				var heavy: bool=action.ends_with("heavy_attack")
				audio(sim,"s05.monk.naginata_heavy_sweep" if heavy else "s05.monk.naginata_quick_swing",f.id)
				if not strike(sim,f,160,47,19 if heavy else 12,heavy).is_empty(): audio(sim,"s05.monk.naginata_impact",f.id)
	if tick>=int(Data.timing(f)[1]):
		f.cooldown=ceili((50 if f.kind=="boss" else 65)/speed)
		sim._begin(f,"idle")
	return true

static func wave(sim, f: Dictionary) -> void:
	var kind: String = f.action.trim_prefix("s05_natsume_")
	var scale := Data.height("natsume")/691.2
	var distance := (600.0 if kind=="diagonal" else 700.0)*scale
	var duration := 21
	var vz := (320.0*scale/duration) if kind=="diagonal" else 0.0
	sim._effect("s05_wave",f.x+f.face*70,f.y,duration,{"s05_asset":kind,"owner":f.id,"team":f.team,"face":f.face,"z":42.0 if kind=="diagonal" else 25.0,"vx":f.face*distance/duration,"vz":vz,"damage":maxi(1,roundi(23*sim._difficulty.enemy_damage)),"hit_ids":[],"action":f.action})
	audio(sim,"s05.natsume.wave_horizontal" if kind=="sweep" else ("s05.natsume.wave_diagonal" if kind=="diagonal" else "s05.natsume.wave_downward"),f.id)

static func projectile(sim, e: Dictionary) -> void:
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
