extends SceneTree
const Main = preload("res://main.gd")
const TITLES := ["信長｜下砍・上揮挑飛・寬幅橫掃", "信長｜二段重刀，再試大範圍無敵必殺", "阿市｜左手・右手・轉身飛針；短射程", "阿市｜二段長弓；蓄力箭橫跨畫面", "阿市｜貫穿長箭必殺・暈眩控場", "信長｜按住抓人擋箭，放開飛摔", "阿市｜肉盾受痛，再投向小兵", "阿市｜抓滿三秒自動放下，不會自動摔"]

func _initialize() -> void:
	_run.call_deferred()

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _reset(app: Node, hero: String, shield: bool = false) -> void:
	for action in Main.CONTROL_ACTIONS: Input.action_release(action)
	app.selected_hero = hero
	app.heroes.selected = 1 if hero == "oichi" else 0
	app.training_drill = "shield" if shield else "dummy"
	app._reset_training()

func _target(app: Node, x: float, y: float = 480.0) -> void:
	var dummy: Dictionary = app.sim.state.fighters[1]
	dummy.x = x
	dummy.y = y
	dummy.home_x = x
	dummy.home_y = y

func _extra_dummy(app: Node, x: float, y: float) -> void:
	var dummy: Dictionary = app.sim._make_fighter(1, "dummy", x, y, 1000)
	dummy.home_x = x
	dummy.home_y = y
	app.sim.state.fighters.append(dummy)

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
	# The fixture owns its keyboard events; desktop focus must not pause the recording.
	for signal_name in ["focus_exited", "focus_entered"]:
		for connection in root.get_signal_connection_list(signal_name): root.disconnect(signal_name, connection.callable)
	app._set_game_focus(true)
	app._start_training()
	var caption: Label = app.hud.duplicate()
	caption.position = Vector2(28, 120)
	caption.add_theme_font_size_override("font_size", 23)
	app.hud.get_parent().add_child(caption)
	var report: Array = []
	var shield_hits := 0
	for frame in range(1440):
		var trial := frame / 180
		if frame % 180 == 0:
			_reset(app, "nobunaga" if trial in [0, 1, 5] else "oichi", trial >= 5)
			caption.text = TITLES[trial]
			shield_hits = 0
			if trial == 3: _target(app, 950.0)
			if trial == 4:
				_target(app, 850.0, 480.0)
				_extra_dummy(app, 1050.0, 420.0)
				_extra_dummy(app, 1200.0, 540.0)
		for half in range(2):
			var tick := (frame % 180) * 2 + half
			if trial in [0, 2]:
				if tick in [42, 65, 88]: _key(KEY_J, true)
				if tick in [44, 67, 90]: _key(KEY_J, false)
				if trial == 2 and tick == 170:
					_reset(app, "oichi")
					_target(app, 960.0)
					caption.text = "阿市｜短針射程外會消失，需換長弓或靠近"
				if trial == 2 and tick in [210, 233, 256]: _key(KEY_J, true)
				if trial == 2 and tick in [212, 235, 258]: _key(KEY_J, false)
			elif trial in [1, 3]:
				if tick in [30, 55]: _key(KEY_K, true)
				if tick in [32, 57]: _key(KEY_K, false)
				if tick == 170:
					_reset(app, "nobunaga" if trial == 1 else "oichi")
					if trial == 1:
						_extra_dummy(app, 340.0, 440.0)
						_extra_dummy(app, 780.0, 535.0)
					else:
						app.sim.state.fighters[0].x = 100.0
						_target(app, 1240.0)
				if trial == 1:
					if tick == 205: _key(KEY_U, true)
					if tick == 207: _key(KEY_U, false)
				else:
					if tick == 200: _key(KEY_K, true)
					if tick == 244: _key(KEY_K, false)
			elif trial == 4:
				if tick == 42: _key(KEY_U, true)
				if tick == 44: _key(KEY_U, false)
			elif trial >= 5:
				if tick == 8: _key(KEY_D, true)
				if tick == 18: _key(KEY_D, false)
				if tick == 26: _key(KEY_L, true)
				if tick == (265 if trial == 7 else 170): _key(KEY_L, false)
			app._physics_process(1.0 / 60.0)
			assert(not app.paused and app.training_active)
			for event in app.sim.state.events:
				if event.type == "shield_hit": shield_hits += 1
			if trial in [0, 2] and tick == 120: assert(app.sim.state.training.hit_count == 3, "Three distinct attacks must connect")
			if trial == 2 and tick == 340: assert(app.sim.state.training.hit_count == 0, "Short needles cannot hit the distant target")
			if trial == 3 and tick == 340: assert(app.sim.state.training.hit_count > 0, "Charged arrow must hit across the viewport")
			if trial in [5, 6] and tick == 169: assert(shield_hits > 0 and app.sim.state.fighters[0].action == "holding", "Held target absorbs real enemy attacks")
			if trial in [5, 6] and tick == 175: assert(app.sim.state.fighters[1].throw_ticks > 0, "Release throws the shield")
			if trial == 7 and tick == 220: assert(app.sim.state.fighters[0].grab_target == 0 and app.sim.state.fighters[1].throw_ticks == 0, "Three seconds expires as a safe drop")
		await process_frame
		if frame % 180 in [16, 27, 36, 47, 72, 84, 88, 103, 117, 131, 150]:
			await RenderingServer.frame_post_draw
			var file := output.path_join("training-%d-%03d.png" % [trial, frame % 180])
			assert(root.get_texture().get_image().save_png(file) == OK)
			report.append({"file": file, "training": app.sim.state.training.duplicate(), "shield_hits": shield_hits, "fighters": app.sim.state.fighters.duplicate(true)})
	var file := FileAccess.open(output.path_join("training.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("PASS: keyboard capture: sword chain, bow range, specials, real shield damage, release throw and three-second timeout")
	app.queue_free()
	quit()
