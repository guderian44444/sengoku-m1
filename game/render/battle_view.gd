extends Node2D

const ArtAssets = preload("res://render/art_assets.gd")
const FrameAnimation = preload("res://render/frame_animation.gd")

var state: Dictionary = {}
var camera_x: float = 0.0
var local_slot: int = 0
var weather: int = 0
var art_demo: bool = false
var art_time: float = 0.0
var demo_pose: int = -1
var demo_progress: float = 0.0
var _art = ArtAssets.new()
var _positions: Dictionary = {}
var _moving: Dictionary = {}
var _walk_distance: Dictionary = {}
var _walk_ticks: Dictionary = {}
var _facing_back: Dictionary = {}
var _motion_tick: int = -1
var _projectile_origins: Dictionary = {}
var _frozen_samples: Dictionary = {}

const INK := Color("172226")
const PAPER := Color("e0d4b4")
const RED := Color("b84538")
const GOLD := Color("d9af5e")
const DECOR_PARALLAX := {"background": 128.0 / 1100.0, "bamboo": 0.14, "ground": 1.0, "flags": 1.0, "fence": 1.0, "stone": 1.0, "grass": 1.0, "ripples": 1.0}
const GROUND_TILE_WIDTH := 1408.0
const GROUND_TOP := 364.0
const GROUND_BLEND_HEIGHT := 24.0

static func decor_offset(layer: String, camera: float) -> float:
	return camera * float(DECOR_PARALLAX.get(layer, 1.0))

static func ground_tiles(camera: float) -> Array:
	var tiles := []
	for index in range(floori(camera / GROUND_TILE_WIDTH),floori((camera + 1280.0) / GROUND_TILE_WIDTH) + 1):
		tiles.append({"x":index * GROUND_TILE_WIDTH - camera,"mirrored":posmod(index,2) == 1})
	return tiles

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	_update_motion()
	_draw_landscape()
	_draw_scenery()
	_draw_wet_zones()
	for effect in state.get("effects", []):
		if effect.get("type", "") in ["warning", "slam", "shockwave", "arrow_target"]:
			_draw_ground_effect(effect)
	for drop in state.get("drops", []):
		_draw_drop(drop)
	var fighters: Array = state.get("fighters", []).duplicate()
	fighters.append_array(_npc_samples(_art_clock()))
	for prop in state.get("props",[]):
		var display: Dictionary = prop.duplicate()
		display["scenery_prop"] = true
		fighters.append(display)
	fighters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return fighter_depth(a) < fighter_depth(b))
	for fighter in fighters:
		if fighter.get("scenery_prop",false):
			_draw_prop(fighter)
		elif fighter.get("scenery_npc", false):
			_draw_npc(fighter)
		else:
			_draw_fighter(fighter)
	_draw_demo_projectiles()
	var live_origins: Dictionary = {}
	for effect in state.get("effects", []):
		if effect.get("type", "") == "projectile":
			var key := _projectile_key(effect)
			live_origins[key] = _projectile_release_offset(effect)
		_draw_effect(effect)
	_projectile_origins = live_origins
	draw_set_transform(Vector2.ZERO)
	_draw_weather()

static func fighter_depth(fighter: Dictionary) -> float:
	return float(fighter.get("y", 0)) + (0.25 if int(fighter.get("held_by", 0)) != 0 else 0.0)

func _update_motion() -> void:
	var tick := int(art_time * 60.0) if art_demo else int(state.get("tick", 0))
	if tick == _motion_tick:
		return
	var elapsed := maxi(0,tick - _motion_tick)
	if tick < _motion_tick:
		_positions.clear()
		_walk_distance.clear()
		_walk_ticks.clear()
		_frozen_samples.clear()
	_motion_tick = tick
	for fighter in state.get("fighters", []):
		var id := int(fighter.get("id", -1))
		var position_now := Vector2(float(fighter.get("x", 0)), float(fighter.get("y", 0)))
		var movement: Vector2 = position_now - _positions.get(id, position_now)
		_moving[id] = movement.length_squared() > 0.1
		if _moving[id]:
			_facing_back[id] = movement.y < -0.1 and absf(movement.y) > absf(movement.x)
			if movement.length() < 60.0 and str(fighter.get("action", "idle")) in ["idle", "walk", "run", "move", "retreat"] and float(fighter.get("z", 0)) <= 0:
				_walk_distance[id] = float(_walk_distance.get(id, 0.0)) + movement.length()
		if (int(fighter.get("team",0)) == 0 and str(fighter.get("kind","")) in ["nobunaga","oichi"]) or (int(fighter.get("team",0)) != 0 and fighter.get("faction","mori") == "mori"):
			var walking: bool = fighter.get("moving",_moving[id]) and str(fighter.get("action","idle")) in ["idle","walk","run","move","retreat"] and float(fighter.get("z",0)) <= 0 and int(fighter.get("freeze",0)) == 0
			if walking:
				_walk_ticks[id] = int(_walk_ticks[id]) + elapsed if _walk_ticks.has(id) else 0
			else:
				_walk_ticks.erase(id)
		_positions[id] = position_now

func animation_sample(hero: String = "nobunaga") -> Dictionary:
	_update_motion()
	for fighter in state.get("fighters", []):
		if fighter.get("kind", "") == hero and int(fighter.get("team", 0)) == 0:
			return _fighter_animation(fighter)
	return _fighter_animation({"kind": hero})

static func _hero_animation_tick(hero: String, action: String, tick: float) -> float:
	var milestones: Array = {
		"light":[6,19], "heavy":[14,36], "charged":[14,36], "rising":[6,24],
		"ground_slam":[14,42], "low_sweep":[9,28], "dash_strike":[10,30], "dash_heavy":[12,34],
		"air_light":[6,20], "air_heavy":[12,19,38], "upper_heavy":[12,36],
		"charged_upper":[22,56], "charged_slam":[28,72],
		"mixed_finisher":[9,27,48], "mixed_rising":[9,27,48], "counter_cut":[5,24]
	}[action]
	var previous_live := 0.0
	var previous_drawing := 0.0
	for milestone in milestones:
		var live := float(FrameAnimation.Battle.hero_tick(hero,int(milestone)))
		if tick <= live:
			# The simulation rounds attack-speed timings to whole ticks. Match each
			# impact and recovery boundary exactly instead of multiplying after rounding.
			return lerpf(previous_drawing,float(milestone),(tick - previous_live) / (live - previous_live))
		previous_live = live
		previous_drawing = float(milestone)
	return previous_drawing

static func _retreat_backwards(fighter: Dictionary) -> bool:
	if fighter.get("action", "") != "retreat": return false
	# A ranged fighter escaping the wall side-steps and then runs forward past
	# the pursuer; only the portion moving away from its facing plays backwards.
	return float(fighter.get("move_dx",-float(fighter.get("face",1)))) * float(fighter.get("face",1)) < 0

func _fighter_animation(fighter: Dictionary) -> Dictionary:
	var hero := str(fighter.get("kind", "nobunaga"))
	var action := str(fighter.get("action", "idle"))
	var tick := float(fighter.get("action_tick", 0))
	if int(fighter.get("team",0)) == 0 and action in ["light","heavy","charged","rising","ground_slam","low_sweep","dash_strike","dash_heavy","air_light","air_heavy","upper_heavy","charged_upper","charged_slam","mixed_finisher","mixed_rising","counter_cut"]:
		tick = _hero_animation_tick(hero,action,tick)
		fighter = fighter.duplicate()
		fighter.action_tick = tick
	var clock_tick := _art_clock() * 60.0
	var walking: bool = fighter.get("moving", _moving.get(int(fighter.get("id", -1)), false))
	if int(fighter.get("team",0)) == 0 and hero == "tadakatsu":
		if art_demo and demo_pose >= 0:
			var showcase := FrameAnimation.demo_sample(demo_pose,demo_progress,_art_clock())
			action = str(showcase.clip)
			tick = float(showcase.tick)
			walking = action == "walk"
			if action == "victory": clock_tick = tick
		if state.get("phase","") == "won": action = "victory"
		elif action == "idle" and float(fighter.get("z",0)) > 0: action = "jump"
		return _tadakatsu_sample(fighter,action,tick,walking,clock_tick)
	if int(fighter.get("team", 0)) != 0 and _art.enemies.has(hero):
		var id := int(fighter.get("id", 0))
		if int(fighter.get("freeze", 0)) > 0 and _frozen_samples.has(id) and _frozen_samples[id].hero == hero:
			return _frozen_samples[id]
		var hd_enemy := fighter.duplicate()
		hd_enemy.moving = walking
		var discrete := FrameAnimation.enemy_v14_sample(hd_enemy,float(_walk_ticks.get(id,0)),clock_tick,_art.enemy_clips)
		if not discrete.is_empty():
			_frozen_samples[id] = discrete
			return discrete
		var enemy_key: String = _art._enemy_key(hero,str(fighter.get("faction","mori")))
		if _art.enemy_reactions.has(enemy_key) and action in ["hurt","stunned","grabbed","pulled","launched","thrown","down","recovering","dead","defeated"]:
			var role := ["soldier","flag","commander","archer","gunner","boss"].find(hero)
			var counts: Array = _art.v11_counts.get("reactions-" + str(fighter.get("faction","mori")),[8,8,8,8,8,8])
			var pain := FrameAnimation.enemy_reaction_sample(action,tick,int(counts[role]),float(fighter.get("z",0)) > 0)
			pain.hero = hero
			_frozen_samples[id] = pain
			return pain
		var hd_boss: bool = hero == "boss" and _art.enemy_attacks.has(enemy_key) and _art.enemy_attacks[enemy_key][0].source == "v12"
		if hd_boss and action == "idle" and not walking:
			return {"clip":"idle","sheet":"enemy_attack","frame":0,"cell":0,"count":12,"tick":tick,"duration":0,"released":false,"source":"v12","hero":hero}
		if not hd_boss and _art.enemy_movements.has(enemy_key) and action in ["idle","walk","run","move","retreat"]:
			var role := ["soldier","flag","commander","archer","gunner","boss"].find(hero)
			var count := int(_art.v11_counts["movement-" + str(fighter.get("faction","mori"))][role])
			var step := posmod(floori(float(_walk_distance.get(id,0)) / 106.0 * count),count) if walking else 0
			if _retreat_backwards(fighter): step = posmod(-step,count)
			var movement := {"clip":action,"sheet":"enemy_movement","frame":step,"cell":step,"count":count,"tick":tick,"duration":0,"released":false,"source":"v11","hero":hero}
			_frozen_samples[id] = movement
			return movement
		if _art.enemy_attacks.has(enemy_key) and action == FrameAnimation.primary_enemy_action(fighter):
			var role := ["soldier","flag","commander","archer","gunner","boss"].find(hero)
			var count := int(_art.v11_counts["attacks-" + str(fighter.get("faction","mori"))][role])
			var source := str(_art.enemy_attacks[enemy_key][0].source)
			if source == "v12": count = _art.enemy_attacks[enemy_key].size()
			var attack := FrameAnimation.primary_enemy_sample(fighter,count)
			attack.source = source
			_frozen_samples[id] = attack
			return attack
		var atlas_size: int = _art.enemies[enemy_key].size()
		var expanded_enemy := _art.enemy_clip_size(hero,str(fighter.get("faction","mori"))) == 6
		var enemy := FrameAnimation.enemy_sample(hero, action, tick, float(_walk_distance.get(id, 0.0)), walking, expanded_enemy)
		enemy.source = str(_art.enemies[enemy_key][0].get("source","v09"))
		if hero == "boss" and FrameAnimation.Battle.ENEMY_TIMING.has(action):
			var timing: Array = FrameAnimation.Battle.enemy_timing(fighter)
			var count := 6 if expanded_enemy else 4
			enemy.frame = FrameAnimation._attack_frame(tick,float(timing[0]),float(timing[1]),count)
			enemy.released = tick >= timing[0]
			enemy.duration = timing[1]
			if fighter.get("boss_variant","kusarigama") != "kusarigama": enemy.cell = (clampi(int(fighter.get("attack_variant",0)),0,2) + 1) * count + int(enemy.frame)
		if atlas_size == 8 and action in ["bow_shot","gun_shot"]:
			var timing: Array = FrameAnimation.Battle.enemy_timing(fighter)
			enemy.frame = mini(1,floori(tick * 2.0 / timing[0])) if tick < timing[0] else (2 if tick < timing[0] + (7 if action == "gun_shot" else 15) else 3)
			enemy.cell = 4 + int(enemy.frame)
		if _retreat_backwards(fighter) and hero in ["archer", "gunner"] and walking:
			# Backstep keeps the face toward the target and reverses the actual walking poses.
			enemy.frame = posmod(-int(enemy.frame),4)
			enemy.cell = int(enemy.frame)
		elif atlas_size == 8 and action in ["hurt","stunned","grabbed","pulled","thrown","launched","down","recovering","dead","defeated"]:
			enemy.cell = 0
		_frozen_samples[id] = enemy
		return enemy
	if int(fighter.get("team",0)) == 0 and (not art_demo or hero in ["nobunaga", "oichi"]):
		var hd_fighter := fighter.duplicate()
		hd_fighter.moving = walking
		hd_fighter.locomotion_tick = clock_tick if art_demo else float(_walk_ticks.get(int(fighter.get("id",-1)),0))
		if action == "idle": hd_fighter.action_tick = clock_tick
		var showcase := {}
		if art_demo and demo_pose >= 0:
			showcase = FrameAnimation.demo_sample(demo_pose, demo_progress, _art_clock())
			if demo_pose == 8 and _art.animations.get(hero,{}).has("v15_victory"):
				showcase = FrameAnimation.sample("victory",minf(120.0,demo_progress * FrameAnimation.DEMO_SECONDS * 60.0))
			hd_fighter.action = "air_light" if showcase.clip == "jump" else ("idle" if showcase.clip == "walk" else showcase.clip)
			hd_fighter.action_tick = showcase.tick
			hd_fighter.moving = showcase.clip == "walk"
			fighter = hd_fighter
			action = str(fighter.action)
			tick = float(fighter.action_tick)
			walking = bool(fighter.moving)
		var hd_height := (225 if hero == "oichi" else 240) if art_demo else (148 if hero == "oichi" else 155)
		var hd := FrameAnimation.hero_v12_sample(hd_fighter,float(_walk_distance.get(int(fighter.get("id",-1)),0)),hd_height,_art.animations.get(hero,{}))
		if not hd.is_empty():
			if not showcase.is_empty():
				hd.clip = showcase.clip
				# Compact showcases retain their original release times and finish one complete action.
				if showcase.clip in ["jump", "special", "throw"]:
					var hit: float = {"jump":16.0,"special":26.0,"throw":12.0}[showcase.clip]
					hd.frame = FrameAnimation._attack_frame(float(showcase.tick),hit,float(showcase.duration),int(hd.count))
					hd.cell = hd.frame
					hd.duration = showcase.duration
					hd.released = float(showcase.tick) >= hit
			hd.hero = hero
			return hd
		var counts := {}
		for sheet in ["combat","skills","reactions","movement","needles"]:
			if _art.v11_counts.has(hero + "-" + sheet): counts[sheet] = _art.v11_counts[hero + "-" + sheet]
		if not counts.is_empty() and (hero == "oichi" or action != "idle" or walking or float(fighter.get("z",0)) > 0) and not (action == "dash_heavy" and hero in ["hideyoshi","ieyasu","mitsuhide","tadakatsu"]):
			fighter = fighter.duplicate()
			fighter.moving = walking
			if art_demo:
				if action == "jump_attack": fighter.action = "air_light"
				elif action == "victory" and not counts.has("movement"): fighter.action = "idle"
			var modern := FrameAnimation.hero_v11_sample(fighter,float(_walk_distance.get(int(fighter.get("id",-1)),0)),148 if hero == "oichi" else 155,counts)
			if not modern.is_empty():
				if action == "idle" and walking: modern.clip = "walk"
				modern.hero = hero
				return modern
	var expanded_hero := hero in ["hideyoshi", "ieyasu", "mitsuhide", "tadakatsu"]
	var reaction := action in ["guard","hurt","grabbed","pulled","launched","thrown","down","dead","defeated","stunned","recovering"]
	if _art.has_v10(hero) and not art_demo and (expanded_hero or reaction or action == "light" or (walking and action == "idle")):
		if expanded_hero and action == "dash_heavy":
			fighter = fighter.duplicate()
			fighter.action = "heavy"
			fighter.heavy_combo = 1 if hero in ["hideyoshi","tadakatsu"] else 2
			fighter.action_tick = tick * 14.0 / 12.0 if tick < 12 else 14.0 + (tick - 12.0)
		var v10 := FrameAnimation.hero_v10_sample(fighter,float(_walk_distance.get(int(fighter.get("id",-1)),0)),148 if hero == "oichi" else 155)
		if expanded_hero and action == "dash_heavy":
			v10.merge({"clip":action,"tick":tick,"duration":34,"released":tick >= 12},true)
		if action == "idle" and walking: v10.clip = "walk"
		if expanded_hero and action == "idle" and not walking and float(fighter.get("z",0)) <= 0 and _art.animations[hero].has("idle"):
			v10 = FrameAnimation.planted_idle_sample(clock_tick)
		if expanded_hero and action == "idle" and float(fighter.get("z",0)) > 0:
			v10.sheet = "skills"
			v10.frame = 0 if float(fighter.get("vz",0)) > 3 else (1 if float(fighter.get("vz",0)) > -3 else 2)
			v10.cell = 24 + int(v10.frame)
			v10.clip = "jump"
		v10["source"] = "v10"
		v10["hero"] = hero
		return v10
	var clip := action
	if clip in ["charged", "heavy_attack"]: clip = "heavy"
	elif clip in ["attack", "light_attack"]: clip = "light"
	var result: Dictionary
	if art_demo and demo_pose >= 0:
		result = FrameAnimation.demo_sample(demo_pose, demo_progress, _art_clock())
		if demo_pose == 0 and walking:
			result = FrameAnimation.sample("walk", clock_tick)
	elif action in ["rising", "ground_slam", "charged_slam", "low_sweep", "dash_strike", "air_light", "air_heavy", "upper_heavy", "charged_upper", "mixed_finisher", "mixed_rising"] and _art.has_techniques(hero):
		result = FrameAnimation.technique_sample(action, tick)
		if not _art.animations[hero].has(result.sheet):
			result = FrameAnimation.directional_sample("rising" if action == "rising" else "ground_slam", tick)
	elif action == "special" and not art_demo:
		result = FrameAnimation.battle_special_sample(tick)
	elif action == "charge" and int(fighter.get("charge_direction",0)) != 0 and _art.has_techniques(hero):
		var held_action := "charged_upper" if int(fighter.charge_direction) < 0 else "charged_slam"
		result = FrameAnimation.technique_sample(held_action, minf(16.0,tick * 0.6))
		result.clip = "charge"
		result.tick = tick
	elif action in ["rising", "ground_slam"]:
		result = FrameAnimation.directional_sample(action, tick)
	elif action in ["holding", "grabbed", "thrown", "stunned", "pulled"]:
		result = FrameAnimation.restraint_sample(action, tick)
		if action == "holding" and hero == "nobunaga":
			result.frame = 0
			result.cell = 4
	elif action in ["down", "defeated", "dead"] and _art.has_v06(hero):
		result = FrameAnimation.restraint_sample(action, tick)
	elif action in ["hurt", "down", "defeated", "dead"]:
		result = FrameAnimation.sample("hurt", tick)
	elif clip in ["light", "heavy", "charge", "special", "throw"]:
		result = FrameAnimation.sample(clip, tick)
	elif float(fighter.get("z", 0)) > 0 or float(fighter.get("vz", 0)) > 0:
		result = FrameAnimation.jump_sample(float(fighter.get("z", 0)), float(fighter.get("vz", 0)))
	elif state.get("phase", "") == "won":
		result = FrameAnimation.sample("victory", clock_tick)
	else:
		if clip in ["idle", "walk", "run", "move"]: clip = "walk" if walking else "idle"
		result = FrameAnimation.sample(clip, clock_tick if clip in ["idle", "walk", "victory"] else tick)
	if result.clip == "walk":
		var height := (225.0 if hero == "oichi" else 240.0) if art_demo else (148.0 if hero == "oichi" else 155.0)
		var distance := float(_walk_distance.get(int(fighter.get("id", -1)), 0.0))
		result = FrameAnimation.walk_sample(distance, height * 0.82)
	if result.clip == "light" and _art.has_combo(hero):
		result = FrameAnimation.combo_sample(maxi(1, int(fighter.get("combo", 0))), float(result.tick))
	elif hero == "oichi" and action in ["charged_upper", "charged_slam"] and result.sheet in ["advanced", "techniques"] and not result.released:
		result.frame = 1
		result.cell = 5 if action == "charged_upper" else 13
	elif hero == "oichi" and _art.has_v06(hero) and result.clip in ["heavy", "charge"] and result.sheet not in ["techniques", "advanced"]:
		result = FrameAnimation.bow_sample("charged" if action == "charged" and not art_demo else str(result.clip), float(result.tick), int(fighter.get("heavy_combo", 1)))
	elif result.clip == "heavy" and action == "heavy" and int(fighter.get("heavy_combo", 0)) == 2 and _art.has_combo(hero):
		result = FrameAnimation.heavy_chain_sample(2, float(result.tick), hero)
	if _art.has_v06(hero) and result.clip == "hurt" and (art_demo or action == "hurt"):
		# The fourth new drawing is genuinely prone and belongs only to down/thrown states.
		result.count = 3
		result.frame = mini(2, floori(float(result.tick) * 3.0 / 18.0))
		result.cell = 8 + int(result.frame)
	result["source"] = _art.animation_source(hero, result) if _art.has_animation(hero) else ("v03" if _art.heroes.has(hero) else "paper")
	result["hero"] = hero
	if result.source not in ["v04", "v05", "v06", "v07", "v09", "v10"]:
		result.frame = 0
		result.count = 1
		result.cell = ArtAssets.pose_for(action, float(fighter.get("z", 0)))
	return result

func _tadakatsu_sample(fighter: Dictionary, action: String, tick: float, walking: bool, clock_tick: float) -> Dictionary:
	var sheet := "v16_idle"
	var frame := 0
	var count := 12
	var duration := 0.0
	var released := false
	var clip := action
	match action:
		"idle":
			if walking:
				clip = "walk"
				sheet = "v16_run" if fighter.get("sprinting",false) else "v16_walk"
				frame = posmod(floori(clock_tick * (16.0 if fighter.get("sprinting",false) else 12.0) / 60.0),12)
			else:
				count = 6
				frame = posmod(floori(clock_tick / 10.0),6)
		"walk", "run", "move", "retreat":
			sheet = "v16_run" if action == "run" else "v16_walk"
			frame = posmod(floori(clock_tick * (16.0 if action == "run" else 12.0) / 60.0),12) if walking else 0
		"jump", "air_light", "air_heavy":
			sheet = "v16_jump" if action == "jump" else ("v16_light3" if action == "air_light" else "v16_heavy1")
			if action == "jump": frame = clampi(floori(float(fighter.get("z",0)) / 90.0 * 12.0),0,11)
			else:
				frame = FrameAnimation._attack_frame(tick,12.0 if action == "air_heavy" else 6.0,38.0 if action == "air_heavy" else 20.0,12)
				duration = 38.0 if action == "air_heavy" else 20.0
				released = tick >= (12.0 if action == "air_heavy" else 6.0)
		"light":
			sheet = "v16_light%d" % clampi(int(fighter.get("combo",1)),1,3)
			duration = 19.0
			frame = FrameAnimation._attack_frame(tick,6.0,duration,12)
			released = tick >= 6.0
		"heavy", "charged":
			sheet = "v16_charge" if action == "charged" else ("v16_heavy2" if int(fighter.get("heavy_combo",1)) == 2 else "v16_heavy1")
			if action == "charged":
				frame = 6 + clampi(floori(tick * 6.0 / 36.0),0,5)
				duration = 36.0
				released = tick >= 14.0
			else:
				duration = 36.0
				frame = FrameAnimation._attack_frame(tick,14.0,duration,12)
				released = tick >= 14.0
		"charge":
			sheet = "v16_charge"
			frame = clampi(floori(float(fighter.get("charge",0)) * 6.0 / 35.0),0,5)
		"dash_heavy", "heavy_attack":
			sheet = "v16_heavy2"
			frame = FrameAnimation._attack_frame(tick,12.0,34.0,12)
			duration = 34.0
			released = tick >= 12.0
		"rising", "low_sweep", "dash_strike", "upper_heavy", "charged_upper", "ground_slam", "charged_slam", "mixed_finisher", "mixed_rising", "counter_cut":
			var timings: Dictionary = {"rising":[6.0,24.0],"low_sweep":[9.0,28.0],"dash_strike":[10.0,30.0],"upper_heavy":[12.0,36.0],"charged_upper":[22.0,56.0],"ground_slam":[14.0,42.0],"charged_slam":[28.0,72.0],"mixed_finisher":[9.0,48.0],"mixed_rising":[9.0,48.0],"counter_cut":[5.0,24.0]}
			var timing: Array = timings[action]
			var local_tick := tick - (22.0 if action in ["mixed_finisher","mixed_rising"] and tick >= 22.0 else 0.0)
			sheet = "v16_light2" if action == "dash_strike" else ("v16_light3" if action == "mixed_finisher" and tick < 22.0 else ("v16_heavy2" if action == "mixed_rising" else ("v16_charge" if action in ["charged_upper","charged_slam"] else "v16_heavy1")))
			if sheet == "v16_charge":
				frame = 6 + FrameAnimation._attack_frame(local_tick,float(timing[0]),float(timing[1]),6)
			else:
				frame = FrameAnimation._attack_frame(local_tick,float(timing[0]),float(timing[1]),12)
			duration = timing[1]
			released = tick >= timing[0]
		"special":
			sheet = "v16_special"
			duration = FrameAnimation.Battle.SPECIAL_TICKS
			var pulses: Array = FrameAnimation.Battle.SPECIAL_HIT_TICKS.tadakatsu
			for index in range(pulses.size()):
				var start := float(pulses[index - 1]) if index > 0 else 0.0
				var finish := float(pulses[index])
				if tick < finish or index == pulses.size() - 1:
					frame = index * 3 + mini(2,floori(maxf(0.0,tick - start) * 3.0 / maxf(1.0,finish - start)))
					break
			released = tick >= float(pulses[0])
		"holding", "throw":
			sheet = "v16_grab"
			frame = clampi(floori(tick * 12.0 / (30.0 if action == "holding" else 24.0)),0,11)
			if action == "throw": released = tick >= 12.0
		"hurt", "guard", "stunned", "grabbed", "pulled", "frozen":
			sheet = "v16_reactions"
			frame = clampi(floori(tick * 3.0 / 18.0),0,2)
		"launched", "thrown":
			sheet = "v16_reactions"
			frame = 3 + clampi(floori(tick * 3.0 / 18.0),0,2)
		"down":
			sheet = "v16_reactions"
			frame = 6
		"dead", "defeated":
			sheet = "v16_reactions"
			frame = 7
		"recovering":
			sheet = "v16_reactions"
			frame = 8 + clampi(floori(tick * 4.0 / float(FrameAnimation.Battle.RECOVER_TICKS)),0,3)
		"victory":
			sheet = "v16_victory"
			frame = clampi(floori(clock_tick * 12.0 / float(FrameAnimation.Battle.VICTORY_TICKS)),0,11)
			duration = FrameAnimation.Battle.VICTORY_TICKS
		_:
			sheet = "v16_idle"
			count = 6
			frame = posmod(floori(clock_tick / 10.0),6)
	assert(_art.animations.get("tadakatsu",{}).has(sheet) and frame >= 0 and frame < count)
	return {"clip":clip,"sheet":sheet,"frame":frame,"cell":frame,"count":count,"tick":tick,"duration":duration,"released":released,"source":"v16","hero":"tadakatsu"}

func _draw_landscape() -> void:
	var backdrop: Dictionary = _art.background(weather)
	if not backdrop.is_empty():
		var source: Rect2 = backdrop.region
		var horizon := source.size.y * 0.69
		var pan := clampf(decor_offset("background",camera_x),0.0,128.0)
		# Keep architecture behind the road; the lower crop contains only earth and stones.
		draw_texture_rect_region(backdrop.texture, Rect2(-pan, 0, 1408, 364), Rect2(source.position, Vector2(source.size.x, horizon)))
		draw_texture_rect_region(backdrop.texture, Rect2(-pan, 364, 1408, 356), Rect2(source.position + Vector2(0, horizon), Vector2(source.size.x, source.size.y - horizon)))
		_draw_near_ground(backdrop,Rect2(source.position + Vector2(0,horizon),Vector2(source.size.x,source.size.y - horizon)))
		return
	draw_rect(Rect2(0, 0, 1280, 720), Color("26383c"))
	draw_rect(Rect2(0, 130, 1280, 270), Color("4e6667"))
	for ridge in range(3):
		var ridge_points := PackedVector2Array([Vector2(-100, 410)])
		for segment in range(11):
			var x := float(segment * 160 - 100) - fmod(camera_x * (0.08 + ridge * 0.06), 160.0)
			var y := 190.0 + ridge * 42 + sin(segment * 2.1 + ridge) * 42.0
			ridge_points.append(Vector2(x, y))
		ridge_points.append(Vector2(1500, 410))
		draw_colored_polygon(ridge_points, Color(0.21 - ridge * 0.025, 0.32 - ridge * 0.025, 0.33 - ridge * 0.02))
	for index in range(42):
		var bamboo_x := float(index * 88 - 160) - decor_offset("bamboo", camera_x)
		if bamboo_x < -100 or bamboo_x > 1380:
			continue
		var height := 140.0 + float((index * 37) % 115)
		var base := Vector2(bamboo_x, 380)
		var tip := base + Vector2(14 * sin(index), -height)
		draw_line(base, tip, Color("274943"), 8.0)
		for joint in range(1, 5):
			var joint_pos := base.lerp(tip, joint / 5.0)
			draw_line(joint_pos + Vector2(-5, 0), joint_pos + Vector2(5, 0), Color("667d59"), 2.0)
			if joint > 2:
				for leaf in range(3):
					var reach := Vector2((25 + leaf * 10) * (-1 if joint % 2 else 1), -12 + leaf * 9)
					draw_line(joint_pos, joint_pos + reach, Color("34584c"), 4.0)
	draw_rect(Rect2(0, 360, 1280, 320), Color("655e4e"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 405), Vector2(1280, 370), Vector2(1280, 599), Vector2(0, 630)]), Color("84755b"))
	for index in range(60):
		var stone_x := float((index * 157) % 2500) - decor_offset("stone", camera_x)
		var stone_y := 407.0 + float((index * 53) % 208)
		if stone_x > -30 and stone_x < 1310:
			_ellipse(Vector2(stone_x, stone_y), Vector2(12 + index % 17, 3 + index % 3), Color(0.32, 0.34, 0.31, 0.30))
	for index in range(27):
		var fence_x := float(index * 98 + 20) - decor_offset("fence", camera_x)
		if fence_x < -100 or fence_x > 1380:
			continue
		draw_line(Vector2(fence_x, 388), Vector2(fence_x + 3, 317), Color("3e3930"), 9)
		draw_line(Vector2(fence_x, 334), Vector2(fence_x + 98, 337), Color("534937"), 7)
		draw_line(Vector2(fence_x, 365), Vector2(fence_x + 98, 361), Color("534937"), 6)
	_draw_gate(2105.0 - camera_x)
	draw_rect(Rect2(0, 648, 1280, 72), Color("27372f"))
	for index in range(floori(camera_x / 15.0) - 1,floori(camera_x / 15.0) + 87):
		var grass_x := index * 15.0 - decor_offset("grass", camera_x)
		draw_line(Vector2(grass_x, 663), Vector2(grass_x - 6, 635 - index % 4 * 5), Color("3c5140"), 4)

func _draw_near_ground(backdrop: Dictionary, source: Rect2) -> void:
	var texture_size: Vector2 = backdrop.texture.get_size()
	for tile in ground_tiles(decor_offset("ground",camera_x)):
		var left: float = source.end.x if tile.mirrored else source.position.x
		var right: float = source.position.x if tile.mirrored else source.end.x
		# Mirrored neighbors share the exact edge pixels; fade only the distant road margin.
		for band in range(2):
			var top := GROUND_TOP if band == 0 else GROUND_TOP + GROUND_BLEND_HEIGHT
			var bottom := GROUND_TOP + GROUND_BLEND_HEIGHT if band == 0 else 720.0
			var uv_top := source.position.y + (top - GROUND_TOP) / (720.0 - GROUND_TOP) * source.size.y
			var uv_bottom := source.position.y + (bottom - GROUND_TOP) / (720.0 - GROUND_TOP) * source.size.y
			var vertices := PackedVector2Array([Vector2(tile.x,top),Vector2(tile.x + GROUND_TILE_WIDTH,top),Vector2(tile.x + GROUND_TILE_WIDTH,bottom),Vector2(tile.x,bottom)])
			var uvs := PackedVector2Array([Vector2(left,uv_top) / texture_size,Vector2(right,uv_top) / texture_size,Vector2(right,uv_bottom) / texture_size,Vector2(left,uv_bottom) / texture_size])
			var edge := Color(1,1,1,0) if band == 0 else Color.WHITE
			draw_polygon(vertices,PackedColorArray([edge,edge,Color.WHITE,Color.WHITE]),uvs,backdrop.texture)

func _art_clock() -> float:
	return art_time if art_demo else float(state.get("tick", 0)) / 60.0

func _camp_flag_sample(index: int, clock: float) -> Dictionary:
	var frames: Array = _art.prop_frames.get("mori-camp-flag",[])
	if state.get("faction","") == "mori" and not frames.is_empty():
		return {"frame":frames[posmod(floori(clock * 5),frames.size())],"rotation":0.0}
	return {"frame":_art.scenery_frames[index % 2],"rotation":sin(clock * 2.2 + index) * 0.018}

func _draw_scenery() -> void:
	if _art.scenery_frames.size() != 8:
		return
	var clock := _art_clock()
	for index in range(5):
		var x := 140.0 + index * 510.0 - decor_offset("flags", camera_x)
		if x < -150 or x > 1430:
			continue
		var flag := _camp_flag_sample(index,clock)
		_draw_art_frame(flag.frame, Vector2(x, 392), 134.0, 1.0, flag.rotation)
		var fire_x := x + 160.0
		var fire_position := Vector2(fire_x, 402)
		var glow := 0.08 if weather == 0 else 0.16
		var flicker := 0.88 + sin(clock * 14.0 + index) * 0.12
		for ring in range(4, 0, -1):
			draw_circle(fire_position - Vector2(0, 38), ring * 15.0 * flicker, Color(1.0, 0.55, 0.12, glow / 4.0))
		_draw_art_frame(_art.scenery_frames[2 + (int(clock * 7 + index) % 2)], fire_position, 87.0)

func _npc_samples(clock: float) -> Array:
	var people: Array = []
	var lanes := [
		{"kind":"woman","origin":310.0,"y":424.0,"speed":42.0,"scale":1.0},
		{"kind":"child","origin":430.0,"y":430.0,"speed":42.0,"scale":0.63},
		{"kind":"elder","origin":1030.0,"y":449.0,"speed":-31.0,"scale":0.96},
		{"kind":"cart_vendor","origin":1490.0,"y":465.0,"speed":-43.0,"scale":1.08},
		{"kind":"herb_vendor","origin":750.0,"y":422.0,"speed":0.0,"scale":1.02},
		{"kind":"produce_vendor","origin":1780.0,"y":448.0,"speed":0.0,"scale":1.0}
	]
	var flee_tick := int(state.get("civilian_flee_tick",-1))
	var fleeing := flee_tick >= 0 and clock >= float(flee_tick) / 60.0
	var walk_time := minf(clock,float(flee_tick) / 60.0) if fleeing else clock
	for lane in lanes:
		var height := (94.0 + (float(lane.y) - 400.0) * 0.52) * float(lane.scale)
		var x := fposmod(float(lane.origin) + walk_time * float(lane.speed) + 130.0,2700.0) - 130.0
		var speed := float(lane.speed)
		var distance := walk_time * absf(speed)
		if fleeing:
			var direction := -1.0 if x < float(state.get("civilian_flee_x",640)) else 1.0
			speed = direction * (125.0 if lane.kind == "elder" else (165.0 if lane.kind == "child" else 188.0))
			var run_time := clock - walk_time
			x += run_time * speed
			distance = run_time * absf(speed)
			if x < -160 or x > 2600: continue
		var stride := height * (1.32 if fleeing else 0.88)
		var count := 6 if _art.npc_frames.has(lane.kind) else 4
		people.append({"scenery_npc":true,"kind":lane.kind,"x":x,"y":lane.y,"height":height,"face":-1 if speed < 0 else 1,"frame":posmod(floori(distance / stride * count),count),"distance":distance,"stride":stride,"speed":speed,"mode":"run" if fleeing else "walk"})
	return people

func _draw_npc(person: Dictionary) -> void:
	var origin := Vector2(float(person.x) - camera_x,float(person.y))
	if origin.x < -130 or origin.x > 1410: return
	var height := float(person.height)
	var frame: Dictionary = _art.npc_frame(str(person.kind),int(person.frame) + (6 if person.mode == "run" else 0))
	if frame.is_empty():
		if _art.villager_frames.size() != 8: return
		frame = _art.villager_frames[int(person.frame) % 4 + (4 if person.mode == "run" else 0)]
	_draw_actor_shadow(origin,height,0,height * 0.22)
	_draw_art_frame(frame,origin,height,float(person.face),0,Color.WHITE,float(frame.body_height))

func _draw_prop(prop: Dictionary) -> void:
	var origin := Vector2(float(prop.x) - camera_x,float(prop.y))
	if origin.x < -240 or origin.x > 1520: return
	var damage := 2 if prop.get("broken",false) else (1 if float(prop.hp) < float(prop.max_hp) * 0.6 else 0)
	var frame: Dictionary = _art.prop_frame(str(prop.kind),damage)
	if frame.is_empty(): return
	var heights := {"stall":150.0,"cart":107.0,"jar":55.0,"basket":39.0,"crate":58.0}
	var height := float(heights.get(prop.kind,60))
	_draw_actor_shadow(origin,height,0,float(prop.get("width",60)) * 0.45)
	_draw_art_frame(frame,origin,height,1,0,Color.WHITE,float(frame.body_height))

func _draw_wet_zones() -> void:
	for zone in state.get("wet_zones",[]):
		var origin := Vector2(float(zone.x) - camera_x,float(zone.y))
		var edge := PackedVector2Array()
		for i in range(30):
			var angle := i * TAU / 30.0
			var noise := 0.85 + sin(i * 7.13) * 0.1
			edge.append(origin + Vector2(cos(angle) * float(zone.width) * 0.5,sin(angle) * float(zone.depth) * 0.5) * noise)
		draw_colored_polygon(edge,Color(0.23,0.34,0.36,0.30))
		for i in range(7):
			var center := origin + Vector2(sin(i * 3.7) * float(zone.width) * 0.29,cos(i * 2.1) * float(zone.depth) * 0.24)
			draw_line(center - Vector2(12 + i * 2,0),center + Vector2(15 + i * 2,0),Color(0.69,0.77,0.74,0.22),1.5)

func _draw_weather() -> void:
	if weather != 2:
		return
	var clock := _art_clock()
	for index in range(95):
		var rain_x := fposmod(index * 89.0 - clock * 155.0, 1360.0) - 40.0
		var rain_y := fposmod(index * 53.0 + clock * 420.0, 720.0)
		draw_line(Vector2(rain_x, rain_y), Vector2(rain_x - 7, rain_y + 21), Color(0.72, 0.85, 0.96, 0.22), 1)
	for index in range(44):
		var phase := fposmod(clock * 1.7 + index * 0.31, 1.0)
		var ripple := Vector2(float((index * 113) % 2500) - decor_offset("ripples",camera_x), 414.0 + (index * 47) % 204)
		if ripple.x < -20 or ripple.x > 1300: continue
		draw_set_transform(ripple, 0, Vector2(1, 0.28))
		draw_arc(Vector2.ZERO, 4 + phase * 12, 0, TAU, 18, Color(0.76, 0.87, 0.97, (1.0 - phase) * 0.28), 1)
	draw_set_transform(Vector2.ZERO)

func _draw_art_frame(frame: Dictionary, origin: Vector2, height: float, face: float = 1.0, rotation: float = 0.0, tint: Color = Color.WHITE, base_height: float = 0.0) -> void:
	if frame.has("layers"):
		for layer in frame.layers:
			_draw_art_frame(layer, origin, height, face, rotation, tint, base_height)
		return
	var region: Rect2 = frame.region
	var scale := height / (base_height if base_height > 0 else region.size.y)
	var size := region.size * scale
	var anchor: Vector2 = frame.get("anchor", Vector2(region.size.x * 0.5, region.size.y))
	draw_set_transform(origin, rotation, Vector2(face, 1))
	if frame.has("clip_polygon"):
		# Keep integer atlas contours intact; scaled near-collinear points can fail triangulation.
		draw_set_transform(origin - (anchor * Vector2(face,1) * scale).rotated(rotation),rotation,Vector2(face * scale,scale))
		var vertices := PackedVector2Array()
		var uvs := PackedVector2Array()
		for point in frame.clip_polygon:
			vertices.append(point)
			uvs.append((point + region.position) / frame.texture.get_size())
		draw_polygon(vertices,PackedColorArray([tint]),uvs,frame.texture)
	else:
		draw_texture_rect_region(frame.texture, Rect2(-anchor * scale, size), region, tint)
	draw_set_transform(Vector2.ZERO)

func _draw_art_fighter(fighter: Dictionary, origin: Vector2) -> bool:
	var hero := str(fighter.get("kind", ""))
	if not _art.heroes.has(hero) and not _art.has_animation(hero):
		return false
	var action := str(fighter.get("action", "idle"))
	var z := float(fighter.get("z", 0))
	var sample := _fighter_animation(fighter)
	var animated: bool = sample.source in ["v04", "v05", "v06", "v07", "v09", "v10", "v11", "v12", "v13", "v14", "v15", "v16"]
	var pose := ArtAssets.pose_for(action, z, state.get("phase", "") == "won")
	var progress := clampf(demo_progress, 0.0, 1.0)
	if art_demo and demo_pose >= 0:
		pose = 0 if demo_pose == 9 else clampi(demo_pose, 0, 8)
		if pose in [1, 2, 5, 7] and (progress < 0.15 or progress > 0.8):
			pose = 0
	elif not art_demo:
		var action_tick := int(fighter.get("action_tick", 0))
		if action == "light":
			pose = (4 if z > 1.0 else 0) if action_tick < 6 else (4 if z > 1.0 else 1)
		elif action in ["heavy", "charged"] and action_tick < 14:
			pose = 3
		elif action == "special" and action_tick < 26:
			pose = 3
		elif pose == 5:
			# shortcut: the throw cell includes a victim; use heavy until separate throw layers exist.
			pose = 2
	var frame: Dictionary = _art.animation_frame(hero, sample) if animated else _art.hero_frame(hero, pose)
	var height := (225.0 if hero == "oichi" else 240.0) if art_demo else (148.0 if hero == "oichi" else 155.0)
	var face := -1.0 if float(fighter.get("face", 1)) < 0 else 1.0
	var clock := _art_clock()
	var rotation := 0.0
	var down := action in ["down", "defeated", "dead"]
	if down and not art_demo and not _art.has_v06(hero) and sample.source not in ["v10","v11","v12","v13","v14","v15","v16"]:
		rotation = -1.3 * face
	elif action == "thrown" and sample.source not in ["v10","v11","v12","v13","v14","v15","v16"]:
		rotation = sin((30.0 - float(fighter.get("throw_ticks", 30))) * 0.13) * 0.55 * face
	var player_color := Color("82bbcf") if int(fighter.get("player_index", 0)) == 0 else Color("e7bd72")
	var contacts: Array[float] = []
	if animated and frame.get("planted", false):
		var planted_x := -float(ArtAssets.SUPPORT_OFFSET.get(hero,0.32)) * height * face
		contacts.append(planted_x)
		if sample.clip == "idle":
			contacts.append(-planted_x)
	elif sample.clip == "walk":
		for contact in frame.get("contacts", []):
			contacts.append(float(contact) * height / float(frame.body_height) * face)
	_draw_actor_shadow(origin, height, z, height * 0.49, height * 0.07 * face, contacts)
	draw_set_transform(origin, 0, Vector2(1, 0.28))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([origin + Vector2(-5, 12), origin + Vector2(5, 12), origin + Vector2(0, 6)]), player_color)
	draw_string(ThemeDB.fallback_font,origin + Vector2(-9,27),"%dP" % (int(fighter.get("player_index",0)) + 1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,player_color)
	var tint := Color.WHITE
	if int(fighter.get("invuln", 0)) > 0 and action != "special" and int(clock * 60) % 6 < 3:
		tint = Color(1.5, 1.5, 1.5, 0.72)
	_draw_hero_power(fighter, origin, height, sample, false)
	_draw_art_frame(frame, origin - Vector2(0, z), height, face, rotation, tint, float(frame.body_height))
	_draw_hero_power(fighter, origin, height, sample, true)
	_draw_status(fighter, origin, height)
	if int(fighter.get("poison", 0)) > 0:
		for bubble in range(3):
			draw_circle(origin + Vector2(-20 + bubble * 20, -z - 48 - fposmod(clock * 30 + bubble * 12, 60.0)), 3, Color("95b660"))
	return true

static func power_phase(clip: String, tick: float) -> Dictionary:
	var hit := 26.0 if clip == "special" else (28.0 if clip == "charged_slam" else (22.0 if clip == "charged_upper" else 14.0))
	var duration := float(FrameAnimation.Battle.SPECIAL_TICKS) if clip == "special" else (72.0 if clip == "charged_slam" else (56.0 if clip == "charged_upper" else (42.0 if clip == "ground_slam" else 36.0)))
	return {"guard": clip == "special" and tick >= 0 and tick < duration, "released": tick >= hit and tick < duration, "progress": clampf((tick - hit) / (duration - hit), 0.0, 1.0), "charge": clampf(tick / hit, 0.0, 1.0)}

static func charge_visual(ticks: float, height: float) -> Dictionary:
	var amount := clampf(ticks / 35.0, 0.0, 1.0)
	var growth := smoothstep(0.0, 1.0, amount)
	return {"amount": amount, "radius": lerpf(10.0, height * 0.8, growth), "glow": lerpf(3.0, height * 0.3, growth), "flame": lerpf(3.0, height * 0.34, growth), "width": lerpf(1.0, 6.0, growth)}

func _draw_charge(fighter: Dictionary, ground: Vector2, height: float, sample: Dictionary, front: bool) -> void:
	var power := charge_visual(float(sample.tick) if art_demo else float(fighter.get("charge",sample.tick)),height)
	var element := _hero_element(str(fighter.get("kind","")))
	var origin := ground - Vector2(0,float(fighter.get("z",0)))
	var face := float(fighter.get("face",1))
	if not front:
		_draw_dust(ground,power.radius * 0.8,power.amount,0.35)
		return
	var frame := _art.animation_frame(str(fighter.kind),sample)
	var hand: Vector2 = origin + frame.get("hand_offset",Vector2(0.32,-0.65) * float(frame.body_height)) * height / float(frame.body_height) * Vector2(face,1)
	for i in range(6):
		var point := hand + Vector2(face * (i - 2) * (3 + power.amount * 6),sin(i * 1.8) * 6)
		if element == "fire": _paint_flame(point,power.flame * (0.75 + i * 0.11),i,0.84)
		elif element == "ice": _paint_ice(point,Vector2(4 + power.amount * 8,8 + power.amount * 27),i,0.75)
		else:
			var direction := Vector2.from_angle(-PI + i * PI / 5)
			_paint_streak(point,direction,power.flame * 1.6,3 + power.amount * 3,_element_color(element),0.6)

func _draw_hero_power(fighter: Dictionary, ground: Vector2, height: float, sample: Dictionary, front: bool) -> void:
	var clip := str(sample.clip)
	if str(fighter.get("kind","")) in ["nobunaga","oichi"] or (clip == "dash_heavy" and sample.get("source","") != "v16"):
		_draw_strike_accent(fighter,ground,height,sample,front)
	if clip == "charge" or (fighter.get("kind","") == "oichi" and fighter.get("action","") == "charged" and float(sample.tick) < 14):
		if not (fighter.get("kind","") == "tadakatsu" and sample.get("source","") == "v16"):
			_draw_charge(fighter,ground,height,sample,front)
		return
	if clip == "special":
		_draw_special_aura(fighter,ground,height,front)
		return
	if not front or not sample.released: return
	if str(fighter.get("kind","")) in ["nobunaga","oichi"]: return
	if str(fighter.get("kind", "")) == "tadakatsu" and sample.get("source","") == "v16": return
	if clip in ["heavy","charged","rising","upper_heavy","charged_upper","ground_slam","charged_slam","low_sweep","dash_strike","air_light","air_heavy","mixed_finisher","mixed_rising","counter_cut"]:
		_draw_technique_trail(fighter,ground - Vector2(0,float(fighter.get("z",0))),height,sample)

static func strike_accent(fighter: Dictionary, sample: Dictionary) -> Dictionary:
	var hero := str(fighter.get("kind",""))
	if hero == "tadakatsu" and sample.get("source","") == "v16": return {}
	var action := str(fighter.get("action",sample.get("clip","idle")))
	var tick := float(sample.get("tick",0))
	var key := action
	if action == "light": key += str(fighter.get("combo",1))
	elif action == "heavy": key += str(fighter.get("heavy_combo",1))
	var hit: float = {"light":6,"heavy":14,"charged":14,"rising":6,"low_sweep":9,"upper_heavy":12,"charged_upper":22,"ground_slam":14,"charged_slam":28,"air_light":6,"air_heavy":12,"dash_strike":10,"dash_heavy":12,"counter_cut":5,"mixed_finisher":9,"mixed_rising":9}.get(action,-1)
	if action in ["mixed_finisher","mixed_rising"]:
		key = "light3" if tick < 22 else ("charged_upper" if action == "mixed_rising" else "charged_slam")
		if hero == "oichi" and tick < 22: key = "light2"
		if tick >= 22: hit = 27
	if action == "special":
		hit = -1
		for pulse in FrameAnimation.Battle.SPECIAL_HIT_TICKS[hero]:
			if tick >= pulse: hit = pulse
	if hit < 0 or tick < hit: return {}
	# radius, width, starting angle, sweep, vertical compression: each cut keeps its own path.
	var profiles := {
		"light1":[.59,3.0,-1.6,2.4,.8],"light2":[.64,3.5,.8,-2.6,.88],"light3":[.79,6.0,-2.6,3.8,.30],
		"heavy1":[.9,9.0,-2.05,3.0,1.0],"heavy2":[1.05,12.0,-2.8,4.2,.38],"charged":[1.2,14.0,-1.9,3.5,.8],
		"rising":[.68,4.0,.95,-2.5,1.0],"upper_heavy":[.88,9.0,1.1,-3.0,1.0],"charged_upper":[1.15,14.0,1.2,-3.3,1.0],
		"low_sweep":[.76,5.0,-2.5,3.7,.22],"ground_slam":[.87,10.0,-1.9,3.1,.95],"charged_slam":[1.18,16.0,-1.9,3.3,1.0],
		"air_light":[.69,5.0,-1.7,2.6,.9],"air_heavy":[1.0,12.0,-1.9,3.0,1.0],"dash_strike":[.72,4.0,-.7,1.3,.42],
		"counter_cut":[.73,6.0,.8,-2.5,.75],"special":[1.32,17.0,-2.5,4.3,.65],
		"dash_heavy":[1.15,15.0,-2.8,4.4,.30],
	}
	if not profiles.has(key): return {}
	var power := 2 if key in ["charged","charged_upper","charged_slam","special"] else (1 if key in ["heavy1","heavy2","air_heavy","ground_slam","upper_heavy","dash_heavy"] else 0)
	if power > 0 and hero != "oichi":
		profiles[key][0] *= 1.3
		profiles[key][1] *= 1.5
	var age := (tick - hit) / (8.0 + power * 3.0)
	if age >= 1: return {}
	return {"path":profiles[key],"age":age,"power":power,"key":key,"bow":hero == "oichi" and key not in ["light3","dash_heavy"],"thrust":key == "dash_heavy" and hero in ["hideyoshi","tadakatsu"],"low":key in ["low_sweep","ground_slam","charged_slam"],"shock":key in ["heavy2","charged","ground_slam","charged_slam","special","dash_heavy"]}

func _draw_strike_accent(fighter: Dictionary, ground: Vector2, height: float, sample: Dictionary, front: bool) -> void:
	if fighter.get("kind","") == "nobunaga" and sample.get("source","") == "v13" and fighter.get("action","") == "light":
		if not front or int(sample.frame) == 0: return
		var previous := sample.duplicate()
		previous.frame = int(sample.frame) - 1
		previous.cell = previous.frame
		var current_frame := _art.animation_frame("nobunaga",sample)
		var previous_frame := _art.animation_frame("nobunaga",previous)
		if current_frame.has("blade_offsets") and previous_frame.has("blade_offsets"):
			var now: Array = current_frame.blade_offsets
			var before: Array = previous_frame.blade_offsets
			var now_scale := height / float(current_frame.body_height)
			var before_scale := height / float(previous_frame.body_height)
			var trail := PackedVector2Array([before[0].lerp(before[1],.6) * before_scale,before[1] * before_scale,now[1] * now_scale,now[0].lerp(now[1],.6) * now_scale])
			var fade := clampf((14.0 - float(sample.tick)) / 3.0,0,1)
			draw_set_transform(ground - Vector2(0,float(fighter.get("z",0))),0,Vector2(float(fighter.get("face",1)),1))
			draw_colored_polygon(Geometry2D.convex_hull(trail),Color(1,.93,.74,.38 * fade))
			draw_set_transform(Vector2.ZERO)
		return
	var style := strike_accent(fighter,sample)
	if style.is_empty(): return
	var age: float = style.age
	var face := float(fighter.get("face",1))
	var origin := ground - Vector2(0,float(fighter.get("z",0)))
	var fade := (1.0 - age) * .82
	var color := Color("ffcd82") if style.power > 0 else Color("f3edda")
	if fighter.kind == "oichi": color = Color("b9edf2")
	if not front:
		if style.shock and float(fighter.get("z",0)) <= 2 and not (fighter.kind == "oichi" and style.key == "charged_slam"):
			var radius: float = height * (.35 + style.power * .16 + age * .95)
			_draw_dust(ground,radius,age,fade * .55)
			draw_set_transform(ground,0,Vector2(1,.24))
			draw_arc(Vector2.ZERO,radius,0,TAU,40,Color(color,fade * .60),2 + style.power * 1.5,true)
			draw_set_transform(Vector2.ZERO)
		return
	if style.thrust:
		_paint_streak(origin + Vector2(face * height * (.55 + age * .9),-height * .57),Vector2(face,0),height * .65,9,color,fade)
		return
	if style.bow:
		if fighter.get("action","") == "charged_slam" and float(sample.tick) < 28: return
		var frame := _art.animation_frame(str(fighter.kind),sample)
		var hand: Vector2 = frame.get("hand_offset",Vector2(.38,-.67) * frame.body_height) * height / float(frame.body_height)
		var direction := Vector2(1,-.65 if style.key in ["rising","upper_heavy","charged_upper"] else (.65 if style.key == "air_heavy" else 0)).normalized()
		draw_set_transform(origin,0,Vector2(face,1))
		for i in range(1 + style.power):
			_paint_streak(hand + Vector2(8 + age * 32,(i - style.power * .5) * 12),direction,18 + style.power * 16,2 + style.power,color,fade)
		draw_set_transform(Vector2.ZERO)
		return
	var path: Array = style.path
	var radius: float = height * path[0]
	var center := origin + Vector2(face * 9,-height * (.16 if style.low else .57))
	var head: float = path[2] + path[3] * (.85 + .15 * age)
	var tail: float = head - path[3] * (.38 + .18 * sin(age * PI))
	var ribbon := PackedVector2Array()
	for side in [1,-1]:
		for i in range(25):
			var t := float(i if side == 1 else 24 - i) / 24
			var angle := lerpf(tail,head,t)
			var r: float = radius + side * path[1] * sin(t * PI) * .5
			ribbon.append(Vector2(cos(angle) * r,sin(angle) * r * path[4]))
	draw_set_transform(center,0,Vector2(face,1))
	draw_colored_polygon(ribbon,Color(color,fade))
	draw_set_transform(Vector2.ZERO)
	if fighter.kind == "nobunaga" and style.power > 0:
		for i in range(7):
			var angle := lerpf(tail,head,float(i) / 6.0)
			var point := center + Vector2(face * cos(angle) * radius,sin(angle) * radius * path[4])
			_paint_flame(point,16 + style.power * 12,i,fade * .72)

func _draw_special_aura(fighter: Dictionary, ground: Vector2, height: float, front: bool) -> void:
	var tick := float(fighter.get("action_tick",0))
	var element := _hero_element(str(fighter.get("kind","")))
	var fade := clampf(minf(tick / 18.0,(FrameAnimation.Battle.SPECIAL_TICKS - tick) / 16.0),0,1)
	var phase := fposmod(maxf(0,tick - 14),42.0) / 42.0
	var extent := height * (0.5 + phase * 2.5)
	if not front:
		_draw_dust(ground,extent,phase,fade * 0.55)
		return
	for i in range(14):
		var age := fposmod(floor(tick / 5) * 0.12 + i * 0.19,1)
		var side := -1.0 if i % 2 == 0 else 1.0
		var base := ground + Vector2(side * height * (0.22 + age * 1.9),sin(i * 2.1) * 25 - age * height * 0.58)
		var alpha := fade * (1.0 - age) * 0.8
		if element == "fire": _paint_flame(base,height * (0.32 + (i % 3) * 0.18),i,alpha)
		elif element == "ice": _paint_ice(base,Vector2(14 + i % 3 * 6,height * (0.32 + (i % 4) * 0.16)),i,alpha)
		elif element == "earth": _paint_ice(base,Vector2(22,35 + i % 3 * 17),i,alpha,Color("aa8958"))
		else: _paint_streak(base,Vector2(side,-0.18),height * 0.95,13,_element_color(element),alpha)

func _draw_technique_trail(fighter: Dictionary, origin: Vector2, height: float, sample: Dictionary) -> void:
	var action := str(fighter.get("action",sample.clip))
	var tick := float(sample.tick)
	var hit: float = {"rising":6,"upper_heavy":12,"charged_upper":22,"charged_slam":28,"ground_slam":14,"low_sweep":9,"dash_strike":10,"air_light":6,"air_heavy":12,"mixed_finisher":9,"mixed_rising":9}.get(action,14)
	var age := clampf((tick - hit) / maxf(1,float(sample.duration) - hit),0,1)
	var face := float(fighter.get("face",1))
	var element := _hero_element(str(fighter.kind))
	var low := action in ["low_sweep","ground_slam","charged_slam"]
	var charged := action in ["charged","charged_upper","charged_slam"]
	var radius := height * (1.26 if charged else 0.72)
	var center := origin + Vector2(face * 12,-height * (0.12 if low else 0.58))
	for i in range(7 if charged else 4):
		var angle := -1.6 + i * 0.42 + age * 1.2
		if action in ["rising","upper_heavy","charged_upper"]: angle = 0.8 - i * 0.38 - age
		var direction := Vector2(face * cos(angle),sin(angle) * (0.28 if low else 0.8))
		var point := center + direction * radius
		var alpha := (1.0 - age) * 0.7
		if element == "fire": _paint_flame(point,22 + (18 if charged else 0),i,alpha)
		elif element == "ice" and charged: _paint_ice(point,Vector2(10,34),i,alpha)
		else: _paint_streak(point,direction.orthogonal(),24 + (32 if charged else 0),4 + (5 if charged else 0),_element_color(element),alpha)

static func _hero_element(hero: String) -> String:
	return {"nobunaga":"fire","oichi":"ice","hideyoshi":"wind","ieyasu":"earth","mitsuhide":"blade","tadakatsu":"fire"}.get(hero,"blade")

static func _element_color(element: String) -> Color:
	return {"fire":Color("d97032"),"ice":Color("a2cbd0"),"earth":Color("b49969"),"wind":Color("c3c9ac"),"blade":Color("e0dfcb")}.get(element,PAPER)

func _paint_flame(base: Vector2, height: float, seed: int, opacity: float) -> void:
	if height < 1.0 or opacity <= 0.005: return
	var phase := floorf(_art_clock() * 12) * 0.71 + seed * 2.1
	var width := height * 0.31
	# Rounded, asymmetrical tongues retain painted color masses without a luminous rim.
	var shape := PackedVector2Array()
	for side in [-1,1]:
		for step in range(13):
			if side == 1 and step == 0: continue
			var t := float(step if side == -1 else 12 - step) / 12.0
			var bend := sin(t * 4.1 + phase) * width * t * 0.52
			var envelope := pow(1.0 - t,0.72) * (0.72 + sin(t * PI) * 0.35)
			var ripple := 1.0 + sin(t * 16.0 + phase) * 0.11 * sin(t * PI)
			shape.append(base + Vector2(bend + side * width * envelope * ripple,-height * t))
	draw_colored_polygon(shape,Color(0.68,0.23,0.10,opacity))
	for i in range(shape.size()): shape[i] = base + (shape[i] - base) * Vector2(0.76,0.82)
	draw_colored_polygon(shape,Color(0.96,0.43,0.12,opacity))
	for i in range(shape.size()): shape[i] = base + (shape[i] - base) * Vector2(0.58,0.63)
	draw_colored_polygon(shape,Color(1,0.78,0.31,opacity))

func _paint_ice(base: Vector2, size: Vector2, seed: int, opacity: float, color: Color = Color("a4d1da")) -> void:
	if size.x < 1.0 or size.y < 1.0 or opacity <= 0.005: return
	var bend := sin(seed * 2.3) * size.x * 0.38
	var points := PackedVector2Array([base + Vector2(-size.x * 0.6,2),base + Vector2(-size.x,-size.y * 0.4),base + Vector2(bend,-size.y),base + Vector2(size.x * 0.72,-size.y * 0.55),base + Vector2(size.x * 0.85,0)])
	draw_colored_polygon(points,Color(color.darkened(0.2),opacity))
	draw_colored_polygon(PackedVector2Array([points[0],points[2],base + Vector2(size.x * 0.05,0)]),Color(color.lightened(0.22),opacity * 0.84))
	draw_line(points[1],points[2],Color(color.lightened(0.38),opacity),1.5)

func _paint_streak(base: Vector2, direction: Vector2, length: float, width: float, color: Color, opacity: float) -> void:
	var side := direction.orthogonal().normalized() * width
	var vector := direction.normalized() * length
	draw_colored_polygon(PackedVector2Array([base - vector,base - vector * 0.28 + side,base + vector * 0.65,base - vector * 0.12 - side * 0.4]),Color(color,opacity))

func _draw_dust(base: Vector2, radius: float, age: float, opacity: float) -> void:
	for i in range(11):
		var angle := i * TAU / 11.0
		var point := base + Vector2(cos(angle) * radius,sin(angle) * radius * 0.24 - sin(age * PI) * 12)
		var size := Vector2(9 + i % 3 * 5,5 + i % 4 * 2) * (0.65 + age * 0.8)
		_ellipse(point,size,Color(0.66,0.58,0.44,opacity * (0.7 + (i % 3) * 0.1)))
		for dot in range(3): draw_circle(point + Vector2(dot * 5 - 4,-dot * 3),1.0,Color(0.31,0.29,0.23,opacity * 0.35))

func _draw_status(fighter: Dictionary, ground: Vector2, height: float) -> void:
	var origin := ground - Vector2(0, float(fighter.get("z", 0)))
	var clock := _art_clock()
	if int(fighter.get("burn",0)) > 0:
		for i in range(9):
			var age := fposmod(floor(clock * 12) * 0.12 + i * 0.17,1)
			var base := origin + Vector2(sin(i * 2.4) * height * 0.22,-height * (0.05 + age * 0.78))
			_paint_flame(base,height * (0.18 + i % 3 * 0.05),i,0.85 * (1.0 - age))
	if int(fighter.get("freeze",0)) > 0:
		# Separate irregular facets follow the body instead of enclosing it in a rectangular ward.
		for i in range(9):
			var base := origin + Vector2(sin(i * 2.4) * height * 0.22,-height * (0.03 + (i % 4) * 0.19))
			_paint_ice(base,Vector2(height * (0.1 + (i % 3) * 0.03),height * (0.33 + (i % 2) * 0.14)),i,0.48)
	if fighter.get("action", "") == "stunned" or int(fighter.get("stun", 0)) > 0:
		_draw_stun(origin - Vector2(0, height * 1.06), float(state.get("tick", 0)))

func _draw_enemy_art(fighter: Dictionary, origin: Vector2) -> bool:
	var kind := str(fighter.get("kind", ""))
	if not _art.enemies.has(kind): return false
	if shattered_defeat(fighter): return true
	var sample := _fighter_animation(fighter)
	var genuine_reaction: bool = sample.sheet == "enemy_reaction" or sample.source == "v14"
	var frame: Dictionary = _art.enemy_frame(kind,int(sample.cell),str(fighter.get("faction","mori")),str(sample.sheet))
	if sample.source != "v14" and kind == "boss" and fighter.get("faction","mori") == "mori" and fighter.get("action", "") == "boss_chain" and int(sample.cell) == 6 and frame.has("hand_offset") and frame.has("clip_polygon"):
		# The live chain replaces the atlas's short demonstration weight beyond the casting hand.
		var cutoff: float = frame.anchor.x + frame.hand_offset.x + 6.0
		var crop := PackedVector2Array([Vector2.ZERO,Vector2(cutoff,0),Vector2(cutoff,frame.region.size.y),Vector2(0,frame.region.size.y)])
		var clipped := Geometry2D.intersect_polygons(frame.clip_polygon,crop)
		if not clipped.is_empty():
			frame = frame.duplicate()
			frame.clip_polygon = clipped[0]
	var height := 163.0 if kind == "boss" else (158.0 if kind == "commander" else 146.0)
	var action := str(fighter.get("action", "idle"))
	var face := float(fighter.get("face", 1))
	var z := float(fighter.get("z", 0))
	var down := action in ["down", "dead", "defeated", "thrown", "launched"]
	var rotation := -1.25 * face if down else (-0.13 * face if action in ["hurt", "grabbed", "pulled"] else 0.0)
	if action in ["thrown","launched"]: rotation = clampf(float(fighter.get("vz",0)) * -0.09 - 1.1,-1.9,-0.3) * face
	elif action == "recovering": rotation = -1.25 * face * (1.0 - clampf(float(fighter.get("action_tick",0)) / 36.0,0,1))
	elif action == "stunned": rotation = sin(float(fighter.get("action_tick",0)) * 0.14) * 0.16
	if genuine_reaction: rotation = 0.0
	var tint := Color(0.67,0.86,1) if int(fighter.get("freeze",0)) > 0 else Color.WHITE
	if int(fighter.get("invuln",0)) > 0 and int(state.get("tick",0)) % 6 < 3: tint = Color(1.35,1.12,1.05,0.85)
	_draw_actor_shadow(origin, height, z, height * 0.29, 0, [-height * 0.36, height * 0.27] if frame.get("planted", false) else [-height * 0.18, height * 0.18])
	var body_origin := origin - Vector2(0, z)
	if down and not genuine_reaction: body_origin += Vector2(face * height * 0.33, -height * 0.09)
	_draw_art_frame(frame, body_origin, height, face, rotation, tint, float(frame.body_height))
	_draw_status(fighter, origin, height)
	if FrameAnimation.Battle.ENEMY_TIMING.has(action) and not sample.released and int(fighter.get("freeze",0)) == 0:
		var warning := origin - Vector2(0,z + height + 16)
		draw_line(warning - Vector2(0,10), warning, GOLD, 3)
		draw_circle(warning + Vector2(0,5), 2, GOLD)
	if float(fighter.get("hp",0)) > 0:
		var bar := origin - Vector2(27, z + height + 6)
		draw_rect(Rect2(bar,Vector2(54,9)),INK)
		draw_rect(Rect2(bar,Vector2(54 * clampf(float(fighter.hp) / maxf(1,float(fighter.get("max_hp",100))),0,1),9)),RED)
	return true

static func shattered_defeat(fighter: Dictionary) -> bool:
	return float(fighter.get("hp", 0)) <= 0 and int(fighter.get("shattered_tick", -1)) >= 0 and int(fighter.shattered_tick) == int(fighter.get("damage_tick", -2))

func _demo_projectile_sample(fighter: Dictionary, clip: String, release: float) -> Dictionary:
	# Read the launch pose independently of the showcase's later idle hold.
	var launch := fighter.duplicate()
	launch.action = "air_light" if clip == "jump" else clip
	launch.action_tick = release
	var hd := FrameAnimation.hero_v12_sample(launch,0,225,_art.animations.get("oichi",{}))
	if not hd.is_empty():
		hd.frame = 6
		hd.cell = 6
		return hd
	if clip == "light": return FrameAnimation.combo_sample(maxi(1,int(fighter.get("combo",1))),release)
	if clip == "heavy" and _art.has_v06("oichi"): return FrameAnimation.bow_sample("heavy",release,int(fighter.get("heavy_combo",1)))
	return FrameAnimation.sample(clip,release)

func _draw_demo_projectiles() -> void:
	if not art_demo or demo_pose not in [1, 2, 4, 7] or not _art.has_animation("oichi"):
		return
	var clip: String = FrameAnimation.POSE_CLIPS[demo_pose]
	var tick := (demo_progress * FrameAnimation.DEMO_SECONDS - FrameAnimation.DEMO_HOLD) * 60.0 * FrameAnimation.DEMO_SPEED
	var release := 16.0 if clip == "jump" else float(FrameAnimation.CLIPS[clip].get("hit", 0))
	var bow := _art.has_v06("oichi") and clip in ["heavy", "special"]
	var bursts := 3 if clip == "special" and not bow else 1
	for fighter in state.get("fighters", []):
		if fighter.get("kind", "") != "oichi":
			continue
		var face := -1.0 if float(fighter.get("face", 1)) < 0 else 1.0
		var launch_z := 74.6 if clip == "jump" else 0.0
		var release_sample := _demo_projectile_sample(fighter,clip,release)
		var hand_offset: Vector2 = _art.projectile_origin(release_sample, 225.0)
		var hand := Vector2(float(fighter.get("x", 0)) - camera_x, float(fighter.get("y", 585)) - launch_z) + hand_offset * Vector2(face, 1)
		for burst in range(bursts):
			var age := tick - release - burst * 4.0
			if age < 0 or age > 34:
				continue
			if bow:
				for lane in ([-1,0,1] if clip == "special" else [0]):
					var position_now := hand + Vector2(face * age * (30 if clip == "special" else 23), float(lane) * minf(60, age * 8))
					_draw_arrow(position_now, Vector2(face, 0), clip == "special", minf(1.0, (34.0 - age) / 6.0))
				continue
			var needle_count := 7 if clip == "special" else 3
			for needle in range(needle_count):
				var spread := (needle - (needle_count - 1) * 0.5) * (0.11 if clip == "special" else 0.065)
				var direction := Vector2(face * cos(spread), sin(spread))
				var position_now := hand + direction * age * (14.0 + burst)
				_draw_needle(position_now, direction, clip in ["heavy", "special"], minf(1.0, (34.0 - age) / 8.0))

func _draw_needle(position_now: Vector2, direction: Vector2, poison: bool, opacity: float = 1.0) -> void:
	var color := Color("a8f07e") if poison else Color("e4f2ff")
	color.a = opacity
	draw_line(position_now - direction * 35, position_now - direction * 8, Color(color, opacity * 0.24), 5)
	draw_line(position_now - direction * 21, position_now + direction * 5, color, 2)
	var side := direction.orthogonal() * 3.5
	draw_colored_polygon(PackedVector2Array([position_now + direction * 10, position_now + side, position_now - side]), Color(1, 1, 0.91, opacity))

static func projectile_style(weapon: String) -> Dictionary:
	return {"arrow": weapon in ["arrow", "special_arrow"], "bullet": weapon in ["bullet", "gun", "matchlock"], "blade":weapon == "blade", "powered": weapon == "special_arrow", "shaft": 92.0 if weapon == "special_arrow" else 56.0, "trail": 185.0 if weapon == "special_arrow" else 86.0}

func _projectile_key(effect: Dictionary) -> String:
	var age := int(effect.get("max_life", effect.get("life", 0))) - int(effect.get("life", 0))
	return "%s:%s:%s" % [effect.get("owner",0), int(state.get("tick",0)) - age, effect.get("weapon","needle")]

func _projectile_release_offset(effect: Dictionary) -> Vector2:
	var key := _projectile_key(effect)
	if not _projectile_origins.has(key):
		_projectile_origins[key] = _projectile_offset(effect)
	return _projectile_origins[key]

func _projectile_offset(effect: Dictionary) -> Vector2:
	if int(effect.get("team",0)) == 1:
		for fighter in state.get("fighters",[]):
			if fighter.get("id",0) != effect.get("owner",0) or not _art.enemies.has(str(fighter.get("kind",""))): continue
			var release_fighter: Dictionary = fighter.duplicate()
			release_fighter.action = effect.get("action",fighter.get("action","idle"))
			release_fighter.action_tick = effect.get("action_tick",fighter.get("action_tick",0))
			release_fighter.freeze = 0
			var owner_id := int(fighter.id)
			var had_frozen_sample := _frozen_samples.has(owner_id)
			var frozen_sample: Dictionary = _frozen_samples.get(owner_id,{})
			var sample := _fighter_animation(release_fighter)
			if had_frozen_sample: _frozen_samples[owner_id] = frozen_sample
			else: _frozen_samples.erase(owner_id)
			var frame := _art.enemy_frame(str(fighter.kind),int(sample.cell),str(fighter.get("faction","mori")),str(sample.sheet))
			if frame.has("hand_offset"):
				var hand: Vector2 = frame.hand_offset * (163.0 if fighter.kind == "boss" else 146.0) / float(frame.body_height)
				return Vector2((hand.x - 40.0) * float(effect.get("face",1)), hand.y + (float(effect.get("start_z",40)) if effect.get("arcing",false) else 70.0))
		return Vector2.ZERO
	if not _art.has_v06("oichi"):
		return Vector2.ZERO
	for fighter in state.get("fighters", []):
		if fighter.get("id",0) != effect.get("owner",0) or fighter.get("kind","") != "oichi": continue
		var weapon := str(effect.get("weapon","needle"))
		var sample := FrameAnimation.combo_sample(maxi(1,int(fighter.get("combo",1))),6)
		if _art.has_v10("oichi") and fighter.get("action","") == "light":
			var release_fighter: Dictionary = fighter.duplicate()
			release_fighter.action_tick = 6
			sample = FrameAnimation.hero_v10_sample(release_fighter)
		elif _art.has_techniques("oichi") and fighter.get("action","") in ["rising", "ground_slam", "charged_slam", "low_sweep", "dash_strike", "air_light", "air_heavy", "upper_heavy", "charged_upper", "mixed_finisher", "mixed_rising"]:
			sample = FrameAnimation.technique_sample(str(fighter.action),float(fighter.get("action_tick",0)))
		else:
			if effect.get("rising", false): sample = FrameAnimation.directional_sample("rising",6)
			if weapon == "special_arrow": sample = FrameAnimation.sample("special",26)
			elif weapon == "arrow": sample = FrameAnimation.bow_sample("charged" if effect.get("charged",false) else "heavy",14,maxi(1,int(fighter.get("heavy_combo",1))))
		if _art.v11_counts.has("oichi-combat"):
			var release_fighter: Dictionary = fighter.duplicate()
			release_fighter.action = effect.get("action",fighter.get("action","light"))
			for field in ["action_tick","combo","heavy_combo"]:
				release_fighter[field] = effect.get(field,fighter.get(field,0 if field == "action_tick" else 1))
			sample = _fighter_animation(release_fighter)
			if sample.source in ["v12","v13","v14"]:
				sample.frame = 6
				sample.cell = 6
		var hand: Vector2 = _art.projectile_origin(sample,148.0)
		return Vector2((hand.x - 105.0) * float(effect.get("face",1)), hand.y + 124.0)
	return Vector2.ZERO

func _draw_arrow(position_now: Vector2, direction: Vector2, powered: bool, opacity: float = 1.0) -> void:
	var side := direction.orthogonal()
	var length := 64.0 if powered else 46.0
	var tail := position_now - direction * length
	draw_line(tail,position_now,Color(0.31,0.23,0.15,opacity),3,true)
	draw_line(tail + side,position_now + side,Color(0.74,0.60,0.37,opacity),1,true)
	draw_colored_polygon(PackedVector2Array([position_now + direction * 12,position_now - direction * 4 + side * 5,position_now - direction * 1,position_now - direction * 4 - side * 5]),Color(0.76,0.81,0.79,opacity))
	for offset in [0,7,14]:
		var point: Vector2 = tail + direction * offset
		draw_line(point,point - direction * 6 + side * 5,Color(PAPER,opacity),2)
		draw_line(point,point - direction * 6 - side * 5,Color(PAPER,opacity),2)

static func arc_projectile_position(effect: Dictionary, camera: float, release_offset: Vector2) -> Vector2:
	var progress := clampf(float(effect.get("flight_tick",0)) / maxf(1,float(effect.get("flight_ticks",1))),0,1)
	return Vector2(float(effect.x) - camera,float(effect.y) - float(effect.get("z",0))) + release_offset * (1.0 - progress)

static func projectile_direction(effect: Dictionary, release_offset: Vector2 = Vector2.ZERO) -> Vector2:
	var velocity := Vector2(float(effect.get("vx",effect.get("face",1))),float(effect.get("vy",0)) - float(effect.get("vz",0)))
	if effect.get("arcing",false): velocity -= release_offset / maxf(1,float(effect.get("flight_ticks",1)))
	return velocity.normalized() if velocity.length_squared() > 0.01 else Vector2(float(effect.get("face",1)),0)

func _draw_gate(x: float) -> void:
	if x < -280 or x > 1560:
		return
	draw_line(Vector2(x - 84, 387), Vector2(x - 84, 229), Color("483c31"), 22)
	draw_line(Vector2(x + 84, 387), Vector2(x + 84, 229), Color("483c31"), 22)
	draw_line(Vector2(x - 117, 260), Vector2(x + 117, 260), Color("483c31"), 20)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 148, 237), Vector2(x - 118, 211), Vector2(x + 118, 211), Vector2(x + 148, 237)]), INK)
	for side in [-1, 1]:
		draw_rect(Rect2(x + side * 84 - 21, 269, 42, 62), Color("ad974f"))
		draw_circle(Vector2(x + side * 84, 292), 11, Color("313c31"))
		draw_line(Vector2(x + side * 84, 282), Vector2(x + side * 84, 302), GOLD, 3)

func _draw_drop(drop: Dictionary) -> void:
	var p := Vector2(float(drop.get("x", 0)) - camera_x, float(drop.get("y", 450)))
	var kind := str(drop.get("kind", drop.get("type", "food")))
	_ellipse(p, Vector2(19, 6), Color(0.12, 0.17, 0.13, 0.35))
	draw_arc(p + Vector2(0, -8), 22, PI, TAU, 18, Color(0.89, 0.76, 0.37, 0.45), 2)
	if kind in ["weapon", "sword", "spear"]:
		draw_line(p + Vector2(-17, -8), p + Vector2(21, -22), PAPER, 4)
		draw_line(p + Vector2(-12, -15), p + Vector2(-6, -2), GOLD, 3)
	elif kind in ["armor", "armour"]:
		_shape([p + Vector2(-13, -23), p + Vector2(13, -23), p + Vector2(16, -3), p + Vector2(-16, -3)], Color("78939c"))
	else:
		_shape([p + Vector2(-15, -4), p + Vector2(0, -25), p + Vector2(15, -4)], PAPER)
		draw_rect(Rect2(p + Vector2(-5, -11), Vector2(10, 9)), Color("304737"))

func _draw_fighter(fighter: Dictionary) -> void:
	var hp := float(fighter.get("hp", 1))
	var action := str(fighter.get("action", "idle"))
	if hp <= 0 and action not in ["down", "dead", "defeat", "defeated"]:
		return
	var origin := Vector2(float(fighter.get("x", 0)) - camera_x, float(fighter.get("y", 470)))
	if origin.x < -180 or origin.x > 1460:
		return
	var team := int(fighter.get("team", 0))
	var kind := str(fighter.get("kind", "soldier"))
	if kind == "dummy":
		_draw_dummy(fighter, origin)
		_draw_status(fighter, origin, 138.0)
		return
	if team == 0 and _draw_art_fighter(fighter, origin):
		return
	if team != 0 and _draw_enemy_art(fighter, origin):
		return
	var female := kind == "oichi"
	var boss := kind == "boss"
	var archer := kind == "archer"
	var facing_back: bool = _facing_back.get(int(fighter.get("id", -1)), false)
	var size := 1.38 if boss else (0.94 if female else 1.0)
	var face := -1.0 if float(fighter.get("face", 1)) < 0 else 1.0
	var tick := float(state.get("tick", 0))
	var action_tick := float(fighter.get("action_tick", 0))
	var jumping := float(fighter.get("z", 0))
	var walking: bool = action in ["walk", "run", "move"] or (action == "idle" and _moving.get(int(fighter.get("id", -1)), false))
	var attacking := action in ["attack", "light", "light_attack", "heavy", "heavy_attack", "charged", "special", "throw", "grab_attack", "air_attack", "jump_attack"]
	var heavy := action in ["heavy", "heavy_attack", "charged", "special"]
	var shield_hurt := int(fighter.get("shield_hurt_tick", 0)) > 0
	var grabbed := action == "grabbed" or int(fighter.get("held_by", 0)) != 0
	var hurt := action in ["hurt", "hit", "stagger"] or shield_hurt
	var down := action in ["down", "dead", "defeat", "defeated", "thrown"]
	var windup := action == "windup" and action_tick < (58 if boss else (30 if archer else 35))
	var striking := attacking and action_tick >= (26 if action == "special" else (14 if heavy else 6))
	var stride := sin(tick * 0.3) * 12.0 if walking else 2.0
	var breath := sin(tick * 0.07) * 1.5 if not attacking and not grabbed else 0.0
	var flash := int(fighter.get("invuln", 0)) > 0 and int(tick) % 6 < 3
	var cloth := Color("633e42") if female else (Color("493d32") if boss else Color("384750"))
	var armor := Color("9d4d43") if team == 0 else Color("697776")
	if female:
		armor = Color("ad716d")
	if boss:
		armor = Color("706443")
	elif archer:
		armor = Color("847855")
	if flash or shield_hurt:
		armor = PAPER
	var skin := Color("d5b391") if female else Color("ba9476")
	var player_color := Color("82bbcf") if int(fighter.get("player_index", 0)) == 0 else Color("e7bd72")
	_draw_actor_shadow(origin, 116.0 * size, jumping, 28.0 * size, 6.0 * size * face, [(-9.0 - stride) * size * face, (21.0 + stride) * size * face])
	if team == 0:
		draw_arc(origin + Vector2(0, -1), 28 * size, 0, PI, 22, player_color, 3)
		if int(fighter.get("player_index", 0)) == local_slot:
			draw_colored_polygon(PackedVector2Array([origin + Vector2(-5, 11), origin + Vector2(5, 11), origin + Vector2(0, 5)]), player_color)
	var rotation := -1.4 * face if down else (0.14 * -face if hurt else 0.0)
	if action == "thrown": rotation = -(0.65 + (30.0 - float(fighter.get("throw_ticks", 30))) * 0.065) * face
	elif grabbed: rotation = -0.12 * face + sin(tick * 0.8) * (0.07 if shield_hurt else 0.0)
	draw_set_transform(origin - Vector2(0, jumping + breath), rotation, Vector2(face * size, size))
	if female:
		_shape([Vector2(-10, -89), Vector2(-29, -75), Vector2(-27, -29), Vector2(-13, -43), Vector2(0, -80)], Color("262b32"))
	_limb(Vector2(-8, -38), Vector2(-14 - stride, -7), 13 if not female else 9, cloth)
	_limb(Vector2(9, -37), Vector2(16 + stride, -7), 14 if not female else 9, cloth)
	_limb(Vector2(-15 - stride, -6), Vector2(-4 - stride, -5), 7, INK)
	_limb(Vector2(15 + stride, -6), Vector2(27 + stride, -5), 7, INK)
	var back_hand := Vector2(-25 - stride * 0.2, -49) if not grabbed else Vector2(-28, -80)
	_limb(Vector2(-13, -70), back_hand, 12, cloth)
	draw_circle(back_hand, 5, skin)
	if female:
		_shape([Vector2(-14, -76), Vector2(14, -74), Vector2(11, -51), Vector2(22, -22), Vector2(-23, -22), Vector2(-11, -52)], cloth)
		_shape([Vector2(-13, -75), Vector2(3, -69), Vector2(-5, -49), Vector2(-14, -52)], armor)
		_shape([Vector2(11, -74), Vector2(-4, -56), Vector2(12, -52), Vector2(16, -68)], Color("d0bba7"))
		draw_line(Vector2(-14, -49), Vector2(15, -49), GOLD, 7)
		draw_line(Vector2(0, -44), Vector2(6, -24), armor, 3)
	else:
		_shape([Vector2(-18, -76), Vector2(17, -76), Vector2(20, -43), Vector2(-20, -43)], armor)
		for plate in range(4):
			draw_line(Vector2(-17, -69 + plate * 7), Vector2(18, -69 + plate * 7), GOLD.darkened(0.25), 2)
		_shape([Vector2(-19, -44), Vector2(20, -44), Vector2(27, -23), Vector2(2, -27), Vector2(-25, -23)], armor.darkened(0.18))
		draw_line(Vector2(-17, -45), Vector2(18, -45), INK, 6)
		draw_rect(Rect2(-27, -78, 17, 17), armor.darkened(0.2))
		draw_rect(Rect2(12, -78, 16, 17), armor.darkened(0.2))
	if int(fighter.get("armor", 0)) > 0:
		draw_line(Vector2(-12, -72), Vector2(12, -51), Color("a8c4c5"), 5)
		draw_circle(Vector2(0, -61), 5, GOLD)
	_limb(Vector2(0, -82), Vector2(0, -75), 10, skin)
	_ellipse(Vector2(0, -91), Vector2(12 if female else 14, 15), skin)
	if female:
		_shape([Vector2(-12, -94), Vector2(-13, -105), Vector2(2, -110), Vector2(13, -101), Vector2(11, -92), Vector2(3, -101), Vector2(-4, -95)], Color("202a31"))
		draw_line(Vector2(-13, -101), Vector2(2, -105), RED, 4)
		draw_line(Vector2(-19, -106), Vector2(-4, -99), GOLD, 2)
	else:
		_shape([Vector2(-17, -90), Vector2(-17, -105), Vector2(-6, -116), Vector2(9, -113), Vector2(18, -99), Vector2(18, -91)], armor.darkened(0.24))
		draw_line(Vector2(-21, -92), Vector2(22, -92), INK, 5)
		if kind in ["nobunaga", "boss"]:
			draw_arc(Vector2(0, -111), 15, -PI * 0.9, -PI * 0.1, 15, GOLD, 4)
			draw_line(Vector2(-7, -79), Vector2(6, -77), INK, 4)
	if facing_back:
		_ellipse(Vector2(-1, -91), Vector2(11, 13), Color("202a31") if female else armor.darkened(0.25))
		if female:
			draw_line(Vector2(-8, -90), Vector2(-3, -58), Color("202a31"), 13)
			draw_line(Vector2(-14, -83), Vector2(1, -83), RED, 4)
	else:
		if grabbed or hurt or action == "stunned":
			draw_polyline(PackedVector2Array([Vector2(-8,-93),Vector2(-3,-90),Vector2(-8,-88)]), INK, 2, true)
			draw_polyline(PackedVector2Array([Vector2(9,-93),Vector2(4,-90),Vector2(9,-88)]), INK, 2, true)
			_ellipse(Vector2(1,-82), Vector2(4 if shield_hurt else 3, 5 if shield_hurt else 2), Color("632d28"))
		else:
			draw_line(Vector2(5, -91), Vector2(11, -90), INK, 2)
	var reach := 43.0 if striking else 25.0
	var hand := Vector2(reach, -60 if attacking else -48)
	if (heavy and not striking) or action == "charge" or windup:
		hand = Vector2(24, -103)
	elif action == "guard":
		hand = Vector2(21, -78)
	elif grabbed:
		hand = Vector2(28, -84)
	if archer and not grabbed:
		hand = Vector2(31, -70)
	_limb(Vector2(13, -70), hand, 10 if female else 13, cloth)
	draw_circle(hand, 5, skin)
	if archer:
		var bow := PackedVector2Array()
		for index in range(17):
			var fraction := index / 16.0
			bow.append(hand + Vector2(3 + sin(fraction * PI) * 12, -36 + fraction * 72))
		draw_polyline(bow, Color("d7b77a"), 3, true)
		var draw_hand := hand + Vector2(-28 if windup else -3, 0)
		draw_polyline(PackedVector2Array([hand+Vector2(3,-36),draw_hand,hand+Vector2(3,36)]), Color("eee1b8"), 1.2, true)
		if windup:
			_limb(Vector2(-9,-70),draw_hand,9,cloth)
			draw_line(draw_hand,hand+Vector2(26,0),PAPER,2)
			draw_colored_polygon(PackedVector2Array([hand+Vector2(32,0),hand+Vector2(23,-3),hand+Vector2(23,3)]),PAPER)
	elif female:
		for needle in range(3):
			draw_line(hand + Vector2(-3, needle * 3 - 4), hand + Vector2(20, needle * 7 - 7), PAPER, 2)
	else:
		var blade_angle := -1.7 if (heavy and not striking) or action == "charge" or windup else (-0.15 if striking else -0.85)
		var blade_length := 72.0 if boss else 54.0
		var blade_color := GOLD if int(fighter.get("weapon", 0)) > 0 else PAPER
		var blade_dir := Vector2.from_angle(blade_angle)
		var cross := blade_dir.orthogonal()
		draw_line(hand - blade_dir * 9, hand + blade_dir * 7, INK, 5)
		draw_line(hand + blade_dir * 8 - cross * 8, hand + blade_dir * 8 + cross * 8, GOLD, 4)
		draw_line(hand + blade_dir * 11, hand + blade_dir * blade_length, blade_color, 5)
		draw_line(hand + blade_dir * 13, hand + blade_dir * blade_length + cross * 2, Color("9caeac"), 2)
	if striking and not female and action_tick < (36 if action == "special" else (24 if heavy else 13)):
		var trail_color := Color(0.98, 0.77, 0.34, 0.80) if heavy else Color(0.84, 0.93, 0.89, 0.72)
		draw_arc(Vector2(13, -63), 85 if heavy else 64, -1.5, 0.45 if heavy else -0.05, 20, trail_color, 9 if heavy else 4)
	if action == "special":
		draw_arc(Vector2(0, -45), 86, -PI, PI, 40, Color(0.99, 0.78, 0.26, 0.72), 5)
	if windup:
		draw_line(Vector2(0, -140), Vector2(0, -126), GOLD, 4)
		draw_circle(Vector2(0, -119), 2.5, GOLD)
	if float(fighter.get("charge", 0)) > 0 or action == "charge":
		draw_arc(Vector2(0, -48), 43, -PI * 0.7, PI * 0.7, 28, GOLD, 3)
	if int(fighter.get("poison", 0)) > 0:
		for bubble in range(3):
			draw_circle(Vector2(-19 + bubble * 19, -65 - fmod(tick * 0.5 + bubble * 12, 44.0)), 3, Color("95b660"))
	draw_set_transform(Vector2.ZERO)
	if action == "stunned" or int(fighter.get("stun", 0)) > 0:
		_draw_stun(origin - Vector2(0, jumping + 138.0 * size), tick)
	if team != 0 and hp > 0:
		var bar_pos := origin - Vector2(24 * size, 140 * size + jumping)
		draw_rect(Rect2(bar_pos, Vector2(48 * size, 5)), INK)
		draw_rect(Rect2(bar_pos, Vector2(48 * size * clampf(hp / maxf(float(fighter.get("max_hp", 100)), 1.0), 0.0, 1.0), 5)), RED)

func _draw_dummy(fighter: Dictionary, origin: Vector2) -> void:
	var z := float(fighter.get("z", 0))
	var tick := float(fighter.get("action_tick", 0))
	var action := str(fighter.get("action", "idle"))
	var hurt := action == "hurt" or int(fighter.get("shield_hurt_tick", 0)) > 0
	var tilt := sin(tick * 0.75) * 0.10 * exp(-tick * 0.12) if hurt else 0.0
	if action == "down": tilt = -0.42 * float(fighter.get("face", 1))
	elif action == "grabbed": tilt = -0.12 * float(fighter.get("face", 1))
	elif action == "thrown": tilt = -(0.65 + (30.0 - float(fighter.get("throw_ticks", 30))) * 0.065) * float(fighter.get("face", 1))
	_draw_actor_shadow(origin, 138.0, z, 32.0, 0.0, [-21.0, 21.0])
	draw_set_transform(origin - Vector2(0, z), tilt)
	var wood := Color("826046")
	var straw := Color("d5b971") if not hurt or tick > 5 else Color("fff0c0")
	_limb(Vector2(-26, -5), Vector2(27, -5), 10, wood.darkened(0.25))
	_limb(Vector2(0, -6), Vector2(0, -120), 12, wood)
	_limb(Vector2(-41, -86), Vector2(41, -86), 11, wood)
	_shape([Vector2(-19,-106),Vector2(20,-106),Vector2(27,-54),Vector2(19,-38),Vector2(-20,-38),Vector2(-27,-56)], straw)
	for strand in range(11):
		var x := -21.0 + strand * 4.2
		draw_line(Vector2(x * 0.8, -102), Vector2(x, -40 - (strand % 3) * 3), straw.darkened(0.22), 1.3)
	for y in [-100, -49]:
		draw_line(Vector2(-23, y), Vector2(23, y), Color("6c4932"), 4)
	_ellipse(Vector2(0,-122),Vector2(18,19),straw)
	draw_arc(Vector2(0,-122),17,0,TAU,24,INK,2)
	draw_line(Vector2(-15,-129),Vector2(15,-129),Color("9a4238"),5)
	draw_circle(Vector2(0,-78),17,Color("9a4238"))
	draw_circle(Vector2(0,-78),11,Color("e3d4a4"))
	draw_circle(Vector2(0,-78),5,Color("9a4238"))
	if hurt and tick < 13:
		for index in range(5):
			var direction := Vector2.from_angle(index * 1.1 - 2.5)
			var p := Vector2(0,-85) + direction * (18 + tick * 2.5)
			draw_line(p, p + direction * 7, Color("edce89"), 2)
	draw_set_transform(Vector2.ZERO)
	if action == "stunned" or int(fighter.get("stun", 0)) > 0:
		_draw_stun(origin - Vector2(0, z + 150), float(state.get("tick", 0)))

func _draw_stun(origin: Vector2, tick: float) -> void:
	for index in range(3):
		var angle := tick * 0.12 + index * TAU / 3.0
		var point := origin + Vector2(cos(angle) * 21, sin(angle) * 6)
		var star := PackedVector2Array()
		for tip in range(8):
			star.append(point + Vector2.from_angle(tip * PI / 4.0) * (5.0 if tip % 2 == 0 else 2.0))
		draw_colored_polygon(star, Color("ffe593"))

static func shockwave_points(effect: Dictionary, extent: float) -> PackedVector2Array:
	var arc := deg_to_rad(float(effect.get("arc_degrees",360)))
	var fan := arc < TAU
	var points := PackedVector2Array()
	for i in range(13):
		var angle := -arc * .5 + arc * i / (12.0 if fan else 13.0)
		points.append(Vector2(cos(angle) * extent * float(effect.get("face",1)),sin(angle) * extent * .4))
	return points

func _draw_ground_effect(effect: Dictionary) -> void:
	var p := Vector2(float(effect.get("x",0)) - camera_x,float(effect.get("y",460)))
	var radius := float(effect.get("radius",85))
	var age := 1.0 - float(effect.get("life",0)) / maxf(float(effect.get("max_life",1)),1)
	var kind := str(effect.get("type",""))
	if kind in ["warning","arrow_target"]:
		# A restrained contact shadow keeps the playable scene free of debugging bounds.
		_ellipse(p,Vector2(minf(radius,42),12),Color(0.25,0.17,0.11,0.1 + age * 0.14))
		return
	var extent := radius * (age if kind == "shockwave" else (0.2 + age * 0.8))
	if float(effect.get("arc_degrees",360)) >= 360:
		_draw_dust(p,extent,age,(1.0 - age) * 0.5)
	if kind == "shockwave":
		var element := str(effect.get("element","earth"))
		var points := shockwave_points(effect,extent)
		for i in range(points.size()):
			var base := p + points[i]
			if element == "fire": _paint_flame(base,24 + sin(age * PI) * 48,i,(1.0 - age) * 0.9)
			elif element == "ice": _paint_ice(base,Vector2(10,18 + sin(age * PI) * 42),i,(1.0 - age) * 0.85)
			else: _paint_ice(base,Vector2(8,12 + sin(age * PI) * 15),i,(1.0 - age) * 0.7,Color("ab936a"))

func _draw_effect(effect: Dictionary) -> void:
	var ground := Vector2(float(effect.get("x", 0)) - camera_x, float(effect.get("y", 460)))
	var p := ground - Vector2(0, 52)
	var kind := str(effect.get("type", effect.get("kind", "hit")))
	var life := float(effect.get("life", effect.get("ttl", 12)))
	var opacity := clampf(life / 8.0, 0.0, 1.0)
	if kind == "projectile":
		var needle_pos := ground - Vector2(0, float(effect.get("z", 28)) + (42.0 if int(effect.get("team", 0)) == 1 else 96.0))
		# Freeze the release-hand offset, then preserve the core's flight displacement and collision state.
		var release_offset := _projectile_release_offset(effect)
		if effect.get("arcing",false):
			needle_pos = arc_projectile_position(effect,camera_x,release_offset)
		else: needle_pos += release_offset
		var face := float(effect.get("face", 1))
		var style := projectile_style(str(effect.get("weapon", "needle")))
		if style.bullet:
			draw_line(needle_pos - Vector2(face * 42,0),needle_pos,Color(0.87,0.73,0.47,opacity * 0.7),2)
			draw_circle(needle_pos,2,Color(0.92,0.88,0.74,opacity))
		elif style.blade:
			for i in range(5):
				var point := needle_pos + Vector2(-face * absf(i - 2) * 10,(i - 2) * 21)
				_paint_streak(point,Vector2(face,-0.12),58,7,_element_color("blade"),opacity * (0.85 - absf(i - 2) * 0.14))
		elif style.arrow:
			_draw_arrow(needle_pos, projectile_direction(effect,release_offset), style.powered or effect.get("charged", false), opacity)
		else:
			_draw_needle(needle_pos, projectile_direction(effect), int(effect.get("poison", 0)) > 0, opacity)
		if effect.get("element","") in ["fire","ice"]:
			for i in range(5):
				var point := needle_pos - projectile_direction(effect) * (i * 15.0 + 12)
				if effect.element == "fire": _paint_flame(point,22 - i * 3,i,opacity * (0.8 - i * 0.13))
				else: _paint_ice(point,Vector2(5,17 - i * 2),i,opacity * (0.8 - i * 0.13))
	elif kind == "chain":
		_draw_chain(effect)
	elif kind in ["fire_wave","ice_wave","wind_wave","earth_wave","blade_wave"]:
		var age := 1.0 - life / maxf(1,float(effect.get("max_life",36)))
		var radius := float(effect.get("radius",320)) * (0.25 + age * 0.75)
		var face := float(effect.get("face",1))
		if kind == "blade_wave" and effect.get("action","") == "light":
			var reach := float(effect.get("radius",260))
			# This wave deals one instantaneous extended cut, so its leading edge never travels beyond that hit.
			draw_set_transform(ground + Vector2(face * (reach - 64),-64),0,Vector2(face,.6))
			draw_arc(Vector2.ZERO,64,-1.25,1.25,24,Color(1,.93,.77,(1 - age) * .85),7 * (1 - age) + 1,true)
			draw_set_transform(Vector2.ZERO)
			_paint_streak(ground + Vector2(face * reach * .5,-64),Vector2(face,0),reach * .65,3,Color("eee1be"),(1 - age) * .4)
			return
		for i in range(10):
			var base := ground + Vector2(face * radius * i / 10.0,0)
			var height := maxf(10.0,(65.0 + 70.0 * sin(i * 0.45 + age * PI)) * (1.0 - age * 0.5))
			if kind == "fire_wave": _paint_flame(base,height,i,(1.0 - age) * 0.76)
			elif kind == "ice_wave": _paint_ice(base,Vector2(21,height),i,(1.0 - age) * 0.77)
			elif kind == "earth_wave": _paint_ice(base,Vector2(28,height * 0.55),i,(1.0 - age) * 0.8,Color("a38a60"))
			else: _paint_streak(base - Vector2(0,40 + i % 3 * 20),Vector2(face,-0.1),45 + height * 0.3,9,_element_color(kind.trim_suffix("_wave")),(1.0 - age) * 0.8)
	elif kind in ["wind_hit","earth_hit","blade_hit"]:
		var age := 1.0 - life / maxf(1,float(effect.get("max_life",24)))
		var element := kind.trim_suffix("_hit")
		for i in range(10):
			var direction := Vector2.from_angle(i * TAU / 10)
			var point := p + direction * (12 + age * 65)
			if element == "earth": _paint_ice(point,Vector2(6,9 + i % 4 * 3),i,1.0 - age,_element_color(element))
			else: _paint_streak(point,direction,11 + i % 3 * 5,3,_element_color(element),1.0 - age)
	elif kind in ["fire_hit", "ice_hit", "shatter"]:
		var age := 1.0 - life / maxf(1,float(effect.get("max_life",24)))
		if effect.get("burst",false):
			var radius := float(effect.get("radius",100)) * (.2 + age * .8)
			for point in shockwave_points({"face":1},radius):
				_paint_ice(ground + point,Vector2(9,18 + sin(age * PI) * 25),point.x,(1 - age) * .8)
			return
		var ice := kind != "fire_hit"
		var color := Color("a8f3ff") if ice else Color("ff9d36")
		var count := 22 if kind == "shatter" else 12
		for shard in range(count):
			var direction := Vector2.from_angle(shard * TAU / count + (shard % 3) * 0.12)
			var distance := (28.0 + age * (150 if kind == "shatter" else 65)) * (0.6 + shard % 4 * 0.17)
			var position_now := p + direction * distance + Vector2(0, age * age * 60)
			if ice:
				var width := 4.0 + shard % 4 * 2.0
				draw_colored_polygon(PackedVector2Array([position_now + direction * width * 2,position_now + direction.orthogonal() * width,position_now - direction * width,position_now - direction.orthogonal() * width]),Color(color,1.0 - age))
			else:
				_paint_flame(position_now,18 * (1.0 - age),shard,1.0 - age)

	elif kind == "damage":
		var age := 1.0 - life / maxf(1,float(effect.get("max_life",40)))
		var amount := str(int(effect.get("amount",0)))
		var position_now := p - Vector2(8,60 + age * 52)
		draw_string_outline(ThemeDB.fallback_font,position_now,amount,HORIZONTAL_ALIGNMENT_LEFT,-1,23,4,Color(0.1,0.08,0.06,opacity))
		draw_string(ThemeDB.fallback_font,position_now,amount,HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color(1,0.88,0.61,opacity))
	elif kind in ["landing","arrow_impact","debris"]:
		var age := 1.0 - life / maxf(1,float(effect.get("max_life",22)))
		if effect.get("wet",false):
			for i in range(12):
				var direction := Vector2(-1 if i % 2 == 0 else 1,-1)
				var position_now := ground + Vector2(direction.x * age * (22 + i * 5),-sin(age * PI) * (13 + i % 4 * 8))
				_paint_streak(position_now,Vector2(direction.x * 0.3,-1 + age * 2),4 + i % 3,2,Color("a4bfc0"),(1.0 - age) * 0.85)
		else: _draw_dust(ground,18 + age * (55 if kind == "debris" else 32),age,(1.0 - age) * 0.55)
		if kind == "debris":
			for i in range(12):
				var point := ground + Vector2(sin(i * 3.2) * age * 95,-sin(age * PI) * (20 + i % 4 * 13))
				_paint_streak(point,Vector2.from_angle(i + age * 4),5 + i % 4,3,Color("8d6942"),1.0 - age)
	elif kind in ["guard","guard_break"]:
		var face := float(effect.get("face",1))
		for i in range(7):
			var direction := Vector2.from_angle(-1.7 + i * 0.56) * Vector2(face,1)
			_paint_streak(p + Vector2(face * 24,-25) + direction * (24 - life),direction,7 + i % 3 * 4,2.5,PAPER,opacity)
	elif kind == "slash":
		_paint_streak(p,Vector2(float(effect.get("face",1)),-0.35),float(effect.get("radius",60)),4,PAPER,opacity * 0.7)
	elif kind in ["hit", "heavy_hit", "special", "shield_hit", "throw_hit"]:
		var radius := 28.0 if kind == "heavy_hit" or effect.get("heavy", false) else 18.0
		if kind == "special":
			radius = 48.0
		elif kind in ["shield_hit", "throw_hit"]:
			radius = 36.0
			for ring in range(3):
				draw_circle(p, 24 - ring * 6, Color(1,0.66,0.30,opacity * 0.08))
		for ray in range(8):
			var direction := Vector2.from_angle(ray * TAU / 8.0 + 0.2)
			draw_line(p + direction * 6, p + direction * radius, Color(1.0, 0.87, 0.57, opacity), 3 if ray % 2 else 5)
		draw_circle(p, 5, Color(1.0, 0.97, 0.83, opacity))
	elif kind == "pickup":
		draw_arc(p + Vector2(0, 25), 22, -PI, PI, 24, Color(0.69, 0.90, 0.55, opacity), 3)
	elif kind == "defeat":
		_ellipse(p + Vector2(0, 48), Vector2(36, 12), Color(0.72, 0.66, 0.46, opacity * 0.5))
	elif kind == "poison":
		draw_arc(ground, 16, -PI, PI, 20, Color(0.64, 0.84, 0.35, opacity), 3)

func _draw_chain(effect: Dictionary) -> void:
	var start := Vector2(float(effect.get("x",0)) - camera_x,float(effect.get("y",460)) - 87)
	var end := Vector2(float(effect.get("target_x",effect.get("x",0))) - camera_x,float(effect.get("target_y",460)) - 70)
	for fighter in state.get("fighters",[]):
		if fighter.get("id",0) == effect.get("owner",-1):
			start = Vector2(float(fighter.x) - camera_x,float(fighter.y) - float(fighter.get("z",0)))
			var hand := Vector2(float(fighter.get("face",1)) * 60,-98)
			if _art.enemies.has(str(fighter.get("kind",""))):
				var sample := _fighter_animation(fighter)
				var frame := _art.enemy_frame(str(fighter.kind),int(sample.cell),str(fighter.get("faction","mori")),str(sample.sheet))
				if frame.has("hand_offset"): hand = frame.hand_offset * 163.0 / float(frame.body_height) * Vector2(float(fighter.get("face",1)),1)
			start += hand
		if fighter.get("id",0) == effect.get("target",-1): end = Vector2(float(fighter.x) - camera_x,float(fighter.y) - float(fighter.get("z",0)) - 65)
	var distance := start.distance_to(end)
	var count := maxi(2,ceili(distance / 8.0))
	var direction := (end - start).normalized()
	for link in range(count):
		var progress := float(link) / count
		var point := start.lerp(end,progress) + Vector2(0,sin(progress * PI) * minf(25,distance * 0.05))
		draw_set_transform(point,direction.angle(),Vector2(1,0.52 if link % 2 == 0 else 0.85))
		draw_arc(Vector2.ZERO,4.2,0,TAU,12,Color("d5dfe5"),1.5)
		draw_set_transform(Vector2.ZERO)
	draw_circle(end,7,INK)
	draw_circle(end,4,Color("b9c6cc"))

static func shadow_geometry(origin: Vector2, height: float, half_width: float, z: float, center_x: float = 0.0) -> Dictionary:
	var lift := clampf(maxf(z, 0.0) / maxf(height * 0.6, 1.0), 0.0, 1.0)
	return {"center": origin + Vector2(center_x, height * 0.01), "radius": Vector2(half_width + height * 0.13, height * 0.08) * lerpf(1.0, 0.55, lift), "opacity": lerpf(1.0, 0.42, lift), "contact_opacity": clampf(1.0 - z / 12.0, 0.0, 1.0)}

func _draw_actor_shadow(origin: Vector2, height: float, z: float, half_width: float, center_x: float = 0.0, contacts: Array = []) -> void:
	var shadow := shadow_geometry(origin, height, half_width, z, center_x)
	for layer in range(7):
		var spread := 1.0 - layer * 0.105
		var opacity := (0.035 + layer * 0.015) * float(shadow.opacity)
		_ellipse(shadow.center, shadow.radius * spread, Color(0.015, 0.019, 0.025, opacity))
	for contact_x in contacts:
		for layer in range(3):
			var radius := Vector2(height * 0.115, height * 0.028) * (1.0 - layer * 0.2)
			_ellipse(origin + Vector2(float(contact_x), 1.0), radius, Color(0.012, 0.016, 0.020, (0.12 + layer * 0.08) * float(shadow.contact_opacity)))

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		points.append(center + Vector2(cos(index * TAU / 20.0), sin(index * TAU / 20.0)) * radius)
	draw_colored_polygon(points, color)

func _shape(points: Array, color: Color) -> void:
	var polygon := PackedVector2Array(points)
	draw_colored_polygon(polygon, color)
	polygon.append(polygon[0])
	draw_polyline(polygon, INK, 2.0, true)

func _limb(start: Vector2, end: Vector2, width: float, color: Color) -> void:
	draw_line(start, end, INK, width + 3, true)
	draw_line(start, end, color, width, true)
	draw_circle(end, width * 0.5, color)


