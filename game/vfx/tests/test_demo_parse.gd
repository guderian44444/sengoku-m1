extends SceneTree
const Demo = preload("res://vfx/demo/vfx_demo.gd")
func _initialize() -> void:
	print("PASS: isolated demo dependency parse")
	quit()
