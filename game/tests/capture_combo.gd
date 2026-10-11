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
	for frame in range(240):
		var trial := frame / 120
		if frame % 120 == 0:
			app.sim.reset("normal", 1, ["nobunaga"])
			var player: Dictionary = app.sim.state.fighters[0]
			var enemy: Dictionary = app.sim.state.fighters[1]
			app.sim.state.fighters = [player, enemy]
			app.sim.state.drops = []
			player.x = 500.0
			player.y = 550.0
			# This medium-weight target staggers on the uppercut; light targets now launch.
			enemy.kind = "dummy"
			enemy.weight = "medium"
			enemy.x = 585.0
			enemy.y = 550.0
			enemy.hp = 1000
			enemy.max_hp = 1000
			enemy.cooldown = 10000
		for half in range(2):
			var tick := int(app.sim.state.tick)
			var pressed := tick in [30, 34] or (trial == 1 and tick == 54)
			app.sim.step([{"buttons": Battle.LIGHT if pressed else 0}])
		var player: Dictionary = app.sim.state.fighters[0]
		var enemy: Dictionary = app.sim.state.fighters[1]
		app.view.state = app.sim.state
		app.view.camera_x = 0
		app.view.queue_redraw()
		app.hud.text = "M1 實際戰鬥規則  ·  %s\n%s  ·  連段 %d / 3  ·  敵人 %s" % ["只按兩次：不擊飛" if trial == 0 else "接第三刀：橫掃擊飛", "下砍 → 上揮 → 停手" if trial == 0 else "下砍 → 上揮 → 橫掃", player.combo, "倒地／擊飛" if enemy.action == "down" else "受擊硬直" if enemy.action == "hurt" else "站立"]
		if frame == 39:
			assert(enemy.x == 585.0 and enemy.z == 0.0 and enemy.knockback == 0.0)
		if frame == 160:
			assert(enemy.x > 585.0 and enemy.z > 0 and enemy.action == "down")
		await process_frame
	print("PASS: real simulation two-hit stop and three-hit launch recorded")
	app.queue_free()
	quit()
