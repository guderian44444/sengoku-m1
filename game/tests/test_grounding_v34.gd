extends SceneTree

const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const StageArt = preload("res://render/stage_art.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var art := StageArt.new()
	var battle := Battle.new()
	battle.reset_campaign("normal",1,["nobunaga"])
	var kinds := {}
	for scene in range(7):
		battle._enter_segment(scene)
		for prop in battle.state.props:
			var frame := art.prop(str(prop.kind))
			var original := var_to_bytes(prop)
			var depth := View.prop_ground_depth(prop,frame)
			check(depth > 0 and depth <= float(prop.depth),"Visible footprint stays inside collision bounds: " + str(prop.kind))
			check(var_to_bytes(prop) == original,"Grounding leaves authoritative prop data unchanged")
			if prop.get("mandatory",false):
				check(depth <= float(frame.display_height) * .5,"Checkpoint blocking depth must not push the image 65 pixels forward")
			else: kinds[prop.kind] = prop.duplicate()
	for kind in kinds:
		var prop: Dictionary = kinds[kind]
		prop.x = 500.0
		prop.y = 480.0
		var display := prop.duplicate()
		display.ground_depth = View.prop_ground_depth(prop,art.prop(kind))
		battle.state.props = [prop]
		battle.state.fighters = battle.state.fighters.filter(func(f): return f.team == 0)
		var player: Dictionary = battle.state.fighters[0]
		player.x = prop.x
		player.y = 590.0
		for tick in range(100): battle._move_fighter(player,0,-2)
		var gap := float(player.y) - View.fighter_depth(display)
		check(gap >= 11.99 and gap <= 14.01,"Approaching visible front stops at the player's 12 pixel collision margin: " + kind)
		check(View.fighter_depth(player) > View.fighter_depth(display),"Player walking in front draws over the object")
		prop.broken = true
		check(View.prop_ground_depth(prop,art.prop(kind)) == 0,"Broken rubble returns to its ground center")
		for tick in range(100): battle._move_fighter(player,0,-2)
		check(player.y < prop.y,"Destroyed props do not leave invisible blockers")
	var cabinet := {"x":500.0,"y":480.0,"ground_depth":58.0,"broken":false}
	var player := {"team":0,"hp":100,"x":500.0,"y":495.0}
	check(View.fighter_depth(cabinet) > View.fighter_depth(player),"Near face occludes actors between center and front edge")
	check(View.prop_opacity(cabinet,[player],150,170) == .42,"A player behind the shifted front edge remains visible")
	player.y = 510.0
	check(View.prop_opacity(cabinet,[player],150,170) == 1.0,"Player ahead of the object does not fade it")
	check(View.fighter_depth({"y":500.0,"z":120.0}) == 500,"Airborne fighters keep ground-plane depth ordering")
	check(View.fighter_depth({"y":500.0,"held_by":4}) > 500,"Carried fighters remain in front of their holder")
	print("GROUNDING V34 %s: %d checks, %d failures; collision approach, footprint anchors, depth ordering, player reveal and broken props." % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)
