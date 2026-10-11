extends SceneTree

const View = preload("res://render/battle_view.gd")

func _initialize() -> void:
	_run.call_deferred()

func _hero(kind: String, action: String, tick: int, x: float) -> Dictionary:
	return {"id":1 if kind == "nobunaga" else 2,"team":0,"player_index":0,"kind":kind,"x":x,"y":555.0,"z":0.0,"face":1,"hp":100,"max_hp":100,"action":action,"action_tick":tick,"charge":tick,"combo":2,"heavy_combo":1}

func _run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	assert(not output.is_empty() and DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280,720)
	var view := View.new()
	root.add_child(view)
	var scenes := []
	for tick in [0,6,12,18,26,35,70]:
		scenes.append({"name":"charge-%02d" % tick,"fighters":[_hero("nobunaga","charge",tick,380),_hero("oichi","charge",tick,860)],"effects":[]})
	for tick in [0,6,12,20]:
		scenes.append({"name":"rising-%02d" % tick,"fighters":[_hero("nobunaga","rising",tick,380),_hero("oichi","rising",tick,860)],"effects":[]})
	for age in [0,6,12,18,23]:
		scenes.append({"name":"slam-%02d" % age,"fighters":[_hero("nobunaga","ground_slam",14+age,480)],"effects":[{"type":"shockwave","x":535,"y":555,"radius":240,"life":24-age,"max_life":24}]})
	for step in range(4):
		var nobu := _hero("nobunaga","idle",0,380)
		var oichi := _hero("oichi","idle",0,860)
		nobu.moving = true
		oichi.moving = true
		scenes.append({"name":"walk-%d" % step,"fighters":[nobu,oichi],"effects":[],"walk_frame":step})
	for index in range(scenes.size()):
		var scene: Dictionary = scenes[index]
		view.state = {"tick":index,"fighters":scene.fighters,"effects":scene.effects,"drops":[]}
		view._positions.clear()
		if scene.has("walk_frame"):
			view._walk_distance[1] = float(scene.walk_frame) * 155.0 * 0.82 / 4.0 + 0.001
			view._walk_distance[2] = float(scene.walk_frame) * 148.0 * 0.82 / 4.0 + 0.001
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(scene.name+".png")) == OK)
	view.queue_free()
	print("PASS: captured charge growth, stable bow, directional attacks and walk contacts")
	quit()
