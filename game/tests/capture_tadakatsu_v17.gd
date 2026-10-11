extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
const TRIAL_TICKS := 240

class Formation extends Battle:
	func _enemy_input(fighter: Dictionary) -> void:
		fighter.move_dx = 0
		fighter.move_dy = 0

class App extends "res://main.gd":
	var capture_input := {"dx":0,"dy":0,"buttons":0}
	func _ready() -> void:
		testing = true
		super._ready()
	func _input_frame() -> Dictionary: return capture_input
	func _stop_rumble() -> void: pass

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v17/combat")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280,720)
	var app := App.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.sim = Formation.new()
	app.sim.boss_intros = {}
	var caption: Label = app.hud.duplicate()
	caption.position = Vector2(28,84)
	caption.add_theme_font_size_override("font_size",18)
	app.hud.get_parent().add_child(caption)
	var report := {"version":"0.17","fps":60,"input_driven":true,"setup":"Synthetic keyboard input against stationary durable soldiers. Native renderer and camera; no physical input or listening acceptance.","trials":[]}
	for trial in range(4):
		var slam := trial < 2
		var face := 1 if trial % 2 == 0 else -1
		app._close_network()
		app.session = "solo"
		app.training_active = true
		app.sim.reset_training("tadakatsu")
		app.sim.state.props.clear()
		app.sim.state.drops.clear()
		app.sim.state.civilian_spawn_enabled = false
		app.sim.state.fighters.resize(1)
		var player: Dictionary = app.sim.state.fighters[0]
		player.x = 1100.0
		player.y = 490.0
		player.face = face
		for side in [-1,1]:
			var enemy: Dictionary = app.sim._make_fighter(1,"soldier",player.x + side * 150.0,player.y,1000)
			enemy.home_x = enemy.x
			enemy.home_y = enemy.y
			app.sim.state.fighters.append(enemy)
		app._activate()
		app.audio.stop_speech()
		var record := {"trial":trial,"action":"charged_slam" if slam else "charged","face":face,"hold_frames":[],"release_frames":[],"captures":[],"trace":[],"events":[]}
		caption.text = ("本多忠勝｜長槍高舉蓄力 → 槍底重砸 → 全周震飛" if slam else "本多忠勝｜橫槍蓄力 → 連續平順突進 → 三次命中") + ("｜面右" if face > 0 else "｜面左")
		for tick in range(TRIAL_TICKS):
			var held := tick >= 20 and tick < 75
			app.capture_input = {"dx":0,"dy":1 if held and slam else 0,"buttons":Battle.HEAVY if held else 0}
			app._physics_process(1.0/60.0)
			app.view._update_motion()
			assert(Wire.valid_snapshot(app.sim.state))
			var sample: Dictionary = app.view._fighter_animation(player)
			if player.action == "charge" or player.action == record.action:
				assert(sample.source == "v17" and sample.count == 12,"Capture requires all accepted v17 source frames")
				var frames: Array = record.hold_frames if player.action == "charge" else record.release_frames
				if not frames.has(sample.frame): frames.append(sample.frame)
			var drawing: Dictionary = app.view._art.animation_frame("tadakatsu",sample)
			var scale: float = 155.0 / drawing.body_height
			var support: Vector2 = drawing.get("support_point",drawing.anchor)
			var support_offset: Vector2 = (support - drawing.anchor) * Vector2(face,1) * scale
			var foot_world := Vector2(player.x,player.y - player.z) + support_offset
			var foot_screen := foot_world - Vector2(app.view.camera_x,0)
			record.trace.append({"tick":tick,"x":player.x,"y":player.y,"z":player.z,"camera_x":app.view.camera_x,"action":player.action,"action_tick":player.action_tick,"sheet":sample.sheet,"frame":sample.frame,"body_height":drawing.body_height,"anchor":[drawing.anchor.x,drawing.anchor.y],"support_source":[support.x,support.y],"foot_world":[foot_world.x,foot_world.y],"foot_screen":[foot_screen.x,foot_screen.y]})
			for event in app.sim.state.events: record.events.append(event.duplicate())
			await process_frame
			if tick in [19,35,55,74,95,110,130,180,239]:
				await RenderingServer.frame_post_draw
				var filename := "trial-%d-tick-%03d.png" % [trial,tick]
				assert(root.get_texture().get_image().save_png(output.path_join(filename)) == OK)
				record.captures.append(filename)
		assert(record.hold_frames == range(12) and record.release_frames == range(12),"Native capture must render every preparation and release drawing")
		assert(player.action == "idle","Every recorded move must recover completely")
		if slam:
			assert(player.x == 1100.0,"Spear butt slam must remain planted")
			assert(app.sim.state.fighters[1].hp < 1000 and app.sim.state.fighters[2].hp < 1000,"Both sides are hit by the centered shockwave")
		else:
			assert(is_equal_approx((player.x - 1100.0) * face,156.0),"Native rushing move retains its complete intended travel")
			for tick in range(76,96):
				assert(absf(record.trace[tick].camera_x - record.trace[tick - 1].camera_x) < 9.0,"Rush cannot cause repeated 52px camera jumps")
		var largest_camera_step := 0.0
		var largest_foot_screen_step := 0.0
		for tick in range(1,TRIAL_TICKS):
			largest_camera_step = maxf(largest_camera_step,absf(record.trace[tick].camera_x - record.trace[tick - 1].camera_x))
			largest_foot_screen_step = maxf(largest_foot_screen_step,absf(record.trace[tick].foot_screen[0] - record.trace[tick - 1].foot_screen[0]))
		record["max_camera_step"] = largest_camera_step
		record["max_support_screen_step"] = largest_foot_screen_step
		report.trials.append(record)
	var file := FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report,"\t") + "\n")
	file.close()
	app.queue_free()
	await process_frame
	print("PASS: native v17 input-driven spear slam and smooth rush, both directions, all 12 preparation/release drawings")
	quit()
