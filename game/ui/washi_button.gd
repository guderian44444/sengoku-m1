extends StyleBox

var bg_color := Color.TRANSPARENT
var border_color := Color.TRANSPARENT
var border_width := 1.0

# Keep the native button's content margins and hit area; only the paper is cut.
func paper_outline(rect: Rect2) -> PackedVector2Array:
	var cut := minf(11.0, minf(rect.size.x, rect.size.y) * 0.22)
	var p := rect.position
	var end := rect.end
	return PackedVector2Array([
		p + Vector2(cut, 0), Vector2(end.x - cut * 0.5, p.y),
		Vector2(end.x, p.y + cut * 0.5), Vector2(end.x, end.y - cut),
		Vector2(end.x - cut, end.y), Vector2(p.x + cut * 0.5, end.y),
		Vector2(p.x, end.y - cut * 0.5), p + Vector2(0, cut),
		p + Vector2(cut, 0),
	])

func _draw(canvas: RID, rect: Rect2) -> void:
	var edge := rect.grow(-1.5)
	if edge.size.x <= 0 or edge.size.y <= 0:
		return
	var outline := paper_outline(edge)
	if bg_color.a > 0:
		RenderingServer.canvas_item_add_polygon(canvas, outline, PackedColorArray([bg_color]))
		# Deterministic fibres stay still when the button is hovered or pressed.
		var fibres := PackedVector2Array()
		for y in range(7, int(rect.size.y) - 6, 7):
			for x in range(14, int(rect.size.x) - 15, 13):
				var grain := x * 17 + y * 29
				var start := rect.position + Vector2(x + grain % 7 - 3, y + grain % 5 - 2)
				fibres.append(start)
				fibres.append(start + Vector2(2 + grain % 5, grain % 3 - 1))
		if not fibres.is_empty():
			RenderingServer.canvas_item_add_multiline(canvas, fibres, PackedColorArray([Color("efddba0b")]), 1.0, true)
		# Small seigaiha fans decorate the ends without competing with the label.
		if rect.size.x >= 64 and rect.size.y >= 36:
			for x in [rect.position.x + 22, rect.end.x - 22]:
				for radius in [5.0, 9.0, 13.0]:
					var wave := PackedVector2Array()
					for step in range(13):
						var angle := PI + PI * step / 12.0
						wave.append(Vector2(x, rect.end.y - 9) + Vector2(cos(angle), sin(angle)) * radius)
					RenderingServer.canvas_item_add_polyline(canvas, wave, PackedColorArray([Color("bc986724")]), 1.0, true)
		if edge.size.x > 24 and edge.size.y > 18:
			RenderingServer.canvas_item_add_polyline(canvas, paper_outline(edge.grow(-4)), PackedColorArray([Color(border_color, 0.25)]), 1.0, true)
	RenderingServer.canvas_item_add_polyline(canvas, outline, PackedColorArray([border_color]), border_width, true)
	if bg_color.a == 0 and edge.size.x > 24 and edge.size.y > 18:
		# A small vermilion seal adds a shape cue for controller focus.
		var center := Vector2(rect.position.x + 8, rect.get_center().y)
		var seal := PackedVector2Array([center + Vector2(0, -4), center + Vector2(3, 0), center + Vector2(0, 4), center + Vector2(-3, 0)])
		RenderingServer.canvas_item_add_polygon(canvas, seal, PackedColorArray([Color("b65c43")]))
