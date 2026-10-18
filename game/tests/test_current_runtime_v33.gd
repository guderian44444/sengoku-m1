extends SceneTree
const Battle = preload("res://core/battle.gd")
const Main = preload("res://main.gd")
const Source = preload("res://render/layered_hero_source.gd")
const Demo = preload("res://render/art_demo.gd")
const Players = preload("res://core/player_store.gd")
const Equipment = preload("res://core/equipment.gd")
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	assert(value,label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	check(Battle.HEROES.size()==6 and Battle.PLAYABLE_HEROES==Battle.HEROES,"Stable save IDs, six playable heroes")
	for hero in Battle.HEROES:
		var battle := Battle.new()
		battle.reset("normal",1,[hero])
		check(battle.state.fighters[0].kind==(hero if hero in Battle.PLAYABLE_HEROES else "nobunaga"),"Unavailable hero cannot start: "+hero)
		var player: Dictionary = battle.state.fighters[0]
		player.rage = 100
		battle.step([{"buttons":Battle.SPECIAL,"dx":0,"dy":0}])
		check(player.action=="idle" and player.rage==100,"Retired special input ignored: "+hero)
	var saves := Players.new("user://current-roster-%d" % Time.get_ticks_usec(),"user://current-roster-missing.json")
	for hero in Battle.HEROES:
		var row := saves.character(0,hero)
		row.score = 1234
		saves.records[saves.selected[0]].data.characters["0:"+hero] = row
		check(Equipment.valid(row),"All saved hero inventories remain valid: "+hero)
	check(saves.save()==OK,"Save all six character records")
	var reload := Players.new(saves.directory,"user://current-roster-missing.json")
	for hero in Battle.HEROES: check(reload.character(0,hero).score==1234,"Future hero progress preserved: "+hero)
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	check(not InputMap.has_action("special") and InputMap.has_action("guard"),"Guard restored while retired special remains removed")
	for choice in [app.heroes,app.partner_heroes,app.roster_choices[0],app.roster_choices[1]]:
		for index in range(6):
			check(not choice.is_item_disabled(index),"Only current heroes selectable")
			check(not choice.get_item_text(index).contains("尚未應召"),"All delivered heroes available")
			if index==4: check(choice.get_item_text(index).contains("顯如"),"Planned monk replaces Mitsuhide in unavailable roster label")
	for hero in Battle.PLAYABLE_HEROES:
		var path := Source.folder(hero)
		var registration: Variant = JSON.parse_string(FileAccess.get_file_as_string(path+"registration.json"))
		check(Source.complete_registration(registration),"Current common poses complete: "+hero)
		for clip in registration.clips:
			check(clip in ["idle","walk","run","jump","hurt","stunned","down","recovering","launched","victory"],"No retired attack in common art")
		var sheets: Dictionary = app.view._art.animations[hero]
		check(not sheets.has("v22_light1") and not sheets.has("v22_special"),"No legacy attack fallback loaded")
		app.active = false
		app.training_active = true
		app.selected_hero = hero
		app._switch_training_hero()
		check(app.selected_hero==Battle.PLAYABLE_HEROES[(Battle.PLAYABLE_HEROES.find(hero)+1)%6],"Training cycles current roster")
	var gallery := Demo.new()
	for index in range(Demo.POSES.size()):
		gallery.seek(index)
		app.view.art_demo = true
		for fighter in gallery.world().fighters:
			var sample: Dictionary = app.view._fighter_animation(fighter)
			check(not app.view._art.animation_frame(fighter.kind,sample).is_empty(),"Gallery uses available current frame")
	app.queue_free()
	await process_frame
	print("CURRENT RUNTIME V33 PASS: %d checks" % checks)
	quit()
