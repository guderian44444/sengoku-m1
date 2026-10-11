extends SceneTree

const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")
var checks := 0
var failures := 0

class Probe extends View:
	var drawn := {}
	var projectile_queries := 0
	func _projectile_offset(effect: Dictionary) -> Vector2:
		projectile_queries += 1
		return super._projectile_offset(effect)
	func _draw_art_frame(frame: Dictionary, origin: Vector2, height: float, face: float = 1.0, rotation: float = 0.0, _tint: Color = Color.WHITE, base_height: float = 0.0) -> void:
		drawn = {"frame":frame,"origin":origin,"height":height,"face":face,"rotation":rotation,"base_height":base_height}
	func _draw_actor_shadow(_origin: Vector2, _height: float, _z: float, _half_width: float, _center_x: float = 0.0, _contacts: Array = []) -> void: pass
	func _draw_status(_fighter: Dictionary, _origin: Vector2, _height: float) -> void: pass

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _frames(count: int) -> Array:
	var frames := []
	for index in range(count):
		frames.append({"region":Rect2(0,0,400,100),"anchor":Vector2(200,90),"body_height":300.0,"source":"v14","test_frame":index})
	return frames

func _initialize() -> void:
	var view := Probe.new()
	if "--require-v14" in OS.get_cmdline_user_args(): _test_v14_assets(view)
	# Route fixtures test timing and transforms independently of pending artwork QA.
	for kind in ["soldier","flag","commander","archer","gunner","boss"]:
		for clip in ["idle","walk","hurt","struggle","death"]:
			view._art.enemy_clips["mori:" + kind + ":" + clip] = _frames(12 if clip == "walk" and kind == "boss" else (3 if clip == "struggle" else 6))
		var attacks: Array = ["bow_shot"] if kind == "archer" else (["gun_shot"] if kind == "gunner" else Battle.ENEMY_ATTACKS[kind])
		for action in attacks: view._art.enemy_clips["mori:" + kind + ":" + action] = _frames(6)
	_test_enemy_routes(view)
	_test_authored_release_timing(view)
	_test_arc_arrow_snapshot(view)
	_test_enemy_movement(view)
	_test_death_scale(view)
	_test_run_and_slam(view)
	_test_camp_flag(view)
	_test_power()
	view.free()
	print("V14 RENDER TESTS %s: %d checks, %d failures; routing/timing/transform fixtures, not source-image visual acceptance" % ["PASSED" if failures == 0 else "FAILED",checks,failures])
	quit(0 if failures == 0 else 1)

func _test_v14_assets(view) -> void:
	for kind in ["soldier","flag","commander","archer","gunner","boss"]:
		var expected := {"idle":6 if kind == "boss" else 1,"walk":12 if kind == "boss" else 6,"hurt":6 if kind == "boss" else 3,"death":6}
		if kind != "boss": expected.struggle = 3
		var attacks: Array = ["bow_shot"] if kind == "archer" else (["gun_shot"] if kind == "gunner" else Battle.ENEMY_ATTACKS[kind])
		for action in attacks: expected[action] = 6
		for clip in expected:
			var key: String = "mori:" + kind + ":" + clip
			var frames: Array = view._art.enemy_clips.get(key,[])
			check(frames.size() == expected[clip],key + " registers every approved distinct source frame")
			var sources := []
			for frame in frames:
				var identity := str(frame.texture.get_instance_id()) + str(frame.region)
				check(frame.source == "v14" and frame.body_height >= 220 and not sources.has(identity),key + " keeps unique HD source regions at anatomical scale")
				sources.append(identity)
			var fighter := {"id":777,"team":1,"kind":kind,"faction":"mori","action":clip,"action_tick":0,"moving":clip == "walk"}
			if clip == "struggle": fighter.action = "grabbed"
			elif clip == "death": fighter.action = "defeated"
			if Battle.ENEMY_TIMING.has(clip): fighter.action_tick = Battle.enemy_timing(fighter)[0]
			var sample: Dictionary = view._fighter_animation(fighter)
			check(sample.source == "v14" and sample.sheet == "enemy_clip:" + key,key + " cannot silently return to a low-resolution fallback")
	var run: Array = view._art.animations.nobunaga.get("v14_run",[])
	check(run.size() == 12,"Nobunaga registers twelve new running drawings")
	var sample: Dictionary = view._fighter_animation({"kind":"nobunaga","team":0,"action":"idle","moving":true,"sprinting":true})
	check(sample.sheet == "v14_run" and sample.source == "v14","Sprinting uses the new Nobunaga run rather than an old sheet")
	var flags: Array = view._art.prop_frames.get("mori-camp-flag",[])
	check(flags.size() == 6 and flags.all(func(frame: Dictionary) -> bool: return frame.source == "v14"),"Mori camp flag registers six actual v14 drawings")
	var bow := {"kind":"archer","team":1,"faction":"mori","action":"bow_shot","action_tick":30}
	var bow_sample: Dictionary = view._fighter_animation(bow)
	check(bow_sample.source == "v14" and bow_sample.frame == 4,"Actual archer source releases its string on frame four at tick thirty")
	check(view._art.enemy_frame("archer",int(bow_sample.cell),"mori",str(bow_sample.sheet)).has("hand_offset"),"Actual archer release has a measured hand anchor")
	for action in ["boss_chain","boss_grab_throw"]:
		var boss := {"kind":"boss","team":1,"faction":"mori","action":action,"action_tick":26}
		check(view._fighter_animation(boss).frame == 2,action + " actual artwork casts on its third drawing")
		boss.action_tick = 54
		check(view._fighter_animation(boss).frame == 3,action + " actual artwork pulls or throws on its fourth drawing")

func _test_enemy_routes(view) -> void:
	var sim := Battle.new()
	for kind in ["soldier","flag","commander","archer","gunner","boss"]:
		var fighter: Dictionary = sim._make_fighter(1,kind,800,480,100)
		fighter.faction = "mori"
		for action in ["idle","hurt","grabbed","down","dead","defeated","recovering"]:
			fighter.action = action
			fighter.action_tick = 24
			var sample: Dictionary = view._fighter_animation(fighter)
			check(sample.source == "v14" and sample.sheet.begins_with("enemy_clip:mori:" + kind + ":"),kind + " " + action + " selects its discrete clip")
			check(not view._art.enemy_frame(kind,sample.cell,"mori",sample.sheet).is_empty(),"Sampling and frame loading agree on the exact enemy clip key")
		fighter.action = "grabbed"
		var frames := []
		for tick in [0,10,20,30]:
			fighter.action_tick = tick
			frames.append(view._fighter_animation(fighter).frame)
		check(frames == [0,1,2,0],kind + " struggles with three actual frame indices instead of rotating one pose")
		var attacks: Array = ["bow_shot"] if kind == "archer" else (["gun_shot"] if kind == "gunner" else Battle.ENEMY_ATTACKS[kind])
		for action in attacks:
			fighter.action = action
			var hit := int(Battle.enemy_timing(fighter)[0])
			fighter.action_tick = hit - 1
			check(not view._fighter_animation(fighter).released,action + " does not strike early")
			fighter.action_tick = hit
			var sample: Dictionary = view._fighter_animation(fighter)
			check(sample.released and sample.frame == 3 and sample.source == "v14",action + " reaches its impact drawing on the simulation hit tick")
		fighter.faction = "takeda"
		check(view._fighter_animation(fighter).source != "v14","The new Mori sheets never replace another faction")
	var boss := {"kind":"boss","team":1,"faction":"mori","action":"boss_grab_throw","action_tick":54}
	check(view._fighter_animation(boss).frame == 4,"Mori grab-throw reaches the follow-through pose when the victim is actually thrown")

func _test_authored_release_timing(view) -> void:
	var frames: Array = view._art.enemy_clips["mori:archer:bow_shot"]
	var ticks := [0,8,16,23,30,46]
	for index in range(6):
		frames[index].frame_tick = ticks[index]
		frames[index].hand_offset = Vector2(index * 10,-180)
	for face in [-1,1]:
		var archer := {"id":777,"kind":"archer","team":1,"faction":"mori","action":"bow_shot","action_tick":29,"face":face}
		check(view._fighter_animation(archer).frame == 3 and not view._fighter_animation(archer).released,"Bow stays drawn before the actual release tick")
		archer.action_tick = 30
		check(view._fighter_animation(archer).frame == 4 and view._fighter_animation(archer).released,"Bow release and projectile emission use drawing four together")
		archer.action_tick = 46
		check(view._fighter_animation(archer).frame == 5,"Bow lowers only after its release drawing")
		var effect := {"owner":777,"team":1,"action":"bow_shot","action_tick":30,"face":face}
		archer.action = "hurt"
		archer.action_tick = 3
		archer.face = -face
		archer.freeze = 20
		view.state = {"fighters":[archer]}
		var hand: Vector2 = frames[4].hand_offset * 146.0 / 300.0
		check(view._projectile_offset(effect).is_equal_approx(Vector2((hand.x - 40) * face,hand.y + 70)),"A delayed enemy arrow still starts at the snapshotted release hand after hurt/freeze/turn")
	for action in ["boss_chain","boss_grab_throw"]:
		var boss_frames: Array = view._art.enemy_clips["mori:boss:" + action]
		for index in range(6): boss_frames[index].frame_tick = [0,14,26,54,72,91][index]
		var boss := {"kind":"boss","team":1,"faction":"mori","action":action,"action_tick":26}
		check(view._fighter_animation(boss).frame == 2 and view._fighter_animation(boss).released,"Authored chain cast aligns drawing two with tick twenty-six")
		boss.action_tick = 54
		check(view._fighter_animation(boss).frame == 3,"Authored chain follow-up aligns drawing three with tick fifty-four")

func _test_arc_arrow_snapshot(view) -> void:
	for face in [-1,1]:
		var sim := Battle.new()
		var archer: Dictionary = sim._make_fighter(1,"archer",700,450,100)
		archer.faction = "mori"
		archer.action = "bow_shot"
		archer.action_tick = 30
		archer.face = face
		sim.state.fighters = [sim.state.fighters[0],archer]
		sim.state.effects.clear()
		sim._arc_arrow(archer,10)
		var shots: Array = sim.state.effects.filter(func(effect: Dictionary) -> bool: return effect.type == "projectile")
		check(shots.size() == 1,"Actual enemy bow code creates one arcing arrow")
		if shots.is_empty(): continue
		var effect: Dictionary = shots[0]
		check(effect.get("action","") == "bow_shot" and effect.get("action_tick",-1) == 30 and effect.get("combo",-1) == archer.combo and effect.get("heavy_combo",-1) == archer.heavy_combo,"Actual arcing arrow snapshots the launch action and pose tick")
		archer.action = "hurt"
		archer.action_tick = 3
		archer.face = -face
		archer.freeze = 20
		view.state = sim.get_state()
		var frozen_pose := {"hero":"archer","clip":"hurt","cell":2,"source":"v14"}
		view._frozen_samples[archer.id] = frozen_pose.duplicate()
		view._projectile_origins.clear()
		view.projectile_queries = 0
		var frame: Dictionary = view._art.enemy_clips["mori:archer:bow_shot"][4]
		var hand: Vector2 = frame.hand_offset * 146.0 / float(frame.body_height)
		var offset: Vector2 = view._projectile_release_offset(effect)
		check(offset.is_equal_approx(Vector2((hand.x - 40) * face,hand.y + effect.start_z)),"A real arcing arrow first displayed after owner hurt/freeze/turn retains its release hand")
		check(view._frozen_samples[archer.id] == frozen_pose,"Reconstructing an arrow release never replaces the owner's frozen body pose")
		check(view._projectile_release_offset(effect) == offset and view.projectile_queries == 1,"Repeated draw callers reuse the arrow origin without eagerly resampling its owner")
		view._frozen_samples.erase(archer.id)
		view._projectile_offset(effect)
		check(not view._frozen_samples.has(archer.id),"Release reconstruction does not create a live frozen-body cache entry")

func _test_enemy_movement(view) -> void:
	for face in [-1,1]:
		var fighter := {"id":444,"kind":"archer","team":1,"faction":"mori","action":"retreat","action_tick":0,"face":face,"move_dx":-face,"moving":true,"x":800.0,"y":480.0}
		view._motion_tick = -1
		view._walk_ticks.clear()
		var cells := []
		for tick in range(61):
			fighter.x -= face * (1.0 if tick < 30 else 3.0)
			view.state = {"tick":tick,"fighters":[fighter]}
			view._update_motion()
			if tick % 5 == 0: cells.append(view._fighter_animation(fighter).frame)
		check(cells == [0,5,4,3,2,1,0,5,4,3,2,1,0],"Changing movement speed does not change the backward twelve-fps six-drawing gait")
		fighter.move_dx = face
		view._walk_ticks[444] = 5
		check(view._fighter_animation(fighter).frame == 1,"Forward wall escape plays the same gait forwards")
		fighter.moving = false
		view.state.tick = 62
		view._update_motion()
		check(not view._walk_ticks.has(444) and view._fighter_animation(fighter).clip == "idle","Stopping resets the movement clock and selects the actual idle clip")

func _test_death_scale(view) -> void:
	for face in [-1,1]:
		var fighter := {"id":555,"kind":"soldier","team":1,"faction":"mori","action":"down","action_tick":0,"face":face,"hp":0,"z":0.0}
		for tick in [0,20,59]:
			fighter.action_tick = tick
			check(view._fighter_animation(fighter).frame == 5,"Grounded knockdown remains on the final horizontal death drawing")
		view._draw_enemy_art(fighter,Vector2(600,480))
		check(view.drawn.rotation == 0 and view.drawn.origin == Vector2(600,480) and view.drawn.base_height == 300.0,"Prone v14 source keeps anatomical scale and ground anchor without legacy rotation or bbox enlargement")
		fighter.action = "recovering"
		var recovery := []
		for tick in [0,6,12,18,24,30]:
			fighter.action_tick = tick
			recovery.append(view._fighter_animation(fighter).frame)
		check(recovery == [5,4,3,2,1,0],"Recovery reverses the actual fall sequence")
		fighter.action = "defeated"
		fighter.action_tick = 0
		fighter.airborne_lock = true
		check(view._fighter_animation(fighter).frame == 2,"Airborne defeat does not restart the standing fall")
		fighter.airborne_lock = false
		fighter.down_from_air = true
		check(view._fighter_animation(fighter).frame == 5,"Landing a defeated enemy goes directly to its final prone drawing")

func _test_run_and_slam(view) -> void:
	view._art.animations.nobunaga.v14_run = _frames(12)
	for index in range(12):
		view._walk_ticks[666] = index * 60.0 / 16.0
		var sample: Dictionary = view._fighter_animation({"id":666,"kind":"nobunaga","team":0,"action":"idle","moving":true,"sprinting":true})
		check(sample.sheet == "v14_run" and sample.frame == index and sample.source == "v14","New Nobunaga run takes priority at sixteen fps")
	for combo in range(1,4):
		check(view._fighter_animation({"kind":"nobunaga","team":0,"action":"light","combo":combo,"action_tick":6}).sheet == "v13_light%d" % combo,"Nobunaga's accepted v13 blade sequences stay selected")
	for tick in [27,28]:
		var fighter := {"kind":"oichi","team":0,"action":"charged_slam","action_tick":tick}
		var sample: Dictionary = view._fighter_animation(fighter)
		check(sample.frame == (5 if tick == 27 else 6) and sample.released == (tick == 28),"Oichi's bow release drawing agrees with the shared arrow/wave tick28")
		check(View.strike_accent(fighter,sample).is_empty() == (tick == 27),"Bow release energy starts with the actual arrows")

func _test_power() -> void:
	for stage in [1,2]:
		var style := View.strike_accent({"kind":"nobunaga","action":"heavy","heavy_combo":stage},{"tick":14})
		check(is_equal_approx(style.path[0],(0.9 if stage == 1 else 1.05) * 1.3) and is_equal_approx(style.path[1],(9.0 if stage == 1 else 12.0) * 1.5),"Heavy sword energy expands its arc length and width without modifying hit timing")
	check(View.charge_visual(35,155).flame > 155 * .3 and View.charge_visual(35,155).radius > 155 * .75,"Full charge has a larger visible flame and ground footprint")

func _test_camp_flag(view) -> void:
	view._art.prop_frames["mori-camp-flag"] = _frames(6)
	view.state = {"faction":"mori"}
	for index in range(7):
		var sample: Dictionary = view._camp_flag_sample(0,index * .2)
		check(sample.frame.test_frame == index % 6 and sample.rotation == 0,"Mori cloth advances at five fps while its mast remains fixed")
	view.state.faction = "takeda"
	check(view._camp_flag_sample(1,.2).frame == view._art.scenery_frames[1],"Other faction camp flags retain their existing artwork")
