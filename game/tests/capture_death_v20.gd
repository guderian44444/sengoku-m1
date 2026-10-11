extends SceneTree

const Battle = preload("res://core/battle.gd")
const BattleView = preload("res://render/battle_view.gd")
const CombatHUD = preload("res://render/combat_hud.gd")
var output := ""
var report := {"purpose":"Native current Battle/BattleView/CombatHUD staged late-checkpoint deaths, including real damage and settling; not an input-driven playthrough.","captures":[]}

class ObservedView extends BattleView:
	var rendered: Dictionary = {}
	func _draw_art_fighter(fighter: Dictionary, origin: Vector2) -> bool:
		var sample := _fighter_animation(fighter)
		rendered[int(fighter.id)] = {"action":fighter.action,"source":sample.source,"sheet":sample.sheet,"frame":sample.frame,"count":sample.count,"screen_x":origin.x,"screen_y":origin.y}
		return super._draw_art_fighter(fighter,origin)

func _initialize() -> void: run.call_deferred()

func prepare(heroes: Array) -> RefCounted:
	var battle := Battle.new()
	battle.reset_campaign("normal",heroes.size(),heroes)
	battle._enter_segment(6)
	battle._start_checkpoint(1)
	battle.state.fighters = battle.state.fighters.filter(func(f):return f.team == 0)
	battle.state.intro = {}
	battle.state.tick = 1900
	for player in battle.state.fighters:
		player.x = 2660.0 if heroes.size() == 1 else 2500.0 + 300.0 * player.player_index
		player.y = 608.0
		player.face = 1 if player.player_index == 0 else -1
		player.lives = 1
		assert(battle._damage(player,1000,0,false,true,true))
	for tick in range(90): battle.step([])
	assert(battle.state.phase == "lost")
	assert(battle.state.effects.is_empty(), "Hit sparks and damage numbers must expire after defeat.")
	assert(Battle.camera_left(battle.state) > 1280.0, "All-dead party must retain the late-section camera.")
	for player in battle.state.fighters:
		assert(player.hp == 0 and player.action == "defeated")
		assert(player.action_tick >= 24 and player.z == 0 and player.vz == 0)
	return battle

func capture(battle: RefCounted, view: ObservedView, hud: Control, filename: String) -> void:
	var before: Dictionary = battle.state.duplicate(true)
	view.state = battle.state
	view.camera_x = Battle.camera_left(battle.state)
	view.rendered.clear()
	view.queue_redraw()
	hud.sync(battle.state)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(battle.state == before, "Rendering must not mutate authoritative state.")
	var players := []
	for player in battle.state.fighters:
		assert(view.rendered.has(int(player.id)), "Zero-HP player was skipped: " + str(player.kind))
		var shown: Dictionary = view.rendered[int(player.id)]
		assert(shown.action in ["defeated","dead"])
		assert("down" in shown.sheet or "death" in shown.sheet)
		assert(shown.frame == shown.count - 1, "Death must hold its final prone drawing.")
		assert(shown.screen_x > 200 and shown.screen_x < 1080)
		players.append({"hero":player.kind,"world_action":player.action,"world_hp":player.hp,"world_x":player.x,"rendered":shown})
	assert(root.get_texture().get_image().save_png(output.path_join(filename)) == OK)
	report.captures.append({"file":filename,"camera_x":view.camera_x,"scene":7,"checkpoint":2,"phase":battle.state.phase,"world_unchanged":battle.state == before,"players":players})

func run() -> void:
	assert(DisplayServer.get_name() != "headless", "Use --windowed for native image evidence.")
	output = ProjectSettings.globalize_path("res://../artifacts/native-v20/death")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280,720)
	var view := ObservedView.new()
	root.add_child(view)
	var hud := CombatHUD.new()
	root.add_child(hud)
	await process_frame
	for hero in ["nobunaga","oichi","tadakatsu"]:
		var battle: RefCounted = prepare([hero])
		await capture(battle,view,hud,"dead-" + hero + ".png")
	var pair: RefCounted = prepare(["nobunaga","oichi"])
	await capture(pair,view,hud,"dead-two-players.png")
	pair.state.fighters[0].action = "hurt"
	pair.state.fighters[1].action = "idle"
	await capture(pair,view,hud,"zero-hp-transient-hurt-idle.png")
	var file := FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report,"\t") + "\n")
	file.close()
	view.queue_free()
	hud.queue_free()
	await process_frame
	print("PASS death_v20: three solo and two-player late deaths stay in camera and hold final prone art; zero-HP hurt/idle snapshots draw without changing world.")
	quit()
