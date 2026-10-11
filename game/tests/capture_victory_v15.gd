extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
const TRIAL_TICKS := 600

class Formation extends Battle:
	func _enemy_input(fighter: Dictionary) -> void:
		fighter.move_dx = 0
		fighter.move_dy = 0

class App extends "res://main.gd":
	var capture_input := {"dx":0,"dy":0,"buttons":0}
	func _ready() -> void:
		testing = true
		super._ready()
	func _connected_pads() -> Array[int]: return [3,7]
	func _stop_rumble() -> void: pass
	func _input_frame() -> Dictionary: return capture_input
	func _partner_frame() -> Dictionary: return _neutral()

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v15/victory")
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
	var report := {"version":"0.15","fps":60,"input_driven":true,"setup":"Final wave staged with one stationary 1 HP soldier. Actual player attack triggers damage, death and victory. Co-op uses synthetic controller slots; no physical controller acceptance.","trials":[]}
	for trial in range(3):
		var hero := "oichi" if trial == 1 else "nobunaga"
		app._close_network()
		app.session = "local" if trial == 2 else "solo"
		app.sim.reset("normal",2 if trial == 2 else 1,[hero,"oichi"],"mori")
		app.sim.state.wave = 3
		app.sim.state.props.clear()
		app.sim.state.drops.clear()
		app.sim.state.civilian_spawn_enabled = false
		app.sim.state.fighters = app.sim.state.fighters.filter(func(f: Dictionary) -> bool: return f.team == 0)
		for fighter in app.sim.state.fighters:
			fighter.x = 500 + fighter.player_index * 180
			fighter.y = 480 + fighter.player_index * 65
			fighter.face = 1
		var target: Dictionary = app.sim._make_fighter(1,"soldier",565,480,1)
		app.sim.state.fighters.append(target)
		app._activate()
		app.audio.stop_speech()
		var record := {"trial":trial,"heroes":[hero,"oichi"] if trial == 2 else [hero],"victory_frames":{},"lines":[],"captures":[],"events":[],"won_tick":-1}
		caption.text = ["信長｜最後一刀清場 → 高舉武士刀 → 勝利台詞","阿市｜最後一箭清場 → 露肩回眸 → 勝利台詞","雙人合作｜各播 12 張慶祝圖 → 台詞依序播放"][trial]
		for tick in range(TRIAL_TICKS):
			app.capture_input = {"dx":0,"dy":0,"buttons":Battle.HEAVY if hero == "oichi" and tick == 20 else (Battle.LIGHT if hero != "oichi" and tick == 20 else 0)}
			app._physics_process(1.0/60.0)
			app.view._update_motion()
			assert(Wire.valid_snapshot(app.sim.state))
			for event in app.sim.state.events: record.events.append(event.duplicate())
			if app.sim.state.phase == "won" and record.won_tick < 0: record.won_tick = tick
			for fighter in app.sim.state.fighters:
				if fighter.team != 0 or fighter.action != "victory": continue
				var sample: Dictionary = app.view._fighter_animation(fighter)
				assert(sample.source == "v15" and sample.count == 12, "Capture requires accepted v15 PNGs")
				if not record.victory_frames.has(fighter.kind): record.victory_frames[fighter.kind] = []
				if not record.victory_frames[fighter.kind].has(sample.frame): record.victory_frames[fighter.kind].append(sample.frame)
			if not app._victory_subtitle.is_empty() and not record.lines.has(app._victory_subtitle): record.lines.append(app._victory_subtitle)
			await process_frame
			if tick in [19,35,60,90,120,150,180,300,599]:
				await RenderingServer.frame_post_draw
				var filename := "trial-%d-tick-%03d.png" % [trial,tick]
				assert(root.get_texture().get_image().save_png(output.path_join(filename)) == OK)
				record.captures.append(filename)
		assert(record.won_tick >= 20 and target.hp == 0, "Actual attack must clear the staged wave")
		assert(record.lines.size() == (2 if trial == 2 else 1), "Every living winner speaks exactly once")
		for frames in record.victory_frames.values(): assert(frames.size() == 12, "Every authored drawing reaches the native renderer")
		assert(record.victory_frames.size() == (2 if trial == 2 else 1))
		report.trials.append(record)
	var file := FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report,"\t") + "\n")
	file.close()
	app.queue_free()
	await process_frame
	print("PASS: native v15 capture; three input-driven victories, all twelve frames, four sequential victory lines")
	quit()
