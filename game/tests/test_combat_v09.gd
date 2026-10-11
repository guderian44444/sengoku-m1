extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0
var snapshots_valid := true


func _init() -> void:
	_test_roster()
	_test_melee_roles()
	_test_ranged_ai()
	_test_chain()
	_test_directional_and_combos()
	_test_elements()
	_test_specials()
	_test_replay()
	_check(snapshots_valid, "all v09 scenario snapshots validate for multiplayer")
	print("V09 COMBAT TESTS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _arena(hero: String = "nobunaga"):
	var battle = Battle.new()
	battle.reset_training(hero)
	return battle


func _step(battle, frames: int, buttons: int = 0, dy: int = 0, dx: int = 0) -> void:
	for tick in range(frames):
		battle.step([{"dx": dx, "dy": dy, "buttons": buttons}])
		snapshots_valid = snapshots_valid and Wire.valid_snapshot(battle.get_state())


func _test_roster() -> void:
	var battle = Battle.new()
	battle.reset_training("nobunaga", "enemies")
	var kinds: Array = []
	for fighter in battle.state.fighters:
		if fighter.team == 1: kinds.append(fighter.kind)
	_check(kinds == ["soldier", "soldier", "flag", "gunner"], "Mori practice begins with four regular troops")
	var target: Dictionary = battle.state.fighters[1]
	battle._damage(target, 20, battle.state.fighters[0].id, false)
	_check(battle.state.training.hit_count == 1 and battle.state.training.total_damage == 20, "training counts non-dummy enemy hits")
	target.invuln = 0
	battle._damage(target, 200, battle.state.fighters[0].id, true)
	_check(target.hp == 0, "practice enemies can be defeated")
	_step(battle, 125)
	_check(target.hp == 0, "wave practice defeated enemy stays down until the wave clears")
	battle.reset_training("oichi", "ranged")
	_check(battle.state.fighters.size() == 3 and battle.state.fighters[2].kind == "gunner", "ranged drill contains bow and matchlock")
	battle.reset_training("oichi", "boss")
	_check(battle.state.fighters.size() == 2 and battle.state.fighters[1].kind == "boss", "boss drill is isolated")


func _test_melee_roles() -> void:
	for kind in Battle.ENEMY_ATTACKS:
		var actions: Array = Battle.ENEMY_ATTACKS[kind]
		_check(actions.size() == (4 if kind == "boss" else 3) and actions[0] != actions[1] and actions[1] != actions[2], kind + " retains its distinct attack states, including Mori's fourth grab-throw")
		for action in actions:
			var battle = _arena()
			var player: Dictionary = battle.state.fighters[0]
			var enemy: Dictionary = battle.state.fighters[1]
			enemy.kind = kind
			enemy.x = 580.0
			enemy.face = -1
			enemy.cooldown = 1000
			battle._begin(enemy, action)
			_step(battle, int(Battle.ENEMY_TIMING[action][0]) - 1)
			_check(player.hp == player.max_hp, action + " telegraphs before active frame")
			_step(battle, 1)
			_check(player.hp < player.max_hp, action + " connects on declared hit frame")
			if action in ["boss_smash", "flag_slam", "commander_rise"]:
				_check(player.action == "launched" and player.vz > 0, action + " launches player before landing knockdown")
			elif action in ["boss_sweep", "spear_sweep", "flag_sweep", "commander_dash"]:
				_check(absf(player.knockback) > 0, action + " pushes player away")
			elif action == "spear_butt":
				_check(player.stun > 0, "spear butt stuns")
	var cycling = _arena()
	cycling.state.fighters[1].kind = "flag"
	cycling.state.fighters[1].x = 610.0
	for index in range(3):
		var enemy: Dictionary = cycling.state.fighters[1]
		enemy.cooldown = 0
		cycling._begin(enemy, "idle")
		cycling._enemy_input(enemy)
		_check(enemy.action == Battle.ENEMY_ATTACKS.flag[index] and enemy.attack_variant == index, "AI cycles flag attack " + str(index))


func _test_ranged_ai() -> void:
	for kind in ["archer", "gunner"]:
		var battle = _arena()
		var enemy: Dictionary = battle.state.fighters[1]
		enemy.kind = kind
		enemy.x = 650.0
		enemy.cooldown = 0
		_step(battle, 20)
		_check(enemy.x > 690.0 and enemy.action == "retreat", kind + " retreats when player closes in")
		battle = _arena()
		enemy = battle.state.fighters[1]
		enemy.kind = kind
		enemy.x = 1000.0
		enemy.cooldown = 0
		_step(battle, 1)
		_check(enemy.action == ("bow_shot" if kind == "archer" else "gun_shot"), kind + " attacks from distance")
		_step(battle, 140)
		_check(battle.state.fighters[0].hp < battle.state.fighters[0].max_hp, kind + " ranged shot reaches player")
		battle = _arena()
		battle.state.fighters[0].x = 2170.0
		enemy = battle.state.fighters[1]
		enemy.kind = kind
		enemy.x = 2290.0
		_step(battle, 100)
		_check(enemy.y != 480.0 and enemy.x < 2290.0, kind + " sidesteps and leaves wall instead of retreating in place")


func _test_chain() -> void:
	var battle = _arena()
	var player: Dictionary = battle.state.fighters[0]
	var boss: Dictionary = battle.state.fighters[1]
	boss.kind = "boss"
	boss.x = 820.0
	boss.face = -1
	battle._begin(boss, "boss_chain")
	_step(battle, 26)
	_check(player.action == "pulled" and player.pull_owner == boss.id, "chain attaches to player at range")
	var start: float = player.x
	_step(battle, 20)
	_check(player.x > start + 200.0, "chain physically pulls player toward boss")
	_step(battle, 8)
	_check(player.action == "stunned" and player.stun == 65 and player.pull_owner == 0, "chain follow-up strikes and stuns after pull")
	battle = _arena()
	player = battle.state.fighters[0]
	boss = battle.state.fighters[1]
	boss.kind = "boss"
	boss.x = 820.0
	boss.face = -1
	player.rage = 100
	battle._begin(player, "special")
	battle._cast_chain(boss)
	_check(player.action == "special" and player.pull_owner == 0, "special invulnerability prevents chain capture")
	battle = _arena()
	player = battle.state.fighters[0]
	var shield: Dictionary = battle.state.fighters[1]
	battle._try_grab(player)
	boss = battle._make_fighter(1, "boss", 820.0, 480.0, 400)
	boss.face = -1
	battle.state.fighters.append(boss)
	battle._cast_chain(boss)
	_check(shield.hp < shield.max_hp and player.pull_owner == 0 and player.action == "holding", "held enemy blocks incoming chain")
	battle = _arena()
	player = battle.state.fighters[0]
	boss = battle.state.fighters[1]
	boss.kind = "boss"
	boss.x = 820.0
	boss.face = -1
	battle._begin(boss, "boss_chain")
	_step(battle, 26)
	battle._apply_element(boss, "ice", player.id)
	_step(battle, 1)
	_check(player.pull_owner == 0 and boss.chain_target == 0 and player.action != "pulled", "freezing chain boss releases both ends of restraint")
	battle = _arena()
	player = battle.state.fighters[0]
	boss = battle.state.fighters[1]
	boss.kind = "boss"
	boss.x = 820.0
	boss.face = -1
	battle._begin(boss, "boss_chain")
	_step(battle, 26)
	battle.state.erase("training")
	player.invuln = 0
	battle._damage(player, 9999, boss.id, true)
	_check(player.hp == 0 and player.pull_owner == 0 and boss.chain_target == 0, "defeated pulled player leaves no sticky chain ownership")


func _test_directional_and_combos() -> void:
	for hero in ["nobunaga", "oichi"]:
		for spec in [[Battle.LIGHT, -1, 0, "rising"], [Battle.LIGHT, 1, 0, "low_sweep"], [Battle.LIGHT, 0, 1, "dash_strike"]]:
			var battle = _arena(hero)
			_step(battle, 1, spec[0], spec[1], spec[2])
			_check(battle.state.fighters[0].action == spec[3], hero + " selects " + spec[3])
		for direction in [-1, 0, 1]:
			for charged in [false, true]:
				var battle = _arena(hero)
				_step(battle, 40 if charged else 1, Battle.HEAVY, direction)
				_check(battle.state.fighters[0].x == 500.0 and battle.state.fighters[0].y == 480.0, hero + " charge keeps feet rooted")
				_step(battle, 1)
				var expected: String = (["charged_upper", "charged", "charged_slam"] if charged else ["upper_heavy", "heavy", "ground_slam"])[direction + 1]
				_check(battle.state.fighters[0].action == expected, hero + " directional tap/hold selects " + expected)
		var mixed = _arena(hero)
		_step(mixed, 1, Battle.LIGHT)
		_step(mixed, 2)
		_step(mixed, 1, Battle.HEAVY)
		_step(mixed, 17)
		_check(mixed.state.fighters[0].action == "mixed_finisher", hero + " J to K buffers mixed finisher")
		mixed = _arena(hero)
		_step(mixed, 1, Battle.HEAVY)
		_step(mixed, 1)
		_step(mixed, 1, Battle.LIGHT)
		_step(mixed, 35)
		_check(mixed.state.fighters[0].action == "mixed_rising", hero + " K to J buffers distinct mixed rising")
		for attack in [Battle.LIGHT, Battle.HEAVY]:
			var air = _arena(hero)
			_step(air, 1, Battle.JUMP)
			_step(air, 4)
			_step(air, 1, attack)
			_check(air.state.fighters[0].action == ("air_light" if attack == Battle.LIGHT else "air_heavy"), hero + " has distinct aerial light/heavy")
		var juggle = _arena(hero)
		_step(juggle, 1, Battle.LIGHT, -1)
		_step(juggle, 24)
		_step(juggle, 1, Battle.JUMP)
		_step(juggle, 4)
		_step(juggle, 1, Battle.LIGHT)
		_step(juggle, 12)
		_check(juggle.state.training.chain_hits >= 2 and juggle.state.fighters[0].z > 0, hero + " rising to jump-light is an executable juggle combo")
	var tap = _arena()
	_step(tap, 1, Battle.HEAVY, 1)
	_step(tap, 15)
	var small: Dictionary = tap.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "shockwave")[0]
	var charge = _arena()
	_step(charge, 40, Battle.HEAVY, 1)
	_step(charge, 29)
	var big: Dictionary = charge.state.effects.filter(func(e: Dictionary) -> bool: return e.type == "shockwave")[0]
	_check(big.radius > small.radius and big.damage > small.damage and big.max_life > small.max_life and big.element == "fire", "charged down-heavy has larger range, damage, effect duration and element")


func _test_elements() -> void:
	var battle = _arena()
	var player: Dictionary = battle.state.fighters[0]
	var target: Dictionary = battle.state.fighters[1]
	_step(battle, 40, Battle.HEAVY)
	_step(battle, 15)
	_check(target.burn > 0, "Nobunaga charged blade ignites target")
	var hp: int = target.hp
	_step(battle, 31)
	_check(target.hp < hp and target.burn > 0, "burn deals continuing damage")
	battle = _arena("oichi")
	player = battle.state.fighters[0]
	target = battle.state.fighters[1]
	_step(battle, 40, Battle.HEAVY)
	_step(battle, 16)
	_check(target.freeze > 0 and target.action == "frozen", "Oichi charged arrow freezes target")
	var position := Vector3(target.x, target.y, target.z)
	_step(battle, 15)
	_check(Vector3(target.x, target.y, target.z) == position, "frozen target cannot drift or act")
	hp = target.hp
	target.invuln = 0
	battle._damage(target, 30, player.id, true)
	_check(target.hp == hp - 54 and target.freeze == 0 and battle.state.effects.any(func(e: Dictionary) -> bool: return e.type == "shatter"), "heavy shatters ice with bonus damage and debris event")
	battle._apply_element(target, "ice", player.id)
	_check(target.freeze == 0, "shattering hit cannot immediately refreeze the same target")
	_step(battle, 1)
	battle._apply_element(target, "ice", player.id)
	battle._apply_element(target, "fire", player.id)
	_check(target.freeze == 0 and target.burn > 0, "fire thaws ice and starts burn")
	battle = _arena("oichi")
	target = battle.state.fighters[1]
	target.invuln = 200
	_step(battle, 40, Battle.HEAVY)
	_step(battle, 16)
	_check(target.hp == target.max_hp and target.freeze == 0, "rejected invulnerable hit cannot apply ice")
	battle = _arena()
	player = battle.state.fighters[0]
	battle._apply_element(player, "fire", 2)
	battle._begin(player, "special")
	hp = player.hp
	_step(battle, 35)
	_check(player.hp == hp, "special also blocks burn ticks")
	for element in ["fire", "ice"]:
		battle.reset_training("nobunaga", "enemies")
		player = battle.state.fighters[0]
		target = battle.state.fighters[1]
		target.hp = 1
		battle._damage(target, 10, player.id, true)
		battle._apply_element(target, element, player.id)
		_check(target.hp == 0 and target.burn == 0 and target.freeze == 0 and battle.state.effects.any(func(e: Dictionary) -> bool: return e.type == ("fire_hit" if element == "fire" else "ice_hit")), "lethal " + element + " retains impact without resurrecting status")


func _test_specials() -> void:
	for hero in ["nobunaga", "oichi"]:
		var battle = _arena(hero)
		var player: Dictionary = battle.state.fighters[0]
		var target: Dictionary = battle.state.fighters[1]
		target.x = 680.0
		_step(battle, 1, Battle.SPECIAL)
		var hp: int = player.hp
		var early_shatters := 0
		for tick in range(209):
			battle._damage(player, 100, target.id, true)
			_step(battle, 1)
			if tick < 191:
				early_shatters += battle.state.events.filter(func(e: Dictionary) -> bool: return e.type == "shatter").size()
		_check(player.action == "special" and player.hp == hp, hero + " remains invincible for full 3.5-second special")
		_check(target.hp < 850, hero + " multi-phase special lands repeated damage")
		if hero == "oichi": _check(early_shatters == 0, "ice special freezes during setup and reserves shatter for final volley")
		_step(battle, 1)
		_check(player.action == "idle", hero + " special returns control at tick210")


func _test_replay() -> void:
	var first = Battle.new()
	var second = Battle.new()
	first.reset_training("oichi", "enemies")
	second.reset_training("oichi", "enemies")
	for tick in range(1600):
		var buttons: int = Battle.HEAVY if tick % 150 < 45 else (Battle.LIGHT if tick % 20 == 0 else 0)
		if tick % 250 == 150: buttons = Battle.SPECIAL
		var inputs := [{"dx": 1 if tick % 400 < 260 else -1, "dy": (tick / 150) % 3 - 1, "buttons": buttons}]
		first.step(inputs)
		second.step(inputs)
		snapshots_valid = snapshots_valid and Wire.valid_snapshot(first.get_state())
	_check(first.get_state() == second.get_state(), "enemy tactics, elemental status and expanded combos replay deterministically")
