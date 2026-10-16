extends SceneTree

const Battle = preload("res://core/battle.gd")
const Equipment = preload("res://core/equipment.gd")
const Profile = preload("res://core/save_profile.gd")
const View = preload("res://render/battle_view.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func equip(battle: RefCounted, id: String) -> Dictionary:
	var player: Dictionary = battle.state.fighters[0]
	Equipment.equip(player,Equipment.add(player,id))
	return player

func enemy(battle: RefCounted, hp: int = 500) -> Dictionary:
	var player: Dictionary = battle.state.fighters[0]
	var target: Dictionary = battle._make_fighter(1,"soldier",player.x+80,player.y,hp)
	target.weight = "heavy"
	battle.state.fighters = [player,target]
	return target

func _initialize() -> void:
	check(Equipment.TREASURES.size() == 30,"Exactly thirty charms are installed")
	var signatures := []
	for id in Equipment.TREASURES:
		var battle := Battle.new()
		var player := equip(battle,id)
		var spec: Dictionary = Equipment.TREASURES[id]
		check(Equipment.valid(player) and Wire.valid_snapshot(battle.state),id+" equips in a legal state")
		check(not spec.description.is_empty() and spec.source.begins_with("https://") and not spec.history.is_empty(),id+" carries function definitions and separate historical source metadata")
		check(spec.icons.size() >= 1 and spec.icons.size() <= 3 and View.buff_icon(player) == spec.icons[0],id+" has readable function icons")
		var before := int(player.shield_points)
		Equipment.absorb(player,20)
		check(player.shield_points < before,id+" loses durability on damage protection")
		var saved := Profile.new("user://charm-v30-"+id+"-%d.json" % Time.get_ticks_usec(),"護符驗證")
		saved.capture(player)
		check(saved.save() == OK,id+" saves successfully")
		var reloaded := Profile.new(saved.path,"護符驗證")
		var row: Dictionary = reloaded.character(0,"nobunaga")
		check(row.inventory == player.inventory and row.treasure_uid == player.treasure_uid,id+" reloads the same instance and wear")
		Equipment.remove(player,int(player.treasure_uid))
		check(View.buff_icon(player).is_empty(),id+" disappears on unequip/removal")
		var signature := [spec.mode,spec.durability,spec.reduction]
		for field in ["damage_bonus","move_bonus","reach_bonus","attack_speed_bonus","knockback_bonus","heavy_bonus","charged_bonus","air_bonus","throw_bonus","special_bonus","food_bonus","kill_rage","guard_rage","burn_resist","freeze_resist","poison_resist"]: signature.append(spec.get(field,0))
		check(signature not in signatures,id+" has a distinct functional definition")
		signatures.append(signature)
	for pair in [["kashima","heavy"],["katori","charged"],["sky_marici","air_light"],["grapple_vow","throw"],["fan_victory","special"]]:
		var battle := Battle.new()
		var player := equip(battle,pair[0])
		var target := enemy(battle)
		player.action = pair[1]
		battle._damage(target,100,player.id,false)
		check(500-int(target.hp) == roundi(100*Equipment.damage_multiplier(player,pair[1])),str(pair)+" changes real accepted direct damage")
		target.invuln = 0
		target.action = "idle"
		target.hp = 500
		battle._damage(target,100,player.id,false,false)
		check(target.hp == 400,str(pair)+" never amplifies damage over time")
	var battle := Battle.new()
	var player := equip(battle,"tenjin")
	check(Battle.fighter_tick(player,100) < Battle.hero_tick(player.kind,100),"Attack speed charm shortens simulation timing")
	var view := View.new()
	player.action = "heavy"
	player.heavy_combo = 1
	player.action_tick = Battle.fighter_tick(player,14)
	check(view._fighter_animation(player).frame == 3,"Faster attack still hits on authored contact frame four")
	view.free()
	for pair in [["atago","fire","burn",108],["snow_mirror","ice","freeze",59]]:
		battle = Battle.new()
		player = equip(battle,pair[0])
		var target := enemy(battle)
		battle._apply_element(player,pair[1],target.id)
		check(int(player[pair[2]]) == int(pair[3]),str(pair)+" shortens the new status without immunity")
	battle = Battle.new()
	player = equip(battle,"clear_water")
	battle._poison(player,100,0)
	check(player.poison == 65,"Poison charm reduces the new poison duration")
	battle = Battle.new()
	player = equip(battle,"inari")
	player.hp = 50
	battle.state.drops = [{"id":990,"kind":"food","x":player.x,"y":player.y,"heal":40}]
	battle._pickup(player)
	check(player.hp == 96,"Food charm adds healing through the pickup path")
	player.hp = player.max_hp-2
	battle.state.drops = [{"id":991,"kind":"food","x":player.x,"y":player.y,"heal":40}]
	battle._pickup(player)
	check(player.hp == player.max_hp,"Food bonus never exceeds maximum HP")
	battle = Battle.new()
	player = equip(battle,"battle_spirit")
	player.action = "guard"
	player.rage = 0
	var target := enemy(battle)
	check(not battle._damage(player,10,target.id,false) and player.rage == 1,"Only a successful guard awards guard rage")
	player.action = "idle"
	player.invuln = 0
	battle._damage(target,1000,player.id,true)
	check(player.rage == 3,"One enemy kill awards two rage")
	battle._damage(target,1000,player.id,true)
	check(player.rage == 3,"An already defeated enemy cannot award rage again")
	var dropped := {}
	battle.reset_campaign("normal",1,["nobunaga"],2)
	player = battle.state.fighters[0]
	target.stage_boss = true
	for index in range(40000):
		battle.state.drops.clear()
		battle._drop_talisman(target,player.id)
		for drop in battle.state.drops: dropped[drop.talisman_id] = true
	check(dropped.size() == 30,"All thirty charms can actually appear as second-chapter loot")
	print("TALISMANS V30 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
