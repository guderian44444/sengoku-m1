extends SceneTree

const Battle = preload("res://core/battle.gd")
const Alarm = preload("res://core/stage03_encounter.gd")
const Stages = preload("res://core/stage_data.gd")
const Wire = preload("res://core/wire.gd")
const Audio = preload("res://render/combat_audio.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_test_data()
	_test_queue()
	_test_supports()
	_test_cancel()
	_test_wire()
	_test_inputs()
	print("STAGE03 ALARM %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + label)

func fresh(players: int = 1):
	var sim = Battle.new()
	sim.reset_campaign("normal",players,["nobunaga","oichi"],3)
	return sim

func kill(sim, fighter: Dictionary) -> void:
	fighter.entering = false
	fighter.action = "idle"
	fighter.invuln = 0
	sim._damage(fighter,500,sim.state.fighters[0].id,true,false,true)

func enemies(sim) -> Array:
	return sim.state.fighters.filter(func(f):return f.team == 1 and f.hp > 0)

func pillars(sim) -> Array:
	return sim.state.props.filter(func(p):return p.kind == "bell_pillar")

func _test_data() -> void:
	check(not Stages.available().any(func(s):return s.id == 3),"prototype hidden from normal chapter progression")
	var data := Stages.chapter(3)
	var spec: Dictionary = data.segments[0].encounters[0]
	check(Alarm.valid_spec(spec,2400),"alarm spec validates")
	for field in ["solo","coop","delay_ticks","admit_ticks"]:
		var invalid := spec.duplicate(true)
		invalid.population[field] = -1
		check(not Alarm.valid_spec(invalid,2400),"negative " + field + " rejected")
	for players in [1,2]:
		var sim = fresh(players)
		check(Alarm.population(sim.state) == (6 if players == 1 else 9),"population includes entering actors")
		check(Wire.valid_snapshot(sim.get_state()),"initial authoritative snapshot")
		check(enemies(sim).all(func(f):return f.entering and f.face == -1 and f.x > Battle.camera_left(sim.state) + 1280),"fixed offscreen right entry")
	var multi = fresh()
	multi.state.fighters = multi.state.fighters.filter(func(f):return f.team == 0)
	multi.state.props = []
	var configurable := spec.duplicate(true)
	configurable.alarm.supports.append([1010,485])
	Alarm.begin(multi,configurable)
	check(pillars(multi).size() == 3 and Wire.valid_snapshot(multi.get_state()),"configurable three-post alarm")
	for index in range(2):
		multi._damage_prop(pillars(multi)[index],1000,multi.state.fighters[0].id)
		Alarm.tick(multi)
		check(multi.state.encounter.ringing,"all configured supports required")
	multi._damage_prop(pillars(multi)[2],1000,multi.state.fighters[0].id)
	Alarm.tick(multi)
	check(not multi.state.encounter.ringing,"third configured support stops alarm")

func _test_queue() -> void:
	var sim = fresh()
	var enemy: Dictionary = enemies(sim)[0]
	kill(sim,enemy)
	check(sim.state.encounter.tickets.size() == 1 and Alarm.population(sim.state) == 5,"real damage reserves one replacement")
	Alarm.enemy_defeated(sim,enemy)
	check(sim.state.encounter.tickets.size() == 1,"duplicate death callback ignored")
	var old := enemy.duplicate(true)
	old.id += 10000
	old.encounter_epoch -= 1
	old.replacement_queued = false
	Alarm.enemy_defeated(sim,old)
	check(sim.state.encounter.tickets.size() == 1,"old encounter death ignored")
	sim.state.tick = 239
	Alarm.tick(sim)
	check(Alarm.population(sim.state) == 5,"no replacement before due tick")
	sim.state.tick = 240
	Alarm.tick(sim)
	check(Alarm.population(sim.state) == 6 and sim.state.encounter.tickets.is_empty(),"one due replacement admitted")
	for f in enemies(sim): kill(sim,f)
	check(sim.state.encounter.tickets.size() == 6 and Alarm.population(sim.state) == 0,"mass deaths have bounded reservations")
	sim.state.tick = 480
	Alarm.tick(sim)
	check(Alarm.population(sim.state) == 1 and sim.state.encounter.tickets.size() == 5,"backlog admits only one")
	for tick in range(481,525):
		sim.state.tick = tick
		Alarm.tick(sim)
	check(Alarm.population(sim.state) == 1,"minimum admission spacing")
	sim.state.tick = 525
	Alarm.tick(sim)
	check(Alarm.population(sim.state) == 2,"next admission after spacing")
	check(Wire.valid_snapshot(sim.get_state()),"queued population snapshot validates")
	var crowded = fresh()
	kill(crowded,enemies(crowded)[0])
	while crowded.state.fighters.size() < Alarm.ACTOR_LIMIT:
		var corpse: Dictionary = crowded._make_fighter(1,"soldier",1700,490,65)
		corpse.hp = 0
		corpse.action = "defeated"
		corpse.damage_tick = 240
		corpse.encounter_epoch = crowded.state.encounter.epoch
		corpse.replacement_queued = true
		crowded.state.fighters.append(corpse)
	crowded.state.tick = 240
	Alarm.tick(crowded)
	check(crowded.state.encounter.tickets.size() == 1,"actor cap retains reservation")
	crowded.state.fighters.pop_back()
	Alarm.tick(crowded)
	check(crowded.state.fighters.size() == Alarm.ACTOR_LIMIT and crowded.state.encounter.tickets.is_empty(),"single admission when capacity opens")

func _test_supports() -> void:
	var sim = fresh()
	kill(sim,enemies(sim)[0])
	sim._damage_prop(pillars(sim)[0],1000,sim.state.fighters[0].id)
	Alarm.tick(sim)
	check(sim.state.encounter.ringing and Audio.alarm_should_ring(sim.state),"one broken post keeps bell ringing")
	check(Wire.valid_snapshot(sim.get_state()),"partial support destruction snapshot")
	sim.state.tick = 240
	var before: int = sim.state.encounter.spawned_count
	sim._damage_prop(pillars(sim)[1],1000,sim.state.fighters[0].id)
	Alarm.tick(sim)
	check(sim.state.encounter.phase == "draining" and sim.state.encounter.tickets.is_empty(),"all broken posts cancel due reservations")
	check(sim.state.encounter.spawned_count == before and not Audio.alarm_should_ring(sim.state),"same-tick stop precedes due admission")
	check(Wire.valid_snapshot(sim.get_state()),"stopped alarm snapshot validates")
	for f in enemies(sim): kill(sim,f)
	for tick in range(60): sim.step([])
	check(sim.state.phase == "playing" and sim.state.stage.go and sim.state.encounter.phase == "complete","alarm clears to next scene after remaining enemies")
	check(sim.state.encounter.spawned_count == before and Wire.valid_snapshot(sim.get_state()),"terminal state cannot replenish")

func _test_cancel() -> void:
	for terminal in ["won","lost"]:
		var sim = fresh()
		kill(sim,enemies(sim)[0])
		sim.state.phase = terminal
		sim.step([])
		check(sim.state.encounter.phase == "cancelled" and sim.state.encounter.tickets.is_empty(),terminal + " cancels queued work")
		check(not Audio.alarm_should_ring(sim.state) and Wire.valid_snapshot(sim.get_state()),terminal + " snapshot/audio valid")
	var loss = fresh()
	loss.state.fighters[0].hp = 0
	loss.state.fighters[0].lives = 0
	loss.step([])
	check(loss.state.phase == "lost" and not loss.state.encounter.ringing,"actual party wipe stops bell in same tick")
	var sim = fresh()
	kill(sim,enemies(sim)[0])
	var old_epoch: int = sim.state.encounter.epoch
	sim._start_checkpoint(0)
	check(sim.state.encounter.epoch != old_epoch and sim.state.encounter.tickets.is_empty(),"checkpoint restart discards old reservations")
	check(Alarm.population(sim.state) == 6 and pillars(sim).size() == 2 and Wire.valid_snapshot(sim.get_state()),"checkpoint restart cleans old actors and supports")
	sim.reset_campaign("normal",1,["nobunaga"],1)
	check(not sim.state.has("encounter") and Wire.valid_snapshot(sim.get_state()),"chapter reset removes encounter reservations")
	sim.reset_campaign("normal",1,["nobunaga"],3)
	check(sim.state.encounter.tickets.is_empty() and Alarm.population(sim.state) == 6,"new run starts with fresh capacity")

func rejected(world: Dictionary, label: String) -> void:
	check(not Wire.valid_snapshot(world),"reject " + label)

func _test_wire() -> void:
	var sim = fresh()
	kill(sim,enemies(sim)[0])
	var valid: Dictionary = sim.get_state()
	check(Wire.valid_snapshot(bytes_to_var(var_to_bytes(valid))),"snapshot copy preserves pending work")
	for key in ["epoch","target","delay_ticks","admit_ticks","next_admit_tick","spawned_count","stopped_tick","ringing","tickets","support_ids","entry_lanes"]:
		var invalid := valid.duplicate(true)
		invalid.encounter[key] = "wrong-type"
		rejected(invalid,key + " type")
	var invalid := valid.duplicate(true)
	invalid.erase("encounter")
	rejected(invalid,"prototype without encounter")
	invalid = valid.duplicate(true)
	invalid.encounter.tickets.append(invalid.encounter.tickets[0].duplicate())
	rejected(invalid,"duplicate death ticket")
	invalid = valid.duplicate(true)
	invalid.encounter.tickets[0].epoch += 1
	rejected(invalid,"old ticket epoch")
	invalid = valid.duplicate(true)
	invalid.encounter.tickets[0].id = enemies(sim)[0].id
	rejected(invalid,"ticket for living enemy")
	invalid = valid.duplicate(true)
	invalid.encounter.support_ids.append(invalid.encounter.support_ids[0])
	rejected(invalid,"duplicate support")
	invalid = valid.duplicate(true)
	invalid.encounter.ringing = false
	rejected(invalid,"ringing/phase mismatch")
	invalid = valid.duplicate(true)
	invalid.encounter.target = 1
	rejected(invalid,"population plus reservations above target")
	invalid = valid.duplicate(true)
	invalid.fighters[-1].encounter_epoch += 1
	rejected(invalid,"actor epoch mismatch")
	invalid = valid.duplicate(true)
	invalid.stage.prototype = false
	rejected(invalid,"unflagged one-scene stage")
	invalid = Battle.new().get_state()
	invalid.props.append(pillars(sim)[0].duplicate(true))
	invalid.props[-1].id = 999999
	rejected(invalid,"orphan pillar without encounter")
	invalid = valid.duplicate(true)
	invalid.props.append(pillars(sim)[0].duplicate(true))
	invalid.props[-1].id = 999999
	rejected(invalid,"pillar outside support group")
	check(not Wire.valid_input({"dx":0,"dy":0,"buttons":0,"tickets":[]}),"client input cannot submit encounter queue")

func _test_inputs() -> void:
	var a = fresh(2)
	var b = fresh(2)
	var snapshots_valid := true
	for tick in range(720):
		for sim in [a,b]:
			for f in sim.state.fighters:
				if f.team == 0: f.invuln = 5
		var buttons: int = Battle.LIGHT if tick % 3 == 0 else 0
		var inputs := [{"dx":1 if tick < 280 else 0,"dy":0,"buttons":buttons},{"dx":1 if tick < 250 else 0,"dy":0,"buttons":buttons}]
		a.step(inputs)
		b.step(inputs)
		snapshots_valid = snapshots_valid and Wire.valid_snapshot(a.get_state())
	check(snapshots_valid,"720 real co-op simulation snapshots validate")
	check(a.get_state() == b.get_state(),"identical authoritative input is deterministic")
	check(enemies(a).any(func(f):return not f.entering),"existing enemy movement enters playable area")
	var melee = fresh()
	var post: Dictionary = pillars(melee)[0]
	var player: Dictionary = melee.state.fighters[0]
	player.x = post.x - 75
	player.y = post.y
	player.face = 1
	var hp: int = post.hp
	for tick in range(90):
		player.invuln = 5
		melee.step([{"dx":0,"dy":0,"buttons":Battle.LIGHT if tick % 2 == 0 else 0}])
	check(post.hp < hp,"real player attack input damages reachable ground support")
