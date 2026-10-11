extends SceneTree

const View = preload("res://render/battle_view.gd")

class Board extends View:
	var frames: Array = []
	var title := ""
	var sheet_size := Vector2i(1600,1380)
	var tile_width := 400
	var support_x := 170
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,Vector2(sheet_size)),Color("162430"))
		draw_string(ThemeDB.fallback_font,Vector2(24,35),title,HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("efdbc1"))
		for index in range(frames.size()):
			var tile := Rect2(index%4*tile_width+4,64+int(index/4)*438,tile_width-8,426)
			draw_rect(tile,Color("213540" if index%2==0 else "293c48"))
			var origin := tile.position+Vector2(support_x,399)
			draw_line(Vector2(tile.position.x+6,origin.y),Vector2(tile.end.x-6,origin.y),Color("829793"),1)
			draw_line(origin-Vector2(0,290),origin+Vector2(0,8),Color("455768"),1)
			var frame: Dictionary=frames[index]
			_draw_art_frame(frame,origin,185,1,0,Color.WHITE,float(frame.body_height))
			draw_string(ThemeDB.fallback_font,tile.position+Vector2(10,24),"frame %02d | source body %.0f px"%[index,float(frame.body_height)],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("efdbc1"))

func _initialize() -> void: _run.call_deferred()

func _before_frames(board: Board, spec: Dictionary) -> Array:
	var regions := {}
	for key in spec.regions:
		var r: Array=spec.regions[key]
		regions[int(key)]=Rect2i(r[0],r[1],r[2],r[3])
	var frames: Array=board._art._load_grid("res://assets/v16/"+str(spec.file),int(spec.columns),int(spec.rows),true,regions,{},true)
	for index in range(frames.size()):
		var frame: Dictionary=frames[index]
		frame.anchor=Vector2(spec.feet[index][0],spec.feet[index][1])-frame.source_region.position+frame.frame_padding
		frame.body_height=float(spec.body_height)
	return frames

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/tadakatsu-atlas-v17")
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("registration-before.json")))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/v16/registration.json"))
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1600,1380)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	viewport.add_child(board)
	var capture := "--capture" in OS.get_cmdline_user_args()
	var report := {"registration_sha256":FileAccess.get_sha256("res://assets/v16/registration.json"),"original_sources":{},"frames":[],"boards":[],"assertions":0}
	var total := 0
	for actor in before.actors:
		var old: Dictionary=before.actors[actor]
		var spec: Dictionary=after.actors[actor]
		var frames: Array=board._art.animations.tadakatsu[spec.sheet]
		assert(frames.size()==int(spec.columns)*int(spec.rows))
		var original_path: String="res://assets/v16/"+str(spec.file)
		report.original_sources[spec.file]=FileAccess.get_sha256(original_path)
		for index in range(frames.size()):
			var frame: Dictionary=frames[index]
			assert(frame.source_region.has_area() and frame.body_height>=220)
			assert(frame.region.position==Vector2(2,2),"Keep the independent transparent texture gutter")
			assert(frame.texture.get_size()==frame.region.size+Vector2(4,4))
			var polygon := []
			if spec.sheet!="v16_special":
				assert(frame.has("clip_polygon"),"Irregular drawings must exclude neighbouring silhouettes")
				assert(not Geometry2D.triangulate_polygon(frame.clip_polygon).is_empty(),"Native contour must triangulate")
				for point in frame.clip_polygon: polygon.append([point.x,point.y])
			var r: Rect2=frame.source_region
			report.frames.append({"actor":actor,"index":index,"file":spec.get("frame_files",{}).get(str(index),spec.file),"region":[r.position.x,r.position.y,r.size.x,r.size.y],"body_height":frame.body_height,"support":[frame.support_point.x,frame.support_point.y],"polygon":polygon,"superseded":spec.sheet=="v16_special"})
			report.assertions+=5 if spec.sheet!="v16_special" else 3
			total+=1
		if capture:
			for stage in ["before","after"]:
				board.frames=_before_frames(board,old) if stage=="before" else frames
				board.title=str(actor)+" / "+stage+" / native renderer / same 185px anatomical scale"
				if spec.sheet=="v16_special": board.title+=" / REJECTED SOURCE, superseded by v17"
				board.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var filename: String=str(actor)+"-"+stage+".png"
				assert(viewport.get_texture().get_image().save_png(output.path_join(filename))==OK)
				report.boards.append(filename)
	assert(total==162,"Audit all fourteen original sheets")
	report.total_frames=total
	var file := FileAccess.open(output.path_join("native-verification.json"),FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify(report,"\t"))
	print("TADAKATSU ATLAS V17 PASS: ",report.assertions," checks; ",total," original frames; ",report.boards.size()," native boards")
	viewport.queue_free()
	await process_frame
	quit()
