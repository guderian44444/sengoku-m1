extends RefCounted

const PATH := "res://data/stage-01.json"

static func first() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(data.segments.size() >= 6 and data.segments.size() <= 8)
	for region in data.segments:
		assert(region.width >= 3200 and region.encounters.size() >= 2)
		for encounter in region.encounters: assert(encounter.waves.size() >= 2 and encounter.waves.size() <= 3)
	return data
