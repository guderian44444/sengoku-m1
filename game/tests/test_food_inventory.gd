extends SceneTree

const Battle = preload("res://core/battle.gd")
const Equipment = preload("res://core/equipment.gd")
const Players = preload("res://core/player_store.gd")
const Wire = preload("res://core/wire.gd")
const Main = preload("res://main.gd")
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func _initialize() -> void: run.call_deferred()

func core() -> void:
	var sim := Battle.new()
	sim.reset_campaign("normal",1,["nobunaga"],4)
	var p: Dictionary = sim.state.fighters[0]
	for id in ["sword_heshikiri","sword_nagamitsu","wind","vajra"]: check(Equipment.add(p,id)>0,"fill equipment slots")
	Equipment.sync(p)
	for id in ["rice","fish","dango","peach"]:
		check(sim._add_drop("food",p.x,p.y,p.id),"food pickup fixture")
		sim.state.drops[-1].food_id=id
		var before: int=p.inventory.size()
		sim._pickup(p)
		check(p.inventory.size()==before+1 and p.hp==p.max_hp,"full HP stores food beyond equipment slots")
		check(sim.state.drops.is_empty(),"storing consumes the ground pickup")
		check(sim.state.events[-1].type=="food_stored" and Equipment.valid(p),"stored food validates and reports storage")
		var uid: int=p.inventory[-1].uid
		check(not Equipment.equip(p,uid) and Equipment.sell(p,uid)==0,"food cannot become weapon or sell for money")
		sim._add_drop("food",p.x,p.y,p.id)
		p.hp-=1
		sim._pickup(p)
		check(p.hp==p.max_hp and p.inventory.size()==before+1 and sim.state.drops.is_empty(),"even one missing HP consumes whole food")
	check(p.inventory.filter(func(item):return Equipment.FOODS.has(item.item_id)).size()==4,"all stored foods share the warehouse without equipment slots")
	check(Wire.valid_snapshot(sim.get_state()),"food inventory crosses snapshot boundary")
	var folder: String="user://food-save-%d"%Time.get_ticks_usec()
	var players:=Players.new(folder,"user://no-legacy-food.json")
	players.capture(p)
	check(players.save()==OK,"food saved with existing inventory")
	var loaded:=Players.new(folder,"user://no-legacy-food.json")
	var replay:=Battle.new()
	loaded.apply_to(replay.state.fighters[0])
	check(replay.state.fighters[0].inventory==p.inventory and Equipment.valid(replay.state.fighters[0]),"four food types survive save/load and departure")
	while p.inventory.size()<Equipment.CAPACITY: check(Equipment.add(p,"food_rice")>0,"food uses existing total capacity")
	sim._add_drop("food",p.x,p.y,p.id)
	sim._pickup(p)
	check(sim.state.drops.size()==1 and sim.state.events[-1].type=="inventory_full","full inventory preserves ground food")
	p.hp-=1;sim._pickup(p)
	check(sim.state.drops.is_empty() and p.hp==p.max_hp,"injured pickup still eats with full inventory")
	check(Equipment.valid(p),"full bag remains valid")

func run() -> void:
	core()
	var app:=Main.new()
	app.testing=true
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.profiles=Players.new("user://food-menu-%d"%Time.get_ticks_usec(),"user://no-food-menu-legacy.json")
	check(app.profiles.save()==OK,"isolated profile initialized")
	app._open_selection(false)
	app._start_solo()
	app.paused=true
	var p: Dictionary=app.sim.state.fighters[0]
	var uid:=Equipment.add(p,"food_rice")
	app.profiles.capture(p)
	check(app.profiles.save()==OK,"stored ration persisted before opening menu")
	app._show_menu_page("pause")
	app._open_collection(0)
	app.collection.categories.current_tab=5
	app.collection.select_item(str(uid))
	check(app.collection.listed.size()==1 and app.collection.picture.texture!=null,"food tab shows existing food art")
	check(app.collection.equip_button.text=="使用" and app.collection.equip_button.disabled,"full HP cannot waste stored ration")
	app._use_food(str(uid))
	check(not Equipment.instance(p,uid).is_empty(),"full HP use rejected without consumption")
	p.hp-=1
	app._refresh_collection();app.collection.select_item(str(uid))
	check(not app.collection.equip_button.disabled,"injured player can use ration")
	app.collection.equip_button.pressed.emit()
	check(p.hp==p.max_hp and Equipment.instance(p,uid).is_empty(),"real menu action heals and consumes once")
	var loaded:=Players.new(app.profiles.directory,"user://no-food-menu-legacy.json")
	check(Equipment.instance(loaded.character(0,p.kind),uid).is_empty(),"consumption persisted, no reload duplication")
	uid=Equipment.add(p,"food_fish")
	app.profiles.capture(p);app.profiles.save()
	p.hp-=30
	app._refresh_collection()
	var profile=app.profiles.records[app.profiles.selected[0]]
	profile.blocked=true
	app._use_food(str(uid))
	check(p.hp==p.max_hp-30 and not Equipment.instance(p,uid).is_empty(),"failed save restores item and gives no free healing")
	profile.blocked=false
	check(not Equipment.instance(app.profiles.character(0,p.kind),uid).is_empty(),"profile rollback keeps food too")
	app._refresh_collection();app.collection.select_item(str(uid))
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		var folder:=OS.get_environment("TEST_ARTIFACT_DIR")
		check(root.get_texture().get_image().save_png(folder.path_join("food-inventory.png"))==OK,"native food tab capture")
	app.session="local"
	app.sim.reset_campaign("normal",2,["nobunaga","oichi"],4)
	for fighter in app.sim.state.fighters:
		if fighter.team==0: app.profiles.apply_to(fighter)
	var left: Dictionary=app.sim.state.fighters[0]
	var right: Dictionary=app.sim.state.fighters[1]
	left.hp-=10;right.hp-=20
	uid=Equipment.add(right,"food_peach")
	app.profiles.capture(left);app.profiles.capture(right)
	check(app.profiles.save()==OK,"co-op stores ration in correct account")
	app._open_collection(1)
	app.collection.categories.current_tab=5;app.collection.select_item(str(uid))
	app.collection.equip_button.pressed.emit()
	check(right.hp==right.max_hp and left.hp==left.max_hp-10,"2P food heals only 2P")
	check(Equipment.instance(right,uid).is_empty() and app.profiles.character(1,right.kind).inventory.is_empty(),"2P consumption saved to 2P account")
	app.queue_free()
	await process_frame
	print("FOOD INVENTORY PASS: %d checks; full/partial HP, capacity, storage, UI use, persistence and failed-save rollback"%checks)
	quit()
