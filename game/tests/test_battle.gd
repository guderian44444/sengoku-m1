extends SceneTree

const Battle = preload("res://core/battle.gd")
var checks := 0
var failures := 0


func _init() -> void:
	_test_attacks()
	_test_combo()
	_test_needle_origin()
	_test_grab_and_poison()
	_test_pickups_and_difficulty()
	_test_wave_restart_and_copy()
	_test_boss_and_special()
	_test_replay()
	_test_playthrough()
	if failures == 0:
		print("BATTLE TESTS PASSED: %d checks" % checks)
	else:
		push_error("BATTLE TESTS FAILED: %d of %d checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + label)


func _arena(hero: String = "nobunaga"):
	var battle = Battle.new()
	battle.reset("normal", 1, [hero])
	var player: Dictionary = battle.state.fighters[0]
	var enemy: Dictionary = battle.state.fighters[1]
	battle.state.fighters = [player, enemy]
	battle.state.props = []
	player.x = 500.0
	player.y = 460.0
	enemy.x = 560.0
	enemy.y = 460.0
	enemy.hp = 1000
	enemy.max_hp = 1000
	enemy.cooldown = 10000
	return battle


func _advance(battle, count: int, buttons: int = 0) -> void:
	for i in range(count):
		battle.step([{"buttons": buttons}])


func _test_attacks() -> void:
	var light = _arena()
	_advance(light, 1, Battle.LIGHT)
	_advance(light, 7)
	var light_damage: int = 1000 - light.state.fighters[1].hp
	var heavy = _arena()
	_advance(heavy, 1, Battle.HEAVY)
	_advance(heavy, 16)
	var heavy_damage: int = 1000 - heavy.state.fighters[1].hp
	var charged = _arena()
	_advance(charged, 40, Battle.HEAVY)
	_check(charged.state.fighters[1].hp == 1000, "held heavy charges without damaging")
	_advance(charged, 16)
	var charge_damage: int = 1000 - charged.state.fighters[1].hp
	_check(light_damage > 0 and heavy_damage > light_damage, "heavy damages more than light")
	_check(charge_damage > heavy_damage, "charged release damages more than tap heavy")
	var jumping = _arena()
	_advance(jumping, 4, Battle.JUMP)
	_check(jumping.state.fighters[0].z > 0, "jump lifts player")
	_advance(jumping, 45)
	_check(jumping.state.fighters[0].z == 0, "jump lands")


func _test_grab_and_poison() -> void:
	var battle = _arena()
	battle.state.fighters[1].x = 800.0
	_advance(battle, 1, Battle.GRAB)
	_check(battle.state.fighters[1].hp == 1000, "cannot grab a distant enemy")
	_advance(battle, 1)
	battle.state.fighters[1].x = 550.0
	_advance(battle, 1, Battle.GRAB)
	_check(battle.state.fighters[1].hp == 1000 and battle.state.fighters[1].action == "grabbed", "holding grab restrains without prematurely throwing")
	_advance(battle, 1)
	_check(battle.state.fighters[1].hp < 1000 and battle.state.fighters[1].action == "thrown", "releasing a close grab throws")
	var oichi = _arena("oichi")
	oichi.state.fighters[1].x = 680.0
	oichi.state.fighters[1].action = "stunned"
	oichi.state.fighters[1].stun = 300
	oichi.state.fighters[0].rage = 100
	_advance(oichi, 1, Battle.SPECIAL)
	_advance(oichi, 35)
	var enemy: Dictionary = oichi.state.fighters[1]
	_check(enemy.freeze > 0, "Oichi ice special freezes at range")
	var hp: int = enemy.hp
	var frozen_x: float = enemy.x
	_advance(oichi, 31)
	_check(enemy.hp == hp and enemy.x == frozen_x and enemy.freeze > 0, "frozen enemy stays still until the next special wave")
	var poison = _arena("oichi")
	poison._poison(poison.state.fighters[1], 120, poison.state.fighters[0].id)
	_advance(poison, 31)
	_check(poison.state.fighters[1].hp == 997, "existing poison status still ticks independently")


func _test_combo() -> void:
	for hero in ["nobunaga", "oichi"]:
		var stopped = _arena(hero)
		stopped.state.fighters[1].x = 550.0
		for tick in range(40):
			_advance(stopped, 1, Battle.LIGHT if tick in [0, 4] else 0)
		var enemy: Dictionary = stopped.state.fighters[1]
		var hp: int = enemy.hp
		_check(stopped.state.fighters[0].combo == 2 and hp < 1000, hero + " buffers exactly the second strike")
		_check(enemy.z > 0 if hero == "nobunaga" else enemy.x == 550.0 and enemy.z == 0, hero + " second strike has its intended sword-uppercut or planted-needle reaction")
		_advance(stopped, 40)
		_check(enemy.hp == hp and stopped.state.fighters[0].combo == 0, hero + " stopping after two never invents a third hit and expires the chain")
		_advance(stopped, 1, Battle.LIGHT)
		_check(stopped.state.fighters[0].combo == 1, hero + " expired chain restarts at first strike")
		var full = _arena(hero)
		full.state.fighters[1].x = 550.0
		for tick in range(48):
			_advance(full, 1, Battle.LIGHT if tick in [0, 4, 24] else 0)
		_check(full.state.fighters[0].combo == 3, hero + " three presses advance three stages")
		_check(full.state.fighters[1].action == "launched" and full.state.fighters[1].x > 550.0 and full.state.fighters[1].z > 0, hero + " finisher launches enemy into locked airborne reaction")
	var held = _arena()
	_advance(held, 80, Battle.LIGHT)
	_check(held.state.fighters[1].hp == 986, "holding a button is one press, not an automatic combo")
	var interrupted = _arena()
	_advance(interrupted, 1, Battle.LIGHT)
	_advance(interrupted, 1)
	_advance(interrupted, 1, Battle.LIGHT)
	interrupted._damage(interrupted.state.fighters[0], 1, interrupted.state.fighters[1].id, false)
	_advance(interrupted, 30)
	_check(interrupted.state.fighters[0].combo == 0 and interrupted.state.fighters[1].hp == 1000, "being hit cancels buffered combo input")
	var lethal = _arena()
	lethal.state.fighters[1].x = 550.0
	lethal.state.fighters[1].hp = 40
	var victim: Dictionary = lethal.state.fighters[1]
	for tick in range(48):
		_advance(lethal, 1, Battle.LIGHT if tick in [0, 4, 24] else 0)
	_check(victim.hp == 0 and victim.x > 550 and victim.z > 0, "lethal finisher keeps its launch motion")
	lethal = _arena()
	lethal.state.wave = 3
	lethal.state.fighters[1].x = 550.0
	lethal.state.fighters[1].hp = 40
	victim = lethal.state.fighters[1]
	for tick in range(48):
		_advance(lethal, 1, Battle.LIGHT if tick in [0, 4, 24] else 0)
	var won_tick: int = lethal.state.tick
	_check(lethal.state.phase == "won" and victim.z > 0, "final-wave finisher wins while enemy is airborne")
	_advance(lethal, 120, Battle.LIGHT | Battle.SPECIAL)
	_check(victim.z == 0 and absf(victim.knockback) <= 0.1 and lethal.state.tick > won_tick, "victory lets the final launch land and updates snapshots")
	_check(lethal.state.phase == "won" and lethal.state.fighters[0].action == "victory", "terminal settling celebrates instead of accepting a new attack")


func _test_needle_origin() -> void:
	for facing in [-1, 1]:
		var battle = _arena("oichi")
		var player: Dictionary = battle.state.fighters[0]
		var enemy: Dictionary = battle.state.fighters[1]
		player.face = facing
		enemy.x = player.x + facing * 50.0
		_advance(battle, 1, Battle.LIGHT)
		_advance(battle, 6)
		var needles: Array = battle.state.effects.filter(func(effect: Dictionary) -> bool: return effect.type == "projectile")
		_check(needles.size() == 1 and needles[0].x == player.x + facing * 105.0, "needle visibly begins at extended hand in both directions")
		_advance(battle, 1)
		_check(enemy.hp < 1000, "hand-origin needle still catches a close target along first segment")
		battle = _arena("oichi")
		battle.state.fighters[0].face = facing
		battle.state.fighters[1].x = 500.0 - facing * 50.0
		_advance(battle, 1, Battle.LIGHT)
		_advance(battle, 9)
		_check(battle.state.fighters[1].hp == 1000, "extended needle does not hit an enemy behind the player")
	var shield = _arena("oichi")
	shield.state.fighters[1].x = 600.0
	var front: Dictionary = shield.state.fighters[1].duplicate(true)
	front.id = 99
	front.x = 540.0
	shield.state.fighters.append(front)
	_advance(shield, 1, Battle.LIGHT)
	_advance(shield, 8)
	_check(front.hp < 1000 and shield.state.fighters[1].hp == 1000, "first swept needle hits nearest enemy regardless of fighter array order")


func _test_pickups_and_difficulty() -> void:
	var battle = _arena()
	var player: Dictionary = battle.state.fighters[0]
	player.x = 390.0
	player.y = 450.0
	_advance(battle, 1, Battle.INTERACT)
	_check(player.weapon_id == "sword_nagamitsu" and player.weapon_id in player.owned_weapons, "weapon pickup equips the named sword and records ownership")
	_advance(battle, 1)
	player.x = 450.0
	player.y = 505.0
	_advance(battle, 1, Battle.INTERACT)
	_check(player.armor == 1, "armor pickup sets appearance and defense flag")
	_advance(battle, 1)
	player.x = 520.0
	player.y = 465.0
	player.hp = 20
	_advance(battle, 1, Battle.INTERACT)
	_check(player.hp == 100, "food restores 80 health")
	var normal = _arena()
	var armed = _arena()
	armed.state.fighters[0].weapon = 1
	_advance(normal, 1, Battle.LIGHT)
	_advance(armed, 1, Battle.LIGHT)
	_advance(normal, 7)
	_advance(armed, 7)
	_check(armed.state.fighters[1].hp < normal.state.fighters[1].hp, "weapon raises actual damage")
	var easy = Battle.new()
	var hard = Battle.new()
	easy.reset("easy")
	hard.reset("hard")
	_check(easy.state.fighters[0].max_hp > hard.state.fighters[0].max_hp, "difficulty changes player health")
	_check(easy.state.fighters[1].max_hp < hard.state.fighters[1].max_hp, "difficulty changes enemy health")
	battle.reset("invalid", 8, ["invalid"])
	_check(battle.state.difficulty == "normal" and battle.state.fighters[0].kind == "nobunaga", "invalid setup values safely default")
	_check(battle.state.fighters.filter(func(f: Dictionary) -> bool: return f.team == 0).size() == 2, "player count clamps to two")


func _test_wave_restart_and_copy() -> void:
	var battle = Battle.new()
	var initial: Dictionary = battle.get_state()
	var copy: Dictionary = battle.get_state()
	copy.fighters[0].hp = 1
	_check(battle.state.fighters[0].hp > 1, "get_state returns deep copy")
	for wave in range(3):
		for fighter in battle.state.fighters:
			if fighter.team == 1:
				fighter.hp = 0
		battle.step([])
	_check(battle.state.phase == "won" and battle.state.wave == 3, "three completed waves win")
	battle.reset()
	_check(battle.get_state() == initial, "reset restores full initial state")
	battle.state.fighters[0].hp = 0
	battle.step([])
	_check(battle.state.phase == "lost", "no living players loses")
	battle.reset("normal", 2)
	battle.state.fighters[0].hp = 0
	battle.step([])
	_check(battle.state.phase == "playing", "co-op continues while one player survives")


func _test_boss_and_special() -> void:
	var battle = _arena()
	var player: Dictionary = battle.state.fighters[0]
	var enemy: Dictionary = battle.state.fighters[1]
	enemy.kind = "boss"
	enemy.cooldown = 0
	battle.step([])
	_check(enemy.action == "boss_sweep" and battle.state.effects.any(func(e: Dictionary) -> bool: return e.type == "warning"), "boss telegraphs its sweep before hitting")
	var hp: int = player.hp
	for i in range(58):
		battle.step([{"dy": 1}])
	_check(player.hp == hp, "walking out of boss telegraph avoids damage")
	var hit = _arena()
	hit.state.fighters[1].kind = "boss"
	hit.state.fighters[1].cooldown = 0
	_advance(hit, 60)
	_check(hit.state.fighters[0].hp < hit.state.fighters[0].max_hp, "remaining in boss telegraph takes damage")
	var armored = _arena()
	armored.state.fighters[0].armor = 1
	armored.state.fighters[1].kind = "boss"
	armored.state.fighters[1].cooldown = 0
	_advance(armored, 60)
	_check(armored.state.fighters[0].hp > hit.state.fighters[0].hp, "armor reduces real enemy damage")
	var special = _arena()
	special.state.fighters[0].rage = 100
	special.state.fighters[1].x = 730.0
	_advance(special, 1, Battle.SPECIAL)
	_check(special.state.fighters[1].hp == 1000, "special has startup before damage")
	_advance(special, 27)
	_check(special.state.fighters[1].hp < 1000, "Nobunaga area special now catches nearby sidesteps")
	_check(special.state.tick == 28, "special does not freeze simulation")


func _test_replay() -> void:
	var a = Battle.new()
	var b = Battle.new()
	a.reset("normal", 2)
	b.reset("normal", 2)
	for tick in range(900):
		var buttons := 0
		if tick % 40 == 0:
			buttons |= Battle.LIGHT
		if tick % 110 > 75:
			buttons |= Battle.HEAVY
		if tick % 180 == 5:
			buttons |= Battle.JUMP
		var inputs := [{"dx": 1 if tick % 180 < 110 else -1, "dy": 1 if tick % 120 < 60 else -1, "buttons": buttons}, {"dx": 1, "dy": 0, "buttons": buttons | (Battle.INTERACT if tick % 65 == 0 else 0)}]
		a.step(inputs)
		b.step(inputs)
	_check(a.get_state() == b.get_state(), "900-tick two-player input replay is deterministic")
	_check(hash(a.get_state()) == hash(b.get_state()), "replay state hashes match")


func _test_playthrough() -> void:
	var battle = Battle.new()
	battle.reset("easy", 2)
	for tick in range(12000):
		if battle.state.phase != "playing":
			break
		var inputs: Array = []
		for player in battle.state.fighters:
			if player.team != 0:
				continue
			var target: Dictionary = {}
			var closest := INF
			for enemy in battle.state.fighters:
				if enemy.team != 1 or enemy.hp <= 0:
					continue
				var distance: float = absf(enemy.x - player.x) + absf(enemy.y - player.y)
				if distance < closest:
					closest = distance
					target = enemy
			var input := {"dx": 0, "dy": 0, "buttons": 0}
			if not target.is_empty():
				var range_x := 65.0 if player.kind == "nobunaga" else 180.0
				var delta: float = target.x - player.x
				if absf(delta) > range_x or (delta != 0.0 and signf(delta) != player.face):
					input.dx = int(signf(delta))
				if absf(target.y - player.y) > 10.0:
					input.dy = int(signf(target.y - player.y))
				if absf(delta) < range_x + 30.0 and absf(target.y - player.y) < 30.0:
					input.buttons = Battle.LIGHT if tick % 2 == 0 else 0
			inputs.append(input)
		battle.step(inputs)
	_check(battle.state.phase == "won", "two-player easy encounter is completable using normal inputs")
