extends RefCounted

const Data = preload("res://core/stage05_data.gd")
# Bound decoded texture memory; files retain their original PNG bytes.
const CACHE_BYTES := 192*1024*1024
var textures: Dictionary = {}
var recent: Array = []
var cached_bytes := 0

func texture(path: String, crop: Array = []) -> Texture2D:
	var key := path+str(crop)
	if textures.has(key):
		recent.erase(key); recent.append(key)
		return textures[key].texture
	var source := Image.load_from_file(Data.ROOT+path)
	assert(source != null,"Missing stage-five art: "+path)
	if not crop.is_empty(): source = source.get_region(Rect2i(int(crop[0]),int(crop[1]),int(crop[2]),int(crop[3])))
	source.generate_mipmaps()
	var size := source.get_data_size()
	while not recent.is_empty() and cached_bytes+size > CACHE_BYTES:
		var old: String = recent.pop_front()
		cached_bytes -= int(textures[old].bytes)
		textures.erase(old)
	var tex := ImageTexture.create_from_image(source)
	textures[key] = {"texture":tex,"bytes":size}; recent.append(key); cached_bytes += size
	return tex

func frame(row: Dictionary) -> Dictionary:
	var crop: Array = row.get("crop",[])
	var tex := texture(str(row.path),crop)
	var offset := Vector2(crop[0],crop[1]) if not crop.is_empty() else Vector2.ZERO
	return {"texture":tex,"region":Rect2(Vector2.ZERO,tex.get_size()),"anchor":Vector2(row.anchor[0],row.anchor[1])-offset,"body_height":float(row.body_height),"opaque_bounds":Rect2(Vector2.ZERO,tex.get_size())}

func sample(world: Dictionary, fighter: Dictionary, walk_tick: float, clock_tick: float) -> Dictionary:
	var role: String = fighter.s05_role
	var clips: Dictionary = Data.actors()[role]
	var action: String = fighter.action
	var clip := action if clips.has(action) else "idle"
	var ms := float(fighter.action_tick)*1000.0/60.0*Data.speed(fighter)
	if action == "recovering": clip = "recover"
	elif action in ["frozen","pulled"]: clip = "stunned"
	elif action == "grabbed" and not clips.has(action): clip = "hurt"
	elif action in ["dead","defeated"] or fighter.hp <= 0: clip = "down"
	elif action in ["launched","thrown"] and not clips.has(action): clip = "down"; ms = Data.duration(role,clip)-1
	elif action == "retreat": clip = "retreat_run" if clips.has("retreat_run") else "run"
	elif action == "idle" and fighter.get("moving",false): clip = str(fighter.get("s05_move_clip","walk"))
	if clip == "idle": ms = clock_tick*1000.0/60.0
	elif clip in ["walk","run","retreat_run"]: ms = walk_tick*1000.0/60.0*Data.speed(fighter)
	var spec: Dictionary = clips[clip]
	var index := Data.frame_index(spec,ms)
	var row: Dictionary = spec.frames[index]
	var drawing := frame(row)
	var behind := []
	for layer in row.get("layers_before",[]): behind.append(frame(layer))
	if not behind.is_empty(): drawing.behind = {"layers":behind}
	drawing.overlays = []
	for layer in row.get("layers_after",[]): drawing.overlays.append(frame(layer))
	# Both of these approved running cycles face left in the source files.
	var native_face := int(spec.get("native_face",-1 if role == "kusei" and clip == "retreat_run" else 1))
	return {"source":"stage5","sheet":"stage5","clip":clip,"cell":index,"frame":index,"count":spec.frames.size(),"tick":fighter.action_tick,"duration":spec.duration_ms,"released":not Data.HITS.has(action) or Data.HITS[action].is_empty() or ms >= Data.HITS[action][0],"genuine_reaction":true,"native_face":native_face,"frame_data":drawing}

func draw_landscape(view) -> void:
	var tex := texture("backgrounds/"+Data.BACKGROUNDS[int(view.state.stage.index)]+".png")
	var horizon := 512.0 # Below architecture/tree roots: only floor may tile independently.
	var scale := 364.0/horizon
	var width := tex.get_width()*scale
	var pan := clampf(view.camera_x*.06,0,maxf(0,width-1280))
	view.draw_texture_rect_region(tex,Rect2(-pan,0,width,364),Rect2(0,0,tex.get_width(),horizon))
	view.draw_texture_rect_region(tex,Rect2(0,364,1280,356),Rect2(0,horizon,tex.get_width(),tex.get_height()-horizon))
	view._draw_near_ground({"texture":tex,"region":Rect2(Vector2.ZERO,tex.get_size())},Rect2(0,horizon,tex.get_width(),tex.get_height()-horizon))

func effect(view, e: Dictionary) -> void:
	var point := Vector2(float(e.x)-view.camera_x,float(e.y)-float(e.z))
	if e.type == "s05_fx":
		var age := float(int(e.max_life)-int(e.life))*1000/60
		var index := mini(25,floori(age/5))
		var rapid: bool=e.s05_asset=="rapid"
		var path := "hachiya/hachiya_actions/fx_v3/frames/%02d.png"%index if rapid else "hachiya/hachiya_actions/secondary_fx_v2/return_%02d.png"%index
		var drawing := frame({"path":path,"anchor":[16,192 if rapid else 325],"body_height":1015})
		view._draw_art_frame(drawing,point,Data.height("hachiya"),e.face,deg_to_rad(float(e.angle))*int(e.face),Color.WHITE,1015)
		return
	var kind: String=e.s05_asset
	var path := "natsume/skills/sources/8f3c72ed36c58bb2.png" if kind=="sweep" else "natsume/fx_patch_v3/natsume-%s-fx-native-crop.png"%("diag" if kind=="diagonal" else "down")
	var tex := texture(path)
	var drawing := frame({"path":path,"anchor":[tex.get_width()*.85,tex.get_height()*.75],"body_height":691.2})
	var alpha := minf(1.0,float(e.life)/5.0)
	view._draw_art_frame(drawing,point,Data.height("natsume")*1.25,e.face,0,Color(1,1,1,alpha),691.2)

func actor_fx(view, f: Dictionary, point: Vector2) -> void:
	if f.action != "s05_hachiya_sweep": return
	var ms := float(f.action_tick)*1000/60
	if ms<420 or ms>=680: return
	var row := Data.row("hachiya",f.action,ms)
	var grip: Array=row.grips.rear
	var scale := Data.height("hachiya")/1015
	var at := point+Vector2((float(grip[0])-820)*f.face,float(grip[1])-1400)*scale
	var index := mini(26,floori((ms-420)/10))
	var drawing := frame({"path":"hachiya/hachiya_actions/secondary_fx_v2/sweep_%02d.png"%index,"anchor":[944.8,944.8],"body_height":1015})
	view._draw_art_frame(drawing,at,Data.height("hachiya"),f.face,deg_to_rad(float(row.weapon_angle_degrees))*int(f.face),Color.WHITE,1015)

func prop(prop: Dictionary, tick: int) -> Dictionary:
	var asset: String = prop.s05_asset
	var meta: Dictionary = Data.read("props/manifest.json")
	var flag := asset.begins_with("militia_") or asset.begins_with("temple_")
	var spec: Dictionary = {}
	for row in meta.flags if flag else meta.destructibles:
		if row.id == asset: spec = row; break
	var folder := "props/flags/" if flag else "props/destructibles/"
	folder += asset+"/"
	var path := folder+("broken.png" if prop.broken else ("damaged.png" if prop.hp < prop.max_hp else "intact.png"))
	if prop.broken and spec.has("destroy"):
		var age := maxf(0,float(tick-int(prop.get("broken_tick",tick))))*1000/60
		var index := mini(int(age/float(spec.destroy.frame_ms[0])),int(spec.destroy.frames)-1)
		if FileAccess.file_exists(Data.ROOT+folder+"destroy/%02d.png"%index): path=folder+"destroy/%02d.png"%index
	elif flag and spec.has("idle") and prop.hp == prop.max_hp:
		var index := posmod(int(tick*1000.0/60/120)+int(prop.id),8)
		if FileAccess.file_exists(Data.ROOT+folder+"idle/%02d.png"%index): path=folder+"idle/%02d.png"%index
	var drawing := frame({"path":path,"anchor":spec.root_px,"body_height":float(spec.canvas_px[1])})
	drawing.display_height = float(spec.canvas_px[1])*float(spec.draw_scale)
	return drawing
