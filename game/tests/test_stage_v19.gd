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
	_test_route()
	_test_coop_gate()
	_test_scaled_waves_and_entries()
	_test_reinforcements()
	_test_queue()
	_test_wire()
	print("STAGE V19 %s: %d checks, %d failures. Deterministic state-machine fixtures clear enemies manually; these are not attack-driven playthroughs." % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)

func _living_enemies(battle) -> Array:
	return battle.state.fighters.filter(func(f):return f.team == 1 and f.hp > 0)

func _kill_wave(battle) -> void:
	for fighter in battle.state.fighters:
		if fighter.team == 1:
			fighter.hp = 0
			fighter.action = "defeated"
			fighter.damage_tick = battle.state.tick

func _ticks(battle, count: int) -> void:
	for tick in range(count):
		battle.state.tick += 1
		battle._tick_segment()

func _break_current_gate(battle) -> void:
	for prop in battle.state.props:
		if prop.get("mandatory",false) and prop.x < battle.state.stage.encounter_end:
			battle._damage_prop(prop,10000,battle.state.fighters[0].id)

func _entries(battle, label: String) -> void:
	var camera: float = Battle.camera_left(battle.state)
	for enemy in _living_enemies(battle):
		check(enemy.entering and (enemy.x <= camera-240 or enemy.x >= camera+1280+240),label+": enemies begin >=240px beyond the current viewport")
		check(enemy.entry_x >= 80.0 and enemy.entry_x <= battle.state.stage.encounter_end-60.0,label+": entry destination stays inside the accessible scene corridor")

func _test_route() -> void:
	var battle := Battle.new()
	battle.reset_campaign()
	check(battle._campaign.segments.size() == 7 and battle.state.stage.total == 7,"Seven separate scenes")
	var wave_count := 0
	var checkpoint_count := 0
	var foes := 0
	var bosses := []
	for scene in range(7):
		check(battle.state.stage.index == scene,"Expected scene order")
		check(battle.state.stage.width >= 3200 and battle.state.stage.width <= 3800,"Long scene width")
		for checkpoint in range(2):
			checkpoint_count += 1
			check(battle.state.stage.checkpoint == checkpoint and battle.state.stage.checkpoint_total == 2,"Two combat checkpoints per scene")
			var waves: int = battle.state.stage.wave_total
			check(waves in [2,3],"Each checkpoint has two or three waves")
			for wave in range(1,waves+1):
				wave_count += 1
				check(battle.state.wave == wave and not battle.state.stage.go,"GO stays closed through scheduled waves")
				check(Wire.valid_snapshot(battle.get_state()),"Every route wave sends a valid snapshot")
				foes += _living_enemies(battle).size()
				for fighter in _living_enemies(battle):
					if fighter.kind == "boss": bosses.append([scene,checkpoint,str(fighter.display_name)])
				_entries(battle,"Route wave")
				_kill_wave(battle)
				_ticks(battle,76 if wave < waves else 46)
			var blockers: Array = battle.state.props.filter(func(p):return p.get("mandatory",false) and not p.broken and p.x < battle.state.stage.encounter_end)
			if not blockers.is_empty():
				check(not battle.state.stage.go,"Current checkpoint's mandatory props block GO")
				_break_current_gate(battle)
				_ticks(battle,46)
			if scene == 6 and checkpoint == 1:
				check(battle.state.phase == "won" and not battle.state.stage.go,"Final checkpoint alone ends the level")
				continue
			check(battle.state.stage.go,"Cleared checkpoint opens GO")
			_ticks(battle,10)
			check(battle.state.stage.index == scene and battle.state.stage.checkpoint == checkpoint,"GO waits for players to advance")
			var player: Dictionary = battle.state.fighters[0]
			player.hp = 81
			player.weapon = 1
			player.armor = 1
			player.rage = 37
			player.x = battle.state.stage.encounter_end-100
			var exit_x: float = player.x
			battle.state.drops.append({"id":900000+scene*2+checkpoint,"kind":"food","food_id":"rice","heal":35,"x":exit_x-50,"y":570.0})
			var saved_drop: int = battle.state.drops[-1].id
			_ticks(battle,1)
			player = battle.state.fighters[0]
			check(player.hp == 81 and player.weapon == 1 and player.armor == 1 and player.rage == 37,"Health, equipment and rage persist")
			if checkpoint == 0:
				check(battle.state.stage.index == scene and battle.state.stage.checkpoint == 1 and player.x == exit_x,"First GO continues the same scene without teleporting the player")
				check(battle.state.drops.any(func(drop):return drop.id == saved_drop),"Same-scene checkpoint preserves existing drops")
			else:
				check(battle.state.stage.index == scene+1 and battle.state.stage.checkpoint == 0 and player.x == 180,"Final checkpoint GO changes the backdrop and entrance")
				check(battle.state.drops.is_empty(),"Changing scenes clears the old scene's drops")
	check(checkpoint_count == 14 and wave_count == 31,"Fourteen checkpoints and thirty-one scheduled waves")
	check(foes == 108,"Solo scheduled enemies total 108 before timed reinforcements")
	check(bosses == [[1,1,"瀨名氏俊"],[3,1,"鵜殿長照"],[5,1,"井伊直盛"],[6,1,"松井宗信"]],"Three officers and the final commander keep their intended checkpoints")

func _test_coop_gate() -> void:
	var battle := Battle.new()
	battle.reset_campaign("normal",2)
	battle._enter_segment(1)
	battle.state.wave = battle.state.stage.wave_total
	_kill_wave(battle)
	_ticks(battle,46)
	check(battle.state.stage.go and battle.state.props.any(func(p):return p.get("mandatory",false) and not p.broken),"Future checkpoint barricades do not block the current GO")
	var first: Dictionary = battle.state.fighters[0]
	var second: Dictionary = battle.state.fighters[1]
	first.x = battle.state.stage.encounter_end-100
	second.x = first.x-200
	_ticks(battle,1)
	check(battle.state.stage.checkpoint == 0,"One living partner cannot abandon the other")
	second.x = first.x-20
	_ticks(battle,1)
	check(battle.state.stage.checkpoint == 1,"Both living partners cross GO together")
	second.hp = 0
	second.action = "defeated"
	battle.state.wave = battle.state.stage.wave_total
	_kill_wave(battle)
	_break_current_gate(battle)
	_ticks(battle,46)
	first.x = battle.state.stage.encounter_end-100
	_ticks(battle,1)
	check(battle.state.stage.index == 2 and battle.state.fighters[1].hp == 0,"A defeated partner does not block the gate or revive during scene change")

func _test_scaled_waves_and_entries() -> void:
	for count in [1,2]:
		var battle := Battle.new()
		battle.reset_campaign("normal",count)
		var total := 0
		for scene in range(7):
			battle._enter_segment(scene)
			for checkpoint in range(2):
				battle.state.fighters = battle.state.fighters.filter(func(f):return f.team == 0)
				var spec: Dictionary = battle._campaign.segments[scene].encounters[checkpoint]
				var start := 0.0 if checkpoint == 0 else float(battle._campaign.segments[scene].encounters[checkpoint-1].end)
				for player in battle.state.fighters: player.x = start+720.0+player.player_index*55.0
				battle._start_checkpoint(checkpoint)
				for index in range(spec.waves.size()):
					battle.state.fighters = battle.state.fighters.filter(func(f):return f.team == 0)
					battle.state.wave = index+1
					battle._spawn_segment_wave()
					var base: Array = spec.waves[index]
					var ordinary: int = base.filter(func(kind):return kind != "boss").size()
					var expected := ceili(ordinary*1.5) if count == 2 else ordinary
					var enemies := _living_enemies(battle)
					check(enemies.filter(func(f):return f.kind != "boss").size() == expected,"Every co-op grunt wave uses ceil(solo * 1.5)")
					check(enemies.filter(func(f):return f.kind == "boss").size() == base.count("boss"),"Co-op never duplicates a unique boss")
					total += enemies.size()
					_entries(battle,"Scaled wave")
		check(total == (108 if count == 1 else 165),"Scheduled enemy budget matches solo / co-op mode")

func _boss_fixture(players: int):
	var battle := Battle.new()
	battle.reset_campaign("normal",players)
	battle._enter_segment(6)
	for player in battle.state.fighters:
		if player.team == 0: player.x = 2200.0+player.player_index*55.0
	battle._start_checkpoint(1)
	battle.state.fighters = battle.state.fighters.filter(func(f):return f.team == 0)
	battle.state.wave = 2
	battle._spawn_segment_wave()
	return battle

func _test_reinforcements() -> void:
	for players in [1,2]:
		var battle = _boss_fixture(players)
		var boss: Dictionary = _living_enemies(battle)[0]
		var due: int = battle.state.stage.next_reinforce_tick
		var amount := 4 if players == 1 else 6
		battle.state.tick = due-1
		battle._tick_segment()
		check(_living_enemies(battle).size() == 1,"No reinforcements before thirty seconds")
		battle.state.tick = due
		battle._tick_segment()
		check(_living_enemies(battle).size() == 1+amount and battle.state.stage.reinforcement_calls == 1,"Thirty seconds summons four / six ordinary soldiers")
		_entries(battle,"First boss reinforcement")
		battle.state.tick = due+1800
		battle._tick_segment()
		check(_living_enemies(battle).size() == 1+amount*2 and battle.state.stage.reinforcement_calls == 2,"A living final boss summons repeatedly every thirty seconds")
		check(_living_enemies(battle).filter(func(f):return f.kind == "boss").size() == 1,"Repeated reinforcements do not duplicate the boss")
		boss.hp = 0
		boss.action = "defeated"
		boss.damage_tick = battle.state.tick
		_ticks(battle,1)
		var survivors: int = _living_enemies(battle).size()
		battle.state.tick += 3600
		battle._tick_segment()
		check(_living_enemies(battle).size() == survivors and battle.state.stage.next_reinforce_tick == -1 and battle.state.stage.reinforcement_queue == 0,"Boss death stops the timer and clears pending calls")

func _test_queue() -> void:
	var battle = _boss_fixture(2)
	while battle.state.fighters.size() < 49:
		battle.state.fighters.append(battle._make_fighter(1,"soldier",100,450,50))
	battle.state.tick = battle.state.stage.next_reinforce_tick
	battle._tick_segment()
	check(battle.state.fighters.size() == 49 and battle.state.stage.reinforcement_queue == 1,"More than 48 actors queues a reinforcement call")
	for fighter in battle.state.fighters:
		if fighter.team == 1 and not fighter.get("stage_boss",false):
			fighter.hp = 0
			fighter.damage_tick = battle.state.tick-300
	_ticks(battle,1)
	check(battle.state.fighters.size() == 9 and battle.state.stage.reinforcement_queue == 0,"Clearing space admits the queued six-person co-op reinforcement")
	check(Wire.valid_snapshot(battle.get_state()),"A released reinforcement queue remains a valid network snapshot")

func _test_wire() -> void:
	var battle := Battle.new()
	battle.reset_campaign()
	var valid: Dictionary = battle.get_state()
	check(Wire.valid_snapshot(valid),"Baseline v19 snapshot is accepted")
	for pair in [["index",7],["width",INF],["width",3199],["checkpoint",2],["checkpoint_total",0],["encounter_start",-1],["encounter_end",900],["next_reinforce_tick",-2],["reinforcement_queue",-1],["reinforcement_calls",1.5],["phase","unknown"],["go",true]]:
		var invalid := valid.duplicate(true)
		invalid.stage[pair[0]] = pair[1]
		check(not Wire.valid_snapshot(invalid),"Reject malformed checkpoint snapshot field "+str(pair[0]))
	for pair in [["entering",1],["entry_x",INF]]:
		var invalid := valid.duplicate(true)
		invalid.fighters[1][pair[0]] = pair[1]
		check(not Wire.valid_snapshot(invalid),"Reject malformed entry field "+str(pair[0]))
