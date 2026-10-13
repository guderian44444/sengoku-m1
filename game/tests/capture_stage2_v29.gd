extends SceneTree

const Main = preload("res://main.gd")
const Equipment = preload("res://core/equipment.gd")
var output := ""
var report := {"version":"0.29","evidence":"Native renderer screenshots with staged positions/poses; not an input-driven playthrough or human difficulty review.","scenes":[],"poses":[],"bosses":[]}

class App extends Main:
	func _ready() -> void:
		testing = true
		super._ready()
	func _set_game_focus(_focused: bool) -> void: pass

func _initialize() -> void: run.call_deferred()

func capture(app: Node, filename: String) -> Image:
	var before := var_to_bytes(app.sim.state)
	if not app.menu.visible:
		app._camera_scene = -2
		app._update_view()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(var_to_bytes(app.sim.state) == before,"Rendering must not mutate battle state: " + filename)
	var image := root.get_texture().get_image()
	assert(image.save_png(output.path_join(filename)) == OK)
	return image

func prepare(app: Node, scene: int, checkpoint: int) -> void:
	app.sim._enter_segment(scene)
	var spec: Dictionary = app.sim._campaign.segments[scene]
	var encounter: Dictionary = spec.encounters[checkpoint]
	var start := 0.0 if checkpoint == 0 else float(spec.encounters[checkpoint-1].end)
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0)
	for fighter in app.sim.state.fighters:
		fighter.x = start+615.0
		fighter.y = 535.0
		fighter.rage = 67
	app.sim._start_checkpoint(checkpoint)
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0)
	app.sim.state.wave = encounter.waves.size()
	app.sim._spawn_segment_wave()
	app.sim.state.intro = {}
	app.sim.state.tick = 0
	var camera: float = Main.Battle.camera_left(app.sim.state)
	var poses := [Vector2(810,425),Vector2(1030,430),Vector2(900,505),Vector2(1160,520),Vector2(830,595),Vector2(1080,600)]
	var index := 0
	for fighter in app.sim.state.fighters:
		if fighter.team == 0: continue
		fighter.entering = false
		var pose: Vector2 = poses[index % poses.size()]
		fighter.x = minf(float(spec.width)-140.0,camera+pose.x)
		fighter.y = pose.y
		fighter.face = -1
		fighter.action = "idle"
		fighter.action_tick = 0
		fighter.cooldown = 70
		index += 1
	app.view._motion_tick = -1

func run() -> void:
	output = ProjectSettings.globalize_path("res://../artifacts/native-v29/stage2")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280,720)
	var app := App.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.audio.stop_music()
	app.audio.stop_speech()
	app.session = "solo"
	app.menu.hide()
	app.sim.reset_campaign("normal",1,["tadakatsu"],2)
	var player: Dictionary = app.sim.state.fighters[0]
	Equipment.equip(player,Equipment.add(player,"spear_tonbokiri"))
	Equipment.equip(player,Equipment.add(player,"war"))
	var board := Image.create(1280,2160,false,Image.FORMAT_RGBA8)
	for scene in range(6):
		for checkpoint in range(2):
			prepare(app,scene,checkpoint)
			var filename := "%02d-%s-cp%d.png" % [scene+1,app.sim.state.stage.theme,checkpoint+1]
			var image: Image = await capture(app,filename)
			var roles := []
			for fighter in app.sim.state.fighters:
				if fighter.team == 1 and fighter.get("role","") != "": roles.append(fighter.role)
			report.scenes.append({"name":app.sim.state.stage.name,"theme":app.sim.state.stage.theme,"checkpoint":checkpoint+1,"camera":app.view.camera_x,"roles":roles,"npcs":app.view._npc_samples(0.0).size(),"filename":filename})
			image.resize(640,360,Image.INTERPOLATE_LANCZOS)
			board.blit_rect(image,Rect2i(0,0,640,360),Vector2i(checkpoint*640,scene*360))
	assert(board.save_png(output.path_join("six-scenes-twelve-checkpoints.png")) == OK)
	prepare(app,1,0)
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0 or f.get("role","") == "fire_archer")
	player = app.sim.state.fighters[0]
	var archer: Dictionary = app.sim.state.fighters[1]
	player.x = 530.0
	player.y = 520.0
	archer.x = 1080.0
	archer.y = player.y
	archer.cooldown = 0
	app.sim._enemy_input(archer)
	assert(archer.action == "bow_shot")
	player.x = 740.0
	archer.action_tick = 30
	app.sim._tick_enemy_attack(archer)
	var arrow: Dictionary = app.sim.state.effects.filter(func(e): return e.type == "projectile")[0]
	for tick in range(int(arrow.flight_ticks)+40): app.sim._tick_effects()
	archer.action = "idle"
	archer.cooldown = 0
	app.sim._enemy_input(archer)
	assert(app.sim.state.effects.any(func(e): return e.type == "fire_patch") and app.sim.state.effects.any(func(e): return e.type == "arrow_target" and e.get("element","") == "fire"))
	await capture(app,"fire-lane-warning.png")
	var poses := [["idle",0,0.0],["light",8,0.0],["heavy",13,0.0],["jump",8,95.0],["down",12,0.0]]
	var pose_board := Image.create(1280,1800,false,Image.FORMAT_RGBA8)
	for index in range(poses.size()):
		prepare(app,1,0)
		app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0)
		player = app.sim.state.fighters[0]
		player.action = poses[index][0]
		player.action_tick = poses[index][1]
		player.z = poses[index][2]
		player.combo = 1
		player.heavy_combo = 1
		app.sim.state.tick = 600+index
		var filename := "shadow-%s.png" % poses[index][0]
		var image: Image = await capture(app,filename)
		report.poses.append({"action":player.action,"tick":player.action_tick,"z":player.z,"filename":filename})
		image.resize(640,360,Image.INTERPOLATE_LANCZOS)
		pose_board.blit_rect(image,Rect2i(0,0,640,360),Vector2i(0,index*360))
		var crop := root.get_texture().get_image().get_region(Rect2i(320,300,640,360))
		pose_board.blit_rect(crop,Rect2i(0,0,640,360),Vector2i(640,index*360))
	assert(pose_board.save_png(output.path_join("pose-shadows.png")) == OK)
	var boss_board := Image.create(1520,1440,false,Image.FORMAT_RGBA8)
	var boss_scenes := [1,3,5]
	for row in range(boss_scenes.size()):
		for pose in range(2):
			prepare(app,boss_scenes[row],1)
			app.sim.state.fighters = app.sim.state.fighters.filter(func(f): return f.team == 0 or f.kind == "boss")
			var boss: Dictionary = app.sim.state.fighters[1]
			boss.x = Main.Battle.camera_left(app.sim.state)+900.0
			boss.y = 535.0
			boss.action = "idle" if pose == 0 else "boss_thrust"
			boss.attack_variant = boss.boss_actions.find("boss_thrust")
			assert(boss.attack_variant >= 0,"Every chapter 2 spear boss has a thrust attack")
			boss.action_tick = 0 if pose == 0 else int(Main.Battle.enemy_timing(boss)[0])
			app.sim.state.tick = 720+row*2+pose
			var filename := "boss-%s-%s.png" % [boss.boss_variant,"idle" if pose == 0 else "thrust"]
			var image: Image = await capture(app,filename)
			report.bosses.append({"name":boss.display_name,"variant":boss.boss_variant,"faction":boss.faction,"action":boss.action,"tick":boss.action_tick,"filename":filename})
			boss_board.blit_rect(image,Rect2i(480,190,760,480),Vector2i(pose*760,row*480))
	assert(boss_board.save_png(output.path_join("three-bosses-idle-thrust.png")) == OK)
	app.active = false
	app.profiles.capture_chapter(1,true)
	app._open_selection(false)
	assert(app.chapter_choice.get_item_metadata(app.chapter_choice.selected) == 2)
	await capture(app,"chapter2-selection.png")
	var file := FileAccess.open(output.path_join("capture-report.json"),FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	file.close()
	app.free()
	await process_frame
	print("STAGE 2 CAPTURE V29 PASS: 6 scenes x 2 checkpoints, 5 pose/shadow samples, 3 bosses x idle/thrust, live-effect fire warning and unlocked selection. 25 native shots and 3 contact sheets; rendering left all battle snapshots unchanged. Staged native renderer evidence only.")
	quit()
