extends RefCounted

const Data = preload("res://core/stage04_data.gd")
const GROUND := ["rain_camp","rain_camp","rain_camp","rain_camp","camp"]
const FOREGROUND := [
	["grass","earth_low","wood_rail","shrubs"],
	["grass","earth_low","grass","shrubs"],
	["wood_rail","grass","basket","earth_low"],
	["grass","shrubs","earth_low","grass"],
	["rice_bales","grass","crate","bamboo_rail"]
]
var textures: Dictionary = {}

func texture(path: String) -> Texture2D:
	if not textures.has(path):
		var source := Image.load_from_file(Data.ROOT+path)
		assert(source != null,"Missing Mikawa art: "+path)
		source.generate_mipmaps()
		textures[path] = ImageTexture.create_from_image(source)
	return textures[path]

func frame(row: Dictionary) -> Dictionary:
	var tex := texture(str(row.path))
	var region := Rect2(Vector2.ZERO,tex.get_size())
	if row.has("region"): region = Rect2(row.region[0],row.region[1],row.region[2],row.region[3])
	return {"texture":tex,"region":region,"anchor":Vector2(row.anchor[0],row.anchor[1]),"body_height":float(row.body_height),"opaque_bounds":Rect2(Vector2.ZERO,region.size)}

func image_frame(path: String, anchor: Vector2, height: float) -> Dictionary:
	return frame({"path":path,"anchor":[anchor.x,anchor.y],"body_height":height})

func sample(world: Dictionary, fighter: Dictionary, walk_tick: float, clock_tick: float) -> Dictionary:
	var role: String = fighter.mikawa_role
	var action: String = fighter.action
	var clips: Dictionary = Data.actors()[role]
	var clip := "idle"
	var time := float(fighter.action_tick)*1000.0/60.0
	if role == "udono":
		clip = "udono_walk" if fighter.get("moving",false) else "udono_idle"
		if clips.has(action): clip = action
		elif action in ["stunned","frozen"]: clip = "udono_stun"
		elif action == "hurt": clip = "udono_hurt"
		elif fighter.hp <= 0:
			var elapsed := float(int(world.tick)-int(world.mikawa.retreat_tick))*1000.0/60.0*Data.UDONO_SPEED
			clip = "udono_defeat_retreat"
			time = 0.0 if elapsed < 600 else (650.0 if elapsed < 950 else 1150.0)
			if elapsed >= 1300: clip = "udono_walk"; time = (elapsed-1300)*1.4
	else:
		if action == "idle" and fighter.get("moving",false): clip = "walk"
		elif action == "down" and not fighter.get("down_from_air",false): clip = "knockdown"
		elif action == "kira_arrow":
			clip = action
			if time >= 620 and time < 900: time = 540+fposmod(time-620,140)
		elif clips.has(action): clip = action
		elif action == "kira_volley":
			clip = "rain"
			if time >= 500: time = 690+fposmod(time-500,200)
		elif action == "bow_shot" or action.begins_with("spear_") or action == "commander_cut": clip = Data.attack_clip(role,action)
		elif action == "recovering": clip = "recovery"
		elif action in ["launched","thrown"]: clip = "knockdown"
		elif action == "grabbed":
			clip = "struggle" if clips.has("struggle") else "hurt"
			# Holding never advances into the unrelated standing frame at the end of hurt.
			if clip == "hurt": time = float(clips.hurt.frames[0].duration_ms)
		elif action in ["pulled","frozen"]: clip = "hurt"
		elif action == "defeated" or fighter.hp <= 0: clip = "knockdown"
		elif action == "retreat": clip = "withdraw" if clips.has("withdraw") else "walk"
		elif fighter.get("moving",false): clip = "walk"
	if clip in ["idle","udono_idle"]: time = clock_tick*1000.0/60.0
	elif clip in ["walk","withdraw","udono_walk"] and fighter.hp > 0: time = walk_tick*1000.0/60.0
	if role == "udono" and fighter.hp > 0: time *= Data.UDONO_SPEED
	var spec: Dictionary = clips[clip]
	var duration := Data.duration(role,clip)
	if bool(spec.loop): time = fposmod(time,duration)
	var index := 0
	while index < spec.frames.size()-1 and time >= float(spec.frames[index].duration_ms):
		time -= float(spec.frames[index].duration_ms)
		index += 1
	var row: Dictionary = spec.frames[index]
	var drawing := frame(row)
	if row.has("crest"): drawing.crest = {"texture":texture(str(row.crest.path)),"anchor":Vector2(row.crest.anchor[0],row.crest.anchor[1]),"width":float(row.crest.width)}
	# Authored gold trails share the same original canvas and root as each spin pose.
	if clip == "udono_melee_spin_counter":
		var path: String = str(row.path).replace("/frames/","/vfx/")
		drawing.behind = image_frame(path,Vector2(row.anchor[0],row.anchor[1]),float(row.body_height))
	return {"source":"stage4","sheet":"stage4","clip":clip,"cell":index,"frame":index,"count":spec.frames.size(),"tick":fighter.action_tick,"duration":duration,"released":not Data.HITS.has(action) or float(fighter.action_tick)*1000.0/60.0 >= float(Data.HITS[action][0]) if action != "kira_volley" else false,"genuine_reaction":true,"frame_data":drawing}

func prop(prop: Dictionary, tick: int) -> Dictionary:
	var asset: String = prop.mikawa_asset
	if asset in ["fence","cheval"]:
		var folder := "barricade" if asset == "fence" else "cheval"
		var state := "broken" if prop.broken else ("damaged" if prop.hp < prop.max_hp else "intact")
		return image_frame("props/%s/sprites/%s_%s.png"%[folder,folder,state],Vector2(800,740),740)
	var who := "kira" if asset == "kflag" else "udono"
	if prop.broken:
		var index := clampi((tick-int(prop.broken_tick))/6,0,7)
		return image_frame("props/flags/destroy/%s_wood_crossfoot_break_%02d.png"%[who,index],Vector2(360,683),683)
	var index := floori(float(tick)*1000.0/60.0/120.0+int(prop.id)*2)%8
	var path := "props/flags/frames/%s_%02d.png"%[who,index] if prop.hp == prop.max_hp else "props/flags/damage/%s_damaged_idle_%02d.png"%[who,index]
	return image_frame(path,Vector2(160,683),683)

func draw_landscape(view) -> void:
	var index := int(view.state.stage.index)
	var tex := texture("backgrounds/"+Data.BACKGROUNDS[index]+".png")
	var far_scale := 364.0/478.0
	var pan := clampf(view.camera_x*.06,0,tex.get_width()*far_scale-1280)
	view.draw_texture_rect_region(tex,Rect2(-pan,0,tex.get_width()*far_scale,364),Rect2(0,0,tex.get_width(),478))
	# Keep the 24 px transition from the authored scene; near ground uses the same native-resolution tiles as chapters 1-3.
	view.draw_texture_rect_region(tex,Rect2(-pan,364,tex.get_width()*far_scale,24),Rect2(0,478,tex.get_width(),24/far_scale))
	var ground: Dictionary = view._stage_art.backgrounds[GROUND[index]]
	var region: Rect2 = ground.region
	var horizon: float = region.size.y*float(ground.horizon)
	view._draw_near_ground(ground,Rect2(region.position+Vector2(0,horizon),Vector2(region.size.x,region.size.y-horizon)))
	if index != 4: return
	var crowd: Dictionary = Data.read("backgrounds/crowd/animation_events.json")
	for actor in crowd.placement:
		var time := fposmod(float(view.state.tick)*1000/60+float(actor.phase_ms),880)
		var cell := 0
		while cell < 3 and time >= float(crowd.loop_durations_ms[cell]): time -= float(crowd.loop_durations_ms[cell]); cell += 1
		var drawing := image_frame("backgrounds/crowd/frames/%s_%02d.png"%[actor.type,cell],Vector2(crowd.foot_anchor[0],crowd.foot_anchor[1]),float(crowd.foot_anchor[1]))
		var origin := Vector2(float(actor.x)*far_scale-pan,float(actor.foot_y)*far_scale)
		view._draw_art_frame(drawing,origin,384*float(actor.scale)*far_scale,-1 if actor.flip else 1,0,Color.WHITE,float(drawing.body_height))

func draw_foreground(view) -> void:
	var kinds: Array = FOREGROUND[int(view.state.stage.index)]
	var offset: float = view.camera_x*1.06
	for shadows in [true,false]:
		for index in range(floori(offset/310)-1,floori((offset+1280)/310)+2):
			var kind: String = kinds[posmod(index,kinds.size())]
			var drawing: Dictionary = view._stage_art.border_frames.get(kind,view._stage_art.props.get(kind,{}))
			var foot := Vector2(index*310+posmod(index*73,95)-offset,708+posmod(index*17,11))
			var height := minf(96,float(drawing.display_height)*1.35)*(0.92+posmod(index,3)*.04)
			if shadows: view._ellipse(foot+Vector2(8,-3),Vector2(height*.65,10),Color(0,0,0,.22))
			else: view._draw_art_frame(drawing,foot,height,-1 if posmod(index,3)==0 else 1,0,Color(.85,.88,.82),float(drawing.body_height))

func effect(view, effect: Dictionary) -> bool:
	var origin := Vector2(float(effect.x)-view.camera_x,float(effect.y))
	var kind := str(effect.get("mikawa_projectile",""))
	if kind == "rain":
		view._draw_arrow(origin-Vector2(0,float(effect.z)),Vector2(0,1) if int(effect.life) < 24 else Vector2(float(effect.face),-2),false)
		return true
	if kind == "stone":
		var tex := texture("characters/udono/rock/stone.png")
		var drawing := image_frame("characters/udono/rock/stone.png",tex.get_size()*.5,tex.get_height())
		view._ellipse(origin,Vector2(14,5),Color(0,0,0,.25))
		view._draw_art_frame(drawing,origin-Vector2(0,float(effect.z)),32,1,0,Color.WHITE,float(drawing.body_height))
		return true
	if kind == "wave":
		var spec: Dictionary = Data.read("characters/minibosses/specials/special_attack_events.json").tominaga
		var time := float(int(effect.max_life)-int(effect.life))*1000/60
		var cell := 0
		while cell < 7 and time >= float(spec.effect_frame_ms[cell]): time -= float(spec.effect_frame_ms[cell]); cell += 1
		var rect: Array = spec.effect_source_rects[cell]
		var drawing := frame({"path":"characters/minibosses/specials/"+str(spec.effect_atlas),"region":rect,"anchor":[0,[224,224,176,176,148,148,105,105][cell]],"body_height":rect[2],"duration_ms":1})
		view._draw_art_frame(drawing,Vector2(float(effect.origin_x)-view.camera_x,effect.y),680,float(effect.face),0,Color.WHITE,float(drawing.body_height))
		return true
	if effect.type != "mikawa_fx": return false
	var cell := mini(3,int((1.0-float(effect.life)/float(effect.max_life))*4))
	if effect.asset == "quake":
		var path := "characters/udono/base/radial_phase_%d.png"%cell
		var tex := texture(path)
		var drawing := image_frame(path,tex.get_size()*.5,tex.get_width())
		view._draw_art_frame(drawing,origin,float(effect.radius)*2,1,0,Color.WHITE,float(drawing.body_height))
	else:
		var path := "characters/udono/rock/vfx/impact_%d.png"%cell
		var tex := texture(path)
		view._draw_art_frame(image_frame(path,tex.get_size()*.5,tex.get_width()),origin-Vector2(0,float(effect.get("z",0))),85,1,0,Color.WHITE,tex.get_width())
	return true
