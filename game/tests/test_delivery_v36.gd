extends SceneTree
const Battle = preload("res://core/battle.gd")
const Moves = preload("res://core/combat_moves.gd")
const Art = preload("res://render/art_assets.gd")
const Frames = preload("res://render/frame_animation.gd")
const Wire = preload("res://core/wire.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Equipment = preload("res://core/equipment.gd")
const WeaponRenderer = preload("res://render/weapon_renderer.gd")
var checks := 0
var failures := 0
var measurements := []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

class Sheet extends "res://render/battle_view.gd":
	var rows := []
	var subject: Dictionary
	func _draw() -> void:
		draw_rect(Rect2(0,0,1800,rows.size()*230),Color("353535"))
		for row in range(rows.size()):
			if rows[row].has("weapon"): subject.weapon_id=rows[row].weapon
			var frames: Array = rows[row].frames
			for col in range(6):
				var index := roundi((frames.size()-1)*col/5.0)
				var frame: Dictionary = frames[index]
				var origin := Vector2(col*300+130,row*230+200)
				var face := -1.0 if col==5 else 1.0
				var height: float = FrameAnimation.CombatMoves.HEIGHTS[subject.kind]
				draw_line(origin+Vector2(-120,0),origin+Vector2(165,0),Color("776654"))
				for key in ["fx_back"]:
					if frame.get("combat_layers",{}).has(key): _draw_art_frame(frame.combat_layers[key],origin,height,face,0,Color.WHITE,float(frame.combat_layers[key].body_height))
				_weapons.draw_weapon(self,subject,frame,origin,height,face,0,Color.WHITE,true)
				_draw_art_frame(frame,origin,height,face,0,Color.WHITE,float(frame.body_height))
				_weapons.draw_weapon(self,subject,frame,origin,height,face,0,Color.WHITE,false)
				_weapons.draw_hand_occlusion(self,frame,origin,height,face,0,Color.WHITE)
				if frame.get("combat_layers",{}).has("fx"): _draw_art_frame(frame.combat_layers.fx,origin,height,face,0,Color.WHITE,float(frame.combat_layers.fx.body_height))
				draw_string(ThemeDB.fallback_font,Vector2(col*300+8,row*230+18),"%s %s #%d" % [subject.kind,rows[row].name,index],HORIZONTAL_ALIGNMENT_LEFT,-1,14)
	func _process(_delta: float) -> void: pass

func _initialize() -> void: run.call_deferred()

func balance_checks(art: Art) -> void:
	for hero in Moves.HEROES:
		for weapon in Weapons.ids_for(hero):
			var battle := Battle.new()
			battle.reset_training(hero,"dummy")
			var player: Dictionary = battle.state.fighters[0]
			Equipment.equip(player,Equipment.add(player,weapon))
			var stats := Battle.character_stats(player)
			var target: Dictionary = battle.state.fighters[1]
			target.x=player.x+70;target.y=player.y;target.hp=10000;target.max_hp=10000
			target.home_x=target.x;target.home_y=target.y
			player.combo=1
			player.combo_tick=200
			battle._begin(player,"heavy" if hero=="oichi" else "light")
			for tick in range(120):
				battle.step([{"buttons":0,"dx":0,"dy":0}])
				if target.hp<10000: break
			check(10000-target.hp==stats.damage,"Inventory damage matches first live hit: "+hero+"/"+weapon)
			if hero!="oichi": check(is_equal_approx(player.attack_reach,stats.reach),"Inventory reach matches live melee: "+hero+"/"+weapon)
		for distance in [-90,500]:
			var battle := Battle.new();battle.reset_training(hero,"dummy")
			var player: Dictionary = battle.state.fighters[0]
			var target: Dictionary = battle.state.fighters[1]
			target.x=player.x+distance;target.hp=10000;target.max_hp=10000
			target.home_x=target.x;target.home_y=target.y
			battle._begin(player,"light")
			var hit := false
			for tick in range(60):
				battle.step([{"buttons":0,"dx":0,"dy":0}])
				hit=hit or target.hp<10000
			check(not hit,"Light cannot hit distant or rear targets: "+hero)
	check(Weapons.valid_inventory("mitsuhide","sword_uchigatana",["practice_mitsuhide","sword_uchigatana"]),"Legacy Kennyo inventory survives")
	for id in ["staff_long_staff","staff_ornate_shakujo","staff_approved03_naginata"]:
		check(Weapons.compatible("mitsuhide",id) and not Weapons.compatible("tadakatsu",id),"Delivered staff belongs to Kennyo")
	var renderer := WeaponRenderer.new()
	for hero in ["hideyoshi","ieyasu","mitsuhide","tadakatsu"]:
		var battle := Battle.new();battle.reset_training(hero,"dummy")
		var player: Dictionary = battle.state.fighters[0]
		for weapon in Weapons.ids_for(hero):
			player.weapon_id=weapon
			for sheet in art.animations[hero]:
				if not sheet.begins_with("v33_"): continue
				for frame in art.animations[hero][sheet]:
					if not frame.get("weapon_visible",true) or renderer.uses_authored_weapon(player,frame): continue
					var pose := renderer.geometry(player,frame,Moves.HEIGHTS[hero])
					check(not pose.is_empty(),"Every equipped weapon has a rendered socket: "+hero+weapon+sheet)
					if frame.get("weapon_stowed",false) and hero=="tadakatsu": check(maxf(pose.top.y,pose.bottom.y)<0,"Carried spear clears the floor")
	for action in ["heavy","charged"]:
		var battle := Battle.new();battle.reset_training("ieyasu","dummy")
		var player: Dictionary = battle.state.fighters[0]
		var targets := []
		battle.state.fighters=[player]
		for distance in [100,160,220]:
			var target := battle._make_fighter(1,"dummy",player.x+distance,player.y,10000)
			target.home_x=target.x;target.home_y=target.y
			target.weight="heavy"
			battle.state.fighters.append(target);targets.append(target)
		battle._begin(player,action)
		var hits := [0,0,0]
		var hp := [10000,10000,10000]
		for tick in range(180):
			battle.step([{"buttons":0,"dx":0,"dy":0}])
			for i in range(targets.size()):
				if targets[i].hp<hp[i]: hits[i]+=1
				hp[i]=targets[i].hp
		check(hits==[1,1,1],"Ieyasu sword wave pierces three enemies exactly once: "+action)

func run() -> void:
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts/integration-v36"))==OK,"Create verification output directory on a fresh checkout")
	var art := Art.new()
	balance_checks(art)
	for hero in Moves.HEROES:
		var battle := Battle.new()
		battle.reset_training(hero,"dummy")
		var player: Dictionary = battle.state.fighters[0]
		check(player.kind==hero,"All six selectable: "+hero)
		for clip_name in ["idle","walk","run","jump","hurt","stunned","launched","down","recovering","victory"]:
			check(art.animations[hero].has("v22_"+clip_name),"Complete basic action: "+hero+clip_name)
		var registration := Moves.registration(hero)
		check(registration.clips.size()==(17 if hero=="oichi" else 16),"Every accepted combat action is registered")
		for name in registration.clips:
			var spec: Dictionary = registration.clips[name]
			check(art.animations[hero]["v33_"+name].size()==spec.frames.size(),"Every delivered frame reaches renderer")
			if name in ["charge_ready","charge_hold","grab_hold","grab_start"]: continue
			battle.reset_training(hero,"dummy")
			player = battle.state.fighters[0]
			var target: Dictionary = battle.state.fighters[1]
			player.x = 500.0
			player.y = 500.0
			target.x = 580.0
			target.y = 500.0
			target.home_x=target.x;target.home_y=target.y
			target.hp = 10000
			target.max_hp = 10000
			var action: String = "light" if name.begins_with("light_") else ("charged" if name=="charge_release" else ("throw" if name.begins_with("throw_") else name))
			player.combo = int(name.right(1)) if name.begins_with("light_") else 1
			player.combo_tick = 200
			if name.begins_with("air_"): player.z = 1.0; player.vz = 9.0
			if name.begins_with("grab_hit_") or action=="throw":
				player.grab_target = target.id
				target.held_by = player.id
				battle._begin(target,"grabbed")
			if action=="throw": player.throw_clip=name;player.throw_face=1
			battle._begin(player,action)
			var hit_count := 0
			var total_damage := 0
			var previous_hp: int = target.hp
			for tick in range(300):
				battle.step([{"buttons":0,"dx":0,"dy":0}])
				check(Wire.valid_snapshot(battle.state),"Network state valid: "+hero+name)
				if target.hp<previous_hp:
					hit_count+=1
					total_damage+=previous_hp-target.hp
				previous_hp=target.hp
				if player.action in ["idle","holding"] and tick>160: break
			check(hit_count>0,"Attack connects: "+hero+" "+name)
			check(player.action in ["idle","holding"],"Action exits: "+hero+" "+name)
			measurements.append({"hero":hero,"move":name,"damage":total_damage,"hits":hit_count,"reach":player.get("attack_reach",0)})
			if hero=="mitsuhide" and name=="charge_release": check(hit_count==6,"Prayer beads strike six times")
			if action=="throw": check(total_damage==Battle.HERO_PROFILES[hero].throw_damage and hit_count==1,"Throw releases once at the hero's damage")
		# Physical button edges exercise buffering and facing, independently of clip length.
		battle.reset_training(hero,"dummy")
		player=battle.state.fighters[0]
		battle.step([{"buttons":Battle.LIGHT,"dx":1,"dy":0}])
		battle.step([{"buttons":0,"dx":0,"dy":0}])
		battle.step([{"buttons":Battle.LIGHT,"dx":0,"dy":0}])
		for tick in range(40): battle.step([{"buttons":0,"dx":0,"dy":0}])
		check(player.combo==2,"Buffered next light is not held behind animation tail: "+hero)
		battle._begin(player,"idle")
		battle.step([{"buttons":Battle.HEAVY,"dx":1,"dy":0}])
		battle.step([{"buttons":Battle.HEAVY,"dx":-1,"dy":0}])
		check(player.face==-1,"Charge turns freely: "+hero)
		battle.step([{"buttons":0,"dx":-1,"dy":0}])
		check(player.action=="heavy" and player.action_tick>=2,"Partial charge credited: "+hero)
	if "--capture" in OS.get_cmdline_user_args():
		var viewport := SubViewport.new()
		viewport.size=Vector2i(1800,3680)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var sheet := Sheet.new()
		viewport.add_child(sheet)
		for hero in Moves.HEROES:
			var b := Battle.new();b.reset_training(hero,"dummy")
			sheet.subject=b.state.fighters[0]
			sheet.rows=[]
			for name in Moves.registration(hero).clips:sheet.rows.append({"name":name,"frames":art.animations[hero]["v33_"+name]})
			viewport.size=Vector2i(1800,sheet.rows.size()*230)
			sheet.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(viewport.get_texture().get_image().save_png("res://../artifacts/integration-v36/"+hero+"-combat.png")==OK,"Native capture saved")
			sheet.rows=[]
			for name in ["idle","walk","run","jump","hurt","stunned","launched","down","recovering","victory"]:sheet.rows.append({"name":name,"frames":art.animations[hero]["v22_"+name]})
			viewport.size=Vector2i(1800,2300)
			sheet.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(viewport.get_texture().get_image().save_png("res://../artifacts/integration-v36/"+hero+"-basic.png")==OK,"Native basics saved")
			if hero in ["hideyoshi","ieyasu","tadakatsu"]:
				sheet.subject.weapon_id="spear_tonbokiri" if hero=="tadakatsu" else "sword_heshikiri"
				sheet.rows=[]
				for name in Moves.registration(hero).clips: sheet.rows.append({"name":name,"frames":art.animations[hero]["v33_"+name]})
				viewport.size=Vector2i(1800,sheet.rows.size()*230)
				sheet.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				check(viewport.get_texture().get_image().save_png("res://../artifacts/integration-v36/"+hero+"-equipped.png")==OK,"Native equipped actions saved")
			if hero=="mitsuhide":
				sheet.rows=[]
				for weapon in ["staff_long_staff","staff_ornate_shakujo","staff_approved03_naginata"]:
					for name in ["light_1","heavy","charge_ready","charge_release","grab_start"]:
						sheet.rows.append({"name":weapon+" "+name,"weapon":weapon,"frames":art.animations[hero]["v33_"+name]})
				viewport.size=Vector2i(1800,sheet.rows.size()*230)
				sheet.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				check(viewport.get_texture().get_image().save_png("res://../artifacts/integration-v36/kennyo-weapons.png")==OK,"Native staff swaps saved")
		viewport.queue_free()
		await process_frame
	FileAccess.open("res://../artifacts/integration-v36/balance.json",FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t"))
	print("DELIVERY V36 %s: %d checks, %d failures" % ["PASS" if failures==0 else "FAILED",checks,failures])
	quit(0 if failures==0 else 1)
