extends SceneTree
const Main = preload("res://main.gd")
const Frames = preload("res://render/frame_animation.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	assert(not output.is_empty(), "Supply --output for the frame review captures")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var app := Main.new()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app._start_art_demo()
	app.art_demo.running = false
	var captures: Array = []
	for pose in range(Frames.POSE_CLIPS.size()):
		var clip: String = Frames.POSE_CLIPS[pose]
		var seen := {}
		var expected := 0
		for step in range(288):
			app.art_demo.elapsed = pose * 2.4 + step / 120.0
			app._update_art_demo()
			var sample: Dictionary = app.view.animation_sample()
			var partner: Dictionary = app.view.animation_sample("oichi")
			assert(sample.source in ["v04", "v05", "v06", "v07", "v12", "v13"] and partner.source in ["v12", "v13"])
			if partner.count > sample.count: sample = partner
			if sample.clip != clip or seen.has(sample.frame): continue
			expected = int(sample.count) / 2 if clip == "charge" and sample.source in ["v12", "v13"] else int(sample.count)
			seen[sample.frame] = true
			await process_frame
			await RenderingServer.frame_post_draw
			var file := "%s/%s-%02d.png" % [output, clip, int(sample.frame) + 1]
			assert(root.get_texture().get_image().save_png(file) == OK)
			captures.append({"clip": clip, "frame": sample.frame, "tick": sample.tick, "file": file})
		assert(seen.size() == expected, "Not all frames captured: " + clip)
	var report := FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(captures, "  "))
	report.close()
	print("PASS: captured all %d frame positions for both heroes using registered animation textures" % captures.size())
	app.queue_free()
	quit()
