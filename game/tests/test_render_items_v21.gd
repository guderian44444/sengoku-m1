extends SceneTree

const View = preload("res://render/battle_view.gd")
const HUD = preload("res://render/combat_hud.gd")
const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
var checks := 0
var failures := 0

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
	check(labels.lives == "命×3" and labels.score == "分 0012500" and labels.shield == "盾 75","HUD keeps current body in three lives and shows score and finite shield")
	check(HUD.player_status({"lives":0},0).lives == "命盡","Exhausted lives are explicit")
	check(HUD.player_status({"lives":2,"respawn_ticks":72},0).shield == "再起 1.2","Revival countdown uses simulation seconds")
	check(HUD.player_status({"extra_life_tick":100},100).extra,"Extra life flashes at award")
	check(not HUD.player_status({"extra_life_tick":100},116).extra,"Extra life flash has a readable off phase")
	check(not HUD.player_status({"extra_life_tick":100},220).extra,"Extra life hint expires after 120 ticks")
	check(not HUD.player_status({"extra_life_tick":100},99).extra,"Future snapshots do not flash early")
	check(HUD.player_rect(0).size == Vector2(392,104) and HUD.player_rect(1).end.x == 1264,"Weapon row adds twenty pixels within the two corner HUD panels")
	for kind in Battle.TALISMANS:
		var fighter := {"hp":120,"shield_points":1,"shield_kind":kind}
		check(View.shield_glow_color(fighter) == Color(Battle.TALISMANS[kind].color),kind + " keeps its colored glow until last shield point")
		fighter.shield_points = 0
		check(View.shield_glow_color(fighter).a == 0,kind + " glow ends exactly at zero")
		fighter.shield_points = 40
		fighter.hp = 0
		check(View.shield_glow_color(fighter).a == 0,kind + " does not outline a corpse")
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
	view.queue_free()
	await process_frame
	print("RENDER ITEMS v21: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
