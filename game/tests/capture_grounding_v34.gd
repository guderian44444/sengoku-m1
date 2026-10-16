extends SceneTree

const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")

class WetView extends View:
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color(.5,.5,.5))
		_draw_wet_zones()

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var output := ProjectSettings.globalize_path("res://../artifacts/grounding-v34/after")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := View.new()
	viewport.add_child(view)
	var battle := Battle.new()
	for sample in [[1,2,"market"],[1,6,"chamber"],[2,0,"supply-road"]]:
		battle.reset_campaign("normal",2,["nobunaga","oichi"],int(sample[0]))
		battle._enter_segment(int(sample[1]))
		battle.state.fighters = battle.state.fighters.filter(func(f): return f.team == 0)
		battle.state.effects.clear()
		battle.state.tick = 600
		battle.state.fighters[0].x = 420.0
		battle.state.fighters[0].y = 535.0
		battle.state.fighters[1].x = 730.0
		battle.state.fighters[1].y = 510.0
		view.camera_x = 0
		view.state = battle.state
		var before := var_to_bytes(battle.state)
		view.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		assert(var_to_bytes(battle.state) == before,"Drawing must not move authoritative collision anchors")
		assert(viewport.get_texture().get_image().save_png(output.path_join(str(sample[2])+".png")) == OK)
	view.hide()
	var wet := WetView.new()
	wet.state = {"wet_zones":[{"x":640.0,"y":480.0,"width":800.0,"depth":200.0}]}
	viewport.add_child(wet)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var edge_x := roundi(640 - (.85 + sin(15 * 7.13) * .1) * 400 * .92)
	var background := image.get_pixel(40,480).r
	var center_darkening := background - image.get_pixel(640,480).r
	var edge_darkening := background - image.get_pixel(edge_x,480).r
	assert(center_darkening > .04,"Wet ground must remain visibly damp at its center")
	assert(edge_darkening >= 0 and edge_darkening < center_darkening * .25,"Wet-ground edge fades into the surface instead of forming an opaque polygon")
	assert(image.save_png(output.path_join("wet-edge-check.png")) == OK)
	viewport.queue_free()
	await process_frame
	print("GROUNDING V34 CAPTURE PASS: 3 native staged scenes; battle state unchanged; wet-edge gradient verified from rendered pixels. Not a physical-input playthrough.")
	quit()
