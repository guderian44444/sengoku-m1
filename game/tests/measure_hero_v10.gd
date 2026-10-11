extends SceneTree

func _initialize() -> void:
	var path := "res://assets/v10/hero-registration.json"
	var registration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var measured := {}
	for actor in registration.actors:
		var image := Image.load_from_file("res://assets/v10/" + actor + ".png")
		var mask := BitMap.new()
		mask.create_from_image_alpha(image,0.35)
		var components := []
		for polygon in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),1.5):
			var area := 0.0
			var bounds := Rect2(polygon[0],Vector2.ZERO)
			for i in range(polygon.size()):
				area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
				bounds = bounds.expand(polygon[i])
			if absf(area) < 800: continue
			components.append({"area":absf(area) / 2,"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]})
		measured[actor] = components
		print(actor,": ",components.size()," components")
	var output := FileAccess.open("res://../artifacts/art-native-v10/hero-components.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(measured))
	output.close()
	quit()
