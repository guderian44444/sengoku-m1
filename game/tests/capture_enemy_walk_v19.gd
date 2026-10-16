extends SceneTree

const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")
const Frames = preload("res://render/frame_animation.gd")
const ROLES := ["soldier","flag","commander","archer","gunner","boss","matsui"]
var output := ""

class Board extends View:
	var mode := "walk"
	var title := ""
	var actors: Array = []
	var selected: Dictionary = {}
	var facing := 1
	var walk_tick := 0
	var board_size := Vector2(1280,720)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,board_size),Color("172329"))
		draw_string(ThemeDB.fallback_font,Vector2(24,34),title,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("ecd6a8"))
		if mode == "contact":
			var count: int = _art.enemy_clips["imagawa:"+str(selected.label)+":walk"].size()
			for index in range(count):
				var x := index * board_size.x / float(count)
				draw_rect(Rect2(x+3,54,board_size.x/float(count)-6,board_size.y-60),Color("23353d"))
				draw_string(ThemeDB.fallback_font,Vector2(x+14,88),"%02d" % [index+1],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ecd6a8"))
				_walk_ticks[selected.id] = index * 60.0 / count
				_draw_actor(selected,Vector2(x+board_size.x/float(count*2),350))
		elif mode == "actions":
			for index in range(actors.size()):
				_draw_actor(actors[index],Vector2((index+0.5)*board_size.x/6.0,350))
		elif mode == "scale":
			for index in range(actors.size()):
				var origin := Vector2(160+index*315,535)
				_draw_actor(actors[index],origin)
		else:
			for index in range(actors.size()):
				var origin := Vector2(160+(index%4)*320,325+int(index/4)*330)
				_walk_ticks[actors[index].id] = walk_tick
				_draw_actor(actors[index],origin)
	func _draw_actor(actor: Dictionary, origin: Vector2) -> void:
		actor.face = facing
		var sample := _fighter_animation(actor)
		var hero: bool = int(actor.team) == 0
		var frame: Dictionary = _art.animation_frame(actor.kind,sample) if hero else _art.enemy_frame(actor.kind,sample.cell,actor.faction,sample.sheet)
		var height := 155.0 if hero else enemy_display_height(actor)
		draw_line(origin-Vector2(148,0),origin+Vector2(148,0),Color("a6b7ac"),1)
		_draw_art_frame(frame,origin,height,facing,0,Color.WHITE,float(frame.body_height))
		var label := "%s | %.1f px | frame %d/%d" % [actor.get("label",actor.kind),height,sample.frame+1,sample.count]
		draw_string(ThemeDB.fallback_font,origin+Vector2(-145,26),label,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("d5e5e6"))

func actor(role: String, id: int, moving := true) -> Dictionary:
	return {"id":id,"kind":"boss" if role == "matsui" else role,"faction":"imagawa","team":1,"action":"idle","action_tick":0,"moving":moving,"face":1,"move_dx":1,"z":0.0,"stage_boss":role == "matsui","render_scale":1.3 if role == "matsui" else 1.0,"label":role}

func _initialize() -> void: run.call_deferred()

func save_board(board: Board, filename: String) -> void:
	board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(board.get_viewport().get_texture().get_image().save_png(output.path_join(filename)) == OK)

func finish(board: Board, report: Dictionary, filename: String) -> void:
	var file := FileAccess.open(output.path_join(filename),FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	file.close()
	board.queue_free()
	await process_frame
	print("PASS: seven formal enemy roles, both facings and 60-tick walk cycles; ",report.boards.size()," native boards")
	quit()

func run() -> void:
	output = ProjectSettings.globalize_path("res://../artifacts/native-v19/enemy-walk")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280,720)
	var board := Board.new()
	root.add_child(board)
	board.state = {"tick":0,"phase":"playing","fighters":[]}
	var report := {"fps":60,"cycle_ticks":60,"source":"v19","acceptance":"Native source sampling and rendering at fixed support points. Staged gait and scale review; not input-driven enemy AI or human gait acceptance.","registration_sha256":FileAccess.get_sha256("res://assets/v19/enemies/registration.json"),"cycles":[],"boards":[]}
	for index in range(ROLES.size()):
		var fighter := actor(ROLES[index],index+1)
		board.actors.append(fighter)
		var key: String = "imagawa:"+ROLES[index]+":walk"
		assert(board._art.enemy_clips.has(key) and board._art.enemy_clips[key].size() == (12 if ROLES[index] == "soldier" else 6),"Capture uses every current genuine walk pose")
	var nobunaga := {"id":100,"kind":"nobunaga","team":0,"action":"idle","moving":false,"face":1,"label":"nobunaga"}
	board.actors.append(nobunaga)
	# --write-movie records this first section at 60 fps: two full cycles in each facing.
	for face in [1,-1]:
		board.facing = face
		var record := {"face":face,"ticks":120,"trace":[]}
		for tick in range(120):
			board.walk_tick = tick
			board.state.tick = tick
			board.title = "今川七身份｜%s｜足輕 12／其他 6 姿勢；60 tick 一輪｜第 %d tick" % ["面右" if face == 1 else "面左",tick%60]
			for fighter in board.actors:
				if fighter.team == 0: continue
				board._walk_ticks[fighter.id] = tick
				var sample := board._fighter_animation(fighter)
				assert(sample.source == "v19" and sample.count == (12 if fighter.label == "soldier" else 6) and sample.duration == 60)
				assert(sample.frame == int(tick%60*sample.count/60),"All poses retain the complete one-second gait")
				record.trace.append({"role":fighter.label,"tick":tick,"frame":sample.frame,"sheet":sample.sheet})
			board.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			if tick == 30:
				var filename := "all-seven-"+("right" if face == 1 else "left")+".png"
				assert(root.get_texture().get_image().save_png(output.path_join(filename)) == OK)
				report.boards.append(filename)
		report.cycles.append(record)
	if "--movie-only" in OS.get_cmdline_user_args():
		await finish(board,report,"movie-verification.json")
		return
	board.mode = "contact"
	board.board_size = Vector2(2000,420)
	var sheets := SubViewport.new()
	sheets.size = Vector2i(2000,420)
	sheets.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheets)
	board.reparent(sheets)
	for role in ROLES:
		board.selected = actor(role,70)
		board.board_size.x = 4000 if role == "soldier" else 2000
		sheets.size = Vector2i(board.board_size)
		for face in [1,-1]:
			board.facing = face
			board.title = role+"｜全部來源姿勢｜"+("面右" if face == 1 else "面左")+"｜60 tick 一輪；原生遊戲比例"
			var filename: String = role+"-poses-"+("right" if face == 1 else "left")+".png"
			await save_board(board,filename)
			report.boards.append(filename)
	board.mode = "actions"
	board.board_size = Vector2(2520,420)
	sheets.size = Vector2i(2520,420)
	board.facing = 1
	for role in ROLES:
		board.actors.clear()
		for index in range(6):
			var fighter := actor(role,80+index,index in [1,2])
			fighter.label = ["stand","walk-open","walk-cross","windup","hit","recovery"][index]
			if index in [1,2]: board._walk_ticks[fighter.id] = 0 if index == 1 else 20
			if index >= 3:
				fighter.boss_variant = Battle.FACTIONS.imagawa.boss
				fighter.action = Frames.primary_enemy_action(fighter)
				var timing := Battle.enemy_timing(fighter)
				fighter.action_tick = 0 if index == 3 else (timing[0] if index == 4 else timing[1]-1)
			board.actors.append(fighter)
		board.title = role+"｜站立 → 步行 → 主攻擊｜同地面、相同解剖尺度；檢查身材銜接"
		var filename: String = role+"-stand-walk-attack.png"
		await save_board(board,filename)
		report.boards.append(filename)
	board.mode = "scale"
	board.board_size = Vector2(1280,720)
	board.reparent(root)
	sheets.queue_free()
	board.actors = [nobunaga,actor("soldier",71,false),actor("boss",72,false),actor("matsui",73,false)]
	for face in [1,-1]:
		board.facing = face
		board.title = "同地面原生比例｜信長 155／足輕 146／小王 163／松井宗信 201.5 px"
		var filename := "nobunaga-soldier-boss-matsui-scale-"+("right" if face == 1 else "left")+".png"
		await save_board(board,filename)
		report.boards.append(filename)
	await finish(board,report,"verification.json")
