extends StyleBox

var bg_color := Color.TRANSPARENT
var border_color := Color.TRANSPARENT
var border_width := 1.0
var paper_tint := Color.WHITE
static var _texture: Texture2D
# Crop only the empty outer canvas at draw time; the supplied PNG stays unchanged.
const SOURCE := Rect2(8,88,2148,462)
const LEFT_CAP := 250.0
const RIGHT_CAP := 245.0
const INNER_PAPER := Rect2(270,190,1633,260)

static func texture() -> Texture2D:
	if _texture == null:
		_texture = ImageTexture.create_from_image(Image.load_from_file("res://assets/current/ui/scroll02/scroll02_blank.png"))
	return _texture

func slices(rect: Rect2) -> Array[Rect2]:
	var scale := rect.size.y / SOURCE.size.y
	var left := minf(LEFT_CAP * scale,rect.size.x * .22)
	var right := minf(RIGHT_CAP * scale,rect.size.x * .22)
	return [
		Rect2(rect.position,Vector2(left,rect.size.y)),
		Rect2(rect.position+Vector2(left,0),Vector2(maxf(0,rect.size.x-left-right),rect.size.y)),
		Rect2(Vector2(rect.end.x-right,rect.position.y),Vector2(right,rect.size.y))
	]

func _draw(canvas: RID, rect: Rect2) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0: return
	if bg_color.a > 0:
		var tint := Color.WHITE
		if bg_color == Color("754834"): tint = Color(1.1,1.07,1.02)
		elif bg_color == Color("772d24"): tint = Color(.86,.84,.8)
		elif bg_color == Color("bba888"): tint = Color(.72,.72,.72,.65)
		var source := [
			Rect2(SOURCE.position,Vector2(LEFT_CAP,SOURCE.size.y)),
			Rect2(SOURCE.position+Vector2(LEFT_CAP,0),Vector2(SOURCE.size.x-LEFT_CAP-RIGHT_CAP,SOURCE.size.y)),
			Rect2(Vector2(SOURCE.end.x-RIGHT_CAP,SOURCE.position.y),Vector2(RIGHT_CAP,SOURCE.size.y))
		]
		var destination := slices(rect)
		for i in range(3):
			RenderingServer.canvas_item_add_texture_rect_region(canvas,destination[i],texture().get_rid(),source[i],tint)
	else:
		# Focus brackets remain separate from ink text and inside the original hit area.
		var mark := Vector2(rect.position.x + minf(10,rect.size.x*.15),rect.get_center().y)
		var diamond := PackedVector2Array([mark+Vector2(0,-5),mark+Vector2(3,0),mark+Vector2(0,5),mark+Vector2(-3,0)])
		RenderingServer.canvas_item_add_polygon(canvas,diamond,PackedColorArray([Color("fff0c8")]))
		var b := rect.grow(-2)
		var arm := minf(10,minf(b.size.x,b.size.y)*.22)
		for corner in [b.position,Vector2(b.end.x,b.position.y),b.end,Vector2(b.position.x,b.end.y)]:
			var dx := 1.0 if corner.x < b.get_center().x else -1.0
			var dy := 1.0 if corner.y < b.get_center().y else -1.0
			var points := PackedVector2Array([corner+Vector2(dx*arm,0),corner,corner+Vector2(0,dy*arm)])
			RenderingServer.canvas_item_add_polyline(canvas,points,PackedColorArray([border_color]),border_width,true)
	if paper_tint != Color.WHITE:
		# Tint only the inner paper, preserving the red brocade and rollers.
		var center: Rect2 = slices(rect)[1]
		var scale := Vector2(center.size.x/(SOURCE.size.x-LEFT_CAP-RIGHT_CAP),rect.size.y/SOURCE.size.y)
		var offset := INNER_PAPER.position-SOURCE.position-Vector2(LEFT_CAP,0)
		var paper_rect := Rect2(center.position+offset*scale,INNER_PAPER.size*scale)
		RenderingServer.canvas_item_add_texture_rect_region(canvas,paper_rect,texture().get_rid(),INNER_PAPER,paper_tint)
