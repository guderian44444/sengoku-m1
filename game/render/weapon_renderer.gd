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
	return Weapons.pose(fighter,frame,height)

static func pose_transform(pose: Dictionary, origin: Vector2, face: float, rotation: float) -> Transform2D:
	var hand: Vector2 = pose.hand
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
	if bool(frame.get("weapon_behind",false)) != behind: return
	var pose := geometry(fighter,frame,height)
	if pose.is_empty(): return
	var texture: Texture2D = textures[pose.id]
	canvas.draw_set_transform_matrix(pose_transform(pose,origin,face,rotation))
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
	canvas.draw_set_transform(Vector2.ZERO)

static func weapon_region(pose: Dictionary, frame: Dictionary, size: Vector2) -> Rect2:
	var top := 0.0
	var mode := str(frame.get("weapon_mode","drawn"))
	if mode == "sheathed": top = float(pose.guard.y)-5
	elif mode in ["sheathed_transition","drawing","resheathing"] and frame.has("scabbard_mouth"):
		top = ((frame.scabbard_mouth*float(pose.body_scale)-Vector2(pose.hand)).rotated(-float(pose.angle))/float(pose.scale)).y + float(pose.grip.y)
	return Rect2(Vector2(0,clampf(top,0,size.y)),Vector2(size.x,maxf(0,size.y-maxf(0,top))))

func draw_shadow(canvas: CanvasItem, fighter: Dictionary, frame: Dictionary, _origin: Vector2, height: float, face: float, rotation: float, projection: Transform2D, tint: Color) -> void:
	var pose := geometry(fighter,frame,height)
	if pose.is_empty(): return
	var shadow := Color(0,0,0,tint.a)
	canvas.draw_set_transform_matrix(projection * pose_transform(pose,Vector2.ZERO,face,rotation))
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

func draw_hand_occlusion(canvas: CanvasItem, frame: Dictionary, origin: Vector2, height: float, face: float, rotation: float, tint: Color) -> void:
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
