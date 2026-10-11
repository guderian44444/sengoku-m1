extends SceneTree

const View = preload("res://render/battle_view.gd")
const Frames = preload("res://render/frame_animation.gd")
const Battle = preload("res://core/battle.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_test_active_clocks()
	_test_battle_stop()
	_test_demo_clock()
	_test_samples()
	_test_legacy_dash()
	print("V13 WALK CLOCK: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _test_active_clocks() -> void:
	var view := View.new()
	var slow := {"id":1,"kind":"nobunaga","team":0,"action":"idle","x":100.0,"y":500.0,"z":0.0}
	var fast := {"id":2,"kind":"oichi","team":0,"action":"idle","x":100.0,"y":500.0,"z":0.0}
	view.state = {"tick":0,"fighters":[slow,fast]}
	view._update_motion()
	for tick in range(1,67):
		view.state.tick = tick
		slow.x += .5
		fast.x += 12.0
		view._update_motion()
		var expected := int((tick - 1) / 5) % 12
		for fighter in [slow,fast]:
			var sample: Dictionary = view._fighter_animation(fighter)
			check(sample.clip == "walk" and sample.frame == expected,"Different distances keep the same 12 fps frame at tick %d" % tick)
	var paused: Dictionary = view._fighter_animation(slow)
	view.art_time = 900.0
	view._update_motion()
	check(view._fighter_animation(slow).frame == paused.frame,"A paused battle tick does not advance the walk clock")
	view.state.tick += 1
	fast.x += 12.0
	view._update_motion()
	check(view._fighter_animation(slow).clip == "idle","Stopping immediately selects a standing drawing")
	check(not view._walk_ticks.has(1) and view._walk_ticks[2] == 66,"Stopping player one leaves player two's clock running")
	view.state.tick += 1
	slow.x += .5
	fast.x += 12.0
	view._update_motion()
	check(view._fighter_animation(slow).frame == 0,"The next movement starts at frame zero without finishing the interrupted cycle")
	slow.action = "light"
	view.state.tick += 1
	slow.x += 5.0
	view._update_motion()
	check(not view._walk_ticks.has(1),"An attack's own forward motion never advances the walk cycle")
	slow.action = "idle"
	view.state.tick += 1
	slow.x += .5
	view._update_motion()
	check(view._fighter_animation(slow).frame == 0,"Returning to ordinary movement restarts the cycle")
	view.state.tick = 0
	view._update_motion()
	check(view._walk_ticks.is_empty(),"A fresh match cannot inherit old movement clocks")
	view.free()

func _test_battle_stop() -> void:
	for hero in ["nobunaga","oichi"]:
		var battle := Battle.new()
		battle.reset_training(hero)
		battle.state.fighters[1].x = 2200.0
		var view := View.new()
		view.state = battle.state
		view._update_motion()
		for tick in range(18):
			battle.step([{"dx":1}])
			var sample := view.animation_sample(hero)
			check(sample.clip == "walk" and sample.frame == int(tick / 5),"Real held movement advances by time for " + hero)
		var player: Dictionary = battle.state.fighters[0]
		var stop_x := float(player.x)
		battle.step([{}])
		check(view.animation_sample(hero).clip == "idle" and player.x == stop_x,"Releasing the real input stops position and pose together for " + hero)
		for tick in range(20): battle.step([{}])
		view._update_motion()
		battle.step([{"dx":1}])
		check(view.animation_sample(hero).frame == 0,"Real input resumes from the first drawing for " + hero)
		view.free()

func _test_demo_clock() -> void:
	var view := View.new()
	view.art_demo = true
	view.demo_pose = 9
	view.demo_progress = .5
	view.state = {"tick":0,"fighters":[{"id":1,"kind":"oichi","team":0,"action":"idle","moving":true,"x":100.0,"y":500.0}]}
	for tick in [0,5,10,35,55,60,65]:
		view.art_time = float(tick) / 60.0
		check(view.animation_sample("oichi").frame == int(tick / 5) % 12,"Demo seeking follows art_time rather than previous movement at %d" % tick)
	view.free()

func _test_samples() -> void:
	var drawings := []
	drawings.resize(12)
	var sheets := {"v12_walk":drawings,"v12_run":drawings,"v12_light1":drawings,"v12_heavy2":drawings,"v13_walk":drawings,"v13_light1":drawings,"v13_light3":drawings,"v13_dash_heavy":drawings}
	for hero in ["nobunaga","oichi"]:
		for sprinting in [false,true]:
			var fighter := {"kind":hero,"action":"idle","moving":true,"sprinting":sprinting}
			var fps := 16.0 if sprinting else 12.0
			for tick in range(61):
				fighter.locomotion_tick = tick
				var sample := Frames.hero_v12_sample(fighter,float(tick * 99),330,sheets)
				check(sample.frame == floori(tick * fps / 60.0 + .0001) % 12,"Walk/run fixed rate ignores distance, body height and speed")
				check(sample.sheet == ("v12_run" if sprinting else "v13_walk"),"Prefer v13 only when that clip exists")
	for tick in range(19):
		var sample := Frames.hero_v12_sample({"kind":"nobunaga","action":"light","action_tick":tick},0,155,sheets)
		check(sample.source == "v13" and sample.frame == mini(tick,11) and sample.released == (tick >= 6),"The new light arc advances uniformly then holds its final drawing")
	for hero in ["nobunaga","oichi"]:
		var sample := Frames.hero_v12_sample({"kind":hero,"action":"dash_heavy","action_tick":12},0,155,sheets)
		check(sample.sheet == ("v13_light3" if hero == "nobunaga" else "v13_dash_heavy") and sample.frame == 6 and sample.duration == 34 and sample.released,"Dash heavy uses its actual tick 12 impact and tick 34 ending")
	sheets.erase("v13_light3")
	check(Frames.hero_v12_sample({"kind":"nobunaga","action":"dash_heavy","action_tick":12},0,155,sheets).sheet == "v12_heavy2","Dash heavy keeps the legacy heavy fallback when its new sweep is absent")
	var legacy := Frames.hero_v12_sample({"kind":"hideyoshi","action":"idle","moving":true,"locomotion_tick":50},155 * .82 / 12.0,155,{"v12_walk":drawings})
	check(legacy.frame == 1,"Other heroes retain their existing distance-based contract")

func _test_legacy_dash() -> void:
	var view := View.new()
	for hero in ["hideyoshi","ieyasu","mitsuhide","tadakatsu"]:
		var fighter := {"kind":hero,"team":0,"action":"dash_heavy","action_tick":Battle.hero_tick(hero,12)}
		var sample := view._fighter_animation(fighter)
		var row := 4 if hero in ["hideyoshi","tadakatsu"] else 5
		if hero == "tadakatsu":
			check(sample.source == "v17" and sample.sheet == "v17_dash" and sample.frame == 6 and sample.count == 12 and sample.released and sample.clip == "dash_heavy","Tadakatsu dash uses the v17 twelve-frame strike at its real damage tick")
		else:
			check(sample.source == "v10" and sample.cell == row * 6 + 3 and sample.released and sample.clip == "dash_heavy","Legacy dash uses the correct heavy strike at its real damage tick for " + hero)
		fighter.action_tick -= 1
		check(not view._fighter_animation(fighter).released,"Legacy dash remains in windup before damage for " + hero)
	view.free()
