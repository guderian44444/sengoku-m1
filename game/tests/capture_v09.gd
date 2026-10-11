extends SceneTree
const Main = preload("res://main.gd")
const TITLES := [
	"毛利軍｜六兵種實戰，長槍、旗桿、指揮刀與遠程火力",
	"遠程兵｜玩家逼近時先後撤，換位後再瞄準",
	"鎖鏈小王｜甩鏈拉近、近身追打、橫掃與震地",
	"信長｜三段輕擊、輕轉重終結、上挑接空中追擊",
	"信長｜下＋K 短按震地／滿蓄炎獄裂地",
	"信長必殺｜3.5 秒全程無敵，刀焰多段與灼燒",
	"阿市｜三段飛針、蓄力冰箭凍結、重箭碎冰",
	"阿市｜下＋K 散羽／滿蓄霜華冰陣",
	"阿市必殺｜冰箭多波凍結，終段破冰追傷",
	"方向重手與空中技｜蓄力上挑、空中針與落矢",
]

func _initialize() -> void:
	_run.call_deferred()

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _reset(app: Node, hero: String, drill: String = "dummy") -> void:
	for action in Main.CONTROL_ACTIONS: Input.action_release(action)
	app.selected_hero = hero
	app.heroes.selected = 1 if hero == "oichi" else 0
	app.training_drill = drill
	app._reset_training()
	if drill != "dummy": return
	# Passive durable sparring partners isolate the hero's real input and hit reactions.
	app.sim.state.fighters.resize(1)
	for spec in [["soldier", 595.0, 480.0], ["flag", 725.0, 510.0], ["commander", 790.0, 430.0]]:
		var enemy: Dictionary = app.sim._make_fighter(1, spec[0], spec[1], spec[2], 1000)
		enemy.cooldown = 10000
		enemy.home_x = enemy.x
		enemy.home_y = enemy.y
		app.sim.state.fighters.append(enemy)

func _run() -> void:
	var output := ""
	var check_only := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument == "--check-only": check_only = true
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	for signal_name in ["focus_exited", "focus_entered"]:
		for connection in root.get_signal_connection_list(signal_name): root.disconnect(signal_name, connection.callable)
	app._set_game_focus(true)
	app._start_training()
	var caption: Label = app.hud.duplicate()
	caption.position = Vector2(28, 122)
	caption.add_theme_font_size_override("font_size", 21)
	app.hud.get_parent().add_child(caption)
	var report: Array = []
	var seen_actions := {}
	var seen_effects := {}
	var seen_status := {"burn": false, "freeze": false, "pulled": false}
	for frame in range(1800):
		var trial: int = frame / 180
		if frame % 180 == 0:
			_reset(app, "nobunaga" if trial < 6 or trial == 9 else "oichi", ["enemies", "ranged", "boss"][trial] if trial < 3 else "dummy")
			caption.text = TITLES[trial]
			if trial == 2:
				app.sim.state.fighters[1].ai_cycle = 2
				app.sim.state.fighters[1].cooldown = 10
			if trial == 6:
				app.sim.state.fighters[1].x = 660.0
				app.sim.state.fighters[1].home_x = 660.0
		for half in range(2):
			var tick := (frame % 180) * 2 + half
			if trial == 0:
				if tick == 10: _key(KEY_D, true)
				if tick == 100: _key(KEY_D, false)
				if tick in [120, 145, 170]: _key(KEY_J, true)
				if tick in [122, 147, 172]: _key(KEY_J, false)
			elif trial == 1:
				if tick == 100: _key(KEY_D, true)
				if tick == 290: _key(KEY_D, false)
			elif trial == 3:
				if tick in [25, 46, 67, 125, 145]: _key(KEY_J, true)
				if tick in [27, 48, 69, 127, 147]: _key(KEY_J, false)
				if tick == 150: _key(KEY_K, true)
				if tick == 152: _key(KEY_K, false)
				if tick == 225:
					_reset(app, "nobunaga")
				if tick == 237: _key(KEY_W, true); _key(KEY_J, true)
				if tick == 239: _key(KEY_W, false); _key(KEY_J, false)
				if tick == 263: _key(KEY_SPACE, true)
				if tick == 264: _key(KEY_SPACE, false)
				if tick == 266: _key(KEY_J, true)
				if tick == 268: _key(KEY_J, false)
				if tick == 287: _key(KEY_K, true)
				if tick == 289: _key(KEY_K, false)
			elif trial in [4, 7]:
				if tick in [25, 150]: _key(KEY_S, true); _key(KEY_K, true)
				if tick in [27, 205]: _key(KEY_S, false); _key(KEY_K, false)
			elif trial in [5, 8]:
				if tick == 25: _key(KEY_U, true)
				if tick == 27: _key(KEY_U, false)
			elif trial == 6:
				if tick in [20, 41, 62]: _key(KEY_J, true)
				if tick in [22, 43, 64]: _key(KEY_J, false)
				if tick == 125:
					_reset(app, "oichi")
					app.sim.state.fighters[1].x = 680.0
					app.sim.state.fighters[1].home_x = 680.0
				if tick in [142, 242]: _key(KEY_K, true)
				if tick in [188, 244]: _key(KEY_K, false)
			elif trial == 9:
				if tick == 25: _key(KEY_W, true); _key(KEY_K, true)
				if tick == 78: _key(KEY_W, false); _key(KEY_K, false)
				if tick == 180: _reset(app, "oichi")
				if tick == 198: _key(KEY_SPACE, true)
				if tick == 199: _key(KEY_SPACE, false)
				if tick == 202: _key(KEY_J, true)
				if tick == 204: _key(KEY_J, false)
				if tick == 225: _key(KEY_K, true)
				if tick == 227: _key(KEY_K, false)
			app._physics_process(1.0 / 60.0)
			assert(not app.paused and app.training_active)
			for fighter in app.sim.state.fighters:
				seen_actions[fighter.action] = true
				seen_status.burn = seen_status.burn or fighter.burn > 0
				seen_status.freeze = seen_status.freeze or fighter.freeze > 0
				seen_status.pulled = seen_status.pulled or fighter.action == "pulled"
			for effect in app.sim.state.effects: seen_effects[effect.type] = true
		await process_frame
		if not check_only and frame % 180 in [20, 35, 65, 100, 120, 140]:
			await RenderingServer.frame_post_draw
			var file := output.path_join("v09-%d-%03d.png" % [trial, frame % 180])
			assert(root.get_texture().get_image().save_png(file) == OK)
			report.append({"file": file, "trial": trial, "frame": frame, "fighters": app.sim.state.fighters.duplicate(true), "effects": app.sim.state.effects.duplicate(true)})
	for action in ["retreat", "boss_chain", "pulled", "mixed_finisher", "ground_slam", "charged_slam", "special", "frozen", "air_light", "air_heavy", "charged_upper"]:
		assert(seen_actions.has(action), "Recording must exercise " + action)
	for effect in ["chain", "shatter", "fire_wave", "ice_wave"]: assert(seen_effects.has(effect), "Recording must show " + effect)
	assert(seen_status.burn and seen_status.freeze and seen_status.pulled)
	var file := FileAccess.open(output.path_join("v09.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames": report, "actions": seen_actions.keys(), "effects": seen_effects.keys(), "statuses": seen_status}, "  "))
	print("PASS: 60-second real-keyboard v09 recording; enemy AI, chain pull, tap/charged branches, combos, fire/ice and shatter observed")
	app.queue_free()
	quit()
