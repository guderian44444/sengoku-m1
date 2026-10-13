extends SceneTree
const VFX = preload("res://vfx/vfx_player.gd")
func _initialize() -> void:
	var one := {"frames":4,"duration_ticks":24,"loop":false}
	assert(VFX.sample(one,-1).is_empty())
	assert(VFX.sample(one,24).is_empty())
	assert(VFX.sample(one,0).frame == 0)
	assert(VFX.sample(one,12).frame == 2)
	assert(VFX.sample(one,6,0,2).frame == 2)
	assert(VFX.sample(one,16,10).frame == 1)
	assert(VFX.sample({"frames":1,"duration_ticks":24},12).mix == 0.0)
	var loop := one.duplicate()
	loop.loop = true
	assert(VFX.sample(loop,24).frame == 0)
	assert(VFX.sample(loop,23).next == 0)
	assert(VFX.anchored(Vector2(100,100),Vector2(30,-60),-1,310) == Vector2(40,-20))
	print("PASS: VFX visibility, looping, speed, start tick, mirrored scaled anchors")
	quit()
