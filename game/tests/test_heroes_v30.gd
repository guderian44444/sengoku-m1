extends SceneTree

const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const Equipment = preload("res://core/equipment.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Profile = preload("res://core/save_profile.gd")
const HUD = preload("res://render/combat_hud.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0
var output := ""

class CaptureView extends View:
	var cards: Array = []
	var samples: Dictionary = {}
	var card_effects: Dictionary = {}
	var title := ""
	var row_height := 340
	var baseline := 300
	var margin := 160
	var columns := 6
	func _fighter_animation(fighter: Dictionary) -> Dictionary:
		return samples[int(fighter.id)] if samples.has(int(fighter.id)) else super._fighter_animation(fighter)
	func live_sample(fighter: Dictionary) -> Dictionary:
		return super._fighter_animation(fighter)
	func _draw() -> void:
		if _fx.configured: _fx.shared_player.begin_draw(self)
		draw_rect(get_viewport_rect(),Color("303c39"))
		Typography.draw_label(self,Vector2(24,34),title,24,Typography.PAPER)
		for index in range(cards.size()):
			var at := Vector2(margin+(index%columns)*320,baseline+(index/columns)*row_height)
			_shadow_pass = true
			_draw_art_fighter(cards[index],at)
			_shadow_pass = false
			_draw_art_fighter(cards[index],at)
			for effect in card_effects.get(int(cards[index].id),[]):
				var positioned: Dictionary = effect.duplicate(true)
				positioned.x += at.x-float(cards[index].x)
				positioned.y += at.y-float(cards[index].y)
				if positioned.type == "shockwave": _draw_ground_effect(positioned)
				else: _draw_effect(positioned)
			Typography.draw_label(self,at+Vector2(-145,46),str(cards[index].qa_label),17,Typography.PAPER,290,HORIZONTAL_ALIGNMENT_CENTER)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: run.call_deferred()

func arena(hero: String = "hideyoshi") -> Battle:
	var battle := Battle.new()
	battle.reset("normal",1,[hero])
	battle.state.fighters = battle.state.fighters.filter(func(f): return f.team == 0)
	battle.state.props.clear()
	battle.state.drops.clear()
	var player: Dictionary = battle.state.fighters[0]
	player.x = 600
	player.y = 500
	return battle

func target(battle: Battle, offset: float = 70, heavy: bool = true) -> Dictionary:
	var player: Dictionary = battle.state.fighters[0]
	var enemy: Dictionary = battle._make_fighter(1,"soldier",player.x+offset,player.y,1000)
	if heavy: enemy.weight = "heavy"
	enemy.cooldown = 999
	battle.state.fighters.append(enemy)
	return enemy

func run() -> void:
	output = ProjectSettings.globalize_path("res://../artifacts/hideyoshi-forward-v30/poses")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var view := CaptureView.new()
	root.add_child(view)
	var sheets: Dictionary = view._art.animations.hideyoshi
	var registration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/v27/hideyoshi/registration.json"))
	check(registration.clips.size() == 39,"All thirty-nine approved Hideyoshi clips are active")
	check(HUD.portrait_spec("oichi").file.begins_with("res://assets/v27/oichi/") and HUD.portrait_spec("hideyoshi").file.begins_with("res://assets/v27/hideyoshi/"),"Both HUD portraits use the approved new sources")
	var review_weapons := ["sword_uchigatana","sword_kanesada_mino","sword_okanehira"]
	var weapon_shapes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/v22/weapons/registration.json")).items
	for clip in registration.clips:
		var frames: Array = sheets["v22_"+clip]
		check(frames.size() == 6,"Six authored poses load: "+clip)
		var clip_scale := -1.0
		for index in range(6):
			var frame: Dictionary = frames[index]
			check(frame.source_version == "v27" and (frame.has("hand_foreground") or frame.has("hand_occluders")),clip+" loads a usable hand foreground or body occlusion")
			for id in review_weapons:
				var actor := {"kind":"hideyoshi","weapon_id":id}
				var pose: Dictionary = view._weapons.geometry(actor,frame,155)
				if not frame.get("weapon_visible",true) and frame.get("weapon_mode","") != "sheathed":
					check(pose.is_empty(),clip+" carries only the baked fan and sheathed sword")
					continue
				check(not pose.is_empty() and pose.family == "sword" and pose.id == id,clip+" equips "+id)
				var region := View.WeaponRenderer.weapon_region(pose,frame,view._weapons.textures[id].get_size())
				check(Rect2(Vector2.ZERO,view._weapons.textures[id].get_size()).encloses(region),clip+" sheath clipping stays within the equipped sword")
				for face in [-1.0,1.0]:
					var transform := View.WeaponRenderer.pose_transform(pose,Vector2.ZERO,face,0)
					check((transform*Vector2.ZERO).is_equal_approx(pose.hand*Vector2(face,1)),clip+" mirrors the hand and weapon together")
					var tip: Array = weapon_shapes[id].tip_top
					check((transform*(Vector2(tip[0],tip[1])-Vector2(pose.grip))).is_equal_approx(pose.top*Vector2(face,1)),clip+" rendered blade tip matches the sweep and shadow geometry")
					if clip in ["idle","walk","run"]:
						var cutting_edge: Vector2 = transform*Vector2(20,0)-transform*Vector2.ZERO
						var direction: Vector2 = pose.top-pose.hand
						check(cutting_edge.x*face > 0 and direction.y < 0 and (is_zero_approx(pose.angle) if clip == "idle" else pose.angle > 0),id+" carries the outward-facing cutting edge, tip upward or forward")
						if clip in ["walk","run"]:
							check(frame.has("second_hand") and frame.get("hand_occluders",[]).size() == 2,"Both locomotion hands have a registered grip and foreground occlusion")
							var second: Vector2 = frame.second_hand*float(pose.body_scale)
							var grip_distance := Geometry2D.get_closest_point_to_segment(second,pose.hand,pose.bottom).distance_to(second)
							check(grip_distance < .5 and pose.bottom.distance_to(pose.hand) > second.distance_to(pose.hand),"Both locomotion hands stay within half a world pixel of the curved hilt, above its end")
			var spec: Dictionary = registration.clips[clip].frames[index]
			check(spec.has("scale_ruler"),"All 234 frames use the standing calibration, including reactions and special moves")
			check(absf(float(spec.scale_ruler.head_width_px)*155/float(frame.body_height)-55.0*155/416) < .01,clip+" uses the standing reference instead of cropped pose height")
			var normalized := float(frame.body_height)/float(spec.scale_ruler.source_resolution)
			if clip_scale < 0: clip_scale = normalized
			check(absf(normalized-clip_scale) < .001,clip+" never changes zoom inside its six-frame loop")
	check(sheets.v22_idle[0].body_height == 416 and registration.clips.idle.frames[0].file == "body/idle/01.png","The user's standing reference keeps its original source and display scale")
	var nobunaga_frame: Dictionary = view._art.animations.nobunaga.v22_idle[0]
	var nobunaga_pose: Dictionary = view._weapons.geometry({"kind":"nobunaga","weapon_id":"practice_nobunaga"},nobunaga_frame,155)
	check(View.WeaponRenderer.pose_transform(nobunaga_pose,Vector2.ZERO,1,0).determinant() > 0,"Hideyoshi's cutting edge correction preserves other heroes' weapon orientation")
	var live_view := View.new()
	for action in ["idle","jump","light","heavy","rising","low_sweep","dash_strike","dash_heavy","air_light","air_heavy","mixed_rising","mixed_finisher","grabbed","pulled","down","recovering","stunned","launched","hurt","holding","throw","victory","guard","charge","upper_heavy","ground_slam","charged","charged_upper","charged_slam","special"]:
		for face in [-1,1]:
			var actor: Dictionary = arena().state.fighters[0]
			actor.action = action
			actor.face = face
			var before := var_to_bytes(actor)
			for tick in range(0,211,3):
				actor.action_tick = tick
				var sampled: Dictionary = live_view._fighter_animation(actor)
				check(sampled.source_version == "v27" and sampled.frame >= 0 and sampled.frame < 6 and not live_view._art.animation_frame("hideyoshi",sampled).is_empty(),action+" keeps the complete approved source throughout both facing timelines")
			actor.action_tick = 0
			check(var_to_bytes(actor) == before,"All-action sampling preserves combat data")
	for action in ["upper_heavy","ground_slam","mixed_finisher","mixed_rising","grabbed","pulled"]:
		var battle := arena()
		var player: Dictionary = battle.state.fighters[0]
		player.action = action
		player.action_tick = Battle.fighter_tick(player,14)
		check(live_view._fighter_animation(player).sheet == "v22_"+action,action+" uses its independent approved route")
	for speed in [.8,1.0,1.2]:
		for attack in [["light",1,6],["heavy",1,14],["heavy",2,14],["rising",0,6],["low_sweep",0,9],["dash_strike",0,10],["dash_heavy",0,12],["air_light",0,6],["air_heavy",0,12],["upper_heavy",0,12],["ground_slam",0,14],["charged",0,12],["charged",0,34],["charged",0,56],["charged_upper",0,22],["charged_slam",0,28],["mixed_finisher",0,14],["mixed_rising",0,14],["throw",0,12]]:
			var player: Dictionary = arena().state.fighters[0]
			player.attack_speed = speed
			player.action = attack[0]
			player.combo = attack[1] if attack[0] == "light" else 0
			player.heavy_combo = attack[1] if attack[0] == "heavy" else 0
			player.action_tick = Battle.fighter_tick(player,attack[2])
			check(live_view._fighter_animation(player).frame == 3,str(attack)+" hits at frame four with attack speed "+str(speed))
	var battle := arena()
	var player: Dictionary = battle.state.fighters[0]
	player.rage = 100
	battle.step([{"dx":0,"dy":0,"buttons":Battle.SPECIAL}])
	check(player.action == "special" and player.rage == 0,"One special input begins all three fan stages")
	for pair in [[35,"special_1"],[105,"special_2"],[175,"special_3"]]:
		player.action_tick = pair[0]
		var sample: Dictionary = live_view._fighter_animation(player)
		check(sample.sheet == "v22_"+pair[1] and sample.frame == 3,"Fan stage contact matches native frame four: "+str(pair))
	check(Battle.SPECIAL_HIT_TICKS.hideyoshi == [35,105,175],"The new special has three damage contacts")
	battle = arena()
	player = battle.state.fighters[0]
	var special_target := target(battle)
	battle._begin(player,"special")
	var contacts := []
	for tick in range(210):
		var hp: int = special_target.hp
		battle.state.tick += 1
		battle._tick_fighter(player)
		battle._tick_fighter(special_target)
		if special_target.hp < hp: contacts.append(tick+1)
	check(contacts == [35,105,175] and player.action == "idle","Actual special deals three hits and finishes once after all eighteen frames")
	battle = arena()
	player = battle.state.fighters[0]
	var victim := target(battle,55,false)
	battle._try_grab(player)
	check(player.grab_target == victim.id,"Hideyoshi grabs a legal separate enemy")
	battle._release_grab(player,true)
	check(victim.hp == 1000 and player.action == "throw" and victim.held_by == player.id,"Releasing grab starts the throw without premature damage")
	player.action_tick = Battle.fighter_tick(player,12)-1
	battle._tick_fighter(player)
	check(victim.hp == 953 and victim.held_by == 0 and player.grab_target == 0 and victim.thrown_by == player.id,"Throw damage and release occur at authored contact")
	for face in [-1,1]:
		battle = arena()
		player = battle.state.fighters[0]
		player.face = face
		victim = target(battle,75*face,false)
		var rear := target(battle,-75*face,false)
		player.action = "dash_heavy"
		player.action_tick = Battle.fighter_tick(player,12)-1
		battle._tick_fighter(player)
		check(victim.hp < 1000 and victim.knockback*face > 0 and victim.airborne_lock and rear.hp == 1000,"Dash heavy knocks the front enemy down and leaves the rear enemy untouched")
		check(live_view._fighter_animation(player).sheet == "v22_heavy1","Dash heavy visibly uses the forward downward cut")
		for combo in [1,2]:
			battle = arena()
			player = battle.state.fighters[0]
			player.face = face
			victim = target(battle,170*face,false)
			var outside := target(battle,260*face,false)
			player.heavy_combo = combo-1
			battle._release_heavy(player)
			player.action_tick = Battle.fighter_tick(player,14)-1
			battle._tick_fighter(player)
			check(victim.hp < 1000 and outside.hp == 1000 and victim.airborne_lock == (combo == 2),"Heavy forward range and launch: combo=%d reach=%.1f hp=%d outside=%d weight=%s airborne=%s" % [combo,player.attack_reach,victim.hp,outside.hp,victim.weight,victim.airborne_lock])
			check(battle.state.effects.filter(func(e): return e.type == "blade_wave").size() == 1,"Each heavy has one limited sword-air effect")
		for speed in [.8,1.0,1.2,1.6]:
			battle = arena()
			player = battle.state.fighters[0]
			player.face = face
			player.attack_speed = speed
			victim = target(battle,150*face,false)
			var armored := target(battle,180*face,true)
			var rear_target := target(battle,-75*face,false)
			player.action = "charged"
			var damage_ticks := []
			var steps := []
			var start_x: float = player.x
			for tick in range(1,Battle.fighter_tick(player,66)+1):
				var hp: int = victim.hp
				battle.state.tick = tick
				battle._tick_fighter(player)
				if victim.hp < hp:
					damage_ticks.append(tick)
					steps.append((player.x-start_x)*face)
					check((victim.action == "down") == (damage_ticks.size() == 3),"Only charged cut three knocks down")
					check(Wire.valid_snapshot(battle.get_state()),"Each charged hit and sword-air effect remain valid for co-op")
				battle._tick_fighter(victim)
				battle._tick_fighter(armored)
			check(damage_ticks == [Battle.fighter_tick(player,12),Battle.fighter_tick(player,34),Battle.fighter_tick(player,56)],"Charged attack lands three distinct cuts across attack speeds")
			check(steps.size() == 3 and is_equal_approx(steps[0],42) and is_equal_approx(steps[1],84) and is_equal_approx(steps[2],126),"Each charged cut advances one 42-pixel step")
			check(armored.action == "down" and rear_target.hp == 1000 and player.action == "idle","Third cut knocks down armored targets, never attacks behind, and recovers")
	for action in ["ground_slam","air_heavy"]:
		battle = arena()
		player = battle.state.fighters[0]
		player.action = action
		player.action_tick = Battle.fighter_tick(player,28 if action == "charged_slam" else (19 if action == "air_heavy" else 14))-1
		battle._tick_fighter(player)
		check(not battle.state.effects.any(func(effect): return effect.get("type","") == "shockwave"),action+" does not inherit the old spear ground wave")
	battle = arena()
	player = battle.state.fighters[0]
	var front_target := target(battle,140,false)
	var back_target := target(battle,-140,false)
	var far_target := target(battle,320,false)
	player.action = "charged_slam"
	player.action_tick = Battle.fighter_tick(player,28)-1
	battle._tick_fighter(player)
	var waves: Array = battle.state.effects.filter(func(e): return e.type == "shockwave")
	check(waves.size() == 1 and waves[0].element == "earth" and battle._melee_weapon(player) == "blunt","Charged down-heavy emits one fan ground impact with blunt sound")
	check(waves.size() == 1 and is_equal_approx(waves[0].x,player.x+player.face*55),"The fan quake begins at its forward ground contact")
	check(Wire.valid_snapshot(battle.get_state()),"Fan quake remains a valid co-op snapshot")
	for tick in range(24): battle._tick_effects()
	check(front_target.hp < 1000 and back_target.hp < 1000 and far_target.hp == 1000,"Fan quake covers a modest surrounding ground area")
	var old := {"hero":"hideyoshi","slot":0,"score":1234,"max_hp_bonus":7,"weapon_id":"spear_nihongo","owned_weapons":["spear_nihongo","spear_tonbokiri"]}
	Equipment.ensure(old)
	check(old.weapon_id == "practice_hideyoshi" and old.inventory.size() == 2 and old.weapon_uid == 0 and "spear_nihongo" in old.owned_weapons and "spear_tonbokiri" in old.owned_weapons,"Legacy spears retain both instance IDs; the virtual practice sword takes no storage slot")
	var old_equipped := int(old.weapon_uid)
	check(not Equipment.equip(old,int(old.inventory[0].uid)) and int(old.weapon_uid) == old_equipped,"Preserved old spears cannot be equipped by the new sword hero")
	var full := old.duplicate(true)
	while full.inventory.size() < Equipment.CAPACITY: Equipment.add(full,"spear_nihongo")
	Equipment.remove(full,old_equipped)
	Equipment.add(full,"spear_nihongo")
	full.weapon_uid = int(full.inventory[0].uid)
	Equipment.sync(full)
	Equipment.ensure(full)
	check(full.inventory.size() == Equipment.CAPACITY and full.weapon_uid == 0 and Equipment.valid(full),"Full legacy inventory stays intact even when there is no room for a sword")
	var save := Profile.new("user://hideyoshi-v30-%d.json" % Time.get_ticks_usec(),"秀吉遷移")
	old.achievements = []
	save.data.characters["0:hideyoshi"] = old
	check(save.save() == OK,"Migrated sword/spear inventory can be saved")
	var reloaded := Profile.new(save.path,"秀吉遷移")
	check(reloaded.character(0,"hideyoshi").inventory == old.inventory and reloaded.character(0,"hideyoshi").score == 1234,"Old weapons and score survive a real disk reload")
	Equipment.remove(old,old_equipped)
	old.weapon_uid = int(old.inventory[0].uid)
	Equipment.sync(old)
	old.erase("bag_uids") # The genuine legacy record predates carried-slot bookkeeping.
	save.data.characters["0:hideyoshi"] = old
	check(save.save() == OK,"A genuine legacy spear-equipped record remains readable")
	reloaded = Profile.new(save.path,"秀吉遷移")
	var migrated: Dictionary = reloaded.character(0,"hideyoshi")
	check(not reloaded.blocked and migrated.weapon_id == "practice_hideyoshi" and migrated.inventory.size() == 2 and Equipment.instance(migrated,int(old.inventory[0].uid)).item_id == "spear_nihongo","Loading an old disk record selects the virtual sword while retaining original spear instance IDs")
	live_view.free()
	if "--capture" in OS.get_cmdline_user_args() or "--capture-all" in OS.get_cmdline_user_args():
		root.size = Vector2i(1920,1080)
		root.content_scale_size = Vector2i(1920,1080)
		if "--capture-all" in OS.get_cmdline_user_args():
			root.size = Vector2i(2200,1080)
			root.content_scale_size = Vector2i(2200,1080)
			view.margin = 300
		for clip in ["idle","walk","run","light1","light2","light3","heavy1","heavy2","dash_heavy","charged_1","charged_2","charged_3","charge_slam","charged_slam"]:
			for face in [-1,1]:
				view.cards.clear()
				view.samples.clear()
				view.card_effects.clear()
				view.title = "秀吉新造型  "+clip+"  /  "+("左向" if face < 0 else "右向")+"  /  三刀 × 六格"
				for id in review_weapons:
					for frame in range(6):
						var capture_battle := arena()
						var actor: Dictionary = capture_battle.state.fighters[0]
						actor.id = 100+view.cards.size()
						actor.weapon_id = id
						actor.face = face
						if clip in ["idle","walk","run"]:
							actor.moving = clip != "idle"
							actor.sprinting = clip == "run"
							view._walk_ticks[actor.id] = (45 if clip == "run" else 60)*frame/6.0+1
						elif clip == "charge_slam":
							actor.action = "charge"
							actor.charge_direction = 1
							actor.action_tick = frame*6
							actor.charge = frame*7
						else:
							var hit := 14
							var finish := 36
							var phase := 0
							actor.action = clip
							if clip.begins_with("light"): actor.action = "light"; actor.combo = int(clip[-1]); hit = 6; finish = 19
							elif clip.begins_with("heavy"): actor.action = "heavy"; actor.heavy_combo = int(clip[-1])
							elif clip.begins_with("charged_") and clip != "charged_slam": actor.action = "charged"; phase = (int(clip[-1])-1)*22; hit = 12; finish = 22
							elif clip == "dash_heavy": hit = 12; finish = 34
							elif clip == "charged_slam": hit = 28; finish = 72
							var ticks := [0,ceili(hit*.5),floori(hit*.84),hit,hit+ceili((finish-hit)*.5),hit+ceili((finish-hit)*.84)]
							actor.action_tick = Battle.fighter_tick(actor,phase+ticks[frame]) if ticks[frame]+phase > 0 else 0
						actor.qa_label = Weapons.item(id).name+" / "+str(frame+1)
						if actor.action in ["heavy","charged","dash_heavy","charged_slam"]:
							var draw_tick: int = actor.action_tick
							actor.action_tick = 0
							actor.heavy_combo_tick = 70
							for tick in range(draw_tick):
								capture_battle.state.tick = tick+1
								capture_battle.state.events.clear()
								capture_battle._tick_fighter(actor)
								capture_battle._tick_effects()
							view.card_effects[actor.id] = capture_battle.state.effects.filter(func(e): return e.type in ["blade_wave","shockwave"])
						view.cards.append(actor)
						view.samples[actor.id] = view.live_sample(actor)
				var before := var_to_bytes(view.cards)
				view.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				check(var_to_bytes(view.cards) == before,"Native composition preserves the actor data")
				check(root.get_texture().get_image().save_png(output.path_join(clip+("-left.png" if face < 0 else "-right.png"))) == OK,"Native pose sheet saved")
		if "--capture-all" in OS.get_cmdline_user_args():
			for clip in registration.clips:
				for face in [-1,1]:
					view.cards.clear()
					view.samples.clear()
					view.card_effects.clear()
					view.title = "秀吉完整素材  "+clip+"  /  "+("左向" if face < 0 else "右向")+"  /  三刀 × 六格"
					for id in review_weapons:
						for frame in range(6):
							var actor: Dictionary = arena().state.fighters[0]
							actor.id = 100+view.cards.size()
							actor.weapon_id = id
							actor.face = face
							actor.qa_label = Weapons.item(id).name+" / "+str(frame+1)
							view.cards.append(actor)
							view.samples[actor.id] = {"source":"v22","source_version":"v27","hero":"hideyoshi","clip":clip,"sheet":"v22_"+clip,"frame":frame,"cell":frame,"count":6,"tick":0,"duration":0,"released":false}
					var before := var_to_bytes(view.cards)
					view.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					check(var_to_bytes(view.cards) == before,"Complete native atlas composition preserves actor data")
					check(root.get_texture().get_image().save_png(output.path_join("source-"+clip+("-left.png" if face < 0 else "-right.png"))) == OK,"Complete approved pose sheet saved")
			root.size = Vector2i(2520,1200)
			root.content_scale_size = root.size
			view.columns = 7
			view.row_height = 275
			view.baseline = 240
			var clips: Array = registration.clips.keys()
			for page in range(ceili(clips.size()/4.0)):
				for face in [-1,1]:
					view.cards.clear()
					view.samples.clear()
					view.title = "秀吉站立尺規與全動作  %d  /  %s" % [page+1,"左向" if face < 0 else "右向"]
					for clip in clips.slice(page*4,mini(clips.size(),page*4+4)):
						var reference: Dictionary = arena().state.fighters[0]
						reference.id = 100+view.cards.size()
						reference.weapon_id = "sword_uchigatana"
						reference.face = face
						reference.qa_label = "站立基準"
						view.cards.append(reference)
						view.samples[reference.id] = {"source":"v22","source_version":"v27","hero":"hideyoshi","clip":"idle","sheet":"v22_idle","frame":0,"cell":0,"count":6,"tick":0,"duration":0,"released":false}
						for frame in range(6):
							var actor: Dictionary = arena().state.fighters[0]
							actor.id = 100+view.cards.size()
							actor.weapon_id = "sword_uchigatana"
							actor.face = face
							actor.qa_label = clip+" / "+str(frame+1)
							view.cards.append(actor)
							view.samples[actor.id] = {"source":"v22","source_version":"v27","hero":"hideyoshi","clip":clip,"sheet":"v22_"+clip,"frame":frame,"cell":frame,"count":6,"tick":0,"duration":0,"released":false}
					view.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					check(root.get_texture().get_image().save_png(output.path_join("overview-%02d-%s.png" % [page+1,"left" if face < 0 else "right"])) == OK,"Native all-action overview saved")
	view.free()
	print("HEROES V30 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
