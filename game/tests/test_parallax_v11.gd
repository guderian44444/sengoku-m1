extends SceneTree
const View = preload("res://render/battle_view.gd")

func _init() -> void:
	var checks := 0
	for camera in [0.0,0.25,550.0,600.0,1100.0,1407.75,1408.0,1408.25]:
		var tiles: Array = View.ground_tiles(camera)
		assert(tiles[0].x <= 0 and tiles[-1].x + View.GROUND_TILE_WIDTH >= 1280,"Near ground must cover the viewport without gaps")
		checks += 1
		for i in range(1,tiles.size()):
			assert(is_equal_approx(tiles[i - 1].x + View.GROUND_TILE_WIDTH,tiles[i].x),"Ground strips must meet at the same world point")
			assert(tiles[i - 1].mirrored != tiles[i].mirrored,"Shared boundary samples the same source edge")
			checks += 2
		for layer in ["ground","flags","fence","stone","grass","ripples"]:
			assert(is_equal_approx(View.decor_offset(layer,camera),camera),"Near ground and decorations must stay attached to world props")
			checks += 1
		assert(View.decor_offset("background",camera) <= camera * 0.2)
		checks += 1
	for point in [180.0,900.0,1500.0,2100.0]:
		for camera in [0.0,550.0,1100.0]:
			var ground_x: float = point - View.decor_offset("ground",camera)
			var prop_x: float = point - camera
			assert(is_equal_approx(ground_x,prop_x),"A crate, basket, or foot must not slide against its ground mark")
			checks += 1
	assert(View.GROUND_TOP + View.GROUND_BLEND_HEIGHT < 400,"All walkable ground must already use full world speed")
	checks += 1
	print("PASS: parallax v11 geometry checks: ",checks)
	quit()
