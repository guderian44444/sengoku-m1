extends SceneTree
const Entry = preload("res://tests/play_stage03_alarm.gd")
const Encounter = preload("res://core/stage03_encounter.gd")
const Wire = preload("res://core/wire.gd")
var output := ""
var captures := []

func _initialize(): run.call_deferred()

func capture(app: Node, name: String):
	if output.is_empty(): return
	app._camera_scene = -1
	app._update_view()
	assert(Wire.valid_snapshot(app.sim.get_state()))
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name)) == OK)
	captures.append(name)

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if not output.is_empty():
		assert(DisplayServer.get_name() != "headless")
		assert(DirAccess.make_dir_recursive_absolute(output) == OK)
		root.size = Vector2i(1280,720)
	var app := Entry.App.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.testing = true
	app.session = "local"
	app._start_alarm(2)
	app.sim._enter_segment(2)
	for f in app.sim.state.fighters:
		if f.team == 0: f.x = 2850 + f.player_index * 30
	Encounter.tick(app.sim)
	await capture(app,"01-tent-entrance.png")
	for tick in range(50): app.sim.step([])
	assert(app.sim.state.stage.index == 3)
	for f in app.sim.state.fighters:
		if f.team == 0: f.x = 1050 + f.player_index * 100
	app._update_view()
	assert(app.combat_hud.leaders.size() == 2)
	assert(app.combat_hud.leaders[0].id != app.combat_hud.leaders[1].id)
	assert(app.combat_hud.leaders[0].hp > 0 and app.combat_hud.leaders[1].hp > 0)
	await capture(app,"02-two-leaders.png")
	var ids: Array = app.sim.state.encounter.leaders.map(func(b):return b.id)
	app.sim._damage(app.sim._fighter(ids[0]),10000,app.sim.state.fighters[0].id,true,false,true)
	Encounter.tick(app.sim)
	app._update_view()
	assert(app.combat_hud.leaders[0].defeated and app.combat_hud.leaders[0].hp == 0)
	assert(not app.combat_hud.leaders[1].defeated and app.combat_hud.leaders[1].hp > 0)
	assert(app.sim.state.encounter.phase == "active")
	await capture(app,"03-leader-a-defeated.png")
	app.sim._damage(app.sim._fighter(ids[1]),10000,app.sim.state.fighters[0].id,true,false,true)
	Encounter.tick(app.sim)
	app._update_view()
	assert("義元階段待接" in app.hud.text)
	assert(app.combat_hud.leaders.all(func(b):return b.defeated))
	assert(Wire.valid_snapshot(app.sim.get_state()))
	await capture(app,"04-awaiting-yoshimoto.png")
	for tick in range(300):
		for f in app.sim.state.fighters:
			if f.team == 0: f.invuln = 5
		app.sim.step([])
	app._update_view()
	assert(app.combat_hud.leaders.size() == 2 and app.combat_hud.leaders.all(func(b):return b.defeated and b.hp == 0))
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("review.json"),FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"capture":"Native Main, staged positions and damage; not a human difficulty playthrough.","files":captures,"leader_ids":ids,"all_snapshots_valid":true,"formal_art":false},"  ") + "\n")
	print("STAGE03 TENT VIEW PASS: entrance transition, two independent HP bars, one/both deaths, tombstones")
	app.queue_free()
	await process_frame
	quit()
