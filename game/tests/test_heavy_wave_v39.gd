extends SceneTree

const Battle = preload("res://core/battle.gd")
const Moves = preload("res://core/combat_moves.gd")
const Equipment = preload("res://core/equipment.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Wire = preload("res://core/wire.gd")
const View = preload("res://render/battle_view.gd")
var checks := 0
var captures := []

class Board extends View:
	var poses := []
	func _process(_delta: float) -> void: pass
	func _draw() -> void:
		_fx.shared_player.begin_draw(self)
		draw_rect(Rect2(0,0,2400,1500),Color("273337"))
		for i in range(poses.size()):
			var pose: Dictionary = poses[i]
			state = pose.world
			var fighter: Dictionary = state.fighters[0]
			var offset := Vector2((i%2)*1200+(850 if fighter.face<0 else 350),(i/2)*500+450)-Vector2(fighter.x,fighter.y)
			var origin := Vector2(fighter.x,fighter.y)+offset
			draw_line(origin-Vector2(420,0),origin+Vector2(420,0),Color("566965"))
			_draw_art_fighter(fighter,origin)
			for source in state.effects:
				if source.type != "blade_wave": continue
				var effect: Dictionary = source.duplicate(true)
				effect.x += offset.x
				effect.y += offset.y
				_draw_effect(effect)
			draw_string(ThemeDB.fallback_font,Vector2((i%2)*1200+30,(i/2)*500+32),pose.label,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)

func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)

func arena(hero: String, face: int = 1, weapon: String = "") -> Battle:
	var battle := Battle.new()
	battle.reset_training(hero,"dummy")
	battle.state.props.clear()
	var player: Dictionary = battle.state.fighters[0]
	player.x = 1000.0
	player.y = 500.0
	player.face = face
	if not weapon.is_empty(): Equipment.equip(player,Equipment.add(player,weapon))
	var target: Dictionary = battle.state.fighters[1]
	target.hp = 10000
	target.max_hp = 10000
	target.x = player.x+face*300
	target.y = player.y
	return battle

func boundaries() -> void:
	for hero in Moves.HEROES:
		if hero == "oichi": continue
		for face in [-1,1]:
			for weapon in Weapons.ids_for(hero):
				var reach := (420.0+float(Weapons.item(weapon).get("reach_bonus",0))+12.0)*float(Battle.HERO_PROFILES[hero].reach)
				var depth := 150.0*float(Battle.HERO_PROFILES[hero].depth)
				for probe in [Vector3(reach-.01,0,1),Vector3(reach+.1,0,0),Vector3(80,depth-.01,1),Vector3(80,depth+.1,0),Vector3(-36,0,1),Vector3(-36.1,0,0)]:
					var battle := arena(hero,face,weapon)
					var player: Dictionary = battle.state.fighters[0]
					Equipment.equip(player,Equipment.add(player,"moon"))
					battle._begin(player,"air_heavy")
					player.z = 125.0
					var target: Dictionary = battle.state.fighters[1]
					target.x = player.x+probe.x*face
					target.y = player.y+probe.y
					battle._combat_contact_v33(player,"contact")
					check((target.hp<10000)==bool(probe.z),"Downward wave boundary: "+hero+"/"+weapon+"/"+str(probe))
					if probe.z == 1:
						check(target.action == "down","Ground target is knocked down, even below airborne attacker")
						var base_damage := roundi((26+player.weapon*8)*1.3) if hero=="nobunaga" else 35+int(player.weapon)*6
						var expected := maxi(1,roundi((base_damage+int(Weapons.item(weapon).get("damage_bonus",0)))*float(Battle.HERO_PROFILES[hero].damage))-int(target.armor)*3)
						check(10000-target.hp==expected,"Aerial damage is unchanged while coverage expands")
					var waves: Array = battle.state.effects.filter(func(e): return e.type == "blade_wave")
					check(waves.size()==1 and is_equal_approx(waves[0].radius,reach) and is_equal_approx(waves[0].hit_depth,depth),"Visual wave receives the actual equipment-adjusted hit bounds")
					check(Wire.valid_snapshot(battle.state),"Expanded wave serializes for co-op")

func safety() -> void:
	for hero in Moves.HEROES:
		if hero == "oichi": continue
		var battle := arena(hero)
		var player: Dictionary = battle.state.fighters[0]
		var target: Dictionary = battle.state.fighters[1]
		battle._begin(player,"air_heavy")
		player.z = 125.0
		var ally: Dictionary = player.duplicate(true)
		ally.id = 10
		ally.x += 80
		battle.state.fighters.append(ally)
		var health := int(ally.hp)
		battle.state.props.append({"id":999,"kind":"crate","x":player.x+220,"y":player.y,"width":40.0,"depth":40.0,"hp":10000,"max_hp":10000,"broken":false,"drop":""})
		battle._combat_contact_v33(player,"contact")
		check(ally.hp==health and target.hp<10000,"Downward wave ignores allies and hits enemies")
		check(battle.state.props[0].hp<10000,"Downward wave also reaches ground props")
		health = int(target.hp)
		for tick in range(25):
			target.invuln = 0
			battle._tick_effects()
		check(target.hp==health,"Visual tail cannot apply the hit twice")
		target.invuln = 20
		battle._combat_contact_v33(player,"contact")
		check(target.hp==health,"Downward wave respects invulnerability")

func live_inputs() -> void:
	for hero in Moves.HEROES:
		for face in [-1,1]:
			var battle := arena(hero,face)
			var player: Dictionary = battle.state.fighters[0]
			battle.step([{"buttons":Battle.JUMP|Battle.HEAVY}])
			check(player.action=="air_heavy","Jump plus heavy input selects aerial heavy: "+hero)
			var waves: int = battle.state.effects.filter(func(e): return e.type=="blade_wave").size()
			var arrows := 0
			var hits: int = battle.state.events.filter(func(e): return e.type=="weapon_swing").size()
			if hero == "nobunaga": check(waves==1 and hits==1,"Nobunaga releases on the heavy input tick")
			for tick in range(90):
				battle.step([{}])
				hits += battle.state.events.filter(func(e): return e.type=="weapon_swing").size()
				for e in battle.state.effects:
					if e.get("weapon","")=="arrow" and e.life==e.max_life: arrows += 1
					if e.type=="blade_wave":
						var age := int(e.max_life-e.life)
						if age==0: waves += 1
						if age==0 or (hero=="nobunaga" and age in [4,8]):
							captures.append({"order":Moves.HEROES.find(hero)*1000+age*10+(0 if face<0 else 1),"label":("kennyo" if hero=="mitsuhide" else hero)+" air heavy / %d ticks / " % age+("left" if face<0 else "right"),"world":battle.state.duplicate(true)})
				check(Wire.valid_snapshot(battle.state),"Actual input, motion and visual tail keep valid state")
			if hero == "oichi": check(waves==0 and arrows==3,"Oichi keeps her three arrows and gets no sword wave")
			else: check(waves==1 and hits==1,"Each aerial heavy emits one wave and one weapon swing")
			check(player.action=="idle" and player.z==0,"Aerial heavy lands and recovers")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	boundaries()
	safety()
	live_inputs()
	if DisplayServer.get_name() != "headless":
		var viewport := SubViewport.new()
		viewport.size = Vector2i(2400,1500)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var view := Board.new()
		viewport.add_child(view)
		view._fx.muted = true
		check(view._fx.configured and view._fx.shared_player.textures.has("blade_arc") and view._fx.shared_player.textures.has("blade_wave"),"Existing sword-wave assets load")
		var folder := "res://../artifacts/heavy-wave-v39"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		captures.sort_custom(func(a,b): return a.order<b.order)
		for page in range(ceili(captures.size()/6.0)):
			view.poses = captures.slice(page*6,mini(captures.size(),page*6+6))
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(viewport.get_texture().get_image().save_png(folder+"/moves-%d.png" % page)==OK,"Native move capture saved")
		viewport.free()
	print("HEAVY WAVE V39 PASS: %d checks" % checks)
	quit()
