extends SceneTree

const Main = preload("res://main.gd")
const Wire = preload("res://core/wire.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.testing = true
	app._start_solo()
	app._update_view()
	assert(app.sim.state.has("stage") and app.sim.state.stage.index == 0 and app.sim.state.faction == "imagawa")
	assert(app.hud.text.contains("01/10") and app.audio._music_key == "siege")
	assert(app.view.camera_x == 0 and not app.menu.visible)
	app.sim._enter_segment(9)
	app.sim.state.wave = 2
	app.sim._spawn_segment_wave()
	app._update_view()
	assert(app.hud.text.contains("10/10") and app.audio._music_key == "boss")
	assert(app.end_label.text.contains("松井宗信") and not app.end_label.text.contains("暫停") and not app.end_label.text.contains("結束後開戰"))
	assert(Wire.valid_snapshot(app.sim.get_state()))
	app._close_network()
	assert(not app.audio._music_player.playing and not app.audio._music_tail.playing)
	app.queue_free()
	await process_frame
	await create_timer(.3).timeout
	print("STAGE INTEGRATION PASS: menu starts campaign, HUD/camera/music follow region, officer text does not announce a pause, stop releases both BGM players")
	quit()
