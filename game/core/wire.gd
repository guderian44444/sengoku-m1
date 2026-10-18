extends RefCounted

const CampaignMusic = preload("res://core/campaign_music.gd")
const Mikawa = preload("res://core/stage04_data.gd")
const Ikki = preload("res://core/stage05_data.gd")

const Stage03 = preload("res://core/stage03_encounter.gd")
const Battle = preload("res://core/battle.gd")
const Weapons = preload("res://core/weapon_catalog.gd")
const Equipment = preload("res://core/equipment.gd")
const Achievements = preload("res://core/achievements.gd")

const ACTIONS := ["victory", "idle", "light", "charge", "heavy", "charged", "throw", "special", "windup", "hurt", "down", "defeated", "holding", "grabbed", "thrown", "stunned", "rising", "ground_slam", "low_sweep", "dash_strike", "dash_heavy", "air_light", "air_heavy", "upper_heavy", "charged_upper", "charged_slam", "mixed_finisher", "mixed_rising", "retreat", "pulled", "frozen", "spear_thrust", "spear_sweep", "spear_butt", "flag_poke", "flag_sweep", "flag_slam", "commander_cut", "commander_rise", "commander_dash", "boss_sweep", "boss_smash", "boss_chain", "bow_shot", "gun_shot", "guard", "recovering", "launched"]
const KINDS := ["nobunaga", "oichi", "hideyoshi", "ieyasu", "mitsuhide", "tadakatsu", "soldier", "flag", "commander", "archer", "gunner", "boss", "dummy"]
const EFFECTS := ["projectile", "slash", "warning", "slam", "hit", "poison", "shield_hit", "shockwave", "chain", "fire_hit", "ice_hit", "shatter", "fire_wave", "ice_wave", "guard", "guard_break", "damage", "landing", "debris", "arrow_target", "arrow_impact", "wind_hit", "earth_hit", "blade_hit", "wind_wave", "earth_wave", "blade_wave","fire_patch"]
const EVENTS := ["hit", "heavy_hit", "special", "pickup", "food_pickup", "food_stored", "armor_pickup", "armor_break", "extra_life", "revive", "defeat", "grab", "shield_hit", "bow_release", "gunshot", "shatter", "guard", "guard_break", "damage", "landing", "run_bump", "prop_hit", "prop_break", "swing", "weapon_swing", "boss_intro","achievement","weapon_break","inventory_full","challenge_complete","challenge_failed","encounter_phase","bell_fall"]
const ARRAY_LIMITS := {"fighters": 64, "drops": 64, "effects": 256, "events": 128, "props": 32, "wet_zones": 16}
const PROP_KINDS := ["bell_pillar","stall","cart","jar","basket","crate","large_crate","barricade","fence","planter","stone_lantern","lantern","rice_bales","screen","cabinet"]
const FOODS := ["","rice","fish","dango","peach"]
const FIGHTER_RANGES := {
	"id": [1, 1000000000], "team": [0, 1], "player_index": [-1, 1],
	"hp": [-1000000, 1000000], "max_hp": [1, 1000000], "rage": [0, 100],
	"armor": [0, 1], "weapon": [0, 1], "face": [-1, 1], "action_tick": [0, 1000000000],
	"lives": [0, 1000000], "score": [0, 1000000000], "next_life_score": [10000, 1000010000],
	"respawn_ticks": [0, 120], "shield_points": [0, 320],
	"max_hp_bonus": [0,10000],
}


static func valid_input(frame: Dictionary) -> bool:
	if frame.has("stick_full") and not frame.stick_full is bool: return false
	return frame.size() == (4 if frame.has("stick_full") else 3) and _integer(frame.get("dx"), -1, 1) and _integer(frame.get("dy"), -1, 1) and _integer(frame.get("buttons"), 0, 255)


static func valid_snapshot(world: Dictionary) -> bool:
	if world.get("stage",{}).get("id",0) == 5 and not _valid_ikki(world.get("ikki")): return false
	if world.has("ikki") and world.get("stage",{}).get("id",0) != 5: return false
	if world.get("stage",{}).get("id",0) == 4 and not _valid_mikawa(world.get("mikawa")): return false
	if not _integer(world.get("loot_rng"),0,2147483647): return false
	if world.has("victory_looting") and not world.victory_looting is bool: return false
	if not _choice(world.get("phase"), ["playing", "won", "lost"]) or not _choice(world.get("difficulty"), ["easy", "normal", "hard"]):
		return false
	if not _integer(world.get("tick"), 0) or not _integer(world.get("wave"), 1, 3) or not _integer(world.get("event_seq"), 0):
		return false
	if not world.get("civilian_spawn_enabled") is bool or not _integer(world.get("civilian_flee_tick"), -1) or not _number(world.get("civilian_flee_x")): return false
	if not _choice(world.get("faction"), Battle.FACTIONS.keys()) or not world.get("intro") is Dictionary: return false
	if world.has("stage") and not _valid_stage(world.stage): return false
	if world.has("challenge") and (not world.has("stage") or not _valid_challenge(world.challenge,world.stage)): return false
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
		if intro.has("line") and (not intro.line is String or intro.line.length() > 200): return false
		if intro.has("blocking") and not intro.blocking is bool: return false
	for drop in world.drops:
		if not _integer(drop.get("id"), 1) or not _choice(drop.get("kind"), ["food", "weapon", "armor", "talisman"]) or not _position(drop):
			return false
		if drop.has("type") and not drop.type is String:
			return false
		if drop.has("food_id") and not _choice(drop.food_id,FOODS): return false
		if drop.has("heal") and not _integer(drop.heal,1,120): return false
		if drop.kind == "talisman" and not _choice(drop.get("talisman_id"),Battle.TALISMANS.keys()): return false
		if drop.kind == "weapon" and not _choice(drop.get("weapon_id"),Weapons.ITEMS.keys()): return false
	for prop in world.props:
		if prop.has("s05_banner") and (not prop.s05_banner is bool or not prop.has("s05_asset") or prop.s05_banner!=str(prop.s05_asset).contains("_")): return false
		if prop.has("s05_asset") and (not _choice(prop.s05_asset,["militia_ragged","militia_patched","militia_wicker","temple_brown","temple_ochre","rice","wood","jar"]) or not _integer(prop.get("broken_tick"),-1)): return false
		if prop.has("mikawa_asset") and (not _choice(prop.mikawa_asset,["kflag","uflag","fence","cheval"]) or not _integer(prop.get("broken_tick"),-1)): return false
		if not _position(prop) or not _integer(prop.get("id"), 1) or not _choice(prop.get("kind"), PROP_KINDS): return false
		if by_id.has(prop.id): return false
		by_id[prop.id] = prop
		if not _integer(prop.get("hp"), 0) or not _integer(prop.get("max_hp"), 1) or prop.hp > prop.max_hp: return false
		if not prop.get("broken") is bool or prop.broken != (prop.hp == 0): return false
		if not _number(prop.get("width"), 1.0, 1000.0) or not _number(prop.get("depth"), 1.0, 1000.0) or not _choice(prop.get("drop"), ["", "food", "weapon", "armor", "talisman"]): return false
		if prop.drop == "talisman" and not _choice(prop.get("talisman_id"),Battle.TALISMANS.keys()): return false
		if prop.has("food_id") and not _choice(prop.food_id,FOODS): return false
		if prop.has("mandatory") and not prop.mandatory is bool: return false
		if prop.has("stage03_barrier") and not prop.stage03_barrier is bool: return false
		if prop.has("encounter_epoch") and not _integer(prop.encounter_epoch,1): return false
		if prop.has("hit_tick") and not _integer(prop.hit_tick,0): return false
	if world.props.any(func(p): return p.kind == "bell_pillar") and (not world.get("encounter") is Dictionary or world.encounter.get("kind", "") != "alarm"): return false
	if world.has("encounter") and not Stage03.valid_state(world): return false
	if world.fighters.any(func(f):return f.get("is_yoshimoto",false)) and world.get("encounter",{}).get("kind", "") != "lieutenants": return false
	if world.props.any(func(p):return p.get("stage03_barrier",false)) and world.get("encounter",{}).get("kind", "") != "barriers": return false
	if world.get("stage",{}).get("id",0) == 3 and not world.has("encounter"): return false
	for zone in world.wet_zones:
		if not _position(zone) or not _number(zone.get("width"), 1.0, 10000.0) or not _number(zone.get("depth"), 1.0, 10000.0): return false
	for effect in world.effects:
		if not _valid_effect(effect):
			return false
	for event in world.events:
		if event.get("type") == "stage05_audio" and not _choice(event.get("cue"),Ikki.audio_cues()): return false
		if event.get("type","") == "achievement":
			if not Achievements.valid([event.get("achievement_id")]) or not event.get("loot") is bool or not event.get("description") is String or event.description.length() > 120: return false
		if event.get("type") == "mikawa_audio" and (not _choice(event.get("cue"),Mikawa.audio_cues()) or not event.get("voice") is bool): return false
		for field in ["actor_mikawa","target_mikawa"]:
			if event.has(field) and not event[field] is bool: return false
		if not _choice(event.get("type"), EVENTS + ["throw_swing","element_hit","mikawa_audio","stage05_audio"]) or not _position(event):
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
		if event.type == "encounter_phase" and (not _choice(event.get("phase"),Stage03.PHASES) or not _integer(event.get("encounter_epoch"),1)): return false
		if event.type == "damage" and not event.has("amount"): return false
		if event.type == "challenge_complete" and not _integer(event.get("amount"),1,10000): return false
		if event.type == "food_stored" and not _choice(event.get("food_id"),FOODS): return false
		if event.type == "food_pickup" and (not _choice(event.get("food_id"),FOODS) or not _integer(event.get("heal"),1,120)): return false
		if event.has("wet") and not event.wet is bool: return false
		if event.has("target_stage_boss") and not event.target_stage_boss is bool: return false
		if event.has("material") and not _choice(event.material,["ceramic","stone","box","wood","wicker","body","armor"]): return false
		if event.has("action") and event.action != "body_collision" and not _action(event.action): return false
		if event.has("actor_team") and not _integer(event.actor_team,0,1): return false
		if event.has("weapon_id") and event.weapon_id != "" and not _choice(event.weapon_id,Weapons.ITEMS.keys()): return false
		for field in ["attack_id","action_tick"]:
			if event.has(field) and not _integer(event[field],-1): return false
		for field in ["body","spin_finish","sound_suppressed"]:
			if event.has(field) and not event[field] is bool: return false
		if event.has("contact") and not _choice(event.contact,["armor_absorb","held_body"]): return false
		if event.type == "element_hit" and not _choice(event.get("element"),["fire","ice","wind","lightning"]): return false
		if event.has("combo") and not _integer(event.combo, 0, 3): return false
		if event.has("heavy_combo") and not _integer(event.heavy_combo, 0, 2): return false
		if event.has("finisher") and not event.finisher is bool: return false
		for field in ["name", "line_key"]:
			if event.has(field) and (not event[field] is String or event[field].length() > 200): return false
	return true


static func _valid_challenge(cart: Variant, stage: Dictionary) -> bool:
	if not cart is Dictionary or cart.size() != 8: return false
	if cart.get("kind") != "reclaim" or not _choice(cart.get("status"),["active","complete","failed"]): return false
	if not _number(cart.get("x"),80,stage.width-160) or not _number(cart.get("y"),360,600): return false
	if not _integer(cart.get("max_hp"),1,10000) or not _integer(cart.get("hp"),0,cart.max_hp): return false
	if (cart.status == "failed") != (cart.hp == 0): return false
	if cart.status == "complete" and stage.checkpoint == 0 and stage.phase != "exit": return false
	return _integer(cart.get("reward"),1,10000) and _integer(cart.get("next_hit_tick"),0)


static func _valid_stage(stage: Variant) -> bool:
	if not stage is Dictionary: return false
	if stage.has("prototype") and (not stage.prototype is bool or stage.get("id") != 3): return false
	var camp: bool = stage.get("id",0) == 3
	var mikawa: bool = stage.get("id",0) == 4
	var ikki: bool = stage.get("id",0) == 5
	if not _integer(stage.get("id"),1,24) or not _integer(stage.get("total"),5 if mikawa or ikki else (4 if camp else 6),5 if mikawa or ikki else (4 if camp else 8)) or not _integer(stage.get("index"),0,stage.total - 1): return false
	if not _choice(stage.get("theme"),["bamboo","ridge","village","road","outpost","gate","camp","courtyard","command","chamber","supply_road","riverbank","granary","switchback","marune_gate","supply_court"]): return false
	if not _choice(stage.get("weather"),["clear","rain","storm","mist","indoor"]) or not _choice(stage.get("music"),["bamboo","siege","town","castle","boss"] + CampaignMusic.KEYS + Mikawa.MUSIC + Ikki.MUSIC): return false
	if not _choice(stage.get("civilians"),["none","villagers","vendors","porters"]): return false
	if not _number(stage.get("width"),2000,6516 if mikawa else 4800) or not _integer(stage.get("wave_total"),1 if camp or mikawa or ikki else 2,1 if camp or mikawa or ikki else 3): return false
	if not _integer(stage.get("checkpoint_total"),1 if camp else 2,1 if camp else 4) or not _integer(stage.get("checkpoint"),0,stage.checkpoint_total-1): return false
	if not _number(stage.get("encounter_start"),0,stage.width) or not _number(stage.get("encounter_end"),stage.encounter_start+1000,stage.width): return false
	if not _choice(stage.get("phase"),["combat","exit"]) or not stage.get("go") is bool or stage.go != (stage.phase == "exit"): return false
	for field in ["next_wave_tick","entered_tick","clear_tick","next_reinforce_tick"]:
		if not _integer(stage.get(field),-1): return false
	for field in ["reinforcement_queue","reinforcement_calls"]:
		if not _integer(stage.get(field),0): return false
	for field in ["title","name"]:
		if not stage.get(field) is String or stage[field].length() > 100: return false
	return true


static func _valid_fighter(fighter: Dictionary) -> bool:
	if fighter.has("s05_role"):
		if fighter.get("team") != 1 or not _choice(fighter.s05_role,Ikki.ROLES): return false
		if not fighter.get("s05_elite") is bool or not fighter.get("s05_weak") is bool: return false
		if fighter.s05_elite and fighter.s05_role != "monk": return false
		if fighter.s05_weak and fighter.s05_role not in Ikki.FARMERS: return false
		if not _choice(fighter.get("s05_move_clip"),["walk","run","retreat_run","retreat"]): return false
		if not _number(fighter.get("s05_root_px"),-2000,3000) or not _integer(fighter.get("s05_target"),0): return false
		if not _id_list(fighter.get("s05_combo")) or fighter.s05_combo.size()>2: return false
		if not _strings(fighter.get("s05_events"),32,80): return false
	if fighter.has("s05_combo_owner") and not _integer(fighter.s05_combo_owner,0): return false
	if fighter.has("mikawa_role"):
		if fighter.get("team") != 1 or not _choice(fighter.mikawa_role,Mikawa.ROLES) or not fighter.get("mikawa_escort") is bool: return false
		for key in ["mikawa_sequence","mikawa_command"]:
			if not _integer(fighter.get(key),0): return false
		if not _strings(fighter.get("mikawa_events"),16,32) or not fighter.get("mikawa_pressure") is Array or fighter.mikawa_pressure.size()>150: return false
		for hit in fighter.mikawa_pressure:
			if not hit is Dictionary or not _strings([hit.get("key")],1,32) or not _integer(hit.get("tick"),0) or not _choice(hit.get("band"),["near","far"]): return false
		if not fighter.get("mikawa_counters") is Dictionary: return false
		for key in ["spin","rock","shared"]:
			if not _integer(fighter.mikawa_counters.get(key),0): return false
		if fighter.has("mikawa_roster") and (not _id_list(fighter.mikawa_roster) or fighter.mikawa_roster.size()>6): return false
	for field in ["combat_previous_ms","combat_step","combat_air_start"]:
		if fighter.has(field) and not _number(fighter[field],-1,1000000000): return false
	if fighter.has("light_recovery_ticks") and not _integer(fighter.light_recovery_ticks,0,30): return false
	if fighter.has("grab_hits") and not _integer(fighter.grab_hits,0,2): return false
	if fighter.has("throw_clip") and not _choice(fighter.throw_clip,["throw_forward","throw_reverse"]): return false
	if fighter.has("throw_face") and (not _integer(fighter.throw_face,-1,1) or fighter.throw_face == 0): return false
	for field in ["reach_thrust","reach_sweep"]:
		if fighter.has(field) and not _number(fighter[field],1,400): return false
	if not _position(fighter) or not _number(fighter.get("z"), 0.0, 10000.0):
		return false
	if not _choice(fighter.get("kind"), KINDS) or not _action(fighter.get("action")):
		return false
	for field in FIGHTER_RANGES:
		if not _integer(fighter.get(field), FIGHTER_RANGES[field][0], FIGHTER_RANGES[field][1]):
			return false
	if fighter.face == 0 or fighter.hp > fighter.max_hp:
		return false
	if not _choice(fighter.get("shield_kind"),[""] + Battle.TALISMANS.keys()): return false
	if fighter.shield_points > 0 and (fighter.shield_kind == "" or fighter.shield_points > Battle.TALISMANS[fighter.shield_kind].durability): return false
	if fighter.shield_points == 0 and fighter.shield_kind != "": return false
	if fighter.next_life_score <= fighter.score or fighter.next_life_score % Battle.EXTRA_LIFE_SCORE != 0: return false
	if fighter.team == 0 and (fighter.player_index < 0 or fighter.kind not in Battle.PLAYABLE_HEROES):
		return false
	if fighter.team == 1 and fighter.player_index != -1:
		return false
	if fighter.has("role"):
		if fighter.team != 1 or not _choice(fighter.role,Battle.ENEMY_ROLES.keys()) or fighter.kind != Battle.ENEMY_ROLES[fighter.role]: return false
	if fighter.team == 0:
		if not _choice(fighter.get("food_state"),["ready","pending","spent"]): return false
		if fighter.get("bag_only") != true: return false
		if fighter.weapon_id != "" and not Weapons.compatible(fighter.kind,fighter.weapon_id): return false
		if not Equipment.valid(fighter) or not Achievements.valid(fighter.get("achievements")) or not Achievements.valid(fighter.get("performance_awards")): return false
		for field in ["attack_id","achievement_reward_tick"]:
			if not _integer(fighter.get(field),-1200,1000000000): return false
		if not _number(fighter.get("attack_speed"),0.5,2.0): return false
		if not fighter.get("performance") is Dictionary or fighter.performance.size() > 40: return false
		for key in fighter.performance:
			if not (key is String or key is StringName) or str(key).length() > 32: return false
			if key == "hit_ids":
				if not _id_list(fighter.performance[key]): return false
			elif not _integer(fighter.performance[key],-1000,1000000000): return false
	if fighter.team == 1 and (fighter.get("weapon_id") != "" or fighter.get("owned_weapons") != []): return false
	if fighter.has("combo") and not _integer(fighter.combo, 0, 3):
		return false
	if fighter.has("heavy_combo") and not _integer(fighter.heavy_combo, 0, 2):
		return false
	if fighter.has("weight") and not _choice(fighter.weight, ["light", "medium", "heavy"]): return false
	if fighter.has("throw_hits") and not _id_list(fighter.throw_hits): return false
	if fighter.has("charge_direction") and not _integer(fighter.charge_direction, -1, 1): return false
	if fighter.has("shattered_tick") and not _integer(fighter.shattered_tick, -1): return false
	if fighter.has("pickup_flash_tick") and not _integer(fighter.pickup_flash_tick,-1000): return false
	if fighter.has("extra_life_tick") and not _integer(fighter.extra_life_tick,-1000): return false
	if fighter.has("is_yoshimoto") and not fighter.is_yoshimoto is bool: return false
	if fighter.get("is_yoshimoto",false) and (fighter.team != 1 or fighter.kind != "boss"): return false
	if fighter.has("lieutenant_slot") and not _integer(fighter.lieutenant_slot,1,2): return false
	if fighter.has("formation_slot") and not _integer(fighter.formation_slot,1,16): return false
	if fighter.has("formation_moving") and not fighter.formation_moving is bool: return false
	if fighter.has("encounter_epoch") and not _integer(fighter.encounter_epoch,1): return false
	if fighter.has("replacement_queued") and not fighter.replacement_queued is bool: return false
	if fighter.has("entering") and not fighter.entering is bool: return false
	if fighter.has("entry_x") and not _number(fighter.entry_x): return false
	if fighter.has("attack_variant") and not _integer(fighter.attack_variant, 0, 3): return false
	if fighter.has("mixed_ready") and not fighter.mixed_ready is bool: return false
	for field in ["sprinting", "airborne_lock", "down_from_air"]:
		if fighter.has(field) and not fighter[field] is bool: return false
	for field in ["move_dx", "move_dy", "tap_dx", "tap_dy", "sprint_dx", "sprint_dy"]:
		if fighter.has(field) and not _integer(fighter[field], -1, 1): return false
	if fighter.has("tap_tick") and not _integer(fighter.tap_tick, -1000): return false
	if fighter.has("sprint_ticks") and not _integer(fighter.sprint_ticks,0,12): return false
	if fighter.has("bounces_left") and not _integer(fighter.bounces_left, 0, 2): return false
	if fighter.has("landing_count") and not _integer(fighter.landing_count, 0, 3): return false
	for field in ["down_ticks", "bump_cooldown", "guard_hit_tick", "counter_ticks"]:
		if fighter.has(field) and not _integer(fighter[field], 0, 1000): return false
	if fighter.has("faction") and not _choice(fighter.faction, ["heroes"] + Battle.FACTIONS.keys()): return false
	if fighter.has("boss_variant") and not _choice(fighter.boss_variant, [""] + Battle.BOSS_PROFILES.keys()): return false
	if fighter.has("stage_boss") and not fighter.stage_boss is bool: return false
	if fighter.has("death_ticks") and not _integer(fighter.death_ticks,1,600): return false
	if fighter.has("death_voice") and (not fighter.death_voice is String or fighter.death_voice.length() > 100): return false
	if fighter.has("render_scale") and not _number(fighter.render_scale,0.8,1.5): return false
	for field in ["display_name","intro_line"]:
		if fighter.has(field) and (not fighter[field] is String or fighter[field].length() > 200): return false
	if fighter.has("boss_actions"):
		if not fighter.boss_actions is Array or fighter.boss_actions.is_empty() or fighter.boss_actions.size() > 4: return false
		for action in fighter.boss_actions:
			if not _choice(action,Battle.ENEMY_TIMING.keys()): return false
	if fighter.has("last_attack") and not _choice(fighter.last_attack, ["", "light", "heavy"]): return false
	for field in ["element_weapon_uid","element_attack_id","poison_weapon_uid"]:
		if fighter.has(field) and not _integer(fighter[field],0,1000000000): return false
	if fighter.has("element_action") and fighter.element_action != "" and not _action(fighter.element_action): return false
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
	if effect.has("s05_arrow") and (not effect.s05_arrow is bool or not effect.s05_arrow or effect.get("type")!="projectile" or effect.get("weapon")!="arrow" or effect.get("team")!=1): return false
	if effect.get("type") in ["s05_wave","s05_fx"]:
		if not _integer(effect.get("owner"),1) or not _number(effect.get("z"),-500,2000): return false
		if effect.type == "s05_wave":
			if not _choice(effect.get("s05_asset"),["ground","diagonal","sweep"]) or effect.get("team") != 1: return false
			if not _number(effect.get("vx"),-50,50) or effect.vx==0 or not _number(effect.get("vz"),-20,20): return false
			if not _id_list(effect.get("hit_ids")) or effect.hit_ids.size()>2 or not _integer(effect.get("damage"),1,100): return false
		else:
			if not _choice(effect.get("s05_asset"),["rapid","return"]) or not _number(effect.get("angle"),-360,360): return false
	for field in ["visual_exact_origin","combat_sword_wave"]:
		if effect.has(field) and not effect[field] is bool: return false
	for field in ["collision_height","standing_push"]:
		if effect.has(field) and not _number(effect[field],0,200): return false
	if effect.has("rain_center_x") and not _number(effect.rain_center_x): return false
	if effect.get("type","") in ["sky_arrow","arrow_rain"]:
		for field in ["owner","team","radius","damage","equipment_uid","attack_id"]:
			if not effect.has(field): return false
		if effect.type == "sky_arrow" and (not effect.has("z") or not effect.has("rain_center_x")): return false
	if effect.get("type") == "mikawa_fx" and (not _choice(effect.get("asset"),["quake","stone_impact"]) or not _integer(effect.get("owner"),1)): return false
	if effect.has("mikawa_projectile"):
		if effect.get("type") != "projectile" or not _choice(effect.mikawa_projectile,["stone","rain","wave"]) or effect.get("team") != 1: return false
		if effect.mikawa_projectile == "stone" and not _number(effect.get("range_left"),0,1100): return false
		if effect.mikawa_projectile == "rain":
			for field in ["from_x","from_y","land_x","land_y"]:
				if not _number(effect.get(field)): return false
			if not _integer(effect.get("command"),1) or not _integer(effect.get("wave"),0,3): return false
	if not _choice(effect.get("type"), EFFECTS+["sky_arrow","arrow_rain","mikawa_fx","s05_wave","s05_fx"]) or not _position(effect):
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
	for field in ["arcing", "wet", "descending", "fire_area"]:
		if effect.has(field) and not effect[field] is bool: return false
	for field in ["flight_tick", "flight_ticks", "bounce", "amount"]:
		if effect.has(field) and not _integer(effect[field], 0, 1000000): return false
	for field in ["start_z", "arc_height"]:
		if effect.has(field) and not _number(effect[field], 0.0, 10000.0): return false
	if effect.has("element") and not _choice(effect.element, ["", "fire", "ice", "wind", "earth", "blade"]): return false
	if effect.has("equipment_id") and not _choice(effect.equipment_id,[""] + Weapons.ITEMS.keys()): return false
	for field in ["equipment_uid","attack_id"]:
		if effect.has(field) and not _integer(effect[field],0,1000000000): return false
	if effect.has("equipment_knockback") and not _number(effect.equipment_knockback,0,4): return false
	if effect.has("hit_ids") and not _id_list(effect.hit_ids): return false
	if effect.has("weapon") and not _choice(effect.weapon, ["needle", "arrow", "special_arrow", "bullet", "blade","blunt"]): return false
	if effect.has("kind") and not effect.kind is String:
		return false
	if effect.has("action") and not _action(effect.action): return false
	if effect.has("action_tick") and not _integer(effect.action_tick, 0): return false
	if effect.has("combo") and not _integer(effect.combo, 0, 3): return false
	if effect.has("heavy_combo") and not _integer(effect.heavy_combo, 0, 2): return false
	if effect.has("yoshimoto_projectile") and not effect.yoshimoto_projectile is bool: return false
	if effect.has("boss_wave") and not effect.boss_wave is bool: return false
	if effect.get("yoshimoto_projectile",false):
		if effect.has("visual_height") and not _number(effect.visual_height,0,400): return false
		if effect.type != "projectile" or not effect.has("boss_wave") or effect.get("team") != 1: return false
		if effect.get("weapon") != ("blade" if effect.boss_wave else "arrow") or effect.get("action") != ("boss_sword_wave" if effect.boss_wave else "boss_arrow"): return false
		if not _number(effect.get("vx")) or absf(float(effect.vx)) < 1 or not _number(effect.get("vy")): return false
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
	if effect.type == "fire_patch":
		if not _number(effect.get("radius"),1,120) or not _integer(effect.get("owner"),1) or not _integer(effect.get("team"),0,1): return false
		if not _integer(effect.get("damage"),1,30) or not _integer(effect.get("warmup"),1,120) or not _integer(effect.get("interval"),1,120): return false
	if effect.type == "landing" and (not effect.has("wet") or not effect.has("bounce") or not effect.has("target")): return false
	if effect.type == "debris" and not _choice(effect.get("kind"), PROP_KINDS): return false
	return true


static func _position(item: Dictionary) -> bool:
	return _number(item.get("x")) and _number(item.get("y"))

static func _strings(items: Variant, count: int, length: int) -> bool:
	if not items is Array or items.size()>count: return false
	return items.all(func(item): return item is String and item.length()<=length)

static func _valid_mikawa(box: Variant) -> bool:
	if not box is Dictionary or not _integer(box.get("node"),1,13) or not _choice(box.get("phase"),["combat","retreat","complete"]): return false
	if not _integer(box.get("command"),0) or not _integer(box.get("boss"),0) or not _integer(box.get("retreat_tick"),-1): return false
	for key in ["epoch","admit_tick","escort_tick"]:
		if not _integer(box.get(key),0): return false
	if not _integer(box.get("next_batch"),0,3) or not box.get("escape_complete") is bool: return false
	if not box.get("reserved") is Array or box.reserved.size()>4: return false
	for pair in box.reserved:
		if not pair is Dictionary: return false
		for side in ["left","right"]:
			var unit: Variant = pair.get(side)
			if not unit is Dictionary or not _choice(unit.get("kind"),["soldier","archer","gunner"]) or not _choice(unit.get("role"),Mikawa.ROLES.slice(0,6)): return false
	if not _id_list(box.get("deaths")) or not _strings(box.get("rain_hits"),128,32): return false
	if not box.get("pending") is Array or box.pending.size()>6 or not box.get("mud") is Array or box.mud.size()>16: return false
	for token in box.pending:
		if not token is Dictionary or not _integer(token.get("due"),0) or not _integer(token.get("dead"),1): return false
	for point in box.mud:
		if not point is Array or point.size()!=2 or not _number(point[0]) or not _number(point[1],360,600): return false
	return true


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
	return value is String and (value in ACTIONS or value in ["counter_cut","grab_start","grab_hit_1","grab_hit_2","charge_rain"] or Battle.ENEMY_TIMING.has(value) or Ikki.HITS.has(value))

static func _valid_ikki(box: Variant) -> bool:
	if not box is Dictionary: return false
	if not _integer(box.get("node"),1,12) or not _choice(box.get("phase"),["combat","complete"]): return false
	for key in ["admit_tick","farmer_tick","entry_seq","boss"]:
		if not _integer(box.get(key),0): return false
	if not _integer(box.get("summon_count"),0,3): return false
	for key in ["thresholds","summons"]:
		if not box.get(key) is Array or box[key].size()>3: return false
		var seen := []
		for value in box[key]:
			if not value is int or value not in [70,40,10] or value in seen: return false
			seen.append(value)
	if not box.get("pending") is Array or box.pending.size()>24: return false
	for unit in box.pending:
		if not unit is Dictionary or not _choice(unit.get("role"),Ikki.FARMERS+["monk"]) or not unit.get("elite") is bool or not unit.get("weak") is bool: return false
		if not _choice(unit.get("source"),["banner","summon","farmer"]) or not _integer(unit.get("due"),0): return false
		if unit.elite and unit.role != "monk": return false
		if unit.weak and unit.role not in Ikki.FARMERS: return false
		if (unit.source=="summon")!=unit.elite or (unit.source=="farmer")!=unit.weak: return false
	return true
