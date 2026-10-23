extends SceneTree
const Main=preload("res://main.gd")
const Stage=preload("res://core/stage07_10_encounter.gd")
const Wire=preload("res://core/wire.gd")
class App extends Main:
	func _save_characters(_manual: bool=false) -> Error: return OK
	func _set_game_focus(_focused: bool) -> void: _has_focus=true
var app: App
var output := ""
var records := []
func _initialize() -> void: run.call_deferred()
func capture(name: String) -> void:
	app.view._frozen_samples.clear();app._camera_scene=-1;app._update_view();app.view.queue_redraw()
	assert(Wire.valid_snapshot(app.sim.state),"Captured scene remains a valid network snapshot")
	await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK)
	records.append(name)
func setup(chapter: int) -> void:
	app.audio.stop_speech();app.sim.reset_campaign("normal",1,["nobunaga"],chapter)
	app.sim.state.intro.clear();app.sim.state.expedition.pending=[]
	app.sim.state.fighters=app.sim.state.fighters.filter(func(f):return f.team==0)
	app.sim.state.fighters[0].x=280.0;app.sim.state.fighters[0].y=510.0
	app._activate();app.set_physics_process(false)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	assert(not output.is_empty() and DisplayServer.get_name()!="headless")
	assert(DirAccess.make_dir_recursive_absolute(output)==OK);root.size=Vector2i(1280,720)
	app=App.new();root.add_child(app);app.testing=true;app.set_physics_process(false)
	for chapter in [7,8,9,10]:
		for region in 5:
			setup(chapter);app.sim._enter_segment(region)
			await capture("region-%02d-%d"%[chapter,region])
	for chapter in [7,9,10]:
		setup(chapter);app.sim.state.props=[]
		for i in 5:
			var troop := Stage.spawn(app.sim,Stage.Data.SOLDIERS[i],510+i*145,445+(i%2)*100)
			troop.entering=false;app.sim.state.fighters.append(troop)
		for state in ["idle","walk","attack","hurt","down","recovering"]:
			for f in app.sim.state.fighters:
				if f.team==0: continue
				f.action="idle" if state in ["idle","walk"] else state;f.moving=state=="walk";f.action_tick=8
				if state=="attack":
					f.action={"archer":"bow_shot","gunner":"gun_shot","raider":"commander_cut"}.get(f.expedition_role,"spear_thrust")
					f.action_tick=Main.Battle.enemy_timing(f)[0]
				if state in ["down","recovering"]: f.action_tick=30
				app.view._walk_ticks[f.id]=21
			app.sim.state.tick+=30
			await capture("troops-%02d-%s"%[chapter,state])
	setup(7)
	var hero: Dictionary=app.sim.state.fighters[0];hero.x=650;hero.y=480;hero.invuln=0
	var enemy := Stage.spawn(app.sim,"spear",720,480);enemy.entering=false;app.sim.state.fighters.append(enemy)
	Stage.hazard(app.sim,"rock",Vector2(690,480),80,40,48,24)
	for frame in 72:
		app.sim.state.tick+=1
		if frame in [0,20,42,48,65]: await capture("rockfall-%02d"%frame)
		Stage.tick_hazards(app.sim)
	setup(9);app.sim.state.props=app.sim.state.props.filter(func(p):return p.expedition_asset=="barricade")
	var guard := Stage.spawn(app.sim,"spear",900,480);guard.entering=false;app.sim.state.fighters.append(guard)
	for frame in 180:
		app.sim.state.tick+=1;Stage.evacuate_civilians(app.sim)
		if frame in [0,30,90,150]: await capture("civilian-flee-%03d"%frame)
	for role in Stage.Data.BOSSES:
		var spec: Dictionary=Stage.Data.BOSSES[role]
		setup(int(spec.stage))
		app.sim._enter_segment(4 if role in ["inaba","tatsuoki","iwanari","yoshikage"] else 2);app.sim._start_checkpoint(1)
		app._physics_process(1.0/60);await capture("intro-"+role)
		for action in spec.actions:
			setup(int(spec.stage));app.sim.state.props=[]
			var move_hero: Dictionary=app.sim.state.fighters[0];move_hero.x=420;move_hero.y=480;move_hero.invuln=0
			var boss := Stage.spawn(app.sim,role,800,480);boss.entering=false;boss.face=-1
			app.sim.state.fighters.append(boss)
			var move: Dictionary=Stage.Data.ACTIONS[action]
			if not Stage.Data.ranged(move): move_hero.x=640
			Stage.start(app.sim,boss,action,move_hero)
			var landing := -1
			for tick in int(move.duration)+65:
				app.sim.state.tick+=1;boss.action_tick=tick+1
				Stage.attack(app.sim,boss);Stage.tick_hazards(app.sim)
				if tick+1==int(move.hits[0])+8: await capture("move-"+action+"-release")
				if landing<0 and not app.sim.state.expedition.hazards.is_empty():
					landing=tick+int(app.sim.state.expedition.hazards[0].warning)+3
				if tick==landing: await capture("move-"+action+"-impact")
	for chapter in [7,8,9,10]:
		setup(chapter);app.sim.state.props=[]
		var shooter := Stage.spawn(app.sim,"gunner",950,480);shooter.entering=false;shooter.cooldown=0
		app.sim.state.fighters.append(shooter);app.sim._enemy_input(shooter)
		shooter.action_tick=int(Main.Battle.enemy_timing(shooter)[0]);app.sim._tick_enemy_attack(shooter)
		await capture("gunner-%02d-aim"%chapter)
		for tick in 9: Stage.tick_hazards(app.sim)
		await capture("gunner-%02d-shot"%chapter)
	var groups := {"regions":records.filter(func(n):return n.begins_with("region-")),"stage07":records.filter(func(n):return n.begins_with("move-s07")),"stage08":records.filter(func(n):return n.begins_with("move-s08")),"stage09":records.filter(func(n):return n.begins_with("move-s09")),"stage10":records.filter(func(n):return n.begins_with("move-s10")),"gunners":records.filter(func(n):return n.begins_with("gunner-"))}
	for group in groups:
		var names: Array=groups[group]
		var sheet := Image.create(1600,180*ceili(names.size()/5.0),false,Image.FORMAT_RGBA8)
		for i in names.size():
			var frame := Image.load_from_file(output.path_join(names[i]+".png"));frame.resize(320,180,Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(frame,Rect2i(0,0,320,180),Vector2i((i%5)*320,(i/5)*180))
		assert(sheet.save_png(output.path_join("overview-"+group+".png"))==OK)
	app.audio.stop_speech();FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	app.queue_free();await process_frame;print("FEEDBACK_NATIVE_PASS ",records.size()," frames");quit()
