extends SceneTree
const View = preload("res://tests/legacy_battle_view.gd")
const Battle = preload("res://core/battle.gd")
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func _initialize() -> void:
	var view := View.new()
	var sim := Battle.new()
	for hero in Battle.HEROES:
		var fighter := {"kind":hero,"team":0,"action":"dash_heavy","action_tick":Battle.hero_tick(hero,12),"face":1}
		var sample := view._fighter_animation(fighter)
		check(sample.clip == "dash_heavy" and sample.released,"Every hero must visibly attack at the sprint-heavy hit tick")
		var accent := View.strike_accent(fighter,sample)
		check(not accent.is_empty() and not accent.bow,"Sprint heavy is a physical sweep or thrust, not an arrow firing pose")
		check(accent.thrust == (hero in ["hideyoshi","tadakatsu"]),"Only spears get the narrow forward energy trail")
		fighter.action_tick = Battle.hero_tick(hero,12) - 1
		check(not view._fighter_animation(fighter).released,"Sprint-heavy effect cannot precede the hit")
	for face in [-1,1]:
		var points := View.shockwave_points({"arc_degrees":120,"face":face},320)
		for point in points:
			check(point.x * face > 0,"Oichi's ice particles stay in front")
			check(sim._inside_arc(point.x,point.y,face,120.01),"Visible ice fan matches the collision sector")
		var ring := View.shockwave_points({"arc_degrees":360,"face":face},320)
		var behind := false
		for point in ring: behind = behind or point.x * face < 0
		check(behind,"Nobunaga's fire ring includes enemies behind him")
	check(View.projectile_direction({"vx":8,"vy":3,"vz":0}).y > 0,"Fan needles follow their actual divergent trajectory")
	for hero in ["nobunaga","oichi"]:
		var sources := []
		for index in range(12):
			view._walk_ticks[99] = index * 5
			var sample := view._fighter_animation({"id":99,"kind":hero,"team":0,"action":"idle","moving":true})
			check(sample.sheet == "v13_walk" and sample.frame == index,"The fixed walk clock uses the twelve corrected drawings")
			var frame := view._art.animation_frame(hero,sample)
			var key := str(frame.texture.get_instance_id()) + str(frame.region)
			check(frame.body_height >= 220 and not sources.has(key),"Each walk frame uses its own original HD drawing")
			sources.append(key)
	for combo in range(1,4):
		var sources := []
		var previous_angle := 0.0
		for index in range(12):
			var sample := view._fighter_animation({"kind":"nobunaga","team":0,"action":"light","combo":combo,"action_tick":index})
			check(sample.source == "v13" and sample.frame == index,"Each light cut advances one actual drawing per tick")
			var frame := view._art.animation_frame("nobunaga",sample)
			check(frame.has("blade_offsets"),"Sword trail needs the actual blade endpoints of every source drawing")
			if combo < 3 and frame.has("blade_offsets"):
				var blade: Vector2 = frame.blade_offsets[1] - frame.blade_offsets[0]
				var angle := blade.angle()
				if index > 0:
					var advance := wrapf(angle - previous_angle,-PI,PI) * (1 if combo == 1 else -1)
					check(advance > deg_to_rad(3) and advance < deg_to_rad(40),"Each diagonal cut advances visibly without reversing or jumping over its intervening drawings")
				previous_angle = angle
			var key := str(frame.texture.get_instance_id()) + str(frame.region)
			check(not sources.has(key),"Repeated source regions cannot count as additional drawings")
			sources.append(key)
	var hand: Dictionary = view._art.animations.oichi.v13_dash_heavy[6]
	check(hand.has("hand_offset") and Rect2(Vector2.ZERO,hand.region.size).has_point(hand.anchor + hand.hand_offset),"Five needles originate from the bow swing's impact drawing")
	for face in [-1,1]:
		view.state = {"tick":50,"fighters":[{"id":8,"kind":"oichi","team":0,"action":"idle","face":-face}]}
		var shot := {"owner":8,"team":0,"face":face,"action":"dash_heavy","action_tick":12,"combo":0,"heavy_combo":0,"weapon":"needle"}
		var release: Vector2 = hand.hand_offset * 148.0 / float(hand.body_height)
		check(view._projectile_offset(shot).is_equal_approx(Vector2((release.x - 105) * face,release.y + 124)),"A delayed sprint needle still uses the saved bow-swing hand after its owner turns or returns idle")
	view.free()
	print("PASS: v13 attack routes, elemental fan geometry, divergent needles and 36 actual blade frames: ",checks)
	quit()
