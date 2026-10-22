extends SceneTree

const Art = preload("res://render/stage07_10_art.gd")

class Sheet extends "res://render/battle_view.gd":
	var role := "ujie"
	var row := 0
	var column := 0
	func _draw() -> void:
		draw_rect(Rect2(0,0,448,400),Color("d8d1be"))
		var font := ThemeDB.fallback_font
		var actor: Dictionary=_stage0710_art.actors()[role]
		var clips: Dictionary=actor.clips
		var top: Array=clips.idle+clips.hurt+clips.guard
		var bottom: Array=clips.down.duplicate()
		while bottom.size()<4: bottom.append(clips.down[-1])
		bottom.append_array(clips.recover)
		var groups := [top,clips.walk,clips.attack_a,clips.attack_b,clips.attack_c,bottom]
		var names := ["idle / hurt / guard","walk","attack_a","attack_b","attack_c","down / recover"]
		draw_string(font,Vector2(12,22),role+" / "+names[row],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("554e40"))
		var origin := Vector2(192,366)
		draw_line(Vector2(7,origin.y),Vector2(441,origin.y),Color("a4a08c"),1)
		draw_line(origin-Vector2(0,6),origin+Vector2(0,6),Color("826f48"),1)
		var frame := _stage0710_art.actor_frame(role,int(groups[row][column]))
		_draw_art_frame(frame,origin,float(Art.HEIGHTS[role]),1,0,Color.WHITE,float(frame.body_height))
		draw_string(font,Vector2(12,390),"pose %d / source height %.0f"%[column,float(frame.body_height)],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("554e40"))

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var output := ""
	var only_role := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--role="): only_role=arg.trim_prefix("--role=")
	assert(not output.is_empty() and DisplayServer.get_name()!="headless")
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	var canvas := SubViewport.new()
	canvas.size=Vector2i(448,400)
	canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var board := Sheet.new()
	canvas.add_child(board)
	for role in Art.HEIGHTS:
		if not only_role.is_empty() and role!=only_role: continue
		board.role=role
		var contact := Image.create(3584,2400,false,Image.FORMAT_RGBA8)
		# Each pose uses the real renderer in isolation so tall weapons cannot
		# overlap another row and hide a source or anchor defect during inspection.
		for row in 6:
			for column in 8:
				board.row=row;board.column=column;board.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				contact.blit_rect(canvas.get_texture().get_image(),Rect2i(0,0,448,400),Vector2i(column*448,row*400))
		assert(contact.save_png(output.path_join(role+"-contact.png"))==OK)
		print("ART_CONTACT ",role)
	board.queue_free()
	quit()
