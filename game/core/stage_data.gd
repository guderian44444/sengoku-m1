extends RefCounted

const Stage04Data = preload("res://core/stage04_data.gd")
const Stage03 = preload("res://core/stage03_encounter.gd")
const Expedition = preload("res://core/stage07_10_data.gd")

const PATH := "res://data/stage-01.json"

static func first() -> Dictionary:
	return chapter(1)

static func available() -> Array:
	var result := []
	for id in range(1,25):
		if FileAccess.file_exists("res://data/stage-%02d.json" % id):
			var data := chapter(id)
			if not data.get("prototype", false): result.append({"id":id,"title":str(data.title)})
	return result

static func chapter(id: int) -> Dictionary:
	assert(id >= 1 and id <= 24)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stage-%02d.json" % id))
	assert(int(data.id) == id)
	var camp: bool = id == 3
	assert(data.segments.size() == 5 if id in [4,5,7,8,9,10] else (data.segments.size() == 4 if camp else (data.segments.size() >= 6 and data.segments.size() <= 8)))
	var mikawa_node := 0
	for region in data.segments:
		assert(region.width >= 2000 and (region.encounters.size() == 1 if camp else region.encounters.size() >= 2))
		if region.has("challenge"):
			var challenge: Dictionary = region.challenge
			assert(challenge.kind == "reclaim", "Unknown stage challenge")
			assert(challenge.start_x >= 100 and challenge.start_x < region.encounters[0].end - 160)
			assert(challenge.y >= 360 and challenge.y <= 600 and challenge.hp >= 1 and challenge.hp <= 1000)
			assert(challenge.reward >= 1 and challenge.reward <= 10000)
		var start := 0.0
		for encounter in region.encounters:
			assert(encounter.end >= start + 1000 and encounter.end <= region.width)
			if id in Expedition.STAGES:
				mikawa_node+=1
				assert(Expedition.valid_spec(encounter,start,float(region.width),id),"Invalid stage 7-10 encounter")
				assert(int(encounter.node)==mikawa_node)
				assert((str(encounter.boss)!="")== (mikawa_node in [6,10]),"One lieutenant and one final boss per stage")
				start=float(encounter.end)
				continue
			if id == 5:
				mikawa_node += 1
				assert(encounter.mode == "ikki" and int(encounter.node) == mikawa_node)
				assert(encounter.role in ["militia","monk"])
				assert(encounter.garrison >= (4 if encounter.role=="monk" else 6) and encounter.garrison <= (6 if encounter.role=="monk" else 8))
				assert(encounter.boss in ["","hachiya","natsume","kusei"])
				var pairs := {}
				for object in encounter.objects:
					assert(object.x>=start+100 and object.x<=encounter.end-150 and object.y>=360 and object.y<=600)
					if object.has("banner_pair"):
						var key := int(object.banner_pair)
						if not pairs.has(key): pairs[key]=[]
						pairs[key].append(object)
				assert(not pairs.is_empty())
				for pair in pairs.values():
					assert(pair.size()==2 and pair[0].x==pair[1].x and absf(pair[0].y-pair[1].y)>=150)
				start = float(encounter.end)
				continue
			if id == 4:
				mikawa_node += 1
				assert(encounter.mode == "mikawa" and int(encounter.node) == mikawa_node)
				assert(encounter.units.size() >= 1 and encounter.units.size() <= 8)
				assert(int(encounter.cap) in [10,11,15] and int(encounter.regular_cap) in [8,10])
				assert(encounter.batches.size() in [2,3])
				var total: int = encounter.units.size()
				for batch in encounter.batches:
					assert(batch.left.size() == batch.right.size() and batch.left.size() in [3,4])
					for unit in batch.left+batch.right:
						assert(unit.role in Stage04Data.ROLES and unit.kind in ["soldier","archer","gunner"])
					total += batch.left.size()*2
				assert(total == int(encounter.scheduled_total))
				for unit in encounter.units:
					assert(unit.role in Stage04Data.ROLES and unit.kind in ["soldier","archer","gunner","boss"])
					assert(unit.x >= start and unit.x <= encounter.end and unit.y >= 360 and unit.y <= 600)
				start = float(encounter.end)
				continue
			if camp:
				assert(Stage03.valid_spec(encounter, float(region.width)))
				start = float(encounter.end)
				continue
			assert(encounter.waves.size() >= 2 and encounter.waves.size() <= 3)
			for wave in encounter.waves:
				assert(not wave.is_empty() and wave.size() <= 16)
				for kind in wave:
					assert(kind in ["soldier", "archer", "gunner", "flag", "commander", "boss", "shield_spear", "fire_archer", "raider"], "Unknown stage enemy")
				if "boss" in wave: assert(encounter.has("boss"), "Boss wave needs a named boss")
			if encounter.has("boss"):
				var boss: Dictionary = encounter.boss
				for field in ["reach_thrust","reach_sweep"]:
					if boss.has(field): assert(boss[field] > 0 and boss[field] <= 400)
				if boss.has("variant"): assert(boss.variant in ["naginata", "matchlock", "hook_yari", "dual_swords", "cross_spear", "nodachi", "long_yari", "monk_naginata", "kusarigama", "fan_sword", "short_yari", "weighted_chain"])
				if boss.has("actions"):
					assert(not boss.actions.is_empty() and boss.actions.size() <= 4)
					for action in boss.actions: assert(action in ["boss_sweep", "boss_smash", "boss_chain", "boss_thrust", "boss_dash", "boss_volley", "boss_counter", "boss_double", "boss_hook", "boss_earth", "boss_grab_throw"])
				if boss.has("reinforcements"):
					assert(not boss.reinforcements.is_empty() and boss.reinforcements.size() <= 8)
					for kind in boss.reinforcements: assert(kind in ["soldier", "archer", "gunner", "flag", "commander", "shield_spear", "fire_archer", "raider"])
			start = float(encounter.end)
		assert(start == float(region.width), "Final checkpoint must reach scene exit")
	if id in Expedition.STAGES: assert(mikawa_node==10,"Stages seven to ten each contain ten complete battle nodes")
	if id==5:
		assert(mikawa_node==12,"Stage five has twelve nodes")
		for section in data.segments.slice(0,2):
			var flags := 0
			for encounter in section.encounters:
				flags+=encounter.objects.filter(func(o):return o.has("banner_pair")).size()
			assert(flags>=8 and flags<=10,"Farm scenes have eight to ten deliberately paired banners")
	return data
