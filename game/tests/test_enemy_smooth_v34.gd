extends SceneTree

const View = preload("res://render/battle_view.gd")
const Frames = preload("res://render/frame_animation.gd")
const Battle = preload("res://core/battle.gd")
const OUT := "res://../artifacts/enemy-smooth-v34/"
var checks := 0
var failures := 0

class Board extends View:
	var pose_tick := 0
	var contact_sheet := false
	var contact_faction := "imagawa"
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("172329"))
		draw_string(ThemeDB.fallback_font,Vector2(24,32),"Existing soldier drawings | 12 poses / 60 ticks | 5 ticks per pose",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("ecd6a8"))
		if contact_sheet:
			for index in range(12):
				var enemy := actor(index+1,contact_faction)
				enemy.role = "shield_spear" if contact_faction == "oda" else ""
				_walk_ticks[enemy.id] = index*5
				var origin := Vector2(105+(index%6)*210,320+(index/6)*330)
				draw_line(origin-Vector2(100,0),origin+Vector2(100,0),Color("a6b7ac"),1)
				_draw_enemy_art(enemy,origin)
				draw_string(ThemeDB.fallback_font,origin+Vector2(-60,30),"pose %02d" % (index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
		else:
			for row in range(3):
				var enemy := actor(row+1,"oda" if row == 2 else "imagawa")
				enemy.role = "shield_spear" if row == 2 else ""
				enemy.face = 1 if pose_tick < 120 else -1
				var origin := Vector2(480,235+row*235)
				draw_line(Vector2(280,origin.y),Vector2(1050,origin.y),Color("a6b7ac"),1)
				_walk_ticks[enemy.id] = pose_tick
				if row == 0:
					var old_indices := [0,2,3,5,8,9]
					var frame: Dictionary = _art.enemy_clips["imagawa:soldier:walk"][old_indices[(pose_tick/10)%6]]
					_draw_art_frame(frame,origin,146,enemy.face,0,Color.WHITE,float(frame.body_height))
				else: _draw_enemy_art(enemy,origin)
				draw_string(ThemeDB.fallback_font,Vector2(680,origin.y-70),["Previous: 6 poses / second","Current: 12 poses / second","Oda: 12 poses + registered shield"][row],HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
	static func actor(id: int, faction: String) -> Dictionary:
		return {"id":id,"kind":"soldier","team":1,"faction":faction,"action":"idle","action_tick":0,"moving":true,"face":1,"move_dx":1,"z":0.0,"x":200.0,"y":500.0,"hp":100.0,"max_hp":100.0}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var view := Board.new()
	root.add_child(view)
	view.state = {"tick":0,"phase":"playing","fighters":[]}
	for faction in ["imagawa","oda"]:
		var enemy := Board.actor(1,faction)
		var frames: Array = view._art.enemy_clips[faction+":soldier:walk"]
		check(frames.size() == 12,faction+" exposes 12 genuine drawings")
		var textures := {}
		for frame in frames:
			textures[frame.texture.get_instance_id()] = true
			check(frame.frame_padding == Vector2(2,2) and frame.body_height == 310,"Original anatomical scale and independent padded textures")
			check(frame.has("shield_anchor"),"Every walk pose has its shield hand registered")
		check(textures.size() == 12,"No repeated texture masquerades as an extra drawing")
		for face in [-1,1]:
			for backwards in [false,true]:
				enemy.face = face
				enemy.action = "retreat" if backwards else "idle"
				enemy.move_dx = -face if backwards else face
				for tick in range(121):
					var sample := Frames.enemy_v14_sample(enemy,tick,tick,view._art.enemy_clips)
					var expected := posmod((-1 if backwards else 1)*(tick/5),12)
					check(sample.frame == expected and sample.duration == 60,"Full forward/backward loop keeps exact one-second stride")
		for role in ["soldier","flag","commander","archer","gunner","boss","matsui"]:
			if faction == "oda" and role in ["boss","matsui"]: continue
			var key: String = faction+":"+role+":walk"
			check(view._art.enemy_clips[key].size() == (12 if role == "soldier" else 6),"Frame counts reflect real source art")
		# Exercise the actual renderer clock: the Oda omission previously held every pose at zero.
		enemy = Board.actor(20,faction)
		view.state.fighters = [enemy]
		view.state.tick = 0
		view._update_motion()
		var seen := {}
		for tick in range(60):
			view.state.tick = tick
			enemy.x += 1
			view._update_motion()
			seen[view._fighter_animation(enemy).frame] = true
		check(seen.size() == 12,faction+" live movement plays all 12 poses")
		enemy.freeze = 10
		var frozen: Dictionary = view._fighter_animation(enemy).duplicate()
		view.state.tick += 6
		view._update_motion()
		check(view._fighter_animation(enemy) == frozen,"Freeze holds the visible enemy pose")
		enemy.freeze = 0
		enemy.moving = false
		view.state.tick += 1
		view._update_motion()
		check(view._fighter_animation(enemy).clip == "idle","Stopping selects idle immediately")
	for key in view._art.enemy_clips:
		if not str(key).begins_with("imagawa:"): continue
		var parts: PackedStringArray = str(key).split(":")
		if not Battle.ENEMY_TIMING.has(parts[2]): continue
		var enemy := Board.actor(30,"imagawa")
		enemy.kind = "boss" if parts[1] == "matsui" else parts[1]
		enemy.stage_boss = parts[1] == "matsui"
		enemy.action = parts[2]
		var timing := Battle.enemy_timing(enemy)
		for tick in [timing[0]-1,timing[0],timing[1]-1]:
			enemy.action_tick = tick
			var sample := Frames.enemy_v14_sample(enemy,0,0,view._art.enemy_clips)
			check(sample.released == (tick >= timing[0]) and sample.duration == timing[1],"Attack contact and recovery timing unchanged: "+key)
	var corpse := Board.actor(31,"imagawa")
	corpse.action = "dead"
	var death := Frames.enemy_v14_sample(corpse,0,0,view._art.enemy_clips)
	check(death.frame == death.count-1 and death.count == 6,"Dead enemies keep the original final prone pose")
	if "--capture" in OS.get_cmdline_user_args() and failures == 0:
		root.size = Vector2i(1280,720)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		view.state.fighters = []
		for tick in range(240):
			view.pose_tick = tick
			view.state.tick = tick
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
		view.contact_sheet = true
		for faction in ["imagawa","oda"]:
			view.contact_faction = faction
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OUT+faction+"-12-poses.png") == OK,"Native contact sheet saved")
	view.queue_free()
	await process_frame
	print("ENEMY SMOOTH V34: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
