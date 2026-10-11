extends SceneTree

const AtlasAudit = preload("res://tests/test_tadakatsu_atlas_v17.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/tadakatsu-atlas-v17/clips")
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/v17/registration.json"))
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clips="): selected=arg.trim_prefix("--clips=")
	if "--require-all" in OS.get_cmdline_user_args(): assert(registration.actors.size()==16)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(2000,1380)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := AtlasAudit.Board.new()
	board.sheet_size=viewport.size
	board.tile_width=500
	board.support_x=250
	viewport.add_child(board)
	var report := {"registration_sha256":FileAccess.get_sha256("res://assets/v17/registration.json"),"frames":[],"boards":[]}
	for actor in registration.actors:
		var clip: String=str(actor).trim_prefix("tadakatsu-")
		if not selected.is_empty() and not clip in selected.split(","): continue
		var spec: Dictionary=registration.actors[actor]
		var frames: Array=board._art.animations.tadakatsu[spec.sheet]
		assert(frames.size()==12)
		for index in range(frames.size()):
			var frame: Dictionary=frames[index]
			assert(frame.has("clip_polygon") and not Geometry2D.triangulate_polygon(frame.clip_polygon).is_empty())
			assert(frame.body_height>=220 and frame.region.position==Vector2(2,2))
			var r: Rect2=frame.source_region
			var polygon := []
			for point in frame.clip_polygon: polygon.append([point.x,point.y])
			report.frames.append({"actor":actor,"index":index,"file":spec.frame_files[str(index)],"region":[r.position.x,r.position.y,r.size.x,r.size.y],"body_height":frame.body_height,"support":[frame.support_point.x,frame.support_point.y],"polygon":polygon})
		for compare in [false,true]:
			board.frames=[board._art.animations.tadakatsu.v16_idle[0],frames[0],frames[3],frames[6],frames[9],frames[11]] if compare else frames
			board.title=str(actor)+" / "+("v16 idle + frames 0,3,6,9,11" if compare else "12 original drawings")+" / same 185px anatomical scale"
			board.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var filename: String=str(actor)+("-comparison.png" if compare else "-12.png")
			assert(viewport.get_texture().get_image().save_png(output.path_join(filename))==OK)
			report.boards.append(filename)
	var file := FileAccess.open(output.path_join("native-verification.json"),FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify(report,"\t"))
	print("TADAKATSU V17 CLIPS PASS: ",report.frames.size()," drawings, ",report.boards.size()," native boards")
	viewport.queue_free()
	await process_frame
	quit()
