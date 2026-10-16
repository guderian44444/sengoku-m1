extends RefCounted

const Rules = preload("res://core/stage03_objectives.gd")
const RANGED := ["boss_arrow","boss_sword_wave"]
const TACTICS := ["approach","sidestep","backstep","recover","guard"]

static func valid_spec(s: Variant, width: float) -> bool:
	if not s is Dictionary or not Rules.setting(s.get("hp"),200,2000) or not Rules.number(s.get("x"),800,width-200) or not Rules.number(s.get("y"),380,580): return false
	if not Rules.number(s.get("move_speed"),2.5,4) or not Rules.number(s.get("melee_enter"),250,450) or not Rules.number(s.get("ranged_enter"),s.melee_enter+100,800): return false
	for key in ["transition_ticks","ranged_cooldown","guard_cooldown","motion_cooldown"]:
		if not Rules.setting(s.get(key),60,600): return false
	for key in ["guard_ticks","guard_recover_ticks","motion_ticks","motion_recover_ticks"]:
		if not Rules.setting(s.get(key),12,60): return false
	return Rules.number(s.get("motion_distance"),30,100)

static func can_target(f: Dictionary) -> bool:
	return f.get("team",1) == 0 and f.hp > 0 and f.action not in ["down","recovering","defeated"] and not f.get("airborne_lock",false)

static func spawn(sim) -> void:
	var e: Dictionary = sim.state.encounter
	var s: Dictionary = e.yoshi_spec
	var coop: bool = sim.state.fighters.filter(func(f):return f.team == 0).size() == 2
	var hp: int = maxi(1,roundi(float(s.hp) * sim._difficulty.enemy_hp * (1.35 if coop else 1.0)))
	var f: Dictionary = sim._make_fighter(1,"boss",maxf(sim.camera_left(sim.state)+1520,float(s.x)+180),s.y,hp)
	f.is_yoshimoto = true
	f.encounter_epoch = e.epoch
	f.replacement_queued = false
	f.display_name = "今川義元（占位）"
	f.stage_boss = true
	f.boss_variant = "naginata"
	f.boss_actions = ["boss_thrust","boss_sweep"]
	f.render_scale = 1.3
	f.entering = true
	f.entry_x = float(s.x)
	f.face = -1
	f.home_x = float(s.x)
	f.home_y = float(s.y)
	f.ai_target_id = 0
	f.ai_target_until = 0
	f.target_cycle = 0
	f.combat_mode = "melee"
	f.tactic = "approach"
	f.motion_until = 0
	f.motion_ready_tick = int(sim.state.tick) + 45
	f.motion_origin_x = float(f.x)
	f.motion_origin_y = float(f.y)
	f.motion_dx = 0.0
	f.motion_dy = 0.0
	f.motion_cycle = 0
	f.guard_ready_tick = 0
	f.ranged_ready_tick = int(sim.state.tick) + 90
	f.ranged_cycle = 0
	f.aim_dx = -1.0
	f.aim_dy = 0.0
	f.aim_face = -1
	f.cooldown = 60
	e.yoshimoto_id = f.id
	e.yoshimoto_max_hp = hp
	e.yoshimoto_defeated = false
	e.phase = "yoshimoto"
	sim.state.fighters.append(f)
	sim._event("encounter_phase",f.x,f.y,0,0,{"phase":"yoshimoto","encounter_epoch":int(e.epoch)})

static func target_for(sim, f: Dictionary, fallback: Dictionary) -> Dictionary:
	var party: Array = sim.state.fighters.filter(func(p):return can_target(p))
	if party.is_empty(): return fallback
	var held: Dictionary = sim._fighter(int(f.ai_target_id))
	if not held.is_empty() and can_target(held) and sim.state.tick < f.ai_target_until: return held
	var chosen: Dictionary = party[f.target_cycle % party.size()]
	f.target_cycle += 1
	f.ai_target_id = chosen.id
	f.ai_target_until = int(sim.state.tick) + int(sim.state.encounter.tactics.target_hold_ticks)
	return chosen

static func recover(sim, f: Dictionary, ticks: int) -> void:
	f.tactic = "recover"
	f.motion_until = int(sim.state.tick) + ticks
	f.cooldown = maxi(f.cooldown,ticks)

static func tick_action(sim, f: Dictionary) -> bool:
	if not f.get("is_yoshimoto",false) or f.action != "guard": return false
	if f.action_tick >= sim.state.encounter.yoshi_spec.guard_ticks:
		sim._begin(f,"idle")
		recover(sim,f,int(sim.state.encounter.yoshi_spec.guard_recover_ticks))
	return true

static func commit(sim, f: Dictionary, target: Dictionary, action: String) -> void:
	var delta := Vector2(target.x-f.x,target.y-f.y).normalized()
	f.face = 1 if delta.x >= 0 else -1
	f.aim_face = f.face
	f.aim_dx = delta.x
	f.aim_dy = delta.y
	f.target_x = target.x
	f.target_y = target.y
	sim._begin(f,action)
	if action in RANGED:
		f.ranged_ready_tick = int(sim.state.tick) + int(sim.state.encounter.yoshi_spec.ranged_cooldown)
		f.ranged_cycle += 1
		sim._effect("warning",target.x,target.y,int(sim.enemy_timing(f)[0]),{"owner":f.id,"radius":48.0 if action == "boss_arrow" else 88.0,"face":f.face})
	else:
		f.ai_cycle += 1
		sim._effect("warning",f.x+f.face*120,f.y,int(sim.enemy_timing(f)[0]),{"owner":f.id,"radius":180.0,"face":f.face})

static func steer(sim, f: Dictionary, target: Dictionary) -> bool:
	if not f.get("is_yoshimoto",false): return false
	f.move_dx = 0
	f.move_dy = 0
	if f.action != "idle" or f.freeze > 0 or f.stun > 0 or f.airborne_lock or f.held_by != 0: return true
	if not can_target(target): return true
	var s: Dictionary = sim.state.encounter.yoshi_spec
	if f.tactic == "recover":
		if sim.state.tick < f.motion_until: return true
		f.tactic = "approach"
	if f.tactic in ["sidestep","backstep"]:
		var travelled := Vector2(f.x-f.motion_origin_x,f.y-f.motion_origin_y).length()
		if sim.state.tick >= f.motion_until or travelled >= s.motion_distance - 2:
			recover(sim,f,int(s.motion_recover_ticks))
			return true
		var before := Vector2(f.x,f.y)
		var move := Vector2(f.motion_dx,f.motion_dy) * minf(2.0,float(s.motion_distance)-travelled)
		sim._move_fighter(f,move.x,move.y)
		f.move_dx = int(signf(move.x))
		f.move_dy = int(signf(move.y))
		if before.distance_to(Vector2(f.x,f.y)) < .1: recover(sim,f,int(s.motion_recover_ticks))
		return true
	f.tactic = "approach"
	var dx: float = target.x-f.x
	var dy: float = target.y-f.y
	var distance: float = absf(dx)
	if distance <= s.melee_enter: f.combat_mode = "melee"
	elif distance >= s.ranged_enter: f.combat_mode = "ranged"
	f.face = 1 if dx >= 0 else -1
	if f.cooldown == 0 and distance < 260 and absf(dy) < 80 and sim.state.tick >= f.guard_ready_tick and f.ai_cycle % 3 == 2:
		f.tactic = "guard"
		f.guard_ready_tick = int(sim.state.tick) + int(s.guard_cooldown)
		sim._begin(f,"guard")
		return true
	if f.cooldown == 0:
		if f.combat_mode == "ranged" and distance >= s.melee_enter + 40 and distance <= 1100 and absf(dy) < 150 and sim.state.tick >= f.ranged_ready_tick:
			commit(sim,f,target,RANGED[f.ranged_cycle % 2])
			return true
		if distance < 240 and absf(dy) < 40:
			commit(sim,f,target,f.boss_actions[f.ai_cycle % f.boss_actions.size()])
			return true
	if sim.state.tick >= f.motion_ready_tick and (f.cooldown > 0 or (f.combat_mode == "ranged" and sim.state.tick < f.ranged_ready_tick)):
		var direction := Vector2(0,1 if f.y < 480 else -1)
		if distance < 180 and f.x - f.face * s.motion_distance >= 100 and f.x - f.face * s.motion_distance <= sim._right_edge()-30:
			direction = Vector2(-f.face,0)
			f.tactic = "backstep"
		else: f.tactic = "sidestep"
		f.motion_until = int(sim.state.tick) + int(s.motion_ticks)
		f.motion_ready_tick = int(sim.state.tick) + int(s.motion_cooldown)
		f.motion_origin_x = float(f.x)
		f.motion_origin_y = float(f.y)
		f.motion_dx = direction.x
		f.motion_dy = direction.y
		f.motion_cycle += 1
		return true
	var movement := Vector2(signf(dx) if distance > 200 else 0.0,signf(dy) if absf(dy) > 8 else 0.0).normalized() * float(s.move_speed)
	sim._move_fighter(f,movement.x,movement.y)
	f.move_dx = int(signf(movement.x))
	f.move_dy = int(signf(movement.y))
	return true

static func release(sim, f: Dictionary) -> void:
	if not f.get("is_yoshimoto",false) or f.action not in RANGED: return
	f.ranged_ready_tick = maxi(int(f.ranged_ready_tick),int(sim.state.tick) + int(sim.state.encounter.yoshi_spec.ranged_cooldown))
	var wave: bool = f.action == "boss_sword_wave"
	var speed := 10.0 if wave else 14.0
	var vx: float = f.aim_dx * speed
	var vy: float = f.aim_dy * speed
	var lifetime: int = ceili(1100.0/maxf(.1,absf(vx))) + 2
	sim._effect("projectile",f.x+f.aim_face*50,f.y,lifetime,{"z":28.0,"vx":vx,"vy":vy,"face":int(f.aim_face),"owner":int(f.id),"team":1,
		"damage":maxi(1,roundi((22 if wave else 16) * sim._difficulty.enemy_damage)),"poison":0,"weapon":"blade" if wave else "arrow",
		"action":str(f.action),"action_tick":int(f.action_tick),"range_left":1100.0,"hit_depth":34.0 if wave else 16.0,"height_tolerance":70.0,
		"piercing":wave,"hit_ids":[],"previous_x":float(f.x)+f.aim_face*25,"previous_y":float(f.y),"yoshimoto_projectile":true,"boss_wave":wave})
	sim._weapon_release(f,"blade" if wave else "arrow")

static func valid_fighter(f: Dictionary, e: Dictionary) -> bool:
	if f.get("is_yoshimoto") != true or f.kind != "boss" or not f.get("stage_boss",false) or f.has("lieutenant_slot") or f.max_hp != e.yoshimoto_max_hp: return false
	if f.get("display_name") != "今川義元（占位）" or f.get("boss_variant") != "naginata" or f.get("boss_actions") != ["boss_thrust","boss_sweep"]: return false
	if f.get("combat_mode") not in ["melee","ranged"] or f.get("tactic") not in TACTICS: return false
	for key in ["target_cycle","motion_until","motion_ready_tick","motion_cycle","guard_ready_tick","ranged_ready_tick","ranged_cycle"]:
		if not Rules.integer(f.get(key),0,1000000000): return false
	for key in ["motion_origin_x","motion_origin_y"]:
		if not Rules.number(f.get(key),-10000,10000): return false
	for key in ["motion_dx","motion_dy","aim_dx","aim_dy"]:
		if not Rules.number(f.get(key),-1,1): return false
	if not Rules.integer(f.get("aim_face"),-1,1) or f.aim_face == 0: return false
	return f.action != "boss_volley" and f.action != "gun_shot"
