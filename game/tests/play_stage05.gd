extends SceneTree
const Main = preload("res://main.gd")
const Wire = preload("res://core/wire.gd")
const S5 = preload("res://core/stage05_encounter.gd")

class App extends Main:
	func _save_characters(_manual: bool = false) -> Error: return OK
	func _choices() -> void:
		super._choices()
		selected_chapter=5
	func start_stage5(players: int = 1) -> void:
		selected_chapter=5;local_slot=0
		session="local" if players==2 else "solo"
		sim.reset_campaign("normal",players,["nobunaga","oichi"],5)
		_activate()

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-dir="): output=arg.trim_prefix("--review-dir=")
	var app := App.new();root.add_child(app)
	await process_frame
	app.start_stage5(2 if "--coop" in OS.get_cmdline_user_args() else 1)
	if output.is_empty(): return
	assert(DisplayServer.get_name()!="headless")
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	root.size=Vector2i(1280,720);app.set_physics_process(false);app.testing=true
	for section in 5:
		app.sim._enter_segment(section)
		app.sim._start_checkpoint(app.sim.state.stage.checkpoint_total-1)
		app.sim.state.intro.clear()
		var left: float=app.sim.state.stage.encounter_start
		for hero in app.sim.state.fighters.filter(func(f):return f.team==0): hero.x=left+450+hero.player_index*95;hero.y=530
		var bosses: Array=app.sim.state.fighters.filter(func(f):return f.get("kind","")=="boss")
		if not bosses.is_empty():
			var boss: Dictionary=bosses[0]
			boss.x=left+850;boss.y=500
			var move: String={"hachiya":"s05_hachiya_sweep","natsume":"s05_natsume_diagonal","kusei":"s05_kusei_stomp"}[boss.s05_role]
			S5.start(app.sim,boss,move,app.sim.state.fighters[0])
			boss.action_tick=32 if boss.s05_role=="natsume" else (31 if boss.s05_role=="hachiya" else 39)
			S5.attack(app.sim,boss)
		app._camera_scene=-1;app._update_view()
		assert(Wire.valid_snapshot(app.sim.state))
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join("section-%d.png"%(section+1)))==OK)
	print("STAGE05_NATIVE_MAIN_PASS five sections and three bosses")
	app.queue_free();await process_frame;quit()
