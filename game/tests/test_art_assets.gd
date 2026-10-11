extends SceneTree

const ArtAssets = preload("res://render/art_assets.gd")
const BattleView = preload("res://render/battle_view.gd")
const Frames = preload("res://render/frame_animation.gd")

func _init() -> void:
	var expected := {"idle": 0, "light": 1, "heavy": 2, "charged": 2, "charge": 3, "throw": 5, "hurt": 6, "defeated": 6, "special": 7, "victory": 8}
	for action in expected:
		assert(ArtAssets.pose_for(action, 0.0) == expected[action], "Wrong pose: " + action)
	assert(ArtAssets.pose_for("idle", 10.0) == 4)
	assert(ArtAssets.pose_for("idle", 0.0, true) == 8)
	assert(ArtAssets.pose_for("defeated", 0.0, true) == 6)
	var total_area := 0
	for index in range(9):
		var rect: Rect2i = ArtAssets.cell_rect(Vector2i(1535, 1024), 3, 3, index)
		assert(rect.has_area())
		assert(Rect2i(0, 0, 1535, 1024).encloses(rect))
		total_area += rect.size.x * rect.size.y
	assert(total_area == 1535 * 1024, "Odd sheet dimensions must not lose edge pixels")
	var art := ArtAssets.new()
	assert(art.heroes.size() == 2, "Both transparent nine-pose character sheets must be included")
	assert(art.weather_frames.size() == 3, "All three weather backgrounds must be included")
	assert(art.scenery_frames.size() == 8, "Both flags, both fires and all four walking frames must be included")
	assert(art.villager_frames.size() == 8, "Separate walk and run cycles must be included")
	assert(art.animations.size() == 6, "All six playable heroes need registered action sheets")
	var tadakatsu_idle: Array = art.animations.tadakatsu.v16_idle
	assert(tadakatsu_idle.size() == 6 and tadakatsu_idle[0].texture != tadakatsu_idle[1].texture, "Tadakatsu atlas cells must use isolated textures to prevent edge bleed")
	assert(tadakatsu_idle[0].region.position == Vector2(2, 2) and tadakatsu_idle[0].source_region.position != tadakatsu_idle[0].region.position, "Padded frames must retain their source atlas coordinates for registration")
	for sheet in art.animations.tadakatsu:
		if not str(sheet).begins_with("v16_"): continue
		var frames: Array = art.animations.tadakatsu[sheet]
		for index in range(frames.size()):
			assert(frames[index].region.position == Vector2(2, 2) and Vector2i(frames[index].texture.get_size()) == Vector2i(frames[index].region.size) + Vector2i(4, 4))
			assert(frames[index].texture != frames[(index + 1) % frames.size()].texture, "Every Tadakatsu frame needs its own padded texture")
	for hero in ["nobunaga", "oichi"]:
		assert(art.has_combo(hero), "Both heroes need the three distinct v0.5 light stages")
		assert(art.animations[hero].motion[0].get("source", "") in ["v05", "v06", "v07", "v10"], "Calmer registered idle must be loaded")
		assert(art.animations[hero].combo.size() == 12)
	for sheet in ["combo", "attacks", "special"]:
		assert(art.animations.oichi[sheet][0].get("source", "") in ["v05", "v06", "v10"], "Oichi technique upgrade must be loaded")
	assert(art.villager_frames[0].get("source", "") == "v05", "Expressive v0.5 villagers must be loaded")
	assert(art.hero_frame("missing_hero", 0).is_empty())
	for hero in art.heroes:
		for pose in range(9):
			var frame: Dictionary = art.hero_frame(hero, pose)
			assert(frame.region.has_area())
			assert(frame.texture.get_size().x > 0)
			assert(frame.body_height > 0)
			assert(frame.anchor.x >= 0 and frame.anchor.y >= 0, "Foot anchor must be inside its figure cell")
	assert(art.background(-1) == art.background(0))
	assert(art.background(0).texture.get_width() >= 1600, "Daylight uses the high-resolution original background")
	if art.animations.nobunaga.motion[4].get("source", "v04") == "v04":
		assert(art.animations.nobunaga.motion[4].region.end.x > 384, "Walk blade must survive its irregular atlas boundary")
		assert(art.animations.nobunaga.motion[5].region.position.x >= 412)
	if art.animations.nobunaga.attacks[0].get("source", "v04") == "v04":
		assert(art.animations.nobunaga.attacks[0].region.end.y > 341, "Heavy windup must retain complete soles")
		assert(art.animations.nobunaga.attacks[4].region.position.y >= 370)
		assert(art.animations.nobunaga.attacks[9].region.end.x > 768)
		assert(art.animations.nobunaga.attacks[10].region.position.x >= 800)
	for clip in ["light", "heavy", "special", "jump"]:
		var hand: Vector2 = art.needle_origin(clip, 225)
		assert(hand.x > 50 and hand.x < 220 and hand.y < -40 and hand.y > -230, "Invalid release origin for %s: %s" % [clip, hand])
	for hero in art.animations:
		assert(art.animations[hero].size() >= (4 if hero in ["nobunaga","oichi"] else 3))
		for sheet in art.animations[hero]:
			var expected_count := 6 if sheet in ["idle", "v16_idle"] else (8 if sheet == "air" else (16 if sheet in ["techniques","advanced"] else 12))
			if sheet in ["combat","reactions","skills"]: expected_count = 30 if sheet == "combat" and hero in ["nobunaga","oichi"] else 36
			if str(sheet).begins_with("v11_"): expected_count = 48
			if sheet == "v11_needles": expected_count = 24
			assert(art.animations[hero][sheet].size() == expected_count)
			for frame in art.animations[hero][sheet]:
				assert(frame.region.has_area() and frame.body_height > 0)
				if frame.planted:
					var contact: Vector2 = (frame.support_point - frame.anchor) / frame.body_height
					assert(contact.is_equal_approx(Vector2(-float(ArtAssets.SUPPORT_OFFSET.get(hero,0.32)), 0)), "Grounded frames must share one planted foot relative to the collision center")
		if not art.animations[hero].has("motion"): continue
		var idle: Array = art.animations[hero].motion
		for index in range(4):
			assert(idle[index].layers.size() == 2)
			assert(idle[index].layers[0] == idle[0].layers[0], "Idle must retain both first-frame shoes")
			assert(idle[index].layers[1].region.has_area())
			assert(idle[index].body_height == idle[0].body_height)
	var view := BattleView.new()
	assert(view.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR)
	var floor_point := Vector2(330, 585)
	var grounded := BattleView.shadow_geometry(floor_point, 240, 240 * 0.49, 0, 240 * 0.07)
	var jumping := BattleView.shadow_geometry(floor_point, 240, 240 * 0.49, 75, 240 * 0.07)
	assert(grounded.center == jumping.center, "Jump shadow must remain at the ground position")
	assert(jumping.radius.x < grounded.radius.x and jumping.radius.y < grounded.radius.y)
	assert(jumping.opacity < grounded.opacity and jumping.opacity > 0.0)
	assert(grounded.contact_opacity == 1.0 and jumping.contact_opacity == 0.0)
	assert(grounded.radius.x > ArtAssets.SUPPORT_OFFSET.nobunaga * 240 + 25, "Hero shadow must cover the planted stance")
	var far_shadow := BattleView.shadow_geometry(floor_point, 55, 55 * 0.24, 0)
	var near_shadow := BattleView.shadow_geometry(floor_point, 95, 95 * 0.24, 0)
	assert(near_shadow.radius.x > far_shadow.radius.x and near_shadow.radius.y > far_shadow.radius.y)
	var fighter := {"id": 1, "team": 0, "kind": "nobunaga", "x": 300.0, "y": 500.0, "action": "idle", "z": 0.0, "vz": 0.0}
	view.state = {"tick": 0, "fighters": [fighter]}
	assert(view.animation_sample().clip == "idle")
	fighter.x += 2.0
	view.state.tick = 1
	assert(view.animation_sample().clip == "walk", "Moving idle fighter must use walking frames")
	view.state.tick = 2
	assert(view.animation_sample().clip == "idle")
	fighter.z = 40.0
	fighter.vz = 3.0
	for action in ["light", "heavy", "special"]:
		fighter.action = action
		fighter.action_tick = Frames.CLIPS[action].hit
		assert(view.animation_sample().clip == action, "Airborne attacks must keep their actual attack frames")
	for stage in range(1, 4):
		fighter.action = "light"
		fighter.action_tick = 6
		fighter.combo = stage
		assert(view.animation_sample().cell == (6 if art.animations.nobunaga.has("v12_light%d" % stage) else (stage * 8 + 4 if art.v11_counts.has("nobunaga-combat") else (stage * 6 + 3 if art.has_v10("nobunaga") else Frames.combo_sample(stage, 6).cell))))
	fighter.action = "heavy"
	fighter.heavy_combo = 2
	fighter.action_tick = 14
	var heavy := view.animation_sample()
	assert((heavy.sheet == "v12_heavy2" and heavy.cell == 6) if art.animations.nobunaga.has("v12_heavy2") else ((heavy.sheet == "v11_combat" and heavy.cell == 44) if art.v11_counts.has("nobunaga-combat") else (heavy.sheet == "special" and heavy.cell == 4)), "Second heavy must use a separate heavy sequence")
	fighter.action = "charged"
	assert(view.animation_sample().sheet == ("v12_heavy2" if art.animations.nobunaga.has("v12_heavy2") else ("v11_combat" if art.v11_counts.has("nobunaga-combat") else "attacks")), "Charged release must use its heavy attack sheet")
	var people: Array = view._npc_samples(0.0)
	assert(people[1].height < people[0].height, "Children retain a smaller stature at nearby depth")
	assert(people[0].mode == "walk" and people[2].mode == "walk")
	for index in range(people.size()):
		var person: Dictionary = people[index]
		if is_zero_approx(person.speed): continue
		var count := 6 if art.npc_frames.has(person.kind) else 4
		var quarter_stride_time: float = person.stride / absf(person.speed) / count
		var next: Dictionary = view._npc_samples(quarter_stride_time + 0.00001)[index]
		assert(next.frame == 1 and is_equal_approx(next.distance, quarter_stride_time * absf(person.speed) + 0.00001 * absf(person.speed)))
	view.free()
	print("PASS: loaded hero frames, planted support, fixed idle shoes, aerial attacks, distinct combo mapping, shadows and depth/distance-driven NPC cycles")
	quit()

