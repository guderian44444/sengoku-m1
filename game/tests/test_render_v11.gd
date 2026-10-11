extends SceneTree
const View = preload("res://render/battle_view.gd")
const Frames = preload("res://render/frame_animation.gd")
const Battle = preload("res://core/battle.gd")
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		push_error(label)
		quit(1)
		assert(ok,label)

func _initialize() -> void:
	var view := View.new()
	var counts: Dictionary = view._art.v11_counts
	for hero in Battle.HEROES:
		var fallen := view._fighter_animation({"kind":hero,"team":0,"action":"defeated","action_tick":100})
		var corpse: Dictionary = view._art.animation_frame(hero,fallen)
		check(corpse.region.size.x > corpse.region.size.y * 1.7,"Hero corpse must lie flat: " + hero)
		for sheet in ["combat","skills","reactions"]:
			check(counts.has(hero + "-" + sheet),"Missing v11 " + hero + " " + sheet)
			for row in range(6):
				var count := int(counts[hero + "-" + sheet][row])
				check(count >= 7,"Increase true source poses beyond six for " + hero + " " + sheet + " row%d" % row)
				var regions := []
				for frame in range(count):
					var drawing: Dictionary = view._art.animations[hero]["v11_" + sheet][row * 8 + frame]
					check(not drawing.planted,"Measured v11 anchors must not receive a legacy foot shift")
					check(not regions.has(drawing.region),"Duplicating a source frame is not an extra drawing")
					regions.append(drawing.region)
		for combo in [1,2,3]:
			var cells := []
			for tick in range(Battle.hero_tick(hero,19)):
				var sample := view._fighter_animation({"kind":hero,"team":0,"action":"light","combo":combo,"action_tick":tick})
				var expected_sequence: bool = (sample.source == "v16" and sample.sheet == "v16_light%d" % combo) if hero == "tadakatsu" else (sample.source in ["v11","v12","v13"] and sample.sheet in ["v11_combat","v12_light%d" % combo,"v13_light%d" % combo])
				check(expected_sequence,"Live combo must use its independently drawn sequence")
				if not cells.has(sample.cell): cells.append(sample.cell)
			check(cells.size() >= 7,"Live light sequence must traverse seven or more drawings")
		var pain_cells := []
		for tick in range(18):
			var pain := view._fighter_animation({"kind":hero,"team":0,"action":"hurt","action_tick":tick})
			check(pain.sheet == "v17_hurt" if hero == "tadakatsu" else pain.sheet in ["v11_reactions","v12_hurt"],"All heroes need an independently drawn pain sequence")
			if not pain_cells.has(pain.cell): pain_cells.append(pain.cell)
		check(pain_cells.size() >= 7,"Every hero shows at least seven actual pain drawings")
	for faction in Battle.FACTIONS:
		for kind in ["soldier","flag","commander","archer","gunner","boss"]:
			var fighter := {"kind":kind,"faction":faction,"team":1,"action":"hurt","action_tick":0}
			var clip_prefix: String = faction + ":" + kind + ":"
			var formal: bool = faction == "imagawa" and view._art.enemy_clips.has(clip_prefix + "hurt")
			var hd_pain: bool = faction == "mori" and view._art.enemy_clips.has(clip_prefix + "hurt")
			var cells := []
			for tick in range(18):
				fighter.action_tick = tick
				var pain := view._fighter_animation(fighter)
				var expected_pain: bool = pain.source == "v19" and pain.sheet == "enemy_clip:" + clip_prefix + "hurt" if formal else ((pain.source == "v14" and pain.sheet == "enemy_clip:" + clip_prefix + "hurt") if hd_pain else (pain.source == "v11" and pain.sheet == "enemy_reaction"))
				check(expected_pain,"Every faction needs actual pain poses from its current source")
				if not cells.has(pain.cell): cells.append(pain.cell)
			var pain_count: int = 3 if formal else ((6 if kind == "boss" else 3) if hd_pain else 4)
			check(cells.size() == pain_count,"Pain traverses the actual bent poses of the new or legacy source")
			fighter.action = "defeated"
			fighter.action_tick = 30
			var dead := view._fighter_animation(fighter)
			fighter.action_tick = 100
			check(view._fighter_animation(fighter).cell == dead.cell,"Dead actors stay on the flat endpoint")
			var drawing: Dictionary = view._art.enemy_frame(kind,dead.cell,faction,dead.sheet)
			check(drawing.region.size.x > drawing.region.size.y * 1.7,"Death drawing must actually be horizontal")
			check((dead.frame == dead.count - 1 and dead.count >= 6) if dead.source in ["v14","v19"] else dead.frame >= 6,"Death finishes on the final drawn collapse pose")
			fighter.action = "retreat"
			fighter.moving = true
			fighter.id = 7
			var role := ["soldier","flag","commander","archer","gunner","boss"].find(kind)
			check(counts.has("movement-" + faction),"Each faction needs real movement frames")
			var hd_walk: bool = faction in ["mori","imagawa"] and view._art.enemy_clips.has(clip_prefix + "walk")
			var walk_count: int = view._art.enemy_clips[clip_prefix + "walk"].size() if hd_walk else int(counts["movement-" + faction][role])
			var expected_walk: bool = walk_count >= 6 if formal else (walk_count == (12 if kind == "boss" else 6) if hd_walk else walk_count >= 7)
			check(expected_walk,"Walking uses the approved high-resolution cycle or the existing legacy drawings")
			if kind in ["archer","gunner"]:
				var steps := []
				var expected := []
				for phase in range(walk_count):
					view._walk_distance[7] = (phase + .01) * 106.0 / walk_count
					view._walk_ticks[7] = phase * 60.0 / walk_count if formal else phase * 5
					var step := view._fighter_animation(fighter)
					check(step.sheet == ("enemy_clip:" + clip_prefix + "walk" if hd_walk else "enemy_movement"),"Backsteps use actual movement drawings")
					steps.append(step.cell)
					expected.append(posmod(-phase,walk_count))
				check(steps == expected,"Retreat must run separate walk poses backward while facing target")
			fighter.boss_variant = Battle.FACTIONS[faction].boss
			fighter.action = Frames.primary_enemy_action(fighter)
			var hd_attack: bool = faction in ["mori","imagawa"] and view._art.enemy_clips.has(clip_prefix + fighter.action)
			var timing: Array = Battle.enemy_timing(fighter)
			var attack_cells := []
			for tick in range(timing[1]):
				fighter.action_tick = tick
				var strike := view._fighter_animation(fighter)
				if formal: check(strike.source == "v19","Formal Imagawa attacks must not fall back to older artwork")
				check((strike.sheet == "enemy_clip:" + clip_prefix + fighter.action and strike.count >= 6) if hd_attack else (strike.sheet == "enemy_attack" and strike.count >= 7),"Every role and faction needs actual primary attack drawings: %s%s sheet=%s count=%d" % [clip_prefix,fighter.action,strike.sheet,strike.count])
				if not attack_cells.has(strike.cell): attack_cells.append(strike.cell)
				var attack_drawing: Dictionary = view._art.enemy_frame(kind,strike.cell,faction,strike.sheet)
				check(not attack_drawing.is_empty() and attack_drawing.region.has_area(),"Primary attack must resolve the same actual source sheet")
			check(attack_cells.size() >= (6 if hd_attack else 7),"Primary attack traverses its full true-drawing sequence")
			fighter.action_tick = timing[0]
			var impact := view._fighter_animation(fighter)
			var impact_frame: int = impact.count / 2
			if hd_attack and view._art.enemy_clips[clip_prefix + fighter.action][0].has("frame_tick"):
				for index in range(impact.count):
					if timing[0] >= view._art.enemy_clips[clip_prefix + fighter.action][index].frame_tick: impact_frame = index
			check(impact.frame == impact_frame and impact.released,"Enemy impact pose matches the exact damage or projectile tick")
			if kind in ["archer","gunner"]:
				var release_art: Dictionary = view._art.enemy_frame(kind,impact.cell,faction,impact.sheet)
				check(release_art.has("hand_offset"),"Every new ranged source needs its own measured release point")
				check(Rect2(Vector2(-12,-12),release_art.region.size + Vector2(24,24)).has_point(release_art.anchor + release_art.hand_offset),"Release hand must belong to the current source region")
			if fighter.action == "boss_double":
				fighter.action_tick += 18
				check(view._fighter_animation(fighter).frame == impact.frame,"Second boss strike also matches its real hit tick")
			elif fighter.action in ["boss_chain","boss_hook"]:
				fighter.action_tick += 28
				check(view._fighter_animation(fighter).frame == (3 if hd_attack else (9 if impact.count == 12 else impact.count - 2)),"Chain pull follow-up uses the closing strike drawing")
	var oichi := {"kind":"oichi","team":0,"action":"light","action_tick":6,"combo":3}
	var kick := view._fighter_animation(oichi)
	check(kick.frame == kick.count / 2 and (kick.sheet == "v12_light3" or (kick.sheet == "v11_combat" and kick.cell / 8 == 3)),"Kick impact drawing must match actual hit tick")
	for action in ["rising","low_sweep","air_light"]:
		oichi.action = action
		check(view._fighter_animation(oichi).sheet in ["v11_needles","v12_" + action],"Oichi light techniques must throw needles, not draw the heavy bow")
	for action in ["holding","throw","guard","victory"]:
		oichi.action = action
		var expected_sheets := ["v15_victory"] if action == "victory" else ["v11_movement","v12_" + action,"v12_throw"]
		check(view._fighter_animation(oichi).sheet in expected_sheets,"Oichi needs dedicated " + action + " poses")
	oichi.action = "throw"
	oichi.action_tick = 12
	check(view._fighter_animation(oichi).released,"Oichi throw pose releases at the actual throw tick")
	check(Frames.hero_v10_sample({"action":"defeated"}).cell == 22,"Legacy hero death must lie flat, not prop on elbow")
	view.free()
	print("PASS: v11 real pose traversal, all faction pain/corpse art, stable flat endpoints and backsteps: ",checks)
	quit()
