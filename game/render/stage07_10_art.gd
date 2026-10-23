extends RefCounted

const Data = preload("res://core/stage07_10_data.gd")
const ROOT := "res://assets/stages07-10/"
const HORIZONS := {7:.61,8:.61,9:.56,10:.55}
const HEIGHTS := {"ujie":180.0,"inaba":194.0,"nagai":178.0,"tatsuoki":188.0,"nagayasu":182.0,"iwanari":192.0,"kagetsune":188.0,"yoshikage":194.0}
var textures := {}
var frames := {}
var manifest: Dictionary = {}
var troop_manifest: Dictionary = {}
var props: Dictionary = {}

static func landscape_path(stage: int, region: int) -> String:
	return ROOT+("backgrounds/s%02d.png"%stage if region=={7:1,8:0,9:1,10:0}[stage] else "backgrounds/s%02d-%d.png"%[stage,region])

func actors() -> Dictionary:
	if manifest.is_empty(): manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"actors.json"))
	return manifest.actors

static func height(fighter: Dictionary) -> float:
	var role := str(fighter.get("expedition_role",""))
	return float(HEIGHTS.get(role,{"spear":164.0,"archer":160.0,"gunner":162.0,"shield":170.0,"raider":166.0}.get(role,164.0)))

func troops() -> Dictionary:
	if troop_manifest.is_empty(): troop_manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"troops.json"))
	return troop_manifest.actors

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
	var actor: Dictionary
	if role.begins_with("civilian-"):
		troops()
		actor=troop_manifest.civilians[role.trim_prefix("civilian-")]
	else: actor=actors()[role] if actors().has(role) else troops()[role]
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
	if not Data.BOSSES.has(role): role=str(fighter.faction)+"-"+role
	var actor: Dictionary=actors()[role] if actors().has(role) else troops()[role]
	var clips: Dictionary=actor.clips
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
		cell=attack_frame(spec,tick,clips[clip].size(),actor.impact_indices[clip])
		released=tick>=float(spec.hits[0])
	elif action=="guard": clip="guard";cell=mini(1,clips.guard.size()-1)
	elif fighter.get("expedition_attacking",false):
		var timing: Array=fighter.expedition_timing
		clip="attack";duration=float(timing[1]);released=tick>=float(timing[0])
		cell=attack_frame({"hits":[timing[0]],"duration":timing[1]},tick,8,[3])
	elif fighter.get("moving",false) or fighter.get("entering",false):
		clip="walk";cell=posmod(floori(walk_tick/7.0),clips.walk.size())
	else: cell=posmod(floori(clock_tick/12.0),clips.idle.size())
	cell=clampi(cell,0,clips[clip].size()-1)
	return {"source":"stage0710","sheet":"stage0710","clip":clip,"cell":cell,"frame":cell,"count":clips[clip].size(),"tick":tick,"duration":duration,"released":released,"genuine_reaction":true,"native_face":1,"frame_data":actor_frame(role,int(clips[clip][cell]))}

func draw_landscape(view) -> void:
	var stage := int(view.state.stage.id)
	var image := texture(landscape_path(stage,int(view.state.stage.index)))
	var horizon := image.get_height()*float(HORIZONS[stage])
	var scale := 364.0/horizon
	var width := image.get_width()*scale
	var pan := clampf(view.camera_x*.18,0,maxf(0,width-1280))
	view.draw_texture_rect_region(image,Rect2(-pan,0,width,364),Rect2(0,0,image.get_width(),horizon))
	view._draw_near_ground({"texture":image,"region":Rect2(Vector2.ZERO,image.get_size())},Rect2(0,horizon,image.get_width(),image.get_height()-horizon))

func simple_frame(path: String, region: Rect2, anchor: Vector2, body: float, display: float) -> Dictionary:
	return {"texture":texture(path),"region":region,"anchor":anchor,"body_height":body,"display_height":display,"opaque_bounds":Rect2(Vector2.ZERO,region.size)}

func prop(item: Dictionary, _tick: int) -> Dictionary:
	var asset := str(item.expedition_asset)
	if asset=="rock_support":
		var image := texture(ROOT+"props/rock-support.png")
		var cell := image.get_width()/3.0
		var index := 2 if item.broken else (1 if float(item.hp)/float(item.max_hp)<.5 else 0)
		return simple_frame(ROOT+"props/rock-support.png",Rect2(index*cell,0,cell,image.get_height()),Vector2(cell*.5,image.get_height()*.93),image.get_height()*.86,62 if item.broken else 148)
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
	var civilians: Array=world.get("expedition",{}).get("civilians",[]).duplicate()
	if civilians.is_empty() and int(world.get("stage",{}).get("id",0)) in [7,8,10]:
		var elapsed := maxi(0,int(world.tick)-int(world.stage.get("entered_tick",0))-18)
		for i in 3:
			var speed: float=[3.5,2.8,3.8][i]
			var x: float=[430.0,520.0,620.0][i]+elapsed*speed
			if x>float(world.stage.width)+180: continue
			var y: float=[400.0,555.0,590.0][i]
			for item in world.get("props",[]):
				if item.get("expedition_asset","")=="supplies": continue
				var clearance := float(item.depth)*.5+32
				if absf(y-float(item.y))>=clearance: continue
				var side := 1.0 if y>=float(item.y) else -1.0
				var lane: float=item.y+side*clearance
				if lane<365 or lane>595: lane=item.y-side*clearance
				var blend := clampf((float(item.width)*.5+120-absf(x-float(item.x)))/100,0,1)
				y=lerpf(y,lane,smoothstep(0,1,blend))
			civilians.append({"kind":["woman","elder","child"][i],"x":x,"y":y,"safe":false,"walking":elapsed>0,"distance":elapsed*speed})
	for index in civilians.size():
		var c: Dictionary=civilians[index]
		if c.safe: continue
		var moving := bool(c.walking)
		var kind: String=str(c.get("kind",["woman","elder","child"][index%3]))
		var distance := float(c.get("distance",0))
		people.append({"scenery_npc":true,"expedition_npc":true,"kind":kind,"x":c.x,"y":c.y,"height":{"woman":154.0,"elder":150.0,"child":130.0}[kind],"face":1,"frame":posmod(floori(distance/38.0),4) if moving else 0,"distance":distance,"stride":152.0,"speed":210.0 if moving else 0.0,"activity":"walk","mode":"run" if moving else "walk"})
	return people

func civilian_frame(person: Dictionary) -> Dictionary:
	return actor_frame("civilian-"+str(person.kind),int(person.frame))

func draw_rockfall(view, h: Dictionary, falling_stone: bool=false) -> void:
	var at := Vector2(float(h.x)-view.camera_x,float(h.y))
	var progress := clampf(float(h.age)/float(h.warning),0,1)
	var image := texture(ROOT+"props/rockfall.png")
	var cell := Vector2(image.get_width()/4.0,image.get_height()/2.0)
	var variant := posmod(int(h.x)*13+int(h.y),4)
	var rock := simple_frame(ROOT+"props/rockfall.png",Rect2(Vector2(variant*cell.x,0),cell),cell*.5,cell.y*.9,108)
	if h.age<h.warning:
		if falling_stone:
			view._draw_art_frame(rock,at-Vector2(0,42+360*pow(1-progress,1.6)),108,1,progress*1.4,Color.WHITE,float(rock.body_height))
			return
		view._ellipse(at,Vector2(float(h.radius),float(h.depth))*(.55+.45*progress),Color(.20,.11,.04,.12+.22*progress))
		view.draw_set_transform(at,0,Vector2(1,float(h.depth)/float(h.radius)))
		view.draw_arc(Vector2.ZERO,float(h.radius),0,TAU,40,Color(.84,.56,.2,.3+.5*progress),2,true)
		view.draw_set_transform(Vector2.ZERO)
		return
	var age := float(h.age-h.warning)/30.0
	view._draw_dust(at,float(h.radius)*1.2,age,1-age)
	var debris := simple_frame(ROOT+"props/rockfall.png",Rect2(Vector2(variant*cell.x,cell.y),cell),Vector2(cell.x*.5,cell.y*.85),cell.y*.8,80)
	view._draw_art_frame(debris,at+Vector2(0,12),80+age*32,1,0,Color(1,1,1,1-age),float(debris.body_height))

func draw_attack_warning(view, effect: Dictionary) -> void:
	var center := Vector2(float(effect.x)-view.camera_x,float(effect.y))
	var radius := float(effect.radius)
	var depth := float(effect.get("depth",55))
	var pulse := .7+.3*sin(float(view.state.tick)*.22)
	view._ellipse(center,Vector2(radius,depth),Color(.72,.25,.08,.08+.04*pulse))
	view.draw_set_transform(center,0,Vector2(1,depth/maxf(1,radius)))
	view.draw_arc(Vector2.ZERO,radius,0,TAU,48,Color(.96,.64,.29,.35+.2*pulse),1.5,true)
	view.draw_set_transform(Vector2.ZERO)

func draw_hazards(view) -> void:
	for h in view.state.get("expedition",{}).get("hazards",[]):
		if h.kind=="rock":
			draw_rockfall(view,h)
			continue
		var at := Vector2(float(h.x)-view.camera_x,float(h.y))
		var progress := clampf(float(h.age)/float(h.warning),0,1)
		if h.age<h.warning:
			if h.kind=="fireline":
				view.draw_line(at-Vector2(float(h.radius),0),at+Vector2(float(h.radius),0),Color(.92,.64,.27,.12+.2*progress),1.2,true)
			else:
				view._ellipse(at,Vector2(float(h.radius),float(h.depth))*(.65+.35*progress),Color(.28,.14,.04,.14+.2*progress))
			continue
		var age := float(h.age-h.warning)/30.0
		if h.kind=="arrows":
			view._draw_dust(at,18,age,.65*(1-age))
		elif h.kind=="powder":
			view._ellipse(at,Vector2(float(h.radius),float(h.depth))*(1+.3*age),Color(.15,.09,.05,.4*(1-age)))
		elif h.kind=="quake":
			var cracks := PackedVector2Array()
			for i in 9: cracks.append(at+Vector2((i-4)*float(h.radius)/4,sin(i*7.3)*12))
			view.draw_polyline(cracks,Color(.15,.08,.025,1-age),3,true)
			view._draw_dust(at,float(h.radius),age,.85*(1-age))

func draw_hazard_air(view, h: Dictionary) -> void:
	if h.kind=="rock":
		if h.age<h.warning: draw_rockfall(view,h,true)
		return
	var at := Vector2(float(h.x)-view.camera_x,float(h.y))
	var progress := clampf(float(h.age)/float(h.warning),0,1)
	var age := float(h.age-h.warning)
	if h.kind=="arrows":
		if age<0: view._draw_arrow(at-Vector2(0,(1-progress)*440),Vector2.DOWN,false)
		else: view.draw_line(at-Vector2(3,26),at,Color(.9,.84,.65,1-age/30),2,true)
	elif h.kind=="powder":
		if age<0:
			var start := Vector2(float(h.from_x)-view.camera_x,float(h.from_y)-95)
			var position := start.lerp(at,progress)-Vector2(0,sin(progress*PI)*130)
			var image := texture(ROOT+"props/powder-bomb.png")
			var frame := simple_frame(ROOT+"props/powder-bomb.png",Rect2(Vector2.ZERO,image.get_size()),image.get_size()*.5,image.get_height()*.7,38)
			view._draw_art_frame(frame,position,38,1,progress*4,Color.WHITE,float(frame.body_height))
		else:
			for i in 3:
				var point := at+Vector2((i-1)*55,-25-18*(i%2))
				view._fx.shared_player.draw_phase(view,"fire_burn",age,30,point,true,{"opacity":[[0,1],[.6,.8],[1,0]]},{"size":135,"stretch":Vector2(.9,1.1)})
			view._fx.shared_player.draw_phase(view,"fire_ring",age,30,at-Vector2(0,6),true,{"opacity":[[0,1],[.4,.85],[1,0]]},{"size":float(h.radius)*2.5,"stretch":Vector2(1,.4)})
			view._draw_dust(at,float(h.radius)*1.2,age/30,1-age/30)
	elif h.kind=="fireline":
		var face := 1 if float(h.x)>float(h.from_x) else -1
		var muzzle := Vector2(float(h.from_x)-view.camera_x+face*95,float(h.from_y)-100)
		var end := Vector2(at.x+face*float(h.radius),at.y-80)
		if age<0:
			view.draw_circle(muzzle,2+progress*3,Color(1,.6,.18,.5+.3*progress))
		else:
			view._fx.shared_player.draw_phase(view,"matchlock_muzzle_flash",age,10,muzzle,true,{"opacity":[[0,1],[.4,.9],[1,0]]},{"size":155,"face":face})
			view._fx.shared_player.draw_phase(view,"matchlock_smoke",age,30,muzzle,true,{"opacity":[[0,.5],[.4,.85],[1,0]]},{"size":180,"face":face})
			if age<7:
				view.draw_line(muzzle,end,Color(1,.76,.35,(1-age/7)*.95),2,true)
				for i in 5:
					var tip := muzzle.lerp(end,fposmod(i*.211+age*.12,1))
					view.draw_line(tip-Vector2(face*22,0),tip,Color(1,.95,.72,1-age/7),3,true)

func actor_fx(view, fighter: Dictionary, origin: Vector2) -> void:
	if not Data.ACTIONS.has(str(fighter.action)): return
	var spec: Dictionary=Data.ACTIONS[str(fighter.action)]
	var tick := int(fighter.action_tick)
	for hit in spec.hits:
		var age := tick-int(hit)
		if age<0 or age>9: continue
		if Data.ranged(spec): continue
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
