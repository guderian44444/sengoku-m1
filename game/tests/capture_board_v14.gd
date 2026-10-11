extends SceneTree

const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")
const AssetChecks = preload("res://tests/capture_v14_assets.gd")

class Board extends View:
	var actor := "soldier"
	var rows := []
	var sheet_size := Vector2i(2880,1200)
	var board_height := 210.0
	var comparison := false
	var evidence := []

	func prepare(kind: String) -> void:
		actor = kind
		comparison = false
		rows.clear()
		evidence.clear()
		board_height = 210.0
		var clips := ["idle","walk","hurt","struggle","death"]
		var attacks: Array = ["bow_shot"] if kind=="archer" else (["gun_shot"] if kind=="gunner" else Battle.ENEMY_ATTACKS[kind])
		clips.append_array(attacks)
		for clip in clips:
			var frames: Array = _art.enemy_clips.get("mori:" + kind + ":" + clip,[])
			if frames.is_empty(): continue
			for start in range(0,frames.size(),6): rows.append({"clip":clip,"start":start,"frames":frames.slice(start,mini(start+6,frames.size()))})
			for frame in frames:
				var scale := 210.0 / float(frame.body_height)
				# One common scale for this actor, never enlarge a crouch or a death pose.
				board_height = minf(board_height,210.0 * minf(444.0 / (frame.region.size.x * scale),276.0 / (frame.region.size.y * scale)))
		sheet_size = Vector2i(2880,maxi(480,120+rows.size()*370))
		queue_redraw()

	func prepare_comparison() -> void:
		comparison = true
		evidence.clear()
		sheet_size = Vector2i(1920,1150)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,Vector2(sheet_size)),Color("17232c"))
		evidence.clear()
		if comparison:
			_draw_comparison()
			return
		draw_string(ThemeDB.fallback_font,Vector2(28,45),"毛利 " + actor + " · 全部正式逐張圖 · 固定解剖比例；未替姿勢自動放大",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("f4e6c8"))
		draw_string(ThemeDB.fallback_font,Vector2(28,86),"遊戲原圖直接取樣／數字為 clip frame index／本板統一人體高度 %.1f px" % board_height,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("c3cabd"))
		for row_index in range(rows.size()):
			var row: Dictionary = rows[row_index]
			for column in range(row.frames.size()):
				var frame: Dictionary = row.frames[column]
				var index: int = row.start+column
				var tile := Rect2(column*480+10,120+row_index*370,460,350)
				draw_rect(tile,Color("213541" if column%2==0 else "263c48"))
				var scale := board_height/float(frame.body_height)
				var offset: float = (frame.region.size.x*.5-frame.anchor.x)*scale
				var origin := Vector2(tile.get_center().x-offset,tile.position.y+316)
				draw_line(Vector2(tile.position.x+8,origin.y),Vector2(tile.end.x-8,origin.y),Color("617071"),1)
				_draw_art_frame(frame,origin,board_height,1,0,Color.WHITE,float(frame.body_height))
				draw_string(ThemeDB.fallback_font,tile.position+Vector2(12,30),"%s · %02d" % [row.clip,index],HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("f4e6c8"))
				evidence.append({"kind":actor,"clip":row.clip,"frame":index,"source":frame.source,"source_body_height":frame.body_height,"display_body_height":board_height,"region":[frame.region.position.x,frame.region.position.y,frame.region.size.x,frame.region.size.y],"anchor":[frame.anchor.x,frame.anchor.y]})

	func _draw_comparison() -> void:
		draw_string(ThemeDB.fallback_font,Vector2(30,46),"遊戲比例對照 · 全員相同 2× 放大 · 同列腳底同地面",HORIZONTAL_ALIGNMENT_LEFT,-1,34,Color("f4e6c8"))
		draw_string(ThemeDB.fallback_font,Vector2(30,91),"信長155／阿市148／雜兵146／部將158／毛利小王163：保持解剖高度，不用武器或頭飾包圍盒縮放",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("c3cabd"))
		var actors := ["nobunaga","oichi","soldier","flag","commander","archer","gunner","boss"]
		for index in range(actors.size()):
			var kind: String = actors[index]
			var team := 0 if index<2 else 1
			var height := (155.0 if kind=="nobunaga" else 148.0) if team==0 else (163.0 if kind=="boss" else (158.0 if kind=="commander" else 146.0))
			var fighter := {"kind":kind,"team":team,"faction":"mori","action":"idle","action_tick":0,"face":1,"moving":false}
			var sample := _fighter_animation(fighter)
			var frame: Dictionary = _art.animation_frame(kind,sample) if team==0 else _art.enemy_frame(kind,int(sample.cell),"mori",sample.sheet)
			var origin := Vector2(240+(index%4)*480,570+(index/4)*510)
			draw_line(origin-Vector2(215,0),origin+Vector2(215,0),Color("8a9876"),2)
			draw_line(origin-Vector2(215,310),origin+Vector2(215,-310),Color("415861"),1)
			_draw_art_frame(frame,origin,height*2,1,0,Color.WHITE,float(frame.body_height))
			draw_string(ThemeDB.fallback_font,origin+Vector2(-200,42),"%s · %.0f px · %s" % [kind,height,sample.source],HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("f4e6c8"))
			evidence.append({"kind":kind,"source":sample.source,"sheet":sample.sheet,"cell":sample.cell,"game_body_height":height,"zoom":2,"source_body_height":frame.body_height,"ground_y":origin.y})

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v14/boards")
	var require_assets := "--require-v14" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	root.size = Vector2i(1280,720)
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	viewport.add_child(board)
	var missing: Array = AssetChecks.missing(board._art)
	var report := {"version":"0.14","technical_preview":not require_assets,"missing_assets":missing,"native_original_art":true,"registration_sha256":FileAccess.get_sha256("res://assets/v14/registration.json") if FileAccess.file_exists("res://assets/v14/registration.json") else "","boards":[],"passed":false}
	if require_assets and not missing.is_empty():
		report.error = "Final board requires all registered v14 clips"
		_write(output,report)
		push_error(str(report.error)+": "+str(missing))
		quit(1)
		return
	for kind in ["soldier","flag","commander","archer","gunner","boss","comparison"]:
		if kind=="comparison": board.prepare_comparison()
		else: board.prepare(kind)
		viewport.size = board.sheet_size
		await process_frame
		await RenderingServer.frame_post_draw
		var filename: String = "mori-"+kind+".png"
		assert(viewport.get_texture().get_image().save_png(output.path_join(filename))==OK)
		report.boards.append({"file":filename,"size":[board.sheet_size.x,board.sheet_size.y],"drawings":board.evidence.duplicate(true)})
	report.passed = true
	_write(output,report)
	print("V14 BOARD CAPTURE: %d boards; technical_preview=%s; %s" % [report.boards.size(),not require_assets,output])
	viewport.queue_free()
	await process_frame
	quit()

func _write(output: String, report: Dictionary) -> void:
	var file := FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify(report,"\t"))
