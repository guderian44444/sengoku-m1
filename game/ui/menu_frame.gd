extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var bounds := Rect2(Vector2(10,10),size - Vector2(20,20))
	draw_rect(bounds,Color("bd915b"),false,2)
	draw_rect(bounds.grow(-5),Color("765136"),false,1)
	for x in [24.0,size.x - 24]:
		for y in [24.0,size.y - 24]:
			var at := Vector2(x,y)
			draw_colored_polygon(PackedVector2Array([at+Vector2(0,-6),at+Vector2(6,0),at+Vector2(0,6),at+Vector2(-6,0)]),Color("bd915b"))
