extends SceneTree

const ArtAssets = preload("res://render/art_assets.gd")
const Frames = preload("res://render/frame_animation.gd")
const BattleView = preload("res://render/battle_view.gd")

func _init() -> void:
	for stage in [1, 2]:
		var visited := []
		for tick in range(36):
			var sample := Frames.bow_sample("heavy", tick, stage)
			if not visited.has(sample.cell): visited.append(sample.cell)
			assert(sample.sheet == "attacks" and sample.count == 4 and sample.duration == 36)
		assert(visited == ([0,1,2,3] if stage == 1 else [4,5,6,7]))
		assert(Frames.bow_sample("heavy", 13.99, stage).frame == 1)
		assert(Frames.bow_sample("heavy", 14, stage).frame == 2)
	assert(Frames.bow_sample("charged", 14).cell == 4 and Frames.bow_sample("charged", 14).sheet == "special")
	assert(Frames.bow_sample("charge", 0).sheet == "attacks" and Frames.bow_sample("charge", 0).cell == 8)
	for tick in [0, 12, 60, 600]:
		assert(Frames.restraint_sample("holding", tick).cell == 5, "Held pose must not play through a release")
	assert(Frames.restraint_sample("down", 0).cell == 11)
	assert(Frames.restraint_sample("grabbed", 600).cell == 9)
	assert(BattleView.fighter_depth({"y":500,"held_by":1}) > BattleView.fighter_depth({"y":500}), "Carried victim must draw in front of its carrier")
	assert(not BattleView.projectile_style("needle").arrow)
	assert(BattleView.projectile_style("arrow").arrow)
	assert(BattleView.projectile_style("special_arrow").powered)
	assert(BattleView.projectile_style("special_arrow").trail > BattleView.projectile_style("arrow").trail)
	assert(BattleView.power_phase("special", 0).guard)
	assert(BattleView.power_phase("special", 55).guard)
	assert(BattleView.power_phase("special", 209).guard)
	assert(not BattleView.power_phase("special", 210).guard)
	assert(not BattleView.power_phase("special", 25.99).released)
	assert(BattleView.power_phase("special", 26).released)
	for layer in BattleView.DECOR_PARALLAX:
		var travel: float = BattleView.decor_offset(layer,1100) - BattleView.decor_offset(layer,0)
		assert(is_equal_approx(travel,1100.0) if layer in ["ground","flags","fence","stone","grass","ripples"] else travel >= 128 and travel <= 220, "Near decorations share world movement; distant scenery moves slowly")
		assert(is_equal_approx(BattleView.decor_offset(layer,550), travel * 0.5), "Decoration parallax must be continuous, without camera-boundary jumps")
	var view := BattleView.new()
	var art = view._art
	if "--require-v06" in OS.get_cmdline_user_args():
		assert(art.has_v06("oichi"), "Complete v0.6 Oichi outfit and actions must be shipped")
	if art.has_v06("oichi"):
		assert(not art.animations.oichi.physical[1].planted and not art.animations.oichi.motion[11].planted, "JSON numeric indices must not pin airborne/prone drawings to a standing support foot")
		assert(art.animations.oichi.motion[0].planted and art.animations.oichi.combo[2].planted)
		for sheet in ["motion", "combo", "attacks", "special", "physical"]:
			assert(art.animations.oichi[sheet].size() == 12)
			for frame in art.animations.oichi[sheet]:
				assert(frame.source == "v06" or (sheet == "motion" and frame.source == "v07") or (sheet == "special" and frame.source == "v10"), "One outfit must cover every action; never mix old sheets")
		var fighter := {"id":1,"team":0,"kind":"oichi","action":"heavy","action_tick":14,"heavy_combo":2}
		view.state = {"fighters":[fighter]}
		var sample := view.animation_sample("oichi")
		var modern: bool = art.v11_counts.has("oichi-combat")
		assert((sample.sheet == "v12_heavy2" and sample.frame == 6 and sample.count == 12) if art.animations.oichi.has("v12_heavy2") else (sample.sheet == "v11_combat" and sample.cell == 44 and sample.count == 8) if modern else (sample.sheet == "attacks" and sample.cell == 6 and sample.count == 4))
		var arrow := {"owner":1,"team":0,"weapon":"arrow","face":1,"life":35,"max_life":36}
		var release_hand: Vector2 = art.projectile_origin(sample if modern else Frames.bow_sample("heavy",14,2),148)
		assert((Vector2(105,-124) + view._projectile_offset(arrow)).is_equal_approx(release_hand), "Runtime heavy2 arrow must begin at the elevated bow, not the old fixed height")
		arrow.face = -1
		assert((Vector2(-105,-124) + view._projectile_offset(arrow)).is_equal_approx(release_hand * Vector2(-1,1)))
		fighter.action = "charged"
		assert(view.animation_sample("oichi").sheet == ("v12_heavy2" if art.animations.oichi.has("v12_heavy2") else ("v11_combat" if modern else "special")))
		fighter.action = "holding"
		assert(view.animation_sample("oichi").clip == "holding" if modern else view.animation_sample("oichi").cell == 5)
		fighter.action = "down"
		assert(view.animation_sample("oichi").sheet == "v12_down" if art.animations.oichi.has("v12_down") else view.animation_sample("oichi").cell / 8 == 3 if modern else view.animation_sample("oichi").cell == (19 if art.has_v10("oichi") else 11))
		fighter.action = "hurt"
		fighter.action_tick = 17
		assert(view.animation_sample("oichi").sheet == "v12_hurt" if art.animations.oichi.has("v12_hurt") else view.animation_sample("oichi").cell / 8 == 1 if modern else view.animation_sample("oichi").cell == (11 if art.has_v10("oichi") else 10), "Ordinary stagger must not show the prone down drawing")
		for stage in [1,2,3]:
			var hand: Vector2 = art.projectile_origin(Frames.combo_sample(stage,6),148)
			assert(hand.is_finite() and absf(hand.x) < 250 and hand.y < 0)
	view.free()
	print("PASS: v0.6 bow timing, complete outfit selection, holding/down poses, projectile distinction and invulnerability visual contract")
	quit()

