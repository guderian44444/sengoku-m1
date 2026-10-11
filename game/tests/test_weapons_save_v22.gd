extends SceneTree

const Battle = preload("res://core/battle.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Profiles = preload("res://core/save_profile.gd")
const Wire = preload("res://core/wire.gd")
const HUD = preload("res://render/combat_hud.gd")
var checks := 0
var failures := 0
var output: String

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	output = ProjectSettings.globalize_path("res://../artifacts/native-v22/saves-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(output)
	_catalog()
	_pickup()
	_attacks()
	_loot()
	_persistence()
	_wire()
	print("WEAPONS / SAVE V22 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)

func arena(hero: String = "nobunaga", count: int = 1) -> Battle:
	var battle := Battle.new()
	battle.reset("normal",count,[hero,hero])
	battle.state.fighters = battle.state.fighters.filter(func(f): return f.team == 0)
	battle.state.drops.clear()
	battle.state.props.clear()
	battle.state.effects.clear()
	return battle

func enemy(battle: Battle, x: float = 400.0, kind: String = "dummy") -> Dictionary:
	var target := battle._make_fighter(1,kind,x,460.0,1000)
	battle.state.fighters.append(target)
	return target

func equip(player: Dictionary, id: String) -> void:
	player.weapon_id = id
	if id not in player.owned_weapons: player.owned_weapons.append(id)

func drop(battle: Battle, id: String, player: Dictionary) -> void:
	battle._add_drop("weapon",player.x,player.y)
	battle.state.drops[-1].weapon_id = id

func _catalog() -> void:
	check(Weapons.ITEMS.size() == 15,"Exactly fifteen distinct historical weapon designs")
	for hero in ["nobunaga","oichi","tadakatsu"]:
		var family: Array = Weapons.ITEMS.keys().filter(func(id): return Weapons.compatible(hero,id))
		check(family.size() == 5,hero + " has five compatible designs")
		check(Weapons.item(Weapons.default_for(hero)).tier == 1,hero + " begins equipped with its first weapon")
		for id in family:
			check(Weapons.item(id).source.begins_with("https://") and Weapons.item(id).history.length() > 10,id + " records historical source and adaptation note")
	check(Weapons.family_for("oichi") == "bow" and Weapons.family_for("tadakatsu") == "spear","Bow and spear remain separate families")

func _pickup() -> void:
	for hero in ["nobunaga","oichi","tadakatsu"]:
		var battle := arena(hero)
		var player: Dictionary = battle.state.fighters[0]
		check(Weapons.valid_inventory(hero,player.weapon_id,player.owned_weapons),hero + " is never empty-handed")
		var upgrade: String = Weapons.upgrades(hero,player.weapon_id)[0]
		drop(battle,upgrade,player)
		battle._pickup(player)
		check(player.weapon_id == upgrade and upgrade in player.owned_weapons and battle.state.drops.is_empty(),"Compatible pickup equips and records ownership")
		check(HUD.Weapons.name_for(player) == Weapons.item(upgrade).name,"HUD weapon label follows actual equipped item")
		drop(battle,upgrade,player)
		battle._pickup(player)
		check(player.owned_weapons.size() == 2 and battle.state.drops.size() == 1,"Duplicate equipped weapon does not destroy the pickup or duplicate inventory")
		battle.state.drops.clear()
		var other := "sword_uchigatana" if hero == "oichi" else "bow_azusa"
		drop(battle,other,player)
		battle._pickup(player)
		check(player.weapon_id == upgrade and battle.state.drops.size() == 1,"Wrong-family weapon remains available for the partner")
		player.hp = 0
		player.lives = 2
		player.respawn_ticks = 1
		battle._tick_respawn(player)
		check(player.weapon_id == upgrade and upgrade in player.owned_weapons,"Respawn preserves equipped and owned weapons")
		var campaign := Battle.new()
		campaign.reset_campaign("normal",1,[hero])
		equip(campaign.state.fighters[0],upgrade)
		campaign._enter_segment(1)
		check(campaign.state.fighters[0].weapon_id == upgrade,"Changing region preserves equipment")
	var duo := arena("nobunaga",2)
	drop(duo,"sword_nagamitsu",duo.state.fighters[0])
	duo._pickup(duo.state.fighters[0])
	check(duo.state.fighters[1].owned_weapons.size() == 1,"Two copies of a hero do not share mutable inventory")

func _attacks() -> void:
	var battle := arena()
	var player: Dictionary = battle.state.fighters[0]
	player.action = "heavy"
	var target := enemy(battle,425.0)
	battle._melee(player,200,80,26,false)
	check(target.hp == 1000,"Baseline sword cannot hit beyond its actual reach")
	equip(player,"sword_heshikiri")
	battle._melee(player,200,80,26,false)
	check(target.hp == 967 and target.burn > 0,"Upgraded sword adds seven damage and fire within its extra reach")
	check(target.knockback > 0,"Weapon push augments a successful standing hit")
	var oichi := arena("oichi")
	var archer: Dictionary = oichi.state.fighters[0]
	equip(archer,"bow_shigeto")
	archer.action = "light"
	check(oichi._attack_equipment(archer).is_empty(),"Bow never changes Oichi's kick or needle melee")
	oichi._projectile(archer,24,0,false,"needle",280)
	check(oichi.state.effects[-1].damage == 24 and oichi.state.effects[-1].element == "","Bow never upgrades thrown needles")
	oichi._projectile(archer,24,0,false,"arrow",760)
	var arrow: Dictionary = oichi.state.effects[-1]
	check(arrow.damage == 34 and arrow.element == "ice" and not arrow.piercing,"Bow upgrades one-target arrow damage and ice, not unlimited piercing")
	check(arrow.equipment_id == "bow_shigeto" and arrow.equipment_knockback == 3 and arrow.range_left == 765,"Arrow records range, push and weapon at release")
	equip(archer,"bow_azusa")
	check(arrow.damage == 34 and arrow.element == "ice" and arrow.equipment_id == "bow_shigeto","Changing weapon cannot rewrite a flying arrow")

func _loot() -> void:
	var signatures := []
	for replay in range(2):
		var battle := arena("oichi")
		battle.state.loot_rng = 777
		var player: Dictionary = battle.state.fighters[0]
		var results := []
		for index in range(40):
			var boss := enemy(battle,700,"boss")
			boss.stage_boss = index % 2 == 0
			var before: int = battle.state.drops.size()
			battle._drop_boss_weapon(boss,player.id)
			var added: int = battle.state.drops.size() - before
			if boss.stage_boss: check(added == 1,"Major boss always rewards an upgrade while one exists")
			if added:
				var id: String = battle.state.drops[-1].weapon_id
				check(Weapons.compatible(player.kind,id) and Weapons.item(id).tier > 1,"Boss loot is an upgrade in the killer's family")
				results.append(id)
			else: results.append("")
		check("" in results and results.any(func(id): return id != ""),"Minor boss drop chance includes rewards and misses")
		signatures.append(results)
	check(signatures[0] == signatures[1],"Identical PRNG seed and kills reproduce identical loot")
	var training := Battle.new()
	training.reset_training("nobunaga","boss")
	training.state.drops.clear()
	training._drop_boss_weapon(training.state.fighters[-1],training.state.fighters[0].id)
	check(training.state.drops.is_empty(),"Training boss cannot farm persistent weapons")
	var battle := arena("tadakatsu")
	var boss := enemy(battle,700,"boss")
	boss.stage_boss = true
	battle._damage(boss,10000,battle.state.fighters[0].id,false,false,true)
	check(battle.state.drops.any(func(item): return item.kind == "weapon" and Weapons.compatible("tadakatsu",item.weapon_id)),"Real fatal damage invokes the boss weapon reward")
	var rewards: int = battle.state.drops.size()
	battle._damage(boss,10000,battle.state.fighters[0].id,false,false,true)
	check(battle.state.drops.size() == rewards,"Repeated damage to a corpse never duplicates loot")

func write(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _persistence() -> void:
	var path := output.path_join("characters.json")
	var profiles := Profiles.new(path)
	check(profiles.warning == "" and profiles.character(0,"nobunaga").weapon_id == "sword_uchigatana","Missing save safely gives a default weapon")
	var battle := arena("nobunaga",2)
	var first: Dictionary = battle.state.fighters[0]
	var second: Dictionary = battle.state.fighters[1]
	first.score = 14500
	first.max_hp_bonus = 20
	first.hp = 0
	first.lives = 0
	first.action = "defeated"
	equip(first,"sword_heshikiri")
	second.score = 400
	equip(second,"sword_nagamitsu")
	profiles.capture(first)
	profiles.capture(second)
	check(profiles.save() == OK and FileAccess.file_exists(path),"First save is atomically written")
	var loaded := Profiles.new(path)
	check(loaded.character(0,"nobunaga").weapon_id == "sword_heshikiri" and loaded.character(1,"nobunaga").weapon_id == "sword_nagamitsu","Same hero in two player slots retains separate equipment")
	var restored: Dictionary = arena("nobunaga").state.fighters[0]
	loaded.apply_to(restored)
	check(restored.hp == 140 and restored.max_hp == 140 and restored.max_hp_bonus == 20,"Permanent HP attribute applies to fresh difficulty HP")
	check(restored.score == 14500 and restored.next_life_score == 20000,"Score and the next-life threshold restore without granting duplicate lives")
	check(restored.lives == 3 and restored.action == "idle" and restored.respawn_ticks == 0,"No death, action, life-count or stage state leaks into a new sortie")
	check(not loaded.equip(0,"nobunaga","bow_shigeto") and not loaded.equip(0,"nobunaga","sword_dojigiri"),"Loadout cannot select an incompatible or unowned weapon")
	check(loaded.equip(0,"nobunaga","sword_uchigatana") and loaded.save() == OK,"Owned starter can be re-equipped and saved")
	check(FileAccess.file_exists(path + ".bak"),"Second save retains a validated backup")
	write(path,"{broken")
	var backup := Profiles.new(path)
	check(backup.warning != "" and not backup.blocked and backup.character(0,"nobunaga").weapon_id == "sword_heshikiri","Damaged primary falls back to last known-good backup")
	check(backup.save() == OK and Profiles.new(path).warning == "","Saving recovered data repairs primary while retaining evidence")
	check(Array(DirAccess.get_files_at(output)).any(func(name): return name.contains(".corrupt-")),"Corrupt primary is preserved separately")
	var corrupt_path := output.path_join("bad.json")
	write(corrupt_path,"bad primary")
	write(corrupt_path + ".bak","bad backup")
	var corrupt := Profiles.new(corrupt_path)
	check(corrupt.blocked and corrupt.save() == ERR_INVALID_DATA,"Two damaged files block automatic overwrite")
	check(FileAccess.get_file_as_string(corrupt_path) == "bad primary" and FileAccess.get_file_as_string(corrupt_path + ".bak") == "bad backup","Both damaged originals remain byte-for-byte unchanged")
	for field in ["score","max_hp_bonus","owned_weapons","weapon_id","slot","hero"]:
		var invalid: Dictionary = loaded.data.duplicate(true)
		invalid.characters["0:nobunaga"][field] = -1
		check(not Profiles.valid(invalid),"Reject malformed saved " + field)
	var future: Dictionary = loaded.data.duplicate(true)
	future.version = 2
	check(not Profiles.valid(future),"Unsupported future save version is rejected")
	var future_path := output.path_join("future.json")
	var future_bytes := JSON.stringify(future)
	var known_backup := JSON.stringify(loaded.data)
	write(future_path,future_bytes)
	write(future_path + ".bak",known_backup)
	var unknown := Profiles.new(future_path)
	check(unknown.blocked and unknown.save() == ERR_INVALID_DATA,"Unknown primary version blocks saving even with a valid older backup")
	check(FileAccess.get_file_as_string(future_path) == future_bytes and FileAccess.get_file_as_string(future_path + ".bak") == known_backup,"Future primary and known older backup remain byte-for-byte unchanged")
	write(future_path,known_backup)
	var open_session := Profiles.new(future_path)
	write(future_path,future_bytes)
	check(open_session.save() == ERR_INVALID_DATA and open_session.blocked and FileAccess.get_file_as_string(future_path) == future_bytes,"An already-open session also protects a newer save written after loading")

func _wire() -> void:
	var battle := Battle.new()
	check(Wire.valid_snapshot(battle.get_state()),"New equipment snapshot passes strict validation")
	for field in ["weapon_id","owned_weapons","max_hp_bonus"]:
		var snapshot: Dictionary = battle.get_state()
		snapshot.fighters[0][field] = -1
		check(not Wire.valid_snapshot(snapshot),"Wire rejects malformed " + field)
	var snapshot := battle.get_state()
	snapshot.drops[0].weapon_id = "invented"
	check(not Wire.valid_snapshot(snapshot),"Wire rejects an unknown weapon drop")
	snapshot = battle.get_state()
	snapshot.loot_rng = INF
	check(not Wire.valid_snapshot(snapshot),"Wire rejects non-finite PRNG state")
