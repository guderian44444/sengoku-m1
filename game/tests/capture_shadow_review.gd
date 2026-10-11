extends SceneTree

const Main = preload("res://main.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app._start_art_demo()
	app.art_demo.running = false
	for weather in [0, 2]:
		for pose in [0, 4]:
			app.art_demo.elapsed = 0.2 if pose == 0 else 4 * 2.4 + 0.7
			app.art_demo.weather_override = weather
			app._update_art_demo()
			await process_frame
			await RenderingServer.frame_post_draw
			var filename := "%s/%s-%s.png" % [output, "idle" if pose == 0 else "jump", "day" if weather == 0 else "night"]
			assert(root.get_texture().get_image().save_png(filename) == OK)
	print("PASS: captured idle/jump shadows in daylight and rain night")
	app.queue_free()
	quit()
