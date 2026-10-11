extends SceneTree
const Main = preload("res://main.gd")
const Frames = preload("res://render/frame_animation.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app._start_solo()
	app._physics_process(1.0 / 60.0)
	var saved := JSON.stringify(app.sim.get_state())
	app._start_art_demo()
	assert(app.demo_active and not app.active)
	assert(app.session == "solo" and app.remote_id == 0)
	app._physics_process(0.8)
	assert(JSON.stringify(app.sim.get_state()) == saved, "Demo must not mutate the battle simulation")
	assert(app.view.art_demo and app.view.state.fighters.size() == 2)
	app._toggle_art_demo()
	var elapsed: float = app.art_demo.elapsed
	app._physics_process(5.0)
	assert(app.art_demo.elapsed == elapsed)
	app._seek_art_demo(1)
	assert(app.art_demo.pose() == 1 and not app.art_demo.running)
	var sample: Dictionary = app.view.animation_sample()
	app._step_art_frame(1)
	var next: Dictionary = app.view.animation_sample()
	assert(sample.frame != next.frame or sample.clip != next.clip)
	assert(not app.art_demo.running and app.art_demo.pose() == 1)
	app._step_art_frame(-1)
	assert(app.view.animation_sample().frame == sample.frame)
	app._toggle_art_speed()
	assert(app.art_demo.speed == 0.5)
	var flip := InputEventKey.new()
	flip.physical_keycode = KEY_F
	flip.pressed = true
	app._input(flip)
	assert(app.view.state.fighters[0].face == -1)
	_check_hd_routes(app)
	app._leave_to_menu()
	assert(not app.demo_active and not app.view.art_demo and app.view.demo_pose == -1)
	assert(app.menu.visible and not app.demo_controls.visible)
	app._start_solo()
	assert(app.active and not app.demo_active and app.sim.state.wave == 1)
	app._physics_process(1.0 / 60.0)
	assert(app.view.state == app.sim.state)
	print("PASS: showcase isolated from battle and networking; pause/seek/facing; return to solo")
	app.queue_free()
	quit()

func _check_hd_routes(app) -> void:
	var sheets := {1:"light1",2:"heavy1",3:"heavy2",4:"air_light",5:"throw",6:"hurt",7:"special",8:"victory",9:"walk"}
	for pose in sheets:
		app.art_demo.elapsed = pose * 2.4 + 0.5
		app._update_art_demo()
		for hero in ["nobunaga", "oichi"]:
			var sample: Dictionary = app.view.animation_sample(hero)
			var version := "v12"
			for candidate in ["v15","v14","v13"]:
				if app.view._art.animations[hero].has(candidate + "_" + sheets[pose]):
					version = candidate
					break
			assert(sample.source == version and sample.sheet == version + "_" + sheets[pose], "%s showcase pose %d uses matching HD route: %s" % [hero, pose, JSON.stringify(sample)])
	for frame in range(12):
		app.art_demo.elapsed = 8 * 2.4 + (frame * 10 + 1) / 60.0
		app._update_art_demo()
		for hero in ["nobunaga", "oichi"]:
			if app.view._art.animations[hero].has("v15_victory"):
				assert(app.view.animation_sample(hero).frame == frame, "The compact showcase includes all twelve new celebration drawings")
	for pose in [1,2,4,5,6,7]:
		for seconds in [0.1,2.35]:
			app.art_demo.elapsed = pose * 2.4 + seconds
			app._update_art_demo()
			for hero in ["nobunaga", "oichi"]:
				assert(app.view.animation_sample(hero).clip == "idle", hero + " showcase holds idle before and after the action")
	for pose in [4,5,7]:
		var hit: float = {4:16.0,5:12.0,7:26.0}[pose]
		var duration: float = Frames.CLIPS[Frames.POSE_CLIPS[pose]].duration
		for tick in [hit - 0.25,hit + 0.25,duration - 0.25]:
			app.art_demo.elapsed = pose * 2.4 + Frames.DEMO_HOLD + tick / (60.0 * Frames.DEMO_SPEED)
			app._update_art_demo()
			for hero in ["nobunaga", "oichi"]:
				var sample: Dictionary = app.view.animation_sample(hero)
				assert(sample.source == "v12" and sample.frame == (5 if tick < hit else (6 if tick < hit + 1 else 11)), hero + " compact showcase matches release and full recovery frames")
	for hero in ["hideyoshi","ieyasu","mitsuhide","tadakatsu"]:
		assert(app.view._fighter_animation({"kind":hero,"team":0,"action":"light","action_tick":6}).source != "v12", "Other heroes keep their existing showcase route")
	for pose in [1,2,4,7]:
		var clip: String = Frames.POSE_CLIPS[pose]
		var hit: float = 16.0 if pose == 4 else float(Frames.CLIPS[clip].hit)
		for tick in [hit + 0.25,float(Frames.CLIPS[clip].duration) + 1.0]:
			app.art_demo.elapsed = pose * 2.4 + Frames.DEMO_HOLD + tick / (60.0 * Frames.DEMO_SPEED)
			app._update_art_demo()
			var launch: Dictionary = app.view._demo_projectile_sample(app.view.state.fighters[1],clip,hit)
			assert(launch.source == "v12" and launch.sheet == "v12_" + sheets[pose] and launch.cell == 6, "Demo projectile retains the HD release pose even after the character returns to idle")
			var frame: Dictionary = app.view._art.animations.oichi[launch.sheet][6]
			assert(app.view._art.projectile_origin(launch,225).is_equal_approx(frame.hand_offset * 225.0 / frame.body_height), "Demo projectile uses the same measured HD hand at showcase scale")
	var hd_light: Array = app.view._art.animations.oichi.v12_light1
	app.view._art.animations.oichi.erase("v12_light1")
	var fallback: Dictionary = app.view._demo_projectile_sample({"kind":"oichi","combo":1},"light",6)
	app.view._art.animations.oichi.v12_light1 = hd_light
	assert(fallback.sheet == "combo", "Missing HD clip keeps the existing demo projectile fallback")
