extends SceneTree

const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const Encounter = preload("res://core/stage04_encounter.gd")
const Data = preload("res://core/stage04_data.gd")
const Audio = preload("res://render/combat_audio.gd")
var folder := "res://../artifacts/nobunaga-combat-20261018/stage4-captures/"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := View.new()
	viewport.add_child(view)
	view._fx.muted = true
	var sim := Battle.new()
	sim.reset_campaign("normal",1,["nobunaga"],4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for section in 5:
		sim._enter_segment(section)
		var hero: Dictionary = sim.state.fighters[0]
		var checkpoint: int = [1,1,1,1,2][section]
		hero.x = float(sim._campaign.segments[section].encounters[checkpoint-1].end)-150
		sim._start_checkpoint(checkpoint)
		view.state = sim.get_state()
		view.camera_x = Battle.camera_left(view.state)
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(folder+"scene-%d.png"%section)==OK)
	for role in Data.ROLES:
		sim._enter_segment(4)
		sim.state.props.clear()
		sim.state.effects.clear()
		sim.state.fighters = sim.state.fighters.filter(func(f):return f.team==0)
		var enemy := Encounter.spawn(sim,{"role":role,"kind":"boss" if role in ["udono","kira","tominaga"] else ("archer" if role=="archer_kira" else ("gunner" if role=="gunner" else "soldier")),"x":800,"y":540},1)
		sim.state.fighters.append(enemy)
		sim.state.fighters[0].x = 450
		sim.state.fighters[0].y = 540
		for action in ["idle","walk"]+Data.HITS.keys().filter(func(a): return a.begins_with(role+"_") and a!="kira_volley"):
			enemy.action = action if action!="walk" else "idle"
			enemy.moving = action=="walk"
			enemy.action_tick = int(Data.attack_timing(enemy)[0]) if Data.HITS.has(action) else 12
			sim.state.effects.clear()
			if Data.HITS.has(action):
				enemy.mikawa_events=[]
				if action == "kira_command": enemy.mikawa_roster=[]
				Encounter.attack(sim,enemy)
				for effect in sim.state.effects: effect.life = maxi(1,int(effect.life)-12)
			view.state = sim.get_state()
			view.camera_x = 0
			view._moving[enemy.id] = action=="walk"
			view._walk_ticks[enemy.id] = 12.0
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			assert(viewport.get_texture().get_image().save_png(folder+role+"-"+action+".png")==OK)
	for state_index in 3:
		sim.state.props.clear();sim.state.effects.clear()
		for index in 4:
			sim.state.props.append({"id":900+index,"kind":"fence","mikawa_asset":["kflag","uflag","fence","cheval"][index],"x":180+index*300,"y":560,"hp":100 if state_index==0 else (50 if state_index==1 else 0),"max_hp":100,"width":270,"depth":100,"drop":"","broken":state_index==2,"broken_tick":int(sim.state.tick)-48})
		view.state=sim.get_state();view.state.fighters=[];view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(folder+"props-%d.png"%state_index)==OK)
	viewport.free()
	var app := preload("res://main.gd").new()
	app.testing=true
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.sim.reset_campaign("normal",1,["nobunaga"],4)
	app._activate()
	app.sim._enter_segment(4)
	app.sim.state.fighters[0].x=float(app.sim._campaign.segments[4].encounters[2].end)-1100
	app.sim._start_checkpoint(2)
	app.sim.state.intro.clear()
	app._update_view()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+"full-game.png")==OK)
	app.queue_free()
	await process_frame
	print("STAGE04 CAPTURES PASS")
	quit()
