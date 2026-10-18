extends RefCounted
const Mikawa = preload("res://core/stage04_data.gd")
const Ikki = preload("res://core/stage05_data.gd")

const ROOT := "res://audio/peritune-campaign-v1/"
const KEYS := ["s01_bamboo_approach","s01_outpost_battle","s01_matsui_boss","s02_supply_road_battle","s02_fort_battle","s02_sakuma_boss","s03_rain_approach","s03_camp_battle","s03_dual_miniboss","s03_yoshimoto_boss","victory_jingle","victory_loop"]
const BOSSES := {1:"s01_matsui_boss",2:"s02_sakuma_boss",3:"s03_yoshimoto_boss"}

static func combat_near(world: Dictionary) -> bool:
	for prop in world.get("props",[]):
		if prop.get("hp",0) < prop.get("max_hp",0): return true
	for enemy in world.get("fighters",[]):
		if enemy.get("team",0) != 1 or enemy.get("hp",0) <= 0 or enemy.get("entering",false): continue
		for player in world.get("fighters",[]):
			if player.get("team",1) == 0 and player.get("hp",0) > 0 and Vector2(enemy.x-player.x,enemy.y-player.y).length() < 360: return true
	return false

static func select(world: Dictionary, previous: String) -> String:
	var stage: Variant = world.get("stage",{})
	if stage is Dictionary and int(stage.get("id",0)) == 5:
		if world.get("phase","") == "won" and previous=="victory_loop": return "victory_loop"
		return Ikki.music(world)
	if stage is Dictionary and int(stage.get("id",0)) == 4: return Mikawa.music(world)
	if not stage is Dictionary or int(stage.get("id",0)) not in [1,2,3]: return ""
	if world.get("phase","") == "lost": return "silence"
	if world.get("phase","") == "won": return "victory_loop" if previous == "victory_loop" else "victory_jingle"
	var chapter: int = int(stage.id)
	if chapter == 3 and world.get("encounter",{}).get("phase","") in ["awaiting_yoshimoto","yoshimoto"]: return BOSSES[3]
	for fighter in world.get("fighters",[]):
		if fighter.get("team",0) == 1 and fighter.get("kind","") == "boss" and fighter.get("hp",0) > 0:
			return "s03_dual_miniboss" if chapter == 3 else BOSSES[chapter]
	var key: String = str(stage.get("music","legacy"))
	if key in ["s01_bamboo_approach","s03_rain_approach"]:
		var combat := "s01_outpost_battle" if chapter == 1 else "s03_camp_battle"
		# Keep the combat cue after first contact, even when enemies die or separate.
		if previous == combat or combat_near(world): return combat
	return key

static func gain(world: Dictionary, key: String) -> float:
	var amount := .8 if key in ["s01_bamboo_approach","s03_rain_approach"] else 1.0
	if key == "s03_camp_battle" and world.get("stage",{}).get("index",-1) == 0: amount = .85
	if key == "s02_supply_road_battle": amount = .9 if combat_near(world) else .7
	if key in ["s01_matsui_boss","s02_sakuma_boss"] and not world.get("fighters",[]).any(func(f):return f.get("team",0) == 1 and f.get("hp",0) > 0 and f.get("stage_boss",false)): amount = .85
	return .65 * amount

static func fade_seconds(key: String) -> float:
	if key == "victory_jingle": return .18
	if key == "victory_loop" or key in BOSSES.values(): return .25
	if key == "s03_dual_miniboss": return .3
	if key in ["s01_bamboo_approach","s03_rain_approach"]: return 1.2
	return .6

static func mikawa_track(key: String) -> Dictionary:
	for row in Mikawa.read("audio/music/music_map.json").tracks:
		if "s04_"+str(row.role) == key: return row
	return {}
