extends RefCounted

const Data = preload("res://core/stage07_10_data.gd")
const ROOT := "res://assets/stages07-10/"
const HORIZONS := {7:.61,8:.61,9:.56,10:.55}
const HEIGHTS := {"ujie":180.0,"inaba":194.0,"nagai":178.0,"tatsuoki":188.0,"nagayasu":182.0,"iwanari":192.0,"kagetsune":188.0,"yoshikage":194.0}
var textures := {}
var frames := {}
var manifest: Dictionary = {}
var props: Dictionary = {}

func actors() -> Dictionary:
	if manifest.is_empty(): manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"actors.json"))
	return manifest.actors

static func height(fighter: Dictionary) -> float:
	return float(HEIGHTS.get(str(fighter.get("expedition_role","")),146.0))

func texture(path: String) -> Texture2D:
	if not textures.has(path):
		var image := Image.load_from_file(path)
		assert(image!=null,"Missing expedition art: "+path)
		image.generate_mipmaps()
		textures[path]=ImageTexture.create_from_image(image)
	return textures[path]

func actor_frame(role: String, index: int) -> Dictionary:
	var key := role+":"+str(index)
	if frames.has(key): return frames[key]
	var actor: Dictionary=actors()[role]
	var row: Dictionary=actor.frames[index]
	var polygon := PackedVector2Array()
	for p in row.polygon: polygon.append(Vector2(p[0],p[1]))
	frames[key]={"texture":texture(ROOT+str(row.get("path",actor.path))),"region":Rect2(row.region[0],row.region[1],row.region[2],row.region[3]),"anchor":Vector2(row.anchor[0],row.anchor[1]),"body_height":float(row.get("body_height",actor.body_height)),"opaque_bounds":Rect2(0,0,row.region[2],row.region[3]),"clip_polygon":polygon}
	return frames[key]

static func attack_frame(spec: Dictionary, tick: float, count: int, impact_indices: Array = []) -> int:
	var hits: Array=spec.hits
	if count<=4:
		if tick<float(hits[0]): return 0 if tick<float(hits[0])*.45 else 1
		for i in hits.size():
			if tick<float(hits[i])+8: return mini(2,count-1)
			if i<hits.size()-1 and tick<float(hits[i+1]): return 1
		return count-1
	var marks := [0.0]
	var poses := [0]
	for i in hits.size():
		marks.append(float(hits[i]))
		poses.append(int(impact_indices[i]) if i<impact_indices.size() else (3+i*2 if hits.size()<3 else [3,5,6][i]))
	marks.append(float(spec.duration));poses.append(count-1)
	for i in range(1,marks.size()):
		if tick<=marks[i]: return clampi(floori(lerpf(float(poses[i-1]),float(poses[i]),inverse_lerp(marks[i-1],marks[i],tick))),0,count-1)
	return count-1

func sample(world: Dictionary, fighter: Dictionary, walk_tick: float, clock_tick: float) -> Dictionary:
	var role := str(fighter.expedition_role)
	var clips: Dictionary=actors()[role].clips
	var action := str(fighter.action)
	var tick := float(fighter.action_tick)
	var clip := "idle"
	var cell := 0
	var duration := 60.0
	var released := false
	if fighter.hp<=0 or action in ["dead","defeated","down"]:
		clip="down"; duration=float(fighter.get("death_ticks",48));cell=mini(clips.down.size()-1,floori(tick/maxf(1,duration)*clips.down.size()))
		if action=="dead" or fighter.get("down_from_air",false): cell=clips.down.size()-1
	elif action=="recovering":
		clip="recover";duration=36;cell=mini(clips.recover.size()-1,floori(tick/duration*clips.recover.size()))
	elif action in ["thrown","launched"]: clip="down";cell=1
	elif action in ["hurt","stunned","grabbed","pulled","frozen"]:
		clip="hurt";cell=0 if tick<7 else mini(1,clips.hurt.size()-1)
	elif Data.ACTIONS.has(action):
		var spec: Dictionary=Data.ACTIONS[action]
		clip=spec.art_clip;duration=float(spec.duration)
		cell=attack_frame(spec,tick,clips[clip].size(),actors()[role].impact_indices[clip])
		released=tick>=float(spec.hits[0])
	elif action=="guard": clip="guard";cell=mini(1,clips.guard.size()-1)
	elif fighter.get("moving",false) or fighter.get("entering",false):
		clip="walk";cell=posmod(floori(walk_tick/7.0),clips.walk.size())
	else: cell=posmod(floori(clock_tick/12.0),clips.idle.size())
	cell=clampi(cell,0,clips[clip].size()-1)
	return {"source":"stage0710","sheet":"stage0710","clip":clip,"cell":cell,"frame":cell,"count":clips[clip].size(),"tick":tick,"duration":duration,"released":released,"genuine_reaction":true,"native_face":1,"frame_data":actor_frame(role,int(clips[clip][cell]))}

func draw_landscape(view) -> void:
	var stage := int(view.state.stage.id)
	var image := texture(ROOT+"backgrounds/s%02d.png"%stage)
	var horizon := image.get_height()*float(HORIZONS[stage])
	var scale := 364.0/horizon
	var width := image.get_width()*scale
	var pan := clampf(float(view.state.stage.index)*maxf(0,width-1280)/4.0+view.camera_x*.035,0,maxf(0,width-1280))
	view.draw_texture_rect_region(image,Rect2(-pan,0,width,364),Rect2(0,0,image.get_width(),horizon))
	view._draw_near_ground({"texture":image,"region":Rect2(Vector2.ZERO,image.get_size())},Rect2(0,horizon,image.get_width(),image.get_height()-horizon))

func simple_frame(path: String, region: Rect2, anchor: Vector2, body: float, display: float) -> Dictionary:
	return {"texture":texture(path),"region":region,"anchor":anchor,"body_height":body,"display_height":display,"opaque_bounds":Rect2(Vector2.ZERO,region.size)}

func prop(item: Dictionary, _tick: int) -> Dictionary:
	var asset := str(item.expedition_asset)
	if props.is_empty(): props=JSON.parse_string(FileAccess.get_file_as_string("res://assets/v18/registration.json"))
	if asset=="signal" and not item.broken:
		var image := texture(ROOT+"props/signal.png")
		return simple_frame(ROOT+"props/signal.png",Rect2(Vector2.ZERO,image.get_size()),Vector2(image.get_width()*.5,image.get_height()*.927),image.get_height()*.883,188)
	var id: String = {"rock_support":"fence","gate":"barricade","barricade":"barricade","supplies":"rice_bales","signal":"fence"}[asset]
	var row: Dictionary=props.debris.wood if item.broken else props.props[id]
	var display := 36.0 if item.broken else (180.0 if asset=="gate" else (118.0 if asset=="rock_support" else float(row.display_height)))
	return simple_frame("res://assets/v18/"+str(row.source),Rect2(row.region[0],row.region[1],row.region[2],row.region[3]),Vector2(row.anchor[0],row.anchor[1]),float(row.body_height),display)

static func civilian_samples(world: Dictionary) -> Array:
	var people := []
	var civilians: Array=world.get("expedition",{}).get("civilians",[])
	for index in civilians.size():
		var c: Dictionary=civilians[index]
		if c.safe: continue
		var moving := bool(c.walking)
		people.append({"scenery_npc":true,"kind":["woman","elder","child"][index%3],"x":c.x,"y":c.y,"height":[126.0,122.0,90.0][index%3],"face":1,"frame":posmod(int(world.tick)/8+index,6) if moving else 0,"distance":0.0,"stride":80.0,"speed":90.0 if moving else 0.0,"activity":"walk","mode":"run" if moving else "walk"})
	return people

func draw_attack_warning(view, effect: Dictionary) -> void:
	var center := Vector2(float(effect.x)-view.camera_x,float(effect.y))
	var radius := float(effect.radius)
	var depth := float(effect.get("depth",55))
	var box := Rect2(center-Vector2(radius,depth),Vector2(radius*2,depth*2))
	var pulse := .7+.3*sin(float(view.state.tick)*.22)
	view.draw_rect(box,Color(.78,.22,.075,.12+.04*pulse))
	view.draw_rect(box,Color(1,.61,.23,.72+.2*pulse),false,2.0)
	for x in range(ceili(box.position.x/48)*48,floori(box.end.x),48):
		view.draw_line(Vector2(x,box.position.y),Vector2(x+14,box.position.y+7),Color(1,.75,.4,.65),2,true)

func draw_hazards(view) -> void:
	for h in view.state.get("expedition",{}).get("hazards",[]):
		var at := Vector2(float(h.x)-view.camera_x,float(h.y))
		var progress := clampf(float(h.age)/float(h.warning),0,1)
		var size := Vector2(float(h.radius),float(h.depth))
		if h.age<h.warning:
			view.draw_rect(Rect2(at-size,size*2),Color(.7,.12,.03,.12+progress*.10))
			view.draw_rect(Rect2(at-size,size*2),Color(1,.62,.25,.75),false,2,true)
			view.draw_line(at-Vector2(size.x,size.y),at-Vector2(size.x,size.y)+Vector2(size.x*2*progress,0),Color(1,.9,.55),4,true)
			if h.kind=="fireline":
				var direction := 1 if float(h.from_x)<float(h.x) else -1
				for x in range(-int(size.x)+24,int(size.x)-12,80):
					var tip := at+Vector2(x,0)
					view.draw_polyline(PackedVector2Array([tip+Vector2(-direction*12,-7),tip,tip+Vector2(-direction*12,7)]),Color(1,.82,.53,.9),2,true)
			continue
		var age := float(h.age-h.warning)/30.0
		if h.kind=="rock":
			view._draw_dust(at,float(h.radius),age,1-age)
			for i in 4:
				var offset := Vector2(sin(i*2.4)*size.x*.55,cos(i*2.4)*size.y*.5)
				view._paint_ice(at+offset,Vector2(22,28*(1-age)),i,(1-age)*.85,Color("88745c"))
		elif h.kind=="arrows":
			for i in 9:
				var point := at+Vector2(sin(i*2.4)*size.x*.8,cos(i*2.4)*size.y*.8)-Vector2(0,maxf(0,1-age*4)*260)
				view._draw_arrow(point,Vector2.DOWN,false,1-age)
		elif h.kind=="fireline":
			var from := Vector2(float(h.from_x)-view.camera_x,float(h.y))
			if age<.3: view.draw_line(from,at,Color(1,.83,.45,(1-age/.3)*.9),2.5,true)
			view._draw_dust(at,36,age,.6*(1-age))
		elif h.kind=="powder":
			for i in 5:
				var point := at+Vector2(sin(i*2.4)*size.x*.7,cos(i*2.4)*size.y*.5)
				if view._fx.configured:
					view._fx.shared_player.draw_phase(view,"fire_burn",float(h.age-h.warning),30,point-Vector2(0,35),true,{"opacity":[[0,.9],[.45,.8],[1,0]]},{"size":95,"stretch":Vector2(.8,1.1)})
				else: view._paint_flame(point,70*(1-age),i,1-age)
			view._draw_dust(at,size.x,age,.6*(1-age))
		else: view._draw_dust(at,size.x,age,.85*(1-age))

func actor_fx(view, fighter: Dictionary, origin: Vector2) -> void:
	if not Data.ACTIONS.has(str(fighter.action)): return
	var spec: Dictionary=Data.ACTIONS[str(fighter.action)]
	var tick := int(fighter.action_tick)
	for hit in spec.hits:
		var age := tick-int(hit)
		if age<0 or age>9: continue
		if spec.kind in ["rain","crossfire","reinforce","powder","burst"]: continue
		var face := float(fighter.face)
		var radius := minf(float(spec.reach),225)
		var center := origin+Vector2(face*30,-height(fighter)*.48)
		if view._fx.configured:
			var thrust: bool = fighter.expedition_role=="kagetsune" or (fighter.expedition_role=="ujie" and spec.kind!="hook")
			var low: bool = spec.kind=="low" or (spec.kind=="advance" and hit==spec.hits.back())
			var at := origin+Vector2(face*radius*.55,-(25.0 if low else height(fighter)*.5))
			var angle: float = 0.0 if thrust else (.5 if spec.kind=="quake" else -.3+spec.hits.find(hit)*.35)
			var stretch := Vector2(1,.45) if thrust or low else Vector2(1,.8)
			view._fx.shared_player.draw_phase(view,"neutral_thrust_cone" if thrust else "neutral_slash_arc",float(age),10,at,true,{"opacity":[[0,.75],[.3,.95],[1,0]]},{"face":face,"rotation":angle,"size":radius*(.9 if thrust else 1.5),"stretch":stretch})
			continue
		view.draw_set_transform(center,0,Vector2(face,.45))
		var alpha := (1-float(age)/10)*.8
		view.draw_arc(Vector2.ZERO,radius,-1.15+.12*age,.95+.12*age,24,Color(.79,.78,.6,alpha*.2),15,true)
		view.draw_arc(Vector2.ZERO,radius,-1.15+.12*age,.95+.12*age,24,Color(1,.96,.76,alpha),3,true)
		view.draw_set_transform(Vector2.ZERO)

func effect(_view, _effect: Dictionary) -> bool:
	return false
