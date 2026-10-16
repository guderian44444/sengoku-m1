extends SceneTree

const Renderer = preload("res://render/weapon_renderer.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const View = preload("res://render/battle_view.gd")
const Art = preload("res://render/stage_art.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var renderer := Renderer.new()
	var origin := Vector2(400,500)
	var projection := View.shadow_projection(origin,0,"riverbank")
	check((projection * Vector2.ZERO).is_equal_approx(origin),"Grounded shadow anchors exactly at the feet")
	var airborne := View.shadow_projection(origin,90,"riverbank")
	check((airborne.origin-origin).length() > 20,"Jumping moves the shadow along the light direction")
	check((airborne * Vector2(0,90)).is_equal_approx(origin),"Jump altitude and projection use the same ground direction")
	check((View.shadow_projection(origin,0,"switchback") * Vector2(0,-155)-origin).length() > (projection * Vector2(0,-155)-origin).length(),"Late-day scene casts a longer silhouette")
	check(View.shadow_projection(origin,-10,"riverbank").is_equal_approx(projection),"Negative visual altitude cannot lift the ground anchor")
	for hero in ["nobunaga","oichi","tadakatsu"]:
		for id in Weapons.ids_for(hero):
			var fighter := {"kind":hero,"weapon_id":id}
			var frame := {"layered_weapon":true,"weapon_hand":Vector2(42,-270),"weapon_angle":37.0,"body_height":620.0}
			var pose := renderer.geometry(fighter,frame,155)
			check(not pose.is_empty() and renderer.textures.has(pose.id),"Shadow has the equipped weapon alpha: " + id)
			for face in [-1.0,1.0]:
				for rotation in [0.0,-0.6]:
					var local := Renderer.pose_transform(pose,Vector2.ZERO,face,rotation)
					var transform := projection * local
					var expected_hand: Vector2 = (pose.hand * Vector2(face,1)).rotated(rotation)
					check((transform * Vector2.ZERO).is_equal_approx(projection * expected_hand),"Shadow grip follows visible weapon hand/facing/rotation")
					var spec: Dictionary = renderer.items[pose.id]
					for end in ["top","bottom"]:
						var tip: Array = spec["tip_" + end]
						var sprite_point := Vector2(tip[0],tip[1]) - Vector2(pose.grip)
						var expected: Vector2 = (pose[end] * Vector2(face,1)).rotated(rotation)
						check((transform * sprite_point).is_equal_approx(projection * expected),"Shadow endpoint matches the catalog's actual weapon extent")
			frame.weapon_visible = false
			check(renderer.geometry(fighter,frame,155).is_empty(),"Hidden weapon casts no detached shadow")
			frame.weapon_visible = true
			frame.layered_weapon = false
			check(renderer.geometry(fighter,frame,155).is_empty(),"Baked sprite does not cast an extra weapon shadow")
	var art := Art.new()
	var sources := []
	for theme in ["supply_road","riverbank","granary","switchback","marune_gate","supply_court"]:
		var background := art.background(theme)
		check(not background.is_empty() and background.texture.get_width() >= 1280,"Second chapter backdrop loads: " + theme)
		check(background.horizon > .45 and background.horizon < .65,"Background road horizon stays within authored bounds")
		sources.append(str(background.source))
	check(sources.size() == 6 and sources.all(func(path): return sources.count(path) == 1),"Each second-chapter scene uses its own background file")
	var view := View.new()
	var standing := {"anchor":Vector2(100,200),"body_height":180.0,"clip_polygon":PackedVector2Array([Vector2(20,200),Vector2(10,190),Vector2(70,20),Vector2(130,20),Vector2(190,190),Vector2(180,200),Vector2(140,200),Vector2(100,160),Vector2(60,200)])}
	var feet: Array = View.frame_contact_points(standing,155)
	check(feet.size() == 2 and absf(feet[0].offset.x-feet[1].offset.x) > 10,"Wide stance polygon creates separate shoe contact shadows")
	check(feet.all(func(foot): return absf(foot.offset.y) < 4),"Shoe contact shadows remain at the authored sole height")
	var mirrored_feet: Array = View.frame_contact_points(standing,155,-1)
	check(is_equal_approx(mirrored_feet[0].offset.x,-feet[0].offset.x),"Shoe contact follows facing without changing source anchor")
	view.state = {"tick":0,"stage":{"id":2,"index":0,"theme":"supply_road","width":2400,"entered_tick":0,"civilians":"villagers"},"fighters":[]}
	var peaceful: Array = view._npc_samples(0)
	check(peaceful.size() >= 5 and peaceful.all(func(p): return p.mode == "walk"),"Roadside families and workers remain present before nearby combat")
	view._stage_key = "2:0"
	view._motion_tick = 120
	view.state.fighters = [{"x":340.0,"y":410.0,"hp":120,"action":"light"}]
	var alarmed: Array = view._npc_samples(0)
	check(alarmed.any(func(p): return p.mode == "run" and p.x < 650),"Nearby family reacts to fighting")
	check(alarmed.any(func(p): return p.mode == "walk" and p.x > 900),"Distant workers do not vanish when combat starts elsewhere")
	view.state.fighters = []
	var later: Array = view._npc_samples(2)
	check(later.any(func(p): return p.mode == "run" and p.distance > 0),"Frightened pedestrians keep moving toward safety")
	view._update_motion()
	check(view._npc_samples(0).all(func(p): return p.mode == "walk"),"Restarting the same scene resets pedestrian panic")
	for variant in ["cross_spear","short_yari","long_yari"]:
		var expected := "oda"
		var boss := {"id":777,"team":1,"kind":"boss","faction":"oda","boss_variant":variant,"action":"idle","action_tick":0,"hp":240,"stage_boss":true,"x":800.0,"y":460.0,"face":-1,"z":0.0,"moving":false}
		var unchanged := var_to_bytes(boss)
		check(View.enemy_art_faction(boss) == expected,"Named spear boss selects its authored matching weapon: " + variant)
		check(view._art.enemy_clips.has("oda:"+variant+":poses"),"New HD matching spear boss source exists without old faction fallback")
		for action in ["idle","boss_thrust","boss_sweep","boss_dash","boss_double","dead"]:
			boss.action = action
			var before := var_to_bytes(boss)
			var sample: Dictionary = view._fighter_animation(boss)
			var frame: Dictionary = view._art.enemy_frame("boss",int(sample.cell),View.enemy_art_faction(boss),str(sample.sheet))
			check(not frame.is_empty() and sample.source == "v31","HD matching spear boss has drawable action " + action)
			check(var_to_bytes(boss) == before,"Visual source selection leaves authoritative fighter untouched")
		boss.action = "idle"
		check(var_to_bytes(boss) == unchanged,"Boss identity and combat faction remain Oda")
		var frozen_boss := boss.duplicate()
		frozen_boss.moving = true
		view._walk_distance[777] = 70
		var before_freeze: Dictionary = view._fighter_animation(frozen_boss)
		frozen_boss.freeze = 60
		frozen_boss.moving = false
		check(view._fighter_animation(frozen_boss) == before_freeze,"New HD boss keeps its actual pose while frozen")
	check(View.enemy_art_faction({"kind":"commander","faction":"oda","boss_variant":"long_yari"}) == "oda","Regular Oda troops use dedicated Oda clips and corrected banners")
	check(View.enemy_art_faction({"kind":"boss","faction":"imagawa","boss_variant":"naginata"}) == "imagawa","First-chapter boss art stays unchanged")
	view.free()
	print("SHADOWS V29 %s: %d checks, %d failures. Geometry checks; native pose captures cover appearance." % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)
