extends SceneTree

const StageArt = preload("res://render/stage_art.gd")
const View = preload("res://render/battle_view.gd")
var checks := 0

func verify(ok: bool, message: String) -> void:
	checks += 1
	assert(ok,message)

func _initialize() -> void:
	var art := StageArt.new()
	verify(art.props.size() >= 12 and art.food.size() == 4 and art.debris.size() == 4 and art.flags.size() == 4,"Preserve complete v18 foreground inventory when newer scenery is installed")
	for group in [art.props,art.food,art.debris,art.flags]:
		for key in group:
			var frame: Dictionary = group[key]
			var image: Image = frame.texture.get_image()
			verify(frame.body_height >= frame.display_height,"Never enlarge a low-resolution prop: " + str(key))
			verify(image.get_format() == Image.FORMAT_RGBA8,"Retain actual alpha: " + str(key))
			var clean := true
			for x in range(image.get_width()):
				clean = clean and image.get_pixel(x,0).a == 0 and image.get_pixel(x,image.get_height()-1).a == 0
			for y in range(image.get_height()):
				clean = clean and image.get_pixel(0,y).a == 0 and image.get_pixel(image.get_width()-1,y).a == 0
			verify(clean,"No adjacent atlas pixels at filtered texture edge: " + str(key))
	for source in art.registration.sources:
		verify(FileAccess.get_sha256(StageArt.ROOT+source) == art.registration.sources[source].sha256,"Untouched generated PNG: "+source)
	var unique := {}
	for theme in StageArt.THEMES:
		var background: Dictionary = art.background(theme)
		verify(not background.is_empty() and background.texture.get_width() >= 1536,"Registered panorama for " + theme)
		unique[background.source] = true
	verify(unique.size() >= 6,"Preserve six genuine base landscapes when newer scenery is installed")
	verify(StageArt.civilian_kinds("none").is_empty(),"No random civilians in military/indoor regions")
	verify(StageArt.civilian_kinds("villagers") != StageArt.civilian_kinds("vendors"),"Region-specific citizens")
	verify(is_equal_approx(View.enemy_display_height({"kind":"boss","stage_boss":true,"render_scale":1.3}),201.5),"Final commander is 1.3 times player anatomical height")
	verify(is_equal_approx(View.decor_offset("ground",480),480) and View.decor_offset("background",480) < 60,"Foreground and distant scenery move at different rates")
	print("PASS: stage art v18 / %d checks" % checks)
	quit()
