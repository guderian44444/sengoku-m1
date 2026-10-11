extends SceneTree
const View = preload("res://render/battle_view.gd")

class Board extends View:
	func _draw() -> void:
		draw_rect(Rect2(0,0,5040,1620),Color("19232c"))
		draw_string(ThemeDB.fallback_font,Vector2(35,50),"信長三段輕手・遊戲實際載入的 12 × 3 張連續圖",HORIZONTAL_ALIGNMENT_LEFT,-1,34,Color("f4e6c8"))
		var labels := ["第一刀：右上 → 左下","第二刀：左下 → 右上","第三刀：左 → 右"]
		var height := 280.0
		# Every drawing uses one anatomical scale; a long blade never shrinks its wielder.
		for row in range(3):
			for frame in _art.animations.nobunaga["v13_light" + str(row + 1)]:
				var scale := 280.0 / float(frame.body_height)
				height = minf(height,280.0 * minf(382.0 / (frame.region.size.x * scale),410.0 / (frame.region.size.y * scale)))
		for row in range(3):
			draw_string(ThemeDB.fallback_font,Vector2(35,100 + row * 505),labels[row],HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("d8bd89"))
			for index in range(12):
				var tile := Rect2(index * 420 + 12,120 + row * 505,396,450)
				draw_rect(tile,Color("22313d" if index % 2 == 0 else "263743"))
				var fighter := {"kind":"nobunaga","team":0,"action":"light","combo":row+1,"action_tick":index}
				var sample := _fighter_animation(fighter)
				assert(sample.sheet == "v13_light" + str(row + 1) and sample.frame == index)
				var frame := _art.animation_frame("nobunaga",sample)
				var scale := height / float(frame.body_height)
				var center_offset: float = (frame.region.size.x * .5 - frame.anchor.x) * scale
				_draw_art_frame(frame,Vector2(tile.get_center().x - center_offset,tile.end.y - 28),height,1,0,Color.WHITE,float(frame.body_height))
				draw_string(ThemeDB.fallback_font,tile.position + Vector2(12,30),"%02d" % (index + 1),HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("f3e6ca"))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(not output.is_empty())
	root.size = Vector2i(1680,540)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(5040,1620)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	viewport.add_child(board)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(output) == OK)
	print("PASS: actual registered Nobunaga light frames 12 x 3 at 5040 x 1620: ",output)
	quit()
