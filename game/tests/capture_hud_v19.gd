extends SceneTree

const Main = preload("res://main.gd")
var output := ""

class App extends Main:
	func _ready() -> void:
		testing = true
		super._ready()

func _initialize() -> void: run.call_deferred()

func capture(app: Node, filename: String) -> void:
	app._update_view()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(filename))
	if error != OK:
		push_error("Unable to capture " + filename)
		quit(1)

func run() -> void:
	output = ProjectSettings.globalize_path("res://../artifacts/native-v19/hud")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var app := App.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.audio.stop_music()
	app.audio.stop_speech()
	for pair in [["nobunaga", "oichi"], ["hideyoshi", "ieyasu"], ["mitsuhide", "tadakatsu"]]:
		app.session = "local"
		app.sim.reset_campaign("normal", 2, pair)
		app.sim.state.fighters[0].hp = int(app.sim.state.fighters[0].max_hp * 0.7)
		app.sim.state.fighters[0].rage = 65
		app.sim.state.fighters[1].hp = int(app.sim.state.fighters[1].max_hp * 0.2)
		app.sim.state.fighters[1].rage = 100
		app.sim.state.fighters[0].x = 460.0
		app.sim.state.fighters[1].x = 620.0
		await capture(app, "players-" + pair[0] + "-" + pair[1] + ".png")
	app.session = "solo"
	app.training_active = true
	app.training_drill = "boss"
	app.sim.reset_training("nobunaga", "boss", "imagawa")
	app.sim.state.fighters[-1].display_name = "松井宗信"
	app.sim.state.intro = {"remaining_ticks":180, "name":"松井宗信", "line":"此陣有我，休想再進一步！"}
	await capture(app, "boss-dialogue.png")
	app.training_active = false
	app.sim.reset_campaign("normal", 1, ["oichi"])
	app.sim.state.stage.go = true
	app.sim.state.stage.phase = "exit"
	await capture(app, "solo-go.png")
	app._close_network()
	app.menu.show()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("menu.png"))
	app._show_controls()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("controls.png"))
	for index in range(3):
		app.audio._sound_variants.food_pickup[index].save_to_wav(output.path_join("food-pickup-%d.wav" % (index + 1)))
	app.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("PASS: v19 native HUD/menu/help captures with six existing-art portraits; fullscreen and real listening are separate manual acceptance")
	quit()
