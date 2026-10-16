extends RefCounted
## Optional VISUAL ONLY special move adapter. Pass authoritative Battle hit ticks.
const Player = preload("res://vfx/vfx_player.gd")
var vfx = Player.new()
var presets: Dictionary = {}
func _init() -> void:
	vfx.load_catalog()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://vfx/special_presets.json"))
	if data is Dictionary: presets = data.get("heroes",{})

func draw_special(canvas: CanvasItem, fighter: Dictionary, ground: Vector2, height: float, front: bool, authoritative_hits: Array) -> void:
	if fighter.get("action","") != "special": return
	var hero := str(fighter.get("kind",""))
	if not presets.has(hero): return
	var preset: Dictionary = presets[hero]
	var tick := float(fighter.get("action_tick",0))
	var origin := ground - Vector2(0,float(fighter.get("z",0)))
	var body_scale := height / 155.0
	for index in range(authoritative_hits.size()):
		var release := float(authoritative_hits[index])
		for layer: Dictionary in preset.layers:
			var start := release + float(layer.get("delay",0))
			var duration := float(layer.get("duration_ticks",36))
			if tick < start or tick >= start + duration: continue
			var offset := Vector2(layer.offset[0],layer.offset[1]) * body_scale
			if layer.get("alternate_side",false) and index % 2 != 0: offset.y -= 35.0 * body_scale
			var velocity: Array = layer.get("velocity",[0,0])
			var stretch: Array = layer.get("stretch",[1,1])
			var opacity := minf(1.0,(start+duration-tick)/6.0)
			vfx.draw_pass(canvas,str(layer.effect),tick,origin,front,{
				"start_tick":start,"face":fighter.get("face",1),"offset":offset,
				"size":float(layer.size)*body_scale,"rotation":float(layer.get("rotation",0)),
				"velocity":Vector2(velocity[0],velocity[1])*body_scale,
				"stretch":Vector2(stretch[0],stretch[1]),"opacity":opacity,
				"flow_radians_per_second":float(layer.get("flow_radians_per_second",.6))})
