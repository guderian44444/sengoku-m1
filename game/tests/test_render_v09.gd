extends SceneTree

const Frames = preload("res://render/frame_animation.gd")
const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")

func _init() -> void:
	for kind in Battle.ENEMY_ATTACKS:
		var impacts := []
		for action in Battle.ENEMY_ATTACKS[kind]:
			var timing: Array = Battle.ENEMY_TIMING[action]
			assert(not Frames.enemy_sample(kind,action,timing[0] - 0.01,0,false).released)
			var impact := Frames.enemy_sample(kind,action,timing[0],0,false)
			assert(impact.released and impact.frame == 2)
			impacts.append(impact.cell)
			var cells := []
			for tick in range(timing[1]):
				var cell: int = Frames.enemy_sample(kind,action,tick,0,false).cell
				if not cells.has(cell): cells.append(cell)
			assert(cells.size() >= 4, "Every enemy attack needs at least four actual atlas drawings")
		assert(impacts == ([10,14,6,6] if kind == "boss" else [6,10,14]), "Legacy attacks keep their rows; the new grab-throw reuses the chain fallback until its dedicated clip is loaded")
	for action in ["rising","low_sweep","ground_slam","charged_slam","air_light","air_heavy","upper_heavy","charged_upper","dash_strike","mixed_finisher"]:
		var cells := []
		var sample := Frames.technique_sample(action,0)
		for tick in range(sample.duration):
			var cell: int = Frames.technique_sample(action,tick).cell
			if not cells.has(cell): cells.append(cell)
		assert(cells.size() == 4)
	assert(Frames.technique_sample("ground_slam",14).cell == 10)
	assert(Frames.technique_sample("charged_slam",28).cell == 14)
	assert(not Frames.technique_sample("charged_slam",27.9).released)
	assert(Frames.technique_sample("mixed_rising",27).sheet != Frames.technique_sample("mixed_finisher",27).sheet, "Heavy-to-light uses the low-to-rising sequence rather than the light-to-heavy finisher drawings")
	for tick in range(Battle.SPECIAL_TICKS):
		assert(View.power_phase("special",tick).guard)
	assert(not View.power_phase("special",Battle.SPECIAL_TICKS).guard)
	for pulse in [26,68,110,152,192]:
		assert(Frames.battle_special_sample(pulse).frame >= 4)
	assert(Frames.battle_special_sample(0).frame == 0, "Special must begin with the preparation drawing")
	assert(View.projectile_style("bullet").bullet and not View.projectile_style("bullet").arrow)
	assert(View.shattered_defeat({"hp":0,"shattered_tick":70,"damage_tick":70}))
	assert(not View.shattered_defeat({"hp":0,"shattered_tick":70,"damage_tick":120}), "Surviving an earlier shatter must not erase a later ordinary defeat")
	assert(not View.shattered_defeat({"hp":10,"shattered_tick":70,"damage_tick":70}))
	assert(Frames.enemy_sample("archer","bow_shot",30,0,false).cell == 7)
	assert(Frames.enemy_sample("gunner","gun_shot",44,0,false).cell == 7)
	assert(Frames.enemy_sample("boss","boss_chain",54,0,false).cell == 10, "The chain pull must visibly follow with the sickle strike at the real hit tick")
	if "--require-v09" in OS.get_cmdline_user_args():
		var view := View.new()
		for kind in ["soldier","flag","commander","archer","gunner","boss"]:
			assert(view._art.enemies.has(kind), "Missing enemy atlas: " + kind)
			assert(view._art.enemies[kind].size() == (24 if kind == "soldier" and view._art.has_enemy_v10(kind) else 16))
			for frame in view._art.enemies[kind]: _check_frame(frame)
		for hero in ["nobunaga","oichi"]:
			for sheet in ["techniques","air","advanced"]:
				assert(view._art.animations[hero].has(sheet), "Missing hero technique sheet")
				assert(view._art.animations[hero][sheet].size() == (8 if sheet == "air" else 16))
				for frame in view._art.animations[hero][sheet]: _check_frame(frame)
		for sheet in ["techniques","air","advanced"]:
			for frame in view._art.animations.oichi[sheet]:
				assert(frame.has("hand_offset"), "Every Oichi technique must use its own measured release hand")
		assert(view._art.enemies.boss[6].has("hand_offset"))
		assert(view._art.enemies.gunner[7].has("hand_offset") and view._art.enemies.archer[7].has("hand_offset"))
		var enemy := {"id":44,"kind":"soldier","team":1,"action":"spear_thrust","action_tick":25,"freeze":0}
		var original := view._fighter_animation(enemy)
		enemy.freeze = 90
		enemy.action = "frozen"
		enemy.action_tick = 80
		assert(view._fighter_animation(enemy) == original, "Frozen enemy must hold the struck drawing")
		for direction in [-1,1]:
			var archer := {"id":45,"kind":"oichi","team":0,"action":"charge","action_tick":35,"charge_direction":direction}
			var held := view._fighter_animation(archer)
			archer.action_tick = 90
			assert(view._fighter_animation(archer).cell == held.cell, "Directional full draw must stay still")
			archer.action = "charged_upper" if direction < 0 else "charged_slam"
			archer.action_tick = 0
			assert(view._fighter_animation(archer).cell == held.cell, "Directional release must not restart bow draw")
		view.free()
	print("PASS: enemy hit-aligned distinct atlas rows, hero tap/charged/air branches, sustained special, freeze-frame and v09 asset coverage")
	quit()

func _check_frame(frame: Dictionary) -> void:
	assert(frame.source in ["v09","v10"] and frame.body_height > 30)
	assert(frame.region.has_area() and frame.anchor.is_finite())
	assert(frame.region.position.x >= 0 and frame.region.position.y >= 0)
	assert(frame.region.end.x <= frame.texture.get_width() and frame.region.end.y <= frame.texture.get_height())
