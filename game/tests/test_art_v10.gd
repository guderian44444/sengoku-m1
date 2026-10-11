extends SceneTree

const ArtAssets = preload("res://render/art_assets.gd")

func _init() -> void:
	var art := ArtAssets.new()
	assert(art.hero_frame("missing", 0).is_empty())
	assert(art.npc_frame("missing", 0).is_empty())
	assert(art.prop_frame("missing", 0).is_empty())
	if "--require-factions" in OS.get_cmdline_user_args():
		for faction in ["imagawa","oda","saito","miyoshi","azai","asakura","takeda","ikko","akechi","hashiba","iga"]:
			for kind in ["soldier","flag","commander","archer","gunner","boss"]:
				var key: String = kind + "-" + faction
				assert(art.enemies.has(key), "Missing faction enemy: " + key)
				var expected := 24 if kind == "boss" else (8 if kind in ["archer","gunner"] else 16)
				assert(art.enemies[key].size() == expected)
				assert(art.enemy_clip_size(kind,faction) == (6 if kind == "boss" else 4))
				assert(art.enemy_frame(kind,0,faction) == art.enemies[key][0])
				for frame in art.enemies[key]: _check_frame(frame)
	if "--require-v10" in OS.get_cmdline_user_args():
		for hero in ["nobunaga", "oichi"]:
			assert(art.has_v10(hero), "Missing six-frame hero atlas: " + hero)
			assert(art.animations[hero].combat.size() == 30)
			assert(art.animations[hero].reactions.size() == 36)
			for sheet in ["combat", "reactions"]:
				for frame in art.animations[hero][sheet]: _check_frame(frame)
		assert(art.has_enemy_v10("soldier") and art.enemies.soldier.size() == 24)
		for frame in art.enemies.soldier: _check_frame(frame)
		for kind in ["woman", "child", "elder", "cart_vendor", "herb_vendor", "produce_vendor"]:
			assert(art.npc_frames.get(kind, []).size() == 12, "Each civilian needs separate six-frame walk and escape cycles")
			for frame in art.npc_frames[kind]: _check_frame(frame)
		for kind in ["stall", "cart", "jar", "basket", "crate"]:
			assert(art.prop_frames.get(kind, []).size() == 3, "Each destructible prop needs intact, damaged and broken states")
			for frame in art.prop_frames[kind]: _check_frame(frame)
		assert(art.enemy_frame("soldier", 999) == art.enemies.soldier[-1])
		assert(art.npc_frame("woman", 999) == art.npc_frames.woman[-1])
		assert(art.prop_frame("jar", 999) == art.prop_frames.jar[-1])
	print("PASS: v10 flexible atlas loader, six-frame clips, civilian groups and prop damage states")
	quit()

func _check_frame(frame: Dictionary) -> void:
	assert(frame.source == "v10")
	assert(frame.body_height > 0.0 and frame.region.has_area())
	assert(Rect2(Vector2.ZERO, frame.texture.get_size()).encloses(frame.region))
	assert(frame.anchor.is_finite() and frame.support_point.is_finite())
