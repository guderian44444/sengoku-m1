extends SceneTree
const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")
const Frames = preload("res://render/frame_animation.gd")

func _initialize() -> void:
	_run.call_deferred()

func actor(kind: String, action: String, tick: int, x: float, face: int = 1, faction: String = "mori") -> Dictionary:
	return {"id":int(x),"kind":kind,"team":0 if kind in Battle.HEROES else 1,"player_index":0 if kind == "nobunaga" else 1,"x":x,"y":570,"z":0,"vz":0,"face":face,"action":action,"action_tick":tick,"hp":0 if action == "defeated" else 100,"max_hp":100,"combo":3,"heavy_combo":1,"faction":faction,"boss_variant":Battle.FACTIONS[faction].boss}

func _run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var view := View.new()
	root.add_child(view)
	var scenes := []
	for face in [1,-1]:
		for action in ["light","heavy","hurt","defeated"]:
			for part in range(2):
				var fighters := []
				for i in range(4):
					var tick: int = [0,2,3,5,6,9,13,17][part * 4 + i] if action == "light" else (part * 4 + i) * (5 if action == "heavy" else 4)
					fighters.append(actor("oichi",action,tick,170 + i * 310,face))
				scenes.append({"name":"oichi-%s-%s-%d" % [action,"right" if face > 0 else "left",part],"fighters":fighters})
	for faction in Battle.FACTIONS:
		for action in ["hurt","defeated"]:
			var fighters := []
			for i in range(6): fighters.append(actor(["soldier","flag","commander","archer","gunner","boss"][i],action,12 if action == "hurt" else 60,100 + i * 215,1,faction))
			scenes.append({"name":faction + "-" + action,"fighters":fighters})
		var walkers := []
		for i in range(6):
			var walker := actor(["soldier","flag","commander","archer","gunner","boss"][i],"retreat",0,100 + i * 215,1,faction)
			walker.moving = true
			walkers.append(walker)
			view._walk_distance[walker.id] = 42.0
		scenes.append({"name":faction + "-movement","fighters":walkers})
		for phase in ["windup","impact"]:
			var attackers := []
			for i in range(6):
				var attacker := actor(["soldier","flag","commander","archer","gunner","boss"][i],"idle",0,100 + i * 215,1,faction)
				attacker.action = Frames.primary_enemy_action(attacker)
				attacker.action_tick = Battle.enemy_timing(attacker)[0] - (8 if phase == "windup" else 0)
				attackers.append(attacker)
			scenes.append({"name":faction + "-attack-" + phase,"fighters":attackers})
	for action in ["light","heavy","rising","ground_slam","charged_upper","charged_slam","air_light","special","hurt","defeated"]:
		var fighters := []
		for i in range(6): fighters.append(actor(Battle.HEROES[i],action,60 if action == "defeated" else (6 if action == "light" else 14),100 + i * 215))
		scenes.append({"name":"heroes-" + action,"fighters":fighters})
	scenes.append({"name":"coop","fighters":[actor("nobunaga","heavy",18,380),actor("oichi","light",6,780),actor("soldier","hurt",12,900),actor("archer","defeated",60,1120)]})
	for scene in scenes:
		view.state = {"tick":300,"fighters":scene.fighters,"effects":[],"drops":[],"props":[],"civilian_flee_tick":0}
		view._motion_tick = 300
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(scene.name + ".png")) == OK)
	print("PASS: v11 actual renderer captures saved: ",scenes.size())
	view.queue_free()
	quit()
