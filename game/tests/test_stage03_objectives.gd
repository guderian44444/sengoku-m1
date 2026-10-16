extends SceneTree

const Battle = preload("res://core/battle.gd")
const Encounter = preload("res://core/stage03_encounter.gd")
const Objective = preload("res://core/stage03_objectives.gd")
const Stages = preload("res://core/stage_data.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func _init() -> void:
	data_tests()
	barrier_tests()
	formation_tests()
	breached_combat_tests()
	wipe_and_cancel_tests()
	wire_tests()
	sync_tests()
	print("STAGE03 OBJECTIVES %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAILED: " + label)

func fresh(scene: int, players: int = 1):
	var sim = Battle.new()
	sim.reset_campaign("normal",players,["nobunaga","oichi"],3)
	sim._enter_segment(scene)
	return sim

func kill(sim, fighter: Dictionary) -> void:
	fighter.entering = false
	fighter.action = "idle"
	fighter.invuln = 0
	sim._damage(fighter,500,sim.state.fighters[0].id,true,false,true)

func front(sim) -> Array:
	return sim.state.encounter.slots.filter(func(s):return s.rank == 0)

func data_tests() -> void:
	var data := Stages.chapter(3)
	check(data.segments.size() == 4 and Stages.available().any(func(s):return s.id == 3),"four completed scenes are available")
	for region in data.segments:
		check(Encounter.valid_spec(region.encounters[0],region.width),"valid scene " + region.name)
	var bad: Dictionary = data.segments[1].encounters[0].duplicate(true)
	bad.barriers.depth = 240
	check(not Encounter.valid_spec(bad,2600),"reject barrier that leaves a lane detour")
	bad = data.segments[1].encounters[0].duplicate(true)
	bad.barriers.layers[1][0] = bad.barriers.layers[0][0]
	check(not Encounter.valid_spec(bad,2600),"reject overlapping layers")
	bad = data.segments[2].encounters[0].duplicate(true)
	for row in bad.formation.slots: row[0] = 1
	check(not Encounter.valid_spec(bad,3000),"reject formation without front ranks")
	bad = data.segments[2].encounters[0].duplicate(true)
	bad.formation.slots[3][2] = 800
	check(not Encounter.valid_spec(bad,3000),"reserve must begin behind front")

func barrier_tests() -> void:
	var sim = fresh(1)
	check(sim.state.encounter.kind == "barriers" and Objective.barriers_left(sim.state) == 3,"three mandatory layers")
	check(Wire.valid_snapshot(sim.get_state()),"barrier snapshot validates")
	var player: Dictionary = sim.state.fighters[0]
	var layers: Array = sim.state.props
	for index in range(layers.size()):
		var prop: Dictionary = layers[index]
		for lane in [360,395,480,575,600]:
			for height in [0,100]:
				player.x = prop.x - 150
				player.y = lane
				player.z = height
				sim._move_fighter(player,4000,0,true)
				check(player.x <= prop.x - prop.width * .5 - 19,"no lane/jump/shove detour at layer %d" % index)
		player.x = prop.x - 80
		player.y = 480
		player.z = 0
		player.face = 1
		if index == 0:
			for tick in range(360): sim.step([{"dx":0,"dy":0,"buttons":Battle.LIGHT if tick % 2 == 0 else 0}])
			check(prop.broken,"actual player light attacks destroy first full-depth layer")
		else: sim._damage_prop(prop,1000,player.id)
		Encounter.tick(sim)
		check(Objective.barriers_left(sim.state) == 2-index,"layer progress updates")
		var before: float = prop.x - prop.width * .5 - 20
		player.x = before
		sim._move_fighter(player,100)
		check(player.x > before + 50,"destroyed layer opens its collision")
	check(sim.state.encounter.phase == "complete","all layers required to clear")
	for tick in range(50): sim.step([])
	check(sim.state.stage.go and sim.state.phase == "playing","barriers open forward transition")
	player.x = 2500
	sim.step([])
	check(sim.state.stage.index == 2 and sim.state.encounter.kind == "formation","walk through exit enters formation")
	check(Wire.valid_snapshot(sim.get_state()),"transition discards old barrier state")

func formation_tests() -> void:
	for players in [1,2]:
		var sim = fresh(2,players)
		check(Objective.population(sim.state) == (6 if players == 1 else 9),"formation population for party size")
		check(Wire.valid_snapshot(sim.get_state()),"initial mixed formation snapshot")
		check(front(sim).map(func(s):return s.x).min() != front(sim).map(func(s):return s.x).max(),"front has deliberate horizontal offsets")
	var sim = fresh(2)
	var e: Dictionary = sim.state.encounter
	var vacancy: Dictionary = front(sim)[0]
	var dead: Dictionary = sim._fighter(vacancy.occupant)
	kill(sim,dead)
	check(vacancy.occupant == 0 and e.tickets.size() == 1 and e.tickets[0].slot == 0,"front death opens gap with unresolved rear reservation")
	Encounter.enemy_defeated(sim,dead)
	check(e.tickets.size() == 1,"duplicate front death ignored")
	sim.state.tick = e.gap_ticks - 1
	Encounter.tick(sim)
	check(vacancy.occupant == 0,"front gap held for configured minimum")
	var rears: Array = e.slots.filter(func(s):return s.rank == 1)
	var before := {}
	for slot in rears:
		var f: Dictionary = sim._fighter(slot.occupant)
		f.hp = 33
		before[f.id] = {"x":f.x,"y":f.y,"hp":f.hp,"kind":f.kind,"role":f.get("role", ""),"slot":slot.id}
	sim.state.tick = e.gap_ticks
	Encounter.tick(sim)
	var mover: Dictionary = sim._fighter(vacancy.occupant)
	check(not mover.is_empty() and before.has(mover.id),"existing rear soldier uniquely reserves front gap")
	var original: Dictionary = before[mover.id]
	check(mover.x == original.x and mover.y == original.y and mover.hp == original.hp,"assignment does not teleport or heal mover")
	check(mover.kind == original.kind and mover.get("role", "") == original.role,"assignment preserves actual soldier role")
	check(e.tickets[0].slot == original.slot and e.slots[original.slot-1].occupant == 0,"replacement targets vacated rear, not front")
	var previous: float = mover.x
	sim.step([])
	check(mover.x < previous and previous - mover.x < 3,"real movement advances toward gap by a bounded step")
	for tick in range(180): sim.step([])
	check(mover.x < original.x - 100 and mover.hp == 33,"rear unit walks forward over multiple ticks with unchanged HP")
	var refill: Dictionary = sim._fighter(e.slots[original.slot-1].occupant)
	check(not refill.is_empty() and refill.id != mover.id and refill.entering and refill.x > Battle.camera_left(sim.state) + 1280,"new soldier enters offscreen rear position")
	check(Objective.population(sim.state) + e.tickets.size() == e.target and Wire.valid_snapshot(sim.get_state()),"movement and rear admission maintain reserved capacity")
	kill(sim,mover)
	check(vacancy.occupant == 0 and e.tickets.size() == 1,"mover killed en route creates one new vacancy")
	check(Wire.valid_snapshot(sim.get_state()),"en-route death snapshot validates")
	var many = fresh(2)
	for slot in front(many).slice(0,2): kill(many,many._fighter(slot.occupant))
	many.state.tick = many.state.encounter.gap_ticks
	Encounter.tick(many)
	var a: int = front(many)[0].occupant
	var b: int = front(many)[1].occupant
	check(a != 0 and b != 0 and a != b,"two front gaps cannot reserve the same rear soldier")
	check(many.state.encounter.tickets[0].slot != many.state.encounter.tickets[1].slot,"rear refill destinations are unique")

func breached_combat_tests() -> void:
	var sim = fresh(2)
	var defender: Dictionary = sim._fighter(front(sim)[0].occupant)
	var player: Dictionary = sim.state.fighters[0]
	player.x = 1200
	player.y = defender.y
	var start: float = defender.x
	Encounter.tick(sim)
	check(sim.state.encounter.breached,"crossing front line releases formation combat")
	var attacks := false
	for tick in range(180):
		player.invuln = 5
		sim.step([])
		attacks = attacks or defender.action in Battle.ENEMY_TIMING
	check(defender.x > start + 10 and attacks,"front defender turns, pursues and attacks after breach")
	player.x = 200
	Encounter.tick(sim)
	check(sim.state.encounter.breached and Wire.valid_snapshot(sim.get_state()),"breach combat state persists in authoritative snapshot")

func wipe_and_cancel_tests() -> void:
	var sim = fresh(2)
	for f in sim.state.fighters:
		if f.team == 1: kill(sim,f)
	check(sim.state.encounter.tickets.size() == 6,"mass wipe queues bounded population")
	var valid := true
	for tick in range(2200):
		sim.state.fighters[0].invuln = 5
		sim.step([])
		if tick % 3 == 0: valid = valid and Wire.valid_snapshot(sim.get_state())
	check(valid,"mass wipe recovery snapshots validate through corpse cleanup")
	check(Objective.population(sim.state) == 6 and sim.state.encounter.tickets.is_empty(),"resolved rear admissions prevent mass-wipe deadlock")
	var coop = fresh(2,2)
	var players: Array = coop.state.fighters.filter(func(f):return f.team == 0)
	kill(coop,coop._fighter(front(coop)[0].occupant))
	players[0].x = coop.state.encounter.breach_x + 50
	Encounter.tick(coop)
	check(coop.state.encounter.phase == "active","co-op breach waits for both living players")
	players[1].x = players[0].x + 20
	Encounter.tick(coop)
	check(coop.state.encounter.phase == "complete" and coop.state.encounter.tickets.is_empty() and Objective.population(coop.state) > 0,"breach completes with surviving enemies and cancels reservations")
	for tick in range(50): coop.step([])
	check(coop.state.phase == "playing" and coop.state.stage.go and Wire.valid_snapshot(coop.get_state()),"formation opens tent passage without killing every soldier")
	var survivor: Dictionary = coop.state.fighters.filter(func(f):return f.team == 1 and f.hp > 0)[0]
	var occupied: Dictionary = coop.state.encounter.slots[survivor.formation_slot-1]
	kill(coop,survivor)
	check(occupied.occupant == 0 and coop.state.encounter.tickets.is_empty() and Wire.valid_snapshot(coop.get_state()),"exit combat clears dead occupants without restarting reinforcements")
	for mode in [1,2]:
		for terminal in ["won","lost"]:
			var cancelled = fresh(mode)
			cancelled.state.phase = terminal
			cancelled.step([])
			check(cancelled.state.encounter.phase == "cancelled" and Wire.valid_snapshot(cancelled.get_state()),"terminal cancels objective " + str(mode) + terminal)
	var restart = fresh(2)
	kill(restart,restart._fighter(front(restart)[0].occupant))
	var epoch: int = restart.state.encounter.epoch
	restart._start_checkpoint(0)
	check(restart.state.encounter.epoch != epoch and restart.state.encounter.tickets.is_empty() and Wire.valid_snapshot(restart.get_state()),"formation restart removes old actors, vacancies, reservations")

func rejected(world: Dictionary, label: String) -> void:
	check(not Wire.valid_snapshot(world),"reject " + label)

func wire_tests() -> void:
	var sim = fresh(2)
	kill(sim,sim._fighter(front(sim)[0].occupant))
	sim.state.tick = sim.state.encounter.gap_ticks
	Encounter.tick(sim)
	var valid: Dictionary = sim.get_state()
	for field in ["slots","gap_ticks","breach_x","target","tickets","breached"]:
		var bad := valid.duplicate(true)
		bad.encounter[field] = "bad"
		rejected(bad,field + " type")
	var bad := valid.duplicate(true)
	bad.encounter.slots[1].occupant = bad.encounter.slots[0].occupant
	rejected(bad,"duplicate mover reservation")
	bad = valid.duplicate(true)
	bad.encounter.tickets[0].slot = 1
	rejected(bad,"new soldier assigned directly to front")
	bad = valid.duplicate(true)
	bad.encounter.tickets[0].epoch += 1
	rejected(bad,"stale reinforcement epoch")
	bad = valid.duplicate(true)
	bad.encounter.tickets.append(bad.encounter.tickets[0].duplicate())
	rejected(bad,"duplicate replacement and destination")
	bad = valid.duplicate(true)
	bad.fighters[-1].formation_slot = 0
	rejected(bad,"invalid actor slot")
	var wall = fresh(1)
	bad = wall.get_state()
	bad.props[0].depth = 100
	rejected(bad,"barrier with bypassable depth")
	bad = wall.get_state()
	bad.props[0].erase("mandatory")
	rejected(bad,"barrier missing mandatory flag without crashing validation")
	bad = wall.get_state()
	bad.encounter.barrier_ids.append(bad.encounter.barrier_ids[0])
	rejected(bad,"duplicate barrier group")
	bad = wall.get_state()
	bad.erase("encounter")
	rejected(bad,"orphan barrier objective")

func sync_tests() -> void:
	var host = fresh(2,2)
	var twin = fresh(2,2)
	var remote := {}
	var all_valid := true
	var reservations_match := true
	for tick in range(900):
		if tick in [15,60,300]:
			for sim in [host,twin]:
				var living: Array = sim.state.fighters.filter(func(f):return f.team == 1 and f.hp > 0 and not f.get("entering",false))
				if not living.is_empty(): kill(sim,living[0])
		for sim in [host,twin]:
			for f in sim.state.fighters:
				if f.team == 0: f.invuln = 5
		var inputs := [{"dx":0,"dy":0,"buttons":0},{"dx":0,"dy":0,"buttons":0}]
		host.step(inputs)
		twin.step(inputs)
		if tick % 3 == 0:
			remote = bytes_to_var(var_to_bytes(host.get_state()))
			remote.events = []
			all_valid = all_valid and Wire.valid_snapshot(remote)
			reservations_match = reservations_match and remote.encounter == host.state.encounter and remote.fighters == host.state.fighters
	check(all_valid and reservations_match,"300 authoritative snapshot roundtrips preserve movement reservations without events")
	check(host.get_state() == twin.get_state(),"formation movement and reinforcement schedule are deterministic")
	check(not Wire.valid_input({"dx":0,"dy":0,"buttons":0,"formation_slot":1}),"client input cannot choose formation assignments")
