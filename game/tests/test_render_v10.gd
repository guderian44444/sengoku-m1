extends SceneTree
const Frames = preload("res://render/frame_animation.gd")
const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")

func _initialize() -> void:
	for combo in [1,2,3]:
		var cells := []
		for tick in range(19):
			var sample := Frames.hero_v10_sample({"kind":"nobunaga","action":"light","action_tick":tick,"combo":combo})
			if not cells.has(sample.cell): cells.append(sample.cell)
		assert(cells == range(combo * 6,combo * 6 + 6),"Each light stage needs six distinct drawings")
	for action in ["guard","hurt","launched","down","stunned","recovering"]:
		var sample := Frames.hero_v10_sample({"kind":"oichi","action":action,"action_tick":14,"vz":3,"z":50})
		assert(sample.sheet == "reactions")
		assert(sample.cell / 6 == ["guard","hurt","launched","down","stunned","recovering"].find(action))
	var held := Frames.hero_v10_sample({"kind":"nobunaga","action":"guard","action_tick":60})
	assert(held.cell == 3)
	assert(Frames.hero_v10_sample({"action":"guard","guard_hit_tick":9}).cell == 4)
	assert(Frames.hero_v10_sample({"action":"guard","guard_hit_tick":3}).cell == 5)
	for hero in ["hideyoshi","ieyasu","mitsuhide","tadakatsu"]:
		for action in ["light","heavy","charged","charge","special","rising","low_sweep","ground_slam","charged_slam","charged_upper","air_light","air_heavy","dash_strike","mixed_finisher","counter_cut"]:
			var sample := Frames.hero_v10_sample({"kind":hero,"action":action,"action_tick":14,"combo":2})
			assert(sample.cell >= 0 and sample.cell < 36)
		assert(Frames.hero_v10_sample({"kind":hero,"action":"ground_slam","action_tick":20}).cell / 6 == 1)
		assert(Frames.hero_v10_sample({"kind":hero,"action":"charged_slam","action_tick":35}).cell / 6 == 3)
	for action in Battle.ENEMY_ATTACKS.soldier:
		var cells := []
		for tick in range(Battle.ENEMY_TIMING[action][1]):
			var sample := Frames.enemy_sample("soldier",action,tick,0,false,true)
			if not cells.has(sample.cell): cells.append(sample.cell)
		assert(cells.size() == 6)
	var ascending := View.projectile_direction({"vx":7,"vy":0,"vz":6})
	var descending := View.projectile_direction({"vx":7,"vy":0,"vz":-6})
	assert(ascending.x > 0 and ascending.y < 0)
	assert(descending.x > 0 and descending.y > 0)
	assert(View.projectile_direction({"vx":17,"vy":0,"vz":0}).is_equal_approx(Vector2.RIGHT))
	var arrow := {"x":140,"y":500,"z":40,"arcing":true,"flight_tick":0,"flight_ticks":100,"vx":7,"vy":0,"vz":6}
	assert(View.arc_projectile_position(arrow,0,Vector2(25,-60)) == Vector2(165,400),"Arc must depart from the measured bow hand")
	arrow.x = 840; arrow.z = 0; arrow.flight_tick = 100
	assert(View.arc_projectile_position(arrow,0,Vector2(25,-60)) == Vector2(840,500),"Hand offset must disappear at the locked ground target")
	assert(View.projectile_direction(arrow,Vector2(25,-60)).is_equal_approx(Vector2(6.75,-5.4).normalized()),"Arrow rotation must follow the corrected visual tangent")
	var idle_frames := []
	for tick in range(0,121,12): idle_frames.append(Frames.planted_idle_sample(tick).cell)
	assert(idle_frames == [0,1,2,3,4,5,4,3,2,1,0],"Idle should gently ping-pong at five drawings per second")
	var view := View.new()
	for hero in view._art.animations:
		for sheet in view._art.animations[hero]:
			for cell in range(view._art.animations[hero][sheet].size()):
				var drawing: Dictionary = view._art.animations[hero][sheet][cell]
				if not drawing.has("clip_polygon"): continue
				var polygon := PackedVector2Array()
				for point in drawing.clip_polygon: polygon.append(point)
				if Geometry2D.triangulate_polygon(polygon).is_empty(): print("INVALID rendered atlas polygon: ",hero," ",sheet," ",cell)
				assert(not Geometry2D.triangulate_polygon(polygon).is_empty(),"Atlas mask must remain triangulable before CanvasItem transform")
	view.state = {"civilian_flee_tick":60,"civilian_flee_x":640}
	assert(view._npc_samples(0).size() == 6)
	var fleeing := view._npc_samples(2)
	assert(fleeing.size() == 6)
	for person in fleeing: assert(person.mode == "run" and absf(person.speed) >= 125)
	assert(view._npc_samples(40).is_empty(),"Civilian escape must end rather than wrap and respawn")
	if "--require-v10" in OS.get_cmdline_user_args():
		for hero in Battle.HEROES:
			assert(view._art.has_v10(hero),"Missing six-frame hero: " + hero)
			for action in ["guard","hurt","launched","down","stunned","recovering","light"]:
				var sample := view._fighter_animation({"kind":hero,"team":0,"action":action,"action_tick":12,"combo":1})
				assert(sample.source in ["v10","v11","v12","v13"])
				assert(not view._art.animation_frame(hero,sample).is_empty())
		for hero in ["hideyoshi","ieyasu","mitsuhide","tadakatsu"]:
			var cells := []
			for tick in range(0,72,12):
				view.state = {"tick":tick}
				var sample := view._fighter_animation({"kind":hero,"team":0,"action":"idle","moving":false,"z":0})
				assert(sample.sheet == "idle" and sample.clip == "idle")
				cells.append(sample.cell)
			assert(cells == [0,1,2,3,4,5],"Stationary new heroes must use all six planted idle drawings")
		assert(view._art.has_enemy_v10("soldier"))
		assert(view._art.npc_frames.size() == 6)
		for kind in ["stall","cart","jar","basket","crate"]:
			assert(view._art.prop_frames.has(kind))
	if "--require-factions" in OS.get_cmdline_user_args():
		for faction in Battle.FACTIONS:
			for kind in ["soldier","flag","commander","archer","gunner","boss"]:
				var key: String = view._art._enemy_key(kind,faction)
				assert(key == kind if faction == "mori" else key == kind + "-" + faction,"Every faction must load its own approved costume, not a fallback")
				var count: int = view._art.enemy_clip_size(kind,faction)
				var actions: Array = ["bow_shot"] if kind == "archer" else (["gun_shot"] if kind == "gunner" else (Battle.ENEMY_ATTACKS[kind] if kind != "boss" else Battle.BOSS_PROFILES[Battle.FACTIONS[faction].boss].actions))
				for action in actions:
					var actor := {"kind":kind,"faction":faction,"boss_variant":Battle.FACTIONS[faction].boss,"team":1,"action":action,"action_tick":0,"attack_variant":0}
					actor.attack_variant = actions.find(action)
					var timing: Array = Battle.enemy_timing(actor)
					if kind in ["archer","gunner"] and faction != "mori":
						actor.action_tick = timing[0]
						var released := view._fighter_animation(actor)
						assert(released.frame == released.count / 2 if released.source == "v11" else released.cell == 6,"Ranged attacks use their actual release drawing")
					var seen := []
					for tick in range(timing[1]):
						actor.action_tick = tick
						var sample := view._fighter_animation(actor)
						if not seen.has(sample.cell): seen.append(sample.cell)
						var frame: Dictionary = view._art.enemy_frame(kind,sample.cell,faction,sample.sheet)
						assert(not frame.is_empty() and frame.region.has_area())
					assert(seen.size() >= count,"Every enemy attack must play through its whole genuine clip")
	view.free()
	print("PASS: six-frame combo/reactions, expanded hero branches, six-frame spear attacks, tangent arrows and finite civilian escape")
	quit()
