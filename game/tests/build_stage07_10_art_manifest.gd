extends SceneTree

const ROOT := "res://assets/stages07-10/"
const ROLES := ["ujie","inaba","nagai","tatsuoki","nagayasu","iwanari","kagetsune","yoshikage"]

static func bounds_of(polygon: PackedVector2Array) -> Rect2:
	var bounds := Rect2(polygon[0],Vector2.ZERO)
	for point in polygon: bounds=bounds.expand(point)
	return bounds

static func area_of(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for i in polygon.size(): area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
	return absf(area)*.5

static func groups(source: Image, row_count: int, path: String) -> Array:
	var mask := BitMap.new()
	mask.create_from_image_alpha(source,.12)
	var rows := []
	for i in row_count: rows.append([])
	for polygon in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,source.get_size()),1.0):
		var bounds := bounds_of(polygon)
		if area_of(polygon)<1000 or bounds.size.y<float(source.get_height())/row_count*.23: continue
		# The last Tatsuoki counter pose's crest touches the boot in the row above.
		# Reject that joined vertical pair; use the complete neutral return below.
		if path=="actors/tatsuoki-motion.png" and bounds.position.x>1500 and bounds.size.y>350: continue
		var row := clampi(floori(bounds.get_center().y/float(source.get_height())*row_count),0,row_count-1)
		# The two prone Inaba poses meet at their sword tips in the source atlas.
		if path=="actors/inaba.png" and row==6 and bounds.size.x>source.get_width()*.45:
			# Follow the diagonal between the touching boots, not an arbitrary column.
			for r in [PackedVector2Array([Vector2(430,1320),Vector2(630,1320),Vector2(630,1463),Vector2(670,1503),Vector2(670,1580),Vector2(430,1580)]),PackedVector2Array([Vector2(630,1320),Vector2(894,1320),Vector2(894,1580),Vector2(670,1580),Vector2(670,1503),Vector2(630,1463)])]:
				for part in Geometry2D.intersect_polygons(polygon,r):
					if area_of(part)>1000: rows[row].append({"polygon":part,"bounds":bounds_of(part)})
			continue
		rows[row].append({"polygon":polygon,"bounds":bounds})
	for row in rows: row.sort_custom(func(a,b):return a.bounds.position.x<b.bounds.position.x)
	return rows

static func frame(source: Image, item: Dictionary, path: String, body: float) -> Dictionary:
	var bounds: Rect2=item.bounds.grow(2).intersection(Rect2(Vector2.ZERO,source.get_size()))
	var points := []
	for point in item.polygon: points.append([point.x-bounds.position.x,point.y-bounds.position.y])
	var mass := 0.0
	var weighted := 0.0
	# Alpha mass follows the body, unlike the midpoint of a long spear's bounding box.
	for y in range(int(item.bounds.position.y),ceili(item.bounds.end.y),2):
		for x in range(int(item.bounds.position.x),ceili(item.bounds.end.x),2):
			if not Geometry2D.is_point_in_polygon(Vector2(x,y),item.polygon): continue
			var alpha := source.get_pixel(x,y).a
			mass+=alpha;weighted+=x*alpha
	var root_x: float = weighted/mass if mass>0 else item.bounds.get_center().x
	return {"path":path,"region":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"anchor":[root_x-bounds.position.x,item.bounds.end.y-bounds.position.y],"body_height":body,"polygon":points}

static func append_group(actor: Dictionary, source: Image, group: Array, path: String, body: float) -> Array:
	var ids := []
	for item in group:
		actor.frames.append(frame(source,item,path,body))
		ids.append(actor.frames.size()-1)
	return ids

static func sheet_height(group: Array, row_height: float) -> float:
	# The opening pose is a standing guard; cap raised weapons above the helmet.
	return minf(float(group[0].bounds.size.y),row_height*.9)

func _init() -> void:
	var result := {"format":"sengoku-expedition-art-v2","actors":{}}
	var impacts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"impact-indices.json"))
	for role in ROLES:
		var path := "actors/%s.png"%role
		if not FileAccess.file_exists(ROOT+path): continue
		var source := Image.load_from_file(ROOT+path)
		var rows := groups(source,8,path)
		var body := sheet_height(rows[0],source.get_height()/8.0)
		var actor := {"path":path,"body_height":body,"frames":[],"clips":{}}
		var names := ["idle","walk","attack_a","attack_b","attack_c","reactions","down","recover"]
		for i in 8: actor.clips[names[i]]=append_group(actor,source,rows[i],path,body)
		actor.clips.hurt=actor.clips.reactions.slice(0,2)
		actor.clips.guard=actor.clips.reactions.slice(2)
		actor.clips.erase("reactions")
		# The last fully upright recovery drawing is taller in these base sheets.
		# Match its anatomical standing height to idle; preserve the rising poses.
		if role in ["nagayasu","yoshikage"]:
			var neutral: Dictionary=actor.frames[actor.clips.idle[0]]
			var recovered: Dictionary=actor.frames[actor.clips.recover[-1]]
			recovered.body_height=body*float(recovered.region[3])/float(neutral.region[3])
		var motion := "actors/%s-motion.png"%role
		if FileAccess.file_exists(ROOT+motion):
			var image := Image.load_from_file(ROOT+motion)
			var motion_rows := groups(image,4,motion)
			var motion_height := sheet_height(motion_rows[0],image.get_height()/4.0)
			for i in 4:
				var clip: String=["walk","attack_a","attack_b","attack_c"][i]
				if role=="tatsuoki" and clip=="attack_c" and motion_rows[i].size()==7:
					var ids := append_group(actor,image,motion_rows[i],motion,motion_height)
					ids.append(actor.clips.walk[-1]) # Complete neutral stance closes the counter.
					actor.clips[clip]=ids
					continue
				if motion_rows[i].size()!=8:
					print("REJECT ",role," motion ",clip," count=",motion_rows[i].size())
					continue
				actor.clips[clip]=append_group(actor,image,motion_rows[i],motion,motion_height)
		for clip in ["walk","attack_a","attack_b","attack_c"]:
			var single := "actors/%s-%s.png"%[role,clip]
			if not FileAccess.file_exists(ROOT+single): continue
			var image := Image.load_from_file(ROOT+single)
			var clip_rows := groups(image,2,single)
			var poses: Array=clip_rows[0]+clip_rows[1]
			assert(poses.size()==8,"Eight isolated authored poses required: "+single+" found "+str(poses.size()))
			actor.clips[clip]=append_group(actor,image,poses,single,sheet_height(clip_rows[0],image.get_height()/2.0))
		var kept := []
		var mapped := {}
		for clip in actor.clips:
			var remapped := []
			for old in actor.clips[clip]:
				if not mapped.has(old): mapped[old]=kept.size();kept.append(actor.frames[old])
				remapped.append(mapped[old])
			actor.clips[clip]=remapped
		actor.frames=kept
		actor.impact_indices=impacts[role]
		result.actors[role]=actor
		print(role," clips=",actor.clips.keys().map(func(k):return k+":"+str(actor.clips[k].size())))
	var file := FileAccess.open(ROOT+"actors.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	var paths := ["actors.json","impact-indices.json","props/signal.png","backgrounds/s07.png","backgrounds/s08.png","backgrounds/s09.png","backgrounds/s10.png","../v18/registration.json","../v18/props.png","../v18/debris.png"]
	for actor in result.actors.values():
		for item in actor.frames:
			if item.path not in paths: paths.append(str(item.path))
	for name in DirAccess.get_files_at(ROOT):
		if name.ends_with(".json") and name.contains("generation"): paths.append(name)
	paths.sort()
	var hashes := {}
	for path in paths:
		assert(FileAccess.file_exists(ROOT+path),"Runtime dependency exists: "+path)
		hashes[path]=FileAccess.get_sha256(ROOT+path)
	var runtime := FileAccess.open(ROOT+"runtime-files.json",FileAccess.WRITE)
	runtime.store_string(JSON.stringify({"runtime_files":hashes},"\t"))
	quit()
