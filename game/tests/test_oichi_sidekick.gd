extends SceneTree

const HEIGHT := 148.0
const RULER := 390.34722222222223

func _initialize() -> void:
	var registration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/v33/oichi/registration.json"))
	var light_3: Dictionary = registration.clips.light_3
	var idle: Dictionary = registration.clips.light_1.frames[0].layers.body
	assert(light_3.frames.size() == 17 and light_3.duration_ms == 970)
	assert(is_equal_approx(float(light_3.events[0].ms), 380.0))
	assert(is_equal_approx(float(idle.body_height), 315.0))
	var idle_sole := _sole(idle)
	for frame in light_3.frames:
		var body: Dictionary = frame.layers.body
		assert(is_equal_approx(float(body.body_height), RULER))
		assert(str(body.file) == "light3-b-body.png")
		assert(bool(frame.authored_weapon) and bool(frame.fixed_weapon) and not bool(frame.nocked))
		assert(not frame.layers.has("weapon") and not frame.layers.has("string"))
		if frame.layers.has("fx_back"):
			assert(is_equal_approx(float(frame.layers.fx_back.body_height), 304.0599415204678))
	var opening: Dictionary = light_3.frames[0].layers.body
	var recovery: Dictionary = light_3.frames[light_3.frames.size() - 1].layers.body
	assert(absf(_sole(opening) - idle_sole) < 0.5)
	assert(absf(_sole(recovery) - idle_sole) < 0.5)
	# Hair on the left, bow on the right. This is the calibrated standing height, not a per-frame stretch.
	assert(absf(_span(opening, 0.42) - 153.56) < 1.0)
	print("OICHI SIDE KICK PASS")
	quit()

func _sole(layer: Dictionary) -> float:
	return _extent(layer, 1.0).sole

func _span(layer: Dictionary, x_fraction: float) -> float:
	var extent := _extent(layer, x_fraction)
	return extent.sole - extent.head

func _extent(layer: Dictionary, x_fraction: float) -> Dictionary:
	var image := Image.load_from_file("res://assets/v33/oichi/" + str(layer.file))
	var rect: Array = layer.rect
	var anchor: Array = layer.anchor
	var limit := int(float(rect[2]) * x_fraction)
	var top := -1
	var bottom := -1
	for y in range(int(rect[3])):
		for x in range(limit):
			if image.get_pixel(int(rect[0]) + x, int(rect[1]) + y).a >= 32.0 / 255.0:
				top = y
				break
		if top >= 0:
			break
	for y in range(int(rect[3]) - 1, -1, -1):
		for x in range(int(rect[2])):
			if image.get_pixel(int(rect[0]) + x, int(rect[1]) + y).a >= 32.0 / 255.0:
				bottom = y
				break
		if bottom >= 0:
			break
	var scale := HEIGHT / float(layer.body_height)
	return {"head": (float(top) - float(anchor[1])) * scale, "sole": (float(bottom) - float(anchor[1])) * scale}
