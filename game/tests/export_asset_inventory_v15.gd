extends SceneTree

const Battle = preload("res://core/battle.gd")
const View = preload("res://render/battle_view.gd")
const HERO_CLIPS := ["idle","walk","run","jump","light1","light2","light3","heavy1","heavy2","charge","charged","rising","low_sweep","dash_strike","dash_heavy","upper_heavy","charged_upper","ground_slam","charged_slam","air_light","air_heavy","mixed_finisher","mixed_rising","counter_cut","guard","hurt","launched","down","recovering","stunned","grabbed","holding","throw","special","victory"]

func _initialize() -> void:
	var view := View.new()
	var sim := Battle.new()
	var report := {"version":"0.15", "acceptance":"Runtime source inventory only; a frame count does not certify distinct poses or artistic quality.", "heroes":{}, "enemies":{}}
	for hero in Battle.HEROES:
		var rows := []
		for clip in HERO_CLIPS:
			if clip == "counter_cut" and hero != "mitsuhide": continue
			var fighter: Dictionary = sim._make_fighter(0,hero,500,480,120)
			fighter.action = clip
			if clip in ["walk","run","jump"]:
				fighter.action = "idle"
				fighter.moving = clip != "jump"
				fighter.sprinting = clip == "run"
				fighter.z = 25 if clip == "jump" else 0
			elif clip.begins_with("light"):
				fighter.action = "light"
				fighter.combo = int(clip.right(1))
			elif clip.begins_with("heavy"):
				fighter.action = "heavy"
				fighter.heavy_combo = int(clip.right(1))
			rows.append(_inspect(view,fighter,clip))
		report.heroes[hero] = rows
	for faction in Battle.FACTIONS:
		var profiles := {}
		for kind in ["soldier","flag","commander","archer","gunner","boss"]:
			var clips := ["idle","walk","hurt","grabbed","down","recovering","defeated"]
			if kind in ["archer","gunner"]: clips.append_array(["retreat","bow_shot" if kind == "archer" else "gun_shot"])
			elif kind == "boss": clips.append_array(Battle.BOSS_PROFILES[Battle.FACTIONS[faction].boss].actions)
			else: clips.append_array(Battle.ENEMY_ATTACKS[kind])
			var rows := []
			for clip in clips:
				var fighter: Dictionary = sim._make_fighter(1,kind,800,480,100)
				fighter.faction = faction
				fighter.boss_variant = Battle.FACTIONS[faction].boss
				fighter.action = "idle" if clip == "walk" else clip
				fighter.moving = clip in ["walk","retreat"]
				rows.append(_inspect(view,fighter,clip))
			profiles[kind] = rows
		report.enemies[faction] = profiles
	var path := ProjectSettings.globalize_path("res://../docs/character-assets-v15.json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report,"\t") + "\n")
	file.close()
	assert(report.heroes.size() == 6 and report.enemies.size() == 12)
	for rows in report.heroes.values():
		assert(rows.all(func(row: Dictionary) -> bool: return row.has("routes") and not row.routes.is_empty()))
	view.free()
	print("PASS: exported six heroes and twelve factions using actual renderer routes")
	quit()

func _inspect(view, fighter: Dictionary, clip: String) -> Dictionary:
	var sources := {}
	for tick in range(211):
		fighter.action_tick = tick
		view.state = {"tick":tick}
		view._walk_ticks[fighter.id] = tick
		view._walk_distance[fighter.id] = tick * 4.0
		if clip in ["jump","launched"]: fighter.vz = 10.0 - mini(tick,24) * 20.0 / 24.0
		var sample: Dictionary = view._fighter_animation(fighter)
		var key := str(sample.get("source","legacy")) + ":" + str(sample.sheet)
		if not sources.has(key): sources[key] = {"source":sample.get("source","legacy"),"sheet":sample.sheet,"declared_frames":sample.count,"cells":[]}
		if not sources[key].cells.has(sample.cell): sources[key].cells.append(sample.cell)
	for spec in sources.values(): spec["sampled_cells"] = spec.cells.size()
	return {"action":clip,"routes":sources.values()}
