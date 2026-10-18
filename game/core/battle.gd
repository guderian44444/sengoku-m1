extends RefCounted

const CombatMoves = preload("res://core/combat_moves.gd")

const Stage03Encounter = preload("res://core/stage03_encounter.gd")
const Stage04 = preload("res://core/stage04_encounter.gd")
const Stage05 = preload("res://core/stage05_encounter.gd")
const StageData = preload("res://core/stage_data.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Equipment = preload("res://core/equipment.gd")
const Achievements = preload("res://core/achievements.gd")
const LIGHT := 1
const HEAVY := 2
const JUMP := 4
const GRAB := 8
const SPECIAL := 16
const INTERACT := 32
const CANCEL := 64
const GUARD := 128
const VICTORY_TICKS := 120
const VICTORY_VOICE_TICK := 60
const THROW_TIME_SCALE := 0.65
const LIGHT_TIME_SCALE := 1.3
const NOBUNAGA_HEAVY_RANGE_SCALE := 1.5
const AIR_HEAVY_REACH := 420.0
const AIR_HEAVY_DEPTH := 150.0
const HIDEYOSHI_CHARGED_RANGE_SCALE := 2.0
const HIDEYOSHI_BLINK_STEP := 1280.0 / 9.0
# blade_ring.png outer edge, measured from the texture pivot at alpha 20.
const TADAKATSU_CHARGED_RANGE_SCALE := 1.4
const TADAKATSU_RING_OUTER_X := 0.368
const TADAKATSU_RING_OUTER_Y := 0.160
const TADAKATSU_RING_PIVOT_LIFT := 0.0256
const OICHI_HEAVY_SPEED := 24.0 / 19.0
const PLAYABLE_HEROES := CombatMoves.HEROES
const LIGHT_REACH := {"nobunaga":145.0,"hideyoshi":130.0,"ieyasu":145.0,"mitsuhide":180.0,"tadakatsu":185.0}
const HEROES := ["nobunaga", "oichi", "hideyoshi", "ieyasu", "mitsuhide", "tadakatsu"]
const HERO_PROFILES := {
	"nobunaga": {"attack_speed": 1.0, "move_speed": 1.0, "reach": 1.0, "depth": 1.0, "damage": 1.0, "throw_damage": 31, "element": "fire"},
	"oichi": {"attack_speed": 1.0, "move_speed": 1.0, "reach": 1.0, "depth": 1.0, "damage": 1.0, "throw_damage": 31, "element": "ice"},
	"hideyoshi": {"attack_speed": 1.25, "move_speed": 1.12, "reach": 0.88, "depth": 0.85, "damage": 0.85, "throw_damage": 47, "element": "wind"},
	"ieyasu": {"attack_speed": 0.88, "move_speed": 0.92, "reach": 1.08, "depth": 1.25, "damage": 1.08, "throw_damage": 38, "element": "earth"},
	"mitsuhide": {"attack_speed": 1.12, "move_speed": 1.04, "reach": 1.10, "depth": 0.82, "damage": 0.98, "throw_damage": 28, "element": "blade"},
	"tadakatsu": {"attack_speed": 0.80, "move_speed": 0.86, "reach": 1.48, "depth": 0.78, "damage": 1.25, "throw_damage": 55, "element": "fire"},
}
const FACTIONS := {
	"imagawa": {"ranged": "archer", "boss": "naginata"}, "oda": {"ranged": "gunner", "boss": "matchlock"},
	"saito": {"ranged": "archer", "boss": "hook_yari"}, "miyoshi": {"ranged": "gunner", "boss": "dual_swords"},
	"azai": {"ranged": "archer", "boss": "cross_spear"}, "asakura": {"ranged": "archer", "boss": "nodachi"},
	"takeda": {"ranged": "archer", "boss": "long_yari"}, "ikko": {"ranged": "gunner", "boss": "monk_naginata"},
	"mori": {"ranged": "gunner", "boss": "kusarigama"}, "akechi": {"ranged": "gunner", "boss": "fan_sword"},
	"hashiba": {"ranged": "gunner", "boss": "short_yari"}, "iga": {"ranged": "archer", "boss": "weighted_chain"},
}
const BOSS_PROFILES := {
	"naginata": {"actions": ["boss_sweep", "boss_thrust", "boss_counter"], "speed": 0.95, "reach": 1.08, "damage": 1.0},
	"matchlock": {"actions": ["boss_volley", "boss_dash", "boss_double"], "speed": 1.0, "reach": 0.85, "damage": 1.1},
	"hook_yari": {"actions": ["boss_hook", "boss_thrust", "boss_sweep"], "speed": 0.95, "reach": 1.0, "damage": 1.0},
	"dual_swords": {"actions": ["boss_double", "boss_dash", "boss_counter"], "speed": 1.25, "reach": 0.75, "damage": 0.8},
	"cross_spear": {"actions": ["boss_thrust", "boss_sweep", "boss_hook"], "speed": 0.95, "reach": 1.18, "damage": 1.05},
	"nodachi": {"actions": ["boss_sweep", "boss_smash", "boss_earth"], "speed": 0.75, "reach": 1.2, "damage": 1.25},
	"long_yari": {"actions": ["boss_dash", "boss_thrust", "boss_double"], "speed": 1.05, "reach": 1.35, "damage": 0.95},
	"monk_naginata": {"actions": ["boss_sweep", "boss_earth", "boss_counter"], "speed": 0.85, "reach": 1.15, "damage": 1.1},
	"kusarigama": {"actions": ["boss_sweep", "boss_smash", "boss_chain", "boss_grab_throw"], "speed": 1.0, "reach": 1.0, "damage": 1.0},
	"fan_sword": {"actions": ["boss_counter", "boss_dash", "boss_double"], "speed": 1.15, "reach": 0.9, "damage": 1.1},
	"short_yari": {"actions": ["boss_double", "boss_thrust", "boss_dash"], "speed": 1.2, "reach": 0.8, "damage": 0.85},
	"weighted_chain": {"actions": ["boss_chain", "boss_dash", "boss_double"], "speed": 1.2, "reach": 1.1, "damage": 0.8},
}
const SPECIAL_TICKS := 210
const SPECIAL_HIT_TICKS := {
	"nobunaga": [26, 68, 110, 152, 192], "oichi": [26, 68, 110, 152, 192],
	"hideyoshi": [35, 105, 175], "ieyasu": [36, 102, 168],
	"mitsuhide": [24, 66, 108, 150, 192], "tadakatsu": [36, 84, 132, 180],
}
const ENEMY_SPEED := 0.7
const ENEMY_ROLES := {"shield_spear":"soldier", "fire_archer":"archer", "raider":"commander"}
const DOWN_TICKS := 60
const RECOVER_TICKS := 36
const STARTING_LIVES := 3
const RESPAWN_TICKS := 120
const EXTRA_LIFE_SCORE := 10000
const TALISMANS := Equipment.TREASURES
const KILL_SCORES := {"soldier":100, "flag":150, "commander":300, "archer":150, "gunner":200, "boss":1500}
const ENEMY_ATTACKS := {
	"soldier": ["spear_thrust", "spear_sweep", "spear_butt"],
	"flag": ["flag_poke", "flag_sweep", "flag_slam"],
	"commander": ["commander_cut", "commander_rise", "commander_dash"],
	"boss": ["boss_sweep", "boss_smash", "boss_chain", "boss_grab_throw"],
}
const ENEMY_TIMING := {
	"spear_thrust": [24, 48], "spear_sweep": [32, 57], "spear_butt": [18, 42],
	"flag_poke": [26, 50], "flag_sweep": [34, 62], "flag_slam": [40, 70],
	"commander_cut": [22, 46], "commander_rise": [30, 56], "commander_dash": [30, 60],
	"boss_sweep": [40, 76], "boss_smash": [48, 86], "boss_chain": [26, 92],
	"bow_shot": [30, 62], "gun_shot": [44, 90],
	"boss_thrust": [34, 70], "boss_dash": [34, 76], "boss_volley": [52, 112], "boss_counter": [46, 84],
	"boss_double": [26, 78], "boss_hook": [26, 92], "boss_earth": [54, 100],
	"boss_grab_throw": [26, 92], "boss_arrow": [42, 88], "boss_sword_wave": [50, 100],
	"udono_upthrust":[44,87],"udono_charge":[47,96],"udono_sweep":[45,93],
	"udono_groundsmash":[34,60],"udono_triplequake":[38,150],"udono_melee_spin_counter":[48,87],"udono_ranged_rock_volley":[48,216],
	"tominaga_sweep":[26,69],"tominaga_pursuit":[22,59],"tominaga_heavy_chop":[47,87],
	"kira_arrow":[38,59],"kira_counter":[15,51],"kira_command":[54,150],"kira_volley":[54,100],
}
const DIFFICULTIES := {
	"easy": {"enemy_hp": 0.75, "enemy_damage": 0.65, "player_hp": 140},
	"normal": {"enemy_hp": 1.0, "enemy_damage": 1.0, "player_hp": 120},
	"hard": {"enemy_hp": 1.35, "enemy_damage": 1.3, "player_hp": 105},
}

var state: Dictionary = {}
var _previous_buttons: Array = []
var _queued_buttons: Array = []
var _queued_heavy: Array = []
var _queued_slam: Array = []
var _difficulty: Dictionary = {}
var _next_id := 1
var boss_intros: Dictionary = {}
var boss_deaths: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/v27/deaths.json"))
var _campaign: Dictionary = {}


func _init() -> void:
	reset()


func reset(difficulty: String = "normal", player_count: int = 1, hero_ids: Array = ["nobunaga", "oichi"], faction: String = "mori") -> void:
	_campaign = {}
	if not DIFFICULTIES.has(difficulty):
		difficulty = "normal"
	_difficulty = DIFFICULTIES[difficulty]
	_next_id = 1
	if not FACTIONS.has(faction): faction = "mori"
	_previous_buttons = []
	_queued_buttons = []
	_queued_heavy = []
	_queued_slam = []
	state = {"tick": 0, "phase": "playing", "wave": 1, "fighters": [], "drops": [], "effects": [], "event_seq": 0, "events": [], "difficulty": difficulty, "loot_rng":1,
		"props": [], "wet_zones": [{"x": 700.0, "y": 515.0, "width": 360.0, "depth": 150.0}, {"x": 1650.0, "y": 465.0, "width": 380.0, "depth": 150.0}],
		"civilian_spawn_enabled": true, "civilian_flee_tick": -1, "civilian_flee_x": 0.0, "faction": faction, "intro": {}}
	for i in range(clampi(player_count, 1, 2)):
		var hero: String = str(hero_ids[i]) if i < hero_ids.size() else HEROES[i]
		if not PLAYABLE_HEROES.has(hero):
			hero = PLAYABLE_HEROES[i]
		var fighter := _make_fighter(0, hero, 220.0 + i * 65.0, 460.0 + i * 55.0, int(_difficulty.player_hp))
		fighter.player_index = i
		state.fighters.append(fighter)
		_previous_buttons.append(0)
		_queued_buttons.append(0)
		_queued_heavy.append(-1)
		_queued_slam.append(false)
	_add_drop("weapon", 390.0, 450.0)
	_add_drop("armor", 450.0, 505.0)
	_add_drop("food", 520.0, 465.0)
	_spawn_props()
	_spawn_wave()


func reset_campaign(difficulty: String = "normal", player_count: int = 1, hero_ids: Array = ["nobunaga", "oichi"], chapter_id: int = 1) -> void:
	var campaign := StageData.chapter(chapter_id)
	reset(difficulty, player_count, hero_ids, campaign.faction)
	_campaign = campaign
	_enter_segment(0)


func _enter_segment(index: int) -> void:
	Stage03Encounter.cancel(self)
	state.erase("encounter")
	state.erase("mikawa")
	state.erase("ikki")
	var spec: Dictionary = _campaign.segments[index]
	var party := []
	for old in state.fighters:
		if old.team != 0: continue
		var player := _make_fighter(0, old.kind, 180.0 + old.player_index * 65.0, 450.0 + old.player_index * 65.0, old.max_hp)
		for field in ["id", "player_index", "hp", "max_hp", "max_hp_bonus", "weapon", "weapon_id", "owned_weapons", "armor", "rage", "lives", "score", "next_life_score", "extra_life_tick", "respawn_ticks", "shield_points", "shield_kind"]: player[field] = old[field]
		for field in ["inventory","next_item_uid","weapon_uid","treasure_uid","gold","achievements","bag_uids","bag_only","storage_reserve","performance","performance_awards","achievement_reward_tick","attack_id"]: player[field] = old.get(field,player.get(field,0))
		Equipment.sync(player)
		if player.hp <= 0: player.action = "defeated"
		party.append(player)
	state.fighters = party
	state.effects = []
	state.drops = []
	state.props = []
	state.intro = {}
	state.erase("challenge")
	state.wave = 1
	state.stage = {"id":int(_campaign.id), "index":index, "total":_campaign.segments.size(), "title":str(_campaign.title), "name":str(spec.name),
		"theme":str(spec.theme), "weather":str(spec.weather), "music":str(spec.music), "width":float(spec.width), "civilians":str(spec.civilians),
		"phase":"combat", "go":false, "wave_total":2, "next_wave_tick":-1, "entered_tick":state.tick, "clear_tick":-1,
		"checkpoint":0,"checkpoint_total":spec.encounters.size(),"encounter_start":0.0,"encounter_end":float(spec.encounters[0].end),
		"next_reinforce_tick":-1,"reinforcement_queue":0,"reinforcement_calls":0}
	if _campaign.get("prototype", false): state.stage.prototype = true
	state.civilian_spawn_enabled = spec.civilians != "none"
	state.civilian_flee_tick = -1
	if spec.has("challenge"):
		var challenge: Dictionary = spec.challenge
		state.challenge = {"kind":"reclaim", "x":float(challenge.start_x), "y":float(challenge.y),
			"hp":int(challenge.hp), "max_hp":int(challenge.hp), "reward":int(challenge.reward), "status":"active", "next_hit_tick":0}
	state.wet_zones = [{"x":float(spec.width) * 0.5,"y":495.0,"width":float(spec.width),"depth":210.0}] if spec.weather in ["rain","storm"] else []
	for player in party: cancel_input(player.player_index)
	for row in spec.props:
		var shape: Array = {"jar":[25,50.0,30.0],"basket":[18,54.0,28.0],"crate":[60,74.0,40.0],"large_crate":[150,130.0,58.0],
			"cart":[140,170.0,58.0],"stall":[110,160.0,48.0],"barricade":[160,155.0,52.0],"fence":[110,140.0,36.0],
			"planter":[55,65.0,38.0],"stone_lantern":[240,64.0,40.0],"screen":[85,140.0,38.0],"cabinet":[220,130.0,62.0]}[row[0]]
		var mandatory: bool = row.size() > 4 and row[4]
		var talisman: String = str(row[5]) if row.size() > 5 else ""
		state.props.append({"id":_next_id,"kind":str(row[0]),"x":float(row[1]),"y":float(row[2]),"hp":int(shape[0]),"max_hp":int(shape[0]),
			"width":shape[1],"depth":130.0 if mandatory else shape[2],"broken":false,"drop":"talisman" if TALISMANS.has(talisman) else ("food" if row[3] != "" else ""), "food_id":str(row[3]),"mandatory":mandatory,"talisman_id":talisman})
		_next_id += 1
	_start_checkpoint(0)


func _start_checkpoint(index: int) -> void:
	Stage03Encounter.cancel(self)
	if state.has("encounter"):
		var epoch: int = state.encounter.epoch
		state.fighters = state.fighters.filter(func(f): return f.get("encounter_epoch", -1) != epoch)
		state.props = state.props.filter(func(p): return p.get("encounter_epoch", -1) != epoch)
	state.erase("encounter")
	var region: Dictionary = _campaign.segments[int(state.stage.index)]
	var encounter: Dictionary = region.encounters[index]
	for player in state.fighters:
		if player.team == 0: player.food_state = "ready"
	state.stage.checkpoint = index
	state.stage.encounter_start = 0.0 if index == 0 else float(region.encounters[index - 1].end)
	state.stage.encounter_end = float(encounter.end)
	state.stage.wave_total = 1 if encounter.get("mode", "") in ["alarm", "barriers", "formation", "lieutenants", "ikki"] else encounter.waves.size()
	state.stage.phase = "combat"
	state.stage.go = false
	state.stage.clear_tick = -1
	state.stage.next_reinforce_tick = -1
	state.stage.reinforcement_queue = 0
	state.wave = 1
	_revive_exhausted_party()
	_arm_food_drop()
	if encounter.get("mode", "") in ["alarm", "barriers", "formation", "lieutenants"]: Stage03Encounter.begin(self, encounter)
	elif encounter.get("mode", "") == "ikki":
		state.intro = {}
		Stage05.begin(self,encounter)
	elif encounter.get("mode", "") == "mikawa":
		state.erase("mikawa")
		state.intro = {}
		Stage04.begin(self,encounter)
	else: _spawn_segment_wave()


func _revive_exhausted_party() -> void:
	var party: Array = state.fighters.filter(func(f): return f.team == 0)
	var survivors: Array = party.filter(func(f): return f.hp > 0)
	if party.size() != 2 or survivors.is_empty(): return
	for player in party:
		if player.hp > 0 or player.lives > 0: continue
		player.lives = 1
		player.x = clampf(float(survivors[0].x) - 65.0,_left_edge() + 40.0,_right_edge() - 40.0)
		player.y = survivors[0].y
		player.z = 0.0
		player.airborne_lock = false
		player.respawn_ticks = 1
		_tick_respawn(player)


static func camera_left(world: Dictionary) -> float:
	var party: Array = world.get("fighters",[]).filter(func(f): return f.team == 0)
	var players: Array = party.filter(func(f): return f.hp > 0)
	if players.is_empty(): players = party
	var center := 640.0
	if not players.is_empty():
		center = 0.0
		for player in players: center += float(player.x) / players.size()
	var stage: Dictionary = world.get("stage",{})
	return clampf(center - 640.0,0.0,maxf(0.0,float(stage.get("encounter_end",stage.get("width",2380.0))) - 1280.0))


func _boss_hp(final: bool = false) -> int:
	var player_hp := 0
	for player in state.fighters:
		if player.team == 0: player_hp = maxi(player_hp,int(player.max_hp))
	if player_hp == 0: player_hp = int(_difficulty.player_hp)
	return player_hp * (3 if final else 2)


func _scaled_wave(kinds: Array) -> Array:
	var result := kinds.duplicate()
	var grunts: Array = kinds.filter(func(kind): return kind != "boss")
	var extra := ceili(grunts.size() * 0.5 * (_previous_buttons.size() - 1))
	for index in range(extra): result.append(grunts[index % grunts.size()])
	return result


func _spawn_segment_wave() -> void:
	var spec: Dictionary = _campaign.segments[int(state.stage.index)].encounters[int(state.stage.checkpoint)]
	var kinds := _scaled_wave(spec.waves[int(state.wave) - 1])
	for index in range(kinds.size()):
		var kind: String = kinds[index]
		var hp: int = {"soldier":65,"flag":85,"archer":52,"gunner":62,"commander":125,"boss":350,"shield_spear":90,"fire_archer":58,"raider":82}[kind]
		hp = _boss_hp(bool(spec.boss.final)) if kind == "boss" else maxi(1,roundi(hp * _difficulty.enemy_hp * (1.35 if _previous_buttons.size() == 2 else 1.0)))
		var fighter := _make_fighter(1, kind, 0.0, [395.0,490.0,575.0,440.0,540.0,470.0][index % 6], hp)
		fighter.home_x = fighter.x
		fighter.home_y = fighter.y
		fighter.cooldown = 70
		if kind == "boss":
			fighter.boss_variant = str(spec.boss.get("variant",fighter.boss_variant))
			for field in ["reach_thrust","reach_sweep"]:
				if spec.boss.has(field): fighter[field] = float(spec.boss[field])
			fighter.display_name = str(spec.boss.name)
			fighter.stage_boss = bool(spec.boss.final)
			fighter.render_scale = 1.30 if fighter.stage_boss else 1.0
			fighter.intro_line = str(spec.boss.line)
			fighter.boss_actions = spec.boss.get("actions",["boss_sweep","boss_thrust","boss_counter","boss_earth"] if fighter.stage_boss else ["boss_sweep","boss_thrust","boss_counter","boss_dash"]).duplicate()
		_stage_entry(fighter,index)
		state.fighters.append(fighter)
		if kind == "boss":
			_start_boss_intro(fighter)
			if fighter.stage_boss: state.stage.next_reinforce_tick = state.tick + 1800
	state.stage.next_wave_tick = -1


func _stage_entry(fighter: Dictionary, index: int) -> void:
	var camera := camera_left(state)
	var from_left: bool = index % 2 == 1
	fighter.x = camera - 240.0 - floori(index / 2.0) * 95.0 if from_left else camera + 1520.0 + floori(index / 2.0) * 95.0
	fighter.face = 1 if from_left else -1
	fighter.entering = true
	fighter.entry_x = maxf(camera + 95.0,_left_edge() + 60.0) if from_left else minf(camera + 1185.0,_right_edge() - 60.0)
	for attempt in range(state.props.size()):
		for prop in state.props:
			if not prop.broken and absf(fighter.x - prop.x) < prop.width * 0.5 + 22.0:
				fighter.x = prop.x + (-1.0 if from_left else 1.0) * (prop.width * 0.5 + 22.0)
	# Choose the approach lane while still offscreen, so arrival never needs a visible teleport.
	var open_lane := false
	for lane in [fighter.y,395.0,440.0,490.0,540.0,580.0,360.0,600.0]:
		var blocked := false
		for prop in state.props:
			if prop.broken: continue
			if absf(lane - prop.y) < prop.depth * 0.5 + 13.0 and prop.x + prop.width * 0.5 + 21.0 > minf(fighter.x,fighter.entry_x) and prop.x - prop.width * 0.5 - 21.0 < maxf(fighter.x,fighter.entry_x): blocked = true
		if not blocked:
			fighter.y = lane
			open_lane = true
			break
	# A future checkpoint's full-width barricade can seal the offscreen right approach.
	if not open_lane and not from_left:
		_stage_entry(fighter,index + 1)
		return
	fighter.home_x = fighter.entry_x
	fighter.home_y = fighter.y
	fighter.cooldown = 55


func _place_enemy(fighter: Dictionary) -> void:
	for offset in [0.0,90.0,-90.0,180.0,-180.0,300.0,-300.0,480.0,-480.0,750.0,-750.0]:
		var x := clampf(fighter.x + offset,_left_edge() + 30.0,_right_edge() - 30.0)
		for lane in [fighter.y,395.0,440.0,490.0,540.0,580.0]:
			var occupied := false
			for prop in state.props:
				if not prop.broken and absf(x-prop.x) < prop.width * 0.5 + 38.0 and absf(lane-prop.y) < prop.depth * 0.5 + 28.0: occupied = true
			for other in state.fighters:
				if other.hp > 0 and absf(x-other.x) < 85.0 and absf(lane-other.y) < 52.0: occupied = true
			if occupied: continue
			fighter.x = x
			fighter.y = lane
			fighter.home_x = x
			fighter.home_y = lane
			return
	assert(false,"Stage has no safe enemy entry point")


func _tick_segment() -> void:
	state.fighters = state.fighters.filter(func(f):return f.team == 0 or f.hp > 0 or (f.get("mikawa_role","") == "udono" and state.get("mikawa",{}).get("phase","") == "retreat") or state.tick - f.damage_tick < maxi(240,int(f.get("death_ticks",0)) + 120))
	if not state.intro.is_empty() and _fighter(state.intro.actor).is_empty(): state.intro = {}
	if Stage03Encounter.Tent.finish_victory(self): return
	var living_party: Array = state.fighters.filter(func(f): return f.team == 0 and f.hp > 0)
	if state.fighters.any(func(f): return f.team == 0 and f.hp <= 0 and f.respawn_ticks > 0): return
	if living_party.is_empty():
		state.phase = "lost"
		Stage03Encounter.cancel(self)
		return
	if state.has("ikki"):
		Stage05.tick(self)
		if state.ikki.phase == "complete": _finish_stage_checkpoint(living_party)
		return
	if state.has("mikawa"):
		Stage04.tick(self)
		if state.mikawa.phase == "complete": _finish_stage_checkpoint(living_party)
		return
	if state.has("encounter"):
		Stage03Encounter.tick(self)
		if state.encounter.phase == "complete": _finish_stage_checkpoint(living_party)
		return
	var boss_alive: bool = state.fighters.any(func(f):return f.get("stage_boss",false) and f.hp > 0)
	if boss_alive and state.stage.next_reinforce_tick >= 0:
		if state.tick >= state.stage.next_reinforce_tick:
			state.stage.next_reinforce_tick += 1800
			state.stage.reinforcement_queue += 1
			state.stage.reinforcement_calls += 1
		# Calls queue during an overcrowded fight; existing soldiers must be cleared before more enter.
		if state.stage.reinforcement_queue > 0 and state.fighters.size() <= 48:
			state.stage.reinforcement_queue -= 1
			var boss_spec: Dictionary = _campaign.segments[int(state.stage.index)].encounters[int(state.stage.checkpoint)].get("boss",{})
			var kinds := _scaled_wave(boss_spec.get("reinforcements",["soldier","soldier","archer","flag","soldier","soldier","archer","flag"]))
			for index in range(kinds.size()):
				var reinforcement := _make_fighter(1,kinds[index],0,395.0 + (index % 3) * 90.0,roundi(58 * _difficulty.enemy_hp))
				_stage_entry(reinforcement,index)
				state.fighters.append(reinforcement)
	else:
		state.stage.reinforcement_queue = 0
		state.stage.next_reinforce_tick = -1
	var alive: bool = state.fighters.any(func(f): return f.team == 1 and f.hp > 0)
	if alive: return
	if state.fighters.any(func(f):return f.hp <= 0 and f.action_tick < int(f.get("death_ticks",0))): return
	if state.wave < state.stage.wave_total:
		if state.stage.next_wave_tick < 0: state.stage.next_wave_tick = state.tick + 75
		if state.tick >= state.stage.next_wave_tick:
			state.wave += 1
			_spawn_segment_wave()
		return
	_finish_stage_checkpoint(living_party)


func _finish_stage_checkpoint(living_party: Array) -> void:
	if state.props.any(func(p): return p.get("mandatory",false) and not p.broken and p.x < state.stage.encounter_end): return
	if state.stage.clear_tick < 0: state.stage.clear_tick = state.tick
	if state.tick - state.stage.clear_tick < 45: return
	if state.stage.checkpoint == 0 and state.get("challenge",{}).get("status","") == "active": _complete_cart()
	if state.stage.index == state.stage.total - 1 and state.stage.checkpoint == state.stage.checkpoint_total - 1:
		state.phase = "won"
		return
	state.stage.go = true
	state.stage.phase = "exit"
	for player in living_party:
		if player.x < state.stage.encounter_end - 160.0 or player.z > 0 or player.action != "idle": return
	if state.stage.checkpoint < state.stage.checkpoint_total - 1: _start_checkpoint(int(state.stage.checkpoint) + 1)
	else: _enter_segment(int(state.stage.index) + 1)


func _complete_cart() -> void:
	var cart: Dictionary = state.challenge
	cart.status = "complete"
	for player in state.fighters:
		if player.team == 0: player.gold = mini(1000000000,int(player.gold) + int(cart.reward))
	_event("challenge_complete",cart.x,cart.y,0,0,{"amount":int(cart.reward)})


func _damage_cart(attacker: Dictionary, reach: float, depth: float, amount: int) -> void:
	if attacker.get("team",1) != 1 or not state.has("challenge"): return
	var cart: Dictionary = state.challenge
	if cart.status != "active" or state.tick < cart.next_hit_tick: return
	var ahead: float = (cart.x - attacker.x) * attacker.face
	if ahead < -15.0 or ahead > reach or absf(cart.y - attacker.y) > depth: return
	_hurt_cart(maxi(1,roundi(amount * _difficulty.enemy_damage)),int(attacker.id))

func _hurt_cart(amount: int, owner: int) -> void:
	if not state.has("challenge"): return
	var cart: Dictionary = state.challenge
	if cart.status != "active" or state.tick < cart.next_hit_tick: return
	cart.hp = maxi(0,int(cart.hp) - amount)
	cart.next_hit_tick = state.tick + 90
	_effect("hit",cart.x,cart.y,12,{"heavy":true})
	if cart.hp == 0:
		cart.status = "failed"
		_event("challenge_failed",cart.x,cart.y,owner,0)


func get_state() -> Dictionary:
	return state.duplicate(true)


func reset_training(hero: String = "nobunaga", drill: String = "dummy", faction: String = "mori") -> void:
	reset("normal", 1, [hero], faction)
	var player: Dictionary = state.fighters[0]
	player.x = 500.0
	player.y = 480.0
	if not drill in ["dummy", "shield", "enemies", "ranged", "boss"]: drill = "dummy"
	player.rage = 100 if drill == "dummy" else 0
	state.fighters = [player]
	if drill in ["dummy", "shield"]:
		state.fighters.append(_make_fighter(1, "dummy", 585.0, 480.0, 1000))
	state.drops = []
	state.mode = "training"
	state.training = {"drill": drill, "free_special": drill == "dummy", "wave_clear_tick": -1, "hit_count": 0, "last_damage": 0, "total_damage": 0, "chain_hits": 0, "last_hit_tick": -120, "last_damage_tick": -120, "last_action": "", "last_stage": 0}
	if drill == "shield":
		state.fighters.append(_make_fighter(1, "soldier", 725.0, 480.0, 70))
		state.fighters.append(_make_fighter(1, "archer", 1100.0, 480.0, 70))
	if drill == "enemies":
		player.x = 360.0
		_spawn_wave()
	elif drill == "ranged":
		state.fighters.append(_make_fighter(1, "archer", 810.0, 430.0, 100))
		state.fighters.append(_make_fighter(1, "gunner", 1080.0, 535.0, 110))
	elif drill == "boss":
		state.fighters.append(_make_fighter(1, "boss", 830.0, 480.0, _boss_hp()))
		_start_boss_intro(state.fighters[-1])
	for fighter in state.fighters:
		fighter.home_x = fighter.x
		fighter.home_y = fighter.y


func cancel_input(player_index: int = 0) -> void:
	if player_index < 0 or player_index >= _previous_buttons.size():
		return
	_previous_buttons[player_index] = 0
	_queued_buttons[player_index] = 0
	_queued_heavy[player_index] = -1
	_queued_slam[player_index] = false
	for fighter in state.fighters:
		if fighter.team == 0 and fighter.player_index == player_index:
			_release_grab(fighter, false)
			fighter.combo = 0
			fighter.combo_tick = 0
			fighter.heavy_combo = 0
			fighter.heavy_combo_tick = 0
			fighter.mixed_ready = false
			fighter.sprinting = false
			fighter.move_dx = 0
			fighter.sprint_ticks = 0
			fighter.move_dy = 0
			fighter.tap_tick = -1000
			if not fighter.airborne_lock and fighter.action not in ["hurt", "down", "recovering", "stunned", "frozen", "pulled", "defeated", "special", "victory"]:
				fighter.charge = 0
				_begin(fighter, "idle")


func step(inputs: Array) -> void:
	state.events = []
	_arm_food_drop()
	if not state.intro.is_empty() and state.intro.remaining_ticks > 0:
		if not state.intro.announced:
			state.intro.announced = true
			_event("boss_intro", 0.0, 0.0, state.intro.actor, 0, {"name": state.intro.name, "line_key": state.intro.line_key})
		state.intro.remaining_ticks -= 1
		if state.intro.get("blocking",false): return
	if state.phase != "playing":
		Stage03Encounter.cancel(self)
		if state.phase == "won" and state.get("victory_looting",false):
			state.tick += 1
			for fighter in state.fighters:
				_tick_motion(fighter)
				if fighter.team != 0 or fighter.hp <= 0: continue
				_tick_fighter(fighter)
				var index: int = fighter.player_index
				var input: Dictionary = inputs[index] if index < inputs.size() and inputs[index] is Dictionary else {}
				var loot_input := input.duplicate()
				loot_input.buttons = int(input.get("buttons",0)) & (INTERACT | JUMP | CANCEL)
				_player_input(fighter,loot_input,index)
			return
		# Land existing launches and finish the celebration without accepting combat input.
		var settling: bool = state.phase == "lost" and not state.effects.is_empty()
		for fighter in state.fighters:
			settling = settling or fighter.z > 0 or fighter.vz > 0 or absf(fighter.knockback) > 0.1 or (fighter.hp <= 0 and fighter.action_tick < int(fighter.get("death_ticks",24)))
			if state.phase == "won" and fighter.team == 0 and fighter.hp > 0:
				fighter.freeze = 0
				settling = settling or fighter.action != "victory" or fighter.action_tick < VICTORY_TICKS
		if settling:
			state.tick += 1
			for fighter in state.fighters: _tick_motion(fighter)
			if state.phase == "lost": _tick_effects()
		if state.phase == "won":
			state.effects.clear()
			for fighter in state.fighters:
				if fighter.team == 0 and fighter.hp > 0:
					_tick_victory(fighter)
		return
	if Stage03Encounter.Tent.transition_step(self): return
	state.tick += 1
	_sync_grabs()
	_tick_effects()
	for fighter in state.fighters:
		_tick_motion(fighter)
		if fighter.hp <= 0:
			if fighter.team == 0: _tick_respawn(fighter)
			continue
		if fighter.team == 0:
			var index: int = fighter.player_index
			var input: Dictionary = inputs[index] if index < inputs.size() and inputs[index] is Dictionary else {}
			_steer_heavy(fighter,input)
		_tick_fighter(fighter)
		if fighter.hp <= 0:
			continue
		if fighter.team == 0:
			var index: int = fighter.player_index
			var input: Dictionary = inputs[index] if index < inputs.size() and inputs[index] is Dictionary else {}
			_player_input(fighter, input, index)
		else:
			_enemy_input(fighter)
	_sync_grabs()
	_resolve_throws()
	_check_achievements()
	if state.get("mode", "") == "training":
		_tick_training()
		return
	if state.has("stage"):
		_tick_segment()
		return
	var players_alive := false
	var enemies_alive := false
	var respawning := false
	for fighter in state.fighters:
		if fighter.team == 0 and fighter.respawn_ticks > 0:
			players_alive = true
			respawning = true
		if fighter.hp > 0:
			if fighter.team == 0:
				players_alive = true
			else:
				enemies_alive = true
	if not players_alive:
		state.phase = "lost"
	elif not enemies_alive and not respawning:
		if state.wave == 3:
			state.phase = "won"
		else:
			state.wave += 1
			_spawn_wave()


func _tick_victory(fighter: Dictionary) -> void:
	fighter.sprinting = false
	fighter.burn = 0
	fighter.poison = 0
	fighter.stun = 0
	fighter.guard_hit_tick = 0
	fighter.invuln = 0
	fighter.charge = 0
	if fighter.z > 0 or fighter.vz > 0 or absf(fighter.knockback) > 0.1: return
	if fighter.action in ["down", "recovering"]:
		fighter.action_tick += 1
		if fighter.action_tick >= (fighter.down_ticks if fighter.action == "down" else RECOVER_TICKS):
			_begin(fighter, "recovering" if fighter.action == "down" else "victory")
		return
	if fighter.action != "victory":
		_release_grab(fighter, false)
		if fighter.held_by != 0:
			var holder := _fighter(fighter.held_by)
			if not holder.is_empty(): _release_grab(holder, false, true)
		_begin(fighter, "victory")
	else:
		fighter.action_tick = mini(VICTORY_TICKS, fighter.action_tick + 1)


func _tick_training() -> void:
	if state.training.free_special: state.fighters[0].rage = 100
	if state.tick - state.training.last_hit_tick > 60:
		state.training.chain_hits = 0
	for fighter in state.fighters:
		if state.tick - fighter.damage_tick < maxi(120,int(fighter.get("death_ticks",0)) + 60) or fighter.held_by != 0 or fighter.grab_target != 0:
			continue
		if fighter.team == 0:
			fighter.hp = fighter.max_hp
		elif state.training.drill != "enemies" and (fighter.kind == "dummy" and fighter.action == "idle" or fighter.hp <= 0) and fighter.z == 0.0 and fighter.knockback == 0.0:
			fighter.hp = fighter.max_hp
			fighter.x = fighter.home_x
			fighter.y = fighter.home_y
			fighter.poison = 0
			fighter.burn = 0
			fighter.freeze = 0
			fighter.stun = 0
			_begin(fighter, "idle")
	if state.training.drill == "enemies":
		var alive: bool = state.fighters.any(func(fighter: Dictionary) -> bool: return fighter.team == 1 and fighter.hp > 0)
		if not alive:
			if state.training.wave_clear_tick < 0: state.training.wave_clear_tick = state.tick
			if state.tick - state.training.wave_clear_tick >= 90:
				if state.wave == 3:
					state.phase = "won"
				else:
					state.wave += 1
					state.training.wave_clear_tick = -1
					_spawn_wave()


func _make_fighter(team: int, kind: String, x: float, y: float, hp: int) -> Dictionary:
	var role := kind if team == 1 and ENEMY_ROLES.has(kind) else ""
	if role != "": kind = ENEMY_ROLES[role]
	var fighter := {
		"id": _next_id, "team": team, "kind": kind, "x": x, "y": y, "z": 0.0, "vz": 0.0,
		"hp": hp, "max_hp": hp, "rage": 0, "face": 1 if team == 0 else -1,
		"lives": STARTING_LIVES if team == 0 else 0, "score":0, "next_life_score":EXTRA_LIFE_SCORE, "extra_life_tick":-1000, "respawn_ticks":0,
		"shield_points":0, "shield_kind":"",
		"action": "idle", "action_tick": 0, "charge": 0, "armor": 0, "weapon": 0,
		"weapon_id":Weapons.default_for(kind) if team == 0 else "", "owned_weapons":[Weapons.default_for(kind)] if team == 0 else [], "max_hp_bonus":0,
		"invuln": 0, "poison": 0, "poison_tick": 0, "poison_owner": 0,
		"combo": 0, "combo_tick": 0, "light_recovery_ticks": 0, "player_index": -1, "target_x": x, "target_y": y,
		"cooldown": 20, "knockback": 0.0, "heavy_combo": 0, "heavy_combo_tick": 0,
		"weight": "heavy" if kind == "boss" else ("medium" if kind == "nobunaga" else "light"),
		"grab_target": 0, "held_by": 0, "thrown_by": 0, "throw_ticks": 0, "throw_hits": [],
		"stun": 0, "shield_hurt_tick": 0, "damage_tick": 0,
		"burn": 0, "burn_tick": 0, "burn_owner": 0, "freeze": 0, "freeze_owner": 0, "shattered_tick": -1,
		"charge_direction": 0, "mixed_ready": false, "mixed_tick": 0, "last_attack": "",
		"attack_variant": 0, "ai_cycle": 0, "chain_target": 0, "pull_owner": 0,
		"sprinting": false, "sprint_dx": 0, "sprint_dy": 0, "move_dx": 0, "move_dy": 0,
		"sprint_ticks": 0,
		"tap_dx": 0, "tap_dy": 0, "tap_tick": -1000, "bump_cooldown": 0, "guard_hit_tick": 0,
		"airborne_lock": false, "bounces_left": 0, "landing_count": 0, "down_ticks": DOWN_TICKS, "down_from_air": false,
		"counter_ticks": 0, "faction": state.get("faction", "mori") if team == 1 else "heroes", "boss_variant": FACTIONS[state.get("faction", "mori")].boss if kind == "boss" else "",
	}
	_next_id += 1
	if role != "": fighter.role = role
	if team == 0:
		Equipment.ensure(fighter)
		fighter.food_state = "ready"
		fighter.bag_only = true
		fighter.storage_reserve = 0
		fighter.attack_id = 0
		fighter.attack_speed = 1.0
		fighter.performance = {}
		fighter.performance_awards = []
		fighter.achievement_reward_tick = -Achievements.REWARD_COOLDOWN
	return fighter


func _tick_respawn(player: Dictionary) -> void:
	if player.respawn_ticks <= 0: return
	player.respawn_ticks -= 1
	if player.respawn_ticks > 0: return
	# Finish the fall before getting up, including deaths caused by a throw.
	if player.z > 0 or player.airborne_lock:
		player.respawn_ticks = 1
		return
	var restored := _make_fighter(0,player.kind,clampf(player.x,_left_edge(),_right_edge()),player.y,player.max_hp)
	for field in ["id","player_index","lives","score","next_life_score","extra_life_tick","weapon","weapon_id","owned_weapons","max_hp_bonus","armor","face"]: restored[field] = player[field]
	for field in ["inventory","next_item_uid","weapon_uid","treasure_uid","gold","achievements","bag_uids","bag_only","storage_reserve","performance","performance_awards","achievement_reward_tick","attack_id","food_state"]: restored[field] = player[field]
	player.merge(restored,true)
	Equipment.sync(player)
	_begin(player,"recovering")
	player.invuln = 180
	player.pickup_flash_tick = state.tick
	cancel_input(player.player_index)
	_event("revive",player.x,player.y,player.id,player.id)


func _award_score(owner: int, points: int) -> void:
	if state.has("training"): return
	var player := _fighter(owner)
	if player.is_empty() or player.team != 0 or points <= 0: return
	player.score += points
	while player.score >= player.next_life_score:
		player.next_life_score += EXTRA_LIFE_SCORE
		player.lives += 1
		player.extra_life_tick = state.tick
		if player.hp <= 0 and player.respawn_ticks == 0: player.respawn_ticks = RESPAWN_TICKS
		_event("extra_life",player.x,player.y,player.id,player.id)


static func nobunaga_heavy_reach(combo: int) -> float:
	return 230.0 if combo == 2 else 200.0


func _spawn_wave() -> void:
	var x: float = [650.0, 1340.0, 2100.0][int(state.wave) - 1]
	if state.has("training"): x = clampf(state.fighters[0].x + 320.0, 540.0, 1930.0)
	var ranged: String = FACTIONS[state.faction].ranged
	var kinds: Array = _scaled_wave(["soldier", "soldier", "flag", ranged] if state.wave == 1 else (["commander", "soldier", "archer", ranged] if state.wave == 2 else ["boss"]))
	for index in range(kinds.size()):
		var kind: String = kinds[index]
		var hp: int = {"soldier": 70, "flag": 90, "archer": 55, "gunner": 65, "commander": 150, "boss": 420}[kind]
		hp = _boss_hp() if kind == "boss" else int(hp * _difficulty.enemy_hp)
		var fighter := _make_fighter(1, kind, clampf(x + index * 70.0, 80.0, 2280.0), [440.0, 550.0, 390.0, 490.0, 585.0][index % 5], hp)
		fighter.home_x = fighter.x
		fighter.home_y = fighter.y
		state.fighters.append(fighter)
		if kind == "boss": _start_boss_intro(fighter)
	if state.wave == 2 and not state.has("training"): _add_drop("food", 1130.0, 460.0)


func _start_boss_intro(boss: Dictionary) -> void:
	var key: String = str(boss.get("display_name",state.faction))
	if not boss_intros.has(key): key = "" if boss.has("intro_line") else state.faction
	var intro: Dictionary = boss_intros.get(key,{})
	var duration := clampi(int(intro.get("ticks", 180)), 1, 1800)
	state.intro = {"actor":boss.id,"name":str(boss.get("display_name",intro.get("name",""))),"line_key":str(intro.get("line_key","")),"remaining_ticks":duration,"duration":duration,"announced":false,"blocking":false}
	if boss.has("intro_line"): state.intro.line = boss.intro_line


func _right_edge() -> float:
	return float(state.stage.encounter_end) - 60.0 if state.has("stage") else 2300.0


func _left_edge() -> float:
	return 80.0


func _move_fighter(fighter: Dictionary, dx: float, dy: float = 0.0, shove: bool = false) -> void:
	var obstacles := []
	if not shove and Stage04.in_mud(state,fighter): dx *= .65; dy *= .65
	for prop in state.props:
		if prop.has("mikawa_asset"): continue
		if not prop.broken: obstacles.append(Rect2(prop.x - prop.width * 0.5 - 20.0, prop.y - prop.depth * 0.5 - 12.0, prop.width + 40.0, prop.depth + 24.0))
	for other in state.fighters:
		# Blink cuts cross bodies; scenery, barriers and co-op bounds still apply.
		if CombatMoves.active(fighter) and fighter.kind == "hideyoshi" and fighter.action == "charged": continue
		if other.id == fighter.id or other.team == fighter.team or other.hp <= 0 or other.held_by != 0 or other.airborne_lock: continue
		if other.team == 1 and other.action in ["down","recovering"]: continue
		if absf(fighter.knockback) > 0.1 or fighter.airborne_lock: continue
		var radius := 25.0 * float(other.get("render_scale",1.0)) + 20.0
		if shove and absf(other.y - fighter.y) < 30.0 and (other.x - fighter.x) * signf(dx) > 0 and absf(other.x - fighter.x) < radius + absf(dx) + 4.0:
			if other.kind != "boss" and other.weight != "heavy":
				if fighter.sprinting and fighter.action == "idle" and other.bump_cooldown == 0 and _damage(other,6,fighter.id,false):
					other.bump_cooldown = 40
					other.knockback = signf(dx) * 12.0
					_event("run_bump",other.x,other.y,fighter.id,other.id)
				if other.knockback * dx > 0: continue
		obstacles.append(Rect2(other.x - radius,other.y - 28.0,radius * 2.0,56.0))
	var start_x: float = fighter.x
	var start_y: float = fighter.y
	var next_x := start_x + dx if fighter.get("entering",false) else clampf(start_x + dx,_left_edge(),_right_edge())
	var next_y := clampf(start_y + dy,360.0,600.0)
	if fighter.team == 0 and state.has("stage"):
		for partner in state.fighters:
			if partner.team == 0 and partner.id != fighter.id and partner.hp > 0: next_x = clampf(next_x,partner.x - 860.0,partner.x + 860.0)
	for box in obstacles:
		if start_y > box.position.y and start_y < box.end.y:
			if dx > 0 and start_x <= box.position.x: next_x = minf(next_x,box.position.x)
			elif dx < 0 and start_x >= box.end.x: next_x = maxf(next_x,box.end.x)
			elif box.has_point(Vector2(start_x,start_y)) and absf(next_x - box.get_center().x) < absf(start_x - box.get_center().x): next_x = start_x
	for box in obstacles:
		if next_x > box.position.x and next_x < box.end.x:
			if dy > 0 and start_y <= box.position.y: next_y = minf(next_y,box.position.y)
			elif dy < 0 and start_y >= box.end.y: next_y = maxf(next_y,box.end.y)
			elif box.has_point(Vector2(start_x,start_y)) and absf(next_y - box.get_center().y) < absf(start_y - box.get_center().y): next_y = start_y
	if state.has("mikawa") and not Stage04.passes_barrier(fighter):
		for prop in state.props:
			if prop.broken or prop.get("mikawa_asset","") not in ["fence","cheval"]: continue
			if Stage04.barrier_blocks(prop,Vector2(start_x,start_y),Vector2(next_x,start_y)): next_x = start_x
			if Stage04.barrier_blocks(prop,Vector2(next_x,start_y),Vector2(next_x,next_y)): next_y = start_y
	fighter.x = next_x
	fighter.y = next_y


static func tadakatsu_charged_area(fighter: Dictionary) -> Dictionary:
	var reach := LIGHT_REACH.tadakatsu * 1.15
	reach += float(Weapons.item(str(fighter.get("weapon_id",""))).get("reach_bonus",0)) + Equipment.bonus(fighter,"reach_bonus")
	reach *= float(HERO_PROFILES.tadakatsu.reach) * TADAKATSU_CHARGED_RANGE_SCALE
	var size := reach / TADAKATSU_RING_OUTER_X
	return {"reach": reach, "depth": reach * TADAKATSU_RING_OUTER_Y / TADAKATSU_RING_OUTER_X, "behind": reach, "size": size, "lift": size * TADAKATSU_RING_PIVOT_LIFT}

static func hero_tick(kind: String, tick: int) -> int:
	return maxi(1, roundi(tick / float(HERO_PROFILES.get(kind, HERO_PROFILES.nobunaga).attack_speed)))

static func fighter_tick(fighter: Dictionary, tick: int) -> int:
	return maxi(1,roundi(tick / (float(HERO_PROFILES[fighter.kind].attack_speed) * float(fighter.get("attack_speed",1.0)) * (1.0+Equipment.bonus(fighter,"attack_speed_bonus")))))

static func character_stats(row: Dictionary, difficulty: String = "normal") -> Dictionary:
	var hero := str(row.get("hero",row.get("kind","nobunaga")))
	var profile: Dictionary = HERO_PROFILES[hero]
	var weapon := Weapons.item(str(row.weapon_id))
	var base: int = 24 if hero == "oichi" else 16
	var damage: int = base + int(weapon.get("damage_bonus",0)) + int(Equipment.bonus(row,"damage_bonus"))
	var reach: float = (760.0 if hero == "oichi" else LIGHT_REACH[hero]) + float(weapon.get("reach_bonus",0)) + Equipment.bonus(row,"reach_bonus")
	if hero != "oichi":
		damage = maxi(1,roundi(damage * profile.damage))
		reach *= profile.reach
	if hero == "hideyoshi": reach *= 1.3 # Match the baseline's light-attack range on the equipment panel.
	damage = maxi(1,roundi(damage*Equipment.damage_multiplier(row,"heavy" if hero == "oichi" else "light")))
	var charm := Equipment.instance(row,int(row.treasure_uid))
	var protection := "無"
	if not charm.is_empty(): protection = "吸收 %d" % charm.durability if Equipment.TREASURES[charm.item_id].mode == "fixed" else "減傷 %.1f%%" % (Equipment.reduction(row) * 100)
	return {"hp":int(DIFFICULTIES[difficulty].player_hp) + int(row.get("max_hp_bonus",0)),"damage":damage,"attack_speed":roundi(profile.attack_speed * float(weapon.get("attack_speed",1)) * (1+Equipment.bonus(row,"attack_speed_bonus")) * 100),"speed":3.5 * (profile.move_speed * (1+Equipment.bonus(row,"move_bonus")) + float(weapon.get("move_bonus",0))),"reach":reach,"knockback":float(weapon.get("knockback",0))+Equipment.bonus(row,"knockback_bonus"),"throw_damage":roundi(float(profile.throw_damage)*Equipment.damage_multiplier(row,"throw")),"protection":protection}


const FAST_PROJECTILE_SPEED := 34.0
const HERO_ARROW_SPEED := 22.0

static func enemy_timing(fighter: Dictionary) -> Array:
	if fighter.has("s05_role") and Stage05.Data.HITS.has(fighter.action): return Stage05.Data.timing(fighter)
	if fighter.has("mikawa_role"): return Stage04.Data.attack_timing(fighter)
	var timing: Array = ENEMY_TIMING.get(fighter.action, [30, 60])
	if fighter.get("is_yoshimoto",false) and fighter.action in ["boss_arrow","boss_sword_wave"]: return timing
	if fighter.kind != "boss": return timing
	var speed: float = BOSS_PROFILES.get(fighter.get("boss_variant", ""), BOSS_PROFILES.kusarigama).speed
	if fighter.has("lieutenant_slot"): speed *= 1.25
	return [roundi(timing[0] / speed), roundi(timing[1] / speed)]


func _tick_motion(fighter: Dictionary) -> void:
	if fighter.get("entering",false): return
	if CombatMoves.active(fighter) and fighter.kind == "nobunaga" and fighter.action == "air_heavy": return
	if fighter.hp <= 0:
		fighter.action_tick = mini(int(fighter.get("death_ticks",24)), fighter.action_tick + 1)
		if fighter.kind == "boss" and not fighter.airborne_lock and fighter.z == 0: fighter.knockback = 0.0
	if fighter.held_by != 0 or fighter.freeze > 0 or fighter.action == "pulled":
		return
	if absf(fighter.knockback) > 0.1:
		_move_fighter(fighter,fighter.knockback)
		fighter.knockback *= 0.992 if fighter.airborne_lock else 0.9
	else:
		fighter.knockback = 0.0
	if fighter.z > 0.0 or fighter.vz > 0.0:
		var falling: bool = fighter.vz < 0.0
		fighter.z = maxf(0.0, fighter.z + fighter.vz)
		fighter.vz -= 0.55
		if fighter.z == 0.0:
			fighter.vz = 0.0
			if falling:
				fighter.landing_count += 1 if fighter.airborne_lock else 0
				_landing(fighter)
				if fighter.airborne_lock and fighter.bounces_left > 0:
					fighter.bounces_left -= 1
					fighter.vz = 3.8 if fighter.landing_count == 1 else 2.7
					fighter.z = 1.0
					fighter.knockback *= 0.45
				elif fighter.airborne_lock:
					fighter.airborne_lock = false
					fighter.knockback = 0.0
					if fighter.hp > 0 or fighter.kind != "boss": _begin(fighter, "defeated" if fighter.hp <= 0 else "down")
					fighter.down_from_air = true
	if fighter.throw_ticks > 0:
		fighter.throw_ticks -= 1
		if fighter.throw_ticks == 0:
			fighter.thrown_by = 0
			if fighter.action == "thrown" and not fighter.airborne_lock:
				_begin(fighter, "defeated" if fighter.hp <= 0 else "down")
				fighter.down_from_air = true


func _tick_fighter(fighter: Dictionary) -> void:
	fighter.shield_hurt_tick = maxi(0, fighter.shield_hurt_tick - 1)
	fighter.stun = maxi(0, fighter.stun - 1)
	fighter.invuln = maxi(0, fighter.invuln - 1)
	fighter.cooldown = maxi(0, fighter.cooldown - 1)
	fighter.light_recovery_ticks = maxi(0, int(fighter.get("light_recovery_ticks",0)) - 1)
	fighter.bump_cooldown = maxi(0, fighter.bump_cooldown - 1)
	fighter.guard_hit_tick = maxi(0, fighter.guard_hit_tick - 1)
	fighter.counter_ticks = maxi(0, fighter.counter_ticks - 1)
	fighter.mixed_tick = maxi(0, fighter.mixed_tick - 1)
	if fighter.mixed_tick == 0: fighter.last_attack = ""
	if fighter.burn > 0:
		fighter.burn -= 1
		fighter.burn_tick += 1
		if fighter.burn_tick >= 30:
			fighter.burn_tick = 0
			if _damage(fighter, 3, fighter.burn_owner, false, false,false,false,NAN,NAN,str(fighter.get("element_action","")),24,"",int(fighter.get("element_weapon_uid",-1)),int(fighter.get("element_attack_id",-1)),"fire"):
				_effect("fire_hit", fighter.x, fighter.y - fighter.z, 12, {"target": fighter.id})
				if fighter.team == 1 and state.has("training"): state.training.last_action = "burn"
	if fighter.freeze > 0:
		fighter.freeze -= 1
		if fighter.freeze == 0 and fighter.action == "frozen": _begin(fighter, "launched" if fighter.airborne_lock else "idle")
		return
	fighter.combo_tick = maxi(0, fighter.combo_tick - 1)
	if fighter.combo_tick == 0:
		fighter.combo = 0
	fighter.heavy_combo_tick = maxi(0, fighter.heavy_combo_tick - 1)
	if fighter.heavy_combo_tick == 0 and fighter.action != "charge":
		fighter.heavy_combo = 0
	if fighter.poison > 0:
		fighter.poison -= 1
		fighter.poison_tick += 1
		if fighter.poison_tick >= 30:
			fighter.poison_tick = 0
			_damage(fighter, 3, fighter.poison_owner, false, false,false,false,NAN,NAN,"",24,"",int(fighter.get("poison_weapon_uid",-1)))
	if fighter.hp <= 0:
		return
	fighter.action_tick += 1
	if Stage03Encounter.Tent.Yoshimoto.tick_action(self,fighter): return
	if fighter.airborne_lock: return
	if Stage05.attack(self,fighter) or Stage05.reaction_tick(self,fighter): return
	if ENEMY_TIMING.has(fighter.action):
		_tick_enemy_attack(fighter)
		return
	if CombatMoves.active(fighter) and _tick_combat_v33(fighter): return
	match fighter.action:
		"windup":
			var boss: bool = fighter.kind == "boss"
			var archer: bool = fighter.kind == "archer"
			var strike_tick := 58 if boss else (30 if archer else 35)
			if fighter.action_tick == strike_tick:
				if archer:
					_projectile(fighter, maxi(1, int(9 * _difficulty.enemy_damage)), 0, false, "arrow", 900.0)
				else:
					_enemy_strike(fighter, 175.0 if boss else 85.0, 75.0 if boss else 42.0, 26 if boss else 10)
			if fighter.action_tick >= strike_tick + 28:
				fighter.cooldown = 90 if archer else (48 if boss else 40)
				_begin(fighter, "idle")
		"hurt":
			if fighter.action_tick >= 18:
				_begin(fighter, "idle")
		"down":
			if fighter.action_tick >= fighter.down_ticks:
				_begin(fighter, "recovering")
		"recovering":
			if fighter.action_tick >= (ceili(Stage04.Data.duration(str(fighter.mikawa_role),"recovery")*.06) if fighter.has("mikawa_role") and fighter.mikawa_role != "udono" else RECOVER_TICKS):
				_begin(fighter, "idle")
				if fighter.team == 1 and fighter.kind == "boss": _boss_getup(fighter)
				elif fighter.team == 0: _player_getup(fighter)
		"stunned":
			if fighter.stun == 0: _begin(fighter, "idle")
		"guard":
			if fighter.team == 1 and fighter.action_tick >= 16: _begin(fighter, "idle")
		"pulled":
			var owner := _fighter(fighter.pull_owner)
			if owner.is_empty() or owner.hp <= 0 or owner.action not in ["boss_chain", "boss_hook", "boss_grab_throw"]:
				fighter.pull_owner = 0
				_begin(fighter, "idle")
			else:
				fighter.x = move_toward(fighter.x, owner.x + owner.face * 58.0, 15.0)
				fighter.y = move_toward(fighter.y, owner.y, 6.0)
				fighter.z = move_toward(fighter.z, 0.0, 8.0)


func _steer_heavy(fighter: Dictionary, input: Dictionary) -> void:
	if fighter.freeze > 0 or fighter.airborne_lock or int(input.get("buttons",0)) & CANCEL: return
	if fighter.action not in ["charge","heavy","charged","charge_rain","air_heavy","dash_heavy"]: return
	var dx := clampi(int(input.get("dx",0)),-1,1)
	if dx != 0: fighter.face = dx

func _player_input(fighter: Dictionary, input: Dictionary, index: int) -> void:
	if int(input.get("buttons", 0)) & CANCEL:
		cancel_input(index)
		return
	_steer_heavy(fighter,input)
	var buttons := int(input.get("buttons", 0)) & (LIGHT | HEAVY | JUMP | GRAB | INTERACT | GUARD)
	var pressed: int = buttons & ~int(_previous_buttons[index])
	var released: int = int(_previous_buttons[index]) & ~buttons
	_previous_buttons[index] = buttons
	var dx := clampi(int(input.get("dx", 0)), -1, 1)
	var dy := clampi(int(input.get("dy", 0)), -1, 1)
	assert(CombatMoves.active(fighter),"Unavailable player character")
	_update_sprint(fighter,dx,dy,input.get("stick_full"))
	_combat_input_v33(fighter,buttons,pressed,released,dx,dy,index)

func _release_heavy(fighter: Dictionary) -> void:
	var full: bool = float(fighter.charge)*1000/60 >= float(CombatMoves.registration(str(fighter.kind)).clips.charge_ready.duration_ms)
	_begin(fighter,"charge_rain" if full and fighter.kind == "oichi" and fighter.charge_direction < 0 else ("charged" if full else "heavy"))
	if not full:
		# Credit time already spent charging; a short tap must still finish its windup.
		var contact := float(CombatMoves.spec(fighter).events[0].ms)
		fighter.action_tick = 1
		fighter.action_tick = mini(int(fighter.charge),ceili(contact / combat_time_ms(fighter)))
		_tick_combat_v33(fighter)


static func combat_time_ms(fighter: Dictionary, tick_offset: int = 0) -> float:
	var tick := maxf(0, float(fighter.get("action_tick",0)) - tick_offset)
	if CombatMoves.active(fighter) and fighter.kind == "hideyoshi" and fighter.get("action","") == "charged": return tick*1000.0/60.0
	var air_shot: bool = fighter.get("kind","") == "oichi" and fighter.get("action","") == "air_heavy"
	var new_air: bool = fighter.get("kind","") not in ["nobunaga","oichi"] and fighter.get("action","") in ["air_light","air_heavy"]
	if CombatMoves.active(fighter) and (fighter.get("action","") == "light" or air_shot or new_air):
		var spec := CombatMoves.spec(fighter)
		var contact := float(spec.events[0].ms)
		var hit_tick := fighter_tick(fighter,10 if new_air else 6)
		var end_tick := fighter_tick(fighter,27 if air_shot or new_air else 19)
		if not air_shot and not new_air:
			hit_tick = roundi(hit_tick * LIGHT_TIME_SCALE)
			end_tick = roundi(end_tick * LIGHT_TIME_SCALE)
		# Fast startup shares one clock with the authored pose, root motion and contact.
		if tick <= hit_tick: return contact*tick/hit_tick
		return lerpf(contact,float(spec.duration_ms),clampf((tick-hit_tick)/maxi(1,end_tick-hit_tick),0,1))
	var speed := float(HERO_PROFILES.get(fighter.get("kind",""),{}).get("attack_speed",1))*float(fighter.get("attack_speed",1))*(1+Equipment.bonus(fighter,"attack_speed_bonus"))
	# Nineteen startup ticks plus eight commitment ticks cap normal bow shots at 0.45 seconds.
	if fighter.get("kind","") == "oichi" and fighter.get("action","") == "heavy": return tick*(1000.0/60*OICHI_HEAVY_SPEED)*minf(speed,1.0)
	if fighter.get("action","") == "throw" and CombatMoves.active(fighter): speed /= THROW_TIME_SCALE
	return tick*1000/60*(1.0 if fighter.get("action","") in ["charge","holding"] else speed)

func _can_chain(fighter: Dictionary) -> bool:
	var spec := CombatMoves.spec(fighter)
	var contact := float(spec.duration_ms) * 0.5 if spec.events.is_empty() else 0.0
	for event in spec.events: contact = maxf(contact,float(event.ms))
	# Light scales its commitment with the cadence; other moves retain eight ticks.
	var commitment := roundi(8 * LIGHT_TIME_SCALE) if fighter.action == "light" else 8
	if fighter.action == "light" and fighter.action_tick < roundi(14 * LIGHT_TIME_SCALE): return false
	return combat_time_ms(fighter,commitment) >= contact and float(fighter.get("combat_previous_ms",-1)) >= contact

func _combat_input_v33(fighter: Dictionary, buttons: int, pressed: int, released: int, dx: int, dy: int, index: int) -> void:
	if int(fighter.get("light_recovery_ticks",0)) > 0:
		pressed &= ~LIGHT
		_queued_buttons[index] &= ~LIGHT
	if fighter.freeze > 0 or fighter.airborne_lock or fighter.action == "pulled": return
	if fighter.action == "guard" and not buttons & GUARD: _begin(fighter,"idle")
	if fighter.action in ["idle","guard"] and buttons & GUARD and fighter.z == 0:
		if dx != 0: fighter.face = dx
		if fighter.action != "guard": _begin(fighter,"guard")
		_queued_buttons[index] = 0
		fighter.sprinting = false
		fighter.sprint_ticks = 0
		return
	if fighter.action in ["light","heavy","charged","charge_rain","air_light","air_heavy","dash_heavy","throw","grab_start","grab_hit_1","grab_hit_2"]:
		var command := pressed & (LIGHT | HEAVY | JUMP | GRAB)
		if command != 0: _queued_buttons[index] = command | (int(_queued_buttons[index]) & JUMP)
		if (_queued_buttons[index] != 0 or dx != 0 or dy != 0) and _can_chain(fighter):
			if fighter.action == "throw" and fighter.get("throw_clip","") == "throw_reverse": fighter.face = int(fighter.get("throw_face",fighter.face))
			_begin(fighter,"holding" if fighter.grab_target != 0 else "idle")
	if fighter.action in ["idle","holding"]:
		pressed |= int(_queued_buttons[index])
		_queued_buttons[index] = 0
	if fighter.action == "holding":
		if dx == -int(fighter.face):
			fighter.throw_clip = "throw_reverse"
			fighter.throw_face = -int(fighter.face)
			_begin(fighter,"throw")
		elif pressed & LIGHT:
			if int(fighter.get("grab_hits",0)) >= 2:
				fighter.throw_clip = "throw_forward"
				fighter.throw_face = int(fighter.face)
				_begin(fighter,"throw")
			else:
				fighter.grab_hits = int(fighter.get("grab_hits",0))+1
				_begin(fighter,"grab_hit_%d" % fighter.grab_hits)
		return
	if fighter.action == "charge":
		if dx != 0: fighter.face = dx
		fighter.charge_direction = dy
		if released & HEAVY: _release_heavy(fighter)
		return
	if fighter.action != "idle": return
	if dx != 0: fighter.face = dx
	if pressed & INTERACT: _pickup(fighter)
	if pressed & JUMP and not pressed & GRAB and fighter.z == 0 and not Stage04.in_mud(state,fighter):
		fighter.vz = 9.0
		fighter.z = 1.0
	if pressed & GRAB and fighter.z == 0:
		_try_grab(fighter)
	elif pressed & HEAVY:
		if fighter.z > 0:
			fighter.combat_air_start = fighter.z
			_begin(fighter,"air_heavy")
			if fighter.kind == "nobunaga": _tick_combat_v33(fighter)
			if fighter.kind == "oichi":
				var windup := fighter_tick(fighter,6)
				# A last-moment descending shot releases now, while the bow is still airborne.
				if fighter.z + fighter.vz * windup - 0.275 * windup * (windup - 1) <= 0:
					fighter.action_tick = windup
					_tick_combat_v33(fighter)
		elif fighter.sprinting: _begin(fighter,"dash_heavy")
		else:
			fighter.charge = 0
			fighter.charge_direction = dy
			_begin(fighter,"charge")
			if not buttons & HEAVY: _release_heavy(fighter)
	elif pressed & LIGHT:
		if fighter.z > 0: _begin(fighter,"air_light")
		else:
			fighter.combo = fighter.combo%3+1
			_begin(fighter,"light")
			fighter.combo_tick = roundi(fighter_tick(fighter,19)*LIGHT_TIME_SCALE)+24
	elif pressed & JUMP:
		pass
	else:
		var move := Vector2(dx,dy).normalized()
		var speed: float = (2.0 if fighter.sprinting else 1.0)*(HERO_PROFILES[fighter.kind].move_speed*(1+Equipment.bonus(fighter,"move_bonus"))+float(Weapons.item(str(fighter.weapon_id)).get("move_bonus",0)))
		_move_fighter(fighter,move.x*3.5*speed,move.y*2.65*speed,fighter.sprinting)
		if fighter.sprinting: _sprint_bump(fighter)

func _tick_combat_v33(fighter: Dictionary) -> bool:
	if fighter.action == "charge":
		fighter.charge = mini(900,fighter.charge+1)
		return true
	var spec := CombatMoves.spec(fighter)
	if spec.is_empty(): return false
	var now := combat_time_ms(fighter)
	var previous := float(fighter.get("combat_previous_ms",-1))
	var frame: Dictionary = spec.frames[CombatMoves.frame_index(spec,now)]
	var step := float(frame.root_step)
	if fighter.action == "light":
		step *= 3.0 if fighter.kind == "oichi" else 1.5
		# Recovery poses must not undo the forward step already taken.
		step = maxf(step,float(fighter.get("combat_step",0)))
	if fighter.action == "dash_heavy":
		var coast := clampf(now / 360.0, 0, 1)
		step += 72.0 * (1.0 - (1.0 - coast) * (1.0 - coast))
	_move_fighter(fighter,(step-float(fighter.get("combat_step",0)))*fighter.face)
	fighter.combat_step = step
	if fighter.kind == "nobunaga" and fighter.action == "air_heavy":
		fighter.z = maxf(float(frame.air_height),float(fighter.get("combat_air_start",0))*maxf(0,1-now/180.0))
		fighter.vz = 0
	for event in spec.events:
		if float(event.ms) > previous and float(event.ms) <= now:
			_combat_contact_v33(fighter,str(event.event))
	fighter.combat_previous_ms = now
	if now >= float(spec.duration_ms) and not spec.loop:
		if fighter.action in ["grab_start","grab_hit_1","grab_hit_2"]:
			_begin(fighter,"holding" if fighter.grab_target != 0 else "idle")
		else:
			if fighter.action == "throw" and fighter.get("throw_clip","") == "throw_reverse": fighter.face = int(fighter.get("throw_face",fighter.face))
			_begin(fighter,"idle")
	return true

func _combat_contact_v33(fighter: Dictionary, event: String) -> void:
	var action := str(fighter.action)
	if action == "throw" and event in ["victim_release","throw_release","release"]:
		_release_grab(fighter,true)
		return
	if action in ["grab_hit_1","grab_hit_2"] and event in ["contact_normal_hit","knee_contact_1","knee_contact_2"]:
		var held := _fighter(fighter.grab_target)
		if not held.is_empty(): _damage(held,12+fighter.weapon*3,fighter.id,false,true,true,false,NAN,NAN,action,24,"blunt")
		return
	if action == "air_heavy" and fighter.kind != "oichi" and event.begins_with("contact"):
		var damage := roundi((26+fighter.weapon*8)*1.3) if fighter.kind == "nobunaga" else 35+int(fighter.weapon)*6
		_melee(fighter,AIR_HEAVY_REACH,AIR_HEAVY_DEPTH,damage,true,0,false,false,36.0)
		return
	if fighter.kind not in ["nobunaga","oichi"]:
		_contact_delivered(fighter,event)
		return
	if not (event.begins_with("contact") or event == "projectile_release"): return
	match action:
		"light":
			_melee(fighter,145 if fighter.kind == "nobunaga" else 115,48,14+fighter.combo*2+fighter.weapon*5,fighter.combo == 3,0,fighter.combo == 3)
			_combat_push_v33(fighter,145 if fighter.kind == "nobunaga" else fighter.attack_reach,48,4 if fighter.kind == "nobunaga" else 3)
		"heavy":
			if fighter.kind == "oichi": _combat_arrow_v33(fighter,false)
			else:
				_melee(fighter,150,60,26+fighter.weapon*8,false)
				_combat_push_v33(fighter,150,60,9)
				_combat_sword_wave_v33(fighter)
		"charged":
			if fighter.kind == "oichi": _combat_arrow_v33(fighter,true)
			else: _melee(fighter,220*NOBUNAGA_HEAVY_RANGE_SCALE,90*NOBUNAGA_HEAVY_RANGE_SCALE,43+fighter.weapon*8,true,0,true,false,220*NOBUNAGA_HEAVY_RANGE_SCALE)
		"charge_rain":
			var spec := CombatMoves.spec(fighter)
			var frame: Dictionary = spec.frames[CombatMoves.frame_index(spec,combat_time_ms(fighter))]
			_effect("sky_arrow",fighter.x+float(frame.hand[0])*fighter.face,fighter.y,90,{"owner":fighter.id,"team":fighter.team,"z":-float(frame.hand[1]),"rain_center_x":fighter.x,"damage":43+fighter.weapon*6+int(Weapons.item(str(fighter.weapon_id)).get("damage_bonus",0))+int(Equipment.bonus(fighter,"damage_bonus")),"face":fighter.face,"radius":1230.0*.2948766456*1.5,"equipment_uid":fighter.weapon_uid,"attack_id":fighter.attack_id})
			_weapon_release(fighter,"arrow")
		"air_light":
			_melee(fighter,174 if fighter.kind == "nobunaga" else 138,57.6,roundi((16+fighter.weapon*5)*1.2),false)
		"air_heavy":
			for reach in [320.0,600.0,900.0]: _combat_arrow_v33(fighter,false,reach)
		"dash_heavy": _melee(fighter,190,70,32+fighter.weapon*6,true,0,true)

func _contact_delivered(fighter: Dictionary, event: String) -> void:
	if event == "withdraw_knockdown":
		for target in state.fighters:
			if target.id in fighter.get("combat_hit_ids",[]) and target.hp > 0 and target.weight != "heavy": _begin(target,"down")
		return
	if event != "contact": return
	var action := str(fighter.action)
	var kind := str(fighter.kind)
	if kind == "hideyoshi" and action == "charged":
		var start_x: float = fighter.x
		_move_fighter(fighter,fighter.face*HIDEYOSHI_BLINK_STEP,0.0,true)
		var distance := absf(fighter.x-start_x)
		# The rear bound covers the entire blink path, including enemies between endpoints.
		_melee(fighter,LIGHT_REACH.hideyoshi*1.15,85.0,30+fighter.weapon*2,true,0,false,false,distance+18.0)
		_effect("wind_wave",start_x,fighter.y,14,{"face":fighter.face,"radius":distance,"kind":"hideyoshi","action":"charged","combo":mini(3,1+floori(combat_time_ms(fighter)/500.0))})
		return
	if kind == "ieyasu" and action in ["heavy","charged"]:
		# One projectile owns the whole piercing window, including its per-enemy hit set.
		_projectile(fighter,(46 if action == "charged" else 29)+fighter.weapon*6,0,true,"blade",520 if action == "charged" else 290,0,"",true,{"piercing":true})
		var wave: Dictionary = state.effects[-1]
		wave.combat_sword_wave = true
		wave.x = fighter.x + fighter.face*35
		wave.previous_x = wave.x
		wave.z = 70.0
		wave.collision_height = 90.0
		wave.visual_exact_origin = true
		wave.hit_depth = 42.0
		return
	var reach: float = LIGHT_REACH[kind]
	var depth := 48.0
	var damage := 14+int(fighter.combo)*2+int(fighter.weapon)*5
	var launch: bool = action == "light" and fighter.combo == 3
	var knockdown := false
	var behind := 18.0
	match action:
		"heavy":
			reach *= 1.12
			damage = 28+fighter.weapon*8
			launch = kind in ["hideyoshi","mitsuhide"]
		"charged":
			reach *= 1.15
			depth = 85.0
			behind = reach
			damage = (11 if kind == "mitsuhide" else 30)+fighter.weapon*2
		"air_light": damage = 22+fighter.weapon*5
		"dash_heavy":
			reach *= 1.15
			damage = 32+fighter.weapon*6
			knockdown = true
			launch = true
	_melee(fighter,reach,depth,damage,knockdown,0,launch,false,behind)
	if kind == "hideyoshi" and action == "heavy": _combat_sword_wave_v33(fighter)
	for target in state.fighters:
		if target.team == fighter.team or target.damage_tick != state.tick: continue
		if not target.id in fighter.combat_hit_ids: fighter.combat_hit_ids.append(target.id)
		if action == "charged" and kind == "mitsuhide": target.invuln = mini(target.invuln,5)
	_combat_push_v33(fighter,float(fighter.attack_reach),depth,3.0)

func _combat_push_v33(fighter: Dictionary, reach: float, depth: float, speed: float) -> void:
	for target in state.fighters:
		if target.team == fighter.team or target.weight == "heavy" or target.action != "hurt" or target.damage_tick != state.tick: continue
		if (target.x-fighter.x)*fighter.face >= 0 and (target.x-fighter.x)*fighter.face <= reach+40 and absf(target.y-fighter.y) <= depth:
			target.knockback += fighter.face*speed

func _combat_arrow_v33(fighter: Dictionary, piercing: bool, air_reach: float = 0) -> void:
	_projectile(fighter,(43 if piercing else 24)+fighter.weapon*6,0,false,"arrow",air_reach+105 if air_reach>0 else (1450 if piercing else 760),0,"",true,{"piercing":piercing,"descending":air_reach>0})
	var effect: Dictionary = state.effects[-1]
	effect.standing_push = 9.0 if piercing else 6.0
	var spec := CombatMoves.spec(fighter)
	var frame: Dictionary = spec.frames[CombatMoves.frame_index(spec,combat_time_ms(fighter))]
	var hand: Array = frame.hand
	effect.x = fighter.x+fighter.face*float(hand[0])
	effect.previous_x = fighter.x
	effect.z = fighter.z-float(hand[1])
	effect.visual_exact_origin = true
	effect.collision_height = 90.0
	if air_reach>0:
		effect.start_z = effect.z
		effect.vz = -effect.z*absf(effect.vx)/air_reach
		effect.range_left = air_reach
	else:
		# Moving the release point to the hand must preserve the advertised total reach.
		effect.range_left += 105.0-float(hand[0])
	effect.life = ceili(effect.range_left/absf(effect.vx))+2
	effect.max_life = effect.life

func _combat_sword_wave_v33(fighter: Dictionary) -> void:
	_projectile(fighter,(28 if fighter.kind == "hideyoshi" else 26)+fighter.weapon*8,0,false,"blade",240,0,"",true,{"piercing":true})
	var wave: Dictionary = state.effects[-1]
	wave.combat_sword_wave = true
	wave.standing_push = 9.0
	wave.x = fighter.x+fighter.face*135
	wave.previous_x = wave.x
	wave.z = 80.0
	wave.range_left += 20.0
	wave.visual_exact_origin = true
	wave.collision_height = 90.0
	wave.vx = fighter.face*12.0
	wave.life = ceili(wave.range_left/absf(wave.vx))+2
	wave.max_life = wave.life

func _update_sprint(fighter: Dictionary, dx: int, dy: int, stick_full: Variant = null) -> void:
	if stick_full != null:
		var running: bool = stick_full == true and (dx != 0 or dy != 0) and fighter.action == "idle" and fighter.z == 0.0 and not fighter.airborne_lock and fighter.freeze == 0
		fighter.sprint_ticks = mini(12,int(fighter.get("sprint_ticks",0))+1) if running else 0
		fighter.sprinting = fighter.sprint_ticks == 12
		fighter.move_dx = dx
		fighter.move_dy = dy
		fighter.sprint_dx = dx
		fighter.sprint_dy = dy
		fighter.tap_tick = -1000
		return
	fighter.sprint_ticks = 0
	if dx != fighter.move_dx or dy != fighter.move_dy:
		if dx == 0 and dy == 0:
			fighter.sprinting = false
		else:
			var steering: bool = fighter.sprinting and dx != 0 and dx == fighter.move_dx
			fighter.sprinting = steering or (fighter.action == "idle" and fighter.z == 0.0 and not fighter.airborne_lock and fighter.move_dx == 0 and fighter.move_dy == 0 and dx == fighter.tap_dx and dy == fighter.tap_dy and state.tick - fighter.tap_tick <= 15)
			fighter.tap_dx = dx
			fighter.tap_dy = dy
			fighter.tap_tick = state.tick
			fighter.sprint_dx = dx
			fighter.sprint_dy = dy
		fighter.move_dx = dx
		fighter.move_dy = dy
	if fighter.action != "idle" or fighter.z > 0.0: fighter.sprinting = false


func _sprint_bump(attacker: Dictionary) -> void:
	for target in state.fighters:
		if target.team == attacker.team or target.hp <= 0 or target.bump_cooldown > 0 or target.z > 25.0: continue
		if absf(target.x - attacker.x) < 48.0 and absf(target.y - attacker.y) < 32.0:
			if _damage(target, 6, attacker.id, false):
				target.bump_cooldown = 40
				target.knockback = attacker.face * 3.0
				_event("run_bump", target.x, target.y, attacker.id, target.id)


func _wet(x: float, y: float) -> bool:
	for zone in state.wet_zones:
		if absf(x - zone.x) <= zone.width * 0.5 and absf(y - zone.y) <= zone.depth * 0.5: return true
	return false


func _landing(fighter: Dictionary) -> void:
	_effect("landing", fighter.x, fighter.y, 22, {"target": fighter.id, "wet": _wet(fighter.x, fighter.y), "bounce": fighter.landing_count})
	_event("landing", fighter.x, fighter.y, fighter.id, fighter.id, {"wet": _wet(fighter.x, fighter.y), "body":fighter.airborne_lock or fighter.action in ["thrown","launched"]})


func _spawn_props() -> void:
	for spec in [["stall", 440.0, 570.0, 80, 130.0, 44.0, "food"], ["cart", 920.0, 410.0, 65, 115.0, 38.0, "weapon"], ["jar", 1200.0, 545.0, 22, 46.0, 28.0, "food"], ["basket", 1630.0, 570.0, 18, 54.0, 28.0, "food"], ["crate", 1960.0, 415.0, 38, 64.0, 36.0, "armor"]]:
		state.props.append({"id": _next_id, "kind": spec[0], "x": spec[1], "y": spec[2], "hp": spec[3], "max_hp": spec[3], "width": spec[4], "depth": spec[5], "broken": false, "drop": spec[6]})
		_next_id += 1


func _damage_prop(prop: Dictionary, damage: int, owner: int, weapon: String = "") -> void:
	if prop.broken: return
	prop.hp = maxi(0, prop.hp - damage)
	prop.hit_tick = state.tick
	var material: String = {"jar":"ceramic","planter":"ceramic","stone_lantern":"stone","crate":"box","large_crate":"box","cabinet":"box","basket":"wicker","rice_bales":"wicker"}.get(prop.kind,"wood")
	_event("prop_hit",prop.x,prop.y,owner,prop.id,{"material":material,"weapon":weapon,"shared_sfx":prop.has("s05_asset")})
	if prop.get("s05_asset","")=="rice" and prop.hp>0: Stage05.audio(self,"s05.prop.rice_sack.hit",owner)
	_effect("hit", prop.x, prop.y - 25.0, 10, {"heavy": damage >= 25})
	if prop.hp == 0:
		prop.broken = true
		if prop.has("s05_asset"): prop.broken_tick=state.tick
		_award_score(owner,50)
		_effect("debris", prop.x, prop.y, 36, {"kind": prop.kind, "target": prop.id})
		_event("prop_break", prop.x, prop.y, owner, prop.id,{"material":material,"shared_sfx":prop.has("s05_asset")})
		if state.has("stage") and _fighter(owner).get("team",1) == 0:
			_add_drop("food",clampf(prop.x,_left_edge()+30,_right_edge()-30),prop.y,owner)
		if not str(prop.drop).is_empty() and (prop.drop != "food" or not state.has("stage")) and (prop.drop == "food" or _loot_roll(1000) < 100) and _add_drop(prop.drop, prop.x, prop.y):
			if prop.drop == "talisman": state.drops[-1].talisman_id = prop.talisman_id
			if prop.drop == "food" and not str(prop.get("food_id","")).is_empty():
				state.drops[-1].food_id = prop.food_id
				state.drops[-1].heal = {"rice":35,"fish":50,"dango":25,"peach":60}.get(prop.food_id,40)


func _melee_props(attacker: Dictionary, reach: float, depth: float, damage: int, behind: float = 18.0, arc_degrees: float = 360.0) -> void:
	if attacker.z > 80.0 and not (CombatMoves.active(attacker) and attacker.kind != "oichi" and attacker.action == "air_heavy"): return
	for prop in state.props:
		var ahead: float = (prop.x - attacker.x) * attacker.face
		if not _inside_arc(prop.x - attacker.x, prop.y - attacker.y, attacker.face, arc_degrees): continue
		if not prop.broken and ahead + prop.width * 0.5 >= -behind and ahead - prop.width * 0.5 <= reach and absf(prop.y - attacker.y) < depth + prop.depth * 0.5:
			_damage_prop(prop, damage, attacker.id)


func _enemy_input(fighter: Dictionary) -> void:
	var target: Dictionary = {}
	var distance := INF
	for player in state.fighters:
		if player.team != 0 or player.hp <= 0: continue
		var delta := Vector2(player.x - fighter.x, (player.y - fighter.y) * 1.8)
		if delta.length_squared() < distance:
			distance = delta.length_squared()
			target = player
	if target.is_empty(): return
	target = Stage03Encounter.Tent.target_for(self, fighter, target)
	var chasing_cart := false
	if fighter.get("role","") in ["raider","fire_archer"] and state.has("challenge") and state.challenge.status == "active":
		var cart: Dictionary = state.challenge
		if Vector2(cart.x-fighter.x,(cart.y-fighter.y)*1.8).length_squared() < distance * 1.25:
			target = cart
			chasing_cart = true
	if fighter.get("entering",false):
		fighter.move_dx = fighter.face
		var old_x: float = fighter.x
		var entry_speed: float = 2.8 * HERO_PROFILES[target.kind].move_speed if fighter.kind == "boss" else 2.4
		if fighter.has("s05_role"): entry_speed *= Stage05.Data.speed(fighter)
		var entry_step := move_toward(fighter.x,fighter.entry_x,entry_speed) - float(fighter.x)
		_move_fighter(fighter,entry_step)
		var blocked := is_equal_approx(old_x,fighter.x)
		if is_equal_approx(fighter.x,fighter.entry_x) or (blocked and fighter.x >= _left_edge() and fighter.x <= _right_edge()):
			fighter.entering = false
		elif blocked:
			_move_fighter(fighter,0.0,2.4 if fighter.y < 480.0 else -2.4)
		return
	if Stage03Encounter.Tent.steer(self, fighter, target): return
	if Stage03Encounter.Objectives.steer(self, fighter, target): return
	fighter.move_dx = 0
	fighter.move_dy = 0
	if fighter.freeze > 0 or fighter.airborne_lock: return
	if fighter.stun > 0:
		if fighter.action == "idle": _begin(fighter, "stunned")
		return
	if Stage04.ai(self,fighter,target): return
	if Stage05.ai(self,fighter,target): return
	if fighter.kind == "dummy" or not fighter.action in ["idle", "retreat", "bow_shot", "gun_shot"]:
		return
	fighter.face = 1 if target.x >= fighter.x else -1
	var dx: float = target.x - fighter.x
	var dy: float = target.y - fighter.y
	if absf(dx) > 950.0 and not state.has("stage"):
		return
	var ranged: bool = fighter.kind in ["archer", "gunner"]
	if ranged:
		if absf(dx) < (270.0 if fighter.action == "retreat" else 210.0) and absf(dy) < 85.0 and (fighter.action in ["idle", "retreat"] or fighter.action_tick < int(ENEMY_TIMING[fighter.action][0]) - 8):
			if fighter.action != "retreat": _begin(fighter, "retreat")
			var away: float = -fighter.face
			var against_wall: bool = fighter.x + away * 60.0 < _left_edge() or fighter.x + away * 60.0 > _right_edge()
			if against_wall:
				var side := 1.0 if target.y < 480.0 else -1.0
				_move_fighter(fighter,0.0,side * 3.6 * ENEMY_SPEED)
				fighter.move_dy = int(side)
				# Move past the pursuer in a different lane before reversing away from the wall.
				if absf(dy) > 45.0:
					_move_fighter(fighter,fighter.face * 3.4 * ENEMY_SPEED)
					fighter.move_dx = fighter.face
			else:
				_move_fighter(fighter,away * 3.0 * ENEMY_SPEED)
				fighter.move_dx = int(away)
			return
		if fighter.action not in ["idle", "retreat"]: return
		if fighter.action == "retreat": _begin(fighter, "idle")
	var reach := (900.0 if fighter.kind == "gunner" else 760.0) if ranged else (165.0 if fighter.kind == "soldier" else 120.0)
	var attacks: Array = ENEMY_ATTACKS.get(fighter.kind, ENEMY_ATTACKS.soldier)
	if state.get("stage",{}).get("id",0) == 3 and fighter.kind == "soldier": attacks = ["spear_thrust"]
	if fighter.has("mikawa_role") and fighter.kind == "soldier": attacks = ["spear_butt","commander_cut"] if fighter.mikawa_role.begins_with("shield_") else ["spear_thrust","spear_sweep"]
	if fighter.kind == "boss":
		var profile: Dictionary = BOSS_PROFILES.get(fighter.boss_variant, BOSS_PROFILES.kusarigama)
		attacks = fighter.get("boss_actions",profile.actions)
		var next: String = attacks[fighter.ai_cycle % attacks.size()]
		reach = float({"boss_chain": 380.0, "boss_hook": 190.0, "boss_grab_throw": 150.0, "boss_volley": 850.0, "boss_thrust": 240.0, "boss_sweep": 220.0, "boss_earth": 230.0}.get(next, 145.0)) * profile.reach
		if fighter.has("lieutenant_slot"): reach = float(fighter.reach_thrust if next == "boss_thrust" else fighter.reach_sweep) * float(fighter.render_scale) * .9
	if absf(dx) < reach and absf(dy) < 32.0 and fighter.cooldown == 0:
		fighter.target_x = fighter.x + fighter.face * (100.0 if fighter.kind == "boss" else 75.0)
		fighter.target_y = fighter.y
		if ranged:
			_begin(fighter, "gun_shot" if fighter.kind == "gunner" else "bow_shot")
			if fighter.get("role","") == "fire_archer":
				fighter.target_x = target.x
				fighter.target_y = target.y
				_effect("arrow_target",target.x,target.y,int(enemy_timing(fighter)[0]),{"owner":fighter.id,"radius":78.0,"element":"fire"})
		else:
			fighter.attack_variant = fighter.ai_cycle % attacks.size()
			fighter.ai_cycle += 1
			_begin(fighter, attacks[fighter.attack_variant])
			if fighter.action == "boss_earth": fighter.target_x = fighter.x
			if not fighter.has("mikawa_role"): _effect("warning", fighter.target_x, fighter.target_y, int(enemy_timing(fighter)[0]), {"radius": (390.0 if fighter.action == "boss_earth" and fighter.get("stage_boss",false) else 210.0) if fighter.kind == "boss" else 115.0, "owner": fighter.id, "face": fighter.face})
	else:
		var speed: float = 3.5 * 0.8 * HERO_PROFILES[target.kind].move_speed if fighter.kind == "boss" else 1.4 * ENEMY_SPEED
		if fighter.get("role","") == "shield_spear": speed *= 0.8
		if fighter.get("role","") == "raider":
			speed *= 1.9
			if absf(dx) > 180.0 and not chasing_cart:
				dy = clampf(target.y + (75.0 if fighter.id % 2 == 0 else -75.0),365.0,595.0) - fighter.y
		var movement := Vector2(signf(dx) if absf(dx) > reach * 0.8 else 0.0,signf(dy) if absf(dy) > 7.0 else 0.0)
		if fighter.kind == "boss": movement = movement.normalized()
		var sidestepped := false
		if absf(dx) > reach * 0.8:
			var old_x: float = fighter.x
			_move_fighter(fighter,movement.x * speed)
			if is_equal_approx(old_x,fighter.x):
				for prop in state.props:
					if prop.broken or absf(fighter.x - prop.x) > prop.width * 0.5 + 28.0 or absf(fighter.y - prop.y) > prop.depth * 0.5 + 20.0: continue
					var above: float = prop.y - prop.depth * 0.5 - 20.0
					var below: float = prop.y + prop.depth * 0.5 + 20.0
					var lane: float = above if above >= 360.0 and (below > 600.0 or absf(fighter.y - above) < absf(fighter.y - below)) else below
					if lane >= 360.0 and lane <= 600.0:
						_move_fighter(fighter,0.0,signf(lane - fighter.y) * speed * (2.65 / 3.5 if fighter.kind == "boss" else 0.65))
						sidestepped = true
					break
		if absf(dy) > 7.0 and not sidestepped:
			_move_fighter(fighter,0.0,movement.y * speed * (2.65 / 3.5 if fighter.kind == "boss" else 0.65))


func _tick_enemy_attack(fighter: Dictionary) -> void:
	if Stage04.attack(self,fighter): return
	var action: String = fighter.action
	var timing: Array = enemy_timing(fighter)
	if action == "commander_dash" and fighter.action_tick >= 18 and fighter.action_tick <= 29:
		_move_fighter(fighter,fighter.face * 4.0 * ENEMY_SPEED,0.0,true)
	if action == "boss_dash" and fighter.action_tick >= timing[0] - 14 and fighter.action_tick < timing[0]:
		_move_fighter(fighter,fighter.face * 4.8 * ENEMY_SPEED,0.0,true)
	if fighter.action_tick == int(timing[0]):
		match action:
			"boss_arrow", "boss_sword_wave": Stage03Encounter.Tent.Yoshimoto.release(self,fighter)
			"bow_shot", "gun_shot":
				_projectile(fighter, maxi(1, int((16 if action == "gun_shot" else 10) * _difficulty.enemy_damage)), 0, false, "bullet" if action == "gun_shot" else "arrow", 1100.0 if action == "gun_shot" else 900.0)
			"spear_thrust": _enemy_melee(fighter, 205.0, 26.0, 12)
			"spear_sweep": _enemy_melee(fighter, 155.0, 82.0, 10, "push")
			"spear_butt": _enemy_melee(fighter, 105.0, 42.0, 14, "stun")
			"flag_poke": _enemy_melee(fighter, 180.0, 32.0, 12)
			"flag_sweep": _enemy_melee(fighter, 180.0, 95.0, 13, "push")
			"flag_slam": _enemy_melee(fighter, 140.0, 65.0, 20, "down")
			"commander_cut": _enemy_melee(fighter, 145.0, 65.0, 16)
			"commander_rise": _enemy_melee(fighter, 140.0, 42.0, 20, "down")
			"commander_dash": _enemy_melee(fighter, 155.0, 32.0, 22, "push")
			"boss_sweep": _enemy_melee(fighter, 260.0, 100.0, 22, "push")
			"boss_smash":
				_enemy_melee(fighter, 180.0, 80.0, 30, "down")
				_effect("slam", fighter.x + fighter.face * 90.0, fighter.y, 28, {"radius": 190.0})
			"boss_chain": _cast_chain(fighter)
			"boss_hook": _cast_chain(fighter, 220.0)
			"boss_grab_throw": _cast_chain(fighter, 160.0)
			"boss_thrust": _enemy_melee(fighter, 310.0, 32.0, 24, "push")
			"boss_dash": _enemy_melee(fighter, 175.0, 38.0, 26, "down")
			"boss_volley": _projectile(fighter, int(28 * _difficulty.enemy_damage), 0, false, "bullet", 1300.0)
			"boss_counter": _enemy_melee(fighter, 180.0, 55.0, 26, "stun")
			"boss_double": _enemy_melee(fighter, 165.0, 65.0, 15)
			"boss_earth":
				var radius := 390.0 if fighter.get("stage_boss",false) else 290.0
				_wave(fighter, radius, int(28 * _difficulty.enemy_damage), "", 32, true)
				_effect("earth_wave", fighter.x, fighter.y, 32, {"face": fighter.face, "radius": radius, "kind": "boss"})
	if action == "boss_double" and fighter.action_tick == timing[0] + 18:
		_enemy_melee(fighter, 200.0, 75.0, 22, "down")
	if action == "boss_arrow" and fighter.get("is_yoshimoto",false) and fighter.action_tick in [int(timing[0])+5,int(timing[0])+10]:
		Stage03Encounter.Tent.Yoshimoto.release(self,fighter,int((fighter.action_tick-int(timing[0]))/5))
	if action in ["boss_chain", "boss_hook"] and fighter.action_tick == timing[0] + 28:
		var target := _fighter(fighter.chain_target)
		if not target.is_empty() and target.pull_owner == fighter.id:
			target.pull_owner = 0
			if _damage(target, int(24 * _difficulty.enemy_damage), fighter.id, false, true, false, true) and target.hp > 0:
				target.stun = 65
				_begin(target, "stunned")
		fighter.chain_target = 0
	if action == "boss_grab_throw" and fighter.action_tick == timing[0] + 28:
		var target := _fighter(fighter.chain_target)
		fighter.chain_target = 0
		if not target.is_empty() and target.pull_owner == fighter.id:
			target.pull_owner = 0
			if _damage(target, int(28 * _difficulty.enemy_damage), fighter.id, true, true, false, true):
				target.thrown_by = fighter.id
				target.throw_ticks = 32
				target.throw_hits = []
				_launch(target, fighter.face, 16.0, 7.0)
				if target.hp > 0: _begin(target, "thrown")
			elif target.action == "pulled":
				_begin(target, "idle")
	if fighter.action_tick >= int(timing[1]):
		fighter.cooldown = 160 if fighter.kind == "gunner" else (65 if fighter.kind == "archer" else 34)
		if fighter.has("lieutenant_slot"): fighter.cooldown = 16
		if fighter.get("role","") == "fire_archer": fighter.cooldown = 130
		_begin(fighter, "idle")


func _enemy_melee(attacker: Dictionary, reach: float, depth: float, amount: int, reaction: String = "") -> void:
	_weapon_release(attacker, _melee_weapon(attacker))
	if attacker.get("role","") == "raider": amount = maxi(1,roundi(amount * 0.8))
	if attacker.kind == "boss" and not attacker.has("mikawa_role"):
		var profile: Dictionary = BOSS_PROFILES.get(attacker.boss_variant, BOSS_PROFILES.kusarigama)
		reach *= profile.reach
		amount = maxi(1, roundi(amount * profile.damage * (1.2 if attacker.get("stage_boss",false) else 1.0)))
		if attacker.has("reach_thrust"):
			reach = float(attacker.reach_sweep if attacker.action == "boss_sweep" else attacker.reach_thrust) * float(attacker.get("render_scale",1.0))
	attacker.attack_reach = reach
	_effect("slash", attacker.x + attacker.face * reach * 0.5, attacker.y, 12, {"face": attacker.face, "radius": reach * 0.55})
	_melee_props(attacker, reach, depth, amount)
	_damage_cart(attacker,reach,depth,amount)
	for player in state.fighters:
		if player.team != 0 or player.hp <= 0 or player.z >= 50.0: continue
		var ahead: float = (player.x - attacker.x) * attacker.face
		if ahead < -15.0 or ahead > reach or absf(player.y - attacker.y) > depth: continue
		var target: Dictionary = player
		var shield := _front_shield(player, attacker.x, attacker.y)
		if not shield.is_empty() and reaction != "down": target = shield
		if _damage(target, maxi(1, int(amount * _difficulty.enemy_damage)), attacker.id, reaction == "down", true, target.held_by != 0, reaction != ""):
			if target.held_by != 0: continue
			if reaction == "down": _launch(target, attacker.face, 9.0, 6.0)
			elif reaction == "push": target.knockback = attacker.face * 12.0
			elif reaction == "stun" and target.hp > 0:
				target.stun = 45
				_begin(target, "stunned")


func _cast_chain(attacker: Dictionary, reach: float = 430.0) -> void:
	_weapon_release(attacker, "chain")
	attacker.chain_target = 0
	var closest: Dictionary = {}
	var distance := reach
	for player in state.fighters:
		if attacker.action == "boss_grab_throw" and not _standing_grab_target(player): continue
		var ahead: float = (player.x - attacker.x) * attacker.face
		if player.team == 0 and player.hp > 0 and player.z < 55.0 and ahead > 0.0 and ahead < distance and absf(player.y - attacker.y) < 34.0:
			distance = ahead
			closest = player
	var endpoint: float = attacker.x + attacker.face * reach
	if not closest.is_empty():
		endpoint = closest.x
		var shield := _front_shield(closest, attacker.x, attacker.y)
		if not shield.is_empty():
			_damage(shield, 12, attacker.id, false, true, true)
		elif _damage(closest, 6, attacker.id, false) and closest.hp > 0:
			attacker.chain_target = closest.id
			closest.pull_owner = attacker.id
			_begin(closest, "pulled")
	_effect("chain", attacker.x, attacker.y, 30, {"owner": attacker.id, "target": attacker.chain_target, "target_x": endpoint, "target_y": attacker.y, "face": attacker.face, "kind": attacker.get("boss_variant", "kusarigama")})


func _attack_equipment(attacker: Dictionary) -> Dictionary:
	if attacker.team != 0 or (attacker.kind == "oichi" and attacker.action != "dash_heavy"): return {}
	return Weapons.item(str(attacker.get("weapon_id","")))

func _loot_roll(limit: int) -> int:
	# Authoritative snapshot holds the PRNG, so replays and network clients agree.
	state.loot_rng = (int(state.loot_rng) * 1103515245 + 12345) & 0x7fffffff
	return (int(state.loot_rng) >> 8) % limit

func _drop_boss_weapon(boss: Dictionary, owner: int) -> void:
	if state.has("training"): return
	var player := _fighter(owner)
	if player.is_empty() or player.team != 0: return
	var major: bool = boss.get("stage_boss",false)
	if _loot_roll(1000) >= (30 if major else (15 if boss.kind == "boss" else 5)): return
	_spawn_weapon_loot(player,boss.x,boss.y,3 if major else 2)

func _drop_talisman(enemy: Dictionary, owner: int) -> void:
	var player := _fighter(owner)
	if state.has("training") or player.is_empty() or player.team != 0: return
	var chance := 18 if enemy.get("stage_boss",false) else (8 if enemy.kind == "boss" else 2)
	if _loot_roll(1000) >= chance: return
	var tier := mini(4,int(state.get("stage",{}).get("id",1))+2)
	var candidates := TALISMANS.keys().filter(func(id): return int(TALISMANS[id].tier) <= tier)
	if _add_drop("talisman",clampf(enemy.x-18,_left_edge()+30,_right_edge()-30),enemy.y): state.drops[-1].talisman_id = candidates[_loot_roll(candidates.size())]

func _spawn_weapon_loot(player: Dictionary, x: float, y: float, tier_step: int = 2) -> void:
	var options := Weapons.loot_candidates(player.kind,player.weapon_id,player.owned_weapons,tier_step)
	if options.is_empty(): return
	if not _add_drop("weapon",clampf(x,_left_edge()+30,_right_edge()-30),y): return
	state.drops[-1].weapon_id = options[_loot_roll(options.size())]

func _check_achievements() -> void:
	if state.has("training"): return
	for player in state.fighters:
		if player.team != 0: continue
		var earned := Achievements.earned(player)
		if earned.is_empty(): continue
		var eligible: bool = int(state.tick) - int(player.achievement_reward_tick) >= Achievements.REWARD_COOLDOWN
		var loot: bool = eligible and _loot_roll(1000) < 10
		if eligible: player.achievement_reward_tick = state.tick
		if loot: _spawn_weapon_loot(player,player.x + 45,player.y)
		for index in range(earned.size()):
			_event("achievement",player.x,player.y,player.id,0,{"achievement_id":earned[index][0],"name":earned[index][1],"description":earned[index][2],"loot":loot and index == 0})

func _wear_weapon(player: Dictionary, uid: int) -> void:
	var item := Equipment.instance(player,uid)
	if item.is_empty() or Equipment.is_practice(str(item.item_id)): return
	item.durability -= 1
	if item.durability <= 0:
		var name := str(Equipment.catalog(item.item_id).name)
		Equipment.remove(player,uid)
		_event("weapon_break",player.x,player.y,player.id,0,{"name":name})

func _melee(attacker: Dictionary, reach: float, depth: float, damage: int, heavy: bool, poison: int = 0, launch: bool = false, uppercut: bool = false, behind: float = 18.0, element: String = "", arc_degrees: float = 360.0) -> void:
	_weapon_release(attacker, _melee_weapon(attacker))
	var equipment := _attack_equipment(attacker)
	var weapon_uid := int(attacker.get("weapon_uid",0))
	damage += int(equipment.get("damage_bonus",0)) + int(Equipment.bonus(attacker,"damage_bonus"))
	reach += float(equipment.get("reach_bonus",0)) + Equipment.bonus(attacker,"reach_bonus")
	if element == "": element = str(equipment.get("element",""))
	if HERO_PROFILES.has(attacker.kind):
		var profile: Dictionary = HERO_PROFILES[attacker.kind]
		reach *= profile.reach
		depth *= profile.depth
		damage = maxi(1, roundi(damage * profile.damage))

	if attacker.kind == "oichi" and attacker.action in ["light", "air_light"]:
		reach *= 1.3
	if CombatMoves.active(attacker) and attacker.kind == "hideyoshi" and attacker.action == "light":
		reach *= 1.3
		depth *= 1.3
	var finisher: bool = CombatMoves.active(attacker) and attacker.action == "light" and attacker.combo == 3
	if finisher:
		# Stack another 20% on the existing finisher range bonus.
		reach *= 1.44
		depth *= 1.44
		attacker.light_recovery_ticks = 30
	if CombatMoves.active(attacker) and attacker.kind == "hideyoshi" and attacker.action == "charged":
		reach *= HIDEYOSHI_CHARGED_RANGE_SCALE
		depth *= HIDEYOSHI_CHARGED_RANGE_SCALE
	if CombatMoves.active(attacker) and attacker.kind == "tadakatsu" and attacker.action == "charged":
		var ring := tadakatsu_charged_area(attacker)
		reach = ring.reach
		depth = ring.depth
		behind = ring.behind
	attacker.attack_reach = reach
	var downward_wave: bool = CombatMoves.active(attacker) and attacker.kind != "oichi" and attacker.action == "air_heavy"
	if finisher:
		_effect("slash",attacker.x,attacker.y,18,{"face":attacker.face,"radius":reach,"hit_depth":depth,"finisher":true,"kind":_melee_weapon(attacker)})
	elif downward_wave:
		_effect("blade_wave",attacker.x,attacker.y,18,{"face":attacker.face,"radius":reach,"hit_depth":depth,"z":attacker.z,"action":"air_heavy"})
	else:
		if not (CombatMoves.active(attacker) and ((attacker.kind in ["tadakatsu","hideyoshi"] and attacker.action == "charged") or (attacker.kind == "nobunaga" and attacker.action in ["light","heavy","dash_heavy"]))):
			_effect("slash", attacker.x + attacker.face * reach * 0.5, attacker.y - attacker.z, 10, {"face": attacker.face, "radius": reach * 0.5})
	_melee_props(attacker, reach, depth, damage, behind, arc_degrees)
	for target in state.fighters:
		if target.team == attacker.team or target.hp <= 0:
			continue
		var ahead: float = (target.x - attacker.x) * attacker.face
		if arc_degrees < 360.0 and (Vector2(ahead, (target.y - attacker.y) / 0.4).length() > reach or not _inside_arc(target.x - attacker.x, target.y - attacker.y, attacker.face, arc_degrees)): continue
		# A downward sweep spans from the airborne weapon to the ground.
		var height_contact: bool = absf(target.z-attacker.z) < 80.0 or (downward_wave and target.z <= attacker.z)
		if ahead >= -behind and ahead <= reach and absf(target.y - attacker.y) <= depth and height_contact:
			var shield_dash: bool = CombatMoves.active(attacker) and attacker.action == "dash_heavy" and target.get("role","") == "shield_spear"
			if _damage(target, damage, attacker.id, heavy and not shield_dash and (attacker.action != "dash_heavy" or target.weight != "heavy"), true, false, not shield_dash and attacker.action in ["heavy", "dash_heavy", "charged", "charged_upper", "upper_heavy", "mixed_finisher", "mixed_rising", "air_heavy"],NAN,NAN,"",24,"",weapon_uid,int(attacker.get("attack_id",0)),element,launch or uppercut or (attacker.team == 0 and attacker.action == "heavy")):
				var hit_face: int = (1 if target.x >= attacker.x else -1) if behind > 18.0 else int(attacker.face)
				if attacker.team == 0 and attacker.action == "heavy" and target.weight != "heavy":
					_launch(target,hit_face,2.2,4.6)
					target.bounces_left = 0
				elif launch and target.weight != "heavy" and not shield_dash:
					_launch(target, hit_face, 16.0 if attacker.action == "charged" else (13.0 if attacker.action in ["heavy", "dash_heavy"] else (12.0 if attacker.kind == "oichi" and attacker.action == "light" else 8.0)))
				elif uppercut and target.weight == "light":
					_launch(target, attacker.face, 12.0 if attacker.action == "charged_upper" else (1.4 if attacker.action == "rising" else 0.8), 9.0 if attacker.action == "charged_upper" else (7.0 if attacker.action == "rising" else 4.6))
				if target.weight != "heavy" and attacker.action != "heavy": target.knockback += hit_face * (float(equipment.get("knockback",0))+Equipment.bonus(attacker,"knockback_bonus"))
				if poison > 0:
					_poison(target, poison, attacker.id,weapon_uid)
				_apply_element(target, element, attacker.id,weapon_uid,int(attacker.get("attack_id",0)))


func _enemy_strike(attacker: Dictionary, reach: float, depth: float, damage: int) -> void:
	_weapon_release(attacker, _melee_weapon(attacker))
	_effect("slam", attacker.target_x, attacker.target_y, 15, {"radius": reach})
	for target in state.fighters:
		if target.team == 0 and target.hp > 0 and target.z < 45.0 and absf(target.x - attacker.target_x) < reach and absf(target.y - attacker.target_y) < depth:
			var shield := _front_shield(target, attacker.x, attacker.y)
			if attacker.kind != "boss" and not shield.is_empty():
				_damage(shield, maxi(1, int(damage * _difficulty.enemy_damage)), attacker.id, false, true, true)
			else:
				_damage(target, maxi(1, int(damage * _difficulty.enemy_damage)), attacker.id, attacker.kind == "boss")


func _standing_grab_target(target: Dictionary) -> bool:
	return target.z == 0.0 and target.vz <= 0.0 and not target.airborne_lock and target.action not in ["down", "recovering", "launched", "thrown", "pulled", "grabbed", "defeated"]


func _prone_enemy(target: Dictionary) -> bool:
	return target.team == 1 and target.action in ["down", "recovering"]


func _try_grab(attacker: Dictionary) -> void:
	var closest: Dictionary = {}
	var closest_distance := INF
	for target in state.fighters:
		if target.team == attacker.team or target.hp <= 0 or target.kind == "boss" or target.weight == "heavy" or Stage04.blocks_grab(target) or target.held_by != 0 or not _standing_grab_target(target):
			continue
		var ahead: float = (target.x - attacker.x) * attacker.face
		if ahead >= -12.0 and ahead <= (135.0 if attacker.kind == "hideyoshi" else 105.0) and absf(target.y - attacker.y) <= (65.0 if attacker.kind == "hideyoshi" else 55.0) and target.z == 0.0:
			var distance := Vector2(target.x - attacker.x, target.y - attacker.y).length_squared()
			if distance < closest_distance:
				closest_distance = distance
				closest = target
	if closest.is_empty(): return
	attacker.grab_target = closest.id
	closest.held_by = attacker.id
	closest.throw_ticks = 0
	closest.thrown_by = 0
	closest.knockback = 0.0
	attacker.grab_hits = 0
	_begin(attacker, "grab_start" if CombatMoves.active(attacker) else "holding")
	_begin(closest, "grabbed")
	_event("grab", closest.x, closest.y, attacker.id, closest.id)


func _fighter(id: int) -> Dictionary:
	for fighter in state.fighters:
		if fighter.id == id: return fighter
	return {}


func _release_grab(holder: Dictionary, throwing: bool, escaping: bool = false) -> void:
	if holder.grab_target == 0: return
	if throwing and holder.kind == "hideyoshi" and holder.action == "holding":
		_begin(holder,"throw")
		return
	var target := _fighter(holder.grab_target)
	holder.grab_target = 0
	if not target.is_empty():
		target.held_by = 0
		if throwing and target.hp > 0:
			_event("throw_swing",holder.x,holder.y,holder.id,target.id)
			_damage(target, int(HERO_PROFILES.get(holder.kind, HERO_PROFILES.nobunaga).throw_damage) + holder.weapon * 4, holder.id, true, true, true,false,NAN,NAN,"throw")
			target.thrown_by = holder.id
			target.throw_ticks = 32
			target.throw_hits = []
			_launch(target, int(holder.get("throw_face",holder.face)) if CombatMoves.active(holder) else int(holder.face), 16.0, 6.0)
			if target.hp > 0: _begin(target, "thrown")
		elif target.hp > 0:
			_begin(target, "idle" if escaping else "down")
	if not throwing or holder.action != "throw": _begin(holder, "defeated" if holder.hp <= 0 else ("throw" if throwing else "idle"))


func _sync_grabs() -> void:
	for holder in state.fighters:
		if holder.grab_target == 0: continue
		var target := _fighter(holder.grab_target)
		if target.is_empty() or target.hp <= 0 or holder.hp <= 0 or holder.action not in ["holding","throw","grab_start","grab_hit_1","grab_hit_2"] or target.held_by != holder.id:
			_release_grab(holder, false)
			continue
		target.x = clampf(holder.x + holder.face * (72.0 if holder.kind == "tadakatsu" else 56.0), 80.0, _right_edge())
		target.y = holder.y + 2.0
		target.z = 0.0
		target.vz = 0.0
		target.face = holder.face
		if CombatMoves.active(holder):
			var spec := CombatMoves.spec(holder)
			var frame: Dictionary = spec.frames[0 if holder.action == "holding" else CombatMoves.frame_index(spec,combat_time_ms(holder))]
			var head: Variant = frame.get("grab_head")
			if head is Array:
				target.x = clampf(holder.x+float(head[0])*holder.face,_left_edge(),_right_edge())
				# Enemy crown/neck sits approximately 132px above its floor root.
				target.z = maxf(0,-float(head[1])-132)


func _front_shield(holder: Dictionary, source_x: float, source_y: float) -> Dictionary:
	if holder.grab_target == 0 or (source_x - holder.x) * holder.face <= 0 or absf(source_y - holder.y) > 45.0:
		return {}
	var target := _fighter(holder.grab_target)
	return target if not target.is_empty() and target.hp > 0 and target.held_by == holder.id else {}


func _resolve_throws() -> void:
	for body in state.fighters:
		if body.throw_ticks <= 0: continue
		for target in state.fighters:
			if target.team != body.team or target.id == body.id or target.hp <= 0 or target.held_by != 0 or target.id in body.throw_hits:
				continue
			if _prone_enemy(target): continue
			if absf(target.x - body.x) < 44.0 and absf(target.y - body.y) < 40.0 and absf(target.z - body.z) < 80.0:
				body.throw_hits.append(target.id)
				if _damage(target, 22, body.thrown_by, target.weight != "heavy", true, false, false, body.x-signf(body.knockback), body.y, "body_collision", 24, "blunt", -1, -1, "", false, int(body.id)) and target.weight != "heavy":
					_launch(target, 1 if body.knockback >= 0 else -1)


static func charged_release_invulnerable(fighter: Dictionary) -> bool:
	return fighter.get("team",1) == 0 and fighter.get("action","") in ["charged","charge_rain"]


func _damage(target: Dictionary, amount: int, actor: int, heavy: bool, reaction: bool = true, bypass_invuln: bool = false, strong_hit: bool = false, source_x: float = NAN, source_y: float = NAN, source_action: String = "", shatter_damage: int = 24, source_weapon: String = "", equipment_uid: int = -1, attack_id: int = -1, source_element: String = "", launch_hit: bool = false, source_body: int = 0) -> bool:
	if target.get("entering",false): return false
	if not Stage05.accepts_damage(self,target,actor,source_body): return false
	var stomp_owner := _fighter(actor) if source_action == "s05_kusei_stomp" else {}
	var repeated_stomp: bool = target.team == 0 and stomp_owner.get("s05_role","") == "kusei" and stomp_owner.get("action","") == "s05_kusei_stomp"
	# Only Kusei's five-step quake can reset ground recovery.
	if target.action in ["down", "recovering"] and not repeated_stomp: return false
	if target.hp <= 0 or target.action == "special" or charged_release_invulnerable(target) or (reaction and target.invuln > 0 and not bypass_invuln):
		return false
	var attacker := _fighter(actor)
	if not is_finite(source_x) and not attacker.is_empty():
		source_x = attacker.x
		source_y = attacker.y
	var attack_action: String = source_action if source_action != "" else str(attacker.get("action", ""))
	var mikawa_role := str(target.get("mikawa_role",""))
	var knockback_hit := heavy or launch_hit or attack_action == "body_collision"
	var guard_result := Stage04.shield_result(target,attack_action,heavy,str(attacker.get("kind","")))
	if float(guard_result.scale) == 0.0:
		target.guard_hit_tick = 10
		Stage04.audio(self,"wood_guard",int(target.id))
		return false
	amount = maxi(1,roundi(amount*float(guard_result.scale)))
	heavy = bool(guard_result.heavy)
	var impact_weapon := source_weapon if source_weapon != "" else _melee_weapon(attacker)
	var source_item := Equipment.instance(attacker,equipment_uid) if equipment_uid >= 0 else {}
	var contact := {"weapon":impact_weapon,"action":attack_action,"attack_id":attack_id if attack_id >= 0 else int(attacker.get("attack_id",0)),"action_tick":int(attacker.get("action_tick",0)),"weapon_id":str(source_item.get("item_id",attacker.get("weapon_id",""))),"material":"armor" if int(target.get("armor",0)) > 0 else "body"}
	contact.spin_finish = false
	if attack_action == "charged" and attacker.get("action","") == "charged" and attacker.get("kind","") in ["nobunaga","mitsuhide","tadakatsu"]:
		var last_contact := -1.0
		for cue in CombatMoves.spec(attacker).get("events",[]):
			if str(cue.event).begins_with("contact"): last_contact = maxf(last_contact,float(cue.ms))
		contact.spin_finish = last_contact >= 0 and combat_time_ms(attacker) >= last_contact
	var shield_ready: bool = target.get("role","") == "shield_spear" and target.held_by == 0 and target.stun == 0 and target.freeze == 0 and not target.airborne_lock and (target.action == "idle" or (target.action in ENEMY_ATTACKS.soldier and target.action_tick < int(enemy_timing(target)[0]) - 8))
	if CombatMoves.active(attacker) and attack_action == "dash_heavy": shield_ready = false
	if reaction and shield_ready and is_finite(source_x) and (source_x-target.x) * target.face > 0.0 and absf(source_y-target.y) <= 100.0:
		if not heavy and attack_action not in ["heavy","charged","dash_heavy","upper_heavy","air_heavy","charged_upper","charged_slam","special","throw"]:
			target.guard_hit_tick = 10
			target.invuln = 8
			_effect("guard",target.x,target.y,12,{"target":target.id,"face":target.face})
			_event("guard",target.x,target.y,actor,target.id)
			return false
		_effect("guard_break",target.x,target.y,20,{"target":target.id,"face":target.face})
		_event("guard_break",target.x,target.y,actor,target.id)
	# A replay-stable 25% parry window; recovery, rear attacks and charged moves cannot trigger it.
	var boss_guard: bool = reaction and target.kind == "boss" and not target.has("mikawa_role") and not target.has("s05_role") and not target.get("is_yoshimoto",false) and target.action == "idle" and target.counter_ticks == 0 and target.freeze == 0 and target.stun == 0 and not target.airborne_lock and not attacker.is_empty() and attacker.team == 0 and attack_action in ["light", "heavy", "dash_heavy", "rising", "low_sweep", "dash_strike", "air_light"] and (state.tick * 17 + target.id * 13 + actor * 7) % 100 < 25
	var player_guard := false
	if reaction and (boss_guard or target.action in ["guard", "boss_counter"]) and is_finite(source_x) and (source_x - target.x) * target.face > 0.0 and absf(source_y - target.y) <= 100.0 and (boss_guard or target.action == "guard" or target.action_tick < enemy_timing(target)[0] - 8):
		player_guard = target.team == 0
		if player_guard or boss_guard or (not heavy and not (strong_hit and not attacker.is_empty() and (attacker.kind == "boss" or attacker.action in ["heavy", "charged", "charged_upper", "upper_heavy", "air_heavy", "counter_cut"]))):
			if boss_guard:
				_begin(target, "guard")
				target.counter_ticks = 90
			if target.kind == "mitsuhide": target.counter_ticks = 45
			if target.action == "boss_counter": target.action_tick = maxi(target.action_tick, enemy_timing(target)[0] - 8)
			target.guard_hit_tick = 10
			target.invuln = 8
			_effect("guard", target.x, target.y, 12, {"target": target.id, "face": target.face})
			_event("guard", target.x, target.y, actor, target.id)
			if target.team == 0: target.rage = mini(100,target.rage+int(Equipment.bonus(target,"guard_rage")))
			if not player_guard: return false
		else:
			_effect("guard_break", target.x, target.y, 20, {"target": target.id, "face": target.face})
			_event("guard_break", target.x, target.y, actor, target.id)
			if target.kind == "ieyasu": amount = maxi(1, roundi(amount * 0.6))
	if reaction and target.freeze > 0 and (heavy or strong_hit):
		target.freeze = 0
		target.shattered_tick = state.tick
		amount += shatter_damage
		_effect("shatter", target.x, target.y - target.z, 34, {"target": target.id, "radius": 100.0})
		_event("shatter", target.x, target.y, actor, target.id)
	if reaction and not attacker.is_empty() and attacker.team == 0 and target.team == 1: amount = maxi(1,roundi(amount*Equipment.damage_multiplier(attacker,attack_action)))
	var final_damage: int = maxi(1, amount - target.armor * 3)
	if player_guard: final_damage = maxi(1,roundi(final_damage*0.2))
	if target.team == 0 and int(target.get("treasure_uid",0)) > 0:
		var previous_uid := int(target.treasure_uid)
		var absorbed := Equipment.absorb(target,final_damage)
		final_damage -= absorbed
		_effect("shield_hit",target.x,target.y,12,{"target":target.id})
		var absorbed_contact: Dictionary = contact.duplicate()
		absorbed_contact.contact = "armor_absorb"
		_event("shield_hit",target.x,target.y,actor,target.id,absorbed_contact)
		contact.sound_suppressed = true
		if int(target.treasure_uid) != previous_uid:
			_event("armor_break",target.x,target.y,target.id,target.id)
		if final_damage == 0:
			if reaction: target.invuln = maxi(target.invuln,14)
			return false
	var previous_hp: int = target.hp
	target.hp = maxi(1 if target.kind == "dummy" or (target.team == 0 and state.has("training")) else 0, target.hp - final_damage)
	if target.team == 0: _arm_food_drop()
	var actual_damage: int = previous_hp - target.hp
	if actual_damage > 0 and not state.has("training"):
		if target.team == 0:
			target.performance.flawless_kills = 0
			target.performance.chain = 0
		elif not attacker.is_empty() and attacker.team == 0:
			Achievements.damage(attacker,target,int(state.tick),attack_action,attack_id if attack_id >= 0 else int(attacker.attack_id),source_element,target.hp == 0)
			_wear_weapon(attacker,equipment_uid if equipment_uid >= 0 else int(attacker.weapon_uid))
	if target.team == 0 and reaction and actual_damage > 0:
		target.rage = mini(100,target.rage + (5 if previous_hp < target.max_hp * 0.25 else 1))
	_effect("damage", target.x, target.y - target.z, 40, {"target": target.id, "amount": actual_damage})
	_event("damage", target.x, target.y - target.z, actor, target.id, {"amount": actual_damage})
	target.damage_tick = state.tick
	if target.team == 1 and state.has("training"):
		var stats: Dictionary = state.training
		stats.last_damage = final_damage
		stats.total_damage += final_damage
		stats.last_damage_tick = state.tick
		stats.last_action = "poison" if not reaction else "hit"
		if reaction:
			stats.hit_count += 1
			stats.chain_hits = stats.chain_hits + 1 if state.tick - stats.last_hit_tick <= 60 else 1
			stats.last_hit_tick = state.tick
			if not attacker.is_empty():
				stats.last_action = attacker.action
				stats.last_stage = attacker.combo if attacker.action == "light" else (attacker.heavy_combo if attacker.action == "heavy" else 0)
	if reaction:
		target.invuln = 14
		if target.held_by != 0:
			target.shield_hurt_tick = 12
			contact.contact = "held_body"
			_event("shield_hit", target.x, target.y, actor, target.id, contact)
			_effect("shield_hit", target.x, target.y, 12, {"target": target.id})
		else:
			_release_grab(target, false)
			var boss_push: bool = target.kind == "boss" and attacker.get("team",1) == 0 and attack_action in ["heavy","air_heavy","charged","charged_upper","charged_slam","upper_heavy","dash_heavy"]
			var steady: bool = target.get("stage_boss",false) and target.action.begins_with("boss_") and not heavy and not strong_hit and target.freeze == 0
			if mikawa_role in ["kira","tominaga"]:
				# Light strings deal damage without keeping minibosses trapped in repeated hurt recovery.
				steady = attack_action in ["light","air_light"] and target.freeze == 0 and target.stun == 0
				heavy = false
			if Stage05.standing_monk(target):
				target.knockback=(12.0 if heavy or strong_hit else 6.0)*(1 if target.x>=source_x else -1)
				target.z=0.0;target.vz=0.0;target.airborne_lock=false;target.bounces_left=0
				_begin(target,"frozen" if target.freeze>0 else "hurt")
			elif attacker.get("kind","") == "hideyoshi" and attack_action == "charged":
				target.z = 0.0; target.vz = 0.0; target.knockback = 0.0; target.stun = 0
				target.airborne_lock = false; target.bounces_left = 0
				_begin(target,"down")
			elif mikawa_role == "udono":
				target.z = 0.0; target.vz = 0.0; target.knockback = 0.0
				target.airborne_lock = false; target.bounces_left = 0
				if Stage04.Data.charged(attack_action): target.stun = maxi(target.stun,78)
				if target.stun > 0 and target.action != "stunned": _begin(target,"stunned")
			elif mikawa_role in Stage04.Data.SHIELD_ROLES and not heavy:
				if not target.airborne_lock: target.knockback = (12.0 if knockback_hit else 6.0)*(1 if target.x >= source_x else -1)
				_begin(target,"frozen" if target.freeze > 0 else ("launched" if target.airborne_lock else "hurt"))
			elif boss_push:
				target.knockback = 10.0 * (1 if target.x >= source_x else -1)
				target.z = 0.0
				target.vz = 0.0
				target.airborne_lock = false
				target.bounces_left = 0
				_begin(target,"frozen" if target.freeze > 0 else "hurt")
			elif not steady: _begin(target, "frozen" if target.freeze > 0 else ("launched" if target.airborne_lock else ("down" if heavy else "hurt")))
			_event("heavy_hit" if heavy or strong_hit else "hit", target.x, target.y - target.z, actor, target.id, contact)
			_effect("hit", target.x, target.y - target.z, 12, {"heavy": heavy or strong_hit})
	elif target.poison > 0:
		_effect("poison", target.x, target.y - 32.0, 10)
	if reaction and actual_damage > 0:
		Stage04.note_hit(self,target,attacker,int(contact.attack_id),attack_action)
	if target.hp == 0:
		if state.intro.get("actor",0) == target.id: state.intro = {}
		if target.team == 0:
			target.lives = maxi(0,target.lives - 1)
			target.respawn_ticks = RESPAWN_TICKS if target.lives > 0 else 0
		else:
			_award_score(actor,5000 if target.get("stage_boss",false) else int(KILL_SCORES.get(target.kind,0)))
			_drop_boss_weapon(target,actor)
			_drop_talisman(target,actor)
			if not attacker.is_empty() and attacker.team == 0: attacker.rage = mini(100,attacker.rage+int(Equipment.bonus(attacker,"kill_rage")))
			if (state.has("stage") and attacker.get("team",1) == 0) or (not state.has("stage") and target.kind == "boss"):
				if not state.has("training"): _add_drop("food",clampf(target.x+38,_left_edge()+30,_right_edge()-30),target.y,actor)
		target.stun = 0
		target.shield_hurt_tick = 0
		target.invuln = 0
		target.freeze = 0
		target.burn = 0
		if target.held_by != 0:
			var holder := _fighter(target.held_by)
			if not holder.is_empty(): _release_grab(holder, false)
		_begin(target, "defeated")
		if target.kind == "boss":
			var death_pool: Array = boss_deaths["boss_fallen" if target.get("stage_boss",false) else "boss_minor_fallen"]
			var death: Dictionary = death_pool[target.id % death_pool.size()]
			target.death_ticks = int(death.ticks)
			target.death_voice = str(death.line_key)
		_event("defeat", target.x, target.y, actor, target.id)
		Stage03Encounter.enemy_defeated(self, target)
		if target.team == 1 and target.kind != "boss" and target.id % 2 == 0 and not state.has("stage") and not state.has("training"):
			_add_drop("food", target.x, target.y)
	return true


func _boss_getup(boss: Dictionary) -> void:
	boss.invuln = maxi(boss.invuln, 30)
	boss.cooldown = maxi(boss.cooldown, 36)
	_effect("slam", boss.x, boss.y, 24, {"radius":150.0})
	_event("landing", boss.x, boss.y, boss.id, boss.id, {"wet":_wet(boss.x,boss.y)})
	for player in state.fighters:
		if player.team != 0 or player.hp <= 0 or charged_release_invulnerable(player) or player.action in ["special", "down", "recovering"] or player.z >= 45.0: continue
		if Vector2(player.x - boss.x,(player.y - boss.y) / 0.4).length() > 150.0: continue
		_release_grab(player, false)
		player.freeze = 0
		player.stun = 0
		_launch(player, 1 if player.x >= boss.x else -1, 9.0, 6.0)
		player.invuln = maxi(player.invuln, 30)


func _player_getup(player: Dictionary) -> void:
	player.invuln = maxi(player.invuln,45)
	_effect("slam",player.x,player.y,18,{"radius":120.0})
	_event("landing",player.x,player.y,player.id,player.id,{"wet":_wet(player.x,player.y)})
	for enemy in state.fighters:
		if enemy.team != 1 or enemy.hp <= 0 or enemy.get("entering",false) or not _standing_grab_target(enemy): continue
		if Vector2(enemy.x-player.x,(enemy.y-player.y)/0.4).length() > 120.0: continue
		if not _damage(enemy,2,player.id,false,false): continue
		if enemy.get("mikawa_role","") == "udono": continue
		_release_grab(enemy,false)
		enemy.freeze = 0
		enemy.stun = 0
		enemy.cooldown = maxi(enemy.cooldown,36)
		enemy.knockback = 11.0 * (1.0 if enemy.x >= player.x else -1.0)
		if enemy.hp > 0: _begin(enemy,"hurt")
		_event("run_bump",enemy.x,enemy.y,player.id,enemy.id)


func _apply_element(target: Dictionary, element: String, owner: int, equipment_uid: int = -1, attack_id: int = -1) -> void:
	# Called only after an accepted hit; invulnerable or shielded players never gain a status.
	if element == "" or target.action == "special": return
	_effect(element + "_hit", target.x, target.y - target.z, 24, {"target": target.id})
	if element in ["fire","ice","wind","lightning"]:
		_event("element_hit",target.x,target.y-target.z,owner,target.id,{"element":element,"attack_id":attack_id})
	if target.hp <= 0: return
	var actor := _fighter(owner)
	target.element_weapon_uid = equipment_uid if equipment_uid >= 0 else int(actor.get("weapon_uid",0))
	target.element_attack_id = attack_id if attack_id >= 0 else int(actor.get("attack_id",0))
	target.element_action = str(actor.get("action",""))
	if element == "fire":
		target.burn = roundi(180*(1-Equipment.bonus(target,"burn_resist")))
		target.burn_tick = 0
		target.burn_owner = owner
		target.freeze = 0
		if target.action == "frozen": _begin(target, "hurt")
	elif element == "ice" and target.shattered_tick != state.tick:
		target.burn = 0
		target.freeze = roundi((30 if target.get("stage_boss",false) else 90)*(1-Equipment.bonus(target,"freeze_resist")))
		target.freeze_owner = owner
		if not target.airborne_lock:
			target.knockback = 0.0
			target.vz = 0.0
		if target.held_by == 0:
			_release_grab(target, false)
			_begin(target, "frozen")


func _wave(fighter: Dictionary, radius: float, damage: int, element: String, life: int, centered: bool = false, arc_degrees: float = 360.0, knockdown: bool = true) -> void:
	# Oichi's ice field shares her simultaneous bow release; it is not a sword swing.
	if fighter.kind != "oichi": _weapon_release(fighter, _melee_weapon(fighter))
	if fighter.team == 0:
		var equipment := Weapons.item(str(fighter.weapon_id))
		damage += int(equipment.get("damage_bonus",0)) + int(Equipment.bonus(fighter,"damage_bonus"))
		radius += float(equipment.get("reach_bonus",0)) + Equipment.bonus(fighter,"reach_bonus")
	if HERO_PROFILES.has(fighter.kind):
		radius *= sqrt(HERO_PROFILES[fighter.kind].reach)
		damage = maxi(1, roundi(damage * HERO_PROFILES[fighter.kind].damage))
	_effect("shockwave", fighter.x + (0.0 if centered else fighter.face * 55.0), fighter.y, life, {"radius": radius, "owner": fighter.id, "team": fighter.team, "face": fighter.face, "damage": damage,"equipment_uid":int(fighter.get("weapon_uid",0)),"attack_id":int(fighter.get("attack_id",0)),"action":fighter.action,"equipment_knockback":float(Weapons.item(str(fighter.get("weapon_id",""))).get("knockback",0)), "hit_ids": [], "element": element, "charged": fighter.action == "charged_slam", "arc_degrees": arc_degrees, "knockdown": knockdown})


func _inside_arc(dx: float, dy: float, face: int, arc_degrees: float) -> bool:
	if arc_degrees >= 360.0: return true
	var offset := Vector2(dx * face, dy / 0.4)
	return offset.is_zero_approx() or offset.normalized().x >= cos(deg_to_rad(arc_degrees * 0.5))


func _poison(target: Dictionary, duration: int, owner: int, equipment_uid: int = -1) -> void:
	duration = roundi(duration*(1-Equipment.bonus(target,"poison_resist")))
	target.poison = maxi(target.poison, duration)
	target.poison_owner = owner
	target.poison_tick = 0
	target.poison_weapon_uid = equipment_uid if equipment_uid >= 0 else int(_fighter(owner).get("weapon_uid",0))


func _launch(target: Dictionary, direction: int, horizontal: float = 8.0, vertical: float = 6.0) -> void:
	if Stage05.invulnerable(target): return
	if charged_release_invulnerable(target) or not Stage04.permits_launch(target): return
	if target.kind == "boss" and target.hp <= 0: return
	if target.held_by != 0 or target.freeze > 0: return
	if Stage05.standing_monk(target):
		target.knockback=direction*horizontal
		_begin(target,"hurt")
		return
	target.knockback = direction * (9.0 if target.team == 0 and horizontal >= 8.0 else horizontal)
	target.z = maxf(target.z, 1.0)
	target.vz = vertical
	target.airborne_lock = true
	target.bounces_left = 2 if target.team == 0 else 1
	target.landing_count = 0
	if target.hp > 0: _begin(target, "launched")


func _melee_weapon(fighter: Dictionary) -> String:
	if fighter.has("mikawa_role"):
		if fighter.mikawa_role == "udono" or fighter.mikawa_role.begins_with("spear_"): return "spear"
		if fighter.mikawa_role.begins_with("shield_"): return "blunt" if fighter.action == "spear_butt" else "sword"
	var kind := str(fighter.get("kind", ""))
	if kind == "hideyoshi" and fighter.get("action","") == "charged_slam": return "blunt"
	if fighter.get("action", "") in ["holding", "throw"]: return "blunt"
	if kind == "oichi":
		if fighter.get("action", "") == "dash_heavy": return "needle"
		return "kick" if fighter.get("action", "") == "light" else "blunt"
	if kind == "mitsuhide":
		var weapon_id := str(fighter.get("weapon_id", "practice_mitsuhide"))
		var weapon := Weapons.item(weapon_id)
		if weapon.get("art_id", weapon_id) in ["staff_long_staff", "staff_ornate_shakujo"]: return "blunt"
		if weapon.get("family", "") == "spear": return "spear"
	if kind in ["soldier", "tadakatsu"]: return "spear"
	if kind == "flag": return "blunt"
	if kind == "boss" and fighter.get("boss_variant", "") in ["kusarigama", "weighted_chain"]: return "chain"
	return "sword"


func _weapon_release(fighter: Dictionary, weapon: String) -> void:
	var type := "bow_release" if weapon in ["arrow", "special_arrow"] else ("gunshot" if weapon == "bullet" else "weapon_swing")
	# A volley is one string release, even when it creates three/five projectiles.
	var shared_release := false
	for event in state.events:
		if event.type == type and event.actor == fighter.id:
			if event.get("weapon", "") == weapon: return
			shared_release = true
	_event(type, fighter.x, fighter.y, fighter.id, 0, {"weapon": weapon, "weapon_id":fighter.get("weapon_id",""), "action": fighter.action, "action_tick": fighter.action_tick, "attack_id":fighter.get("attack_id",0), "sound_suppressed":shared_release})


func _projectile(attacker: Dictionary, damage: int, poison: int, finisher: bool = false, weapon: String = "needle", reach: float = 260.0, lane: float = 0.0, element: String = "", shatter_hit: bool = true, options: Dictionary = {}) -> void:
	if attacker.team == 1 and weapon == "arrow" and not options.get("straight",false):
		_arc_arrow(attacker, damage)
		return
	var equipment: Dictionary = Weapons.item(str(attacker.get("weapon_id",""))) if attacker.team == 0 and weapon in ["arrow","special_arrow","blade"] else {}
	if attacker.team == 0:
		damage += int(Equipment.bonus(attacker,"damage_bonus"))
		reach += Equipment.bonus(attacker,"reach_bonus")
	damage += int(equipment.get("damage_bonus",0))
	reach += float(equipment.get("reach_bonus",0))
	if options.get("descending",false): reach = minf(reach,420.0)
	if element == "": element = str(equipment.get("element",""))
	var speed := FAST_PROJECTILE_SPEED if weapon in ["bullet", "blade"] else (11.0 if weapon == "needle" else (9.0 if attacker.team == 1 else HERO_ARROW_SPEED))
	var angle := deg_to_rad(float(options.get("spread_angle", 0.0)))
	var vx: float = attacker.face * speed * cos(angle)
	var vy := speed * sin(angle) * 0.4
	var lifetime := int(ceil(reach / absf(vx))) + 2
	var origin := 40.0 if attacker.team == 1 else 105.0
	var extra := {
		"z": attacker.z + 28.0, "face": attacker.face, "vx": vx, "vy": vy,
		"previous_x": attacker.x + attacker.face * 25.0, "previous_y": attacker.y + lane,
		"owner": attacker.id, "team": attacker.team, "damage": damage, "poison": poison, "finisher": finisher,
		"action": attacker.action, "action_tick": attacker.action_tick, "combo": attacker.combo, "heavy_combo": attacker.heavy_combo,
		"weapon": weapon, "element": element, "shatter_hit": shatter_hit, "charged": attacker.action in ["charged", "charged_upper", "charged_slam"], "rising": attacker.action in ["rising", "upper_heavy", "charged_upper"], "range_left": reach - origin, "hit_depth": 28.0 if weapon == "special_arrow" else (18.0 if weapon == "needle" else 12.0),
		"equipment_id":str(attacker.get("weapon_id","")), "equipment_uid":int(attacker.get("weapon_uid",0)),"attack_id":int(attacker.get("attack_id",0)), "equipment_knockback":float(equipment.get("knockback",0)),
		"height_tolerance": 100.0 if attacker.action in ["air_light", "air_heavy"] else 70.0, "piercing": weapon in ["special_arrow", "blade"] or (element == "ice" and weapon != "arrow"), "hit_ids": [], "stun": 0,
	}
	for field in ["piercing", "burst_radius", "burst_damage", "shatter_damage", "follow_freeze"]:
		if options.has(field): extra[field] = options[field]
	if options.get("descending",false):
		extra.descending = true
		extra.start_z = attacker.z + 28.0
		extra.vz = -(attacker.z + 28.0) * absf(vx) / maxf(1.0,reach - origin)
	_effect("projectile", attacker.x + attacker.face * origin, attacker.y + lane, lifetime, extra)
	_weapon_release(attacker, weapon)


func _arc_arrow(attacker: Dictionary, damage: int, landing_distance: float = 0.0) -> void:
	var closest: Dictionary = {}
	var distance := INF
	var fire_area: bool = attacker.get("role","") == "fire_archer"
	if fire_area:
		closest = {"x":float(attacker.target_x),"y":float(attacker.target_y)}
		distance = Vector2(closest.x-attacker.x,closest.y-attacker.y).length()
	elif landing_distance > 0:
		closest = {"x":clampf(attacker.x + attacker.face * landing_distance,_left_edge()+30,_right_edge()-30),"y":attacker.y}
		distance = absf(closest.x - attacker.x)
		damage += int(Weapons.item(str(attacker.get("weapon_id",""))).get("damage_bonus",0)) + int(Equipment.bonus(attacker,"damage_bonus"))
	else:
		for player in state.fighters:
			if player.team != 0 or player.hp <= 0: continue
			var span := Vector2(player.x - attacker.x, player.y - attacker.y).length()
			if span < distance:
				distance = span
				closest = player
	if closest.is_empty(): return
	var origin_x: float = attacker.x + attacker.face * 40.0
	var flight := clampi(int(distance / 7.0) + 20, 45, 150)
	_effect("projectile", origin_x, attacker.y, flight + 2, {
		"z": 40.0, "vx": (closest.x - origin_x) / flight, "vy": (closest.y - attacker.y) / flight, "vz": 0.0,
		"face": attacker.face, "owner": attacker.id, "team": attacker.team, "damage": damage, "poison": 0,
		"action": attacker.action, "action_tick": attacker.action_tick, "combo": attacker.combo, "heavy_combo": attacker.heavy_combo,
		"weapon": "arrow", "element": "fire" if fire_area else "", "fire_area":fire_area, "equipment_uid":int(attacker.get("weapon_uid",0)),"attack_id":int(attacker.get("attack_id",0)),"arcing": true, "flight_tick": 0, "flight_ticks": flight,
		"origin_x": origin_x, "origin_y": attacker.y, "target_x": closest.x, "target_y": closest.y,
		"start_z": 40.0, "arc_height": 140.0 + distance * 0.08, "hit_ids": [], "finisher": false})
	if attacker.team == 1: _effect("arrow_target", closest.x, closest.y, flight, {"owner": attacker.id, "radius": 78.0 if fire_area else 32.0,"element":"fire" if fire_area else ""})
	_weapon_release(attacker, "arrow")


func _tick_arc_arrow(effect: Dictionary) -> void:
	effect.flight_tick += 1
	var progress := minf(1.0, float(effect.flight_tick) / effect.flight_ticks)
	effect.x = lerpf(effect.origin_x, effect.target_x, progress)
	effect.y = lerpf(effect.origin_y, effect.target_y, progress)
	effect.z = effect.start_z * (1.0 - progress) + 4.0 * effect.arc_height * progress * (1.0 - progress)
	effect.vz = (-effect.start_z + 4.0 * effect.arc_height * (1.0 - 2.0 * progress)) / effect.flight_ticks
	if effect.flight_tick < effect.flight_ticks: return
	for player in state.fighters:
		if player.team == effect.team or player.hp <= 0 or player.z > 45.0: continue
		if absf(player.x - effect.x) > 32.0 or absf(player.y - effect.y) > 28.0: continue
		var target: Dictionary = player
		var shield := _front_shield(player, effect.origin_x, effect.origin_y)
		if not shield.is_empty(): target = shield
		_damage(target, effect.damage, effect.owner, false, true, target.held_by != 0, false, effect.origin_x, effect.origin_y, effect.get("action", ""), 24, "arrow",int(effect.get("equipment_uid",0)),int(effect.get("attack_id",0)))
		break
	for prop in state.props:
		if not prop.broken and absf(prop.x - effect.x) < prop.width * 0.5 and absf(prop.y - effect.y) < prop.depth * 0.5:
			_damage_prop(prop, effect.damage, effect.owner,"arrow")
			break
	_effect("arrow_impact", effect.x, effect.y, 24, {"wet": _wet(effect.x, effect.y)})
	var cart: Dictionary = state.get("challenge",{})
	if effect.team == 1 and not cart.is_empty() and absf(cart.x-effect.x) < 55 and absf(cart.y-effect.y) < 38: _hurt_cart(int(effect.damage),int(effect.owner))
	if effect.get("fire_area",false):
		_effect("fire_patch",effect.x,effect.y,150,{"radius":78.0,"owner":effect.owner,"team":effect.team,"damage":maxi(1,roundi(8 * _difficulty.enemy_damage)),"warmup":30,"interval":45})
	effect.life = 0


func _tick_effects() -> void:
	# Damage can append effects; iterate a snapshot so new effects begin next tick.
	for effect in state.effects.duplicate():
		effect.life -= 1
		if state.phase != "playing": continue
		if effect.type == "s05_wave":
			Stage05.projectile(self,effect)
			continue
		if effect.has("mikawa_projectile"):
			Stage04.projectile(self,effect)
			continue
		if effect.type == "sky_arrow":
			effect.z += 20.0
			if effect.z > effect.y+90:
				_effect("arrow_rain",effect.rain_center_x,effect.y,48,{"owner":effect.owner,"team":effect.team,"damage":effect.damage,"radius":effect.radius,"equipment_uid":effect.equipment_uid,"attack_id":effect.attack_id})
				effect.life = 0
		if effect.type == "arrow_rain" and effect.max_life-effect.life == 18:
			for target in state.fighters:
				if target.team == effect.team or target.hp <= 0 or target.z>60: continue
				if Vector2(target.x-effect.x,(target.y-effect.y)/.2).length() <= effect.radius:
					_damage(target,int(effect.damage),effect.owner,true,true,false,true,effect.x,effect.y,"charge_rain",24,"arrow",int(effect.equipment_uid),int(effect.attack_id))
		if effect.type == "chain" and effect.get("target", 0) != 0:
			var chained := _fighter(effect.target)
			var chain_owner := _fighter(effect.owner)
			if chained.is_empty() or chain_owner.is_empty() or chained.pull_owner != effect.owner or chain_owner.action not in ["boss_chain", "boss_hook", "boss_grab_throw"]:
				effect.life = 0
			else:
				effect.x = chain_owner.x
				effect.y = chain_owner.y
				effect.target_x = chained.x
				effect.target_y = chained.y
		if effect.type == "shockwave":
			_tick_shockwave(effect)
		if effect.type == "fire_patch":
			var age: int = effect.max_life - effect.life
			if age >= effect.warmup and (age - effect.warmup) % effect.interval == 0:
				var cart: Dictionary = state.get("challenge",{})
				if effect.team == 1 and not cart.is_empty() and Vector2(cart.x-effect.x,(cart.y-effect.y)*1.8).length() <= effect.radius: _hurt_cart(int(effect.damage),int(effect.owner))
				for target in state.fighters:
					if target.team == effect.team or target.hp <= 0 or target.z > 45.0: continue
					if Vector2(target.x-effect.x,(target.y-effect.y)*1.8).length() <= effect.radius:
						_damage(target,effect.damage,effect.owner,false,true,false,false,effect.x,effect.y,"bow_shot",24,"arrow")
		if effect.type != "projectile" or effect.life <= 0:
			continue
		if effect.get("arcing", false):
			_tick_arc_arrow(effect)
			continue
		# The first swept segment includes the extended arm so close targets cannot be skipped.
		var previous_x: float = effect.get("previous_x", effect.x) if effect.life == effect.max_life - 1 else effect.x
		var previous_y: float = effect.get("previous_y", effect.y) if effect.life == effect.max_life - 1 else effect.y
		var distance := minf(absf(effect.vx), float(effect.get("range_left", absf(effect.vx))))
		if effect.get("descending",false): distance = minf(distance,float(effect.z) * absf(effect.vx) / maxf(0.001,-float(effect.vz)))
		effect.x += signf(effect.vx) * distance
		effect.y += float(effect.get("vy", 0.0)) * distance / maxf(absf(effect.vx), 0.001)
		var supply: Dictionary = state.get("challenge",{})
		if effect.team == 1 and supply.get("status","") == "active" and effect.z < 95 and supply.x >= minf(previous_x,effect.x)-45 and supply.x <= maxf(previous_x,effect.x)+45 and absf(supply.y-effect.y) < 32:
			_hurt_cart(int(effect.damage),int(effect.owner))
			effect.life = 0
			continue
		if effect.get("descending",false): effect.z = maxf(0.0,effect.z + effect.vz * distance / maxf(absf(effect.vx),0.001))
		if effect.get("rising", false): effect.z += 1.4
		if effect.has("range_left"): effect.range_left -= distance
		var targets: Array = state.fighters.duplicate()
		targets.append_array(state.props.filter(func(prop: Dictionary) -> bool: return not prop.broken))
		targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x < b.x if effect.vx > 0 else a.x > b.x)
		for target in targets:
			var crossing_y := lerpf(previous_y, effect.y, clampf((target.x - previous_x) / (effect.x - previous_x), 0.0, 1.0)) if effect.x != previous_x else float(effect.y)
			if target.has("broken"):
				if target.id in effect.get("hit_ids", []): continue
				if target.x + target.width * 0.5 >= minf(previous_x, effect.x) and target.x - target.width * 0.5 <= maxf(previous_x, effect.x) and absf(target.y - crossing_y) <= target.depth * 0.5 and effect.z <= 95.0:
					_damage_prop(target, effect.damage, effect.owner,str(effect.get("weapon","")))
					if effect.has("hit_ids"): effect.hit_ids.append(target.id)
					if effect.get("burst_radius", 0.0) > 0.0: _ice_burst(effect, target.x, target.y, target.id)
					if effect.life <= 0 or not effect.get("piercing", false):
						effect.life = 0
						break
				continue
			var hostile_shield: bool = target.held_by != 0 and not _fighter(target.held_by).is_empty() and _fighter(target.held_by).team != effect.team
			if _prone_enemy(target): continue
			if (target.team == effect.team and not hostile_shield) or target.hp <= 0 or target.id in effect.get("hit_ids", []):
				continue
			if target.x > minf(previous_x, effect.x) - 27.0 and target.x < maxf(previous_x, effect.x) + 27.0 and absf(target.y - crossing_y) < effect.get("hit_depth", 30.0) and absf(target.z + float(effect.get("collision_height",28.0)) - effect.z) < effect.get("height_tolerance", 70.0):
				if target.team == 0:
					var shield := _front_shield(target, previous_x, effect.y)
					if not shield.is_empty(): target = shield
				if target.id in effect.get("hit_ids", []): continue
				var frozen_followup: bool = effect.get("follow_freeze", false) and effect.get("action", "") == "charged_slam" and effect.get("weapon", "") == "arrow" and target.freeze > 0 and target.freeze_owner == effect.owner
				var aerial_arrow: bool = target.team == 1 and effect.team == 0 and effect.get("action", "") == "air_heavy" and effect.get("weapon", "") == "arrow"
				if _damage(target, effect.damage, effect.owner, effect.get("finisher", false), true, target.held_by != 0 or frozen_followup or aerial_arrow, effect.get("weapon", "needle") != "needle" and effect.get("shatter_hit", true), previous_x, crossing_y, effect.get("action", ""), effect.get("shatter_damage", 24), effect.get("weapon", "needle"),int(effect.get("equipment_uid",0)),int(effect.get("attack_id",0)),str(effect.get("element","")),effect.get("rising",false) or (effect.get("team",1) == 0 and effect.get("action","") == "heavy" and effect.get("weapon","") == "blade")):
					if target.weight != "heavy": target.knockback += effect.face*float(effect.get("standing_push",0))
					if effect.get("team",1) == 0 and effect.get("action","") == "heavy" and effect.get("weapon","") == "blade" and target.weight != "heavy":
						_launch(target,effect.face,2.2,4.6)
						target.bounces_left = 0
					elif effect.get("finisher", false) and target.weight != "heavy": _launch(target, effect.face, 16.0 if effect.get("charged", false) else (13.0 if effect.get("weapon", "needle") == "arrow" else 8.0))
					elif effect.get("rising", false) and target.weight == "light":
						_launch(target, effect.face, 1.4, 7.0)
					if target.weight != "heavy" and effect.get("action","") != "heavy": target.knockback += effect.face * float(effect.get("equipment_knockback",0))
					if effect.get("stun", 0) > 0 and target.hp > 0 and target.held_by == 0:
						target.stun = effect.stun
						_begin(target, "stunned")
					if effect.poison > 0:
						_poison(target, effect.poison, effect.owner,int(effect.get("equipment_uid",0)))
					_apply_element(target, effect.get("element", ""), effect.owner,int(effect.get("equipment_uid",0)),int(effect.get("attack_id",0)))
				if effect.has("hit_ids"): effect.hit_ids.append(target.id)
				if effect.get("burst_radius", 0.0) > 0.0: _ice_burst(effect, target.x, target.y, target.id)
				if effect.life <= 0 or not effect.get("piercing", false):
					effect.life = 0
					break
		if effect.get("descending",false) and effect.z <= 0.01:
			_effect("arrow_impact",effect.x,effect.y,24,{"wet":_wet(effect.x,effect.y)})
			effect.life = 0
		if effect.get("range_left", 1.0) <= 0: effect.life = 0
	state.effects = state.effects.filter(func(effect: Dictionary) -> bool: return effect.life > 0)


func _ice_burst(projectile: Dictionary, x: float, y: float, first_target: int) -> void:
	# Consume before applying splash: even a blocked arrow can only burst once.
	projectile.life = 0
	var radius: float = projectile.burst_radius
	_effect("ice_hit", x, y, 24, {"owner": projectile.owner, "team": projectile.team, "radius": radius, "burst": true})
	var hit_ids := [first_target]
	for candidate in state.fighters:
		if candidate.team == projectile.team or candidate.hp <= 0 or candidate.id in hit_ids or absf(candidate.z + 28.0 - projectile.z) >= projectile.get("height_tolerance", 70.0): continue
		if Vector2(candidate.x - x, (candidate.y - y) / 0.4).length() > radius: continue
		var target: Dictionary = candidate
		var shield := _front_shield(target, x, y)
		if not shield.is_empty(): target = shield
		if target.id in hit_ids: continue
		hit_ids.append(target.id)
		if _damage(target, int(projectile.get("burst_damage", 6)), projectile.owner, false, true, target.held_by != 0, false, x, y, "charged",24,"arrow",int(projectile.get("equipment_uid",0)),int(projectile.get("attack_id",0)),"ice"):
			_apply_element(target, "ice", projectile.owner,int(projectile.get("equipment_uid",0)),int(projectile.get("attack_id",0)))
	projectile.burst_radius = 0.0


func _tick_shockwave(effect: Dictionary) -> void:
	var radius: float = effect.radius * (1.0 - float(effect.life) / effect.max_life)
	for prop in state.props:
		if prop.broken or prop.id in effect.hit_ids: continue
		if not _inside_arc(prop.x - effect.x, prop.y - effect.y, effect.face, effect.get("arc_degrees", 360.0)): continue
		if Vector2(prop.x - effect.x, (prop.y - effect.y) / 0.4).length() <= radius + prop.width * 0.5:
			effect.hit_ids.append(prop.id)
			_damage_prop(prop, effect.damage, effect.owner)
	for target in state.fighters:
		if target.team == effect.team or target.hp <= 0 or target.held_by != 0 or target.z >= 22.0 or target.id in effect.hit_ids:
			continue
		if _prone_enemy(target): continue
		var distance := Vector2(target.x - effect.x, (target.y - effect.y) / 0.4).length()
		if distance <= radius and _inside_arc(target.x - effect.x, target.y - effect.y, effect.face, effect.get("arc_degrees", 360.0)):
			effect.hit_ids.append(target.id)
			var knockdown: bool = effect.get("knockdown", true)
			if _damage(target, effect.damage, effect.owner, knockdown and target.weight != "heavy", true, false, knockdown,NAN,NAN,str(effect.get("action","")),24,"",int(effect.get("equipment_uid",0)),int(effect.get("attack_id",0)),str(effect.get("element","")),knockdown):
				if knockdown and target.weight == "light": _launch(target, 1 if target.x >= effect.x else -1, 14.0 if effect.get("charged", false) else 3.0, 6.0 if effect.get("charged", false) else 4.0)
				_apply_element(target, effect.get("element", ""), effect.owner,int(effect.get("equipment_uid",0)),int(effect.get("attack_id",0)))


func _pickup(fighter: Dictionary) -> void:
	var full := false
	for drop in state.drops:
		if absf(drop.x - fighter.x) > 55.0 or absf(drop.y - fighter.y) > 40.0:
			continue
		match drop.kind:
			"food":
				if fighter.hp == fighter.max_hp:
					if Equipment.add(fighter,"food_"+str(drop.get("food_id","rice"))) == 0:
						full = true
						continue
					fighter.pickup_flash_tick = state.tick
					_event("food_stored",drop.x,drop.y,fighter.id,drop.id,{"food_id":str(drop.get("food_id","rice"))})
				else: _eat_food(fighter,str(drop.get("food_id","rice")),int(drop.get("heal",40)),int(drop.id))
			"weapon":
				var id: String = drop.get("weapon_id","")
				if not Weapons.compatible(fighter.kind,id): continue
				var uid := Equipment.add(fighter,id)
				if uid == 0:
					full = true
					continue
				Equipment.sync(fighter)
				fighter.pickup_flash_tick = state.tick
			"armor":
				if fighter.armor > 0:
					continue
				fighter.armor = 1
			"talisman":
				var key: String = drop.get("talisman_id","vajra")
				if not TALISMANS.has(key): continue
				var uid := Equipment.add(fighter,key)
				if uid == 0:
					full = true
					continue
				Equipment.sync(fighter)
				fighter.pickup_flash_tick = state.tick
				_event("armor_pickup",drop.x,drop.y,fighter.id,drop.id)
		if drop.kind not in ["food","talisman"]: _event("pickup", drop.x, drop.y, fighter.id, drop.id)
		state.drops.erase(drop)
		return
	if full: _event("inventory_full",fighter.x,fighter.y,fighter.id,0)


func _arm_food_drop() -> void:
	if not state.has("stage"): return
	for player in state.fighters:
		if player.team == 0 and player.get("food_state","ready") == "ready" and player.hp > 0 and player.hp * 2 < player.max_hp:
			player.food_state = "pending"


func _eat_food(fighter: Dictionary, food_id: String, heal: int, target: int = 0) -> void:
	var restored: int = mini(fighter.max_hp-fighter.hp,roundi(heal*(1+Equipment.bonus(fighter,"food_bonus"))))
	fighter.hp += restored
	fighter.pickup_flash_tick = state.tick
	_event("food_pickup",fighter.x,fighter.y,fighter.id,target,{"food_id":food_id,"heal":restored})


func _add_drop(kind: String, x: float, y: float, owner: int = 0) -> bool:
	# Reserve food slots for both players across the segment's at most four checkpoints.
	if state.drops.size() >= (56 if state.has("stage") and kind != "food" else 64): return false
	if kind == "food" and state.has("stage"):
		var player := _fighter(owner)
		if player.get("team",1) != 0 or player.get("food_state","ready") != "pending": return false
		player.food_state = "spent"
	state.drops.append({"id": _next_id, "kind": kind, "x": x, "y": y})
	if kind == "weapon":
		var hero: String = state.fighters[0].kind if not state.fighters.is_empty() else "nobunaga"
		state.drops[-1].weapon_id = Weapons.upgrades(hero,Weapons.default_for(hero))[0]
	if kind == "talisman": state.drops[-1].talisman_id = "vajra"
	if kind == "food" and state.has("stage"):
		state.drops[-1].food_id = ["rice","fish","dango","peach"][_next_id % 4]
		state.drops[-1].heal = 40
	_next_id += 1
	return true


func _begin(fighter: Dictionary, action: String) -> void:
	if Stage05.standing_monk(fighter) and action in ["down","launched","thrown","recovering"]:
		action="frozen" if fighter.freeze>0 else "hurt"
		fighter.z=0.0;fighter.vz=0.0;fighter.airborne_lock=false;fighter.bounces_left=0
	if fighter.kind == "hideyoshi" and action == "charged": fighter.knockback = 0.0
	fighter.combat_previous_ms = -1.0
	fighter.combat_step = 0.0
	fighter.combat_hit_ids = []
	if CombatMoves.active(fighter) and action in ["grab_hit_1","grab_hit_2","charge_rain"]:
		fighter.attack_id = int(fighter.get("attack_id",0))+1
		fighter.attack_speed = float(Weapons.item(str(fighter.weapon_id)).get("attack_speed",1))
	if fighter.team == 0 and action in ["light","heavy","charged","rising","ground_slam","low_sweep","dash_strike","dash_heavy","air_light","air_heavy","upper_heavy","charged_upper","charged_slam","mixed_finisher","mixed_rising","counter_cut","special","throw"]:
		fighter.attack_id = int(fighter.get("attack_id",0)) + 1
		fighter.attack_speed = float(Weapons.item(str(fighter.weapon_id)).get("attack_speed",1.0))
		fighter.attack_reach = 0.0
	if action != "idle":
		fighter.sprinting = false
		fighter.sprint_ticks = 0
	if action in ["light", "heavy", "charged", "rising", "ground_slam", "low_sweep", "dash_strike", "dash_heavy", "air_light", "air_heavy", "upper_heavy", "charged_upper", "charged_slam", "mixed_finisher", "mixed_rising", "counter_cut", "special"] or ENEMY_TIMING.has(action):
		if state.civilian_spawn_enabled:
			state.civilian_spawn_enabled = false
			state.civilian_flee_tick = state.tick
			state.civilian_flee_x = fighter.x
		if action != "special": _event("swing", fighter.x, fighter.y, fighter.id, 0, {"action": action, "combo": fighter.combo if action == "light" else 0, "heavy_combo": fighter.heavy_combo if action == "heavy" else 0, "finisher": (action == "light" and fighter.combo == 3) or (action == "heavy" and fighter.heavy_combo == 2)})
	if action == "down": fighter.down_ticks = DOWN_TICKS
	if fighter.action in ["boss_chain", "boss_hook", "boss_grab_throw"] and action not in ["boss_chain", "boss_hook", "boss_grab_throw"]:
		var target := _fighter(fighter.chain_target)
		fighter.chain_target = 0
		if not target.is_empty() and target.pull_owner == fighter.id:
			target.pull_owner = 0
			if target.action == "pulled": _begin(target, "idle")
	if fighter.action == "pulled" and action != "pulled":
		var owner := _fighter(fighter.pull_owner)
		if not owner.is_empty() and owner.chain_target == fighter.id: owner.chain_target = 0
		fighter.pull_owner = 0
	if fighter.team == 0 and action in ["light", "heavy"]:
		fighter.last_attack = action
		fighter.mixed_tick = 70
	elif fighter.team == 0 and action in ["hurt", "down", "stunned", "frozen", "pulled", "defeated"]:
		fighter.last_attack = ""
		fighter.mixed_tick = 0
	if fighter.team == 0 and action not in ["idle", "holding"]:
		_queued_buttons[fighter.player_index] = 0
	if fighter.team == 0 and action not in ["idle", "light"]:
		fighter.combo = 0
		fighter.combo_tick = 0
	if fighter.team == 0 and action not in ["idle", "charge", "heavy"]:
		_queued_heavy[fighter.player_index] = -1
		_queued_slam[fighter.player_index] = false
		fighter.heavy_combo = 0
		fighter.heavy_combo_tick = 0
	fighter.down_from_air = false
	fighter.action = action
	fighter.action_tick = 0


func _effect(type: String, x: float, y: float, life: int, extra: Dictionary = {}) -> void:
	var effect := {"type": type, "x": x, "y": y, "life": life, "max_life": life}
	effect.merge(extra)
	state.effects.append(effect)


func _event(type: String, x: float, y: float, actor: int, target: int, extra: Dictionary = {}) -> void:
	state.event_seq += 1
	var event := {"type": type, "x": x, "y": y, "actor": actor, "target": target, "id": state.event_seq}
	var source := _fighter(actor)
	var victim := _fighter(target)
	if not state.has("training"):
		if type == "guard" and not victim.is_empty() and victim.team == 0: Achievements.increment(victim.performance,"guards")
		if not source.is_empty() and source.team == 0:
			if type == "prop_break": Achievements.increment(source.performance,"props")
			if type == "shatter": Achievements.increment(source.performance,"shatters")
	if not source.is_empty():
		if source.has("mikawa_role"): event.actor_mikawa = true
		event.actor_kind = source.kind
		event.actor_team = source.team
		event.actor_faction = source.faction
	if not victim.is_empty():
		if victim.has("mikawa_role"): event.target_mikawa = true
		event.target_kind = victim.kind
		event.target_faction = victim.faction
		if type == "defeat" and victim.kind == "boss":
			event.target_stage_boss = bool(victim.get("stage_boss",false))
			event.line_key = str(victim.get("death_voice",""))
	event.merge(extra)
	state.events.append(event)
