extends SceneTree
const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")
const ROLES := ["soldier","flag","commander","archer","gunner","boss","matsui"]

class Board extends View:
	var role := "soldier"
	var clips: Array = []
	func _draw() -> void:
		draw_rect(Rect2(0,0,2200,1500),Color("26343d"))
		draw_string(ThemeDB.fallback_font,Vector2(24,35),role+" | native source v19 | fixed anatomical scale",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
		for row in range(clips.size()):
			var key: String = "imagawa:"+role+":"+str(clips[row])
			var frames: Array = _art.enemy_clips[key]
			var fighter := {"kind":"boss" if role=="matsui" else role,"stage_boss":role=="matsui","render_scale":1.3 if role=="matsui" else 1.0}
			var height := enemy_display_height(fighter)
			draw_string(ThemeDB.fallback_font,Vector2(10,95+row*280),str(clips[row]),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffe0b5"))
			for index in range(frames.size()):
				var origin := Vector2(180+index*340,300+row*280)
				draw_line(origin-Vector2(100,0),origin+Vector2(120,0),Color("718089"),1)
				_draw_art_frame(frames[index],origin,height,1,0,Color.WHITE,float(frames[index].body_height))
				draw_string(ThemeDB.fallback_font,origin+Vector2(-50,20),str(index+1)+" / "+str(frames[index].body_height),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size=Vector2i(1280,720)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(2200,1500)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	viewport.add_child(board)
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v19/enemy-states")
	DirAccess.make_dir_recursive_absolute(output)
	for role in ROLES:
		board.role=role
		var primary: String = "boss_sweep" if role in ["boss","matsui"] else {"soldier":"spear_thrust","flag":"flag_poke","commander":"commander_cut","archer":"bow_shot","gunner":"gun_shot"}[role]
		board.clips=["walk",primary,"hurt","struggle","death"]
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(output.path_join(role+"-states.png"))==OK)
		board.clips=[]
		for clip in ["spear_thrust","spear_sweep","spear_butt","flag_poke","flag_sweep","flag_slam","commander_cut","commander_rise","commander_dash","bow_shot","gun_shot","boss_sweep","boss_thrust","boss_counter","boss_dash","boss_earth"]:
			if board._art.enemy_clips.has("imagawa:"+role+":"+clip): board.clips.append(clip)
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(output.path_join(role+"-attacks.png"))==OK)
	board.queue_free()
	print("PASS: 14 native formal state/attack contact sheets")
	quit()
