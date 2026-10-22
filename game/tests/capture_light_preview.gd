extends SceneTree

const Battle = preload("res://core/battle.gd")
const VIEW_W := 1280
const VIEW_H := 960
const FEET_X := 360.0
const FEET_Y := 700.0

class Board extends "res://render/battle_view.gd":
	func _draw() -> void:
		if _fx.configured and _fx.shared_player != null:
			_fx.shared_player.begin_draw(self)
		var fighter := _player()
		if fighter.is_empty():
			return
		var origin := Vector2(float(fighter.x) - camera_x, float(fighter.y))
		draw_line(origin + Vector2(-90, 0), origin + Vector2(260, 0), Color("6b5a42"), 2)
		_shadow_pass = true
		_draw_art_fighter(fighter, origin)
		_shadow_pass = false
		_draw_art_fighter(fighter, origin)
		for effect in state.get("effects", []):
			if _skip_detached_slash(fighter, effect):
				continue
			_draw_effect(effect)
		if not _shadow_pass:
			_fx.draw_bound(self, int(fighter.get("id", 0)), camera_x)
			_fx.draw_world(self, camera_x)

	func _player() -> Dictionary:
		for fighter in state.get("fighters", []):
			if int(fighter.get("team", 1)) == 0:
				return fighter
		return {}

	func nobunaga_arc_visible(fighter: Dictionary) -> bool:
		if str(fighter.get("kind", "")) != "nobunaga" or str(fighter.get("action", "")) != "light":
			return false
		var sample := _fighter_animation(fighter)
		var frame := _art.animation_frame("nobunaga", sample)
		var height := float(FrameAnimation.CombatMoves.HEIGHTS.nobunaga)
		return not _fx.nobunaga_cut_pose(fighter, sample, _weapons.geometry(fighter, frame, height)).is_empty()

	func preview_arc_name(fighter: Dictionary) -> String:
		if str(fighter.get("kind", "")) == "nobunaga":
			return "blade_arc" if nobunaga_arc_visible(fighter) else ""
		var sample := _fighter_animation(fighter)
		var frame := _art.animation_frame(str(fighter.get("kind", "")), sample)
		return str(_fx.light_follow_pose(self, fighter, sample, frame).get("id", ""))

	func _skip_detached_slash(fighter: Dictionary, effect: Dictionary) -> bool:
		if str(effect.get("type", "")) != "slash" or str(fighter.get("action", "")) != "light":
			return false
		var combo := int(fighter.get("combo", 0))
		var kind := str(fighter.get("kind", ""))
		if combo in [1, 2] and kind != "nobunaga":
			return true
		# Tadakatsu's third light draws the spear-tip path. Hide the old horizontal gust.
		return kind == "tadakatsu" and combo == 3 and bool(effect.get("finisher", false))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/light-combo-preview/raw")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(VIEW_W, VIEW_H)
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(VIEW_W, VIEW_H)
	root.add_child(viewport)
	var board := Board.new()
	viewport.add_child(board)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(board._fx.configured, "Shared combat VFX did not configure")
	assert(board._fx.shared_player.catalog.has("blade_arc"))
	assert(board._fx.shared_player.catalog.has("wind_arc"))
	assert(board._fx.shared_player.catalog.has("neutral_slash_arc"))
	assert(board._fx.shared_player.catalog.has("neutral_thrust_cone"))
	var names := {"nobunaga": "信長", "oichi": "阿市", "hideyoshi": "秀吉", "ieyasu": "家康", "mitsuhide": "顯如", "tadakatsu": "忠勝"}
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	var previous := {}
	if only != "":
		var existing: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("manifest.json")))
		if existing is Dictionary:
			for hero_entry in existing.get("heroes", []):
				previous[str(hero_entry.get("id", ""))] = hero_entry
	var manifest := {"tick_ms": 1000.0 / 60.0, "heroes": []}
	for hero in Battle.HEROES:
		if only != "" and hero != only:
			assert(previous.has(hero), "Missing previous capture for %s" % hero)
			manifest.heroes.append(previous[hero])
			continue
		var hero_dir := output.path_join(hero)
		assert(DirAccess.make_dir_recursive_absolute(hero_dir) == OK)
		var clips := []
		for segment in [1, 2, 3]:
			var battle := Battle.new()
			battle.reset_training(hero, "dummy")
			var player: Dictionary = battle.state.fighters[0]
			player.y = FEET_Y
			player.face = 1
			# The stall at x=440 overlaps the spawn, so a whiff still breaks it and draws a hit spark.
			battle.state.fighters = [player]
			battle.state.props = []
			player.combo = segment - 1
			player.combo_tick = 240
			var start_x := float(player.x)
			board.camera_x = start_x - FEET_X
			board.state = battle.state
			battle.step([{"buttons": Battle.LIGHT, "dx": 0, "dy": 0}])
			assert(str(player.action) == "light" and int(player.combo) == segment, "Light segment did not start: %s %d" % [hero, segment])
			var frames := []
			var index := 0
			var extra := 0
			while index < 120:
				var swinging := str(player.action) == "light"
				var effects := _effect_names(battle.state)
				var hide_horizontal_slash := (str(player.kind) != "nobunaga" and int(player.combo) in [1, 2]) or (str(player.kind) == "tadakatsu" and int(player.combo) == 3)
				if hide_horizontal_slash:
					var kept: Array = []
					for effect_name in effects:
						if effect_name != "slash":
							kept.append(effect_name)
					effects = kept
				var arc_name := board.preview_arc_name(player)
				if arc_name != "":
					effects.append(arc_name)
				assert(not effects.has("hit"), "Hit spark is still in frame: %s light_%d frame %d" % [hero, segment, index])
				if not swinging and effects.is_empty():
					break
				if not swinging:
					extra += 1
					if extra > 24:
						break
				var file_name := "light_%d_%03d.png" % [segment, index]
				board.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var image := viewport.get_texture().get_image()
				assert(image != null and image.get_width() == VIEW_W, "Viewport capture failed")
				assert(image.save_png(hero_dir.path_join(file_name)) == OK)
				frames.append({"file": file_name, "action": str(player.action), "tick": int(player.action_tick), "combo": int(player.combo), "effects": effects})
				index += 1
				battle.step([{"buttons": 0, "dx": 0, "dy": 0}])
			assert(frames.size() > 4, "Clip too short: %s light_%d" % [hero, segment])
			clips.append({"id": "light_%d" % segment, "title": "輕手%s" % ["一", "二", "三"][segment - 1], "frames": frames})
			print("captured %s light_%d (%d frames)" % [hero, segment, frames.size()])
		manifest.heroes.append({"id": hero, "name": names[hero], "clips": clips})
	var report := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify(manifest))
	report.close()
	print("PASS light preview frames -> %s" % output)
	viewport.queue_free()
	quit()

func _effect_names(world: Dictionary) -> Array:
	var names := []
	for effect in world.get("effects", []):
		var type := str(effect.get("type", ""))
		if type in ["slash", "blade_wave", "wind_wave", "wind_hit", "hit"]:
			names.append(type)
	return names
