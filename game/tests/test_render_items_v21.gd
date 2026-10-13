extends SceneTree

const View = preload("res://render/battle_view.gd")
const HUD = preload("res://render/combat_hud.gd")
const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

class IconView extends View:
	var cards: Array = []
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)),Color("303c39"))
		Typography.draw_label(self,Vector2(24,36),"護身符功能圖示：盾牌／疾風／攻擊／範圍",24,Typography.PAPER)
		for index in range(cards.size()):
			var at := Vector2(220+(index%3)*420,330+(index/3)*330)
			_draw_art_fighter(cards[index],at)
			Typography.draw_label(self,at+Vector2(-170,45),str(cards[index].qa_label),20,Typography.PAPER,340,HORIZONTAL_ALIGNMENT_CENTER)

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func capture(view: Node, hud: Node, battle: RefCounted, filename: String) -> void:
	check(Wire.valid_snapshot(battle.state),filename + " uses a legal network snapshot")
	var before := var_to_bytes(battle.state)
	view.state = battle.state
	hud.sync(battle.state)
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(var_to_bytes(battle.state) == before,filename + " render leaves authoritative state unchanged")
	var folder := ProjectSettings.globalize_path("res://../artifacts/native-v21")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(filename)) == OK,filename + " screenshot saved")

func run() -> void:
	var labels := HUD.player_status({"lives":3,"score":12500,"shield_points":75},100)
	check(labels.lives == "命×3" and labels.score == "分 0012500" and labels.shield == "符 75","HUD keeps current body in three lives and shows score and finite charm durability")
	check(HUD.player_status({"lives":0},0).lives == "命盡","Exhausted lives are explicit")
	check(HUD.player_status({"lives":2,"respawn_ticks":72},0).shield == "再起 1.2","Revival countdown uses simulation seconds")
	check(HUD.player_status({"extra_life_tick":100},100).extra,"Extra life flashes at award")
	check(not HUD.player_status({"extra_life_tick":100},116).extra,"Extra life flash has a readable off phase")
	check(not HUD.player_status({"extra_life_tick":100},220).extra,"Extra life hint expires after 120 ticks")
	check(not HUD.player_status({"extra_life_tick":100},99).extra,"Future snapshots do not flash early")
	check(HUD.player_rect(0).size == Vector2(392,104) and HUD.player_rect(1).end.x == 1264,"Weapon row adds twenty pixels within the two corner HUD panels")
	var icons := {"vajra":"shield","iron":"shield","mirror":"shield","wind":"speed","war":"attack","moon":"reach"}
	for kind in icons:
		var fighter := {"hp":120,"shield_points":1,"shield_kind":kind}
		check(View.buff_icon(fighter) == icons[kind],kind + " uses its function icon until last shield point")
		check(View.shield_glow_color(fighter).a == 0,kind + " has no surrounding glow")
		fighter.shield_points = 0
		check(View.buff_icon(fighter).is_empty(),kind + " icon ends exactly at zero")
		fighter.shield_points = 40
		fighter.hp = 0
		check(View.buff_icon(fighter).is_empty(),kind + " does not mark a corpse")
	check(View.buff_icon({"hp":120,"shield_points":40,"shield_kind":"unknown"}).is_empty(),"Unknown charm has no icon")
	for combo in [1,2]:
		var fighter := {"kind":"nobunaga","action":"heavy","heavy_combo":combo}
		var style := View.strike_accent(fighter,{"tick":14,"source":"v12"})
		var extent := View.strike_radius(fighter,style,155) + 9.0 + float(style.path[1]) * .5
		check(is_equal_approx(extent,Battle.nobunaga_heavy_reach(combo)),"Nobunaga heavy %d outer ribbon matches core reach" % combo)
	var other := {"kind":"tadakatsu","action":"heavy","heavy_combo":1}
	var other_style := View.strike_accent(other,{"tick":14,"source":"v17"})
	check(is_equal_approx(View.strike_radius(other,other_style,155),155 * float(other_style.path[0])),"Other heroes keep their existing effect sizing")
	var view := View.new()
	root.add_child(view)
	for hero in Battle.HEROES:
		for clip in view._art.animations[hero]:
			for frame in view._art.animations[hero][clip]:
				for face in [-1.0,1.0]:
					for rotation in [0.0,-1.3*face]:
						var rect := View.buff_rect(frame,155,face,rotation)
						var clear := rect.size == Vector2(20,24) and is_finite(rect.position.y)
						for layer in frame.get("layers",[frame]):
							var bounds: Rect2 = layer.get("opaque_bounds",Rect2(Vector2.ZERO,layer.region.size))
							for point in layer.get("clip_polygon",[bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]):
								var pixel := ((Vector2(point)-Vector2(layer.anchor)) * 155 / float(frame.body_height) * Vector2(face,1)).rotated(rotation)
								clear = clear and rect.end.y <= pixel.y-13.99
						check(clear,hero + "/" + clip + " icon keeps a 14px gap across pose, facing and rotation")
	check(view._treasures.size() == 3,"Three high resolution charm textures load")
	for key in view._treasures:
		var image: Image = view._treasures[key].get_image()
		check(image.get_width() > 500 and image.get_height() > 500,key + " source remains high resolution")
		check(image.get_format() == Image.FORMAT_RGBA8 and image.get_pixel(0,0).a < .04,key + " keeps transparent sprite corners")
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280,720)
		var battle := Battle.new()
		battle.reset_campaign("normal",2,["nobunaga","oichi"])
		var players: Array = battle.state.fighters.filter(func(f): return f.team == 0)
		battle.state.tick = 100
		for index in range(players.size()):
			players[index].x = 440 + index * 250
			players[index].y = 540
			battle._add_drop("talisman",players[index].x,players[index].y)
			battle.state.drops[-1].talisman_id = "vajra" if index == 0 else "mirror"
			battle._pickup(players[index])
		battle.state.tick += 40
		battle._award_score(players[0].id,12500)
		battle._award_score(players[1].id,7200)
		check(players[0].lives == 4 and players[0].next_life_score == 20000,"Native fixture awards its extra life through the core")
		for index in range(3):
			battle._add_drop("talisman",260 + index * 300,650)
			battle.state.drops[-1].talisman_id = Battle.TALISMANS.keys()[index]
		var hud := HUD.new()
		root.add_child(hud)
		await capture(view,hud,battle,"01-hud-shields-treasures.png")
		var enemy: Dictionary = battle.state.fighters.filter(func(f): return f.team == 1)[0]
		battle._damage(players[1],1000,enemy.id,true,true,true)
		for tick in range(48): battle.step([{ "dx":0,"dy":0,"buttons":0 },{ "dx":0,"dy":0,"buttons":0 }])
		check(players[1].hp == 0 and players[1].respawn_ticks == 72 and players[1].shield_points == 0,"Core death consumes shield and enters a real respawn countdown")
		await capture(view,hud,battle,"02-revive-shield-exhausted.png")
		hud.queue_free()
		view.hide()
		var icons_view := IconView.new()
		root.add_child(icons_view)
		for airborne in [false,true]:
			icons_view.cards.clear()
			for index in range(6):
				var hero: String = ["nobunaga","oichi","tadakatsu"][index%3]
				var actor: Dictionary = battle._make_fighter(0,hero,0,0,120)
				actor.player_index = 0
				var kind: String = icons.keys()[index]
				actor.shield_kind = kind
				actor.shield_points = Battle.TALISMANS[kind].durability
				actor.face = -1 if airborne else 1
				actor.z = 42 if airborne else 0
				actor.action_tick = 12 if airborne else 0
				actor.qa_label = str(Battle.TALISMANS[kind].name)
				icons_view.cards.append(actor)
			var before := var_to_bytes(icons_view.cards)
			icons_view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(var_to_bytes(icons_view.cards) == before,"Icon rendering does not change equipment or fighter state")
			check(root.get_texture().get_image().save_png("res://../artifacts/native-v21/" + ("04-airborne-icons.png" if airborne else "03-function-icons.png")) == OK,"Function icon screenshot saved")
		icons_view.queue_free()
	view.queue_free()
	await process_frame
	print("RENDER ITEMS v21: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
