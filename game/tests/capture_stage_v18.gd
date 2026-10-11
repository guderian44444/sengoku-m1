extends SceneTree

const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")

class StageView extends View:
	var caption: String = ""
	var inventory := false
	func _draw() -> void:
		if not inventory:
			super._draw()
		else:
			draw_rect(Rect2(0,0,1280,720),Color("283b40"))
			var kinds: Array = _stage_art.props.keys()
			for i in range(kinds.size()):
				var x := 100.0 + (i % 6)*204.0
				var y := 275.0 + floorf(i / 6.0)*230.0
				_draw_prop({"kind":kinds[i],"x":x,"y":y,"width":100,"hp":100,"max_hp":100,"broken":false})
				draw_string(ThemeDB.fallback_font,Vector2(x-60,y+28),str(kinds[i]),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
			for i in range(4):
				_draw_drop({"kind":"food","food_id":["rice","fish","dango","peach"][i],"x":200+i*280,"y":636})
			draw_string(ThemeDB.fallback_font,Vector2(45,692),"Four distinct, enlarged food pickups / original RGBA pixels / no old sprite enlargement",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
		draw_rect(Rect2(0,0,1280,66),Color(.05,.08,.08,.92))
		draw_string(ThemeDB.fallback_font,Vector2(26,42),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("f3dfad"))

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/native-v18/environment")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280,720)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := StageView.new()
	viewport.add_child(view)
	var sim := Battle.new()
	sim.reset_campaign("normal",1,["nobunaga"])
	var report := {"version":"0.18","capture":"Native Godot renderer with actual stage-01.json and runtime art; staged positions demonstrate environment, not a complete input-driven level playthrough.","registration_sha256":FileAccess.get_sha256("res://assets/v18/registration.json"),"regions":[],"checks":0}
	var board := Image.create(1280,1800,false,Image.FORMAT_RGBA8)
	for index in range(10):
		sim._enter_segment(index)
		sim.state.tick = 180+index*31
		sim.state.fighters[0].x = 280.0
		sim.state.fighters[0].y = 505.0
		sim.state.drops = [{"kind":"food","food_id":["rice","fish","dango","peach"][index%4],"x":665.0,"y":562.0}]
		if index == 9:
			sim.state.fighters.resize(1)
			var boss: Dictionary = sim._make_fighter(1,"boss",880,505,1400)
			boss.faction = "imagawa"
			boss.stage_boss = true
			boss.display_name = "松井宗信"
			boss.render_scale = 1.3
			sim.state.fighters.append(boss)
			assert(is_equal_approx(View.enemy_display_height(boss),155.0*1.3))
			for action in ["idle","walk","heavy_attack","boss_chain","boss_charge","boss_slam"]:
				var probe: Dictionary = boss.duplicate()
				probe.action = action
				probe.moving = action == "walk"
				probe.action_tick = 20
				var sample: Dictionary = view._fighter_animation(probe)
				var frame: Dictionary = view._art.enemy_frame("boss",int(sample.cell),"imagawa",str(sample.sheet))
				assert(sample.source == "v10" and float(frame.body_height) >= 201.5,"Existing high-resolution Imagawa boss source covers " + action)
		view.state = sim.state
		view.camera_x = 0
		view.caption = "%02d / 10  %s   ·   %s / %s" % [index+1,sim.state.stage.name,sim.state.stage.weather,sim.state.stage.music]
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var filename := "%02d-%s.png" % [index+1,sim.state.stage.theme]
		var rendered := viewport.get_texture().get_image()
		assert(rendered.save_png(output.path_join(filename)) == OK)
		rendered.resize(640,360,Image.INTERPOLATE_LANCZOS)
		board.blit_rect(rendered,Rect2i(0,0,640,360),Vector2i((index%2)*640,int(index/2)*360))
		var citizens: Array = view._npc_samples(3.0)
		if sim.state.stage.civilians == "none": assert(citizens.is_empty())
		for person in citizens: assert(person.kind in View.StageArt.civilian_kinds(str(sim.state.stage.civilians)))
		var bg: Dictionary = view._stage_art.background(str(sim.state.stage.theme))
		assert(not bg.is_empty())
		report.regions.append({"index":index,"name":sim.state.stage.name,"theme":sim.state.stage.theme,"background":bg.source,"weather":sim.state.stage.weather,"civilians":sim.state.stage.civilians,"file":filename})
		report.checks += 4
	assert(board.save_png(output.path_join("ten-regions.png")) == OK)
	view.inventory = true
	view.state = {"tick":60}
	view.caption = "v0.18 · foreground inventory / 12 props + 4 food pickups"
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(output.path_join("foreground-inventory.png")) == OK)
	view.inventory = false
	sim._enter_segment(5)
	sim.state.stage.go = true
	sim.state.stage.phase = "exit"
	sim.state.fighters.resize(1)
	sim.state.fighters[0].x = 820.0
	sim.state.fighters[0].y = 510.0
	for prop in sim.state.props:
		if prop.kind in ["fence","barricade"]:
			prop.hp = 0
			prop.broken = true
	view.state = sim.state
	view.camera_x = 480.0
	view.caption = "GO prompt · foreground follows camera 1:1 / distant scenery 0.12:1"
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(output.path_join("go-and-parallax.png")) == OK)
	var file := FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	file.close()
	print("PASS: 10 stage environments, civilian groups, 1.3x final boss, foreground inventory and GO native captures")
	quit()
