extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0
var snapshots_valid := true


func _init() -> void:
	_test_dash_heavy()
	_test_ordinary_heavy()
	_test_charged_burst()
	_test_burst_defenses()
	_test_charged_waves()
	_test_three_arrows()
	_test_light_finisher()
	_test_replay()
	_check(snapshots_valid, "all v13 real input snapshots validate")
	print("V13 COMBAT TESTS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
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


func _target(battle, x: float, y: float = 480.0) -> Dictionary:
	var target: Dictionary = battle._make_fighter(1, "dummy", x, y, 1000)
	target.home_x = x
	target.home_y = y
	battle.state.fighters.append(target)
	return target


func _step(battle, ticks: int = 1, buttons: int = 0, dx: int = 0, dy: int = 0) -> void:
	for tick in range(ticks):
		battle.step([{"buttons": buttons, "dx": dx, "dy": dy}])
		snapshots_valid = snapshots_valid and Wire.valid_snapshot(battle.get_state())


func _charge(battle, direction: int = 0) -> void:
	_step(battle, 40, Battle.HEAVY, 0, direction)
	_step(battle)


func _test_dash_heavy() -> void:
	for hero in Battle.HEROES:
		for face in [-1, 1]:
			var battle = _arena(hero, face)
			var player: Dictionary = battle.state.fighters[0]
			_step(battle, 1, 0, face)
			_step(battle)
			_step(battle, 1, 0, face)
			_check(player.sprinting, hero + " double tap starts a real sprint")
			var impact_x: float = player.x + face * 6.0 * Battle.hero_tick(hero, 9)
			var front := _target(battle, impact_x + face * 100.0)
			var flank := _target(battle, impact_x + face * 95.0, 525.0)
			var outside_arc := _target(battle, impact_x + face * 20.0, 530.0)
			var rear := _target(battle, impact_x - face * 60.0)
			_step(battle, 1, Battle.HEAVY, face)
			_check(player.action == "dash_heavy" and player.action_tick == 0 and player.charge == 0, hero + " sprint heavy begins immediately without charge")
			_check(battle.state.events.any(func(e: Dictionary) -> bool: return e.type == "swing" and e.action == "dash_heavy"), "dash heavy emits the new swing action")
			_step(battle, Battle.hero_tick(hero, 12) - 1, Battle.HEAVY, face)
			_check(front.hp == 1000 and flank.hp == 1000 and rear.hp == 1000, hero + " dash hit waits for its canonical impact")
			_step(battle, 1, Battle.HEAVY, face)
			_check(front.hp < 1000 and front.airborne_lock and front.knockback * face > 12.0, hero + " dash heavy knocks front troops away")
			_check((flank.hp == 1000) if hero in ["hideyoshi", "tadakatsu"] else (flank.hp < 1000), hero + " spear thrust is narrow while sword and bow sweeps cover a fan")
			_check(outside_arc.hp == 1000 and rear.hp == 1000, hero + " dash excludes rear and outside-angle targets")
			if hero == "oichi":
				var needles: Array = battle.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "projectile")
				_check(needles.size() == 5 and needles[0].vy < needles[1].vy and needles[1].vy < needles[2].vy and needles[2].vy < needles[3].vy and needles[3].vy < needles[4].vy, "Oichi dash releases five distinct fan trajectories")
			_step(battle, Battle.hero_tick(hero, 34) - Battle.hero_tick(hero, 12), Battle.HEAVY, face)
			_check(player.action == "idle", hero + " dash recovers at tick 34 without repeating held heavy")
			_step(battle, 8, Battle.HEAVY, face)
			_check(player.action == "idle", hero + " held heavy does not invent a second dash attack")


func _test_ordinary_heavy() -> void:
	for hero in Battle.HEROES:
		var battle = _arena(hero)
		var player: Dictionary = battle.state.fighters[0]
		_step(battle, 1, Battle.HEAVY, 1)
		_check(player.action == "charge", hero + " first direction press plus heavy retains ordinary charging")
		_step(battle)
		_check(player.action == "heavy" and player.heavy_combo == 1, hero + " ordinary tap remains first heavy")
		_step(battle, 1, Battle.HEAVY)
		_step(battle)
		_step(battle, Battle.hero_tick(hero, 36) - 2)
		_check(player.action == "heavy" and player.heavy_combo == 2, hero + " buffered second heavy remains intact")
	var air = _arena()
	_step(air, 1, Battle.JUMP)
	_step(air, 1, Battle.HEAVY, 1)
	_check(air.state.fighters[0].action == "air_heavy", "air heavy cannot be mistaken for a sprint attack")


func _test_charged_burst() -> void:
	for face in [-1, 1]:
		var battle = _arena("oichi", face)
		var player: Dictionary = battle.state.fighters[0]
		var first := _target(battle, player.x + face * 150.0)
		var splash := _target(battle, player.x + face * 205.0, 500.0)
		var far := _target(battle, player.x + face * 300.0)
		var immune := _target(battle, player.x + face * 200.0, 460.0)
		immune.invuln = 200
		_charge(battle)
		_step(battle, 14)
		var arrows: Array = battle.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "projectile")
		_check(arrows.size() == 1 and not arrows[0].piercing and arrows[0].burst_radius == 100.0, "neutral charge releases one finite explosive arrow at tick 14")
		_step(battle)
		_check(first.hp == 957 and first.freeze > 0 and first.airborne_lock, "burst arrow primary target receives one 43-damage heavy hit")
		_check(splash.hp == 994 and splash.freeze > 0 and not splash.airborne_lock, "nearby splash receives only six damage and freeze")
		_check(far.hp == 1000 and immune.hp == 1000 and immune.freeze == 0, "burst excludes distant and invulnerable targets")
		_check(battle.state.effects.filter(func(e: Dictionary) -> bool: return e.get("burst", false)).size() == 1 and battle.state.effects.all(func(e: Dictionary) -> bool: return e.type != "projectile"), "first contact consumes arrow and creates exactly one burst")
		_step(battle, 16)
		_check(first.hp == 957 and splash.hp == 994 and far.hp == 1000, "burst is not repeated and no primary arrow pierces onward")


func _test_burst_defenses() -> void:
	var battle = _arena("oichi")
	var player: Dictionary = battle.state.fighters[0]
	var shield := _target(battle, player.x + 145.0)
	var holder: Dictionary = battle._make_fighter(0, "nobunaga", player.x + 200.0, 480.0, 1000)
	holder.player_index = 1
	holder.face = -1
	holder.grab_target = shield.id
	holder.action = "holding"
	shield.held_by = holder.id
	shield.action = "grabbed"
	battle.state.fighters.append(holder)
	var boss := _target(battle, player.x + 185.0, 500.0)
	boss.kind = "boss"
	boss.weight = "heavy"
	player.action = "charged"
	battle._projectile(player, 43, 0, true, "arrow", 1450.0, 0.0, "ice", true, {"piercing": true, "burst_radius": 100.0, "burst_damage": 6})
	battle._tick_effects()
	_check(holder.hp == 1000 and holder.freeze == 0 and shield.hp == 957, "held shield absorbs the primary explosion without damaging its holder")
	_check(boss.hp == 994 and boss.freeze > 0 and not boss.airborne_lock, "splash damages and freezes a boss without launching it")
	_check(battle.state.effects.all(func(e: Dictionary) -> bool: return e.type != "projectile"), "burst consumption overrides even an accidentally piercing projectile")
	_check(Wire.valid_snapshot(battle.get_state()), "burst with held shield retains valid network links")
	var hostile = _arena("oichi")
	var shooter: Dictionary = hostile.state.fighters[0]
	shooter.team = 1
	shooter.player_index = -1
	var body := _target(hostile, shooter.x + 145.0)
	var defender: Dictionary = hostile._make_fighter(0, "nobunaga", shooter.x + 200.0, 480.0, 1000)
	defender.player_index = 0
	defender.face = -1
	defender.action = "holding"
	defender.grab_target = body.id
	body.held_by = defender.id
	body.action = "grabbed"
	hostile.state.fighters.append(defender)
	shooter.action = "charged"
	# A hostile explosive projectile exercises the real front-shield routing and splash protection.
	hostile._projectile(shooter, 43, 0, true, "special_arrow", 1450.0, 0.0, "ice", true, {"piercing": false, "burst_radius": 100.0, "burst_damage": 6})
	for tick in range(10): hostile._tick_effects()
	_check(body.hp == 957 and body.freeze > 0 and defender.hp == 1000 and defender.freeze == 0, "hostile splash routes through the already-hit front shield instead of bypassing it")


func _test_charged_waves() -> void:
	for hero in ["nobunaga", "oichi"]:
		for face in [-1, 1]:
			var battle = _arena(hero, face)
			var player: Dictionary = battle.state.fighters[0]
			var front := _target(battle, player.x + face * 100.0)
			var rear := _target(battle, player.x - face * 100.0)
			var inside := _target(battle, player.x + face * 100.0, 510.0)
			var outside := _target(battle, player.x + face * 20.0, 540.0)
			var far := _target(battle, player.x + face * 321.0)
			_charge(battle, 1)
			_step(battle, 28)
			var waves: Array = battle.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "shockwave")
			_check(waves.size() == 1 and waves[0].x == player.x and waves[0].y == player.y and waves[0].radius == 320.0, hero + " powered wave begins at the body with reduced radius 320")
			var wave: Dictionary = waves[0]
			_check(wave.arc_degrees == (120.0 if hero == "oichi" else 360.0) and wave.knockdown == (hero == "nobunaga"), hero + " wave describes its actual cone and knockdown behavior")
			# v14 arrows now release with the wave; isolate this test's wave-only damage.
			battle.state.effects = battle.state.effects.filter(func(e: Dictionary) -> bool: return e.type != "projectile")
			_step(battle, 18)
			if hero == "oichi":
				_check(front.hp == 994 and front.freeze > 0 and not front.airborne_lock and inside.hp == 994, "ice wave gives only six damage and holds front targets upright for arrows")
				_check(rear.hp == 1000 and outside.hp == 1000, "ice wave cannot hit behind or outside its 120-degree sector")
			else:
				_check(front.hp == 935 and rear.hp == 935 and front.burn > 0 and rear.burn > 0 and front.airborne_lock and rear.airborne_lock, "Nobunaga flame wave knocks down and burns on both sides")
			# Complete only this wave to isolate its boundary from subsequent arrows and movement.
			wave.life = 0
			battle._tick_shockwave(wave)
			_check(far.hp == 1000 and (outside.hp == 1000 if hero == "oichi" else outside.hp == 935), hero + " final radius and sector remain exact")
	var ordinary = _arena()
	ordinary._wave(ordinary.state.fighters[0], 240.0, 32, "", 24)
	_check(ordinary.state.effects[0].x == 1155.0 and ordinary.state.effects[0].radius == 240.0 and ordinary.state.effects[0].knockdown, "ordinary shockwave retains its old forward center and knockdown")


func _test_three_arrows() -> void:
	for face in [-1, 1]:
		var battle = _arena("oichi", face)
		var player: Dictionary = battle.state.fighters[0]
		_charge(battle, 1)
		_step(battle, 28)
		battle.state.effects = battle.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "projectile")
		_check(battle.state.effects.size() == 3 and battle.state.effects.all(func(e: Dictionary) -> bool: return e.damage == 10 and not e.piercing and e.follow_freeze), "charged slam releases three low-damage nonpiercing arrows exactly at tick 28")
		_check(battle.state.effects.all(func(e: Dictionary) -> bool: return e.x == player.x + face * 105.0 and e.y == player.y and e.vx * face > 0.0), "all three arrows share the bow origin and fly in the attack direction")
		if battle.state.effects.size() == 3:
			for index in range(3):
				var arrow: Dictionary = battle.state.effects[index]
				var expected_angle := deg_to_rad([-32.0, 0.0, 32.0][index])
				_check(is_equal_approx(arrow.vx, face * 22.0 * cos(expected_angle)) and is_equal_approx(arrow.vy, 22.0 * sin(expected_angle) * 0.4), "three arrows follow distinct -32/0/32 degree flight paths")
		var first_targets: Array = []
		var back_targets: Array = []
		for lane in [-1.0, 0.0, 1.0]:
			var target := _target(battle, player.x + face * 280.0, player.y + lane * 45.0)
			target.freeze = 90
			target.freeze_owner = player.id
			target.invuln = 14
			target.hp = 994
			first_targets.append(target)
			back_targets.append(_target(battle, player.x + face * 390.0, player.y + lane * 71.0))
		_step(battle, 10)
		_check(first_targets.all(func(f: Dictionary) -> bool: return f.hp == 984 and f.freeze == 0 and f.airborne_lock), "own ice-wave invulnerability permits the three fan arrows to break ice and knock down separate troops for exactly ten damage")
		_step(battle, 20)
		_check(back_targets.all(func(f: Dictionary) -> bool: return f.hp == 1000), "each charged-slam arrow stops after at most one victim")
	for scenario in ["other_owner", "ordinary_arrow", "immune_unfrozen"]:
		var protected_battle = _arena("oichi")
		var archer: Dictionary = protected_battle.state.fighters[0]
		var target := _target(protected_battle, archer.x + 150.0)
		target.freeze = 0 if scenario == "immune_unfrozen" else 90
		target.freeze_owner = archer.id + 99 if scenario == "other_owner" else archer.id
		target.invuln = 14
		archer.action = "heavy" if scenario == "ordinary_arrow" else "charged_slam"
		protected_battle._projectile(archer, 10, 0, true, "arrow", 1200.0, 0.0, "", true, {"follow_freeze": true, "shatter_damage": 0})
		protected_battle._tick_effects()
		_check(target.hp == 1000 and not target.airborne_lock, scenario + " retains invulnerability without the own-wave followup exception")


func _test_light_finisher() -> void:
	for face in [-1, 1]:
		var battle = _arena("nobunaga", face)
		var player: Dictionary = battle.state.fighters[0]
		var close := _target(battle, player.x + face * 150.0)
		var air_reach := _target(battle, player.x + face * (42.0 + 240.0))
		var outside := _target(battle, player.x + face * (42.0 + 280.0))
		for tick in range(46): _step(battle, 1, Battle.LIGHT if tick in [0, 4, 24] else 0)
		_check(close.hp == 982 and air_reach.hp == 982 and close.airborne_lock and air_reach.airborne_lock, "Nobunaga light-three sword and extended blade air each hit once for eighteen damage")
		_check(outside.hp == 1000 and battle.state.effects.any(func(e: Dictionary) -> bool: return e.type == "blade_wave" and e.get("combo", 0) == 3 and e.radius == 260.0), "short blade air stops at 260 and has its own visual event")


func _test_replay() -> void:
	var host = Battle.new()
	var peer = Battle.new()
	host.reset("normal", 2, ["nobunaga", "oichi"])
	peer.reset("normal", 2, ["nobunaga", "oichi"])
	for tick in range(160):
		var phase: int = tick % 80
		var dx := 1 if phase in [0, 2, 3] else 0
		var buttons := Battle.HEAVY if phase == 3 or phase >= 38 and phase <= 74 else 0
		var inputs := [{"dx":dx,"dy":0,"buttons":buttons},{"dx":dx,"dy":1 if phase >= 38 and phase <= 74 else 0,"buttons":buttons}]
		host.step(inputs)
		peer.step(inputs)
		snapshots_valid = snapshots_valid and Wire.valid_snapshot(host.get_state())
	_check(host.get_state() == peer.get_state(), "two-player v13 input replay remains deterministic")
