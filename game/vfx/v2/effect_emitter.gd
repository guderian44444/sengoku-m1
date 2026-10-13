extends Node
## Unified visual + sound lifecycle. Draw methods NEVER emit sound or hit events.
## All times are authoritative absolute simulation ticks (60Hz), not render delta.
signal audio_cue(instance_id: String, cue_key: String, operation: String, context: Dictionary)
signal audio_update(instance_id: String, intensity: float, phase_progress: float)
signal instance_finished(instance_id: String)
signal pause_changed(paused: bool)
const Player = preload("res://vfx/v2/curve_player.gd")
const Curves = preload("res://vfx/v2/phase_curves.gd")
var player = Player.new()
var recipes: Dictionary = {}
var instances: Dictionary = {}
var retired: Dictionary = {}
var shot_events: Dictionary = {}
var contact_events: Dictionary = {}
var projectile_events: Dictionary = {}
var is_paused := false
var diagnostics: Array[String] = []
var bound_audio: Node = null
var max_instances := 48
var max_late_audio_ticks := 6

func configure(catalog_path: String = "res://vfx/v2/catalog.json", recipes_path: String = "res://vfx/v2/effect_recipes.json") -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(recipes_path))
	if not data is Dictionary: return false
	recipes=data.get("recipes",{})
	var ok:=player.load_catalog(catalog_path)
	for recipe_id in recipes:
		var recipe: Dictionary=recipes[recipe_id]
		for phase: Dictionary in recipe.get("phases",{}).values():
			for layer: Dictionary in phase.get("layers",[]):
				if not player.catalog.has(layer.effect): diagnostics.append("Missing texture for recipe: "+recipe_id);ok=false
			for curve: Array in phase.get("curves",{}).values():
				if not Curves.valid(curve):diagnostics.append("Invalid phase curve: "+recipe_id);ok=false
	return ok

func trigger(id: String, recipe_id: String, context: Dictionary = {}) -> bool:
	if instances.has(id) or retired.has(id) or not recipes.has(recipe_id): return false
	if instances.size()>=max_instances:
		diagnostics.append("Visual budget reached; effect rejected: "+id)
		return false
	var recipe: Dictionary = recipes[recipe_id]
	if recipe.get("requires_confirmed_hit",false) and not context.get("confirmed_hit",false): return false
	if recipe.get("requires_confirmed_shot",false):
		var shot_id:=str(context.get("shot_event_id",""))
		if not context.get("confirmed_shot",false) or shot_id.is_empty() or shot_events.has(shot_id): return false
		shot_events[shot_id]=id
	if recipe.get("requires_confirmed_contact",false):
		var contact:=str(context.get("contact_event_id",""))+"|"+recipe_id
		if not context.get("confirmed_contact",false) or str(context.get("contact_event_id","")).is_empty() or contact_events.has(contact): return false
		contact_events[contact]=id
	if recipe.get("requires_projectile_spawn",false):
		var projectile:=str(context.get("projectile_spawn_id",""))+"|"+recipe_id
		if str(context.get("projectile_spawn_id","")).is_empty() or projectile_events.has(projectile): return false
		projectile_events[projectile]=id
	var tick := int(context.get("simulation_tick",0))
	var phase := str(recipe.get("initial_phase","charge"))
	instances[id]={"recipe_id":recipe_id,"phase":phase,"start_tick":tick,"phase_start":tick,"last_tick":tick,"context":context.duplicate(true),"hits":{},"hit_visuals":[],"audio_events":{},"uv_offset_radians":0.0}
	_emit(id,"activate","start")
	_enter_phase(id,phase)
	return true

func advance(id: String, simulation_tick: int) -> void:
	if is_paused or not instances.has(id): return
	var state: Dictionary=instances[id]
	if simulation_tick<int(state.last_tick):
		diagnostics.append("Out-of-order tick ignored for "+id+"; explicit cancel/rebuild required for rollback")
		return
	var previous_tick:=int(state.last_tick)
	state.last_tick=simulation_tick
	var recipe: Dictionary=recipes[state.recipe_id]
	for _transition in range(8):
		var phase: Dictionary=recipe.phases[state.phase]
		var end:=int(state.phase_start)+int(phase.duration_ticks)
		_emit_crossed_cues(id,phase,previous_tick,mini(simulation_tick,end))
		if phase.get("hold",false) or simulation_tick<end: break
		var next:=str(phase.get("next",""))
		_exit_phase(id,str(state.phase),end)
		if next.is_empty():
			_finish(id,false)
			return
		state.phase=next
		state.phase_start=end
		_enter_phase(id,next)
	var active: Dictionary=recipe.phases[state.phase]
	var progress:=clampf(float(simulation_tick-int(state.phase_start))/maxf(1,float(active.duration_ticks)),0,1)
	var intensity:=clampf(Curves.value(active.get("curves",{}).get("audio_intensity",[]),progress,1),0,1)
	if not state.context.get("silent",false): audio_update.emit(id,intensity,1.0 if recipe.get("family","")=="matchlock" else progress)

func release(id: String, simulation_tick: int) -> bool:
	if is_paused or not instances.has(id): return false
	var state: Dictionary=instances[id]
	if str(state.phase)!="charge" or simulation_tick<int(state.last_tick): return false
	var recipe: Dictionary=recipes[state.recipe_id]
	if not recipe.phases.has("release"): return false
	_exit_phase(id,"charge",simulation_tick)
	state.phase="release"
	state.phase_start=simulation_tick
	state.last_tick=simulation_tick
	_enter_phase(id,"release")
	return true

func confirmed_hit(id: String, event_id: String, simulation_tick: int, hit_context: Dictionary = {}) -> bool:
	if is_paused or not instances.has(id) or event_id.is_empty(): return false
	var state: Dictionary=instances[id]
	if state.hits.has(event_id) or simulation_tick<int(state.last_tick): return false
	if simulation_tick>int(state.last_tick):
		advance(id,simulation_tick)
		if not instances.has(id): return false
	if not str(state.phase) in recipes[state.recipe_id].get("allow_hit_phases",["release","dissipate"]): return false
	state.hits[event_id]=true
	_emit(id,"hit","start")
	state.hit_visuals.append({"tick":simulation_tick,"context":hit_context.duplicate(true)})
	if state.hit_visuals.size()>16: state.hit_visuals.pop_front()
	return true

func cancel(id: String) -> void:
	if instances.has(id): _finish(id,true)
	elif retired.has(id): audio_cue.emit(id,"","stop_all",{})

func cancel_all() -> void:
	var all_ids: Dictionary=retired.duplicate()
	for id: String in instances: all_ids[id]=true
	for id: String in all_ids: cancel(id)

func reset_scene() -> void:
	cancel_all()
	retired.clear()
	shot_events.clear()
	contact_events.clear()
	projectile_events.clear()

func set_paused(paused: bool) -> void:
	if is_paused==paused: return
	is_paused=paused
	pause_changed.emit(paused)

func _emit(id: String, cue_phase: String, operation: String, cue_tick: int = -1) -> void:
	if not instances.has(id): return
	if instances[id].context.get("silent",false): return
	var recipe: Dictionary=recipes[instances[id].recipe_id]
	var cue:=str(recipe.get("audio",{}).get(cue_phase,""))
	var context: Dictionary=instances[id].context.duplicate()
	var variant:=clampi(int(context.get("variant",posmod(id.hash(),4))),0,3)
	cue=cue.replace("{variant}",str(variant))
	var phase: Dictionary=recipe.phases[instances[id].phase]
	var actual_tick:=int(instances[id].last_tick) if cue_tick<0 else cue_tick
	var progress:=clampf(float(actual_tick-int(instances[id].phase_start))/maxf(1,float(phase.duration_ticks)),0,1)
	context["intensity"]=clampf(Curves.value(phase.get("curves",{}).get("audio_intensity",[]),progress,1),0,1)
	context["phase_progress"]=1.0 if recipe.get("family","")=="matchlock" else progress
	context["cue_tick"]=actual_tick
	if not cue.is_empty(): audio_cue.emit(id,cue,operation,context)

func _enter_phase(id: String, phase: String) -> void:
	if phase=="charge": _emit(id,"charge_loop","loop_start")
	elif phase in ["release","dissipate","hit"] and int(instances[id].last_tick)-int(instances[id].phase_start)<=max_late_audio_ticks: _emit(id,phase,"start")

func _exit_phase(id: String, phase: String, exit_tick: int) -> void:
	var state: Dictionary=instances[id]
	var spec: Dictionary=recipes[state.recipe_id].phases[phase]
	var duration:=float(spec.duration_ticks)
	var progress:=maxf(0,float(exit_tick-int(state.phase_start)))/maxf(1,duration)
	state.uv_offset_radians+=Curves.integral(spec.get("curves",{}).get("uv_radians_per_second",[]),progress,.6)*duration/60.0
	if phase=="charge": _emit(id,"charge_loop","loop_stop",exit_tick)

func _finish(id: String, cancelled: bool) -> void:
	# Natural completion leaves short one-shot tails to audio's finite lifetimes;
	# cancellation always stops all active sounds and never starts a new fade cue.
	if cancelled: audio_cue.emit(id,"","stop_all",{})
	else: audio_cue.emit(id,"","finish",{})
	instances.erase(id)
	retired[id]=true
	# Call reset_scene between scenes; caller-generated IDs must remain unique.
	instance_finished.emit(id)

func draw_instance(canvas: CanvasItem, id: String, origin: Vector2, front: bool, draw_context: Dictionary = {}) -> void:
	if not instances.has(id): return
	var state: Dictionary=instances[id]
	var recipe: Dictionary=recipes[state.recipe_id]
	var phase: Dictionary=recipe.phases[state.phase]
	var age:=float(int(state.last_tick)-int(state.phase_start))
	var context: Dictionary=state.context.duplicate()
	context.merge(draw_context,true)
	var family:=str(recipe.family)
	for layer: Dictionary in phase.get("layers",[]):
		var options:=context.duplicate()
		options.erase("start_tick")
		options.erase("speed")
		options.uv_offset_radians=state.uv_offset_radians
		options.size=float(layer.get("size",280))*float(context.get("body_scale",1))*float(context.get("size_multiplier",1))
		options.rotation=float(layer.get("rotation",context.get("rotation",0)))
		var stretch: Array=layer.get("stretch",[1,1])
		options.stretch=Vector2(stretch[0],stretch[1])*context.get("stretch",Vector2.ONE)
		var offset: Array=layer.get("offset",[0,0])
		options.offset=Vector2(offset[0],offset[1])*float(context.get("body_scale",1))
		var velocity: Array=layer.get("velocity",[0,0])
		options.velocity=context.get("velocity",Vector2(velocity[0],velocity[1])*float(context.get("body_scale",1)))
		var curves: Dictionary=phase.get("curves",{}).duplicate(true)
		curves.merge(layer.get("curves",{}),true)
		player.draw_phase(canvas,str(layer.effect),age,float(phase.duration_ticks),origin,front,curves,options)
	# Confirmed impacts only. No visual check ever determines whether an attack hit.
	for hit: Dictionary in state.hit_visuals:
		var hit_age:=float(int(state.last_tick)-int(hit.tick))
		if hit_age<0 or hit_age>=16: continue
		var hit_origin: Vector2=hit.context.get("position",origin)
		var hit_id:=str(recipe.get("hit_effect",family+"_hit"))
		player.draw_phase(canvas,hit_id,hit_age,16,hit_origin,front,{"opacity":[[0,1],[.4,1],[1,0]],"scale":[[0,.55],[.3,1],[1,1.25]]},{"face":context.get("face",1),"size":150})


func _emit_crossed_cues(id: String, phase: Dictionary, previous_tick: int, tick: int) -> void:
	var state: Dictionary=instances[id]
	var cues: Array=phase.get("cues",[])
	for i in range(cues.size()):
		var absolute:=int(state.phase_start)+int(cues[i].tick)
		var key:=str(state.phase_start)+":"+str(i)
		if absolute>previous_tick and absolute<=tick and not state.audio_events.has(key):
			state.audio_events[key]=true
			if int(state.last_tick)-absolute<=max_late_audio_ticks: _emit(id,str(cues[i].phase),"start",absolute)


func bind_audio(controller: Node) -> bool:
	if is_instance_valid(bound_audio) and bound_audio!=controller: return false
	if not controller.has_method("handle_cue") or not controller.has_method("update_instance") or not controller.has_method("set_paused"): return false
	bound_audio=controller
	var cue:=Callable(controller,"handle_cue")
	var update:=Callable(controller,"update_instance")
	var pause:=Callable(controller,"set_paused")
	if not audio_cue.is_connected(cue): audio_cue.connect(cue)
	if not audio_update.is_connected(update): audio_update.connect(update)
	if not pause_changed.is_connected(pause): pause_changed.connect(pause)
	controller.set_paused(is_paused)
	return true
