extends SceneTree
const Main = preload("res://main.gd")
const Battle = preload("res://core/battle.gd")
const TITLES := [
	"信長｜三段斬擊與炎獄必殺", "阿市｜左手・右手・旋身飛針與霜華箭雨",
	"秀吉｜快槍連擊與連環疾風", "家康｜重斬連段與鎮地震波",
	"光秀｜居合連擊與長程刀氣", "忠勝｜長槍破陣與穿透衝擊",
	"防禦與反擊｜格擋命中後反斬", "受擊反應｜擊飛、兩次彈地、倒地與慢起身",
	"鎖鏈小王｜拉近後追打暈眩", "遠程敵兵｜拋物線箭矢與直線鐵砲",
	"街道動態｜雙擊衝刺、路人逃散與積水落地", "破壞布景｜攤位碎裂與實際掉寶"
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

func _reset(app: Node, hero: String, drill: String = "dummy", faction: String = "mori") -> void:
	for code in [KEY_A,KEY_D,KEY_W,KEY_S,KEY_J,KEY_K,KEY_I,KEY_U,KEY_SPACE,KEY_L]: _key(code,false)
	for action in Main.CONTROL_ACTIONS: Input.action_release(action)
	app.selected_hero = hero
	app.heroes.selected = Battle.HEROES.find(hero)
	app.selected_faction = faction
	app.training_drill = drill
	app._reset_training()
	# This capture measures combat; separate intro tests exercise the complete spoken pause.
	app.sim.state.intro = {}
	app.audio.stop_speech()
	if drill != "dummy": return
	app.sim.state.fighters.resize(1)
	for spec in [["soldier",600.0,480.0],["flag",735.0,505.0],["commander",820.0,440.0]]:
		var enemy: Dictionary = app.sim._make_fighter(1,spec[0],spec[1],spec[2],1000)
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
	assert(not output.is_empty() and DirAccess.make_dir_recursive_absolute(output) == OK)
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	for signal_name in ["focus_exited","focus_entered"]:
		for connection in root.get_signal_connection_list(signal_name): root.disconnect(signal_name,connection.callable)
	app._set_game_focus(true)
	app._start_training()
	var caption: Label = app.hud.duplicate()
	caption.position = Vector2(28,122)
	caption.add_theme_font_size_override("font_size",20)
	app.hud.get_parent().add_child(caption)
	var seen_actions := {}
	var seen_effects := {}
	var specials := {}
	var wet_landing := false
	var maximum_bounce := 0
	var report := []
	for frame in range(1800):
		var trial: int = frame / 150
		if frame % 150 == 0:
			caption.text = TITLES[trial]
			if trial < 6: _reset(app,Battle.HEROES[trial])
			elif trial == 6:
				_reset(app,"mitsuhide")
				var enemy: Dictionary = app.sim.state.fighters[1]
				enemy.kind = "commander"
				enemy.x = 600.0
				enemy.face = -1
				app.sim._begin(enemy,"commander_cut")
			elif trial in [7,8]:
				_reset(app,"nobunaga","boss","mori")
				var enemy: Dictionary = app.sim.state.fighters[1]
				enemy.x = 660.0 if trial == 7 else 790.0
				enemy.face = -1
				enemy.cooldown = 10000
				app.sim._begin(enemy,"boss_smash" if trial == 7 else "boss_chain")
			elif trial == 9: _reset(app,"oichi","ranged")
			else:
				_reset(app,"nobunaga")
				app.sim.state.fighters.resize(1)
				if trial == 11:
					app.sim.state.fighters[0].x = 330.0
					app.sim.state.fighters[0].y = 570.0
		for half in range(2):
			var tick := (frame % 150) * 2 + half
			if trial < 6:
				if tick in [10,30,50]: _key(KEY_J,true)
				if tick in [12,32,52]: _key(KEY_J,false)
				if tick == 86: _key(KEY_U,true)
				if tick == 88: _key(KEY_U,false)
			elif trial == 6:
				if tick == 3: _key(KEY_I,true)
				if tick == 35: _key(KEY_I,false)
				if tick == 27: _key(KEY_J,true)
				if tick == 29: _key(KEY_J,false)
			elif trial == 10:
				if tick in [5,12]: _key(KEY_D,true)
				if tick in [7,75]: _key(KEY_D,false)
				if tick == 80:
					app.sim.state.fighters[0].x = 700.0
					app.sim.state.fighters[0].y = 515.0
				if tick == 90: _key(KEY_SPACE,true)
				if tick == 92: _key(KEY_SPACE,false)
				if tick == 150: _key(KEY_J,true)
				if tick == 152: _key(KEY_J,false)
			elif trial == 11:
				if tick == 12: _key(KEY_S,true); _key(KEY_K,true)
				if tick == 60: _key(KEY_S,false); _key(KEY_K,false)
				if tick == 150: _key(KEY_U,true)
				if tick == 152: _key(KEY_U,false)
			app._physics_process(1.0 / 60.0)
			assert(not app.paused and app.training_active)
			for fighter in app.sim.state.fighters:
				seen_actions[fighter.action] = true
				if fighter.team == 0:
					maximum_bounce = maxi(maximum_bounce,int(fighter.get("landing_count",0)))
					if fighter.action == "special": specials[fighter.kind] = true
			for effect in app.sim.state.effects:
				seen_effects[effect.type] = true
				wet_landing = wet_landing or (effect.type == "landing" and effect.get("wet",false))
		await process_frame
		if not check_only and frame % 150 in [12,35,65,100,130]:
			await RenderingServer.frame_post_draw
			var file := output.path_join("v10-%02d-%03d.png" % [trial,frame % 150])
			assert(root.get_texture().get_image().save_png(file) == OK)
			report.append({"file":file,"trial":trial,"frame":frame,"fighters":app.sim.state.fighters.duplicate(true)})
	print("Observed: ",specials.keys()," / ",seen_actions.keys()," bounces=",maximum_bounce," wet=",wet_landing," debris=",seen_effects.has("debris"))
	for hero in Battle.HEROES: assert(specials.has(hero),"Capture must show actual " + hero + " special")
	for action in ["guard","counter_cut","launched","down","recovering","pulled","stunned"]: assert(seen_actions.has(action),"Capture must show " + action)
	assert(maximum_bounce >= 2 and wet_landing)
	assert(seen_effects.has("debris") and seen_effects.has("damage"))
	var file := FileAccess.open(output.path_join("v10.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames":report,"actions":seen_actions.keys(),"effects":seen_effects.keys(),"specials":specials.keys(),"maximum_bounce":maximum_bounce,"wet_landing":wet_landing}))
	print("PASS: 60-second real-keyboard v10 capture, six hero specials, guard counter, two bounces, recovery, chain stun, wet landing and breakable prop loot")
	app.queue_free()
	quit()

