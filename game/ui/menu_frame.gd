extends Control

const SengokuTheme = preload("res://ui/sengoku_theme.gd")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 100 or size.y < 100:
		return
	var bounds := Rect2(Vector2(10, 10), size - Vector2(20, 20))
	draw_rect(bounds, SengokuTheme.GOLD, false, 2)
	draw_rect(bounds.grow(-6), Color(SengokuTheme.GOLD, 0.45), false, 1)
	# Fibres stay at the scroll edges so they never compete with text or cover a page.
	for index in range(56):
		var x := 30.0 + fmod(index * 79.0, size.x - 60.0)
		for y in [20.0, size.y - 23.0]:
			draw_line(Vector2(x, y), Vector2(x + 9 + index % 8, y + 1), Color(SengokuTheme.PAPER, 0.16), 1)
	for x in [24.0, size.x - 24.0]:
		for y in [24.0, size.y - 24.0]:
			var at := Vector2(x, y)
			var inward := Vector2(1 if x < size.x / 2 else -1, 1 if y < size.y / 2 else -1)
			var points := PackedVector2Array()
			for offset in [Vector2(0, 24), Vector2.ZERO, Vector2(24, 0), Vector2(24, 15), Vector2(9, 15), Vector2(9, 8), Vector2(17, 8)]:
				points.append(at + offset * inward)
			draw_polyline(points, SengokuTheme.GOLD, 2, true)
			var seal := at + Vector2(31, 31) * inward
			draw_circle(seal, 5, SengokuTheme.VERMILION)
			draw_circle(seal, 2, SengokuTheme.PAPER)
