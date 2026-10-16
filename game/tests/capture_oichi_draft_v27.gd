extends SceneTree

const View = preload("res://render/battle_view.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
var checks := 0
var failures := 0

class DraftView extends View:
	var frames: Array = []
	var clip := ""
	var preview_height := 148.0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),Color("686868"))
		Typography.draw_label(self,Vector2(24,28),"Oichi draft / " + clip + " / actual world height " + str(preview_height),18,Color.WHITE)
		var actor := {"kind":"oichi","weapon_id":Weapons.default_for("oichi")}
		for index in range(frames.size()):
			var frame: Dictionary = frames[index]
			var origin := Vector2(200+(index%3)*400,285+(index/3)*350)
			draw_line(origin+Vector2(-150,0),origin+Vector2(150,0),Color(.3,.3,.3),1)
			_weapons.draw_weapon(self,actor,frame,origin,preview_height,1,0,Color.WHITE,true)
			_draw_art_frame(frame,origin,preview_height,1,0,Color.WHITE,float(frame.body_height))
			_weapons.draw_weapon(self,actor,frame,origin,preview_height,1,0,Color.WHITE,false)
			_weapons.draw_hand_occlusion(self,frame,origin,preview_height,1,0,Color.WHITE)
			Typography.draw_label(self,origin+Vector2(-160,35),"frame %d / anatomical ruler %.0f px" % [index+1,frame.body_height],14,Color.WHITE)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var manifest := ""
	var source_folder := ""
	var output := ""
	var preview_height := 148.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--manifest="): manifest=argument.trim_prefix("--manifest=")
		if argument.begins_with("--sources="): source_folder=argument.trim_prefix("--sources=")
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		if argument.begins_with("--height="): preview_height=float(argument.trim_prefix("--height="))
	check(not manifest.is_empty() and not source_folder.is_empty() and not output.is_empty(),"Explicit external draft manifest, source folder, and output required")
	if failures:
		quit(1)
		return
	if not source_folder.ends_with("/"): source_folder += "/"
	var registration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	for filename in registration.get("sources",{}):
		check(FileAccess.get_sha256(source_folder+str(filename))==registration.sources[filename].sha256,"Draft source hash still matches: "+str(filename))
	if failures:
		quit(1)
		return
	root.content_scale_size=Vector2i(1200,740)
	root.size=Vector2i(1200,740)
	var view:=DraftView.new()
	root.add_child(view)
	view.preview_height=preview_height
	view._art.load_layered_hero_registration("oichi",source_folder,registration)
	DirAccess.make_dir_recursive_absolute(output)
	for clip in registration.clips:
		view.clip=clip
		view.frames=view._art.animations.oichi["v22_"+clip]
		check(view.frames.size()==6,clip+" has six source frames")
		for frame in view.frames:
			check(frame.source_version=="v27" and str(frame.source_file).begins_with(source_folder),clip+" selects draft source only")
			if frame.has("clip_polygon"):
				check(Geometry2D.triangulate_polygon(frame.clip_polygon).size()>0,clip+" isolation contour triangulates in Godot")
		if DisplayServer.get_name() != "headless":
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join(str(clip)+".png"))==OK,clip+" native renderer screenshot saved")
	print("OICHI DRAFT %s: %d checks, %d failures; native viewport capture=%s" % ["PASS" if failures==0 else "FAILED",checks,failures,str(DisplayServer.get_name()!="headless")])
	view.queue_free()
	await process_frame
	quit(1 if failures else 0)
