extends SceneTree

const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")

func _initialize() -> void:
	_run.call_deferred()

func _fighter(kind: String, action: String, tick: int, x: float, y: float = 570) -> Dictionary:
	return {"id":int(x),"team":0 if kind in ["nobunaga","oichi"] else 1,"player_index":0,"kind":kind,"x":x,"y":y,"z":0.0,"face":1,"hp":100,"max_hp":100,"action":action,"action_tick":tick,"charge":tick,"combo":2,"heavy_combo":1}

func _run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(not output.is_empty() and DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280,720)
	var view := View.new()
	root.add_child(view)
	assert(view._art.enemies.size() == 6 and view._art.has_techniques("nobunaga"))
	var manifest := FileAccess.open(output.get_base_dir().path_join("runtime-registration.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify(view._art.combat_registration,"\t"))
	manifest.close()
	var scenes := []
	for kind in ["soldier","flag","commander","boss"]:
		for stage in range(3):
			var action: String = Battle.ENEMY_ATTACKS[kind][stage]
			var hit := int(Battle.ENEMY_TIMING[action][0])
			var actors := []
			for frame in range(4):
				var tick: int = [0,hit / 2,hit,int(Battle.ENEMY_TIMING[action][1]) - 1][frame]
				actors.append(_fighter(kind,action,tick,180 + frame * 300))
			scenes.append({"name":"%s-%s" % [kind,action],"fighters":actors,"effects":[]})
	for action in ["rising","low_sweep","ground_slam","charged_slam","air_light","air_heavy","upper_heavy","charged_upper","dash_strike","mixed_finisher"]:
		var timing := View.FrameAnimation.technique_sample(action,100)
		var actors := []
		for hero in ["nobunaga","oichi"]:
			for index in range(2):
				actors.append(_fighter(hero,action,0 if index == 0 else int(timing.duration * 0.65),180 + actors.size() * 300))
		scenes.append({"name":"hero-"+action,"fighters":actors,"effects":[]})
	for tick in [15,26,45,80,120,160,195]:
		var burning := _fighter("soldier","hurt",6,540)
		burning.burn = 100
		var frozen := _fighter("commander","idle",0,1080)
		frozen.freeze = 90
		scenes.append({"name":"special-%03d" % tick,"fighters":[_fighter("nobunaga","special",tick,300),burning,_fighter("oichi","special",tick,820),frozen],"effects":[]})
	var boss := _fighter("boss","boss_chain",35,330)
	var victim := _fighter("nobunaga","pulled",8,770)
	scenes.append({"name":"chain-pull","fighters":[boss,victim],"effects":[{"type":"chain","owner":330,"target":770,"x":330,"y":570,"target_x":770,"target_y":570,"life":20,"max_life":30}]})
	scenes.append({"name":"ice-shatter","fighters":[_fighter("oichi","heavy",17,330),_fighter("soldier","down",5,690)],"effects":[{"type":"shatter","x":690,"y":540,"life":22,"max_life":34}]})
	var shattered := _fighter("soldier","dead",0,690)
	shattered.hp = 0
	shattered.shattered_tick = 1
	shattered.damage_tick = 1
	scenes.append({"name":"ice-shatter-defeat","fighters":[_fighter("oichi","charged",17,330),shattered],"effects":[{"type":"shatter","x":690,"y":540,"life":22,"max_life":34}]})
	for charged in [false,true]:
		var action := "charged_slam" if charged else "ground_slam"
		scenes.append({"name":"slam-effect-"+("charged" if charged else "tap"),"fighters":[_fighter("nobunaga",action,38 if charged else 24,530)],"effects":[{"type":"shockwave","x":585,"y":570,"radius":480 if charged else 240,"life":22 if charged else 12,"max_life":42 if charged else 24,"element":"fire" if charged else ""}]})
	scenes.append({"name":"ranged-fire","fighters":[_fighter("archer","bow_shot",30,320),_fighter("gunner","gun_shot",44,820)],"effects":[{"type":"projectile","x":550,"y":570,"team":1,"weapon":"arrow","face":1,"life":30,"max_life":50},{"type":"projectile","x":1030,"y":570,"team":1,"weapon":"bullet","face":1,"life":30,"max_life":50}]})
	for index in range(scenes.size()):
		var scene: Dictionary = scenes[index]
		view.state = {"tick":index * 20,"fighters":scene.fighters,"effects":scene.effects,"drops":[]}
		view._positions.clear()
		view._frozen_samples.clear()
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(scene.name+".png")) == OK)
	view.queue_free()
	print("PASS: captured all melee attack rows, hero direction/air branches, fire, freeze, shatter, chain and ranged fire")
	quit()
