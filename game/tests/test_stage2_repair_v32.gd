extends SceneTree

const Main = preload("res://main.gd")
const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0
var capture := false

class App extends Main:
	var frame := {"dx":0,"dy":0,"buttons":0}
	func _input_frame() -> Dictionary: return frame
	func _set_game_focus(_focused: bool) -> void: pass

class RosterView extends View:
	func _fighter_animation(fighter: Dictionary) -> Dictionary:
		return fighter.review_sample
	func _draw() -> void:
		_fx.shared_player.begin_draw(self)
		draw_rect(Rect2(0,0,1800,1820),Color("42483f"))
		for fighter in state.fighters:
			var origin := Vector2(fighter.x,fighter.y)
			_draw_enemy_art(fighter,origin)
			Typography.draw_label(self,origin+Vector2(-140,28),fighter.review_label,15,Typography.PAPER,280,HORIZONTAL_ALIGNMENT_CENTER)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func shot(app: App, name: String) -> void:
	if not capture: return
	app._update_view()
	var before := var_to_bytes(app.sim.state)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(before == var_to_bytes(app.sim.state),"Native drawing does not change battle: "+name)
	var folder := OS.get_environment("TEST_ARTIFACT_DIR").path_join("screens")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(name+".png")) == OK,"Native main capture: "+name)

func exhausted(battle: Battle) -> Dictionary:
	var player: Dictionary = battle.state.fighters[1]
	player.hp = 0
	player.lives = 0
	player.action = "defeated"
	player.action_tick = 300
	player.respawn_ticks = 0
	player.gold = 1234
	player.score = 6789
	player.z = 42.0
	player.airborne_lock = true
	return player

func test_revive() -> void:
	for chapter in [1,2]:
		var battle := Battle.new()
		battle.reset_campaign("normal",2,["nobunaga","hideyoshi"],chapter)
		var player := exhausted(battle)
		var inventory := var_to_bytes(player.inventory)
		var id: int = player.id
		battle._spawn_segment_wave()
		check(player.hp == 0 and player.lives == 0,"New enemy wave does not revive an exhausted player")
		battle._start_checkpoint(1)
		check(player.hp == player.max_hp and player.lives == 1 and player.invuln == 180 and player.action == "recovering","Next checkpoint restores one life and full health")
		check(player.gold == 1234 and player.score == 6789 and var_to_bytes(player.inventory) == inventory and player.id == id,"Checkpoint revival preserves possessions and identity")
		check(player.z == 0 and not player.airborne_lock and Wire.valid_snapshot(battle.state),"Revival clears old death flight and validates wire")
		player = exhausted(battle)
		battle._enter_segment(1)
		player = battle.state.fighters[1]
		check(player.hp == player.max_hp and player.lives == 1 and player.gold == 1234,"Next scene also restores the exhausted partner")
		battle.state.fighters[0].hp = 0
		player = exhausted(battle)
		battle._revive_exhausted_party()
		check(player.hp == 0 and player.lives == 0,"Both defeated players receive no free revival")
	var solo := Battle.new()
	solo.reset_campaign()
	solo.state.fighters[0].hp = 0
	solo.state.fighters[0].lives = 0
	solo._revive_exhausted_party()
	check(solo.state.fighters[0].hp == 0,"Solo cannot receive a co-op revival")
	var crossing := Battle.new()
	crossing.reset_campaign("normal",2,["nobunaga","oichi"],2)
	var partner := exhausted(crossing)
	crossing.state.fighters = crossing.state.fighters.filter(func(f): return f.team == 0)
	crossing.state.props.clear()
	crossing.state.wave = crossing.state.stage.wave_total
	crossing.state.tick = 100
	crossing.state.stage.clear_tick = 55
	crossing._tick_segment()
	check(partner.hp == 0 and crossing.state.stage.go,"Clear and GO alone leave the exhausted partner waiting")
	crossing.state.fighters[0].x = crossing.state.stage.encounter_end-100
	crossing._tick_segment()
	check(crossing.state.stage.checkpoint == 1 and partner.hp == partner.max_hp and partner.lives == 1,"Survivor crossing the real GO boundary revives partner")
	check(crossing.state.events.filter(func(e): return e.type == "revive").size() == 1,"One earned crossing produces exactly one revival event")

func run() -> void:
	test_revive()
	var low := {"team":0,"hp":29,"max_hp":120}
	check(is_equal_approx(View.low_health_alpha(low,0),1) and is_equal_approx(View.low_health_alpha(low,75),.55) and is_equal_approx(View.low_health_alpha(low,150),1),"Red health smoothly pulses over 150 simulation ticks")
	for tick in range(150):
		check(absf(View.low_health_alpha(low,tick+1)-View.low_health_alpha(low,tick)) < .01,"Red warning has no abrupt flicker")
	low.hp = 30
	check(View.low_health_alpha(low,75) == 1,"Exactly 25 percent matches HUD healthy threshold")
	low.hp = 0
	check(View.low_health_alpha(low,75) == 1,"Dead body has no health warning")
	low.hp = 1; low.team = 1
	check(View.low_health_alpha(low,75) == 1,"Enemies have no player health warning")
	root.size = Vector2i(1280,720)
	var app := App.new()
	root.add_child(app)
	app.set_physics_process(false)
	app.testing = true
	app.active = true
	app.session = "solo"
	app.menu.hide()
	app.controls_dialog.hide()
	app.paused = false
	check(app.view._fx.configured and app.view._fx.shared_player.catalog.size() == 28,"Real Main initializes every shared VFX base")
	for hero in Battle.HEROES:
		for attack in ["light","heavy","charged","charged_slam","special"]:
			app.sim.reset_campaign("normal",1,[hero],2)
			app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0)
			app.sim.state.props.clear()
			app.sim.state.erase("challenge")
			app.sim.state.stage.wave_total = 1
			app.sim.state.stage.clear_tick = -1
			var player: Dictionary = app.sim.state.fighters[0]
			player.x = 520.0; player.y = 520.0
			var dummy := app.sim._make_fighter(1,"dummy",650,520,10000)
			app.sim.state.fighters.append(dummy)
			app.frame = {"dx":0,"dy":0,"buttons":Battle.LIGHT if attack == "light" else (Battle.SPECIAL if attack == "special" else Battle.HEAVY)}
			player.rage = 100
			if attack == "charged_slam": app.frame.dy = 1
			app._physics_process(1.0/60)
			if attack in ["charged","charged_slam"]:
				for tick in range(42): app._physics_process(1.0/60)
				await shot(app,"charge-"+hero+"-"+attack)
			app.frame = {"dx":0,"dy":0,"buttons":0}
			var released := false
			for tick in range(45):
				app._physics_process(1.0/60)
				if player.action == attack and app.view._fighter_animation(player).released:
					released = true
					break
			check(released,"Real Main input reaches "+hero+" "+attack+" release")
			check(app.view._fx.last_tick == app.sim.state.tick and app.view._fx.emitter.diagnostics.is_empty(),"Main syncs VFX at actual simulation time")
			await shot(app,"attack-"+hero+"-"+attack)
			if capture and attack == "charged" and hero in ["nobunaga","hideyoshi","tadakatsu"]: check(not app.view.get_meta("shared_vfx_meshes",[]).is_empty(),"Actual charged move retains native flowing VFX draw meshes")
	for group in [["soldier","flag","commander","archer","gunner"],["shield_spear","fire_archer","raider"]]:
		for pose in ["idle","attack","hurt","dead"]:
			app.sim.reset_campaign("normal",1,["nobunaga"],2)
			app.sim.state.fighters = []
			app.sim.state.props.clear()
			app.sim.state.erase("challenge")
			app.sim.state.tick = 75
			for index in range(group.size()):
				var enemy := app.sim._make_fighter(1,group[index],180+index*225,520,100)
				enemy.face = 1
				enemy.action = pose
				if pose == "attack": enemy.action = {"soldier":"spear_thrust","flag":"flag_sweep","commander":"commander_cut","archer":"bow_shot","gunner":"gun_shot"}[enemy.kind]
				enemy.action_tick = int(Battle.enemy_timing(enemy)[0])+2 if pose == "attack" else (300 if pose == "dead" else 8)
				if pose == "dead": enemy.hp = 0
				app.sim.state.fighters.append(enemy)
			await shot(app,"enemies-"+str(group.size())+"-"+pose)
	app.sim.reset_campaign("normal",1,["nobunaga"],2)
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0)
	app.sim.state.props.clear()
	app.sim.state.erase("challenge")
	app.sim.state.fighters[0].x = 520.0
	app.sim.state.fighters[0].y = 520.0
	var gunner := app.sim._make_fighter(1,"gunner",800,520,80)
	gunner.cooldown = 0
	app.sim.state.fighters.append(gunner)
	app.frame = {"dx":0,"dy":0,"buttons":0}
	for tick in range(48):
		app._physics_process(1.0/60)
		if app.sim.state.events.any(func(e): return e.type == "gunshot"): break
	check(app.sim.state.events.any(func(e): return e.type == "gunshot") and app.view._fx.emitter.instances.values().any(func(i): return i.recipe_id == "enemy_matchlock"),"Actual enemy AI and Main events trigger muzzle flash, smoke and sparks")
	await shot(app,"actual-enemy-matchlock")
	app.sim.reset_campaign("normal",2,["nobunaga","hideyoshi"],2)
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0)
	app.sim.state.props.clear()
	var lost_partner := exhausted(app.sim)
	lost_partner.z = 0.0; lost_partner.airborne_lock = false
	app.sim.state.tick = 100
	app.sim.state.wave = app.sim.state.stage.wave_total
	app.sim.state.stage.clear_tick = 55
	app._physics_process(1.0/60)
	check(lost_partner.hp == 0 and app.sim.state.stage.go,"Main keeps exhausted teammate waiting at GO")
	await shot(app,"coop-waiting-at-go")
	app.sim.state.fighters[0].x = app.sim.state.stage.encounter_end-100
	app._physics_process(1.0/60)
	check(lost_partner.hp == lost_partner.max_hp and lost_partner.lives == 1 and app.sim.state.stage.checkpoint == 1,"Main crossing restores one life and full health in HUD")
	await shot(app,"coop-next-checkpoint-revival")
	app.sim.reset_campaign("normal",2,["nobunaga","hideyoshi"],2)
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0)
	app.sim.state.props.clear()
	app.sim.state.erase("challenge")
	for player in app.sim.state.fighters:
		player.hp = 12
		player.x = 510+player.player_index*230
		player.y = 520
	for tick in [0,75,150]:
		app.sim.state.tick = tick
		await shot(app,"red-health-"+str(tick))
	app.sim.state.tick = 850
	app.sim.state.fighters[0].hp = 120
	app.sim.state.fighters[1].hp = 120
	app.sim.state.fighters[0].burn = 120
	app.sim.state.fighters[1].freeze = 120
	await shot(app,"status-after-850-ticks")
	var art = app.view._art
	for key in art.enemy_clips:
		if not str(key).begins_with("oda:") or str(key).contains(":poses") or str(key).contains(":attacks") or str(key).contains(":reactions"): continue
		for frame in art.enemy_clips[key]:
			check(frame.has("clip_polygon") and frame.frame_padding == Vector2(2,2),"Oda enemy source isolates adjacent sprites: "+str(key))
			if str(key).begins_with("oda:soldier:") and not str(key).ends_with(":death"):
				check(frame.has("shield_anchor") and Geometry2D.is_point_in_polygon(frame.shield_anchor+frame.anchor,frame.clip_polygon),"Shield strap anchors on the actual posed arm: "+str(key))
			if str(key).begins_with("oda:flag:"):
				check(frame.get("overlays",[]).size() == 1,"Every Oda flag pose replaces the Imagawa crest")
				var cloth: Dictionary = frame.overlays[0]
				check(cloth.clip_polygon.size() == cloth.uv_polygon.size() and not Geometry2D.triangulate_polygon(cloth.clip_polygon).is_empty(),"Flag cloth polygon is drawable")
	if capture:
		app.view.hide()
		for child in app.get_children():
			if child is CanvasLayer: child.hide()
		root.size = Vector2i(1800,1820)
		root.content_scale_size = Vector2i(1800,1820)
		var gallery := RosterView.new()
		root.add_child(gallery)
		gallery._fx.muted = true
		var roster := Battle.new()
		roster.reset_campaign("normal",1,["nobunaga"],2)
		for kind in ["soldier","flag","commander","archer","gunner","shield_spear","fire_archer","raider"]:
			var base_kind: String = Battle.ENEMY_ROLES.get(kind,kind)
			var entries := []
			for key in gallery._art.enemy_clips:
				if not str(key).begins_with("oda:"+base_kind+":"): continue
				var clip := str(key).get_slice(":",2)
				var frames: Array = gallery._art.enemy_clips[key]
				for index in range(frames.size()):
					var fighter := roster._make_fighter(1,kind,150+(entries.size()%6)*300,240+floori(entries.size()/6.0)*245,100)
					fighter.face = 1
					fighter.action = "dead" if clip == "death" else ("grabbed" if clip == "struggle" else clip)
					fighter.action_tick = 12
					if clip == "death": fighter.hp = 0
					fighter.review_sample = {"source":"v19","sheet":"enemy_clip:"+str(key),"cell":index,"frame":index,"count":frames.size(),"clip":clip,"released":index>=frames.size()/2,"tick":12}
					fighter.review_label = clip+" / "+str(index+1)
					entries.append(fighter)
			gallery.state = {"tick":850,"fighters":entries,"stage":{},"effects":[]}
			gallery.queue_redraw()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var folder := OS.get_environment("TEST_ARTIFACT_DIR").path_join("screens")
			check(root.get_texture().get_image().save_png(folder.path_join("all-poses-"+kind+".png")) == OK,"All production poses captured: "+kind)
		gallery.free()
	app.free()
	await process_frame
	print("STAGE 2 REPAIR V32 %s: %d checks, %d failures; real Main inputs and native draws, checkpoint revival and health warning." % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
