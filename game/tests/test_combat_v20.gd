extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_test_boss_health()
	_test_death_camera()
	_test_terminal_effects()
	_test_checkpoint_edges()
	_test_player_recovery()
	print("COMBAT V20 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)

func _test_boss_health() -> void:
	for difficulty in Battle.DIFFICULTIES:
		for count in [1,2]:
			var battle := Battle.new()
			battle.reset_campaign(difficulty,count)
			for final in [false,true]:
				battle._enter_segment(6 if final else 1)
				battle._start_checkpoint(1)
				battle.state.fighters = battle.state.fighters.filter(func(f): return f.team == 0)
				battle.state.wave = battle.state.stage.wave_total
				battle._spawn_segment_wave()
				var bosses: Array = battle.state.fighters.filter(func(f): return f.kind == "boss")
				check(bosses.size() == 1,"Boss stays unique at every difficulty and party size")
				check(bosses[0].max_hp == int(Battle.DIFFICULTIES[difficulty].player_hp) * (3 if final else 2),"Player HP boost does not increase campaign officer HP")
			battle.reset(difficulty,count)
			battle.state.fighters = battle.state.fighters.filter(func(f): return f.team == 0)
			battle.state.wave = 3
			battle._spawn_wave()
			check(battle.state.fighters[-1].max_hp == int(Battle.DIFFICULTIES[difficulty].player_hp) * 2,"Trial bosses retain their prior HP")
	var training := Battle.new()
	training.reset_training("nobunaga","boss")
	check(training.state.fighters[1].max_hp == int(Battle.DIFFICULTIES.normal.player_hp) * 2,"Training boss retains its prior HP")
	training.reset("normal",2)
	training.state.fighters[0].max_hp_bonus = 15
	training.state.fighters[1].max_hp_bonus = 30
	training.state.fighters[1].hp = 0
	check(training._boss_hp() == 300 and training._boss_hp(true) == 450,"Highest saved HP bonus still counts for a fallen partner without the new player multiplier")
	training.state.fighters.reverse()
	check(training._boss_hp() == 190,"Party ordering cannot change boss HP")

func _test_death_camera() -> void:
	for count in [1,2]:
		var battle := Battle.new()
		battle.reset_campaign("normal",count)
		battle._start_checkpoint(1)
		battle.state.props.clear()
		battle.state.fighters = battle.state.fighters.filter(func(f): return f.team == 0)
		for player in battle.state.fighters:
			player.x = 2800.0+player.player_index*100.0
			player.y = 480.0
			player.lives = 1
			battle._damage(player,1000,0,false)
		var before := Battle.camera_left(battle.state)
		for tick in range(600): battle.step([])
		check(battle.state.phase == "lost","All players dead ends the fight")
		check(before > 1800 and is_equal_approx(Battle.camera_left(battle.state),before),"Defeat keeps the camera on the fallen party rather than returning to the scene entrance")
		check(battle.state.fighters.size() == count,"Player corpses are never culled by the enemy corpse timer")
		for player in battle.state.fighters:
			check(player.action == "defeated" and player.action_tick == 24 and player.z == 0,"Death reaches and holds the final prone pose")
		check(Wire.valid_snapshot(battle.get_state()),"Settled defeat remains a valid co-op snapshot")

func _test_terminal_effects() -> void:
	var battle := Battle.new()
	battle.reset()
	battle.state.props.clear()
	var player: Dictionary = battle.state.fighters[0]
	var enemy: Dictionary = battle.state.fighters[1]
	enemy.x = player.x+20.0
	enemy.y = player.y
	player.lives = 1
	battle._damage(player,1000,enemy.id,false)
	battle.state.phase = "lost"
	check(battle.state.effects.any(func(e): return e.type == "damage") and battle.state.effects.any(func(e): return e.type == "hit"),"Fatal hit starts with visible impact and damage text")
	battle._effect("shockwave",enemy.x,enemy.y,30,{"radius":120.0,"owner":player.id,"team":0,"face":1,"damage":100,"hit_ids":[],"element":"","knockdown":true})
	var enemy_hp: int = enemy.hp
	for tick in range(60): battle.step([])
	check(not battle.state.effects.any(func(e): return e.type in ["damage","hit"]),"Last-hit sparks and damage text expire after defeat")
	check(battle.state.effects.is_empty(),"Lost state keeps aging effects after the corpse has settled")
	check(enemy.hp == enemy_hp,"Remaining effects cannot damage enemies after the battle ends")
	var settled_tick: int = battle.state.tick
	battle.step([])
	check(battle.state.tick == settled_tick,"Terminal clock settles once bodies and effects are finished")
	battle.reset()
	battle.state.fighters.resize(1)
	battle.state.phase = "won"
	battle._effect("hit",player.x,player.y,12)
	for tick in range(Battle.VICTORY_TICKS+2): battle.step([])
	check(battle.state.effects.is_empty() and battle.state.fighters[0].action == "victory" and battle.state.fighters[0].action_tick == Battle.VICTORY_TICKS,"Victory still clears combat effects and finishes its celebration once")

func _test_checkpoint_edges() -> void:
	var battle := Battle.new()
	battle.reset_campaign()
	battle.state.props.clear()
	battle.state.fighters.resize(1)
	var player: Dictionary = battle.state.fighters[0]
	player.x = battle.state.stage.encounter_end-60.0
	for go in [false,true]:
		battle.state.stage.go = go
		battle.state.stage.phase = "exit" if go else "combat"
		var camera := Battle.camera_left(battle.state)
		check(is_equal_approx(camera+1280,battle.state.stage.encounter_end),"The viewport never reveals the locked next checkpoint, even while GO waits for the party")
		battle._move_fighter(player,500)
		check(is_equal_approx(player.x-camera,1220.0),"The right movement stop is at the visible edge rather than an interior air wall")
	battle._start_checkpoint(1)
	battle.state.fighters.resize(1)
	player.x = 1000.0
	battle._move_fighter(player,-100.0)
	check(player.x == 900 and Battle.camera_left(battle.state) == 260,"Cleared scenery stays accessible for backtracking and food")
	player.x = battle.state.stage.encounter_end-60.0
	check(Battle.camera_left(battle.state)+1280 == battle.state.stage.width,"Final checkpoint camera stops exactly at the scene edge")
	check(Wire.valid_snapshot(battle.get_state()),"Camera and gate changes add no incompatible snapshot fields")

func _test_player_recovery() -> void:
	var battle := Battle.new()
	battle.reset("normal",2)
	battle.state.props.clear()
	battle.state.fighters.resize(2)
	var player: Dictionary = battle.state.fighters[0]
	player.x = 500.0
	player.y = 480.0
	var partner: Dictionary = battle.state.fighters[1]
	partner.x = 510.0
	partner.y = 480.0
	var left: Dictionary = battle._make_fighter(1,"soldier",420,480,100)
	var boss: Dictionary = battle._make_fighter(1,"boss",580,480,240)
	boss.stage_boss = true
	boss.action = "boss_sweep"
	boss.invuln = 14
	var outside: Dictionary = battle._make_fighter(1,"soldier",630,480,100)
	var lane: Dictionary = battle._make_fighter(1,"soldier",500,530,100)
	var down: Dictionary = battle._make_fighter(1,"soldier",510,480,100)
	down.action = "down"
	var flying: Dictionary = battle._make_fighter(1,"soldier",520,480,100)
	flying.airborne_lock = true
	flying.z = 15
	var entering: Dictionary = battle._make_fighter(1,"soldier",530,480,100)
	entering.entering = true
	var corpse: Dictionary = battle._make_fighter(1,"soldier",540,480,0)
	corpse.action = "defeated"
	battle.state.fighters.append_array([left,boss,outside,lane,down,flying,entering,corpse])
	player.action = "down"
	for tick in range(Battle.DOWN_TICKS + Battle.RECOVER_TICKS):
		check(not battle._damage(player,20,boss.id,true),"Grounded player recovery cannot be restarted by surrounding enemies")
		battle._tick_fighter(player)
	check(player.action == "idle" and player.invuln == 45 and player.hp == player.max_hp,"Player finishes recovery with a short protected escape window")
	check(left.hp == 98 and boss.hp == 238,"Getup only does two points of damage, including the boss")
	check(left.knockback < 0 and boss.knockback > 0 and boss.action == "hurt","Getup pushes both sides and interrupts a nearby boss attack")
	check(not boss.airborne_lock and boss.cooldown >= 36,"Boss is shoved without another knockdown/getup shock chain")
	check(partner.hp == partner.max_hp and partner.knockback == 0,"Co-op partner is unaffected")
	for excluded in [outside,lane,down,flying,entering,corpse]:
		check(excluded.hp == (0 if excluded == corpse else 100) and excluded.knockback == 0,"Small grounded pulse excludes distant, airborne, prone, entering and dead enemies")
	var pulses: int = battle.state.effects.filter(func(e): return e.type == "slam").size()
	battle._tick_fighter(player)
	check(left.hp == 98 and boss.hp == 238 and battle.state.effects.filter(func(e): return e.type == "slam").size() == pulses,"Only one pulse is emitted per completed recovery")
	check(not battle._damage(player,10,boss.id,false),"Player cannot immediately be hit again after getting up")
	player.action = "recovering"
	player.action_tick = 18
	battle._boss_getup(boss)
	check(player.action == "recovering" and player.action_tick == 18 and not player.airborne_lock,"Boss getup does not restart an already recovering player's knockdown")
	# The synthetic corpse above has max_hp zero; restore a valid health ceiling for the wire check.
	corpse.max_hp = 100
	check(Wire.valid_snapshot(battle.get_state()),"Getup effects and sound events use the existing network schema")
