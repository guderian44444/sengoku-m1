extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_test_route()
	_test_coop()
	_test_solids()
	_test_food_and_boss()
	_test_spawn_space()
	_test_wire()
	print("STAGE V18 %s: %d checks, %d failures; progression, collisions, two-player gates, boss and snapshot validation" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)

func _clear_wave(battle) -> void:
	for fighter in battle.state.fighters:
		if fighter.team == 1:
			fighter.hp = 0
			fighter.action = "defeated"
	for player in battle.state.fighters:
		if player.team == 0: player.invuln = 20000

func _advance(battle, ticks: int) -> void:
	for tick in range(ticks): battle.step([])

func _test_route() -> void:
	var battle := Battle.new()
	battle.reset_campaign()
	check(battle.state.stage.total == 10 and battle.state.faction == "imagawa","Opening respects approved Imagawa campaign")
	var encountered := []
	var wave_total := 0
	var seen_enemies := {}
	for segment in range(10):
		check(battle.state.stage.index == segment and not battle.state.stage.go,"New section locks GO until actual encounter clears")
		check(Wire.valid_snapshot(battle.get_state()),"Section start snapshot validates")
		var waves: int = battle.state.stage.wave_total
		wave_total += waves
		for wave in range(1,waves + 1):
			check(battle.state.wave == wave,"Expected per-section wave")
			for fighter in battle.state.fighters:
				if fighter.team == 1: seen_enemies[fighter.id] = true
				if fighter.hp > 0 and fighter.kind == "boss":
					encountered.append(segment)
					check(not battle.state.intro.blocking,"Officers announce without pausing")
					if fighter.stage_boss:
						fighter.hp = fighter.max_hp / 2
						battle.step([])
						check(battle.state.stage.boss_reinforced,"Final boss summons its one reserve at half health")
			for fighter in battle.state.fighters:
				if fighter.team == 1: seen_enemies[fighter.id] = true
			_clear_wave(battle)
			_advance(battle,76 if wave < waves else 46)
			if wave < waves: check(not battle.state.stage.go,"Intermediate waves never open exit")
		if battle.state.props.any(func(p):return p.get("mandatory",false)):
			check(not battle.state.stage.go,"Unbroken barricades keep exit closed")
			for prop in battle.state.props:
				if prop.get("mandatory",false): battle._damage_prop(prop,999,battle.state.fighters[0].id)
			_advance(battle,46)
		if segment < 9:
			check(battle.state.stage.go and battle.state.phase == "playing","Every cleared nonfinal section displays GO")
			_advance(battle,30)
			check(battle.state.stage.index == segment,"No automatic warp when players have not reached right exit")
			battle.state.fighters[0].x = battle.state.stage.width - 120.0
			battle.step([])
		else: check(battle.state.phase == "won" and not battle.state.stage.go,"Only final encounter triggers celebration")
	check(encountered == [2,5,7,9],"Officers every 2-3 sections then final boss")
	check(wave_total == 22 and seen_enemies.size() == 90,"Published route: 22 waves, 90 opponents including one reserve")

func _test_coop() -> void:
	var battle := Battle.new()
	battle.reset_campaign("normal",2)
	check(battle.state.fighters.filter(func(f):return f.team == 1).size() == 4,"Co-op adds an enemy to ordinary waves")
	battle.state.wave = battle.state.stage.wave_total
	_clear_wave(battle)
	_advance(battle,46)
	var left: Dictionary = battle.state.fighters[0]
	var right: Dictionary = battle.state.fighters[1]
	left.x = battle.state.stage.width - 120.0
	right.x = 500.0
	battle.step([])
	check(battle.state.stage.index == 0,"One player cannot abandon a living partner")
	left.x = battle.state.stage.width - 120.0
	right.x = left.x - 20
	left.hp = 88
	left.rage = 55
	left.weapon = 1
	battle.step([])
	check(battle.state.stage.index == 1 and battle.state.fighters[0].hp == 88 and battle.state.fighters[0].rage == 55 and battle.state.fighters[0].weapon == 1,"Both cross together with health, equipment and rage intact")
	battle.state.fighters[1].hp = 0
	battle.state.wave = battle.state.stage.wave_total
	_clear_wave(battle)
	_advance(battle,46)
	battle.state.fighters[0].x = battle.state.stage.width - 120.0
	battle.step([])
	check(battle.state.stage.index == 2 and battle.state.fighters[1].hp == 0,"Fallen partner neither blocks exit nor silently revives")

func _test_solids() -> void:
	var battle := Battle.new()
	battle.reset_campaign()
	var player: Dictionary = battle.state.fighters[0]
	var enemy: Dictionary = battle.state.fighters[1]
	battle.state.fighters = [player,enemy]
	battle.state.props = []
	player.x = 500.0
	player.y = 480.0
	enemy.x = 600.0
	enemy.y = 480.0
	battle._move_fighter(player,200.0)
	check(player.x <= 555.0 and enemy.hp > 0,"Large movement cannot tunnel through a standing enemy")
	battle._move_fighter(player,0.0,65.0)
	battle._move_fighter(player,130.0)
	check(player.x > enemy.x,"A different lane allows walking around enemies")
	player.x = 550.0
	player.y = 480.0
	player.sprinting = true
	battle._move_fighter(player,15.0,0.0,true)
	check(player.x > 555.0 and enemy.knockback > 0,"A charge really pushes the enemy before crossing its old footprint")
	check(battle.state.events.any(func(e):return e.type == "run_bump"),"Charge emits its existing impact event")
	enemy.kind = "boss"
	enemy.weight = "heavy"
	enemy.knockback = 0.0
	player.x = 550.0
	battle._move_fighter(player,100.0,0.0,true)
	check(player.x <= 555.0,"An unshoved heavy officer remains solid")
	battle.state.fighters = [player]
	var prop := {"id":999,"kind":"cart","x":700.0,"y":480.0,"width":170.0,"depth":58.0,"hp":90,"max_hp":90,"broken":false,"drop":""}
	battle.state.props = [prop]
	player.x = 500.0
	battle._move_fighter(player,500.0,0.0,true)
	check(player.x == 595.0,"Charging cannot pass an intact large cart")
	battle._damage_prop(prop,999,player.id)
	battle._move_fighter(player,500.0)
	check(player.x > 700.0 and battle.state.drops.is_empty(),"Broken scenery opens passage and an empty prop does not invent loot")
	battle._enter_segment(4)
	player = battle.state.fighters[0]
	battle.state.fighters = [player]
	for lane in [360.0,395.0,450.0,490.0,550.0,600.0]:
		player.x = 1000.0
		player.y = lane
		battle._move_fighter(player,500.0)
		check(player.x < 1230.0,"Mandatory barricade blocks every traversable lane")

func _test_food_and_boss() -> void:
	var battle := Battle.new()
	battle.reset_campaign()
	var player: Dictionary = battle.state.fighters[0]
	var jar: Dictionary = battle.state.props[0]
	player.hp = 50
	player.x = jar.x
	player.y = jar.y
	battle._damage_prop(jar,100,player.id)
	check(battle.state.drops.size() == 1 and battle.state.drops[0].food_id == "rice","Breaking a marked jar exposes its configured food")
	battle._pickup(player)
	check(player.hp == 85 and battle.state.drops.is_empty(),"Food applies the configured heal once")
	battle._enter_segment(9)
	battle.state.wave = 2
	battle._spawn_segment_wave()
	var boss: Dictionary = battle.state.fighters[-1]
	check(boss.display_name == "松井宗信" and boss.max_hp == 1400 and boss.render_scale == 1.3,"Final officer is distinct from midbosses")
	check(boss.boss_actions.size() == 4 and "boss_earth" in boss.boss_actions,"Final officer has short, long, counter and area attacks")
	var tick: int = battle.state.tick
	var before: float = battle.state.fighters[0].x
	battle.step([{"dx":1}])
	check(battle.state.tick == tick + 1 and battle.state.fighters[0].x > before,"Name and dialogue do not freeze movement")
	boss.action = "boss_thrust"
	boss.invuln = 0
	battle._damage(boss,10,battle.state.fighters[0].id,false)
	check(boss.action == "boss_thrust" and boss.hp < boss.max_hp,"Final boss takes light damage without losing its committed attack")
	boss.invuln = 0
	battle._damage(boss,30,battle.state.fighters[0].id,true)
	check(boss.action == "down","Heavy attacks can still interrupt the final officer")

func _test_spawn_space() -> void:
	var battle := Battle.new()
	battle.reset_campaign("normal",2)
	for section in range(10):
		battle._enter_segment(section)
		for player in battle.state.fighters:
			if player.team == 0:
				player.x = battle.state.stage.width - 100
				player.y = 490.0 + player.player_index * 70.0
		_clear_wave(battle)
		battle.state.wave = battle.state.stage.wave_total
		battle._spawn_segment_wave()
		for enemy in battle.state.fighters:
			if enemy.team == 0 or enemy.hp <= 0: continue
			for player in battle.state.fighters:
				if player.team == 0: check(absf(enemy.x-player.x) >= 85.0 or absf(enemy.y-player.y) >= 52.0,"Reinforcements never appear inside an edge-camping player")
			for prop in battle.state.props:
				check(prop.broken or absf(enemy.x-prop.x) >= prop.width * 0.5 + 38.0 or absf(enemy.y-prop.y) >= prop.depth * 0.5 + 28.0,"Enemy spawn avoids intact scenery")

func _test_wire() -> void:
	var battle := Battle.new()
	battle.reset_campaign()
	var valid: Dictionary = battle.get_state()
	for pair in [["index",10],["width",INF],["music","missing"],["go",true],["boss_reinforced",1],["name",[]]]:
		var invalid := valid.duplicate(true)
		invalid.stage[pair[0]] = pair[1]
		check(not Wire.valid_snapshot(invalid),"Malformed section data rejected: " + str(pair[0]))
	for pair in [["mandatory",1],["food_id","secret"],["drop","unknown"]]:
		var invalid := valid.duplicate(true)
		invalid.props[0][pair[0]] = pair[1]
		check(not Wire.valid_snapshot(invalid),"Malformed scenery data rejected")
