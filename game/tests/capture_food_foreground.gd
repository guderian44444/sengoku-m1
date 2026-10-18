extends SceneTree

const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
var folder := "res://../artifacts/food-foreground-20261018/captures/"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := View.new()
	viewport.add_child(view)
	view._fx.muted = true
	var sim := Battle.new()
	sim.reset_campaign("normal",1,["nobunaga"],4)
	for section in 5:
		sim._enter_segment(section)
		sim.state.intro.clear()
		var p: Dictionary=sim.state.fighters[0]
		p.x=450;p.y=600;p.food_state="pending"
		sim._add_drop("food",620,570,p.id)
		for camera in [0,900]:
			view.state=sim.get_state()
			view.camera_x=camera
			view.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			assert(viewport.get_texture().get_image().save_png(folder+"scene-%d-%d.png"%[section,camera])==OK)
		var ground: Dictionary=view._stage_art.backgrounds[view._stage04_art.GROUND[section]]
		assert(ground.region.size.x>=view.GROUND_TILE_WIDTH,"Native ground width must not upscale")
		assert(ground.region.size.y*(1.0-float(ground.horizon))>=356,"Native ground height must not upscale")
		# Every foreground sprite stays below the playable ground edge (y=600).
		for kind in view._stage04_art.FOREGROUND[section]:
			var frame: Dictionary=view._stage_art.border_frames.get(kind,view._stage_art.props.get(kind,{}))
			var height:=minf(96,float(frame.display_height)*1.35)
			assert(708-float(frame.anchor.y)*height/float(frame.body_height)>600,"Foreground overlaps playable lane")
	viewport.queue_free()
	await process_frame
	print("FOOD FOREGROUND CAPTURES PASS: five scenes at two camera positions, foreground geometry below playable lane")
	quit()
