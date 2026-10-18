extends Node

const Emitter = preload("res://vfx/v2/effect_emitter.gd")
const EffectAudio = preload("res://vfx/v2/audio/effect_audio_controller.gd")
const Motion = preload("res://vfx/v2/weapon_motion.gd")
const Battle = preload("res://core/battle.gd")
const CombatAudio = preload("res://render/combat_audio.gd")
static var shared_player
static var shared_recipes: Dictionary = {}
static var active_users := 0
var emitter = Emitter.new()
var sound = EffectAudio.new()
var configured := false
var muted := false
var last_tick := -1
var generation := 0
var stage_key := ""
var events: Dictionary = {}
var origins: Dictionary = {}
var charges: Dictionary = {}
var specials: Dictionary = {}
var continuous: Dictionary = {}

func _init() -> void:
	add_child(emitter)
	add_child(sound)

func _ready() -> void:
	if shared_player == null:
		if not emitter.configure(): return
		shared_player = emitter.player
		shared_recipes = emitter.recipes
	else:
		emitter.player = shared_player
		emitter.recipes = shared_recipes
	if not sound.configure("res://vfx/v2/audio"): return
	for cue in CombatAudio.weapon_banks():
		var bank: Dictionary = CombatAudio.weapon_banks()[cue]
		sound.assets[cue] = {"wav":CombatAudio.WEAPONS_V3_ROOT+str(bank.get("runtime_loop",bank.variants[0].file)),"loop":bank.loop}
	for element in ["blade","fire","ice","wind","lightning"]:
		sound.assets[element+"_activate"] = sound.assets.charge_start
		sound.assets[element+"_charge_loop"] = sound.assets.charge_hold_loop
	emitter.bind_audio(sound)
	configured = true
	active_users += 1

func _exit_tree() -> void:
	reset_scene()
	if configured:
		active_users -= 1
		if active_users == 0: shared_player = null; shared_recipes = {}

static func family(fighter: Dictionary) -> String:
	var element := str(Battle.Weapons.item(str(fighter.get("weapon_id",""))).get("element",""))
	if element in ["fire","ice","wind","lightning","blade"]: return element
	return {"nobunaga":"fire","oichi":"ice","hideyoshi":"wind","ieyasu":"neutral","mitsuhide":"blade","tadakatsu":"fire"}.get(fighter.get("kind",""),"neutral")

func reset_scene() -> void:
	emitter.reset_scene()
	sound.stop_all()
	events.clear()
	origins.clear()
	charges.clear()
	specials.clear()
	continuous.clear()
	generation += 1
	last_tick = -1

func set_paused(value: bool) -> void:
	emitter.set_paused(value)

func sync(world: Dictionary, view) -> void:
	if not configured: return
	var tick := int(world.get("tick",0))
	var stage: Dictionary = world.get("stage",{})
	var key := "%s:%s" % [stage.get("id",0),stage.get("index",0)]
	if tick < last_tick or key != stage_key:
		reset_scene()
		stage_key = key
	if tick == last_tick: return
	last_tick = tick
	var live_charges := {}
	var live_specials := {}
	var live_actors := {}
	var live_loops := {}
	for fighter in world.get("fighters",[]):
		var id := int(fighter.id)
		live_actors[id] = true
		if fighter.hp > 0 and not muted:
			var spec: Dictionary = Battle.CombatMoves.spec(fighter)
			if fighter.get("action","") == "charged" and fighter.kind in ["nobunaga","mitsuhide","tadakatsu"] and not spec.get("events",[]).is_empty() and Battle.combat_time_ms(fighter) >= float(spec.events[0].ms):
				live_loops["spin:%d" % id] = "spin_swing_loop"
			for element in ["fire","ice","wind","lightning"]:
				var status := int(fighter.get("burn" if element == "fire" else "freeze",0)) > 0 if element in ["fire","ice"] else false
				if status or (fighter.get("action","") == "special" and family(fighter) == element): live_loops["%s:%d" % [element,id]] = "element_"+element+"_loop"
		if fighter.get("action","") == "charge" and fighter.hp > 0:
			live_charges[id] = true
			if not charges.has(id):
				var cast := "%d:charge:%d:%d" % [generation,id,tick]
				charges[id] = cast
				var element := family(fighter)
				if element == "neutral": element = "blade"
				emitter.trigger(cast,element+"_charged_wave",{"simulation_tick":tick,"audio_only":true,"silent":muted})
		elif fighter.get("action","") in ["charged","charged_upper","charged_slam"] and fighter.hp > 0 and charges.has(id): live_charges[id] = true
		if fighter.get("action","") == "special" and fighter.hp > 0: live_specials[id] = int(fighter.action_tick)
	for id in charges.keys():
		if not live_charges.has(id): emitter.cancel(charges[id]); charges.erase(id)
	for id in continuous.keys():
		if not live_loops.has(id): sound.stop_instance(id); continuous.erase(id)
	for id in live_loops:
		if not continuous.has(id):
			sound.handle_cue(id,live_loops[id],"loop_start",{"phase_progress":1.0,"layered":true})
			continuous[id] = live_loops[id]
	for id in specials.keys():
		if live_specials.has(id): specials[id].tick = live_specials[id]
		else:
			if int(specials[id].tick) >= 209: sound.finish_instance(specials[id].cast)
			else: sound.stop_instance(specials[id].cast)
			specials.erase(id)
	for event in world.get("events",[]): accept_event(event,world,view)
	for id in emitter.instances.keys(): emitter.advance(id,tick)
	for id in origins.keys():
		if emitter.instances.has(id) and not live_actors.has(int(emitter.instances[id].context.get("binding_actor",0))): emitter.cancel(id)
		if not emitter.instances.has(id): origins.erase(id)

func accept_event(event: Dictionary, world: Dictionary, view) -> bool:
	if not configured or not event.has("id"): return false
	var id := "%d:event:%d" % [generation,int(event.id)]
	if events.has(id): return events[id]
	var fighter: Dictionary = {}
	for candidate in world.get("fighters",[]):
		if candidate.id == event.get("actor",0): fighter = candidate; break
	var type := str(event.get("type",""))
	var recipe := ""
	var sampled := CombatAudio.owns_physical_sound(event)
	var context := {"simulation_tick":int(world.get("tick",0)),"silent":muted or sampled,"variant":int(event.id)%4,"face":fighter.get("face",1),"size_multiplier":.55}
	context.binding_actor = int(event.get("actor",0))
	var position := Vector2(float(event.get("x",0)),float(event.get("y",0)))
	if type in ["weapon_swing","bow_release"] and charges.has(int(fighter.get("id",0))):
		var cast: String = charges[int(fighter.id)]
		if sampled:
			sound.stop_instance(cast)
			if emitter.instances.has(cast): emitter.instances[cast].context.silent = true
		emitter.release(cast,int(world.get("tick",0)))
		charges.erase(int(fighter.id))
		events[id] = not sampled
		return not sampled
	if type == "gunshot":
		recipe = "hero_matchlock" if fighter.get("team",1) == 0 else "enemy_matchlock"
		context.merge({"confirmed_shot":true,"shot_event_id":id,"size_multiplier":.65})
		var fresh := false
		for projectile in world.get("effects",[]):
			var age := int(projectile.get("max_life",0))-int(projectile.get("life",0))
			if projectile.get("type","") == "projectile" and projectile.get("weapon","") == "bullet" and projectile.get("owner",0) == fighter.get("id",-1) and age <= 1:
				position = Vector2(projectile.x,projectile.y)-Vector2(projectile.vx,projectile.vy)*age-Vector2(0,float(projectile.get("z",28))+(42 if int(projectile.get("team",0)) == 1 else 96))+view._projectile_release_offset(projectile)
				context.face = projectile.face
				fresh = true
				break
		if not fresh and not fighter.is_empty():
			# A point-blank bullet can already be gone; the confirmed release still owns its muzzle flash.
			var release := {"owner":fighter.id,"team":fighter.team,"weapon":"bullet","face":context.face,"action":event.get("action",fighter.action),"action_tick":event.get("action_tick",fighter.action_tick),"combo":fighter.combo,"heavy_combo":fighter.heavy_combo,"z":fighter.z+28,"life":1,"max_life":1}
			position += Vector2(float(context.face)*(40 if int(fighter.team) == 1 else 105),-float(release.z)-(42 if int(fighter.team) == 1 else 96))+view._projectile_release_offset(release)
		elif not fresh: context.audio_only = true
	elif type == "weapon_swing":
		if event.get("action","") == "boss_sword_wave": events[id] = false; return false
		if event.get("weapon","") in ["blunt","kick","chain","needle"]: events[id] = false; return false
		recipe = "thrust_cone" if event.get("weapon","") == "spear" else "neutral_slash_arc"
		context.audio_only = true
	elif type == "bow_release":
		recipe = "arrow_trail"
		context.merge({"projectile_spawn_id":id,"audio_only":true})
	elif type in ["hit","heavy_hit","shield_hit","guard","guard_break","run_bump"]:
		position.y -= 52
		context.binding_actor = int(event.get("target",event.get("actor",0)))
		recipe = "guard_sparks" if type in ["guard","guard_break","shield_hit"] else ("blunt_impact" if event.get("weapon","") in ["blunt","kick","bullet"] or type == "run_bump" else "slash_hit")
		context.merge({"confirmed_contact":true,"contact_event_id":id})
	elif type == "landing" and not event.get("wet",false): recipe = "dash_dust"
	if recipe.is_empty(): events[id] = false; return false
	var accepted: bool = emitter.trigger(id,recipe,context)
	if accepted and not context.get("audio_only",false): origins[id] = position
	# Keep contact visuals; the weapon bank owns the single audible physical impact.
	events[id] = accepted and not sampled
	return events[id]

func draw_world(canvas, camera_x: float) -> void:
	if not configured: return
	for id in origins:
		if int(emitter.instances[id].context.get("binding_actor",0)) == 0: emitter.draw_instance(canvas,id,origins[id]-Vector2(camera_x,0),true)

func draw_bound(canvas, actor_id: int, camera_x: float) -> void:
	if not configured: return
	for id in origins:
		if int(emitter.instances[id].context.get("binding_actor",0)) == actor_id: emitter.draw_instance(canvas,id,origins[id]-Vector2(camera_x,0),true)

func draw_actor(canvas, fighter: Dictionary, origin: Vector2, height: float, sample: Dictionary, frame: Dictionary, front: bool) -> bool:
	if not configured or fighter.get("kind","") not in Battle.HEROES: return false
	var action := str(fighter.get("action","idle"))
	var element := family(fighter)
	var tick := float(sample.get("tick",0))
	var face := float(fighter.get("face",1))
	var at := origin-Vector2(0,float(fighter.get("z",0)))
	if action == "charge":
		var ring := "blade_ring" if element == "neutral" else element+"_ring"
		shared_player.draw_phase(canvas,ring,float(fighter.get("charge",0)),72,at-Vector2(0,height*.25),front,{"opacity":[[0,.2],[.5,.5],[1,.65]],"radius":[[0,.55],[.5,.8],[1,1]],"uv_radians_per_second":[[0,TAU*2/1.2],[1,TAU*2/1.2]]},{"face":face,"size":height*1.3,"particle_intensity":0})
		return true
	if action not in ["light","heavy","charged","rising","low_sweep","dash_strike","dash_heavy","air_light","air_heavy","upper_heavy","charged_upper","ground_slam","charged_slam","mixed_finisher","mixed_rising","counter_cut"]: return false
	if not front or not sample.get("released",false): return true
	if fighter.kind == "hideyoshi" and action == "charged_slam": return true
	var geometry: Dictionary = canvas._weapons.geometry(fighter,frame,height)
	var effect := "neutral_slash_arc" if element == "neutral" else element+"_arc"
	var age := float(sample.frame)-float(sample.count)/2
	var curves := {"opacity":[[0,.7],[.55,.45],[1,0]],"scale":[[0,.9],[.4,1],[1,1]]}
	if not geometry.is_empty() and geometry.family == "sword":
		var hand: Vector2 = geometry.hand*Vector2(face,1)
		var direction: Vector2 = (geometry.top-geometry.hand)*Vector2(face,1)
		shared_player.draw_phase(canvas,effect,age,3,at+hand,true,curves,{"face":1,"rotation":direction.angle(),"size":direction.length()*2.0})
	elif not geometry.is_empty() and geometry.family == "spear":
		var tip: Vector2 = geometry.top*Vector2(face,1)
		var direction: Vector2 = (geometry.top-geometry.hand)*Vector2(face,1)
		shared_player.draw_phase(canvas,"neutral_thrust_cone",age,3,at+tip,true,curves,{"face":1,"rotation":direction.angle(),"size":height*.6,"stretch":Vector2(1,.4)})
	elif geometry.is_empty():
		var reach := minf(float(fighter.get("attack_reach",height)),height*1.15)
		shared_player.draw_phase(canvas,effect,age,3,at+Vector2(face*reach*.4,-height*.55),true,curves,{"face":face,"size":reach*.9})
	return true

static func nobunaga_cut_pose(fighter: Dictionary, sample: Dictionary, geometry: Dictionary) -> Dictionary:
	if geometry.is_empty(): return {}
	var clip := str(sample.clip)
	var window: Array = {"light_1":[6,11],"light_2":[9,12],"light_3":[5,9],"heavy":[7,11],"dash_heavy":[5,9]}.get(clip,[])
	if window.is_empty() or int(sample.frame) < int(window[0]) or int(sample.frame) > int(window[1]): return {}
	var direction: Vector2 = geometry.top-geometry.hand
	var size := maxf(210.0,direction.length()*2.1) * (1.2 if clip == "dash_heavy" else 1.0)
	var angle := direction.angle()
	var tip: Vector2 = geometry.top+direction.normalized()*12
	var center := tip-Vector2(.29,-.09).rotated(angle)*size
	return {"center":center*Vector2(float(fighter.face),1),"rotation":angle,"size":size,"age":float(sample.frame)-float(window[0]),"duration":float(window[1]-window[0]+1)}

func draw_nobunaga_cut(canvas, fighter: Dictionary, ground: Vector2, height: float, sample: Dictionary, frame: Dictionary, front: bool) -> void:
	if not configured or not front: return
	var pose := nobunaga_cut_pose(fighter,sample,canvas._weapons.geometry(fighter,frame,height))
	if pose.is_empty(): return
	shared_player.draw_phase(canvas,"blade_arc",pose.age,pose.duration,ground-Vector2(0,float(fighter.z))+pose.center,true,{"opacity":[[0,.85],[.55,.95],[1,0]]},{"face":fighter.face,"rotation":pose.rotation,"size":pose.size})

func draw_wave(canvas, effect: Dictionary, ground: Vector2) -> bool:
	if not configured: return false
	var type := str(effect.get("type",""))
	if type == "wind_wave" and effect.get("kind","") == "hideyoshi" and effect.get("action","") == "charged":
		var age := float(effect.max_life-effect.life)
		var distance := float(effect.radius)
		var face := float(effect.face)
		shared_player.draw_phase(canvas,"wind_wave",age,float(effect.max_life),ground+Vector2(face*distance*.5,-55),true,{"opacity":[[0,.75],[.4,.5],[1,0]]},{"face":face,"size":maxf(90,distance*1.7),"stretch":Vector2(1,.4)})
		shared_player.draw_phase(canvas,"wind_arc",age,float(effect.max_life),ground+Vector2(face*(distance+55),-65),true,{"opacity":[[0,.95],[.5,.8],[1,0]]},{"face":face,"size":300.0,"rotation":-.55 if int(effect.get("combo",1))==2 else .55})
		return true
	if type == "blade_wave" and effect.get("action","") == "air_heavy":
		var age := float(effect.max_life-effect.life)
		var reach := float(effect.radius)
		var depth := float(effect.hit_depth)
		var face := float(effect.face)
		var sweep := clampf(age/8.0,0,1)
		var height := maxf(180,float(effect.z)+120)
		var center := ground+Vector2(face*reach*.42,-height*.5+lerpf(-45,30,sweep))
		shared_player.draw_phase(canvas,"blade_arc",age,float(effect.max_life),center,true,{"opacity":[[0,.95],[.45,.85],[1,0]]},{"face":face,"rotation":lerpf(-.8,.65,sweep),"size":reach*1.35,"stretch":Vector2(1,height/reach)})
		shared_player.draw_phase(canvas,"blade_wave",age,float(effect.max_life),ground+Vector2(face*reach*.48,-20),true,{"opacity":[[0,.45],[.3,.75],[1,0]]},{"face":face,"size":reach*1.25,"stretch":Vector2(1,depth*2.0/(reach*1.25))})
		return true
	if type == "slash" and effect.get("finisher",false):
		var age := float(effect.max_life-effect.life)
		var reach := float(effect.radius)
		var weapon := str(effect.kind)
		var id: String = {"sword":"blade_arc","spear":"wind_wave","blunt":"wind_hit","kick":"wind_arc"}.get(weapon,"blade_arc")
		var size := maxf(240,reach*1.6)
		var height := maxf(220,float(effect.hit_depth)*3.6)
		var center := ground+Vector2(float(effect.face)*reach*.55,-80)
		shared_player.draw_phase(canvas,id,age,float(effect.max_life),center,true,{"opacity":[[0,.95],[.45,.9],[1,0]],"scale":[[0,.9],[.25,1],[1,1]]},{"face":effect.face,"size":size,"stretch":Vector2(1,height/size)})
		return true
	if type == "slash":
		var duration := float(effect.get("max_life",10))
		shared_player.draw_phase(canvas,"neutral_slash_arc",duration-float(effect.get("life",duration)),duration,ground-Vector2(0,52),true,{"opacity":[[0,.4],[.4,.3],[1,0]],"scale":[[0,.55],[.4,1],[1,1]]},{"face":effect.get("face",1),"size":float(effect.get("radius",60))*1.5})
		return true
	if type == "landing" and not effect.get("wet",false):
		for id in origins:
			if emitter.instances[id].recipe_id == "dash_dust" and origins[id].distance_squared_to(ground) < 4: return true
		var duration := float(effect.get("max_life",22))
		shared_player.draw_phase(canvas,"neutral_dust",duration-float(effect.get("life",duration)),duration,ground,true,{"opacity":[[0,.25],[1,0]],"scale":[[0,.3],[1,1]]},{"size":110})
		return true
	var element := type.trim_suffix("_wave")
	if type not in ["fire_wave","ice_wave","wind_wave","earth_wave","blade_wave"]: return false
	var age := float(effect.get("max_life",24))-float(effect.get("life",24))
	var duration := float(effect.get("max_life",24))
	var reach := float(effect.get("radius",180))
	var face := float(effect.get("face",1))
	var id := "neutral_dust" if element == "earth" else element+"_wave"
	shared_player.draw_phase(canvas,id,age,duration,ground+Vector2(face*reach*.35,-35),true,{"opacity":[[0,.6],[.25,.8],[1,0]],"scale":[[0,.75],[.25,1],[1,1]]},{"face":face,"size":reach*.9,"stretch":Vector2(1,.7)})
	return true

func draw_ground(canvas, effect: Dictionary, ground: Vector2) -> bool:
	if not configured or effect.get("type","") != "shockwave": return false
	var age := float(effect.max_life-effect.life)
	var element := str(effect.get("element","earth"))
	var id := "neutral_dust" if element == "earth" or element == "" else element+"_ring"
	if element not in ["earth",""]: shared_player.draw_phase(canvas,id,age,float(effect.max_life),ground,false,{"opacity":[[0,.35],[.5,.4],[1,0]],"radius":[[0,.15],[1,1]]},{"face":effect.get("face",1),"size":float(effect.radius)*2,"stretch":Vector2(1,.38)})
	shared_player.draw_phase(canvas,id,age,float(effect.max_life),ground,true,{"opacity":[[0,.35],[.5,.4],[1,0]],"radius":[[0,.15],[1,1]]},{"face":effect.get("face",1),"size":float(effect.radius)*2,"stretch":Vector2(1,.38)})
	return true

func draw_tail(canvas, effect: Dictionary, position: Vector2) -> void:
	if not configured or effect.get("weapon","") == "bullet": return
	var velocity := Vector2(float(effect.get("vx",0)),float(effect.get("vy",0)))*60
	var binding := Motion.trail_binding(position,velocity,.055,180,.22)
	if not binding.visible: return
	shared_player.draw_phase(canvas,"neutral_trail_strip",1,600,position,true,{"opacity":[[0,.45],[1,.45]]},{"face":1,"rotation":binding.rotation,"size":180*binding.size_multiplier,"stretch":binding.stretch})

func draw_impact(canvas, effect: Dictionary, position: Vector2) -> bool:
	if not configured: return false
	var kind := str(effect.get("type",""))
	if kind in ["hit","shield_hit","guard","guard_break"]:
		for instance in origins:
			if emitter.instances[instance].recipe_id in ["guard_sparks","blunt_impact","slash_hit"] and origins[instance].distance_squared_to(position) < 4: return true
	var id: String = {"hit":"neutral_hit_burst","shield_hit":"neutral_hit_burst","guard":"neutral_hit_burst","guard_break":"neutral_hit_burst","fire_hit":"fire_burn","ice_hit":"ice_shatter","shatter":"ice_shatter","wind_hit":"wind_hit","blade_hit":"blade_hit","earth_hit":"neutral_hit_burst"}.get(kind,"")
	if id.is_empty(): return false
	var duration := float(effect.get("max_life",24))
	shared_player.draw_phase(canvas,id,duration-float(effect.get("life",duration)),duration,position,true,{"opacity":[[0,.85],[.3,.65],[1,0]],"scale":[[0,.55],[.3,1],[1,1.15]]},{"size":100,"face":effect.get("face",1)})
	return true

func draw_status(canvas, fighter: Dictionary, position: Vector2, height: float, front: bool = true) -> bool:
	if not configured: return false
	var tick := float(canvas.state.get("tick",0))
	if front and int(fighter.get("burn",0)) > 0:
		shared_player.draw_phase(canvas,"fire_burn",tick,600,position-Vector2(0,height*.65),true,{"opacity":[[0,.6],[1,.6]]},{"size":height*.8,"face":fighter.get("face",1)})
	if int(fighter.get("freeze",0)) > 0:
		shared_player.draw_phase(canvas,"ice_ring",tick,600,position-Vector2(0,height*.55),front,{"opacity":[[0,.5],[1,.5]]},{"size":height*1.1,"stretch":Vector2(1,4.0)})
	return true
