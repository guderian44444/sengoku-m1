extends RefCounted

const ROOT := "res://assets/officer-fx-power-v4/"
var moves := {}
var textures := {}

func _init() -> void:
	for move in JSON.parse_string(FileAccess.get_file_as_string(ROOT+"all_moves_manifest.json")):
		moves[str(move.id)] = move

static func move_id(fighter: Dictionary, sample: Dictionary) -> String:
	var source: String = sample.get("source","")
	if source == "stage4": return "stage4-"+str(sample.clip)
	if source == "stage3": return "stage3-"+str(sample.actor)+"-"+str(sample.clip)
	if source == "v31": return "v31-"+str(fighter.get("boss_variant",""))+"-"+str(fighter.action)
	if source == "v19":
		var role := "matsui" if str(sample.sheet).contains(":matsui:") else str(fighter.kind)
		return "v19-"+role+"-"+str(fighter.action)
	return ""

func attachment(fighter: Dictionary, sample: Dictionary, height: float, face: float, rotation: float) -> Dictionary:
	var id := move_id(fighter,sample)
	if not moves.has(id): return {}
	var move: Dictionary = moves[id]
	if not move.new_fx_enabled: return {}
	var index := int(sample.cell)
	if sample.source == "v31": index = 0 if index == 0 else 1
	if index < 0 or index >= move.frames.size(): return {}
	var row: Dictionary = move.fx_by_pose[index]
	if not row.visible: return {}
	# Use the displayed sample's tick, including hit-stop, rather than a separate FX clock.
	var tick := float(sample.get("tick",fighter.action_tick))
	var alpha := 0.0
	for event in move.events:
		if tick >= float(event.start_tick) and tick < float(event.end_tick):
			alpha = maxf(alpha,minf(1,(tick-float(event.start_tick)+1)/4)*minf(1,(float(event.end_tick)-tick)/10)*.94)
	if alpha <= 0: return {}
	var root: Array = move.frames[index].root_px
	var offset := (Vector2(row.anchor_px[0],row.anchor_px[1])-Vector2(root[0],root[1]))*height/float(row.body_height_source_px)
	offset = (offset*Vector2(face,1)).rotated(rotation)
	return {"path":id+"/"+str(row.path),"offset":offset,"rotation":rotation+deg_to_rad(float(row.fx_axis_angle_deg))*face,"face":face,"alpha":alpha,"anchor":Vector2(row.origin_fx_px[0],row.origin_fx_px[1]),"ruler":float(row.body_height_source_px),"behind":move.draw_layer=="behind original character","pose":index}

func draw(view, fighter: Dictionary, sample: Dictionary, origin: Vector2, height: float, face: float, rotation: float, behind: bool) -> void:
	var a := attachment(fighter,sample,height,face,rotation)
	if a.is_empty() or a.behind != behind: return
	if not textures.has(a.path):
		var image := Image.load_from_file(ROOT+str(a.path))
		assert(image != null,"Missing weapon-tip FX: "+str(a.path))
		image.generate_mipmaps()
		textures[a.path] = ImageTexture.create_from_image(image)
	var texture: Texture2D = textures[a.path]
	var frame := {"texture":texture,"region":Rect2(Vector2.ZERO,texture.get_size()),"anchor":a.anchor}
	view._draw_art_frame(frame,origin+a.offset,height,a.face,a.rotation,Color(1,1,1,a.alpha),a.ruler)
