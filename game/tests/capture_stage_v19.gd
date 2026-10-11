extends SceneTree

const Main = preload("res://main.gd")
var output := ""
var report := {"version":"0.19","capture":"Native main scene, current BattleView and two-player CombatHUD. Combat poses and clear states are staged for visual review; this does not claim an input-driven playthrough.","regions":[],"extra":[]}

class App extends Main:
	func _ready() -> void:
		testing = true
		super._ready()

func _initialize() -> void: run.call_deferred()

func capture(app: Node, filename: String) -> Image:
	app._update_view()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png(output.path_join(filename)) == OK)
	return image

func prepare(app: Node, scene: int, checkpoint: int) -> void:
	app.sim._enter_segment(scene)
	var spec: Dictionary = app.sim._campaign.segments[scene]
	var encounter: Dictionary = spec.encounters[checkpoint]
	var start := 0.0 if checkpoint == 0 else float(spec.encounters[checkpoint-1].end)
	for fighter in app.sim.state.fighters:
		if fighter.team != 0: continue
		fighter.x = start+650.0+fighter.player_index*180.0
		fighter.y = 515.0+fighter.player_index*24.0
		fighter.hp = 92 if fighter.player_index == 0 else 76
		fighter.rage = 67 if fighter.player_index == 0 else 100
		fighter.weapon = 1 if fighter.player_index == 0 else 0
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f):return f.team == 0)
	app.sim._start_checkpoint(checkpoint)
	if encounter.has("boss"):
		app.sim.state.fighters = app.sim.state.fighters.filter(func(f):return f.team == 0)
		app.sim.state.wave = encounter.waves.size()
		app.sim._spawn_segment_wave()
	app.sim.state.tick = 300+scene*41+checkpoint*73
	var camera: float = Main.Battle.camera_left(app.sim.state)
	var enemy_index := 0
	var poses := [Vector2(850,405),Vector2(1060,415),Vector2(940,485),Vector2(1160,505),Vector2(860,585),Vector2(1090,595)]
	for fighter in app.sim.state.fighters:
		if fighter.team == 0: continue
		fighter.entering = false
		var pose: Vector2 = poses[enemy_index % poses.size()]
		fighter.x = minf(float(spec.width)-140.0,camera+pose.x)
		fighter.y = pose.y
		fighter.face = -1
		fighter.action = "idle"
		fighter.action_tick = 0
		if fighter.kind == "boss":
			fighter.x = camera+1050.0
			fighter.y = 590.0
		enemy_index += 1
	app.sim.state.drops = [
		{"id":990001,"kind":"food","food_id":"rice","heal":35,"x":camera+660.0,"y":600.0},
		{"id":990002,"kind":"food","food_id":"peach","heal":60,"x":camera+815.0,"y":602.0}
	]

func run() -> void:
	output = ProjectSettings.globalize_path("res://../artifacts/native-v19/environment")
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
	app.session = "local"
	app.menu.hide()
	app.sim.reset_campaign("normal",2,["nobunaga","oichi"])
	var board := Image.create(1280,2520,false,Image.FORMAT_RGBA8)
	for scene in range(7):
		for checkpoint in range(2):
			prepare(app,scene,checkpoint)
			var filename := "%02d-%s-cp%d.png" % [scene+1,app.sim.state.stage.theme,checkpoint+1]
			var image: Image = await capture(app,filename)
			var backdrop: Dictionary = app.view._stage_art.background(str(app.sim.state.stage.theme))
			report.regions.append({"scene":scene+1,"checkpoint":checkpoint+1,"name":app.sim.state.stage.name,"theme":app.sim.state.stage.theme,"width":app.sim.state.stage.width,"camera_x":app.view.camera_x,"background":backdrop.source,"filename":filename,"players":app.combat_hud.players.size()})
			image.resize(640,360,Image.INTERPOLATE_LANCZOS)
			board.blit_rect(image,Rect2i(0,0,640,360),Vector2i(checkpoint*640,scene*360))
	assert(board.save_png(output.path_join("seven-scenes-fourteen-checkpoints.png")) == OK)
	prepare(app,0,0)
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f):return f.team == 0)
	app.sim.state.wave = app.sim.state.stage.wave_total
	app.sim.state.stage.go = true
	app.sim.state.stage.phase = "exit"
	await capture(app,"go-same-scene-left.png")
	var left_camera: float = app.view.camera_x
	for fighter in app.sim.state.fighters: fighter.x += 420.0
	await capture(app,"go-same-scene-right.png")
	report.extra.append({"purpose":"Same-scene GO and relative foreground/background movement","left":"go-same-scene-left.png","right":"go-same-scene-right.png","camera_delta":app.view.camera_x-left_camera,"scene_index":app.sim.state.stage.index,"checkpoint":app.sim.state.stage.checkpoint})
	prepare(app,6,0)
	app.sim.state.fighters = app.sim.state.fighters.filter(func(f):return f.team == 0)
	for prop in app.sim.state.props:
		if prop.get("mandatory",false) and prop.x < app.sim.state.stage.encounter_end:
			prop.hp = 0
			prop.broken = true
	app.sim.state.wave = app.sim.state.stage.wave_total
	app.sim.state.stage.go = true
	app.sim.state.stage.phase = "exit"
	await capture(app,"interior-screen-cabinet-go.png")
	report.extra.append({"purpose":"Interior cabinet, screen, broken mandatory screens and two-player HUD","filename":"interior-screen-cabinet-go.png"})
	var file := FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	file.close()
	app.queue_free()
	await process_frame
	print("PASS: v19 native capture: 7 scenes x 2 checkpoints, 2P HUD, GO/parallax pair and interior furniture. Staged visual evidence only.")
	quit()
