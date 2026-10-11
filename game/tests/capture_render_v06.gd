extends SceneTree

const BattleView = preload("res://render/battle_view.gd")

func _initialize() -> void:
	_run.call_deferred()

func _hero(kind: String, action: String, tick: int) -> Dictionary:
	return {"id":1,"team":0,"player_index":0,"kind":kind,"x":425.0,"y":550.0,"z":0.0,"face":1,"hp":100,"max_hp":100,"action":action,"action_tick":tick,"combo":1,"heavy_combo":1}

func _enemy(action: String, x: float = 640.0) -> Dictionary:
	return {"id":2,"team":1,"kind":"soldier","x":x,"y":550.0,"z":0.0,"face":-1,"hp":70,"max_hp":100,"action":action,"action_tick":6}

func _run() -> void:
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280,720)
	var view := BattleView.new()
	root.add_child(view)
	var scenes := []
	for camera in [0,1100]:
		scenes.append({"name":"parallax-%d" % camera,"camera":camera,"fighters":[],"effects":[]})
	for tick in [14,26,40]:
		scenes.append({"name":"nobunaga-%s-%d" % ["heavy" if tick == 14 else "special",tick],"fighters":[_hero("nobunaga","heavy" if tick == 14 else "special",tick),_enemy("hurt")],"effects":[]})
	for kind in ["arrow","special_arrow"]:
		var action := "heavy" if kind == "arrow" else "special"
		var tick := 16 if kind == "arrow" else 29
		scenes.append({"name":"oichi-"+kind,"fighters":[_hero("oichi",action,tick),_enemy("stunned",940.0)],"effects":[{"type":"projectile","weapon":kind,"owner":1,"x":740.0,"y":550.0,"z":28.0,"face":1,"life":30,"max_life":50}]})
	for stage in [1,2,3]:
		var needle_hero := _hero("oichi","light",6)
		needle_hero.combo = stage
		scenes.append({"name":"oichi-light-%d" % stage,"fighters":[needle_hero],"effects":[{"type":"projectile","weapon":"needle","owner":1,"x":530.0,"y":550.0,"z":28.0,"face":1,"life":24,"max_life":26}]})
	var heavy_two := _hero("oichi","heavy",14)
	heavy_two.heavy_combo = 2
	scenes.append({"name":"oichi-heavy-2","fighters":[heavy_two],"effects":[{"type":"projectile","weapon":"arrow","owner":1,"x":530.0,"y":550.0,"z":28.0,"face":1,"life":30}]})
	scenes.append({"name":"oichi-down","fighters":[_hero("oichi","down",18)],"effects":[]})
	var archer := _enemy("windup",900)
	archer.kind = "archer"
	archer.action_tick = 26
	scenes.append({"name":"enemy-archer","fighters":[archer],"effects":[{"type":"projectile","weapon":"arrow","owner":2,"team":1,"x":860.0,"y":550.0,"z":28.0,"face":-1,"life":80}]})
	for hero in ["nobunaga","oichi"]:
		var holder := _hero(hero,"holding",60)
		holder.grab_target = 2
		var victim := _enemy("grabbed",481.0)
		victim.held_by = 1
		victim.z = 12.0
		victim.shield_hurt_tick = 10
		scenes.append({"name":hero+"-shield-hit","fighters":[holder,victim],"effects":[{"type":"shield_hit","target":2,"x":481.0,"y":538.0,"life":10}]})
		var thrown := _enemy("thrown",720.0)
		thrown.z = 52.0
		thrown.throw_ticks = 20
		thrown.thrown_by = 1
		scenes.append({"name":hero+"-throw","fighters":[_hero(hero,"throw",14),thrown,_enemy("down",795.0)],"effects":[{"type":"throw_hit","x":775.0,"y":545.0,"life":8}]})
	for scene in scenes:
		view._projectile_origins.clear()
		view.camera_x = float(scene.get("camera",0))
		view.weather = 2 if "special" in scene.name else 0
		view.state = {"tick":180,"fighters":scene.fighters,"effects":scene.effects,"drops":[]}
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(scene.name+".png")) == OK)
	print("PASS: captured %d representative renderer-contract scenes" % scenes.size())
	view.queue_free()
	quit()
