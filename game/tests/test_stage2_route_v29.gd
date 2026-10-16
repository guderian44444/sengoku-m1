extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
const Stages = preload("res://core/stage_data.gd")
const Main = preload("res://main.gd")
const Players = preload("res://core/player_store.gd")
const Equipment = preload("res://core/equipment.gd")
var checks := 0
var failures := 0

class App extends Main:
	func _connected_pads() -> Array[int]: return [3,7]
	func _set_game_focus(_focused: bool) -> void: pass

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	_test_data()
	for count in [1,2]: _test_route(count)
	_test_attack_smoke()
	await _test_progression()
	print("STAGE 2 ROUTE V29 %s: %d checks, %d failures. Full route transitions clear enemies manually; separate first-wave smoke uses real attacks with refilled player HP. No human difficulty or controller acceptance." % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)

func _test_data() -> void:
	var chapter := Stages.chapter(2)
	check(chapter.id == 2 and chapter.faction == "oda","Second chapter has its own faction and identity")
	check(chapter.segments.size() == 6,"Second chapter has six scenes")
	check(Stages.available().any(func(row): return int(row.id) == 2),"Stage discovery makes chapter 2 available")
	var themes := []
	var roles := {}
	var boss_names := []
	for scene in chapter.segments:
		themes.append(str(scene.theme))
		check(scene.encounters.size() == 2,"Each scene has two checkpoints")
		var previous := 0.0
		for encounter in scene.encounters:
			if encounter.has("boss"): boss_names.append(str(encounter.boss.name))
			check(encounter.end > previous+900 and encounter.end <= scene.width,"Checkpoints advance within the scene bounds")
			for wave in encounter.waves:
				check(not wave.is_empty() and wave.size() <= 8,"Scheduled wave has bounded enemies")
				for kind in wave: roles[str(kind)] = true
			previous = encounter.end
		check(previous == scene.width,"Last checkpoint reaches the scene exit")
		for prop in scene.props:
			check(prop[1] > 40 and prop[1] < scene.width-40 and prop[2] >= 350 and prop[2] <= 625,"Props stay inside the scene corridor")
	check(themes == ["supply_road","riverbank","granary","switchback","marune_gate","supply_court"],"All six different chapter 2 scenery themes are present")
	for role in ["shield_spear","fire_archer","raider"]: check(roles.has(role),"Scheduled waves introduce " + role)
	check(boss_names == ["飯尾定宗","佐久間信盛","佐久間盛重"],"Boss names come from local Oda fort commanders")

func _living(battle: Battle) -> Array:
	return battle.state.fighters.filter(func(f): return f.team == 1 and f.hp > 0)

func _ticks(battle: Battle, count: int) -> void:
	for tick in range(count):
		battle.state.tick += 1
		battle._tick_segment()

func _kill_wave(battle: Battle) -> void:
	for fighter in _living(battle):
		fighter.hp = 0
		fighter.action = "defeated"
		fighter.action_tick = 300
		fighter.damage_tick = battle.state.tick

func _test_route(count: int) -> void:
	var battle := Battle.new()
	battle.reset_campaign("normal",count,["nobunaga","tadakatsu"],2)
	var inventories := []
	for player in battle.state.fighters.filter(func(f): return f.team == 0):
		Equipment.add(player,"sword_heshikiri" if player.kind == "nobunaga" else "spear_tonbokiri")
		Equipment.add(player,"sword_heshikiri" if player.kind == "nobunaga" else "spear_tonbokiri")
		Equipment.equip(player,Equipment.add(player,"war"))
		player.gold = 271+player.player_index
		player.rage = 38
		player.hp = 81
		inventories.append(player.inventory.duplicate(true))
	var waves := 0
	var checkpoint_count := 0
	var defense_bonus := 0
	for scene in range(6):
		check(battle.state.stage.index == scene and battle.state.stage.id == 2,"Chapter 2 progresses to scene " + str(scene+1))
		for checkpoint in range(2):
			checkpoint_count += 1
			check(battle.state.stage.checkpoint == checkpoint,"Correct checkpoint order")
			for wave in range(1,int(battle.state.stage.wave_total)+1):
				waves += 1
				check(battle.state.wave == wave and not battle.state.stage.go,"GO stays closed while scheduled enemies remain")
				check(Wire.valid_snapshot(battle.get_state()),"Valid wire: %dP scene %d checkpoint %d wave %d" % [count,scene+1,checkpoint+1,wave])
				var camera := Battle.camera_left(battle.state)
				for enemy in _living(battle):
					check(enemy.entering and (enemy.x <= camera-239 or enemy.x >= camera+1519),"Enemies arrive from beyond the viewport")
					check(enemy.entry_x >= 80 and enemy.entry_x <= battle.state.stage.encounter_end,"Enemy entry target is reachable inside the open corridor")
				_kill_wave(battle)
				_ticks(battle,76 if wave < battle.state.stage.wave_total else 46)
			for prop in battle.state.props:
				if prop.get("mandatory",false) and not prop.broken and prop.x < battle.state.stage.encounter_end:
					check(not battle.state.stage.go,"Mandatory current checkpoint barrier blocks GO")
					battle._damage_prop(prop,10000,battle.state.fighters[0].id)
			_ticks(battle,46)
			if checkpoint == 0 and scene in [0,2]: defense_bonus += 300 if scene == 0 else 450
			if scene == 5 and checkpoint == 1:
				check(battle.state.phase == "won","Only the final checkpoint wins chapter 2")
				continue
			check(battle.state.stage.go,"Every cleared checkpoint opens GO")
			var end: float = battle.state.stage.encounter_end
			var first: Dictionary = battle.state.fighters[0]
			first.x = end-100
			if count == 2:
				_ticks(battle,1)
				check(battle.state.stage.index == scene and battle.state.stage.checkpoint == checkpoint,"Living partner must reach GO before group transition")
				battle.state.fighters[1].x = end-120
			_ticks(battle,1)
			check(battle.state.stage.index == scene+(1 if checkpoint == 1 else 0),"Checkpoint or scene transition has no lock")
			for player in battle.state.fighters.filter(func(f): return f.team == 0):
				check(player.inventory == inventories[player.player_index],"Duplicate items and exact durability survive every transition")
				check(player.gold == 271+player.player_index+defense_bonus and player.hp == 81 and player.rage == 38,"Health, money, earned defense bonus and rage survive every transition")
			check(Wire.valid_snapshot(battle.get_state()),"Valid wire after %dP scene %d checkpoint %d" % [count,scene+1,checkpoint+1])
	check(checkpoint_count == 12 and waves >= 24,"Full six-scene, twelve-checkpoint route completed")

func _test_attack_smoke() -> void:
	var battle := Battle.new()
	battle.reset_campaign("normal",1,["tadakatsu"],2)
	var initial_ids := []
	for fighter in _living(battle): initial_ids.append(fighter.id)
	var damage_taken := 0
	var entered := {}
	for tick in range(10800):
		var player: Dictionary = battle.state.fighters[0]
		damage_taken += int(player.max_hp-player.hp)
		player.hp = player.max_hp
		var input := {"dx":0,"dy":0,"buttons":0}
		var target := {}
		var nearest := INF
		for enemy in _living(battle):
			if enemy.entering: continue
			entered[enemy.id] = true
			var distance := absf(enemy.x-player.x)+2*absf(enemy.y-player.y)
			if distance < nearest:
				nearest = distance
				target = enemy
		if not target.is_empty():
			var dx: float = target.x-player.x
			var dy: float = target.y-player.y
			if absf(dx) > 150: input.dx = int(signf(dx))
			if absf(dy) > 22: input.dy = int(signf(dy))
			if absf(dx) < 220 and absf(dy) < 32:
				if player.face != signi(int(dx)) and absf(dx) > 2: input.dx = int(signf(dx))
				elif tick % 3 == 0: input.buttons = Battle.HEAVY if target.get("role","") == "shield_spear" else Battle.LIGHT
			if player.action == "charge" and player.charge < 40: input.buttons = Battle.HEAVY
			if player.rage >= 100 and nearest < 400: input.buttons = Battle.SPECIAL
		battle.step([input])
		if tick % 120 == 0: check(Wire.valid_snapshot(battle.get_state()),"Attack-driven chapter 2 smoke has valid wire snapshots")
		if battle.state.wave > 1: break
	check(battle.state.wave > 1,"Real attacks defeat the first chapter 2 wave within three minutes")
	check(entered.size() >= initial_ids.size(),"All first-wave enemies actually enter the reachable corridor")
	check(battle.state.fighters[0].score > 0,"Input-driven attacks award real kill score")
	print("STAGE 2 ATTACK SMOKE ",JSON.stringify({"ticks":battle.state.tick,"wave":battle.state.wave,"damage_refilled":damage_taken,"entered":entered.size()}))

func _test_progression() -> void:
	var app := App.new()
	root.add_child(app)
	app.set_physics_process(false)
	var path := "user://stage2-route-%d" % Time.get_ticks_usec()
	app.profiles = Players.new(path,"user://missing-stage2-legacy.json")
	app._open_selection(false)
	check(app.chapter_choice.item_count == 1 and app.chapter_choice.get_item_metadata(0) == 1,"Fresh player cannot skip normal chapter progression")
	app._start_solo()
	app.sim.state.fighters[0].score = 2211
	Equipment.add(app.sim.state.fighters[0],"sword_heshikiri")
	Equipment.sync(app.sim.state.fighters[0])
	app.sim.state.phase = "won"
	check(app._save_characters(true) == OK,"First chapter completion saves")
	var second_id: String = app.profiles.selected[1]
	check(app.profiles.records[second_id].data.chapter == 1 and app.profiles.records[second_id].data.completed_chapter == 0,"Solo completion does not change the other local player")
	app._leave_to_menu()
	app._accept_confirmation()
	app.profiles = Players.new(path,"user://missing-stage2-legacy.json")
	app._open_selection(false)
	check(app.chapter_choice.item_count == 2 and app.chapter_choice.get_item_metadata(app.chapter_choice.selected) == 2,"Persisted chapter 1 completion unlocks and selects chapter 2")
	app._start_solo()
	check(app.sim.state.stage.id == 2 and app.sim.state.stage.index == 0 and app.sim.state.stage.checkpoint == 0,"Existing chapter 2 save enters the second chapter start")
	check(app.sim.state.fighters[0].score == 2211 and app.sim.state.fighters[0].inventory.size() == 1,"Starting chapter 2 restores carried gear and score; baseline occupies no slot")
	app.sim.state.phase = "won"
	check(app._save_characters(true) == OK,"Second chapter completion saves")
	app._leave_to_menu()
	app._accept_confirmation()
	app.profiles = Players.new(path,"user://missing-stage2-legacy.json")
	app._open_selection(false)
	check(app.profiles.data.chapter == 3 and app.profiles.data.completed_chapter == 2,"Chapter 2 completion stores chapter 3 without losing unlocked progress")
	check(app.chapter_choice.get_item_metadata(app.chapter_choice.selected) == 2 and app.character_panel.notice.text.contains("第3大關尚未開放"),"Unavailable next chapter selects latest released chapter and explains replay")
	app._open_selection(true)
	app.partner_heroes.selected = 0
	app._start_local_coop()
	check(app.sim.state.stage.id == 2 and app.session == "local","Host's unlocked second chapter supports local co-op")
	app.sim.state.fighters[0].score = 3333
	app.sim.state.fighters[1].score = 7777
	app.sim.state.phase = "won"
	check(app._save_characters(true) == OK,"Co-op completion saves both selected players")
	var restored := Players.new(path,"user://missing-stage2-legacy.json")
	check(restored.character(0,"nobunaga").score == 3333 and restored.character(1,"nobunaga").score == 7777,"Co-op character records remain independent")
	for id in restored.selected:
		check(restored.records[id].data.chapter == 3 and restored.records[id].data.completed_chapter == 2,"Both co-op accounts receive chapter 2 completion")
	app.paused = false
	app.sim._event("challenge_complete",280,510,0,0,{"amount":300})
	app._events(app.sim.state.events)
	app._update_achievement_banner(4.0)
	check(app.achievement_banner.visible and app.achievement_banner.text.contains("每名玩家 +300 金"),"Escort success banner reports the per-player reward")
	app.sim._event("challenge_failed",280,510,0,0)
	app._events(app.sim.state.events)
	app._events(app.sim.state.events)
	check(app._achievement_messages.size() == 1,"Repeated event packets do not duplicate challenge banners")
	app._update_achievement_banner(4.0)
	check(app.achievement_banner.visible and app.achievement_banner.text.contains("仍可繼續進軍"),"Escort failure banner makes optional progression clear")
	app.active = false
	app.free()
	await process_frame
