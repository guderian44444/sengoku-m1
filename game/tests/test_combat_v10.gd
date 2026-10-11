extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0
var snapshots_valid := true


func _init() -> void:
	_test_enemy_pace_and_arrows()
	_test_guard_and_rage()
	_test_sprint()
	_test_launch_and_water()
	_test_waves_and_props()
	_test_heroes_and_factions()
	_test_intro_and_boundaries()
	_check(snapshots_valid, "all v10 stepped snapshots pass wire validation")
	print("V10 COMBAT TESTS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _arena(hero: String = "nobunaga"):
	var battle = Battle.new()
	battle.reset_training(hero)
	battle.state.props = []
	battle.state.drops = []
	return battle


func _step(battle, count: int = 1, buttons: int = 0, dx: int = 0, dy: int = 0) -> void:
	for tick in range(count):
		battle.step([{"buttons": buttons, "dx": dx, "dy": dy}])
		snapshots_valid = snapshots_valid and Wire.valid_snapshot(battle.get_state())


func _test_enemy_pace_and_arrows() -> void:
	for kind in ["soldier", "flag", "commander", "boss"]:
		var battle = _arena()
		var enemy: Dictionary = battle.state.fighters[1]
		enemy.kind = kind
		enemy.x = 800.0
		enemy.cooldown = 9999
		battle._enemy_input(enemy)
		var expected: float = 3.5 * Battle.HERO_PROFILES[battle.state.fighters[0].kind].move_speed * 0.8 if kind == "boss" else 1.4 * 0.7
		_check(is_equal_approx(800.0 - enemy.x, expected), "Boss pursues at 80% of the target hero's same-direction walk speed" if kind == "boss" else kind + " pursuit moves at 70% previous pace")
	for kind in ["archer", "gunner"]:
		var battle = _arena()
		var enemy: Dictionary = battle.state.fighters[1]
		enemy.kind = kind
		enemy.x = 620.0
		battle._enemy_input(enemy)
		_check(is_equal_approx(enemy.x - 620.0, 2.1), kind + " retreat is also 70% pace")
	var arrow = _arena()
	var bow: Dictionary = arrow.state.fighters[1]
	bow.kind = "archer"
	bow.x = 1000.0
	bow.cooldown = 9999
	arrow._projectile(bow, 10, 0, false, "arrow", 900.0)
	var shot: Dictionary = arrow.state.effects[0]
	var destination := Vector2(shot.target_x, shot.target_y)
	_check(shot.arcing and shot.flight_ticks > 500.0 / 9.0 and destination == Vector2(500, 480), "bow shot locks release-time target and flies slower")
	_step(arrow, shot.flight_ticks / 2)
	_check(shot.z > 140.0 and Vector2(shot.target_x, shot.target_y) == destination, "arrow visibly climbs above its fixed target")
	arrow.state.fighters[0].y += 80.0
	_step(arrow, shot.flight_ticks)
	_check(arrow.state.fighters[0].hp == arrow.state.fighters[0].max_hp, "moving out of locked landing point dodges arrow")
	var gun = _arena()
	var gunner: Dictionary = gun.state.fighters[1]
	gunner.kind = "gunner"
	gun._projectile(gunner, 16, 0, false, "bullet", 1100.0)
	_check(absf(gun.state.effects[0].vx) == 34.0 and not gun.state.effects[0].get("arcing", false), "matchlock keeps fast straight 34px bullet")
	gun._begin(gunner, "gun_shot")
	gunner.action_tick = 89
	gun._tick_fighter(gunner)
	_check(gunner.cooldown == 160 and is_equal_approx(250.0 / 185.0, 1.351351351), "matchlock complete fire cycle is about 35% longer")


func _test_guard_and_rage() -> void:
	var battle = _arena()
	battle.state.training.free_special = false
	var player: Dictionary = battle.state.fighters[0]
	var enemy: Dictionary = battle.state.fighters[1]
	player.rage = 0
	enemy.kind = "soldier"
	enemy.cooldown = 9999
	_step(battle, 1, Battle.SPECIAL)
	_check(player.action == "idle", "special is rejected without full rage")
	_step(battle, 1, Battle.GUARD)
	battle._enemy_melee(enemy, 110.0, 45.0, 10)
	_check(player.hp == player.max_hp and player.rage == 10 and player.action == "guard", "front light strike is blocked and earns rage")
	_check(battle.state.events.any(func(e: Dictionary) -> bool: return e.type == "guard"), "successful guard emits impact event")
	_step(battle, 9, Battle.GUARD)
	enemy.x = 430.0
	enemy.face = 1
	battle._enemy_melee(enemy, 110.0, 45.0, 10)
	_check(player.hp == player.max_hp - 10 and player.rage == 16, "back hit bypasses guard and also earns rage")
	player.invuln = 0
	enemy.x = 585.0
	enemy.face = -1
	enemy.kind = "boss"
	battle._begin(player, "guard")
	battle._enemy_melee(enemy, 150.0, 60.0, 30, "down")
	_check(player.hp == player.max_hp - 40 and player.airborne_lock and battle.state.effects.any(func(e: Dictionary) -> bool: return e.type == "guard_break"), "heavy boss strike breaks guard and launches")
	for drill in ["shield", "enemies", "ranged", "boss"]:
		battle.reset_training("nobunaga", drill)
		_step(battle, 1, Battle.SPECIAL)
		_check(battle.state.fighters[0].rage == 0 and battle.state.fighters[0].action != "special", drill + " training requires earned rage")
	battle.reset_training("nobunaga", "dummy")
	_step(battle, 1, Battle.SPECIAL)
	_check(battle.state.training.free_special and battle.state.fighters[0].action == "special", "dummy explicitly retains free special practice")
	var guarded_arrow = _arena()
	guarded_arrow.state.training.free_special = false
	guarded_arrow.state.fighters[0].rage = 0
	enemy = guarded_arrow.state.fighters[1]
	enemy.kind = "archer"
	enemy.x = 900.0
	enemy.cooldown = 9999
	guarded_arrow._projectile(enemy, 10, 0, false, "arrow")
	_step(guarded_arrow, 100, Battle.GUARD)
	_check(guarded_arrow.state.fighters[0].hp == 120 and guarded_arrow.state.fighters[0].rage == 10, "facing the shooter guards an arcing arrow")


func _test_sprint() -> void:
	var battle = _arena()
	var player: Dictionary = battle.state.fighters[0]
	var enemy: Dictionary = battle.state.fighters[1]
	enemy.x = 545.0
	_step(battle, 1, 0, 1)
	_check(not player.sprinting and is_equal_approx(player.x, 500.0), "single direction press cannot walk through an adjacent enemy")
	_step(battle)
	_step(battle, 1, 0, 1)
	_check(player.sprinting and is_equal_approx(player.x, 507.0), "same direction second tap starts held sprint and shoves the enemy")
	_check(enemy.hp == 994 and enemy.bump_cooldown > 0, "sprint collision lightly damages enemy")
	battle._sprint_bump(player)
	_check(enemy.hp == 994, "same enemy cannot take repeated bump during cooldown")
	_step(battle)
	_check(not player.sprinting, "releasing direction immediately ends sprint")
	battle = _arena()
	_step(battle, 1, 0, 1)
	_step(battle, 16)
	_step(battle, 1, 0, 1)
	_check(not battle.state.fighters[0].sprinting, "slow repeated press outside15ticks does not sprint")
	battle = _arena()
	_step(battle, 1, 0, 0, -1)
	_step(battle)
	_step(battle, 1, 0, 0, -1)
	_check(battle.state.fighters[0].sprinting, "vertical same-direction double tap also sprints")
	_step(battle, 1, 0, 0, 1)
	_check(not battle.state.fighters[0].sprinting, "changing direction ends existing sprint")


func _test_launch_and_water() -> void:
	for team in [1, 0]:
		var battle = _arena()
		var target: Dictionary = battle.state.fighters[team]
		var start_x: float = target.x
		battle._launch(target, 1, 14.0, 6.0)
		var frames := 0
		while target.airborne_lock and frames < 160:
			_step(battle, 1, Battle.LIGHT | Battle.HEAVY | Battle.JUMP)
			frames += 1
			if target.airborne_lock: _check(target.action == "launched", "involuntary flight cannot turn into attack or recovery")
		_check(not target.airborne_lock and target.action == "down" and target.landing_count == (2 if team == 1 else 3), "landing bounces once for enemy and twice for hero")
		_check(target.x - start_x > (330.0 if team == 1 else 210.0) and target.x - start_x < (430.0 if team == 1 else 300.0), "strong enemy launch preserves its impulse while player knockback stays bounded")
		_step(battle, 58)
		_check(target.action == "down", "grounded target lies for full60ticks")
		_step(battle, 1)
		_check(target.action == "recovering", "lying target transitions to visible slow recovery")
		_step(battle, 35)
		_check(target.action == "recovering", "recovery remains locked for36ticks")
		_step(battle, 1)
		_check(target.action == "idle", "control/AI returns after recovery finishes")
	for point in [Vector2(700, 515), Vector2(150, 370)]:
		var battle = _arena()
		var target: Dictionary = battle.state.fighters[1]
		target.x = point.x
		target.y = point.y
		battle._launch(target, 1, 0.0, 2.0)
		var saw_landing := false
		for tick in range(35):
			_step(battle)
			for effect in battle.state.effects:
				if effect.type == "landing":
					saw_landing = true
					_check(effect.wet == battle._wet(point.x, point.y), "splash uses same wet-zone coordinates as ground")
		_check(saw_landing, "actual landing creates water-or-dust effect")


func _test_waves_and_props() -> void:
	for training in [false, true]:
		var battle = Battle.new()
		if training: battle.reset_training("nobunaga", "enemies")
		for wave in range(1, 4):
			var live: Array = battle.state.fighters.filter(func(f: Dictionary) -> bool: return f.team == 1 and f.hp > 0)
			_check(live.size() == (1 if wave == 3 else 4), "wave %d has limited simultaneous opponents" % wave)
			_check(live.filter(func(f: Dictionary) -> bool: return f.kind == "commander").size() == (1 if wave == 2 else 0), "commander appears only with second-wave escort")
			_check(live.filter(func(f: Dictionary) -> bool: return f.kind == "boss").size() == (1 if wave == 3 else 0), "boss fights alone")
			for enemy in live: enemy.hp = 0
			_step(battle, 91 if training else 1)
		_check(battle.state.phase == "won", "normal and training wave sequences can finish")
	var props = _arena()
	props._spawn_props()
	_check(props.state.props.size() == 5, "stall/cart/jar/basket/crate all exist")
	var prop: Dictionary = props.state.props[0]
	prop.x = 585.0
	prop.y = 480.0
	props._melee(props.state.fighters[0], 130.0, 35.0, 200, true)
	_check(prop.broken and props.state.drops.size() == 1 and props.state.effects.any(func(e: Dictionary) -> bool: return e.type == "debris"), "melee breaks prop with debris and loot")
	props._melee(props.state.fighters[0], 130.0, 35.0, 200, true)
	_check(props.state.drops.size() == 1, "broken prop cannot duplicate loot")
	props = _arena("oichi")
	props.state.fighters.resize(1)
	props._spawn_props()
	prop = props.state.props[2]
	prop.x = 635.0
	prop.y = 480.0
	props._projectile(props.state.fighters[0], 50, 0, false, "arrow")
	_step(props, 8)
	_check(prop.broken, "projectiles also break props")
	props = _arena()
	props._spawn_props()
	prop = props.state.props[3]
	prop.x = 650.0
	prop.y = 480.0
	props._wave(props.state.fighters[0], 250.0, 50, "", 20)
	_step(props, 22)
	_check(prop.broken, "ground shockwaves break nearby props")
	var crowd = _arena()
	_step(crowd, 10)
	_check(crowd.state.civilian_spawn_enabled and crowd.state.civilian_flee_tick == -1, "civilians may enter before fighting")
	_step(crowd, 1, Battle.LIGHT)
	_check(not crowd.state.civilian_spawn_enabled and crowd.state.civilian_flee_tick == crowd.state.tick, "first real attack stops new pedestrians and fixes flee epoch")


func _test_heroes_and_factions() -> void:
	_check(Battle.HEROES.size() == 6 and Battle.FACTIONS.size() == 12, "six heroes and twelve approved factions are playable")
	for hero in Battle.HEROES:
		var battle = _arena(hero)
		var target: Dictionary = battle.state.fighters[1]
		target.x = 580.0
		_step(battle, 1, Battle.LIGHT)
		_step(battle, Battle.hero_tick(hero, 6) + 2)
		_check(target.hp < 1000, hero + " has working weapon attack")
		battle = _arena(hero)
		_step(battle, 1, Battle.SPECIAL)
		_step(battle, 209)
		_check(battle.state.fighters[0].action == "special" and battle.state.training.total_damage > 0, hero + " has real multiphase special damage")
		_step(battle, 1)
		_check(battle.state.fighters[0].action == "idle", hero + " returns control after3.5second special")
	_check(Battle.hero_tick("hideyoshi", 14) < Battle.hero_tick("nobunaga", 14) and Battle.hero_tick("tadakatsu", 14) > Battle.hero_tick("nobunaga", 14), "fast short-spear and slow long-spear timings differ")
	var spear = _arena("tadakatsu")
	spear.state.fighters[1].x = 660.0
	_step(spear, 1, Battle.LIGHT)
	_step(spear, 12)
	_check(spear.state.fighters[1].hp < 1000, "Tadakatsu long spear reaches beyond normal first slash")
	var counter = _arena("mitsuhide")
	counter.state.fighters[1].kind = "soldier"
	counter.state.fighters[1].cooldown = 9999
	_step(counter, 1, Battle.GUARD)
	counter._enemy_melee(counter.state.fighters[1], 110.0, 50.0, 10)
	_step(counter, 1, Battle.GUARD | Battle.LIGHT)
	_check(counter.state.fighters[0].action == "counter_cut", "Mitsuhide alone converts a successful guard into quick counter")
	_step(counter, 6)
	_check(counter.state.fighters[1].hp < 1000, "guard-counter connects with actual hitbox")
	var grab = _arena("hideyoshi")
	grab.state.fighters[1].x = 628.0
	_step(grab, 1, Battle.GRAB)
	_check(grab.state.fighters[0].grab_target > 0, "Hideyoshi has larger technical grab reach")
	_step(grab, 1)
	_check(grab.state.fighters[1].hp == 953, "Hideyoshi throw is stronger than basic sword throw")
	for faction in Battle.FACTIONS:
		var battle = Battle.new()
		battle.reset_training("nobunaga", "boss", faction)
		var boss: Dictionary = battle.state.fighters[1]
		_check(boss.boss_variant == Battle.FACTIONS[faction].boss and boss.faction == faction and Wire.valid_snapshot(battle.get_state()), faction + " selects correct approved boss weapon profile")
		for variant in range(3):
			boss.ai_cycle = variant
			boss.cooldown = 0
			boss.x = 580.0
			battle._begin(boss, "idle")
			battle._enemy_input(boss)
			_check(boss.action == Battle.BOSS_PROFILES[boss.boss_variant].actions[variant], faction + " executes its own boss attack " + str(variant))
			var fighting = Battle.new()
			fighting.reset_training("nobunaga", "boss", faction)
			fighting.state.props = []
			var attacker: Dictionary = fighting.state.fighters[1]
			attacker.x = 580.0
			attacker.cooldown = 9999
			fighting._begin(attacker, boss.action)
			_step(fighting, Battle.enemy_timing(attacker)[0] + 33)
			_check(fighting.state.fighters[0].hp < fighting.state.fighters[0].max_hp, faction + " boss attack causes actual player damage " + str(variant))


func _test_intro_and_boundaries() -> void:
	var battle = Battle.new()
	battle.boss_intros = {"mori": {"name": "清水宗治", "line_key": "boss_mori_intro", "ticks": 30}}
	battle.reset_training("nobunaga", "boss")
	var boss: Dictionary = battle.state.fighters[1]
	var start_x: float = boss.x
	var player_start: float = battle.state.fighters[0].x
	_step(battle, 1, 0, -1)
	var introductions: Array = battle.state.events.filter(func(e): return e.type == "boss_intro")
	_check(introductions.size() == 1 and introductions[0].actor_faction == "mori", "boss intro emits one faction-specific voice event alongside combat events")
	_step(battle, 1, Battle.LIGHT)
	_check(not battle.state.intro.get("blocking",true) and battle.state.tick == 2 and battle.state.fighters[0].action == "light", "boss name and dialogue leave attack input and simulation active")
	_step(battle, 28, 0, -1)
	_check(battle.state.tick == 30 and boss.x < start_x and battle.state.fighters[0].x < player_start and battle.state.intro.remaining_ticks == 0, "intro countdown runs alongside enemy pursuit and player movement")
	_step(battle)
	_check(battle.state.tick == 31, "dialogue completion does not pause or reset world time")
	_check(Wire.valid_input({"dx": 0, "dy": 0, "buttons": Battle.GUARD}) and not Wire.valid_input({"dx": 0, "dy": 0, "buttons": 256}), "wire accepts guardbit and rejects unknown higher bits")
	var snapshot: Dictionary = Battle.new().get_state()
	for pair in [["sprinting", 1], ["airborne_lock", "yes"], ["bounces_left", 3], ["tap_tick", -1001], ["move_dx", 2], ["faction", "unknown"], ["boss_variant", "unknown"]]:
		var invalid := snapshot.duplicate(true)
		invalid.fighters[0][pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(invalid), "wire rejects malformed v10 fighter " + str(pair[0]))
	var invalid := snapshot.duplicate(true)
	invalid.props[0].broken = true
	_check(not Wire.valid_snapshot(invalid), "wire rejects broken prop with remaining hp")
	invalid = snapshot.duplicate(true)
	invalid.wet_zones[0].width = INF
	_check(not Wire.valid_snapshot(invalid), "wire rejects nonfinite wet-zone dimensions")
	var one = Battle.new()
	var two = Battle.new()
	one.reset_training("tadakatsu", "enemies", "miyoshi")
	two.reset_training("tadakatsu", "enemies", "miyoshi")
	for tick in range(1000):
		var input := [{"dx": 1 if tick % 35 != 1 else 0, "dy": 0, "buttons": Battle.GUARD if tick % 100 < 30 else (Battle.LIGHT if tick % 20 == 0 else 0)}]
		one.step(input)
		two.step(input)
		snapshots_valid = snapshots_valid and Wire.valid_snapshot(one.get_state())
	_check(one.get_state() == two.get_state(), "v10 physics, sprint, guards, arrows and factions replay deterministically")
