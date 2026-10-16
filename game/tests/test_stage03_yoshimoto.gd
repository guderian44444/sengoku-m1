extends SceneTree
const Battle = preload("res://core/battle.gd")
const Encounter = preload("res://core/stage03_encounter.gd")
const Tent = preload("res://core/stage03_tent.gd")
const Yoshi = preload("res://core/stage03_yoshimoto.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func _init():
	transition_tests()
	ranged_tests()
	guard_and_tactics_tests()
	speed_and_loss_tests()
	full_route_tests()
	wire_and_sync_tests()
	print("STAGE03 YOSHIMOTO %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		push_error("FAILED: " + label)

func kill(sim, f: Dictionary):
	f.entering = false
	f.action = "idle"
	f.invuln = 0
	sim._damage(f,10000,sim.state.fighters[0].id,true,false,true)

func advance(sim, ticks: int):
	for tick in range(ticks):
		for f in sim.state.fighters:
			if f.team == 0: f.invuln = 5
		sim.step([])

func tent(players: int = 1):
	var sim = Battle.new()
	sim.reset_campaign("normal",players,["nobunaga","oichi"],3)
	sim._enter_segment(3)
	return sim

func defeat_leaders(sim):
	for b in sim.state.encounter.leaders: kill(sim,sim._fighter(b.id))
	Encounter.tick(sim)

func fresh(players: int = 1):
	var sim = tent(players)
	defeat_leaders(sim)
	advance(sim,int(sim.state.encounter.yoshi_spec.transition_ticks))
	var boss: Dictionary = sim._fighter(sim.state.encounter.yoshimoto_id)
	boss.entering = false
	boss.x = 1500.0
	boss.y = 480.0
	boss.cooldown = 0
	boss.ranged_ready_tick = sim.state.tick
	boss.motion_ready_tick = 100000
	sim.state.fighters[0].x = 650.0
	sim.state.fighters[0].y = 480.0
	return sim

func yoshi(sim) -> Dictionary:
	return sim._fighter(sim.state.encounter.yoshimoto_id)

func transition_tests():
	var sim = tent(2)
	var old_ids: Array = sim.state.encounter.leaders.map(func(b):return b.id)
	defeat_leaders(sim)
	var party: Array = sim.state.fighters.filter(func(f):return f.team == 0)
	var before: Array = party.map(func(f):return [f.id,f.x,f.y,f.hp,f.rage,f.weapon_uid])
	var troops: Array = sim.state.fighters.filter(func(f):return f.team == 1 and f.hp > 0).map(func(f):return f.id)
	for tick in range(89): sim.step([{"dx":1,"dy":1,"buttons":Battle.SPECIAL}])
	check(sim.state.encounter.phase == "awaiting_yoshimoto" and sim.state.encounter.yoshimoto_id == 0,"introduction respects configured delay")
	check(party.map(func(f):return [f.id,f.x,f.y,f.hp,f.rage,f.weapon_uid]) == before,"safe introduction preserves players and ignores combat inputs")
	sim.step([])
	check(sim.state.encounter.phase == "yoshimoto" and yoshi(sim).id not in old_ids,"independent Yoshimoto spawns after both leaders")
	check(troops.all(func(id):return not sim._fighter(id).is_empty()),"existing ordinary soldiers retained across handoff")
	check(Wire.valid_snapshot(sim.get_state()),"handoff snapshot validates")
	var restart_id: int = yoshi(sim).id
	sim._start_checkpoint(0)
	check(sim.state.encounter.yoshimoto_id == 0 and sim.state.encounter.leaders.all(func(b):return not b.defeated) and sim._fighter(restart_id).is_empty(),"restart discards final boss and all phase state")

func ranged_tests():
	var sim = fresh()
	var f: Dictionary = yoshi(sim)
	var p: Dictionary = sim.state.fighters[0]
	f.cooldown = 1000
	for distance in [460,500,559,400]:
		p.x = f.x-distance
		Yoshi.steer(sim,f,p)
		check(f.combat_mode == "melee","middle band does not flip melee mode")
	p.x = f.x-600
	Yoshi.steer(sim,f,p)
	check(f.combat_mode == "ranged","far threshold enters ranged mode")
	for distance in [550,500,420]:
		p.x = f.x-distance
		Yoshi.steer(sim,f,p)
		check(f.combat_mode == "ranged","hysteresis holds ranged mode inside middle band")
	p.x = f.x-370
	Yoshi.steer(sim,f,p)
	check(f.combat_mode == "melee","near threshold returns to melee")
	p.x = 650
	f.x = 1500
	f.cooldown = 0
	Yoshi.steer(sim,f,p)
	check(f.action == "boss_arrow" and f.ranged_cycle == 1,"first far action commits a bow arrow")
	var ready: int = f.ranged_ready_tick
	var aim: float = f.aim_dx
	p.x = 1800
	for tick in range(50):
		sim.state.tick += 1
		sim._tick_fighter(f)
		Yoshi.steer(sim,f,p)
	check(f.action == "boss_arrow" and f.face == -1 and f.aim_dx == aim,"crossing distance and side cannot cancel or turn committed shot")
	var arrows: Array = sim.state.effects.filter(func(e):return e.get("yoshimoto_projectile",false))
	check(arrows.size() == 1 and arrows[0].weapon == "arrow" and not arrows[0].get("arcing",false) and not arrows[0].boss_wave,"one straight locked arrow, no matchlock or reacquisition")
	check(sim.state.events.any(func(e):return e.type == "bow_release") and not sim.state.events.any(func(e):return e.type == "gunshot"),"bow string release uses bow event")
	ready = f.ranged_ready_tick
	check(ready >= sim.state.tick - 8 + int(sim.state.encounter.yoshi_spec.ranged_cooldown),"cooldown remains reserved from actual projectile release")
	var arrow: Dictionary = arrows[0]
	var x: float = arrow.x
	sim._tick_effects()
	check(arrow.x < x and arrow.vx < 0,"arrow flight keeps original direction")
	check(Wire.valid_snapshot(sim.get_state()),"arrow state validates")
	f.action = "idle"
	f.action_tick = 0
	f.cooldown = 0
	f.x = 1500
	p.x = 650
	sim.state.tick = ready - 1
	Yoshi.steer(sim,f,p)
	check(f.action == "idle" and f.ranged_cycle == 1,"shared ranged cooldown forbids early second move")
	sim.state.tick = ready
	f.cooldown = 0
	Yoshi.steer(sim,f,p)
	check(f.action == "boss_sword_wave" and f.ranged_cycle == 2,"next eligible ranged move is sword wave")
	for tick in range(50):
		sim.state.tick += 1
		sim._tick_fighter(f)
	var waves: Array = sim.state.effects.filter(func(e):return e.get("boss_wave",false))
	check(waves.size() == 1 and waves[0].weapon == "blade" and waves[0].piercing and waves[0].hit_depth > arrow.hit_depth and absf(waves[0].vx) < absf(arrow.vx),"wave has distinct width, speed and piercing collision")
	check(Wire.valid_snapshot(sim.get_state()),"sword-wave state validates")

func guard_and_tactics_tests():
	for attack in ["front","rear","heavy","recovery"]:
		var sim = fresh()
		var f: Dictionary = yoshi(sim)
		var p: Dictionary = sim.state.fighters[0]
		p.x = 1350
		f.ai_cycle = 2
		Yoshi.steer(sim,f,p)
		check(f.action == "guard","proactive frontal guard")
		var hp: int = f.hp
		if attack == "rear": p.x = f.x + 80
		if attack == "recovery":
			for tick in range(int(sim.state.encounter.yoshi_spec.guard_ticks)):
				sim.state.tick += 1
				sim._tick_fighter(f)
			check(f.action == "idle" and f.tactic == "recover","guard has a visible recovery window")
		f.invuln = 0
		var hit: bool = sim._damage(f,20,p.id,attack == "heavy",true,true,false,p.x,p.y,"heavy" if attack == "heavy" else "light")
		check((not hit and f.hp == hp) if attack == "front" else (hit and f.hp < hp),"guard vulnerability " + attack)
	var sim = fresh(2)
	var f: Dictionary = yoshi(sim)
	var party: Array = sim.state.fighters.filter(func(p):return p.team == 0)
	var target: Dictionary = Yoshi.target_for(sim,f,party[0])
	target.action = "down"
	var other: Dictionary = Yoshi.target_for(sim,f,target)
	check(other.id != target.id and Yoshi.can_target(other),"downed target immediately replaced by standing partner")
	var held: int = other.id
	for tick in range(60):
		sim.state.tick += 1
		other.x += 1 if tick % 2 == 0 else -1
		check(Yoshi.target_for(sim,f,target).id == held,"target hold resists small distance oscillation")
	f.x = 81
	f.y = 360
	f.action = "idle"
	f.tactic = "approach"
	f.cooldown = 1000
	f.motion_ready_tick = 0
	other.x = 120
	other.y = 360
	var bounded := true
	for tick in range(200):
		sim.state.tick += 1
		sim._tick_fighter(f)
		Yoshi.steer(sim,f,other)
		if f.tactic in ["sidestep","backstep"]: bounded = bounded and Vector2(f.x-f.motion_origin_x,f.y-f.motion_origin_y).length() <= sim.state.encounter.yoshi_spec.motion_distance + .01
	check(bounded and f.x >= 80 and f.y >= 360 and f.y <= 600 and f.motion_cycle <= 2,"corner tactics have bounded distance, time and cooldown")

func speed_and_loss_tests():
	var sim = fresh()
	var f: Dictionary = yoshi(sim)
	var p: Dictionary = sim.state.fighters[0]
	f.cooldown = 1000
	var before: float = f.x
	Yoshi.steer(sim,f,p)
	var faster: float = before - f.x
	var ordinary: Dictionary = sim._make_fighter(1,"boss",1500,480,260)
	ordinary.cooldown = 1000
	ordinary.boss_variant = "naginata"
	sim._enemy_input(ordinary)
	check(faster > 1500.0 - ordinary.x,"final boss approaches faster than legacy naginata boss")
	p.hp = 0
	p.lives = 0
	p.respawn_ticks = 0
	sim.step([])
	check(sim.state.phase == "lost" and not sim.state.encounter.yoshimoto_defeated,"party defeat alone cannot award victory")

func move_party(sim, x: float):
	for f in sim.state.fighters:
		if f.team == 0:
			f.x = x + f.player_index * 20
			f.z = 0
			f.action = "idle"

func full_route_tests():
	for players in [1,2]:
		var sim = Battle.new()
		sim.reset_campaign("normal",players,["nobunaga","oichi"],3)
		for prop in sim.state.props:
			if prop.kind == "bell_pillar": sim._damage_prop(prop,10000,sim.state.fighters[0].id)
		for f in sim.state.fighters:
			if f.team == 1: kill(sim,f)
		advance(sim,60)
		move_party(sim,2300)
		sim.step([])
		check(sim.state.stage.index == 1,"route alarm to barriers")
		for prop in sim.state.props: sim._damage_prop(prop,10000,sim.state.fighters[0].id)
		advance(sim,60)
		move_party(sim,2500)
		sim.step([])
		check(sim.state.stage.index == 2,"route barriers to formation")
		move_party(sim,2400)
		Encounter.tick(sim)
		advance(sim,60)
		move_party(sim,2900)
		sim.step([])
		check(sim.state.stage.index == 3,"route formation through tent entrance")
		defeat_leaders(sim)
		advance(sim,250)
		check(sim.state.encounter.phase == "yoshimoto" and Wire.valid_snapshot(sim.get_state()),"route dual leaders to final boss")
		var remaining: int = Tent.population(sim.state)
		kill(sim,yoshi(sim))
		for f in sim.state.fighters:
			if f.team == 0:
				f.hp = 0
				f.lives = 0
				f.respawn_ticks = 0
		sim.step([])
		check(sim.state.phase == "won" and sim.state.encounter.tickets.is_empty() and remaining > 0,"final boss death wins despite surviving troops and same-tick party knockout")
		check(Wire.valid_snapshot(sim.get_state()),"final victory snapshot validates")

func wire_and_sync_tests():
	var host = fresh(2)
	var twin = fresh(2)
	var valid := true
	for tick in range(600):
		for sim in [host,twin]:
			for p in sim.state.fighters:
				if p.team == 0: p.invuln = 5
			sim.step([])
		if tick % 3 == 0:
			var remote: Dictionary = bytes_to_var(var_to_bytes(host.get_state()))
			remote.events = []
			valid = valid and Wire.valid_snapshot(remote) and remote.encounter == host.state.encounter and remote.fighters == host.state.fighters
	check(valid and host.get_state() == twin.get_state(),"200 authoritative final-boss snapshot roundtrips match deterministic host")
	var base: Dictionary = host.get_state()
	for field in ["aim_dx","aim_face","combat_mode","ranged_ready_tick","motion_until"]:
		var bad := base.duplicate(true)
		var found: Array = bad.fighters.filter(func(f):return f.get("is_yoshimoto",false))
		found[0][field] = "bad"
		check(not Wire.valid_snapshot(bad),"reject invalid final-boss " + field)
	var bad := base.duplicate(true)
	bad.encounter.yoshimoto_id = bad.encounter.leaders[0].id
	check(not Wire.valid_snapshot(bad),"reject reused leader ID for Yoshimoto")
	check(not Wire.valid_input({"dx":0,"dy":0,"buttons":0,"ranged_ready_tick":0}),"client cannot override boss cooldown")
