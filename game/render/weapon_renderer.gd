extends RefCounted

const Weapons = preload("res://core/weapon_catalog.gd")
const Typography = preload("res://render/game_typography.gd")
const DIRECTORY := "res://assets/v22/weapons/"
const LENGTHS := {"sword":115.0,"spear":335.0,"bow":175.0}
var items: Dictionary = {}
var textures: Dictionary = {}

func _init() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "registration.json"))
	if not manifest is Dictionary: return
	items = manifest.get("items",{})
	for id in items:
		var image := Image.load_from_file(DIRECTORY + str(items[id].file))
		if image != null: textures[id] = ImageTexture.create_from_image(image)

static func equipped_id(fighter: Dictionary) -> String:
	var hero := str(fighter.get("kind","nobunaga"))
	var id := str(fighter.get("weapon_id",Weapons.default_for(hero)))
	return id if id == "" or Weapons.compatible(hero,id) else Weapons.default_for(hero)

func geometry(fighter: Dictionary, frame: Dictionary, height: float) -> Dictionary:
	var pose := Weapons.pose(fighter,frame,height)
	if not pose.is_empty() and float(frame.get("weapon_longitudinal_scale",1)) != 1:
		pose.basis = Transform2D(float(pose.angle),Vector2(float(pose.scale),float(pose.scale)*float(frame.weapon_longitudinal_scale)),0,Vector2.ZERO)
	if not pose.is_empty() and frame.get("combat_v33",false) and frame.get("weapon_matrix",[]).size() == 2:
		var matrix: Array = frame.weapon_matrix
		var factor := float(pose.scale)/.28
		var basis := Transform2D(Vector2(matrix[0][0],matrix[1][0])*factor,Vector2(matrix[0][1],matrix[1][1])*factor,Vector2.ZERO)
		pose.basis = basis
		var spec: Dictionary = items[pose.id]
		pose.top = pose.hand+basis*(Vector2(spec.tip_top[0],spec.tip_top[1])-Vector2(pose.grip))
		pose.bottom = pose.hand+basis*(Vector2(spec.tip_bottom[0],spec.tip_bottom[1])-Vector2(pose.grip))
	return pose

static func uses_authored_weapon(fighter: Dictionary, frame: Dictionary) -> bool:
	return frame.get("authored_weapon",false) and (frame.get("fixed_weapon",false) or equipped_id(fighter).begins_with("practice_"))

static func pose_transform(pose: Dictionary, origin: Vector2, face: float, rotation: float) -> Transform2D:
	var hand: Vector2 = pose.hand
	if pose.has("basis"):
		var basis: Transform2D = pose.basis
		return Transform2D((basis.x*Vector2(face,1)).rotated(rotation),(basis.y*Vector2(face,1)).rotated(rotation),origin+(hand*Vector2(face,1)).rotated(rotation))
	return Transform2D(rotation + float(pose.angle) * face,Vector2(face*float(pose.get("blade_side",1)),1) * float(pose.scale),0.0,origin + (hand * Vector2(face,1)).rotated(rotation))

func sweep_trail(fighter: Dictionary, current: Dictionary, previous: Dictionary, height: float) -> PackedVector2Array:
	var now := geometry(fighter,current,height)
	var before := geometry(fighter,previous,height)
	if now.is_empty() or before.is_empty() or now.family != "sword": return PackedVector2Array()
	var from: Vector2 = before.top - before.hand
	var to: Vector2 = now.top - now.hand
	var points := PackedVector2Array()
	for edge in [1.0,.84]:
		for index in range(13):
			var progress := float(index if edge == 1.0 else 12 - index) / 12.0
			var hand: Vector2 = before.hand.lerp(now.hand,progress)
			var radius: float = lerpf(from.length(),to.length(),progress) * float(edge)
			points.append(hand + Vector2.from_angle(lerp_angle(from.angle(),to.angle(),progress)) * radius)
	return points

func draw_weapon(canvas: CanvasItem, fighter: Dictionary, frame: Dictionary, origin: Vector2, height: float, face: float, rotation: float, tint: Color, behind: bool) -> void:
	var layers: Dictionary = frame.get("combat_layers",{})
	var accessory := "accessory_back" if behind else "accessory_front"
	if layers.has(accessory): _draw_combat_layer(canvas,layers[accessory],origin,height,face,rotation,tint)
	if behind and uses_authored_weapon(fighter,frame) and layers.has("weapon_back") and equipped_id(fighter) != "": _draw_combat_layer(canvas,layers.weapon_back,origin,height,face,rotation,tint)
	if bool(frame.get("weapon_behind",false)) != behind: return
	if uses_authored_weapon(fighter,frame):
		if layers.has("weapon") and frame.get("weapon_visible",true) and equipped_id(fighter) != "": _draw_combat_layer(canvas,layers.weapon,origin,height,face,rotation,tint)
		return
	var pose := geometry(fighter,frame,height)
	if pose.is_empty(): return
	var texture: Texture2D = textures[pose.id]
	canvas.draw_set_transform_matrix(pose_transform(pose,origin,face,rotation))
	if frame.get("combat_v33",false) and frame.get("weapon_mode","") == "sheathed": _draw_scabbard(canvas,pose,tint)
	var region := weapon_region(pose,frame,texture.get_size())
	if region.has_area(): canvas.draw_texture_rect_region(texture,Rect2(region.position-Vector2(pose.grip),region.size),region,tint)
	if pose.family == "bow":
		canvas.draw_set_transform(origin,rotation,Vector2(face,1))
		var color := Color(.9,.87,.74,tint.a * .86)
		if frame.has("second_hand") and not behind:
			var draw_hand: Vector2 = frame.second_hand * float(pose.body_scale)
			canvas.draw_line(pose.top,draw_hand,color,1.1,true)
			canvas.draw_line(draw_hand,pose.bottom,color,1.1,true)
		else:
			canvas.draw_line(pose.top,pose.bottom,color,.9,true)
		if frame.get("nocked",false):
			var tail: Vector2 = frame.second_hand*float(pose.body_scale) if frame.has("second_hand") else Vector2(pose.hand)-Vector2(height*.3,0)
			var direction := (Vector2(pose.hand)-tail).normalized()
			var tip := Vector2(pose.hand)+direction*height*.12
			canvas.draw_line(tail,tip,Color(.82,.73,.55,tint.a),1.4,true)
			canvas.draw_line(tip-direction*4+direction.orthogonal()*2,tip,Color(.85,.89,.87,tint.a),2,true)
	canvas.draw_set_transform(Vector2.ZERO)

static func weapon_region(pose: Dictionary, frame: Dictionary, size: Vector2) -> Rect2:
	var top := 0.0
	var mode := str(frame.get("weapon_mode","drawn"))
	if mode == "sheathed": top = float(pose.guard.y)-5
	elif mode in ["sheathed_transition","drawing","resheathing"] and frame.has("scabbard_mouth"):
		top = ((frame.scabbard_mouth*float(pose.body_scale)-Vector2(pose.hand)).rotated(-float(pose.angle))/float(pose.scale)).y + float(pose.grip.y)
	return Rect2(Vector2(0,clampf(top,0,size.y)),Vector2(size.x,maxf(0,size.y-maxf(0,top))))

func draw_shadow(canvas: CanvasItem, fighter: Dictionary, frame: Dictionary, _origin: Vector2, height: float, face: float, rotation: float, projection: Transform2D, tint: Color) -> void:
	if uses_authored_weapon(fighter,frame):
		if frame.combat_layers.has("weapon") and frame.get("weapon_visible",true) and equipped_id(fighter) != "":
			var layer: Dictionary = frame.combat_layers.weapon
			var factor := height/float(layer.body_height)
			canvas.draw_set_transform_matrix(projection*Transform2D(rotation,Vector2(face,1),0,Vector2.ZERO))
			canvas.draw_texture_rect_region(layer.texture,Rect2(-Vector2(layer.anchor)*factor,layer.region.size*factor),layer.region,Color(0,0,0,tint.a))
			canvas.draw_set_transform(Vector2.ZERO)
		return
	var pose := geometry(fighter,frame,height)
	if pose.is_empty(): return
	var shadow := Color(0,0,0,tint.a)
	canvas.draw_set_transform_matrix(projection * pose_transform(pose,Vector2.ZERO,face,rotation))
	if frame.get("combat_v33",false) and frame.get("weapon_mode","") == "sheathed": _draw_scabbard(canvas,pose,shadow)
	var region := weapon_region(pose,frame,textures[pose.id].get_size())
	if region.has_area(): canvas.draw_texture_rect_region(textures[pose.id],Rect2(region.position-Vector2(pose.grip),region.size),region,shadow)
	if pose.family == "bow":
		canvas.draw_set_transform_matrix(projection * Transform2D(rotation,Vector2(face,1),0.0,Vector2.ZERO))
		if frame.has("second_hand") and not bool(frame.get("weapon_behind",false)):
			var hand: Vector2 = frame.second_hand * float(pose.body_scale)
			canvas.draw_line(pose.top,hand,shadow,1.1,true)
			canvas.draw_line(hand,pose.bottom,shadow,1.1,true)
		else:
			canvas.draw_line(pose.top,pose.bottom,shadow,0.9,true)
	canvas.draw_set_transform(Vector2.ZERO)

func _draw_scabbard(canvas: CanvasItem, pose: Dictionary, tint: Color) -> void:
	var tip: Array = items[pose.id].tip_top
	var from := Vector2(pose.guard)-Vector2(pose.grip)
	var to := Vector2(tip[0],tip[1])-Vector2(pose.grip)
	var width := float(items[pose.id].length)*.037
	canvas.draw_line(from,to,Color(.38,.30,.17,tint.a),width+8,true)
	canvas.draw_line(from,to,Color(.055,.06,.065,tint.a),width,true)

func draw_hand_occlusion(canvas: CanvasItem, frame: Dictionary, origin: Vector2, height: float, face: float, rotation: float, tint: Color) -> void:
	if frame.get("combat_v33",false):
		if frame.combat_layers.has("hands"): _draw_combat_layer(canvas,frame.combat_layers.hands,origin,height,face,rotation,tint)
		return
	if frame.has("hand_foreground"):
		var factor := height / float(frame.body_height)
		canvas.draw_set_transform(origin,rotation,Vector2(face,1))
		canvas.draw_texture_rect_region(frame.hand_foreground,Rect2(-Vector2(frame.anchor)*factor,frame.region.size*factor),frame.region,tint)
		canvas.draw_set_transform(Vector2.ZERO)
		return
	if not frame.get("layered_weapon",false) or not frame.get("weapon_visible",true): return
	var regions: Array = frame.get("hand_occluders",[])
	if regions.is_empty() and frame.has("hand_occluder"): regions = [frame.hand_occluder]
	if regions.is_empty(): return
	var scale := height / maxf(1,float(frame.body_height))
	var region: Rect2 = frame.region
	var anchor: Vector2 = frame.anchor
	canvas.draw_set_transform(origin,rotation,Vector2(face,1))
	for hand_rect: Rect2 in regions:
		var clipped := hand_rect.intersection(Rect2(Vector2.ZERO,region.size))
		if not clipped.has_area(): continue
		canvas.draw_texture_rect_region(frame.texture,Rect2((clipped.position - anchor) * scale,clipped.size * scale),Rect2(region.position + clipped.position,clipped.size),tint)
	canvas.draw_set_transform(Vector2.ZERO)

func _draw_combat_layer(canvas: CanvasItem, layer: Dictionary, origin: Vector2, height: float, face: float, rotation: float, tint: Color) -> void:
	var factor := height/float(layer.body_height)
	canvas.draw_set_transform(origin,rotation,Vector2(face,1))
	canvas.draw_texture_rect_region(layer.texture,Rect2(-Vector2(layer.anchor)*factor,layer.region.size*factor),layer.region,tint)
	canvas.draw_set_transform(Vector2.ZERO)

func draw_drop(canvas: CanvasItem, drop: Dictionary, position: Vector2, clock: float) -> bool:
	var id := Weapons.art_id(str(drop.get("weapon_id","")))
	if not textures.has(id): return false
	var texture: Texture2D = textures[id]
	var spec: Dictionary = items[id]
	var scale := 92.0 / float(spec.length)
	var hover := sin(clock * 3.0 + float(drop.get("x",0))) * 3.0
	canvas.draw_set_transform(position,0,Vector2(1,.25))
	canvas.draw_circle(Vector2.ZERO,38,Color(.05,.07,.04,.4))
	canvas.draw_set_transform(position - Vector2(0,45 + hover),PI / 3,Vector2.ONE * scale)
	var middle := (Vector2(spec.tip_top[0],spec.tip_top[1]) + Vector2(spec.tip_bottom[0],spec.tip_bottom[1])) * .5
	canvas.draw_texture(texture,-middle)
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_arc(position - Vector2(0,18),40,0,TAU,32,Color(1,.82,.36,.56),1.5,true)
	Typography.draw_label(canvas,position + Vector2(-95,17),str(Weapons.item(id).name),14,Typography.GOLD,190,HORIZONTAL_ALIGNMENT_CENTER)
	return true
