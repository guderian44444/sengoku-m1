extends SceneTree

const Entry = preload("res://tests/play_stage03_alarm.gd")
const Encounter = preload("res://core/stage03_encounter.gd")
const Wire = preload("res://core/wire.gd")
var output := ""
var files := []

func _initialize() -> void:
	run.call_deferred()

func capture(app: Node, filename: String) -> void:
	app._camera_scene = -1
	app._update_view()
	assert(Wire.valid_snapshot(app.sim.get_state()))
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(filename)) == OK)
	files.append(filename)

func advance(app: Node, ticks: int) -> void:
	for tick in range(ticks):
		for fighter in app.sim.state.fighters:
			if fighter.team == 0: fighter.invuln = 5
		app.sim.step([])

func run() -> void:
	output = ProjectSettings.globalize_path("res://../artifacts/stage03-m2/native-review")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(DisplayServer.get_name() != "headless")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280,720)
	var app := Entry.App.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.testing = true
	app.session = "solo"
	app._start_alarm(1)
	app.sim._enter_segment(1)
	var player: Dictionary = app.sim.state.fighters[0]
	player.x = 640
	player.y = 530
	await capture(app,"01-barriers-intact.png")
	app.sim._damage_prop(app.sim.state.props[0],1000,player.id)
	Encounter.tick(app.sim)
	player.x = 1200
	await capture(app,"02-first-layer-open.png")
	for prop in app.sim.state.props: app.sim._damage_prop(prop,1000,player.id)
	advance(app,50)
	player.x = 2500
	app.sim.step([])
	assert(app.sim.state.stage.index == 2)
	player = app.sim.state.fighters[0]
	player.x = 1100
	player.y = 475
	await capture(app,"03-formation-holding.png")
	var front: Dictionary = app.sim.state.encounter.slots[0]
	var dead: Dictionary = app.sim._fighter(front.occupant)
	app.sim._damage(dead,500,player.id,true,false,true)
	Encounter.tick(app.sim)
	await capture(app,"04-front-gap.png")
	app.sim.state.tick = front.gap_until - 1
	Encounter.tick(app.sim)
	assert(front.occupant == 0)
	await capture(app,"05-gap-held.png")
	app.sim.state.tick += 1
	Encounter.tick(app.sim)
	var mover: Dictionary = app.sim._fighter(front.occupant)
	assert(not mover.is_empty())
	var before := {"id":mover.id,"x":mover.x,"y":mover.y,"hp":mover.hp,"kind":mover.kind,"role":mover.get("role","")}
	await capture(app,"06-reserved-rear-soldier.png")
	advance(app,120)
	assert(mover.x < before.x and before.x - mover.x < 200 and mover.hp == before.hp)
	await capture(app,"07-rear-soldier-walking.png")
	advance(app,300)
	await capture(app,"08-gap-filled.png")
	player.x = 1250
	player.y = 490
	advance(app,120)
	assert(app.sim.state.encounter.breached)
	await capture(app,"09-breached-melee.png")
	var report := {"capture":"Native Main/BattleView, staged setup and damage with real deterministic movement ticks. Not a human difficulty playthrough.",
		"stage":3,"players":1,"files":files,"all_snapshots_valid":true,"formal_art":false,"mover_before":before,
		"mover_after":{"id":mover.id,"x":mover.x,"y":mover.y,"hp":mover.hp,"kind":mover.kind,"role":mover.get("role","")},"breached":true}
	var file := FileAccess.open(output.path_join("review.json"),FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report,"  ") + "\n")
	print("STAGE03 OBJECTIVES NATIVE REVIEW PASS")
	app.queue_free()
	await process_frame
	quit()
