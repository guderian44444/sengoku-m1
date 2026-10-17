extends SceneTree

const Battle = preload("res://core/battle.gd")
const Moves = preload("res://core/combat_moves.gd")
const View = preload("res://render/battle_view.gd")
const Equipment = preload("res://core/equipment.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0

class Board extends View:
	var rows := []
	var combat_preview := false
	func _draw() -> void:
		draw_rect(Rect2(0,0,1600,960),Color("273337"))
		for row in range(rows.size()):
			for col in range(rows[row].size()):
				var pose: Dictionary = rows[row][col]
				var fighter: Dictionary = pose.fighter
				_walk_ticks[fighter.id] = pose.tick
				fighter.moving = not combat_preview
				var origin := Vector2(col*800+400 if combat_preview else col*200+100,row*400+370 if combat_preview else row*240+202)
				draw_line(origin-Vector2(95,0),origin+Vector2(95,0),Color("a39a7b"))
				for source in pose.get("effects",[]):
					if source.type!="slam": continue
					var effect: Dictionary = source.duplicate()
					effect.x += origin.x-float(fighter.x)
					effect.y += origin.y-float(fighter.y)
					_draw_ground_effect(effect)
				_draw_art_fighter(fighter,origin)
				var label: String = fighter.action if combat_preview else ("run" if fighter.sprinting else "walk")
				draw_string(ThemeDB.fallback_font,origin+Vector2(-90,-175),"%s %s #%d" % [label,"L" if fighter.face<0 else "R",col+1],HORIZONTAL_ALIGNMENT_LEFT,-1,16)
	func _process(_delta: float) -> void: pass

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func locomotion(view: Board) -> void:
	for hero in Moves.HEROES:
		for face in [1,-1]:
			for running in [false,true]:
				var battle := Battle.new()
				battle.reset_training(hero,"dummy")
				battle.state.props.clear()
				var player: Dictionary = battle.state.fighters[0]
				player.x = 1000.0
				battle.state.fighters = [player]
				view.state = battle.state
				view._update_motion()
				var seen := {}
				var poses := {}
				var clip := "run" if running else "walk"
				for tick in range(100):
					battle.step([{"dx":face,"stick_full":running}])
					var sample := view.animation_sample(hero)
					if running and not player.sprinting: continue
					check(sample.clip==clip,"Actual movement selects "+hero+"/"+clip)
					seen[sample.frame] = true
					poses[sample.frame] = {"fighter":player.duplicate(true),"tick":view._walk_ticks[player.id]}
				var count: int = view._art.animations[hero]["v22_"+clip].size()
				check(seen.size()==count,"Live renderer advances every pose: "+hero+"/"+clip)
				if hero=="mitsuhide":
					var row := []
					for frame in range(count): row.append(poses[frame])
					view.rows.append(row)
				battle.step([{}])
				check(view.animation_sample(hero).clip=="idle","Stopping returns to idle: "+hero)
				for tick in range(20):
					battle.step([{"dx":face,"stick_full":false}])
					view.animation_sample(hero)
				check(view.animation_sample(hero).frame>0,"Movement clock resumes after stopping: "+hero)
				var previous := view._walk_ticks.duplicate()
				view.animation_sample(hero)
				check(view._walk_ticks==previous,"Repeated rendering cannot advance simulation time")

func ranges() -> void:
	for action in ["charged","air_heavy"]:
		for face in [-1,1]:
			for weapon in Weapons.ids_for("nobunaga"):
				var reach := (330.0 if action=="charged" else 420.0)+float(Weapons.item(weapon).get("reach_bonus",0))+12.0
				var depth := 135.0 if action=="charged" else 150.0
				var rear := 330.0 if action=="charged" else 36.0
				for probe in [Vector3(reach,0,1),Vector3(reach+.1,0,0),Vector3(80,depth,1),Vector3(80,depth+.1,0),Vector3(-rear,0,1),Vector3(-rear-.1,0,0)]:
					var battle := Battle.new()
					battle.reset_training("nobunaga","dummy")
					var player: Dictionary = battle.state.fighters[0]
					Equipment.equip(player,Equipment.add(player,weapon))
					Equipment.equip(player,Equipment.add(player,"moon"))
					player.face = face
					player.action = action
					var target: Dictionary = battle.state.fighters[1]
					target.x = player.x+probe.x*face
					target.y = player.y+probe.y
					var hp := float(target.hp)
					battle._combat_contact_v33(player,"contact")
					check((target.hp<hp)==bool(probe.z),"Expanded hit boundary with equipment: "+action+"/"+weapon+"/"+str(probe))
					check(is_equal_approx(player.attack_reach,reach),"Range keeps additive weapon and talisman bonus")

func issen() -> void:
	for face in [-1,1]:
		var battle := Battle.new()
		battle.reset_training("ieyasu","dummy")
		battle.state.props.clear()
		var player: Dictionary = battle.state.fighters[0]
		player.x = 1000.0
		player.face = face
		battle.state.fighters = [player]
		var ticks := ceili(float(Moves.registration("ieyasu").clips.charge_ready.duration_ms)*.06)
		for tick in range(ticks+1): battle.step([{"buttons":Battle.HEAVY}])
		battle.step([{}])
		check(player.action=="charged","Holding heavy for 0.9 seconds then releasing triggers Ieyasu's Issen")
		var origin := float(player.x)
		var wave := false
		for tick in range(100):
			battle.step([{}])
			wave = wave or battle.state.effects.any(func(e): return e.get("combat_sword_wave",false))
		check(is_equal_approx((float(player.x)-origin)*face,365.0),"Issen advances all three authored steps")
		check(wave and player.action=="idle" and Wire.valid_snapshot(battle.state),"Issen emits piercing wave and recovers with a valid snapshot")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600,960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := Board.new()
	viewport.add_child(view)
	locomotion(view)
	ranges()
	issen()
	if DisplayServer.get_name()!="headless":
		view.state.fighters = []
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var folder := "res://../artifacts/combat-tuning-v37"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		check(viewport.get_texture().get_image().save_png(folder+"/kennyo-locomotion.png")==OK,"Native locomotion capture saved")
		view.rows.clear()
		view.combat_preview = true
		for action in ["charged","air_heavy"]:
			var row := []
			for face in [1,-1]:
				var battle := Battle.new()
				battle.reset_training("nobunaga","dummy")
				var fighter: Dictionary = battle.state.fighters[0]
				fighter.face = face
				battle._begin(fighter,action)
				for tick in range(100):
					battle.step([{}])
					if battle.state.events.any(func(e): return e.type=="weapon_swing"):
						if action=="air_heavy":
							for age in range(6): battle.step([{}])
						row.append({"fighter":fighter.duplicate(true),"tick":0,"effects":battle.state.effects.duplicate(true)})
						break
			check(row.size()==2,"Both facing attack contacts captured")
			view.rows.append(row)
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png(folder+"/nobunaga-heavy-range.png")==OK,"Native enlarged combat effects saved")
	viewport.free()
	print("COMBAT TUNING V37 PASS: %d checks" % checks)
	quit()
