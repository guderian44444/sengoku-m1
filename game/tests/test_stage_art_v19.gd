extends SceneTree

const StageArt = preload("res://render/stage_art.gd")
const THEMES = ["bamboo","ridge","village","gate","camp","courtyard","chamber"]
var checks := 0

func verify(ok: bool, message: String) -> void:
	checks += 1
	assert(ok,message)

func _initialize() -> void:
	var art := StageArt.new()
	verify(art.scenery_registration.version == "0.19","Load the new scenery registration")
	verify(art.border_frames.size() == 7,"Seven independent boundary cutouts")
	var unique := {}
	for theme in THEMES:
		var backdrop: Dictionary = art.background(theme)
		verify(not backdrop.is_empty() and backdrop.texture.get_width() >= 1536,"Full-resolution region backdrop: " + theme)
		unique[backdrop.source] = true
		verify(not art.borders(theme).is_empty(),"A transparent boundary selection exists: " + theme)
		verify(art.border(theme,art.borders(theme).size()).source_region == art.border(theme).source_region,"Boundary variants cycle safely: " + theme)
	verify(unique.size() == 7,"Seven scenes use seven different panorama sources")
	verify(art.border("missing").is_empty(),"Unknown decoration theme does not crash")
	verify(art.border("road").source_region == art.border("village").source_region,"Legacy route theme remains supported")
	var frames: Array = art.border_frames.values()
	for kind in ["screen","cabinet"]:
		frames.append(art.prop(kind))
		verify(not art.prop(kind,true).is_empty(),"Furniture breaks into existing wooden debris: " + kind)
		verify(art.prop(kind).footprint_depth > 0,"Furniture exposes a foot-level depth: " + kind)
	for frame in frames:
		var image: Image = frame.texture.get_image()
		verify(frame.body_height >= frame.display_height,"Native source has more pixels than display height")
		verify(image.get_format() == Image.FORMAT_RGBA8,"Cutout retains real alpha")
		verify(frame.anchor.y > image.get_height()-8 and frame.anchor.y < image.get_height(),"Anchor stays at the sprite foot, not its center")
		var clean := true
		for x in range(image.get_width()):
			clean = clean and image.get_pixel(x,0).a == 0 and image.get_pixel(x,image.get_height()-1).a == 0
		for y in range(image.get_height()):
			clean = clean and image.get_pixel(0,y).a == 0 and image.get_pixel(image.get_width()-1,y).a == 0
		verify(clean,"Transparent filter padding prevents neighboring atlas bleed")
		var source := Image.load_from_file(frame.source)
		var original := source.get_region(frame.source_region)
		verify(original.get_data() == image.get_region(Rect2i(2,2,original.get_width(),original.get_height())).get_data(),"Registration preserves authored source pixels")
	for key in ["wood_rail","bamboo_rail","interior_rail"]:
		var image: Image = art.border_frames[key].texture.get_image()
		var empty := 0
		var total := 0
		for y in range(int(image.get_height()*.25),int(image.get_height()*.75)):
			for x in range(int(image.get_width()*.17),int(image.get_width()*.83)):
				total += 1
				if image.get_pixel(x,y).a < .04: empty += 1
		verify(float(empty)/total > .25,"Open railing reveals the scenery behind: " + key)
	for source in art.scenery_registration.sources:
		verify(FileAccess.get_sha256(StageArt.SCENERY_ROOT+source) == art.scenery_registration.sources[source].sha256,"Generated source hash is unchanged: " + source)
	print("PASS: stage art v19 / %d checks; 7 unique scenes, real alpha gaps, original pixels and compatible props" % checks)
	quit()
