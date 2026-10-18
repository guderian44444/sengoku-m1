extends SceneTree

const Main = preload("res://main.gd")
const S5 = preload("res://core/stage05_encounter.gd")
const Data = preload("res://core/stage05_data.gd")

class App extends Main:
	var measured_boss := 0
	var live_troops := false
	var emitted: Array = []
	func _save_characters(_manual: bool = false) -> Error: return OK
	func _set_game_focus(_focused: bool) -> void: _has_focus=true
	func _input_frame() -> Dictionary: return {"dx":0,"dy":0,"buttons":0}
	func _events(events: Array) -> void:
		for event in events: emitted.append(event.duplicate(true))
		super._events(events)
	func _physics_process(delta: float) -> void:
		if active:
			for f in sim.state.fighters:
				if f.team==0: f.hp=f.max_hp
				elif f.action=="idle" and (not live_troops or f.kind=="boss"): f.cooldown=999999
		super._physics_process(delta)

var output := ""
var app: App
var report := {"renderer":"","gpu":"","audio":"","phases":[],"captures":[]}

func _initialize() -> void: run.call_deferred()

func snapshot() -> Dictionary:
	return {"art":app.view._stage05_art.metrics.duplicate(),"cache_bytes":app.view._stage05_art.cached_bytes,"textures":app.view._stage05_art.textures.size(),"frozen_samples":app.view._frozen_samples.size(),"fighters":app.sim.state.fighters.size(),"effects":app.sim.state.effects.size(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"scene_preload_ms":app.view._stage05_art.last_prepare_ms,"entry_seq":app.sim.state.ikki.get("entry_seq",0),"pending":app.sim.state.ikki.get("pending",[]).size(),"banners":S5.banners(app.sim)}

func measure(label: String, ticks: int, capture_tick: int = -1) -> void:
	var before := snapshot()
	var event_start := app.emitted.size()
	var tick_start: int=app.sim.state.tick
	var time_start := Time.get_ticks_usec()
	var previous := time_start
	var frames: Array = []
	var cpu: Array = []
	var captured := false
	var pending_peak := int(before.pending)
	var fighters_peak := int(before.fighters)
	while int(app.sim.state.tick)-tick_start<ticks:
		await process_frame
		await RenderingServer.frame_post_draw
		pending_peak=maxi(pending_peak,app.sim.state.ikki.pending.size())
		fighters_peak=maxi(fighters_peak,app.sim.state.fighters.size())
		var now := Time.get_ticks_usec()
		frames.append(float(now-previous)/1000);previous=now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		if capture_tick>=0 and not captured and int(app.sim.state.tick)-tick_start>=capture_tick:
			captured=true
			var path := output.path_join(label+".png")
			assert(root.get_texture().get_image().save_png(path)==OK)
			report.captures.append(path)
			previous=Time.get_ticks_usec() # Exclude PNG encoding from the next frame.
	var after := snapshot()
	var boss: Dictionary=app.sim._fighter(app.measured_boss)
	var delta := {}
	for key in before.art: delta[key]=after.art[key]-before.art[key]
	var events: Array=app.emitted.slice(event_start)
	var counts := {}
	var unique := {}
	for event in events:
		var key: String=event.get("cue",event.type)
		counts[key]=int(counts.get(key,0))+1
		unique[event.id]=true
	frames.sort();cpu.sort()
	var phase := {"label":label,"sim_ticks":int(app.sim.state.tick)-tick_start,"wall_ms":float(Time.get_ticks_usec()-time_start)/1000,"frames":frames.size(),"frame_median_ms":frames[frames.size()/2],"frame_p95_ms":frames[mini(frames.size()-1,int(frames.size()*.95))],"frame_max_ms":frames[-1],"process_p95_ms":cpu[mini(cpu.size()-1,int(cpu.size()*.95))],"before":before,"after":after,"art_delta":delta,"events":counts,"duplicate_event_ids":events.size()-unique.size()}
	phase.action_hits=boss.get("s05_events",[]).duplicate()
	phase.pending=app.sim.state.ikki.pending.size()
	phase.pending_peak=pending_peak;phase.fighters_peak=fighters_peak
	phase.admissions=int(after.entry_seq)-int(before.entry_seq)
	phase.summon_count=app.sim.state.ikki.summon_count
	report.phases.append(phase)
	FileAccess.open(output.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PROFILE_PHASE ",JSON.stringify(phase))

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	assert(not output.is_empty() and DisplayServer.get_name()!="headless")
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	root.size=Vector2i(1280,720)
	report.renderer=RenderingServer.get_current_rendering_method()
	report.gpu=RenderingServer.get_video_adapter_name()
	report.audio=AudioServer.get_driver_name()
	app=App.new();root.add_child(app)
	app.live_troops="--soak-all" in OS.get_cmdline_user_args()
	app.set_physics_process(false)
	app.view._stage05_art.use_atlas="--legacy" not in OS.get_cmdline_user_args()
	report.derivatives=app.view._stage05_art.use_atlas
	await process_frame
	app.sim.reset_campaign("normal",1,["nobunaga"],5)
	app._activate();app.set_physics_process(false)
	for role in ["kusei","hachiya","natsume"]:
		var section: int={"kusei":4,"hachiya":1,"natsume":3}[role]
		app.sim._enter_segment(section);app.sim._start_checkpoint(app.sim.state.stage.checkpoint_total-1)
		app.sim.state.intro.clear()
		var boss: Dictionary=app.sim.state.fighters.filter(func(f):return f.get("s05_role","")==role)[0]
		var hero: Dictionary=app.sim.state.fighters[0]
		var left: float=app.sim.state.stage.encounter_start
		boss.entering=false;boss.x=left+850;boss.y=485;boss.cooldown=999999
		hero.x=left+570;hero.y=515
		app.measured_boss=boss.id;app._camera_scene=-1
		app.view._stage05_art.profiling=true
		app._update_view();app.set_physics_process(true)
		await measure(role+"-baseline",60)
		var moves: Array={"kusei":["stomp","slash","guard","summon"],"hachiya":["rapid","return","sweep"],"natsume":["ground","diagonal","sweep"]}[role]
		for round_index in 2:
			for move in moves:
				var action: String="s05_"+role+"_"+move
				boss.x=left+850;boss.y=485;boss.z=0;boss.vz=0;boss.freeze=0;boss.stun=0
				hero.x=left+690;hero.y=485;hero.z=0;hero.vz=0;hero.freeze=0;hero.stun=0;hero.action="idle"
				S5.start(app.sim,boss,action,hero)
				app._events(app.sim.state.events)
				await measure(role+"-"+move+"-"+("cold" if round_index==0 else "repeat"),int(ceil(Data.duration(role,action)*.06))+2,39 if role=="kusei" and move=="stomp" else -1)
				await measure(role+"-"+move+"-after-"+str(round_index),30)
		var soak_all := "--soak-all" in OS.get_cmdline_user_args()
		if soak_all or (role=="kusei" and "--soak" in OS.get_cmdline_user_args()):
			var soak_moves: Array=moves if soak_all else ["stomp","slash","summon"]
			var cycle_ticks := 0
			for move in soak_moves: cycle_ticks+=int(ceil(Data.duration(role,"s05_"+role+"_"+move)*.06))+2
			var cycles := ceili(7200.0/cycle_ticks) if soak_all else 12
			for cycle in cycles:
				if soak_all:
					var regular: Array=app.sim.state.fighters.filter(func(f):return f.team==1 and f.hp>0 and f.kind!="boss" and not f.get("s05_elite",false) and not f.get("s05_weak",false))
					assert(not regular.is_empty() and S5.banners(app.sim)>0,"Live flags retain a garrison during the soak")
					regular[0].hp=0;regular[0].damage_tick=app.sim.state.tick
				for f in app.sim.state.fighters:
					if f.get("s05_elite",false) and f.hp>0: f.hp=0;f.damage_tick=app.sim.state.tick
				for move in soak_moves:
					var action: String="s05_"+role+"_"+move
					boss.freeze=0;boss.stun=0;boss.x=left+850;boss.y=485
					hero.x=left+690;hero.y=485;hero.z=0;hero.vz=0;hero.freeze=0;hero.stun=0;hero.action="idle"
					S5.start(app.sim,boss,action,hero)
					app._events(app.sim.state.events)
					await measure(("soak-"+role+"-%02d-%s" if soak_all else "soak-%02d-%s")%[cycle,move],int(ceil(Data.duration(role,action)*.06))+2)
		app.set_physics_process(false)
	report.complete=true
	FileAccess.open(output.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STAGE05_NATIVE_PROFILE_COMPLETE ",output)
	app.queue_free();await process_frame;quit()
