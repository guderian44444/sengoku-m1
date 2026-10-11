extends SceneTree

const Frames = preload("res://render/frame_animation.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	# These fixtures test playback timing; source drawing uniqueness is checked by the art tests.
	for count in [6,12]:
		var drawings := []
		for index in range(count): drawings.append({"source":"v19"})
		var clips := {"imagawa:soldier:walk":drawings,"imagawa:soldier:idle":[{"source":"v19"}]}
		var fighter := {"kind":"soldier","faction":"imagawa","action":"idle","moving":true,"face":1,"move_dx":1}
		var checkpoints: Dictionary = {0:0,9:0,10:1,29:2,30:3,59:5,60:0,70:1,119:5} if count == 6 else {0:0,4:0,5:1,29:5,30:6,59:11,60:0,65:1,119:11}
		for tick in checkpoints:
			var sample := Frames.enemy_v14_sample(fighter,float(tick),0,clips)
			check(not sample.is_empty(),"Formal Imagawa movement resolves its own source")
			if sample.is_empty(): continue
			check(sample.source == "v19" and sample.sheet == "enemy_clip:imagawa:soldier:walk","Formal gait cannot fall back to older enemy drawings")
			check(sample.frame == checkpoints[tick],"%d poses retain the one-second walk cycle at tick %d" % [count,tick])
			check(sample.duration == 60,"Reducing pose count never accelerates the complete gait")
		for face in [-1,1]:
			fighter.action = "retreat"
			fighter.face = face
			fighter.move_dx = -face
			var backwards := Frames.enemy_v14_sample(fighter,60.0/count,0,clips)
			check(not backwards.is_empty() and backwards.get("frame",-1) == count-1,"A real backstep reverses the same cycle in either facing")
			fighter.move_dx = face
			var forwards := Frames.enemy_v14_sample(fighter,60.0/count,0,clips)
			check(not forwards.is_empty() and forwards.get("frame",-1) == 1,"A forward escape keeps the gait in forward order")
		fighter.action = "idle"
		fighter.moving = false
		var stopped := Frames.enemy_v14_sample(fighter,25,25,clips)
		check(not stopped.is_empty() and stopped.get("clip","") == "idle" and stopped.get("frame",-1) == 0,"Releasing movement immediately uses the standing source")
	# The established Mori timing is a separate contract and must not change with this upgrade.
	var old_drawings := []
	for index in range(6): old_drawings.append({"source":"v14"})
	var old := Frames.enemy_v14_sample({"kind":"soldier","faction":"mori","action":"idle","moving":true},30,0,{"mori:soldier:walk":old_drawings})
	check(old.frame == 0 and old.duration == 30 and old.source == "v14","Existing Mori clips retain their previous 12 fps cadence")
	print("ENEMY WALK V19: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
