extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0
var snapshots_valid := true


func _init() -> void:
	_test_roundhouse_and_events()
	_test_launch_strength()
	_test_boss_guard()
	_test_projectile_guard_origin()
	_test_retreat()
	_test_defeat_settling()
	_test_coop_replay()
	_check(snapshots_valid, "v11 combat snapshots remain valid on the wire")
	print("V11 COMBAT TESTS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
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


func _step(battle, ticks: int = 1, buttons: int = 0) -> void:
	for tick in range(ticks):
		battle.step([{"buttons": buttons}])
		snapshots_valid = snapshots_valid and Wire.valid_snapshot(battle.get_state())


func _test_roundhouse_and_events() -> void:
	for face in [-1, 1]:
		var battle = _arena("oichi")
		var player: Dictionary = battle.state.fighters[0]
		player.face = face
		var near: Dictionary = battle.state.fighters[1]
		near.x = player.x + face * 110.0
		near.y += 70.0
		# Third-light startup steps 42px before its planted-foot strike.
		var behind: Dictionary = battle._make_fighter(1, "dummy", player.x + face * (42.0 - 40.0), player.y - 65.0, 1000)
		var far: Dictionary = battle._make_fighter(1, "dummy", player.x + face * (42.0 + 210.0), player.y, 1000)
		battle.state.fighters.append_array([behind, far])
		var swings: Array = []
		for tick in range(46):
			_step(battle, 1, Battle.LIGHT if tick in [0, 4, 24] else 0)
			for event in battle.state.events:
				if event.type == "swing": swings.append(event.duplicate())
		_check(swings.size() == 3 and swings[0].combo == 1 and swings[1].combo == 2 and swings[2].combo == 3 and not swings[0].finisher and not swings[1].finisher and swings[2].finisher, "light events identify only the true combo finisher")
		_check(near.hp == 978 and behind.hp == 978 and near.airborne_lock and behind.airborne_lock, "Oichi roundhouse hits a wide arc on both sides of the planted foot")
		_check(near.knockback * face > 11.0 and behind.knockback * face > 11.0, "roundhouse sweeps nearby troops forward in both facing directions")
		_check(far.hp == 982 and battle.state.effects.all(func(e: Dictionary) -> bool: return e.type != "projectile"), "first two needles retain range and the third move creates no extra needle")
	var heavy = _arena()
	var heavy_events: Array = []
	for tick in range(40):
		_step(heavy, 1, Battle.HEAVY if tick in [0, 5] else 0)
		for event in heavy.state.events:
			if event.type == "swing": heavy_events.append(event.duplicate())
	_check(heavy_events.size() == 2 and heavy_events[0].heavy_combo == 1 and heavy_events[1].heavy_combo == 2 and heavy_events[1].finisher, "heavy events preserve separate first and second stages")


func _test_launch_strength() -> void:
	var distances: Array = []
	for impulse in [8.0, 13.0, 16.0]:
		var battle = _arena()
		var target: Dictionary = battle.state.fighters[1]
		var start_x: float = target.x
		battle._launch(target, 1, impulse)
		while target.airborne_lock: _step(battle)
		distances.append(target.x - start_x)
	_check(distances[1] > distances[0] * 1.5 and distances[2] > distances[1] * 1.2, "second heavy and charged impulses produce progressively longer travel")
	for hero in ["nobunaga", "oichi"]:
		var battle = _arena(hero)
		_step(battle, 40, Battle.HEAVY)
		_step(battle, 17)
		var target: Dictionary = battle.state.fighters[1]
		_check(target.airborne_lock and target.knockback > 15.0, hero + " charged move retains its full troop-clearing impulse")
		if hero == "oichi":
			var frozen_x: float = target.x
			_step(battle, 10)
			_check(target.x == frozen_x and target.freeze > 0, "ice still freezes motion while preserving the pending launch")
			_step(battle, 150)
			_check(target.x > frozen_x + 350.0 and not target.airborne_lock, "frozen charged victim completes the strong launch after thawing")
		battle = _arena(hero)
		var boss: Dictionary = battle._make_fighter(1, "boss", 585.0, 480.0, 1000)
		boss.cooldown = 9999
		battle.state.fighters[1] = boss
		_step(battle, 40, Battle.HEAVY)
		_step(battle, 20)
		_check(boss.hp < 1000 and boss.x == 585.0 and not boss.airborne_lock, hero + " charged move damages bosses without sweeping them away")
	var slam = _arena()
	slam.state.fighters[0].action = "charged_slam"
	slam._wave(slam.state.fighters[0], 480.0, 65, "", 42)
	_step(slam, 4)
	_check(slam.state.fighters[1].knockback > 13.0, "charged shockwave also sweeps troops away")


func _test_boss_guard() -> void:
	var blocked := 0
	for tick in range(100):
		var battle = _arena()
		var player: Dictionary = battle.state.fighters[0]
		player.action = "light"
		var boss: Dictionary = battle._make_fighter(1, "boss", 585.0, 480.0, 1000)
		battle.state.fighters[1] = boss
		battle.state.tick = tick
		var accepted: bool = battle._damage(boss, 14, player.id, false)
		if not accepted:
			blocked += 1
			_check(boss.hp == 1000 and boss.action == "guard" and boss.counter_ticks == 90 and battle.state.events.any(func(e: Dictionary) -> bool: return e.type == "guard"), "boss block has visible state, impact event and cooldown")
			_step(battle, 16)
			_check(boss.action != "guard" and boss.counter_ticks == 74, "boss block returns to combat while its parry cooldown continues counting down")
	_check(blocked == 25, "boss frontal guard succeeds in exactly 25 of 100 deterministic windows")
	for situation in ["rear", "charged", "cooldown", "frozen", "special", "recovering"]:
		var battle = _arena()
		var player: Dictionary = battle.state.fighters[0]
		player.action = "light"
		var boss: Dictionary = battle._make_fighter(1, "boss", 585.0, 480.0, 1000)
		battle.state.fighters[1] = boss
		while (battle.state.tick * 17 + boss.id * 13 + player.id * 7) % 100 >= 25: battle.state.tick += 1
		match situation:
			"rear": player.x = 620.0
			"charged", "special": player.action = situation
			"cooldown": boss.counter_ticks = 1
			"frozen": boss.freeze = 30
			"recovering": boss.action = "recovering"
		var accepted: bool = battle._damage(boss, 20, player.id, false)
		_check(not accepted and boss.hp == 1000 if situation == "recovering" else accepted, situation + " uses ground recovery protection instead of automatic parry")
		_check(not battle.state.events.any(func(e: Dictionary) -> bool: return e.type == "guard"), situation + " does not trigger an automatic parry")


func _test_projectile_guard_origin() -> void:
	for origin in ["light", "charged", "special"]:
		var battle = _arena("oichi")
		var player: Dictionary = battle.state.fighters[0]
		var boss: Dictionary = battle._make_fighter(1, "boss", 620.0, 480.0, 1000)
		battle.state.fighters[1] = boss
		player.action = origin
		battle._projectile(player, 20, 0, origin == "charged", "special_arrow" if origin == "special" else "arrow")
		player.action = "light" if origin != "light" else "idle"
		while (battle.state.tick * 17 + boss.id * 13 + player.id * 7) % 100 >= 25: battle.state.tick += 1
		battle._tick_effects()
		_check((boss.hp == 1000 and boss.action == "guard") if origin == "light" else (boss.hp == 980 and boss.action != "guard"), origin + " projectile uses its launch-time action for boss parry even after the shooter starts another move")
	for removed in [false, true]:
		var battle = _arena("oichi")
		var player: Dictionary = battle.state.fighters[0]
		var target: Dictionary = battle.state.fighters[1]
		target.x = 620.0
		player.action = "charged"
		battle._projectile(player, 43, 0, true, "arrow")
		if removed: battle.state.fighters.erase(player)
		else:
			player.hp = 0
			battle._begin(player, "defeated")
		battle._tick_effects()
		_check(target.hp == 957 and target.airborne_lock and Wire.valid_snapshot(battle.get_state()), "an already released arrow can finish safely after its shooter dies or leaves the fighter list")


func _test_retreat() -> void:
	for kind in ["archer", "gunner"]:
		for face in [-1, 1]:
			var battle = _arena()
			var enemy: Dictionary = battle.state.fighters[1]
			enemy.kind = kind
			enemy.x = 500.0 - face * 205.0
			enemy.cooldown = 9999
			var start_x: float = enemy.x
			_step(battle, 24)
			_check(enemy.action == "retreat" and enemy.face == face and enemy.move_dx == -face and enemy.action_tick >= 23 and (enemy.x - start_x) * -face > 49.0, kind + " backsteps continuously while keeping its weapon toward the player")
			_step(battle, 10)
			_check(enemy.action == "idle" and enemy.move_dx == 0, kind + " stops retreating after opening a safe gap")


func _test_defeat_settling() -> void:
	for launch in [false, true]:
		var battle = _arena()
		battle.state.erase("training")
		battle.state.erase("mode")
		battle.state.wave = 3
		var target: Dictionary = battle.state.fighters[1]
		target.kind = "soldier"
		battle._damage(target, 2000, battle.state.fighters[0].id, true)
		if launch: battle._launch(target, 1, 13.0)
		_step(battle, 120)
		_check(battle.state.phase == "won" and target.hp == 0 and target.action == "defeated" and target.action_tick == 24 and target.z == 0.0 and not target.airborne_lock, "grounded and launched final enemies both finish a settled corpse pose after victory")
		var settled: Dictionary = target.duplicate(true)
		_step(battle, 120)
		_check(target == settled, "defeated corpse never plays recovery or stands back up")


func _test_coop_replay() -> void:
	var first = Battle.new()
	var second = Battle.new()
	first.reset("easy", 2, ["oichi", "nobunaga"])
	second.reset("easy", 2, ["oichi", "nobunaga"])
	for tick in range(1800):
		var inputs := [{"dx": 1 if tick % 260 < 180 else -1, "dy": 0, "buttons": Battle.LIGHT if tick % 21 == 0 else 0}, {"dx": 1 if tick % 350 < 230 else -1, "dy": (tick / 180) % 3 - 1, "buttons": Battle.HEAVY if tick % 70 < 40 else 0}]
		first.step(inputs)
		second.step(inputs)
		snapshots_valid = snapshots_valid and Wire.valid_snapshot(first.get_state())
	_check(first.get_state() == second.get_state(), "two-player stronger launches, Oichi kick and boss defenses replay deterministically")
