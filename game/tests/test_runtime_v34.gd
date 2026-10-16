extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
const Equipment = preload("res://core/equipment.gd")
const Achievements = preload("res://core/achievements.gd")
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	assert(value, label)

func _initialize() -> void:
	rain_equipment_and_credit()
	campaign_stress()
	print("RUNTIME V34 PASS: %d checks" % checks)
	quit()

func rain_equipment_and_credit() -> void:
	var battle := Battle.new()
	battle.reset("normal",1,["oichi"])
	var player: Dictionary = battle.state.fighters[0]
	battle.state.fighters = [player]
	battle.state.props = []
	player.x = 500.0
	player.y = 500.0
	var charm := Equipment.add(player,"katori")
	check(charm > 0 and Equipment.equip(player,charm),"Equip real charged-attack charm")
	check(is_equal_approx(Equipment.damage_multiplier(player,"charge_rain"),1.1),"Arrow rain receives charged bonus")
	check(is_equal_approx(Equipment.damage_multiplier(player,"heavy"),1.0),"Charged bonus does not leak into normal shots")
	var survivor := battle._make_fighter(1,"soldier",540,500,200)
	survivor.armor = 0
	battle.state.fighters.append(survivor)
	for index in range(5):
		var target := battle._make_fighter(1,"soldier",550+index*20,500,1)
		target.armor = 0
		battle.state.fighters.append(target)
	battle._begin(player,"charge_rain")
	battle._combat_contact_v33(player,"projectile_release")
	check(battle.state.effects.any(func(e): return e.type=="sky_arrow"),"Actual move emits its rising arrow")
	# Isolate the delayed hit from AI movement without bypassing rain effect damage or kill accounting.
	player.action = "idle"
	for tick in range(100):
		battle.state.tick += 1
		battle._tick_effects()
		check(Wire.valid_snapshot(battle.state),"Rain remains valid after shooter returns to idle")
	check(survivor.hp==200-roundi(43*1.1),"Delayed rain impact applies charm exactly once")
	check(int(player.performance.get("charged_kills",0))==5,"Rain kills count as charged attacks")
	check(int(player.performance.get("heavy_kills",0))==0,"Rain kills are not double-classified")
	check(Achievements.earned(player).any(func(rule): return rule[0]=="charge5"),"Five rain kills unlock charged achievement")

func campaign_stress() -> void:
	var ticks := 0
	var hits := 0
	var actions := {}
	for chapter in [1,2]:
		for difficulty in ["normal","hard"]:
			var battle := Battle.new()
			battle.reset_campaign(difficulty,2,["nobunaga","oichi"],chapter)
			for segment in range(battle._campaign.segments.size()):
				battle._enter_segment(segment)
				for tick in range(600):
					var inputs := []
					for slot in range(2):
						var player: Dictionary = battle.state.fighters[slot]
						# Endurance fixture keeps production max HP and attack rules; it does not measure difficulty.
						player.hp = player.max_hp
						var target := {}
						var nearest := INF
						for enemy in battle.state.fighters:
							if enemy.team==0 or enemy.hp<=0 or enemy.get("entering",false): continue
							var distance: float = absf(enemy.x-player.x)+2*absf(enemy.y-player.y)
							if distance<nearest:
								target = enemy
								nearest = distance
						var frame := {"dx":1,"dy":0,"buttons":0}
						if not target.is_empty():
							frame.dx = signi(int(target.x-player.x)) if absf(target.x-player.x)>60 else 0
							frame.dy = signi(int(target.y-player.y)) if absf(target.y-player.y)>12 else 0
						var phase := (tick+slot*47)%240
						if phase<90: frame.buttons = Battle.LIGHT if phase%3==0 else 0
						elif phase<155: frame.buttons = Battle.HEAVY
						elif phase==165: frame.buttons = Battle.JUMP
						elif phase==174: frame.buttons = Battle.HEAVY
						elif phase==200: frame.buttons = Battle.GRAB
						elif phase==220: frame.buttons = Battle.INTERACT
						inputs.append(frame)
					battle.step(inputs)
					ticks += 1
					check(Wire.valid_snapshot(battle.state),"Co-op state chapter %d segment %d %s tick %d" % [chapter,segment,difficulty,tick])
					for event in battle.state.events:
						if event.type=="damage": hits += 1
					for player in battle.state.fighters.slice(0,2):
						actions[player.action] = true
	print("CAMPAIGN STRESS V34: ",JSON.stringify({"ticks":ticks,"damage_events":hits,"actions":actions.keys(),"chapters":[1,2],"difficulties":["normal","hard"],"players":2,"refills_hp":true}))
	check(hits>100 and actions.has("light") and actions.has("heavy") and actions.has("air_heavy"),"Stress fixture exercises actual hits and multiple move types")
