extends SceneTree
const Art = preload("res://render/art_assets.gd")
func _initialize() -> void:
	var art = Art.new()
	var output := "user://vfx-actors"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var info := {}
	for hero in ["ieyasu","nobunaga","oichi"]:
		var clips: Dictionary = art.animations[hero]
		var chosen := ""
		for key in clips:
			if str(key).ends_with("idle"): chosen = str(key)
		if chosen.is_empty(): chosen = str(clips.keys()[0])
		var frame: Dictionary = clips[chosen][0]
		var region: Rect2 = frame.region
		var bitmap: Image = frame.texture.get_image().get_region(Rect2i(region))
		bitmap.save_png(output.path_join(hero+".png"))
		info[hero] = {"clip":chosen,"anchor":[frame.anchor.x,frame.anchor.y],"body_height":frame.body_height,"size":[bitmap.get_width(),bitmap.get_height()]}
	var file := FileAccess.open(output.path_join("actors.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(info,"  "))
	print("PASS: sprite source export for OFFLINE compositor (not GPU capture)")
	quit()
