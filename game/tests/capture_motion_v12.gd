extends SceneTree
const Main = preload("res://main.gd")
const Battle = preload("res://core/battle.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v12/motion")
	DirAccess.make_dir_recursive_absolute(output)
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app._start_solo()
	app.sim.boss_intros = {}
	var caption: Label = app.hud.duplicate()
	caption.position = Vector2(28,120)
	caption.add_theme_font_size_override("font_size",23)
	app.hud.get_parent().add_child(caption)
	var titles := ["雙人移動｜地面與遠景視差","按住前進｜輕手三連段","按住前進｜重手二連段","上挑強技｜上行刀弧與仰射","落地強技｜震波與低位箭","雙人必殺｜火焰斬與冰箭"]
	var report := []
	for frame in range(1800):
		var trial := frame / 300
		var tick := frame % 300
		if tick == 0:
			app.session = "local"
			app.sim.reset("normal",2,["nobunaga","oichi"])
			app.sim.state.wave = 3
			app.sim.state.props = []
			app.sim.state.drops = []
			app.sim.state.intro = {}
			app.sim.state.civilian_flee_tick = 0
			var players: Array = app.sim.state.fighters.filter(func(f): return f.team == 0)
			for i in range(2):
				players[i].x = 500.0 + i * 350.0
				players[i].y = 480.0 + i * 95.0
				players[i].face = 1
				players[i].rage = 100
			app.sim.state.fighters = players
			if trial > 0:
				for i in range(2):
					var target: Dictionary = app.sim._make_fighter(1,"soldier",players[i].x + (220 if trial in [1,2] else 110),players[i].y,3000)
					target.cooldown = 10000
					app.sim.state.fighters.append(target)
			caption.text = titles[trial]
			app.last_event = -1
			report.append({"title":titles[trial],"combos":[[],[]],"heavies":[[],[]],"skills":[[],[]],"special":[false,false]})
		var buttons := 0
		var dx := 0
		var dy := 0
		if trial == 0: dx = 1 if tick < 160 else (-1 if tick < 260 else 0)
		elif trial == 1:
			dx = 1 if tick < 100 else 0
			if tick in [30,34,54]: buttons = Battle.LIGHT
		elif trial == 2:
			dx = 1 if tick < 120 else 0
			if (tick >= 30 and tick < 35) or (tick >= 75 and tick < 80): buttons = Battle.HEAVY
		elif trial in [3,4]:
			dy = (-1 if trial == 3 else 1) if tick >= 30 and tick <= 70 else 0
			if tick >= 30 and tick < 70: buttons = Battle.HEAVY
		elif trial == 5 and tick == 30: buttons = Battle.SPECIAL
		app.sim.step([{"dx":dx,"dy":dy,"buttons":buttons},{"dx":dx,"dy":dy,"buttons":buttons}])
		app._events(app.sim.state.events)
		for event in app.sim.state.events:
			if event.type not in ["swing","special"]: continue
			for i in range(2):
				if event.actor != app.sim.state.fighters[i].id: continue
				if event.type == "special":
					report[trial].special[i] = true
					continue
				if event.action == "light": report[trial].combos[i].append(event.combo)
				if event.action == "heavy": report[trial].heavies[i].append(event.heavy_combo)
				if event.action in ["charged_upper","charged_slam"]: report[trial].skills[i].append(event.action)
		app._update_view()
		await process_frame
		if tick in [0,36,49,61,88,96,116,170,299]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("trial-%d-tick-%d.png" % [trial,tick]))
	assert(report[1].combos == [[1,2,3],[1,2,3]],"Both players must actually complete light chains while holding forward")
	assert(report[2].heavies == [[1,2],[1,2]],"Both players must actually complete heavy chains while holding forward")
	assert(report[3].skills == [["charged_upper"],["charged_upper"]],"Both upward skills must actually release from held HEAVY")
	assert(report[4].skills == [["charged_slam"],["charged_slam"]],"Both downward skills must actually release from held HEAVY")
	assert(report[5].special == [true,true],"Both special demonstrations must be driven by real input")
	FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PASS: native two-hero motion, held-direction combos, charged skills and parallax recording")
	app.queue_free()
	quit()
