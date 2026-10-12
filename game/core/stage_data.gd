extends RefCounted

const PATH := "res://data/stage-01.json"

static func first() -> Dictionary:
	return chapter(1)

static func available() -> Array:
	var result := []
	for id in range(1,25):
		if FileAccess.file_exists("res://data/stage-%02d.json" % id):
			var data := chapter(id)
			result.append({"id":id,"title":str(data.title)})
	return result

static func chapter(id: int) -> Dictionary:
	assert(id >= 1 and id <= 24)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stage-%02d.json" % id))
	assert(int(data.id) == id)
	assert(data.segments.size() >= 6 and data.segments.size() <= 8)
	for region in data.segments:
		assert(region.width >= 2000 and region.encounters.size() >= 2)
		for encounter in region.encounters: assert(encounter.waves.size() >= 2 and encounter.waves.size() <= 3)
	return data
