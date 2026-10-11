extends SceneTree

const Capture = preload("res://tests/capture_tadakatsu_v17.gd")
const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v17/extras")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280,720)
	var app := Capture.App.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.sim = Capture.Formation.new()
	app.sim.boss_intros = {}
	var caption: Label = app.hud.duplicate()
	caption.position = Vector2(28,84)
	caption.add_theme_font_size_override("font_size",18)
	app.hud.get_parent().add_child(caption)
	var report := {"version":"0.17","fps":60,"input_driven":true,"setup":"Native game renderer, real GRAB/SPECIAL/direction input. Stationary durable soldier; deterministic successful grip at the existing 50% escape check. No physical controller or audio acceptance.","trials":[]}
	for trial in range(4):
		var face := -1 if trial == 1 else 1
		app._close_network()
		app.session = "solo"
		app.training_active = true
		app.sim.reset_training("tadakatsu")
		app.sim.state.props.clear()
		app.sim.state.drops.clear()
		app.sim.state.civilian_spawn_enabled = false
		app.sim.state.fighters.resize(1)
		var player: Dictionary = app.sim.state.fighters[0]
		player.x = 800.0
		player.y = 490.0
		player.face = face
		var enemy: Dictionary = app.sim._make_fighter(1,"soldier",player.x + face * 82.0,player.y,1000)
		enemy.home_x = enemy.x
		enemy.home_y = enemy.y
		if trial == 3:
			enemy.x = 2200.0
			enemy.home_x = enemy.x
		app.sim.state.fighters.append(enemy)
		# The native 50% escape branch stays active; choose the reproducible non-escape half.
		if trial < 2:
			while ((app.sim.state.tick + 51) * 17 + player.id * 13 + enemy.id * 7) % 100 < 50:
				app.sim.state.tick += 1
		app._activate()
		app.audio.stop_speech()
		var record := {"trial":trial,"face":face,"initial_tick":app.sim.state.tick,"frames":{},"captures":[],"trace":[],"events":[]}
		caption.text = ["本多忠勝｜抓住 → 穩住人質 → 放開即摔｜面右","本多忠勝｜抓住 → 穩住人質 → 放開即摔｜面左","本多忠勝｜必殺：四次完整舞槍循環","本多忠勝｜走路12張 → 放開站定 → 雙擊跑步12張 → 放開站定"][trial]
		for tick in range(260):
			var buttons := Battle.GRAB if trial < 2 and tick >= 20 and tick < 110 else (Battle.SPECIAL if trial == 2 and tick == 20 else 0)
			var dx := 1 if trial == 3 and ((tick >= 20 and tick < 86) or tick == 110 or (tick >= 112 and tick < 176)) else 0
			app.capture_input = {"dx":dx,"dy":0,"buttons":buttons}
			app._physics_process(1.0/60.0)
			app.view._update_motion()
			assert(Wire.valid_snapshot(app.sim.state))
			var sample: Dictionary = app.view._fighter_animation(player)
			var sheet: String = sample.sheet
			var newly_seen: bool = not record.frames.has(sheet) or not record.frames[sheet].has(sample.frame)
			if not record.frames.has(sheet): record.frames[sheet] = []
			if newly_seen: record.frames[sheet].append(sample.frame)
			var drawing: Dictionary = app.view._art.animation_frame("tadakatsu",sample)
			var support: Vector2 = drawing.get("support_point",drawing.anchor)
			var support_offset: Vector2 = (support - drawing.anchor) * Vector2(face,1) * (155.0 / drawing.body_height)
			record.trace.append({"tick":tick,"dx":dx,"buttons":buttons,"x":player.x,"y":player.y,"z":player.z,"camera_x":app.view.camera_x,"action":player.action,"action_tick":player.action_tick,"sprinting":player.sprinting,"sheet":sheet,"frame":sample.frame,"body_height":drawing.body_height,"support_offset":[support_offset.x,support_offset.y],"enemy_x":enemy.x,"enemy_z":enemy.z,"enemy_action":enemy.action,"held_by":enemy.held_by})
			for event in app.sim.state.events: record.events.append(event.duplicate())
			if trial < 2 and tick >= 20 and tick < 110:
				assert(player.action == "holding" and enemy.held_by == player.id,"Native victim must stay held through all 12 registered poses")
			if trial < 2 and tick == 110:
				assert(player.action == "throw" and enemy.action == "thrown" and enemy.held_by == 0,"GRAB release must launch immediately")
			if trial == 3 and tick in [86,111,176]:
				assert(sheet == "v16_idle" and not player.sprinting,"Release returns to idle in the same simulation tick")
			await process_frame
			if newly_seen or tick in [109,110,111,175,176,259]:
				await RenderingServer.frame_post_draw
				var filename := "trial-%d-tick-%03d-%s-%02d.png" % [trial,tick,sheet,sample.frame]
				assert(root.get_texture().get_image().save_png(output.path_join(filename)) == OK)
				record.captures.append(filename)
		var expected: Array = ["v17_holding","v17_throw"] if trial < 2 else (["v17_special"] if trial == 2 else ["v16_walk","v16_run"])
		for sheet in expected:
			assert(record.frames.has(sheet) and record.frames[sheet].size() == 12,"Native continuous playback must reach every accepted drawing in " + sheet)
		assert(player.action == "idle","Recorded move recovers fully")
		if trial < 2: assert(enemy.hp < 1000,"Released throw damages the actual held soldier")
		report.trials.append(record)
	var file := FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report,"\t") + "\n")
	file.close()
	app.queue_free()
	await process_frame
	print("PASS: native holding/throw with victim in both directions, four special cycles, 12-frame walk/run and immediate stopping")
	quit()
