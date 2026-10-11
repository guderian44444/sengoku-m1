extends SceneTree

const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var view := View.new()
	var impacts := {"light":6,"heavy":14,"charged":14,"rising":6,"ground_slam":14,"low_sweep":9,"dash_strike":10,"air_light":6,"air_heavy":12,"upper_heavy":12,"charged_upper":22,"charged_slam":28,"mixed_finisher":9,"mixed_rising":9,"counter_cut":5}
	for hero in Battle.HEROES:
		for action in impacts:
			var hit := int(impacts[action])
			var actual_hit := Battle.hero_tick(hero,hit)
			var fighter := {"kind":hero,"team":0,"action":action,"action_tick":actual_hit,"combo":1,"heavy_combo":1}
			var sample := view._fighter_animation(fighter)
			check(is_equal_approx(float(sample.tick),float(hit)),hero + " " + action + " impact drawing matches rounded simulation tick")
			check(sample.released,hero + " " + action + " impact is released at damage tick")
			fighter.action_tick = actual_hit - 1
			check(not view._fighter_animation(fighter).released,hero + " " + action + " must not strike before simulation hit")
		for action in ["mixed_finisher","mixed_rising"]:
			check(is_equal_approx(View._hero_animation_tick(hero,action,Battle.hero_tick(hero,27)),27),"Second mixed hit matches the rounded simulation tick")
		check(is_equal_approx(View._hero_animation_tick(hero,"air_heavy",Battle.hero_tick(hero,19)),19),"Air heavy landing pulse matches rounded simulation tick")
	var sim := Battle.new()
	sim.reset_training("nobunaga","enemies","imagawa")
	var player: Dictionary = sim.state.fighters[0]
	for face in [-1,1]:
		for kind in ["archer","gunner"]:
			var ranged: Dictionary = sim._make_fighter(1,kind,85.0 if face == 1 else 2295.0,470.0,60)
			player.x = ranged.x + face * 65.0
			player.y = 410.0
			ranged.action = "retreat"
			sim._enemy_input(ranged)
			check(ranged.face == face and ranged.move_dx == face,"Wall escape actually moves forward while facing target")
			check(not View._retreat_backwards(ranged),"Forward wall escape must not reverse its gait")
			ranged.x = 1100.0
			player.x = ranged.x + face * 65.0
			player.y = ranged.y
			sim._enemy_input(ranged)
			check(ranged.move_dx == -face and View._retreat_backwards(ranged),"Ordinary backstep must reverse gait for either facing")
			view._walk_distance[ranged.id] = 106.0 / 8.0 + 0.1
			ranged.moving = true
			var backwards := view._fighter_animation(ranged)
			ranged.move_dx = face
			var forwards := view._fighter_animation(ranged)
			check(backwards.cell == 7 and forwards.cell == 1,"Live new atlas reverses only actual backsteps")
	view.free()
	print("PASS" if failures == 0 else "FAIL", ": rounded attack timings and direction-aware ranged retreat: ",checks)
	quit(0 if failures == 0 else 1)
