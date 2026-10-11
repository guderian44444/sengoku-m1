extends SceneTree

const View = preload("res://render/battle_view.gd")

class Board extends View:
	var actor := "oichi"
	var comparison := false
	var evidence := []
	var sheet_size := Vector2i(2520,1120)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,Vector2(sheet_size)),Color("17232c"))
		evidence.clear()
		draw_string(ThemeDB.fallback_font,Vector2(28,42),actor + " / v15 victory / 12 distinct original drawings / 2x game scale",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("f4e6c8"))
		draw_string(ThemeDB.fallback_font,Vector2(28,80),"Source PNGs + native component clipping; anatomical scale and measured foot support; frame 11 holds",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("c3cabd"))
		var count := 6 if comparison else 12
		for index in range(count):
			var fighter := {"kind":actor,"team":0,"faction":"mori","action":"victory","action_tick":index*10,"face":1,"moving":false}
			if comparison:
				fighter.action = "idle" if index==0 else "victory"
				fighter.action_tick = [0,0,40,70,90,110][index]
			var sample := _fighter_animation(fighter)
			var frame: Dictionary = _art.animation_frame(actor,sample)
			assert(not frame.is_empty())
			if not comparison or index>0: assert(sample.source=="v15" and sample.sheet=="v15_victory")
			var tile := Rect2(index%6*420+10,110+int(index/6)*500,400,480)
			draw_rect(tile,Color("213541" if index%2==0 else "263c48"))
			var height := 296.0 if actor=="oichi" else 310.0
			var origin := Vector2(tile.get_center().x,tile.position.y+434)
			draw_line(Vector2(tile.position.x+8,origin.y),Vector2(tile.end.x-8,origin.y),Color("617071"),1)
			_draw_art_frame(frame,origin,height,1,0,Color.WHITE,float(frame.body_height))
			var label := "idle reference" if comparison and index==0 else "victory %02d / tick %d" % [sample.frame,fighter.action_tick]
			draw_string(ThemeDB.fallback_font,tile.position+Vector2(12,28),label,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("f4e6c8"))
			evidence.append({"hero":actor,"frame":sample.frame,"source":sample.source,"sheet":sample.sheet,"source_body_height":frame.body_height,"display_body_height":height,"region":[frame.region.position.x,frame.region.position.y,frame.region.size.x,frame.region.size.y],"anchor":[frame.anchor.x,frame.anchor.y]})

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v15/boards")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	root.size=Vector2i(1280,720)
	var viewport := SubViewport.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	viewport.add_child(board)
	var report := {"version":"0.15","native_original_art":true,"registration_sha256":FileAccess.get_sha256("res://assets/v15/registration.json"),"boards":[]}
	for hero in ["oichi","nobunaga"]:
		assert(board._art.animations[hero].get("v15_victory",[]).size()==12)
		for compare in [false,true]:
			board.actor=hero
			board.comparison=compare
			board.sheet_size=Vector2i(2520,620 if compare else 1120)
			viewport.size=board.sheet_size
			board.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var filename: String=hero+("-stance-comparison.png" if compare else "-victory-12.png")
			assert(viewport.get_texture().get_image().save_png(output.path_join(filename))==OK)
			report.boards.append({"file":filename,"drawings":board.evidence.duplicate(true)})
	var file := FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify(report,"\t"))
	print("V15 BOARD CAPTURE: original 24 drawings and two stance comparisons saved to ",output)
	viewport.queue_free()
	await process_frame
	quit()
