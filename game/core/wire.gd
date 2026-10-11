extends RefCounted

const Battle = preload("res://core/battle.gd")

const ACTIONS := ["victory", "idle", "light", "charge", "heavy", "charged", "throw", "special", "windup", "hurt", "down", "defeated", "holding", "grabbed", "thrown", "stunned", "rising", "ground_slam", "low_sweep", "dash_strike", "dash_heavy", "air_light", "air_heavy", "upper_heavy", "charged_upper", "charged_slam", "mixed_finisher", "mixed_rising", "retreat", "pulled", "frozen", "spear_thrust", "spear_sweep", "spear_butt", "flag_poke", "flag_sweep", "flag_slam", "commander_cut", "commander_rise", "commander_dash", "boss_sweep", "boss_smash", "boss_chain", "bow_shot", "gun_shot", "guard", "recovering", "launched"]
const KINDS := ["nobunaga", "oichi", "hideyoshi", "ieyasu", "mitsuhide", "tadakatsu", "soldier", "flag", "commander", "archer", "gunner", "boss", "dummy"]
const EFFECTS := ["projectile", "slash", "warning", "slam", "hit", "poison", "shield_hit", "shockwave", "chain", "fire_hit", "ice_hit", "shatter", "fire_wave", "ice_wave", "guard", "guard_break", "damage", "landing", "debris", "arrow_target", "arrow_impact", "wind_hit", "earth_hit", "blade_hit", "wind_wave", "earth_wave", "blade_wave"]
const EVENTS := ["hit", "heavy_hit", "special", "pickup", "defeat", "grab", "shield_hit", "bow_release", "gunshot", "shatter", "guard", "guard_break", "damage", "landing", "run_bump", "prop_break", "swing", "weapon_swing", "boss_intro"]
const ARRAY_LIMITS := {"fighters": 64, "drops": 64, "effects": 256, "events": 128, "props": 32, "wet_zones": 16}
const FIGHTER_RANGES := {
	"id": [1, 1000000000], "team": [0, 1], "player_index": [-1, 1],
	"hp": [-1000000, 1000000], "max_hp": [1, 1000000], "rage": [0, 100],
	"armor": [0, 1], "weapon": [0, 1], "face": [-1, 1], "action_tick": [0, 1000000000],
}


static func valid_input(frame: Dictionary) -> bool:
	return frame.size() == 3 and _integer(frame.get("dx"), -1, 1) and _integer(frame.get("dy"), -1, 1) and _integer(frame.get("buttons"), 0, 255)


static func valid_snapshot(world: Dictionary) -> bool:
	if not _choice(world.get("phase"), ["playing", "won", "lost"]) or not _choice(world.get("difficulty"), ["easy", "normal", "hard"]):
		return false
	if not _integer(world.get("tick"), 0) or not _integer(world.get("wave"), 1, 3) or not _integer(world.get("event_seq"), 0):
		return false
	if not world.get("civilian_spawn_enabled") is bool or not _integer(world.get("civilian_flee_tick"), -1) or not _number(world.get("civilian_flee_x")): return false
	if not _choice(world.get("faction"), Battle.FACTIONS.keys()) or not world.get("intro") is Dictionary: return false
	for field in ARRAY_LIMITS:
		if not world.get(field) is Array or world[field].size() > ARRAY_LIMITS[field]:
			return false
		for item in world[field]:
			if not item is Dictionary:
				return false
	var by_id := {}
	for fighter in world.fighters:
		if not _valid_fighter(fighter):
			return false
		if by_id.has(fighter.id): return false
		by_id[fighter.id] = fighter
	for fighter in world.fighters:
		var held_by: int = fighter.get("held_by", 0)
		var grabbed: int = fighter.get("grab_target", 0)
		if held_by > 0 and (not by_id.has(held_by) or held_by == fighter.id or by_id[held_by].get("grab_target", 0) != fighter.id): return false
		if grabbed > 0 and (not by_id.has(grabbed) or grabbed == fighter.id or by_id[grabbed].get("held_by", 0) != fighter.id): return false
	if not world.intro.is_empty():
		var intro: Dictionary = world.intro
		if not _integer(intro.get("actor"), 1) or not by_id.has(intro.actor) or by_id[intro.actor].kind != "boss": return false
		if not _integer(intro.get("duration"), 1, 1800) or not _integer(intro.get("remaining_ticks"), 0, intro.duration) or not intro.get("announced") is bool: return false
		for field in ["name", "line_key"]:
			if not intro.get(field) is String or intro[field].length() > 200: return false
	for drop in world.drops:
		if not _integer(drop.get("id"), 1) or not _choice(drop.get("kind"), ["food", "weapon", "armor"]) or not _position(drop):
			return false
		if drop.has("type") and not drop.type is String:
			return false
	for prop in world.props:
		if not _position(prop) or not _integer(prop.get("id"), 1) or not _choice(prop.get("kind"), ["stall", "cart", "jar", "basket", "crate"]): return false
		if by_id.has(prop.id): return false
		by_id[prop.id] = prop
		if not _integer(prop.get("hp"), 0) or not _integer(prop.get("max_hp"), 1) or prop.hp > prop.max_hp: return false
		if not prop.get("broken") is bool or prop.broken != (prop.hp == 0): return false
		if not _number(prop.get("width"), 1.0, 1000.0) or not _number(prop.get("depth"), 1.0, 1000.0) or not _choice(prop.get("drop"), ["food", "weapon", "armor"]): return false
	for zone in world.wet_zones:
		if not _position(zone) or not _number(zone.get("width"), 1.0, 10000.0) or not _number(zone.get("depth"), 1.0, 10000.0): return false
	for effect in world.effects:
		if not _valid_effect(effect):
			return false
	for event in world.events:
		if not _choice(event.get("type"), EVENTS) or not _position(event):
			return false
		for field in ["id", "actor", "target"]:
			if not _integer(event.get(field), 0):
				return false
		if event.has("kind") and not event.kind is String:
			return false
		for field in ["actor_kind", "target_kind"]:
			if event.has(field) and not _choice(event[field], KINDS): return false
		for field in ["actor_faction", "target_faction"]:
			if event.has(field) and not _choice(event[field], ["heroes"] + Battle.FACTIONS.keys()): return false
		if event.has("amount") and not _integer(event.amount, 0, 1000000): return false
		if event.type == "damage" and not event.has("amount"): return false
		if event.has("wet") and not event.wet is bool: return false
		if event.has("action") and not _action(event.action): return false
		if event.has("combo") and not _integer(event.combo, 0, 3): return false
		if event.has("heavy_combo") and not _integer(event.heavy_combo, 0, 2): return false
		if event.has("finisher") and not event.finisher is bool: return false
		for field in ["name", "line_key"]:
			if event.has(field) and (not event[field] is String or event[field].length() > 200): return false
	return true


static func _valid_fighter(fighter: Dictionary) -> bool:
	if not _position(fighter) or not _number(fighter.get("z"), 0.0, 10000.0):
		return false
	if not _choice(fighter.get("kind"), KINDS) or not _action(fighter.get("action")):
		return false
	for field in FIGHTER_RANGES:
		if not _integer(fighter.get(field), FIGHTER_RANGES[field][0], FIGHTER_RANGES[field][1]):
			return false
	if fighter.face == 0 or fighter.hp > fighter.max_hp:
		return false
	if fighter.team == 0 and (fighter.player_index < 0 or fighter.kind not in Battle.HEROES):
		return false
	if fighter.team == 1 and fighter.player_index != -1:
		return false
	if fighter.has("combo") and not _integer(fighter.combo, 0, 3):
		return false
	if fighter.has("heavy_combo") and not _integer(fighter.heavy_combo, 0, 2):
		return false
	if fighter.has("weight") and not _choice(fighter.weight, ["light", "medium", "heavy"]): return false
	if fighter.has("throw_hits") and not _id_list(fighter.throw_hits): return false
	if fighter.has("charge_direction") and not _integer(fighter.charge_direction, -1, 1): return false
	if fighter.has("shattered_tick") and not _integer(fighter.shattered_tick, -1): return false
	if fighter.has("attack_variant") and not _integer(fighter.attack_variant, 0, 3): return false
	if fighter.has("mixed_ready") and not fighter.mixed_ready is bool: return false
	for field in ["sprinting", "airborne_lock", "down_from_air"]:
		if fighter.has(field) and not fighter[field] is bool: return false
	for field in ["move_dx", "move_dy", "tap_dx", "tap_dy", "sprint_dx", "sprint_dy"]:
		if fighter.has(field) and not _integer(fighter[field], -1, 1): return false
	if fighter.has("tap_tick") and not _integer(fighter.tap_tick, -1000): return false
	if fighter.has("bounces_left") and not _integer(fighter.bounces_left, 0, 2): return false
	if fighter.has("landing_count") and not _integer(fighter.landing_count, 0, 3): return false
	for field in ["down_ticks", "bump_cooldown", "guard_hit_tick", "counter_ticks"]:
		if fighter.has(field) and not _integer(fighter[field], 0, 1000): return false
	if fighter.has("faction") and not _choice(fighter.faction, ["heroes"] + Battle.FACTIONS.keys()): return false
	if fighter.has("boss_variant") and not _choice(fighter.boss_variant, [""] + Battle.BOSS_PROFILES.keys()): return false
	if fighter.has("last_attack") and not _choice(fighter.last_attack, ["", "light", "heavy"]): return false
	for field in ["charge", "invuln", "poison", "poison_tick", "poison_owner", "combo", "combo_tick", "heavy_combo_tick", "cooldown", "grab_target", "held_by", "thrown_by", "throw_ticks", "stun", "shield_hurt_tick", "damage_tick", "burn", "burn_tick", "burn_owner", "freeze", "freeze_owner", "mixed_tick", "ai_cycle", "chain_target", "pull_owner"]:
		if fighter.has(field) and not _integer(fighter[field], 0):
			return false
	for field in ["vz", "target_x", "target_y", "knockback", "home_x", "home_y"]:
		if fighter.has(field) and not _number(fighter[field]):
			return false
	if fighter.action == "holding" and fighter.get("grab_target", 0) == 0: return false
	if fighter.action == "grabbed" and fighter.get("held_by", 0) == 0: return false
	if fighter.get("throw_ticks", 0) > 0 and fighter.get("thrown_by", 0) == 0: return false
	return true


static func _valid_effect(effect: Dictionary) -> bool:
	if not _choice(effect.get("type"), EFFECTS) or not _position(effect):
		return false
	if not _integer(effect.get("life"), 0, 1000000) or not _integer(effect.get("max_life"), 1, 1000000):
		return false
	if effect.life > effect.max_life:
		return false
	for field in ["z", "vx", "vy", "vz", "previous_x", "previous_y", "target_x", "target_y", "origin_x", "origin_y"]:
		if effect.has(field) and not _number(effect[field]):
			return false
	if effect.has("radius") and not _number(effect.radius, 0.0):
		return false
	for field in ["range_left", "hit_depth", "height_tolerance", "burst_radius"]:
		if effect.has(field) and not _number(effect[field], 0.0): return false
	for field in ["owner", "damage", "poison", "ttl", "stun", "target", "burst_damage"]:
		if effect.has(field) and not _integer(effect[field], 0):
			return false
	if effect.has("team") and not _integer(effect.team, 0, 1):
		return false
	if effect.has("face") and (not _integer(effect.face, -1, 1) or effect.face == 0):
		return false
	if effect.has("heavy") and not effect.heavy is bool:
		return false
	if effect.has("finisher") and not effect.finisher is bool:
		return false
	if effect.has("piercing") and not effect.piercing is bool: return false
	if effect.has("charged") and not effect.charged is bool: return false
	if effect.has("rising") and not effect.rising is bool: return false
	if effect.has("shatter_hit") and not effect.shatter_hit is bool: return false
	if effect.has("shatter_damage") and not _integer(effect.shatter_damage, 0, 24): return false
	if effect.has("arc_degrees") and not _number(effect.arc_degrees, 0.0, 360.0): return false
	for field in ["burst", "knockdown", "follow_freeze"]:
		if effect.has(field) and not effect[field] is bool: return false
	for field in ["arcing", "wet"]:
		if effect.has(field) and not effect[field] is bool: return false
	for field in ["flight_tick", "flight_ticks", "bounce", "amount"]:
		if effect.has(field) and not _integer(effect[field], 0, 1000000): return false
	for field in ["start_z", "arc_height"]:
		if effect.has(field) and not _number(effect[field], 0.0, 10000.0): return false
	if effect.has("element") and not _choice(effect.element, ["", "fire", "ice", "wind", "earth", "blade"]): return false
	if effect.has("hit_ids") and not _id_list(effect.hit_ids): return false
	if effect.has("weapon") and not _choice(effect.weapon, ["needle", "arrow", "special_arrow", "bullet", "blade"]): return false
	if effect.has("kind") and not effect.kind is String:
		return false
	if effect.has("action") and not _action(effect.action): return false
	if effect.has("action_tick") and not _integer(effect.action_tick, 0): return false
	if effect.has("combo") and not _integer(effect.combo, 0, 3): return false
	if effect.has("heavy_combo") and not _integer(effect.heavy_combo, 0, 2): return false
	if effect.type == "projectile":
		for field in ["z", "vx", "owner", "team", "damage", "poison", "face"]:
			if not effect.has(field):
				return false
		if effect.get("arcing", false):
			for field in ["flight_tick", "flight_ticks", "origin_x", "origin_y", "target_x", "target_y", "start_z", "arc_height", "vy", "vz"]:
				if not effect.has(field): return false
			if effect.flight_ticks < 1 or effect.flight_tick > effect.flight_ticks: return false
	if effect.type == "shockwave":
		for field in ["radius", "owner", "team", "damage", "face", "hit_ids"]:
			if not effect.has(field): return false
	if effect.type == "chain":
		for field in ["owner", "target", "target_x", "target_y", "face"]:
			if not effect.has(field): return false
	if effect.type == "damage" and (not effect.has("amount") or not effect.has("target")): return false
	if effect.type == "landing" and (not effect.has("wet") or not effect.has("bounce") or not effect.has("target")): return false
	if effect.type == "debris" and not _choice(effect.get("kind"), ["stall", "cart", "jar", "basket", "crate"]): return false
	return true


static func _position(item: Dictionary) -> bool:
	return _number(item.get("x")) and _number(item.get("y"))


static func _id_list(value: Variant) -> bool:
	if not value is Array or value.size() > 64: return false
	for id in value:
		if not _integer(id, 1): return false
	return true


static func _number(value: Variant, minimum: float = -1000000.0, maximum: float = 1000000.0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum


static func _integer(value: Variant, minimum: int, maximum: int = 1000000000) -> bool:
	return value is int and value >= minimum and value <= maximum


static func _choice(value: Variant, choices: Array) -> bool:
	return value is String and value in choices


static func _action(value: Variant) -> bool:
	return value is String and (value in ACTIONS or value == "counter_cut" or Battle.ENEMY_TIMING.has(value))
