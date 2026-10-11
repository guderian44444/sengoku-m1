extends SceneTree

class Landscape:
	extends "res://render/battle_view.gd"
	var weather_effects := false
	func _draw() -> void:
		_draw_landscape()
		_draw_scenery()
		for prop in state.props: _draw_prop(prop)
		if weather_effects: _draw_weather()
		draw_string(ThemeDB.fallback_font,Vector2(20,28),"Camera %d / weather %d" % [camera_x,weather],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var view := Landscape.new()
	view.weather_effects = "--weather-effects" in OS.get_cmdline_user_args()
	view.state = {"tick":240,"props":[
		{"kind":"basket","x":530,"y":495,"hp":100,"max_hp":100},
		{"kind":"jar","x":1320,"y":535,"hp":100,"max_hp":100},
		{"kind":"crate","x":1800,"y":610,"hp":100,"max_hp":100}]}
	root.add_child(view)
	for weather in range(3):
		view.weather = weather
		for camera in [0,550,600,1100]:
			view.camera_x = camera
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(output.path_join("weather-%d-camera-%d.png" % [weather,camera])) == OK)
	print("PASS: 12 actual parallax captures saved")
	quit()
