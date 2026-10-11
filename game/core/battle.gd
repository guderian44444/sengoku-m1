extends RefCounted

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
const HEROES := ["nobunaga", "oichi", "hideyoshi", "ieyasu", "mitsuhide", "tadakatsu"]
const HERO_PROFILES := {
	"nobunaga": {"attack_speed": 1.0, "move_speed": 1.0, "reach": 1.0, "depth": 1.0, "damage": 1.0, "throw_damage": 31, "element": "fire"},
	"oichi": {"attack_speed": 1.0, "move_speed": 1.0, "reach": 1.0, "depth": 1.0, "damage": 1.0, "throw_damage": 31, "element": "ice"},
	"hideyoshi": {"attack_speed": 1.25, "move_speed": 1.12, "reach": 0.88, "depth": 0.85, "damage": 0.85, "throw_damage": 47, "element": "wind"},
	"ieyasu": {"attack_speed": 0.88, "move_speed": 0.92, "reach": 1.08, "depth": 1.25, "damage": 1.08, "throw_damage": 38, "element": "earth"},
	"mitsuhide": {"attack_speed": 1.12, "move_speed": 1.04, "reach": 1.10, "depth": 0.82, "damage": 0.98, "throw_damage": 28, "element": "blade"},
	"tadakatsu": {"attack_speed": 0.80, "move_speed": 0.86, "reach": 1.48, "depth": 0.78, "damage": 1.25, "throw_damage": 55, "element": "wind"},
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
	"hideyoshi": [18, 44, 70, 96, 122, 148, 174, 198], "ieyasu": [36, 102, 168],
	"mitsuhide": [24, 66, 108, 150, 192], "tadakatsu": [36, 84, 132, 180],
}
const ENEMY_SPEED := 0.7
const DOWN_TICKS := 60
const RECOVER_TICKS := 36
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
	"boss_grab_throw": [26, 92],
}
const DIFFICULTIES := {
	"easy": {"enemy_hp": 0.75, "enemy_damage": 0.65, "player_hp": 140},
	"normal": {"enemy_hp": 1.0, "enemy_damage": 1.0, "player_hp": 120},
	"hard": {"enemy_hp": 1.35, "enemy_damage": 1.3, "player_hp": 105},
}

var state: Dictionary = {}
var _previous_buttons: Array = []
var _queued_light: Array = []
var _queued_heavy: Array = []
var _queued_slam: Array = []
var _difficulty: Dictionary = {}
var _next_id := 1
var boss_intros: Dictionary = {}


func _init() -> void:
	reset()


func reset(difficulty: String = "normal", player_count: int = 1, hero_ids: Array = ["nobunaga", "oichi"], faction: String = "mori") -> void:
	if not DIFFICULTIES.has(difficulty):
		difficulty = "normal"
	_difficulty = DIFFICULTIES[difficulty]
	_next_id = 1
	if not FACTIONS.has(faction): faction = "mori"
	_previous_buttons = []
	_queued_light = []
	_queued_heavy = []
	_queued_slam = []
	state = {"tick": 0, "phase": "playing", "wave": 1, "fighters": [], "drops": [], "effects": [], "event_seq": 0, "events": [], "difficulty": difficulty,
		"props": [], "wet_zones": [{"x": 700.0, "y": 515.0, "width": 360.0, "depth": 150.0}, {"x": 1650.0, "y": 465.0, "width": 380.0, "depth": 150.0}],
		"civilian_spawn_enabled": true, "civilian_flee_tick": -1, "civilian_flee_x": 0.0, "faction": faction, "intro": {}}
	for i in range(clampi(player_count, 1, 2)):
		var hero: String = str(hero_ids[i]) if i < hero_ids.size() else HEROES[i]
		if not HEROES.has(hero):
			hero = HEROES[i]
		var fighter := _make_fighter(0, hero, 220.0 + i * 65.0, 460.0 + i * 55.0, int(_difficulty.player_hp))
		fighter.player_index = i
		state.fighters.append(fighter)
		_previous_buttons.append(0)
		_queued_light.append("")
		_queued_heavy.append(-1)
		_queued_slam.append(false)
	_add_drop("weapon", 390.0, 450.0)
	_add_drop("armor", 450.0, 505.0)
	_add_drop("food", 520.0, 465.0)
	_spawn_props()
	_spawn_wave()


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
		state.fighters.append(_make_fighter(1, "boss", 830.0, 480.0, 600))
		_start_boss_intro(state.fighters[-1])
	for fighter in state.fighters:
		fighter.home_x = fighter.x
		fighter.home_y = fighter.y


func cancel_input(player_index: int = 0) -> void:
	if player_index < 0 or player_index >= _previous_buttons.size():
		return
	_previous_buttons[player_index] = 0
	_queued_light[player_index] = ""
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
			fighter.move_dy = 0
			fighter.tap_tick = -1000
			if not fighter.airborne_lock and fighter.action not in ["hurt", "down", "recovering", "stunned", "frozen", "pulled", "defeated", "special", "victory"]:
				fighter.charge = 0
				_begin(fighter, "idle")


func step(inputs: Array) -> void:
	state.events = []
	if not state.intro.is_empty() and state.intro.remaining_ticks > 0:
		if not state.intro.announced:
			state.intro.announced = true
			_event("boss_intro", 0.0, 0.0, state.intro.actor, 0, {"name": state.intro.name, "line_key": state.intro.line_key})
		state.intro.remaining_ticks -= 1
		return
	if state.phase != "playing":
		# Land existing launches and finish the celebration without accepting combat input.
		var settling := false
		for fighter in state.fighters:
			settling = settling or fighter.z > 0 or fighter.vz > 0 or absf(fighter.knockback) > 0.1 or (fighter.hp <= 0 and fighter.action_tick < 24)
			if state.phase == "won" and fighter.team == 0 and fighter.hp > 0 and fighter.kind in ["nobunaga", "oichi"]:
				fighter.freeze = 0
				settling = settling or fighter.action != "victory" or fighter.action_tick < VICTORY_TICKS
		if settling:
			state.tick += 1
			for fighter in state.fighters: _tick_motion(fighter)
		if state.phase == "won":
			state.effects.clear()
			for fighter in state.fighters:
				if fighter.team == 0 and fighter.hp > 0 and fighter.kind in ["nobunaga", "oichi"]:
					_tick_victory(fighter)
		return
	state.tick += 1
	_sync_grabs()
	_tick_effects()
	for fighter in state.fighters:
		_tick_motion(fighter)
		if fighter.hp <= 0:
			continue
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
	if state.get("mode", "") == "training":
		_tick_training()
		return
	var players_alive := false
	var enemies_alive := false
	for fighter in state.fighters:
		if fighter.hp > 0:
			if fighter.team == 0:
				players_alive = true
			else:
				enemies_alive = true
	if not players_alive:
		state.phase = "lost"
	elif not enemies_alive:
		if state.wave == 3:
			state.phase = "won"
		else:
			state.wave += 1
			_spawn_wave()


func _tick_victory(fighter: Dictionary) -> void:
	fighter.moving = false
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
		if state.tick - fighter.damage_tick < 120 or fighter.held_by != 0 or fighter.grab_target != 0:
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
	var fighter := {
		"id": _next_id, "team": team, "kind": kind, "x": x, "y": y, "z": 0.0, "vz": 0.0,
		"hp": hp, "max_hp": hp, "rage": 0, "face": 1 if team == 0 else -1,
		"action": "idle", "action_tick": 0, "charge": 0, "armor": 0, "weapon": 0,
		"invuln": 0, "poison": 0, "poison_tick": 0, "poison_owner": 0,
		"combo": 0, "combo_tick": 0, "player_index": -1, "target_x": x, "target_y": y,
		"cooldown": 20, "knockback": 0.0, "heavy_combo": 0, "heavy_combo_tick": 0,
		"weight": "heavy" if kind == "boss" else ("medium" if kind == "nobunaga" else "light"),
		"grab_target": 0, "held_by": 0, "thrown_by": 0, "throw_ticks": 0, "throw_hits": [],
		"stun": 0, "shield_hurt_tick": 0, "damage_tick": 0,
		"burn": 0, "burn_tick": 0, "burn_owner": 0, "freeze": 0, "freeze_owner": 0, "shattered_tick": -1,
		"charge_direction": 0, "mixed_ready": false, "mixed_tick": 0, "last_attack": "",
		"attack_variant": 0, "ai_cycle": 0, "chain_target": 0, "pull_owner": 0,
		"sprinting": false, "sprint_dx": 0, "sprint_dy": 0, "move_dx": 0, "move_dy": 0,
		"tap_dx": 0, "tap_dy": 0, "tap_tick": -1000, "bump_cooldown": 0, "guard_hit_tick": 0,
		"airborne_lock": false, "bounces_left": 0, "landing_count": 0, "down_ticks": DOWN_TICKS, "down_from_air": false,
		"counter_ticks": 0, "faction": state.get("faction", "mori") if team == 1 else "heroes", "boss_variant": FACTIONS[state.get("faction", "mori")].boss if kind == "boss" else "",
	}
	_next_id += 1
	return fighter


func _spawn_wave() -> void:
	var x: float = [650.0, 1340.0, 2100.0][int(state.wave) - 1]
	if state.has("training"): x = clampf(state.fighters[0].x + 320.0, 540.0, 1930.0)
	var ranged: String = FACTIONS[state.faction].ranged
	var kinds: Array = ["soldier", "soldier", "flag", ranged] if state.wave == 1 else (["commander", "soldier", "archer", ranged] if state.wave == 2 else ["boss"])
	if state.wave == 1 and _previous_buttons.size() == 2: kinds.append("soldier")
	for index in range(kinds.size()):
		var kind: String = kinds[index]
		var hp: int = {"soldier": 70, "flag": 90, "archer": 55, "gunner": 65, "commander": 150, "boss": 420}[kind]
		var fighter := _make_fighter(1, kind, clampf(x + index * 70.0, 80.0, 2280.0), [440.0, 550.0, 390.0, 490.0, 585.0][index], int(hp * _difficulty.enemy_hp))
		fighter.home_x = fighter.x
		fighter.home_y = fighter.y
		state.fighters.append(fighter)
		if kind == "boss": _start_boss_intro(fighter)
	if state.wave == 2 and not state.has("training"): _add_drop("food", 1130.0, 460.0)


func _start_boss_intro(boss: Dictionary) -> void:
	if not boss_intros.has(state.faction): return
	var intro: Dictionary = boss_intros[state.faction]
	var duration := clampi(int(intro.get("ticks", 180)), 1, 1800)
	state.intro = {"actor": boss.id, "name": str(intro.get("name", "")), "line_key": str(intro.get("line_key", "")), "remaining_ticks": duration, "duration": duration, "announced": false}


static func hero_tick(kind: String, tick: int) -> int:
	return maxi(1, roundi(tick / float(HERO_PROFILES.get(kind, HERO_PROFILES.nobunaga).attack_speed)))


static func enemy_timing(fighter: Dictionary) -> Array:
	var timing: Array = ENEMY_TIMING.get(fighter.action, [30, 60])
	if fighter.kind != "boss": return timing
	var speed: float = BOSS_PROFILES.get(fighter.get("boss_variant", ""), BOSS_PROFILES.kusarigama).speed
	return [roundi(timing[0] / speed), roundi(timing[1] / speed)]


func _tick_motion(fighter: Dictionary) -> void:
	if fighter.hp <= 0:
		fighter.action_tick = mini(24, fighter.action_tick + 1)
	if fighter.held_by != 0 or fighter.freeze > 0 or fighter.action == "pulled":
		return
	if absf(fighter.knockback) > 0.1:
		fighter.x = clampf(fighter.x + fighter.knockback, 80.0, 2300.0)
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
					_begin(fighter, "defeated" if fighter.hp <= 0 else "down")
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
			if _damage(fighter, 3, fighter.burn_owner, false, false):
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
			_damage(fighter, 3, fighter.poison_owner, false, false)
	if fighter.hp <= 0:
		return
	fighter.action_tick += 1
	if fighter.airborne_lock: return
	if ENEMY_TIMING.has(fighter.action):
		_tick_enemy_attack(fighter)
		return
	match fighter.action:
		"light":
			if fighter.combo == 3 and fighter.action_tick <= hero_tick(fighter.kind, 6):
				fighter.x = clampf(fighter.x + fighter.face * 42.0 / hero_tick(fighter.kind, 6), 80.0, 2300.0)
			if fighter.action_tick == hero_tick(fighter.kind, 6):
				var finisher: bool = fighter.combo == 3
				if fighter.kind == "oichi":
					if finisher:
						_melee(fighter, 180.0, 95.0, 22 + fighter.weapon * 4, true, 0, true, false, 55.0)
					else:
						_projectile(fighter, 9 + fighter.weapon * 4, 0, false, "needle", 260.0)
				else:
					var uppercut: bool = fighter.combo == 2
					var blade_air: bool = finisher and fighter.kind == "nobunaga"
					_melee(fighter, (260.0 if blade_air else 180.0) if finisher else (130.0 if uppercut else 110.0), 85.0 if finisher else (42.0 if uppercut else 30.0), 12 + fighter.weapon * 5 + fighter.combo * 2, finisher, 0, finisher, uppercut)
					if blade_air:
						# The extended cut and its visible air trail share one hit, including at sword range.
						_effect("blade_wave", fighter.x, fighter.y, 18, {"owner": fighter.id, "team": fighter.team, "face": fighter.face, "radius": 260.0, "action": "light", "combo": 3})
			if fighter.action_tick >= hero_tick(fighter.kind, 19):
				_begin(fighter, "idle")
		"rising":
			if fighter.action_tick == hero_tick(fighter.kind, 6):
				if fighter.kind == "oichi":
					for lane in [-22.0, 0.0, 22.0]:
						_projectile(fighter, 14 + fighter.weapon * 4, 0, false, "needle", 220.0, lane)
				else:
					_melee(fighter, 145.0, 48.0, 18 + fighter.weapon * 5, false, 0, false, true)
			if fighter.action_tick >= hero_tick(fighter.kind, 24):
				_begin(fighter, "idle")
		"low_sweep":
			if fighter.action_tick == hero_tick(fighter.kind, 9):
				if fighter.kind == "oichi":
					for lane in [-25.0, 0.0, 25.0]: _projectile(fighter, 12 + fighter.weapon * 4, 0, true, "needle", 250.0, lane)
				else: _melee(fighter, 180.0, 75.0, 20 + fighter.weapon * 5, true)
			if fighter.action_tick >= hero_tick(fighter.kind, 28): _begin(fighter, "idle")
		"dash_strike":
			if fighter.action_tick <= hero_tick(fighter.kind, 9): fighter.x = clampf(fighter.x + fighter.face * 6.0, 80.0, 2300.0)
			if fighter.action_tick == hero_tick(fighter.kind, 10):
				if fighter.kind == "oichi": _projectile(fighter, 21 + fighter.weapon * 4, 0, false, "needle", 320.0)
				else: _melee(fighter, 155.0, 30.0, 24 + fighter.weapon * 5, false)
			if fighter.action_tick >= hero_tick(fighter.kind, 30): _begin(fighter, "idle")
		"dash_heavy":
			if fighter.action_tick <= hero_tick(fighter.kind, 9): fighter.x = clampf(fighter.x + fighter.face * 6.0, 80.0, 2300.0)
			if fighter.action_tick == hero_tick(fighter.kind, 12):
				var spear: bool = fighter.kind in ["hideyoshi", "tadakatsu"]
				_melee(fighter, 205.0 if spear else 190.0, 28.0 if spear else 85.0, 32 + fighter.weapon * 6, true, 0, true, false, 0.0, "", 360.0 if spear else 120.0)
				if fighter.kind == "oichi":
					for angle in [-32.0, -16.0, 0.0, 16.0, 32.0]:
						_projectile(fighter, 8 + fighter.weapon * 2, 0, true, "needle", 360.0, 0.0, "", true, {"spread_angle": angle})
			if fighter.action_tick >= hero_tick(fighter.kind, 34): _begin(fighter, "idle")
		"air_light":
			if fighter.action_tick == hero_tick(fighter.kind, 6):
				if fighter.kind == "oichi": _projectile(fighter, 18 + fighter.weapon * 4, 0, false, "needle", 350.0)
				else: _melee(fighter, 155.0, 60.0, 22 + fighter.weapon * 5, false, 0, false, true)
			if fighter.action_tick >= hero_tick(fighter.kind, 20): _begin(fighter, "idle")
		"air_heavy":
			if fighter.action_tick == hero_tick(fighter.kind, 12):
				fighter.vz = -10.0
				if fighter.kind == "oichi":
					for lane in [-30.0, 0.0, 30.0]: _projectile(fighter, 28 + fighter.weapon * 5, 0, true, "arrow", 700.0, lane)
				else: _melee(fighter, 165.0, 85.0, 37 + fighter.weapon * 6, true, 0, true)
			if fighter.action_tick == hero_tick(fighter.kind, 19): _wave(fighter, 190.0, 18, "", 18)
			if fighter.action_tick >= hero_tick(fighter.kind, 38): _begin(fighter, "idle")
		"upper_heavy", "charged_upper":
			var powered: bool = fighter.action == "charged_upper"
			if fighter.action_tick == hero_tick(fighter.kind, 22 if powered else 12):
				if fighter.kind == "oichi":
					_projectile(fighter, (42 if powered else 25) + fighter.weapon * 6, 0, true, "arrow", 1200.0 if powered else 650.0, 0.0, "ice", true, {"piercing": false})
				else: _melee(fighter, 235.0 if powered else 165.0, 90.0 if powered else 55.0, (48 if powered else 30) + fighter.weapon * 6, true, 0, false, true, 18.0, HERO_PROFILES[fighter.kind].element if powered else "")
			if fighter.action_tick >= hero_tick(fighter.kind, 56 if powered else 36): _begin(fighter, "idle")
		"mixed_finisher", "mixed_rising":
			if fighter.action_tick in [hero_tick(fighter.kind, 9), hero_tick(fighter.kind, 27)]:
				var last: bool = fighter.action_tick == hero_tick(fighter.kind, 27)
				if fighter.kind == "oichi":
					_projectile(fighter, (31 if last else 15) + fighter.weapon * 5, 0, last, "arrow" if last else "needle", 950.0 if last else 280.0)
				else: _melee(fighter, 220.0 if last else 140.0, 95.0 if last else 40.0, (32 if last else 16) + fighter.weapon * 5, last, 0, last, fighter.action == "mixed_rising")
			if fighter.action_tick >= hero_tick(fighter.kind, 48): _begin(fighter, "idle")
		"ground_slam", "charged_slam":
			var powered: bool = fighter.action == "charged_slam"
			if fighter.action_tick == hero_tick(fighter.kind, 28 if powered else 14):
				if fighter.kind == "oichi" and not powered:
					for lane in [-40.0, 0.0, 40.0]: _projectile(fighter, 25 + fighter.weapon * 5, 0, true, "arrow", 440.0, lane)
				elif powered and fighter.kind in ["nobunaga", "oichi"]:
					_wave(fighter, 320.0, 6 if fighter.kind == "oichi" else 65 + fighter.weapon * 6, HERO_PROFILES[fighter.kind].element, 42, true, 120.0 if fighter.kind == "oichi" else 360.0, fighter.kind != "oichi")
				else:
					_wave(fighter, 480.0 if powered else 240.0, (65 if powered else 32) + fighter.weapon * 6, HERO_PROFILES[fighter.kind].element if powered else "", 42 if powered else 24)
			if powered and fighter.action_tick == 28 and fighter.kind == "oichi":
				for angle in [-32.0, 0.0, 32.0]: _projectile(fighter, 10, 0, true, "arrow", 1200.0, 0.0, "", true, {"piercing": false, "shatter_damage": 0, "follow_freeze": true, "spread_angle": angle})
			if fighter.action_tick >= hero_tick(fighter.kind, 72 if powered else 42):
				_begin(fighter, "idle")
		"heavy", "charged":
			if fighter.action_tick == hero_tick(fighter.kind, 14):
				var charged: bool = fighter.action == "charged"
				var second: bool = fighter.heavy_combo == 2
				if fighter.kind == "oichi":
					_projectile(fighter, (43 if charged else (30 if second else 24)) + fighter.weapon * 6, 0, charged or second, "arrow", 1450.0 if charged else 760.0, 0.0, "ice" if charged else "", true, {"piercing": false, "burst_radius": 100.0, "burst_damage": 6} if charged else {})
				else:
					_melee(fighter, 255.0 if charged else 140.0, 90.0 if charged else 68.0, (43 if charged else (34 if second else 26)) + fighter.weapon * 8, charged or second, 0, charged or second, false, 18.0, HERO_PROFILES[fighter.kind].element if charged else "")
			if fighter.action_tick >= hero_tick(fighter.kind, 36):
				_begin(fighter, "idle")
		"throw":
			if fighter.action_tick >= hero_tick(fighter.kind, 24):
				_begin(fighter, "idle")
		"counter_cut":
			if fighter.action_tick == hero_tick(fighter.kind, 5):
				_melee(fighter, 225.0, 60.0, 48 + fighter.weapon * 6, true, 0, true, false, 18.0, "blade")
			if fighter.action_tick >= hero_tick(fighter.kind, 24): _begin(fighter, "idle")
		"special":
			if fighter.kind not in ["nobunaga", "oichi"]:
				_tick_hero_special(fighter)
				return
			if fighter.action_tick in SPECIAL_HIT_TICKS[fighter.kind]:
				var final: bool = fighter.action_tick == 192
				if fighter.kind == "oichi":
					for lane in [-90.0, -45.0, 0.0, 45.0, 90.0]:
						_projectile(fighter, (48 if final else 22) + fighter.weapon * 4, 0, final, "special_arrow", 1700.0, lane, "ice", final)
					_effect("ice_wave", fighter.x, fighter.y, 42, {"face": fighter.face, "radius": 600.0 if final else 400.0})
				else:
					_melee(fighter, 520.0 if final else 390.0, 150.0, (55 if final else 27) + fighter.weapon * 5, final, 0, final, false, 350.0, "fire")
					_effect("fire_wave", fighter.x, fighter.y, 42, {"face": fighter.face, "radius": 520.0 if final else 390.0})
			if fighter.action_tick >= SPECIAL_TICKS:
				_begin(fighter, "idle")
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
			if fighter.action_tick >= RECOVER_TICKS:
				_begin(fighter, "idle")
		"charge":
			fighter.charge = mini(90, fighter.charge + 1)
		"holding":
			if fighter.action_tick == 30:
				var held := _fighter(fighter.grab_target)
				# One replay-stable roll per hold; later shield hits cannot reroll it.
				if not held.is_empty() and (state.tick * 17 + fighter.id * 13 + held.id * 7) % 100 < 50:
					_release_grab(fighter, false, true)
			elif fighter.action_tick >= 180: _release_grab(fighter, false)
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


func _player_input(fighter: Dictionary, input: Dictionary, index: int) -> void:
	if int(input.get("buttons", 0)) & CANCEL:
		cancel_input(index)
		return
	var buttons := int(input.get("buttons", 0)) & 191
	var pressed: int = buttons & ~int(_previous_buttons[index])
	var released: int = int(_previous_buttons[index]) & ~buttons
	_previous_buttons[index] = buttons
	var dx := clampi(int(input.get("dx", 0)), -1, 1)
	var dy := clampi(int(input.get("dy", 0)), -1, 1)
	# Once the second ordinary cut connects, its third cut keeps the facing and
	# cannot be replaced by an inserted direction command.
	var finishing_light: bool = fighter.combo == 2 and fighter.combo_tick > 0 and fighter.action in ["light", "idle"] and (pressed & LIGHT or _queued_light[index] != "") and not (pressed & HEAVY or _queued_heavy[index] >= 0)
	if finishing_light:
		dx = 0
		dy = 0
	# A fresh direction + light is a command; an already-held direction is ordinary movement.
	var directional_light: bool = dx != 0 and dx != fighter.move_dx
	var light_action := "air_light" if fighter.z > 0.0 else ("rising" if dy < 0 else ("low_sweep" if dy > 0 else ("dash_strike" if directional_light else "light")))
	if light_action == "light" and fighter.last_attack == "heavy" and fighter.mixed_tick > 0: light_action = "mixed_rising"
	_update_sprint(fighter, dx, dy)
	if fighter.freeze > 0 or fighter.airborne_lock or fighter.action == "pulled": return
	if fighter.action == "guard":
		if dx != 0: fighter.face = dx
		if fighter.kind == "mitsuhide" and fighter.counter_ticks > 0 and pressed & LIGHT:
			fighter.counter_ticks = 0
			fighter.invuln = 12
			_begin(fighter, "counter_cut")
			return
		if buttons & GUARD: return
		_begin(fighter, "idle")
	if fighter.action == "holding":
		if not buttons & GRAB:
			_release_grab(fighter, true)
		else:
			var move := Vector2(clampi(int(input.get("dx", 0)), -1, 1), clampi(int(input.get("dy", 0)), -1, 1)).normalized()
			fighter.x = clampf(fighter.x + move.x * 3.5 * 0.45, 80.0, 2300.0)
			fighter.y = clampf(fighter.y + move.y * 2.65 * 0.45, 360.0, 600.0)
			if move.x != 0: fighter.face = int(signf(move.x))
		return
	# Buffer only one fresh press; holding attack never invents another hit.
	if fighter.action == "light" and pressed & LIGHT and fighter.combo < 3:
		_queued_light[index] = light_action
	if fighter.action == "heavy" and pressed & LIGHT:
		_queued_light[index] = light_action
	if fighter.action in ["light", "heavy"] and pressed & HEAVY:
		_queued_heavy[index] = 0
		_queued_slam[index] = dy
	if _queued_heavy[index] >= 0 and buttons & HEAVY:
		_queued_heavy[index] = mini(90, _queued_heavy[index] + 1)
	if fighter.action == "charge":
		if released & HEAVY:
			_release_heavy(fighter)
		return
	if fighter.action != "idle":
		return
	if buttons & GUARD and fighter.z == 0.0:
		if dx != 0: fighter.face = dx
		_begin(fighter, "guard")
		return
	var next_light: String = light_action if pressed & LIGHT else str(_queued_light[index])
	var heavy_direction: int = dy if pressed & HEAVY else int(_queued_slam[index])
	var continuing_combo: bool = (fighter.combo > 0 and fighter.combo < 3 and fighter.combo_tick > 0) or (fighter.heavy_combo == 1 and fighter.heavy_combo_tick > 0)
	if continuing_combo: fighter.sprinting = false
	var movement := Vector2(0 if continuing_combo else dx, dy).normalized()
	if not (pressed & (HEAVY | LIGHT) or _queued_heavy[index] >= 0 or _queued_light[index] != ""):
		var speed: float = (2.0 if fighter.sprinting else 1.0) * HERO_PROFILES[fighter.kind].move_speed
		fighter.x = clampf(fighter.x + movement.x * 3.5 * speed, 80.0, 2300.0)
		fighter.y = clampf(fighter.y + movement.y * 2.65 * speed, 360.0, 600.0)
		if fighter.sprinting: _sprint_bump(fighter)
	if dx != 0:
		fighter.face = dx
	if pressed & INTERACT:
		_pickup(fighter)
	if pressed & SPECIAL and fighter.rage >= 100 and fighter.z == 0.0:
		fighter.rage = 0
		_begin(fighter, "special")
		_event("special", fighter.x, fighter.y, fighter.id, 0)
	elif pressed & GRAB and fighter.z == 0.0:
		_try_grab(fighter)
	elif pressed & HEAVY or _queued_heavy[index] >= 0:
		if pressed & HEAVY and fighter.sprinting and fighter.z == 0.0:
			fighter.charge = 0
			fighter.mixed_ready = false
			_begin(fighter, "dash_heavy")
			return
		fighter.charge = maxi(0, _queued_heavy[index])
		fighter.charge_direction = heavy_direction
		fighter.mixed_ready = fighter.last_attack == "light" and fighter.mixed_tick > 0 and heavy_direction == 0
		_queued_heavy[index] = -1
		_queued_slam[index] = false
		if fighter.z > 0.0:
			_begin(fighter, "air_heavy")
		elif buttons & HEAVY:
			_begin(fighter, "charge")
		else:
			_release_heavy(fighter)
	elif pressed & LIGHT or _queued_light[index] != "":
		_queued_light[index] = ""
		if next_light != "light":
			_begin(fighter, next_light)
		else:
			fighter.combo = fighter.combo % 3 + 1
			fighter.combo_tick = 42
			_begin(fighter, "light")
	elif pressed & JUMP and fighter.z == 0.0:
		fighter.vz = 9.0
		fighter.z = 1.0


func _release_heavy(fighter: Dictionary) -> void:
	var charged: bool = fighter.charge >= 35
	if fighter.charge_direction > 0:
		_begin(fighter, "charged_slam" if charged else "ground_slam")
	elif fighter.charge_direction < 0:
		_begin(fighter, "charged_upper" if charged else "upper_heavy")
	elif charged:
		_begin(fighter, "charged")
	elif fighter.mixed_ready:
		_begin(fighter, "mixed_finisher")
	else:
		fighter.heavy_combo = fighter.heavy_combo % 2 + 1
		fighter.heavy_combo_tick = 70
		_begin(fighter, "heavy")


func _tick_hero_special(fighter: Dictionary) -> void:
	var tick: int = fighter.action_tick
	if fighter.kind == "hideyoshi" and tick in SPECIAL_HIT_TICKS.hideyoshi:
		_melee(fighter, 265.0, 115.0, 35 if tick == 198 else 17, tick == 198, 0, tick == 198, false, 210.0, "wind")
		_effect("wind_wave", fighter.x, fighter.y, 24, {"face": fighter.face, "radius": 300.0, "kind": fighter.kind})
	elif fighter.kind == "ieyasu" and tick in SPECIAL_HIT_TICKS.ieyasu:
		_wave(fighter, 560.0 if tick == 168 else 420.0, 70 if tick == 168 else 45, "earth", 42)
		_effect("earth_wave", fighter.x, fighter.y, 42, {"face": fighter.face, "radius": 560.0 if tick == 168 else 420.0, "kind": fighter.kind})
	elif fighter.kind == "mitsuhide" and tick in SPECIAL_HIT_TICKS.mitsuhide:
		for lane in [-40.0, 0.0, 40.0]: _projectile(fighter, 52 if tick == 192 else 24, 0, tick == 192, "blade", 1500.0, lane, "blade")
		_effect("blade_wave", fighter.x, fighter.y, 28, {"face": fighter.face, "radius": 620.0, "kind": fighter.kind})
	elif fighter.kind == "tadakatsu" and tick in SPECIAL_HIT_TICKS.tadakatsu:
		_melee(fighter, 690.0, 70.0, 64 if tick == 180 else 36, tick == 180, 0, tick == 180, false, 18.0, "wind")
		_effect("wind_wave", fighter.x, fighter.y, 34, {"face": fighter.face, "radius": 1020.0, "kind": fighter.kind})
	if tick >= SPECIAL_TICKS: _begin(fighter, "idle")


func _update_sprint(fighter: Dictionary, dx: int, dy: int) -> void:
	if dx != fighter.move_dx or dy != fighter.move_dy:
		if dx == 0 and dy == 0:
			fighter.sprinting = false
		else:
			fighter.sprinting = fighter.action == "idle" and fighter.z == 0.0 and not fighter.airborne_lock and fighter.move_dx == 0 and fighter.move_dy == 0 and dx == fighter.tap_dx and dy == fighter.tap_dy and state.tick - fighter.tap_tick <= 15
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
	_event("landing", fighter.x, fighter.y, fighter.id, fighter.id, {"wet": _wet(fighter.x, fighter.y)})


func _spawn_props() -> void:
	for spec in [["stall", 440.0, 570.0, 80, 130.0, 44.0, "food"], ["cart", 920.0, 410.0, 65, 115.0, 38.0, "weapon"], ["jar", 1200.0, 545.0, 22, 46.0, 28.0, "food"], ["basket", 1630.0, 570.0, 18, 54.0, 28.0, "food"], ["crate", 1960.0, 415.0, 38, 64.0, 36.0, "armor"]]:
		state.props.append({"id": _next_id, "kind": spec[0], "x": spec[1], "y": spec[2], "hp": spec[3], "max_hp": spec[3], "width": spec[4], "depth": spec[5], "broken": false, "drop": spec[6]})
		_next_id += 1


func _damage_prop(prop: Dictionary, damage: int, owner: int) -> void:
	if prop.broken: return
	prop.hp = maxi(0, prop.hp - damage)
	_effect("hit", prop.x, prop.y - 25.0, 10, {"heavy": damage >= 25})
	if prop.hp == 0:
		prop.broken = true
		_effect("debris", prop.x, prop.y, 36, {"kind": prop.kind, "target": prop.id})
		_event("prop_break", prop.x, prop.y, owner, prop.id)
		_add_drop(prop.drop, prop.x, prop.y)


func _melee_props(attacker: Dictionary, reach: float, depth: float, damage: int, behind: float = 18.0, arc_degrees: float = 360.0) -> void:
	if attacker.z > 80.0: return
	for prop in state.props:
		var ahead: float = (prop.x - attacker.x) * attacker.face
		if not _inside_arc(prop.x - attacker.x, prop.y - attacker.y, attacker.face, arc_degrees): continue
		if not prop.broken and ahead + prop.width * 0.5 >= -behind and ahead - prop.width * 0.5 <= reach and absf(prop.y - attacker.y) < depth + prop.depth * 0.5:
			_damage_prop(prop, damage, attacker.id)


func _enemy_input(fighter: Dictionary) -> void:
	fighter.move_dx = 0
	fighter.move_dy = 0
	if fighter.freeze > 0 or fighter.airborne_lock: return
	if fighter.stun > 0:
		if fighter.action == "idle": _begin(fighter, "stunned")
		return
	if fighter.kind == "dummy" or not fighter.action in ["idle", "retreat", "bow_shot", "gun_shot"]:
		return
	var target: Dictionary = {}
	var distance := INF
	for player in state.fighters:
		if player.team != 0 or player.hp <= 0:
			continue
		var delta := Vector2(player.x - fighter.x, (player.y - fighter.y) * 1.8)
		if delta.length_squared() < distance:
			distance = delta.length_squared()
			target = player
	if target.is_empty():
		return
	fighter.face = 1 if target.x >= fighter.x else -1
	var dx: float = target.x - fighter.x
	var dy: float = target.y - fighter.y
	if absf(dx) > 950.0:
		return
	var ranged: bool = fighter.kind in ["archer", "gunner"]
	if ranged:
		if absf(dx) < (270.0 if fighter.action == "retreat" else 210.0) and absf(dy) < 85.0 and (fighter.action in ["idle", "retreat"] or fighter.action_tick < int(ENEMY_TIMING[fighter.action][0]) - 8):
			if fighter.action != "retreat": _begin(fighter, "retreat")
			var away: float = -fighter.face
			var against_wall: bool = fighter.x + away * 60.0 < 80.0 or fighter.x + away * 60.0 > 2300.0
			if against_wall:
				var side := 1.0 if target.y < 480.0 else -1.0
				fighter.y = clampf(fighter.y + side * 3.6 * ENEMY_SPEED, 360.0, 600.0)
				fighter.move_dy = int(side)
				# Move past the pursuer in a different lane before reversing away from the wall.
				if absf(dy) > 45.0:
					fighter.x = clampf(fighter.x + fighter.face * 3.4 * ENEMY_SPEED, 80.0, 2300.0)
					fighter.move_dx = fighter.face
			else:
				fighter.x = clampf(fighter.x + away * 3.0 * ENEMY_SPEED, 80.0, 2300.0)
				fighter.move_dx = int(away)
			return
		if fighter.action not in ["idle", "retreat"]: return
		if fighter.action == "retreat": _begin(fighter, "idle")
	var reach := (900.0 if fighter.kind == "gunner" else 760.0) if ranged else (165.0 if fighter.kind == "soldier" else 120.0)
	var attacks: Array = ENEMY_ATTACKS.get(fighter.kind, ENEMY_ATTACKS.soldier)
	if fighter.kind == "boss":
		var profile: Dictionary = BOSS_PROFILES.get(fighter.boss_variant, BOSS_PROFILES.kusarigama)
		attacks = profile.actions
		var next: String = attacks[fighter.ai_cycle % attacks.size()]
		reach = float({"boss_chain": 380.0, "boss_hook": 190.0, "boss_grab_throw": 150.0, "boss_volley": 850.0, "boss_thrust": 240.0, "boss_sweep": 220.0, "boss_earth": 230.0}.get(next, 145.0)) * profile.reach
	if absf(dx) < reach and absf(dy) < 32.0 and fighter.cooldown == 0:
		fighter.target_x = fighter.x + fighter.face * (100.0 if fighter.kind == "boss" else 75.0)
		fighter.target_y = fighter.y
		if ranged:
			_begin(fighter, "gun_shot" if fighter.kind == "gunner" else "bow_shot")
		else:
			fighter.attack_variant = fighter.ai_cycle % attacks.size()
			fighter.ai_cycle += 1
			_begin(fighter, attacks[fighter.attack_variant])
			_effect("warning", fighter.target_x, fighter.target_y, int(ENEMY_TIMING[fighter.action][0]), {"radius": 210.0 if fighter.kind == "boss" else 115.0, "owner": fighter.id, "face": fighter.face})
	else:
		var speed := (1.65 if fighter.kind == "boss" else 1.4) * ENEMY_SPEED
		if absf(dx) > reach * 0.8:
			fighter.x = clampf(fighter.x + signf(dx) * speed, 80.0, 2300.0)
		if absf(dy) > 7.0:
			fighter.y = clampf(fighter.y + signf(dy) * speed * 0.65, 360.0, 600.0)


func _tick_enemy_attack(fighter: Dictionary) -> void:
	var action: String = fighter.action
	var timing: Array = enemy_timing(fighter)
	if action == "commander_dash" and fighter.action_tick >= 18 and fighter.action_tick <= 29:
		fighter.x = clampf(fighter.x + fighter.face * 4.0 * ENEMY_SPEED, 80.0, 2300.0)
	if action == "boss_dash" and fighter.action_tick >= timing[0] - 14 and fighter.action_tick < timing[0]:
		fighter.x = clampf(fighter.x + fighter.face * 4.8 * ENEMY_SPEED, 80.0, 2300.0)
	if fighter.action_tick == int(timing[0]):
		match action:
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
				_wave(fighter, 290.0, int(28 * _difficulty.enemy_damage), "", 32)
				_effect("earth_wave", fighter.x, fighter.y, 32, {"face": fighter.face, "radius": 290.0, "kind": "boss"})
	if action == "boss_double" and fighter.action_tick == timing[0] + 18:
		_enemy_melee(fighter, 200.0, 75.0, 22, "down")
	if action in ["boss_chain", "boss_hook"] and fighter.action_tick == timing[0] + 28:
		var target := _fighter(fighter.chain_target)
		if not target.is_empty() and target.pull_owner == fighter.id:
			target.pull_owner = 0
			if _damage(target, int(24 * _difficulty.enemy_damage), fighter.id, false, true, false, true):
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
		_begin(fighter, "idle")


func _enemy_melee(attacker: Dictionary, reach: float, depth: float, amount: int, reaction: String = "") -> void:
	_weapon_release(attacker, _melee_weapon(attacker))
	if attacker.kind == "boss":
		var profile: Dictionary = BOSS_PROFILES.get(attacker.boss_variant, BOSS_PROFILES.kusarigama)
		reach *= profile.reach
		amount = maxi(1, roundi(amount * profile.damage))
	_effect("slash", attacker.x + attacker.face * reach * 0.5, attacker.y, 12, {"face": attacker.face, "radius": reach * 0.55})
	_melee_props(attacker, reach, depth, amount)
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
			elif reaction == "stun":
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
		elif _damage(closest, 6, attacker.id, false):
			attacker.chain_target = closest.id
			closest.pull_owner = attacker.id
			_begin(closest, "pulled")
	_effect("chain", attacker.x, attacker.y, 30, {"owner": attacker.id, "target": attacker.chain_target, "target_x": endpoint, "target_y": attacker.y, "face": attacker.face, "kind": attacker.get("boss_variant", "kusarigama")})


func _melee(attacker: Dictionary, reach: float, depth: float, damage: int, heavy: bool, poison: int = 0, launch: bool = false, uppercut: bool = false, behind: float = 18.0, element: String = "", arc_degrees: float = 360.0) -> void:
	_weapon_release(attacker, _melee_weapon(attacker))
	if HERO_PROFILES.has(attacker.kind):
		var profile: Dictionary = HERO_PROFILES[attacker.kind]
		reach *= profile.reach
		depth *= profile.depth
		damage = maxi(1, roundi(damage * profile.damage))
	_effect("slash", attacker.x + attacker.face * reach * 0.5, attacker.y - attacker.z, 10, {"face": attacker.face, "radius": reach * 0.55})
	_melee_props(attacker, reach, depth, damage, behind, arc_degrees)
	for target in state.fighters:
		if target.team == attacker.team or target.hp <= 0:
			continue
		var ahead: float = (target.x - attacker.x) * attacker.face
		if arc_degrees < 360.0 and (Vector2(ahead, (target.y - attacker.y) / 0.4).length() > reach or not _inside_arc(target.x - attacker.x, target.y - attacker.y, attacker.face, arc_degrees)): continue
		if ahead >= -behind and ahead <= reach and absf(target.y - attacker.y) <= depth and absf(target.z - attacker.z) < 80.0:
			if _damage(target, damage, attacker.id, heavy and (attacker.action != "dash_heavy" or target.weight != "heavy"), true, false, attacker.action in ["heavy", "dash_heavy", "charged", "charged_upper", "upper_heavy", "mixed_finisher", "mixed_rising", "air_heavy"]):
				if launch and target.weight != "heavy":
					_launch(target, attacker.face, 16.0 if attacker.action == "charged" else (13.0 if attacker.action in ["heavy", "dash_heavy"] else (12.0 if attacker.kind == "oichi" and attacker.action == "light" else 8.0)))
				elif uppercut and target.weight == "light":
					_launch(target, attacker.face, 12.0 if attacker.action == "charged_upper" else (1.4 if attacker.action == "rising" else 0.8), 9.0 if attacker.action == "charged_upper" else (7.0 if attacker.action == "rising" else 4.6))
				attacker.rage = mini(100, attacker.rage + 14)
				if poison > 0:
					_poison(target, poison, attacker.id)
				_apply_element(target, element, attacker.id)


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


func _try_grab(attacker: Dictionary) -> void:
	var closest: Dictionary = {}
	var closest_distance := INF
	for target in state.fighters:
		if target.team == attacker.team or target.hp <= 0 or target.kind == "boss" or target.weight == "heavy" or target.held_by != 0 or not _standing_grab_target(target):
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
	_begin(attacker, "holding")
	_begin(closest, "grabbed")
	_event("grab", closest.x, closest.y, attacker.id, closest.id)


func _fighter(id: int) -> Dictionary:
	for fighter in state.fighters:
		if fighter.id == id: return fighter
	return {}


func _release_grab(holder: Dictionary, throwing: bool, escaping: bool = false) -> void:
	if holder.grab_target == 0: return
	var target := _fighter(holder.grab_target)
	holder.grab_target = 0
	if not target.is_empty():
		target.held_by = 0
		if throwing and target.hp > 0:
			_damage(target, int(HERO_PROFILES.get(holder.kind, HERO_PROFILES.nobunaga).throw_damage) + holder.weapon * 4, holder.id, true, true, true)
			target.thrown_by = holder.id
			target.throw_ticks = 32
			target.throw_hits = []
			_launch(target, holder.face, 16.0, 6.0)
			if target.hp > 0: _begin(target, "thrown")
			holder.rage = mini(100, holder.rage + 18)
		elif target.hp > 0:
			_begin(target, "idle" if escaping else "down")
	_begin(holder, "defeated" if holder.hp <= 0 else ("throw" if throwing else "idle"))


func _sync_grabs() -> void:
	for holder in state.fighters:
		if holder.grab_target == 0: continue
		var target := _fighter(holder.grab_target)
		if target.is_empty() or target.hp <= 0 or holder.hp <= 0 or holder.action != "holding" or target.held_by != holder.id:
			_release_grab(holder, false)
			continue
		target.x = clampf(holder.x + holder.face * 56.0, 80.0, 2300.0)
		target.y = holder.y + 2.0
		target.z = 0.0
		target.vz = 0.0
		target.face = holder.face


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
			if absf(target.x - body.x) < 44.0 and absf(target.y - body.y) < 40.0 and absf(target.z - body.z) < 80.0:
				body.throw_hits.append(target.id)
				if _damage(target, 22, body.thrown_by, target.weight != "heavy", true, false, false, NAN, NAN, "", 24, "blunt") and target.weight != "heavy":
					_launch(target, 1 if body.knockback >= 0 else -1)


func _damage(target: Dictionary, amount: int, actor: int, heavy: bool, reaction: bool = true, bypass_invuln: bool = false, strong_hit: bool = false, source_x: float = NAN, source_y: float = NAN, source_action: String = "", shatter_damage: int = 24, source_weapon: String = "") -> bool:
	if target.hp <= 0 or target.action == "special" or (reaction and target.invuln > 0 and not bypass_invuln):
		return false
	var attacker := _fighter(actor)
	if not is_finite(source_x) and not attacker.is_empty():
		source_x = attacker.x
		source_y = attacker.y
	var attack_action: String = source_action if source_action != "" else str(attacker.get("action", ""))
	var impact_weapon := source_weapon if source_weapon != "" else _melee_weapon(attacker)
	# A replay-stable 25% parry window; recovery, rear attacks and charged moves cannot trigger it.
	var boss_guard: bool = reaction and target.kind == "boss" and target.action == "idle" and target.counter_ticks == 0 and target.freeze == 0 and target.stun == 0 and not target.airborne_lock and not attacker.is_empty() and attacker.team == 0 and attack_action in ["light", "heavy", "dash_heavy", "rising", "low_sweep", "dash_strike", "air_light"] and (state.tick * 17 + target.id * 13 + actor * 7) % 100 < 25
	if reaction and (boss_guard or target.action in ["guard", "boss_counter"]) and is_finite(source_x) and (source_x - target.x) * target.face > 0.0 and absf(source_y - target.y) <= 100.0 and (boss_guard or target.action == "guard" or target.action_tick < enemy_timing(target)[0] - 8):
		if boss_guard or (not heavy and not (strong_hit and not attacker.is_empty() and (attacker.kind == "boss" or attacker.action in ["heavy", "charged", "charged_upper", "upper_heavy", "air_heavy", "counter_cut"]))):
			if boss_guard:
				_begin(target, "guard")
				target.counter_ticks = 90
			target.rage = mini(100, target.rage + (14 if target.kind == "ieyasu" else 10))
			if target.kind == "mitsuhide": target.counter_ticks = 45
			if target.action == "boss_counter": target.action_tick = maxi(target.action_tick, enemy_timing(target)[0] - 8)
			target.guard_hit_tick = 10
			target.invuln = 8
			_effect("guard", target.x, target.y, 12, {"target": target.id, "face": target.face})
			_event("guard", target.x, target.y, actor, target.id)
			return false
		_effect("guard_break", target.x, target.y, 20, {"target": target.id, "face": target.face})
		_event("guard_break", target.x, target.y, actor, target.id)
		if target.kind == "ieyasu": amount = maxi(1, roundi(amount * 0.6))
	if reaction and target.freeze > 0 and (heavy or strong_hit):
		target.freeze = 0
		target.shattered_tick = state.tick
		amount += shatter_damage
		_effect("shatter", target.x, target.y - target.z, 34, {"target": target.id, "radius": 100.0})
		_event("shatter", target.x, target.y, actor, target.id)
	var final_damage: int = maxi(1, amount - target.armor * 3)
	var previous_hp: int = target.hp
	target.hp = maxi(1 if target.kind == "dummy" or (target.team == 0 and state.has("training")) else 0, target.hp - final_damage)
	var actual_damage: int = previous_hp - target.hp
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
		target.rage = mini(100, target.rage + 6)
		if target.held_by != 0:
			target.shield_hurt_tick = 12
			_event("shield_hit", target.x, target.y, actor, target.id, {"weapon": impact_weapon})
			_effect("shield_hit", target.x, target.y, 12, {"target": target.id})
		else:
			_release_grab(target, false)
			_begin(target, "frozen" if target.freeze > 0 else ("launched" if target.airborne_lock else ("down" if heavy else "hurt")))
			_event("heavy_hit" if heavy or strong_hit else "hit", target.x, target.y - target.z, actor, target.id, {"weapon": impact_weapon})
			_effect("hit", target.x, target.y - target.z, 12, {"heavy": heavy or strong_hit})
	elif target.poison > 0:
		_effect("poison", target.x, target.y - 32.0, 10)
	if target.hp == 0:
		target.stun = 0
		target.shield_hurt_tick = 0
		target.invuln = 0
		target.freeze = 0
		target.burn = 0
		if target.held_by != 0:
			var holder := _fighter(target.held_by)
			if not holder.is_empty(): _release_grab(holder, false)
		_begin(target, "defeated")
		_event("defeat", target.x, target.y, actor, target.id)
		if target.team == 1 and target.id % 2 == 0 and not state.has("training"):
			_add_drop("food", target.x, target.y)
	return true


func _apply_element(target: Dictionary, element: String, owner: int) -> void:
	# Called only after an accepted hit; invulnerable or shielded players never gain a status.
	if element == "" or target.action == "special": return
	_effect(element + "_hit", target.x, target.y - target.z, 24, {"target": target.id})
	if target.hp <= 0: return
	if element == "fire":
		target.burn = 180
		target.burn_tick = 0
		target.burn_owner = owner
		target.freeze = 0
		if target.action == "frozen": _begin(target, "hurt")
	elif element == "ice" and target.shattered_tick != state.tick:
		target.burn = 0
		target.freeze = 90
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
	if HERO_PROFILES.has(fighter.kind):
		radius *= sqrt(HERO_PROFILES[fighter.kind].reach)
		damage = maxi(1, roundi(damage * HERO_PROFILES[fighter.kind].damage))
	_effect("shockwave", fighter.x + (0.0 if centered else fighter.face * 55.0), fighter.y, life, {"radius": radius, "owner": fighter.id, "team": fighter.team, "face": fighter.face, "damage": damage, "hit_ids": [], "element": element, "charged": fighter.action == "charged_slam", "arc_degrees": arc_degrees, "knockdown": knockdown})


func _inside_arc(dx: float, dy: float, face: int, arc_degrees: float) -> bool:
	if arc_degrees >= 360.0: return true
	var offset := Vector2(dx * face, dy / 0.4)
	return offset.is_zero_approx() or offset.normalized().x >= cos(deg_to_rad(arc_degrees * 0.5))


func _poison(target: Dictionary, duration: int, owner: int) -> void:
	target.poison = maxi(target.poison, duration)
	target.poison_owner = owner
	target.poison_tick = 0


func _launch(target: Dictionary, direction: int, horizontal: float = 8.0, vertical: float = 6.0) -> void:
	if target.held_by != 0 or target.freeze > 0: return
	target.knockback = direction * (9.0 if target.team == 0 and horizontal >= 8.0 else horizontal)
	target.z = maxf(target.z, 1.0)
	target.vz = vertical
	target.airborne_lock = true
	target.bounces_left = 2 if target.team == 0 else 1
	target.landing_count = 0
	if target.hp > 0: _begin(target, "launched")


func _melee_weapon(fighter: Dictionary) -> String:
	var kind := str(fighter.get("kind", ""))
	if fighter.get("action", "") in ["holding", "throw"]: return "blunt"
	if kind == "oichi":
		if fighter.get("action", "") == "dash_heavy": return "needle"
		return "kick" if fighter.get("action", "") == "light" else "blunt"
	if kind in ["soldier", "hideyoshi", "tadakatsu"]: return "spear"
	if kind == "flag": return "blunt"
	if kind == "boss" and fighter.get("boss_variant", "") in ["kusarigama", "weighted_chain"]: return "chain"
	return "sword"


func _weapon_release(fighter: Dictionary, weapon: String) -> void:
	var type := "bow_release" if weapon in ["arrow", "special_arrow"] else ("gunshot" if weapon == "bullet" else "weapon_swing")
	# A volley is one string release, even when it creates three/five projectiles.
	for event in state.events:
		if event.type == type and event.actor == fighter.id and event.get("weapon", "") == weapon: return
	_event(type, fighter.x, fighter.y, fighter.id, 0, {"weapon": weapon, "action": fighter.action, "action_tick": fighter.action_tick})


func _projectile(attacker: Dictionary, damage: int, poison: int, finisher: bool = false, weapon: String = "needle", reach: float = 260.0, lane: float = 0.0, element: String = "", shatter_hit: bool = true, options: Dictionary = {}) -> void:
	if attacker.team == 1 and weapon == "arrow":
		_arc_arrow(attacker, damage)
		return
	var speed := 34.0 if weapon in ["bullet", "blade"] else (11.0 if weapon == "needle" else (9.0 if attacker.team == 1 else 22.0))
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
		"height_tolerance": 100.0 if attacker.action in ["air_light", "air_heavy"] else 70.0, "piercing": weapon in ["special_arrow", "blade"] or element == "ice", "hit_ids": [], "stun": 0,
	}
	for field in ["piercing", "burst_radius", "burst_damage", "shatter_damage", "follow_freeze"]:
		if options.has(field): extra[field] = options[field]
	_effect("projectile", attacker.x + attacker.face * origin, attacker.y + lane, lifetime, extra)
	_weapon_release(attacker, weapon)


func _arc_arrow(attacker: Dictionary, damage: int) -> void:
	var closest: Dictionary = {}
	var distance := INF
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
		"weapon": "arrow", "element": "", "arcing": true, "flight_tick": 0, "flight_ticks": flight,
		"origin_x": origin_x, "origin_y": attacker.y, "target_x": closest.x, "target_y": closest.y,
		"start_z": 40.0, "arc_height": 140.0 + distance * 0.08, "hit_ids": [], "finisher": false})
	_effect("arrow_target", closest.x, closest.y, flight, {"owner": attacker.id, "radius": 32.0})
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
		_damage(target, effect.damage, effect.owner, false, true, target.held_by != 0, false, effect.origin_x, effect.origin_y, effect.get("action", ""), 24, "arrow")
		break
	for prop in state.props:
		if not prop.broken and absf(prop.x - effect.x) < prop.width * 0.5 and absf(prop.y - effect.y) < prop.depth * 0.5:
			_damage_prop(prop, effect.damage, effect.owner)
			break
	_effect("arrow_impact", effect.x, effect.y, 24, {"wet": _wet(effect.x, effect.y)})
	effect.life = 0


func _tick_effects() -> void:
	# Damage can append effects; iterate a snapshot so new effects begin next tick.
	for effect in state.effects.duplicate():
		effect.life -= 1
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
		if effect.type != "projectile" or effect.life <= 0:
			continue
		if effect.get("arcing", false):
			_tick_arc_arrow(effect)
			continue
		# The first swept segment includes the extended arm so close targets cannot be skipped.
		var previous_x: float = effect.get("previous_x", effect.x) if effect.life == effect.max_life - 1 else effect.x
		var previous_y: float = effect.get("previous_y", effect.y) if effect.life == effect.max_life - 1 else effect.y
		var distance := minf(absf(effect.vx), float(effect.get("range_left", absf(effect.vx))))
		effect.x += signf(effect.vx) * distance
		effect.y += float(effect.get("vy", 0.0)) * distance / maxf(absf(effect.vx), 0.001)
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
					_damage_prop(target, effect.damage, effect.owner)
					if effect.has("hit_ids"): effect.hit_ids.append(target.id)
					if effect.get("burst_radius", 0.0) > 0.0: _ice_burst(effect, target.x, target.y, target.id)
					if effect.life <= 0 or not effect.get("piercing", false):
						effect.life = 0
						break
				continue
			var hostile_shield: bool = target.held_by != 0 and not _fighter(target.held_by).is_empty() and _fighter(target.held_by).team != effect.team
			if (target.team == effect.team and not hostile_shield) or target.hp <= 0 or target.id in effect.get("hit_ids", []):
				continue
			if target.x > minf(previous_x, effect.x) - 27.0 and target.x < maxf(previous_x, effect.x) + 27.0 and absf(target.y - crossing_y) < effect.get("hit_depth", 30.0) and absf(target.z + 28.0 - effect.z) < effect.get("height_tolerance", 70.0):
				if target.team == 0:
					var shield := _front_shield(target, previous_x, effect.y)
					if not shield.is_empty(): target = shield
				if target.id in effect.get("hit_ids", []): continue
				var frozen_followup: bool = effect.get("follow_freeze", false) and effect.get("action", "") == "charged_slam" and effect.get("weapon", "") == "arrow" and target.freeze > 0 and target.freeze_owner == effect.owner
				if _damage(target, effect.damage, effect.owner, effect.get("finisher", false), true, target.held_by != 0 or frozen_followup, effect.get("weapon", "needle") != "needle" and effect.get("shatter_hit", true), previous_x, crossing_y, effect.get("action", ""), effect.get("shatter_damage", 24), effect.get("weapon", "needle")):
					if effect.get("finisher", false) and target.weight != "heavy": _launch(target, effect.face, 16.0 if effect.get("charged", false) else (13.0 if effect.get("weapon", "needle") == "arrow" else 8.0))
					elif effect.get("rising", false) and target.weight == "light":
						_launch(target, effect.face, 1.4, 7.0)
					if effect.get("stun", 0) > 0 and target.hp > 0 and target.held_by == 0:
						target.stun = effect.stun
						_begin(target, "stunned")
					if effect.poison > 0:
						_poison(target, effect.poison, effect.owner)
					_apply_element(target, effect.get("element", ""), effect.owner)
					for owner in state.fighters:
						if owner.id == effect.owner:
							owner.rage = mini(100, owner.rage + 12)
				if effect.has("hit_ids"): effect.hit_ids.append(target.id)
				if effect.get("burst_radius", 0.0) > 0.0: _ice_burst(effect, target.x, target.y, target.id)
				if effect.life <= 0 or not effect.get("piercing", false):
					effect.life = 0
					break
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
		if _damage(target, int(projectile.get("burst_damage", 6)), projectile.owner, false, true, target.held_by != 0, false, x, y, "charged"):
			_apply_element(target, "ice", projectile.owner)
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
		var distance := Vector2(target.x - effect.x, (target.y - effect.y) / 0.4).length()
		if distance <= radius and _inside_arc(target.x - effect.x, target.y - effect.y, effect.face, effect.get("arc_degrees", 360.0)):
			effect.hit_ids.append(target.id)
			var knockdown: bool = effect.get("knockdown", true)
			if _damage(target, effect.damage, effect.owner, knockdown and target.weight != "heavy", true, false, knockdown):
				if knockdown and target.weight == "light": _launch(target, 1 if target.x >= effect.x else -1, 14.0 if effect.get("charged", false) else 3.0, 6.0 if effect.get("charged", false) else 4.0)
				_apply_element(target, effect.get("element", ""), effect.owner)
				for owner in state.fighters:
					if owner.id == effect.owner: owner.rage = mini(100, owner.rage + 14)


func _pickup(fighter: Dictionary) -> void:
	for drop in state.drops:
		if absf(drop.x - fighter.x) > 55.0 or absf(drop.y - fighter.y) > 40.0:
			continue
		match drop.kind:
			"food":
				if fighter.hp == fighter.max_hp:
					continue
				fighter.hp = mini(fighter.max_hp, fighter.hp + 40)
			"weapon":
				if fighter.weapon > 0:
					continue
				fighter.weapon = 1
			"armor":
				if fighter.armor > 0:
					continue
				fighter.armor = 1
		_event("pickup", drop.x, drop.y, fighter.id, drop.id)
		state.drops.erase(drop)
		return


func _add_drop(kind: String, x: float, y: float) -> void:
	state.drops.append({"id": _next_id, "kind": kind, "x": x, "y": y})
	_next_id += 1


func _begin(fighter: Dictionary, action: String) -> void:
	if action != "idle": fighter.sprinting = false
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
	if fighter.team == 0 and action not in ["idle", "light"]:
		_queued_light[fighter.player_index] = ""
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
	if not source.is_empty():
		event.actor_kind = source.kind
		event.actor_faction = source.faction
	if not victim.is_empty():
		event.target_kind = victim.kind
		event.target_faction = victim.faction
	event.merge(extra)
	state.events.append(event)
