extends SceneTree
const Main = preload("res://main.gd")
const Battle = preload("res://core/battle.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app._start_solo()
	app.sim.boss_intros = {}
	var caption: Label = app.hud.duplicate()
	caption.position = Vector2(28, 120)
	caption.add_theme_font_size_override("font_size", 23)
	app.hud.get_parent().add_child(caption)
	var titles := ["阿市｜飛針接轉身高踢", "阿市｜取弓重射與敵兵倒地", "阿市｜抓取與迴身投摔", "同機合作｜兩名主角獨立攻擊"]
	var reports := []
	for frame in range(600):
		var trial := frame / 150
		if frame % 150 == 0:
			reports.append({"title":titles[trial],"combos":[],"attacking_players":[],"thrown":false,"flat_death":false})
			app.session = "local" if trial == 3 else "solo"
			app.sim.reset("normal", 2 if trial == 3 else 1, ["oichi","nobunaga"])
			app.sim.state.wave = 3
			app.sim.state.props = []
			app.sim.state.drops = []
			app.sim.state.intro = {}
			app.sim.state.civilian_flee_tick = 0
			var players: Array = app.sim.state.fighters.filter(func(f): return f.team == 0)
			for i in range(players.size()):
				players[i].x = 450.0 + i * 350.0
				players[i].y = 540.0
				players[i].face = 1
				players[i].rage = 100
			app.sim.state.fighters = players
			for i in range(2 if trial == 3 else 1):
				var target: Dictionary = app.sim._make_fighter(1,"soldier",players[i].x + (50 if trial == 2 else 120),540,20 if trial == 1 else 1200)
				target.cooldown = 10000
				app.sim.state.fighters.append(target)
			caption.text = titles[trial]
			app.last_event = -1
		for half in range(2):
			var tick := (frame % 150) * 2 + half
			var buttons := 0
			if trial in [0,3] and tick in [30,36,54]: buttons = Battle.LIGHT
			elif trial == 1 and tick >= 30 and tick < 38: buttons = Battle.HEAVY
			elif trial == 2 and tick >= 30 and tick < 90: buttons = Battle.GRAB
			var partner := Battle.HEAVY if trial == 3 and ((tick >= 30 and tick < 38) or (tick >= 70 and tick < 78)) else 0
			app.sim.step([{"buttons":buttons},{"buttons":partner}])
			app._events(app.sim.state.events)
			for event in app.sim.state.events:
				if event.type == "swing":
					if event.action == "light" and not reports[trial].combos.has(event.combo): reports[trial].combos.append(event.combo)
					if not reports[trial].attacking_players.has(event.actor): reports[trial].attacking_players.append(event.actor)
			for fighter in app.sim.state.fighters:
				if fighter.team == 0: continue
				if fighter.action == "thrown": reports[trial].thrown = true
				if fighter.hp == 0 and fighter.action_tick >= 24 and fighter.z == 0: reports[trial].flat_death = true
		app._update_view()
		app.view.camera_x = 0
		await process_frame
	assert(reports[0].combos == [1,2,3],"Recorded light combo must actually reach the turning kick")
	assert(reports[1].flat_death,"Recorded arrow hit must leave a settled corpse")
	assert(reports[2].thrown,"Recorded grab must actually release a throw")
	assert(reports[3].attacking_players.size() == 2,"Recorded coop must contain both players' attacks")
	var report := FileAccess.open(ProjectSettings.globalize_path("res://../artifacts/art-native-v11/motion-verification.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(reports,"\t"))
	print("PASS: v11 native simulation animation recording completed")
	app.queue_free()
	quit()
