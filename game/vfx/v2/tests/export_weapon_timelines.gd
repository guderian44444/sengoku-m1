extends SceneTree
const Emitter=preload("res://vfx/v2/effect_emitter.gd")
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	var output:="user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var fx=Emitter.new();root.add_child(fx);assert(fx.configure())
	var frames:=[];var origins:={}
	for tick in range(480):
		var kind:="";var origin:=Vector2.ZERO;var face:=1;var distance:=0.0
		if tick==0:kind="hero";origin=Vector2(300,280)
		if tick==120:kind="enemy";origin=Vector2(930,280);face=-1
		if tick>=240 and tick<=267 and (tick-240)%3==0:kind="enemy";origin=Vector2(100+(tick-240)/3*42,520);distance=.35
		if tick==360:kind="hero";origin=Vector2(970,520);face=-1;distance=1
		if not kind.is_empty():
			var id:="shot:"+str(tick);origins[id]=[origin.x,origin.y]
			fx.trigger(id,kind+"_matchlock",{"simulation_tick":tick,"confirmed_shot":true,"shot_event_id":id,"face":face,"distance":distance,"variant":0})
		for id: String in fx.instances.keys():fx.advance(id,tick)
		if tick%2==0:frames.append({"tick":tick,"instances":fx.instances.duplicate(true),"origins":origins.duplicate(true)})
	FileAccess.open(output.path_join("gun-timeline.json"),FileAccess.WRITE).store_string(JSON.stringify({"frames":frames}))
	fx.reset_scene();frames=[]
	var names:=["neutral_slash_arc","thrust_cone","arrow_trail","throwing_blade_trail","blunt_impact","guard_sparks","slash_hit","dash_dust"]
	for tick in range(480):
		var index:=tick/60
		if tick%60==0:
			fx.reset_scene()
			fx.trigger("case",names[index],{"simulation_tick":tick,"confirmed_contact":true,"contact_event_id":str(index),"projectile_spawn_id":str(index)})
		if tick%60==55:fx.cancel("case")
		fx.advance("case",tick)
		if tick%2==0:frames.append({"tick":tick,"case_index":index,"instances":fx.instances.duplicate(true)})
	FileAccess.open(output.path_join("neutral-timeline.json"),FileAccess.WRITE).store_string(JSON.stringify({"frames":frames}))
	fx.queue_free();await process_frame;print("PASS: two 8-second weapon timelines exported from Emitter");quit()
