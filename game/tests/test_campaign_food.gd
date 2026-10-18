extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0

class FoodBattle extends Battle:
	var food_roll := 0
	func _loot_roll(limit: int) -> int:
		return food_roll if limit == 100 else limit - 1

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func food(sim) -> Array:
	return sim.state.drops.filter(func(d): return d.kind == "food")

func kill(sim, player: Dictionary) -> void:
	var target: Dictionary = sim._make_fighter(1,"soldier",player.x+100,520,50)
	sim.state.fighters.append(target)
	check(sim._damage(target,10000,player.id,false,false,true),"actual kill accepted")
	check(target.hp == 0,"enemy killed")
	sim.state.fighters.erase(target)

func break_prop(sim, player: Dictionary) -> void:
	var prop := {"id":900000+checks,"kind":"crate","x":player.x+80,"y":530.0,"hp":60,"max_hp":60,"broken":false,"drop":"food","food_id":"fish"}
	sim._damage_prop(prop,999,player.id)
	check(prop.broken,"actual prop broken")
	sim._damage_prop(prop,999,player.id)

func routes() -> void:
	for count in [1,2]:
		for chapter in range(1,6):
			var sim := FoodBattle.new()
			sim.reset_campaign("normal",count,["nobunaga","nobunaga"],chapter)
			var nodes := 0
			for section in sim._campaign.segments.size():
				sim._enter_segment(section)
				for checkpoint in sim._campaign.segments[section].encounters.size():
					for f in sim.state.fighters:
						if f.team == 0: f.hp = f.max_hp
					sim._start_checkpoint(checkpoint)
					sim.state.intro.clear();sim.state.events.clear();sim.state.effects.clear()
					var party: Array = sim.state.fighters.filter(func(f): return f.team == 0)
					var before: int = food(sim).size()
					kill(sim,party[0]);break_prop(sim,party[0])
					check(food(sim).size() == before,"healthy kills and breaks do not drop food")
					for index in party.size():
						var player: Dictionary = party[index]
						before = food(sim).size()
						player.hp = player.max_hp / 2
						kill(sim,player)
						check(food(sim).size() == before,"exactly half HP is ineligible")
						player.hp -= 1
						if count == 2:
							kill(sim,party[1-index])
							check(food(sim).size() == before,"healthy partner cannot use another player's low HP")
						for roll in [19,20,0,99,0]:
							sim.food_roll = roll
							var expected: int = food(sim).size() + (1 if roll < 20 else 0)
							kill(sim,player)
							check(food(sim).size() == expected,"independent twenty-percent roll repeats in the same node")
						before = food(sim).size()
						player.hp = player.max_hp
						sim.food_roll = 0
						kill(sim,player);break_prop(sim,player)
						check(food(sim).size() == before,"healing cancels eligibility immediately")
						player.hp = player.max_hp / 2 - 1
						break_prop(sim,player);break_prop(sim,player)
						check(food(sim).size() == before+2,"low-HP breaks have no one-shot quota and cannot duplicate a broken prop")
						player.hp = player.max_hp
					for drop in food(sim): check(drop.heal == 80,"campaign food recovery doubles")
					if sim.state.has("encounter"): Battle.Stage03Encounter.tick(sim)
					check(Wire.valid_snapshot(sim.get_state()),"all five chapter snapshots validate without food quotas")
					nodes += 1
			check(nodes == [14,12,4,13,12][chapter-1],"every current checkpoint covered")

func boundaries() -> void:
	for difficulty in Battle.DIFFICULTIES:
		for hero in Battle.PLAYABLE_HEROES:
			var sim := Battle.new()
			sim.reset(difficulty,1,[hero])
			var player: Dictionary = sim.state.fighters[0]
			check(player.max_hp == roundi(Battle.DIFFICULTIES[difficulty].player_hp * 1.5),"all heroes gain fifty percent HP at every difficulty")
			check(Battle.character_stats(player,difficulty).hp == player.max_hp,"equipment panel matches actual HP")
	for spec in Battle.Equipment.FOODS.values(): check(spec.heal == 80,"all stored foods double recovery")
	var sim := FoodBattle.new()
	sim.reset_campaign("normal",1,["nobunaga"],5)
	var player: Dictionary = sim.state.fighters[0]
	sim.state.drops.clear()
	for i in 56: check(sim._add_drop("talisman",500,500),"ordinary loot fits")
	check(not sim._add_drop("talisman",500,500),"food slots reserved")
	player.hp = 1
	kill(sim,player)
	check(food(sim).size() == 1,"food can drop despite ordinary loot saturation")
	player.hp = 0
	kill(sim,player)
	check(food(sim).size() == 1,"defeated player cannot earn low-health food")

func _initialize() -> void:
	routes()
	boundaries()
	print("CAMPAIGN FOOD PASS: %d checks; five chapters solo/coop, strict threshold, independent 20 percent rolls, no per-node quota, doubled recovery and player HP" % checks)
	quit()
