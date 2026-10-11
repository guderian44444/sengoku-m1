extends SceneTree
const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")

func _initialize() -> void:
	_run.call_deferred()

func _actor(kind: String, action: String, tick: int, x: float, y: float = 565) -> Dictionary:
	return {"id":int(x),"kind":kind,"team":0 if kind in Battle.HEROES else 1,"player_index":0,"x":x,"y":y,"z":0,"vz":0,"face":1,"action":action,"action_tick":tick,"hp":100,"max_hp":100,"combo":1,"charge":tick,"heavy_combo":1,"boss_variant":"kusarigama"}

func _run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(not output.is_empty() and DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280,720)
	var view := View.new()
	root.add_child(view)
	var scenes := []
	for hero in Battle.HEROES:
		if hero not in ["nobunaga","oichi"]:
			for idle in range(6):
				scenes.append({"name":hero + "-idle-%d" % idle,"fighters":[_actor(hero,"idle",0,640)],"effects":[],"tick":idle * 12,"civilian_flee_tick":-1})
		for sprinting in [false,true]:
			var actors := []
			var distances := {}
			for i in range(6):
				var actor := _actor(hero,"idle",0,130 + i * 205)
				actor.moving = true
				actor.sprinting = sprinting
				distances[actor.id] = (148.0 if hero == "oichi" else 155.0) * (1.25 if sprinting else 0.82) * (i + 0.01) / 6
				actors.append(actor)
			scenes.append({"name":hero + ("-sprint" if sprinting else "-walk"),"fighters":actors,"effects":[],"distances":distances})
		for action in ["guard","hurt","launched","down","stunned","recovering"]:
			var actors := []
			for i in range(6):
				var actor := _actor(hero,action,i * (10 if action == "down" else (3 if action == "hurt" else 6)),130 + i * 205)
				if action == "launched":
					actor.vz = [9,5,0,-4,-8,-9][i]
					actor.z = [35,70,95,70,30,5][i]
				elif action == "guard": actor.guard_hit_tick = 9 if i == 4 else (3 if i == 5 else 0)
				actors.append(actor)
			scenes.append({"name":hero + "-" + action,"fighters":actors,"effects":[]})
		for combo in [1,2,3]:
			var actors := []
			for i in range(6):
				var actor := _actor(hero,"light",[0,2,4,6,11,16][i],125 + i * 205)
				actor.combo = combo
				actor.action_tick = Battle.hero_tick(hero,actor.action_tick) if i > 0 else 0
				actors.append(actor)
			scenes.append({"name":hero + "-light%d" % combo,"fighters":actors,"effects":[]})
		for action in ["heavy","upper_heavy","charged_upper","ground_slam","charged_slam","special"]:
			var actors := []
			for i in range(4):
				var action_tick: int = [2,12,24,34][i]
				if action in ["charged_upper","charged_slam"]: action_tick = [2,16,30,48][i]
				elif action == "special": action_tick = [15,68,120,192][i]
				var actor := _actor(hero,action,action_tick if action == "special" else Battle.hero_tick(hero,action_tick),150 + i * 300)
				actors.append(actor)
			scenes.append({"name":hero + "-" + action,"fighters":actors,"effects":[]})
	for moment in ["street","escape","empty"]:
		var battle := Battle.new()
		var tick := 0 if moment == "street" else (160 if moment == "escape" else 2400)
		scenes.append({"name":moment,"fighters":[],"effects":[],"tick":tick,"props":battle.state.props,"wet_zones":battle.state.wet_zones,"civilian_flee_tick":60 if moment != "street" else -1})
	var burning := _actor("soldier","hurt",6,420)
	burning.burn = 90
	var frozen := _actor("commander","idle",0,1040)
	frozen.freeze = 90
	scenes.append({"name":"painted-elements","fighters":[_actor("nobunaga","special",68,200),burning,_actor("oichi","special",68,790),frozen],"effects":[{"type":"damage","x":430,"y":535,"amount":32,"life":30,"max_life":40}]})
	var arrow_effects := []
	for i in range(5):
		arrow_effects.append({"type":"projectile","weapon":"arrow","arcing":true,"x":230 + i * 200,"y":560,"z":[85,180,230,175,45][i],"vx":8,"vy":0,"vz":[9,5,0,-5,-9][i],"life":40,"max_life":60})
	scenes.append({"name":"arrow-tangent","fighters":[],"effects":arrow_effects})
	scenes.append({"name":"landing-water-dust-debris","fighters":[],"effects":[{"type":"landing","x":300,"y":540,"wet":true,"life":12,"max_life":22},{"type":"landing","x":650,"y":540,"wet":false,"life":12,"max_life":22},{"type":"debris","x":950,"y":540,"life":12,"max_life":22}],"wet_zones":[{"x":300,"y":540,"width":260,"depth":110}]})
	for damage in range(3):
		var props := []
		var kinds := ["stall","cart","jar","basket","crate"]
		for i in range(5):
			props.append({"id":100 + i,"kind":kinds[i],"x":150 + i * 240,"y":565,"hp":100 if damage == 0 else (40 if damage == 1 else 0),"max_hp":100,"broken":damage == 2,"width":90,"depth":35})
		scenes.append({"name":"props-%d" % damage,"fighters":[],"effects":[],"props":props})
	for faction in Battle.FACTIONS:
		var variant: String = Battle.FACTIONS[faction].boss
		for attack in range(3):
			var actors := []
			var action: String = Battle.BOSS_PROFILES[variant].actions[attack]
			for i in range(6):
				var actor := _actor("boss",action,0,140 + i * 205)
				actor.faction = faction
				actor.boss_variant = variant
				actor.attack_variant = attack
				var timing: Array = Battle.enemy_timing(actor)
				actor.action_tick = floori(float(timing[0]) * i / 3.0) if i < 3 else int(timing[0]) + floori(float(timing[1] - timing[0]) * (i - 3) / 3.0)
				actors.append(actor)
			scenes.append({"name":"boss-" + faction + "-" + action,"fighters":actors,"effects":[]})
	for faction in Battle.FACTIONS:
		for variation in range(3):
			var actors := []
			for index in range(5):
				var kind: String = ["soldier","flag","commander","archer","gunner"][index]
				var attacks: Array = ["bow_shot"] if kind == "archer" else (["gun_shot"] if kind == "gunner" else Battle.ENEMY_ATTACKS[kind])
				var actor := _actor(kind,attacks[mini(variation,attacks.size() - 1)],0,125 + index * 250)
				actor.faction = faction
				actor.attack_variant = variation if index < 3 else 0
				actor.action_tick = int(Battle.enemy_timing(actor)[0])
				actors.append(actor)
			scenes.append({"name":"troops-" + faction + "-%d" % variation,"fighters":actors,"effects":[],"tick":2400})
	for scene in scenes:
		view.state = {"tick":scene.get("tick",120),"fighters":scene.fighters,"effects":scene.effects,"drops":[],"props":scene.get("props",[]),"wet_zones":scene.get("wet_zones",[]),"civilian_flee_tick":scene.get("civilian_flee_tick",0),"civilian_flee_x":640}
		view._positions.clear()
		view._frozen_samples.clear()
		view._walk_distance = scene.get("distances",{}).duplicate()
		view._motion_tick = int(view.state.tick)
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(scene.name + ".png")) == OK)
	var manifest := FileAccess.open(output.path_join("runtime-registration.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify(view._art.expanded_registration))
	manifest.close()
	print("PASS: native v10 captured hero reaction/combo sequences, finite crowd, props, painted elements and tangent arrows")
	view.queue_free()
	quit()
