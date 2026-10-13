class_name SharedVFX
extends RefCounted
## Visual-only deterministic atlas sampler. Never changes battle damage or state.
var catalog: Dictionary = {}
var textures: Dictionary = {}
var diagnostics: Array[String] = []

func load_catalog(path: String = "res://vfx/catalog.json") -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		diagnostics.append("Invalid VFX catalog")
		return false
	catalog = parsed.get("effects", {})
	for id in catalog:
		var spec: Dictionary = catalog[id]
		var image := Image.load_from_file(str(spec.texture))
		if image == null:
			diagnostics.append("Missing texture: " + id)
			continue
		textures[id] = ImageTexture.create_from_image(image)
	return diagnostics.is_empty()

static func sample(spec: Dictionary, tick: float, start_tick: float = 0.0, speed: float = 1.0) -> Dictionary:
	var age := (tick - start_tick) * maxf(speed, 0.001)
	var duration := float(spec.get("duration_ticks", 24))
	var count := int(spec.get("frames", 4))
	var looping := bool(spec.get("loop", false))
	if age < 0 or (not looping and age >= duration): return {}
	var progress := fposmod(age, duration) / duration if looping else clampf(age / duration, 0, 0.999999)
	var phase := progress * count
	var current := mini(count - 1, floori(phase))
	var following := (current + 1) % count if looping else mini(count - 1, current + 1)
	var fade := 1.0 if looping else minf(1.0, (1.0 - progress) * 5.0)
	return {"frame":current,"next":following,"mix":0.0 if following == current else phase - current,"alpha":fade,"age":age,"progress":progress}

static func anchored(origin: Vector2, local_anchor: Vector2, face: float, body_height: float, reference_height: float = 155.0) -> Vector2:
	return origin + local_anchor * Vector2(-1 if face < 0 else 1, 1) * body_height / maxf(reference_height, 1)

## Call back pass, draw actor + weapon, then front pass, INSIDE each depth-sorted actor.
## Ring frames are horizontally split in image-space at their author-defined seam.
## Ring rotation is prohibited here: rotate ring UV/art internally, never its depth seam.
func draw_pass(canvas: CanvasItem, id: String, tick: float, origin: Vector2, front: bool, options: Dictionary = {}) -> void:
	if not catalog.has(id) or not textures.has(id): return
	var spec: Dictionary = catalog[id]
	var phase := sample(spec, tick, float(options.get("start_tick",0)), float(options.get("speed",1)))
	if phase.is_empty(): return
	var split := bool(spec.get("split_depth",false))
	if not split and front != bool(spec.get("front",true)): return
	var face := -1.0 if float(options.get("face",1)) < 0 else 1.0
	var size := float(options.get("size",spec.get("world_size",240)))
	var angle := 0.0 if split else float(options.get("rotation",0)) * face
	var position: Vector2 = origin + options.get("offset",Vector2.ZERO) * Vector2(face,1)
	var velocity: Vector2 = options.get("velocity",Vector2.ZERO)
	position += velocity * Vector2(face,1) * float(phase.age) / 60.0
	canvas.draw_set_transform(position, angle, Vector2(face,1) * options.get("stretch",Vector2.ONE))
	var first_alpha: float = float(phase.alpha) * (1.0 - float(phase.mix)) * float(options.get("opacity",1))
	var next_alpha: float = float(phase.alpha) * float(phase.mix) * float(options.get("opacity",1))
	_draw_frame(canvas, id, int(phase.frame), size, front, first_alpha, float(phase.age), float(options.get("flow_radians_per_second",spec.get("flow_radians_per_second",.6))))
	if next_alpha > 0.001: _draw_frame(canvas,id,int(phase.next),size,front,next_alpha,float(phase.age),float(options.get("flow_radians_per_second",spec.get("flow_radians_per_second",.6))))
	if front and bool(spec.get("loop",false)): _draw_secondary(canvas,id,size,float(phase.age),float(phase.alpha)*float(options.get("opacity",1)))
	canvas.draw_set_transform(Vector2.ZERO)

func _draw_frame(canvas: CanvasItem, id: String, frame: int, size: float, front: bool, opacity: float, age: float, angular_speed: float) -> void:
	var spec: Dictionary = catalog[id]
	var cell := Vector2(float(spec.cell[0]),float(spec.cell[1]))
	var column := frame % int(spec.get("columns",4))
	var row := frame / int(spec.get("columns",4)) + int(spec.get("row",0))
	var source := Rect2(Vector2(column,row) * cell,cell)
	var pivot := Vector2(float(spec.get("pivot",[0.5,0.5])[0]),float(spec.get("pivot",[0.5,0.5])[1]))
	var dimensions := Vector2(size,size * cell.y / cell.x)
	var destination := Rect2(-pivot * dimensions,dimensions)
	var padding := float(spec.get("render_padding",0.0))
	if padding > 0:
		source.position -= cell * padding
		source.size += cell * padding * 2.0
		destination.position -= dimensions * padding
		destination.size += dimensions * padding * 2.0
	if bool(spec.get("split_depth",false)):
		var seam := (float(spec.get("seam",0.5)) + padding) / (1.0 + padding * 2.0)
		var start := seam if front else 0.0
		var span := 1.0 - seam if front else seam
		source.position.y += source.size.y * start
		source.size.y *= span
		destination.position.y += destination.size.y * start
		destination.size.y *= span
	if spec.get("motion", "") in ["ellipse_flow","turbulence"]:
		_draw_flow_mesh(canvas,id,destination,source,opacity,age,angular_speed)
	else:
		canvas.draw_texture_rect_region(textures[id],destination,source,Color(1,1,1,opacity),false,true)

func _draw_flow_mesh(canvas: CanvasItem, id: String, destination: Rect2, source: Rect2, opacity: float, age: float, angular_speed: float) -> void:
	var spec: Dictionary = catalog[id]
	var texture: Texture2D = textures[id]
	var dimensions := Vector2(texture.get_width(), texture.get_height())
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var center := Vector2(float(spec.get("flow_center",[.5,.526])[0]),float(spec.get("flow_center",[.5,.526])[1]))
	var ellipse := Vector2(float(spec.get("flow_radius",[.46,.18])[0]),float(spec.get("flow_radius",[.46,.18])[1]))
	var angle := age / 60.0 * angular_speed
	# A textured mesh moves flame detail around an ellipse; depth seam stays fixed.
	# This is procedural animation of ONE authored texture, not authored frame animation.
	for y in range(9):
		for x in range(25):
			var fraction := Vector2(x / 24.0,y / 8.0)
			var point := destination.position + fraction * destination.size
			vertices.append(Vector3(point.x,point.y,0))
			var uv := (source.position + fraction * source.size) / dimensions
			if spec.get("motion", "") == "ellipse_flow":
				var circular := (uv-center) / ellipse
				uv = center + circular.rotated(angle) * ellipse
			else:
				var envelope := sin(uv.x * PI) * sin(uv.y * PI)
				var t := age / 60.0
				uv += Vector2(sin(uv.y*26.0-t*6.0),cos(uv.x*21.0-t*4.0)) * .008 * envelope
			uvs.append(uv.clamp(Vector2.ZERO,Vector2.ONE))
	for y in range(8):
		for x in range(24):
			var a := y * 25 + x
			indices.append_array(PackedInt32Array([a,a+1,a+25,a+1,a+26,a+25]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	canvas.draw_mesh(mesh,texture,Transform2D.IDENTITY,Color(1,1,1,opacity))


func _draw_secondary(canvas: CanvasItem, id: String, size: float, age: float, opacity: float) -> void:
	# Optional inexpensive detail. Main artwork is always the authored texture.
	var icy := id.begins_with("ice")
	var tint := Color(.8,.92,1,.65) if icy else Color(1,.62,.16,.65)
	if id.begins_with("blade"): tint = Color(.88,.95,1,.5)
	for i in range(12):
		var phase := fposmod(age / 100.0 + i * .137,1.0)
		var x := sin(i * 2.399 + age * .006) * size * .43
		var y := (phase - .5) * size * .34 if icy else -phase * size * .34
		var point := Vector2(x,y)
		var color := Color(tint,tint.a * sin(phase * PI) * opacity)
		canvas.draw_line(point-Vector2(1,0),point+Vector2(1,0),color,1.0,true)
		if icy: canvas.draw_line(point-Vector2(0,1.5),point+Vector2(0,1.5),color,1.0,true)
