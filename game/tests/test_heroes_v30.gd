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
	var title := ""
	func _fighter_animation(fighter: Dictionary) -> Dictionary:
		return samples.get(int(fighter.id),{})
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,Vector2(1920,1080)),Color("303c39"))
		Typography.draw_label(self,Vector2(24,34),title,24,Typography.PAPER)
		for index in range(cards.size()):
			var at := Vector2(160+(index%6)*320,300+(index/6)*340)
			_shadow_pass = true
			_draw_art_fighter(cards[index],at)
			_shadow_pass = false
			_draw_art_fighter(cards[index],at)
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
	output = ProjectSettings.globalize_path("res://../artifacts/integration-v30/heroes")
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
		for index in range(6):
			var frame: Dictionary = frames[index]
			check(frame.source_version == "v27" and frame.has("hand_foreground"),clip+" loads the authored foreground and metadata")
			for id in review_weapons:
				var actor := {"kind":"hideyoshi","weapon_id":id}
				var pose: Dictionary = view._weapons.geometry(actor,frame,155)
				check(not pose.is_empty() and pose.family == "sword" and pose.id == id,clip+" equips "+id)
				var region := View.WeaponRenderer.weapon_region(pose,frame,view._weapons.textures[id].get_size())
				check(Rect2(Vector2.ZERO,view._weapons.textures[id].get_size()).encloses(region),clip+" sheath clipping stays within the equipped sword")
				for face in [-1.0,1.0]:
					var transform := View.WeaponRenderer.pose_transform(pose,Vector2.ZERO,face,0)
					check((transform*Vector2.ZERO).is_equal_approx(pose.hand*Vector2(face,1)),clip+" mirrors the hand and weapon together")
					var tip: Array = weapon_shapes[id].tip_top
					check((transform*(Vector2(tip[0],tip[1])-Vector2(pose.grip))).is_equal_approx(pose.top*Vector2(face,1)),clip+" rendered blade tip matches the sweep and shadow geometry")
					if clip == "idle":
						var cutting_edge: Vector2 = transform*Vector2(20,0)-transform*Vector2.ZERO
						check(cutting_edge.x*face < 0, id+" idle cutting edge points away from Hideyoshi on either facing")
	var nobunaga_frame: Dictionary = view._art.animations.nobunaga.v22_idle[0]
	var nobunaga_pose: Dictionary = view._weapons.geometry({"kind":"nobunaga","weapon_id":"practice_nobunaga"},nobunaga_frame,155)
	check(View.WeaponRenderer.pose_transform(nobunaga_pose,Vector2.ZERO,1,0).determinant() > 0,"Hideyoshi's cutting edge correction preserves other heroes' weapon orientation")
	var live_view := View.new()
	for action in ["upper_heavy","ground_slam","mixed_finisher","mixed_rising","grabbed","pulled"]:
		var battle := arena()
		var player: Dictionary = battle.state.fighters[0]
		player.action = action
		player.action_tick = Battle.fighter_tick(player,14)
		check(live_view._fighter_animation(player).sheet == "v22_"+action,action+" uses its independent approved route")
	for speed in [.8,1.0,1.2]:
		for attack in [["light",1,6],["heavy",1,14],["heavy",2,14],["rising",0,6],["low_sweep",0,9],["dash_strike",0,10],["dash_heavy",0,12],["air_light",0,6],["air_heavy",0,12],["upper_heavy",0,12],["ground_slam",0,14],["charged",0,14],["charged_upper",0,22],["charged_slam",0,28],["mixed_finisher",0,14],["mixed_rising",0,14],["throw",0,12]]:
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
	battle = arena()
	player = battle.state.fighters[0]
	victim = target(battle,-75,false)
	player.action = "dash_heavy"
	player.action_tick = Battle.fighter_tick(player,12)-1
	battle._tick_fighter(player)
	check(victim.hp < 1000 and victim.knockback < 0,"Rear cut hits and pushes the enemy behind Hideyoshi")
	for action in ["ground_slam","charged_slam","air_heavy"]:
		battle = arena()
		player = battle.state.fighters[0]
		player.action = action
		player.action_tick = Battle.fighter_tick(player,28 if action == "charged_slam" else (19 if action == "air_heavy" else 14))-1
		battle._tick_fighter(player)
		check(not battle.state.effects.any(func(effect): return effect.get("type","") == "shockwave"),action+" does not inherit the old spear ground wave")
	var old := {"hero":"hideyoshi","slot":0,"score":1234,"max_hp_bonus":7,"weapon_id":"spear_nihongo","owned_weapons":["spear_nihongo","spear_tonbokiri"]}
	Equipment.ensure(old)
	check(old.weapon_id == "practice_hideyoshi" and old.inventory.size() == 3 and "spear_nihongo" in old.owned_weapons and "spear_tonbokiri" in old.owned_weapons,"Legacy spear progress stays in inventory while a practice sword is equipped")
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
	save.data.characters["0:hideyoshi"] = old
	check(save.save() == OK,"A genuine legacy spear-equipped record remains readable")
	reloaded = Profile.new(save.path,"秀吉遷移")
	var migrated: Dictionary = reloaded.character(0,"hideyoshi")
	check(not reloaded.blocked and migrated.weapon_id == "practice_hideyoshi" and migrated.inventory.size() == 3 and Equipment.instance(migrated,int(old.inventory[0].uid)).item_id == "spear_nihongo","Loading an old disk record adds a sword while retaining original spear instance IDs")
	live_view.free()
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1920,1080)
		root.content_scale_size = Vector2i(1920,1080)
		for clip in registration.clips:
			for face in [-1,1]:
				view.cards.clear()
				view.samples.clear()
				view.title = "秀吉新造型  "+clip+"  /  "+("左向" if face < 0 else "右向")+"  /  三刀 × 六格"
				for id in review_weapons:
					for frame in range(6):
						var actor: Dictionary = arena().state.fighters[0].duplicate(true)
						actor.id = 100+view.cards.size()
						actor.weapon_id = id
						actor.face = face
						actor.qa_label = Weapons.item(id).name+" / "+str(frame+1)
						view.cards.append(actor)
						view.samples[actor.id] = {"source":"v22","hero":"hideyoshi","clip":clip,"sheet":"v22_"+clip,"frame":frame,"cell":frame,"count":6,"tick":0,"duration":36,"released":false}
				var before := var_to_bytes(view.cards)
				view.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				check(var_to_bytes(view.cards) == before,"Native composition preserves the actor data")
				check(root.get_texture().get_image().save_png(output.path_join(clip+("-left.png" if face < 0 else "-right.png"))) == OK,"Native pose sheet saved")
	view.free()
	print("HEROES V30 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
