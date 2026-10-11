extends SceneTree
const View = preload("res://tests/legacy_battle_view.gd")
const Battle = preload("res://core/battle.gd")
const Frames = preload("res://render/frame_animation.gd")
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func _initialize() -> void:
	var view := View.new()
	for hero in ["nobunaga","oichi"]:
		for clip in ["walk","run","jump","guard","throw","victory","hurt","down","recovering","stunned","launched","rising","low_sweep","charged_upper","charged_slam","air_light","air_heavy","special"]:
			check(view._art.animations[hero].has("v12_" + clip),hero + " is missing its matching " + clip + " drawings")
			check(view._art.animations[hero]["v12_" + clip].size() == 12,"Pilot actions need twelve independently drawn frames")
		for clip in ["light1","light2","light3","heavy1","heavy2"]:
			check(view._art.animations[hero].has("v12_" + clip),hero + " is missing " + clip)
			var frames: Array = view._art.animations[hero]["v12_" + clip]
			check(frames.size() == 12,"Every main attack has twelve source drawings")
			var sources := []
			for frame in frames:
				check(frame.source == "v12" and frame.body_height >= 220,"Use native HD drawings, not enlarged small figures")
				var key := str(frame.texture.get_instance_id()) + str(frame.region)
				check(not sources.has(key),"Duplicating a drawing is not another frame")
				sources.append(key)
			var action := "light" if clip.begins_with("light") else "heavy"
			var hit := 6 if action == "light" else 14
			var fighter := {"kind":hero,"team":0,"action":action,"combo":int(clip.right(1)),"heavy_combo":int(clip.right(1)),"action_tick":Battle.hero_tick(hero,hit)}
			var impact := view._fighter_animation(fighter)
			var expected_sheet: String = ("v13_" if view._art.animations[hero].has("v13_" + clip) else "v12_") + clip
			check(impact.sheet == expected_sheet and impact.frame == 6 and impact.released,"HD impact matches actual damage tick")
			fighter.action_tick -= 1
			check(not view._fighter_animation(fighter).released,"Windup must not release early")
	for hero in ["hideyoshi","ieyasu","mitsuhide","tadakatsu"]:
		check(not view._art.animations[hero].has("v12_light1"),"Unapproved hero redesign stays out of this pilot")
	for faction in Battle.FACTIONS:
		var key: String = view._art._enemy_key("boss",faction)
		check(view._art.enemy_attacks[key][0].source != "v12","Enemy redesign stays deferred until its concept is confirmed")
	for clip in ["idle","walk","light3","hurt","down","guard","throw"]:
		check(view._art.animations.oichi.has("v12_" + clip),"Oichi source family is incomplete: " + clip)
	var walker := {"id":9,"kind":"oichi","team":0,"action":"idle","moving":true}
	for frame in range(12):
		view._walk_ticks[9] = frame * 5
		var sample := view._fighter_animation(walker)
		check(sample.sheet.ends_with("_walk") and sample.frame == frame,"Fixed time advances all twelve separately drawn poses")
	view._walk_ticks[9] = 60
	check(view._fighter_animation(walker).frame == 0,"The walk cycle returns to its first contact")
	for clip in ["light1","light2","heavy1","heavy2","rising","low_sweep","air_light","charged_upper","charged_slam","air_heavy","special"]:
		var frame: Dictionary = view._art.animations.oichi["v12_" + clip][6]
		check(frame.has("hand_offset"),"Each projectile source has a measured release point")
		check(Rect2(Vector2(-12,-12),frame.region.size + Vector2(24,24)).has_point(frame.anchor + frame.hand_offset),"Release point belongs to the current drawing")
	view.free()
	print("PASS: HD source resolution, unique drawings, matching hit ticks, pilot scope and walk cycle: ",checks)
	quit()
