extends RefCounted

const KINDS := ["soldier", "archer", "shield_spear", "fire_archer", "raider"]
const PHASES := ["active", "complete", "cancelled"]

static func valid_spec(spec: Dictionary, width: float) -> bool:
	if spec.get("mode") == "barriers":
		var b: Variant = spec.get("barriers")
		if not b is Dictionary or not b.get("layers") is Array or b.layers.is_empty() or b.layers.size() > 6: return false
		if not number(b.get("width"),60,180) or not number(b.get("depth"),264,360): return false
		var previous := 100.0
		for layer in b.layers:
			if not layer is Array or layer.size() != 2 or not number(layer[0],previous + 180,width - 100) or not setting(layer[1],1,1000): return false
			previous = float(layer[0])
		return true
	if spec.get("mode") != "formation" or not spec.get("formation") is Dictionary or not spec.get("population") is Dictionary: return false
	var f: Dictionary = spec.formation
	var p: Dictionary = spec.population
	if not setting(f.get("gap_ticks"),30,600) or not number(f.get("breach_x"),1800,width - 100): return false
	if not setting(p.get("solo"),4,16) or not setting(p.get("coop"),p.solo,16): return false
	if not setting(p.get("delay_ticks"),1,1800) or not setting(p.get("admit_ticks"),1,600): return false
	if not f.get("slots") is Array or f.slots.size() != int(p.coop): return false
	var front := 0
	var rear := 0
	for index in range(f.slots.size()):
		var slot: Variant = f.slots[index]
		if not slot is Array or slot.size() != 4 or not setting(slot[0],0,1) or slot[1] not in KINDS: return false
		if not number(slot[2],500,f.breach_x - 180) or not number(slot[3],370,590): return false
		if index < int(p.solo):
			if slot[0] == 0: front += 1
			else: rear += 1
		for other in f.slots.slice(0,index):
			if absf(other[2] - slot[2]) < 70 and absf(other[3] - slot[3]) < 45: return false
	if front < 2 or rear < 2: return false
	var front_x: float = f.slots.filter(func(row):return row[0] == 0).map(func(row):return row[2]).max()
	var rear_x: float = f.slots.filter(func(row):return row[0] == 1).map(func(row):return row[2]).min()
	return front >= 2 and rear >= 2 and rear_x >= front_x + 120

static func begin(sim, spec: Dictionary) -> void:
	var world: Dictionary = sim.state
	if spec.mode == "barriers":
		var e := {"kind":"barriers","epoch":int(sim._next_id),"phase":"active","barrier_ids":[]}
		world.encounter = e
		for layer in spec.barriers.layers:
			var id: int = sim._next_id
			sim._next_id += 1
			world.props.append({"id":id,"kind":"barricade","x":float(layer[0]),"y":480.0,"hp":int(layer[1]),"max_hp":int(layer[1]),
				"width":float(spec.barriers.width),"depth":float(spec.barriers.depth),"broken":false,"drop":"","food_id":"","mandatory":true,"talisman_id":"",
				"encounter_epoch":e.epoch,"stage03_barrier":true})
			e.barrier_ids.append(id)
	else:
		var p: Dictionary = spec.population
		var count: int = world.fighters.filter(func(f):return f.team == 0).size()
		var target: int = int(p.solo if count == 1 else p.coop)
		world.encounter = {"kind":"formation","epoch":int(sim._next_id),"phase":"active","target":target,"delay_ticks":int(p.delay_ticks),
			"admit_ticks":int(p.admit_ticks),"next_admit_tick":int(world.tick),"tickets":[],"spawned_count":0,"gap_ticks":int(spec.formation.gap_ticks),
			"breach_x":float(spec.formation.breach_x),"breached":false,"slots":[]}
		for index in range(target):
			var row: Array = spec.formation.slots[index]
			world.encounter.slots.append({"id":index + 1,"rank":int(row[0]),"x":float(row[2]),"y":float(row[3]),"occupant":0,"gap_until":0})
			spawn(sim,str(row[1]),world.encounter.slots[-1],true)
	phase_event(sim,"active")

static func population(world: Dictionary) -> int:
	return world.fighters.filter(func(f):return f.team == 1 and f.hp > 0 and f.get("encounter_epoch",-1) == world.encounter.epoch).size()

static func barriers_left(world: Dictionary) -> int:
	return world.props.filter(func(p):return p.id in world.encounter.barrier_ids and not p.broken).size()

static func enemy_defeated(sim, fighter: Dictionary) -> void:
	var e: Dictionary = sim.state.encounter
	if e.kind != "formation": return
	if fighter.team != 1 or fighter.hp > 0 or fighter.get("replacement_queued",false) or fighter.get("encounter_epoch",-1) != e.epoch: return
	fighter.replacement_queued = true
	var slot: Dictionary = e.slots[int(fighter.formation_slot) - 1]
	if slot.occupant != fighter.id: return
	slot.occupant = 0
	slot.gap_until = int(sim.state.tick) + int(e.gap_ticks) if slot.rank == 0 else 0
	if e.phase != "active" or sim.state.phase != "playing": return
	if population(sim.state) + e.tickets.size() >= e.target: return
	e.tickets.append({"id":int(fighter.id),"epoch":int(e.epoch),"due_tick":int(sim.state.tick) + int(e.delay_ticks),
		"kind":str(fighter.get("role",fighter.kind)),"slot":int(slot.id) if slot.rank == 1 else 0})

static func tick(sim) -> void:
	var world: Dictionary = sim.state
	var e: Dictionary = world.encounter
	if e.kind == "barriers":
		if barriers_left(world) == 0:
			e.phase = "complete"
			phase_event(sim,"complete")
		return
	var party: Array = world.fighters.filter(func(f):return f.team == 0)
	var front_x: float = e.slots.filter(func(slot):return slot.rank == 0).map(func(slot):return slot.x).max()
	if party.any(func(f):return f.hp > 0 and f.x >= front_x + 100): e.breached = true
	if party.all(func(f):return f.hp > 0 and f.x >= e.breach_x and f.z == 0):
		e.tickets.clear()
		e.phase = "complete"
		phase_event(sim,"complete")
		return
	for front in e.slots:
		if front.rank != 0 or front.occupant != 0 or world.tick < front.gap_until: continue
		var candidates := []
		for rear in e.slots:
			if rear.rank != 1 or rear.occupant == 0: continue
			var f: Dictionary = sim._fighter(rear.occupant)
			if f.is_empty() or f.hp <= 0 or f.get("entering",false) or f.action != "idle" or f.freeze > 0 or f.stun > 0 or f.airborne_lock or f.held_by != 0: continue
			candidates.append({"slot":rear,"fighter":f,"distance":Vector2(f.x-front.x,f.y-front.y).length() + (300 if f.kind == "archer" else 0)})
		candidates.sort_custom(func(a,b):return a.distance < b.distance if a.distance != b.distance else a.fighter.id < b.fighter.id)
		if candidates.is_empty(): continue
		var chosen: Dictionary = candidates[0]
		var rear: Dictionary = chosen.slot
		var mover: Dictionary = chosen.fighter
		front.occupant = mover.id
		mover.formation_slot = front.id
		mover.formation_moving = true
		rear.occupant = 0
		for ticket in e.tickets:
			if ticket.slot == 0:
				ticket.slot = rear.id
				break
	if world.tick < e.next_admit_tick or world.fighters.size() >= 48: return
	# Unresolved front deaths cannot block resolved rear admissions after a mass wipe.
	for index in range(e.tickets.size()):
		var ticket: Dictionary = e.tickets[index]
		if world.tick < ticket.due_tick or ticket.slot == 0: continue
		var rear: Dictionary = e.slots[ticket.slot - 1]
		if rear.occupant != 0: continue
		spawn(sim,ticket.kind,rear,false)
		e.tickets.remove_at(index)
		e.next_admit_tick = int(world.tick) + int(e.admit_ticks)
		break

static func spawn(sim, kind: String, slot: Dictionary, initial: bool) -> void:
	var e: Dictionary = sim.state.encounter
	var hp: int = {"soldier":65,"archer":52,"shield_spear":90,"fire_archer":58,"raider":82}[kind]
	var coop: bool = sim.state.fighters.filter(func(f):return f.team == 0).size() == 2
	var f: Dictionary = sim._make_fighter(1,kind,slot.x,slot.y,maxi(1,roundi(hp * sim._difficulty.enemy_hp * (1.35 if coop else 1.0))))
	f.encounter_epoch = e.epoch
	f.replacement_queued = false
	f.formation_slot = slot.id
	f.formation_moving = not initial
	f.face = -1
	f.cooldown = 55
	f.home_x = slot.x
	f.home_y = slot.y
	if not initial:
		f.x = maxf(float(sim.state.stage.width) + 160,sim.camera_left(sim.state) + 1520) + (e.spawned_count % e.target) * 30
		f.entering = true
		f.entry_x = slot.x
	slot.occupant = f.id
	sim.state.fighters.append(f)
	e.spawned_count += 1

static func steer(sim, fighter: Dictionary, target: Dictionary) -> bool:
	if not sim.state.has("encounter") or sim.state.encounter.kind != "formation" or sim.state.encounter.phase != "active": return false
	if fighter.get("encounter_epoch",-1) != sim.state.encounter.epoch or sim.state.encounter.breached: return false
	fighter.move_dx = 0
	fighter.move_dy = 0
	if fighter.freeze > 0 or fighter.stun > 0 or fighter.airborne_lock or fighter.held_by != 0 or fighter.action not in ["idle","retreat"]: return true
	var slot: Dictionary = sim.state.encounter.slots[int(fighter.formation_slot) - 1]
	fighter.face = 1 if target.x >= fighter.x else -1
	var ranged: bool = fighter.kind in ["archer","gunner"]
	var reach := 760.0 if ranged else 165.0
	var attack_distance: float = absf(target.x-fighter.x)
	if fighter.cooldown == 0 and attack_distance < reach and absf(target.y-fighter.y) < 32 and (not ranged or attack_distance >= 270): return false
	var delta := Vector2(float(slot.x)-fighter.x,float(slot.y)-fighter.y)
	if delta.length() <= 5:
		fighter.formation_moving = false
		return true
	fighter.formation_moving = true
	var move: Vector2 = delta.limit_length(1.4 * sim.ENEMY_SPEED)
	fighter.move_dx = int(signf(move.x))
	fighter.move_dy = int(signf(move.y))
	sim._move_fighter(fighter,move.x,move.y)
	return true

static func phase_event(sim, phase: String) -> void:
	sim._event("encounter_phase",0.0,0.0,0,0,{"phase":phase,"encounter_epoch":int(sim.state.encounter.epoch)})

static func valid_state(world: Dictionary) -> bool:
	var e: Dictionary = world.encounter
	if world.props.any(func(p):return p.kind == "bell_pillar"): return false
	if e.get("phase") not in PHASES or not integer(e.get("epoch"),1,1000000000): return false
	if world.phase != "playing" and e.phase == "active": return false
	if e.kind == "barriers":
		if not e.get("barrier_ids") is Array or e.barrier_ids.is_empty() or e.barrier_ids.size() > 6: return false
		var ids := {}
		for id in e.barrier_ids:
			if not integer(id,1,1000000000) or ids.has(id): return false
			var found: Array = world.props.filter(func(p):return p.id == id and p.kind == "barricade" and p.get("stage03_barrier",false) and p.get("encounter_epoch",-1) == e.epoch and p.get("mandatory",false) and p.depth >= 264 and p.y == 480)
			if found.size() != 1: return false
			ids[id] = true
		if world.props.any(func(p):return p.get("stage03_barrier",false) and not ids.has(p.id)): return false
		return (barriers_left(world) == 0) == (e.phase == "complete") if e.phase != "cancelled" else true
	if e.kind != "formation": return false
	if not e.get("breached") is bool: return false
	if not integer(e.get("target"),4,16) or not integer(e.get("gap_ticks"),30,600) or not number(e.get("breach_x"),1800,world.stage.width - 100): return false
	if not integer(e.get("delay_ticks"),1,1800) or not integer(e.get("admit_ticks"),1,600) or not integer(e.get("next_admit_tick"),0,1000000000) or not integer(e.get("spawned_count"),e.target,1000000000): return false
	if not e.get("slots") is Array or e.slots.size() != e.target or not e.get("tickets") is Array or e.tickets.size() > e.target: return false
	var occupants := {}
	for index in range(e.slots.size()):
		var slot: Variant = e.slots[index]
		if not slot is Dictionary or slot.get("id") != index + 1 or not integer(slot.get("rank"),0,1): return false
		if not number(slot.get("x"),500,e.breach_x - 180) or not number(slot.get("y"),370,590) or not integer(slot.get("gap_until"),0,1000000000) or not integer(slot.get("occupant"),0,1000000000): return false
		if slot.occupant == 0: continue
		if occupants.has(slot.occupant): return false
		var matches: Array = world.fighters.filter(func(f):return f.id == slot.occupant and f.team == 1 and f.hp > 0 and f.get("formation_slot",0) == slot.id and f.get("encounter_epoch",-1) == e.epoch)
		if matches.size() != 1: return false
		occupants[slot.occupant] = true
	for f in world.fighters:
		if f.team != 1: continue
		if f.get("role", f.kind) not in KINDS: return false
		if f.get("encounter_epoch",-1) != e.epoch or not integer(f.get("formation_slot"),1,e.target) or not f.get("formation_moving") is bool or not f.get("replacement_queued") is bool: return false
		if f.hp > 0 and not occupants.has(f.id): return false
	var fronts: Array = e.slots.filter(func(slot):return slot.rank == 0)
	var rears: Array = e.slots.filter(func(slot):return slot.rank == 1)
	if fronts.size() < 2 or rears.size() < 2: return false
	if rears.map(func(slot):return slot.x).min() < fronts.map(func(slot):return slot.x).max() + 120: return false
	if e.phase != "active" and not e.tickets.is_empty(): return false
	var tickets := {}
	var destinations := {}
	for t in e.tickets:
		if not t is Dictionary or t.size() != 5 or not integer(t.get("id"),1,1000000000) or tickets.has(t.id) or t.get("epoch") != e.epoch: return false
		if not integer(t.get("due_tick"),0,1000000000) or t.get("kind") not in KINDS or not integer(t.get("slot"),0,e.target): return false
		if world.fighters.any(func(f):return f.id == t.id and f.hp > 0): return false
		if t.slot != 0:
			if destinations.has(t.slot) or e.slots[t.slot - 1].rank != 1 or e.slots[t.slot - 1].occupant != 0: return false
			destinations[t.slot] = true
		tickets[t.id] = true
	return population(world) + e.tickets.size() <= e.target

static func integer(value: Variant, low: int, high: int) -> bool:
	return value is int and value >= low and value <= high

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func setting(value: Variant, low: float, high: float) -> bool:
	return number(value,low,high) and float(value) == floorf(float(value))
