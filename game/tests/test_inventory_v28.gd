extends SceneTree

const Battle = preload("res://core/battle.gd")
const Equipment = preload("res://core/equipment.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Players = preload("res://core/player_store.gd")
const Profile = preload("res://core/save_profile.gd")
const Achievements = preload("res://core/achievements.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var battle := Battle.new()
	var player: Dictionary = battle.state.fighters[0]
	player.bag_only = false
	check(Weapons.ITEMS.size() == 57,"51 collectible weapons plus six practice weapons")
	for hero in Battle.HEROES:
		var id := Weapons.default_for(hero)
		check(Weapons.compatible(hero,id) and int(Weapons.item(id).tier) == 0,"Each hero starts with compatible practice gear")
	check(Weapons.default_for("tadakatsu") != "spear_tonbokiri","Tonbokiri is collectible, never the practice spear")
	for id in Weapons.ITEMS:
		var spec: Dictionary = Weapons.item(id)
		check(spec.attack_speed >= 0.5 and spec.attack_speed <= 2 and spec.durability > 0 and spec.has("special"),"Weapon has complete parameters: " + id)
	var first := Equipment.add(player,"sword_heshikiri")
	var second := Equipment.add(player,"sword_heshikiri")
	check(first != second and Equipment.equip(player,first),"Duplicate blades are independent instances")
	Equipment.instance(player,first).durability = 2
	var target := battle._make_fighter(1,"soldier",player.x+80,player.y,100)
	battle.state.fighters.append(target)
	var previous: int = target.hp
	battle._damage(target,10,player.id,false,true,true)
	check(target.hp < previous and Equipment.instance(player,first).durability == 1,"Accepted damage consumes one durability")
	target.invuln = 100
	battle._damage(target,10,player.id,false)
	check(Equipment.instance(player,first).durability == 1,"Rejected hit consumes no durability")
	target.invuln = 0
	battle._damage(target,10,player.id,false,true,true)
	check(Equipment.instance(player,first).is_empty() and int(player.weapon_uid) == 0 and player.weapon_id == "practice_nobunaga","Exhausted blade returns to infinite baseline; spare remains unequipped")
	check(Equipment.instance(player,second).durability == Weapons.item("sword_heshikiri").durability,"Breaking one duplicate does not affect another")
	check(Equipment.valid(player),"Inventory stays valid after breakage")
	Equipment.equip(player,second)
	var source_durability: int = Equipment.instance(player,second).durability
	var spare_uid: int = Equipment.add(player,"sword_nagamitsu")
	var spare_durability: int = Equipment.instance(player,spare_uid).durability
	battle._apply_element(target,"fire",player.id,second,1)
	Equipment.equip(player,spare_uid)
	target.burn_tick = 29
	battle._tick_fighter(target)
	check(Equipment.instance(player,second).durability == source_durability-1 and Equipment.instance(player,spare_uid).durability == spare_durability,"Burn damage wears its original weapon after switching, without consuming the newly equipped one")
	Equipment.equip(player,second)
	check(Equipment.sell(player,second) == 0,"Cannot sell currently equipped gear")
	var sale := Equipment.add(player,"sword_nagamitsu")
	Equipment.instance(player,sale).durability = 1
	var price := Equipment.sale_price(Equipment.instance(player,sale))
	check(Equipment.sell(player,sale) == price and player.gold == price and Equipment.instance(player,sale).is_empty(),"Selling credits exactly one instance at its wear-adjusted price")
	for id in Equipment.TREASURES:
		var uid := Equipment.add(player,id)
		Equipment.equip(player,uid)
		var spec: Dictionary = Equipment.TREASURES[id]
		var before := int(Equipment.instance(player,uid).durability)
		var absorbed := Equipment.absorb(player,20)
		check(absorbed > 0 and absorbed <= 20 and int(Equipment.instance(player,uid).durability) == before-absorbed,"Both charm types consume absorbed damage: " + id)
		if spec.mode == "percent":
			check(Equipment.reduction(player) < spec.reduction,"Percent reduction tracks current durability")
			Equipment.instance(player,uid).durability = int(spec.durability)/5 + 1
			Equipment.absorb(player,100)
		else: Equipment.absorb(player,1000)
		check(Equipment.instance(player,uid).is_empty() and player.shield_kind == "","Exhausted charm disappears: " + id)
	var snapshot: Dictionary = player.duplicate(true)
	var invalid: Dictionary = snapshot.duplicate(true)
	invalid.inventory.append(invalid.inventory[0].duplicate())
	check(not Equipment.valid(invalid),"Duplicate instance IDs rejected at save/network boundary")
	invalid = snapshot.duplicate(true)
	invalid.inventory[0].durability = -1
	check(not Equipment.valid(invalid),"Invalid durability rejected")
	var save_dir := "user://inventory-v28-%d" % Time.get_ticks_usec()
	var legacy_path := save_dir + "-legacy.json"
	var legacy := Profile.new(legacy_path)
	legacy.data.characters["0:nobunaga"] = {"slot":0,"hero":"nobunaga","score":4321,"max_hp_bonus":7,"weapon_id":"sword_heshikiri","owned_weapons":["sword_uchigatana","sword_heshikiri"]}
	legacy.data.characters["1:nobunaga"] = {"slot":1,"hero":"nobunaga","score":8765,"max_hp_bonus":0,"weapon_id":"sword_uchigatana","owned_weapons":["sword_uchigatana"]}
	check(legacy.save() == OK,"Legacy fixture saved")
	var legacy_bytes := FileAccess.get_file_as_string(legacy_path)
	var players := Players.new(save_dir,legacy_path)
	check(players.character(0,"nobunaga").score == 4321 and players.character(1,"nobunaga").score == 8765,"Legacy 1P/2P migrates to independent players")
	check(players.save() == OK and FileAccess.get_file_as_string(legacy_path) == legacy_bytes,"Migration preserves original legacy file")
	var id := players.add_player("新玩家")
	check(id != "" and FileAccess.file_exists(save_dir.path_join(id + ".json")),"Adding a player creates a separate local file")
	check(players.add_player("新玩家") == "" and players.add_player("  ") == "","Blank and duplicate names rejected")
	check(players.select_player(0,id) == OK and players.character(0,"nobunaga").score == 0,"New player has fresh character progress")
	player.score = 99
	player.player_index = 0
	players.capture(player)
	check(players.save() == OK,"Instances, wear and money saved")
	var loaded := Players.new(save_dir,legacy_path)
	check(loaded.selected[0] == id and loaded.character(0,"nobunaga").inventory == player.inventory and loaded.character(0,"nobunaga").gold == player.gold,"Selected player and complete inventory survive reload")
	check(loaded.character(1,"nobunaga").score == 8765,"Other player's progress remains independent")
	var untouched := Players.new(save_dir + "-fresh-migration",legacy_path)
	check(untouched.add_player("先新增再玩") != "","Player can be created before starting a campaign")
	var migrated := Players.new(untouched.directory,legacy_path)
	check(migrated.records.has("player-1") and migrated.records.has("player-2") and migrated.records["player-2"].character(0,"nobunaga").score == 8765,"Adding a player first durably preserves both imported legacy players")
	var replay := Battle.new()
	loaded.apply_to(replay.state.fighters[0])
	check(Wire.valid_snapshot(replay.get_state()),"Reloaded JSON numbers form a valid live player snapshot")
	var path: String = save_dir.path_join(id + ".json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	var recovered := Profile.new(path,"新玩家")
	check(not recovered.blocked and recovered.warning.contains("備份"),"Valid per-player backup recovers a damaged primary")
	file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string('{"version":99}')
	file.close()
	var unknown := Profile.new(path,"新玩家")
	check(unknown.blocked and unknown.save() != OK and FileAccess.get_file_as_string(path).contains("99"),"Unknown version is preserved, never overwritten")
	check(Achievements.RULES.size() == 30,"Exactly 30 distinct achievements")
	player.performance = {}
	player.performance_awards = []
	player.achievements = []
	for index in range(5):
		Achievements.damage(player,{"id":100+index,"kind":"soldier"},1,"light",1,"",true)
	var earned := Achievements.earned(player)
	check(earned.any(func(rule): return rule[0] == "cleave5") and earned.any(func(rule): return rule[0] == "kill5"),"One strike's multi-hit and multi-kill feats are counted")
	check(Achievements.earned(player).is_empty(),"A feat does not repeatedly unlock each frame")
	player.performance = {}
	player.performance_awards = []
	player.achievements = []
	for rule in Achievements.RULES: player.performance[rule[3]] = rule[4]
	check(Achievements.earned(player).size() == 30 and Achievements.valid(player.achievements),"All 30 achievement paths can unlock")
	for pair in [["soldier",false,0.0],["boss",false,5.0],["boss",true,5.0]]:
		var count := 0
		battle.state.loot_rng = 777
		for attempt in range(10000):
			battle.state.drops.clear()
			battle._drop_boss_weapon({"kind":pair[0],"stage_boss":pair[1],"x":player.x,"y":player.y},player.id)
			if not battle.state.drops.is_empty(): count += 1
		check(absf(float(count)/100.0-float(pair[2])) < 0.3,"Enemy loot rate matches %.1f%%" % pair[2])
	var rewards := 0
	for attempt in range(10000):
		player.performance = {"strike_hits":3}
		player.performance_awards = []
		player.achievement_reward_tick = -1200
		battle.state.tick = 0
		battle.state.drops.clear()
		battle.state.events.clear()
		battle._check_achievements()
		if not battle.state.drops.is_empty(): rewards += 1
	check(rewards==0,"Achievements do not bypass the three equipment drop sources")
	battle.reset_campaign()
	check(Wire.valid_snapshot(battle.get_state()),"New inventory and performance fields pass network validation")
	for hero in Battle.HEROES:
		check(Equipment.valid(players.character(0,hero)),"Future hero inventory remains valid: "+hero)
	pickup_upgrades()
	print("INVENTORY V28 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)

func pickup_upgrades() -> void:
	var sim:=Battle.new()
	var player: Dictionary=sim.state.fighters[0]
	sim.state.drops.clear()
	for id in ["sword_heshikiri","sword_samonnji","sword_nagamitsu"]:
		var old_uid: int=player.weapon_uid
		var old_tier: int=Weapons.item(player.weapon_id).tier
		sim.state.drops=[{"id":900,"kind":"weapon","weapon_id":id,"x":player.x,"y":player.y}]
		sim._pickup(player)
		check(sim.state.drops.is_empty(),"all compatible pickups enter the warehouse")
		if int(Weapons.item(id).tier)>old_tier:
			check(player.weapon_id==id and player.weapon_uid!=old_uid,"only a strictly higher tier auto-equips")
		else: check(player.weapon_uid==old_uid,"equal and lower tiers preserve the equipped instance")
	check(player.inventory.size()==3,"pickup has no two-weapon bag cap")
	check(Wire.valid_snapshot(sim.state),"automatic upgrades keep the full warehouse valid")
	for hero in ["archer","boss"]:
		var archer:=sim._make_fighter(1,hero,player.x+500,player.y,100)
		sim.state.fighters.append(archer);sim.state.effects.clear()
		sim._arc_arrow(archer,10)
		var arrow: Dictionary=sim.state.effects[0]
		var original: int=clampi(int(500/7.0)+20,45,150)
		check(arrow.flight_ticks==(roundi(original/1.2) if hero=="archer" else original),"ordinary bow arrows gain twenty percent speed without changing officer arrows")
