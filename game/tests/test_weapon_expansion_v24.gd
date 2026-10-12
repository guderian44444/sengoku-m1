extends SceneTree

const Battle = preload("res://core/battle.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Profiles = preload("res://core/save_profile.gd")
const Wire = preload("res://core/wire.gd")
const Renderer = preload("res://render/weapon_renderer.gd")
const Archive = preload("res://core/weapon_encyclopedia.gd")
const Typography = preload("res://render/game_typography.gd")
var checks := 0
var failures := 0
var output: String

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func arena(hero: String) -> Battle:
	var battle := Battle.new()
	battle.reset("normal",1,[hero])
	battle.state.fighters = battle.state.fighters.filter(func(f): return f.team == 0)
	battle.state.drops.clear()
	battle.state.props.clear()
	battle.state.effects.clear()
	return battle

func enemy(battle: Battle, x: float, y: float) -> Dictionary:
	var target := battle._make_fighter(1,"dummy",x,y,1000)
	battle.state.fighters.append(target)
	return target

func _initialize() -> void:
	output = ProjectSettings.globalize_path("res://../artifacts/native-v24/saves-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(output)
	var research: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/v24/weapons/research-30.json"))
	var renderer := Renderer.new()
	var archive := Archive.new()
	var font:=Typography.font()
	for character in JSON.stringify(archive.entries):
		if character.unicode_at(0)>32: check(font.has_char(character.unicode_at(0)),"Bundled glyph coverage: "+character)
	check(Weapons.ITEMS.size() == 48 and research.weapons.size() == 30,"48 total, 30 additions")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/v24/weapons/registration-18-before.json"))
	for id in old.items: check(renderer.items[id] == old.items[id],"Approved registration untouched: " + id)
	for hero in ["nobunaga","tadakatsu","oichi"]:
		check(Weapons.ids_for(hero).size() == 16,hero + " has sixteen compatible designs")
		var original_ids: Array = old.items.keys().filter(func(id): return Weapons.compatible(hero,id))
		var profile := {"version":1,"characters":{}}
		profile.characters["0:"+hero] = {"slot":0,"hero":hero,"score":0,"max_hp_bonus":0,"weapon_id":Weapons.default_for(hero),"owned_weapons":original_ids}
		check(original_ids.size() == 6 and Profiles.valid(profile),hero + " exact previous six-item save is compatible")
		original_ids.erase({"nobunaga":"sword_kanesada_mino","tadakatsu":"spear_fukuro_yari","oichi":"bow_awase_yumi"}[hero])
		profile.characters["0:"+hero].owned_weapons=original_ids
		check(original_ids.size() == 5 and Profiles.valid(profile),hero + " exact original five-item save is compatible")
	for row in research.weapons:
		var id: String = row.id
		var item: Dictionary = Weapons.item(id)
		var hero: String = {"sword":"nobunaga","spear":"tadakatsu","bow":"oichi"}[item.family]
		check(renderer.items.has(id) and renderer.textures.has(id),id + " loads texture and rig")
		check(archive.entries.has(id) and archive.entry(id).game_note.contains("遊戲"),id + " has separate historical and gameplay record")
		check(archive.entry(id).reference_images.is_empty() and archive.entry(id).photo_status.contains("授權"),id + " never substitutes art for unlicensed photograph")
		var battle := arena(hero)
		var player: Dictionary = battle.state.fighters[0]
		player.owned_weapons=Weapons.ids_for(hero).filter(func(candidate): return candidate != id)
		player.weapon_id=Weapons.default_for(hero)
		for candidate in player.owned_weapons:
			if Weapons.item(candidate).tier==5: player.weapon_id=candidate
		var boss:=enemy(battle,player.x,player.y)
		boss.stage_boss=true
		battle._drop_boss_weapon(boss,player.id)
		check(battle.state.drops.size()==1 and battle.state.drops[0].weapon_id==id,id + " is collectible as last missing item at tier five")
		battle._pickup(player)
		check(player.weapon_id==id and player.owned_weapons.size()==16,id + " pickup equips and records ownership")
		var path:=output.path_join(id+".json")
		var profiles:=Profiles.new(path)
		profiles.capture(player)
		check(profiles.save()==OK and Profiles.new(path).character(0,hero).weapon_id==id,id + " full inventory saves and reloads equipped item")
		check(Wire.valid_snapshot(battle.get_state()),id + " full equipment snapshot validates")
		check(Weapons.loot_candidates(hero,id,player.owned_weapons,3).is_empty(),id + " complete collection has no repeat loot")
		var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/v22/"+hero+"/registration.json"))
		var height:=148.0 if hero=="oichi" else 155.0
		var bitmap: Image=renderer.textures[id].get_image()
		for action in registration.clips:
			for source_frame in registration.clips[action].frames:
				var foot:=Vector2(source_frame.foot[0],source_frame.foot[1])
				var hand:=Vector2(source_frame.hand[0],source_frame.hand[1])-foot
				var frame: Dictionary=source_frame.duplicate(true)
				frame.layered_weapon=true
				frame.weapon_hand=hand
				var pose:=renderer.geometry(player,frame,height)
				if not frame.get("weapon_visible",true):
					check(pose.is_empty(),id + " hidden frame stays hidden")
					continue
				check(not pose.is_empty() and pose.top.is_finite() and pose.bottom.is_finite(),id + " finite authored geometry "+action)
				check(pose.hand.is_equal_approx(hand*height/float(frame.body_height)),id + " preserves exact primary hand "+action)
				var pixel:=Vector2i(roundi(pose.grip.x),roundi(pose.grip.y))
				check(pixel.x>=0 and pixel.y>=0 and pixel.x<bitmap.get_width() and pixel.y<bitmap.get_height() and bitmap.get_pixel(pixel.x,pixel.y).a>.5,id + " visible primary grip touches actual weapon pixels, including grounded shaft slide "+action)
				for face in [-1,1]:
					var top: Vector2=pose.top*Vector2(face,1)
					var bottom: Vector2=pose.bottom*Vector2(face,1)
					check(top.is_finite() and bottom.is_finite() and top.distance_to(bottom)>40,id + " complete mirrored endpoints "+action)
		if item.family=="bow":
			check(float(renderer.items[id].world_length)>=160 and float(renderer.items[id].world_length)<=180,id + " stays at approved character-relative bow scale")
			var spec: Dictionary=renderer.items[id]
			var fraction: float=(float(spec.grip[1])-float(spec.tip_top[1]))/float(spec.length)
			check(fraction>=.57 and fraction<=.70,id + " has long upper and short lower limb")
		for face in [-1,1]:
			var combat:=arena(hero)
			var attacker: Dictionary=combat.state.fighters[0]
			attacker.x=700.0
			attacker.face=face
			attacker.action="heavy"
			attacker.weapon_id=id
			attacker.owned_weapons.append(id)
			if item.family!="bow":
				var reach: float=(200.0+float(item.reach_bonus))*float(Battle.HERO_PROFILES[hero].reach)
				var inside:=enemy(combat,attacker.x+face*(reach-1.0),attacker.y)
				var outside:=enemy(combat,attacker.x+face*(reach+1.0),attacker.y)
				combat._melee(attacker,200,80,26,false)
				check(inside.hp==1000-roundi((26+int(item.damage_bonus))*float(Battle.HERO_PROFILES[hero].damage)),id + " correct hit damage on facing "+str(face))
				check(outside.hp==1000,id + " cannot hit beyond gameplay reach on facing "+str(face))
			else:
				combat._projectile(attacker,24,0,false,"arrow",760)
				var arrow: Dictionary=combat.state.effects[-1]
				check(arrow.damage==24+item.damage_bonus and arrow.range_left==655+item.reach_bonus,id + " arrow snapshots damage/range")
				check(arrow.equipment_id==id and arrow.equipment_knockback==item.knockback and not arrow.piercing,id + " ordinary arrow remains single-target")
				attacker.weapon_id=Weapons.default_for(hero)
				check(arrow.equipment_id==id and arrow.damage==24+item.damage_bonus,id + " in-flight stats survive equipment swap")
	print("WEAPON EXPANSION V24 %s: %d checks, %d failures" % ["PASS" if failures==0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
