extends SceneTree

const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")
const HUD = preload("res://render/combat_hud.gd")
var checks := 0
var failures := 0

class ObservedView extends View:
	var health_bars: Dictionary = {}
	func _draw() -> void:
		health_bars.clear()
		super._draw()
	func _draw_enemy_health(fighter: Dictionary, rect: Rect2) -> void:
		health_bars[int(fighter.id)] = rect
		super._draw_enemy_health(fighter,rect)

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func actor(id: int, kind: String, x: float, y: float) -> Dictionary:
	return {"id":id,"kind":kind,"team":1,"faction":"imagawa","action":"idle","action_tick":0,"face":1,"z":0.0,"x":x,"y":y,"hp":65.0,"max_hp":100.0,"render_scale":1.0,"moving":false}

func capture(view: ObservedView, hud: Control, name: String) -> void:
	var before := var_to_bytes(view.state)
	hud.sync(view.state)
	view.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(var_to_bytes(view.state) == before,"Rendering leaves fighter health and authoritative state unchanged")
	for fighter in view.state.fighters:
		if fighter.team == 0: continue
		check(view.health_bars.has(fighter.id) == (fighter.hp > 0),"Dead actors hide health; living reactions retain it")
		if fighter.hp > 0: check(view.health_bars[fighter.id].size == Vector2(54,7),"Actual renderer uses a seven-pixel health bar")
	var output := ProjectSettings.globalize_path("res://../artifacts/enemy-health-ui-v34")
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"Native capture: "+name)

func run() -> void:
	root.size = Vector2i(1280,720)
	var frame := {"region":Rect2(0,0,120,220),"opaque_bounds":Rect2(10,20,100,170),"anchor":Vector2(40,200),"body_height":200.0}
	check(View.enemy_health_rect(frame,100) == Rect2(-27,-117,54,7),"Transparent margins do not lower the health bar onto the head")
	check(is_equal_approx(View.enemy_health_rect(frame,100,1,PI/2).end.y,-35),"Rotated reaction geometry keeps twenty pixels above the visible body")
	check(View.buff_rect(frame,100) == Rect2(-10,-128,20,24),"Existing buff placement is unchanged")
	frame.clip_polygon = PackedVector2Array([Vector2(25,5),Vector2(65,5),Vector2(65,180),Vector2(25,180)])
	check(is_equal_approx(View.enemy_health_rect(frame,100).end.y,-117.5),"Helmet clip silhouette takes priority over nominal height")
	var view := ObservedView.new()
	root.add_child(view)
	for kind in ["soldier","archer","commander","boss"]:
		for height_scale in [.8,1.0,1.3]:
			for action in ["idle","hurt","down","recovering"]:
				var enemy := actor(10,kind,300,530)
				enemy.render_scale = height_scale
				enemy.action = action
				enemy.action_tick = 24
				var sample: Dictionary = view._fighter_animation(enemy)
				var pose: Dictionary = view._art.enemy_frame(kind,int(sample.cell),"imagawa",str(sample.sheet))
				var height := View.enemy_display_height(enemy)
				var bar := View.enemy_health_rect(pose,height)
				check(bar.size.y == 7,"Bar thickness is independent of troop height or posture")
				var pixels: Rect2i = pose.texture.get_image().get_used_rect()
				var visible_top := (float(pixels.position.y)-float(pose.region.position.y)-float(pose.anchor.y))*height/float(pose.body_height)
				check(visible_top-bar.end.y >= 17.9,"Sprite gap %.2f: %s %s %.1f; used %s / region %s" % [visible_top-bar.end.y,kind,action,height_scale,pixels,pose.region])
	if DisplayServer.get_name() != "headless" and "--capture" in OS.get_cmdline_user_args():
		var battle := Battle.new()
		battle.reset_campaign("normal",1,["nobunaga"],1)
		battle.state.fighters = battle.state.fighters.filter(func(fighter): return fighter.team == 0)
		battle.state.fighters[0].x = 90.0
		battle.state.fighters[0].y = 625.0
		battle.state.stage.go = true
		battle.state.effects.clear()
		battle.state.props.clear()
		battle.state.tick = 180
		for index in range(5):
			var enemy := actor(index+10,["soldier","archer","soldier","commander","boss"][index],170+index*220,520)
			enemy.render_scale = [.85,1.0,1.15,1.0,1.3][index]
			enemy.hp = 100-index*15
			if index == 4:
				enemy.stage_boss = true
				enemy.display_name = "松井宗信"
			battle.state.fighters.append(enemy)
		view.state = battle.state
		var hud := HUD.new()
		root.add_child(hud)
		await capture(view,hud,"standing")
		var attacker: Dictionary = view.state.fighters[3]
		attacker.action = "spear_thrust"
		attacker.action_tick = 2
		await capture(view,hud,"windup")
		check(view.health_bars[attacker.id].end.y <= attacker.y-View.enemy_display_height(attacker)-30,"Health bar leaves the existing attack warning unobstructed")
		for index in range(5):
			var enemy: Dictionary = view.state.fighters[index+1]
			enemy.action = ["hurt","down","dead","recovering","down"][index]
			enemy.action_tick = 24
			if index == 2: enemy.hp = 0
		await capture(view,hud,"reactions")
		hud.queue_free()
	view.queue_free()
	await process_frame
	print("ENEMY HEALTH UI V34 %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
