extends RefCounted

const Data = preload("res://core/stage04_data.gd")

static func begin(sim, spec: Dictionary) -> void:
	if sim.state.get("mikawa",{}).get("node",0) == int(spec.node): return
	sim.state.fighters = sim.state.fighters.filter(func(f): return f.team == 0)
	sim.state.effects.clear()
	sim.state.props = sim.state.props.filter(func(p): return not p.has("mikawa_asset"))
	sim.state.wet_zones = []
	sim.state.mikawa = {"node":int(spec.node),"phase":"combat","pending":[],"deaths":[],"mud":spec.get("mud",[]),"command":0,"rain_hits":[],"retreat_tick":-1,"boss":0,"epoch":sim._next_id,"next_batch":0,"reserved":[],"admit_tick":0,"escort_tick":0,"escape_complete":false}
	for item in spec.objects:
		var flag: bool = item.asset in ["kflag","uflag"]
		var hp := 65 if flag else 110
		sim.state.props.append({"id":sim._next_id,"kind":"fence" if flag or item.asset == "fence" else "barricade","mikawa_asset":item.asset,"x":item.x,"y":item.y,"hp":hp,"max_hp":hp,"width":28.0 if flag else 270.0,"depth":20.0 if flag else 100.0,"broken":false,"drop":"","mandatory":false,"broken_tick":-1})
		sim._next_id += 1
	var players: int = sim.state.fighters.size()
	var regular_slot := 0
	for unit in spec.units:
		var fighter := spawn(sim,unit,players)
		if unit.kind != "boss" and not fighter.mikawa_escort:
			var camera: float = sim.camera_left(sim.state)
			fighter.x = maxf(camera+720,sim.state.stage.encounter_start+180)+(regular_slot/3)*150
			regular_slot += 1
		sim._place_enemy(fighter)
		sim.state.fighters.append(fighter)
		if unit.kind == "boss": intro(sim,fighter)
		if unit.role == "udono": sim.state.mikawa.boss = fighter.id
	sim.state.stage.wave_total = 1

static func spawn(sim, unit: Dictionary, players: int) -> Dictionary:
	var role: String = unit.role
	var hp := roundi(float({"soldier":80,"archer":60,"gunner":70,"boss":480}[unit.kind])*float(sim._difficulty.enemy_hp))
	if role == "udono":
		var values := Data.tuning()
		hp = roundi(float(values.base_hp)*float(values.difficulty_hp_scale[sim.state.difficulty])*(float(values.coop_hp_scale) if players > 1 else 1.0))
	elif unit.kind == "boss" and players > 1: hp = roundi(hp*1.7)
	var fighter: Dictionary = sim._make_fighter(1,unit.kind,float(unit.x),float(unit.y),hp)
	fighter.mikawa_role = role
	if role in Data.SHIELD_ROLES: fighter.weight = "heavy"
	fighter.mikawa_escort = bool(unit.get("escort",false))
	fighter.death_ticks = 60
	fighter.mikawa_sequence = 0
	fighter.mikawa_events = []
	fighter.mikawa_pressure = []
	fighter.mikawa_counters = {"spin":0,"rock":0,"shared":0}
	fighter.mikawa_command = 0
	fighter.home_x = fighter.x
	fighter.home_y = fighter.y
	fighter.cooldown = 40 + int(fighter.id)%5*13
	if unit.kind == "boss":
		fighter.display_name = {"udono":"鵜殿長照","kira":"吉良義昭","tominaga":"富永忠元"}[role]
		fighter.render_scale = 1.30 if role == "udono" else 1.05
		fighter.stage_boss = role == "udono"
	return fighter

static func start(sim, fighter: Dictionary, action: String) -> void:
	fighter.mikawa_sequence += 1
	fighter.mikawa_events = []
	fighter.mikawa_command = 0
	sim._begin(fighter,action)
	if action == "kira_command":
		sim.state.mikawa.command += 1
		sim.state.mikawa.rain_hits.clear()
		fighter.mikawa_command = sim.state.mikawa.command
		fighter.mikawa_roster = []

static func tick(sim) -> void:
	if sim.state.intro.get("remaining_ticks",0) > 0 and sim.state.intro.get("blocking",false): return
	var box: Dictionary = sim.state.mikawa
	box.deaths = box.deaths.filter(func(id): return sim.state.fighters.any(func(f): return f.id == id))
	var kira_alive: bool = sim.state.fighters.any(func(f): return f.get("mikawa_role","") == "kira" and f.hp > 0)
	if not kira_alive: box.pending.clear()
	for f in sim.state.fighters:
		if not f.has("mikawa_role"): continue
		if f.hp <= 0:
			if f.id in box.deaths: continue
			box.deaths.append(f.id)
			if f.mikawa_escort and kira_alive: box.pending.append({"due":int(sim.state.tick)+180,"dead":int(f.id)})
			if f.mikawa_role == "udono":
				box.phase = "retreat"
				box.retreat_tick = sim.state.tick
				f.death_ticks = 600
				f.knockback = 0.0
				sim.state.effects = sim.state.effects.filter(func(e): return e.get("owner",0) != f.id)
		elif f.mikawa_role == "udono": _counter(sim,f)
	if kira_alive and not box.pending.is_empty() and sim.state.tick >= box.escort_tick and sim.state.tick >= box.pending[0].due:
		var spot := entry(sim,{"role":"archer_kira"},false)
		if not spot.is_empty() and sim.state.fighters.size() < 48:
			admit(sim,{"role":"archer_kira","kind":"archer","escort":true},spot)
			box.pending.pop_front()
			box.escort_tick = sim.state.tick+45
	reinforce(sim)
	for prop in sim.state.props:
		if not prop.has("mikawa_asset") or not prop.broken: continue
		if int(prop.broken_tick) < 0: prop.broken_tick = sim.state.tick
		if prop.mikawa_asset not in ["kflag","uflag"]: continue
		var age: int = sim.state.tick-int(prop.broken_tick)
		if age == 12: audio(sim,"flag_snap",0)
		if age == 36: audio(sim,"flag_land",0)
	if box.phase == "retreat" and not box.escape_complete:
		var boss: Dictionary = sim._fighter(int(box.boss))
		if not boss.is_empty():
			var elapsed: int = int(sim.state.tick)-int(box.retreat_tick)
			boss.face = 1
			if elapsed >= ceili(78/Data.UDONO_SPEED): boss.x += 220.0*Data.UDONO_SPEED/60.0
			if boss.x > float(sim.state.stage.encounter_end)+100: box.escape_complete = true
	var spec: Dictionary = sim._campaign.segments[sim.state.stage.index].encounters[sim.state.stage.checkpoint]
	if box.next_batch == spec.batches.size() and box.reserved.is_empty() and box.pending.is_empty() and not sim.state.fighters.any(func(f): return f.team == 1 and f.hp > 0):
		if box.boss == 0 or box.escape_complete: box.phase = "complete"

static func intro(sim, fighter: Dictionary) -> void:
	var row: Array = {"tominaga":["tominaga_sweep","覚悟しろ！",60],"kira":["kira_withdraw","逃がすな！",60],"udono":["stage_udono_v15_intro_0","砦を守れ！今川の兵よ、我に続け！",351]}[fighter.mikawa_role]
	sim.state.intro = {"actor":fighter.id,"name":fighter.display_name,"line_key":row[0],"line":row[1],"duration":row[2],"remaining_ticks":row[2],"announced":false,"blocking":true}

static func regular(fighter: Dictionary) -> bool:
	return fighter.team == 1 and fighter.hp > 0 and fighter.kind != "boss" and not fighter.get("mikawa_escort",false)

static func reinforce(sim) -> void:
	var box: Dictionary = sim.state.mikawa
	var spec: Dictionary = sim._campaign.segments[sim.state.stage.index].encounters[sim.state.stage.checkpoint]
	var soldiers: Array = sim.state.fighters.filter(regular)
	if box.reserved.is_empty() and box.next_batch < spec.batches.size() and soldiers.size() <= 2 and not soldiers.any(func(f): return f.get("entering",false)):
		var batch: Dictionary = spec.batches[box.next_batch]
		var count: int = batch.left.size()*2
		var alive: int = sim.state.fighters.filter(func(f): return f.team == 1 and f.hp > 0).size()
		if soldiers.size()+count <= spec.regular_cap and alive+box.pending.size()+count <= spec.cap:
			for index in batch.left.size(): box.reserved.append({"left":batch.left[index].duplicate(),"right":batch.right[index].duplicate()})
			box.next_batch += 1
			box.admit_tick = sim.state.tick+45
	if box.reserved.is_empty() or sim.state.tick < box.admit_tick or sim.state.fighters.size()+2 > 48: return
	var pair: Dictionary = box.reserved[0]
	var left := entry(sim,pair.left,true)
	var right := entry(sim,pair.right,false)
	if left.is_empty() or right.is_empty(): return
	admit(sim,pair.left,left)
	admit(sim,pair.right,right)
	box.reserved.pop_front()
	box.admit_tick = sim.state.tick+45

static func entry(sim, unit: Dictionary, left: bool) -> Dictionary:
	var camera: float = sim.camera_left(sim.state)
	var x := camera-240.0 if left else camera+1520.0
	var target: float = maxf(camera+100,sim._left_edge()+60) if left else minf(camera+1150,sim._right_edge()-60)
	for lane in [390.0,480.0,570.0,435.0,525.0]:
		var blocked := false
		for f in sim.state.fighters:
			if f.hp <= 0: continue
			if absf(f.y-lane) < 42 and (absf(f.x-x)<85 or absf(f.x-target)<85): blocked = true
		if not passes_barrier({"team":1,"mikawa_role":unit.role}):
			for prop in sim.state.props:
				if not prop.broken and prop.get("mikawa_asset","") in ["fence","cheval"] and barrier_blocks(prop,Vector2(x,lane),Vector2(target,lane)): blocked = true
		if not blocked: return {"x":x,"y":lane,"entry_x":target}
	return {}

static func admit(sim, unit: Dictionary, spot: Dictionary) -> void:
	var row := unit.duplicate()
	row.merge(spot,true)
	var fighter := spawn(sim,row,sim.state.fighters.filter(func(f): return f.team==0).size())
	fighter.entering = true
	fighter.entry_x = spot.entry_x
	sim.state.fighters.append(fighter)

static func in_mud(world: Dictionary, fighter: Dictionary) -> bool:
	if not world.has("mikawa") or float(fighter.z) > 0: return false
	var polygon := PackedVector2Array()
	for point in world.mikawa.mud: polygon.append(Vector2(point[0],point[1]))
	return polygon.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(fighter.x,fighter.y),polygon)

static func passes_barrier(fighter: Dictionary) -> bool:
	return fighter.team == 1 and fighter.get("mikawa_role","") in ["spear_kira","shield_kira","spear_udono","shield_udono","tominaga","udono"]

static func barrier_blocks(prop: Dictionary, start: Vector2, finish: Vector2) -> bool:
	var folder := "barricade" if prop.mikawa_asset == "fence" else "cheval"
	var points: Array = Data.read("props/%s/%s_manifest.json"%[folder,folder]).ground_placement.approximate_intact_footprint_polygon
	var polygon := PackedVector2Array()
	for point in points: polygon.append(Vector2(prop.x,prop.y)+(Vector2(point[0],point[1])-Vector2(800,740))*.2)
	polygon = Geometry2D.offset_polygon(polygon,15)[0]
	if Geometry2D.is_point_in_polygon(start,polygon): return Geometry2D.is_point_in_polygon(finish,polygon) and finish.distance_to(Vector2(prop.x,prop.y)) < start.distance_to(Vector2(prop.x,prop.y))
	if Geometry2D.is_point_in_polygon(finish,polygon): return true
	for index in polygon.size():
		if Geometry2D.segment_intersects_segment(start,finish,polygon[index],polygon[(index+1)%polygon.size()]) != null: return true
	return false

static func ai(sim, fighter: Dictionary, target: Dictionary) -> bool:
	var role := str(fighter.get("mikawa_role",""))
	if role.is_empty(): return false
	if int(fighter.get("mikawa_command",0)) > 0 and role == "archer_kira": return true
	if role not in ["udono","kira","tominaga"]: return false
	if fighter.action not in ["idle","retreat"] or fighter.stun > 0 or fighter.freeze > 0: return true
	var delta := Vector2(target.x-fighter.x,target.y-fighter.y)
	fighter.face = 1 if delta.x >= 0 else -1
	if role in ["kira","tominaga"]:
		var close := absf(delta.x) < 210 and absf(delta.y) < 85
		var reach := 900.0 if role == "kira" else 650.0
		if fighter.cooldown == 0 and absf(delta.x) <= reach and absf(delta.y) < 55:
			var action := ""
			if close:
				action = "kira_counter" if role == "kira" else ("tominaga_sweep" if int(fighter.ai_cycle)%2 == 0 else "tominaga_pursuit")
			elif role == "kira":
				var archers: bool = sim.state.fighters.any(func(f): return available_archer(f))
				action = "kira_command" if archers and int(fighter.ai_cycle)%2 == 0 else "kira_arrow"
			else: action = "tominaga_heavy_chop"
			fighter.ai_cycle += 1
			start(sim,fighter,action)
		else:
			var horizontal := -float(fighter.face) if absf(delta.x) < 360 else (float(fighter.face) if absf(delta.x) > reach*.85 else 0.0)
			sim._move_fighter(fighter,horizontal*3.2,signf(delta.y)*1.8 if absf(delta.y)>8 else 0.0)
		return true
	var actions: Array = ["udono_upthrust","udono_groundsmash","udono_charge","udono_sweep","udono_triplequake"]
	if fighter.cooldown == 0 and absf(delta.x) > 300:
		start(sim,fighter,"udono_ranged_rock_volley")
		return true
	if fighter.cooldown == 0 and absf(delta.x) <= 210 and absf(delta.y) < 55:
		var action: String = actions[int(fighter.ai_cycle)%actions.size()]
		fighter.ai_cycle += 1
		start(sim,fighter,action)
	else:
		var direction := Vector2(signf(delta.x) if absf(delta.x) > 168 else 0.0,signf(delta.y) if absf(delta.y)>8 else 0.0)
		sim._move_fighter(fighter,direction.x*2.0*Data.UDONO_SPEED,direction.y*1.6*Data.UDONO_SPEED)
	return true

static func _once(fighter: Dictionary, key: String) -> bool:
	if key in fighter.mikawa_events: return false
	fighter.mikawa_events.append(key)
	return true

static func attack(sim, fighter: Dictionary) -> bool:
	var action: String = fighter.action
	if not fighter.has("mikawa_role"): return false
	if not Data.HITS.has(action):
		var timing := Data.attack_timing(fighter)
		if fighter.action_tick == timing[0]:
			if fighter.kind in ["archer","gunner"]:
				sim._projectile(fighter,roundi(14*float(sim._difficulty.enemy_damage)),0,false,"bullet" if fighter.kind == "gunner" else "arrow",1100.0)
			else:
				sim._enemy_melee(fighter,140.0 if fighter.mikawa_role.begins_with("shield_") else 200.0,70.0 if action == "spear_sweep" else 40.0,14,"push")
		if fighter.action_tick >= timing[1]:
			fighter.cooldown = 100 if fighter.kind == "gunner" else 50
			sim._begin(fighter,"idle")
		return true
	if fighter.stun > 0 or fighter.freeze > 0: return true
	var tick: int = fighter.action_tick
	var speed := Data.UDONO_SPEED if fighter.mikawa_role == "udono" else 1.0
	var pose_tick := tick*speed
	if action == "udono_melee_spin_counter" and pose_tick >= 32 and pose_tick <= 63: _spin(sim,fighter)
	for voice in Data.read("audio/voice_animation_map_v3.json").events:
		if voice.animation_id == action and Data.crossed(tick,float(voice.voice_start_s)*1000,speed) and _once(fighter,"voice"):
			audio(sim,str(voice.clip_id),int(fighter.id),true)
	if action == "kira_command" and Data.crossed(tick,400) and _once(fighter,"roster"):
		fighter.mikawa_roster = []
		for archer in sim.state.fighters:
			if available_archer(archer):
				fighter.mikawa_roster.append(archer.id)
				start(sim,archer,"kira_volley")
				archer.mikawa_command = fighter.mikawa_command
	if action in ["udono_charge","tominaga_pursuit"] and pose_tick >= 18 and tick < int(Data.attack_timing(fighter)[0]):
		sim._move_fighter(fighter,float(fighter.face)*5.5*speed,0,true)
	for index in Data.HITS[action].size():
		if not Data.crossed(tick,float(Data.HITS[action][index]),speed) or not _once(fighter,"hit%d"%index): continue
		match action:
			"udono_ranged_rock_volley": _stone(sim,fighter,index)
			"kira_command": _rain(sim,fighter,index)
			"kira_arrow":
				sim._projectile(fighter,roundi(24*float(sim._difficulty.enemy_damage)),0,false,"arrow",1000.0,0,"",true,{"straight":true})
				var arrow: Dictionary = sim.state.effects[-1]
				arrow.x = fighter.x+float(fighter.face)*75.0
				arrow.previous_x = arrow.x
				arrow.z = 95.0
				arrow.vx = float(fighter.face)*sim.HERO_ARROW_SPEED
				arrow.visual_exact_origin = true
				arrow.collision_height = 90.0
				arrow.standing_push = 6.0
				arrow.life = ceili(float(arrow.range_left)/absf(arrow.vx))+2
				arrow.max_life = arrow.life
			"udono_groundsmash","udono_triplequake": _quake(sim,fighter,index)
			"udono_melee_spin_counter": audio(sim,"spin",fighter.id)
			"tominaga_heavy_chop": _wave(sim,fighter)
			_:
				var reach: float = {"udono_upthrust":280.0,"udono_charge":290.0,"udono_sweep":310.0,"tominaga_sweep":230.0,"tominaga_pursuit":240.0,"kira_counter":170.0}[action]
				sim._enemy_melee(fighter,reach,75.0,24,"down" if action == "udono_upthrust" else "push")
				audio(sim,"spear_motion" if action.begins_with("udono_") else "sword_motion",fighter.id)
	if action in ["kira_counter","tominaga_sweep","tominaga_pursuit"] and tick > int(Data.attack_timing(fighter)[0])+6:
		var target := _nearest(sim,fighter)
		if not target.is_empty() and absf(target.x-fighter.x) < 360:
			sim._move_fighter(fighter,-float(fighter.face)*3.6,0,true)
	if tick >= int(Data.attack_timing(fighter)[1]):
		fighter.cooldown = 50 if fighter.mikawa_role == "udono" else 24
		fighter.mikawa_command = 0
		sim._begin(fighter,"idle")
	return true

static func available_archer(fighter: Dictionary) -> bool:
	return fighter.get("mikawa_role","") == "archer_kira" and fighter.get("mikawa_escort",false) and fighter.hp > 0 and not fighter.get("entering",false) and fighter.z == 0 and fighter.stun == 0 and fighter.freeze == 0 and fighter.held_by == 0 and not fighter.airborne_lock and fighter.action not in ["down","recovering","hurt","grabbed"]

static func _nearest(sim, fighter: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var best := INF
	for p in sim.state.fighters:
		if p.team != 0 or p.hp <= 0: continue
		var distance := Vector2(p.x-fighter.x,p.y-fighter.y).length_squared()
		if distance < best: best = distance; result = p
	return result

static func _stone(sim, fighter: Dictionary, shot: int) -> void:
	var target := _nearest(sim,fighter)
	if target.is_empty(): return
	var scale := 201.5/360.0
	var x: float = fighter.x+float(fighter.face)*209.4*scale
	var y: float = fighter.y
	var angle := atan2((float(target.y)-y)/.4,float(target.x)-x)
	var speed: float = sim.FAST_PROJECTILE_SPEED
	sim._effect("projectile",x,y,180,{"mikawa_projectile":"stone","z":261.8*scale,"vx":cos(angle)*speed,"vy":sin(angle)*speed*.4,"owner":fighter.id,"team":1,"damage":roundi(16*float(sim._difficulty.enemy_damage)),"face":fighter.face,"range_left":1100.0,"hit_ids":[],"shot":shot,"action":fighter.action,"attack_id":fighter.mikawa_sequence,"weapon":"blunt","poison":0})
	audio(sim,"stone_release",fighter.id)

static func _rain(sim, fighter: Dictionary, wave: int) -> void:
	var target := _nearest(sim,fighter)
	if target.is_empty(): return
	var spread: Dictionary = Data.read("settings/kira_rain.json").initial_values_unmeasured
	var roster: Array = fighter.mikawa_roster
	for index in roster.size():
		var archer: Dictionary = sim._fighter(int(roster[index]))
		if archer.is_empty() or not available_archer(archer) or archer.mikawa_command != fighter.mikawa_command: continue
		var angle := float(index)*2.399963+wave*.7
		var radius := sqrt(float(index+1)/maxf(1,roster.size()))*.85
		var landing := Vector2(target.x+cos(angle)*radius*float(spread.spread_effective_radius_world_x),target.y+sin(angle)*radius*float(spread.spread_effective_radius_world_y))
		landing.x = clampf(landing.x,sim._left_edge(),sim._right_edge())
		landing.y = clampf(landing.y,360,600)
		sim._effect("projectile",archer.x,archer.y,60,{"mikawa_projectile":"rain","z":90.0,"vx":0.0,"vy":0.0,"owner":archer.id,"team":1,"damage":roundi(10*float(sim._difficulty.enemy_damage)),"face":archer.face,"hit_ids":[],"action":"kira_command","weapon":"arrow","poison":0,"from_x":archer.x,"from_y":archer.y,"land_x":landing.x,"land_y":landing.y,"command":fighter.mikawa_command,"wave":wave})
		audio(sim,"bow_motion",archer.id)

static func _quake(sim, fighter: Dictionary, wave: int) -> void:
	var radius := 260.0+wave*80.0
	var x: float = fighter.x+float(fighter.face)*32.0*201.5/370.0
	sim._effect("mikawa_fx",x,fighter.y,28,{"asset":"quake","radius":radius,"owner":fighter.id})
	audio(sim,"quake",fighter.id)
	for p in sim.state.fighters:
		if p.team != 0 or p.hp <= 0 or p.z > 45: continue
		if Vector2(p.x-x,(p.y-fighter.y)/.4).length() <= radius:
			if sim._damage(p,roundi(30*float(sim._difficulty.enemy_damage)),fighter.id,true,true,false,true,x,fighter.y,fighter.action,24,"blunt"): p.down_ticks = 150

static func _spin(sim, fighter: Dictionary) -> void:
	var values := Data.tuning()
	for p in sim.state.fighters:
		if p.team != 0 or p.hp <= 0 or p.z > 100: continue
		if Vector2(p.x-fighter.x,(p.y-fighter.y)/float(values.spin_depth_scale)).length() > float(values.spin_effective_radius_world): continue
		var key := "spin_target_%d"%int(p.id)
		if key in fighter.mikawa_events: continue
		if sim._damage(p,roundi(int(values.spin_damage)*float(sim._difficulty.enemy_damage)),fighter.id,false,true,false,true,fighter.x,fighter.y,fighter.action):
			fighter.mikawa_events.append(key)
			sim._launch(p,1 if p.x >= fighter.x else -1,9.0,6.0)

static func _wave(sim, fighter: Dictionary) -> void:
	sim._effect("projectile",fighter.x,fighter.y,53,{"mikawa_projectile":"wave","origin_x":fighter.x,"z":0.0,"vx":float(fighter.face)*20.0,"vy":0.0,"owner":fighter.id,"team":1,"damage":roundi(24*float(sim._difficulty.enemy_damage)),"face":fighter.face,"hit_ids":[],"action":fighter.action,"weapon":"blade","poison":0})
	audio(sim,"sword_motion",fighter.id)

static func projectile(sim, effect: Dictionary) -> void:
	var kind: String = effect.mikawa_projectile
	if kind == "rain":
		var age: int = int(effect.max_life)-int(effect.life)
		if age < 36:
			effect.x = lerpf(float(effect.from_x),float(effect.land_x),float(age)/36.0)
			effect.y = lerpf(float(effect.from_y),float(effect.land_y),float(age)/36.0)
			effect.z = 90.0+age*18.0
		else:
			effect.x = effect.land_x; effect.y = effect.land_y
			effect.z = (60-age)*26.0
		if effect.life > 0: return
		for p in sim.state.fighters:
			if p.team != 0 or p.hp <= 0 or p.z > 45: continue
			var key := "%d:%d" % [int(effect.command),int(p.id)]
			if key in sim.state.mikawa.rain_hits or absf(p.x-effect.land_x)>32 or absf(p.y-effect.land_y)>24: continue
			if sim._damage(p,int(effect.damage),effect.owner,false,true,false,false,effect.land_x,effect.land_y,"kira_command",24,"arrow"): sim.state.mikawa.rain_hits.append(key)
		return
	if kind == "wave" and int(effect.max_life)-int(effect.life) > 34: return
	var previous := Vector2(effect.x,effect.y)
	var next := previous+Vector2(effect.vx,effect.vy)
	var first := 2.0
	var hit: Dictionary = {}
	for candidate in sim.state.fighters+sim.state.props:
		var prop: bool = candidate.has("broken")
		if prop:
			if candidate.broken or float(effect.z) > (210.0 if candidate.get("mikawa_asset","") in ["kflag","uflag"] else 110.0): continue
		elif candidate.team == 1 or candidate.hp <= 0 or candidate.id in effect.hit_ids: continue
		var projected := clampf((Vector2(candidate.x,candidate.y)-previous).dot(next-previous)/maxf(.001,(next-previous).length_squared()),0,1)
		var point := previous.lerp(next,projected)
		if absf(candidate.x-point.x) > (float(candidate.width)*.5 if prop else 30.0): continue
		if absf(candidate.y-point.y) > (float(candidate.depth)*.5 if prop else (42.0 if kind == "wave" else 24.0)): continue
		if not prop and (float(effect.z) < float(candidate.z)-12 or float(effect.z) > float(candidate.z)+155): continue
		if projected < first: first = projected; hit = candidate
		if kind == "wave" and not prop:
			effect.hit_ids.append(candidate.id)
			if sim._damage(candidate,int(effect.damage),effect.owner,false,true,false,true,point.x,point.y,"tominaga_heavy_chop",24,"blade"): sim._launch(candidate,int(effect.face),7,6)
	effect.x = next.x; effect.y = next.y
	if kind == "wave": return
	effect.range_left -= Vector2(effect.vx,effect.vy/.4).length()
	if not hit.is_empty():
		effect.x = previous.lerp(next,first).x; effect.y = previous.lerp(next,first).y
		if hit.has("broken"): sim._damage_prop(hit,int(effect.damage),int(effect.owner),"blunt")
		else: sim._damage(hit,int(effect.damage),int(effect.owner),false,true,false,true,effect.x,effect.y,"udono_ranged_rock_volley",24,"blunt")
		effect.life = 0
		sim._effect("mikawa_fx",effect.x,effect.y,24,{"asset":"stone_impact","z":effect.z,"owner":effect.owner})
		audio(sim,"stone_hit",int(effect.owner))
	if effect.range_left <= 0 or effect.x < sim._left_edge()-128 or effect.x > sim._right_edge()+128: effect.life = 0

static func note_hit(sim, boss: Dictionary, attacker: Dictionary, attack_id: int, action: String) -> void:
	if boss.get("mikawa_role","") != "udono" or attacker.is_empty() or attacker.team != 0 or boss.hp <= 0: return
	if boss.stun > 0 or boss.freeze > 0: boss.mikawa_pressure.clear(); return
	var key := "%d:%d" % [int(attacker.id),attack_id]
	for hit in boss.mikawa_pressure:
		if hit.key == key: return
	var distance := absf(float(attacker.x)-float(boss.x))
	var band := "near" if distance <= 260 else ("far" if distance >= 320 else "")
	if band == "" or action in ["poison","burn"]: return
	boss.mikawa_pressure.append({"key":key,"tick":int(sim.state.tick),"band":band})

static func _counter(sim, boss: Dictionary) -> void:
	if boss.stun > 0 or boss.freeze > 0:
		boss.mikawa_pressure.clear()
		return
	var tick: int = sim.state.tick
	boss.mikawa_pressure = boss.mikawa_pressure.filter(func(h): return tick-int(h.tick) <= 150)
	if boss.action != "idle" or tick < int(boss.mikawa_counters.shared): return
	var hits: Array = boss.mikawa_pressure
	if hits.size() < 3: return
	var far: Array = hits.filter(func(h): return h.band == "far")
	var near: Array = hits.filter(func(h): return h.band == "near")
	var band := "far" if far.size() >= 3 and float(far.size())/hits.size() >= .6 else "near"
	var selected: Array = far if band == "far" else near
	if selected.size() < 3 or int(selected[-1].tick)-int(selected[0].tick)<48: return
	var key := "rock" if band == "far" else "spin"
	if tick < int(boss.mikawa_counters[key]): return
	boss.mikawa_counters[key] = tick+480
	boss.mikawa_counters.shared = tick+240
	boss.mikawa_pressure.clear()
	start(sim,boss,"udono_ranged_rock_volley" if band == "far" else "udono_melee_spin_counter")

static func blocks_grab(fighter: Dictionary) -> bool:
	return fighter.get("mikawa_role","") in Data.SHIELD_ROLES+["udono"]

static func permits_launch(fighter: Dictionary) -> bool:
	if fighter.get("mikawa_role","") == "udono": return false
	if fighter.get("mikawa_role","") in Data.SHIELD_ROLES: return fighter.action == "down"
	return true

static func shield_result(target: Dictionary, action: String, heavy: bool, attacker_kind: String) -> Dictionary:
	if target.get("mikawa_role","") in Data.SHIELD_ROLES:
		return {"scale":1.0 if Data.charged(action) else .5,"heavy":Data.charged(action) and (attacker_kind != "oichi" or action == "charge_rain")}
	return {"scale":1.0,"heavy":heavy}

static func audio(sim, cue: String, actor: int, voice: bool = false) -> void:
	sim._event("mikawa_audio",0,0,actor,0,{"cue":cue,"voice":voice})
