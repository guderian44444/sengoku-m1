extends SceneTree
const Battle = preload("res://core/battle.gd")
const Tent = preload("res://core/stage03_tent.gd")
const Encounter = preload("res://core/stage03_encounter.gd")
const Wire = preload("res://core/wire.gd")
const Stages = preload("res://core/stage_data.gd")
var checks := 0
var failures := 0

func _init():
	initial_tests()
	death_tests()
	target_and_retreat_tests()
	wire_and_sync_tests()
	print("STAGE03 TENT %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		push_error("FAILED: " + label)

func fresh(players: int = 1):
	var sim = Battle.new()
	sim.reset_campaign("normal",players,["nobunaga","oichi"],3)
	sim._enter_segment(3)
	return sim

func kill(sim, f: Dictionary):
	f.entering = false
	f.action = "idle"
	f.invuln = 0
	sim._damage(f,10000,sim.state.fighters[0].id,true,false,true)

func boss(sim, index: int) -> Dictionary:
	return sim._fighter(sim.state.encounter.leaders[index].id)

func minions(sim) -> Array:
	return sim.state.fighters.filter(func(f):return f.team == 1 and f.kind != "boss" and f.hp > 0)

func initial_tests():
	var data := Stages.chapter(3)
	check(data.segments.size() == 4 and Tent.valid_spec(data.segments[3].encounters[0],2600),"fourth tent scene spec")
	for players in [1,2]:
		var sim = fresh(players)
		check(boss(sim,0).id != boss(sim,1).id and boss(sim,0).lieutenant_slot == 1 and boss(sim,1).lieutenant_slot == 2,"independent leader IDs and slots")
		check(Tent.population(sim.state) == (4 if players == 1 else 6),"ordinary population excludes two bosses")
		check(Encounter.population(sim.state) == Tent.population(sim.state),"shared population API excludes leaders")
		check(Wire.valid_snapshot(sim.get_state()),"initial tent snapshot")
	var sim = fresh()
	sim._enter_segment(2)
	var player: Dictionary = sim.state.fighters[0]
	player.hp = 87
	player.rage = 64
	player.x = sim.state.encounter.breach_x + 20
	Encounter.tick(sim)
	for tick in range(50): sim.step([])
	player.x = sim.state.stage.encounter_end - 100
	sim.step([])
	check(sim.state.stage.index == 3 and sim.state.encounter.kind == "lieutenants","actual formation exit enters tent")
	check(sim.state.fighters[0].hp == 87 and sim.state.fighters[0].rage == 64,"tent transition preserves player health and rage")

func death_tests():
	for order in [[0,1],[1,0]]:
		var sim = fresh()
		var e: Dictionary = sim.state.encounter
		var ids: Array = e.leaders.map(func(b):return b.id)
		boss(sim,order[1]).hp -= 17
		var survivor_hp: int = boss(sim,order[1]).hp
		kill(sim,boss(sim,order[0]))
		Encounter.tick(sim)
		check(e.phase == "active" and e.leaders[order[0]].defeated,"one leader dead continues phase")
		kill(sim,minions(sim)[0])
		Encounter.enemy_defeated(sim,sim.state.fighters.filter(func(f):return f.team == 1 and f.kind != "boss" and f.hp <= 0)[0])
		check(e.tickets.size() == 1,"ordinary death deduplicates while one leader dead")
		sim.state.tick += e.delay_ticks
		Encounter.tick(sim)
		check(Tent.population(sim.state) == e.target and e.tickets.is_empty(),"one surviving leader keeps minion replenishment")
		check(boss(sim,order[1]).hp == survivor_hp and e.leaders.map(func(b):return b.id) == ids,"no boss healing or new IDs")
		kill(sim,minions(sim)[0])
		sim.state.tick += e.delay_ticks
		var before: int = e.spawned_count
		var alive: Array = minions(sim).map(func(f):return f.id)
		kill(sim,boss(sim,order[1]))
		Encounter.tick(sim)
		check(e.phase == "awaiting_yoshimoto" and e.tickets.is_empty(),"second leader death transitions and cancels old queue")
		check(e.spawned_count == before and minions(sim).map(func(f):return f.id) == alive,"same-tick due admission cancelled; current soldiers retained")
		for tick in range(400):
			sim.state.fighters[0].invuln = 5
			sim.step([])
		check(e.leaders.all(func(b):return b.defeated) and sim.state.fighters.filter(func(f):return f.kind == "boss" and not f.get("is_yoshimoto",false)).is_empty(),"dead leaders stay dead after corpse cleanup")
		check(e.phase == "yoshimoto" and e.yoshimoto_id not in ids and Wire.valid_snapshot(sim.get_state()),"leader tombstones persist through independent Yoshimoto phase")
	var same = fresh(2)
	kill(same,boss(same,0))
	kill(same,boss(same,1))
	Encounter.tick(same)
	check(same.state.encounter.phase == "awaiting_yoshimoto" and Tent.population(same.state) > 0,"simultaneous leader deaths ignore surviving minions")
	var restart = fresh()
	kill(restart,boss(restart,0))
	kill(restart,minions(restart)[0])
	var old_ids: Array = restart.state.encounter.leaders.map(func(b):return b.id)
	restart._start_checkpoint(0)
	check(restart.state.encounter.leaders.all(func(b):return not b.defeated) and restart.state.encounter.leaders[0].id not in old_ids,"explicit restart alone creates fresh leaders")
	check(restart.state.encounter.tickets.is_empty() and Wire.valid_snapshot(restart.get_state()),"restart discards old queue and tombstones")
	for terminal in ["won","lost"]:
		var stopped = fresh()
		kill(stopped,minions(stopped)[0])
		stopped.state.phase = terminal
		stopped.step([])
		check(stopped.state.encounter.phase == "cancelled" and stopped.state.encounter.tickets.is_empty() and Wire.valid_snapshot(stopped.get_state()),terminal + " cancels tent reservations")

func target_and_retreat_tests():
	var sim = fresh(2)
	var a: Dictionary = boss(sim,0)
	var b: Dictionary = boss(sim,1)
	var party: Array = sim.state.fighters.filter(func(f):return f.team == 0)
	check(Tent.target_for(sim,a,party[0]).id == party[0].id and Tent.target_for(sim,b,party[0]).id == party[1].id,"two leaders split co-op targets")
	var stable := true
	for tick in range(179):
		sim.state.tick = tick
		party[0].x = 1200 + (40 if tick % 2 == 0 else -40)
		party[1].x = 1200 - (40 if tick % 2 == 0 else -40)
		stable = stable and Tent.target_for(sim,a,party[1]).id == party[0].id
	check(stable,"nearby crossing players do not oscillate held target")
	party[0].hp = 0
	check(Tent.target_for(sim,a,party[0]).id == party[1].id,"invalid dead target changes immediately")
	a.x = 900
	a.y = 450
	b.x = 1000
	b.y = 480
	a.hp = 177
	a.cooldown = 0
	party[1].x = 850
	party[1].y = 450
	var starts := []
	var last := "approach"
	var bounded := true
	var recovered := false
	for tick in range(500):
		sim.state.tick = tick + 180
		var before := Vector2(a.x,a.y)
		Tent.steer(sim,a,party[1])
		if a.tactic == "retreat" and last != "retreat": starts.append(sim.state.tick)
		if a.tactic == "retreat": bounded = bounded and Vector2(a.x-a.retreat_origin_x,a.y-a.retreat_origin_y).length() <= sim.state.encounter.tactics.retreat_distance + .01
		if a.tactic == "recover": recovered = recovered or before == Vector2(a.x,a.y)
		last = a.tactic
	check(bounded and recovered and starts.size() <= 3,"separation has bounded travel and recovery")
	check(starts.size() < 2 or starts[1] - starts[0] >= sim.state.encounter.tactics.retreat_cooldown,"retreat cooldown prevents endless retreat restart")
	check(a.hp == 177,"tactics never restore boss HP")
	a.x = 81
	a.y = 360
	a.tactic = "approach"
	a.retreat_ready_tick = 0
	party[1].x = 100
	for tick in range(80):
		sim.state.tick += 1
		Tent.steer(sim,a,party[1])
	check(a.x >= 80 and a.y >= 360 and a.y <= 600 and a.tactic != "retreat","wall retreat ends within arena")

func wire_and_sync_tests():
	var host = fresh(2)
	var twin = fresh(2)
	var valid := true
	var equal := true
	for tick in range(600):
		if tick == 50:
			for sim in [host,twin]: kill(sim,minions(sim)[0])
		if tick == 200:
			for sim in [host,twin]: kill(sim,boss(sim,0))
		for sim in [host,twin]:
			for f in sim.state.fighters:
				if f.team == 0: f.invuln = 5
			sim.step([])
		if tick % 3 == 0:
			var remote: Dictionary = bytes_to_var(var_to_bytes(host.get_state()))
			remote.events = []
			valid = valid and Wire.valid_snapshot(remote)
			equal = equal and remote.encounter == host.state.encounter and remote.fighters == host.state.fighters
	check(valid and equal and host.get_state() == twin.get_state(),"200 host snapshot roundtrips preserve target/tactics/HP/queue deterministically")
	var baseline: Dictionary = fresh().get_state()
	for field in ["leaders","tactics","transition_tick","tickets","target"]:
		var bad := baseline.duplicate(true)
		bad.encounter[field] = "bad"
		check(not Wire.valid_snapshot(bad),"reject " + field + " type")
	var bad := baseline.duplicate(true)
	bad.encounter.leaders[1].id = bad.encounter.leaders[0].id
	check(not Wire.valid_snapshot(bad),"reject duplicate leader IDs")
	bad = baseline.duplicate(true)
	bad.encounter.leaders[0].defeated = true
	check(not Wire.valid_snapshot(bad),"reject live boss with dead tombstone")
	bad = baseline.duplicate(true)
	bad.fighters = bad.fighters.filter(func(f):return f.id != bad.encounter.leaders[0].id)
	check(not Wire.valid_snapshot(bad),"reject missing live leader")
	bad = baseline.duplicate(true)
	bad.encounter.phase = "awaiting_yoshimoto"
	bad.encounter.transition_tick = 0
	check(not Wire.valid_snapshot(bad),"reject premature phase transition")

	bad = baseline.duplicate(true)
	var alarm = Battle.new()
	alarm.reset_campaign("normal",1,["nobunaga"],3)
	var pillar: Dictionary = alarm.state.props.filter(func(p):return p.kind == "bell_pillar")[0].duplicate(true)
	pillar.id = 999999
	bad.props.append(pillar)
	check(not Wire.valid_snapshot(bad),"reject foreign alarm pillar in tent before renderer")
