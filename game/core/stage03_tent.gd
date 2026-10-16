extends RefCounted

const Rules = preload("res://core/stage03_objectives.gd")
const PHASES := ["active","awaiting_yoshimoto","cancelled"]
const VARIANTS := ["naginata","dual_swords"]
const ATTACKS := ["boss_thrust","boss_sweep","boss_counter","boss_double"]

static func valid_spec(spec: Dictionary, width: float) -> bool:
	if spec.get("mode") != "lieutenants" or not spec.get("population") is Dictionary or not spec.get("tactics") is Dictionary: return false
	var p: Dictionary = spec.population
	if not Rules.setting(p.get("solo"),1,12) or not Rules.setting(p.get("coop"),p.solo,12): return false
	if not Rules.setting(p.get("delay_ticks"),1,1800) or not Rules.setting(p.get("admit_ticks"),1,600): return false
	if not p.get("kinds") is Array or p.kinds.is_empty() or p.kinds.size() > 8: return false
	for kind in p.kinds:
		if kind not in Rules.KINDS: return false
	var t: Dictionary = spec.tactics
	for key in ["retreat_ticks","recover_ticks","target_hold_ticks"]:
		if not Rules.setting(t.get(key),12,600): return false
	if not Rules.setting(t.get("retreat_cooldown"),t.retreat_ticks + t.recover_ticks,1800): return false
	if not Rules.number(t.get("separation"),150,450) or not Rules.number(t.get("retreat_distance"),20,140): return false
	if not spec.get("leaders") is Array or spec.leaders.size() != 2: return false
	for index in range(2):
		var b: Variant = spec.leaders[index]
		if not b is Dictionary or b.get("key") != ["A","B"][index] or b.get("label") != "小王 %s（占位）" % ["A","B"][index]: return false
		if b.get("variant") not in VARIANTS or not Rules.setting(b.get("hp"),100,1000): return false
		if not Rules.number(b.get("x"),500,width - 300) or not Rules.number(b.get("y"),380,580): return false
		if not b.get("actions") is Array or b.actions.is_empty() or b.actions.size() > 4: return false
		for action in b.actions:
			if action not in ATTACKS: return false
	return Vector2(spec.leaders[0].x-spec.leaders[1].x,spec.leaders[0].y-spec.leaders[1].y).length() >= 200

static func begin(sim, spec: Dictionary) -> void:
	var p: Dictionary = spec.population
	var party: Array = sim.state.fighters.filter(func(f):return f.team == 0)
	var e := {"kind":"lieutenants","phase":"active","epoch":int(sim._next_id),"leaders":[],"target":int(p.solo if party.size() == 1 else p.coop),
		"tickets":[],"delay_ticks":int(p.delay_ticks),"admit_ticks":int(p.admit_ticks),"next_admit_tick":int(sim.state.tick),
		"kinds":p.kinds.duplicate(),"spawned_count":0,"tactics":spec.tactics.duplicate(true),"transition_tick":-1}
	# JSON settings become integer ticks in the authoritative runtime state.
	for key in ["retreat_ticks","recover_ticks","retreat_cooldown","target_hold_ticks"]: e.tactics[key] = int(e.tactics[key])
	sim.state.encounter = e
	for index in range(2):
		var spec_b: Dictionary = spec.leaders[index]
		var hp: int = maxi(1,roundi(float(spec_b.hp) * sim._difficulty.enemy_hp * (1.35 if party.size() == 2 else 1.0)))
		var b: Dictionary = sim._make_fighter(1,"boss",spec_b.x,spec_b.y,hp)
		b.encounter_epoch = e.epoch
		b.lieutenant_slot = index + 1
		b.display_name = str(spec_b.label)
		b.boss_variant = str(spec_b.variant)
		b.boss_actions = spec_b.actions.duplicate()
		b.stage_boss = false
		b.render_scale = 1.05 if index == 0 else 1.18
		b.replacement_queued = false
		b.ai_target_id = 0
		b.ai_target_until = 0
		b.tactic = "approach"
		b.tactic_until = 0
		b.retreat_ready_tick = 0
		b.retreat_origin_x = float(b.x)
		b.retreat_origin_y = float(b.y)
		b.retreat_dx = 0.0
		b.retreat_dy = 0.0
		b.cooldown = 75 + index * 35
		e.leaders.append({"id":int(b.id),"slot":index + 1,"label":str(spec_b.label),"max_hp":hp,"defeated":false})
		sim.state.fighters.append(b)
	for index in range(e.target): spawn_minion(sim)
	phase_event(sim,"active")

static func population(world: Dictionary) -> int:
	return world.fighters.filter(func(f):return f.team == 1 and f.kind != "boss" and f.hp > 0 and f.get("encounter_epoch",-1) == world.encounter.epoch).size()

static func enemy_defeated(sim, fighter: Dictionary) -> void:
	var e: Dictionary = sim.state.encounter
	if e.phase != "active" or fighter.team != 1 or fighter.hp > 0 or fighter.get("encounter_epoch",-1) != e.epoch: return
	if fighter.kind == "boss":
		for leader in e.leaders:
			if leader.id == fighter.id: leader.defeated = true
		return
	if fighter.get("replacement_queued",false): return
	fighter.replacement_queued = true
	if population(sim.state) + e.tickets.size() < e.target:
		e.tickets.append({"id":int(fighter.id),"epoch":int(e.epoch),"due_tick":int(sim.state.tick) + int(e.delay_ticks)})

static func tick(sim) -> void:
	var e: Dictionary = sim.state.encounter
	if e.phase != "active": return
	if e.leaders.all(func(b):return b.defeated):
		e.tickets.clear()
		e.phase = "awaiting_yoshimoto"
		e.transition_tick = int(sim.state.tick)
		phase_event(sim,"awaiting_yoshimoto")
		return
	if e.tickets.is_empty() or sim.state.tick < e.next_admit_tick or sim.state.fighters.size() >= 48: return
	var ticket: Dictionary = e.tickets[0]
	if ticket.epoch != e.epoch:
		e.tickets.pop_front()
		return
	if sim.state.tick < ticket.due_tick or population(sim.state) >= e.target: return
	e.tickets.pop_front()
	spawn_minion(sim)
	e.next_admit_tick = int(sim.state.tick) + int(e.admit_ticks)

static func spawn_minion(sim) -> void:
	var e: Dictionary = sim.state.encounter
	var kind: String = e.kinds[e.spawned_count % e.kinds.size()]
	var base: int = {"soldier":65,"archer":52,"shield_spear":90,"fire_archer":58,"raider":82}[kind]
	var coop: bool = sim.state.fighters.filter(func(f):return f.team == 0).size() == 2
	var f: Dictionary = sim._make_fighter(1,kind,0,[395.0,490.0,575.0][e.spawned_count % 3],maxi(1,roundi(base * sim._difficulty.enemy_hp * (1.35 if coop else 1.0))))
	f.encounter_epoch = e.epoch
	f.replacement_queued = false
	f.ai_target_id = 0
	f.ai_target_until = 0
	var camera: float = sim.camera_left(sim.state)
	f.x = camera + 1520 + (e.spawned_count % e.target) * 55
	f.face = -1
	f.entering = true
	f.entry_x = minf(camera + 1150,sim._right_edge() - 60)
	f.home_x = f.entry_x
	f.home_y = f.y
	f.cooldown = 55
	sim.state.fighters.append(f)
	e.spawned_count += 1

static func target_for(sim, fighter: Dictionary, fallback: Dictionary) -> Dictionary:
	if sim.state.get("encounter",{}).get("kind","") != "lieutenants": return fallback
	var e: Dictionary = sim.state.encounter
	if fighter.get("encounter_epoch",-1) != e.epoch: return fallback
	var held: Dictionary = sim._fighter(int(fighter.get("ai_target_id",0)))
	if not held.is_empty() and held.team == 0 and held.hp > 0 and sim.state.tick < fighter.ai_target_until: return held
	var party: Array = sim.state.fighters.filter(func(f):return f.team == 0 and f.hp > 0)
	if party.is_empty(): return fallback
	var slot: int = int(fighter.get("lieutenant_slot",fighter.id % 2 + 1)) - 1
	var preferred: Array = party.filter(func(f):return f.player_index == slot)
	var chosen: Dictionary = preferred[0] if not preferred.is_empty() else party[0]
	fighter.ai_target_id = chosen.id
	fighter.ai_target_until = int(sim.state.tick) + int(e.tactics.target_hold_ticks)
	return chosen

static func steer(sim, fighter: Dictionary, target: Dictionary) -> bool:
	if sim.state.get("encounter",{}).get("kind","") != "lieutenants" or not fighter.has("lieutenant_slot"): return false
	if sim.state.encounter.phase != "active": return false
	fighter.move_dx = 0
	fighter.move_dy = 0
	if fighter.action != "idle" or fighter.freeze > 0 or fighter.stun > 0 or fighter.airborne_lock or fighter.held_by != 0: return true
	var t: Dictionary = sim.state.encounter.tactics
	if fighter.tactic == "retreat":
		var displacement := Vector2(fighter.x-fighter.retreat_origin_x,fighter.y-fighter.retreat_origin_y)
		if sim.state.tick >= fighter.tactic_until or displacement.length() >= t.retreat_distance - 2:
			recover(sim,fighter)
			return true
		var before := Vector2(fighter.x,fighter.y)
		var move := Vector2(fighter.retreat_dx,fighter.retreat_dy) * minf(2.0,float(t.retreat_distance)-displacement.length())
		sim._move_fighter(fighter,move.x,move.y)
		fighter.move_dx = int(signf(move.x))
		fighter.move_dy = int(signf(move.y))
		if before.distance_to(Vector2(fighter.x,fighter.y)) < .1: recover(sim,fighter)
		return true
	if fighter.tactic == "recover":
		if sim.state.tick < fighter.tactic_until: return true
		fighter.tactic = "approach"
	var leaders: Array = sim.state.fighters.filter(func(f):return f.kind == "boss" and f.hp > 0 and f.id != fighter.id and f.get("encounter_epoch",-1) == sim.state.encounter.epoch)
	var away := Vector2(fighter.x-target.x,fighter.y-target.y)
	var close: bool = away.length() < 125
	if not leaders.is_empty():
		var other: Dictionary = leaders[0]
		var separation := Vector2(fighter.x-other.x,fighter.y-other.y)
		if separation.length() < t.separation:
			away = separation if separation.length() > 1 else Vector2(0, -1 if fighter.lieutenant_slot == 1 else 1)
			close = true
	if close and sim.state.tick >= fighter.retreat_ready_tick:
		var direction := away.normalized()
		if direction.length() < .5: direction = Vector2(-1,0)
		if fighter.x + direction.x * t.retreat_distance < 100 or fighter.x + direction.x * t.retreat_distance > sim._right_edge() - 30:
			direction = Vector2(0,1 if fighter.y < 480 else -1)
		fighter.tactic = "retreat"
		fighter.tactic_until = int(sim.state.tick) + int(t.retreat_ticks)
		fighter.retreat_ready_tick = int(sim.state.tick) + int(t.retreat_cooldown)
		fighter.retreat_origin_x = float(fighter.x)
		fighter.retreat_origin_y = float(fighter.y)
		fighter.retreat_dx = direction.x
		fighter.retreat_dy = direction.y
		return true
	return false

static func recover(sim, fighter: Dictionary) -> void:
	fighter.tactic = "recover"
	fighter.tactic_until = int(sim.state.tick) + int(sim.state.encounter.tactics.recover_ticks)
	fighter.cooldown = maxi(fighter.cooldown,int(sim.state.encounter.tactics.recover_ticks))

static func phase_event(sim, phase: String) -> void:
	sim._event("encounter_phase",0.0,0.0,0,0,{"phase":phase,"encounter_epoch":int(sim.state.encounter.epoch)})

static func valid_state(world: Dictionary) -> bool:
	var e: Dictionary = world.encounter
	if e.get("phase") not in PHASES or not Rules.integer(e.get("epoch"),1,1000000000): return false
	if world.phase != "playing" and e.phase == "active": return false
	if not Rules.integer(e.get("target"),1,12) or not Rules.integer(e.get("delay_ticks"),1,1800) or not Rules.integer(e.get("admit_ticks"),1,600): return false
	if not Rules.integer(e.get("next_admit_tick"),0,1000000000) or not Rules.integer(e.get("spawned_count"),e.target,1000000000) or not Rules.integer(e.get("transition_tick"),-1,1000000000): return false
	if not e.get("tactics") is Dictionary or not e.get("leaders") is Array or e.leaders.size() != 2: return false
	var t: Dictionary = e.tactics
	for key in ["retreat_ticks","recover_ticks","target_hold_ticks"]:
		if not Rules.integer(t.get(key),12,600): return false
	if not Rules.integer(t.get("retreat_cooldown"),t.retreat_ticks+t.recover_ticks,1800) or not Rules.number(t.get("separation"),150,450) or not Rules.number(t.get("retreat_distance"),20,140): return false
	if not e.get("kinds") is Array or e.kinds.is_empty() or e.kinds.size() > 8: return false
	for kind in e.kinds:
		if kind not in Rules.KINDS: return false
	var ids := {}
	for index in range(2):
		var b: Variant = e.leaders[index]
		if not b is Dictionary or not Rules.integer(b.get("id"),1,1000000000) or ids.has(b.id) or b.get("slot") != index+1: return false
		if b.get("label") != "小王 %s（占位）" % ["A","B"][index] or not Rules.integer(b.get("max_hp"),1,1000000) or not b.get("defeated") is bool: return false
		var found: Array = world.fighters.filter(func(f):return f.id == b.id)
		if found.is_empty():
			if not b.defeated: return false
		elif found.size() != 1 or found[0].kind != "boss" or found[0].get("lieutenant_slot",0) != index+1 or found[0].max_hp != b.max_hp or (found[0].hp <= 0) != b.defeated: return false
		ids[b.id] = true
	var both: bool = e.leaders.all(func(b):return b.defeated)
	if e.phase == "active" and (both or e.transition_tick != -1): return false
	if e.phase == "awaiting_yoshimoto" and (not both or e.transition_tick < 0): return false
	var player_ids: Array = world.fighters.filter(func(f):return f.team == 0).map(func(f):return f.id)
	for f in world.fighters:
		if f.team != 1: continue
		if f.get("encounter_epoch",-1) != e.epoch or not f.get("replacement_queued") is bool: return false
		if not Rules.integer(f.get("ai_target_id"),0,1000000000) or not Rules.integer(f.get("ai_target_until"),0,1000000000): return false
		if f.ai_target_id != 0 and f.ai_target_id not in player_ids: return false
		if f.kind != "boss":
			if f.get("role",f.kind) not in Rules.KINDS or f.has("lieutenant_slot"): return false
			continue
		if not ids.has(f.id) or not Rules.integer(f.get("lieutenant_slot"),1,2) or f.get("tactic") not in ["approach","retreat","recover"]: return false
		for key in ["tactic_until","retreat_ready_tick"]:
			if not Rules.integer(f.get(key),0,1000000000): return false
		for key in ["retreat_origin_x","retreat_origin_y"]:
			if not Rules.number(f.get(key),-10000,10000): return false
		for key in ["retreat_dx","retreat_dy"]:
			if not Rules.number(f.get(key),-1,1): return false
	if not e.get("tickets") is Array or e.tickets.size() > e.target or (e.phase != "active" and not e.tickets.is_empty()): return false
	var tickets := {}
	for ticket in e.tickets:
		if not ticket is Dictionary or ticket.size() != 3 or not Rules.integer(ticket.get("id"),1,1000000000) or tickets.has(ticket.id) or ids.has(ticket.id): return false
		if ticket.get("epoch") != e.epoch or not Rules.integer(ticket.get("due_tick"),0,1000000000) or world.fighters.any(func(f):return f.id == ticket.id and f.hp > 0): return false
		tickets[ticket.id] = true
	return population(world) + e.tickets.size() <= e.target
