extends SceneTree

const StageArt = preload("res://render/stage_art.gd")

class AtlasView extends Node2D:
	var art := StageArt.new()
	var names := ["grass","shrubs","earth_low","earth_high","wood_rail","bamboo_rail","interior_rail","screen","cabinet"]
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,800),Color("26363d"))
		draw_string(ThemeDB.fallback_font,Vector2(26,32),"v0.19 / generated RGBA scenery / native Godot texture sampling",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("f1e0b6"))
		for i in range(names.size()):
			var x := 20.0 + (i%3)*420.0
			var y := 48.0 + floorf(i/3.0)*244.0
			for row in range(8):
				for col in range(16):
					draw_rect(Rect2(x+col*25,y+row*25,25,25),Color("5b7180") if (row+col)%2 else Color("405662"))
			var frame: Dictionary = art.border_frames.get(names[i],art.prop(names[i]))
			var scale := minf(185.0/float(frame.body_height),365.0/frame.region.size.x)
			var foot := Vector2(x+200,y+195)
			draw_texture_rect_region(frame.texture,Rect2(foot-frame.anchor*scale,frame.region.size*scale),frame.region)
			draw_string(ThemeDB.fallback_font,Vector2(x+5,y+226),"%s / display %.0f px / native %.0f px" % [names[i],frame.display_height,frame.body_height],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v19/scenery")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(AtlasView.new())
	await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(output.path_join("transparent-scenery.png")) == OK)
	print("PASS: native v19 scenery captured to " + output)
	quit()
