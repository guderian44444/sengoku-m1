extends RefCounted

# Chapter-three objectives opt in; ordinary chapters keep their existing wave rules.
const Tent = preload("res://core/stage03_tent.gd")
const Objectives = preload("res://core/stage03_objectives.gd")
const KINDS := ["soldier", "archer", "shield_spear", "fire_archer", "raider"]
const PHASES := ["active", "draining", "complete", "cancelled", "awaiting_yoshimoto", "yoshimoto"]
const ACTOR_LIMIT := 48

static func valid_spec(spec: Dictionary, width: float) -> bool:
	if spec.get("mode", "") == "lieutenants": return Tent.valid_spec(spec, width)
	if spec.get("mode", "") in ["barriers", "formation"]: return Objectives.valid_spec(spec, width)
	if spec.get("mode", "") != "alarm" or not spec.get("population") is Dictionary or not spec.get("alarm") is Dictionary: return false
	var population: Dictionary = spec.population
	for key in ["solo", "coop"]:
		if not _setting(population.get(key), 1, 16): return false
	if not _setting(population.get("delay_ticks"), 1, 1800) or not _setting(population.get("admit_ticks"), 1, 600): return false
	if not population.get("kinds") is Array or population.kinds.is_empty() or population.kinds.size() > 16: return false
	for kind in population.kinds:
		if kind not in KINDS: return false
	if not _setting(population.get("entry_side"), -1, 1) or population.entry_side == 0 or not population.get("entry_lanes") is Array: return false
	if population.entry_lanes.is_empty() or population.entry_lanes.size() > 4: return false
	for lane in population.entry_lanes:
		if not _number(lane, 360, 600): return false
	var alarm: Dictionary = spec.alarm
	if not alarm.get("supports") is Array or alarm.supports.is_empty() or alarm.supports.size() > 8: return false
	if not _setting(alarm.get("hp"), 1, 1000): return false
	for point in alarm.supports:
		if not point is Array or point.size() != 2 or not _number(point[0], 100, width - 100) or not _number(point[1], 360, 600): return false
	return _number(alarm.get("x"), 100, width - 100) and _number(alarm.get("y"), 360, 600) and _number(alarm.get("height"), 120, 360)

static func begin(sim, spec: Dictionary) -> void:
	if spec.get("mode", "") == "lieutenants":
		Tent.begin(sim, spec)
		return
	if spec.get("mode", "") in ["barriers", "formation"]:
		Objectives.begin(sim, spec)
		return
	var world: Dictionary = sim.state
	var population: Dictionary = spec.population
	var alarm: Dictionary = spec.alarm
	var players: int = world.fighters.filter(func(f): return f.team == 0).size()
	var encounter := {"kind":"alarm", "epoch":int(sim._next_id), "phase":"active", "ringing":true,
		"target":int(population.solo if players == 1 else population.coop), "delay_ticks":int(population.delay_ticks),
		"admit_ticks":int(population.admit_ticks), "next_admit_tick":int(world.tick), "tickets":[], "support_ids":[],
		"kinds":population.kinds.duplicate(), "entry_side":int(population.entry_side), "entry_lanes":population.entry_lanes.duplicate(),
		"bell_x":float(alarm.x), "bell_y":float(alarm.y), "bell_height":float(alarm.height), "stopped_tick":-1,
		"spawned_count":0,"bell_landed":false}
	world.encounter = encounter
	for point in alarm.supports:
		var id: int = sim._next_id
		sim._next_id += 1
		world.props.append({"id":id, "kind":"bell_pillar", "x":float(point[0]), "y":float(point[1]),
			"hp":int(alarm.hp), "max_hp":int(alarm.hp), "width":56.0, "depth":52.0, "broken":false,
			"drop":"", "food_id":"", "mandatory":true, "talisman_id":"", "encounter_epoch":encounter.epoch})
		encounter.support_ids.append(id)
	for index in range(encounter.target): _spawn(sim)
	sim._event("encounter_phase", encounter.bell_x, encounter.bell_y, 0, 0, {"phase":"active", "encounter_epoch":encounter.epoch})

static func population(world: Dictionary) -> int:
	if not world.has("encounter"): return 0
	if world.encounter.kind == "lieutenants": return Tent.population(world)
	var epoch: int = world.encounter.epoch
	return world.fighters.filter(func(f): return f.team == 1 and f.hp > 0 and int(f.get("encounter_epoch", -1)) == epoch).size()

static func supports_left(world: Dictionary) -> int:
	if not world.has("encounter"): return 0
	var ids: Array = world.encounter.support_ids
	return world.props.filter(func(p): return p.id in ids and not p.broken).size()

static func enemy_defeated(sim, fighter: Dictionary) -> void:
	var world: Dictionary = sim.state
	if not world.has("encounter") or world.phase != "playing": return
	var encounter: Dictionary = world.encounter
	if encounter.kind == "lieutenants":
		Tent.enemy_defeated(sim, fighter)
		return
	if encounter.kind != "alarm":
		Objectives.enemy_defeated(sim, fighter)
		return
	if encounter.phase != "active" or not encounter.ringing or supports_left(world) == 0: return
	if fighter.team != 1 or fighter.hp > 0 or fighter.kind == "boss" or fighter.get("replacement_queued", false): return
	if int(fighter.get("encounter_epoch", -1)) != encounter.epoch: return
	fighter.replacement_queued = true
	if population(world) + encounter.tickets.size() >= encounter.target: return
	encounter.tickets.append({"id":int(fighter.id), "due_tick":int(world.tick) + int(encounter.delay_ticks), "epoch":int(encounter.epoch)})

static func tick(sim) -> void:
	var world: Dictionary = sim.state
	var encounter: Dictionary = world.encounter
	if world.phase != "playing":
		cancel(sim)
		return
	if encounter.phase in ["complete", "cancelled"]: return
	if encounter.kind == "lieutenants":
		Tent.tick(sim)
		return
	if encounter.kind != "alarm":
		Objectives.tick(sim)
		return
	if encounter.phase == "active" and supports_left(world) == 0:
		encounter.tickets.clear()
		encounter.ringing = false
		encounter.phase = "draining"
		encounter.stopped_tick = world.tick
		sim._event("encounter_phase", encounter.bell_x, encounter.bell_y, 0, 0, {"phase":"draining", "encounter_epoch":encounter.epoch})
	if encounter.phase == "draining":
		if not encounter.bell_landed and world.tick >= encounter.stopped_tick + 36:
			encounter.bell_landed = true
			sim._event("bell_fall",encounter.bell_x,encounter.bell_y,0,0)
		if encounter.bell_landed and population(world) == 0:
			encounter.phase = "complete"
			sim._event("encounter_phase", encounter.bell_x, encounter.bell_y, 0, 0, {"phase":"complete", "encounter_epoch":encounter.epoch})
		return
	# Count reservations and entering soldiers; never admit a backlog in one burst.
	if encounter.tickets.is_empty() or world.tick < encounter.next_admit_tick or world.fighters.size() >= ACTOR_LIMIT: return
	var ticket: Dictionary = encounter.tickets[0]
	if ticket.epoch != encounter.epoch:
		encounter.tickets.pop_front()
		return
	if world.tick < ticket.due_tick or population(world) >= encounter.target: return
	encounter.tickets.pop_front()
	_spawn(sim)
	encounter.next_admit_tick = int(world.tick) + int(encounter.admit_ticks)

static func cancel(sim) -> void:
	if not sim.state.has("encounter"): return
	var encounter: Dictionary = sim.state.encounter
	if encounter.has("tickets"): encounter.tickets.clear()
	if encounter.has("ringing"): encounter.ringing = false
	if encounter.get("stopped_tick", 0) < 0: encounter.stopped_tick = sim.state.tick
	if encounter.phase not in ["complete", "cancelled"]:
		encounter.phase = "cancelled"
		sim._event("encounter_phase", encounter.get("bell_x", 0.0), encounter.get("bell_y", 0.0), 0, 0, {"phase":"cancelled", "encounter_epoch":encounter.epoch})

static func _spawn(sim) -> void:
	var world: Dictionary = sim.state
	var encounter: Dictionary = world.encounter
	var ordinal: int = encounter.spawned_count
	var kind: String = str(encounter.kinds[ordinal % encounter.kinds.size()])
	var hp: int = {"soldier":65, "archer":52, "shield_spear":90, "fire_archer":58, "raider":82}[kind]
	var players: int = world.fighters.filter(func(f): return f.team == 0).size()
	hp = maxi(1, roundi(hp * sim._difficulty.enemy_hp * (1.35 if players == 2 else 1.0)))
	var lane: float = float(encounter.entry_lanes[ordinal % encounter.entry_lanes.size()])
	var fighter: Dictionary = sim._make_fighter(1, kind, 0.0, lane, hp)
	var camera: float = sim.camera_left(world)
	var from_left: bool = encounter.entry_side == -1
	fighter.x = camera - 240.0 - (ordinal % encounter.target) * 55.0 if from_left else camera + 1520.0 + (ordinal % encounter.target) * 55.0
	fighter.face = 1 if from_left else -1
	fighter.entering = true
	fighter.entry_x = maxf(camera + 100.0, sim._left_edge() + 60.0) if from_left else minf(camera + 1150.0, sim._right_edge() - 60.0)
	fighter.home_x = fighter.entry_x
	fighter.home_y = lane
	fighter.cooldown = 55
	fighter.encounter_epoch = encounter.epoch
	fighter.replacement_queued = false
	world.fighters.append(fighter)
	encounter.spawned_count += 1

static func valid_state(world: Dictionary) -> bool:
	var encounter: Variant = world.get("encounter")
	if not encounter is Dictionary or not world.has("stage") or world.stage.id != 3: return false
	if encounter.get("kind") == "lieutenants": return Tent.valid_state(world)
	if encounter.get("kind") in ["barriers", "formation"]: return Objectives.valid_state(world)
	if encounter.get("kind") != "alarm" or encounter.get("phase") not in PHASES: return false
	if not _integer(encounter.get("epoch"), 1, 1000000000) or not _integer(encounter.get("target"), 1, 16): return false
	if not _integer(encounter.get("delay_ticks"), 1, 1800) or not _integer(encounter.get("admit_ticks"), 1, 600): return false
	for key in ["next_admit_tick", "spawned_count"]:
		if not _integer(encounter.get(key), 0, 1000000000): return false
	if not _integer(encounter.get("stopped_tick"), -1, 1000000000) or not encounter.get("ringing") is bool: return false
	if not encounter.get("bell_landed") is bool: return false
	if encounter.bell_landed and (encounter.ringing or world.tick < encounter.stopped_tick + 36): return false
	if encounter.phase == "complete" and not encounter.bell_landed: return false
	if encounter.ringing != (encounter.phase == "active"): return false
	if encounter.ringing and (world.phase != "playing" or encounter.stopped_tick != -1): return false
	if not encounter.ringing and encounter.stopped_tick < 0: return false
	if not _number(encounter.get("bell_x"), 100, world.stage.width - 100) or not _number(encounter.get("bell_y"), 360, 600) or not _number(encounter.get("bell_height"), 120, 360): return false
	if not encounter.get("support_ids") is Array or encounter.support_ids.is_empty() or encounter.support_ids.size() > 8: return false
	var support_set := {}
	for id in encounter.support_ids:
		if not _integer(id, 1, 1000000000) or support_set.has(id): return false
		var props: Array = world.props.filter(func(p): return p.id == id and p.kind == "bell_pillar" and p.get("encounter_epoch", -1) == encounter.epoch)
		if props.size() != 1: return false
		support_set[id] = true
	if world.props.any(func(p): return p.kind == "bell_pillar" and not support_set.has(p.id)): return false
	if encounter.phase == "active" and supports_left(world) == 0: return false
	if encounter.phase in ["draining", "complete"] and supports_left(world) != 0: return false
	for fighter in world.fighters:
		if fighter.team == 1 and (fighter.get("encounter_epoch") != encounter.epoch or not fighter.get("replacement_queued") is bool): return false
	if encounter.phase == "complete" and population(world) != 0: return false
	if not encounter.get("tickets") is Array or encounter.tickets.size() > encounter.target: return false
	if encounter.phase != "active" and not encounter.tickets.is_empty(): return false
	var tickets := {}
	for ticket in encounter.tickets:
		if not ticket is Dictionary or ticket.size() != 3: return false
		if not _integer(ticket.get("id"), 1, 1000000000) or tickets.has(ticket.id): return false
		if not _integer(ticket.get("due_tick"), 0, 1000000000) or ticket.get("epoch") != encounter.epoch: return false
		if world.fighters.any(func(f): return f.id == ticket.id and f.hp > 0): return false
		tickets[ticket.id] = true
	if not encounter.get("kinds") is Array or encounter.kinds.is_empty() or encounter.kinds.size() > 16: return false
	for kind in encounter.kinds:
		if kind not in KINDS: return false
	if encounter.get("entry_side") not in [-1, 1] or not encounter.get("entry_lanes") is Array or encounter.entry_lanes.is_empty() or encounter.entry_lanes.size() > 4: return false
	for lane in encounter.entry_lanes:
		if not _number(lane, 360, 600): return false
	return population(world) + encounter.tickets.size() <= encounter.target

static func _integer(value: Variant, low: int, high: int) -> bool:
	return value is int and value >= low and value <= high

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func _setting(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and float(value) == floorf(float(value))
