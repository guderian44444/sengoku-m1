extends Node2D

const ArtAssets = preload("res://render/art_assets.gd")
const FrameAnimation = preload("res://render/frame_animation.gd")
const StageArt = preload("res://render/stage_art.gd")
const Stage03Art = preload("res://render/stage03_art.gd")
const Stage04Art = preload("res://render/stage04_art.gd")
const Stage05Art = preload("res://render/stage05_art.gd")
const Stage0710Art = preload("res://render/stage07_10_art.gd")
const OfficerWeaponFX = preload("res://render/officer_weapon_fx.gd")
const Stage2Scenery = preload("res://render/stage2_scenery.gd")
const Typography = preload("res://render/game_typography.gd")
const WeaponRenderer = preload("res://render/weapon_renderer.gd")
const SharedCombatVFX = preload("res://render/shared_combat_vfx.gd")

var state: Dictionary = {}
var camera_x: float = 0.0
var local_slot: int = 0
var weather: int = 0
var art_demo: bool = false
var art_time: float = 0.0
var demo_pose: int = -1
var demo_progress: float = 0.0
static var _shared_art: ArtAssets
var _art: ArtAssets
var _stage_art = StageArt.new()
var _stage03_art = Stage03Art.new()
var _stage04_art = Stage04Art.new()
var _stage05_art = Stage05Art.new()
var _stage0710_art = Stage0710Art.new()
var _officer_weapon_fx = OfficerWeaponFX.new()
var _stage_key: String = ""
var _positions: Dictionary = {}
var _moving: Dictionary = {}
var _walk_distance: Dictionary = {}
var _walk_ticks: Dictionary = {}
var _facing_back: Dictionary = {}
var _motion_tick: int = -1
var _projectile_origins: Dictionary = {}
var _frozen_samples: Dictionary = {}
var _treasures: Dictionary = {}
var _weapons = WeaponRenderer.new()
var _shadow_pass := false
var _opaque_bounds: Dictionary = {}
var _npc_alarm: Dictionary = {}
var _fx = SharedCombatVFX.new()

const INK := Color("172226")
const PAPER := Color("e0d4b4")
const RED := Color("b84538")
const GOLD := Color("d9af5e")
const DECOR_PARALLAX := {"background": 128.0 / 1100.0, "bamboo": 0.14, "ground": 1.0, "flags": 1.0, "fence": 1.0, "stone": 1.0, "grass": 1.0, "ripples": 1.0}
const GROUND_TILE_WIDTH := 1408.0
const GROUND_TOP := 364.0
const GROUND_BLEND_HEIGHT := 24.0
const TREASURE_FILES := {"vajra":"kongo", "iron":"iron", "mirror":"mirror"}

static func decor_offset(layer: String, camera: float) -> float:
	return camera * float(DECOR_PARALLAX.get(layer, 1.0))

static func ground_tiles(camera: float) -> Array:
	var tiles := []
	for index in range(floori(camera / GROUND_TILE_WIDTH),floori((camera + 1280.0) / GROUND_TILE_WIDTH) + 1):
		tiles.append({"x":index * GROUND_TILE_WIDTH - camera,"mirrored":posmod(index,2) == 1})
	return tiles

func _init() -> void:
	add_child(_fx)
	if _shared_art == null: _shared_art = ArtAssets.new()
	_art = _shared_art
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for key in TREASURE_FILES:
		var source := Image.load_from_file("res://assets/v21/treasures/%s.png" % TREASURE_FILES[key])
		if source != null: _treasures[key] = ImageTexture.create_from_image(source)

func _draw() -> void:
	if _fx.configured: _fx.shared_player.begin_draw(self)
	_update_motion()
	_draw_landscape()
	_draw_scenery()
	_draw_alarm()
	_draw_wet_zones()
	if state.has("expedition"): _stage0710_art.draw_hazards(self)
	for effect in state.get("effects", []):
		if effect.get("type", "") in ["warning", "slam", "shockwave", "arrow_target", "fire_patch"]:
			_draw_ground_effect(effect)
	for drop in state.get("drops", []):
		_draw_drop(drop)
	var fighters: Array = state.get("fighters", []).duplicate()
	fighters.append_array(_npc_samples(_art_clock()))
	if state.has("expedition"): fighters.append_array(Stage0710Art.civilian_samples(state))
	if state.get("encounter",{}).get("kind","") == "formation":
		fighters.append({"scenery_tent":true,"x":float(state.stage.encounter_end)-160,"y":610.0})
	for prop in state.get("props",[]):
		if prop.get("stage03_barrier",false):
			for panel in range(3):
				var piece: Dictionary = prop.duplicate()
				piece.scenery_prop = true
				piece.barrier_panel = panel
				piece.x = prop.x + (panel-1)*50
				piece.y = 390 + panel*90
				piece.ground_depth = 0.0
				fighters.append(piece)
			continue
		var display: Dictionary = prop.duplicate()
		display["scenery_prop"] = true
		display["ground_depth"] = prop_ground_depth(prop,_stage_art.prop(str(prop.kind)))
		fighters.append(display)
	if state.get("challenge",{}).get("kind","") == "reclaim":
		var cart: Dictionary = state.challenge.duplicate()
		cart.scenery_cart = true
		fighters.append(cart)
	fighters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return fighter_depth(a) < fighter_depth(b))
	_shadow_pass = true
	for fighter in fighters: _draw_scene_actor(fighter)
	_shadow_pass = false
	for effect in state.get("effects",[]):
		if effect.get("type","") == "arrow_rain": _draw_arrow_rain(effect,true)
	for fighter in fighters:
		_draw_scene_actor(fighter)
	_draw_demo_projectiles()
	var live_origins: Dictionary = {}
	for effect in state.get("effects", []):
		if effect.get("type", "") == "projectile" and not effect.get("yoshimoto_projectile",false):
			var key := _projectile_key(effect)
			live_origins[key] = _projectile_release_offset(effect)
		_draw_effect(effect)
	_projectile_origins = live_origins
	_fx.draw_world(self,camera_x)
	draw_set_transform(Vector2.ZERO)
	if state.has("mikawa"): _stage04_art.draw_foreground(self)
	_draw_weather()
	_draw_stage_go()
	_draw_stage2_hint()

func _draw_scene_actor(fighter: Dictionary) -> void:
	if fighter.get("scenery_tent",false):
		var at := Vector2(float(fighter.x)-camera_x,float(fighter.y))
		var frame: Dictionary = _stage_art.stage3_props.tent
		if _shadow_pass: _draw_prop_shadow(frame,at,320,65,.22)
		else: _draw_art_frame(frame,at,320,1,0,Color.WHITE,float(frame.body_height))
	elif fighter.get("scenery_cart",false): _draw_escort_cart(fighter)
	elif fighter.get("scenery_prop",false): _draw_prop(fighter)
	elif fighter.get("scenery_npc",false): _draw_npc(fighter)
	else:
		_draw_fighter(fighter)
		if not _shadow_pass: _fx.draw_bound(self,int(fighter.get("id",0)),camera_x)

static func fighter_depth(fighter: Dictionary) -> float:
	return float(fighter.get("y", 0)) + float(fighter.get("ground_depth",0)) * .5 + (0.25 if int(fighter.get("held_by", 0)) != 0 else 0.0)

static func prop_ground_depth(prop: Dictionary, frame: Dictionary) -> float:
	if prop.get("broken",false): return 0.0
	var depth := float(prop.get("depth",0))
	if float(frame.get("footprint_depth",0)) > 0: return minf(depth,float(frame.footprint_depth))
	# Checkpoint barriers have enlarged blocking zones, not enlarged visible bases.
	return minf(depth,float(frame.get("display_height",100)) * .5) if prop.get("mandatory",false) else depth

func _update_motion() -> void:
	var stage: Dictionary = state.get("stage",{})
	var key := "%s:%s" % [stage.get("id",0),stage.get("index",0)]
	if key != _stage_key:
		_stage_key = key
		_positions.clear()
		_walk_distance.clear()
		_walk_ticks.clear()
		_frozen_samples.clear()
		_projectile_origins.clear()
		_npc_alarm.clear()
	var tick := int(art_time * 60.0) if art_demo else int(state.get("tick", 0))
	if tick == _motion_tick:
		return
	var elapsed := maxi(0,tick - _motion_tick)
	if tick < _motion_tick:
		_positions.clear()
		_walk_distance.clear()
		_walk_ticks.clear()
		_frozen_samples.clear()
		_npc_alarm.clear()
	_motion_tick = tick
	var living_ids := {}
	for fighter in state.get("fighters",[]): living_ids[int(fighter.id)]=true
	# Retired reinforcements must not keep an evicted texture alive through a frozen pose.
	for cache in [_positions,_walk_distance,_walk_ticks,_frozen_samples,_moving,_facing_back,_npc_alarm]:
		for id in cache.keys():
			if not living_ids.has(id): cache.erase(id)
	for fighter in state.get("fighters", []):
		var id := int(fighter.get("id", -1))
		var position_now := Vector2(float(fighter.get("x", 0)), float(fighter.get("y", 0)))
		var movement: Vector2 = position_now - _positions.get(id, position_now)
		_moving[id] = movement.length_squared() > 0.1
		if _moving[id]:
			_facing_back[id] = movement.y < -0.1 and absf(movement.y) > absf(movement.x)
			if movement.length() < 60.0 and str(fighter.get("action", "idle")) in ["idle", "walk", "run", "move", "retreat"] and float(fighter.get("z", 0)) <= 0:
				_walk_distance[id] = float(_walk_distance.get(id, 0.0)) + movement.length()
		if FrameAnimation.CombatMoves.active(fighter) or Stage0710Art.Data.BOSSES.has(str(fighter.get("expedition_role",""))) or (int(fighter.get("team",0)) != 0 and enemy_art_faction(fighter) in ["mori","imagawa","oda"]):
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

static func _hero_animation_tick(hero: String, action: String, tick: float, attack_speed: float = 1.0) -> float:
	var milestones: Array = {
		"light":[6,19], "heavy":[14,36], "charged":[14,36], "rising":[6,24],
		"ground_slam":[14,42], "low_sweep":[9,28], "dash_strike":[10,30], "dash_heavy":[12,34],
		"air_light":[6,20], "air_heavy":[12,19,38], "upper_heavy":[12,36],
		"charged_upper":[22,56], "charged_slam":[28,72],
		"mixed_finisher":[9,27,48], "mixed_rising":[9,27,48], "counter_cut":[5,24], "throw":[12,36]
	}[action]
	if hero == "tadakatsu" and action == "charged": milestones = [5,10,15,36]
	if hero == "hideyoshi" and action == "charged": milestones = [12,22,34,44,56,66]
	if hero == "hideyoshi" and action in ["mixed_finisher","mixed_rising"]: milestones = [14,48]
	var previous_live := 0.0
	var previous_drawing := 0.0
	for milestone in milestones:
		var live := float(FrameAnimation.Battle.fighter_tick({"kind":hero,"attack_speed":attack_speed},int(milestone)))
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
	var art_faction := enemy_art_faction(fighter)
	if int(fighter.get("team",0)) != 0 and art_faction != str(fighter.get("faction","mori")):
		fighter = fighter.duplicate()
		fighter.faction = art_faction
	var hero := str(fighter.get("kind", "nobunaga"))
	var action := str(fighter.get("action", "idle"))
	var tick := float(fighter.get("action_tick", 0))
	var clock_tick := _art_clock() * 60.0
	var walking: bool = fighter.get("moving", _moving.get(int(fighter.get("id", -1)), false))
	if Stage0710Art.Data.BOSSES.has(str(fighter.get("expedition_role",""))):
		var id := int(fighter.id)
		if int(fighter.get("freeze",0)) > 0 and _frozen_samples.has(id): return _frozen_samples[id]
		var current := fighter.duplicate()
		current.moving = walking
		var sample := _stage0710_art.sample(state,current,float(_walk_ticks.get(id,0)),clock_tick)
		_frozen_samples[id] = sample
		return sample
	if fighter.has("s05_role"):
		var id := int(fighter.id)
		if int(fighter.get("freeze",0)) > 0 and _frozen_samples.has(id): return _frozen_samples[id]
		var current := fighter.duplicate()
		current.moving = walking
		var sample := _stage05_art.sample(state,current,float(_walk_ticks.get(id,0)),clock_tick)
		_frozen_samples[id] = sample
		return sample
	if fighter.has("mikawa_role"):
		var id := int(fighter.id)
		if int(fighter.get("freeze",0)) > 0 and _frozen_samples.has(id): return _frozen_samples[id]
		var current := fighter.duplicate()
		current.moving = walking
		var sample := _stage04_art.sample(state,current,float(_walk_ticks.get(id,0)),clock_tick)
		_frozen_samples[id] = sample
		return sample
	if not Stage03Art.actor_id(state,fighter).is_empty():
		var id := int(fighter.id)
		if int(fighter.get("freeze",0)) > 0 and _frozen_samples.has(id): return _frozen_samples[id]
		var current := fighter.duplicate()
		current.moving = walking
		var sample := _stage03_art.sample(state,current,float(_walk_ticks.get(id,0)),clock_tick)
		_frozen_samples[id] = sample
		return sample
	if int(fighter.get("team",0)) == 0:
		assert(FrameAnimation.CombatMoves.active(fighter),"Unavailable player art")
		var current := fighter.duplicate()
		current.moving = walking
		current.locomotion_tick = clock_tick if art_demo else float(_walk_ticks.get(int(fighter.get("id",-1)),0))
		if action == "idle": current.action_tick = clock_tick
		return FrameAnimation.hero_v22_sample(current,_art.animations[hero])
	var stage2_key := "oda:" + str(fighter.get("boss_variant","")) + ":poses"
	if int(fighter.get("team",0)) == 1 and hero == "boss" and fighter.get("faction","") == "oda" and _art.enemy_clips.has(stage2_key):
		var id := int(fighter.get("id",0))
		if int(fighter.get("freeze",0)) > 0 and _frozen_samples.has(id): return _frozen_samples[id]
		var cell := 0
		var reaction_key := stage2_key.trim_suffix(":poses")+":reactions"
		var reaction: bool = action in ["hurt","stunned","grabbed","pulled","frozen","down","dead","defeated","thrown","launched","recovering"] and _art.enemy_clips.has(reaction_key)
		if reaction:
			if fighter.get("airborne_lock",false) or action in ["thrown","launched"]: cell = 3
			elif action == "recovering":
				cell = 4 if tick < 6 else (3 if tick < 12 else 5)
				if tick >= 26: reaction = false; cell = 0
			elif action == "defeated":
				var progress := tick/maxf(1,float(fighter.get("death_ticks",24)))
				cell = 0 if progress < .12 else (1 if progress < .30 else (2 if progress < .64 else (3 if progress < .83 else 4)))
			elif action in ["down","dead"]: cell = 4 if action == "dead" or fighter.get("down_from_air",false) or tick >= 18 else (2 if tick < 8 else 3)
			else: cell = 0 if tick < 6 else 1
		elif walking and action in ["idle","walk","run","retreat"]: cell = 1 + posmod(floori(float(_walk_distance.get(int(fighter.id),0))/65.0),2)
		elif FrameAnimation.Battle.ENEMY_TIMING.has(action):
			var timing: Array = FrameAnimation.Battle.enemy_timing(fighter)
			if tick >= timing[0]: cell = 4 if action == "boss_sweep" else 3
		var sample := {"clip":action,"sheet":"enemy_clip:"+stage2_key,"frame":cell,"cell":cell,"count":6,"tick":tick,"duration":0,"released":cell in [3,4],"source":"v31","hero":hero}
		if reaction:
			sample.sheet = "enemy_clip:"+reaction_key
			sample.genuine_reaction = true
			if action == "defeated": sample.duration = int(fighter.get("death_ticks",24))
		if action == "recovering": sample.genuine_reaction = true
		_frozen_samples[id] = sample
		return sample

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
		if action == "defeated" and fighter.has("death_ticks"): tick = tick * 24.0 / float(fighter.death_ticks)
		if _art.enemy_reactions.has(enemy_key) and action in ["hurt","stunned","grabbed","pulled","launched","thrown","down","recovering","dead","defeated"]:
			var role := ["soldier","flag","commander","archer","gunner","boss"].find(hero)
			var counts: Array = _art.v11_counts.get("reactions-" + str(fighter.get("faction","mori")),[8,8,8,8,8,8])
			var pain := FrameAnimation.enemy_reaction_sample(action,tick,int(counts[role]),float(fighter.get("z",0)) > 0)
			pain.hero = hero
			_frozen_samples[id] = pain
			return pain
		var hd_boss: bool = hero == "boss" and _art.enemy_attacks.has(enemy_key) and _art.enemy_attacks[enemy_key][0].source == "v12"
		# The 235px Imagawa drawings retain detail at the final commander's 201.5px height.
		var imagawa_boss: bool = hero == "boss" and fighter.get("faction","") == "imagawa" and _art.enemy_clip_size(hero,"imagawa") == 6
		if hd_boss and action == "idle" and not walking:
			return {"clip":"idle","sheet":"enemy_attack","frame":0,"cell":0,"count":12,"tick":tick,"duration":0,"released":false,"source":"v12","hero":hero}
		if not hd_boss and not imagawa_boss and _art.enemy_movements.has(enemy_key) and action in ["idle","walk","run","move","retreat"]:
			var role := ["soldier","flag","commander","archer","gunner","boss"].find(hero)
			var count := int(_art.v11_counts["movement-" + str(fighter.get("faction","mori"))][role])
			var step := posmod(floori(float(_walk_distance.get(id,0)) / 106.0 * count),count) if walking else 0
			if _retreat_backwards(fighter): step = posmod(-step,count)
			var movement := {"clip":action,"sheet":"enemy_movement","frame":step,"cell":step,"count":count,"tick":tick,"duration":0,"released":false,"source":"v11","hero":hero}
			_frozen_samples[id] = movement
			return movement
		if not imagawa_boss and _art.enemy_attacks.has(enemy_key) and action == FrameAnimation.primary_enemy_action(fighter):
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
	return {}

func _draw_landscape() -> void:
	if state.has("expedition"):
		_stage0710_art.draw_landscape(self)
		return
	if state.get("stage",{}).get("id",0) == 5:
		_stage05_art.draw_landscape(self)
		return
	if state.get("stage",{}).get("id",0) == 4:
		_stage04_art.draw_landscape(self)
		return
	if not state.get("stage",{}).is_empty():
		var backdrop := _stage_art.background(str(state.stage.get("theme","bamboo")),int(state.stage.id),int(state.stage.index))
		if not backdrop.is_empty():
			var source: Rect2 = backdrop.region
			var horizon: float = source.size.y * float(backdrop.horizon)
			var far := Rect2(source.position,Vector2(source.size.x,horizon))
			var pan := clampf(camera_x / maxf(1.0,float(state.stage.width) - 1280.0) * 256.0,0.0,256.0)
			draw_texture_rect_region(backdrop.texture,Rect2(-pan,0,1536,GROUND_TOP),far)
			_draw_near_ground(backdrop,Rect2(source.position + Vector2(0,horizon),Vector2(source.size.x,source.size.y-horizon)))
			return
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
	if state.has("mikawa") or state.has("ikki") or state.has("expedition"): return
	if not state.get("stage",{}).is_empty():
		_draw_stage_scenery()
		return
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

func _draw_stage_scenery() -> void:
	_draw_stage_scenery_pass(true)
	_draw_stage_scenery_pass(false)

func _draw_stage_scenery_pass(shadows: bool) -> void:
	var theme: String = str(state.stage.get("theme","bamboo"))
	for index in range(floori(camera_x / 175.0) - 1,floori((camera_x + 1280.0) / 175.0) + 2):
		var border: Dictionary = _stage_art.border(theme,index)
		if border.is_empty(): continue
		var x := index * 175.0 + posmod(index * 47,73) - camera_x
		var y := GROUND_TOP + 9.0 + posmod(index * 13,17)
		var height: float = border.display_height * (0.86 + posmod(index * 7,5) * 0.05)
		var face := 1 if index % 3 else -1
		if shadows:
			_draw_frame_shadow(border,shadow_projection(Vector2(x,y),0,theme),height,face,0,.13)
		else: _draw_art_frame(border,Vector2(x,y),height,face,0,Color.WHITE,float(border.body_height))
	if theme in ["outpost","gate","camp","courtyard","command"] and _stage_art.flags.size() == 4:
		for index in range(ceili(float(state.stage.width) / 470.0)):
			var x := 290.0 + index*470.0 - camera_x
			if x < -120 or x > 1380: continue
			var flag: Dictionary = _stage_art.flags[str(posmod(floori(_art_clock()*5)+index,4))]
			if shadows: _draw_frame_shadow(flag,shadow_projection(Vector2(x,372),0,theme),168,1,0,.18)
			else: _draw_art_frame(flag,Vector2(x,372),168.0,1,0,Color.WHITE,float(flag.body_height))
	var kinds: Array = Stage2Scenery.DECOR.get(theme,{"village":["rice_bales","planter"],"road":["rice_bales","basket"],"outpost":["lantern"],"gate":["lantern"],"camp":["rice_bales","large_crate"],"courtyard":["stone_lantern","planter"],"command":["lantern","rice_bales"],"chamber":["lantern","planter"]}.get(theme,[]))
	if kinds.is_empty(): return
	var spacing := 345.0 if Stage2Scenery.DECOR.has(theme) else 560.0
	for index in range(ceili(float(state.stage.width) / spacing)):
		var x := 100.0 + index * spacing - camera_x
		if x < -180 or x > 1460: continue
		var frame := _stage_art.prop(str(kinds[index % kinds.size()]))
		if not frame.is_empty():
			var foot := Vector2(x,379 + index % 3 * 4)
			var height := float(frame.display_height) * .75
			if shadows: _draw_prop_shadow(frame,foot,height,height * .22,.20)
			else: _draw_art_frame(frame,foot,height,1,0,Color(.87,.90,.88),float(frame.body_height))
	if not shadows and theme in ["marune_gate","supply_court"]:
		for index in range(ceili(float(state.stage.width) / 620.0)):
			_draw_oda_banner(Vector2(170 + index * 620 - camera_x,375),index)

func _draw_oda_banner(foot: Vector2, index: int) -> void:
	if foot.x < -100 or foot.x > 1380: return
	var wave := sin(_art_clock() * 2.2 + index) * 5.0
	draw_line(foot,foot - Vector2(0,177),Color("4b3d29"),4,true)
	var top := foot - Vector2(0,170)
	draw_colored_polygon(PackedVector2Array([top,top+Vector2(48,wave),top+Vector2(45,126+wave),top+Vector2(0,125)]),Color("282927"))
	draw_line(top+Vector2(3,3),top+Vector2(44,4+wave),GOLD,2,true)
	var crest := top + Vector2(24,42+wave*.4)
	for petal in range(5):
		var center := crest + Vector2.from_angle(petal * TAU / 5 - PI/2) * 8
		draw_arc(center,8,0,TAU,16,GOLD,1.6,true)
	draw_circle(crest,3.3,GOLD)

func _draw_escort_cart(cart: Dictionary) -> void:
	var foot := Vector2(float(cart.x)-camera_x,float(cart.y))
	if foot.x < -180 or foot.x > 1460: return
	var failed: bool = cart.get("status","") == "failed"
	var frame := _stage_art.prop("cart",failed)
	if frame.is_empty(): frame = _art.prop_frame("cart",2 if failed else 0)
	if frame.is_empty(): return
	var height := 52.0 if failed else 112.0
	if _shadow_pass:
		_draw_pose_shadow(frame,foot,height,1,0,0,[-37.0,34.0])
		if not failed:
			var load_frame := _stage_art.prop("rice_bales")
			var projection := shadow_projection(foot,0,str(state.get("stage",{}).get("theme","")))
			_draw_frame_shadow(load_frame,projection * Transform2D(0,Vector2(-7,-55)),52,1,0,.25)
		return
	_draw_art_frame(frame,foot,height,1,0,Color(.57,.45,.38) if failed else Color.WHITE,float(frame.body_height))
	if not failed:
		var bale := _stage_art.prop("rice_bales")
		if not bale.is_empty(): _draw_art_frame(bale,foot+Vector2(-7,-55),52,1,0,Color.WHITE,float(bale.body_height))
	var bar := foot-Vector2(51,height+23)
	draw_rect(Rect2(bar,Vector2(102,7)),INK)
	draw_rect(Rect2(bar,Vector2(102*clampf(float(cart.hp)/float(cart.max_hp),0,1),7)),Color("c2b263") if not failed else RED)
	Typography.draw_label(self,bar-Vector2(7,7),"糧車" if not failed else "糧車已毀",15,GOLD,115,HORIZONTAL_ALIGNMENT_CENTER)

func _draw_stage2_hint() -> void:
	var stage: Dictionary = state.get("stage",{})
	var theme := str(stage.get("theme",""))
	if not Stage2Scenery.HINTS.has(theme): return
	var challenge: Dictionary = state.get("challenge",{})
	var has_cart: bool = challenge.get("kind","") == "reclaim"
	var opening := int(state.get("tick",0)) - int(stage.get("entered_tick",0)) < 480
	if not opening and not has_cart: return
	var panel := Rect2(16,121,680,62 if has_cart else 34)
	draw_rect(panel,Color(.055,.066,.068,.88))
	draw_line(panel.position,panel.position+Vector2(0,panel.size.y),GOLD,3)
	Typography.draw_label(self,panel.position+Vector2(12,23),str(Stage2Scenery.HINTS[theme]),17,Typography.PAPER)
	if has_cart:
		var status := str(challenge.status)
		var label := "奪回糧車  %d / %d 耐久　阻止敵人毀車，清場賞金 %d" % [int(challenge.hp),int(challenge.max_hp),int(challenge.reward)]
		if status == "complete": label = "糧車奪回 · 賞金 +%d" % int(challenge.reward)
		elif status == "failed": label = "糧車損毀 · 加賞失敗，仍可繼續進軍"
		Typography.draw_label(self,panel.position+Vector2(12,50),label,16,GOLD if status != "failed" else Color("ee9780"))

func _draw_stage_go() -> void:
	var stage: Dictionary = state.get("stage",{})
	if not stage.get("go",false): return
	var shift := 7.0 * sin(_art_clock()*6.0)
	var panel := Rect2(1080 + shift,150,172,92)
	draw_rect(panel,Color(.08,.09,.08,.9))
	draw_rect(panel,GOLD,false,3)
	Typography.draw_label(self,panel.position+Vector2(18,49),"進軍",42,Typography.GOLD)
	var tip := panel.position+Vector2(150,41)
	draw_line(tip-Vector2(39,0),tip,GOLD,9,true)
	draw_colored_polygon(PackedVector2Array([tip+Vector2(8,0),tip+Vector2(-15,-19),tip+Vector2(-15,19)]),GOLD)
	Typography.draw_label(self,panel.position+Vector2(21,77),"繼續向右",18,Typography.PAPER)

func _npc_samples(clock: float) -> Array:
	var people: Array = []
	var stage: Dictionary = state.get("stage",{})
	var theme := str(stage.get("theme",""))
	var stage2_civilians := Stage2Scenery.LANES.has(theme)
	var lanes := Stage2Scenery.lanes(theme) if stage2_civilians else [
		{"kind":"woman","origin":310.0,"y":424.0,"speed":42.0,"scale":1.0},
		{"kind":"child","origin":430.0,"y":430.0,"speed":42.0,"scale":.63},
		{"kind":"elder","origin":1030.0,"y":449.0,"speed":-31.0,"scale":.96},
		{"kind":"cart_vendor","origin":1490.0,"y":465.0,"speed":-43.0,"scale":1.08},
		{"kind":"herb_vendor","origin":750.0,"y":422.0,"speed":0.0,"scale":1.02},
		{"kind":"produce_vendor","origin":1780.0,"y":448.0,"speed":0.0,"scale":1.0}]
	var allowed := StageArt.civilian_kinds(str(stage.get("civilians","none")))
	var local_clock := maxf(0,clock - float(stage.get("entered_tick",0)) / 60.0) if stage2_civilians else clock
	var flee_tick := int(state.get("civilian_flee_tick",-1))
	var legacy_flee := not stage2_civilians and flee_tick >= 0 and clock >= float(flee_tick) / 60.0
	var walk_time := minf(clock,float(flee_tick)/60.0) if legacy_flee else local_clock
	for index in range(lanes.size()):
		var lane: Dictionary = lanes[index]
		if not Stage2Scenery.LANES.has(theme) and not stage.is_empty() and not lane.kind in allowed: continue
		var height := (94.0 + (float(lane.y) - 400.0) * .52) * float(lane.scale)
		var span := float(stage.get("width",2440)) + 260.0
		var speed := float(lane.speed)
		var x := fposmod(float(lane.origin) + walk_time * speed + 130.0,span) - 130.0
		if legacy_flee and not _npc_alarm.has(index):
			_npc_alarm[index] = {"time":float(flee_tick)/60.0,"x":x,"face":-1.0 if x < float(state.get("civilian_flee_x",640)) else 1.0}
		if stage2_civilians and not _npc_alarm.has(index):
			for fighter in state.get("fighters",[]):
				if fighter.get("action","idle") in ["idle","walk","run","dead","defeated"] or float(fighter.get("hp",0)) <= 0: continue
				if absf(float(fighter.get("x",0)) - x) < 280 and absf(float(fighter.get("y",0)) - float(lane.y)) < 190:
					_npc_alarm[index] = {"time":local_clock,"x":x,"face":-1.0 if x < float(fighter.x) else 1.0}
					break
		var fleeing := _npc_alarm.has(index)
		var distance := local_clock * absf(speed)
		if fleeing:
			var alarm: Dictionary = _npc_alarm[index]
			speed = float(alarm.face) * (118 if lane.kind == "elder" else (162 if lane.kind == "child" else 176))
			var age := maxf(0,local_clock - float(alarm.time))
			x = float(alarm.x) + age * speed
			distance = age * absf(speed)
			if x < -160 or x > span: continue
		var stride := height * (1.32 if fleeing else .88)
		var count := 6 if _art.npc_frames.has(lane.kind) else 4
		people.append({"scenery_npc":true,"kind":lane.kind,"x":x,"y":lane.y,"height":height,"face":-1 if speed < 0 else 1,"frame":posmod(floori(distance / stride * count),count),"distance":distance,"stride":stride,"speed":speed,"activity":lane.get("activity","walk"),"mode":"run" if fleeing else "walk"})
	return people

func _draw_npc(person: Dictionary) -> void:
	var origin := Vector2(float(person.x) - camera_x,float(person.y))
	if origin.x < -130 or origin.x > 1410: return
	var height := float(person.height)
	var frame: Dictionary = _art.npc_frame(str(person.kind),int(person.frame) + (6 if person.mode == "run" else 0))
	if frame.is_empty():
		if _art.villager_frames.size() != 8: return
		frame = _art.villager_frames[int(person.frame) % 4 + (4 if person.mode == "run" else 0)]
	if _shadow_pass:
		_draw_pose_shadow(frame,origin,height,float(person.face),0,0)
		if person.get("activity","") in ["porter","basket"]:
			var load_frame := _stage_art.prop("rice_bales" if person.activity == "porter" else "basket")
			var projection := shadow_projection(origin,0,str(state.get("stage",{}).get("theme","")))
			_draw_frame_shadow(load_frame,projection * Transform2D(0,Vector2(-float(person.face) * height * .16,-height * .44)),height * .28,1,0,.28)
		return
	_draw_art_frame(frame,origin,height,float(person.face),0,_scene_light(),float(frame.body_height))
	if person.get("activity","") in ["porter","basket"]:
		var load_frame := _stage_art.prop("rice_bales" if person.activity == "porter" else "basket")
		if not load_frame.is_empty():
			var load_pos := origin + Vector2(-float(person.face) * height * .16,-height * .44)
			_draw_art_frame(load_frame,load_pos,height * .28,1,0,Color.WHITE,float(load_frame.body_height))

func _draw_alarm() -> void:
	if not state.has("encounter") or state.encounter.kind != "alarm": return
	var encounter: Dictionary = state.encounter
	var floor_pos := Vector2(float(encounter.bell_x) - camera_x, float(encounter.bell_y))
	var top := floor_pos + Vector2(0,25) - Vector2(0,float(encounter.bell_height))
	var supports: Array = state.props.filter(func(p): return p.id in encounter.support_ids)
	var remaining: int = supports.filter(func(p): return not p.broken).size()
	for prop in supports:
		if prop.broken: continue
		var start := Vector2(float(prop.x) - camera_x,float(prop.y) + 25 - float(encounter.bell_height))
		var delta := top - start
		var beam: Dictionary = _stage_art.stage3_props.pillar
		_draw_art_frame(beam,start,delta.length(),1,delta.angle()+PI*.5,_scene_light(),float(beam.body_height))
	var fall := clampf((int(state.tick) - int(encounter.stopped_tick)) / 36.0, 0.0, 1.0) if remaining == 0 else 0.0
	top = top.lerp(floor_pos - Vector2(0, 36), fall * fall)
	var swing := sin(float(state.tick) * .16) * .18 if encounter.ringing else 0.0
	var tilt := .22 if remaining < supports.size() else 0.0
	var bell: Dictionary = _stage_art.stage3_props.bell
	_draw_art_frame(bell,top,82,1,swing + tilt + fall * .9,_scene_light(),float(bell.body_height))

func _draw_alarm_pillar(prop: Dictionary, origin: Vector2, hit_gain: float) -> void:
	var ratio := float(prop.hp) / float(prop.max_hp)
	var key := "pillar_debris" if prop.broken else ("pillar_split" if ratio < .34 else ("pillar_cracked" if ratio < .67 else "pillar"))
	var frame: Dictionary = _stage_art.stage3_props[key]
	var height: float = 38.0 if prop.broken else float(state.encounter.bell_height)
	if _shadow_pass:
		_draw_prop_shadow(frame,origin,height,30,.25)
		return
	var tint := _scene_light().lerp(Color(1.7,1.45,1.1),hit_gain)
	tint.a = prop_opacity(prop,state.fighters,height,45)
	_draw_art_frame(frame,origin,height,1,0,tint,float(frame.body_height))
	if prop.broken: return
	draw_rect(Rect2(origin + Vector2(-30,10),Vector2(60,6)),INK)
	draw_rect(Rect2(origin + Vector2(-30,10),Vector2(60 * ratio,6)),GOLD)

func _draw_camp_barrier(prop: Dictionary, origin: Vector2, hit_gain: float) -> void:
	var frame: Dictionary = _stage_art.stage3_props.barrier_debris if prop.broken else _stage_art.stage3_props.barrier
	var tint := _scene_light().lerp(Color(1.7,1.45,1.1),hit_gain)
	var scale := (135.0 if prop.broken else 175.0) / float(frame.body_height)
	# Project the fence along the ground lane; each panel sorts against nearby feet.
	if _shadow_pass:
		draw_set_transform_matrix(Transform2D(Vector2(.70,.62),Vector2(.30,.20),origin))
		draw_texture_rect_region(frame.texture,Rect2(-frame.anchor*scale,frame.region.size*scale),frame.region,Color(0,0,0,.24))
	else:
		tint.a = prop_opacity(prop,state.fighters,175,60)
		if not prop.broken:
			for offset in [Vector2(12,-7),Vector2(6,-3.5)]:
				draw_set_transform_matrix(Transform2D(Vector2(.70,.62),Vector2(0,1),origin+offset))
				draw_texture_rect_region(frame.texture,Rect2(-frame.anchor*scale,frame.region.size*scale),frame.region,tint.darkened(.4))
		draw_set_transform_matrix(Transform2D(Vector2(.70,.62),Vector2(0,1),origin))
		draw_texture_rect_region(frame.texture,Rect2(-frame.anchor*scale,frame.region.size*scale),frame.region,tint)
	draw_set_transform(Vector2.ZERO)
	if not prop.broken and not _shadow_pass and int(prop.get("barrier_panel",0)) == 0:
		draw_rect(Rect2(origin + Vector2(-38,-190),Vector2(76,6)),INK)
		draw_rect(Rect2(origin + Vector2(-38,-190),Vector2(76 * float(prop.hp)/float(prop.max_hp),6)),GOLD)

func _draw_prop(prop: Dictionary) -> void:
	if prop.has("expedition_asset"):
		var drawing := _stage0710_art.prop(prop,int(state.tick))
		var ground := Vector2(float(prop.x)-camera_x,float(prop.y))
		if _shadow_pass:
			_draw_attached_prop_shadow(drawing,ground,float(drawing.display_height))
			return
		_draw_art_frame(drawing,ground,float(drawing.display_height),1,0,Color.WHITE,float(drawing.body_height))
		return
	if prop.has("s05_asset"):
		var drawing := _stage05_art.prop(prop,int(state.tick))
		var ground := Vector2(float(prop.x)-camera_x,float(prop.y))
		if _shadow_pass:
			_draw_attached_prop_shadow(drawing,ground,float(drawing.display_height))
			return
		_draw_art_frame(drawing,ground,float(drawing.display_height),1,0,Color.WHITE,float(drawing.body_height))
		return
	if prop.has("mikawa_asset"):
		var drawing := _stage04_art.prop(prop,int(state.tick))
		var ground := Vector2(float(prop.x)-camera_x,float(prop.y))
		var height := 245.0 if prop.mikawa_asset in ["kflag","uflag"] else 148.0
		if _shadow_pass:
			_draw_attached_prop_shadow(drawing,ground,height)
			return
		_draw_art_frame(drawing,ground,height,1,0,Color.WHITE,float(drawing.body_height))
		return
	var origin := Vector2(float(prop.x) - camera_x,fighter_depth(prop))
	if origin.x < -240 or origin.x > 1520: return
	var hit_age := int(state.get("tick",0)) - int(prop.get("hit_tick",-100))
	var hit_gain := maxf(0.0,1.0 - hit_age / 12.0) if hit_age >= 0 else 0.0
	origin.x += sin(hit_age * 1.8) * hit_gain * 5.0
	if prop.get("stage03_barrier",false):
		_draw_camp_barrier(prop,origin,hit_gain)
		return
	if prop.kind == "bell_pillar":
		_draw_alarm_pillar(prop, origin, hit_gain)
		return
	var hd := _stage_art.prop(str(prop.kind),bool(prop.get("broken",false)))
	if not hd.is_empty():
		var height: float = hd.display_height
		if prop.get("broken",false): height = clampf(float(_stage_art.props.get(str(prop.kind),{}).get("display_height",78)) * .30,22.0,48.0)
		if _shadow_pass:
			_draw_prop_shadow(hd,origin,height,float(prop.get("ground_depth",0)))
			return
		var damaged: bool = not prop.get("broken",false) and float(prop.get("hp",100)) < float(prop.get("max_hp",100)) * .6
		var tint := Color(.78,.71,.63) if damaged else _scene_light()
		tint = tint.lerp(Color(1.7,1.45,1.1),hit_gain if hit_age % 4 < 2 else 0.0)
		tint.a = prop_opacity(prop,state.get("fighters",[]),height,float(hd.region.size.x) * height / float(hd.body_height))
		_draw_art_frame(hd,origin,height,1,0,tint,float(hd.body_height))
		return
	var damage := 2 if prop.get("broken",false) else (1 if float(prop.hp) < float(prop.max_hp) * 0.6 else 0)
	var frame: Dictionary = _art.prop_frame(str(prop.kind),damage)
	if frame.is_empty(): return
	var heights := {"stall":150.0,"cart":107.0,"jar":55.0,"basket":39.0,"crate":58.0}
	var height := float(heights.get(prop.kind,60))
	if _shadow_pass:
		_draw_pose_shadow(frame,origin,height,1,0,0)
		return
	_draw_art_frame(frame,origin,height,1,0,Color.WHITE.lerp(Color(1.7,1.45,1.1),hit_gain),float(frame.body_height))

static func prop_opacity(prop: Dictionary, fighters: Array, height: float, width: float) -> float:
	if prop.get("broken",false) or height < 105.0: return 1.0
	var front := fighter_depth(prop)
	for fighter in fighters:
		if fighter.team == 0 and fighter.hp > 0 and fighter.y < front and fighter.y > front - height and absf(fighter.x - prop.x) < width * 0.5 + 22.0: return 0.42
	return 1.0

func _source_scale(frame: Dictionary) -> Vector2:
	# Stage-five pages store a half-size atlas region stretched onto the crop.
	# Anchors live in that crop, so opaque pixels have to be measured there too.
	var region: Rect2 = frame.region
	var source: Vector2 = frame.get("source_size", region.size)
	return Vector2(source.x / maxf(1.0, region.size.x), source.y / maxf(1.0, region.size.y))

func _frame_opaque_bounds(frame: Dictionary) -> Rect2:
	var region: Rect2 = frame.region
	var key := "%s:%d,%d,%d,%d" % [frame.texture.get_rid(), region.position.x, region.position.y, region.size.x, region.size.y]
	if _opaque_bounds.has(key): return _opaque_bounds[key]
	var image: Image = frame.texture.get_image()
	var min_x := region.end.x
	var min_y := region.end.y
	var max_x := region.position.x
	var max_y := region.position.y
	var found := false
	if image != null:
		var y := int(region.position.y)
		var y_end := mini(int(region.end.y), image.get_height())
		var x_end := mini(int(region.end.x), image.get_width())
		while y < y_end:
			var x := int(region.position.x)
			while x < x_end:
				if image.get_pixel(x, y).a > 0.08:
					found = true
					min_x = minf(min_x, x)
					min_y = minf(min_y, y)
					max_x = maxf(max_x, x + 1)
					max_y = maxf(max_y, y + 1)
				x += 2
			y += 2
	var bounds := Rect2(region.position, Vector2(1, 1))
	if found: bounds = Rect2(min_x, min_y, maxf(1, max_x - min_x), maxf(1, max_y - min_y))
	var to_source := _source_scale(frame)
	bounds = Rect2((bounds.position - region.position) * to_source, bounds.size * to_source)
	_opaque_bounds[key] = bounds
	return bounds

func _opaque_band(frame: Dictionary, local_top: float, local_bottom: float) -> Rect2:
	var region: Rect2 = frame.region
	var key := "%s:%d,%d,%d,%d:%.0f" % [frame.texture.get_rid(), region.position.x, region.position.y, region.size.x, region.size.y, local_top]
	if _opaque_bounds.has(key): return _opaque_bounds[key]
	var to_source := _source_scale(frame)
	var image: Image = frame.texture.get_image()
	var min_x := region.end.x
	var max_x := region.position.x
	var found := false
	if image != null:
		var y := clampi(int(region.position.y + local_top / to_source.y), 0, image.get_height())
		var y_end := clampi(int(ceil(region.position.y + local_bottom / to_source.y)), 0, image.get_height())
		var x_end := mini(int(region.end.x), image.get_width())
		while y < y_end:
			var x := int(region.position.x)
			while x < x_end:
				if image.get_pixel(x, y).a > 0.08:
					found = true
					min_x = minf(min_x, x)
					max_x = maxf(max_x, x + 1)
				x += 2
			y += 2
	var band := Rect2(0, local_top, frame.get("source_size", region.size).x, maxf(1.0, local_bottom - local_top))
	if found:
		var left := (min_x - region.position.x) * to_source.x
		var right := (max_x - region.position.x) * to_source.x
		band = Rect2(left, local_top, maxf(1.0, right - left), maxf(1.0, local_bottom - local_top))
	_opaque_bounds[key] = band
	return band

func _draw_attached_prop_shadow(frame: Dictionary, ground: Vector2, height: float) -> void:
	# Chapter 1 jars read as sitting down because their shadow overlaps the base.
	# A tall prop projected with the usual 0.24 depth drops that shadow clear of the feet.
	if frame.is_empty() or height <= 1.0: return
	var body := float(frame.get("body_height", height))
	var scale := height / body
	var region: Rect2 = frame.region
	var source: Vector2 = frame.get("source_size", region.size)
	var anchor: Vector2 = frame.get("anchor", Vector2(source.x * 0.5, source.y))
	var bounds := _frame_opaque_bounds(frame)
	var bottom := bounds.position.y + bounds.size.y
	var top := maxf(bounds.position.y, bottom - 42.0 / scale)
	var foot := ground + Vector2(0, (bottom - anchor.y) * scale)
	var band := _opaque_band(frame, top, bottom)
	var base_width := maxf(22.0, band.size.x * scale)
	var rx := base_width * 0.48
	var ry := clampf(rx * 0.2, 8.0, 13.0)
	# Sit across the opaque bottom: part of the oval tucks into the feet, the rest lies on the ground.
	var center := foot + Vector2((band.get_center().x - anchor.x) * scale, ry * 0.35)
	for layer in range(6):
		var alpha := 0.06 + layer * 0.025
		_ellipse(center, Vector2(rx, ry) * (1.0 - layer * 0.1), Color(0.015, 0.019, 0.025, alpha))

func _draw_prop_shadow(frame: Dictionary, front: Vector2, height: float, depth: float, opacity: float = .25) -> void:
	_draw_frame_shadow(frame,shadow_projection(front,0,str(state.get("stage",{}).get("theme",""))),height,1,0,opacity)
	var width := float(frame.region.size.x) * height / float(frame.body_height)
	var center := front - Vector2(0,depth * .5)
	var radius := Vector2(width * .43,maxf(3,depth * .58))
	for layer in range(5):
		_ellipse(center,radius * (1.0-layer*.13),Color(0.015,0.019,0.025,.045+layer*.018))

func _draw_wet_zones() -> void:
	for zone in state.get("wet_zones",[]):
		var origin := Vector2(float(zone.x) - camera_x,float(zone.y))
		var edge := PackedVector2Array()
		for i in range(30):
			var angle := i * TAU / 30.0
			var noise := 0.85 + sin(i * 7.13) * 0.1
			edge.append(origin + Vector2(cos(angle) * float(zone.width) * 0.5,sin(angle) * float(zone.depth) * 0.5) * noise)
		for i in range(edge.size()):
			draw_polygon(PackedVector2Array([origin,edge[i],edge[(i+1)%edge.size()]]),PackedColorArray([Color(.23,.34,.36,.30),Color(.23,.34,.36,0),Color(.23,.34,.36,0)]))
		for i in range(7):
			var center := origin + Vector2(sin(i * 3.7) * float(zone.width) * 0.29,cos(i * 2.1) * float(zone.depth) * 0.24)
			draw_line(center - Vector2(12 + i * 2,0),center + Vector2(15 + i * 2,0),Color(0.69,0.77,0.74,0.22),1.5)

func _draw_weather() -> void:
	var mode: String = str(state.get("stage",{}).get("weather","rain" if weather == 2 else "clear"))
	if mode == "indoor" or mode == "clear": return
	var clock := _art_clock()
	if mode == "mist":
		for band in range(5):
			var y := 310.0 + band * 48.0 + sin(clock*.2 + band) * 8.0
			draw_rect(Rect2(0,y,1280,64),Color(.76,.84,.79,.025))
		return
	if mode == "storm":
		draw_rect(Rect2(0,0,1280,720),Color(.06,.10,.18,.17))
		if fposmod(clock,9.0) < .08: draw_rect(Rect2(0,0,1280,720),Color(.80,.89,1,.11))
	for index in range(155 if mode == "storm" else 95):
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
	var source_size: Vector2 = frame.get("source_size",region.size)
	var scale := height / (base_height if base_height > 0 else source_size.y)
	var size := source_size * scale
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
		if frame.has("uv_polygon"): uvs = frame.uv_polygon
		draw_polygon(vertices,PackedColorArray([tint]),uvs,frame.texture)
	else:
		draw_texture_rect_region(frame.texture, Rect2(-anchor * scale, size), region, tint)
	draw_set_transform(Vector2.ZERO)
	for overlay in frame.get("overlays",[]): _draw_art_frame(overlay,origin,height,face,rotation,tint,base_height)

static func shadow_projection(origin: Vector2, z: float, theme: String = "") -> Transform2D:
	var lean := .76 if theme in ["switchback","marune_gate"] else .46
	var depth := .32 if theme in ["switchback","marune_gate"] else .24
	return Transform2D(Vector2(1,0),Vector2(-lean,-depth),origin + Vector2(lean,depth) * maxf(0,z))

func _scene_light() -> Color:
	var theme := str(state.get("stage",{}).get("theme",""))
	if theme == "supply_court": return Color(.83,.85,.98)
	if theme in ["switchback","marune_gate"]: return Color(1,.90,.77)
	return Color.WHITE

static func frame_contact_points(frame: Dictionary, height: float, face: float = 1.0, rotation: float = 0.0) -> Array:
	var result := []
	if not frame.has("clip_polygon"): return result
	var anchor: Vector2 = frame.anchor
	var body_height := float(frame.body_height)
	var scale := height / body_height
	var bottom := -INF
	for point in frame.clip_polygon: bottom = maxf(bottom,point.y)
	for side in [-1,1]:
		var lowest := -INF
		for point in frame.clip_polygon:
			if (point.x-anchor.x)*side >= 0: lowest = maxf(lowest,point.y)
		if lowest < bottom-body_height*.13: continue
		var left := INF
		var right := -INF
		for point in frame.clip_polygon:
			if (point.x-anchor.x)*side >= 0 and point.y >= lowest-body_height*.025:
				left = minf(left,point.x)
				right = maxf(right,point.x)
		if left == INF: continue
		var offset := ((Vector2((left+right)*.5,lowest)-anchor)*Vector2(face,1)*scale).rotated(rotation)
		result.append({"offset":offset,"width":clampf((right-left)*scale*.5,6,height*.16)})
	return result

func _draw_frame_shadow(frame: Dictionary, projection: Transform2D, height: float, face: float = 1.0, rotation: float = 0.0, alpha: float = .26, base_height: float = 0.0) -> void:
	if frame.is_empty(): return
	if frame.has("layers"):
		for layer in frame.layers: _draw_frame_shadow(layer,projection,height,face,rotation,alpha,base_height)
		return
	var region: Rect2 = frame.region
	var scale := height / (base_height if base_height > 0 else float(frame.get("body_height",region.size.y)))
	var anchor: Vector2 = frame.get("anchor",Vector2(region.size.x * .5,region.size.y))
	var local := Transform2D(rotation,Vector2(face * scale,scale),0,-(anchor * Vector2(face,1) * scale).rotated(rotation))
	draw_set_transform_matrix(projection * local)
	var tint := Color(0,0,0,alpha)
	if frame.has("clip_polygon"):
		var uvs := PackedVector2Array()
		for point in frame.clip_polygon: uvs.append((point + region.position) / frame.texture.get_size())
		draw_polygon(frame.clip_polygon,PackedColorArray([tint]),uvs,frame.texture)
	else:
		draw_texture_rect_region(frame.texture,Rect2(Vector2.ZERO,frame.get("source_size",region.size)),region,tint)
	draw_set_transform(Vector2.ZERO)

func _draw_pose_shadow(frame: Dictionary, origin: Vector2, height: float, face: float, rotation: float, z: float, contacts: Array = [], fighter: Dictionary = {}) -> void:
	var projection := shadow_projection(origin,z,str(state.get("stage",{}).get("theme","")))
	var opacity := lerpf(.39,.17,clampf(z / 150.0,0,1))
	_draw_frame_shadow(frame,projection,height,face,rotation,opacity,float(frame.get("body_height",height)))
	if not fighter.is_empty(): _weapons.draw_shadow(self,fighter,frame,origin,height,face,rotation,projection,Color(0,0,0,opacity))
	var foot_points := frame_contact_points(frame,height,face,rotation)
	_draw_actor_shadow(origin,height,z,height * .19,0,contacts if foot_points.is_empty() else [])
	var contact_alpha := maxf(0,1.0-z/42.0)
	for foot in foot_points:
		var at: Vector2 = origin + Vector2(foot.offset)
		for layer in range(3):
			_ellipse(at,Vector2(float(foot.width)+3-layer*2,height*.026-layer*.8),Color(0,0,0,(.17+layer*.06)*contact_alpha))

func _draw_art_fighter(fighter: Dictionary, origin: Vector2) -> bool:
	var hero := str(fighter.get("kind", ""))
	if not _art.heroes.has(hero) and not _art.has_animation(hero):
		return false
	var action := str(fighter.get("action", "idle"))
	var z := float(fighter.get("z", 0))
	var sample := _fighter_animation(fighter)
	var animated: bool = sample.source in ["v04", "v05", "v06", "v07", "v09", "v10", "v11", "v12", "v13", "v14", "v15", "v16", "v17", "v22"]
	var pose := ArtAssets.pose_for(action, z, state.get("phase", "") == "won" and not state.get("victory_looting",false))
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
	var height := (225.0 if hero == "oichi" else 240.0) if art_demo else float(FrameAnimation.CombatMoves.HEIGHTS[hero])
	var face := -1.0 if float(fighter.get("face", 1)) < 0 else 1.0
	var clock := _art_clock()
	var rotation := 0.0
	var down := action in ["down", "defeated", "dead"]
	if down and not art_demo and not _art.has_v06(hero) and sample.source not in ["v10","v11","v12","v13","v14","v15","v16","v17","v22"]:
		rotation = -1.3 * face
	elif action == "thrown" and sample.source not in ["v10","v11","v12","v13","v14","v15","v16","v17","v22"]:
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
	if _shadow_pass:
		_draw_pose_shadow(frame,origin,height,face,rotation,z,contacts,fighter)
		return true
	draw_set_transform(origin, 0, Vector2(1, 0.28))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([origin + Vector2(-5, 12), origin + Vector2(5, 12), origin + Vector2(0, 6)]), player_color)
	Typography.draw_label(self,origin + Vector2(-9,27),"%dP" % (int(fighter.get("player_index",0)) + 1),14,player_color)
	var tint := _scene_light()
	if int(fighter.get("invuln", 0)) > 0 and action != "special" and int(clock * 60) % 6 < 3:
		tint = Color(1.5, 1.5, 1.5, 0.72)
	tint.a *= low_health_alpha(fighter,int(state.get("tick",0)))
	_fx.draw_status(self,fighter,origin-Vector2(0,z),height,false)
	_draw_hero_power(fighter, origin, height, sample, false)
	if pickup_flash_visible(fighter,int(state.get("tick",0))):
		for offset in [Vector2(-3,0),Vector2(3,0),Vector2(0,-3),Vector2(0,3),Vector2(-2,-2),Vector2(2,-2),Vector2(-2,2),Vector2(2,2)]:
			_draw_art_frame(frame,origin - Vector2(0,z) + offset,height,face,rotation,Color(3.2,4.0,2.3,0.9),float(frame.body_height))
	_weapons.draw_weapon(self,fighter,frame,origin - Vector2(0,z),height,face,rotation,tint,true)
	_draw_art_frame(frame, origin - Vector2(0, z), height, face, rotation, tint, float(frame.body_height))
	_weapons.draw_weapon(self,fighter,frame,origin - Vector2(0,z),height,face,rotation,tint,false)
	_weapons.draw_hand_occlusion(self,frame,origin - Vector2(0,z),height,face,rotation,tint)
	_draw_hero_power(fighter, origin, height, sample, true)
	_draw_status(fighter, origin, height)
	_draw_buff(fighter,origin,height,frame,face,rotation)
	if int(fighter.get("poison", 0)) > 0:
		for bubble in range(3):
			draw_circle(origin + Vector2(-20 + bubble * 20, -z - 48 - fposmod(clock * 30 + bubble * 12, 60.0)), 3, Color("95b660"))
	return true

static func low_health_alpha(fighter: Dictionary, tick: int) -> float:
	if int(fighter.get("team",0)) != 0 or float(fighter.get("hp",0)) <= 0 or float(fighter.hp) >= float(fighter.get("max_hp",1)) * .25: return 1.0
	return .55 + .45 * (.5 + .5 * cos(float(tick) * TAU / 150.0))

static func buff_icon(fighter: Dictionary) -> String:
	if int(fighter.get("shield_points",0)) <= 0 or int(fighter.get("hp",0)) <= 0: return ""
	var spec: Dictionary = FrameAnimation.Battle.TALISMANS.get(str(fighter.get("shield_kind","")),{})
	if spec.is_empty(): return ""
	return str(spec.icons[0])

static func frame_visible_top(frame: Dictionary, height: float, face: float = 1.0, rotation: float = 0.0) -> float:
	var top := INF
	for layer in frame.get("layers",[frame]):
		var bounds: Rect2 = layer.get("opaque_bounds",Rect2(Vector2.ZERO,layer.region.size))
		var corners := PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
		for point in layer.get("clip_polygon",corners):
			var offset := ((Vector2(point)-Vector2(layer.anchor)) * height / float(frame.body_height) * Vector2(face,1)).rotated(rotation)
			top = minf(top,offset.y)
	return top

static func buff_rect(frame: Dictionary, height: float, face: float = 1.0, rotation: float = 0.0) -> Rect2:
	# Helmets and reaction poses extend above the nominal body height.
	return Rect2(Vector2(-10,frame_visible_top(frame,height,face,rotation)-38),Vector2(20,24))

static func enemy_health_rect(frame: Dictionary, height: float, face: float = 1.0, rotation: float = 0.0) -> Rect2:
	return Rect2(-27,frame_visible_top(frame,height,face,rotation)-27,54,7)

func _draw_enemy_health(fighter: Dictionary, rect: Rect2) -> void:
	draw_rect(rect,INK)
	var fill := rect.grow(-1)
	fill.size.x *= clampf(float(fighter.hp) / maxf(1,float(fighter.get("max_hp",100))),0,1)
	draw_rect(fill,RED)
	var rim := Color("a98b54")
	draw_rect(rect.grow(-.5),rim,false,1)
	for x in [rect.position.x-2,rect.end.x+2]:
		var end := Vector2(x,rect.get_center().y)
		var ornament := PackedVector2Array([end+Vector2(-3,0),end+Vector2(0,-3),end+Vector2(3,0),end+Vector2(0,3),end+Vector2(-3,0)])
		draw_colored_polygon(ornament,INK)
		draw_polyline(ornament,rim,1)

func _draw_buff(fighter: Dictionary, origin: Vector2, height: float, frame: Dictionary, face: float, rotation: float) -> void:
	var icon := buff_icon(fighter)
	if icon.is_empty(): return
	var at := origin - Vector2(0,float(fighter.get("z",0))) + buff_rect(frame,height,face,rotation).get_center()
	var icons: Array = FrameAnimation.Battle.TALISMANS[fighter.shield_kind].icons
	for index in range(icons.size()): _draw_buff_symbol(str(icons[index]),at+Vector2((index-(icons.size()-1)*.5)*24,0))

func _draw_buff_symbol(icon: String, at: Vector2) -> void:
	var color := Color("9bdce899")
	draw_set_transform(at)
	match icon:
		"shield":
			var shield := PackedVector2Array([Vector2(-9,-10),Vector2(0,-12),Vector2(9,-10),Vector2(8,3),Vector2(0,12),Vector2(-8,3)])
			draw_colored_polygon(shield,Color(color,.35))
			shield.append(shield[0])
			draw_polyline(shield,color,1.5,true)
			draw_line(Vector2(0,-7),Vector2(0,6),color,1.5,true)
		"speed":
			for y in [-6,0,6]:
				draw_line(Vector2(-9,y),Vector2(6,y),color,2,true)
				draw_arc(Vector2(6,y-3),3,-PI*.5,PI*.5,8,color,2,true)
		"attack":
			color = Color("ffd38e99")
			draw_colored_polygon(PackedVector2Array([Vector2(-3,3),Vector2(-3,-6),Vector2(0,-12),Vector2(3,-6),Vector2(3,3)]),color)
			draw_line(Vector2(-7,4),Vector2(7,4),color,2,true)
			draw_line(Vector2(0,4),Vector2(0,11),color,3,true)
		"reach":
			color = Color("dbbaff99")
			draw_line(Vector2(-9,0),Vector2(9,0),color,2,true)
			for side in [-1,1]:
				draw_polyline(PackedVector2Array([Vector2(side*4,-6),Vector2(side*9,0),Vector2(side*4,6)]),color,2,true)
		"tempo":
			draw_polyline(PackedVector2Array([Vector2(-7,-10),Vector2(7,-10),Vector2(0,0),Vector2(7,10),Vector2(-7,10),Vector2(0,0),Vector2(-7,-10)]),color,1.5,true)
		"food":
			draw_arc(Vector2(0,-2),9,0,PI,16,Color("a7df9399"),2,true)
			draw_line(Vector2(-9,-2),Vector2(9,-2),Color("a7df9399"),2,true)
			for x in [-4,0,4]: draw_line(Vector2(x,-10),Vector2(x,-6),color,1.5,true)
		"flame":
			draw_colored_polygon(PackedVector2Array([Vector2(0,-11),Vector2(8,2),Vector2(4,9),Vector2(-5,9),Vector2(-8,2)]),Color("efa77970"))
			draw_line(Vector2(-9,11),Vector2(9,-11),color,1.5,true)
		"snow":
			for angle in [0.0,PI/3,PI*2/3]: draw_line(Vector2(9,0).rotated(angle),Vector2(-9,0).rotated(angle),color,1.5,true)
			draw_line(Vector2(-8,11),Vector2(8,-11),Color("dbbaff99"),1.5,true)
		"leaf":
			draw_colored_polygon(PackedVector2Array([Vector2(-7,8),Vector2(-8,-2),Vector2(7,-10),Vector2(8,2)]),Color("a7df9366"))
			draw_line(Vector2(-8,10),Vector2(7,-9),Color("a7df9399"),2,true)
		"heavy":
			draw_rect(Rect2(-9,-9,18,7),Color("ffd38e99"))
			draw_line(Vector2(0,-2),Vector2(0,11),Color("ffd38e99"),3,true)
		"charge":
			draw_polyline(PackedVector2Array([Vector2(5,-11),Vector2(-6,0),Vector2(5,0),Vector2(-4,11)]),Color("ffd38e99"),3,true)
		"air":
			draw_polyline(PackedVector2Array([Vector2(-8,-1),Vector2(0,-10),Vector2(8,-1)]),color,2,true)
			draw_line(Vector2(0,-8),Vector2(0,9),color,2,true)
		"throw":
			draw_arc(Vector2(-1,0),8,PI*.5,PI*1.7,16,color,2,true)
			draw_polyline(PackedVector2Array([Vector2(2,-10),Vector2(8,-6),Vector2(3,-3)]),color,2,true)
		"rage":
			draw_colored_polygon(PackedVector2Array([Vector2(-7,8),Vector2(-8,0),Vector2(-3,-6),Vector2(0,-2),Vector2(5,-11),Vector2(8,3),Vector2(5,8)]),Color("e8b27599"))
		"special":
			for angle in [0.0,PI*.5,PI*.25,PI*.75]: draw_line(Vector2(-10,0).rotated(angle),Vector2(10,0).rotated(angle),Color("dbbaff99"),1.5,true)
		"push":
			for x in [-5,3]: draw_polyline(PackedVector2Array([Vector2(x-4,-7),Vector2(x+3,0),Vector2(x-4,7)]),Color("ffd38e99"),2,true)
	draw_set_transform(Vector2.ZERO)

static func shield_glow_color(_fighter: Dictionary) -> Color:
	return Color.TRANSPARENT

static func pickup_flash_visible(fighter: Dictionary, tick: int) -> bool:
	var elapsed := tick - int(fighter.get("pickup_flash_tick",-1000))
	return elapsed >= 0 and elapsed < 30 and elapsed % 10 < 6

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
	var frame := _art.animation_frame(str(fighter.get("kind","")),sample)
	if frame.get("combat_v33",false):
		if fighter.kind == "nobunaga" and fighter.action in ["light","heavy","dash_heavy"]:
			_fx.draw_nobunaga_cut(self,fighter,ground,height,sample,frame,front)
			return
		var layer_key := "fx" if front else "fx_back"
		if frame.combat_layers.has(layer_key):
			var fx: Dictionary = frame.combat_layers[layer_key]
			var factor := 1.0
			var hand := Vector2.ZERO
			if fighter.kind == "nobunaga" and not frame.get("authored_weapon",false) and str(sample.clip) in ["light_1","light_2","light_3","charge_release","air_light","air_heavy","dash_heavy"]:
				var weapon := _weapons.geometry(fighter,frame,height)
				if not weapon.is_empty():
					factor = float(weapon.scale)*float(_weapons.items[weapon.id].length)/(114.08*height/155.0)
					hand = Vector2(weapon.hand)*Vector2(float(fighter.get("face",1)),1)
			if fighter.kind == "nobunaga" and str(sample.clip) in ["charge_release","air_heavy"]:
				factor *= FrameAnimation.Battle.NOBUNAGA_HEAVY_RANGE_SCALE
			_draw_art_frame(fx,ground-Vector2(0,float(fighter.get("z",0)))+hand*(1-factor),height*factor,float(fighter.get("face",1)),0,Color.WHITE,float(fx.body_height))
		if str(fighter.get("kind","")) == "tadakatsu" and str(sample.get("clip","")) == "charge_release":
			_draw_tadakatsu_charge_ring(fighter, ground, front)
		_fx.draw_light_follow(self, fighter, ground, sample, frame, front)
		return
	if _fx.draw_actor(self,fighter,ground,height,sample,frame,front): return
	var clip := str(sample.clip)
	if fighter.get("kind","") == "tadakatsu" and sample.get("source","") in ["v17","v22"]:
		if fighter.get("action","") == "charge" or clip == "charge" or (clip in ["ground_slam","charged_slam"] and not sample.released):
			_draw_spear_charge_aura(fighter,ground,height,sample,front)
		elif clip == "special": _draw_special_aura(fighter,ground,height,front)
		elif clip not in ["ground_slam","charged_slam"]: _draw_strike_accent(fighter,ground,height,sample,front)
		return
	if str(fighter.get("kind","")) in ["nobunaga","oichi","hideyoshi"] or (clip == "dash_heavy" and sample.get("source","") != "v16"):
		_draw_strike_accent(fighter,ground,height,sample,front)
	if fighter.get("action","") == "charge" or clip == "charge" or (fighter.get("kind","") == "oichi" and fighter.get("action","") == "charged" and float(sample.tick) < 14):
		if not (fighter.get("kind","") == "tadakatsu" and sample.get("source","") == "v16"):
			_draw_charge(fighter,ground,height,sample,front)
		return
	if clip == "special":
		_draw_special_aura(fighter,ground,height,front)
		return
	if not front or not sample.released: return
	if str(fighter.get("kind","")) in ["nobunaga","oichi","hideyoshi"]: return
	if str(fighter.get("kind", "")) == "tadakatsu" and sample.get("source","") == "v16": return
	if clip in ["heavy","charged","rising","upper_heavy","charged_upper","ground_slam","charged_slam","low_sweep","dash_strike","air_light","air_heavy","mixed_finisher","mixed_rising","counter_cut"]:
		_draw_technique_trail(fighter,ground - Vector2(0,float(fighter.get("z",0))),height,sample)

func _draw_tadakatsu_charge_ring(fighter: Dictionary, ground: Vector2, front: bool) -> void:
	if _fx.shared_player == null: return
	var ring: Dictionary = FrameAnimation.Battle.tadakatsu_charged_area(fighter)
	var now := FrameAnimation.Battle.combat_time_ms(fighter)
	var bloom := 0.28
	for hit_ms in [190.0, 720.0]:
		var delta: float = now - hit_ms
		if delta < -160.0: continue
		if delta < 0.0: bloom = maxf(bloom, lerpf(0.28, 1.0, (delta + 160.0) / 160.0))
		else: bloom = maxf(bloom, lerpf(1.0, 0.45, clampf(delta / 460.0, 0.0, 1.0)))
	_fx.shared_player.draw_phase(self, "blade_ring", now * 0.06, 90.0, ground - Vector2(0, float(ring.lift) + float(fighter.get("z", 0))), front, {"opacity": [[0, bloom], [1, bloom]], "uv_radians_per_second": [[0, TAU * 1.4], [1, TAU * 1.4]]}, {"face": float(fighter.get("face", 1)), "size": float(ring.size)})

func _draw_spear_charge_aura(fighter: Dictionary, ground: Vector2, height: float, sample: Dictionary, front: bool) -> void:
	var power := charge_visual(float(sample.tick) if art_demo else float(fighter.get("charge",0)),height)
	var amount: float = power.amount
	var color := Color("dab774")
	color.a = .10 + amount * .48
	var radius: float = height * (.24 + amount * .56)
	draw_set_transform(ground,0,Vector2(1,.32))
	draw_arc(Vector2.ZERO,radius,0.0 if front else PI,PI if front else TAU,48,color,1.0 + amount * 3.0,true)
	if amount > .5:
		color.a *= .45
		draw_arc(Vector2.ZERO,radius * 1.14,0.0 if front else PI,PI if front else TAU,48,color,1.0 + amount,true)
	draw_set_transform(Vector2.ZERO)
	if not front:
		_draw_dust(ground,radius,.25 + amount * .45,.08 + amount * .32)
		for side in [-1,1]:
			for index in range(4):
				var age := fposmod(_art_clock() * (.65 + amount * .75) + index * .25,1.0)
				var point := ground + Vector2(side * radius * (.75 + index * .06),-age * height * (.25 + amount * .95))
				_paint_streak(point,Vector2.UP,6.0 + amount * 28.0,1.0 + amount * 2.0,Color("c7adcf"),(1.0 - age) * amount * .6)

static func strike_accent(fighter: Dictionary, sample: Dictionary) -> Dictionary:
	var hero := str(fighter.get("kind",""))
	if hero == "tadakatsu" and sample.get("source","") == "v16": return {}
	var action := str(fighter.get("action",sample.get("clip","idle")))
	var tick := float(sample.get("tick",0))
	var key := action
	if action == "light": key += str(fighter.get("combo",1))
	elif action == "heavy": key += str(fighter.get("heavy_combo",1))
	var hit: float = {"light":6,"heavy":14,"charged":14,"rising":6,"low_sweep":9,"upper_heavy":12,"charged_upper":22,"ground_slam":14,"charged_slam":28,"air_light":6,"air_heavy":12,"dash_strike":10,"dash_heavy":12,"counter_cut":5,"mixed_finisher":9,"mixed_rising":9}.get(action,-1)
	if hero == "tadakatsu" and action == "charged":
		hit = 5
		for pulse in [10,15]:
			if tick >= pulse: hit = pulse
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
	return {"path":profiles[key],"age":age,"power":power,"key":key,"bow":hero == "oichi" and key not in ["light3","dash_heavy"],"thrust":(key == "dash_heavy" and hero in ["hideyoshi","tadakatsu"]) or (hero == "tadakatsu" and key in ["charged","dash_strike"]),"low":key in ["low_sweep","ground_slam","charged_slam"],"shock":key in ["heavy2","charged","ground_slam","charged_slam","special","dash_heavy"]}

static func strike_radius(fighter: Dictionary, style: Dictionary, height: float) -> float:
	if fighter.get("kind","") == "nobunaga" and fighter.get("action","") == "heavy":
		# The visible ribbon's outer edge shares the core's normal-heavy reach.
		var bonus := float(WeaponRenderer.Weapons.item(WeaponRenderer.equipped_id(fighter)).get("reach_bonus",0)) + float(fighter.get("treasure_reach",0))
		var reach := float(fighter.get("attack_reach",0))
		if reach <= 0: reach = FrameAnimation.Battle.nobunaga_heavy_reach(int(fighter.get("heavy_combo",1))) + bonus
		return reach * height / 155.0 - 9.0 - float(style.path[1]) * .5
	return height * float(style.path[0])

func _draw_strike_accent(fighter: Dictionary, ground: Vector2, height: float, sample: Dictionary, front: bool) -> void:
	if fighter.get("kind","") == "hideyoshi" and fighter.get("action","") == "charged_slam": return
	if fighter.get("kind","") in ["nobunaga","hideyoshi"] and sample.get("source","") == "v22" and (fighter.get("action","") == "light" or (fighter.get("kind","") == "hideyoshi" and fighter.get("action","") in ["heavy","charged","dash_heavy"])):
		if not front or int(sample.frame) not in [2,3,4]: return
		var previous := sample.duplicate()
		previous.frame = int(sample.frame) - 1
		previous.cell = previous.frame
		var hero := str(fighter.kind)
		var trail := _weapons.sweep_trail(fighter,_art.animation_frame(hero,sample),_art.animation_frame(hero,previous),height)
		if trail.size() >= 3:
			var fade := clampf((17.0 - float(sample.tick)) / 4.0,0,1) if hero == "nobunaga" else 0.55
			draw_set_transform(ground - Vector2(0,float(fighter.get("z",0))),0,Vector2(float(fighter.get("face",1)),1))
			draw_colored_polygon(trail,Color(1,.93,.74,.38 * fade))
			draw_polyline(trail.slice(0,13),Color(1,.97,.86,.66 * fade),1.4,true)
			draw_set_transform(Vector2.ZERO)
		return
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
	var radius := strike_radius(fighter,style,height)
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
		var flame_radius: float = radius - float(path[1]) * .5 - 6.0 if fighter.get("action","") == "heavy" else radius
		for i in range(7):
			var angle := lerpf(tail,head,float(i) / 6.0)
			var point := center + Vector2(face * cos(angle) * flame_radius,sin(angle) * flame_radius * path[4])
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
	var shared_status := _fx.draw_status(self,fighter,origin,height)
	var clock := _art_clock()
	if not shared_status and int(fighter.get("burn",0)) > 0:
		for i in range(9):
			var age := fposmod(floor(clock * 12) * 0.12 + i * 0.17,1)
			var base := origin + Vector2(sin(i * 2.4) * height * 0.22,-height * (0.05 + age * 0.78))
			_paint_flame(base,height * (0.18 + i % 3 * 0.05),i,0.85 * (1.0 - age))
	if not shared_status and int(fighter.get("freeze",0)) > 0:
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
	var genuine_reaction: bool = sample.get("genuine_reaction",false) or sample.sheet == "enemy_reaction" or sample.source in ["v14","v19"]
	var frame: Dictionary = sample.frame_data if sample.source in ["stage3","stage4","stage5","stage0710"] else _art.enemy_frame(kind,int(sample.cell),enemy_art_faction(fighter),str(sample.sheet))
	if sample.source != "v14" and kind == "boss" and fighter.get("faction","mori") == "mori" and fighter.get("action", "") == "boss_chain" and int(sample.cell) == 6 and frame.has("hand_offset") and frame.has("clip_polygon"):
		# The live chain replaces the atlas's short demonstration weight beyond the casting hand.
		var cutoff: float = frame.anchor.x + frame.hand_offset.x + 6.0
		var crop := PackedVector2Array([Vector2.ZERO,Vector2(cutoff,0),Vector2(cutoff,frame.region.size.y),Vector2(0,frame.region.size.y)])
		var clipped := Geometry2D.intersect_polygons(frame.clip_polygon,crop)
		if not clipped.is_empty():
			frame = frame.duplicate()
			frame.clip_polygon = clipped[0]
	var height := enemy_display_height(fighter)
	var action := str(fighter.get("action", "idle"))
	var face := float(fighter.get("face", 1)) * int(sample.get("native_face",1))
	var z := float(fighter.get("z", 0))
	var down := action in ["down", "dead", "defeated", "thrown", "launched"]
	var rotation := -1.25 * face if down else (-0.13 * face if action in ["hurt", "grabbed", "pulled"] else 0.0)
	if action in ["thrown","launched"]: rotation = clampf(float(fighter.get("vz",0)) * -0.09 - 1.1,-1.9,-0.3) * face
	elif action == "recovering": rotation = -1.25 * face * (1.0 - clampf(float(fighter.get("action_tick",0)) / 36.0,0,1))
	elif action == "stunned": rotation = sin(float(fighter.get("action_tick",0)) * 0.14) * 0.16
	if genuine_reaction: rotation = 0.0
	var tint := Color(0.67,0.86,1) if int(fighter.get("freeze",0)) > 0 else _scene_light()
	if int(fighter.get("invuln",0)) > 0 and int(state.get("tick",0)) % 6 < 3: tint = Color(1.35,1.12,1.05,0.85)
	var body_origin := origin - Vector2(0, z)
	if action == "grabbed" and int(fighter.get("held_by",0)) != 0:
		rotation = sin(float(fighter.get("action_tick",0)) * 0.10) * 0.018
		var grip := Vector2(0,-height * 0.78)
		body_origin += grip - grip.rotated(rotation)
	if down and not genuine_reaction: body_origin += Vector2(face * height * 0.33, -height * 0.09)
	if _shadow_pass:
		_draw_pose_shadow(frame,body_origin + Vector2(0,z),height,face,rotation,z,[-height * .18,height * .18])
		if not down and sample.source not in ["stage3","stage4","stage5","stage0710"]: _draw_role_shadow(fighter,body_origin + Vector2(0,z),height,face,z,frame)
		return true
	_fx.draw_status(self,fighter,origin-Vector2(0,z),height,false)
	_officer_weapon_fx.draw(self,fighter,sample,body_origin,height,face,rotation,true)
	if frame.has("behind"): _draw_art_frame(frame.behind,body_origin,height,face,0,Color.WHITE,float(frame.body_height))
	_draw_art_frame(frame, body_origin, height, face, rotation, tint, float(frame.body_height))
	_officer_weapon_fx.draw(self,fighter,sample,body_origin,height,face,rotation,false)
	if fighter.has("s05_role"): _stage05_art.actor_fx(self,fighter,body_origin)
	if fighter.has("expedition_role"): _stage0710_art.actor_fx(self,fighter,body_origin)
	if frame.has("crest"):
		var scale: float = height/float(frame.body_height)
		var at: Vector2 = body_origin+(frame.crest.anchor-frame.anchor)*Vector2(face,1)*scale
		var width: float = frame.crest.width*scale
		draw_texture_rect(frame.crest.texture,Rect2(at-Vector2.ONE*width*.5,Vector2.ONE*width),false,tint)
	if sample.source not in ["stage3","stage4","stage5","stage0710"]: _draw_enemy_role(fighter,body_origin,height,face,down,frame,sample)
	if fighter.get("is_yoshimoto",false) and fighter.action == "guard":
		var guard_at := body_origin + Vector2(face*25,-height*.55)
		draw_set_transform(guard_at,0,Vector2(face,1))
		draw_arc(Vector2.ZERO,50,-1.2,1.2,24,GOLD,5,true)
		draw_set_transform(Vector2.ZERO)
	_draw_status(fighter, origin, height)
	var attack_warning: bool = not fighter.has("mikawa_role") and FrameAnimation.Battle.ENEMY_TIMING.has(action) and not sample.released and int(fighter.get("freeze",0)) == 0
	if attack_warning:
		var warning := origin - Vector2(0,z + height + 16)
		draw_line(warning - Vector2(0,10), warning, GOLD, 3)
		draw_circle(warning + Vector2(0,5), 2, GOLD)
	if float(fighter.get("hp",0)) > 0:
		var bar := enemy_health_rect(frame,height,face,rotation)
		if fighter.has("mikawa_role"): bar = Rect2(-30,-height-18,60,6)
		bar.position += body_origin
		if attack_warning: bar.position.y = minf(bar.position.y,origin.y-z-height-37)
		_draw_enemy_health(fighter,bar)
		if fighter.get("stage_boss",false) and not fighter.has("mikawa_role") and fighter.get("faction","") != "oda":
			Typography.draw_label(self,bar.position-Vector2(21,7),str(fighter.get("display_name","")),18,Typography.GOLD)
	return true

func _draw_role_shadow(fighter: Dictionary, origin: Vector2, height: float, face: float, z: float, frame: Dictionary) -> void:
	var role := str(fighter.get("role",""))
	if role != "shield_spear" or not frame.has("shield_anchor"): return
	var scale := height / 146.0
	var projection := shadow_projection(origin,z,str(state.get("stage",{}).get("theme","")))
	draw_set_transform_matrix(projection * Transform2D(0,Vector2(face*scale,scale),0,Vector2.ZERO))
	var tint := Color(0,0,0,lerpf(.39,.17,clampf(z/150.0,0,1)))
	var shield: Dictionary = _art.stage2_equipment.shield
	var hand: Vector2 = frame.shield_anchor * 146.0 / float(frame.body_height)
	draw_texture_rect_region(shield.texture,Rect2(hand-Vector2(16,19.5),Vector2(32,65)),shield.region,tint)
	draw_set_transform(Vector2.ZERO)

func _draw_enemy_role(fighter: Dictionary, origin: Vector2, height: float, face: float, down: bool, frame: Dictionary, sample: Dictionary) -> void:
	var role := str(fighter.get("role",""))
	if role.is_empty() or down or float(fighter.get("hp",0)) <= 0: return
	var scale := height / 146.0
	if role == "shield_spear":
		if not frame.has("shield_anchor"): return
		var hand: Vector2 = frame.shield_anchor * height / float(frame.body_height)
		_draw_art_frame(_art.stage2_equipment.shield,origin+hand*Vector2(face,1),65*scale,face,0,_scene_light(),float(_art.stage2_equipment.shield.body_height))
	elif role == "fire_archer" and sample.clip == "bow_shot" and not sample.released and frame.has("hand_offset"):
		var tip: Vector2 = frame.hand_offset * height / float(frame.body_height) * Vector2(face,1)
		if _fx.configured: _fx.shared_player.draw_phase(self,"fire_burn",float(state.get("tick",0)),600,origin+tip,true,{"opacity":[[0,.8],[1,.8]]},{"size":24,"face":face})

static func enemy_art_faction(fighter: Dictionary) -> String:
	var faction := str(fighter.get("faction","mori"))
	return faction

static func enemy_display_height(fighter: Dictionary) -> float:
	if Stage0710Art.Data.BOSSES.has(str(fighter.get("expedition_role",""))): return Stage0710Art.height(fighter)
	if fighter.has("s05_role"): return Stage05Art.Data.height(fighter.s05_role)
	var kind: String = str(fighter.get("kind","soldier"))
	var height := (155.0 if fighter.get("stage_boss",false) else 163.0) if kind == "boss" else (158.0 if kind == "commander" else 146.0)
	return height * float(fighter.get("render_scale",1.0))

static func shattered_defeat(fighter: Dictionary) -> bool:
	if fighter.get("kind","") == "boss" and fighter.has("death_ticks"): return false
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
	if effect.get("visual_exact_origin",false): return Vector2.ZERO
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
			if sample.source in ["stage3","stage0710"]:
				var height := enemy_display_height(fighter)
				return Vector2(24.0 * float(effect.get("face",1)),float(effect.get("start_z",40))-height*.62)
			var frame := _art.enemy_frame(str(fighter.kind),int(sample.cell),enemy_art_faction(fighter),str(sample.sheet))
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
	if effect.get("descending",false) and not effect.get("visual_exact_origin",false): velocity += Vector2(release_offset.x,release_offset.y - 96.0) * float(effect.get("vz",0)) / maxf(1.0,float(effect.get("start_z",1)))
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
	if kind == "weapon" and _weapons.draw_drop(self,drop,p,_art_clock()): return
	if kind == "talisman" and FrameAnimation.Battle.TALISMANS.has(str(drop.get("talisman_id",""))):
		var key := str(drop.talisman_id)
		var image_key: String = {"kongo":"vajra","iron":"iron","mirror":"mirror"}[FrameAnimation.Battle.TALISMANS[key].image]
		var texture: Texture2D = _treasures[image_key]
		var size := texture.get_size() * 56.0 / texture.get_height()
		var hover := 6.0 + sin(_art_clock() * 3.2 + float(drop.get("x",0))) * 3.0
		_ellipse(p,Vector2(27,8),Color(.08,.12,.08,.45))
		var color := Color(str(FrameAnimation.Battle.TALISMANS[key].color))
		draw_arc(p - Vector2(0,12),31,PI,TAU,28,Color(color,.7),2,true)
		draw_texture_rect(texture,Rect2(p - Vector2(size.x * .5,size.y + hover),size),false)
		Typography.draw_label(self,p+Vector2(-110,23),str(FrameAnimation.Battle.TALISMANS[key].name),16,GOLD,220,HORIZONTAL_ALIGNMENT_CENTER)
		return
	if kind == "food":
		var food: Dictionary = _stage_art.food.get(str(drop.get("food_id","rice")),{})
		if not food.is_empty():
			var hover := 5.0 + sin(_art_clock()*3.2 + float(drop.get("x",0)))*3.0
			_ellipse(p,Vector2(29,8),Color(.08,.12,.08,.45))
			draw_arc(p-Vector2(0,16),34,PI,TAU,28,Color(.98,.84,.37,.7),2,true)
			_draw_art_frame(food,p-Vector2(0,hover),float(food.display_height),1,0,Color.WHITE,float(food.body_height))
			return
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
		if int(fighter.get("team",0)) != 0: return
		# A lethal hit and its death state may arrive in separate snapshots.
		fighter = fighter.duplicate()
		fighter.action = "dead"
		action = "dead"
	var origin := Vector2(float(fighter.get("x", 0)) - camera_x, float(fighter.get("y", 470)))
	if origin.x < -180 or origin.x > 1460:
		return
	var team := int(fighter.get("team", 0))
	var kind := str(fighter.get("kind", "soldier"))
	if kind == "dummy":
		_draw_dummy(fighter, origin)
		if not _shadow_pass: _draw_status(fighter,origin,138.0)
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
	if team != 0: size = enemy_display_height(fighter) / 116.0
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
	if _shadow_pass:
		_draw_actor_shadow(origin,116.0 * size,jumping,28.0 * size,6.0 * size * face,[(-9.0-stride)*size*face,(21.0+stride)*size*face])
		return
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
		var body := {"region":Rect2(-27,-130,54,130),"opaque_bounds":Rect2(-27,-130,54,130),"anchor":Vector2.ZERO,"body_height":116.0}
		var bar := enemy_health_rect(body,116*size,face,rotation)
		bar.position += origin - Vector2(0,jumping+breath)
		_draw_enemy_health(fighter,bar)

func _draw_dummy(fighter: Dictionary, origin: Vector2) -> void:
	var z := float(fighter.get("z", 0))
	var tick := float(fighter.get("action_tick", 0))
	var action := str(fighter.get("action", "idle"))
	var hurt := action == "hurt" or int(fighter.get("shield_hurt_tick", 0)) > 0
	var tilt := sin(tick * 0.75) * 0.10 * exp(-tick * 0.12) if hurt else 0.0
	if action == "down": tilt = -0.42 * float(fighter.get("face", 1))
	elif action == "grabbed": tilt = -0.12 * float(fighter.get("face", 1))
	elif action == "thrown": tilt = -(0.65 + (30.0 - float(fighter.get("throw_ticks", 30))) * 0.065) * float(fighter.get("face", 1))
	if _shadow_pass:
		_draw_actor_shadow(origin,138.0,z,32.0,0.0,[-21.0,21.0])
		return
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
	if effect.get("expedition_warning",false):
		_stage0710_art.draw_attack_warning(self,effect)
		return
	var p := Vector2(float(effect.get("x",0)) - camera_x,float(effect.get("y",460)))
	if _fx.draw_ground(self,effect,p): return
	var radius := float(effect.get("radius",85))
	var age := 1.0 - float(effect.get("life",0)) / maxf(float(effect.get("max_life",1)),1)
	var kind := str(effect.get("type",""))
	if kind == "fire_patch" or (kind == "arrow_target" and effect.get("element","") == "fire"):
		var warmup := kind == "arrow_target" or int(effect.get("max_life",150))-int(effect.get("life",150)) < int(effect.get("warmup",30))
		var pulse := .5 + .5 * sin(_art_clock()*10)
		_ellipse(p,Vector2(radius,radius/1.8),Color(1,.23,.06,.08+.07*pulse))
		draw_set_transform(p,0,Vector2(1,1.0/1.8))
		draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(1,.44,.13,.64+.2*pulse),2.2,true)
		draw_set_transform(Vector2.ZERO)
		if not warmup:
			for i in range(9):
				var base := p+Vector2(sin(i*2.4)*radius*.77,cos(i*2.4)*radius*.37)
				_paint_flame(base,24+i%3*12,i,clampf(float(effect.life)/20,0,1)*.75)
		return
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

func _draw_arrow_rain(effect: Dictionary, behind: bool) -> void:
	var ground := Vector2(float(effect.x)-camera_x,float(effect.y))
	var age := float(effect.max_life)-float(effect.life)
	var opacity := clampf(float(effect.life)/8,0,1)
	for index in range(70):
		var angle := float(index)*2.399963
		var radius := sqrt((float(index)+.5)/70.0)*float(effect.radius)
		var landing := ground+Vector2(cos(angle)*radius,sin(angle)*radius*.2)
		if (landing.y < ground.y) != behind: continue
		var progress := clampf((age-float(index%7))/18.0,0,1)
		if progress<1 and age>=index%7: _draw_arrow(landing-Vector2(0,(1-progress)*440),Vector2.DOWN,false,opacity)
		elif progress>=1 and age<36: draw_line(landing-Vector2(0,19),landing,Color(.94,.87,.69,opacity*.7),1.2,true)

func _draw_effect(effect: Dictionary) -> void:
	if effect.type in ["s05_fx","s05_wave","s05_roar"] or effect.get("s05_arrow",false):
		_stage05_art.effect(self,effect)
		return
	if effect.has("mikawa_projectile") or effect.type == "mikawa_fx":
		_stage04_art.effect(self,effect)
		return
	var ground := Vector2(float(effect.get("x", 0)) - camera_x, float(effect.get("y", 460)))
	if effect.get("yoshimoto_projectile",false):
		var point := ground - Vector2(0,float(effect.get("visual_height",float(effect.z)+42)))
		var direction := Vector2(float(effect.vx),float(effect.get("vy",0))).normalized()
		if effect.boss_wave:
			if _fx.configured:
				_fx.shared_player.draw_phase(self,"blade_wave",1,600,point,true,{"opacity":[[0,.8],[1,.8]]},{"face":effect.face,"size":360,"stretch":Vector2(.55,1)})
				return
			draw_set_transform(point,direction.angle())
			draw_arc(Vector2(-20,0),150,-1.15,1.15,24,Color("a3edf4"),12,true)
			draw_arc(Vector2(-20,0),150,-1.15,1.15,24,Color("f1ffff"),4,true)
			draw_set_transform(Vector2.ZERO)
		else: _draw_arrow(point,direction,false,1.0)
		return
	if _fx.draw_wave(self,effect,ground): return
	var p := ground - Vector2(0, 52)
	if _fx.draw_impact(self,effect,p): return
	var kind := str(effect.get("type", effect.get("kind", "hit")))
	var life := float(effect.get("life", effect.get("ttl", 12)))
	var opacity := clampf(life / 8.0, 0.0, 1.0)
	if kind == "sky_arrow":
		_draw_arrow(ground-Vector2(0,float(effect.z)),Vector2.UP,true)
		return
	if kind == "arrow_rain":
		_draw_arrow_rain(effect,false)
		return
	if kind == "projectile":
		if effect.get("combat_sword_wave",false):
			var age := float(effect.max_life-effect.life)
			_fx.shared_player.draw_phase(self,"blade_wave",age,float(effect.max_life),ground,true,{"opacity":[[0,.95],[.75,.9],[1,0]]},{"face":effect.face,"size":210.0,"stretch":Vector2(.72,1.0)})
			return
		var needle_pos := ground - Vector2(0, float(effect.get("z", 28)) + (42.0 if int(effect.get("team", 0)) == 1 else 96.0))
		# Freeze the release-hand offset, then preserve the core's flight displacement and collision state.
		var release_offset := _projectile_release_offset(effect)
		if effect.get("visual_exact_origin",false): needle_pos = ground-Vector2(0,float(effect.z))
		elif effect.get("arcing",false):
			needle_pos = arc_projectile_position(effect,camera_x,release_offset)
		elif effect.get("descending",false):
			var height_ratio := clampf(float(effect.get("z",0)) / maxf(1.0,float(effect.get("start_z",1))),0.0,1.0)
			needle_pos = ground - Vector2(0,float(effect.get("z",0))) + Vector2(release_offset.x,release_offset.y - 96.0) * height_ratio
		else: needle_pos += release_offset
		_fx.draw_tail(self,effect,needle_pos)
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
		if kind == "blade_wave" and effect.get("kind","") == "hideyoshi":
			var reach := float(effect.radius)
			var rising: bool = int(effect.get("combo",1)) == 2
			draw_set_transform(ground+Vector2(face*(reach-48),-62),0,Vector2(face,.75))
			draw_arc(Vector2.ZERO,48,-1.1,1.1,20,Color("e1e6ce",(1-age)*.6),3,true)
			draw_set_transform(Vector2.ZERO)
			_paint_streak(ground+Vector2(face*(reach-25),-62),Vector2(face*.3,-1 if rising else 1),48,2,Color("e1e6ce"),(1-age)*.45)
			return
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
		Typography.draw_label(self,position_now,amount,23,Color(Typography.GOLD,opacity))
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
				var frame := _art.enemy_frame(str(fighter.kind),int(sample.cell),enemy_art_faction(fighter),str(sample.sheet))
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


