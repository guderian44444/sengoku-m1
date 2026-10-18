extends SceneTree

const Data = preload("res://core/stage05_data.gd")
const Art = preload("res://render/stage05_art.gd")

class Arena extends Node2D:
	var art = Art.new()
	var clock := 0.0
	var selected := 0
	var face := 1
	var paused := false
	var capture := false
	var font := ThemeDB.fallback_font
	func _process(delta: float) -> void:
		if not paused: clock += delta
		queue_redraw()
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_RIGHT: selected += 1; clock = 0
			if event.keycode == KEY_LEFT: selected -= 1; clock = 0
			if event.keycode == KEY_SPACE: paused = not paused
			if event.keycode == KEY_F: face *= -1
	func draw_frame(frame: Dictionary, origin: Vector2, height: float, facing: int) -> void:
		if frame.has("layers"):
			for item in frame.layers: draw_frame(item,origin,height,facing)
			return
		var scale := height/float(frame.body_height)
		draw_set_transform(origin,0,Vector2(facing,1))
		draw_texture_rect_region(frame.texture,Rect2(-frame.anchor*scale,frame.region.size*scale),frame.region)
		draw_set_transform(Vector2.ZERO)
		for item in frame.get("overlays",[]): draw_frame(item,origin,height,facing)
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("1b2025"))
		draw_string(font,Vector2(28,38),"Stage 05 / approved v09 action arena",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color.WHITE)
		draw_string(font,Vector2(28,68),"Left / Right: next action    Space: pause    F: mirror    Fixed body ruler, original frame timing",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a8bac9"))
		var defaults := ["s05_hachiya_rapid","s05_natsume_diagonal","s05_kusei_slash","walk","walk"]
		for i in Data.ROLES.size():
			var role: String = Data.ROLES[i]
			var clips: Dictionary = Data.actors()[role]
			var keys: Array = clips.keys()
			var clip: String = defaults[i] if capture else keys[posmod(selected,keys.size())]
			var time := 800.0 if capture and role == "kusei" else (570.0 if capture else fposmod(clock*1000,Data.duration(role,clip)+500))
			var fighter := {"id":i+1,"s05_role":role,"action":clip,"action_tick":time*.06,"hp":100,"moving":false}
			var sample: Dictionary = art.sample({"tick":time*.06},fighter,time*.06,time*.06)
			var origin := Vector2(125+i*250,460)
			var height := Data.height(role)
			var facing := face*int(sample.native_face)
			draw_line(Vector2(i*250+8,460),Vector2(i*250+242,460),Color("668888"))
			if sample.frame_data.has("behind"): draw_frame(sample.frame_data.behind,origin,height,facing)
			draw_frame(sample.frame_data,origin,height,facing)
			draw_circle(origin,3,Color("ffc66d"))
			draw_string(font,Vector2(i*250+15,510),role,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
			draw_string(font,Vector2(i*250+15,540),clip.trim_prefix("s05_"),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("b1c6d6"))
			draw_string(font,Vector2(i*250+15,567),"frame %d / %d   %d ms"%[sample.cell+1,sample.count,Data.duration(role,clip)],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("b1c6d6"))
			draw_string(font,Vector2(i*250+15,594),"body height %.2f"%height,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("b1c6d6"))

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var arena := Arena.new()
	root.size=Vector2i(1280,720)
	root.title="Stage 05 action arena"
	root.add_child(arena)
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output=arg.trim_prefix("--capture=")
	if output.is_empty(): return
	arena.capture=true; arena.paused=true
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output)
	assert(error==OK,"Capture failed")
	print("STAGE05_ART_CAPTURE "+output)
	quit(0)
