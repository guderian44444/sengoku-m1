extends SceneTree

const Battle = preload("res://core/battle.gd")
const Moves = preload("res://core/combat_moves.gd")
const Wire = preload("res://core/wire.gd")
const View = preload("res://render/battle_view.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: run.call_deferred()

func fresh(hero: String) -> Battle:
	var battle := Battle.new()
	battle.reset_training(hero,"dummy")
	battle.state.fighters[0].x = 500.0
	battle.state.fighters[0].y = 500.0
	battle.state.fighters[0].face = 1
	battle.state.fighters[1].x = 570.0
	battle.state.fighters[1].y = 500.0
	battle.state.fighters[1].hp = 5000
	battle.state.fighters[1].max_hp = 5000
	return battle

func tick(battle: Battle, buttons: int = 0, dx: int = 0, dy: int = 0) -> void:
	battle.step([{"buttons":buttons,"dx":dx,"dy":dy}])
	check(Wire.valid_snapshot(battle.state),"Actual v33 combat state remains valid for co-op: "+str(battle.state.fighters[0].action))

func finish(battle: Battle, target: String = "idle") -> void:
	for index in range(180):
		if battle.state.fighters[0].action == target: return
		tick(battle)
	check(false,"Action reaches "+target)

func body_contact_tests() -> void:
	for hero in ["nobunaga","oichi"]:
		var battle := fresh(hero)
		var player: Dictionary = battle.state.fighters[0]
		var enemy: Dictionary = battle.state.fighters[1]
		for stage in range(1,4):
			enemy.x = player.x+65
			enemy.knockback = 0.0
			enemy.invuln = 0
			var start := float(player.x)
			var health := int(enemy.hp)
			tick(battle,Battle.LIGHT,1,-1)
			check(player.action == "light" and player.combo == stage,"Directions still trigger ordinary light stage %d for %s" % [stage,hero])
			finish(battle)
			check(player.x>start,"Each separate light stage advances "+hero)
			check(enemy.hp<health,"Each light stage uses melee damage "+hero)
			check(battle.state.effects.all(func(e): return e.type != "projectile"),"Bow light never emits an arrow or needle")
			if stage<3: check(not enemy.airborne_lock and enemy.z == 0,"First two hits keep target standing")
			else: check(enemy.airborne_lock or enemy.action in ["down","recovering"],"Third hit launches")
		var hold := fresh(hero)
		tick(hold,Battle.LIGHT)
		for index in range(100): tick(hold,Battle.LIGHT)
		check(hold.state.fighters[0].action == "idle","Holding light never auto-plays all three stages")
		var grab := fresh(hero)
		var holder: Dictionary = grab.state.fighters[0]
		tick(grab,Battle.GRAB)
		check(holder.action == "grab_start","New grab entry exists")
		finish(grab,"holding")
		for stage in range(1,3):
			tick(grab,Battle.LIGHT)
			check(holder.action == "grab_hit_%d" % stage,"Distinct grab attack "+str(stage))
			finish(grab,"holding")
		var held_id := int(holder.grab_target)
		tick(grab,Battle.LIGHT)
		check(holder.action == "throw","Third light starts forward throw")
		var saw_throw := false
		for index in range(100):
			tick(grab)
			saw_throw = saw_throw or grab._fighter(held_id).thrown_by == holder.id
			if holder.action == "idle": break
		check(holder.grab_target == 0 and saw_throw,"Release event launches real enemy")
		var reverse := fresh(hero)
		tick(reverse,Battle.GRAB)
		finish(reverse,"holding")
		tick(reverse,0,-1)
		check(reverse.state.fighters[0].get("throw_clip") == "throw_reverse","Reverse stick selects shoulder throw")
		finish(reverse)
		check(reverse.state.fighters[0].face == -1,"Reverse throw recovers facing the new direction")

func heavy_tests() -> void:
	for hero in ["nobunaga","oichi"]:
		var battle := fresh(hero)
		var player: Dictionary = battle.state.fighters[0]
		var enemy: Dictionary = battle.state.fighters[1]
		var damage := int(enemy.hp)
		tick(battle,Battle.HEAVY)
		tick(battle)
		check(player.action == "heavy","Tap-release selects one fixed normal heavy")
		for index in range(60):
			tick(battle)
			if enemy.hp<damage:
				check(enemy.action == "hurt" and not enemy.airborne_lock,"Normal heavy pushes standing enemies")
				break
		check(enemy.hp<damage,"Released normal heavy hits without a second startup")
		var interrupt := fresh(hero)
		tick(interrupt,Battle.HEAVY)
		tick(interrupt)
		interrupt._damage(interrupt.state.fighters[0],1,interrupt.state.fighters[1].id,false)
		check(interrupt.state.fighters[0].action == "hurt","Heavy follow-through remains interruptible")
		var charge := fresh(hero)
		tick(charge,Battle.HEAVY)
		for index in range(65): tick(charge,Battle.HEAVY)
		check(charge.state.fighters[0].action == "charge","Full charge waits for release")
		tick(charge)
		check(charge.state.fighters[0].action == "charged","Full release selects powered move")
		var saw_piercing := false
		for index in range(100):
			tick(charge)
			for effect in charge.state.effects:
				if effect.type == "projectile" and effect.get("piercing",false): saw_piercing = true
		if hero == "oichi": check(saw_piercing,"Charged bow arrow penetrates")
	var rain := fresh("oichi")
	var rain_hp := int(rain.state.fighters[1].hp)
	tick(rain,Battle.HEAVY)
	for index in range(65): tick(rain,Battle.HEAVY)
	tick(rain,0,0,-1)
	check(rain.state.fighters[0].action == "charge_rain","Up held on release selects arrow rain")
	var saw_sky := false
	var saw_rain := false
	for index in range(160):
		tick(rain)
		for effect in rain.state.effects:
			saw_sky = saw_sky or effect.type == "sky_arrow"
			saw_rain = saw_rain or effect.type == "arrow_rain"
	check(saw_sky and saw_rain,"Independent arrow rain begins after upward arrow exits")
	check(rain.state.fighters[1].hp<rain_hp,"Arrow rain area actually damages enemies")
	var piercing := fresh("oichi")
	piercing.state.fighters[1].x = 680.0
	var second := piercing._make_fighter(1,"dummy",760,500,5000)
	piercing.state.fighters.append(second)
	tick(piercing,Battle.HEAVY)
	for index in range(65): tick(piercing,Battle.HEAVY)
	tick(piercing)
	for index in range(80): tick(piercing)
	check(piercing.state.fighters[1].hp<5000 and second.hp<5000,"One charged arrow hits two separate targets")
	var wave := fresh("nobunaga")
	wave.state.fighters[1].x = 765.0
	tick(wave,Battle.HEAVY)
	tick(wave)
	for index in range(65): tick(wave)
	check(wave.state.fighters[1].hp<5000 and not wave.state.fighters[1].airborne_lock,"Sword wave hits beyond blade contact with standing knockback")

func air_and_dash_tests() -> void:
	for hero in ["nobunaga","oichi"]:
		for action in ["air_light","air_heavy","dash_heavy"]:
			var battle := fresh(hero)
			var player: Dictionary = battle.state.fighters[0]
			player.combat_air_start = 50.0
			player.z = 50.0 if action.begins_with("air_") else 0.0
			battle._begin(player,action)
			var seen_arrows := 0
			for index in range(110):
				tick(battle)
				seen_arrows = maxi(seen_arrows,battle.state.effects.filter(func(e): return e.type == "projectile").size())
				if player.action == "idle": break
			check(player.action == "idle","Air/dash recovery completes "+hero+" "+action)
			if hero == "oichi": check(seen_arrows == (3 if action == "air_heavy" else 0),"Only aerial heavy emits exactly three arrows")
			if hero == "nobunaga" and action == "air_heavy": check(player.z == 0,"Sword aerial heavy reaches grounded landing")
		var shield_case := fresh(hero)
		var shield: Dictionary = shield_case.state.fighters[1]
		shield.kind = "soldier"
		shield.role = "shield_spear"
		shield.face = -1
		var hp := int(shield.hp)
		shield_case._begin(shield_case.state.fighters[0],"dash_heavy")
		for index in range(40):
			tick(shield_case)
			if shield.hp<hp: break
		check(shield.hp<hp and shield.action == "hurt" and not shield.airborne_lock,"Dash against shield soldier is a normal standing hit")

func actor(battle: Battle, hero: String, clip: String, milliseconds: float, index: int) -> Dictionary:
	var fighter := battle._make_fighter(0,hero,400,500,120)
	fighter.id = index+100
	fighter.player_index = index%2
	fighter.action = clip
	fighter.face = -1 if index%2 else 1
	fighter.action_tick = roundi(milliseconds*.06)
	if hero == "oichi" and clip == "heavy": fighter.action_tick = milliseconds*.06/Battle.OICHI_HEAVY_SPEED
	if clip.begins_with("light_"): fighter.action = "light"; fighter.combo = int(clip[-1])
	if fighter.action == "light" or (hero == "oichi" and fighter.action == "air_heavy"):
		var spec := Moves.spec(fighter)
		var contact := float(spec.events[0].ms)
		var hit_tick := Battle.fighter_tick(fighter,6)
		var end_tick := Battle.fighter_tick(fighter,27 if fighter.action == "air_heavy" else 19)
		if fighter.action == "light":
			hit_tick = roundi(hit_tick*Battle.LIGHT_TIME_SCALE)
			end_tick = roundi(end_tick*Battle.LIGHT_TIME_SCALE)
		fighter.action_tick = milliseconds/contact*hit_tick if milliseconds <= contact else hit_tick+(milliseconds-contact)/(float(spec.duration_ms)-contact)*(end_tick-hit_tick)
	if clip == "charge_release": fighter.action = "charged"
	if clip == "grab_hold": fighter.action = "holding"
	if clip.begins_with("throw_"): fighter.action = "throw";fighter.throw_clip = clip
	if fighter.action == "throw": fighter.action_tick = milliseconds*.06*Battle.THROW_TIME_SCALE
	if clip.begins_with("charge_") and clip in ["charge_ready","charge_hold"]:
		fighter.action = "charge"
		fighter.charge = roundi(milliseconds*.06)+(ceili(float(Moves.registration(hero).clips.charge_ready.duration_ms)*.06) if clip == "charge_hold" else 0)
	return fighter

func held_pose_tests(view: View) -> void:
	for hero in Battle.PLAYABLE_HEROES:
		for faction in ["mori","imagawa","oda"]:
			for kind in ["soldier","flag","commander","archer","gunner"]:
				for facing in [-1,1]:
					var battle := fresh(hero)
					var holder: Dictionary = battle.state.fighters[0]
					var target := battle._make_fighter(1,kind,holder.x+65*facing,holder.y,500)
					target.faction = faction
					holder.face = facing
					battle.state.fighters = [holder,target]
					battle._try_grab(holder)
					battle._begin(holder,"holding")
					battle._sync_grabs()
					var origin := Vector3(target.x,target.y,target.z)
					var first := view._fighter_animation(target)
					var cells := {}
					for index in range(120):
						battle.step([{}])
						var sample := view._fighter_animation(target)
						cells[sample.cell] = true
						check(Vector3(target.x,target.y,target.z).distance_to(origin) < .001 and target.vz == 0, "Holding keeps the real captive position stable")
						check(sample.sheet == first.sheet and target.held_by == holder.id, "Holding keeps the same restraint and art source")
					check(cells.size() == 1, "Held enemy must not cycle between displaced struggle poses: "+faction+"/"+kind)

class CaptureView extends View:
	var cards: Array = []
	var title := ""
	var stage_mode := false
	var floor_y := 240.0
	var row_stride := 250.0
	var column_start := 135.0
	var column_stride := 270.0
	func _draw() -> void:
		if stage_mode:
			super._draw()
			return
		draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),Color("303b40"))
		Typography.draw_label(self,Vector2(25,30),title,20,Color.WHITE)
		for index in range(cards.size()):
			var p := Vector2(column_start+(index%6)*column_stride,floor_y+(index/6)*row_stride)
			draw_line(p-Vector2(100,0),p+Vector2(100,0),Color("748189"),1)
			_draw_art_fighter(cards[index],p)
			Typography.draw_label(self,p+Vector2(-115,35),str(cards[index].qa_label),14,Color.WHITE)

func run() -> void:
	body_contact_tests()
	heavy_tests()
	air_and_dash_tests()
	var view := CaptureView.new()
	root.add_child(view)
	held_pose_tests(view)
	root.content_scale_size = Vector2i(1620,1000)
	root.size = Vector2i(1620,1000)
	var output := ProjectSettings.globalize_path("res://../artifacts/combat-v33")
	DirAccess.make_dir_recursive_absolute(output)
	var battle := Battle.new()
	for hero in ["nobunaga","oichi"]:
		var reg := Moves.registration(hero)
		check(reg.clips.size() == (16 if hero == "nobunaga" else 17),"Complete approved action inventory")
		view.cards.clear()
		view.title = hero+" / native battle size / 155 : 148 / alternating facings"
		for clip in reg.clips:
			var spec: Dictionary = reg.clips[clip]
			var time := 0.0
			for index in range(spec.frames.size()):
				var fighter := actor(battle,hero,clip,(time+float(spec.frames[index].duration_ms)*.5)*float(spec.duration_ms)/float(spec.get("animation_duration_ms",spec.duration_ms)),index)
				var sample := view._fighter_animation(fighter)
				check(sample.get("source_version") == "v33","Live renderer selects new source: "+clip)
				check(sample.get("frame") == index,"Variable-duration frame timing matches source: "+clip)
				var frame := view._art.animation_frame(hero,sample)
				check(not frame.is_empty() and not frame.combat_layers.has("string") and (not frame.combat_layers.has("weapon") or frame.get("authored_weapon",false)),"Weapons are independently registered and never baked into body: "+clip)
				var body_texture: Texture2D = frame.texture
				for weapon in Weapons.ids_for(hero):
					fighter.weapon_id = weapon
					var geometry: Dictionary = view._weapons.geometry(fighter,frame,148 if hero == "oichi" else 155)
					check(not geometry.is_empty() and geometry.id == Weapons.art_id(weapon),"All compatible equipped weapons resolve for "+clip)
					check(view._art.animation_frame(hero,sample).texture == body_texture,"Changing weapons never changes body pixels")
					var grip := view._weapons.pose_transform(geometry,Vector2.ZERO,float(fighter.face),0)*Vector2.ZERO
					check(grip.distance_to(Vector2(geometry.hand)*Vector2(fighter.face,1))<.001,"Equipped weapon grip stays at the authored anchor")
				time += float(spec.frames[index].duration_ms)
			var mid := actor(battle,hero,clip,float(spec.duration_ms)*.45,view.cards.size())
			mid.qa_label = clip
			view.cards.append(mid)
		view.state = {"tick":0,"phase":"playing","fighters":view.cards}
		if DisplayServer.get_name() != "headless":
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join(hero+"-native.png")) == OK,"Native action contact sheet saved")
	if DisplayServer.get_name() != "headless":
		root.content_scale_size = Vector2i(1620,900)
		root.size = Vector2i(1620,900)
		view.floor_y = 400.0
		view.row_stride = 400.0
		view.cards.clear()
		view.title = "Identical character pixels / equipped weapons change independently"
		for hero in ["nobunaga","oichi"]:
			var ids := Weapons.ids_for(hero)
			for index in range(6):
				var card := actor(battle,hero,"heavy",240 if hero == "oichi" else 300,view.cards.size())
				card.weapon_id = ids[mini(index*3,ids.size()-1)]
				card.face = 1
				card.qa_label = str(Weapons.item(card.weapon_id).name)
				view.cards.append(card)
		view.state = {"tick":0,"phase":"playing","fighters":view.cards}
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("weapon-swap-native.png")) == OK,"Same body with six different weapons per hero")
	if DisplayServer.get_name() != "headless":
		root.content_scale_size = Vector2i(1280,720)
		root.size = Vector2i(1280,720)
		battle.reset("normal",2,["nobunaga","oichi"])
		battle.state.fighters = battle.state.fighters.filter(func(f): return f.team == 0)
		battle.state.fighters[0].x = 480.0
		battle.state.fighters[1].x = 820.0
		for f in battle.state.fighters: f.y = 510.0;f.face = 1
		view.stage_mode = true
		view.state = battle.state
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("scale-stage.png")) == OK,"Both heroes on the native game stage")
		for holder in battle.state.fighters.duplicate():
			var target := battle._make_fighter(1,"soldier",holder.x+65,holder.y,500)
			battle.state.fighters.append(target)
			battle._try_grab(holder)
			battle._begin(holder,"holding")
		battle._sync_grabs()
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("grab-stage.png")) == OK,"Grab contacts use real enemy art")
		for phase in range(1,5):
			for tick in range(10): battle.step([{},{}])
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("grab-hold-%d.png" % (phase*10))) == OK,"Holding pose remains stable across struggle phases")
		battle.reset_training("oichi")
		battle.state.props.clear()
		battle.state.fighters[0].x = 140.0
		battle.state.fighters[0].y = 510.0
		battle.state.fighters[1].x = 2000.0
		view.state = battle.state
		view.camera_x = 0.0
		for tick in range(45):
			battle.step([{"buttons":Battle.JUMP|Battle.HEAVY if tick == 0 else 0}])
			if tick in [8,16,32,44]:
				view.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(output.path_join("oichi-air-range-%d.png" % tick)) == OK,"Aerial spread rendered at native screen width")
		view.stage_mode = false
		view.art_demo = true
		view.floor_y = 520.0
		view.column_start = 360.0
		view.column_stride = 560.0
		view.cards.clear()
		for hero in ["nobunaga","oichi"]:
			var card := actor(battle,hero,"light_1",0,view.cards.size())
			card.action = "idle"
			card.qa_label = hero+" / max showcase"
			view.cards.append(card)
		view.title = "Maximum showcase size: Nobunaga 240px / Oichi 225px"
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("maximum-native.png")) == OK,"Maximum-size native rendering saved")
	view.queue_free()
	await process_frame
	print("COMBAT V33 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
