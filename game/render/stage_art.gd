extends RefCounted

const ROOT := "res://assets/v18/"
const SCENERY_ROOT := "res://assets/v19/scenery/"
const STAGE2_ROOT := "res://assets/v29/stage2/"
const STAGE3_ROOT := "res://assets/stage3/"
const STAGE3_BACKGROUNDS := ["rain_camp","barrier_camp","command_front","command_inside"]
const STAGE2_HORIZONS := {"supply_road":0.515,"riverbank":0.565,"granary":0.515,"switchback":0.56,"marune_gate":0.55,"supply_court":0.515}
const THEMES := {"bamboo":"bamboo","ridge":"ridge","village":"village","road":"village","outpost":"fort","gate":"fort","camp":"camp","courtyard":"courtyard","command":"camp","chamber":"chamber"}
const DEBRIS := {"jar":"ceramic","basket":"wicker","barricade":"bamboo","fence":"bamboo","planter":"ceramic","stone_lantern":"ceramic","rice_bales":"wicker"}
var props: Dictionary = {}
var food: Dictionary = {}
var debris: Dictionary = {}
var backgrounds: Dictionary = {}
var flags: Dictionary = {}
var registration: Dictionary = {}
var scenery_registration: Dictionary = {}
var border_frames: Dictionary = {}
var stage3_props: Dictionary = {}
var _images: Dictionary = {}

func _init() -> void:
	if not FileAccess.file_exists(ROOT + "registration.json"): return
	registration = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "registration.json"))
	for group in ["props","food","debris","flags"]:
		var target: Dictionary = get(group)
		for key in registration[group]: target[key] = _frame(registration[group][key])
	for key in registration.backgrounds:
		var entry: Dictionary = registration.backgrounds[key]
		var image := _image(str(entry.source))
		backgrounds[key] = {"texture":ImageTexture.create_from_image(image),"region":Rect2(Vector2.ZERO,image.get_size()),"horizon":float(entry.horizon),"source":str(entry.source)}
	if FileAccess.file_exists(SCENERY_ROOT + "registration.json"):
		scenery_registration = JSON.parse_string(FileAccess.get_file_as_string(SCENERY_ROOT + "registration.json"))
		for key in scenery_registration.props: props[key] = _frame(scenery_registration.props[key],SCENERY_ROOT)
		for key in scenery_registration.borders: border_frames[key] = _frame(scenery_registration.borders[key],SCENERY_ROOT)
		for key in scenery_registration.backgrounds:
			var entry: Dictionary = scenery_registration.backgrounds[key]
			var image := _image(str(entry.source),SCENERY_ROOT)
			backgrounds[key] = {"texture":ImageTexture.create_from_image(image),"region":Rect2(Vector2.ZERO,image.get_size()),"horizon":float(entry.horizon),"source":SCENERY_ROOT+str(entry.source)}
	for key in STAGE2_HORIZONS:
		var image := _image(str(key) + ".png",STAGE2_ROOT)
		if image != null:
			backgrounds[key] = {"texture":ImageTexture.create_from_image(image),"region":Rect2(Vector2.ZERO,image.get_size()),"horizon":float(STAGE2_HORIZONS[key]),"source":STAGE2_ROOT+str(key)+".png"}
	for key in STAGE3_BACKGROUNDS:
		var image := _image(key + ".png",STAGE3_ROOT)
		assert(image != null,"Missing Stage 3 background: " + key)
		backgrounds[key] = {"texture":ImageTexture.create_from_image(image),"region":Rect2(Vector2.ZERO,image.get_size()),"horizon":.53 if key in ["rain_camp","barrier_camp"] else .50,"source":STAGE3_ROOT+key+".png"}
	var objects := ["bell","pillar","pillar_cracked","pillar_split","pillar_debris","barrier","barrier_debris","tent"]
	for index in range(objects.size()):
		var entry := {"source":"props.png","region":[(index%4)*384,(index/4)*512,384,512],"anchor":[192,508 if index < 4 else 470],"body_height":502}
		if index == 0: entry.anchor = [192,84]; entry.body_height = 400
		elif index == 4: entry.body_height = 220
		elif index in [5,6]: entry.body_height = 380
		elif index == 7: entry.body_height = 440
		stage3_props[objects[index]] = _frame(entry,STAGE3_ROOT)
	_images.clear()

func _image(source: String, root: String = ROOT) -> Image:
	var path := root + source
	if not _images.has(path): _images[path] = Image.load_from_file(path)
	return _images[path]

func _frame(entry: Dictionary, root: String = ROOT) -> Dictionary:
	var r: Array = entry.region
	var region := Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
	var crop := _image(str(entry.source),root).get_region(region)
	# Transparent padding isolates bilinear filtering without changing the authored pixels.
	var padded := Image.create(crop.get_width()+4,crop.get_height()+4,false,Image.FORMAT_RGBA8)
	padded.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(2,2))
	return {"texture":ImageTexture.create_from_image(padded),"region":Rect2(Vector2.ZERO,padded.get_size()),"anchor":Vector2(float(entry.anchor[0])+2,float(entry.anchor[1])+2),"body_height":float(entry.body_height),"display_height":float(entry.get("display_height",40)),"source":(root if root != ROOT else "")+str(entry.source),"source_region":region,"footprint_depth":float(entry.get("footprint_depth",0))}

func background(theme: String, chapter: int = 0, scene: int = 0) -> Dictionary:
	if chapter == 3: return backgrounds[STAGE3_BACKGROUNDS[clampi(scene,0,3)]]
	var key: String = theme if STAGE2_HORIZONS.has(theme) else THEMES.get(theme,"bamboo")
	if key == "courtyard" and not backgrounds.has(key): key = "camp"
	return backgrounds.get(key,{})

func borders(theme: String) -> Array:
	var result := []
	var key: String = {"road":"village","outpost":"gate","command":"camp","supply_road":"bamboo","riverbank":"ridge","granary":"village","switchback":"ridge","marune_gate":"gate","supply_court":"courtyard"}.get(theme,theme)
	for id in scenery_registration.get("border_themes",{}).get(key,[]):
		if border_frames.has(id): result.append(border_frames[id])
	return result

func border(theme: String, index: int = 0) -> Dictionary:
	var options := borders(theme)
	return options[posmod(index,options.size())] if not options.is_empty() else {}

func prop(kind: String, broken: bool = false) -> Dictionary:
	return debris.get(DEBRIS.get(kind,"wood"),{}) if broken else props.get(kind,{})

static func civilian_kinds(group: String) -> Array:
	return {"villagers":["woman","child","elder"],"vendors":["cart_vendor","herb_vendor","produce_vendor"],"porters":["cart_vendor","elder"],"none":[]}.get(group,[])
