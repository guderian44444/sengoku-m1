extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0
var snapshots_valid := true


func _init() -> void:
	_test_synchronized_ice()
	_test_single_upper_arrow()
	_test_light_step()
	_test_grab_eligibility()
	_test_escape()
	_test_mori_attacks()
	_test_chain_throw_cleanup()
	_check(snapshots_valid, "all v14 simulation snapshots validate")
	print("V14 COMBAT TESTS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _arena(hero: String = "nobunaga", face: int = 1):
	var battle = Battle.new()
	battle.reset_training(hero)
	battle.state.props = []
	battle.state.drops = []
	battle.state.fighters.resize(1)
	battle.state.fighters[0].x = 1100.0
	battle.state.fighters[0].face = face
	return battle


func _target(battle, x: float, y: float = 480.0, kind: String = "dummy") -> Dictionary:
	var target: Dictionary = battle._make_fighter(1, kind, x, y, 1000)
	target.home_x = x
	target.home_y = y
	target.cooldown = 10000
	battle.state.fighters.append(target)
	return target


func _step(battle, ticks: int = 1, buttons: int = 0, dx: int = 0, dy: int = 0) -> void:
	for tick in range(ticks):
		battle.step([{"buttons":buttons,"dx":dx,"dy":dy}])
		snapshots_valid = snapshots_valid and Wire.valid_snapshot(battle.get_state())


func _test_synchronized_ice() -> void:
	for face in [-1,1]:
		var battle = _arena("oichi",face)
		_step(battle,40,Battle.HEAVY,0,1)
		_step(battle)
		var player: Dictionary = battle.state.fighters[0]
		_check(player.action == "charged_slam", "downward held heavy starts the real ice field")
		_step(battle,27)
		_check(battle.state.effects.is_empty(), "neither arrows nor ice wave release before tick28")
		_step(battle)
		var arrows: Array = battle.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "projectile")
		var waves: Array = battle.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "shockwave")
		_check(arrows.size() == 3 and waves.size() == 1, "one ice wave and three arrows are born together at tick28")
		_check(arrows.all(func(e: Dictionary) -> bool: return e.action_tick == 28 and e.life == e.max_life and e.damage == 10 and not e.piercing), "simultaneous arrows remain low-damage and nonpiercing")
		_check(waves[0].life == waves[0].max_life and waves[0].arc_degrees == 120.0 and waves[0].damage == 6 and not waves[0].knockdown, "simultaneous wave keeps the forward low-damage freezing sector")
		var births := arrows.size()
		for tick in range(44):
			_step(battle)
			births += battle.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "projectile" and e.life == e.max_life).size()
		_check(births == 3 and player.action == "idle", "the skill emits only one volley and still ends at tick72")


func _test_single_upper_arrow() -> void:
	for face in [-1,1]:
		for powered in [false,true]:
			var battle = _arena("oichi",face)
			var player: Dictionary = battle.state.fighters[0]
			_step(battle,40 if powered else 1,Battle.HEAVY,0,-1)
			_step(battle)
			var action := "charged_upper" if powered else "upper_heavy"
			var impact := 22 if powered else 12
			_check(player.action == action, "real upward heavy input selects " + action)
			_step(battle,impact - 1)
			_check(not battle.state.effects.any(func(e: Dictionary) -> bool: return e.type == "projectile"), action + " waits for its canonical release")
			_step(battle)
			var arrows: Array = battle.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "projectile")
			_check(arrows.size() == 1 and arrows[0].element == "ice" and not arrows[0].piercing and not arrows[0].has("burst_radius"), action + " releases exactly one nonpiercing ice arrow without a burst")
			var first := _target(battle,player.x + face * 150.0)
			var behind := _target(battle,player.x + face * 230.0)
			var beside := _target(battle,player.x + face * 160.0,510.0)
			_step(battle,10)
			_check(first.hp == (958 if powered else 975) and first.freeze > 0, action + " freezes its only hit target with the intended charge-dependent damage")
			_check(behind.hp == 1000 and behind.freeze == 0 and beside.hp == 1000 and beside.freeze == 0, action + " cannot pierce or freeze nearby troops")


func _test_light_step() -> void:
	for hero in Battle.HEROES:
		for face in [-1,1]:
			var battle = _arena(hero,face)
			var player: Dictionary = battle.state.fighters[0]
			var origin: float = player.x
			_step(battle,1,Battle.LIGHT)
			_step(battle)
			_step(battle,1,Battle.LIGHT)
			while player.combo != 2: _step(battle)
			_check(is_equal_approx(player.x,origin), hero + " first two cuts do not inherit the finishing step")
			_step(battle)
			_step(battle,1,Battle.LIGHT,-face,1)
			while player.combo != 3: _step(battle,1,0,-face,-1)
			_check(player.action == "light" and player.face == face and is_equal_approx(player.y,480.0), hero + " third-cut input cannot insert a directional technique or turn")
			_step(battle,Battle.hero_tick(hero,6),0,-face,1)
			_check(is_equal_approx(player.x,origin + face * 42.0) and player.face == face and is_equal_approx(player.y,480.0), hero + " third cut advances exactly42 pixels in its original facing before impact")
			_step(battle,Battle.hero_tick(hero,19) - Battle.hero_tick(hero,6) - 1)
			_check(is_equal_approx(player.x,origin + face * 42.0), hero + " finishing step does not continue during recovery")
	var edge = _arena()
	var fighter: Dictionary = edge.state.fighters[0]
	fighter.x = 2290.0
	fighter.combo = 3
	fighter.combo_tick = 42
	edge._begin(fighter,"light")
	_step(edge,6)
	_check(fighter.x == 2300.0, "third-cut step respects the arena boundary")
	var directional = _arena("oichi")
	var archer: Dictionary = directional.state.fighters[0]
	_step(directional,1,Battle.LIGHT)
	_step(directional)
	_step(directional,1,Battle.LIGHT)
	while archer.combo != 2: _step(directional)
	_step(directional,1,Battle.HEAVY,0,-1)
	while archer.action == "light": _step(directional,1,Battle.HEAVY,0,-1)
	_step(directional)
	_check(archer.action == "upper_heavy", "third-light direction locking does not steal an explicitly buffered upward heavy")


func _test_grab_eligibility() -> void:
	for action in ["idle","hurt","down","recovering","launched","thrown","pulled"]:
		var battle = _arena()
		var player: Dictionary = battle.state.fighters[0]
		var victim := _target(battle,player.x + 65.0)
		victim.action = action
		battle._try_grab(player)
		_check((player.grab_target == victim.id) == (action in ["idle","hurt"]), "grab eligibility respects actual posture " + action)
	for airborne in ["z","vz","airborne_lock"]:
		var battle = _arena()
		var player: Dictionary = battle.state.fighters[0]
		var victim := _target(battle,player.x + 65.0)
		victim[airborne] = true if airborne == "airborne_lock" else 1.0
		battle._try_grab(player)
		_check(player.grab_target == 0 and victim.held_by == 0, "ground-level animation cannot hide airborne state " + airborne)


func _test_escape() -> void:
	var escaped := 0
	for start_tick in range(100):
		var battle = _arena()
		var replay = _arena()
		var player: Dictionary = battle.state.fighters[0]
		var victim := _target(battle,player.x + 65.0)
		_target(replay,player.x + 65.0)
		battle.state.tick = start_tick
		replay.state.tick = start_tick
		for sim in [battle,replay]:
			_step(sim,1,Battle.GRAB)
			_step(sim,29,Battle.GRAB)
		_check(player.action == "holding" and victim.held_by == player.id, "no escape roll before the thirtieth hold tick")
		_step(battle,1,Battle.GRAB)
		_step(replay,1,Battle.GRAB)
		_check(battle.get_state() == replay.get_state(), "escape outcome remains deterministic across matching peers")
		if player.grab_target == 0:
			escaped += 1
			_check(player.action == "idle" and victim.action == "idle" and victim.held_by == 0 and victim.throw_ticks == 0 and victim.thrown_by == 0, "escape clears both links without a throw or knockdown")
			_step(battle,2,Battle.GRAB)
			_check(player.grab_target == 0, "a held grab button does not automatically recapture an escaped troop")
		else:
			battle._damage(victim,1,999,false,true,true)
			_step(battle,149,Battle.GRAB)
			_check(player.action == "holding" and player.action_tick == 179 and victim.held_by == player.id, "surviving the only escape roll preserves the full hold even after shield pain")
			_step(battle,1,Battle.GRAB)
			_check(player.grab_target == 0 and victim.held_by == 0 and victim.throw_ticks == 0, "surviving holds still drop safely at the original180-tick timeout")
	_check(escaped == 50, "exactly50 of100 uniformly spaced capture ticks escape at0.5 seconds")


func _boss_arena(distance: float = 100.0):
	var battle = _arena()
	var player: Dictionary = battle.state.fighters[0]
	var boss := _target(battle,player.x + distance,480.0,"boss")
	boss.face = -1
	boss.cooldown = 0
	return battle


func _test_mori_attacks() -> void:
	var actions: Array = Battle.BOSS_PROFILES.kusarigama.actions
	_check(actions.size() == 4 and actions.has("boss_grab_throw"), "Mori has four distinct actual attacks")
	for index in range(4):
		var battle = _boss_arena()
		var boss: Dictionary = battle.state.fighters[1]
		boss.ai_cycle = index
		battle._enemy_input(boss)
		_check(boss.action == actions[index] and boss.attack_variant == index and Wire.valid_snapshot(battle.get_state()), "the live Mori AI can select and synchronize attack" + str(index))
	for spec in [["boss_smash",100.0,0.0],["boss_chain",350.0,0.0],["boss_sweep",240.0,85.0],["boss_grab_throw",100.0,0.0]]:
		var battle = _boss_arena(spec[1])
		var player: Dictionary = battle.state.fighters[0]
		var boss: Dictionary = battle.state.fighters[1]
		player.y += spec[2]
		battle._begin(boss,spec[0])
		_step(battle,Battle.enemy_timing(boss)[0])
		_check(player.hp < player.max_hp, str(spec[0]) + " actually reaches its intended short/long/wide/grab target")
		if spec[0] == "boss_grab_throw":
			_check(player.action == "pulled" and player.pull_owner == boss.id and boss.chain_target == player.id, "close chain grab establishes both restraint links at26")
			_step(battle,28)
			_check(player.action == "thrown" and player.airborne_lock and player.knockback < 0.0 and player.thrown_by == boss.id and player.throw_ticks > 0, "Mori follows the pull with an actual airborne throw at54")
			_check(player.pull_owner == 0 and boss.chain_target == 0, "chain throw clears both pull links before flight")
		elif spec[0] == "boss_chain":
			_step(battle,28)
			_check(player.action == "stunned" and player.stun > 0, "long chain retains its separate pull-and-sickle stun followup")


func _test_chain_throw_cleanup() -> void:
	for interruption in ["freeze","hurt","defeat"]:
		var battle = _boss_arena()
		var player: Dictionary = battle.state.fighters[0]
		var boss: Dictionary = battle.state.fighters[1]
		battle._begin(boss,"boss_grab_throw")
		_step(battle,26)
		boss.invuln = 0
		if interruption == "freeze": battle._apply_element(boss,"ice",player.id)
		else: battle._damage(boss,2000 if interruption == "defeat" else 1,player.id,true)
		_check(player.pull_owner == 0 and boss.chain_target == 0 and player.action != "pulled", interruption + " releases both sides of the boss grab")
		_check(Wire.valid_snapshot(battle.get_state()), interruption + " leaves a valid synchronized snapshot")
	var downed = _boss_arena()
	var target: Dictionary = downed.state.fighters[0]
	var boss: Dictionary = downed.state.fighters[1]
	target.action = "down"
	boss.action = "boss_grab_throw"
	downed._cast_chain(boss,160.0)
	_check(boss.chain_target == 0 and target.pull_owner == 0, "Mori's close grab cannot capture a downed player")
