extends SceneTree

const Battle = preload("res://core/battle.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var battle := Battle.new()
	for players in [1,2]:
		battle.reset("normal",players)
		for wave in range(1,4):
			battle.state.fighters = battle.state.fighters.filter(func(f):return f.team == 0)
			battle.state.wave = wave
			battle._spawn_wave()
			check(battle.state.fighters.size()-players == (1 if wave == 3 else (4 if players == 1 else 6)),"Trial waves use the same 50 percent co-op scaling; boss stays unique")
	for players in [1,2]:
		battle.reset_campaign("normal",players,["nobunaga","oichi"])
		for scene in range(7):
			battle._enter_segment(scene)
			for checkpoint in range(2):
				var region: Dictionary = battle._campaign.segments[scene]
				var start: float = 0 if checkpoint == 0 else region.encounters[checkpoint-1].end
				for prop in battle.state.props:
					if prop.get("mandatory",false) and prop.x < start: prop.broken = true
				battle.state.fighters = battle.state.fighters.filter(func(f):return f.team == 0)
				for player in battle.state.fighters: player.x = maxf(180,start+100)
				battle._start_checkpoint(checkpoint)
				for wave in range(1,battle.state.stage.wave_total+1):
					if wave > 1:
						battle.state.fighters = battle.state.fighters.filter(func(f):return f.team == 0)
						battle.state.wave = wave
						battle._spawn_segment_wave()
					var continuous := true
					var solid := true
					for tick in range(1200):
						var pending := false
						for enemy in battle.state.fighters:
							if enemy.team != 1 or not enemy.get("entering",false): continue
							pending = true
							var before := Vector2(enemy.x,enemy.y)
							battle._enemy_input(enemy)
							if before.distance_to(Vector2(enemy.x,enemy.y)) > 3.16: continuous = false
							for prop in battle.state.props:
								if not prop.broken and absf(enemy.x-prop.x) < prop.width*0.5+19.9 and absf(enemy.y-prop.y) < prop.depth*0.5+11.9:
									if solid: print("COLLISION DEBUG ",scene,"/",checkpoint," ",enemy.kind," ",Vector2(enemy.x,enemy.y)," prop=",prop)
									solid = false
						if not pending: break
					var label := "Scene %d checkpoint %d wave %d" % [scene,checkpoint,wave]
					check(continuous,label+": entry moves smoothly without arrival teleport")
					check(solid,label+": entry respects solid scenery")
					check(not battle.state.fighters.any(func(f):return f.get("entering",false)),label+": every enemy reaches the arena")
					if not solid or battle.state.fighters.any(func(f):return f.get("entering",false)):
						print("ENTRY DEBUG ",label," ",JSON.stringify(battle.state.fighters.filter(func(f):return f.get("entering",false)).map(func(f):return {"kind":f.kind,"x":f.x,"y":f.y,"goal":f.entry_x})))
		_test_short_checkpoint_clear(players)
	for hero in Battle.PLAYABLE_HEROES:
		for diagonal in [false,true]:
			battle.reset("normal",1,[hero])
			var player: Dictionary = battle.state.fighters[0]
			player.x = 300
			player.y = 550 if diagonal else 400
			var boss: Dictionary = battle._make_fighter(1,"boss",1000,400,500)
			battle.state.props.clear()
			battle.state.fighters = [player,boss]
			var before := Vector2(boss.x,boss.y)
			battle._enemy_input(boss)
			var actual := Vector2(boss.x,boss.y)-before
			var direction := Vector2(-1,1 if diagonal else 0).normalized()
			var expected := Vector2(direction.x*3.5,direction.y*2.65)*float(Battle.HERO_PROFILES[hero].move_speed)*0.8
			check(actual.distance_to(expected)<0.001,"Boss follows "+hero+" at 80 percent walk speed, diagonal="+str(diagonal))
	print("STAGE MOVEMENT V19 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)

func _test_short_checkpoint_clear(players: int) -> void:
	var battle := Battle.new()
	battle.reset_campaign("normal",players,["nobunaga","oichi"])
	battle._enter_segment(1)
	# Match the reported cleared foreground; the inaccessible future barricades stay intact.
	for prop in battle.state.props:
		if prop.x < battle.state.stage.encounter_end: prop.broken = true
	for tick in range(1800):
		for fighter in battle.state.fighters:
			if fighter.team == 0: fighter.invuln = 6000
			elif fighter.hp > 0 and not fighter.get("entering",false):
				battle._damage(fighter,10000,battle.state.fighters[0].id,false,true,true)
		battle.step([])
		if battle.state.stage.go: break
	check(battle.state.stage.go,"Ridge first checkpoint clears after defeating only enemies that actually enter, players="+str(players))
	check(battle.state.props.any(func(p):return p.get("mandatory",false) and not p.broken),"Future barricades remain intact during first-checkpoint clearance")
	for tick in range(600):
		battle.step([{"dx":1},{"dx":1}])
		if battle.state.stage.checkpoint == 1: break
	check(battle.state.stage.checkpoint == 1,"Cleared party can walk into the second checkpoint, players="+str(players))
