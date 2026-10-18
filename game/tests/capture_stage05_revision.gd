extends SceneTree
const Main = preload("res://main.gd")
const S5 = preload("res://core/stage05_encounter.gd")
const Art = preload("res://render/stage05_art.gd")
const Data = preload("res://core/stage05_data.gd")

class App extends Main:
	func _save_characters(_manual: bool = false) -> Error: return OK
	func _set_game_focus(_focused: bool) -> void: _has_focus=true

var app: App
var output := ""
var records := []

func _initialize() -> void: run.call_deferred()

func capture(name: String) -> void:
	app._update_view()
	app.view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(name+".png")
	assert(root.get_texture().get_image().save_png(path)==OK)
	records.append({"file":name+".png","tick":app.sim.state.tick,"camera":app.view.camera_x})

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	assert(not output.is_empty() and DisplayServer.get_name()!="headless")
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	root.size=Vector2i(1280,720)
	app=App.new();root.add_child(app);app.set_physics_process(false);app.testing=true
	app.sim.reset_campaign("normal",1,["nobunaga"],5);app._activate();app.set_physics_process(false)
	var poses := [["kusei","stomp",39],["kusei","stomp",45],["kusei","stomp",255],["kusei","stomp",261],["kusei","slash",27],["kusei","slash",48],["kusei","slash",63],["kusei","guard",30],["kusei","summon",99],["hachiya","rapid",25],["hachiya","return",40],["hachiya","sweep",31],["natsume","ground",18],["natsume","diagonal",18],["natsume","sweep",18]]
	if "--motion-only" in OS.get_cmdline_user_args(): poses=[]
	for pose in poses:
		var role: String=pose[0]
		var section: int={"kusei":4,"hachiya":1,"natsume":3}[role]
		app.sim._enter_segment(section);app.sim._start_checkpoint(app.sim.state.stage.checkpoint_total-1)
		app.sim.state.intro.clear();app.sim.state.ikki.pending.clear()
		app.sim.state.props.clear() # Isolate the complete silhouette for same-pose visual comparison.
		app.sim.state.tick=3900
		var boss: Dictionary=app.sim._fighter(app.sim.state.ikki.boss)
		var hero: Dictionary=app.sim.state.fighters[0]
		var left: float=app.sim.state.stage.encounter_start
		boss.entering=false;boss.x=left+770;boss.y=490
		hero.x=left+440;hero.y=530
		S5.start(app.sim,boss,"s05_"+role+"_"+str(pose[1]),hero);boss.action_tick=pose[2]
		S5.attack(app.sim,boss)
		for mode in ["master","runtime"]:
			app.view._stage05_art=Art.new();app.view._stage05_art.use_atlas=mode=="runtime"
			app.view._frozen_samples.clear();app._camera_scene=-1
			await capture("%s-%s-%03d-%s"%[role,pose[1],pose[2],mode])
	if "--motion-only" in OS.get_cmdline_user_args():
		for move in ["ground","diagonal","sweep"]:
			app.sim._enter_segment(3);app.sim._start_checkpoint(2)
			app.sim.state.intro.clear();app.sim.state.ikki.pending.clear();app.sim.state.props.clear()
			var boss: Dictionary=app.sim._fighter(app.sim.state.ikki.boss)
			var hero: Dictionary=app.sim.state.fighters[0]
			boss.entering=false;boss.x=app.sim.state.stage.encounter_start+770;boss.y=490;boss.cooldown=0
			hero.x=boss.x-(110 if move=="sweep" else 210);hero.y=490;hero.invuln=999
			hero.z=45 if move=="diagonal" else 0;hero.vz=0
			S5.ai(app.sim,boss,hero)
			assert(boss.action=="s05_natsume_"+move)
			app.view._stage05_art=Art.new();app._camera_scene=-1
			for tick in ceili(Data.duration("natsume",boss.action)*.06)+1:
				if tick%3==0: await capture("natsume-motion-%s-%03d"%[move,tick])
				app.sim.step([{"dx":0,"dy":0,"buttons":0}])
	app.sim._enter_segment(0);app.sim._start_checkpoint(0)
	app.sim.state.intro.clear();app.sim.state.ikki.pending.clear();app.sim.state.props.clear()
	app.sim.state.fighters[0].x=460;app.sim.state.fighters[0].y=550
	var farmers := []
	for i in 4:
		var role := "sickle_farmer" if i%2==0 else "hunting_bow_farmer"
		var f := S5.spawn(app.sim,role,640+(i%2)*240,410+(i/2)*160)
		f.face=1 if i<2 else -1
		farmers.append(f);app.sim.state.fighters.append(f)
	app.view._stage05_art=Art.new();app._camera_scene=-1
	for frame in 6:
		app.sim.state.tick=600+frame*10
		for f in farmers:
			f.action="walk";f.action_tick=frame*10
		await capture("farmer-walk-%02d"%frame)
	for tick in [0,5,12,16,22,28,29,32,40]:
		app.sim.state.tick=900+tick;app.sim.state.effects.clear()
		for f in farmers:
			var action: String="s05_sickle_farmer_attack" if f.s05_role=="sickle_farmer" else "s05_hunting_bow_farmer_shot"
			S5.start(app.sim,f,action)
			if f.s05_role=="hunting_bow_farmer" and tick>=29:
				f.action_tick=29;S5.attack(app.sim,f)
			f.action_tick=tick;S5.attack(app.sim,f)
		if tick>29:
			for elapsed in tick-29: app.sim._tick_effects()
		await capture("farmer-attack-%02d"%tick)
	FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	print("STAGE05_REVISION_CAPTURE_PASS ",records.size()," native frames")
	app.queue_free();await process_frame;quit()
