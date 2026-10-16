extends SceneTree

const Main = preload("res://main.gd")
const Wire = preload("res://core/wire.gd")
var review_dir := ""

class App extends Main:
	func _save_characters(_manual: bool = false) -> Error:
		return OK

	func _start_solo() -> void:
		if _confirm_end(_start_solo, "重新開始今川本陣？"): return
		if not _close_network(): return
		session = "solo"
		_start_alarm(1)

	func _start_local_coop() -> void:
		if _confirm_end(_start_local_coop, "重新開始雙人今川本陣？"): return
		if not _close_network(): return
		session = "local"
		_start_alarm(2)

	func _start_alarm(players: int) -> void:
		selected_chapter = 3
		local_slot = 0
		sim.reset_campaign("normal",players,["nobunaga","oichi"],3)
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--scene="): sim._enter_segment(clampi(int(arg.trim_prefix("--scene=")),0,3))
		_activate()

func _initialize() -> void:
	run.call_deferred()

func capture(app: Node, filename: String) -> void:
	app._update_view()
	assert(Wire.valid_snapshot(app.sim.get_state()))
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(review_dir.path_join(filename)) == OK)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-dir="): review_dir = arg.trim_prefix("--review-dir=")
	var app := App.new()
	root.add_child(app)
	await process_frame
	app.session = "local" if "--coop" in OS.get_cmdline_user_args() else "solo"
	app._start_alarm(2 if app.session == "local" else 1)
	app._update_view()
	if review_dir.is_empty(): return
	assert(DisplayServer.get_name() != "headless", "Review capture needs a native renderer")
	assert(DirAccess.make_dir_recursive_absolute(review_dir) == OK)
	root.size = Vector2i(1280,720)
	app.set_physics_process(false)
	app.testing = true
	app.sim.state.tick = 150
	for fighter in app.sim.state.fighters:
		if fighter.team == 0: fighter.x = 620 + fighter.player_index * 100
		else:
			fighter.entering = false
			fighter.x = 1320 + (fighter.id % 3) * 90
	var posts: Array = app.sim.state.props.filter(func(p):return p.kind == "bell_pillar")
	await capture(app,"01-ringing.png")
	app.sim._damage_prop(posts[0],120,app.sim.state.fighters[0].id)
	await capture(app,"02-heavy-damage.png")
	app.sim._damage_prop(posts[0],1000,app.sim.state.fighters[0].id)
	Main.Battle.Stage03Encounter.tick(app.sim)
	await capture(app,"03-one-post-broken.png")
	app.sim._damage_prop(posts[1],1000,app.sim.state.fighters[0].id)
	Main.Battle.Stage03Encounter.tick(app.sim)
	app.sim.state.tick += 45
	await capture(app,"04-alarm-stopped.png")
	var report := {"capture":"Native Main/BattleView. Poses and damage states staged for visual review, not a human playthrough.","stage":3,"players":2 if app.session == "local" else 1,"files":["01-ringing.png","02-heavy-damage.png","03-one-post-broken.png","04-alarm-stopped.png"],"all_snapshots_valid":true,"formal_art":false}
	var file := FileAccess.open(review_dir.path_join("review.json"),FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report,"  ") + "\n")
	print("STAGE03 NATIVE REVIEW PASS")
	app.queue_free()
	await process_frame
	quit()
