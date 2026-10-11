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

func arena(kind: String = "soldier"):
	var battle := Battle.new()
	battle.reset_training("nobunaga")
	battle.state.props = []
	battle.state.effects = []
	battle.state.fighters.resize(1)
	battle.state.fighters.append(battle._make_fighter(1,kind,580,480,500))
	return battle

func _initialize() -> void:
	for kind in ["soldier","boss"]:
		for action in ["down","recovering"]:
			var battle = arena(kind)
			var target: Dictionary = battle.state.fighters[1]
			target.action = action
			target.action_tick = 8
			for reaction in [false,true]:
				for bypass in [false,true]:
					check(not battle._damage(target,45,battle.state.fighters[0].id,true,reaction,bypass,true),"No downed damage even from status or bypass: "+kind+action)
			check(target.hp == 500 and target.action == action and target.action_tick == 8,"No hit reaction or recovery reset")
			var player: Dictionary = battle.state.fighters[0]
			player.action = "heavy"
			player.rage = 0
			battle._melee(player,160,60,60,true,60,true,false,18,"ice")
			check(target.hp == 500 and target.freeze == 0 and target.poison == 0 and not target.airborne_lock,"Ignored melee grants no element, poison or relaunch")
			check(player.rage == 0,"Ignored hit grants no extra rage")
			target.burn = 120
			target.burn_tick = 29
			target.poison = 120
			target.poison_tick = 29
			battle._tick_fighter(target)
			check(target.hp == 500 and target.action_tick == 9,"Existing DOT ticks do not damage or stall downed recovery")
	_test_arrow_passes()
	_test_getup(false)
	_test_getup(true)
	_test_ordinary_recovery()
	print("KNOCKDOWN V18 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)

func _test_arrow_passes() -> void:
	var battle = arena()
	var player: Dictionary = battle.state.fighters[0]
	player.kind = "oichi"
	player.action = "charged"
	var down: Dictionary = battle.state.fighters[1]
	down.x = 580.0
	down.action = "down"
	var standing: Dictionary = battle._make_fighter(1,"soldier",680,480,500)
	battle.state.fighters.append(standing)
	battle._projectile(player,48,0,false,"arrow",900,0,"ice",false,{"piercing":false,"burst_radius":100.0,"burst_damage":6})
	for tick in range(15): battle._tick_effects()
	check(down.hp == 500 and down.freeze == 0 and down.action == "down","Arrow and explosion ignore prone enemy")
	check(standing.hp < 500 and standing.freeze > 0,"Arrow passes prone enemy and bursts on standing target")
	check(battle.state.effects.any(func(e): return e.type == "ice_hit" and e.get("burst",false) and e.x == standing.x),"Burst origin is the standing enemy")
	check(Wire.valid_snapshot(battle.get_state()),"New behavior keeps snapshot valid")

func _test_getup(final: bool) -> void:
	var battle := Battle.new()
	battle.reset("normal",2)
	battle.state.fighters.resize(2)
	battle.state.props = []
	battle.state.effects = []
	var boss: Dictionary = battle._make_fighter(1,"boss",580,480,500)
	battle.state.fighters.append(boss)
	boss.stage_boss = final
	boss.action = "recovering"
	boss.action_tick = Battle.RECOVER_TICKS - 1
	var left: Dictionary = battle.state.fighters[0]
	left.x = boss.x - 80.0
	left.y = 480.0
	left.action = "light"
	var right: Dictionary = battle.state.fighters[1]
	right.x = boss.x + 80.0
	right.y = 480.0
	var outside: Dictionary = battle._make_fighter(0,"tadakatsu",boss.x+160,480,120)
	var lane: Dictionary = battle._make_fighter(0,"nobunaga",boss.x,550,120)
	var jumping: Dictionary = battle._make_fighter(0,"nobunaga",boss.x+30,480,120)
	jumping.z = 60.0
	var ultimate: Dictionary = battle._make_fighter(0,"nobunaga",boss.x-40,480,120)
	ultimate.action = "special"
	battle.state.fighters.append_array([outside,lane,jumping,ultimate])
	var before_hp := [left.hp,right.hp]
	battle._tick_fighter(boss)
	check(boss.action == "idle" and boss.invuln == 30 and boss.cooldown == 36,"Both boss ranks get a protected recovery window")
	check(left.airborne_lock and left.knockback < 0 and right.airborne_lock and right.knockback > 0,"Getup throws both nearby players outward")
	check(left.hp == before_hp[0] and right.hp == before_hp[1],"Getup is spacing, not extra unavoidable damage")
	check(not outside.airborne_lock and not lane.airborne_lock,"Getup has a limited elliptical ground range")
	check(not jumping.airborne_lock and ultimate.action == "special","Jumping and ultimate remain valid escapes")
	check(not battle._damage(boss,10,left.id,false),"Cannot immediately knock boss down again on its first standing tick")
	var slam_count: int = battle.state.effects.filter(func(e): return e.type == "slam").size()
	battle._tick_fighter(boss)
	check(battle.state.effects.filter(func(e): return e.type == "slam").size() == slam_count,"One pulse per completed getup")

func _test_ordinary_recovery() -> void:
	var battle = arena()
	var target: Dictionary = battle.state.fighters[1]
	target.action = "down"
	for tick in range(Battle.DOWN_TICKS + Battle.RECOVER_TICKS):
		battle._damage(target,10,battle.state.fighters[0].id,false)
		battle._tick_fighter(target)
	check(target.action == "idle" and target.hp == 500,"Repeated light hits cannot delay the complete down/recovery cycle")
	check(not battle.state.fighters[0].airborne_lock,"Ordinary soldiers do not gain boss getup attack")
	check(battle._damage(target,10,battle.state.fighters[0].id,false),"Standing enemy becomes hittable again")
	target.invuln = 0
	check(battle._damage(target,20,battle.state.fighters[0].id,true),"The hit that first knocks down still does damage")
	battle._launch(target,1)
	check(target.airborne_lock,"Legal knockdown hit can still launch the enemy")
	target.invuln = 0
	check(battle._damage(target,10,battle.state.fighters[0].id,false),"Airborne juggling is unchanged until enemy lands")
