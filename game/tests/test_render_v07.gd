extends SceneTree

const Frames = preload("res://render/frame_animation.gd")
const View = preload("res://render/battle_view.gd")

func _init() -> void:
	var last := View.charge_visual(0, 155)
	for tick in range(1, 36):
		var next := View.charge_visual(tick, 155)
		assert(next.radius > last.radius and next.glow > last.glow and next.flame > last.flame, "Charging must visibly grow throughout the actual 35-tick charge window")
		last = next
	assert(View.charge_visual(35,155) == View.charge_visual(90,155), "Full charge must hold its size instead of restarting")
	var draw_cells := []
	for tick in range(120):
		var sample := Frames.bow_sample("charge", tick)
		if not draw_cells.has(sample.cell): draw_cells.append(sample.cell)
		if tick >= 18: assert(sample.cell == 11, "Full draw must remain held, never pump backwards")
	assert(draw_cells == [8,9,10,11])
	for tick in range(14):
		assert(Frames.bow_sample("charged", tick).sheet == "attacks" and Frames.bow_sample("charged", tick).cell == 11, "Releasing a charged bow must not restart the draw")
	assert(Frames.bow_sample("charged",14).sheet == "special" and Frames.bow_sample("charged",14).cell == 4)
	for action in ["rising", "ground_slam"]:
		var hit := 6 if action == "rising" else 14
		assert(not Frames.directional_sample(action,hit-0.01).released)
		assert(Frames.directional_sample(action,hit).released)
		assert(Frames.directional_sample(action,hit).duration == (24 if action == "rising" else 42))
	var view := View.new()
	var hero := {"id":1,"team":0,"kind":"nobunaga","x":100.0,"y":500.0,"z":0.0,"action":"idle","action_tick":0}
	view.state = {"tick":0,"fighters":[hero]}
	view.animation_sample()
	var modern: bool = view._art.v11_counts.has("nobunaga-combat")
	var count := 12 if view._art.animations.nobunaga.has("v12_walk") else (8 if modern else (6 if view._art.has_v10("nobunaga") else 4))
	for step in range(1,count + 2):
		hero.x += 155.0 * 0.82 / count
		view.state.tick = step * 5
		var gait := view.animation_sample()
		var expected := (step - 1) % count if count == 12 else step % count
		assert(gait.clip == "walk" and gait.frame == expected, "HD walking follows fixed 12 fps from its first moving tick")
	view.state.tick += 600
	assert(view.animation_sample().clip == "idle", "Idle elapsed time must not advance a stationary character's feet")
	var distance: float = view._walk_distance[1]
	hero.action = "hurt"
	hero.x += 20
	view.state.tick += 1
	view.animation_sample()
	assert(view._walk_distance[1] == distance, "Knockback must not count as walking")
	hero.action = "rising"
	hero.action_tick = 6
	assert(view.animation_sample().clip == "rising" and view.animation_sample().cell == (6 if view._art.animations.nobunaga.has("v12_rising") else (4 if modern else (2 if view._art.has_techniques("nobunaga") else 6))))
	hero.action = "ground_slam"
	hero.action_tick = 14
	assert(view.animation_sample().clip == "ground_slam" and view.animation_sample().cell == (6 if view._art.animations.nobunaga.has("v12_charged_slam") else (12 if modern else (10 if view._art.has_techniques("nobunaga") else 4))))
	hero.kind = "oichi"
	hero.action = "charge"
	var held_origin := Vector2.ZERO
	for tick in [35,60,90]:
		hero.action_tick = tick
		var sample := view.animation_sample("oichi")
		assert(sample.cell == (5 if view._art.animations.oichi.has("v12_heavy2") else (43 if view._art.v11_counts.has("oichi-combat") else 11)))
		var origin: Vector2 = view._art.projectile_origin(sample,148)
		if tick == 35: held_origin = origin
		else: assert(origin == held_origin, "Bow hand and arrow glow must stay fixed after full draw")
	if "--require-v07" in OS.get_cmdline_user_args():
		for kind in ["nobunaga","oichi"]:
			assert(view._art.animations[kind].motion[0].source in ["v07","v10"])
			for cell in [4,5,6,7]:
				if view._art.animations[kind].motion[cell].source == "v07":
					assert(not view._art.animations[kind].motion[cell].contacts.is_empty(), "Every grounded walk drawing needs a measured contact shadow")
		for sheet in ["motion","combo","attacks","special","physical"]:
			assert(view._art.animations.nobunaga[sheet][0].source == "v07" or (sheet in ["motion","special"] and view._art.animations.nobunaga[sheet][0].source == "v10"))
		for cell in [8,9,10,11]:
			var blade: Array = view._art.animations.nobunaga.special[cell].get("blade_offsets", [])
			assert(blade.size() == 2 and blade[0].is_finite() and blade[1].is_finite() and blade[0].distance_to(blade[1]) > 25, "Charge fire must use the measured blade in every source frame")
	view.free()
	print("PASS: v0.7 monotonic charge effects, held bow draw, fixed-rate HD gait and directional-action rendering")
	quit()

