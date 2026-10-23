extends SceneTree
const Art=preload("res://render/stage07_10_art.gd")
class Sheet extends "res://render/battle_view.gd":
	var role := "saito-spear"
	var pose := 0
	func _draw() -> void:
		draw_rect(Rect2(0,0,448,360),Color("d8d1be"))
		draw_string(ThemeDB.fallback_font,Vector2(12,24),role+" / pose "+str(pose),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("554e40"))
		var frame := _stage0710_art.actor_frame(role,pose)
		var height := 154.0 if role.begins_with("civilian-") else 164.0
		_draw_art_frame(frame,Vector2(224,310),height,1,0,Color.WHITE,float(frame.body_height))
func _initialize() -> void: run.call_deferred()
func overviews(output: String) -> void:
	for faction in ["saito","miyoshi","asakura"]:
		var overview := Image.create(2688,1800,false,Image.FORMAT_RGBA8)
		for row in 5:
			var role: String=["spear","archer","gunner","shield","raider"][row]
			var sheet := Image.load_from_file(output.path_join(faction+"-"+role+".png"))
			var poses := [0,3,11,17,21,23]
			for column in 6:
				var pose: int=poses[column]
				overview.blit_rect(sheet,Rect2i((pose%4)*448,(pose/4)*360,448,360),Vector2i(column*448,row*360))
		assert(overview.save_png(output.path_join(faction+"-overview.png"))==OK)
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	assert(not output.is_empty() and DisplayServer.get_name()!="headless")
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	if "--overview-only" in OS.get_cmdline_user_args():
		overviews(output);print("TROOP_OVERVIEW_PASS");quit();return
	var canvas := SubViewport.new();canvas.size=Vector2i(448,360);canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(canvas)
	var board := Sheet.new();canvas.add_child(board)
	var roles: Array=board._stage0710_art.troops().keys()
	for kind in ["woman","elder","child"]: roles.append("civilian-"+kind)
	for role in roles:
		board.role=role
		var count := 4 if str(role).begins_with("civilian-") else 24
		var contact := Image.create(1792,360*ceili(count/4.0),false,Image.FORMAT_RGBA8)
		for pose in count:
			board.pose=pose;board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
			contact.blit_rect(canvas.get_texture().get_image(),Rect2i(0,0,448,360),Vector2i((pose%4)*448,(pose/4)*360))
		assert(contact.save_png(output.path_join(str(role)+".png"))==OK)
		print("TROOP_CONTACT ",role)
	overviews(output)
	board.queue_free();await process_frame;print("TROOP_CONTACT_PASS");quit()
