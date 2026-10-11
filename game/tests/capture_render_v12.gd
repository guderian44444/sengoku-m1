extends SceneTree
const View = preload("res://render/battle_view.gd")
const Battle = preload("res://core/battle.gd")
const Frames = preload("res://render/frame_animation.gd")

func _initialize() -> void:
	_run.call_deferred()

func actor(kind: String, x: float, faction: String = "mori") -> Dictionary:
	return {"id":int(x),"kind":kind,"team":0 if kind in Battle.HEROES else 1,"x":x,"y":540,"z":0,"vz":0,"face":1,"action":"idle","action_tick":0,"hp":100,"max_hp":100,"combo":1,"heavy_combo":1,"faction":faction,"boss_variant":Battle.FACTIONS[faction].boss}

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
	var reactions := []
	for row in range(2):
		for column in range(4):
			var player := actor("nobunaga" if row == 0 else "oichi",160 + column * 300)
			player.id += row * 2000
			player.y = 360 + row * 280
			player.action = ["idle","hurt","dead","recovering"][column]
			player.action_tick = [0,9,40,20][column]
			reactions.append(player)
	scenes.append({"name":"two-hero-reactions","fighters":reactions})
	for faction in Battle.FACTIONS:
		var key: String = view._art._enemy_key("boss",faction)
		if view._art.enemy_attacks[key][0].source != "v12": continue
		var fighters := []
		for i in range(4):
			var boss := actor("boss",160 + i * 300,faction)
			if i > 0:
				boss.action = Frames.primary_enemy_action(boss)
				var timing: Array = Battle.enemy_timing(boss)
				boss.action_tick = [0,0,timing[0],timing[1] - 1][i]
			fighters.append(boss)
		scenes.append({"name":"boss-" + faction,"fighters":fighters})
	for hero in Battle.HEROES:
		if view._art.animations[hero].has("v12_heavy1"):
			var comparison := []
			for i in range(4):
				var player := actor(hero,160 + i * 300)
				if i > 0:
					player.action = "heavy"
					player.action_tick = Battle.hero_tick(hero,[0,0,14,35][i])
				comparison.append(player)
			scenes.append({"name":hero + "-stance-transition","fighters":comparison})
		for clip in ["light1","light2","light3","heavy1","heavy2","walk"]:
			if not view._art.animations[hero].has("v12_" + clip): continue
			for part in range(3):
				var fighters := []
				for i in range(4):
					var player := actor(hero,160 + i * 300)
					var frame := part * 4 + i
					if clip == "walk":
						player.moving = true
						player.preview_walk_distance = (frame + .01) * (148 if hero == "oichi" else 155) * .82 / 12
					else:
						player.action = "light" if clip.begins_with("light") else "heavy"
						player.combo = int(clip.right(1))
						player.heavy_combo = int(clip.right(1))
						var hit := 6 if player.action == "light" else 14
						var duration := 19 if player.action == "light" else 36
						var tick := float(frame) * hit / 6.0 if frame < 6 else hit + float(frame - 6) * (duration - hit) / 6.0
						player.action_tick = Battle.hero_tick(hero,ceili(tick))
					fighters.append(player)
				scenes.append({"name":"%s-%s-%d" % [hero,clip,part],"fighters":fighters})
	for scene in scenes:
		for fighter in scene.fighters:
			if fighter.has("preview_walk_distance"): view._walk_distance[fighter.id] = fighter.preview_walk_distance
		view.state = {"tick":300,"fighters":scene.fighters,"effects":[],"drops":[],"props":[],"civilian_flee_tick":0}
		view._motion_tick = 300
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(scene.name + ".png")) == OK)
	print("PASS: HD source captures: ",scenes.size())
	view.queue_free()
	quit()
