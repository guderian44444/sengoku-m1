extends SceneTree

const Battle = preload("res://core/battle.gd")
const Wire = preload("res://core/wire.gd")
const Equipment = preload("res://core/equipment.gd")
var checks := 0
var failures := 0


func _init() -> void:
	_test_real_states()
	_test_invalid_snapshots()
	print("WIRE TESTS %s: %d checks, %d failures" % ["PASSED" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + label)


func _test_real_states() -> void:
	var battle = Battle.new()
	for mode in ["easy", "normal", "hard"]:
		battle.reset(mode, 2)
		_check(Wire.valid_snapshot(battle.get_state()), "initial " + mode)
	var every_tick_valid := true
	for tick in range(900):
		var buttons: int = Battle.HEAVY if tick % 80 < 40 else (Battle.LIGHT if tick % 2 == 0 else 0)
		battle.step([{"dx": 1, "dy": 0, "buttons": buttons}, {"dx": 1, "dy": 0, "buttons": buttons}])
		every_tick_valid = every_tick_valid and Wire.valid_snapshot(battle.get_state())
	_check(every_tick_valid, "900 real simulation snapshots validate")
	battle.reset("normal", 2)
	for wave in range(3):
		for fighter in battle.state.fighters:
			if fighter.team == 1:
				fighter.hp = 0
		battle.step([])
		_check(Wire.valid_snapshot(battle.get_state()), "wave transition validates")
	_check(battle.state.phase == "won", "validated terminal snapshot is a real victory")
	battle.reset()
	battle.state.fighters[0].hp = 0
	battle.step([])
	_check(Wire.valid_snapshot(battle.get_state()), "lost snapshot validates")
	var valid: Dictionary = Battle.new().get_state()
	valid.fighters[0].hp = -1
	valid.fighters[0].y = 600.0
	valid["future_extension"] = {"allowed": true}
	_check(Wire.valid_snapshot(valid), "negative defeated HP, lane boundary and unknown field allowed")
	for type in Wire.EFFECTS:
		var effect := {"type": type, "x": 100.0, "y": 300.0, "life": 10, "max_life": 50, "z": 28.0, "vx": -11.0, "owner": 1, "team": 0, "damage": 20, "poison": 120, "face": -1, "radius": 100.0, "heavy": true, "hit_ids": []}
		if type == "chain": effect.merge({"target": 2, "target_x": 300.0, "target_y": 450.0})
		if type == "damage": effect.merge({"target": 2, "amount": 20})
		if type == "landing": effect.merge({"target": 2, "wet": true, "bounce": 1})
		if type == "debris": effect.kind = "crate"
		if type == "fire_patch": effect.merge({"warmup":30,"interval":45})
		valid.effects = [effect]
		_check(Wire.valid_snapshot(valid), "effect " + type)
	valid.effects = []
	for metadata in [{"action_tick":0,"combo":0,"heavy_combo":0},{"action_tick":192,"combo":3,"heavy_combo":2}]:
		valid.effects = [{"type":"projectile","x":100.0,"y":300.0,"life":10,"max_life":50,"z":28.0,"vx":11.0,"owner":1,"team":0,"damage":20,"poison":0,"face":1}]
		valid.effects[0].merge(metadata)
		_check(Wire.valid_snapshot(valid),"projectile source timing metadata accepts boundary values")
	valid.effects = []
	valid.fighters[0]["heavy_combo"] = 2
	valid.fighters[0]["heavy_combo_tick"] = 70
	_check(Wire.valid_snapshot(valid), "second heavy chain stage validates")
	valid.fighters[0].action = "dash_heavy"
	valid.effects = [{"type":"ice_hit","x":100.0,"y":300.0,"life":10,"max_life":24,"burst":true,"burst_radius":100.0,"burst_damage":6,"previous_y":480.0,"arc_degrees":120.0,"knockdown":false,"shatter_damage":0,"follow_freeze":true}]
	_check(Wire.valid_snapshot(valid), "v13 dash action and optional burst, cone and freeze-followup metadata validate")
	valid.effects = []
	valid.fighters[1].action = "boss_grab_throw"
	valid.fighters[1].attack_variant = 3
	_check(Wire.valid_snapshot(valid), "v14 fourth boss attack and grab-throw action validate")
	for type in Wire.EVENTS:
		valid.events = [{"type": type, "x": 500.0, "y": 450.0, "id": 1, "actor": 1, "target": 2}]
		if type == "encounter_phase": valid.events[0].merge({"phase":"active","encounter_epoch":1})
		if type == "damage": valid.events[0].amount = 20
		if type == "challenge_complete": valid.events[0].amount = 300
		if type == "food_pickup": valid.events[0].merge({"food_id":"rice", "heal":40})
		if type == "food_stored": valid.events[0].food_id = "rice"
		if type == "achievement": valid.events[0].merge({"achievement_id":"cleave3","loot":false,"description":"單次攻擊命中 3 人","name":"一刀三斬"})
		_check(Wire.valid_snapshot(valid), "event " + type)
	for metadata in [{}, {"combo": 0, "heavy_combo": 0, "finisher": false}, {"combo": 3, "heavy_combo": 2, "finisher": true}]:
		valid.events = [{"type": "swing", "x": 500.0, "y": 450.0, "id": 1, "actor": 1, "target": 0, "action": "light"}]
		valid.events[0].merge(metadata)
		_check(Wire.valid_snapshot(valid), "optional v11 swing metadata preserves old events and accepts boundary values")


func _test_invalid_snapshots() -> void:
	var original: Dictionary = Battle.new().get_state()
	for field in original:
		var missing := original.duplicate(true)
		missing.erase(field)
		_check(not Wire.valid_snapshot(missing), "missing top-level " + str(field))
	for field in {"fighters": 64, "drops": 64, "effects": 256, "events": 128}:
		var oversize := original.duplicate(true)
		var limit: int = {"fighters": 64, "drops": 64, "effects": 256, "events": 128}[field]
		oversize[field] = []
		oversize[field].resize(limit + 1)
		_check(not Wire.valid_snapshot(oversize), "oversize " + field)
		var malformed := original.duplicate(true)
		malformed[field] = [1]
		_check(not Wire.valid_snapshot(malformed), "non-dictionary " + field + " item")
	for field in ["x", "y", "z", "hp", "max_hp", "rage", "team", "kind", "player_index", "armor", "weapon", "face", "action", "action_tick", "charge", "poison", "invuln", "vz", "target_x", "lives", "score", "next_life_score", "respawn_ticks", "shield_points", "shield_kind", "extra_life_tick", "food_state"]:
		var malformed := original.duplicate(true)
		malformed.fighters[0][field] = []
		_check(not Wire.valid_snapshot(malformed), "malformed fighter " + field)
	for value in [NAN, INF, -INF]:
		var malformed := original.duplicate(true)
		malformed.fighters[0].x = value
		_check(not Wire.valid_snapshot(malformed), "non-finite fighter coordinate")
	for pair in [["tick", -1], ["tick", 1.5], ["phase", "unknown"], ["difficulty", "unknown"], ["wave", 4], ["wave", 0]]:
		var malformed := original.duplicate(true)
		malformed[pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(malformed), "invalid top-level " + str(pair))
	for pair in [["face", 0], ["team", 2], ["rage", 101], ["max_hp", 0], ["armor", 2], ["player_index", -1], ["combo", 4], ["heavy_combo", 3], ["heavy_combo", 1.5], ["heavy_combo_tick", -1], ["heavy_combo_tick", INF], ["knockback", INF]]:
		var malformed := original.duplicate(true)
		malformed.fighters[0][pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(malformed), "invalid fighter range " + str(pair))
	for pair in [["lives",-1],["lives",1.5],["score",NAN],["score",-1],["next_life_score",0],["next_life_score",10001],["respawn_ticks",121],["shield_points",111],["shield_kind","unknown"],["extra_life_tick",INF]]:
		var malformed := original.duplicate(true)
		malformed.fighters[0][pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(malformed), "invalid progression stat " + str(pair))
	for key in Battle.TALISMANS:
		var shielded := original.duplicate(true)
		Equipment.equip(shielded.fighters[0],Equipment.add(shielded.fighters[0],key))
		shielded.drops = [{"id":999,"kind":"talisman","x":300.0,"y":450.0,"talisman_id":key}]
		_check(Wire.valid_snapshot(shielded), "Valid talisman and shield " + key)
		shielded.fighters[0].shield_points += 1
		_check(not Wire.valid_snapshot(shielded), "Shield cannot exceed its own capacity " + key)
	for key in [null,"",[],"unknown"]:
		var malformed := original.duplicate(true)
		malformed.drops = [{"id":999,"kind":"talisman","x":300.0,"y":450.0,"talisman_id":key}]
		_check(not Wire.valid_snapshot(malformed), "Talisman ID must be known")
	for pair in [["x", NAN], ["kind", "unknown"], ["id", "1"]]:
		var malformed := original.duplicate(true)
		malformed.drops[0][pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(malformed), "invalid drop " + str(pair[0]))
	for pair in [["radius", NAN], ["radius", -1.0], ["heavy", []], ["life", "5"], ["type", "unknown"], ["face", 0], ["owner", []], ["z", INF], ["finisher", []], ["previous_x", INF]]:
		var malformed := original.duplicate(true)
		malformed.effects = [{"type": "hit", "x": 1.0, "y": 2.0, "life": 5, "max_life": 10}]
		malformed.effects[0][pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(malformed), "invalid effect " + str(pair[0]))
	for pair in [["x", INF], ["id", []], ["actor", "1"], ["target", -1], ["type", "unknown"], ["combo", -1], ["combo", 4], ["combo", 1.5], ["combo", "3"], ["heavy_combo", -1], ["heavy_combo", 3], ["heavy_combo", 1.5], ["heavy_combo", "2"], ["finisher", 1], ["finisher", "true"]]:
		var malformed := original.duplicate(true)
		malformed.events = [{"type": "hit", "x": 1.0, "y": 2.0, "id": 1, "actor": 1, "target": 2}]
		malformed.events[0][pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(malformed), "invalid event " + str(pair[0]))
	for pair in [["food_id","unknown"],["food_id",null],["heal",0],["heal",121],["heal",1.5],["heal",null]]:
		var malformed := original.duplicate(true)
		malformed.events = [{"type":"food_pickup","x":500.0,"y":450.0,"id":1,"actor":1,"target":2,"food_id":"rice","heal":40}]
		malformed.events[0][pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(malformed), "invalid healing event " + str(pair[0]))
	for pair in [["action_tick",{}],["action_tick","12"],["action_tick",-1],["action_tick",1.5],["combo",{}],["combo","1"],["combo",-1],["combo",4],["heavy_combo",{}],["heavy_combo","1"],["heavy_combo",-1],["heavy_combo",3]]:
		var malformed := original.duplicate(true)
		malformed.effects = [{"type":"projectile","x":100.0,"y":300.0,"life":10,"max_life":50,"z":28.0,"vx":11.0,"owner":1,"team":0,"damage":20,"poison":0,"face":1}]
		malformed.effects[0][pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(malformed),"invalid projectile source timing " + str(pair[0]))
	for pair in [["previous_y",INF],["previous_y",{}],["arc_degrees",-1],["arc_degrees",361],["arc_degrees","120"],["burst_radius",-1],["burst_radius",{}],["burst_damage",-1],["burst_damage",1.5],["burst",1],["knockdown","false"],["follow_freeze",[]],["shatter_damage",-1],["shatter_damage",25]]:
		var malformed := original.duplicate(true)
		malformed.effects = [{"type":"ice_hit","x":100.0,"y":300.0,"life":10,"max_life":24}]
		malformed.effects[0][pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(malformed),"reject malformed v13 combat metadata " + str(pair[0]))
	for pair in [["burn", -1], ["freeze", "120"], ["burn_owner", INF], ["charge_direction", 2], ["attack_variant", 4], ["mixed_ready", 1], ["last_attack", "arbitrary"], ["pull_owner", -1], ["shattered_tick", -2]]:
		var malformed := original.duplicate(true)
		malformed.fighters[0][pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(malformed), "reject malformed v09 fighter field " + str(pair[0]))
	for pair in [["element", "lightning"], ["shatter_hit", 1], ["target_x", INF], ["target_y", "450"], ["weapon", "unknown"], ["action", "unknown"], ["action", 1]]:
		var malformed := original.duplicate(true)
		malformed.effects = [{"type": "hit", "x": 1.0, "y": 2.0, "life": 5, "max_life": 10}]
		malformed.effects[0][pair[0]] = pair[1]
		_check(not Wire.valid_snapshot(malformed), "reject malformed v09 effect field " + str(pair[0]))
	for field in ["owner", "target", "target_x", "target_y", "face"]:
		var malformed := original.duplicate(true)
		malformed.effects = [{"type": "chain", "x": 1.0, "y": 2.0, "life": 5, "max_life": 10, "owner": 1, "target": 2, "target_x": 500.0, "target_y": 450.0, "face": 1}]
		malformed.effects[0].erase(field)
		_check(not Wire.valid_snapshot(malformed), "reject incomplete chain " + field)
