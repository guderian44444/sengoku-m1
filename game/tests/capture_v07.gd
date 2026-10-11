extends SceneTree
const Main = preload("res://main.gd")
const TITLES := ["信長｜左右行走：接觸・通過・換腳", "信長｜按住 K：刀焰與地圈由小到大", "信長｜W＋J 上挑，輕型小兵浮空", "信長｜S＋K 震地，擴散震波命中多敵", "阿市｜左右行走：小步幅與自然換腳", "阿市｜按住 K 滿弓保持，放開射擊"]

func _initialize() -> void:
	_run.call_deferred()

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _reset(app: Node, hero: String) -> void:
	for action in Main.CONTROL_ACTIONS: Input.action_release(action)
	app.selected_hero = hero
	app.heroes.selected = 1 if hero == "oichi" else 0
	app.training_drill = "dummy"
	app._reset_training()

func _target(app: Node, x: float) -> void:
	var dummy: Dictionary = app.sim.state.fighters[1]
	dummy.x = x
	dummy.home_x = x

func _soldier(app: Node, x: float, y: float = 480.0) -> Dictionary:
	var soldier: Dictionary = app.sim._make_fighter(1, "soldier", x, y, 1000)
	soldier.home_x = x
	soldier.home_y = y
	soldier.cooldown = 10000
	app.sim.state.fighters.append(soldier)
	return soldier

func _run() -> void:
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	# This fixture owns keyboard input; desktop focus changes must not alter the recording.
	for signal_name in ["focus_exited", "focus_entered"]:
		for connection in root.get_signal_connection_list(signal_name): root.disconnect(signal_name, connection.callable)
	app._set_game_focus(true)
	app._start_training()
	var caption: Label = app.hud.duplicate()
	caption.position = Vector2(28, 120)
	caption.add_theme_font_size_override("font_size", 23)
	app.hud.get_parent().add_child(caption)
	var report: Array = []
	var soldiers: Array = []
	var walk_cells := {}
	for frame in range(1080):
		var trial := frame / 180
		if frame % 180 == 0:
			_reset(app, "nobunaga" if trial < 4 else "oichi")
			caption.text = TITLES[trial]
			soldiers = []
			walk_cells = {}
			if trial in [0, 4]:
				app.sim.state.fighters[0].x = 400.0
				_target(app, 1240.0)
			elif trial == 2:
				_target(app, 1120.0)
				soldiers.append(_soldier(app, 610.0))
			elif trial == 3:
				_target(app, 1100.0)
				for point in [Vector2(650, 470), Vector2(765, 515), Vector2(420, 460)]:
					soldiers.append(_soldier(app, point.x, point.y))
			elif trial == 5:
				_target(app, 1040.0)
		for half in range(2):
			var tick := (frame % 180) * 2 + half
			if trial in [0, 4]:
				if tick == 15: _key(KEY_D, true)
				if tick == 135: _key(KEY_D, false)
				if tick == 165: _key(KEY_A, true)
				if tick == 285: _key(KEY_A, false)
			elif trial in [1, 5]:
				if tick == 30: _key(KEY_K, true)
				if tick == 200: _key(KEY_K, false)
				if trial == 1:
					if tick == 265: _key(KEY_K, true)
					if tick == 325: _key(KEY_K, false)
				elif tick == 255:
					_reset(app, "oichi")
					_target(app, 630.0)
					soldiers.append(_soldier(app, 690.0, 505.0))
					caption.text = "阿市｜W＋J 上揚短針，輕型小兵浮空"
				if trial == 5 and tick == 285:
					_key(KEY_W, true)
					_key(KEY_J, true)
				if trial == 5 and tick == 287:
					_key(KEY_W, false)
					_key(KEY_J, false)
			elif trial == 2:
				if tick in [30, 210]:
					_key(KEY_W, true)
					_key(KEY_J, true)
				if tick in [32, 212]:
					_key(KEY_W, false)
					_key(KEY_J, false)
			elif trial == 3:
				if tick in [30, 210]:
					_key(KEY_S, true)
					_key(KEY_K, true)
				if tick in [32, 212]:
					_key(KEY_S, false)
					_key(KEY_K, false)
			app._physics_process(1.0 / 60.0)
			assert(not app.paused and app.training_active)
			var player: Dictionary = app.sim.state.fighters[0]
			if trial in [0, 4]:
				var sample: Dictionary = app.view.animation_sample(str(player.kind))
				if sample.clip == "walk": walk_cells[sample.cell] = true
				if tick == 285:
					assert(is_equal_approx(player.x, 400.0) and walk_cells.size() == 4, "Both directions must walk at real input speed through all four gait frames")
			if trial in [1, 5] and tick in [65, 120, 180]:
				assert(player.action == "charge" and player.charge >= 35 and is_equal_approx(player.x, 500.0), "Charge must hold without movement until K release")
				if trial == 5:
					assert(app.view.animation_sample("oichi").cell == 11, "Full-draw Oichi holds the same bow frame until release")
			if trial in [1, 5] and tick == 250: assert(app.sim.state.training.hit_count > 0, "Releasing charged K must produce a real hit")
			if trial == 2 and tick == 40: assert(soldiers[0].z > 0 and soldiers[0].hp < 1000, "W+J must launch a real light soldier")
			if trial == 3 and tick == 75: assert(soldiers.all(func(enemy: Dictionary) -> bool: return enemy.hp < 1000), "Expanding ground wave must hit all three soldiers")
			if trial == 5 and tick == 300: assert(soldiers[0].z > 0 and soldiers[0].hp < 1000, "Oichi directional needle must launch a real light soldier")
		await process_frame
		if frame % 180 in [10, 18, 20, 24, 30, 42, 65, 85, 100, 112, 135, 150]:
			await RenderingServer.frame_post_draw
			var file := output.path_join("v07-%d-%03d.png" % [trial, frame % 180])
			assert(root.get_texture().get_image().save_png(file) == OK)
			report.append({"file": file, "trial": trial, "frame": frame, "fighters": app.sim.state.fighters.duplicate(true), "effects": app.sim.state.effects.duplicate(true)})
	var file := FileAccess.open(output.path_join("v07.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("PASS: 36-second v0.7 keyboard capture: bidirectional gait, growing charge, stable full draw, rising launchers and ground shockwave")
	app.queue_free()
	quit()
