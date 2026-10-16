extends SceneTree

const Battle = preload("res://core/battle.gd")
const Equipment = preload("res://core/equipment.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0
var records: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func measure(hero: String, weapon: String, treasure: String = "") -> Dictionary:
	var battle := Battle.new()
	battle.reset("normal",1,[hero])
	var player: Dictionary = battle.state.fighters[0]
	if weapon != player.weapon_id: Equipment.equip(player,Equipment.add(player,weapon))
	if treasure != "": Equipment.equip(player,Equipment.add(player,treasure))
	var target := battle._make_fighter(1,"dummy",player.x + (200 if hero == "oichi" else 70),player.y,100000)
	battle.state.fighters = [player,target]
	battle.state.props.clear()
	battle.state.effects.clear()
	var stats := Battle.character_stats(player)
	battle._player_input(player,{"dx":0,"dy":0,"buttons":Battle.HEAVY if hero == "oichi" else Battle.LIGHT},0)
	if hero == "oichi": battle._player_input(player,{"dx":0,"dy":0,"buttons":0},0)
	var damage := 0
	var hit_tick := 0
	var recovery := 0
	for tick in range(1,181):
		battle.state.tick = tick
		battle.state.events.clear()
		if recovery == 0:
			battle._tick_fighter(player)
			if player.action == "idle": recovery = tick
		battle._tick_effects()
		if damage == 0 and target.hp < 100000:
			damage = 100000 - int(target.hp)
			hit_tick = tick
		if damage > 0 and recovery > 0: break
	check(damage > 0 and recovery > 0,"Real attack connects and recovers: " + hero + "/" + weapon)
	check(damage == stats.damage,"Displayed damage equals actual damage: " + hero + "/" + weapon + "/" + treasure)
	check(Wire.valid_snapshot(battle.get_state()),"Balanced loadout remains a valid live state")
	return {"hero":hero,"weapon":weapon,"name":Weapons.item(weapon).name,"tier":Weapons.item(weapon).tier,"treasure":treasure,"damage":damage,"hit_tick":hit_tick,"recovery":recovery,"dps":float(damage)*60/maxi(1,recovery),"reach":stats.reach,"attack_speed":stats.attack_speed,"knockback":stats.knockback,"durability":Weapons.item(weapon).durability,"element":Weapons.item(weapon).element}

func _initialize() -> void:
	var baselines := {}
	for hero in Battle.HEROES:
		var baseline := measure(hero,Weapons.default_for(hero))
		baselines[hero] = baseline
		for id in Weapons.ids_for(hero):
			var result := measure(hero,id)
			records.append(result)
			check(result.damage >= baseline.damage and result.dps >= baseline.dps * 0.98,"Every collectible is at least as effective as its hero's practice gear")
			for charm in Equipment.TREASURES:
				var with_charm := measure(hero,id,charm)
				check(with_charm.damage >= result.damage and with_charm.dps >= result.dps,"Charms never reduce the selected weapon's effective damage")
	check(baselines.tadakatsu.damage >= baselines.nobunaga.damage * 1.5 and baselines.tadakatsu.reach > baselines.nobunaga.reach * 2 and baselines.tadakatsu.recovery > baselines.nobunaga.recovery,"Tadakatsu has high single-hit power and long range, with a slower recovery")
	for hero in Battle.HEROES:
		var high: Array = records.filter(func(row): return row.hero == hero and int(row.tier) == 5)
		var middle: Array = records.filter(func(row): return row.hero == hero and int(row.tier) == 4)
		var strongest := 0.0
		for row in middle: strongest = maxf(strongest,row.dps)
		for row in high: check(row.dps >= strongest * 0.95,"Tier-five weapon does not lose raw DPS to tier-four gear: " + row.weapon)
	var spear := Battle.new()
	spear.reset("normal",1,["tadakatsu"])
	var player: Dictionary = spear.state.fighters[0]
	var practice := Weapons.spear_reach({"kind":"tadakatsu","weapon_id":player.weapon_id,"action":"light","combo":1})
	Equipment.equip(player,Equipment.add(player,"spear_tonbokiri"))
	check(Weapons.spear_reach({"kind":"tadakatsu","weapon_id":player.weapon_id,"action":"light","combo":1}) > practice,"Tonbokiri reaches farther than the practice spear")
	var folder := "res://../artifacts/native-v28"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var json := FileAccess.open(folder.path_join("balance.json"),FileAccess.WRITE)
	json.store_string(JSON.stringify({"checks":checks,"failures":failures,"baselines":baselines,"loadouts":records},"\t"))
	json.close()
	var csv := FileAccess.open(folder.path_join("weapon-balance.csv"),FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["hero","weapon","name","tier","damage","recovery_ticks","dps","reach","attack_speed_percent","knockback","durability","element"]))
	for row in records: csv.store_csv_line(PackedStringArray([row.hero,row.weapon,row.name,str(row.tier),str(row.damage),str(row.recovery),"%.2f" % row.dps,"%.2f" % row.reach,str(row.attack_speed),str(row.knockback),str(row.durability),row.element]))
	csv.close()
	print("BALANCE V28 %s: %d checks, %d failures; %d character/weapon pairs and %d charms each" % ["PASS" if failures == 0 else "FAILED",checks,failures,records.size(),Equipment.TREASURES.size()])
	quit(1 if failures else 0)
