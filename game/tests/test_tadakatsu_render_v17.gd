extends SceneTree

const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const Frames = preload("res://render/frame_animation.gd")
const CLIPS := ["slam_charge","charged_slam","charge_forward","upper","low_sweep","dash","air_light","air_heavy","hurt","guard","death","recover","special","holding","throw","launched"]
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var view := View.new()
	var required := "--require-v17" in OS.get_cmdline_user_args()
	for clip in CLIPS:
		var key: String = "v17_" + clip
		if required:
			var drawings: Array = view._art.animations.tadakatsu.get(key,[])
			check(drawings.size() == 12,key + " requires twelve authored source frames")
			for drawing in drawings:
				check(drawing.source == "v17" and drawing.body_height >= 220 and not drawing.texture.get_image().is_empty(),key + " must load actual full-resolution artwork")
		else: view._art.animations.tadakatsu[key] = range(12)
	var routes := {"charged":"dash","dash_heavy":"dash","dash_strike":"dash","rising":"upper","upper_heavy":"upper","charged_upper":"upper","low_sweep":"low_sweep","ground_slam":"charged_slam","charged_slam":"charged_slam","air_light":"air_light","air_heavy":"air_heavy"}
	var timings := {"charged":[5,36],"dash_heavy":[12,34],"dash_strike":[10,30],"rising":[6,24],"upper_heavy":[12,36],"charged_upper":[22,56],"low_sweep":[9,28],"ground_slam":[14,42],"charged_slam":[28,72],"air_light":[6,20],"air_heavy":[12,38]}
	for action in routes:
		var timing: Array = timings[action]
		var fighter := {"kind":"tadakatsu","team":0,"action":action,"action_tick":Battle.hero_tick("tadakatsu",timing[0])}
		var sample := view._fighter_animation(fighter)
		check(sample.sheet == "v17_" + routes[action] and sample.frame == 6 and sample.released,action + " uses its authored contact pose on the actual damage tick")
		fighter.action_tick -= 1
		check(not view._fighter_animation(fighter).released,action + " cannot visibly strike before the simulation contact")
		var seen := []
		for tick in range(Battle.hero_tick("tadakatsu",timing[1])):
			fighter.action_tick = tick
			var frame: int = view._fighter_animation(fighter).frame
			if not seen.has(frame): seen.append(frame)
		check(seen == range(12),action + " exposes every sequential drawing without skipping or shuffling")
	for direction in [-1,0,1]:
		var fighter := {"kind":"tadakatsu","team":0,"action":"charge","action_tick":0,"charge_direction":direction,"charge":0}
		var expected := "v17_slam_charge" if direction > 0 else ("v17_upper" if direction < 0 else "v17_charge_forward")
		var seen := []
		for tick in range(91):
			fighter.charge = tick
			var sample := view._fighter_animation(fighter)
			check(sample.sheet == expected and not sample.released,"Charge direction selects its own preparation and never attacks while held")
			if not seen.has(sample.frame): seen.append(sample.frame)
		check(seen == range(6 if direction < 0 else 12),"Charge reaches each prepared drawing once and then holds its final pose")
	for action in ["hurt","guard","holding","throw","down","defeated","recovering"]:
		var seen := []
		for tick in range(90):
			var sample := view._fighter_animation({"kind":"tadakatsu","team":0,"action":action,"action_tick":tick})
			check(sample.source == "v17",action + " cannot fall back to the three-frame reactions atlas")
			if not seen.has(sample.frame): seen.append(sample.frame)
		check(seen == range(12),action + " plays all twelve source drawings")
	var release := view._fighter_animation({"kind":"tadakatsu","team":0,"action":"throw","action_tick":0})
	check(release.released and release.frame == 0,"Throw artwork begins at actual release, after the held victim leaves the hand")
	for action in ["mixed_finisher","mixed_rising"]:
		for hit in [9,27]:
			var fighter := {"kind":"tadakatsu","team":0,"action":action,"action_tick":Battle.hero_tick("tadakatsu",hit)}
			var sample := view._fighter_animation(fighter)
			check(sample.frame == 6 and sample.released,action + " synchronizes both contacts, not only the first")
			if hit == 27: check(sample.sheet == ("v17_upper" if action == "mixed_rising" else "v17_charged_slam"),"Mixed finisher ends in the matching dedicated directional technique")
	for hit in Battle.SPECIAL_HIT_TICKS.tadakatsu:
		var sample := view._fighter_animation({"kind":"tadakatsu","team":0,"action":"special","action_tick":hit})
		check(sample.sheet == "v17_special" and sample.frame == 6 and sample.released,"Each special pulse reaches its actual full-extension impact pose")
	var actor := {"id":101,"kind":"tadakatsu","team":0,"action":"idle","moving":true,"z":0}
	for run in [false,true]:
		actor.sprinting = run
		for frame in range(12):
			view._walk_ticks[101] = frame * (60.0 / (16.0 if run else 12.0)) + .01
			var sample := view._fighter_animation(actor)
			check(sample.sheet == ("v16_run" if run else "v16_walk") and sample.frame == frame,"Walk and run use active movement time and all twelve drawings")
	actor.moving = false
	check(view._fighter_animation(actor).clip == "idle","Releasing movement immediately returns to standing")
	for tick in range(35):
		var sample := view._fighter_animation({"kind":"tadakatsu","team":0,"action":"idle","z":1,"vz":9.0 - tick * .55})
		check(sample.frame == clampi(floori(tick * .55 / 18.0 * 12.0),0,11),"Jump progresses from rise to landing without reversing the source sequence")
	view.state = {"phase":"won","tick":10000}
	check(view._fighter_animation({"kind":"tadakatsu","team":0,"action":"victory","action_tick":0}).frame == 0,"Victory does not inherit the global clock and skip to the final pose")
	check(view._fighter_animation({"kind":"tadakatsu","team":0,"action":"defeated","action_tick":24}).sheet == "v17_death","A dead cooperative partner remains prone during the win screen")
	var weak := View.charge_visual(0,155)
	var strong := View.charge_visual(35,155)
	check(strong.amount > weak.amount and strong.radius > weak.radius and strong.width > weak.width,"The surrounding charge aura grows with held charge")
	check(View.charge_visual(90,155) == strong,"Holding a completed charge maintains full aura instead of pulsing its size")
	for tick in [5,10,15]:
		var accent := View.strike_accent({"kind":"tadakatsu","action":"charged"},{"tick":tick,"source":"v17"})
		check(not accent.is_empty() and accent.thrust and accent.age == 0,"Every rushing spear contact gets a synchronized straight thrust accent")
	var flight_seen := []
	for tick in range(35):
		var sample := view._fighter_animation({"kind":"tadakatsu","team":0,"action":"launched","action_tick":tick,"vz":9.0 - tick * .55,"z":1})
		check(sample.sheet == "v17_launched","Launched body uses its dedicated flight drawings")
		if not flight_seen.has(sample.frame): flight_seen.append(sample.frame)
	check(flight_seen == range(12),"The new launch sequence progresses through all twelve ascent and descent drawings")
	view.free()
	print("V17 TADAKATSU RENDER: %d checks, %d failures; %s" % [checks,failures,"actual source assets required" if required else "timing and routing fixtures only"])
	quit(0 if failures == 0 else 1)
