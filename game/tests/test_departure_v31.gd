extends SceneTree

const Main = preload("res://main.gd")
const Players = preload("res://core/player_store.gd")
const Equipment = preload("res://core/equipment.gd")
const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0
var capture := false

class App extends Main:
	func _connected_pads() -> Array[int]: return [3,7]
	func _set_game_focus(_focused: bool) -> void: pass

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func shot(app: Node, name: String) -> void:
	if not capture: return
	var before := var_to_bytes(app.sim.state)
	if not app.menu.visible: app._update_view()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(var_to_bytes(app.sim.state) == before,"Rendering leaves simulation unchanged: "+name)
	var output := OS.get_environment("TEST_ARTIFACT_DIR").path_join("screens")
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"Native capture: "+name)

func run() -> void:
	root.size = Vector2i(1280,720)
	var app := App.new()
	root.add_child(app)
	app.set_physics_process(false)
	app.profiles = Players.new("user://departure-%d" % Time.get_ticks_usec(),"user://missing-departure.json")
	app._open_login(false)
	check(app.menu_screen == "players" and app.players_continue.visible,"Start enters player login")
	await shot(app,"01-login")
	app._open_roster()
	check(app.menu_screen == "roster","Login leads to separate hero choice")
	await shot(app,"02-roster")
	app.menu_pages.roster.get_node("Continue").pressed.emit()
	check(app.menu_screen == "select" and app.character_panel.stats.text.contains("基準攻擊"),"Hero choice leads to real character stats")
	var profile = app.profiles.records[app.profiles.selected[0]]
	var row: Dictionary = app.profiles.character(0,"nobunaga")
	check(row.inventory.is_empty() and row.weapon_uid == 0 and row.weapon_id == "practice_nobunaga","New player has permanent baseline without consuming bag slots")
	var swords := []
	for id in ["sword_nagamitsu","sword_heshikiri","sword_dojigiri"]: swords.append(Equipment.add(row,id))
	var charms := []
	for id in ["war","wind","mirror"]: charms.append(Equipment.add(row,id))
	check(Equipment.pack(row,swords[0],true) and Equipment.pack(row,swords[1],true),"Two weapons can be prepared")
	check(not Equipment.pack(row,swords[2],true),"Third weapon cannot bypass departure capacity")
	check(Equipment.pack(row,charms[0],true) and Equipment.pack(row,charms[1],true),"Two charms can be prepared")
	check(not Equipment.pack(row,charms[2],true),"Third charm cannot bypass departure capacity")
	Equipment.equip(row,swords[0])
	Equipment.equip(row,charms[0])
	profile.data.characters["0:nobunaga"] = row
	check(app.profiles.save() == OK,"Prepared warehouse and bag persist through real storage")
	var legacy: Dictionary = profile.data.duplicate(true)
	legacy.characters["0:nobunaga"].erase("bag_uids")
	var legacy_path: String = app.profiles.directory.path_join("legacy-v2.json")
	var legacy_file := FileAccess.open(legacy_path,FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	var migrated = preload("res://core/save_profile.gd").new(legacy_path,"玩家")
	var migrated_row: Dictionary = migrated.character(0,"nobunaga")
	check(not migrated.blocked and migrated_row.inventory == row.inventory and migrated_row.bag_uids == [swords[0],charms[0]],"Old v2 stock and exact durability survive migration; only equipped items start packed")
	app._refresh_loadouts()
	await shot(app,"03-status")
	app._open_collection(0)
	check(app.collection.categories.tab_count == 5 and app.collection.entries.size() == 6,"Warehouse has category tabs and all stock")
	check(app.collection.pack_button.visible and not app.collection.discard_button.visible,"Preparation transfers stock without destructive discard")
	await shot(app,"04-warehouse")
	app._menu_back()
	app._start_solo()
	var player: Dictionary = app.sim.state.fighters[0]
	check(player.inventory.size() == 4 and player.storage_reserve == 2,"Battle carries only prepared items; warehouse stays separate")
	check(Wire.valid_snapshot(app.sim.state),"Prepared battle snapshot passes wire validation")
	var oversized: Dictionary = app.sim.get_state()
	oversized.fighters[0].bag_only = false
	check(not Wire.valid_snapshot(oversized),"Network snapshots cannot expose permanent warehouse as battle bag")
	var before_warehouse: Dictionary = app.profiles.character(0,"nobunaga")
	app.sim.state.drops = [{"id":900,"kind":"weapon","weapon_id":"sword_heshikiri","x":player.x,"y":player.y}]
	app.sim._pickup(player)
	check(player.inventory.size() == 4 and app.sim.state.drops.size() == 1,"Full weapon category leaves loot on the ground")
	player.hp -= 30
	app.sim.state.drops.append({"id":901,"kind":"food","food_id":"rice","heal":20,"x":player.x,"y":player.y})
	app.sim._pickup(player)
	check(player.hp == player.max_hp-10 and player.inventory.size() == 4,"Food remains usable with a full bag")
	app.sim.state.drops.append({"id":903,"kind":"talisman","talisman_id":"moon","x":player.x,"y":player.y})
	app.sim._pickup(player)
	check(app.sim.state.drops.size() == 2 and player.inventory.size() == 4,"Full charm category leaves charm loot on ground too")
	app.sim.state.drops.pop_back()
	app._show_menu_page("pause")
	app.paused = true
	app._open_collection(0)
	check(app.collection.entries.size() == 4 and not app.collection.sell_button.visible and not app.collection.pack_button.visible,"Battle exposes bag only, with no selling or warehouse transfer")
	await shot(app,"05-battle-bag")
	app._request_discard(str(swords[0]))
	check(app.menu_screen == "confirm" and app.confirmation_text.text.contains("永久消失"),"Discard explicitly confirms permanent removal")
	await shot(app,"06-discard-confirm")
	app._cancel_confirmation()
	check(not Equipment.instance(player,swords[0]).is_empty(),"Cancelling discard preserves equipped weapon")
	app._request_discard(str(swords[0]))
	app._accept_confirmation()
	check(Equipment.instance(player,swords[0]).is_empty() and player.weapon_id == "practice_nobunaga","Confirmed discard removes item and equips infinite baseline")
	check(app.sim.state.drops.size() == 1,"Discard never creates recoverable ground loot")
	app.sim._pickup(player)
	check(player.inventory.size() == 4 and app.sim.state.drops.is_empty() and player.weapon_uid == 0,"Freed slot accepts loot without auto-equipping")
	app._unequip_treasure(0)
	var removed: int = player.treasure_uid
	check(removed == 0,"Battle can unequip charm through bag UI")
	var carried: int = player.inventory.filter(func(i): return Equipment.TREASURES.has(i.item_id))[0].uid
	Equipment.remove(player,carried)
	app.sim.state.drops = [{"id":902,"kind":"talisman","talisman_id":"mirror","x":player.x,"y":player.y}]
	app.sim._pickup(player)
	check(player.treasure_uid == 0 and player.shield_kind == "","Picked charm stays in bag until explicitly equipped")
	for tick in range(500): app.sim._wear_weapon(player,0)
	check(player.weapon_id == "practice_nobunaga","Baseline survives repeated accepted-hit wear calls")
	check(app._save_characters() == OK,"Battle mutations save successfully")
	var saved: Dictionary = app.profiles.character(0,"nobunaga")
	check(not Equipment.instance(saved,swords[2]).is_empty() and not Equipment.instance(saved,charms[2]).is_empty(),"Untaken warehouse items survive bag discard and battle save")
	var reloaded := Players.new(app.profiles.directory,"user://missing-departure.json")
	check(reloaded.character(0,"nobunaga").inventory == saved.inventory and reloaded.character(0,"nobunaga").bag_uids == saved.bag_uids,"Warehouse, bag, UIDs and durability reload intact")
	check(reloaded.character(1,"nobunaga").inventory.is_empty(),"Other player account remains independent")
	app._open_collection(0)
	var discard_uid: int = player.inventory[0].uid
	var unchanged := var_to_bytes(player)
	profile.blocked = true
	app._request_discard(str(discard_uid))
	app._accept_confirmation()
	check(var_to_bytes(player) == unchanged and not Equipment.instance(app.profiles.character(0,"nobunaga"),discard_uid).is_empty(),"Failed discard save preserves both live bag and stored item")
	profile.blocked = false
	app.active = false
	app.sim.reset_campaign("normal",1,["tadakatsu"],2)
	app.active = true
	app.menu.hide()
	app.view.state = app.sim.state
	app.sim._add_drop("talisman",450,550)
	app.sim.state.drops[-1].talisman_id = "moon"
	var cart: Dictionary = app.sim.state.challenge
	var x: float = cart.x
	check(cart.kind == "reclaim" and not cart.has("guard_flee_tick"),"Stolen cart has no friendly escort state")
	await shot(app,"07-cart-stolen")
	var raider := app.sim._make_fighter(1,"raider",cart.x+100,cart.y,82)
	raider.face = -1
	app.sim.state.fighters.append(raider)
	check(cart.x == x,"Enemy approach leaves stolen cart stationary")
	app.sim.state.tick = 75
	await shot(app,"08-cart-enemy-destruction")
	var hp: int = cart.hp
	app.sim._enemy_melee(raider,145,65,16)
	check(cart.hp < hp,"Enemy strikes can damage the stationary cart")
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0)
	app.sim.state.wave = app.sim.state.stage.wave_total
	app.sim.state.stage.clear_tick = app.sim.state.tick-45
	app.sim._tick_segment()
	check(cart.status == "complete" and app.sim.state.fighters[0].gold == 300,"Surviving first checkpoint awards cart reclaim bonus")
	app.sim._tick_segment()
	check(cart.x == x and app.sim.state.fighters[0].gold == 300,"Reclaim reward occurs once and cart remains fixed")
	check(Wire.valid_snapshot(app.sim.state),"Stationary reclaim event have valid wire state")
	for scene in [1,3,5]:
		app.sim._enter_segment(scene)
		app.sim._start_checkpoint(1)
		app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0)
		app.sim.state.wave = app.sim.state.stage.wave_total
		app.sim._spawn_segment_wave()
		app.sim.state.intro = {}
		var boss: Dictionary = app.sim.state.fighters.filter(func(f): return f.kind == "boss")[0]
		boss.entering = false
		boss.x = 900.0
		boss.y = 520.0
		boss.face = -1
		boss.action = "boss_thrust"
		boss.action_tick = Battle.enemy_timing(boss)[0]
		var sample: Dictionary = app.view._fighter_animation(boss)
		var frame: Dictionary = app.view._art.enemy_frame("boss",int(sample.cell),"oda",sample.sheet)
		check(sample.source == "v31" and frame.body_height >= 600,"Second chapter spear commander uses newly authored sharp attack source")
		var tip_reach: float = (frame.region.end.x-frame.anchor.x)*155/frame.body_height*boss.render_scale
		app.sim._enemy_melee(boss,200,65,20)
		check(absf(boss.attack_reach-tip_reach) < 3,"Spear attack reach follows measured visible tip")
		await shot(app,"09-boss-"+boss.boss_variant)
	app.sim.reset_campaign("normal",1,["nobunaga"],2)
	for kind in ["soldier","flag","commander","archer","gunner"]:
		var enemy := app.sim._make_fighter(1,kind,800,480,80)
		var sample: Dictionary = app.view._fighter_animation(enemy)
		check(sample.source in ["v14","v19"],"Oda regular troops use first-chapter HD source: "+kind)
	var loot := Battle.new()
	loot.reset_campaign("normal",1,["nobunaga"],2)
	var owner: Dictionary = loot.state.fighters[0]
	var enemy := loot._make_fighter(1,"soldier",800,480,80)
	var weapons := 0
	var charms_found := 0
	for index in range(20000):
		loot.state.drops.clear()
		loot._drop_boss_weapon(enemy,owner.id)
		weapons += loot.state.drops.size()
		loot.state.drops.clear()
		loot._drop_talisman(enemy,owner.id)
		charms_found += loot.state.drops.size()
	check(weapons >= 50 and weapons <= 160,"Actual seeded grunt weapon drops match 0.5%, not former 5%")
	check(charms_found >= 15 and charms_found <= 85,"Actual seeded grunt charm drops match 0.2%, not former 2%")
	app.free()
	await process_frame
	print("DEPARTURE V31 %s: %d checks, %d failures; login, warehouse/bag, pickup, discard, persistence, stationary defense, HD source and measured spear reach." % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)
