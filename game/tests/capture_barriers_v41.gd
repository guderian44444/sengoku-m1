extends SceneTree
const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	var sim := Battle.new()
	sim.reset_campaign("normal",1,["nobunaga"],3)
	sim._enter_segment(1)
	var view := View.new()
	root.add_child(view)
	view.state = sim.get_state()
	view.camera_x = 170
	view.state.fighters[0].x = 700
	view.state.fighters[0].y = 480
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("TEST_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(root.get_texture().get_image().save_png(output.path_join("barrier-perspective.png")) == OK)
	view.queue_free()
	await process_frame
	print("BARRIER V41 CAPTURE PASS")
	quit()
