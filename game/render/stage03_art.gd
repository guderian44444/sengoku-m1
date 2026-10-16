extends RefCounted

const Battle = preload("res://core/battle.gd")
const ROOT := "res://assets/stage3/enemies/"
var actors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "registration.json"))
var frames := {}

static func actor_id(world: Dictionary, fighter: Dictionary) -> String:
	if world.get("stage",{}).get("id",0) != 3 or fighter.get("team",0) != 1 or fighter.get("faction","") != "imagawa": return ""
	if not world.has("encounter") or fighter.get("encounter_epoch",-1) != world.encounter.epoch: return ""
	if fighter.get("is_yoshimoto",false): return "yoshimoto"
	if fighter.has("lieutenant_slot"): return "ii_naomori" if fighter.lieutenant_slot == 1 else "ujinori"
	if fighter.get("role","") == "shield_spear": return "shield"
	return {"soldier":"spear","archer":"archer"}.get(fighter.get("kind",""),"")

func sample(world: Dictionary, fighter: Dictionary, walk_tick: float, clock_tick: float) -> Dictionary:
	var actor := actor_id(world,fighter)
	if actor.is_empty(): return {}
	var action: String = fighter.action
	var clip := "idle"
	var time := float(fighter.action_tick) * 1000.0 / 60.0
	var genuine := true
	if fighter.hp <= 0 or action in ["down","dead","defeated","recovering"]: clip = "down"
	elif action in ["hurt","grabbed","pulled","stunned","frozen","thrown","launched"]:
		clip = "hurt"
		if action != "hurt": time = 100.0
		genuine = action == "hurt"
	elif action == "guard" or (actor == "shield" and fighter.get("guard_hit_tick",0) > 0):
		clip = "block" if actors[actor].actions.has("block") else ("guard_retreat" if actors[actor].actions.has("guard_retreat") else "hurt")
		time = 160.0
	elif Battle.ENEMY_TIMING.has(action):
		clip = {"boss_arrow":"bow_shot","boss_sword_wave":"sword_energy"}.get(action,"naginata_slash" if actor == "yoshimoto" else ("thrust" if actor == "ii_naomori" else ("slash" if actor == "ujinori" else "attack")))
	elif fighter.get("moving",false) or fighter.get("entering",false):
		clip = "walk"
		if actor == "yoshimoto" and fighter.get("tactic","") == "backstep": clip = "retreat"
		elif actor in ["ii_naomori","ujinori"] and fighter.get("tactic","") == "retreat": clip = "guard_retreat"
		time = walk_tick * 1000.0 / 60.0
	else: time = clock_tick * 1000.0 / 60.0
	var spec: Dictionary = actors[actor].actions[clip]
	var duration := 0.0
	for frame in spec.frames: duration += float(frame.duration_ms)
	var released := false
	if spec.has("release_ms") and Battle.ENEMY_TIMING.has(action):
		var timing := Battle.enemy_timing(fighter)
		var tick := float(fighter.action_tick)
		var hit := float(spec.release_ms)
		time = tick / timing[0] * hit if tick < timing[0] else hit + (tick-timing[0]) / (timing[1]-timing[0]) * (duration-hit)
		released = tick >= timing[0]
	elif action == "recovering": time = duration * (1.0-clampf(float(fighter.action_tick)/Battle.RECOVER_TICKS,0,1))
	elif action == "down" and fighter.get("down_from_air",false): time = duration
	if spec.loop: time = fposmod(time,duration)
	var index := 0
	while index < spec.frames.size()-1 and time >= float(spec.frames[index].duration_ms):
		time -= float(spec.frames[index].duration_ms)
		index += 1
	var item: Dictionary = spec.frames[index]
	var key: String = item.package_path
	if not frames.has(key):
		var image := Image.load_from_file(ROOT + key)
		assert(image != null,"Missing Stage 3 frame: " + key)
		frames[key] = {"texture":ImageTexture.create_from_image(image),"region":Rect2(Vector2.ZERO,image.get_size()),"anchor":Vector2(item.root[0],item.root[1]),"body_height":float(actors[actor].body_height),"source":"stage3","opaque_bounds":Rect2(image.get_used_rect())}
	return {"clip":clip,"sheet":"stage3","frame":index,"cell":index,"count":spec.frames.size(),"tick":fighter.action_tick,"duration":duration,"released":released,"source":"stage3","hero":fighter.kind,"genuine_reaction":genuine,"frame_data":frames[key],"actor":actor}
