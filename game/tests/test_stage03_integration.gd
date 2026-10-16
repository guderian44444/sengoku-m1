extends SceneTree

const Main = preload("res://main.gd")
const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
const Art = preload("res://render/stage03_art.gd")
var checks := 0
var output := ""

class App extends Main:
	func _connected_pads() -> Array[int]: return [3,7]
	func _set_game_focus(_focused: bool) -> void: pass

func check(ok: bool, message: String) -> void:
	checks += 1
	assert(ok,message)

func _initialize() -> void: run.call_deferred()

func capture(app: Node, name: String) -> void:
	if output.is_empty(): return
	app._camera_scene = -1
	app._update_view()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"Native capture: "+name)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if not output.is_empty():
		check(DisplayServer.get_name() != "headless","Captures require native renderer")
		DirAccess.make_dir_recursive_absolute(output)
		root.size = Vector2i(1280,720)
	var app := App.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.testing = true
	var profile_dir := "user://stage03-integration-%d" % Time.get_ticks_usec()
	app.profiles = Main.PlayerStore.new(profile_dir,"user://missing-stage03-legacy.json")
	app._open_selection(true)
	app.profiles.capture_chapter(2,true)
	app._refresh_chapters()
	check(app.chapter_choice.item_count == 3,"Completing chapter 2 unlocks chapter 3 in the real menu")
	var art := Art.new()
	var hashes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Art.ROOT+"SHA256.json"))
	for path in hashes: check(FileAccess.get_sha256(Art.ROOT+path) == hashes[path],"Unmodified delivered PNG: "+path)
	app.chapter_choice.select(2)
	app._start_local_coop()
	check(app.active and app.sim.state.stage.id == 3 and app.sim.state.fighters.filter(func(f):return f.team==0).size() == 2,"Normal menu starts the unlocked chapter for both players")
	var seen := {}
	for scene in range(4):
		app.sim._enter_segment(scene)
		for f in app.sim.state.fighters:
			if f.team == 0: f.x = 650+f.player_index*100
			else:
				f.entering = false
				f.moving = false
				f.x = 950+(f.id%3)*100
		check(Wire.valid_snapshot(app.sim.get_state()),"Four scenes use valid authoritative state")
		check(app.view._stage_art.background(app.sim.state.stage.theme,3,scene).source.begins_with("res://assets/stage3/"),"Dedicated camp background")
		app._update_view()
		check(not app.objective_scroll.order.is_empty(),"Current objective UI handles third-chapter encounters")
		await capture(app,"scene-%d" % scene)
		if scene == 2:
			for f in app.sim.state.fighters:
				if f.team == 0: f.x = 2450 + f.player_index*100
			await capture(app,"tent-door")
		for f in app.sim.state.fighters:
			if f.team != 1: continue
			var actor := Art.actor_id(app.sim.state,f)
			seen[actor] = f.duplicate(true)
			verify_actor(art,app.sim.state,f)
		if scene == 0:
			for prop in app.sim.state.props:
				if prop.kind == "bell_pillar": app.sim._damage_prop(prop,10000,app.sim.state.fighters[0].id)
			Battle.Stage03Encounter.tick(app.sim)
			app._update_view()
			check(not app.audio._alarm_player.playing,"All broken supports stop the loop")
			for tick in range(45): app.sim.step([])
			await capture(app,"bell-broken")
	var sim = app.sim
	for row in sim.state.encounter.leaders:
		var leader: Dictionary = sim._fighter(row.id)
		sim._damage(leader,10000,sim.state.fighters[0].id,true,false,true)
	Battle.Stage03Encounter.tick(sim)
	for tick in range(91): sim.step([])
	var yoshi: Dictionary = sim._fighter(sim.state.encounter.yoshimoto_id)
	check(not yoshi.is_empty(),"Both lieutenants transition to Yoshimoto")
	yoshi.entering = false
	yoshi.x = 1200
	yoshi.y = 480
	seen[Art.actor_id(sim.state,yoshi)] = yoshi.duplicate(true)
	verify_actor(art,sim.state,yoshi)
	check(seen.size() == 6 and not seen.has(""),"All six delivered enemies have live bindings")
	check(sim.state.intro.name == "今川義元" and sim.state.intro.line_key != "","Existing Yoshimoto introduction and voice are connected")
	sim.state.intro = {}
	for action in ["boss_arrow","boss_sword_wave"]:
		sim.state.effects.clear()
		yoshi.action = action
		yoshi.action_tick = Battle.enemy_timing(yoshi)[0]
		yoshi.aim_face = -1
		yoshi.aim_dx = -1.0
		yoshi.aim_dy = 0.0
		Battle.Stage03Encounter.Tent.Yoshimoto.release(sim,yoshi)
		check(Wire.valid_snapshot(sim.get_state()),"Socket-aligned projectile passes wire validation")
		var shot: Dictionary = sim.state.effects.filter(func(e):return e.get("yoshimoto_projectile",false))[0]
		check(shot.z == 28.0 and shot.visual_height > 0,"Visual socket preserves collision height")
		if action == "boss_sword_wave":
			var release_event: Dictionary = sim.state.events.filter(func(e):return e.type == "weapon_swing" and e.get("action","") == action)[0]
			check(not app.view._fx.accept_event(release_event,sim.state,app.view),"Shared slash audio leaves the dedicated sword-wave cue to CombatAudio")
			app.audio.play_event(release_event)
			check(app.audio.last_sound == "sword_air","Actual release selects the new sword-wave sound")
		await capture(app,action)
	sim._damage(yoshi,10000,sim.state.fighters[0].id,true,false,true)
	sim.step([])
	app._update_view()
	check(sim.state.phase == "won" and app.audio._music_key == "victory_jingle","Yoshimoto defeat immediately reaches the common victory score")
	for tick in range(60): app._physics_process(1.0/60.0)
	app.testing = false
	check(app._save_characters(true) == OK,"Normal completion save succeeds in the isolated test profile")
	app.testing = true
	var saved := Main.PlayerStore.new(profile_dir,"user://missing-stage03-legacy.json")
	for id in saved.selected:
		check(saved.records[id].data.completed_chapter == 3,"Each player's third-chapter clear survives reloading")
	await capture(app,"victory")
	if not output.is_empty(): await capture_poses(app,seen)
	app.queue_free()
	await process_frame
	print("STAGE03 INTEGRATION PASS: %d checks; native captures are arranged states, not human playthrough" % checks)
	quit()

func capture_poses(app: Node, actors: Dictionary) -> void:
	app.objective_scroll.hide()
	app.combat_hud.hide()
	app.end_label.hide()
	for pose in ["idle","attack","down","launched"]:
		for face in [-1,1]:
			var world: Dictionary = app.sim.state.duplicate(true)
			world.fighters = []
			world.effects = []
			world.drops = []
			world.props = []
			app.view._fx.reset_scene()
			for actor in actors:
				var f: Dictionary = actors[actor].duplicate(true)
				var i: int = world.fighters.size()
				f.x = [260.0,640.0,1020.0][i%3]
				f.y = 370.0 if i < 3 else 630.0
				f.face = face
				f.hp = f.max_hp
				f.encounter_epoch = world.encounter.epoch
				f.entering = false
				f.freeze = 0
				f.action = pose if pose != "attack" else {"ii_naomori":"boss_thrust","ujinori":"boss_sweep","yoshimoto":"boss_sword_wave","archer":"bow_shot"}.get(actor,"spear_thrust")
				f.action_tick = Battle.enemy_timing(f)[0] if pose == "attack" else 60
				f.z = 50 if pose == "launched" else 0
				world.fighters.append(f)
			app.view.camera_x = 0
			app.view.state = world
			app.view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("poses-%s-%d.png" % [pose,face])) == OK,"Native pose sheet")

func verify_actor(art: RefCounted, world: Dictionary, fighter: Dictionary) -> void:
	var proxy := fighter.duplicate(true)
	for action in ["idle","hurt","down","recovering","grabbed","thrown","launched","stunned","guard","defeated"]:
		proxy.action = action
		proxy.action_tick = 500
		for face in [-1,1]:
			proxy.face = face
			var sample: Dictionary = art.sample(world,proxy,12,30)
			check(sample.source == "stage3" and sample.frame_data.texture != null,"State coverage: %s/%s/%d" % [Art.actor_id(world,proxy),action,face])
	proxy.action = "idle"
	proxy.moving = true
	var walk: Dictionary = art.sample(world,proxy,24,24)
	check(walk.clip == "walk","Live movement selects the actual walk frames")
	var actor := Art.actor_id(world,proxy)
	var actions: Array = ["boss_arrow","boss_sword_wave","boss_sweep"] if actor == "yoshimoto" else (["boss_thrust"] if actor == "ii_naomori" else (["boss_sweep"] if actor == "ujinori" else (["bow_shot"] if actor == "archer" else ["spear_thrust"])))
	for action in actions:
		proxy.action = action
		var timing := Battle.enemy_timing(proxy)
		proxy.action_tick = timing[0]-1
		check(not art.sample(world,proxy,0,0).released,"Windup remains before authority release")
		proxy.action_tick = timing[0]
		var sample: Dictionary = art.sample(world,proxy,0,0)
		check(sample.released and sample.frame in [2,3,4],"Source impact pose coincides with authority release: "+actor+"/"+action)
		proxy.action_tick = 10000
		check(art.sample(world,proxy,0,0).frame == sample.count-1,"One-shot attack holds its last frame")
	var wrong_stage := world.duplicate(true)
	wrong_stage.stage.id = 1
	check(Art.actor_id(wrong_stage,proxy) == "","Existing first-chapter art stays scoped")
