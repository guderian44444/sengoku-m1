extends SceneTree

const Battle = preload("res://core/battle.gd")
const Frames = preload("res://render/frame_animation.gd")
const View = preload("res://render/battle_view.gd")
const EXPECTED_PULSES := {
	"nobunaga":[26,68,110,152,192], "oichi":[26,68,110,152,192],
	"hideyoshi":[18,44,70,96,122,148,174,198], "ieyasu":[36,102,168],
	"mitsuhide":[24,66,108,150,192], "tadakatsu":[36,84,132,180],
}
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	for hero in Battle.HEROES:
		for count in [7,8]:
			var counts := {"skills":[count,count,count,count,count,count]}
			var fighter := {"kind":hero,"action":"special","action_tick":0}
			var releases := []
			var seen := []
			var previous := -1
			for tick in range(Battle.SPECIAL_TICKS):
				fighter.action_tick = tick
				var sample := Frames.hero_v11_sample(fighter,0,155,counts)
				check(sample.frame >= 0 and sample.frame < count,"Special frame stays inside its measured row")
				if sample.frame >= count / 2 and previous < count / 2: releases.append(tick)
				if not seen.has(sample.frame): seen.append(sample.frame)
				previous = sample.frame
			check(releases == EXPECTED_PULSES[hero],hero + " drawing releases match every special pulse for " + str(count) + " frames")
			check(seen.size() == count,hero + " special uses every windup and recovery drawing")
			for hit in EXPECTED_PULSES[hero]:
				fighter.action_tick = hit - 0.01
				var before := Frames.hero_v11_sample(fighter,0,155,counts)
				check(before.frame < count / 2 and not before.released,hero + " stays in windup immediately before each pulse")
				fighter.action_tick = hit
				var impact := Frames.hero_v11_sample(fighter,0,155,counts)
				check(impact.frame == count / 2 and impact.released,hero + " uses first strike drawing at the exact emission tick")
			fighter.action_tick = Battle.SPECIAL_TICKS + 10
			check(Frames.hero_v11_sample(fighter,0,155,counts).frame == count - 1,hero + " holds final recovery instead of looping after special")
	var view := View.new()
	for hero in Battle.HEROES:
		var thrower := {"kind":hero,"team":0,"action":"throw","action_tick":11}
		if hero == "tadakatsu":
			thrower.action_tick = 0
			var release: Dictionary = view._fighter_animation(thrower)
			check(release.sheet == "v17_throw" and release.frame == 0 and release.released,"Tadakatsu v17 throw releases immediately from its first drawing")
			thrower.action_tick = 23
			check(view._fighter_animation(thrower).frame == 11,"Tadakatsu v17 throw completes all twelve drawings before the simulation ends")
		elif view._art.animations[hero].has("v12_throw"):
			thrower.action_tick = 0
			var release: Dictionary = view._fighter_animation(thrower)
			check(release.frame == 6 and release.released,hero + " throw follows the immediate grab release")
			thrower.action_tick = 23
			check(view._fighter_animation(thrower).frame == 11,hero + " throw completes recovery before the simulation ends")
		else:
			check(not view._fighter_animation(thrower).released,hero + " retains its legacy throw preparation")
			thrower.action_tick = 12
			check(view._fighter_animation(thrower).released,hero + " retains its legacy throw release drawing")
		var battle := Battle.new()
		battle.reset_training(hero)
		var player: Dictionary = battle.state.fighters[0]
		battle.state.fighters = [player]
		battle.state.props = []
		battle.state.drops = []
		battle.step([{"buttons":Battle.SPECIAL}])
		check(player.action == "special",hero + " special starts through live input")
		var emitted := []
		for tick in range(1,Battle.SPECIAL_TICKS + 1):
			battle.step([{"buttons":0}])
			var pulse: bool = battle.state.effects.any(func(effect: Dictionary) -> bool:
				return str(effect.type).ends_with("_wave") and effect.life == effect.max_life)
			if pulse:
				emitted.append(player.action_tick)
				var drawing := view._fighter_animation(player)
				var expected_sequence: bool = drawing.sheet == "v17_special" if hero == "tadakatsu" else (drawing.sheet == "v12_special" or (drawing.sheet == "v11_skills" and drawing.cell / 8 == 5))
				check(expected_sequence,hero + " emitted attack uses the special sequence")
				check(drawing.frame == drawing.count / 2 and drawing.released,hero + " live emission matches its strike drawing")
		check(emitted == EXPECTED_PULSES[hero],hero + " simulation retains all original pulse times")
		check(player.action == "idle",hero + " special still ends after 210 simulation ticks")
	view.free()
	print("PASS" if failures == 0 else "FAIL", ": special pulse animation alignment: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
