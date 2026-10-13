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
		if region.has("challenge"):
			var challenge: Dictionary = region.challenge
			assert(challenge.kind == "escort", "Unknown stage challenge")
			assert(challenge.start_x >= 100 and challenge.target_x > challenge.start_x and challenge.target_x <= region.width - 160)
			assert(challenge.y >= 360 and challenge.y <= 600 and challenge.hp >= 1 and challenge.hp <= 1000)
			assert(challenge.reward >= 1 and challenge.reward <= 10000)
		var start := 0.0
		for encounter in region.encounters:
			assert(encounter.end >= start + 1000 and encounter.end <= region.width)
			assert(encounter.waves.size() >= 2 and encounter.waves.size() <= 3)
			for wave in encounter.waves:
				assert(not wave.is_empty() and wave.size() <= 16)
				for kind in wave:
					assert(kind in ["soldier", "archer", "gunner", "flag", "commander", "boss", "shield_spear", "fire_archer", "raider"], "Unknown stage enemy")
				if "boss" in wave: assert(encounter.has("boss"), "Boss wave needs a named boss")
			if encounter.has("boss"):
				var boss: Dictionary = encounter.boss
				if boss.has("variant"): assert(boss.variant in ["naginata", "matchlock", "hook_yari", "dual_swords", "cross_spear", "nodachi", "long_yari", "monk_naginata", "kusarigama", "fan_sword", "short_yari", "weighted_chain"])
				if boss.has("actions"):
					assert(not boss.actions.is_empty() and boss.actions.size() <= 4)
					for action in boss.actions: assert(action in ["boss_sweep", "boss_smash", "boss_chain", "boss_thrust", "boss_dash", "boss_volley", "boss_counter", "boss_double", "boss_hook", "boss_earth", "boss_grab_throw"])
				if boss.has("reinforcements"):
					assert(not boss.reinforcements.is_empty() and boss.reinforcements.size() <= 8)
					for kind in boss.reinforcements: assert(kind in ["soldier", "archer", "gunner", "flag", "commander", "shield_spear", "fire_archer", "raider"])
			start = float(encounter.end)
		assert(start == float(region.width), "Final checkpoint must reach scene exit")
	return data
