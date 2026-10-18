extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func food(sim) -> Array:
	return sim.state.drops.filter(func(d): return d.kind == "food")

func kill(sim, player: Dictionary) -> void:
	var enemies: Array = sim.state.fighters.filter(func(f): return f.team == 1 and f.hp > 0)
	var target: Dictionary
	if enemies.is_empty():
		target = sim._make_fighter(1,"soldier",780,520,50)
		sim.state.fighters.append(target)
	else: target = enemies[0]
	target.entering = false
	target.action = "idle"
	target.x = clampf(player.x+100,sim._left_edge()+60,sim._right_edge()-60)
	target.y = 520
	check(sim._damage(target,10000,player.id,false,false,true),"actual kill accepted")
	check(target.hp == 0,"enemy killed")

func break_prop(sim, player: Dictionary, configured_food: bool = false) -> void:
	var prop := {"id":900000+checks,"kind":"crate","x":player.x+80,"y":530.0,"hp":60,"max_hp":60,"broken":false,"drop":"food" if configured_food else "","food_id":"fish"}
	sim._damage_prop(prop,999,player.id)
	check(prop.broken,"actual prop broken")
	sim._damage_prop(prop,999,player.id)

func hurt(sim, player: Dictionary) -> void:
	player.hp = 60
	player.max_hp = 120
	player.action = "idle"
	player.invuln = 0
	sim._arm_food_drop()
	check(player.food_state == "ready","exactly 50 percent does not trigger")
	check(sim._damage(player,1,0,false,false,true),"real damage crosses below half")
	check(player.hp == 59 and player.food_state == "pending","crossing latches pending food")

func routes() -> void:
	for count in [1,2]:
		for chapter in range(1,5):
			var sim := Battle.new()
			sim.reset_campaign("normal",count,["nobunaga","nobunaga"],chapter)
			var nodes := 0
			for section in sim._campaign.segments.size():
				sim._enter_segment(section)
				for checkpoint in sim._campaign.segments[section].encounters.size():
					for f in sim.state.fighters:
						if f.team == 0: f.hp = f.max_hp
					sim._start_checkpoint(checkpoint)
					sim.state.intro.clear()
					sim.state.events.clear()
					sim.state.effects.clear()
					var party: Array = sim.state.fighters.filter(func(f): return f.team == 0)
					var before: int = food(sim).size()
					kill(sim,party[0])
					break_prop(sim,party[0],true)
					check(food(sim).size() == before,"healthy kills, bosses and food containers never bypass gate")
					for index in party.size():
						var player: Dictionary = party[index]
						hurt(sim,player)
						check(food(sim).size() == before+index,"damage alone does not drop food")
						if index == 0 and count == 2:
							kill(sim,party[1])
							check(food(sim).size() == before and party[0].food_state == "pending","healthy partner cannot spend pending quota")
						player.hp = player.max_hp
						if index == 0: kill(sim,player)
						else: break_prop(sim,player)
						check(food(sim).size() == before+index+1 and player.food_state == "spent","next credited kill or any break yields exactly one even after healing")
						player.hp = 59
						sim._arm_food_drop()
						kill(sim,player)
						break_prop(sim,player,true)
						check(food(sim).size() == before+index+1,"no repeat food after another low-health crossing or break")
					if sim.state.has("encounter"): Battle.Stage03Encounter.tick(sim)
					check(Wire.valid_snapshot(sim.get_state()),"chapter node snapshot and per-player quota validate")
					nodes += 1
			check(nodes == [14,12,4,13][chapter-1],"every current checkpoint tested")

func boundaries() -> void:
	var sim := Battle.new()
	sim.reset_campaign("normal",2,["nobunaga","oichi"],4)
	var party: Array = sim.state.fighters.filter(func(f):return f.team == 0)
	for p in party: hurt(sim,p)
	kill(sim,party[0]);kill(sim,party[1])
	check(food(sim).size() == 2,"simultaneous pending players each get one")
	var bad := sim.get_state()
	bad.fighters[0].food_state = "again"
	check(not Wire.valid_snapshot(bad),"invalid food state rejected")
	party[0].lives = 2;party[0].hp = 0;party[0].respawn_ticks = 1
	sim._tick_respawn(party[0])
	check(sim.state.fighters[0].food_state == "spent","respawn cannot reset quota")
	sim.state.fighters[0].hp = 30
	sim._start_checkpoint(1)
	check(sim.state.fighters[0].food_state == "pending","entering new node already below half arms new quota")
	# Ordinary loot cannot use the slots needed by both players in later checkpoints.
	sim.state.drops.clear()
	for i in 56: check(sim._add_drop("talisman",500,500),"ordinary loot fits")
	check(not sim._add_drop("talisman",500,500),"food slots reserved")
	kill(sim,sim.state.fighters[0])
	check(food(sim).size() == 1,"guaranteed food survives normal loot saturation")

func _initialize() -> void:
	routes()
	boundaries()
	print("CAMPAIGN FOOD PASS: %d checks; all 43 nodes solo/coop, strict threshold, per-player one-shot, credited kills/breaks, reset and wire" % checks)
	quit()
