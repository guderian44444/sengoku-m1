extends SceneTree

const View = preload("res://render/battle_view.gd")
const CURRENT := ["idle","walk","run","jump","light1","light2","light3","heavy1","heavy2","victory"]
const NEW := ["slam_charge","charged_slam","charge_forward","upper","low_sweep","dash","air_light","air_heavy","hurt","guard","death","recover","special","holding","throw","launched"]

class Board extends View:
	var sheet := "v16_idle"
	var evidence := []
	var board_size := Vector2i(2400,1740)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,Vector2(board_size)),Color("17232c"))
		evidence.clear()
		draw_string(ThemeDB.fallback_font,Vector2(28,42),"Tadakatsu / " + sheet + " / sequential native source drawings",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("f4e6c8"))
		draw_string(ThemeDB.fallback_font,Vector2(28,86),"Shared 240px anatomical height; registered support cross; no per-pose stretching or camera offset",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("c3cabd"))
		var frames: Array = _art.animations.tadakatsu[sheet]
		for index in range(frames.size()):
			var drawing: Dictionary = frames[index]
			var tile := Rect2(index % 4 * 600 + 10,120 + int(index / 4) * 540,580,520)
			draw_rect(tile,Color("213541" if index % 2 == 0 else "30444c"))
			var origin := Vector2(tile.get_center().x,tile.position.y + 460)
			draw_line(Vector2(tile.position.x + 8,origin.y),Vector2(tile.end.x - 8,origin.y),Color("617071"),1)
			draw_line(origin - Vector2(0,8),origin + Vector2(0,8),Color("bcd2bb"),1)
			_draw_art_frame(drawing,origin,240.0,1,0,Color.WHITE,float(drawing.body_height))
			var label := "%02d / native body %.0f px" % [index,drawing.body_height]
			draw_string(ThemeDB.fallback_font,tile.position + Vector2(12,30),label,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("f4e6c8"))
			var source: Rect2 = drawing.get("source_region",drawing.region)
			var support: Vector2 = drawing.get("support_point",drawing.anchor)
			evidence.append({"sheet":sheet,"frame":index,"source":drawing.source,"body_height":drawing.body_height,"display_height":240,"region":[source.position.x,source.position.y,source.size.x,source.size.y],"anchor":[drawing.anchor.x,drawing.anchor.y],"support_point":[support.x,support.y]})

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v17/boards")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280,720)
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	viewport.add_child(board)
	var report := {"version":"0.17","setup":"All final gameplay source sequences through the native draw function. Compare old-v16 region boards separately in artifacts/tadakatsu-atlas-v17.","v16_registration_sha256":FileAccess.get_sha256("res://assets/v16/registration.json"),"v17_registration_sha256":FileAccess.get_sha256("res://assets/v17/registration.json"),"boards":[]}
	var sheets := []
	for clip in CURRENT: sheets.append("v16_" + clip)
	for clip in NEW: sheets.append("v17_" + clip)
	for sheet in sheets:
		var drawings: Array = board._art.animations.tadakatsu.get(sheet,[])
		assert(drawings.size() == (6 if sheet == "v16_idle" else 12),"Final contact boards require all authored drawings: " + sheet)
		board.sheet = sheet
		board.board_size = Vector2i(2400,120 + ceili(drawings.size() / 4.0) * 540)
		viewport.size = board.board_size
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var filename: String = "tadakatsu-" + sheet.replace("_","-") + ".png"
		assert(viewport.get_texture().get_image().save_png(output.path_join(filename)) == OK)
		report.boards.append({"file":filename,"drawings":board.evidence.duplicate(true)})
	var file := FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report,"\t") + "\n")
	file.close()
	viewport.queue_free()
	await process_frame
	print("PASS: native v17 Tadakatsu boards; 26 sequences and 306 sequential registered drawings")
	quit()
