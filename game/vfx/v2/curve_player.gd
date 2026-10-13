extends "res://vfx/vfx_player.gd"
const Curves = preload("res://vfx/v2/phase_curves.gd")
var particle_intensity := 0.0
var current_family := ""

func load_catalog(path: String = "res://vfx/v2/catalog.json") -> bool:
	diagnostics.clear()
	textures.clear()
	catalog.clear()
	var ok := super.load_catalog(path)
	# Phase controller owns visibility/lifetime; base sampler must not terminate early.
	for id in catalog:
		catalog[id]["authored_duration_ticks"] = catalog[id].get("duration_ticks",24)
		catalog[id].loop = true
		catalog[id].duration_ticks = 600
	return ok

func draw_phase(canvas: CanvasItem, id: String, age_ticks: float, duration_ticks: float, origin: Vector2, front: bool, curves: Dictionary, options: Dictionary = {}) -> void:
	if not catalog.has(id): return
	var phase := maxf(0,age_ticks)/maxf(1,duration_ticks)
	var progress := clampf(phase,0,1)
	var settings := options.duplicate()
	var scale_curve := maxf(0,Curves.value(curves.get("scale",[]),progress,1))
	var radius_curve := maxf(0,Curves.value(curves.get("radius",[]),progress,1))
	settings.size = float(settings.get("size",catalog[id].get("world_size",280))) * scale_curve * radius_curve
	settings.opacity = clampf(float(settings.get("opacity",1))*Curves.value(curves.get("opacity",[]),progress,1),0,1)
	particle_intensity = clampf(Curves.value(curves.get("particle_intensity",[]),progress,0),0,2)
	current_family = str(catalog[id].get("family",id.get_slice("_",0)))
	var radians := float(settings.get("uv_offset_radians",0))+Curves.integral(curves.get("uv_radians_per_second",[]),phase,0.6)*duration_ticks/60.0
	var render_age := maxf(age_ticks,.001)
	settings.flow_radians_per_second = radians/(render_age/60.0)
	# Electric flashes are deterministic and bounded, not random per rendered frame.
	if current_family == "lightning":
		var pulse := .82 + .18 * sin(floor(age_ticks/3.0)*2.399)
		settings.opacity *= pulse
	if float(settings.opacity)<=0.001 or float(settings.size)<=0.001: return
	super.draw_pass(canvas,id,render_age,origin,front,settings)

func _draw_secondary(canvas: CanvasItem, id: String, size: float, age: float, opacity: float) -> void:
	var count := mini(24,int(12*particle_intensity))
	if count<=0: return
	var color := Color(.8,.94,1,.55*opacity)
	if current_family in ["fire","matchlock"]: color=Color(1,.6,.12,.65*opacity)
	if current_family=="wind": color=Color(.73,.94,.81,.6*opacity)
	if current_family=="lightning": color=Color(.84,.79,1,.8*opacity)
	for i in range(count):
		var phase := fposmod(age/90.0+i*.137,1.0)
		var angle := i*2.399+age*.025
		var point := Vector2(cos(angle)*size*.42,sin(angle)*size*.13)
		if current_family=="matchlock":
			point=Vector2(phase*size*.62,sin(i*2.399)*size*.07-phase*size*.04)
			canvas.draw_line(point-Vector2(3,0),point+Vector2(3,0),color,1,true)
		elif current_family=="wind":
			var tangent := Vector2(-sin(angle),cos(angle)*.3)*8
			canvas.draw_line(point-tangent,point+tangent,color,1,true)
		elif current_family=="lightning":
			var jitter := sin(floor(age/3.0)+i*4.7)*4.0
			canvas.draw_polyline(PackedVector2Array([point-Vector2(4,7),point+Vector2(jitter,0),point+Vector2(3,-7)]),color,1,true)
		else:
			point.y += (phase-.5)*size*.25 if current_family=="ice" else -phase*size*.22
			canvas.draw_line(point-Vector2(1,0),point+Vector2(1,0),Color(color,color.a*sin(phase*PI)),1,true)
			if current_family=="ice":canvas.draw_line(point-Vector2(0,1.5),point+Vector2(0,1.5),color,1,true)
