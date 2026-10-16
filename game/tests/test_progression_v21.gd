extends SceneTree

const Battle = preload("res://core/battle.gd")
const Equipment = preload("res://core/equipment.gd")
var checks := 0
var failures := 0

class QuietBattle extends Battle:
	func _enemy_input(_fighter: Dictionary) -> void: pass

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_test_lives()
	_test_fatal_reactions()
	_test_coop()
	_test_region_stats()
	_test_training()
	_test_score()
	_test_talismans()
	_test_heavy_reach()
	print("PROGRESSION V21 %s: %d checks, %d failures; deterministic combat, lives, score and shield rules" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)

func arena(count: int = 1, campaign: bool = false) -> QuietBattle:
	var battle := QuietBattle.new()
	if campaign: battle.reset_campaign("normal", count)
	else: battle.reset("normal", count)
	battle.state.fighters = battle.state.fighters.filter(func(f): return f.team == 0)
	battle.state.props.clear()
	battle.state.drops.clear()
	battle.state.effects.clear()
	battle.state.intro.clear()
	add_enemy(battle, "dummy", 1400, 590, 10000)
	return battle

func add_enemy(battle: QuietBattle, kind: String, x: float, y: float, hp: int = 100) -> Dictionary:
	var enemy: Dictionary = battle._make_fighter(1, kind, x, y, hp)
	enemy.home_x = x
	enemy.home_y = y
	battle.state.fighters.append(enemy)
	return enemy

func ticks(battle: QuietBattle, amount: int) -> void:
	for tick in range(amount): battle.step([])

func kill_player(battle: QuietBattle, player: Dictionary) -> void:
	player.action = "idle"
	player.invuln = 0
	player.shield_points = 0
	battle._damage(player, 10000, 0, false)

func _test_lives() -> void:
	for campaign in [false, true]:
		var battle := arena(1, campaign)
		var player: Dictionary = battle.state.fighters[0]
		check(player.lives == 3 and player.score == 0 and player.next_life_score == 10000, "New solo fighter starts with three lives and a 10000-point threshold")
		for remaining in [2, 1]:
			kill_player(battle, player)
			check(player.hp == 0 and player.action == "defeated" and player.lives == remaining and player.respawn_ticks == 120, "Fatal damage spends one life and leaves a prone body")
			check(not battle._damage(player, 10000, 0, false) and player.lives == remaining, "Repeated hits on a dead player cannot spend more lives")
			ticks(battle, 119)
			check(player.hp == 0 and player.respawn_ticks == 1 and battle.state.phase == "playing", "The first 119 ticks keep the body and do not declare a loss")
			ticks(battle, 1)
			check(player.hp == player.max_hp and player.action == "recovering" and player.respawn_ticks == 0, "Tick 120 restores full HP into the recovery animation")
			check(player.lives == remaining and player.invuln >= 180 and battle.state.events.any(func(e): return e.type == "revive" and e.actor == player.id), "Revival preserves remaining lives and emits protection plus its event")
			ticks(battle, Battle.RECOVER_TICKS)
			check(player.action == "idle" and player.invuln > 0, "Revival recovery finishes with protection still active")
		kill_player(battle, player)
		ticks(battle, 1)
		check(player.lives == 0 and player.hp == 0 and player.respawn_ticks == 0 and battle.state.phase == "lost", "The third death exhausts lives and ends solo play")
		ticks(battle, 300)
		check(battle.state.fighters.has(player) and player.action == "defeated" and player.action_tick == 24 and player.z == 0, "Exhausted player remains in the final prone frame without respawning")
	var falling := arena()
	var body: Dictionary = falling.state.fighters[0]
	body.z = 5000.0
	body.airborne_lock = true
	body.bounces_left = 0
	kill_player(falling, body)
	ticks(falling, 120)
	check(body.hp == 0 and body.z > 0 and body.respawn_ticks == 1, "A death still in the air waits for the landing instead of reviving mid-fall")
	ticks(falling, 100)
	check(body.hp == body.max_hp and body.z == 0 and body.lives == 2, "An airborne death revives after landing without spending a second life")

func _test_fatal_reactions() -> void:
	for attack in ["chain_cast", "chain_finish", "counter_stun"]:
		var battle := arena()
		var player: Dictionary = battle.state.fighters[0]
		player.x = 700.0
		player.y = 480.0
		player.hp = 24 if attack == "chain_finish" else 1
		player.z = 30.0
		player.vz = 0.0
		var boss := add_enemy(battle, "boss", 500, 480, 240)
		boss.boss_variant = "kusarigama"
		boss.face = 1
		battle._begin(boss, "boss_counter" if attack == "counter_stun" else "boss_chain")
		if attack == "chain_cast":
			battle._cast_chain(boss)
		elif attack == "chain_finish":
			player.action = "pulled"
			player.pull_owner = boss.id
			boss.chain_target = player.id
			boss.action_tick = Battle.enemy_timing(boss)[0] + 28
			battle._tick_enemy_attack(boss)
		else:
			battle._enemy_melee(boss, 240.0, 80.0, 26, "stun")
		check(player.hp == 0 and player.action == "defeated" and player.respawn_ticks == 120, attack + " leaves a fatal low-air hit defeated instead of pulled or stunned")
		check(player.pull_owner == 0 and boss.chain_target == 0, attack + " does not attach a dead body to the chain")
		ticks(battle, 300)
		check(player.hp == player.max_hp and player.z == 0 and player.respawn_ticks == 0 and player.lives == 2, attack + " lands and revives instead of getting stuck at respawn tick one")
	for lives in [1, 3]:
		var battle := arena()
		var player: Dictionary = battle.state.fighters[0]
		player.lives = lives
		var last_enemy := add_enemy(battle, "soldier", 700, 480, 1)
		battle.state.fighters = [player, last_enemy]
		battle.state.wave = 3
		kill_player(battle, player)
		battle._damage(last_enemy, 10, player.id, false, false)
		ticks(battle, 119)
		check(battle.state.phase == ("lost" if lives == 1 else "playing") and player.hp == 0, "A final-wave simultaneous defeat waits for reserve lives, or loses when exhausted")
		if lives > 1:
			ticks(battle, 1)
			check(player.hp == player.max_hp and battle.state.phase == "won", "Final-wave victory is declared only after the surviving reserve life returns")

func _test_coop() -> void:
	var battle := arena(2, true)
	var first: Dictionary = battle.state.fighters[0]
	var second: Dictionary = battle.state.fighters[1]
	check(first.lives == 3 and second.lives == 3, "Each co-op player owns three lives")
	kill_player(battle, first)
	kill_player(battle, second)
	ticks(battle, 119)
	check(battle.state.phase == "playing" and first.hp == 0 and second.hp == 0, "Both co-op bodies can wait for revival without a premature defeat")
	ticks(battle, 1)
	check(first.hp > 0 and second.hp > 0 and first.lives == 2 and second.lives == 2, "Both players revive independently at the two-second boundary")
	first.lives = 1
	kill_player(battle, first)
	ticks(battle, Battle.RECOVER_TICKS + 2)
	var before: float = second.x
	battle.step([{}, {"dx":1,"dy":0,"buttons":0}])
	check(first.lives == 0 and first.hp == 0 and second.x > before and battle.state.phase == "playing", "The surviving partner remains controllable when the other player is out of lives")
	battle.state.fighters = [first, second]
	battle.state.wave = battle.state.stage.wave_total
	battle.state.stage.clear_tick = battle.state.tick - 45
	second.x = battle.state.stage.encounter_end - 100.0
	second.action = "idle"
	battle._tick_segment()
	check(battle.state.stage.checkpoint == 1 and first.hp == first.max_hp and first.lives == 1, "Survivor advancing through GO grants the exhausted partner one life")
	kill_player(battle,first)
	first.score = 9950
	first.next_life_score = 10000
	battle._award_score(first.id, 50)
	check(first.lives == 1 and first.respawn_ticks == 120 and first.hp == 0, "A delayed personal award can return an exhausted co-op partner to the revival queue")
	ticks(battle, 120)
	check(first.hp == first.max_hp and first.lives == 1 and battle.state.phase == "playing", "The newly earned reserve life revives the exhausted partner without ending co-op")

func _test_region_stats() -> void:
	var battle := arena(2, true)
	var expected := []
	for index in range(2):
		var player: Dictionary = battle.state.fighters[index]
		player.lives = 5 - index
		player.score = 25000 + index * 50
		player.next_life_score = 30000
		player.weapon = 1
		player.armor = 1
		player.rage = 47
		var charm := Equipment.add(player,"iron")
		Equipment.instance(player,charm).durability = 63
		Equipment.equip(player,charm)
		if index == 1:
			player.hp = 0
			player.respawn_ticks = 38
		expected.append(player.duplicate(true))
	battle._enter_segment(1)
	for index in range(2):
		var player: Dictionary = battle.state.fighters[index]
		for field in ["id","kind","player_index","hp","max_hp","lives","score","next_life_score","weapon","armor","rage","shield_points","shield_kind","respawn_ticks"]:
			check(player[field] == expected[index][field], "Changing scenery preserves player %d %s" % [index + 1, field])
	check(battle.state.fighters[1].action == "defeated", "A waiting teammate remains a body across a scene change")

func _test_training() -> void:
	var battle := QuietBattle.new()
	battle.reset_training("nobunaga", "enemies")
	var player: Dictionary = battle.state.fighters[0]
	battle._damage(player, 10000, 0, false)
	check(player.hp == 1 and player.lives == 3 and player.respawn_ticks == 0, "Training fatal damage leaves one HP and never spends a life")
	for enemy in battle.state.fighters:
		if enemy.team == 1: battle._damage(enemy, 10000, player.id, false, false)
	for prop in battle.state.props: battle._damage_prop(prop, 10000, player.id)
	battle._award_score(player.id, 35000)
	check(player.score == 0 and player.lives == 3 and player.next_life_score == 10000, "Training kills, props and direct awards cannot farm score or extra lives")

func _test_score() -> void:
	var battle := arena(2)
	var first: Dictionary = battle.state.fighters[0]
	var second: Dictionary = battle.state.fighters[1]
	for kind in ["soldier", "flag", "commander", "archer", "gunner", "boss"]:
		var target := add_enemy(battle, kind, 950, 480)
		var before: int = second.score
		battle._damage(target, 1000, second.id, false, false)
		check(second.score == before + Battle.KILL_SCORES[kind] and first.score == 0, kind + " credits its killer's personal score only")
		battle._damage(target, 1000, first.id, false, false)
		check(second.score == before + Battle.KILL_SCORES[kind] and first.score == 0, "Repeated death damage cannot award " + kind + " twice")
	var final_boss := add_enemy(battle, "boss", 950, 480)
	final_boss.stage_boss = true
	var before: int = second.score
	battle._damage(final_boss, 1000, second.id, false, false)
	check(second.score == before + 5000, "The final commander awards 5000 rather than the midboss reward")
	var poisoned := add_enemy(battle, "soldier", 900, 400, 3)
	poisoned.poison = 60
	poisoned.poison_tick = 29
	poisoned.poison_owner = first.id
	battle._tick_fighter(poisoned)
	check(poisoned.hp == 0 and first.score == 100, "A lingering poison kill credits the stored original owner")
	var arrow_target := add_enemy(battle, "archer", second.x + 170, second.y, 10)
	before = second.score
	battle._projectile(second, 100, 0, false, "arrow", 400)
	for tick in range(12): battle._tick_effects()
	check(arrow_target.hp == 0 and second.score == before + 150, "A traveling arrow credits its projectile owner")
	var prop := {"id":9000,"kind":"jar","x":900.0,"y":450.0,"hp":20,"max_hp":20,"width":50.0,"depth":30.0,"broken":false,"drop":""}
	before = first.score
	battle._damage_prop(prop, 19, first.id)
	check(first.score == before, "Damaging a prop without breaking it gives no points")
	battle._damage_prop(prop, 1, first.id)
	check(first.score == before + 50, "Breaking a prop awards 50 points to the finishing owner")
	before = second.score
	battle._damage_prop(prop, 1000, second.id)
	check(first.score == 150 and second.score == before, "A broken prop never awards another player duplicate points")
	var awards := arena()
	var player: Dictionary = awards.state.fighters[0]
	awards._award_score(player.id, 9999)
	check(player.lives == 3 and player.score == 9999 and player.next_life_score == 10000, "One point short of a threshold does not grant a life")
	awards._award_score(player.id, 1)
	check(player.lives == 4 and player.next_life_score == 20000, "Exactly 10000 points grants one life")
	awards._award_score(player.id, 25000)
	check(player.score == 35000 and player.lives == 6 and player.next_life_score == 40000, "A large award crosses every threshold once")
	check(awards.state.events.filter(func(e): return e.type == "extra_life").size() == 3, "Each crossed threshold emits exactly one extra-life event")
	awards._award_score(0, 1000)
	awards._award_score(awards.state.fighters[1].id, 1000)
	awards._award_score(player.id, 0)
	awards._award_score(player.id, -10)
	check(player.score == 35000 and player.lives == 6, "Unknown owners, enemies and nonpositive awards cannot affect player progression")

func give_talisman(battle: QuietBattle, player: Dictionary, key: String, equip: bool = true) -> void:
	battle._add_drop("talisman", player.x, player.y)
	battle.state.drops[-1].talisman_id = key
	battle._pickup(player)
	if equip and battle.state.drops.is_empty(): Equipment.equip(player,int(player.inventory[-1].uid))

func _test_talismans() -> void:
	for key in ["vajra","iron","mirror"]:
		var battle := arena()
		var player: Dictionary = battle.state.fighters[0]
		var capacity: int = Battle.TALISMANS[key].durability
		check(capacity == {"vajra":40,"iron":75,"mirror":110}[key], key + " has the specified 40/75/110-point capacity")
		battle.state.tick = 12
		give_talisman(battle, player, key)
		check(player.shield_points == capacity and player.shield_kind == key and battle.state.drops.is_empty(), key + " grants and consumes its advertised shield pickup")
		check(player.pickup_flash_tick == 12 and battle.state.events.any(func(e): return e.type == "armor_pickup"), key + " emits its glow/sound confirmation")
		var hp: int = player.hp
		check(not battle._damage(player, 15, 0, false) and player.hp == hp and player.shield_points == capacity - 15 and player.action == "idle", key + " absorbs the full hit without HP loss or hurt reaction")
		player.invuln = 0
		check(not battle._damage(player, capacity - 15, 0, false) and player.hp == hp and player.shield_points == 0 and player.shield_kind == "", key + " disappears exactly when its protection is consumed")
		check(battle.state.events.filter(func(e): return e.type == "armor_break").size() == 1, key + " emits one shield-break event")
		give_talisman(battle, player, key)
		player.invuln = 0
		check(battle._damage(player, capacity + 7, 0, false) and player.hp == hp - 7 and player.shield_points == 0, key + " passes only excess damage through to HP")
	var battle := arena()
	var player: Dictionary = battle.state.fighters[0]
	give_talisman(battle, player, "mirror")
	give_talisman(battle, player, "vajra",false)
	check(player.shield_points == 110 and player.shield_kind == "mirror" and battle.state.drops.is_empty() and player.inventory.size() == 2, "A weaker talisman enters the bag without replacing equipped protection")
	battle.state.drops.clear()
	give_talisman(battle, player, "mirror",false)
	check(player.shield_points == 110 and battle.state.drops.size() == 1, "A third talisman stays on the floor when the bag is full")
	battle.state.drops.clear()
	Equipment.instance(player,int(player.treasure_uid)).durability = 25
	Equipment.sync(player)
	Equipment.remove(player,int(player.inventory[-1].uid))
	give_talisman(battle, player, "iron")
	check(player.shield_points == 75 and player.shield_kind == "iron" and battle.state.drops.is_empty(), "A stronger remaining shield replaces depleted protection")
	player.armor = 1
	battle._damage(player, 30, 0, false, false)
	check(player.shield_points == 48 and player.hp == player.max_hp, "Permanent armor reduction applies before shield consumption")

func _test_heavy_reach() -> void:
	for face in [-1, 1]:
		for combo in [1, 2]:
			var battle := arena()
			var player: Dictionary = battle.state.fighters[0]
			player.x = 700
			player.y = 480
			player.face = face
			var reach := 200.0 if combo == 1 else 230.0
			var probes := []
			for offset in [[reach,0,true],[reach+1,0,false],[150,80,true],[150,81,false],[-18,0,true],[-19,0,false]]:
				probes.append([add_enemy(battle, "soldier", player.x + face * offset[0], player.y + offset[1], 200), offset[2]])
			battle.state.props = [{"id":9001,"kind":"crate","x":player.x+face*(reach+24),"y":480.0,"hp":100,"max_hp":100,"width":50.0,"depth":30.0,"broken":false,"drop":""}, {"id":9002,"kind":"crate","x":player.x+face*(reach+26),"y":480.0,"hp":100,"max_hp":100,"width":50.0,"depth":30.0,"broken":false,"drop":""}]
			player.heavy_combo = combo
			player.heavy_combo_tick = 70
			battle._begin(player, "heavy")
			player.action_tick = Battle.hero_tick("nobunaga", 14) - 1
			battle._tick_fighter(player)
			for probe in probes: check((probe[0].hp < 200) == probe[1], "Heavy %d facing %d respects forward/depth/back boundaries at (%s,%s)" % [combo, face, probe[0].x, probe[0].y])
			check(battle.state.props[0].hp < 100 and battle.state.props[1].hp == 100, "Heavy %d uses the same sword reach for prop edges" % combo)
			if combo == 2: check(probes[0][0].airborne_lock, "The second heavy cut still launches the enemy at its extended tip")
	var battle := arena()
	var player: Dictionary = battle.state.fighters[0]
	player.x = 700
	player.y = 480
	var target := add_enemy(battle, "soldier", 895, 480, 200)
	battle.step([{"buttons":Battle.HEAVY}])
	battle.step([{"buttons":0}])
	ticks(battle, Battle.hero_tick("nobunaga", 14))
	check(player.heavy_combo == 1 and target.hp < 200, "A real short heavy-button tap hits at 195px without pressing against the enemy")
